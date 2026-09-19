--!strict
--[[
	Sim/WeaponLevels.luau -- the ONLY reader of Data.Weapons.data[id].levels.

	Oracle: research/vs/weapons.md.
	  * "Level entries are deltas applied on top of the previous level, exactly
	    as shipped. Lv1 is the base row."  (weapons.md, Conventions)
	  * "Absolute percent stats are multipliers (area: 1.0 = 100%); percent
	    changes are additive fractions (areaDelta: 0.1 = +10%)."
	  * Fields absent from a weapon's shipped record carry the Data sentinel,
	    never 0; they resolve to Tuning.defaults through DataAccess.num.
	  * Each weapon's shipped `Ignores:` tip lists the player stats that do not
	    apply to it (weapons.md, per-weapon "Shipped tips field").

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.

	Types: src/shared/Types.luau is the contract, but it returns nil, which the
	plain `luau` CLI refuses to require ("module must return a table or
	function"). The aliases below therefore restate the contract structurally,
	field for field; Luau's structural typing makes them interchangeable with
	Types.WeaponLevelStats / Types.WeaponInstanceStats / Types.StatBlock for
	every consumer. Keep them byte-for-byte in step with Types.luau.
]]

local Weapons = require("../Data/Weapons")
local DataAccess = require("./DataAccess")

-- Mirrors Types.WeaponLevelStats.
export type WeaponLevelStats = {
	damage: number,
	area: number,
	speed: number,
	amount: number,
	duration: number,
	cooldown: number,
	pierce: number,
	knockback: number,
	poolLimit: number,
	projectileInterval: number,
	critChance: number,
	critMultiplier: number,
	hitboxDelay: number,
}

-- Mirrors Types.WeaponInstanceStats.
export type WeaponInstanceStats = WeaponLevelStats

-- Mirrors Types.StatBlock.
export type StatBlock = {
	maxHealth: number,
	recovery: number,
	armor: number,
	moveSpeed: number,
	might: number,
	area: number,
	speed: number,
	duration: number,
	amount: number,
	cooldown: number,
	luck: number,
	growth: number,
	greed: number,
	magnet: number,
	revival: number,
	curse: number,
}

local WeaponLevels = {}

-- Runtime-only tag on the table statsAt returns, so effective(base, player)
-- can look up the weapon's `ignores` rule without an id in its signature. It
-- is not part of the WeaponLevelStats type; it survives table.clone.
local WEAPON_ID_TAG = "weaponId"

-- Shipped level `changes` key -> WeaponLevelStats field. Every delta is added
-- (weapons.md: "deltas applied on top of the previous level"); areaDelta and
-- speedDelta are additive fractions on the 1.0-based multipliers.
local DELTA_FIELD: { [string]: string } = {
	baseDamage = "damage",
	areaDelta = "area",
	speedDelta = "speed",
	amount = "amount",
	cooldown = "cooldown",
	duration = "duration",
	pierce = "pierce",
	projectileInterval = "projectileInterval",
}

-- Player StatBlock key -> the WeaponLevelStats field it multiplies. SCHEMA.md
-- and characters.md: might/area/speed/duration/cooldown are multipliers with
-- 1.0 = unmodified, so the weapon value is multiplied by the player value.
local MULTIPLIED_BY: { { statKey: string, field: string } } = {
	{ statKey = "might", field = "damage" },
	{ statKey = "area", field = "area" },
	{ statKey = "speed", field = "speed" },
	{ statKey = "duration", field = "duration" },
	{ statKey = "cooldown", field = "cooldown" },
}

local function weaponRecord(weaponId: string): Weapons.Weapon
	local record = Weapons.data[weaponId]
	if record == nil then
		error(string.format("WeaponLevels: unknown weapon id %q", tostring(weaponId)))
	end
	return record
end

-- Parses the shipped tip ("Ignores: Speed, Duration.") into a set of lowercase
-- player stat keys. A "Best with:" tip ignores nothing.
local function parseIgnores(tip: string): { [string]: boolean }
	local ignored: { [string]: boolean } = {}
	local body = string.match(tip, "^Ignores:%s*(.*)$")
	if body ~= nil then
		for word in string.gmatch(body, "%a+") do
			ignored[string.lower(word)] = true
		end
	end
	return ignored
end

-- Parsed once per weapon id at load; the tip is data, not player-facing text.
local ignoresById: { [string]: { [string]: boolean } } = {}
for weaponId, record in Weapons.data do
	ignoresById[weaponId] = parseIgnores(record.ignores)
end

local function ignoresFor(base: WeaponLevelStats): { [string]: boolean }
	local tagged = (base :: any)[WEAPON_ID_TAG]
	if type(tagged) == "string" and ignoresById[tagged] ~= nil then
		return ignoresById[tagged]
	end
	return {}
end

function WeaponLevels.maxLevel(weaponId: string): number
	return weaponRecord(weaponId).maxLevel
end

-- The Lv1 row with absent fields resolved to Tuning.defaults (weapons.md
-- "Base stats" table; the `-` cells are the absent ones).
local function baseRow(record: Weapons.Weapon): WeaponLevelStats
	return {
		damage = record.baseDamage,
		area = record.area,
		speed = record.speed,
		amount = record.amount,
		duration = DataAccess.num(record.duration, "weaponDuration"),
		cooldown = record.cooldown,
		pierce = DataAccess.num(record.pierce, "weaponPierce"),
		knockback = DataAccess.num(record.knockback, "weaponKnockback"),
		poolLimit = record.poolLimit,
		projectileInterval = record.projectileInterval,
		critChance = DataAccess.num(record.critChance, "weaponCritChance"),
		critMultiplier = DataAccess.num(record.critMultiplier, "weaponCritMultiplier"),
		hitboxDelay = DataAccess.num(record.hitboxDelay, "weaponHitboxDelay"),
	}
end

function WeaponLevels.statsAt(weaponId: string, level: number): WeaponLevelStats
	local record = weaponRecord(weaponId)
	if type(level) ~= "number" or level ~= math.floor(level) or level < 1 or level > record.maxLevel then
		error(
			string.format(
				"WeaponLevels: level %s out of range 1..%d for %q",
				tostring(level),
				record.maxLevel,
				weaponId
			)
		)
	end

	local stats = baseRow(record)
	local fields = stats :: { [string]: any }

	-- Fold the Lv2..level deltas in order. Lv1's entry is the base row and
	-- carries no changes (weapons.md, Conventions).
	for _, entry in record.levels do
		local entryLevel = entry.level
		if entryLevel > 1 and entryLevel <= level then
			for key, delta in entry.changes do
				local field = DELTA_FIELD[key]
				if field == nil then
					error(string.format("WeaponLevels: unmapped level change %q on %q Lv%d", key, weaponId, entryLevel))
				end
				fields[field] += delta
			end
		end
	end

	fields[WEAPON_ID_TAG] = weaponId
	return stats
end

-- Applies the player's StatBlock (SCHEMA.md conventions): multiplier stats
-- multiply, `amount` adds flat and stays an integer >= 1, and everything the
-- weapon's shipped `Ignores:` tip names keeps its level value. pierce,
-- knockback, poolLimit, projectileInterval, hitboxDelay, critChance and
-- critMultiplier have no player stat and pass through unchanged. `base` is
-- not mutated.
function WeaponLevels.effective(base: WeaponLevelStats, player: StatBlock): WeaponInstanceStats
	local ignored = ignoresFor(base)
	local out = table.clone(base)
	local outFields = out :: { [string]: any }
	local baseFields = base :: { [string]: any }
	local playerFields = player :: { [string]: any }

	for _, rule in MULTIPLIED_BY do
		if not ignored[rule.statKey] then
			outFields[rule.field] = baseFields[rule.field] * playerFields[rule.statKey]
		end
	end
	if not ignored.amount then
		out.amount = math.max(1, base.amount + player.amount)
	end
	return out
end

return WeaponLevels
