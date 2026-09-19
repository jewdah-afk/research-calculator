--!strict
--[[
	server/SpatialHash.luau -- uniform grid over the live enemy positions.

	Answers the spatial half of Types.EnemyQuery (inRadius / inBox / closest,
	plus the count/nth pair EnemyManager uses for `random`) by consulting only
	the grid cells that overlap the query area, never the whole enemy list.

	Layout (all preallocated in `new`; nothing after it allocates):
	  * A square grid of `side x side` cells, cell edge `cellSize` studs,
	    centred on the origin passed to `rebuild` (the player), covering
	    [-halfExtent, +halfExtent) on both axes. Positions outside are clamped
	    into the edge cells, so far enemies are still found, only slower.
	  * Counting sort: `cellCount[c]` -> prefix sums `cellStart[c]` -> the
	    handle list `sorted`, where cell c owns sorted[cellStart[c] ..
	    cellStart[c + 1] - 1]. Rebuilt in O(cells + enemies) each step.
	  * `x`, `z`, `alive` are the caller's structure-of-arrays columns; the
	    grid only reads them. Dead handles are skipped at rebuild, so a query
	    between rebuilds may still return a handle killed since the last
	    rebuild; every query therefore re-checks `alive`.

	Every distance test is exact (squared distances against the real
	positions), so clamping only costs candidates, never correctness. The one
	place clamping could mislead is closest()'s ring early-exit when the query
	point itself lies outside the grid; that case falls back to an exact scan.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.
	Every number here is 0, 1, -1 or 2 or comes from the constructor; the
	engine constants live in Tuning (spatialCellSize, spatialGridHalfExtent).
]]

export type Handle = number

export type SpatialHash = {
	-- Configuration.
	cellSize: number,
	halfExtent: number,
	side: number, -- cells per axis
	capacity: number, -- highest handle the columns may hold
	-- Diagnostic: candidates examined by queries since the last reset. Tests
	-- use it to prove queries touch only nearby cells (PERF-05).
	candidatesVisited: number,
	-- Origin of the grid's [-halfExtent, +halfExtent) window (the player at
	-- the last rebuild).
	originX: number,
	originZ: number,

	rebuild: (self: SpatialHash, originX: number, originZ: number) -> (),
	inRadius: (self: SpatialHash, x: number, z: number, radius: number, out: { Handle }) -> number,
	inBox: (self: SpatialHash, x: number, z: number, halfW: number, halfD: number, out: { Handle }) -> number,
	closest: (self: SpatialHash, x: number, z: number, maxDist: number) -> Handle?,
	countInRadius: (self: SpatialHash, x: number, z: number, radius: number) -> number,
	-- The k-th (1-based, in cell order) living handle within radius; nil if
	-- fewer than k. countInRadius + nthInRadius give a uniform pick.
	nthInRadius: (self: SpatialHash, x: number, z: number, radius: number, k: number) -> Handle?,
}

type Internal = SpatialHash & {
	x: { number },
	z: { number },
	alive: { boolean },
	cellCount: { number },
	cellStart: { number }, -- side*side + 1 entries
	cellFill: { number },
	cellOf: { number }, -- per handle, cell index at the last rebuild
	sorted: { Handle },
	sortedCount: number,
}

local SpatialHash = {}
SpatialHash.__index = SpatialHash

-- Clamped cell coordinate (0-based) along one axis.
local function axisCell(self: Internal, world: number, origin: number): number
	local c = math.floor((world - origin + self.halfExtent) / self.cellSize)
	if c < 0 then
		return 0
	end
	local last = self.side - 1
	if c > last then
		return last
	end
	return c
end

-- True when (x, z) lies inside the grid window (before clamping).
local function inside(self: Internal, x: number, z: number): boolean
	local hx = x - self.originX
	local hz = z - self.originZ
	local e = self.halfExtent
	return hx >= -e and hx < e and hz >= -e and hz < e
end

