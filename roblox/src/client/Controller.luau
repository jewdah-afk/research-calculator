--!strict
-- Controller — 1:1 port of the HTML player controller (src/world/World.js updatePlayer + canStand), in the HTML
-- game's own units (game px, 1 tile = 16 px; z = height in px). The result drives the network-owned root part.
--   input is screen-relative (camera yaw 0: screen right = +x, screen down = +y)
--   speed 60 px/s walking, 100 with Shift, x Wing Training; velocity approaches the target at 600 px/s^2
--   (800 when stopping); x then y moved separately against canStand(r = 4); Space jumps (vz 115, gravity 380).
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Map = require(Shared:WaitForChild("MapData"))
local Models = require(Shared:WaitForChild("Models"))
local World = require(Shared:WaitForChild("World"))
local S = Models.S

local Controller = {}

-- ---------------------------------------------------------------- world queries (World.canStand)
local VOID, WATER = 0, 3
local STEP_UP = 13   -- hills are walkable now (owner: "explore every part"); a hill step is up to ~3 studs
local colliders: { { x: number, y: number, r: number, base: number, top: number, hw: number?, hh: number? } } = {}
-- footprint radius (px) and height (px) per Park prop kind (Park overhaul props; see client/IslandView)
-- tight hitboxes (owner 2026-10-09: "right around them"): footprint radius in studs per kind, sized to the
-- generated models; kinds not listed are walk-through decor
local FOOT = { lantern = 0.5, oak = 0.7, bigoak = 0.9, pine = 0.6, tree = 0.7, palm = 0.5, deadtree = 0.6, rock = 1.0,
	cart = 2.0, bench = 1.1, windmill = 3.4, lighthouse = 3.4, arch = 0.9, barrel = 0.9, birdhouse = 0.4, scarecrow = 0.4, post = 0.3,
	keep = 9, tower = 2.6, temple = 6, pyramid = 6, greenhouse = 3.6, hut = 3.2, mineentrance = 4, minecart = 1.2,
	crystal = 1.0, ore = 1.0, cactus = 0.6, altar = 1.6, pillar = 0.9, bell = 1.2, banner = 0.3, rod = 0.4, tent = 2.2 }
local PX_PER_STUD = Map.PX / S
local TRUNK_R = 3
local SOFT = { bush = true, flowers = true, sunflower = true }
local TREES = { tree = true, oak = true, bigoak = true, pine = true }
local PROP_COLL0 = { lantern = { 3, 40 }, oak = { TRUNK_R, 60 }, bigoak = { TRUNK_R, 70 }, pine = { TRUNK_R, 60 }, rock = { 9, 10 },
	cart = { 16, 40 }, bench = { 9, 10 }, fence = { 6, 12 } }
for _, o in Map.objects do
	local kind, x, y = o[1], o[2], o[3]
	local r = FOOT[kind]
	if r then table.insert(colliders, { x = x, y = y, r = r * PX_PER_STUD, base = -100, top = 400 }) end
end
-- other islands + land joins: the same tight footprints
for _, isl in World.all() do
	if isl.park then continue end
	for _, p in isl.props do
		local r = FOOT[p.kind]
		if p.dropped or not r then continue end
		table.insert(colliders, { x = p.x * Map.PX, y = p.z * Map.PX, r = r * PX_PER_STUD, base = -100, top = 400 })
	end
end
-- coarse buckets so canStand only checks nearby colliders
local BUCKET = 64
local buckets: { [number]: { any } } = {}
local function bkey(bx: number, by: number): number return (by + 500) * 2000 + bx + 500 end
for _, c in colliders do
	local rx, ry = (c.hw or c.r) + 8, (c.hh or c.r) + 8
	for bx = math.floor((c.x - rx) / BUCKET), math.floor((c.x + rx) / BUCKET) do
		for by = math.floor((c.y - ry) / BUCKET), math.floor((c.y + ry) / BUCKET) do
			local k = bkey(bx, by); buckets[k] = buckets[k] or {}; table.insert(buckets[k], c)
		end
	end
end

local function tileAt(x: number, y: number): number
	return World.tile(math.floor(x / Map.PX), math.floor(y / Map.PX))
end
local heightAtLocalImpl
local function heightAtLocal(x: number, y: number): number return heightAtLocalImpl(x, y) end
local function heightAt(x: number, y: number): number
	-- terrace height (Peckwood Ascent) under everything else, in game px (Map.PX px per tile = S studs)
	local base = (World.base(math.floor(x / Map.PX), math.floor(y / Map.PX)) + World.relief(x / Map.PX, y / Map.PX)) * Map.PX / S
	return base + heightAtLocal(x, y)
