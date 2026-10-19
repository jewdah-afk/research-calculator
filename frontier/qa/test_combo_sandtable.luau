-- Sand table: top-down sand / water / lava sim lifted into two HeightfieldMesh layers + one RGBA texture.
-- Checks: exact mass identities (every source/sink counted), angle of repose, level lakes, lava -> basalt + steam,
-- chunk sleep, incremental mesh / texture == full rebuild, triangle limits, collision debounce. Timings and
-- oblique previews (MeshViz.shaded: smooth normals, texture, lava emission, soft heightfield shadows, water).
local Out = require("./Out")
local MeshViz = require("./MeshViz")
local HM = require("../mesh/HeightfieldMesh")
local ST = require("../combo/SandTable")

local function report(name: string, sec: number, n: number)
	print(string.format("@@TIME %s %.4f %d", name, sec * 1000 / math.max(n, 1), n))
end
local function rel(a: number, b: number): number
	return math.abs(a - b) / math.max(math.abs(b), 1)
end

-- Mass identities: every quantity equals its initial amount plus counted sources minus counted sinks.
local function snapshot(t: ST.SandTable)
	local s = t:totals()
	return { rock = s.rock, sand = s.sand + s.sed, water = s.water, lava = s.lava }
end
local function massErrors(t: ST.SandTable, t0: { [string]: number }): (number, number, number, number)
	local s = snapshot(t)
	local eS = rel(s.sand + t.fusedSand + t.removedSand, t0.sand + t.addedSand)
	local eW = rel(s.water + t.steamWater + t.evapWater, t0.water + t.addedWater)
	local eL = rel(s.lava + t.cooledLava + t.removedLava, t0.lava + t.addedLava)
	local eR = rel(s.rock + t.removedRock, t0.rock + t.cooledLava + t.fusedSand)
	return eS, eW, eL, eR
end
local function settle(t: ST.SandTable, maxSteps: number): number
	for s = 1, maxSteps do
		t:step()
		if t:awakeCount() == 0 then
			return s
		end
	end
	return -1
end

-- 1. Small tables ------------------------------------------------------------------------------------------

-- Sand poured on a point forms a cone at the angle of repose, then sleeps.
do
	local t = ST.new(64, 64)
	for y = 0, 63 do
		for x = 0, 63 do
			t:setColumn(x, y, 1, 0)
		end
	end
	t:refresh()
	local m0 = snapshot(t)
	for _ = 1, 400 do
		t:dropSand(32, 32, 2, 0.6)
		t:step()
	end
	local at = settle(t, 4000)
	local worst, peak = 0, 0
	for y = 1, 62 do
		for x = 1, 62 do
			local o = (y * 64 + x) * 8
			if buffer.readf64(t.sand, o) > 0.01 then
				local g = buffer.readf64(t.G, o)
				peak = math.max(peak, g - 1)
				for dy = -1, 1 do
					for dx = -1, 1 do
						if dx ~= 0 or dy ~= 0 then
							local d = math.sqrt(dx * dx + dy * dy)
							worst = math.max(worst, (g - buffer.readf64(t.G, ((y + dy) * 64 + x + dx) * 8)) / d)
						end
					end
				end
			end
		end
	end
	local eS = massErrors(t, m0)
	Out.check("sandtable.repose_angle", worst <= t.talusDry + t.slideDead + 1e-6 and peak > 6, string.format("max slope %.3f (talus %.2f = %.1f deg), cone height %.1f", worst, t.talusDry, math.deg(math.atan(t.talusDry)), peak))
	Out.check("sandtable.pile_sleeps", at > 0, `settled {at} steps after pouring`)
	Out.check("sandtable.pile_mass", eS < 1e-12, string.format("sand rel err %.1e", eS))
end

