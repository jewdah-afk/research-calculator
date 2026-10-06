--!strict
-- Balance data for the orb idle game. All numbers are tuning values only;
-- presentation (colours, art, sounds) lives elsewhere.

local OrbConfig = {}

-- Rarity tiers 1-50 (names climb from everyday things to gems, elements, beasts, cosmos, divine).
-- Looks/effects for every rarity come from RarityStyle.luau. `oneIn` is the base 1-in-N chance at 1x luck, `value` is money per orb,
-- `radius` is orb radius in board pixels (board is 400 x 800).
OrbConfig.Rarities = {
	{ name = "Pebble", oneIn = 1, value = 1, radius = 5 },
	{ name = "Marble", oneIn = 4, value = 4, radius = 6 },
	{ name = "Clover", oneIn = 15, value = 14, radius = 6 },
	{ name = "Bubble", oneIn = 50, value = 35, radius = 6 },
	{ name = "Copper", oneIn = 250, value = 145, radius = 7 },
	{ name = "Silver", oneIn = 1200, value = 450, radius = 7 },
	{ name = "Gold", oneIn = 7000, value = 1600, radius = 7 },
	{ name = "Jade", oneIn = 30000, value = 4800, radius = 8 },
	{ name = "Amber", oneIn = 140000, value = 16000, radius = 8 },
	{ name = "Sapphire", oneIn = 750000, value = 60000, radius = 9 },
	{ name = "Ruby", oneIn = 6e6, value = 4e5, radius = 9 },
	{ name = "Emerald", oneIn = 2e7, value = 8.25e5, radius = 9 },
	{ name = "Amethyst", oneIn = 4.5e8, value = 1.1e7, radius = 10 },
	{ name = "Diamond", oneIn = 7e9, value = 6.7e7, radius = 10 },
	{ name = "Frostbite", oneIn = 2.5e12, value = 1.57e9, radius = 10 },
	{ name = "Ember", oneIn = 7e13, value = 1.62e10, radius = 10 },
	{ name = "Thunderstrike", oneIn = 1.5e15, value = 1.64e11, radius = 11 },
	{ name = "Tidal", oneIn = 3e16, value = 1.72e12, radius = 11 },
	{ name = "Venom", oneIn = 5.8e17, value = 1.78e13, radius = 11 },
	{ name = "Phantom", oneIn = 1e20, value = 9e14, radius = 11 },
	{ name = "Wyvern", oneIn = 8e21, value = 1.85e16, radius = 11 },
	{ name = "Phoenix", oneIn = 7.5e23, value = 4e17, radius = 12 },
	{ name = "Kraken", oneIn = 1.6e26, value = 1.7e19, radius = 12 },
	{ name = "Titan", oneIn = 5.5e27, value = 2.9e20, radius = 12 },
	{ name = "Leviathan", oneIn = 4e29, value = 7.9e21, radius = 12 },
	{ name = "Seraph", oneIn = 3.2e30, value = 3e22, radius = 12 },
	{ name = "Archon", oneIn = 2.4e32, value = 6e23, radius = 13 },
	{ name = "Eclipse", oneIn = 5e33, value = 3.5e24, radius = 13 },
	{ name = "Aurora", oneIn = 1.5e35, value = 3.3e25, radius = 13 },
	{ name = "Comet", oneIn = 5e37, value = 1.9e27, radius = 13 },
	{ name = "Supernova", oneIn = 8e38, value = 9e27, radius = 13 },
	{ name = "Pulsar", oneIn = 1.5e40, value = 5e28, radius = 14 },
	{ name = "Quasar", oneIn = 2e41, value = 2.7e29, radius = 14 },
	{ name = "Nebula", oneIn = 6e42, value = 2.6e30, radius = 14 },
	{ name = "Starforge", oneIn = 5e44, value = 1e32, radius = 14 },
	{ name = "Black Hole", oneIn = 1e46, value = 7e32, radius = 14 },
	{ name = "Wormhole", oneIn = 1e47, value = 4e33, radius = 14 },
	{ name = "Event Horizon", oneIn = 5e48, value = 8e34, radius = 14 },
	{ name = "Dark Matter", oneIn = 1e50, value = 8e35, radius = 14 },
	{ name = "Antimatter", oneIn = 2.8e51, value = 1e37, radius = 15 },
	{ name = "Chrono", oneIn = 2.8e53, value = 5e38, radius = 15 },
	{ name = "Paradox", oneIn = 1.7e54, value = 1.2e39, radius = 15 },
	{ name = "Dreamweaver", oneIn = 5e55, value = 1.5e40, radius = 15 },
	{ name = "Astral Crown", oneIn = 1e57, value = 1.2e41, radius = 15 },
	{ name = "Celestial", oneIn = 5e58, value = 1.8e42, radius = 15 },
	{ name = "Godspark", oneIn = 2.5e60, value = 1.8e43, radius = 15 },
	{ name = "Genesis", oneIn = 2.5e62, value = 1.8e44, radius = 15 },
	{ name = "Omniverse", oneIn = 5e64, value = 1.8e45, radius = 15 },
	{ name = "Infinity", oneIn = 2.5e67, value = 1.8e46, radius = 15 },
	{ name = "The Absolute", oneIn = 2.5e70, value = 1.8e49, radius = 15 },
}

