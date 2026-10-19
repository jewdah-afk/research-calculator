--!native
--!optimize 2
-- ContourMesh: Worms-style destructible 2D terrain. A u8 density mask (solid where value > 127.5) is cut into
-- 32x32-cell tiles; each tile becomes one closed extruded mesh (its own EditableMesh).
--
-- Per tile:
--   1. Marching squares with linear interpolation on a padded copy of the tile (padding = empty), so every
--      contour is closed and the tile's solid region is clipped to the tile square. Segments are oriented
--      with solid on the left (world, Y up): outlines come out CCW, holes CW.
--   2. Loops are traced from a next-edge table, clamped to the tile, and collinear points along the tile
--      border are dropped. Remaining border points are pinned, so both tiles sharing a seam keep identical
--      seam vertices; Ramer-Douglas-Peucker runs between pins.
--   3. Front cap = earcut-style ear clipping with hole bridging; back cap = mirrored. Side walls are built
--      from the cap's boundary edges (so caps and walls always agree), except edges lying on an interior
--      tile seam: those walls would be hidden between two tiles. A tile is watertight except along seams.
-- carveCircle/paintCircle edit the mask with an anti-aliased disc and rebuild only tiles whose samples changed.
-- Cost: one 32x32 tile rebuild is ~1k cells of marching squares + a few hundred points of ear clipping.
-- Pure Luau except the ROBLOX ADAPTER section at the bottom. Rebuild allocates (topology changes); the
-- per-frame path is "nothing" until the next carve.

local ContourMesh = {}

local MAX_TRIS, MAX_VERTS = 20000, 60000
local ISO = 127.5

export type Loop = { xs: { number }, ys: { number }, hole: boolean } -- tile-local sample coords, y down

export type Tile = {
	tx: number,
	ty: number,
	vcount: number,
	tcount: number,
	pos: buffer, -- f32 x3 world studs: X right, Y up, Z = +-depth/2 (front faces +Z)
	idx: buffer, -- u32 x3, CCW from outside
	fnrm: buffer, -- f32 x3 per triangle (flat)
	mat: buffer, -- u8 per triangle: 0 front cap, 1 back cap, 2 wall
	loops: { Loop }, -- simplified loops (after RDP)
	rawLoops: { Loop }?, -- traced loops before simplification (only with field.keepDebug)
	openChains: number, -- contour chains that failed to close (must be 0)
	rawPoints: number,
	keptPoints: number,
}

export type Field = {
	w: number,
	h: number,
	mask: buffer,
	tile: number,
	ntx: number,
	nty: number,
	cell: number,
	depth: number,
	epsilon: number,
	minArea: number,
	keepDebug: boolean,
	tiles: { Tile },
	-- scratch for one tile
	S: number,
	vals: buffer,
	nextE: buffer,
	ex: buffer,
	ey: buffer,
}

function ContourMesh.newField(w: number, h: number, opts: { [string]: any }?): Field
	local o = opts or {}
	local T = o.tile or 32
	assert((w - 1) % T == 0 and (h - 1) % T == 0, "mask size must be k*tile+1")
	local S = T + 3
	return {
		w = w,
		h = h,
		mask = buffer.create(w * h),
		tile = T,
		ntx = (w - 1) // T,
		nty = (h - 1) // T,
		cell = o.cell or 1,
		depth = o.depth or 6,
		epsilon = o.epsilon or 0.3,
		minArea = o.minArea or 0.2,
		keepDebug = o.keepDebug or false,
		tiles = {},
		S = S,
		vals = buffer.create(S * S),
		nextE = buffer.create(2 * S * S * 4),
		ex = buffer.create(2 * S * S * 8),
		ey = buffer.create(2 * S * S * 8),
	}
end

-- Re-size a field in place, keeping its buffers when they are big enough (grow-only). Lets one field mesh
-- many differently sized masks (e.g. fracture fragments) without reallocating scratch per mesh. The caller
-- rewrites the first w*h bytes of f.mask; f.tiles is cleared.
function ContourMesh.reshape(f: Field, w: number, h: number, tile: number)
	assert((w - 1) % tile == 0 and (h - 1) % tile == 0, "mask size must be k*tile+1")
	local S = tile + 3
	if buffer.len(f.mask) < w * h then
		f.mask = buffer.create(w * h)
	end
	if buffer.len(f.vals) < S * S then
		f.vals = buffer.create(S * S)
		f.nextE = buffer.create(2 * S * S * 4)
		f.ex = buffer.create(2 * S * S * 8)
		f.ey = buffer.create(2 * S * S * 8)
	end
	f.w, f.h, f.tile, f.S = w, h, tile, S
	f.ntx, f.nty = (w - 1) // tile, (h - 1) // tile
	table.clear(f.tiles)
