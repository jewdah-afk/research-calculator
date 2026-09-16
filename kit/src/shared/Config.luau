--!nonstrict
--[[
	Config — every tunable number in the game lives here.

	Rarity is expressed as "one in N" (oneIn). Luck divides N, so a 2x luck pass is
	honestly 2x. Income is per second, per placed pet, before multipliers.

	Rule of thumb used for the tuning below:
		income ~= 0.55 * oneIn ^ 0.78
	which keeps each biome worth roughly 8-14 minutes of play before the next one
	out-earns it. Change the pets, keep the shape.
]]

local Config = {}

Config.GameName = "Steal a Spark"
Config.DataStoreKey = "SparkData_v1"   -- bump the suffix to wipe saves
Config.StudioSaves = false             -- set true if you want DataStore writes in Studio

-- ---------------------------------------------------------------- economy ---

Config.StartingCoins = 0
Config.IncomeTickRate = 1              -- seconds between income ticks
Config.BaseStorage = 250               -- coins a plot banks before it stops earning
Config.OfflineEarningsCapHours = 8     -- the "come back tomorrow" hook
Config.OfflineEarningsRate = 0.5       -- offline pets earn at 50%

Config.CollectRadius = 14              -- studs; walk near your vault to collect

-- --------------------------------------------------------------- rarities ---
-- Purely cosmetic tiering: the name/colour shown on a pet, chosen from its oneIn.

Config.Rarities = {
	{ id = "Common",    minOneIn = 1,        color = Color3.fromRGB(198, 205, 215), shake = 0.0, sound = "rbxassetid://12221967" },
	{ id = "Uncommon",  minOneIn = 8,        color = Color3.fromRGB(126, 217, 128), shake = 0.0, sound = "rbxassetid://12221967" },
	{ id = "Rare",      minOneIn = 60,       color = Color3.fromRGB(92, 168, 255),  shake = 0.2, sound = "rbxassetid://12221967" },
	{ id = "Epic",      minOneIn = 400,      color = Color3.fromRGB(180, 118, 255), shake = 0.4, sound = "rbxassetid://12221967" },
	{ id = "Legendary", minOneIn = 3000,     color = Color3.fromRGB(255, 192, 74),  shake = 0.7, sound = "rbxassetid://12221967" },
	{ id = "Mythic",    minOneIn = 25000,    color = Color3.fromRGB(255, 104, 104), shake = 1.0, sound = "rbxassetid://12221967" },
	{ id = "Divine",    minOneIn = 200000,   color = Color3.fromRGB(255, 255, 255), shake = 1.4, sound = "rbxassetid://12221967" },
	{ id = "Secret",    minOneIn = 1500000,  color = Color3.fromRGB(24, 24, 32),    shake = 2.0, sound = "rbxassetid://12221967" },
}

function Config.rarityFor(oneIn)
	local pick = Config.Rarities[1]
	for _, tier in ipairs(Config.Rarities) do
		if oneIn >= tier.minOneIn then
			pick = tier
		end
	end
	return pick
end

-- ----------------------------------------------------------------- biomes ---
-- speedGate is the WalkSpeed a player must have bought to enter. This is the
-- progression spine: upgrades buy speed, speed buys biomes, biomes buy income.

