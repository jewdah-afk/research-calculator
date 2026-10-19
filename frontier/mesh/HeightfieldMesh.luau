--!native
--!optimize 2
-- HeightfieldMesh: "paint-to-geometry". A height image (u8, f32 or RGBA8 from EditableImage:ReadPixelsBuffer)
-- becomes a grid of 64x64-quad terrain chunks, one EditableMesh each.
--
-- Technique (CDLOD-style):
--   * Chunk LOD by camera distance: step 1/2/4 samples (8192 / 2048 / 512 surface tris + skirts).
--   * Geomorphing: every vertex stores its own height and the height of the next-coarser level at the same
--     point (odd vertices lie on a coarse edge/diagonal, so that is the mean of two coarse corners). The drawn
--     height blends toward the coarse one by vertex distance, reaching it exactly where the chunk switches
--     level, so switches do not pop.
--   * Skirts: a 4-sided curtain hanging `skirt` studs below each chunk edge hides residual LOD cracks.
--   * Smooth normals by central differences at the LOD's own spacing; vertex colour by height and slope.
--   * Incremental update: a dirty rect of the image touches only vertices within `step` samples of it (their
--     height, normal stencil or morph target reads it). Those are recomputed with the same per-vertex function
--     as the full build, so the result is bit-identical, and the changed vertex indices are listed per chunk.
-- Normals are not morphed (they belong to each vertex's own level); only heights blend.
-- Cost: full step-1 chunk build ~4.5k vertices; an 8x8 brush recomputes ~100 vertices in 1-4 chunks.
-- Morph updates touch only vertex Y. No allocation in updateRect / applyMorph.
-- Pure Luau except the ROBLOX ADAPTER section at the bottom.

local HeightfieldMesh = {}

local CHUNK = 64 -- quads per chunk side at step 1
local MAX_TRIS, MAX_VERTS = 20000, 60000
local INF = math.huge

HeightfieldMesh.CHUNK = CHUNK
HeightfieldMesh.STEPS = { 1, 2, 4 }

export type Image = { w: number, h: number, data: buffer, format: string } -- "u8" | "f32" | "rgba8" (R channel)

export type Chunk = {
	cx: number,
	cy: number,
	level: number,
	step: number,
	n: number, -- quads per side
	side: number, -- vertices per side
	ox: number, -- sample origin
	oy: number,
	gridCount: number,
	vcount: number,
	tcount: number,
	pos: buffer, -- f32 x3, chunk-local (centred in XZ, Y = world height)
	nrm: buffer, -- f32 x3
	uv: buffer, -- f32 x2
	col: buffer, -- u32 RGBA8 (r in low byte)
	baseH: buffer, -- f32, own height
	coarseH: buffer, -- f32, morph target
	idx: buffer, -- u32 x3, CCW seen from above
	morphStart: number,
	morphEnd: number,
	forceMorph: number?,
	morphState: number, -- 0 / 1 = every vertex at that morph factor, 2 = mixed, -1 = unknown
	changed: buffer, -- u32 vertex indices touched by the last updateRect/applyMorph
	changedCount: number,
	changedAttrs: number, -- bit 1 = positions, bit 2 = normals+colours
}

export type Terrain = {
	w: number,
	h: number,
	img: Image,
	hbuf: buffer, -- f32 heights in studs (converted copy of img)
	cell: number,
	heightScale: number,
	maxHeight: number,
	skirt: number,
	uvTile: number,
	ranges: { number },
	morphFrac: number,
	hysteresis: number,
	ncx: number,
	ncy: number,
	chunks: { Chunk },
	camX: number,
	camZ: number,
	dirty: { Chunk },
	colorFn: ((gx: number, gy: number, h: number, ny: number) -> number)?, -- per-vertex RGBA8 override
	skirtFloor: number?, -- skirt bottoms at this Y instead of top - skirt
}

-- Core -------------------------------------------------------------------------------------------------------

local function syncRect(t: Terrain, x0: number, y0: number, x1: number, y1: number)
	local img, w, hb, s = t.img, t.w, t.hbuf, t.heightScale
	local data, fmt = img.data, img.format
	for y = y0, y1 do
		for x = x0, x1 do
			local i = y * w + x
			local v
			if fmt == "f32" then
				v = buffer.readf32(data, i * 4)
			elseif fmt == "u8" then
				v = buffer.readu8(data, i)
			else
				v = buffer.readu8(data, i * 4)
			end
			buffer.writef32(hb, i * 4, v * s)
		end
	end
end

local function H(t: Terrain, x: number, y: number): number
	local w, h = t.w, t.h
	if x < 0 then
		x = 0
	elseif x >= w then
		x = w - 1
	end
	if y < 0 then
		y = 0
	elseif y >= h then
		y = h - 1
	end
	return buffer.readf32(t.hbuf, (y * w + x) * 4)
end

local function packColor(r: number, g: number, b: number): number
	return bit32.bor(math.floor(r), bit32.lshift(math.floor(g), 8), bit32.lshift(math.floor(b), 16), 0xFF000000)
end

-- Sand -> grass -> rock (steep) -> snow (high).
local function terrainColor(h: number, maxH: number, ny: number): number
	local t = h / maxH
	local r, g, b
	if t < 0.15 then
		r, g, b = 194, 178, 128
	elseif t < 0.7 then
		local k = (t - 0.15) / 0.55
		r, g, b = 86 - 30 * k, 140 - 40 * k, 60 - 10 * k
	else
		r, g, b = 235, 238, 242
	end
	local rock = math.clamp((0.85 - ny) * 4, 0, 1) -- slope > ~32 deg fades to rock
	r += (120 - r) * rock
	g += (110 - g) * rock
	b += (100 - b) * rock
	return packColor(r, g, b)
end

local function morphFactor(c: Chunk, wx: number, wz: number, camX: number, camZ: number): number
	local f = c.forceMorph
	if f then
		return f
	end
	local ms = c.morphStart
	if ms == INF then
		return 0
	end
	local dx, dz = wx - camX, wz - camZ
	local d = math.sqrt(dx * dx + dz * dz)
	local m = (d - ms) / (c.morphEnd - ms)
	return if m < 0 then 0 elseif m > 1 then 1 else m
end

-- Morphed Y from the stored f32 base/coarse heights (both paths use this, so results are bit-identical).
local function morphY(t: Terrain, c: Chunk, v: number, gx: number, gy: number): number
	local b = buffer.readf32(c.baseH, v * 4)
	local cc = buffer.readf32(c.coarseH, v * 4)
	local cell = t.cell
	return b + (cc - b) * morphFactor(c, gx * cell, gy * cell, t.camX, t.camZ)
end

local function markChanged(c: Chunk, v: number)
	buffer.writeu32(c.changed, c.changedCount * 4, v)
	c.changedCount += 1
end

-- Recompute grid vertex (i, j). Returns attribute bits that changed.
local function gridVertex(t: Terrain, c: Chunk, i: number, j: number): number
	local s = c.step
	local gx, gy = c.ox + i * s, c.oy + j * s
	local v = j * c.side + i
	local h, hc, hl, hr, hu, hd
	local w = t.w
	if gx >= s and gy >= s and gx + s < w and gy + s < t.h then -- interior: same samples, no clamping
		local hb, o, so, ro = t.hbuf, (gy * w + gx) * 4, s * 4, s * w * 4
		h = buffer.readf32(hb, o)
		hl, hr = buffer.readf32(hb, o - so), buffer.readf32(hb, o + so)
		hu, hd = buffer.readf32(hb, o - ro), buffer.readf32(hb, o + ro)
		if i % 2 == 1 then
			if j % 2 == 1 then
				hc = (buffer.readf32(hb, o - ro - so) + buffer.readf32(hb, o + ro + so)) * 0.5
			else
				hc = (hl + hr) * 0.5
			end
		elseif j % 2 == 1 then
			hc = (hu + hd) * 0.5
		else
			hc = h
		end
	else
		h = H(t, gx, gy)
		hl, hr, hu, hd = H(t, gx - s, gy), H(t, gx + s, gy), H(t, gx, gy - s), H(t, gx, gy + s)
		if i % 2 == 1 then
			if j % 2 == 1 then -- on the coarse quad's diagonal (i-1,j-1)->(i+1,j+1)
				hc = (H(t, gx - s, gy - s) + H(t, gx + s, gy + s)) * 0.5
			else
				hc = (hl + hr) * 0.5
			end
		elseif j % 2 == 1 then
			hc = (hu + hd) * 0.5
		else
			hc = h
		end
	end
	buffer.writef32(c.baseH, v * 4, h)
	buffer.writef32(c.coarseH, v * 4, hc)

	local inv = 1 / (2 * s * t.cell)
	local nx = -(hr - hl) * inv
	local nz = -(hd - hu) * inv
	local il = 1 / math.sqrt(nx * nx + 1 + nz * nz)
	nx, nz = nx * il, nz * il
	local ny = il

	local bits = 0
	local pos, nrm, o = c.pos, c.nrm, v * 12
	local oy = buffer.readf32(pos, o + 4)
	-- no morph band (and no forced morph): morphY would return the stored base height unchanged
	buffer.writef32(pos, o + 4, if c.morphStart == INF and c.forceMorph == nil then buffer.readf32(c.baseH, v * 4) else morphY(t, c, v, gx, gy))
	if buffer.readf32(pos, o + 4) ~= oy then
		bits = 1
	end
	local a, b2, d = buffer.readf32(nrm, o), buffer.readf32(nrm, o + 4), buffer.readf32(nrm, o + 8)
	buffer.writef32(nrm, o, nx)
	buffer.writef32(nrm, o + 4, ny)
	buffer.writef32(nrm, o + 8, nz)
	local cf = t.colorFn
	local col = if cf then cf(gx, gy, h, ny) else terrainColor(h, t.maxHeight, ny)
	if
		buffer.readf32(nrm, o) ~= a
		or buffer.readf32(nrm, o + 4) ~= b2
		or buffer.readf32(nrm, o + 8) ~= d
		or buffer.readu32(c.col, v * 4) ~= col
	then
		bits = bit32.bor(bits, 2)
	end
	buffer.writeu32(c.col, v * 4, col)
	return bits
end

-- Skirt vertex k (edge e = k // side, position along edge q) copies its top vertex, dropped by t.skirt
-- (or placed at Y = t.skirtFloor when set: flat-bottomed side walls, e.g. a diorama/table base).
local function skirtTop(c: Chunk, e: number, q: number): number
	local side, n = c.side, c.n
	if e == 0 then
		return q -- j = 0
	elseif e == 1 then
		return n * side + q -- j = n
	elseif e == 2 then
		return q * side -- i = 0
	end
	return q * side + n -- i = n
end

local function skirtVertex(t: Terrain, c: Chunk, k: number): number
	local side = c.side
	local top = skirtTop(c, k // side, k % side)
	local v = c.gridCount + k
	local pos, nrm, o, ot = c.pos, c.nrm, v * 12, top * 12
	local before = buffer.readf32(pos, o + 4)
	local floor = t.skirtFloor
	buffer.writef32(pos, o + 4, if floor then floor else buffer.readf32(pos, ot + 4) - t.skirt)
	local bits = if buffer.readf32(pos, o + 4) ~= before then 1 else 0
	if
		buffer.readf32(nrm, o) ~= buffer.readf32(nrm, ot)
		or buffer.readf32(nrm, o + 4) ~= buffer.readf32(nrm, ot + 4)
		or buffer.readf32(nrm, o + 8) ~= buffer.readf32(nrm, ot + 8)
		or buffer.readu32(c.col, v * 4) ~= buffer.readu32(c.col, top * 4)
	then
		bits = bit32.bor(bits, 2)
	end
	buffer.copy(nrm, o, nrm, ot, 12)
	buffer.copy(c.col, v * 4, c.col, top * 4, 4)
	return bits
end

local function levelOf(t: Terrain, cx: number, cy: number): (number, number)
	-- XZ distance from camera to the chunk's AABB.
	local span = CHUNK * t.cell
	local x0, z0 = cx * span, cy * span
	local dx = math.max(x0 - t.camX, 0, t.camX - (x0 + span))
	local dz = math.max(z0 - t.camZ, 0, t.camZ - (z0 + span))
	local d = math.sqrt(dx * dx + dz * dz)
	local r = t.ranges
	for L = 1, #r do
		if d < r[L] then
			return L - 1, d
		end
	end
	return #r, d
end

local function setMorphRange(t: Terrain, c: Chunk)
	local R = t.ranges[c.level + 1]
	if R then
		c.morphStart, c.morphEnd = R * (1 - t.morphFrac), R
	else
		c.morphStart, c.morphEnd = INF, INF
	end
end

-- 0 / 1 when the whole chunk sits below / beyond the morph band, else 2.
local function morphStateOf(t: Terrain, c: Chunk): number
	if c.forceMorph then
		return -1
	end
	if c.morphStart == INF then
		return 0
	end
	local cell = t.cell
	local x0, x1, z0, z1 = c.ox * cell, (c.ox + CHUNK) * cell, c.oy * cell, (c.oy + CHUNK) * cell
	local dx = math.max(x0 - t.camX, 0, t.camX - x1)
	local dz = math.max(z0 - t.camZ, 0, t.camZ - z1)
	if math.sqrt(dx * dx + dz * dz) >= c.morphEnd then
		return 1
	end
	local fx = math.max(math.abs(x0 - t.camX), math.abs(x1 - t.camX))
	local fz = math.max(math.abs(z0 - t.camZ), math.abs(z1 - t.camZ))
	return if math.sqrt(fx * fx + fz * fz) <= c.morphStart then 0 else 2
end

-- Build one chunk at LOD level (0 => step 1). Allocates (topology change); not a per-frame path.
function HeightfieldMesh.buildChunk(t: Terrain, cx: number, cy: number, level: number): Chunk
	local step = 2 ^ level
	local n = CHUNK // step
	local side = n + 1
	local gridCount = side * side
	local vcount = gridCount + 4 * side
	local tcount = 2 * n * n + 8 * n
	assert(tcount <= MAX_TRIS and vcount <= MAX_VERTS, "chunk exceeds EditableMesh limits")
	local c: Chunk = {
		cx = cx,
		cy = cy,
		level = level,
		step = step,
		n = n,
		side = side,
		ox = cx * CHUNK,
		oy = cy * CHUNK,
		gridCount = gridCount,
		vcount = vcount,
		tcount = tcount,
		pos = buffer.create(vcount * 12),
		nrm = buffer.create(vcount * 12),
		uv = buffer.create(vcount * 8),
		col = buffer.create(vcount * 4),
		baseH = buffer.create(gridCount * 4),
		coarseH = buffer.create(gridCount * 4),
		idx = buffer.create(tcount * 12),
		morphStart = INF,
		morphEnd = INF,
		forceMorph = nil,
		morphState = -1,
		changed = buffer.create(vcount * 4),
		changedCount = 0,
		changedAttrs = 0,
	}
	setMorphRange(t, c)
	local cell, half, uvTile = t.cell, CHUNK * 0.5, t.uvTile
	local pos, uv = c.pos, c.uv
	for j = 0, n do
		for i = 0, n do
			local v = j * side + i
			local gx, gy = c.ox + i * step, c.oy + j * step
			buffer.writef32(pos, v * 12, (gx - c.ox - half) * cell)
			buffer.writef32(pos, v * 12 + 8, (gy - c.oy - half) * cell)
			buffer.writef32(uv, v * 8, gx / uvTile)
			buffer.writef32(uv, v * 8 + 4, gy / uvTile)
			gridVertex(t, c, i, j)
		end
	end
	for k = 0, 4 * side - 1 do
		local v, top = gridCount + k, skirtTop(c, k // side, k % side)
		buffer.copy(pos, v * 12, pos, top * 12, 12)
		buffer.copy(uv, v * 8, uv, top * 8, 8)
		skirtVertex(t, c, k)
	end

	-- Surface: diagonal (i,j)->(i+1,j+1) in every quad (the geomorph targets assume it).
	local idx, o = c.idx, 0
	local function tri(a: number, b: number, d: number)
		buffer.writeu32(idx, o, a)
		buffer.writeu32(idx, o + 4, b)
		buffer.writeu32(idx, o + 8, d)
		o += 12
	end
	for j = 0, n - 1 do
		for i = 0, n - 1 do
			local a = j * side + i
			local b, cc, d = a + 1, a + side, a + side + 1
			tri(a, cc, d)
			tri(a, d, b)
		end
	end
	-- Skirts, wound to face outward.
	for e = 0, 3 do
		local base = gridCount + e * side
		for q = 0, n - 1 do
			local a, b = skirtTop(c, e, q), skirtTop(c, e, q + 1)
			local a2, b2 = base + q, base + q + 1
			if e == 0 or e == 3 then -- -Z and +X edges
				tri(a, b, b2)
				tri(a, b2, a2)
			else -- +Z and -X edges
				tri(a, b2, b)
				tri(a, a2, b2)
			end
		end
	end
	assert(o == tcount * 12)
	c.changedCount, c.changedAttrs = 0, 0
	c.morphState = morphStateOf(t, c)
	return c
end

-- opts: cell (studs/sample), heightScale (studs per image unit), ranges ({r0, r1} studs), morphFrac,
-- hysteresis (studs), skirt (studs), uvTile (samples per texture repeat), camX/camZ,
-- colorFn(gx, gy, h, ny) -> u32 RGBA8 (optional per-vertex colour, e.g. constant white under a texture),
-- skirtFloor (optional Y for flat skirt bottoms).
function HeightfieldMesh.newTerrain(img: Image, opts: { [string]: any }?): Terrain
	local o = opts or {}
	local w, h = img.w, img.h
	assert((w - 1) % CHUNK == 0 and (h - 1) % CHUNK == 0, "image size must be k*64+1")
	local t: Terrain = {
		w = w,
		h = h,
		img = img,
		hbuf = buffer.create(w * h * 4),
		cell = o.cell or 1,
		heightScale = o.heightScale or 1,
		maxHeight = 1,
		skirt = o.skirt or 2,
		uvTile = o.uvTile or 16,
		ranges = o.ranges or { 128, 320 },
		morphFrac = o.morphFrac or 0.35,
		hysteresis = o.hysteresis or 8,
		ncx = (w - 1) // CHUNK,
		ncy = (h - 1) // CHUNK,
		chunks = {},
		camX = o.camX or 0,
		camZ = o.camZ or 0,
		dirty = {},
		colorFn = o.colorFn,
		skirtFloor = o.skirtFloor,
	}
	t.maxHeight = o.maxHeight or (if img.format == "f32" then t.heightScale else 255 * t.heightScale)
	syncRect(t, 0, 0, w - 1, h - 1)
	for cy = 0, t.ncy - 1 do
		for cx = 0, t.ncx - 1 do
			t.chunks[cy * t.ncx + cx + 1] = HeightfieldMesh.buildChunk(t, cx, cy, (levelOf(t, cx, cy)))
		end
	end
	return t
end

-- Re-evaluate morph for a chunk (camera already stored on t). Lists vertices whose Y changed.
-- Chunks that were and still are entirely unmorphed or fully morphed are skipped.
local function morphChunk(t: Terrain, c: Chunk)
	local side, n, s, pos = c.side, c.n, c.step, c.pos
	c.changedCount, c.changedAttrs = 0, 0
	local state = morphStateOf(t, c)
	if (state == 0 or state == 1) and state == c.morphState then
		return
	end
	c.morphState = state
	-- Same arithmetic as morphY (kept inline for speed; the bit-exact test covers both paths).
	local cell, camX, camZ, baseH, coarseH = t.cell, t.camX, t.camZ, c.baseH, c.coarseH
	for j = 0, n do
		local wz = (c.oy + j * s) * cell
		for i = 0, n do
			local v = j * side + i
			local b, cc = buffer.readf32(baseH, v * 4), buffer.readf32(coarseH, v * 4)
			if b ~= cc then -- vertices on the coarse grid never move
				local o = v * 12 + 4
				local before = buffer.readf32(pos, o)
				buffer.writef32(pos, o, b + (cc - b) * morphFactor(c, (c.ox + i * s) * cell, wz, camX, camZ))
				if buffer.readf32(pos, o) ~= before then
					markChanged(c, v)
				end
			end
		end
	end
	local gc, drop, floor = c.gridCount, t.skirt, t.skirtFloor
	for k = 0, 4 * side - 1 do
		local o = (gc + k) * 12 + 4
		local before = buffer.readf32(pos, o)
		buffer.writef32(pos, o, if floor then floor else buffer.readf32(pos, skirtTop(c, k // side, k % side) * 12 + 4) - drop)
		if buffer.readf32(pos, o) ~= before then
			markChanged(c, gc + k)
		end
	end
	if c.changedCount > 0 then
		c.changedAttrs = 1
	end
end

-- Per-frame camera update: switches chunk LODs (with hysteresis on coarsening) and re-morphs vertices.
-- Returns the chunks rebuilt this call (their meshes need a fresh EditableMesh build).
function HeightfieldMesh.setCamera(t: Terrain, camX: number, camZ: number): { Chunk }
	t.camX, t.camZ = camX, camZ
	local rebuilt = t.dirty
	table.clear(rebuilt)
	for k, c in t.chunks do
		local L, d = levelOf(t, c.cx, c.cy)
		if L > c.level and d < t.ranges[c.level + 1] + t.hysteresis then
			L = c.level
		end
		if L ~= c.level then
			local nc = HeightfieldMesh.buildChunk(t, c.cx, c.cy, L)
			t.chunks[k] = nc
			table.insert(rebuilt, nc)
		else
			morphChunk(t, c)
		end
	end
	return rebuilt
end

-- Recompute the vertices of chunk c that read samples in [x0..x1] x [y0..y1]; appends to c.changed.
-- A vertex already recomputed against the same samples reports no change, so it is never listed twice.
local function recomputeRect(t: Terrain, c: Chunk, x0: number, y0: number, x1: number, y1: number)
	local s, n = c.step, c.n
	-- Vertices reading any dirty sample lie within s of the rect.
	local i0 = math.max(0, -((c.ox - (x0 - s)) // s))
	local i1 = math.min(n, (x1 + s - c.ox) // s)
	local j0 = math.max(0, -((c.oy - (y0 - s)) // s))
	local j1 = math.min(n, (y1 + s - c.oy) // s)
	if i0 > i1 or j0 > j1 then
		return
	end
	local attrs = c.changedAttrs
	for j = j0, j1 do
		for i = i0, i1 do
			local bits = gridVertex(t, c, i, j)
			if bits ~= 0 then
				markChanged(c, j * c.side + i)
				attrs = bit32.bor(attrs, bits)
			end
		end
	end
	-- Skirts on edges the rect touches.
	local side = c.side
	for e = 0, 3 do
		local lo, hi
		if e <= 1 then
			if (e == 0 and j0 ~= 0) or (e == 1 and j1 ~= n) then
				continue
			end
			lo, hi = i0, i1
		else
			if (e == 2 and i0 ~= 0) or (e == 3 and i1 ~= n) then
				continue
			end
			lo, hi = j0, j1
		end
		for q = lo, hi do
			local bits = skirtVertex(t, c, e * side + q)
			if bits ~= 0 then
				markChanged(c, c.gridCount + e * side + q)
				attrs = bit32.bor(attrs, bits)
			end
		end
	end
	c.changedAttrs = attrs
end

-- Incremental update after the image changed inside [x0..x1] x [y0..y1] (inclusive sample coords).
-- Returns the chunks with changed vertices; each has changed/changedCount/changedAttrs set.
function HeightfieldMesh.updateRect(t: Terrain, x0: number, y0: number, x1: number, y1: number): { Chunk }
	x0, y0 = math.max(x0, 0), math.max(y0, 0)
	x1, y1 = math.min(x1, t.w - 1), math.min(y1, t.h - 1)
	syncRect(t, x0, y0, x1, y1)
	local out = t.dirty
	table.clear(out)
	for _, c in t.chunks do
		c.changedCount, c.changedAttrs = 0, 0
		recomputeRect(t, c, x0, y0, x1, y1)
		if c.changedCount > 0 then
			table.insert(out, c)
		end
	end
	return out
end

-- Several dirty rects in one frame: rects = {x0, y0, x1, y1, ...} (n rects). All samples are synced before
-- any vertex is recomputed, so overlapping halos never list a vertex twice. Same result as one updateRect
-- over the union, without recomputing the space between rects. No allocation.
function HeightfieldMesh.updateRects(t: Terrain, rects: { number }, n: number): { Chunk }
	local w1, h1 = t.w - 1, t.h - 1
	for r = 0, n - 1 do
		local b = r * 4
		syncRect(t, math.max(rects[b + 1], 0), math.max(rects[b + 2], 0), math.min(rects[b + 3], w1), math.min(rects[b + 4], h1))
	end
	local out = t.dirty
	table.clear(out)
	for _, c in t.chunks do
		c.changedCount, c.changedAttrs = 0, 0
		local cx0, cy0 = c.ox - c.step, c.oy - c.step
		local cx1, cy1 = c.ox + CHUNK + c.step, c.oy + CHUNK + c.step
		for r = 0, n - 1 do
			local b = r * 4
			local x0, y0 = math.max(rects[b + 1], 0), math.max(rects[b + 2], 0)
			local x1, y1 = math.min(rects[b + 3], w1), math.min(rects[b + 4], h1)
			if x1 >= cx0 and x0 <= cx1 and y1 >= cy0 and y0 <= cy1 then
				recomputeRect(t, c, x0, y0, x1, y1)
			end
		end
		if c.changedCount > 0 then
			table.insert(out, c)
		end
	end
	return out
end

-- Test/debug helper: force a uniform morph factor on a chunk (0 = own level, 1 = coarse level); nil clears.
function HeightfieldMesh.setUniformMorph(t: Terrain, c: Chunk, m: number?)
	c.forceMorph = if m == nil and c.morphStart == INF then 0 else m
	morphChunk(t, c)
	c.forceMorph = m
end

-- World-space origin (chunk centre in XZ) for placing a chunk's mesh.
function HeightfieldMesh.chunkOrigin(t: Terrain, c: Chunk): (number, number)
	return (c.ox + CHUNK * 0.5) * t.cell, (c.oy + CHUNK * 0.5) * t.cell
end

-- ROBLOX ADAPTER ---------------------------------------------------------------------------------------------
-- Cannot run headless. Method names are from doc 21 (EditableMesh.yaml, fetched 2026-09-17).
-- [UNVERIFIED] whether BatchAdd(Face) creates default per-corner normal/UV/colour IDs like AddTriangle does;
--   we rebind every corner with BatchSetFaceAttributes and then RemoveUnused() to drop any orphans.
-- [UNVERIFIED] colour alpha semantics: doc says "alpha (transparency)"; we pass 1 assuming 1 = opaque.
-- [UNVERIFIED] UV V origin (top vs bottom of the image); we pass 1 - v.
-- CreateMeshPartAsync re-centres geometry on the part (cookbook): place the part at
--   chunkOrigin + em:GetCenter() rather than at chunkOrigin.

export type MeshHandles = { vids: { number }, nids: { number }, cids: { number }, fids: { number }, ids: { any }, vals: { any } }

function HeightfieldMesh.toEditableMesh(em: any, c: Chunk): MeshHandles
	local vc = c.vcount
	local P, N, U, C, A = table.create(vc), table.create(vc), table.create(vc), table.create(vc), table.create(vc, 1)
	for v = 0, vc - 1 do
		local o = v * 12
		P[v + 1] = Vector3.new(buffer.readf32(c.pos, o), buffer.readf32(c.pos, o + 4), buffer.readf32(c.pos, o + 8))
		N[v + 1] = Vector3.new(buffer.readf32(c.nrm, o), buffer.readf32(c.nrm, o + 4), buffer.readf32(c.nrm, o + 8))
		U[v + 1] = Vector2.new(buffer.readf32(c.uv, v * 8), 1 - buffer.readf32(c.uv, v * 8 + 4))
		local rgba = buffer.readu32(c.col, v * 4)
		C[v + 1] = Color3.fromRGB(bit32.band(rgba, 255), bit32.band(bit32.rshift(rgba, 8), 255), bit32.band(bit32.rshift(rgba, 16), 255))
	end
	local vids = em:BatchAdd(Enum.MeshAttribute.Vertex, P)
	local nids = em:BatchAdd(Enum.MeshAttribute.Normal, N)
	local uids = em:BatchAdd(Enum.MeshAttribute.UV, U)
	local cids = em:BatchAdd(Enum.MeshAttribute.Color, C, A)
	local tc = c.tcount
	local F, FN, FU, FC = table.create(tc), table.create(tc), table.create(tc), table.create(tc)
	for f = 0, tc - 1 do
		local a = buffer.readu32(c.idx, f * 12) + 1
		local b = buffer.readu32(c.idx, f * 12 + 4) + 1
		local d = buffer.readu32(c.idx, f * 12 + 8) + 1
		F[f + 1] = { vids[a], vids[b], vids[d] }
		FN[f + 1] = { nids[a], nids[b], nids[d] } -- shared IDs => smooth shading
		FU[f + 1] = { uids[a], uids[b], uids[d] }
		FC[f + 1] = { cids[a], cids[b], cids[d] }
	end
	local fids = em:BatchAdd(Enum.MeshAttribute.Face, F)
	em:BatchSetFaceAttributes(fids, FN)
	em:BatchSetFaceAttributes(fids, FU)
	em:BatchSetFaceAttributes(fids, FC)
	em:RemoveUnused()
	return { vids = vids, nids = nids, cids = cids, fids = fids, ids = {}, vals = {} }
end

-- Push the chunk's changed list (from updateRect or setCamera) with at most three batched calls.
-- Reuses the handle's scratch tables. Vector3 is a value type (no GC); Color3 is userdata, so colour pushes
-- (sculpt only, never morph) allocate one small object per changed vertex.
function HeightfieldMesh.updateEditableMesh(em: any, hnd: MeshHandles, c: Chunk)
	local n, attrs = c.changedCount, c.changedAttrs
	if n == 0 then
		return
	end
	local ids, vals, changed, pos, nrm, col = hnd.ids, hnd.vals, c.changed, c.pos, c.nrm, c.col
	if bit32.band(attrs, 1) ~= 0 then
		table.clear(ids)
		table.clear(vals)
		for k = 1, n do
			local v = buffer.readu32(changed, (k - 1) * 4)
			ids[k] = hnd.vids[v + 1]
			vals[k] = Vector3.new(buffer.readf32(pos, v * 12), buffer.readf32(pos, v * 12 + 4), buffer.readf32(pos, v * 12 + 8))
		end
		em:BatchSetValues(ids, vals)
	end
	if bit32.band(attrs, 2) ~= 0 then
		table.clear(ids)
		table.clear(vals)
		for k = 1, n do
			local v = buffer.readu32(changed, (k - 1) * 4)
			ids[k] = hnd.nids[v + 1]
			vals[k] = Vector3.new(buffer.readf32(nrm, v * 12), buffer.readf32(nrm, v * 12 + 4), buffer.readf32(nrm, v * 12 + 8))
		end
		em:BatchSetValues(ids, vals)
		table.clear(ids)
		table.clear(vals)
		for k = 1, n do
			local v = buffer.readu32(changed, (k - 1) * 4)
			local rgba = buffer.readu32(col, v * 4)
			ids[k] = hnd.cids[v + 1]
			vals[k] = Color3.fromRGB(bit32.band(rgba, 255), bit32.band(bit32.rshift(rgba, 8), 255), bit32.band(bit32.rshift(rgba, 16), 255))
		end
		em:BatchSetValues(ids, vals)
	end
	c.changedCount, c.changedAttrs = 0, 0
end

-- Collision is baked only at CreateMeshPartAsync; call once per finished stroke, not per frame (~22 ms).
function HeightfieldMesh.bakeCollision(em: any, part: any)
	local AssetService = game:GetService("AssetService")
	local ok, rebuilt = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Default })
	end)
	if ok and rebuilt then
		part:ApplyMesh(rebuilt)
		rebuilt:Destroy()
	end
end

return HeightfieldMesh
