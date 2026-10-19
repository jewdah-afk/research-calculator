local Out = require("./Out")
local FS = require("../fx/FallingSand")

local W, H = 320, 180
local world = FS.new(W, H, 777)

-- Level: stone frame, a bowl, two slanted ledges, a wooden hut to burn.
world:rect(0, H - 4, W - 1, H - 1, FS.STONE)
world:rect(0, 0, 2, H - 1, FS.STONE)
world:rect(W - 3, 0, W - 1, H - 1, FS.STONE)
for k = 0, 40 do -- ledge sloping down to the right, under the sand spout
	world:rect(40 + k, 50 + k // 3, 40 + k, 52 + k // 3, FS.STONE)
end
for k = 0, 40 do -- ledge sloping down to the left, under the water spout
	world:rect(230 - k, 60 + k // 3, 230 - k, 62 + k // 3, FS.STONE)
end
world:rect(110, 120, 200, 123, FS.STONE) -- bowl floor
world:rect(110, 96, 113, 123, FS.STONE)
world:rect(197, 96, 200, 123, FS.STONE)
world:rect(250, 140, 290, 143, FS.WOOD) -- hut
world:rect(250, 144, 253, H - 5, FS.WOOD)
world:rect(287, 144, 290, H - 5, FS.WOOD)
world:rect(262, 120, 278, 139, FS.WOOD)

local poured = { [FS.SAND] = 0, [FS.WATER] = 0 }
local seed = 99
local function rand(n: number): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n
end
local function spout(cx: number, mat: number, n: number)
	for _ = 1, n do
		local x, y = cx + rand(7) - 3, 4 + rand(3)
		if world:get(x, y) == FS.EMPTY then
			world:set(x, y, mat)
			poured[mat] += 1
		end
	end
end
local function pourStep(stepNo: number)
	spout(70, FS.SAND, 4)
	spout(150, FS.SAND, 2)
	spout(205, FS.WATER, 5)
	spout(160, FS.WATER, 2)
	if stepNo == 120 then
		world:rect(266, 116, 272, 119, FS.FIRE) -- light the hut roof
	end
	world:step()
end

local frames = buffer.create(W * 2 * H * 4)
local function grab(slot: number)
	local rgba = world:render()
	for y = 0, H - 1 do
		buffer.copy(frames, (y * W * 2 + slot * W) * 4, rgba, y * W * 4, W * 4)
	end
end

local n = 0
local tActive = Out.time("fs.step_active_320x180", 399, function()
	n += 1
	pourStep(n)
	if n == 230 then
		grab(0)
	end
end)
Out.check("fs.mass_sand_pouring", world:count(FS.SAND) == poured[FS.SAND], `{world:count(FS.SAND)} vs poured {poured[FS.SAND]}`)
Out.check("fs.mass_water_pouring", world:count(FS.WATER) == poured[FS.WATER], `{world:count(FS.WATER)} vs poured {poured[FS.WATER]}`)
Out.check("fs.fire_burned_wood", world:count(FS.WOOD) < 41 * 4 + 2 * 4 * 32 + 17 * 20, `{world:count(FS.WOOD)} wood left`)

-- Let everything settle (fire burns out, smoke dissipates, water levels).
local settledAt = -1
for s = 1, 6000 do
	world:step()
	if world:awakeCount() == 0 then
		settledAt = s
		break
	end
end
grab(1)
Out.image("fs_pour_and_settled", W * 2, H, frames)
Out.check("fs.all_chunks_sleep", settledAt > 0, `settled after {settledAt} steps, awake {world:awakeCount()}`)
Out.check("fs.mass_sand_settled", world:count(FS.SAND) == poured[FS.SAND], `{world:count(FS.SAND)} vs {poured[FS.SAND]}`)
Out.check("fs.mass_water_settled", world:count(FS.WATER) == poured[FS.WATER], `{world:count(FS.WATER)} vs {poured[FS.WATER]}`)
Out.check("fs.no_fire_left", world:count(FS.FIRE) == 0 and world:count(FS.SMOKE) == 0)

local tSettled = Out.time("fs.step_settled_320x180", 2000, function()
	world:step()
end)
Out.check("fs.settled_cheaper", tSettled < tActive * 0.02, string.format("%.4f vs %.4f ms", tSettled, tActive))

-- Bias: a symmetric sand pile poured from one point on a flat floor is roughly symmetric.
local sym = FS.new(128, 96, 5)
sym:rect(0, 92, 127, 95, FS.STONE)
for _ = 1, 500 do
	sym:set(64, 2, FS.SAND)
	sym:step()
end
for _ = 1, 400 do
	sym:step()
end
local left, right = 0, 0
for y = 0, 91 do
	for x = 0, 127 do
		if sym:get(x, y) == FS.SAND then
			if x < 64 then left += 1 elseif x > 64 then right += 1 end
		end
	end
end
Out.check("fs.unbiased_pile", math.abs(left - right) < 0.1 * (left + right), `left {left} right {right}`)
Out.done()
