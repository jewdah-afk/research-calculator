--!native
--!optimize 2
-- The Reaper, built from parts so it can animate:
--   body    hood + mantle + cloak, pre-rendered in NB hem-flutter frames. Folds are shaded from a
--           corrugated cylinder (not stripes), own-shade outline, cold rim from above-left, violet
--           up-light on the hem, warm candle rim on the lower right, a deep hood with a lit lip.
--   scythe  staff + blade rasterised analytically at any angle (cached per 2 degrees): bright
--           cutting edge, dark spine, own-shade outlines, and a per-pixel edge parameter so a glint
--           can travel along the edge.
--   arm     bell sleeve from the shoulder to a bony hand that grips the staff, drawn per frame.
-- compose(t, pose) assembles one frame into a CW x CH canvas (0 = transparent); blit() puts it on
-- screen solid, as a dithered ghost, or dissolving from ghost to solid with a burning edge.

local Palette = require("./Palette")

local C = Palette.C
local BAYER = Palette.BAYER

local Reaper = {}
Reaper.__index = Reaper

local CW, CH = 224, 200
local AX, AY = 112, 168 -- feet anchor inside the canvas
Reaper.CW, Reaper.CH, Reaper.AX, Reaper.AY = CW, CH, AX, AY

local NB = 8 -- hem flutter frames
Reaper.NB = NB
local BW, BH = 92, 134
local BX0, BY0 = AX - 46, AY - 126 -- body window inside the canvas

local SHX, SHY = 13, -70 -- shoulder (anchor-relative, y down)
Reaper.SHX, Reaper.SHY = SHX, SHY
local ARM = 24 -- shoulder to grip
Reaper.ARM = ARM
local EYES = { { -3, -86 }, { 4, -86 } }
Reaper.EYES = EYES

local M32 = 4294967296
local function hash(x: number, y: number, s: number): number
	local h = bit32.bxor((x * 73856093) % M32, (y * 19349663) % M32, (s * 83492791) % M32)
	h = (h * 69069 + 12345) % M32
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = (h * 69069 + 1013904223) % M32
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 69069 + 907633385) % M32
	return bit32.bxor(h, bit32.rshift(h, 16)) / M32
end

