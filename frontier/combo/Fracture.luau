--!native
--!optimize 2
-- Fracture: designed fracture. Cracks are drawn into the wall's texture first, then the mesh breaks exactly
-- along them.
--   1. impact() punches a crater and seeds crack tips; step() advances every tip a few pixels per frame
--      (radial primaries with a drifting stress bias, branches biased away from the impact, tangential ring
--      cracks for big impacts that run until they meet the next radial). Tips stop at the mask edge or on
--      meeting another crack, so the network closes into cells. Each new crack pixel is shaded into the RGBA
--      texture (dark line, bevel light/shadow, light chips) and logged in p.changed + a dirty rect, ready for
--      WritePixelsBuffer. Crack lines are 8-connected, so they cut the mask into 4-connected regions.
--   2. fracture() labels those regions (scanline flood fill), classifies them (anchored if touching the
--      anchor and big enough; loose; debris; dust) and meshes each one with ContourMesh: the region is 255,
--      adjacent crack pixels 127 (just under the iso), so each fragment's outline runs through the middle of
--      its crack and neighbouring fragments meet there. Caps get UVs = the fragment's own texture pixels.
--   3. Per fragment: local mesh buffers around the pixel centroid, centroid, area, mass, anchored flag, and
--      launch() gives a deterministic initial velocity/spin away from the impact.
-- Growth is deterministic for a seed (own xorshift RNG) and step() allocates nothing. fracture() allocates
-- (one-shot event). Roblox APIs only in the ROBLOX ADAPTER section.

local CM = require("../mesh/ContourMesh")

local Fracture = {}

local RADIAL, BRANCH, RING = 0, 1, 2
local TAU = math.pi * 2
local LX, LY = -0.7071, -0.7071 -- light direction in image space (from the top-left), for crack bevels

-- 8-neighbour offsets and their bevel sign (+ lit, - shadow): a groove lit from the top-left has a lit
-- wall on its bottom-right side.
local NOX = { -1, 0, 1, -1, 1, -1, 0, 1 }
local NOY = { -1, -1, -1, 0, 0, 1, 1, 1 }
local NBEV = table.create(8, 0)
for k = 1, 8 do
	local l = math.sqrt(NOX[k] ^ 2 + NOY[k] ^ 2)
	NBEV[k] = -(NOX[k] * LX + NOY[k] * LY) / l
end

export type Material = { [string]: any }

-- Stone/brick: a handful of jagged radials, wide near the crater, heavy chipping, 2-3 rings when hit hard.
Fracture.STONE = {
	radials = { 5, 9 }, -- count at energy 0 .. 1
	reach = 0.8, -- radial length as a fraction of max(w, h), per unit energy
	wobble = 0.11, -- per-pixel heading noise (radians, 1 sigma)
	pull = 0.06, -- steering toward the stress direction per pixel
	drift = 0.03, -- random walk of each radial's bias off the pure radial direction
	maxDrift = 0.45,
	kink = 0.012, -- chance per pixel of a sharp kink
	branchP = 0.012,
	branchAng = { 0.35, 0.85 },
	branchLen = { 0.25, 0.6 },
	maxGen = 3,
	rings = 3.2, -- ring count per unit energy
	ringStart = 0.13, -- first ring radius as a fraction of the mean reach
	ringStep = 0.15,
	ringP = 0.85, -- chance each radial seeds its arc of a ring
	crush = 6, -- crater radius (px) per unit energy
	speed = 7, -- pixels per tip per frame
	wideFrac = 0.4, -- radials are 2 px wide for this fraction of their length
	crackRGB = { 24, 19, 17 },
	crackMix = 0.9,
	crushRGB = { 34, 29, 26 },
	crushMix = 0.94,
	chipRGB = { 232, 224, 208 },
	chipMix = 0.75,
	chipP = 0.22,
	lit = 0.55,
	dark = 0.5,
	spall = 2.2, -- spall ring radius / crater radius
	fractureEnergy = 0.35, -- below this, border-touching pieces never fall
	anchorMin = 0.012, -- anchored pieces need this fraction of the panel area
	debrisArea = 140, -- px: below this a piece is debris (pool a generic rock in Roblox)
	dustArea = 6, -- px: below this, no mesh (particles)
	epsilon = 0.8, -- RDP tolerance (px): removes the pixel staircase from fragment outlines
	blast = 11, -- launch speed scale (studs/s per unit energy)
	push = 9,
	spin = 9,
	interiorRGB = { 172, 112, 86 },
}

-- Glass: many straight radials, dense rings (spider web), white cracks, little chipping.
Fracture.GLASS = {
	radials = { 9, 17 },
	reach = 0.95,
	wobble = 0.035,
	pull = 0.05,
	drift = 0.012,
	maxDrift = 0.25,
	kink = 0.006,
	branchP = 0.009,
	branchAng = { 0.25, 0.6 },
	branchLen = { 0.2, 0.5 },
	maxGen = 2,
	rings = 6,
	ringStart = 0.1,
	ringStep = 0.11,
	ringP = 0.92,
	crush = 4,
	speed = 9,
	wideFrac = 0.15,
	crackRGB = { 236, 248, 255 },
	crackMix = 0.85,
	crushRGB = { 245, 250, 255 },
	crushMix = 0.92,
	chipRGB = { 205, 235, 250 },
	chipMix = 0.55,
	chipP = 0.08,
	lit = 0.45,
	dark = 0.25,
	spall = 1.8,
	fractureEnergy = 0.3,
	anchorMin = 0.004,
	debrisArea = 60,
	dustArea = 5,
	epsilon = 0.8,
	blast = 10,
	push = 11,
	spin = 14,
	interiorRGB = { 170, 215, 225 },
}

