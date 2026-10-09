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
	-- d = distance (tiles) to the smooth coast contour; the cliff mesh's beach meets the water at ~2.2 tiles
	local WAVE_D = { 4.9, 3.9, 3.0 }   -- wave line distance from the coast (tiles), outermost first
	for py = 0, PH - 1 do
		local fy = (py + 0.5) / PX - 0.5
		local j = math.clamp(math.floor(fy), 0, h - 1); local ty = math.clamp(fy - j, 0, 1)
		for px = 0, PW - 1 do
			local fx = (px + 0.5) / PX - 0.5
			local i = math.clamp(math.floor(fx), 0, w - 1); local tx = math.clamp(fx - i, 0, 1)
			local r0 = j * (w + 1) + i + 1
			local d = lerp1(lerp1(g[r0], g[r0 + 1], tx), lerp1(g[r0 + w + 1], g[r0 + w + 2], tx), ty)
			local shallow = 1 - smooth(2.0, 7.5, d)
			local c = DEEP:Lerp(MID, smooth(9, 4, d)):Lerp(SHAL, shallow * shallow)
			local n = hash(px * 0.37, py * 0.53)
			c += Vector3.one * ((n - 0.5) * 0.025 * (1 - smooth(6, 7.5, d)))
			if d >= 7.5 then c = FARV end   -- open water: exactly the far-sea colour, so the painted edge never shows
			local a = if d < 2.0 then 0 elseif d > 7.5 then 0.8 else lerp1(0.8, 0.42, shallow)
			local o = (py * PW + (PW - 1 - px)) * 4   -- Top-face decals run U along -X
			buffer.writeu8(tb, o, math.clamp(c.X * 255, 0, 255)); buffer.writeu8(tb, o + 1, math.clamp(c.Y * 255, 0, 255))
			buffer.writeu8(tb, o + 2, math.clamp(c.Z * 255, 0, 255)); buffer.writeu8(tb, o + 3, a * 255)
			-- foam: soft band hugging the coast with ripples running in, plus rare flecks further out
			local band = smooth(3.0, 2.2, d) * smooth(1.95, 2.25, d)
			local f = band * (0.6 + 0.4 * math.sin(d * 7 + n * 1.5))
			if d > 3.0 and d < 5.5 and n > 0.985 then f = math.max(f, 0.5) end
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
local function skirtLand(i, j) local c = World.tile(i, j); return c ~= 0 and c ~= 5 end
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
	{ -4.6, 0.00, "grass", 0, false, 0.00 }, { 0.2, 0.05, "grass", 0, false, 0.07 }, { 1.05, -0.25, "grass", 0, false, 0.11 },
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
	local GRASS, GRASS_L, GRASS_D, GRASS_DD = C("7cc24a"), C("93d35c"), C("4f9a34"), C("3a7a28")
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
				col = if v < h then GRASS_DD else ROCKS[1]:Lerp(INKR, 0.55)
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
local BAND = { grass = hx("6fb843"), grassD = hx("3f8a2c"), rockT = hx("6e4526"), rockA = hx("b97b40"), ledge = hx("7a4c2a"),
	rockB = hx("a26a37"), foot = hx("5a3b22"), sand = hx("f0dca0"), sandW = hx("dcc58c"), shelf = hx("8fd8c8") }
local lastLoops = {}
local AssetService2 = game:GetService("AssetService")
local function buildSkirt(mnI, mnJ, mxI, mxJ)
	if skirtF then skirtF:Destroy() end
	skirtF = Instance.new("Folder"); skirtF.Name = "Skirt"
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
		local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
		local function P(q, r)
			local pr = PROFILE[r]
			local out = SKIRT_OUT + pr[1] + bulge[q] * pr[4]
			local p2 = loop[q] + nrm[q] * out
			local v = Vector3.new(p2.X, if pr[5] then WSURF + pr[2] else SKIRT_TOP + pr[2] * scaleY, p2.Y) - origin
			mn = mn:Min(v); mx = mx:Max(v)
			return v
		end
		local tex = cliffTexture()
		local colIds = {}
		for name, col in BAND do colIds[name] = em:AddColor(if tex then Color3.new(1, 1, 1) else col, 1) end
		-- arc length per point (texture u)
		local arc = table.create(nP + 1)
		arc[1] = 0
		for q = 2, nP + 1 do arc[q] = arc[q - 1] + (loop[(q - 1) % nP + 1] - loop[q - 1]).Magnitude end
		-- flat-shaded quads (own vertices per face): crisp toon facets
		for q = 1, nP do
			local q2 = q % nP + 1
			for r = 1, #PROFILE - 1 do
				local a, b, cc, d = P(q, r), P(q2, r), P(q2, r + 1), P(q, r + 1)
				local band = PROFILE[r][3]
				local n1 = (b - a):Cross(d - a)
				if n1.Magnitude < 1e-6 then continue end
				n1 = n1.Unit
				-- winding: the face must point away from the land (outward / up)
				local outward = Vector3.new(nrm[q].X, 0, nrm[q].Y) + Vector3.new(0, 0.3, 0)
				local flip = n1:Dot(outward) < 0
				local va, vb, vc, vd = em:AddVertex(a), em:AddVertex(b), em:AddVertex(cc), em:AddVertex(d)
				local ni = em:AddNormal(if flip then -n1 else n1)
				local u0, u1 = arc[q] / U_PERIOD, arc[q + 1] / U_PERIOD
				local tv0, tv1 = PROFILE[r][6], PROFILE[r + 1][6]
				local ua, ub, uc, ud = em:AddUV(Vector2.new(u0, tv0)), em:AddUV(Vector2.new(u1, tv0)), em:AddUV(Vector2.new(u1, tv1)), em:AddUV(Vector2.new(u0, tv1))
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
			if tex then pcall(function() mp.TextureContent = Content.fromObject(tex) end) end
			mp.Parent = skirtF
		else
			warn("[Ocean] cliff mesh failed: " .. tostring(mp))
		end
	end
	local hl = Instance.new("Highlight")
	hl.OutlineColor = Color3.fromHex("16181e"); hl.OutlineTransparency = 0; hl.FillTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded; hl.Adornee = skirtF; hl.Parent = skirtF
	skirtF.Parent = root
end
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
		buildSkirt(mnI, mnJ, mxI, mxJ)
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
			if not d0 or d0 >= 10 then return 8 end
			local c = Vector2.new(sx(i) + S / 2, sz(j) + S / 2)
			local bi, bj = math.floor(i / BK), math.floor(j / BK)
			local best = math.huge
			for dj = -3, 3 do
				for di = -3, 3 do
					local list = buckets[(bi + di) .. "," .. (bj + dj)]
					if list then for _, p in list do local m = (p - c).Magnitude; if m < best then best = m end end end
				end
			end
			return math.min(8, best / S)
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
