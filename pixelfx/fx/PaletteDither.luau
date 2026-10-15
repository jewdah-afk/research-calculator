--!native
--!optimize 2
-- Floyd–Steinberg error diffusion to a fixed palette in OKLab (Ottosson 2020) for perceptual
-- nearest colour, serpentine scan to avoid worms. Optional ordered Bayer 4x4 mode for stable
-- animation (FS shimmers frame to frame). VS use: portrait/Arcana card filter, snapping any
-- procedural output to the stage palette so effects never break the pixel-art look.
local M = {}

local function lin(c) c /= 255; return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4 end
local function oklab(r, g, b)
	r, g, b = lin(r), lin(g), lin(b)
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
	return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end
M.oklab = oklab

local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }

-- palette: { {r,g,b}, ... }; mode "fs" | "bayer"; strength scales the dither (0..1).
function M.apply(c, palette, mode: string?, strength: number?)
	strength = strength or 1
	local labs = {}
	for i, p in palette do labs[i] = { oklab(p[1], p[2], p[3]) } end
	local function nearest(r, g, b)
		local L, A, B = oklab(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
		local bi, bd = 1, math.huge
		for i, q in labs do
			local d = (L - q[1]) ^ 2 + (A - q[2]) ^ 2 + (B - q[3]) ^ 2
			if d < bd then bd, bi = d, i end
		end
		return palette[bi]
	end
	local w, h, buf = c.w, c.h, c.buf
	if mode == "bayer" then
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local o = (y * w + x) * 4
				local t = (BAYER[(y % 4) * 4 + x % 4 + 1] / 16 - 0.5) * 48 * strength
				local p = nearest(buffer.readu8(buf, o) + t, buffer.readu8(buf, o + 1) + t, buffer.readu8(buf, o + 2) + t)
				buffer.writeu8(buf, o, p[1]); buffer.writeu8(buf, o + 1, p[2]); buffer.writeu8(buf, o + 2, p[3])
			end
		end
		return
	end
	local err = buffer.create(w * h * 12)
	local function addErr(x, y, er, eg, eb, k)
		if x < 0 or x >= w or y >= h then return end
		local i = (y * w + x) * 12
		buffer.writef32(err, i, buffer.readf32(err, i) + er * k)
		buffer.writef32(err, i + 4, buffer.readf32(err, i + 4) + eg * k)
		buffer.writef32(err, i + 8, buffer.readf32(err, i + 8) + eb * k)
	end
	for y = 0, h - 1 do
		local dir = if y % 2 == 0 then 1 else -1
		local x0, x1 = if dir == 1 then 0 else w - 1, if dir == 1 then w - 1 else 0
		for x = x0, x1, dir do
			local o, i = (y * w + x) * 4, (y * w + x) * 12
			local r = buffer.readu8(buf, o) + buffer.readf32(err, i)
			local g = buffer.readu8(buf, o + 1) + buffer.readf32(err, i + 4)
			local b = buffer.readu8(buf, o + 2) + buffer.readf32(err, i + 8)
			local p = nearest(r, g, b)
			buffer.writeu8(buf, o, p[1]); buffer.writeu8(buf, o + 1, p[2]); buffer.writeu8(buf, o + 2, p[3])
			local er, eg, eb = (r - p[1]) * strength, (g - p[2]) * strength, (b - p[3]) * strength
			addErr(x + dir, y, er, eg, eb, 7 / 16)
			addErr(x - dir, y + 1, er, eg, eb, 3 / 16)
			addErr(x, y + 1, er, eg, eb, 5 / 16)
			addErr(x + dir, y + 1, er, eg, eb, 1 / 16)
		end
	end
end

return M
