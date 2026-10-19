--!native
--!optimize 2
-- MeshViz: headless triangle rasteriser for QA. Perspective or orthographic look-at camera, z-buffer
-- (stores 1/depth), flat Lambert shading from the face normal, back-face culling (CCW = front), optional
-- depth-tested wireframe overlay. Output is an RGBA8 buffer for Out.image.
-- `shaded` (additive): perspective-correct smooth normals, bilinear texture / vertex colour / alpha, hemisphere
-- ambient, sun with a lightmap (e.g. `heightShadow`), emission, Blinn spec + Fresnel sky reflection, depth fog.
-- `clearSky` paints a gradient, `downsample` gives SSAA.

local MeshViz = {}
MeshViz.__index = MeshViz

export type Viz = typeof(setmetatable(
	{} :: {
		w: number,
		h: number,
		rgba: buffer,
		z: buffer,
		ex: number,
		ey: number,
		ez: number,
		rx: number,
		ry: number,
		rz: number,
		ux: number,
		uy: number,
		uz: number,
		fx: number,
		fy: number,
		fz: number,
		focal: number,
		ortho: boolean,
		lx: number,
		ly: number,
		lz: number,
	},
	MeshViz
))

local function norm(x: number, y: number, z: number): (number, number, number)
	local l = math.sqrt(x * x + y * y + z * z)
	if l == 0 then
		return 0, 0, 0
	end
	return x / l, y / l, z / l
end

function MeshViz.new(w: number, h: number): Viz
	local self = setmetatable({
		w = w,
		h = h,
		rgba = buffer.create(w * h * 4),
		z = buffer.create(w * h * 4),
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
		focal = h,
		ortho = false,
		lx = 0,
		ly = 0,
		lz = 0,
	}, MeshViz)
	self:light(0.4, 0.8, 0.45)
	return self
end

function MeshViz.light(self: Viz, x: number, y: number, z: number)
	self.lx, self.ly, self.lz = norm(x, y, z)
end

function MeshViz.clear(self: Viz, r: number, g: number, b: number)
	local px = bit32.bor(r, bit32.lshift(g, 8), bit32.lshift(b, 16), 0xFF000000)
	for i = 0, self.w * self.h - 1 do
		buffer.writeu32(self.rgba, i * 4, px)
		buffer.writef32(self.z, i * 4, 0)
	end
end

-- fovDeg = nil gives an orthographic camera showing `orthoHalf` world units above/below centre.
function MeshViz.lookAt(self: Viz, ex: number, ey: number, ez: number, tx: number, ty: number, tz: number, fovDeg: number?, orthoHalf: number?)
	self.ex, self.ey, self.ez = ex, ey, ez
	local fx, fy, fz = norm(tx - ex, ty - ey, tz - ez)
	local rx, ry, rz = norm(fy * 0 - fz * 1, fz * 0 - fx * 0, fx * 1 - fy * 0) -- f x up(0,1,0)
	if rx == 0 and ry == 0 and rz == 0 then
		rx, ry, rz = 1, 0, 0
	end
	self.fx, self.fy, self.fz = fx, fy, fz
	self.rx, self.ry, self.rz = rx, ry, rz
	self.ux, self.uy, self.uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
	if fovDeg then
		self.ortho = false
		self.focal = (self.h * 0.5) / math.tan(math.rad(fovDeg) * 0.5)
	else
		self.ortho = true
		self.focal = (self.h * 0.5) / (orthoHalf or 1)
	end
end

-- Returns screen x, y and depth along the view axis.
function MeshViz.project(self: Viz, x: number, y: number, z: number): (number, number, number)
	local dx, dy, dz = x - self.ex, y - self.ey, z - self.ez
	local cx = dx * self.rx + dy * self.ry + dz * self.rz
	local cy = dx * self.ux + dy * self.uy + dz * self.uz
	local cz = dx * self.fx + dy * self.fy + dz * self.fz
	local k = if self.ortho then self.focal else self.focal / cz
	return self.w * 0.5 + cx * k, self.h * 0.5 - cy * k, cz
end

local function px(r: number, g: number, b: number): number
	return bit32.bor(math.clamp(math.floor(r), 0, 255), bit32.lshift(math.clamp(math.floor(g), 0, 255), 8), bit32.lshift(math.clamp(math.floor(b), 0, 255), 16), 0xFF000000)
end

