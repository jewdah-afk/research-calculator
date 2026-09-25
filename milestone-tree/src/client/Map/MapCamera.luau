--!strict
--[[
	MapCamera: the realm camera contract of art/camera.js, ported line for line (art/REALM.md sections 2, 5, 6).
	Pure Luau: no Roblox services and no requires, so the unit tests run it under plain luau against camera.js
	(port/tools/camera_cases.js -> port/tests/unit/map_camera.luau).

	The names and shapes follow camera.js: points are { x, y }, sizes { w, h }, all in map points (V, screen
	positions) or world / layer-local px (C, p). MapView converts to Vector2 at its edge. On top of camera.js this adds
	what the client chooses inside the contract (DESIGN.md 3.3, 3.5): the HUD-safe start framing, frameRect, the fly-to
	target on the free rect, SmoothDamp, and the whole-pixel tile edges of REALM.md 9.3.
]]

export type Pt = { x: number, y: number }
export type Size = { w: number, h: number }
export type Rect = { x: number, y: number, w: number, h: number }
export type Domain = { minW: number, minH: number, maxW: number, maxH: number, minAspect: number, maxAspect: number }
export type LayerDef = { f: number, w: number, h: number, ax: number?, ay: number? }
export type Scale = { scale: number, w: number, h: number, box: Size }
export type Limits = { x0: number, x1: number, y0: number, y1: number }
export type Cam = { x: number, y: number, z: number }
export type Weights = { rift: number, corrupt: number, cover: number }
export type Channel = { ch: string, type: string, amp: number?, period: number?, phase: number?, speed: number?,
	from: number?, to: number?, a: number?, b: number?, dur: number?, ease: string?, slot: number?, seed: number?,
	out: string? }
export type SpriteInst = { a: number?, m: { Channel }? }
export type SpriteState = { dx: number, dy: number, rot: number, scale: number, alpha: number, grad: number }
export type BiomeDef = {
	rift: { from: number, to: number },
	corrupt: { rect: { number }, cover: { number }, focus: { number }, light: { radius: { number }, falloff: { number } } },
}
export type Particle = { x: number, y: number, size: number, vx: number, vy: number, bx: number?, by: number?,
	bt: number?, bp: number?, a: number, ta: number?, tt: number?, tp: number?, tau: number }
export type FieldDef = { f: number, zHide: number, zShow: number, cell: { number }, maxSize: number, maxBob: number }
export type Placed = { i: number, x: number, y: number, size: number, alpha: number }
export type RGB = { number }

local MapCamera = {}

-- ------------------------------------------------------------------------------------------------ contract constants
-- realm.json repeats these (src/shared/Realm.luau camera); the unit test fails if they ever disagree.
local WORLD = table.freeze({ w = 3840, h = 2560, cx = 1920, cy = 1280 })
local Z_MAX = 1.25
local ZOOM_SLACK = 0.06
local OVERSCROLL = 72
-- the hard pan margin (world px): how far the visible rect may extend past each world edge, capped at half the view
local PAN_MARGIN: Pt = table.freeze({ x = 960, y = 720 })
local NO_MARGIN: Pt = table.freeze({ x = 0, y = 0 }) -- the world rect itself: the start camera (REALM.md 2.8)
local DOMAIN: Domain = table.freeze({ minW = 568, minH = 320, maxW = 2560, maxH = 1440, minAspect = 0.45, maxAspect = 3.6 })
MapCamera.WORLD, MapCamera.Z_MAX, MapCamera.ZOOM_SLACK, MapCamera.OVERSCROLL, MapCamera.DOMAIN =
	WORLD, Z_MAX, ZOOM_SLACK, OVERSCROLL, DOMAIN
MapCamera.PAN_MARGIN, MapCamera.NO_MARGIN = PAN_MARGIN, NO_MARGIN
local START: Pt = table.freeze({ x = 1500, y = 1150 })
MapCamera.START = START

local function clamp(x: number, a: number, b: number): number
	return if x < a then a elseif x > b then b else x
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
local function smoothstep(a: number, b: number, x: number): number
	local t = clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
local function mod(a: number, n: number): number
	return ((a % n) + n) % n
end
MapCamera.clamp, MapCamera.lerp, MapCamera.smoothstep, MapCamera.mod = clamp, lerp, smoothstep, mod

