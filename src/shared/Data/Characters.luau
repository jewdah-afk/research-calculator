--!strict
--[[
	Characters.luau

	REFERENCE DATA, NOT SHIPPED CONTENT.
	GENERATED FILE -- do not edit by hand.
	Regenerate with: python3 tools/gen_luau_data.py research/vs src/shared/Data

	source JSON    : characters.json
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

export type BaseStats = {
	maxHealth: number?,
	recovery: number?,
	armor: number?,
	moveSpeed: number?,
	might: number?,
	area: number?,
	speed: number?,
	duration: number?,
	amount: number?,
	cooldown: number?,
	luck: number?,
	growth: number?,
	greed: number?,
	magnet: number?,
	revival: number?,
	curse: number?,
}

export type LevelBonus = { level: number, stat: string, value: number }

export type Character = {
	name: string,
	id: string,
	startingWeaponId: string,
	unlockCondition: string | Unknown,
	unlockCost: number | Unknown,
	baseStats: BaseStats,
	levelBonuses: { LevelBonus },
	passiveAbility: string | Unknown,
	sourceIds: { string }?,
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

local Characters = {
	schemaVersion = 1,
	game = "Vampire Survivors",
	scope = "base game (no DLC)",
	sources = {
		{
			id = "vst-chardata",
			url = "https://raw.githubusercontent.com/jerek/vampire-survivors-tools/main/src/js/VST/VS/Character.js",
			retrieved = "2026-09-19",
		},
		{
			id = "vs-build-planner",
			url = "https://raw.githubusercontent.com/Danmer/vs-build-planner/main/data.js",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-mirror-characters",
			url = "https://raw.githubusercontent.com/NobleStripes/Survivors-Helper/main/data/raw/wiki/characters.wikitext",
			retrieved = "2026-09-19",
		},
		{
			id = "official-wiki-mirror-achievements",
			url = "https://raw.githubusercontent.com/NobleStripes/Survivors-Helper/main/data/raw/wiki/achievements.wikitext",
			retrieved = "2026-09-19",
		},
		{
			id = "websearch-wiki-summary",
			url = "https://vampire.survivors.wiki/w/Characters",
			retrieved = "2026-09-19",
		},
	} :: { any },
	notes = "vampire.survivors.wiki, vampire-survivors.fandom.com, GameFAQs and steamcommunity.com are all blocked by this session's egress proxy; direct fetches failed. Primary numbers therefore come from a decompiled/extracted copy of the game's own character table (vst-chardata), cross-checked against a community build planner and against a verbatim mirror of the official wiki's Characters/Achievements pages fetched over raw.githubusercontent.com. CONVENTIONS: multiplier stats (might, area, speed, duration, cooldown, luck, growth, greed, curse, moveSpeed) are stored as MULTIPLIERS (1 = unmodified, 1.3 = +30%). maxHealth is flat HP. recovery is flat HP/sec. armor, amount, revival are flat integers. magnet is an additive fractional bonus (0 = unmodified, 0.25 = +25% pickup radius). levelBonuses values are DELTAS applied to the stat at that level (e.g. {stat:'might', value:0.1} = +0.1 to the might multiplier). Source field names map as: power->might, regen->recovery, maxHp->maxHealth, revivals->revival.",
	conflicts = {
		{
			field = "data.pasqualina.passiveAbility",
			values = {
				"Projectiles get 10% faster every 5 levels (max +30%)",
				"+10% Projectile Speed every 5 levels, maximum +40%",
			},
			sourceIds = {
				"vst-chardata",
				"websearch-wiki-summary",
			},
			note = "Game data shows base speed 1.1 plus +0.1 at levels 5/10/15 = 1.4 total. Reading the base 1.1 as part of the ability gives '+40% max'; counting only the level-ups gives '+30% max'. Both statements describe the same numbers.",
		},
		{
			field = "data.antonio.baseStats.maxHealth",
			values = {
				120,
				100,
			},
			sourceIds = {
				"vst-chardata",
				"websearch-wiki-summary",
			},
			note = "Wiki phrasing is '+20 Max Health' relative to the 100 default; the absolute value is 120. Not a real disagreement, recorded for clarity.",
		},
		{
			field = "data.*.unlockCost",
			values = {
				"fixed listed price",
				"price increases +10% additively per character already purchased",
			},
			sourceIds = {
				"vs-build-planner",
				"official-wiki-mirror-characters",
			},
			note = "unlockCost is the BASE price. The wiki states every purchasable character's price rises by 10% additively for each character already bought.",
		},
	} :: { any },
	unknowns = {
		"data.arca.unlockCost (base price cross-check from an official source; 500 taken from vs-build-planner only)",
		"data.porta.unlockCost (same as above)",
		"data.gennaro.unlockCost (same as above)",
	},
	data = {
		antonio = {
			name = "Antonio Belpaese",
			id = "antonio",
			startingWeaponId = "whip",
			unlockCondition = "Available from the start (first character a new player uses)",
			unlockCost = 0,
			baseStats = {
				maxHealth = 120,
				recovery = 0,
				armor = 1,
				moveSpeed = 1,
				might = 1,
				area = 1,
				speed = 1,
				duration = 1,
				amount = 0,
				cooldown = 1,
				luck = 1,
				growth = 1,
				greed = 1,
				magnet = 0,
				revival = 0,
				curse = 1,
			},
			levelBonuses = {
				{
					level = 10,
					stat = "might",
					value = 0.1,
				},
				{
					level = 20,
					stat = "might",
					value = 0.1,
				},
				{
					level = 20,
					stat = "growth",
					value = 1,
				},
				{
					level = 21,
					stat = "growth",
					value = -1,
				},
				{
					level = 30,
					stat = "might",
					value = 0.1,
				},
				{
					level = 40,
					stat = "might",
					value = 0.1,
				},
				{
					level = 40,
					stat = "growth",
					value = 1,
				},
				{
					level = 41,
					stat = "growth",
					value = -1,
				},
				{
					level = 50,
					stat = "might",
					value = 0.1,
				},
			} :: { any },
			levelBonusCap = {
				stat = "might",
				maxTotal = 0.5,
				lastLevel = 50,
			},
			passiveAbility = "Gains 10% more damage (Might) every 10 levels, up to +50% at level 50.",
			sourceIds = {
				"vst-chardata",
				"vs-build-planner",
				"official-wiki-mirror-characters",
			},
		},
		imelda = {
			name = "Imelda Belpaese",
			id = "imelda",
			startingWeaponId = "magic_wand",
			unlockCondition = "Unlocked by default; must be purchased with gold",
			unlockCost = 10,
			baseStats = {
				maxHealth = 100,
				recovery = 0,
				armor = 0,
				moveSpeed = 1,
				might = 1,
				area = 1,
				speed = 1,
				duration = 1,
				amount = 0,
				cooldown = 1,
				luck = 1,
				growth = 1,
				greed = 1,
				magnet = 0,
				revival = 0,
				curse = 1,
			},
			levelBonuses = {
				{
					level = 5,
					stat = "growth",
					value = 0.1,
				},
				{
					level = 10,
					stat = "growth",
					value = 0.1,
				},
				{
					level = 15,
					stat = "growth",
					value = 0.1,
				},
				{
					level = 20,
					stat = "growth",
					value = 1,
				},
				{
					level = 21,
					stat = "growth",
					value = -1,
				},
				{
					level = 40,
					stat = "growth",
					value = 1,
				},
				{
					level = 41,
					stat = "growth",
					value = -1,
				},
			} :: { any },
			levelBonusCap = {
				stat = "growth",
				maxTotal = 0.3,
				lastLevel = 15,
			},
			passiveAbility = "Gains 10% more experience (Growth) every 5 levels, up to +30% at level 15.",
			sourceIds = {
				"vst-chardata",
				"vs-build-planner",
			},
		},
		pasqualina = {
			name = "Pasqualina Belpaese",
			id = "pasqualina",
			startingWeaponId = "runetracer",
			unlockCondition = "Unlocked by default; must be purchased with gold",
			unlockCost = 100,
			baseStats = {
				maxHealth = 100,
				recovery = 0,
				armor = 0,
				moveSpeed = 1,
				might = 1,
				area = 1,
				speed = 1.1,
				duration = 1,
				amount = 0,
				cooldown = 1,
				luck = 1,
				growth = 1,
				greed = 1,
				magnet = 0,
				revival = 0,
				curse = 1,
			},
			levelBonuses = {
				{
					level = 5,
					stat = "speed",
					value = 0.1,
				},
				{
					level = 10,
					stat = "speed",
					value = 0.1,
				},
				{
					level = 15,
					stat = "speed",
					value = 0.1,
				},
				{
					level = 20,
					stat = "growth",
					value = 1,
				},
				{
					level = 21,
					stat = "growth",
					value = -1,
				},
				{
					level = 40,
					stat = "growth",
					value = 1,
				},
				{
					level = 41,
					stat = "growth",
					value = -1,
				},
			} :: { any },
			levelBonusCap = {
				stat = "speed",
				maxTotal = 0.3,
				lastLevel = 15,
			},
			passiveAbility = "Starts with +10% Projectile Speed; projectiles get 10% faster every 5 levels, for a further +30% by level 15 (1.4x total).",
			sourceIds = {
				"vst-chardata",
				"vs-build-planner",
			},
		},
		gennaro = {
			name = "Gennaro Belpaese",
			id = "gennaro",
			startingWeaponId = "knife",
			unlockCondition = "Unlocked by default; must be purchased with gold",
			unlockCost = 500,
			baseStats = {
				maxHealth = 120,
				recovery = 0,
				armor = 0,
				moveSpeed = 1,
				might = 1,
				area = 1,
				speed = 1,
				duration = 1,
				amount = 1,
				cooldown = 1,
				luck = 1,
				growth = 1,
				greed = 1,
				magnet = 0,
				revival = 0,
				curse = 1,
			},
			levelBonuses = {
				{
					level = 20,
					stat = "growth",
					value = 1,
				},
				{
					level = 21,
					stat = "growth",
					value = -1,
				},
				{
					level = 40,
					stat = "growth",
					value = 1,
				},
				{
					level = 41,
					stat = "growth",
					value = -1,
				},
			} :: { any },
			levelBonusCap = UNKNOWN,
			passiveAbility = "Permanent +1 Amount (one extra projectile on all weapons). Also starts with +20 Max Health. No scaling level-up bonus.",
			sourceIds = {
				"vst-chardata",
				"vs-build-planner",
			},
		},
		arca = {
			name = "Arca Ladonna",
			id = "arca",
			startingWeaponId = "fire_wand",
			unlockCondition = "Get Fire Wand to Level 4 (achievement 'Arca'), then purchase with gold",
			unlockCost = 500,
			baseStats = {
				maxHealth = 100,
				recovery = 0,
				armor = 0,
				moveSpeed = 1,
				might = 1.1,
				area = 1,
				speed = 1,
				duration = 1,
				amount = 0,
				cooldown = 1,
				luck = 1,
				growth = 1,
				greed = 1,
				magnet = 0,
				revival = 0,
				curse = 1,
			},
			levelBonuses = {
				{
					level = 10,
					stat = "cooldown",
					value = -0.05,
				},
				{
					level = 20,
					stat = "cooldown",
					value = -0.05,
				},
				{
					level = 20,
					stat = "growth",
					value = 1,
				},
				{
					level = 21,
					stat = "growth",
					value = -1,
				},
				{
					level = 30,
					stat = "cooldown",
					value = -0.05,
				},
				{
					level = 40,
					stat = "growth",
					value = 1,
				},
				{
					level = 41,
					stat = "growth",
					value = -1,
				},
			} :: { any },
			levelBonusCap = {
				stat = "cooldown",
				maxTotal = -0.15,
				lastLevel = 30,
			},
			passiveAbility = "Starts with +10% Might. Weapon cooldown is reduced by 5% every 10 levels, up to -15% at level 30.",
			sourceIds = {
				"vst-chardata",
				"vs-build-planner",
				"official-wiki-mirror-achievements",
			},
		},
		porta = {
			name = "Porta Ladonna",
			id = "porta",
			startingWeaponId = "lightning_ring",
			unlockCondition = "Get Lightning Ring to Level 4 (achievement 'Porta'), then purchase with gold",
			unlockCost = 500,
			baseStats = {
				maxHealth = 100,
				recovery = 0,
				armor = 0,
				moveSpeed = 1,
				might = 1,
				area = 1.3,
				speed = 1,
				duration = 1,
				amount = 0,
				cooldown = 0.1,
				luck = 1,
				growth = 1,
				greed = 1,
				magnet = 0,
				revival = 0,
				curse = 1,
			},
			levelBonuses = {
				{
					level = 2,
					stat = "cooldown",
					value = 0.3,
				},
				{
					level = 3,
					stat = "cooldown",
					value = 0.3,
				},
				{
					level = 4,
					stat = "cooldown",
					value = 0.3,
				},
				{
					level = 20,
					stat = "growth",
					value = 1,
				},
				{
					level = 21,
					stat = "growth",
					value = -1,
				},
				{
					level = 40,
					stat = "growth",
					value = 1,
				},
				{
					level = 41,
					stat = "growth",
					value = -1,
				},
			} :: { any },
			levelBonusCap = {
				stat = "cooldown",
				maxTotal = 0.9,
				lastLevel = 4,
			},
			passiveAbility = "Permanent +30% Area. Starts at 0.1x Cooldown (a temporary -90% cooldown), which decays back to 1.0x by gaining +0.3 at each of levels 2, 3 and 4.",
			sourceIds = {
				"vst-chardata",
				"vs-build-planner",
				"official-wiki-mirror-achievements",
			},
		},
	},
	omitted = {},
	sourceJson = "characters.json",
	gameVersion = "v1.16",
	retrieved = "2026-09-19",
	UNKNOWN = UNKNOWN,
}

deepFreeze(Characters)

return Characters
