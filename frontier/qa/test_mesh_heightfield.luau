local Out = require("./Out")
local MeshViz = require("./MeshViz")
local HM = require("../mesh/HeightfieldMesh")

-- Deterministic value noise -> f32 height image in [0,1].
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
local function makeImage(n: number): HM.Image
	local data = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local h = 0.55 * vnoise(x / 64, y / 64) + 0.3 * vnoise(x / 23 + 7, y / 23) + 0.15 * vnoise(x / 9, y / 9 + 3)
			buffer.writef32(data, (y * n + x) * 4, h * h * 1.4)
		end
	end
	return { w = n, h = n, data = data, format = "f32" }
end
local function cloneImage(img: HM.Image): HM.Image
	local d = buffer.create(buffer.len(img.data))
	buffer.copy(d, 0, img.data)
	return { w = img.w, h = img.h, data = d, format = img.format }
end

local N = 513 -- 8x8 chunks
local OPTS = { cell = 2, heightScale = 60, ranges = { 160, 600 }, morphFrac = 0.35, hysteresis = 8, skirt = 3, camX = 120, camZ = 140 }
local img = makeImage(N)
local terrain = HM.newTerrain(img, OPTS)

-- Limits --------------------------------------------------------------------------------------------------
local worstT, worstV, okLimits = 0, 0, true
for level = 0, 2 do
	local c = HM.buildChunk(terrain, 1, 1, level)
	worstT, worstV = math.max(worstT, c.tcount), math.max(worstV, c.vcount)
	okLimits = okLimits and c.tcount <= 20000 and c.vcount <= 60000
	Out.check(`heightfield.lod{level}_counts`, c.tcount <= 20000 and c.vcount <= 60000, `step {c.step}: {c.vcount} verts, {c.tcount} tris`)
end
local levels = { 0, 0, 0 }
for _, c in terrain.chunks do
	okLimits = okLimits and c.tcount <= 20000 and c.vcount <= 60000
	levels[c.level + 1] += 1
end
Out.check("heightfield.all_chunks_within_limits", okLimits, `worst {worstV} verts / {worstT} tris; chunks per LOD {levels[1]}/{levels[2]}/{levels[3]}`)
Out.check("heightfield.three_lods_present", levels[1] > 0 and levels[2] > 0 and levels[3] > 0)

-- Normals unit length, winding --------------------------------------------------------------------------------
local maxErr, badUp, badSkirt = 0, 0, 0
for _, c in terrain.chunks do
	for v = 0, c.vcount - 1 do
		local x, y, z = buffer.readf32(c.nrm, v * 12), buffer.readf32(c.nrm, v * 12 + 4), buffer.readf32(c.nrm, v * 12 + 8)
		maxErr = math.max(maxErr, math.abs(math.sqrt(x * x + y * y + z * z) - 1))
	end
	local surf = 2 * c.n * c.n
	for t = 0, c.tcount - 1 do
		local p = {}
		for k = 0, 2 do
			local v = buffer.readu32(c.idx, t * 12 + k * 4)
			p[k] = { buffer.readf32(c.pos, v * 12), buffer.readf32(c.pos, v * 12 + 4), buffer.readf32(c.pos, v * 12 + 8) }
		end
		local ux, uy, uz = p[1][1] - p[0][1], p[1][2] - p[0][2], p[1][3] - p[0][3]
		local vx, vy, vz = p[2][1] - p[0][1], p[2][2] - p[0][2], p[2][3] - p[0][3]
		local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
		if t < surf then
			if ny <= 0 then
				badUp += 1
			end
		else
			-- Skirt faces point away from the chunk centre (positions are centred).
			local mx, mz = (p[0][1] + p[1][1] + p[2][1]) / 3, (p[0][3] + p[1][3] + p[2][3]) / 3
			if nx * mx + nz * mz <= 0 then
				badSkirt += 1
			end
		end
	end
end
Out.check("heightfield.normals_unit", maxErr < 1e-5, `max |len-1| = {maxErr}`)
Out.check("heightfield.surface_ccw_up", badUp == 0, `{badUp} downward surface tris`)
Out.check("heightfield.skirts_face_out", badSkirt == 0, `{badSkirt} inward skirt tris`)

