--!nonstrict
-- Server-authoritative game state + every player action.
-- Money/diamond-like values are Big (EternityNum); luck is stored in log10.
--
--   Economy.newData(difficulty, rng)          fresh save
--   Economy.serialize(data) / deserialize(t)  DataStore-safe plain tables
--   Economy.tickSecond(data, hooks)            once per second
--   Economy.tickAutomation(data, dt)           every frame
--   Economy.rollSpawn(data, spawner, orbCount) orbs a spawner produces this cycle
--   Economy.collect(data, orb, x)              pay out an orb that reached the bottom
--   Economy.<action>(data, ...)                purchases / resets; return true on success

local Config = require(script.Parent.OrbConfig)
local F = require(script.Parent.OrbFormulas)
local Big = require(script.Parent.Big)
local Progression = require(script.Parent.Progression)
local Prestige = require(script.Parent.Prestige)

local Economy = {}
Economy.SAVE_VERSION = 4

local BIG_FIELDS = { "money", "totalMoney", "diamonds", "totalDiamonds", "moneyMultiplier", "diamondLuckCost" }

local function zeros(n: number): { number }
	return table.create(n, 0)
end

function Economy.newData(difficulty: string?, rng: Random?)
	local r = rng or Random.new()
	local skills = {}
	for cat, def in Config.SkillTree do
		skills[cat] = zeros(#def.upgrades)
	end
	return {
		version = Economy.SAVE_VERSION,
		difficulty = difficulty or "orig",
		money = Big.new(0),
		totalMoney = Big.new(0),
		diamonds = Big.new(0),
		totalDiamonds = Big.new(0),
		moneyMultiplier = Big.new(1),
		diamondLuckCost = Big.new(Config.Base.DiamondLuckCost),
		baseLuckLog = 0,
		bestLuckLog = 0,
		diamondLuckLog = 0,
		diamondChance = Config.Base.DiamondChance,
		highestRarity = 0,
		orbsObtained = {}, -- [rarityIndex] = count (sparse; endless)
		orbsSpawned = 0,

		mechanics = 0,
		rebirths = 0,
		tiers = 0,

		spawnersUnlocked = 1,
		spawnIntervals = table.clone(Config.Spawners.BaseInterval),
		mainLevels = { 0, 0, 0 },
		intervalLevels = zeros(7),
		spawnerLuckLevels = zeros(7),

		boostTimes = { money = 0, luck = 0, duplicate = 0, obstacle = 0 },
		boostUses = zeros(6),
		autoPotion = { money = false, luck = false },

		weatherPoints = 0,
		stormLevel = 0, -- endless weather upgrade: +10% weather effects per level (bonus-budgeted)
		weatherUnlocked = 1,
		weatherRolled = 0,
		weatherPower = 0,
		weatherMoney = 1,
		weatherRollCooldown = 0,
		weatherDuration = zeros(#Config.Weather),
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
		tutorialStep = 1, -- see Tutorial.luau; 0 = finished/skipped
		tierReqOdds = 0, -- relative tiers: odds target (log10) for the next tier
		tierProgress = 0, -- relative tiers: qualifying orbs collected since the last tier
		tierStartTime = 0, -- timePlayed when the current tier began (pacing floor)
		prestige = Prestige.newState(), -- ascension / transcension / ... (see Prestige.luau)
		totalLuckLog = 0, -- cached for UI
	}
end

---------------------------------------------------------------- save / load

function Economy.serialize(data)
	local out = table.clone(data)
	for _, k in BIG_FIELDS do
		out[k] = Big.serialize(data[k])
	end
	-- sparse rarity counts -> string keys for DataStore JSON
	local obt = {}
	for k, v in data.orbsObtained do
		obt[tostring(k)] = v
	end
	out.orbsObtained = obt
	return out
end

function Economy.deserialize(saved)
	local data = Economy.newData(saved and saved.difficulty)
	if type(saved) ~= "table" then
		return data
	end
	for k, v in saved do
		if data[k] ~= nil and type(v) == type(data[k]) or (table.find(BIG_FIELDS, k) and type(v) == "string") then
			data[k] = v
		end
	end
	for _, k in BIG_FIELDS do
		if type(saved[k]) == "string" then
			data[k] = Big.deserialize(saved[k])
		end
	end
	local obt = {}
	for k, v in saved.orbsObtained or {} do
		obt[tonumber(k)] = v
	end
	data.orbsObtained = obt
	-- make sure new skill slots exist if the tree grew
	for cat, def in Config.SkillTree do
		data.skills[cat] = data.skills[cat] or {}
		for i = 1, #def.upgrades do
			data.skills[cat][i] = data.skills[cat][i] or 0
		end
	end
	Economy.migrate(data, tonumber(saved.version) or 1)
	Prestige.ensure(data)
	Economy.refresh(data)
	return data
end

-- Versioned save migrations. Add a step whenever saved data changes shape; never edit old steps.
Economy.MIGRATIONS = {
	[3] = function(data)
		-- v3 -> v4: prestige layers
		Prestige.ensure(data)
	end,
	[2] = function(data)
		-- v2 -> v3: relative tiers. Players already past tier 4 get a target from their current luck.
		data.tierProgress = data.tierProgress or 0
		if data.tiers >= 4 and (data.tierReqOdds or 0) <= 0 then
			Economy.refresh(data)
			data.tierReqOdds = Progression.nextTierOdds(data.tiers, data.totalLuckLog, nil)
		end
	end,
	[1] = function(data)
		-- v1 -> v2: storm level + tutorial added. Veterans skip the tutorial.
		data.stormLevel = data.stormLevel or 0
		if data.rebirths > 0 or data.tiers > 0 then
			data.tutorialStep = 0
		end
	end,
}

function Economy.migrate(data, fromVersion: number)
	for v = fromVersion, Economy.SAVE_VERSION - 1 do
		local step = Economy.MIGRATIONS[v]
		if step then
			step(data)
		end
	end
	data.version = Economy.SAVE_VERSION
end

---------------------------------------------------------------- derived

function Economy.refresh(data)
	data.baseLuckLog = F.baseLuckLog(data) + data.mainLevels[2] * math.log10(Config.Main.Luck.effect)
	local l, best = F.totalLuckLog(data)
	data.totalLuckLog, data.bestLuckLog = l, best
	if data.spawnersUnlocked == 5 and F.skill(data, "SPW-1") >= 1 then
		data.spawnersUnlocked = 6
	end
	if data.spawnersUnlocked == 6 and F.skill(data, "SPW-1") >= 2 then
		data.spawnersUnlocked = 7
	end
end

function Economy.points(data)
	local spentTP, spentQP = F.spentPoints(data)
	local maxTP, maxQP = F.maxTP(data), F.maxQP(data)
	return { maxTP = maxTP, tp = maxTP - spentTP, maxQP = maxQP, qp = maxQP - spentQP }
end

---------------------------------------------------------------- spawning

-- Returns 0..2 orbs: { kind = "orb"|"diamond"|"weather", rarity?, variant? }
function Economy.rollSpawn(data, spawner: number, orbCount: number, rng: Random?)
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
		if r:NextNumber() < F.diamondChance(data) then
			table.insert(out, { kind = "diamond", variant = F.rollVariant(data, r:NextNumber()) })
			return
		end
		local rarity = F.rollRarity(data.totalLuckLog + F.spawnerLuckLog(data, spawner), r:NextNumber())
		if rarity > data.highestRarity then
			data.highestRarity = rarity
		end
		data.orbsSpawned += 1
		table.insert(out, { kind = "orb", rarity = rarity, variant = F.rollVariant(data, r:NextNumber()) })
	end
	one()
	if r:NextNumber() < F.skill(data, "SPW-4") * 0.1 then
		one()
	end
	return out
end

function Economy.collect(data, orb, x: number, rng: Random?)
	local slot = F.slotMult(data.tiers, x)
	if orb.kind == "orb" then
		local gain = F.orbMoney(data, orb.rarity, slot, orb.variant)
		data.money = Big.add(data.money, gain)
		data.totalMoney = Big.add(data.totalMoney, gain)
		data.orbsObtained[orb.rarity] = (data.orbsObtained[orb.rarity] or 0) + 1
		local req = F.tierRequirement(data)
		if req.relative and orb.rarity >= req.rarity then
			data.tierProgress += 1
		end
		if data.tiers >= 2 and (rng or Random.new()):NextNumber() < Config.Automation.PointChance then
			data.automationPoints += orb.rarity
		end
		return { money = gain, slot = slot }
	elseif orb.kind == "diamond" then
		local gain = F.diamondGain(data, slot, orb.variant)
		data.diamonds = Big.add(data.diamonds, gain)
		data.totalDiamonds = Big.add(data.totalDiamonds, gain)
		return { diamonds = gain, slot = slot }
	end
	local gain = F.variantMult(orb.variant)
	data.weatherPoints += gain
	return { weatherPoints = gain }
end

---------------------------------------------------------------- timers

function Economy.tickSecond(data, hooks)
	local b = data.boostTimes
	-- BST-4 auto potion: re-buy a 1 min potion the moment it runs out
	local hadMoney, hadLuck = b.money > 0, b.luck > 0
	b.money = math.max(b.money - 1, 0)
	b.luck = math.max(b.luck - 1, 0)
	b.duplicate = math.max(b.duplicate - 1, 0)
	if F.skill(data, "BST-4") >= 1 then
		if hadMoney and b.money == 0 and data.autoPotion.money then
			Economy.buyBoost(data, 1)
		end
		if hadLuck and b.luck == 0 and data.autoPotion.luck then
			Economy.buyBoost(data, 3)
		end
	end
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

function Economy.obstaclesRemoved(data): boolean
	return data.boostTimes.obstacle > Config.Boosts[6].downtime
end

function Economy.tickAutomation(data, dt: number)
	local a = data.automation
	for i = 1, 2 do
		if a.levels[i] > 0 and a.enabled[i] then
			a.timers[i] -= dt
			if a.timers[i] <= 0 then
				Economy.runAutomation(data, i)
				a.timers[i] = F.automationInterval(a.levels[i])
			end
		end
	end
end

---------------------------------------------------------------- main + spawner upgrades

local MAIN = { Config.Main.Money, Config.Main.Luck, Config.Main.Diamond }

local function pay(data, field: string, cost): boolean
	if Big.gte(data[field], cost) then
		data[field] = Big.sub(data[field], cost)
		return true
	end
	return false
end

local function applyMain(data, kind: number, n: number)
	data.mainLevels[kind] += n
	if kind == 1 then
		data.moneyMultiplier = Big.mul(data.moneyMultiplier, Big.pow(Config.Main.Money.effect, n))
	elseif kind == 3 then
		data.diamondChance += Config.Main.Diamond.effect * n
	end
	Economy.refresh(data) -- luck derives from mainLevels[2]
end

local function mainMax(data, kind: number): number
	if kind == 3 then
		local left = (F.DIAMOND_CHANCE_CAP - data.diamondChance) / Config.Main.Diamond.effect
		return math.max(math.floor(left + 1e-9), 0)
	end
	return math.huge
end

function Economy.mainUpgradeCost(data, kind: number)
	local d = MAIN[kind]
	return F.scaledCost(d.baseCost, d.costMult, data.mainLevels[kind])
end

-- kind: 1 = money multiplier, 2 = luck, 3 = diamond chance. Buys `count` levels (default 1), or as many as affordable.
function Economy.buyMain(data, kind: number, count: number?): boolean
	local d = MAIN[kind]
	if not d then
		return false
	end
	local want = math.min(count or 1, mainMax(data, kind))
	local n = F.affordableLevels(data.money, d.baseCost, d.costMult, data.mainLevels[kind], want)
	if n < 1 then
		return false
	end
	if not pay(data, "money", F.geometricSum(d.baseCost, d.costMult, data.mainLevels[kind], n)) then
		return false
	end
	applyMain(data, kind, n)
	return true
end

local function intervalMaxLevels(data, s: number): number
	local S = Config.Spawners
	local cap = math.ceil(math.log(S.MinInterval / S.BaseInterval[s]) / math.log(S.IntervalFactor))
	return math.max(cap - data.intervalLevels[s], 0)
end

function Economy.intervalCost(data, s: number)
	return F.scaledCost(Config.Spawners.IntervalBaseCost[s], F.intervalCostMult(s), data.intervalLevels[s])
end

function Economy.spawnerLuckCost(data, s: number)
	return F.scaledCost(Config.Spawners.LuckBaseCost[s], Config.Spawners.LuckCostMult, data.spawnerLuckLevels[s])
end

local function refreshInterval(data, s: number)
	local S = Config.Spawners
	data.spawnIntervals[s] = math.max(S.BaseInterval[s] * S.IntervalFactor ^ data.intervalLevels[s], S.MinInterval)
end

function Economy.buyInterval(data, s: number, count: number?): boolean
	if s > data.spawnersUnlocked then
		return false
	end
	local base, mult = Config.Spawners.IntervalBaseCost[s], F.intervalCostMult(s)
	local n = F.affordableLevels(data.money, base, mult, data.intervalLevels[s], math.min(count or 1, intervalMaxLevels(data, s)))
	if n < 1 or not pay(data, "money", F.geometricSum(base, mult, data.intervalLevels[s], n)) then
		return false
	end
	data.intervalLevels[s] += n
	refreshInterval(data, s)
	return true
end

function Economy.buySpawnerLuck(data, s: number, count: number?): boolean
	if s > data.spawnersUnlocked then
		return false
	end
	local base, mult = Config.Spawners.LuckBaseCost[s], Config.Spawners.LuckCostMult
	local n = F.affordableLevels(data.money, base, mult, data.spawnerLuckLevels[s], count or 1)
	if n < 1 or not pay(data, "money", F.geometricSum(base, mult, data.spawnerLuckLevels[s], n)) then
		return false
	end
	data.spawnerLuckLevels[s] += n
	return true
end

function Economy.buySpawner(data, s: number): boolean
	local cost = Config.Spawners.UnlockCost[s]
	if cost == nil or data.spawnersUnlocked ~= s - 1 or not pay(data, "money", cost) then
		return false
	end
	data.spawnersUnlocked = s
	return true
end

-- Max-buy keeps the original priority (money > luck > diamond; interval > luck) but buys in
-- bulk so it stays instant at any money amount.
function Economy.maxBuyMain(data)
	for _ = 1, 64 do
		if not (Economy.buyMain(data, 1, math.huge) or Economy.buyMain(data, 2, math.huge) or Economy.buyMain(data, 3, math.huge)) then
			break
		end
	end
end

function Economy.maxBuySpawner(data, s: number)
	for _ = 1, 64 do
		if not (Economy.buyInterval(data, s, math.huge) or Economy.buySpawnerLuck(data, s, math.huge)) then
			break
		end
	end
end

function Economy.maxBuyAllSpawners(data)
	for _ = 1, 64 do
		local any = false
		for s = 1, data.spawnersUnlocked do
			any = Economy.buyInterval(data, s, math.huge) or Economy.buySpawnerLuck(data, s, math.huge) or any
		end
		if not any then
			break
		end
	end
end

function Economy.maxBuyAll(data)
	if F.skill(data, "MAX-5") >= 1 then
		Economy.maxBuyMain(data)
	end
	Economy.maxBuyAllSpawners(data)
end

function Economy.buyDiamondLuck(data): boolean
	if not pay(data, "diamonds", data.diamondLuckCost) then
		return false
	end
	data.diamondLuckCost = Big.mul(data.diamondLuckCost, 2)
	data.diamondLuckLog += math.log10(Config.Base.DiamondLuckEffect)
	Economy.refresh(data)
	return true
end

function Economy.unlockMechanic(data): boolean
	local m = Config.Mechanics[data.mechanics + 1]
	if not m then
		return false
	end
	if (m.minRebirths and data.rebirths < m.minRebirths) or (m.minTiers and data.tiers < m.minTiers) then
		return false
	end
	if not pay(data, "diamonds", m.cost) then
		return false
	end
	data.mechanics += 1
	return true
end

---------------------------------------------------------------- resets

local function currencyReset(data, resetBoosts: boolean)
	data.money = Big.new(0)
	data.moneyMultiplier = Big.pow(2, data.tiers)
	data.diamondChance = Config.Base.DiamondChance
	data.spawnIntervals = table.clone(Config.Spawners.BaseInterval)
	if resetBoosts then
		data.boostTimes = { money = 0, luck = 0, duplicate = 0, obstacle = 0 }
	end
end

-- RL-1: keep % of upgrade levels on rebirth
local function keepLevels(data)
	local rl1 = F.skill(data, "RL-1")
	local pct = rl1 >= 1 and (F.skillDef("RL-1")).values[rl1] / 100 or 0
	local main, intv, luck = data.mainLevels, data.intervalLevels, data.spawnerLuckLevels
	data.mainLevels, data.intervalLevels, data.spawnerLuckLevels = { 0, 0, 0 }, zeros(7), zeros(7)
	for k = 1, 3 do
		applyMain(data, k, math.floor(main[k] * pct))
	end
	for s = 1, 7 do
		data.intervalLevels[s] = math.floor(intv[s] * pct)
		refreshInterval(data, s)
		data.spawnerLuckLevels[s] = math.floor(luck[s] * pct)
	end
end

function Economy.rebirth(data): boolean
	if data.mechanics < 1 then
		return false
	end
	local bought = if F.skill(data, "MAX-3") >= 1 then F.bulkRebirths(data) else 1
	if not Big.gt(data.money, F.rebirthCost(data, data.rebirths + bought - 1)) then
		return false
	end
	-- ascension magnifies rebirths: each rebirth bought grants (1 + 0.1*lifetimeAP + echo) rebirths
	data.rebirths += math.floor(bought * Prestige.rebirthGainMult(data))
	data.diamonds = Big.floor(Big.mul(data.diamonds, Config.Rebirth.DiamondKeep))
	currencyReset(data, F.skill(data, "RL-4") < 1)
	keepLevels(data)
	Economy.refresh(data)
	return true
end

function Economy.tier(data): boolean
	if data.mechanics < 4 or not F.canTier(data) then
		return false
	end
	local luckAtTier = data.totalLuckLog
	data.tiers += 1
	data.tierStartTime = data.timePlayed
	if Progression.isRelativeTier(data.tiers + 1) then
		local prev = data.tierReqOdds > 0 and data.tierReqOdds or nil
		data.tierReqOdds = Progression.nextTierOdds(data.tiers, luckAtTier, prev)
		data.tierProgress = 0
	end
	local rl3 = F.skill(data, "RL-3")
	data.rebirths = rl3 >= 1 and math.floor(data.rebirths * (F.skillDef("RL-3")).values[rl3] / 100) or 0
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
	data.boostUses = zeros(6)
	data.mainLevels, data.intervalLevels, data.spawnerLuckLevels = { 0, 0, 0 }, zeros(7), zeros(7)
	currencyReset(data, true)
	Economy.refresh(data)
	return true
end

---------------------------------------------------------------- boosts

-- id 5 (duplicate) and 6 (obstacle remover) need the caller to act on the board afterwards.
function Economy.buyBoost(data, id: number): boolean
	local def = Config.Boosts[id]
	if data.mechanics < 2 or not def then
		return false
	end
	local b = data.boostTimes
	if (id == 5 and b.duplicate ~= 0) or (id == 6 and (b.obstacle ~= 0 or F.skill(data, "BST-3") < 1)) then
		return false
	end
	if not pay(data, "diamonds", F.boostCost(data, id)) then
		return false
	end
	data.boostUses[id] += 1
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

function Economy.setAutoPotion(data, which: string, on: boolean): boolean
	if data.autoPotion[which] == nil then
		return false
	end
	data.autoPotion[which] = on == true
	return true
end

---------------------------------------------------------------- weather

function Economy.rollWeather(data, rng: Random?): number?
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
	local pick, acc = data.weatherUnlocked, 0
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

function Economy.unlockWeather(data): boolean
	local c = data.weatherCosts
	if data.mechanics < 5 or data.weatherPoints < c.unlock or data.weatherUnlocked >= Config.WeatherShop.MaxUnlockable then
		return false
	end
	data.weatherPoints -= c.unlock
	data.weatherUnlocked += 1
	c.unlock = math.round(c.unlock * 2)
	return true
end

-- Endless weather sink: storm levels never cap; their effect is bonus-budgeted (Balance), so
-- grinding storm levels speeds you up but can never break the core curve.
function Economy.stormLevelCost(data): number
	return math.floor(10 * 1.6 ^ data.stormLevel)
end

function Economy.buyStormLevel(data): boolean
	if data.mechanics < 5 then
		return false
	end
	local cost = Economy.stormLevelCost(data)
	if data.weatherPoints < cost then
		return false
	end
	data.weatherPoints -= cost
	data.stormLevel += 1
	Economy.refresh(data)
	return true
end

function Economy.buyWeatherMoney(data): boolean
	local c = data.weatherCosts
	if data.mechanics < 5 or data.weatherPoints < c.money then
		return false
	end
	data.weatherPoints -= c.money
	data.weatherMoney *= Config.WeatherShop.MoneyEffect
	c.money = math.round(c.money * 1.5)
	return true
end

---------------------------------------------------------------- automation

function Economy.buyAutomation(data, idx: number): boolean
	local a = data.automation
	if not a.levels[idx] or data.tiers < 2 then
		return false
	end
	if (idx == 3 and F.skill(data, "MAX-1") < 1) or (idx == 4 and F.skill(data, "MAX-2") < 1) or (idx >= 3 and a.levels[idx] >= 1) then
		return false
	end
	local cost = F.automationCost(data, idx)
	if data.automationPoints < cost then
		return false
	end
	data.automationPoints -= cost
	a.levels[idx] += 1
	if idx <= 2 then
		a.timers[idx] = math.min(a.timers[idx], F.automationInterval(a.levels[idx]))
	end
	return true
end

function Economy.toggleAutomation(data, idx: number): boolean
	local a = data.automation
	if idx ~= 1 and idx ~= 2 then
		return false
	end
	a.enabled[idx] = not a.enabled[idx]
	return true
end

function Economy.runAutomation(data, idx: number)
	local a = data.automation
	if idx == 1 then
		if a.levels[3] >= 1 and F.skill(data, "MAX-1") >= 1 then
			Economy.maxBuyMain(data)
		else
			Economy.buyMain(data, 1)
			Economy.buyMain(data, 2)
			Economy.buyMain(data, 3)
		end
	elseif a.levels[4] >= 1 and F.skill(data, "MAX-2") >= 1 then
		Economy.maxBuyAllSpawners(data)
	else
		for s = 1, data.spawnersUnlocked do
			Economy.buyInterval(data, s)
			Economy.buySpawnerLuck(data, s)
		end
	end
end

---------------------------------------------------------------- TP / QP / skills

function Economy.gainTP(data, source: string): boolean
	local s = Config.TPSources[source]
	if not s or (s.unlockMaxTP and F.maxTP(data) < s.unlockMaxTP) then
		return false
	end
	local cost = F.tpSourceCost(source, data.tpBought[source])
	if source == "Money" then
		if not pay(data, "money", cost) then
			return false
		end
	elseif source == "Diamonds" then
		if not pay(data, "diamonds", cost) then
			return false
		end
	else
		local have = source == "WeatherRolls" and data.weatherRolled or data.orbsSpawned
		if Big.lt(have, cost) then
			return false
		end
	end
	data.tpBought[source] += 1
	return true
end

function Economy.gainQP(data): boolean
	local q = Config.QPSources.HighestRarity
	if data.highestRarity < q.baseCost + q.step * data.qpBought then
		return false
	end
	data.qpBought += 1
	return true
end

function Economy.buySkill(data, id: string): boolean
	local ok, upg, cat, idx = pcall(F.skillDef, id)
	if not ok or not upg then
		return false
	end
	local lvl = data.skills[cat][idx]
	if data.tiers < 1 or lvl >= F.skillMaxLevel(upg) or (upg.tier4 and data.tiers < 4) then
		return false
	end
	for _, req in upg.req or {} do
		if F.skill(data, req) < 1 then
			return false
		end
	end
	local pts = Economy.points(data)
	local have = Config.SkillTree[cat].currency == "QP" and pts.qp or pts.tp
	if have < F.skillCost(upg, lvl) then
		return false
	end
	data.skills[cat][idx] += 1
	Economy.refresh(data)
	return true
end

-- Refund TP trees (QP trees are permanent): -2 rebirths and a full currency/upgrade reset.
function Economy.respec(data): boolean
	for cat, def in Config.SkillTree do
		if def.currency == "TP" then
			data.skills[cat] = zeros(#def.upgrades)
		end
	end
	data.rebirths = math.max(data.rebirths - 2, 0)
	data.diamonds = Big.new(0)
	data.spawnersUnlocked = 1
	data.mainLevels, data.intervalLevels, data.spawnerLuckLevels = { 0, 0, 0 }, zeros(7), zeros(7)
	currencyReset(data, true)
	Economy.refresh(data)
	return true
end

function Economy.setDifficulty(data, difficulty: string): boolean
	if data.rebirths ~= 0 or data.tiers ~= 0 or not Config.Difficulties[difficulty] then
		return false
	end
	data.difficulty = difficulty
	return true
end

---------------------------------------------------------------- prestige layers

function Economy.prestigePending(data, layerId: string): number
	return Prestige.pending(data, layerId)
end

-- Ascend / transcend / ...: bank points, then reset everything the layer resets.
function Economy.prestige(data, layerId: string): boolean
	local L = Prestige.byId[layerId]
	if not L then
		return false
	end
	local pts = Prestige.pending(data, layerId)
	if pts < 1 then
		return false
	end
	local st = data.prestige[layerId]
	st.points += pts
	st.lifetime += pts
	st.count += 1
	local r = L.resets
	-- reset layers below (lower index) first
	for i = L.index - 1, 1, -1 do
		local below = Prestige.LAYERS[i]
		if r[below.id] then
			data.prestige[below.id] = { points = 0, lifetime = 0, count = 0, shop = {} }
		end
	end
	if r.tiers then
		data.tiers = 0
		data.tierReqOdds = 0
		data.tierProgress = 0
		data.tierStartTime = data.timePlayed
		-- tier points shrink with tiers, so refund the TP skill trees
		for cat, def in Config.SkillTree do
			if def.currency == "TP" then
				data.skills[cat] = zeros(#def.upgrades)
			end
		end
	end
	if r.rebirths then
		-- Rebirth Memory keeps a slice (only when ascending; higher layers wipe it)
		data.rebirths = if layerId == "ascension" then math.floor(data.rebirths * Prestige.keepRebirths(data)) else 0
	end
	if r.gems then
		data.diamonds = Big.new(0)
		data.boostUses = zeros(6)
	end
	if r.run then
		data.mainLevels, data.intervalLevels, data.spawnerLuckLevels = { 0, 0, 0 }, zeros(7), zeros(7)
		currencyReset(data, true)
		data.spawnersUnlocked = math.max(1, Prestige.startSpawners(data))
	end
	Economy.refresh(data)
	return true
end

function Economy.buyPrestigeUpgrade(data, upgradeId: string): boolean
	local ok = Prestige.buy(data, upgradeId)
	if ok then
		Economy.refresh(data)
	end
	return ok
end

Economy.Progression = Progression
return Economy