export type Fragment = {
	id: number,
	kind: string, -- "anchored" | "loose" | "debris" | "dust" (dust has no mesh)
	anchored: boolean,
	area: number, -- pixels
	areaStuds: number,
	mass: number, -- areaStuds * depth * density
	cx: number, -- centroid, studs, panel space (panel centre at 0, X right, Y up, Z out of the front face)
	cy: number,
	cz: number,
	radius: number, -- bounding radius of the local mesh
	bx0: number, -- pixel bbox
	by0: number,
	bx1: number,
	by1: number,
	vcount: number,
	tcount: number,
	pos: buffer?, -- f32 x3, local to the centroid
	uv: buffer?, -- f32 x2 per vertex, (0,0) = top-left of the texture
	idx: buffer?, -- u32 x3, CCW from outside
	nrm: buffer?, -- f32 x3 per triangle
	mat: buffer?, -- u8 per triangle: 0 front, 1 back, 2 side
	loops: number,
}

export type Panel = {
	w: number,
	h: number,
	cell: number,
	depth: number,
	density: number,
	mat: Material,
	mask: buffer, -- u8: nonzero = solid
	anchor: buffer, -- u8: nonzero = supporting pixel
	base: buffer, -- RGBA8, untouched texture
	rgba: buffer, -- RGBA8, live texture (crack shading applied)
	crack: buffer, -- u8: 0 none, 1 crack line, 2 crater
	owner: buffer, -- u16 tip serial that drew a crack pixel (0 = crater)
	edge: buffer, -- i8 bevel (+ lit, - shadow)
	chip: buffer, -- u8 chip strength
	label: buffer, -- u32 region label per pixel (after fracture)
	stack: buffer, -- u32 scratch for flood fill
	maskArea: number,
	-- tips (structure of arrays)
	maxTips: number,
	nTips: number,
	serial: number,
	tf: buffer, -- f64 x 6: x, y, angle, length left, bias, ring radius
	ti: buffer, -- i32 x 8: alive, kind, width, gen, grace, owner, last px, last py
	ts: buffer, -- i32 x 2: next ring, travelled
	-- impact
	ix: number,
	iy: number,
	energy: number,
	rng: number,
	nRings: number,
	rings: buffer, -- f64 ring radii
	ringSense: number,
	growing: boolean,
	frame: number,
	-- per-step output
	changed: buffer, -- u32 pixel indices touched this step
	nChanged: number,
	changedCap: number,
	overflow: boolean,
	dx0: number,
	dy0: number,
	dx1: number,
	dy1: number,
	field: CM.Field,
	uploadCache: { [number]: buffer },
}

local TF, TI, TS = 6, 8, 2

function Fracture.newPanel(w: number, h: number, opts: { [string]: any }?): Panel
	local o = opts or {}
	local n = w * h
	local maxTips = o.maxTips or 1024
	local p: Panel = {
		w = w,
		h = h,
		cell = o.cell or 0.04,
		depth = o.depth or 0.8,
		density = o.density or 1,
		mat = o.mat or Fracture.STONE,
		mask = buffer.create(n),
		anchor = buffer.create(n),
		base = buffer.create(n * 4),
		rgba = buffer.create(n * 4),
		crack = buffer.create(n),
		owner = buffer.create(n * 2),
		edge = buffer.create(n),
		chip = buffer.create(n),
		label = buffer.create(n * 4),
		stack = buffer.create(n * 4),
		maskArea = n,
		maxTips = maxTips,
		nTips = 0,
		serial = 0,
		tf = buffer.create(maxTips * TF * 8),
		ti = buffer.create(maxTips * TI * 4),
		ts = buffer.create(maxTips * TS * 4),
		ix = 0,
		iy = 0,
		energy = 0,
		rng = 1,
		nRings = 0,
		rings = buffer.create(16 * 8),
		ringSense = 1,
		growing = false,
		frame = 0,
		changed = buffer.create(65536 * 4),
		nChanged = 0,
		changedCap = 65536,
		overflow = false,
		dx0 = 0,
		dy0 = 0,
		dx1 = -1,
		dy1 = -1,
		field = CM.newField(17, 17, { tile = 16, cell = 1, epsilon = 0.45, minArea = 0.2 }),
		uploadCache = {},
	}
	buffer.fill(p.mask, 0, 1)
	return p
end

-- Call after writing p.mask / p.base: recounts the mask and restores the uncracked texture.
function Fracture.reset(p: Panel)
	local n = p.w * p.h
	buffer.copy(p.rgba, 0, p.base)
	buffer.fill(p.crack, 0, 0)
	buffer.fill(p.owner, 0, 0)
	buffer.fill(p.edge, 0, 0)
	buffer.fill(p.chip, 0, 0)
	local a = 0
	for i = 0, n - 1 do
		if buffer.readu8(p.mask, i) ~= 0 then
			a += 1
		end
	end
	p.maskArea = a
	p.nTips, p.growing, p.frame = 0, false, 0
end

-- Mark mask pixels on the panel's rectangle edges as supports: bits 1 left, 2 right, 4 top, 8 bottom.
function Fracture.anchorEdges(p: Panel, bits: number)
	local w, h = p.w, p.h
	buffer.fill(p.anchor, 0, 0)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local on = (x == 0 and bit32.band(bits, 1) ~= 0)
				or (x == w - 1 and bit32.band(bits, 2) ~= 0)
				or (y == 0 and bit32.band(bits, 4) ~= 0)
				or (y == h - 1 and bit32.band(bits, 8) ~= 0)
			if on and buffer.readu8(p.mask, y * w + x) ~= 0 then
				buffer.writeu8(p.anchor, y * w + x, 1)
			end
		end
	end
end

-- RNG (xorshift32) --------------------------------------------------------------------------------------------

local function rnd(p: Panel): number
	local s = p.rng
	s = bit32.bxor(s, bit32.lshift(s, 13))
	s = bit32.bxor(s, bit32.rshift(s, 17))
	s = bit32.bxor(s, bit32.lshift(s, 5))
	p.rng = s
	return s / 4294967296
