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
-- AAA plan (target B, 2026-10-09): each island is a raised diorama plate: the sea sits CLIFF studs below the grass, so
-- a rock cliff skirt shows between the grass lip and a rounded sand beach at the waterline
Ocean.CLIFF = 9   -- owner 2026-10-09: 16 was too high
Ocean.SEA_Y = -PLATE - BRICK * 1.25 - Ocean.CLIFF
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
	PX = math.clamp(math.floor(1024 / math.max(i1 - i0, j1 - j0)), 1, 6)
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
	end
	-- sparkle: a tiling 64px image of white flecks, two layers at different scales drifting apart
	local gl = newImage(64, 64)
	if gl then
		local buf = buffer.create(64 * 64 * 4)
		for y = 0, 63 do
			for x = 0, 63 do
				local v = hash(x * 1.7 + 3, y * 2.3 + 1)
				local a = if v > 0.997 then 190 elseif v > 0.993 then 60 else 0
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
local function C3(h) local c = hx(h); return Vector3.new(c.R, c.G, c.B) end
-- water hierarchy (owner 2026-10-09: "water also has to get a hierarchy look ... the water is now slacking"): clear toon
-- depth TIERS instead of one soft gradient, like a handheld-RPG sea: crisp white foam at the beach, bright aqua lagoon,
-- cyan reef shelf, mid blue, deep blue (= the far sea). Each step has a wobbly organic edge and a thin light rim on
-- its shallow side (the drop-off line), and each tier shades a little towards the next so it is not flat.
local DMAX = 12                                   -- distances are capped here (tiles); beyond the last step = deep
local TIERS = {                                   -- { outer edge (tiles from the coast), colour, alpha }
	{ 4.2, C3("8af2e2"), 0.66 },                  -- lagoon (the beach sand shows through a little)
	{ 6.4, C3("3fd4e8"), 0.76 },                  -- reef shelf
	{ 9.2, C3("2a9fe0"), 0.80 },                  -- mid
}
local RIM = C3("c8fff6")
local paintGen = 0
-- rolling waves (owner 2026-10-09: "water needs to animate"): white crest lines that roll in to the beach and fade
-- into the foam, like a handheld-RPG shore. Two crest FRONTS, each ONE ribbon mesh along every coast loop (offset
-- along a heavily smoothed outward normal so bays don't fold), dashed by low-frequency noise so each crest keeps its
-- gaps as it travels. Every frame the visible fronts slide their vertices inward (EditableMesh budget: 2 meshes,
-- ~700 vertex moves per frame) and fade; the painted foam surges as a crest lands.
local function skirtLand(i, j) local c = World.tile(i, j); return c ~= 0 and c ~= 5 end
local WAVE_FROM, WAVE_TO = 7.4, 2.5   -- tiles from the coast contour
local waveF, fronts = nil, {}
local AssetServiceW = game:GetService("AssetService")
local function buildWaveFronts(loops)
	if waveF then waveF:Destroy(); waveF = nil end
	fronts = {}
	local TOPW = math.floor(SEA_Y / 4 + 0.5) * 4 + 0.14
	local function landAtW(p: Vector2) return skirtLand(math.floor((p.X - sx(0)) / S), math.floor((p.Y - sz(0)) / S)) end
	local rails = {}
	for _, loop in loops do
		local m0 = #loop
		if m0 < 12 then continue end
		local pts = {}
		for q = 1, m0, 2 do table.insert(pts, loop[q]) end
		local m = #pts
		local raw = table.create(m)
		local landSide = 0
		for q = 1, m do
			local tg = pts[q % m + 1] - pts[(q - 2) % m + 1]
			tg = if tg.Magnitude > 0 then tg.Unit else Vector2.new(1, 0)
			raw[q] = Vector2.new(tg.Y, -tg.X)
			if landAtW(pts[q] + raw[q] * 2.5) then landSide += 1 end
		end
		local sgn = if landSide > m / 2 then -1 else 1
		-- the crest path is the coast with its corners ironed out (two passes of a wide moving average), so the
		-- offset lines are round swells, not copies of the cliff's facets
		local base = pts
		for _ = 1, 2 do
			local sm = table.create(m)
			for q = 1, m do
				local sum = Vector2.zero
				for k = -6, 6 do sum += base[(q - 1 + k) % m + 1] end
				sm[q] = sum / 13
			end
			base = sm
		end
		local rail = table.create(m)
		for q = 1, m do
			local sum = Vector2.zero
			for k = -7, 7 do sum += raw[(q - 1 + k) % m + 1] end
			local nv = (if sum.Magnitude > 0 then sum.Unit else raw[q]) * sgn
			local p = base[q]
			local on = math.clamp((math.noise(p.X * 0.045, p.Y * 0.045, 11.3) + 0.02) / 0.16, 0, 1)
			rail[q] = { base = p, n = nv, hw = 0.4 * on * (0.8 + 0.4 * hash(q, 2.7)) }
		end
		table.insert(rails, rail)
	end
	if #rails == 0 then return end
	waveF = Instance.new("Folder"); waveF.Name = "Waves"; waveF.Parent = root
	for f = 1, 2 do
		local ok, em = pcall(function() return AssetServiceW:CreateEditableMesh({}) end)
		if not ok or not em then warn("[Ocean] wave mesh: " .. tostring(em)); break end
		local up = em:AddNormal(Vector3.yAxis)
		local verts = {}
		for _, rail in rails do
			local m = #rail
			local ids = table.create(m)
			for q = 1, m do
				local r = rail[q]
				local p = r.base + r.n * (WAVE_FROM * S)
				local a = em:AddVertex(Vector3.new(p.X - r.n.X * r.hw, 0, p.Y - r.n.Y * r.hw))
				local b = em:AddVertex(Vector3.new(p.X + r.n.X * r.hw, 0, p.Y + r.n.Y * r.hw))
				ids[q] = { a, b }
				table.insert(verts, { a = a, b = b, r = r })
			end
			for q = 1, m do
				local q2 = q % m + 1
				if rail[q].hw <= 0 and rail[q2].hw <= 0 then continue end
				local A, B, C, D = ids[q][1], ids[q][2], ids[q2][2], ids[q2][1]
				local pa, pb, pc = em:GetPosition(A), em:GetPosition(B), em:GetPosition(C)
				local faceUp = (pb - pa):Cross(pc - pa).Y >= 0
				local f1 = if faceUp then em:AddTriangle(A, B, C) else em:AddTriangle(A, C, B)
				local f2 = if faceUp then em:AddTriangle(A, C, D) else em:AddTriangle(A, D, C)
				em:SetFaceNormals(f1, { up, up, up }); em:SetFaceNormals(f2, { up, up, up })
			end
		end
		local okP, mp = pcall(function() return AssetServiceW:CreateMeshPartAsync(Content.fromObject(em)) end)
		if okP and mp then
			mp.Name = "WaveFront"
			mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false; mp.CastShadow = false
			mp.Material = Enum.Material.SmoothPlastic; mp.Color = hx("f2fdff"); mp.Transparency = 1
			mp.CFrame = CFrame.new(0, TOPW, 0)   -- EditableMesh vertices keep their own origin
			mp.Parent = waveF
			table.insert(fronts, { em = em, part = mp, verts = verts, phase = (f - 1) * 0.5 })
		end
	end
end
local function paint(distOf)
	if not tintImg or not B then return end
	paintGen += 1
	local gen = paintGen
	local w, h = B.w, B.h
	local g = table.create((w + 1) * (h + 1), DMAX)
	for j = 0, h do
		for i = 0, w do
			local d = distOf(B.i0 + i, B.j0 + j)
			g[j * (w + 1) + i + 1] = if d then math.min(DMAX, d) else DMAX
		end
	end
	local PW, PH = w * PX, h * PX
	local tb, fb = buffer.create(PW * PH * 4), buffer.create(PW * PH * 4)
	-- d = distance (tiles) to the smooth coast contour; the cliff mesh's beach meets the water at ~2.2 tiles
	for py = 0, PH - 1 do
		local fy = (py + 0.5) / PX - 0.5
		local j = math.clamp(math.floor(fy), 0, h - 1); local ty = math.clamp(fy - j, 0, 1)
		local tj = B.j0 + fy
		for px = 0, PW - 1 do
			local fx = (px + 0.5) / PX - 0.5
			local i = math.clamp(math.floor(fx), 0, w - 1); local tx = math.clamp(fx - i, 0, 1)
			local r0 = j * (w + 1) + i + 1
			local d = lerp1(lerp1(g[r0], g[r0 + 1], tx), lerp1(g[r0 + w + 1], g[r0 + w + 2], tx), ty)
			local o = ((PH - 1 - py) * PW + (PW - 1 - px)) * 4   -- Top-face decal: image row 0 at +Z, column 0 at +X (tested)
			if d >= DMAX - 0.01 then   -- open water: exactly the far-sea colour, so the painted edge never shows
				buffer.writeu8(tb, o, FAR[1]); buffer.writeu8(tb, o + 1, FAR[2]); buffer.writeu8(tb, o + 2, FAR[3]); buffer.writeu8(tb, o + 3, 204)
				continue
			end
			local ti = B.i0 + fx
			-- organic step edges: low-frequency wobble + a little finer detail
			local dw = d + math.noise(ti * 0.3, tj * 0.3, 3.1) * 0.55 + math.noise(ti * 1.05, tj * 1.05, 7.7) * 0.14
			local c, a = FARV, 0.8
			local inner = 2.2
			for t = 1, #TIERS do
				local T = TIERS[t]
				if dw < T[1] + 0.1 then
					local nextC = if t < #TIERS then TIERS[t + 1][2] else FARV
					local nextA = if t < #TIERS then TIERS[t + 1][3] else 0.8
					local cc = T[2]:Lerp(nextC, smooth(inner, T[1], dw) * 0.28)
					cc = cc:Lerp(RIM, smooth(T[1] - 0.5, T[1] - 0.03, dw) * 0.22)   -- soft drop-off glow before the step
					local k = smooth(T[1] - 0.1, T[1] + 0.1, dw)                     -- anti-aliased step (~1 px)
					c = cc:Lerp(nextC, k); a = lerp1(T[3], nextA, k)
					break
				end
				inner = T[1]
			end
			if d < 2.0 then a = 0 end
			buffer.writeu8(tb, o, math.clamp(c.X * 255, 0, 255)); buffer.writeu8(tb, o + 1, math.clamp(c.Y * 255, 0, 255))
			buffer.writeu8(tb, o + 2, math.clamp(c.Z * 255, 0, 255)); buffer.writeu8(tb, o + 3, a * 255)
			-- foam: a crisp white line on the beach waterline + a broken wash line just outside it
			local fw = d + math.noise(ti * 0.6, tj * 0.6, 5.3) * 0.18
			local f = smooth(1.94, 2.12, fw) * (1 - smooth(2.46, 2.66, fw))
			local wash = math.max(0, 1 - math.abs(fw - 2.95) / 0.17) * smooth(-0.2, 0.05, math.noise(ti * 0.9, tj * 0.9, 2.2))
			f = math.max(f, wash * 0.75)
			buffer.writeu8(fb, o, 255); buffer.writeu8(fb, o + 1, 255); buffer.writeu8(fb, o + 2, 255); buffer.writeu8(fb, o + 3, math.clamp(f, 0, 1) * 245)
		end
		if py % 48 == 47 then task.wait(); if gen ~= paintGen then return end end   -- a newer coastline superseded this one
	end
	tintImg:WritePixelsBuffer(Vector2.zero, Vector2.new(PW, PH), tb)
	if foamImg then foamImg:WritePixelsBuffer(Vector2.zero, Vector2.new(PW, PH), fb) end
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
local BED = -40              -- matches LandTerrain's sea bed
local ringTiles, ringSig = {}, nil   -- beach / shelf tiles last written into Terrain

-- ---------------------------------------------------------------- cliff skirt (target B / handheld-RPG cliffs)
-- Terrain walls read as jagged voxel rock (owner: "disgusting"), so the coast gets a crisp handheld-RPG cliff built
-- from parts along a SMOOTH contour: marching squares over the land tiles -> closed loops -> Chaikin rounding, pushed
-- out a little so it always encloses the tile corners. Along the curve: chunky vertical rock slabs (varied width /
-- depth / height / shade), a darker wet-rock foot at the waterline and a thick grass lip on top; one ink outline.
local SKIRT_TOP = -0.3       -- grass lip top, flush with the visible turf (logic ground 0 renders at -0.5)
local SKIRT_IN = 3.2         -- how far the lip reaches back over the land (covers the stepped terrain edge)
local SKIRT_OUT = 1.6        -- contour offset out to sea, so the smoothed curve never cuts a land tile corner
local STEP = 1.6             -- studs between resampled contour points (mesh resolution along the coast)
local skirtF, skirtSig = nil, nil
-- closed coast loops in world studs (x, z as Vector2), smoothed
local function coastLoops(mnI, mnJ, mxI, mxJ)
	local function v(i, j) return if skirtLand(i, j) then 1 else 0 end
	-- tile-centre index space: point (ci, cj) -> world (sx(0) + (ci + 0.5) * S, sz(0) + (cj + 0.5) * S)
	local function W(p: Vector2) return Vector2.new(sx(0) + (p.X + 0.5) * S, sz(0) + (p.Y + 0.5) * S) end
	local segs = {}
	for j = mnJ - 1, mxJ do
		for i = mnI - 1, mxI do
			local a, b, c, d = v(i, j), v(i + 1, j), v(i + 1, j + 1), v(i, j + 1)
			local idx = a * 8 + b * 4 + c * 2 + d
			if idx == 0 or idx == 15 then continue end
			local T, R, B, Lf = Vector2.new(i + 0.5, j), Vector2.new(i + 1, j + 0.5), Vector2.new(i + 0.5, j + 1), Vector2.new(i, j + 0.5)
			local cross = {}
			if a ~= b then table.insert(cross, T) end
			if b ~= c then table.insert(cross, R) end
			if c ~= d then table.insert(cross, B) end
			if d ~= a then table.insert(cross, Lf) end
			if #cross == 2 then table.insert(segs, { W(cross[1]), W(cross[2]) })
			elseif #cross == 4 then   -- saddle: keep the land diagonal connected
				if a == 1 then table.insert(segs, { W(T), W(R) }); table.insert(segs, { W(B), W(Lf) })
				else table.insert(segs, { W(T), W(Lf) }); table.insert(segs, { W(R), W(B) }) end
			end
		end
	end
	-- chain segments into loops
	local function key(p: Vector2) return math.floor(p.X * 10 + 0.5) .. "," .. math.floor(p.Y * 10 + 0.5) end
	local at = {}
	for n, sgm in segs do
		for e = 1, 2 do local k = key(sgm[e]); at[k] = at[k] or {}; table.insert(at[k], n) end
	end
	local used, loops = {}, {}
	for n0 in segs do
		if used[n0] then continue end
		used[n0] = true
		local loop = { segs[n0][1], segs[n0][2] }
		local cur = segs[n0][2]
		while true do
			local nxt = nil
			for _, m in at[key(cur)] or {} do if not used[m] then nxt = m; break end end
			if not nxt then break end
			used[nxt] = true
			local sg = segs[nxt]
			cur = if key(sg[1]) == key(cur) then sg[2] else sg[1]
			if key(cur) == key(loop[1]) then break end
			table.insert(loop, cur)
		end
		if #loop >= 4 then table.insert(loops, loop) end
	end
	-- Chaikin rounding (closed loops), 3 passes
	for li, loop in loops do
		for _ = 1, 3 do
			local out = table.create(#loop * 2)
			for q = 1, #loop do
				local p0, p1 = loop[q], loop[q % #loop + 1]
				table.insert(out, p0:Lerp(p1, 0.25)); table.insert(out, p0:Lerp(p1, 0.75))
			end
			loop = out
		end
		-- resample at an even STEP so part count follows the coast length, not the rounding detail
		local per = 0
		for q = 1, #loop do per += (loop[q % #loop + 1] - loop[q]).Magnitude end
		local nOut = math.max(6, math.floor(per / STEP + 0.5))
		local stepLen = per / nOut
		local res, q, acc, want = {}, 1, 0, 0
		local cur = loop[1]
		while #res < nOut do
			local nxt = loop[q % #loop + 1]
			local segL = (nxt - loop[q]).Magnitude
			if acc + segL >= want then
				res[#res + 1] = loop[q]:Lerp(nxt, if segL > 0 then (want - acc) / segL else 0)
				want += stepLen
			else
				acc += segL; q += 1
				if q > #loop then break end
			end
		end
		loops[li] = res
		_ = cur
	end
	return loops
end
-- cross-section of the cliff, swept along each smooth coast loop: { out (studs past the contour), y (studs below the
-- lip top), colour band, smooth? }. Lip: rounded grass overhang; then a tuck, a bulging rock face with a ledge, a
-- wet foot under the beach. "j" = how much the per-point noise pushes that vertex out (chunky rock masses).
local PROFILE = {
	-- { out (studs past the contour), y, colour band, bulge, abs?, v (texture row 0..1) }
	-- rock part: y in "rock units" 0..-9.6 (scaled to fit between the lip top and the beach)
	{ -4.6, -0.30, "grass", 0, false, 0.00 }, { 0.2, 0.05, "grass", 0, false, 0.07 }, { 1.05, -0.25, "grass", 0, false, 0.11 },
	{ 1.45, -0.80, "grass", 0, false, 0.15 }, { 1.20, -1.30, "grassD", 0, false, 0.195 }, { 0.55, -1.55, "rockT", 0.2, false, 0.225 },
	{ 0.95, -2.6, "rockA", 0.9, false, 0.32 }, { 1.25, -4.1, "rockA", 1.0, false, 0.45 }, { 1.05, -4.8, "ledge", 0.6, false, 0.50 },
	{ 1.65, -5.25, "ledge", 0.6, false, 0.545 }, { 1.30, -5.9, "rockB", 0.9, false, 0.59 }, { 1.55, -7.6, "rockB", 1.0, false, 0.71 },
	{ 1.95, -9.6, "foot", 0.6, false, 0.82 },
	-- beach: y relative to the water surface: an even sand apron sloping into the water
	{ 2.4, 1.05, "sand", 0.25, true, 0.86 }, { 4.6, 0.75, "sand", 0.3, true, 0.90 }, { 6.6, 0.2, "sandW", 0.3, true, 0.94 },
	{ 8.0, -0.55, "sandW", 0.3, true, 0.97 }, { 9.6, -2.2, "shelf", 0.3, true, 1.00 },
}
local U_PERIOD = 24          -- studs of coast per texture repeat
-- the cliff texture: painted procedurally (toon look, no upload): grass lip with hanging blade tips, layered rock
-- strata with cracks, bright top edges and dark bottom edges, a wet foot, speckled sand -> wet sand
local cliffTex = nil
local function cliffTexture()
	if cliffTex then return cliffTex end
	local TW, TH = 256, 512
	local img = newImage(TW, TH)
	if not img then return nil end
	local buf = buffer.create(TW * TH * 4)
	local function C(h) local c = hx(h); return Vector3.new(c.R, c.G, c.B) end
	local GRASS, GRASS_L, GRASS_D, GRASS_DD = C("6fb43f"), C("86c64f"), C("4f9a34"), C("3a7a28")   -- lip top matched to the rendered turf
	local ROCKS = { C("c98d4d"), C("b47a42"), C("a46c3a"), C("bb8247"), C("9a6234"), C("b07743") }
	local INKR, LIGHT = C("5c391d"), C("e2ae6c")
	local FOOTC, SAND, SAND_D, WET = C("5a3b22"), C("f2dea4"), C("e2c98a"), C("cdb37a")
	-- strata band edges (v) inside the rock zone
	local EDGES = { 0.225, 0.30, 0.40, 0.495, 0.55, 0.63, 0.72, 0.80 }
	for y = 0, TH - 1 do
		local v = (y + 0.5) / TH
		for x = 0, TW - 1 do
			local u = (x + 0.5) / TW
			local col
			if v < 0.17 then
				-- the lip top matches the flat turf exactly (no stripes), only the rolled front edge darkens
				col = GRASS
				if v > 0.115 then col = col:Lerp(GRASS_D, math.clamp((v - 0.115) / 0.05, 0, 1) * 0.55) end
				if v > 0.06 and v < 0.11 and hash(x * 0.9, math.floor(y / 3)) > 0.985 then col = GRASS_L end
			elseif v < 0.215 then
				-- underside of the lip with hanging blade tips
				local tip = (u * 30) % 1
				local h = 0.17 + 0.045 * (1 - math.abs(tip - 0.5) * 2) * (0.6 + hash(math.floor(u * 30), 2) * 0.4)
				col = if v < h then GRASS_DD:Lerp(Vector3.new(0.12, 0.3, 0.08), 0.35) else ROCKS[1]:Lerp(INKR, 0.55)
			elseif v < 0.80 then
				local band = 1
				for k = 1, #EDGES - 1 do if v >= EDGES[k] then band = k end end
				local v0, v1 = EDGES[band], EDGES[band + 1]
				local wob = math.sin(u * 37 + band * 1.7) * 0.004 + math.sin(u * 91 + band) * 0.002
				col = ROCKS[(band - 1) % #ROCKS + 1]
				if band == 4 then col = col:Lerp(INKR, 0.35) end   -- the ledge band
				local t = (v - v0) / (v1 - v0)
				if v - v0 < 0.006 + wob then col = LIGHT                         -- lit top edge of the layer
				elseif v1 - v < 0.008 - wob then col = INKR                       -- dark seam under the layer
				elseif t > 0.62 then col = col:Lerp(INKR, 0.18) end               -- 2-band toon shade on the lower part
				-- vertical cracks: a few per band, jittered, with a light rim on one side
				local nC = 2 + (band % 3)
				for c = 1, nC do
					local cx = (hash(band, c * 3.1) * 0.8 + c + hash(c, band * 1.3) * 0.6) / nC % 1
					local dx = math.abs(((u - cx + 0.5) % 1) - 0.5) * TW
					local jag = math.sin(v * 220 + c) * 0.8
					if dx < 1.1 + jag * 0.3 and t > 0.08 and t < 0.92 then col = INKR
					elseif dx < 2.3 and dx >= 1.1 and ((u - cx) % 1) < 0.5 and t > 0.08 and t < 0.92 then col = col:Lerp(LIGHT, 0.35) end
				end
				-- pebbles / pits
				if hash(x * 0.71, y * 1.33) > 0.996 then col = col:Lerp(INKR, 0.5) end
			elseif v < 0.84 then
				col = FOOTC
				if v < 0.805 then col = INKR end
				if math.sin(u * 60) > 0.97 then col = FOOTC:Lerp(LIGHT, 0.25) end
			else
				local t = (v - 0.84) / 0.16
				col = SAND:Lerp(SAND_D, math.clamp((t - 0.45) / 0.3, 0, 1)):Lerp(WET, math.clamp((t - 0.72) / 0.28, 0, 1))
				if hash(x * 1.9, y * 0.77) > 0.985 then col = col:Lerp(Vector3.new(1, 1, 1), 0.35) end
				if hash(x * 0.37, y * 2.1) > 0.992 then col = col:Lerp(C("a88a5a"), 0.5) end
			end
			local o = (y * TW + x) * 4
			buffer.writeu8(buf, o, math.clamp(col.X * 255, 0, 255)); buffer.writeu8(buf, o + 1, math.clamp(col.Y * 255, 0, 255))
			buffer.writeu8(buf, o + 2, math.clamp(col.Z * 255, 0, 255)); buffer.writeu8(buf, o + 3, 255)
		end
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(TW, TH), buf)
	cliffTex = img
	return img
end
local BEACH_OUT = 9.6 + 1.6   -- studs from the coast contour to the beach's underwater edge (SKIRT_OUT + last point)
local BAND = { grass = hx("6fb843"), grassD = hx("2f6f22"), rockT = hx("6e4526"), rockA = hx("b97b40"), ledge = hx("7a4c2a"),
	rockB = hx("a26a37"), foot = hx("5a3b22"), sand = hx("f0dca0"), sandW = hx("dcc58c"), shelf = hx("8fd8c8") }
local lastLoops = {}
local AssetService2 = game:GetService("AssetService")
local skirtAnim: RBXScriptConnection? = nil
local function buildSkirt(mnI, mnJ, mxI, mxJ, riseAt)
	if skirtF then skirtF:Destroy() end
	if skirtAnim then skirtAnim:Disconnect(); skirtAnim = nil end
	skirtF = Instance.new("Folder"); skirtF.Name = "Skirt"
	-- unlock animation: columns whose land tile is part of the fresh island start DROP studs under the sea and rise
	-- with the tile wave (riseAt(i, j) = seconds after the unlock starts, nil = already open land)
	local rising = {}   -- { em, delay, verts = { {vid, pos} } }
	local DROP, DUR = 14, 0.45
	local function landAtWorld(p: Vector2) return skirtLand(math.floor((p.X - sx(0)) / S), math.floor((p.Y - sz(0)) / S)) end
	local WSURF = math.floor(SEA_Y / 4 + 0.5) * 4   -- the visible water surface (Terrain water top / painted sheet)
	local scaleY = (SKIRT_TOP - (WSURF + 1.05)) / 9.6   -- rock profile authored 9.6 tall, ends where the beach starts
	for _, loop in lastLoops do
		local nP = #loop
		if nP < 6 then continue end
		-- outward normal per point (average of the two neighbouring segments, flipped toward the sea)
		local nrm = table.create(nP)
		for q = 1, nP do
			local a0, a1 = loop[(q - 2) % nP + 1], loop[q % nP + 1]
			local t = (a1 - a0).Unit
			local nv = Vector2.new(t.Y, -t.X)
			if landAtWorld(loop[q] + nv * 2.5) and not landAtWorld(loop[q] - nv * 2.5) then nv = -nv end
			nrm[q] = nv
		end
		-- smooth per-point bulge noise (rock masses ~3 points wide)
		local bulge = table.create(nP)
		for q = 1, nP do
			local raw = 0
			for k = -1, 1 do raw += hash((q + k) % nP + 1, 4.4) * (if k == 0 then 0.5 else 0.25) end
			bulge[q] = (raw - 0.5) * 1.4
		end
		local ok, em = pcall(function() return AssetService2:CreateEditableMesh({}) end)
		if not ok or not em then continue end
		-- centre of this loop (vertices are written relative to it)
		local c = Vector2.zero
		for q = 1, nP do c += loop[q] end
		c /= nP
		local origin = Vector3.new(c.X, SKIRT_TOP, c.Y)
		-- grass drips (owner 2026-10-09: the grass line was "too flat"): the lip's underside hangs down in scallops of
		-- uneven depth, so the grass / rock border is a wavy hand-drawn line instead of a straight edge
		local drip = table.create(nP)
		do
			local a = 0
			for q = 1, nP do
				if q > 1 then a += (loop[q] - loop[q - 1]).Magnitude end
				local sc = 0.5 + 0.5 * math.sin(a / 2.8 * math.pi * 2 + hash(math.floor(a / 5.6), 3.3) * 2.4)
				drip[q] = 0.25 + 2.3 * sc ^ 2.2 * (0.55 + hash(math.floor(a / 2.8), 7.7) * 0.9) + hash(q, 8.8) * 0.2
			end
		end
		local DRIP_ROW = { [4] = 0.55, [5] = 1.0, [6] = 1.0 }
		local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
		local function P(q, r)
			local pr = PROFILE[r]
			local dr = (DRIP_ROW[r] or 0) * drip[q]
			local out = SKIRT_OUT + pr[1] + bulge[q] * pr[4] + dr * 0.18
			local p2 = loop[q] + nrm[q] * out
			local v = Vector3.new(p2.X, if pr[5] then WSURF + pr[2] else SKIRT_TOP + pr[2] * scaleY - dr, p2.Y) - origin
			mn = mn:Min(v); mx = mx:Max(v)
			return v
		end
		local tex = cliffTexture()
		local colIds = {}
		for name, col in BAND do colIds[name] = em:AddColor(if tex then Color3.new(1, 1, 1) else col, 1) end
		local colDelay, colVerts = {}, {}
		if riseAt then
			for q = 1, nP do
				local inner = loop[q] - nrm[q] * 2
				colDelay[q] = riseAt(math.floor((inner.X - sx(0)) / S), math.floor((inner.Y - sz(0)) / S))
				if colDelay[q] then colVerts[q] = {} end
			end
		end
		-- arc length per point (texture u)
		local arc = table.create(nP + 1)
		arc[1] = 0
		for q = 2, nP + 1 do arc[q] = arc[q - 1] + (loop[(q - 1) % nP + 1] - loop[q - 1]).Magnitude end
		-- toon facets on SHARED vertices (EditableMesh budget, 2026-10-09: one vertex per face corner used 18k vertices and
		-- starved every other EditableMesh in the game). Positions and UVs are one per grid point; flat shading stays
		-- because normals and colours are set per face (SetFaceNormals / SetFaceColors are independent of vertices).
		local NR = #PROFILE
		local vid, uvid = table.create(nP + 1), table.create(nP + 1)
		for q = 1, nP + 1 do
			local qq = (q - 1) % nP + 1
			vid[q], uvid[q] = table.create(NR), table.create(NR)
			for r = 1, NR do
				if q <= nP then
					local pos = P(qq, r)
					vid[q][r] = em:AddVertex(pos)
					if colVerts[qq] then table.insert(colVerts[qq], { vid[q][r], pos }) end
				else
					vid[q][r] = vid[1][r]   -- the loop closes on the first column (same position, own UV for the seam)
				end
				uvid[q][r] = em:AddUV(Vector2.new(arc[q] / U_PERIOD, PROFILE[r][6]))
			end
		end
		for q = 1, nP do
			local q2 = q % nP + 1
			for r = 1, NR - 1 do
				local a, b, cc, d = P(q, r), P(q2, r), P(q2, r + 1), P(q, r + 1)
				local band = PROFILE[r][3]
				local n1 = (b - a):Cross(d - a)
				if n1.Magnitude < 1e-6 then continue end
				n1 = n1.Unit
				-- winding: the face must point away from the land (outward / up)
				local outward = Vector3.new(nrm[q].X, 0, nrm[q].Y) + Vector3.new(0, 0.3, 0)
				local flip = n1:Dot(outward) < 0
				local va, vb, vc, vd = vid[q][r], vid[q + 1][r], vid[q + 1][r + 1], vid[q][r + 1]
				local ua, ub, uc, ud = uvid[q][r], uvid[q + 1][r], uvid[q + 1][r + 1], uvid[q][r + 1]
				local ni = em:AddNormal(if flip then -n1 else n1)
				local f1 = if flip then em:AddTriangle(va, vc, vb) else em:AddTriangle(va, vb, vc)
				local f2 = if flip then em:AddTriangle(va, vd, vc) else em:AddTriangle(va, vc, vd)
				local cid = colIds[band]
				em:SetFaceNormals(f1, { ni, ni, ni }); em:SetFaceNormals(f2, { ni, ni, ni })
				em:SetFaceColors(f1, { cid, cid, cid }); em:SetFaceColors(f2, { cid, cid, cid })
				if flip then em:SetFaceUVs(f1, { ua, uc, ub }); em:SetFaceUVs(f2, { ua, ud, uc })
				else em:SetFaceUVs(f1, { ua, ub, uc }); em:SetFaceUVs(f2, { ua, uc, ud }) end
			end
		end
		local okP, mp = pcall(function() return AssetService2:CreateMeshPartAsync(Content.fromObject(em)) end)
		if okP and mp then
			mp.Name = "Cliff"
			mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false
			mp.Material = Enum.Material.SmoothPlastic; mp.Color = Color3.new(1, 1, 1)
			mp.CFrame = CFrame.new(origin)   -- EditableMesh vertices keep their own origin (measured: no recentring)
			for q, list in colVerts do
				for _, v in list do em:SetPosition(v[1], v[2] - Vector3.new(0, DROP, 0)) end
				table.insert(rising, { em = em, delay = colDelay[q], verts = list })
			end
			if tex then pcall(function() mp.TextureContent = Content.fromObject(tex) end) end
			mp.Parent = skirtF
		else
			warn("[Ocean] cliff mesh failed: " .. tostring(mp))
		end
	end
	if #rising > 0 then
		local t = 0
		skirtAnim = RunService.RenderStepped:Connect(function(dt)
			t += dt
			local left = 0
			for _, r in rising do
				if r.done then continue end
				left += 1
				local k = math.clamp((t - r.delay) / DUR, 0, 1)
				if k <= 0 then continue end
				local e = 1 + 2.2 * (k - 1) ^ 3 + 1.2 * (k - 1) ^ 2   -- ease-out with a small overshoot (easeBack)
				local off = (1 - e) * DROP
				for _, v in r.verts do r.em:SetPosition(v[1], v[2] - Vector3.new(0, off, 0)) end
				if k >= 1 then r.done = true end
			end
			if left == 0 and skirtAnim then skirtAnim:Disconnect(); skirtAnim = nil end
		end)
	end
	local hl = Instance.new("Highlight")
	hl.OutlineColor = Color3.fromHex("16181e"); hl.OutlineTransparency = 0; hl.FillTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded; hl.Adornee = skirtF; hl.Parent = skirtF
	skirtF.Parent = root
end
function Ocean.rebuild(riseAt: ((number, number) -> number?)?)
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
	-- BFS distance from open land over the sea, up to 14 tiles
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
		if d0 >= 14 then continue end
		for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = c[1] + o[1], c[2] + o[2]
			if ni < mnI or ni > mxI or nj < mnJ or nj > mxJ then continue end
			if dist[k(ni, nj)] == nil then dist[k(ni, nj)] = d0 + 1; table.insert(q, { ni, nj }) end
		end
	end
	-- coast signature (BFS ring) -> rebuild the smooth coast loops, the cliff+beach mesh and the painted sea
	local sig = {}
	for j = mnJ, mxJ do
		for i = mnI, mxI do
			local d = dist[k(i, j)]
			if d and d > 0 and d <= 2 then table.insert(sig, k(i, j) * 8 + d) end
		end
	end
	table.sort(sig)
	local sigS = table.concat(sig, ",")
	if sigS ~= skirtSig then
		skirtSig = sigS
		lastLoops = coastLoops(mnI, mnJ, mxI, mxJ)
		buildSkirt(mnI, mnJ, mxI, mxJ, riseAt)
		buildWaveFronts(lastLoops)
		-- exact distance (tiles) from each tile centre to the smooth coast, bucketed so it stays cheap; the painted
		-- shallows / foam / wave lines then follow the real curved coast instead of tile-step diamonds
		local BK = 4
		local buckets = {}
		for _, loop in lastLoops do
			for _, p in loop do
				local bi, bj = math.floor((p.X - sx(0)) / S / BK), math.floor((p.Y - sz(0)) / S / BK)
				local kk = bi .. "," .. bj
				buckets[kk] = buckets[kk] or {}
				table.insert(buckets[kk], p)
			end
		end
		local function exact(i, j)
			if openLand(i, j) then return 0 end
			local d0 = dist[k(i, j)]
			if not d0 or d0 >= 14 then return 12 end
			local c = Vector2.new(sx(i) + S / 2, sz(j) + S / 2)
			local bi, bj = math.floor(i / BK), math.floor(j / BK)
			local best = math.huge
			for dj = -3, 3 do
				for di = -3, 3 do
					local list = buckets[(bi + di) .. "," .. (bj + dj)]
					if list then for _, p in list do local m = (p - c).Magnitude; if m < best then best = m end end end
				end
			end
			return math.min(12, best / S)
		end
		local cache = {}
		task.spawn(paint, function(i, j)
			local kk = k(i, j)
			local v = cache[kk]
			if v == nil then v = exact(i, j); cache[kk] = v end
			return v
		end)
		-- the old Terrain beach / shelf columns go back to open sea (the beach is part of the cliff mesh now)
		local T = workspace.Terrain
		local TOP = math.floor(SEA_Y / 4 + 0.5) * 4
		local old = ringTiles
		ringTiles, ringSig = {}, sigS
		task.spawn(function()
			local n = 0
			for _, t in old do
				if not openLand(t[1], t[2]) then
					local x, z = sx(t[1]) + S / 2, sz(t[2]) + S / 2
					T:FillBlock(CFrame.new(x, (BED + TOP + 8) / 2, z), Vector3.new(S, TOP + 8 - BED, S), Enum.Material.Air)
					T:FillBlock(CFrame.new(x, TOP - 2, z), Vector3.new(S, 4, S), Enum.Material.Water)
				end
				n += 1; if n % 200 == 0 then task.wait() end
			end
		end)
	end
	local function shelfTop(d) return SEA_Y - 2.5 - math.max(0, d - 3) * 1.4 end
	-- coral on the reef edge + lists for life
	for j = mnJ, mxJ do
		for i = mnI, mxI do
			local d = dist[k(i, j)]
			if not d or d == 0 then continue end
			local x, z = sx(i) + S / 2, sz(j) + S / 2
			if d >= 2 and d <= 5 then table.insert(coastList, Vector3.new(x, 0, z)) end
			if d >= 8 then table.insert(deepList, Vector3.new(x, 0, z)) end
			if d >= 3 and d <= 5 and hash(i, j) < 0.1 then
				local base = shelfTop(d)
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
	for _, g in glints do g.Transparency = 0.68 + 0.3 * n end
	for _, fr in fronts do fr.part.Color = hx("f2fdff"):Lerp(hx("8fa6c4"), n) end
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
		r.Transparency = 0.55 + 0.45 * ripFade
	end
	-- rolling waves: two crest fronts half a cycle apart travel from WAVE_FROM to WAVE_TO, building up far out and
	-- fading into the foam; only a visible front moves its vertices
	local surge = 0
	local dim = 1 - night * 0.55
	for _, fr in fronts do
		local ph = ((clock / 6.5) + fr.phase) % 1
		local pos = WAVE_FROM - ph * (WAVE_FROM - WAVE_TO)
		local amp = smooth(WAVE_FROM, WAVE_FROM - 1.1, pos) * (1 - smooth(3.3, WAVE_TO, pos))
		if pos < 3.3 then surge = math.max(surge, smooth(3.3, 2.7, pos)) end
		local tr = 1 - amp * 0.9 * dim
		if math.abs(fr.part.Transparency - tr) > 0.005 then fr.part.Transparency = tr end
		if amp > 0.01 then
			local off = pos * S
			local wsc = 0.7 + 0.6 * amp   -- the crest thickens as it builds
			local em = fr.em
			for _, v in fr.verts do
				local r = v.r
				local hw = r.hw * wsc
				local cx, cz = r.base.X + r.n.X * off, r.base.Y + r.n.Y * off
				em:SetPosition(v.a, Vector3.new(cx - r.n.X * hw, 0, cz - r.n.Y * hw))
				em:SetPosition(v.b, Vector3.new(cx + r.n.X * hw, 0, cz + r.n.Y * hw))
			end
		end
	end
	for kk, g in glints do
		g.OffsetStudsU = clock * (if kk == 1 then 1.6 else -1.1)
		g.OffsetStudsV = clock * (if kk == 1 then 1.1 else 1.4)
	end
	-- foam surges as each crest lands
	if foamDecal then
		local ft = 0.04 + (1 - surge) * 0.28
		if math.abs(foamDecal.Transparency - ft) > 0.01 then foamDecal.Transparency = ft end
	end
end

return Ocean
