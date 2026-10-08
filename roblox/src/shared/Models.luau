--!strict
-- Models — the Blender asset builders (tools/blender/make_assets.py) ported 1:1 to Parts.
-- Blender units: 1 = one map tile, +Z up, -Y = front. Roblox: 1 tile = Models.S studs, +Y up, -Z = front.
-- (x, y, z)_blender -> (x, z, y)_roblox * S. Same sizes, offsets and palette as the GLBs.
local Models = {}
local S = 4
Models.S = S

local P = {
	white = "#fbf7ee", cream = "#fff1c9", butter = "#ffd75e", hull = "#e0a03c", orange = "#ff9a2e", beak = "#ffb21f",
	eye = "#1b1720", cheek = "#ff8fa0", leaf = "#71ac58", leafL = "#8fbf6c", leafD = "#548f48",
	stone = "#b3b5bd", stoneD = "#8a8c96", red = "#ef4c47", gold = "#ffcc33",
}
Models.P = P
local function col(h: string): Color3 return Color3.fromHex(h) end

local function v(x: number, y: number, z: number): Vector3 return Vector3.new(x * S, z * S, y * S) end

-- Blender euler (rx, ry, rz) -> Roblox (axis swap y<->z is a reflection, so angles flip sign)
local function rot(r: { number }?): CFrame
	if not r then return CFrame.identity end
	return CFrame.fromEulerAnglesXYZ(-(r[1] or 0), -(r[3] or 0), -(r[2] or 0))
end

local function base(p: BasePart, color: string, model: Model, name: string)
	p.Name = name; p.Color = col(color); p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Parent = model
end

function Models.box(model: Model, name: string, size: { number }, at: { number }, color: string, r: { number }?): Part
	local p = Instance.new("Part")
	p.Size = Vector3.new(size[1] * S, size[3] * S, size[2] * S)
	p.CFrame = CFrame.new(v(at[1], at[2], at[3])) * rot(r)
	base(p, color, model, name); return p
end

-- ellipsoid via a sphere SpecialMesh (non-uniform scale)
function Models.ball(model: Model, name: string, r: number, at: { number }, color: string, sc: { number }?): Part
	local s = sc or { 1, 1, 1 }
	local p = Instance.new("Part")
	p.Size = Vector3.new(2 * r * s[1] * S, 2 * r * s[3] * S, 2 * r * s[2] * S)
	p.CFrame = CFrame.new(v(at[1], at[2], at[3]))
	local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
	base(p, color, model, name); return p
end

function Models.cyl(model: Model, name: string, r: number, d: number, at: { number }, color: string): Part
	local p = Instance.new("Part"); p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(d * S, 2 * r * S, 2 * r * S)
	p.CFrame = CFrame.new(v(at[1], at[2], at[3])) * CFrame.Angles(0, 0, math.rad(90))
	base(p, color, model, name); return p
end

local function newModel(name: string): Model
	local m = Instance.new("Model"); m.Name = name; return m
end

-- ---------------------------------------------------------------- bird (a_bird)
function Models.bird(): Model
	local m, box = newModel("Bird"), Models.box
	box(m, "body", { 0.56, 0.62, 0.5 }, { 0, 0, 0.42 }, P.white)
	box(m, "belly", { 0.4, 0.06, 0.32 }, { 0, -0.31, 0.36 }, "#ffffff")
	box(m, "head", { 0.5, 0.5, 0.42 }, { 0, -0.08, 0.82 }, P.white)
	box(m, "crest", { 0.12, 0.26, 0.14 }, { 0, -0.02, 1.08 }, "#ef4c47")
	box(m, "beak", { 0.18, 0.2, 0.12 }, { 0, -0.42, 0.78 }, P.beak)
	box(m, "beakLow", { 0.13, 0.12, 0.06 }, { 0, -0.38, 0.69 }, "#e58a10")
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		box(m, "eye" .. side, { 0.02, 0.1, 0.12 }, { s * 0.255, -0.2, 0.86 }, P.eye)
		box(m, "shine" .. side, { 0.025, 0.04, 0.04 }, { s * 0.262, -0.23, 0.9 }, P.white)
		box(m, "cheek" .. side, { 0.02, 0.08, 0.06 }, { s * 0.255, -0.3, 0.72 }, P.cheek)
		box(m, "wing" .. side, { 0.1, 0.4, 0.3 }, { s * 0.32, 0.04, 0.48 }, "#e6dccb")
		box(m, "leg" .. side, { 0.07, 0.07, 0.17 }, { s * 0.13, -0.02, 0.09 }, P.orange)
		box(m, "foot" .. side, { 0.14, 0.2, 0.04 }, { s * 0.13, -0.09, 0.02 }, P.orange)
	end
	box(m, "tail", { 0.36, 0.18, 0.16 }, { 0, 0.36, 0.56 }, "#e6dccb", { 0.5, 0, 0 })
	return m