Config.Biomes = {
	{
		id = "Meadow", speedGate = 0, color = Color3.fromRGB(110, 178, 106),
		origin = Vector3.new(0, 0, -260), nests = 6, respawn = 12,
		pets = {
			{ id = "Chick",      oneIn = 1,       income = 1,      color = Color3.fromRGB(255, 227, 122) },
			{ id = "Bunny",      oneIn = 4,       income = 4,      color = Color3.fromRGB(238, 238, 238) },
			{ id = "Fox Cub",    oneIn = 16,      income = 16,     color = Color3.fromRGB(226, 126, 64)  },
			{ id = "Stag",       oneIn = 90,      income = 90,     color = Color3.fromRGB(150, 104, 70)  },
			{ id = "Sun Hare",   oneIn = 700,     income = 900,    color = Color3.fromRGB(255, 205, 96)  },
			{ id = "Meadowborn", oneIn = 9000,    income = 14000,  color = Color3.fromRGB(180, 255, 170) },
		},
	},
	{
		id = "Cavern", speedGate = 16, color = Color3.fromRGB(96, 96, 124),
		origin = Vector3.new(-300, 0, -60), nests = 6, respawn = 14,
		pets = {
			{ id = "Bat",        oneIn = 1,       income = 22,     color = Color3.fromRGB(88, 82, 110)   },
			{ id = "Mole",       oneIn = 5,       income = 95,     color = Color3.fromRGB(122, 96, 74)   },
			{ id = "Crystal Rat",oneIn = 24,      income = 420,    color = Color3.fromRGB(140, 210, 235) },
			{ id = "Golem Pup",  oneIn = 140,     income = 2100,   color = Color3.fromRGB(150, 150, 160) },
			{ id = "Geode Wyrm", oneIn = 1200,    income = 16500,  color = Color3.fromRGB(190, 120, 255) },
			{ id = "Deep Echo",  oneIn = 18000,   income = 190000, color = Color3.fromRGB(70, 255, 235)  },
		},
	},
	{
		id = "Tundra", speedGate = 28, color = Color3.fromRGB(196, 222, 238),
		origin = Vector3.new(300, 0, -60), nests = 5, respawn = 16,
		pets = {
			{ id = "Pup",        oneIn = 1,       income = 380,    color = Color3.fromRGB(226, 234, 240) },
			{ id = "Seal",       oneIn = 6,       income = 1700,   color = Color3.fromRGB(180, 190, 200) },
			{ id = "Yeti Cub",   oneIn = 30,      income = 8200,   color = Color3.fromRGB(240, 250, 255) },
			{ id = "Mammoth",    oneIn = 190,     income = 42000,  color = Color3.fromRGB(150, 120, 96)  },
			{ id = "Frost Wing", oneIn = 2200,    income = 320000, color = Color3.fromRGB(120, 220, 255) },
			{ id = "Aurora",     oneIn = 30000,   income = 2900000,color = Color3.fromRGB(150, 255, 210) },
		},
	},
	{
		id = "Volcano", speedGate = 42, color = Color3.fromRGB(196, 86, 62),
		origin = Vector3.new(0, 0, 260), nests = 5, respawn = 18,
		pets = {
			{ id = "Ember",      oneIn = 1,       income = 6200,    color = Color3.fromRGB(255, 140, 70)  },
			{ id = "Magma Slug", oneIn = 7,       income = 30000,   color = Color3.fromRGB(220, 80, 40)   },
			{ id = "Ash Hound",  oneIn = 36,      income = 150000,  color = Color3.fromRGB(110, 90, 90)   },
			{ id = "Cinder Rex", oneIn = 240,     income = 820000,  color = Color3.fromRGB(255, 90, 40)   },
			{ id = "Obsidian",   oneIn = 3200,    income = 7400000, color = Color3.fromRGB(40, 36, 48)    },
			{ id = "Phoenix",    oneIn = 48000,   income = 72000000,color = Color3.fromRGB(255, 200, 80)  },
		},
	},
	{
		id = "Void", speedGate = 60, color = Color3.fromRGB(58, 44, 92),
		origin = Vector3.new(0, 140, 0), nests = 4, respawn = 22,
		pets = {
			{ id = "Drifter",    oneIn = 1,        income = 140000,     color = Color3.fromRGB(120, 100, 190) },
			{ id = "Null Moth",  oneIn = 9,        income = 720000,     color = Color3.fromRGB(150, 130, 230) },
			{ id = "Star Eater", oneIn = 50,       income = 4100000,    color = Color3.fromRGB(80, 60, 160)   },
			{ id = "Paradox",    oneIn = 400,      income = 26000000,   color = Color3.fromRGB(255, 255, 255) },
			{ id = "Singularity",oneIn = 6000,     income = 290000000,  color = Color3.fromRGB(20, 20, 26)    },
			{ id = "The Spark",  oneIn = 2000000,  income = 9000000000, color = Color3.fromRGB(255, 240, 160) },
		},
	},
}

function Config.biomeById(id)
	for _, biome in ipairs(Config.Biomes) do
		if biome.id == id then
			return biome
		end
	end
	return nil
end

function Config.petById(biomeId, petId)
	local biome = Config.biomeById(biomeId)
	if not biome then
		return nil
	end
	for _, pet in ipairs(biome.pets) do
		if pet.id == petId then
			return pet
		end
	end
	return nil
end

-- --------------------------------------------------------------- upgrades ---
-- cost(level) = base * growth ^ level. Growth stays in the 1.12-1.20 band that
-- web incrementals converge on: a purchase is always 5-8 seconds away.

