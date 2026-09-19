--!strict
--[[
	server/EnemyPresenter.luau -- pooled anchored parts for the enemies.

	The swappable presentation seam from docs/ARCHITECTURE.md: the simulation
	(server/EnemyManager) never touches an Instance; this module owns a pool
	of `capacity` anchored parts created once in new() and moves them with a
	single workspace:BulkMoveTo per flush(), relying on Roblox replication.
	Replace this module with one over the place's own renderer, keeping the
	same four functions, and nothing in the mechanics changes.

	  Presenter.new(capacity)          warm-up: every part exists after this
	  presenter:show(handle, typeId)   part `handle` takes typeId's look
	  presenter:hide(handle)           part parks below the map on next flush
	  presenter:flush(x, z, alive, facing)   one BulkMoveTo for all shown parts

	After new() no Instance is created or destroyed, and no part's CFrame is
	assigned anywhere but inside flush()'s BulkMoveTo. show() only writes
	Size and Color, once per spawn.

	Art is placeholder and ours: a cube per enemy, hue by type index (so
	every type reads as a different colour), bosses Tuning.enemyPresenter
	.bossPartScale times larger. Sizes and the parking height live in
	Tuning.enemyPresenter and are NOT from research.

	This module is Roblox-only (workspace, Instance) and is never required by
	Sim or by the headless tests.
]]

local Tuning = require("../shared/Tuning")
local EnemyStats = require("../shared/Sim/EnemyStats")

export type Presenter = {
	capacity: number,
	folder: Folder,
	show: (self: Presenter, handle: number, typeId: string) -> (),
	hide: (self: Presenter, handle: number) -> (),
	flush: (self: Presenter, x: { number }, z: { number }, alive: { boolean }, facing: { number }) -> (),
	destroy: (self: Presenter) -> (),
}

type Look = { size: Vector3, color: Color3 }

type Internal = Presenter & {
	parts: { BasePart },
	shown: { boolean },
	-- Handles currently shown, densely packed, so flush() walks the live
	-- enemies instead of the whole pool. `slot[handle]` is its index here.
	shownList: { number },
	shownCount: number,
	slot: { number },
	-- Half of each part's Y size, written in show(); avoids reading the
	-- engine's part.Size property in the per-enemy flush loop.
	halfHeights: { number },
	-- Handles hidden since the last flush; parked by that flush.
	toPark: { number },
	toParkCount: number,
	-- Reused BulkMoveTo argument lists.
	moveParts: { BasePart },
	moveCFrames: { CFrame },
	looks: { [string]: Look },
	parkedCFrame: CFrame,
}

local Presenter = {}
Presenter.__index = Presenter

local PART_SIZE = Tuning.enemyPresenter.partSize
local BOSS_SIZE = PART_SIZE * Tuning.enemyPresenter.bossPartScale

-- The type's placeholder look, computed once per typeId: hue from its
-- position in EnemyStats.ids, size from isBoss.
local function lookFor(s: Internal, typeId: string): Look
	local look = s.looks[typeId]
	if look ~= nil then
		return look
	end
	local ids = EnemyStats.ids
	local index = 0
	for i, id in ids do
		if id == typeId then
			index = i
			break
		end
	end
	local hue = if #ids > 0 then (index - 1) / #ids else 0
	local isBoss = EnemyStats.scaled(typeId, 0, 1, 1).isBoss
	local edge = if isBoss then BOSS_SIZE else PART_SIZE
	look = {
		size = Vector3.new(edge, edge, edge),
		color = Color3.fromHSV(hue, 1, 1),
	}
	s.looks[typeId] = look
	return look
end

-- Creates the pool: `capacity` anchored, non-colliding parts parked below
-- the map in a workspace folder. This is the only place Instances are made.
function Presenter.new(capacity: number): Presenter
	if capacity < 1 then
		error("EnemyPresenter.new: capacity must be >= 1")
	end
	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
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
		shownList = table.create(capacity, 0),
		shownCount = 0,
		slot = table.create(capacity, 0),
		halfHeights = table.create(capacity, PART_SIZE / 2),
		toPark = table.create(capacity, 0),
		toParkCount = 0,
		moveParts = table.create(capacity),
		moveCFrames = table.create(capacity),
		looks = {},
		parkedCFrame = parkedCFrame,
		show = Presenter.show,
		hide = Presenter.hide,
		flush = Presenter.flush,
		destroy = Presenter.destroy,
	}, Presenter) :: any
	return s
