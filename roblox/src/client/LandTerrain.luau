--!nonstrict
-- LandTerrain: the island ground as Roblox Terrain (owner 2026-10-09: "real terrain, just like the water").
-- One 4x4-stud column per map tile (tiles sit on the 4-stud voxel grid), smooth tops from partial occupancy:
--   surface voxel layer = the tile's material (grass / path / sand / rock / snow ...), then a soil layer, then rock
--   down to the sea bed; coast columns get sand under the turf so beaches show where the land meets the water.
-- Ponds are Terrain water on a sand bed. Colours follow the World Guide palette (SetMaterialColor is global).
local Terrain = workspace.Terrain
local LandTerrain = {}

local M = Enum.Material
local BED = -40          -- sea bed: columns reach down to it so cliffs continue under the clear water
local WATER_TOP = -12    -- Ocean's terrain sea level (Ocean.CLIFF studs under the grass: islands are raised plates)

-- cel look: every terrain material is overridden by a flat MaterialVariant (a plain white map, so the colour is
-- exactly SetMaterialColor), hard shadows come from Lighting. No grass blades (Workspace.Terrain.Decoration off).
-- Valheim / The Forest look (owner 2026-10-09): Roblox's realistic materials (no flat overrides), natural earthy
-- tones, grass blades on (Terrain.Decoration in the project). The Flat* MaterialVariants stay in the place but are
-- not applied.
-- Painted storybook look (owner 2026-10-09, art direction locked): every terrain material uses a hand-painted
-- MaterialVariant authored in default.project.json MaterialService (Painted<Material>, tiles in assets/terrain/).
-- Material colours stay near white so the painted texture shows its own colours.
-- Toon flat colour blocking (owner 2026-10-09, 2.5D handheld-RPG / Wind Waker / Tokyo 42 look): every terrain
-- material uses Flat<Material> (plain white map, project MaterialService) so the colour is exactly this palette;
-- light / dark grass patches, dry meadow, path, sand and cliff rock read as clean colour blocks.
local FLAT = { [M.Grass] = "7cc24a", [M.LeafyGrass] = "5aa83c", [M.Pavement] = "9ccf55", [M.Ground] = "e2b878",
	[M.Sand] = "f0dca0", [M.Rock] = "a8743f", [M.Mud] = "8a5a32", [M.Slate] = "7a4f2c", [M.Salt] = "c9c6f0",
	[M.Basalt] = "5a5560", [M.Cobblestone] = "b9b2a6", [M.Sandstone] = "e6c27a", [M.Snow] = "f4f8ff" }
function LandTerrain.setup()
	local MS = game:GetService("MaterialService")
	for mat, col in FLAT do
		Terrain:SetMaterialColor(mat, Color3.fromHex(col))
		local v = if MS:FindFirstChild("Flat" .. mat.Name) then "Flat" .. mat.Name elseif MS:FindFirstChild("Painted" .. mat.Name) then "Painted" .. mat.Name else nil
		if v then pcall(function() MS:SetBaseMaterialOverride(mat, v) end) end
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

-- ---------------------------------------------------------------- smooth landforms (art pass, 2026-10-09)
-- Visual height of a tile (studs). Walkable tiles sit exactly on World.base; the 3 tiles at the foot of a higher
-- terrace become a rocky slope up to it (Controller treats that band as a wall), hills become rolling mounds, and
-- shore tiles dip into the sea. Columns are written with WriteVoxels and fractional top occupancy, so the surface
-- is smooth instead of 4-stud steps.
local World = require(game:GetService("ReplicatedStorage"):WaitForChild("Peckwood"):WaitForChild("World"))
local COLS, ROWS = 40, 30
local function tileOf(x0, z0) return math.floor(x0 / 4 + 0.5) + COLS / 2, math.floor(z0 / 4 + 0.5) + ROWS / 2 end
local function landAt(i, j) return World.rawTile(i, j) ~= 0 end
local function smoothstep(t) t = math.clamp(t, 0, 1); return t * t * (3 - 2 * t) end
-- distance (tiles, <= 3) to the nearest tile whose terrace is clearly higher, and that terrace's base
local function cliffAbove(i, j, base)
	local best, bb
	for dj = -3, 3 do
		for di = -3, 3 do
			local d = math.sqrt(di * di + dj * dj)
			if d > 0 and d <= 3.2 and landAt(i + di, j + dj) then
				local b = World.base(i + di, j + dj)
				if b > base + 3 and (not best or d < best) then best, bb = d, b end
			end
		end
	end
	return best, bb
end
LandTerrain.cliffAbove = cliffAbove
local function hillAvg(i, j)
	local s, n = 0, 0
	for dj = -1, 1 do for di = -1, 1 do s += World.height(i + di, j + dj); n += 1 end end
	return s / n
