--!strict
--[[
	server/EnemyManager.luau -- the enemy simulation: structure-of-arrays
	pools, movement, knockback, contact and death. Implements Types.EnemyQuery
	over server/SpatialHash for the weapons.

	Mechanics are the reference's (research/vs/enemies_waves.md):
	  * An enemy spawns with the statline Sim/EnemyStats.scaled resolved for
	    it (health, power, speed in studs/s, knockbackTaken, xp, isBoss) and
	    walks straight at the player at that speed. Enemies do not collide
	    with each other; the reference lets them overlap.
	  * Knockback: "the shipped `knockback` field ... is a knockback-TAKEN
	    multiplier -- HIGHER means knocked back FURTHER ... 0 = immune. The
	    Reaper's -0.5 is negative." (§ Conventions). damage() takes the
	    WEAPON's knockback and applies the enemy's knockbackTaken through
	    Sim/Damage.knockback, so the Ghost (0) never moves and the Reaper
	    (-0.5) is pulled toward the player. The push is an impulse away from
	    the player of Tuning.knockbackScale studs/s per unit, decaying by
	    exp(-Tuning.knockbackDecay * dt) each step (both NOT from research).
	    The shipped per-enemy `maxKnockback` / `deathKnockback` fields carry
	    no stated semantics in the research (§2 lists them bare), so they are
	    deliberately not applied -- reported, not guessed.
	  * Contact: an enemy whose distance to the player is within
	    Tuning.enemyRadius + Tuning.playerRadius reports its `power` through
	    the onContact hook every step. Armor, the invulnerability window and
	    health are the player's rules (Sim/Damage.toPlayer, PlayerSession),
	    not the enemy's, so nothing is gated here.
	  * Death: health <= 0 fires onDeath once with the enemy's xp and isBoss
	    (gem drop and kill count belong to the caller). The handle stays
	    reserved until the next step so lists a weapon is iterating do not
	    see it reused mid-tick; isAlive() is false immediately.
	  * Ring recycle: an enemy farther than Tuning.despawnRadius from the
	    player is moved to a random point on the Tuning.spawnRingRadius ring
	    (docs/ARCHITECTURE.md, Spawner note), keeping health; it is the same
	    enemy, not a new spawn, so no hook fires.

	Order inside step(): free last tick's dead -> recycle or move every
	living enemy -> rebuild the grid at the player -> report contacts. An
	enemy spawned after a step is not in the grid until the next one.

	Performance: parallel numeric/boolean arrays indexed by handle with a
	free list, preallocated at capacity. Nothing per-enemy is a table or an
	Instance and nothing inside step() or the query closures allocates.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.

	Types: src/shared/Types.luau returns nil, which the plain `luau` CLI
	refuses to require, so EnemyQuery / EnemyScaledStats / Rng below restate
	the Types.luau shapes structurally. Keep them in step with Types.luau.
]]

local Tuning = require("../shared/Tuning")
local Damage = require("../shared/Sim/Damage")
local SpatialHash = require("./SpatialHash")

export type EnemyHandle = number

-- Mirrors Types.Rng.
export type Rng = {
	next: (self: Rng) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
}

-- Mirrors Types.EnemyScaledStats.
export type EnemyScaledStats = {
	health: number,
	power: number,
	speed: number,
	knockbackTaken: number,
	xp: number,
	isBoss: boolean,
}

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

