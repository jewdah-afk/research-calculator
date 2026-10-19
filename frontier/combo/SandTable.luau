--!native
--!optimize 2
-- SandTable: a top-down 2D material sim lifted into walkable 3D terrain.
-- Each cell holds a column: rock (immobile) + sand + lava (viscous fluid) + water, plus suspended sediment.
--   Sand:    thermal-erosion avalanche to the 8 neighbours whose drop exceeds the angle of repose (dry/wet).
--   Water:   virtual pipes (Mei et al. 2007) with flux damping so lakes come to rest; closed walls.
--   Erosion: capacity = Kc * speed * min(depth, capDepth); erode sand below it, deposit above it. Sediment rides
--            the pipe outflows (an exact scatter, so it is conserved, unlike semi-Lagrangian advection).
--   Lava:    Bingham-like 8-neighbour flow (moves only where drop > yield / thickness), cools to basalt in air
--            (slowly) and in water (fast), boiling water off as steam (hiss counter + fading steam flag); it
--            fuses the sand under it into rock. Every source and sink is counted: mass checks are identities.
-- Transfers are computed by the source cell into delta buffers and applied afterwards: order independent and
-- conserved (f64 state, float rounding only).
-- Sleeping: 16x16 chunks. Only awake chunks simulate; deltas landing in a sleeping chunk are applied on its
-- 1-cell rim, which wakes it if they matter. A chunk stays awake while heights/water move more than ACT_EPS,
-- water flows more than FLOW_EPS, lava is present or steam lingers; it zeroes its fluxes when it sleeps.
-- Rendering: ground (rock+sand+lava) and water surface are two HeightfieldMesh layers fed from f32 vertex
-- images (4x4 tent filter of cell heights, quantised to 1/64 stud, water 1/32), re-sampled only for chunks whose
-- accumulated change is visible, and pushed through HeightfieldMesh.updateRects over just the moved vertices.
-- The ground texture is one W x H RGBA8 image (1 texel per cell) shared by every ground chunk, rebuilt per
-- dirty chunk.
-- Why a separate water layer: the water part has no collision (players wade to the bed), it is translucent
-- over the carved bed, and ripples do not dirty the ground mesh, so ground chunks settle and their ~22 ms
-- collision rebakes stop while the water still moves.
-- Pure Luau except the ROBLOX ADAPTER section. No allocation in step / updateMeshes / updateTexture.

local HM = require("../mesh/HeightfieldMesh")

local ST = {}
ST.__index = ST

local CS = 16 -- sim chunk side (cells)
local Q = 64 -- ground vertex height quantum = 1/Q stud
local QW = 32 -- water surface quantum (ripples finer than ~1 cm are not worth an EditableMesh push)
local INF = math.huge
local SQRT2 = math.sqrt(2)
local ACT_EPS = 2e-5 -- studs of height/water change that keeps a chunk awake
local FLOW_EPS = 2e-4 -- total outflow (studs/step) that keeps a cell's chunk awake
local STEAM_DECAY = 5
local MESH_EPS = 0.5 / Q -- half a vertex quantum
local TEX_EPS = 0.01

ST.CHUNK = CS

export type SandTable = typeof(setmetatable(
	{} :: {
		w: number,
		h: number,
		cell: number,
		cw: number,
		ch: number,
		-- state (f64 per cell unless noted)
		rock: buffer,
		sand: buffer,
		water: buffer,
		sed: buffer,
		lava: buffer,
		G: buffer, -- cached ground = rock + sand + lava
		fL: buffer, -- f32 outflow fluxes
		fR: buffer,
		fT: buffer,
		fB: buffer,
		dW: buffer,
		dS: buffer,
		dSed: buffer,
		dL: buffer,
		steam: buffer, -- u8
		basalt: buffer, -- u8 (cooled lava: dark rock)
		lmove: buffer, -- u8 smoothed lava motion (moving lava glows, still lava crusts over)
		tone: buffer, -- u8 static colour noise
		-- chunks (u8 per chunk)
		awake: buffer,
		nextAwake: buffer,
		mdirty: buffer, -- mesh needs resample
		tdirty: buffer, -- texture needs rebuild
		udirty: buffer, -- texture needs upload
		mcursor: number,
		macc: { number }, -- accumulated sub-visible change per chunk (mesh / texture)
		tacc: { number },
		-- params
		kPipe: number,
		damp: number,
		wetEps: number,
		talusDry: number,
		talusWet: number,
		slideRate: number,
		slideDead: number,
		Kc: number,
		Ks: number,
		Kd: number,
		maxEro: number,
		capDepth: number,
		kLava: number,
		lavaYield: number,
		lavaMaxFrac: number,
		coolAir: number,
		coolFrac: number,
		coolWater: number,
		steamRatio: number,
		evap: number,
		-- accounting (exact sources/sinks)
		addedSand: number,
		addedWater: number,
		addedLava: number,
		removedSand: number,
		removedRock: number,
		removedLava: number,
		fusedSand: number,
		cooledLava: number,
		steamWater: number,
		evapWater: number,
		clampLoss: number,
		hiss: number, -- cells that boiled water this step (drive a sound)
		activeChunks: number,
		steps: number,
		-- rendering
		tex: buffer, -- RGBA8 w*h
		emit: buffer, -- u8 lava glow per texel
		groundImg: HM.Image?,
		waterImg: HM.Image?,
		ground: HM.Terrain?,
		waterMesh: HM.Terrain?,
		rects: { number },
		wrects: { number },
		groundChanged: { HM.Chunk },
		waterChanged: { HM.Chunk },
		wetShow: number,
		hideDrop: number,
		colPending: { number },
		colQuiet: { number },
		colAge: { number },
		colDue: { number },
		colSettle: number,
		colMaxWait: number,
	},
	ST
))

-- Static value noise for colour variation.
local function hash(x: number, y: number): number
	local n = bit32.bxor(x * 374761393, y * 668265263)
	n = bit32.bxor(n, bit32.rshift(n, 13)) * 1274126177
	return bit32.band(bit32.bxor(n, bit32.rshift(n, 16)), 0xFFFF) / 0xFFFF
end
local function vnoise(x: number, y: number): number
	local xi, yi = math.floor(x), math.floor(y)
	local fx, fy = x - xi, y - yi
	fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	local a, b = hash(xi, yi), hash(xi + 1, yi)
	local c, d = hash(xi, yi + 1), hash(xi + 1, yi + 1)
	return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
end
ST.vnoise = vnoise