end
function LandTerrain.visualTop(i, j, top, code)
	local base = World.base(i, j)
	local y = top + World.relief(i + 0.5, j + 0.5)
	local d, ub = nil, nil
	if code ~= 2 then d, ub = cliffAbove(i, j, base) end   -- trail ramps stay on their own height
	if d then
		-- rocky slope rising to the upper terrace's edge (bumpy so it reads as natural rock)
		local k = smoothstep(1 - (d - 1) / 2.4)
		y = math.max(y, base + (ub - base) * k * (0.92 + math.noise(i * 0.31, j * 0.31, 4.2) * 0.12))
	end
	local h = World.height(i, j)
	if h > 0 then y = base + hillAvg(i, j) * 3.2 + math.noise(i * 0.2, j * 0.2, 9) * 1.5 end
	-- pond banks: land within ~2 tiles of a pond slopes gently down to the water (rounded natural edge, not a pit)
	if code ~= 3 then
		local best = math.huge
		for dj = -3, 3 do for di = -3, 3 do
			if World.rawTile(i + di, j + dj) == 3 then best = math.min(best, math.sqrt(di * di + dj * dj) + math.noise(i * 0.4, j * 0.4, 2) * 0.8) end
		end end
		-- the first ring dips below the waterline, so the shore follows this rounded slope instead of the square tiles
		-- (not next to the sea: there the cliff lip sits flush with the turf, so a dipped bank would show a gap under it)
		local nearSea = false
		for dj = -2, 2 do for di = -2, 2 do if not landAt(i + di, j + dj) then nearSea = true end end end
		if false and best < 3.2 and not nearSea then y = math.min(y, top - (1 - math.clamp((best - 0.8) / 2.4, 0, 1)) ^ 1.3 * 5) end
	end
	-- (no shore dip any more: the coast is a cliff skirt with a grass lip flush with the turf, Ocean.buildSkirt)
	return y, d ~= nil, h > 0
end

local function column(x0, z0, yTop, layers)
	-- layers: { {fromY, mat}, ... } top-down; everything from BED to yTop
	local top = math.max(BED + 1, yTop)
	local y0 = BED
	local n = math.ceil((top - y0) / 4)
	local mats, occ = table.create(1), table.create(1)
	mats[1], occ[1] = { }, { }
	for k = 1, n do
		local vy0 = y0 + (k - 1) * 4
		local fill = math.clamp((top - vy0) / 4, 0, 1)
		local m = layers[#layers][2]
		for _, L in layers do if vy0 + 2 >= L[1] then m = L[2]; break end end
		mats[1][k] = { m }; occ[1][k] = { fill }
	end
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + 4, y0 + n * 4, z0 + 4))
	Terrain:WriteVoxels(region, 4, mats, occ)
end

-- fill one tile column: x0/z0 = tile corner (studs), top = surface y, mat = surface material, shore = touches sea.
local function snap(y) return math.floor(y / 4 + 0.5) * 4 end
function LandTerrain.column(x0, z0, top, mat, code, shore)
	local i, j = tileOf(x0, z0)
	if code == 3 then   -- pond / river: sand bed, water on top (at its terrace height)
		local wt = math.max(0, snap(top)) - 4   -- one voxel below the land, so the water can't spill over the banks
		block(x0, z0, BED, wt - 4, M.Mud)   -- dark bed so ponds read blue, not pale
		-- a ball of water per tile: neighbouring balls merge into a rounded natural shoreline instead of a square
		Terrain:FillBall(Vector3.new(x0 + 2, wt - 1.5, z0 + 2), 3.1, M.Water)
		-- flood the dipped bank too: water up to the pond level wherever the bank is lower (air only)
		local r = Region3.new(Vector3.new(x0 - 6, wt - 4, z0 - 6), Vector3.new(x0 + 10, wt, z0 + 10)):ExpandToGrid(4)
		Terrain:ReplaceMaterial(r, 4, M.Air, M.Water)
		return
	end
	local y, cliff, hill = LandTerrain.visualTop(i, j, math.max(0, top), code)
	-- toon colour blocking (owner 2026-10-09: the random lighter "yellow" patches looked messy): grass is ONE clean
	-- colour; variety comes from placed props (tall grass, flowers, paths), not from noise patches
	-- cliff slopes show rock (snow way up high); hills stay grassy mounds, capped with snow on the summit
	if cliff and y - World.base(i, j) > 2 then mat = if y > 76 then M.Snow else M.Rock
	elseif hill and y > 86 then mat = M.Snow end
	local under = if mat == M.Snow or mat == M.Rock or mat == M.Slate then M.Slate elseif mat == M.Sand then M.Sand else M.Mud
	-- the top two voxels carry the surface material: with a fractional top voxel the one below is what you see
	-- WriteVoxels: a full voxel's rendered surface sits ~2 studs above its top (measured in Play: logic ground 0,
	-- terrain surface 2.0), so write 2 studs lower to put the visible ground exactly where the bird / eggs / props stand
	local yv = y - 2.5   -- measured: -2 -> surface +1.0, -3 -> -1.0
	-- island edge (target B): a grass lip, a thin soil band, then the rock cliff face down to the sea bed
	column(x0, z0, yv, { { yv - 5, mat }, { yv - 9, under }, { -math.huge, M.Rock } })
end

-- remove a column (area locked again): back to sea water up to sea level
function LandTerrain.clear(x0, z0)
	Terrain:FillBlock(CFrame.new(x0 + 2, 60, z0 + 2), Vector3.new(4, 128, 4), M.Air)   -- up past the summit
	block(x0, z0, WATER_TOP - 4, WATER_TOP, M.Water)
	block(x0, z0, BED, WATER_TOP - 4, M.Air)
end

return LandTerrain