export type EnemyManager = {
	capacity: number,
	query: EnemyQuery,
	grid: SpatialHash.SpatialHash,
	-- Structure-of-arrays columns, indexed by handle. Read-only outside this
	-- module; EnemyPresenter.flush reads x, z, alive and facing directly.
	x: { number },
	z: { number },
	alive: { boolean },
	facing: { number }, -- heading in radians (atan2(dz, dx)) of the last move
	-- Hooks, settable at any time. None fire during new().
	onSpawn: ((handle: EnemyHandle, typeId: string) -> ())?,
	onDeath: ((handle: EnemyHandle, typeId: string, x: number, z: number, xp: number, isBoss: boolean) -> ())?,
	onContact: ((handle: EnemyHandle, power: number) -> ())?,

	spawn: (self: EnemyManager, typeId: string, x: number, z: number, stats: EnemyScaledStats) -> EnemyHandle?,
	-- Applies `amount` damage and the WEAPON's knockback (the enemy's
	-- knockbackTaken is applied here). Returns true if this killed it.
	damage: (self: EnemyManager, handle: EnemyHandle, amount: number, weaponKnockback: number) -> boolean,
	-- Kills outright (fires onDeath) / removes silently (no hook, no gem).
	kill: (self: EnemyManager, handle: EnemyHandle) -> (),
	despawn: (self: EnemyManager, handle: EnemyHandle) -> (),
	clear: (self: EnemyManager) -> (),
	step: (self: EnemyManager, dt: number, playerX: number, playerZ: number) -> (),
	-- Per-handle reads; each errors on a handle that is not alive.
	typeId: (self: EnemyManager, handle: EnemyHandle) -> string,
	health: (self: EnemyManager, handle: EnemyHandle) -> number,
	maxHealth: (self: EnemyManager, handle: EnemyHandle) -> number,
	power: (self: EnemyManager, handle: EnemyHandle) -> number,
	speed: (self: EnemyManager, handle: EnemyHandle) -> number,
	knockbackTaken: (self: EnemyManager, handle: EnemyHandle) -> number,
	xp: (self: EnemyManager, handle: EnemyHandle) -> number,
	isBoss: (self: EnemyManager, handle: EnemyHandle) -> boolean,
	aliveCount: (self: EnemyManager) -> number,
}

type Internal = EnemyManager & {
	rng: Rng,
	count: number,
	-- Per-handle columns beyond the public ones.
	hp: { number },
	hpMax: { number },
	speedCol: { number },
	powerCol: { number },
	kbTaken: { number },
	xpCol: { number },
	boss: { boolean },
	typeIdx: { number },
	knockX: { number },
	knockZ: { number },
	-- Free handles (stack) and handles killed since the last step.
	free: { EnemyHandle },
	freeCount: number,
	dead: { EnemyHandle },
	deadCount: number,
	-- Type registry: typeIdx -> id, id -> typeIdx.
	typeIds: { string },
	typeIndex: { [string]: number },
	-- Player position at the last step (knockback direction, recycling).
	playerX: number,
	playerZ: number,
	-- Scratch list for the contact query.
	contactOut: { EnemyHandle },
}

local TWO_PI = 2 * math.pi

local EnemyManager = {}
EnemyManager.__index = EnemyManager

local function checkAlive(s: Internal, handle: EnemyHandle, what: string)
	if not s.alive[handle] then
		error(string.format("EnemyManager.%s: handle %s is not alive", what, tostring(handle)))
	end
end

