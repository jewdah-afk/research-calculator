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
local World = require(Shared:WaitForChild("World"))

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
local parkCodes = World.byId.park.codes
local function tile(i, j) local r = parkCodes[j]; return r and r[i] or 0 end
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
DEFS.arch = { w = 8, d = 2, parts = {   -- 8 studs: the 4-stud opening spans the 2-tile road exactly
	P(0, 0, 0, 2, 2, 3, "stone"), P(0, 0, 3, 2, 2, 3, "stoneB"), P(0, 0, 6, 2, 2, 3, "stone"), P(0, 0, 9, 2, 2, 3, "stoneB"),
	P(6, 0, 0, 2, 2, 3, "stoneB"), P(6, 0, 3, 2, 2, 3, "stone"), P(6, 0, 6, 2, 2, 3, "stoneB"), P(6, 0, 9, 2, 2, 3, "stone"),
	P(0, 0, 12, 8, 2, 3, "stoneL"), P(1, 0, 15, 6, 2, 2, "stone"), P(3, 1.95, 12.6, 2, 0.1, 1.8, "gold") } }
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
		task.defer(function() IslandView.addLeaves(info.model, o[1]) end)
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
		table.insert(clouds, { model = m, r = (34 + hash(k, 4) * 26) * S / 2, a = hash(k, 5) * math.pi * 2, y = -10 - hash(k, 6) * 22, sp = 0.006 + hash(k, 7) * 0.006 })   -- clouds stay below the island tops (never across a bridge)
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
	IslandView.ready = true
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

-- ---------------------------------------------------------------- other islands + bridges (approved concept islands.html)
-- Ground is plain Parts (the EditableMesh budget belongs to the Park): per tile a top plate (+ 4 cylinder studs on
-- grass), hill courses, and only the underside courses the camera can actually see (rim + stepped taper).
-- Props are the concept's exact brick parts (shared/IslandData, tile units -> studs).
local built = {}         -- island id -> record
local builtBridges = {}  -- bridge -> record
local bobs, islandLamps, islandGlows = {}, {}, {}
local islandsF
local function islandsFolder()
	if not islandsF or not islandsF.Parent then
		islandsF = Instance.new("Folder"); islandsF.Name = "Islands"; islandsF.Parent = root or workspace
	end
	return islandsF
end
local function sx(i) return (i - COLS / 2) * S end   -- world tile coord -> studs (continuous)
local function sz(j) return (j - ROWS / 2) * S end
local MAT = { [0] = Enum.Material.SmoothPlastic, [1] = Enum.Material.Glass, [2] = Enum.Material.Neon, [3] = Enum.Material.Neon, [4] = Enum.Material.Glass }

local function islandTopY(isl, i, j)
	local c = World.rawTile(i, j)
	if c == 2 then return -0.5 * PLATE end
	if c == 3 then return -2 * PLATE end
	return isl.H(i, j) * BRICK
end

