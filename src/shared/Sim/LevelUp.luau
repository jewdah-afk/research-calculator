--!strict
--[[
	Sim/LevelUp.luau -- the level-up offer: option count, pool rules, apply,
	reroll / skip / banish.

	Oracle: research/vs/core_loop.md.
	  * §2 "Options offered: 3, or 4 with a Luck-based chance" ->
	    CoreLoop.data.levelUp.optionsOffered {min, max}.
	  * §2 "4-option chance: Luck / (100 + Luck) where Luck is total Luck in
	    percentage points" (community token-bag model; the official formula
	    is absent from the research, CoreLoop.unknowns). With L = luck *
	    percentScale that is L / (percentScale + L) == luck / (1 + luck), so
	    the roll below needs no scale constant at all.
	  * §2 "Options are unique -- no duplicate entries in one offer".
	  * §2 / §6 slot rule: "Once the player holds 6 different weapons, no new
	    weapons are offered (only upgrades to owned ones); same rule
	    independently for 6 passive items" -> CoreLoop.data.slots.
	  * §6 "Max weapon level 8 ... Max passive item level 5" -> read per item
	    from Weapons.data (via WeaponLevels.maxLevel) and
	    PassivesEvolutions.data.passives[].maxLevel, which is where Duplicator
	    and Tiragisu's 2 live.
	  * §2 Reroll "Reshuffles the current offer into a new set"; Banish
	    "Permanently removes an item from the offer pool for the rest of the
	    run"; Skip "Declines the whole offer and grants XP instead", "20% of
	    the XP required for the next level" ->
	    CoreLoop.data.levelUp.xpGrantedInsteadOfItem. (Conflict, core_loop.md
	    "Conflicts": one wiki phrasing attributes the 20% to Reroll and Banish
	    as well. Only Skip grants it here: the Skip page is the primary
	    source and the alternative reading is a second phrasing of the same
	    page, not a second value.)
	  * Reroll / Skip / Banish counts come from the PowerUp shop, which is out
	    of scope, so PlayerState.rerolls/skips/banishes start at 0 and each
	    action is refused, with the state untouched, when its count is 0.

	Research gaps, chosen and reported (see the final build report):
	  * Offer weighting. The passive records carry a shipped `rarity`, the
	    weapon records do not, and core_loop.md describes no weighting, so
	    the draw is uniform over the eligible pool. Weighting only the half
	    of the pool that has data would skew weapons against passives.
	  * Banish removes the option from the current offer without drawing a
	    replacement (the offer shrinks), and never touches the pool draw.
	  * Skip adds the XP to state.xp and does not level; carrying overflow
	    across levels is Experience.addXp's job (the caller runs it after a
	    skip that reaches xpToNext).

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.
	Every offer allocates its option tables; nothing here runs per enemy.

	Types: src/shared/Types.luau returns nil, which the plain `luau` CLI
	refuses to require, so the aliases below restate the contract
	structurally. Keep them byte-for-byte in step with Types.luau.
]]

local CoreLoop = require("../Data/CoreLoop")
local PassivesEvolutions = require("../Data/PassivesEvolutions")
local Weapons = require("../Data/Weapons")
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

-- Mirrors Types.OptionKind / Types.LevelUpOption / Types.LevelUpOffer.
export type OptionKind = "weapon" | "passive"

export type LevelUpOption = {
	kind: OptionKind,
	itemId: string,
	toLevel: number,
	isNew: boolean,
}

export type LevelUpOffer = {
	options: { LevelUpOption },
	rerollsLeft: number,
	skipsLeft: number,
	banishesLeft: number,
}

local levelUpData = CoreLoop.data.levelUp
local slots = CoreLoop.data.slots

local OPTIONS_MIN: number = levelUpData.optionsOffered.min
local OPTIONS_MAX: number = levelUpData.optionsOffered.max
local SKIP_XP_FRACTION: number = levelUpData.xpGrantedInsteadOfItem
local WEAPON_SLOTS: number = slots.weaponSlots
local PASSIVE_SLOTS: number = slots.passiveSlots

