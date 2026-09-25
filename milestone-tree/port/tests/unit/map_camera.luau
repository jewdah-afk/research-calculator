--!nocheck
--[[
	MapCamera.luau against art/camera.js: the parity cases of tools/camera_cases.js (layer placement, zoom about a
	point, hard and rubber clamps, mapScale, biome weights and colours, the hash, every sprite group's motion
	channels, particle fields), plus the client framing numbers of DESIGN.md 3.3 and the whole-pixel tile edges of
	REALM.md 9.3. Run from port/: node tools/camera_cases.js > data/unit/camera_cases.luau && luau tests/unit/map_camera.luau
]]
local MC = require("../../../src/client/Map/MapCamera")
local Realm = require("../../../src/shared/Realm")
local cases = require("../../data/unit/camera_cases")

local failures, checks = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failures += 1
		if failures <= 25 then print("  FAIL  " .. what) end
	end
end
local function near(a: number, b: number, tol: number?): boolean
	local t = tol or 1e-9
	return math.abs(a - b) <= t * math.max(1, math.abs(a), math.abs(b))
end

-- the constants camera.js and realm.json share
check(MC.Z_MAX == Realm.camera.zMax, "zMax")
check(MC.ZOOM_SLACK == Realm.camera.zoomSlack, "zoomSlack")
check(MC.OVERSCROLL == Realm.camera.overscroll, "overscroll")
check(MC.ZOOM_OUT_FIT == Realm.camera.zoomOutFit, "zoomOutFit")
check(MC.PAN_MARGIN.x == Realm.camera.panMargin[1] and MC.PAN_MARGIN.y == Realm.camera.panMargin[2], "pan margin")
check(MC.NO_MARGIN.x == 0 and MC.NO_MARGIN.y == 0, "no margin")
for k, v in Realm.camera.domain do check(MC.DOMAIN[k] == v, "domain " .. k) end
check(MC.WORLD.w == Realm.world.w and MC.WORLD.h == Realm.world.h, "world size")
check(MC.START.x == Realm.camera.start[1] and MC.START.y == Realm.camera.start[2], "start centre")

local function fieldParticles(F, low: boolean)
	if not low then return F.particles end
	local out = {}
	for _, p in F.particles do if p.low == 1 then table.insert(out, p) end end
	return out
end

local run = {
	mapScale = function(i) local m = MC.mapScale({ w = i[1], h = i[2] }); return { m.scale, m.w, m.h, m.box.w, m.box.h } end,
	layerOffset = function(i)
		local ox, oy, s = MC.layerOffset({ f = i[1], w = i[2], h = i[3], ax = i[4], ay = i[5] }, { x = i[6], y = i[7] }, i[8], { w = i[9], h = i[10] })
		return { ox, oy, s }
	end,
	zoomAt = function(i) local c = MC.zoomAt({ x = i[1], y = i[2] }, i[3], i[4], { x = i[5], y = i[6] }, { w = i[7], h = i[8] }); return { c.x, c.y } end,
	clampCamera = function(i) local c = MC.clampCamera({ x = i[1], y = i[2] }, i[3], { w = i[4], h = i[5] }, i[6] == 1); return { c.x, c.y, c.z } end,
	clampCameraM = function(i)
		local c = MC.clampCamera({ x = i[1], y = i[2] }, i[3], { w = i[4], h = i[5] }, i[6] == 1, { x = i[7], y = i[8] })
		return { c.x, c.y, c.z }
	end,
	panLimits = function(i)
		local L = MC.panLimits(i[1], { w = i[2], h = i[3] }, i[4], { x = i[5], y = i[6] })
		return { L.x0, L.x1, L.y0, L.y1 }
	end,
	startCamera = function(i) local c = MC.startCamera({ w = i[1], h = i[2] }); return { c.x, c.y, c.z, MC.startZoom({ w = i[1], h = i[2] }) } end,
	rubberBand = function(i) return { MC.rubberBand(i[1]) } end,
	zoomRange = function(i)
		local V = { w = i[1], h = i[2] }
		local lo, hi = MC.zoomRange(V, i[3] == 1)
		return { MC.zMin(V), MC.zCover(V), lo, hi }
	end,
	biome = function(i) local w = MC.biome({ x = i[1], y = i[2] }, Realm.biome, i[3], { w = i[4], h = i[5] }); return { w.rift, w.corrupt, w.cover } end,
	corruptLight = function(i) return { MC.corruptLight(Realm.biome, { x = i[1], y = i[2] }) } end,
	biomeFieldColor = function(i)
		local kind = Realm.fields[i[1] + 1].kinds[i[2] + 1]
		return MC.biomeFieldColor(kind, i[3], i[4], { rift = i[5], corrupt = i[6], cover = 0 }, Realm.biome, { x = i[7], y = i[8] })
	end,
	biomeSpriteColor = function(i)
		return MC.biomeSpriteColor(Realm.sprites[i[1] + 1].color, { rift = i[2], corrupt = i[3], cover = 0 }, Realm.biome, { x = i[4], y = i[5] })
	end,
	hash01 = function(i) return { MC.hash01(i[1], i[2]) } end,
	spriteState = function(i)
		local s = MC.spriteState(Realm.sprites[i[1] + 1].instances[i[2] + 1], i[3])
		return { s.dx, s.dy, s.rot, s.scale, s.alpha, s.grad }
	end,
	fieldPlace = function(i)
		local F = Realm.fields[i[1] + 1]
		local out = {}
		for _, p in MC.fieldPlace(F, fieldParticles(F, i[2] == 1), { x = i[3], y = i[4] }, i[5], { w = i[6], h = i[7] }, i[8]) do
			table.insert(out, p.i); table.insert(out, p.x); table.insert(out, p.y); table.insert(out, p.size); table.insert(out, p.alpha)
		end
		return out
	end,
}