end
-- the rocky slope at the foot of a higher terrace (LandTerrain.visualTop) is scenery: a wall, cached per tile
local slopeCache: { [number]: boolean } = {}
local function onSlope(i: number, j: number): boolean
	local k = (j + 1000) * 4000 + i + 1000
	local v = slopeCache[k]
	if v == nil then
		local base = World.base(i, j)
		v = false
		if World.rawTile(i, j) == 2 then slopeCache[k] = false; return false end   -- trail ramps stay walkable
		for dj = -3, 3 do
			for di = -3, 3 do
				local d = math.sqrt(di * di + dj * dj)
				if d > 0 and d <= 3.2 and World.rawTile(i + di, j + dj) ~= 0 and World.base(i + di, j + dj) > base + 3 then v = true end
			end
		end
		slopeCache[k] = v
	end
	return v
end
heightAtLocalImpl = function(x: number, y: number): number
	local t = tileAt(x, y)
	if t ~= VOID and t ~= 5 and onSlope(math.floor(x / Map.PX), math.floor(y / Map.PX)) then return 99 end
	if (t == 1 or t == 4) and World.height(math.floor(x / Map.PX), math.floor(y / Map.PX)) > 0 then
		-- hills / dunes: walk up and over at the height the terrain shows (LandTerrain.visualTop)
		local i, j = math.floor(x / Map.PX), math.floor(y / Map.PX)
		local LT = require(script.Parent:WaitForChild("LandTerrain"))
		local base = World.base(i, j)
		return ((LT.visualTop(i, j, base, t)) - base) * Map.PX / S
	end
	if t == 5 then   -- bridge / dock deck: walk on the planks
		local h = World.deckH(math.floor(x / Map.PX), math.floor(y / Map.PX))
		return if h then h / S * Map.PX else 0   -- planks (+) or a sagging rope bridge (-)
	end
	return if t == WATER then -6 elseif t == VOID then -36 else 0   -- wading: the hen sinks to its belly
end
Controller.heightAt = heightAt

local PTS = { 0, 0, 1, 0, -1, 0, 0, 1, 0, -1 }
function Controller.canStand(x: number, y: number, z: number, r: number): boolean
	for k = 1, #PTS, 2 do
		local px, py = x + PTS[k] * r, y + PTS[k + 1] * r
		local t = tileAt(px, py)
		if t == VOID then return false end   -- lakes / ponds are wadeable (owner 2026-10-09)
		if heightAt(px, py) - z > (if t == 5 then 15 else STEP_UP) then return false end   -- hop up onto plank decks
	end
	for _, c in buckets[bkey(math.floor(x / BUCKET), math.floor(y / BUCKET))] or {} do
		if z >= c.top or z + 14 < c.base then continue end
		local dx, dy = x - c.x, y - c.y
		if c.hw then
			if math.abs(dx) < c.hw + r and math.abs(dy) < (c.hh :: number) + r then return false end
		elseif dx * dx + dy * dy < (r + c.r) * (r + c.r) then return false end
	end
	return true
end

local function approach(v: number, t: number, d: number): number
	return if v < t then math.min(v + d, t) else math.max(v - d, t)
end

-- ---------------------------------------------------------------- the player body (World.player)
export type Body = { x: number, y: number, z: number, vx: number, vy: number, vz: number, groundZ: number, onGround: boolean,
	dust: number, landed: number, puffs: number, target: any? }
function Controller.new(x: number, y: number): Body
	return { x = x, y = y, z = 0, vx = 0, vy = 0, vz = 0, groundZ = 0, onGround = true, dust = 0, landed = 0, puffs = 0, target = nil }
end

