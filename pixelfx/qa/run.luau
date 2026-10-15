-- Headless QA: renders each effect, writes PPM frames and prints timing per frame.
local Core = require("../Core")
local out = {}
local function save(name, c)
	local ok, fs = pcall(require, "@std/fs")
	out[name] = Core.ppm(c)
end
local function time(name, f)
	local t0 = os.clock(); f(); local ms = (os.clock() - t0) * 1000
	print(string.format("%-20s %8.2f ms", name, ms))
end

local W, H = 96, 96
local results = {}

local L = require("../fx/Lichtenberg")
local c = Core.canvas(W, H)
local e = L.new(W, H)
time("Lichtenberg.strike", function() e:strike(48, 2) end)
time("Lichtenberg.frame", function() e:step(1/30); e:render(c) end)
results.lichtenberg = Core.ppm(c)

local P = require("../fx/Physarum")
e = P.new(W, H, { agents = 2000 }); c = Core.canvas(W, H)
for _ = 1, 120 do e:step(1/30) end
time("Physarum.frame", function() e:step(1/30); e:render(c) end)
results.physarum = Core.ppm(c)

local Wv = require("../fx/WaveRing")
e = Wv.new(W, H); c = Core.canvas(W, H)
e:pulse(48, 48, 6); for _ = 1, 25 do e:step(1/30) end; e:pulse(48, 48, 6)
for _ = 1, 15 do e:step(1/30) end
time("WaveRing.frame", function() e:step(1/30); e:render(c) end)
results.wavering = Core.ppm(c)

local F = require("../fx/FrostDLA")
e = F.new(W, H); c = Core.canvas(W, H)
time("FrostDLA.grow(1500)", function() e:grow(1500) end)
for _ = 1, 30 do e:step(1/30) end
e:render(c); results.frost = Core.ppm(c)

local J = require("../fx/JumpFloodOutline")
local mask = buffer.create(W * H)
c = Core.canvas(W, H)
for y = 0, H - 1 do for x = 0, W - 1 do
	local inside = ((x - 48) / 22) ^ 2 + ((y - 50) / 16) ^ 2 < 1 or (math.abs(x - 48) < 4 and y > 20 and y < 40)
	if inside then buffer.writeu8(mask, y * W + x, 1); Core.set(c, x, y, 120, 70, 40, 255) end
end end
time("JumpFlood.build", function() e = J.new(W, H, mask, { width = 1, glow = 7 }) end)
e:render(c); results.outline = Core.ppm(c)

local BN = require("../fx/BlueNoiseDissolve")
local noise
time("BlueNoise(32)", function() noise = BN.blueNoise(32) end)
local spr = Core.canvas(W, H)
for y = 10, 85 do for x = 20, 75 do Core.set(spr, x, y, 70 + x, 40, 140 - y, 255) end end
e = BN.new(spr, noise, 32); e:step(0.22); c = Core.canvas(W, H)
e:render(c); results.dissolve = Core.ppm(c)

local Bl = require("../fx/Bloom")
c = Core.canvas(W, H)
for y = 40, 56 do for x = 30, 66 do Core.set(c, x, y, 255, 230, 120, 255) end end
time("Bloom.apply", function() Bl.apply(c, 150, 3, 1.2) end)
results.bloom = Core.ppm(c)

local PD = require("../fx/PaletteDither")
c = Core.canvas(W, H)
for y = 0, H - 1 do for x = 0, W - 1 do Core.set(c, x, y, x * 255 // W, y * 255 // H, 128, 255) end end
time("PaletteDither.fs", function() PD.apply(c, { {20,12,28}, {68,36,52}, {48,52,109}, {78,74,78}, {133,76,48}, {52,101,36}, {208,70,72}, {117,113,97}, {89,125,206}, {210,125,44}, {133,149,161}, {109,170,44}, {210,170,153}, {109,194,202}, {218,212,94}, {222,238,214} }) end)
results.dither = Core.ppm(c)

local Ph = require("../fx/Phyllotaxis")
e = Ph.new(); e:step(1.2); c = Core.canvas(W, H); e:render(c, 48, 48); results.phyllotaxis = Core.ppm(c)

local O = require("../fx/OrbitTrails")
e = O.new(W, H, { count = 4, radius = 30 }); c = Core.canvas(W, H)
for i = 1, 40 do e:setCentre(48 + math.sin(i / 8) * 6, 48); e:step(1/30) end
time("OrbitTrails.frame", function() e:step(1/30); e:render(c) end)
results.orbit = Core.ppm(c)

local Fb = require("../fx/FabrikChain")
e = Fb.new(24, 4); c = Core.canvas(W, H)
time("Fabrik.solve", function() e:solve(10, 80, 85, 20) end)
e:render(c); results.fabrik = Core.ppm(c)

local CA = require("../fx/CaveCA")
local cells; time("CaveCA.chunk", function() cells = CA.chunk(0, 0, W, H) end)
c = Core.canvas(W, H)
for i = 0, W * H - 1 do if buffer.readu8(cells, i) == 1 then Core.set(c, i % W, i // W, 60, 80, 50, 255) end end
results.cave = Core.ppm(c)

local SR = require("../fx/SlotReel")
local icons = {}
for k = 1, 6 do
	local ic = Core.canvas(24, 24)
	for y = 3, 20 do for x = 3, 20 do Core.set(ic, x, y, (k * 70) % 256, (k * 130) % 256, (k * 40) % 256, 255) end end
	icons[k] = ic
end
e = SR.new(icons, 24, 72); e:land(3)
for _ = 1, 20 do e:step(1/30) end
c = Core.canvas(W, H); e:render(c, 36, 12); results.slotreel = Core.ppm(c)

-- emit as a single stream: name\nlen\nbytes
for name, data in results do print("@@" .. name .. " " .. #data); print(data) end
