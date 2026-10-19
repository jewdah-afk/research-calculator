--!native
--!optimize 2
-- Comanche-style "Voxel Space" heightmap terrain (NovaLogic 1992).
-- For each depth slice z (front to back, step growing with distance) project a line of map
-- samples across the screen columns; each column keeps a y-buffer (highest pixel drawn so far)
-- and only draws the vertical span that pokes above it, so every screen pixel is written once.
-- Cost: O(columns * slices) map samples plus O(pixels) span writes; no per-pixel depth test.
-- Fog is a per-slice blend toward the horizon colour; the sky is a per-row gradient written
-- into whatever each column left uncovered.
-- Temporal checkerboard: render only even or odd columns per frame and keep the rest from the
-- previous frame (half the cost; stale columns smear slightly during fast turns).
-- The map generator bakes fBm/ridged Perlin height, water, beaches, rock on slopes, snow caps,
-- Lambert + swept sun shadows + cavity AO into a colour map.

local VS = {}
VS.__index = VS

local HEIGHT = 120 -- map height units for normalised height 1 (texels are 1 unit wide)

export type Map = {
	size: number,
	mask: number,
	height: buffer, -- u8 per texel (water already flattened to the water level)
	color: buffer, -- u32 RGBA per texel, lighting baked in
	water: number, -- water level in height units
}

export type Camera = {
	x: number,
	y: number,
	height: number,
	yaw: number, -- radians, 0 looks toward -y
	pitch: number, -- shifts the horizon, in screen heights (0.2 = look down a fifth of the screen)
	horizon: number, -- base horizon row (pixels)
	distance: number, -- far plane in map texels
	scale: number, -- vertical projection scale (pixels per height unit at z = 1)
}

export type VoxelSpace = typeof(setmetatable(
	{} :: {
		w: number,
		h: number,
		map: Map,
		cam: Camera,
		rgba: buffer,
		ybuf: buffer, -- i32 per column
		sky: buffer, -- u32 per row
		skyTop: { number },
		skyHorizon: { number },
		frame: number,
	},
	VS
))

-- Map generation --------------------------------------------------------------------------------

local function makePerm(seed: number): buffer
	local p = buffer.create(512)
	for i = 0, 255 do
		buffer.writeu8(p, i, i)
	end
	local s = seed
	for i = 255, 1, -1 do
		s = (s * 1103515245 + 12345) % 2147483648
		local j = s % (i + 1)
		local a, b = buffer.readu8(p, i), buffer.readu8(p, j)
		buffer.writeu8(p, i, b)
		buffer.writeu8(p, j, a)
	end
	buffer.copy(p, 256, p, 0, 256)
	return p
end

local function grad(p: buffer, hx: number, hy: number, dx: number, dy: number): number
	local hsh = bit32.band(buffer.readu8(p, buffer.readu8(p, hx) + hy), 7)
	if hsh == 0 then return dx + dy
	elseif hsh == 1 then return -dx + dy
	elseif hsh == 2 then return dx - dy
	elseif hsh == 3 then return -dx - dy
	elseif hsh == 4 then return dx * 1.4142
	elseif hsh == 5 then return -dx * 1.4142
	elseif hsh == 6 then return dy * 1.4142
	else return -dy * 1.4142 end
end

-- Tileable 2D Perlin noise with period `per` (power of two <= 256). Returns roughly [-1, 1].
local function perlin(p: buffer, x: number, y: number, per: number): number
	local m = per - 1
	local xi, yi = math.floor(x), math.floor(y)
	local xf, yf = x - xi, y - yi
	local x0, y0 = bit32.band(xi, m), bit32.band(yi, m)
	local x1, y1 = bit32.band(xi + 1, m), bit32.band(yi + 1, m)
	local u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
	local v = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
	local a = grad(p, x0, y0, xf, yf)
	local b = grad(p, x1, y0, xf - 1, yf)
	local c = grad(p, x0, y1, xf, yf - 1)
	local d = grad(p, x1, y1, xf - 1, yf - 1)
	local ab = a + (b - a) * u
	local cd = c + (d - c) * u
	return (ab + (cd - ab) * v) * 0.7
