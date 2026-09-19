--!strict
--[[
	server/PickupManager.luau -- the XP gems lying on the floor: the pool,
	the magnet pull and the merge at the cap.

	Oracle: research/vs/core_loop.md §3 ("XP gems", "Gem merging /
	consolidation") and §4 ("Magnet / pickup radius").

	  * Cap and merge. "Max simultaneous gems on the map: 400"; at the cap
	    "The game picks one existing gem, converts it to a red gem, and adds
	    the value of all further gem drops into it"; "Gems do not despawn;
	    value is never lost." So drop() never fails and never discards: past
	    the cap it folds the value into one randomly chosen existing gem,
	    whose tier then follows Sim/Pickups.gemTier -- which returns the open
	    ended top tier for anything above 9, the same tier core_loop.md calls
	    "the tier used for merged/consolidated gems". The 400 itself is
	    Tuning.gemCapacity, which carries the core_loop.md citation.
	  * Magnet. "Base Magnet 30 (world units -- radius in which gems and
	    pickups are collected)". The caller passes the radius in studs
	    (CoreLoop.magnet.base scaled by the player's magnet stat and
	    Tuning.magnetScale); this module only compares against it. Inside the
	    radius a gem is pulled at Tuning.gemPullSpeed and collected within
	    Tuning.gemCollectRadius -- the pull speed and the collect radius are
	    ours (the reference pulls in pixel space), the radius is research.
	  * Growth. "Gem values are scaled by the Growth stat." Gems store the
	    enemy's RAW xp and Sim/Experience.gemValue applies Growth at COLLECT
	    time, so a Growth passive taken mid-run pays on gems already lying on
	    the floor -- the same gems the player can still see.

	Presentation: this module exposes the gem columns (x, z, alive, tier) and
	the onGemSpawn/onGemDespawn/onGemTier hooks, and never touches an
	Instance itself. server/GemPresenter consumes them -- the same
	pooled-part + BulkMoveTo seam as server/EnemyPresenter -- and
	server/GameLoop does the wiring: onGemSpawn/onGemTier -> presenter:show,
	onGemDespawn -> presenter:hide, and one presenter:flush(x, z, alive) per
	Heartbeat. Swapping that presenter out changes nothing here.

	Performance: structure-of-arrays columns indexed by handle with a free
	stack, exactly like server/EnemyManager. 400 gems is small, but the step
	loop still allocates nothing: no closures, no temporary tables, and the
	collect hook is called with plain numbers.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require. The Rng alias below restates
	Types.Rng structurally; keep it in step with Types.luau.
]]

local Tuning = require("../shared/Tuning")
local Experience = require("../shared/Sim/Experience")
local Pickups = require("../shared/Sim/Pickups")

export type GemHandle = number

-- Mirrors Types.Rng.
export type Rng = {
	next: (self: Rng) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
}

export type PickupManager = {
	capacity: number,
	-- Gem columns, indexed by handle. Read-only outside this module; a
	-- presenter reads x, z, alive, tier to place its pooled parts.
	x: { number },
	z: { number },
	xp: { number }, -- RAW xp; Growth is applied on collection
	tier: { number }, -- Sim/Pickups.gemTier of the raw xp
	alive: { boolean },

	-- Presentation hooks, settable at any time. A gem that merges into
	-- another does not spawn, so no hook fires for it; the absorbing gem's
	-- tier may change, which onGemTier reports.
	onGemSpawn: ((handle: GemHandle, tier: number) -> ())?,
	onGemDespawn: ((handle: GemHandle) -> ())?,
	onGemTier: ((handle: GemHandle, tier: number) -> ())?,
	-- A gem reached the player. `xp` is already scaled by Growth.
	onCollect: ((xp: number, handle: GemHandle) -> ())?,

	-- Drops a gem worth `rawXp`. Returns the handle, or nil when the drop
	-- merged into an existing gem at the cap (value is still banked).
	drop: (self: PickupManager, x: number, z: number, rawXp: number) -> GemHandle?,
	-- Pulls every gem inside `magnetRadius` toward the player and collects
	-- the ones that reach them. `growth` is the player's Growth multiplier.
	step: (
		self: PickupManager,
		dt: number,
		playerX: number,
		playerZ: number,
		magnetRadius: number,
		growth: number
	) -> (),
	-- Collects every gem on the map regardless of distance (the Vacuum
	-- floor pickup, pickups_meta.md §1).
	collectAll: (self: PickupManager, growth: number) -> (),
	count: (self: PickupManager) -> number,
	-- Removes every gem silently, no hooks, no XP (end of run).
	clear: (self: PickupManager) -> (),
}

type Internal = PickupManager & {
	rng: Rng,
	live: number,
	free: { GemHandle },
	freeCount: number,
	-- Handles of the living gems, so the cap-merge can pick one without
	-- scanning the whole pool. `slot[handle]` is its index here.
	liveList: { GemHandle },
	slot: { number },
}

