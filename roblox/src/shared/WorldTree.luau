--!strict
-- WorldTree: the one map hierarchy (spec: MAP_HIERARCHY.md in the repo root). Client only.
-- Every map module parents into this tree; nothing map-related goes straight into workspace.
--
--   workspace.World
--     Sky          backdrop: Clouds, Far (horizon islets). Hazy, desaturated, never outlined, no shadows.
--     Sea          Ocean.luau: surface, far sea, waves, shelf, sea life, cliff skirt.
--     Islands      one Model per area (park, garden, ...), each with the same layer folders (LAYERS below).
--     Actors       hen, eggs, companions, their blob shadows: the focus tier (ink outline, brightest values).
--     Atmosphere   world-wide ambience: wind/pollen emitters, fireflies, build-in dust.
--     Vfx          transient effects (Vfx engine roots).
--
-- Visual hierarchy, highest first (what the eye must find first in every frame):
--   1 Actors > 2 Interactables > 3 Landmarks > 4 Props / paths > 5 Foliage / Rocks > 6 Ground > 7 Sea / Sky.
-- The layer an object lives in decides its render rules (RULES below), so placing it right is the whole job.
local WorldTree = {}

WorldTree.TOP = { "Sky", "Sea", "Islands", "Actors", "Atmosphere", "Vfx" }

-- per-island layers, in build / read order
WorldTree.LAYERS = { "Ground", "Landmarks", "Interactables", "Props", "Foliage", "Rocks", "Life", "FX" }

-- Render rules per layer (enforced by the builders; QA checks them, see MAP_HIERARCHY.md section 4).
--   tier:   visual hierarchy rank (1 = read first)
--   shadow: may cast shadows (small parts never do, see SHADOW_MIN)
--   sway:   tagged for the wind (CollectionService tag "Sway")
--   studs:  subtle stud texture allowed (owner decision C: man-made only, never nature)
WorldTree.RULES = {
	Ground        = { tier = 6, shadow = false, sway = false, studs = false },
	Landmarks     = { tier = 3, shadow = true,  sway = false, studs = true },
	Interactables = { tier = 2, shadow = true,  sway = false, studs = true },
	Props         = { tier = 4, shadow = true,  sway = false, studs = true },
	Foliage       = { tier = 5, shadow = true,  sway = true,  studs = false },
	Rocks         = { tier = 5, shadow = true,  sway = false, studs = false },
	Life          = { tier = 5, shadow = false, sway = false, studs = false },
	FX            = { tier = 4, shadow = false, sway = false, studs = false },
}
WorldTree.SHADOW_MIN = 0.6   -- parts thinner than this (studs) never cast shadows

-- Every prop kind in MapData / IslandData -> its layer. A kind missing here lands in Props and is reported by
-- WorldTree.unknownKinds() (QA), so a new kind can't silently break the hierarchy.
local LAYER_OF: { [string]: string } = {
	-- Landmarks: one hero per island, the silhouette you remember the area by
	lighthouse = "Landmarks", cottage = "Landmarks", keep = "Landmarks", temple = "Landmarks", pyramid = "Landmarks",
	tower = "Landmarks", greenhouse = "Landmarks", mineentrance = "Landmarks", hut = "Landmarks", altar = "Landmarks",
	arch = "Landmarks", bell = "Landmarks", balloon = "Landmarks", windmill = "Landmarks", cart = "Landmarks",
	-- Interactables: gameplay objects the player walks up to
	goldbird = "Interactables", monster = "Interactables", nesttree = "Interactables", tank = "Interactables",
	-- Props: small man-made pieces (paths and walkable structures included)
	lantern = "Props", bench = "Props", barrel = "Props", fence = "Props", wall = "Props", pillar = "Props",
	post = "Props", banner = "Props", rod = "Props", tent = "Props", scarecrow = "Props", birdhouse = "Props",
	minecart = "Props", rails = "Props", pier = "Props", footbridge = "Props", boat = "Props", yardfence = "Props",
	-- Foliage: everything that grows (sways in the wind)
	tree = "Foliage", oak = "Foliage", bigoak = "Foliage", pine = "Foliage", palm = "Foliage", deadtree = "Foliage",
	bush = "Foliage", flowers = "Foliage", sunflower = "Foliage", vine = "Foliage", cactus = "Foliage",
	mushroom = "Foliage",
	-- Rocks: still nature dressing
	rock = "Rocks", ore = "Rocks", crystal = "Rocks", monolith = "Rocks", bones = "Rocks", log = "Rocks", twigs = "Rocks",
}
WorldTree.LAYER_OF = LAYER_OF