-- opts: cell (studs per cell), and any tuning field by name.
function ST.new(w: number, h: number, opts: { [string]: any }?): SandTable
	local o = opts or {}
	local n = w * h
	local cw, ch = (w + CS - 1) // CS, (h + CS - 1) // CS
	local self = setmetatable({
		w = w,
		h = h,
		cell = o.cell or 1,
		cw = cw,
		ch = ch,
		rock = buffer.create(n * 8),
		sand = buffer.create(n * 8),
		water = buffer.create(n * 8),
		sed = buffer.create(n * 8),
		lava = buffer.create(n * 8),
		G = buffer.create(n * 8),
		fL = buffer.create(n * 4),
		fR = buffer.create(n * 4),
		fT = buffer.create(n * 4),
		fB = buffer.create(n * 4),
		dW = buffer.create(n * 8),
		dS = buffer.create(n * 8),
		dSed = buffer.create(n * 8),
		dL = buffer.create(n * 8),
		steam = buffer.create(n),
		basalt = buffer.create(n),
		lmove = buffer.create(n),
		tone = buffer.create(n),
		awake = buffer.create(cw * ch),
		nextAwake = buffer.create(cw * ch),
		mdirty = buffer.create(cw * ch),
		tdirty = buffer.create(cw * ch),
		udirty = buffer.create(cw * ch),
		macc = table.create(cw * ch, 0),
		mcursor = 0,
		tacc = table.create(cw * ch, 0),
		kPipe = o.kPipe or 0.2,
		damp = o.damp or 0.985,
		wetEps = o.wetEps or 0.004,
		talusDry = o.talusDry or 0.7, -- tan(angle of repose) ~ 35 deg
		talusWet = o.talusWet or 0.45,
		slideRate = o.slideRate or 0.5,
		slideDead = o.slideDead or 0.002,
		Kc = o.Kc or 1.2,
		Ks = o.Ks or 0.25,
		Kd = o.Kd or 0.08,
		maxEro = o.maxEro or 0.03,
		capDepth = o.capDepth or 0.6,
		kLava = o.kLava or 0.2,
		lavaYield = o.lavaYield or 0.02,
		lavaMaxFrac = o.lavaMaxFrac or 0.24,
		coolAir = o.coolAir or 0.0004,
		coolFrac = o.coolFrac or 0.0008, -- plus this fraction of the depth per step (thick lava radiates more)
		coolWater = o.coolWater or 0.05,
		steamRatio = o.steamRatio or 1.5,
		evap = o.evap or 0,
		addedSand = 0,
		addedWater = 0,
		addedLava = 0,
		removedSand = 0,
		removedRock = 0,
		removedLava = 0,
		fusedSand = 0,
		cooledLava = 0,
		steamWater = 0,
		evapWater = 0,
		clampLoss = 0,
		hiss = 0,
		activeChunks = 0,
		steps = 0,
		tex = buffer.create(n * 4),
		emit = buffer.create(n),
		groundImg = nil,
		waterImg = nil,
		ground = nil,
		waterMesh = nil,
		rects = table.create(cw * ch * 4, 0),
		wrects = table.create(cw * ch * 4, 0),
		groundChanged = {},
		waterChanged = {},
		wetShow = o.wetShow or 0.04,
		hideDrop = o.hideDrop or 0.6,
		colPending = {},
		colQuiet = {},
		colAge = {},
		colDue = {},
		colSettle = o.colSettle or 30,
		colMaxWait = o.colMaxWait or 600,
	}, ST)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local t = 0.6 * vnoise(x / 9, y / 9) + 0.4 * hash(x, y)
			buffer.writeu8(self.tone, y * w + x, math.floor(t * 255))
		end
	end
	return self
end

-- Authoring ---------------------------------------------------------------------------------------------------

-- Direct column write for scene setup; call refresh() afterwards.
function ST.setColumn(self: SandTable, x: number, y: number, rock: number, sand: number, water: number?, lava: number?)
	local i = (y * self.w + x) * 8
	buffer.writef64(self.rock, i, rock)
	buffer.writef64(self.sand, i, sand)
	buffer.writef64(self.water, i, water or 0)
	buffer.writef64(self.lava, i, lava or 0)
end

-- Recompute cached ground everywhere, wake every chunk and mark everything for redraw.
function ST.refresh(self: SandTable)
	for i = 0, self.w * self.h - 1 do
		local o = i * 8
		buffer.writef64(self.G, o, buffer.readf64(self.rock, o) + buffer.readf64(self.sand, o) + buffer.readf64(self.lava, o))
	end
	local nc = self.cw * self.ch
	buffer.fill(self.nextAwake, 0, 1, nc)
	buffer.fill(self.mdirty, 0, 1, nc)
	buffer.fill(self.tdirty, 0, 1, nc)
end

local function wakeRect(self: SandTable, x0: number, y0: number, x1: number, y1: number)
	local cx0, cy0 = math.max(x0 - 1, 0) // CS, math.max(y0 - 1, 0) // CS
	local cx1, cy1 = math.min(x1 + 1, self.w - 1) // CS, math.min(y1 + 1, self.h - 1) // CS
	for cy = cy0, cy1 do
		for cx = cx0, cx1 do
			local k = cy * self.cw + cx
			buffer.writeu8(self.nextAwake, k, 1)
			buffer.writeu8(self.mdirty, k, 1)
			buffer.writeu8(self.tdirty, k, 1)
		end
	end
end

-- Player tools ------------------------------------------------------------------------------------------------
-- Brush: smooth (1 - d^2/r^2)^2 falloff, `amount` studs at the centre. kind: "sand" | "water" | "lava" | "dig".
-- dig removes lava, then sand, then rock (never below 0); water is left to flow into the hole.
function ST.brush(self: SandTable, kind: string, cx: number, cy: number, r: number, amount: number)
	local w, h = self.w, self.h
	local x0, y0 = math.max(0, math.floor(cx - r)), math.max(0, math.floor(cy - r))
	local x1, y1 = math.min(w - 1, math.ceil(cx + r)), math.min(h - 1, math.ceil(cy + r))
	if x0 > x1 or y0 > y1 then
		return
	end
	local r2 = r * r
	local rock, sand, water, lava, G = self.rock, self.sand, self.water, self.lava, self.G
	for y = y0, y1 do
		for x = x0, x1 do
			local dx, dy = x + 0.5 - cx, y + 0.5 - cy
			local q = 1 - (dx * dx + dy * dy) / r2
			if q <= 0 then
				continue
			end
			local a = amount * q * q
			local o = (y * w + x) * 8
			if kind == "sand" then
				buffer.writef64(sand, o, buffer.readf64(sand, o) + a)
				self.addedSand += a
			elseif kind == "water" then
				buffer.writef64(water, o, buffer.readf64(water, o) + a)
				self.addedWater += a
			elseif kind == "lava" then
				buffer.writef64(lava, o, buffer.readf64(lava, o) + a)
				self.addedLava += a
			elseif kind == "dig" then
				local l = buffer.readf64(lava, o)
				local t = math.min(l, a)
				buffer.writef64(lava, o, l - t)
				self.removedLava += t
				a -= t
				local s = buffer.readf64(sand, o)
				t = math.min(s, a)
				buffer.writef64(sand, o, s - t)
				self.removedSand += t
				a -= t
				local rk = buffer.readf64(rock, o)
				t = math.min(rk, a)
				buffer.writef64(rock, o, rk - t)
				self.removedRock += t
			end
			buffer.writef64(G, o, buffer.readf64(rock, o) + buffer.readf64(sand, o) + buffer.readf64(lava, o))
		end
	end
	wakeRect(self, x0, y0, x1, y1)
end

function ST.dropSand(self: SandTable, x: number, y: number, r: number, amount: number)
	self:brush("sand", x, y, r, amount)
end
function ST.pourWater(self: SandTable, x: number, y: number, r: number, amount: number)
	self:brush("water", x, y, r, amount)
end
function ST.spawnLava(self: SandTable, x: number, y: number, r: number, amount: number)
	self:brush("lava", x, y, r, amount)
end
function ST.dig(self: SandTable, x: number, y: number, r: number, amount: number)
	self:brush("dig", x, y, r, amount)
end

-- Simulation --------------------------------------------------------------------------------------------------

