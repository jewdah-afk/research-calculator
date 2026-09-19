--!strict
--[[
	Headless tests for the server-weapons-b behaviours (King Bible, Garlic,
	Santa Water, Lightning Ring, Runetracer) -- the five targeting rules the
	weapons_a suite does not reach.

	Oracle: research/vs/weapons.md (base table, per-weapon targeting text,
	max-level totals, conflicts), src/shared/Data/Weapons for the numbers and
	Tuning for the engine constants. Every expected value below is a research
	literal, a Data lookup or a Tuning lookup, never a Sim/runner call used as
	its own oracle. The enemy world is the same tiny scripted EnemyQuery
	weapons_a uses, so positions and hits are fully controlled.
]]
local T = require("./_harness")
local Tuning = require("../src/shared/Tuning")
local Weapons = require("../src/shared/Data/Weapons")
local Rng = require("../src/shared/Sim/Rng")
local Stats = require("../src/shared/Sim/Stats")
local WeaponRunner = require("../src/server/WeaponRunner")
local KingBible = require("../src/server/Weapons/KingBible")
local Garlic = require("../src/server/Weapons/Garlic")
local SantaWater = require("../src/server/Weapons/SantaWater")
local LightningRing = require("../src/server/Weapons/LightningRing")
local Runetracer = require("../src/server/Weapons/Runetracer")

type Rng = WeaponRunner.Rng
type EnemyQuery = WeaponRunner.EnemyQuery
type WeaponBehavior = WeaponRunner.WeaponBehavior
type VisualSpec = WeaponRunner.VisualSpec

local BEHAVIOURS: { WeaponBehavior } = { KingBible, Garlic, SantaWater, LightningRing, Runetracer }

-- ------------------------------------------------------------ fake world
type Hit = { enemy: number, amount: number, knockback: number, weaponId: string, time: number }
type World = {
	query: EnemyQuery,
	x: { number },
	z: { number },
	hp: { number },
	alive: { boolean },
	hits: { Hit },
	now: number,
	add: (self: World, x: number, z: number, hp: number) -> number,
	hitsOn: (self: World, enemy: number) -> number,
	-- Marker projectiles (King Bible bibles, Runetracer tracers) carry damage
	-- 0 and let the pool resolve a harmless hit; the gameplay hit is the one
	-- the behaviour itself rolls, so these helpers count damaging hits only.
	realHitsOn: (self: World, enemy: number) -> number,
	realHits: (self: World) -> { Hit },
	damage: (enemy: number, amount: number, knockback: number, weaponId: string) -> boolean,
}

