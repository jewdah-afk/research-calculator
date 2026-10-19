local Out = require("./Out")
local RC = require("../fx/RadianceCascades")

local EXPOSURE = 0.3

-- Scene authored at 256x256, scaled by k for other sizes.
-- Room box (enclosed, unlit) and probe points are returned for the checks.
local function buildScene(rc: RC.RadianceCascades, t: number)
	local k = rc.w / 256
	local function R(x0: number, y0: number, x1: number, y1: number, er: number, eg: number, eb: number, ar: number, ag: number, ab: number)
		rc:rect(math.floor(x0 * k), math.floor(y0 * k), math.floor(x1 * k), math.floor(y1 * k), er, eg, eb, ar, ag, ab)
	end
	rc:clear()
	-- white-ish walls with doorways
	R(0, 0, 256, 4, 0, 0, 0, 0.35, 0.35, 0.38)
	R(0, 252, 256, 256, 0, 0, 0, 0.35, 0.35, 0.38)
	R(0, 0, 4, 256, 0, 0, 0, 0.35, 0.35, 0.38)
	R(252, 0, 256, 256, 0, 0, 0, 0.35, 0.35, 0.38)
	R(96, 4, 102, 70, 0, 0, 0, 0.35, 0.35, 0.38)
	R(96, 100, 102, 140, 0, 0, 0, 0.35, 0.35, 0.38)
	R(4, 134, 70, 140, 0, 0, 0, 0.35, 0.35, 0.38)
	-- red wall (colour bleed) and green pillar
	R(140, 20, 146, 120, 0, 0, 0, 0.95, 0.12, 0.08)
	R(40, 190, 60, 210, 0, 0, 0, 0.15, 0.85, 0.25)
	-- enclosed dark room
	R(176, 160, 246, 166, 0, 0, 0, 0.35, 0.35, 0.38)
	R(176, 240, 246, 246, 0, 0, 0, 0.35, 0.35, 0.38)
	R(176, 160, 182, 246, 0, 0, 0, 0.35, 0.35, 0.38)
	R(240, 160, 246, 246, 0, 0, 0, 0.35, 0.35, 0.38)
	-- lights
	rc:circle(46 * k, 60 * k, 7 * k, 14, 7, 2)
	rc:circle(212 * k, 70 * k, 6 * k, 2, 8, 14)
	rc:circle(120 * k, 200 * k, 6 * k, 12, 3, 12)
	-- moving occluder orbiting the orange light
	local ox, oy = 46 + 30 * math.cos(t), 60 + 30 * math.sin(t)
	rc:circle(ox * k, oy * k, 8 * k, 0, 0, 0, 0.4, 0.4, 0.45)
end

local function lum(rc: RC.RadianceCascades, x: number, y: number): number
	local o = (y * rc.w + x) * 12
	return buffer.readf32(rc.fluence, o) + buffer.readf32(rc.fluence, o + 4) + buffer.readf32(rc.fluence, o + 8)
end

-- EDT exactness vs brute force on a small random scene; JFA close to EDT.
do
	local s = RC.new(48, 40, { method = "edt", maxDist = 1e9 })
	local j = RC.new(48, 40, { method = "jfa", maxDist = 1e9 })
	local cl = RC.new(48, 40, { method = "edt" }) -- default: clamped to maxDist (16)
	local seed = 12345
	local pts = {}
	for _ = 1, 25 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local x = seed % 48
		seed = (seed * 1103515245 + 12345) % 2147483648
		local y = seed % 40
		s:rect(x, y, x + 1, y + 1, 0, 0, 0)
		j:rect(x, y, x + 1, y + 1, 0, 0, 0)
		cl:rect(x, y, x + 1, y + 1, 0, 0, 0)
		table.insert(pts, { x, y })
	end
	s:buildScene()
	j:buildScene()
	cl:buildScene()
	local maxErr, maxJ, maxC = 0, 0, 0
	for y = 0, 39 do
		for x = 0, 47 do
			local best = math.huge
			for _, p in pts do
				best = math.min(best, math.sqrt((p[1] - x) ^ 2 + (p[2] - y) ^ 2))
			end
			local d = buffer.readf32(s.sdf, (y * 48 + x) * 4)
			maxErr = math.max(maxErr, math.abs(d - best))
			maxJ = math.max(maxJ, math.abs(buffer.readf32(j.sdf, (y * 48 + x) * 4) - best))
			maxC = math.max(maxC, math.abs(buffer.readf32(cl.sdf, (y * 48 + x) * 4) - math.min(best, cl.maxDist)))
		end
	end
	Out.check("rc.edt_exact", maxErr < 1e-3, string.format("max err %.5f", maxErr))
	Out.check("rc.jfa_close", maxJ < 1.5, string.format("max err %.3f", maxJ))
	Out.check("rc.edt_clamped", maxC < 1e-3, string.format("max err %.5f (maxDist %d)", maxC, cl.maxDist))
end

local rc = RC.new(256, 256, { spacing = 2, exposure = EXPOSURE })
-- a few frames so the one-bounce feedback converges
for f = 0, 7 do
	buildScene(rc, 0.7 + f * 0.02)
	rc:render()
