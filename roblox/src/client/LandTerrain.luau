--!nonstrict
-- LandTerrain: the island ground as Roblox Terrain (owner 2026-10-09: "real terrain, just like the water").
-- One 4x4-stud column per map tile (tiles sit on the 4-stud voxel grid), smooth tops from partial occupancy:
--   surface voxel layer = the tile's material (grass / path / sand / rock / snow ...), then a soil layer, then rock
--   down to the sea bed; coast columns get sand under the turf so beaches show where the land meets the water.
-- Ponds are Terrain water on a sand bed. Colours follow the World Guide palette (SetMaterialColor is global).
local Terrain = workspace.Terrain
local LandTerrain = {}

local M = Enum.Material
local BED = -24          -- sea bed: columns reach down to it so cliffs continue under the clear water
local WATER_TOP = -4     -- Ocean's terrain sea level (one voxel under the grass)

-- cel look: every terrain material is overridden by a flat MaterialVariant (a plain white map, so the colour is
-- exactly SetMaterialColor), hard shadows come from Lighting. No grass blades (Workspace.Terrain.Decoration off).
function LandTerrain.setup()
	local MS = game:GetService("MaterialService")
	for mat, hex in {
		-- 3DS-Pokemon (X/Y) palette: lively, clean, warm; one flat colour per material
		[M.Grass] = "7cc35a", [M.LeafyGrass] = "58a548", [M.Ground] = "d8bf8a", [M.Mud] = "9a7454", [M.Pavement] = "a9c86a",
		[M.Sand] = "f0e1a9", [M.Sandstone] = "e6cf92", [M.Rock] = "a39d90", [M.Slate] = "8a8478",
		[M.Cobblestone] = "c4bdb0", [M.Snow] = "f6f8fc", [M.Salt] = "8c96dc", [M.Basalt] = "9a7454",
	} do
		Terrain:SetMaterialColor(mat, Color3.fromHex(hex))
		-- the Flat* MaterialVariants are authored in the place (default.project.json, MaterialService): game scripts
		-- may not create them; here we only point each base material at its flat variant
		if MS:FindFirstChild("Flat" .. mat.Name) then pcall(function() MS:SetBaseMaterialOverride(mat, "Flat" .. mat.Name) end) end
	end
end

-- surface material for a tile: code 1 grass, 2 path, 3 water, 4 the area's "alt" ground
local ALT = { garden = M.Mud, castle = M.Cobblestone, bridge = M.Sand, forest = M.LeafyGrass, mine = M.Rock,
	desert = M.Sand, expedition = M.LeafyGrass, echo = M.Salt }
local GRASS = { forest = M.LeafyGrass, expedition = M.LeafyGrass, echo = M.Salt, desert = M.Sandstone }
local function baseId(isl) return (isl.area or isl.id):gsub("^region:", "") end
function LandTerrain.surface(isl, code, h)
	local id = if isl then baseId(isl) else "park"
	if code == 2 then return M.Ground end
	if code == 3 then return M.Sand end
	if code == 4 then
		if isl and isl.join then   -- highland peaks: rock, snow on the top levels
			if h >= 5 then return M.Snow end
			if h >= 2 then return M.Rock end
		end
		return ALT[id] or M.Rock
	end
	if id == "desert" and code == 1 then return M.Grass end
	return GRASS[id] or M.Grass
end

local function block(x0, z0, y0, y1, mat)
	if y1 <= y0 then return end
	Terrain:FillBlock(CFrame.new(x0 + 2, (y0 + y1) / 2, z0 + 2), Vector3.new(4, y1 - y0, 4), mat)
end

-- fill one tile column: x0/z0 = tile corner (studs), top = surface y, mat = surface material, shore = touches sea.
-- Everything snaps to whole voxels (4 studs): flat ground stays flat, hills step in clean voxel terraces, and no
-- layer boundary sits mid-voxel (partial occupancy is what made the surface lumpy).
local function snap(y) return math.floor(y / 4 + 0.5) * 4 end
function LandTerrain.column(x0, z0, top, mat, code, shore)
	if code == 3 then   -- pond / river: sand bed one voxel down, water on top (at its terrace height)
		local wt = math.max(0, snap(top))
		block(x0, z0, BED, wt - 4, M.Sand)
		block(x0, z0, wt - 4, wt, M.Water)
		return
	end
	local t = math.max(0, snap(top))
	-- natural variation on grass: sandy beaches on the coast, then smooth noise patches of lush grass, dry meadow
	-- and bare dirt (each a flat cel colour), so the land reads like generated terrain, not one green sheet
	if mat == M.Grass or mat == M.LeafyGrass then
		local i, j = x0 / 4, z0 / 4
		local n1 = math.noise(i * 0.07, j * 0.07, 3.1)
		local n2 = math.noise(i * 0.19 + 40, j * 0.19, 7.7)
		if shore and t == 0 then mat = M.Sand
		elseif n2 > 0.42 then mat = M.Ground
		elseif n1 > 0.22 then mat = M.LeafyGrass
		elseif n1 < -0.28 then mat = M.Pavement   -- dry meadow tone (flat override, coloured olive)
		end
	end
	local under = if mat == M.Snow or mat == M.Rock or mat == M.Slate then M.Slate elseif t > 0 then M.Rock elseif shore then M.Sand else M.Basalt
	block(x0, z0, BED, WATER_TOP - 4, M.Rock)
	block(x0, z0, WATER_TOP - 4, t - 4, under)
	block(x0, z0, t - 4, t, mat)
end

-- remove a column (area locked again): back to sea water up to sea level
function LandTerrain.clear(x0, z0)
	Terrain:FillBlock(CFrame.new(x0 + 2, 60, z0 + 2), Vector3.new(4, 128, 4), M.Air)   -- up past the summit
	block(x0, z0, WATER_TOP - 4, WATER_TOP, M.Water)
	block(x0, z0, BED, WATER_TOP - 4, M.Air)
end

return LandTerrain