-- Creates a grid over the caller's columns. `capacity` is the largest handle
-- index the columns can hold. All storage is allocated here, once.
function SpatialHash.new(
	cellSize: number,
	halfExtent: number,
	capacity: number,
	x: { number },
	z: { number },
	alive: { boolean }
): SpatialHash
	if cellSize <= 0 or halfExtent <= 0 or capacity < 1 then
		error("SpatialHash.new: cellSize and halfExtent must be positive and capacity >= 1")
	end
	local side = math.ceil((halfExtent * 2) / cellSize)
	local cells = side * side
	local self: Internal = setmetatable({
		cellSize = cellSize,
		halfExtent = halfExtent,
		side = side,
		capacity = capacity,
		candidatesVisited = 0,
		originX = 0,
		originZ = 0,
		x = x,
		z = z,
		alive = alive,
		cellCount = table.create(cells, 0),
		cellStart = table.create(cells + 1, 1),
		cellFill = table.create(cells, 0),
		cellOf = table.create(capacity, 1),
		sorted = table.create(capacity, 0),
		sortedCount = 0,
		rebuild = SpatialHash.rebuild,
		inRadius = SpatialHash.inRadius,
		inBox = SpatialHash.inBox,
		closest = SpatialHash.closest,
		countInRadius = SpatialHash.countInRadius,
		nthInRadius = SpatialHash.nthInRadius,
	}, SpatialHash) :: any
	return self
end

-- Re-sorts every living handle into cells around (originX, originZ).
function SpatialHash.rebuild(self: SpatialHash, originX: number, originZ: number)
	local s = self :: Internal
	s.originX = originX
	s.originZ = originZ
	local side = s.side
	local cells = side * side
	local cellCount = s.cellCount
	local cellStart = s.cellStart
	local cellFill = s.cellFill
	local cellOf = s.cellOf
	local sorted = s.sorted
	local alive = s.alive
	local x = s.x
	local z = s.z

	-- Pass 1: cell of every living handle, and per-cell counts. `cellCount`
	-- was zeroed by the prefix sweep of the previous rebuild (and by
	-- table.create in `new`), so no separate clearing pass is needed.
	for h = 1, s.capacity do
		if alive[h] then
			local c = axisCell(s, z[h], originZ) * side + axisCell(s, x[h], originX) + 1
			cellOf[h] = c
			cellCount[c] += 1
		end
	end
	-- Prefix sums: cell c owns sorted[cellStart[c] .. cellStart[c + 1] - 1].
	-- The same sweep zeroes cellCount again, ready for the next rebuild.
	local run = 1
	for c = 1, cells do
		cellStart[c] = run
		cellFill[c] = run
		run += cellCount[c]
		cellCount[c] = 0
	end
	cellStart[cells + 1] = run
	s.sortedCount = run - 1
	-- Pass 2: scatter handles into their cell's slice.
	for h = 1, s.capacity do
		if alive[h] then
			local c = cellOf[h]
			sorted[cellFill[c]] = h
			cellFill[c] += 1
		end
	end
end

-- Fills `out` (cleared first) with living handles within `radius` of (x, z).
function SpatialHash.inRadius(self: SpatialHash, x: number, z: number, radius: number, out: { Handle }): number
	local s = self :: Internal
	table.clear(out)
	if radius < 0 then
		return 0
	end
	local px, pz, alive = s.x, s.z, s.alive
	local sorted, cellStart, side = s.sorted, s.cellStart, s.side
	local r2 = radius * radius
	local cx0 = axisCell(s, x - radius, s.originX)
	local cx1 = axisCell(s, x + radius, s.originX)
	local cz0 = axisCell(s, z - radius, s.originZ)
	local cz1 = axisCell(s, z + radius, s.originZ)
	local n = 0
	local visited = 0
	for cz = cz0, cz1 do
		local row = cz * side + 1
		for cx = cx0, cx1 do
			local c = row + cx
			for i = cellStart[c], cellStart[c + 1] - 1 do
				local h = sorted[i]
				visited += 1
				if alive[h] then
					local dx = px[h] - x
					local dz = pz[h] - z
					if dx * dx + dz * dz <= r2 then
						n += 1
						out[n] = h
					end
				end
			end
		end
	end
	s.candidatesVisited += visited
	return n
end

