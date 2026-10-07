--!strict
-- Island — the Park map rebuilt from MapData, matching src/three/View3D.js buildTerrain() 1:1:
-- per tile a 0.3-tile top (grass checker / dirt path / sand) on a soil column; edge columns hang deeper and ragged
-- so the island floats; 4 studs per grass tile; scenery at the exported positions. 1 tile = S studs, top surface y = 0.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Map = require(Shared:WaitForChild("MapData"))
local Models = require(Shared:WaitForChild("Models"))

local S = Models.S
local Island = {}

local C = {   -- toned-down, natural palette (owner: "way too vibrant")
	grassA = Color3.fromHex("#8cc06a"), grassB = Color3.fromHex("#84b863"), dirt = Color3.fromHex("#d9bf91"), dirtB = Color3.fromHex("#d1b687"),
	sand = Color3.fromHex("#e8d9ad"), soil = Color3.fromHex("#8b6a4e"), soilD = Color3.fromHex("#6e533e"),
	lip = Color3.fromHex("#6fa553"), topsoil = Color3.fromHex("#5f4532"), rock = Color3.fromHex("#8d8478"), rockD = Color3.fromHex("#746c62"),
	tuft = Color3.fromHex("#7fb35e"), tuftL = Color3.fromHex("#a6d27c"), pebble = Color3.fromHex("#b9b2a6"),
}

local function hash(i: number, j: number): number   -- deterministic 0..1 per tile (View3D hash role)
	local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453
	return n - math.floor(n)
end

-- game px (x, y) -> world position on the ground plane
function Island.toWorld(x: number, y: number, z: number?): Vector3
	return Vector3.new((x / Map.PX - Map.COLS / 2) * S, (z or 0) / Map.PX * S, (y / Map.PX - Map.ROWS / 2) * S)
end
function Island.tileCenter(i: number, j: number): Vector3
	return Vector3.new((i + 0.5 - Map.COLS / 2) * S, 0, (j + 0.5 - Map.ROWS / 2) * S)
end

local function shade(c: Color3, d: number): Color3
	local h, s, v = c:ToHSV(); return Color3.fromHSV(h, s, math.clamp(v + d, 0, 1))
end

local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, collide: boolean, shadow: boolean): Part
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.Position = pos; p.Color = color; p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true; p.CanCollide = collide; p.CanTouch = false; p.CanQuery = collide; p.CastShadow = shadow
	p.Parent = parent
	return p
end