-- Board / collection
OrbConfig.Board = {
	Width = 400,
	Height = 600, -- board is 400 x 600 logical px (shorter than the 400x800 original to fit the HUD)
	CollectY = 580, -- orb is cashed in once its centre passes this y (y grows downward)
	SpawnXMin = 50,
	SpawnXMax = 350,
	SpawnY = 30,
	SpecialOrbRadius = 15, -- diamond + weather orbs
	BaseSpawnCap = 100,
}

-- Orb variants (need skill SPW-3). Rolled as one uniform r, checked top to bottom.
OrbConfig.Variants = {
	Rainbow = { mult = 50, chance = 0.0014, requiresMN4 = 4 },
	Glowing = { mult = 5, baseThreshold = 0.01, perMN4 = 0.005 },
	Shiny = { mult = 2, baseThreshold = 0.1, perMN4 = 0.01 },
}

-- Spawners (index 1..7)
OrbConfig.Spawners = {
	BaseInterval = { 1000, 2000, 4000, 10000, 60000, 100000, 180000 }, -- ms
	BaseLuck = { 1, 1.5, 2.5, 10, 100, 1000, 25000 },
	UnlockCost = { 0, 1000, 20000, 1e9, 1e13 }, -- spawners 6/7 come from skill SPW-1
	MinInterval = 100,
	IntervalFactor = 0.95,
	IntervalBaseCost = { 250, 1500, 25000, 1e10, 5e13, 1e20, 1e38 },
	-- interval cost multiplier = 2.5 + 0.25 * spawnerIndex
	LuckFactor = 1.1,
	LuckBaseCost = { 2000, 8000, 75000, 1e9, 2.5e13, 1e22, 1e40 },
	LuckCostMult = 4,
}

-- Main money-bought upgrades
OrbConfig.Main = {
	Money = { baseCost = 50, costMult = 1.7, effect = 1.15 }, -- multiplicative, cost floored
	Luck = { baseCost = 100, costMult = 2, effect = 1.2 },
	Diamond = { baseCost = 500, costMult = 5, effect = 0.001 }, -- additive to diamond chance
}

OrbConfig.Base = {
	DiamondChance = 0.01,
	DiamondValue = 10,
	DiamondLuckCost = 200, -- diamonds, x2 per buy
	DiamondLuckEffect = 1.1,
	RarityMoneyBonus = 1.06, -- per highest rarity index, once mechanic 3 unlocked
}

