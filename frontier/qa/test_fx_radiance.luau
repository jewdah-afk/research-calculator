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
	local s = RC.new(48, 40, { method = "edt" })
	local j = RC.new(48, 40, { method = "jfa" })
	local seed = 12345
	local pts = {}
	for _ = 1, 25 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local x = seed % 48
		seed = (seed * 1103515245 + 12345) % 2147483648
		local y = seed % 40
		s:rect(x, y, x + 1, y + 1, 0, 0, 0)
		j:rect(x, y, x + 1, y + 1, 0, 0, 0)
		table.insert(pts, { x, y })
	end
	s:buildScene()
	j:buildScene()
	local maxErr, maxJ = 0, 0
	for y = 0, 39 do
		for x = 0, 47 do
			local best = math.huge
			for _, p in pts do
				best = math.min(best, math.sqrt((p[1] - x) ^ 2 + (p[2] - y) ^ 2))
			end
			local d = buffer.readf32(s.sdf, (y * 48 + x) * 4)
			maxErr = math.max(maxErr, math.abs(d - best))
			maxJ = math.max(maxJ, math.abs(buffer.readf32(j.sdf, (y * 48 + x) * 4) - best))
		end
	end
	Out.check("rc.edt_exact", maxErr < 1e-3, string.format("max err %.5f", maxErr))
	Out.check("rc.jfa_close", maxJ < 1.5, string.format("max err %.3f", maxJ))
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
Out.done()