local function buildIslandGround(isl, rec)
	local d = isl.data
	local function land(i, j) local c, o = World.rawTile(i, j); return c ~= 0 and o == isl end
	local eCache = {}
	local function edge(i, j)
		local k = i * 1000 + j
		if eCache[k] then return eCache[k] end
		local dd = 0
		for r = 1, 7 do
			local ok = true
			for a = -r, r do
				for b = -r, r do
					if (math.abs(a) == r or math.abs(b) == r) and not land(i + a, j + b) then ok = false; break end
				end
				if not ok then break end
			end
			if not ok then break end
			dd = r
		end
		eCache[k] = dd
		return dd
	end
	local function depth(i, j)
		if not land(i, j) then return 0 end
		return math.min(7, 1 + math.floor(edge(i, j) * 1.15) + math.floor(hash(i, j) * 2.2))
	end
	local grassCol = { hx(d.grass[1]), hx(d.grass[2]) }
	local altCol = { hx(d.alt[1]), hx(d.alt[2]) }
	local pathCol = { hx(d.path[1]), hx(d.path[2]) }
	local count = 0
	for j = isl.oj, isl.oj + isl.N - 1 do
		for i = isl.oi, isl.oi + isl.W - 1 do
			local c = World.rawTile(i, j)
			if not land(i, j) then continue end
			local m = Instance.new("Model"); m.Name = i .. "," .. j
			local x0, z0 = sx(i), sz(j)
			local n = hash(i, j)
			local ty = islandTopY(isl, i, j)
			local col
			if c == 1 then col = grassCol[(i + j) % 2 + 1]
			elseif c == 4 then col = altCol[(i + j) % 2 + 1]
			elseif c == 2 then col = pathCol[if n > 0.5 then 1 else 2]
			else col = hx(C.sand) end
			col = vary(col, (n - 0.5) * 0.03)
			brickPart(m, Vector3.new(x0, ty - PLATE, z0), Vector3.new(S, PLATE, S), col)
			if c == 1 then
				local sc = vary(col, 0.035)
				for _, o in { { 0.25, 0.25 }, { 0.75, 0.25 }, { 0.25, 0.75 }, { 0.75, 0.75 } } do
					local st = Instance.new("Part")
					st.Shape = Enum.PartType.Cylinder; st.Size = Vector3.new(STUD_H, 2 * STUD_R, 2 * STUD_R)
					st.Anchored = true; st.CanCollide = false; st.CanQuery = false; st.CanTouch = false; st.CastShadow = false
					st.Material = Enum.Material.SmoothPlastic; st.Color = sc
					st.CFrame = CFrame.new(x0 + o[1] * S, ty + STUD_H / 2, z0 + o[2] * S) * CFrame.Angles(0, 0, math.pi / 2)
					st.Parent = m
				end
			end
			-- hill courses under a raised top
			local lv = if c == 1 or c == 4 then isl.H(i, j) else 0
			for k = 1, lv do
				local y0 = if k == 1 then -PLATE else (k - 1) * BRICK
				local y1 = if k == lv then ty - PLATE else k * BRICK
				local cc = if c == 4 and isl.id ~= "garden" then altCol[(k + 1) % 2 + 1] else hx(if k % 2 == 1 then C.soil else C.soilD)
				brickPart(m, Vector3.new(x0, y0, z0), Vector3.new(S, y1 - y0, S), vary(cc, (hash(i + k, j) - 0.5) * 0.05))
			end
			-- underside: only courses with an exposed side
			local dp = depth(i, j)
			local yy = if c == 2 or c == 3 then ty - PLATE else math.min(ty - PLATE, -PLATE)
			for k = 1, dp do
				local inset = if k > dp - 2 and dp > 2 then (k - (dp - 2)) * 0.25 * L else 0
				local exposed = inset > 0
				for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					if not land(i + o[1], j + o[2]) or depth(i + o[1], j + o[2]) < k or World.rawTile(i + o[1], j + o[2]) == 3 then exposed = true end
				end
				if exposed then
					local cc
					if k == 1 then cc = hx(C.topsoil)
					elseif n > 0.82 and k > 2 then cc = hx(if k % 2 == 1 then C.rock else C.rockD)
					else cc = hx(if k % 2 == 1 then C.soil else C.soilD) end
					brickPart(m, Vector3.new(x0 + inset, yy - BRICK, z0 + inset), Vector3.new(S - 2 * inset, BRICK, S - 2 * inset), vary(cc, (hash(i * 3 + k, j) - 0.5) * 0.05))
				end
				yy -= BRICK
			end
			if c == 3 then
				local w = brickPart(m, Vector3.new(x0, -2 * PLATE, z0), Vector3.new(S, PLATE, S), hx("6fb7d8"), Enum.Material.Glass)
				w.Name = "Water"; w.Transparency = 0.28; w.Reflectance = 0.05; w.CastShadow = false
			end
			m.WorldPivot = CFrame.new(x0 + S / 2, 0, z0 + S / 2)
			m.Parent = rec.ground
			table.insert(rec.tiles, { model = m, i = i, j = j })
			count += 1
			if count % 60 == 0 then task.wait() end
		end
	end
	-- waterfalls at the river mouths
	for _, sp in d.spills do
		local i = isl.oi + math.floor(sp[1])
		local jj
		if sp[2] == "n" then for j = isl.oj, isl.oj + isl.N - 1 do if land(i, j) then jj = j; break end end
		else for j = isl.oj + isl.N - 1, isl.oj, -1 do if land(i, j) then jj = j; break end end end
		if not jj then continue end
		local zEdge = if sp[2] == "n" then sz(jj) - 0.6 else sz(jj + 1) + 0.2
		local sheet = brickPart(rec.ground, Vector3.new(sx(isl.oi + sp[1]) - 1.5 * S, -30 - PLATE, zEdge), Vector3.new(3 * S, 30, 0.4), hx("bfe6f5"), Enum.Material.Glass)
		sheet.Name = "Waterfall"; sheet.Transparency = 0.45; sheet.CastShadow = false
		local src = Instance.new("Attachment"); src.Position = Vector3.new(0, 15, 0); src.Parent = sheet
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"; pe.Color = ColorSequence.new(hx("e8f7ff"))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1.2, 1.8); pe.Rate = 30; pe.Speed = NumberRange.new(2, 4); pe.SpreadAngle = Vector2.new(12, 12)
		pe.Acceleration = Vector3.new(0, -26, 0); pe.EmissionDirection = if sp[2] == "n" then Enum.NormalId.Back else Enum.NormalId.Front
		pe.LightEmission = 0.2; pe.Parent = src
		table.insert(rec.extras, sheet)
	end
end

