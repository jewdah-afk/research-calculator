--!strict
--[[
	Headless tests for server/EnemyManager + server/SpatialHash.

	Oracle: research/vs/enemies_waves.md (statlines, knockback-taken caveat),
	docs/ARCHITECTURE.md (structure-of-arrays, ring recycle, EnemyQuery) and
	Tuning for the engine constants. Every expected value below is computed
	from Data / Tuning numbers, never by calling the implementation.
]]
local T = require("./_harness")
local Tuning = require("../src/shared/Tuning")
local EnemiesWaves = require("../src/shared/Data/EnemiesWaves")
local Rng = require("../src/shared/Sim/Rng")
local EnemyStats = require("../src/shared/Sim/EnemyStats")
local EnemyManager = require("../src/server/EnemyManager")
local SpatialHash = require("../src/server/SpatialHash")

local STAGE_SPEED = EnemiesWaves.data.madForest.stageModifiers.enemySpeed :: number

-- Data statline by internalId (enemies_waves.md §2), at display scale.
local function record(internalId: string): any
	for _, e in EnemiesWaves.data.enemies :: { any } do
		if e.internalId == internalId then
			return e
		end
	end
	error("no such enemy in Data: " .. internalId)
end

local function stats(id: string)
	return EnemyStats.scaled(id, 0, 1, 1)
end

local function newManager(capacity: number?)
	return EnemyManager.new(Rng.new(7), capacity)
end

-- ------------------------------------------------------------ spawn / pool
T.test("spawn fills the structure-of-arrays columns and the query sees it", function()
	local m = newManager(8)
	local h = m:spawn("ZOMBIE", 10, -4, stats("ZOMBIE"))
	T.truthy(h ~= nil, "spawn returns a handle")
	local handle = h :: number
	T.eq(m.query.count(), 1, "count")
	T.truthy(m.query.isAlive(handle), "alive")
	local x, z = m.query.position(handle)
	T.eq(x, 10, "x")
	T.eq(z, -4, "z")
	T.eq(m:typeId(handle), "ZOMBIE", "typeId")
	-- enemies_waves.md §2: ZOMBIE health 1 raw -> 10 display, power 10,
	-- kbTaken 0.8, xp 1, not a boss.
	T.eq(m:health(handle), record("ZOMBIE").health, "health from Data")
	T.eq(m:health(handle), 10, "zombie health 10 (display scale)")
	T.eq(m:power(handle), 10, "zombie power 10")
	T.eq(m:knockbackTaken(handle), 0.8, "zombie kbTaken 0.8")
	T.eq(m:xp(handle), 1, "zombie xp 1")
	T.eq(m:isBoss(handle), false, "zombie is not a boss")
	T.eq(m:speed(handle), 100 * Tuning.enemySpeedScale * STAGE_SPEED, "zombie speed studs/s")
end)

T.test("pool is bounded by capacity and handles are recycled after a step", function()
	local m = newManager(3)
	local a = m:spawn("BAT1", 0, 0, stats("BAT1")) :: number
	local b = m:spawn("BAT1", 1, 0, stats("BAT1")) :: number
	local c = m:spawn("BAT1", 2, 0, stats("BAT1")) :: number
	T.truthy(a ~= b and b ~= c and a ~= c, "distinct handles")
	T.eq(m:spawn("BAT1", 3, 0, stats("BAT1")), nil, "full pool returns nil")
	m:despawn(b)
	T.eq(m.query.count(), 2, "count after despawn")
	T.eq(m.query.isAlive(b), false, "despawned handle not alive")
	-- The handle is held until the next step so in-flight lists stay valid.
	T.eq(m:spawn("BAT1", 3, 0, stats("BAT1")), nil, "still full before the step")
	m:step(0, 100, 100)
	local d = m:spawn("BAT1", 3, 0, stats("BAT1"))
	T.eq(d, b, "freed handle is reused")
end)

T.test("onSpawn fires with the handle and typeId", function()
	local m = newManager(4)
	local got: { any } = {}
	m.onSpawn = function(handle: number, typeId: string)
		got[1] = handle
		got[2] = typeId
	end
	local h = m:spawn("GHOST", 0, 0, stats("GHOST"))
	T.eq(got[1], h, "handle")
	T.eq(got[2], "GHOST", "typeId")
end)