-- Water poured over bumpy ground ends level in each basin and sleeps; dig/drop/lava tools keep identities.
do
	local t = ST.new(64, 64)
	for y = 0, 63 do
		for x = 0, 63 do
			local b = 2 + 1.5 * math.sin(x / 5) * math.cos(y / 7) + 0.03 * x
			t:setColumn(x, y, b, 0.5)
		end
	end
	t:refresh()
	local m0 = snapshot(t)
	for k = 1, 300 do
		t:pourWater(12, 12, 4, 0.2)
		if k == 100 then
			t:dig(40, 40, 6, 2.5)
		end
		if k == 150 then
			t:dropSand(20, 44, 5, 3)
		end
		t:step()
	end
	local at = settle(t, 20000)
	-- every pond's surface is flat: the largest surface step between two wet neighbours
	local maxStep = 0
	for y = 0, 63 do
		for x = 0, 62 do
			local o, o2 = (y * 64 + x) * 8, (y * 64 + x + 1) * 8
			local w1, w2 = buffer.readf64(t.water, o), buffer.readf64(t.water, o2)
			if w1 > 0.05 and w2 > 0.05 then
				maxStep = math.max(maxStep, math.abs(buffer.readf64(t.G, o) + w1 - buffer.readf64(t.G, o2) - w2))
			end
		end
	end
	local eS, eW = massErrors(t, m0)
	Out.check("sandtable.lake_level", maxStep < 0.01, string.format("max surface step between wet neighbours %.4f studs", maxStep))
	Out.check("sandtable.lake_sleeps", at > 0, `settled {at} steps after pouring`)
	Out.check("sandtable.tools_mass", eS < 1e-10 and eW < 1e-10 and t.removedSand > 0 and t.removedRock > 0, string.format("sand %.1e water %.1e (dug %.1f sand, %.1f rock)", eS, eW, t.removedSand, t.removedRock))

	-- Lava poured into the pond: cools to basalt, boils water off (counted), and fuses the sand it lies on.
	local m1 = snapshot(t)
	local a = t.addedSand
	t.addedSand, t.addedWater, t.addedLava, t.removedSand, t.removedRock, t.removedLava = 0, 0, 0, 0, 0, 0
	t.fusedSand, t.cooledLava, t.steamWater, t.evapWater = 0, 0, 0, 0
	local hiss = 0
	for _ = 1, 200 do
		t:spawnLava(16, 14, 3, 0.4)
		t:step()
		hiss += t.hiss
	end
	settle(t, 20000)
	local eS2, eW2, eL2, eR2 = massErrors(t, m1)
	local basalt = 0
	for i = 0, 64 * 64 - 1 do
		basalt += buffer.readu8(t.basalt, i)
	end
	Out.check("sandtable.lava_quench", hiss > 0 and t.steamWater > 0 and basalt > 0 and snapshot(t).lava == 0, string.format("%d hiss events, %.1f water boiled, %d basalt cells, %.2f sand fused (prior drops %.1f)", hiss, t.steamWater, basalt, t.fusedSand, a))
	Out.check("sandtable.lava_mass", math.max(eS2, eW2, eL2, eR2) < 1e-10, string.format("sand %.1e water %.1e lava %.1e rock %.1e", eS2, eW2, eL2, eR2))
end

-- 2. The 256^2 table ------------------------------------------------------------------------------------------
local N = 256
local SPRING = { 44, 12 }
local CRATER = { 194, 146 }
local LAKE = { 118, 214 }
local LEVEL = 6.5
local RIVER = { { 44, 4 }, { 64, 52 }, { 52, 100 }, { 78, 148 }, { 104, 196 } }
local GULLY = { { 191, 152 }, { 176, 176 }, { 160, 200 }, { 148, 214 } }

local function distPath(path: { { number } }, x: number, y: number): number
	local best = math.huge
	for k = 1, #path - 1 do
		local ax, ay, bx, by = path[k][1], path[k][2], path[k + 1][1], path[k + 1][2]
		local dx, dy = bx - ax, by - ay
		local u = math.clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0, 1)
		local ex, ey = x - ax - dx * u, y - ay - dy * u
		best = math.min(best, ex * ex + ey * ey)
	end
	return math.sqrt(best)
end
local function smooth(v: number): number
	v = math.clamp(v, 0, 1)
	return v * v * (3 - 2 * v)
