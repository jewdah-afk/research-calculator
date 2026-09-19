--!strict
-- Sim/LevelUp. Oracle: research/vs/core_loop.md §2 L28-39 (options, 4th by
-- Luck, unique, slot rule, reroll/banish/skip, 20% XP) and §6 L204-211
-- (6 + 6 slots, max levels).
local T = require("./_harness")
local F = require("./_fixtures")
local LevelUp = require("../src/shared/Sim/LevelUp")
local Rng = require("../src/shared/Sim/Rng")
local CoreLoop = require("../src/shared/Data/CoreLoop")
local PassivesEvolutions = require("../src/shared/Data/PassivesEvolutions")
local Weapons = require("../src/shared/Data/Weapons")

type PlayerState = F.PlayerState
type LevelUpOption = F.LevelUpOption

local PASSIVE_IDS: { string } = {}
for _, p in PassivesEvolutions.data.passives :: { any } do
	table.insert(PASSIVE_IDS, p.id)
end
local WEAPON_IDS: { string } = {}
for id in Weapons.data do
	table.insert(WEAPON_IDS, id)
end

local function ids(offer: any): { string }
	local out = {}
	for _, o in offer.options do
		table.insert(out, o.itemId)
	end
	return out
end

local function fourFraction(luck: number, seed: number, n: number): number
	local state = F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" } })
	state.stats.luck = luck
	local rng = Rng.new(seed)
	local fours = 0
	for _ = 1, n do
		local offer = LevelUp.offer(state, rng)
		local count = #offer.options
		T.truthy(count == 3 or count == 4, "option count " .. count)
		T.truthy(count >= CoreLoop.data.levelUp.optionsOffered.min, "not below min")
		T.truthy(count <= CoreLoop.data.levelUp.optionsOffered.max, "not above max")
		if count == 4 then
			fours += 1
		end
	end
	return fours / n
end

T.test("LU-01 core_loop.md L30-31: 4th option with chance L/(100+L); luck 1.0 -> 0.50 +- 0.02", function()
	local frac = fourFraction(1.0, 1, 20000)
	T.truthy(math.abs(frac - 0.5) <= 0.02, "fraction " .. frac)
end)

T.test("LU-01 core_loop.md L31: luck 1.5 (150 points) -> 150/250 = 0.60 +- 0.02", function()
	local frac = fourFraction(1.5, 1, 20000)
	T.truthy(math.abs(frac - 0.6) <= 0.02, "fraction " .. frac)
end)

T.test("LU-01 core_loop.md L30: options offered is always 3 or 4 (CoreLoop optionsOffered min/max)", function()
	T.eq(CoreLoop.data.levelUp.optionsOffered.min, 3, "min 3")
	T.eq(CoreLoop.data.levelUp.optionsOffered.max, 4, "max 4")
end)

T.test("LU-02 core_loop.md L32-33: unique ids, never maxed, never banished; toLevel/isNew", function()
	local state = F.newState({
		weapons = { whip = 8, axe = 3 },
		weaponOrder = { "whip", "axe" },
		passives = { spinach = 5 },
		passiveOrder = { "spinach" },
		banished = { knife = true },
	})
	local rng = Rng.new(5)
	local sawAxe, sawCross = false, false
	for _ = 1, 5000 do
		local offer = LevelUp.offer(state, rng)
		local seen: { [string]: boolean } = {}
		for _, o in offer.options do
			T.eq(seen[o.itemId], nil, "duplicate " .. o.itemId)
			seen[o.itemId] = true
			T.truthy(o.itemId ~= "whip", "maxed whip offered")
			T.truthy(o.itemId ~= "spinach", "maxed spinach offered")
			T.truthy(o.itemId ~= "knife", "banished knife offered")
			if o.itemId == "axe" then
				sawAxe = true
				T.eq(o.kind, "weapon", "axe kind")
				T.eq(o.toLevel, 4, "axe toLevel")
				T.eq(o.isNew, false, "axe isNew")
			elseif o.itemId == "cross" then
				sawCross = true
				T.eq(o.kind, "weapon", "cross kind")
				T.eq(o.toLevel, 1, "cross toLevel")
				T.eq(o.isNew, true, "cross isNew")
			end
			if o.kind == "passive" then
				T.truthy(F.contains(PASSIVE_IDS, o.itemId), "passive id known " .. o.itemId)
			else
				T.truthy(F.contains(WEAPON_IDS, o.itemId), "weapon id known " .. o.itemId)
			end
		end
	end
	T.truthy(sawAxe, "axe offered at least once")
	T.truthy(sawCross, "cross offered at least once")
end)