end
Out.image("rc_256", 256, 256, rc.rgba)

-- Enclosed room interior (inset 3px from the walls) stays near black.
local sum, mx, n = 0, 0, 0
for y = 169, 236 do
	for x = 185, 236 do
		local l = lum(rc, x, y)
		sum += l
		mx = math.max(mx, l)
		n += 1
	end
end
local open = lum(rc, 70, 100)
Out.check("rc.dark_room", sum / n < 0.002 * open and mx < 0.02 * open, string.format("mean %.5f max %.5f (open floor %.4f)", sum / n, mx, open))

-- Falloff from the cyan light (212,70) heading down-left into open floor.
local prev = math.huge
local okFall = true
local det = {}
for _, d in { 10, 16, 24, 36, 52 } do
	local x, y = math.floor(212 - d * 0.6), math.floor(70 + d * 0.8)
	local l = lum(rc, x, y)
	table.insert(det, string.format("%d:%.3f", d, l))
	if l >= prev then
		okFall = false
	end
	prev = l
end
Out.check("rc.falloff", okFall, table.concat(det, " "))

-- Colour bleed: next to the red wall's lit (right) face, the floor is redder with the bounce on.
do
	local nb = RC.new(256, 256, { spacing = 2, exposure = EXPOSURE, bounce = 0 })
	buildScene(nb, 0.84)
	nb:render()
	local o = (60 * 256 + 148) * 12
	local r1, g1 = buffer.readf32(rc.fluence, o), buffer.readf32(rc.fluence, o + 4)
	local r0, g0 = buffer.readf32(nb.fluence, o), buffer.readf32(nb.fluence, o + 4)
	Out.check("rc.colour_bleed", r1 / g1 > 1.15 * (r0 / g0), string.format("r/g with bounce %.3f, without %.3f", r1 / g1, r0 / g0))
	Out.image("rc_256_nobounce", 256, 256, nb.rgba)
end

-- Moving occluder, a few frames apart (strip of 4 frames at 128).
local small = RC.new(128, 128, { spacing = 2, exposure = EXPOSURE })
local strip = buffer.create(512 * 128 * 4)
for f = 0, 3 do
	for _ = 1, 4 do
		buildScene(small, f * 1.6)
		small:render()
	end
	for y = 0, 127 do
		buffer.copy(strip, (y * 512 + f * 128) * 4, small.rgba, y * 128 * 4, 128 * 4)
	end
end
Out.image("rc_128_moving", 512, 128, strip)

local frame = 0
Out.time("rc.frame_128_moving", 10, function()
	frame += 1
	buildScene(small, frame * 0.05)
	small:render()
end)
Out.time("rc.frame_256_moving", 4, function()
	frame += 1
	buildScene(rc, frame * 0.05)
	rc:render()
end)
Out.time("rc.frame_256_static", 4, function()
	rc:render()
end)
local vanilla = RC.new(256, 256, { spacing = 2, fix = false })
buildScene(vanilla, 1)
Out.time("rc.frame_256_static_vanilla", 4, function()
	vanilla:render()
end)
local coarse = RC.new(256, 256, { spacing = 4 })
buildScene(coarse, 1)
Out.time("rc.frame_256_static_spacing4", 4, function()
	coarse:render()
end)
Out.time("rc.edt_256", 10, function()
	rc.method = "edt"
	rc:buildScene()
end)
Out.time("rc.jfa_256", 3, function()
	rc.method = "jfa"
	rc:buildScene()
end)

-- Real-time path -------------------------------------------------------------------------------------

local function relErr(a: RC.RadianceCascades, b: RC.RadianceCascades): number
	local s, ref = 0, 0
	for i = 0, a.w * a.h * 3 - 1 do
		local x, y = buffer.readf32(a.fluence, i * 4), buffer.readf32(b.fluence, i * 4)
		s += math.abs(x - y)
		ref += y
	end
	return s / ref
end

-- Incremental edits: moving the occluder patches the sdf exactly and the ray cache locally.
do
	local inc = RC.new(256, 256, { spacing = 2, exposure = EXPOSURE })
	local full = RC.new(256, 256, { spacing = 2, exposure = EXPOSURE })
	buildScene(inc, 1.0)
	inc:render()
	for f = 1, 6 do
		buildScene(inc, 1.0 + f * 0.05)
		inc:render()
	end
	buildScene(full, 1.3)
	full:buildScene()
	local sdfErr = 0
	for i = 0, 256 * 256 - 1 do
		sdfErr = math.max(sdfErr, math.abs(buffer.readf32(inc.sdf, i * 4) - buffer.readf32(full.sdf, i * 4)))
	end
	for _ = 1, 10 do
		inc:render()
		full:render()
	end
	local e = relErr(inc, full)
	Out.check("rc.incremental_edit", sdfErr < 1e-4 and e < 0.01 and inc.stats.partial >= 6,
		string.format("sdf max err %.6f, fluence rel err %.4f, %d partial updates, %d segments re-marched last edit", sdfErr, e, inc.stats.partial, inc.stats.remarched))