end

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function at(hf: buffer, size: number, mask: number, wl: number, x: number, y: number, dx: number, dy: number): number
	return math.max(buffer.readf32(hf, (bit32.band(y + dy, mask) * size + bit32.band(x + dx, mask)) * 4), wl)
end

-- Procedural tileable terrain. size must be a power of two (256..1024).
function VS.generate(size: number, seed: number?): Map
	local perm = makePerm(seed or 7)
	local n = size * size
	local hf = buffer.create(n * 4) -- f32 heights 0..1
	local base = 4 -- lattice cells across the map for the lowest octave
	local lo, hi = math.huge, -math.huge
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local fx, fy = x / size, y / size
			-- continent mask (low frequency) decides plains vs mountains
			local cont = (perlin(perm, fx * 4 + 0.31, fy * 4 + 0.77, 4) + perlin(perm, fx * 8 + 5.3, fy * 8 + 1.9, 8) * 0.35) * 0.55 + 0.5
			local f, amp, per, sum, ridged, ramp = 0, 0.5, base, 0, 0, 0.9
			for o = 0, 6 do
				local nv = perlin(perm, fx * per + o * 17.1, fy * per + o * 9.7, per)
				f += nv * amp
				if o >= 1 then -- ridges from the second octave up (lowest octave creases look like straight seams)
					local r = 1 - math.abs(nv)
					ridged += r * r * ramp * (0.5 + 0.5 * math.min(1, ridged * 2))
				end
				sum += amp
				amp *= 0.5
				ramp *= 0.5
				per *= 2
			end
			f = f / sum * 0.5 + 0.5
			local mtn = smooth(0.45, 0.75, cont)
			local hgt = f * 0.55 + mtn * ridged * 0.75 + cont * 0.25
			buffer.writef32(hf, (y * size + x) * 4, hgt)
			lo = math.min(lo, hgt)
			hi = math.max(hi, hgt)
		end
	end
	for i = 0, n - 1 do
		local v = (buffer.readf32(hf, i * 4) - lo) / (hi - lo)
		buffer.writef32(hf, i * 4, v ^ 1.35) -- flatter lowlands, sharper peaks
	end

	local waterLevel = 0.2
	local mask = size - 1
	local height = buffer.create(n)
	local color = buffer.create(n * 4)
	-- sun shadows: sweep each row from the sun side (sun low in the +x direction)
	local shadow = buffer.create(n)
	local sunSlope = 0.55 / HEIGHT -- sun elevation ~29 degrees: height lost per texel along the ray
	for y = 0, size - 1 do
		local hs = 0
		for pass = 0, 1 do -- second pass wraps around so the seam is shadowed correctly
			for x = size - 1, 0, -1 do
				local i = y * size + x
				local v = math.max(buffer.readf32(hf, i * 4), waterLevel)
				hs -= sunSlope
				if v >= hs then
					hs = v
					if pass == 1 then buffer.writeu8(shadow, i, 0) end
				elseif pass == 1 then
					buffer.writeu8(shadow, i, math.min(255, (hs - v) * HEIGHT * 12 // 1))
				end
			end
		end
	end
	local lx, ly, lz = 0.75, -0.2, 0.62 -- sun direction (x east, y south, z up), normalised below
	local ll = math.sqrt(lx * lx + ly * ly + lz * lz)
	lx, ly, lz = lx / ll, ly / ll, lz / ll
	local hscale = HEIGHT -- map units per unit of normalised height
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local i = y * size + x
			local v = buffer.readf32(hf, i * 4)
			local hx = (at(hf, size, mask, waterLevel, x, y, 1, 0) - at(hf, size, mask, waterLevel, x, y, -1, 0)) * hscale * 0.5
			local hy = (at(hf, size, mask, waterLevel, x, y, 0, 1) - at(hf, size, mask, waterLevel, x, y, 0, -1)) * hscale * 0.5
			local nx, ny, nz = -hx, -hy, 1
			local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
			nx, ny, nz = nx / nl, ny / nl, nz / nl
			local slope = 1 - nz
			local lam = math.max(0, nx * lx + ny * ly + nz * lz)
			local sh = 1 - math.min(1, buffer.readu8(shadow, i) / 60) * 0.75
			-- cavity: how far below the local average this texel sits
			local avg = (at(hf, size, mask, waterLevel, x, y, 4, 0) + at(hf, size, mask, waterLevel, x, y, -4, 0) + at(hf, size, mask, waterLevel, x, y, 0, 4) + at(hf, size, mask, waterLevel, x, y, 0, -4) + at(hf, size, mask, waterLevel, x, y, 3, 3) + at(hf, size, mask, waterLevel, x, y, -3, -3) + at(hf, size, mask, waterLevel, x, y, 3, -3) + at(hf, size, mask, waterLevel, x, y, -3, 3)) / 8
			local ao = math.clamp(1 + (math.max(v, waterLevel) - avg) * 18, 0.55, 1.15)
			local jitter = perlin(perm, x * 0.11, y * 0.11, 64) * 0.5 + 0.5
			local r, g, b
			local hv = waterLevel * HEIGHT
			if v < waterLevel then
				local depth = math.clamp((waterLevel - v) / 0.12, 0, 1)
				r, g, b = mix(70, 18, depth), mix(150, 62, depth), mix(160, 112, depth)
				local lit = 0.85 + 0.15 * sh
				r, g, b = r * lit, g * lit, b * lit
			else
				local e = (v - waterLevel) / (1 - waterLevel) -- elevation above water, 0..1
				-- grass -> dry grass -> rock -> snow, with slope pushing toward rock
				r, g, b = mix(78, 104, jitter), mix(118, 128, jitter), mix(52, 62, jitter)
				local dry = smooth(0.25, 0.45, e + jitter * 0.08)
				r, g, b = mix(r, 128, dry), mix(g, 120, dry), mix(b, 72, dry)
				local rock = math.max(smooth(0.5, 0.7, e + jitter * 0.1), smooth(0.35, 0.6, slope))
				r, g, b = mix(r, 118 + jitter * 20, rock), mix(g, 106 + jitter * 16, rock), mix(b, 96 + jitter * 12, rock)
				local snow = smooth(0.56, 0.62, e + jitter * 0.06 - slope * 0.35)
				r, g, b = mix(r, 236, snow), mix(g, 240, snow), mix(b, 248, snow)
				local sand = 1 - smooth(0.01, 0.035, e)
				r, g, b = mix(r, 206, sand), mix(g, 190, sand), mix(b, 140, sand)
				local lit = (0.3 + 0.95 * lam * sh) * ao
				r, g, b = r * lit, g * lit, b * lit
				hv = v * HEIGHT
			end
			buffer.writeu8(height, i, math.clamp(hv // 1, 0, 255))
			buffer.writeu32(color, i * 4, math.clamp(r // 1, 0, 255) + math.clamp(g // 1, 0, 255) * 256 + math.clamp(b // 1, 0, 255) * 65536 + 0xFF000000)
		end
	end
	return { size = size, mask = mask, height = height, color = color, water = waterLevel * HEIGHT }
end

-- Renderer -----------------------------------------------------------------------------------------

function VS.new(w: number, h: number, map: Map): VoxelSpace
	return setmetatable({
		w = w,
		h = h,
		map = map,
		cam = {
			x = 0,
			y = 0,
			height = 200,
			yaw = 0,
			pitch = 0,
			horizon = h * 0.4,
			distance = 700,
			scale = h * 0.9,
		},
		rgba = buffer.create(w * h * 4),
		ybuf = buffer.create(w * 4),
		sky = buffer.create(h * 4),
		skyTop = { 58, 104, 178 },
		skyHorizon = { 196, 214, 228 },
		frame = 0,
	}, VS)
end

-- Height of the map under a world position (for keeping the camera above ground).
function VS.heightAt(self: VoxelSpace, x: number, y: number): number
	local m = self.map
	return buffer.readu8(m.height, bit32.band(y // 1, m.mask) * m.size + bit32.band(x // 1, m.mask))
end

-- Render columns first, first+step, ... (step 1 = full frame, 2 = one checkerboard field).
local function renderColumns(self: VoxelSpace, first: number, step: number)
	local w, h, rgba, ybuf, sky = self.w, self.h, self.rgba, self.ybuf, self.sky
	local cam, map = self.cam, self.map
	local hmap, cmap, size, mask = map.height, map.color, map.size, map.mask
	local horizon = cam.horizon - cam.pitch * h
	local camH, scale, far = cam.height, cam.scale, cam.distance
	local sinA, cosA = math.sin(cam.yaw), math.cos(cam.yaw)
	local fr, fg, fb = self.skyHorizon[1], self.skyHorizon[2], self.skyHorizon[3]

	-- sky gradient rows (top colour -> horizon colour at the horizon row)
	local tr, tg, tb = self.skyTop[1], self.skyTop[2], self.skyTop[3]
	for y = 0, h - 1 do
		local t = math.clamp(y / math.max(1, horizon), 0, 1)
		t = t * t * t
		buffer.writeu32(sky, y * 4, (tr + (fr - tr) * t) // 1 + ((tg + (fg - tg) * t) // 1) * 256 + ((tb + (fb - tb) * t) // 1) * 65536 + 0xFF000000)
	end

	for x = first, w - 1, step do
		buffer.writei32(ybuf, x * 4, h)
	end
	local cols = (w - first + step - 1) // step
	local remaining = cols
	local z, dz = 1, 0.5
	local stride = w * 4
	while z < far and remaining > 0 do
		-- view-plane line at depth z: from (-z, -z) to (z, -z) rotated by yaw (90 degree FOV)
		local plx = -cosA * z - sinA * z
		local ply = sinA * z - cosA * z
		local prx = cosA * z - sinA * z
		local pry = -sinA * z - cosA * z
		local dx = (prx - plx) / w
		local dy = (pry - ply) / w
		plx += cam.x + dx * (first + 0.5)
		ply += cam.y + dy * (first + 0.5)
		dx *= step
		dy *= step
		local invz = scale / z
		-- fog: 0 near, 1 at the far plane (smooth start)
		local f = math.clamp((z / far - 0.25) / 0.75, 0, 1)
		local fog = (f * f * (3 - 2 * f) * 256) // 1
		local keep = 256 - fog
		local fogR, fogG, fogB = fr * fog, fg * fog, fb * fog
		for x = first, w - 1, step do
			local yb = buffer.readi32(ybuf, x * 4)
			if yb > 0 then
				local idx = bit32.band(ply // 1, mask) * size + bit32.band(plx // 1, mask)
				local sy = ((camH - buffer.readu8(hmap, idx)) * invz + horizon) // 1
				if sy < 0 then
					sy = 0
				end
				if sy < yb then
					local c = buffer.readu32(cmap, idx * 4)
					local r = (bit32.band(c, 255) * keep + fogR) // 256
					local g = (bit32.band(bit32.rshift(c, 8), 255) * keep + fogG) // 256
					local b = (bit32.band(bit32.rshift(c, 16), 255) * keep + fogB) // 256
					local px = r + g * 256 + b * 65536 + 0xFF000000
					local o = (sy * w + x) * 4
					for _ = sy, yb - 1 do
						buffer.writeu32(rgba, o, px)
						o += stride
					end
					buffer.writei32(ybuf, x * 4, sy)
					if sy == 0 then
						remaining -= 1
					end
				end
			end
			plx += dx
			ply += dy
		end
		z += dz
		dz *= 1.012
	end
	-- sky fills whatever each column left uncovered
	for x = first, w - 1, step do
		local yb = buffer.readi32(ybuf, x * 4)
		local o = x * 4
		for y = 0, yb - 1 do
			buffer.writeu32(rgba, o, buffer.readu32(sky, y * 4))
			o += stride
		end
	end
end

function VS.render(self: VoxelSpace)
	renderColumns(self, 0, 1)
	self.frame += 1
end

-- Temporal checkerboard: only every other column, alternating each call.
function VS.renderCheckerboard(self: VoxelSpace)
	renderColumns(self, self.frame % 2, 2)
	self.frame += 1
end

-- Roblox only ------------------------------------------------------------------------------------
function VS.present(self: VoxelSpace, img: any)
	img:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(self.w, self.h), self.rgba)
end

return VS
