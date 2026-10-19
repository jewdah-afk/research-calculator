--!native
--!optimize 2
-- "THE REAPER" boss entrance (minute 30) in a clean Bit-Wonder pixel style, rendered into a
-- 480x270 palette-indexed frame (IndexedFrame). Deterministic: draw(t) depends only on t (0..10 s).
--
--   0.0  calm graveyard at night: grass, cobbles, candles, tombstones, trees, lantern pool
--   1.0  the void opens in the graveyard (swirling pit, purple glow)
--   1.3  Voronoi-cracked void stone spreads outward behind a glowing purple frontier, eating the grass
--   3.0  a translucent ghost rises out of the pit; Lichtenberg-style lightning strikes it (flash)
--   3.5  title card: "THE REAPER" scrambles in, "MINUTE 30" types out
--   5.5  the ghost condenses into the solid reaper with its scythe
--   7.6  a red hatched cone telegraph sweeps out toward the player and pulses
--
-- Static layers (ground material + shade offset for the normal and the corrupted world, and the
-- corruption arrival field) are built once in new(). Each frame: clear and splat a handful of
-- point lights, one ground pass that picks a layer, quantises light with a Bayer threshold and
-- writes a palette index, then sprites and UI on top.

local IndexedFrame = require("../IndexedFrame")
local Palette = require("./Palette")
local Light = require("./Light")
local Font = require("./Font")

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

-- Sprites ---------------------------------------------------------------------------------------
local RW, RH, RAX, RAY = 96, 116, 40, 112 -- reaper sprite and its feet anchor

