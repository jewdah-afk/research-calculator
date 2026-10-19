--!native
--!optimize 2
-- Real lightmaps for a 3D room from 2D radiance cascades. The GI grid is the floor plan: walls are
-- occluders, lamps are analytic disc lights (moving one costs no re-bake), lava pools and other
-- glowing floor features are emissive solids; light leaving the plan (doorways, windows) is `sky`.
-- Outputs, RGBA8 straight alpha, ready for EditableImage:WritePixelsBuffer:
--   floor: floor albedo x GI fluence (x optional contrast curve) x contact AO, tonemapped,
--          texScale texels per plan pixel.
--   atlas: one light strip per exposed wall face (GI sampled just outside the face along its
--          length, x brick albedo, x height falloff), packed on an Atlas page; face.region gives
--          the UV rect for that face's wall mesh.
-- update() is the rebuildOnChange flow: free when nothing changed; an edit re-runs GI (incremental
-- in RadianceCascades) and rebuilds the textures. update(budgetMs) is the amortized flow: GI is
-- time-sliced, the textures are rebuilt in row slices after each GI cycle, and the floor patch
-- around a moved lamp is re-lit every frame.

local RC = require("../fx/RadianceCascades")
local Atlas = require("../Atlas")

local LM = {}
LM.__index = LM

type Wall = { x0: number, y0: number, x1: number, y1: number, r: number, g: number, b: number, height: number }
type Emitter = { x0: number, y0: number, x1: number, y1: number, r: number, g: number, b: number }
export type Lamp = { x: number, y: number, radius: number, r: number, g: number, b: number, height: number }
export type Face = {
	wall: number,
	ax: number, -- plan segment A -> B (u runs A -> B, v runs top -> bottom)
	ay: number,
	bx: number,
	by: number,
	nx: number, -- outward normal
	ny: number,
	len: number,
	height: number,
	region: Atlas.Region,
}

export type Lightmap = typeof(setmetatable(
	{} :: {
		rc: RC.RadianceCascades,
		w: number,
		h: number,
		texScale: number,
		fw: number,
		fh: number,
		floorAlbedo: buffer, -- RGBA8, fw x fh
		floor: buffer, -- RGBA8 lit floor, fw x fh
		lit: buffer, -- f32 RGB per plan pixel: light term for the floor
		atlas: Atlas.Page,
		faces: { Face },
		walls: { Wall },
		emitters: { Emitter },
		lamps: { [number]: Lamp },
		wallHeight: number,
		wallTexScale: number,
		stripH: number,
		floorGain: number,
		contrast: number, -- > 1 deepens light pools (2D GI falls off as 1/r, a 3D room looks closer to 1/r^2)
		wallGain: number,
		settle: number,
		strip: buffer,
		col: buffer,
		geomDirty: boolean,
		lightDirty: boolean,
		floorRow: number, -- amortized texture job: next floor row (-1 = not on the floor)
		faceIdx: number, -- then the next wall face (0 = idle)
		again: boolean, -- a GI cycle landed mid-job: run the job once more
		patchMs: number, -- cost of last frame's floor patch (taken out of the GI budget)
		version: number, -- bumps whenever floor or atlas content changed
		stats: { [string]: number },
	},
	LM
))

local function hash(x: number, y: number): number
	local n = (x * 374761393 + y * 668265263) % 2147483647
	n = (n * (n % 1013 + 1277)) % 1000003
	return n / 1000003
end