end

local function randn(p: Panel): number
	return (rnd(p) + rnd(p) + rnd(p) - 1.5) * 2
end

local function angDiff(a: number, b: number): number
	return (a - b + math.pi) % TAU - math.pi
end

-- Texture shading ---------------------------------------------------------------------------------------------

local function touch(p: Panel, i: number)
	local w = p.w
	local x, y = i % w, i // w
	if x < p.dx0 then
		p.dx0 = x
	end
	if x > p.dx1 then
		p.dx1 = x
	end
	if y < p.dy0 then
		p.dy0 = y
	end
	if y > p.dy1 then
		p.dy1 = y
	end
	local n = p.nChanged
	if n < p.changedCap then
		buffer.writeu32(p.changed, n * 4, i)
		p.nChanged = n + 1
	else
		p.overflow = true
	end
end

-- Recompute one texel from the untouched base + crack state (idempotent, order independent).
local function shade(p: Panel, i: number)
	local m, base, o = p.mat, p.base, i * 4
	local r, g, b = buffer.readu8(base, o), buffer.readu8(base, o + 1), buffer.readu8(base, o + 2)
	local c = buffer.readu8(p.crack, i)
	if c ~= 0 then
		local col, k = m.crackRGB, m.crackMix
		if c == 2 then
			col, k = m.crushRGB, m.crushMix
		end
		-- small per-pixel variation so lines don't read as flat ink
		local hsh = bit32.band(bit32.bxor(i * 2654435761, bit32.rshift(i, 7)), 255) / 255
		k *= 0.92 + 0.08 * hsh
		r += (col[1] - r) * k
		g += (col[2] - g) * k
		b += (col[3] - b) * k
	else
		local e = buffer.readi8(p.edge, i) / 127
		if e > 0 then
			local k = e * m.lit
			r += (255 - r) * k
			g += (255 - g) * k
			b += (255 - b) * k
		elseif e < 0 then
			local k = 1 + e * m.dark
			r *= k
			g *= k
			b *= k
		end
		local ch = buffer.readu8(p.chip, i)
		if ch > 0 then
			local k, col = ch / 255 * m.chipMix, m.chipRGB
			r += (col[1] - r) * k
			g += (col[2] - g) * k
			b += (col[3] - b) * k
		end
	end
	buffer.writeu8(p.rgba, o, math.clamp(r // 1, 0, 255))
	buffer.writeu8(p.rgba, o + 1, math.clamp(g // 1, 0, 255))
	buffer.writeu8(p.rgba, o + 2, math.clamp(b // 1, 0, 255))
	touch(p, i)
end

local function solid(p: Panel, x: number, y: number): boolean
	return x >= 0 and y >= 0 and x < p.w and y < p.h and buffer.readu8(p.mask, y * p.w + x) ~= 0
end

-- Mark (x, y) as crack, then bevel and chip its uncracked neighbours. `strength` scales the chipping.
local function crackPx(p: Panel, x: number, y: number, own: number, strength: number)
	local w = p.w
	local i = y * w + x
	if buffer.readu8(p.crack, i) ~= 0 then
		return
	end
	buffer.writeu8(p.crack, i, 1)
	buffer.writeu16(p.owner, i * 2, own)
	shade(p, i)
	local m = p.mat
	local chipP = m.chipP * strength
	for k = 1, 8 do
		local nx, ny = x + NOX[k], y + NOY[k]
		if solid(p, nx, ny) then
			local j = ny * w + nx
			if buffer.readu8(p.crack, j) == 0 then
				local e = math.floor(NBEV[k] * 127 * math.min(1, 0.6 + 0.4 * strength))
				local old = buffer.readi8(p.edge, j)
				if math.abs(e) > math.abs(old) then
					buffer.writei8(p.edge, j, e)
				end
				if rnd(p) < chipP then
					buffer.writeu8(p.chip, j, math.min(255, buffer.readu8(p.chip, j) + 90 + math.floor(rnd(p) * 120)))
				end
				shade(p, j)
			end
		end
	end
	-- occasional wider spall flake one pixel further out on the lit side
	if strength > 0.8 and rnd(p) < chipP * 0.5 then
		local k = 1 + math.floor(rnd(p) * 8)
		local nx, ny = x + 2 * NOX[k], y + 2 * NOY[k]
		if solid(p, nx, ny) and buffer.readu8(p.crack, ny * w + nx) == 0 then
			local j = ny * w + nx
			buffer.writeu8(p.chip, j, math.min(255, buffer.readu8(p.chip, j) + 70))
			shade(p, j)
		end
	end
end

-- Tips ---------------------------------------------------------------------------------------------------------

local function tfR(p: Panel, t: number, k: number): number
	return buffer.readf64(p.tf, (t * TF + k) * 8)
end
local function tfW(p: Panel, t: number, k: number, v: number)
	buffer.writef64(p.tf, (t * TF + k) * 8, v)
end
local function tiR(p: Panel, t: number, k: number): number
	return buffer.readi32(p.ti, (t * TI + k) * 4)
end
local function tiW(p: Panel, t: number, k: number, v: number)
	buffer.writei32(p.ti, (t * TI + k) * 4, v)
end
local function tsR(p: Panel, t: number, k: number): number
	return buffer.readi32(p.ts, (t * TS + k) * 4)
end
local function tsW(p: Panel, t: number, k: number, v: number)
	buffer.writei32(p.ts, (t * TS + k) * 4, v)
end

local function spawnTip(p: Panel, kind: number, x: number, y: number, a: number, len: number, width: number, gen: number, grace: number, bias: number, ringR: number): number
	local t = p.nTips
	if t >= p.maxTips then
		return -1
	end
	p.nTips = t + 1
	p.serial = p.serial % 65535 + 1
	tfW(p, t, 0, x)
	tfW(p, t, 1, y)
	tfW(p, t, 2, a)
	tfW(p, t, 3, len)
	tfW(p, t, 4, bias)
	tfW(p, t, 5, ringR)
	tiW(p, t, 0, 1)
	tiW(p, t, 1, kind)
	tiW(p, t, 2, width)
	tiW(p, t, 3, gen)
	tiW(p, t, 4, grace)
	tiW(p, t, 5, p.serial)
	tiW(p, t, 6, math.floor(x + 0.5))
	tiW(p, t, 7, math.floor(y + 0.5))
	tsW(p, t, 0, 0)
	tsW(p, t, 1, 0)
	return t
end

-- One pixel of growth. Returns false when the tip dies (edge, joined another crack, or out of length).
local function stepTip(p: Panel, t: number): boolean
	local m, w = p.mat, p.w
	local x, y, a = tfR(p, t, 0), tfR(p, t, 1), tfR(p, t, 2)
	local kind, own = tiR(p, t, 1), tiR(p, t, 5)
	local rx, ry = x - p.ix, y - p.iy
	local r = math.sqrt(rx * rx + ry * ry)
	local ar = math.atan2(ry, rx)
	if kind == RADIAL then
		local bias = math.clamp(tfR(p, t, 4) + randn(p) * m.drift, -m.maxDrift, m.maxDrift)
		tfW(p, t, 4, bias)
		a += angDiff(ar + bias, a) * m.pull + randn(p) * m.wobble
	elseif kind == BRANCH then
		local bias = tfR(p, t, 4) * 0.985 -- the branch's offset relaxes toward radial
		tfW(p, t, 4, bias)
		a += angDiff(ar + bias, a) * m.pull + randn(p) * m.wobble
	else
		local R, sense = tfR(p, t, 5), tiR(p, t, 3)
		local corr = math.clamp((R - r) / R * 4, -0.8, 0.8)
		a += angDiff(ar + sense * (math.pi / 2 - corr), a) * 0.3 + randn(p) * m.wobble * 0.6
	end
	if rnd(p) < m.kink then
		a += (rnd(p) - 0.5) * 1.0
	end
	x += math.cos(a)
	y += math.sin(a)
	tfW(p, t, 0, x)
	tfW(p, t, 1, y)
	tfW(p, t, 2, a)
	local len = tfR(p, t, 3) - 1
	tfW(p, t, 3, len)
	local travelled = tsR(p, t, 1) + 1
	tsW(p, t, 1, travelled)
	local grace = tiR(p, t, 4)
	if grace > 0 then
		tiW(p, t, 4, grace - 1)
	end
	local px, py = math.floor(x + 0.5), math.floor(y + 0.5)
	local qx, qy = tiR(p, t, 6), tiR(p, t, 7)
	if px == qx and py == qy then
		return len > 0
	end
	local diag = px ~= qx and py ~= qy
	if not solid(p, px, py) then
		-- Left the mask. On a diagonal exit seal the corner so no 4-connected path slips round the tip.
		if diag then
			if solid(p, qx, py) then
				crackPx(p, qx, py, own, 0.5)
			end
			if solid(p, px, qy) then
				crackPx(p, px, qy, own, 0.5)
			end
		end
		return false
	end
	local i = py * w + px
	if grace <= 0 then
		local c = buffer.readu8(p.crack, i)
		if c ~= 0 and buffer.readu16(p.owner, i * 2) ~= own then
			return false -- joined another crack: this closes a cell
		end
		if diag then
			local j1, j2 = qy * w + px, py * w + qx
			if (buffer.readu8(p.crack, j1) ~= 0 and buffer.readu16(p.owner, j1 * 2) ~= own) or (buffer.readu8(p.crack, j2) ~= 0 and buffer.readu16(p.owner, j2 * 2) ~= own) then
				return false -- crossing a diagonal crack line
			end
		end
	end
	tiW(p, t, 6, px)
	tiW(p, t, 7, py)
	local width = tiR(p, t, 2)
	local strength = if kind == RADIAL then 1 elseif kind == BRANCH then 0.7 else 0.6
	crackPx(p, px, py, own, strength * (if width >= 2 then 1.2 else 1))
	if width >= 2 then
		local wx, wy = math.floor(x - math.sin(a) * 0.8 + 0.5), math.floor(y + math.cos(a) * 0.8 + 0.5)
		if solid(p, wx, wy) then
			crackPx(p, wx, wy, own, 1.2)
		end
		if travelled > tfR(p, t, 5) then -- radials store their wide length in slot 5
			tiW(p, t, 2, 1)
		end
	end
	-- Branching (radials and branches), biased away from the impact.
	local gen = tiR(p, t, 3)
	if kind ~= RING and gen < m.maxGen and travelled > 10 and rnd(p) < m.branchP then
		local lo, hi = m.branchAng[1], m.branchAng[2]
		local off = (lo + (hi - lo) * rnd(p)) * (if rnd(p) < 0.5 then -1 else 1)
		local ca = a + off
		if math.cos(angDiff(ca, ar)) < 0.15 then
			ca = a - off
		end
		local bl = m.branchLen
		local clen = math.max(8, len * (bl[1] + (bl[2] - bl[1]) * rnd(p)))
		spawnTip(p, BRANCH, x, y, ca, clen, 1, gen + 1, 3, angDiff(ca, ar), 0)
	end
	-- Ring seeding: a radial crossing ring radius k starts that ring's arc toward the next radial.
	if kind == RADIAL then
		local k = tsR(p, t, 0)
		if k < p.nRings then
			local R = buffer.readf64(p.rings, k * 8)
			if r >= R then
				tsW(p, t, 0, k + 1)
				if rnd(p) < m.ringP then
					local s = p.ringSense
					spawnTip(p, RING, x, y, ar + s * math.pi / 2, TAU * R * 0.6, 1, s, 3, 0, R)
				end
			end
		end
	end
	return len > 0
end

-- Impact ----------------------------------------------------------------------------------------------------------

-- Punch a crater at (ix, iy) (pixels) and seed the crack tips. Existing cracks are kept, so later impacts
-- stop on earlier cracks. energy ~ 0..1.5 (1 = cracks reach the panel edges).
function Fracture.impact(p: Panel, ix: number, iy: number, energy: number, seed: number)
	local m, w, h = p.mat, p.w, p.h
	p.rng = bit32.bor(bit32.band(seed * 2654435761 + 0x9E3779B9, 0xFFFFFFFF), 1)
	for _ = 1, 4 do
		rnd(p)
	end
	p.ix, p.iy, p.energy = ix, iy, energy
	p.nTips, p.frame, p.growing = 0, 0, true
	p.nChanged, p.overflow = 0, false
	p.dx0, p.dy0, p.dx1, p.dy1 = w, h, -1, -1
	local E = math.max(energy, 0)
	-- Crater (crack = 2) with a lobed outline, then a spall ring of light chips.
	local rc = math.max(0.8, m.crush * E)
	local ph1, ph2 = rnd(p) * TAU, rnd(p) * TAU
	local function rcAt(th: number): number
		return rc * (1 + 0.2 * math.sin(5 * th + ph1) + 0.1 * math.sin(11 * th + ph2))
	end
	local R2 = rc * m.spall * 1.35 + 2
	for y = math.max(0, math.floor(iy - R2)), math.min(h - 1, math.ceil(iy + R2)) do
		for x = math.max(0, math.floor(ix - R2)), math.min(w - 1, math.ceil(ix + R2)) do
			local i = y * w + x
			if buffer.readu8(p.mask, i) ~= 0 then
				local dx, dy = x - ix, y - iy
				local d = math.sqrt(dx * dx + dy * dy)
				local rr = rcAt(math.atan2(dy, dx))
				if d <= rr then
					buffer.writeu8(p.crack, i, 2)
					buffer.writeu16(p.owner, i * 2, 0)
					shade(p, i)
				elseif buffer.readu8(p.crack, i) == 0 and d < rr * m.spall then
					local k = 1 - (d - rr) / (rr * (m.spall - 1))
					if rnd(p) < 0.25 + 0.7 * k then
						buffer.writeu8(p.chip, i, math.min(255, buffer.readu8(p.chip, i) + math.floor(255 * k * (0.5 + 0.5 * rnd(p)))))
						shade(p, i)
					end
				end
			end
		end
	end
	-- Rim bevel so the crater reads as a hole.
	for y = math.max(0, math.floor(iy - R2)), math.min(h - 1, math.ceil(iy + R2)) do
		for x = math.max(0, math.floor(ix - R2)), math.min(w - 1, math.ceil(ix + R2)) do
			local i = y * w + x
			if buffer.readu8(p.crack, i) == 2 then
				for k = 1, 8 do
					local nx, ny = x + NOX[k], y + NOY[k]
					if solid(p, nx, ny) and buffer.readu8(p.crack, ny * w + nx) == 0 then
						local j = ny * w + nx
						buffer.writei8(p.edge, j, math.floor(NBEV[k] * 127))
						shade(p, j)
					end
				end
			end
		end
	end
	-- Radials, evenly spaced with jitter.
	local rl, rh = m.radials[1], m.radials[2]
	local nr = math.floor(rl + (rh - rl) * math.clamp(E, 0, 1) + 0.5)
	local reach = m.reach * math.max(w, h) * E
	local a0 = rnd(p) * TAU
	for k = 0, nr - 1 do
		local a = a0 + (k + (rnd(p) - 0.5) * 0.55) * TAU / nr
		local rr = rcAt(a)
		local len = reach * (0.7 + 0.6 * rnd(p))
		local t = spawnTip(p, RADIAL, ix + math.cos(a) * rr, iy + math.sin(a) * rr, a, len, 2, 0, 3, 0, 0)
		if t >= 0 then
			tfW(p, t, 5, len * m.wideFrac)
		end
	end
	-- Ring radii (big impacts only).
	local nRings = math.min(16, math.floor(E * m.rings))
	p.nRings = 0
	for k = 0, nRings - 1 do
		local R = reach * (m.ringStart + k * m.ringStep) * (1 + (rnd(p) - 0.5) * 0.25)
		if R > rc * 1.6 and R < reach * 0.8 then
			buffer.writef64(p.rings, p.nRings * 8, R)
			p.nRings += 1
		end
	end
	p.ringSense = if rnd(p) < 0.5 then -1 else 1
end

-- Advance the crack network by one animation frame. Allocation-free. Returns the number of texels changed
-- (indices in p.changed[0 .. n-1]; p.overflow means "upload the whole dirty rect") and the dirty rect
-- (inclusive pixel bounds; x1 < x0 when nothing changed).
function Fracture.step(p: Panel): (number, number, number, number, number)
	if p.frame > 0 then
		p.nChanged, p.overflow = 0, false
		p.dx0, p.dy0, p.dx1, p.dy1 = p.w, p.h, -1, -1
	end
	local speed = p.mat.speed
	local n = p.nTips -- tips born this frame start next frame
	local alive = false
	for t = 0, n - 1 do
		if tiR(p, t, 0) == 1 then
			for _ = 1, speed do
				if not stepTip(p, t) then
					tiW(p, t, 0, 0)
					break
				end
			end
			alive = alive or tiR(p, t, 0) == 1
		end
	end
	p.growing = alive or p.nTips > n
	p.frame += 1
	return p.nChanged, p.dx0, p.dy0, p.dx1, p.dy1
end

-- Run growth to completion (for tests / instant cracks).
function Fracture.grow(p: Panel, maxFrames: number?): number
	local f = 0
	repeat
		Fracture.step(p)
		f += 1
	until not p.growing or f >= (maxFrames or 1000)
	return f
end

-- Labelling -----------------------------------------------------------------------------------------------------

export type Region = { area: number, sx: number, sy: number, x0: number, y0: number, x1: number, y1: number, anchored: boolean }

-- 4-connected regions of (mask and not crack). Labels 1..n in p.label (0 = crack/outside).
function Fracture.label(p: Panel): { Region }
	local w, h, mask, crack, lab, st, anc = p.w, p.h, p.mask, p.crack, p.label, p.stack, p.anchor
	buffer.fill(lab, 0, 0)
	local regions: { Region } = {}
	local n = w * h
	for seed = 0, n - 1 do
		if buffer.readu8(mask, seed) == 0 or buffer.readu8(crack, seed) ~= 0 or buffer.readu32(lab, seed * 4) ~= 0 then
			continue
		end
		local id = #regions + 1
		local area, sx, sy, x0, y0, x1, y1, an = 0, 0, 0, w, h, -1, -1, false
		buffer.writeu32(lab, seed * 4, id)
		buffer.writeu32(st, 0, seed)
		local top = 1
		while top > 0 do
			top -= 1
			local i = buffer.readu32(st, top * 4)
			local x, y = i % w, i // w
			area += 1
			sx += x
			sy += y
			if x < x0 then
				x0 = x
			end
			if x > x1 then
				x1 = x
			end
			if y < y0 then
				y0 = y
			end
			if y > y1 then
				y1 = y
			end
			if buffer.readu8(anc, i) ~= 0 then
				an = true
			end
			-- push the 4 neighbours (each pixel is pushed once: labelled on push)
			if x > 0 then
				local j = i - 1
				if buffer.readu8(mask, j) ~= 0 and buffer.readu8(crack, j) == 0 and buffer.readu32(lab, j * 4) == 0 then
					buffer.writeu32(lab, j * 4, id)
					buffer.writeu32(st, top * 4, j)
					top += 1
				end
			end
			if x < w - 1 then
				local j = i + 1
				if buffer.readu8(mask, j) ~= 0 and buffer.readu8(crack, j) == 0 and buffer.readu32(lab, j * 4) == 0 then
					buffer.writeu32(lab, j * 4, id)
					buffer.writeu32(st, top * 4, j)
					top += 1
				end
			end
			if y > 0 then
				local j = i - w
				if buffer.readu8(mask, j) ~= 0 and buffer.readu8(crack, j) == 0 and buffer.readu32(lab, j * 4) == 0 then
					buffer.writeu32(lab, j * 4, id)
					buffer.writeu32(st, top * 4, j)
					top += 1
				end
			end
			if y < h - 1 then
				local j = i + w
				if buffer.readu8(mask, j) ~= 0 and buffer.readu8(crack, j) == 0 and buffer.readu32(lab, j * 4) == 0 then
					buffer.writeu32(lab, j * 4, id)
					buffer.writeu32(st, top * 4, j)
					top += 1
				end
			end
		end
		regions[id] = { area = area, sx = sx, sy = sy, x0 = x0, y0 = y0, x1 = x1, y1 = y1, anchored = an }
	end
	return regions
end

-- Meshing -----------------------------------------------------------------------------------------------------

-- Build the mesh of region `id` into frag (ContourMesh on a padded copy of its bbox).
local function meshRegion(p: Panel, id: number, frag: Fragment)
	local w, h, lab, crack, mask = p.w, p.h, p.label, p.crack, p.mask
	local f = p.field
	local x0, y0, x1, y1 = frag.bx0 - 2, frag.by0 - 2, frag.bx1 + 2, frag.by1 + 2
	local T = math.max(x1 - x0, y1 - y0) + 3
	local ox, oy = x0 - 1, y0 - 1 -- panel pixel (ox, oy) = tile sample (0, 0), always empty
	CM.reshape(f, T + 1, T + 1, T)
	f.depth = p.depth / p.cell
	f.epsilon = p.mat.epsilon
	local S = T + 1
	local fm = f.mask
	buffer.fill(fm, 0, 0, S * S)
	for y = math.max(0, y0), math.min(h - 1, y1) do
		for x = math.max(0, x0), math.min(w - 1, x1) do
			local i = y * w + x
			local v = 0
			if buffer.readu32(lab, i * 4) == id then
				v = 255
			elseif buffer.readu8(crack, i) ~= 0 and buffer.readu8(mask, i) ~= 0 then
				-- Crack pixel. If only this region lies within 2 px it is a dangling crack (it does not separate
				-- anything): mesh it as solid, else the outline would pinch into a zero-width slit. If it borders
				-- this region and another, sit just under the iso so the outline runs through its centre.
				local other, adj = false, false
				for dy = -2, 2 do
					local ny = y + dy
					if ny < 0 or ny >= h then
						continue
					end
					for dx = -2, 2 do
						local nx = x + dx
						if nx >= 0 and nx < w then
							local l = buffer.readu32(lab, (ny * w + nx) * 4)
							if l == id then
								if dx >= -1 and dx <= 1 and dy >= -1 and dy <= 1 then
									adj = true
								end
							elseif l ~= 0 then
								other = true
							end
						end
					end
				end
				if adj and not other then
					v = 255
				elseif adj then
					v = 127
				end
			end
			if v ~= 0 then
				buffer.writeu8(fm, (y - oy) * S + (x - ox), v)
			end
		end
	end
	local tile = CM.buildTile(f, 0, 0)
	local vc, tc = tile.vcount, tile.tcount
	local cell = p.cell
	local hw, hh = (w - 1) * 0.5, (h - 1) * 0.5
	local pos, uv = tile.pos, buffer.create(vc * 8)
	local cx, cy = frag.cx, frag.cy
	local rad = 0
	for v = 0, vc - 1 do
		local tx, ty, tz = buffer.readf32(pos, v * 12), buffer.readf32(pos, v * 12 + 4), buffer.readf32(pos, v * 12 + 8)
		local px, py = ox + tx, oy + (T - ty) -- panel pixel coords (pixel centres at integers)
		buffer.writef32(uv, v * 8, (px + 0.5) / w)
		buffer.writef32(uv, v * 8 + 4, (py + 0.5) / h)
		local X, Y, Z = (px - hw) * cell - cx, (hh - py) * cell - cy, tz * cell
		buffer.writef32(pos, v * 12, X)
		buffer.writef32(pos, v * 12 + 4, Y)
		buffer.writef32(pos, v * 12 + 8, Z)
		rad = math.max(rad, X * X + Y * Y + Z * Z)
	end
	frag.vcount, frag.tcount = vc, tc
	frag.pos, frag.uv, frag.idx, frag.nrm, frag.mat = pos, uv, tile.idx, tile.fnrm, tile.mat
	frag.radius = math.sqrt(rad)
	frag.loops = #tile.loops
end

-- Label the cracked panel and build one mesh per fragment. Fragments come back largest first.
-- defer = true skips meshing: call Fracture.buildMesh(p, frag) later (e.g. one per frame, right before
-- CreateMeshPartAsync); p.label must not change in between (no new fracture on this panel).
function Fracture.fracture(p: Panel, defer: boolean?): { Fragment }
	local m, w, h, cell = p.mat, p.w, p.h, p.cell
	local regions = Fracture.label(p)
	local hw, hh = (w - 1) * 0.5, (h - 1) * 0.5
	local hard = p.energy >= m.fractureEnergy
	local frags: { Fragment } = {}
	for id, r in regions do
		local anchored = r.anchored and (r.area >= m.anchorMin * p.maskArea or not hard)
		local kind = if anchored then "anchored" elseif r.area < m.dustArea then "dust" elseif r.area < m.debrisArea then "debris" else "loose"
		local cxp, cyp = r.sx / r.area, r.sy / r.area
		local frag: Fragment = {
			id = id,
			kind = kind,
			anchored = anchored,
			area = r.area,
			areaStuds = r.area * cell * cell,
			mass = r.area * cell * cell * p.depth * p.density,
			cx = (cxp - hw) * cell,
			cy = (hh - cyp) * cell,
			cz = 0,
			radius = 0,
			bx0 = r.x0,
			by0 = r.y0,
			bx1 = r.x1,
			by1 = r.y1,
			vcount = 0,
			tcount = 0,
			pos = nil,
			uv = nil,
			idx = nil,
			nrm = nil,
			mat = nil,
			loops = 0,
		}
		if kind ~= "dust" and not defer then
			meshRegion(p, id, frag)
		end
		table.insert(frags, frag)
	end
	table.sort(frags, function(a, b)
		return a.area > b.area or (a.area == b.area and a.id < b.id)
	end)
	return frags
end

function Fracture.buildMesh(p: Panel, frag: Fragment)
	if frag.kind ~= "dust" and not frag.pos then
		meshRegion(p, frag.id, frag)
	end
end

-- Deterministic launch for a detached fragment: velocity (studs/s) away from the impact and out of the far
-- face, falling off with distance, plus a spin (rad/s). Panel space (X right, Y up). side = the Z direction
-- the blast travels (-1 default: the impact hits the +Z face).
function Fracture.launch(p: Panel, frag: Fragment, seed: number, side: number?): (number, number, number, number, number, number)
	local m, cell = p.mat, p.cell
	local s = bit32.bor(bit32.band((frag.id * 7919 + seed * 104729) * 2654435761, 0xFFFFFFFF), 1)
	local function r(): number
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		return s / 4294967296
	end
	local ixw, iyw = (p.ix - (p.w - 1) * 0.5) * cell, ((p.h - 1) * 0.5 - p.iy) * cell
	local dx, dy = frag.cx - ixw, frag.cy - iyw
	local d = math.sqrt(dx * dx + dy * dy)
	local R0 = 0.3 * math.max(p.w, p.h) * cell
	local fall = 1 / (1 + (d / R0) ^ 2)
	local E = p.energy
	if d > 1e-6 then
		dx, dy = dx / d, dy / d
	else
		dx, dy = 0, 1
	end
	local small = math.clamp(math.sqrt(m.debrisArea / frag.area), 0.2, 1.8) -- small bits fly faster, slabs topple
	local sp = E * m.blast * (0.25 + 0.75 * fall) * (0.7 + 0.6 * r()) * small
	local vz = (side or -1) * E * m.push * (0.3 + 0.7 * fall) * (0.6 + 0.8 * r())
	local vx, vy = dx * sp, dy * sp + E * 2.5 * (0.5 + r())
	local ax, ay, az = r() - 0.5, r() - 0.5, r() - 0.5
	local al = math.sqrt(ax * ax + ay * ay + az * az) + 1e-9
	local spin = E * m.spin * (0.4 + 0.8 * r()) * small
	return vx, vy, vz, ax / al * spin, ay / al * spin, az / al * spin
end

-- ROBLOX ADAPTER ---------------------------------------------------------------------------------------------
-- Cannot run headless. API names per docs 20/21. Costs: WritePixelsBuffer of the dirty rect each crack frame
-- (one EditableImage refresh per frame); CreateMeshPartAsync ~22 ms each and it yields, so fragments are
-- created a few per frame from a queue (or pre-spawned while the cracks animate). Debris (< debrisArea px)
-- should use pooled generic rock MeshParts scaled to the bbox instead of CreateMeshPartAsync; dust becomes
-- particles. [UNVERIFIED] UV V origin (we pass 1 - v as ContourMesh notes); CreateMeshPartAsync re-centres on
-- the mesh bbox, so the part goes at centroid + em:GetCenter().
-- Flow: on hit, impact(); each Heartbeat step() + uploadDirty() (crack animation, ~0.1-0.5 ms + one upload);
-- when not p.growing, frags = fracture(p, true) (label only, ~3-16 ms), hide the intact wall, then a spawner
-- builds + creates 2 fragments per frame (~0.7-2 ms meshing each, CreateMeshPartAsync yields).

-- Wall texture: one EditableImage shared by the intact wall and every fragment (TextureContent).
function Fracture.newWallImage(AssetService: any, p: Panel): any
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(p.w, p.h) })
	if img then
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(p.w, p.h), p.rgba)
	end
	return img
end

-- Upload this step's dirty rect (from Fracture.step's return values). WritePixelsBuffer wants a buffer of
-- exactly w*h*4 bytes, so the rect is snapped to 16 px tiles and one buffer per snapped size is cached:
-- no allocation once the sizes seen so far are warm.
function Fracture.uploadDirty(img: any, p: Panel, x0: number, y0: number, x1: number, y1: number)
	if x1 < x0 then
		return
	end
	x0, y0 = x0 // 16 * 16, y0 // 16 * 16
	x1, y1 = math.min(p.w - 1, (x1 // 16 + 1) * 16 - 1), math.min(p.h - 1, (y1 // 16 + 1) * 16 - 1)
	local rw, rh = x1 - x0 + 1, y1 - y0 + 1
	local cache = p.uploadCache
	local key = rw * 65536 + rh
	local up = cache[key]
	if not up then
		up = buffer.create(rw * rh * 4)
		cache[key] = up
	end
	for y = 0, rh - 1 do
		buffer.copy(up, y * rw * 4, p.rgba, ((y0 + y) * p.w + x0) * 4, rw * 4)
	end
	img:WritePixelsBuffer(Vector2.new(x0, y0), Vector2.new(rw, rh), up)
end

function Fracture.toEditableMesh(em: any, frag: Fragment)
	local pos, uv, idx, nrm = frag.pos :: buffer, frag.uv :: buffer, frag.idx :: buffer, frag.nrm :: buffer
	local vc, tc = frag.vcount, frag.tcount
	local P, U, N = table.create(vc), table.create(vc), table.create(tc)
	for v = 0, vc - 1 do
		P[v + 1] = Vector3.new(buffer.readf32(pos, v * 12), buffer.readf32(pos, v * 12 + 4), buffer.readf32(pos, v * 12 + 8))
		U[v + 1] = Vector2.new(buffer.readf32(uv, v * 8), 1 - buffer.readf32(uv, v * 8 + 4))
	end
	for t = 0, tc - 1 do
		N[t + 1] = Vector3.new(buffer.readf32(nrm, t * 12), buffer.readf32(nrm, t * 12 + 4), buffer.readf32(nrm, t * 12 + 8))
	end
	local vids = em:BatchAdd(Enum.MeshAttribute.Vertex, P)
	local uids = em:BatchAdd(Enum.MeshAttribute.UV, U)
	local nids = em:BatchAdd(Enum.MeshAttribute.Normal, N)
	local F, FU, FN = table.create(tc), table.create(tc), table.create(tc)
	for t = 0, tc - 1 do
		local a, b, c = buffer.readu32(idx, t * 12) + 1, buffer.readu32(idx, t * 12 + 4) + 1, buffer.readu32(idx, t * 12 + 8) + 1
		F[t + 1] = { vids[a], vids[b], vids[c] }
		FU[t + 1] = { uids[a], uids[b], uids[c] } -- side walls reuse the edge texel: the crack shows on the break
		FN[t + 1] = { nids[t + 1], nids[t + 1], nids[t + 1] }
	end
	local fids = em:BatchAdd(Enum.MeshAttribute.Face, F)
	em:BatchSetFaceAttributes(fids, FU)
	em:BatchSetFaceAttributes(fids, FN)
	em:RemoveUnused()
end

-- Spawn fragments a few per frame (anchored remainder first: fragments are sorted largest first). Call
-- update() every Heartbeat until it returns true. wallCFrame: the intact wall's CFrame (hide that part when
-- the first pieces appear). side: blast direction along the wall's Z (see launch).
function Fracture.newSpawner(AssetService: any, p: Panel, frags: { Fragment }, wallCFrame: any, image: any, perFrame: number?, side: number?)
	local queue, qi, busy = {}, 1, 0
	for _, f in frags do
		if f.kind ~= "dust" then
			table.insert(queue, f)
		end
	end
	local self = {}
	function self.update(): boolean
		local n = perFrame or 2
		while n > 0 and qi <= #queue do
			local frag = queue[qi]
			qi += 1
			n -= 1
			busy += 1
			task.spawn(function()
				local em = AssetService:CreateEditableMesh()
				if not em then
					busy -= 1
					return -- budget exhausted: skip (or fall back to a pooled rock)
				end
				Fracture.buildMesh(p, frag) -- no-op unless fracture(p, true) deferred it
				Fracture.toEditableMesh(em, frag)
				local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
					CollisionFidelity = Enum.CollisionFidelity.Hull,
					RenderFidelity = Enum.RenderFidelity.Precise,
				})
				part.TextureContent = Content.fromObject(image)
				part.CFrame = wallCFrame * CFrame.new(frag.cx, frag.cy, 0) * CFrame.new(em:GetCenter())
				part.Anchored = frag.anchored
				part.Parent = workspace
				if not frag.anchored then
					local vx, vy, vz, wx, wy, wz = Fracture.launch(p, frag, 1, side)
					part.AssemblyLinearVelocity = wallCFrame:VectorToWorldSpace(Vector3.new(vx, vy, vz))
					part.AssemblyAngularVelocity = wallCFrame:VectorToWorldSpace(Vector3.new(wx, wy, wz))
				end
				busy -= 1
			end)
		end
		return qi > #queue and busy == 0
	end
	return self
end

return Fracture
