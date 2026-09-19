--!strict
-- Sim/Chests. Oracle: research/vs/pickups_meta.md §3 L104-108 (items and gold
-- per level), L113-120 (roll order and Luck formula), L139-147 (per-minute
-- chances [5-item, 3-item, 1-item], base level fallback), L172-173 (minute-1
-- fixedPrizes AMOUNT), L134-137 (chests level owned items; evolutions out of
-- scope), §4 L181-183 (Greed multiplies every gold source).
local T = require("./_harness")
local F = require("./_fixtures")
local Chests = require("../src/shared/Sim/Chests")
local Rng = require("../src/shared/Sim/Rng")
local PickupsMeta = require("../src/shared/Data/PickupsMeta")

type TreasureConfig = F.TreasureConfig

local function treasure(c5: number, c3: number, c1: number, level: number, fixed: { string }?): TreasureConfig
	return {
		chancePercent5Item = c5,
		chancePercent3Item = c3,
		chancePercent1Item = c1,
		level = level,
		fixedPrizes = fixed or {},
	}
end

local function whipState(level: number): F.PlayerState
	return F.newState({ weapons = { whip = level }, weaponOrder = { "whip" } })
end

-- pickups_meta.md L147: the Silver Bat example reads [3, 10, 50].
local SILVER_BAT = treasure(3, 10, 50, 1)

T.test("CH-01 pickups_meta.md L113-120: 5-item check first; 0.02 < 0.03 -> 5 items", function()
	local r = Chests.roll(SILVER_BAT, 1.0, F.scriptedRng({ 0.02 }, 1), whipState(1), 540)
	T.eq(r.itemCount, 5, "itemCount")
end)

T.test("CH-01 pickups_meta.md L113-114: 5 fails, 3-item succeeds (0.05 < 0.10) -> 3 items", function()
	local r = Chests.roll(SILVER_BAT, 1.0, F.scriptedRng({ 0.5, 0.05 }, 1), whipState(1), 540)
	T.eq(r.itemCount, 3, "itemCount")
end)

T.test("CH-01 pickups_meta.md L113-114: 5 and 3 fail, 1-item succeeds (0.3 < 0.5) -> 1 item", function()
	local r = Chests.roll(SILVER_BAT, 1.0, F.scriptedRng({ 0.5, 0.5, 0.3 }, 1), whipState(1), 540)
	T.eq(r.itemCount, 1, "itemCount")
end)

T.test("CH-01 pickups_meta.md L114-115: all three fail -> configured base level 1 -> 1 item", function()
	local r = Chests.roll(SILVER_BAT, 1.0, F.scriptedRng({ 0.9, 0.9, 0.9 }, 1), whipState(1), 540)
	T.eq(r.itemCount, 1, "itemCount")
end)

T.test("CH-01 pickups_meta.md L142-144 + L156: minute-7 base level 2 -> fallback is 3 items", function()
	local r = Chests.roll(treasure(3, 10, 50, 2), 1.0, F.scriptedRng({ 0.9, 0.9, 0.9 }, 1), whipState(1), 420)
	T.eq(r.itemCount, 3, "itemCount")
end)

T.test("CH-01 pickups_meta.md L118-119: successChance = levelChance x totalLuck; luck 2.0 -> 0.06 threshold", function()
	local r = Chests.roll(SILVER_BAT, 2.0, F.scriptedRng({ 0.05 }, 1), whipState(1), 540)
	T.eq(r.itemCount, 5, "0.05 < 0.03 x 2")
	local r2 = Chests.roll(SILVER_BAT, 1.0, F.scriptedRng({ 0.05, 0.5, 0.5 }, 1), whipState(1), 540)
	T.eq(r2.itemCount, 1, "0.05 >= 0.03 at luck 1.0, falls through")
end)

