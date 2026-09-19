--!strict
--[[
	Sim/EnemyStats.luau -- the statline an enemy spawns with, resolved from
	Data and scaled for the moment of spawn.

	Oracle: research/vs/enemies_waves.md.
	  * §2 statlines: health / power / speed / kbTaken / xp / boss per enemy.
	    Wave tables and this module address enemies by the shipped
	    `internalId` ("ZOMBIE", "BOSS_XLDEATH"); the lowercase Data `id`
	    ("zombie") is accepted as an alias. Health is at DISPLAY scale
	    (docs/DATA_CONVENTIONS.md: shipped rawHealth x 10, so ZOMBIE 10 and
	    the Reaper 655350); power is the shipped contact damage.
	  * §3 "`HP_x_Level` skill: health multiplied by a level factor at spawn;
	    per the wiki this is the PLAYER's level at the moment of spawn,
	    applied once and never updated." -- an enemy whose `skills` list
	    carries HP_x_Level has health x playerLevel. EnemiesWaves.unknowns
	    lists "data.scaling.hpXLevelFormula": the multiplier's exact shape is
	    not in the data, and the plain product is the only stated form.
	  * §3 "Each enemy record also carries its own `level` ... How that
	    interacts with HP_x_Level is not stated in the data -- unknown, not
	    guessed." (OQ-03) -- `enemyLevel` is NOT used as a multiplier: XLBAT
	    (level 10, no skill) keeps its 270 health at every player level, and
	    BOSS_XLDEATH (level 100) is health x playerLevel, not x 100 x level.
	  * §3 "Curse raises enemy Max Health, MoveSpeed and spawn frequency (new
	    spawns only)" and passives_evolutions.md §1 Skull O'Maniac "Increases
	    enemy speed, health, quantity, and frequency by 10%" -- curse is the
	    player's StatBlock multiplier (1.0 = base) applied to health and
	    speed here; quantity and frequency belong to the Spawner. Power,
	    knockback and xp are not cursed.
	  * §1 "Stage mods: ... enemySpeed 1.1, everything else neutral" --
	    madForest.stageModifiers.enemySpeed multiplies speed and
	    enemyHealthMultiplier (1 on the base stage) multiplies health, so the
	    stage's own modifiers are honoured rather than assumed neutral.
	  * §3 "Normal enemies scale with elapsed time (the wave table); bosses
	    and minibosses with time and level." -- the only time dependence in
	    the shipped base-stage data is WHICH enemies the wave table spawns;
	    no per-enemy stat grows with elapsed time (the inverse-mode
	    hpPerMinute / speedPerMinute timeMods are a different mode and out of
	    scope). `time` therefore changes no field.
	  * Speed is the shipped unit; studs/s = speed * Tuning.enemySpeedScale
	    (NOT from research) * stageModifiers.enemySpeed * curse.
	  * Knockback: "the shipped `knockback` field ... is a knockback-TAKEN
	    multiplier -- HIGHER means knocked back FURTHER ... 0 = immune. The
	    Reaper's -0.5 is negative." -- passed through as knockbackTaken with
	    its sign; a missing value reads Tuning.defaults.enemyKnockbackTaken.
	  * xp: the shipped `xpDropped` (Growth is applied at collection by
	    Sim/Experience.gemValue); a missing value reads Tuning.defaults.enemyXp.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require. EnemyScaledStats below restates
	Types.EnemyScaledStats structurally; keep it in step with Types.luau.
]]

local Tuning = require("../Tuning")
local EnemiesWaves = require("../Data/EnemiesWaves")
local DataAccess = require("./DataAccess")

-- Mirrors Types.EnemyScaledStats.
export type EnemyScaledStats = {
	health: number,
	power: number,
	speed: number,
	knockbackTaken: number,
	xp: number,
	isBoss: boolean,
}

-- The shipped skill name that marks player-level health scaling (§2, §3).
local HP_X_LEVEL = "HP_x_Level"

-- A number the data always carries for every Mad Forest enemy. There is no
-- engine default for it (a made-up health, power or speed would be an
-- invented balance number), so anything but a number is an error.
local function required(value: any, context: string): number
	if type(value) ~= "number" then
		error(string.format("EnemyStats: %s is not a number in Data (%s)", context, tostring(value)))
	end
	return value