end

-- Marching squares ------------------------------------------------------------------------------------------

local function crossing(f: Field, e: number)
	-- Edge id e: 2*(lj*S+li) (+1 for the vertical edge). Crossing point in tile-local coords.
	local S, vals = f.S, f.vals
	local cellId = e // 2
	local li, lj = cellId % S, cellId // S
	local v0 = buffer.readu8(vals, cellId)
	if e % 2 == 0 then
		local v1 = buffer.readu8(vals, cellId + 1)
		buffer.writef64(f.ex, e * 8, li - 1 + (ISO - v0) / (v1 - v0))
		buffer.writef64(f.ey, e * 8, lj - 1)
	else
		local v1 = buffer.readu8(vals, cellId + S)
		buffer.writef64(f.ex, e * 8, li - 1)
		buffer.writef64(f.ey, e * 8, lj - 1 + (ISO - v0) / (v1 - v0))
	end
end

-- Link e1 -> e2 so that reference corner (rx, ry) lies on the segment's left iff it is solid. In y-down
-- tile coords cross < 0 means "visually left", which stays left in the Y-up world (same picture).
local function link(f: Field, e1: number, e2: number, rx: number, ry: number, rSolid: boolean)
	local px, py = buffer.readf64(f.ex, e1 * 8), buffer.readf64(f.ey, e1 * 8)
	local qx, qy = buffer.readf64(f.ex, e2 * 8), buffer.readf64(f.ey, e2 * 8)
	local cr = (qx - px) * (ry - py) - (qy - py) * (rx - px)
	if (cr < 0) ~= rSolid then
		e1, e2 = e2, e1
	end
	buffer.writei32(f.nextE, e1 * 4, e2)
end

local function traceTile(f: Field, tx: number, ty: number): ({ Loop }, number, number)
	local T, S, w, mask, vals = f.tile, f.S, f.w, f.mask, f.vals
	-- Padded copy of the tile's (T+1)^2 samples.
	buffer.fill(vals, 0, 0)
	for m = 0, T do
		buffer.copy(vals, (m + 1) * S + 1, mask, (ty * T + m) * w + tx * T, T + 1)
	end
	buffer.fill(f.nextE, 0, 0xFF)
	for lj = 0, S - 2 do
		for li = 0, S - 2 do
			local c = lj * S + li
			local va, vb = buffer.readu8(vals, c), buffer.readu8(vals, c + 1)
			local vd, vc = buffer.readu8(vals, c + S), buffer.readu8(vals, c + S + 1)
			local a, b, cc, d = va > ISO, vb > ISO, vc > ISO, vd > ISO
			if a == b and b == cc and cc == d then
				continue
			end
			local eT, eB, eL, eR = 2 * c, 2 * (c + S), 2 * c + 1, 2 * (c + 1) + 1
			local x0, y0 = li - 1, lj - 1 -- corner a; b = (x0+1, y0), c = (x0+1, y0+1), d = (x0, y0+1)
			if a ~= b then
				crossing(f, eT)
			end
			if d ~= cc then
				crossing(f, eB)
			end
			if a ~= d then
				crossing(f, eL)
			end
			if b ~= cc then
				crossing(f, eR)
			end
			if a == cc and b == d then -- saddle: disambiguate by the cell centre
				local centre = (va + vb + vc + vd) * 0.25 > ISO
				if centre == a then -- a and c joined: cut corners b and d
					link(f, eT, eR, x0 + 1, y0, b)
					link(f, eB, eL, x0, y0 + 1, d)
				else
					link(f, eT, eL, x0, y0, a)
					link(f, eR, eB, x0 + 1, y0 + 1, cc)
				end
			elseif a ~= b and a ~= d then
				link(f, eT, eL, x0, y0, a)
			elseif b ~= a and b ~= cc then
				link(f, eT, eR, x0 + 1, y0, b)
			elseif cc ~= b and cc ~= d then
				link(f, eR, eB, x0 + 1, y0 + 1, cc)
			elseif d ~= a and d ~= cc then
				link(f, eB, eL, x0, y0 + 1, d)
			elseif a ~= b then -- vertical split
				link(f, eT, eB, x0, y0, a)
			else -- horizontal split
				link(f, eL, eR, x0, y0, a)
			end
		end
	end
	-- Trace loops; clamp to the tile square (padding crossings land on the border).
	local loops, open, nE = {}, 0, 2 * S * S
	for e = 0, nE - 1 do
		if buffer.readi32(f.nextE, e * 4) < 0 then
			continue
		end
		local xs, ys = {}, {}
		local cur = e
		repeat
			local x, y = math.clamp(buffer.readf64(f.ex, cur * 8), 0, T), math.clamp(buffer.readf64(f.ey, cur * 8), 0, T)
			local n = #xs
			if n == 0 or xs[n] ~= x or ys[n] ~= y then
				xs[n + 1], ys[n + 1] = x, y
			end
			local nx = buffer.readi32(f.nextE, cur * 4)
			buffer.writei32(f.nextE, cur * 4, -2)
			cur = nx
		until cur < 0 or cur == e
		if cur ~= e then
			open += 1
			continue
		end
		local n = #xs
		while n > 1 and xs[n] == xs[1] and ys[n] == ys[1] do
			xs[n], ys[n] = nil, nil
			n -= 1
		end
		if n >= 3 then
			table.insert(loops, { xs = xs, ys = ys, hole = false })
		end
	end
	return loops, open, nE
