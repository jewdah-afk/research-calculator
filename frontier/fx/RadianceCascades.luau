--!native
--!optimize 2
-- 2D global illumination with Radiance Cascades (Sannikov 2023), CPU edition, real-time variant.
-- Scene: per-pixel solid mask + emission + albedo (walls, static emitters), plus up to 16 analytic
-- disc lights (setLight) that move for free: they are intersected exactly per ray segment.
-- 1. Exact Euclidean distance field (Felzenszwalb two-pass EDT) or JFA+1, clamped to maxDist so
--    an edit only changes the sdf within maxDist of it.
-- 2. Cascade i: probe spacing s0*2^i, 4^(i+1) rays, ray interval [L0(4^i-1)/3, L0(4^(i+1)-1)/3].
--    Every cascade has the same ray count, so cost is O(pixels/s0^2 * cascades).
-- 3. Bake (geometry only): every ray segment is sphere-traced once and its first hit pixel (or
--    CLEAR / OUT) is cached. Default "bilinear fix": one segment per bilinear upper probe, from
--    p + d*t0 to q + d*t1, so light cannot hop over walls. A small solid edit re-marches only the
--    segments that cross the changed sdf box beyond their cached hit (exact, see remarchBox).
-- 4. Gather: radiance = surf[hit] | sky | upper cascade (4 rays pre-averaged), disc lights tested
--    on the same segments; merge weights = bilinear * line-of-sight (cached). No marching.
-- 5. One light bounce per cycle: wall surface pixels re-emit albedo * neighbouring fluence.
-- 6. render() runs bake/gather/composite to completion. step(budgetMs) time-slices the same work
--    across frames into back buffers swapped in per cycle; moved lights also get a per-frame local
--    re-gather of cascades 0-1 around them. Idles once the scene has settled.
-- bakeBand/traceBand only write their own probe rows: the unit of work for Parallel Luau Actors.
-- Output: fluence (linear f32 RGB) and ACES-tonemapped RGBA8 with lit wall faces.

local RC = {}
RC.__index = RC

local INF = 1e12
local CLEAR = -1 -- segment reached its end: continue with the upper cascade (sky at the top)
local OUT = -2 -- segment left the frame: sky
local MAXL = 16 -- analytic lights
local GATHER, COMPOSITE = 1, 2

type Cascade = {
	spacing: number,
	nx: number,
	ny: number,
	rays: number,
	groups: number,
	segs: number, -- cached segments per ray: 4 (bilinear fix) or 1
	t0: number,
	t1: number,
	slack: number, -- max distance of any segment from its ray line (for angular culling)
	dirs: buffer, -- f32 (dx, dy) per ray
	avg: buffer, -- f32 RGB per (probe, group of 4 rays), probe-major (front: complete, displayed)
	back: buffer, -- same, written by the time-sliced cycle and swapped in when it completes
	vis: buffer, -- f32 x4 merge weights per probe (bilinear * line-of-sight to upper probe)
	hits: buffer, -- i32 per (probe, ray, segment): pixel index, CLEAR or OUT
}

export type RadianceCascades = typeof(setmetatable(
	{} :: {
		w: number,
		h: number,
		solid: buffer,
		emis: buffer,
		albedo: buffer,
		surf: buffer,
		sdf: buffer,
		fluence: buffer,
		flBack: buffer,
		rgbaBack: buffer,
		rgba: buffer,
		lut: buffer,
		edges: buffer,
		edgeCount: number,
		cascades: { Cascade },
		s0: number,
		exposure: number,
		bounce: number,
		fix: boolean,
		wallGain: number,
		wallAmbient: number,
		sky: { number },
		method: string,
		maxDist: number,
		editMargin: number,
		dirty: boolean,
		-- analytic lights: slot table (x, y, r, er, eg, eb, on) and the packed active list
		slots: buffer,
		lights: buffer,
		nl: number,
		lwin: buffer,
		lastL: buffer,
		lastN: number,
		localLevels: number,
		levelsNow: number,
		levelsCap: number,
		patchX0: number, -- pixel rect re-lit by this frame's light patch (empty when x1 <= x0)
		patchY0: number,
		patchX1: number,
		patchY1: number,
		rmask: buffer,
		-- incremental geometry / scheduler
		prevSolid: buffer,
		built: boolean,
		bakeAll: boolean,
		bakeC: number,
		bakeP: number,
		phase: number,
		curC: number,
		curRow: number,
		active: number,
		settle: number,
		stats: { [string]: number },
		-- scratch
		g: buffer,
		f1: buffer,
		d1: buffer,
		v1: buffer,
		z1: buffer,
		seedA: buffer,
		seedB: buffer,
		col: buffer,
		xtab: buffer,
	},
	RC
))

