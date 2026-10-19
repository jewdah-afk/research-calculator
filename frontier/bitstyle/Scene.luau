--!native
--!optimize 2
-- "THE REAPER" boss entrance (minute 30) in a clean Bit-Wonder pixel style, rendered into a
-- 480x270 palette-indexed frame (IndexedFrame). Deterministic: draw(t) depends only on t (0..10 s).
--
--   0.0  calm graveyard at night: flickering candles, fireflies, the knight's lantern pool breathing
--   1.2  the void opens in the graveyard (rotating swirl pit, purple glow)
--   1.5  the timer rolls over to a pulsing red 30:00 and a drain wave sweeps out: behind its
--        crackling front the world sinks to its lowest bands (deep navy void stone, candles snuffed
--        one by one, cobbles flipping in with a flash); only the knight's lantern pool keeps colour
--   3.0  the reaper's ghost (same pose, spectral ramp) rises out of the pit through lightning;
--        void tendrils sweep slowly around the graveyard
--   3.5  title card slides in: "THE REAPER" scrambles in, "MINUTE 30" types out in a growing tag
--   5.45 a bolt hits the hood: flash, screen shake, the ghost dissolves into the solid reaper from
--        the hem up behind a burning edge
--   6.2  idle: float bob, hem flutter, sleeve sway, ember eyes pulsing, wisps, a glint along the
--        blade; a faint ring of clock numerals fades in around the bone-white reaper
--   7.1  title card dithers away
--   7.45 attack telegraph: the cone opens and fills outward from the reaper, outline pulsing faster
--        while the reaper winds up (scythe raised back, eyes flaring)
--   8.75 slash: the scythe sweeps through with a smeared arc, impact flash on the cone, screen
--        shake, sparks and dust, the knight flinches; the cone then dithers away
--
-- Static layers (ground material + shade offset for the normal and the corrupted world, and the
-- corruption arrival field) are built once in new(). Each frame: clear and splat a handful of
-- point lights, one ground pass that picks a layer, quantises light with a Bayer threshold and
-- writes a palette index, then sprites, particles and UI on top.

local IndexedFrame = require("../IndexedFrame")
local Palette = require("./Palette")
local Light = require("./Light")
local Font = require("./Font")
local Reaper = require("./Reaper")

local Scene = {}
Scene.__index = Scene

local W, H = 480, 270
local N = W * H
Scene.W = W
Scene.H = H

local C = Palette.C
local BAYER = Palette.BAYER
local OFF0 = 8 -- bias for signed shade offsets stored in u8 layers
local VEIN_FLAG = 16 -- added to a corrupted-layer material on crack pixels

local GRASS, PATH, COBBLE, CSTONE = Palette.GRASS, Palette.PATH, Palette.COBBLE, Palette.CSTONE
local TOMB, LEAF, TRUNK, DEAD = Palette.TOMB, Palette.LEAF, Palette.TRUNK, Palette.DEAD

-- Layout (canvas pixels) ---------------------------------------------------------------------
local GX, GY, GRX, GRY = 318, 176, 90, 52 -- graveyard oval
local PX, PY = 142, 196 -- player feet
local VX, VY = 318, 177 -- void pit centre
local CANDLES = {
	{ 294, 152 }, { 341, 152 }, { 262, 165 }, { 374, 165 },
	{ 262, 186 }, { 374, 186 }, { 294, 199 }, { 341, 199 },
}
local TOMBS = { { 220, 88 }, { 372, 82 }, { 398, 100 }, { 428, 198 }, { 168, 64 } }
local ROCKS = { { 76, 104 }, { 46, 172 }, { 106, 250 }, { 450, 160 }, { 392, 248 }, { 286, 30 }, { 200, 150 } }
local TREES = { { 22, 62 }, { 456, 70 }, { 16, 262 }, { 466, 262 }, { 120, 22 } }
local SHROOMS = { { 36, 82 }, { 92, 122 }, { 470, 98 }, { 444, 236 }, { 184, 238 } }

-- Deterministic hash / noise --------------------------------------------------------------------
local M32 = 4294967296
local function hash(x: number, y: number, s: number): number
	local h = bit32.bxor((x * 73856093) % M32, (y * 19349663) % M32, (s * 83492791) % M32)
	h = (h * 69069 + 12345) % M32
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = (h * 69069 + 1013904223) % M32
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 69069 + 907633385) % M32
	return bit32.bxor(h, bit32.rshift(h, 16)) / M32
end

local function vnoise(x: number, y: number, s: number): number
	local xi, yi = math.floor(x), math.floor(y)
	local fx, fy = x - xi, y - yi
	fx = fx * fx * (3 - 2 * fx)
	fy = fy * fy * (3 - 2 * fy)
	local a, b = hash(xi, yi, s), hash(xi + 1, yi, s)
	local c, d = hash(xi, yi + 1, s), hash(xi + 1, yi + 1, s)
	return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
end

local function fbm(x: number, y: number, s: number): number
	return vnoise(x, y, s) * 0.55 + vnoise(x * 2.03, y * 2.03, s + 1) * 0.3 + vnoise(x * 4.1, y * 4.1, s + 2) * 0.15
end

local function smooth(a: number, b: number, t: number): number
	local u = math.clamp((t - a) / (b - a), 0, 1)
	return u * u * (3 - 2 * u)
end

-- Jittered-grid Voronoi: id of the nearest seed.
local function voronoi(x: number, y: number, s: number, seed: number): (number, number, number)
	local gx, gy = math.floor(x / s), math.floor(y / s)
	local best, bid, bx, by = 1e18, 0, 0, 0
	for oy = -1, 1 do
		for ox = -1, 1 do
			local cx, cy = gx + ox, gy + oy
			local sx = (cx + 0.12 + 0.76 * hash(cx, cy, seed)) * s
			local sy = (cy + 0.12 + 0.76 * hash(cx, cy, seed + 7)) * s
			local d = (x - sx) ^ 2 + (y - sy) ^ 2
			if d < best then
				best, bid, bx, by = d, (cy + 100) * 1000 + (cx + 100), sx, sy
			end
		end
	end
	return bid, bx, by
end

-- Layer helpers ---------------------------------------------------------------------------------
type Layers = { nMat: buffer, nOff: buffer, cMat: buffer, cOff: buffer }

local function inb(x: number, y: number): boolean
	return x >= 0 and y >= 0 and x < W and y < H
end

local function put(L: Layers, x: number, y: number, nm: number, no: number, cm: number, co: number)
	if not inb(x, y) then
		return
	end
	local i = y * W + x
	buffer.writeu8(L.nMat, i, nm)
	buffer.writeu8(L.nOff, i, no + OFF0)
	buffer.writeu8(L.cMat, i, cm)
	buffer.writeu8(L.cOff, i, co + OFF0)
end

-- Add `d` to the shade offset of both layers inside an ellipse; dithered edge.
local function shade(L: Layers, cx: number, cy: number, rx: number, ry: number, d: number)
	for y = math.floor(cy - ry), math.ceil(cy + ry) do
		for x = math.floor(cx - rx), math.ceil(cx + rx) do
			if inb(x, y) then
				local q = ((x + 0.5 - cx) / rx) ^ 2 + ((y + 0.5 - cy) / ry) ^ 2
				if q < 1 and (q < 0.6 or Palette.bayer(x, y) > (q - 0.6) / 0.4) then
					local i = y * W + x
					buffer.writeu8(L.nOff, i, buffer.readu8(L.nOff, i) + d)
					buffer.writeu8(L.cOff, i, buffer.readu8(L.cOff, i) + d)
				end
			end
		end
	end
end

-- Bitmap stamp: map[char] = { normalMat, normalOff, corruptMat, corruptOff }
local function stamp(L: Layers, rows: { string }, x0: number, y0: number, map: { [string]: { number } })
	for r, row in rows do
		for c = 1, #row do
			local e = map[string.sub(row, c, c)]
			if e then
				put(L, x0 + c - 1, y0 + r - 1, e[1], e[2], e[3], e[4])
			end
		end
	end
end

local TOMB_ROWS = {
	"..ooooo..",
	".ohhhhmo.",
	"ohhhchmso",
	"ohhcccmso",
	"ohhhchmso",
	"ohhhchmso",
	"ohmmmmmso",
	"ohmmmmmso",
	"ohmmmmsso",
	"ommmmmsso",
	"ooooooooo",
}
local TOMB_MAP = {
	o = { TOMB, -2, TOMB, -2 },
	h = { TOMB, 1, TOMB, 1 },
	m = { TOMB, 0, TOMB, 0 },
	s = { TOMB, -1, TOMB, -1 },
	c = { TOMB, -2, TOMB, -2 },
}
local ROCK_ROWS = {
	"..oooo..",
	".ohhmmo.",
	"ohhmmmso",
	"ommmmsso",
	".oooooo.",
}

