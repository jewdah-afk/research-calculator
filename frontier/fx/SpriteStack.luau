--!native
--!optimize 2
-- Sprite stacking: a voxel model stored as N horizontal slices (N x N RGBA each), drawn bottom to
-- top, each slice rotated about the object's centre and lifted `lift` pixels above the previous.
-- Every slice of one object shares the same rotation, so the inverse rotation is done once per
-- object: each destination pixel in the rotated bounding box is mapped back to a source texel,
-- and only texels inside the model's footprint are kept. Slices then replay that list with a
-- vertical offset: one buffer read + one write per pixel, no trig, no bounds math in the fast path.
-- Gaps between lifted slices are filled by drawing each slice `lift` times; the lower copies use
-- a darker "side" colour and the top copy the lit "top" colour, which reads as shaded 3D faces.
-- Drop shadows: each footprint column casts a streak along the light direction proportional to its
-- height, rasterised into a u8 mask and applied to the ground once (no double-darkening).
-- Cost per object ~ footprint_px * N * lift.

local SS = {}
SS.__index = SS

export type Model = {
	n: number,
	top: buffer, -- u32 RGBA per (z, v, u), 0 = empty
	side: buffer, -- same texels, darkened for side faces
	columnTop: buffer, -- u8 per (v, u): highest filled z + 1 (0 = empty column)
	firstZ: number,
	lastZ: number,
}

export type Object = { model: Model, x: number, y: number, angle: number }

export type SpriteStack = typeof(setmetatable(
	{} :: {
		w: number,
		h: number,
		scale: number,
		lift: number,
		rgba: buffer,
		ground: buffer?,
		shadow: buffer,
		shadowDX: number,
		shadowDY: number,
		shadowDarken: number,
		mapX: buffer,
		mapY: buffer,
		mapT: buffer,
		mapCap: number,
	},
	SS
))

