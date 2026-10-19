local Out = require("./Out")
local MeshViz = require("./MeshViz")
local CM = require("../mesh/ContourMesh")

local W, H = 257, 129 -- 8 x 4 tiles of 32 cells
local function hash(x: number, y: number): number
	local n = bit32.bxor(x * 374761393, y * 668265263)
	n = bit32.bxor(n, bit32.rshift(n, 13)) * 1274126177
	return bit32.band(bit32.bxor(n, bit32.rshift(n, 16)), 0xFFFF) / 0xFFFF
end
local function vnoise(x: number, y: number): number
	local xi, yi = math.floor(x), math.floor(y)
	local fx, fy = x - xi, y - yi
	fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	local a, b = hash(xi, yi), hash(xi + 1, yi)
	local c, d = hash(xi, yi + 1), hash(xi + 1, yi + 1)
	return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
end

-- Worms-style island: ground below a noisy skyline, noise caves, a floating rock. Soft density edges.
local function makeField(): CM.Field
	local f = CM.newField(W, H, { tile = 32, cell = 1, depth = 8, epsilon = 0.3, keepDebug = true })
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local ground = 58 + 22 * vnoise(x / 40, 1.5) + 8 * vnoise(x / 11, 4.2)
			local sd = y - ground -- > 0 below the surface
			local edge = math.min(x - 6, W - 7 - x, H - 4 - y) -- island sides
			sd = math.min(sd, edge)
			local cave = (vnoise(x / 14 + 9, y / 9) - 0.68) * 30
			sd = math.min(sd, -cave)
			local fx, fy = (x - 190) / 26, (y - 30) / 9
			sd = math.max(sd, (1 - math.sqrt(fx * fx + fy * fy)) * 9)
			buffer.writeu8(f.mask, y * W + x, math.clamp(math.floor(127.5 + sd * 60), 0, 255))
		end
	end
	return f
end

local f = makeField()
CM.buildAll(f)

-- Bilinear density, for checking which side of an edge is solid.
local function density(x: number, y: number): number
	x, y = math.clamp(x, 0, W - 1.0001), math.clamp(y, 0, H - 1.0001)
	local xi, yi = math.floor(x), math.floor(y)
	local fx, fy = x - xi, y - yi
	local function m(a: number, b: number): number
		return buffer.readu8(f.mask, b * W + a)
	end
	local top = m(xi, yi) + (m(xi + 1, yi) - m(xi, yi)) * fx
	local bot = m(xi, yi + 1) + (m(xi + 1, yi + 1) - m(xi, yi + 1)) * fx
	return top + (bot - top) * fy
end