local function buildTree(L: Layers, tx: number, ty: number)
	-- shadow, trunk, canopy (clumps of discs lit from the top-left, outlined in dark leaf green)
	shade(L, tx + 3, ty + 1, 13, 4, -1)
	for y = ty - 10, ty do
		for x = tx - 2, tx + 1 do
			local o = if x == tx - 2 or x == tx + 1 then -2 elseif x == tx - 1 then 1 else 0
			if y == ty then
				o = -2
			end
			put(L, x, y, TRUNK, o, DEAD, o - 1)
		end
	end
	local cx, cy = tx, ty - 21
	local blobs = {
		{ 0, 6, 10 }, { -8, 2, 8 }, { 8, 2, 8 }, { -5, -6, 8 }, { 5, -6, 8 }, { 0, -11, 7 }, { -10, 8, 6 }, { 10, 8, 6 },
	}
	local S = 18
	local owner = table.create((2 * S + 1) * (2 * S + 1), 0)
	local val = table.create((2 * S + 1) * (2 * S + 1), 0)
	for y = -S, S do
		for x = -S, S do
			local best, bi, bv = -1e9, 0, 0
			for k, b in blobs do
				local dx, dy = x + 0.5 - b[1], y + 0.5 - b[2]
				local d = math.sqrt(dx * dx + dy * dy)
				-- lower blobs are in front: bias by y so clumps overlap top-down
				local depth = b[3] - d + b[2] * 0.15
				if d < b[3] and depth > best then
					best, bi = depth, k
					local nx, ny = dx / b[3], dy / b[3]
					local nz = math.sqrt(math.max(0, 1 - nx * nx - ny * ny))
					bv = 0.55 * nz + 0.6 * (-0.55 * nx - 0.8 * ny)
				end
			end
			local k = (y + S) * (2 * S + 1) + (x + S) + 1
			owner[k] = bi
			val[k] = bv
		end
	end
	local function own(x: number, y: number): number
		if x < -S or x > S or y < -S or y > S then
			return 0
		end
		return owner[(y + S) * (2 * S + 1) + (x + S) + 1]
	end
	for y = -S, S do
		for x = -S, S do
			local bi = own(x, y)
			if bi ~= 0 then
				local px, py = cx + x, cy + y
				local o
				if own(x - 1, y) == 0 or own(x + 1, y) == 0 or own(x, y - 1) == 0 or own(x, y + 1) == 0 then
					o = -2
				else
					local v = val[(y + S) * (2 * S + 1) + (x + S) + 1]
					local b = if inb(px, py) then Palette.bayer(px, py) else 0.5
					o = Palette.level(v * 2.2 + 0.25, b) - 1
					o = math.clamp(o, -1, 1)
					-- clump separation: a darker line where a front clump overlaps one behind it
					local ub = own(x, y - 1)
					if ub ~= bi and ub ~= 0 and blobs[ub][2] < blobs[bi][2] then
						o = -1
					end
				end
				put(L, px, py, LEAF, o, DEAD, o)
			end
		end
	end
end


-- Lightning: branching stepped leader (Lichtenberg-like), precomputed as pixel lists.
local function genBolt(seed: number, x0: number, y0: number, x1: number, y1: number): { number }
	local pts = {}
	local st = seed
	local function rnd(): number
		st = (st * 69069 + 12345) % M32
		st = bit32.bxor(st, bit32.rshift(st, 11))
		return st / M32
	end
	for _ = 1, 4 do
		rnd()
	end
	local function walk(x: number, y: number, tx: number, ty: number, kind: number, steps: number)
		local dx, seg = 0, 0
		for s = 1, steps do
			if seg <= 0 then
				seg = 2 + math.floor(rnd() * 6)
				local want = (tx - x) / math.max(6, ty - y)
				local v = want * 1.3 + (rnd() * 2 - 1) * 1.6
				dx = if v > 1.25 then 2 elseif v > 0.4 then 1 elseif v < -1.25 then -2 elseif v < -0.4 then -1 else 0
				if kind < 2 and s > 4 and rnd() < (if kind == 0 then 0.36 else 0.22) then
					local side = if rnd() < 0.5 then -1 else 1
					local len = if kind == 0 then 10 + rnd() * 26 else 5 + rnd() * 10
					walk(x, y, x + side * (14 + rnd() * 26), y + 30, kind + 1, math.floor(len))
				end
			end
			if dx == 2 or dx == -2 then
				x += dx // 2
				table.insert(pts, x)
				table.insert(pts, y)
				table.insert(pts, kind)
				x += dx // 2
			else
				x += dx
			end
			y += 1
			seg -= 1
			table.insert(pts, x)
			table.insert(pts, y)
			table.insert(pts, kind)
			if kind == 0 and y >= ty then
				break
			end
		end
	end
	table.insert(pts, x0)
	table.insert(pts, y0)
	table.insert(pts, 0)
	walk(x0, y0, x1, y1, 0, 400)
	return pts
end

-- Construction ----------------------------------------------------------------------------------

export type Scene = typeof(setmetatable(
	{} :: {
		frame: IndexedFrame.IndexedFrame,
		light: Light.Light,
		nLay: buffer,
		cLay: buffer,
		corr: buffer,
		rp: Reaper.Reaper,
		bolts: { { number } },
		stats: { [string]: number }?,
		ambB: buffer,
		sparkC: { number },
		sparkXY: { number },
		cone: { number },
		card: buffer,
		snuff: { number },
		pitBase: buffer,
		reapBase: buffer,
	},
	Scene
))

-- Drain / corruption front radius (monotonic, eases in, never jumps more than a few px per frame).
local T_DRAIN = 1.5 -- the timer reads 30:00
local T_VOID0, T_VOID1 = 1.2, 2.0
local T_MAT = 5.45 -- bolt hits, ghost starts to solidify
local T_MAT_END = 6.15
local function corruptionRadius(t: number): number
	if t < T_DRAIN then
		return -1000
	end
	-- starts at the field's minimum (~16 px) so the wave bursts out right on the roll-over
	return 14 + 358 * (1 - math.exp(-(t - T_DRAIN) / 2.2)) * (0.45 + 0.55 * smooth(T_DRAIN, T_DRAIN + 0.4, t))
end

-- Attack telegraph geometry: an annular sector from the reaper toward the knight.
local CAX, CAY = 300, 164
local CONE_R0, CONE_R1, CONE_HALF = 24, 136, 0.44
local CONE_DIR = math.atan2(PY - 6 - CAY, PX - CAX)

local TITLE = "THE REAPER"
local SUB = "MINUTE 30"
local T_SCALE = 3
local CARD_W = Font.width(TITLE, T_SCALE) + 22
local CARD_H = 33