local function buildReaper(): buffer
	local code = buffer.create(RW * RH)
	local cx = 40
	local function bodyW(y: number): number
		local u = math.clamp((y - 34) / 72, 0, 1)
		return 13 + 17 * u ^ 0.8
	end
	for y = 0, RH - 1 do
		for x = 0, RW - 1 do
			local px, py = x + 0.5, y + 0.5
			local c = 0
			-- hood + pointed tip leaning back
			local hx, hy = (px - cx) / 12.5, (py - 23) / 14
			if hx * hx + hy * hy < 1 then
				c = 1
			end
			if py > 5 and py < 16 and math.abs(px - (cx - 2 + (16 - py) * 0.5)) < (py - 5) * 0.75 then
				c = 1
			end
			-- shoulders
			local sx, sy = (px - cx) / 18, (py - 40) / 10
			if sx * sx + sy * sy < 1 then
				c = 1
			end
			-- robe with a ragged hem
			if py > 36 then
				local tooth = math.abs((x % 9) - 4.5) - 2.2
				if math.abs(px - cx) < bodyW(py) and py < 106 + tooth then
					c = 1
				end
			end
			-- sleeve reaching to the staff (capsule)
			do
				local ax, ay, bx, by = 48, 42, 63, 60
				local vx, vy = bx - ax, by - ay
				local u = math.clamp(((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy), 0, 1)
				local qx, qy = ax + vx * u - px, ay + vy * u - py
				if qx * qx + qy * qy < (7 - 2 * u) ^ 2 then
					c = 3
				end
			end
			-- face opening
			if c == 1 then
				local fx, fy = (px - cx) / 7.5, (py - 25) / 8.5
				if fx * fx + fy * fy < 1 then
					c = 2
				end
			end
			buffer.writeu8(code, y * RW + x, c)
		end
	end
	local function codeAt(x: number, y: number): number
		if x < 0 or y < 0 or x >= RW or y >= RH then
			return 0
		end
		return buffer.readu8(code, y * RW + x)
	end
	local out = buffer.create(RW * RH)
	for y = 0, RH - 1 do
		for x = 0, RW - 1 do
			local c = codeAt(x, y)
			local col = 0
			local b = Palette.bayer(x, y)
			if c == 3 then
				-- sleeve sits over the body: outlined against everything that is not sleeve
				if codeAt(x - 1, y) ~= 3 or codeAt(x + 1, y) ~= 3 or codeAt(x, y - 1) ~= 3 or codeAt(x, y + 1) ~= 3 then
					col = C.ROBE0
				else
					-- signed distance across the sleeve axis: upper side lit
					local ax, ay, bx, by = 48, 42, 63, 60
					local vx, vy = bx - ax, by - ay
					local len = math.sqrt(vx * vx + vy * vy)
					local side = ((x + 0.5 - ax) * vy - (y + 0.5 - ay) * vx) / len
					local s = 0.5 + side * 0.11
					col = C.ROBE1 + math.clamp(Palette.level(s * 3.6, b), 0, 3)
				end
			elseif c == 1 then
				if codeAt(x - 1, y) == 0 or codeAt(x + 1, y) == 0 or codeAt(x, y - 1) == 0 or codeAt(x, y + 1) == 0 then
					col = C.ROBE0
				else
					local px, py = x + 0.5, y + 0.5
					local w = if py < 36 then 13 else bodyW(py)
					local nx = math.clamp((px - cx) / w, -1, 1)
					local s = 0.36 - 0.42 * nx
					if codeAt(x - 2, y) == 0 or codeAt(x - 1, y - 2) == 0 then
						s = 1 -- void rim light along the left silhouette
					end
					if py > 44 then
						for _, f in { -0.62, -0.18, 0.3, 0.7 } do
							local lx = cx + f * w
							local d = px - lx
							if math.abs(d) < 0.8 then
								s -= 0.42
							elseif d < 0 and d > -2 then
								s += 0.18
							end
						end
					end
					-- void up-light on the hem
					s += 0.5 * math.clamp((py - 86) / 22, 0, 1)
					-- hood lip around the face catches light
					if codeAt(x + 1, y + 1) == 2 or codeAt(x, y + 1) == 2 or codeAt(x + 1, y) == 2 then
						s = 0.98
					elseif codeAt(x - 1, y - 1) == 2 or codeAt(x - 1, y) == 2 or codeAt(x, y - 1) == 2 then
						s = 0.05
					end
					local lv = math.clamp(Palette.level(s * 3.6, b), 0, 3)
					col = C.ROBE1 + lv
				end
			elseif c == 2 then
				col = if y < 21 then C.ROBE0 else C.BLACK
			end
			buffer.writeu8(out, y * RW + x, col)
		end
	end
	-- eyes
	for _, e in { { 35, 26 }, { 43, 26 } } do
		buffer.writeu8(out, e[2] * RW + e[1], C.EYE)
		buffer.writeu8(out, e[2] * RW + e[1] + 1, C.EYE_HI)
		buffer.writeu8(out, (e[2] + 1) * RW + e[1], C.EYE)
		buffer.writeu8(out, (e[2] + 1) * RW + e[1] + 1, C.EYE)
	end
	local function setp(x: number, y: number, col: number)
		if x >= 0 and y >= 0 and x < RW and y < RH then
			buffer.writeu8(out, y * RW + x, col)
		end
	end
	-- staff: 2 px, slightly tilted, outlined on both sides
	for y = 2, RH - 4 do
		local x = math.floor(70 - (y - 2) * 0.09)
		setp(x - 1, y, C.ROBE0)
		setp(x, y, C.STAFF)
		setp(x + 1, y, C.STAFF_SH)
		setp(x + 2, y, C.ROBE0)
	end
	-- bony hand gripping the staff
	for _, p in { { 67, 59, C.BONE }, { 68, 59, C.BONE }, { 67, 60, C.BONE_SH }, { 68, 60, C.BONE },
		{ 69, 60, C.BONE_SH }, { 67, 61, C.BONE_SH }, { 68, 61, C.BONE_SH }, { 66, 60, C.ROBE0 }, { 66, 59, C.ROBE0 } } do
		setp(p[1], p[2], p[3])
	end
	-- blade: crescent sweeping left over the hood
	local blade = buffer.create(RW * RH)
	for y = 0, 30 do
		for x = 10, 74 do
			local px, py = x + 0.5, y + 0.5
			local o = (px - 50) ^ 2 + (py - 30) ^ 2 < 27 ^ 2
			local i = (px - 47) ^ 2 + (py - 36) ^ 2 < 27 ^ 2
			if o and not i and py < 24 and px < 72 then
				buffer.writeu8(blade, y * RW + x, 1)
			end
		end
	end
	local function bl(x: number, y: number): boolean
		return x >= 0 and y >= 0 and x < RW and y < RH and buffer.readu8(blade, y * RW + x) == 1
	end
	for y = 0, 34 do
		for x = 0, RW - 1 do
			if bl(x, y) then
				local col = C.BLADE
				if not bl(x, y - 1) or not bl(x - 1, y - 1) then
					col = C.BLADE_HI
				elseif not bl(x, y + 1) then
					col = C.BLADE_SH
				end
				setp(x, y, col)
			elseif bl(x - 1, y) or bl(x + 1, y) or bl(x, y - 1) or bl(x, y + 1) then
				setp(x, y, C.ROBE0)
			end
		end
	end
	-- staff head collar
	setp(68, 2, C.BLADE_SH)
	setp(69, 2, C.BLADE_SH)
	setp(70, 2, C.BLADE_SH)
	setp(71, 2, C.BLADE_SH)
	return out
end

local GK = 1.2 -- ghost drawn at 1.2x its design size
local GW, GH, GAX, GAY = 134, 120, 67, 115 -- ghost sprite and anchor

local function sdEllipse(px: number, py: number, cx: number, cy: number, rx: number, ry: number): number
	local q = math.sqrt(((px - cx) / rx) ^ 2 + ((py - cy) / ry) ^ 2)
	return (q - 1) * math.min(rx, ry)
end
local function sdCapsule(px: number, py: number, ax: number, ay: number, bx: number, by: number, ra: number, rb: number): number
	local vx, vy = bx - ax, by - ay
	local u = math.clamp(((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy), 0, 1)
	local dx, dy = ax + vx * u - px, ay + vy * u - py
	return math.sqrt(dx * dx + dy * dy) - (ra + (rb - ra) * u)
end
local function smin(a: number, b: number, k: number): number
	local h = math.clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)
end

-- Wraith: pointed hood, arms spread wide, body thinning into a wisp. Smooth-union SDF so the
-- parts melt together; alpha comes from depth inside the shape (dense glowing rim, thin core).
local function buildGhost(): (buffer, buffer)
	local alpha = buffer.create(GW * GH)
	local col = buffer.create(GW * GH)
	local cx = 56
	for y = 0, GH - 1 do
		for x = 0, GW - 1 do
			local px, py = (x + 0.5) / GK, (y + 0.5) / GK
			local wx = px - math.sin(py * 0.17) * 3.2 * math.clamp((py - 52) / 40, 0, 1)
			local d = sdEllipse(px, py, cx, 23, 12.5, 13.5)
			d = smin(d, sdCapsule(px, py, cx - 2, 5, cx, 18, 2, 9), 3)
			d = smin(d, sdEllipse(px, py, cx, 42, 17, 10), 5)
			-- arms held out and down, blended only a little so the armpits stay notched
			local arms = math.min(
				sdCapsule(px, py, cx - 12, 39, cx - 34, 54, 7.5, 5),
				sdCapsule(px, py, cx + 12, 39, cx + 34, 54, 7.5, 5)
			)
			-- wide sleeves drooping into tatters
			arms = smin(arms, sdCapsule(px, py, cx - 35, 56, cx - 39, 72, 5.5, 1), 3)
			arms = smin(arms, sdCapsule(px, py, cx + 35, 56, cx + 40, 71, 5.5, 1), 3)
			d = smin(d, arms, 2.5)
			d = smin(d, sdCapsule(wx, py, cx, 46, cx + 3, 95, 15, 1), 5)
			local a, c
			if d < 0 then
				-- dense bright core, ordered-dither falloff toward the edge (reads as glow)
				local depth = -d * GK
				a = 0.62 + 0.38 * math.clamp(depth / 6, 0, 1)
				c = if depth > 5 then C.GHOST3 elseif depth > 2.2 then C.GHOST2 else C.GHOST1
				if depth < 1 then
					a, c = 1, C.GHOST2 -- crisp silhouette edge
				end
			elseif d * GK < 6 then
				a, c = 0.4 * (1 - d * GK / 6), C.GHOST1 -- halo
			else
				a, c = 0, 0
			end
			a *= 1 - smooth(66, 97, py)
			-- face opening
			local f = sdEllipse(px, py, cx, 25, 6.5, 7)
			if f < 0 then
				a, c = 1, C.GHOST0
			end
			buffer.writeu8(alpha, y * GW + x, math.floor(a * 255 + 0.5))
			buffer.writeu8(col, y * GW + x, c)
		end
	end
	for _, e in { { 62, 30 }, { 70, 30 } } do
		buffer.writeu8(col, e[2] * GW + e[1], C.EYE)
		buffer.writeu8(col, e[2] * GW + e[1] + 1, C.EYE_HI)
		buffer.writeu8(col, (e[2] + 1) * GW + e[1], C.EYE)
		buffer.writeu8(col, (e[2] + 1) * GW + e[1] + 1, C.EYE)
	end
	return alpha, col
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
		layers: Layers,
		corr: buffer,
		reaper: buffer,
		ghostA: buffer,
		ghostC: buffer,
		bolts: { { number } },
		stats: { [string]: number }?,
		ambB: buffer,
	},
	Scene
))

