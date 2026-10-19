-- Lightmap: radiance cascades on a floor plan -> lit floor texture + wall light-strip atlas, shown
-- through a small perspective rasteriser (z-buffer, perspective-correct UVs, lamp glows, bloom).
local Out = require("./Out")
local LM = require("../combo/Lightmap")
local Atlas = require("../Atlas")

-- Scene: three rooms, a sealed closet, pillars, a golden wall, a lava channel, coloured lamps, and
-- moonlight (sky) through a west doorway and two north windows. The south wall is a cutaway curb.
local function build(lm: LM.Lightmap)
	local G = { 0.62, 0.6, 0.58 }
	local function wall(x0: number, y0: number, x1: number, y1: number, c: { number }?, ht: number?)
		local k = c or G
		lm:addWall(x0, y0, x1, y1, k[1], k[2], k[3], ht)
	end
	wall(0, 0, 56, 8) -- north, windows at 56..72 and 184..200
	wall(72, 0, 184, 8)
	wall(200, 0, 256, 8)
	wall(0, 248, 256, 256, nil, 6) -- south (cutaway)
	wall(0, 8, 8, 150) -- west, doorway 150..186
	wall(0, 186, 8, 248)
	wall(248, 8, 256, 248) -- east
	wall(120, 8, 128, 96) -- interior, doorway 96..126
	wall(120, 126, 128, 248)
	wall(128, 140, 196, 148, { 0.92, 0.74, 0.22 }) -- golden wall, passage 196..248
	wall(206, 8, 212, 60) -- sealed closet 212..248 x 8..54
	wall(212, 54, 248, 60)
	wall(40, 52, 54, 66) -- pillars
	wall(76, 52, 90, 66)
	wall(40, 196, 54, 210)
	wall(76, 196, 90, 210)
	wall(160, 60, 168, 68)
	lm:addEmitter(136, 200, 232, 210, 4, 1.0, 0.12) -- lava channel
	lm:addEmitter(222, 210, 232, 240, 4, 1.0, 0.12)
	lm:setLamp(1, 64, 128, 4, 9, 1.2, 6.5) -- magenta
	lm:setLamp(2, 200, 90, 4, 1.5, 9, 15) -- cyan
	lm:setLamp(3, 64, 228, 3, 2, 7, 2.2) -- green
end

