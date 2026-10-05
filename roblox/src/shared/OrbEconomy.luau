--!nonstrict
-- Server-authoritative game state + actions. Board physics, UI and saving are left to the
-- caller: call the hooks below from your spawn loop, collection detector and remotes.
--
--   Economy.newData(difficulty)                -> fresh save table (DataStore-safe, plain values)
--   Economy.tickSecond(data, hooks)            -> once per second (boost/weather timers)
--   Economy.tickAutomation(data, dt)           -> every frame / 0.1 s
--   Economy.rollSpawn(data, spawner, orbCount) -> what a spawner produces this cycle
--   Economy.collect(data, orb, x, y)           -> cash in an orb that hit the bottom
--   Economy.buy*/rebirth/tier/...              -> player actions, return true on success

local Config = require(script.Parent.OrbConfig)
local F = require(script.Parent.OrbFormulas)
local Big = require(script.Parent.Big)

local Economy = {}

local function copy<T>(t: T): T
	return table.clone(t :: any) :: any
end

function Economy.newData(difficulty: string?, rng: Random?)
	local r = rng or Random.new()
	local skills = {}
	for cat, def in Config.SkillTree do
		skills[cat] = table.create(#def.upgrades, 0)
	end
	local data = {
		difficulty = difficulty or "orig",
		-- Big (EternityNum) values: money, totalMoney, diamonds, totalDiamonds, moneyMultiplier, diamondLuckCost
		money = Big.new(0),
		totalMoney = Big.new(0),
		diamonds = Big.new(0),
		totalDiamonds = Big.new(0),
		moneyMultiplier = Big.new(1),
		baseLuck = 1,
		bestLuck = 1,
		diamondLuck = 1,
		diamondChance = Config.Base.DiamondChance,
		diamondLuckCost = Big.new(Config.Base.DiamondLuckCost),
		highestRarity = 0,
		orbsObtained = table.create(#Config.Rarities, 0),
		orbsSpawned = 0,

		mechanics = 0,
		rebirths = 0,
		tiers = 0,

		spawnersUnlocked = 1,
		spawnIntervals = copy(Config.Spawners.BaseInterval),
		spawnerLuck = copy(Config.Spawners.BaseLuck),
		-- levels: main = {money, luck, diamond}; per spawner {interval, luck}
		mainLevels = { 0, 0, 0 },
		intervalLevels = table.create(7, 0),
		spawnerLuckLevels = table.create(7, 0),

		boostTimes = { money = 0, luck = 0, duplicate = 0, obstacle = 0 },
		boostUses = table.create(6, 0),

		weatherPoints = 0,
		weatherUnlocked = 1,
		weatherRolled = 0,
		weatherPower = 0,
		weatherMoney = 1,
		weatherRollCooldown = 0,
		weatherDuration = table.create(#Config.Weather, 0),
		weatherCosts = {
			roll = Config.WeatherShop.RollBaseCost,
			unlock = Config.WeatherShop.UnlockBaseCost,
			money = Config.WeatherShop.MoneyBaseCost,
		},

		automationPoints = 0,
		automation = {
			levels = { 0, 0, 0, 0 },
			timers = { 0, 0 },
			enabled = { true, true },
			scales = {
				Config.Automation.ScaleMin + r:NextNumber() * Config.Automation.ScaleRange,
				Config.Automation.ScaleMin + r:NextNumber() * Config.Automation.ScaleRange,
			},
		},

		skills = skills,
		tpBought = { Money = 0, Diamonds = 0, WeatherRolls = 0, OrbsSpawned = 0 },
		qpBought = 0,

		timePlayed = 0,
		-- derived each tick, cached for UI
		totalLuck = 1,
	}
	return data
end

export type Data = typeof(Economy.newData())

---------------------------------------------------------------- derived

function Economy.refresh(data: Data)
	local luck, best = F.totalLuck(data)
	data.totalLuck = luck
	data.bestLuck = best
	-- SPW-1 auto-unlocks spawners 6 and 7
	if data.spawnersUnlocked == 5 and F.skill(data, "SPW-1") >= 1 then
		data.spawnersUnlocked = 6
	end
	if data.spawnersUnlocked == 6 and F.skill(data, "SPW-1") >= 2 then
		data.spawnersUnlocked = 7
	end
end

function Economy.points(data: Data)
	local spentTP, spentQP = F.spentPoints(data)
	local maxTP, maxQP = F.maxTP(data), F.maxQP(data)
	return { maxTP = maxTP, tp = maxTP - spentTP, maxQP = maxQP, qp = maxQP - spentQP }
end

---------------------------------------------------------------- spawning

export type Orb = { kind: "orb" | "diamond" | "weather", rarity: number?, variant: string? }

-- Returns 0..2 orbs for one spawner cycle. `orbCount` = rarity orbs currently on the board.
-- Spawner timer: wait data.spawnIntervals[spawner] ms between cycles.
function Economy.rollSpawn(data: Data, spawner: number, orbCount: number, rng: Random?): { Orb }
	local r = rng or Random.new()
	local out = {}
	if spawner > data.spawnersUnlocked then
		return out
	end
	local cap = F.spawnCap(data)
	local function one()
		if orbCount + #out >= cap then
			return
		end
		if data.mechanics >= 5 and r:NextNumber() < F.weatherOrbChance(data) then
			table.insert(out, { kind = "weather", variant = F.rollVariant(data, r:NextNumber()) })
			return
		end
		if r:NextNumber() < data.diamondChance then
			table.insert(out, { kind = "diamond", variant = F.rollVariant(data, r:NextNumber()) })
			return
		end
		Economy.refresh(data)
		local rarity = F.rollRarity(data.totalLuck * data.spawnerLuck[spawner], r:NextNumber())
		if rarity > data.highestRarity then
			data.highestRarity = rarity
		end
		data.orbsSpawned += 1
		table.insert(out, { kind = "orb", rarity = rarity, variant = F.rollVariant(data, r:NextNumber()) })
	end
	one()
	-- SPW-4 double drop
	if r:NextNumber() < F.skill(data, "SPW-4") * 0.1 then
		one()
	end
	return out
end

-- Called when an orb on the board meets F.isCollected(). Returns what was gained.
function Economy.collect(data: Data, orb: Orb, x: number, rng: Random?)
	local slot = F.slotMult(data.tiers, x)
	if orb.kind == "orb" then
		local rarity = orb.rarity :: number
		local gain = F.orbMoney(data, rarity, slot, orb.variant)
		data.money = Big.add(data.money, gain)
		data.totalMoney = Big.add(data.totalMoney, gain)
		data.orbsObtained[rarity] += 1
		if data.tiers >= 2 and (rng or Random.new()):NextNumber() < Config.Automation.PointChance then
			data.automationPoints += rarity
		end
		return { money = gain, slot = slot }
	elseif orb.kind == "diamond" then
		local gain = F.diamondGain(data, slot, orb.variant)
		data.diamonds = Big.add(data.diamonds, gain)
		data.totalDiamonds = Big.add(data.totalDiamonds, gain)
		return { diamonds = gain, slot = slot }
	else
		local gain = F.variantMult(orb.variant)
		data.weatherPoints += gain
		return { weatherPoints = gain }
	end
end

---------------------------------------------------------------- timers

-- Call once per second. `hooks.onObstacleChange()` should rebuild the board
-- (obstacle remover starts, active phase ends, or cooldown ends).
function Economy.tickSecond(data: Data, hooks: { onObstacleChange: (() -> ())? }?)
	local b = data.boostTimes
	b.money = math.max(b.money - 1, 0)
	b.luck = math.max(b.luck - 1, 0)
	b.duplicate = math.max(b.duplicate - 1, 0)
	for i = 1, #data.weatherDuration do
		data.weatherDuration[i] = math.max(data.weatherDuration[i] - 1, 0)
	end
	data.weatherRollCooldown = math.max(data.weatherRollCooldown - 1, 0)
	if b.obstacle > 0 then
		b.obstacle -= 1
		if (b.obstacle == 0 or b.obstacle == Config.Boosts[6].downtime) and hooks and hooks.onObstacleChange then
			hooks.onObstacleChange()
		end
	end
	data.timePlayed += 1
	Economy.refresh(data)
end

-- True while the obstacle-remover boost's active phase is running.
function Economy.obstaclesRemoved(data: Data): boolean
	return data.boostTimes.obstacle > Config.Boosts[6].downtime
end

function Economy.tickAutomation(data: Data, dt: number)
	local a = data.automation
	for i = 1, 2 do
		if a.levels[i] > 0 and a.enabled[i] then
			if a.timers[i] <= 0 then
				Economy.runAutomation(data, i)
				a.timers[i] = F.automationInterval(a.levels[i])
			else
				a.timers[i] -= dt
			end
		end
	end
end

---------------------------------------------------------------- main upgrades

local function payMoney(data: Data, cost): boolean
	if Big.gte(data.money, cost) then
		data.money = Big.sub(data.money, cost)
		return true
	end
	return false
end

local function payDiamonds(data: Data, cost): boolean
	if Big.gte(data.diamonds, cost) then
		data.diamonds = Big.sub(data.diamonds, cost)
		return true
	end
	return false
end

-- Cost = base * mult^level. The original floors each step for money/spawner costs; the
-- difference is < 1 coin per level so we use the closed form (fast at any level, works in Big).
local function scaledCost(base: number, mult: number, level: number)
	return Big.floor(Big.mul(Big.pow(mult, level), base))
end

local function mainCost(kind: number, level: number)
	local def = ({ Config.Main.Money, Config.Main.Luck, Config.Main.Diamond })[kind]
	return scaledCost(def.baseCost, def.costMult, level)
end

function Economy.mainUpgradeCost(data: Data, kind: number)
	return mainCost(kind, data.mainLevels[kind])
end

-- kind: 1 = money multiplier, 2 = luck, 3 = diamond chance
function Economy.buyMain(data: Data, kind: number): boolean
	if not payMoney(data, Economy.mainUpgradeCost(data, kind)) then
		return false
	end
	data.mainLevels[kind] += 1
	if kind == 1 then
		data.moneyMultiplier = Big.mul(data.moneyMultiplier, Config.Main.Money.effect)
	elseif kind == 2 then
		data.baseLuck *= Config.Main.Luck.effect
	else
		data.diamondChance += Config.Main.Diamond.effect
	end
	return true
end

function Economy.intervalCost(data: Data, s: number)
	return scaledCost(Config.Spawners.IntervalBaseCost[s], F.intervalCostMult(s), data.intervalLevels[s])
end

function Economy.spawnerLuckCost(data: Data, s: number)
	return scaledCost(Config.Spawners.LuckBaseCost[s], Config.Spawners.LuckCostMult, data.spawnerLuckLevels[s])
end

function Economy.buyInterval(data: Data, s: number): boolean
	local S = Config.Spawners
	if data.spawnIntervals[s] <= S.MinInterval or not payMoney(data, Economy.intervalCost(data, s)) then
		return false
	end
	data.intervalLevels[s] += 1
	data.spawnIntervals[s] = math.max(data.spawnIntervals[s] * S.IntervalFactor, S.MinInterval)
	return true
end

function Economy.buySpawnerLuck(data: Data, s: number): boolean
	if not payMoney(data, Economy.spawnerLuckCost(data, s)) then
		return false
	end
	data.spawnerLuckLevels[s] += 1
	data.spawnerLuck[s] *= Config.Spawners.LuckFactor
	return true
end

function Economy.buySpawner(data: Data, s: number): boolean
	local cost = Config.Spawners.UnlockCost[s]
	if cost == nil or data.spawnersUnlocked ~= s - 1 or not payMoney(data, cost) then
		return false
	end
	data.spawnersUnlocked = s
	return true
end

-- Buy-max: money > luck > diamond, repeat until nothing affordable
function Economy.maxBuyMain(data: Data)
	while Economy.buyMain(data, 1) or Economy.buyMain(data, 2) or Economy.buyMain(data, 3) do
	end
end

function Economy.maxBuySpawner(data: Data, s: number)
	while Economy.buyInterval(data, s) or Economy.buySpawnerLuck(data, s) do
	end
end

-- Buys the cheapest-index affordable spawner upgrade one at a time (interval before luck)
function Economy.maxBuyAllSpawners(data: Data)
	local bought = true
	while bought do
		bought = false
		for s = 1, data.spawnersUnlocked do
			if Economy.buyInterval(data, s) or Economy.buySpawnerLuck(data, s) then
				bought = true
				break
			end
		end
	end
end

function Economy.maxBuyAll(data: Data)
	Economy.maxBuyMain(data)
	Economy.maxBuyAllSpawners(data)
end

function Economy.buyDiamondLuck(data: Data): boolean
	if not payDiamonds(data, data.diamondLuckCost) then
		return false
	end
	data.diamondLuckCost = Big.mul(data.diamondLuckCost, 2)
	data.diamondLuck *= Config.Base.DiamondLuckEffect
	return true
end

function Economy.unlockMechanic(data: Data): boolean
	local m = Config.Mechanics[data.mechanics + 1]
	if not m or Big.lt(data.diamonds, m.cost) then
		return false
	end
	if m.minRebirths and data.rebirths < m.minRebirths then
		return false
	end
	if m.minTiers and data.tiers < m.minTiers then
		return false
	end
	data.diamonds = Big.sub(data.diamonds, m.cost)
	data.mechanics += 1
	return true
end

---------------------------------------------------------------- resets

-- Shared by rebirth/tier/respec. `onClearBoard` is up to the caller (delete all orbs).
local function currencyReset(data: Data, resetBoosts: boolean)
	data.money = Big.new(0)
	data.moneyMultiplier = Big.pow(2, data.tiers)
	data.baseLuck = 2 ^ data.rebirths * 3 ^ data.tiers
	data.diamondChance = Config.Base.DiamondChance
	data.spawnIntervals = copy(Config.Spawners.BaseInterval)
	data.spawnerLuck = copy(Config.Spawners.BaseLuck)
	if resetBoosts then
		data.boostTimes = { money = 0, luck = 0, duplicate = 0, obstacle = 0 }
	end
end

-- RL-1: keep a % of every upgrade level and re-apply its effect.
local function keepLevels(data: Data)
	local rl1 = F.skill(data, "RL-1")
	local pct = 0
	if rl1 >= 1 then
		pct = (F.skillDef("RL-1") :: any).values[rl1] / 100
	end
	local main, intv, luck = data.mainLevels, data.intervalLevels, data.spawnerLuckLevels
	data.mainLevels, data.intervalLevels, data.spawnerLuckLevels = { 0, 0, 0 }, table.create(7, 0), table.create(7, 0)
	for k = 1, 3 do
		local kept = math.floor(main[k] * pct)
		data.mainLevels[k] = kept
		if k == 1 then
			data.moneyMultiplier = Big.mul(data.moneyMultiplier, Big.pow(Config.Main.Money.effect, kept))
		elseif k == 2 then
			data.baseLuck *= Config.Main.Luck.effect ^ kept
		else
			data.diamondChance += Config.Main.Diamond.effect * kept
		end
	end
	local S = Config.Spawners
	for s = 1, 7 do
		local ki = math.floor(intv[s] * pct)
		data.intervalLevels[s] = ki
		data.spawnIntervals[s] = math.max(S.BaseInterval[s] * S.IntervalFactor ^ ki, S.MinInterval)
		local kl = math.floor(luck[s] * pct)
		data.spawnerLuckLevels[s] = kl
		data.spawnerLuck[s] = S.BaseLuck[s] * S.LuckFactor ^ kl
	end
end

function Economy.rebirth(data: Data): boolean
	if data.mechanics < 1 then
		return false
	end
	local bulk = F.skill(data, "MAX-3") >= 1
	local gained = if bulk then F.bulkRebirths(data) else 1
	local cost = F.rebirthCost(data, data.rebirths + gained - 1)
	if not Big.gt(data.money, cost) then
		return false
	end
	data.rebirths += gained
	data.diamonds = Big.floor(Big.mul(data.diamonds, Config.Rebirth.DiamondKeep))
	currencyReset(data, F.skill(data, "RL-4") < 1)
	keepLevels(data)
	Economy.refresh(data)
	return true
end

function Economy.tier(data: Data): boolean
	if data.mechanics < 4 or not F.canTier(data) then
		return false
	end
	data.tiers += 1
	local rl3 = F.skill(data, "RL-3")
	if rl3 >= 1 then
		data.rebirths = math.floor(data.rebirths * (F.skillDef("RL-3") :: any).values[rl3] / 100)
	else
		data.rebirths = 0
	end
	data.diamonds = Big.new(0)
	data.weatherPoints = 0
	data.automationPoints = 0
	data.weatherPower = math.floor(data.weatherPower / 2)
	data.weatherCosts.roll = Config.WeatherShop.RollBaseCost
	if F.skill(data, "RL-5") < 1 then
		data.weatherCosts.money = Config.WeatherShop.MoneyBaseCost
		data.weatherMoney = 1
	end
	data.spawnersUnlocked = 1
	data.boostUses = table.create(6, 0)
	data.mainLevels, data.intervalLevels, data.spawnerLuckLevels = { 0, 0, 0 }, table.create(7, 0), table.create(7, 0)
	currencyReset(data, true)
	Economy.refresh(data)
	return true
end

---------------------------------------------------------------- boosts

-- Returns true on success. For id 5 the caller must duplicate every orb on the board
-- (ignores the cap). For id 6 the caller rebuilds the board with obstacles removed.
function Economy.buyBoost(data: Data, id: number): boolean
	if data.mechanics < 2 then
		return false
	end
	local cost = F.boostCost(data, id)
	local b = data.boostTimes
	if Big.lt(data.diamonds, cost) then
		return false
	end
	if id == 5 and b.duplicate ~= 0 then
		return false
	end
	if id == 6 and (b.obstacle ~= 0 or F.skill(data, "BST-3") < 1) then
		return false
	end
	data.diamonds = Big.sub(data.diamonds, cost)
	data.boostUses[id] += 1
	local def = Config.Boosts[id]
	if def.kind == "Money" then
		b.money += def.seconds
	elseif def.kind == "Luck" then
		b.luck += def.seconds
	elseif def.kind == "Duplicate" then
		b.duplicate = if F.skill(data, "BST-2") >= 1 then def.cooldownWithBST2 else def.cooldown
	else
		b.obstacle = if F.skill(data, "BST-3") > 1 then def.totalEnhanced else def.total
	end
	Economy.refresh(data)
	return true
end

---------------------------------------------------------------- weather

-- Returns the 1-based weather index rolled, or nil. Apply after your 2 s roll animation if wanted.
function Economy.rollWeather(data: Data, rng: Random?): number?
	if data.mechanics < 5 or data.weatherRollCooldown > 0 then
		return nil
	end
	local price = F.weatherRollPrice(data)
	if data.weatherPoints < price then
		return nil
	end
	data.weatherPoints -= price
	data.weatherCosts.roll += Config.WeatherShop.RollCostStep
	data.weatherRollCooldown = Config.WeatherShop.RollCooldown
	data.weatherRolled += 1

	local odds = Config.WeatherOdds[data.weatherUnlocked]
	local r = (rng or Random.new()):NextNumber()
	local pick = data.weatherUnlocked
	local acc = 0
	for i, p in odds do
		acc += p
		if r < acc then
			pick = i
			break
		end
	end
	data.weatherDuration[pick] += Config.Weather[pick].seconds + Config.WeatherShop.ExtendPerBST5 * F.skill(data, "BST-5")
	data.weatherPower += 2 ^ (pick - 1)
	Economy.refresh(data)
	return pick
end

function Economy.unlockWeather(data: Data): boolean
	local c = data.weatherCosts
	if data.weatherPoints < c.unlock or data.weatherUnlocked >= Config.WeatherShop.MaxUnlockable then
		return false
	end
	data.weatherPoints -= c.unlock
	data.weatherUnlocked += 1
	c.unlock = math.round(c.unlock * 2)
	return true
end

function Economy.buyWeatherMoney(data: Data): boolean
	local c = data.weatherCosts
	if data.weatherPoints < c.money then
		return false
	end
	data.weatherPoints -= c.money
	data.weatherMoney *= Config.WeatherShop.MoneyEffect
	c.money = math.round(c.money * 1.5)
	return true
end

---------------------------------------------------------------- automation

function Economy.buyAutomation(data: Data, idx: number): boolean
	local a = data.automation
	local cost = F.automationCost(data, idx)
	if data.automationPoints < cost then
		return false
	end
	if idx == 3 and F.skill(data, "MAX-1") < 1 then
		return false
	end
	if idx == 4 and F.skill(data, "MAX-2") < 1 then
		return false
	end
	if idx >= 3 and a.levels[idx] >= 1 then
		return false
	end
	data.automationPoints -= cost
	a.levels[idx] += 1
	if idx <= 2 then
		a.timers[idx] = math.min(a.timers[idx], F.automationInterval(a.levels[idx]))
	end
	return true
end

function Economy.runAutomation(data: Data, idx: number)
	local a = data.automation
	if idx == 1 then
		if a.levels[3] >= 1 and F.skill(data, "MAX-1") >= 1 then
			Economy.maxBuyMain(data)
		else
			Economy.buyMain(data, 1)
			Economy.buyMain(data, 2)
			Economy.buyMain(data, 3)
		end
	else
		if a.levels[4] >= 1 and F.skill(data, "MAX-2") >= 1 then
			Economy.maxBuyAllSpawners(data)
		else
			for s = 1, data.spawnersUnlocked do
				Economy.buyInterval(data, s)
				Economy.buySpawnerLuck(data, s)
			end
		end
	end
end

---------------------------------------------------------------- TP / QP / skill tree

function Economy.gainTP(data: Data, source: string): boolean
	local s = Config.TPSources[source]
	local cost = F.tpSourceCost(source, data.tpBought[source])
	local have
	if source == "Money" then
		have = data.money
	elseif source == "Diamonds" then
		have = data.diamonds
	elseif source == "WeatherRolls" then
		have = data.weatherRolled
	else
		have = data.orbsSpawned
	end
	if s.unlockMaxTP and F.maxTP(data) < s.unlockMaxTP then
		return false
	end
	if Big.lt(have, cost) then
		return false
	end
	if source == "Money" then
		data.money = Big.sub(data.money, cost)
	elseif source == "Diamonds" then
		data.diamonds = Big.sub(data.diamonds, cost)
	end
	data.tpBought[source] += 1
	return true
end

function Economy.gainQP(data: Data): boolean
	local q = Config.QPSources.HighestRarity
	if data.highestRarity < q.baseCost + q.step * data.qpBought then
		return false
	end
	data.qpBought += 1
	return true
end

function Economy.buySkill(data: Data, id: string): boolean
	local upg, cat, idx = F.skillDef(id)
	local lvl = data.skills[cat][idx]
	if lvl >= F.skillMaxLevel(upg) then
		return false
	end
	if upg.tier4 and data.tiers < 4 then
		return false
	end
	for _, req in upg.req or {} do
		if F.skill(data, req) < 1 then
			return false
		end
	end
	local pts = Economy.points(data)
	local have = if Config.SkillTree[cat].currency == "QP" then pts.qp else pts.tp
	if have < F.skillCost(upg, lvl) then
		return false
	end
	data.skills[cat][idx] += 1
	Economy.refresh(data)
	return true
end

-- Refunds TP trees (QP trees are permanent). Costs 2 rebirths and a full currency/upgrade reset.
function Economy.respec(data: Data)
	for cat, def in Config.SkillTree do
		if def.currency == "TP" then
			data.skills[cat] = table.create(#def.upgrades, 0)
		end
	end
	data.rebirths = math.max(data.rebirths - 2, 0)
	data.diamonds = Big.new(0)
	data.spawnersUnlocked = 1
	data.mainLevels, data.intervalLevels, data.spawnerLuckLevels = { 0, 0, 0 }, table.create(7, 0), table.create(7, 0)
	currencyReset(data, true)
	Economy.refresh(data)
end

function Economy.setDifficulty(data: Data, difficulty: string): boolean
	if data.rebirths ~= 0 or not Config.Difficulties[difficulty] then
		return false
	end
	data.difficulty = difficulty
	return true
end

return Economy