function Scene.new(): Scene
	local frame = IndexedFrame.new(W, H)
	Palette.apply(frame)
	local light = Light.new(W, H)
	light:setAmbient(2.0, 1.05)
	-- the player's lantern is static in this shot: bake it into the warm base once
	light:clear()
	light:point(Light.WARM, PX + 0.5, PY - 5, 80, 3.3)
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
	-- dark swirl strokes in the void stone
	for arm = 0, 1 do
		for k = 0, 360 do
			local u = k / 360
			local th = arm * math.pi + 0.6 + u * 3.6
			local r = 92 + 60 * u
			local x = GX + math.cos(th) * r * 1.25
			local y = GY + math.sin(th) * r * 0.78
			local rad = 2.2 * math.sin(math.pi * u) ^ 0.6
			for oy = -3, 3 do
				for ox = -3, 3 do
					local px, py = math.floor(x + ox), math.floor(y + oy)
					if inb(px, py) and (px + 0.5 - x) ^ 2 + (py + 0.5 - y) ^ 2 < rad * rad then
						buffer.writeu8(L.cOff, py * W + px, OFF0 - 4)
					end
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
			d += math.max(0, 112 - pd) * 1.9
			buffer.writef32(corr, (y * W + x) * 4, math.max(0, d))
		end
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

	local ghostA, ghostC = buildGhost()
	local bolts = {
		genBolt(11, 430, -2, 396, 40),
		genBolt(23, 372, -2, 324, 104),
		genBolt(37, 262, -2, 310, 110),
		genBolt(41, 392, -2, 336, 138),
		genBolt(59, 410, -2, 354, 128),
	}

	return setmetatable({
		frame = frame,
		light = light,
		layers = L,
		corr = corr,
		reaper = buildReaper(),
		ghostA = ghostA,
		ghostC = ghostC,
		bolts = bolts,
		stats = nil,
		ambB = ambB,
	}, Scene)