local unknown: { [string]: boolean } = {}
function WorldTree.layerOf(kind: string): string
	local l = LAYER_OF[kind]
	if l then return l end
	unknown[kind] = true
	return "Props"
end
function WorldTree.unknownKinds(): { string }
	local out = {}
	for k in unknown do table.insert(out, k) end
	table.sort(out)
	return out
end

local function child(parent: Instance, name: string, class: string): Instance
	local c = parent:FindFirstChild(name)
	if c and c.ClassName == class then return c end
	local n = Instance.new(class)
	n.Name = name
	n.Parent = parent
	return n
end

function WorldTree.root(): Folder
	local r = child(workspace, "World", "Folder") :: Folder
	for _, name in WorldTree.TOP do child(r, name, "Folder") end
	return r
end

-- a top-level folder: WorldTree.get("Sky"), WorldTree.get("Actors"), ...
function WorldTree.get(name: string): Folder
	assert(table.find(WorldTree.TOP, name), "WorldTree: no top-level folder " .. name)
	return WorldTree.root():FindFirstChild(name) :: Folder
end

-- a fresh island Model with every layer folder, NOT parented (the caller parents it so it appears in one frame and
-- can be culled by unparenting). Use WorldTree.mount(m) to parent it under Islands.
function WorldTree.newIsland(id: string): Model
	local m = Instance.new("Model")
	m.Name = id
	for _, l in WorldTree.LAYERS do child(m, l, "Folder") end
	return m
end
function WorldTree.mount(island: Model) island.Parent = WorldTree.get("Islands") end

-- an island's layer folder: WorldTree.layer(isl, "Foliage")
function WorldTree.layer(island: Instance, layer: string): Folder
	assert(WorldTree.RULES[layer], "WorldTree: no layer " .. layer)
	return child(island, layer, "Folder") :: Folder
end
-- the layer folder a prop kind belongs in
function WorldTree.layerFor(island: Instance, kind: string): Folder
	return WorldTree.layer(island, WorldTree.layerOf(kind))
end

-- QA: walk the tree and report every rule break as a string (empty = clean). Run from the Studio command bar:
--   print(table.concat(require(game.ReplicatedStorage.Peckwood.WorldTree).audit(), "\n"))
function WorldTree.audit(): { string }
	local out = {}
	local r = workspace:FindFirstChild("World")
	if not r then return { "no workspace.World" } end
	for _, c in workspace:GetChildren() do
		-- allowed at the top: World, Terrain, the camera, characters, the server's empty Island folder
		if c == r or c:IsA("Terrain") or c:IsA("Camera") or c.Name == "Island" or c:FindFirstChildOfClass("Humanoid") then continue end
		table.insert(out, "loose in workspace: " .. c.Name .. " (" .. c.ClassName .. ")")
	end
	for _, name in WorldTree.TOP do
		if not r:FindFirstChild(name) then table.insert(out, "missing World." .. name) end
	end
	local islands = r:FindFirstChild("Islands")
	for _, isl in if islands then islands:GetChildren() else {} do
		for _, l in isl:GetChildren() do
			local rule = WorldTree.RULES[l.Name]
			if not rule then table.insert(out, "not a layer: " .. l:GetFullName()); continue end
			for _, d in l:GetDescendants() do
				if d:IsA("BasePart") and d.CastShadow then
					if not rule.shadow then table.insert(out, "shadow in " .. l.Name .. ": " .. d:GetFullName())
					elseif math.min(d.Size.X, d.Size.Y, d.Size.Z) < WorldTree.SHADOW_MIN and d.Transparency < 1 then
						table.insert(out, "thin part casts shadow: " .. d:GetFullName())
					end
				end
			end
		end
	end
	for _, k in WorldTree.unknownKinds() do table.insert(out, "prop kind with no layer: " .. k) end
	return out
end

return WorldTree
