-- Placeholder physics: rigid circles (Verlet) in a trapezoid-ish cup.
-- Swap this for your jelly sim by implementing the same adapter functions.

local Config = require(script.Parent.Config)

local SimpleSim = {}
SimpleSim.__index = SimpleSim

export type Ball = { pos: Vector2, prev: Vector2, r: number, tier: number }

function SimpleSim.new(cupWidth: number, cupHeight: number)
	local self = setmetatable({}, SimpleSim)
	self.w, self.h = cupWidth, cupHeight -- cup spans x in [-w/2, w/2], y in [0, h]
	self.balls = {} :: { [Ball]: boolean }
	self.gravity = Vector2.new(0, -60)
	self.substeps = 4
	return self
end

function SimpleSim:spawnBall(tier: number, position: Vector2): Ball
	local b = { pos = position, prev = position, r = Config.Tiers[tier].radius, tier = tier }
	self.balls[b] = true
	return b
end

function SimpleSim:removeBall(b: Ball) self.balls[b] = nil end
function SimpleSim:getCenter(b: Ball): Vector2 return b.pos end
function SimpleSim:isOutsideCup(b: Ball): boolean
	return b.pos.Y < -5 or math.abs(b.pos.X) > self.w / 2 + 5
end

function SimpleSim:getTouchingPairs(): { { Ball } }
	local list, pairs_ = {}, {}
	for b in self.balls do table.insert(list, b) end
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if (a.pos - b.pos).Magnitude <= a.r + b.r + 0.05 then
				table.insert(pairs_, { a, b })
			end
		end
	end
	return pairs_
end

function SimpleSim:Step(dt: number)
	dt = math.min(dt, 1 / 30)
	local h = dt / self.substeps
	local list = {}
	for b in self.balls do table.insert(list, b) end
	for _ = 1, self.substeps do
		for _, b in list do
			local vel = (b.pos - b.prev) * 0.995
			b.prev = b.pos
			b.pos += vel + self.gravity * h * h
		end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local d = b.pos - a.pos
				local dist, minD = d.Magnitude, a.r + b.r
				if dist < minD and dist > 1e-6 then
					local n = d / dist
					local push = (minD - dist)
					local ma, mb = a.r * a.r, b.r * b.r
					a.pos -= n * push * mb / (ma + mb)
					b.pos += n * push * ma / (ma + mb)
				end
			end
		end
		local half = self.w / 2
		for _, b in list do
			if b.pos.Y - b.r < 0 then b.pos = Vector2.new(b.pos.X, b.r) end
			if b.pos.X - b.r < -half then b.pos = Vector2.new(-half + b.r, b.pos.Y) end
			if b.pos.X + b.r > half then b.pos = Vector2.new(half - b.r, b.pos.Y) end
		end
	end
end

-- Adapter in the shape MergeGame expects.
function SimpleSim:Adapter()
	return {
		spawnBall = function(t, p) return self:spawnBall(t, p) end,
		removeBall = function(b) self:removeBall(b) end,
		getCenter = function(b) return self:getCenter(b) end,
		getTouchingPairs = function() return self:getTouchingPairs() end,
		isOutsideCup = function(b) return self:isOutsideCup(b) end,
	}
end

return SimpleSim
