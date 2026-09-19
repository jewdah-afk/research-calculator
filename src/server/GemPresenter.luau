--!strict
--[[
	server/GemPresenter.luau -- pooled anchored parts for the XP gems.

	The gem half of the presentation seam in docs/ARCHITECTURE.md, the same
	pattern as server/EnemyPresenter and server/ProjectilePool: the
	simulation (server/PickupManager) never touches an Instance; this module
	owns a pool of `capacity` anchored parts created once in new() and moves
	them with a single workspace:BulkMoveTo per flush(). Wire it to the
	pickup manager's hooks:

	  pickups.onGemSpawn   = function(h, tier) gems:show(h, tier) end
	  pickups.onGemTier    = function(h, tier) gems:show(h, tier) end
	  pickups.onGemDespawn = function(h) gems:hide(h) end
	  every Heartbeat:       gems:flush(pickups.x, pickups.z, pickups.alive)

	  Presenter.new(capacity)        warm-up: every part exists after this
	  presenter:show(handle, tier)   part `handle` takes that tier's look
	  presenter:hide(handle)         part parks below the map on next flush
	  presenter:flush(x, z, alive)   one BulkMoveTo for all shown parts

	After new() no Instance is created or destroyed, and no part's CFrame is
	assigned anywhere but inside flush()'s BulkMoveTo. show() only writes
	Color, once per spawn (and again when a cap-merge changes a gem's tier).

	Art is placeholder and ours: a small neon cube per gem hovering at
	Tuning.gemPresenter.floatHeight, hue by tier so the merged top tier reads
	differently from a trash gem. Sizes and the hue step are NOT from
	research; parts park at Tuning.enemyPresenter.hiddenY like the other
	pools.

	This module is Roblox-only (workspace, Instance) and is never required by
	Sim or by the headless tests.
]]

local Tuning = require("../shared/Tuning")

export type Presenter = {
	capacity: number,
	folder: Folder,
	show: (self: Presenter, handle: number, tier: number) -> (),
	hide: (self: Presenter, handle: number) -> (),
	flush: (self: Presenter, x: { number }, z: { number }, alive: { boolean }) -> (),
	destroy: (self: Presenter) -> (),
}

type Internal = Presenter & {
	parts: { BasePart },
	shown: { boolean },
	toPark: { number },
	toParkCount: number,
	moveParts: { BasePart },
	moveCFrames: { CFrame },
	colors: { [number]: Color3 },
	parkedCFrame: CFrame,
}

local Presenter = {}
Presenter.__index = Presenter

local PART_SIZE = Tuning.gemPresenter.partSize
local FLOAT_Y = Tuning.gemPresenter.floatHeight
local HUE_STEP = Tuning.gemPresenter.tierHueStep

-- The tier's placeholder colour, computed once per tier.
local function colorFor(s: Internal, tier: number): Color3
	local color = s.colors[tier]
	if color == nil then
		color = Color3.fromHSV(((tier - 1) * HUE_STEP) % 1, 1, 1)
		s.colors[tier] = color
	end
	return color
end

-- Creates the pool: `capacity` anchored, non-colliding parts parked below
-- the map in a workspace folder. This is the only place Instances are made.
function Presenter.new(capacity: number): Presenter
	if capacity < 1 then
		error("GemPresenter.new: capacity must be >= 1")
	end
	local folder = Instance.new("Folder")
	folder.Name = "Gems"
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
		show = Presenter.show,
		hide = Presenter.hide,
		flush = Presenter.flush,
		destroy = Presenter.destroy,
	}, Presenter) :: any
	return s
end

-- Gives part `handle` the tier's colour; it moves on the next flush. Safe
-- to call again for a gem already shown, which is what a tier change is.
function Presenter.show(self: Presenter, handle: number, tier: number)
	local s = self :: Internal
	if handle < 1 or handle > s.capacity then
		error(string.format("GemPresenter.show: handle %s is outside the pool", tostring(handle)))
	end
	s.parts[handle].Color = colorFor(s, tier)
	s.shown[handle] = true
end

-- Parks part `handle` on the next flush.
function Presenter.hide(self: Presenter, handle: number)
	local s = self :: Internal
	if handle < 1 or handle > s.capacity then
		error(string.format("GemPresenter.hide: handle %s is outside the pool", tostring(handle)))
	end
	if s.shown[handle] then
		s.shown[handle] = false
		s.toParkCount += 1
		s.toPark[s.toParkCount] = handle
	end
end

-- Moves every shown part to its simulation position at float height, and
-- parks the parts hidden since the last flush, in ONE BulkMoveTo.
function Presenter.flush(self: Presenter, x: { number }, z: { number }, alive: { boolean })
	local s = self :: Internal
	local parts, shown = s.parts, s.shown
	local moveParts, moveCFrames = s.moveParts, s.moveCFrames
	local n = 0
	for h = 1, s.capacity do
		if shown[h] and alive[h] then
			n += 1
			moveParts[n] = parts[h]
			moveCFrames[n] = CFrame.new(x[h], FLOAT_Y, z[h])
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
	table.clear(s.moveParts)
	table.clear(s.moveCFrames)
end

return Presenter