-- ------------------------------------------------------------------------------------------------ viewport
-- Map-point viewport for a device viewport: big screens scale up, tiny ones down, extreme aspects letterbox.
function MapCamera.mapScale(Vpx: Size, dom: Domain?): Scale
	local d = dom or DOMAIN
	local bw, bh = Vpx.w, Vpx.h
	if bw / bh > d.maxAspect then bw = bh * d.maxAspect end
	if bw / bh < d.minAspect then bh = bw / d.minAspect end
	local s = 1
	if bw > d.maxW or bh > d.maxH then
		s = math.max(bw / d.maxW, bh / d.maxH)
	elseif bw < d.minW or bh < d.minH then
		s = math.min(bw / d.minW, bh / d.minH)
	end
	return { scale = s, w = bw / s, h = bh / s, box = { w = bw, h = bh } }
end

-- ------------------------------------------------------------------------------------------------ zoom
-- the dolly law: a layer's scale is z / (f + (1 - f) z); depth order never flips at any zoom
local function layerZoom(f: number, z: number): number
	return z / (f + (1 - f) * z)
end
MapCamera.layerZoom = layerZoom
function MapCamera.layerZoomInverse(f: number, s: number): number
	return (s * f) / (1 - s * (1 - f))
end
-- the cover fit: the smallest zoom at which the world still fills the viewport
local function zMin(V: Size): number
	return math.min(Z_MAX, math.max(V.w / WORLD.w, V.h / WORLD.h))
end
MapCamera.zMin = zMin
local function zoomRange(V: Size, slack: boolean?): (number, number)
	local lo = zMin(V)
	local k = if slack then ZOOM_SLACK else 0
	return lo * (1 - k), Z_MAX * (1 + k)
end
MapCamera.zoomRange = zoomRange

-- ------------------------------------------------------------------------------------------------ layers
local function layerCenter(L: LayerDef, C: Pt): Pt
	local ax = if L.ax ~= nil then L.ax else L.w / 2
	local ay = if L.ay ~= nil then L.ay else L.h / 2
	return { x = ax + L.f * (C.x - WORLD.cx), y = ay + L.f * (C.y - WORLD.cy) }
end
MapCamera.layerCenter = layerCenter
-- the screen position of the layer's local (0, 0), its zoom, and its on-screen size
function MapCamera.layerOffset(L: LayerDef, C: Pt, z: number, V: Size): (number, number, number)
	local s = layerZoom(L.f, z)
	local P = layerCenter(L, C)
	return V.w / 2 - s * P.x, V.h / 2 - s * P.y, s
end
function MapCamera.visibleRect(L: LayerDef, C: Pt, z: number, V: Size): Limits
	local s = layerZoom(L.f, z)
	local P = layerCenter(L, C)
	local hw, hh = V.w / (2 * s), V.h / (2 * s)
	return { x0 = P.x - hw, y0 = P.y - hh, x1 = P.x + hw, y1 = P.y + hh }
end
local function localToScreen(L: LayerDef, C: Pt, z: number, V: Size, p: Pt): Pt
	local s = layerZoom(L.f, z)
	local P = layerCenter(L, C)
	return { x = V.w / 2 + s * (p.x - P.x), y = V.h / 2 + s * (p.y - P.y) }
end
MapCamera.localToScreen = localToScreen
function MapCamera.screenToLocal(L: LayerDef, C: Pt, z: number, V: Size, q: Pt): Pt
	local s = layerZoom(L.f, z)
	local P = layerCenter(L, C)
	return { x = P.x + (q.x - V.w / 2) / s, y = P.y + (q.y - V.h / 2) / s }
end
-- the world (f = 1, anchor = the world centre): q = Vc + z (p - C)
function MapCamera.worldToScreen(C: Pt, z: number, V: Size, p: Pt): Pt
	return { x = V.w / 2 + z * (p.x - C.x), y = V.h / 2 + z * (p.y - C.y) }
end
function MapCamera.screenToWorld(C: Pt, z: number, V: Size, q: Pt): Pt
	return { x = C.x + (q.x - V.w / 2) / z, y = C.y + (q.y - V.h / 2) / z }
end
-- camera centre after zooming z -> z2 about screen point S (the world point under S stays put)
function MapCamera.zoomAt(C: Pt, z: number, z2: number, S: Pt, V: Size): Pt
	local qx, qy = C.x + (S.x - V.w / 2) / z, C.y + (S.y - V.h / 2) / z
	return { x = qx - (S.x - V.w / 2) / z2, y = qy - (S.y - V.h / 2) / z2 }
end

