--!strict
-- Sim/Stats. Oracle: research/vs/characters.md (base stats L265-282, per-level
-- bonuses L301-325), core_loop.md §5 L92-95 (universal growth spike),
-- passives_evolutions.md §1 L16-33 (per-level passive values).
local T = require("./_harness")
local F = require("./_fixtures")
local Stats = require("../src/shared/Sim/Stats")
local Characters = require("../src/shared/Data/Characters")

local IDS = { "antonio", "imelda", "pasqualina", "gennaro", "arca", "porta" }

-- characters.md L265-282: the six columns of the Base stats table.
T.test("ST-01 characters.md L265-282: Imelda is the pure baseline", function()
	local s = Stats.base("imelda")
	T.eq(s.maxHealth, 100, "maxHealth")
	T.eq(s.recovery, 0, "recovery")
	T.eq(s.armor, 0, "armor")
	T.eq(s.moveSpeed, 1, "moveSpeed")
	T.eq(s.might, 1, "might")
	T.eq(s.area, 1, "area")
	T.eq(s.speed, 1, "speed")
	T.eq(s.duration, 1, "duration")
	T.eq(s.amount, 0, "amount")
	T.eq(s.cooldown, 1, "cooldown")
	T.eq(s.luck, 1, "luck")
	T.eq(s.growth, 1, "growth")
	T.eq(s.greed, 1, "greed")
	T.eq(s.magnet, 0, "magnet")
	T.eq(s.revival, 0, "revival")
	T.eq(s.curse, 1, "curse")
end)

T.test("ST-01 characters.md L267-276: the five non-baseline cells", function()
	T.eq(Stats.base("antonio").maxHealth, 120, "antonio maxHealth")
	T.eq(Stats.base("antonio").armor, 1, "antonio armor")
	T.eq(Stats.base("gennaro").maxHealth, 120, "gennaro maxHealth")
	T.eq(Stats.base("gennaro").amount, 1, "gennaro amount")
	T.eq(Stats.base("arca").might, 1.1, "arca might")
	T.eq(Stats.base("porta").area, 1.3, "porta area")
	T.eq(Stats.base("porta").cooldown, 0.1, "porta cooldown")
	T.eq(Stats.base("pasqualina").speed, 1.1, "pasqualina speed")
end)

T.test("ST-01 characters.md L284 (source vst-chardata): every key equals Characters.data baseStats", function()
	for _, id in IDS do
		local s = Stats.base(id) :: any
		local rec = (Characters.data :: any)[id]
		for _, key in F.STAT_KEYS do
			T.eq(s[key], rec.baseStats[key], id .. "." .. key)
		end
	end
end)

T.test("ST-01 Stats.base returns a fresh table each call", function()
	local a = Stats.base("imelda")
	local b = Stats.base("imelda")
	T.truthy(a ~= b, "distinct tables")
end)

-- characters.md L303-325: per-level bonus deltas, cumulative.
T.test("ST-02 characters.md L304: Antonio +0.1 Might at 10/20/30/40/50, cap 1.5", function()
	T.eq(Stats.forLevel("antonio", 1).might, 1, "Lv1")
	T.eq(Stats.forLevel("antonio", 9).might, 1, "Lv9")
	T.eq(Stats.forLevel("antonio", 10).might, 1.1, "Lv10")
	T.eq(Stats.forLevel("antonio", 49).might, 1.4, "Lv49")
	T.eq(Stats.forLevel("antonio", 50).might, 1.5, "Lv50")
	T.eq(Stats.forLevel("antonio", 100).might, 1.5, "Lv100")
end)

T.test("ST-02 characters.md L308: Imelda +0.1 Growth at 5/10/15, cap 1.3", function()
	T.eq(Stats.forLevel("imelda", 4).growth, 1, "Lv4")
	T.eq(Stats.forLevel("imelda", 5).growth, 1.1, "Lv5")
	T.eq(Stats.forLevel("imelda", 10).growth, 1.2, "Lv10")
	T.eq(Stats.forLevel("imelda", 15).growth, 1.3, "Lv15")
	T.eq(Stats.forLevel("imelda", 19).growth, 1.3, "Lv19")
end)

T.test("ST-02 characters.md L312: Pasqualina 1.1 Speed +0.1 at 5/10/15 = 1.4 (conflict 1: same numbers)", function()
	T.eq(Stats.forLevel("pasqualina", 1).speed, 1.1, "Lv1")
	T.eq(Stats.forLevel("pasqualina", 5).speed, 1.2, "Lv5")
	T.eq(Stats.forLevel("pasqualina", 15).speed, 1.4, "Lv15")
	T.eq(Stats.forLevel("pasqualina", 60).speed, 1.4, "Lv60")
end)

T.test("ST-02 characters.md L320: Arca -0.05 Cooldown at 10/20/30, cap 0.85", function()
	T.eq(Stats.forLevel("arca", 9).cooldown, 1, "Lv9")
	T.eq(Stats.forLevel("arca", 10).cooldown, 0.95, "Lv10")
	T.eq(Stats.forLevel("arca", 20).cooldown, 0.9, "Lv20")
	T.eq(Stats.forLevel("arca", 30).cooldown, 0.85, "Lv30")
	T.eq(Stats.forLevel("arca", 30).might, 1.1, "innate might kept")
end)