-- Pass A (awake chunk): steam decay, lava cooling, water pipe fluxes, lava and sand transfers into deltas.
-- Returns whether lava/steam is animating, and the largest direct water change (boil-off, evaporation).
local function passA(self: SandTable, cx: number, cy: number): (boolean, number)
	local W, H = self.w, self.h
	local x0, y0 = cx * CS, cy * CS
	local x1, y1 = math.min(x0 + CS, W) - 1, math.min(y0 + CS, H) - 1
	local G, Wb, Sb, Lb, Rb = self.G, self.water, self.sand, self.lava, self.rock
	local fL, fR, fT, fB = self.fL, self.fR, self.fT, self.fB
	local dS, dL, steam, basalt, lmove = self.dS, self.dL, self.steam, self.basalt, self.lmove
	local kPipe, damp, wetEps = self.kPipe, self.damp, self.wetEps
	local coolAir, coolFrac, coolWater, steamRatio, evap = self.coolAir, self.coolFrac, self.coolWater, self.steamRatio, self.evap
	local kLava, lavaYield, lavaMaxFrac = self.kLava, self.lavaYield, self.lavaMaxFrac
	local cell = self.cell
	local tDry, tWet, slideRate, slideDead = self.talusDry * cell, self.talusWet * cell, self.slideRate, self.slideDead
	local act = false
	local direct = 0
	local fused, cooled, steamed, evaped, hiss = 0, 0, 0, 0, 0
	for y = y0, y1 do
		local row = y * W
		for x = x0, x1 do
			local i = row + x
			local o = i * 8
			local st = buffer.readu8(steam, i)
			if st > 0 then
				buffer.writeu8(steam, i, if st > STEAM_DECAY then st - STEAM_DECAY else 0)
				act = true
			end
			local wv = buffer.readf64(Wb, o)
			local l = buffer.readf64(Lb, o)
			local s = buffer.readf64(Sb, o)
			if evap > 0 and wv > 0 then
				local e = if wv < evap then wv else evap
				wv -= e
				evaped += e
				if e > direct then
					direct = e
				end
				buffer.writef64(Wb, o, wv)
			end
			if l > 0 then
				-- cooling: lava -> basalt (ground height unchanged); sand underneath fuses into the rock
				act = true
				local contact = wv > wetEps
				local c = if contact then coolWater else coolAir + coolFrac * l
				if c > l or l < 0.004 then
					c = l
				end
				l -= c
				buffer.writef64(Lb, o, l)
				buffer.writef64(Rb, o, buffer.readf64(Rb, o) + c + s)
				buffer.writeu8(basalt, i, 1)
				cooled += c
				if s > 0 then
					fused += s
					s = 0
					buffer.writef64(Sb, o, 0)
				end
				if contact then
					local e = c * steamRatio
					if e > wv then
						e = wv
					end
					wv -= e
					steamed += e
					if e > direct then
						direct = e
					end
					buffer.writef64(Wb, o, wv)
					buffer.writeu8(steam, i, 255)
					hiss += 1
				end
			end
			local g = buffer.readf64(G, o)
			local gl = if x > 0 then buffer.readf64(G, o - 8) else INF
			local gr = if x < W - 1 then buffer.readf64(G, o + 8) else INF
			local gt = if y > 0 then buffer.readf64(G, o - W * 8) else INF
			local gb = if y < H - 1 then buffer.readf64(G, o + W * 8) else INF
			-- water: virtual pipes (flux in studs of depth per step), scaled so outflow <= depth
			local o4 = i * 4
			if wv > 0 then
				local hw = g + wv
				local fl, fr, ft, fb = 0, 0, 0, 0
				if x > 0 then
					fl = buffer.readf32(fL, o4) * damp + kPipe * (hw - gl - buffer.readf64(Wb, o - 8))
					if fl < 0 then
						fl = 0
					end
				end
				if x < W - 1 then
					fr = buffer.readf32(fR, o4) * damp + kPipe * (hw - gr - buffer.readf64(Wb, o + 8))
					if fr < 0 then
						fr = 0
					end
				end
				if y > 0 then
					ft = buffer.readf32(fT, o4) * damp + kPipe * (hw - gt - buffer.readf64(Wb, o - W * 8))
					if ft < 0 then
						ft = 0
					end
				end
				if y < H - 1 then
					fb = buffer.readf32(fB, o4) * damp + kPipe * (hw - gb - buffer.readf64(Wb, o + W * 8))
					if fb < 0 then
						fb = 0
					end
				end
				local sum = fl + fr + ft + fb
				if sum > wv then
					local k = wv / sum * (1 - 1e-6) -- margin: the stored f32 fluxes may round up
					fl, fr, ft, fb = fl * k, fr * k, ft * k, fb * k
				end
				buffer.writef32(fL, o4, fl)
				buffer.writef32(fR, o4, fr)
				buffer.writef32(fT, o4, ft)
				buffer.writef32(fB, o4, fb)
			else
				buffer.writef32(fL, o4, 0)
				buffer.writef32(fR, o4, 0)
				buffer.writef32(fT, o4, 0)
				buffer.writef32(fB, o4, 0)
			end
			-- lava: flows only where the drop beats yield / thickness (thin lava stalls, thick lobes advance)
			if l > 0.004 then
				local thr = lavaYield / l
				local thd = thr * SQRT2
				local al, ar, at, ab = g - gl - thr, g - gr - thr, g - gt - thr, g - gb - thr
				al = if al > 0 then al * kLava else 0
				ar = if ar > 0 then ar * kLava else 0
				at = if at > 0 then at * kLava else 0
				ab = if ab > 0 then ab * kLava else 0
				-- diagonals (drop over sqrt2 cells, weight 1/sqrt2) keep flows from growing grid-aligned arms
				local dtl, dtr, dbl, dbr = 0, 0, 0, 0
				local kd = kLava / SQRT2
				if y > 0 then
					if x > 0 then
						dtl = g - buffer.readf64(G, o - W * 8 - 8) - thd
						dtl = if dtl > 0 then dtl * kd else 0
					end
					if x < W - 1 then
						dtr = g - buffer.readf64(G, o - W * 8 + 8) - thd
						dtr = if dtr > 0 then dtr * kd else 0
					end
				end
				if y < H - 1 then
					if x > 0 then
						dbl = g - buffer.readf64(G, o + W * 8 - 8) - thd
						dbl = if dbl > 0 then dbl * kd else 0
					end
					if x < W - 1 then
						dbr = g - buffer.readf64(G, o + W * 8 + 8) - thd
						dbr = if dbr > 0 then dbr * kd else 0
					end
				end
				local sum = al + ar + at + ab + dtl + dtr + dbl + dbr
				local mv = math.min(sum / l * 900, 255)
				buffer.writeu8(lmove, i, math.floor(buffer.readu8(lmove, i) * 0.9 + mv * 0.1))
				if sum > 0 then
					local cap = lavaMaxFrac * l
					if sum > cap then
						local k = cap / sum
						al, ar, at, ab = al * k, ar * k, at * k, ab * k
						dtl, dtr, dbl, dbr = dtl * k, dtr * k, dbl * k, dbr * k
						sum = cap
					end
					buffer.writef64(dL, o, buffer.readf64(dL, o) - sum)
					if al > 0 then
						buffer.writef64(dL, o - 8, buffer.readf64(dL, o - 8) + al)
					end
					if ar > 0 then
						buffer.writef64(dL, o + 8, buffer.readf64(dL, o + 8) + ar)
					end
					if at > 0 then
						buffer.writef64(dL, o - W * 8, buffer.readf64(dL, o - W * 8) + at)
					end
					if ab > 0 then
						buffer.writef64(dL, o + W * 8, buffer.readf64(dL, o + W * 8) + ab)
					end
					if dtl > 0 then
						buffer.writef64(dL, o - W * 8 - 8, buffer.readf64(dL, o - W * 8 - 8) + dtl)
					end
					if dtr > 0 then
						buffer.writef64(dL, o - W * 8 + 8, buffer.readf64(dL, o - W * 8 + 8) + dtr)
					end
					if dbl > 0 then
						buffer.writef64(dL, o + W * 8 - 8, buffer.readf64(dL, o + W * 8 - 8) + dbl)
					end
					if dbr > 0 then
						buffer.writef64(dL, o + W * 8 + 8, buffer.readf64(dL, o + W * 8 + 8) + dbr)
					end
				end
			end
			-- sand: avalanche to the 8 neighbours past the angle of repose
			if s > 1e-6 then
				local tal = if wv > wetEps then tWet else tDry
				local tald = tal * SQRT2
				local el, er, et, eb = g - gl - tal, g - gr - tal, g - gt - tal, g - gb - tal
				local etl, etr, ebl, ebr = -1, -1, -1, -1
				if y > 0 then
					if x > 0 then
						etl = g - buffer.readf64(G, o - W * 8 - 8) - tald
					end
					if x < W - 1 then
						etr = g - buffer.readf64(G, o - W * 8 + 8) - tald
					end
				end
				if y < H - 1 then
					if x > 0 then
						ebl = g - buffer.readf64(G, o + W * 8 - 8) - tald
					end
					if x < W - 1 then
						ebr = g - buffer.readf64(G, o + W * 8 + 8) - tald
					end
				end
				local m = math.max(el, er, et, eb, etl, etr, ebl, ebr)
				if m > slideDead then
					el = if el > 0 then el else 0
					er = if er > 0 then er else 0
					et = if et > 0 then et else 0
					eb = if eb > 0 then eb else 0
					etl = if etl > 0 then etl else 0
					etr = if etr > 0 then etr else 0
					ebl = if ebl > 0 then ebl else 0
					ebr = if ebr > 0 then ebr else 0
					local sumE = el + er + et + eb + etl + etr + ebl + ebr
					local mv = slideRate * m * 0.5
					if mv > s * 0.5 then
						mv = s * 0.5
					end
					local k = mv / sumE
					buffer.writef64(dS, o, buffer.readf64(dS, o) - mv)
					if el > 0 then
						buffer.writef64(dS, o - 8, buffer.readf64(dS, o - 8) + el * k)
					end
					if er > 0 then
						buffer.writef64(dS, o + 8, buffer.readf64(dS, o + 8) + er * k)
					end
					if et > 0 then
						buffer.writef64(dS, o - W * 8, buffer.readf64(dS, o - W * 8) + et * k)
					end
					if eb > 0 then
						buffer.writef64(dS, o + W * 8, buffer.readf64(dS, o + W * 8) + eb * k)
					end
					if etl > 0 then
						buffer.writef64(dS, o - W * 8 - 8, buffer.readf64(dS, o - W * 8 - 8) + etl * k)
					end
					if etr > 0 then
						buffer.writef64(dS, o - W * 8 + 8, buffer.readf64(dS, o - W * 8 + 8) + etr * k)
					end
					if ebl > 0 then
						buffer.writef64(dS, o + W * 8 - 8, buffer.readf64(dS, o + W * 8 - 8) + ebl * k)
					end
					if ebr > 0 then
						buffer.writef64(dS, o + W * 8 + 8, buffer.readf64(dS, o + W * 8 + 8) + ebr * k)
					end
				end
			end
		end
	end
	self.fusedSand += fused
	self.cooledLava += cooled
	self.steamWater += steamed
	self.evapWater += evaped
	self.hiss += hiss
	return act, direct
