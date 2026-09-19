--!strict
--[[
	server/Weapons/Axe.luau -- Types.WeaponBehavior for the axe.

	Oracle: research/vs/weapons.md, Axe. "Thrown upward above the player,
	arcing back down under gravity. First axe goes straight up; extra axes
	are thrown toward the facing direction in progressively wider arcs.
	Character Area is multiplied by 1.3 for this weapon. Ignores Duration."

	  * One cast = rt.stats.amount axes, spaced by rt.stats
	    .projectileInterval (0.2 s). Axe k (k = 0 first) launches with
	    upward speed v = rt.stats.speed * Tuning.projectileSpeedScale along
	    -Z (screen-up, the axis Types.ProjectileSpec.gravity is defined on)
	    plus k * Tuning.axeSpreadStep * v sideways toward the facing side;
	    the runner applies Tuning.axeGravity along +Z. Both Tuning values
	    are NOT from research (the reference arc is pixel-space).
	  * "Toward the facing direction": on the reference's side-view screen
	    facing is left or right, so the sideways component follows the sign
	    of ctx.facingX. Facing exactly along Z (facingX == 0) has no side;
	    +X is used (an engine choice, recorded in the report).
	  * Hitbox radius = Tuning.projectileRadius * rt.stats.area *
	    Tuning.axeAreaMultiplier: the 1.3 is research-stated (weapons.md
	    Axe; OQ-13) and lives in Tuning because no Data field carries it.
	  * Lifetime = rt.stats.duration (shipped 2 s; the Duration stat is
	    ignored per the record's tip, so it is the raw 2 s). Pierce from
	    rt.stats (3 -> 7), crit innate 30% / 2x (weapons.md Conflicts:
	    shipped data), knockback = Tuning.defaults.weaponKnockback (record
	    omits it), all through rt.stats; the runner rolls crit per hit.

	Pure Luau: no Roblox APIs, no Instances, no yields.
]]

local Tuning = require("../../shared/Tuning")
local WeaponRunner = require("../WeaponRunner")

type WeaponRuntime = WeaponRunner.WeaponRuntime
type WeaponContext = WeaponRunner.WeaponContext
type WeaponBehavior = WeaponRunner.WeaponBehavior
type ProjectileSpec = WeaponRunner.ProjectileSpec

local ID = "axe"
local VISUAL_KIND = "axe"

local function fireOne(rt: WeaponRuntime, ctx: WeaponContext, shot: number)
	local stats = rt.stats
	local v = stats.speed * Tuning.projectileSpeedScale
	local side = if ctx.facingX < 0 then -1 else 1
	local spec = rt.state.spec :: ProjectileSpec
	spec.x = ctx.playerX
	spec.z = ctx.playerZ
	spec.vx = side * shot * Tuning.axeSpreadStep * v
	spec.vz = -v
	spec.gravity = Tuning.axeGravity
	spec.radius = Tuning.projectileRadius * stats.area * Tuning.axeAreaMultiplier
	spec.lifetime = stats.duration
	spec.pierce = stats.pierce
	spec.damage = stats.damage
	spec.knockback = stats.knockback
	spec.critChance = stats.critChance
	spec.critMultiplier = stats.critMultiplier
	ctx.spawnProjectile(spec)
end

local Axe: WeaponBehavior = {
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
			gravity = 0,
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
			fireOne(rt, ctx, st.shot)
			st.pending -= 1
			st.shot += 1
			st.nextShotAt += rt.stats.projectileInterval
		end
	end,
}

return Axe
