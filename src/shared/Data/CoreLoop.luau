--!strict
--[[
	CoreLoop.luau

	REFERENCE DATA, NOT SHIPPED CONTENT.
	GENERATED FILE -- do not edit by hand.
	Regenerate with: python3 tools/gen_luau_data.py research/vs src/shared/Data

	source JSON    : core_loop.json
	schemaVersion  : 1
	game version   : 1.16
	scope          : base game (no DLC) -- base game, no DLC
	retrieved      : 2026-09-19

	REFERENCE DATA ONLY. This module lives under src/shared/Data as a reference
	corpus for deriving our own balance. These are mechanics reference points for
	deriving original balance, NOT values to ship verbatim. Nothing here is
	in-game-facing content: no names, art, audio or assets are shipped from it.

	CONVENTIONS
	* DISPLAY_SCALE = 10 is the single global damage/health convention, applied
	  uniformly to weapon damage and enemy health in Weapons and EnemiesWaves.
	  This module rescales nothing: every number in it is a raw shipped value, so
	  it neither applies that scale nor exports a `displayScale` field.
	* All in-run times are SECONDS as plain numbers (10:00 -> 600).
	* A field that is null in the source JSON is emitted as the sentinel
	  `M.UNKNOWN` -- never 0, never false, never an invented number.
	* `unknowns` lists the dotted paths that are unknown in the source.
	* `conflicts` retains every conflicting value; nothing was silently dropped.
	* `sourceIds` is carried through verbatim, so websearch-derived (unverified)
	  values stay distinguishable from game-data-v1.16 values.
	* The `notes` and `conflicts` strings below are source-JSON text, carried over
	  verbatim EXCEPT for the reviewed rewrites in the generator's PROSE_REWRITES,
	  which re-word the sentences that named a key this module renames (AC-09) or
	  that called a rescaled field "raw" (AC-10).
]]

--- Sentinel for "not present in the source data". Never 0, never false.
local UNKNOWN = table.freeze(setmetatable({}, {
	__tostring = function(): string
		return "UNKNOWN"
	end,
}))

export type Unknown = typeof(UNKNOWN)
export type Conflict = {
	field: string,
	values: { any },
	sourceIds: { string }?,
	note: string?,
}

local function deepFreeze<T>(value: T): T
	if type(value) == "table" then
		for _, v in pairs(value :: any) do
			deepFreeze(v)
		end
		if not table.isfrozen(value :: any) then
			table.freeze(value :: any)
		end
	end
	return value
end