-- ---------------------------------------------------------------- click-to-move (Game.click / findPath / playerInput)
-- A* on an 8-unit grid over canStand (r 6), 8-neighbour, no corner cutting, best-effort when the goal is unreachable.
function Controller.findPath(sx: number, sy: number, gx: number, gy: number, reach: number): { { x: number, y: number } }
	local G, cols = 8, 4000
	local function key(i: number, j: number): number return (j + 2000) * cols + i + 2000 end
	local function cx(i: number): number return i * G + G / 2 end
	local memo: { [number]: number | boolean } = {}
	local function pass(i: number, j: number): number?
		local k = key(i, j)
		local m = memo[k]
		if m ~= nil then return if m == false then nil else m :: number end
		local x, y = cx(i), cx(j)
		local h = heightAt(x, y)
		local ok = h > -2.5 and Controller.canStand(x, y, h, 6)
		memo[k] = if ok then h else false
		return if ok then h else nil
	end
	local si, sj = math.floor(sx / G), math.floor(sy / G)
	local function H(i: number, j: number): number return math.max(0, math.sqrt((cx(i) - gx) ^ 2 + (cx(j) - gy) ^ 2) - reach) end
	local open = { { H(si, sj), 0, si, sj } }
	local came: { [number]: number } = {}
	local cost: { [number]: number } = { [key(si, sj)] = 0 }
	local best, bestH, it = { si, sj }, H(si, sj), 0
	while #open > 0 and it < 9000 do
		it += 1
		local bi = 1
		for k = 2, #open do if open[k][1] < open[bi][1] then bi = k end end
		local cur = table.remove(open, bi) :: { number }
		local c, i, j = cur[2], cur[3], cur[4]
		local h0 = H(i, j)
		if h0 < bestH then bestH = h0; best = { i, j } end
		if h0 <= 0 then best = { i, j }; break end
		local z0 = if i == si and j == sj then heightAt(sx, sy) else (pass(i, j) or 0)
		for di = -1, 1 do
			for dj = -1, 1 do
				if di == 0 and dj == 0 then continue end
				local ni, nj = i + di, j + dj
				local z1 = pass(ni, nj)
				if z1 == nil or z1 - z0 > 15 then continue end   -- 15: hop onto plank decks
				if di ~= 0 and dj ~= 0 and (pass(i + di, j) == nil or pass(i, j + dj) == nil) then continue end
				local nc = c + (if di ~= 0 and dj ~= 0 then 1.414 else 1) + (if z0 - z1 > 5 then 3 else 0)
				local k = key(ni, nj)
				if nc < (cost[k] or 1e9) then cost[k] = nc; came[k] = key(i, j); table.insert(open, { nc + H(ni, nj) / G, nc, ni, nj }) end
			end
		end
	end
	local path = {}
	local k = key(best[1], best[2])
	while k ~= key(si, sj) and came[k] do
		table.insert(path, 1, { x = cx(k % cols - 2000), y = cx(k // cols - 2000) })
		k = came[k]
	end
	return path
end

-- hands-free travel ("Go to ..."): route island -> island over open bridges (BFS on the island graph), then stitch
-- short A* legs between the bridge landings so the bird walks the best path on its own
function Controller.travel(p: Body, gx: number, gy: number): boolean
	if #World.bridges == 0 then   -- Peckwood Isle: one landmass, walk the whole way with A*
		local path = Controller.findPath(p.x, p.y, gx, gy, 3)
		if #path == 0 then return false end
		p.target = { x = gx, y = gy, path = path, st = 0, travel = true }
		return true
	end
	local from = World.nearest(p.x / Map.PX, p.y / Map.PX)
	local to = World.nearest(gx / Map.PX, gy / Map.PX)
	local prev: { [any]: any } = { [from] = false }
	local q = { from }
	local head = 1
	while head <= #q do
		local cur = q[head]; head += 1
		if cur == to then break end
		for _, br in World.bridges do
			if not World.bridgeOpen(br) then continue end
			local nxt = if br.a == cur then br.b elseif br.b == cur then br.a else nil
			if nxt and prev[nxt] == nil then prev[nxt] = { cur, br }; table.insert(q, nxt) end
		end
	end
	if prev[to] == nil then return false end
	local hops = {}
	local n = to
	while prev[n] do table.insert(hops, 1, prev[n]); n = prev[n][1] end
	local pts = {}
	for _, h in hops do
		local cur, br = h[1], h[2]
		local a, b = if br.a == cur then br.pa else br.pb, if br.a == cur then br.pb else br.pa
		table.insert(pts, a); table.insert(pts, b)
	end
	table.insert(pts, { gx, gy })
	local path = {}
	local sx, sy = p.x, p.y
	for _, pt in pts do
		local leg = Controller.findPath(sx, sy, pt[1], pt[2], 3)
		for _, w in leg do table.insert(path, w) end
		table.insert(path, { x = pt[1], y = pt[2] })
		sx, sy = pt[1], pt[2]
	end
	p.target = { x = gx, y = gy, path = path, st = 0, travel = true }
	return true
end

function Controller.click(p: Body, wx: number, wy: number)
	p.target = { x = wx, y = wy, path = Controller.findPath(p.x, p.y, wx, wy, 5), st = 0 }
end

-- playerInput's move-target follow -> a world direction (or nil)
local function followTarget(p: Body, dt: number): (number?, number?)
	local m = p.target; if not m then return nil, nil end
	m.st += dt
	if m.st > 0.5 then
		if m.lx ~= nil and math.sqrt((p.x - m.lx) ^ 2 + (p.y - m.ly) ^ 2) < (if m.travel then 0.5 else 1.5) then p.target = nil; return nil, nil end   -- stuck
		m.st = 0; m.lx = p.x; m.ly = p.y
	end
	local path = m.path
	while #path > 1 and math.sqrt((path[1].x - p.x) ^ 2 + (path[1].y - p.y) ^ 2) < 4 do table.remove(path, 1) end
	local wp = if #path > 0 then path[1] else m
	if #path == 1 and math.sqrt((wp.x - p.x) ^ 2 + (wp.y - p.y) ^ 2) < 2 then table.clear(path) end
	local dx, dy = wp.x - p.x, wp.y - p.y
	local d = math.sqrt(dx * dx + dy * dy); if d == 0 then d = 1 end
	if math.sqrt((m.x - p.x) ^ 2 + (m.y - p.y) ^ 2) < 3 or #path == 0 then p.target = nil; return nil, nil end
	return dx / d, dy / d
end

local jumpEdge = false
UIS.InputBegan:Connect(function(io, gp)
	if gp then return end
	if io.KeyCode == Enum.KeyCode.Space or io.KeyCode == Enum.KeyCode.ButtonA then jumpEdge = true end
end)

local function down(...: Enum.KeyCode): boolean
	if UIS:GetFocusedTextBox() then return false end
	for _, k in { ... } do if UIS:IsKeyDown(k) then return true end end
	return false
end

-- one fixed step. speedMul = Wing Training multiplier from the server state.
function Controller.step(p: Body, dt: number, speedMul: number, dustCb: ((x: number, y: number, z: number, vx: number, vy: number, n: number) -> ())?)
	local K = Enum.KeyCode
	local ix = (if down(K.D, K.Right) then 1 else 0) - (if down(K.A, K.Left) then 1 else 0)
	local iy = (if down(K.S, K.Down) then 1 else 0) - (if down(K.W, K.Up) then 1 else 0)
	-- gamepad / touch thumbstick fallback (screen-relative too)
	if ix == 0 and iy == 0 then
		for _, st in UIS:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if st.KeyCode == K.Thumbstick1 and st.Position.Magnitude > 0.2 then ix, iy = st.Position.X, -st.Position.Y end
		end
	end
	local len = math.sqrt(ix * ix + iy * iy); if len == 0 then len = 1 end
	ix /= len; iy /= len
	local wx, wy = ix, iy   -- camera yaw 0: screen axes are world axes
	if ix ~= 0 or iy ~= 0 then p.target = nil   -- keys cancel click-to-move
	else
		local tx, ty = followTarget(p, dt)
		if tx then wx, wy = tx, ty :: number end
	end
	local run = down(K.LeftShift, K.RightShift)
	local speed = (if run then 100 else 60) * speedMul
	if tileAt(p.x, p.y) == WATER then speed *= 0.5 end   -- slow while wading
	local moving = wx ~= 0 or wy ~= 0
	p.vx = approach(p.vx, wx * speed, (if moving then 600 else 800) * dt)
	p.vy = approach(p.vy, wy * speed, (if moving then 600 else 800) * dt)

	local nx = p.x + p.vx * dt; if Controller.canStand(nx, p.y, p.z, 4) then p.x = nx else p.vx = 0 end
	local ny = p.y + p.vy * dt; if Controller.canStand(p.x, ny, p.z, 4) then p.y = ny else p.vy = 0 end

	local g = heightAt(p.x, p.y); p.groundZ = g
	if jumpEdge and p.onGround then p.vz = 115; p.onGround = false end
	jumpEdge = false
	p.vz -= 380 * dt; p.z += p.vz * dt
	if p.onGround and p.z > g and p.z - g < 6 then p.z = g end   -- stick to ramps
	if p.z <= g then
		if not p.onGround and p.vz < -60 then
			p.landed += 1
			if dustCb then dustCb(p.x, p.y, g, 0, 0, 6) end   -- puff on a hard landing
		end
		p.z = g; p.vz = 0; p.onGround = true
	elseif p.z > g + 0.5 then p.onGround = false end

	local sp = math.sqrt(p.vx * p.vx + p.vy * p.vy)
	if p.onGround and sp > 40 then
		p.dust -= dt
		if p.dust <= 0 then
			if dustCb then dustCb(p.x, p.y, p.z, -p.vx * 0.1, -p.vy * 0.1, 1) end
			p.dust = if sp > 80 then 0.08 else 0.16
		end
	end
end

-- game px -> world (matches Island.toWorld)
function Controller.toWorld(x: number, y: number, z: number): Vector3
	return Vector3.new((x / Map.PX - Map.COLS / 2) * S, z / Map.PX * S, (y / Map.PX - Map.ROWS / 2) * S)
end
function Controller.fromWorld(v: Vector3): (number, number, number)
	return (v.X / S + Map.COLS / 2) * Map.PX, (v.Z / S + Map.ROWS / 2) * Map.PX, v.Y / S * Map.PX
end

return Controller