local function line(self: Viz, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, colr: number)
	local w, h, zb, rgba = self.w, self.h, self.z, self.rgba
	local n = math.ceil(math.max(math.abs(x1 - x0), math.abs(y1 - y0)))
	if n > 4 * (w + h) then
		return
	end
	n = math.max(n, 1)
	for k = 0, n do
		local t = k / n
		local x, y = math.floor(x0 + (x1 - x0) * t), math.floor(y0 + (y1 - y0) * t)
		if x >= 0 and x < w and y >= 0 and y < h then
			local iz = 1 / (z0 + (z1 - z0) * t)
			local i = (y * w + x) * 4
			if iz >= buffer.readf32(zb, i) * 0.997 then
				if colr == 0 then -- darken mode: keeps the fill colour readable under dense wire
					local c = buffer.readu32(rgba, i)
					local r = bit32.band(c, 255) * 0.55
					local g = bit32.band(bit32.rshift(c, 8), 255) * 0.55
					local b = bit32.band(bit32.rshift(c, 16), 255) * 0.55
					buffer.writeu32(rgba, i, bit32.bor(math.floor(r), bit32.lshift(math.floor(g), 8), bit32.lshift(math.floor(b), 16), 0xFF000000))
				else
					buffer.writeu32(rgba, i, colr)
				end
			end
		end
	end
end

export type DrawOpts = {
	offset: { number }?, -- added to every position
	color: ((tri: number) -> (number, number, number))?, -- per-triangle base colour 0..255
	vcol: buffer?, -- per-vertex u32 RGBA8; triangle uses the mean
	tint: { number }?, -- multiplies base colour (0..1 each)
	wire: { number }?, -- wire colour; nil = no wireframe; {} = darken the fill under the wire
	cull: boolean?, -- default true
}