local CoreLoop = {
	schemaVersion = 1,
	game = "Vampire Survivors",
	scope = "base game (no DLC)",
	sources = {
		{
			id = "official-wiki-levelup",
			url = "https://vampire.survivors.wiki/w/Level_up",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-gem",
			url = "https://vampire.survivors.wiki/w/Experience_Gem",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-growth",
			url = "https://vampire.survivors.wiki/w/Growth",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-magnet",
			url = "https://vampire.survivors.wiki/w/Magnet",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-reaper",
			url = "https://vampire.survivors.wiki/w/The_Reaper",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-skip",
			url = "https://vampire.survivors.wiki/w/Skip",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-reroll",
			url = "https://vampire.survivors.wiki/w/Reroll",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-banish",
			url = "https://vampire.survivors.wiki/w/Banish",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-powerups",
			url = "https://vampire.survivors.wiki/w/PowerUps",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-luck",
			url = "https://vampire.survivors.wiki/w/Luck",
			retrieved = "2026-09-19",
		},
		{
			id = "fandom-weapons",
			url = "https://vampire-survivors.fandom.com/wiki/Weapons",
			retrieved = "2026-09-19",
		},
		{
			id = "steam-gemcap",
			url = "https://steamcommunity.com/app/1794680/discussions/0/3201496371582426598/",
			retrieved = "2026-09-19",
		},
	} :: { any },
	notes = "Times in seconds. Growth/Luck percentages stored as multipliers where the game multiplies (growthBase 1.0) and as fractional deltas where additive. All wiki/Steam domains were blocked by the network egress proxy; figures come from search-engine extracts of the cited pages.",
	conflicts = {
		{
			field = "data.levelUp.xpGrantedInsteadOfItem",
			values = {
				0.2,
				0.2,
			},
			sourceIds = {
				"official-wiki-skip",
			},
			note = "Search extracts of the Skip page attribute the 20%-of-next-level XP grant to Skip in one phrasing and to 'Reroll and Banish' in another. Value identical (0.20); which options grant it is ambiguous.",
		},
		{
			field = "data.xpGems.tiers[].xp",
			values = {
				"ranges: blue<=2, green<=9, red>9",
				"flat: blue=1, green=5, red=10",
			},
			sourceIds = {
				"official-wiki-gem",
				"steam-gemcap",
			},
			note = "Wikis give ranges; older community posts claim flat 1/5/10. Ranges treated as authoritative.",
		},
	} :: { any },
	unknowns = {
		"data.xpGems.tiers[0].xpExact",
		"data.xpGems.tiers[1].xpExact",
		"data.xpGems.tiers[2].xpExact",
		"data.levelUp.fourthOptionChanceFormulaOfficial",
		"data.runStructure.reaper.speed",
		"data.xpGems.merging.maxGemsOnMapConfirmedByWiki",
		"data.magnet.unitDefinition",
	},
	data = {
		runStructure = {
			sourceIds = {
				"official-wiki-reaper",
			},
			stageTimeLimit = 1800,
			atTimeLimit = "A Reaper (Red Death) spawns unless Endless mode is active",
			reaper = {
				name = "The Reaper",
				id = "the_reaper",
				health = 655350,
				healthScalesWithPlayerLevel = true,
				power = 65535,
				speed = UNKNOWN,
				spawnIntervalAfterLimit = 60,
				extraReaperPerMinute = true,
				killable = true,
				intendedKillable = false,
				onKilledFollowup = "Screen zooms in, 12 bells toll, an unhittable 'White Hand' reaper instantly kills the player",
				isBoss = true,
			},
			survivalGoldReward = 500,
			revivalGoldBonusPerRevive = 100,
		},
		levelUp = {
			sourceIds = {
				"official-wiki-levelup",
				"official-wiki-luck",
				"official-wiki-skip",
				"official-wiki-reroll",
				"official-wiki-banish",
				"official-wiki-powerups",
			},
			pausesGame = true,
			optionsOffered = {
				min = 3,
				max = 4,
			},
			fourthOptionChanceFormula = "luck / (100 + luck), luck in percentage points including the 100 base",
			fourthOptionChanceFormulaOfficial = UNKNOWN,
			optionsAreUnique = true,
			xpGrantedInsteadOfItem = 0.2,
			reroll = {
				effect = "Reshuffle the current offer",
				powerUpPerRank = 2,
				maxRank = 5,
				maxTotal = 10,
				firstRankCost = 1000,
			},
			banish = {
				effect = "Permanently remove an item from this run's offer pool",
				powerUpPerRank = 2,
				maxRank = 5,
				maxTotal = 10,
				firstRankCost = 100,
			},
			skip = {
				effect = "Decline the offer and gain XP instead",
				powerUpPerRank = 2,
				maxRank = 5,
				maxTotal = 10,
				firstRankCost = 100,
			},
			powerUpCostScaling = "Each rank purchased increases the next rank's base cost by the initial price",
			whenSlotsFull = "No new items of that type are offered; only upgrades to already-owned items",
			limitBreak = "When nothing remains to upgrade and Limit Break is active, extra levels on maxed weapons are offered",
		},
		slots = {
			sourceIds = {
				"official-wiki-levelup",
				"fandom-weapons",
			},
			weaponSlots = 6,
			passiveSlots = 6,
			maxWeaponLevel = 8,
			maxPassiveLevel = 5,
			notes = "Max weapon level 8 is the typical value; individual weapons may differ.",
		},
		xpGems = {
			sourceIds = {
				"official-wiki-gem",
				"official-wiki-growth",
				"steam-gemcap",
			},
			growthBase = 1,
			growthStacking = "additive",
			tiers = {
				{
					tier = 1,
					color = "blue",
					xpMin = 1,
					xpMax = 2,
					xpExact = UNKNOWN,
				},
				{
					tier = 2,
					color = "green",
					xpMin = 3,
					xpMax = 9,
					xpExact = UNKNOWN,
				},
				{
					tier = 3,
					color = "red",
					xpMin = 10,
					xpMax = UNKNOWN,
					xpExact = UNKNOWN,
				},
			} :: { any },
			merging = {
				maxGemsOnMap = 400,
				maxGemsOnMapConfirmedByWiki = UNKNOWN,
				behaviorAtCap = "One existing gem is converted to a red gem and absorbs the value of all subsequent gem drops",
				gemsDespawn = false,
				sourceIds = {
					"steam-gemcap",
				},
			},
		},
		magnet = {
			sourceIds = {
				"official-wiki-magnet",
			},
			base = 30,
			stacking = "multiplicative",
			cap = UNKNOWN,
			unitDefinition = UNKNOWN,
			description = "Radius within which experience gems and other pickups are collected",
		},
		experienceCurve = {
			sourceIds = {
				"official-wiki-levelup",
				"official-wiki-growth",
			},
			formula = "base(n) = 5+10*(n-1) for n<=20; 195+13*(n-20) for 21<=n<=40; 455+16*(n-40) for n>=41. req(n) = base(n) + 600 if n==20, + 2400 if n==40.",
			firstLevelUpXp = 5,
			incrementTier1 = 10,
			incrementTier2 = 13,
			incrementTier3 = 16,
			breakpoints = {
				{
					level = 20,
					extraXp = 600,
					growthBonus = 1,
					note = "+100% Growth granted at level 20, reverted (-100%) at level 21",
				},
				{
					level = 40,
					extraXp = 2400,
					growthBonus = 1,
					note = "+100% Growth granted at level 40, reverted (-100%) at level 41",
				},
			} :: { any },
			table = {
				{
					level = 1,
					xpToNextLevel = 5,
					extraSurcharge = 0,
					cumulativeXp = 5,
					xpRequired = 5,
				},
				{
					level = 2,
					xpToNextLevel = 15,
					extraSurcharge = 0,
					cumulativeXp = 20,
					xpRequired = 15,
				},
				{
					level = 3,
					xpToNextLevel = 25,
					extraSurcharge = 0,
					cumulativeXp = 45,
					xpRequired = 25,
				},
				{
					level = 4,
					xpToNextLevel = 35,
					extraSurcharge = 0,
					cumulativeXp = 80,
					xpRequired = 35,
				},
				{
					level = 5,
					xpToNextLevel = 45,
					extraSurcharge = 0,
					cumulativeXp = 125,
					xpRequired = 45,
				},
				{
					level = 6,
					xpToNextLevel = 55,
					extraSurcharge = 0,
					cumulativeXp = 180,
					xpRequired = 55,
				},
				{
					level = 7,
					xpToNextLevel = 65,
					extraSurcharge = 0,
					cumulativeXp = 245,
					xpRequired = 65,
				},
				{
					level = 8,
					xpToNextLevel = 75,
					extraSurcharge = 0,
					cumulativeXp = 320,
					xpRequired = 75,
				},
				{
					level = 9,
					xpToNextLevel = 85,
					extraSurcharge = 0,
					cumulativeXp = 405,
					xpRequired = 85,
				},
				{
					level = 10,
					xpToNextLevel = 95,
					extraSurcharge = 0,
					cumulativeXp = 500,
					xpRequired = 95,
				},
				{
					level = 11,
					xpToNextLevel = 105,
					extraSurcharge = 0,
					cumulativeXp = 605,
					xpRequired = 105,
				},
				{
					level = 12,
					xpToNextLevel = 115,
					extraSurcharge = 0,
					cumulativeXp = 720,
					xpRequired = 115,
				},
				{
					level = 13,
					xpToNextLevel = 125,
					extraSurcharge = 0,
					cumulativeXp = 845,
					xpRequired = 125,
				},
				{
					level = 14,
					xpToNextLevel = 135,
					extraSurcharge = 0,
					cumulativeXp = 980,
					xpRequired = 135,
				},
				{
					level = 15,
					xpToNextLevel = 145,
					extraSurcharge = 0,
					cumulativeXp = 1125,
					xpRequired = 145,
				},
				{
					level = 16,
					xpToNextLevel = 155,
					extraSurcharge = 0,
					cumulativeXp = 1280,
					xpRequired = 155,
				},
				{
					level = 17,
					xpToNextLevel = 165,
					extraSurcharge = 0,
					cumulativeXp = 1445,
					xpRequired = 165,
				},
				{
					level = 18,
					xpToNextLevel = 175,
					extraSurcharge = 0,
					cumulativeXp = 1620,
					xpRequired = 175,
				},
				{
					level = 19,
					xpToNextLevel = 185,
					extraSurcharge = 0,
					cumulativeXp = 1805,
					xpRequired = 185,
				},
				{
					level = 20,
					xpToNextLevel = 795,
					extraSurcharge = 600,
					cumulativeXp = 2600,
					xpRequired = 795,
				},
				{
					level = 21,
					xpToNextLevel = 208,
					extraSurcharge = 0,
					cumulativeXp = 2808,
					xpRequired = 208,
				},
				{
					level = 22,
					xpToNextLevel = 221,
					extraSurcharge = 0,
					cumulativeXp = 3029,
					xpRequired = 221,
				},
				{
					level = 23,
					xpToNextLevel = 234,
					extraSurcharge = 0,
					cumulativeXp = 3263,
					xpRequired = 234,
				},
				{
					level = 24,
					xpToNextLevel = 247,
					extraSurcharge = 0,
					cumulativeXp = 3510,
					xpRequired = 247,
				},
				{
					level = 25,
					xpToNextLevel = 260,
					extraSurcharge = 0,
					cumulativeXp = 3770,
					xpRequired = 260,
				},
				{
					level = 26,
					xpToNextLevel = 273,
					extraSurcharge = 0,
					cumulativeXp = 4043,
					xpRequired = 273,
				},
				{
					level = 27,
					xpToNextLevel = 286,
					extraSurcharge = 0,
					cumulativeXp = 4329,
					xpRequired = 286,
				},
				{
					level = 28,
					xpToNextLevel = 299,
					extraSurcharge = 0,
					cumulativeXp = 4628,
					xpRequired = 299,
				},
				{
					level = 29,
					xpToNextLevel = 312,
					extraSurcharge = 0,
					cumulativeXp = 4940,
					xpRequired = 312,
				},
				{
					level = 30,
					xpToNextLevel = 325,
					extraSurcharge = 0,
					cumulativeXp = 5265,
					xpRequired = 325,
				},
				{
					level = 31,
					xpToNextLevel = 338,
					extraSurcharge = 0,
					cumulativeXp = 5603,
					xpRequired = 338,
				},
				{
					level = 32,
					xpToNextLevel = 351,
					extraSurcharge = 0,
					cumulativeXp = 5954,
					xpRequired = 351,
				},
				{
					level = 33,
					xpToNextLevel = 364,
					extraSurcharge = 0,
					cumulativeXp = 6318,
					xpRequired = 364,
				},
				{
					level = 34,
					xpToNextLevel = 377,
					extraSurcharge = 0,
					cumulativeXp = 6695,
					xpRequired = 377,
				},
				{
					level = 35,
					xpToNextLevel = 390,
					extraSurcharge = 0,
					cumulativeXp = 7085,
					xpRequired = 390,
				},
				{
					level = 36,
					xpToNextLevel = 403,
					extraSurcharge = 0,
					cumulativeXp = 7488,
					xpRequired = 403,
				},
				{
					level = 37,
					xpToNextLevel = 416,
					extraSurcharge = 0,
					cumulativeXp = 7904,
					xpRequired = 416,
				},
				{
					level = 38,
					xpToNextLevel = 429,
					extraSurcharge = 0,
					cumulativeXp = 8333,
					xpRequired = 429,
				},
				{
					level = 39,
					xpToNextLevel = 442,
					extraSurcharge = 0,
					cumulativeXp = 8775,
					xpRequired = 442,
				},
				{
					level = 40,
					xpToNextLevel = 2855,
					extraSurcharge = 2400,
					cumulativeXp = 11630,
					xpRequired = 2855,
				},
				{
					level = 41,
					xpToNextLevel = 471,
					extraSurcharge = 0,
					cumulativeXp = 12101,
					xpRequired = 471,
				},
				{
					level = 42,
					xpToNextLevel = 487,
					extraSurcharge = 0,
					cumulativeXp = 12588,
					xpRequired = 487,
				},
				{
					level = 43,
					xpToNextLevel = 503,
					extraSurcharge = 0,
					cumulativeXp = 13091,
					xpRequired = 503,
				},
				{
					level = 44,
					xpToNextLevel = 519,
					extraSurcharge = 0,
					cumulativeXp = 13610,
					xpRequired = 519,
				},
				{
					level = 45,
					xpToNextLevel = 535,
					extraSurcharge = 0,
					cumulativeXp = 14145,
					xpRequired = 535,
				},
				{
					level = 46,
					xpToNextLevel = 551,
					extraSurcharge = 0,
					cumulativeXp = 14696,
					xpRequired = 551,
				},
				{
					level = 47,
					xpToNextLevel = 567,
					extraSurcharge = 0,
					cumulativeXp = 15263,
					xpRequired = 567,
				},
				{
					level = 48,
					xpToNextLevel = 583,
					extraSurcharge = 0,
					cumulativeXp = 15846,
					xpRequired = 583,
				},
				{
					level = 49,
					xpToNextLevel = 599,
					extraSurcharge = 0,
					cumulativeXp = 16445,
					xpRequired = 599,
				},
				{
					level = 50,
					xpToNextLevel = 615,
					extraSurcharge = 0,
					cumulativeXp = 17060,
					xpRequired = 615,
				},
				{
					level = 51,
					xpToNextLevel = 631,
					extraSurcharge = 0,
					cumulativeXp = 17691,
					xpRequired = 631,
				},
				{
					level = 52,
					xpToNextLevel = 647,
					extraSurcharge = 0,
					cumulativeXp = 18338,
					xpRequired = 647,
				},
				{
					level = 53,
					xpToNextLevel = 663,
					extraSurcharge = 0,
					cumulativeXp = 19001,
					xpRequired = 663,
				},
				{
					level = 54,
					xpToNextLevel = 679,
					extraSurcharge = 0,
					cumulativeXp = 19680,
					xpRequired = 679,
				},
				{
					level = 55,
					xpToNextLevel = 695,
					extraSurcharge = 0,
					cumulativeXp = 20375,
					xpRequired = 695,
				},
				{
					level = 56,
					xpToNextLevel = 711,
					extraSurcharge = 0,
					cumulativeXp = 21086,
					xpRequired = 711,
				},
				{
					level = 57,
					xpToNextLevel = 727,
					extraSurcharge = 0,
					cumulativeXp = 21813,
					xpRequired = 727,
				},
				{
					level = 58,
					xpToNextLevel = 743,
					extraSurcharge = 0,
					cumulativeXp = 22556,
					xpRequired = 743,
				},
				{
					level = 59,
					xpToNextLevel = 759,
					extraSurcharge = 0,
					cumulativeXp = 23315,
					xpRequired = 759,
				},
				{
					level = 60,
					xpToNextLevel = 775,
					extraSurcharge = 0,
					cumulativeXp = 24090,
					xpRequired = 775,
				},
				{
					level = 61,
					xpToNextLevel = 791,
					extraSurcharge = 0,
					cumulativeXp = 24881,
					xpRequired = 791,
				},
				{
					level = 62,
					xpToNextLevel = 807,
					extraSurcharge = 0,
					cumulativeXp = 25688,
					xpRequired = 807,
				},
				{
					level = 63,
					xpToNextLevel = 823,
					extraSurcharge = 0,
					cumulativeXp = 26511,
					xpRequired = 823,
				},
				{
					level = 64,
					xpToNextLevel = 839,
					extraSurcharge = 0,
					cumulativeXp = 27350,
					xpRequired = 839,
				},
				{
					level = 65,
					xpToNextLevel = 855,
					extraSurcharge = 0,
					cumulativeXp = 28205,
					xpRequired = 855,
				},
				{
					level = 66,
					xpToNextLevel = 871,
					extraSurcharge = 0,
					cumulativeXp = 29076,
					xpRequired = 871,
				},
				{
					level = 67,
					xpToNextLevel = 887,
					extraSurcharge = 0,
					cumulativeXp = 29963,
					xpRequired = 887,
				},
				{
					level = 68,
					xpToNextLevel = 903,
					extraSurcharge = 0,
					cumulativeXp = 30866,
					xpRequired = 903,
				},
				{
					level = 69,
					xpToNextLevel = 919,
					extraSurcharge = 0,
					cumulativeXp = 31785,
					xpRequired = 919,
				},
				{
					level = 70,
					xpToNextLevel = 935,
					extraSurcharge = 0,
					cumulativeXp = 32720,
					xpRequired = 935,
				},
				{
					level = 71,
					xpToNextLevel = 951,
					extraSurcharge = 0,
					cumulativeXp = 33671,
					xpRequired = 951,
				},
				{
					level = 72,
					xpToNextLevel = 967,
					extraSurcharge = 0,
					cumulativeXp = 34638,
					xpRequired = 967,
				},
				{
					level = 73,
					xpToNextLevel = 983,
					extraSurcharge = 0,
					cumulativeXp = 35621,
					xpRequired = 983,
				},
				{
					level = 74,
					xpToNextLevel = 999,
					extraSurcharge = 0,
					cumulativeXp = 36620,
					xpRequired = 999,
				},
				{
					level = 75,
					xpToNextLevel = 1015,
					extraSurcharge = 0,
					cumulativeXp = 37635,
					xpRequired = 1015,
				},
				{
					level = 76,
					xpToNextLevel = 1031,
					extraSurcharge = 0,
					cumulativeXp = 38666,
					xpRequired = 1031,
				},
				{
					level = 77,
					xpToNextLevel = 1047,
					extraSurcharge = 0,
					cumulativeXp = 39713,
					xpRequired = 1047,
				},
				{
					level = 78,
					xpToNextLevel = 1063,
					extraSurcharge = 0,
					cumulativeXp = 40776,
					xpRequired = 1063,
				},
				{
					level = 79,
					xpToNextLevel = 1079,
					extraSurcharge = 0,
					cumulativeXp = 41855,
					xpRequired = 1079,
				},
				{
					level = 80,
					xpToNextLevel = 1095,
					extraSurcharge = 0,
					cumulativeXp = 42950,
					xpRequired = 1095,
				},
				{
					level = 81,
					xpToNextLevel = 1111,
					extraSurcharge = 0,
					cumulativeXp = 44061,
					xpRequired = 1111,
				},
				{
					level = 82,
					xpToNextLevel = 1127,
					extraSurcharge = 0,
					cumulativeXp = 45188,
					xpRequired = 1127,
				},
				{
					level = 83,
					xpToNextLevel = 1143,
					extraSurcharge = 0,
					cumulativeXp = 46331,
					xpRequired = 1143,
				},
				{
					level = 84,
					xpToNextLevel = 1159,
					extraSurcharge = 0,
					cumulativeXp = 47490,
					xpRequired = 1159,
				},
				{
					level = 85,
					xpToNextLevel = 1175,
					extraSurcharge = 0,
					cumulativeXp = 48665,
					xpRequired = 1175,
				},
				{
					level = 86,
					xpToNextLevel = 1191,
					extraSurcharge = 0,
					cumulativeXp = 49856,
					xpRequired = 1191,
				},
				{
					level = 87,
					xpToNextLevel = 1207,
					extraSurcharge = 0,
					cumulativeXp = 51063,
					xpRequired = 1207,
				},
				{
					level = 88,
					xpToNextLevel = 1223,
					extraSurcharge = 0,
					cumulativeXp = 52286,
					xpRequired = 1223,
				},
				{
					level = 89,
					xpToNextLevel = 1239,
					extraSurcharge = 0,
					cumulativeXp = 53525,
					xpRequired = 1239,
				},
				{
					level = 90,
					xpToNextLevel = 1255,
					extraSurcharge = 0,
					cumulativeXp = 54780,
					xpRequired = 1255,
				},
				{
					level = 91,
					xpToNextLevel = 1271,
					extraSurcharge = 0,
					cumulativeXp = 56051,
					xpRequired = 1271,
				},
				{
					level = 92,
					xpToNextLevel = 1287,
					extraSurcharge = 0,
					cumulativeXp = 57338,
					xpRequired = 1287,
				},
				{
					level = 93,
					xpToNextLevel = 1303,
					extraSurcharge = 0,
					cumulativeXp = 58641,
					xpRequired = 1303,
				},
				{
					level = 94,
					xpToNextLevel = 1319,
					extraSurcharge = 0,
					cumulativeXp = 59960,
					xpRequired = 1319,
				},
				{
					level = 95,
					xpToNextLevel = 1335,
					extraSurcharge = 0,
					cumulativeXp = 61295,
					xpRequired = 1335,
				},
				{
					level = 96,
					xpToNextLevel = 1351,
					extraSurcharge = 0,
					cumulativeXp = 62646,
					xpRequired = 1351,
				},
				{
					level = 97,
					xpToNextLevel = 1367,
					extraSurcharge = 0,
					cumulativeXp = 64013,
					xpRequired = 1367,
				},
				{
					level = 98,
					xpToNextLevel = 1383,
					extraSurcharge = 0,
					cumulativeXp = 65396,
					xpRequired = 1383,
				},
				{
					level = 99,
					xpToNextLevel = 1399,
					extraSurcharge = 0,
					cumulativeXp = 66795,
					xpRequired = 1399,
				},
				{
					level = 100,
					xpToNextLevel = 1415,
					extraSurcharge = 0,
					cumulativeXp = 68210,
					xpRequired = 1415,
				},
			} :: { any },
		},
	},
	omitted = {},
	sourceJson = "core_loop.json",
	gameVersion = "v1.16",
	retrieved = "2026-09-19",
	UNKNOWN = UNKNOWN,
}

deepFreeze(CoreLoop)

return CoreLoop
