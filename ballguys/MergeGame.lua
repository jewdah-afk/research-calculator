-- Game layer for the merge mode: queue, drops, merges, combos, score,
-- danger line, abilities. It does NOT do physics — it drives YOUR jelly sim
-- through a small adapter (see SimAdapter below).
--
-- SimAdapter you provide (wrap your existing soft-body code):
--   spawnBall(tier: number, position: Vector2): any        -> returns a ball handle
--   removeBall(ball: any)
--   getCenter(ball: any): Vector2
--   getTouchingPairs(): { {any} }                          -> pairs of balls currently in contact
--   isOutsideCup(ball: any): boolean
-- Coordinates are 2D in cup space (y up). DangerY is the height of the pink line.

local Config = require(script.Parent.Config)

export type SimAdapter = {
	spawnBall: (tier: number, position: Vector2) -> any,
	removeBall: (ball: any) -> (),
	getCenter: (ball: any) -> Vector2,
	getTouchingPairs: () -> { { any } },
	isOutsideCup: (ball: any) -> boolean,
}

local MergeGame = {}
MergeGame.__index = MergeGame

local function rollTier(rng: Random): number
	local total = 0
	for _, w in Config.DropPool do total += w end
	local r = rng:NextNumber() * total
	for tier, w in Config.DropPool do
		r -= w
		if r <= 0 then return tier end
	end
	return 1
end

function MergeGame.new(sim: SimAdapter, dangerY: number, seed: number?)
	local self = setmetatable({}, MergeGame)
	self.sim = sim
	self.dangerY = dangerY
	self.rng = Random.new(seed or os.clock() * 1e6)
	self.balls = {} :: { [any]: { tier: number, droppedAt: number, dangerSince: number? } }
	self.score = 0
	self.chain = 0
	self.lastMergeAt = -math.huge
	self.lastDropAt = -math.huge
	self.current = rollTier(self.rng)
	self.next = rollTier(self.rng)
	self.charges = {}
	self.nextChargeAt = {}
	for name, a in Config.Abilities do
		self.charges[name] = a.charges
		self.nextChargeAt[name] = a.earnEveryPoints
	end
	self.over = false
	-- Hook these from UI/effects code.
	self.onMerge = Instance.new("BindableEvent")    -- (newTier, position, points, chain)
	self.onScore = Instance.new("BindableEvent")    -- (score)
	self.onQueue = Instance.new("BindableEvent")    -- (current, next)
	self.onCharges = Instance.new("BindableEvent")  -- (charges table)
	self.onGameOver = Instance.new("BindableEvent") -- (score)
	return self
end

function MergeGame:_track(ball: any, tier: number, now: number)
	self.balls[ball] = { tier = tier, droppedAt = now, dangerSince = nil }
end

-- Player releases at x (cup space). Returns false if on cooldown or game over.
function MergeGame:Drop(x: number, spawnY: number): boolean
	local now = os.clock()
	if self.over or now - self.lastDropAt < Config.DropCooldown then return false end
	self.lastDropAt = now
	local tier = self.current
	self:_track(self.sim.spawnBall(tier, Vector2.new(x, spawnY)), tier, now)
	self.current, self.next = self.next, rollTier(self.rng)
	self.onQueue:Fire(self.current, self.next)
	return true
end

function MergeGame:UseSwap(): boolean
	if self.over or self.charges.Swap <= 0 then return false end
	self.charges.Swap -= 1
	self.current, self.next = self.next, self.current
	self.onQueue:Fire(self.current, self.next)
	self.onCharges:Fire(self.charges)
	return true
end

-- Sniper: remove the tapped ball (no points).
function MergeGame:UseSniper(ball: any): boolean
	if self.over or self.charges.Sniper <= 0 or not self.balls[ball] then return false end
	self.charges.Sniper -= 1
	self.balls[ball] = nil
	self.sim.removeBall(ball)
	self.onCharges:Fire(self.charges)
	return true
end

function MergeGame:_addPoints(points: number)
	self.score += points
	for name, a in Config.Abilities do
		while self.score >= self.nextChargeAt[name] do
			self.charges[name] += 1
			self.nextChargeAt[name] += a.earnEveryPoints
			self.onCharges:Fire(self.charges)
		end
	end
	self.onScore:Fire(self.score)
end

function MergeGame:_merge(a: any, b: any, now: number)
	local tier = self.balls[a].tier
	local pa, pb = self.sim.getCenter(a), self.sim.getCenter(b)
	local mid = (pa + pb) / 2
	self.balls[a], self.balls[b] = nil, nil
	self.sim.removeBall(a)
	self.sim.removeBall(b)

	self.chain = if now - self.lastMergeAt <= Config.ComboWindow then self.chain + 1 else 1
	self.lastMergeAt = now
	local mult = math.min(1 + (self.chain - 1) * Config.ComboStep, Config.ComboMaxMultiplier)

	if tier >= Config.MaxTier then
		local pts = math.floor(Config.MaxTierClearBonus * mult)
		self:_addPoints(pts)
		self.onMerge:Fire(0, mid, pts, self.chain)
		return
	end
	local newTier = tier + 1
	local merged = self.sim.spawnBall(newTier, mid)
	self:_track(merged, newTier, now)
	self.balls[merged].droppedAt = -math.huge -- merged balls aren't immune
	local pts = math.floor(Config.Tiers[newTier].points * mult)
	self:_addPoints(pts)
	self.onMerge:Fire(newTier, mid, pts, self.chain)
end

-- Call every frame AFTER your sim steps.
function MergeGame:Step()
	if self.over then return end
	local now = os.clock()

	-- Merges: each ball merges at most once per step.
	local used = {}
	for _, pair in self.sim.getTouchingPairs() do
		local a, b = pair[1], pair[2]
		local ia, ib = self.balls[a], self.balls[b]
		if ia and ib and not used[a] and not used[b] and ia.tier == ib.tier then
			used[a], used[b] = true, true
			self:_merge(a, b, now)
		end
	end

	-- Lose checks.
	for ball, info in self.balls do
		if self.sim.isOutsideCup(ball) then return self:_end() end
		local fresh = now - info.droppedAt < Config.FreshDropImmunity
		local top = self.sim.getCenter(ball).Y + Config.Tiers[info.tier].radius
		if not fresh and top > self.dangerY then
			info.dangerSince = info.dangerSince or now
			if now - info.dangerSince >= Config.DangerGraceTime then return self:_end() end
		else
			info.dangerSince = nil
		end
	end
end

-- 0..1 for the "danger" warning effect (flash the line as it nears 1).
function MergeGame:DangerLevel(): number
	local now, worst = os.clock(), 0
	for _, info in self.balls do
		if info.dangerSince then
			worst = math.max(worst, (now - info.dangerSince) / Config.DangerGraceTime)
		end
	end
	return math.min(worst, 1)
end

function MergeGame:_end()
	self.over = true
	self.onGameOver:Fire(self.score)
end

return MergeGame