-- ------------------------------------------------------------------------------------------------ clamping
-- range of camera centres at zoom z; overscroll in map points (the rubber band), 0 for the hard limit. On each axis
-- the visible rect may extend past the world by m = min(margin, half the view) world px (margin defaults to
-- PAN_MARGIN), so the centre ranges over [h - m, W - h + m] and never leaves the world; wider than W + 2m pins it
local function panLimits(z: number, V: Size, overscroll: number?, margin: Pt?): Limits
	local hw, hh, o = V.w / (2 * z), V.h / (2 * z), (overscroll or 0) / z
	local M = margin or PAN_MARGIN
	local mx, my = math.min(M.x, hw), math.min(M.y, hh)
	local ax0, ax1 = WORLD.cx, WORLD.cx
	if 2 * hw <= WORLD.w + 2 * mx then ax0, ax1 = hw - mx, WORLD.w - hw + mx end
	local ay0, ay1 = WORLD.cy, WORLD.cy
	if 2 * hh <= WORLD.h + 2 * my then ay0, ay1 = hh - my, WORLD.h - hh + my end
	return { x0 = ax0 - o, x1 = ax1 + o, y0 = ay0 - o, y1 = ay1 + o }
end
MapCamera.panLimits = panLimits
-- the hard clamp, or the rubber-band envelope (rubber = true); margin as in panLimits
local function clampCamera(C: Pt, z: number, V: Size, rubber: boolean?, margin: Pt?): Cam
	local lo, hi = zoomRange(V, rubber)
	local zz = clamp(z, lo, hi)
	local lim = panLimits(zz, V, if rubber then OVERSCROLL else 0, margin)
	return { x = clamp(C.x, lim.x0, lim.x1), y = clamp(C.y, lim.y0, lim.y1), z = zz }
end
MapCamera.clampCamera = clampCamera
-- the start zoom frames the whole tree (REALM.md 2.8)
local function startZoom(V: Size): number
	return clamp(math.min(V.w / 1500, V.h / 1750), zMin(V), 1)
end
MapCamera.startZoom = startZoom
-- the start camera: START at the start zoom, clamped to the world rect (no pan margin: the first view shows only the
-- world; the player pans into the margin from there)
function MapCamera.startCamera(V: Size): Cam
	return clampCamera(START, startZoom(V), V, false, NO_MARGIN)
end
-- iOS-style resistance: raw overshoot x (>= 0, map points) -> displayed overshoot, approaching d
function MapCamera.rubberBand(x: number, d: number?, c: number?): number
	local dd, cc = d or OVERSCROLL, c or 0.55
	return dd * (1 - 1 / (x * cc / dd + 1))
end

-- ------------------------------------------------------------------------------------------------ biome
-- share of the visible world rect that rect r = { x0, y0, x1, y1 } covers
local function viewCover(r: { number }, C: Pt, z: number, V: Size): number
	local hw, hh = V.w / (2 * z), V.h / (2 * z)
	local ix = math.max(0, math.min(C.x + hw, r[3]) - math.max(C.x - hw, r[1]))
	local iy = math.max(0, math.min(C.y + hh, r[4]) - math.max(C.y - hh, r[2]))
	return (ix * iy) / (4 * hw * hh)
end
MapCamera.viewCover = viewCover
-- biome weights: rift from the camera centre, corrupt from the share of the view the outcrop covers
function MapCamera.biome(C: Pt, B: BiomeDef, z: number, V: Size): Weights
	local rift = smoothstep(B.rift.from, B.rift.to, C.x)
	local c = B.corrupt
	local cover = viewCover(c.rect, C, z, V)
	local corrupt = rift * smoothstep(c.cover[1], c.cover[2], cover)
	return { rift = rift, corrupt = corrupt, cover = cover }
end
-- the outcrop's light at world point p, in [0, 1]
local function corruptLight(B: BiomeDef, p: Pt): number
	local c = B.corrupt
	local L = c.light
	local dx, dy = (p.x - c.focus[1]) / L.radius[1], (p.y - c.focus[2]) / L.radius[2]
	local d = math.sqrt(dx * dx + dy * dy)
	return 1 - smoothstep(L.falloff[1], L.falloff[2], d)
end
MapCamera.corruptLight = corruptLight
local function mixRGB(a: RGB, b: RGB, t: number): RGB
	return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) }
end
MapCamera.mixRGB = mixRGB
local WHITE: RGB = table.freeze({ 255, 255, 255 })
-- tile tint (multiply) of a layer with tint rift: mix(white, rift, w.rift); the world (no tint) stays white
function MapCamera.biomeTint(tintRift: RGB?, w: Weights): RGB
	return if tintRift then mixRGB(WHITE, tintRift, w.rift) else { 255, 255, 255 }