T.test("LU-03 core_loop.md L33: 6 distinct weapons owned -> no new weapon is offered", function()
	local state = F.newState({
		weapons = { whip = 1, magic_wand = 1, knife = 1, axe = 1, cross = 1, fire_wand = 1 },
		weaponOrder = { "whip", "magic_wand", "knife", "axe", "cross", "fire_wand" },
	})
	local rng = Rng.new(9)
	local sawPassive, sawWeapon = false, false
	for _ = 1, 5000 do
		local offer = LevelUp.offer(state, rng)
		for _, o in offer.options do
			if o.kind == "weapon" then
				sawWeapon = true
				T.truthy(state.weapons[o.itemId] ~= nil, "new weapon offered: " .. o.itemId)
				T.eq(o.isNew, false, "owned weapon isNew")
				T.eq(o.toLevel, 2, "owned weapon toLevel")
			else
				sawPassive = true
				T.truthy(F.contains(PASSIVE_IDS, o.itemId), "passive id")
				T.eq(o.isNew, true, "new passive")
			end
		end
	end
	T.truthy(sawPassive and sawWeapon, "both kinds appear")
end)

T.test("LU-03 core_loop.md L33: 6 passives owned -> no new passive is offered", function()
	local state = F.newState({
		weapons = { whip = 1 },
		weaponOrder = { "whip" },
		passives = { spinach = 1, armor = 1, hollow_heart = 1, pummarola = 1, empty_tome = 1, candelabrador = 1 },
		passiveOrder = { "spinach", "armor", "hollow_heart", "pummarola", "empty_tome", "candelabrador" },
	})
	local rng = Rng.new(10)
	for _ = 1, 5000 do
		local offer = LevelUp.offer(state, rng)
		for _, o in offer.options do
			if o.kind == "passive" then
				T.truthy(state.passives[o.itemId] ~= nil, "new passive offered: " .. o.itemId)
				T.eq(o.toLevel, 2, "owned passive toLevel")
			else
				T.truthy(F.contains(WEAPON_IDS, o.itemId), "weapon id")
			end
		end
	end
end)

