--!strict
--[[
	Sim/Pickups.luau -- XP gem tiers, floor pickup effects, and the
	light-source drop pool.

	Oracle: research/vs/core_loop.md §3 and research/vs/pickups_meta.md §1-2.
	  * Gem tiers (core_loop.md §3): tier 1 "up to 2", tier 2 "up to 9",
	    tier 3 "anything above 9 (unbounded)" -> CoreLoop.data.xpGems.tiers
	    [].xpMin/xpMax; the top tier's xpMax is absent from the Data.
	    OQ-09, fractional XP: a gem worth 2.5 XP falls in the first tier
	    whose upper bound it does not exceed (2.5 > 2, so tier 2), i.e. the
	    tier test is `xp <= xpMax` with no rounding. The research only gives
	    integer bounds; this reads them as inclusive upper bounds.
	  * Floor pickups (pickups_meta.md §1): Gold Coin "+1, multiplied by the
	    Greed stat", Coin Bag +10, Rich Coin Bag +100, Floor Chicken
	    "Restores 30 Health", Little Clover "Increases Luck by 10% until the
	    end of the stage" -> PickupsMeta.data.floorPickups.items[].goldValue
	    / scalesWithGreed / healAmount / luckBonus. Health is clamped to
	    maxHealth; the Luck bonus is added to the luck multiplier (+10% ->
	    +0.1, characters.md convention) and lasts the run.
	    Rosary, Orologion, Vacuum, Nduja Fritta and Gilded Clover act on the
	    world (kill all, freeze, pull gems, breathe fire, gather gold), not on
	    the PlayerState; floorEffect leaves the state untouched for them and
	    effectKind() tells the server layer to act.
	  * Light sources (pickups_meta.md §2): "A destroyed light source drops
	    exactly one pickup, chosen by weighted random from the pool below,
	    restricted to entries the player has unlocked (character level >=
	    unlocksAt, plus any requiresArcana / requiresItem condition)" ->
	    PickupsMeta.data.lightSources.dropTable, contentGroup BASE only
	    (EXTRA entries need an Arcana, a relic, or are DLC-era content).
	  * Luck rule (pickups_meta.md §2, conflict #5 in SUMMARY.md and
	    PickupsMeta.conflicts "littleClover.luckAffectsDropRate"): "Luck
	    multiplies only their [isRare] weight"; the wiki's "everything except
	    Gold Coin and Coin Bag" is the non-authoritative side. Shipped data
	    is authoritative: Little Clover, Gilded Clover, coins and bags are
	    never scaled. "The exact multiplier applied to the weight is still
	    unknown", so the multiplier's shape is Tuning.rareDropLuckScale
	    (NOT from research): weight * (1 + (luck - 1) * scale), 1.0 at base.

	Two id spaces meet here and both are accepted by floorEffect /
	effectKind: the drop-table ids the roll returns (coin, roast, coinbag1,
	coinbagmax, clover, ...) and the floorPickups ids (gold_coin,
	floor_chicken, coin_bag, rich_coin_bag, little_clover, ...). They are
	joined on the record `name`, which is a reference label, never shown.
	Note the drop-table id "clover" (Little Clover) is not the passive id
	"clover" (Clover); pickups and level-up items are separate vocabularies.

	Integration gap (deferred, verified 2026-09-19): nothing in src/server or
	src/client calls rollDrop / dropPool / effectKind / floorEffect yet, so
	destructible light sources never drop anything in the live run loop --
	only gemTier is wired (PickupManager). The roll and effect halves here are
	covered by tests/pickups.test.luau and are ready for a caller: a light
	source's destruction should call rollDrop(playerLevel, luck, rng), then
	effectKind(id) to split "state" ids (floorEffect(id, state)) from "world"
	ids (PickupManager:collectAll and friends). Wiring that caller into
	PickupManager/Spawner is out of scope for this module.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.
	rollDrop allocates nothing; dropPool builds a list for inspection.

	Types: src/shared/Types.luau returns nil, which the plain `luau` CLI
	refuses to require, so the aliases below restate the contract
	structurally. Keep them byte-for-byte in step with Types.luau.
]]