function RC.new(w: number, h: number, opts: { [string]: any }?): RadianceCascades
	local o = opts or {}
	local s0: number = o.spacing or 2
	local L0: number = o.interval or s0
	local fix: boolean = if o.fix == nil then true else o.fix
	local diag = math.sqrt(w * w + h * h)
	local cascades: { Cascade } = {}
	local i = 0
	while true do
		local spacing = s0 * 2 ^ i
		local nx, ny = math.ceil(w / spacing), math.ceil(h / spacing)
		local rays = 4 ^ (i + 1)
		local t0 = L0 * (4 ^ i - 1) / 3
		local t1 = L0 * (4 ^ (i + 1) - 1) / 3
		local last = t1 >= diag
		if last then
			t1 = diag + 1
		end
		local dirs = buffer.create(rays * 8)
		for r = 0, rays - 1 do
			local a = (r + 0.5) * 2 * math.pi / rays
			buffer.writef32(dirs, r * 8, math.cos(a))
			buffer.writef32(dirs, r * 8 + 4, math.sin(a))
		end
		local segs = if fix and not last then 4 else 1
		table.insert(cascades, {
			spacing = spacing,
			nx = nx,
			ny = ny,
			rays = rays,
			groups = rays // 4,
			segs = segs,
			t0 = t0,
			t1 = t1,
			slack = if segs == 4 then spacing * 2 * 1.5 + 1 else 0.5,
			dirs = dirs,
			avg = buffer.create(nx * ny * (rays // 4) * 12),
			back = buffer.create(nx * ny * (rays // 4) * 12),
			vis = buffer.create(nx * ny * 16),
			hits = buffer.create(nx * ny * rays * segs * 4),
		})
		if last then
			break
		end
		i += 1
	end
	local n = w * h
	local m = math.max(w, h)
	local lut = buffer.create(2048)
	for k = 0, 2047 do
		local x = k / 128 -- ACES fit (Narkowicz) then sRGB-ish gamma
		local y = math.clamp(x * (2.51 * x + 0.03) / (x * (2.43 * x + 0.59) + 0.14), 0, 1)
		buffer.writeu8(lut, k, math.floor(255 * y ^ (1 / 2.2) + 0.5))
	end
	-- per-column bilinear taps of cascade 0 for composite: qx0*12, qx1*12 (i32), fx (f32)
	local c0 = cascades[1]
	local xtab = buffer.create(w * 12)
	for x = 0, w - 1 do
		local vx = (x + 0.5) / s0 - 0.5
		local qx0 = math.floor(vx)
		local fx = vx - qx0
		local qx1 = qx0 + 1
		if qx0 < 0 then qx0 = 0 end
		if qx1 > c0.nx - 1 then qx1 = c0.nx - 1 end
		buffer.writei32(xtab, x * 12, qx0 * 12)
		buffer.writei32(xtab, x * 12 + 4, qx1 * 12)
		buffer.writef32(xtab, x * 12 + 8, fx)
	end
	local self = setmetatable({
		w = w,
		h = h,
		solid = buffer.create(n),
		emis = buffer.create(n * 12),
		albedo = buffer.create(n * 12),
		surf = buffer.create(n * 12),
		sdf = buffer.create(n * 4),
		fluence = buffer.create(n * 12),
		flBack = buffer.create(n * 12),
		rgbaBack = buffer.create(n * 4),
		rgba = buffer.create(n * 4),
		lut = lut,
		edges = buffer.create(n * 4),
		edgeCount = 0,
		cascades = cascades,
		s0 = s0,
		exposure = o.exposure or 1,
		bounce = o.bounce or 1,
		fix = fix,
		wallGain = o.wallGain or 1.5,
		wallAmbient = o.wallAmbient or 0.4,
		sky = o.sky or { 0, 0, 0 },
		method = o.method or "edt",
		maxDist = o.maxDist or 16,
		editMargin = o.editMargin or 2,
		dirty = true,
		slots = buffer.create(MAXL * 28),
		lights = buffer.create(MAXL * 28),
		nl = 0,
		lwin = buffer.create(MAXL * 12),
		lastL = buffer.create(MAXL * 28),
		lastN = 0,
		localLevels = o.localLevels or 2,
		levelsNow = o.localLevels or 2,
		levelsCap = o.localLevels or 2,
		patchX0 = 0,
		patchY0 = 0,
		patchX1 = 0,
		patchY1 = 0,
		rmask = buffer.create(cascades[#cascades].rays),
		prevSolid = buffer.create(n),
		built = false,
		bakeAll = true,
		bakeC = #cascades,
		bakeP = 0,
		phase = GATHER,
		curC = #cascades,
		curRow = 0,
		active = 0,
		settle = o.settle or 8,
		stats = { remarched = 0, partial = 0, full = 0 },
		g = buffer.create(n * 8),
		f1 = buffer.create(m * 8),
		d1 = buffer.create(m * 8),
		v1 = buffer.create(m * 4),
		z1 = buffer.create((m + 1) * 8),
		seedA = buffer.create(n * 4),
		seedB = buffer.create(n * 4),
		col = buffer.create(c0.nx * 12),
		xtab = xtab,
	}, RC)
	return self
end

-- Scene editing ---------------------------------------------------------------------------------

function RC.clear(self: RadianceCascades)
	buffer.fill(self.solid, 0, 0)
	buffer.fill(self.emis, 0, 0)
	buffer.fill(self.albedo, 0, 0)
	self.dirty = true
end

local function put(self: RadianceCascades, i: number, er: number, eg: number, eb: number, ar: number, ag: number, ab: number)
	buffer.writeu8(self.solid, i, 1)
	local e, a = self.emis, self.albedo
	buffer.writef32(e, i * 12, er)
	buffer.writef32(e, i * 12 + 4, eg)
	buffer.writef32(e, i * 12 + 8, eb)
	buffer.writef32(a, i * 12, ar)
	buffer.writef32(a, i * 12 + 4, ag)
	buffer.writef32(a, i * 12 + 8, ab)
end

-- Solid axis-aligned box [x0,x1) x [y0,y1) with emission (linear, >1 allowed) and albedo (0..1).
function RC.rect(self: RadianceCascades, x0: number, y0: number, x1: number, y1: number, er: number, eg: number, eb: number, ar: number?, ag: number?, ab: number?)
	local w = self.w
	for y = math.max(0, y0), math.min(self.h, y1) - 1 do
		for x = math.max(0, x0), math.min(w, x1) - 1 do
			put(self, y * w + x, er, eg, eb, ar or 0, ag or 0, ab or 0)
		end
	end
	self.dirty = true
end

function RC.circle(self: RadianceCascades, cx: number, cy: number, rad: number, er: number, eg: number, eb: number, ar: number?, ag: number?, ab: number?)
	local w = self.w
	local r2 = rad * rad
	for y = math.max(0, math.floor(cy - rad)), math.min(self.h - 1, math.ceil(cy + rad)) do
		for x = math.max(0, math.floor(cx - rad)), math.min(w - 1, math.ceil(cx + rad)) do
			local dx, dy = x + 0.5 - cx, y + 0.5 - cy
			if dx * dx + dy * dy <= r2 then
				put(self, y * w + x, er, eg, eb, ar or 0, ag or 0, ab or 0)
			end
		end
	end
	self.dirty = true
end

local function packLights(self: RadianceCascades)
	local slots, lights = self.slots, self.lights
	local k = 0
	for s = 0, MAXL - 1 do
		if buffer.readf32(slots, s * 28 + 24) ~= 0 then
			buffer.copy(lights, k * 28, slots, s * 28, 28)
			k += 1
		end
	end
	self.nl = k
	self.active = math.max(self.active, self.settle)
end

-- Analytic disc light (id 1..16): opaque emitter of radius `radius`, not part of the solid mask,
-- so moving it never touches the distance field or the ray cache.
function RC.setLight(self: RadianceCascades, id: number, x: number, y: number, radius: number, er: number, eg: number, eb: number)
	assert(id >= 1 and id <= MAXL, "light id 1..16")
	local o = (id - 1) * 28
	local s = self.slots
	buffer.writef32(s, o, x)
	buffer.writef32(s, o + 4, y)
	buffer.writef32(s, o + 8, radius)
	buffer.writef32(s, o + 12, er)
	buffer.writef32(s, o + 16, eg)
	buffer.writef32(s, o + 20, eb)
	buffer.writef32(s, o + 24, 1)
	packLights(self)
end

function RC.removeLight(self: RadianceCascades, id: number)
	buffer.writef32(self.slots, (id - 1) * 28 + 24, 0)
	packLights(self)
end

-- Distance field ---------------------------------------------------------------------------------

-- 1D squared distance transform of sampled function f (Felzenszwalb & Huttenlocher 2012).
local function edt1d(f: buffer, n: number, v: buffer, z: buffer, d: buffer)
	local k = 0
	buffer.writei32(v, 0, 0)
	buffer.writef64(z, 0, -math.huge)
	buffer.writef64(z, 8, math.huge)
	for q = 1, n - 1 do
		local fq = buffer.readf64(f, q * 8) + q * q
		local s = 0
		while true do
			local vk = buffer.readi32(v, k * 4)
			s = (fq - (buffer.readf64(f, vk * 8) + vk * vk)) / (2 * (q - vk))
			if s <= buffer.readf64(z, k * 8) then
				k -= 1
			else
				break
			end
		end
		k += 1
		buffer.writei32(v, k * 4, q)
		buffer.writef64(z, k * 8, s)
		buffer.writef64(z, (k + 1) * 8, math.huge)
	end
	k = 0
	for q = 0, n - 1 do
		while buffer.readf64(z, (k + 1) * 8) < q do
			k += 1
		end
		local vk = buffer.readi32(v, k * 4)
		buffer.writef64(d, q * 8, (q - vk) * (q - vk) + buffer.readf64(f, vk * 8))
	end
end

-- Clamped EDT for the window [x0,x1) x [y0,y1). Solids further than maxDist cannot matter, so the
-- transform runs over the window grown by maxDist+1 and matches a full-frame build exactly.
local function edtWindow(self: RadianceCascades, x0: number, y0: number, x1: number, y1: number)
	local w, h = self.w, self.h
	local solid, g, f1, d1, v1, z1, sdf = self.solid, self.g, self.f1, self.d1, self.v1, self.z1, self.sdf
	local md = self.maxDist
	local e = math.ceil(md) + 1
	local ex0, ey0, ex1, ey1 = math.max(0, x0 - e), math.max(0, y0 - e), math.min(w, x1 + e), math.min(h, y1 + e)
	local hh = ey1 - ey0
	for x = ex0, ex1 - 1 do
		for y = ey0, ey1 - 1 do
			buffer.writef64(f1, (y - ey0) * 8, if buffer.readu8(solid, y * w + x) ~= 0 then 0 else INF)
		end
		edt1d(f1, hh, v1, z1, d1)
		for y = y0, y1 - 1 do
			buffer.writef64(g, (y * w + x) * 8, buffer.readf64(d1, (y - ey0) * 8))
		end
	end
	local ww = ex1 - ex0
	for y = y0, y1 - 1 do
		buffer.copy(f1, 0, g, (y * w + ex0) * 8, ww * 8)
		edt1d(f1, ww, v1, z1, d1)
		for x = x0, x1 - 1 do
			buffer.writef32(sdf, (y * w + x) * 4, math.min(md, math.sqrt(buffer.readf64(d1, (x - ex0) * 8))))
		end
	end
end

-- Jump flooding alternative (JFA+1): log2(max(w,h))+1 passes of 9 taps. Approximate.
local function buildJFA(self: RadianceCascades)
	local w, h = self.w, self.h
	local n = w * h
	local solid = self.solid
	local a, b = self.seedA, self.seedB
	for i = 0, n - 1 do
		buffer.writeu32(a, i * 4, if buffer.readu8(solid, i) ~= 0 then i + 1 else 0)
	end
	local step = 1
	while step * 2 < math.max(w, h) do
		step *= 2
	end
	local extra = false
	while step >= 1 do
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local best = buffer.readu32(a, (y * w + x) * 4)
				local bd = INF
				if best > 0 then
					local sx, sy = (best - 1) % w - x, (best - 1) // w - y
					bd = sx * sx + sy * sy
				end
				for dy = -step, step, step do
					local ny = y + dy
					if ny >= 0 and ny < h then
						for dx = -step, step, step do
							local nx = x + dx
							if nx >= 0 and nx < w then
								local s = buffer.readu32(a, (ny * w + nx) * 4)
								if s > 0 then
									local sx, sy = (s - 1) % w - x, (s - 1) // w - y
									local d = sx * sx + sy * sy
									if d < bd then
										bd, best = d, s
									end
								end
							end
						end
					end
				end
				buffer.writeu32(b, (y * w + x) * 4, best)
			end
		end
		a, b = b, a
		if step == 1 and not extra then
			extra = true -- JFA+1: one more unit pass fixes most JFA errors
		else
			step //= 2
		end
	end
	local sdf, md = self.sdf, self.maxDist
	for i = 0, n - 1 do
		local s = buffer.readu32(a, i * 4)
		local d = INF
		if s > 0 then
			local sx, sy = (s - 1) % w - i % w, (s - 1) // w - i // w
			d = math.sqrt(sx * sx + sy * sy)
		end
		buffer.writef32(sdf, i * 4, math.min(md, d))
	end
end

-- Wall surface pixels: incoming = mean fluence of open 4-neighbours. Displayed as albedo * incoming,
-- and re-emitted next cycle as albedo * incoming * bounce (one bounce per cycle, converges).
local function shadeWalls(self: RadianceCascades, display: boolean)
	local w, n, solid, emis, albedo, surf, fl, edges, rgba, lut = self.w, self.w * self.h, self.solid, self.emis, self.albedo, self.surf, self.fluence, self.edges, self.rgba, self.lut
	local k = self.bounce
	local ex = self.exposure * 128 * self.wallGain
	for e = 0, self.edgeCount - 1 do
		local i = buffer.readu32(edges, e * 4)
		local o = i * 12
		local ar, ag, ab = buffer.readf32(albedo, o), buffer.readf32(albedo, o + 4), buffer.readf32(albedo, o + 8)
		local er, eg, eb = buffer.readf32(emis, o), buffer.readf32(emis, o + 4), buffer.readf32(emis, o + 8)
		if ar + ag + ab > 0 then
			local sr, sg, sb, c = 0, 0, 0, 0
			local x = i % w
			if x > 0 and buffer.readu8(solid, i - 1) == 0 then
				local q = (i - 1) * 12
				sr += buffer.readf32(fl, q); sg += buffer.readf32(fl, q + 4); sb += buffer.readf32(fl, q + 8); c += 1
			end
			if x < w - 1 and buffer.readu8(solid, i + 1) == 0 then
				local q = (i + 1) * 12
				sr += buffer.readf32(fl, q); sg += buffer.readf32(fl, q + 4); sb += buffer.readf32(fl, q + 8); c += 1
			end
			if i >= w and buffer.readu8(solid, i - w) == 0 then
				local q = (i - w) * 12
				sr += buffer.readf32(fl, q); sg += buffer.readf32(fl, q + 4); sb += buffer.readf32(fl, q + 8); c += 1
			end
			if i + w < n and buffer.readu8(solid, i + w) == 0 then
				local q = (i + w) * 12
				sr += buffer.readf32(fl, q); sg += buffer.readf32(fl, q + 4); sb += buffer.readf32(fl, q + 8); c += 1
			end
			sr, sg, sb = ar * sr / c, ag * sg / c, ab * sb / c
			buffer.writef32(surf, o, er + sr * k)
			buffer.writef32(surf, o + 4, eg + sg * k)
			buffer.writef32(surf, o + 8, eb + sb * k)
			if display and er + eg + eb == 0 then
				local ir, ig, ib = math.min(2047, sr * ex // 1), math.min(2047, sg * ex // 1), math.min(2047, sb * ex // 1)
				buffer.writeu32(rgba, i * 4, buffer.readu8(lut, ir) + buffer.readu8(lut, ig) * 256 + buffer.readu8(lut, ib) * 65536 + 0xFF000000)
			end
		end
	end
end

local function visible(sdf: buffer, w: number, h: number, ax: number, ay: number, bx: number, by: number): boolean
	bx, by = math.clamp(bx, 0, w - 0.01), math.clamp(by, 0, h - 0.01)
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)
	if len > 1e-6 then
		dx /= len
		dy /= len
	end
	local t = 0
	while true do
		if t > len then
			t = len
		end
		local x, y = ax + dx * t, ay + dy * t
		local d = buffer.readf32(sdf, ((y // 1) * w + x // 1) * 4)
		if d < 0.5 then
			return false
		end
		if t >= len then
			return true
		end
		t += if d > 1.5 then d - 1 else 0.5
	end
end

-- Merge weights for probes [px0,px1) x [py0,py1) of cascade ci: bilinear, zeroed for upper probes
-- hidden behind walls (stops light leaking into closed rooms), renormalised; plain bilinear when
-- every upper probe is hidden.
local function visRect(self: RadianceCascades, ci: number, px0: number, py0: number, px1: number, py1: number)
	local w, h, sdf, cs = self.w, self.h, self.sdf, self.cascades
	local c, up = cs[ci], cs[ci + 1]
	local nx, sp, vis = c.nx, c.spacing, c.vis
	local unx, uny, usp = up.nx, up.ny, up.spacing
	for py = py0, py1 - 1 do
		local oy = math.min((py + 0.5) * sp, h - 0.01)
		local vy = oy / usp - 0.5
		local qy0 = math.floor(vy)
		local fy = vy - qy0
		local qy1 = qy0 + 1
		for px = px0, px1 - 1 do
			local ox = math.min((px + 0.5) * sp, w - 0.01)
			local vx = ox / usp - 0.5
			local qx0 = math.floor(vx)
			local fx = vx - qx0
			local qx1 = qx0 + 1
			local w00, w10, w01, w11 = (1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy
			local o = (py * nx + px) * 16
			if buffer.readf32(sdf, ((oy // 1) * w + ox // 1) * 4) >= 0.5 then
				local cx0, cx1 = (math.clamp(qx0, 0, unx - 1) + 0.5) * usp, (math.clamp(qx1, 0, unx - 1) + 0.5) * usp
				local cy0, cy1 = (math.clamp(qy0, 0, uny - 1) + 0.5) * usp, (math.clamp(qy1, 0, uny - 1) + 0.5) * usp
				local v00 = if w00 > 0 and visible(sdf, w, h, ox, oy, cx0, cy0) then w00 else 0
				local v10 = if w10 > 0 and visible(sdf, w, h, ox, oy, cx1, cy0) then w10 else 0
				local v01 = if w01 > 0 and visible(sdf, w, h, ox, oy, cx0, cy1) then w01 else 0
				local v11 = if w11 > 0 and visible(sdf, w, h, ox, oy, cx1, cy1) then w11 else 0
				local sum = v00 + v10 + v01 + v11
				if sum > 1e-4 then
					w00, w10, w01, w11 = v00 / sum, v10 / sum, v01 / sum, v11 / sum
				end
			end
			buffer.writef32(vis, o, w00)
			buffer.writef32(vis, o + 4, w10)
			buffer.writef32(vis, o + 8, w01)
			buffer.writef32(vis, o + 12, w11)
		end
	end
end

-- Recompute merge weights of every probe whose line of sight could touch the pixel box.
local function visBox(self: RadianceCascades, x0: number, y0: number, x1: number, y1: number)
	local cs = self.cascades
	for ci = 1, #cs - 1 do
		local c = cs[ci]
		local sp, m = c.spacing, cs[ci + 1].spacing * 1.5 + 2
		local px0, py0 = math.max(0, math.floor((x0 - m) / sp)), math.max(0, math.floor((y0 - m) / sp))
		local px1, py1 = math.min(c.nx, math.ceil((x1 + m) / sp) + 1), math.min(c.ny, math.ceil((y1 + m) / sp) + 1)
		if px1 > px0 and py1 > py0 then
			visRect(self, ci, px0, py0, px1, py1)
		end
	end
end

-- Wall surface pixels (solid with an empty 4-neighbour).
local function buildEdges(self: RadianceCascades)
	local w, h, solid, edges = self.w, self.h, self.solid, self.edges
	local count = 0
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local i = y * w + x
			if buffer.readu8(solid, i) ~= 0 then
				local open = (x > 0 and buffer.readu8(solid, i - 1) == 0)
					or (x < w - 1 and buffer.readu8(solid, i + 1) == 0)
					or (y > 0 and buffer.readu8(solid, i - w) == 0)
					or (y < h - 1 and buffer.readu8(solid, i + w) == 0)
				if open then
					buffer.writeu32(edges, count * 4, i)
					count += 1
				end
			end
		end
	end
	self.edgeCount = count
end

-- Ray cache ---------------------------------------------------------------------------------------

-- Sphere trace the segment a->b: first solid pixel index, OUT (left the frame) or CLEAR.
local function marchHit(sdf: buffer, w: number, h: number, ax: number, ay: number, bx: number, by: number): number
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1e-6 then
		return CLEAR
	end
	dx /= len
	dy /= len
	local t = 0
	while t < len do
		local x, y = ax + dx * t, ay + dy * t
		if x < 0 or y < 0 or x >= w or y >= h then
			return OUT
		end
		local i = (y // 1) * w + x // 1
		local d = buffer.readf32(sdf, i * 4)
		if d < 0.5 then
			return i
		end
		t += if d > 1.5 then d - 1 else 0.5
	end
	return CLEAR
end

-- Probe centre and the four (clamped) upper bilinear probes: centres and indices.
local function probeGeom(c: Cascade, up: Cascade?, p: number): (number, number, number, number, number, number, number, number, number, number)
	local sp, nx = c.spacing, c.nx
	local ox, oy = (p % nx + 0.5) * sp, (p // nx + 0.5) * sp
	if not up then
		return ox, oy, ox, ox, oy, oy, 0, 0, 0, 0
	end
	local unx, uny, usp = up.nx, up.ny, up.spacing
	local qy0 = math.floor(oy / usp - 0.5)
	local qy1 = qy0 + 1
	if qy0 < 0 then qy0 = 0 end
	if qy1 > uny - 1 then qy1 = uny - 1 end
	if qy0 > uny - 1 then qy0 = uny - 1 end
	local qx0 = math.floor(ox / usp - 0.5)
	local qx1 = qx0 + 1
	if qx0 < 0 then qx0 = 0 end
	if qx1 > unx - 1 then qx1 = unx - 1 end
	if qx0 > unx - 1 then qx0 = unx - 1 end
	return ox, oy, (qx0 + 0.5) * usp, (qx1 + 0.5) * usp, (qy0 + 0.5) * usp, (qy1 + 0.5) * usp,
		qy0 * unx + qx0, qy0 * unx + qx1, qy1 * unx + qx0, qy1 * unx + qx1
end

local function bakeProbe(self: RadianceCascades, c: Cascade, up: Cascade?, p: number)
	local w, h, sdf = self.w, self.h, self.sdf
	local rays, segs, t0, t1, dirs, hits = c.rays, c.segs, c.t0, c.t1, c.dirs, c.hits
	local ox, oy, cx0, cx1, cy0, cy1 = probeGeom(c, up, p)
	-- longest bilinear-fix segment (|q - p| + interval length) plus pixel slack
	local reach = if up then (t1 - t0) + up.spacing * 1.415 + 1.5 else INF
	local base = p * rays * segs * 4
	for r = 0, rays - 1 do
		local dx, dy = buffer.readf32(dirs, r * 8), buffer.readf32(dirs, r * 8 + 4)
		local sx, sy = ox + dx * t0, oy + dy * t0
		local o = base + r * segs * 4
		if segs == 1 then
			buffer.writei32(hits, o, marchHit(sdf, w, h, sx, sy, ox + dx * t1, oy + dy * t1))
		elseif sx > reach and sy > reach and sx < w - reach and sy < h - reach
			and buffer.readf32(sdf, ((sy // 1) * w + sx // 1) * 4) > reach then
			-- every segment from here stays in empty space
			buffer.writei32(hits, o, CLEAR)
			buffer.writei32(hits, o + 4, CLEAR)
			buffer.writei32(hits, o + 8, CLEAR)
			buffer.writei32(hits, o + 12, CLEAR)
		else
			local ex, ey = dx * t1, dy * t1
			buffer.writei32(hits, o, marchHit(sdf, w, h, sx, sy, cx0 + ex, cy0 + ey))
			buffer.writei32(hits, o + 4, marchHit(sdf, w, h, sx, sy, cx1 + ex, cy0 + ey))
			buffer.writei32(hits, o + 8, marchHit(sdf, w, h, sx, sy, cx0 + ex, cy1 + ey))
			buffer.writei32(hits, o + 12, marchHit(sdf, w, h, sx, sy, cx1 + ex, cy1 + ey))
		end
	end
end

-- Rays of a probe whose segments can touch the disc (lx, ly, rad): returns first ray index and span
-- (inclusive, wraps), or -1 when none. A segment strays from its ray line by at most
-- slack * (tau - t0) / (t1 - t0) at distance tau, so near targets get tight windows.
local function rayWindow(ox: number, oy: number, lx: number, ly: number, rad: number, slack: number, t0: number, t1: number, rays: number): (number, number)
	local dx, dy = lx - ox, ly - oy
	local dd = math.sqrt(dx * dx + dy * dy)
	rad += slack * math.clamp((dd + rad - t0) / (t1 - t0), 0, 1)
	if dd - rad > t1 or dd + rad < t0 then
		return -1, 0
	end
	if dd <= rad then
		return 0, rays - 1
	end
	local half = math.asin(rad / dd)
	local th = math.atan2(dy, dx)
	local k = rays / (2 * math.pi)
	local lo = math.ceil((th - half) * k - 0.5)
	local hi = math.floor((th + half) * k - 0.5)
	if hi < lo then
		return -1, 0
	end
	return lo % rays, math.min(hi - lo, rays - 1)
end

-- Entry parameter (0..1) of segment a->b into box [x0,x1]x[y0,y1], or 2 if it misses (slab test).
local function boxEntry(ax: number, ay: number, bx: number, by: number, x0: number, y0: number, x1: number, y1: number): number
	local dx, dy = bx - ax, by - ay
	local lo, hi = 0, 1
	if math.abs(dx) < 1e-9 then
		if ax < x0 or ax > x1 then return 2 end
	else
		local u0, u1 = (x0 - ax) / dx, (x1 - ax) / dx
		if u0 > u1 then u0, u1 = u1, u0 end
		if u0 > lo then lo = u0 end
		if u1 < hi then hi = u1 end
	end
	if math.abs(dy) < 1e-9 then
		if ay < y0 or ay > y1 then return 2 end
	else
		local u0, u1 = (y0 - ay) / dy, (y1 - ay) / dy
		if u0 > u1 then u0, u1 = u1, u0 end
		if u0 > lo then lo = u0 end
		if u1 < hi then hi = u1 end
	end
	return if lo <= hi then lo else 2
end

-- Re-march one cached segment if it reaches the changed box before its cached hit. Samples before
-- the box saw an unchanged sdf, so every other segment is already exactly what a full bake gives.
local function remarchSeg(self: RadianceCascades, hits: buffer, o: number, ax: number, ay: number, bx: number, by: number, x0: number, y0: number, x1: number, y1: number, resume: boolean): number
	local u = boxEntry(ax, ay, bx, by, x0, y0, x1, y1)
	if u > 1 then
		return 0
	end
	local hh = buffer.readi32(hits, o)
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)
	if hh >= 0 then
		local th = ((hh % self.w + 0.5 - ax) * dx + (hh // self.w + 0.5 - ay) * dy) / len
		if th + 0.75 < u * len then
			return 0
		end
	end
	if resume then
		-- approximate mode: nothing was hit before the box, so start just before it
		local t = math.max(0, u - 1.5 / len)
		ax, ay = ax + dx * t, ay + dy * t
	end
	buffer.writei32(hits, o, marchHit(self.sdf, self.w, self.h, ax, ay, bx, by))
	return 1
end

-- Fix the ray cache after the sdf changed inside the pixel box [x0,x1) x [y0,y1).
local function remarchBox(self: RadianceCascades, x0: number, y0: number, x1: number, y1: number, resume: boolean)
	local cs = self.cascades
	local cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
	local brad = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) * 0.5
	local count = 0
	for ci = 1, #cs do
		local c, up = cs[ci], cs[ci + 1]
		local rays, segs, t0, t1, dirs, hits = c.rays, c.segs, c.t0, c.t1, c.dirs, c.hits
		for p = 0, c.nx * c.ny - 1 do
			local ox, oy, qx0, qx1, qy0, qy1 = probeGeom(c, up, p)
			local rlo, span = rayWindow(ox, oy, cx, cy, brad + 1, c.slack, t0 - 1, t1 + 1, rays)
			if rlo >= 0 then
				local base = p * rays * segs * 4
				for j = 0, span do
					local r = (rlo + j) % rays
					local dx, dy = buffer.readf32(dirs, r * 8), buffer.readf32(dirs, r * 8 + 4)
					local sx, sy = ox + dx * t0, oy + dy * t0
					local o = base + r * segs * 4
					if segs == 1 then
						count += remarchSeg(self, hits, o, sx, sy, ox + dx * t1, oy + dy * t1, x0, y0, x1, y1, resume)
					else
						local ex, ey = dx * t1, dy * t1
						count += remarchSeg(self, hits, o, sx, sy, qx0 + ex, qy0 + ey, x0, y0, x1, y1, resume)
						count += remarchSeg(self, hits, o + 4, sx, sy, qx1 + ex, qy0 + ey, x0, y0, x1, y1, resume)
						count += remarchSeg(self, hits, o + 8, sx, sy, qx0 + ex, qy1 + ey, x0, y0, x1, y1, resume)
						count += remarchSeg(self, hits, o + 12, sx, sy, qx1 + ex, qy1 + ey, x0, y0, x1, y1, resume)
					end
				end
			end
		end
	end
	self.stats.remarched = count
end

-- Gather --------------------------------------------------------------------------------------------

-- First analytic light on segment a->b in front of cached hit hh: packed light index + 1, or 0.
local function lightHit(lights: buffer, lwin: buffer, w: number, nw: number, r: number, rays: number, ax: number, ay: number, bx: number, by: number, hh: number): number
	local Dx, Dy = bx - ax, by - ay
	local a = Dx * Dx + Dy * Dy
	if a < 1e-12 then
		return 0
	end
	local bu = 1
	if hh >= 0 then
		bu = ((hh % w + 0.5 - ax) * Dx + (hh // w + 0.5 - ay) * Dy) / a
	end
	local best = 0
	for j = 0, nw - 1 do
		local dr = r - buffer.readi32(lwin, j * 12 + 4)
		if dr < 0 then
			dr += rays
		end
		if nw == 1 or dr <= buffer.readi32(lwin, j * 12 + 8) then
			local li = buffer.readi32(lwin, j * 12)
			local lo = li * 28
			local lr = buffer.readf32(lights, lo + 8)
			local fx, fy = ax - buffer.readf32(lights, lo), ay - buffer.readf32(lights, lo + 4)
			local cc = fx * fx + fy * fy - lr * lr
			local u = 2
			if cc <= 0 then
				u = 0
			else
				local b = fx * Dx + fy * Dy
				if b < 0 then
					local disc = b * b - a * cc
					if disc >= 0 then
						u = (-b - math.sqrt(disc)) / a
					end
				end
			end
			if u < bu then
				best, bu = li + 1, u
			end
		end
	end
	return best
end

-- lightHit for the 4 bilinear-fix segments of one ray (shared start a, ends e0..e3, hits h0..h3).
local function lightHit4(lights: buffer, lwin: buffer, w: number, nw: number, r: number, rays: number, ax: number, ay: number,
	e0x: number, e0y: number, e1x: number, e1y: number, e2x: number, e2y: number, e3x: number, e3y: number,
	h0: number, h1: number, h2: number, h3: number): (number, number, number, number)
	local d0x, d0y, d1x, d1y = e0x - ax, e0y - ay, e1x - ax, e1y - ay
	local d2x, d2y, d3x, d3y = e2x - ax, e2y - ay, e3x - ax, e3y - ay
	local a0, a1 = d0x * d0x + d0y * d0y + 1e-12, d1x * d1x + d1y * d1y + 1e-12
	local a2, a3 = d2x * d2x + d2y * d2y + 1e-12, d3x * d3x + d3y * d3y + 1e-12
	local u0, u1, u2, u3 = 1, 1, 1, 1
	if h0 >= 0 then u0 = ((h0 % w + 0.5 - ax) * d0x + (h0 // w + 0.5 - ay) * d0y) / a0 end
	if h1 >= 0 then u1 = ((h1 % w + 0.5 - ax) * d1x + (h1 // w + 0.5 - ay) * d1y) / a1 end
	if h2 >= 0 then u2 = ((h2 % w + 0.5 - ax) * d2x + (h2 // w + 0.5 - ay) * d2y) / a2 end
	if h3 >= 0 then u3 = ((h3 % w + 0.5 - ax) * d3x + (h3 // w + 0.5 - ay) * d3y) / a3 end
	local l0, l1, l2, l3 = 0, 0, 0, 0
	for j = 0, nw - 1 do
		local dr = r - buffer.readi32(lwin, j * 12 + 4)
		if dr < 0 then
			dr += rays
		end
		if nw == 1 or dr <= buffer.readi32(lwin, j * 12 + 8) then
			local li = buffer.readi32(lwin, j * 12)
			local lo = li * 28
			local lr = buffer.readf32(lights, lo + 8)
			local fx, fy = ax - buffer.readf32(lights, lo), ay - buffer.readf32(lights, lo + 4)
			local cc = fx * fx + fy * fy - lr * lr
			if cc <= 0 then -- start inside the disc
				if u0 > 0 then l0, u0 = li + 1, 0 end
				if u1 > 0 then l1, u1 = li + 1, 0 end
				if u2 > 0 then l2, u2 = li + 1, 0 end
				if u3 > 0 then l3, u3 = li + 1, 0 end
			else
				local b = fx * d0x + fy * d0y
				if b < 0 and b * b >= a0 * cc then
					local u = (-b - math.sqrt(b * b - a0 * cc)) / a0
					if u < u0 then l0, u0 = li + 1, u end
				end
				b = fx * d1x + fy * d1y
				if b < 0 and b * b >= a1 * cc then
					local u = (-b - math.sqrt(b * b - a1 * cc)) / a1
					if u < u1 then l1, u1 = li + 1, u end
				end
				b = fx * d2x + fy * d2y
				if b < 0 and b * b >= a2 * cc then
					local u = (-b - math.sqrt(b * b - a2 * cc)) / a2
					if u < u2 then l2, u2 = li + 1, u end
				end
				b = fx * d3x + fy * d3y
				if b < 0 and b * b >= a3 * cc then
					local u = (-b - math.sqrt(b * b - a3 * cc)) / a3
					if u < u3 then l3, u3 = li + 1, u end
				end
			end
		end
	end
	return l0, l1, l2, l3
end

-- Band functions: probe rows [row0, row1) of cascade ci. Each writes only its own rows of
-- c.hits (bake) or c.avg (trace), so bands can run on separate Actors (see the adapter below).
function RC.bakeBand(self: RadianceCascades, ci: number, row0: number, row1: number)
	local c, up = self.cascades[ci], self.cascades[ci + 1]
	for p = row0 * c.nx, row1 * c.nx - 1 do
		bakeProbe(self, c, up, p)
	end
end

-- Gather probes [px0,px1) x [py0,py1) of cascade ci: no marching, only cached hits, surf, the
-- upper cascade and the analytic lights.
local function gatherRect(self: RadianceCascades, ci: number, px0: number, py0: number, px1: number, py1: number, back: boolean)
	local cs = self.cascades
	local c, up = cs[ci], cs[ci + 1]
	local surf, lights, lwin, rmask, w = self.surf, self.lights, self.lwin, self.rmask, self.w
	local nx, sp, rays, groups, segs, t0, t1, dirs, hits, avg, vis, slack = c.nx, c.spacing, c.rays, c.groups, c.segs, c.t0, c.t1, c.dirs, c.hits, c.avg, c.vis, c.slack
	local skyR, skyG, skyB = self.sky[1], self.sky[2], self.sky[3]
	local nl = self.nl
	if back then
		avg = c.back
	end
	local uavg, unx, uny, usp = avg, 1, 1, 1
	if up then
		uavg, unx, uny, usp = if back then up.back else up.avg, up.nx, up.ny, up.spacing
	end
	local stride = rays * 12 -- upper probe stride in avg (up.groups == rays)
	for py = py0, py1 - 1 do
		local oy = (py + 0.5) * sp
		local qy0 = math.floor(oy / usp - 0.5)
		local qy1 = qy0 + 1
		if qy0 < 0 then qy0 = 0 end
		if qy1 > uny - 1 then qy1 = uny - 1 end
		if qy0 > uny - 1 then qy0 = uny - 1 end
		local cy0, cy1 = (qy0 + 0.5) * usp, (qy1 + 0.5) * usp
		for px = px0, px1 - 1 do
			local p = py * nx + px
			local ox = (px + 0.5) * sp
			local qx0 = math.floor(ox / usp - 0.5)
			local qx1 = qx0 + 1
			if qx0 < 0 then qx0 = 0 end
			if qx1 > unx - 1 then qx1 = unx - 1 end
			if qx0 > unx - 1 then qx0 = unx - 1 end
			local cx0, cx1 = (qx0 + 0.5) * usp, (qx1 + 0.5) * usp
			local b00, b10 = (qy0 * unx + qx0) * stride, (qy0 * unx + qx1) * stride
			local b01, b11 = (qy1 * unx + qx0) * stride, (qy1 * unx + qx1) * stride
			local w00, w10, w01, w11 = 0, 0, 0, 0
			if up then
				local vo = p * 16
				w00, w10 = buffer.readf32(vis, vo), buffer.readf32(vis, vo + 4)
				w01, w11 = buffer.readf32(vis, vo + 8), buffer.readf32(vis, vo + 12)
			end
			-- rays that can meet an analytic light: windows in lwin, flags in rmask
			local nw = 0
			if nl > 0 then
				for li = 0, nl - 1 do
					local lo = li * 28
					local rlo, span = rayWindow(ox, oy, buffer.readf32(lights, lo), buffer.readf32(lights, lo + 4), buffer.readf32(lights, lo + 8) + 0.5, slack, t0, t1, rays)
					if rlo >= 0 then
						if nw == 0 then
							buffer.fill(rmask, 0, 0, rays)
						end
						buffer.writei32(lwin, nw * 12, li)
						buffer.writei32(lwin, nw * 12 + 4, rlo)
						buffer.writei32(lwin, nw * 12 + 8, span)
						nw += 1
						for j = 0, span do
							buffer.writeu8(rmask, (rlo + j) % rays, 1)
						end
					end
				end
			end
			local outBase = p * groups * 12
			local hbase = p * rays * segs * 4
			for g = 0, groups - 1 do
				local ar, ag, ab = 0, 0, 0
				for k = 0, 3 do
					local r = g * 4 + k
					local o = hbase + r * segs * 4
					local u = r * 12
					local lit = nw > 0 and buffer.readu8(rmask, r) ~= 0
					if segs == 1 then
						local hh = buffer.readi32(hits, o)
						local cr, cg, cb = skyR, skyG, skyB
						if hh >= 0 then
							cr, cg, cb = buffer.readf32(surf, hh * 12), buffer.readf32(surf, hh * 12 + 4), buffer.readf32(surf, hh * 12 + 8)
						elseif hh == CLEAR and up then
							cr = w00 * buffer.readf32(uavg, u + b00) + w10 * buffer.readf32(uavg, u + b10)
								+ w01 * buffer.readf32(uavg, u + b01) + w11 * buffer.readf32(uavg, u + b11)
							cg = w00 * buffer.readf32(uavg, u + b00 + 4) + w10 * buffer.readf32(uavg, u + b10 + 4)
								+ w01 * buffer.readf32(uavg, u + b01 + 4) + w11 * buffer.readf32(uavg, u + b11 + 4)
							cb = w00 * buffer.readf32(uavg, u + b00 + 8) + w10 * buffer.readf32(uavg, u + b10 + 8)
								+ w01 * buffer.readf32(uavg, u + b01 + 8) + w11 * buffer.readf32(uavg, u + b11 + 8)
						end
						if lit then
							local dx, dy = buffer.readf32(dirs, r * 8), buffer.readf32(dirs, r * 8 + 4)
							local l = lightHit(lights, lwin, w, nw, r, rays, ox + dx * t0, oy + dy * t0, ox + dx * t1, oy + dy * t1, hh)
							if l > 0 then
								local lo = (l - 1) * 28
								cr, cg, cb = buffer.readf32(lights, lo + 12), buffer.readf32(lights, lo + 16), buffer.readf32(lights, lo + 20)
							end
						end
						ar += cr; ag += cg; ab += cb
					else
						local h00, h10 = buffer.readi32(hits, o), buffer.readi32(hits, o + 4)
						local h01, h11 = buffer.readi32(hits, o + 8), buffer.readi32(hits, o + 12)
						local r00, g00, c00 = skyR, skyG, skyB
						local r10, g10, c10 = skyR, skyG, skyB
						local r01, g01, c01 = skyR, skyG, skyB
						local r11, g11, c11 = skyR, skyG, skyB
						if h00 >= 0 then
							r00, g00, c00 = buffer.readf32(surf, h00 * 12), buffer.readf32(surf, h00 * 12 + 4), buffer.readf32(surf, h00 * 12 + 8)
						elseif h00 == CLEAR then
							r00, g00, c00 = buffer.readf32(uavg, u + b00), buffer.readf32(uavg, u + b00 + 4), buffer.readf32(uavg, u + b00 + 8)
						end
						if h10 >= 0 then
							r10, g10, c10 = buffer.readf32(surf, h10 * 12), buffer.readf32(surf, h10 * 12 + 4), buffer.readf32(surf, h10 * 12 + 8)
						elseif h10 == CLEAR then
							r10, g10, c10 = buffer.readf32(uavg, u + b10), buffer.readf32(uavg, u + b10 + 4), buffer.readf32(uavg, u + b10 + 8)
						end
						if h01 >= 0 then
							r01, g01, c01 = buffer.readf32(surf, h01 * 12), buffer.readf32(surf, h01 * 12 + 4), buffer.readf32(surf, h01 * 12 + 8)
						elseif h01 == CLEAR then
							r01, g01, c01 = buffer.readf32(uavg, u + b01), buffer.readf32(uavg, u + b01 + 4), buffer.readf32(uavg, u + b01 + 8)
						end
						if h11 >= 0 then
							r11, g11, c11 = buffer.readf32(surf, h11 * 12), buffer.readf32(surf, h11 * 12 + 4), buffer.readf32(surf, h11 * 12 + 8)
						elseif h11 == CLEAR then
							r11, g11, c11 = buffer.readf32(uavg, u + b11), buffer.readf32(uavg, u + b11 + 4), buffer.readf32(uavg, u + b11 + 8)
						end
						if lit then
							local dx, dy = buffer.readf32(dirs, r * 8), buffer.readf32(dirs, r * 8 + 4)
							local sx, sy = ox + dx * t0, oy + dy * t0
							dx *= t1
							dy *= t1
							local l0, l1, l2, l3 = lightHit4(lights, lwin, w, nw, r, rays, sx, sy,
								cx0 + dx, cy0 + dy, cx1 + dx, cy0 + dy, cx0 + dx, cy1 + dy, cx1 + dx, cy1 + dy, h00, h10, h01, h11)
							if l0 > 0 then
								local lo = (l0 - 1) * 28
								r00, g00, c00 = buffer.readf32(lights, lo + 12), buffer.readf32(lights, lo + 16), buffer.readf32(lights, lo + 20)
							end
							if l1 > 0 then
								local lo = (l1 - 1) * 28
								r10, g10, c10 = buffer.readf32(lights, lo + 12), buffer.readf32(lights, lo + 16), buffer.readf32(lights, lo + 20)
							end
							if l2 > 0 then
								local lo = (l2 - 1) * 28
								r01, g01, c01 = buffer.readf32(lights, lo + 12), buffer.readf32(lights, lo + 16), buffer.readf32(lights, lo + 20)
							end
							if l3 > 0 then
								local lo = (l3 - 1) * 28
								r11, g11, c11 = buffer.readf32(lights, lo + 12), buffer.readf32(lights, lo + 16), buffer.readf32(lights, lo + 20)
							end
						end
						ar += w00 * r00 + w10 * r10 + w01 * r01 + w11 * r11
						ag += w00 * g00 + w10 * g10 + w01 * g01 + w11 * g11
						ab += w00 * c00 + w10 * c10 + w01 * c01 + w11 * c11
					end
				end
				local o = outBase + g * 12
				buffer.writef32(avg, o, ar * 0.25)
				buffer.writef32(avg, o + 4, ag * 0.25)
				buffer.writef32(avg, o + 8, ab * 0.25)
			end
		end
	end
end

function RC.traceBand(self: RadianceCascades, ci: number, row0: number, row1: number, back: boolean?)
	gatherRect(self, ci, 0, row0, self.cascades[ci].nx, row1, back == true)
end

-- Upsample cascade-0 radiance `avg` to pixels [x0,x1) x [y0,y1) of fl/rgba (separable bilinear)
-- and tonemap. patch (light refresh): leave solid pixels alone, shadeWalls owns their lit faces.
local function compositeRows(self: RadianceCascades, avg: buffer, fl: buffer, rgba: buffer, y0: number, y1: number, x0: number, x1: number, patch: boolean)
	local w, lut, solid, emis, albedo, col, xtab = self.w, self.lut, self.solid, self.emis, self.albedo, self.col, self.xtab
	local amb = self.wallAmbient
	local c = self.cascades[1]
	local nx, ny, sp = c.nx, c.ny, c.spacing
	local ex = self.exposure * 128
	for y = y0, y1 - 1 do
		local vy = (y + 0.5) / sp - 0.5
		local qy0 = math.floor(vy)
		local fy = vy - qy0
		local qy1 = qy0 + 1
		if qy0 < 0 then qy0 = 0 end
		if qy1 > ny - 1 then qy1 = ny - 1 end
		local a0, a1 = qy0 * nx * 12, qy1 * nx * 12
		local gy = 1 - fy
		for o = 0, (nx - 1) * 12, 12 do
			buffer.writef32(col, o, gy * buffer.readf32(avg, a0 + o) + fy * buffer.readf32(avg, a1 + o))
			buffer.writef32(col, o + 4, gy * buffer.readf32(avg, a0 + o + 4) + fy * buffer.readf32(avg, a1 + o + 4))
			buffer.writef32(col, o + 8, gy * buffer.readf32(avg, a0 + o + 8) + fy * buffer.readf32(avg, a1 + o + 8))
		end
		for x = x0, x1 - 1 do
			local k0, k1, fx = buffer.readi32(xtab, x * 12), buffer.readi32(xtab, x * 12 + 4), buffer.readf32(xtab, x * 12 + 8)
			local gx = 1 - fx
			local r = gx * buffer.readf32(col, k0) + fx * buffer.readf32(col, k1)
			local g = gx * buffer.readf32(col, k0 + 4) + fx * buffer.readf32(col, k1 + 4)
			local b = gx * buffer.readf32(col, k0 + 8) + fx * buffer.readf32(col, k1 + 8)
			local i = y * w + x
			local o = i * 12
			if patch and buffer.readu8(solid, i) ~= 0 then
				continue
			end
			buffer.writef32(fl, o, r)
			buffer.writef32(fl, o + 4, g)
			buffer.writef32(fl, o + 8, b)
			if buffer.readu8(solid, i) ~= 0 then
				if buffer.readf32(emis, o) + buffer.readf32(emis, o + 4) + buffer.readf32(emis, o + 8) == 0 then
					-- wall body (surface pixels are overwritten by shadeWalls)
					r, g, b = buffer.readf32(albedo, o) * amb, buffer.readf32(albedo, o + 4) * amb, buffer.readf32(albedo, o + 8) * amb
				end
			end
			local ir, ig, ib = math.min(2047, r * ex // 1), math.min(2047, g * ex // 1), math.min(2047, b * ex // 1)
			buffer.writeu32(rgba, i * 4, buffer.readu8(lut, ir) + buffer.readu8(lut, ig) * 256 + buffer.readu8(lut, ib) * 65536 + 0xFF000000)
		end
	end
end

-- Scene update ----------------------------------------------------------------------------------------

-- Full rebuild: distance field, wall surface list, merge weights; the ray cache is marked stale.
function RC.buildScene(self: RadianceCascades)
	if self.method == "jfa" then
		buildJFA(self)
	else
		edtWindow(self, 0, 0, self.w, self.h)
	end
	buildEdges(self)
	buffer.copy(self.surf, 0, self.emis)
	shadeWalls(self, false) -- keep last frame's bounce light on the rebuilt walls
	local cs = self.cascades
	for ci = 1, #cs - 1 do
		visRect(self, ci, 0, 0, cs[ci].nx, cs[ci].ny)
	end
	buffer.copy(self.prevSolid, 0, self.solid)
	self.built = true
	self.bakeAll = true
	self.bakeC, self.bakeP = #cs, 0
	self.dirty = false
	self.stats.full += 1
end

-- Bounding box [x0,x1) x [y0,y1) of solid pixels that changed since the last build, or nil.
local function diffBox(self: RadianceCascades): (number?, number, number, number)
	local a, b, w, n = self.solid, self.prevSolid, self.w, self.w * self.h
	local x0, y0, x1, y1 = math.huge, math.huge, -1, -1
	local words = n // 4
	for i = 0, words - 1 do
		if buffer.readu32(a, i * 4) ~= buffer.readu32(b, i * 4) then
			for j = i * 4, i * 4 + 3 do
				if buffer.readu8(a, j) ~= buffer.readu8(b, j) then
					local x, y = j % w, j // w
					if x < x0 then x0 = x end
					if x > x1 then x1 = x end
					if y < y0 then y0 = y end
					if y > y1 then y1 = y end
				end
			end
		end
	end
	for j = words * 4, n - 1 do
		if buffer.readu8(a, j) ~= buffer.readu8(b, j) then
			local x, y = j % w, j // w
			x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
		end
	end
	if x1 < 0 then
		return nil, 0, 0, 0
	end
	return x0, y0, x1 + 1, y1 + 1
end

-- Incremental scene update after rect/circle/clear: nothing for an identical solid mask (only
-- emission/albedo changed), a local sdf/weights/ray-cache fix for a small edit, else a full rebuild.
local function updateGeometry(self: RadianceCascades)
	if not self.built or self.method == "jfa" then
		self:buildScene()
		return
	end
	self.dirty = false
	local x0, y0, x1, y1 = diffBox(self)
	if x0 == nil then
		buffer.copy(self.surf, 0, self.emis)
		shadeWalls(self, false)
		return
	end
	local w, h = self.w, self.h
	if (x1 - x0) * (y1 - y0) * 8 > w * h then
		self:buildScene()
		return
	end
	local e = math.ceil(self.maxDist) + 1
	edtWindow(self, math.max(0, x0 - e), math.max(0, y0 - e), math.min(w, x1 + e), math.min(h, y1 + e))
	buildEdges(self)
	buffer.copy(self.surf, 0, self.emis)
	shadeWalls(self, false)
	-- ray cache / weights: bit-exact needs the whole changed-sdf box (margin maxDist+1); a margin of
	-- 2 px already re-marches every segment that touches changed solids (hits stay geometrically right)
	local m = math.min(e, self.editMargin)
	local rx0, ry0, rx1, ry1 = math.max(0, x0 - m), math.max(0, y0 - m), math.min(w, x1 + m), math.min(h, y1 + m)
	visBox(self, rx0, ry0, rx1, ry1)
	remarchBox(self, rx0, ry0, rx1, ry1, m < e)
	buffer.copy(self.prevSolid, 0, self.solid)
	self.stats.partial += 1
end

-- Frame drivers -------------------------------------------------------------------------------------

-- Full quality frame: scene update, any pending bake, every cascade top-down, composite, bounce.
function RC.render(self: RadianceCascades)
	if self.dirty then
		updateGeometry(self)
	end
	local cs = self.cascades
	if self.bakeAll then
		for ci = #cs, 1, -1 do
			RC.bakeBand(self, ci, 0, cs[ci].ny)
		end
		self.bakeAll = false
	end
	for ci = #cs, 1, -1 do
		RC.traceBand(self, ci, 0, cs[ci].ny)
	end
	compositeRows(self, cs[1].avg, self.fluence, self.rgba, 0, self.h, 0, self.w, false)
	shadeWalls(self, true)
	buffer.copy(self.lastL, 0, self.lights, 0, self.nl * 28) -- lights are current: no patch needed
	self.lastN = self.nl
	self.phase, self.curC, self.curRow = GATHER, #cs, 0
	self.active = math.max(0, self.active - 1)
end

-- Moved lights: re-gather the lowest `localLevels` cascades (front buffers) around each light's old
-- and new position and re-composite that patch, so the bright core tracks the light every frame.
-- The patch reads the same front upper cascades as its surroundings, so it has no seam; the far
-- field catches up when the next cycle is swapped in.
local function refreshRect(self: RadianceCascades, levels: number, x0: number, y0: number, x1: number, y1: number)
	local cs = self.cascades
	-- level ci covers probes that see the light, plus those merging a refreshed upper probe
	local rr = 0
	for ci = math.min(levels, #cs), 1, -1 do
		local c = cs[ci]
		local sp = c.spacing
		rr = math.max(c.t1 + c.slack + 1, if rr > 0 then rr + 2 * sp else 0)
		local px0, py0 = math.max(0, math.floor((x0 - rr) / sp)), math.max(0, math.floor((y0 - rr) / sp))
		local px1, py1 = math.min(c.nx, math.ceil((x1 + rr) / sp)), math.min(c.ny, math.ceil((y1 + rr) / sp))
		if px1 > px0 and py1 > py0 then
			gatherRect(self, ci, px0, py0, px1, py1, false)
		end
	end
	-- pixels whose cascade-0 probes were refreshed
	local c0 = cs[1]
	rr -= c0.spacing
	local w, h = self.w, self.h
	local ix0, iy0 = math.max(0, math.floor(x0 - rr)), math.max(0, math.floor(y0 - rr))
	local ix1, iy1 = math.min(w, math.ceil(x1 + rr)), math.min(h, math.ceil(y1 + rr))
	if ix1 > ix0 and iy1 > iy0 then
		compositeRows(self, c0.avg, self.fluence, self.rgba, iy0, iy1, ix0, ix1, true)
		if self.patchX1 > self.patchX0 then
			ix0, iy0 = math.min(ix0, self.patchX0), math.min(iy0, self.patchY0)
			ix1, iy1 = math.max(ix1, self.patchX1), math.max(iy1, self.patchY1)
		end
		self.patchX0, self.patchY0, self.patchX1, self.patchY1 = ix0, iy0, ix1, iy1
	end
end

local function refreshLights(self: RadianceCascades, levels: number)
	local nl, ln, lights, last = self.nl, self.lastN, self.lights, self.lastL
	for li = 0, math.max(nl, ln) - 1 do
		local changed = li >= nl or li >= ln
		if not changed then
			for k = li * 7, li * 7 + 6 do
				if buffer.readu32(lights, k * 4) ~= buffer.readu32(last, k * 4) then
					changed = true
					break
				end
			end
		end
		if changed then
			local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
			if li < nl then
				local lx, ly, lr = buffer.readf32(lights, li * 28), buffer.readf32(lights, li * 28 + 4), buffer.readf32(lights, li * 28 + 8)
				x0, y0, x1, y1 = lx - lr, ly - lr, lx + lr, ly + lr
			end
			if li < ln then
				local lx, ly, lr = buffer.readf32(last, li * 28), buffer.readf32(last, li * 28 + 4), buffer.readf32(last, li * 28 + 8)
				x0, y0 = math.min(x0, lx - lr), math.min(y0, ly - lr)
				x1, y1 = math.max(x1, lx + lr), math.max(y1, ly + lr)
			end
			refreshRect(self, levels, x0, y0, x1, y1)
		end
	end
	buffer.copy(last, 0, lights, 0, nl * 28)
	self.lastN = nl
end

-- Amortized frame: spend about budgetMs on the same pipeline, resuming where the last call stopped
-- (pending bake, then cascades top-down a probe row at a time, then composite rows, then bounce).
-- The cycle writes back buffers (avg, fluence, rgba) and swaps them in when complete, so the shown
-- frame never tears. Idles once `settle` cycles have run since the last change. Returns true when
-- a cycle finished.
function RC.step(self: RadianceCascades, budgetMs: number): boolean
	local clock = os.clock
	local limit = clock() + budgetMs / 1000
	if self.dirty then
		updateGeometry(self)
		self.active = math.max(self.active, self.settle)
	end
	self.patchX0, self.patchY0, self.patchX1, self.patchY1 = 0, 0, 0, 0
	if not self.bakeAll and self.nl + self.lastN > 0 then
		-- light patch first; drop a level when it eats too much of the budget (interpreter)
		local t = clock()
		refreshLights(self, self.levelsNow)
		local ms = (clock() - t) * 1000
		if ms > budgetMs * 0.5 and self.levelsNow > 1 then
			self.levelsNow -= 1
			self.levelsCap = self.levelsNow -- stay down until the scene settles (no oscillation)
		elseif ms < budgetMs * 0.1 and self.levelsNow < self.levelsCap then
			self.levelsNow += 1
		end
	end
	local cs = self.cascades
	local finished = false
	local item = 0 -- duration of the last work item: start another only if one more still fits
	while self.active > 0 or self.bakeAll do
		local ts = clock()
		if ts + item >= limit then
			break
		end
		if self.bakeAll then
			local c = cs[self.bakeC]
			bakeProbe(self, c, cs[self.bakeC + 1], self.bakeP)
			self.bakeP += 1
			if self.bakeP >= c.nx * c.ny then
				self.bakeC, self.bakeP = self.bakeC - 1, 0
				if self.bakeC < 1 then
					self.bakeAll = false
					self.phase, self.curC, self.curRow = GATHER, #cs, 0
					self.active = math.max(self.active, self.settle)
				end
			end
		elseif self.phase == GATHER then
			local ci = self.curC
			gatherRect(self, ci, 0, self.curRow, cs[ci].nx, self.curRow + 1, true)
			self.curRow += 1
			if self.curRow >= cs[ci].ny then
				self.curRow = 0
				if ci == 1 then
					self.phase = COMPOSITE
				else
					self.curC = ci - 1
				end
			end
		else
			local y = self.curRow
			local y1 = math.min(self.h, y + 8)
			compositeRows(self, cs[1].back, self.flBack, self.rgbaBack, y, y1, 0, self.w, false)
			self.curRow = y1
			if y1 >= self.h then
				for _, c in cs do
					c.avg, c.back = c.back, c.avg
				end
				self.fluence, self.flBack = self.flBack, self.fluence
				self.rgba, self.rgbaBack = self.rgbaBack, self.rgba
				shadeWalls(self, true)
				self.phase, self.curC, self.curRow = GATHER, #cs, 0
				self.active -= 1
				finished = true
				if self.active <= 0 then
					self.levelsCap = self.localLevels
				end
			end
		end
		item = clock() - ts
	end
	return finished
end

-- Roblox only ------------------------------------------------------------------------------------
function RC.present(self: RadianceCascades, img: any)
	img:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(self.w, self.h), self.rgba)
end

--[[ Parallel Luau (Roblox only, sketch). Each Actor requires this module once (require is illegal
while desynchronized) and builds its own RC with the same size/options and scene, so it owns its
ray cache (bake once per geometry change: bakeBand). Per cycle, the main script sends the shared
inputs, which arrive as copies: surf (w*h*12 B), the upper cascade's avg, the light list. Each
Actor traces its rows and sends back its avg band; main copies bands in and moves one cascade down.

	-- inside the Actor's script (bands: this Actor's probe rows per cascade)
	local rc = RC.new(W, H, OPTS); buildMyScene(rc); rc:buildScene()
	for ci, b in bands do RC.bakeBand(rc, ci, b[1], b[2]) end -- only this Actor's ray cache
	actor:BindToMessageParallel("cascade", function(ci, row0, row1, surf, upAvg, lights, nl)
		rc.surf, rc.lights, rc.nl = surf, lights, nl
		if upAvg then rc.cascades[ci + 1].avg = upAvg end
		RC.traceBand(rc, ci, row0, row1)
		local c = rc.cascades[ci]
		local bytes = (row1 - row0) * c.nx * c.groups * 12 -- probe-major: the band is contiguous
		local out = buffer.create(bytes)
		buffer.copy(out, 0, c.avg, row0 * c.nx * c.groups * 12, bytes)
		mainActor:SendMessage("band", ci, row0, out)
	end)
]]

return RC
