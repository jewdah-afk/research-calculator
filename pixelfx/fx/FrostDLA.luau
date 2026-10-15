--!native
--!optimize 2
-- Diffusion-limited aggregation (Witten-Sander 1981) frost for freeze (Clock Lancet, Orologion
-- edge frost). Walkers spawn on a circle just outside the cluster and random-walk until they
-- touch it; a stickiness < 1 thickens branches. Each crystal stores its arrival order, which
-- drives a grow-in reveal and a shimmer phase.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

function M.new(w: number, h: number, opts: any?)
	opts = opts or {}
	local self = setmetatable({
		w = w, h = h, rand = Core.rng(opts.seed or 11), stick = opts.stickiness or 0.7,
		order = buffer.create(w * h * 4), count = 0, rmax = 2, t = 0,
		reveal = opts.reveal or 0.6, vis = Core.field(w, h),
		lut = Core.ramp(opts.ramp or { {0,0,0}, {20,60,120}, {120,200,255}, {240,250,255} }),
	}, M)
	local cx, cy = w // 2, h // 2
	buffer.writeu32(self.order, (cy * w + cx) * 4, 1)
	self.count, self.cx, self.cy = 1, cx, cy
	return self
end

function M:grow(particles: number)
	local w, h, rand, ord = self.w, self.h, self.rand, self.order
	local cx, cy = self.cx, self.cy
	local limit = math.min(w, h) / 2 - 2
	for _ = 1, particles do
		if self.rmax >= limit then return end
		local a = rand() * math.pi * 2
		local r0 = self.rmax + 3
		local x, y = math.floor(cx + math.cos(a) * r0), math.floor(cy + math.sin(a) * r0)
		for _ = 1, 4000 do
			local d = rand()
			if d < 0.25 then x += 1 elseif d < 0.5 then x -= 1 elseif d < 0.75 then y += 1 else y -= 1 end
			local dd = (x - cx) ^ 2 + (y - cy) ^ 2
			if dd > (self.rmax + 8) ^ 2 or x < 1 or y < 1 or x > w - 2 or y > h - 2 then break end
			local i = y * w + x
			local touch = buffer.readu32(ord, (i - 1) * 4) + buffer.readu32(ord, (i + 1) * 4)
				+ buffer.readu32(ord, (i - w) * 4) + buffer.readu32(ord, (i + w) * 4)
			if touch > 0 and rand() < self.stick then
				self.count += 1
				buffer.writeu32(ord, i * 4, self.count)
				self.rmax = math.max(self.rmax, math.sqrt(dd))
				break
			end
		end
	end
end

function M:step(dt: number)
	self.t += dt
	local w, h, ord, vis, n = self.w, self.h, self.order, self.vis, self.count
	local front = math.min(1, self.t / self.reveal) * n
	for i = 0, w * h - 1 do
		local o = buffer.readu32(ord, i * 4)
		local v = 0
		if o > 0 and o <= front then
			local young = 1 - math.min(1, (front - o) / (n * 0.15 + 1))
			v = 0.55 + 0.25 * math.sin(self.t * 6 + o * 0.37) * 0.5 + young * 0.45
		end
		buffer.writef32(vis, i * 4, v)
	end
end

function M:render(c) Core.shade(c, self.vis, self.lut) end

return M
