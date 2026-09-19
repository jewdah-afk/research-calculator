--!strict
--[[
	server/Weapons/Runetracer.luau -- bouncing straight-line tracer.
	Implements Types.WeaponBehavior against Types.WeaponContext only.

	Oracle: research/vs/weapons.md, "Runetracer" (L129-L148), base stats
	table (L33) and Conflicts (L282):
	  * "Straight-line projectile that BOUNCES off screen edges and obstacles
	    until its Duration expires. Infinite pierce, gated by a 0.5s
	    per-enemy hitbox delay." So: lifetime = rt.stats.duration, pierce -1,
	    and each tracer keeps its own per-enemy next-hit time compared
	    against rt.stats.hitboxDelay.
	  * Base row: damage 10, area 1, speed 1, amount 1, duration 2.25,
	    cooldown 3, pool 50 (conflict: shipped 50 over the wiki's 25,
	    shipped authoritative, weapons.md L282), projectile interval 0.2,
	    hitbox delay 0.5; pierce / knockback / crit absent (Tuning.defaults
	    via Sim/WeaponLevels). Every number is read from rt.stats.
	  * "Best with: Speed, Duration": tracer speed = rt.stats.speed *
	    Tuning.projectileSpeedScale studs/s.

	Research is silent on the launch direction; the tracer leaves the player
	in a uniformly random direction (recorded in the final report).

	Screen edges: the port has no screen, so the tracer reflects off the
	player-centred box Tuning.projectileBounce (NOT from research), the same
	box server/WeaponRunner uses for projectiles flagged `bounces`. The
	spec's `bounces` is set to math.huge (the reference bounces until the
	duration ends, never a fixed number of times). Reflection is applied
	here too, from the tracer's observed motion (the context exposes no
	velocity read), and only when it is moving outward, so a runner that
	already reflected it is left alone and one that does not is covered.
	There are no obstacles in the arena, so "and obstacles" has nothing to
	hit (reported).

	Presentation: each tracer is a projectile-pool entry used as a moving
	marker (radius 0, damage 0, pierce -1, lifetime 0 = until this module
	despawns it at rt.stats.duration); the hitbox
	Tuning.runetracer.hitRadius * rt.stats.area (NOT from research) is
	resolved here with query.inRadius because the pool has no per-enemy
	hitbox delay. No Instances, no yields.

	Fire signal: see KingBible.luau, "Fire signal".

	Types: src/shared/Types.luau returns nil, which the plain `luau` CLI
	refuses to require, so the shapes used here are restated structurally
	(same convention as Sim/ and server/EnemyManager). Keep them in step.
]]

local Tuning = require("../../shared/Tuning")
local Damage = require("../../shared/Sim/Damage")
local WeaponLevels = require("../../shared/Sim/WeaponLevels")

export type EnemyHandle = number
export type ProjectileHandle = number
export type Rng = Damage.Rng
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

local ID = "runetracer"
local VISUAL_KIND = "runetracer"
local NO_HANDLE = 0
local FULL_TURN = 2 * math.pi

-- What this behaviour keeps under rt.state (rt.state IS this table).
type State = {
	lastCooldownSeen: number?,
	enemyCapacity: number,
	slotCapacity: number, -- rt.stats.poolLimit
	-- Tracer slots (structure-of-arrays).
	handles: { ProjectileHandle }, -- NO_HANDLE = slot free
	expiresAt: { number },
	hitRadius: { number },
	speed: { number }, -- studs/s, fixed at launch
	lastX: { number },
	lastZ: { number },
	hitReadyAt: { number }, -- [(slot - 1) * enemyCapacity + enemy] -> time
	-- The cast in progress.
	castLeft: number,
	nextShotAt: number,
	out: { EnemyHandle },
}

local function stateOf(rt: WeaponRuntime): State
	return (rt.state :: any) :: State
end

-- See KingBible.luau, "Fire signal". Returns (fired, carry), carry <= 0.
local function cooldownElapsed(rt: WeaponRuntime, dt: number): (boolean, number)
	local s = stateOf(rt)
	local remaining = rt.cooldownRemaining
	local last = s.lastCooldownSeen
	if last ~= nil and last ~= math.huge then
		if remaining > last then
			s.lastCooldownSeen = remaining
			return true, 0
		end
		if remaining == last and dt > 0 then
			remaining -= dt
			rt.cooldownRemaining = remaining
		end
	end
	s.lastCooldownSeen = remaining
	if remaining <= 0 then
		return true, remaining
	end
	return false, 0
end

local function armCooldown(rt: WeaponRuntime, seconds: number)
	rt.cooldownRemaining = seconds
	stateOf(rt).lastCooldownSeen = seconds
end

local function freeSlot(s: State): number?
	for i = 1, s.slotCapacity do
		if s.handles[i] == NO_HANDLE then
			return i
		end
	end
	return nil
end

local function clearRow(s: State, slot: number)
	local base = (slot - 1) * s.enemyCapacity
	local ready = s.hitReadyAt
	for e = 1, s.enemyCapacity do
		ready[base + e] = 0
	end
end