T.test("CH-01 pickups_meta.md L155: minute-5 [1, 5, 100]: a 100% roll never fails", function()
	local r = Chests.roll(treasure(1, 5, 100, 1), 1.0, F.scriptedRng({ 0.5, 0.5, 0.999 }, 1), whipState(1), 300)
	T.eq(r.itemCount, 1, "itemCount")
end)

T.test("CH-01 itemCount is always 1, 3 or 5 over 2000 real rolls", function()
	local rng = Rng.new(21)
	for _ = 1, 2000 do
		local r = Chests.roll(SILVER_BAT, 1.3, rng, whipState(1), 540)
		T.truthy(r.itemCount == 1 or r.itemCount == 3 or r.itemCount == 5, "itemCount " .. r.itemCount)
	end
end)

T.test(
	"CH-02 pickups_meta.md L104-108: Data chest levels are 1/3/5 items with gold 100-200/300-600/500-1000",
	function()
		local levels = PickupsMeta.data.treasureChests.levels :: { any }
		T.eq(levels[1].items, 1, "L1 items")
		T.eq(levels[1].goldMin, 100, "L1 goldMin")
		T.eq(levels[1].goldMax, 200, "L1 goldMax")
		T.eq(levels[2].items, 3, "L2 items")
		T.eq(levels[2].goldMin, 300, "L2 goldMin")
		T.eq(levels[2].goldMax, 600, "L2 goldMax")
		T.eq(levels[3].items, 5, "L3 items")
		T.eq(levels[3].goldMin, 500, "L3 goldMin")
		T.eq(levels[3].goldMax, 1000, "L3 goldMax")
	end
)

T.test("CH-02 pickups_meta.md L106: forced 1-item chest pays a uniform integer in [100, 200] at greed 1.0", function()
	local rng = Rng.new(33)
	local lo, hi = math.huge, -math.huge
	for _ = 1, 2000 do
		local r = Chests.roll(treasure(0, 0, 100, 1), 1.0, rng, whipState(1), 60)
		T.eq(r.itemCount, 1, "itemCount")
		T.truthy(r.gold >= 100 and r.gold <= 200, "gold " .. r.gold)
		T.eq(r.gold, math.floor(r.gold), "integer gold at greed 1.0")
		lo = math.min(lo, r.gold)
		hi = math.max(hi, r.gold)
	end
	T.eq(lo, 100, "min observed")
	T.eq(hi, 200, "max observed")
end)

T.test("CH-02 pickups_meta.md L181-183: Greed multiplies chest gold; greed 1.5 -> [150, 300]", function()
	local rng = Rng.new(34)
	local state = whipState(1)
	state.stats.greed = 1.5
	for _ = 1, 2000 do
		local r = Chests.roll(treasure(0, 0, 100, 1), 1.0, rng, state, 60)
		T.truthy(r.gold >= 150 and r.gold <= 300, "gold " .. r.gold)
	end
end)

T.test("CH-02 pickups_meta.md L107-108: forced 3-item and 5-item chests pay their tier ranges", function()
	local rng = Rng.new(35)
	for _ = 1, 500 do
		local r3 = Chests.roll(treasure(0, 100, 0, 1), 1.0, rng, whipState(1), 420)
		T.eq(r3.itemCount, 3, "3 items")
		T.truthy(r3.gold >= 300 and r3.gold <= 600, "3-item gold " .. r3.gold)
		local r5 = Chests.roll(treasure(100, 0, 0, 1), 1.0, rng, whipState(1), 600)
		T.eq(r5.itemCount, 5, "5 items")
		T.truthy(r5.gold >= 500 and r5.gold <= 1000, "5-item gold " .. r5.gold)
	end
end)