-- Fills `out` (cleared first) with living handles inside the axis-aligned
-- box centred on (x, z) with half sizes halfW (x) and halfD (z).
function SpatialHash.inBox(
	self: SpatialHash,
	x: number,
	z: number,
	halfW: number,
	halfD: number,
	out: { Handle }
): number
	local s = self :: Internal
	table.clear(out)
	if halfW < 0 or halfD < 0 then
		return 0
	end
	local px, pz, alive = s.x, s.z, s.alive
	local sorted, cellStart, side = s.sorted, s.cellStart, s.side
	local cx0 = axisCell(s, x - halfW, s.originX)
	local cx1 = axisCell(s, x + halfW, s.originX)
	local cz0 = axisCell(s, z - halfD, s.originZ)
	local cz1 = axisCell(s, z + halfD, s.originZ)
	local minX, maxX = x - halfW, x + halfW
	local minZ, maxZ = z - halfD, z + halfD
	local n = 0
	local visited = 0
	for cz = cz0, cz1 do
		local row = cz * side + 1
		for cx = cx0, cx1 do
			local c = row + cx
			for i = cellStart[c], cellStart[c + 1] - 1 do
				local h = sorted[i]
				visited += 1
				if alive[h] then
					local ex, ez = px[h], pz[h]
					if ex >= minX and ex <= maxX and ez >= minZ and ez <= maxZ then
						n += 1
						out[n] = h
					end
				end
			end
		end
	end
	s.candidatesVisited += visited
	return n
end

-- Exact scan of every living handle: the fallback when the query point lies
-- outside the grid window, where the ring bound below would not hold.
local function closestByScan(s: Internal, x: number, z: number, maxDist: number): Handle?
	local px, pz, alive = s.x, s.z, s.alive
	local sorted = s.sorted
	local best: Handle? = nil
	local bestD2 = maxDist * maxDist
	local visited = 0
	for i = 1, s.sortedCount do
		local h = sorted[i]
		visited += 1
		if alive[h] then
			local dx = px[h] - x
			local dz = pz[h] - z
			local d2 = dx * dx + dz * dz
			if d2 <= bestD2 then
				bestD2 = d2
				best = h
			end
		end
	end
	s.candidatesVisited += visited
	return best
end

-- Examines one cell for closest(): returns the best handle and squared
-- distance after the cell, plus how many candidates it looked at. A plain
-- function with multiple returns, so a query allocates nothing.
local function closestInCell(
	s: Internal,
	cx: number,
	cz: number,
	x: number,
	z: number,
	best: Handle?,
	bestD2: number
): (Handle?, number, number)
	local px, pz, alive = s.x, s.z, s.alive
	local sorted, cellStart = s.sorted, s.cellStart
	local c = cz * s.side + cx + 1
	local visited = 0
	for i = cellStart[c], cellStart[c + 1] - 1 do
		local h = sorted[i]
		visited += 1
		if alive[h] then
			local dx = px[h] - x
			local dz = pz[h] - z
			local d2 = dx * dx + dz * dz
			if d2 <= bestD2 then
				bestD2 = d2
				best = h
			end
		end
	end
	return best, bestD2, visited
end