end

-- Timeline ---------------------------------------------------------------------------------------
local STRIKES = { -- time, bolt, flash strength
	{ 2.42, 1, 0.7 },
	{ 3.3, 2, 1.6 },
	{ 3.88, 3, 1.9 },
	{ 4.75, 4, 1.4 },
	{ 5.45, 2, 1.6 },
	{ 6.35, 5, 1.9 },
	{ 7.25, 3, 1.0 },
}

local function corruptionRadius(t: number): number
	if t < 1.3 then
		return -1000
	end
	return 305 * (1 - math.exp(-(t - 1.3) / 1.7))
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

-- Darken lit ground pixels one ramp step inside an ellipse (dithered rim).
local function darken(idx: buffer, cx: number, cy: number, rx: number, ry: number)
	for y = math.floor(cy - ry), math.ceil(cy + ry) do
		for x = math.floor(cx - rx), math.ceil(cx + rx) do
			if inb(x, y) then
				local q = ((x + 0.5 - cx) / rx) ^ 2 + ((y + 0.5 - cy) / ry) ^ 2
				if q < 1 and (q < 0.55 or BAYER[(y % 4) * 4 + x % 4 + 1] > (q - 0.55) / 0.45) then
					local i = y * W + x
					local v = buffer.readu8(idx, i)
					if v < 192 and v % 6 > 0 then
						buffer.writeu8(idx, i, v - 1)
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