-- Weapon ids in a fixed order (Weapons.data is a dictionary; sorting keeps
-- the draw reproducible for a given seed regardless of hash order).
local weaponIds: { string } = {}
for weaponId in Weapons.data do
	table.insert(weaponIds, weaponId)
end
table.sort(weaponIds)

-- Passive ids in shipped order, plus id -> maxLevel.
local passiveIds: { string } = {}
local passiveMaxLevel: { [string]: number } = {}
for _, record in PassivesEvolutions.data.passives :: { any } do
	local id: string = record.id
	table.insert(passiveIds, id)
	passiveMaxLevel[id] = record.maxLevel
end

local LevelUp = {}

-- Max level of any offerable item, or an error for an unknown id.
local function maxLevelOf(kind: OptionKind, itemId: string): number
	if kind == "weapon" then
		return WeaponLevels.maxLevel(itemId)
	end
	local max = passiveMaxLevel[itemId]
	if max == nil then
		error(string.format("LevelUp: unknown passive id %q", tostring(itemId)))
	end
	return max
end

-- Appends every offerable option of one kind to `out` (core_loop.md §2):
-- not banished, below its max level, and -- for an item not yet owned --
-- only while that kind still has a free slot.
local function collectCandidates(
	kind: OptionKind,
	ids: { string },
	owned: { [string]: number },
	ownedCount: number,
	slotLimit: number,
	banished: { [string]: boolean },
	out: { LevelUpOption }
)
	local slotFree = ownedCount < slotLimit
	for _, itemId in ids do
		if not banished[itemId] then
			local level = owned[itemId]
			if level == nil then
				if slotFree then
					table.insert(out, { kind = kind, itemId = itemId, toLevel = 1, isNew = true })
				end
			elseif level < maxLevelOf(kind, itemId) then
				table.insert(out, { kind = kind, itemId = itemId, toLevel = level + 1, isNew = false })
			end
		end
	end
end