end

-- Dunes (gentle windward, steep lee) over a north-to-south tilt, an old valley under the dunes, a lake basin,
-- and a volcano whose gully runs into the lake.
local function buildScene(): ST.SandTable
	local t = ST.new(N, N)
	local vn = ST.vnoise
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local ny = y / (N - 1)
			local rock = 6 + 26 * (1 - ny) ^ 1.5 + 4 * vn(x / 23, y / 23)
			local dx, dy = (x - LAKE[1]) / 72, (y - LAKE[2]) / 48
			rock -= 11 * smooth(1 - math.sqrt(dx * dx + dy * dy))
			local vx, vy = x - CRATER[1], y - CRATER[2]
			local vd = math.sqrt(vx * vx + vy * vy)
			local cone = 38 * math.max(0, 1 - vd / 60) ^ 1.6
			if vd < 8 then
				cone -= 7 * (1 - (vd / 8) ^ 2)
			end
			rock += cone * (0.9 + 0.18 * vn(x / 6, y / 6))
			local dv = distPath(RIVER, x + 6 * vn(x / 13, y / 13), y)
			rock -= 7 * math.exp(-dv * dv / (2 * 12 * 12))
			local dg = distPath(GULLY, x, y)
			rock -= (3 + 5 * math.clamp(cone / 3, 0, 1)) * math.exp(-dg * dg / (2 * 7 * 7))
			rock += 14 * math.max(0, vn(x / 15 + 5, y / 15) - 0.6) * (1 - ny)
			local band = smooth(1.4 - math.abs(ny - 0.45) / 0.3)
			local ph = (x * 0.42 + y * 0.91) / 21 + 1.6 * vn(x / 37, y / 37) + 0.4 * vn(x / 9, y / 9)
			local p = ph - math.floor(ph)
			local prof = if p < 0.72 then p / 0.72 else (1 - p) / 0.28
			local dune = 1.5 + 7 * prof * (0.6 + 0.6 * vn(x / 29 + 3, y / 29))
			local sand = (band * dune * smooth((dg - 6) / 14) + 0.8) * smooth(1 - cone / 6)
			t:setColumn(x, y, rock, sand)
		end
	end
	t:refresh()
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local dx, dy = (x - LAKE[1]) / 90, (y - LAKE[2]) / 60
			local o = (y * N + x) * 8
			if dx * dx + dy * dy < 1 and buffer.readf64(t.G, o) < LEVEL then
				buffer.writef64(t.water, o, LEVEL - buffer.readf64(t.G, o))
			end
		end
	end
	t:refresh()
	return t
end