local function sdCapsule(px: number, py: number, ax: number, ay: number, bx: number, by: number, ra: number, rb: number): number
	local vx, vy = bx - ax, by - ay
	local u = math.clamp(((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy), 0, 1)
	local dx, dy = ax + vx * u - px, ay + vy * u - py
	return math.sqrt(dx * dx + dy * dy) - (ra + (rb - ra) * u)
end

-- Body ------------------------------------------------------------------------------------------
-- Anchor-relative coordinates with hy = height above the feet (up is positive).

local function hemShift(hy: number, ph: number): number
	local k = math.clamp((30 - hy) / 26, 0, 1)
	return 2.3 * math.sin(ph + hy * 0.19) * k ^ 1.5
end

local function halfW(hy: number): number
	local u = math.clamp((68 - hy) / 60, 0, 1)
	return 12.5 + 17.5 * u ^ 0.85
end

local function mantleBottom(px: number): number
	local m = px / 19.5
	return 69 - 8.5 * math.sqrt(math.max(0, 1 - m * m))
end

-- 0 empty, 1 cloak, 2 hood, 3 mantle, 4 face opening
local function bodyCode(px: number, hy: number, ph: number): number
	local hx, hq = (px - 0.5) / 12, (hy - 87) / 13
	local hood = hx * hx + hq * hq < 1
	if not hood then
		hood = sdCapsule(px, hy, -1, 94, -7, 109, 7.5, 0.6) < 0
	end
	if hood then
		local fx, fy = (px - 1.5) / 7, (hy - 84) / 8
		return if fx * fx + fy * fy < 1 then 4 else 2
	end
	local mx, my = px / 19.5, (hy - 69) / 8.5
	if mx * mx + my * my < 1 then
		return 3
	end
	if hy < 70 then
		local sx = px - hemShift(hy, ph)
		if math.abs(sx) < halfW(hy) then
			local fk = (sx + 48) / 5.5
			local k = math.floor(fk)
			local f = fk - k
			local L = (2.2 + 7.5 * hash(k, 3, 801)) * (1 + 0.25 * math.sin(ph + k * 2.3))
			local tri = 1 - math.abs(2 * f - 1)
			local bottom = 10 + 1.2 * math.sin(sx * 0.21) - L * tri ^ 0.85
			if hy > bottom then
				return 1
			end
		end
	end
	return 0
end

local function buildBody(ph: number): buffer
	local code = buffer.create(BW * BH)
	for y = 0, BH - 1 do
		for x = 0, BW - 1 do
			local px = BX0 + x + 0.5 - AX
			local hy = AY - (BY0 + y + 0.5)
			buffer.writeu8(code, y * BW + x, bodyCode(px, hy, ph))
		end
	end
	local function cd(x: number, y: number): number
		if x < 0 or y < 0 or x >= BW or y >= BH then
			return 0
		end
		return buffer.readu8(code, y * BW + x)
	end
	local function edge(x: number, y: number): boolean
		local c = cd(x, y)
		return c ~= 0 and (cd(x - 1, y) == 0 or cd(x + 1, y) == 0 or cd(x, y - 1) == 0 or cd(x, y + 1) == 0)
	end
	local out = buffer.create(BW * BH)
	for y = 0, BH - 1 do
		for x = 0, BW - 1 do
			local c = cd(x, y)
			local col = 0
			if c ~= 0 then
				local cx, cy = BX0 + x, BY0 + y -- canvas pixel (bayer is taken in canvas space)
				local b = BAYER[(cy % 4) * 4 + cx % 4 + 1]
				local px = cx + 0.5 - AX
				local hy = AY - (cy + 0.5)
				if edge(x, y) then
					col = C.CLOAK0
				elseif c == 4 then
					-- hood interior: deep black, the inner fabric just visible at the top, faint violet
					-- bounce from the void at the chin
					local fx, fy = (px - 1.5) / 7, (hy - 84) / 8
					local q = math.sqrt(fx * fx + fy * fy)
					if fy > 0.35 and q > 0.72 then
						col = C.CLOAK1
					elseif fy < -0.62 and q > 0.7 and b < 0.55 then
						col = C.VOID1
					else
						col = C.BLACK
					end
				else
					local lin = 0.4
					if c == 2 then
						local hx, hq = (px - 0.5) / 12, (hy - 87) / 13
						lin = 0.5 - 0.34 * hx + 0.3 * hq
						-- hood lip around the face catches the light on its upper/left side
						local fx, fy = (px - 1.5) / 7, (hy - 84) / 8
						local q = math.sqrt(fx * fx + fy * fy)
						if q < 1.3 then
							lin = if fy > -0.15 and fx < 0.55 then 0.95 elseif fx > 0.3 and fy < 0 then 0.1 else 0.55
						elseif q < 1.55 then
							lin -= 0.18 -- the fold just outside the lip
						end
						if hy < 79 then
							lin -= 0.2 -- hood throat sits in its own shadow
						end
					elseif c == 3 then
						local mx, my = px / 19.5, (hy - 69) / 8.5
						lin = 0.6 - 0.32 * mx + 0.28 * my
						if cd(x, y + 1) == 1 or cd(x, y + 2) == 1 then
							lin = 0.12 -- crease where the mantle overhangs the cloak
						end
					else
						local sx = px - hemShift(hy, 0)
						local w = halfW(hy)
						local q = math.clamp(sx / w, -1, 1)
						lin = 0.6 - 0.3 * q
						-- corrugated cylinder: fold normals lean toward / away from the light
						local depth = math.clamp((62 - hy) / 46, 0, 1) ^ 0.8
						local f = (q * 0.5 + 0.5) * 4.6 * 2 * math.pi + 0.7 + 0.35 * math.sin(hy * 0.09)
						lin += 0.3 * depth * math.cos(f)
						if math.sin(f) > 0.93 then
							lin -= 0.22 * depth -- crease at the back of each fold
						end
						-- shadow under the mantle
						local mb = mantleBottom(px)
						if hy < mb and hy > mb - 7 then
							lin -= 0.3 * (1 - (mb - hy) / 7)
						end
						-- the cloak parts at the front: dark inner gap
						if hy < 44 and math.abs(sx - 1.5) < (44 - hy) * 0.075 then
							lin = math.min(lin, 0.02)
						end
						-- void up-light on the lower hem
						lin -= 0.18 * math.clamp((14 - hy) / 12, 0, 1) -- hem in its own shade
					end
					local lv = math.clamp(Palette.level(lin * 4, b), 0, 3)
					col = C.CLOAK1 + lv
					-- rim light on the pixels just inside the outline
					local L, R, U, D = edge(x - 1, y), edge(x + 1, y), edge(x, y - 1), edge(x, y + 1)
					if D and c == 1 then
						col = if b < 0.6 then C.RIM else C.CLOAK2 -- violet up-light from the pit
					elseif L then
						col = if hy > 30 then C.CLOAK4 else C.CLOAK3
					elseif R then
						col = C.CLOAK1 -- shadow side
					elseif U and (c == 2 or c == 3) then
						col = C.CLOAK4
					end
				end
			end
			buffer.writeu8(out, y * BW + x, col)
		end
	end
	return out
end

-- Scythe ----------------------------------------------------------------------------------------
-- Local frame: a runs along the staff toward the blade end, b is the side the blade points to.
local STAFF_LO, STAFF_HI = -52, 66
local BLADE_L = 44
local function bladeTop(s: number): number
	return 60 + 7 * math.sin(2.67 * s) - 16 * s ^ 2.4
end
local function bladeW(s: number): number
	return 7.4 * (1 - s) ^ 0.6 + 0.7
end

-- 0 none, 1 staff, 3 collar, 4 blade, 5 ferrule
local function scytheCode(a: number, b: number): number
	if b >= -0.6 and b <= BLADE_L then
		local s = math.max(0, b) / BLADE_L
		local top = bladeTop(s)
		if a <= top and a >= top - bladeW(s) then
			return 4
		end
	end
	local ab = math.abs(b)
	if a >= 56 and a <= 60.5 and ab <= 1.7 then
		return 3
	end
	if a > STAFF_HI and a <= STAFF_HI + 3.2 and ab <= 1.1 then
		return 9 -- ember tip
	end
	if a >= STAFF_LO + 2 and a <= STAFF_HI and ab <= 0.62 then
		return 1
	end
	if a >= STAFF_LO - 1 and a < STAFF_LO + 2 and ab <= 1.6 then
		return 5
	end
	return 0
end

export type ScytheSprite = {
	x0: number,
	y0: number,
	w: number,
	h: number,
	col: buffer,
	par: buffer, -- edge parameter (0 = not edge, 1..250 = base..tip)
	blade: { number }, -- x, y, s triples (grip-relative) for the smear
}

local SR = 84
local function buildScythe(deg: number): ScytheSprite
	local th = math.rad(deg)
	local ux, uy = math.sin(th), -math.cos(th)
	local vx, vy = -math.cos(th), -math.sin(th)
	local S = 2 * SR + 1
	local code = buffer.create(S * S)
	local lit = vx * -0.6 + vy * -0.8 -- which side of the staff faces the light (upper left)
	local x0, y0, x1, y1 = S, S, -1, -1
	for y = 0, S - 1 do
		local dy = y - SR
		for x = 0, S - 1 do
			local dx = x - SR
			local a = dx * ux + dy * uy
			local b = dx * vx + dy * vy
			if a > STAFF_LO - 2 and a < 71 and b > -3 and b < BLADE_L + 1 then
				local c = scytheCode(a, b)
				if c ~= 0 then
					if c == 4 then
						if scytheCode(a - 1.05, b) ~= 4 then
							c = 6 -- cutting edge
						elseif scytheCode(a + 1.05, b) ~= 4 then
							c = 7 -- spine
						elseif scytheCode(a - 2.1, b) ~= 4 then
							c = 8 -- bevel just above the edge
						end
					elseif c == 1 then
						c = if b * lit > 0 then 1 else 2
					end
					buffer.writeu8(code, y * S + x, c)
					x0, y0 = math.min(x0, x), math.min(y0, y)
					x1, y1 = math.max(x1, x), math.max(y1, y)
				end
			end
		end
	end
	x0, y0, x1, y1 = x0 - 1, y0 - 1, x1 + 1, y1 + 1
	local w, h = x1 - x0 + 1, y1 - y0 + 1
	local col = buffer.create(w * h)
	local par = buffer.create(w * h)
	local blade = {}
	local function cd(x: number, y: number): number
		if x < 0 or y < 0 or x >= S or y >= S then
			return 0
		end
		return buffer.readu8(code, y * S + x)
	end
	local MAP = { [1] = C.STAFF, [2] = C.STAFF_SH, [3] = C.BLADE_SH, [4] = C.STEEL, [5] = C.STAFF_SH, [6] = C.BLADE_HI, [7] = C.BLADE_SH, [8] = C.BLADE, [9] = C.RED2 }
	for y = y0, y1 do
		for x = x0, x1 do
			local c = cd(x, y)
			local o = (y - y0) * w + (x - x0)
			if c ~= 0 then
				buffer.writeu8(col, o, MAP[c])
				if c >= 4 and c ~= 5 and c ~= 9 then
					local dx, dy = x - SR, y - SR
					local s = math.clamp((dx * vx + dy * vy) / BLADE_L, 0, 1)
					table.insert(blade, dx)
					table.insert(blade, dy)
					table.insert(blade, s)
					if c == 6 then
						buffer.writeu8(par, o, 1 + math.floor(s * 249))
					end
				end
			else
				local n1, n2, n3, n4 = cd(x - 1, y), cd(x + 1, y), cd(x, y - 1), cd(x, y + 1)
				if n1 ~= 0 or n2 ~= 0 or n3 ~= 0 or n4 ~= 0 then
					local function isB(n: number): boolean
						return n >= 3 and n ~= 5 and n ~= 9
					end
					local bl = isB(n1) or isB(n2) or isB(n3) or isB(n4)
					buffer.writeu8(col, o, if bl then C.BLADE_OUT else C.STAFF_OUT)
				end
			end
		end
	end
	return { x0 = x0 - SR, y0 = y0 - SR, w = w, h = h, col = col, par = par, blade = blade }
end

-- Construction ------------------------------------------------------------------------------------

export type Pose = {
	arm: number, -- shoulder->grip angle (radians, screen space, y down)
	scythe: number, -- staff angle in degrees (0 = blade end straight up, clockwise positive)
	glint: number, -- position of the travelling glint along the edge (0..1), or < 0 for none
	smearFrom: number?, -- scythe angle the slash smear trails back to
	eye: number, -- eye glow 0..1+
	hem: number, -- hem flutter phase (radians)
	sway: number, -- sleeve sway in pixels
}

export type Reaper = typeof(setmetatable(
	{} :: {
		body: { buffer },
		scythes: { [number]: ScytheSprite },
		canvas: buffer,
		thr: buffer,
		bx0: number,
		by0: number,
		bx1: number,
		by1: number,
		gripX: number,
		gripY: number,
		glintX: number,
		glintY: number,
		halo: { number }?,
	},
	Reaper
))

function Reaper.new(): Reaper
	local body = table.create(NB)
	for k = 0, NB - 1 do
		body[k + 1] = buildBody(k / NB * 2 * math.pi)
	end
	-- materialisation threshold field: low at the hem, high at the hood tip, broken up by noise
	local thr = buffer.create(CW * CH)
	for y = 0, CH - 1 do
		for x = 0, CW - 1 do
			local v = math.clamp((AY + 4 - y) / 150, 0, 1)
			local n = hash(x // 2, y // 2, 905) * 0.6 + hash(x, y, 906) * 0.4
			buffer.writeu8(thr, y * CW + x, math.floor(math.clamp(v * 0.78 + n * 0.22, 0, 1) * 250))
		end
	end
	return setmetatable({
		body = body,
		scythes = {},
		canvas = buffer.create(CW * CH),
		thr = thr,
		bx0 = 0,
		by0 = 0,
		bx1 = 0,
		by1 = 0,
		gripX = 0,
		gripY = 0,
		glintX = -1,
		glintY = -1,
		halo = nil,
	}, Reaper)
end

function Reaper.scythe(self: Reaper, deg: number): ScytheSprite
	local key = math.floor(deg / 2 + 0.5) % 180
	local s = self.scythes[key]
	if s == nil then
		s = buildScythe(key * 2)
		self.scythes[key] = s
	end
	return s
end

-- Compose ---------------------------------------------------------------------------------------

local function grow(self: Reaper, x0: number, y0: number, x1: number, y1: number)
	self.bx0 = math.max(0, math.min(self.bx0, x0))
	self.by0 = math.max(0, math.min(self.by0, y0))
	self.bx1 = math.min(CW - 1, math.max(self.bx1, x1))
	self.by1 = math.min(CH - 1, math.max(self.by1, y1))
end

local function cput(cv: buffer, x: number, y: number, c: number)
	if x >= 0 and y >= 0 and x < CW and y < CH then
		buffer.writeu8(cv, y * CW + x, c)
	end
end

local function overlay(self: Reaper, sp: ScytheSprite, gx: number, gy: number, glint: number)
	local cv = self.canvas
	local col, par, w = sp.col, sp.par, sp.w
	local ox, oy = gx + sp.x0, gy + sp.y0
	local gq = math.floor(glint * 249) + 1
	local best = 1e9
	for y = 0, sp.h - 1 do
		local cy = oy + y
		if cy >= 0 and cy < CH then
			for x = 0, w - 1 do
				local c = buffer.readu8(col, y * w + x)
				if c ~= 0 then
					local cx = ox + x
					if cx >= 0 and cx < CW then
						if glint >= 0 then
							local p = buffer.readu8(par, y * w + x)
							if p ~= 0 then
								local d = math.abs(p - gq)
								if d < 14 then
									c = C.SPARK
									if d < best then
										best = d
										self.glintX, self.glintY = cx, cy
									end
								elseif d < 34 then
									c = C.WHITE
								end
							end
						end
						buffer.writeu8(cv, cy * CW + cx, c)
					end
				end
			end
		end
	end
	grow(self, ox, oy, ox + w - 1, oy + sp.h - 1)
end

-- Motion smear of the blade between two angles: oldest steps dithered thin, newest solid white.
local function smear(self: Reaper, gx: number, gy: number, from: number, to: number)
	local cv = self.canvas
	local span = from - to
	local steps = math.max(1, math.floor(math.abs(span) / 2.5))
	for k = steps, 1, -1 do
		local age = k / steps -- 1 = oldest
		local sp = self:scythe(to + span * age)
		local pts = sp.blade
		local col = if age < 0.3 then C.SPARK elseif age < 0.55 then C.BLADE_HI elseif age < 0.8 then C.BOLT1 else C.BOLT0
		local dens = 1.05 - age * 0.9
		for i = 1, #pts, 3 do
			local s = pts[i + 2]
			if s > 0.2 then
				local x, y = gx + pts[i], gy + pts[i + 1]
				if x >= 0 and y >= 0 and x < CW and y < CH and dens * (0.4 + s) > BAYER[(y % 4) * 4 + x % 4 + 1] then
					buffer.writeu8(cv, y * CW + x, col)
				end
			end
		end
		grow(self, gx + sp.x0, gy + sp.y0, gx + sp.x0 + sp.w, gy + sp.y0 + sp.h)
	end
end

local function sleeve(self: Reaper, sx: number, sy: number, wx: number, wy: number)
	local cv = self.canvas
	local ra, rb = 4.6, 6.4
	local vx, vy = wx - sx, wy - sy
	local vv = vx * vx + vy * vy
	local x0, x1 = math.floor(math.min(sx, wx) - rb - 1), math.ceil(math.max(sx, wx) + rb + 1)
	local y0, y1 = math.floor(math.min(sy, wy) - rb - 1), math.ceil(math.max(sy, wy) + rb + 1)
	for y = y0, y1 do
		for x = x0, x1 do
			local px, py = x + 0.5, y + 0.5
			local raw = ((px - sx) * vx + (py - sy) * vy) / vv
			local u = math.clamp(raw, 0, 1)
			local qx, qy = px - (sx + vx * u), py - (sy + vy * u)
			local d = math.sqrt(qx * qx + qy * qy)
			local r = ra + (rb - ra) * u
			if d < r and x >= 0 and y >= 0 and x < CW and y < CH then
				local c
				if raw > 1.0 and d < r - 1.6 then
					c = C.BLACK -- the dark inside of the cuff the hand comes out of
				elseif d > r - 1 and raw > 0.22 then
					c = C.CLOAK0
				else
					local nx, ny = qx / math.max(d, 0.01), qy / math.max(d, 0.01)
					local s = 0.55 + 0.4 * (nx * -0.6 + ny * -0.8) - 0.12 * u
					local b = BAYER[(y % 4) * 4 + x % 4 + 1]
					c = C.CLOAK1 + math.clamp(Palette.level(s * 4, b), 0, 3)
					if d > r - 2 and nx * -0.6 + ny * -0.8 > 0.55 and u > 0.25 then
						c = C.CLOAK4
					end
				end
				buffer.writeu8(cv, y * CW + x, c)
			end
		end
	end
	grow(self, x0, y0, x1, y1)
end

-- Bony fist wrapped around the staff at the grip: three finger bones across the staff with dark
-- gaps between them, a thumb on the near side, all outlined.
local function hand(self: Reaper, gx: number, gy: number, deg: number)
	local cv = self.canvas
	local th = math.rad(deg)
	local ux, uy = math.sin(th), -math.cos(th)
	local vx, vy = -math.cos(th), -math.sin(th)
	for y = gy - 5, gy + 5 do
		for x = gx - 5, gx + 5 do
			local dx, dy = x - gx, y - gy
			local a = dx * ux + dy * uy
			local b = dx * vx + dy * vy
			local aa, ab = math.abs(a), math.abs(b)
			if aa <= 2.6 and ab <= 2.2 then
				local f = a + 2.6 -- 0..5.2: finger, gap, finger, gap, finger
				local seg = f % 1.75
				local lit = (dx * -0.6 + dy * -0.8) > -0.5
				local c
				if seg > 1.2 then
					c = C.BONE_SH
				else
					c = if lit then C.BONE else C.BONE_SH
				end
				cput(cv, x, y, c)
			elseif aa <= 3.6 and ab <= 3.1 then
				cput(cv, x, y, C.CLOAK0)
			end
		end
	end
	grow(self, gx - 5, gy - 5, gx + 5, gy + 5)
end

local function eyes(self: Reaper, k: number, t: number)
	local cv = self.canvas
	for i, e in EYES do
		local ex, ey = AX + e[1], AY + e[2]
		-- dithered halo, pulsing (only inside the dark hood opening)
		local r = 1.4 + 0.9 * k
		for y = ey - 4, ey + 4 do
			for x = ex - 4, ex + 5 do
				local dx, dy = x - ex - 0.5, (y - ey) * 1.25
				local d = math.sqrt(dx * dx + dy * dy)
				if d < r then
					local o = y * CW + x
					local c = buffer.readu8(cv, o)
					if c == C.BLACK or c == C.VOID1 or c == C.CLOAK1 then
						local dens = (1 - d / r) * (0.55 + 0.6 * k)
						if dens > BAYER[(y % 4) * 4 + x % 4 + 1] then
							buffer.writeu8(cv, o, if d < r * 0.45 and k > 0.6 then C.RED1 else C.RED0)
						end
					end
				end
			end
		end
		cput(cv, ex, ey, if k > 0.3 then C.EYE_HI else C.EYE)
		cput(cv, ex + 1, ey, C.EYE)
		if k > 1.1 then
			cput(cv, ex, ey + 1, C.RED1)
		end
	end
end

-- Grip position for a pose (canvas coordinates, integer).
function Reaper.grip(pose: Pose): (number, number)
	local sx, sy = AX + SHX, AY + SHY
	return math.floor(sx + math.cos(pose.arm) * ARM + pose.sway + 0.5), math.floor(sy + math.sin(pose.arm) * ARM + 0.5)
end

function Reaper.compose(self: Reaper, t: number, pose: Pose)
	local cv = self.canvas
	buffer.fill(cv, 0, 0)
	self.bx0, self.by0, self.bx1, self.by1 = BX0, BY0, BX0 + BW - 1, BY0 + BH - 1
	-- body frame (hem flutter phase)
	local fi = math.floor((pose.hem / (2 * math.pi)) * NB) % NB
	local bd = self.body[fi + 1]
	for y = 0, BH - 1 do
		buffer.copy(cv, (BY0 + y) * CW + BX0, bd, y * BW, BW)
	end
	eyes(self, pose.eye, t)
	local gx, gy = Reaper.grip(pose)
	self.gripX, self.gripY = gx, gy
	if pose.smearFrom then
		smear(self, gx, gy, pose.smearFrom, pose.scythe)
	end
	self.glintX, self.glintY = -1, -1
	overlay(self, self:scythe(pose.scythe), gx, gy, pose.glint)
	-- sleeve from the shoulder to the wrist (just short of the grip), then the fist over the staff
	local sx, sy = AX + SHX + 0.5, AY + SHY + 0.5
	local dx, dy = gx + 0.5 - sx, gy + 0.5 - sy
	local dl = math.sqrt(dx * dx + dy * dy)
	local wx, wy = gx + 0.5 - dx / dl * 4.5, gy + 0.5 - dy / dl * 4.5
	sleeve(self, sx, sy, wx, wy)
	hand(self, gx, gy, pose.scythe)
	-- 4-point sparkle where the glint peaks
	if pose.glint >= 0.15 and pose.glint <= 0.92 and self.glintX >= 0 then
		local x, y = self.glintX, self.glintY
		local arm = if math.abs(pose.glint - 0.55) < 0.2 then 3 else 2
		for k = 1, arm do
			local c = if k == 1 then C.SPARK else C.BOLT1
			cput(cv, x - k, y, c)
			cput(cv, x + k, y, c)
			cput(cv, x, y - k, c)
			cput(cv, x, y + k, c)
		end
		cput(cv, x, y, C.SPARK)
		grow(self, x - 3, y - 3, x + 3, y + 3)
	end
end

-- Blit ------------------------------------------------------------------------------------------
-- Ghost look: the same drawing remapped to a glowing spectral ramp, alpha-dithered (cloak edges
-- solid, the dark interior thin and see-through).
local GMAP = buffer.create(256)
local GALPHA = table.create(256, 0)
do
	for i = 0, 255 do
		buffer.writeu8(GMAP, i, C.GHOST2)
		GALPHA[i + 1] = 0.9
	end
	local function g(name: string, to: number, a: number)
		buffer.writeu8(GMAP, C[name], to)
		GALPHA[C[name] + 1] = a
	end
	g("CLOAK0", C.GHOST3, 1)
	g("CLOAK1", C.GHOST1, 0.5)
	g("CLOAK2", C.GHOST1, 0.62)
	g("CLOAK3", C.GHOST2, 0.72)
	g("CLOAK4", C.GHOST3, 0.85)
	g("RIM", C.GHOST3, 1)
	g("RIM_COLD", C.GHOST3, 1)
	g("RIM_WARM", C.GHOST2, 1)
	g("BLACK", C.GHOST0, 1)
	g("VOID1", C.GHOST0, 1)
	g("EYE", C.EYE, 1)
	g("EYE_HI", C.EYE_HI, 1)
	g("RED0", C.GHOST1, 0.8)
	g("RED1", C.EYE, 1)
	g("RED2", C.EYE, 1)
	g("BLADE", C.GHOST3, 0.9)
	g("BLADE_HI", C.GHOST3, 1)
	g("BLADE_SH", C.GHOST2, 0.9)
	g("BLADE_OUT", C.GHOST1, 0.8)
	g("STAFF", C.GHOST2, 0.85)
	g("STAFF_SH", C.GHOST1, 0.85)
	g("STAFF_OUT", C.GHOST1, 0.8)
	g("BONE", C.GHOST3, 1)
	g("BONE_SH", C.GHOST2, 1)
	g("SPARK", C.GHOST3, 1)
end

-- Precompute the ghost's glow halo (distance <= 6 outside the current canvas silhouette).
function Reaper.buildHalo(self: Reaper)
	local cv = self.canvas
	local halo = {}
	for y = 0, CH - 1 do
		for x = 0, CW - 1 do
			if buffer.readu8(cv, y * CW + x) == 0 then
				local best = 99
				for oy = -6, 6 do
					local yy = y + oy
					if yy >= 0 and yy < CH then
						for ox = -6, 6 do
							local xx = x + ox
							if xx >= 0 and xx < CW and buffer.readu8(cv, yy * CW + xx) ~= 0 then
								local d = math.sqrt(ox * ox + oy * oy)
								if d < best then
									best = d
								end
							end
						end
					end
				end
				if best <= 6 then
					table.insert(halo, x)
					table.insert(halo, y)
					table.insert(halo, best)
				end
			end
		end
	end
	self.halo = halo
end

-- mode 0 solid; 1 ghost (alpha ga); 2 dissolve ghost -> solid at progress p (0..1).
-- (x0, y0) is where the canvas origin lands on screen; rows below clipY are hidden (rising out of
-- the pit).
function Reaper.blit(self: Reaper, idx: buffer, W: number, H: number, x0: number, y0: number, mode: number, p: number, ga: number, phase: number, clipY: number)
	local cv, thr = self.canvas, self.thr
	if mode ~= 0 and self.halo then
		local halo = self.halo :: { number }
		local k = ga * (if mode == 2 then 1 - p else 1)
		for i = 1, #halo, 3 do
			local sx, sy = x0 + halo[i], y0 + halo[i + 1]
			if sx >= 0 and sy >= 0 and sx < W and sy < H and sy <= clipY then
				local a = 0.42 * (1 - halo[i + 2] / 7) * k
				if a > (BAYER[(sy % 4) * 4 + sx % 4 + 1] + phase) % 1 then
					buffer.writeu8(idx, sy * W + sx, C.GHOST1)
				end
			end
		end
	end
	local pq = p * 250
	for y = self.by0, self.by1 do
		local sy = y0 + y
		if sy >= 0 and sy < H and sy <= clipY then
			local row = y * CW
			local srow = sy * W
			local brow = (sy % 4) * 4 + 1
			for x = self.bx0, self.bx1 do
				local c = buffer.readu8(cv, row + x)
				if c ~= 0 then
					local sx = x0 + x
					if sx >= 0 and sx < W then
						local m = mode
						if m == 2 then
							local th = buffer.readu8(thr, row + x)
							if pq > th + 16 then
								m = 0
							elseif pq > th then
								-- burning edge of the materialisation front
								c = if pq > th + 7 then C.RIM_HI elseif BAYER[brow + sx % 4] < 0.5 then C.SPARK else C.GHOST3
								m = 3
							else
								m = 1
							end
						end
						if m == 1 then
							if GALPHA[c + 1] * ga > (BAYER[brow + sx % 4] + phase) % 1 then
								buffer.writeu8(idx, srow + sx, buffer.readu8(GMAP, c))
							end
						else
							buffer.writeu8(idx, srow + sx, c)
						end
					end
				end
			end
		end
	end
end

Reaper.hash = hash

return Reaper
