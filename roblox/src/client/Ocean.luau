--!nonstrict
-- Ocean: the sea the growing landmass rises out of (owner 2026-10-07: "the outside filled with water and life").
--   * one big sea surface + a deep floor, sea level just under the grass so the island cliffs stand out of the water
--   * shallow reef shelf hugging every open coast (turquoise sand seen through the water), coral clusters, a foam line
--   * life: fish schools over the reefs, shark fins circling offshore, a whale that surfaces and spouts now and then,
--     glowing jellyfish at night
-- Everything is client-only scenery. Rebuild() follows the open coastline after every unlock; Step() animates only
-- what is near the camera. Bricks stay on the LEGO grid like the rest of the world.
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Models = require(Shared:WaitForChild("Models"))
local Map = require(Shared:WaitForChild("MapData"))
local World = require(Shared:WaitForChild("World"))

local Ocean = {}
local S = Models.S
local L = S / 2
local PLATE = 0.4 * L
local BRICK = 3 * PLATE
Ocean.SEA_Y = -PLATE - BRICK * 1.25   -- a bit more than one brick of cliff shows above the water
local SEA_Y = Ocean.SEA_Y
local COLS, ROWS = Map.COLS, Map.ROWS

local colCache = {}
local function hx(h) local c = colCache[h]; if not c then c = Color3.fromHex(h); colCache[h] = c end; return c end
local function hash(i, j) local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453; return n - math.floor(n) end
local function sx(i) return (i - COLS / 2) * S end
local function sz(j) return (j - ROWS / 2) * S end

local function part(parent, size, cf, col, mat, transp)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size; p.CFrame = cf; p.Color = col; p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = transp or 0
	p.Parent = parent
	return p
end

-- ellipsoid: a box part with a sphere mesh (Ball parts are always perfect spheres)
local function blob(parent, size, cf, col, transp)
	local p = part(parent, size, cf, col, nil, transp)
	local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = p
	return p
end

local root, shelfF, lifeF
local surface, deep
local splashPart
local schools, sharks, jellies, whale = {}, {}, {}, nil
local coastList = {}   -- { x, z } world studs of shallow-water tiles (for placing life)
local deepList = {}    -- open-water tiles 6+ tiles from land (sharks / whale)
local night = 0

-- ---------------------------------------------------------------- painted sea surface
local AssetService = game:GetService("AssetService")
local tintImg, foamImg, tintDecal, foamDecal, sheet
local glints, frame = {}, {}
local ripples, waveDecals, waveImgs = {}, {}, {}
local B = nil   -- painted rectangle in tiles
local PX = 2    -- pixels per tile
local FAR = { 27, 112, 177 }   -- deep-sea colour (the gradient at distance 8), shared by the painted and far sea
local FARV = Vector3.new(FAR[1] / 255, FAR[2] / 255, FAR[3] / 255)
local function newImage(w, h)
	local ok, img = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) }) end)
	if ok and img then return img end
	warn("[Ocean] EditableImage: " .. tostring(img))
	return nil
