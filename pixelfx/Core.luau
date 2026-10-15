--!native
--!optimize 2
-- PixelFX core: RGBA8 canvas over a buffer, matching EditableImage:WritePixelsBuffer layout.
-- Runs headless (plain Luau) and in Roblox. Only `present` touches Roblox APIs.

local Core = {}

export type Canvas = { w: number, h: number, buf: buffer }

local floor, max, min = math.floor, math.max, math.min

function Core.canvas(w: number, h: number): Canvas
	return { w = w, h = h, buf = buffer.create(w * h * 4) }
end

function Core.clear(c: Canvas, r: number?, g: number?, b: number?, a: number?)
	local px = bit32.bor(r or 0, bit32.lshift(g or 0, 8), bit32.lshift(b or 0, 16), bit32.lshift(a or 0, 24))
	local buf = c.buf
	for i = 0, c.w * c.h - 1 do
		buffer.writeu32(buf, i * 4, px)
	end
end

function Core.set(c: Canvas, x: number, y: number, r: number, g: number, b: number, a: number?)
	if x < 0 or y < 0 or x >= c.w or y >= c.h then return end
	local o = (y * c.w + x) * 4
	local buf = c.buf
	buffer.writeu8(buf, o, r); buffer.writeu8(buf, o + 1, g)
	buffer.writeu8(buf, o + 2, b); buffer.writeu8(buf, o + 3, a or 255)
end

-- Additive blend, saturating. Roblox GUI has no additive mode, so effects add in-buffer.
-- Pixels are stored straight-alpha (as EditableImage expects): we convert to premultiplied,
-- add, then store alpha = brightest channel and un-premultiply, so glow over any background
-- looks additive instead of double-darkening.
function Core.add(c: Canvas, x: number, y: number, r: number, g: number, b: number)
	if x < 0 or y < 0 or x >= c.w or y >= c.h then return end
	local o = (y * c.w + x) * 4
	local buf = c.buf
	local a = buffer.readu8(buf, o + 3) / 255
	local pr = min(255, buffer.readu8(buf, o) * a + r)
	local pg = min(255, buffer.readu8(buf, o + 1) * a + g)
	local pb = min(255, buffer.readu8(buf, o + 2) * a + b)
	local na = max(pr, pg, pb, a * 255)
	if na <= 0 then return end
	local k = 255 / na
	buffer.writeu8(buf, o, min(255, floor(pr * k + 0.5)))
	buffer.writeu8(buf, o + 1, min(255, floor(pg * k + 0.5)))
	buffer.writeu8(buf, o + 2, min(255, floor(pb * k + 0.5)))
	buffer.writeu8(buf, o + 3, floor(na + 0.5))
end

-- Multiply alpha by k: cheap persistence trails (straight alpha, so colour is kept).
function Core.fade(c: Canvas, k: number)
	local buf = c.buf
	for o = 3, c.w * c.h * 4 - 1, 4 do
		buffer.writeu8(buf, o, floor(buffer.readu8(buf, o) * k))
	end
end

-- Palette ramp: list of {r,g,b} stops -> 256-entry lookup of packed u32 (alpha from t).
function Core.ramp(stops: { { number } }, alphaCurve: boolean?): { number }
	local lut, n = table.create(256), #stops
	for i = 0, 255 do
		local t = i / 255 * (n - 1)
		local k = min(floor(t), n - 2)
		local f = t - k
		local s0, s1 = stops[k + 1], stops[k + 2]
		local r = floor(s0[1] + (s1[1] - s0[1]) * f)
		local g = floor(s0[2] + (s1[2] - s0[2]) * f)
		local b = floor(s0[3] + (s1[3] - s0[3]) * f)
		local a = if alphaCurve then min(255, i * 3) else 255
		lut[i + 1] = bit32.bor(r, bit32.lshift(g, 8), bit32.lshift(b, 16), bit32.lshift(a, 24))
	end
	return lut
end

-- Map a float field (0..1 per cell, f32 buffer w*h) through a ramp into the canvas.
function Core.shade(c: Canvas, field: buffer, lut: { number })
	local buf = c.buf
	for i = 0, c.w * c.h - 1 do
		local v = buffer.readf32(field, i * 4)
		local idx = if v <= 0 then 0 elseif v >= 1 then 255 else floor(v * 255)
		buffer.writeu32(buf, i * 4, lut[idx + 1])
	end
end

function Core.field(w: number, h: number): buffer
	return buffer.create(w * h * 4)
end

-- Deterministic PRNG (xorshift32) so Luau output can be diffed against reference frames.
function Core.rng(seed: number)
	local s = bit32.bor(seed, 1)
	return function(): number
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		return s / 4294967296
	end
end

-- Bresenham line with additive colour.
function Core.line(c: Canvas, x0: number, y0: number, x1: number, y1: number, r: number, g: number, b: number)
	x0, y0, x1, y1 = floor(x0), floor(y0), floor(x1), floor(y1)
	local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
	local sx, sy = if x0 < x1 then 1 else -1, if y0 < y1 then 1 else -1
	local err = dx + dy
	while true do
		Core.add(c, x0, y0, r, g, b)
		if x0 == x1 and y0 == y1 then break end
		local e2 = 2 * err
		if e2 >= dy then err += dy; x0 += sx end
		if e2 <= dx then err += dx; y0 += sy end
	end
end

-- Roblox only: push the canvas into an EditableImage of the same size.
function Core.present(c: Canvas, image: any)
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(c.w, c.h), c.buf)
end

-- Headless only: PPM dump for QA diffs (alpha composited over black).
function Core.ppm(c: Canvas): string
	local parts = { `P6\n{c.w} {c.h}\n255\n` }
	local row = table.create(c.w * 3)
	for y = 0, c.h - 1 do
		for x = 0, c.w - 1 do
			local o = (y * c.w + x) * 4
			local a = buffer.readu8(c.buf, o + 3) / 255
			row[x * 3 + 1] = string.char(floor(buffer.readu8(c.buf, o) * a))
			row[x * 3 + 2] = string.char(floor(buffer.readu8(c.buf, o + 1) * a))
			row[x * 3 + 3] = string.char(floor(buffer.readu8(c.buf, o + 2) * a))
		end
		table.insert(parts, table.concat(row))
	end
	return table.concat(parts)
end

return Core