T.test("CH-03 pickups_meta.md L134-137: grants level owned items by one, never past max, no evolutions", function()
	local rng = Rng.new(36)
	for _ = 1, 1000 do
		local r = Chests.roll(treasure(100, 0, 0, 1), 1.0, rng, whipState(7), 600)
		T.eq(r.itemCount, 5, "forced 5 items")
		local whipGrants = 0
		for _, g in r.grants do
			T.truthy(g.kind ~= "evolution", "no evolution")
			T.truthy(g.kind == "weapon" or g.kind == "passive", "kind " .. g.kind)
			if g.itemId == "whip" then
				whipGrants += 1
				T.eq(g.kind, "weapon", "whip kind")
				T.eq(g.toLevel, 8, "whip toLevel")
			else
				error("unexpected grant " .. g.kind .. " " .. g.itemId .. " (only whip is owned)")
			end
		end
		T.truthy(whipGrants <= 1, "at most one whip grant, got " .. whipGrants)
	end
end)

T.test("CH-03 grants to the same item in one chest have consecutive toLevel within max", function()
	local rng = Rng.new(37)
	for _ = 1, 500 do
		local state = F.newState({
			weapons = { whip = 3, knife = 1 },
			weaponOrder = { "whip", "knife" },
			passives = { spinach = 2 },
			passiveOrder = { "spinach" },
		})
		local r = Chests.roll(treasure(100, 0, 0, 1), 1.0, rng, state, 600)
		local next: { [string]: number } = { whip = 4, knife = 2, spinach = 3 }
		local max: { [string]: number } = { whip = 8, knife = 8, spinach = 5 }
		for _, g in r.grants do
			T.truthy(g.kind ~= "evolution", "no evolution")
			T.truthy(next[g.itemId] ~= nil, "owned item " .. g.itemId)
			T.eq(g.toLevel, next[g.itemId], g.itemId .. " consecutive")
			T.truthy(g.toLevel <= max[g.itemId], g.itemId .. " within max")
			next[g.itemId] += 1
		end
		T.truthy(#r.grants <= 5, "at most 5 grants")
	end
end)

T.test("CH-03 pickups_meta.md L172-173: minute-1 fixedPrizes AMOUNT -> Duplicator is grants[1]", function()
	local rng = Rng.new(38)
	for _ = 1, 1000 do
		local r = Chests.roll(treasure(0, 0, 30, 1, { "AMOUNT" }), 1.0, rng, whipState(1), 60)
		T.truthy(#r.grants >= 1, "has a grant")
		T.eq(r.grants[1].kind, "passive", "kind")
		T.eq(r.grants[1].itemId, "duplicator", "duplicator (vsId AMOUNT, passives_evolutions.md L45)")
		T.eq(r.grants[1].toLevel, 1, "toLevel 1")
		for _, g in r.grants do
			T.truthy(g.kind ~= "evolution", "no evolution")
		end
	end
end)

T.test("CH-03 pickups_meta.md L137: nothing upgradeable -> no grants, gold still paid", function()
	local rng = Rng.new(39)
	local state = F.newState({ weapons = { whip = 8 }, weaponOrder = { "whip" } })
	for _ = 1, 200 do
		local r = Chests.roll(treasure(0, 0, 100, 1), 1.0, rng, state, 60)
		T.eq(#r.grants, 0, "no grants")
		T.truthy(r.gold >= 100, "gold paid")
	end
end)

T.test("CH-04 Chests.roll does not mutate the PlayerState", function()
	local rng = Rng.new(40)
	local state = F.newState({
		weapons = { whip = 3, knife = 1 },
		weaponOrder = { "whip", "knife" },
		passives = { spinach = 2 },
		passiveOrder = { "spinach" },
		gold = 123,
	})
	local before = F.deepCopy(state)
	for _ = 1, 200 do
		Chests.roll(treasure(3, 10, 50, 1, { "AMOUNT" }), 1.3, rng, state, 540)
	end
	T.truthy(F.deepEqual(state, before), "state unchanged")
	T.eq(state.gold, 123, "gold untouched")
	T.eq(state.weapons.whip, 3, "whip untouched")
	T.eq(state.passives.duplicator, nil, "duplicator not added")
end)

return T.finish()
