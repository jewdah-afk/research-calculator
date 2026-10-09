--!nonstrict
-- Sparrow (Birb companion, Evolution 1+): seed feeder, resonance drain, level-ups, mitosis, rebirb, autos, and the
-- birds that collect eggs on the Park field while you are anywhere (also away from the Park). Written fresh from the
-- playtest (playtest/js/systems.js PT.feedSparrow ... PT.updateSparrows). Server only, pure Luau.
-- State: s.sparrow = { unlocked, level, xp, maxLevelReached, count, prestigeCount, resonanceXP, totalEnergyDrained,
-- feedRatePercent, feeding, draining, autoMitosis, autoRebirb } (Birb's sparrow* fields, see Game.migrate).
local function shared(name)
	if script then return require(game:GetService("ReplicatedStorage"):WaitForChild("Peckwood"):WaitForChild("Birb"):WaitForChild(name)) end
	return nil
end
local R = (shared("Rules") or require("../../shared/Birb/Rules")) :: any
local Park = (if script then require(script.Parent.Park) else require("./Park")) :: any
local EN = R.EN
local SP = R.SP

local Sparrow = {}

-- Birb fz: feed a % of seed income, capped at 25% of the current level's XP per second
function Sparrow.feed(s, rt, dt)
	local sp = s.sparrow
	if not sp.feeding then return end
	if not R.hasSun(s, "d_seed_feeder") or sp.draining then sp.feeding = false; return end
	local seeds = EN.toNumber(R.res(s, "sunflowerSeeds"))
	if seeds <= 0 then return end
	local rate = math.max(0, rt.rates.sunflowerSeeds or 0)
	if rate <= 0 then return end
	local pct = math.max(1, math.min(100, math.floor(R.orv(sp.feedRatePercent, 25)))) / 100
	local xpPer = R.seedFeedXp(s)
	local cap = (0.25 * R.sparrowXpNeeded(sp.level)) / xpPer
	local i = math.min(rate * pct, cap * pct)
	local per = R.seedCostPerUnit(s)
	local o = math.min(i * dt, seeds / per, cap * dt)
	if o > 0 then
		R.sub(s, "sunflowerSeeds", o * per)
		sp.xp += o * xpPer
	end
end
-- resonance drain (d_sparrow_drain_power, Evolution 2+): levels flow back into resonance XP
function Sparrow.drain(s, dt)
	local sp = s.sparrow
	if not (sp.draining and R.sparrowFeaturesOn(s) and R.hasSun(s, "d_sparrow_drain_power")) then return end
	local before = R.sparrowTotalXp(sp.level, sp.xp)
	local r = R.sparrowXpNeeded(sp.level) * math.max(2, 0.1 * sp.level) * dt
	local take = math.min(sp.xp, r)
	sp.xp -= take; r -= take
	while r > 1e-10 and sp.level > 1 do
		sp.level -= 1
		local need = R.sparrowXpNeeded(sp.level)
		local t = math.min(r, need)
		sp.xp = need - t; r -= t
	end
	local drained = math.max(0, before - R.sparrowTotalXp(sp.level, sp.xp)) * R.milestoneMult(s, "drained_xp_mult")
	sp.resonanceXP = (sp.resonanceXP or 0) + drained
	sp.totalEnergyDrained = (sp.totalEnergyDrained or 0) + drained
end
function Sparrow.levelUps(s)
	local sp = s.sparrow
	local need = R.sparrowXpNeeded(sp.level)
	while sp.xp >= need do
		sp.xp -= need; sp.level += 1
		need = R.sparrowXpNeeded(sp.level)
	end
	sp.maxLevelReached = math.max(sp.maxLevelReached or 1, sp.level)
end
-- Birb sz: mitosis doubles the flock and resets the level to 0
function Sparrow.mitosis(s): boolean
	local sp = s.sparrow
	local t = math.max(1, math.floor(R.orv(sp.count, 1)))
	if not R.hasSun(s, "d_sparrow_mitosis") or t >= SP.full then return false end
	if R.sparrowTotalXp(sp.level, sp.xp) < R.mitosisNeed(s, t) then return false end
	sp.count = math.min(SP.full, 2 * t); sp.level = 0; sp.xp = 0; sp.draining = false
	return true
end
-- Birb oz: rebirb at 16 sparrows, also needs the nest's first tier
function Sparrow.rebirb(s): boolean
	local sp = s.sparrow
	local n = math.max(1, math.floor(R.orv(sp.count, 1)))
	if not R.sparrowRebirbReady(s) or n < SP.full then return false end
	if R.sparrowTotalXp(sp.level, sp.xp) < R.mitosisNeed(s, n) then return false end
	sp.count = 1; sp.prestigeCount = (sp.prestigeCount or 0) + 1; sp.level = 1; sp.xp = 0; sp.draining = false
	return true
end
function Sparrow.auto(s)
	if not R.hasSun(s, "d_sparrow_mitosis") then return end
	local sp = s.sparrow
	if sp.autoRebirb and R.sparrowAutoUnlocked(s, "rebirb") then Sparrow.rebirb(s) end
	if sp.autoMitosis and R.sparrowAutoUnlocked(s, "mitosis") then Sparrow.mitosis(s) end
end

-- Birb updateSparrow: the birds hunt eggs on the Park field, anchored on the bird (or where it left the Park).
-- Fixed 16 ms sub-steps (max 30 per call), nearest unclaimed egg, peck delay from the flight speed.
local H = 0.016
function Sparrow.update(s, rt, dt)
	local sp = s.sparrow
	if not sp.unlocked then table.clear(rt.sparrows); return end
	if rt.map == 0 then
		local a = rt.anchor
		if not a then a = { x = 0, y = 0 }; rt.anchor = a end
		a.x, a.y = rt.player.x, rt.player.y
	end
	Sparrow.feed(s, rt, dt)
	Sparrow.drain(s, dt)
	Sparrow.levelUps(s)
	Sparrow.auto(s)
	local birds = rt.sparrows
	local n = R.orv(sp.count, 1)
	local A = rt.anchor or rt.defaultAnchor
	while #birds < n do
		table.insert(birds, { x = A.x - 30 - 20 * #birds, y = A.y - 60, target = nil, timer = 0, state = "idle", face = 1, ix = 0, iy = 0, idleT = nil })
	end
	while #birds > n do table.remove(birds) end
	local acc = (rt.sparrowAcc or 0) + dt
	local steps = math.floor((acc + 1e-10) / H)
	rt.sparrowAcc = math.max(0, acc - steps * H)
	if steps <= 0 then return end
	local field = Park.list(rt, 0)
	local byId = rt.field.byId
	local c = R.sparrowSpeed(s)
	local claimed = rt.claimed
	table.clear(claimed)
	for _, b in birds do
		if b.target ~= nil and b.target ~= -1 and byId[b.target] then claimed[b.target] = true
		elseif b.target ~= -1 then b.target = nil end
	end
	local peckDelay = math.max(0.01, (200 / math.max(c, 200)) * 0.2)
	for _ = 1, math.min(steps, 30) do
		for _, b in birds do
			if b.target == nil or b.target == -1 then
				local best, id = math.huge, nil
				for _, p in field do
					if not claimed[p.id] then
						local dx, dy = p.x - b.x, p.y - b.y
						local d = dx * dx + dy * dy
						if d < best then best = d; id = p.id end
					end
				end
				if id ~= nil then b.target = id; claimed[id] = true
				elseif b.target == nil then b.target = -1 end
			end
			local tx, ty
			if b.target == -1 then
				if b.idleT and b.idleT > 0 then
					tx, ty = b.ix, b.iy; b.idleT -= H
				else
					local an = rt.rng.sparrow() * math.pi * 2
					local r = 100 + 150 * rt.rng.sparrow()
					b.ix = A.x + math.cos(an) * r; b.iy = A.y + math.sin(an) * r
					b.idleT = 1 + 2 * rt.rng.sparrow()
					tx, ty = b.ix, b.iy
				end
			else
				local p = byId[b.target]
				if p then tx, ty = p.x, p.y else b.target = nil; tx, ty = A.x, A.y - 60 end
			end
			local dx, dy = tx - b.x, ty - b.y
			local d = Park.hypot(dx, dy)
			if math.abs(dx) > 2 then b.face = if dx > 0 then 1 else -1 end
			local step = c * H
			local collect = false
			if d > math.max(5, math.min(0.5 * step, 50)) then
				b.state = "fly"
				if step >= d then
					b.x, b.y = tx, ty
					if b.target ~= -1 and b.target ~= nil then b.state = "peck"; collect = true end
				else
					b.x += (dx / d) * step; b.y += (dy / d) * step
				end
			elseif b.target ~= -1 then
				b.state = "peck"; b.timer += H
				if b.timer > peckDelay then collect = true end
			else
				b.state = "idle"
				if #field > #birds then b.target = nil end
			end
			if collect then
				local p = Park.take(rt, 0, b.target)
				if p then Park.award(s, rt, p, "sparrow") end
				b.target = nil; b.timer = 0
			end
		end
	end
end

return Sparrow
