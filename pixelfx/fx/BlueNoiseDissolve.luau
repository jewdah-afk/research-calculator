--!native
--!optimize 2
-- Void-and-cluster blue-noise threshold map (Ulichney 1993), then a dissolve that removes
-- sprite pixels in blue-noise order with a hot burning edge. VS use: enemy death, chest
-- vanish, Molt-style dust-out. Blue noise has no clumps, so it reads as an even crumble
-- at low res where white noise looks like static.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

-- Builds an n×n rank map (0..1) once; cache and reuse across all sprites.
function M.blueNoise(n: number, seed: number?): buffer
	local rand, N = Core.rng(seed or 5), n * n
	local on = buffer.create(N)
	local energy = Core.field(n, n)
	local sigma2 = 2 * 1.5 ^ 2
	local function splat(i, sgn)
		local ix, iy = i % n, i // n
		for dy = -4, 4 do
			for dx = -4, 4 do
				local j = ((iy + dy) % n) * n + (ix + dx) % n
				buffer.writef32(energy, j * 4, buffer.readf32(energy, j * 4) + sgn * math.exp(-(dx * dx + dy * dy) / sigma2))
			end
		end
	end
	local rank = Core.field(n, n)
	-- Phase 1: random 10% seeds, relaxed by moving tightest cluster to largest void.
	local ones = 0
	for i = 0, N - 1 do
		if rand() < 0.1 then buffer.writeu8(on, i, 1); splat(i, 1); ones += 1 end
	end
	local function extreme(wantOn, pickMax)
		local best, bv = -1, if pickMax then -math.huge else math.huge
		for i = 0, N - 1 do
			if (buffer.readu8(on, i) == 1) == wantOn then
				local e = buffer.readf32(energy, i * 4)
				if (pickMax and e > bv) or (not pickMax and e < bv) then bv, best = e, i end
			end
		end
		return best
	end
	for _ = 1, N do
		local c = extreme(true, true); buffer.writeu8(on, c, 0); splat(c, -1)
		local v = extreme(false, false)
		if v == c then buffer.writeu8(on, c, 1); splat(c, 1); break end
		buffer.writeu8(on, v, 1); splat(v, 1)
	end
	-- Phase 2: rank the remaining voids in order of fill; phase 1 points ranked by removal.
	local proto = buffer.create(N); buffer.copy(proto, 0, on, 0, N)
	local protoE = buffer.create(N * 4); buffer.copy(protoE, 0, energy, 0, N * 4)
	for r = ones - 1, 0, -1 do
		local c = extreme(true, true); buffer.writeu8(on, c, 0); splat(c, -1)
		buffer.writef32(rank, c * 4, r / N)
	end
	buffer.copy(on, 0, proto, 0, N); buffer.copy(energy, 0, protoE, 0, N * 4)
	for r = ones, N - 1 do
		local v = extreme(false, false); buffer.writeu8(on, v, 1); splat(v, 1)
		buffer.writef32(rank, v * 4, r / N)
	end
	return rank
end

-- sprite: Canvas with the enemy sprite; noise: from blueNoise(n)
function M.new(sprite, noise: buffer, n: number, opts: any?)
	opts = opts or {}
	return setmetatable({
		sprite = sprite, noise = noise, n = n, t = 0, dur = opts.duration or 0.45,
		edge = opts.edge or 0.06, edgeColor = opts.edgeColor or { 255, 200, 80 },
	}, M)
end

function M:step(dt: number) self.t += dt end
function M:done(): boolean return self.t >= self.dur end

function M:render(c, ox: number?, oy: number?)
	ox, oy = ox or 0, oy or 0
	local s, n, cut = self.sprite, self.n, self.t / self.dur
	local ec = self.edgeColor
	for y = 0, s.h - 1 do
		for x = 0, s.w - 1 do
			local o = (y * s.w + x) * 4
			if buffer.readu8(s.buf, o + 3) > 0 then
				local th = buffer.readf32(self.noise, ((y % n) * n + x % n) * 4)
				if th > cut + self.edge then
					Core.set(c, ox + x, oy + y, buffer.readu8(s.buf, o), buffer.readu8(s.buf, o + 1), buffer.readu8(s.buf, o + 2), 255)
				elseif th > cut then
					Core.set(c, ox + x, oy + y, ec[1], ec[2], ec[3], 255)
				end
			end
		end
	end
end

return M
