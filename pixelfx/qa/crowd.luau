-- Headless stress test: 1000 enemies chasing a moving player across a 384×216 view.
local Core = require("../Core")
local Bake = require("../fx/EnemyBake")
local Crowd = require("../fx/Crowd")

-- placeholder 16×16 "bat" PNG: dark purple body, red eyes
local src = Core.canvas(16, 16)
for y = 0, 15 do for x = 0, 15 do
	local dx, dy = (x - 7.5) / 7, (y - 8) / 6
	if dx * dx + dy * dy < 1 or (y < 9 and math.abs(dx) > 0.6 and math.abs(dx) < 1.1 and y > 3) then
		Core.set(src, x, y, 70, 30, 90, 255)
	end
end end
Core.set(src, 5, 7, 230, 40, 40, 255); Core.set(src, 10, 7, 230, 40, 40, 255)

local t0 = os.clock()
local sheet = Bake.bake(src)
print(string.format("bake 8 frames: %.2f ms", (os.clock() - t0) * 1000))

local W, H = 384, 216
local crowd = Crowd.new(1200, W, H)
for cx = 20, 28 do crowd:setSolid(cx, 12, true) end -- a wall to route around
local rand = Core.rng(9)
for _ = 1, 1000 do
	local edge = rand()
	local x = if edge < 0.5 then rand() * W else (if rand() < 0.5 then 0 else W - 1)
	local y = if edge >= 0.5 then rand() * H else (if rand() < 0.5 then 0 else H - 1)
	crowd:spawn(x, y, 1)
end
local c = Core.canvas(W, H)
local simT, renT, frames = 0, 0, 120
for f = 1, frames do
	local px, py = W / 2 + math.cos(f / 40) * 60, H / 2 + math.sin(f / 40) * 30
	local a = os.clock()
	if f % 6 == 1 then crowd:refreshFlow(px, py) end -- the flow field at 10 Hz is plenty
	crowd:step(1 / 60)
	local b = os.clock()
	Core.clear(c, 24, 28, 22, 255)
	crowd:render(c, { sheet })
	renT += os.clock() - b; simT += b - a
	if f == 40 then for i = 0, 99 do crowd:hit(i, 1, 30, 0) end end
end
print(string.format("1000 enemies: sim %.2f ms/frame, render %.2f ms/frame (interpreter)", simT / frames * 1000, renT / frames * 1000))
print("@@crowd " .. #Core.ppm(c)); print(Core.ppm(c))
local strip = Core.canvas(sheet.w * 9, sheet.h)
for i, fr in sheet.frames do for y = 0, fr.h - 1 do for x = 0, fr.w - 1 do
	local px = buffer.readu32(fr.buf, (y * fr.w + x) * 4)
	if px >= 0x80000000 then buffer.writeu32(strip.buf, (y * strip.w + (i - 1) * sheet.w + x) * 4, px) end
end end end
for y = 0, sheet.h - 1 do for x = 0, sheet.w - 1 do
	local px = buffer.readu32(sheet.flash.buf, (y * sheet.w + x) * 4)
	if px >= 0x80000000 then buffer.writeu32(strip.buf, (y * strip.w + 8 * sheet.w + x) * 4, px) end
end end
print("@@bake " .. #Core.ppm(strip)); print(Core.ppm(strip))
