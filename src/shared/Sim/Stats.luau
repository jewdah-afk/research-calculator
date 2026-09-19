--!strict
--[[
	Sim/Stats.luau -- the player StatBlock: character base line, per-level
	bonuses, passives.

	Oracle: research/vs/characters.md and passives_evolutions.md §1.
	  * "Multiplier stats (might, area, speed, duration, cooldown, luck,
	    growth, greed, curse, moveSpeed) are stored as multipliers: 1 =
	    unmodified, 1.3 = +30%. maxHealth flat HP; recovery flat HP/sec;
	    armor, amount, revival flat integers. magnet is an additive fraction:
	    0 = unmodified."  (characters.md, Conventions)
	  * "levelBonuses values are deltas added at that level."
	    (characters.md, Conventions) -- forLevel sums every bonus whose
	    level <= the player's level, so the +1/-1 growth pairs at 20/21 and
	    40/41 (core_loop.md §5: "+100% Growth at levels 20 and 40, reverted
	    at 21 and 41") fall out of the data with no special case.
	  * "Passive percentage bonuses are stored as FRACTIONAL DELTAS per level
	    (e.g. Spinach 0.1 = +10% Might per level); totalAtMax is the
	    arithmetic sum of the per-level values. Armor/Duplicator/Tiragisu
	    are flat integers."  (PassivesEvolutions notes) -- apply adds the
	    summed valuePerLevel[1..level] to the stat, which is the additive
	    stacking SCHEMA.md prescribes for fractional deltas.
	  * Hollow Heart is the one passive on an absolute stat: its 0.2/level
	    is a fraction OF maxHealth, added additively (+100% at Lv5), per
	    conflict `data.passives.hollow_heart.totalAtMax` (SUMMARY.md conflict
	    #4: shipped additive is authoritative over the fandom x1.2 compounding).
	  * Attractorb's per-level magnet is non-uniform (0.5, 0.33, 0.25, 0.2,
	    0.33 = 1.61 total), per conflict `data.passives.attractorb.valuePerLevel`
	    (shipped data over the wiki's flat +20%/level). apply reads the
	    shipped array, so nothing here assumes uniform steps.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require ("module must return a table or
	function"). The StatBlock alias below therefore restates Types.StatBlock
	structurally; Luau's structural typing makes it interchangeable for every
	consumer. Keep it byte-for-byte in step with Types.luau.
]]

local Characters = require("../Data/Characters")
local PassivesEvolutions = require("../Data/PassivesEvolutions")
local DataAccess = require("./DataAccess")

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

-- The canonical 16 stat keys, in SCHEMA.md order. Exposed so consumers and
-- tests can iterate a StatBlock without restating the list.
local KEYS: { string } = table.freeze({
	"maxHealth",
	"recovery",
	"armor",
	"moveSpeed",
	"might",
	"area",
	"speed",
	"duration",
	"amount",
	"cooldown",
	"luck",
	"growth",
	"greed",
	"magnet",
	"revival",
	"curse",
})
local IS_KEY: { [string]: boolean } = {}
for _, key in KEYS do
	IS_KEY[key] = true
end

-- Absolute stats whose passive delta is a fraction OF the current value
-- rather than a plain addend (Hollow Heart on maxHealth; see header).
local FRACTION_OF_VALUE: { [string]: boolean } = { maxHealth = true }

-- Data.PassivesEvolutions.data.passives is a list; index it by id once.
type PassiveRecord = { id: string, stat: string, maxLevel: number, valuePerLevel: { any } }
local passiveById: { [string]: PassiveRecord } = {}
for _, record in (PassivesEvolutions.data.passives :: any) :: { PassiveRecord } do
	passiveById[record.id] = record
end

local function characterRecord(characterId: string): any
	local record = (Characters.data :: any)[characterId]
	if record == nil then
		error(string.format("Stats: unknown character id %q", tostring(characterId)))
	end
	return record
end

local function assertStatKey(key: any, context: string)
	if type(key) ~= "string" or not IS_KEY[key] then
		error(string.format("Stats: %s names an unknown stat %q", context, tostring(key)))
	end
end

local function assertLevel(level: number, context: string)
	if type(level) ~= "number" or level < 1 or level ~= math.floor(level) then
		error(string.format("Stats: %s level must be an integer >= 1, got %s", context, tostring(level)))
	end
end

-- Mutable string-keyed view of a StatBlock for data-driven access.
local function view(block: StatBlock): { [string]: number }
	return (block :: any) :: { [string]: number }
end

local Stats = {}

Stats.keys = KEYS

-- The character's base line, copied fresh from Data (characters.md "Base
-- stats"). A base stat carrying the Data sentinel has no engine default (a
-- made-up base stat would be an invented balance number), so it errors.
function Stats.base(characterId: string): StatBlock
	local record = characterRecord(characterId)
	local source = record.baseStats :: { [string]: any }
	local out: { [string]: number } = {}
	for _, key in KEYS do
		local value = source[key]
		if DataAccess.isUnknown(value) or type(value) ~= "number" then
			error(string.format("Stats.base: %s.baseStats.%s is not a number in Data", characterId, key))
		end
		out[key] = value
	end
	return (out :: any) :: StatBlock
end

-- Base line plus every levelBonuses delta whose level <= `level`
-- (characters.md "Per-level bonuses and caps"). Includes the universal
-- growth spike entries at 20/21 and 40/41, which every character carries.
function Stats.forLevel(characterId: string, level: number): StatBlock
	assertLevel(level, "forLevel")
	local block = Stats.base(characterId)
	local out = view(block)
	local record = characterRecord(characterId)
	for _, bonus in record.levelBonuses :: { any } do
		if bonus.level <= level then
			assertStatKey(bonus.stat, characterId .. ".levelBonuses")
			out[bonus.stat] += bonus.value
		end
	end
	return block
end

-- A new StatBlock with each owned passive (passiveId -> level) applied on
-- top of `stats`. Levels are validated against the passive's Data maxLevel
-- (5, or 2 for Duplicator and Tiragisu); an unknown id errors. Passives are
-- walked in Data order so the float sums are deterministic.
function Stats.apply(stats: StatBlock, passives: { [string]: number }): StatBlock
	for passiveId, level in passives do
		local record = passiveById[passiveId]
		if record == nil then
			error(string.format("Stats.apply: unknown passive id %q", tostring(passiveId)))
		end
		assertLevel(level, "passive " .. passiveId)
		if level > record.maxLevel then
			error(string.format("Stats.apply: %s level %d exceeds maxLevel %d", passiveId, level, record.maxLevel))
		end
	end

	local input = view(stats)
	local out: { [string]: number } = {}
	for _, key in KEYS do
		out[key] = input[key]
	end

	for _, record in (PassivesEvolutions.data.passives :: any) :: { PassiveRecord } do
		local level = passives[record.id]
		if level ~= nil then
			assertStatKey(record.stat, "passive " .. record.id)
			local sum = 0
			for i = 1, level do
				local step = record.valuePerLevel[i]
				if type(step) ~= "number" then
					error(string.format("Stats.apply: %s.valuePerLevel[%d] is not a number in Data", record.id, i))
				end
				sum += step
			end
			if FRACTION_OF_VALUE[record.stat] then
				-- Hollow Heart: +20% of maxHealth per level, additive (conflict #4).
				out[record.stat] += input[record.stat] * sum
			else
				out[record.stat] += sum
			end
		end
	end
	return (out :: any) :: StatBlock
end

-- base -> per-level bonuses -> passives, composed.
function Stats.effective(characterId: string, level: number, passives: { [string]: number }): StatBlock
	return Stats.apply(Stats.forLevel(characterId, level), passives)
end

return Stats