function Scene.new(): Scene
	local frame = IndexedFrame.new(W, H)
	Palette.apply(frame)
	local light = Light.new(W, H)
	light:setAmbient(2.0, 1.05)
	-- the player's lantern is static in this shot: bake it into the warm base once (a small extra
	-- light on top makes the pool breathe)
	light:clear()
	light:point(Light.WARM, PX + 0.5, PY - 5, 80, 3.2)
	light:bakeWarm()

	local L: Layers = {
		nMat = buffer.create(N),
		nOff = buffer.create(N),
		cMat = buffer.create(N),
		cOff = buffer.create(N),
	}

	-- 1. Grass (normal) and big cracked void stone (corrupted) --------------------------------
	local big = buffer.create(N * 4)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local id = voronoi(x + 0.5, (y + 0.5) * 1.18, 36, 21)
			buffer.writeu32(big, (y * W + x) * 4, id)
		end
	end
	local function bigId(x: number, y: number): number
		x = math.clamp(x, 0, W - 1)
		y = math.clamp(y, 0, H - 1)
		return buffer.readu32(big, (y * W + x) * 4)
	end
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			-- grass: lighter blotches, a few dark specks
			local n = fbm(x / 20, y / 17, 11)
			local go = 0
			if n > 0.69 then
				go = 1
			elseif hash(x, y, 4) < 0.02 then
				go = -1
			end
			-- void stone
			local id = bigId(x, y)
			local co
			local cm = CSTONE
			if bigId(x + 1, y) ~= id or bigId(x, y + 1) ~= id then
				co = -3
				cm = CSTONE + VEIN_FLAG
			else
				co = if hash(id, 0, 77) < 0.35 then -1 else 0
				if bigId(x - 1, y) ~= id or bigId(x, y - 1) ~= id then
					co += 1
				elseif fbm(x / 11, y / 11, 31) > 0.66 then
					co += 1
				elseif hash(x, y, 9) < 0.018 then
					co = 1
				end
			end
			put(L, x, y, GRASS, go, cm, co)
		end
	end
	-- grass tufts (lighter blade tips over a dark root)
	for cy = 0, H // 7 do
		for cx = 0, W // 8 do
			if hash(cx, cy, 5) < 0.32 then
				local x = cx * 8 + math.floor(hash(cx, cy, 6) * 6)
				local y = cy * 7 + math.floor(hash(cx, cy, 7) * 5)
				if inb(x, y) then
					local i = y * W + x
					local base = buffer.readu8(L.nOff, i) - OFF0
					local tip = base + 1
					local function g(px: number, py: number, o: number)
						if inb(px, py) then
							local j = py * W + px
							buffer.writeu8(L.nOff, j, o + OFF0)
						end
					end
					g(x - 1, y - 1, tip)
					g(x + 1, y - 1, tip)
					g(x, y - 2, tip)
					g(x, y - 1, tip)
					g(x - 1, y, base - 1)
					g(x, y, base - 1)
					g(x + 1, y, base - 1)
				end
			end
		end
	end

	-- 2. Dirt path from the bottom-left into the graveyard --------------------------------------
	local path = { { -14, 254 }, { 40, 241 }, { 100, 227 }, { 160, 214 }, { 212, 204 }, { 250, 196 } }
	for y = 180, H - 1 do
		for x = 0, 262 do
			local best = 1e9
			for k = 1, #path - 1 do
				local a, b = path[k], path[k + 1]
				local vx, vy = b[1] - a[1], b[2] - a[2]
				local u = math.clamp(((x - a[1]) * vx + (y - a[2]) * vy) / (vx * vx + vy * vy), 0, 1)
				local d = (a[1] + vx * u - x) ^ 2 + (a[2] + vy * u - y) ^ 2
				if d < best then
					best = d
				end
			end
			local d = math.sqrt(best)
			local hw = 5.2 + (fbm(x / 9, y / 9, 51) - 0.5) * 2.4
			if d < hw then
				local o = 0
				if d > hw - 1.1 then
					o = -1
				elseif hash(x, y, 52) < 0.06 then
					o = 1
				elseif hash(x, y, 53) < 0.05 then
					o = -1
				end
				local i = y * W + x
				buffer.writeu8(L.nMat, i, PATH)
				buffer.writeu8(L.nOff, i, o + OFF0)
			end
		end
	end

	-- 3. Graveyard: oval of Voronoi cobbles with mortar, top-left bevel, dark outer edge -----------
	local cob = buffer.create(N * 4)
	for y = GY - GRY - 12, GY + GRY + 12 do
		for x = GX - GRX - 14, GX + GRX + 14 do
			if inb(x, y) then
				local id, sx, sy = voronoi(x + 0.5, (y + 0.5) * 1.32, 8.5, 41)
				sy /= 1.32
				local q = ((sx - GX) / GRX) ^ 2 + ((sy - GY) / GRY) ^ 2
				if q < 1 then
					buffer.writeu32(cob, (y * W + x) * 4, id)
				end
			end
		end
	end
	local function cobId(x: number, y: number): number
		if not inb(x, y) then
			return 0
		end
		return buffer.readu32(cob, (y * W + x) * 4)
	end
	for y = GY - GRY - 12, GY + GRY + 12 do
		for x = GX - GRX - 14, GX + GRX + 14 do
			local id = cobId(x, y)
			if id ~= 0 then
				local o
				if cobId(x - 1, y) == 0 or cobId(x + 1, y) == 0 or cobId(x, y - 1) == 0 or cobId(x, y + 1) == 0 then
					o = -3
				elseif cobId(x + 1, y) ~= id or cobId(x, y + 1) ~= id then
					o = -3
				elseif cobId(x - 1, y) ~= id or cobId(x, y - 1) ~= id then
					o = 1
				elseif cobId(x + 2, y + 1) ~= id or cobId(x + 1, y + 2) ~= id then
					o = -1
				else
					local hsh = hash(id, 1, 91)
					o = if hsh < 0.25 then -1 elseif hsh > 0.85 then 1 else 0
				end
				put(L, x, y, COBBLE, o, if o == -3 then CSTONE + VEIN_FLAG else CSTONE, o)
			elseif cobId(x, y - 1) ~= 0 or cobId(x, y - 2) ~= 0 then
				-- soft drop shadow of the raised paving onto the grass below it
				local i = y * W + x
				buffer.writeu8(L.nOff, i, buffer.readu8(L.nOff, i) - 1)
			end
		end
	end

	-- 4. Props: rocks, tombstones, trees (each with a dithered contact shadow) --------------------
	for _, r in ROCKS do
		shade(L, r[1] + 5, r[2] + 5, 6, 2, -1)
		stamp(L, ROCK_ROWS, r[1], r[2], TOMB_MAP)
	end
	for _, tpos in TOMBS do
		shade(L, tpos[1] + 6, tpos[2] + 11, 7, 2.5, -1)
		stamp(L, TOMB_ROWS, tpos[1], tpos[2], TOMB_MAP)
	end
	for _, tr in TREES do
		buildTree(L, tr[1], tr[2])
	end

	-- 5. Corruption arrival field: distance from the graveyard, warped by noise, held back by the
	--    player's lantern so the lit pool stays grass.
	local corr = buffer.create(N * 4)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local dx, dy = x + 0.5 - GX, (y + 0.5 - GY) * 1.22
			local d = math.sqrt(dx * dx + dy * dy)
			d += 52 * (fbm(x / 46, y / 46, 61) - 0.5) + 12 * (fbm(x / 13, y / 13, 62) - 0.5)
			local pd = math.sqrt((x + 0.5 - PX) ^ 2 + ((y + 0.5 - PY + 6) * 1.1) ^ 2)
			d += math.max(0, 112 - pd) * 1.9 + math.max(0, 74 - pd) * 3.2
			buffer.writef32(corr, (y * W + x) * 4, math.max(0, d))
		end
	end
	-- Cobbles convert whole: each paving stone takes the mean arrival of its pixels, so stones flip
	-- in one at a time (with a highlight) instead of being cut by the front.
	do
		local sum, cnt = {}, {}
		for y = GY - GRY - 12, GY + GRY + 12 do
			for x = GX - GRX - 14, GX + GRX + 14 do
				local id = cobId(x, y)
				if id ~= 0 then
					sum[id] = (sum[id] or 0) + buffer.readf32(corr, (y * W + x) * 4)
					cnt[id] = (cnt[id] or 0) + 1
				end
			end
		end
		for y = GY - GRY - 12, GY + GRY + 12 do
			for x = GX - GRX - 14, GX + GRX + 14 do
				local id = cobId(x, y)
				if id ~= 0 then
					buffer.writef32(corr, (y * W + x) * 4, sum[id] / cnt[id] + 2.5 * (hash(id, 5, 93) - 0.5))
				end
			end
		end
	end
	-- Sample points for the crackling frontier, sorted by arrival so a frame can binary-search the
	-- ones sitting on the front.
	local samples = {}
	for y = 2, H - 3 do
		for x = 1, W - 2 do
			if hash(x, y, 404) < 0.05 then
				table.insert(samples, { buffer.readf32(corr, (y * W + x) * 4), x, y })
			end
		end
	end
	table.sort(samples, function(a, b)
		return a[1] < b[1]
	end)
	local sparkC, sparkXY = table.create(#samples, 0), table.create(#samples * 2, 0)
	for i, s in samples do
		sparkC[i] = s[1]
		sparkXY[i * 2 - 1] = s[2]
		sparkXY[i * 2] = s[3]
	end

	-- Pack each world's layer as one byte: material (+8 for a crack) in the high nibble, shade
	-- offset + OFF0 in the low nibble.
	local nLay, cLay = buffer.create(N), buffer.create(N)
	for i = 0, N - 1 do
		local nm, cm = buffer.readu8(L.nMat, i), buffer.readu8(L.cMat, i)
		local no = math.clamp(buffer.readu8(L.nOff, i), 0, 15)
		local co = math.clamp(buffer.readu8(L.cOff, i), 0, 15)
		if cm >= VEIN_FLAG then
			cm = cm - VEIN_FLAG + 8
		end
		buffer.writeu8(nLay, i, nm * 16 + no)
		buffer.writeu8(cLay, i, cm * 16 + co)
	end

	-- Fold the ordered dither into the ambient: level = floor(L) + (sharpen(frac(L)) > b) is the
	-- same as floor(L + 1 - tb) with tb = (b - 0.5) / SHARP + 0.5.
	local ambB = buffer.create(N * 4)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local o = (y * W + x) * 4
			local tb = (Palette.bayer(x, y) - 0.5) / Palette.SHARP + 0.5
			buffer.writef32(ambB, o, buffer.readf32(light.ambient, o) + 1 - tb)
		end
	end

	-- Cone pixels in polar form: x, y, radius, angle off the axis.
	local cone = {}
	for y = math.max(0, CAY - CONE_R1 - 1), math.min(H - 1, CAY + CONE_R1 + 1) do
		for x = math.max(0, CAX - CONE_R1 - 1), math.min(W - 1, CAX) do
			local dx, dy = x + 0.5 - CAX, y + 0.5 - CAY
			local r = math.sqrt(dx * dx + dy * dy)
			if r >= CONE_R0 and r <= CONE_R1 + 0.5 then
				local da = math.atan2(dy, dx) - CONE_DIR
				if da > math.pi then
					da -= 2 * math.pi
				elseif da < -math.pi then
					da += 2 * math.pi
				end
				if math.abs(da) <= CONE_HALF then
					table.insert(cone, x)
					table.insert(cone, y)
					table.insert(cone, r)
					table.insert(cone, da)
				end
			end
		end
	end

	-- when the drain front reaches each candle
	local snuff = {}
	for i, c in CANDLES do
		local e = buffer.readf32(corr, (c[2] * W + c[1]) * 4)
		local ts = 99
		for k = 0, 1000 do
			local tt = T_DRAIN + k * 0.005
			if corruptionRadius(tt) > e then
				ts = tt
				break
			end
		end
		snuff[i] = ts
	end
	-- the pit's glow (and later the reaper's) are fixed once fully open: bake them
	light:clear()
	light:point(Light.VOID, VX, VY, 120, 1.7, 0.72)
	local pitBase = light:snapshot(Light.VOID)
	light:point(Light.VOID, VX, VY - 40, 96, 0.8)
	local reapBase = light:snapshot(Light.VOID)
	light:clear()

	local rp = Reaper.new()
	-- the ghost's halo follows the idle silhouette
	rp:compose(0, { arm = 0.78, scythe = 18, glint = -1, eye = 0.5, hem = 0, sway = 0 })
	rp:buildHalo()

	local bolts = {
		genBolt(11, 430, -2, 396, 40),
		genBolt(23, 372, -2, 324, 104),
		genBolt(37, 262, -2, 310, 110),
		genBolt(41, 392, -2, 336, 138),
		genBolt(59, 410, -2, 354, 128),
		genBolt(23, 350, -2, 311, 70), -- onto the hood: the materialisation strike
	}

	return setmetatable({
		frame = frame,
		light = light,
		nLay = nLay,
		cLay = cLay,
		corr = corr,
		rp = rp,
		bolts = bolts,
		stats = nil,
		ambB = ambB,
		sparkC = sparkC,
		sparkXY = sparkXY,
		cone = cone,
		card = buffer.create(CARD_W * CARD_H),
		snuff = snuff,
		pitBase = pitBase,
		reapBase = reapBase,
	}, Scene)
