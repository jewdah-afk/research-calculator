--!strict
-- Sim/Pickups. Oracle: research/vs/core_loop.md §3 L48-52 (gem tiers),
-- pickups_meta.md §1 L18-29 (floor pickup effects), §2 L47-76 (drop pool,
-- weights, level gates, isRare/Luck rule; conflict #5 shipped data
-- authoritative), §4 L181-183 (Greed multiplies gold).
local T = require("./_harness")
local F = require("./_fixtures")
local Pickups = require("../src/shared/Sim/Pickups")
local Rng = require("../src/shared/Sim/Rng")
local Tuning = require("../src/shared/Tuning")
local PickupsMeta = require("../src/shared/Data/PickupsMeta")

local function weightOf(pool: { any }, id: string): number?
	for _, row in pool do
		if row.id == id then
			return row.weight
		end
	end
	return nil
end

T.test("PK-01 core_loop.md L50-52: gem tiers 1 (up to 2), 2 (up to 9), 3 (above 9)", function()
	T.eq(Pickups.gemTier(1), 1, "1")
	T.eq(Pickups.gemTier(2), 1, "2")
	T.eq(Pickups.gemTier(3), 2, "3")
	T.eq(Pickups.gemTier(9), 2, "9")
	T.eq(Pickups.gemTier(10), 3, "10")
	T.eq(Pickups.gemTier(30), 3, "30")
	T.eq(Pickups.gemTier(655350), 3, "655350")
end)

T.test("PK-02 pickups_meta.md L20-22 + L181-183: coins add goldValue x Greed", function()
	local state = F.newState()
	state.stats.greed = 1.3
	Pickups.floorEffect("gold_coin", state)
	T.eq(state.gold, 1.3, "gold coin 1 x 1.3")
	Pickups.floorEffect("coin_bag", state)
	T.eq(state.gold, 14.3, "coin bag +10 x 1.3")
	Pickups.floorEffect("rich_coin_bag", state)
	T.eq(state.gold, 144.3, "rich coin bag +100 x 1.3")
end)

T.test("PK-02 pickups_meta.md L24: Floor Chicken restores 30, clamped to maxHealth", function()
	local state = F.newState()
	state.health = 80
	Pickups.floorEffect("floor_chicken", state)
	T.eq(state.health, 100, "80 + 30 clamped to 100")
	state.health = 50
	Pickups.floorEffect("floor_chicken", state)
	T.eq(state.health, 80, "50 + 30")
end)

T.test("PK-02 pickups_meta.md L29: Little Clover +0.1 Luck until stage end", function()
	local state = F.newState()
	Pickups.floorEffect("little_clover", state)
	T.eq(state.stats.luck, 1.1, "luck 1.0 -> 1.1")
	Pickups.floorEffect("little_clover", state)
	T.eq(state.stats.luck, 1.2, "stacks")
end)

T.test("PK-02 floorEffect on an unknown id errors", function()
	T.throws(function()
		Pickups.floorEffect("nonsense", F.newState())
	end, "unknown pickup")
end)