end

-- Gives part `handle` the look of `typeId`; it moves on the next flush.
function Presenter.show(self: Presenter, handle: number, typeId: string)
	local s = self :: Internal
	if handle < 1 or handle > s.capacity then
		error(string.format("EnemyPresenter.show: handle %s is outside the pool", tostring(handle)))
	end
	local part = s.parts[handle]
	local look = lookFor(s, typeId)
	part.Size = look.size
	part.Color = look.color
	s.halfHeights[handle] = look.size.Y / 2
	if not s.shown[handle] then
		s.shown[handle] = true
		s.shownCount += 1
		s.shownList[s.shownCount] = handle
		s.slot[handle] = s.shownCount
	end
end

-- Parks part `handle` on the next flush.
function Presenter.hide(self: Presenter, handle: number)
	local s = self :: Internal
	if handle < 1 or handle > s.capacity then
		error(string.format("EnemyPresenter.hide: handle %s is outside the pool", tostring(handle)))
	end
	if s.shown[handle] then
		s.shown[handle] = false
		-- Swap-remove from the dense live list.
		local index = s.slot[handle]
		local last = s.shownCount
		local moved = s.shownList[last]
		s.shownList[index] = moved
		s.slot[moved] = index
		s.shownList[last] = 0
		s.slot[handle] = 0
		s.shownCount = last - 1
		s.toParkCount += 1
		s.toPark[s.toParkCount] = handle
	end
end

-- Moves every shown part to its simulation position (parts sit on the
-- ground: centre at half their height) facing its heading, and parks the
-- parts hidden since the last flush, in ONE BulkMoveTo.
function Presenter.flush(self: Presenter, x: { number }, z: { number }, alive: { boolean }, facing: { number })
	local s = self :: Internal
	local parts, halfHeights = s.parts, s.halfHeights
	local shownList = s.shownList
	local moveParts, moveCFrames = s.moveParts, s.moveCFrames
	local n = 0
	for i = 1, s.shownCount do
		local h = shownList[i]
		if alive[h] then
			n += 1
			moveParts[n] = parts[h]
			-- Heading is atan2(dz, dx) in the XZ plane; a part's look vector
			-- is -Z, so rotate about Y by -(heading) - pi/2 to face it. With
			-- t = -heading - pi/2, cos(t) = -sin(heading) and
			-- sin(t) = -cos(heading), so the Y rotation's columns are
			-- right = (cos t, 0, -sin t) and back = (sin t, 0, cos t). One
			-- fromMatrix builds the whole matrix in a single allocation.
			local f = facing[h]
			local sf, cf = math.sin(f), math.cos(f)
			moveCFrames[n] = CFrame.fromMatrix(
				Vector3.new(x[h], halfHeights[h], z[h]),
				Vector3.new(-sf, 0, cf),
				Vector3.yAxis,
				Vector3.new(-cf, 0, -sf)
			)
		end
	end
	local parked = s.parkedCFrame
	for i = 1, s.toParkCount do
		n += 1
		moveParts[n] = parts[s.toPark[i]]
		moveCFrames[n] = parked
	end
	s.toParkCount = 0
	-- Trim the reused lists to exactly n entries (BulkMoveTo needs equal
	-- lengths); table.clear would drop their capacity.
	for i = #moveParts, n + 1, -1 do
		moveParts[i] = nil
		moveCFrames[i] = nil
	end
	if n > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Tears the pool down (end of run / hot reload). The only Destroy call.
function Presenter.destroy(self: Presenter)
	local s = self :: Internal
	s.folder:Destroy()
	table.clear(s.parts)
	table.clear(s.shownList)
	s.shownCount = 0
	table.clear(s.moveParts)
	table.clear(s.moveCFrames)
end

return Presenter