end

-- The base statline resolved from Data once per enemy at load; scaled()
-- only multiplies. Health here already carries the stage's own multiplier.
type BaseLine = {
	health: number,
	power: number,
	speed: number,
	knockbackTaken: number,
	xp: number,
	isBoss: boolean,
	healthScalesWithPlayerLevel: boolean,
}

local stage = EnemiesWaves.data.madForest
local STAGE_ENEMY_SPEED = required(stage.stageModifiers.enemySpeed, "madForest.stageModifiers.enemySpeed")
local STAGE_ENEMY_HEALTH =
	required(stage.stageModifiers.enemyHealthMultiplier, "madForest.stageModifiers.enemyHealthMultiplier")

local byId: { [string]: BaseLine } = {}
local internalIds: { string } = {}

for i, record in EnemiesWaves.data.enemies :: { any } do
	local context = string.format("enemies[%d]", i)
	if type(record.internalId) ~= "string" then
		error("EnemyStats: " .. context .. ".internalId is not a string in Data")
	end
	local scalesWithLevel = false
	for _, skill in record.skills :: { any } do
		if skill == HP_X_LEVEL then
			scalesWithLevel = true
		end
	end
	local line: BaseLine = {
		health = required(record.health, context .. ".health") * STAGE_ENEMY_HEALTH,
		power = required(record.power, context .. ".power"),
		speed = required(record.speed, context .. ".speed") * Tuning.enemySpeedScale * STAGE_ENEMY_SPEED,
		knockbackTaken = DataAccess.num(record.knockbackTaken, "enemyKnockbackTaken"),
		xp = DataAccess.num(record.xpDropped, "enemyXp"),
		isBoss = record.isBoss == true,
		healthScalesWithPlayerLevel = scalesWithLevel,
	}
	if byId[record.internalId] ~= nil then
		error("EnemyStats: duplicate enemy internalId " .. record.internalId .. " in Data")
	end
	byId[record.internalId] = line
	internalIds[#internalIds + 1] = record.internalId
	-- Lowercase Data id as an alias, never shadowing an internalId.
	if type(record.id) == "string" and byId[record.id] == nil then
		byId[record.id] = line
	end
end

local EnemyStats = {}

-- Every shipped internalId, in Data order (for tests and presenters).
EnemyStats.ids = table.freeze(internalIds)

-- True when `enemyId` names a Mad Forest enemy (internalId or Data id).
function EnemyStats.exists(enemyId: string): boolean
	return byId[enemyId] ~= nil
end

-- True when the enemy's health is multiplied by the player's level at spawn.
function EnemyStats.scalesWithPlayerLevel(enemyId: string): boolean
	local line = byId[enemyId]
	if line == nil then
		error(string.format("EnemyStats: unknown enemy id %q", tostring(enemyId)))
	end
	return line.healthScalesWithPlayerLevel
end

-- The statline an enemy spawns with at run time `time` (unused: the shipped
-- base-stage data has no time-based stat growth, see header), at the
-- player's `playerLevel` (HP_x_Level enemies only) and the player's curse
-- multiplier (1.0 = base; health and speed). With a caller-owned `out` line
-- (Sim/Waves.fillBoss's shape) the fields are written into it and it is
-- returned, so a per-spawn loop allocates nothing; without one a fresh
-- table is returned. The result is consumed before the next call.
function EnemyStats.scaled(
	enemyId: string,
	_time: number,
	playerLevel: number,
	curse: number,
	out: EnemyScaledStats?
): EnemyScaledStats
	local line = byId[enemyId]
	if line == nil then
		error(string.format("EnemyStats.scaled: unknown enemy id %q", tostring(enemyId)))
	end
	local health = line.health
	if line.healthScalesWithPlayerLevel then
		health *= playerLevel
	end
	if out == nil then
		return {
			health = health * curse,
			power = line.power,
			speed = line.speed * curse,
			knockbackTaken = line.knockbackTaken,
			xp = line.xp,
			isBoss = line.isBoss,
		}
	end
	out.health = health * curse
	out.power = line.power
	out.speed = line.speed * curse
	out.knockbackTaken = line.knockbackTaken
	out.xp = line.xp
	out.isBoss = line.isBoss
	return out
end

return EnemyStats
