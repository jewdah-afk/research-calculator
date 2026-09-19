--!strict
--[[
	server/Weapons/FireWand.luau -- Types.WeaponBehavior for the fire wand.

	Oracle: research/vs/weapons.md, Fire Wand. "Fires an arc of fireballs
	toward a RANDOM enemy; all fireballs of a cast launch near-simultaneously
	(repeatInterval 0.02s) and extra fireballs widen the ends of the arc.
	Ignores Duration."

	  * A cast picks ONE random living enemy through ctx.query.random within
	    Tuning.fireWandTargetRadius (NOT from research; stands in for "on
	    screen") and fires rt.stats.amount fireballs (base amount 3:
	    weapons.md Conflicts, shipped data over the fandom wiki's 1) spaced
	    by rt.stats.projectileInterval (0.02 s). Fireball k of a cast of n
	    leaves at angle toTarget + (k - (n - 1) / 2) * Tuning.fireWandArcStep
	    (NOT from research), so the arc is centred on the target and every
	    extra fireball widens its ends.
	  * Speed = rt.stats.speed * Tuning.projectileSpeedScale (0.75 -> 1.35).
	    Pierce is the record's omission resolved to Tuning.defaults
	    .weaponPierce (1): the base Fire Wand does not pass through, its
	    evolution does. Damage, knockback and crit from rt.stats; the runner
	    rolls crit per hit.
	  * The shipped record carries duration 0.1 s. At 0.75 x 30 studs/s that
	    would be a 2.25-stud flight, which is not the reference behaviour
	    (fireballs cross the screen), so it is NOT used as the projectile
	    lifetime; lifetime is 0 (until pierce is spent or the despawn
	    radius). What the shipped field means is a research gap, recorded in
	    the report.
	  * Research is silent on a cast with no living enemy in range. Choice:
	    the arc is centred on a uniformly random direction (ctx.rng),
	    recorded in the report.

	Pure Luau: no Roblox APIs, no Instances, no yields.
]]

local Tuning = require("../../shared/Tuning")
local WeaponRunner = require("../WeaponRunner")

type WeaponRuntime = WeaponRunner.WeaponRuntime
type WeaponContext = WeaponRunner.WeaponContext
type WeaponBehavior = WeaponRunner.WeaponBehavior
type ProjectileSpec = WeaponRunner.ProjectileSpec

local ID = "fire_wand"
local VISUAL_KIND = "fireball"
local TWO_PI = 2 * math.pi
-- Not a lifetime: see the header on the shipped 0.1 s duration.
local NO_LIFETIME = 0

-- Picks the cast's target direction and arc size.
local function beginCast(rt: WeaponRuntime, ctx: WeaponContext)
	local st = rt.state
	local px, pz = ctx.playerX, ctx.playerZ
	local angle
	local target = ctx.query.random(px, pz, Tuning.fireWandTargetRadius, ctx.rng)
	if target ~= nil then
		local tx, tz = ctx.query.position(target)
		local dx = tx - px
		local dz = tz - pz
		if dx ~= 0 or dz ~= 0 then
			angle = math.atan2(dz, dx)
		else
			angle = math.atan2(ctx.facingZ, ctx.facingX)
		end
	else
		-- No enemy in range (research silent): random direction, see header.
		angle = ctx.rng:next() * TWO_PI
	end
	st.castAngle = angle
	st.castAmount = rt.stats.amount
end

local function fireOne(rt: WeaponRuntime, ctx: WeaponContext, shot: number)
	local stats = rt.stats
	local st = rt.state
	local n = st.castAmount :: number
	local k = shot % n
	local angle = st.castAngle + (k - (n - 1) / 2) * Tuning.fireWandArcStep
	local speed = stats.speed * Tuning.projectileSpeedScale
	local spec = st.spec :: ProjectileSpec
	spec.x = ctx.playerX
	spec.z = ctx.playerZ
	spec.vx = math.cos(angle) * speed
	spec.vz = math.sin(angle) * speed
	spec.radius = Tuning.projectileRadius * stats.area
	spec.lifetime = NO_LIFETIME
	spec.pierce = stats.pierce
	spec.damage = stats.damage
	spec.knockback = stats.knockback
	spec.critChance = stats.critChance
	spec.critMultiplier = stats.critMultiplier
	ctx.spawnProjectile(spec)
end

local FireWand: WeaponBehavior = {
	id = ID,
	create = function(rt: WeaponRuntime)
		local st = rt.state
		st.fire = false
		st.pending = 0
		st.shot = 0
		st.nextShotAt = 0
		st.castAngle = 0
		st.castAmount = 1
		st.spec = {
			weaponId = ID,
			x = 0,
			z = 0,
			vx = 0,
			vz = 0,
			radius = 0,
			lifetime = 0,
			pierce = 1,
			damage = 0,
			knockback = 0,
			critChance = 0,
			critMultiplier = 1,
			visualKind = VISUAL_KIND,
		} :: ProjectileSpec
	end,
	onStatsChanged = function(_rt: WeaponRuntime) end,
	tick = function(rt: WeaponRuntime, ctx: WeaponContext)
		local st = rt.state
		if st.fire then
			beginCast(rt, ctx)
			if st.pending == 0 then
				st.shot = 0
				st.nextShotAt = ctx.time
			end
			st.pending += rt.stats.amount
		end
		while st.pending > 0 and ctx.time >= st.nextShotAt do
			fireOne(rt, ctx, st.shot)
			st.pending -= 1
			st.shot += 1
			st.nextShotAt += rt.stats.projectileInterval
		end
	end,
}

return FireWand
