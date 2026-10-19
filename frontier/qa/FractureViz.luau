--!native
--!optimize 2
-- FractureViz: headless preview renderer for combo/Fracture (QA only). Supersampled perspective rasteriser with
-- a sky gradient and fogged ground plane, planar soft shadows, perspective-correct bilinear texturing, flat
-- Lambert + hemisphere ambient + Blinn specular, and a sorted alpha pass for glass. Also a tiny rigid-body
-- tumble (gravity, spin, ground bounce on the lowest vertex) used only to pose fragments for pictures.

local FV = {}
FV.__index = FV

local function norm(x: number, y: number, z: number): (number, number, number)
	local l = math.sqrt(x * x + y * y + z * z)
	if l == 0 then
		return 0, 0, 0
	end
	return x / l, y / l, z / l
end

function FV.new(w: number, h: number, ss: number)
	local W, H = w * ss, h * ss
	local self = setmetatable({
		w = w,
		h = h,
		ss = ss,
		W = W,
		H = H,
		col = buffer.create(W * H * 4),
		z = buffer.create(W * H * 4),
		flag = buffer.create(W * H),
		shadow = buffer.create(W * H),
		ex = 0,
		ey = 0,
		ez = 0,
		rx = 1,
		ry = 0,
		rz = 0,
		ux = 0,
		uy = 1,
		uz = 0,
		fx = 0,
		fy = 0,
		fz = -1,
		focal = H,
		lx = 0,
		ly = 1,
		lz = 0,
		gy = 0,
		trans = {},
	}, FV)
	self:light(-0.45, 0.8, 0.55)
	return self
end

function FV.light(self, x: number, y: number, z: number)
	self.lx, self.ly, self.lz = norm(x, y, z)
end

function FV.lookAt(self, ex: number, ey: number, ez: number, tx: number, ty: number, tz: number, fovDeg: number)
	self.ex, self.ey, self.ez = ex, ey, ez
	local fx, fy, fz = norm(tx - ex, ty - ey, tz - ez)
	local rx, ry, rz = norm(-fz, 0, fx)
	self.fx, self.fy, self.fz = fx, fy, fz
	self.rx, self.ry, self.rz = rx, ry, rz
	self.ux, self.uy, self.uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
	self.focal = (self.H * 0.5) / math.tan(math.rad(fovDeg) * 0.5)
end

function FV.project(self, x: number, y: number, z: number): (number, number, number)
	local dx, dy, dz = x - self.ex, y - self.ey, z - self.ez
	local cx = dx * self.rx + dy * self.ry + dz * self.rz
	local cy = dx * self.ux + dy * self.uy + dz * self.uz
	local cz = dx * self.fx + dy * self.fy + dz * self.fz
	local k = self.focal / cz
	return self.W * 0.5 + cx * k, self.H * 0.5 - cy * k, cz
end