T.test("LU-04 core_loop.md L33-34: canOffer true from the start, false only when nothing is offerable", function()
	T.eq(LevelUp.canOffer(F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" } })), true, "start")
	T.eq(LevelUp.canOffer(F.newState()), true, "empty inventory")
	local full = F.newState({
		weapons = { whip = 8, magic_wand = 8, knife = 8, axe = 8, cross = 8, fire_wand = 8 },
		weaponOrder = { "whip", "magic_wand", "knife", "axe", "cross", "fire_wand" },
		passives = { spinach = 5, armor = 5, hollow_heart = 5, pummarola = 5, empty_tome = 5, duplicator = 2 },
		passiveOrder = { "spinach", "armor", "hollow_heart", "pummarola", "empty_tome", "duplicator" },
	})
	T.eq(LevelUp.canOffer(full), false, "everything maxed and full")
	local fivePassives = F.newState({
		weapons = { whip = 8, magic_wand = 8, knife = 8, axe = 8, cross = 8, fire_wand = 8 },
		weaponOrder = { "whip", "magic_wand", "knife", "axe", "cross", "fire_wand" },
		passives = { spinach = 5, armor = 5, hollow_heart = 5, pummarola = 5, empty_tome = 5 },
		passiveOrder = { "spinach", "armor", "hollow_heart", "pummarola", "empty_tome" },
	})
	T.eq(LevelUp.canOffer(fivePassives), true, "a passive slot is free")
	local oneUpgradeLeft = F.newState({
		weapons = { whip = 7, magic_wand = 8, knife = 8, axe = 8, cross = 8, fire_wand = 8 },
		weaponOrder = { "whip", "magic_wand", "knife", "axe", "cross", "fire_wand" },
		passives = { spinach = 5, armor = 5, hollow_heart = 5, pummarola = 5, empty_tome = 5, duplicator = 2 },
		passiveOrder = { "spinach", "armor", "hollow_heart", "pummarola", "empty_tome", "duplicator" },
	})
	T.eq(LevelUp.canOffer(oneUpgradeLeft), true, "one upgrade left")
end)

T.test("LU-04 offer with fewer offerable items than min still returns them (never invents)", function()
	local state = F.newState({
		weapons = { whip = 7, magic_wand = 8, knife = 8, axe = 8, cross = 8, fire_wand = 8 },
		weaponOrder = { "whip", "magic_wand", "knife", "axe", "cross", "fire_wand" },
		passives = { spinach = 5, armor = 5, hollow_heart = 5, pummarola = 5, empty_tome = 5, duplicator = 2 },
		passiveOrder = { "spinach", "armor", "hollow_heart", "pummarola", "empty_tome", "duplicator" },
	})
	local offer = LevelUp.offer(state, Rng.new(3))
	T.eq(#offer.options, 1, "only whip")
	T.eq(offer.options[1].itemId, "whip", "whip")
	T.eq(offer.options[1].toLevel, 8, "to 8")
end)

T.test("LU-05 core_loop.md L206-209: apply records a new weapon at 1 and appends to weaponOrder", function()
	local state = F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" } })
	local opt: LevelUpOption = { kind = "weapon", itemId = "cross", toLevel = 1, isNew = true }
	LevelUp.apply(state, opt)
	T.eq(state.weapons.cross, 1, "cross level")
	T.eq(state.weaponOrder[#state.weaponOrder], "cross", "appended")
	T.eq(#state.weaponOrder, 2, "order length")
end)

T.test("LU-05 core_loop.md L208: owned weapon levels by one, never above 8", function()
	local state = F.newState({ weapons = { whip = 7 }, weaponOrder = { "whip" } })
	local up: LevelUpOption = { kind = "weapon", itemId = "whip", toLevel = 8, isNew = false }
	LevelUp.apply(state, up)
	T.eq(state.weapons.whip, 8, "whip 8")
	T.eq(#state.weaponOrder, 1, "order unchanged")
	local over: LevelUpOption = { kind = "weapon", itemId = "whip", toLevel = 9, isNew = false }
	T.throws(function()
		LevelUp.apply(state, over)
	end, "whip above max")
	T.eq(state.weapons.whip, 8, "unchanged after refused apply")
end)

T.test("LU-05 passives_evolutions.md L26: Duplicator 1 -> 2, then refused (max 2)", function()
	local state = F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" } })
	local new: LevelUpOption = { kind = "passive", itemId = "duplicator", toLevel = 1, isNew = true }
	LevelUp.apply(state, new)
	T.eq(state.passives.duplicator, 1, "level 1")
	T.eq(state.passiveOrder[#state.passiveOrder], "duplicator", "appended")
	local up: LevelUpOption = { kind = "passive", itemId = "duplicator", toLevel = 2, isNew = false }
	LevelUp.apply(state, up)
	T.eq(state.passives.duplicator, 2, "level 2")
	local over: LevelUpOption = { kind = "passive", itemId = "duplicator", toLevel = 3, isNew = false }
	T.throws(function()
		LevelUp.apply(state, over)
	end, "duplicator above max")
	T.eq(state.passives.duplicator, 2, "unchanged")
end)

T.test("LU-05 core_loop.md L206-207: ownership never exceeds 6 per kind", function()
	local state = F.newState({
		weapons = { whip = 1, magic_wand = 1, knife = 1, axe = 1, cross = 1, fire_wand = 1 },
		weaponOrder = { "whip", "magic_wand", "knife", "axe", "cross", "fire_wand" },
	})
	local seventh: LevelUpOption = { kind = "weapon", itemId = "garlic", toLevel = 1, isNew = true }
	T.throws(function()
		LevelUp.apply(state, seventh)
	end, "7th weapon")
	T.eq(state.weapons.garlic, nil, "not added")
	T.eq(#state.weaponOrder, 6, "order unchanged")
end)

T.test("LU-06 core_loop.md L37-38: skip grants 20% of xpToNext and consumes a skip", function()
	T.eq(CoreLoop.data.levelUp.xpGrantedInsteadOfItem, 0.2, "Data 0.2")
	local state =
		F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" }, skips = 1, xpToNext = 15, xp = 0, level = 2 })
	local rng = Rng.new(4)
	local offer = LevelUp.offer(state, rng)
	LevelUp.skip(state, offer, rng)
	T.eq(state.xp, 3, "xp 0.2 x 15")
	T.eq(state.skips, 0, "skips consumed")
	T.eq(state.level, 2, "no level change")
end)

T.test("LU-06 skips = 0: skip is refused and the state is unchanged", function()
	local state =
		F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" }, skips = 0, xpToNext = 15, xp = 0, level = 2 })
	local rng = Rng.new(4)
	local offer = LevelUp.offer(state, rng)
	LevelUp.skip(state, offer, rng)
	T.eq(state.xp, 0, "xp unchanged")
	T.eq(state.level, 2, "level unchanged")
	T.eq(state.skips, 0, "skips stay 0")
end)

T.test("LU-06 core_loop.md L36: banish removes the item from the pool and consumes a banish", function()
	local state = F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" }, banishes = 1 })
	local rng = Rng.new(6)
	local offer = LevelUp.offer(state, rng)
	local fresh = LevelUp.banish(state, offer, rng, "knife")
	T.eq(state.banished.knife, true, "banished")
	T.eq(state.banishes, 0, "banishes consumed")
	T.eq(F.contains(ids(fresh), "knife"), false, "fresh offer has no knife")
	for _ = 1, 2000 do
		T.eq(F.contains(ids(LevelUp.offer(state, rng)), "knife"), false, "knife never offered again")
	end
end)

T.test("LU-06 banishes = 0: banish is refused and the state is unchanged", function()
	local state = F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" }, banishes = 0 })
	local rng = Rng.new(6)
	local offer = LevelUp.offer(state, rng)
	LevelUp.banish(state, offer, rng, "knife")
	T.eq(state.banished.knife, nil, "not banished")
	T.eq(state.banishes, 0, "banishes stay 0")
end)

T.test("LU-06 core_loop.md L35: reroll returns a fresh offer and consumes a reroll", function()
	local state = F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" }, rerolls = 2 })
	local rng = Rng.new(8)
	local offer = LevelUp.offer(state, rng)
	local fresh = LevelUp.reroll(state, offer, rng)
	T.eq(state.rerolls, 1, "rerolls consumed")
	T.truthy(#fresh.options == 3 or #fresh.options == 4, "fresh offer size")
	T.eq(fresh.rerollsLeft, 1, "offer reports rerollsLeft")
end)

T.test("LU-06 rerolls = 0: reroll returns the same offer and rerolls stays 0", function()
	local state = F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" }, rerolls = 0 })
	local rng = Rng.new(8)
	local offer = LevelUp.offer(state, rng)
	local before = ids(offer)
	local same = LevelUp.reroll(state, offer, rng)
	local after = ids(same)
	T.eq(#after, #before, "same size")
	for i, id in before do
		T.eq(after[i], id, "same option " .. i)
	end
	T.eq(state.rerolls, 0, "rerolls stay 0")
end)

T.test("LU-06 the offer carries the remaining counts", function()
	local state = F.newState({ weapons = { whip = 1 }, weaponOrder = { "whip" }, rerolls = 3, skips = 2, banishes = 1 })
	local offer = LevelUp.offer(state, Rng.new(1))
	T.eq(offer.rerollsLeft, 3, "rerollsLeft")
	T.eq(offer.skipsLeft, 2, "skipsLeft")
	T.eq(offer.banishesLeft, 1, "banishesLeft")
end)

return T.finish()
