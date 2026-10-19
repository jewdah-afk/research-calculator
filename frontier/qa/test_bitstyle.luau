-- Bit-style Reaper entrance: 480x270 palette-indexed frames at the five reference moments, timings,
-- and determinism checks. `luau test_bitstyle.luau -a dump [fps] [seconds]` streams every frame of
-- the animation instead (used by qa/bit_compare.py to encode the preview video).
local Out = require("./Out")
local Scene = require("../bitstyle/Scene")

local args = { ... }
local W, H = Scene.W, Scene.H

local t0 = os.clock()
local scene = Scene.new()
local buildMs = (os.clock() - t0) * 1000

if args[1] == "dump" then
	local fps = tonumber(args[2]) or 15
	local secs = tonumber(args[3]) or 10
	for f = 0, fps * secs - 1 do
		scene:draw(f / fps)
		scene.frame:resolve()
		Out.image(string.format("anim_%04d", f), W, H, scene.frame.rgba)
	end
	Out.done()
	return
end

print(string.format("@@TIME bitstyle.build_static %.4f 1", buildMs))

local MOMENTS = { { 0.5, "05" }, { 2.5, "25" }, { 4, "40" }, { 6.5, "65" }, { 9.5, "95" } }
local copies = {}
for _, m in MOMENTS do
	scene:draw(m[1])
	scene.frame:resolve()
	Out.image("bit_reaper_" .. m[2], W, H, scene.frame.rgba)
	copies[m[2]] = buffer.tostring(scene.frame.idx)
end

-- Determinism: redrawing a moment after others gives identical indices.
scene:draw(4)
Out.check("bitstyle.deterministic_t4", buffer.tostring(scene.frame.idx) == copies["40"])
local other = Scene.new()
other:draw(6.5)
Out.check("bitstyle.deterministic_fresh_t6.5", buffer.tostring(other.frame.idx) == copies["65"])

-- Palette discipline: count colours used per frame; everything must be a defined palette entry.
for _, m in MOMENTS do
	local s = copies[m[2]]
	local seen, n = {}, 0
	for i = 1, #s do
		local v = string.byte(s, i)
		if not seen[v] then
			seen[v] = true
			n += 1
		end
	end
	Out.check("bitstyle.colours_t" .. m[2], n <= 160 and not seen[233] and not seen[255], `{n} colours`)
end

-- The story actually progresses: calm frame has no void stone, final frame is mostly corrupted.
local function countMat(s: string, mat: number): number
	local c = 0
	for i = 1, #s do
		local v = string.byte(s, i)
		if v < 192 and v // 24 == mat then
			c += 1
		end
	end
	return c
end
Out.check("bitstyle.calm_has_no_void", countMat(copies["05"], 3) == 0)
local late = countMat(copies["95"], 3) / (W * H)
Out.check("bitstyle.corruption_spreads", late > 0.5, string.format("%.0f%% void stone at 9.5 s", late * 100))

Out.time("bitstyle.draw_t0.5", 40, function()
	scene:draw(0.5)
end)
Out.time("bitstyle.draw_t4", 40, function()
	scene:draw(4)
end)
Out.time("bitstyle.draw_t9.5", 40, function()
	scene:draw(9.5)
end)
-- Stage breakdown over the whole 10 s shot (native timings are what matter for the game).
scene.stats = {}
for f = 0, 149 do
	scene:draw(f / 15)
end
local st = scene.stats :: { [string]: number }
for _, k in { "lights", "ground", "overlays" } do
	print(string.format("@@TIME bitstyle.stage_%s_avg %.4f %d", k, st[k] / st.frames, st.frames))
end
print(string.format("@@TIME bitstyle.draw_avg_10s %.4f %d", (st.lights + st.ground + st.overlays) / st.frames, st.frames))
scene.stats = nil

Out.time("bitstyle.resolve_rgba", 40, function()
	scene.frame.allDirty = true
	scene.frame:resolve()
end)

Out.done()
