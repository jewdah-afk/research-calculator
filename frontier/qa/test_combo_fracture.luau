-- Designed fracture QA: crack growth in the texture, then one mesh per fragment along those cracks.
local Out = require("./Out")
local FV = require("./FractureViz")
local Fracture = require("../combo/Fracture")

-- Noise -----------------------------------------------------------------------------------------------------
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
local function fbm(x: number, y: number): number
	return vnoise(x, y) * 0.5 + vnoise(x * 2.1 + 7, y * 2.1 + 3) * 0.3 + vnoise(x * 4.3 + 1, y * 4.3 + 9) * 0.2
end
local function put(buf: buffer, i: number, r: number, g: number, b: number)
	buffer.writeu8(buf, i * 4, math.clamp(r // 1, 0, 255))
	buffer.writeu8(buf, i * 4 + 1, math.clamp(g // 1, 0, 255))
	buffer.writeu8(buf, i * 4 + 2, math.clamp(b // 1, 0, 255))
	buffer.writeu8(buf, i * 4 + 3, 255)
end

-- Materials ---------------------------------------------------------------------------------------------------
local BRICKS = { { 150, 62, 44 }, { 168, 80, 54 }, { 132, 54, 40 }, { 178, 98, 66 }, { 122, 50, 40 }, { 160, 70, 50 } }

local function brickWall(): Fracture.Panel
	local W, H = 320, 224
	local p = Fracture.newPanel(W, H, { mat = Fracture.STONE, cell = 0.04, depth = 1.0 })
	local BW, BH, M = 38, 17, 2
	for y = 0, H - 1 do
		local row = y // BH
		local yy = y % BH
		local off = (row % 2) * (BW // 2)
		for x = 0, W - 1 do
			local i = y * W + x
			local xx, col = (x + off) % BW, (x + off) // BW
			local n = fbm(x / 9, y / 9)
			local grain = hash(x, y) - 0.5
			local r, g, b
			if yy < M or xx < M then
				local k = 0.82 + 0.18 * n + grain * 0.08
				r, g, b = 176 * k, 168 * k, 154 * k
			else
				local c = BRICKS[math.floor(hash(col, row + 101) * #BRICKS) + 1]
				local k = 0.78 + 0.32 * n + grain * 0.14
				r, g, b = c[1] * k, c[2] * k, c[3] * k
				local d = math.min(xx - M, BW - 1 - xx, yy - M, BH - 1 - yy)
				if d < 2 then
					r, g, b = r * (0.8 + 0.1 * d), g * (0.8 + 0.1 * d), b * (0.8 + 0.1 * d)
				end
				if hash(x * 3, y * 7) > 0.985 then -- dark speckles
					r, g, b = r * 0.6, g * 0.6, b * 0.6
				end
			end
			-- Painted hazard band and a white target, both weathered.
			local wear = fbm(x / 6 + 40, y / 6)
			if y >= 22 and y < 46 and wear < 0.62 then
				local s = ((x + y) // 14) % 2 == 0
				local cr, cg, cb = if s then 236 else 34, if s then 186 else 32, if s then 36 else 30
				local k = 0.86
				r, g, b = r + (cr - r) * k, g + (cg - g) * k, b + (cb - b) * k
			end
			local dx, dy = x - 165, y - 128
			local d = math.sqrt(dx * dx + dy * dy)
			if ((d > 44 and d < 52) or (d > 20 and d < 27)) and wear < 0.66 then
				local k = 0.85
				r, g, b = r + (240 - r) * k, g + (238 - g) * k, b + (228 - b) * k
			end
			put(p.base, i, r, g, b)
		end
	end
	Fracture.reset(p)
	Fracture.anchorEdges(p, 1 + 2 + 8) -- left, right, bottom are built in; the top is free
	return p
end

local function glassPane(): Fracture.Panel
	local W, H = 256, 256
	local p = Fracture.newPanel(W, H, { mat = Fracture.GLASS, cell = 0.03, depth = 0.12, density = 0.9 })
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local i = y * W + x
			local k = 1 - y / H * 0.18
			local r, g, b = 150 * k, 200 * k, 214 * k
			local s = (x + y * 0.55) / 256
			local streak = math.max(0, 1 - math.abs(s - 0.42) / 0.05) * 0.55 + math.max(0, 1 - math.abs(s - 0.55) / 0.018) * 0.4
			r, g, b = r + (245 - r) * streak, g + (252 - g) * streak, b + (255 - b) * streak
			local n = (vnoise(x / 20, y / 20) - 0.5) * 10
			put(p.base, i, r + n, g + n, b + n)
		end
	end
	Fracture.reset(p)
	Fracture.anchorEdges(p, 15) -- held by the frame on all sides
	return p
end

-- Statue silhouette: bust on a plinth (the crack network and meshing follow any mask).
local function statue(): Fracture.Panel
	local W, H = 200, 300
	local mat = table.clone(Fracture.STONE)
	mat.crackRGB, mat.chipRGB, mat.interiorRGB = { 70, 66, 64 }, { 255, 255, 250 }, { 222, 218, 210 }
	mat.reach, mat.radials, mat.rings = 0.62, { 6, 9 }, 2.2
	local p = Fracture.newPanel(W, H, { mat = mat, cell = 0.03, depth = 0.9 })
	local function sdBox(x: number, y: number, x0: number, y0: number, x1: number, y1: number, r: number): number
		local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
		local hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
		local qx, qy = math.abs(x - cx) - hx, math.abs(y - cy) - hy
		return math.sqrt(math.max(qx, 0) ^ 2 + math.max(qy, 0) ^ 2) + math.min(math.max(qx, qy), 0) - r
	end
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local i = y * W + x
			local head = math.sqrt(((x - 100) / 36) ^ 2 + ((y - 70) / 46) ^ 2) - 1
			head *= 38
			local neck = sdBox(x, y, 84, 100, 116, 150, 4)
			local torso = sdBox(x, y, 30, 136, 170, 250, 34)
			local plinth = sdBox(x, y, 22, 244, 178, 258, 2)
			local base = sdBox(x, y, 38, 256, 162, 300, 0)
			local d = math.min(head, neck, torso, plinth, base)
			buffer.writeu8(p.mask, i, if d <= 0 then 1 else 0)
			local r, g, b
			if y >= 244 then -- dark granite plinth
				local n = fbm(x / 5, y / 5)
				local sp = hash(x, y)
				local k = 70 + 40 * n + (if sp > 0.93 then 60 else 0)
				r, g, b = k, k, k * 1.05
			else
				local n = fbm(x / 28, y / 28)
				local v = math.abs(math.sin(x * 0.05 + y * 0.022 + n * 6))
				local vein = math.max(0, 1 - v / 0.07)
				local v2 = math.abs(math.sin(x * -0.03 + y * 0.06 + fbm(x / 14 + 5, y / 14) * 5))
				vein = math.max(vein, 0.5 * math.max(0, 1 - v2 / 0.04))
				local k = 0.93 + 0.07 * fbm(x / 7, y / 7)
				r, g, b = 236 * k, 232 * k, 224 * k
				r, g, b = r + (128 - r) * vein, g + (132 - g) * vein, b + (140 - b) * vein
				-- soft shading so the silhouette reads as a carved bust
				local ao = math.clamp(-d / 14, 0, 1)
				local s = 0.82 + 0.18 * ao
				r, g, b = r * s, g * s, b * s
			end
			put(p.base, i, r, g, b)
		end
	end
	Fracture.reset(p)
	Fracture.anchorEdges(p, 8) -- stands on the ground
	return p
end

local function crackCount(p: Fracture.Panel): number
	local n = 0
	for i = 0, p.w * p.h - 1 do
		if buffer.readu8(p.crack, i) ~= 0 and buffer.readu8(p.mask, i) ~= 0 then
			n += 1
		end
	end
	return n
end

-- Checks ----------------------------------------------------------------------------------------------------------
local function meshChecks(tag: string, p: Fracture.Panel, frags: { Fracture.Fragment })
	local W, H, cell = p.w, p.h, p.cell
	local hw, hh = (W - 1) * 0.5, (H - 1) * 0.5
	local nonManifold, open, meshes, badVol, badCap, capN = 0, 0, 0, 0, 0, 0
	local uvOut, uvAffine, own, ownN, maxT, maxV = 0, 0, 0, 0, 0, 0
	local volRatioMin, volRatioMax = math.huge, 0
	for _, f in frags do
		if not f.pos then
			continue
		end
		meshes += 1
		local pos, idx, uv, mat = f.pos :: buffer, f.idx :: buffer, f.uv :: buffer, f.mat :: buffer
		maxT, maxV = math.max(maxT, f.tcount), math.max(maxV, f.vcount)
		local directed: { [number]: number } = {}
		local vol = 0
		for t = 0, f.tcount - 1 do
			local a, b, c = buffer.readu32(idx, t * 12), buffer.readu32(idx, t * 12 + 4), buffer.readu32(idx, t * 12 + 8)
			for k = 0, 2 do
				local e0 = if k == 0 then a elseif k == 1 then b else c
				local e1 = if k == 0 then b elseif k == 1 then c else a
				local key = e0 * 1048576 + e1
				directed[key] = (directed[key] or 0) + 1
			end
			local ax, ay, az = buffer.readf32(pos, a * 12), buffer.readf32(pos, a * 12 + 4), buffer.readf32(pos, a * 12 + 8)
			local bx, by, bz = buffer.readf32(pos, b * 12), buffer.readf32(pos, b * 12 + 4), buffer.readf32(pos, b * 12 + 8)
			local cx, cy, cz = buffer.readf32(pos, c * 12), buffer.readf32(pos, c * 12 + 4), buffer.readf32(pos, c * 12 + 8)
			vol += (ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)) / 6
			if buffer.readu8(mat, t) == 0 then
				local nz = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
				if nz < -1e-9 then
					badCap += 1
				end
				-- UV of the cap triangle's centroid must land on this fragment's own pixels (or its crack rim).
				local u = (buffer.readf32(uv, a * 8) + buffer.readf32(uv, b * 8) + buffer.readf32(uv, c * 8)) / 3
				local v = (buffer.readf32(uv, a * 8 + 4) + buffer.readf32(uv, b * 8 + 4) + buffer.readf32(uv, c * 8 + 4)) / 3
				local px, py = math.clamp(math.floor(u * W), 0, W - 1), math.clamp(math.floor(v * H), 0, H - 1)
				local i = py * W + px
				ownN += 1
				if buffer.readu32(p.label, i * 4) == f.id or buffer.readu8(p.crack, i) ~= 0 then
					own += 1
				end
				capN += 1
			end
		end
		for key, n in directed do
			local a, b = key // 1048576, key % 1048576
			local back = directed[b * 1048576 + a] or 0
			if n ~= 1 or back ~= 1 then
				if back == 0 then
					open += 1
				else
					nonManifold += 1
				end
			end
		end
		local expect = f.areaStuds * p.depth
		local ratio = vol / expect
		volRatioMin, volRatioMax = math.min(volRatioMin, ratio), math.max(volRatioMax, ratio)
		if vol <= 0 then
			badVol += 1
		end
		for v = 0, f.vcount - 1 do
			local u, vv = buffer.readf32(uv, v * 8), buffer.readf32(uv, v * 8 + 4)
			if u < 0 or u > 1 or vv < 0 or vv > 1 then
				uvOut += 1
			end
			-- UV is the affine map of the panel position: the fragment keeps exactly the texels it had.
			local X, Y = buffer.readf32(pos, v * 12) + f.cx, buffer.readf32(pos, v * 12 + 4) + f.cy
			local eu = math.abs((X / cell + hw + 0.5) / W - u)
			local ev = math.abs((hh - Y / cell + 0.5) / H - vv)
			if eu > 1e-4 or ev > 1e-4 then
				uvAffine += 1
			end
		end
	end
	Out.check(`fracture.{tag}.watertight`, meshes > 0 and open == 0 and nonManifold == 0, `{meshes} meshes: {open} open edges, {nonManifold} edges not used exactly twice in opposite directions`)
	Out.check(`fracture.{tag}.orientation`, badVol == 0 and badCap == 0, `{badVol} meshes with volume <= 0, {badCap}/{capN} front-cap tris facing back; volume / (pixel area x depth) in [{string.format("%.3f", volRatioMin)}, {string.format("%.3f", volRatioMax)}]`)
	Out.check(`fracture.{tag}.uv_in_unit_square`, uvOut == 0, `{uvOut} UVs outside [0,1]`)
	Out.check(`fracture.{tag}.uv_is_own_texture`, uvAffine == 0 and own >= ownN * 0.99, `{uvAffine} UVs off the panel->texture map; {own}/{ownN} cap triangles sample their own fragment or its crack rim`)
	Out.check(`fracture.{tag}.limits`, maxT <= 20000 and maxV <= 60000, `worst fragment {maxV} verts / {maxT} tris`)
end

local function partitionCheck(tag: string, p: Fracture.Panel, frags: { Fracture.Fragment })
	local sum = 0
	for _, f in frags do
		sum += f.area
	end
	local cracks = crackCount(p)
	-- every mask pixel is exactly one of: crack, labelled
	local bad = 0
	for i = 0, p.w * p.h - 1 do
		local m, c, l = buffer.readu8(p.mask, i) ~= 0, buffer.readu8(p.crack, i) ~= 0, buffer.readu32(p.label, i * 4) ~= 0
		if m and (c == l) then
			bad += 1
		elseif not m and l then
			bad += 1
		end
	end
	Out.check(`fracture.{tag}.partition`, sum + cracks == p.maskArea and bad == 0, `{#frags} fragments {sum} px + {cracks} crack px = {sum + cracks} (panel {p.maskArea}); {bad} pixels double/unassigned`)
end

local function summary(frags: { Fracture.Fragment }): (number, number, number, number, number)
	local a, l, d, s, tris = 0, 0, 0, 0, 0
	for _, f in frags do
		if f.kind == "anchored" then
			a += 1
		elseif f.kind == "loose" then
			l += 1
		elseif f.kind == "debris" then
			d += 1
		else
			s += 1
		end
		tris += f.tcount
	end
	return a, l, d, s, tris
end

-- (a) Brick wall: growth, increments, determinism -------------------------------------------------------------
local wall = brickWall()
local IX, IY, E, SEED = 165, 128, 1.0, 7
Fracture.impact(wall, IX, IY, E, SEED)
local W, H = wall.w, wall.h
local snaps, snapAt = {}, { [3] = true, [8] = true, [16] = true }
local touched = buffer.create(W * H)
local rectOk, frames = true, 0
repeat
	local n, x0, y0, x1, y1 = Fracture.step(wall)
	frames += 1
	for k = 0, n - 1 do
		local i = buffer.readu32(wall.changed, k * 4)
		buffer.writeu8(touched, i, 1)
		local x, y = i % W, i // W
		if x < x0 or x > x1 or y < y0 or y > y1 then
			rectOk = false
		end
	end
	rectOk = rectOk and not wall.overflow
	if snapAt[frames] then
		local b = buffer.create(W * H * 4)
		buffer.copy(b, 0, wall.rgba)
		table.insert(snaps, { frames, b })
	end
until not wall.growing or frames > 400
do
	local b = buffer.create(W * H * 4)
	buffer.copy(b, 0, wall.rgba)
	table.insert(snaps, { frames, b })
end
Out.check("fracture.wall.growth_terminates", not wall.growing and frames > 4, `{frames} frames, {wall.nTips} tips ({crackCount(wall)} crack px)`)
do
	-- Every texel that differs from the clean texture was reported in some frame's increment.
	local missed, diff = 0, 0
	for i = 0, W * H - 1 do
		if buffer.readu32(wall.rgba, i * 4) ~= buffer.readu32(wall.base, i * 4) then
			diff += 1
			if buffer.readu8(touched, i) == 0 then
				missed += 1
			end
		end
	end
	Out.check("fracture.wall.increments_cover_changes", missed == 0 and rectOk and diff > 0, `{diff} texels changed, {missed} missing from per-frame lists, dirty rects ok: {rectOk}`)
end
do
	local w2 = brickWall()
	Fracture.impact(w2, IX, IY, E, SEED)
	Fracture.grow(w2)
	local same = buffer.tostring(w2.rgba) == buffer.tostring(wall.rgba) and buffer.tostring(w2.crack) == buffer.tostring(wall.crack)
	local w3 = brickWall()
	Fracture.impact(w3, IX, IY, E, SEED + 1)
	Fracture.grow(w3)
	local differs = buffer.tostring(w3.crack) ~= buffer.tostring(wall.crack)
	Out.check("fracture.wall.deterministic", same and differs, `same seed identical: {same}; next seed differs: {differs}`)
end

local wallFrags = Fracture.fracture(wall)
partitionCheck("wall", wall, wallFrags)
meshChecks("wall", wall, wallFrags)
do
	local a, l, d, s, tris = summary(wallFrags)
	Out.check("fracture.wall.breaks", a >= 1 and l >= 3, `{#wallFrags} regions: {a} anchored, {l} loose, {d} debris, {s} dust; {tris} tris total`)
end

-- A weak hit cracks the wall but nothing falls.
do
	local w2 = brickWall()
	Fracture.impact(w2, 100, 150, 0.22, 3)
	local fr = Fracture.grow(w2)
	local frags = Fracture.fracture(w2)
	local detached = 0
	for _, f in frags do
		if not f.anchored and f.kind ~= "dust" then
			detached += 1
		end
	end
	Out.check("fracture.wall.weak_hit_holds", detached == 0 and crackCount(w2) > 50, `{crackCount(w2)} crack px in {fr} frames, {detached} pieces fall`)
	-- A second impact grows into the first one's cracks and stops there.
	Fracture.impact(w2, 230, 90, 0.5, 4)
	Fracture.grow(w2)
	local f2 = Fracture.fracture(w2)
	partitionCheck("wall_two_hits", w2, f2)
end

-- Images (a): crack growth frames, 2x nearest, 2x2 grid ------------------------------------------------------
do
	local S, G = 2, 10
	local cw, ch = W * S, H * S
	local ow, oh = cw * 2 + G * 3, ch * 2 + G * 3
	local img = buffer.create(ow * oh * 4)
	for i = 0, ow * oh - 1 do
		buffer.writeu32(img, i * 4, 0xFF1A1A1E)
	end
	for k, s in snaps do
		local gx, gy = (k - 1) % 2, (k - 1) // 2
		local ox, oy = G + gx * (cw + G), G + gy * (ch + G)
		local src = s[2]
		for y = 0, ch - 1 do
			for x = 0, cw - 1 do
				buffer.writeu32(img, ((oy + y) * ow + ox + x) * 4, buffer.readu32(src, ((y // S) * W + x // S) * 4))
			end
		end
	end
	Out.image("fracture_crack_frames", ow, oh, img)
end

-- Fragment map: label colours (anchored grey, loose hues, debris red, dust white, cracks black).
local function fragmentMap(p: Fracture.Panel, frags: { Fracture.Fragment }): buffer
	local w, h = p.w, p.h
	local byId = {}
	for _, f in frags do
		byId[f.id] = f
	end
	local img = buffer.create(w * h * 4)
	for i = 0, w * h - 1 do
		local l = buffer.readu32(p.label, i * 4)
		local r, g, b = 24, 24, 28
		if buffer.readu8(p.mask, i) == 0 then
			r, g, b = 60, 64, 72
		elseif l ~= 0 then
			local f = byId[l]
			if f.kind == "anchored" then
				local k = 120 + 50 * hash(l, 1)
				r, g, b = k, k, k
			elseif f.kind == "dust" then
				r, g, b = 255, 255, 255
			elseif f.kind == "debris" then
				r, g, b = 230, 70, 60
			else
				local hue = hash(l, 7) * 6
				local c = { 0, 0, 0 }
				local x = 1 - math.abs(hue % 2 - 1)
				local seg = math.floor(hue)
				local t = ({ { 1, x, 0 }, { x, 1, 0 }, { 0, 1, x }, { 0, x, 1 }, { x, 0, 1 }, { 1, 0, x } })[seg + 1]
				c = t
				r, g, b = 70 + 170 * c[1], 70 + 170 * c[2], 70 + 170 * c[3]
			end
		end
		put(img, i, r, g, b)
	end
	return img
end
do
	local map = fragmentMap(wall, wallFrags)
	local G = 10
	local ow, oh = W * 2 + G * 3, H + G * 2
	local img = buffer.create(ow * oh * 4)
	for i = 0, ow * oh - 1 do
		buffer.writeu32(img, i * 4, 0xFF1A1A1E)
	end
	for y = 0, H - 1 do
		buffer.copy(img, ((G + y) * ow + G) * 4, wall.rgba, y * W * 4, W * 4)
		buffer.copy(img, ((G + y) * ow + G * 2 + W) * 4, map, y * W * 4, W * 4)
	end
	Out.image("fracture_wall_fragment_map", ow, oh, img)
end

-- 3D previews -------------------------------------------------------------------------------------------------
local function concrete(x: number, z: number): (number, number, number)
	local n = fbm(x * 0.9, z * 0.9)
	local k = 132 + 34 * n + (hash(math.floor(x * 40), math.floor(z * 40)) - 0.5) * 10
	local gx, gz = x / 3 - math.floor(x / 3), z / 3 - math.floor(z / 3)
	if gx < 0.012 or gz < 0.012 then
		k *= 0.78
	end
	return k * 1.0, k * 0.98, k * 0.93
end

-- Pose bodies for every meshed fragment; panel stands on y = 0, centred on x = 0, front face at +z.
local function makeBodies(p: Fracture.Panel, frags: { Fracture.Fragment }, side: number, seed: number): { FV.Body }
	local bodies = {}
	local baseY = (p.h - 1) * 0.5 * p.cell + 0.5 * p.cell
	for _, f in frags do
		if not f.pos then
			continue
		end
		local b = FV.newBody(f, f.cx, f.cy + baseY, 0, f.anchored)
		if not f.anchored then
			b.vx, b.vy, b.vz, b.wx, b.wy, b.wz = Fracture.launch(p, f, seed, side)
		end
		table.insert(bodies, b)
	end
	-- Dust has no mesh (particles in Roblox); show it as tiny chips coloured by its own texel.
	for _, f in frags do
		if f.kind ~= "dust" then
			continue
		end
		local s = math.max(0.05, math.sqrt(f.area) * p.cell * 1.1)
		local d = math.min(s, p.depth * 0.6)
		local pos, nrm, uv, idx, tc = FV.box(-s / 2, -s / 2, -d / 2, s / 2, s / 2, d / 2)
		local u, v = (f.cx / p.cell + (p.w - 1) * 0.5 + 0.5) / p.w, ((p.h - 1) * 0.5 - f.cy / p.cell + 0.5) / p.h
		for k = 0, 23 do
			buffer.writef32(uv, k * 8, u)
			buffer.writef32(uv, k * 8 + 4, v)
		end
		local chip = { id = f.id, pos = pos, nrm = nrm, uv = uv, idx = idx, mat = nil, vcount = 24, tcount = tc, radius = s }
		local b = FV.newBody(chip, f.cx, f.cy + baseY, 0, false)
		b.vx, b.vy, b.vz, b.wx, b.wy, b.wz = Fracture.launch(p, f, seed, side)
		table.insert(bodies, b)
	end
	return bodies
end

local function drawBodies(v: any, bodies: { FV.Body }, tex: FV.Tex, opts: FV.MeshOpts, shadowOnly: boolean?)
	for _, b in bodies do
		FV.pose(b)
		local f = b.frag
		if shadowOnly then
			v:shadowMesh(b.wpos, f.idx, f.tcount)
		else
			v:mesh(b.wpos, b.wnrm, f.uv, f.idx, f.mat, f.tcount, tex, opts)
		end
	end
end

-- (b) Brick wall blowing out toward the camera, mid-tumble.
do
	local bodies = makeBodies(wall, wallFrags, 1, 11)
	FV.simulate(bodies, 0.36, 1 / 240, 0, 32)
	local v = FV.new(960, 540, 2)
	v:lookAt(7.5, 5.2, 16.5, -0.4, 3.6, 1.8, 50)
	v:light(-0.5, 0.85, 0.6)
	v:background(0, { 92, 140, 205 }, { 205, 214, 222 }, concrete, 0.012)
	for _, b in bodies do
		FV.pose(b)
		v:shadowMesh(b.wpos, b.frag.idx, b.frag.tcount)
	end
	v:applyShadow(0.55, 5)
	local tex = { buf = wall.rgba, w = wall.w, h = wall.h }
	local m = wall.mat
	drawBodies(v, bodies, tex, { interior = m.interiorRGB, interiorMix = 0.55, spec = 0.08, shininess = 12 })
	Out.image("fracture_wall_explode", v.w, v.h, v:resolve())
end

-- (c1) Glass pane in a frame: spider-web cracks, many shards, sorted alpha.
local glass = glassPane()
Fracture.impact(glass, 118, 132, 1.15, 21)
local glassFrames = Fracture.grow(glass)
local glassFrags = Fracture.fracture(glass)
partitionCheck("glass", glass, glassFrags)
meshChecks("glass", glass, glassFrags)
do
	local a, l, d, s, tris = summary(glassFrags)
	Out.check("fracture.glass.many_shards", l + d >= 40, `{glassFrames} frames; {#glassFrags} regions: {a} anchored, {l} loose, {d} debris, {s} dust; {tris} tris`)
	local bodies = makeBodies(glass, glassFrags, 1, 5)
	-- raise the pane into a window frame 1.2 studs off the ground
	for _, b in bodies do
		b.py += 1.2
	end
	FV.simulate(bodies, 0.3, 1 / 240, 0, 32)
	local v = FV.new(960, 540, 2)
	v:lookAt(4.2, 3.2, 10.5, 0, 4.2, 1.2, 46)
	v:light(-0.4, 0.8, 0.7)
	v:background(0, { 40, 70, 130 }, { 170, 186, 205 }, concrete, 0.015)
	local hw, top = glass.w * glass.cell * 0.5, 1.2 + glass.h * glass.cell
	local frame = {
		{ FV.box(-hw - 0.35, 1.2 - 0.35, -0.25, hw + 0.35, 1.2, 0.25) },
		{ FV.box(-hw - 0.35, top, -0.25, hw + 0.35, top + 0.35, 0.25) },
		{ FV.box(-hw - 0.35, 1.2, -0.25, -hw, top, 0.25) },
		{ FV.box(hw, 1.2, -0.25, hw + 0.35, top, 0.25) },
		{ FV.box(-hw - 0.6, 0, -0.5, hw + 0.6, 0.85, 0.5) }, -- sill wall below
	}
	for _, fm in frame do
		v:shadowMesh(fm[1], fm[4], fm[5])
	end
	for _, b in bodies do
		FV.pose(b)
		v:shadowMesh(b.wpos, b.frag.idx, b.frag.tcount)
	end
	v:applyShadow(0.45, 5)
	local wood = buffer.create(4)
	buffer.writeu32(wood, 0, 0xFF2A3F5C)
	local wtex = { buf = wood, w = 1, h = 1 }
	local grey = buffer.create(4)
	buffer.writeu32(grey, 0, 0xFF8C9296)
	local sill = { buf = grey, w = 1, h = 1 }
	for k, fm in frame do
		v:mesh(fm[1], fm[2], fm[3], fm[4], nil, fm[5], if k == 5 then sill else wtex, { spec = 0.15 })
	end
	local tex = { buf = glass.rgba, w = glass.w, h = glass.h }
	drawBodies(v, bodies, tex, { alpha = 0.38, interior = { 120, 205, 190 }, interiorMix = 0.7, spec = 0.9, shininess = 60, ambient = 0.55 })
	v:flushTransparent()
	Out.image("fracture_glass_shatter", v.w, v.h, v:resolve())
	-- crack texture alongside its fragment map
	local map = fragmentMap(glass, glassFrags)
	local G = 10
	local ow, oh = glass.w * 2 + G * 3, glass.h + G * 2
	local img = buffer.create(ow * oh * 4)
	for i = 0, ow * oh - 1 do
		buffer.writeu32(img, i * 4, 0xFF1A1A1E)
	end
	for y = 0, glass.h - 1 do
		buffer.copy(img, ((G + y) * ow + G) * 4, glass.rgba, y * glass.w * 4, glass.w * 4)
		buffer.copy(img, ((G + y) * ow + G * 2 + glass.w) * 4, map, y * glass.w * 4, glass.w * 4)
	end
	Out.image("fracture_glass_fragment_map", ow, oh, img)
end

-- (c2) Statue: a bust hit in the chest; the plinth holds, the top breaks away.
local bust = statue()
Fracture.impact(bust, 104, 178, 0.95, 8)
Fracture.grow(bust)
local bustFrags = Fracture.fracture(bust)
partitionCheck("statue", bust, bustFrags)
meshChecks("statue", bust, bustFrags)
do
	local a, l, d, s, tris = summary(bustFrags)
	Out.check("fracture.statue.breaks", a >= 1 and l >= 3, `{#bustFrags} regions: {a} anchored, {l} loose, {d} debris, {s} dust; {tris} tris`)
	-- Left: cracked, the instant before it breaks. Right: 0.24 s later.
	local halves = {}
	for k, T in { 0, 0.24 } do
		local bodies = makeBodies(bust, bustFrags, 1, 3)
		FV.simulate(bodies, T, 1 / 240, 0, 32)
		local v = FV.new(540, 600, 2)
		v:lookAt(3.2, 4.6, 12.5, 0, 4.0, 0.8, 48)
		v:light(-0.55, 0.8, 0.5)
		v:background(0, { 26, 26, 34 }, { 118, 110, 102 }, function(x: number, z: number)
			local r, g, b = concrete(x, z)
			return r * 0.85, g * 0.8, b * 0.75
		end, 0.02)
		for _, b in bodies do
			FV.pose(b)
			v:shadowMesh(b.wpos, b.frag.idx, b.frag.tcount)
		end
		v:applyShadow(0.6, 6)
		local tex = { buf = bust.rgba, w = bust.w, h = bust.h }
		drawBodies(v, bodies, tex, { interior = bust.mat.interiorRGB, interiorMix = 0.3, spec = 0.2, shininess = 24 })
		halves[k] = { w = v.w, h = v.h, rgba = v:resolve() }
	end
	local ow, oh = halves[1].w * 2, halves[1].h
	local img = buffer.create(ow * oh * 4)
	for y = 0, oh - 1 do
		buffer.copy(img, y * ow * 4, halves[1].rgba, y * halves[1].w * 4, halves[1].w * 4)
		buffer.copy(img, (y * ow + halves[1].w) * 4, halves[2].rgba, y * halves[1].w * 4, halves[1].w * 4)
	end
	Out.image("fracture_statue", ow, oh, img)
end

-- Timings -------------------------------------------------------------------------------------------------------
local function growthTiming(tag: string, make: () -> Fracture.Panel, ix: number, iy: number, e: number, seed: number)
	local p = make()
	local reps, total, worst, nf, impactMs = 4, 0, 0, 0, 0
	for r = 1, reps + 1 do
		Fracture.reset(p)
		local t0 = os.clock()
		Fracture.impact(p, ix, iy, e, seed)
		local ti = os.clock() - t0
		repeat
			local t1 = os.clock()
			Fracture.step(p)
			local dt = os.clock() - t1
			if r > 1 then -- first rep is warm-up
				total += dt
				nf += 1
				worst = math.max(worst, dt)
			end
		until not p.growing
		if r > 1 then
			impactMs += ti
		end
	end
	print(string.format("@@TIME %s %.4f %d", `fracture.{tag}.impact_crater_seed`, impactMs * 1000 / reps, reps))
	print(string.format("@@TIME %s %.4f %d", `fracture.{tag}.crack_step_mean_per_frame`, total * 1000 / nf, nf))
	print(string.format("@@TIME %s %.4f %d", `fracture.{tag}.crack_step_worst_frame`, worst * 1000, nf))
	return p
end
local tw = growthTiming("wall", brickWall, IX, IY, E, SEED)
local tg = growthTiming("glass", glassPane, 118, 132, 1.15, 21)
Out.time("fracture.wall.label_320x224", 5, function()
	Fracture.label(tw)
end)
local nW = #wallFrags
Out.time(`fracture.wall.fracture_{nW}_regions_{select(2, summary(wallFrags)) + select(3, summary(wallFrags)) + select(1, summary(wallFrags))}_meshes`, 3, function()
	Fracture.fracture(tw)
end)
do
	-- Deferred meshing: the cost one frame pays per fragment when the spawner builds them one at a time.
	local frags = Fracture.fracture(tw, true)
	local big, loose = frags[1], {}
	for _, f in frags do
		if f.kind == "loose" or f.kind == "debris" then
			table.insert(loose, f)
		end
	end
	Out.time(`fracture.wall.label_only_{#frags}_regions`, 3, function()
		Fracture.fracture(tw, true)
	end)
	Out.time(`fracture.wall.mesh_largest_{big.area}px`, 5, function()
		big.pos = nil
		Fracture.buildMesh(tw, big)
	end)
	Out.time(`fracture.wall.mesh_all_{#loose}_loose`, 3, function()
		for _, f in loose do
			f.pos = nil
			Fracture.buildMesh(tw, f)
		end
	end)
	-- divide by count for per-mesh (printed separately)
	local t0 = os.clock()
	for _, f in loose do
		f.pos = nil
		Fracture.buildMesh(tw, f)
	end
	print(string.format("@@TIME %s %.4f %d", "fracture.wall.mesh_per_loose_fragment", (os.clock() - t0) * 1000 / #loose, #loose))
end
local ga, gl, gd = summary(glassFrags)
Out.time(`fracture.glass.fracture_{#glassFrags}_regions_{ga + gl + gd}_meshes`, 3, function()
	Fracture.fracture(tg)
end)

Out.done()