local function checkField(tag: string)
	local open, loops, rawPts, keptPts, tris, verts = 0, 0, 0, 0, 0, 0
	local orientOk, orientN = 0, 0
	local nonManifold, badBoundary, badCap, badWall, wallN = 0, 0, 0, 0, 0
	local seamEdges, degenerate = 0, 0
	local maxT, maxV = 0, 0
	for _, t in f.tiles do
		open += t.openChains
		loops += #t.loops
		rawPts += t.rawPoints
		keptPts += t.keptPoints
		tris += t.tcount
		verts += t.vcount
		maxT, maxV = math.max(maxT, t.tcount), math.max(maxV, t.vcount)
		local ox, oy = t.tx * 32, t.ty * 32
		-- Raw contours: solid lies on the left of each edge (image coords y down, left normal = (dy, -dx)).
		for _, l in t.rawLoops :: { CM.Loop } do
			local n = #l.xs
			for i = 1, n do
				local j = i % n + 1
				local dx, dy = l.xs[j] - l.xs[i], l.ys[j] - l.ys[i]
				local len = math.sqrt(dx * dx + dy * dy)
				local mx, my = (l.xs[i] + l.xs[j]) / 2, (l.ys[i] + l.ys[j]) / 2
				local onBorder = (dx == 0 and (mx == 0 or mx == 32)) or (dy == 0 and (my == 0 or my == 32))
				if len > 0.3 and not onBorder then
					orientN += 1
					local nx, ny = dy / len, -dx / len
					-- Density must increase toward the left (the MS chord can cut a corner of the bilinear
					-- isoline, so test the gradient rather than absolute thresholds).
					if density(ox + mx + nx * 0.15, oy + my + ny * 0.15) > density(ox + mx - nx * 0.15, oy + my - ny * 0.15) then
						orientOk += 1
					end
				end
			end
		end
		-- Edge use: every directed edge must be matched by its reverse exactly once.
		local directed: { [number]: number } = {}
		local function P(v: number): (number, number, number)
			return buffer.readf32(t.pos, v * 12), buffer.readf32(t.pos, v * 12 + 4), buffer.readf32(t.pos, v * 12 + 8)
		end
		for k = 0, t.tcount - 1 do
			local a, b, c = buffer.readu32(t.idx, k * 12), buffer.readu32(t.idx, k * 12 + 4), buffer.readu32(t.idx, k * 12 + 8)
			for _, e in { { a, b }, { b, c }, { c, a } } do
				local key = e[1] * 65536 + e[2]
				directed[key] = (directed[key] or 0) + 1
			end
			local ax, ay, az = P(a)
			local bx, by, bz = P(b)
			local cx, cy, cz = P(c)
			local nx = (by - ay) * (cz - az) - (bz - az) * (cy - ay)
			local ny = (bz - az) * (cx - ax) - (bx - ax) * (cz - az)
			local nz = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
			local m = buffer.readu8(t.mat, k)
			if (m == 0 or m == 1) and math.abs(nz) < 1e-4 then
				degenerate += 1 -- exactly collinear sliver from ear clipping (zero area, harmless)
			elseif m == 0 and nz < 0 or m == 1 and nz > 0 then
				badCap += 1
			elseif m == 2 then
				-- Wall normal must point into empty space.
				wallN += 1
				local l = math.sqrt(nx * nx + ny * ny)
				local sx, sy = (ax + bx + cx) / 3 + nx / l * 0.6, (ay + by + cy) / 3 + ny / l * 0.6
				if density(sx, (H - 1) - sy) > 127.5 then
					badWall += 1
				end
			end
		end
		for key, count in directed do
			local a, b = key // 65536, key % 65536
			local back = directed[b * 65536 + a] or 0
			if count ~= 1 or back > 1 then
				nonManifold += 1
			elseif back == 0 then
				-- Open edge: allowed only along an interior tile seam.
				local ax, ay = buffer.readf32(t.pos, a * 12), buffer.readf32(t.pos, a * 12 + 4)
				local bx, by = buffer.readf32(t.pos, b * 12), buffer.readf32(t.pos, b * 12 + 4)
				local x0, x1 = t.tx * 32, t.tx * 32 + 32
				local y0, y1 = (H - 1) - t.ty * 32, (H - 1) - t.ty * 32 - 32
				local onSeam = (ax == bx and ((ax == x0 and t.tx > 0) or (ax == x1 and t.tx < f.ntx - 1)))
					or (ay == by and ((ay == y0 and t.ty > 0) or (ay == y1 and t.ty < f.nty - 1)))
				if onSeam then
					seamEdges += 1
				else
					badBoundary += 1
				end
			end
		end
	end
	Out.check(`contour.{tag}.closed`, open == 0, `{loops} loops, {open} open chains`)
	Out.check(`contour.{tag}.orientation_solid_left`, orientN > 0 and orientOk == orientN, `{orientOk}/{orientN} raw edges have solid on the left`)
	Out.check(`contour.{tag}.watertight`, nonManifold == 0 and badBoundary == 0, `{nonManifold} non-manifold/same-direction edges, {badBoundary} open edges off-seam, {seamEdges} open edges on interior seams (hidden walls skipped)`)
	Out.check(`contour.{tag}.caps_ccw`, badCap == 0, `{badCap} cap tris facing the wrong way, {degenerate} zero-area slivers`)
	Out.check(`contour.{tag}.walls_face_out`, wallN > 0 and badWall / wallN < 0.01, `{badWall}/{wallN} wall tris face solid`)
	Out.check(`contour.{tag}.limits`, maxT <= 20000 and maxV <= 60000, `worst tile {maxV} verts / {maxT} tris; total {verts} verts / {tris} tris`)
	Out.check(`contour.{tag}.rdp_reduces`, keptPts < rawPts, `{rawPts} -> {keptPts} contour points`)
end

-- Seam vertices match between neighbouring tiles (no cracks in the cap outline).
local function seamCheck(tag: string)
	local mismatched, total = 0, 0
	local function seamPoints(t: CM.Tile, onSide: (number, number) -> boolean): { [string]: boolean }
		local s = {}
		for v = 0, t.vcount // 2 - 1 do
			local x, y = buffer.readf32(t.pos, v * 12), buffer.readf32(t.pos, v * 12 + 4)
			if onSide(x, y) then
				s[`{x},{y}`] = true
			end
		end
		return s
	end
	for ty = 0, f.nty - 1 do
		for tx = 0, f.ntx - 2 do
			local a, b = f.tiles[ty * f.ntx + tx + 1], f.tiles[ty * f.ntx + tx + 2]
			local X = (tx + 1) * 32
			local sa = seamPoints(a, function(x)
				return x == X
			end)
			local sb = seamPoints(b, function(x)
				return x == X
			end)
			for k in sa do
				total += 1
				if not sb[k] then
					mismatched += 1
				end
			end
			for k in sb do
				if not sa[k] then
					mismatched += 1
				end
			end
		end
	end
	Out.check(`contour.{tag}.seam_vertices_match`, mismatched == 0 and total > 0, `{total} seam vertices, {mismatched} unmatched`)
end

checkField("initial")
seamCheck("initial")