local lm = LM.new(256, 256, { exposure = 0.32, sky = { 1.6, 2.4, 5 }, texScale = 2, contrast = 1.5 })
build(lm)
local t0 = os.clock()
local changed = lm:update()
local fullMs = (os.clock() - t0) * 1000
print(string.format("@@INFO full build %.1f ms (GI %.1f, floor %.1f, walls %.1f), %d wall faces", fullMs, lm.stats.giMs, lm.stats.floorMs, lm.stats.wallsMs, #lm.faces))

-- texture checks -----------------------------------------------------------------------------------
local function floorRGB(x: number, y: number): (number, number, number) -- plan coords, 1-px average
	local s = lm.texScale
	local r, g, b = 0, 0, 0
	for dy = 0, s - 1 do
		for dx = 0, s - 1 do
			local v = buffer.readu32(lm.floor, ((y * s + dy) * lm.fw + x * s + dx) * 4)
			r += v % 256
			g += (v // 256) % 256
			b += (v // 65536) % 256
		end
	end
	return r / (s * s), g / (s * s), b / (s * s)
end
local function floorMean(x0: number, y0: number, x1: number, y1: number): (number, number, number)
	local r, g, b, n = 0, 0, 0, 0
	for y = y0, y1 - 1 do
		for x = x0, x1 - 1 do
			local a, c, d = floorRGB(x, y)
			r += a
			g += c
			b += d
			n += 1
		end
	end
	return r / n, g / n, b / n
end
local cr, cg, cb = floorMean(214, 10, 246, 52)
local or_, og, ob = floorMean(20, 120, 110, 136)
Out.check("lm.closet_dark", changed and cr + cg + cb < 3 and or_ + og + ob > 60,
	string.format("sealed closet floor %.1f,%.1f,%.1f vs open floor %.0f,%.0f,%.0f", cr, cg, cb, or_, og, ob))
local lr, lg, lb = floorMean(150, 186, 210, 196)
Out.check("lm.lava_glow", lr > 1.6 * lb and lr > 90, string.format("floor beside lava rgb %.0f,%.0f,%.0f", lr, lg, lb))
local yr, yg, yb = floorMean(190, 100, 210, 112)
Out.check("lm.cyan_pool", yb > 1.3 * yr, string.format("floor under cyan lamp rgb %.0f,%.0f,%.0f", yr, yg, yb))
local dr, dg, db = floorMean(10, 160, 30, 176)
local ir, ig, ib = floorMean(90, 160, 110, 176)
Out.check("lm.moonlight_doorway", db > dr and db > 1.3 * ib, string.format("inside doorway rgb %.0f,%.0f,%.0f vs deeper %.0f,%.0f,%.0f", dr, dg, db, ir, ig, ib))

-- wall strips: the east wall's inner face is cyan beside the cyan room and orange beside the lava
local function stripAt(face: LM.Face, along: number): (number, number, number)
	local reg = face.region
	local s = math.floor(along * lm.wallTexScale)
	local r, g, b = 0, 0, 0
	for k = reg.h // 2, reg.h - 4 do
		local v = buffer.readu32(lm.atlas.rgba, ((reg.y + k) * lm.atlas.size + reg.x + s) * 4)
		r += v % 256
		g += (v // 256) % 256
		b += (v // 65536) % 256
	end
	local n = reg.h - 4 - reg.h // 2 + 1
	return r / n, g / n, b / n
end
local east: LM.Face? = nil
for _, f in lm.faces do
	if f.ax == 248 and f.nx == -1 then
		east = f
	end
end
assert(east, "east wall inner face")
local e = east :: LM.Face
-- west face runs A=(248,248) -> B=(248,8): plan y = 248 - along
local wr1, wg1, wb1 = stripAt(e, 248 - 85)
local wr2, wg2, wb2 = stripAt(e, 248 - 225)
Out.check("lm.wall_strips", wb1 > wr1 and wr2 > 1.5 * wb2, string.format("east wall at y=85 rgb %.0f,%.0f,%.0f; at y=225 (lava) %.0f,%.0f,%.0f", wr1, wg1, wb1, wr2, wg2, wb2))

-- preview renderer -----------------------------------------------------------------------------------
local W3, H3 = 960, 600
local acc = buffer.create(W3 * H3 * 12) -- f32 RGB 0..1+
local zb = buffer.create(W3 * H3 * 4) -- f32 1/z
local EYE = { 128, 250, 405 } -- (plan x, height, plan y)
local AT = { 128, 0, 122 }
local fwd = { AT[1] - EYE[1], AT[2] - EYE[2], AT[3] - EYE[3] }
local fl = math.sqrt(fwd[1] ^ 2 + fwd[2] ^ 2 + fwd[3] ^ 2)
fwd = { fwd[1] / fl, fwd[2] / fl, fwd[3] / fl }
-- right = fwd x up(0,1,0); up' = right x fwd
local right = { -fwd[3], 0, fwd[1] }
local rl = math.sqrt(right[1] ^ 2 + right[3] ^ 2)
right = { right[1] / rl, 0, right[3] / rl }
local upv = { right[2] * fwd[3] - right[3] * fwd[2], right[3] * fwd[1] - right[1] * fwd[3], right[1] * fwd[2] - right[2] * fwd[1] }
local focal = (H3 / 2) / math.tan(math.rad(46) / 2)

local function project(x: number, yUp: number, z: number): (number, number, number)
	local dx, dy, dz = x - EYE[1], yUp - EYE[2], z - EYE[3]
	local xc = dx * right[1] + dy * right[2] + dz * right[3]
	local yc = dx * upv[1] + dy * upv[2] + dz * upv[3]
	local zc = dx * fwd[1] + dy * fwd[2] + dz * fwd[3]
	return W3 / 2 + xc / zc * focal, H3 / 2 - yc / zc * focal, 1 / zc
end

type Sampler = (number, number) -> (number, number, number)
local function bilinear(tex: buffer, tw: number, th: number, u: number, v: number): (number, number, number)
	local x, y = math.clamp(u - 0.5, 0, tw - 1.001), math.clamp(v - 0.5, 0, th - 1.001)
	local x0, y0 = x // 1, y // 1
	local fx, fy = x - x0, y - y0
	local o = (y0 * tw + x0) * 4
	local a, b = buffer.readu32(tex, o), buffer.readu32(tex, o + 4)
	local c, d = buffer.readu32(tex, o + tw * 4), buffer.readu32(tex, o + tw * 4 + 4)
	local w00, w10, w01, w11 = (1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy
	local r = w00 * (a % 256) + w10 * (b % 256) + w01 * (c % 256) + w11 * (d % 256)
	local g = w00 * ((a // 256) % 256) + w10 * ((b // 256) % 256) + w01 * ((c // 256) % 256) + w11 * ((d // 256) % 256)
	local bb = w00 * ((a // 65536) % 256) + w10 * ((b // 65536) % 256) + w01 * ((c // 65536) % 256) + w11 * ((d // 65536) % 256)
	return r / 255, g / 255, bb / 255
end

-- Triangle with per-vertex (world x, height, plan y, u, v); perspective-correct, z-tested.
local function tri(p: { { number } }, shade: Sampler)
	local sx, sy, iz, uz, vz = {}, {}, {}, {}, {}
	for i = 1, 3 do
		local a, b, c = project(p[i][1], p[i][2], p[i][3])
		sx[i], sy[i], iz[i], uz[i], vz[i] = a, b, c, p[i][4] * c, p[i][5] * c
	end
	local area = (sx[2] - sx[1]) * (sy[3] - sy[1]) - (sx[3] - sx[1]) * (sy[2] - sy[1])
	if math.abs(area) < 1e-9 then
		return
	end
	local x0, x1 = math.max(0, math.floor(math.min(sx[1], sx[2], sx[3]))), math.min(W3 - 1, math.ceil(math.max(sx[1], sx[2], sx[3])))
	local y0, y1 = math.max(0, math.floor(math.min(sy[1], sy[2], sy[3]))), math.min(H3 - 1, math.ceil(math.max(sy[1], sy[2], sy[3])))
	for y = y0, y1 do
		local py = y + 0.5
		for x = x0, x1 do
			local px = x + 0.5
			local b0 = ((sx[2] - px) * (sy[3] - py) - (sx[3] - px) * (sy[2] - py)) / area
			local b1 = ((sx[3] - px) * (sy[1] - py) - (sx[1] - px) * (sy[3] - py)) / area
			local b2 = 1 - b0 - b1
			if b0 >= 0 and b1 >= 0 and b2 >= 0 then
				local z = b0 * iz[1] + b1 * iz[2] + b2 * iz[3]
				local o = y * W3 + x
				if z > buffer.readf32(zb, o * 4) then
					buffer.writef32(zb, o * 4, z)
					local r, g, b = shade((b0 * uz[1] + b1 * uz[2] + b2 * uz[3]) / z, (b0 * vz[1] + b1 * vz[2] + b2 * vz[3]) / z)
					buffer.writef32(acc, o * 12, r)
					buffer.writef32(acc, o * 12 + 4, g)
					buffer.writef32(acc, o * 12 + 8, b)
				end
			end
		end
	end
end

local function quad(a: { number }, b: { number }, c: { number }, d: { number }, shade: Sampler)
	tri({ a, b, c }, shade)
	tri({ a, c, d }, shade)
end

local function render(lm: LM.Lightmap): buffer
	buffer.fill(acc, 0, 0)
	buffer.fill(zb, 0, 0)
	local s, fw, fh = lm.texScale, lm.fw, lm.fh
	local floorTex: Sampler = function(u: number, v: number)
		return bilinear(lm.floor, fw, fh, u, v)
	end
	quad({ 0, 0, 0, 0, 0 }, { 256, 0, 0, 256 * s, 0 }, { 256, 0, 256, 256 * s, 256 * s }, { 0, 0, 256, 0, 256 * s }, floorTex)
	local page = lm.atlas
	local atlasTex: Sampler = function(u: number, v: number)
		return bilinear(page.rgba, page.size, page.size, u, v)
	end
	local rgba = lm.rc.rgba
	local capTex: Sampler = function(u: number, v: number)
		local c = buffer.readu32(rgba, ((math.clamp(v // 1, 0, 255)) * 256 + math.clamp(u // 1, 0, 255)) * 4)
		return (c % 256) / 255 * 0.5, ((c // 256) % 256) / 255 * 0.5, ((c // 65536) % 256) / 255 * 0.5
	end
	for _, f in lm.faces do
		local mx, my = (f.ax + f.bx) / 2, (f.ay + f.by) / 2
		if (EYE[1] - mx) * f.nx + (EYE[3] - my) * f.ny > 0 then
			local reg = f.region
			local H = f.height
			quad({ f.ax, H, f.ay, reg.x, reg.y }, { f.bx, H, f.by, reg.x + reg.w, reg.y },
				{ f.bx, 0, f.by, reg.x + reg.w, reg.y + reg.h }, { f.ax, 0, f.ay, reg.x, reg.y + reg.h }, atlasTex)
		end
	end
	for _, wl in lm.walls do
		local H = wl.height
		quad({ wl.x0, H, wl.y0, wl.x0, wl.y0 }, { wl.x1, H, wl.y0, wl.x1, wl.y0 }, { wl.x1, H, wl.y1, wl.x1, wl.y1 }, { wl.x0, H, wl.y1, wl.x0, wl.y1 }, capTex)
	end
	-- lamp orbs with additive glow, occluded by the z-buffer at their centre
	for _, lamp in lm.lamps do
		local px, py, z = project(lamp.x, lamp.height, lamp.y)
		local cx, cy = px // 1, py // 1
		if cx >= 0 and cy >= 0 and cx < W3 and cy < H3 and z >= buffer.readf32(zb, (cy * W3 + cx) * 4) * 0.98 then
			local m = math.max(lamp.r, lamp.g, lamp.b)
			local r, g, b = lamp.r / m, lamp.g / m, lamp.b / m
			local rad = 60
			for y = math.max(0, cy - rad), math.min(H3 - 1, cy + rad) do
				for x = math.max(0, cx - rad), math.min(W3 - 1, cx + rad) do
					local d2 = ((x - px) ^ 2 + (y - py) ^ 2)
					local core = math.exp(-d2 / 18)
					local halo = 0.55 * math.exp(-d2 / 500)
					local o = (y * W3 + x) * 12
					buffer.writef32(acc, o, buffer.readf32(acc, o) + r * halo + core)
					buffer.writef32(acc, o + 4, buffer.readf32(acc, o + 4) + g * halo + core)
					buffer.writef32(acc, o + 8, buffer.readf32(acc, o + 8) + b * halo + core)
				end
			end
		end
	end
	-- bloom: bright pass at half resolution, two box blurs, added back
	local hw, hh = W3 // 2, H3 // 2
	local bA, bB = buffer.create(hw * hh * 12), buffer.create(hw * hh * 12)
	for y = 0, hh - 1 do
		for x = 0, hw - 1 do
			for c = 0, 2 do
				local v = 0
				for k = 0, 3 do
					v += buffer.readf32(acc, (((2 * y + k // 2) * W3 + 2 * x + k % 2) * 12) + c * 4)
				end
				buffer.writef32(bA, (y * hw + x) * 12 + c * 4, math.max(0, v / 4 - 0.55))
			end
		end
	end
	local R = 7
	for _ = 1, 2 do
		for y = 0, hh - 1 do -- horizontal A -> B
			for c = 0, 2 do
				local sum = 0
				for x = -R, hw - 1 + R do
					if x + R < hw then
						sum += buffer.readf32(bA, (y * hw + x + R) * 12 + c * 4)
					end
					if x - R - 1 >= 0 then
						sum -= buffer.readf32(bA, (y * hw + x - R - 1) * 12 + c * 4)
					end
					if x >= 0 and x < hw then
						buffer.writef32(bB, (y * hw + x) * 12 + c * 4, sum / (2 * R + 1))
					end
				end
			end
		end
		for x = 0, hw - 1 do -- vertical B -> A
			for c = 0, 2 do
				local sum = 0
				for y = -R, hh - 1 + R do
					if y + R < hh then
						sum += buffer.readf32(bB, ((y + R) * hw + x) * 12 + c * 4)
					end
					if y - R - 1 >= 0 then
						sum -= buffer.readf32(bB, ((y - R - 1) * hw + x) * 12 + c * 4)
					end
					if y >= 0 and y < hh then
						buffer.writef32(bA, (y * hw + x) * 12 + c * 4, sum / (2 * R + 1))
					end
				end
			end
		end
	end
	local out = buffer.create(W3 * H3 * 4)
	for y = 0, H3 - 1 do
		for x = 0, W3 - 1 do
			local o = (y * W3 + x) * 12
			local bo = ((math.min(hh - 1, y // 2)) * hw + math.min(hw - 1, x // 2)) * 12
			local vig = 1 - 0.35 * (((x - W3 / 2) / W3) ^ 2 + ((y - H3 / 2) / H3) ^ 2) * 2
			local r = (buffer.readf32(acc, o) + 1.4 * buffer.readf32(bA, bo)) * vig
			local g = (buffer.readf32(acc, o + 4) + 1.4 * buffer.readf32(bA, bo + 4)) * vig
			local b = (buffer.readf32(acc, o + 8) + 1.4 * buffer.readf32(bA, bo + 8)) * vig
			buffer.writeu32(out, (y * W3 + x) * 4, math.clamp(r * 255 // 1, 0, 255) + math.clamp(g * 255 // 1, 0, 255) * 256 + math.clamp(b * 255 // 1, 0, 255) * 65536 + 0xFF000000)
		end
	end
	return out
end

Out.image("lm_room_3d", W3, H3, render(lm))
Out.image("lm_floor_texture", lm.fw, lm.fh, lm.floor)
do -- used part of the wall atlas page
	local S = lm.atlas.size
	local rows = 0
	for _, f in lm.faces do
		rows = math.max(rows, f.region.y + f.region.h + 1)
	end
	local crop = buffer.create(S * rows * 4)
	buffer.copy(crop, 0, lm.atlas.rgba, 0, S * rows * 4)
	Out.image("lm_wall_atlas", S, rows, crop)
end

-- rebuildOnChange ------------------------------------------------------------------------------------
local tn = os.clock()
local again = lm:update()
local idleMs = (os.clock() - tn) * 1000
Out.check("lm.idle_when_unchanged", not again and idleMs < 0.05, string.format("update() with no change: %s in %.4f ms", tostring(again), idleMs))

-- amortized: the magenta lamp walks around the left room; GI time-sliced, textures re-lit in slices
local BUDGET = 3.5
local tot, worst, versions = 0, 0, lm.version
for f = 1, 60 do
	local a = f * 0.08
	local t = os.clock()
	lm:setLamp(1, 64 + 30 * math.cos(a), 128 + 40 * math.sin(a), 4, 9, 1.2, 6.5)
	lm:update(BUDGET)
	local dt = (os.clock() - t) * 1000
	tot += dt
	worst = math.max(worst, dt)
end
print(string.format("@@INFO amortized lamp: %.2f ms/frame avg (worst %.2f), textures changed %d times in 60 frames", tot / 60, worst, lm.version - versions))
Out.check("lm.amortized_budget", tot / 60 <= BUDGET + 1 and lm.version - versions >= 30,
	string.format("%.2f ms/frame avg over 60 frames (budget %.1f), %d texture updates", tot / 60, BUDGET, lm.version - versions))
-- lamp stops: the amortized flow converges, then goes idle (update returns false, costs nothing)
local settleFrames = 0
while not lm:isSettled() and settleFrames < 2000 do
	lm:update(BUDGET)
	settleFrames += 1
end
local idleT = os.clock()
local idle2 = lm:update(BUDGET)
local idle2Ms = (os.clock() - idleT) * 1000
Out.check("lm.amortized_settles", settleFrames < 2000 and not idle2 and idle2Ms < 0.05,
	string.format("textures final %d frames after the lamp stopped, then idle (%.4f ms)", settleFrames, idle2Ms))
local snap = render(lm)

-- open a door into the sealed closet: an occluder edit, handled incrementally
local partial0 = lm.rc.stats.partial
lm:removeWall(11) -- wall(206, 8, 212, 60)
lm:addWall(206, 8, 212, 30)
local te = os.clock()
lm:update()
local editMs = (os.clock() - te) * 1000
local cr2, cg2, cb2 = floorMean(214, 34, 246, 52)
Out.check("lm.door_edit", cr2 + cg2 + cb2 > 6 and lm.rc.stats.partial > partial0,
	string.format("closet floor after opening a door %.0f,%.0f,%.0f (was %.1f), incremental GI, %.1f ms", cr2, cg2, cb2, cr + cg + cb, editMs))
Out.image("lm_room_3d_moved_lamp", W3, H3, snap)

Out.time("lm.update_full_after_lamp_move", 2, function()
	lm:setLamp(2, 200 + math.random() * 4, 90, 4, 1.5, 9, 15)
	lm:update()
end)
Out.time("lm.update_amortized_lamp_move", 30, function()
	lm:setLamp(2, 200 + math.random() * 20, 90, 4, 1.5, 9, 15)
	lm:update(BUDGET)
end)
Out.time("lm.relight_textures", 3, function()
	lm:relight()
end)
Out.done()
