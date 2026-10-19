--!native
--!optimize 2
-- Palette-indexed framebuffer: simulate and draw at 1 byte per pixel, expand to RGBA8 only when presenting.
-- 4x less memory traffic than RGBA for simulations, and palette effects (cycling, team recolour, flash,
-- day/night) cost 256 writes instead of a full repaint.
-- Dirty tracking is per 16x16 tile, so presenting only touches tiles that changed.
-- Pure Luau. Only `present` touches Roblox (EditableImage:WritePixelsBuffer).

local IndexedFrame = {}
IndexedFrame.__index = IndexedFrame

local TILE = 16

export type IndexedFrame = typeof(setmetatable(
	{} :: {
		w: number,
		h: number,
		idx: buffer,
		rgba: buffer,
		lut: buffer,
		tw: number,
		th: number,
		dirty: buffer,
		allDirty: boolean,
		stage: buffer?,
	},
	IndexedFrame
))

function IndexedFrame.new(w: number, h: number): IndexedFrame
	local tw, th = (w + TILE - 1) // TILE, (h + TILE - 1) // TILE
	local self = setmetatable({
		w = w,
		h = h,
		idx = buffer.create(w * h),
		rgba = buffer.create(w * h * 4),
		lut = buffer.create(256 * 4),
		tw = tw,
		th = th,
		dirty = buffer.create(tw * th),
		allDirty = true,
		stage = nil,
	}, IndexedFrame)
	return self
end

-- Palette ------------------------------------------------------------------

function IndexedFrame.setColor(self: IndexedFrame, i: number, r: number, g: number, b: number, a: number?)
	buffer.writeu32(self.lut, i * 4, bit32.bor(r, bit32.lshift(g, 8), bit32.lshift(b, 16), bit32.lshift(a or 255, 24)))
	self.allDirty = true
end

function IndexedFrame.getColor(self: IndexedFrame, i: number): number
	return buffer.readu32(self.lut, i * 4)
end

-- Rotate palette entries [first, last] by `shift` places (classic colour cycling: water, lava, neon).
function IndexedFrame.cycle(self: IndexedFrame, first: number, last: number, shift: number)
	local n = last - first + 1
	shift %= n
	if shift == 0 then
		return
	end
	local tmp = buffer.create(n * 4)
	buffer.copy(tmp, 0, self.lut, first * 4, n * 4)
	for k = 0, n - 1 do
		buffer.writeu32(self.lut, (first + (k + shift) % n) * 4, buffer.readu32(tmp, k * 4))
	end
	self.allDirty = true
end

-- Drawing -------------------------------------------------------------------