T.test("ST-02 characters.md L324: Porta +0.3 Cooldown at 2/3/4 -> 0.4/0.7/1.0", function()
	T.eq(Stats.forLevel("porta", 1).cooldown, 0.1, "Lv1")
	T.eq(Stats.forLevel("porta", 2).cooldown, 0.4, "Lv2")
	T.eq(Stats.forLevel("porta", 3).cooldown, 0.7, "Lv3")
	T.eq(Stats.forLevel("porta", 4).cooldown, 1.0, "Lv4")
	T.eq(Stats.forLevel("porta", 50).cooldown, 1.0, "Lv50")
	T.eq(Stats.forLevel("porta", 50).area, 1.3, "area kept")
end)

T.test("ST-02 characters.md L316: Gennaro has no scaling bonus except the growth spike", function()
	local base = Stats.base("gennaro") :: any
	for level = 1, 100 do
		local s = Stats.forLevel("gennaro", level) :: any
		for _, key in F.STAT_KEYS do
			if key ~= "growth" then
				T.eq(s[key], base[key], "Lv" .. level .. " " .. key)
			end
		end
	end
end)

-- core_loop.md L94-95: "+100% Growth at levels 20 and 40, reverted with -100%
-- Growth at levels 21 and 41"; characters.md L261: every character has them.
T.test("ST-03 core_loop.md L94-95: growth spike at 20/40, reverted at 21/41, for all six", function()
	for _, id in IDS do
		local b19 = Stats.forLevel(id, 19).growth
		T.eq(Stats.forLevel(id, 20).growth, b19 + 1, id .. " Lv20")
		T.eq(Stats.forLevel(id, 21).growth, b19, id .. " Lv21")
		T.eq(Stats.forLevel(id, 39).growth, b19, id .. " Lv39")
		T.eq(Stats.forLevel(id, 40).growth, b19 + 1, id .. " Lv40")
		T.eq(Stats.forLevel(id, 41).growth, b19, id .. " Lv41")
	end
end)

T.test("ST-03 core_loop.md L94 + characters.md L308: Imelda growth 1.3 at 15, 2.3 at 20, 1.3 at 21", function()
	T.eq(Stats.forLevel("imelda", 15).growth, 1.3, "Lv15")
	T.eq(Stats.forLevel("imelda", 20).growth, 2.3, "Lv20")
	T.eq(Stats.forLevel("imelda", 21).growth, 1.3, "Lv21")
	T.eq(Stats.forLevel("imelda", 40).growth, 2.3, "Lv40")
	T.eq(Stats.forLevel("imelda", 41).growth, 1.3, "Lv41")
end)

T.test("ST-03 characters.md L261: baseline growth 2 at 20, 1 at 21, 2 at 40, 1 at 41", function()
	T.eq(Stats.forLevel("gennaro", 20).growth, 2, "Lv20")
	T.eq(Stats.forLevel("gennaro", 21).growth, 1, "Lv21")
	T.eq(Stats.forLevel("gennaro", 40).growth, 2, "Lv40")
	T.eq(Stats.forLevel("gennaro", 41).growth, 1, "Lv41")
end)

-- passives_evolutions.md §1 L16-33: per-level values; SCHEMA.md conventions.
T.test("ST-04 passives_evolutions.md L18-33: multiplier passives add the summed per-level values", function()
	local base = Stats.base("imelda")
	T.eq(Stats.apply(base, { spinach = 5 }).might, 1.5, "spinach 5 might")
	T.eq(Stats.apply(base, { spinach = 1 }).might, 1.1, "spinach 1 might")
	T.eq(Stats.apply(base, { empty_tome = 5 }).cooldown, 0.6, "empty tome 5 cooldown")
	T.eq(Stats.apply(base, { empty_tome = 2 }).cooldown, 0.84, "empty tome 2 cooldown")
	T.eq(Stats.apply(base, { candelabrador = 5 }).area, 1.5, "candelabrador 5 area")
	T.eq(Stats.apply(base, { bracer = 5 }).speed, 1.5, "bracer 5 speed")
	T.eq(Stats.apply(base, { spellbinder = 5 }).duration, 1.5, "spellbinder 5 duration")
	T.eq(Stats.apply(base, { wings = 5 }).moveSpeed, 1.5, "wings 5 moveSpeed")
	T.eq(Stats.apply(base, { clover = 5 }).luck, 1.5, "clover 5 luck")
	T.eq(Stats.apply(base, { crown = 5 }).growth, 1.4, "crown 5 growth")
	T.eq(Stats.apply(base, { stone_mask = 5 }).greed, 1.5, "stone mask 5 greed")
	T.eq(Stats.apply(base, { skull_omaniac = 5 }).curse, 1.5, "skull 5 curse")
end)

