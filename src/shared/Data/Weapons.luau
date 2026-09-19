--!strict
--[[
	Weapons.luau

	REFERENCE DATA, NOT SHIPPED CONTENT.
	GENERATED FILE -- do not edit by hand.
	Regenerate with: python3 tools/gen_luau_data.py research/vs src/shared/Data

	source JSON    : weapons.json
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
	  uniformly to BOTH weapon damage and enemy health. Every `baseDamage` and
	  every enemy `health` in these modules is a DISPLAY-scale number
	  (shipped raw x DISPLAY_SCALE). The untouched shipped values are retained
	  alongside them as `rawPower` (weapons) and `rawHealth` (enemies). This
	  module applies the scale and exports the constant as `displayScale`.
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
	  that called a rescaled field "raw" (AC-10). They otherwise describe the
	  SOURCE's raw values: where such a string calls a health or damage figure
	  "raw", it refers to the `rawHealth` / `rawPower` field here, not to `health`
	  / `baseDamage`, which carry DISPLAY_SCALE.
]]

--- Sentinel for "not present in the source data". Never 0, never false.
local UNKNOWN = table.freeze(setmetatable({}, {
	__tostring = function(): string
		return "UNKNOWN"
	end,
}))

--- The single global damage/health scale convention (see header).
local DISPLAY_SCALE = 10

export type Unknown = typeof(UNKNOWN)
export type Conflict = {
	field: string,
	values: { any },
	sourceIds: { string }?,
	note: string?,
}

export type WeaponLevel = { level: number, changes: { [string]: any }, description: string? }

