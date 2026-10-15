--!native
--!optimize 2
-- Bright-pass + three box blurs ≈ Gaussian (Wells 1986 / central limit), at half res, added
-- back. Box blur uses running sums so cost is O(n) independent of radius. VS use: crits,
-- evolved projectiles, chest light column, Pentagram flash (respect Flashing VFX setting).
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}

local function boxH(src, dst, w, h, r)
	local inv = 1 / (2 * r + 1)
	for y = 0, h - 1 do
		local row = y * w
		for ch = 0, 2 do
			local acc = 0
			for k = -r, r do acc += buffer.readf32(src, ((row + math.clamp(k, 0, w - 1)) * 3 + ch) * 4) end
			for x = 0, w - 1 do
				buffer.writef32(dst, ((row + x) * 3 + ch) * 4, acc * inv)
				local add = math.min(x + r + 1, w - 1)
				local sub = math.max(x - r, 0)
				acc += buffer.readf32(src, ((row + add) * 3 + ch) * 4) - buffer.readf32(src, ((row + sub) * 3 + ch) * 4)
			end
		end
	end
end

local function transpose(src, dst, w, h)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			for ch = 0, 2 do
				buffer.writef32(dst, ((x * h + y) * 3 + ch) * 4, buffer.readf32(src, ((y * w + x) * 3 + ch) * 4))
			end
		end
	end
end

-- In place on canvas c. threshold 0..255, radius in half-res pixels, intensity 0..2.
function M.apply(c, threshold: number?, radius: number?, intensity: number?)
	threshold, radius, intensity = threshold or 180, radius or 3, intensity or 0.9
	local hw, hh = c.w // 2, c.h // 2
	local a, b = buffer.create(hw * hh * 12), buffer.create(hw * hh * 12)
	for y = 0, hh - 1 do
		for x = 0, hw - 1 do
			for ch = 0, 2 do
				local s = 0
				for dy = 0, 1 do for dx = 0, 1 do
					s += buffer.readu8(c.buf, (((y * 2 + dy) * c.w + x * 2 + dx) * 4) + ch)
				end end
				buffer.writef32(a, ((y * hw + x) * 3 + ch) * 4, math.max(0, s * 0.25 - threshold))
			end
		end
	end
	local w, h = hw, hh
	for _ = 1, 3 do boxH(a, b, w, h, radius); a, b = b, a end
	transpose(a, b, w, h); a, b = b, a; w, h = h, w
	for _ = 1, 3 do boxH(a, b, w, h, radius); a, b = b, a end
	transpose(a, b, w, h); a = b; w, h = h, w
	for y = 0, c.h - 1 do
		for x = 0, c.w - 1 do
			local hx, hy = math.min(x // 2, hw - 1), math.min(y // 2, hh - 1)
			local i = (hy * hw + hx) * 3
			Core.add(c, x, y, math.floor(buffer.readf32(a, i * 4) * intensity),
				math.floor(buffer.readf32(a, (i + 1) * 4) * intensity),
				math.floor(buffer.readf32(a, (i + 2) * 4) * intensity))
		end
	end
end

return M