end
local function buildSurface(parent)
	glints, frame = {}, {}
	local i0, j0, i1, j1 = math.huge, math.huge, -math.huge, -math.huge
	for _, isl in World.all() do
		i0 = math.min(i0, isl.oi); j0 = math.min(j0, isl.oj)
		i1 = math.max(i1, isl.oi + isl.W); j1 = math.max(j1, isl.oj + isl.N)
	end
	i0 -= 24; j0 -= 24; i1 += 24; j1 += 24
	PX = math.clamp(math.floor(1024 / math.max(i1 - i0, j1 - j0)), 1, 4)
	B = { i0 = i0, j0 = j0, w = i1 - i0, h = j1 - j0 }
	local W, H = B.w * S, B.h * S
	local cx, cz = sx(i0) + W / 2, sz(j0) + H / 2
	-- the surface itself is Terrain water: real waves, sun glints and a waterline where it meets the cliffs. It is
	-- kept nearly clear, so the painted colour layer just under it (the guide's gradient + foam) gives the colour.
	local T = workspace.Terrain
	local TOP = math.floor(SEA_Y / 4 + 0.5) * 4
	T.WaterColor = hx("1b70b1"); T.WaterTransparency = 0.75; T.WaterReflectance = 0.28
	T.WaterWaveSize = 0.04; T.WaterWaveSpeed = 6
	task.spawn(function()
		local TILE = 512
		for x = -2048, 2048 - TILE, TILE do
			for z = -2048, 2048 - TILE, TILE do
				local r = Region3.new(Vector3.new(x, TOP - 4, z), Vector3.new(x + TILE, TOP, z + TILE)):ExpandToGrid(4)
				T:ReplaceMaterial(r, 4, Enum.Material.Air, Enum.Material.Water)   -- only empty voxels: land columns stay
				task.wait()
			end
		end
	end)
	sheet = part(parent, Vector3.new(W, 0.2, H), CFrame.new(cx, TOP + 0.02, cz), Color3.new(1, 1, 1), nil, 1)
	sheet.Name = "Sea"
	tintImg = newImage(B.w * PX, B.h * PX)
	foamImg = newImage(B.w * PX, B.h * PX)
	if tintImg then
		tintDecal = Instance.new("Decal"); tintDecal.Face = Enum.NormalId.Top; tintDecal.ZIndex = 1
		tintDecal.ColorMapContent = Content.fromObject(tintImg); tintDecal.Parent = sheet
	end
	if foamImg then
		foamDecal = Instance.new("Decal"); foamDecal.Face = Enum.NormalId.Top; foamDecal.ZIndex = 3
		foamDecal.ColorMapContent = Content.fromObject(foamImg); foamDecal.Parent = sheet
	end
	-- Pokemon-style water: (1) a ripple sheet over the whole sea with painted wavy strokes drifting two ways, visible
	-- at any zoom (far Terrain water renders flat); (2) three shore-wave bands that light up outermost first, so waves
	-- read as rolling in to the beach (painted in paint())
	do
		local RW = 128
		local rip = newImage(RW, RW)
		if rip then
			local rb = buffer.create(RW * RW * 4)
			for y = 0, RW - 1 do
				for x = 0, RW - 1 do
					-- three wavy stroke rows per tile, broken into dashes so it reads as ripples, not stripes
					local a = 0
					for k = 0, 2 do
						local cy = (k + 0.5) * RW / 3 + math.sin(x / RW * math.pi * 2 * 2 + k * 2.1) * 5
						local d = math.abs(y - cy)
						local dash = math.sin(x / RW * math.pi * 2 * (3 + k) + k) > -0.2
						if d < 1.6 and dash then a = math.max(a, 1 - d / 1.6) end
					end
					local o = (y * RW + x) * 4
					buffer.writeu8(rb, o, 255); buffer.writeu8(rb, o + 1, 255); buffer.writeu8(rb, o + 2, 255); buffer.writeu8(rb, o + 3, a * 150)
				end
			end
			rip:WritePixelsBuffer(Vector2.zero, Vector2.new(RW, RW), rb)
			local rs = part(parent, Vector3.new(6000, 0.2, 6000), CFrame.new(cx, TOP + 0.06, cz), Color3.new(1, 1, 1), nil, 1)
			rs.Name = "Ripples"
			for _, st in { 46, 71 } do
				local t = Instance.new("Texture"); t.Face = Enum.NormalId.Top; t.StudsPerTileU = st; t.StudsPerTileV = st * 0.8
				t.ColorMapContent = Content.fromObject(rip); t.Transparency = 0.35; t.Parent = rs
				table.insert(ripples, t)
			end
		end
		for k = 1, 3 do
			local img = newImage(B.w * PX, B.h * PX)
			if img then
				local dcl = Instance.new("Decal"); dcl.Face = Enum.NormalId.Top; dcl.ZIndex = 4; dcl.Transparency = 1
				dcl.ColorMapContent = Content.fromObject(img); dcl.Parent = sheet
				waveImgs[k], waveDecals[k] = img, dcl
			end
		end
	end
	-- sparkle: a tiling 64px image of white flecks, two layers at different scales drifting apart
	local gl = newImage(64, 64)
	if gl then
		local buf = buffer.create(64 * 64 * 4)
		for y = 0, 63 do
			for x = 0, 63 do
				local v = hash(x * 1.7 + 3, y * 2.3 + 1)
				local a = if v > 0.994 then 170 elseif v > 0.985 then 70 else 0
				local o = (y * 64 + x) * 4
				buffer.writeu8(buf, o, 255); buffer.writeu8(buf, o + 1, 255); buffer.writeu8(buf, o + 2, 255); buffer.writeu8(buf, o + 3, a)
			end
		end
		gl:WritePixelsBuffer(Vector2.zero, Vector2.new(64, 64), buf)
		for _, st in { 22, 37 } do
			local t = Instance.new("Texture"); t.Face = Enum.NormalId.Top; t.ZIndex = 2; t.StudsPerTileU = st; t.StudsPerTileV = st
			t.ColorMapContent = Content.fromObject(gl); t.Transparency = 0.55; t.Parent = sheet
			table.insert(glints, t)
		end
	end
	-- deep-blue frame to the horizon around the painted rectangle
	local R = 3000
	-- the far sea is painted the same way (a flat deep-colour image on invisible parts) so it matches the
	-- painted rectangle exactly and never catches a specular sun glare
	local farImg = newImage(4, 4)
	if farImg then
		local fbuf = buffer.create(64)
		for q = 0, 15 do buffer.writeu8(fbuf, q * 4, FAR[1]); buffer.writeu8(fbuf, q * 4 + 1, FAR[2]); buffer.writeu8(fbuf, q * 4 + 2, FAR[3]); buffer.writeu8(fbuf, q * 4 + 3, 255) end
		farImg:WritePixelsBuffer(Vector2.zero, Vector2.new(4, 4), fbuf)
	end
	-- one floor under the whole sea, painted the deep colour: outside the rectangle you see it at full colour,
	-- inside, the painted deep water (same colour, opaque) covers it, so there is no seam to catch the light
	local fp = part(parent, Vector3.new(2 * R, 0.2, 2 * R), CFrame.new(cx, SEA_Y - 7.6, cz), hx("1b70b1"))   -- under the deepest reef step
	fp.Name = "SeaFar"
	if farImg then
		fp.Transparency = 1
		local fd = Instance.new("Decal"); fd.Face = Enum.NormalId.Top; fd.ZIndex = 1; fd.ColorMapContent = Content.fromObject(farImg); fd.Parent = fp
		table.insert(frame, fd)
	end
	if gl then
		for _, st in { 22, 37 } do
			local t = Instance.new("Texture"); t.Face = Enum.NormalId.Top; t.StudsPerTileU = st; t.StudsPerTileV = st
			t.ColorMapContent = Content.fromObject(gl); t.Transparency = 0.25; t.Parent = fp
			table.insert(glints, t)
		end
	end
end

-- repaint tint + foam from the tile distance to open land (bilinear between tile centres, so contours are smooth)
local function lerp1(a, b, t) return a + (b - a) * t end
local function smooth(e0, e1, x) local t = math.clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t) end
local DEEP, MID, SHAL = Vector3.new(0.10, 0.42, 0.68), Vector3.new(0.16, 0.60, 0.80), Vector3.new(0.36, 0.86, 0.86)
local paintGen = 0
local function paint(distOf)
	if not tintImg or not B then return end
	paintGen += 1
	local gen = paintGen
	local w, h = B.w, B.h
	local g = table.create((w + 1) * (h + 1), 8)
	for j = 0, h do
		for i = 0, w do
			local d = distOf(B.i0 + i, B.j0 + j)
			g[j * (w + 1) + i + 1] = if d then math.min(8, d) else 8
		end
	end
	local PW, PH = w * PX, h * PX
	local tb, fb = buffer.create(PW * PH * 4), buffer.create(PW * PH * 4)
	local wb = { buffer.create(PW * PH * 4), buffer.create(PW * PH * 4), buffer.create(PW * PH * 4) }
	local WAVE_D = { 3.6, 2.6, 1.7 }   -- wave line distance from shore (tiles), outermost first
	for py = 0, PH - 1 do
		local fy = (py + 0.5) / PX - 0.5
		local j = math.clamp(math.floor(fy), 0, h - 1); local ty = math.clamp(fy - j, 0, 1)
		for px = 0, PW - 1 do
			local fx = (px + 0.5) / PX - 0.5
			local i = math.clamp(math.floor(fx), 0, w - 1); local tx = math.clamp(fx - i, 0, 1)
			local r0 = j * (w + 1) + i + 1
			local d = lerp1(lerp1(g[r0], g[r0 + 1], tx), lerp1(g[r0 + w + 1], g[r0 + w + 2], tx), ty)
			local shallow = 1 - smooth(0.6, 6.5, d)
			local c = DEEP:Lerp(MID, smooth(9, 4, d)):Lerp(SHAL, shallow * shallow)
			local n = hash(px * 0.37, py * 0.53)
			c += Vector3.one * ((n - 0.5) * 0.025 * (1 - smooth(6, 7.5, d)))
			if d >= 7.5 then c = FARV end   -- open water: exactly the far-sea colour, so the painted edge never shows
			local a = if d < 0.5 then 0 elseif d > 7.5 then 0.8 else lerp1(0.8, 0.42, shallow)
			local o = (py * PW + (PW - 1 - px)) * 4   -- Top-face decals run U along -X
			buffer.writeu8(tb, o, math.clamp(c.X * 255, 0, 255)); buffer.writeu8(tb, o + 1, math.clamp(c.Y * 255, 0, 255))
			buffer.writeu8(tb, o + 2, math.clamp(c.Z * 255, 0, 255)); buffer.writeu8(tb, o + 3, a * 255)
			-- foam: soft band hugging the coast with ripples running in, plus rare flecks further out
			local band = smooth(1.8, 0.9, d) * smooth(0.35, 0.75, d)
			local f = band * (0.6 + 0.4 * math.sin(d * 7 + n * 1.5))
			if d > 1.2 and d < 4 and n > 0.985 then f = math.max(f, 0.5) end
			buffer.writeu8(fb, o, 255); buffer.writeu8(fb, o + 1, 255); buffer.writeu8(fb, o + 2, 255); buffer.writeu8(fb, o + 3, math.clamp(f, 0, 1) * 235)
			for k = 1, 3 do   -- thin wavy wave crest following the coast at WAVE_D[k], broken where noise is low
				local wd = WAVE_D[k] + math.sin(px * 0.05 + py * 0.035 + k) * 0.18
				local wa = math.max(0, 1 - math.abs(d - wd) / 0.22) * (if n > 0.18 then 1 else 0.3)
				local ow = o
				buffer.writeu8(wb[k], ow, 255); buffer.writeu8(wb[k], ow + 1, 255); buffer.writeu8(wb[k], ow + 2, 255); buffer.writeu8(wb[k], ow + 3, wa * 220)
			end
		end
		if py % 64 == 63 then task.wait(); if gen ~= paintGen then return end end   -- a newer coastline superseded this one
	end
	tintImg:WritePixelsBuffer(Vector2.zero, Vector2.new(PW, PH), tb)
	if foamImg then foamImg:WritePixelsBuffer(Vector2.zero, Vector2.new(PW, PH), fb) end
	for k = 1, 3 do if waveImgs[k] then waveImgs[k]:WritePixelsBuffer(Vector2.zero, Vector2.new(PW, PH), wb[k]) end end