end

-- Simplification ----------------------------------------------------------------------------------------------

local function borderBits(x: number, y: number, T: number): number
	return (if x == 0 then 1 else 0) + (if x == T then 2 else 0) + (if y == 0 then 4 else 0) + (if y == T then 8 else 0)
end

local function rdp(xs: { number }, ys: { number }, i0: number, i1: number, eps: number, keep: { boolean })
	if i1 - i0 < 2 then
		return
	end
	local ax, ay, bx, by = xs[i0], ys[i0], xs[i1], ys[i1]
	local dx, dy = bx - ax, by - ay
	local len2 = dx * dx + dy * dy
	local best, bi = -1, -1
	for i = i0 + 1, i1 - 1 do
		local px, py = xs[i] - ax, ys[i] - ay
		local d
		if len2 == 0 then
			d = px * px + py * py
		else
			local c = px * dy - py * dx
			d = c * c / len2
		end
		if d > best then
			best, bi = d, i
		end
	end
	if best > eps * eps then
		keep[bi] = true
		rdp(xs, ys, i0, bi, eps, keep)
		rdp(xs, ys, bi, i1, eps, keep)
	end
end

local function simplify(loop: Loop, T: number, eps: number): Loop?
	local xs, ys = loop.xs, loop.ys
	local n = #xs
	local bits = table.create(n)
	for i = 1, n do
		bits[i] = borderBits(xs[i], ys[i], T)
	end
	-- Drop points strictly inside a straight run along one tile border (seam-consistent in both tiles).
	local px, py, pb = {}, {}, {}
	for i = 1, n do
		local prev, nxt = bits[if i == 1 then n else i - 1], bits[if i == n then 1 else i + 1]
		if bit32.band(prev, bits[i], nxt) == 0 then
			table.insert(px, xs[i])
			table.insert(py, ys[i])
			table.insert(pb, bits[i])
		end
	end
	n = #px
	if n < 3 then
		return nil
	end
	-- Rotate so the loop starts at a pin (any border point), else at point 1 with the farthest point pinned.
	local start = 1
	for i = 1, n do
		if pb[i] ~= 0 then
			start = i
			break
		end
	end
	local rx, ry, keep = table.create(n + 1), table.create(n + 1), table.create(n + 1, false)
	for k = 0, n - 1 do
		local i = (start - 1 + k) % n + 1
		rx[k + 1], ry[k + 1] = px[i], py[i]
		keep[k + 1] = pb[i] ~= 0
	end
	rx[n + 1], ry[n + 1] = rx[1], ry[1]
	keep[1], keep[n + 1] = true, true
	local anyPin = false
	for k = 2, n do
		anyPin = anyPin or keep[k]
	end
	if not anyPin and pb[start] == 0 then
		local far, fi = -1, 2
		for k = 2, n do
			local d = (rx[k] - rx[1]) ^ 2 + (ry[k] - ry[1]) ^ 2
			if d > far then
				far, fi = d, k
			end
		end
		keep[fi] = true
	end
	local a = 1
	for k = 2, n + 1 do
		if keep[k] then
			rdp(rx, ry, a, k, eps, keep)
			a = k
		end
	end
	local ox, oy = {}, {}
	for k = 1, n do
		if keep[k] then
			table.insert(ox, rx[k])
			table.insert(oy, ry[k])
		end
	end
	if #ox < 3 then
		return nil
	end
	return { xs = ox, ys = oy, hole = false }
end

-- Signed area in world orientation (Y up), tile-local units.
local function areaUp(xs: { number }, ys: { number }): number
	local s, n = 0, #xs
	for i = 1, n do
		local j = if i == n then 1 else i + 1
		s += xs[i] * -ys[j] - xs[j] * -ys[i]
	end
	return s * 0.5
end