local CoreLoop = require("../Data/CoreLoop")
local PickupsMeta = require("../Data/PickupsMeta")
local Tuning = require("../Tuning")
local DataAccess = require("./DataAccess")

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

-- One eligible-or-not drop-table row, weight before the Luck rule.
export type DropEntry = {
	id: string,
	weight: number,
	unlocksAtCharacterLevel: number,
	isRare: boolean,
}

-- One row of a computed pool: the id and its weight after the Luck rule.
export type DropWeight = { id: string, weight: number }

-- "state" = floorEffect applies it to the PlayerState; "world" = it acts on
-- enemies/gems/gold on the map and the server layer applies it.
export type EffectKind = "state" | "world"

local RARE_LUCK_SCALE: number = Tuning.rareDropLuckScale

-- ------------------------------------------------------------- gem tiers
type GemTier = { tier: number, xpMax: number? }
local gemTiers: { GemTier } = {}
for _, entry in CoreLoop.data.xpGems.tiers :: { any } do
	local xpMax: number? = nil
	if not DataAccess.isUnknown(entry.xpMax) then
		xpMax = entry.xpMax
	end
	table.insert(gemTiers, { tier = entry.tier, xpMax = xpMax })
end
table.sort(gemTiers, function(a, b)
	return a.tier < b.tier
end)

-- ------------------------------------------------------- floor pickups
type FloorEffect = {
	id: string,
	goldValue: number?,
	scalesWithGreed: boolean,
	healAmount: number?,
	luckBonus: number?,
}

-- floorPickups id -> effect record, and record name -> id (for the join).
local effectById: { [string]: FloorEffect } = {}
local floorIdByName: { [string]: string } = {}
for _, item in PickupsMeta.data.floorPickups.items :: { any } do
	local effect: FloorEffect = {
		id = item.id,
		goldValue = if type(item.goldValue) == "number" then item.goldValue else nil,
		scalesWithGreed = item.scalesWithGreed == true,
		healAmount = if type(item.healAmount) == "number" then item.healAmount else nil,
		luckBonus = if type(item.luckBonus) == "number" then item.luckBonus else nil,
	}
	effectById[item.id] = effect
	floorIdByName[item.name] = item.id
end

-- ------------------------------------------------------ light sources
-- Every BASE drop-table row with no Arcana/relic requirement, in shipped
-- order; the level gate is applied per query.
local baseDrops: { DropEntry } = {}
-- drop-table id -> floorPickups id (name join); absent for world-only
-- pickups with no floorPickups record.
local floorIdByDropId: { [string]: string } = {}
local knownDropIds: { [string]: boolean } = {}
for _, entry in PickupsMeta.data.lightSources.dropTable :: { any } do
	knownDropIds[entry.id] = true
	local floorId = floorIdByName[entry.name]
	if floorId ~= nil then
		floorIdByDropId[entry.id] = floorId
	end
	if
		entry.contentGroup == "BASE"
		and DataAccess.isUnknown(entry.requiresArcana)
		and DataAccess.isUnknown(entry.requiresItem)
	then
		table.insert(baseDrops, {
			id = entry.id,
			weight = entry.rarityWeight,
			unlocksAtCharacterLevel = entry.unlocksAtCharacterLevel,
			isRare = entry.isRare == true,
		})
	end
end

local Pickups = {}

-- The tier (1, 2, 3) of a gem worth `xp`: the first tier whose upper bound
-- xp does not exceed; the open-ended top tier takes everything else.
function Pickups.gemTier(xp: number): number
	for _, tier in gemTiers do
		local xpMax = tier.xpMax
		if xpMax == nil or xp <= xpMax then
			return tier.tier
		end
	end
	error("Pickups.gemTier: CoreLoop.xpGems.tiers has no open-ended tier")
