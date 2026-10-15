--!native
--!optimize 2
-- Physarum polycephalum transport network (Jones 2010). Agents sense trail ahead-left/ahead/
-- ahead-right, turn toward the strongest, move, deposit; the trail diffuses and decays.
-- VS use: Corruption spread, Mudman sludge, Curse aura, La Borra pools seen from above.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

function M.new(w: number, h: number, opts: any?)
	opts = opts or {}
	local n = opts.agents or 1500
	local rand = Core.rng(opts.seed or 3)
	local ax, ay, ah = buffer.create(n * 4), buffer.create(n * 4), buffer.create(n * 4)
	for i = 0, n - 1 do
		local a, r = rand() * math.pi * 2, rand() * math.min(w, h) * 0.3
		buffer.writef32(ax, i * 4, w / 2 + math.cos(a) * r)
		buffer.writef32(ay, i * 4, h / 2 + math.sin(a) * r)
		buffer.writef32(ah, i * 4, rand() * math.pi * 2)
	end
	return setmetatable({
		w = w, h = h, n = n, ax = ax, ay = ay, ah = ah, rand = rand,
		sa = opts.sensorAngle or 0.785, sd = opts.sensorDist or 9, ra = opts.turn or 0.785,
		speed = opts.speed or 1, deposit = opts.deposit or 0.05, decay = opts.decay or 0.92,
		trail = Core.field(w, h), tmp = Core.field(w, h),
		lut = Core.ramp(opts.ramp or { {0,0,0}, {40,0,60}, {150,20,160}, {255,140,255} }),
	}, M)
end

local function sample(self, x, y)
	local w, h = self.w, self.h
	x, y = math.floor(x) % w, math.floor(y) % h
	return buffer.readf32(self.trail, (y * w + x) * 4)
end

function M:step(_dt: number)
	local w, h, sa, sd, ra = self.w, self.h, self.sa, self.sd, self.ra
	local ax, ay, ah, rand = self.ax, self.ay, self.ah, self.rand
	for i = 0, self.n - 1 do
		local o = i * 4
		local x, y, a = buffer.readf32(ax, o), buffer.readf32(ay, o), buffer.readf32(ah, o)
		local f = sample(self, x + math.cos(a) * sd, y + math.sin(a) * sd)
		local l = sample(self, x + math.cos(a - sa) * sd, y + math.sin(a - sa) * sd)
		local r = sample(self, x + math.cos(a + sa) * sd, y + math.sin(a + sa) * sd)
		if f >= l and f >= r then -- keep heading
		elseif f < l and f < r then a += if rand() < 0.5 then ra else -ra
		elseif l > r then a -= ra
		elseif r > l then a += ra end
		x = (x + math.cos(a) * self.speed) % w
		y = (y + math.sin(a) * self.speed) % h
		buffer.writef32(ax, o, x); buffer.writef32(ay, o, y); buffer.writef32(ah, o, a)
		local ti = (math.floor(y) * w + math.floor(x)) * 4
		buffer.writef32(self.trail, ti, math.min(1, buffer.readf32(self.trail, ti) + self.deposit))
	end
	-- 3x3 box diffuse + decay, toroidal.
	local src, dst, k = self.trail, self.tmp, self.decay / 9
	for y = 0, h - 1 do
		local ym, yp = ((y - 1) % h) * w, ((y + 1) % h) * w
		local y0 = y * w
		for x = 0, w - 1 do
			local xm, xp = (x - 1) % w, (x + 1) % w
			local s = 0
			for _, row in { ym, y0, yp } do
				s += buffer.readf32(src, (row + xm) * 4) + buffer.readf32(src, (row + x) * 4)
					+ buffer.readf32(src, (row + xp) * 4)
			end
			buffer.writef32(dst, (y0 + x) * 4, s * k)
		end
	end
	self.trail, self.tmp = dst, src
end

function M:render(c) Core.shade(c, self.trail, self.lut) end

return M