end

-- Moving analytic light, amortized: step(budget) per frame vs the full-quality render.
local BUDGET = 3.5
local function lightAt(r: RC.RadianceCascades, f: number)
	r:setLight(1, 110 + 45 * math.cos(f * 0.09), 160 + 20 * math.sin(f * 0.09), 5, 3, 14, 5)
end
local am = RC.new(256, 256, { spacing = 2, exposure = EXPOSURE })
buildScene(am, 0.7)
lightAt(am, 0)
for _ = 1, 8 do
	am:render()
end
local shots = buffer.create(1024 * 512 * 4)
local function shot(src: buffer, col: number, row: number)
	for y = 0, 255 do
		buffer.copy(shots, ((row * 256 + y) * 1024 + col * 256) * 4, src, y * 256 * 4, 256 * 4)
	end
end
local tot, worst, cycles = 0, 0, 0
for f = 1, 60 do
	local t0 = os.clock()
	lightAt(am, f)
	if am:step(BUDGET) then
		cycles += 1
	end
	local dt = (os.clock() - t0) * 1000
	tot += dt
	worst = math.max(worst, dt)
	if f % 15 == 0 then
		shot(am.rgba, f // 15 - 1, 0)
	end
end
local ref = RC.new(256, 256, { spacing = 2, exposure = EXPOSURE })
buildScene(ref, 0.7)
lightAt(ref, 60)
for _ = 1, 10 do
	ref:render()
end
local moving = relErr(am, ref)
-- after the light stops: frames (and full cycles) until within 1% of the full-quality result
local settledFrame, settledCycle, after, k = -1, -1, 0, 0
local e = moving
while after < 6 and k < 600 do
	k += 1
	if am:step(BUDGET) then
		after += 1
	end
	e = relErr(am, ref)
	if settledFrame < 0 and e < 0.01 then
		settledFrame, settledCycle = k, after
	end
end
print(string.format("@@INFO amortized: %.2f ms/frame avg (worst %.2f), %d full cycles in 60 frames (%.1f frames/cycle)", tot / 60, worst, cycles, 60 / math.max(1, cycles)))
print(string.format("@@INFO error vs full: while moving %.4f; < 1%% %d frames after stop; %.5f after %d frames", moving, settledFrame, e, k))
-- (+1 ms: the last work item of a frame may overrun; the interpreter is ~8x slower per item)
Out.check("rc.amortized_budget", tot / 60 <= BUDGET + 1, string.format("%.2f ms/frame avg over 60 frames, budget %.1f, %.1f frames per full cycle", tot / 60, BUDGET, 60 / math.max(1, cycles)))
Out.check("rc.amortized_converges", settledFrame > 0 and settledCycle <= 3 and e < 0.003,
	string.format("rel MAD < 1%% after %d frames (%d full cycles); %.5f after %d frames; while moving %.4f", settledFrame, settledCycle, e, k, moving))
do
	local sum, mx, n = 0, 0, 0
	for y = 169, 236 do
		for x = 185, 236 do
			local l = lum(am, x, y)
			sum += l
			mx = math.max(mx, l)
			n += 1
		end
	end
	local open = lum(am, 70, 100)
	Out.check("rc.amortized_dark_room", sum / n < 0.002 * open and mx < 0.02 * open, string.format("mean %.5f max %.5f (open floor %.4f)", sum / n, mx, open))
end
shot(am.rgba, 0, 1)
shot(ref.rgba, 1, 1)
local diff = buffer.create(256 * 256 * 4)
for i = 0, 256 * 256 - 1 do
	local a, b = buffer.readu32(am.rgba, i * 4), buffer.readu32(ref.rgba, i * 4)
	local d = 0
	for c = 0, 2 do
		local s0 = 8 * c
		d = math.max(d, math.abs(bit32.extract(a, s0, 8) - bit32.extract(b, s0, 8)))
	end
	local v = math.min(255, d * 16)
	buffer.writeu32(diff, i * 4, v + v * 256 + v * 65536 + 0xFF000000)
end
shot(diff, 2, 1)
do -- light only, no static emitters: shows the analytic light's shadows clearly
	local solo = RC.new(256, 256, { spacing = 2, exposure = EXPOSURE })
	buildScene(solo, 0.7)
	for _, c in { { 46, 60, 7 }, { 212, 70, 6 }, { 120, 200, 6 } } do
		solo:circle(c[1], c[2], c[3], 0, 0, 0, 0.35, 0.35, 0.38)
	end
	lightAt(solo, 60)
	for _ = 1, 6 do
		solo:render()
	end
	shot(solo.rgba, 3, 1)
end
Out.image("rc_256_amortized", 1024, 512, shots)

local fl = 0
Out.time("rc.frame_256_light_full", 4, function()
	fl += 1
	lightAt(ref, fl)
	ref:render()
end)
Out.time("rc.frame_256_light_amortized", 30, function()
	fl += 1
	lightAt(am, fl)
	am:step(BUDGET)
end)
Out.done()
