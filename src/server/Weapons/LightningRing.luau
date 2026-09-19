--!strict
--[[
	server/Weapons/LightningRing.luau -- lightning strikes on random
	enemies. Implements Types.WeaponBehavior against Types.WeaponContext only.

	Oracle: research/vs/weapons.md, "Lightning Ring" (L236-L255) and the base
	stats table (L39):
	  * "Calls lightning down on RANDOM on-screen enemies. The bolt itself is
	    cosmetic; damage comes from the circular ground-impact hitbox, scaled
	    by Area." So each strike picks query.random and damages every enemy
	    inside a circle of rt.stats.area * Tuning.areaScale studs around the
	    target's position, once per strike.
	  * "Ignores Speed and Duration": Sim/WeaponLevels.effective keeps the
	    level values; this module never reads speed or duration.
	  * Base row: damage 15, area 1, amount 2, cooldown 4.5, pool 50,
	    projectile interval 0.05 (strikes of one cast are spaced by it);
	    duration / pierce / knockback / crit absent (Tuning.defaults via
	    Sim/WeaponLevels). Every number is read from rt.stats.

	Engine choice the research does not state: "on-screen" is a
	player-centred radius, Tuning.lightningRing.targetRadius (NOT from
	research). A strike with no enemy inside it has no target and is
	skipped (nothing in the text has lightning fall on empty ground);
	recorded in the final report.

	Presentation is one fire-and-forget visual per strike carrying the
	impact circle. Strikes are instantaneous, so nothing lives in the
	projectile pool and the shipped pool limit (50) is never reached.
	No Instances, no yields.

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

local ID = "lightning_ring"
local VISUAL_KIND = "lightning_ring_strike"

-- What this behaviour keeps under rt.state (rt.state IS this table).
type State = {
	lastCooldownSeen: number?,
	castLeft: number,
	nextStrikeAt: number,
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

local function strike(s: State, rt: WeaponRuntime, ctx: WeaponContext)
	local stats = rt.stats
	local target = ctx.query.random(ctx.playerX, ctx.playerZ, Tuning.lightningRing.targetRadius, ctx.rng)
	if target == nil then
		return -- no on-screen enemy: nothing to strike
	end
	local ex, ez = ctx.query.position(target)
	local radius = stats.area * Tuning.areaScale
	ctx.visual({
		kind = VISUAL_KIND,
		x = ex,
		z = ez,
		radius = radius,
		weaponId = ID,
	})
	-- Damage is the ground-impact circle, once per enemy per strike.
	local out = s.out
	local knockback = stats.knockback
	local count = ctx.query.inRadius(ex, ez, radius, out)
	for k = 1, count do
		local dmg = Damage.roll(stats.damage, stats.critChance, stats.critMultiplier, ctx.rng)
		ctx.damage(out[k], dmg, knockback, ID)
	end
end

local LightningRing = {} :: WeaponBehavior
LightningRing.id = ID

function LightningRing.create(rt: WeaponRuntime)
	local s = stateOf(rt)
	s.lastCooldownSeen = rt.cooldownRemaining
	s.castLeft = 0
	s.nextStrikeAt = 0
	s.out = table.create(Tuning.enemyCapacity)
end

function LightningRing.onStatsChanged(rt: WeaponRuntime)
	-- Every number is re-read from rt.stats at each strike. See
	-- KingBible.onStatsChanged.
	stateOf(rt).lastCooldownSeen = math.huge
end

function LightningRing.tick(rt: WeaponRuntime, ctx: WeaponContext)
	local s = stateOf(rt)
	local stats = rt.stats
	local time = ctx.time

	local fired, carry = cooldownElapsed(rt, ctx.dt)
	if fired then
		s.castLeft = stats.amount
		s.nextStrikeAt = time
		armCooldown(rt, stats.cooldown + carry)
	end

	-- Strikes of one cast are spaced by projectileInterval.
	while s.castLeft > 0 and time >= s.nextStrikeAt do
		s.castLeft -= 1
		strike(s, rt, ctx)
		s.nextStrikeAt += stats.projectileInterval
	end
end

return LightningRing
