--!strict
--[[
	server/Weapons/SantaWater.luau -- sky-drop bottles that open damaging
	ground zones. Implements Types.WeaponBehavior against Types.WeaponContext
	only.

	Oracle: research/vs/weapons.md, "Santa Water" (L215-L234), base stats
	table (L38) and Conflicts (L279, L281):
	  * "Bottles fall from the sky and shatter into stationary damaging ground
	    zones lasting the weapon's Duration."
	  * "Below 4 total Amount the first bottle of a cast aims at the CLOSEST
	    enemy; at Amount 4+ the bottles land in a clockwise, roughly circular
	    pattern around the player." The threshold 4 is research-stated with
	    no Data field, so it is Tuning.santaWater.circlePatternMinAmount with
	    a research citation.
	  * "Per-enemy hitbox delay 0.5s": each zone keeps its own per-enemy
	    next-hit time, so overlapping zones stack.
	  * "Ignores Speed": Sim/WeaponLevels.effective keeps the level speed;
	    this module never reads speed.
	  * Base row: damage 10, area 1, amount 1, duration 2, cooldown 4.5
	    (conflict: shipped 4.5 s over the wiki's 3.0 s, RESOLVED for shipped
	    data, weapons.md L279 / SUMMARY.md), knockback 0 (shipped), pool 20,
	    projectile interval 0.3, hitbox delay 0.5; duration deltas
	    +0.5/+0.25/+0.25 (conflict L281, shipped data authoritative). Every
	    number is read from rt.stats; deltas are folded by Sim/WeaponLevels.
	  * Pool 20 is the shipped cap on simultaneous zones: a bottle dropped
	    while 20 zones are open is lost, as a pooled bullet is.

	Research is silent on three points; each choice is recorded here and in
	the final report:
	  * Bottles after the first when Amount < 4: each bottle re-targets the
	    closest enemy at its own drop time (the same per-shot retargeting the
	    Magic Wand uses); nothing in the text singles out only the first one.
	  * A bottle with no enemy to aim at lands on the circle-pattern point it
	    would have taken at Amount 4+ (no new number is invented).
	  * "Closest" is unbounded (maxDist math.huge), as for the Magic Wand.
	Engine choices (Tuning, NOT from research): the landing circle radius
	Tuning.santaWater.ringRadius, the time in the air before a zone opens
	Tuning.santaWater.fallTime, and the zone radius in studs
	rt.stats.area * Tuning.areaScale. "Clockwise" is read on the top-down
	screen where -Z is screen-up, so the angle increases with (cos, sin).

	Fire signal: see KingBible.luau, "Fire signal".

	Presentation is fire-and-forget visuals (a drop, then a zone); zones are
	simulated here with query.inRadius. No Instances, no yields.

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

local ID = "santa_water"
local VISUAL_DROP = "santa_water_drop"
local VISUAL_ZONE = "santa_water_zone"
local FULL_TURN = 2 * math.pi

-- What this behaviour keeps under rt.state (rt.state IS this table).
type State = {
	lastCooldownSeen: number?,
	enemyCapacity: number,
	slotCapacity: number, -- rt.stats.poolLimit
	-- Zone slots (structure-of-arrays).
	zoneActive: { boolean },
	zoneX: { number },
	zoneZ: { number },
	zoneRadius: { number },
	zoneOpensAt: { number },
	zoneExpiresAt: { number },
	zoneAnnounced: { boolean }, -- zone visual emitted on its first open tick
	hitReadyAt: { number }, -- [(slot - 1) * enemyCapacity + enemy] -> time
	-- The cast in progress.
	castAmount: number,
	castLeft: number,
	castIndex: number, -- bottles already dropped this cast
	nextDropAt: number,
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
		if not s.zoneActive[i] then
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

-- Landing point of bottle `index` (1-based) of a cast of `amount` on the
-- clockwise circle around the player.
local function circlePoint(ctx: WeaponContext, index: number, amount: number): (number, number)
	local a = (index - 1) * (FULL_TURN / amount)
	local r = Tuning.santaWater.ringRadius
	return ctx.playerX + r * math.cos(a), ctx.playerZ + r * math.sin(a)
end

local function dropBottle(s: State, rt: WeaponRuntime, ctx: WeaponContext, index: number)
	local stats = rt.stats
	local amount = s.castAmount
	local lx, lz
	if amount < Tuning.santaWater.circlePatternMinAmount then
		local target = ctx.query.closest(ctx.playerX, ctx.playerZ, math.huge)
		if target ~= nil then
			lx, lz = ctx.query.position(target)
		else
			lx, lz = circlePoint(ctx, index, amount)
		end
	else
		lx, lz = circlePoint(ctx, index, amount)
	end

	local radius = stats.area * Tuning.areaScale
	local fallTime = Tuning.santaWater.fallTime
	ctx.visual({
		kind = VISUAL_DROP,
		x = lx,
		z = lz,
		radius = radius,
		duration = fallTime,
		weaponId = ID,
	})

	local slot = freeSlot(s)
	if slot == nil then
		return -- shipped pool limit reached: the bottle is lost
	end
	clearRow(s, slot)
	s.zoneActive[slot] = true
	s.zoneX[slot] = lx
	s.zoneZ[slot] = lz
	s.zoneRadius[slot] = radius
	s.zoneOpensAt[slot] = ctx.time + fallTime
	s.zoneExpiresAt[slot] = ctx.time + fallTime + stats.duration
	s.zoneAnnounced[slot] = false
end

local SantaWater = {} :: WeaponBehavior
SantaWater.id = ID

function SantaWater.create(rt: WeaponRuntime)
	local s = stateOf(rt)
	local enemyCapacity = Tuning.enemyCapacity
	local slots = rt.stats.poolLimit
	s.lastCooldownSeen = rt.cooldownRemaining
	s.enemyCapacity = enemyCapacity
	s.slotCapacity = slots
	s.zoneActive = table.create(slots, false)
	s.zoneX = table.create(slots, 0)
	s.zoneZ = table.create(slots, 0)
	s.zoneRadius = table.create(slots, 0)
	s.zoneOpensAt = table.create(slots, 0)
	s.zoneExpiresAt = table.create(slots, 0)
	s.zoneAnnounced = table.create(slots, false)
	s.hitReadyAt = table.create(slots * enemyCapacity, 0)
	s.castAmount = 0
	s.castLeft = 0
	s.castIndex = 0
	s.nextDropAt = 0
	s.out = table.create(enemyCapacity)
end

function SantaWater.onStatsChanged(rt: WeaponRuntime)
	-- Open zones keep the radius and expiry they were dropped with; the next
	-- cast reads the new rt.stats. See KingBible.onStatsChanged.
	stateOf(rt).lastCooldownSeen = math.huge
end

function SantaWater.tick(rt: WeaponRuntime, ctx: WeaponContext)
	local s = stateOf(rt)
	local stats = rt.stats
	local time = ctx.time

	local fired, carry = cooldownElapsed(rt, ctx.dt)
	if fired then
		s.castAmount = stats.amount
		s.castLeft = stats.amount
		s.castIndex = 0
		s.nextDropAt = time
		armCooldown(rt, stats.cooldown + carry)
	end

	-- Bottles of one cast are spaced by projectileInterval.
	while s.castLeft > 0 and time >= s.nextDropAt do
		s.castIndex += 1
		s.castLeft -= 1
		dropBottle(s, rt, ctx, s.castIndex)
		s.nextDropAt += stats.projectileInterval
	end

	-- Open zones.
	local out = s.out
	local ready = s.hitReadyAt
	local capacity = s.enemyCapacity
	for slot = 1, s.slotCapacity do
		if s.zoneActive[slot] then
			if time >= s.zoneExpiresAt[slot] then
				s.zoneActive[slot] = false
			elseif time >= s.zoneOpensAt[slot] then
				local zx, zz, zr = s.zoneX[slot], s.zoneZ[slot], s.zoneRadius[slot]
				if not s.zoneAnnounced[slot] then
					s.zoneAnnounced[slot] = true
					ctx.visual({
						kind = VISUAL_ZONE,
						x = zx,
						z = zz,
						radius = zr,
						duration = s.zoneExpiresAt[slot] - time,
						weaponId = ID,
					})
				end
				local base = (slot - 1) * capacity
				local count = ctx.query.inRadius(zx, zz, zr, out)
				for k = 1, count do
					local e = out[k]
					local idx = base + e
					if time >= ready[idx] then
						local dmg = Damage.roll(stats.damage, stats.critChance, stats.critMultiplier, ctx.rng)
						local died = ctx.damage(e, dmg, stats.knockback, ID)
						if died then
							ready[idx] = 0
						else
							ready[idx] = time + stats.hitboxDelay
						end
					end
				end
			end
		end
	end
end

return SantaWater
