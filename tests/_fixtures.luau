--!strict
--[[
	Shared fixtures for the headless mechanics tests. Not a test file.

	Every number here is a research literal with its citation; nothing is
	derived from a Sim implementation. src/shared/Types.luau returns nil and so
	cannot be required at runtime under the luau CLI; the aliases below restate
	the relevant Types structurally (keep them in step with Types.luau).
]]
local Rng = require("../src/shared/Sim/Rng")
local EnemiesWaves = require("../src/shared/Data/EnemiesWaves")
local PassivesEvolutions = require("../src/shared/Data/PassivesEvolutions")

local F = {}

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

-- Mirrors Types.PlayerState.
export type PlayerState = {
	characterId: string,
	level: number,
	xp: number,
	xpToNext: number,
	health: number,
	stats: StatBlock,
	weapons: { [string]: number },
	weaponOrder: { string },
	passives: { [string]: number },
	passiveOrder: { string },
	gold: number,
	kills: number,
	revivalsUsed: number,
	rerolls: number,
	skips: number,
	banishes: number,
	banished: { [string]: boolean },
}

-- Mirrors Types.TreasureConfig.
export type TreasureConfig = {
	chancePercent5Item: number,
	chancePercent3Item: number,
	chancePercent1Item: number,
	level: number,
	fixedPrizes: { string },
}

-- Mirrors Types.OptionKind / Types.LevelUpOption.
export type OptionKind = "weapon" | "passive"
export type LevelUpOption = {
	kind: OptionKind,
	itemId: string,
	toLevel: number,
	isNew: boolean,
}

-- research/vs/SCHEMA.md L340: the 16 canonical stat keys.
F.STAT_KEYS = {
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
}

-- research/vs/characters.md §Base stats L265-282, Imelda column: the pure
-- baseline line (every multiplier 1, maxHealth 100, flat stats 0).
function F.baseStats(overrides: { [string]: number }?): StatBlock
	local s: StatBlock = {
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
	}
	if overrides then
		local raw = s :: any
		for k, v in overrides do
			raw[k] = v
		end
	end
	return s
end

-- A fresh run state: level 1, xp 0, xpToNext 5 (research/vs/core_loop.md
-- L101: Lv1 -> 2 costs 5 XP), health full, nothing owned, all counts 0.
function F.newState(overrides: { [string]: any }?): PlayerState
	local stats = F.baseStats()
	local s: PlayerState = {
		characterId = "imelda",
		level = 1,
		xp = 0,
		xpToNext = 5,
		health = stats.maxHealth,
		stats = stats,
		weapons = {},
		weaponOrder = {},
		passives = {},
		passiveOrder = {},
		gold = 0,
		kills = 0,
		revivalsUsed = 0,
		rerolls = 0,
		skips = 0,
		banishes = 0,
		banished = {},
	}
	if overrides then
		local raw = s :: any
		for k, v in overrides do
			raw[k] = v
		end
	end
	return s
end

function F.deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = F.deepCopy(x)
	end
	return out
end

-- Structural equality; numbers compare with the harness tolerance (1e-9).
function F.deepEqual(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= 1e-9
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, x in a do
		if not F.deepEqual(x, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- An Rng whose next() replays `seq` in order, then falls back to a real
-- seeded stream. chance(p) is next() < p, int/range/pick derive from next(),
-- so every scripted value is consumed by exactly one draw.
function F.scriptedRng(seq: { number }, fallbackSeed: number): any
	local fallback = Rng.new(fallbackSeed)
	local i = 0
	local obj = {}
	function obj.next(_self: any): number
		i += 1
		if i <= #seq then
			return seq[i]
		end
		return fallback:next()
	end
	function obj.range(self: any, min: number, max: number): number
		return min + (max - min) * self:next()
	end
	function obj.int(self: any, min: number, max: number): number
		return math.min(max, math.floor(min + (max - min + 1) * self:next()))
	end
	function obj.chance(self: any, p: number): boolean
		return self:next() < p
	end
	function obj.pick(self: any, list: { any }): any
		return list[self:int(1, #list)]
	end
	return obj
end

-- Enemy record by the wave-table identifier (EnemiesWaves.data.enemies[].internalId).
function F.findEnemy(internalId: string): any
	for _, e in EnemiesWaves.data.enemies :: { any } do
		if e.internalId == internalId then
			return e
		end
	end
	error("no enemy record " .. internalId)
end

-- Passive record by id (PassivesEvolutions.data.passives[].id).
function F.findPassive(id: string): any
	for _, p in PassivesEvolutions.data.passives :: { any } do
		if p.id == id then
			return p
		end
	end
	error("no passive record " .. id)
end

function F.contains(list: { string }, v: string): boolean
	return table.find(list, v) ~= nil
end

return F
