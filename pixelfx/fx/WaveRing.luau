--!native
--!optimize 2
-- 2D damped wave equation (leapfrog, 5-point Laplacian) for the Garlic / Soul Eater pulse.
-- Each pulse injects a ring impulse; interference with earlier rings gives the shimmering
-- edge. Height is shaded through a ramp; slope adds a fake specular rim.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

function M.new(w: number, h: number, opts: any?)
	opts = opts or {}
	return setmetatable({
		w = w, h = h, c2 = (opts.speed or 0.45) ^ 2, damp = opts.damping or 0.985,
		u = Core.field(w, h), prev = Core.field(w, h), vis = Core.field(w, h),
		lut = Core.ramp(opts.ramp or { {0,0,0}, {90,10,20}, {230,80,90}, {255,230,230} }),
	}, M)
end

function M:pulse(cx: number, cy: number, radius: number, amp: number?)
	local w, h = self.w, self.h
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) - radius
			if math.abs(d) < 2 then
				local i = (y * w + x) * 4
				buffer.writef32(self.u, i, buffer.readf32(self.u, i) + (amp or 1) * (1 - math.abs(d) / 2))
			end
		end
	end
end

function M:step(_dt: number)
	local w, h, u, p, c2, damp = self.w, self.h, self.u, self.prev, self.c2, self.damp
	for y = 1, h - 2 do
		for x = 1, w - 2 do
			local i = (y * w + x) * 4
			local v = buffer.readf32(u, i)
			local lap = buffer.readf32(u, i - 4) + buffer.readf32(u, i + 4)
				+ buffer.readf32(u, i - w * 4) + buffer.readf32(u, i + w * 4) - 4 * v
			buffer.writef32(p, i, (2 * v - buffer.readf32(p, i) + c2 * lap) * damp)
		end
	end
	self.u, self.prev = p, u
	local vis = self.vis
	for y = 1, h - 2 do
		for x = 1, w - 2 do
			local i = (y * w + x) * 4
			local gx = buffer.readf32(p, i + 4) - buffer.readf32(p, i - 4)
			local gy = buffer.readf32(p, i + w * 4) - buffer.readf32(p, i - w * 4)
			buffer.writef32(vis, i, math.abs(buffer.readf32(p, i)) * 0.8 + math.max(0, gx - gy) * 1.5)
		end
	end
end

function M:render(c) Core.shade(c, self.vis, self.lut) end

return M
