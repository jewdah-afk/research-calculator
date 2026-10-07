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

-- the Park is drawn on each client (client/IslandView: EditableMesh LEGO); movement/collision use MapData in Controller.
-- The server keeps an empty "Island" folder so anything waiting on it still resolves.
function Island.build(): Folder
	local root = Instance.new("Folder"); root.Name = "Island"
	root.Parent = workspace
	return root
end

return Island