end

-- ---------------------------------------------------------------- static sea
function Ocean.build(parent)
	if root then root:Destroy() end
	root = Instance.new("Folder"); root.Name = "Ocean"; root.Parent = parent or workspace
	-- the sea (World Guide look): one surface over the whole map with three painted layers
	--   tint  = colour + alpha from the distance to open land (turquoise and clear over the reef -> deep blue), smooth
	--   foam  = the soft band along the coast, its transparency breathes
	--   glint = small tiling sparkle textures drifting two ways (only two offsets change per frame)
	-- outside the painted rectangle four deep-blue frame parts carry the sea to the horizon
	buildSurface(root)
	deep = part(root, Vector3.new(6000, 1, 6000), CFrame.new(0, SEA_Y - 14.5, 0), hx("0f3c66"))
	shelfF = Instance.new("Folder"); shelfF.Name = "Shelf"; shelfF.Parent = root
	lifeF = Instance.new("Folder"); lifeF.Name = "Life"; lifeF.Parent = root
	local Lighting = game:GetService("Lighting")
	if not Lighting:FindFirstChild("SeaRays") then
		local sr = Instance.new("SunRaysEffect"); sr.Name = "SeaRays"; sr.Intensity = 0.03; sr.Spread = 0.4; sr.Parent = Lighting
	end
	-- splash emitter (terraform + whale)
	splashPart = part(root, Vector3.new(4, 0.2, 4), CFrame.new(0, SEA_Y, 0), Color3.new(1, 1, 1), nil, 1)
	splashPart.Name = "Splash"
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Spray"; pe.Texture = "rbxasset://textures/particles/smoke_main.dds"; pe.Color = ColorSequence.new(hx("e8f8ff"))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.5, 0.9); pe.Rate = 0; pe.Speed = NumberRange.new(6, 11); pe.SpreadAngle = Vector2.new(35, 35)
	pe.Acceleration = Vector3.new(0, -30, 0); pe.EmissionDirection = Enum.NormalId.Top; pe.Drag = 1.5; pe.Parent = splashPart
	return root