local function ground(self: Scene, R: number, flash: number)
	local idx: buffer = self.frame.idx
	local L = self.layers
	local nMat, nOff, cMat, cOff = L.nMat, L.nOff, L.cMat, L.cOff
	local corr: buffer = self.corr
	local ambB: buffer = self.ambB
	local lw, lc, lp = self.light.warm, self.light.cold, self.light.void
	local RIM, RIM_HI = C.RIM, C.RIM_HI
	for y = 0, H - 1 do
		local brow = bit32.band(y, 3) * 4 + 1
		local row = y * W
		for x = 0, W - 1 do
			local i = row + x
			local o = i * 4
			local e = buffer.readf32(corr, o) - R
			local p = buffer.readf32(lp, o)
			local mat, off
			if e < 0 then
				if e > -1.5 then
					buffer.writeu8(idx, i, RIM_HI)
					continue
				end
				mat = buffer.readu8(cMat, i)
				off = buffer.readu8(cOff, i)
				if mat >= VEIN_FLAG then
					mat -= VEIN_FLAG
					-- cracks glow just behind the frontier, then go dark as the stone settles
					if e > -VEIN then
						buffer.writeu8(idx, i, if e > -VEIN * 0.35 then RIM_HI else RIM)
						continue
					end
				end
				if e > -14 then
					p += 1.5 * (1 + e / 14)
				end
			else
				mat = buffer.readu8(nMat, i)
				off = buffer.readu8(nOff, i)
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
			end
			local w = buffer.readf32(lw, o)
			local c = buffer.readf32(lc, o) + flash
			-- ambB already holds ambient + the per-pixel Bayer bias, so the dithered, band-sharpened
			-- quantisation is a single floor
			local lvl = math.floor(buffer.readf32(ambB, o) + w + c + p) + off - OFF0
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
			buffer.writeu8(idx, i, mat * 24 + tint * 6 + lvl)
		end
	end
end

-- Overlays ----------------------------------------------------------------------------------------
local function drawVoid(idx: buffer, t: number, k: number)
	if k <= 0.02 then
		return
	end
	local rx, ry = 27 * k, 11.5 * k
	local function q(x: number, y: number): number
		return ((x + 0.5 - VX) / rx) ^ 2 + ((y + 0.5 - VY) / ry) ^ 2
	end
	for y = math.floor(VY - ry - 1), math.ceil(VY + ry + 1) do
		for x = math.floor(VX - rx - 1), math.ceil(VX + rx + 1) do
			local qq = q(x, y)
			if qq < 1 then
				local col
				if q(x - 1, y) >= 1 or q(x + 1, y) >= 1 or q(x, y - 1) >= 1 or q(x, y + 1) >= 1 then
					col = if y + 0.5 > VY then C.RIM_HI else C.RIM
				elseif y + 0.5 < VY and qq > 0.5 then
					col = C.VOID1 -- far inner wall
				else
					local dx, dy = (x + 0.5 - VX) / rx, (y + 0.5 - VY) / ry
					local a = math.atan2(dy, dx) / (2 * math.pi)
					local v = (a * 2 + math.sqrt(qq) * 1.4 - t * 0.55) % 1
					col = if v < 0.16 then C.VOID1 else C.VOID0
				end
				px(idx, x, y, col)
			end
		end
	end
end

local function drawCandle(idx: buffer, x: number, y: number, t: number, i: number)
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
	local f = hash(i, math.floor(t * 9), 17)
	local sway = if f < 0.25 then -1 elseif f > 0.8 then 1 else 0
	local top = y - h - 2
	px(idx, x, top, C.FLAME_HI)
	px(idx, x - 1, top, C.FLAME_LO)
	px(idx, x + 1, top, C.FLAME_LO)
	px(idx, x, top - 1, C.FLAME_HI)
	px(idx, x, top - 2, C.FLAME)
	if f > 0.3 then
		px(idx, x + sway, top - 3, C.FLAME_LO)
	end
end