-- Creates a manager with every column preallocated at `capacity` (default
-- Tuning.enemyCapacity) and a grid of Tuning.spatialCellSize cells over
-- +/- Tuning.spatialGridHalfExtent. `rng` drives recycling and random().
function EnemyManager.new(rng: Rng, capacity: number?): EnemyManager
	local cap = capacity or Tuning.enemyCapacity
	if cap < 1 then
		error("EnemyManager.new: capacity must be >= 1")
	end
	local x = table.create(cap, 0)
	local z = table.create(cap, 0)
	local alive = table.create(cap, false)
	local free = table.create(cap, 0)
	-- Free stack: handle 1 is on top so the first spawns take low handles.
	for h = 1, cap do
		free[h] = cap + 1 - h
	end

	local s: Internal = setmetatable({
		capacity = cap,
		rng = rng,
		count = 0,
		x = x,
		z = z,
		alive = alive,
		facing = table.create(cap, 0),
		hp = table.create(cap, 0),
		hpMax = table.create(cap, 0),
		speedCol = table.create(cap, 0),
		powerCol = table.create(cap, 0),
		kbTaken = table.create(cap, 0),
		xpCol = table.create(cap, 0),
		boss = table.create(cap, false),
		typeIdx = table.create(cap, 0),
		knockX = table.create(cap, 0),
		knockZ = table.create(cap, 0),
		free = free,
		freeCount = cap,
		dead = table.create(cap, 0),
		deadCount = 0,
		typeIds = {},
		typeIndex = {},
		playerX = 0,
		playerZ = 0,
		contactOut = table.create(cap, 0),
		grid = SpatialHash.new(Tuning.spatialCellSize, Tuning.spatialGridHalfExtent, cap, x, z, alive),
		onSpawn = nil,
		onDeath = nil,
		onContact = nil,
		spawn = EnemyManager.spawn,
		damage = EnemyManager.damage,
		kill = EnemyManager.kill,
		despawn = EnemyManager.despawn,
		clear = EnemyManager.clear,
		step = EnemyManager.step,
		typeId = EnemyManager.typeId,
		health = EnemyManager.health,
		maxHealth = EnemyManager.maxHealth,
		power = EnemyManager.power,
		speed = EnemyManager.speed,
		knockbackTaken = EnemyManager.knockbackTaken,
		xp = EnemyManager.xp,
		isBoss = EnemyManager.isBoss,
		aliveCount = EnemyManager.aliveCount,
	}, EnemyManager) :: any

	-- Types.EnemyQuery: plain closures over the columns and the grid.
	local grid = s.grid
	local query: EnemyQuery = {
		count = function(): number
			return s.count
		end,
		isAlive = function(handle: EnemyHandle): boolean
			return alive[handle] == true
		end,
		position = function(handle: EnemyHandle): (number, number)
			return x[handle], z[handle]
		end,
		closest = function(qx: number, qz: number, maxDist: number): EnemyHandle?
			return grid:closest(qx, qz, maxDist)
		end,
		random = function(qx: number, qz: number, maxDist: number, r: Rng): EnemyHandle?
			-- Count, then walk to a uniformly chosen index: one draw, no
			-- allocation, deterministic for a given rng state.
			local n = grid:countInRadius(qx, qz, maxDist)
			if n == 0 then
				return nil
			end
			return grid:nthInRadius(qx, qz, maxDist, r:int(1, n))
		end,
		inRadius = function(qx: number, qz: number, radius: number, out: { EnemyHandle }): number
			return grid:inRadius(qx, qz, radius, out)
		end,
		inBox = function(qx: number, qz: number, halfW: number, halfD: number, out: { EnemyHandle }): number
			return grid:inBox(qx, qz, halfW, halfD, out)
		end,
	}
	s.query = query
	return s
end

-- Takes a handle from the free stack and fills its columns from `stats`
-- (the Sim/EnemyStats.scaled line for this spawn). Returns nil when the
-- pool is full. The new enemy joins the grid at the next step.
function EnemyManager.spawn(
	self: EnemyManager,
	typeId: string,
	x: number,
	z: number,
	stats: EnemyScaledStats
): EnemyHandle?
	local s = self :: Internal
	if s.freeCount == 0 then
		return nil
	end
	if stats.health <= 0 then
		error(string.format("EnemyManager.spawn: %s has non-positive health %s", typeId, tostring(stats.health)))
	end
	local idx = s.typeIndex[typeId]
	if idx == nil then
		idx = #s.typeIds + 1
		s.typeIds[idx] = typeId
		s.typeIndex[typeId] = idx
	end
	local h = s.free[s.freeCount]
	s.freeCount -= 1
	s.x[h] = x
	s.z[h] = z
	s.hp[h] = stats.health
	s.hpMax[h] = stats.health
	s.speedCol[h] = stats.speed
	s.powerCol[h] = stats.power
	s.kbTaken[h] = stats.knockbackTaken
	s.xpCol[h] = stats.xp
	s.boss[h] = stats.isBoss
	s.typeIdx[h] = idx
	s.knockX[h] = 0
	s.knockZ[h] = 0
	-- Face the player it will walk toward.
	s.facing[h] = math.atan2(s.playerZ - z, s.playerX - x)
	s.alive[h] = true
	s.count += 1
	local onSpawn = s.onSpawn
	if onSpawn ~= nil then
		onSpawn(h, typeId)
	end
	return h