-- Mechanic unlock chain (mechanicsUnlocked goes 0 -> 5), paid in diamonds
OrbConfig.Mechanics = {
	{ name = "Rebirth", cost = 50 },
	{ name = "Boosts", cost = 250 },
	{ name = "RarityMoneyBonus", cost = 800 },
	{ name = "Tier", cost = 1600, minRebirths = 15 },
	{ name = "Weather", cost = 8000, minTiers = 2 },
}

OrbConfig.Difficulties = {
	baby = { rebBase = 2000, rebScaling = 3.37, diamondMult = 2 },
	easy = { rebBase = 2000, rebScaling = 3.46, diamondMult = 1 },
	orig = { rebBase = 4000, rebScaling = 3.5, diamondMult = 1 },
	hard = { rebBase = 10000, rebScaling = 3.53, diamondMult = 1 },
	extreme = { rebBase = 25000, rebScaling = 3.56, diamondMult = 0.5 },
}

OrbConfig.Rebirth = {
	DiamondKeep = 0.9, -- floor(diamonds * 0.9)
	-- diamond mult bonus from rebirths
	ScaleStart = 50, -- mult *= 0.025 * rebirths - 0.15
	ExpStart = 80, -- mult *= 1.01 ^ (rebirths - 80)
}

-- Tier requirements: own `count` total of rarity index `rarity`
OrbConfig.Tiers = {
	Max = 4,
	Requirements = {
		{ rarity = 14, count = 50 }, -- Void
		{ rarity = 21, count = 10 }, -- Forsaken
		{ rarity = 30, count = 5 }, -- Fusion
		{ rarity = 38, count = 750 }, -- Volcano
	},
	-- Slot multipliers by board x-range (x is the orb centre when collected)
	-- Each entry: list of {xMin, xMax, mult} checked in order, then `default`.
	Slots = {
		[0] = { zones = { { -math.huge, 66, 2 }, { 155, 244, 1.5 }, { 333, math.huge, 2 } }, default = 1 },
		[1] = { zones = { { 155, 244, 5 } }, default = 1 },
		[2] = { zones = {}, default = 2 },
		[3] = { zones = { { -math.huge, 66, 4 }, { 155, 244, 2.25 }, { 333, math.huge, 4 } }, default = 3 },
		[4] = { zones = { { -math.huge, 66, 4 }, { 155, 244, 2.25 }, { 333, math.huge, 4 } }, default = 3 },
	},
	-- Mega Board slot strip (symmetric, by distance from the centre x=200). Landing odds measured
	-- with the board's own physics (200k drops): EV ~ x1.37, i.e. the x1.4 average the economy
	-- was tuned on. The far edges are ~1 in 6,000.
	MegaSlots = {
		{ upTo = 10, mult = 0.8 }, -- 58%
		{ upTo = 20, mult = 1 }, -- 20%
		{ upTo = 30, mult = 1.5 }, -- 12%
		{ upTo = 45, mult = 2 }, -- 3.4%
		{ upTo = 60, mult = 3 }, -- 2.4%
		{ upTo = 80, mult = 5 }, -- 2.2%
		{ upTo = 100, mult = 10 }, -- 1%
		{ upTo = 140, mult = 20 }, -- 0.5%
		{ upTo = 175, mult = 40 }, -- 0.13%
		{ upTo = math.huge, mult = 100 }, -- ~1/6,000
	},
	-- later tiers pay more on the same strip (matches the old per-tier boards' averages)
	SlotScale = { [0] = 1, 1.3, 1.4, 2.2, 2.2 },
	-- Tier 3 board also collects orbs in the two side pockets (x<=55 or x>=345, 450<=y<=500)
	Tier3Pockets = { leftX = 55, rightX = 345, yMin = 340, yMax = 376 },
}

-- Boosts paid in diamonds. cost = baseCost + uses * increment; uses reset on Tier.
OrbConfig.Boosts = {
	[1] = { kind = "Money", seconds = 60, baseCost = 50, increment = 25 },
	[2] = { kind = "Money", seconds = 300, baseCost = 250, increment = 150 },
	[3] = { kind = "Luck", seconds = 60, baseCost = 50, increment = 15 },
	[4] = { kind = "Luck", seconds = 300, baseCost = 250, increment = 100 },
	[5] = { kind = "Duplicate", cooldown = 60, cooldownWithBST2 = 40, baseCost = 500, increment = 100 },
	[6] = { kind = "ObstacleRemover", total = 80, totalEnhanced = 120, downtime = 20, baseCost = 250, increment = 50 },
}
-- With skill BST-1 these replace base/increment
OrbConfig.BoostsBST1 = {
	[1] = { baseCost = 0, increment = 12 },
	[2] = { baseCost = 200, increment = 80 },
	[3] = { baseCost = 0, increment = 12 },
	[4] = { baseCost = 200, increment = 80 },
	[5] = { baseCost = 450, increment = 100 },
	[6] = { baseCost = 200, increment = 50 },
}

-- Weather. Effects are additive onto a base of 1 while active.
OrbConfig.Weather = {
	{ name = "Drizzle", luck = 0.5, money = 0, diamonds = 0, seconds = 60 },
	{ name = "Rain", luck = 0, money = 0.5, diamonds = 0, seconds = 60 },
	{ name = "Thunderstorm", luck = 0.5, money = 0.5, diamonds = 0, seconds = 60 },
	{ name = "Snow", luck = 1, money = 0.5, diamonds = 0.1, seconds = 75 },
	{ name = "Hail", luck = 1.25, money = 0.5, diamonds = 0.25, seconds = 75 },
	{ name = "Avalanche", luck = 1.75, money = 1, diamonds = 0.25, seconds = 120 },
	{ name = "Tornado", luck = 2.5, money = 1, diamonds = 0.25, seconds = 150 },
	{ name = "Hurricane", luck = 2.5, money = 2, diamonds = 0.25, seconds = 150 },
	{ name = "Asteroid Impact", luck = 2.5, money = 2, diamonds = 2, seconds = 150 },
	{ name = "Meteor Shower", luck = 5, money = 3, diamonds = 2, seconds = 150 },
}
-- Roll odds indexed by number of weathers unlocked
OrbConfig.WeatherOdds = {
	[1] = { 1 },
	[2] = { 0.45, 0.55 },
	[3] = { 0.45, 0.25, 0.3 },
	[4] = { 0.45, 0.25, 0.15, 0.15 },
	[5] = { 0.45, 0.25, 0.15, 0.08, 0.07 },
	[6] = { 0.45, 0.25, 0.15, 0.08, 0.05, 0.02 },
	[7] = { 0.45, 0.25, 0.15, 0.08, 0.05, 0.011, 0.009 },
	[8] = { 0.45, 0.25, 0.15, 0.08, 0.05, 0.011, 0.006, 0.003 },
	[9] = { 0.45, 0.25, 0.15, 0.08, 0.05, 0.011, 0.006, 0.0025, 0.0005 },
	[10] = { 0.45, 0.25, 0.15, 0.08, 0.05, 0.011, 0.006, 0.0025, 0.0003, 0.0002 },
}
OrbConfig.WeatherShop = {
	RollBaseCost = 0.8, -- actual price = round(cost); +0.2 per roll; reset to 0.8 on Tier
	RollCostStep = 0.2,
	RollCooldown = 5,
	UnlockBaseCost = 1, -- x2 per unlock
	MaxUnlockable = 9, -- original only lets you reach 9 of 10 (see README)
	MoneyBaseCost = 3, -- round(x1.5) per buy; reset on Tier unless RL-5
	MoneyEffect = 1.1,
	ExtendPerBST5 = 10,
	OrbChanceDivisor = 250, -- weather orb chance = diamondChance / 250 * (1 + 0.1*log2(power+1))
}

-- Automation points: on tier >= 2, each rarity orb collected has 10% to give +rarityIndex points
OrbConfig.Automation = {
	PointChance = 0.1,
	Costs = { 1000, 2500, 500000, 700000 },
	ScaleMin = 1.8, -- per-save random cost scaling for AUTO-1/2: 1.8 + random*0.1
	ScaleRange = 0.1,
	BaseSeconds = 60, -- interval = 60 * 0.95^level
	IntervalFactor = 0.95,
}

-- Tier Points (TP) and Quantum-ish points (QP)
OrbConfig.TPSources = {
	Money = { baseCost = 1e33, costMult = 1e15, spends = true },
	Diamonds = { baseCost = 10000, costMult = 5, spends = true },
	WeatherRolls = { baseCost = 10, costMult = 4, spends = false, unlockMaxTP = 7 },
	OrbsSpawned = { baseCost = 500000, costMult = 4, spends = false, unlockMaxTP = 12 },
}
OrbConfig.QPSources = {
	HighestRarity = { baseCost = 40, step = 5 },
}

-- Skill tree. `cost` = flat per level, `costs` = per-level list, `max` = level cap (default 1).
-- `infinite` upgrades cost `cost` every level. `currency` is TP or QP.
-- Fifth upgrade in every category unlocks at Tier 4.
OrbConfig.SkillTree = {
	max = {
		currency = "QP",
		upgrades = {
			{ id = "MAX-1", cost = 1 },
			{ id = "MAX-2", cost = 1 },
			{ id = "MAX-3", cost = 3, req = { "MAX-1", "MAX-2" } },
			{ id = "MAX-4", cost = 1, req = { "MAX-2" } },
			{ id = "MAX-5", cost = 1, req = { "MAX-3", "MAX-4" }, tier4 = true },
		},
	},
	rless = {
		currency = "QP",
		upgrades = {
			{ id = "RL-1", costs = { 1, 1, 2, 2, 3 }, values = { 35, 60, 80, 86, 91 } }, -- % upgrade levels kept on rebirth
			{ id = "RL-2", costs = { 1, 1, 1, 1, 3 } }, -- luck recovery strength (level count used)
			{ id = "RL-3", costs = { 1, 1, 2, 3, 2, 5 }, values = { 30, 55, 70, 80, 84, 94 } }, -- % rebirths kept on tier
			{ id = "RL-4", cost = 1 }, -- keep boost timers on rebirth
			{ id = "RL-5", cost = 2, tier4 = true }, -- keep weather money on tier
		},
	},
	boost = {
		currency = "TP",
		upgrades = {
			{ id = "BST-1", cost = 1 },
			{ id = "BST-2", cost = 1 },
			{ id = "BST-3", costs = { 1, 2 } },
			{ id = "BST-4", cost = 2, req = { "BST-2", "BST-3" } },
			{ id = "BST-5", costs = { 1, 1, 1 }, tier4 = true },
		},
	},
	main = {
		currency = "TP",
		upgrades = {
			{ id = "MN-1", cost = 1, infinite = true }, -- x1.05 money
			{ id = "MN-2", cost = 1, infinite = true }, -- x1.1 luck
			{ id = "MN-3", cost = 1, infinite = true }, -- x1.05 diamonds (display only in original)
			{ id = "MN-4", cost = 1, infinite = true, req = { "SPW-3" } }, -- variant odds
			{ id = "MN-5", costs = { 7, 10 }, tier4 = true }, -- /2 rebirth cost, x1.3 luck
		},
	},
	spawner = {
		currency = "TP",
		upgrades = {
			{ id = "SPW-1", cost = 1, max = 2 }, -- unlock spawner 6, 7
			{ id = "SPW-2", costs = { 1, 1, 2, 5 } }, -- +25 orb cap each
			{ id = "SPW-3", cost = 2 }, -- variants
			{ id = "SPW-4", cost = 1, max = 10 }, -- +10% double spawn
			{ id = "SPW-5", costs = { 1, 2, 3, 4, 5 }, tier4 = true }, -- -5% orb size
		},
	},
}

return OrbConfig