local function buildIslandProp(isl, p, parent)
	local i, j = math.floor(p.x), math.floor(p.z)
	local c = World.rawTile(i, j)
	local base = if c == 3 then -0.2 else islandTopY(isl, i, j)
	local origin = CFrame.new(sx(p.x), base, sz(p.z)) * CFrame.Angles(0, p.rot or 0, 0)
	local m = Instance.new("Model"); m.Name = p.kind
	local bobM
	local info = { model = m, kind = p.kind, base = base, x = sx(p.x), z = sz(p.z), i = i, j = j }
	for _, q in p.parts do
		local b = Instance.new("Part")
		b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false
		b.TopSurface = Enum.SurfaceType.Smooth; b.BottomSurface = Enum.SurfaceType.Smooth
		local cf = origin * CFrame.new(q[5] * S, q[6] * S, q[7] * S) * CFrame.Angles(q[8], q[9], q[10])
		if q[1] == 1 then
			b.Shape = Enum.PartType.Cylinder; b.Size = Vector3.new(q[3] * S, q[2] * S, q[4] * S); cf *= CFrame.Angles(0, 0, math.pi / 2)
		else b.Size = Vector3.new(q[2] * S, q[3] * S, q[4] * S) end
		b.CFrame = cf
		b.Color = hx(q[11]); b.Material = MAT[q[12]]
		if q[12] == 1 then b.Transparency = 0.5 elseif q[12] == 4 then b.Transparency = 0.4; b.Color = hx("4fa8d8") end
		b.CastShadow = q[12] ~= 1 and q[12] ~= 4 and math.min(b.Size.X, b.Size.Z) > 0.6
		if q[12] == 2 then b.Material = Enum.Material.SmoothPlastic; table.insert(islandGlows, b) end   -- Neon only at night
		if q[12] == 3 then
			b.Color = hx("5a5048")
			local pl = Instance.new("PointLight"); pl.Color = hx("ffc56b"); pl.Range = 16; pl.Brightness = 0; pl.Shadows = false; pl.Parent = b
			table.insert(islandLamps, { glow = b, light = pl })
		end
		if q[13] == 1 then
			if not bobM then bobM = Instance.new("Model"); bobM.Name = "Bob"; bobM.Parent = m end
			b.Parent = bobM
		else b.Parent = m end
	end
	m.WorldPivot = CFrame.new(info.x, base, info.z)
	m.Parent = parent
	info.home = m:GetPivot()
	if bobM then
		bobM.WorldPivot = CFrame.new(info.x, base, info.z)
		info.bob = { model = bobM, home = bobM:GetPivot(), amp = (p.bob and p.bob[1] or 0.2) * S, sp = p.bob and p.bob[2] or 1, ph = hash(i, j) * 6 }
		table.insert(bobs, info.bob)
	end
	return info
end