T.test("PK-03 pickups_meta.md L56-70: BASE pool at level 30, luck 1.0 totals 80.5 with the shipped weights", function()
	local pool = Pickups.dropPool(30, 1.0)
	T.eq(Pickups.poolTotal(pool), 80.5, "total")
	T.eq(weightOf(pool, "coin"), 50, "coin")
	T.eq(weightOf(pool, "roast"), 12, "roast")
	T.eq(weightOf(pool, "coinbag1"), 10, "coinbag1")
	T.eq(weightOf(pool, "orologion"), 2, "orologion")
	T.eq(weightOf(pool, "vacuum"), 2, "vacuum")
	T.eq(weightOf(pool, "coinbagmax"), 1, "coinbagmax")
	T.eq(weightOf(pool, "rosary"), 1, "rosary")
	T.eq(weightOf(pool, "nft"), 1, "nft")
	T.eq(weightOf(pool, "clover"), 0.5, "clover")
	T.eq(weightOf(pool, "gilded"), 1, "gilded")
	T.eq(#pool, 10, "ten BASE entries")
end)

T.test("PK-03 pickups_meta.md L49-50 + L59-65: level 1 excludes the level-gated entries -> 73.5", function()
	local pool = Pickups.dropPool(1, 1.0)
	T.eq(Pickups.poolTotal(pool), 73.5, "total")
	T.eq(weightOf(pool, "orologion"), nil, "orologion (lv 4)")
	T.eq(weightOf(pool, "vacuum"), nil, "vacuum (lv 12)")
	T.eq(weightOf(pool, "coinbagmax"), nil, "coinbagmax (lv 5)")
	T.eq(weightOf(pool, "rosary"), nil, "rosary (lv 8)")
	T.eq(weightOf(pool, "gilded"), nil, "gilded (lv 30)")
	T.eq(#pool, 5, "five entries")
	T.eq(Pickups.poolTotal(Pickups.dropPool(4, 1.0)), 75.5, "lv4 adds orologion")
	T.eq(Pickups.poolTotal(Pickups.dropPool(29, 1.0)), 79.5, "lv29 everything but gilded")
end)

T.test("PK-03 pickups_meta.md L66-68 + L41: EXTRA entries never enter the pool", function()
	for _, level in { 1, 30, 100 } do
		for _, luck in { 1.0, 1.5, 3.0 } do
			local pool = Pickups.dropPool(level, luck)
			T.eq(weightOf(pool, "sorbetto"), nil, "sorbetto")
			T.eq(weightOf(pool, "pickup_reroll_dice"), nil, "reroll dice")
			T.eq(weightOf(pool, "goldfinger"), nil, "goldfinger")
		end
	end
end)

T.test("PK-03 pickups_meta.md L20 + L70: P(coin) at level 30 == Data baseShareAtZeroLuck 0.621118", function()
	local pool = Pickups.dropPool(30, 1.0)
	local coin = weightOf(pool, "coin") :: number
	T.eq(coin / Pickups.poolTotal(pool), 0.621118, "share", 1e-6)
	local entry = (PickupsMeta.data.lightSources.dropTable :: { any })[1]
	T.eq(entry.id, "coin", "first entry is coin")
	T.eq(coin / Pickups.poolTotal(pool), entry.baseShareAtZeroLuck, "Data share", 1e-6)
end)

T.test("PK-03 pool weights equal Data rarityWeight for every BASE entry at luck 1.0", function()
	local pool = Pickups.dropPool(100, 1.0)
	for _, e in PickupsMeta.data.lightSources.dropTable :: { any } do
		if e.contentGroup == "BASE" then
			T.eq(weightOf(pool, e.id), e.rarityWeight, e.id)
		end
	end
end)

T.test("PK-04 pickups_meta.md L72-76 (conflict #5): Luck multiplies only isRare weights", function()
	local base = Pickups.dropPool(30, 1.0)
	local lucky = Pickups.dropPool(30, 1.5)
	T.eq(weightOf(lucky, "coin"), weightOf(base, "coin"), "coin unchanged")
	T.eq(weightOf(lucky, "coinbag1"), weightOf(base, "coinbag1"), "coinbag1 unchanged")
	T.eq(weightOf(lucky, "clover"), weightOf(base, "clover"), "clover unchanged (contradicts wiki)")
	T.eq(weightOf(lucky, "gilded"), weightOf(base, "gilded"), "gilded unchanged")
	T.truthy((weightOf(lucky, "roast") :: number) >= 12, "roast boosted")
	for _, id in { "roast", "orologion", "vacuum", "coinbagmax", "rosary", "nft" } do
		T.truthy((weightOf(lucky, id) :: number) > (weightOf(base, id) :: number), id .. " boosted")
	end
end)

T.test("PK-04 the rare multiplier is exactly 1.0 at base Luck and lives in Tuning (NOT from research)", function()
	T.eq(type(Tuning.rareDropLuckScale), "number", "Tuning.rareDropLuckScale exists")
	T.eq(Pickups.rareWeightMultiplier(1.0), 1, "1.0 at base luck")
	T.truthy(Pickups.rareWeightMultiplier(1.5) > 1, "grows with luck")
	local pool = Pickups.dropPool(30, 1.0)
	for _, e in PickupsMeta.data.lightSources.dropTable :: { any } do
		if e.contentGroup == "BASE" then
			T.eq(weightOf(pool, e.id), e.rarityWeight, e.id .. " raw at luck 1.0")
		end
	end
end)

T.test("PK-03/04 rollDrop only returns pool members for the level", function()
	local rng = Rng.new(50)
	local pool = Pickups.dropPool(1, 1.0)
	for _ = 1, 2000 do
		local id = Pickups.rollDrop(1, 1.0, rng)
		T.truthy(id ~= nil and weightOf(pool, id :: string) ~= nil, "member " .. tostring(id))
	end
end)

return T.finish()
