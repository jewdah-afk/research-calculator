--!nonstrict
-- IslandView: the Park, drawn on the client as LEGO (approved concept: rc-main/concepts/park.html).
--   * ground = EditableMesh chunks (vertex-coloured bricks, only exposed faces, 10-sided studs on every grass top)
--   * every prop is ONE EditableMesh MeshPart built from bricks in LEGO units: footprints are whole studs and each
--     prop is snapped to the stud grid by its footprint parity, so its edges always sit on stud lines
--   * day cycle: 24 real minutes per day (1 min = 1 game hour), from server time so every player shares the sky
--   * IslandView.play(): the unlock build-in (rings rise from the centre, scenery drops with dust, camera swoop, toast)
-- Movement/collision stay in Controller (map data), so nothing here collides.
local RS = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Shared = RS:WaitForChild("Peckwood")
local Map = require(Shared:WaitForChild("MapData"))
local Models = require(Shared:WaitForChild("Models"))

local S = Models.S              -- 4 world studs per tile
local L = S / 2                 -- LEGO stud pitch (2 per tile)
local PLATE = 0.4 * L           -- LEGO plate height (0.4 pitch)
local BRICK = 3 * PLATE
local IslandView = { camCF = nil }

local C = {
	grassA = "8cc06a", grassB = "84b863", grassF = "95c870", path = "d9bf91", pathB = "cfb487", sand = "e8d9ad",
	topsoil = "5f4532", soil = "8b6a4e", soilD = "6e533e", rock = "8d8478", rockD = "746c62",
	bark = "7a5638", leafA = "6fa553", leafB = "7fb35e", leafC = "8fc46a", pineA = "5d9a4c", pineB = "67a656",
	stone = "b9b2a6", stoneB = "a9a296", stoneL = "c9c2b4", gold = "ffd27a", metal = "3d3a40", wood = "9a6b42", woodD = "8b5a2e",
	cart = "c9a06a", cream = "fff1c8", red = "e0503c", white = "f3eee2", mill = "e9e2d2", millB = "d8d0be", roof = "b5574a", roofD = "a04a3e",
}
local colCache = {}
local function hx(h) local c = colCache[h]; if not c then c = Color3.fromHex(h); colCache[h] = c end; return c end
local function hash(i, j) local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453; return n - math.floor(n) end
local function vary(c: Color3, d: number) local h, s, v = c:ToHSV(); return Color3.fromHSV(h, s, math.clamp(v + d, 0, 1)) end

-- ---------------------------------------------------------------- mesh builder (geometry first, emitted centred)
local MAX_TRIS = 19500
local MAX_VERTS = 58000
local Builder = {}
Builder.__index = Builder
function Builder.new() return setmetatable({ v = {}, t = {}, tris = 0 }, Builder) end
function Builder:vert(p: Vector3) table.insert(self.v, p); return #self.v end
-- triangle a,b,c counter-clockwise seen from outside (verified: Roblox front faces use this order as given)
function Builder:tri(a, b, c, col) table.insert(self.t, { a, b, c, col }); self.tris += 1 end
function Builder:quad(a, b, c, d, col)
	local ia, ib, ic, id = self:vert(a), self:vert(b), self:vert(c), self:vert(d)
	self:tri(ia, ib, ic, col); self:tri(ia, ic, id, col)
end
function Builder:full() return self.tris > MAX_TRIS or #self.v > MAX_VERTS end
local SIDE, BOTTOM = 0.86, 0.7
function Builder:box(p: Vector3, s: Vector3, col: Color3, skip)
	local x0, y0, z0 = p.X, p.Y, p.Z
	local x1, y1, z1 = x0 + s.X, y0 + s.Y, z0 + s.Z
	skip = skip or {}
	local side = vary(col, -0.06)
	if not skip.top then self:quad(Vector3.new(x0, y1, z0), Vector3.new(x0, y1, z1), Vector3.new(x1, y1, z1), Vector3.new(x1, y1, z0), col) end
	if not skip.bottom then self:quad(Vector3.new(x0, y0, z0), Vector3.new(x1, y0, z0), Vector3.new(x1, y0, z1), Vector3.new(x0, y0, z1), col:Lerp(Color3.new(), 1 - BOTTOM)) end
	if not skip.px then self:quad(Vector3.new(x1, y0, z0), Vector3.new(x1, y1, z0), Vector3.new(x1, y1, z1), Vector3.new(x1, y0, z1), side:Lerp(Color3.new(), 1 - SIDE)) end
	if not skip.nx then self:quad(Vector3.new(x0, y0, z1), Vector3.new(x0, y1, z1), Vector3.new(x0, y1, z0), Vector3.new(x0, y0, z0), side:Lerp(Color3.new(), 1 - SIDE)) end
	if not skip.pz then self:quad(Vector3.new(x1, y0, z1), Vector3.new(x1, y1, z1), Vector3.new(x0, y1, z1), Vector3.new(x0, y0, z1), side) end
	if not skip.nz then self:quad(Vector3.new(x0, y0, z0), Vector3.new(x0, y1, z0), Vector3.new(x1, y1, z0), Vector3.new(x1, y0, z0), side) end