local PickupManager = {}
PickupManager.__index = PickupManager

local function setTier(s: Internal, handle: GemHandle, rawXp: number)
	local tier = Pickups.gemTier(rawXp)
	if s.tier[handle] ~= tier then
		s.tier[handle] = tier
		local hook = s.onGemTier
		if hook ~= nil then
			hook(handle, tier)
		end
	end
end

-- Removes a gem from the pool and the live list. Fires no collect hook.
local function release(s: Internal, handle: GemHandle)
	s.alive[handle] = false
	local index = s.slot[handle]
	local last = s.live
	local moved = s.liveList[last]
	s.liveList[index] = moved
	s.slot[moved] = index
	s.liveList[last] = 0
	s.slot[handle] = 0
	s.live = last - 1
	s.freeCount += 1
	s.free[s.freeCount] = handle
	local hook = s.onGemDespawn
	if hook ~= nil then
		hook(handle)
	end
end

function PickupManager.new(rng: Rng, capacity: number?): PickupManager
	local cap = capacity or Tuning.gemCapacity
	if cap < 1 then
		error("PickupManager.new: capacity must be >= 1")
	end
	local free = table.create(cap, 0)
	-- Free stack with handle 1 on top, so the first gems take low handles.
	for h = 1, cap do
		free[h] = cap + 1 - h
	end
	local self: Internal = {
		capacity = cap,
		x = table.create(cap, 0),
		z = table.create(cap, 0),
		xp = table.create(cap, 0),
		tier = table.create(cap, 0),
		alive = table.create(cap, false),
		rng = rng,
		live = 0,
		free = free,
		freeCount = cap,
		liveList = table.create(cap, 0),
		slot = table.create(cap, 0),
		onGemSpawn = nil,
		onGemDespawn = nil,
		onGemTier = nil,
		onCollect = nil,
		drop = PickupManager.drop,
		step = PickupManager.step,
		collectAll = PickupManager.collectAll,
		count = PickupManager.count,
		clear = PickupManager.clear,
	} :: any
	return (setmetatable(self, PickupManager) :: any) :: PickupManager
end

function PickupManager.count(self: PickupManager): number
	return (self :: Internal).live
end

function PickupManager.drop(self: PickupManager, x: number, z: number, rawXp: number): GemHandle?
	local s = self :: Internal
	if s.freeCount == 0 then
		-- At the cap (core_loop.md §3): fold the value into one existing gem
		-- rather than dropping it. Nothing despawns and no value is lost.
		local absorber = s.liveList[s.rng:int(1, s.live)]
		local merged = s.xp[absorber] + rawXp
		s.xp[absorber] = merged
		setTier(s, absorber, merged)
		return nil
	end
	local handle = s.free[s.freeCount]
	s.free[s.freeCount] = 0
	s.freeCount -= 1
	s.x[handle] = x
	s.z[handle] = z
	s.xp[handle] = rawXp
	s.tier[handle] = Pickups.gemTier(rawXp)
	s.alive[handle] = true
	s.live += 1
	s.liveList[s.live] = handle
	s.slot[handle] = s.live
	local hook = s.onGemSpawn
	if hook ~= nil then
		hook(handle, s.tier[handle])
	end
	return handle
end

-- Banks one gem's value and frees it. `growth` scales the raw xp.
local function collect(s: Internal, handle: GemHandle, growth: number)
	local value = Experience.gemValue(s.xp[handle], growth)
	release(s, handle)
	local hook = s.onCollect
	if hook ~= nil then
		hook(value, handle)
	end
end

function PickupManager.step(
	self: PickupManager,
	dt: number,
	playerX: number,
	playerZ: number,
	magnetRadius: number,
	growth: number
)
	local s = self :: Internal
	local pullStep = Tuning.gemPullSpeed * dt
	local magnetSq = magnetRadius * magnetRadius
	local collectSq = Tuning.gemCollectRadius * Tuning.gemCollectRadius
	local x, z = s.x, s.z
	-- Backwards: collect() swaps the last live handle into the slot it frees,
	-- so walking down never skips the gem that moved.
	for i = s.live, 1, -1 do
		local handle = s.liveList[i]
		local dx = playerX - x[handle]
		local dz = playerZ - z[handle]
		local distSq = dx * dx + dz * dz
		if distSq <= collectSq then
			collect(s, handle, growth)
		elseif distSq <= magnetSq then
			local dist = math.sqrt(distSq)
			if dist <= pullStep then
				collect(s, handle, growth)
			else
				local scale = pullStep / dist
				x[handle] += dx * scale
				z[handle] += dz * scale
			end
		end
	end
end

function PickupManager.collectAll(self: PickupManager, growth: number)
	local s = self :: Internal
	for i = s.live, 1, -1 do
		collect(s, s.liveList[i], growth)
	end
end

function PickupManager.clear(self: PickupManager)
	local s = self :: Internal
	for i = s.live, 1, -1 do
		release(s, s.liveList[i])
	end
end

return PickupManager
