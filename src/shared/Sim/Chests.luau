--!strict
--[[
	Sim/Chests.luau -- rolling a boss treasure chest: tier, gold, grants.

	Oracle: research/vs/pickups_meta.md §3 "Treasure chests".
	  * Roll order (quoted): "checks levels top-down -- level 3 (5 items)
	    first, then level 2 (3 items), then level 1 (1 item). If every check
	    fails, the chest's configured base level is used."
	  * Luck formula: "successChance(level) = levelChance(level) * totalLuck;
	    totalLuck = 1 + (displayed Luck % / 100)". The player's luck stat is
	    already that multiplier (StatBlock: luck 1.0 = base, characters.md),
	    and the shipped chances are raw percents (TreasureConfig
	    .chancePercent5Item etc., "chances: [a, b, c] = raw percent chance of
	    the 5-item, 3-item and 1-item roll"), so
	        successChance = chancePercent / Tuning.percentScale * luck.
	  * Items and gold per level: the treasureChests `levels` table in
	    PickupsMeta (1 item 100-200, 3 items 300-600, 5 items 500-1000). Conflict,
	    pickups_meta.md §3: a second source gives a flat 60-500 for every
	    chest; the per-level bands are recorded first in the Data conflict
	    entry and match the more recent wiki table, so they are used here.
	  * §4 "Every one of these [gold sources, including chests] is multiplied
	    by Greed" -> gold * state.stats.greed.
	  * Contents: "weapons, passive items, gold, and evolutions/unions" and
	    "If nothing in the player's inventory can be upgraded, the chest pays
	    extra coins instead." Each granted item levels an owned, non-maxed
	    weapon or passive by one; evolutions are out of scope for this port
	    and never appear (no grant has kind "evolution").
	  * "Note minute 1 carries fixedPrizes: ['AMOUNT'] -- the first chest is
	    a guaranteed Amount pickup": fixedPrizes are shipped vsIds, mapped to
	    our passive ids through PassivesEvolutions.data.passives[].vsId and
	    granted first, as a new acquisition when not owned.
	  * "Contents and level are rolled when the chest is opened": the caller
	    passes the luck at open time; `time` is accepted for the evolution
	    rule (evolutionRules.minimumRunTimeSeconds) and unused until
	    evolutions are in scope.

	Research gaps, chosen and reported (see the final build report):
	  * Which owned item each regular slot levels is not stated; the pick is
	    uniform over the currently upgradeable items.
	  * The "extra coins instead" amount when a slot cannot be filled is not
	    stated, so an unfillable slot yields nothing (grants may be shorter
	    than itemCount) rather than an invented amount.

	Chests.roll never mutates the PlayerState it reads; the caller applies
	the ChestResult (levels, gold, then Stats.effective / onStatsChanged).

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.

	Types: src/shared/Types.luau returns nil, which the plain `luau` CLI
	refuses to require, so the aliases below restate the contract
	structurally. Keep them byte-for-byte in step with Types.luau.
]]

local CoreLoop = require("../Data/CoreLoop")
local PassivesEvolutions = require("../Data/PassivesEvolutions")
local PickupsMeta = require("../Data/PickupsMeta")
local Tuning = require("../Tuning")
local WeaponLevels = require("./WeaponLevels")

-- Mirrors Types.Rng.
export type Rng = {
	next: (self: Rng) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
}

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

-- Mirrors Types.ChestResult.
export type ChestGrant = { kind: string, itemId: string, toLevel: number }
export type ChestResult = {
	itemCount: number,
	gold: number,
	grants: { ChestGrant },
}

local PERCENT_SCALE: number = Tuning.percentScale
local PASSIVE_SLOTS: number = CoreLoop.data.slots.passiveSlots

-- Chest level -> {items, goldMin, goldMax} from Data. The treasureChests
-- table is read by key: this is the chest-tier table, not a weapon's level
-- deltas, which only Sim/WeaponLevels may read (docs/ARCHITECTURE.md rule 4).
type ChestLevel = { level: number, items: number, goldMin: number, goldMax: number }
local chestLevels: { [number]: ChestLevel } = {}
local chestLevelsDescending: { ChestLevel } = {}
local chestLevelRows = (PickupsMeta.data.treasureChests :: any)["levels"] :: { any }
if type(chestLevelRows) ~= "table" then
	error("Chests: PickupsMeta.data.treasureChests has no chest-level table")
end
for _, entry in chestLevelRows do
	local row: ChestLevel =
		{ level = entry.level, items = entry.items, goldMin = entry.goldMin, goldMax = entry.goldMax }
	chestLevels[row.level] = row
	table.insert(chestLevelsDescending, row)
end
table.sort(chestLevelsDescending, function(a, b)
	return a.level > b.level
end)

-- Shipped passive vsId (the fixedPrizes vocabulary) -> our passive id, and
-- passive id -> max level.
local passiveIdByVsId: { [string]: string } = {}
local passiveMaxLevel: { [string]: number } = {}
for _, record in PassivesEvolutions.data.passives :: { any } do
	passiveIdByVsId[record.vsId] = record.id
	passiveMaxLevel[record.id] = record.maxLevel
end

-- The per-tier roll chance, shipped as a percent, keyed by the item count
-- that tier grants. Read from the TreasureConfig by composed field name so
-- the three fields stay tied to the Data levels table rather than to a
-- hard-coded 5/3/1.
local function chanceForItems(treasure: TreasureConfig, items: number): number
	local value = (treasure :: any)["chancePercent" .. items .. "Item"]
	if type(value) ~= "number" then
		error(string.format("Chests: TreasureConfig has no chancePercent%dItem", items))
	end
	return value
end

-- Walks the tiers top-down (pickups_meta.md §3) and returns the chest level
-- that succeeded, or the treasure's base level when every roll fails.
local function rollLevel(treasure: TreasureConfig, luck: number, rng: Rng): ChestLevel
	for _, row in chestLevelsDescending do
		local successChance = chanceForItems(treasure, row.items) / PERCENT_SCALE * luck
		-- Same semantics as Rng.chance (draw < p) written on next() so a
		-- scripted next() sequence drives the roll exactly.
		if rng:next() < successChance then
			return row
		end
	end
	local fallback = chestLevels[treasure.level]
	if fallback == nil then
		error(string.format("Chests: treasure base level %s is not a Data chest level", tostring(treasure.level)))
	end
	return fallback
end

-- Working copies of item levels so a chest can level the same item more
-- than once with consecutive toLevel and never above its max, without
-- touching the PlayerState.
type Working = {
	weapons: { [string]: number },
	passives: { [string]: number },
	passiveCount: number,
}

local function grantExisting(work: Working, rng: Rng): ChestGrant?
	-- Every owned item still below its max, in a fixed order for a seed.
	local ids: { string } = {}
	local kinds: { string } = {}
	local sortedWeapons: { string } = {}
	for weaponId in work.weapons do
		table.insert(sortedWeapons, weaponId)
	end
	table.sort(sortedWeapons)
	for _, weaponId in sortedWeapons do
		if work.weapons[weaponId] < WeaponLevels.maxLevel(weaponId) then
			table.insert(ids, weaponId)
			table.insert(kinds, "weapon")
		end
	end
	local sortedPassives: { string } = {}
	for passiveId in work.passives do
		table.insert(sortedPassives, passiveId)
	end
	table.sort(sortedPassives)
	for _, passiveId in sortedPassives do
		if work.passives[passiveId] < passiveMaxLevel[passiveId] then
			table.insert(ids, passiveId)
			table.insert(kinds, "passive")
		end
	end
	if #ids == 0 then
		return nil
	end
	local pick = rng:int(1, #ids)
	local itemId = ids[pick]
	local kind = kinds[pick]
	local owned = if kind == "weapon" then work.weapons else work.passives
	local toLevel = owned[itemId] + 1
	owned[itemId] = toLevel
	return { kind = kind, itemId = itemId, toLevel = toLevel }
end

-- A fixed prize names a shipped passive vsId. Grants it as a new level-1
-- passive (while a passive slot is free) or levels it by one; nil when it
-- is maxed, unknown, or would need a slot that is full.
local function grantFixed(work: Working, vsId: string): ChestGrant?
	local passiveId = passiveIdByVsId[vsId]
	if passiveId == nil then
		return nil
	end
	local current = work.passives[passiveId]
	if current == nil then
		if work.passiveCount >= PASSIVE_SLOTS then
			return nil
		end
		work.passives[passiveId] = 1
		work.passiveCount += 1
		return { kind = "passive", itemId = passiveId, toLevel = 1 }
	end
	if current >= passiveMaxLevel[passiveId] then
		return nil
	end
	work.passives[passiveId] = current + 1
	return { kind = "passive", itemId = passiveId, toLevel = current + 1 }
end

local Chests = {}

-- Rolls a chest opened now: tier (5 -> 3 -> 1 -> base level), gold in the
-- tier's band times Greed, then one grant per item slot -- fixed prizes
-- first, then levels for owned items. `luck` is the player's luck
-- multiplier at open time (1.0 = base). `state` is read, never written.
-- `_time` is the run clock at open time, reserved for the evolution rule.
function Chests.roll(treasure: TreasureConfig, luck: number, rng: Rng, state: PlayerState, _time: number): ChestResult
	local row = rollLevel(treasure, luck, rng)
	local gold = rng:int(row.goldMin, row.goldMax) * state.stats.greed

	local work: Working = {
		weapons = table.clone(state.weapons),
		passives = table.clone(state.passives),
		passiveCount = #state.passiveOrder,
	}
	local grants: { ChestGrant } = {}
	local fixedIndex = 1
	for _ = 1, row.items do
		local grant: ChestGrant? = nil
		while grant == nil and fixedIndex <= #treasure.fixedPrizes do
			grant = grantFixed(work, treasure.fixedPrizes[fixedIndex])
			fixedIndex += 1
		end
		if grant == nil then
			grant = grantExisting(work, rng)
		end
		if grant ~= nil then
			table.insert(grants, grant)
		end
	end

	return { itemCount = row.items, gold = gold, grants = grants }
end

return Chests