-- Geomorph: at morph = 1 a step-s chunk lies exactly on the step-2s surface --------------------------------
do
	local fine = HM.buildChunk(terrain, 3, 2, 0)
	local coarse = HM.buildChunk(terrain, 3, 2, 1)
	HM.setUniformMorph(terrain, fine, 1)
	local function Yc(i: number, j: number): number
		return buffer.readf32(coarse.baseH, (j * coarse.side + i) * 4)
	end
	local err = 0
	for j = 0, fine.n do
		for i = 0, fine.n do
			local y = buffer.readf32(fine.pos, (j * fine.side + i) * 12 + 4)
			local I, J = i // 2, j // 2
			local want
			if i % 2 == 0 and j % 2 == 0 then
				want = Yc(I, J)
			elseif j % 2 == 0 then
				want = (Yc(I, J) + Yc(I + 1, J)) / 2
			elseif i % 2 == 0 then
				want = (Yc(I, J) + Yc(I, J + 1)) / 2
			else
				want = (Yc(I, J) + Yc(I + 1, J + 1)) / 2
			end
			err = math.max(err, math.abs(y - want))
		end
	end
	Out.check("heightfield.geomorph_full_matches_coarse", err < 1e-4, `max err {err} studs`)
	HM.setUniformMorph(terrain, fine, 0)
	local changed = fine.changedCount
	local err0 = 0
	for v = 0, fine.gridCount - 1 do
		err0 = math.max(err0, math.abs(buffer.readf32(fine.pos, v * 12 + 4) - buffer.readf32(fine.baseH, v * 4)))
	end
	Out.check("heightfield.geomorph_zero_is_own_level", err0 == 0 and changed > 0, `{changed} verts moved back from m=1`)
end

-- LOD switch is pop-free: just before coarsening every vertex is fully morphed; after the switch the coarse
-- chunk (unmorphed there) occupies exactly that surface.
do
	local t2 = HM.newTerrain(img, OPTS)
	local cx, cy = 2, 0
	local key = cy * t2.ncx + cx + 1
	local span = 64 * OPTS.cell
	local function camFor(d: number)
		HM.setCamera(t2, cx * span - d, span * 0.5)
	end
	camFor(100)
	local before = t2.chunks[key]
	camFor(OPTS.ranges[1] + OPTS.hysteresis - 1)
	local stillFine = t2.chunks[key] == before and before.level == 0
	local yFine = {}
	for v = 0, before.gridCount - 1 do
		yFine[v] = buffer.readf32(before.pos, v * 12 + 4)
	end
	camFor(OPTS.ranges[1] + OPTS.hysteresis + 1)
	local after = t2.chunks[key]
	local pop = 0
	for j = 0, before.n do
		for i = 0, before.n do
			local I0, J0, I1, J1 = i // 2, j // 2, (i + 1) // 2, (j + 1) // 2
			local function Y(I: number, J: number): number
				return buffer.readf32(after.pos, (J * after.side + I) * 12 + 4)
			end
			local want = (Y(I0, J0) + Y(I1, J1)) / 2 -- even: same vertex twice; odd: the coarse edge midpoint
			pop = math.max(pop, math.abs(yFine[j * before.side + i] - want))
		end
	end
	Out.check("heightfield.lod_switch_no_pop", stillFine and after.level == 1 and pop < 1e-4, `pop {pop} studs (hysteresis held: {stillFine})`)
end

-- Incremental update == full rebuild ---------------------------------------------------------------------
local function brush(im: HM.Image, x0: number, y0: number, size: number, amount: number)
	for y = y0, y0 + size - 1 do
		for x = x0, x0 + size - 1 do
			local i = (y * im.w + x) * 4
			local dx, dy = x - (x0 + (size - 1) / 2), y - (y0 + (size - 1) / 2)
			buffer.writef32(im.data, i, buffer.readf32(im.data, i) + amount * math.exp(-(dx * dx + dy * dy) / (size * 2)))
		end
	end
end
local function snapshot(t: HM.Terrain)
	local s = {}
	for k, c in t.chunks do
		s[k] = { pos = buffer.tostring(c.pos), nrm = buffer.tostring(c.nrm), col = buffer.tostring(c.col) }
	end
	return s
