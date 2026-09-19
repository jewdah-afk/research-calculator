--!strict
--[[
	server/Weapons/Whip.luau -- Types.WeaponBehavior for the whip.

	Oracle: research/vs/weapons.md, Whip. "Slashes horizontally from the
	character's torso in the facing direction; area-of-effect, passes through
	all enemies in the rectangle. Extra slashes from Amount alternate between
	firing toward and away from the facing direction, each placed
	progressively higher. Ignores Speed and Duration."

	  * One cast = rt.stats.amount slashes, spaced by rt.stats
	    .projectileInterval (0.1 s, base table). Slash k (k = 0 first) goes
	    toward facing when k is even and away from it when k is odd.
	  * A slash is an instant rectangular hitbox reaching outward from the
	    player along its direction, Tuning.whipHalfLength / whipHalfWidth
	    studs (NOT from research, sprite-sized in the reference) scaled by
	    rt.stats.area. Every enemy whose contact circle overlaps it is hit
	    once per slash.
	  * Crit is rolled ONCE per slash from rt.stats (innate 20% / 2x, weapons
	    .md Conflicts: shipped data over the wiki's Arcana figure) and every
	    enemy in that slash takes the same rolled damage.
	  * Knockback is rt.stats.knockback (the record omits it; Tuning.defaults
	    .weaponKnockback through WeaponLevels).
	  * Speed and duration never enter (WeaponLevels honours the shipped
	    `Ignores:` tip); no projectile is spawned.
	  * "each placed progressively higher": the reference offsets alternate
	    slashes vertically on a side-view screen. In the top-down XZ arena
	    that offset has no equivalent and is not modelled (research gives no
	    magnitude; it would be an invented number).

	Pure Luau: no Roblox APIs, no Instances, no yields.
]]

local Tuning = require("../../shared/Tuning")
local Damage = require("../../shared/Sim/Damage")
local WeaponRunner = require("../WeaponRunner")

type WeaponRuntime = WeaponRunner.WeaponRuntime
type WeaponContext = WeaponRunner.WeaponContext
type WeaponBehavior = WeaponRunner.WeaponBehavior
type VisualSpec = WeaponRunner.VisualSpec

local ID = "whip"
local VISUAL_KIND = "slash"

-- One slash of the cast: hits everything in the rectangle once.
local function slash(rt: WeaponRuntime, ctx: WeaponContext, shot: number)
	local stats = rt.stats
	local st = rt.state
	-- Even shots go toward facing, odd shots away from it.
	local side = if shot % 2 == 0 then 1 else -1
	local dirX = ctx.facingX * side
	local dirZ = ctx.facingZ * side
	local halfL = Tuning.whipHalfLength * stats.area
	local halfW = Tuning.whipHalfWidth * stats.area
	local cx = ctx.playerX + dirX * halfL
	local cz = ctx.playerZ + dirZ * halfL

	-- Candidates from the bounding square of the rotated rectangle, then
	-- the exact rectangle test in the slash's own axes.
	local reach = math.sqrt(halfL * halfL + halfW * halfW) + Tuning.enemyRadius
	local out = st.out :: { number }
	local n = ctx.query.inBox(cx, cz, reach, reach, out)
	local amount = Damage.roll(stats.damage, stats.critChance, stats.critMultiplier, ctx.rng)
	local alongMax = halfL + Tuning.enemyRadius
	local acrossMax = halfW + Tuning.enemyRadius
	for i = 1, n do
		local enemy = out[i]
		local ex, ez = ctx.query.position(enemy)
		local dx = ex - cx
		local dz = ez - cz
		local along = dx * dirX + dz * dirZ
		local across = -dx * dirZ + dz * dirX
		if math.abs(along) <= alongMax and math.abs(across) <= acrossMax then
			ctx.damage(enemy, amount, stats.knockback, ID)
		end
	end

	local visual = st.visual :: VisualSpec
	visual.x = cx
	visual.z = cz
	visual.radius = halfL
	visual.angle = math.atan2(dirZ, dirX)
	visual.duration = stats.projectileInterval
	ctx.visual(visual)
end

local Whip: WeaponBehavior = {
	id = ID,
	create = function(rt: WeaponRuntime)
		local st = rt.state
		st.fire = false
		st.pending = 0
		st.shot = 0
		st.nextShotAt = 0
		st.out = table.create(Tuning.enemyCapacity, 0)
		st.visual = {
			kind = VISUAL_KIND,
			x = 0,
			z = 0,
			radius = 0,
			angle = 0,
			duration = 0,
			weaponId = ID,
		} :: VisualSpec
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
			slash(rt, ctx, st.shot)
			st.pending -= 1
			st.shot += 1
			st.nextShotAt += rt.stats.projectileInterval
		end
	end,
}

return Whip