export type Weapon = {
	name: string,
	id: string,
	baseDamage: number,
	rawPower: number,
	area: number,
	speed: number,
	amount: number,
	duration: number | Unknown,
	cooldown: number,
	pierce: number | Unknown,
	knockback: number | Unknown,
	poolLimit: number,
	projectileInterval: number,
	hitboxDelay: number | Unknown,
	critChance: number | Unknown,
	critMultiplier: number | Unknown,
	intervalDependsOnDuration: boolean,
	hitsWalls: boolean | Unknown,
	ignores: string,
	targeting: string,
	maxLevel: number,
	levels: { WeaponLevel },
	sourceIds: { any },
	maxLevelTotals: { [string]: any },
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

local Weapons = {
	schemaVersion = 1,
	game = "Vampire Survivors",
	scope = "base game (no DLC)",
	sources = {
		{
			id = "game-data-v1.16",
			url = "https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json",
			retrieved = "2026-09-19",
			note = "Community rip of the game's shipped Weapon.json, game version 1.16, base-game folder (DLC data lives in separate folders). Not an official published page.",
		},
		{
			id = "official-wiki",
			url = "https://vampire.survivors.wiki/w/Weapons",
			retrieved = "2026-09-19",
			note = "Reached only through WebSearch result summaries; direct fetch blocked by the network egress proxy.",
		},
		{
			id = "fandom-wiki",
			url = "https://vampire-survivors.fandom.com/wiki/Weapons",
			retrieved = "2026-09-19",
			note = "Reached only through WebSearch result summaries.",
		},
		{
			id = "progameguides-santa-water",
			url = "https://progameguides.com/vampire-survivors/how-to-evolve-the-santa-water-in-vampire-survivors/",
			retrieved = "2026-09-19",
			note = "Tertiary guide; superseded by the shipped data.",
		},
	},
	notes = "Primary source is the game's own shipped balance file Data/Vampire Survivors/Weapon.json (game v1.16), obtained from a community rip of the game files on GitHub — authoritative but NOT an official page. In that file 'power' is a damage multiplier where displayed damage = power * 10; `baseDamage` below is the DISPLAYED value (power*10) and `rawPower` preserves the shipped multiplier. Level entries are DELTAS applied on top of the previous level, exactly as shipped. Absolute percent stats (area, speed) are multipliers (1.0 = 100%); percent CHANGES are additive fractions (areaDelta 0.1 = +10% Area). All times in seconds (shipped file stores milliseconds). 'interval' maps to cooldown, 'repeatInterval' to projectileInterval, 'penetrating' to pierce. maxLevelTotals is the summed Lv2-Lv8 delta per field. Fields absent from the shipped record are null (the weapon either ignores that stat or uses an engine default) and are listed in unknowns.",
	conflicts = {
		{
			field = "data.santa_water.cooldown",
			values = {
				4.5,
				3,
			},
			sourceIds = {
				"game-data-v1.16",
				"official-wiki",
			},
			note = "RESOLVED in favour of the shipped data: interval 4500 ms = 4.5 s. The 3.0 s figure came from a wiki search summary.",
		},
		{
			field = "data.fire_wand.amount",
			values = {
				3,
				1,
			},
			sourceIds = {
				"game-data-v1.16",
				"fandom-wiki",
			},
			note = "RESOLVED in favour of the shipped data: base amount is 3.",
		},
		{
			field = "data.santa_water.levels[*].changes.duration",
			values = {
				{
					0.5,
					0.25,
					0.25,
				},
				{
					0.5,
					0.5,
					0.3,
				},
			},
			sourceIds = {
				"game-data-v1.16",
				"progameguides-santa-water",
			},
			note = "RESOLVED in favour of the shipped data: Lv3 +0.5s, Lv5 +0.25s, Lv7 +0.25s, summing to the +1.0 s max-level total. The tertiary guide's +0.5/+0.5/+0.3 was wrong.",
		},
		{
			field = "data.runetracer.poolLimit",
			values = {
				50,
				25,
			},
			sourceIds = {
				"game-data-v1.16",
				"official-wiki",
			},
			note = "Shipped data says 50; a wiki search summary said 25. Shipped value is authoritative; the wiki figure may predate a balance patch.",
		},
		{
			field = "data.whip.critChance / data.whip.critMultiplier",
			values = {
				{
					0.2,
					2,
				},
				{
					0.2,
					4,
				},
			},
			sourceIds = {
				"game-data-v1.16",
				"official-wiki",
			},
			note = "Shipped data gives Whip an INNATE 20% crit chance at 2x damage. Wiki summaries described 20%/4x as granted by the Slash (XVI) Arcana. Both recorded; the 2x innate value is the shipped one.",
		},
		{
			field = "data.axe.critMultiplier",
			values = {
				2,
				4,
			},
			sourceIds = {
				"game-data-v1.16",
				"official-wiki",
			},
			note = "Shipped data: innate 30% chance at 2x. Wiki described 30%/4x via Slash (XVI).",
		},
		{
			field = "data.knife.critChance",
			values = {
				0.3,
				UNKNOWN,
			},
			sourceIds = {
				"game-data-v1.16",
				"official-wiki",
			},
			note = "Shipped data gives Knife an innate 30% crit at 3x; no wiki summary mentioned Knife crits.",
		},
		{
			field = "data.whip.evolution",
			values = {
				"VAMPIRICA",
				"Bloody Tear",
			},
			sourceIds = {
				"game-data-v1.16",
				"official-wiki",
			},
			note = "Internal id vs display name; not a real disagreement.",
		},
	},
	unknowns = {
		"data.whip.duration",
		"data.whip.pierce",
		"data.whip.knockback",
		"data.magic_wand.duration",
		"data.magic_wand.knockback",
		"data.knife.duration",
		"data.axe.knockback",
		"data.runetracer.pierce",
		"data.runetracer.knockback",
		"data.fire_wand.pierce",
		"data.fire_wand.knockback",
		"data.king_bible.pierce",
		"data.king_bible.knockback",
		"data.garlic.pierce",
		"data.santa_water.pierce",
		"data.lightning_ring.duration",
		"data.lightning_ring.pierce",
		"data.lightning_ring.knockback",
		"data.cross.duration",
		"data.cross.pierce",
		"data.cross.knockback",
		"Weapons whose record omits 'penetrating' are area-of-effect or infinite-pierce in behaviour; the shipped file carries no numeric pierce for them, so it is null rather than 1.",
		"Weapons whose record omits 'knockback' use an engine default not present in the shipped file.",
	},
	data = {
		whip = {
			name = "Whip",
			id = "whip",
			baseDamage = 10,
			rawPower = 1,
			area = 1,
			speed = 1,
			amount = 1,
			duration = UNKNOWN,
			cooldown = 1.35,
			pierce = UNKNOWN,
			knockback = UNKNOWN,
			poolLimit = 30,
			projectileInterval = 0.1,
			hitboxDelay = UNKNOWN,
			critChance = 0.2,
			critMultiplier = 2,
			intervalDependsOnDuration = false,
			hitsWalls = false,
			ignores = "Ignores: Speed, Duration.",
			targeting = "Slashes horizontally from the character's torso in the facing direction; area-of-effect, passes through all enemies in the rectangle. Extra slashes from Amount alternate between firing toward and away from the facing direction, each placed progressively higher. Ignores Speed and Duration.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 3,
					changes = {
						baseDamage = 5,
					},
					description = "+5 Damage.",
				},
				{
					level = 4,
					changes = {
						baseDamage = 5,
						areaDelta = 0.1,
					},
					description = "+5 Damage, +10% Area.",
				},
				{
					level = 5,
					changes = {
						baseDamage = 5,
					},
					description = "+5 Damage.",
				},
				{
					level = 6,
					changes = {
						baseDamage = 5,
						areaDelta = 0.1,
					},
					description = "+5 Damage, +10% Area.",
				},
				{
					level = 7,
					changes = {
						baseDamage = 5,
					},
					description = "+5 Damage.",
				},
				{
					level = 8,
					changes = {
						baseDamage = 5,
					},
					description = "+5 Damage, unlocks evolution (VAMPIRICA).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				amount = 1,
				baseDamage = 30,
				areaDelta = 0.2,
			},
		},
		magic_wand = {
			name = "Magic Wand",
			id = "magic_wand",
			baseDamage = 10,
			rawPower = 1,
			area = 1,
			speed = 1,
			amount = 1,
			duration = UNKNOWN,
			cooldown = 1.2,
			pierce = 1,
			knockback = UNKNOWN,
			poolLimit = 60,
			projectileInterval = 0.1,
			hitboxDelay = UNKNOWN,
			critChance = UNKNOWN,
			critMultiplier = UNKNOWN,
			intervalDependsOnDuration = false,
			hitsWalls = UNKNOWN,
			ignores = "Ignores: Duration.",
			targeting = "Fires a magic missile at the CLOSEST enemy; unlimited range, retargets every shot. Extra projectiles fire in quick succession (repeatInterval 0.1s) at nearest targets. Ignores Duration.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 3,
					changes = {
						cooldown = -0.2,
					},
					description = "-0.2 s Cooldown.",
				},
				{
					level = 4,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 5,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage.",
				},
				{
					level = 6,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 7,
					changes = {
						pierce = 1,
					},
					description = "+1 Pierce.",
				},
				{
					level = 8,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage, unlocks evolution (HOLY_MISSILE).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				amount = 3,
				cooldown = -0.2,
				baseDamage = 20,
				pierce = 1,
			},
		},
		knife = {
			name = "Knife",
			id = "knife",
			baseDamage = 6.5,
			rawPower = 0.65,
			area = 1,
			speed = 1,
			amount = 1,
			duration = UNKNOWN,
			cooldown = 1,
			pierce = 1,
			knockback = 0.5,
			poolLimit = 70,
			projectileInterval = 0.1,
			hitboxDelay = UNKNOWN,
			critChance = 0.3,
			critMultiplier = 3,
			intervalDependsOnDuration = false,
			hitsWalls = UNKNOWN,
			ignores = "Ignores: Duration.",
			targeting = "Throws knives in a straight line in the FACING direction (movement direction, or last-moved when idle); unlimited range. Extra knives fire as a volley spaced by repeatInterval. Ignores Duration.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 3,
					changes = {
						baseDamage = 5,
						amount = 1,
					},
					description = "+5 Damage, +1 Amount.",
				},
				{
					level = 4,
					changes = {
						amount = 1,
						projectileInterval = -0.02,
					},
					description = "+1 Amount, -0.02 s Projectile Interval.",
				},
				{
					level = 5,
					changes = {
						pierce = 1,
					},
					description = "+1 Pierce.",
				},
				{
					level = 6,
					changes = {
						amount = 1,
						projectileInterval = -0.02,
					},
					description = "+1 Amount, -0.02 s Projectile Interval.",
				},
				{
					level = 7,
					changes = {
						baseDamage = 5,
						amount = 1,
					},
					description = "+5 Damage, +1 Amount.",
				},
				{
					level = 8,
					changes = {
						pierce = 1,
						projectileInterval = -0.02,
					},
					description = "+1 Pierce, -0.02 s Projectile Interval, unlocks evolution (THOUSAND).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				amount = 5,
				baseDamage = 10,
				projectileInterval = -0.06,
				pierce = 2,
			},
		},
		axe = {
			name = "Axe",
			id = "axe",
			baseDamage = 20,
			rawPower = 2,
			area = 1,
			speed = 1,
			amount = 1,
			duration = 2,
			cooldown = 4,
			pierce = 3,
			knockback = UNKNOWN,
			poolLimit = 70,
			projectileInterval = 0.2,
			hitboxDelay = UNKNOWN,
			critChance = 0.3,
			critMultiplier = 2,
			intervalDependsOnDuration = false,
			hitsWalls = false,
			ignores = "Ignores: Duration.",
			targeting = "Thrown upward above the player, arcing back down under gravity. First axe goes straight up; extra axes are thrown toward the facing direction in progressively wider arcs. Character Area is multiplied by 1.3 for this weapon. Ignores Duration.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 3,
					changes = {
						baseDamage = 20,
					},
					description = "+20 Damage.",
				},
				{
					level = 4,
					changes = {
						pierce = 2,
					},
					description = "+2 Pierce.",
				},
				{
					level = 5,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 6,
					changes = {
						baseDamage = 20,
					},
					description = "+20 Damage.",
				},
				{
					level = 7,
					changes = {
						pierce = 2,
					},
					description = "+2 Pierce.",
				},
				{
					level = 8,
					changes = {
						baseDamage = 20,
					},
					description = "+20 Damage, unlocks evolution (SCYTHE).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				amount = 2,
				baseDamage = 60,
				pierce = 4,
			},
		},
		runetracer = {
			name = "Runetracer",
			id = "runetracer",
			baseDamage = 10,
			rawPower = 1,
			area = 1,
			speed = 1,
			amount = 1,
			duration = 2.25,
			cooldown = 3,
			pierce = UNKNOWN,
			knockback = UNKNOWN,
			poolLimit = 50,
			projectileInterval = 0.2,
			hitboxDelay = 0.5,
			critChance = UNKNOWN,
			critMultiplier = UNKNOWN,
			intervalDependsOnDuration = false,
			hitsWalls = UNKNOWN,
			ignores = "Best with: Speed, Duration.",
			targeting = "Straight-line projectile that BOUNCES off screen edges and obstacles until its Duration expires. Infinite pierce, gated by a 0.5s per-enemy hitbox delay. Best with Speed and Duration.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						baseDamage = 5,
						speedDelta = 0.2,
					},
					description = "+5 Damage, +20% Projectile Speed.",
				},
				{
					level = 3,
					changes = {
						baseDamage = 5,
						duration = 0.25,
					},
					description = "+5 Damage, +0.25 s Duration.",
				},
				{
					level = 4,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 5,
					changes = {
						baseDamage = 5,
						speedDelta = 0.2,
					},
					description = "+5 Damage, +20% Projectile Speed.",
				},
				{
					level = 6,
					changes = {
						baseDamage = 5,
						duration = 0.25,
					},
					description = "+5 Damage, +0.25 s Duration.",
				},
				{
					level = 7,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 8,
					changes = {
						duration = 0.5,
					},
					description = "+0.5 s Duration, unlocks evolution (ROCHER).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				baseDamage = 20,
				speedDelta = 0.4,
				duration = 1,
				amount = 2,
			},
		},
		fire_wand = {
			name = "Fire Wand",
			id = "fire_wand",
			baseDamage = 20,
			rawPower = 2,
			area = 1,
			speed = 0.75,
			amount = 3,
			duration = 0.1,
			cooldown = 3,
			pierce = UNKNOWN,
			knockback = UNKNOWN,
			poolLimit = 30,
			projectileInterval = 0.02,
			hitboxDelay = UNKNOWN,
			critChance = UNKNOWN,
			critMultiplier = UNKNOWN,
			intervalDependsOnDuration = false,
			hitsWalls = UNKNOWN,
			ignores = "Ignores: Duration.",
			targeting = "Fires an arc of fireballs toward a RANDOM enemy; all fireballs of a cast launch near-simultaneously (repeatInterval 0.02s) and extra fireballs widen the ends of the arc. Ignores Duration.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage.",
				},
				{
					level = 3,
					changes = {
						baseDamage = 10,
						speedDelta = 0.2,
					},
					description = "+10 Damage, +20% Projectile Speed.",
				},
				{
					level = 4,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage.",
				},
				{
					level = 5,
					changes = {
						baseDamage = 10,
						speedDelta = 0.2,
					},
					description = "+10 Damage, +20% Projectile Speed.",
				},
				{
					level = 6,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage.",
				},
				{
					level = 7,
					changes = {
						baseDamage = 10,
						speedDelta = 0.2,
					},
					description = "+10 Damage, +20% Projectile Speed.",
				},
				{
					level = 8,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage, unlocks evolution (HELLFIRE).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				baseDamage = 70,
				speedDelta = 0.6,
			},
		},
		king_bible = {
			name = "King Bible",
			id = "king_bible",
			baseDamage = 10,
			rawPower = 1,
			area = 1,
			speed = 1,
			amount = 1,
			duration = 3,
			cooldown = 3,
			pierce = UNKNOWN,
			knockback = UNKNOWN,
			poolLimit = 50,
			projectileInterval = 0,
			hitboxDelay = 1.7,
			critChance = UNKNOWN,
			critMultiplier = UNKNOWN,
			intervalDependsOnDuration = true,
			hitsWalls = false,
			ignores = "Best with: Speed, Duration, Area.",
			targeting = "Bibles orbit the player clockwise for the weapon's Duration, then the weapon goes on cooldown. Speed = rotation rate, Area = orbit radius (capped) and bible hitbox size, Amount = evenly spaced extras. intervalDependsOnDuration is true, so the effective cycle = cooldown + duration (3.0 + 3.0 = 6.0s at Lv1). Per-enemy hitbox delay 1.7s.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 3,
					changes = {
						areaDelta = 0.25,
						speedDelta = 0.3,
					},
					description = "+25% Area, +30% Projectile Speed.",
				},
				{
					level = 4,
					changes = {
						baseDamage = 10,
						duration = 0.5,
					},
					description = "+10 Damage, +0.5 s Duration.",
				},
				{
					level = 5,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 6,
					changes = {
						areaDelta = 0.25,
						speedDelta = 0.3,
					},
					description = "+25% Area, +30% Projectile Speed.",
				},
				{
					level = 7,
					changes = {
						baseDamage = 10,
						duration = 0.5,
					},
					description = "+10 Damage, +0.5 s Duration.",
				},
				{
					level = 8,
					changes = {
						amount = 1,
					},
					description = "+1 Amount, unlocks evolution (VESPERS).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				amount = 3,
				areaDelta = 0.5,
				speedDelta = 0.6,
				baseDamage = 20,
				duration = 1,
			},
		},
		garlic = {
			name = "Garlic",
			id = "garlic",
			baseDamage = 5,
			rawPower = 0.5,
			area = 1,
			speed = 1,
			amount = 1,
			duration = 1.3,
			cooldown = 1.3,
			pierce = UNKNOWN,
			knockback = 0,
			poolLimit = 50,
			projectileInterval = 0,
			hitboxDelay = UNKNOWN,
			critChance = UNKNOWN,
			critMultiplier = UNKNOWN,
			intervalDependsOnDuration = false,
			hitsWalls = false,
			ignores = "Ignores: Amount, Duration, Speed.",
			targeting = "Permanent damaging aura centred on the player; no aiming. The cooldown (interval) doubles as the per-enemy hitbox delay: an enemy is hit on entry, then not again until the cooldown elapses even if it leaves and re-enters. Each hit lowers the target's knockback and freeze resistance. Ignores Amount, Duration and Speed.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						baseDamage = 2,
						areaDelta = 0.4,
					},
					description = "+2 Damage, +40% Area.",
				},
				{
					level = 3,
					changes = {
						baseDamage = 1,
						cooldown = -0.1,
					},
					description = "+1 Damage, -0.1 s Cooldown.",
				},
				{
					level = 4,
					changes = {
						baseDamage = 1,
						areaDelta = 0.2,
					},
					description = "+1 Damage, +20% Area.",
				},
				{
					level = 5,
					changes = {
						baseDamage = 2,
						cooldown = -0.1,
					},
					description = "+2 Damage, -0.1 s Cooldown.",
				},
				{
					level = 6,
					changes = {
						baseDamage = 1,
						areaDelta = 0.2,
					},
					description = "+1 Damage, +20% Area.",
				},
				{
					level = 7,
					changes = {
						baseDamage = 1,
						cooldown = -0.1,
					},
					description = "+1 Damage, -0.1 s Cooldown.",
				},
				{
					level = 8,
					changes = {
						baseDamage = 2,
						areaDelta = 0.2,
					},
					description = "+2 Damage, +20% Area, unlocks evolution (VORTEX).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				baseDamage = 10,
				areaDelta = 1,
				cooldown = -0.3,
			},
		},
		santa_water = {
			name = "Santa Water",
			id = "santa_water",
			baseDamage = 10,
			rawPower = 1,
			area = 1,
			speed = 1,
			amount = 1,
			duration = 2,
			cooldown = 4.5,
			pierce = UNKNOWN,
			knockback = 0,
			poolLimit = 20,
			projectileInterval = 0.3,
			hitboxDelay = 0.5,
			critChance = UNKNOWN,
			critMultiplier = UNKNOWN,
			intervalDependsOnDuration = false,
			hitsWalls = false,
			ignores = "Ignores: Speed.",
			targeting = "Bottles fall from the sky and shatter into stationary damaging ground zones lasting the weapon's Duration. Below 4 total Amount the first bottle of a cast aims at the CLOSEST enemy; at Amount 4+ the bottles land in a clockwise, roughly circular pattern around the player. Per-enemy hitbox delay 0.5s. Ignores Speed.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						areaDelta = 0.2,
						amount = 1,
					},
					description = "+20% Area, +1 Amount.",
				},
				{
					level = 3,
					changes = {
						baseDamage = 10,
						duration = 0.5,
					},
					description = "+10 Damage, +0.5 s Duration.",
				},
				{
					level = 4,
					changes = {
						areaDelta = 0.2,
						amount = 1,
					},
					description = "+20% Area, +1 Amount.",
				},
				{
					level = 5,
					changes = {
						baseDamage = 10,
						duration = 0.25,
					},
					description = "+10 Damage, +0.25 s Duration.",
				},
				{
					level = 6,
					changes = {
						areaDelta = 0.2,
						amount = 1,
					},
					description = "+20% Area, +1 Amount.",
				},
				{
					level = 7,
					changes = {
						baseDamage = 5,
						duration = 0.25,
					},
					description = "+5 Damage, +0.25 s Duration.",
				},
				{
					level = 8,
					changes = {
						baseDamage = 5,
						areaDelta = 0.2,
					},
					description = "+5 Damage, +20% Area, unlocks evolution (BORA).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				areaDelta = 0.8,
				amount = 3,
				baseDamage = 30,
				duration = 1,
			},
		},
		lightning_ring = {
			name = "Lightning Ring",
			id = "lightning_ring",
			baseDamage = 15,
			rawPower = 1.5,
			area = 1,
			speed = 1,
			amount = 2,
			duration = UNKNOWN,
			cooldown = 4.5,
			pierce = UNKNOWN,
			knockback = UNKNOWN,
			poolLimit = 50,
			projectileInterval = 0.05,
			hitboxDelay = UNKNOWN,
			critChance = UNKNOWN,
			critMultiplier = UNKNOWN,
			intervalDependsOnDuration = false,
			hitsWalls = false,
			ignores = "Ignores: Speed, Duration.",
			targeting = "Calls lightning down on RANDOM on-screen enemies. The bolt itself is cosmetic; damage comes from the circular ground-impact hitbox, scaled by Area. Ignores Speed and Duration.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 3,
					changes = {
						baseDamage = 10,
						areaDelta = 1,
					},
					description = "+10 Damage, +100% Area.",
				},
				{
					level = 4,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 5,
					changes = {
						baseDamage = 20,
						areaDelta = 1,
					},
					description = "+20 Damage, +100% Area.",
				},
				{
					level = 6,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 7,
					changes = {
						baseDamage = 20,
						areaDelta = 1,
					},
					description = "+20 Damage, +100% Area.",
				},
				{
					level = 8,
					changes = {
						amount = 1,
					},
					description = "+1 Amount, unlocks evolution (LOOP).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				amount = 4,
				baseDamage = 50,
				areaDelta = 3,
			},
		},
		cross = {
			name = "Cross",
			id = "cross",
			baseDamage = 5,
			rawPower = 0.5,
			area = 1,
			speed = 1,
			amount = 1,
			duration = UNKNOWN,
			cooldown = 2,
			pierce = UNKNOWN,
			knockback = UNKNOWN,
			poolLimit = 100,
			projectileInterval = 0.1,
			hitboxDelay = UNKNOWN,
			critChance = UNKNOWN,
			critMultiplier = UNKNOWN,
			intervalDependsOnDuration = false,
			hitsWalls = false,
			ignores = "Ignores: Duration.",
			targeting = "Spinning cross thrown at the CLOSEST enemy; it decelerates, boomerangs back through the player and continues off screen. Damages every enemy it contacts on both legs. Speed sets how far out it travels before reversing. Ignores Duration.",
			maxLevel = 8,
			levels = {
				{
					level = 1,
					changes = {},
					description = "Base weapon.",
				},
				{
					level = 2,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage.",
				},
				{
					level = 3,
					changes = {
						areaDelta = 0.1,
						speedDelta = 0.25,
					},
					description = "+10% Area, +25% Projectile Speed.",
				},
				{
					level = 4,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 5,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage.",
				},
				{
					level = 6,
					changes = {
						areaDelta = 0.1,
						speedDelta = 0.25,
					},
					description = "+10% Area, +25% Projectile Speed.",
				},
				{
					level = 7,
					changes = {
						amount = 1,
					},
					description = "+1 Amount.",
				},
				{
					level = 8,
					changes = {
						baseDamage = 10,
					},
					description = "+10 Damage, unlocks evolution (HEAVENSWORD).",
				},
			},
			sourceIds = {
				"game-data-v1.16",
			},
			maxLevelTotals = {
				baseDamage = 30,
				areaDelta = 0.2,
				speedDelta = 0.5,
				amount = 2,
			},
		},
	} :: { [string]: Weapon },
	omitted = {},
	sourceJson = "weapons.json",
	gameVersion = "v1.16",
	retrieved = "2026-09-19",
	displayScale = DISPLAY_SCALE,
	UNKNOWN = UNKNOWN,
}

deepFreeze(Weapons)

return Weapons