-- --------------------------------------------------------------- movement
T.test("enemies walk straight at the player at their scaled speed", function()
	local m = newManager(4)
	local h = m:spawn("ZOMBIE", 10, 0, stats("ZOMBIE")) :: number
	local dt = 0.1
	m:step(dt, 0, 0)
	-- enemies_waves.md §2 ZOMBIE speed 100; studs/s = 100 * enemySpeedScale *
	-- stage enemySpeed (1.1, §1 "Stage mods").
	local speed = 100 * Tuning.enemySpeedScale * STAGE_SPEED
	local x, z = m.query.position(h)
	T.eq(x, 10 - speed * dt, "moved toward the player along x")
	T.eq(z, 0, "no z drift")
	T.eq(m.facing[h], math.atan2(0 - 0, 0 - x), "faces the player")
end)

T.test("an enemy stops at the player instead of overshooting", function()
	local m = newManager(4)
	local h = m:spawn("GHOST", 0.5, 0, stats("GHOST")) :: number
	m:step(1, 0, 0) -- GHOST speed 200 -> 26.4 studs/s, far more than 0.5
	local x, z = m.query.position(h)
	T.eq(x, 0, "arrived exactly")
	T.eq(z, 0, "arrived exactly")
end)

T.test("the Reaper's scaled speed is Data speed * scale * stage mod", function()
	local m = newManager(4)
	local h = m:spawn("BOSS_XLDEATH", 0, 100, stats("BOSS_XLDEATH")) :: number
	-- enemies_waves.md §2 BOSS_XLDEATH speed 1200.
	T.eq(m:speed(h), 1200 * Tuning.enemySpeedScale * STAGE_SPEED, "reaper speed")
	T.eq(m:isBoss(h), true, "reaper is a boss")
	T.eq(m:health(h), 655350, "reaper health at display scale")
end)

-- -------------------------------------------------------------- knockback
T.test("knockback = weapon knockback * knockbackTaken, pushed away from the player", function()
	local m = newManager(4)
	local h = m:spawn("ZOMBIE", 10, 0, stats("ZOMBIE")) :: number
	m:step(0, 0, 0) -- player at the origin, no movement
	-- enemies_waves.md §2 ZOMBIE kbTaken 0.8; a Knife (weapons.md knockback
	-- 0.5) gives 0.4 units -> 0.4 * Tuning.knockbackScale studs/s away.
	local died = m:damage(h, 1, 0.5)
	T.eq(died, false, "1 damage does not kill 10 hp")
	T.eq(m:health(h), 9, "hp 9")
	local dt = 0.1
	m:step(dt, 0, 0)
	local speed = 100 * Tuning.enemySpeedScale * STAGE_SPEED
	local push = 0.5 * 0.8 * Tuning.knockbackScale
	local x = m.query.position(h)
	T.eq(x, 10 - speed * dt + push * dt, "walked in, pushed out")
end)

T.test("knockback decays by exp(-knockbackDecay * dt) each step", function()
	local m = newManager(4)
	local h = m:spawn("SKELETON", 10, 0, stats("SKELETON")) :: number
	m:step(0, 0, 0)
	m:damage(h, 1, 1) -- SKELETON kbTaken 1 -> knockbackScale studs/s
	local dt = 0.05
	local speed = 100 * Tuning.enemySpeedScale * STAGE_SPEED
	local push = Tuning.knockbackScale
	local damp = math.exp(-Tuning.knockbackDecay * dt)
	local expected = 10
	local v = push
	for _ = 1, 3 do
		m:step(dt, 0, 0)
		expected = expected - speed * dt + v * dt
		v *= damp
	end
	local x = m.query.position(h)
	T.eq(x, expected, "three decaying pushes", 1e-9)
end)

T.test("Ghost (kbTaken 0) is immune; Garlic (knockback 0) pushes nobody", function()
	local m = newManager(4)
	local g = m:spawn("GHOST", 10, 0, stats("GHOST")) :: number
	local z = m:spawn("ZOMBIE", 10, 5, stats("ZOMBIE")) :: number
	m:step(0, 0, 0)
	m:damage(g, 1, 1)
	m:damage(z, 1, 0)
	local dt = 0.1
	m:step(dt, 0, 0)
	local gx = m.query.position(g)
	local zx, zz = m.query.position(z)
	T.eq(gx, 10 - 200 * Tuning.enemySpeedScale * STAGE_SPEED * dt, "ghost only walked")
	-- Zombie only walked: along its unit direction toward the origin.
	local d = math.sqrt(10 * 10 + 5 * 5)
	local move = 100 * Tuning.enemySpeedScale * STAGE_SPEED * dt
	T.eq(zx, 10 - 10 / d * move, "zombie x only walked")
	T.eq(zz, 5 - 5 / d * move, "zombie z only walked")
end)