end

-- Pass B (awake chunk): erosion/deposition from pipe velocity, then scatter water + sediment along the fluxes.
local function passB(self: SandTable, cx: number, cy: number): boolean
	local W, H = self.w, self.h
	local x0, y0 = cx * CS, cy * CS
	local x1, y1 = math.min(x0 + CS, W) - 1, math.min(y0 + CS, H) - 1
	local Wb, Sb, Sed = self.water, self.sand, self.sed
	local fL, fR, fT, fB = self.fL, self.fR, self.fT, self.fB
	local dW, dSed = self.dW, self.dSed
	local wetEps, Kc, Ks, Kd, maxEro, capDepth = self.wetEps, self.Kc, self.Ks, self.Kd, self.maxEro, self.capDepth
	local act = false
	for y = y0, y1 do
		local row = y * W
		for x = x0, x1 do
			local i = row + x
			local o, o4 = i * 8, i * 4
			local wv = buffer.readf64(Wb, o)
			local sd = buffer.readf64(Sed, o)
			if wv <= 0 and sd <= 0 then
				continue
			end
			local fl, fr, ft, fb = buffer.readf32(fL, o4), buffer.readf32(fR, o4), buffer.readf32(fT, o4), buffer.readf32(fB, o4)
			local sum = fl + fr + ft + fb
			if wv > wetEps then
				local inL = if x > 0 then buffer.readf32(fR, o4 - 4) else 0
				local inR = if x < W - 1 then buffer.readf32(fL, o4 + 4) else 0
				local inT = if y > 0 then buffer.readf32(fB, o4 - W * 4) else 0
				local inB = if y < H - 1 then buffer.readf32(fT, o4 + W * 4) else 0
				local vx = (inL - fl + fr - inR) * 0.5
				local vy = (inT - ft + fb - inB) * 0.5
				local spd = math.sqrt(vx * vx + vy * vy) / (wv + 0.02)
				local cap = Kc * spd * (if wv < capDepth then wv else capDepth)
				local s = buffer.readf64(Sb, o)
				if cap > sd then
					local e = Ks * (cap - sd)
					if e > maxEro then
						e = maxEro
					end
					if e > s * 0.5 then
						e = s * 0.5
					end
					s -= e
					sd += e
				else
					local d = Kd * (sd - cap)
					if sd < 1e-5 then
						d = sd
					end
					s += d
					sd -= d
				end
				buffer.writef64(Sb, o, s)
				buffer.writef64(Sed, o, sd)
				if sum > FLOW_EPS then
					act = true
				end
			elseif sd > 0 then -- dried out: drop the load
				buffer.writef64(Sb, o, buffer.readf64(Sb, o) + sd)
				buffer.writef64(Sed, o, 0)
				if sd > ACT_EPS then
					act = true
				end
				sd = 0
			end
			if sum > 0 then
				local c = sd / wv
				buffer.writef64(dW, o, buffer.readf64(dW, o) - sum)
				buffer.writef64(dSed, o, buffer.readf64(dSed, o) - sum * c)
				if fl > 0 then
					buffer.writef64(dW, o - 8, buffer.readf64(dW, o - 8) + fl)
					buffer.writef64(dSed, o - 8, buffer.readf64(dSed, o - 8) + fl * c)
				end
				if fr > 0 then
					buffer.writef64(dW, o + 8, buffer.readf64(dW, o + 8) + fr)
					buffer.writef64(dSed, o + 8, buffer.readf64(dSed, o + 8) + fr * c)
				end
				if ft > 0 then
					buffer.writef64(dW, o - W * 8, buffer.readf64(dW, o - W * 8) + ft)
					buffer.writef64(dSed, o - W * 8, buffer.readf64(dSed, o - W * 8) + ft * c)
				end
				if fb > 0 then
					buffer.writef64(dW, o + W * 8, buffer.readf64(dW, o + W * 8) + fb)
					buffer.writef64(dSed, o + W * 8, buffer.readf64(dSed, o + W * 8) + fb * c)
				end
			end
		end
	end
	return act
end

