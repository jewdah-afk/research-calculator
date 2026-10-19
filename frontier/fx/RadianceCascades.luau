--!native
--!optimize 2
-- 2D global illumination with Radiance Cascades (Sannikov 2023), CPU edition.
-- Scene: per-pixel solid mask + emission + albedo. Lights are emissive solids, walls are dark solids.
-- 1. Exact Euclidean distance field (Felzenszwalb two-pass EDT, O(n)) or jump flooding (JFA+1,
--    O(n log n)) for sphere-traced rays.
-- 2. Cascade i: probe spacing s0*2^i, 4^(i+1) rays, ray interval [L0(4^i-1)/3, L0(4^(i+1)-1)/3].
--    Every cascade has the same ray count (4 * probes of cascade 0), so cost is
--    O(pixels/s0^2 * cascades), independent of the number of lights.
-- 3. Merge top-down: radiance = near + transmittance * upper cascade (4 rays pre-averaged).
--    Default "bilinear fix": each ray is traced once per bilinear upper probe, from p + d*t0 to
--    q + d*t1, so segments join up and light cannot hop over walls (~3x the cost of vanilla).
--    fix = false gives vanilla bilinear merging (fast, leaks/ringing near walls).
-- 4. Merge weights are bilinear * line-of-sight to each upper probe (cached per scene build).
-- 5. One light bounce per frame: wall surface pixels re-emit albedo * neighbouring fluence from the
--    previous frame, converging over a few frames into colour bleed.
-- Output: fluence (linear f32 RGB) and ACES-tonemapped RGBA8 with lit wall faces.

local RC = {}
RC.__index = RC

local INF = 1e12

type Cascade = {
	spacing: number,
	nx: number,
	ny: number,
	rays: number,
	t0: number,
	t1: number,
	dirs: buffer, -- f32 (dx, dy) per ray
	avg: buffer, -- f32 RGB per (group of 4 rays, probe), direction-major
	vis: buffer, -- f32 x4 merge weights per probe (bilinear * line-of-sight to upper probe)
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
		dirty: boolean,
		-- scratch
		g: buffer,
		f1: buffer,
		d1: buffer,
		v1: buffer,
		z1: buffer,
		seedA: buffer,
		seedB: buffer,
	},
	RC
))

