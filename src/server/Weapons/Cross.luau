--!strict
--[[
	server/Weapons/Cross.luau -- Types.WeaponBehavior for the cross.

	Oracle: research/vs/weapons.md, Cross. "Spinning cross thrown at the
	CLOSEST enemy; it decelerates, boomerangs back through the player and
	continues off screen. Damages every enemy it contacts on both legs.
	Speed sets how far out it travels before reversing. Ignores Duration."

	  * One cast = rt.stats.amount crosses, spaced by rt.stats
	    .projectileInterval (0.1 s). Each cross re-queries ctx.query.closest
	    (unlimited range) when thrown.
	  * Flight: launch speed v0 = rt.stats.speed * Tuning
	    .projectileSpeedScale along the launch line, then constant
	    deceleration Tuning.crossDeceleration (NOT from research) applied
	    here every tick through ctx.setProjectileVelocity: v(t) = v0 - a t.
	    v goes negative, so the cross comes back through the player and keeps
	    going until the runner's despawn radius. Outward distance =
	    v0^2 / (2 a), so "Speed sets how far out it travels" holds.
	  * Pierce -1 (unbounded) with returnsToPlayer = true: the runner hits
	    each enemy once per leg and forgets the hit list when the velocity
	    reverses, which is "damages every enemy it contacts on both legs".
	    The record omits pierce (weapons.md: "Weapons whose record omits
	    'penetrating' are area-of-effect or infinite-pierce in behaviour").
	  * Hitbox radius = Tuning.projectileRadius * rt.stats.area (1 -> 1.2).
	    Damage from rt.stats; knockback and crit are the record's omissions
	    resolved by Tuning.defaults through WeaponLevels; lifetime is
	    rt.stats.duration (omitted -> 0 = no timeout).
	  * Research is silent on a throw with no living enemy. Choice: random
	    direction (ctx.rng), as for the Magic Wand; recorded in the report.
	  * Flight records are pooled and never allocate after warm-up; a record
	    whose projectile is no longer alive is dropped on the next tick
	    (handles are not reused until every behaviour has ticked once).

	Pure Luau: no Roblox APIs, no Instances, no yields.
]]

local Tuning = require("../../shared/Tuning")
local WeaponRunner = require("../WeaponRunner")

type WeaponRuntime = WeaponRunner.WeaponRuntime
type WeaponContext = WeaponRunner.WeaponContext
type WeaponBehavior = WeaponRunner.WeaponBehavior
type ProjectileSpec = WeaponRunner.ProjectileSpec

type Flight = { handle: number, dx: number, dz: number, v0: number, t: number }

local ID = "cross"
local VISUAL_KIND = "cross"
local TWO_PI = 2 * math.pi

local function fireOne(rt: WeaponRuntime, ctx: WeaponContext)
	local stats = rt.stats
	local st = rt.state
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
			dirX = ctx.facingX
			dirZ = ctx.facingZ
		end
	else
		-- No enemy alive (research silent): random direction, see header.
		local a = ctx.rng:next() * TWO_PI
		dirX = math.cos(a)
		dirZ = math.sin(a)
	end
	local v0 = stats.speed * Tuning.projectileSpeedScale
	local spec = st.spec :: ProjectileSpec
	spec.x = px
	spec.z = pz
	spec.vx = dirX * v0
	spec.vz = dirZ * v0
	spec.radius = Tuning.projectileRadius * stats.area
	spec.lifetime = stats.duration
	spec.damage = stats.damage
	spec.knockback = stats.knockback
	spec.critChance = stats.critChance
	spec.critMultiplier = stats.critMultiplier
	local handle = ctx.spawnProjectile(spec)
	if handle == nil then
		return
	end
	local flights = st.flights :: { Flight }
	local idx = st.flightCount + 1
	local flight = flights[idx]
	if flight == nil then
		flight = { handle = 0, dx = 0, dz = 0, v0 = 0, t = 0 }
		flights[idx] = flight
	end
	flight.handle = handle
	flight.dx = dirX
	flight.dz = dirZ
	flight.v0 = v0
	flight.t = 0
	st.flightCount = idx
end

-- Advances every live cross along its deceleration curve and drops the
-- records of crosses the runner has despawned.
local function steer(rt: WeaponRuntime, ctx: WeaponContext)
	local st = rt.state
	local flights = st.flights :: { Flight }
	local count = st.flightCount :: number
	local a = Tuning.crossDeceleration
	local i = 1
	while i <= count do
		local flight = flights[i]
		if ctx.projectileAlive(flight.handle) then
			flight.t += ctx.dt
			local v = flight.v0 - a * flight.t
			ctx.setProjectileVelocity(flight.handle, flight.dx * v, flight.dz * v)
			i += 1
		else
			flights[i] = flights[count]
			flights[count] = flight
			count -= 1
		end
	end
	st.flightCount = count
end

local Cross: WeaponBehavior = {
	id = ID,
	create = function(rt: WeaponRuntime)
		local st = rt.state
		st.fire = false
		st.pending = 0
		st.shot = 0
		st.nextShotAt = 0
		st.flights = {} :: { Flight }
		st.flightCount = 0
		st.spec = {
			weaponId = ID,
			x = 0,
			z = 0,
			vx = 0,
			vz = 0,
			radius = 0,
			lifetime = 0,
			pierce = -1,
			damage = 0,
			knockback = 0,
			critChance = 0,
			critMultiplier = 1,
			returnsToPlayer = true,
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
		-- AFTER this tick's throws, so a cross launched on this frame has
		-- already spent one tick of deceleration when the runner moves it:
		-- v(t) = v0 - a t from the first simulated frame onward.
		steer(rt, ctx)
	end,
}

return Cross
