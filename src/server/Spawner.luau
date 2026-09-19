--!strict
--[[
	server/Spawner.luau -- turns the wave table into enemies on the ring.

	Oracle: Sim/Waves (which reads research/vs/enemies_waves.md) for WHAT is
	due and WHEN; docs/ARCHITECTURE.md "Spawner note" for the ring model,
	which is ours because the research has no spawn count per tick.

	Three things are due at any moment, and each is read over the half-open
	window (lastTime, time] so nothing fires twice and nothing is skipped
	when a frame is long:

	  * Trash. Every wave.spawnIntervalSeconds, Waves.spawnCount tops the
	    field up to wave.minEnemiesOnScreen, capped at Tuning.maxSpawnPerTick
	    (ARCHITECTURE.md, Spawner note). `alive` is the manager's live count,
	    so enemies recycled onto the ring by EnemyManager still count and the
	    field does not double up behind the player.
	  * Bosses. Waves.bossesBetween, including the 1800 s Reaper and one more
	    every 60 s after it, unbounded (core_loop.md §1). A boss carries its
	    wave's treasure; onBoss hands both to the caller, which owns chests.
	  * Map events. Waves.eventsBetween gives eventType, chancePercent,
	    repeatCount and delay. The chance is rolled ONCE per entry when it
	    comes due (enemies_waves.md §4 lists one chance per entry, not one
	    per repeat); on success the entry's repeats are queued at `delay`
	    apart and emitted through onEvent as they fall due.

	    RESEARCH GAP, deliberately not guessed: enemies_waves.md §4 states
	    "The internal definitions of these event types -- how many enemies a
	    swarm emits, and the geometry of the flower wall/ring -- are not in
	    Stage.json and remain unknown." So this module schedules events
	    exactly as shipped and reports them; it does NOT spawn anything for
	    them. With onEvent left nil, BAT_SWARM and friends are inert. Filling
	    that in means inventing a swarm size, which the build rules forbid.

	Positions: every spawn lands at a uniformly random angle on the
	Tuning.spawnRingRadius ring around the player. EnemyManager recycles
	anything past Tuning.despawnRadius back onto the same ring.

	Allocation: the pending-event queue is the only table that grows, and it
	grows once per shipped event entry (23 on Mad Forest) for the whole run.
	The spawn path itself allocates nothing per enemy beyond what
	EnemyManager.spawn does.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require. The aliases below restate it
	structurally; keep them in step with Types.luau.
]]

local Tuning = require("../shared/Tuning")
local Waves = require("../shared/Sim/Waves")
local DataAccess = require("../shared/Sim/DataAccess")
local EnemyStats = require("../shared/Sim/EnemyStats")

export type EnemyHandle = number

-- Mirrors Types.Rng.
export type Rng = {
	next: (self: Rng) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
}

export type TreasureConfig = Waves.TreasureConfig

-- The slice of server/EnemyManager this module needs. Anything with these
-- two members works, which is what makes the spawner testable headless.
export type EnemyPool = {
	spawn: (self: any, typeId: string, x: number, z: number, stats: EnemyStats.EnemyScaledStats) -> EnemyHandle?,
	aliveCount: (self: any) -> number,
}

export type Deps = {
	enemies: EnemyPool,
	rng: Rng,
}

export type Spawner = {
	-- Run time of the last step; the window starts here.
	time: number,
	-- Seconds since the last trash spawn tick (Waves.spawnCount reads it).
	sinceLast: number,
	-- Totals, for the HUD and for tests.
	spawned: number,
	bossesSpawned: number,
	eventsFired: number,

	-- A boss just spawned, with the treasure its wave ships (nil where the
	-- wave has no chest entry). The caller owns chests, not this module.
	onBoss: ((handle: EnemyHandle, enemyId: string, treasure: TreasureConfig?) -> ())?,
	-- One occurrence of a map event came due. `occurrence` counts from 1 up
	-- to the entry's repeatCount. See the research gap in the header: no
	-- enemies are spawned for this.
	onEvent: ((eventType: string, time: number, occurrence: number) -> ())?,

	-- Advances to absolute run time `time` and spawns everything due in
	-- (self.time, time]. The run clock stops while paused, so a paused loop
	-- simply does not call this and nothing accrues.
	step: (self: Spawner, time: number, playerX: number, playerZ: number, playerLevel: number, curse: number) -> (),
	-- Back to t = 0 with an empty event queue (new run).
	reset: (self: Spawner) -> (),
}

type PendingEvent = { eventType: string, time: number, occurrence: number }

type Internal = Spawner & {
	deps: Deps,
	pending: { PendingEvent },
	pendingCount: number,
}

local Spawner = {}
Spawner.__index = Spawner

-- A uniformly random point on the spawn ring around (px, pz).
local function ringPoint(rng: Rng, px: number, pz: number): (number, number)
	local angle = rng:range(0, math.pi * 2)
	return px + math.cos(angle) * Tuning.spawnRingRadius, pz + math.sin(angle) * Tuning.spawnRingRadius
