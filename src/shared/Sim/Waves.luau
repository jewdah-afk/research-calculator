--!strict
--[[
	Sim/Waves.luau -- the Mad Forest wave schedule: which wave is active at a
	given run time, the map events and bosses due in a time window, and the
	spawn-count model the Spawner ticks against.

	Oracle: research/vs/enemies_waves.md.
	  * §1 "Wave `time` = minute x 60 and is the START of the wave; the wave
	    runs until the next one." -- at(time) is the wave with the greatest
	    start time <= time. 31 waves, 0 s .. 1800 s; the 1800 s wave has no
	    successor and stays active for the rest of the run.
	  * §1 "`spawnIntervalSeconds` is the shipped `frequency` field" and
	    "`minEnemiesOnScreen` is the shipped `minimum`: the game tops the
	    field up to at least this many." -- copied through unchanged.
	  * §1 "Treasure `chances` ships as [5-item%, 3-item%, 1-item%]" -- the
	    generated Data already splits them into chancePercent{5,3,1}Item and
	    they stay raw percents here; Sim/Chests owns the percent -> fraction
	    conversion. A wave whose treasure carries the Data sentinel has no chest
	    entry (§3: "480s XLBAT (no chest entry)") and exposes treasure = nil.
	  * §4 map events table: "Blank cells are fields the shipped wave entry
	    omits (the event's own defaults apply)." The delay / repeat / duration
	    defaults are not in the data, so those stay nil (the WaveEvent fields
	    are optional); the fire chance must be a number for the Spawner's
	    roll, so an omitted chance reads Tuning.defaults.eventChancePercent
	    through DataAccess.num. "Note the 300s FLOWER_WALL is shipped with
	    `chance: 0`, i.e. it never fires" -- a shipped 0 is a real value and
	    passes through untouched.
	  * §3 "Chests: dropped by the wave's `bosses` (and arcana holders)" and
	    "Mad Forest boss-with-chest schedule, straight from the data" --
	    bossesBetween pairs each wave's `bosses` with that wave's treasure.
	    Arcana holders are out of scope (no Arcanas in this port) and are
	    not returned.
	  * core_loop.md / CoreLoop.data.runStructure.reaper: "A Reaper spawns at
	    the time limit; +1 each further minute, unbounded"
	    (spawnIntervalAfterLimit 60, extraReaperPerMinute true). The first
	    Reaper is the 1800 s wave's own boss; every further one is emitted by
	    bossesBetween at timeLimit + k * spawnIntervalAfterLimit, k >= 1,
	    with the same boss list as the time-limit wave and its (absent)
	    treasure.
	  * Research gap, docs/ARCHITECTURE.md "Spawner note": the data has no
	    spawn count per tick ("data.madForest.waves[*].spawnCountPerTick" is
	    in EnemiesWaves.unknowns). spawnCount implements the documented
	    model: nothing until spawnIntervalSeconds has elapsed, then top the
	    field up to minEnemiesOnScreen, capped at Tuning.maxSpawnPerTick.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require. The aliases below restate
	Types.TreasureConfig / WaveEvent / ActiveWave structurally; keep them in
	step with Types.luau.
]]

local Tuning = require("../Tuning")
local CoreLoop = require("../Data/CoreLoop")
local EnemiesWaves = require("../Data/EnemiesWaves")
local DataAccess = require("./DataAccess")

-- Mirrors Types.TreasureConfig.
export type TreasureConfig = {
	chancePercent5Item: number,
	chancePercent3Item: number,
	chancePercent1Item: number,
	level: number,
	fixedPrizes: { string },
}

-- Mirrors Types.WaveEvent.
export type WaveEvent = {
	eventType: string,
	time: number,
	chancePercent: number,
	amount: number?,
	repeatCount: number?,
	delay: number?,
	duration: number?,
}

-- Mirrors Types.ActiveWave.
export type ActiveWave = {
	index: number,
	startTime: number,
	minEnemiesOnScreen: number,
	spawnIntervalSeconds: number,
	enemies: { string },
	bosses: { string },
	treasure: TreasureConfig?,
}

export type BossSpawn = { enemyId: string, time: number, treasure: TreasureConfig? }

-- A number the data always carries for this stage. There is no engine
-- default for it (a made-up wave interval or chest odds would be an invented
-- balance number), so anything but a number is an error, never a fallback.
local function required(value: any, context: string): number
	if type(value) ~= "number" then
		error(string.format("Waves: %s is not a number in Data (%s)", context, tostring(value)))
	end
	return value
end

-- A Data field the shipped entry may omit: nil when it carries the sentinel.
local function optional(value: any, context: string): number?
	if value == nil or DataAccess.isUnknown(value) then
		return nil
	end
	return required(value, context)
end

local function copyStrings(list: any, context: string): { string }
	local out: { string } = {}
	for i, v in list :: { any } do
		if type(v) ~= "string" then
			error(string.format("Waves: %s[%d] is not a string in Data", context, i))
		end
		out[i] = v
	end
	return out
end

local function treasureOf(raw: any, context: string): TreasureConfig?
	if raw == nil or DataAccess.isUnknown(raw) then
		return nil
	end
	local fixed: { string } = {}
	if not DataAccess.isUnknown(raw.fixedPrizes) then
		fixed = copyStrings(raw.fixedPrizes, context .. ".fixedPrizes")
	end
	return {
		chancePercent5Item = required(raw.chancePercent5Item, context .. ".chancePercent5Item"),
		chancePercent3Item = required(raw.chancePercent3Item, context .. ".chancePercent3Item"),
		chancePercent1Item = required(raw.chancePercent1Item, context .. ".chancePercent1Item"),
		level = required(raw.level, context .. ".level"),
		fixedPrizes = fixed,
	}
end

-- ------------------------------------------------------------ build once
-- Every wave, event and boss is resolved from Data at load so the per-tick
-- functions allocate nothing beyond their result lists.
local stage = EnemiesWaves.data.madForest
local rawWaves = stage.waves :: { any }

local WAVES: { ActiveWave } = {}
-- Per wave index: the events / bosses / raw treasure of that wave.
local WAVE_EVENTS: { { WaveEvent } } = {}
local WAVE_BOSSES: { { string } } = {}

for index, raw in rawWaves do
	local context = string.format("madForest.waves[%d]", index)
	local startTime = required(raw.time, context .. ".time")
	if index > 1 and startTime <= WAVES[index - 1].startTime then
		error(string.format("Waves: %s.time is not after the previous wave", context))
	end
	local wave: ActiveWave = {
		index = index,
		startTime = startTime,
		minEnemiesOnScreen = required(raw.minEnemiesOnScreen, context .. ".minEnemiesOnScreen"),
		spawnIntervalSeconds = required(raw.spawnIntervalSeconds, context .. ".spawnIntervalSeconds"),
		enemies = copyStrings(raw.enemies, context .. ".enemies"),
		bosses = copyStrings(raw.bosses, context .. ".bosses"),
		treasure = treasureOf(raw.treasure, context .. ".treasure"),
	}
	WAVES[index] = wave
	WAVE_BOSSES[index] = wave.bosses

	local events: { WaveEvent } = {}
	for e, rawEvent in raw.events :: { any } do
		local ec = string.format("%s.events[%d]", context, e)
		if type(rawEvent.eventType) ~= "string" then
			error("Waves: " .. ec .. ".eventType is not a string in Data")
		end
		events[e] = {
			eventType = rawEvent.eventType,
			time = startTime,
			-- Shipped 0 stays 0; an omitted chance takes the engine default.
			chancePercent = DataAccess.num(rawEvent.chancePercent, "eventChancePercent"),
			amount = optional(rawEvent.amount, ec .. ".amount"),
			repeatCount = optional(rawEvent["repeat"], ec .. ".repeat"),
			delay = optional(rawEvent.delay, ec .. ".delay"),
			duration = optional(rawEvent.duration, ec .. ".duration"),
		}
	end
	WAVE_EVENTS[index] = events
end

local WAVE_COUNT = #WAVES
if WAVE_COUNT < 1 then
	error("Waves: madForest has no waves in Data")
end

-- The run's time limit and the wave that starts on it (the CYCLE_COMPLETE
-- wave whose boss is the first Reaper). Extra Reapers repeat its boss list.
local TIME_LIMIT = required(stage.timeLimit, "madForest.timeLimit")
local REAPER_INTERVAL =
	required(CoreLoop.data.runStructure.reaper.spawnIntervalAfterLimit, "runStructure.reaper.spawnIntervalAfterLimit")
