local Out = require("./Out")
local IndexedFrame = require("../IndexedFrame")

local W, H = 256, 144
local f = IndexedFrame.new(W, H)
for i = 0, 15 do
	f:setColor(i, i * 16, 255 - i * 16, 128)
end
f:setColor(255, 255, 255, 255)

-- Full resolve on first frame.
f:fill(0)
local x, y, w, h = f:resolve()
Out.check("indexed.full_first", x == 0 and y == 0 and w == W and h == H, `{x},{y},{w},{h}`)

-- Clean frame: nothing to send.
x = f:resolve()
Out.check("indexed.clean", x == nil)

-- One pixel dirties exactly one tile.
f:set(40, 20, 255)
x, y, w, h = f:resolve()
Out.check("indexed.one_tile", x == 32 and y == 16 and w == 16 and h == 16, `{x},{y},{w},{h}`)
Out.check("indexed.pixel_value", buffer.readu32(f.rgba, (20 * W + 40) * 4) == f:getColor(255))

-- Setting the same value does not dirty.
f:set(40, 20, 255)
Out.check("indexed.same_value_clean", f:resolve() == nil)

-- Dirty bounds clamp to the frame edge (H = 144 is a multiple of 16, W too; use a ragged frame).
local g = IndexedFrame.new(37, 21)
g:resolve()
g:set(36, 20, 1)
x, y, w, h = g:resolve()
Out.check("indexed.edge_clamp", x == 32 and y == 16 and w == 5 and h == 5, `{x},{y},{w},{h}`)

-- packRegion returns tightly packed rows.
g:setColor(1, 9, 8, 7)
g:resolve()
local p = g:packRegion(32, 16, 5, 5)
Out.check("indexed.pack_len", buffer.len(p) == 100)
Out.check("indexed.pack_value", buffer.readu32(p, (4 * 5 + 4) * 4) == g:getColor(1))

-- Cycling rotates entries.
local before = f:getColor(0)
f:cycle(0, 15, 1)
Out.check("indexed.cycle", f:getColor(1) == before)

-- Picture: gradient bands + cycling stripes.
for yy = 0, H - 1 do
	for xx = 0, W - 1 do
		f:set(xx, yy, (xx // 8 + yy // 8) % 16)
	end
end
f:resolve()
Out.image("indexed_bands", W, H, f.rgba)

Out.time("indexed.resolve_full_256x144", 50, function()
	f.allDirty = true
	f:resolve()
end)
Out.time("indexed.cycle+resolve_256x144", 50, function()
	f:cycle(0, 15, 1)
	f:resolve()
end)
Out.time("indexed.resolve_8_tiles", 200, function()
	for k = 0, 7 do
		f:set(k * 20, 50, k)
		f:set(k * 20, 50, k + 1)
	end
	f:resolve()
end)
Out.done()