function IndexedFrame.markDirty(self: IndexedFrame, x0: number, y0: number, x1: number, y1: number)
	local tx0, ty0 = math.max(0, x0 // TILE), math.max(0, y0 // TILE)
	local tx1, ty1 = math.min(self.tw - 1, x1 // TILE), math.min(self.th - 1, y1 // TILE)
	local d, tw = self.dirty, self.tw
	for ty = ty0, ty1 do
		for tx = tx0, tx1 do
			buffer.writeu8(d, ty * tw + tx, 1)
		end
	end
end

function IndexedFrame.set(self: IndexedFrame, x: number, y: number, c: number)
	if x < 0 or y < 0 or x >= self.w or y >= self.h then
		return
	end
	local o = y * self.w + x
	if buffer.readu8(self.idx, o) ~= c then
		buffer.writeu8(self.idx, o, c)
		buffer.writeu8(self.dirty, (y // TILE) * self.tw + x // TILE, 1)
	end
end

function IndexedFrame.get(self: IndexedFrame, x: number, y: number): number
	return buffer.readu8(self.idx, y * self.w + x)
end

function IndexedFrame.fill(self: IndexedFrame, c: number)
	buffer.fill(self.idx, 0, c)
	self.allDirty = true
end

function IndexedFrame.rect(self: IndexedFrame, x: number, y: number, w: number, h: number, c: number)
	local x0, y0 = math.max(0, x), math.max(0, y)
	local x1, y1 = math.min(self.w, x + w) - 1, math.min(self.h, y + h) - 1
	if x1 < x0 or y1 < y0 then
		return
	end
	for yy = y0, y1 do
		buffer.fill(self.idx, yy * self.w + x0, c, x1 - x0 + 1)
	end
	self:markDirty(x0, y0, x1, y1)
end

-- Expansion -------------------------------------------------------------------

local function expandTile(self: IndexedFrame, tx: number, ty: number)
	local w, idx, rgba, lut = self.w, self.idx, self.rgba, self.lut
	local x0, y0 = tx * TILE, ty * TILE
	local x1, y1 = math.min(self.w, x0 + TILE) - 1, math.min(self.h, y0 + TILE) - 1
	for y = y0, y1 do
		local row = y * w
		for x = x0, x1 do
			local o = row + x
			buffer.writeu32(rgba, o * 4, buffer.readu32(lut, buffer.readu8(idx, o) * 4))
		end
	end
end

-- Expand every dirty tile into the RGBA buffer. Returns the dirty bounds in pixels (or nil if clean).
function IndexedFrame.resolve(self: IndexedFrame): (number?, number?, number?, number?)
	local tw, th, d = self.tw, self.th, self.dirty
	if self.allDirty then
		local n, idx, rgba, lut = self.w * self.h, self.idx, self.rgba, self.lut
		for o = 0, n - 1 do
			buffer.writeu32(rgba, o * 4, buffer.readu32(lut, buffer.readu8(idx, o) * 4))
		end
		buffer.fill(d, 0, 0)
		self.allDirty = false
		return 0, 0, self.w, self.h
	end
	local minx, miny, maxx, maxy = tw, th, -1, -1
	for ty = 0, th - 1 do
		for tx = 0, tw - 1 do
			if buffer.readu8(d, ty * tw + tx) ~= 0 then
				expandTile(self, tx, ty)
				if tx < minx then minx = tx end
				if ty < miny then miny = ty end
				if tx > maxx then maxx = tx end
				if ty > maxy then maxy = ty end
			end
		end
	end
	if maxx < 0 then
		return nil, nil, nil, nil
	end
	buffer.fill(d, 0, 0)
	local px, py = minx * TILE, miny * TILE
	return px, py, math.min(self.w, (maxx + 1) * TILE) - px, math.min(self.h, (maxy + 1) * TILE) - py
end

-- Copy a sub-rectangle of the RGBA buffer into a tightly packed buffer (what WritePixelsBuffer wants).
function IndexedFrame.packRegion(self: IndexedFrame, x: number, y: number, w: number, h: number): buffer
	if x == 0 and y == 0 and w == self.w and h == self.h then
		return self.rgba
	end
	-- WritePixelsBuffer wants an exact-size buffer; reuse the last one when the region size repeats.
	local need = w * h * 4
	local stage = self.stage
	if stage == nil or buffer.len(stage) ~= need then
		stage = buffer.create(need)
		self.stage = stage
	end
	local s = stage :: buffer
	for row = 0, h - 1 do
		buffer.copy(s, row * w * 4, self.rgba, ((y + row) * self.w + x) * 4, w * 4)
	end
	return s
end

-- Roblox only: push dirty pixels to an EditableImage of the same size. Returns true if anything was sent.
function IndexedFrame.present(self: IndexedFrame, img: any): boolean
	local x, y, w, h = self:resolve()
	if x == nil then
		return false
	end
	local rx, ry, rw, rh = x :: number, y :: number, w :: number, h :: number
	img:WritePixelsBuffer(Vector2.new(rx, ry), Vector2.new(rw, rh), self:packRegion(rx, ry, rw, rh))
	return true
end

return IndexedFrame
