--!native
--!optimize 2
-- Cellular-automaton cave (4-5 rule) seeded by a hash of the chunk coordinate, so an
-- infinite map is generated chunk by chunk and every chunk is identical on revisit and on
-- every client. Marching-squares autotile index (0..15) is computed per cell for edge tiles.
-- VS use: scatter of rocks/grass clumps/ruins over the repeating stage chunk; Bone Zone /
-- Mad Forest dense-undergrowth masks; never blocks movement in 1:1 mode (decor only).
local M = {}

local function hash(x: number, y: number, seed: number): number
	local h = bit32.bxor(x * 374761393, y * 668265263, seed * 2246822519)
	h = bit32.bxor(h, bit32.rshift(h, 13)) * 1274126177
	return bit32.band(bit32.bxor(h, bit32.rshift(h, 16)), 0xFFFFFF) / 0x1000000
end
M.hash = hash

-- Returns cells (u8 w*h, 1=solid) and tiles (u8 marching-squares index per cell).
function M.chunk(cx: number, cy: number, w: number, h: number, opts: any?)
	opts = opts or {}
	local fill, seed, gens = opts.fill or 0.45, opts.seed or 1, opts.generations or 5
	local a, b = buffer.create(w * h), buffer.create(w * h)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			-- world coords so chunk borders agree with neighbours
			local v = hash(cx * w + x, cy * h + y, seed) < fill
			buffer.writeu8(a, y * w + x, if v then 1 else 0)
		end
	end
	local function at(buf, x, y)
		if x < 0 or y < 0 or x >= w or y >= h then
			return if hash(cx * w + x, cy * h + y, seed) < fill then 1 else 0
		end
		return buffer.readu8(buf, y * w + x)
	end
	for _ = 1, gens do
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local n = 0
				for dy = -1, 1 do for dx = -1, 1 do
					if dx ~= 0 or dy ~= 0 then n += at(a, x + dx, y + dy) end
				end end
				local s = buffer.readu8(a, y * w + x)
				buffer.writeu8(b, y * w + x, if n > 4 or (s == 1 and n == 4) then 1 else 0)
			end
		end
		a, b = b, a
	end
	local tiles = buffer.create(w * h)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local idx = at(a, x, y) + at(a, x + 1, y) * 2 + at(a, x + 1, y + 1) * 4 + at(a, x, y + 1) * 8
			buffer.writeu8(tiles, y * w + x, idx)
		end
	end
	return a, tiles
end

return M
