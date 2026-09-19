--!strict
--[[
	Headless tests for server/WeaponRunner and the server-weapons-a
	behaviours (Whip, MagicWand, Knife, Axe, Cross, FireWand).

	Oracle: research/vs/weapons.md (base table, per-weapon targeting text,
	max-level totals, conflicts), src/shared/Data/Weapons for the numbers and
	Tuning for the engine constants. Every expected value below is a research
	literal, a Data lookup or a Tuning lookup, never a Sim/runner call used
	as its own oracle. The enemy world is a tiny hand-rolled EnemyQuery so
	positions and hits are fully controlled.
]]
local T = require("./_harness")
local Tuning = require("../src/shared/Tuning")
local Weapons = require("../src/shared/Data/Weapons")
local Rng = require("../src/shared/Sim/Rng")
local Stats = require("../src/shared/Sim/Stats")
local WeaponRunner = require("../src/server/WeaponRunner")
local Whip = require("../src/server/Weapons/Whip")
local MagicWand = require("../src/server/Weapons/MagicWand")
local Knife = require("../src/server/Weapons/Knife")
local Axe = require("../src/server/Weapons/Axe")
local Cross = require("../src/server/Weapons/Cross")
local FireWand = require("../src/server/Weapons/FireWand")

type Rng = WeaponRunner.Rng
type EnemyQuery = WeaponRunner.EnemyQuery
type WeaponBehavior = WeaponRunner.WeaponBehavior
type WeaponRuntime = WeaponRunner.WeaponRuntime
type WeaponContext = WeaponRunner.WeaponContext
type ProjectileSpec = WeaponRunner.ProjectileSpec

local BEHAVIOURS: { WeaponBehavior } = { Whip, MagicWand, Knife, Axe, Cross, FireWand }

-- ------------------------------------------------------------ fake world
type Hit = { enemy: number, amount: number, knockback: number, weaponId: string }
type World = {
	query: EnemyQuery,
	x: { number },
	z: { number },
	hp: { number },
	alive: { boolean },
	hits: { Hit },
	add: (self: World, x: number, z: number, hp: number) -> number,
	hitsOn: (self: World, enemy: number) -> number,
	damage: (enemy: number, amount: number, knockback: number, weaponId: string) -> boolean,
}

local function newWorld(): World
	local w = {} :: World
	w.x, w.z, w.hp, w.alive, w.hits = {}, {}, {}, {}, {}
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
	w.damage = function(enemy: number, amount: number, knockback: number, weaponId: string): boolean
		if not w.alive[enemy] then
			return false
		end
		table.insert(w.hits, { enemy = enemy, amount = amount, knockback = knockback, weaponId = weaponId })
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