end

-- ---------------------------------------------------------------- egg (the main currency pickup; was the popcorn kernel)
local SPECKS = { { 0.11, 0.11, 0.17 }, { -0.15, 0.03, 0.2 }, { 0.03, -0.155, 0.15 }, { -0.085, -0.09, 0.29 }, { 0.15, -0.045, 0.12 }, { -0.03, 0.125, 0.3 } }   -- sit on the shell surface
function Models.kernel(golden: boolean?): Model
	local m = newModel("Egg")
	local shell = if golden then "#ffc93a" else "#f4ead8"
	Models.ball(m, "shell", 0.15, { 0, 0, 0.17 }, shell, { 1, 1, 1.15 })      -- wide bottom
	Models.ball(m, "top", 0.12, { 0, 0, 0.27 }, shell, { 1, 1, 1.25 })        -- narrower top gives the egg shape
	for i, p in SPECKS do Models.ball(m, "speck" .. i, 0.022, p, if golden then "#e0a010" else "#c9a888") end
	if golden then for _, p in m:GetChildren() do (p :: BasePart).Reflectance = 0.08 end end   -- gold reads by colour + outline, not Neon (bloom blob)
	m.WorldPivot = CFrame.new(); m:ScaleTo(2.3)   -- scale about the base point, same size as the old kernel
	return m
end

-- ---------------------------------------------------------------- scenery
function Models.bush(seed: number): Model
	local m, rnd = newModel("Bush"), Random.new(5 + seed)
	for i = 0, 3 do
		Models.box(m, "b" .. i, { 0.45, 0.45, 0.4 }, { rnd:NextNumber(-0.2, 0.2), rnd:NextNumber(-0.2, 0.2), 0.2 + i * 0.05 }, if i % 2 == 1 then P.leaf else P.leafD)
	end
	for i = 1, 3 do Models.ball(m, "berry" .. i, 0.05, { rnd:NextNumber(-0.3, 0.3), -0.3, rnd:NextNumber(0.2, 0.4) }, P.red) end
	return m
end

function Models.rock(): Model
	local m = newModel("Rock")
	Models.ball(m, "rock", 0.4, { 0, 0, 0.25 }, P.stone, { 1.2, 1, 0.75 })
	Models.ball(m, "rock2", 0.22, { 0.35, 0.15, 0.12 }, P.stoneD)
	return m
end

local FCOLS = { "#ef8fa3", "#f2d36b", "#b9a0e6", "#f6f2ea" }
function Models.flower(k: number): Model
	local m = newModel("Flower")
	Models.box(m, "stem", { 0.03, 0.03, 0.2 }, { 0, 0, 0.1 }, P.leafD)
	for i = 0, 3 do
		local a = i * math.pi / 2
		Models.box(m, "pet" .. i, { 0.08, 0.08, 0.03 }, { math.cos(a) * 0.06, math.sin(a) * 0.06, 0.21 }, FCOLS[(k % 4) + 1])
	end
	Models.box(m, "ctr", { 0.06, 0.06, 0.04 }, { 0, 0, 0.22 }, P.butter)
	return m
end

function Models.pillar(): Model
	local m = newModel("Pillar")
	Models.box(m, "base", { 0.7, 0.7, 0.2 }, { 0, 0, 0.1 }, P.stoneD)
	Models.box(m, "shaft", { 0.5, 0.5, 2.1 }, { 0, 0, 1.2 }, P.stone)
	Models.box(m, "cap", { 0.7, 0.7, 0.2 }, { 0, 0, 2.3 }, P.stoneD)
	for k = 0, 2 do Models.box(m, "ivy" .. k, { 0.06, 0.52, 0.3 }, { 0.26, 0, 0.5 + k * 0.6 }, P.leafD) end
	return m
