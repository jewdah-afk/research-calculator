--!native
--!optimize 2
-- Noita-style falling-sand sandbox on an IndexedFrame (1 byte per cell, palette-indexed).
-- Cell byte = material * 16 + variant: the high nibble is the material, the low nibble is a
-- colour variant (sand/water/stone/wood) or remaining life (fire/smoke), so the palette shows
-- fire cooling and smoke thinning with no extra state and no RGBA work in the simulation.
-- Update: rows bottom to top, x direction alternating every step (no left/right bias); a u8
-- stamp per cell stops a particle that moved up or sideways from being updated twice.
-- Sleeping: the world is split into 64x64 chunks. Only chunks flagged awake are scanned. Any
-- cell write wakes its chunk for the next step, and also the neighbouring chunk(s) when the
-- write is within MARGIN cells of the shared border (the furthest a particle can move or look in
-- one step), so a settled world costs a few flag reads per step.
-- Water only moves sideways toward a drop within DISPERSE cells, so pools settle (surface slope
-- under 1/DISPERSE) instead of jittering forever.

local IndexedFrame = require("../IndexedFrame")

local FS = {}
FS.__index = FS

local CHUNK = 64
local FALL = 3 -- cells a grain/drop can fall per step
local DISPERSE = 20 -- how far water looks sideways for somewhere lower
local MARGIN = DISPERSE + 1

FS.EMPTY = 0
FS.STONE = 1
FS.SAND = 2
FS.WATER = 3
FS.FIRE = 4
FS.SMOKE = 5
FS.WOOD = 6

local SAND, WATER, FIRE, SMOKE, WOOD = 2, 3, 4, 5, 6

export type World = typeof(setmetatable(
	{} :: {
		w: number,
		h: number,
		frame: IndexedFrame.IndexedFrame,
		idx: buffer,
		stamp: buffer,
		cw: number,
		ch: number,
		awake: buffer,
		nextAwake: buffer,
		tick: number,
		rng: number,
		ignite: number, -- % chance per step that fire lights a touching wood cell
	},
	FS
))

-- xorshift32 shared by all worlds; step() loads/stores the world's seed
local rs = 2463534242
local function rnd(): number
	rs = bit32.bxor(rs, bit32.lshift(rs, 13))
	rs = bit32.bxor(rs, bit32.rshift(rs, 17))
	rs = bit32.bxor(rs, bit32.lshift(rs, 5))
	return rs
end

local function setupPalette(f: IndexedFrame.IndexedFrame)
	f:setColor(0, 18, 20, 28)
	local function ramp(base: number, n: number, r0: number, g0: number, b0: number, r1: number, g1: number, b1: number)
		for k = 0, n - 1 do
			local t = if n > 1 then k / (n - 1) else 0
			f:setColor(base + k, math.floor(r0 + (r1 - r0) * t), math.floor(g0 + (g1 - g0) * t), math.floor(b0 + (b1 - b0) * t))
		end
	end
	ramp(16, 4, 84, 86, 96, 112, 114, 124) -- stone
	ramp(32, 4, 214, 178, 106, 238, 208, 140) -- sand
	ramp(48, 4, 34, 92, 186, 52, 118, 214) -- water
	-- fire by remaining life: embers -> orange -> yellow-white
	for k = 0, 15 do
		local t = k / 15
		f:setColor(64 + k, math.floor(120 + 135 * math.min(1, t * 1.6)), math.floor(20 + 210 * t * t), math.floor(10 + 120 * math.max(0, t - 0.7) / 0.3))
	end
	-- smoke by remaining life: fades toward the background
	for k = 0, 15 do
		local t = k / 15
		f:setColor(80 + k, math.floor(18 + 70 * t), math.floor(20 + 70 * t), math.floor(28 + 70 * t))
	end
	ramp(96, 4, 112, 72, 40, 138, 92, 54) -- wood
end

function FS.new(w: number, h: number, seed: number?): World
	local frame = IndexedFrame.new(w, h)
	setupPalette(frame)
	local cw, ch = (w + CHUNK - 1) // CHUNK, (h + CHUNK - 1) // CHUNK
	local self = setmetatable({
		w = w,
		h = h,
		frame = frame,
		idx = frame.idx,
		stamp = buffer.create(w * h),
		cw = cw,
		ch = ch,
		awake = buffer.create(cw * ch),
		nextAwake = buffer.create(cw * ch),
		tick = 0,
		rng = seed or 12345,
		ignite = 30,
	}, FS)
	buffer.fill(self.nextAwake, 0, 1)
	return self
end