T.test(
	"ST-04 passives_evolutions.md L28 (conflict: non-uniform, game files authoritative): Attractorb magnet +1.61",
	function()
		local base = Stats.base("imelda")
		T.eq(Stats.apply(base, { attractorb = 1 }).magnet, 0.5, "Lv1")
		T.eq(Stats.apply(base, { attractorb = 2 }).magnet, 0.83, "Lv2")
		T.eq(Stats.apply(base, { attractorb = 3 }).magnet, 1.08, "Lv3")
		T.eq(Stats.apply(base, { attractorb = 4 }).magnet, 1.28, "Lv4")
		T.eq(Stats.apply(base, { attractorb = 5 }).magnet, 1.61, "Lv5")
	end
)

T.test("ST-04 passives_evolutions.md L19/L26/L33: armor/amount/revival add flat", function()
	local base = Stats.base("imelda")
	T.eq(Stats.apply(base, { armor = 5 }).armor, 5, "armor 5")
	T.eq(Stats.apply(base, { duplicator = 2 }).amount, 2, "duplicator 2")
	T.eq(Stats.apply(base, { tiragisu = 2 }).revival, 2, "tiragisu 2")
	T.eq(Stats.apply(Stats.base("antonio"), { armor = 3 }).armor, 4, "antonio armor 1 + 3")
	T.eq(Stats.apply(Stats.base("gennaro"), { duplicator = 2 }).amount, 3, "gennaro amount 1 + 2")
end)

T.test("ST-04 passives_evolutions.md L21: Pummarola recovery flat HP/s, +1.0 at Lv5", function()
	local base = Stats.base("imelda")
	T.eq(Stats.apply(base, { pummarola = 1 }).recovery, 0.2, "Lv1")
	T.eq(Stats.apply(base, { pummarola = 5 }).recovery, 1.0, "Lv5")
end)

T.test(
	"ST-04 passives_evolutions.md L20 + conflict #4 (additive authoritative): Hollow Heart +20% maxHealth/level",
	function()
		T.eq(Stats.apply(Stats.base("imelda"), { hollow_heart = 5 }).maxHealth, 200, "imelda hh5")
		T.eq(Stats.apply(Stats.base("imelda"), { hollow_heart = 1 }).maxHealth, 120, "imelda hh1")
		T.eq(Stats.apply(Stats.base("antonio"), { hollow_heart = 3 }).maxHealth, 192, "antonio hh3")
		T.eq(Stats.apply(Stats.base("antonio"), { hollow_heart = 5 }).maxHealth, 240, "antonio hh5")
	end
)

T.test("ST-04 passives stack independently and leave other stats alone", function()
	local s = Stats.apply(Stats.base("imelda"), { spinach = 2, candelabrador = 3, armor = 1 })
	T.eq(s.might, 1.2, "might")
	T.eq(s.area, 1.3, "area")
	T.eq(s.armor, 1, "armor")
	T.eq(s.speed, 1, "speed untouched")
	T.eq(s.maxHealth, 100, "maxHealth untouched")
end)

T.test("ST-04 Stats.apply does not mutate its input", function()
	local base = Stats.base("imelda")
	Stats.apply(base, { spinach = 5, hollow_heart = 5 })
	T.eq(base.might, 1, "might untouched")
	T.eq(base.maxHealth, 100, "maxHealth untouched")
end)

T.test(
	"ST-05 passives_evolutions.md L26/L33: level above Data maxLevel (2 for duplicator/tiragisu, 5 others) errors",
	function()
		local base = Stats.base("imelda")
		T.throws(function()
			Stats.apply(base, { duplicator = 3 })
		end, "duplicator 3")
		T.throws(function()
			Stats.apply(base, { tiragisu = 3 })
		end, "tiragisu 3")
		T.throws(function()
			Stats.apply(base, { spinach = 6 })
		end, "spinach 6")
		T.throws(function()
			Stats.apply(base, { nonsense = 1 })
		end, "unknown passive")
	end
)

T.test("ST-05 unknown character id errors", function()
	T.throws(function()
		Stats.base("dracula")
	end, "base")
	T.throws(function()
		Stats.forLevel("dracula", 1)
	end, "forLevel")
end)

T.test("ST-06 ARCHITECTURE.md Sim/Stats: effective == apply(forLevel) for all six at 1/20/21/50", function()
	local passives = { spinach = 3, hollow_heart = 2, duplicator = 1, attractorb = 5, empty_tome = 4 }
	for _, id in IDS do
		for _, level in { 1, 20, 21, 50 } do
			local a = Stats.effective(id, level, passives) :: any
			local b = Stats.apply(Stats.forLevel(id, level), passives) :: any
			for _, key in F.STAT_KEYS do
				T.eq(a[key], b[key], id .. " Lv" .. level .. " " .. key)
			end
		end
	end
end)

T.test("ST-06 characters.md L304 + passives_evolutions.md L18: Antonio Lv50 + Spinach 5 might = 2.0", function()
	T.eq(Stats.effective("antonio", 50, { spinach = 5 }).might, 2.0, "might")
end)

return T.finish()