local function pack(r: number, g: number, b: number): number
	return math.clamp(r // 1, 0, 255) + math.clamp(g // 1, 0, 255) * 256 + math.clamp(b // 1, 0, 255) * 65536 + 0xFF000000
end

-- Models ---------------------------------------------------------------------------------------------

-- Build a model from fill(u, v, z) -> (r, g, b) or nil. z = 0 is the bottom slice.
-- Shading baked per slice: slight ambient occlusion toward the ground, lit tops only where a
-- voxel has nothing above it, darker sides everywhere else.
function SS.model(n: number, fill: (number, number, number) -> (number?, number?, number?)): Model
	local top = buffer.create(n * n * n * 4)
	local side = buffer.create(n * n * n * 4)
	local filled = buffer.create(n * n * n)
	local cols = buffer.create(n * n)
	local rgb = buffer.create(n * n * n * 12)
	local firstZ, lastZ = n, -1
	for z = 0, n - 1 do
		for v = 0, n - 1 do
			for u = 0, n - 1 do
				local r, g, b = fill(u, v, z)
				if r then
					local i = (z * n + v) * n + u
					buffer.writeu8(filled, i, 1)
					buffer.writef32(rgb, i * 12, r)
					buffer.writef32(rgb, i * 12 + 4, g :: number)
					buffer.writef32(rgb, i * 12 + 8, b :: number)
					buffer.writeu8(cols, v * n + u, z + 1)
					firstZ = math.min(firstZ, z)
					lastZ = math.max(lastZ, z)
				end
			end
		end
	end
	for z = 0, n - 1 do
		local ao = 0.72 + 0.28 * math.min(1, z / (n * 0.5))
		for v = 0, n - 1 do
			for u = 0, n - 1 do
				local i = (z * n + v) * n + u
				if buffer.readu8(filled, i) ~= 0 then
					local r, g, b = buffer.readf32(rgb, i * 12), buffer.readf32(rgb, i * 12 + 4), buffer.readf32(rgb, i * 12 + 8)
					-- a covered voxel only ever shows its side, so its "top" copy uses the side colour too
					local covered = z < n - 1 and buffer.readu8(filled, i + n * n) ~= 0
					local s = ao * 0.68
					local t = if covered then s else ao * 1.08
					buffer.writeu32(top, i * 4, pack(r * t, g * t, b * t))
					buffer.writeu32(side, i * 4, pack(r * s, g * s, b * s))
				end
			end
		end
	end
	return { n = n, top = top, side = side, columnTop = cols, firstZ = firstZ, lastZ = lastZ }
end

local function hash3(u: number, v: number, z: number): number
	local h = (u * 73856093 + v * 19349663 + z * 83492791) % 1000003
	return (h % 1000) / 1000
end

-- 16^3 cottage: plaster walls with timber corners, door, windows, gabled tile roof, chimney.
function SS.house(): Model
	return SS.model(16, function(u: number, v: number, z: number)
		local j = hash3(u, v, z) * 14 - 7
		local u0, u1, v0, v1 = 2, 13, 3, 12
		if u == 11 and v == 5 and z >= 9 and z <= 15 then -- chimney
			return 120 + j, 108 + j, 104 + j
		end
		if z <= 7 and u >= u0 and u <= u1 and v >= v0 and v <= v1 then
			local edgeU, edgeV = u == u0 or u == u1, v == v0 or v == v1
			if edgeU and edgeV or z == 0 or z == 7 then
				return 104 + j, 72 + j, 46 + j -- timber frame
			end
			if v == v1 and u >= 7 and u <= 8 and z <= 4 then
				return 86 + j, 54 + j, 32 + j -- door
			end
			if (edgeV and (u == 4 or u == 5 or u == 10 or u == 11) or edgeU and (v == 6 or v == 7 or v == 9)) and z >= 3 and z <= 5 then
				return 120, 190, 230 -- windows
			end
			return 232 + j, 220 + j, 196 + j -- plaster
		end
		local k = z - 8 -- roof layer
		if k >= 0 and k <= 5 and u >= u0 - 1 and u <= u1 + 1 then
			local va, vb = v0 - 1 + k, v1 + 1 - k
			if v == va or v == vb or (k == 5 and v >= va and v <= vb) then
				local stripe = if (u + k) % 2 == 0 then 0 else 18
				return 178 - stripe + j, 72 - stripe * 0.5 + j, 52 + j
			end
			if (u == u0 or u == u1) and v > va and v < vb then
				return 225 + j, 214 + j, 190 + j -- gable end
			end
		end
		return nil
	end)
end

-- 16^3 hatchback: red body, glass cabin, wheels, head/tail lights.
function SS.car(): Model
	return SS.model(16, function(u: number, v: number, z: number)
		local j = hash3(u, v, z) * 8 - 4
		local u0, u1, v0, v1 = 1, 14, 4, 11
		-- wheels
		if (u == 3 or u == 4 or u == 11 or u == 12) and (v == v0 or v == v1) and z <= 2 then
			return 28 + j, 28 + j, 32 + j
		end
		if u >= u0 and u <= u1 and v >= v0 + 1 and v <= v1 - 1 and z >= 1 and z <= 4 then
			if u == u1 and (v == v0 + 1 or v == v1 - 1) and z == 3 then
				return 255, 240, 160 -- headlights
			end
			if u == u0 and (v == v0 + 1 or v == v1 - 1) and z == 3 then
				return 210, 30, 30 -- tail lights
			end
			if z == 1 then
				return 60 + j, 60 + j, 66 + j -- skirt
			end
			return 205 + j, 40 + j, 44 + j
		end
		if u >= 4 and u <= 11 and v >= v0 + 1 and v <= v1 - 1 and z >= 5 and z <= 7 then
			if z == 7 then
				return 196 + j, 36 + j, 40 + j -- roof
			end
			if u == 4 or u == 11 or v == v0 + 1 or v == v1 - 1 then
				return 140 + j, 200 + j, 235 + j -- glass
			end
			return 40, 44, 52
		end
		return nil
	end)
end

-- 16^3 tree: trunk plus a lumpy sphere canopy.
function SS.tree(): Model
	return SS.model(16, function(u: number, v: number, z: number)
		local j = hash3(u, v, z)
		if (u == 7 or u == 8) and (v == 7 or v == 8) and z <= 6 then
			return 110 + j * 20, 76 + j * 14, 44
		end
		local dx, dy, dz = u - 7.5, v - 7.5, (z - 9.5) * 1.15
		local d = math.sqrt(dx * dx + dy * dy + dz * dz)
		if z >= 4 and d < 6.2 + j * 1.2 then
			local lightness = 0.8 + 0.25 * (z - 4) / 11
			return (56 + j * 40) * lightness, (128 + j * 50) * lightness, (44 + j * 20) * lightness
		end
		return nil
	end)
end

-- Renderer ---------------------------------------------------------------------------------------------

function SS.new(w: number, h: number, opts: { [string]: any }?): SpriteStack
	local o = opts or {}
	local scale: number = o.scale or 2
	local cap = (32 * scale + 8) * (32 * scale + 8)
	return setmetatable({
		w = w,
		h = h,
		scale = scale,
		lift = o.lift or scale,
		rgba = buffer.create(w * h * 4),
		ground = nil,
		shadow = buffer.create(w * h),
		shadowDX = o.shadowDX or 0.55,
		shadowDY = o.shadowDY or 0.3,
		shadowDarken = o.shadowDarken or 0.58,
		mapX = buffer.create(cap * 2),
		mapY = buffer.create(cap * 2),
		mapT = buffer.create(cap * 2),
		mapCap = cap,
	}, SS)
end

function SS.setGround(self: SpriteStack, rgba: buffer)
	self.ground = rgba
end

-- Inverse-rotate the object's bounding box once; keep (dx, dy, texel) for footprint texels only.
local function buildMap(self: SpriteStack, m: Model, angle: number): number
	local n, s = m.n, self.scale
	local half = n * 0.5
	local c, si = math.cos(angle), math.sin(angle)
	local R = math.ceil(half * s * (math.abs(c) + math.abs(si))) + 1
	local cols, mx, my, mt = m.columnTop, self.mapX, self.mapY, self.mapT
	local du, dv = c / s, -si / s
	local count = 0
	for dy = -R, R - 1 do
		local fy = dy + 0.5
		local fx = -R + 0.5
		local u = (fx * c + fy * si) / s + half
		local v = (-fx * si + fy * c) / s + half
		for dx = -R, R - 1 do
			if u >= 0 and v >= 0 and u < n and v < n then
				local t = (v // 1) * n + u // 1
				if buffer.readu8(cols, t) ~= 0 then
					buffer.writei16(mx, count * 2, dx)
					buffer.writei16(my, count * 2, dy)
					buffer.writeu16(mt, count * 2, t)
					count += 1
				end
			end
			u += du
			v += dv
		end
	end
	return count
end

local function drawShadow(self: SpriteStack, m: Model, cx: number, cy: number, count: number)
	local w, h, sh, mx, my, mt, cols = self.w, self.h, self.shadow, self.mapX, self.mapY, self.mapT, m.columnTop
	local sdx, sdy = self.shadowDX * self.lift, self.shadowDY * self.lift
	for e = 0, count - 1 do
		local px, py = cx + buffer.readi16(mx, e * 2), cy + buffer.readi16(my, e * 2)
		local top = buffer.readu8(cols, buffer.readu16(mt, e * 2))
		for k = 0, top - 1 do
			local x, y = (px + sdx * k) // 1, (py + sdy * k) // 1
			if x >= 0 and y >= 0 and x < w and y < h then
				buffer.writeu8(sh, y * w + x, 1)
			end
		end
	end
end

local function drawStack(self: SpriteStack, m: Model, cx: number, cy: number, count: number)
	local w, h, rgba, mx, my, mt, lift = self.w, self.h, self.rgba, self.mapX, self.mapY, self.mapT, self.lift
	local n2 = m.n * m.n
	local top, side = m.top, m.side
	local R = math.ceil(m.n * 0.5 * self.scale * 1.415) + 1
	local inside = cx - R >= 0 and cx + R < w and cy + R < h and cy - R - (m.lastZ + 1) * lift >= 0
	for z = m.firstZ, m.lastZ do
		local zb = z * n2
		for k = 0, lift - 1 do
			local src = if k == lift - 1 then top else side
			local oy = cy - z * lift - k
			if inside then
				local base = oy * w + cx
				for e = 0, count - 1 do
					local c = buffer.readu32(src, (zb + buffer.readu16(mt, e * 2)) * 4)
					if c ~= 0 then
						buffer.writeu32(rgba, (base + buffer.readi16(my, e * 2) * w + buffer.readi16(mx, e * 2)) * 4, c)
					end
				end
			else
				for e = 0, count - 1 do
					local c = buffer.readu32(src, (zb + buffer.readu16(mt, e * 2)) * 4)
					if c ~= 0 then
						local x, y = cx + buffer.readi16(mx, e * 2), oy + buffer.readi16(my, e * 2)
						if x >= 0 and y >= 0 and x < w and y < h then
							buffer.writeu32(rgba, (y * w + x) * 4, c)
						end
					end
				end
			end
		end
	end
end

local function byDepth(a: Object, b: Object): boolean
	return a.y < b.y
end

-- Draw a list of objects (sorted in place back to front). Ground -> shadows -> stacks.
function SS.drawScene(self: SpriteStack, objects: { Object })
	local w, h, rgba = self.w, self.h, self.rgba
	if self.ground then
		buffer.copy(rgba, 0, self.ground :: buffer)
	else
		buffer.fill(rgba, 0, 0)
	end
	table.sort(objects, byDepth)
	local sh = self.shadow
	buffer.fill(sh, 0, 0)
	for _, o in objects do
		local count = buildMap(self, o.model, o.angle)
		drawShadow(self, o.model, o.x // 1, o.y // 1, count)
	end
	local keep = (self.shadowDarken * 256) // 1
	for i = 0, w * h - 1 do
		if buffer.readu8(sh, i) ~= 0 then
			local c = buffer.readu32(rgba, i * 4)
			local r = (bit32.band(c, 255) * keep) // 256
			local g = (bit32.band(bit32.rshift(c, 8), 255) * keep) // 256
			local b = (bit32.band(bit32.rshift(c, 16), 255) * keep) // 256
			buffer.writeu32(rgba, i * 4, r + g * 256 + b * 65536 + 0xFF000000)
		end
	end
	for _, o in objects do
		local count = buildMap(self, o.model, o.angle)
		drawStack(self, o.model, o.x // 1, o.y // 1, count)
	end
end

-- Number of destination pixels covered by the model's footprint at this angle (for tests/culling).
SS.rotationMap = buildMap

-- Roblox only ------------------------------------------------------------------------------------
function SS.present(self: SpriteStack, img: any)
	img:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(self.w, self.h), self.rgba)
end

return SS