-- Wake the chunk holding (x, y) for the next step, plus neighbours within MARGIN of a border,
-- and dirty the display tile.
local function touch(self: World, x: number, y: number)
	local cw, ch, na = self.cw, self.ch, self.nextAwake
	local cx, cy = x // CHUNK, y // CHUNK
	local lx, ly = x - cx * CHUNK, y - cy * CHUNK
	local x0 = if lx < MARGIN and cx > 0 then cx - 1 else cx
	local x1 = if lx >= CHUNK - MARGIN and cx < cw - 1 then cx + 1 else cx
	local y0 = if ly < MARGIN and cy > 0 then cy - 1 else cy
	local y1 = if ly >= CHUNK - MARGIN and cy < ch - 1 then cy + 1 else cy
	for yy = y0, y1 do
		for xx = x0, x1 do
			buffer.writeu8(na, yy * cw + xx, 1)
		end
	end
	local f = self.frame
	buffer.writeu8(f.dirty, (y // 16) * f.tw + x // 16, 1)
end

local function swap(self: World, i: number, j: number, tick: number)
	local idx, w = self.idx, self.w
	local a = buffer.readu8(idx, i)
	buffer.writeu8(idx, i, buffer.readu8(idx, j))
	buffer.writeu8(idx, j, a)
	buffer.writeu8(self.stamp, i, tick)
	buffer.writeu8(self.stamp, j, tick)
	touch(self, i % w, i // w)
	touch(self, j % w, j // w)
end

local function put(self: World, i: number, v: number, tick: number)
	buffer.writeu8(self.idx, i, v)
	buffer.writeu8(self.stamp, i, tick)
	touch(self, i % self.w, i // self.w)
end

-- Editing -----------------------------------------------------------------------------------------

-- Set a cell to a material (random colour variant, full life for fire/smoke).
function FS.set(self: World, x: number, y: number, mat: number)
	if x < 0 or y < 0 or x >= self.w or y >= self.h then
		return
	end
	local v = mat * 16
	if mat == FIRE or mat == SMOKE then
		v += 15
	elseif mat ~= 0 then
		v += rnd() % 4
	end
	buffer.writeu8(self.idx, y * self.w + x, v)
	touch(self, x, y)
end

function FS.get(self: World, x: number, y: number): number
	return buffer.readu8(self.idx, y * self.w + x) // 16
end

function FS.rect(self: World, x0: number, y0: number, x1: number, y1: number, mat: number)
	for y = y0, y1 do
		for x = x0, x1 do
			self:set(x, y, mat)
		end
	end
end

-- Count cells of a material (mass check).
function FS.count(self: World, mat: number): number
	local idx, n = self.idx, 0
	for i = 0, self.w * self.h - 1 do
		if buffer.readu8(idx, i) // 16 == mat then
			n += 1
		end
	end
	return n
end

function FS.awakeCount(self: World): number
	local n = 0
	for i = 0, self.cw * self.ch - 1 do
		n += buffer.readu8(self.nextAwake, i)
	end
	return n
end

-- Simulation -------------------------------------------------------------------------------------

local function updateCell(self: World, x: number, y: number, i: number, v: number, tick: number)
	local idx, w, h = self.idx, self.w, self.h
	local m = v // 16
	if m == SAND then
		local t = i
		for k = 1, FALL do
			if y + k >= h then break end
			local j = t + w
			local b = buffer.readu8(idx, j) // 16
			if b == 0 or b == SMOKE or b == FIRE then
				t = j
			else
				break
			end
		end
		if t ~= i then
			swap(self, i, t, tick)
			return
		end
		if y + 1 >= h then return end
		local below = buffer.readu8(idx, i + w) // 16
		if below == WATER then
			if rnd() % 4 ~= 0 then -- sinks a little slower than it falls
				swap(self, i, i + w, tick)
			end
			return
		end
		local d = if rnd() % 2 == 0 then -1 else 1
		for _ = 1, 2 do
			local xx = x + d
			if xx >= 0 and xx < w then
				local b = buffer.readu8(idx, i + w + d) // 16
				if b == 0 or b == WATER or b == SMOKE then
					swap(self, i, i + w + d, tick)
					return
				end
			end
			d = -d
		end
	elseif m == WATER then
		local t = i
		for k = 1, FALL do
			if y + k >= h then break end
			local j = t + w
			local b = buffer.readu8(idx, j) // 16
			if b == 0 or b == SMOKE then
				t = j
			else
				break
			end
		end
		if t ~= i then
			swap(self, i, t, tick)
			return
		end
		if y + 1 >= h then return end
		local d = if rnd() % 2 == 0 then -1 else 1
		for _ = 1, 2 do
			local xx = x + d
			if xx >= 0 and xx < w and buffer.readu8(idx, i + w + d) < 16 then
				swap(self, i, i + w + d, tick)
				return
			end
			d = -d
		end
		-- flow sideways only toward somewhere lower, so level pools come to rest
		for _ = 1, 2 do
			for k = 1, DISPERSE do
				local xx = x + d * k
				if xx < 0 or xx >= w or buffer.readu8(idx, i + d * k) >= 16 then
					break
				end
				if buffer.readu8(idx, i + d * k + w) < 16 then
					swap(self, i, i + d * k, tick)
					return
				end
			end
			d = -d
		end
	elseif m == FIRE then
		local life = v % 16
		-- doused by any touching water (the water survives)
		if (x > 0 and buffer.readu8(idx, i - 1) // 16 == WATER) or (x < w - 1 and buffer.readu8(idx, i + 1) // 16 == WATER)
			or (y > 0 and buffer.readu8(idx, i - w) // 16 == WATER) or (y < h - 1 and buffer.readu8(idx, i + w) // 16 == WATER) then
			put(self, i, SMOKE * 16 + 15, tick)
			return
		end
		-- spread to one random neighbour
		local r = rnd()
		local dir = r % 4
		local j, ok = i, false
		if dir == 0 and x > 0 then j, ok = i - 1, true
		elseif dir == 1 and x < w - 1 then j, ok = i + 1, true
		elseif dir == 2 and y > 0 then j, ok = i - w, true
		elseif dir == 3 and y < h - 1 then j, ok = i + w, true end
		if ok and buffer.readu8(idx, j) // 16 == WOOD and (r // 4) % 100 < self.ignite then
			put(self, j, FIRE * 16 + 15, tick)
		end
		if (r // 512) % 100 < 22 then
			life -= 1
			if life <= 0 then
				put(self, i, if (r // 65536) % 3 == 0 then 0 else SMOKE * 16 + 10, tick)
				return
			end
			put(self, i, FIRE * 16 + life, tick)
		end
		-- flicker upward into air, unless it is still sitting on fuel
		local onFuel = y < h - 1 and buffer.readu8(idx, i + w) // 16 == WOOD
		if y > 0 and not onFuel and (r // 131072) % 100 < 35 then
			local dx = (r // 16777216) % 3 - 1
			local xx = x + dx
			if xx >= 0 and xx < w and buffer.readu8(idx, i - w + dx) < 16 then
				swap(self, i, i - w + dx, tick)
			end
		end
	elseif m == SMOKE then
		local r = rnd()
		local life = v % 16
		if r % 100 < 5 then
			life -= 1
			if life <= 0 then
				put(self, i, 0, tick)
				return
			end
			put(self, i, SMOKE * 16 + life, tick)
		end
		if y == 0 then
			put(self, i, 0, tick) -- leaves the world
			return
		end
		local dx = (r // 128) % 3 - 1
		local xx = x + dx
		if xx >= 0 and xx < w and buffer.readu8(idx, i - w + dx) < 16 then
			swap(self, i, i - w + dx, tick)
		elseif buffer.readu8(idx, i - w) < 16 then
			swap(self, i, i - w, tick)
		end
	end
end

-- One simulation step over awake chunks.
function FS.step(self: World)
	local tick = self.tick % 255 + 1
	self.tick = tick
	self.awake, self.nextAwake = self.nextAwake, self.awake
	buffer.fill(self.nextAwake, 0, 0)
	rs = self.rng
	local w, h, idx, stamp, awake, cw = self.w, self.h, self.idx, self.stamp, self.awake, self.cw
	local leftToRight = tick % 2 == 0
	for y = h - 1, 0, -1 do
		local rowBase = (y // CHUNK) * cw
		for c = 0, cw - 1 do
			local ci = if leftToRight then c else cw - 1 - c
			if buffer.readu8(awake, rowBase + ci) ~= 0 then
				local x0 = ci * CHUNK
				local x1 = math.min(w, x0 + CHUNK) - 1
				local xs, xe, xd = x0, x1, 1
				if not leftToRight then
					xs, xe, xd = x1, x0, -1
				end
				local row = y * w
				for x = xs, xe, xd do
					local i = row + x
					local v = buffer.readu8(idx, i)
					-- only sand, water, fire, smoke (32..95) ever move
					if v >= 32 and v < 96 and buffer.readu8(stamp, i) ~= tick then
						updateCell(self, x, y, i, v, tick)
					end
				end
			end
		end
	end
	self.rng = rs
end

-- Expand to RGBA (dirty tiles only). Returns the IndexedFrame's RGBA buffer.
function FS.render(self: World): buffer
	self.frame:resolve()
	return self.frame.rgba
end

-- Roblox only ------------------------------------------------------------------------------------
function FS.present(self: World, img: any)
	self.frame:present(img)
end

return FS
