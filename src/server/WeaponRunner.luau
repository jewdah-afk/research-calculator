--!strict
--[[
	server/WeaponRunner.luau -- owns the WeaponRuntime of every weapon the
	player holds, builds the Types.WeaponContext each tick, dispatches to the
	registered Types.WeaponBehavior modules, and simulates every projectile
	they spawn (movement, gravity arcs, wall bounces, boomerang legs, hits
	with pierce, pool limits, lifetimes and the despawn radius).

	Mechanics are the reference's (research/vs/weapons.md):
	  * A weapon fires when its cooldown elapses. The runner counts
	    rt.cooldownRemaining down by dt every tick; when it reaches <= 0 the
	    runner sets rt.state.fire = true for that one tick (the behaviour
	    starts its cast from `tick`) and afterwards re-arms the timer by the
	    weapon's cycle: rt.stats.cooldown, or rt.stats.cooldown + rt.stats
	    .duration when the shipped record says intervalDependsOnDuration
	    (King Bible: "the cooldown clock only starts after the effect ends,
	    so the effective cycle is cooldown + duration", weapons.md). The
	    re-arm ADDS the cycle to the (<= 0) remainder so cadence never drifts;
	    a behaviour that re-arms rt.cooldownRemaining itself is left alone.
	  * rt.stats is always WeaponLevels.effective(WeaponLevels.statsAt(id,
	    level), player.stats): re-derived by onStatsChanged(state) on
	    level-up, chest grants and every passive change, after which the
	    behaviour's onStatsChanged runs. A shortened cooldown is felt at once:
	    the remaining wait is clamped to the new cycle.
	  * Projectiles: pierce is the number of enemies a projectile may hit
	    before despawning (-1 = unbounded; weapons.md maps `penetrating` to
	    pierce). Each enemy is hit once per projectile, except that an
	    unbounded projectile whose weapon has a hitboxDelay re-hits after that
	    many seconds (Runetracer: "Infinite pierce, gated by a 0.5s per-enemy
	    hitbox delay"), and a boomerang (returnsToPlayer) forgets its hits
	    when it reverses so it "damages every enemy it contacts on both legs"
	    (Cross). The weapon's poolLimit caps its live projectiles: a spawn
	    past it is refused (returns nil), exactly like a full pool.
	  * Crit is rolled per hit through Sim/Damage.roll with the projectile's
	    critChance / critMultiplier (innate per weapon, weapons.md Conflicts).

	Engine choices, all NOT from research and held in Tuning:
	  * Wall bounces reflect off the player-centred Tuning.projectileBounce
	    box (the reference bounces off the screen edges).
	  * A projectile farther than Tuning.despawnRadius from the player is
	    despawned: nothing it could hit is simulated beyond that radius.

	Order inside step(): per weapon: count down, flag fire, tick the
	behaviour, re-arm -> free the handles despawned since the last tick
	(every behaviour has now had a tick to notice they died, so a handle it
	still holds is never reused under it) -> move every live projectile
	(gravity, bounce, leg flip) -> resolve hits -> expire.

	Performance: structure-of-arrays columns per projectile handle with a
	free list, preallocated at capacity; one reused context table; one
	reused scratch list for enemy queries. Nothing inside step() allocates
	after warm-up (per-projectile hit maps are table.clear'ed, which keeps
	their capacity).

	Pure Luau: no Roblox APIs, no yields, so it runs headless under the plain
	`luau` CLI (tests/weapons_a.test.luau). Presentation is server/
	ProjectilePool, which reads the x / z / alive / heading columns.

	Types: src/shared/Types.luau returns nil, which the plain `luau` CLI
	refuses to require, so the aliases below restate the Types.luau shapes
	structurally. Keep them in step with Types.luau.
]]

local Tuning = require("../shared/Tuning")
local Weapons = require("../shared/Data/Weapons")
local WeaponLevels = require("../shared/Sim/WeaponLevels")
local Damage = require("../shared/Sim/Damage")

-- Cooldown boundary tolerance; see Tuning.cooldownEpsilon.
local EPSILON = Tuning.cooldownEpsilon

export type EnemyHandle = number
export type ProjectileHandle = number

-- Mirrors Types.Rng.
export type Rng = {
	next: (self: Rng) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
}

-- Mirrors Types.StatBlock.
export type StatBlock = WeaponLevels.StatBlock

-- Mirrors Types.WeaponInstanceStats.
export type WeaponInstanceStats = WeaponLevels.WeaponInstanceStats

-- Mirrors Types.EnemyQuery.
export type EnemyQuery = {
	count: () -> number,
	isAlive: (EnemyHandle) -> boolean,
	position: (EnemyHandle) -> (number, number),
	closest: (x: number, z: number, maxDist: number) -> EnemyHandle?,
	random: (x: number, z: number, maxDist: number, rng: Rng) -> EnemyHandle?,
	inRadius: (x: number, z: number, radius: number, out: { EnemyHandle }) -> number,
	inBox: (x: number, z: number, halfW: number, halfD: number, out: { EnemyHandle }) -> number,
}

-- Mirrors Types.ProjectileSpec.
export type ProjectileSpec = {
	weaponId: string,
	x: number,
	z: number,
	vx: number,
	vz: number,
	radius: number,
	lifetime: number,
	pierce: number,
	damage: number,
	knockback: number,
	critChance: number,
	critMultiplier: number,
	gravity: number?,
	bounces: number?,
	returnsToPlayer: boolean?,
	visualKind: string,
}

-- Mirrors Types.VisualSpec.
export type VisualSpec = {
	kind: string,
	x: number,
	z: number,
	radius: number?,
	angle: number?,
	duration: number?,
	weaponId: string?,
}

-- Mirrors Types.WeaponContext.
export type WeaponContext = {
	time: number,
	dt: number,
	playerX: number,
	playerZ: number,
	facingX: number,
	facingZ: number,
	moveX: number,
	moveZ: number,
	query: EnemyQuery,
	rng: Rng,
	damage: (enemy: EnemyHandle, amount: number, knockback: number, weaponId: string) -> boolean,
	spawnProjectile: (spec: ProjectileSpec) -> ProjectileHandle?,
	despawnProjectile: (ProjectileHandle) -> (),
	projectileAlive: (ProjectileHandle) -> boolean,
	projectilePosition: (ProjectileHandle) -> (number, number),
	setProjectilePosition: (ProjectileHandle, x: number, z: number) -> (),
	setProjectileVelocity: (ProjectileHandle, vx: number, vz: number) -> (),
	visual: (spec: VisualSpec) -> (),
}

-- Mirrors Types.WeaponRuntime.
export type WeaponRuntime = {
	weaponId: string,
	level: number,
	stats: WeaponInstanceStats,
	cooldownRemaining: number,
	state: { [string]: any },
}

-- Mirrors Types.WeaponBehavior.
export type WeaponBehavior = {
	id: string,
	create: (rt: WeaponRuntime) -> (),
	onStatsChanged: (rt: WeaponRuntime) -> (),
	tick: (rt: WeaponRuntime, ctx: WeaponContext) -> (),
}

-- The slice of Types.PlayerState the runner reads.
export type PlayerWeapons = {
	stats: StatBlock,
	weapons: { [string]: number },
	weaponOrder: { string },
}

-- Where the player is this tick. facing is a unit vector, never zero
-- (Types.WeaponContext); move may be zero.
export type PlayerFrame = {
	time: number,
	playerX: number,
	playerZ: number,
	facingX: number,
	facingZ: number,
	moveX: number,
	moveZ: number,
}

export type Deps = {
	query: EnemyQuery,
	-- Applies damage and the weapon's knockback to an enemy; true if it
	-- died. Normally EnemyManager:damage bound to the manager.
	damage: (enemy: EnemyHandle, amount: number, knockback: number, weaponId: string) -> boolean,
	rng: Rng,
	-- Fire-and-forget visuals for the clients; nil discards them.
	visual: ((spec: VisualSpec) -> ())?,
	-- Projectile pool size; default Tuning.projectileCapacity.
	capacity: number?,
}

export type WeaponRunner = {
	capacity: number,
	-- Weapon runtimes in acquisition order, and by id.
	runtimes: { WeaponRuntime },
	runtimeById: { [string]: WeaponRuntime },
	-- Projectile structure-of-arrays columns, indexed by handle. Read-only
	-- outside this module; ProjectilePool.flush reads x, z, alive, heading.
	x: { number },
	z: { number },
	alive: { boolean },
	heading: { number }, -- atan2(vz, vx) of the last non-zero velocity
	-- Presentation hooks, settable at any time.
	onProjectileSpawn: ((handle: ProjectileHandle, weaponId: string, visualKind: string) -> ())?,
	onProjectileDespawn: ((handle: ProjectileHandle) -> ())?,

	-- Makes a behaviour available; a weapon id with no behaviour errors when
	-- the player acquires it. Re-registering an id replaces it.
	register: (self: WeaponRunner, behaviour: WeaponBehavior) -> (),
	registerAll: (self: WeaponRunner, behaviours: { WeaponBehavior }) -> (),
	-- Syncs runtimes with the player's weapons and re-derives every
	-- rt.stats from the player's StatBlock. Call after LevelUp.apply, after
	-- a chest is applied and whenever a passive changes.
	onStatsChanged: (self: WeaponRunner, player: PlayerWeapons) -> (),
	-- One tick of every weapon and every projectile.
	step: (self: WeaponRunner, dt: number, frame: PlayerFrame) -> (),
	-- Live projectiles in total / for one weapon.
	projectileCount: (self: WeaponRunner) -> number,
	liveProjectiles: (self: WeaponRunner, weaponId: string) -> number,
	-- The cycle the runner re-arms `rt` with (see header).
	cycleOf: (self: WeaponRunner, rt: WeaponRuntime) -> number,
	-- Despawns every projectile silently (end of run).
	clear: (self: WeaponRunner) -> (),
}

type Internal = WeaponRunner & {
	deps: Deps,
	behaviours: { [string]: WeaponBehavior },
	ctx: WeaponContext,
	-- Player frame of the current/last step (despawn radius, bounce box).
	playerX: number,
	playerZ: number,
	time: number,
	-- Projectile columns beyond the public ones.
	vx: { number },
	vz: { number },
	radius: { number },
	lifetime: { number },
	timed: { boolean }, -- lifetime counts down (spec.lifetime > 0)
	pierce: { number }, -- remaining hits; < 0 = unbounded
	dmg: { number },
	kb: { number },
	critChance: { number },
	critMul: { number },
	gravity: { number },
	bounces: { number }, -- 0 = none, > 0 remaining, < 0 unbounded
	returns: { boolean },
	launchX: { number }, -- unit launch direction (boomerang leg test)
	launchZ: { number },
	outward: { boolean }, -- boomerang still on its first leg
	hitDelay: { number }, -- weapon hitboxDelay at spawn
	hits: { { [EnemyHandle]: number } }, -- enemy -> time of last hit
	weaponIdCol: { string },
	visualKindCol: { string },
	-- Pool bookkeeping.
	count: number,
	free: { ProjectileHandle },
	freeCount: number,
	dead: { ProjectileHandle },
	deadCount: number,
	liveByWeapon: { [string]: number },
	-- Scratch list for hit queries.
	out: { EnemyHandle },
}

local WeaponRunner = {}
WeaponRunner.__index = WeaponRunner

-- The cycle a weapon re-arms with: cooldown, plus duration when the shipped
-- record flags intervalDependsOnDuration (weapons.md, King Bible).
function WeaponRunner.cycleOf(self: WeaponRunner, rt: WeaponRuntime): number
	local record = Weapons.data[rt.weaponId]
	if record ~= nil and record.intervalDependsOnDuration == true then
		return rt.stats.cooldown + rt.stats.duration
	end
	return rt.stats.cooldown
end

local function checkHandle(s: Internal, handle: ProjectileHandle, what: string)
	if type(handle) ~= "number" or handle < 1 or handle > s.capacity or handle ~= math.floor(handle) then
		error(string.format("WeaponRunner.%s: %s is not a projectile handle", what, tostring(handle)))
	end
end

-- Marks a live projectile dead now; the handle returns to the free stack
-- only after every behaviour has ticked again, so a behaviour-held handle
-- is never reused before its owner can see projectileAlive() go false.
local function retire(s: Internal, h: ProjectileHandle)
	if not s.alive[h] then
		return
	end
	s.alive[h] = false
	s.count -= 1
	s.deadCount += 1
	s.dead[s.deadCount] = h
	local weaponId = s.weaponIdCol[h]
	s.liveByWeapon[weaponId] -= 1
	local hook = s.onProjectileDespawn
	if hook ~= nil then
		hook(h)
	end
end

local function spawn(s: Internal, spec: ProjectileSpec): ProjectileHandle?
	local weaponId = spec.weaponId
	local rt = s.runtimeById[weaponId]
	if rt == nil then
		error(string.format("WeaponRunner.spawnProjectile: %q is not a weapon the player holds", tostring(weaponId)))
	end
	if s.freeCount == 0 then
		return nil
	end
	local live = s.liveByWeapon[weaponId]
	if live >= rt.stats.poolLimit then
		return nil
	end
	local h = s.free[s.freeCount]
	s.freeCount -= 1
	s.x[h] = spec.x
	s.z[h] = spec.z
	s.vx[h] = spec.vx
	s.vz[h] = spec.vz
	if spec.vx ~= 0 or spec.vz ~= 0 then
		s.heading[h] = math.atan2(spec.vz, spec.vx)
	end
	s.radius[h] = spec.radius
	s.lifetime[h] = spec.lifetime
	s.timed[h] = spec.lifetime > 0
	-- A projectile that may hit nothing is not a thing: 0 behaves as 1.
	local pierce = spec.pierce
	if pierce == 0 then
		pierce = 1
	end
	s.pierce[h] = pierce
	s.dmg[h] = spec.damage
	s.kb[h] = spec.knockback
	s.critChance[h] = spec.critChance
	s.critMul[h] = spec.critMultiplier
	local gravity = spec.gravity
	s.gravity[h] = if gravity ~= nil then gravity else 0
	local bounces = spec.bounces
	s.bounces[h] = if bounces ~= nil then bounces else 0
	s.returns[h] = spec.returnsToPlayer == true
	local len = math.sqrt(spec.vx * spec.vx + spec.vz * spec.vz)
	if len > 0 then
		s.launchX[h] = spec.vx / len
		s.launchZ[h] = spec.vz / len
	else
		s.launchX[h] = 0
		s.launchZ[h] = 0
	end
	s.outward[h] = true
	s.hitDelay[h] = rt.stats.hitboxDelay
	table.clear(s.hits[h])
	s.weaponIdCol[h] = weaponId
	s.visualKindCol[h] = spec.visualKind
	s.alive[h] = true
	s.count += 1
	s.liveByWeapon[weaponId] = live + 1
	local hook = s.onProjectileSpawn
	if hook ~= nil then
		hook(h, weaponId, spec.visualKind)
	end
	return h
end

-- Creates a runner over `deps.query` / `deps.damage` with every projectile
-- column preallocated at `deps.capacity` (default Tuning.projectileCapacity).
function WeaponRunner.new(deps: Deps): WeaponRunner
	local cap = deps.capacity or Tuning.projectileCapacity
	if cap < 1 then
		error("WeaponRunner.new: capacity must be >= 1")
	end
	local free = table.create(cap, 0)
	for h = 1, cap do
		free[h] = cap + 1 - h
	end
	local hits = table.create(cap)
	for h = 1, cap do
		hits[h] = {}
	end

	local s: Internal = setmetatable({
		capacity = cap,
		deps = deps,
		behaviours = {},
		runtimes = {},
		runtimeById = {},
		x = table.create(cap, 0),
		z = table.create(cap, 0),
		alive = table.create(cap, false),
		heading = table.create(cap, 0),
		vx = table.create(cap, 0),
		vz = table.create(cap, 0),
		radius = table.create(cap, 0),
		lifetime = table.create(cap, 0),
		timed = table.create(cap, false),
		pierce = table.create(cap, 0),
		dmg = table.create(cap, 0),
		kb = table.create(cap, 0),
		critChance = table.create(cap, 0),
		critMul = table.create(cap, 0),
		gravity = table.create(cap, 0),
		bounces = table.create(cap, 0),
		returns = table.create(cap, false),
		launchX = table.create(cap, 0),
		launchZ = table.create(cap, 0),
		outward = table.create(cap, false),
		hitDelay = table.create(cap, 0),
		hits = hits,
		weaponIdCol = table.create(cap, ""),
		visualKindCol = table.create(cap, ""),
		count = 0,
		free = free,
		freeCount = cap,
		dead = table.create(cap, 0),
		deadCount = 0,
		liveByWeapon = {},
		out = table.create(Tuning.enemyCapacity, 0),
		playerX = 0,
		playerZ = 0,
		time = 0,
		onProjectileSpawn = nil,
		onProjectileDespawn = nil,
		register = WeaponRunner.register,
		registerAll = WeaponRunner.registerAll,
		onStatsChanged = WeaponRunner.onStatsChanged,
		step = WeaponRunner.step,
		projectileCount = WeaponRunner.projectileCount,
		liveProjectiles = WeaponRunner.liveProjectiles,
		cycleOf = WeaponRunner.cycleOf,
		clear = WeaponRunner.clear,
	}, WeaponRunner) :: any

	-- Types.WeaponContext: one table, fields rewritten every step.
	local visual = deps.visual
	local ctx: WeaponContext = {
		time = 0,
		dt = 0,
		playerX = 0,
		playerZ = 0,
		facingX = 1,
		facingZ = 0,
		moveX = 0,
		moveZ = 0,
		query = deps.query,
		rng = deps.rng,
		damage = deps.damage,
		spawnProjectile = function(spec: ProjectileSpec): ProjectileHandle?
			return spawn(s, spec)
		end,
		despawnProjectile = function(h: ProjectileHandle)
			checkHandle(s, h, "despawnProjectile")
			retire(s, h)
		end,
		projectileAlive = function(h: ProjectileHandle): boolean
			return s.alive[h] == true
		end,
		projectilePosition = function(h: ProjectileHandle): (number, number)
			return s.x[h], s.z[h]
		end,
		setProjectilePosition = function(h: ProjectileHandle, x: number, z: number)
			checkHandle(s, h, "setProjectilePosition")
			s.x[h] = x
			s.z[h] = z
		end,
		setProjectileVelocity = function(h: ProjectileHandle, vx: number, vz: number)
			checkHandle(s, h, "setProjectileVelocity")
			s.vx[h] = vx
			s.vz[h] = vz
			if vx ~= 0 or vz ~= 0 then
				s.heading[h] = math.atan2(vz, vx)
			end
		end,
		visual = function(spec: VisualSpec)
			if visual ~= nil then
				visual(spec)
			end
		end,
	}
	s.ctx = ctx
	return s
end

function WeaponRunner.register(self: WeaponRunner, behaviour: WeaponBehavior)
	local s = self :: Internal
	if Weapons.data[behaviour.id] == nil then
		error(string.format("WeaponRunner.register: %q is not a weapon id in Data", tostring(behaviour.id)))
	end
	s.behaviours[behaviour.id] = behaviour
end

function WeaponRunner.registerAll(self: WeaponRunner, behaviours: { WeaponBehavior })
	for _, behaviour in behaviours do
		self:register(behaviour)
	end
end

local function syncOne(s: Internal, weaponId: string, level: number, stats: StatBlock)
	local behaviour = s.behaviours[weaponId]
	if behaviour == nil then
		error(string.format("WeaponRunner: no behaviour registered for weapon %q", weaponId))
	end
	local derived = WeaponLevels.effective(WeaponLevels.statsAt(weaponId, level), stats)
	local rt = s.runtimeById[weaponId]
	if rt == nil then
		rt = {
			weaponId = weaponId,
			level = level,
			stats = derived,
			-- Fires on its first tick, as the reference does at run start.
			cooldownRemaining = 0,
			state = {},
		}
		s.runtimeById[weaponId] = rt
		table.insert(s.runtimes, rt)
		if s.liveByWeapon[weaponId] == nil then
			s.liveByWeapon[weaponId] = 0
		end
		behaviour.create(rt)
	else
		rt.level = level
		rt.stats = derived
		-- A shorter cycle is felt now, not after the current wait.
		local cycle = s:cycleOf(rt)
		if rt.cooldownRemaining > cycle then
			rt.cooldownRemaining = cycle
		end
		behaviour.onStatsChanged(rt)
	end
end

-- Creates runtimes for newly acquired weapons (in weaponOrder, then any id
-- weaponOrder omits, alphabetically) and re-derives every rt.stats.
function WeaponRunner.onStatsChanged(self: WeaponRunner, player: PlayerWeapons)
	local s = self :: Internal
	local seen: { [string]: boolean } = {}
	for _, weaponId in player.weaponOrder do
		local level = player.weapons[weaponId]
		if level ~= nil and not seen[weaponId] then
			seen[weaponId] = true
			syncOne(s, weaponId, level, player.stats)
		end
	end
	local extra: { string } = {}
	for weaponId in player.weapons do
		if not seen[weaponId] then
			table.insert(extra, weaponId)
		end
	end
	if #extra > 0 then
		table.sort(extra)
		for _, weaponId in extra do
			syncOne(s, weaponId, player.weapons[weaponId], player.stats)
		end
	end
end

-- Moves one live projectile: gravity, straight flight, the bounce box, the
-- boomerang leg flip. Returns false if it left the despawn radius.
local function move(s: Internal, h: ProjectileHandle, dt: number): boolean
	local vx, vz = s.vx[h], s.vz[h]
	local g = s.gravity[h]
	if g ~= 0 then
		-- Gravity acts along +Z (screen-down); axes launch along -Z.
		vz += g * dt
	end
	local x = s.x[h] + vx * dt
	local z = s.z[h] + vz * dt

	local bounces = s.bounces[h]
	if bounces ~= 0 then
		local px, pz = s.playerX, s.playerZ
		local hw = Tuning.projectileBounce.halfWidth
		local hd = Tuning.projectileBounce.halfDepth
		local bounced = false
		if x < px - hw and vx < 0 then
			x = 2 * (px - hw) - x
			vx = -vx
			bounced = true
		elseif x > px + hw and vx > 0 then
			x = 2 * (px + hw) - x
			vx = -vx
			bounced = true
		end
		if z < pz - hd and vz < 0 then
			z = 2 * (pz - hd) - z
			vz = -vz
			bounced = true
		elseif z > pz + hd and vz > 0 then
			z = 2 * (pz + hd) - z
			vz = -vz
			bounced = true
		end
		if bounced and bounces > 0 then
			s.bounces[h] = bounces - 1
		end
	end

	if s.returns[h] and s.outward[h] then
		-- Reversed along its launch line: second leg, fresh hit list.
		if vx * s.launchX[h] + vz * s.launchZ[h] < 0 then
			s.outward[h] = false
			table.clear(s.hits[h])
		end
	end

	s.x[h] = x
	s.z[h] = z
	s.vx[h] = vx
	s.vz[h] = vz
	if vx ~= 0 or vz ~= 0 then
		s.heading[h] = math.atan2(vz, vx)
	end

	local dx = x - s.playerX
	local dz = z - s.playerZ
	return dx * dx + dz * dz <= Tuning.despawnRadius * Tuning.despawnRadius
end

-- Damages every enemy overlapping projectile `h` that it may hit now, and
-- spends pierce. Returns false when the projectile is exhausted.
local function resolveHits(s: Internal, h: ProjectileHandle, time: number): boolean
	local query = s.deps.query
	local out = s.out
	local n = query.inRadius(s.x[h], s.z[h], s.radius[h] + Tuning.enemyRadius, out)
	if n == 0 then
		return true
	end
	local hits = s.hits[h]
	local delay = s.hitDelay[h]
	local pierce = s.pierce[h]
	local weaponId = s.weaponIdCol[h]
	local damage = s.deps.damage
	local rng = s.deps.rng
	for i = 1, n do
		local enemy = out[i]
		if not query.isAlive(enemy) then
			-- A dead enemy is still in the grid for the tick between its
			-- death and EnemyManager freeing its handle. Drop its entry
			-- now: the handle is about to be recycled, and a stale entry
			-- would make the next enemy to reuse it immune to this
			-- projectile for the rest of its life.
			hits[enemy] = nil
			continue
		end
		local last = hits[enemy]
		local mayHit = last == nil or (delay > 0 and time - last >= delay)
		if mayHit then
			hits[enemy] = time
			local amount = Damage.roll(s.dmg[h], s.critChance[h], s.critMul[h], rng)
			damage(enemy, amount, s.kb[h], weaponId)
			if pierce > 0 then
				pierce -= 1
				if pierce == 0 then
					s.pierce[h] = 0
					return false
				end
			end
		end
	end
	s.pierce[h] = pierce
	return true
end

-- One tick. See the header for the order of operations.
function WeaponRunner.step(self: WeaponRunner, dt: number, frame: PlayerFrame)
	local s = self :: Internal
	s.playerX = frame.playerX
	s.playerZ = frame.playerZ
	s.time = frame.time

	-- 1. Weapons: cooldown, fire flag, behaviour tick, re-arm.
	local ctx = s.ctx
	ctx.time = frame.time
	ctx.dt = dt
	ctx.playerX = frame.playerX
	ctx.playerZ = frame.playerZ
	ctx.facingX = frame.facingX
	ctx.facingZ = frame.facingZ
	ctx.moveX = frame.moveX
	ctx.moveZ = frame.moveZ
	for _, rt in s.runtimes do
		-- The timer is TESTED before this tick's dt is spent, so a weapon
		-- fires on the frame whose time has reached its cycle, not one frame
		-- early: a cooldown 1.35 whip cast at t = 0 fires again at t = 1.35,
		-- never at 1.35 - dt (weapons.md base table: Whip cooldown 1.35 s).
		-- The comparison carries Tuning.cooldownEpsilon so the tick that
		-- exactly consumes the cooldown fires whichever way the accumulated
		-- subtraction rounded; see the constant's note in Tuning.
		local fire = rt.cooldownRemaining <= EPSILON
		rt.state.fire = fire
		s.behaviours[rt.weaponId].tick(rt, ctx)
		if fire then
			rt.state.fire = false
			if rt.cooldownRemaining <= EPSILON then
				local cycle = s:cycleOf(rt)
				rt.cooldownRemaining += cycle
				if rt.cooldownRemaining <= EPSILON then
					rt.cooldownRemaining = cycle
				end
			end
		end
		rt.cooldownRemaining -= dt
	end

	-- 2. Return the handles despawned since the last tick to the free stack.
	local free, dead = s.free, s.dead
	local freeCount = s.freeCount
	for i = 1, s.deadCount do
		freeCount += 1
		free[freeCount] = dead[i]
	end
	s.freeCount = freeCount
	s.deadCount = 0

	-- 3. Projectiles: move, hit, expire.
	local alive, lifetime, timed = s.alive, s.lifetime, s.timed
	local time = frame.time
	for h = 1, s.capacity do
		if alive[h] then
			local keep = move(s, h, dt)
			if keep then
				keep = resolveHits(s, h, time)
			end
			if keep and timed[h] then
				local left = lifetime[h] - dt
				lifetime[h] = left
				keep = left > 0
			end
			if not keep then
				retire(s, h)
			end
		end
	end
end

function WeaponRunner.projectileCount(self: WeaponRunner): number
	return (self :: Internal).count
end

function WeaponRunner.liveProjectiles(self: WeaponRunner, weaponId: string): number
	local live = (self :: Internal).liveByWeapon[weaponId]
	if live == nil then
		return 0
	end
	return live
end

-- Despawns every projectile (hooks fire) and resets the pool.
function WeaponRunner.clear(self: WeaponRunner)
	local s = self :: Internal
	for h = 1, s.capacity do
		if s.alive[h] then
			retire(s, h)
		end
	end
	for h = 1, s.capacity do
		s.free[h] = s.capacity + 1 - h
	end
	s.freeCount = s.capacity
	s.deadCount = 0
	s.count = 0
end

return WeaponRunner