local function launch(s: State, rt: WeaponRuntime, ctx: WeaponContext)
	local stats = rt.stats
	local slot = freeSlot(s)
	if slot == nil then
		return -- shipped pool limit reached
	end
	local a = ctx.rng:range(0, FULL_TURN)
	local speed = stats.speed * Tuning.projectileSpeedScale
	local px, pz = ctx.playerX, ctx.playerZ
	local h = ctx.spawnProjectile({
		weaponId = ID,
		x = px,
		z = pz,
		vx = speed * math.cos(a),
		vz = speed * math.sin(a),
		radius = 0, -- hitbox resolved here, not by the pool
		lifetime = 0, -- despawned here at rt.stats.duration
		pierce = -1,
		damage = 0,
		knockback = 0,
		critChance = 0,
		critMultiplier = 1,
		bounces = math.huge,
		visualKind = VISUAL_KIND,
	})
	if h == nil then
		return -- projectile pool full: the tracer has nowhere to live
	end
	clearRow(s, slot)
	s.handles[slot] = h
	s.expiresAt[slot] = ctx.time + stats.duration
	s.hitRadius[slot] = Tuning.runetracer.hitRadius * stats.area
	s.speed[slot] = speed
	s.lastX[slot] = px
	s.lastZ[slot] = pz
end

-- Reflects the tracer off the player-centred bounce box when it is outside
-- and still moving outward, using its observed motion since the last tick.
-- Returns the tracer's position afterwards.
local function bounce(
	s: State,
	slot: number,
	ctx: WeaponContext,
	h: ProjectileHandle,
	x: number,
	z: number
): (number, number)
	local dx = x - s.lastX[slot]
	local dz = z - s.lastZ[slot]
	if dx == 0 and dz == 0 then
		return x, z
	end
	local halfW = Tuning.projectileBounce.halfWidth
	local halfD = Tuning.projectileBounce.halfDepth
	local minX, maxX = ctx.playerX - halfW, ctx.playerX + halfW
	local minZ, maxZ = ctx.playerZ - halfD, ctx.playerZ + halfD
	local reflected = false
	local nx, nz = x, z
	if x > maxX and dx > 0 then
		dx = -dx
		nx = maxX
		reflected = true
	elseif x < minX and dx < 0 then
		dx = -dx
		nx = minX
		reflected = true
	end
	if z > maxZ and dz > 0 then
		dz = -dz
		nz = maxZ
		reflected = true
	elseif z < minZ and dz < 0 then
		dz = -dz
		nz = minZ
		reflected = true
	end
	if not reflected then
		return x, z
	end
	local len = math.sqrt(dx * dx + dz * dz)
	local speed = s.speed[slot]
	ctx.setProjectilePosition(h, nx, nz)
	ctx.setProjectileVelocity(h, speed * dx / len, speed * dz / len)
	return nx, nz
end

local Runetracer = {} :: WeaponBehavior
Runetracer.id = ID

function Runetracer.create(rt: WeaponRuntime)
	local s = stateOf(rt)
	local enemyCapacity = Tuning.enemyCapacity
	local slots = rt.stats.poolLimit
	s.lastCooldownSeen = rt.cooldownRemaining
	s.enemyCapacity = enemyCapacity
	s.slotCapacity = slots
	s.handles = table.create(slots, NO_HANDLE)
	s.expiresAt = table.create(slots, 0)
	s.hitRadius = table.create(slots, 0)
	s.speed = table.create(slots, 0)
	s.lastX = table.create(slots, 0)
	s.lastZ = table.create(slots, 0)
	s.hitReadyAt = table.create(slots * enemyCapacity, 0)
	s.castLeft = 0
	s.nextShotAt = 0
	s.out = table.create(enemyCapacity)
end

function Runetracer.onStatsChanged(rt: WeaponRuntime)
	-- Tracers in flight keep the speed, hitbox and expiry they launched
	-- with; the next cast reads the new rt.stats. See KingBible.onStatsChanged.
	stateOf(rt).lastCooldownSeen = math.huge
end

function Runetracer.tick(rt: WeaponRuntime, ctx: WeaponContext)
	local s = stateOf(rt)
	local stats = rt.stats
	local time = ctx.time

	local fired, carry = cooldownElapsed(rt, ctx.dt)
	if fired then
		s.castLeft = stats.amount
		s.nextShotAt = time
		armCooldown(rt, stats.cooldown + carry)
	end

	-- Tracers of one cast are spaced by projectileInterval.
	while s.castLeft > 0 and time >= s.nextShotAt do
		s.castLeft -= 1
		launch(s, rt, ctx)
		s.nextShotAt += stats.projectileInterval
	end

	local out = s.out
	local ready = s.hitReadyAt
	local capacity = s.enemyCapacity
	local hitboxDelay = stats.hitboxDelay
	local knockback = stats.knockback
	for slot = 1, s.slotCapacity do
		local h = s.handles[slot]
		if h ~= NO_HANDLE then
			local alive = ctx.projectileAlive(h)
			if not alive or time >= s.expiresAt[slot] then
				if alive then
					ctx.despawnProjectile(h)
				end
				s.handles[slot] = NO_HANDLE
			else
				local x, z = ctx.projectilePosition(h)
				x, z = bounce(s, slot, ctx, h, x, z)
				s.lastX[slot] = x
				s.lastZ[slot] = z
				local base = (slot - 1) * capacity
				local count = ctx.query.inRadius(x, z, s.hitRadius[slot], out)
				for k = 1, count do
					local e = out[k]
					local idx = base + e
					if time >= ready[idx] then
						local dmg = Damage.roll(stats.damage, stats.critChance, stats.critMultiplier, ctx.rng)
						local died = ctx.damage(e, dmg, knockback, ID)
						if died then
							ready[idx] = 0
						else
							ready[idx] = time + hitboxDelay
						end
					end
				end
			end
		end
	end
end

return Runetracer