T.test("the Reaper (kbTaken -0.5) is pulled toward the player", function()
	local m = newManager(4)
	local h = m:spawn("BOSS_XLDEATH", 50, 0, stats("BOSS_XLDEATH")) :: number
	m:step(0, 0, 0)
	m:damage(h, 1, 1)
	local dt = 0.01
	m:step(dt, 0, 0)
	local speed = 1200 * Tuning.enemySpeedScale * STAGE_SPEED
	local pull = -0.5 * Tuning.knockbackScale
	local x = m.query.position(h)
	T.eq(x, 50 - speed * dt + pull * dt, "walked in and pulled in")
end)

-- ------------------------------------------------------------------ death
T.test("death fires onDeath once with xp and isBoss, then frees the handle", function()
	local m = newManager(4)
	local deaths = 0
	local seen: { any } = {}
	m.onDeath = function(handle: number, typeId: string, x: number, z: number, xp: number, isBoss: boolean)
		deaths += 1
		seen = { handle, typeId, x, z, xp, isBoss }
	end
	local h = m:spawn("MUDMAN2", 3, 4, stats("MUDMAN2")) :: number
	-- enemies_waves.md §2 MUDMAN2 health 15 raw -> 150 display, xp 2.5.
	T.eq(m:damage(h, 100, 0), false, "100 of 150")
	T.eq(m:damage(h, 50, 0), true, "lethal")
	T.eq(deaths, 1, "one death")
	T.eq(seen[1], h, "handle")
	T.eq(seen[2], "MUDMAN2", "typeId")
	T.eq(seen[3], 3, "x")
	T.eq(seen[4], 4, "z")
	T.eq(seen[5], 2.5, "xp")
	T.eq(seen[6], false, "isBoss")
	T.eq(m.query.isAlive(h), false, "dead")
	T.eq(m.query.count(), 0, "count")
	T.eq(m:damage(h, 1, 0), false, "damage on a dead handle is ignored")
	T.eq(deaths, 1, "no second death")
	T.throws(function()
		m:health(h)
	end, "reading a dead handle errors")
end)

T.test("kill fires onDeath; despawn does not", function()
	local m = newManager(4)
	local deaths = 0
	m.onDeath = function()
		deaths += 1
	end
	local a = m:spawn("BAT1", 0, 0, stats("BAT1")) :: number
	local b = m:spawn("BAT1", 0, 0, stats("BAT1")) :: number
	m:kill(a)
	m:despawn(b)
	T.eq(deaths, 1, "only kill notifies")
	T.eq(m.query.count(), 0, "both gone")
end)

T.test("boss death reports isBoss true and the Data xp", function()
	local m = newManager(4)
	local seenXp, seenBoss = -1, false
	m.onDeath = function(_h: number, _id: string, _x: number, _z: number, xp: number, isBoss: boolean)
		seenXp = xp
		seenBoss = isBoss
	end
	local h = m:spawn("BOSS_WEREWOLF", 0, 0, stats("BOSS_WEREWOLF")) :: number
	m:kill(h)
	T.eq(seenXp, 30, "BOSS_WEREWOLF xp 30 (enemies_waves.md §2)")
	T.eq(seenBoss, true, "isBoss")
end)

-- ---------------------------------------------------------------- contact
T.test("contact reports each touching enemy's power every step; far ones do not", function()
	local m = newManager(8)
	local hits: { [number]: number } = {}
	m.onContact = function(handle: number, power: number)
		hits[handle] = (hits[handle] or 0) + power
	end
	local reach = Tuning.enemyRadius + Tuning.playerRadius
	local near = m:spawn("ZOMBIE", reach - 0.1, 0, stats("ZOMBIE")) :: number
	local far = m:spawn("WEREWOLF", reach + 50, 0, stats("WEREWOLF")) :: number
	m:step(0, 0, 0)
	T.eq(hits[near], 10, "zombie power 10 reported once")
	T.eq(hits[far], nil, "far werewolf not touching")
	m:step(0, 0, 0)
	T.eq(hits[near], 20, "reported again next step")
end)