function Island.build(): Folder
	local root = Instance.new("Folder"); root.Name = "Island"
	local tops, bodies, studs, walls, detail = Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
	tops.Name, bodies.Name, studs.Name, walls.Name, detail.Name = "Tops", "Bodies", "Studs", "Walls", "Detail"
	for _, f in { tops, bodies, studs, walls, detail } do f.Parent = root end
	-- Models (not Folders) so the client can outline each group with ONE Highlight (Roblox caps highlights at 31)
	local deco = Instance.new("Model"); deco.Name = "Scenery"; deco.Parent = root
	local flowers = Instance.new("Model"); flowers.Name = "Flowers"; flowers.Parent = root
	local function blob(at: Vector3, r: number)   -- soft contact shadow: grounds every object on the studs
		local d = part(detail, "Contact", Vector3.new(0.02, r * 2, r * 2), at + Vector3.new(0, 0.07 * S, 0), Color3.fromHex("#22301c"), false, false)
		d.Shape = Enum.PartType.Cylinder; d.CFrame = CFrame.new(d.Position) * CFrame.Angles(0, 0, math.rad(90)); d.Transparency = 0.72
	end

	local land = {}
	for j = 0, Map.ROWS - 1 do for i = 0, Map.COLS - 1 do land[j * Map.COLS + i] = Map.tile(i, j) ~= 0 end end
	local function isLand(i: number, j: number): boolean
		if i < 0 or j < 0 or i >= Map.COLS or j >= Map.ROWS then return false end
		return land[j * Map.COLS + i]
	end

	local studSize = Vector3.new(0.035 * S, 0.32 * S, 0.32 * S)   -- low studs: texture, not noise, under a low sun   -- cylinder axis is X: (height, diameter, diameter)
	for j = 0, Map.ROWS - 1 do
		for i = 0, Map.COLS - 1 do
			local t = Map.tile(i, j)
			local c = Island.tileCenter(i, j)
			if t == 0 then
				-- invisible wall on void tiles that touch land, so the bird can't walk off the edge
				if isLand(i + 1, j) or isLand(i - 1, j) or isLand(i, j + 1) or isLand(i, j - 1) then
					local w = part(walls, "Wall", Vector3.new(S, 6 * S, S), c + Vector3.new(0, 3 * S, 0), Color3.new(), true, false)
					w.Transparency = 1
				end
				continue
			end
			local n = hash(i, j)
			local col: Color3, stud = C.grassA, false
			if t == 2 then col = if (i + j) % 2 == 1 then C.dirt else C.dirtB
			elseif t == 4 then col = C.sand
			else col = if (i + j) % 2 == 1 then C.grassA else C.grassB; stud = true end
			col = shade(col, (n - 0.5) * 0.03)
			part(tops, "Top", Vector3.new(S, 0.3 * S, S), c - Vector3.new(0, 0.15 * S, 0), col, true, false)
			local edge = not (isLand(i + 1, j) and isLand(i - 1, j) and isLand(i, j + 1) and isLand(i, j - 1))
			local depth = if edge then 1.6 + n * 2.6 else 1.4
			-- strata: dark topsoil band, then soil, then rock on the deep edge columns (readable cliff faces)
			local band = 0.35
			part(bodies, "Topsoil", Vector3.new(S, band * S, S), c - Vector3.new(0, (0.3 + band / 2) * S, 0), shade(C.topsoil, (n - 0.5) * 0.04), false, true)
			local soilH = math.min(depth - band, 1.3)
			part(bodies, "Soil", Vector3.new(S, soilH * S, S), c - Vector3.new(0, (0.3 + band + soilH / 2) * S, 0), shade(C.soil, (n - 0.5) * 0.05), false, true)
			local rockH = depth - band - soilH
			if rockH > 0.05 then
				part(bodies, "Rock", Vector3.new(S * 0.96, rockH * S, S * 0.96), c - Vector3.new(0, (0.3 + band + soilH + rockH / 2) * S, 0), shade(if (i + j) % 2 == 0 then C.rock else C.rockD, (n - 0.5) * 0.05), false, true)
			end
			if edge and n > 0.45 then
				part(bodies, "Drip", Vector3.new(0.7 * S, 1.2 * S, 0.7 * S), c - Vector3.new(0, (0.3 + depth + 0.6) * S, 0), C.rockD, false, true)
			end
			-- grass lip: a slightly proud, darker rim on every open edge = a clean island silhouette
			if t == 1 then
				for _, dd in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					if not isLand(i + dd[1], j + dd[2]) then
						local sz = if dd[1] ~= 0 then Vector3.new(0.16 * S, 0.22 * S, S * 1.04) else Vector3.new(S * 1.04, 0.22 * S, 0.16 * S)
						part(tops, "Lip", sz, c + Vector3.new(dd[1] * 0.47 * S, -0.2 * S, dd[2] * 0.47 * S), shade(C.lip, (n - 0.5) * 0.03), false, true)
					end
				end
			end
			-- detail: grass tufts on open grass, pebbles where the path meets grass
			if t == 1 and n > 0.93 and not edge then
				for b = 0, 2 do
					local a = (n * 40 + b * 2.1)
					local blade = part(detail, "Tuft", Vector3.new(0.05 * S, (0.16 + b * 0.04) * S, 0.12 * S),
						c + Vector3.new(math.cos(a) * 0.18 * S, (0.08 + b * 0.02) * S, math.sin(a) * 0.18 * S), if b == 1 then C.tuftL else C.tuft, false, false)
					blade.CFrame = CFrame.new(blade.Position) * CFrame.Angles(0, a, (b - 1) * 0.35)
				end
			elseif t == 2 and n > 0.55 and (isLand(i, j) and (Map.tile(i + 1, j) == 1 or Map.tile(i - 1, j) == 1 or Map.tile(i, j + 1) == 1 or Map.tile(i, j - 1) == 1)) then
				local pb = part(detail, "Pebble", Vector3.new(0.16 * S, 0.08 * S, 0.12 * S), c + Vector3.new((n - 0.7) * S, 0.04 * S, (hash(j, i) - 0.5) * 0.6 * S), C.pebble, false, false)
				pb.Shape = Enum.PartType.Ball; pb.Size = Vector3.one * 0.13 * S
			end
			if stud then
				local sc = shade(col, 0.012)
				for _, o in { { 0.27, 0.27 }, { 0.73, 0.27 }, { 0.27, 0.73 }, { 0.73, 0.73 } } do
					local p = part(studs, "Stud", studSize, c + Vector3.new((o[1] - 0.5) * S, 0.017 * S, (o[2] - 0.5) * S), sc, false, false)
					p.Shape = Enum.PartType.Cylinder; p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, 0, math.rad(90))
				end
			end
		end
	end

	-- scenery at the exported spots (same models / scales / yaw hashing as View3D)
	local k = 0
	for _, o in Map.objects do
		local kind, x, y, z = o[1], o[2], o[3], o[4]
		local m: Model
		if kind == "pillar" then m = Models.pillar()
		elseif kind == "arch lintel" then m = Models.lintel()
		elseif kind == "bush" then m = Models.bush(k)
		elseif kind == "rock" then m = Models.rock()
		elseif kind == "lantern" then m = Models.lantern()
		elseif kind == "tree" then m = Models.tree(k % 3); m.WorldPivot = CFrame.new(); m:ScaleTo(1.15)
		else continue end
		k += 1
		Models.place(m, Island.toWorld(x, y, z), if kind == "bush" or kind == "tree" then hash(x, y) * 6 else 0)
		if kind ~= "arch lintel" then blob(Island.toWorld(x, y, 0), (if kind == "pillar" then 0.5 elseif kind == "bush" then 0.38 elseif kind == "tree" then 0.75 elseif kind == "lantern" then 0.22 else 0.42) * S) end
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then p.CanCollide = kind ~= "arch lintel"; p.CanQuery = p.CanCollide end
		end
		m.Parent = deco
	end
	for idx, f in Map.flowers do
		local m = Models.flower(f[1])
		m.WorldPivot = CFrame.new(); m:ScaleTo(1.3)
		Models.place(m, Island.toWorld(f[1], f[2]), hash(f[2], f[1]) * 6)
		m.Name = "Flower" .. idx; m.Parent = flowers
	end

	-- voxel clouds drifting around the island (the client animates them)
	local clouds = Instance.new("Folder"); clouds.Name = "Clouds"; clouds.Parent = root
	local rnd = Random.new(9)
	for c = 1, 9 do
		local m = Models.cloud(c)
		local a = (c / 9) * math.pi * 2
		Models.place(m, Vector3.new(math.cos(a) * 26 * S, rnd:NextNumber(-6, 4) * S, math.sin(a) * 20 * S))
		m.Parent = clouds
	end

	-- ---------------- mood backdrop: dusky sky floor, distant islands (atmospheric perspective), low clouds
	local back = Instance.new("Folder"); back.Name = "Backdrop"; back.Parent = root
	local sky = part(back, "SkyFloor", Vector3.new(6000, 2, 6000), Vector3.new(0, -420, 0), Color3.fromHex("#7d93bf"), false, false)
	sky.Material = Enum.Material.SmoothPlastic
	local glow = part(back, "SkyGlow", Vector3.new(0.02, 900, 900), Vector3.new(0, -300, 0), Color3.fromHex("#f3c9a0"), false, false)
	glow.Shape = Enum.PartType.Cylinder; glow.CFrame = CFrame.new(glow.Position) * CFrame.Angles(0, 0, math.rad(90)); glow.Transparency = 0.55
	-- distant floating islands: further = smaller, cooler, hazier (stacked voxel slabs, darker underside)
	local far = { { -150, -70, -160, 1.0 }, { 170, -95, -120, 0.8 }, { -210, -120, 60, 0.7 }, { 230, -60, 90, 0.9 }, { 40, -140, -260, 0.6 }, { -60, -110, 230, 0.65 } }
	for idx, f in far do
		local x, y, z, sc = f[1], f[2], f[3], f[4]
		local haze = math.clamp((-y - 50) / 110, 0, 1)
		local top = Color3.fromHex("#86b268"):Lerp(Color3.fromHex("#9fb0c8"), 0.35 + haze * 0.45)
		local side = Color3.fromHex("#6b5442"):Lerp(Color3.fromHex("#7f8aa6"), 0.4 + haze * 0.45)
		local w = (10 + idx % 3 * 4) * sc * S
		part(back, "FarTop", Vector3.new(w, 0.5 * S, w * 0.75), Vector3.new(x, y, z), top, false, false)
		for k = 1, 3 do
			local kw = w * (1 - k * 0.22)
			part(back, "FarRock", Vector3.new(kw, 1.6 * S * sc, kw * 0.72), Vector3.new(x + (k % 2) * 2, y - (0.25 + k * 1.4) * S * sc, z), side:Lerp(Color3.fromHex("#7f8aa6"), k * 0.12), false, false)
		end
		if idx % 2 == 1 then   -- a lone voxel tree silhouette
			part(back, "FarTrunk", Vector3.new(0.4 * S * sc, 1.2 * S * sc, 0.4 * S * sc), Vector3.new(x + w * 0.2, y + 0.85 * S * sc, z), side, false, false)
			part(back, "FarCanopy", Vector3.new(1.6 * S * sc, 1.2 * S * sc, 1.6 * S * sc), Vector3.new(x + w * 0.2, y + 2 * S * sc, z), top:Lerp(Color3.fromHex("#5f8f55"), 0.4), false, false)
		end
	end
	-- low clouds lit peach from the setting sun
	for k = 1, 7 do
		local m = Models.cloud(40 + k)
		local a = k / 7 * math.pi * 2 + 0.4
		Models.place(m, Vector3.new(math.cos(a) * 60 * S, -18 * S - (k % 3) * 4 * S, math.sin(a) * 48 * S))
		for _, p in m:GetChildren() do (p :: BasePart).Color = Color3.fromHex("#ffe2c8"); (p :: BasePart).Transparency = 0.1 end
		m.WorldPivot = m:GetPivot(); m:ScaleTo(2.2)
		m.Parent = back
	end
	root.Parent = workspace
	return root
end

return Island