-- Pass C: apply deltas in a rect, refresh cached ground. Returns: the largest change (height, water, 4x sediment),
-- whether any change exceeded ACT_EPS,
-- and whether that significant change touched the left/right/top/bottom edge of chunk [ex0..ex1]x[ey0..ey1].
local function applyRect(self: SandTable, x0: number, y0: number, x1: number, y1: number, ex0: number, ey0: number, ex1: number, ey1: number): (number, boolean, boolean, boolean, boolean, boolean)
	local W = self.w
	local G, Wb, Sb, Lb, Rb, Sed = self.G, self.water, self.sand, self.lava, self.rock, self.sed
	local dW, dS, dSed, dL = self.dW, self.dS, self.dSed, self.dL
	local mx, sig, eL, eR, eT, eB = 0, false, false, false, false, false
	local loss = 0
	for y = y0, y1 do
		for x = x0, x1 do
			local o = (y * W + x) * 8
			local dw, ds, dd, dl = buffer.readf64(dW, o), buffer.readf64(dS, o), buffer.readf64(dSed, o), buffer.readf64(dL, o)
			local s, l = buffer.readf64(Sb, o), buffer.readf64(Lb, o)
			if dw ~= 0 or dd ~= 0 then
				local wv, sd = buffer.readf64(Wb, o) + dw, buffer.readf64(Sed, o) + dd
				if wv < 0 then
					loss += wv
					wv = 0
				end
				if sd < 0 then
					loss += sd
					sd = 0
				end
				buffer.writef64(Wb, o, wv)
				buffer.writef64(Sed, o, sd)
				buffer.writef64(dW, o, 0)
				buffer.writef64(dSed, o, 0)
			end
			if ds ~= 0 then
				s += ds
				if s < 0 then
					loss += s
					s = 0
				end
				buffer.writef64(Sb, o, s)
				buffer.writef64(dS, o, 0)
			end
			if dl ~= 0 then
				l += dl
				if l < 0 then
					loss += l
					l = 0
				end
				buffer.writef64(Lb, o, l)
				buffer.writef64(dL, o, 0)
			end
			local g = buffer.readf64(Rb, o) + s + l
			local og = buffer.readf64(G, o)
			if g ~= og then
				buffer.writef64(G, o, g)
			end
			local dg = g - og
			local m = math.max(math.abs(dg), math.abs(dw), math.abs(dd) * 4)
			if m > mx then
				mx = m
			end
			if dg > ACT_EPS or dg < -ACT_EPS or dw > ACT_EPS or dw < -ACT_EPS then
				sig = true
				if x == ex0 then
					eL = true
				elseif x == ex1 then
					eR = true
				end
				if y == ey0 then
					eT = true
				elseif y == ey1 then
					eB = true
				end
			end
		end
	end
	self.clampLoss += loss
	return mx, sig, eL, eR, eT, eB
end

local function wakeAround(self: SandTable, cx: number, cy: number, eL: boolean, eR: boolean, eT: boolean, eB: boolean)
	local cw, ch, na = self.cw, self.ch, self.nextAwake
	local x0 = if eL and cx > 0 then cx - 1 else cx
	local x1 = if eR and cx < cw - 1 then cx + 1 else cx
	local y0 = if eT and cy > 0 then cy - 1 else cy
	local y1 = if eB and cy < ch - 1 then cy + 1 else cy
	for yy = y0, y1 do
		for xx = x0, x1 do
			buffer.writeu8(na, yy * cw + xx, 1)
		end
	end
end

local function zeroFlux(self: SandTable, cx: number, cy: number)
	local W = self.w
	local x0, y0 = cx * CS, cy * CS
	local x1, y1 = math.min(x0 + CS, W) - 1, math.min(y0 + CS, self.h) - 1
	local n = (x1 - x0 + 1) * 4
	for y = y0, y1 do
		local o = (y * W + x0) * 4
		buffer.fill(self.fL, o, 0, n)
		buffer.fill(self.fR, o, 0, n)
		buffer.fill(self.fT, o, 0, n)
		buffer.fill(self.fB, o, 0, n)
	end
end

