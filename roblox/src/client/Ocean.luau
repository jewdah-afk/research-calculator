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

-- ---------------------------------------------------------------- static sea
function Ocean.build(parent)
	if root then root:Destroy() end
	root = Instance.new("Folder"); root.Name = "Ocean"; root.Parent = parent or workspace
	surface = part(root, Vector3.new(4000, 1, 4000), CFrame.new(0, SEA_Y - 0.5, 0), hx("2f93c8"), Enum.Material.SmoothPlastic, 0.18)
	surface.Name = "Sea"; surface.Reflectance = 0.06
	deep = part(root, Vector3.new(4000, 1, 4000), CFrame.new(0, SEA_Y - 26, 0), hx("0e3d66"))
	deep.Name = "SeaFloor"
	shelfF = Instance.new("Folder"); shelfF.Name = "Shelf"; shelfF.Parent = root
	lifeF = Instance.new("Folder"); lifeF.Name = "Life"; lifeF.Parent = root
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
	return c ~= 0
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
	-- shelf plates: depth steps down with distance (d 1..3 shallow sand, 4..5 reef edge); runs merged per row
	local function level(d) return if d <= 1 then 1 elseif d <= 3 then 2 elseif d <= 5 then 3 else 0 end
	local LEVEL_Y = { SEA_Y - 1.2, SEA_Y - 2.6, SEA_Y - 4.6 }
	local LEVEL_C = { "f1e2b4", "e2d29e", "5aa7a4" }
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
	-- foam: thin white plates on the surface along the waterline (d == 1), merged per row
	for j = mnJ, mxJ do
		local runStart = nil
		for i = mnI, mxI + 1 do
			local on = i <= mxI and dist[k(i, j)] == 1
			if on and not runStart then runStart = i
			elseif not on and runStart then
				local w = (i - runStart) * S
				local f = part(shelfF, Vector3.new(w - 0.4, 0.15, S * 0.55), CFrame.new(sx(runStart) + w / 2, SEA_Y + 0.05, sz(j) + S / 2), hx("ffffff"), nil, 0.55)
				f.Name = "Foam"
				runStart = nil
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
	if surface then surface.Color = hx("2f93c8"):Lerp(hx("173a66"), n) end
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
	-- foam breathes
	if shelfF and math.floor(clock * 4) ~= math.floor((clock - dt) * 4) then
		local tr = 0.5 + math.sin(clock * 1.3) * 0.12
		for _, f in shelfF:GetChildren() do if f.Name == "Foam" then f.Transparency = tr end end
	end
end

return Ocean