-- Sky gradient + ground plane y = gy. ground(x, z) -> r, g, b.
function FV.background(self, gy: number, top: { number }, horizon: { number }, ground: (number, number) -> (number, number, number), fog: number)
	local W, H, col, zb, flag = self.W, self.H, self.col, self.z, self.flag
	self.gy = gy
	buffer.fill(self.shadow, 0, 0)
	for sy = 0, H - 1 do
		local cyv = -((sy + 0.5) - H * 0.5) / self.focal
		for sx = 0, W - 1 do
			local cxv = ((sx + 0.5) - W * 0.5) / self.focal
			local dx = self.fx + cxv * self.rx + cyv * self.ux
			local dy = self.fy + cxv * self.ry + cyv * self.uy
			local dz = self.fz + cxv * self.rz + cyv * self.uz
			local i = sy * W + sx
			local r, g, b
			if dy < -1e-4 and (gy - self.ey) / dy > 0 then
				local t = (gy - self.ey) / dy -- view-space depth (forward component of d is 1)
				local x, z = self.ex + dx * t, self.ez + dz * t
				r, g, b = ground(x, z)
				local dist = t * math.sqrt(dx * dx + dy * dy + dz * dz)
				local k = 1 - math.exp(-dist * fog)
				r += (horizon[1] - r) * k
				g += (horizon[2] - g) * k
				b += (horizon[3] - b) * k
				buffer.writef32(zb, i * 4, 1 / t)
				buffer.writeu8(flag, i, 1)
			else
				local l = math.sqrt(dx * dx + dy * dy + dz * dz)
				local k = math.clamp(dy / l * 2.2, 0, 1) ^ 0.7
				r = horizon[1] + (top[1] - horizon[1]) * k
				g = horizon[2] + (top[2] - horizon[2]) * k
				b = horizon[3] + (top[3] - horizon[3]) * k
				buffer.writef32(zb, i * 4, 0)
				buffer.writeu8(flag, i, 0)
			end
			buffer.writeu8(col, i * 4, math.clamp(r // 1, 0, 255))
			buffer.writeu8(col, i * 4 + 1, math.clamp(g // 1, 0, 255))
			buffer.writeu8(col, i * 4 + 2, math.clamp(b // 1, 0, 255))
			buffer.writeu8(col, i * 4 + 3, 255)
		end
	end
end

-- Planar shadow: project triangles onto the ground along the light, mark ground pixels.
function FV.shadowMesh(self, pos: buffer, idx: buffer, tcount: number)
	local W, H, sh, flag = self.W, self.H, self.shadow, self.flag
	local lx, ly, lz, gy = self.lx, self.ly, self.lz, self.gy
	local sxs, sys = table.create(3, 0), table.create(3, 0)
	for t = 0, tcount - 1 do
		local ok = true
		for k = 0, 2 do
			local v = buffer.readu32(idx, t * 12 + k * 4)
			local x, y, z = buffer.readf32(pos, v * 12), buffer.readf32(pos, v * 12 + 4), buffer.readf32(pos, v * 12 + 8)
			local s = (y - gy) / ly
			local sx, sy, cz = self:project(x - lx * s, gy, z - lz * s)
			if cz <= 0.05 then
				ok = false
			end
			sxs[k + 1], sys[k + 1] = sx, sy
		end
		if not ok then
			continue
		end
		local x0, y0, x1, y1, x2, y2 = sxs[1], sys[1], sxs[2], sys[2], sxs[3], sys[3]
		local area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
		if area == 0 then
			continue
		end
		local inv = 1 / area
		local minx, maxx = math.max(0, math.floor(math.min(x0, x1, x2))), math.min(W - 1, math.ceil(math.max(x0, x1, x2)))
		local miny, maxy = math.max(0, math.floor(math.min(y0, y1, y2))), math.min(H - 1, math.ceil(math.max(y0, y1, y2)))
		for y = miny, maxy do
			local py = y + 0.5
			for x = minx, maxx do
				local pxx = x + 0.5
				local w0 = ((x1 - pxx) * (y2 - py) - (x2 - pxx) * (y1 - py)) * inv
				local w1 = ((x2 - pxx) * (y0 - py) - (x0 - pxx) * (y2 - py)) * inv
				if w0 >= 0 and w1 >= 0 and w0 + w1 <= 1 then
					local i = y * W + x
					if buffer.readu8(flag, i) == 1 then
						buffer.writeu8(sh, i, 255)
					end
				end
			end
		end
	end
end

-- Soften (separable box blur, radius r) and darken shadowed ground.
function FV.applyShadow(self, strength: number, r: number)
	local W, H, sh, col = self.W, self.H, self.shadow, self.col
	local tmp = buffer.create(W * H * 2)
	for y = 0, H - 1 do
		local acc = 0
		for x = -r, W - 1 + r do
			if x + r < W and x + r >= 0 then
				acc += buffer.readu8(sh, y * W + x + r)
			end
			if x - r - 1 >= 0 and x - r - 1 < W then
				acc -= buffer.readu8(sh, y * W + x - r - 1)
			end
			if x >= 0 and x < W then
				buffer.writeu16(tmp, (y * W + x) * 2, acc // (2 * r + 1))
			end
		end
	end
	for x = 0, W - 1 do
		local acc = 0
		for y = -r, H - 1 + r do
			if y + r < H and y + r >= 0 then
				acc += buffer.readu16(tmp, ((y + r) * W + x) * 2)
			end
			if y - r - 1 >= 0 and y - r - 1 < H then
				acc -= buffer.readu16(tmp, ((y - r - 1) * W + x) * 2)
			end
			if y >= 0 and y < H then
				local i = y * W + x
				local s = acc / (2 * r + 1) / 255
				if s > 0 and buffer.readu8(self.flag, i) == 1 then
					local k = 1 - strength * s
					for c = 0, 2 do
						buffer.writeu8(col, i * 4 + c, math.floor(buffer.readu8(col, i * 4 + c) * k))
					end
				end
			end
		end
	end
end

export type Tex = { buf: buffer, w: number, h: number }
export type MeshOpts = {
	interior: { number }?, -- side-wall (mat 2) colour, blended over the edge texel
	interiorMix: number?,
	spec: number?,
	shininess: number?,
	alpha: number?, -- nil = opaque; else queued for the sorted transparent pass
	tint: { number }?,
	ambient: number?,
}

local function sample(tex: Tex, u: number, v: number): (number, number, number)
	local tw, th, buf = tex.w, tex.h, tex.buf
	local x, y = u * tw - 0.5, v * th - 0.5
	local x0, y0 = math.floor(x), math.floor(y)
	local fx, fy = x - x0, y - y0
	local xa, xb = math.clamp(x0, 0, tw - 1), math.clamp(x0 + 1, 0, tw - 1)
	local ya, yb = math.clamp(y0, 0, th - 1), math.clamp(y0 + 1, 0, th - 1)
	local i00, i10, i01, i11 = (ya * tw + xa) * 4, (ya * tw + xb) * 4, (yb * tw + xa) * 4, (yb * tw + xb) * 4
	local w00, w10, w01, w11 = (1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy
	local r = buffer.readu8(buf, i00) * w00 + buffer.readu8(buf, i10) * w10 + buffer.readu8(buf, i01) * w01 + buffer.readu8(buf, i11) * w11
	local g = buffer.readu8(buf, i00 + 1) * w00 + buffer.readu8(buf, i10 + 1) * w10 + buffer.readu8(buf, i01 + 1) * w01 + buffer.readu8(buf, i11 + 1) * w11
	local b = buffer.readu8(buf, i00 + 2) * w00 + buffer.readu8(buf, i10 + 2) * w10 + buffer.readu8(buf, i01 + 2) * w01 + buffer.readu8(buf, i11 + 2) * w11
	return r, g, b
end

-- Rasterise one triangle t of a mesh. pos: world f32x3; nrm: world per-triangle f32x3; uv f32x2.
local function drawTri(self, pos: buffer, nrm: buffer, uv: buffer, idx: buffer, mat: buffer?, t: number, tex: Tex, o: MeshOpts, alpha: number?)
	local W, H, col, zb = self.W, self.H, self.col, self.z
	local ia, ib, ic = buffer.readu32(idx, t * 12), buffer.readu32(idx, t * 12 + 4), buffer.readu32(idx, t * 12 + 8)
	local ax, ay, az = buffer.readf32(pos, ia * 12), buffer.readf32(pos, ia * 12 + 4), buffer.readf32(pos, ia * 12 + 8)
	local bx, by, bz = buffer.readf32(pos, ib * 12), buffer.readf32(pos, ib * 12 + 4), buffer.readf32(pos, ib * 12 + 8)
	local cx, cy, cz = buffer.readf32(pos, ic * 12), buffer.readf32(pos, ic * 12 + 4), buffer.readf32(pos, ic * 12 + 8)
	local sx0, sy0, z0 = self:project(ax, ay, az)
	local sx1, sy1, z1 = self:project(bx, by, bz)
	local sx2, sy2, z2 = self:project(cx, cy, cz)
	if z0 <= 0.05 or z1 <= 0.05 or z2 <= 0.05 then
		return
	end
	local area = (sx1 - sx0) * (sy2 - sy0) - (sx2 - sx0) * (sy1 - sy0)
	if area >= 0 then -- y-down screen: CCW front faces have negative area
		return
	end
	local nx, ny, nz = buffer.readf32(nrm, t * 12), buffer.readf32(nrm, t * 12 + 4), buffer.readf32(nrm, t * 12 + 8)
	local lam = math.max(0, nx * self.lx + ny * self.ly + nz * self.lz)
	local amb = (o.ambient or 0.42) + 0.16 * ny
	local shade = amb + 0.78 * lam
	-- Blinn specular, per triangle (view from the centroid).
	local spec = 0
	local vx, vy, vz = norm(self.ex - (ax + bx + cx) / 3, self.ey - (ay + by + cy) / 3, self.ez - (az + bz + cz) / 3)
	if o.spec then
		local hx, hy, hz = norm(self.lx + vx, self.ly + vy, self.lz + vz)
		spec = o.spec * math.max(0, nx * hx + ny * hy + nz * hz) ^ (o.shininess or 32)
	end
	local isSide = mat ~= nil and buffer.readu8(mat, t) == 2
	local inter, imix = o.interior, o.interiorMix or 0.6
	local tint = o.tint
	local a = alpha
	if a then -- fresnel: glass is more opaque at grazing angles
		local c = math.abs(nx * vx + ny * vy + nz * vz)
		a = a + (1 - a) * (1 - c) ^ 4
		if isSide then
			a = math.max(a, 0.85)
		end
	end
	local u0, v0 = buffer.readf32(uv, ia * 8), buffer.readf32(uv, ia * 8 + 4)
	local u1, v1 = buffer.readf32(uv, ib * 8), buffer.readf32(uv, ib * 8 + 4)
	local u2, v2 = buffer.readf32(uv, ic * 8), buffer.readf32(uv, ic * 8 + 4)
	local iz0, iz1, iz2 = 1 / z0, 1 / z1, 1 / z2
	local minx = math.max(0, math.floor(math.min(sx0, sx1, sx2)))
	local maxx = math.min(W - 1, math.ceil(math.max(sx0, sx1, sx2)))
	local miny = math.max(0, math.floor(math.min(sy0, sy1, sy2)))
	local maxy = math.min(H - 1, math.ceil(math.max(sy0, sy1, sy2)))
	local inv = 1 / area
	for y = miny, maxy do
		local py = y + 0.5
		for x = minx, maxx do
			local pxx = x + 0.5
			local w0 = ((sx1 - pxx) * (sy2 - py) - (sx2 - pxx) * (sy1 - py)) * inv
			local w1 = ((sx2 - pxx) * (sy0 - py) - (sx0 - pxx) * (sy2 - py)) * inv
			local w2 = 1 - w0 - w1
			if w0 >= 0 and w1 >= 0 and w2 >= 0 then
				local iz = w0 * iz0 + w1 * iz1 + w2 * iz2
				local i = y * W + x
				if iz > buffer.readf32(zb, i * 4) then
					local zz = 1 / iz
					local u = (w0 * u0 * iz0 + w1 * u1 * iz1 + w2 * u2 * iz2) * zz
					local v = (w0 * v0 * iz0 + w1 * v1 * iz1 + w2 * v2 * iz2) * zz
					local r, g, b = sample(tex, u, v)
					if isSide and inter then -- fracture face: interior colour with a hint of the edge texel
						local l = (r + g + b) / 765
						local k = 1 - imix + imix * (0.8 + 0.4 * l)
						r, g, b = inter[1] * k, inter[2] * k, inter[3] * k
					end
					if tint then
						r, g, b = r * tint[1], g * tint[2], b * tint[3]
					end
					r = r * shade + 255 * spec
					g = g * shade + 255 * spec
					b = b * shade + 255 * spec
					if a then
						local k = a
						r = buffer.readu8(col, i * 4) * (1 - k) + r * k
						g = buffer.readu8(col, i * 4 + 1) * (1 - k) + g * k
						b = buffer.readu8(col, i * 4 + 2) * (1 - k) + b * k
					else
						buffer.writef32(zb, i * 4, iz)
						buffer.writeu8(self.flag, i, 2)
					end
					buffer.writeu8(col, i * 4, math.clamp(r // 1, 0, 255))
					buffer.writeu8(col, i * 4 + 1, math.clamp(g // 1, 0, 255))
					buffer.writeu8(col, i * 4 + 2, math.clamp(b // 1, 0, 255))
				end
			end
		end
	end
end

function FV.mesh(self, pos: buffer, nrm: buffer, uv: buffer, idx: buffer, mat: buffer?, tcount: number, tex: Tex, opts: MeshOpts?)
	local o = opts or {} :: MeshOpts
	if o.alpha then
		-- Queue for the sorted transparent pass (copies are owned by the queue).
		local m = { pos = pos, nrm = nrm, uv = uv, idx = idx, mat = mat, tex = tex, o = o }
		for t = 0, tcount - 1 do
			local a, b, c = buffer.readu32(idx, t * 12), buffer.readu32(idx, t * 12 + 4), buffer.readu32(idx, t * 12 + 8)
			local x = (buffer.readf32(pos, a * 12) + buffer.readf32(pos, b * 12) + buffer.readf32(pos, c * 12)) / 3
			local y = (buffer.readf32(pos, a * 12 + 4) + buffer.readf32(pos, b * 12 + 4) + buffer.readf32(pos, c * 12 + 4)) / 3
			local z = (buffer.readf32(pos, a * 12 + 8) + buffer.readf32(pos, b * 12 + 8) + buffer.readf32(pos, c * 12 + 8)) / 3
			local _, _, d = self:project(x, y, z)
			table.insert(self.trans, { d = d, m = m, t = t })
		end
		return
	end
	for t = 0, tcount - 1 do
		drawTri(self, pos, nrm, uv, idx, mat, t, tex, o, nil)
	end
end

function FV.flushTransparent(self)
	table.sort(self.trans, function(a, b)
		return a.d > b.d
	end)
	for _, e in self.trans do
		local m = e.m
		drawTri(self, m.pos, m.nrm, m.uv, m.idx, m.mat, e.t, m.tex, m.o, m.o.alpha)
	end
	table.clear(self.trans)
end

-- Box-filter the supersampled frame down to w x h RGBA8.
function FV.resolve(self): buffer
	local w, h, ss, W, col = self.w, self.h, self.ss, self.W, self.col
	local out = buffer.create(w * h * 4)
	local k = 1 / (ss * ss)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local r, g, b = 0, 0, 0
			for j = 0, ss - 1 do
				for i = 0, ss - 1 do
					local o = ((y * ss + j) * W + x * ss + i) * 4
					r += buffer.readu8(col, o)
					g += buffer.readu8(col, o + 1)
					b += buffer.readu8(col, o + 2)
				end
			end
			local o = (y * w + x) * 4
			buffer.writeu8(out, o, math.floor(r * k + 0.5))
			buffer.writeu8(out, o + 1, math.floor(g * k + 0.5))
			buffer.writeu8(out, o + 2, math.floor(b * k + 0.5))
			buffer.writeu8(out, o + 3, 255)
		end
	end
	return out
end

-- Axis-aligned box mesh (for frames/props), CCW outward. Returns pos, nrm, uv, idx, tcount.
function FV.box(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): (buffer, buffer, buffer, buffer, number)
	local faces = {
		{ { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 }, { x1, y0, z1 }, { 1, 0, 0 } },
		{ { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 }, { x0, y0, z0 }, { -1, 0, 0 } },
		{ { x0, y1, z0 }, { x0, y1, z1 }, { x1, y1, z1 }, { x1, y1, z0 }, { 0, 1, 0 } },
		{ { x0, y0, z1 }, { x0, y0, z0 }, { x1, y0, z0 }, { x1, y0, z1 }, { 0, -1, 0 } },
		{ { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 }, { 0, 0, 1 } },
		{ { x1, y0, z0 }, { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 }, { 0, 0, -1 } },
	}
	local pos, nrm, uv, idx = buffer.create(24 * 12), buffer.create(12 * 12), buffer.create(24 * 8), buffer.create(12 * 12)
	for f, q in faces do
		for k = 1, 4 do
			local v = (f - 1) * 4 + k - 1
			buffer.writef32(pos, v * 12, q[k][1])
			buffer.writef32(pos, v * 12 + 4, q[k][2])
			buffer.writef32(pos, v * 12 + 8, q[k][3])
			buffer.writef32(uv, v * 8, if k == 2 or k == 3 then 1 else 0)
			buffer.writef32(uv, v * 8 + 4, if k >= 3 then 1 else 0)
		end
		local b = (f - 1) * 4
		for tt, tri in { { b, b + 1, b + 2 }, { b, b + 2, b + 3 } } do
			local t = (f - 1) * 2 + tt - 1
			buffer.writeu32(idx, t * 12, tri[1])
			buffer.writeu32(idx, t * 12 + 4, tri[2])
			buffer.writeu32(idx, t * 12 + 8, tri[3])
			buffer.writef32(nrm, t * 12, q[5][1])
			buffer.writef32(nrm, t * 12 + 4, q[5][2])
			buffer.writef32(nrm, t * 12 + 8, q[5][3])
		end
	end
	return pos, nrm, uv, idx, 12
end

-- Rigid-body tumble (preview only) ---------------------------------------------------------------------------

export type Body = {
	frag: any,
	px: number,
	py: number,
	pz: number,
	vx: number,
	vy: number,
	vz: number,
	qw: number,
	qx: number,
	qy: number,
	qz: number,
	wx: number,
	wy: number,
	wz: number,
	static: boolean,
	wpos: buffer,
	wnrm: buffer,
}

function FV.newBody(frag: any, px: number, py: number, pz: number, static: boolean): Body
	return {
		frag = frag,
		px = px,
		py = py,
		pz = pz,
		vx = 0,
		vy = 0,
		vz = 0,
		qw = 1,
		qx = 0,
		qy = 0,
		qz = 0,
		wx = 0,
		wy = 0,
		wz = 0,
		static = static,
		wpos = buffer.create(frag.vcount * 12),
		wnrm = buffer.create(frag.tcount * 12),
	}
end

local function rot(b: Body, x: number, y: number, z: number): (number, number, number)
	local qw, qx, qy, qz = b.qw, b.qx, b.qy, b.qz
	-- v' = v + 2w(q x v) + 2 q x (q x v)
	local tx, ty, tz = 2 * (qy * z - qz * y), 2 * (qz * x - qx * z), 2 * (qx * y - qy * x)
	return x + qw * tx + (qy * tz - qz * ty), y + qw * ty + (qz * tx - qx * tz), z + qw * tz + (qx * ty - qy * tx)
end

-- World-space vertices and face normals into b.wpos / b.wnrm.
function FV.pose(b: Body)
	local f = b.frag
	local pos, nrm = f.pos, f.nrm
	for v = 0, f.vcount - 1 do
		local x, y, z = rot(b, buffer.readf32(pos, v * 12), buffer.readf32(pos, v * 12 + 4), buffer.readf32(pos, v * 12 + 8))
		buffer.writef32(b.wpos, v * 12, x + b.px)
		buffer.writef32(b.wpos, v * 12 + 4, y + b.py)
		buffer.writef32(b.wpos, v * 12 + 8, z + b.pz)
	end
	for t = 0, f.tcount - 1 do
		local x, y, z = rot(b, buffer.readf32(nrm, t * 12), buffer.readf32(nrm, t * 12 + 4), buffer.readf32(nrm, t * 12 + 8))
		buffer.writef32(b.wnrm, t * 12, x)
		buffer.writef32(b.wnrm, t * 12 + 4, y)
		buffer.writef32(b.wnrm, t * 12 + 8, z)
	end
end

function FV.simulate(bodies: { Body }, T: number, dt: number, gy: number, g: number)
	local steps = math.floor(T / dt + 0.5)
	for _ = 1, steps do
		for _, b in bodies do
			if b.static then
				continue
			end
			b.vy -= g * dt
			b.px += b.vx * dt
			b.py += b.vy * dt
			b.pz += b.vz * dt
			-- q += 0.5 * (0, w) * q * dt
			local qw, qx, qy, qz, wx, wy, wz = b.qw, b.qx, b.qy, b.qz, b.wx, b.wy, b.wz
			local h = 0.5 * dt
			b.qw = qw + h * (-wx * qx - wy * qy - wz * qz)
			b.qx = qx + h * (wx * qw + wy * qz - wz * qy)
			b.qy = qy + h * (wy * qw + wz * qx - wx * qz)
			b.qz = qz + h * (wz * qw + wx * qy - wy * qx)
			local l = math.sqrt(b.qw ^ 2 + b.qx ^ 2 + b.qy ^ 2 + b.qz ^ 2)
			b.qw, b.qx, b.qy, b.qz = b.qw / l, b.qx / l, b.qy / l, b.qz / l
			-- Ground: push the lowest vertex out, bounce, rub off speed and spin.
			if b.py - b.frag.radius < gy then
				local f, minY = b.frag, math.huge
				for v = 0, f.vcount - 1 do
					local _, y = rot(b, buffer.readf32(f.pos, v * 12), buffer.readf32(f.pos, v * 12 + 4), buffer.readf32(f.pos, v * 12 + 8))
					if y < minY then
						minY = y
					end
				end
				if b.py + minY < gy then
					b.py = gy - minY
					if b.vy < 0 then
						b.vy = -b.vy * 0.3
					end
					b.vx *= 0.8
					b.vz *= 0.8
					b.wx *= 0.75
					b.wy *= 0.75
					b.wz *= 0.75
				end
			end
		end
	end
end

return FV
