--!strict
--[[
	server/Weapons/Knife.luau -- Types.WeaponBehavior for the knife.

	Oracle: research/vs/weapons.md, Knife. "Throws knives in a straight line
	in the FACING direction (movement direction, or last-moved when idle);
	unlimited range. Extra knives fire as a volley spaced by repeatInterval.
	Ignores Duration."

	  * One cast = rt.stats.amount knives, spaced by rt.stats
	    .projectileInterval (0.1 s at Lv1, 0.04 s at Lv8: three "-0.02 s
	    Projectile Interval" steps). Every knife flies along the facing
	    vector (ctx.facingX, ctx.facingZ), which is never zero.
	  * Knife speed = rt.stats.speed * Tuning.projectileSpeedScale studs/s
	    (scale NOT from research). Unlimited range: lifetime is rt.stats
	    .duration, which the record omits (Tuning.defaults.weaponDuration =
	    0 = until pierce is spent), so a knife lives until it has hit
	    rt.stats.pierce enemies (1 -> 3) or left the despawn radius.
	  * Damage, knockback (shipped 0.5), crit (innate 30% / 3x, weapons.md
	    Conflicts: shipped data) all come from rt.stats; the runner rolls
	    crit per hit.

	Pure Luau: no Roblox APIs, no Instances, no yields.
]]

local Tuning = require("../../shared/Tuning")
local WeaponRunner = require("../WeaponRunner")

type WeaponRuntime = WeaponRunner.WeaponRuntime
type WeaponContext = WeaponRunner.WeaponContext
type WeaponBehavior = WeaponRunner.WeaponBehavior
type ProjectileSpec = WeaponRunner.ProjectileSpec

local ID = "knife"
local VISUAL_KIND = "knife"

local function fireOne(rt: WeaponRuntime, ctx: WeaponContext)
	local stats = rt.stats
	local speed = stats.speed * Tuning.projectileSpeedScale
	local spec = rt.state.spec :: ProjectileSpec
	spec.x = ctx.playerX
	spec.z = ctx.playerZ
	spec.vx = ctx.facingX * speed
	spec.vz = ctx.facingZ * speed
	spec.radius = Tuning.projectileRadius * stats.area
	spec.lifetime = stats.duration
	spec.pierce = stats.pierce
	spec.damage = stats.damage
	spec.knockback = stats.knockback
	spec.critChance = stats.critChance
	spec.critMultiplier = stats.critMultiplier
	ctx.spawnProjectile(spec)
end

local Knife: WeaponBehavior = {
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

return Knife