end
function Ocean.splash(pos: Vector3, n: number?)
	if not splashPart then return end
	splashPart.CFrame = CFrame.new(pos.X, SEA_Y + 0.2, pos.Z)
	splashPart.Spray:Emit(n or 8)
end

-- ---------------------------------------------------------------- coast shelf (follows the open coastline)
local function openLand(i, j)
	local c = World.tile(i, j)
	return c ~= 0   -- inland ponds belong to the land (painting them as sea put a white foam square on them)
end
local CORAL = { "ff7a8a", "ffb14a", "b98cff", "ff5fb0", "5fe0c8", "ffe066" }
function Ocean.rebuild()
	if not shelfF then return end
	shelfF:ClearAllChildren()
	for _, f in lifeF:GetChildren() do f:Destroy() end
	schools, sharks, jellies, whale = {}, {}, {}, nil
	coastList, deepList = {}, {}
	-- bounds of the open land, + margin
	local mnI, mnJ, mxI, mxJ = math.huge, math.huge, -math.huge, -math.huge
	for _, isl in World.all() do
		if World.isOpen(isl) then
			mnI = math.min(mnI, isl.oi); mnJ = math.min(mnJ, isl.oj)
			mxI = math.max(mxI, isl.oi + isl.W); mxJ = math.max(mxJ, isl.oj + isl.N)
		end
	end
	if mnI == math.huge then return end
	local M = 12
	mnI -= M; mnJ -= M; mxI += M; mxJ += M
	-- BFS distance from open land over the sea, up to 10 tiles
	local dist = {}
	local q, head = {}, 1
	local function k(i, j) return (j + 500) * 2000 + i + 500 end
	for j = mnJ, mxJ do
		for i = mnI, mxI do
			if openLand(i, j) then dist[k(i, j)] = 0; table.insert(q, { i, j }) end
		end
	end
	while head <= #q do
		local c = q[head]; head += 1
		local d0 = dist[k(c[1], c[2])]
		if d0 >= 10 then continue end
		for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = c[1] + o[1], c[2] + o[2]
			if ni < mnI or ni > mxI or nj < mnJ or nj > mxJ then continue end
			if dist[k(ni, nj)] == nil then dist[k(ni, nj)] = d0 + 1; table.insert(q, { ni, nj }) end
		end
	end
	task.spawn(paint, function(i, j) return dist[k(i, j)] end)
	-- shelf plates: depth steps down with distance (d 1..3 shallow sand, 4..5 reef edge); runs merged per row
	local function level(d) return if d <= 1 then 1 elseif d <= 3 then 2 elseif d <= 5 then 3 else 0 end
	local LEVEL_Y = { SEA_Y - 1.2, SEA_Y - 2.6, SEA_Y - 4.6 }
	local LEVEL_C = { "f1e2b4", "e2d29e", "6fb3a8" }
	for j = mnJ, mxJ do
		local runStart, runLv = nil, 0
		for i = mnI, mxI + 1 do
			local d = dist[k(i, j)]
			local lv = if d and d > 0 and i <= mxI then level(d) else 0
			if lv ~= runLv then
				if runStart and runLv > 0 then
					local w = (i - runStart) * S
					local x0 = sx(runStart)
					part(shelfF, Vector3.new(w, BRICK, S), CFrame.new(x0 + w / 2, LEVEL_Y[runLv] - BRICK / 2, sz(j) + S / 2), hx(LEVEL_C[runLv]))
				end
				runStart, runLv = i, lv
			end
		end
	end
	-- coral on the reef edge + lists for life
	for j = mnJ, mxJ do
		for i = mnI, mxI do
			local d = dist[k(i, j)]
			if not d or d == 0 then continue end
			local x, z = sx(i) + S / 2, sz(j) + S / 2
			if d >= 2 and d <= 5 then table.insert(coastList, Vector3.new(x, 0, z)) end
			if d >= 8 then table.insert(deepList, Vector3.new(x, 0, z)) end
			if d >= 2 and d <= 4 and hash(i, j) < 0.1 then
				local lv = level(d)
				local base = LEVEL_Y[lv]
				local m = Instance.new("Model"); m.Name = "Coral"
				local col = hx(CORAL[math.floor(hash(i + 3, j) * #CORAL) + 1])
				local col2 = hx(CORAL[math.floor(hash(i, j + 5) * #CORAL) + 1])
				local hgt = 0.8 + hash(i, j + 1) * 1.4
				local stem = part(m, Vector3.new(hgt, 0.5, 0.5), CFrame.new(x, base + hgt / 2, z) * CFrame.Angles(0, 0, math.pi / 2), col)
				stem.Shape = Enum.PartType.Cylinder
				part(m, Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, base + hgt, z), col).Shape = Enum.PartType.Ball
				part(m, Vector3.new(0.6, 0.6, 0.6), CFrame.new(x + 0.7, base + hgt * 0.6, z + 0.3), col2).Shape = Enum.PartType.Ball
				part(m, Vector3.new(L * 0.5, PLATE, L * 0.5), CFrame.new(x - 0.6, base + PLATE / 2, z - 0.5), col2)
				m.Parent = shelfF
			end
		end
	end
	Ocean.spawnLife()
end

-- ---------------------------------------------------------------- life
local FISH_COLS = { "ffb43a", "ff6f5a", "5fd0ff", "ffe066", "b98cff", "7dff9a" }
local function rnd(list, s) if #list == 0 then return nil end; return list[math.floor(hash(s, #list) * #list) + 1] end
function Ocean.spawnLife()
	-- fish schools over the reefs
	for n = 1, math.min(10, math.floor(#coastList / 60) + 3) do
		local c = rnd(coastList, n * 7.3)
		if not c then break end
		local col = hx(FISH_COLS[(n - 1) % #FISH_COLS + 1])
		local sch = { c = c, r = 3 + hash(n, 2) * 5, sp = (0.5 + hash(n, 3) * 0.5) * (if n % 2 == 0 then 1 else -1), a = hash(n, 4) * 6.28, fish = {} }
		for f = 1, 6 + n % 4 do
			local m = Instance.new("Model"); m.Name = "Fish"
			local body = part(m, Vector3.new(0.35, 0.3, 0.8), CFrame.new(), col)
			local tail = part(m, Vector3.new(0.1, 0.35, 0.3), CFrame.new(0, 0, 0.5), col:Lerp(Color3.new(0, 0, 0), 0.2))
			m.PrimaryPart = body; m.Parent = lifeF
			table.insert(sch.fish, { m = m, o = Vector3.new((hash(n, f) - 0.5) * 2.2, -0.4 - hash(f, n) * 0.9, (hash(f, n + 9) - 0.5) * 2.2), ph = hash(n + f, 1) * 6.28 })
			_ = tail
		end
		table.insert(schools, sch)
	end
	-- shark fins circling offshore
	for n = 1, math.min(3, math.floor(#deepList / 200) + 1) do
		local c = rnd(deepList, n * 13.1)
		if not c then break end
		local m = Instance.new("Model"); m.Name = "Shark"
		local fin = Instance.new("WedgePart")
		fin.Anchored = true; fin.CanCollide = false; fin.CanQuery = false; fin.CanTouch = false; fin.CastShadow = false
		fin.Size = Vector3.new(0.25, 1.4, 1.4); fin.Color = hx("4a5866"); fin.Material = Enum.Material.SmoothPlastic; fin.Parent = m
		local wake = part(m, Vector3.new(1.4, 0.12, 2.6), CFrame.new(), hx("ffffff"), nil, 0.6)
		m.PrimaryPart = fin; m.Parent = lifeF
		table.insert(sharks, { m = m, fin = fin, wake = wake, c = c, r = 10 + hash(n, 5) * 10, sp = 0.18 + hash(n, 6) * 0.1, a = hash(n, 7) * 6.28 })
	end
	-- the whale (one, offshore)
	local wc = rnd(deepList, 99.1)
	if wc then
		local m = Instance.new("Model"); m.Name = "Whale"
		local body = blob(m, Vector3.new(11, 4.2, 4.6), CFrame.new(), hx("3c5f86"))
		blob(m, Vector3.new(9, 2.2, 3.8), CFrame.new(0, -1.2, 0), hx("c9d8e6"))
		local tail = part(m, Vector3.new(1, 0.4, 4.5), CFrame.new(-6.2, 0.4, 0), hx("34557a"))
		local eye = part(m, Vector3.new(0.4, 0.4, 0.4), CFrame.new(3.6, 0.4, 1.9), hx("10141a")); eye.Shape = Enum.PartType.Ball
		m.PrimaryPart = body; m.Parent = lifeF
		local spout = Instance.new("ParticleEmitter")
		spout.Texture = "rbxasset://textures/particles/smoke_main.dds"; spout.Color = ColorSequence.new(hx("f2fbff"))
		spout.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
		spout.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		spout.Lifetime = NumberRange.new(0.8, 1.2); spout.Rate = 0; spout.Speed = NumberRange.new(10, 14); spout.SpreadAngle = Vector2.new(10, 10)
		spout.Acceleration = Vector3.new(0, -12, 0); spout.EmissionDirection = Enum.NormalId.Top
		local at = Instance.new("Attachment"); at.Position = Vector3.new(2.5, 2, 0); at.Parent = body; spout.Parent = at
		whale = { m = m, spout = spout, c = wc, t = hash(3, 3) * 20, period = 38, dir = hash(4, 4) * 6.28 }
		_ = tail
	end
	-- jellyfish (glow at night)
	for n = 1, math.min(8, #coastList // 40) do
		local c = rnd(coastList, n * 3.7 + 50)
		if not c then break end
		local j = blob(lifeF, Vector3.new(0.9, 0.6, 0.9), CFrame.new(c.X, SEA_Y - 0.6, c.Z), hx("ff8fd0"), 0.35)
		j.Name = "Jelly"
		table.insert(jellies, { p = j, c = c, ph = hash(n, 8) * 6.28 })
	end
end

-- ---------------------------------------------------------------- animation (near the camera only)
local function near(p: Vector3, focus: Vector3, r: number) return math.abs(p.X - focus.X) < r and math.abs(p.Z - focus.Z) < r end
function Ocean.setNight(n: number)
	night = n
	if tintDecal then tintDecal.Color3 = Color3.new(1, 1, 1):Lerp(hx("3a5d8a"), n) end
	if foamDecal then foamDecal.Color3 = Color3.new(1, 1, 1):Lerp(hx("7f93b0"), n) end
	for _, g in glints do g.Transparency = 0.55 + 0.42 * n end
	workspace.Terrain.WaterColor = hx("1b70b1"):Lerp(hx("12305a"), n)
	workspace.Terrain.WaterReflectance = 0.28 * (1 - n) + 0.04 * n   -- no grey sky blotches at night
	for _, f in frame do f.Color3 = Color3.new(1, 1, 1):Lerp(hx("3a5d8a"), n) end
	for _, j in jellies do j.p.Material = if n > 0.4 then Enum.Material.Neon else Enum.Material.SmoothPlastic; j.p.Transparency = 0.35 - 0.15 * n end
end
local clock = 0
function Ocean.step(dt: number)
	if not root then return end
	clock += dt
	local focus = workspace.CurrentCamera.Focus.Position
	local R = 140
	for _, sch in schools do
		if not near(sch.c, focus, R) then continue end
		sch.a += sch.sp * dt
		local ctr = sch.c + Vector3.new(math.cos(sch.a) * sch.r, 0, math.sin(sch.a) * sch.r)
		local fwd = Vector3.new(-math.sin(sch.a), 0, math.cos(sch.a)) * (if sch.sp > 0 then 1 else -1)
		for _, f in sch.fish do
			local p = ctr + f.o + Vector3.new(0, SEA_Y + math.sin(clock * 2 + f.ph) * 0.15, 0)
			f.m:PivotTo(CFrame.lookAt(p, p - fwd) * CFrame.Angles(0, math.sin(clock * 9 + f.ph) * 0.25, 0))
		end
	end
	for _, sh in sharks do
		if not near(sh.c, focus, R + 40) then continue end
		sh.a += sh.sp * dt
		local p = sh.c + Vector3.new(math.cos(sh.a) * sh.r, SEA_Y + 0.55, math.sin(sh.a) * sh.r)
		local fwd = Vector3.new(-math.sin(sh.a), 0, math.cos(sh.a))
		local cf = CFrame.lookAt(p, p + fwd)
		sh.fin.CFrame = cf * CFrame.Angles(0, math.pi, 0)
		sh.wake.CFrame = cf * CFrame.new(0, -0.5, 1.2)
	end
	if whale then
		whale.t += dt
		local k = (whale.t % whale.period) / whale.period   -- 0..1 cycle: under, surface, spout, dive
		local rise = if k < 0.7 then 0 elseif k < 0.78 then (k - 0.7) / 0.08 elseif k < 0.92 then 1 else 1 - (k - 0.92) / 0.08
		rise = rise * rise * (3 - 2 * rise)
		local drift = Vector3.new(math.cos(whale.dir), 0, math.sin(whale.dir)) * (k * 14)
		local p = whale.c + drift + Vector3.new(0, SEA_Y - 5 + rise * 4.4, 0)
		whale.m:PivotTo(CFrame.new(p) * CFrame.Angles(0, -whale.dir, (rise - 0.5) * 0.12))
		if k > 0.8 and k < 0.84 and not whale.spouted then whale.spouted = true; whale.spout:Emit(28); Ocean.splash(p, 6) end
		if k < 0.5 then whale.spouted = false end
	end
	for _, j in jellies do
		if not near(j.c, focus, R) then continue end
		j.p.CFrame = CFrame.new(j.c.X + math.sin(clock * 0.3 + j.ph) * 2, SEA_Y - 0.7 + math.sin(clock * 1.2 + j.ph) * 0.25, j.c.Z + math.cos(clock * 0.25 + j.ph) * 2)
	end
	-- the ripple sheet sits under the land; from far away (whole-island zoom) it bleeds through the grass as white
	-- streaks, so it fades out with camera distance (close: full, >= 420 studs: gone; shore waves + foam carry it)
	local camDist = (workspace.CurrentCamera.CFrame.Position - focus).Magnitude
	local ripFade = math.clamp((camDist - 300) / 120, 0, 1)
	for kk, r in ripples do
		r.OffsetStudsU = clock * (if kk == 1 then 1.3 else -0.9)
		r.OffsetStudsV = clock * (if kk == 1 then 0.6 else 1.1)
		r.Transparency = 0.35 + 0.65 * ripFade
	end
	-- shore waves: a set every 4.5 s, outermost line first, each brightening then fading as the next takes over
	local cyc = (clock / 4.5) % 1
	for k, dcl in waveDecals do
		local ph = (cyc - (k - 1) * 0.22) % 1
		local a = if ph < 0.35 then math.sin(ph / 0.35 * math.pi) else 0
		dcl.Transparency = 1 - a * 0.85 * (1 - night * 0.6)
	end
	for kk, g in glints do
		g.OffsetStudsU = clock * (if kk == 1 then 1.6 else -1.1)
		g.OffsetStudsV = clock * (if kk == 1 then 1.1 else 1.4)
	end
	-- foam breathes
	if shelfF and math.floor(clock * 4) ~= math.floor((clock - dt) * 4) then
		if foamDecal then foamDecal.Transparency = 0.12 + (0.5 + 0.5 * math.sin(clock * 1.6)) * 0.45 end
	end
end

return Ocean
