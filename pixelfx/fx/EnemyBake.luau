--!native
--!optimize 2
-- Bakes one static enemy PNG into an animated sprite sheet at load time, so the per-frame cost
-- in play is a frame lookup. Per frame:
--   * row-sine walk deform: each pixel row shifts sideways by sin(phase) * (1 - row/height),
--     so the feet stay planted and the head sways (more organic than scaling the whole image);
--   * squash and stretch on the step beat, anchored at the feet;
--   * rim light: a JumpFlood-style distance-to-edge test brightens the edge that faces "up-left"
--     (the shading is baked in; the left/right flip at runtime mirrors it);
--   * plus a white hit-flash frame.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}

-- src: Canvas holding the PNG pixels (RGBA, straight alpha). Returns { frames = {Canvas}, flash = Canvas, w, h }.
function M.bake(src, opts: any?)
	opts = opts or {}
	local n = opts.frames or 8
	local sway = opts.sway or 1.5 -- px at the top row
	local squash = opts.squash or 0.08
	local rim = opts.rim or 0.35
	local pad = math.ceil(sway) + 1
	local W, H = src.w + pad * 2, math.ceil(src.h * (1 + squash)) + 1
	local frames = {}
	-- edge mask: an opaque pixel next to a transparent pixel up or to the left = rim pixel
	local function alphaAt(x, y)
		if x < 0 or y < 0 or x >= src.w or y >= src.h then return 0 end
		return buffer.readu8(src.buf, (y * src.w + x) * 4 + 3)
	end
	for f = 0, n - 1 do
		local ph = f / n * math.pi * 2
		local c = Core.canvas(W, H)
		local sy = 1 - squash * math.max(0, math.cos(ph * 2)) -- two steps per cycle
		local sx = 1 / sy
		local outH = src.h * sy
		for y = 0, H - 1 do
			-- map the output row back to a source row, anchored at the feet (the bottom row)
			local fromBottom = (H - 1 - y) / sy
			local syy = src.h - 1 - math.floor(fromBottom)
			if syy >= 0 and syy < src.h and (H - 1 - y) < outH + 1 then
				local hgt = 1 - syy / src.h
				local shift = math.sin(ph) * sway * hgt
				for x = 0, W - 1 do
					local cx = (x - pad - shift - src.w / 2) / sx + src.w / 2
					local sxx = math.floor(cx + 0.5)
					local a = alphaAt(sxx, syy)
					if a > 0 then
						local o = (syy * src.w + sxx) * 4
						local r, g, b = buffer.readu8(src.buf, o), buffer.readu8(src.buf, o + 1), buffer.readu8(src.buf, o + 2)
						if alphaAt(sxx - 1, syy) == 0 or alphaAt(sxx, syy - 1) == 0 then
							r = math.min(255, r + (255 - r) * rim); g = math.min(255, g + (255 - g) * rim); b = math.min(255, b + (255 - b) * rim)
						end
						Core.set(c, x, y, math.floor(r), math.floor(g), math.floor(b), a)
					end
				end
			end
		end
		frames[f + 1] = c
	end
	local flash = Core.canvas(W, H)
	local f0 = frames[1]
	for i = 0, W * H - 1 do
		local a = buffer.readu8(f0.buf, i * 4 + 3)
		if a > 0 then buffer.writeu32(flash.buf, i * 4, bit32.bor(0xFFFFFF, bit32.lshift(a, 24))) end
	end
	return { frames = frames, flash = flash, w = W, h = H }
end

return M