end
-- LEGO stud: 10-sided, shared rings (smooth sides), flat top fan: 21 verts, 30 tris
local STUD_R, STUD_H, SEG = 0.3 * L, 0.17 * L, 10
local ring = {}
for k = 0, SEG - 1 do local a = k / SEG * math.pi * 2; ring[k + 1] = Vector2.new(math.cos(a), math.sin(a)) end
function Builder:stud(cx, y, cz, col: Color3)
	local top = vary(col, 0.035)
	local side = col:Lerp(Color3.new(), 0.1)
	local lo, hi, cap = {}, {}, {}
	for k = 1, SEG do
		local r = ring[k]
		lo[k] = self:vert(Vector3.new(cx + r.X * STUD_R, y, cz + r.Y * STUD_R))
		hi[k] = self:vert(Vector3.new(cx + r.X * STUD_R, y + STUD_H, cz + r.Y * STUD_R))
	end
	for k = 1, SEG do
		local n = k % SEG + 1
		self:tri(lo[k], hi[k], hi[n], side); self:tri(lo[k], hi[n], lo[n], side)
	end
	local c = self:vert(Vector3.new(cx, y + STUD_H, cz))
	for k = 1, SEG do cap[k] = self:vert(Vector3.new(cx + ring[k].X * STUD_R, y + STUD_H, cz + ring[k].Y * STUD_R)) end
	for k = 1, SEG do self:tri(c, cap[k % SEG + 1], cap[k], top) end