end

function Models.lintel(): Model   -- View3D arch lintel: 4.3 x 0.4 x 0.75 tiles
	local m = newModel("Lintel")
	Models.box(m, "lintel", { 4.3, 0.75, 0.4 }, { 0, 0, 0.2 }, P.stone)
	return m
end

function Models.cloud(seed: number): Model
	local m, rnd = newModel("Cloud"), Random.new(seed)
	local n = rnd:NextInteger(3, 5)
	for i = 1, n do
		local w = rnd:NextNumber(1.6, 3.2)
		Models.box(m, "puff" .. i, { w, w * 0.8, rnd:NextNumber(0.8, 1.4) }, { (i - n / 2) * 1.4, rnd:NextNumber(-0.6, 0.6), rnd:NextNumber(0, 0.5) }, "#ffffff")
	end
	for _, p in m:GetChildren() do (p :: BasePart).CastShadow = false end
	return m
end

-- voxel tree (a_tree): square trunk + three stacked canopy blocks + side clumps (+ an apple on odd variants)
function Models.tree(variant: number): Model
	local m, rnd = newModel("Tree"), Random.new(11 + variant)
	local cols = { P.leaf, P.leafL, P.leafD }
	Models.box(m, "trunk", { 0.3, 0.3, 1.0 }, { 0, 0, 0.5 }, "#8a5a36")
	local layers = { { 1.2, 1.15, 1.1 }, { 0.95, 0.95, 1.55 }, { 0.6, 0.6, 1.95 } }
	for i, L in layers do
		local w = L[1] * (1 + variant * 0.04)
		Models.box(m, "can" .. i, { w, L[2], 0.5 }, { rnd:NextNumber(-0.05, 0.05), rnd:NextNumber(-0.05, 0.05), L[3] }, if i < 3 then cols[((i - 1 + variant) % 2) + 1] else cols[1])
	end
	for k = 1, 3 do
		local a = rnd:NextNumber(0, 6.28)
		Models.box(m, "clump" .. k, { 0.42, 0.42, 0.38 }, { math.cos(a) * 0.55, math.sin(a) * 0.55, 1.2 + rnd:NextNumber(0, 0.4) }, cols[3])
	end
	if variant % 2 == 1 then Models.ball(m, "apple", 0.07, { 0.5, -0.45, 1.25 }, P.red) end
	return m
end

-- garden lantern: stone foot, warm wooden post, a glowing paper lantern ON TOP (reads from the high iso camera)
function Models.lantern(): Model
	local m = newModel("Lantern")
	Models.box(m, "foot", { 0.32, 0.32, 0.12 }, { 0, 0, 0.06 }, P.stoneD)
	Models.box(m, "post", { 0.12, 0.12, 1.15 }, { 0, 0, 0.67 }, "#9a6234")
	Models.box(m, "arm", { 0.38, 0.08, 0.08 }, { 0.12, 0, 1.22 }, "#9a6234")
	local bulb = Models.ball(m, "bulb", 0.2, { 0.27, 0, 1.0 }, "#ffcf7a", { 1, 1, 1.25 })
	bulb.Material = Enum.Material.Neon
	Models.box(m, "lid", { 0.2, 0.2, 0.05 }, { 0.27, 0, 1.25 }, "#5a3a22")
	Models.box(m, "string", { 0.02, 0.02, 0.08 }, { 0.27, 0, 1.19 }, "#5a3a22")
	local light = Instance.new("PointLight"); light.Color = Color3.fromHex("#ffc98a"); light.Range = 2.6 * S; light.Brightness = 0.45; light.Shadows = false   -- Future lighting: keep pools small + soft
	light.Parent = bulb
	return m
end

-- pivot every model at its base (feet) point
function Models.place(m: Model, pos: Vector3, yaw: number?): Model
	m.WorldPivot = CFrame.new()
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0))
	return m
end

return Models