local LIMIT_WAVE: ActiveWave? = nil
for _, wave in WAVES do
	if wave.startTime == TIME_LIMIT then
		LIMIT_WAVE = wave
	end
end
if LIMIT_WAVE == nil then
	error("Waves: no wave starts at madForest.timeLimit in Data")
end
local limitWave: ActiveWave = LIMIT_WAVE :: ActiveWave

local Waves = {}

-- Number of waves in the stage table (31 on Mad Forest).
Waves.count = WAVE_COUNT

-- The wave active at `time`: the one with the greatest start time <= time.
-- The returned table is shared and must be treated as read-only. Negative
-- time is a caller bug (the run clock starts at 0 and never runs backwards).
function Waves.at(time: number): ActiveWave
	if type(time) ~= "number" or time ~= time or time < 0 then
		error(string.format("Waves.at: time must be a number >= 0, got %s", tostring(time)))
	end
	local index = WAVE_COUNT
	while index > 1 and WAVES[index].startTime > time do
		index -= 1
	end
	return WAVES[index]
end

-- Every map event of every wave whose start time lies in (t0, t1], in wave
-- order. `time` is the wave start; delay/repeatCount/duration are as shipped
-- (nil where the entry omits them) and chancePercent is a 0-100 percent. A
-- caller-owned `out` list is cleared and filled in place when given; the
-- list and the number of entries are both returned.
function Waves.eventsBetween(t0: number, t1: number, out: { WaveEvent }?): ({ WaveEvent }, number)
	local result: { WaveEvent } = out or {}
	if out ~= nil then
		table.clear(out)
	end
	local n = 0
	for index, wave in WAVES do
		local t = wave.startTime
		if t > t0 and t <= t1 then
			for _, event in WAVE_EVENTS[index] do
				n += 1
				result[n] = event
			end
		end
	end
	return result, n
