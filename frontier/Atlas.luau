--!native
--!optimize 2
-- Texture atlas pages: many small dynamic surfaces share one EditableImage.
-- The engine refreshes only one EditableImage per frame, so 16 separate 256² images take 16 frames to
-- show a change; 16 regions on one 1024² page show it next frame. Each region gives ImageRect values
-- for ImageLabels and a UV rect for meshes.
--
-- Allocation is shelf packing with power-of-two-ish shelf heights and a per-shelf free list, so freed
-- regions are reused without fragmentation creeping across the page. Regions carry a gutter of
-- duplicated edge pixels so bilinear sampling never bleeds into a neighbour.
-- Pure Luau: Uploader.luau decides which page to send each frame.

local Atlas = {}
Atlas.__index = Atlas

export type Region = {
	page: Page,
	x: number, -- content origin inside the page (gutter excluded)
	y: number,
	w: number,
	h: number,
	shelf: Shelf,
	slotX: number,
	slotW: number,
	weight: number, -- visibility weight used by Uploader (e.g. on-screen pixel area)
}

export type Shelf = {
	y: number,
	h: number,
	cursor: number,
	free: { { x: number, w: number } },
}

export type Page = {
	id: number,
	size: number,
	gutter: number,
	rgba: buffer,
	shelves: { Shelf },
	nextShelfY: number,
	-- dirty rect, inclusive-exclusive; dx0 > dx1 means clean
	dx0: number,
	dy0: number,
	dx1: number,
	dy1: number,
	lastUpload: number,
	live: number,
}

local function shelfHeight(h: number): number
	-- Round up to a multiple of 8 below 64 and to the next power of two above, so similar sizes share shelves.
	if h <= 64 then
		return (h + 7) // 8 * 8
	end
	local p = 64
	while p < h do
		p *= 2
	end
	return p
end

function Atlas.newPage(id: number, size: number?, gutter: number?): Page
	local s = size or 1024
	return {
		id = id,
		size = s,
		gutter = gutter or 1,
		rgba = buffer.create(s * s * 4),
		shelves = {},
		nextShelfY = 0,
		dx0 = s,
		dy0 = s,
		dx1 = 0,
		dy1 = 0,
		lastUpload = -1,
		live = 0,
	}
end

-- Allocate a w×h region. Returns nil if the page has no room.
function Atlas.alloc(page: Page, w: number, h: number): Region?
	local g = page.gutter
	local sw, sh = w + 2 * g, h + 2 * g
	if sw > page.size or sh > page.size then
		return nil
	end
	local want = shelfHeight(sh)
	local best: Shelf? = nil
	for _, shelf in page.shelves do
		if shelf.h >= sh and shelf.h <= want * 2 then
			-- Reuse a freed slot first (first fit).
			for i, slot in shelf.free do
				if slot.w >= sw then
					table.remove(shelf.free, i)
					if slot.w > sw then
						table.insert(shelf.free, { x = slot.x + sw, w = slot.w - sw })
					end
					page.live += 1
					return {
						page = page, x = slot.x + g, y = shelf.y + g, w = w, h = h,
						shelf = shelf, slotX = slot.x, slotW = sw, weight = 1,
					}
				end
			end
			if page.size - shelf.cursor >= sw and (best == nil or shelf.h < (best :: Shelf).h) then
				best = shelf
			end
		end
	end
	local shelf = best
	if shelf == nil then
		-- An empty shelf that is too tall gets split instead of wasting its height.
		for i, s in page.shelves do
			if s.cursor == 0 and #s.free == 0 and s.h >= sh then
				if s.h - want >= 8 then
					table.insert(page.shelves, i + 1, { y = s.y + want, h = s.h - want, cursor = 0, free = {} })
					s.h = want
				end
				shelf = s
				break
			end
		end
	end
	if shelf == nil then
		if page.nextShelfY + want > page.size then
			if page.nextShelfY + sh > page.size then
				return nil
			end
			want = page.size - page.nextShelfY -- last shelf takes whatever height is left
		end
		local s: Shelf = { y = page.nextShelfY, h = want, cursor = 0, free = {} }
		page.nextShelfY += want
		table.insert(page.shelves, s)
		shelf = s
	end
	local sh2 = shelf :: Shelf
	local x = sh2.cursor
	sh2.cursor += sw
	page.live += 1
	return { page = page, x = x + g, y = sh2.y + g, w = w, h = h, shelf = sh2, slotX = x, slotW = sw, weight = 1 }