local function newWorld(): World
	local w = {} :: World
	w.x, w.z, w.hp, w.alive, w.hits = {}, {}, {}, {}, {}
	w.now = 0
	function w.add(self: World, x: number, z: number, hp: number): number
		local h = #self.x + 1
		self.x[h], self.z[h], self.hp[h], self.alive[h] = x, z, hp, true
		return h
	end
	function w.hitsOn(self: World, enemy: number): number
		local n = 0
		for _, hit in self.hits do
			if hit.enemy == enemy then
				n += 1
			end
		end
		return n
	end
	function w.realHitsOn(self: World, enemy: number): number
		local n = 0
		for _, hit in self.hits do
			if hit.enemy == enemy and hit.amount > 0 then
				n += 1
			end
		end
		return n
	end
	function w.realHits(self: World): { Hit }
		local out = {}
		for _, hit in self.hits do
			if hit.amount > 0 then
				table.insert(out, hit)
			end
		end
		return out
	end
	w.damage = function(enemy: number, amount: number, knockback: number, weaponId: string): boolean
		if not w.alive[enemy] then
			return false
		end
		table.insert(
			w.hits,
			{ enemy = enemy, amount = amount, knockback = knockback, weaponId = weaponId, time = w.now }
		)
		w.hp[enemy] -= amount
		if w.hp[enemy] <= 0 then
			w.alive[enemy] = false
			return true
		end
		return false
	end
	local function dist2(h: number, x: number, z: number): number
		local dx, dz = w.x[h] - x, w.z[h] - z
		return dx * dx + dz * dz
	end
	w.query = {
		count = function(): number
			local n = 0
			for _, a in w.alive do
				if a then
					n += 1
				end
			end
			return n
		end,
		isAlive = function(h: number): boolean
			return w.alive[h] == true
		end,
		position = function(h: number): (number, number)
			return w.x[h], w.z[h]
		end,
		closest = function(x: number, z: number, maxDist: number): number?
			local best, bestD2 = nil, maxDist * maxDist
			for h, a in w.alive do
				if a then
					local d2 = dist2(h, x, z)
					if d2 <= bestD2 then
						best, bestD2 = h, d2
					end
				end
			end
			return best
		end,
		random = function(x: number, z: number, maxDist: number, rng: Rng): number?
			local list = {}
			for h, a in w.alive do
				if a and dist2(h, x, z) <= maxDist * maxDist then
					table.insert(list, h)
				end
			end
			if #list == 0 then
				return nil
			end
			return rng:pick(list)
		end,
		inRadius = function(x: number, z: number, radius: number, out: { number }): number
			local n = 0
			for h, a in w.alive do
				if a and dist2(h, x, z) <= radius * radius then
					n += 1
					out[n] = h
				end
			end
			return n
		end,
		inBox = function(x: number, z: number, halfW: number, halfD: number, out: { number }): number
			local n = 0
			for h, a in w.alive do
				if a and math.abs(w.x[h] - x) <= halfW and math.abs(w.z[h] - z) <= halfD then
					n += 1
					out[n] = h
				end
			end
			return n
		end,
	}
	return w
end

local function frameAt(time: number, fx: number?, fz: number?)
	return { time = time, playerX = 0, playerZ = 0, facingX = fx or 1, facingZ = fz or 0, moveX = 0, moveZ = 0 }
end

-- A runner over `world` holding `weapons` (id -> level) for `characterId` at
-- Lv1 with `passives`. Also returns the spawn log and the visual log.
local function newRunner(
	world: World,
	weapons: { [string]: number },
	characterId: string?,
	passives: { [string]: number }?
)
	local order = {}
	for id in weapons do
		table.insert(order, id)
	end
	table.sort(order)
	local visuals: { VisualSpec } = {}
	local runner = WeaponRunner.new({
		query = world.query,
		damage = world.damage,
		rng = Rng.new(11),
		visual = function(spec: VisualSpec)
			table.insert(visuals, {
				kind = spec.kind,
				x = spec.x,
				z = spec.z,
				radius = spec.radius,
				duration = spec.duration,
				weaponId = spec.weaponId,
			})
		end,
	})
	runner:registerAll(BEHAVIOURS)
	local spawns: { { handle: number, weaponId: string } } = {}
	runner.onProjectileSpawn = function(h: number, weaponId: string)
		table.insert(spawns, { handle = h, weaponId = weaponId })
	end
	local player = {
		stats = Stats.effective(characterId or "imelda", 1, passives or {}),
		weapons = weapons,
		weaponOrder = order,
	}
	runner:onStatsChanged(player)
	return runner, spawns, visuals, player
end

-- Steps `runner` from t0 in `dt` increments until t1 (inclusive of t0).
local function run(world: World, runner: WeaponRunner.WeaponRunner, t0: number, t1: number, dt: number)
	local t = t0
	while t <= t1 + 1e-9 do
		world.now = t
		runner:step(dt, frameAt(t))
		t += dt
	end
end

local function projPos(runner: WeaponRunner.WeaponRunner, h: number): (number, number)
	local s = runner :: any
	return s.x[h], s.z[h]
end

local function visualsOfKind(visuals: { VisualSpec }, kind: string): { VisualSpec }
	local out = {}
	for _, v in visuals do
		if v.kind == kind then
			table.insert(out, v)
		end
	end
	return out
end