function RC.new(w: number, h: number, opts: { [string]: any }?): RadianceCascades
	local o = opts or {}
	local s0: number = o.spacing or 2
	local L0: number = o.interval or s0
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
		table.insert(cascades, {
			spacing = spacing,
			nx = nx,
			ny = ny,
			rays = rays,
			t0 = t0,
			t1 = t1,
			dirs = dirs,
			avg = buffer.create(nx * ny * (rays // 4) * 12),
			vis = buffer.create(nx * ny * 16),
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
	local self = setmetatable({
		w = w,
		h = h,
		solid = buffer.create(n),
		emis = buffer.create(n * 12),
		albedo = buffer.create(n * 12),
		surf = buffer.create(n * 12),
		sdf = buffer.create(n * 4),
		fluence = buffer.create(n * 12),
		rgba = buffer.create(n * 4),
		lut = lut,
		edges = buffer.create(n * 4),
		edgeCount = 0,
		cascades = cascades,
		s0 = s0,
		exposure = o.exposure or 1,
		bounce = o.bounce or 1,
		fix = if o.fix == nil then true else o.fix,
		wallGain = o.wallGain or 1.5,
		wallAmbient = o.wallAmbient or 0.4,
		sky = o.sky or { 0, 0, 0 },
		method = o.method or "edt",
		dirty = true,
		g = buffer.create(n * 8),
		f1 = buffer.create(m * 8),
		d1 = buffer.create(m * 8),
		v1 = buffer.create(m * 4),
		z1 = buffer.create((m + 1) * 8),
		seedA = buffer.create(n * 4),
		seedB = buffer.create(n * 4),
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

local function buildEDT(self: RadianceCascades)
	local w, h = self.w, self.h
	local solid, g, f1, d1, v1, z1, sdf = self.solid, self.g, self.f1, self.d1, self.v1, self.z1, self.sdf
	for x = 0, w - 1 do
		for y = 0, h - 1 do
			buffer.writef64(f1, y * 8, if buffer.readu8(solid, y * w + x) ~= 0 then 0 else INF)
		end
		edt1d(f1, h, v1, z1, d1)
		for y = 0, h - 1 do
			buffer.writef64(g, (y * w + x) * 8, buffer.readf64(d1, y * 8))
		end
	end
	for y = 0, h - 1 do
		buffer.copy(f1, 0, g, y * w * 8, w * 8)
		edt1d(f1, w, v1, z1, d1)
		for x = 0, w - 1 do
			buffer.writef32(sdf, (y * w + x) * 4, math.sqrt(buffer.readf64(d1, x * 8)))
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
	local sdf = self.sdf
	for i = 0, n - 1 do
		local s = buffer.readu32(a, i * 4)
		local d = INF
		if s > 0 then
			local sx, sy = (s - 1) % w - i % w, (s - 1) // w - i // w
			d = math.sqrt(sx * sx + sy * sy)
		end
		buffer.writef32(sdf, i * 4, d)
	end
end

-- Wall surface pixels: incoming = mean fluence of open 4-neighbours. Displayed as albedo * incoming,
-- and re-emitted next frame as albedo * incoming * bounce (one bounce per frame, converges).
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

-- Merge weights: bilinear, zeroed for upper probes hidden behind walls (stops light leaking into
-- closed rooms), renormalised; plain bilinear when every upper probe is hidden.
local function buildVisibility(self: RadianceCascades)
	local w, h, sdf, cs = self.w, self.h, self.sdf, self.cascades
	for ci = 1, #cs - 1 do
		local c, up = cs[ci], cs[ci + 1]
		local nx, ny, sp, vis = c.nx, c.ny, c.spacing, c.vis
		local unx, uny, usp = up.nx, up.ny, up.spacing
		for py = 0, ny - 1 do
			local oy = math.min((py + 0.5) * sp, h - 0.01)
			local vy = oy / usp - 0.5
			local qy0 = math.floor(vy)
			local fy = vy - qy0
			local qy1 = qy0 + 1
			for px = 0, nx - 1 do
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
end

-- Rebuild distance field and the list of wall surface pixels (solid with an empty 4-neighbour).
function RC.buildScene(self: RadianceCascades)
	if self.method == "jfa" then
		buildJFA(self)
	else
		buildEDT(self)
	end
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
	buffer.copy(self.surf, 0, self.emis)
	shadeWalls(self, false) -- keep last frame's bounce light on the rebuilt walls
	buildVisibility(self)
	self.dirty = false
end

-- Lighting -----------------------------------------------------------------------------------------

-- Sphere trace the segment a->b. Returns radiance hit (or sky when leaving the frame) and
-- transmittance (1 = segment is clear, so the caller continues with the upper cascade).
local function march(sdf: buffer, surf: buffer, w: number, h: number, ax: number, ay: number, bx: number, by: number, sr: number, sg: number, sb: number): (number, number, number, number)
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1e-6 then
		return 0, 0, 0, 1
	end
	dx /= len
	dy /= len
	local t = 0
	while t < len do
		local x, y = ax + dx * t, ay + dy * t
		if x < 0 or y < 0 or x >= w or y >= h then
			return sr, sg, sb, 0
		end
		local i = (y // 1) * w + x // 1
		local d = buffer.readf32(sdf, i * 4)
		if d < 0.5 then
			return buffer.readf32(surf, i * 12), buffer.readf32(surf, i * 12 + 4), buffer.readf32(surf, i * 12 + 8), 0
		end
		t += if d > 1.5 then d - 1 else 0.5
	end
	return 0, 0, 0, 1
end

local function traceCascade(self: RadianceCascades, c: Cascade, up: Cascade?)
	local w, h, sdf, surf = self.w, self.h, self.sdf, self.surf
	local nx, ny, rays, t0, t1, dirs, avg, sp, vis = c.nx, c.ny, c.rays, c.t0, c.t1, c.dirs, c.avg, c.spacing, c.vis
	local groups = rays // 4
	local plane = nx * ny * 12
	local skyR, skyG, skyB = self.sky[1], self.sky[2], self.sky[3]
	local fix = self.fix
	local unx, uny, uavg, usp, uplane = 1, 1, avg, 1.0, 0
	if up then
		unx, uny, uavg, usp, uplane = up.nx, up.ny, up.avg, up.spacing, up.nx * up.ny * 12
	end
	-- longest bilinear-fix segment (|q - p| + interval length) plus pixel slack
	local reach = (t1 - t0) + usp * 1.415 + 1.5
	for py = 0, ny - 1 do
		local oy = (py + 0.5) * sp
		local qy0 = math.floor(oy / usp - 0.5)
		local qy1 = qy0 + 1
		if qy0 < 0 then qy0 = 0 end
		if qy1 > uny - 1 then qy1 = uny - 1 end
		if qy0 > uny - 1 then qy0 = uny - 1 end
		local cy0, cy1 = (qy0 + 0.5) * usp, (qy1 + 0.5) * usp
		for px = 0, nx - 1 do
			local ox = (px + 0.5) * sp
			local qx0 = math.floor(ox / usp - 0.5)
			local qx1 = qx0 + 1
			if qx0 < 0 then qx0 = 0 end
			if qx1 > unx - 1 then qx1 = unx - 1 end
			if qx0 > unx - 1 then qx0 = unx - 1 end
			local cx0, cx1 = (qx0 + 0.5) * usp, (qx1 + 0.5) * usp
			local vo = (py * nx + px) * 16
			local w00, w10 = buffer.readf32(vis, vo), buffer.readf32(vis, vo + 4)
			local w01, w11 = buffer.readf32(vis, vo + 8), buffer.readf32(vis, vo + 12)
			local b00, b10 = (qy0 * unx + qx0) * 12, (qy0 * unx + qx1) * 12
			local b01, b11 = (qy1 * unx + qx0) * 12, (qy1 * unx + qx1) * 12
			local outBase = (py * nx + px) * 12
			for g = 0, groups - 1 do
				local ar, ag, ab = 0, 0, 0
				for k = 0, 3 do
					local r = g * 4 + k
					local dx, dy = buffer.readf32(dirs, r * 8), buffer.readf32(dirs, r * 8 + 4)
					local sx, sy = ox + dx * t0, oy + dy * t0
					if up == nil then
						local cr, cg, cb, tr = march(sdf, surf, w, h, sx, sy, ox + dx * t1, oy + dy * t1, skyR, skyG, skyB)
						ar += cr + tr * skyR
						ag += cg + tr * skyG
						ab += cb + tr * skyB
					elseif fix and sx > reach and sy > reach and sx < w - reach and sy < h - reach
						and buffer.readf32(sdf, ((sy // 1) * w + sx // 1) * 4) > reach then
						-- every segment from here stays in empty space: plain bilinear merge, no marching
						local u = r * uplane
						ar += w00 * buffer.readf32(uavg, u + b00) + w10 * buffer.readf32(uavg, u + b10)
							+ w01 * buffer.readf32(uavg, u + b01) + w11 * buffer.readf32(uavg, u + b11)
						ag += w00 * buffer.readf32(uavg, u + b00 + 4) + w10 * buffer.readf32(uavg, u + b10 + 4)
							+ w01 * buffer.readf32(uavg, u + b01 + 4) + w11 * buffer.readf32(uavg, u + b11 + 4)
						ab += w00 * buffer.readf32(uavg, u + b00 + 8) + w10 * buffer.readf32(uavg, u + b10 + 8)
							+ w01 * buffer.readf32(uavg, u + b01 + 8) + w11 * buffer.readf32(uavg, u + b11 + 8)
					elseif fix then
						-- bilinear fix: one segment per upper probe, ending where that probe's interval starts
						local u = r * uplane
						local ex, ey = dx * t1, dy * t1
						if w00 > 0 then
							local cr, cg, cb, tr = march(sdf, surf, w, h, sx, sy, cx0 + ex, cy0 + ey, skyR, skyG, skyB)
							if tr > 0 then
								cr += buffer.readf32(uavg, u + b00); cg += buffer.readf32(uavg, u + b00 + 4); cb += buffer.readf32(uavg, u + b00 + 8)
							end
							ar += w00 * cr; ag += w00 * cg; ab += w00 * cb
						end
						if w10 > 0 then
							local cr, cg, cb, tr = march(sdf, surf, w, h, sx, sy, cx1 + ex, cy0 + ey, skyR, skyG, skyB)
							if tr > 0 then
								cr += buffer.readf32(uavg, u + b10); cg += buffer.readf32(uavg, u + b10 + 4); cb += buffer.readf32(uavg, u + b10 + 8)
							end
							ar += w10 * cr; ag += w10 * cg; ab += w10 * cb
						end
						if w01 > 0 then
							local cr, cg, cb, tr = march(sdf, surf, w, h, sx, sy, cx0 + ex, cy1 + ey, skyR, skyG, skyB)
							if tr > 0 then
								cr += buffer.readf32(uavg, u + b01); cg += buffer.readf32(uavg, u + b01 + 4); cb += buffer.readf32(uavg, u + b01 + 8)
							end
							ar += w01 * cr; ag += w01 * cg; ab += w01 * cb
						end
						if w11 > 0 then
							local cr, cg, cb, tr = march(sdf, surf, w, h, sx, sy, cx1 + ex, cy1 + ey, skyR, skyG, skyB)
							if tr > 0 then
								cr += buffer.readf32(uavg, u + b11); cg += buffer.readf32(uavg, u + b11 + 4); cb += buffer.readf32(uavg, u + b11 + 8)
							end
							ar += w11 * cr; ag += w11 * cg; ab += w11 * cb
						end
					else
						local cr, cg, cb, tr = march(sdf, surf, w, h, sx, sy, ox + dx * t1, oy + dy * t1, skyR, skyG, skyB)
						if tr > 0 then
							local u = r * uplane
							cr += w00 * buffer.readf32(uavg, u + b00) + w10 * buffer.readf32(uavg, u + b10)
								+ w01 * buffer.readf32(uavg, u + b01) + w11 * buffer.readf32(uavg, u + b11)
							cg += w00 * buffer.readf32(uavg, u + b00 + 4) + w10 * buffer.readf32(uavg, u + b10 + 4)
								+ w01 * buffer.readf32(uavg, u + b01 + 4) + w11 * buffer.readf32(uavg, u + b11 + 4)
							cb += w00 * buffer.readf32(uavg, u + b00 + 8) + w10 * buffer.readf32(uavg, u + b10 + 8)
								+ w01 * buffer.readf32(uavg, u + b01 + 8) + w11 * buffer.readf32(uavg, u + b11 + 8)
						end
						ar += cr; ag += cg; ab += cb
					end
				end
				local o = g * plane + outBase
				buffer.writef32(avg, o, ar * 0.25)
				buffer.writef32(avg, o + 4, ag * 0.25)
				buffer.writef32(avg, o + 8, ab * 0.25)
			end
		end
	end
end

-- Upsample cascade-0 fluence to pixels and tonemap.
local function composite(self: RadianceCascades)
	local w, h, fl, rgba, lut, solid, emis, albedo = self.w, self.h, self.fluence, self.rgba, self.lut, self.solid, self.emis, self.albedo
	local amb = self.wallAmbient
	local c = self.cascades[1]
	local nx, ny, avg, sp = c.nx, c.ny, c.avg, c.spacing
	local ex = self.exposure * 128
	for y = 0, h - 1 do
		local vy = (y + 0.5) / sp - 0.5
		local qy0 = math.floor(vy)
		local fy = vy - qy0
		local qy1 = qy0 + 1
		if qy0 < 0 then qy0 = 0 end
		if qy1 > ny - 1 then qy1 = ny - 1 end
		for x = 0, w - 1 do
			local vx = (x + 0.5) / sp - 0.5
			local qx0 = math.floor(vx)
			local fx = vx - qx0
			local qx1 = qx0 + 1
			if qx0 < 0 then qx0 = 0 end
			if qx1 > nx - 1 then qx1 = nx - 1 end
			local w00, w10, w01, w11 = (1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy
			local b00, b10 = (qy0 * nx + qx0) * 12, (qy0 * nx + qx1) * 12
			local b01, b11 = (qy1 * nx + qx0) * 12, (qy1 * nx + qx1) * 12
			local r = w00 * buffer.readf32(avg, b00) + w10 * buffer.readf32(avg, b10) + w01 * buffer.readf32(avg, b01) + w11 * buffer.readf32(avg, b11)
			local g = w00 * buffer.readf32(avg, b00 + 4) + w10 * buffer.readf32(avg, b10 + 4) + w01 * buffer.readf32(avg, b01 + 4) + w11 * buffer.readf32(avg, b11 + 4)
			local b = w00 * buffer.readf32(avg, b00 + 8) + w10 * buffer.readf32(avg, b10 + 8) + w01 * buffer.readf32(avg, b01 + 8) + w11 * buffer.readf32(avg, b11 + 8)
			local i = y * w + x
			buffer.writef32(fl, i * 12, r)
			buffer.writef32(fl, i * 12 + 4, g)
			buffer.writef32(fl, i * 12 + 8, b)
			if buffer.readu8(solid, i) ~= 0 then
				local o = i * 12
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

-- Full frame: distance field if the scene changed, bounce, cascades top-down, composite.
function RC.render(self: RadianceCascades)
	if self.dirty then
		self:buildScene()
	end
	local cs = self.cascades
	for i = #cs, 1, -1 do
		traceCascade(self, cs[i], cs[i + 1])
	end
	composite(self)
	shadeWalls(self, true)
end

-- Roblox only ------------------------------------------------------------------------------------
function RC.present(self: RadianceCascades, img: any)
	img:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(self.w, self.h), self.rgba)
end

return RC