end

-- Resolves either id space to the floorPickups effect record, or nil for a
-- known pickup with no state-local effect. Errors for an unknown id.
local function effectFor(itemId: string): FloorEffect?
	local direct = effectById[itemId]
	if direct ~= nil then
		return direct
	end
	local floorId = floorIdByDropId[itemId]
	if floorId ~= nil then
		return effectById[floorId]
	end
	if knownDropIds[itemId] then
		return nil
	end
	error(string.format("Pickups: unknown pickup id %q", tostring(itemId)))
end

-- Whether floorEffect handles this pickup ("state") or the server layer
-- must ("world": kill all, freeze, gem vacuum, fire breath, gold gather).
function Pickups.effectKind(itemId: string): EffectKind
	local effect = effectFor(itemId)
	if effect ~= nil and (effect.goldValue ~= nil or effect.healAmount ~= nil or effect.luckBonus ~= nil) then
		return "state"
	end
	return "world"
end

-- Applies a state-local pickup: gold (times Greed where the effect says
-- so), a heal clamped to maxHealth, or a lasting Luck bonus. World-effect
-- pickups leave the state untouched. Unknown ids error.
function Pickups.floorEffect(itemId: string, state: PlayerState)
	local effect = effectFor(itemId)
	if effect == nil then
		return
	end
	local goldValue = effect.goldValue
	if goldValue ~= nil then
		state.gold += if effect.scalesWithGreed then goldValue * state.stats.greed else goldValue
	end
	local healAmount = effect.healAmount
	if healAmount ~= nil then
		state.health = math.min(state.stats.maxHealth, state.health + healAmount)
	end
	local luckBonus = effect.luckBonus
	if luckBonus ~= nil then
		state.stats.luck += luckBonus
	end
end

-- The factor Luck applies to an isRare weight: exactly 1 at base Luck.
function Pickups.rareWeightMultiplier(luck: number): number
	return 1 + (luck - 1) * RARE_LUCK_SCALE
end

-- The weight of one row at this Luck (non-rare rows are unchanged).
function Pickups.dropWeight(entry: DropEntry, luck: number): number
	if entry.isRare then
		return entry.weight * Pickups.rareWeightMultiplier(luck)
	end
	return entry.weight
end

-- The pool a light source draws from at this character level and Luck,
-- in shipped order, with each row's effective weight.
function Pickups.dropPool(playerLevel: number, luck: number): { DropWeight }
	local pool: { DropWeight } = {}
	for _, entry in baseDrops do
		if entry.unlocksAtCharacterLevel <= playerLevel then
			table.insert(pool, { id = entry.id, weight = Pickups.dropWeight(entry, luck) })
		end
	end
	return pool
end

-- Sum of a pool's weights.
function Pickups.poolTotal(pool: { DropWeight }): number
	local total = 0
	for _, row in pool do
		total += row.weight
	end
	return total
end

-- Draws the one pickup a destroyed light source drops, weighted by the
-- pool at this level and Luck. Allocation-free. nil only if the pool is
-- empty, which the shipped table never is (coin has no gate).
function Pickups.rollDrop(playerLevel: number, luck: number, rng: Rng): string?
	local total = 0
	for _, entry in baseDrops do
		if entry.unlocksAtCharacterLevel <= playerLevel then
			total += Pickups.dropWeight(entry, luck)
		end
	end
	if total <= 0 then
		return nil
	end
	local target = rng:next() * total
	local last: string? = nil
	for _, entry in baseDrops do
		if entry.unlocksAtCharacterLevel <= playerLevel then
			local weight = Pickups.dropWeight(entry, luck)
			if weight > 0 then
				last = entry.id
				if target < weight then
					return entry.id
				end
				target -= weight
			end
		end
	end
	return last
end

return Pickups
