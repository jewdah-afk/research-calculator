--!strict
-- Sim/Waves. Oracle: research/vs/enemies_waves.md §1 L230-262 (the 31-wave
-- Mad Forest table), §4 L339-372 (events), L323-335 (boss/chest schedule),
-- core_loop.md L15 (one more Reaper every minute after 30:00);
-- docs/ARCHITECTURE.md "Spawner note" (documented spawner model).
local T = require("./_harness")
local Waves = require("../src/shared/Sim/Waves")
local Tuning = require("../src/shared/Tuning")
local CoreLoop = require("../src/shared/Data/CoreLoop")

local function names(list: { string }): string
	return table.concat(list, ",")
end

T.test("WV-01 enemies_waves.md L232: at(0) is wave 1: min 15, interval 1.0, BAT3, no boss", function()
	local w = Waves.at(0)
	T.eq(w.index, 1, "index")
	T.eq(w.startTime, 0, "startTime")
	T.eq(w.minEnemiesOnScreen, 15, "min")
	T.eq(w.spawnIntervalSeconds, 1.0, "interval")
	T.eq(names(w.enemies), "BAT3", "enemies")
	T.eq(#w.bosses, 0, "no boss")
end)

T.test("WV-01 enemies_waves.md L214: a wave runs until the next one starts", function()
	T.eq(Waves.at(59.99).index, 1, "59.99 still wave 1")
	T.eq(Waves.at(60).index, 2, "60 is wave 2")
	T.eq(Waves.at(119.5).index, 2, "119.5 still wave 2")
	T.eq(Waves.at(30).startTime, 0, "startTime of wave 1")
	T.eq(Waves.at(90).startTime, 60, "startTime of wave 2")
end)

T.test("WV-01 enemies_waves.md L233: at(60): min 30, interval 1, ZOMBIE+BAT1, boss BAT4", function()
	local w = Waves.at(60)
	T.eq(w.index, 2, "index")
	T.eq(w.minEnemiesOnScreen, 30, "min")
	T.eq(w.spawnIntervalSeconds, 1, "interval")
	T.eq(names(w.enemies), "ZOMBIE,BAT1", "enemies")
	T.eq(names(w.bosses), "BAT4", "bosses")
end)

T.test("WV-01 enemies_waves.md L243/L246: 660 s min 300 @0.1; 840 s min 20 @0.1", function()
	T.eq(Waves.at(660).minEnemiesOnScreen, 300, "660 min")
	T.eq(Waves.at(660).spawnIntervalSeconds, 0.1, "660 interval")
	T.eq(names(Waves.at(660).enemies), "SKELETON", "660 enemies")
	T.eq(Waves.at(840).minEnemiesOnScreen, 20, "840 min")
	T.eq(Waves.at(840).spawnIntervalSeconds, 0.1, "840 interval")
	T.eq(names(Waves.at(840).enemies), "XLBAT,WEREWOLF", "840 enemies")
	T.eq(names(Waves.at(840).bosses), "BAT5", "840 boss")
end)

T.test("WV-01 enemies_waves.md L261-262: 1799.9 is wave 30 (BAT4,BAT5 min 300); 1800+ is wave 31 (Reaper)", function()
	local w30 = Waves.at(1799.9)
	T.eq(w30.index, 30, "index")
	T.eq(w30.minEnemiesOnScreen, 300, "min")
	T.eq(names(w30.enemies), "BAT4,BAT5", "enemies")
	for _, t in { 1800, 1801, 9999 } do
		local w = Waves.at(t)
		T.eq(w.index, 31, "index at " .. t)
		T.eq(w.startTime, 1800, "startTime")
		T.eq(w.minEnemiesOnScreen, 1, "min")
		T.eq(w.spawnIntervalSeconds, 10, "interval")
		T.eq(#w.enemies, 0, "no roster")
		T.eq(names(w.bosses), "BOSS_XLDEATH", "Reaper")
	end
end)

T.test("WV-01 enemies_waves.md L232-262: all 31 wave starts are minute x 60", function()
	for i = 1, 31 do
		local w = Waves.at((i - 1) * 60)
		T.eq(w.index, i, "index at minute " .. (i - 1))
		T.eq(w.startTime, (i - 1) * 60, "startTime")
	end
end)

T.test("WV-01 at(-1) errors or returns wave 1", function()
	local ok, w = pcall(Waves.at, -1)
	if ok then
		T.eq((w :: any).index, 1, "index")
	end
end)

T.test(
	"WV-02 enemies_waves.md L233 + pickups_meta.md L153/L172: at(60).treasure is 0/0/30 level 1 fixed AMOUNT",
	function()
		local t = Waves.at(60).treasure
		T.truthy(t ~= nil, "has treasure")
		local tr = t :: any
		T.eq(tr.chancePercent5Item, 0, "5")
		T.eq(tr.chancePercent3Item, 0, "3")
		T.eq(tr.chancePercent1Item, 30, "1")
		T.eq(tr.level, 1, "level")
		T.eq(#tr.fixedPrizes, 1, "one fixed prize")
		T.eq(tr.fixedPrizes[1], "AMOUNT", "AMOUNT")
	end
)

T.test("WV-02 pickups_meta.md L155-156: 420 s is level 2 with [3,10,50]; 300 s is [1,5,100]", function()
	local t420 = Waves.at(420).treasure :: any
	T.eq(t420.level, 2, "420 level")
	T.eq(t420.chancePercent5Item, 3, "420 5")
	T.eq(t420.chancePercent3Item, 10, "420 3")
	T.eq(t420.chancePercent1Item, 50, "420 1")
	T.eq(#t420.fixedPrizes, 0, "420 no fixed prizes (UNKNOWN -> empty list)")
	local t300 = Waves.at(300).treasure :: any
	T.eq(t300.chancePercent5Item, 1, "300 5")
	T.eq(t300.chancePercent3Item, 5, "300 3")
	T.eq(t300.chancePercent1Item, 100, "300 1")
	T.eq(t300.level, 1, "300 level")
end)

T.test("WV-02 enemies_waves.md L234/L240: waves without a treasure return nil", function()
	T.eq(Waves.at(120).treasure, nil, "120")
	T.eq(Waves.at(480).treasure, nil, "480 (XLBAT, no chest entry L330)")
	T.eq(Waves.at(0).treasure, nil, "0")
	T.eq(Waves.at(1800).treasure, nil, "1800 (Reaper, no chest L335)")
end)

T.test("WV-03 enemies_waves.md L341: no event before 120 s; (119,120] has one BAT_SWARM", function()
	T.eq(#Waves.eventsBetween(0, 60), 0, "(0,60]")
	T.eq(#Waves.eventsBetween(0, 119), 0, "(0,119]")
	local evs = Waves.eventsBetween(119, 120)
	T.eq(#evs, 1, "one event")
	T.eq(evs[1].eventType, "BAT_SWARM", "type")
	T.eq(evs[1].time, 120, "time")
	T.eq(evs[1].delay, 5, "delay")
	T.eq(evs[1].repeatCount, 2, "repeat")
	T.eq(evs[1].chancePercent, Tuning.defaults.eventChancePercent, "blank chance -> engine default (L365-366)")
	T.truthy(evs[1].chancePercent > 0, "default is never 0")
end)

T.test("WV-03 (t0, t1] excludes t0 and includes t1: (120,180] has only the 180 s event", function()
	local evs = Waves.eventsBetween(120, 180)
	T.eq(#evs, 1, "one event")
	T.eq(evs[1].time, 180, "time")
	T.eq(evs[1].chancePercent, 10, "L342 chance 10")
	T.eq(evs[1].repeatCount, 1, "repeat 1")
end)

T.test("WV-03 enemies_waves.md L344 + L370: the 300 s FLOWER_WALL ships chance 0, duration 30", function()
	local evs = Waves.eventsBetween(299, 300)
	T.eq(#evs, 1, "one event")
	T.eq(evs[1].eventType, "FLOWER_WALL", "type")
	T.eq(evs[1].chancePercent, 0, "chance 0 stays 0")
	T.eq(evs[1].duration, 30, "duration")
end)

T.test("WV-03 enemies_waves.md L352-353: two GHOST_SWARM at 780 s, delays 1.2 / 2.3, x20, 70%", function()
	local evs = Waves.eventsBetween(779, 780)
	T.eq(#evs, 2, "two events")
	local delays = { evs[1].delay, evs[2].delay }
	table.sort(delays :: { any })
	T.eq(delays[1], 1.2, "delay 1.2")
	T.eq(delays[2], 2.3, "delay 2.3")
	for _, e in evs do
		T.eq(e.eventType, "GHOST_SWARM", "type")
		T.eq(e.time, 780, "time")
		T.eq(e.repeatCount, 20, "repeat")
		T.eq(e.chancePercent, 70, "chance")
	end
end)

T.test("WV-03 enemies_waves.md L354/L357: 900 s FLOWER_WALL 80%; 1500 s FLOWER_WALL delay 10 x5 dur 10", function()
	local e900 = Waves.eventsBetween(899, 900)
	T.eq(#e900, 1, "900 one")
	T.eq(e900[1].eventType, "FLOWER_WALL", "900 type")
	T.eq(e900[1].chancePercent, 80, "900 chance")
	local e1500 = Waves.eventsBetween(1499, 1500)
	T.eq(#e1500, 1, "1500 one")
	T.eq(e1500[1].delay, 10, "1500 delay")
	T.eq(e1500[1].repeatCount, 5, "1500 repeat")
	T.eq(e1500[1].duration, 10, "1500 duration")
	T.eq(e1500[1].chancePercent, Tuning.defaults.eventChancePercent, "1500 blank chance")
end)

T.test("WV-03 enemies_waves.md L341-362: 22 event rows in (0, 1800]", function()
	local all = Waves.eventsBetween(0, 1800)
	T.eq(#all, 22, "count")
	local last = all[#all]
	T.eq(last.eventType, "CYCLE_COMPLETE", "last is CYCLE_COMPLETE at 1800")
	T.eq(last.time, 1800, "time")
	local prev = 0
	for _, e in all do
		T.truthy(e.time >= prev, "sorted by time")
		prev = e.time
	end
	T.eq(#Waves.eventsBetween(0, 1799), 21, "without the 1800 s row")
end)

T.test("WV-04 enemies_waves.md L329: bossesBetween(0,60) -> BAT4 at 60 with the minute-1 treasure", function()
	local b = Waves.bossesBetween(0, 60)
	T.eq(#b, 1, "one boss")
	T.eq(b[1].enemyId, "BAT4", "id")
	T.eq(b[1].time, 60, "time")
	T.truthy(b[1].treasure ~= nil, "treasure")
	T.eq((b[1].treasure :: any).chancePercent1Item, 30, "1-item 30%")
end)

T.test("WV-04 enemies_waves.md L330: 480 s XLBAT has no chest entry -> treasure nil", function()
	local b = Waves.bossesBetween(479, 480)
	T.eq(#b, 1, "one boss")
	T.eq(b[1].enemyId, "XLBAT", "id")
	T.eq(b[1].time, 480, "time")
	T.eq(b[1].treasure, nil, "no treasure")
end)

T.test("WV-04 enemies_waves.md L331 + pickups_meta.md L158: 600 s BOSS_XLMANTIS with [3,10,100]", function()
	local b = Waves.bossesBetween(599, 600)
	T.eq(#b, 1, "one boss")
	T.eq(b[1].enemyId, "BOSS_XLMANTIS", "id")
	local t = b[1].treasure :: any
	T.eq(t.chancePercent5Item, 3, "5")
	T.eq(t.chancePercent3Item, 10, "3")
	T.eq(t.chancePercent1Item, 100, "1")
end)

T.test("WV-04 enemies_waves.md L329-335: 21 boss spawns in (0, 1800], excluding t0", function()
	local all = Waves.bossesBetween(0, 1800)
	T.eq(#all, 21, "count")
	T.eq(all[#all].enemyId, "BOSS_XLDEATH", "last is the Reaper")
	T.eq(all[#all].time, 1800, "at 1800")
	T.eq(#Waves.bossesBetween(60, 1800), 20, "(60,1800] drops the 60 s BAT4")
end)

T.test(
	"WV-04 core_loop.md L15 + CoreLoop reaper.spawnIntervalAfterLimit: one more Reaper every 60 s, unbounded",
	function()
		T.eq(CoreLoop.data.runStructure.reaper.spawnIntervalAfterLimit, 60, "Data interval")
		local b1 = Waves.bossesBetween(1800, 1860)
		T.eq(#b1, 1, "one")
		T.eq(b1[1].enemyId, "BOSS_XLDEATH", "id")
		T.eq(b1[1].time, 1860, "time")
		T.eq(b1[1].treasure, nil, "no treasure")
		local b2 = Waves.bossesBetween(1860, 1980)
		T.eq(#b2, 2, "two")
		T.eq(b2[1].time, 1920, "1920")
		T.eq(b2[2].time, 1980, "1980")
		local b3 = Waves.bossesBetween(3599, 3600)
		T.eq(#b3, 1, "one at 3600")
		T.eq(b3[1].time, 3600, "3600")
		T.eq(b3[1].enemyId, "BOSS_XLDEATH", "id")
		T.eq(#Waves.bossesBetween(1800.5, 1859.5), 0, "none strictly between")
	end
)

T.test(
	"WV-05 ARCHITECTURE.md Spawner note: 0 before the interval, then top-up capped by Tuning.maxSpawnPerTick",
	function()
		local w0 = Waves.at(0) -- min 15, interval 1
		T.eq(Waves.spawnCount(w0, 10, 0.5), 0, "before interval")
		T.eq(Waves.spawnCount(w0, 10, 1), 5, "top up to 15")
		T.eq(Waves.spawnCount(w0, 20, 1), 0, "already above min")
		T.eq(Waves.spawnCount(w0, 15, 1), 0, "exactly at min")
		T.eq(Waves.spawnCount(w0, 0, 1), 15, "empty screen")
		local w660 = Waves.at(660) -- min 300, interval 0.1
		T.eq(Waves.spawnCount(w660, 0, 0.1), Tuning.maxSpawnPerTick, "capped")
		T.eq(Waves.spawnCount(w660, 299, 0.1), 1, "one short")
		T.eq(Waves.spawnCount(w660, 0, 0.05), 0, "before the 0.1 s interval")
	end
)

return T.finish()
