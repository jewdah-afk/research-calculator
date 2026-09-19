--!strict
-- Sim/Experience. Oracle: research/vs/core_loop.md §5 L82-95 (piecewise
-- formula), L99-200 (the Lv1-100 table), §3 L54 (Growth multiplier),
-- L64-65 (merged gems can grant several levels).
local T = require("./_harness")
local F = require("./_fixtures")
local Experience = require("../src/shared/Sim/Experience")
local CoreLoop = require("../src/shared/Data/CoreLoop")

-- core_loop.md L85-89, transcribed from the research, NOT from the module.
local function req(n: number): number
	local base
	if n <= 20 then
		base = 5 + 10 * (n - 1)
	elseif n <= 40 then
		base = 195 + 13 * (n - 20)
	else
		base = 455 + 16 * (n - 40)
	end
	if n == 20 then
		return base + 600
	elseif n == 40 then
		return base + 2400
	end
	return base
end

T.test("XP-01 core_loop.md L101-200: table literals at 1, 2, 19, 20, 21, 39, 40, 41, 100", function()
	T.eq(Experience.xpToNext(1), 5, "n=1")
	T.eq(Experience.xpToNext(2), 15, "n=2")
	T.eq(Experience.xpToNext(19), 185, "n=19")
	T.eq(Experience.xpToNext(20), 795, "n=20 (+600 surcharge)")
	T.eq(Experience.xpToNext(21), 208, "n=21")
	T.eq(Experience.xpToNext(39), 442, "n=39")
	T.eq(Experience.xpToNext(40), 2855, "n=40 (+2400 surcharge)")
	T.eq(Experience.xpToNext(41), 471, "n=41")
	T.eq(Experience.xpToNext(100), 1415, "n=100")
end)

T.test("XP-01 core_loop.md L85-89: the formula continues beyond the Lv100 table", function()
	T.eq(Experience.xpToNext(101), 1431, "n=101 = 455 + 16*61")
	T.eq(Experience.xpToNext(150), 2215, "n=150 = 455 + 16*110")
	T.eq(Experience.xpToNext(101), req(101), "n=101 formula")
	T.eq(Experience.xpToNext(500), req(500), "n=500 formula")
end)

T.test("XP-01 core_loop.md L85-89 vs L101-200: formula and table agree for n = 1..100", function()
	local tbl = CoreLoop.data.experienceCurve.table :: { any }
	T.eq(#tbl, 100, "table has 100 rows")
	for n = 1, 100 do
		T.eq(Experience.xpToNext(n), tbl[n].xpToNextLevel, "table n=" .. n)
		T.eq(Experience.xpToNext(n), req(n), "formula n=" .. n)
		T.eq(tbl[n].level, n, "row level")
	end
end)

T.test("XP-02 core_loop.md L101/L120/L140/L200: cumulative 5, 2600, 11630, 68210", function()
	T.eq(Experience.cumulativeAt(1), 5, "n=1")
	T.eq(Experience.cumulativeAt(20), 2600, "n=20")
	T.eq(Experience.cumulativeAt(40), 11630, "n=40")
	T.eq(Experience.cumulativeAt(100), 68210, "n=100")
end)

T.test("XP-02 core_loop.md L99-200: cumulative column == running sum of xpToNext for n = 1..100", function()
	local tbl = CoreLoop.data.experienceCurve.table :: { any }
	local sum = 0
	for n = 1, 100 do
		sum += req(n)
		T.eq(Experience.cumulativeAt(n), sum, "sum n=" .. n)
		T.eq(Experience.cumulativeAt(n), tbl[n].cumulativeXp, "table n=" .. n)
	end
end)

T.test("XP-03 core_loop.md L54: gem value = base XP x Growth (multiplier, base 1.0)", function()
	T.eq(Experience.gemValue(1, 1), 1, "1 x 1")
	T.eq(Experience.gemValue(30, 1.4), 42, "30 x 1.4")
	T.eq(Experience.gemValue(2.5, 2), 5, "2.5 x 2 (growth spike)")
	T.eq(Experience.gemValue(0, 1.4), 0, "0 xp stays 0")
end)

T.test(
	"XP-04 core_loop.md L101: fresh Lv1 needs 5; addXp(4) no level, addXp(1) levels to 2 with xpToNext 15",
	function()
		local s = F.newState()
		T.eq(Experience.addXp(s, 4), 0, "gained after 4")
		T.eq(s.level, 1, "level")
		T.eq(s.xp, 4, "xp")
		T.eq(s.xpToNext, 5, "xpToNext")
		T.eq(Experience.addXp(s, 1), 1, "gained after +1")
		T.eq(s.level, 2, "level")
		T.eq(s.xp, 0, "xp")
		T.eq(s.xpToNext, 15, "xpToNext L102")
	end
)

T.test("XP-04 core_loop.md L65: a big gem carries overflow across several levels", function()
	local s = F.newState()
	-- 25 = 5 (Lv1->2) + 15 (Lv2->3) + 5 left over toward the 25 needed at Lv3.
	T.eq(Experience.addXp(s, 25), 2, "levels gained")
	T.eq(s.level, 3, "level")
	T.eq(s.xp, 5, "xp carried")
	T.eq(s.xpToNext, 25, "xpToNext L103")
end)

T.test("XP-04 core_loop.md L119-121: Lv19 + 185 + 795 crosses the Lv20 wall to Lv21 exactly", function()
	local s = F.newState({ level = 19, xp = 0, xpToNext = 185 })
	T.eq(Experience.addXp(s, 185 + 795), 2, "levels gained")
	T.eq(s.level, 21, "level")
	T.eq(s.xp, 0, "xp")
	T.eq(s.xpToNext, 208, "xpToNext L121")
end)

T.test("XP-04 addXp of 0 changes nothing", function()
	local s = F.newState({ level = 7, xp = 3, xpToNext = 65 })
	T.eq(Experience.addXp(s, 0), 0, "gained")
	T.eq(s.level, 7, "level")
	T.eq(s.xp, 3, "xp")
end)

return T.finish()