local function candidates(state: PlayerState): { LevelUpOption }
	local out: { LevelUpOption } = {}
	collectCandidates("weapon", weaponIds, state.weapons, #state.weaponOrder, WEAPON_SLOTS, state.banished, out)
	collectCandidates("passive", passiveIds, state.passives, #state.passiveOrder, PASSIVE_SLOTS, state.banished, out)
	return out
end

-- True while at least one option could be offered (core_loop.md §6: with
-- everything maxed and both slot kinds full there is nothing left; Limit
-- Break, which would then offer extra levels, is out of scope).
function LevelUp.canOffer(state: PlayerState): boolean
	return #candidates(state) > 0
end

-- How many options this level-up shows: the minimum, plus one more with
-- probability luck / (1 + luck) (== L / (100 + L) with L in percentage
-- points, core_loop.md §2), never above the maximum and never more than
-- the pool holds.
local function optionCount(state: PlayerState, poolSize: number, rng: Rng): number
	local count = OPTIONS_MIN
	local luck = state.stats.luck
	if count < OPTIONS_MAX and rng:chance(luck / (1 + luck)) then
		count += 1
	end
	return math.min(count, poolSize)
end

-- Builds a fresh offer: unique options drawn uniformly without replacement
-- from the eligible pool (partial Fisher-Yates over the candidate list).
function LevelUp.offer(state: PlayerState, rng: Rng): LevelUpOffer
	local pool = candidates(state)
	local count = optionCount(state, #pool, rng)
	local options: { LevelUpOption } = {}
	for i = 1, count do
		local j = rng:int(i, #pool)
		pool[i], pool[j] = pool[j], pool[i]
		options[i] = pool[i]
	end
	return {
		options = options,
		rerollsLeft = state.rerolls,
		skipsLeft = state.skips,
		banishesLeft = state.banishes,
	}
end

-- Records a chosen option. A new item is added at level 1 and appended to
-- its acquisition order; an owned item goes up by exactly one. Anything
-- else -- an unknown id, a banished item, a level jump, a level past the
-- item's max, or a new item into a full slot kind -- is an error, so the
-- caller can only ever apply what offer() produced.
function LevelUp.apply(state: PlayerState, option: LevelUpOption)
	local kind: OptionKind = option.kind
	local itemId = option.itemId
	local maxLevel = maxLevelOf(kind, itemId)
	local owned: { [string]: number }
	local order: { string }
	local slotLimit: number
	if kind == "weapon" then
		owned, order, slotLimit = state.weapons, state.weaponOrder, WEAPON_SLOTS
	elseif kind == "passive" then
		owned, order, slotLimit = state.passives, state.passiveOrder, PASSIVE_SLOTS
	else
		error(string.format("LevelUp.apply: unknown option kind %q", tostring(kind)))
	end

	if state.banished[itemId] then
		error(string.format("LevelUp.apply: %q is banished", itemId))
	end
	local current = owned[itemId]
	local expected = if current == nil then 1 else current + 1
	if option.toLevel ~= expected then
		error(
			string.format(
				"LevelUp.apply: %q is at %s, cannot go to %s",
				itemId,
				tostring(current),
				tostring(option.toLevel)
			)
		)
	end
	if expected > maxLevel then
		error(string.format("LevelUp.apply: %q is already at its max level %d", itemId, maxLevel))
	end
	if current == nil then
		if #order >= slotLimit then
			error(string.format("LevelUp.apply: no free %s slot for %q", kind, itemId))
		end
		table.insert(order, itemId)
	end
	owned[itemId] = expected
end

-- Reroll: spends one reroll and returns a fresh offer. With no rerolls
-- left the same offer comes back and nothing changes.
function LevelUp.reroll(state: PlayerState, offer: LevelUpOffer, rng: Rng): LevelUpOffer
	if state.rerolls <= 0 then
		return offer
	end
	state.rerolls -= 1
	return LevelUp.offer(state, rng)
end

-- Skip: spends one skip and grants xpGrantedInsteadOfItem (20%) of the XP
-- needed for the next level (core_loop.md §2). Returns the XP granted, 0
-- when refused. The XP is added to state.xp only; the caller runs
-- Experience.addXp for any level this reaches.
function LevelUp.skip(state: PlayerState, _offer: LevelUpOffer, _rng: Rng): number
	if state.skips <= 0 then
		return 0
	end
	state.skips -= 1
	local granted = SKIP_XP_FRACTION * state.xpToNext
	state.xp += granted
	return granted
end

-- Banish: spends one banish, removes itemId from this run's pool
-- (state.banished) and returns the current offer with that option taken
-- out. With no banishes left the same offer comes back and nothing changes.
-- The itemId is the 4th argument; the (state, offer, rng) prefix matches
-- the architecture's shorthand, and the two trailing arguments are also
-- accepted swapped so a caller written from that shorthand still works.
function LevelUp.banish(state: PlayerState, offer: LevelUpOffer, rng: Rng, itemId: string): LevelUpOffer
	if type(rng) == "string" then
		local swapped: any = rng
		rng = itemId :: any
		itemId = swapped
	end
	if type(itemId) ~= "string" then
		error("LevelUp.banish: itemId must be a string")
	end
	if state.banishes <= 0 then
		return offer
	end
	state.banishes -= 1
	state.banished[itemId] = true

	local remaining: { LevelUpOption } = {}
	for _, option in offer.options do
		if option.itemId ~= itemId then
			table.insert(remaining, option)
		end
	end
	return {
		options = remaining,
		rerollsLeft = state.rerolls,
		skipsLeft = state.skips,
		banishesLeft = state.banishes,
	}
end

return LevelUp
