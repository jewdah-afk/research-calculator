local Out = require("./Out")
local VS = require("../fx/VoxelSpace")

local W, H = 320, 180
local t0 = os.clock()
local map = VS.generate(512, 7)
print(string.format("@@TIME vs.generate_512 %.4f 1", (os.clock() - t0) * 1000))
Out.image("vs_colormap", 512, 512, map.color)

local vs = VS.new(W, H, map)
local cam = vs.cam
local function place(x: number, y: number, yaw: number, above: number, pitch: number)
	cam.x, cam.y, cam.yaw, cam.pitch = x, y, yaw, pitch
	cam.height = vs:heightAt(x, y) + above
end

place(300, 470, 0.35, 70, 0.05)
vs:render()
Out.image("vs_view", W, H, vs.rgba)

-- Every pixel written (opaque), sky at the top, terrain at the bottom.
local opaque = true
for i = 0, W * H - 1 do
	if buffer.readu8(vs.rgba, i * 4 + 3) ~= 255 then
		opaque = false
		break
	end
end
Out.check("vs.all_pixels_written", opaque)
Out.check("vs.sky_top", buffer.readu32(vs.rgba, (W // 2) * 4) == buffer.readu32(vs.sky, 0))
Out.check("vs.ground_bottom", buffer.readu32(vs.rgba, ((H - 1) * W + W // 2) * 4) ~= buffer.readu32(vs.sky, (H - 1) * 4))

-- Static camera: two checkerboard fields reproduce the full frame exactly.
local full = buffer.create(W * H * 4)
buffer.copy(full, 0, vs.rgba)
buffer.fill(vs.rgba, 0, 0)
vs:renderCheckerboard()
vs:renderCheckerboard()
Out.check("vs.checkerboard_matches_full", buffer.tostring(full) == buffer.tostring(vs.rgba))

-- A flyover strip: different yaw / pitch / height.
local strip = buffer.create(W * 2 * H * 2 * 4)
local views = {
	{ 120, 200, 2.4, 40, 0.0 },
	{ 420, 90, -0.8, 110, 0.12 },
	{ 60, 330, 4.0, 25, -0.05 },
	{ 250, 250, 1.2, 160, 0.25 },
}
for k, v in views do
	place(v[1], v[2], v[3], v[4], v[5])
	vs:render()
	local ox, oy = ((k - 1) % 2) * W, ((k - 1) // 2) * H
	for y = 0, H - 1 do
		buffer.copy(strip, ((oy + y) * W * 2 + ox) * 4, vs.rgba, y * W * 4, W * 4)
	end
end
Out.image("vs_views", W * 2, H * 2, strip)

place(300, 470, 0.35, 70, 0.05)
local tFull = Out.time("vs.full_320x180", 30, function()
	cam.yaw += 0.01
	vs:render()
end)
local tCb = Out.time("vs.checkerboard_320x180", 30, function()
	cam.yaw += 0.01
	vs:renderCheckerboard()
end)
Out.check("vs.checkerboard_cheaper", tCb < tFull * 0.7, string.format("%.3f vs %.3f ms", tCb, tFull))
Out.done()