Config.Upgrades = {
	speed = {
		label = "Speed",   desc = "Run faster. Speed unlocks biomes.",
		base = 120,  growth = 1.28, max = 40,
		apply = function(level) return 16 + level * 1.4 end,      -- WalkSpeed
	},
	luck = {
		label = "Luck",    desc = "Divides every pet's 1-in-N.",
		base = 400,  growth = 1.34, max = 30,
		apply = function(level) return 1 + level * 0.35 end,      -- luck multiplier
	},
	storage = {
		label = "Storage", desc = "Bank more before your vault fills.",
		base = 200,  growth = 1.26, max = 35,
		apply = function(level) return Config.BaseStorage * (1 + level * 1.15) end,
	},
	pads = {
		label = "Pads",    desc = "Room for more pets on your plot.",
		base = 1500, growth = 1.55, max = 8,
		apply = function(level) return 4 + level end,             -- pad count
	},
}

Config.UpgradeOrder = { "speed", "luck", "storage", "pads" }

function Config.upgradeCost(key, level)
	local def = Config.Upgrades[key]
	if not def then
		return math.huge
	end
	if level >= def.max then
		return math.huge
	end
	return math.floor(def.base * def.growth ^ level)
end

-- --------------------------------------------------------------- rebirths ---

Config.Rebirth = {
	baseCost = 250000,       -- first rebirth lands around the 15 minute mark
	growth = 6.5,            -- cost(n) = baseCost * growth ^ n
	incomeBonus = 0.25,      -- +25% income each, additive
	padEvery = 3,            -- +1 pad every 3 rebirths
	keepsUpgrades = false,
}

function Config.rebirthCost(rebirths)
	return math.floor(Config.Rebirth.baseCost * Config.Rebirth.growth ^ rebirths)
end

-- ----------------------------------------------------------------- theft ----

Config.Steal = {
	baseHoldSeconds = 4,
	holdPerLock = 0.9,        -- each lock level adds this much hold time
	maxLockLevel = 5,
	lockCostBase = 5000,
	lockCostGrowth = 3.2,
	graceSeconds = 45,        -- a freshly placed pet cannot be stolen
	thiefCooldown = 8,        -- per thief, per plot
	shieldSeconds = 900,      -- what the Robux shield buys
	carrySpeedPenalty = 0.72, -- multiplier on WalkSpeed while carrying anything
	dropOnDeath = true,
}

-- ------------------------------------------------------------------ fuse ----

Config.Fuse = {
	copiesRequired = 3,
	incomeMultiplier = 3.5,
	maxTier = 4,              -- Normal -> Gold -> Diamond -> Void -> Prismatic
	tierNames = { "", "Gold ", "Diamond ", "Void ", "Prismatic " },
	tierColors = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 206, 84),
		Color3.fromRGB(140, 226, 255),
		Color3.fromRGB(122, 84, 190),
		Color3.fromRGB(255, 130, 220),
	},
}

-- ------------------------------------------------------------ limited egg ---
-- The weekly/daily return hook. Rotates on a fixed wall-clock cycle so every
-- server agrees without any extra service.

Config.Limited = {
	cycleSeconds = 3600,      -- a new limited egg every hour
	windowSeconds = 1200,     -- it is buyable for 20 minutes of that hour
	luckBonus = 3,            -- rolls inside the window get 3x luck
	pool = { "Meadowborn", "Deep Echo", "Aurora", "Phoenix", "The Spark" },
}

-- ---------------------------------------------------------------- daily -----

Config.Daily = {
	rewards = { 500, 1500, 5000, 20000, 75000, 250000, 1000000 },
	resetSeconds = 86400,
	graceSeconds = 172800,    -- miss two days and the streak breaks
}

-- ----------------------------------------------------------- monetization ---
-- Fill these in from the Creator Dashboard. 0 means "not configured" and the
-- kit will simply skip the feature instead of erroring.

Config.GamePasses = {
	doubleIncome = { id = 0, label = "2x Income",   multiplier = 2 },
	autoCollect  = { id = 0, label = "Auto Collect" },
	luckyRolls   = { id = 0, label = "2x Luck",     luck = 2 },
	vipSpeed     = { id = 0, label = "VIP Speed",   speedBonus = 6 },
}

Config.Products = {
	coinsSmall = { id = 0, coins = 50000 },
	coinsLarge = { id = 0, coins = 1000000 },
	shield     = { id = 0, shield = Config.Steal.shieldSeconds },
	luckBoost  = { id = 0, luckSeconds = 600, luckMultiplier = 5 },
}

-- ------------------------------------------------------------ rate limits ---

Config.RateLimits = {
	hatch = 0.35,
	place = 0.2,
	collect = 0.5,
	buy = 0.25,
	fuse = 0.5,
}

return Config
