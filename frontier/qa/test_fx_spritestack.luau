local Out = require("./Out")
local SS = require("../fx/SpriteStack")

local W, H = 320, 180

-- Procedural ground: mottled grass with a dirt road and a few pebbles.
local function hash(x: number, y: number): number
	local h = (x * 374761393 + y * 668265263) % 2147483647
	h = (h * 1274126177) % 2147483647
	return (h % 10007) / 10007
end
local function vnoise(x: number, y: number): number
	local xi, yi = math.floor(x), math.floor(y)
	local fx, fy = x - xi, y - yi
	fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	local a, b = hash(xi, yi), hash(xi + 1, yi)
	local c, d = hash(xi, yi + 1), hash(xi + 1, yi + 1)
	return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
end
local ground = buffer.create(W * H * 4)
for y = 0, H - 1 do
	for x = 0, W - 1 do
		local n = vnoise(x / 18, y / 18) * 0.6 + vnoise(x / 5, y / 5) * 0.3 + hash(x, y) * 0.1
		local r, g, b = 70 + n * 40, 120 + n * 45, 50 + n * 20
		local roadY = 104 + math.sin(x / 45) * 10
		local d = math.abs(y - roadY)
		if d < 14 + vnoise(x / 4, 3) * 2 then
			local m = vnoise(x / 6, y / 6)
			r, g, b = 168 + m * 30, 142 + m * 24, 98 + m * 18
			if d > 12 then
				r, g, b = r * 0.85, g * 0.85, b * 0.85
			end
		elseif hash(x * 3, y * 7) > 0.995 then
			r, g, b = 236, 226, 120 -- flowers
		end
		buffer.writeu32(ground, (y * W + x) * 4, math.floor(r) + math.floor(g) * 256 + math.floor(b) * 65536 + 0xFF000000)
	end
end

local house, car, tree = SS.house(), SS.car(), SS.tree()
local ss = SS.new(W, H, { scale = 2 })
ss:setGround(ground)

local objects: { SS.Object } = {
	{ model = house, x = 40, y = 70, angle = 0.3 },
	{ model = house, x = 110, y = 66, angle = -0.2 },
	{ model = house, x = 185, y = 72, angle = 0.9 },
	{ model = house, x = 262, y = 64, angle = 2.0 },
	{ model = house, x = 70, y = 168, angle = 3.5 },
	{ model = house, x = 230, y = 170, angle = 4.4 },
	{ model = car, x = 60, y = 106, angle = 0.15 },
	{ model = car, x = 150, y = 110, angle = 3.3 },
	{ model = car, x = 214, y = 104, angle = -0.25 },
	{ model = car, x = 290, y = 98, angle = 3.0 },
	{ model = car, x = 150, y = 168, angle = 1.2 },
	{ model = tree, x = 15, y = 36 + 20, angle = 0 },
	{ model = tree, x = 150, y = 48, angle = 1 },
	{ model = tree, x = 225, y = 40, angle = 2 },
	{ model = tree, x = 300, y = 150, angle = 3 },
	{ model = tree, x = 20, y = 150, angle = 4 },
	{ model = tree, x = 120, y = 150, angle = 5 },
	{ model = tree, x = 300, y = 40, angle = 0.5 },
	{ model = tree, x = 190, y = 140, angle = 1.5 },
	{ model = tree, x = 270, y = 140, angle = 2.5 },
}
Out.check("ss.twenty_objects", #objects == 20)
ss:drawScene(objects)
Out.image("ss_scene", W, H, ss.rgba)

-- Shadows exist and darken the ground.
local nShadow = 0
for i = 0, W * H - 1 do
	nShadow += buffer.readu8(ss.shadow, i)
end
Out.check("ss.shadows", nShadow > 2000, `{nShadow} shadow px`)

-- Inverse-rotation map: footprint texels * scale^2 pixels at multiples of 90 degrees (exact
-- permutation under nearest sampling), and close to it at any other angle.
do
	local cols = 0
	for i = 0, 16 * 16 - 1 do
		if buffer.readu8(house.columnTop, i) ~= 0 then
			cols += 1
		end
	end
	local want = cols * 4
	local ok, det = true, {}
	for k = 0, 3 do
		local n = SS.rotationMap(ss, house, k * math.pi / 2)
		ok = ok and n == want
		table.insert(det, tostring(n))
	end
	local nOdd = SS.rotationMap(ss, house, 0.6)
	ok = ok and math.abs(nOdd - want) <= want * 0.04
	Out.check("ss.rotation_map", ok, `want {want}: {table.concat(det, " ")} @0.6rad {nOdd}`)
end

-- Turntable strip: one house at 8 angles, larger scale.
local TH = 76
local tt = SS.new(64 * 8, TH, { scale = 2 })
local spin: { SS.Object } = {}
for k = 0, 7 do
	table.insert(spin, { model = if k % 2 == 0 then house else car, x = 32 + k * 64, y = 62, angle = k * math.pi / 4 })
end
local bg = buffer.create(64 * 8 * TH * 4)
for i = 0, 64 * 8 * TH - 1 do
	buffer.writeu32(bg, i * 4, 0xFF5A7A4A)
end
tt:setGround(bg)
tt:drawScene(spin)
Out.image("ss_turntable", 64 * 8, TH, tt.rgba)

Out.time("ss.scene_20_objects_320x180", 30, function()
	for _, o in objects do
		o.angle += 0.05
	end
	ss:drawScene(objects)
end)
Out.done()
