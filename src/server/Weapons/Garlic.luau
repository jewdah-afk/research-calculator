--!strict
--[[
	server/Weapons/Garlic.luau -- permanent damaging aura. Implements
	Types.WeaponBehavior against Types.WeaponContext only.

	Oracle: research/vs/weapons.md, "Garlic" (L194-L213) and the base stats
	table (L37):
	  * "Permanent damaging aura centred on the player; no aiming."
	  * "The cooldown (interval) doubles as the per-enemy hitbox delay: an
	    enemy is hit on entry, then not again until the cooldown elapses even
	    if it leaves and re-enters." So the aura is evaluated every tick and
	    each enemy carries its own next-hit time = last hit + rt.stats.cooldown;
	    leaving the aura does not reset it.
	  * "Ignores Amount, Duration and Speed." Sim/WeaponLevels.effective
	    already keeps the level values for those; this module never reads
	    amount, duration or speed.
	  * Base row: damage 5, area 1, cooldown 1.3, knockback 0 (shipped), pool
	    50, projectile interval 0; pierce / crit absent (Tuning.defaults via
	    Sim/WeaponLevels). Every number is read from rt.stats.
	  * "Each hit lowers the target's knockback and freeze resistance" has no
	    counterpart in Types.WeaponContext (no per-enemy resistance write), so
	    it is NOT modelled; reported as an interface gap.

	Engine choice the research does not state: the aura radius in studs is
	rt.stats.area * Tuning.areaScale (the shared area-to-studs scale, NOT
	from research).

	Presentation: an aura pulse visual is emitted once per rt.stats.cooldown
	through the runner's cooldown counter (WPN-01: the runner fires a weapon
	when rt.cooldownRemaining <= 0 and it is re-armed to rt.stats.cooldown);
	that pulse carries no gameplay state -- the per-enemy timers above do.

	Fire signal: see KingBible.luau, "Fire signal"; the same protocol is used
	here for the pulse visual only.

	Handle reuse: a per-enemy next-hit time can outlive its enemy by at most
	one cooldown (<= 1.3 s). A reused handle spawns on the Tuning
	.spawnRingRadius ring, far outside the aura, so it never inherits a live
	window in practice; a kill by this aura clears it immediately anyway.

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

local ID = "garlic"
local VISUAL_KIND = "garlic_aura"

-- What this behaviour keeps under rt.state (rt.state IS this table).
type State = {
	lastCooldownSeen: number?,
	hitReadyAt: { number }, -- [enemy handle] -> time the aura may hit it again
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

local Garlic = {} :: WeaponBehavior
Garlic.id = ID

function Garlic.create(rt: WeaponRuntime)
	local s = stateOf(rt)
	local enemyCapacity = Tuning.enemyCapacity
	s.lastCooldownSeen = rt.cooldownRemaining
	s.hitReadyAt = table.create(enemyCapacity, 0)
	s.out = table.create(enemyCapacity)
end

function Garlic.onStatsChanged(rt: WeaponRuntime)
	-- Radius, damage and the per-enemy delay are re-read from rt.stats every
	-- tick; timers already running keep the interval they were set with.
	stateOf(rt).lastCooldownSeen = math.huge
end

function Garlic.tick(rt: WeaponRuntime, ctx: WeaponContext)
	local s = stateOf(rt)
	local stats = rt.stats
	local time = ctx.time
	local px, pz = ctx.playerX, ctx.playerZ
	local radius = stats.area * Tuning.areaScale

	-- Aura pulse visual on the weapon's cooldown cadence (no gameplay state).
	local fired, carry = cooldownElapsed(rt, ctx.dt)
	if fired then
		ctx.visual({
			kind = VISUAL_KIND,
			x = px,
			z = pz,
			radius = radius,
			duration = stats.cooldown,
			weaponId = ID,
		})
		armCooldown(rt, stats.cooldown + carry)
	end

	-- The aura itself: every enemy inside is hit on entry, then once per
	-- cooldown while its own timer says so.
	local out = s.out
	local ready = s.hitReadyAt
	local cooldown = stats.cooldown
	local knockback = stats.knockback -- shipped 0: Garlic never pushes
	local count = ctx.query.inRadius(px, pz, radius, out)
	for k = 1, count do
		local e = out[k]
		if time >= ready[e] then
			local dmg = Damage.roll(stats.damage, stats.critChance, stats.critMultiplier, ctx.rng)
			local died = ctx.damage(e, dmg, knockback, ID)
			if died then
				ready[e] = 0
			else
				ready[e] = time + cooldown
			end
		end
	end
end

return Garlic