-- Nearest living handle to (x, z) within maxDist; nil if none. Expands in
-- Chebyshev rings of cells around the query cell and stops as soon as no
-- unvisited ring can hold anything nearer than the best found: every cell
-- in ring r + 1 is at least r * cellSize away from a point inside ring 0.
function SpatialHash.closest(self: SpatialHash, x: number, z: number, maxDist: number): Handle?
	local s = self :: Internal
	if maxDist < 0 then
		return nil
	end
	if not inside(s, x, z) then
		return closestByScan(s, x, z, maxDist)
	end
	local cell = s.cellSize
	local ccx = axisCell(s, x, s.originX)
	local ccz = axisCell(s, z, s.originZ)
	local last = s.side - 1
	-- Farthest ring that still has a cell inside the grid.
	local maxRing = math.max(ccx, last - ccx, ccz, last - ccz)
	local best: Handle? = nil
	local bestD2 = maxDist * maxDist
	local visited = 0
	local v = 0

	for r = 0, maxRing do
		-- Ring r's nearest point is at least (r - 1) * cell away; past maxDist
		-- nothing in it (or beyond) can qualify.
		if r > 0 and (r - 1) * cell > maxDist then
			break
		end
		if r == 0 then
			best, bestD2, v = closestInCell(s, ccx, ccz, x, z, best, bestD2)
			visited += v
		else
			local cx0 = math.max(ccx - r, 0)
			local cx1 = math.min(ccx + r, last)
			-- Top and bottom rows of the ring (full width).
			if ccz - r >= 0 then
				for cx = cx0, cx1 do
					best, bestD2, v = closestInCell(s, cx, ccz - r, x, z, best, bestD2)
					visited += v
				end
			end
			if ccz + r <= last then
				for cx = cx0, cx1 do
					best, bestD2, v = closestInCell(s, cx, ccz + r, x, z, best, bestD2)
					visited += v
				end
			end
			-- Left and right columns, excluding the corners already visited.
			local cz0 = math.max(ccz - r + 1, 0)
			local cz1 = math.min(ccz + r - 1, last)
			if ccx - r >= 0 then
				for cz = cz0, cz1 do
					best, bestD2, v = closestInCell(s, ccx - r, cz, x, z, best, bestD2)
					visited += v
				end
			end
			if ccx + r <= last then
				for cz = cz0, cz1 do
					best, bestD2, v = closestInCell(s, ccx + r, cz, x, z, best, bestD2)
					visited += v
				end
			end
		end
		if best ~= nil then
			local bound = r * cell
			if bestD2 <= bound * bound then
				break
			end
		end
	end
	s.candidatesVisited += visited
	return best
end

-- Number of living handles within radius of (x, z).
function SpatialHash.countInRadius(self: SpatialHash, x: number, z: number, radius: number): number
	local s = self :: Internal
	if radius < 0 then
		return 0
	end
	local px, pz, alive = s.x, s.z, s.alive
	local sorted, cellStart, side = s.sorted, s.cellStart, s.side
	local r2 = radius * radius
	local cx0 = axisCell(s, x - radius, s.originX)
	local cx1 = axisCell(s, x + radius, s.originX)
	local cz0 = axisCell(s, z - radius, s.originZ)
	local cz1 = axisCell(s, z + radius, s.originZ)
	local n = 0
	local visited = 0
	for cz = cz0, cz1 do
		local row = cz * side + 1
		for cx = cx0, cx1 do
			local c = row + cx
			for i = cellStart[c], cellStart[c + 1] - 1 do
				local h = sorted[i]
				visited += 1
				if alive[h] then
					local dx = px[h] - x
					local dz = pz[h] - z
					if dx * dx + dz * dz <= r2 then
						n += 1
					end
				end
			end
		end
	end
	s.candidatesVisited += visited
	return n
end

-- The k-th living handle within radius, in the same cell order that
-- countInRadius walks, so k in [1, countInRadius(...)] always resolves.
function SpatialHash.nthInRadius(self: SpatialHash, x: number, z: number, radius: number, k: number): Handle?
	local s = self :: Internal
	if radius < 0 or k < 1 then
		return nil
	end
	local px, pz, alive = s.x, s.z, s.alive
	local sorted, cellStart, side = s.sorted, s.cellStart, s.side
	local r2 = radius * radius
	local cx0 = axisCell(s, x - radius, s.originX)
	local cx1 = axisCell(s, x + radius, s.originX)
	local cz0 = axisCell(s, z - radius, s.originZ)
	local cz1 = axisCell(s, z + radius, s.originZ)
	local n = 0
	local visited = 0
	for cz = cz0, cz1 do
		local row = cz * side + 1
		for cx = cx0, cx1 do
			local c = row + cx
			for i = cellStart[c], cellStart[c + 1] - 1 do
				local h = sorted[i]
				visited += 1
				if alive[h] then
					local dx = px[h] - x
					local dz = pz[h] - z
					if dx * dx + dz * dz <= r2 then
						n += 1
						if n == k then
							s.candidatesVisited += visited
							return h
						end
					end
				end
			end
		end
	end
	s.candidatesVisited += visited
	return nil
end

return SpatialHash