end

-- Marks a living enemy dead now; its handle is returned to the free stack
-- at the next step. Fires onDeath when `notify` is true.
local function retire(s: Internal, h: EnemyHandle, notify: boolean)
	s.alive[h] = false
	s.count -= 1
	s.deadCount += 1
	s.dead[s.deadCount] = h
	if notify then
		local onDeath = s.onDeath
		if onDeath ~= nil then
			onDeath(h, s.typeIds[s.typeIdx[h]], s.x[h], s.z[h], s.xpCol[h], s.boss[h])
		end
	end
end

-- Applies `amount` damage and the weapon's knockback; returns true if the
-- enemy died from it. A dead handle is ignored (returns false) so a weapon
-- that hits the same enemy twice in one tick is harmless.
function EnemyManager.damage(self: EnemyManager, handle: EnemyHandle, amount: number, weaponKnockback: number): boolean
	local s = self :: Internal
	if not s.alive[handle] then
		return false
	end
	local hp = s.hp[handle] - amount
	s.hp[handle] = hp
	if weaponKnockback ~= 0 then
		local kb = Damage.knockback(weaponKnockback, s.kbTaken[handle])
		if kb ~= 0 then
			-- Push away from the player (pull toward it when kb < 0).
			local dx = s.x[handle] - s.playerX
			local dz = s.z[handle] - s.playerZ
			local d = math.sqrt(dx * dx + dz * dz)
			if d > 0 then
				dx /= d
				dz /= d
			else
				-- On top of the player: push back along where it came from.
				local f = s.facing[handle]
				dx = -math.cos(f)
				dz = -math.sin(f)
			end
			local impulse = kb * Tuning.knockbackScale
			s.knockX[handle] += dx * impulse
			s.knockZ[handle] += dz * impulse
		end
	end
	if hp <= 0 then
		retire(s, handle, true)
		return true
	end
	return false
end

-- Kills a living enemy outright; onDeath fires as for any death.
function EnemyManager.kill(self: EnemyManager, handle: EnemyHandle)
	local s = self :: Internal
	checkAlive(s, handle, "kill")
	s.hp[handle] = 0
	retire(s, handle, true)
end

-- Removes a living enemy silently: no onDeath, no xp.
function EnemyManager.despawn(self: EnemyManager, handle: EnemyHandle)
	local s = self :: Internal
	checkAlive(s, handle, "despawn")
	retire(s, handle, false)
end

-- Removes every enemy silently and resets the pool.
function EnemyManager.clear(self: EnemyManager)
	local s = self :: Internal
	for h = 1, s.capacity do
		s.alive[h] = false
		s.free[h] = s.capacity + 1 - h
	end
	s.freeCount = s.capacity
	s.deadCount = 0
	s.count = 0
	s.grid:rebuild(s.playerX, s.playerZ)
end