-- Redraw only after a visible amount of change: the per-step max change is summed per chunk (an upper bound on
-- any cell's drift) and the chunk is marked for mesh / texture rebuild when the sum passes MESH_EPS / TEX_EPS.
local function accumulate(self: SandTable, k: number, mx: number)
	if mx <= 0 then
		return
	end
	local m, t = self.macc[k + 1] + mx, self.tacc[k + 1] + mx
	if m > MESH_EPS then
		buffer.writeu8(self.mdirty, k, 1)
		m = 0
	end
	if t > TEX_EPS then
		buffer.writeu8(self.tdirty, k, 1)
		t = 0
	end
	self.macc[k + 1], self.tacc[k + 1] = m, t
end

-- Mark every chunk with any pending (sub-threshold) change for redraw, e.g. before an exact comparison.
function ST.flushRender(self: SandTable)
	for k = 0, self.cw * self.ch - 1 do
		if self.macc[k + 1] > 0 then
			buffer.writeu8(self.mdirty, k, 1)
			self.macc[k + 1] = 0
		end
		if self.tacc[k + 1] > 0 then
			buffer.writeu8(self.tdirty, k, 1)
			self.tacc[k + 1] = 0
		end
	end
end

-- One simulation step over awake chunks (+ the rims of sleeping chunks next to them).
function ST.step(self: SandTable)
	local cw, ch, W, H = self.cw, self.ch, self.w, self.h
	local prev = self.awake
	local awake = self.nextAwake
	self.awake, self.nextAwake = awake, prev
	self.hiss = 0
	self.steps += 1
	local n = 0
	for k = 0, cw * ch - 1 do
		local a = buffer.readu8(awake, k)
		n += a
		if a == 0 and buffer.readu8(prev, k) ~= 0 then
			zeroFlux(self, k % cw, k // cw)
		end
	end
	local na = prev
	buffer.fill(na, 0, 0)
	self.activeChunks = n
	if n == 0 then
		return
	end
	for cy = 0, ch - 1 do
		for cx = 0, cw - 1 do
			local k = cy * cw + cx
			if buffer.readu8(awake, k) ~= 0 then
				local anim, direct = passA(self, cx, cy)
				if anim then -- lava / steam: the texture animates (cooling keeps ground height unchanged)
					buffer.writeu8(na, k, 1)
					buffer.writeu8(self.tdirty, k, 1)
				end
				accumulate(self, k, direct)
			end
		end
	end
	for cy = 0, ch - 1 do
		for cx = 0, cw - 1 do
			local k = cy * cw + cx
			if buffer.readu8(awake, k) ~= 0 and passB(self, cx, cy) then
				buffer.writeu8(na, k, 1)
			end
		end
	end
	for cy = 0, ch - 1 do
		for cx = 0, cw - 1 do
			local k = cy * cw + cx
			local x0, y0 = cx * CS, cy * CS
			local x1, y1 = math.min(x0 + CS, W) - 1, math.min(y0 + CS, H) - 1
			if buffer.readu8(awake, k) ~= 0 then
				local mx, sig, eL, eR, eT, eB = applyRect(self, x0, y0, x1, y1, x0, y0, x1, y1)
				accumulate(self, k, mx)
				if sig then
					buffer.writeu8(na, k, 1)
					wakeAround(self, cx, cy, eL, eR, eT, eB)
				end
			else
				-- sleeping: deltas can only have landed on the rim facing an awake neighbour
				local nb = false
				for yy = math.max(cy - 1, 0), math.min(cy + 1, ch - 1) do
					for xx = math.max(cx - 1, 0), math.min(cx + 1, cw - 1) do
						if buffer.readu8(awake, yy * cw + xx) ~= 0 then
							nb = true
						end
					end
				end
				if nb then
					local a1, s1, l1, r1, t1, b1 = applyRect(self, x0, y0, x1, y0, x0, y0, x1, y1)
					local a2, s2, l2, r2, t2, b2 = applyRect(self, x0, y1, x1, y1, x0, y0, x1, y1)
					local a3, s3, l3, r3, t3, b3 = applyRect(self, x0, y0 + 1, x0, y1 - 1, x0, y0, x1, y1)
					local a4, s4, l4, r4, t4, b4 = applyRect(self, x1, y0 + 1, x1, y1 - 1, x0, y0, x1, y1)
					accumulate(self, k, math.max(a1, a2, a3, a4))
					if s1 or s2 or s3 or s4 then
						buffer.writeu8(na, k, 1)
						wakeAround(self, cx, cy, l1 or l2 or l3 or l4, r1 or r2 or r3 or r4, t1 or t2 or t3 or t4, b1 or b2 or b3 or b4)
					end
				end
			end
		end
	end
end

function ST.awakeCount(self: SandTable): number
	local n = 0
	for k = 0, self.cw * self.ch - 1 do
		n += buffer.readu8(self.nextAwake, k)
	end
	return n
end

-- Sums for mass checks (test helper; allocates).
function ST.totals(self: SandTable): { [string]: number }
	local t = { rock = 0, sand = 0, water = 0, sed = 0, lava = 0 }
	for i = 0, self.w * self.h - 1 do
		local o = i * 8
		t.rock += buffer.readf64(self.rock, o)
		t.sand += buffer.readf64(self.sand, o)
		t.water += buffer.readf64(self.water, o)
		t.sed += buffer.readf64(self.sed, o)
		t.lava += buffer.readf64(self.lava, o)
	end
	return t
end

-- Texture -----------------------------------------------------------------------------------------------------

local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Colour of one cell: rock / basalt / sand (thin sand shows rock), wet darkening, lava glow, underwater
-- absorption with sediment turbidity, steam. Returns packed RGBA8 and glow 0..255.
local function cellColor(self: SandTable, i: number): (number, number)
	local o = i * 8
	local s = buffer.readf64(self.sand, o)
	local wv = buffer.readf64(self.water, o)
	local l = buffer.readf64(self.lava, o)
	local tn = buffer.readu8(self.tone, i) / 255
	local r, g, b
	if buffer.readu8(self.basalt, i) ~= 0 then
		local v = 0.8 + 0.4 * tn
		r, g, b = 58 * v, 52 * v, 54 * v
	else
		-- layered rock: strata bands by rock height (wobbled by the static noise) between buff and grey-brown
		local rh = buffer.readf64(self.rock, o)
		local band = 0.5 + 0.5 * math.sin(rh * 1.1 + tn * 2.2)
		band = band * band
		local v = 0.85 + 0.25 * tn
		r, g, b = mix(116, 140, band) * v, mix(108, 120, band) * v, mix(100, 98, band) * v
	end
	if s > 0 then
		local k = math.min(s / 0.5, 1)
		local v = 0.93 + 0.12 * tn
		r, g, b = mix(r, 228 * v, k), mix(g, 192 * v, k), mix(b, 134 * v, k)
	end
	-- damp: thin films and anything under water darken
	local wet = math.min(wv / 0.03, 1)
	r, g, b = r * (1 - 0.38 * wet), g * (1 - 0.36 * wet), b * (1 - 0.3 * wet)
	local glow = 0
	if l > 0 then
		-- moving or thick lava glows; still lava skins over with dark crust plates and glowing seams
		local mv = buffer.readu8(self.lmove, i) / 255
		local heat = math.min(l / 2, 1)
		local seam = math.clamp(1 - math.abs(tn - 0.5) * 8, 0, 1)
		local hot = math.clamp(mv * 1.15, 0, 1) * (0.55 + 0.45 * heat)
		hot = math.max(hot, seam * (0.3 + 0.4 * heat))
		-- crust -> dark red -> orange -> yellow
		local lr, lg, lb
		if hot < 0.35 then
			local q = hot / 0.35
			lr, lg, lb = mix(38, 140, q), mix(30, 26, q), mix(30, 12, q)
		elseif hot < 0.75 then
			local q = (hot - 0.35) / 0.4
			lr, lg, lb = mix(140, 240, q), mix(26, 96, q), mix(12, 16, q)
		else
			local q = (hot - 0.75) / 0.25
			lr, lg, lb = mix(240, 255, q), mix(96, 214, q), mix(16, 96, q)
		end
		local k = math.min(l / 0.03, 1)
		r, g, b = mix(r, lr, k), mix(g, lg, k), mix(b, lb, k)
		glow = math.floor(200 * k * hot * hot)
	end
	if wv > 0.01 then
		local sd = buffer.readf64(self.sed, o)
		local turb = math.min(sd / wv * 12, 1)
		local a = 1 - math.exp(-wv * 0.55)
		local wr, wg, wb = mix(16, 104, turb), mix(70, 92, turb), mix(98, 58, turb)
		a = math.min(a * 0.92 + turb * 0.25, 0.95)
		r, g, b = mix(r, wr, a), mix(g, wg, a), mix(b, wb, a)
	end
	local st = buffer.readu8(self.steam, i)
	if st > 0 then
		local k = st / 255 * 0.75
		r, g, b = mix(r, 236, k), mix(g, 236, k), mix(b, 240, k)
	end
	local px = bit32.bor(math.floor(math.min(r, 255)), bit32.lshift(math.floor(math.min(g, 255)), 8), bit32.lshift(math.floor(math.min(b, 255)), 16), 0xFF000000)
	return px, glow
end

local function texChunk(self: SandTable, cx: number, cy: number)
	local W = self.w
	local x0, y0 = cx * CS, cy * CS
	local x1, y1 = math.min(x0 + CS, W) - 1, math.min(y0 + CS, self.h) - 1
	local tex, emit = self.tex, self.emit
	for y = y0, y1 do
		for x = x0, x1 do
			local i = y * W + x
			local c, e = cellColor(self, i)
			buffer.writeu32(tex, i * 4, c)
			buffer.writeu8(emit, i, e)
		end
	end
end

-- Rebuild texels of chunks dirtied since the last call; marks them for upload. Returns chunks rebuilt.
function ST.updateTexture(self: SandTable): number
	local n = 0
	local td, ud = self.tdirty, self.udirty
	for k = 0, self.cw * self.ch - 1 do
		if buffer.readu8(td, k) ~= 0 then
			texChunk(self, k % self.cw, k // self.cw)
			buffer.writeu8(td, k, 0)
			buffer.writeu8(ud, k, 1)
			n += 1
		end
	end
	return n
end

-- Full rebuild (reference for the incremental check).
function ST.fullTexture(self: SandTable)
	for k = 0, self.cw * self.ch - 1 do
		texChunk(self, k % self.cw, k // self.cw)
	end
end

-- Meshes ------------------------------------------------------------------------------------------------------

-- Vertex images over vertex rect [vx0..vx1] x [vy0..vy1]: ground = tent-filtered cells; water = highest wet
-- surface among the 4 touching cells, else the nearest wet level (cells within 2), else hidden: snapped to a
-- 4-stud band at least hideDrop under the ground, so dry ground changes rarely move the water layer.
-- Returns bounding boxes (x0 > x1 when empty) of changed ground vertices, changed water vertices, and changed
-- ground vertices under visible water (the water colour reads the depth there).
local HIDE_BAND = 4
local function sampleVerts(self: SandTable, vx0: number, vy0: number, vx1: number, vy1: number): (number, number, number, number, number, number, number, number, number, number, number, number)
	local W, H = self.w, self.h
	local gi, wi = (self.groundImg :: HM.Image).data, (self.waterImg :: HM.Image).data
	local G, Wb = self.G, self.water
	local wetShow, hide = self.wetShow, self.hideDrop
	local vw = W + 1
	local gx0, gy0, gx1, gy1 = INF, INF, -1, -1
	local wx0, wy0, wx1, wy1 = INF, INF, -1, -1
	local cx0, cy0, cx1, cy1 = INF, INF, -1, -1
	-- any water near this rect at all? (dry chunks skip the shore search)
	local anyWet = false
	for cy = math.max(vy0 - 2, 0), math.min(vy1 + 1, H - 1) do
		for cx = math.max(vx0 - 2, 0), math.min(vx1 + 1, W - 1) do
			if buffer.readf64(Wb, (cy * W + cx) * 8) > wetShow then
				anyWet = true
				break
			end
		end
		if anyWet then
			break
		end
	end
	for vy = vy0, vy1 do
		local ya, yb = math.max(vy - 1, 0), math.min(vy, H - 1)
		local yA, yB = math.max(vy - 2, 0), math.min(vy + 1, H - 1)
		for vx = vx0, vx1 do
			local xa, xb = math.max(vx - 1, 0), math.min(vx, W - 1)
			local xA, xB = math.max(vx - 2, 0), math.min(vx + 1, W - 1)
			local o1, o2, o3, o4 = (ya * W + xa) * 8, (ya * W + xb) * 8, (yb * W + xa) * 8, (yb * W + xb) * 8
			local g1, g2, g3, g4 = buffer.readf64(G, o1), buffer.readf64(G, o2), buffer.readf64(G, o3), buffer.readf64(G, o4)
			-- (1,3,3,1)^2 / 64 over the 4x4 cells round the vertex: rounds off angle-of-repose crests and toes
			-- that would otherwise alias into cell-sized stairs (render only; the sim keeps its columns)
			local rA, rB = yA * W, yB * W
			local edge = buffer.readf64(G, (rA + xa) * 8) + buffer.readf64(G, (rA + xb) * 8) + buffer.readf64(G, (rB + xa) * 8) + buffer.readf64(G, (rB + xb) * 8)
				+ buffer.readf64(G, (ya * W + xA) * 8) + buffer.readf64(G, (yb * W + xA) * 8) + buffer.readf64(G, (ya * W + xB) * 8) + buffer.readf64(G, (yb * W + xB) * 8)
			local corner = buffer.readf64(G, (rA + xA) * 8) + buffer.readf64(G, (rA + xB) * 8) + buffer.readf64(G, (rB + xA) * 8) + buffer.readf64(G, (rB + xB) * 8)
			local ga = ((g1 + g2 + g3 + g4) * 9 + edge * 3 + corner) / 64
			local m = -INF
			if anyWet then
				local w1, w2, w3, w4 = buffer.readf64(Wb, o1), buffer.readf64(Wb, o2), buffer.readf64(Wb, o3), buffer.readf64(Wb, o4)
				if w1 > wetShow and g1 + w1 > m then
					m = g1 + w1
				end
				if w2 > wetShow and g2 + w2 > m then
					m = g2 + w2
				end
				if w3 > wetShow and g3 + w3 > m then
					m = g3 + w3
				end
				if w4 > wetShow and g4 + w4 > m then
					m = g4 + w4
				end
				if m == -INF then
					-- dry vertex next to water: continue the neighbours' level flat (capped just under this
					-- ground), so the shoreline is where a level plane meets the bank, not a sliver triangle
					local ex = -INF
					for cy = yA, yB do
						for cx = xA, xB do
							local oc = (cy * W + cx) * 8
							local wc = buffer.readf64(Wb, oc)
							if wc > wetShow then
								local sfc = buffer.readf64(G, oc) + wc
								if sfc > ex then
									ex = sfc
								end
							end
						end
					end
					if ex > -INF then
						m = math.min(ex, ga - 0.05)
					end
				end
			end
			local visible = m > -INF
			if not visible then
				m = math.floor((ga - hide) / HIDE_BAND) * HIDE_BAND
			end
			local vi = (vy * vw + vx) * 4
			local gq = math.floor(ga * Q + 0.5) / Q
			local wq = math.floor(m * QW + 0.5) / QW
			if buffer.readf32(gi, vi) ~= gq then
				buffer.writef32(gi, vi, gq)
				gx0, gx1 = math.min(gx0, vx), math.max(gx1, vx)
				gy0, gy1 = math.min(gy0, vy), math.max(gy1, vy)
				if visible then
					cx0, cx1 = math.min(cx0, vx), math.max(cx1, vx)
					cy0, cy1 = math.min(cy0, vy), math.max(cy1, vy)
				end
			end
			if buffer.readf32(wi, vi) ~= wq then
				buffer.writef32(wi, vi, wq)
				wx0, wx1 = math.min(wx0, vx), math.max(wx1, vx)
				wy0, wy1 = math.min(wy0, vy), math.max(wy1, vy)
			end
		end
	end
	return gx0, gy0, gx1, gy1, wx0, wy0, wx1, wy1, cx0, cy0, cx1, cy1
end

local function packRGBA(r: number, g: number, b: number, a: number): number
	return bit32.bor(math.floor(r), bit32.lshift(math.floor(g), 8), bit32.lshift(math.floor(b), 16), bit32.lshift(math.floor(a), 24))
end

-- Build both HeightfieldMesh layers. opts: skirtFloor (Y of the flat table base, default 0) or skirt (relative
-- drop instead), waterSkirt, ranges (LOD; default none).
-- Requires w == h == k*64. Allocates (setup path).
function ST.buildMeshes(self: SandTable, opts: { [string]: any }?)
	local o = opts or {}
	local W, H = self.w, self.h
	assert(W == H and W % 64 == 0, "sand table meshes need a square k*64 grid")
	self.groundImg = { w = W + 1, h = H + 1, data = buffer.create((W + 1) * (H + 1) * 4), format = "f32" }
	self.waterImg = { w = W + 1, h = H + 1, data = buffer.create((W + 1) * (H + 1) * 4), format = "f32" }
	sampleVerts(self, 0, 0, W, H)
	local gdata, vw = (self.groundImg :: HM.Image).data, W + 1
	local ranges = o.ranges or {} -- a table is small: no LOD, so no morphing either
	self.ground = HM.newTerrain(self.groundImg :: HM.Image, {
		cell = self.cell,
		heightScale = 1,
		maxHeight = 64,
		ranges = ranges,
		skirt = o.skirt or 12,
		skirtFloor = if o.skirt then nil else (o.skirtFloor or 0), -- flat table base by default
		uvTile = W,
		colorFn = function()
			return 0xFFFFFFFF -- the texture carries the colour
		end,
	})
	self.waterMesh = HM.newTerrain(self.waterImg :: HM.Image, {
		cell = self.cell,
		heightScale = 1,
		maxHeight = 64,
		ranges = ranges,
		skirt = o.waterSkirt or 0.3,
		uvTile = W,
		colorFn = function(gx: number, gy: number, h: number, _ny: number): number
			local d = h - buffer.readf32(gdata, (gy * vw + gx) * 4)
			if d <= 0 then
				return packRGBA(60, 130, 150, 0)
			end
			local k = 1 - math.exp(-d * 0.35)
			local a = math.clamp(0.4 + d * 0.15, 0.4, 0.75)
			return packRGBA(mix(52, 14, k), mix(158, 62, k), mix(170, 100, k), a * 255)
		end,
	})
	local nk = #(self.ground :: HM.Terrain).chunks
	for k = 1, nk do
		self.colPending[k], self.colQuiet[k], self.colAge[k] = 0, 0, 0
	end
	buffer.fill(self.mdirty, 0, 0)
end

-- Per-frame mesh update: re-sample vertices of dirty sim chunks, then one updateRects call per layer over just
-- the vertices whose quantised height moved (water also where the ground moved: its colour reads the depth).
-- Fills groundChanged / waterChanged (chunks with changed vertex lists) and colDue (ground chunk keys whose
-- collision should be rebaked: quiet for colSettle frames after changing, or changing for colMaxWait frames).
-- maxChunks (optional) caps the sim chunks re-sampled per call (round robin; the rest stay dirty for later).
-- Returns the number of sim chunks re-sampled.
function ST.updateMeshes(self: SandTable, maxChunks: number?): number
	local cw, md, rects, wrects = self.cw, self.mdirty, self.rects, self.wrects
	local n, ng, nw = 0, 0, 0
	local nc = cw * self.ch
	local cap = maxChunks or nc
	local start = self.mcursor
	for kk = 0, nc - 1 do
		local k = (start + kk) % nc
		if n >= cap then
			self.mcursor = k
			break
		end
		if buffer.readu8(md, k) ~= 0 then
			buffer.writeu8(md, k, 0)
			n += 1
			local x0, y0 = (k % cw) * CS, (k // cw) * CS
			-- vertex v reads cells v-2..v+1, so a chunk's cells move vertices x0-1 .. x0+CS+1
			local gx0, gy0, gx1, gy1, wx0, wy0, wx1, wy1, cx0, cy0, cx1, cy1 = sampleVerts(self, math.max(x0 - 1, 0), math.max(y0 - 1, 0), math.min(x0 + CS + 1, self.w), math.min(y0 + CS + 1, self.h))
			if gx1 >= 0 then
				rects[ng * 4 + 1], rects[ng * 4 + 2], rects[ng * 4 + 3], rects[ng * 4 + 4] = gx0, gy0, gx1, gy1
				ng += 1
			end
			if cx1 >= 0 then -- depth changed under visible water: its colour changes too
				wx0, wy0, wx1, wy1 = math.min(wx0, cx0), math.min(wy0, cy0), math.max(wx1, cx1), math.max(wy1, cy1)
			end
			if wx1 >= 0 then
				wrects[nw * 4 + 1], wrects[nw * 4 + 2], wrects[nw * 4 + 3], wrects[nw * 4 + 4] = wx0, wy0, wx1, wy1
				nw += 1
			end
		end
	end
	local gt, wt = self.ground :: HM.Terrain, self.waterMesh :: HM.Terrain
	local due = self.colDue
	table.clear(due)
	self.groundChanged = HM.updateRects(gt, rects, ng)
	self.waterChanged = HM.updateRects(wt, wrects, nw)
	local pend, quiet, age, ncx = self.colPending, self.colQuiet, self.colAge, gt.ncx
	for _, c in self.groundChanged do
		local key = c.cy * ncx + c.cx + 1
		if pend[key] == 0 then
			age[key] = 0
		end
		pend[key], quiet[key] = 1, 0
	end
	for key = 1, #pend do
		if pend[key] ~= 0 then
			quiet[key] += 1
			age[key] += 1
			if quiet[key] > self.colSettle or age[key] >= self.colMaxWait then
				pend[key], age[key] = 0, 0
				table.insert(due, key)
			end
		end
	end
	return n
end

-- ROBLOX ADAPTER ----------------------------------------------------------------------------------------------
-- Cannot run headless. Per doc 21: CreateEditableMesh() is never FixedSize; visual edits through BatchSetValues
-- show at once; collision only changes through CreateMeshPartAsync + ApplyMesh (debounced via colDue);
-- MeshPart.TextureContent accepts Content.fromObject(EditableImage); one EditableImage is shared (multi-
-- referenced) by every ground part, so the whole texture costs one image of the editable budget.
-- [UNVERIFIED] carried over from HeightfieldMesh: BatchAdd default attributes, V origin (1 - v), part re-centring
-- (part placed at chunk origin + GetCenter()), colour alpha semantics (water passes per-vertex alpha).
-- Lava glow (self.emit) is preview-only here; in game, drive a few PointLights from it.

export type Mount = {
	img: any,
	stages: { [number]: buffer }, -- upload staging, keyed by run length in chunks
	ground: { { em: any, hnd: HM.MeshHandles, part: any } },
	water: { { em: any, hnd: HM.MeshHandles, part: any } },
}

local function pushAlpha(em: any, hnd: HM.MeshHandles, c: HM.Chunk, all: boolean)
	if not all and bit32.band(c.changedAttrs, 2) == 0 then
		return
	end
	local ids, vals = hnd.ids, hnd.vals
	table.clear(ids)
	table.clear(vals)
	local cnt = if all then c.vcount else c.changedCount
	for k = 1, cnt do
		local v = if all then k - 1 else buffer.readu32(c.changed, (k - 1) * 4)
		ids[k] = hnd.cids[v + 1]
		vals[k] = bit32.rshift(buffer.readu32(c.col, v * 4), 24) / 255
	end
	em:BatchSetValues(ids, vals)
end

function ST.robloxMount(self: SandTable, parent: any, origin: any): Mount
	local AssetService = game:GetService("AssetService")
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(self.w, self.h) })
	assert(img, "editable memory budget exhausted")
	self:fullTexture()
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(self.w, self.h), self.tex)
	local m: Mount = { img = img, stages = {}, ground = {}, water = {} }
	local texContent = Content.fromObject(img)
	for layer = 1, 2 do
		local t = (if layer == 1 then self.ground else self.waterMesh) :: HM.Terrain
		for k, c in t.chunks do
			local em = AssetService:CreateEditableMesh()
			local hnd = HM.toEditableMesh(em, c)
			if layer == 2 then
				pushAlpha(em, hnd, c, true)
			end
			local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
				CollisionFidelity = if layer == 1 then Enum.CollisionFidelity.Default else Enum.CollisionFidelity.Box,
			})
			local ox, oz = HM.chunkOrigin(t, c)
			part.Anchored = true
			part.Position = origin + Vector3.new(ox, 0, oz) + em:GetCenter()
			if layer == 1 then
				part.TextureContent = texContent
				part.Material = Enum.Material.SmoothPlastic
			else
				part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
				part.Transparency = 0.25
				part.Material = Enum.Material.Glass
			end
			part.Parent = parent
			local list = if layer == 1 then m.ground else m.water
			list[k] = { em = em, hnd = hnd, part = part }
		end
	end
	buffer.fill(self.udirty, 0, 0)
	return m
