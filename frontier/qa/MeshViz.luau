--!native
--!optimize 2
-- MeshViz: headless triangle rasteriser for QA. Perspective or orthographic look-at camera, z-buffer
-- (stores 1/depth), flat Lambert shading from the face normal, back-face culling (CCW = front), optional
-- depth-tested wireframe overlay. Output is an RGBA8 buffer for Out.image.

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

return MeshViz