local byKind = {}
for n, c in cases do
	local fn = run[c.f]
	if not fn then check(false, "no runner for " .. c.f); continue end
	byKind[c.f] = (byKind[c.f] or 0) + 1
	local ok, got = pcall(fn, c.i)
	if not ok then check(false, string.format("case %d %s: error %s", n, c.f, tostring(got))); continue end
	local same = #got == #c.o
	if same then
		for k = 1, #got do if not near(got[k], c.o[k]) then same = false; break end end
	end
	check(same, string.format("case %d %s", n, c.f))
end
local kinds = {}
for k, n in byKind do table.insert(kinds, k .. " " .. n) end
table.sort(kinds)

-- DESIGN.md 3.3: the HUD-safe start at 1920x1080 is z .505, C (1901, 1146)
do
	local V = { w = 1920, h = 1080 }
	local C, z = MC.startFraming(V, { x = 0, y = 100, w = 1920, h = 884 }, "WIDE")
	check(near(z, 884 / 1750, 1e-12), "start zoom 1920x1080 " .. z)
	check(math.abs(C.x - 1901) < 1 and math.abs(C.y - 1146) < 1, string.format("start centre 1920x1080 (%.1f, %.1f)", C.x, C.y))
	local C2, z2 = MC.startFraming({ w = 844, h = 390 }, { x = 0, y = 76, w = 844, h = 314 }, "COMPACT", { x = 1500, y = 1900 }, 0.6)
	check(near(z2, 0.34), "phone rest zoom .34")
	local q = MC.worldToScreen(C2, z2, { w = 844, h = 390 }, { x = 1500, y = 1900 })
	check(q.y <= 390 and q.y >= 76, "phone focus stays on screen")
end
-- fly-to lands the node at the free rect's centre when the clamp allows it
do
	local V = { w = 760, h = 1080 }
	local C, z = MC.flyTarget({ x = 1500, y = 1580 }, 0.9, V, { x = 0, y = 100, w = 760, h = 980 })
	local q = MC.worldToScreen(C, z, V, { x = 1500, y = 1580 })
	check(math.abs(q.x - 380) < 1e-6 and math.abs(q.y - 590) < 1e-6, "fly target centres the free rect")
	local Ce = MC.flyTarget({ x = 3690, y = 930 }, 0.9, V, nil)
	local lim = MC.panLimits(0.9, V, 0)
	check(Ce.x <= lim.x1 + 1e-9, "fly target respects the east pan limit")
	check(math.abs(Ce.x - 3690) < 1e-9, "the pan margin lets the fly target centre CM")
	-- the margin is capped at half the view: the screen centre never leaves the world
	local far = MC.clampCamera({ x = 1e6, y = -1e6 }, 1.25, V, false)
	check(far.x == 3840 and far.y == 0, string.format("margin capped at half the view (%.1f, %.1f)", far.x, far.y))
	-- and the start framing stays inside the world rect (no margin)
	local Cs, zs = MC.startFraming({ w = 844, h = 390 }, { x = 0, y = 76, w = 844, h = 314 }, "WIDE")
	local hw = 844 / (2 * zs)
	check(Cs.x - hw >= -1e-9 and Cs.x + hw <= 3840 + 1e-9, "start framing inside the world")
end
-- SmoothDamp converges without overshoot
do
	local x, v = 0, 0
	local over = false
	for _ = 1, 240 do
		x, v = MC.smoothDamp(x, 100, v, 0.35, 1 / 60)
		if x > 100 + 1e-9 then over = true end
	end
	check(math.abs(x - 100) < 0.01 and not over, "smoothDamp settles on the target " .. x)
end
-- REALM.md 9.3: tile edges on whole device pixels, shared by neighbours, at random cameras and three map scales
do
	local rng = MC.rng(7)
	local edges = { 0, 960, 1920, 2880, 3840 }
	local out = {}
	local bad = 0
	for _, m in { 0.687, 1, 1.5 } do
		for _ = 1, 50 do
			local o, s = (rng() - 0.5) * 4000, 0.2 + rng()
			MC.snapEdges(edges, m, o, s, out)
			for k = 1, #edges do
				if out[k] ~= math.floor(out[k]) then bad += 1 end
				if k > 1 and out[k] < out[k - 1] then bad += 1 end
			end
		end
	end
	check(bad == 0, "snapped tile edges are whole and ordered")
end

print(string.format("map_camera: %d cases (%s), %d checks, %d failures", #cases, table.concat(kinds, ", "), checks, failures))
if failures > 0 then error("map_camera failed") end