-- One simulation step. See the header for the order of operations.
function EnemyManager.step(self: EnemyManager, dt: number, playerX: number, playerZ: number)
	local s = self :: Internal
	s.playerX = playerX
	s.playerZ = playerZ

	-- 1. Return last tick's dead handles to the free stack.
	local free, dead = s.free, s.dead
	local freeCount = s.freeCount
	for i = 1, s.deadCount do
		freeCount += 1
		free[freeCount] = dead[i]
	end
	s.freeCount = freeCount
	s.deadCount = 0

	-- 2. Recycle far enemies, move the rest.
	local x, z, alive, facing = s.x, s.z, s.alive, s.facing
	local speed, knockX, knockZ = s.speedCol, s.knockX, s.knockZ
	local despawnR2 = Tuning.despawnRadius * Tuning.despawnRadius
	local ringR = Tuning.spawnRingRadius
	local damp = math.exp(-Tuning.knockbackDecay * dt)
	local rng = s.rng
	for h = 1, s.capacity do
		if alive[h] then
			local dx = playerX - x[h]
			local dz = playerZ - z[h]
			local d2 = dx * dx + dz * dz
			if d2 > despawnR2 then
				-- Same enemy, new place on the ring; knockback discarded.
				local a = rng:next() * TWO_PI
				x[h] = playerX + math.cos(a) * ringR
				z[h] = playerZ + math.sin(a) * ringR
				knockX[h] = 0
				knockZ[h] = 0
				facing[h] = a + math.pi
			else
				local d = math.sqrt(d2)
				if d > 0 then
					-- Walk toward the player, never past it.
					local move = speed[h] * dt
					if move > d then
						move = d
					end
					local inv = move / d
					x[h] += dx * inv
					z[h] += dz * inv
					facing[h] = math.atan2(dz, dx)
				end
				local kx, kz = knockX[h], knockZ[h]
				if kx ~= 0 or kz ~= 0 then
					x[h] += kx * dt
					z[h] += kz * dt
					knockX[h] = kx * damp
					knockZ[h] = kz * damp
				end
			end
		end
	end

	-- 3. Grid around the player.
	s.grid:rebuild(playerX, playerZ)

	-- 4. Contacts: everything overlapping the player's contact circle.
	local onContact = s.onContact
	if onContact ~= nil then
		local out = s.contactOut
		local n = s.grid:inRadius(playerX, playerZ, Tuning.enemyRadius + Tuning.playerRadius, out)
		local power = s.powerCol
		for i = 1, n do
			local h = out[i]
			onContact(h, power[h])
		end
	end
end

function EnemyManager.typeId(self: EnemyManager, handle: EnemyHandle): string
	local s = self :: Internal
	checkAlive(s, handle, "typeId")
	return s.typeIds[s.typeIdx[handle]]
end

function EnemyManager.health(self: EnemyManager, handle: EnemyHandle): number
	local s = self :: Internal
	checkAlive(s, handle, "health")
	return s.hp[handle]
end

function EnemyManager.maxHealth(self: EnemyManager, handle: EnemyHandle): number
	local s = self :: Internal
	checkAlive(s, handle, "maxHealth")
	return s.hpMax[handle]
end

function EnemyManager.power(self: EnemyManager, handle: EnemyHandle): number
	local s = self :: Internal
	checkAlive(s, handle, "power")
	return s.powerCol[handle]
end

function EnemyManager.speed(self: EnemyManager, handle: EnemyHandle): number
	local s = self :: Internal
	checkAlive(s, handle, "speed")
	return s.speedCol[handle]
end

function EnemyManager.knockbackTaken(self: EnemyManager, handle: EnemyHandle): number
	local s = self :: Internal
	checkAlive(s, handle, "knockbackTaken")
	return s.kbTaken[handle]
end

function EnemyManager.xp(self: EnemyManager, handle: EnemyHandle): number
	local s = self :: Internal
	checkAlive(s, handle, "xp")
	return s.xpCol[handle]
end

function EnemyManager.isBoss(self: EnemyManager, handle: EnemyHandle): boolean
	local s = self :: Internal
	checkAlive(s, handle, "isBoss")
	return s.boss[handle]
end

-- Living enemies right now (same as query.count()).
function EnemyManager.aliveCount(self: EnemyManager): number
	return (self :: Internal).count
end

return EnemyManager