-- ---------------------------------------------------------- shape / ids
T.test("WPN-B: the five behaviours export id/create/onStatsChanged/tick and their id is a Data weapon", function()
	local expected = { king_bible = true, garlic = true, santa_water = true, lightning_ring = true, runetracer = true }
	for _, b in BEHAVIOURS do
		T.truthy(Weapons.data[b.id] ~= nil, b.id .. " in Weapons.data")
		T.truthy(expected[b.id], b.id .. " is a server-weapons-b id")
		T.eq(type(b.create), "function", b.id .. ".create")
		T.eq(type(b.onStatsChanged), "function", b.id .. ".onStatsChanged")
		T.eq(type(b.tick), "function", b.id .. ".tick")
	end
end)

-- ------------------------------------------------------------ king bible
T.test(
	"WPN-08: bibles orbit the player clockwise at Area radius, for Duration, on a cooldown+duration cycle",
	function()
		local world = newWorld()
		local runner, spawns = newRunner(world, { king_bible = 1 }, "imelda")
		local rt = runner.runtimeById.king_bible
		-- weapons.md base table: King Bible amount 1, duration 3, cooldown 3.
		T.eq(rt.stats.amount, 1)
		T.eq(rt.stats.duration, 3)
		T.eq(rt.stats.cooldown, 3)
		-- weapons.md King Bible: "the effective cycle = cooldown + duration
		-- (3.0 + 3.0 = 6.0s at Lv1)".
		T.eq(runner:cycleOf(rt), 6)

		runner:step(0.01, frameAt(0))
		T.eq(#spawns, 1, "one bible at Lv1")
		local h = spawns[1].handle
		-- "Area = orbit radius (capped)": area 1 * Tuning.areaScale, under the cap.
		local radius = math.min(1 * Tuning.areaScale, Tuning.kingBible.orbitRadiusCap)
		local x, z = projPos(runner, h)
		T.eq(math.sqrt(x * x + z * z), radius, "orbit radius", 1e-6)
		-- "Bibles orbit the player CLOCKWISE": the angle grows with (cos, sin), so
		-- just after the start the bible is right-and-down of the player.
		T.truthy(x > 0 and z > 0, "clockwise from angle 0 (screen-up is -Z)")
		-- "Speed = rotation rate": a quarter turn takes 0.25 / revolutionsPerSecond.
		local quarter = 0.25 / Tuning.kingBible.revolutionsPerSecond
		run(world, runner, 0.01, quarter, 0.01)
		local qx, qz = projPos(runner, h)
		T.eq(math.sqrt(qx * qx + qz * qz), radius, "still on the circle", 1e-6)
		T.eq(math.atan2(qz, qx), math.pi / 2, "a quarter turn on", 0.05)

		-- The orbit lasts the Duration, then the weapon goes on cooldown.
		run(world, runner, quarter + 0.01, 2.99, 0.01)
		T.eq(runner:projectileCount(), 1, "still orbiting just under 3 s")
		run(world, runner, 3.0, 3.1, 0.01)
		T.eq(runner:projectileCount(), 0, "orbit ended at Duration 3")
		run(world, runner, 3.11, 5.99, 0.01)
		T.eq(#spawns, 1, "no new orbit before cooldown + duration")
		run(world, runner, 6.0, 6.05, 0.01)
		T.eq(#spawns, 2, "next orbit at the 6 s cycle")
	end
)

T.test(
	"WPN-08: Amount spaces extra bibles evenly; an enemy on the circle is re-hit only after the 1.7 s delay",
	function()
		-- weapons.md King Bible Lv2 and Lv5 "+1 Amount" -> 3 bibles at Lv5.
		local world = newWorld()
		local runner, spawns = newRunner(world, { king_bible = 5 }, "imelda")
		T.eq(runner.runtimeById.king_bible.stats.amount, 3)
		runner:step(0.01, frameAt(0))
		T.eq(#spawns, 3)
		local angles = {}
		for i = 1, 3 do
			local x, z = projPos(runner, spawns[i].handle)
			angles[i] = math.atan2(z, x)
		end
		local spacing = 2 * math.pi / 3
		T.eq((angles[2] - angles[1]) % (2 * math.pi), spacing, "evenly spaced", 1e-6)
		T.eq((angles[3] - angles[2]) % (2 * math.pi), spacing, "evenly spaced", 1e-6)

		-- Lv1, one bible, one enemy parked on the orbit circle. The bible passes
		-- it once per revolution (1 / 0.75 = 1.33 s), but weapons.md gives a
		-- "Per-enemy hitbox delay 1.7s", so the second pass is skipped.
		local world2 = newWorld()
		local enemy = world2:add(math.min(1 * Tuning.areaScale, Tuning.kingBible.orbitRadiusCap), 0, 1e9)
		local runner2 = newRunner(world2, { king_bible = 1 }, "imelda")
		T.eq(runner2.runtimeById.king_bible.stats.hitboxDelay, 1.7, "weapons.md base table: hitbox delay 1.7")
		run(world2, runner2, 0, 2.99, 0.01)
		local hits = world2:realHits()
		T.eq(world2:realHitsOn(enemy), 2, "passes at ~0, ~1.33 (blocked) and ~2.67")
		T.truthy(hits[2].time - hits[1].time >= 1.7, "hits at least 1.7 s apart")
		-- weapons.md King Bible: 10 damage, crit absent -> always the base roll.
		T.eq(hits[1].amount, Weapons.data.king_bible.baseDamage)
		T.eq(hits[1].weaponId, "king_bible")
	end
)

-- ---------------------------------------------------------------- garlic
T.test("WPN-09: the aura damages everything inside Area studs of the player and nothing outside", function()
	local world = newWorld()
	local radius = 1 * Tuning.areaScale -- Garlic base area 1 (weapons.md base table)
	local inside = world:add(radius - 1, 0, 1e9)
	local outside = world:add(radius + 1, 0, 1e9)
	local runner, spawns, visuals = newRunner(world, { garlic = 1 }, "imelda")
	runner:step(0.01, frameAt(0))
	T.eq(world:hitsOn(inside), 1, "hit on entry")
	T.eq(world:hitsOn(outside), 0, "outside the aura")
	T.eq(#spawns, 0, "the aura spawns no projectile")
	-- weapons.md Garlic: 5 damage, knockback 0 (shipped), crit absent.
	T.eq(world.hits[1].amount, Weapons.data.garlic.baseDamage)
	T.eq(world.hits[1].knockback, 0)
	T.eq(world.hits[1].weaponId, "garlic")
	local pulses = visualsOfKind(visuals, "garlic_aura")
	T.eq(#pulses, 1, "one aura pulse per cooldown")
	T.eq(pulses[1].radius, radius)
end)

T.test("WPN-09: the cooldown doubles as the per-enemy hitbox delay, and leaving the aura does not reset it", function()
	local world = newWorld()
	local enemy = world:add(1, 0, 1e9)
	local runner = newRunner(world, { garlic = 1 }, "imelda")
	-- weapons.md base table: Garlic cooldown 1.3.
	T.eq(runner.runtimeById.garlic.stats.cooldown, 1.3)
	run(world, runner, 0, 1.29, 0.01)
	T.eq(world:hitsOn(enemy), 1, "one hit per cooldown while standing in it")
	run(world, runner, 1.3, 2.59, 0.01)
	T.eq(world:hitsOn(enemy), 2)
	run(world, runner, 2.6, 2.99, 0.01)
	T.eq(world:hitsOn(enemy), 3)

	-- weapons.md Garlic: "an enemy is hit on entry, then not again until the
	-- cooldown elapses EVEN IF IT LEAVES AND RE-ENTERS."
	local world2 = newWorld()
	local e = world2:add(1, 0, 1e9)
	local runner2 = newRunner(world2, { garlic = 1 }, "imelda")
	runner2:step(0.01, frameAt(0))
	T.eq(world2:hitsOn(e), 1)
	world2.x[e] = 100 -- steps out
	run(world2, runner2, 0.01, 0.5, 0.01)
	world2.x[e] = 1 -- steps back in, well before the 1.3 s window is up
	run(world2, runner2, 0.51, 1.29, 0.01)
	T.eq(world2:hitsOn(e), 1, "re-entering does not re-trigger the hit")
	run(world2, runner2, 1.3, 1.35, 0.01)
	T.eq(world2:hitsOn(e), 2, "hit again once its own window elapsed")
end)

-- ---------------------------------------------------------- santa water
T.test("WPN-10: below Amount 4 a bottle aims at the CLOSEST enemy and its zone opens after the fall", function()
	local world = newWorld()
	local near = world:add(20, 0, 1e9)
	local far = world:add(40, 0, 1e9)
	local runner, _, visuals = newRunner(world, { santa_water = 1 }, "imelda")
	local rt = runner.runtimeById.santa_water
	-- weapons.md base table (shipped, Conflicts L279): amount 1, duration 2,
	-- cooldown 4.5; the circle pattern needs Amount 4+.
	T.eq(rt.stats.amount, 1)
	T.eq(rt.stats.cooldown, 4.5)
	T.truthy(rt.stats.amount < Tuning.santaWater.circlePatternMinAmount)
	runner:step(0.01, frameAt(0))
	local drops = visualsOfKind(visuals, "santa_water_drop")
	T.eq(#drops, 1, "one bottle")
	T.eq(drops[1].x, 20, "aimed at the closest enemy")
	T.eq(drops[1].z, 0)
	T.eq(world:hitsOn(near), 0, "the zone has not opened yet")
	run(world, runner, 0.01, Tuning.santaWater.fallTime - 0.02, 0.01)
	T.eq(world:hitsOn(near), 0, "still falling")
	run(world, runner, Tuning.santaWater.fallTime, Tuning.santaWater.fallTime + 0.05, 0.01)
	T.eq(world:hitsOn(near), 1, "the zone opened where the bottle landed")
	T.eq(world:hitsOn(far), 0, "far outside the zone")
	-- weapons.md Santa Water: 10 damage, knockback 0 (shipped), crit absent.
	T.eq(world.hits[1].amount, Weapons.data.santa_water.baseDamage)
	T.eq(world.hits[1].weaponId, "santa_water")
	-- "stationary damaging ground zones lasting the weapon's Duration", with a
	-- "Per-enemy hitbox delay 0.5s": duration 2 -> hits at +0, +0.5 .. +1.5.
	T.eq(rt.stats.hitboxDelay, 0.5)
	run(world, runner, Tuning.santaWater.fallTime + 0.06, Tuning.santaWater.fallTime + 1.99, 0.01)
	T.eq(world:hitsOn(near), 4, "one hit per 0.5 s over the 2 s zone")
end)

T.test("WPN-10: at Amount 4+ the bottles land on a clockwise circle around the player", function()
	local world = newWorld()
	-- weapons.md Santa Water Lv2 / Lv4 / Lv6 "+1 Amount" -> 4 at Lv6.
	local r = Tuning.santaWater.ringRadius
	local marks = {}
	for i = 1, 4 do
		local a = (i - 1) * (2 * math.pi / 4)
		marks[i] = world:add(r * math.cos(a), r * math.sin(a), 1e9)
	end
	local atPlayer = world:add(0, 0, 1e9)
	local runner, _, visuals = newRunner(world, { santa_water = 6 }, "imelda")
	local rt = runner.runtimeById.santa_water
	T.eq(rt.stats.amount, 4)
	T.truthy(rt.stats.amount >= Tuning.santaWater.circlePatternMinAmount)
	local zoneRadius = rt.stats.area * Tuning.areaScale
	T.truthy(zoneRadius < r, "the zones do not reach the player, so the circle is what is under test")
	-- Bottles of one cast are spaced by projectileInterval 0.3 (base table).
	T.eq(rt.stats.projectileInterval, 0.3)
	run(world, runner, 0, 0.91 + Tuning.santaWater.fallTime, 0.01)
	local drops = visualsOfKind(visuals, "santa_water_drop")
	T.eq(#drops, 4, "four bottles, 0.3 s apart")
	for i = 1, 4 do
		local a = (i - 1) * (2 * math.pi / 4)
		T.eq(drops[i].x, r * math.cos(a), "bottle " .. i .. " x on the circle", 1e-6)
		T.eq(drops[i].z, r * math.sin(a), "bottle " .. i .. " z (clockwise: angle grows with sin)", 1e-6)
	end
	for i = 1, 4 do
		T.truthy(world:hitsOn(marks[i]) >= 1, "an enemy on landing point " .. i .. " is hit")
	end
	T.eq(world:hitsOn(atPlayer), 0, "the player's own spot is not a landing zone at Amount 4+")
end)

-- -------------------------------------------------------- lightning ring
T.test("WPN-11: strikes fall on RANDOM enemies within the on-screen radius, never outside it", function()
	local world = newWorld()
	local onScreen = world:add(20, 0, 1e9)
	local offScreen = world:add(Tuning.lightningRing.targetRadius + 10, 0, 1e9)
	local runner, spawns, visuals = newRunner(world, { lightning_ring = 1 }, "imelda")
	local rt = runner.runtimeById.lightning_ring
	-- weapons.md base table: Lightning Ring amount 2, cooldown 4.5, interval 0.05.
	T.eq(rt.stats.amount, 2)
	T.eq(rt.stats.cooldown, 4.5)
	T.eq(rt.stats.projectileInterval, 0.05)
	run(world, runner, 0, 0.1, 0.01)
	local strikes = visualsOfKind(visuals, "lightning_ring_strike")
	T.eq(#strikes, 2, "two strikes per cast, 0.05 s apart")
	T.eq(#spawns, 0, "strikes are instantaneous: nothing enters the projectile pool")
	for _, s in strikes do
		T.eq(s.x, 20, "only the on-screen enemy could be picked")
		T.eq(s.z, 0)
	end
	T.eq(world:hitsOn(onScreen), 2)
	T.eq(world:hitsOn(offScreen), 0, "past Tuning.lightningRing.targetRadius: never struck")
	-- weapons.md Lightning Ring: 15 damage, crit absent -> always the base roll.
	T.eq(world.hits[1].amount, Weapons.data.lightning_ring.baseDamage)
	T.eq(world.hits[1].weaponId, "lightning_ring")
	run(world, runner, 0.11, 4.49, 0.01)
	T.eq(#visualsOfKind(visuals, "lightning_ring_strike"), 2, "no strike before the cooldown")
	run(world, runner, 4.5, 4.6, 0.01)
	T.eq(#visualsOfKind(visuals, "lightning_ring_strike"), 4, "next cast at cooldown 4.5")
end)

T.test("WPN-11: damage is the ground-impact circle scaled by Area, not the single target", function()
	local world = newWorld()
	local radius = 1 * Tuning.areaScale -- Lightning Ring base area 1 (weapons.md)
	local target = world:add(20, 0, 1e9)
	local beside = world:add(20 + radius - 1, 0, 1e9) -- inside the impact circle
	world:add(20, 30, 1e9) -- on screen, but its own circle covers nobody else
	local runner, _, visuals = newRunner(world, { lightning_ring = 1 }, "imelda")
	run(world, runner, 0, 0.1, 0.01)
	local strikes = visualsOfKind(visuals, "lightning_ring_strike")
	T.eq(#strikes, 2)
	T.eq(strikes[1].radius, radius, "impact circle = Area * Tuning.areaScale")
	-- "damage comes from the circular ground-impact hitbox": every enemy
	-- inside a strike's circle is hit once by it, and nobody outside is. Which
	-- enemy each strike picked is the RNG's business, so the expectation is
	-- read off the strike positions the behaviour reported.
	local expected = 0
	local perEnemy: { number } = {}
	for _, st in strikes do
		for e = 1, #world.x do
			local dx, dz = world.x[e] - st.x, world.z[e] - st.z
			if dx * dx + dz * dz <= radius * radius then
				expected += 1
				perEnemy[e] = (perEnemy[e] or 0) + 1
			end
		end
	end
	T.eq(#world.hits, expected, "one hit per enemy per covering strike, and none outside")
	for e = 1, #world.x do
		T.eq(world:hitsOn(e), perEnemy[e] or 0, "enemy " .. e .. " hit exactly by the circles covering it")
	end
	T.truthy(world:hitsOn(target) + world:hitsOn(beside) >= 2, "the cluster was struck")
	-- weapons.md Lightning Ring Lv3 "+100% Area" -> a wider circle at Lv3.
	local runner3 = newRunner(newWorld(), { lightning_ring = 3 }, "imelda")
	T.eq(runner3.runtimeById.lightning_ring.stats.area, 2)
end)

-- ------------------------------------------------------------ runetracer
T.test("WPN-06: the tracer flies straight at Speed, bounces off the screen box and expires at its Duration", function()
	local world = newWorld()
	local runner, spawns = newRunner(world, { runetracer = 1 }, "imelda")
	local rt = runner.runtimeById.runetracer
	-- weapons.md base table: Runetracer duration 2.25, cooldown 3, speed 1.
	T.eq(rt.stats.duration, 2.25)
	T.eq(rt.stats.cooldown, 3)
	runner:step(0.01, frameAt(0))
	T.eq(#spawns, 1, "one tracer at Lv1 (amount 1)")
	local h = spawns[1].handle
	local s = runner :: any
	T.eq(s.pierce[h], -1, "weapons.md Runetracer: infinite pierce")
	local speed = rt.stats.speed * Tuning.projectileSpeedScale
	T.eq(math.sqrt(s.vx[h] * s.vx[h] + s.vz[h] * s.vz[h]), speed, "launched at Speed * scale", 1e-6)

	-- "BOUNCES off screen edges": the port's stand-in is the player-centred
	-- Tuning.projectileBounce box, so the tracer never leaves it.
	local halfW = Tuning.projectileBounce.halfWidth
	local halfD = Tuning.projectileBounce.halfDepth
	local bounced = false
	local t = 0.01
	while t <= 2.24 do
		world.now = t
		runner:step(0.01, frameAt(t))
		local x, z = projPos(runner, h)
		T.truthy(math.abs(x) <= halfW + 1e-6, "inside the box along X: " .. tostring(x))
		T.truthy(math.abs(z) <= halfD + 1e-6, "inside the box along Z: " .. tostring(z))
		if math.abs(math.abs(x) - halfW) < 1 or math.abs(math.abs(z) - halfD) < 1 then
			bounced = true
		end
		t += 0.01
	end
	T.truthy(bounced, "reached a wall and turned back inside the box")
	T.eq(s.alive[h], true, "alive just under its 2.25 s duration")
	run(world, runner, 2.25, 2.3, 0.01)
	T.eq(s.alive[h], false, "expired at Duration 2.25")
end)

T.test("WPN-06: infinite pierce is gated by the 0.5 s per-enemy hitbox delay", function()
	local world = newWorld()
	-- An enemy sitting on the player: the tracer launches on top of it and
	-- comes back over it as it bounces, so only the delay limits the hits.
	local enemy = world:add(0, 0, 1e9)
	local runner = newRunner(world, { runetracer = 1 }, "imelda")
	local rt = runner.runtimeById.runetracer
	T.eq(rt.stats.hitboxDelay, 0.5, "weapons.md base table: hitbox delay 0.5")
	run(world, runner, 0, 2.24, 0.01)
	local hits = world:realHits()
	local n = world:realHitsOn(enemy)
	T.truthy(n >= 1, "the tracer hit it at least once")
	T.truthy(
		n <= math.ceil(rt.stats.duration / rt.stats.hitboxDelay),
		"no more hits than the delay allows: " .. tostring(n)
	)
	for i = 2, #hits do
		T.truthy(hits[i].time - hits[i - 1].time >= 0.5 - 1e-9, "consecutive hits at least 0.5 s apart")
	end
	-- weapons.md Runetracer: 10 damage, crit absent -> always the base roll.
	T.eq(hits[1].amount, Weapons.data.runetracer.baseDamage)
	T.eq(hits[1].weaponId, "runetracer")
end)

return T.finish()
