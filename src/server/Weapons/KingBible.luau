--!strict
--[[
	server/Weapons/KingBible.luau -- orbiting bibles. Implements
	Types.WeaponBehavior against Types.WeaponContext only.

	Oracle: research/vs/weapons.md, "King Bible" (L171-L192) and the base
	stats table (L36):
	  * "Bibles orbit the player clockwise for the weapon's Duration, then the
	    weapon goes on cooldown. Speed = rotation rate, Area = orbit radius
	    (capped) and bible hitbox size, Amount = evenly spaced extras."
	  * "intervalDependsOnDuration: true - the cooldown clock only starts
	    after the effect ends, so the effective cycle is cooldown + duration"
	    (3.0 + 3.0 = 6.0 s at Lv1). The cooldown is therefore re-armed to
	    rt.stats.cooldown + rt.stats.duration, never to cooldown alone.
	  * "Per-enemy hitbox delay 1.7s": each bible keeps its own per-enemy
	    next-hit time, so two bibles can each hit the same enemy.
	  * Base row: damage 10, area 1, speed 1, amount 1, duration 3, cooldown 3,
	    pool 50, projectile interval 0 (all bibles appear at once), hitbox
	    delay 1.7; pierce / knockback / crit absent (Tuning.defaults via
	    Sim/WeaponLevels). Every number is read from rt.stats.

	Engine choices the research does not state (all in Tuning, NOT from
	research): the orbit radius is rt.stats.area * Tuning.areaScale capped at
	Tuning.kingBible.orbitRadiusCap; the bible hitbox is
	Tuning.kingBible.hitRadius * rt.stats.area; the rotation rate is
	2 * pi * Tuning.kingBible.revolutionsPerSecond * rt.stats.speed rad/s.
	"Clockwise" is read on the top-down screen where -Z is screen-up
	(docs: Axe launches screen-up along -Z), so the angle increases with
	(x, z) = (cos, sin): right -> down -> left -> up.

	Presentation: each bible is a projectile-pool entry used purely as a
	moving marker (radius 0, damage 0, pierce -1, lifetime 0 = until this
	module despawns it). The hitbox is resolved here with query.inRadius
	because the projectile pool has no per-enemy hitbox delay. Handles are
	integers; no Instances, no yields.

	Fire signal: Types.WeaponBehavior has no fire hook. WeaponRunner counts
	rt.cooldownRemaining down every step (WPN-01); the weapon fires when it
	reaches 0 and re-arms it here. A runner that re-arms the counter itself
	before tick shows as an upward jump and one that leaves it untouched
	shows as a stall; both are read as the same signal, so no variant
	double-fires or never fires.

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

local ID = "king_bible"
local VISUAL_KIND = "king_bible"
local NO_HANDLE = 0
local FULL_TURN = 2 * math.pi

-- What this behaviour keeps under rt.state (rt.state IS this table).
type State = {
	lastCooldownSeen: number?,
	enemyCapacity: number,
	slotCapacity: number, -- rt.stats.poolLimit
	handles: { ProjectileHandle }, -- per bible slot; NO_HANDLE when the pool was full
	activeCount: number, -- bibles in the current orbit, 0 between orbits
	activeUntil: number,
	angle: number, -- orbit phase of bible 1 (radians)
	hitReadyAt: { number }, -- [(slot - 1) * enemyCapacity + enemy] -> time
	out: { EnemyHandle },
}

local function stateOf(rt: WeaponRuntime): State
	return (rt.state :: any) :: State
end

-- See the header, "Fire signal". Returns (fired, carry) where carry <= 0 is
-- the overshoot past 0 to fold into the next arm so the average cadence is
-- exactly the stat.
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

local function clearRow(s: State, slot: number)
	local base = (slot - 1) * s.enemyCapacity
	local ready = s.hitReadyAt
	for e = 1, s.enemyCapacity do
		ready[base + e] = 0
	end
end

local function endOrbit(s: State, ctx: WeaponContext)
	for i = 1, s.activeCount do
		local h = s.handles[i]
		if h ~= NO_HANDLE and ctx.projectileAlive(h) then
			ctx.despawnProjectile(h)
		end
		s.handles[i] = NO_HANDLE
	end
	s.activeCount = 0
end

local KingBible = {} :: WeaponBehavior
KingBible.id = ID

function KingBible.create(rt: WeaponRuntime)
	local s = stateOf(rt)
	local enemyCapacity = Tuning.enemyCapacity
	local slots = rt.stats.poolLimit
	s.lastCooldownSeen = rt.cooldownRemaining
	s.enemyCapacity = enemyCapacity
	s.slotCapacity = slots
	s.handles = table.create(slots, NO_HANDLE)
	s.activeCount = 0
	s.activeUntil = 0
	s.angle = 0
	s.hitReadyAt = table.create(slots * enemyCapacity, 0)
	s.out = table.create(enemyCapacity)
end

function KingBible.onStatsChanged(rt: WeaponRuntime)
	-- Nothing is cached from rt.stats between ticks: radius, rate, hitbox and
	-- damage are re-read every tick, and the bible count is fixed per orbit.
	-- Suppress the jump heuristic for one tick in case the runner rescales
	-- rt.cooldownRemaining for the new cooldown.
	stateOf(rt).lastCooldownSeen = math.huge
end

function KingBible.tick(rt: WeaponRuntime, ctx: WeaponContext)
	local s = stateOf(rt)
	local stats = rt.stats
	local time = ctx.time
	local px, pz = ctx.playerX, ctx.playerZ

	local fired, carry = cooldownElapsed(rt, ctx.dt)
	if fired then
		if s.activeCount > 0 then
			-- Fired mid-orbit (only possible if the runner shortened the counter
			-- on a stats change): "the cooldown clock only starts after the
			-- effect ends", so wait out the orbit, then the cooldown.
			armCooldown(rt, (s.activeUntil - time) + stats.cooldown)
		else
			local n = stats.amount
			if n > s.slotCapacity then
				n = s.slotCapacity -- shipped pool limit
			end
			s.activeCount = n
			s.activeUntil = time + stats.duration
			s.angle = 0
			for i = 1, n do
				clearRow(s, i)
				local h = ctx.spawnProjectile({
					weaponId = ID,
					x = px,
					z = pz,
					vx = 0,
					vz = 0,
					radius = 0, -- hitbox resolved here, not by the pool
					lifetime = 0, -- despawned by endOrbit
					pierce = -1,
					damage = 0,
					knockback = 0,
					critChance = 0,
					critMultiplier = 1,
					visualKind = VISUAL_KIND,
				})
				s.handles[i] = h or NO_HANDLE
			end
			-- intervalDependsOnDuration: cycle = cooldown + duration.
			armCooldown(rt, stats.cooldown + stats.duration + carry)
		end
	end

	local n = s.activeCount
	if n == 0 then
		return
	end
	if time >= s.activeUntil then
		endOrbit(s, ctx)
		return
	end

	-- Advance the orbit. Speed = rotation rate; Area = orbit radius (capped)
	-- and hitbox size.
	s.angle += FULL_TURN * Tuning.kingBible.revolutionsPerSecond * stats.speed * ctx.dt
	local orbitRadius = math.min(stats.area * Tuning.areaScale, Tuning.kingBible.orbitRadiusCap)
	local hitRadius = Tuning.kingBible.hitRadius * stats.area
	local spacing = FULL_TURN / n
	local out = s.out
	local ready = s.hitReadyAt
	local capacity = s.enemyCapacity
	local hitboxDelay = stats.hitboxDelay
	local knockback = stats.knockback

	for i = 1, n do
		local a = s.angle + (i - 1) * spacing
		local bx = px + orbitRadius * math.cos(a)
		local bz = pz + orbitRadius * math.sin(a)
		local h = s.handles[i]
		if h ~= NO_HANDLE and ctx.projectileAlive(h) then
			ctx.setProjectilePosition(h, bx, bz)
		end
		local base = (i - 1) * capacity
		local count = ctx.query.inRadius(bx, bz, hitRadius, out)
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

return KingBible