end

-- Drops every queued occurrence whose time has passed, oldest first. The
-- queue is short (one shipped entry's repeats at a time), so the linear
-- compaction costs nothing and keeps emission in time order.
local function drainEvents(s: Internal, time: number)
	local pending = s.pending
	local count = s.pendingCount
	if count == 0 then
		return
	end
	local onEvent = s.onEvent
	local kept = 0
	for i = 1, count do
		local entry = pending[i]
		if entry.time <= time then
			s.eventsFired += 1
			if onEvent ~= nil then
				onEvent(entry.eventType, entry.time, entry.occurrence)
			end
		else
			kept += 1
			pending[kept] = entry
		end
	end
	for i = kept + 1, count do
		pending[i] = nil
	end
	s.pendingCount = kept
end

-- Queues the occurrences of one shipped event entry, chance already passed.
-- repeatCount nil means the single occurrence at the entry's own time; delay
-- nil means no spacing (enemies_waves.md §4: "Blank cells are fields the
-- shipped wave entry omits").
local function queueEvent(s: Internal, event: Waves.WaveEvent)
	-- Absent repeats/delay are UNKNOWN, not zero: DataAccess substitutes the
	-- documented default (Tuning.defaults), never a bare fallback.
	local repeats = DataAccess.num(event.repeatCount, "eventRepeatCount")
	local delay = DataAccess.num(event.delay, "eventDelaySeconds")
	local pending = s.pending
	for k = 1, repeats do
		s.pendingCount += 1
		pending[s.pendingCount] = {
			eventType = event.eventType,
			time = event.time + (k - 1) * delay,
			occurrence = k,
		}
	end
end

function Spawner.new(deps: Deps): Spawner
	local self: Internal = {
		deps = deps,
		time = 0,
		sinceLast = 0,
		spawned = 0,
		bossesSpawned = 0,
		eventsFired = 0,
		pending = {},
		pendingCount = 0,
		onBoss = nil,
		onEvent = nil,
		step = Spawner.step,
		reset = Spawner.reset,
	} :: any
	return (setmetatable(self, Spawner) :: any) :: Spawner
end

function Spawner.reset(self: Spawner)
	local s = self :: Internal
	s.time = 0
	s.sinceLast = 0
	s.spawned = 0
	s.bossesSpawned = 0
	s.eventsFired = 0
	for i = 1, s.pendingCount do
		s.pending[i] = nil
	end
	s.pendingCount = 0
end

function Spawner.step(self: Spawner, time: number, playerX: number, playerZ: number, playerLevel: number, curse: number)
	local s = self :: Internal
	local t0 = s.time
	if time < t0 then
		error(string.format("Spawner.step: time must not run backwards (%f -> %f)", t0, time))
	end
	local dt = time - t0
	s.time = time
	if dt == 0 then
		return
	end
	local rng = s.deps.rng
	local pool = s.deps.enemies

	-- 1. Map events due in (t0, time], chance rolled once per shipped entry.
	for _, event in Waves.eventsBetween(t0, time) do
		if rng:chance(event.chancePercent / Tuning.percentScale) then
			queueEvent(s, event)
		end
	end
	drainEvents(s, time)

	-- 2. Bosses due in (t0, time], the Reaper and its every-60 s repeats
	--    among them. A boss spawns on the ring like anything else.
	for _, boss in Waves.bossesBetween(t0, time) do
		local stats = EnemyStats.scaled(boss.enemyId, boss.time, playerLevel, curse)
		local x, z = ringPoint(rng, playerX, playerZ)
		local handle = pool:spawn(boss.enemyId, x, z, stats)
		if handle ~= nil then
			s.bossesSpawned += 1
			local onBoss = s.onBoss
			if onBoss ~= nil then
				onBoss(handle, boss.enemyId, boss.treasure)
			end
		end
	end

	-- 3. Trash, on the wave's own interval.
	local wave = Waves.at(time)
	s.sinceLast += dt
	local count = Waves.spawnCount(wave, pool:aliveCount(), s.sinceLast)
	if s.sinceLast >= wave.spawnIntervalSeconds then
		-- Sim/Waves.spawnCount: "The caller resets `sinceLast` when this
		-- returns from an elapsed interval." The reset is on the INTERVAL
		-- elapsing, not on the count: a full field spends its tick and waits
		-- for the next one, rather than topping up the instant an enemy dies.
		s.sinceLast = 0
	end
	if count > 0 then
		local roster = wave.enemies
		if #roster > 0 then
			for _ = 1, count do
				local enemyId = rng:pick(roster)
				local stats = EnemyStats.scaled(enemyId, time, playerLevel, curse)
				local x, z = ringPoint(rng, playerX, playerZ)
				if pool:spawn(enemyId, x, z, stats) ~= nil then
					s.spawned += 1
				end
			end
		end
	end
end

return Spawner