end
function Builder:emit(parent: Instance, name: string): MeshPart?
	if #self.t == 0 then return nil end
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, v in self.v do mn = mn:Min(v); mx = mx:Max(v) end
	local c = (mn + mx) / 2
	local ok, em = pcall(function() return AssetService:CreateEditableMesh({}) end)
	if not ok or not em then warn("[IslandView] EditableMesh budget: " .. tostring(em)); return nil end
	local ids = table.create(#self.v)
	for k, v in self.v do ids[k] = em:AddVertex(v - c) end
	local colors = {}
	for _, t in self.t do
		local key = t[4]:ToHex()
		local cid = colors[key]
		if not cid then cid = em:AddColor(t[4], 1); colors[key] = cid end
		local f = em:AddTriangle(ids[t[1]], ids[t[2]], ids[t[3]])
		em:SetFaceColors(f, { cid, cid, cid })
	end
	local ok2, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok2 or not mp then warn("[IslandView] CreateMeshPartAsync failed: " .. tostring(mp)); em:Destroy(); return nil end
	-- keep `em` alive: the MeshPart renders from it (destroying it blanks the mesh)
	IslandView.meshes = IslandView.meshes or {}
	table.insert(IslandView.meshes, em)
	mp.Name = name; mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false
	mp.Material = Enum.Material.SmoothPlastic; mp.Color = Color3.new(1, 1, 1)
	mp.CFrame = CFrame.new(c)
	mp.Parent = parent
	return mp
end

-- part bricks for props / clouds / sails (EditableMesh budget is kept for the ground)
local function brickPart(parent: Instance, p: Vector3, s: Vector3, col: Color3, material)
	local b = Instance.new("Part")
	b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false
	b.TopSurface = Enum.SurfaceType.Smooth; b.BottomSurface = Enum.SurfaceType.Smooth
	b.Material = material or Enum.Material.SmoothPlastic; b.Color = col
	b.Size = s; b.CFrame = CFrame.new(p + s / 2); b.Parent = parent
	return b
end

-- ---------------------------------------------------------------- tiles
local COLS, ROWS = Map.COLS, Map.ROWS
local function tile(i, j) return Map.tile(i, j) end
local function land(i, j) return tile(i, j) ~= 0 end
local function x0Of(i) return (i - COLS / 2) * S end
local function z0Of(j) return (j - ROWS / 2) * S end
-- top surface y of a tile column (grass top = 0, hill levels add bricks, path sits a plate lower, water bed lower)
local function topY(i, j)
	local t = tile(i, j)
	if t == 0 then return -math.huge end
	if t == 2 then return -0.5 * PLATE end
	if t == 3 then return -2 * PLATE end
	return Map.height(i, j) * BRICK
end
local edgeCache = {}
local function edgeDist(i, j)
	local key = i * 100 + j
	if edgeCache[key] then return edgeCache[key] end
	local d = 0
	for r = 1, 7 do
		local ok = true
		for a = -r, r do
			for b = -r, r do
				if (math.abs(a) == r or math.abs(b) == r) and not land(i + a, j + b) then ok = false; break end
			end
			if not ok then break end
		end
		if not ok then break end
		d = r
	end
	edgeCache[key] = d
	return d
end
local function depthOf(i, j)   -- underside brick layers below the top plate
	if not land(i, j) then return 0 end
	return math.min(7, 1 + math.floor(edgeDist(i, j) * 1.15) + math.floor(hash(i, j) * 2.2))
end
local function inField(i, j) return i >= 12 and i <= 27 and j >= 10 and j <= 19 end

local function buildColumn(b, i, j)
	local t = tile(i, j)
	local x0, z0 = x0Of(i), z0Of(j)
	local n = hash(i, j)
	local ty = topY(i, j)
	local function nTop(di, dj) return if land(i + di, j + dj) then topY(i + di, j + dj) else -math.huge end
	-- top plate (+ hill bricks under it)
	local col
	if t == 1 then
		local base = if inField(i, j) then (if (i + j) % 2 == 1 then C.grassF else C.grassA) else (if (i + j) % 2 == 1 then C.grassA else C.grassB)
		col = vary(hx(base), (n - 0.5) * 0.03)
	elseif t == 2 then col = vary(hx(if n > 0.5 then C.path else C.pathB), (n - 0.5) * 0.03)
	else col = hx(C.sand) end
	local plateBottom = ty - PLATE
	-- side faces only where the neighbour's top is lower than this one (otherwise hidden)
	local function sideSkip(y)
		return { bottom = true, px = nTop(1, 0) >= y, nx = nTop(-1, 0) >= y, pz = nTop(0, 1) >= y, nz = nTop(0, -1) >= y }
	end
	b:box(Vector3.new(x0, plateBottom, z0), Vector3.new(S, PLATE, S), col, sideSkip(ty))
	if t == 1 then
		local studCol = vary(col, 0.012)
		for _, o in { { 0.25, 0.25 }, { 0.75, 0.25 }, { 0.25, 0.75 }, { 0.75, 0.75 } } do b:stud(x0 + o[1] * S, ty, z0 + o[2] * S, studCol) end
	end
	-- hill bricks between ground level and the top plate (earth bricks, alternating shade per course)
	local lv = if t == 1 then Map.height(i, j) else 0
	for k = lv, 1, -1 do
		local y1 = (k - 1) * BRICK + (BRICK - PLATE) * 0   -- course k spans [(k-1)*BRICK, k*BRICK - PLATE] under the top plate
		local yTop = if k == lv then ty - PLATE else k * BRICK
		local y0 = if k == 1 then -PLATE else (k - 1) * BRICK   -- first course also fills the ground plate band
		local h = yTop - y0
		local cc = vary(hx(if k % 2 == 1 then C.soil else C.soilD), (hash(i + k, j) - 0.5) * 0.05)
		b:box(Vector3.new(x0, y0, z0), Vector3.new(S, h, S), cc,
			{ top = true, bottom = true, px = nTop(1, 0) >= yTop, nx = nTop(-1, 0) >= yTop, pz = nTop(0, 1) >= yTop, nz = nTop(0, -1) >= yTop })
		local _ = y1
	end
	-- underside courses: topsoil, then soil / rock; outer courses step inwards (ragged taper) where exposed
	local depth = depthOf(i, j)
	local top = math.min(plateBottom, -PLATE)
	if t == 2 then top = plateBottom end
	if t == 3 then top = plateBottom end
	-- fill the gap between the ground plane band and the top plate for low tiles (path/water) so no seam shows
	local yy = top
	for k = 1, depth do
		local h = BRICK
		local inset = if k > depth - 2 and depth > 2 then (k - (depth - 2)) * 0.25 * L else 0
		local cc
		if k == 1 then cc = hx(C.topsoil)
		elseif n > 0.82 and k > 2 then cc = hx(if k % 2 == 1 then C.rock else C.rockD)
		else cc = hx(if k % 2 == 1 then C.soil else C.soilD) end
		cc = vary(cc, (hash(i * 3 + k, j) - 0.5) * 0.05)
		local function hid(di, dj) return land(i + di, j + dj) and tile(i + di, j + dj) ~= 3 and depthOf(i + di, j + dj) >= k and inset == 0 end
		b:box(Vector3.new(x0 + inset, yy - h, z0 + inset), Vector3.new(S - 2 * inset, h, S - 2 * inset), cc,
			{ top = (k > 1 or t == 1) and inset == 0, bottom = k < depth, px = hid(1, 0), nx = hid(-1, 0), pz = hid(0, 1), nz = hid(0, -1) })
		yy -= h
	end
end

-- ---------------------------------------------------------------- props: bricks in LEGO units (x,z in studs L, y in plates)
-- each def: { w = footprint studs X, d = footprint studs Z, parts = { {x, z, y, w, d, h, colourKey}, ... } }
local function P(...) return { ... } end
local DEFS = {}
DEFS.oak = { w = 5, d = 5, parts = {
	P(2, 2, 0, 1, 1, 6, "bark"), P(0, 0, 6, 5, 5, 3, "leafA"), P(1, 1, 9, 3, 3, 3, "leafB"), P(2, 2, 12, 1, 1, 2, "leafC"),
	P(0, 2, 9, 1, 1, 1, "leafA"), P(4, 1, 9, 1, 1, 1, "leafA") } }
DEFS.bigoak = { w = 7, d = 7, parts = {
	P(3, 3, 0, 1, 1, 9, "bark"), P(2, 3, 0, 1, 1, 2, "bark"), P(0, 0, 9, 7, 7, 3, "leafA"), P(1, 1, 12, 5, 5, 3, "leafB"),
	P(2, 2, 15, 3, 3, 3, "leafC"), P(3, 3, 18, 1, 1, 2, "leafB"), P(0, 3, 12, 1, 1, 1, "leafA"), P(6, 2, 12, 1, 2, 1, "leafA") } }
DEFS.pine = { w = 5, d = 5, parts = {
	P(2, 2, 0, 1, 1, 3, "bark"), P(0, 0, 3, 5, 5, 2, "pineA"), P(1, 1, 5, 3, 3, 3, "pineB"), P(0.5, 0.5, 8, 4, 4, 2, "pineA"),
	P(1, 1, 10, 3, 3, 3, "pineB"), P(2, 2, 13, 1, 1, 4, "pineA") } }
DEFS.bush = { w = 3, d = 3, parts = { P(0, 0, 0, 3, 3, 2, "leafA"), P(1, 0, 2, 2, 2, 2, "leafB"), P(0, 2, 2, 1, 1, 1, "leafC") } }
DEFS.rock = { w = 3, d = 2, parts = { P(0, 0, 0, 3, 2, 2, "rock"), P(1, 0, 2, 2, 1, 2, "rockD"), P(0, 1, 2, 1, 1, 1, "rockD") } }
DEFS.lantern = { w = 1, d = 1, parts = {
	P(0, 0, 0, 1, 1, 1, "metal"), P(0.35, 0.35, 1, 0.3, 0.3, 7, "metal"), P(0, 0, 8, 1, 1, 0.5, "metal"),
	P(0, 0, 10.6, 1, 1, 0.5, "metal"), P(0.25, 0.25, 11.1, 0.5, 0.5, 0.6, "metal") }, glow = { 0.15, 0.15, 8.5, 0.7, 0.7, 2.1 } }
DEFS.arch = { w = 7, d = 2, parts = {
	P(0, 0, 0, 2, 2, 3, "stone"), P(0, 0, 3, 2, 2, 3, "stoneB"), P(0, 0, 6, 2, 2, 3, "stone"), P(0, 0, 9, 2, 2, 3, "stoneB"),
	P(5, 0, 0, 2, 2, 3, "stoneB"), P(5, 0, 3, 2, 2, 3, "stone"), P(5, 0, 6, 2, 2, 3, "stoneB"), P(5, 0, 9, 2, 2, 3, "stone"),
	P(0, 0, 12, 7, 2, 3, "stoneL"), P(1, 0, 15, 5, 2, 2, "stone"), P(2.5, 1.95, 12.6, 2, 0.1, 1.8, "gold") } }
DEFS.cart = { w = 5, d = 3, parts = {
	P(0.5, 0.2, 0, 1.2, 0.2, 3, "metal"), P(3.3, 0.2, 0, 1.2, 0.2, 3, "metal"), P(0.5, 2.6, 0, 1.2, 0.2, 3, "metal"), P(3.3, 2.6, 0, 1.2, 0.2, 3, "metal"),
	P(0, 0.4, 2, 5, 2.2, 3, "cart"), P(0, 0.3, 5, 5, 2.4, 0.5, "woodD"), P(0.5, 0.8, 5.5, 4, 1.4, 2, "cream"), P(1.5, 1, 7.5, 2, 1, 1, "cream"),
	P(0.1, 0.4, 5.5, 0.3, 0.3, 7, "woodD"), P(4.6, 0.4, 5.5, 0.3, 0.3, 7, "woodD"), P(0.1, 2.3, 5.5, 0.3, 0.3, 7, "woodD"), P(4.6, 2.3, 5.5, 0.3, 0.3, 7, "woodD"),
	P(0, 0, 12.5, 1, 3, 1, "red"), P(1, 0, 12.5, 1, 3, 1, "white"), P(2, 0, 12.5, 1, 3, 1, "red"), P(3, 0, 12.5, 1, 3, 1, "white"), P(4, 0, 12.5, 1, 3, 1, "red") } }
DEFS.bench = { w = 3, d = 1, parts = {
	P(0.2, 0.2, 0, 0.3, 0.6, 2, "metal"), P(2.5, 0.2, 0, 0.3, 0.6, 2, "metal"), P(0, 0, 2, 3, 1, 0.5, "wood"), P(0, 0.8, 2.5, 3, 0.2, 2.5, "wood") } }
DEFS.fence = { w = 4, d = 1, parts = {
	P(0.35, 0.35, 0, 0.3, 0.3, 3, "wood"), P(1.35, 0.35, 0, 0.3, 0.3, 3, "wood"), P(2.35, 0.35, 0, 0.3, 0.3, 3, "wood"), P(3.35, 0.35, 0, 0.3, 0.3, 3, "wood"),
	P(0, 0.4, 2, 4, 0.2, 0.5, "woodD"), P(0, 0.4, 0.9, 4, 0.2, 0.5, "woodD") } }
DEFS.windmill = { w = 5, d = 5, parts = {
	P(0, 0, 0, 5, 5, 6, "mill"), P(0.5, 0.5, 6, 4, 4, 6, "millB"), P(1, 1, 12, 3, 3, 4, "mill"), P(0.5, 0.5, 16, 4, 4, 2, "roof"),
	P(1, 1, 18, 3, 3, 2, "roofD"), P(2, 2, 20, 1, 1, 2, "roofD"), P(2, 4.95, 0, 1, 0.1, 4, "woodD"), P(2.2, 3.95, 13, 0.6, 1.2, 0.6, "woodD") } }
local FLOWER_COLS = { "f2c6d8", "fff1a8", "c9b6ff", "ffffff" }

-- world position helpers
local function pxToWorld(x, y) return (x / Map.PX - COLS / 2) * S, (y / Map.PX - ROWS / 2) * S end
-- snap a footprint (studs) to the LEGO grid: returns min corner (world) such that edges land on stud lines
local function snapCorner(cx, cz, w, d)
	return math.floor((cx - w * L / 2) / L + 0.5) * L, math.floor((cz - d * L / 2) / L + 0.5) * L
end
local function groundAtWorld(x, z)
	local i, j = math.floor(x / S + COLS / 2), math.floor(z / S + ROWS / 2)
	if not land(i, j) then return 0 end
	return math.max(0, topY(i, j))
end

local function buildProp(def, kind, cx, cz, parent, seed)
	local ox, oz = snapCorner(cx, cz, def.w, def.d)
	-- sit on the highest top under the footprint
	local base = 0
	for sx = 0, def.w - 1 do for sz = 0, def.d - 1 do base = math.max(base, groundAtWorld(ox + (sx + 0.5) * L, oz + (sz + 0.5) * L)) end end
	local m = Instance.new("Model"); m.Name = kind
	for k, p in def.parts do
		local col = vary(hx(C[p[7]]), (hash(seed + k, k) - 0.5) * 0.04)
		local b = brickPart(m, Vector3.new(ox + p[1] * L, base + p[3] * PLATE, oz + p[2] * L), Vector3.new(p[4] * L, p[6] * PLATE, p[5] * L), col)
		b.CastShadow = p[4] >= 0.5 or p[5] >= 0.5
	end
	local info = { model = m, kind = kind, base = base, ox = ox, oz = oz, x = ox + def.w * L / 2, z = oz + def.d * L / 2 }
	if def.glow then
		local g = def.glow
		local lamp = brickPart(m, Vector3.new(ox + g[1] * L, base + g[3] * PLATE, oz + g[2] * L), Vector3.new(g[4] * L, g[6] * PLATE, g[5] * L), hx("5a5048"), Enum.Material.Neon)
		lamp.Name = "Glow"; lamp.CastShadow = false
		local pl = Instance.new("PointLight"); pl.Color = hx("ffc56b"); pl.Range = 16; pl.Brightness = 0; pl.Shadows = false; pl.Parent = lamp
		info.glow = lamp; info.light = pl
	end
	m.WorldPivot = CFrame.new(info.x, base, info.z)
	m.Parent = parent
	info.home = m:GetPivot()
	return info
end

-- windmill sails: a part model turning about the hub (pivot = hub)
local function buildSails(parent, hub: Vector3)
	local m = Instance.new("Model"); m.Name = "Sails"
	for k = 0, 3 do
		local a = k * math.pi / 2
		local rot = CFrame.new(hub) * CFrame.Angles(0, 0, a)
		local spar = brickPart(m, Vector3.zero, Vector3.new(0.4 * L, 7.2, 0.25), hx(C.woodD)); spar.CFrame = rot * CFrame.new(0, 3.9, 0)
		local sail = brickPart(m, Vector3.zero, Vector3.new(1.4 * L, 5.6, 0.12), hx(C.white)); sail.CFrame = rot * CFrame.new(0.95 * L, 4.4, 0.08)
	end
	local hubP = brickPart(m, Vector3.zero, Vector3.new(L, L, 0.8), hx(C.woodD)); hubP.CFrame = CFrame.new(hub)
	m.WorldPivot = CFrame.new(hub)
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------- clouds + far islands (brick models)
local function buildCloud(parent, seed)
	local m = Instance.new("Model"); m.Name = "Cloud"
	local n = 3 + math.floor(hash(seed, 1) * 4)
	for q = 0, n - 1 do
		local w, h, d = (2 + math.floor(hash(seed, q) * 3)) * L, (1 + math.floor(hash(q, seed) * 2)) * BRICK, (2 + math.floor(hash(q, seed + 1) * 2)) * L
		local b = brickPart(m, Vector3.new(q * 1.5 * L - n * 0.75 * L, math.floor(hash(seed, q + 2) * 2) * PLATE, math.floor(hash(q, seed + 3) * 2) * L), Vector3.new(w, h, d), hx("ffffff"))
		b.CastShadow = false
	end
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------- build
local root, meshes, props, clouds, waterParts = nil, {}, {}, {}, {}
local lamps = {}
local fireflies, dustPart

function IslandView.build()
	if root then root:Destroy() end
	for _, em in IslandView.meshes or {} do em:Destroy() end
	IslandView.meshes = {}
	root = Instance.new("Folder"); root.Name = "IslandView"; root.Parent = workspace
	local groundF = Instance.new("Folder"); groundF.Name = "Ground"; groundF.Parent = root
	local scenery = Instance.new("Model"); scenery.Name = "Scenery"; scenery.Parent = root
	IslandView.scenery = scenery
	meshes, props, clouds, waterParts, lamps = {}, {}, {}, {}, {}
	-- ground: tiles ordered centre-out, packed into as few EditableMeshes as the tri limit allows (client budget is
	-- per mesh), so each mesh is one "band" the unlock raises in order
	local cx, cy = COLS / 2, ROWS / 2
	local order = {}
	for j = 0, ROWS - 1 do
		for i = 0, COLS - 1 do
			if land(i, j) then table.insert(order, { i, j, math.sqrt((i + 0.5 - cx) ^ 2 + ((j + 0.5 - cy) * 1.25) ^ 2) }) end
		end
	end
	table.sort(order, function(a, b) return a[3] < b[3] end)
	local b = Builder.new()
	local n = 0
	local function flush()
		local mp = b:emit(groundF, "Band" .. (#meshes + 1))
		if mp then mp.CastShadow = true; table.insert(meshes, { part = mp, home = mp.CFrame }) end
		b = Builder.new()
		task.wait()
	end
	for _, t in order do
		buildColumn(b, t[1], t[2])
		n += 1
		if b:full() then flush() end
	end
	flush()
	IslandView.stats = { bands = #meshes, tiles = n }
	-- water (pond + stream): translucent plate over the sand bed
	for j = 0, ROWS - 1 do
		for i = 0, COLS - 1 do
			if tile(i, j) == 3 then
				local w = brickPart(groundF, Vector3.new(x0Of(i), -2 * PLATE, z0Of(j)), Vector3.new(S, PLATE, S), hx("6fb7d8"), Enum.Material.Glass)
				w.Name = "Water"; w.Transparency = 0.28; w.Reflectance = 0.05; w.CastShadow = false
				table.insert(waterParts, { part = w, home = w.CFrame })
			end
		end
	end
	-- waterfall off the west lip of the stream (tile 3,14)
	do
		local x, z = x0Of(3), z0Of(14)
		local sheet = brickPart(groundF, Vector3.new(x - 0.6, -30 - PLATE, z + 0.2), Vector3.new(0.4, 30, S - 0.4), hx("bfe6f5"), Enum.Material.Glass)
		sheet.Name = "Waterfall"; sheet.Transparency = 0.45; sheet.CastShadow = false
		local src = Instance.new("Attachment"); src.Position = Vector3.new(0, 15, 0); src.Parent = sheet
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"; pe.Color = ColorSequence.new(hx("e8f7ff"))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1.2, 1.8); pe.Rate = 40; pe.Speed = NumberRange.new(2, 4); pe.SpreadAngle = Vector2.new(12, 12)
		pe.Acceleration = Vector3.new(0, -26, 0); pe.EmissionDirection = Enum.NormalId.Left; pe.LightEmission = 0.2; pe.Parent = src
		table.insert(waterParts, { part = sheet, home = sheet.CFrame })
	end
	-- props (each a brick Model snapped to the stud grid)
	local seed = 0
	for _, o in Map.objects do
		local def = DEFS[o[1]]
		if not def then continue end
		seed += 1
		local x, z = pxToWorld(o[2], o[3])
		local info = buildProp(def, o[1], x, z, scenery, seed)
		table.insert(props, info)
		if info.light then table.insert(lamps, info) end
		if o[1] == "windmill" then
			local hub = Vector3.new(info.ox + 2.5 * L, info.base + 14 * PLATE, info.oz + 5 * L + 0.6)
			info.sails = buildSails(info.model, hub)
			info.sailsHome = info.sails:GetPivot()
			info.model.WorldPivot = CFrame.new(info.x, info.base, info.z)
			info.home = info.model:GetPivot()
		end
	end
	-- flowers: 1x1-stud clusters on stud centres, grass only, never in the field / on the hill
	do
		local fm = Instance.new("Model"); fm.Name = "Flowers"
		for k, f in Map.flowers do
			local x, z = pxToWorld(f[1], f[2])
			local i, j = math.floor(x / S + COLS / 2), math.floor(z / S + ROWS / 2)
			if tile(i, j) ~= 1 or Map.height(i, j) > 0 or inField(i, j) then continue end
			local sx, sz = math.floor(x / L) * L, math.floor(z / L) * L
			local col = hx(FLOWER_COLS[k % #FLOWER_COLS + 1])
			brickPart(fm, Vector3.new(sx + 0.45 * L, STUD_H, sz + 0.45 * L), Vector3.new(0.1 * L, 1.6 * PLATE, 0.1 * L), hx("5f9a45")).CastShadow = false
			brickPart(fm, Vector3.new(sx + 0.25 * L, STUD_H + 1.6 * PLATE, sz + 0.25 * L), Vector3.new(0.5 * L, 0.5 * PLATE, 0.5 * L), col).CastShadow = false
			brickPart(fm, Vector3.new(sx + 0.4 * L, STUD_H + 2.1 * PLATE, sz + 0.4 * L), Vector3.new(0.2 * L, 0.2 * PLATE, 0.2 * L), hx("ffd27a")).CastShadow = false
		end
		fm.WorldPivot = CFrame.new(); fm.Parent = scenery
		table.insert(props, { model = fm, home = fm:GetPivot(), kind = "flowers", base = 0, x = 0, z = 0 })
	end
	-- clouds orbiting around and below the island
	local cf = Instance.new("Folder"); cf.Name = "Clouds"; cf.Parent = root
	for k = 1, 12 do
		local m = buildCloud(cf, k)
		table.insert(clouds, { model = m, r = (34 + hash(k, 4) * 26) * S / 2, a = hash(k, 5) * math.pi * 2, y = (hash(k, 6) - 0.7) * 26, sp = 0.006 + hash(k, 7) * 0.006 })
	end
	-- far islands: small brick islands in the haze
	local farF = Instance.new("Folder"); farF.Name = "Far"; farF.Parent = root
	for k, f in { { -150, -70, -160, 1.0 }, { 170, -95, -120, 0.8 }, { -210, -120, 60, 0.7 }, { 230, -60, 90, 0.9 }, { 40, -140, -260, 0.6 }, { -60, -110, 230, 0.65 } } do
		local o = Vector3.new(f[1], f[2], f[3])
		local w = math.floor((10 + k % 3 * 4) * f[4]) * L
		brickPart(farF, o + Vector3.new(-w / 2, 0, -w * 0.35), Vector3.new(w, PLATE * 2, w * 0.7), hx("86b268")).CastShadow = false
		for q = 1, 3 do
			local kw = w * (1 - q * 0.22)
			brickPart(farF, o + Vector3.new(-kw / 2, -q * BRICK * 1.5, -kw * 0.35), Vector3.new(kw, BRICK * 1.5, kw * 0.7), hx(if q % 2 == 1 then C.soil else C.soilD)).CastShadow = false
		end
		if k % 2 == 1 then
			brickPart(farF, o + Vector3.new(w * 0.2, PLATE * 2, 0), Vector3.new(L, BRICK * 1.2, L), hx(C.bark)).CastShadow = false
			brickPart(farF, o + Vector3.new(w * 0.2 - L, PLATE * 2 + BRICK * 1.2, -L), Vector3.new(3 * L, BRICK, 3 * L), hx(C.leafA)).CastShadow = false
		end
	end
	-- fireflies (night only): one emitter over the grass
	fireflies = Instance.new("Part")
	fireflies.Name = "Fireflies"; fireflies.Anchored = true; fireflies.CanCollide = false; fireflies.CanQuery = false; fireflies.CanTouch = false
	fireflies.Transparency = 1; fireflies.Size = Vector3.new(COLS * S * 0.8, 6, ROWS * S * 0.8); fireflies.CFrame = CFrame.new(0, 4, 0); fireflies.Parent = root
	local ff = Instance.new("ParticleEmitter")
	ff.Name = "FF"; ff.Texture = "rbxasset://textures/particles/sparkles_main.dds"; ff.Color = ColorSequence.new(hx("fff4a0"))
	ff.LightEmission = 1; ff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 0) })
	ff.Lifetime = NumberRange.new(3, 5); ff.Rate = 0; ff.Speed = NumberRange.new(0.3, 1); ff.SpreadAngle = Vector2.new(180, 180)
	ff.Shape = Enum.ParticleEmitterShape.Box; ff.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward; ff.Parent = fireflies
	-- dust puffs for the build-in
	dustPart = Instance.new("Part")
	dustPart.Name = "Dust"; dustPart.Anchored = true; dustPart.CanCollide = false; dustPart.CanQuery = false; dustPart.CanTouch = false; dustPart.Transparency = 1
	dustPart.Size = Vector3.new(4, 0.2, 4); dustPart.Parent = root
	local dpe = Instance.new("ParticleEmitter")
	dpe.Name = "Puff"; dpe.Texture = "rbxasset://textures/particles/smoke_main.dds"; dpe.Color = ColorSequence.new(hx("f3ead6"))
	dpe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
	dpe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	dpe.Lifetime = NumberRange.new(0.5, 0.8); dpe.Rate = 0; dpe.Speed = NumberRange.new(4, 7); dpe.SpreadAngle = Vector2.new(80, 10)
	dpe.EmissionDirection = Enum.NormalId.Top; dpe.Drag = 4; dpe.Parent = dustPart
	return root
end

-- ---------------------------------------------------------------- unlock build-in
local playing = false
local function easeBack(t) local c1 = 1.9; local c3 = c1 + 1; return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2 end
local function setVisible(m: Instance, v: number)
	if m:IsA("BasePart") then m.LocalTransparencyModifier = v; return end
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.LocalTransparencyModifier = v end end
end
function IslandView.play(onDone)
	if playing or not root then return end
	playing = true
	local reduced = false
	pcall(function() reduced = UserSettings():GetService("UserGameSettings").ReducedMotion end)
	local items = {}
	local GAP = 0.32
	for k, it in meshes do table.insert(items, { set = function(dy) it.part.CFrame = it.home + Vector3.new(0, dy, 0) end, inst = it.part, delay = (k - 1) * GAP, drop = 26, dur = 0.6 }) end
	local after = #meshes * GAP
	for _, w in waterParts do table.insert(items, { set = function(dy) w.part.CFrame = w.home + Vector3.new(0, dy, 0) end, inst = w.part, delay = after, drop = 8, dur = 0.5 }) end
	local base = after + 0.2
	for k, p in props do
		table.insert(items, { set = function(dy) p.model:PivotTo(p.home + Vector3.new(0, dy, 0)) end, inst = p.model, delay = base + (k - 1) * 0.04, drop = 16, dur = 0.5,
			dust = p.kind ~= "flowers", at = Vector3.new(p.x, p.base, p.z) })
	end
	local total = 0
	for _, x in items do total = math.max(total, x.delay + x.dur); x.set(x.drop); setVisible(x.inst, 1) end
	local cam = workspace.CurrentCamera
	local toCF = cam.CFrame
	local fromCF = CFrame.lookAt(toCF.Position + Vector3.new(-120, 110, 140), Vector3.new(0, -4, 6))
	local t = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		for _, x in items do
			if x.done then continue end
			local k = math.clamp((t - x.delay) / x.dur, 0, 1)
			if k > 0 then
				if not x.shown then x.shown = true; setVisible(x.inst, 0) end
				x.set((1 - easeBack(k)) * x.drop)
				if x.dust and not x.puffed and k > 0.55 then
					x.puffed = true
					dustPart.CFrame = CFrame.new(x.at)
					dustPart.Puff:Emit(10)
				end
				if k >= 1 then x.done = true end
			end
		end
		-- camera: high wide shot easing into the play view
		local ck = math.clamp(t / (total + 0.3), 0, 1)
		local e = 1 - (1 - ck) ^ 3
		IslandView.camCF = if reduced then nil else fromCF:Lerp(toCF, e)
		if t > total + 0.35 then
			conn:Disconnect(); IslandView.camCF = nil; playing = false
			if onDone then onDone() end
		end
	end)
end

-- ---------------------------------------------------------------- day cycle: 24 real min per day (1 min = 1 game hour)
local KF = {   -- hour, brightness, outdoorAmbient, ambient, colorShiftTop, fog, tint, exposure, atmosphere colour, atmosphere decay
	{ 0, 1.1, "5d6a9a", "414a70", "5a6488", "1d2a58", "c4ceef", 0.05, "2a3560", "141c3c" },
	{ 4.5, 1.1, "5d6a9a", "414a70", "5a6488", "1d2a58", "c4ceef", 0.05, "2a3560", "141c3c" },
	{ 5.6, 1.6, "8a7aa0", "3d3a55", "ffb38a", "e0a080", "ffe0d0", 0, "ffc8a8", "c890a8" },
	{ 7, 2.1, "8494b4", "323a50", "ffe2bf", "d8e2ee", "fff1e0", -0.12, "d2e6fa", "a8cbef" },
	{ 11, 2.4, "8a9cba", "343c55", "fff8ec", "c8dcf0", "fffaf2", -0.18, "cfe4fa", "9cc4ee" },
	{ 15, 2.35, "8898b6", "343c55", "fff0d8", "cfe2f2", "fff6ea", -0.16, "d2e6fa", "a8cbef" },
	{ 17.5, 2.6, "8a86aa", "35324c", "ffb46b", "f0c49a", "ffe0c0", -0.06, "ffd6b8", "f0a89a" },
	{ 18.7, 1.8, "7a6a96", "353050", "ff8a5c", "c87a78", "ffd0c0", 0, "f0a090", "8a5a8a" },
	{ 20, 1.15, "60709f", "424c72", "5e6a90", "22305e", "c4ceef", 0.05, "2e3a68", "182044" },
	{ 24, 1.1, "5d6a9a", "414a70", "5a6488", "1d2a58", "c4ceef", 0.05, "2a3560", "141c3c" },
}
local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density = 0.2; atmo.Offset = 0.08; atmo.Glare = 0.2; atmo.Haze = 0.35; atmo.Parent = Lighting
local function lerpHex(a, b, t) return hx(a):Lerp(hx(b), t) end
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local sky = Lighting:FindFirstChildOfClass("Sky")
if sky then sky.CelestialBodiesShown = true; sky.StarCount = 3000 end
IslandView.timeOverride = nil   -- dev/QA: set a game hour to freeze the sky
function IslandView.hour()
	if IslandView.timeOverride then return IslandView.timeOverride end
	return (workspace:GetServerTimeNow() / 60 + 8) % 24   -- +8: the server epoch starts at 08:00
end
local function nightOf(h)
	if h >= 20 or h < 4.5 then return 1 end
	if h < 6 then return 1 - (h - 4.5) / 1.5 end
	if h > 18.5 then return (h - 18.5) / 1.5 end
	return 0
end
local skyT = 0
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	if not root then return end
	-- windmill + clouds every frame (pivots only)
	if not playing then
		for _, info in props do if info.sails then info.sails:PivotTo(info.sailsHome * CFrame.Angles(0, 0, -clock * 0.7)) end end
	end
	for _, c in clouds do
		c.a += c.sp * dt
		c.model:PivotTo(CFrame.new(math.cos(c.a) * c.r, c.y + math.sin(clock * 0.3 + c.a * 5) * 0.6, math.sin(c.a) * c.r * 0.85))
	end
	-- sky at 4 Hz (cheap), smooth because the hour moves slowly
	skyT += dt
	if skyT < 0.25 then return end
	skyT = 0
	local h = IslandView.hour()
	local k = 1
	while KF[k + 1][1] < h do k += 1 end
	local a, b = KF[k], KF[k + 1]
	local t = (h - a[1]) / (b[1] - a[1])
	Lighting.ClockTime = h
	Lighting.Brightness = a[2] + (b[2] - a[2]) * t
	Lighting.OutdoorAmbient = lerpHex(a[3], b[3], t)
	Lighting.Ambient = lerpHex(a[4], b[4], t)
	Lighting.ColorShift_Top = lerpHex(a[5], b[5], t)
	Lighting.FogColor = lerpHex(a[6], b[6], t)
	Lighting.ExposureCompensation = a[8] + (b[8] - a[8]) * t
	if cc then cc.TintColor = lerpHex(a[7], b[7], t) end
	atmo.Color = lerpHex(a[9], b[9], t); atmo.Decay = lerpHex(a[10], b[10], t)
	local n = nightOf(h)
	for _, info in lamps do
		info.glow.Color = hx("5a5048"):Lerp(hx("ffd890"), n)
		info.light.Brightness = 2.2 * n
	end
	if fireflies then fireflies.FF.Rate = 14 * n end
end)

return IslandView