-- Earcut sanity: square with a square hole -> 8 triangles of total area 16 - 4.
do
	local tri = CM.earcut({ 0, 0, 4, 0, 4, 4, 0, 4, 1, 1, 1, 3, 3, 3, 3, 1 }, { 4 })
	local d = { 0, 0, 4, 0, 4, 4, 0, 4, 1, 1, 1, 3, 3, 3, 3, 1 }
	local area = 0
	for k = 1, #tri, 3 do
		local a, b, c = tri[k], tri[k + 1], tri[k + 2]
		area += ((d[2 * b + 1] - d[2 * a + 1]) * (d[2 * c + 2] - d[2 * a + 2]) - (d[2 * c + 1] - d[2 * a + 1]) * (d[2 * b + 2] - d[2 * a + 2])) / 2
	end
	Out.check("contour.earcut_square_hole", #tri == 24 and math.abs(math.abs(area) - 12) < 1e-9, `{#tri // 3} tris, area {area}`)
end

-- Pictures + carving ---------------------------------------------------------------------------------------
local TILECOL = { { 150, 108, 70 }, { 128, 94, 62 } }
local function render(): any
	local v = MeshViz.new(768, 400)
	v:clear(140, 180, 225)
	v:lookAt(128 + 70, 64 + 60, 260, 128, 60, 0, nil, 75)
	for _, t in f.tiles do
		local base = TILECOL[(t.tx + t.ty) % 2 + 1]
		v:mesh(t.pos, t.idx, t.tcount, {
			color = function(k: number)
				local m = buffer.readu8(t.mat, k)
				if m == 2 then
					return 95, 80, 64
				end
				return base[1], base[2], base[3]
			end,
			wire = {},
		})
	end
	return v
end
local before = render()

local carves = { { 70, 60, 9 }, { 96, 66, 7 }, { 128, 80, 12 }, { 160, 64, 6 }, { 192, 30, 7 }, { 44, 90, 8 }, { 224, 72, 10 } }
local rebuiltTotal = 0
for _, c in carves do
	rebuiltTotal += #CM.carveCircle(f, c[1], c[2], c[3])
end
-- A tunnel of overlapping carves crossing tile seams, and a painted bridge.
for k = 0, 12 do
	rebuiltTotal += #CM.carveCircle(f, 20 + k * 6, 100 - k * 2, 3.5)
end
for k = 0, 10 do
	rebuiltTotal += #CM.paintCircle(f, 150 + k * 4, 46 - k, 2.5)
end
Out.check("contour.carve_rebuilds_few_tiles", rebuiltTotal > 0 and rebuiltTotal < 3 * (#carves + 24), `{rebuiltTotal} tile rebuilds for {#carves + 24} stamps`)

-- Incremental rebuild == rebuilding everything from the edited mask.
do
	local same = true
	for k, t in f.tiles do
		local fresh = CM.buildTile(f, t.tx, t.ty)
		if buffer.tostring(fresh.pos) ~= buffer.tostring(t.pos) or buffer.tostring(fresh.idx) ~= buffer.tostring(t.idx) then
			same = false
		end
	end
	Out.check("contour.incremental_equals_full", same)
end
checkField("carved")
seamCheck("carved")

local after = render()
local img, iw, ih = MeshViz.sideBySide(before, after)
Out.image("mesh_contour_before_after", iw, ih, img)

-- Front view, orthographic and straight on, to see the outline and the cap triangulation.
do
	local v = MeshViz.new(1028, 516)
	v:clear(140, 180, 225)
	v:lookAt(128, 64, 300, 128, 64, 0, nil, 64.5)
	for _, t in f.tiles do
		local base = TILECOL[(t.tx + t.ty) % 2 + 1]
		v:mesh(t.pos, t.idx, t.tcount, {
			color = function()
				return base[1], base[2], base[3]
			end,
			wire = {},
		})
	end
	Out.image("mesh_contour_carved_front", v.w, v.h, v.rgba)
end

-- Timings ---------------------------------------------------------------------------------------------------
f.keepDebug = false
local saved = buffer.create(W * H)
buffer.copy(saved, 0, f.mask)
Out.time("contour.build_all_32_tiles", 5, function()
	CM.buildAll(f)
end)
local spot = 0
Out.time("contour.carve_r6_plus_rebuild_1_tile", 50, function()
	buffer.copy(f.mask, 0, saved) -- restore so every carve does real work (~33 KB copy)
	spot = (spot + 1) % 8
	CM.carveCircle(f, 112 + spot, 110, 6) -- stays inside tile (3, 3)
end)
Out.time("contour.build_tile_3_3", 50, function()
	CM.buildTile(f, 3, 3)
end)
buffer.copy(f.mask, 0, saved)
local r = CM.carveCircle(f, 113, 110, 6)
Out.check("contour.timed_carve_hits_one_tile", #r == 1 and r[1] == 3 * f.ntx + 4, `{#r} tiles rebuilt`)

Out.done()