end
-- the full-screen wash between mid and near
function MapCamera.biomeWash(W: { realm: { color: RGB, alpha: number }, rift: { color: RGB, alpha: number } }, w: Weights): (RGB, number)
	return mixRGB(W.realm.color, W.rift.color, w.rift), lerp(W.realm.alpha, W.rift.alpha, w.rift)
end
-- a sprite with a colour { realm, rift, corrupt } over world point p
function MapCamera.biomeSpriteColor(color: { realm: RGB, rift: RGB, corrupt: RGB }, w: Weights, B: BiomeDef, p: Pt): RGB
	return mixRGB(mixRGB(color.realm, color.rift, w.rift), color.corrupt, w.corrupt * corruptLight(B, p))
end
-- a field particle (palette index c from 0, threshold cg) of a kind { palette, rift, corrupt } over world point p
function MapCamera.biomeFieldColor(kind: { palette: { RGB }, rift: RGB, corrupt: RGB }, c: number, cg: number, w: Weights,
	B: BiomeDef, p: Pt): RGB
	local g = w.corrupt * corruptLight(B, p)
	local base = mixRGB(kind.palette[(c % #kind.palette) + 1], kind.rift, w.rift)
	return mixRGB(base, kind.corrupt, smoothstep(math.max(0, cg - 0.12), math.min(1, cg + 0.12), g))
end
-- the draw alpha of a corrupt bloom (0 = hidden)
function MapCamera.bloomAlpha(alpha: number, w: Weights): number
	return alpha * w.corrupt
end

-- ------------------------------------------------------------------------------------------------ rng / hashing
-- mulberry32 on unsigned 32-bit words, bit-identical to camera.js rng (Math.imul, >>>, ^, |)
local TWO32 = 4294967296
local function u32(x: number): number
	x = if x >= 0 then math.floor(x) else math.ceil(x)
	return x - math.floor(x / TWO32) * TWO32
end
local function imul(a: number, b: number): number
	local ah, al = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	local bh, bl = bit32.rshift(b, 16), bit32.band(b, 0xFFFF)
	local mid = (ah * bl + al * bh) % 65536
	return (al * bl + mid * 65536) % TWO32
end
function MapCamera.rng(seed: number): () -> number
	local s = u32(seed)
	return function(): number
		s = u32(s + 0x6D2B79F5)
		local t = imul(bit32.bxor(s, bit32.rshift(s, 15)), bit32.bor(1, s))
		t = bit32.bxor(u32(t + imul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(61, t))), t)
		return bit32.bxor(t, bit32.rshift(t, 14)) / TWO32
	end
end
local function hash01(a: number, b: number?): number
	return MapCamera.rng(a * 374761393 + (b or 0) * 668265263)()
end
MapCamera.hash01 = hash01

-- ------------------------------------------------------------------------------------------------ motion
-- every channel is a closed form of time t; the client plays the same curves with TweenService (REALM.md 6.2)
local EASE: { [string]: (number) -> number } = {
	linear = function(u: number): number return u end,
	quadOut = function(u: number): number return 1 - (1 - u) * (1 - u) end,
	quintOut = function(u: number): number return 1 - (1 - u) ^ 5 end,
	sineInOut = function(u: number): number return -(math.cos(math.pi * u) - 1) / 2 end,
}
MapCamera.EASE = EASE
-- one channel -> the value to add to the base (x, y, rot, scale) or the absolute value (alpha, grad)
local function channel(m: Channel, t: number): number
	local ty = m.type
	local phase = m.phase or 0
	if ty == "sine" then
		return (m.amp or 0) * math.sin(2 * math.pi * (t / (m.period or 1) + phase))
	elseif ty == "drift" then
		local from, to = m.from or 0, m.to or 0
		local span = to - from
		return from + mod((m.speed or 0) * t + phase * span, span)
	elseif ty == "pulse" then
		local period, dur = m.period or 1, m.dur or 1
		local u = mod(t / period + phase, 1) * period
		local a, b = m.a or 0, m.b or 0
		return if u < dur then lerp(a, b, (EASE[m.ease or "quadOut"] or EASE.quadOut)(u / dur)) else b
	elseif ty == "scroll" then
		return -1 + 2 * mod(t / (m.period or 1) + phase, 1)
	elseif ty == "flicker" then
		local slot, dur, seed = m.slot or 1, m.dur or 0, m.seed or 0
		local k = math.floor(t / slot)
		local start = k * slot + hash01(seed, k) * (slot - dur)
		local on = if t >= start and t < start + dur then 1 else 0
		return if m.out == "jitter" then on * (hash01(seed + 1, k) - 0.5) * 2 * (m.amp or 0) else on
	end
	error("unknown motion type " .. tostring(ty))
end
MapCamera.channel = channel
-- all channels of a sprite instance
function MapCamera.spriteState(inst: SpriteInst, t: number): SpriteState
	local o = { dx = 0, dy = 0, rot = 0, scale = 1, alpha = if inst.a ~= nil then inst.a else 1, grad = 0 }
	local list: { Channel } = inst.m or {}
	for _, m in list do
		local v = channel(m, t)
		local ch = m.ch
		if ch == "x" then
			o.dx += v
		elseif ch == "y" then
			o.dy += v
		elseif ch == "rot" then
			o.rot += v
		elseif ch == "scale" then
			o.scale = if m.type == "pulse" then v else o.scale + v
		elseif ch == "alpha" then
			o.alpha = if m.type == "pulse" then v elseif m.type == "flicker" then o.alpha * v else o.alpha + v
		elseif ch == "grad" then
			o.grad = v
		end
	end
	o.alpha = clamp(o.alpha, 0, 1)
	return o
end

-- ------------------------------------------------------------------------------------------------ particle fields
-- a particle's local position inside the cell at time t (the drift wraps inside the cell: seamless)
local function fieldLocal(p: Particle, cw: number, ch: number, t: number): (number, number)
	local x = mod(p.x + p.vx * t, cw)
	local bx = p.bx
	if bx and bx ~= 0 then x += bx * math.sin(2 * math.pi * (t / (p.bt or 1) + (p.bp or 0))) end
	local y = mod(p.y + p.vy * t, ch)
	local by = p.by
	if by and by ~= 0 then y += by * math.sin(2 * math.pi * (t / (p.bt or 1) + (p.bp or 0) + 0.25)) end
	return x, y
end
MapCamera.fieldLocal = fieldLocal
-- Visit every on-screen copy of a field's particles for camera (C, z, V) at time t: visit(i, x, y, size, alpha) in
-- map points (i = the index in `particles`, size = diameter). A visit returning true stops the walk (pool full).
function MapCamera.fieldVisit(field: FieldDef, particles: { Particle }, C: Pt, z: number, V: Size, t: number,
	visit: (i: number, x: number, y: number, size: number, alpha: number) -> boolean?)
	local vis = smoothstep(field.zHide, field.zShow, z)
	if vis <= 0 then return end
	local s = layerZoom(field.f, z)
	-- the field layer has anchor (0, 0): P = f (C - Wc)
	local Px, Py = field.f * (C.x - WORLD.cx), field.f * (C.y - WORLD.cy)
	local hw, hh = V.w / (2 * s), V.h / (2 * s)
	local x0, x1, y0, y1 = Px - hw, Px + hw, Py - hh, Py + hh
	local cw, ch = field.cell[1], field.cell[2]
	local pad = field.maxSize / 2 + field.maxBob
	local i0, i1 = math.floor((x0 - pad) / cw), math.floor((x1 + pad) / cw)
	local j0, j1 = math.floor((y0 - pad) / ch), math.floor((y1 + pad) / ch)
	local vcx, vcy = V.w / 2, V.h / 2
	for k, p in particles do
		if z < p.tau then continue end
		local ta = p.ta
		local tw = if ta and ta ~= 0 then ta * math.sin(2 * math.pi * (t / (p.tt or 1) + (p.tp or 0))) else 0
		local a = vis * smoothstep(p.tau, p.tau * 1.12, z) * (p.a + tw)
		if a <= 0.004 then continue end
		local qx, qy = fieldLocal(p, cw, ch, t)
		local r = p.size / 2
		for i = i0, i1 do
			for j = j0, j1 do
				local lx, ly = i * cw + qx, j * ch + qy
				if lx + r < x0 or lx - r > x1 or ly + r < y0 or ly - r > y1 then continue end
				if visit(k, vcx + s * (lx - Px), vcy + s * (ly - Py), p.size * s, a) then return end
			end
		end
	end
end
-- camera.js fieldPlace: the list of placed copies (the reference form of fieldVisit)
function MapCamera.fieldPlace(field: FieldDef, particles: { Particle }, C: Pt, z: number, V: Size, t: number): { Placed }
	local out: { Placed } = {}
	MapCamera.fieldVisit(field, particles, C, z, V, t, function(i: number, x: number, y: number, size: number, alpha: number): boolean?
		table.insert(out, { i = i, x = x, y = y, size = size, alpha = alpha })
		return nil
	end)
	return out
end

-- ------------------------------------------------------------------------------------------------ client framing
-- (DESIGN.md 3.3, 3.5, REALM.md 9.4; not in camera.js: the client's choices inside the contract)

-- Unity's SmoothDamp for one scalar: critically damped spring toward target; returns (x, velocity)
function MapCamera.smoothDamp(x: number, target: number, vel: number, smoothTime: number, dt: number): (number, number)
	local st = math.max(0.0001, smoothTime)
	local omega = 2 / st
	local k = omega * dt
	local e = 1 / (1 + k + 0.48 * k * k + 0.235 * k * k * k)
	local change = x - target
	local temp = (vel + omega * change) * dt
	local v = (vel - omega * temp) * e
	local out = target + (change + temp) * e
	-- never overshoot the target
	if (target - x > 0) == (out > target) then
		out = target
		v = (out - target) / math.max(dt, 1e-6)
	end
	return out, v
end

-- The HUD-safe start (DESIGN.md 3.3, REALM.md 2.8). V = the Box in map points, safe = the part of it not under the
-- HUD bands (map points, Box-relative). WIDE / MEDIUM: the whole tree framed on the safe rect. COMPACT: the touch rest
-- zoom 0.34 around `focus` (the READY centroid, the last layer, or the trunk), placed `focusY` of the way down the
-- safe rect (0.5 = centred; a new player's M sits at 0.6). Returns (C, z) clamped to the world rect (NO_MARGIN, like
-- startCamera): the first view shows only the world.
function MapCamera.startFraming(V: Size, safe: Rect, mode: string, focus: Pt?, focusY: number?): (Pt, number)
	local lo = zMin(V)
	local z: number
	local target = focus or MapCamera.START
	if mode == "COMPACT" then
		z = clamp(0.34, lo, Z_MAX)
	else
		z = clamp(math.min(safe.w / 1500, safe.h / 1750), lo, 1)
	end
	-- the screen point where the target should land: the safe rect's centre (or focusY of the way down)
	local sx = safe.x + safe.w / 2
	local sy = safe.y + safe.h * (focusY or 0.5)
	local C = { x = target.x + (V.w / 2 - sx) / z, y = target.y + (V.h / 2 - sy) / z }
	local c = clampCamera(C, z, V, false, NO_MARGIN)
	return { x = c.x, y = c.y }, c.z
end
-- frameNodes: fit a world rect (the rings and plates of some nodes) into the safe rect; returns the hard-clamped (C, z)
function MapCamera.frameRect(bbox: Rect, V: Size, safe: Rect, zCap: number?): (Pt, number)
	local lo = zMin(V)
	local bw, bh = math.max(bbox.w, 1), math.max(bbox.h, 1)
	local z = clamp(math.min(safe.w / bw, safe.h / bh), lo, math.max(lo, zCap or 1))
	local cx, cy = bbox.x + bbox.w / 2, bbox.y + bbox.h / 2
	local sx, sy = safe.x + safe.w / 2, safe.y + safe.h / 2
	local c = clampCamera({ x = cx + (V.w / 2 - sx) / z, y = cy + (V.h / 2 - sy) / z }, z, V, false)
	return { x = c.x, y = c.y }, c.z
end
-- the fly-to target: node N at the centre of the free rect F (map points, Box-relative), at zoom z, hard-clamped
function MapCamera.flyTarget(N: Pt, z: number, V: Size, free: Rect?): (Pt, number)
	local fx = if free then free.x + free.w / 2 else V.w / 2
	local fy = if free then free.y + free.h / 2 else V.h / 2
	local c = clampCamera({ x = N.x + (V.w / 2 - fx) / z, y = N.y + (V.h / 2 - fy) / z }, z, V, false)
	return { x = c.x, y = c.y }, c.z
end

-- REALM.md 9.3: whole-device-pixel tile edges. edges = a layer's column (or row) edges in local px; o = the
-- container origin and s the layer zoom (map points); m = device px per map point. Writes out[i] and returns it.
function MapCamera.snapEdges(edges: { number }, m: number, o: number, s: number, out: { number }): { number }
	for i, x in edges do
		out[i] = math.round(m * (o + s * x))
	end
	return out
end

return MapCamera