-- A runner over `world` holding `weapons` (id -> level) for `characterId`
-- at Lv1 with `passives`. Also returns a spawn log.
local function newRunner(
	world: World,
	weapons: { [string]: number },
	characterId: string?,
	passives: { [string]: number }?,
	capacity: number?
)
	local order = {}
	for id in weapons do
		table.insert(order, id)
	end
	table.sort(order)
	local runner = WeaponRunner.new({
		query = world.query,
		damage = world.damage,
		rng = Rng.new(11),
		capacity = capacity,
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
	return runner, spawns, player
end

-- Steps `runner` from t0 in `dt` increments until t1 (inclusive of t0).
local function run(runner: WeaponRunner.WeaponRunner, t0: number, t1: number, dt: number, fx: number?, fz: number?)
	local t = t0
	while t <= t1 + 1e-9 do
		runner:step(dt, frameAt(t, fx, fz))
		t += dt
	end
end

local function projVelocity(runner: WeaponRunner.WeaponRunner, h: number): (number, number)
	local s = runner :: any
	return s.vx[h], s.vz[h]
end

-- ---------------------------------------------------------- WPN-01 shape
T.test("WPN-01: the six behaviours export id/create/onStatsChanged/tick and their id is a Data weapon", function()
	local expected = { whip = true, magic_wand = true, knife = true, axe = true, cross = true, fire_wand = true }
	for _, b in BEHAVIOURS do
		T.truthy(Weapons.data[b.id] ~= nil, b.id .. " in Weapons.data")
		T.truthy(expected[b.id], b.id .. " is a server-weapons-a id")
		T.eq(type(b.create), "function", b.id .. ".create")
		T.eq(type(b.onStatsChanged), "function", b.id .. ".onStatsChanged")
		T.eq(type(b.tick), "function", b.id .. ".tick")
	end
end)

T.test("WPN-01: registering an id that is not a Data weapon errors", function()
	local runner = WeaponRunner.new({ query = newWorld().query, damage = newWorld().damage, rng = Rng.new(1) })
	T.throws(function()
		runner:register({ id = "sword", create = Whip.create, onStatsChanged = Whip.onStatsChanged, tick = Whip.tick })
	end)
end)

-- ------------------------------------------------------- runtime / stats
T.test("WPN-13: rt.stats is the Data base row with the player's StatBlock applied", function()
	local world = newWorld()
	local runner = newRunner(world, { whip = 1 }, "imelda")
	local rt = runner.runtimeById.whip
	T.truthy(rt ~= nil, "whip runtime exists")
	T.eq(rt.level, 1)
	-- weapons.md base table: Whip 10 dmg, cooldown 1.35, 20% / 2x crit, pool 30, interval 0.1.
	T.eq(rt.stats.damage, Weapons.data.whip.baseDamage)
	T.eq(rt.stats.cooldown, Weapons.data.whip.cooldown)
	T.eq(rt.stats.critChance, 0.2)
	T.eq(rt.stats.critMultiplier, 2)
	T.eq(rt.stats.poolLimit, 30)
	T.eq(rt.stats.projectileInterval, 0.1)
	T.eq(rt.cooldownRemaining, 0, "fires on the first tick")
end)

T.test(
	"WPN-13: onStatsChanged re-derives stats (Empty Tome Lv5 cooldown 0.6 -> whip 0.81) and clamps the wait",
	function()
		local world = newWorld()
		local runner, _, player = newRunner(world, { whip = 1 }, "imelda")
		local rt = runner.runtimeById.whip
		rt.cooldownRemaining = 1.35
		-- passives_evolutions.md §1: Empty Tome -8% cooldown per level -> 0.6 at Lv5.
		player.stats = Stats.effective("imelda", 1, { empty_tome = 5 })
		runner:onStatsChanged(player)
		T.eq(rt.stats.cooldown, 1.35 * 0.6, "whip cooldown x0.6")
		T.eq(rt.cooldownRemaining, 1.35 * 0.6, "remaining wait clamped to the new cycle")
		-- Level-up to Lv2: weapons.md Whip Lv2 "+1 Amount".
		player.weapons.whip = 2
		runner:onStatsChanged(player)
		T.eq(rt.level, 2)
		T.eq(rt.stats.amount, 2)
	end
)

T.test("WPN-13: a newly acquired weapon gets a runtime; the old one keeps its state", function()
	local world = newWorld()
	local runner, _, player = newRunner(world, { whip = 1 }, "imelda")
	local whipRt = runner.runtimeById.whip
	player.weapons.knife = 1
	table.insert(player.weaponOrder, "knife")
	runner:onStatsChanged(player)
	T.eq(#runner.runtimes, 2)
	T.eq(runner.runtimes[1], whipRt, "acquisition order kept")
	T.eq(runner.runtimes[2].weaponId, "knife")
end)

T.test("a weapon with no registered behaviour errors on acquisition", function()
	local world = newWorld()
	local runner = WeaponRunner.new({ query = world.query, damage = world.damage, rng = Rng.new(1) })
	T.throws(function()
		runner:onStatsChanged({ stats = Stats.base("imelda"), weapons = { garlic = 1 }, weaponOrder = { "garlic" } })
	end)
end)

-- --------------------------------------------------------------- cadence
T.test("WPN-01: knife (cooldown 1.0, amount 1) fires at t=0 and again exactly one cooldown later", function()
	local world = newWorld()
	local runner, spawns = newRunner(world, { knife = 1 }, "imelda")
	-- weapons.md base table: Knife cooldown 1.
	T.eq(Weapons.data.knife.cooldown, 1)
	runner:step(0.1, frameAt(0))
	T.eq(#spawns, 1, "first knife at t=0")
	run(runner, 0.1, 0.9, 0.1)
	T.eq(#spawns, 1, "none before the cooldown elapses")
	runner:step(0.1, frameAt(1.0))
	T.eq(#spawns, 2, "second knife when 1.0 s has elapsed")
	run(runner, 1.1, 1.9, 0.1)
	T.eq(#spawns, 2)
	runner:step(0.1, frameAt(2.0))
	T.eq(#spawns, 3, "cadence does not drift")
end)

T.test(
	"WPN-01: a behaviour that re-arms the cooldown itself is left alone; King Bible cycle = cooldown + duration",
	function()
		local world = newWorld()
		local runner = WeaponRunner.new({ query = world.query, damage = world.damage, rng = Rng.new(1) })
		local fires = 0
		local selfArmed: WeaponBehavior = {
			id = "king_bible",
			create = function(_rt: WeaponRuntime) end,
			onStatsChanged = function(_rt: WeaponRuntime) end,
			tick = function(rt: WeaponRuntime, _ctx: WeaponContext)
				if rt.state.fire then
					fires += 1
				end
			end,
		}
		runner:register(selfArmed)
		runner:onStatsChanged({
			stats = Stats.base("imelda"),
			weapons = { king_bible = 1 },
			weaponOrder = { "king_bible" },
		})
		local rt = runner.runtimeById.king_bible
		runner:step(0.1, frameAt(0))
		T.eq(fires, 1)
		-- weapons.md King Bible: "effective cycle = cooldown + duration (3.0 + 3.0 = 6.0s at Lv1)".
		T.eq(runner:cycleOf(rt), 6)
		T.eq(rt.cooldownRemaining, 6 - 0.1, "re-armed by the 6 s cycle minus this tick's overshoot")
		-- knife has no intervalDependsOnDuration: cycle is the bare cooldown.
		runner:register(Knife)
		runner:onStatsChanged({
			stats = Stats.base("imelda"),
			weapons = { king_bible = 1, knife = 1 },
			weaponOrder = { "king_bible", "knife" },
		})
		T.eq(runner:cycleOf(runner.runtimeById.knife), 1)
	end
)

-- ----------------------------------------------------------------- knife
T.test("WPN-04: knives fly along facing at speed * projectileSpeedScale; Lv8 fires 6 spaced by 0.04 s", function()
	local world = newWorld()
	local runner, spawns = newRunner(world, { knife = 8 }, "imelda")
	local scale = Tuning.projectileSpeedScale
	-- Facing (0, 1) -> velocity (0, scale). weapons.md: Knife speed 1.
	runner:step(0.01, frameAt(0, 0, 1))
	T.eq(#spawns, 1, "one knife on the first tick")
	local vx, vz = projVelocity(runner, spawns[1].handle)
	T.eq(vx, 0)
	T.eq(vz, scale)
	-- weapons.md max-level totals: amount +5 (6 knives), projectileInterval -0.06 (0.04 s).
	T.eq(runner.runtimeById.knife.stats.projectileInterval, 0.04)
	run(runner, 0.01, 0.03, 0.01, 0, 1)
	T.eq(#spawns, 1, "second knife not before 0.04 s")
	run(runner, 0.04, 0.21, 0.01, 0, 1)
	T.eq(#spawns, 6, "six knives by 0.2 s (5 intervals of 0.04)")
	run(runner, 0.22, 0.9, 0.01, 0, 1)
	T.eq(#spawns, 6, "no more until the next cooldown")
end)

T.test("WPN-04: Gennaro (+1 amount) with Duplicator 2 fires 9 knives at Lv8", function()
	local world = newWorld()
	local runner, spawns = newRunner(world, { knife = 8 }, "gennaro", { duplicator = 2 })
	-- characters.md: Gennaro amount 1; passives_evolutions.md: Duplicator +1/level, max 2.
	T.eq(runner.runtimeById.knife.stats.amount, 9)
	run(runner, 0, 0.5, 0.01)
	T.eq(#spawns, 9)
end)

T.test(
	"WPN-04: a Lv1 knife hits one enemy (pierce 1) with knockback 0.5 and despawns; a Lv5 knife (pierce 2) hits two",
	function()
		local world = newWorld()
		local e1 = world:add(6, 0, 1000)
		local e2 = world:add(12, 0, 1000)
		local runner = newRunner(world, { knife = 1 }, "imelda")
		run(runner, 0, 0.9, 0.05)
		T.eq(world:hitsOn(e1), 1, "first enemy on the line hit once")
		T.eq(world:hitsOn(e2), 0, "pierce 1: the knife stopped at the first")
		T.eq(world.hits[1].knockback, 0.5, "weapons.md Knife knockback 0.5")
		T.eq(world.hits[1].weaponId, "knife")
		-- weapons.md: Knife 6.5 dmg, innate 30% / 3x crit -> 6.5 or 19.5.
		local a = world.hits[1].amount
		T.truthy(math.abs(a - 6.5) < 1e-9 or math.abs(a - 19.5) < 1e-9, "6.5 or a 3x crit")
		T.eq(runner:projectileCount(), 0, "despawned after its pierce")

		-- weapons.md Knife Lv5 "+1 Pierce".
		local world2 = newWorld()
		local f1 = world2:add(6, 0, 1000)
		local f2 = world2:add(12, 0, 1000)
		local f3 = world2:add(18, 0, 1000)
		local runner2 = newRunner(world2, { knife = 5 }, "imelda")
		run(runner2, 0, 0.9, 0.05)
		T.eq(world2:hitsOn(f1), 1)
		T.eq(world2:hitsOn(f2), 1)
		T.eq(world2:hitsOn(f3), 0, "pierce 2 stops at the second enemy")
	end
)

T.test("WPN-04: a knife that hits nothing despawns past Tuning.despawnRadius", function()
	local world = newWorld()
	local runner = newRunner(world, { knife = 1 }, "imelda")
	runner:step(0.01, frameAt(0))
	T.eq(runner:projectileCount(), 1)
	local flight = Tuning.despawnRadius / Tuning.projectileSpeedScale
	run(runner, 0.01, flight - 0.05, 0.01)
	T.eq(runner:projectileCount(), 1, "still inside the radius")
	run(runner, flight, flight + 0.2, 0.01)
	-- The cooldown (1 s) may have fired more knives; the FIRST is gone.
	T.eq(runner.alive[1], false, "first knife despawned past the radius")
end)

-- ------------------------------------------------------------ magic wand
T.test("WPN-03: each missile targets the closest enemy at unlimited range and retargets per shot", function()
	local world = newWorld()
	local near = world:add(0, -30, 1)
	local far = world:add(10, 0, 1000)
	-- Lv2 = 2 missiles (weapons.md Lv2 "+1 Amount") spaced 0.1 s.
	local runner, spawns = newRunner(world, { magic_wand = 2 }, "imelda")
	runner:step(0.01, frameAt(0))
	T.eq(#spawns, 1)
	local vx, vz = projVelocity(runner, spawns[1].handle)
	T.eq(vx, 0, "aimed at (0,-30)")
	T.eq(vz, -Tuning.projectileSpeedScale)
	-- Kill the near one before the second shot: it must aim at `far`.
	world.alive[near] = false
	run(runner, 0.01, 0.11, 0.01)
	T.eq(#spawns, 2, "second missile after projectileInterval 0.1")
	local vx2, vz2 = projVelocity(runner, spawns[2].handle)
	T.eq(vx2, Tuning.projectileSpeedScale, "retargeted to (10,0)")
	T.eq(vz2, 0)
	T.eq(world:hitsOn(far), 0, "not yet")
	run(runner, 0.12, 1.0, 0.01)
	T.eq(world:hitsOn(far), 1, "the second missile hit it")
end)

T.test("WPN-03: Lv7 missile has pierce 2 and passes through one enemy into a second", function()
	local world = newWorld()
	local e1 = world:add(6, 0, 1000)
	local e2 = world:add(12, 0, 1000)
	local e3 = world:add(18, 0, 1000)
	local runner = newRunner(world, { magic_wand = 7 }, "imelda")
	-- weapons.md Magic Wand Lv7 "+1 Pierce" -> 2.
	T.eq(runner.runtimeById.magic_wand.stats.pierce, 2)
	runner:step(0.01, frameAt(0))
	run(runner, 0.01, 0.8, 0.01)
	T.eq(world:hitsOn(e1), 1)
	T.eq(world:hitsOn(e2), 1)
	T.eq(world:hitsOn(e3), 0)
	-- Record omits crit: Tuning defaults -> always base damage 30 (10 + 10 + 10).
	T.eq(world.hits[1].amount, 30)
end)

T.test("WPN-03: with no enemy alive the wand still fires (random direction) and keeps cadence", function()
	local world = newWorld()
	local runner, spawns = newRunner(world, { magic_wand = 1 }, "imelda")
	run(runner, 0, 1.19, 0.01)
	T.eq(#spawns, 2, "t=0 and t=1.2 (weapons.md cooldown 1.2)")
	local vx, vz = projVelocity(runner, spawns[1].handle)
	T.eq(math.sqrt(vx * vx + vz * vz), Tuning.projectileSpeedScale, "unit direction times speed", 1e-6)
end)

-- ------------------------------------------------------------------ whip
T.test("WPN-02: Lv1 whip hits the enemy in front once per slash and never the one behind", function()
	local world = newWorld()
	local front = world:add(5, 0, 1000)
	local behind = world:add(-5, 0, 1000)
	local runner = newRunner(world, { whip = 1 }, "imelda")
	runner:step(0.05, frameAt(0))
	T.eq(world:hitsOn(front), 1)
	T.eq(world:hitsOn(behind), 0)
	-- weapons.md Whip: 10 dmg, innate 20% / 2x -> 10 or 20; knockback omitted -> default.
	local a = world.hits[1].amount
	T.truthy(a == 10 or a == 20, "10 or a 2x crit")
	T.eq(world.hits[1].knockback, Tuning.defaults.weaponKnockback)
	T.eq(runner:projectileCount(), 0, "the whip spawns no projectile")
	run(runner, 0.05, 1.3, 0.05)
	T.eq(world:hitsOn(front), 1, "one slash per cast at amount 1")
	runner:step(0.05, frameAt(1.35))
	T.eq(world:hitsOn(front), 2, "next cast at cooldown 1.35")
end)

T.test("WPN-02: Lv2 whip (amount 2) slashes both sides, the second 0.1 s after the first", function()
	local world = newWorld()
	local front = world:add(5, 0, 1000)
	local behind = world:add(-5, 0, 1000)
	local runner = newRunner(world, { whip = 2 }, "imelda")
	runner:step(0.01, frameAt(0))
	T.eq(world:hitsOn(front), 1)
	T.eq(world:hitsOn(behind), 0, "second slash waits projectileInterval")
	run(runner, 0.01, 0.09, 0.01)
	T.eq(world:hitsOn(behind), 0)
	runner:step(0.01, frameAt(0.1))
	T.eq(world:hitsOn(behind), 1, "away-from-facing slash at 0.1 s")
	T.eq(world:hitsOn(front), 1)
end)

T.test("WPN-02: Gennaro (+1 amount) already slashes both sides at Lv1", function()
	local world = newWorld()
	local front = world:add(5, 0, 1000)
	local behind = world:add(-5, 0, 1000)
	local runner = newRunner(world, { whip = 1 }, "gennaro")
	run(runner, 0, 0.2, 0.01)
	T.eq(world:hitsOn(front), 1)
	T.eq(world:hitsOn(behind), 1)
end)

T.test(
	"WPN-02: the slash rectangle follows facing and scales with area; everything in one slash takes the same roll",
	function()
		local world = newWorld()
		local halfL = Tuning.whipHalfLength
		local halfW = Tuning.whipHalfWidth
		-- Facing +Z: an enemy up the Z axis inside the reach is hit; one just
		-- past the reach (+ enemyRadius) is not; one beside the rectangle is not.
		local inside = world:add(0, halfL, 1000)
		local past = world:add(0, 2 * halfL + Tuning.enemyRadius + 0.01, 1000)
		local beside = world:add(halfW + Tuning.enemyRadius + 0.01, halfL, 1000)
		local runner = newRunner(world, { whip = 1 }, "imelda")
		runner:step(0.01, frameAt(0, 0, 1))
		T.eq(world:hitsOn(inside), 1)
		T.eq(world:hitsOn(past), 0)
		T.eq(world:hitsOn(beside), 0)

		-- Porta: area 1.3 (characters.md) -> reach grows to 1.3x.
		local world2 = newWorld()
		local a1 = world2:add(0, halfL, 1000)
		local a2 = world2:add(0, 2 * halfL * 1.3 - 0.01, 1000)
		local runner2 = newRunner(world2, { whip = 1 }, "porta")
		runner2:step(0.01, frameAt(0, 0, 1))
		T.eq(world2:hitsOn(a1), 1)
		T.eq(world2:hitsOn(a2), 1, "inside the 1.3x reach")
		T.eq(world2.hits[1].amount, world2.hits[2].amount, "one crit roll per slash")
	end
)

-- ------------------------------------------------------------------- axe
T.test("WPN-05: Lv1 throws one axe straight up (-Z) that falls under Tuning.axeGravity and lives 2 s", function()
	local world = newWorld()
	local runner, spawns = newRunner(world, { axe = 1 }, "imelda")
	runner:step(0.01, frameAt(0))
	T.eq(#spawns, 1)
	local h = spawns[1].handle
	local vx, vz = projVelocity(runner, h)
	T.eq(vx, 0, "first axe has no sideways component")
	-- Launched at -speed*scale, then one tick of gravity along +Z.
	T.eq(vz, -Tuning.projectileSpeedScale + Tuning.axeGravity * 0.01, "", 1e-9)
	-- weapons.md base table: Axe duration 2 (Duration stat ignored).
	T.eq(runner.runtimeById.axe.stats.duration, 2)
	run(runner, 0.01, 1.98, 0.01)
	T.eq(runner.alive[h], true, "still flying just under 2 s")
	run(runner, 1.99, 2.05, 0.01)
	T.eq(runner.alive[h], false, "expired at its 2 s lifetime")
end)

T.test("WPN-05: extra axes go toward the facing side in progressively wider arcs, 0.2 s apart", function()
	local world = newWorld()
	-- Lv5: amount 3 (weapons.md Lv2 and Lv5 "+1 Amount").
	local runner, spawns = newRunner(world, { axe = 5 }, "imelda")
	T.eq(runner.runtimeById.axe.stats.amount, 3)
	runner:step(0.01, frameAt(0, -1, 0))
	T.eq(#spawns, 1)
	run(runner, 0.01, 0.41, 0.01, -1, 0)
	T.eq(#spawns, 3, "three axes by 0.4 s (interval 0.2)")
	local v = Tuning.projectileSpeedScale
	local vx1 = projVelocity(runner, spawns[1].handle)
	local vx2 = projVelocity(runner, spawns[2].handle)
	local vx3 = projVelocity(runner, spawns[3].handle)
	T.eq(vx1, 0)
	T.eq(vx2, -1 * Tuning.axeSpreadStep * v, "second axe toward facing (-X)")
	T.eq(vx3, -2 * Tuning.axeSpreadStep * v, "third axe wider")
end)

T.test("WPN-05: axe hitbox uses area x axeAreaMultiplier and pierce 3 -> 7 at Lv8", function()
	local world = newWorld()
	local runner = newRunner(world, { axe = 1 }, "imelda")
	runner:step(0.01, frameAt(0))
	local s = runner :: any
	T.eq(s.radius[1], Tuning.projectileRadius * Tuning.axeAreaMultiplier)
	T.eq(Tuning.axeAreaMultiplier, 1.3, "weapons.md Axe: Character Area x1.3")
	T.eq(s.pierce[1], 3, "weapons.md Axe pierce 3")
	local runner8 = newRunner(newWorld(), { axe = 8 }, "imelda")
	T.eq(runner8.runtimeById.axe.stats.pierce, 7, "weapons.md max totals: pierce +4")
end)

-- ----------------------------------------------------------------- cross
T.test(
	"WPN-12: the cross flies at the closest enemy, decelerates, reverses through the player and hits on both legs",
	function()
		local world = newWorld()
		local onPath = world:add(6, 0, 1e9)
		world:add(0, 40, 1e9)
		local runner, spawns = newRunner(world, { cross = 1 }, "imelda")
		runner:step(0.01, frameAt(0))
		T.eq(#spawns, 1)
		local h = spawns[1].handle
		local vx0 = projVelocity(runner, h)
		local v0 = Tuning.projectileSpeedScale
		T.eq(vx0, v0 - Tuning.crossDeceleration * 0.01, "launched toward (6,0), one tick of deceleration", 1e-9)
		local s = runner :: any
		T.eq(s.pierce[h], -1, "unbounded pierce")
		T.eq(s.returns[h], true)
		-- Reverses at t = v0 / a; the outward distance is v0^2 / (2a).
		local tRev = v0 / Tuning.crossDeceleration
		run(runner, 0.01, tRev - 0.02, 0.01)
		T.truthy(select(1, projVelocity(runner, h)) > 0, "still outward just before reversal")
		local xMax = s.x[h]
		T.eq(xMax, v0 * v0 / (2 * Tuning.crossDeceleration), "outward reach", 0.5)
		run(runner, tRev, tRev + 0.1, 0.01)
		T.truthy(select(1, projVelocity(runner, h)) < 0, "reversed")
		run(runner, tRev + 0.11, 2 * tRev + 0.5, 0.01)
		T.truthy(s.x[h] < 0, "came back through the player")
		T.eq(world:hitsOn(onPath), 2, "hit once on each leg")
		-- weapons.md Cross: 5 dmg, crit omitted -> always 5.
		T.eq(world.hits[1].amount, 5)
	end
)

T.test("WPN-12: outward reach scales with speed (Lv8 speed 1.5 -> 2.25x the Lv1 reach)", function()
	local function reach(level: number): number
		local world = newWorld()
		world:add(50, 0, 1e9)
		local runner, spawns = newRunner(world, { cross = level }, "imelda")
		runner:step(0.01, frameAt(0))
		local h = spawns[1].handle
		local s = runner :: any
		local best = 0
		for _ = 1, 400 do
			runner:step(0.01, frameAt(0))
			if s.alive[h] and s.x[h] > best then
				best = s.x[h]
			end
		end
		return best
	end
	local r1 = reach(1)
	local r8 = reach(8)
	-- weapons.md max totals: speedDelta +0.5 -> 1.5; reach ~ v0^2.
	T.eq(r8 / r1, 1.5 * 1.5, "", 0.05)
end)

-- ------------------------------------------------------------- fire wand
T.test("WPN-07: Lv1 fires 3 fireballs in an arc centred on a random enemy, 0.02 s apart", function()
	local world = newWorld()
	world:add(0, 20, 1e9)
	local runner, spawns = newRunner(world, { fire_wand = 1 }, "imelda")
	-- weapons.md Conflicts: base amount 3 (shipped), not 1.
	T.eq(runner.runtimeById.fire_wand.stats.amount, 3)
	runner:step(0.005, frameAt(0))
	T.eq(#spawns, 1)
	run(runner, 0.005, 0.05, 0.005)
	T.eq(#spawns, 3, "three fireballs within 0.04 s")
	local speed = 0.75 * Tuning.projectileSpeedScale
	local angles = {}
	for i = 1, 3 do
		local vx, vz = projVelocity(runner, spawns[i].handle)
		T.eq(math.sqrt(vx * vx + vz * vz), speed, "weapons.md Fire Wand speed 0.75", 1e-6)
		angles[i] = math.atan2(vz, vx)
	end
	local toTarget = math.pi / 2
	T.eq(angles[1], toTarget - Tuning.fireWandArcStep, "", 1e-9)
	T.eq(angles[2], toTarget, "middle fireball straight at the target", 1e-9)
	T.eq(angles[3], toTarget + Tuning.fireWandArcStep, "", 1e-9)
end)

T.test("WPN-07: each fireball hits once (pierce default) and the arc widens with Duplicator", function()
	local world = newWorld()
	local e1 = world:add(0, 6, 1e9)
	local e2 = world:add(0, 12, 1e9)
	local runner = newRunner(world, { fire_wand = 1 }, "imelda")
	T.eq(runner.runtimeById.fire_wand.stats.pierce, Tuning.defaults.weaponPierce)
	run(runner, 0, 1.0, 0.01)
	T.truthy(world:hitsOn(e1) >= 1, "the centre fireball hits the first enemy")
	T.eq(world:hitsOn(e1) + world:hitsOn(e2), 3 + 0, "3 fireballs, each spent on one hit at most", 3)
	local world2 = newWorld()
	world2:add(0, 20, 1e9)
	local runner2, spawns2 = newRunner(world2, { fire_wand = 1 }, "imelda", { duplicator = 2 })
	T.eq(runner2.runtimeById.fire_wand.stats.amount, 5)
	run(runner2, 0, 0.2, 0.005)
	T.eq(#spawns2, 5)
	local vx, vz = projVelocity(runner2, spawns2[1].handle)
	T.eq(math.atan2(vz, vx), math.pi / 2 - 2 * Tuning.fireWandArcStep, "end of a 5-wide arc", 1e-9)
end)

-- ------------------------------------------------ runner projectile rules
T.test("pool limit: a weapon never has more live projectiles than its Data poolLimit", function()
	local world = newWorld()
	local runner = WeaponRunner.new({ query = world.query, damage = world.damage, rng = Rng.new(1) })
	local greedy: WeaponBehavior = {
		id = "knife",
		create = function(_rt: WeaponRuntime) end,
		onStatsChanged = function(_rt: WeaponRuntime) end,
		tick = function(rt: WeaponRuntime, ctx: WeaponContext)
			for _ = 1, 200 do
				ctx.spawnProjectile({
					weaponId = "knife",
					x = 0,
					z = 0,
					vx = 0,
					vz = 0,
					radius = 1,
					lifetime = 0,
					pierce = 1,
					damage = rt.stats.damage,
					knockback = 0,
					critChance = 0,
					critMultiplier = 1,
					visualKind = "knife",
				})
			end
		end,
	}
	runner:register(greedy)
	runner:onStatsChanged({ stats = Stats.base("imelda"), weapons = { knife = 1 }, weaponOrder = { "knife" } })
	runner:step(0.01, frameAt(0))
	-- weapons.md base table: Knife pool 70.
	T.eq(runner:liveProjectiles("knife"), 70)
	T.eq(runner:projectileCount(), 70)
end)

T.test("capacity: the pool refuses spawns past its capacity and reuses handles only after a tick", function()
	local world = newWorld()
	local runner, spawns = newRunner(world, { knife = 8 }, "imelda", nil, 2)
	run(runner, 0, 0.3, 0.01)
	T.eq(#spawns, 2, "capacity 2")
	T.eq(runner:projectileCount(), 2)
end)

T.test(
	"bounces: a flagged projectile reflects off the Tuning.projectileBounce box; unbounded hitboxDelay re-hits",
	function()
		local world = newWorld()
		local runner = WeaponRunner.new({ query = world.query, damage = world.damage, rng = Rng.new(1) })
		local handle: number? = nil
		local tracer: WeaponBehavior = {
			id = "runetracer",
			create = function(_rt: WeaponRuntime) end,
			onStatsChanged = function(_rt: WeaponRuntime) end,
			tick = function(rt: WeaponRuntime, ctx: WeaponContext)
				if rt.state.fire and handle == nil then
					handle = ctx.spawnProjectile({
						weaponId = "runetracer",
						x = 0,
						z = 0,
						vx = Tuning.projectileSpeedScale,
						vz = 0,
						radius = 1,
						lifetime = rt.stats.duration,
						pierce = -1,
						damage = rt.stats.damage,
						knockback = 1,
						critChance = 0,
						critMultiplier = 1,
						bounces = -1,
						visualKind = "tracer",
					})
				end
			end,
		}
		runner:register(tracer)
		runner:onStatsChanged({
			stats = Stats.base("imelda"),
			weapons = { runetracer = 1 },
			weaponOrder = { "runetracer" },
		})
		local enemy = world:add(10, 0, 1e9)
		runner:step(0.01, frameAt(0))
		T.truthy(handle ~= nil)
		local h = handle :: number
		local toWall = Tuning.projectileBounce.halfWidth / Tuning.projectileSpeedScale
		run(runner, 0.01, toWall - 0.02, 0.01)
		T.truthy(select(1, projVelocity(runner, h)) > 0, "outbound before the wall")
		run(runner, toWall, toWall + 0.05, 0.01)
		T.truthy(select(1, projVelocity(runner, h)) < 0, "reflected off +X wall")
		local s = runner :: any
		T.truthy(s.x[h] <= Tuning.projectileBounce.halfWidth, "inside the box after reflecting")
		-- weapons.md Runetracer: duration 2.25, hitboxDelay 0.5, infinite pierce.
		T.eq(s.lifetime[h] > 0, true)
		run(runner, toWall + 0.06, 2.24, 0.01)
		T.eq(s.alive[h], true)
		run(runner, 2.25, 2.3, 0.01)
		T.eq(s.alive[h], false, "expired at duration 2.25")
		-- Passed the enemy at x=10 outbound (~0.3 s) and inbound (~2.9 s would be
		-- past duration), so: outbound hits are gated by hitboxDelay 0.5 s while
		-- overlapping (~2.5 studs / 30 studs/s = 0.08 s) -> exactly one hit.
		T.eq(world:hitsOn(enemy), 1)
	end
)

T.test(
	"hits: an unbounded projectile with hitboxDelay 0 hits each enemy once; a stationary one does not repeat",
	function()
		local world = newWorld()
		local runner = WeaponRunner.new({ query = world.query, damage = world.damage, rng = Rng.new(1) })
		local sitter: WeaponBehavior = {
			id = "cross",
			create = function(_rt: WeaponRuntime) end,
			onStatsChanged = function(_rt: WeaponRuntime) end,
			tick = function(rt: WeaponRuntime, ctx: WeaponContext)
				if rt.state.fire then
					ctx.spawnProjectile({
						weaponId = "cross",
						x = 0,
						z = 0,
						vx = 0,
						vz = 0,
						radius = 1,
						lifetime = 0,
						pierce = -1,
						damage = rt.stats.damage,
						knockback = 0,
						critChance = 0,
						critMultiplier = 1,
						visualKind = "cross",
					})
				end
			end,
		}
		runner:register(sitter)
		runner:onStatsChanged({ stats = Stats.base("imelda"), weapons = { cross = 1 }, weaponOrder = { "cross" } })
		local enemy = world:add(0.5, 0, 1e9)
		run(runner, 0, 1.9, 0.1)
		-- One projectile per cast (cooldown 2), each hits the overlapping enemy once.
		T.eq(world:hitsOn(enemy), 1)
		run(runner, 2.0, 3.9, 0.1)
		T.eq(world:hitsOn(enemy), 2)
	end
)

T.test(
	"zero allocation: stepping the runner with live projectiles and enemies allocates nothing in steady state",
	function()
		local world = newWorld()
		for i = 1, 200 do
			world:add((i % 20) * 3, math.floor(i / 20) * 3, 1e9)
		end
		local runner =
			newRunner(world, { knife = 8, magic_wand = 8, axe = 8, fire_wand = 8, cross = 8, whip = 8 }, "imelda")
		-- The fake world's hit log allocates; swap it for a no-op after warm-up.
		local deps = (runner :: any).deps
		local t = 0
		for _ = 1, 300 do
			runner:step(1 / 60, frameAt(t))
			t += 1 / 60
		end
		deps.damage = function(): boolean
			return false
		end;
		(runner :: any).ctx.damage = deps.damage
		collectgarbage("collect")
		local before = collectgarbage("count")
		for _ = 1, 300 do
			runner:step(1 / 60, frameAt(t))
			t += 1 / 60
		end
		local grown = collectgarbage("count") - before
		print(string.format("    weapons_a steady-state growth over 300 steps: %.1f KB", grown))
		T.truthy(grown <= 64, "allocation growth (KB) stays small: " .. tostring(grown))
	end
)

return T.finish()