local KNIGHT = {
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
}
local KNIGHT_MAP = {
	o = C.KNIGHT_OUT, H = C.KNIGHT_HI, W = C.KNIGHT, V = C.VISOR,
	b = C.CAPE, c = C.CAPE_SH, L = C.LANTERN,
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
	local bob = if (t * 2.5) % 2 < 1 then 0 else -1
	local x0, y0 = PX - 7, PY - 15 + bob
	drawSprite(idx, KNIGHT, KNIGHT_MAP, x0, y0)
	-- lantern glint flickers
	if hash(3, math.floor(t * 8), 29) > 0.5 then
		px(idx, x0 + 14, y0 + 12, C.FLAME_HI)
	end
end

local function drawGhost(self: Scene, t: number, a: number, rise: number)
	if a <= 0.01 then
		return
	end
	local idx: buffer = self.frame.idx
	local x0, y0 = VX - GAX, VY - GAY + math.floor(rise)
	local phase = (math.floor(t * 10) % 4) * 0.25
	local ga, gc = self.ghostA, self.ghostC
	for y = 0, GH - 1 do
		local sy = y0 + y
		if sy >= 0 and sy < H and sy <= VY then
			local wob = math.floor(math.sin(t * 5 + y * 0.21) * 1.2 + 0.5)
			for x = 0, GW - 1 do
				local al = buffer.readu8(ga, y * GW + x)
				if al > 0 then
					local sx = x0 + x + (if y > 50 then wob else 0)
					if sx >= 0 and sx < W then
						local th = (BAYER[(sy % 4) * 4 + sx % 4 + 1] + phase) % 1
						if al / 255 * a > th then
							buffer.writeu8(idx, sy * W + sx, buffer.readu8(gc, y * GW + x))
						end
					end
				end
			end
		end
	end
end

local function drawReaper(self: Scene, t: number, a: number)
	if a <= 0.01 then
		return
	end
	local idx: buffer = self.frame.idx
	local bob = math.floor(math.sin(t * 2.2) * 1.5 + 0.5)
	local x0, y0 = VX - RAX, VY - RAY + bob
	local spr = self.reaper
	for y = 0, RH - 1 do
		local sy = y0 + y
		if sy >= 0 and sy < H then
			for x = 0, RW - 1 do
				local col = buffer.readu8(spr, y * RW + x)
				if col ~= 0 then
					local sx = x0 + x
					if sx >= 0 and sx < W and (a >= 1 or a > BAYER[(sy % 4) * 4 + sx % 4 + 1]) then
						buffer.writeu8(idx, sy * W + sx, col)
					end
				end
			end
		end
	end
end

-- Void motes: single pixels drifting up out of the pit, dimming as they rise.
local function drawMotes(idx: buffer, t: number, k: number)
	if k <= 0 then
		return
	end
	for m = 1, 36 do
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

-- Red attack telegraph: annular sector toward the player, outlined, hatched on pixel diagonals.
local CAX, CAY = 300, 164
local function drawCone(idx: buffer, t: number, k: number)
	if k <= 0 then
		return
	end
	local dir = math.atan2(PY - 6 - CAY, PX - CAX)
	local half = 0.44
	local r0 = 24
	local r1 = math.floor(r0 + (136 - r0) * k)
	local pulse = math.floor(t * 6) % 2
	local edge = if pulse == 0 then C.RED2 else C.RED3
	local hatch = math.floor(t * 14)
	for y = math.max(0, CAY - r1 - 1), math.min(H - 1, CAY + r1 + 1) do
		for x = math.max(0, CAX - r1 - 1), math.min(W - 1, CAX) do
			local dx, dy = x + 0.5 - CAX, y + 0.5 - CAY
			local r = math.sqrt(dx * dx + dy * dy)
			if r >= r0 and r <= r1 + 0.5 then
				local da = math.atan2(dy, dx) - dir
				if da > math.pi then
					da -= 2 * math.pi
				elseif da < -math.pi then
					da += 2 * math.pi
				end
				local ad = math.abs(da)
				if ad <= half then
					local i = y * W + x
					local m = math.min(r - r0, r1 + 0.5 - r, (half - ad) * r)
					if m < 1 then
						buffer.writeu8(idx, i, edge)
					elseif math.abs(r - (r1 - 5)) < 0.5 then
						buffer.writeu8(idx, i, edge)
					elseif (x + y + hatch) % 6 < 2 then
						buffer.writeu8(idx, i, C.RED1)
					elseif (x + y + hatch) % 6 == 2 then
						buffer.writeu8(idx, i, C.RED0)
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
end

local function drawTimer(idx: buffer, t: number)
	local secs = 1799 + math.floor(t - 0.5)
	local s = string.format("%02d:%02d", secs // 60, secs % 60)
	local tw = Font.width(s, 1)
	local x = 240 - (tw + 1) // 2
	rect(idx, x - 4, 4, tw + 8, 13, C.BLACK)
	Font.text(idx, W, H, s, x, 7, C.WHITE, 1)
end

local TITLE = "THE REAPER"
local SUB = "MINUTE 30"
local function drawTitle(idx: buffer, t: number)
	if t < 3.5 or t > 8.9 then
		return
	end
	local scale = 3
	local tw = Font.width(TITLE, scale)
	local bw, bh = tw + 18, 33
	local open = smooth(3.5, 3.75, t) * (1 - smooth(8.55, 8.85, t))
	local cw = math.floor(bw * open / 2) * 2
	local ch = math.max(2, math.floor(bh * math.min(1, open * 1.6) / 2) * 2)
	local bx, by = 240 - cw // 2, 206 + (bh - ch) // 2
	rect(idx, bx, by, cw, ch, C.BLACK)
	if open < 0.98 then
		return
	end
	local x0, y0 = 240 - tw // 2, 212
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
			Font.char(idx, W, H, chr, x0 + (i - 1) * Font.ADV * scale, y0, col, scale)
		end
	end
	-- subtitle tag types out under the box once the title has resolved
	if t > 5.95 then
		local n = math.clamp(math.floor((t - 5.95) / 0.035) + 1, 0, #SUB)
		local sw = Font.width(SUB, 1)
		local sx = 240 - sw // 2
		rect(idx, sx - 5, 239, sw + 10, 13, C.BLACK)
		Font.text(idx, W, H, string.sub(SUB, 1, n), sx, 242, C.TITLE_GOLD, 1)
	end
end

-- Frame -------------------------------------------------------------------------------------------
-- Optional per-stage timing: set scene.stats = {} and draw() accumulates ms into it.
function Scene.draw(self: Scene, t: number)
	local stats = self.stats
	local c0 = if stats then os.clock() else 0
	local light = self.light
	light:clear()
	local idx: buffer = self.frame.idx

	local R = corruptionRadius(t)
	local voidK = smooth(1.0, 2.0, t)
	local ghostA = smooth(3.0, 4.4, t) * (1 - smooth(5.6, 6.25, t))
	local rise = (1 - smooth(3.0, 4.8, t)) * 26
	local reapA = smooth(5.5, 6.25, t)
	local coneK = smooth(7.6, 8.1, t)

	-- lights
	for i, c in CANDLES do
		local fl = 1.9 + 0.2 * math.sin(t * 9.3 + i * 1.7) + 0.12 * math.sin(t * 23.1 + i * 3.1)
		light:point(Light.WARM, c[1] + 0.5, c[2] - 5, 20, fl, 0.8)
	end
	light:point(Light.VOID, VX, VY, 40 + 80 * voidK, 1.7 * voidK, 0.72)
	if ghostA > 0 then
		light:point(Light.COLD, VX, VY - 50 + rise, 84, 1.7 * ghostA)
	end
	if reapA > 0 then
		light:point(Light.VOID, VX, VY - 40, 96, 0.8 * reapA)
		light:point(Light.WARM, VX + 30, VY - 54, 10, 0.8 * reapA)
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
	ground(self, R, flash)
	local c2 = if stats then os.clock() else 0

	drawVoid(idx, t, voidK)
	drawCone(idx, t, coneK)
	for i, c in CANDLES do
		if c[2] < VY then
			drawCandle(idx, c[1], c[2], t, i)
		end
	end
	for _, s in SHROOMS do
		px(idx, s[1], s[2] - 1, C.SHROOM)
		px(idx, s[1] - 1, s[2], C.SHROOM)
		px(idx, s[1], s[2], C.SHROOM)
		px(idx, s[1] + 1, s[2], C.SHROOM_SH)
		px(idx, s[1], s[2] + 1, C.BONE_SH)
	end
	drawMotes(idx, t, voidK)
	drawGhost(self, t, ghostA, rise)
	drawReaper(self, t, reapA)
	for i, c in CANDLES do
		if c[2] >= VY then
			drawCandle(idx, c[1], c[2], t, i)
		end
	end
	drawPlayer(idx, t)
	for _, pts in live do
		drawBolt(idx, pts)
	end
	drawTimer(idx, t)
	drawTitle(idx, t)
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