-- Preview renderer. Shadows are a preview stand-in for the engine's (heightShadow over the drawn surfaces).
local SUN = { -0.75, 0.5, -0.35 }
local function render(t: ST.SandTable, w: number, h: number, cam: { number }): buffer
	local SS = 2
	local v = MeshViz.new(w * SS, h * SS)
	v:light(SUN[1], SUN[2], SUN[3])
	v:scene({ sky = { 172, 200, 232 }, ground = { 96, 82, 64 }, sun = { 1.05, 0.98, 0.86 }, fog = { 196, 212, 230 }, fogDensity = 0.0011 })
	v:clearSky({ 104, 148, 206 }, { 214, 224, 236 })
	v:lookAt(cam[1], cam[2], cam[3], cam[4], cam[5], cam[6], cam[7])
	local hs = buffer.create(N * N * 8)
	local gimg, wimg, vw = (t.groundImg :: any).data, (t.waterImg :: any).data, N + 1
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local sum = 0
			for k = 0, 3 do
				local vi = ((y + k // 2) * vw + x + k % 2) * 4
				sum += math.max(buffer.readf32(gimg, vi), buffer.readf32(wimg, vi))
			end
			buffer.writef64(hs, (y * N + x) * 8, sum / 4)
		end
	end
	local R = 2
	local lm = MeshViz.heightShadow(hs, N, N, t.cell, SUN[1], SUN[2], SUN[3], 5, R)
	local g, wm = t.ground :: HM.Terrain, t.waterMesh :: HM.Terrain
	for _, c in g.chunks do
		local ox, oz = HM.chunkOrigin(g, c)
		local surf = 2 * c.n * c.n
		v:shaded(c.pos, c.idx, surf, { offset = { ox, 0, oz }, nrm = c.nrm, uv = c.uv, tex = t.tex, tw = N, th = N, emit = t.emit, lightmap = lm, lw = N * R, lh = N * R })
		v:shaded(c.pos, c.idx, c.tcount, { offset = { ox, 0, oz }, tstart = surf, color = { 104, 78, 54 } }) -- table sides
	end
	for _, c in wm.chunks do
		local ox, oz = HM.chunkOrigin(wm, c)
		v:shaded(c.pos, c.idx, 2 * c.n * c.n, { offset = { ox, 0, oz }, nrm = c.nrm, uv = c.uv, lightmap = lm, lw = N * R, lh = N * R, vcol = c.col, useAlpha = true, spec = 0.9, shininess = 90, fresnel = 0.55 })
	end
	local out = v:downsample(SS)
	return out
end
local function sideBySide(a: buffer, b: buffer, w: number, h: number): buffer
	local out = buffer.create(w * 2 * h * 4)
	for y = 0, h - 1 do
		buffer.copy(out, y * w * 2 * 4, a, y * w * 4, w * 4)
		buffer.copy(out, (y * w * 2 + w) * 4, b, y * w * 4, w * 4)
	end
	return out
end

local WIDE = { -20, 110, 310, 140, 4, 118, 46 }
local LAVACAM = { 88, 40, 292, 184, 10, 160, 44 }
local RIVERCAM = { -30, 70, 200, 70, 6, 110, 52 }

local t = buildScene()
local tb = os.clock()
t:buildMeshes()
report("sandtable.build_meshes_2x16_chunks", os.clock() - tb, 1)
t:fullTexture()
local m0 = snapshot(t)

-- Triangle / vertex limits on both layers.
do
	local worstT, worstV, nch = 0, 0, 0
	for _, layer in { t.ground :: HM.Terrain, t.waterMesh :: HM.Terrain } do
		for _, c in layer.chunks do
			worstT, worstV, nch = math.max(worstT, c.tcount), math.max(worstV, c.vcount), nch + 1
		end
	end
	Out.check("sandtable.mesh_limits", worstT <= 20000 and worstV <= 60000, `{nch} chunks, worst {worstV} verts / {worstT} tris (limit 60000 / 20000)`)
end

-- Collision debounce bookkeeping: frame of the last ground change and of the last bake request per chunk.
local frame = 0
local lastChange, lastBake, bakes = {}, {}, 0
local function frameUpdate(): (number, number, number)
	frame += 1
	local a = os.clock()
	t:step()
	local b = os.clock()
	t:updateMeshes()
	local c = os.clock()
	t:updateTexture()
	local d = os.clock()
	local gt = t.ground :: HM.Terrain
	for _, ch in t.groundChanged do
		lastChange[ch.cy * gt.ncx + ch.cx + 1] = frame
	end
	for _, key in t.colDue do
		lastBake[key] = frame
		bakes += 1
	end
	return b - a, c - b, d - c
end

for _ = 1, 300 do
	frameUpdate()
end
local before = render(t, 560, 340, WIDE)
local riverBefore = render(t, 560, 340, RIVERCAM)
local sandRiver0 = 0
for y = 0, N - 1 do
	for x = 0, N - 1 do
		if distPath(RIVER, x, y) < 10 and y > 30 and y < 180 then
			sandRiver0 += buffer.readf64(t.sand, (y * N + x) * 8)
		end
	end
end

-- River: a player pours water at the top. Then an eruption while the river still runs.
local tStep, tMesh, tTex, nAct, maxAwake = 0, 0, 0, 0, 0
local awakeMap = buffer.create(N * N * 4)
local function activeFrame()
	local a, b, c = frameUpdate()
	tStep += a
	tMesh += b
	tTex += c
	nAct += 1
	maxAwake = math.max(maxAwake, t.activeChunks)
end
for _ = 1, 700 do
	t:pourWater(SPRING[1], SPRING[2], 4, 0.25)
	activeFrame()
end
report("sandtable.river.step_256", tStep, nAct)
report("sandtable.river.mesh_update", tMesh, nAct)
report("sandtable.river.texture_update", tTex, nAct)
report("sandtable.river.frame_total", tStep + tMesh + tTex, nAct)
local riverAwake = maxAwake
tStep, tMesh, tTex, nAct, maxAwake = 0, 0, 0, 0, 0
local after = render(t, 560, 340, WIDE)
local riverAfter = render(t, 560, 340, RIVERCAM)
Out.image("sandtable_pour_before_after", 1120, 340, sideBySide(before, after, 560, 340))
Out.image("sandtable_river_before_after", 1120, 340, sideBySide(riverBefore, riverAfter, 560, 340))
local sandRiver1, sedNow = 0, 0
for y = 0, N - 1 do
	for x = 0, N - 1 do
		if distPath(RIVER, x, y) < 10 and y > 30 and y < 180 then
			sandRiver1 += buffer.readf64(t.sand, (y * N + x) * 8)
		end
		sedNow += buffer.readf64(t.sed, (y * N + x) * 8)
	end
end
Out.check("sandtable.river_carves", sandRiver1 < sandRiver0 - 50, string.format("sand along the river %.0f -> %.0f, %.0f in suspension", sandRiver0, sandRiver1, sedNow))

local hissTotal = 0
for k = 1, 900 do
	t:pourWater(SPRING[1], SPRING[2], 4, 0.25)
	if k <= 800 then
		t:spawnLava(CRATER[1], CRATER[2], 4, 0.45)
	end
	activeFrame()
	hissTotal += t.hiss
	if k == 600 then -- snapshot of which chunks are awake mid-eruption
		for y = 0, N - 1 do
			for x = 0, N - 1 do
				local i = y * N + x
				local c = buffer.readu32(t.tex, i * 4)
				local on = buffer.readu8(t.awake, (y // ST.CHUNK) * t.cw + x // ST.CHUNK) ~= 0
				local edge = x % ST.CHUNK == 0 or y % ST.CHUNK == 0
				local r, g, b = bit32.band(c, 255), bit32.band(bit32.rshift(c, 8), 255), bit32.band(bit32.rshift(c, 16), 255)
				local l = (r + g + b) / 3
				if on then
					r, g, b = l * 0.5 + 120, l * 0.5 + 40, l * 0.3 + 20
				else
					r, g, b = l * 0.45, l * 0.5, l * 0.6
				end
				if edge then
					r, g, b = 30, 30, 30
				end
				buffer.writeu32(awakeMap, i * 4, bit32.bor(math.floor(r), bit32.lshift(math.floor(g), 8), bit32.lshift(math.floor(b), 16), 0xFF000000))
			end
		end
		Out.image("sandtable_lava_meets_water", 960, 540, render(t, 960, 540, LAVACAM))
	end
end
Out.image("sandtable_hero", 960, 540, render(t, 960, 540, WIDE))
report("sandtable.eruption.step_256", tStep, nAct)
report("sandtable.eruption.mesh_update", tMesh, nAct)
report("sandtable.eruption.texture_update", tTex, nAct)
report("sandtable.eruption.frame_total", tStep + tMesh + tTex, nAct)
local basalt = 0
for i = 0, N * N - 1 do
	basalt += buffer.readu8(t.basalt, i)
end
Out.check("sandtable.lava_meets_water", hissTotal > 0 and t.steamWater > 0 and basalt > 500, string.format("%d hiss events, %.0f water boiled, %d basalt cells, %.0f lava cooled", hissTotal, t.steamWater, basalt, t.cooledLava))
Out.check("sandtable.chunks_sleep_while_active", maxAwake < t.cw * t.ch, `at most {riverAwake} (river) / {maxAwake} (eruption) of {t.cw * t.ch} chunks awake`)

-- Sources off: everything settles (lava cools, water levels, sand rests) and the table sleeps.
local settledAt = -1
local tq = os.clock()
for s = 1, 12000 do
	frameUpdate()
	if t:awakeCount() == 0 then
		settledAt = s
		break
	end
end
local settleSec = os.clock() - tq
for _ = 1, t.colSettle + 2 do -- let the collision debounce fire for chunks that changed last
	frameUpdate()
end
local tSettled = Out.time("sandtable.step_settled_256", 2000, function()
	t:step()
end)
local tMeshIdle = Out.time("sandtable.mesh_update_settled", 2000, function()
	t:updateMeshes()
end)
Out.check("sandtable.table_sleeps", settledAt > 0 and t.activeChunks == 0, `asleep {settledAt} steps after the sources stopped ({string.format("%.1f", settleSec)} s incl. mesh + texture)`)
Out.check("sandtable.settled_cost_near_zero", tSettled < 0.02 * tStep * 1000 / nAct and tMeshIdle < 0.05, string.format("settled step %.4f ms vs active %.3f ms; idle mesh update %.4f ms", tSettled, tStep * 1000 / nAct, tMeshIdle))
local stale, changed = 0, 0
for key, f in lastChange do
	changed += 1
	if (lastBake[key] or 0) < f then
		stale += 1
	end
end
local pending = 0
for _, p in t.colPending do
	pending += p
end
Out.check("sandtable.collision_debounced", stale == 0 and pending == 0 and bakes < frame * changed / 10, string.format("%d bakes over %d frames for %d changed chunks (%.1f%% of per-frame), none stale", bakes, frame, changed, 100 * bakes / math.max(frame * changed, 1)))

-- Exact mass identities over the whole run.
do
	local eS, eW, eL, eR = massErrors(t, m0)
	Out.check("sandtable.mass_identities_256", math.max(eS, eW, eL, eR) < 1e-9 and math.abs(t.clampLoss) < 1e-9, string.format("rel err sand %.1e water %.1e lava %.1e rock %.1e (clamped %.1e); added water %.0f, boiled %.0f, fused sand %.0f", eS, eW, eL, eR, t.clampLoss, t.addedWater, t.steamWater, t.fusedSand))
end

-- Incremental mesh and texture == full rebuild from the same sim state.
do
	t:flushRender()
	t:updateMeshes()
	t:updateTexture()
	local g1, w1 = t.ground :: HM.Terrain, t.waterMesh :: HM.Terrain
	local gi1, wi1 = buffer.tostring((t.groundImg :: any).data), buffer.tostring((t.waterImg :: any).data)
	local tex1, emit1 = buffer.tostring(t.tex), buffer.tostring(t.emit)
	t:buildMeshes()
	t:fullTexture()
	local same, detail = true, "byte-identical: 2 vertex images, 32 chunks (pos/nrm/uv/col/idx), texture + glow"
	if gi1 ~= buffer.tostring((t.groundImg :: any).data) or wi1 ~= buffer.tostring((t.waterImg :: any).data) then
		same, detail = false, "vertex images differ"
	end
	for li, pair in { { g1, t.ground }, { w1, t.waterMesh } } do
		for k, c in (pair[1] :: any).chunks do
			local f = (pair[2] :: any).chunks[k]
			for _, field in { "pos", "nrm", "uv", "col", "idx" } do
				if buffer.tostring(c[field]) ~= buffer.tostring(f[field]) then
					same, detail = false, `layer {li} chunk {k} field {field}`
				end
			end
		end
	end
	Out.check("sandtable.incremental_mesh_equals_full", same, detail)
	Out.check("sandtable.incremental_texture_equals_full", tex1 == buffer.tostring(t.tex) and emit1 == buffer.tostring(t.emit))
end

Out.time("sandtable.texture_full_256", 20, function()
	t:fullTexture()
end)
Out.image("sandtable_texture_and_awake", N * 2, N, sideBySide(t.tex, awakeMap, N, N))
Out.image("sandtable_settled", 960, 540, render(t, 960, 540, WIDE))
Out.done()