-- --------------------------------------------------------------- recycling
T.test("enemies beyond despawnRadius are moved onto the spawn ring, keeping hp", function()
	local m = newManager(4)
	local h = m:spawn("ZOMBIE", Tuning.despawnRadius + 30, 0, stats("ZOMBIE")) :: number
	m:damage(h, 3, 0)
	m:step(0.1, 0, 0)
	local x, z = m.query.position(h)
	T.eq(math.sqrt(x * x + z * z), Tuning.spawnRingRadius, "on the ring", 1e-9)
	T.eq(m:health(h), 7, "hp kept")
	T.eq(m.query.count(), 1, "same enemy")
	-- Around a moved player, the ring is centred on the player.
	m:step(0, 500, 500)
	x, z = m.query.position(h)
	T.eq(math.sqrt((x - 500) ^ 2 + (z - 500) ^ 2), Tuning.spawnRingRadius, "ring follows the player", 1e-9)
end)

-- ---------------------------------------------------------------- queries
T.test("closest / inRadius / inBox / random over a known layout", function()
	local m = newManager(16)
	local a = m:spawn("BAT1", 3, 0, stats("BAT1")) :: number
	local b = m:spawn("BAT1", 0, 5, stats("BAT1")) :: number
	local c = m:spawn("BAT1", -20, 0, stats("BAT1")) :: number
	local d = m:spawn("BAT1", 40, 40, stats("BAT1")) :: number
	m:step(0, 0, 0)
	local q = m.query
	T.eq(q.closest(0, 0, math.huge), a, "closest is a (3 studs)")
	T.eq(q.closest(0, 0, 2), nil, "nothing within 2")
	T.eq(q.closest(-19, 0, 5), c, "closest near c")
	T.eq(q.closest(39, 41, 3), d, "closest near d")
	T.eq(q.closest(1000, 1000, math.huge), d, "query point outside the grid still exact")

	local out: { number } = {}
	T.eq(q.inRadius(0, 0, 5, out), 2, "two within 5")
	local set: { [number]: boolean } = {}
	for i = 1, 2 do
		set[out[i]] = true
	end
	T.truthy(set[a] and set[b], "a and b")
	T.eq(q.inRadius(0, 0, 4.99, out), 1, "b is exactly at 5, excluded at 4.99")
	T.eq(out[1], a, "only a")
	T.eq(q.inRadius(0, 0, 100, out), 4, "all four within 100")
	T.eq(#out, 4, "out length matches")
	T.eq(q.inRadius(0, 0, 1, out), 0, "none within 1")
	T.eq(#out, 0, "out cleared")

	T.eq(q.inBox(0, 0, 3, 1, out), 1, "box 3x1 holds a only")
	T.eq(out[1], a, "a")
	T.eq(q.inBox(0, 0, 25, 6, out), 3, "box 25x6 holds a, b, c")
	T.eq(q.inBox(-20, 0, 0, 0, out), 1, "degenerate box on c")
	T.eq(out[1], c, "c")

	m:despawn(a)
	T.eq(q.closest(0, 0, math.huge), b, "dead a skipped before the rebuild")
	T.eq(q.inRadius(0, 0, 5, out), 1, "only b now")

	-- random: uniform over the set within range, never outside it.
	local rng = Rng.new(3)
	local counts: { [number]: number } = {}
	for _ = 1, 3000 do
		local h = q.random(0, 0, 25, rng) :: number
		counts[h] = (counts[h] or 0) + 1
	end
	T.eq(counts[a], nil, "dead a never picked")
	T.eq(counts[d], nil, "d out of range")
	T.truthy(counts[b] > 1200 and counts[c] > 1200, "b and c roughly even")
	T.eq(q.random(0, 0, 1, rng), nil, "nothing in range")
end)

T.test("SpatialHash alone: rebuild, cells and clamping", function()
	local cap = 6
	local x = { 0, 9, -9, 300, -300, 0 }
	local z = { 0, 9, -9, 300, -300, 0 }
	local alive = { true, true, true, true, true, false }
	local g = SpatialHash.new(8, 32, cap, x, z, alive)
	g:rebuild(0, 0)
	local out: { number } = {}
	T.eq(g:inRadius(0, 0, 1, out), 1, "only handle 1 at the origin (6 is dead)")
	T.eq(out[1], 1, "handle 1")
	T.eq(g:inRadius(0, 0, 13, out), 3, "1, 2, 3 within 13")
	T.eq(g:inRadius(0, 0, 1000, out), 5, "clamped far handles still found")
	T.eq(g:closest(250, 250, math.huge), 4, "far handle found through the edge cell")
	T.eq(g:countInRadius(0, 0, 13), 3, "count")
	T.eq(g:nthInRadius(0, 0, 13, 3) ~= nil, true, "3rd exists")
	T.eq(g:nthInRadius(0, 0, 13, 4), nil, "no 4th")
	T.throws(function()
		SpatialHash.new(0, 32, cap, x, z, alive)
	end, "zero cell size")
end)

-- ------------------------------------------------------------ performance
local CAP = Tuning.enemyCapacity
T.truthy(CAP >= 2048, "Tuning.enemyCapacity >= 2048")

local function spawnSpread(m: any, n: number, extent: number, seed: number)
	local r = Rng.new(seed)
	local line = stats("ZOMBIE")
	for _ = 1, n do
		local h = m:spawn("ZOMBIE", r:range(-extent, extent), r:range(-extent, extent), line)
		if h == nil then
			error("pool full")
		end
	end
end

T.test("PERF-02: step + queries allocate nothing in steady state at 2048 enemies", function()
	local m = newManager(CAP)
	spawnSpread(m, 2048, 60, 11)
	local dt = 1 / 60
	for _ = 1, 50 do
		m:step(dt, 0, 0)
	end
	local out = table.create(CAP, 0)
	local rng = Rng.new(5)
	-- Warm every query path once so any lazy growth happens before measuring.
	m.query.closest(0, 0, 10)
	m.query.inRadius(0, 0, 10, out)
	m.query.inBox(0, 0, 10, 10, out)
	m.query.random(0, 0, 10, rng)
	collectgarbage("collect")
	local before = collectgarbage("count")
	for _ = 1, 100 do
		m:step(dt, 0, 0)
	end
	for i = 1, 1000 do
		m.query.closest(i % 50, 0, 10)
		m.query.inRadius(0, i % 50, 10, out)
		m.query.inBox(i % 50, i % 50, 5, 5, out)
		m.query.random(0, 0, 20, rng)
	end
	local grown = collectgarbage("count") - before
	print(string.format("  steady-state growth: %.2f KB", grown))
	T.truthy(grown <= 8, string.format("grew %.2f KB (limit 8)", grown))
end)

T.test("PERF-03: 2048 enemies step in <= 16 ms average under the interpreter", function()
	local m = newManager(CAP)
	spawnSpread(m, 2048, 60, 13)
	m.onContact = function() end
	local dt = 1 / 60
	local t0 = os.clock()
	for _ = 1, 300 do
		m:step(dt, 0, 0)
	end
	local avg = (os.clock() - t0) / 300
	print(string.format("  EnemyManager.step avg: %.3f ms for 2048 enemies", avg * 1000))
	T.truthy(avg <= 0.016, string.format("avg %.4f s > 0.016", avg))
end)

T.test("PERF-05: queries touch only nearby cells (sub-linear in radius)", function()
	local m = newManager(CAP)
	-- 2048 enemies over a 400x400 area (+/- 200): the grid must cover it.
	T.truthy(Tuning.spatialGridHalfExtent >= 200, "grid covers the spread")
	spawnSpread(m, 2048, 200, 17)
	m:step(0, 0, 0)
	local g = m.grid
	g.candidatesVisited = 0
	m.query.closest(0, 0, 10)
	local small = g.candidatesVisited
	print(string.format("  closest(0,0,10) examined %d candidates", small))
	T.truthy(small < 100, string.format("closest(10) examined %d candidates", small))
	g.candidatesVisited = 0
	m.query.closest(0, 0, 400)
	T.truthy(g.candidatesVisited < 100, "closest with a huge maxDist still stops early")

	local out = table.create(CAP, 0)
	local t0 = os.clock()
	for i = 1, 1000 do
		m.query.inRadius(i % 100, 0, 10, out)
	end
	local tSmall = os.clock() - t0
	t0 = os.clock()
	for i = 1, 1000 do
		m.query.inRadius(i % 100, 0, 400, out)
	end
	local tLarge = os.clock() - t0
	print(string.format("  1000 inRadius: r=10 %.1f ms, r=400 %.1f ms", tSmall * 1000, tLarge * 1000))
	T.truthy(tSmall * 10 < tLarge, "radius 10 is under a tenth of radius 400")
end)

return T.finish()
