--!strict
--[[
	server/Weapons/MagicWand.luau -- Types.WeaponBehavior for the magic wand.

	Oracle: research/vs/weapons.md, Magic Wand. "Fires a magic missile at
	the CLOSEST enemy; unlimited range, retargets every shot. Extra
	projectiles fire in quick succession (repeatInterval 0.1s) at nearest
	targets. Ignores Duration."

	  * One cast = rt.stats.amount missiles, spaced by rt.stats
	    .projectileInterval (0.1 s). Each missile re-queries
	    ctx.query.closest with maxDist math.huge (unlimited range) when it is
	    fired, so a volley retargets shot by shot.
	  * Missile speed = rt.stats.speed * Tuning.projectileSpeedScale studs/s
	    (the scale is NOT from research); it despawns after rt.stats.pierce
	    hits (1 at Lv1-6, 2 from Lv7: weapons.md Lv7 "+1 Pierce") or past
	    the despawn radius. Lifetime is rt.stats.duration, which the record
	    omits (Tuning.defaults.weaponDuration = 0 = until pierce is spent).
	  * Damage, knockback (record omits it: Tuning.defaults.weaponKnockback),
	    crit chance and multiplier (record omits them: defaults 0 / 1) all
	    come from rt.stats; the runner rolls crit per hit.
	  * Research is silent on a cast with no living enemy. Choice: the
	    missile flies in a uniformly random direction (ctx.rng) rather than
	    being withheld, so the cadence and pool usage stay identical whether
	    or not a target exists. Recorded in the final report.

	Pure Luau: no Roblox APIs, no Instances, no yields.
]]

local Tuning = require("../../shared/Tuning")
local WeaponRunner = require("../WeaponRunner")

type WeaponRuntime = WeaponRunner.WeaponRuntime
type WeaponContext = WeaponRunner.WeaponContext
type WeaponBehavior = WeaponRunner.WeaponBehavior
type ProjectileSpec = WeaponRunner.ProjectileSpec

local ID = "magic_wand"
local VISUAL_KIND = "missile"
local TWO_PI = 2 * math.pi

local function fireOne(rt: WeaponRuntime, ctx: WeaponContext)
	local stats = rt.stats
	local px, pz = ctx.playerX, ctx.playerZ
	local dirX, dirZ
	local target = ctx.query.closest(px, pz, math.huge)
	if target ~= nil then
		local tx, tz = ctx.query.position(target)
		local dx = tx - px
		local dz = tz - pz
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 0 then
			dirX = dx / len
			dirZ = dz / len
		else
			-- On top of the target: any direction hits it; use facing.
			dirX = ctx.facingX
			dirZ = ctx.facingZ
		end
	else
		-- No enemy alive (research silent): random direction, see header.
		local a = ctx.rng:next() * TWO_PI
		dirX = math.cos(a)
		dirZ = math.sin(a)
	end
	local speed = stats.speed * Tuning.projectileSpeedScale
	local spec = rt.state.spec :: ProjectileSpec
	spec.x = px
	spec.z = pz
	spec.vx = dirX * speed
	spec.vz = dirZ * speed
	spec.radius = Tuning.projectileRadius * stats.area
	spec.lifetime = stats.duration
	spec.pierce = stats.pierce
	spec.damage = stats.damage
	spec.knockback = stats.knockback
	spec.critChance = stats.critChance
	spec.critMultiplier = stats.critMultiplier
	ctx.spawnProjectile(spec)
end

local MagicWand: WeaponBehavior = {
	id = ID,
	create = function(rt: WeaponRuntime)
		local st = rt.state
		st.fire = false
		st.pending = 0
		st.shot = 0
		st.nextShotAt = 0
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
			if st.pending == 0 then
				st.shot = 0
				st.nextShotAt = ctx.time
			end
			st.pending += rt.stats.amount
		end
		while st.pending > 0 and ctx.time >= st.nextShotAt do
			fireOne(rt, ctx)
			st.pending -= 1
			st.shot += 1
			st.nextShotAt += rt.stats.projectileInterval
		end
	end,
}

return MagicWand