end
local function vertexDiff(a: string, b: string, stride: number, out: { [number]: boolean })
	for v = 0, #a // stride - 1 do
		if string.sub(a, v * stride + 1, v * stride + stride) ~= string.sub(b, v * stride + 1, v * stride + stride) then
			out[v] = true
		end
	end
end

local strokes = { { 60, 124 }, { 400, 330 }, { 0, 250 }, { 505, 505 } } -- chunk corners, far LOD, image edges
local listOk, listDetail = true, ""
for _, s in strokes do
	local pre = snapshot(terrain)
	brush(img, s[1], s[2], 8, 0.08)
	local dirty = HM.updateRect(terrain, s[1], s[2], s[1] + 7, s[2] + 7)
	local listed: { [any]: { [number]: boolean } } = {}
	for _, c in dirty do
		local set = {}
		for k = 0, c.changedCount - 1 do
			set[buffer.readu32(c.changed, k * 4)] = true
		end
		listed[c] = set
	end
	for k, c in terrain.chunks do
		local diff = {}
		vertexDiff(pre[k].pos, buffer.tostring(c.pos), 12, diff)
		vertexDiff(pre[k].nrm, buffer.tostring(c.nrm), 12, diff)
		vertexDiff(pre[k].col, buffer.tostring(c.col), 4, diff)
		local set = listed[c] or {}
		for v in diff do
			if not set[v] then
				listOk = false
				listDetail = `chunk {k} vertex {v} changed but unlisted`
			end
		end
		for v in set do
			if not diff[v] then
				listOk = false
				listDetail = `chunk {k} vertex {v} listed but unchanged`
			end
		end
	end
end
Out.check("heightfield.changed_list_exact", listOk, listDetail)

local fresh = HM.newTerrain(img, OPTS)
local same, nTouched = true, 0
for k, c in terrain.chunks do
	local f = fresh.chunks[k]
	for _, field in { "pos", "nrm", "uv", "col", "baseH", "coarseH", "idx" } do
		if buffer.tostring((c :: any)[field]) ~= buffer.tostring((f :: any)[field]) then
			same = false
			listDetail = `chunk {k} field {field}`
		end
	end
end
Out.check("heightfield.incremental_equals_full_rebuild", same, if same then "byte-identical, 4 strokes incl. seams + edges" else listDetail)

-- Per-frame morph (setCamera) gives the same bytes as building fresh at that camera.
do
	local moved = HM.newTerrain(img, OPTS)
	HM.setCamera(moved, OPTS.camX + 37.25, OPTS.camZ + 11.5)
	local again = HM.newTerrain(img, { cell = OPTS.cell, heightScale = OPTS.heightScale, ranges = OPTS.ranges, morphFrac = OPTS.morphFrac, hysteresis = OPTS.hysteresis, skirt = OPTS.skirt, camX = OPTS.camX + 37.25, camZ = OPTS.camZ + 11.5 })
	local ok, compared = true, 0
	for k, c in moved.chunks do
		if c.level == again.chunks[k].level then
			compared += 1
			ok = ok and buffer.tostring(c.pos) == buffer.tostring(again.chunks[k].pos)
		end
	end
	Out.check("heightfield.setCamera_equals_fresh_build", ok and compared > 50, `{compared} chunks compared`)
end

-- u8 / RGBA8 sources -------------------------------------------------------------------------------------------
do
	local n = 65
	local u8, rgba = buffer.create(n * n), buffer.create(n * n * 4)
	for i = 0, n * n - 1 do
		local v = (i * 7) % 256
		buffer.writeu8(u8, i, v)
		buffer.writeu8(rgba, i * 4, v)
	end
	local a = HM.newTerrain({ w = n, h = n, data = u8, format = "u8" }, { heightScale = 0.25 })
	local b = HM.newTerrain({ w = n, h = n, data = rgba, format = "rgba8" }, { heightScale = 0.25 })
	local ca, cb = a.chunks[1], b.chunks[1]
	Out.check("heightfield.u8_and_rgba8_sources", buffer.tostring(ca.pos) == buffer.tostring(cb.pos) and math.abs(buffer.readf32(ca.baseH, 4 * 3) - 21 * 0.25) < 1e-6)