end

-- Return a region's slot to its shelf. Adjacent free slots merge; a free tail rolls the cursor back.
function Atlas.free(region: Region)
	local shelf, page = region.shelf, region.page
	page.live -= 1
	local x, w = region.slotX, region.slotW
	local free = shelf.free
	local i = 1
	while i <= #free do
		local s = free[i]
		if s.x + s.w == x then
			x, w = s.x, s.w + w
			table.remove(free, i)
		elseif x + w == s.x then
			w += s.w
			table.remove(free, i)
		else
			i += 1
		end
	end
	if x + w == shelf.cursor then
		shelf.cursor = x
	else
		table.insert(free, { x = x, w = w })
	end
	if shelf.cursor == 0 and #free == 0 then
		-- Shelf is empty: merge it with empty neighbours so taller regions can use the space later.
		local shelves = page.shelves
		local i = 1
		while i < #shelves do
			local a, b = shelves[i], shelves[i + 1]
			if a.cursor == 0 and #a.free == 0 and b.cursor == 0 and #b.free == 0 and a.y + a.h == b.y then
				a.h += b.h
				table.remove(shelves, i + 1)
			else
				i += 1
			end
		end
		local last = shelves[#shelves]
		if last and last.cursor == 0 and #last.free == 0 and last.y + last.h == page.nextShelfY then
			page.nextShelfY = last.y
			table.remove(shelves)
		end
	end
end

local function markDirty(page: Page, x0: number, y0: number, x1: number, y1: number)
	if x0 < page.dx0 then page.dx0 = x0 end
	if y0 < page.dy0 then page.dy0 = y0 end
	if x1 > page.dx1 then page.dx1 = x1 end
	if y1 > page.dy1 then page.dy1 = y1 end
end
Atlas.markDirty = markDirty

-- Copy a tightly packed w×h RGBA buffer into the region and refresh its gutter.
function Atlas.write(region: Region, src: buffer)
	local page, g = region.page, region.page.gutter
	local S, dst = page.size, page.rgba
	local x, y, w, h = region.x, region.y, region.w, region.h
	for row = 0, h - 1 do
		buffer.copy(dst, ((y + row) * S + x) * 4, src, row * w * 4, w * 4)
	end
	if g > 0 then
		-- Extend edge pixels into the gutter (left/right columns, then full top/bottom rows).
		for row = 0, h - 1 do
			local o = ((y + row) * S + x) * 4
			local l, r = buffer.readu32(dst, o), buffer.readu32(dst, o + (w - 1) * 4)
			for k = 1, g do
				buffer.writeu32(dst, o - k * 4, l)
				buffer.writeu32(dst, o + (w - 1 + k) * 4, r)
			end
		end
		local rowBytes = (w + 2 * g) * 4
		local top, bottom = (y * S + x - g) * 4, ((y + h - 1) * S + x - g) * 4
		for k = 1, g do
			buffer.copy(dst, top - k * S * 4, dst, top, rowBytes)
			buffer.copy(dst, bottom + k * S * 4, dst, bottom, rowBytes)
		end
	end
	markDirty(page, x - g, y - g, x + w + g, y + h + g)
end

-- ImageLabel.ImageRectOffset / ImageRectSize values (pixels).
function Atlas.imageRect(region: Region): (number, number, number, number)
	return region.x, region.y, region.w, region.h
end

-- UV rect for mesh faces: texel centres of the content area, origin top-left.
function Atlas.uvRect(region: Region): (number, number, number, number)
	local S = region.page.size
	return (region.x + 0.5) / S, (region.y + 0.5) / S, (region.x + region.w - 0.5) / S, (region.y + region.h - 0.5) / S
end

function Atlas.isDirty(page: Page): boolean
	return page.dx0 < page.dx1
end

function Atlas.clearDirty(page: Page)
	page.dx0, page.dy0, page.dx1, page.dy1 = page.size, page.size, 0, 0
end

return Atlas