end

-- Call after step() / updateMeshes() / updateTexture(). Pushes changed vertices, dirty texture blocks, and
-- rebakes collision for chunks that settled.
function ST.robloxFrame(self: SandTable, m: Mount)
	local gt, wt = self.ground :: HM.Terrain, self.waterMesh :: HM.Terrain
	for _, c in self.groundChanged do
		local e = m.ground[c.cy * gt.ncx + c.cx + 1]
		HM.updateEditableMesh(e.em, e.hnd, c)
	end
	for _, c in self.waterChanged do
		local e = m.water[c.cy * wt.ncx + c.cx + 1]
		pushAlpha(e.em, e.hnd, c, false)
		HM.updateEditableMesh(e.em, e.hnd, c)
	end
	-- dirty texture chunks, merged into horizontal runs: one WritePixelsBuffer per run, exact-size stage
	-- buffers cached per run length (allocated once)
	local W, cw, ud, tex = self.w, self.cw, self.udirty, self.tex
	for cy = 0, self.ch - 1 do
		local cx = 0
		while cx < cw do
			if buffer.readu8(ud, cy * cw + cx) == 0 then
				cx += 1
				continue
			end
			local c0 = cx
			while cx < cw and buffer.readu8(ud, cy * cw + cx) ~= 0 do
				buffer.writeu8(ud, cy * cw + cx, 0)
				cx += 1
			end
			local x0, y0, rw = c0 * CS, cy * CS, (cx - c0) * CS
			local stage = m.stages[cx - c0]
			if not stage then
				stage = buffer.create(rw * CS * 4)
				m.stages[cx - c0] = stage
			end
			for r = 0, CS - 1 do
				buffer.copy(stage, r * rw * 4, tex, ((y0 + r) * W + x0) * 4, rw * 4)
			end
			m.img:WritePixelsBuffer(Vector2.new(x0, y0), Vector2.new(rw, CS), stage)
		end
	end
	for _, key in self.colDue do
		local e = m.ground[key]
		task.spawn(HM.bakeCollision, e.em, e.part)
	end
end

return ST