end

-- Reuses `entry` (a boss slot left in a caller's scratch list by an earlier
-- call) instead of allocating, so a per-tick caller allocates nothing.
local function fillBoss(entry: BossSpawn?, enemyId: string, time: number, treasure: TreasureConfig?): BossSpawn
	if entry == nil then
		return { enemyId = enemyId, time = time, treasure = treasure }
	end
	entry.enemyId = enemyId
	entry.time = time
	entry.treasure = treasure
	return entry
end

-- Every boss due in (t0, t1]: each wave's `bosses` at the wave start with
-- that wave's treasure (nil where the data has no chest entry), then one
-- more Reaper spawn every spawnIntervalAfterLimit past the time limit,
-- without bound. With a caller-owned `out` list the results are written into
-- it (reusing its boss tables) and the returned count -- not `#list` -- says
-- how many of them are live this call; without one a fresh list is returned.
function Waves.bossesBetween(t0: number, t1: number, out: { BossSpawn }?): ({ BossSpawn }, number)
	local result: { BossSpawn } = out or {}
	local n = 0
	for index, wave in WAVES do
		local t = wave.startTime
		if t > t0 and t <= t1 then
			for _, enemyId in WAVE_BOSSES[index] do
				n += 1
				result[n] = fillBoss(result[n], enemyId, t, wave.treasure)
			end
		end
	end
	if t1 > TIME_LIMIT and #limitWave.bosses > 0 then
		-- First extra spawn strictly after t0: k >= 1 and limit + k*interval > t0.
		local k = 1
		if t0 > TIME_LIMIT then
			k = math.floor((t0 - TIME_LIMIT) / REAPER_INTERVAL) + 1
		end
		local t = TIME_LIMIT + k * REAPER_INTERVAL
		while t <= t1 do
			if t > t0 then
				for _, enemyId in limitWave.bosses do
					n += 1
					result[n] = fillBoss(result[n], enemyId, t, limitWave.treasure)
				end
			end
			k += 1
			t = TIME_LIMIT + k * REAPER_INTERVAL
		end
	end
	return result, n
end

-- Documented spawner model (docs/ARCHITECTURE.md "Spawner note"): nothing
-- until the wave's interval has elapsed since the last spawn tick, then top
-- the field up to minEnemiesOnScreen, never more than Tuning.maxSpawnPerTick
-- in one tick. The caller resets `sinceLast` when this returns from an
-- elapsed interval.
function Waves.spawnCount(wave: ActiveWave, alive: number, sinceLast: number): number
	if sinceLast < wave.spawnIntervalSeconds then
		return 0
	end
	local deficit = wave.minEnemiesOnScreen - alive
	if deficit <= 0 then
		return 0
	end
	return math.min(deficit, Tuning.maxSpawnPerTick)
end

return Waves