end

-- Timings --------------------------------------------------------------------------------------------------
Out.time("heightfield.build_chunk_step1", 20, function()
	HM.buildChunk(terrain, 2, 2, 0)
end)
Out.time("heightfield.build_chunk_step4", 50, function()
	HM.buildChunk(terrain, 2, 2, 2)
end)
local sign = 1
Out.time("heightfield.brush8x8_incremental", 200, function()
	sign = -sign
	brush(img, 60, 124, 8, 0.02 * sign) -- spans 4 chunks
	HM.updateRect(terrain, 60, 124, 67, 131)
end)
Out.time("heightfield.brush8x8_one_chunk", 200, function()
	sign = -sign
	brush(img, 20, 20, 8, 0.02 * sign)
	HM.updateRect(terrain, 20, 20, 27, 27)
end)
local camT = 0
Out.time("heightfield.setCamera_morph_64_chunks", 20, function()
	camT += 1
	HM.setCamera(terrain, 120 + (camT % 2) * 0.5, 140)
end)
HM.setCamera(terrain, OPTS.camX, OPTS.camZ)

-- Pictures -------------------------------------------------------------------------------------------------
-- A painted crater + ridge so the sculpting shows up.
for k = 0, 10 do
	brush(img, 90 + k * 4, 60 + k * 3, 8, -0.06)
	HM.updateRect(terrain, 90 + k * 4, 60 + k * 3, 97 + k * 4, 67 + k * 3)
end
local LODCOL = { { 90, 200, 95 }, { 235, 200, 70 }, { 225, 90, 75 } }
local function drawTerrain(v: any, wire: boolean)
	for _, c in terrain.chunks do
		local ox, oz = HM.chunkOrigin(terrain, c)
		local col = LODCOL[c.level + 1]
		v:mesh(c.pos, c.idx, c.tcount, {
			offset = { ox, 0, oz },
			color = function()
				return col[1], col[2], col[3]
			end,
			wire = if wire then {} else nil,
		})
	end
end
local viz = MeshViz.new(720, 420)
viz:clear(150, 185, 230)
viz:lookAt(40, 150, 20, 560, -40, 600, 62)
drawTerrain(viz, true)
Out.image("mesh_terrain_lod_perspective", viz.w, viz.h, viz.rgba)

local top = MeshViz.new(512, 512)
top:clear(20, 20, 30)
top:lookAt(512, 900, 512, 512, 0, 512, nil, 520)
drawTerrain(top, false)
local span = 64 * OPTS.cell
for k = 0, terrain.ncx do
	top:line3(k * span, 80, 0, k * span, 80, 1024, 20, 20, 20, true)
	top:line3(0, 80, k * span, 1024, 80, k * span, 20, 20, 20, true)
end
for _, r in OPTS.ranges do -- LOD switch radii around the camera
	for a = 0, 127 do
		local t0, t1 = a / 128 * 2 * math.pi, (a + 1) / 128 * 2 * math.pi
		top:line3(OPTS.camX + r * math.cos(t0), 80, OPTS.camZ + r * math.sin(t0), OPTS.camX + r * math.cos(t1), 80, OPTS.camZ + r * math.sin(t1), 255, 255, 255, true)
	end
end
-- Camera marker
local mx, my = top:project(OPTS.camX, 0, OPTS.camZ)
for dy = -4, 4 do
	for dx = -4, 4 do
		local x, y = math.floor(mx) + dx, math.floor(my) + dy
		if x >= 0 and y >= 0 and x < top.w and y < top.h then
			buffer.writeu32(top.rgba, (y * top.w + x) * 4, 0xFFFFFFFF)
		end
	end
end
Out.image("mesh_terrain_lod_topdown", top.w, top.h, top.rgba)

local close = MeshViz.new(512, 384)
close:clear(150, 185, 230)
close:lookAt(120, 140, -40, 230, 20, 170, 50)
for _, c in terrain.chunks do
	local ox, oz = HM.chunkOrigin(terrain, c)
	close:mesh(c.pos, c.idx, c.tcount, { offset = { ox, 0, oz }, vcol = c.col })
end
Out.image("mesh_terrain_sculpted_shaded", close.w, close.h, close.rgba)

Out.done()