-- pos: f32 x3 per vertex; idx: u32 x3 per triangle.
function MeshViz.mesh(self: Viz, pos: buffer, idx: buffer, tcount: number, opts: DrawOpts?)
	local o = opts or {} :: DrawOpts
	local off = o.offset or { 0, 0, 0 }
	local ox, oy, oz = off[1], off[2], off[3]
	local cull = o.cull ~= false
	local tint = o.tint or { 1, 1, 1 }
	local wire = o.wire
	local wcol = if wire and wire[1] then px(wire[1], wire[2], wire[3]) else 0
	local w, h, zb, rgba = self.w, self.h, self.z, self.rgba
	local lx, ly, lz = self.lx, self.ly, self.lz
	local vcol, colorFn = o.vcol, o.color
	for t = 0, tcount - 1 do
		local ia, ib, ic = buffer.readu32(idx, t * 12), buffer.readu32(idx, t * 12 + 4), buffer.readu32(idx, t * 12 + 8)
		local ax, ay, az = buffer.readf32(pos, ia * 12) + ox, buffer.readf32(pos, ia * 12 + 4) + oy, buffer.readf32(pos, ia * 12 + 8) + oz
		local bx, by, bz = buffer.readf32(pos, ib * 12) + ox, buffer.readf32(pos, ib * 12 + 4) + oy, buffer.readf32(pos, ib * 12 + 8) + oz
		local cx, cy, cz = buffer.readf32(pos, ic * 12) + ox, buffer.readf32(pos, ic * 12 + 4) + oy, buffer.readf32(pos, ic * 12 + 8) + oz
		local sx0, sy0, z0 = self:project(ax, ay, az)
		local sx1, sy1, z1 = self:project(bx, by, bz)
		local sx2, sy2, z2 = self:project(cx, cy, cz)
		if z0 <= 0.01 or z1 <= 0.01 or z2 <= 0.01 then
			continue
		end
		local area = (sx1 - sx0) * (sy2 - sy0) - (sx2 - sx0) * (sy1 - sy0)
		if area == 0 or (cull and area > 0) then -- y-down screen: CCW front faces have negative area
			continue
		end
		local nx, ny, nz = norm((by - ay) * (cz - az) - (bz - az) * (cy - ay), (bz - az) * (cx - ax) - (bx - ax) * (cz - az), (bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
		local lam = nx * lx + ny * ly + nz * lz
		if area > 0 then
			lam = -lam -- back face seen with culling off
		end
		local shade = 0.3 + 0.7 * math.max(lam, 0)
		local r, g, b = 200, 200, 200
		if vcol then
			r, g, b = 0, 0, 0
			for _, v in { ia, ib, ic } do
				local c = buffer.readu32(vcol, v * 4)
				r += bit32.band(c, 255) / 3
				g += bit32.band(bit32.rshift(c, 8), 255) / 3
				b += bit32.band(bit32.rshift(c, 16), 255) / 3
			end
		elseif colorFn then
			r, g, b = colorFn(t)
		end
		local fill = px(r * tint[1] * shade, g * tint[2] * shade, b * tint[3] * shade)
		local iz0, iz1, iz2 = 1 / z0, 1 / z1, 1 / z2
		local minx = math.max(0, math.floor(math.min(sx0, sx1, sx2)))
		local maxx = math.min(w - 1, math.ceil(math.max(sx0, sx1, sx2)))
		local miny = math.max(0, math.floor(math.min(sy0, sy1, sy2)))
		local maxy = math.min(h - 1, math.ceil(math.max(sy0, sy1, sy2)))
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
					local i = (y * w + x) * 4
					if iz > buffer.readf32(zb, i) then
						buffer.writef32(zb, i, iz)
						buffer.writeu32(rgba, i, fill)
					end
				end
			end
		end
		if wire then
			line(self, sx0, sy0, z0, sx1, sy1, z1, wcol)
			line(self, sx1, sy1, z1, sx2, sy2, z2, wcol)
			line(self, sx2, sy2, z2, sx0, sy0, z0, wcol)
		end
	end
end

-- Depth-tested 3D line (ignores depth when `onTop`).
function MeshViz.line3(self: Viz, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, r: number, g: number, b: number, onTop: boolean?)
	local sx0, sy0, d0 = self:project(x0, y0, z0)
	local sx1, sy1, d1 = self:project(x1, y1, z1)
	if d0 <= 0.01 or d1 <= 0.01 then
		return
	end
	if onTop then
		d0, d1 = 1e-6, 1e-6
	end
	line(self, sx0, sy0, d0, sx1, sy1, d1, px(r, g, b))
end

-- Composite another viz side by side into a new RGBA buffer (for before/after images).
function MeshViz.sideBySide(a: Viz, b: Viz): (buffer, number, number)
	local w, h = a.w + b.w, math.max(a.h, b.h)
	local out = buffer.create(w * h * 4)
	for y = 0, h - 1 do
		if y < a.h then
			buffer.copy(out, (y * w) * 4, a.rgba, y * a.w * 4, a.w * 4)
		end
		if y < b.h then
			buffer.copy(out, (y * w + a.w) * 4, b.rgba, y * b.w * 4, b.w * 4)
		end
	end
	return out, w, h
end


-- Shaded/textured path (additive) -------------------------------------------------------------------------

export type Scene = {
	sky: { number }, -- ambient from above, and the Fresnel reflection colour (0..255)
	ground: { number }, -- ambient from below
	sun: { number }, -- sun colour x intensity (0..1 each)
	fog: { number }?, -- fog colour (0..255)
	fogDensity: number?, -- per world unit
}

export type ShadeOpts = {
	offset: { number }?,
	tstart: number?, -- first triangle (default 0)
	cull: boolean?,
	nrm: buffer?, -- f32 x3 per vertex (smooth shading); nil = face normal
	uv: buffer?, -- f32 x2 per vertex
	tex: buffer?, -- RGBA8 texture, bilinear, clamp
	tw: number?,
	th: number?,
	emit: buffer?, -- u8 per texel: self-lit fraction (lava glow)
	lightmap: buffer?, -- u8 per texel: sun visibility (shadows), lw x lh texels over the same UVs
	lw: number?,
	lh: number?,
	vcol: buffer?, -- u32 RGBA8 per vertex (interpolated; alpha used when useAlpha)
	useAlpha: boolean?,
	color: { number }?, -- constant base colour when no tex/vcol
	alpha: number?, -- global opacity (blended over; z written only when opaque)
	spec: number?, -- Blinn specular strength
	shininess: number?,
	fresnel: number?, -- 0..1 strength of sky reflection at grazing angles (water)
}

function MeshViz.scene(self: Viz, sc: Scene)
	(self :: any).sc = sc
end

-- Vertical gradient background (top colour -> bottom colour).
function MeshViz.clearSky(self: Viz, top: { number }, bottom: { number })
	local w, h, rgba, zb = self.w, self.h, self.rgba, self.z
	for y = 0, h - 1 do
		local t = y / math.max(h - 1, 1)
		local c = px(top[1] + (bottom[1] - top[1]) * t, top[2] + (bottom[2] - top[2]) * t, top[3] + (bottom[3] - top[3]) * t)
		for x = 0, w - 1 do
			buffer.writeu32(rgba, (y * w + x) * 4, c)
			buffer.writef32(zb, (y * w + x) * 4, 0)
		end
	end
end

local function texel(tex: buffer, tw: number, th: number, u: number, v: number): (number, number, number, number)
	local fx, fy = u * tw - 0.5, v * th - 0.5
	local x0, y0 = math.floor(fx), math.floor(fy)
	local ax, ay = fx - x0, fy - y0
	local x1, y1 = x0 + 1, y0 + 1
	x0 = if x0 < 0 then 0 elseif x0 >= tw then tw - 1 else x0
	x1 = if x1 < 0 then 0 elseif x1 >= tw then tw - 1 else x1
	y0 = if y0 < 0 then 0 elseif y0 >= th then th - 1 else y0
	y1 = if y1 < 0 then 0 elseif y1 >= th then th - 1 else y1
	local c00, c10 = buffer.readu32(tex, (y0 * tw + x0) * 4), buffer.readu32(tex, (y0 * tw + x1) * 4)
	local c01, c11 = buffer.readu32(tex, (y1 * tw + x0) * 4), buffer.readu32(tex, (y1 * tw + x1) * 4)
	local w00, w10, w01, w11 = (1 - ax) * (1 - ay), ax * (1 - ay), (1 - ax) * ay, ax * ay
	local r = bit32.band(c00, 255) * w00 + bit32.band(c10, 255) * w10 + bit32.band(c01, 255) * w01 + bit32.band(c11, 255) * w11
	local g = bit32.band(bit32.rshift(c00, 8), 255) * w00 + bit32.band(bit32.rshift(c10, 8), 255) * w10 + bit32.band(bit32.rshift(c01, 8), 255) * w01 + bit32.band(bit32.rshift(c11, 8), 255) * w11
	local b = bit32.band(bit32.rshift(c00, 16), 255) * w00 + bit32.band(bit32.rshift(c10, 16), 255) * w10 + bit32.band(bit32.rshift(c01, 16), 255) * w01 + bit32.band(bit32.rshift(c11, 16), 255) * w11
	local a = bit32.rshift(c00, 24) * w00 + bit32.rshift(c10, 24) * w10 + bit32.rshift(c01, 24) * w01 + bit32.rshift(c11, 24) * w11
	return r, g, b, a
end

local function sample8(m: buffer, tw: number, th: number, u: number, v: number): number
	local fx, fy = u * tw - 0.5, v * th - 0.5
	local x0, y0 = math.floor(fx), math.floor(fy)
	local ax, ay = fx - x0, fy - y0
	local x1, y1 = x0 + 1, y0 + 1
	x0 = if x0 < 0 then 0 elseif x0 >= tw then tw - 1 else x0
	x1 = if x1 < 0 then 0 elseif x1 >= tw then tw - 1 else x1
	y0 = if y0 < 0 then 0 elseif y0 >= th then th - 1 else y0
	y1 = if y1 < 0 then 0 elseif y1 >= th then th - 1 else y1
	local a = buffer.readu8(m, y0 * tw + x0) + (buffer.readu8(m, y0 * tw + x1) - buffer.readu8(m, y0 * tw + x0)) * ax
	local b = buffer.readu8(m, y1 * tw + x0) + (buffer.readu8(m, y1 * tw + x1) - buffer.readu8(m, y1 * tw + x0)) * ax
	return (a + (b - a) * ay) / 255
end

-- Smooth-shaded, optionally textured / translucent triangles. Draw opaque geometry first, translucent last.
function MeshViz.shaded(self: Viz, pos: buffer, idx: buffer, tcount: number, opts: ShadeOpts?)
	local o = opts or {} :: ShadeOpts
	local sc: Scene = (self :: any).sc or { sky = { 160, 190, 230 }, ground = { 70, 60, 50 }, sun = { 1, 0.95, 0.85 } }
	local off = o.offset or { 0, 0, 0 }
	local ox, oy, oz = off[1], off[2], off[3]
	local cull = o.cull ~= false
	local nrm, uvb, tex, emit, lmap, vcol = o.nrm, o.uv, o.tex, o.emit, o.lightmap, o.vcol
	local tw, th = o.tw or 1, o.th or 1
	local lw, lh = o.lw or tw, o.lh or th
	local useA = o.useAlpha == true
	local base = o.color or { 200, 200, 200 }
	local galpha = o.alpha or 1
	local spec, shin, fres = o.spec or 0, o.shininess or 40, o.fresnel or 0
	local w, h, zb, rgba = self.w, self.h, self.z, self.rgba
	local lx, ly, lz = self.lx, self.ly, self.lz
	local skr, skg, skb = sc.sky[1] / 255, sc.sky[2] / 255, sc.sky[3] / 255
	local gr, gg, gb = sc.ground[1] / 255, sc.ground[2] / 255, sc.ground[3] / 255
	local sr, sg, sb = sc.sun[1], sc.sun[2], sc.sun[3]
	local fog, fogD = sc.fog, sc.fogDensity or 0
	local fr, fgc, fb = 0, 0, 0
	if fog then
		fr, fgc, fb = fog[1], fog[2], fog[3]
	end
	local ex, ey, ez = self.ex, self.ey, self.ez
	for t = o.tstart or 0, tcount - 1 do
		local ia, ib, ic = buffer.readu32(idx, t * 12), buffer.readu32(idx, t * 12 + 4), buffer.readu32(idx, t * 12 + 8)
		local ax, ay, az = buffer.readf32(pos, ia * 12) + ox, buffer.readf32(pos, ia * 12 + 4) + oy, buffer.readf32(pos, ia * 12 + 8) + oz
		local bx, by, bz = buffer.readf32(pos, ib * 12) + ox, buffer.readf32(pos, ib * 12 + 4) + oy, buffer.readf32(pos, ib * 12 + 8) + oz
		local cx, cy, cz = buffer.readf32(pos, ic * 12) + ox, buffer.readf32(pos, ic * 12 + 4) + oy, buffer.readf32(pos, ic * 12 + 8) + oz
		local sx0, sy0, z0 = self:project(ax, ay, az)
		local sx1, sy1, z1 = self:project(bx, by, bz)
		local sx2, sy2, z2 = self:project(cx, cy, cz)
		if z0 <= 0.01 or z1 <= 0.01 or z2 <= 0.01 then
			continue
		end
		local area = (sx1 - sx0) * (sy2 - sy0) - (sx2 - sx0) * (sy1 - sy0)
		if area == 0 or (cull and area > 0) then
			continue
		end
		local minx = math.max(0, math.floor(math.min(sx0, sx1, sx2)))
		local maxx = math.min(w - 1, math.ceil(math.max(sx0, sx1, sx2)))
		local miny = math.max(0, math.floor(math.min(sy0, sy1, sy2)))
		local maxy = math.min(h - 1, math.ceil(math.max(sy0, sy1, sy2)))
		if minx > maxx or miny > maxy then
			continue
		end
		local fnx, fny, fnz = norm((by - ay) * (cz - az) - (bz - az) * (cy - ay), (bz - az) * (cx - ax) - (bx - ax) * (cz - az), (bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
		local n0x, n0y, n0z, n1x, n1y, n1z, n2x, n2y, n2z = fnx, fny, fnz, fnx, fny, fnz, fnx, fny, fnz
		if nrm then
			n0x, n0y, n0z = buffer.readf32(nrm, ia * 12), buffer.readf32(nrm, ia * 12 + 4), buffer.readf32(nrm, ia * 12 + 8)
			n1x, n1y, n1z = buffer.readf32(nrm, ib * 12), buffer.readf32(nrm, ib * 12 + 4), buffer.readf32(nrm, ib * 12 + 8)
			n2x, n2y, n2z = buffer.readf32(nrm, ic * 12), buffer.readf32(nrm, ic * 12 + 4), buffer.readf32(nrm, ic * 12 + 8)
		end
		local u0, v0, u1, v1, u2, v2 = 0, 0, 0, 0, 0, 0
		if uvb then
			u0, v0 = buffer.readf32(uvb, ia * 8), buffer.readf32(uvb, ia * 8 + 4)
			u1, v1 = buffer.readf32(uvb, ib * 8), buffer.readf32(uvb, ib * 8 + 4)
			u2, v2 = buffer.readf32(uvb, ic * 8), buffer.readf32(uvb, ic * 8 + 4)
		end
		local c0, c1, c2 = 0, 0, 0
		if vcol then
			c0, c1, c2 = buffer.readu32(vcol, ia * 4), buffer.readu32(vcol, ib * 4), buffer.readu32(vcol, ic * 4)
		end
		local iz0, iz1, iz2 = 1 / z0, 1 / z1, 1 / z2
		local inv = 1 / area
		for y = miny, maxy do
			local py = y + 0.5
			for x = minx, maxx do
				local pxx = x + 0.5
				local w0 = ((sx1 - pxx) * (sy2 - py) - (sx2 - pxx) * (sy1 - py)) * inv
				local w1 = ((sx2 - pxx) * (sy0 - py) - (sx0 - pxx) * (sy2 - py)) * inv
				local w2 = 1 - w0 - w1
				if w0 < 0 or w1 < 0 or w2 < 0 then
					continue
				end
				local iz = w0 * iz0 + w1 * iz1 + w2 * iz2
				local i = (y * w + x) * 4
				if iz <= buffer.readf32(zb, i) then
					continue
				end
				local zz = 1 / iz
				local b0, b1, b2 = w0 * iz0 * zz, w1 * iz1 * zz, w2 * iz2 * zz
				local nx, ny, nz = norm(b0 * n0x + b1 * n1x + b2 * n2x, b0 * n0y + b1 * n1y + b2 * n2y, b0 * n0z + b1 * n1z + b2 * n2z)
				if area > 0 then
					nx, ny, nz = -nx, -ny, -nz
				end
				local r, g, b, a = base[1], base[2], base[3], 255
				local u, v = 0, 0
				if uvb then
					u, v = b0 * u0 + b1 * u1 + b2 * u2, b0 * v0 + b1 * v1 + b2 * v2
				end
				if tex then
					r, g, b, a = texel(tex, tw, th, u, v)
				elseif vcol then
					r = b0 * bit32.band(c0, 255) + b1 * bit32.band(c1, 255) + b2 * bit32.band(c2, 255)
					g = b0 * bit32.band(bit32.rshift(c0, 8), 255) + b1 * bit32.band(bit32.rshift(c1, 8), 255) + b2 * bit32.band(bit32.rshift(c2, 8), 255)
					b = b0 * bit32.band(bit32.rshift(c0, 16), 255) + b1 * bit32.band(bit32.rshift(c1, 16), 255) + b2 * bit32.band(bit32.rshift(c2, 16), 255)
					a = b0 * bit32.rshift(c0, 24) + b1 * bit32.rshift(c1, 24) + b2 * bit32.rshift(c2, 24)
				end
				local alpha = galpha * (if useA then a / 255 else 1)
				-- lighting
				local hemi = ny * 0.5 + 0.5
				local ar, ag, ab = gr + (skr - gr) * hemi, gg + (skg - gg) * hemi, gb + (skb - gb) * hemi
				local lam = nx * lx + ny * ly + nz * lz
				if lam < 0 then
					lam = 0
				end
				local vis = if lmap then sample8(lmap, lw, lh, u, v) else 1
				local e = if emit then sample8(emit, tw, th, u, v) else 0
				local kr = ar * 0.55 + sr * lam * vis + e * 1.6
				local kg = ag * 0.55 + sg * lam * vis + e * 1.6
				local kb = ab * 0.55 + sb * lam * vis + e * 1.6
				r, g, b = r * kr, g * kg, b * kb
				local wx, wy, wz = b0 * ax + b1 * bx + b2 * cx, b0 * ay + b1 * by + b2 * cy, b0 * az + b1 * bz + b2 * cz
				local vx, vy, vz = ex - wx, ey - wy, ez - wz
				local dist = math.sqrt(vx * vx + vy * vy + vz * vz)
				vx, vy, vz = vx / dist, vy / dist, vz / dist
				if spec > 0 or fres > 0 then
					local ndv = math.max(nx * vx + ny * vy + nz * vz, 0)
					if fres > 0 then
						local f = fres * (0.04 + 0.96 * (1 - ndv) ^ 5)
						r, g, b = r + (sc.sky[1] - r) * f, g + (sc.sky[2] - g) * f, b + (sc.sky[3] - b) * f
						alpha += (1 - alpha) * f
					end
					if spec > 0 then
						local hx, hy, hz = norm(lx + vx, ly + vy, lz + vz)
						local s = spec * math.max(nx * hx + ny * hy + nz * hz, 0) ^ shin * vis * 255
						r, g, b = r + s * sr, g + s * sg, b + s * sb
						alpha += (1 - alpha) * math.min(s / 255, 1)
					end
				end
				if fogD > 0 then
					local f = 1 - math.exp(-dist * fogD)
					r, g, b = r + (fr - r) * f, g + (fgc - g) * f, b + (fb - b) * f
				end
				if alpha >= 0.999 then
					buffer.writef32(zb, i, iz)
					buffer.writeu32(rgba, i, px(r, g, b))
				else
					local cc = buffer.readu32(rgba, i)
					local k = 1 - alpha
					buffer.writeu32(rgba, i, px(r * alpha + bit32.band(cc, 255) * k, g * alpha + bit32.band(bit32.rshift(cc, 8), 255) * k, b * alpha + bit32.band(bit32.rshift(cc, 16), 255) * k))
				end
			end
		end
	end
end

-- Box-filter downsample by an integer factor (SSAA resolve). Returns a new RGBA buffer and its size.
function MeshViz.downsample(self: Viz, k: number): (buffer, number, number)
	local w, h = self.w // k, self.h // k
	local out, src, sw = buffer.create(w * h * 4), self.rgba, self.w
	local n = k * k
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local r, g, b = 0, 0, 0
			for dy = 0, k - 1 do
				for dx = 0, k - 1 do
					local c = buffer.readu32(src, ((y * k + dy) * sw + x * k + dx) * 4)
					r += bit32.band(c, 255)
					g += bit32.band(bit32.rshift(c, 8), 255)
					b += bit32.band(bit32.rshift(c, 16), 255)
				end
			end
			buffer.writeu32(out, (y * w + x) * 4, px(r / n + 0.5, g / n + 0.5, b / n + 0.5))
		end
	end
	return out, w, h
end

-- Soft sun visibility over a heightfield (cell-centred f64 heights, `cell` world units apart), u8 per texel at
-- `res` texels per cell (so magnified shadow edges stay smooth). Marches toward the light through bilinear
-- heights; the smallest clearance/distance ratio gives a penumbra. Preview-only shadows.
function MeshViz.heightShadow(hgt: buffer, w: number, h: number, cell: number, lx: number, ly: number, lz: number, soft: number?, res: number?): buffer
	local R = res or 1
	local W, H = w * R, h * R
	local out = buffer.create(W * H)
	local hl = math.sqrt(lx * lx + lz * lz)
	local dx, dz = lx / hl, lz / hl
	local rise = ly / hl * cell -- height gained per cell stepped toward the sun
	local k = soft or 6
	local maxSteps = math.max(w, h)
	local function hgtAt(fx: number, fz: number): number
		fx = math.clamp(fx, 0, w - 1)
		fz = math.clamp(fz, 0, h - 1)
		local ix, iz = math.floor(fx), math.floor(fz)
		local ax, az = fx - ix, fz - iz
		local ix1, iz1 = math.min(ix + 1, w - 1), math.min(iz + 1, h - 1)
		local h00, h10 = buffer.readf64(hgt, (iz * w + ix) * 8), buffer.readf64(hgt, (iz * w + ix1) * 8)
		local h01, h11 = buffer.readf64(hgt, (iz1 * w + ix) * 8), buffer.readf64(hgt, (iz1 * w + ix1) * 8)
		local a = h00 + (h10 - h00) * ax
		return a + ((h01 + (h11 - h01) * ax) - a) * az
	end
	for Y = 0, H - 1 do
		local y = (Y + 0.5) / R - 0.5
		for X = 0, W - 1 do
			local x = (X + 0.5) / R - 0.5
			local h0 = hgtAt(x, y) + 0.05
			local best = 1
			for s = 0.5, maxSteps, 0.5 do
				local fx, fz = x + dx * s, y + dz * s
				if fx < 0 or fz < 0 or fx > w - 1 or fz > h - 1 then
					break
				end
				local clear = h0 + rise * s - hgtAt(fx, fz)
				local r = k * clear / (s * cell)
				if r < best then
					best = r
					if best <= -1 then
						break
					end
				end
				if clear > 60 then
					break
				end
			end
			local v = math.clamp(best * 0.5 + 0.5, 0, 1)
			buffer.writeu8(out, Y * W + X, math.floor(v * v * (3 - 2 * v) * 255 + 0.5))
		end
	end
	return out
end

return MeshViz