end

-- Timeline ---------------------------------------------------------------------------------------
local T_TEL = 7.45 -- telegraph opens
local T_WIND0, T_WIND1 = 7.75, 8.5
local T_SLASH = 8.75
local T_HIT = 8.87
local T_TITLE_OUT = 7.1

local STRIKES = { -- time, bolt, flash strength
	{ 2.42, 1, 0.7 },
	{ 3.3, 2, 1.6 },
	{ 3.88, 3, 1.9 },
	{ 4.75, 4, 1.4 },
	{ T_MAT, 6, 2.2 },
	{ 6.6, 5, 1.2 },
}

local function easeOut(u: number): number
	u = math.clamp(u, 0, 1)
	return 1 - (1 - u) * (1 - u) * (1 - u)
end
local function easeIn(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * u
end
local function lerp(a: number, b: number, u: number): number
	return a + (b - a) * u
end

-- Reaper pose for time t (idle sway, wind-up, slash, recovery).
local IDLE_ARM, WIND_ARM, SLASH_ARM = 0.78, -0.42, 2.25
local IDLE_SCY, WIND_SCY, SLASH_SCY = 18, 78, -128
local function scytheAt(t: number): (number, number)
	local arm = IDLE_ARM + 0.06 * math.sin(t * 1.7)
	local scy = IDLE_SCY + 3 * math.sin(t * 1.7 + 0.5)
	if t >= T_WIND0 then
		local w = smooth(T_WIND0, T_WIND1, t)
		arm = lerp(arm, WIND_ARM, w)
		scy = lerp(scy, WIND_SCY, w)
		if t >= T_WIND1 and t < T_SLASH then
			-- coiled: a tiny tremble before the release
			scy += if math.floor(t * 30) % 2 == 0 then 1.5 else -1.5
		end
	end
	if t >= T_SLASH then
		local s = (t - T_SLASH) / (T_HIT - T_SLASH)
		local e = if s < 1 then easeIn(s) * 0.35 + s * 0.65 else 1
		arm = lerp(WIND_ARM, SLASH_ARM, e)
		scy = lerp(WIND_SCY, SLASH_SCY, e)
		-- follow-through settles a little past the hit, then eases back to idle
		local rec = smooth(9.25, 9.95, t)
		local idleArm = IDLE_ARM + 0.06 * math.sin(t * 1.7)
		local idleScy = IDLE_SCY + 3 * math.sin(t * 1.7 + 0.5)
		arm = lerp(arm, idleArm, rec)
		scy = lerp(scy, idleScy, rec)
	end
	return arm, scy
end

local GLINTS = { 6.55, 8.42, 9.98 }
local function glintAt(t: number): number
	for _, g in GLINTS do
		local u = (t - g) / 0.42
		if u >= 0 and u <= 1 then
			return u
		end
	end
	return -1
end

local function poseAt(t: number): Reaper.Pose
	local arm, scy = scytheAt(t)
	local smearFrom: number? = nil
	if t >= T_SLASH and t < T_HIT + 0.16 then
		local _, back = scytheAt(math.max(T_SLASH, t - 0.075))
		if t > T_HIT then
			-- the trail catches up with the blade once it stops
			back = lerp(back, scy, smooth(T_HIT, T_HIT + 0.16, t))
		end
		if math.abs(back - scy) > 4 then
			smearFrom = back
		end
	end
	local eye = 0.45 + 0.35 * math.sin(t * 3.4)
	if t >= T_WIND0 then
		eye = lerp(eye, 1.4, smooth(T_WIND0, T_WIND1, t) * (1 - smooth(T_HIT + 0.2, 9.8, t)))
	end
	if t >= T_MAT and t < T_MAT + 0.5 then
		eye = 1.5 -- eyes snap open as it solidifies
	end
	return {
		arm = arm,
		scythe = scy,
		glint = glintAt(t),
		smearFrom = smearFrom,
		eye = eye,
		hem = t * 7.5,
		sway = math.floor(math.sin(t * 1.3) * 0.9 + 0.5),
	}
end

-- Pixel helpers on the index buffer ---------------------------------------------------------------
local function px(idx: buffer, x: number, y: number, c: number)
	if x >= 0 and y >= 0 and x < W and y < H then
		buffer.writeu8(idx, y * W + x, c)
	end
end

local function rect(idx: buffer, x: number, y: number, w: number, h: number, c: number)
	local x0, y0 = math.max(0, x), math.max(0, y)
	local x1, y1 = math.min(W, x + w) - 1, math.min(H, y + h) - 1
	for yy = y0, y1 do
		if x1 >= x0 then
			buffer.fill(idx, yy * W + x0, c, x1 - x0 + 1)
		end
	end
end

-- Darken lit ground pixels `steps` ramp levels inside an ellipse (dithered rim).
local function darken(idx: buffer, cx: number, cy: number, rx: number, ry: number, steps: number?)
	local st = steps or 1
	for y = math.floor(cy - ry), math.ceil(cy + ry) do
		for x = math.floor(cx - rx), math.ceil(cx + rx) do
			if inb(x, y) then
				local q = ((x + 0.5 - cx) / rx) ^ 2 + ((y + 0.5 - cy) / ry) ^ 2
				if q < 1 and (q < 0.55 or BAYER[(y % 4) * 4 + x % 4 + 1] > (q - 0.55) / 0.45) then
					local i = y * W + x
					local v = buffer.readu8(idx, i)
					if v < 192 then
						local lv = v % 6
						buffer.writeu8(idx, i, v - math.min(lv, st))
					end
				end
			end
		end
	end
end

-- Ground pass -------------------------------------------------------------------------------------
local GLOW = 20 -- width of the purple glow band ahead of the frontier
local GLOW_AMP = 2.0
local CREEP = 9 -- width of the dithered spore band
local VEIN = 46 -- how far behind the frontier the cracks still glow

local function ground(self: Scene, R: number, flash: number, fresh: number, crackle: number, lift: number)
	local idx: buffer = self.frame.idx
	local nLay, cLay = self.nLay, self.cLay
	local corr: buffer = self.corr
	local ambB: buffer = self.ambB
	local lw, lc, lp = self.light.warm, self.light.cold, self.light.void
	local RIM, RIM_HI, VOID1, VOID0 = C.RIM, C.RIM_HI, C.VOID1, C.VOID0
	local hasCold = self.light.coldUsed
	local liftTint = if lift > 0 then 12 else 0
	for y = 0, H - 1 do
		local brow = bit32.band(y, 3) * 4 + 1
		local row = y * W
		for x = 0, W - 1 do
			local i = row + x
			local o = i * 4
			local e = buffer.readf32(corr, o) - R
			local p = buffer.readf32(lp, o)
			if e < 0 then
				-- Drained world ------------------------------------------------------------------
				if e > -1.5 then
					-- the drain crest crackles: a crawling broken line
					buffer.writeu8(idx, i, if bit32.band(x + y * 3 + crackle, 7) < 2 then RIM else RIM_HI)
					continue
				end
				local lay = buffer.readu8(cLay, i)
				if lay >= 128 then
					lay -= 128
					-- cracks flare just behind the crest, then sink as the stone goes dark
					if e > -VEIN then
						buffer.writeu8(idx, i, if e > -VEIN * 0.2 then RIM elseif e > -VEIN * 0.55 then VOID1 else VOID0)
						continue
					end
				end
				local boost = 0
				if e > -14 then
					p += 1.5 * (1 + e / 14)
				end
				if e > -fresh then
					boost = 2 -- just converted: flips in bright for a frame or two
				end
				-- The drain holds light down to one level. Ambient + dither is always >= 1 level, so the
				-- capped level is exactly 1 (+ a flat lightning strobe); the stone keeps its own shade
				-- offsets, and only the void channel tints it. No other light reads needed.
				local lv = 1 + lift + bit32.band(lay, 15) - OFF0 + boost
				if lv < 0 then
					lv = 0
				elseif lv > 5 then
					lv = 5
				end
				local tint = liftTint
				if tint == 0 and p >= 0.3 and (p >= 0.9 or p >= 0.3 + BAYER[brow + bit32.band(x, 3)] * 0.6) then
					tint = 18
				end
				buffer.writeu8(idx, i, bit32.rshift(lay, 4) * 24 + tint + lv)
				continue
			end
			-- Living world ----------------------------------------------------------------------
			local lay = buffer.readu8(nLay, i)
			if e < GLOW then
				p += GLOW_AMP * (1 - e / GLOW)
				if e < CREEP then
					-- creeping spores: ordered-dither density falloff ahead of the rim
					local k = 1 - e / CREEP
					if k * k > BAYER[brow + bit32.band(x, 3)] then
						buffer.writeu8(idx, i, RIM)
						continue
					end
				end
			end
			local w = buffer.readf32(lw, o)
			local c = flash
			if hasCold then
				c += buffer.readf32(lc, o)
			end
			-- ambB already holds ambient + the per-pixel Bayer bias, so the dithered, band-sharpened
			-- quantisation is a single floor
			local lvl = math.floor(buffer.readf32(ambB, o) + w + c + p) + bit32.band(lay, 15) - OFF0
			if lvl < 0 then
				lvl = 0
			elseif lvl > 5 then
				lvl = 5
			end
			local tint, m = 1, w
			if c > m then
				tint, m = 2, c
			end
			if p > m then
				tint, m = 3, p
			end
			-- tint edge is dithered too (only pixels in the 0.3..0.9 band need the threshold)
			if m < 0.9 and (m < 0.3 or m < 0.3 + BAYER[brow + bit32.band(x, 3)] * 0.6) then
				tint = 0
			end
			buffer.writeu8(idx, i, bit32.rshift(lay, 4) * 24 + tint * 6 + lvl)
		end
	end
end

-- Overlays ----------------------------------------------------------------------------------------

-- Two void tendrils spiralling round the graveyard, slowly rotating and pulsing; they only exist
-- on corrupted stone (sink it to its darkest shades, with a violet lip on the outer side).
local function drawTendrils(idx: buffer, t: number, k: number)
	if k <= 0 then
		return
	end
	local rot = t * 0.16
	for arm = 0, 1 do
		for s = 0, 300 do
			local u = s / 300
			local th = arm * math.pi + 0.6 + u * 3.6 + rot
			local r = 92 + 60 * u
			local x = GX + math.cos(th) * r * 1.25
			local y = GY + math.sin(th) * r * 0.78
			local pulse = 0.75 + 0.25 * math.sin(t * 3.1 - u * 14 + arm * 2)
			local rad = 2.3 * math.sin(math.pi * u) ^ 0.6 * pulse * k
			if rad > 0.6 then
				local r2 = rad * rad
				local ri2 = (rad - 0.9) * (rad - 0.9)
				for py = math.floor(y - rad), math.ceil(y + rad) do
					for pxx = math.floor(x - rad), math.ceil(x + rad) do
						if pxx >= 0 and py >= 0 and pxx < W and py < H then
							local d2 = (pxx + 0.5 - x) ^ 2 + (py + 0.5 - y) ^ 2
							if d2 < r2 then
								local i = py * W + pxx
								local v = buffer.readu8(idx, i)
								if v < 192 and v // 24 == CSTONE then
									local base = v - v % 6
									if d2 < ri2 then
										buffer.writeu8(idx, i, base)
									else
										buffer.writeu8(idx, i, base + math.min(v % 6, 1))
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

local function drawVoid(idx: buffer, t: number, k: number)
	if k <= 0.02 then
		return
	end
	local rx, ry = 27 * k, 11.5 * k
	local function q(x: number, y: number): number
		return ((x + 0.5 - VX) / rx) ^ 2 + ((y + 0.5 - VY) / ry) ^ 2
	end
	local spin = t * 0.9
	for y = math.floor(VY - ry - 1), math.ceil(VY + ry + 1) do
		for x = math.floor(VX - rx - 1), math.ceil(VX + rx + 1) do
			local qq = q(x, y)
			if qq < 1 then
				local col
				if q(x - 1, y) >= 1 or q(x + 1, y) >= 1 or q(x, y - 1) >= 1 or q(x, y + 1) >= 1 then
					-- lip: lit front edge with a sparkle running round it
					local a = math.atan2((y + 0.5 - VY) / ry, (x + 0.5 - VX) / rx)
					local run = (a / (2 * math.pi) * 3 - t * 1.4) % 1
					col = if y + 0.5 > VY then (if run < 0.08 then C.SPARK else C.RIM_HI) else C.RIM
				elseif y + 0.5 < VY and qq > 0.55 then
					col = C.VOID1 -- far inner wall
				else
					local dx, dy = (x + 0.5 - VX) / rx, (y + 0.5 - VY) / ry
					local a = math.atan2(dy, dx) / (2 * math.pi)
					local v = (a * 2 + math.sqrt(qq) * 1.5 - spin) % 1
					col = if v < 0.12 then C.RIM elseif v < 0.3 then C.VOID1 else C.VOID0
					if qq < 0.06 then
						col = C.VOID0
					end
				end
				px(idx, x, y, col)
			end
		end
	end
end

-- Candle with a 3-frame flame cycle (tall / lean left / short lean right).
local FLAMES = {
	{ { 0, -3, "LO" }, { 0, -2, "F" }, { 0, -1, "HI" }, { -1, 0, "LO" }, { 0, 0, "HI" }, { 1, 0, "LO" } },
	{ { -1, -3, "LO" }, { -1, -2, "F" }, { 0, -2, "LO" }, { 0, -1, "HI" }, { -1, 0, "LO" }, { 0, 0, "HI" }, { 1, 0, "LO" } },
	{ { 1, -2, "LO" }, { 0, -2, "F" }, { 0, -1, "HI" }, { -1, 0, "LO" }, { 0, 0, "HI" }, { 1, 0, "F" } },
}
local FLAME_C = { LO = C.FLAME_LO, F = C.FLAME, HI = C.FLAME_HI }
local function flameFrame(t: number, i: number): number
	return (math.floor(t * 11) + i * 7 + math.floor(hash(i, math.floor(t * 3), 17) * 2)) % 3
end

local function drawCandle(idx: buffer, x: number, y: number, t: number, i: number, snuff: number)
	local h = 5 + (i % 3)
	for yy = y - h, y - 1 do
		px(idx, x - 1, yy, C.WAX)
		px(idx, x, yy, C.WAX)
		px(idx, x + 1, yy, C.WAX_SH)
	end
	px(idx, x - 2, y, C.WAX_OUT)
	px(idx, x - 1, y, C.WAX_SH)
	px(idx, x, y, C.WAX_SH)
	px(idx, x + 1, y, C.WAX_OUT)
	px(idx, x + 2, y, C.WAX_OUT)
	px(idx, x + 1, y - h, C.WAX) -- melted lip
	px(idx, x, y - h - 1, C.WAX_OUT) -- wick
	local top = y - h - 2
	local ds = t - snuff
	if ds < -0.15 then
		for _, p in FLAMES[flameFrame(t, i) + 1] do
			px(idx, x + p[1], top + p[2], FLAME_C[p[3]])
		end
	elseif ds < 0 then
		-- guttering: a short, dim flame
		px(idx, x, top, C.FLAME_LO)
		px(idx, x, top - 1, if math.floor(t * 20) % 2 == 0 then C.FLAME else C.FLAME_LO)
	else
		-- snuffed by the drain: an ember on the wick and a thread of smoke curling up
		if ds < 0.4 then
			px(idx, x, top + 1, C.FLAME_LO)
		end
		if ds < 1.1 then
			for k = 0, 4 do
				local sy = top - k - math.floor(ds * 10)
				local sx = x + math.floor(math.sin(ds * 6 + k * 0.9) * 1.4 + 0.5)
				local a = 1 - ds / 1.1 - k * 0.12
				if a > BAYER[(sy % 4) * 4 + sx % 4 + 1] then
					px(idx, sx, sy, if k < 2 then C.TEXT_DIM else C.BOX_EDGE)
				end
			end
		end
	end
end

local KNIGHT = {
	{
		".....ooooo......",
		"....oHHHHWo.....",
		"...oHHHHHHWo....",
		"...oHHHHHHWo....",
		"...oHVVVVVWo....",
		"...oHHHVHHWo....",
		"....oHHVHWo.....",
		"...coooooooo....",
		"..cbboHHHWobo...",
		"..cbboHHHWobbo..",
		"..cbHHHHHHWboWo.",
		"..cbWHHHHWWbo.o.",
		"..ccoWWWWWWoooLo",
		"...cooWWoWWo.oLo",
		".....oWWoWWo..o.",
		".....ooo.ooo....",
	},
	{ -- second idle frame: breath in, cape swings, lantern sways
		".....ooooo......",
		"....oHHHHWo.....",
		"...oHHHHHHWo....",
		"...oHHHHHHWo....",
		"...oHVVVVVWo....",
		"...oHHHVHHWo....",
		"....oHHVHWo.....",
		"...coooooooo....",
		"..cbboHHHWobo...",
		"..cbboHHHWobbo..",
		".cbbHHHHHHWboWo.",
		".ccbWHHHHWWbo..o",
		"..ccoWWWWWWooooL",
		"...cooWWoWWo..oL",
		".....oWWoWWo...o",
		".....ooo.ooo....",
	},
}
local KNIGHT_MAP = {
	o = C.KNIGHT_OUT, H = C.KNIGHT_HI, W = C.KNIGHT, V = C.VISOR,
	b = C.CAPE, c = C.CAPE_SH, L = C.LANTERN,
}
local KNIGHT_HIT = {
	o = C.KNIGHT_OUT, H = C.WHITE, W = C.WHITE, V = C.KNIGHT,
	b = C.WHITE, c = C.KNIGHT_HI, L = C.WHITE, -- hit flash: white, never red (red = danger)
}

local function drawSprite(idx: buffer, rows: { string }, map: { [string]: number }, x0: number, y0: number)
	for r, row in rows do
		for c = 1, #row do
			local col = map[string.sub(row, c, c)]
			if col then
				px(idx, x0 + c - 1, y0 + r - 1, col)
			end
		end
	end
end

local function drawPlayer(idx: buffer, t: number)
	darken(idx, PX + 0.5, PY + 0.5, 7, 2.5)
	local fr = math.floor(t * 2.5) % 2
	local bob = if fr == 0 then 0 else -1
	local dx = 0
	local map = KNIGHT_MAP
	local dh = t - (T_HIT + 0.05)
	if dh >= 0 and dh < 0.5 then
		-- flinch from the shockwave: knocked back two pixels, one white hit frame, then recovers
		dx = if dh < 0.12 then -2 elseif dh < 0.3 then -1 else 0
		bob = 0
		if dh < 0.07 then
			map = KNIGHT_HIT
		end
	end
	local x0, y0 = PX - 7 + dx, PY - 15 + bob
	drawSprite(idx, KNIGHT[fr + 1], map, x0, y0)
	-- lantern glint flickers
	if hash(3, math.floor(t * 8), 29) > 0.5 then
		px(idx, x0 + 14 + fr, y0 + 12, C.FLAME_HI)
	end
end

-- Ambient life: fireflies over the grass that turn into void motes once the stone has taken over.
local function drawMotes(idx: buffer, t: number)
	for m = 1, 34 do
		local bx = hash(m, 11, 72) * W
		local sp = 3 + 6 * hash(m, 12, 72)
		local y = math.floor((hash(m, 13, 72) * (H + 20) - t * sp) % (H + 20) - 10)
		local x = math.floor(bx + math.sin(t * (0.6 + hash(m, 14, 72)) + m) * 7 + 0.5)
		if x >= 0 and y >= 0 and x < W and y < H then
			local v = buffer.readu8(idx, y * W + x)
			local blink = math.sin(t * (2 + hash(m, 15, 72) * 2) + m * 1.7)
			if v < 192 and v // 24 == CSTONE then
				local col = if blink > 0.6 then C.RIM_HI elseif blink > -0.3 then C.RIM else C.VOID1
				px(idx, x, y, col)
				if blink > 0.85 then
					px(idx, x, y + 1, C.RIM)
				end
			elseif v < 192 and blink > -0.1 then
				px(idx, x, y, if blink > 0.7 then C.FLAME_HI else C.SHROOM)
			end
		end
	end
end

-- Void motes drifting up out of the pit.
local function drawPitMotes(idx: buffer, t: number, k: number)
	if k <= 0 then
		return
	end
	for m = 1, 30 do
		local speed = 0.18 + 0.2 * hash(m, 1, 71)
		local ph = (t * speed + hash(m, 2, 71)) % 1
		if hash(m, 3, 71) < k then
			local bx = VX + (hash(m, 4, 71) - 0.5) * 56
			local x = math.floor(bx + math.sin(t * 2 + m) * 2.5 * ph + 0.5)
			local y = math.floor(VY - 2 - ph * 96 + 0.5)
			local col = if ph < 0.35 then C.RIM_HI elseif ph < 0.7 then C.RIM else C.VOID1
			px(idx, x, y, col)
			if ph < 0.2 then
				px(idx, x, y + 1, C.RIM)
			end
		end
	end
end

-- Wisps peeling off the tattered hem and curling upward.
local function drawWisps(idx: buffer, t: number, k: number, x0: number, y0: number, ghost: boolean)
	if k <= 0 then
		return
	end
	for m = 1, 18 do
		local life = 0.9 + 0.6 * hash(m, 1, 73)
		local ph = (t / life + hash(m, 2, 73)) % 1
		local cyc = math.floor(t / life + hash(m, 2, 73))
		local hx = (hash(m, cyc, 74) - 0.5) * 54
		local side = if hx < 0 then -1 else 1
		local x = math.floor(x0 + hx + side * ph * ph * 10 + math.sin(ph * 6 + m) * 1.5 + 0.5)
		local y = math.floor(y0 - 2 - ph * 26 + 0.5)
		if hash(m, cyc, 75) < k and ph > 0.05 then
			local col
			if ghost then
				col = if ph < 0.5 then C.GHOST2 else C.GHOST1
			else
				col = if ph < 0.3 then C.CLOAK3 elseif ph < 0.65 then C.CLOAK2 else C.CLOAK1
			end
			if ph < 0.75 or BAYER[(y % 4) * 4 + x % 4 + 1] > (ph - 0.75) * 4 then
				px(idx, x, y, col)
				if ph < 0.4 then
					px(idx, x - side, y + 1, if ghost then C.GHOST1 else C.CLOAK2)
				end
			end
		end
	end
end

-- Sparks dancing on the corruption front (sample points whose arrival is within a few px of R).
local function drawFrontSparks(self: Scene, idx: buffer, t: number, R: number)
	if R < 4 then
		return
	end
	local sc, sxy = self.sparkC, self.sparkXY
	-- lower bound for R - 3
	local lo, hi = 1, #sc + 1
	while lo < hi do
		local mid = (lo + hi) // 2
		if sc[mid] < R - 3 then
			lo = mid + 1
		else
			hi = mid
		end
	end
	local fr = math.floor(t * 15)
	local i = lo
	while i <= #sc and sc[i] < R + 2.5 do
		if hash(i, fr, 405) < 0.22 then
			local x, y = sxy[i * 2 - 1], sxy[i * 2]
			local rise = math.floor(hash(i, fr, 406) * 4)
			local col = if hash(i, fr, 407) < 0.3 then C.RIM_HI else C.RIM
			px(idx, x, y - rise, col)
			if rise > 1 then
				px(idx, x, y - rise + 1, C.RIM)
			end
		end
		i += 1
	end
end

local function drawBolt(idx: buffer, pts: { number })
	for k = 1, #pts, 3 do
		local x, y, kind = pts[k], pts[k + 1], pts[k + 2]
		if kind == 0 then
			px(idx, x - 1, y, C.BOLT0)
			px(idx, x + 1, y, C.BOLT1)
		end
	end
	for k = 1, #pts, 3 do
		local x, y, kind = pts[k], pts[k + 1], pts[k + 2]
		px(idx, x, y, if kind == 0 then C.GHOST3 elseif kind == 1 then C.BOLT1 else C.BOLT0)
	end
end

-- Red attack telegraph. Opens from its axis, fills with hatching outward from the reaper (a
-- bright fill front), the outline pulses faster as the strike nears; on impact it flashes, then
-- dithers away from the far end in.
local function drawCone(self: Scene, idx: buffer, t: number)
	if t < T_TEL or t > T_HIT + 0.95 then
		return
	end
	local cone = self.cone
	local open = easeOut((t - T_TEL) / 0.2)
	local half = CONE_HALF * open
	local fill = smooth(T_TEL + 0.1, T_SLASH - 0.05, t)
	local rf = CONE_R0 + (CONE_R1 + 6 - CONE_R0) * fill
	local rate = 5 + 13 * fill
	local pulse = math.floor((t - T_TEL) * rate) % 2
	local edge = if pulse == 0 then C.RED2 else C.RED3
	local hatch = math.floor(t * 16)
	local hit = t - T_HIT
	local fade = if hit > 0.12 then 1 - smooth(0.12, 0.9, hit) else 1
	for k = 1, #cone, 4 do
		local x, y, r, da = cone[k], cone[k + 1], cone[k + 2], cone[k + 3]
		local ad = math.abs(da)
		if ad <= half then
			local bth = BAYER[(y % 4) * 4 + x % 4 + 1]
			if fade >= 1 or fade > bth * 0.75 + (r - CONE_R0) / (CONE_R1 - CONE_R0) * 0.25 then
				local i = y * W + x
				local m = math.min(r - CONE_R0, CONE_R1 + 0.5 - r, (half - ad) * r)
				local col = -1
				if hit >= 0 and hit < 0.14 then
					-- impact flash: white-hot first frame, then red
					-- impact flash, still hatched and capped below white: hot first frame, then red
					local hv = (x + y + hatch) % 4
					if hit < 0.07 then
						col = if m < 1 or hv < 2 then C.RED3 else C.RED1
					else
						col = if m < 1 or hv < 2 then C.RED2 else C.RED0
					end
				elseif m < 1 then
					col = edge
				elseif math.abs(r - (CONE_R1 - 5)) < 0.5 then
					col = edge
				elseif r < rf then
					local behind = rf - r
					if behind < 1.2 and hit < 0 then
						col = C.RED3 -- the fill front
					else
						local hv = (x + y + hatch) % 6
						-- fresh fill is sparse, settles to full hatching
						local dens = math.clamp(behind / 14, 0.25, 1)
						if hv < 2 and dens > bth then
							col = C.RED1
						elseif hv == 2 and dens > bth then
							col = C.RED0
						end
					end
				end
				if col >= 0 then
					buffer.writeu8(idx, i, col)
				else
					-- translucent wash: ground one shade darker
					local v = buffer.readu8(idx, i)
					if v < 192 and v % 6 > 0 then
						buffer.writeu8(idx, i, v - 1)
					end
				end
			end
		end
	end
end

-- Sparks and dust thrown out of the cone by the impact.
local function drawImpact(idx: buffer, t: number)
	local dt = t - T_HIT
	if dt < 0 or dt > 0.9 then
		return
	end
	for m = 1, 56 do
		local life = 0.35 + 0.5 * hash(m, 1, 81)
		local u = dt / life
		if u < 1 then
			local r0 = CONE_R0 + 8 + (CONE_R1 - CONE_R0 - 10) * hash(m, 2, 81)
			local a = CONE_DIR + (hash(m, 3, 81) - 0.5) * 2 * CONE_HALF * 0.9
			local spd = 40 + 70 * hash(m, 4, 81)
			local dist = spd * life * (1 - (1 - u) * (1 - u)) * 0.5
			local x = CAX + math.cos(a) * (r0 + dist)
			local y = CAY + math.sin(a) * (r0 + dist) - 22 * u + 30 * u * u
			local spark = hash(m, 5, 81) < 0.55
			local col
			if spark then
				col = if u < 0.3 then C.RED3 elseif u < 0.6 then C.RED2 else C.RED1
			else
				col = if u < 0.5 then C.BONE_SH else C.WAX_OUT
			end
			local ix, iy = math.floor(x + 0.5), math.floor(y + 0.5)
			if u < 0.7 or BAYER[(iy % 4) * 4 + ix % 4 + 1] > (u - 0.7) / 0.3 then
				px(idx, ix, iy, col)
				if spark and u < 0.35 then
					-- short streak behind a fast spark
					px(idx, math.floor(ix - math.cos(a) + 0.5), math.floor(iy - math.sin(a) + 0.5), C.RED2)
				elseif not spark then
					px(idx, ix + 1, iy, col)
				end
			end
		end
	end
end

-- Screen shake: move the whole frame by (dx, dy); the uncovered strip keeps its old pixels.
local function shake(idx: buffer, dx: number, dy: number)
	if dy > 0 then
		for y = H - 1, dy, -1 do
			buffer.copy(idx, y * W, idx, (y - dy) * W, W)
		end
	elseif dy < 0 then
		for y = 0, H - 1 + dy do
			buffer.copy(idx, y * W, idx, (y - dy) * W, W)
		end
	end
	if dx > 0 then
		for y = 0, H - 1 do
			buffer.copy(idx, y * W + dx, idx, y * W, W - dx)
		end
	elseif dx < 0 then
		for y = 0, H - 1 do
			buffer.copy(idx, y * W, idx, y * W - dx, W + dx)
		end
	end
end

local SHAKES = { { 3.88, 1.2, 0.18 }, { T_MAT, 3, 0.32 }, { T_HIT, 3, 0.3 } } -- time, px, duration
local function shakeAt(t: number): (number, number)
	for _, s in SHAKES do
		local dt = t - s[1]
		if dt >= 0 and dt < s[3] then
			local a = s[2] * (1 - dt / s[3])
			local f = math.floor(t * 30)
			return math.floor((hash(f, 1, 91) * 2 - 1) * a + 0.5), math.floor((hash(f, 2, 91) * 2 - 1) * a + 0.5)
		end
	end
	return 0, 0
end

local function drawTimer(idx: buffer, t: number)
	local secs = 1799 + math.floor(t - 0.5)
	local s = string.format("%02d:%02d", secs // 60, secs % 60)
	if secs == 1800 then
		-- 30:00: the only time the clock goes red; doubled, boxed, pulsing on the beat
		local beat = (t - T_DRAIN) * 4 % 1
		local hot = beat < 0.5
		local tw = Font.width(s, 2)
		local x = 240 - (tw + 1) // 2
		local grow = if beat < 0.18 then 1 else 0
		rect(idx, x - 6 - grow, 3 - grow, tw + 12 + grow * 2, 20 + grow * 2, C.RED0)
		rect(idx, x - 5 - grow, 4 - grow, tw + 10 + grow * 2, 18 + grow * 2, C.BLACK)
		local edge = if hot then C.RED2 else C.RED1
		rect(idx, x - 6 - grow, 3 - grow, tw + 12 + grow * 2, 1, edge)
		rect(idx, x - 6 - grow, 22 + grow, tw + 12 + grow * 2, 1, edge)
		rect(idx, x - 6 - grow, 3 - grow, 1, 20 + grow * 2, edge)
		rect(idx, x + tw + 5 + grow, 3 - grow, 1, 20 + grow * 2, edge)
		Font.text(idx, W, H, s, x, 6, if hot then C.RED3 else C.RED2, 2)
		return
	end
	local tw = Font.width(s, 1)
	local x = 240 - (tw + 1) // 2
	rect(idx, x - 4, 4, tw + 8, 13, C.BLACK)
	Font.text(idx, W, H, s, x, 7, C.WHITE, 1)
end

-- Faint clock numerals 1-12 in a ring round the reaper, fading in once it is solid; one numeral at
-- a time brightens as a slow hand sweeps round.
local function drawClockRing(idx: buffer, t: number, bob: number)
	local k = smooth(T_MAT_END - 0.2, T_MAT_END + 0.9, t)
	if k <= 0 then
		return
	end
	local cx, cy = VX + 2, VY - 60 + bob
	local hand = math.floor((t - T_MAT_END) * 3) % 12
	for n = 1, 12 do
		local a = (n / 12) * 2 * math.pi - math.pi / 2
		local s = tostring(n)
		local w = Font.width(s, 1)
		local x = math.floor(cx + math.cos(a) * 64 - w / 2 + 0.5)
		local y = math.floor(cy + math.sin(a) * 60 - 3 + 0.5)
		local col = if n % 12 == hand then C.GHOST1 else C.CLOCK
		if k >= 1 or k > BAYER[(y % 4) * 4 + x % 4 + 1] then
			Font.text(idx, W, H, s, x, y, col, 1)
		end
		-- tick dot halfway to the next numeral
		local a2 = a + math.pi / 12
		local dx, dy = math.floor(cx + math.cos(a2) * 64 + 0.5), math.floor(cy + math.sin(a2) * 60 + 0.5)
		if k >= 1 then
			px(idx, dx, dy, C.CLOCK)
		end
	end
end

-- Title card: rendered into its own buffer, then blitted with a slide + dither-in and a dither
-- wipe out (no empty box ever left behind). The tag below grows with the typed text.
local CARD_X, CARD_Y = 240 - CARD_W // 2, 204
local function drawTitle(self: Scene, idx: buffer, t: number)
	if t < 3.5 or t > T_TITLE_OUT + 0.4 then
		return
	end
	local card = self.card
	buffer.fill(card, 0, C.BLACK)
	-- inner frame
	for x = 1, CARD_W - 2 do
		buffer.writeu8(card, CARD_W + x, C.BOX_EDGE)
		buffer.writeu8(card, (CARD_H - 2) * CARD_W + x, C.BOX_EDGE)
	end
	for y = 1, CARD_H - 2 do
		buffer.writeu8(card, y * CARD_W + 1, C.BOX_EDGE)
		buffer.writeu8(card, y * CARD_W + CARD_W - 2, C.BOX_EDGE)
	end
	local x0 = (CARD_W - Font.width(TITLE, T_SCALE)) // 2
	for i = 1, #TITLE do
		local chr = string.sub(TITLE, i, i)
		if chr ~= " " then
			local rt = 4.0 + (i - 1) * 0.2 + hash(i, 0, 3) * 0.12
			local col
			if t < rt then
				local r = hash(i, math.floor(t * 14), 5)
				chr = string.sub(Font.LETTERS, 1 + math.floor(r * 26), 1 + math.floor(r * 26))
				col = if hash(i, math.floor(t * 14), 6) < 0.3 then C.WHITE else C.TEXT_DIM
			elseif t < rt + 0.08 then
				col = C.WHITE
			else
				col = if i <= 3 then C.WHITE else C.TITLE_RED
			end
			Font.char(card, CARD_W, CARD_H, chr, x0 + (i - 1) * Font.ADV * T_SCALE, 6, col, T_SCALE)
		end
	end
	local kin = smooth(3.5, 3.8, t)
	local slide = math.floor((1 - easeOut((t - 3.5) / 0.3)) * 12 + 0.5)
	local wipe = if t > T_TITLE_OUT then (t - T_TITLE_OUT) / 0.35 else -1
	local function vis(sx: number, sy: number): boolean
		local b = BAYER[(sy % 4) * 4 + sx % 4 + 1]
		if kin < 1 and kin <= b then
			return false
		end
		if wipe >= 0 then
			local u = (sx - CARD_X) / CARD_W
			return u * 0.8 + b * 0.2 > wipe
		end
		return true
	end
	local cy0 = CARD_Y + slide
	for y = 0, CARD_H - 1 do
		local sy = cy0 + y
		if sy >= 0 and sy < H then
			for x = 0, CARD_W - 1 do
				local sx = CARD_X + x
				if vis(sx, sy) then
					buffer.writeu8(idx, sy * W + sx, buffer.readu8(card, y * CARD_W + x))
				end
			end
		end
	end
	-- the tag types out once the title has resolved; its box grows with the text plus a cursor
	if t > 5.95 then
		local n = math.clamp(math.floor((t - 5.95) / 0.04) + 1, 1, #SUB)
		local typing = n < #SUB or t < 5.95 + #SUB * 0.04 + 0.35
		local cursor = typing and math.floor(t * 8) % 2 == 0
		local shown = string.sub(SUB, 1, n)
		local fw = Font.width(SUB, 1)
		local tx = 240 - fw // 2
		local tw = Font.width(shown, 1) + (if typing then 4 else 0)
		local bx, by, bw, bh = tx - 5, cy0 + CARD_H + 2, tw + 10, 13
		for y = by, by + bh - 1 do
			for x = bx, bx + bw - 1 do
				if x >= 0 and y >= 0 and x < W and y < H and vis(x, y) then
					buffer.writeu8(idx, y * W + x, C.BLACK)
				end
			end
		end
		local glyphX = tx
		for i = 1, n do
			local ch = string.sub(SUB, i, i)
			if wipe < 0 or (glyphX + 2 - CARD_X) / CARD_W * 0.8 + 0.1 > wipe then
				Font.char(idx, W, H, ch, glyphX, by + 3, if i == n and typing then C.WHITE else C.TITLE_GOLD, 1)
			end
			glyphX += Font.ADV
		end
		if cursor and wipe < 0 then
			rect(idx, glyphX, by + 3, 3, 7, C.TITLE_GOLD)
		end
	end
end

-- Frame -------------------------------------------------------------------------------------------
-- Optional per-stage timing: set scene.stats = {} and draw() accumulates ms into it.
function Scene.draw(self: Scene, t: number)
	local stats = self.stats
	local c0 = if stats then os.clock() else 0
	local light = self.light
	local voidK = smooth(T_VOID0, T_VOID1, t)
	light:setVoidBase(if voidK < 1 then nil elseif t >= T_MAT_END then self.reapBase else self.pitBase)
	light:clear()
	local idx: buffer = self.frame.idx

	local R = corruptionRadius(t)
	local fresh = math.max(2.5, R - corruptionRadius(t - 0.08))
	local ghostA = smooth(3.0, 3.9, t)
	local rise = (1 - smooth(3.0, 4.8, t)) * 26
	local matP = math.clamp((t - T_MAT) / (T_MAT_END - T_MAT), 0, 1)
	local present = if t >= T_MAT then 1 else ghostA
	local hit = t - T_HIT

	-- lights
	for i, c in CANDLES do
		local ds = self.snuff[i] - t
		if ds > 0 then
			local fk = flameFrame(t, i)
			local fl = 1.7 + (if fk == 0 then 0.28 elseif fk == 1 then 0.12 else -0.04) + 0.1 * math.sin(t * 2.3 + i * 1.7)
			if ds < 0.15 then
				fl *= 0.55 -- gutters as the wave arrives
			end
			light:point(Light.WARM, c[1] + 0.5, c[2] - 5, 20, fl, 0.8)
		end
	end
	-- the lantern pool breathes
	light:point(Light.WARM, PX + 0.5, PY - 5, 44, 0.45 + 0.3 * math.sin(t * 2.4))
	if voidK < 1 then
		light:point(Light.VOID, VX, VY, 40 + 80 * voidK, 1.7 * voidK, 0.72)
	end
	if t < T_MAT_END and ghostA > 0 then
		light:point(Light.COLD, VX, VY - 50 + rise, 84, 1.7 * ghostA * (1 - matP))
	end
	if t >= T_MAT and t < T_MAT_END then
		light:point(Light.VOID, VX, VY - 40, 96, 0.8 * smooth(T_MAT, T_MAT_END, t))
	end
	if hit >= 0 and hit < 0.4 then
		light:point(Light.COLD, CAX - 70, CAY + 10, 90, 2.4 * (1 - hit / 0.4))
	end
	local flash = 0
	local live = {}
	for _, s in STRIKES do
		local dt = t - s[1]
		if dt >= 0 and dt < 0.6 then
			flash += s[3] * math.exp(-dt * 11)
			if dt < 0.05 or (dt > 0.075 and dt < 0.24) then
				local pts = self.bolts[s[2]]
				table.insert(live, pts)
				for k = 1, #pts, 30 do
					if pts[k + 2] == 0 then
						light:point(Light.COLD, pts[k], pts[k + 1], 16, 1.1)
					end
				end
			end
		end
	end
	-- pixel-snapped flash steps so it reads as a hard strobe
	flash = math.min(1, math.floor(flash * 2 + 0.5) / 2)

	local c1 = if stats then os.clock() else 0
	ground(self, R, flash, fresh, math.floor(t * 20), math.floor(flash * 2 + 0.5))
	local c2 = if stats then os.clock() else 0

	drawTendrils(idx, t, smooth(2.0, 4.5, t))
	drawVoid(idx, t, voidK)

	-- reaper / ghost
	local rp = self.rp
	local pose = poseAt(t)
	local bob = math.floor(math.sin(t * 2.2) * 1.5 + 0.5)
	if t >= T_MAT then
		-- cast shadow on the stone around the pit (tighter when it bobs up)
		darken(idx, VX + 1, VY + 1, 38 + bob, 12, 1)
		darken(idx, VX + 1, VY + 1, 30 + bob, 9, 1)
	end
	drawCone(self, idx, t)
	for i, c in CANDLES do
		if c[2] < VY then
			drawCandle(idx, c[1], c[2], t, i, self.snuff[i])
		end
	end
	for _, s in SHROOMS do
		px(idx, s[1], s[2] - 1, C.SHROOM)
		px(idx, s[1] - 1, s[2], C.SHROOM)
		px(idx, s[1], s[2], C.SHROOM)
		px(idx, s[1] + 1, s[2], C.SHROOM_SH)
		px(idx, s[1], s[2] + 1, C.BONE_SH)
	end
	drawFrontSparks(self, idx, t, R)
	drawMotes(idx, t)
	drawPitMotes(idx, t, voidK)
	drawClockRing(idx, t, bob)
	if present > 0.01 then
		rp:compose(t, pose)
		local ox, oy = VX - Reaper.AX, VY - Reaper.AY + bob + math.floor(rise + 0.5)
		local phase = (math.floor(t * 12) % 4) * 0.25
		if t < T_MAT then
			rp:blit(idx, W, H, ox, oy, 1, 0, ghostA, phase, VY + 1)
			drawWisps(idx, t, ghostA * 0.6, VX, VY + bob + math.floor(rise + 0.5), true)
		elseif matP < 1 then
			rp:blit(idx, W, H, ox, oy, 2, matP, 1, phase, H)
			drawWisps(idx, t, matP, VX, VY + bob, false)
		else
			rp:blit(idx, W, H, ox, oy, 0, 1, 1, 0, H)
			drawWisps(idx, t, 1, VX, VY + bob, false)
		end
	end
	for i, c in CANDLES do
		if c[2] >= VY then
			drawCandle(idx, c[1], c[2], t, i, self.snuff[i])
		end
	end
	drawPlayer(idx, t)
	drawImpact(idx, t)
	for _, pts in live do
		drawBolt(idx, pts)
	end
	local sx, sy = shakeAt(t)
	shake(idx, sx, sy)
	drawTimer(idx, t)
	drawTitle(self, idx, t)
	self.frame.allDirty = true
	if stats then
		local c3 = os.clock()
		stats.lights = (stats.lights or 0) + (c1 - c0) * 1000
		stats.ground = (stats.ground or 0) + (c2 - c1) * 1000
		stats.overlays = (stats.overlays or 0) + (c3 - c2) * 1000
		stats.frames = (stats.frames or 0) + 1
	end
end

Scene.hash = hash

return Scene
