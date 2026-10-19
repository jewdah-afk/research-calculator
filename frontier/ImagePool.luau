--!optimize 2
-- EditableImage pool with a byte budget.
-- The client editable budget is device-specific, shared with EditableMesh and unpublished (community
-- reports put it near 32 MB, with late allocations failing or rendering black once it fragments).
-- So: never create/destroy per effect. Acquire from a pool keyed by size, release back, and keep our own
-- byte count under a conservative cap. If creation still returns nil, evict idle images and retry once.
--
-- `create(w, h)` and `destroy(img)` are injected so this runs headless. In Roblox:
--   create = function(w, h) return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) }) end
--   destroy = function(img) img:Destroy() end

local ImagePool = {}
ImagePool.__index = ImagePool

export type ImagePool = typeof(setmetatable(
	{} :: {
		create: (number, number) -> any?,
		destroy: (any) -> (),
		budget: number,
		used: number,
		idle: { [number]: { any } }, -- key = w * 65536 + h
		sizes: { [any]: number },
		idleOrder: { any },
		stats: { created: number, reused: number, evicted: number, failed: number },
	},
	ImagePool
))

local function key(w: number, h: number): number
	return w * 65536 + h
end

function ImagePool.new(create: (number, number) -> any?, destroy: (any) -> (), budgetBytes: number?): ImagePool
	return setmetatable({
		create = create,
		destroy = destroy,
		budget = budgetBytes or 24 * 1024 * 1024,
		used = 0,
		idle = {},
		sizes = {},
		idleOrder = {},
		stats = { created = 0, reused = 0, evicted = 0, failed = 0 },
	}, ImagePool)
end

local function evictOne(self: ImagePool): boolean
	local img = table.remove(self.idleOrder, 1)
	if img == nil then
		return false
	end
	local k = self.sizes[img]
	local list = self.idle[k]
	local i = table.find(list, img)
	if i then
		table.remove(list, i)
	end
	self.sizes[img] = nil
	local w, h = k // 65536, k % 65536
	self.used -= w * h * 4
	self.destroy(img)
	self.stats.evicted += 1
	return true
end

-- Returns an image of exactly w×h, or nil if the budget can't fit it even after evicting idle images.
function ImagePool.acquire(self: ImagePool, w: number, h: number): any?
	local k = key(w, h)
	local list = self.idle[k]
	if list and #list > 0 then
		local img = table.remove(list)
		local i = table.find(self.idleOrder, img)
		if i then
			table.remove(self.idleOrder, i)
		end
		self.stats.reused += 1
		return img
	end
	local bytes = w * h * 4
	while self.used + bytes > self.budget do
		if not evictOne(self) then
			self.stats.failed += 1
			return nil
		end
	end
	local img = self.create(w, h)
	if img == nil and evictOne(self) then
		img = self.create(w, h) -- the engine's real budget was tighter than ours; free something and retry once
	end
	if img == nil then
		self.stats.failed += 1
		return nil
	end
	self.used += bytes
	self.sizes[img] = k
	self.stats.created += 1
	return img
end

-- Return an image for reuse. Contents are kept; overwrite before showing it again.
function ImagePool.release(self: ImagePool, img: any)
	local k = self.sizes[img]
	assert(k ~= nil, "ImagePool.release: image not from this pool")
	local list = self.idle[k]
	if list == nil then
		list = {}
		self.idle[k] = list
	end
	table.insert(list, img)
	table.insert(self.idleOrder, img)
end

return ImagePool