-- Default floor albedo: 16-pixel stone tiles with grout and per-tile variation.
local function defaultFloor(self: Lightmap)
	local fw, fh, a = self.fw, self.fh, self.floorAlbedo
	local tile = 16 * self.texScale
	for y = 0, fh - 1 do
		for x = 0, fw - 1 do
			local tx, ty = x // tile, y // tile
			local lx, ly = x % tile, y % tile
			local v = 0.78 + 0.22 * hash(tx, ty)
			local grain = 0.92 + 0.08 * hash(x, y)
			local grout = (lx < self.texScale or ly < self.texScale)
			local k = if grout then 0.45 else v * grain
			local r, g, b = 0.62 * k, 0.58 * k, 0.54 * k
			buffer.writeu32(a, (y * fw + x) * 4, (r * 255) // 1 + ((g * 255) // 1) * 256 + ((b * 255) // 1) * 65536 + 0xFF000000)
		end
	end
end

function LM.new(w: number, h: number, opts: { [string]: any }?): Lightmap
	local o = opts or {}
	local s: number = o.texScale or 2
	local rc = RC.new(w, h, {
		spacing = o.spacing or 2,
		exposure = o.exposure or 0.5,
		sky = o.sky or { 0, 0, 0 },
		settle = o.settle or 6,
		bounce = o.bounce or 1,
	})
	local self = setmetatable({
		rc = rc,
		w = w,
		h = h,
		texScale = s,
		fw = w * s,
		fh = h * s,
		floorAlbedo = buffer.create(w * s * h * s * 4),
		floor = buffer.create(w * s * h * s * 4),
		lit = buffer.create(w * h * 12),
		atlas = Atlas.newPage(1, o.atlasSize or 1024, 1),
		faces = {},
		walls = {},
		emitters = {},
		lamps = {},
		wallHeight = o.wallHeight or 40,
		wallTexScale = o.wallTexScale or 1,
		stripH = o.stripH or 60,
		floorGain = o.floorGain or 1,
		contrast = o.contrast or 1,
		wallGain = o.wallGain or 1.5,
		settle = o.settle or 6,
		strip = buffer.create(4),
		col = buffer.create(4),
		geomDirty = true,
		lightDirty = true,
		floorRow = -1,
		faceIdx = 0,
		again = false,
		patchMs = 0,
		version = 0,
		stats = { floorMs = 0, wallsMs = 0, giMs = 0 },
	}, LM)
	defaultFloor(self)
	return self
end

-- Scene ------------------------------------------------------------------------------------------

-- Wall box [x0,x1) x [y0,y1) in plan pixels with albedo; height in plan pixels (3D extrusion).
function LM.addWall(self: Lightmap, x0: number, y0: number, x1: number, y1: number, r: number?, g: number?, b: number?, height: number?): number
	table.insert(self.walls, { x0 = x0, y0 = y0, x1 = x1, y1 = y1, r = r or 0.6, g = g or 0.58, b = b or 0.55, height = height or self.wallHeight })
	self.geomDirty = true
	return #self.walls
end

function LM.removeWall(self: Lightmap, id: number)
	table.remove(self.walls, id)
	self.geomDirty = true
end

-- Glowing floor feature (lava, a light panel): an emissive solid on the plan.
function LM.addEmitter(self: Lightmap, x0: number, y0: number, x1: number, y1: number, r: number, g: number, b: number): number
	table.insert(self.emitters, { x0 = x0, y0 = y0, x1 = x1, y1 = y1, r = r, g = g, b = b })
	self.geomDirty = true
	return #self.emitters
end

-- Lamp id 1..16 at plan (x, y): analytic light, so moving it never touches geometry.
function LM.setLamp(self: Lightmap, id: number, x: number, y: number, radius: number, r: number, g: number, b: number, height: number?)
	local l = self.lamps[id]
	if l then -- reuse: a lamp moved every frame allocates nothing
		l.x, l.y, l.radius, l.r, l.g, l.b, l.height = x, y, radius, r, g, b, height or l.height
	else
		self.lamps[id] = { x = x, y = y, radius = radius, r = r, g = g, b = b, height = height or self.wallHeight * 0.6 }
	end
	self.rc:setLight(id, x, y, radius, r, g, b)
	self.lightDirty = true
end

function LM.removeLamp(self: Lightmap, id: number)
	self.lamps[id] = nil
	self.rc:removeLight(id)
	self.lightDirty = true
end

-- Floor albedo from a function of the texel (x, y) -> r, g, b in 0..1.
function LM.setFloorAlbedo(self: Lightmap, fn: (number, number) -> (number, number, number))
	local fw, a = self.fw, self.floorAlbedo
	for y = 0, self.fh - 1 do
		for x = 0, fw - 1 do
			local r, g, b = fn(x, y)
			buffer.writeu32(a, (y * fw + x) * 4, math.clamp(r * 255 // 1, 0, 255) + math.clamp(g * 255 // 1, 0, 255) * 256 + math.clamp(b * 255 // 1, 0, 255) * 65536 + 0xFF000000)
		end
	end
	self.lightDirty = true
end

-- Rasterise the plan into the GI scene and lay out one atlas strip per exposed wall face.
local function rebuildGeometry(self: Lightmap)
	local rc, w, h = self.rc, self.w, self.h
	rc:clear()
	for _, wl in self.walls do
		rc:rect(wl.x0, wl.y0, wl.x1, wl.y1, 0, 0, 0, wl.r, wl.g, wl.b)
	end
	for _, e in self.emitters do
		rc:rect(e.x0, e.y0, e.x1, e.y1, e.r, e.g, e.b, 0, 0, 0)
	end
	for _, f in self.faces do
		Atlas.free(f.region)
	end
	table.clear(self.faces)
	local solid = rc.solid
	local function open(x: number, y: number): boolean
		return x >= 0 and y >= 0 and x < w and y < h and buffer.readu8(solid, (y // 1) * w + x // 1) == 0
	end
	local maxW = 1
	for wi, wl in self.walls do
		-- faces wound so the outward normal is on the left of A -> B when seen from outside
		local quads = {
			{ wl.x0, wl.y0, wl.x1, wl.y0, 0, -1 }, -- north
			{ wl.x1, wl.y0, wl.x1, wl.y1, 1, 0 }, -- east
			{ wl.x1, wl.y1, wl.x0, wl.y1, 0, 1 }, -- south
			{ wl.x0, wl.y1, wl.x0, wl.y0, -1, 0 }, -- west
		}
		for _, q in quads do
			local ax, ay, bx, by, nx, ny = q[1], q[2], q[3], q[4], q[5], q[6]
			local len = math.abs(bx - ax) + math.abs(by - ay)
			local dx, dy = (bx - ax) / len, (by - ay) / len
			local exposed = false
			for t = 0, len - 1 do
				if open(ax + dx * (t + 0.5) + nx * 1.5, ay + dy * (t + 0.5) + ny * 1.5) then
					exposed = true
					break
				end
			end
			if exposed then
				local sw = math.max(1, math.floor(len * self.wallTexScale + 0.5))
				local region = Atlas.alloc(self.atlas, sw, self.stripH)
				assert(region, "Lightmap: wall atlas page is full (raise atlasSize or lower wallTexScale)")
				maxW = math.max(maxW, sw)
				table.insert(self.faces, {
					wall = wi, ax = ax, ay = ay, bx = bx, by = by, nx = nx, ny = ny, len = len,
					height = wl.height, region = region :: Atlas.Region,
				})
			end
		end
	end
	if buffer.len(self.strip) < maxW * self.stripH * 4 then
		self.strip = buffer.create(maxW * self.stripH * 4)
		self.col = buffer.create(maxW * 12)
	end
	self.geomDirty = false
end

-- Textures ---------------------------------------------------------------------------------------

-- Bilinear GI fluence at plan point (x, y) (pixel centres at +0.5).
local function fluenceAt(fl: buffer, w: number, h: number, x: number, y: number): (number, number, number)
	local vx, vy = math.clamp(x - 0.5, 0, w - 1.001), math.clamp(y - 0.5, 0, h - 1.001)
	local x0, y0 = vx // 1, vy // 1
	local fx, fy = vx - x0, vy - y0
	local i00 = (y0 * w + x0) * 12
	local i10, i01 = i00 + 12, i00 + w * 12
	local i11 = i01 + 12
	local a, b, c, d = (1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy
	return a * buffer.readf32(fl, i00) + b * buffer.readf32(fl, i10) + c * buffer.readf32(fl, i01) + d * buffer.readf32(fl, i11),
		a * buffer.readf32(fl, i00 + 4) + b * buffer.readf32(fl, i10 + 4) + c * buffer.readf32(fl, i01 + 4) + d * buffer.readf32(fl, i11 + 4),
		a * buffer.readf32(fl, i00 + 8) + b * buffer.readf32(fl, i10 + 8) + c * buffer.readf32(fl, i01 + 8) + d * buffer.readf32(fl, i11 + 8)
end

-- Contrast curve on GI: scale by (luminance / pivot)^(contrast - 1), pivot = mid grey after exposure.
local function curve(k: number, pivot: number, r: number, g: number, b: number): (number, number, number)
	if k == 1 then
		return r, g, b
	end
	local l = (r + g + b) * (1 / 3) + 1e-6
	local m = (l * pivot) ^ (k - 1)
	return r * m, g * m, b * m
end

-- Per plan pixel: GI fluence x contrast curve x contact AO x exposure (the floor's light term).
local function prepLit(self: Lightmap, px0: number, py0: number, px1: number, py1: number)
	local rc = self.rc
	local w, fl, sdf, lit = self.w, rc.fluence, rc.sdf, self.lit
	local ex = rc.exposure * 128 * self.floorGain / 255
	local k, pivot = self.contrast, rc.exposure * 4
	for y = py0, py1 - 1 do
		for i = y * w + px0, y * w + px1 - 1 do
			local o = i * 12
			local r, g, b = curve(k, pivot, buffer.readf32(fl, o), buffer.readf32(fl, o + 4), buffer.readf32(fl, o + 8))
			local d = math.clamp((buffer.readf32(sdf, i * 4) - 0.5) / 10, 0, 1)
			local ao = (0.5 + 0.5 * d * (2 - d)) * ex
			buffer.writef32(lit, o, r * ao)
			buffer.writef32(lit, o + 4, g * ao)
			buffer.writef32(lit, o + 8, b * ao)
		end
	end
end

-- Lit floor texels [tx0,tx1) x [ty0,ty1): albedo x bilinear light term, emissive features glow.
local function buildFloor(self: Lightmap, tx0: number, ty0: number, tx1: number, ty1: number)
	local rc = self.rc
	local w, h, s, fw = self.w, self.h, self.texScale, self.fw
	local solid, emis, lut, lit = rc.solid, rc.emis, rc.lut, self.lit
	local alb, out = self.floorAlbedo, self.floor
	local eg0 = 128 * rc.exposure
	local inv = 1 / s
	prepLit(self, math.max(0, tx0 // s - 1), math.max(0, ty0 // s - 1), math.min(w, (tx1 + s - 1) // s + 1), math.min(h, (ty1 + s - 1) // s + 1))
	for ty = ty0, ty1 - 1 do
		local py = (ty + 0.5) * inv
		local row = (py // 1) * w
		local vy = math.clamp(py - 0.5, 0, h - 1.001)
		local y0 = vy // 1
		local fy = vy - y0
		local gy = 1 - fy
		for tx = tx0, tx1 - 1 do
			local px = (tx + 0.5) * inv
			local ip = row + px // 1
			local o = (ty * fw + tx) * 4
			local r, g, b
			if buffer.readu8(solid, ip) ~= 0 then
				local er, eg, eb = buffer.readf32(emis, ip * 12), buffer.readf32(emis, ip * 12 + 4), buffer.readf32(emis, ip * 12 + 8)
				if er + eg + eb > 0 then
					-- glowing feature: its own emission with a slow crusty pattern
					local q = (0.55 + 0.45 * hash(tx // 3, ty // 3) * hash(tx // 7 + 11, ty // 7)) * eg0
					r, g, b = er * q, eg * q * q / eg0, eb * q * q / eg0
				else
					r, g, b = 0, 0, 0 -- under a wall
				end
			else
				local vx = math.clamp(px - 0.5, 0, w - 1.001)
				local x0 = vx // 1
				local fx = vx - x0
				local i00 = (y0 * w + x0) * 12
				local i01 = i00 + w * 12
				local w00, w10, w01, w11 = (1 - fx) * gy, fx * gy, (1 - fx) * fy, fx * fy
				local a = buffer.readu32(alb, o)
				r = (w00 * buffer.readf32(lit, i00) + w10 * buffer.readf32(lit, i00 + 12) + w01 * buffer.readf32(lit, i01) + w11 * buffer.readf32(lit, i01 + 12)) * (a % 256)
				g = (w00 * buffer.readf32(lit, i00 + 4) + w10 * buffer.readf32(lit, i00 + 16) + w01 * buffer.readf32(lit, i01 + 4) + w11 * buffer.readf32(lit, i01 + 16)) * ((a // 256) % 256)
				b = (w00 * buffer.readf32(lit, i00 + 8) + w10 * buffer.readf32(lit, i00 + 20) + w01 * buffer.readf32(lit, i01 + 8) + w11 * buffer.readf32(lit, i01 + 20)) * ((a // 65536) % 256)
			end
			buffer.writeu32(out, o, buffer.readu8(lut, math.min(2047, r // 1)) + buffer.readu8(lut, math.min(2047, g // 1)) * 256
				+ buffer.readu8(lut, math.min(2047, b // 1)) * 65536 + 0xFF000000)
		end
	end
end

-- Wall light strips for faces [f0, f1]: GI 1.5 px outside each face, x brick albedo, x height falloff.
local function buildWalls(self: Lightmap, f0: number, f1: number)
	local rc = self.rc
	local w, h, fl, lut = self.w, self.h, rc.fluence, rc.lut
	local strip, col, SH = self.strip, self.col, self.stripH
	local ex = rc.exposure * 128 * self.wallGain
	local wts = self.wallTexScale
	local kc, pivot = self.contrast, rc.exposure * 4
	for fi = f0, f1 do
		local f = self.faces[fi]
		local wl = self.walls[f.wall]
		local reg = f.region
		local sw = reg.w
		local dx, dy = (f.bx - f.ax) / f.len, (f.by - f.ay) / f.len
		for s = 0, sw - 1 do
			local t = (s + 0.5) / wts
			local r, g, b = curve(kc, pivot, fluenceAt(fl, w, h, f.ax + dx * t + f.nx * 1.5, f.ay + dy * t + f.ny * 1.5))
			buffer.writef32(col, s * 12, r * ex)
			buffer.writef32(col, s * 12 + 4, g * ex)
			buffer.writef32(col, s * 12 + 8, b * ex)
		end
		-- bricks 8 texels tall, 18 wide, staggered; world-anchored so faces line up at corners
		local u0 = (f.ax + f.ay) * wts
		for k = 0, SH - 1 do
			local hgt = 1 - (k + 0.5) / SH -- 1 at the top, 0 at the floor
			local vf = (1 - 0.5 * hgt ^ 1.5) * (if k >= SH - 3 then 0.8 else 1)
			local brow = k // 8
			local mortarRow = k % 8 == 0
			for s = 0, sw - 1 do
				local u = u0 + s + (if brow % 2 == 1 then 9 else 0)
				local brick = u // 18
				local m = if mortarRow or u % 18 == 0 then 0.55 else 0.8 + 0.2 * hash(brick, brow + f.wall * 31)
				local kk = vf * m
				local ir = math.min(2047, buffer.readf32(col, s * 12) * wl.r * kk // 1)
				local ig = math.min(2047, buffer.readf32(col, s * 12 + 4) * wl.g * kk // 1)
				local ib = math.min(2047, buffer.readf32(col, s * 12 + 8) * wl.b * kk // 1)
				buffer.writeu32(strip, (k * sw + s) * 4, buffer.readu8(lut, ir) + buffer.readu8(lut, ig) * 256 + buffer.readu8(lut, ib) * 65536 + 0xFF000000)
			end
		end
		Atlas.write(reg, strip)
	end
end

-- Flow -------------------------------------------------------------------------------------------

-- rebuildOnChange. Without a budget: if anything changed, run GI to convergence (`settle` frames,
-- incremental after the first build) and rebuild both textures; returns true when they changed.
-- With budgetMs: one amortized frame (see header); returns true when floor or atlas changed.
function LM.update(self: Lightmap, budgetMs: number?): boolean
	local rc = self.rc
	local t0 = os.clock()
	if self.geomDirty then
		rebuildGeometry(self)
		self.lightDirty = true
	end
	if budgetMs == nil then
		if not self.lightDirty then
			return false
		end
		for _ = 1, self.settle do
			rc:render()
		end
		local t1 = os.clock()
		buildFloor(self, 0, 0, self.fw, self.fh)
		local t2 = os.clock()
		buildWalls(self, 1, #self.faces)
		local t3 = os.clock()
		self.stats.giMs, self.stats.floorMs, self.stats.wallsMs = (t1 - t0) * 1000, (t2 - t1) * 1000, (t3 - t2) * 1000
		self.lightDirty = false
		self.floorRow, self.faceIdx, self.again = -1, 0, false
		self.version += 1
		return true
	end
	local limit = t0 + budgetMs / 1000
	local changed = false
	local job = self.floorRow >= 0 or self.faceIdx > 0
	if self.lightDirty or rc.dirty or rc.active > 0 or rc.bakeAll then
		self.lightDirty = false
		-- GI share of the budget, minus what last frame's floor patch cost
		if rc:step(math.max(0, (if job then 0.5 else 1) * budgetMs - self.patchMs)) then
			-- a GI cycle landed: re-light the textures over the next frames
			if job then
				self.again = true
			else
				self.floorRow, job = 0, true
			end
		end
		if rc.patchX1 > rc.patchX0 then
			local s = self.texScale
			local tp = os.clock()
			buildFloor(self, rc.patchX0 * s, rc.patchY0 * s, rc.patchX1 * s, rc.patchY1 * s)
			self.patchMs = (os.clock() - tp) * 1000
			changed = true
		else
			self.patchMs = 0
		end
	end
	-- texture job: floor in 8-row slices, then the wall strips a face at a time
	local item = 0
	while job and os.clock() + item < limit do
		local ts = os.clock()
		changed = true
		if self.floorRow >= 0 then
			local y1 = math.min(self.fh, self.floorRow + 8)
			buildFloor(self, 0, self.floorRow, self.fw, y1)
			if y1 >= self.fh then
				self.floorRow, self.faceIdx = -1, 1
			else
				self.floorRow = y1
			end
		else
			if self.faceIdx <= #self.faces then
				buildWalls(self, self.faceIdx, self.faceIdx)
			end
			self.faceIdx += 1
			if self.faceIdx > #self.faces then
				self.faceIdx = 0
				job = false
				if self.again then
					self.again, self.floorRow, job = false, 0, true
				end
			end
		end
		item = os.clock() - ts
	end
	if changed then
		self.version += 1
	end
	return changed
end

-- True when GI has converged and no texture work is pending: update() is then free.
function LM.isSettled(self: Lightmap): boolean
	local rc = self.rc
	return not (self.geomDirty or self.lightDirty or rc.dirty or rc.bakeAll or rc.active > 0 or self.floorRow >= 0 or self.faceIdx > 0)
end

-- Rebuild both textures from the current GI result (no GI work).
function LM.relight(self: Lightmap)
	buildFloor(self, 0, 0, self.fw, self.fh)
	buildWalls(self, 1, #self.faces)
	self.version += 1
end

-- UV rect (u0, v0, u1, v1) of a face's strip on the atlas page: u0 at A, v0 at the top.
function LM.faceUV(face: Face): (number, number, number, number)
	return Atlas.uvRect(face.region)
end

-- Roblox only ------------------------------------------------------------------------------------
-- Two EditableImages (floor, wall atlas) shown through Content.fromObject. Wall meshes map each
-- face quad to LM.faceUV(face). Only one EditableImage refreshes per frame, so alternate uploads
-- when both changed (Uploader.luau does this generally).
function LM.createImages(self: Lightmap, AssetService: any): (any, any)
	local floorImg = AssetService:CreateEditableImage({ Size = Vector2.new(self.fw, self.fh) })
	local atlasImg = AssetService:CreateEditableImage({ Size = Vector2.new(self.atlas.size, self.atlas.size) })
	return floorImg, atlasImg
end

function LM.present(self: Lightmap, floorImg: any, atlasImg: any, floorPart: any, wallParts: { any })
	if floorImg then
		floorImg:WritePixelsBuffer(Vector2.zero, Vector2.new(self.fw, self.fh), self.floor)
		floorPart.TextureContent = Content.fromObject(floorImg)
	end
	if atlasImg then
		local S = self.atlas.size
		atlasImg:WritePixelsBuffer(Vector2.zero, Vector2.new(S, S), self.atlas.rgba)
		Atlas.clearDirty(self.atlas)
		local content = Content.fromObject(atlasImg)
		for _, part in wallParts do
			part.TextureContent = content
		end
	end
end

return LM