local function pointInLoop(x: number, y: number, xs: { number }, ys: { number }): boolean
	local inside, n = false, #xs
	local j = n
	for i = 1, n do
		if (ys[i] > y) ~= (ys[j] > y) and x < (xs[j] - xs[i]) * (y - ys[i]) / (ys[j] - ys[i]) + xs[i] then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Ear clipping with hole bridging (a port of the core of mapbox/earcut, ISC licence; no z-order hash).
-- Input: flat {x0, y0, x1, y1, ...} (Y up), hole start vertex indices. Output: 0-based vertex index triples.

type Node = { i: number, x: number, y: number, prev: Node, next: Node, steiner: boolean }

local function insertNode(i: number, x: number, y: number, last: Node?): Node
	local p = { i = i, x = x, y = y, prev = nil :: any, next = nil :: any, steiner = false }
	if not last then
		p.prev, p.next = p, p
	else
		p.next = last.next
		p.prev = last
		last.next.prev = p
		last.next = p
	end
	return p
end
local function removeNode(p: Node)
	p.next.prev = p.prev
	p.prev.next = p.next
end
local function equals(a: Node, b: Node): boolean
	return a.x == b.x and a.y == b.y
end
local function area(p: Node, q: Node, r: Node): number
	return (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
end
local function pointInTriangle(ax: number, ay: number, bx: number, by: number, cx: number, cy: number, px: number, py: number): boolean
	return (cx - px) * (ay - py) >= (ax - px) * (cy - py) and (ax - px) * (by - py) >= (bx - px) * (ay - py) and (bx - px) * (cy - py) >= (cx - px) * (by - py)
end
local function sign(v: number): number
	return if v > 0 then 1 elseif v < 0 then -1 else 0
end
local function onSegment(p: Node, q: Node, r: Node): boolean
	return q.x <= math.max(p.x, r.x) and q.x >= math.min(p.x, r.x) and q.y <= math.max(p.y, r.y) and q.y >= math.min(p.y, r.y)
end
local function intersects(p1: Node, q1: Node, p2: Node, q2: Node): boolean
	local o1, o2 = sign(area(p1, q1, p2)), sign(area(p1, q1, q2))
	local o3, o4 = sign(area(p2, q2, p1)), sign(area(p2, q2, q1))
	if o1 ~= o2 and o3 ~= o4 then
		return true
	end
	return (o1 == 0 and onSegment(p1, p2, q1)) or (o2 == 0 and onSegment(p1, q2, q1)) or (o3 == 0 and onSegment(p2, p1, q2)) or (o4 == 0 and onSegment(p2, q1, q2))
end
local function intersectsPolygon(a: Node, b: Node): boolean
	local p = a
	repeat
		if p.i ~= a.i and p.next.i ~= a.i and p.i ~= b.i and p.next.i ~= b.i and intersects(p, p.next, a, b) then
			return true
		end
		p = p.next
	until p == a
	return false
end
local function locallyInside(a: Node, b: Node): boolean
	if area(a.prev, a, a.next) < 0 then
		return area(a, b, a.next) >= 0 and area(a, a.prev, b) >= 0
	end
	return area(a, b, a.prev) < 0 or area(a, a.next, b) < 0
end
local function middleInside(a: Node, b: Node): boolean
	local p, inside = a, false
	local px, py = (a.x + b.x) / 2, (a.y + b.y) / 2
	repeat
		if (p.y > py) ~= (p.next.y > py) and p.next.y ~= p.y and px < (p.next.x - p.x) * (py - p.y) / (p.next.y - p.y) + p.x then
			inside = not inside
		end
		p = p.next
	until p == a
	return inside
end
local function splitPolygon(a: Node, b: Node): Node
	local a2 = { i = a.i, x = a.x, y = a.y, prev = nil :: any, next = nil :: any, steiner = false }
	local b2 = { i = b.i, x = b.x, y = b.y, prev = nil :: any, next = nil :: any, steiner = false }
	local an, bp = a.next, b.prev
	a.next = b
	b.prev = a
	a2.next = an
	an.prev = a2
	b2.next = a2
	a2.prev = b2
	bp.next = b2
	b2.prev = bp
	return b2
end
local function filterPoints(start: Node?, finish: Node?): Node?
	if not start then
		return start
	end
	local p: Node = start
	local stop: Node = finish or start
	local again
	repeat
		again = false
		if not p.steiner and (equals(p, p.next) or area(p.prev, p, p.next) == 0) then
			removeNode(p)
			p = p.prev
			stop = p
			if p == p.next then
				break
			end
			again = true
		else
			p = p.next
		end
	until not (again or p ~= stop)
	return stop
end
local function isEar(ear: Node): boolean
	local a, b, c = ear.prev, ear, ear.next
	if area(a, b, c) >= 0 then
		return false
	end
	local ax, ay, bx, by, cx, cy = a.x, a.y, b.x, b.y, c.x, c.y
	local x0, x1 = math.min(ax, bx, cx), math.max(ax, bx, cx)
	local y0, y1 = math.min(ay, by, cy), math.max(ay, by, cy)
	local p = c.next
	while p ~= a do
		if p.x >= x0 and p.x <= x1 and p.y >= y0 and p.y <= y1 and not (ax == p.x and ay == p.y) and pointInTriangle(ax, ay, bx, by, cx, cy, p.x, p.y) and area(p.prev, p, p.next) >= 0 then
			return false
		end
		p = p.next
	end
	return true
end

local earcutLinked: (Node?, { number }, number) -> ()

local function cureLocalIntersections(start: Node, tris: { number }): Node?
	local p = start
	repeat
		local a, b = p.prev, p.next.next
		if not equals(a, b) and intersects(a, p, p.next, b) and locallyInside(a, b) and locallyInside(b, a) then
			table.insert(tris, a.i)
			table.insert(tris, p.i)
			table.insert(tris, b.i)
			removeNode(p)
			removeNode(p.next)
			p = b
			start = b
		end
		p = p.next
	until p == start
	return filterPoints(p)
end
local function isValidDiagonal(a: Node, b: Node): boolean
	return a.next.i ~= b.i
		and a.prev.i ~= b.i
		and not intersectsPolygon(a, b)
		and (
			(locallyInside(a, b) and locallyInside(b, a) and middleInside(a, b) and (area(a.prev, a, b.prev) ~= 0 or area(a, b.prev, b) ~= 0))
			or (equals(a, b) and area(a.prev, a, a.next) > 0 and area(b.prev, b, b.next) > 0)
		)
end
local function splitEarcut(start: Node, tris: { number })
	local a = start
	repeat
		local b = a.next.next
		while b ~= a.prev do
			if a.i ~= b.i and isValidDiagonal(a, b) then
				local c = splitPolygon(a, b)
				earcutLinked(filterPoints(a, a.next), tris, 0)
				earcutLinked(filterPoints(c, c.next), tris, 0)
				return
			end
			b = b.next
		end
		a = a.next
	until a == start
end
earcutLinked = function(ear: Node?, tris: { number }, pass: number)
	if not ear then
		return
	end
	local e: Node = ear
	local stop = e
	while e.prev ~= e.next do
		local prev, nxt = e.prev, e.next
		if isEar(e) then
			table.insert(tris, prev.i)
			table.insert(tris, e.i)
			table.insert(tris, nxt.i)
			removeNode(e)
			e = nxt.next
			stop = nxt.next
			continue
		end
		e = nxt
		if e == stop then
			if pass == 0 then
				earcutLinked(filterPoints(e), tris, 1)
			elseif pass == 1 then
				local cured = cureLocalIntersections(filterPoints(e) :: Node, tris)
				earcutLinked(cured, tris, 2)
			else
				splitEarcut(e, tris)
			end
			break
		end
	end
end

local function linkedList(data: { number }, s: number, e: number, clockwise: boolean): Node?
	local sum, j = 0, e - 1
	for i = s, e - 1 do
		sum += (data[2 * j + 1] - data[2 * i + 1]) * (data[2 * i + 2] + data[2 * j + 2])
		j = i
	end
	local last: Node? = nil
	if clockwise == (sum > 0) then
		for i = s, e - 1 do
			last = insertNode(i, data[2 * i + 1], data[2 * i + 2], last)
		end
	else
		for i = e - 1, s, -1 do
			last = insertNode(i, data[2 * i + 1], data[2 * i + 2], last)
		end
	end
	if last and equals(last, last.next) then
		removeNode(last)
		last = last.next
	end
	return last
end
local function sectorContainsSector(m: Node, p: Node): boolean
	return area(m.prev, m, p.prev) < 0 and area(p.next, m, m.next) < 0
end
local function findHoleBridge(hole: Node, outer: Node): Node?
	local p = outer
	local hx, hy, qx = hole.x, hole.y, -math.huge
	local m: Node? = nil
	repeat
		if hy <= p.y and hy >= p.next.y and p.next.y ~= p.y then
			local x = p.x + (hy - p.y) * (p.next.x - p.x) / (p.next.y - p.y)
			if x <= hx and x > qx then
				qx = x
				m = if p.x < p.next.x then p else p.next
				if x == hx then
					return m
				end
			end
		end
		p = p.next
	until p == outer
	if not m then
		return nil
	end
	local stop: Node = m
	local mx, my, tanMin = stop.x, stop.y, math.huge
	p = stop
	repeat
		if hx >= p.x and p.x >= mx and hx ~= p.x and pointInTriangle(if hy < my then hx else qx, hy, mx, my, if hy < my then qx else hx, hy, p.x, p.y) then
			local tan = math.abs(hy - p.y) / (hx - p.x)
			local mm: Node = m :: Node
			if locallyInside(p, hole) and (tan < tanMin or (tan == tanMin and (p.x > mm.x or (p.x == mm.x and sectorContainsSector(mm, p))))) then
				m = p
				tanMin = tan
			end
		end
		p = p.next
	until p == stop
	return m
end
local function getLeftmost(start: Node): Node
	local p, left = start, start
	repeat
		if p.x < left.x or (p.x == left.x and p.y < left.y) then
			left = p
		end
		p = p.next
	until p == start
	return left
end

function ContourMesh.earcut(data: { number }, holes: { number }): { number }
	local nv = #data // 2
	local tris = {}
	local outer = linkedList(data, 0, if #holes > 0 then holes[1] else nv, true)
	if not outer or outer.next == outer.prev then
		return tris
	end
	if #holes > 0 then
		local queue = {}
		for k, s in holes do
			local list = linkedList(data, s, if k < #holes then holes[k + 1] else nv, false)
			if list then
				if list == list.next then
					list.steiner = true
				end
				table.insert(queue, getLeftmost(list))
			end
		end
		table.sort(queue, function(a, b)
			return a.x < b.x or (a.x == b.x and a.y < b.y)
		end)
		for _, h in queue do
			local bridge = findHoleBridge(h, outer)
			if bridge then
				local rev = splitPolygon(bridge, h)
				filterPoints(rev, rev.next)
				outer = filterPoints(bridge, bridge.next) :: Node
			end
		end
	end
	earcutLinked(outer, tris, 0)
	return tris
end

-- Tile build -------------------------------------------------------------------------------------------------

function ContourMesh.buildTile(f: Field, tx: number, ty: number): Tile
	local T, cell, eps = f.tile, f.cell, f.epsilon
	local raw, open = traceTile(f, tx, ty)
	local rawPoints = 0
	local outers, holes = {}, {}
	for _, l in raw do
		rawPoints += #l.xs
		local s = simplify(l, T, eps)
		if s then
			local a = areaUp(s.xs, s.ys)
			if math.abs(a) >= f.minArea then
				s.hole = a < 0
				table.insert(if s.hole then holes else outers, s)
			end
		end
	end
	-- Group each hole with the smallest outline containing it.
	local groups = {}
	for k, o in outers do
		groups[k] = { o }
	end
	for _, hl in holes do
		local best, bestA = nil, math.huge
		for k, o in outers do
			local a = areaUp(o.xs, o.ys)
			if a < bestA and pointInLoop(hl.xs[1], hl.ys[1], o.xs, o.ys) then
				best, bestA = k, a
			end
		end
		if best then
			table.insert(groups[best], hl)
		end
	end
	-- Vertices: every kept point once on the front (z+) and once on the back (z-).
	local loops, xsAll, ysAll = {}, {}, {}
	local capTris = {}
	for _, g in groups do
		local base = #xsAll
		local data, holeStarts = {}, {}
		for li, l in g do
			table.insert(loops, l)
			if li > 1 then
				table.insert(holeStarts, #data // 2)
			end
			for i = 1, #l.xs do
				table.insert(data, l.xs[i])
				table.insert(data, -l.ys[i])
				table.insert(xsAll, l.xs[i])
				table.insert(ysAll, l.ys[i])
			end
		end
		local tri = ContourMesh.earcut(data, holeStarts)
		local s = 0
		for k = 1, #tri, 3 do
			local a, b, c = tri[k], tri[k + 1], tri[k + 2]
			s += (data[2 * b + 1] - data[2 * a + 1]) * (data[2 * c + 2] - data[2 * a + 2]) - (data[2 * c + 1] - data[2 * a + 1]) * (data[2 * b + 2] - data[2 * a + 2])
		end
		for k = 1, #tri, 3 do
			if s >= 0 then
				table.insert(capTris, { base + tri[k], base + tri[k + 1], base + tri[k + 2] })
			else
				table.insert(capTris, { base + tri[k], base + tri[k + 2], base + tri[k + 1] })
			end
		end
	end
	-- Boundary edges of the front cap (used once) become walls, unless they lie on an interior seam.
	local N = #xsAll
	local useCount = {}
	for _, t in capTris do
		for k = 1, 3 do
			local a, b = t[k], t[k % 3 + 1]
			local key = math.min(a, b) * 65536 + math.max(a, b)
			useCount[key] = (useCount[key] or 0) + 1
		end
	end
	local walls = {}
	local function interiorSeam(a: number, b: number): boolean
		local ab = bit32.band(borderBits(xsAll[a + 1], ysAll[a + 1], T), borderBits(xsAll[b + 1], ysAll[b + 1], T))
		return (bit32.band(ab, 1) ~= 0 and tx > 0)
			or (bit32.band(ab, 2) ~= 0 and tx < f.ntx - 1)
			or (bit32.band(ab, 4) ~= 0 and ty > 0)
			or (bit32.band(ab, 8) ~= 0 and ty < f.nty - 1)
	end
	for _, t in capTris do
		for k = 1, 3 do
			local a, b = t[k], t[k % 3 + 1]
			if useCount[math.min(a, b) * 65536 + math.max(a, b)] == 1 and not interiorSeam(a, b) then
				table.insert(walls, a)
				table.insert(walls, b)
			end
		end
	end
	local vcount, tcount = 2 * N, 2 * #capTris + #walls
	assert(vcount <= MAX_VERTS and tcount <= MAX_TRIS, "tile exceeds EditableMesh limits")
	local tile: Tile = {
		tx = tx,
		ty = ty,
		vcount = vcount,
		tcount = tcount,
		pos = buffer.create(vcount * 12),
		idx = buffer.create(tcount * 12),
		fnrm = buffer.create(tcount * 12),
		mat = buffer.create(tcount),
		loops = loops,
		rawLoops = if f.keepDebug then raw else nil,
		openChains = open,
		rawPoints = rawPoints,
		keptPoints = N,
	}
	local zf = f.depth * 0.5
	for i = 0, N - 1 do
		local X = (tx * T + xsAll[i + 1]) * cell
		local Y = (f.h - 1 - (ty * T + ysAll[i + 1])) * cell
		buffer.writef32(tile.pos, i * 12, X)
		buffer.writef32(tile.pos, i * 12 + 4, Y)
		buffer.writef32(tile.pos, i * 12 + 8, zf)
		buffer.writef32(tile.pos, (N + i) * 12, X)
		buffer.writef32(tile.pos, (N + i) * 12 + 4, Y)
		buffer.writef32(tile.pos, (N + i) * 12 + 8, -zf)
	end
	local o = 0
	local function emit(a: number, b: number, c: number, m: number, nx: number, ny: number, nz: number)
		buffer.writeu32(tile.idx, o * 12, a)
		buffer.writeu32(tile.idx, o * 12 + 4, b)
		buffer.writeu32(tile.idx, o * 12 + 8, c)
		buffer.writef32(tile.fnrm, o * 12, nx)
		buffer.writef32(tile.fnrm, o * 12 + 4, ny)
		buffer.writef32(tile.fnrm, o * 12 + 8, nz)
		buffer.writeu8(tile.mat, o, m)
		o += 1
	end
	for _, t in capTris do
		emit(t[1], t[2], t[3], 0, 0, 0, 1)
	end
	for _, t in capTris do
		emit(N + t[1], N + t[3], N + t[2], 1, 0, 0, -1)
	end
	for k = 1, #walls, 2 do
		-- Edge p->q has solid on its left (world), so the outward normal is its right: (dy, -dx).
		local p, q = walls[k], walls[k + 1]
		local dx = xsAll[q + 1] - xsAll[p + 1]
		local dy = -(ysAll[q + 1] - ysAll[p + 1])
		local l = math.sqrt(dx * dx + dy * dy)
		emit(p, N + p, N + q, 2, dy / l, -dx / l, 0)
		emit(p, N + q, q, 2, dy / l, -dx / l, 0)
	end
	assert(o == tcount)
	return tile
end

function ContourMesh.buildAll(f: Field)
	for ty = 0, f.nty - 1 do
		for tx = 0, f.ntx - 1 do
			f.tiles[ty * f.ntx + tx + 1] = ContourMesh.buildTile(f, tx, ty)
		end
	end
end

-- Editing ---------------------------------------------------------------------------------------------------

-- Anti-aliased disc: carve lowers samples toward empty, paint raises toward solid. The contour lands on radius r.
-- Returns the indices (into f.tiles) of the rebuilt tiles.
local function stamp(f: Field, cx: number, cy: number, r: number, carve: boolean): { number }
	local w, h, mask = f.w, f.h, f.mask
	local x0, x1 = math.max(0, math.floor(cx - r - 2)), math.min(w - 1, math.ceil(cx + r + 2))
	local y0, y1 = math.max(0, math.floor(cy - r - 2)), math.min(h - 1, math.ceil(cy + r + 2))
	local bx0, by0, bx1, by1 = math.huge, math.huge, -1, -1
	for y = y0, y1 do
		for x = x0, x1 do
			local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
			local v = math.clamp(ISO + (d - r) * 100, 0, 255) -- empty inside, ramps to solid over ~2.5 samples
			local i = y * w + x
			local old = buffer.readu8(mask, i)
			local new = if carve then math.min(old, math.floor(v)) else math.max(old, math.ceil(255 - v))
			if new ~= old then
				buffer.writeu8(mask, i, new)
				bx0, by0, bx1, by1 = math.min(bx0, x), math.min(by0, y), math.max(bx1, x), math.max(by1, y)
			end
		end
	end
	local rebuilt = {}
	if bx1 < 0 then
		return rebuilt
	end
	local T = f.tile
	-- Tile (tx,ty) reads samples [tx*T, tx*T+T]; seam samples belong to two tiles.
	for ty = math.max(0, (by0 - 1) // T), math.min(f.nty - 1, by1 // T) do
		for tx = math.max(0, (bx0 - 1) // T), math.min(f.ntx - 1, bx1 // T) do
			if bx0 <= tx * T + T and bx1 >= tx * T and by0 <= ty * T + T and by1 >= ty * T then
				local k = ty * f.ntx + tx + 1
				f.tiles[k] = ContourMesh.buildTile(f, tx, ty)
				table.insert(rebuilt, k)
			end
		end
	end
	return rebuilt
end

function ContourMesh.carveCircle(f: Field, cx: number, cy: number, r: number): { number }
	return stamp(f, cx, cy, r, true)
end

function ContourMesh.paintCircle(f: Field, cx: number, cy: number, r: number): { number }
	return stamp(f, cx, cy, r, false)
end

-- ROBLOX ADAPTER ---------------------------------------------------------------------------------------------
-- Cannot run headless. Method names from doc 21 (EditableMesh.yaml, fetched 2026-09-17).
-- Hard edges: vertices are shared between caps and walls, so each triangle gets its own normal ID (the
-- documented way to crease an edge); colours use three shared IDs (front, back, wall).
-- [UNVERIFIED] BatchAdd(Face) default per-corner IDs (we rebind all corners, then RemoveUnused()).
-- [UNVERIFIED] colour alpha semantics (we pass 1, assuming opaque). UVs are left at default (0,0).
-- Re-centring: CreateMeshPartAsync re-centres geometry on the part (cookbook); positions here are world
-- coordinates, so place the part at em:GetCenter().
-- On carve: em:Clear() (valid only for non-FixedSize meshes, i.e. from CreateEditableMesh()) then rebuild,
-- and bake collision (CreateMeshPartAsync + ApplyMesh) debounced, once per explosion.

local COLORS = { { 120, 84, 52 }, { 70, 50, 32 }, { 92, 66, 44 } }

function ContourMesh.toEditableMesh(em: any, tile: Tile): { number }
	local vc, tc = tile.vcount, tile.tcount
	local P, N = table.create(vc), table.create(tc)
	for v = 0, vc - 1 do
		P[v + 1] = Vector3.new(buffer.readf32(tile.pos, v * 12), buffer.readf32(tile.pos, v * 12 + 4), buffer.readf32(tile.pos, v * 12 + 8))
	end
	for t = 0, tc - 1 do
		N[t + 1] = Vector3.new(buffer.readf32(tile.fnrm, t * 12), buffer.readf32(tile.fnrm, t * 12 + 4), buffer.readf32(tile.fnrm, t * 12 + 8))
	end
	local C = {}
	for k, c in COLORS do
		C[k] = Color3.fromRGB(c[1], c[2], c[3])
	end
	local vids = em:BatchAdd(Enum.MeshAttribute.Vertex, P)
	local nids = em:BatchAdd(Enum.MeshAttribute.Normal, N)
	local cids = em:BatchAdd(Enum.MeshAttribute.Color, C, { 1, 1, 1 })
	local F, FN, FC = table.create(tc), table.create(tc), table.create(tc)
	for t = 0, tc - 1 do
		F[t + 1] = {
			vids[buffer.readu32(tile.idx, t * 12) + 1],
			vids[buffer.readu32(tile.idx, t * 12 + 4) + 1],
			vids[buffer.readu32(tile.idx, t * 12 + 8) + 1],
		}
		local n, c = nids[t + 1], cids[buffer.readu8(tile.mat, t) + 1]
		FN[t + 1] = { n, n, n }
		FC[t + 1] = { c, c, c }
	end
	local fids = em:BatchAdd(Enum.MeshAttribute.Face, F)
	em:BatchSetFaceAttributes(fids, FN)
	em:BatchSetFaceAttributes(fids, FC)
	em:RemoveUnused()
	return fids
end

function ContourMesh.rebuildEditableMesh(em: any, tile: Tile): { number }
	em:Clear()
	return ContourMesh.toEditableMesh(em, tile)
end

return ContourMesh