-- rope bridge: wooden planks hung between stone landing posts, rope rails, posts every fourth plank.
-- Each plank row is its own model so the deck can sway in the wind and dip under the bird (see bridgeStep).
local function buildBridgeModel(br, parent)
	local m = Instance.new("Model"); m.Name = "Bridge_" .. br.a.id .. "_" .. br.b.id
	local rows = {}   -- u -> {tiles}
	for _, t in br.tiles do rows[t.u] = rows[t.u] or {}; table.insert(rows[t.u], t) end
	local planks = {}
	local n = 0
	for _ in rows do n += 1 end
	for u, ts in rows do
		local mn, mx = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
		for _, t in ts do mn = mn:Min(Vector2.new(t.i, t.j)); mx = mx:Max(Vector2.new(t.i + 1, t.j + 1)) end
		local pm = Instance.new("Model"); pm.Name = "Plank" .. u
		local x0, z0, x1, z1 = sx(mn.X), sz(mn.Y), sx(mx.X), sz(mx.Y)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		-- local frame: a = along the bridge, c = across
		local along = if br.alongX then Vector3.xAxis else Vector3.zAxis
		local across = if br.alongX then Vector3.zAxis else Vector3.xAxis
		local lenA = if br.alongX then x1 - x0 else z1 - z0
		local width = (if br.alongX then z1 - z0 else x1 - x0) + 1.2
		local function box(oa, oy, oc, sa, sy, sc, col)
			local size = along * sa + across * sc + Vector3.new(0, sy, 0)
			local centre = Vector3.new(cx, 0, cz) + along * oa + across * oc + Vector3.new(0, oy, 0)
			return brickPart(pm, centre - size / 2, size, col)
		end
		-- two boards per tile with a hairline gap, a darker crossbeam under them
		for h = 0, 1 do
			local oa = (h - 0.5) * lenA / 2
			local wood = vary(hx(if (u * 2 + h) % 3 == 0 then "b27f50" elseif (u * 2 + h) % 3 == 1 then C.wood else "a8774a"), (hash(u, h) - 0.5) * 0.05)
			box(oa, -PLATE * 1.1, (hash(u + h, 7) - 0.5) * 0.3, lenA / 2 - 0.18, PLATE * 1.2, width - 0.4 - hash(h, u) * 0.4, wood)   -- deck top flush with the paths (-0.5 plate)
		end
		box(0, -PLATE * 2.1, 0, 0.5, PLATE * 0.8, width + 0.4, hx(C.woodD))
		-- rope rails (thin, dark) on both sides, a wooden post every 4th plank
		for _, side in { -1, 1 } do
			-- ropes are continuous segments added after all planks hang (see below); posts every 4th plank
			if u % 4 == 1 and u > 2 and u < n - 1 then   -- none next to the end anchor posts (no doubled posts)
				box(0, 1.1, side * (width / 2 + 0.15), 0.6, 2.9, 0.6, hx(C.woodD))
			end
		end
		pm.WorldPivot = CFrame.new(cx, 0, cz)
		local sag = ts[1].sag or 0
		pm:PivotTo(CFrame.new(cx, -sag, cz))   -- hangs in a gentle rope curve
		pm.Parent = m
		table.insert(planks, { model = pm, u = u, home = pm:GetPivot(), at = Vector3.new(cx, -sag, cz), half = width / 2 + 0.15, across = across })
	end
	table.sort(planks, function(a, b) return a.u < b.u end)
	-- ropes: one straight segment between consecutive planks per side and height, so the rail follows the sag
	-- as one unbroken line (each segment rides with its plank during the build-in)
	local function rope(parent, a: Vector3, b: Vector3, th, col)
		local len = (b - a).Magnitude
		if len < 0.01 then return end
		local r = Instance.new("Part")
		r.Anchored = true; r.CanCollide = false; r.CanQuery = false; r.CanTouch = false; r.CastShadow = false
		r.Material = Enum.Material.SmoothPlastic; r.Color = col
		r.Size = Vector3.new(th, th, len + th); r.CFrame = CFrame.lookAt((a + b) / 2, b)
		r.Parent = parent
	end
	for k = 2, #planks do
		local pa, pb = planks[k - 1], planks[k]
		for _, side in { -1, 1 } do
			for _, h in { { 2.3, 0.22, "6e5238" }, { 1.0, 0.16, "7a5c40" } } do
				local a = pa.at + pa.across * side * pa.half + Vector3.new(0, h[1], 0)
				local b = pb.at + pb.across * side * pb.half + Vector3.new(0, h[1], 0)
				rope(pb.model, a, b, h[2], hx(h[3]))
			end
		end
	end
	for k, pl in planks do pl.f = (k - 0.5) / #planks end
	-- stone landing posts at both ends (static)
	local ends = Instance.new("Model"); ends.Name = "Posts"
	for _, e in { planks[1], planks[#planks] } do
		if not e then continue end
		local back = if e == planks[1] then -1 else 1
		local along = if br.alongX then Vector3.xAxis else Vector3.zAxis
		local across = if br.alongX then Vector3.zAxis else Vector3.xAxis
		-- landing pier: a stacked timber crib under the end plank, sunk into the cliff face, so the bridge end
		-- visibly rests on something instead of hanging off the grass lip
		do
			local w = e.half * 2 - 0.6
			for k = 0, 3 do
				local h = BRICK * 0.6
				local inset = k * 0.25
				local sz = along * (S * 0.9 - inset) + across * (w - inset * 2) + Vector3.new(0, h, 0)
				local c0 = Vector3.new(e.at.X, e.at.Y - PLATE * 1.7 - h * (k + 0.5), e.at.Z) + along * back * 0.4
				local logCol = vary(hx(if k % 2 == 0 then C.woodD else "6e4f33"), (hash(k, e.u) - 0.5) * 0.05)
				local pp = brickPart(e.model, c0 - sz / 2, sz, logCol)
				pp.CastShadow = true
			end
		end
		for _, side in { -1, 1 } do
			local c = Vector3.new(e.at.X, 0, e.at.Z) + along * back * (S * 0.5 + 0.4) + across * side * (S + 0.75)
			-- wooden anchor post the ropes tie to, with a darker cap
			brickPart(ends, c - Vector3.new(0.6, 0, 0.6) - Vector3.new(0, PLATE + BRICK, 0), Vector3.new(1.2, 2 * BRICK + PLATE, 1.2), hx(C.woodD))
			brickPart(ends, c - Vector3.new(0.75, 0, 0.75) + Vector3.new(0, BRICK, 0), Vector3.new(1.5, PLATE * 0.6, 1.5), hx("6e4f33"))
			-- tie both ropes from this anchor post to the end plank (they ride with that plank in the build-in)
			for _, h in { { 2.3, 0.22, "6e5238" }, { 1.0, 0.16, "7a5c40" } } do
				rope(e.model, c + Vector3.new(0, h[1], 0), e.at + e.across * side * e.half + Vector3.new(0, h[1], 0), h[2], hx(h[3]))
			end
		end
	end
	ends.Parent = m
	m.Parent = parent
	return { model = m, planks = planks, br = br, centre = if #planks > 0 then (planks[1].at + planks[#planks].at) / 2 else Vector3.zero }
end

-- leaves: a slow emitter in each tree's canopy; leaves tumble down and drift with the wind (Ambience sets the push)
IslandView.leafEmitters = {}
local LEAF_TEX = "rbxasset://textures/whiteCircle.png"
local LEAF_KINDS = { oak = { "7fb35e", "c8b040" }, bigoak = { "7fb35e", "d88a3a" }, tree = { "7fb35e", "c8b040" }, pine = { "5d9a4c" },
	nesttree = { "569a4e", "d88a3a" }, palm = { "5aa04c" } }
local function addLeaves(model: Instance, kind: string)
	local cols = LEAF_KINDS[kind]; if not cols then return end
	local cf, size = model:GetBoundingBox()
	local p = Instance.new("Part")
	p.Name = "Leaves"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1
	p.Size = Vector3.new(size.X * 0.7, 1, size.Z * 0.7); p.CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.25, 0))
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = LEAF_TEX; pe.Shape = Enum.ParticleEmitterShape.Box; pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Color = if #cols == 1 then ColorSequence.new(hx(cols[1])) else ColorSequence.new({ ColorSequenceKeypoint.new(0, hx(cols[1])), ColorSequenceKeypoint.new(0.6, hx(cols[1])), ColorSequenceKeypoint.new(0.61, hx(cols[2])), ColorSequenceKeypoint.new(1, hx(cols[2])) })
	pe.Size = NumberSequence.new(0.32); pe.Squash = NumberSequence.new(0.55)
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(3, 4.5); pe.Rate = 0.25; pe.Speed = NumberRange.new(0.5, 1.5); pe.SpreadAngle = Vector2.new(60, 60)
	pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = NumberRange.new(-140, 140)
	pe.Acceleration = Vector3.new(2, -3, 0.5); pe.Drag = 0.8; pe.LightInfluence = 1
	pe.Parent = p
	p.Parent = model
	table.insert(IslandView.leafEmitters, pe)
end
IslandView.addLeaves = addLeaves

local function setVis(inst: Instance, v: number)
	if inst:IsA("BasePart") then inst.LocalTransparencyModifier = v end
	for _, d in inst:GetDescendants() do if d:IsA("BasePart") then d.LocalTransparencyModifier = v end end
end

local function buildIsland(isl)
	local rec = { tiles = {}, props = {}, extras = {} }
	rec.folder = Instance.new("Folder"); rec.folder.Name = isl.id
	rec.ground = Instance.new("Folder"); rec.ground.Name = "Ground"; rec.ground.Parent = rec.folder
	rec.scenery = Instance.new("Model"); rec.scenery.Name = isl.id
	buildIslandGround(isl, rec)
	for k, p in isl.props do
		if not p.dropped then
			local info = buildIslandProp(isl, p, rec.scenery)
			table.insert(rec.props, info)
			addLeaves(info.model, p.kind)
		end
		if k % 40 == 0 then task.wait() end
	end
	rec.folder.Parent = islandsFolder(); rec.scenery.Parent = IslandView.scenery   -- appear in one frame
	built[isl.id] = rec
	return rec
end
local function destroyIsland(id)
	local rec = built[id]; if not rec then return end
	for k = #bobs, 1, -1 do if bobs[k].model:IsDescendantOf(rec.scenery) then table.remove(bobs, k) end end
	for k = #islandLamps, 1, -1 do if islandLamps[k].glow:IsDescendantOf(rec.scenery) then table.remove(islandLamps, k) end end
	for k = #islandGlows, 1, -1 do if islandGlows[k]:IsDescendantOf(rec.scenery) then table.remove(islandGlows, k) end end
	rec.folder:Destroy(); rec.scenery:Destroy()
	built[id] = nil
end

-- ---------------------------------------------------------------- procedural build-in: from the bridge it unlocks from
-- 1. planks lay out one by one from the previous island's shore; 2. the ground rises tile by tile as a wave flowing
-- outward from the landing (BFS over land, so it follows the island's shape); 3. each prop drops as the wave reaches
-- it, with a dust puff; 4. the other bridges to open neighbours lay out last. The camera rides the wavefront.
local building = 0
local function animate(items, camPath, onDone)
	local reduced = false
	pcall(function() reduced = UserSettings():GetService("UserGameSettings").ReducedMotion end)
	local total = 0
	for _, x in items do total = math.max(total, x.delay + x.dur); setVis(x.inst, 1); x.inst:PivotTo(x.home + Vector3.new(0, x.drop, 0)) end
	if reduced then
		for _, x in items do x.inst:PivotTo(x.home); setVis(x.inst, 0) end
		if onDone then onDone() end
		return
	end
	building += 1
	local t = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		for _, x in items do
			if x.done then continue end
			local k = math.clamp((t - x.delay) / x.dur, 0, 1)
			if k <= 0 then continue end
			if not x.shown then x.shown = true; setVis(x.inst, 0) end
			local e = easeBack(k)
			x.inst:PivotTo(x.home + Vector3.new(0, (1 - e) * x.drop, 0))
			if x.dust and not x.puffed and k > 0.55 then
				x.puffed = true; dustPart.CFrame = CFrame.new(x.at); dustPart.Puff:Emit(x.dust)
			end
			if k >= 1 then x.done = true end
		end
		if camPath then IslandView.camCF = camPath(math.clamp(t / (total + 0.4), 0, 1)) end
		if t > total + 0.45 then
			conn:Disconnect(); building -= 1
			if camPath then IslandView.camCF = nil end
			if onDone then onDone() end
		end
	end)
end

local CAM_PITCH, CAM_DIST = math.rad(52), 15 * S / math.tan(math.rad(5.5))
local function camAt(focus: Vector3)
	return CFrame.lookAt(focus + Vector3.new(0, math.sin(CAM_PITCH), math.cos(CAM_PITCH)) * CAM_DIST, focus)
end
local function bridgeItems(brec, startT, fromEnd)
	local items = {}
	local n = #brec.planks
	for k, pl in brec.planks do
		local order = if fromEnd then n - k else k - 1
		table.insert(items, { inst = pl.model, home = pl.home, drop = 10, dur = 0.38, delay = startT + order * 0.055, dust = if order % 2 == 0 then 4 else nil, at = pl.at })
	end
	return items, startT + n * 0.055 + 0.3
end

function IslandView.unlockIsland(isl, animated, onDone)
	local rec = built[isl.id] or buildIsland(isl)
	-- bridges to every open neighbour; the source bridge (the one it unlocks from) goes first
	local src = World.sourceBridge(isl)
	local items, after = {}, 0
	local startI, startJ = math.floor(isl.cx), math.floor(isl.cz)
	local landing = Vector3.new(sx(isl.cx), 0, sz(isl.cz))
	local brs = {}
	for _, br in World.bridges do
		if (br.a == isl or br.b == isl) and World.bridgeOpen(br) and not builtBridges[br] then
			builtBridges[br] = buildBridgeModel(br, islandsFolder())
			table.insert(brs, br)
		end
	end
	if src and builtBridges[src] then
		local its; its, after = bridgeItems(builtBridges[src], 0, false)
		for _, x in its do table.insert(items, x) end
		startI, startJ = src.landB[1], src.landB[2]
		landing = Vector3.new(sx(startI + 0.5), 0, sz(startJ + 0.5))
	end
	-- BFS distance over this island's land from the landing tile
	local dist = {}
	local q = { { startI, startJ } }
	dist[startI * 1000 + startJ] = 0
	local head = 1
	while head <= #q do
		local cur = q[head]; head += 1
		local d0 = dist[cur[1] * 1000 + cur[2]]
		for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = cur[1] + o[1], cur[2] + o[2]
			local c, own = World.rawTile(ni, nj)
			if c ~= 0 and own == isl and not dist[ni * 1000 + nj] then dist[ni * 1000 + nj] = d0 + 1; table.insert(q, { ni, nj }) end
		end
	end
	local maxD = 0
	for _, d in dist do maxD = math.max(maxD, d) end
	local STEP = math.clamp(1.6 / math.max(1, maxD), 0.035, 0.06)
	local function delayAt(i, j) return after + (dist[i * 1000 + j] or maxD) * STEP end
	for _, t in rec.tiles do
		table.insert(items, { inst = t.model, home = t.model.WorldPivot, drop = -(14 + hash(t.i, t.j) * 6), dur = 0.42, delay = delayAt(t.i, t.j) })
	end
	for _, p in rec.props do
		table.insert(items, { inst = p.model, home = p.home, drop = 18, dur = 0.5, delay = delayAt(p.i, p.j) + 0.28, dust = 10, at = Vector3.new(p.x, p.base, p.z) })
	end
	local waveEnd = after + maxD * STEP + 0.8
	for _, br in brs do
		if br ~= src then
			local its = bridgeItems(builtBridges[br], waveEnd, br.b ~= isl)
			for _, x in its do table.insert(items, x) end
		end
	end
	if not animated then
		for _, x in items do x.inst:PivotTo(x.home); setVis(x.inst, 0) end
		if onDone then onDone() end
		return
	end
	local centre = Vector3.new(sx(isl.cx), 0, sz(isl.cz))
	local from = workspace.CurrentCamera.CFrame
	local srcFocus = if src then Vector3.new(sx(src.landA[1] + 0.5), 0, sz(src.landA[2] + 0.5)) else landing
	animate(items, function(k)
		-- glide to the source shore, ride along the bridge and the wave, settle framing the new island
		if k < 0.15 then return from:Lerp(camAt(srcFocus), 1 - (1 - k / 0.15) ^ 3) end
		local u = (k - 0.15) / 0.85
		local e = u * u * (3 - 2 * u)
		return camAt(srcFocus:Lerp(landing, math.clamp(e * 2.2, 0, 1)):Lerp(centre, math.clamp((e - 0.3) / 0.7, 0, 1)))
	end, onDone)
end

-- bring the world in line with the unlock count; animate a single new island, build bigger jumps instantly
local syncing = false
function IslandView.sync(open, animated)
	while not IslandView.ready or syncing do task.wait() end
	syncing = true
	World.setOpen(open)
	local fresh = {}
	for _, isl in World.list do
		if isl.park then continue end
		if World.isOpen(isl) and not built[isl.id] then table.insert(fresh, isl)
		elseif not World.isOpen(isl) and built[isl.id] then destroyIsland(isl.id) end
	end
	for br, brec in builtBridges do
		if not World.bridgeOpen(br) then brec.model:Destroy(); builtBridges[br] = nil end
	end
	for _, isl in fresh do IslandView.unlockIsland(isl, animated and #fresh == 1) end
	-- bridges whose islands were both already up
	for _, br in World.bridges do
		if World.bridgeOpen(br) and not builtBridges[br] and (br.a.park or built[br.a.id]) and (br.b.park or built[br.b.id]) then
			builtBridges[br] = buildBridgeModel(br, islandsFolder())
		end
	end
	syncing = false
end
-- QA: replay the build-in of an open island
function IslandView.replay(id)
	local isl = World.byId[id]
	if not isl or isl.park or not World.isOpen(isl) then return end
	destroyIsland(id)
	for br, brec in builtBridges do if br.a == isl or br.b == isl then brec.model:Destroy(); builtBridges[br] = nil end end
	IslandView.unlockIsland(isl, true)
end
function IslandView.busy() return building > 0 or playing end

-- ---------------------------------------------------------------- life: bridges sway + dip, trees lean in the wind, culling
-- Wind is one shared gust signal (slow sine sum) so trees, bridges and the Ambience particles all agree.
IslandView.birdPos = nil       -- set by Main every frame (world position of the bird's feet)
IslandView.bridgeDip = 0       -- how far the deck under the bird has sunk (Main lowers the bird by this)
function IslandView.wind(t) return 0.55 + 0.3 * math.sin(t * 0.21) + 0.15 * math.sin(t * 0.67 + 1.3) end
local SWAY_KINDS = { tree = true, pine = true, oak = true, bigoak = true, palm = true, nesttree = true, sunflower = true, bush = true }
local swayT, cullT = 0, 0
local visible = {}   -- island id / bridge -> bool
function IslandView.ambientStep(dt, t)
	local cam = workspace.CurrentCamera
	local focus = cam.Focus.Position
	-- culling at 4 Hz: only islands / bridges near the view are parented (the camera is ~ortho, FOV 11)
	cullT += dt
	if cullT > 0.25 then
		cullT = 0
		local vp = cam.ViewportSize
		local halfX = 18 * S * vp.X / math.max(1, vp.Y) + 40
		for id, rec in built do
			local isl = World.byId[id]
			local c = Vector3.new(sx(isl.cx), 0, sz(isl.cz))
			local show = math.abs(c.X - focus.X) < halfX + isl.W * S / 2 and math.abs(c.Z - focus.Z) < 40 * S + isl.N * S / 2
			if visible[id] ~= show then
				visible[id] = show
				rec.folder.Parent = if show then islandsFolder() else nil
				rec.scenery.Parent = if show then IslandView.scenery else nil
			end
		end
		for br, brec in builtBridges do
			local c = brec.centre
			local show = math.abs(c.X - focus.X) < halfX + 30 and math.abs(c.Z - focus.Z) < 40 * S + 30
			brec.shown = show
			brec.model.Parent = if show then islandsFolder() else nil
		end
	end
	local w = IslandView.wind(t)
	-- bridges: wind sway + a dip that follows the bird, deepest mid-span
	local bird = IslandView.birdPos
	local dipHere = 0
	for br, brec in builtBridges do
		if not brec.shown then continue end
		local n = #brec.planks
		if n == 0 then continue end
		local along = if br.alongX then Vector3.xAxis else Vector3.zAxis
		local birdF, onIt = nil, false
		if bird then
			local a0, a1 = brec.planks[1].at, brec.planks[n].at
			local rel = bird - a0
			local len = (a1 - a0):Dot(along)
			local fa = rel:Dot(along) / (if len ~= 0 then len else 1)
			local off = (rel - along * rel:Dot(along)) * Vector3.new(1, 0, 1)
			if fa > -0.05 and fa < 1.05 and off.Magnitude < S * 1.4 and math.abs(bird.Y) < 6 then birdF = math.clamp(fa, 0, 1); onIt = true end
		end
		brec.dip = (brec.dip or 0) + ((if onIt then 1 else 0) - (brec.dip or 0)) * math.min(1, dt * 4)
		for k, pl in brec.planks do
			local sag = math.sin(pl.f * math.pi)
			local y = math.sin(t * 1.4 + k * 0.45) * 0.1 * sag * w
			local roll = math.sin(t * 0.9 + k * 0.25) * 0.02 * sag * w
			if birdF then
				local d = (pl.f - birdF) * n
				local bump = brec.dip * 0.9 * math.sin(birdF * math.pi) * math.exp(-(d * d) / 8)
				y -= bump
				if math.abs(d) < 0.6 then dipHere = math.max(dipHere, bump) end
			end
			local rot = if br.alongX then CFrame.Angles(roll, 0, 0) else CFrame.Angles(0, 0, roll)
			pl.model:PivotTo(pl.home * CFrame.new(0, y, 0) * rot)
		end
	end
	IslandView.bridgeDip = dipHere
	-- trees lean with the gusts (20 Hz, tiny angles, pivot at the base)
	swayT += dt
	if swayT < 0.05 then return end
	swayT = 0
	local function sway(info)
		if not SWAY_KINDS[info.kind] or not info.model.Parent then return end
		local ph = (info.x * 0.13 + info.z * 0.07)
		local a = (math.sin(t * 1.3 + ph) * 0.6 + math.sin(t * 2.3 + ph * 1.7) * 0.4) * 0.018 * w
		info.model:PivotTo(info.home * CFrame.Angles(a * 0.6, 0, a))
	end
	for _, info in props do sway(info) end
	for id, rec in built do if visible[id] then for _, info in rec.props do sway(info) end end end
end

-- ---------------------------------------------------------------- day cycle: 24 real min per day (1 min = 1 game hour)
local KF = {   -- hour, brightness, outdoorAmbient, ambient, colorShiftTop, fog, tint, exposure, atmosphere colour, atmosphere decay
	{ 0, 1.9, "8a98c8", "5a6690", "8a98c8", "33427a", "dfe6ff", 0.25, "3a4a80", "22305a" },
	{ 4.5, 1.9, "8a98c8", "5a6690", "8a98c8", "33427a", "dfe6ff", 0.25, "3a4a80", "22305a" },
	{ 5.6, 1.6, "8a7aa0", "3d3a55", "ffb38a", "e0a080", "ffe0d0", 0, "ffc8a8", "c890a8" },
	{ 7, 2.1, "8494b4", "323a50", "ffe2bf", "d8e2ee", "fff1e0", -0.12, "d2e6fa", "a8cbef" },
	{ 11, 2.4, "8a9cba", "343c55", "fff8ec", "c8dcf0", "fffaf2", -0.18, "cfe4fa", "9cc4ee" },
	{ 15, 2.35, "8898b6", "343c55", "fff0d8", "cfe2f2", "fff6ea", -0.16, "d2e6fa", "a8cbef" },
	{ 17.5, 2.6, "8a86aa", "35324c", "ffb46b", "f0c49a", "ffe0c0", -0.06, "ffd6b8", "f0a89a" },
	{ 18.7, 2.2, "9a8ab0", "4a4466", "ff9a6c", "d89088", "ffe0d0", 0.08, "f0a898", "9a6a98" },
	{ 20, 1.9, "8a98c8", "5a6690", "8a98c8", "35447c", "dfe6ff", 0.25, "3c4c82", "24325c" },
	{ 24, 1.9, "8a98c8", "5a6690", "8a98c8", "33427a", "dfe6ff", 0.25, "3a4a80", "22305a" },
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
	if building == 0 then
		for _, b in bobs do if b.model.Parent and b.model:IsDescendantOf(workspace) then b.model:PivotTo(b.home + Vector3.new(0, math.sin(clock * b.sp + b.ph) * b.amp, 0)) end end
		IslandView.ambientStep(dt, clock)
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
	for _, list in { lamps, islandLamps } do
		for _, info in list do
			info.glow.Color = hx("5a5048"):Lerp(hx("ffd890"), n)
			info.light.Brightness = 2.2 * n
		end
	end
	if fireflies then fireflies.FF.Rate = 14 * n end
	local neon = n > 0.4
	for _, g in islandGlows do g.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic end
end)

return IslandView
