--!strict
--[[
	server/ProjectilePool.luau -- pooled anchored parts for the projectiles.

	The projectile half of the presentation seam in docs/ARCHITECTURE.md
	("Projectiles follow the same pattern through ProjectilePool"): the
	simulation (server/WeaponRunner) never touches an Instance; this module
	owns a pool of `capacity` anchored parts created once in new() and moves
	them with a single workspace:BulkMoveTo per flush(), relying on Roblox
	replication. Wire it to the runner's hooks:

	  runner.onProjectileSpawn   = function(h, weaponId) pool:show(h, weaponId) end
	  runner.onProjectileDespawn = function(h) pool:hide(h) end
	  every Heartbeat:             pool:flush(runner.x, runner.z, runner.alive, runner.heading)

	  Pool.new(capacity)               warm-up: every part exists after this
	  pool:show(handle, weaponId)      part `handle` takes the weapon's look
	  pool:hide(handle)                part parks below the map on next flush
	  pool:flush(x, z, alive, heading) one BulkMoveTo for all shown parts

	After new() no Instance is created or destroyed, and no part's CFrame is
	assigned anywhere but inside flush()'s BulkMoveTo. show() only writes
	Color, once per spawn.

	Art is placeholder and ours: a small cube per projectile, hue by the
	weapon's position among the Data weapon ids, flying at Tuning
	.projectilePresenter.flightHeight. Sizes are NOT from research; parts
	park at Tuning.enemyPresenter.hiddenY like the enemy pool.

	This module is Roblox-only (workspace, Instance) and is never required by
	Sim or by the headless tests.
]]

local Tuning = require("../shared/Tuning")
local Weapons = require("../shared/Data/Weapons")

export type Pool = {
	capacity: number,
	folder: Folder,
	show: (self: Pool, handle: number, weaponId: string) -> (),
	hide: (self: Pool, handle: number) -> (),
	flush: (self: Pool, x: { number }, z: { number }, alive: { boolean }, heading: { number }) -> (),
	destroy: (self: Pool) -> (),
}

type Internal = Pool & {
	parts: { BasePart },
	shown: { boolean },
	toPark: { number },
	toParkCount: number,
	moveParts: { BasePart },
	moveCFrames: { CFrame },
	colors: { [string]: Color3 },
	parkedCFrame: CFrame,
}

local Pool = {}
Pool.__index = Pool

local PART_SIZE = Tuning.projectilePresenter.partSize
local FLIGHT_Y = Tuning.projectilePresenter.flightHeight

-- Weapon ids in a fixed order so each weapon gets a stable hue.
local weaponIds: { string } = {}
for id in Weapons.data do
	table.insert(weaponIds, id)
end
table.sort(weaponIds)

local function colorFor(s: Internal, weaponId: string): Color3
	local cached: Color3? = s.colors[weaponId]
	if cached ~= nil then
		return cached
	end
	local index = 0
	for i, id in weaponIds do
		if id == weaponId then
			index = i
			break
		end
	end
	local hue = if #weaponIds > 0 then (index - 1) / #weaponIds else 0
	color = Color3.fromHSV(hue, 1, 1)
	s.colors[weaponId] = color
	return color
end

-- Creates the pool: `capacity` anchored, non-colliding parts parked below
-- the map in a workspace folder. This is the only place Instances are made.
function Pool.new(capacity: number): Pool
	if capacity < 1 then
		error("ProjectilePool.new: capacity must be >= 1")
	end
	local folder = Instance.new("Folder")
	folder.Name = "Projectiles"
	local parkedCFrame = CFrame.new(0, Tuning.enemyPresenter.hiddenY, 0)
	local parts = table.create(capacity)
	for h = 1, capacity do
		local part = Instance.new("Part")
		part.Name = tostring(h)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Material = Enum.Material.Neon
		part.Size = Vector3.new(PART_SIZE, PART_SIZE, PART_SIZE)
		part.CFrame = parkedCFrame
		part.Parent = folder
		parts[h] = part
	end
	folder.Parent = workspace

	local s: Internal = setmetatable({
		capacity = capacity,
		folder = folder,
		parts = parts,
		shown = table.create(capacity, false),
		toPark = table.create(capacity, 0),
		toParkCount = 0,
		moveParts = table.create(capacity),
		moveCFrames = table.create(capacity),
		colors = {},
		parkedCFrame = parkedCFrame,
		show = Pool.show,
		hide = Pool.hide,
		flush = Pool.flush,
		destroy = Pool.destroy,
	}, Pool) :: any
	return s
end

-- Gives part `handle` the weapon's colour; it moves on the next flush.
function Pool.show(self: Pool, handle: number, weaponId: string)
	local s = self :: Internal
	if handle < 1 or handle > s.capacity then
		error(string.format("ProjectilePool.show: handle %s is outside the pool", tostring(handle)))
	end
	s.parts[handle].Color = colorFor(s, weaponId)
	s.shown[handle] = true
end

-- Parks part `handle` on the next flush.
function Pool.hide(self: Pool, handle: number)
	local s = self :: Internal
	if handle < 1 or handle > s.capacity then
		error(string.format("ProjectilePool.hide: handle %s is outside the pool", tostring(handle)))
	end
	if s.shown[handle] then
		s.shown[handle] = false
		s.toParkCount += 1
		s.toPark[s.toParkCount] = handle
	end
end

-- Moves every shown part to its simulation position at flight height,
-- facing its heading, and parks the parts hidden since the last flush, in
-- ONE BulkMoveTo.
function Pool.flush(self: Pool, x: { number }, z: { number }, alive: { boolean }, heading: { number })
	local s = self :: Internal
	local parts, shown = s.parts, s.shown
	local moveParts, moveCFrames = s.moveParts, s.moveCFrames
	local n = 0
	for h = 1, s.capacity do
		if shown[h] and alive[h] then
			n += 1
			moveParts[n] = parts[h]
			-- Heading is atan2(vz, vx) in the XZ plane; a part's look vector
			-- is -Z, so rotate about Y by -(heading) - pi/2 to face it.
			moveCFrames[n] = CFrame.new(x[h], FLIGHT_Y, z[h]) * CFrame.Angles(0, -heading[h] - math.pi / 2, 0)
		end
	end
	local parked = s.parkedCFrame
	for i = 1, s.toParkCount do
		n += 1
		moveParts[n] = parts[s.toPark[i]]
		moveCFrames[n] = parked
	end
	s.toParkCount = 0
	for i = #moveParts, n + 1, -1 do
		moveParts[i] = nil
		moveCFrames[i] = nil
	end
	if n > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Tears the pool down (end of run / hot reload). The only Destroy call.
function Pool.destroy(self: Pool)
	local s = self :: Internal
	s.folder:Destroy()
	table.clear(s.parts)
	table.clear(s.moveParts)
	table.clear(s.moveCFrames)
end

return Pool
