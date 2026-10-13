--!optimize 2
--[[
	The 3D board: the original 720 x 480 px play area laid flat at 1 px = 0.1 studs, seen from a fixed top-down
	camera. It builds the map (sand, road, the Area 51 base), keeps a model per turret / attacker / shot, moves
	them between server snapshots (100 ms interpolation delay), and plays the effects (lasers, sparks, blasts,
	money pop-ups). Everything short-lived comes from pools, so a busy late game creates no garbage.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local Board = {}
Board.__index = Board

local S = Config.BOARD.scale -- studs per px
local ORIGIN = Vector3.new(0, 500, 0) -- board corner (0,0); far from anything else in the place
local W, H = 720, 480
local DELAY = 0.1 -- interpolation delay (s)
local FAR = CFrame.new(0, -5000, 0)
local C = Ui.C
local hex = Ui.hex

local function P(x: number, y: number, h: number?): Vector3
	return ORIGIN + Vector3.new(x * S, h or 0, y * S)
end
Board.P = P

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	-- Ball parts are always round; an ellipsoid is a block with a sphere mesh that follows the part's size
	local ellipsoid = props.Shape == Enum.PartType.Ball and props.Size ~= nil and not (props.Size.X == props.Size.Y and props.Size.Y == props.Size.Z)
	for k, v in props do
		if not (ellipsoid and k == "Shape") then
			(p :: any)[k] = v
		end
	end
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	return p
end
-- a flat disc (cylinder standing up)
local function disc(r: number, h: number, color: Color3, props): Part
	local d = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r * 2, r * 2), Color = color })
	for k, v in props or {} do
		(d :: any)[k] = v
	end
	return d
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y
-- A frame at the midpoint of a..b whose X axis runs along a->b (Y stays up). Built from the axes directly,
-- so it doesn't depend on lookAt conventions.
local function along(a: Vector3, b: Vector3): CFrame
	local d = b - a
	if d.Magnitude < 1e-6 then
		return CFrame.new(a)
	end
	local x = d.Unit
	local z = x:Cross(Vector3.yAxis)
	if z.Magnitude < 1e-6 then
		return CFrame.new((a + b) / 2)
	end
	return CFrame.fromMatrix((a + b) / 2, x, z:Cross(x).Unit, z.Unit)
end

-- A thin ring of short segments lying on the board (centre x,y and radius r in px)
local function ringParts(n: number, color: Color3, transparency: number, parent: Instance)
	local list = {}
	for i = 1, n do
		list[i] = part({ Size = Vector3.new(1, 0.03, 0.2), Color = color, Transparency = transparency, Parent = parent })
	end
	return list
end
local function placeRing(list, x: number, y: number, r: number, h: number, width: number?)
	local n = #list
	local rs = r * S
	local seg = 2 * math.pi * rs / n * 1.08
	for i, p in list do
		local a = (i - 0.5) / n * 2 * math.pi
		local c = P(x, y, h) + Vector3.new(math.cos(a) * rs, 0, math.sin(a) * rs)
		p.Size = Vector3.new(math.max(0.05, seg), 0.03, width or 0.2)
		p.CFrame = CFrame.new(c) * CFrame.Angles(0, -a - math.pi / 2, 0)
	end
end

-- ================================================================ map
function Board.new(map, parent: Instance?)
	local self = setmetatable({}, Board)
	self.model = Instance.new("Model")
	self.model.Name = "OnslaughtBoard"
	self.static = Instance.new("Folder", self.model)
	self.dyn = Instance.new("Folder", self.model)
	self.turrets, self.attackers, self.shots = {}, {}, {}
	self.snaps = {}
	self.effects = {}
	self.pools = {}
	self.skins = {}
	self:buildMap(map)
	self.model.Parent = parent or Workspace
	self:lighting()
	return self
end

function Board:lighting()
	Lighting.Ambient = Color3.fromRGB(150, 140, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 145)
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 13.5
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 100000
end

function Board:buildMap(map)
	local f = self.static
	-- the world around the board, then the sand
	part({ Size = Vector3.new(600, 1, 600), CFrame = CFrame.new(P(W / 2, H / 2, -0.6)), Color = hex("#14171d"), Parent = f })
	part({ Size = Vector3.new(W * S + 1.2, 0.6, H * S + 1.2), CFrame = CFrame.new(P(W / 2, H / 2, -0.35)), Color = hex("#5c4228"), Parent = f })
	part({ Size = Vector3.new(W * S, 0.4, H * S), CFrame = CFrame.new(P(W / 2, H / 2, -0.2)), Color = hex("#e9c79a"), Material = Enum.Material.Sand, Parent = f })
	-- sand texture: a few pale rings like the original's background doodles (seeded, same every time)
	local seed = 97
	local function r()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	for _ = 1, 6 do
		local x, y, rr = r() * W, r() * H, 18 + r() * 34
		for k = 0, 2 do
			placeRing(ringParts(20, hex("#fff3de"), 0.55, f), x, y, rr - k * 8, 0.01, 0.2)
		end
	end
	-- road: three strokes like the HTML (31 px dark edge, 28 px dirt, 18 px light centre), round joints
	local road = map.road
	local function stroke(width: number, color: Color3, h: number, transparency: number?)
		for i = 2, #road do
			local a, b = road[i - 1], road[i]
			local pa, pb = P(a.x, a.y, h), P(b.x, b.y, h)
			local len = (pb - pa).Magnitude
			if len > 0 then
				part({ Size = Vector3.new(len, 0.05, width * S), CFrame = along(pa, pb), Color = color, Transparency = transparency or 0, Parent = f })
			end
		end
		for i = 2, #road - 1 do
			disc(width * S / 2, 0.05, color, { CFrame = CFrame.new(P(road[i].x, road[i].y, h)) * UPRIGHT, Transparency = transparency or 0, Parent = f })
		end
	end
	stroke(31, hex("#5c4228"), 0.02)
	stroke(28, hex("#b2885b"), 0.03)
	stroke(18, hex("#f2d9b0"), 0.035, 0.75)
	-- the base: USAF / AREA 51, orange to green
	local b = map.base
	local bx, by = b.x + 50, b.y + 12 + 35
	local left = part({ Size = Vector3.new(5, 1.4, 7), CFrame = CFrame.new(P(bx - 25, by, 0.7)), Color = hex("#c46d17"), Material = Enum.Material.Metal, Parent = f })
	local right = part({ Size = Vector3.new(5, 1.4, 7), CFrame = CFrame.new(P(bx + 25, by, 0.7)), Color = hex("#4b7a19"), Material = Enum.Material.Metal, Parent = f })
	local top = part({ Size = Vector3.new(10, 0.05, 7), CFrame = CFrame.new(P(bx, by, 1.43)), Transparency = 1, Parent = f })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.CanvasSize = Vector2.new(200, 140)
	sg.Parent = top
	local face = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg })
	Ui.new("UIGradient", { Color = ColorSequence.new(hex("#c46d17"), hex("#4b7a19")), Parent = face })
	Ui.new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = face })
	for i, line in { "USAF", "AREA 51" } do
		Ui.new("TextLabel", {
			BackgroundTransparency = 1, Text = line, TextColor3 = Color3.new(1, 1, 1), FontFace = Ui.HEAVY, TextSize = 34,
			Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, (i - 1) * 0.5), TextStrokeTransparency = 0.4, Parent = face,
		})
	end
	left.Name, right.Name = "BaseL", "BaseR"
end

-- ================================================================ camera
-- Fit the board into the part of the screen the HUD leaves free. insets = { top, right, bottom, left } in px.
function Board:fitCamera(insets)
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 24
	local vp = cam.ViewportSize
	local availW = math.max(100, vp.X - insets[2] - insets[4])
	local availH = math.max(100, vp.Y - insets[1] - insets[3])
	local k = math.min(availW / (W * S), availH / (H * S)) * 0.97 -- screen px per stud
	local d = (vp.Y / 2) / (k * math.tan(math.rad(cam.FieldOfView / 2)))
	local cx, cy = insets[4] + availW / 2, insets[1] + availH / 2
	local center = P(W / 2, H / 2)
	local at = center + Vector3.new(-(cx - vp.X / 2) / k, 0, -(cy - vp.Y / 2) / k)
	-- straight down, board x to the right, board y down the screen: right = +X, up = -Z, back = +Y
	cam.CFrame = CFrame.fromMatrix(at + Vector3.new(0, d, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
	self.pxPerStud = k
end

-- Viewport point (UserInputService:GetMouseLocation(), or a touch position plus the GUI inset) -> board px, or nil.
function Board:toBoard(viewport: Vector2 | Vector3): (number?, number?)
	local ray = Workspace.CurrentCamera:ViewportPointToRay(viewport.X, viewport.Y)
	if math.abs(ray.Direction.Y) < 1e-6 then
		return nil
	end
	local t = (ORIGIN.Y - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then
		return nil
	end
	local hit = ray.Origin + ray.Direction * t - ORIGIN
	local x, y = hit.X / S, hit.Z / S
	if x < 0 or x > W or y < 0 or y > H then
		return nil
	end
	return x, y
end

-- ================================================================ pools
function Board:pool(key: string, make: () -> Instance)
	local p = self.pools[key]
	if not p then
		p = { free = {}, make = make }
		self.pools[key] = p
	end
	local o = table.remove(p.free)
	if not o then
		o = make()
		o.Parent = self.dyn
	end
	return o
end
function Board:release(key: string, o: Instance)
	if o:IsA("BasePart") then
		o.CFrame = FAR
	elseif o:IsA("Model") then
		o:PivotTo(FAR)
	end
	table.insert(self.pools[key].free, o)
end

-- ================================================================ turrets
local MOD_COLOURS = { Damage = C.Red, Range = C.Green, Rate = C.Blue, Beacon = C.Gold }
local function skinMat(skin: string, coloured: boolean): Enum.Material
	if skin == "neon" and coloured then
		return Enum.Material.Neon
	elseif skin == "gold" then
		return Enum.Material.Foil
	elseif skin == "retro" then
		return Enum.Material.SmoothPlastic
	end
	return Enum.Material.Metal
end

-- Returns model, head (the part that turns; nil for modifiers)
local function makeTurret(kind: string, typ: string, skin: string, colour: string?)
	local m = Instance.new("Model")
	m.Name = kind
	local big = kind == "Sniper" or kind == "Fusion" or kind == "Railgun" or kind == "Orbital"
	local baseR = (if big then 17 else 13.5) * S
	local base = disc(baseR, 0.35, if skin == "gold" then hex("#d9b45a") else hex("#cdd2d6"), { Material = skinMat(skin, false), Name = "Base" })
	base.Parent = m
	local head = part({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Name = "Head" })
	head.Parent = m
	local parts = { { base, CFrame.new(0, 0.175, 0) * UPRIGHT } }
	local headParts = {}
	local function add(p: Part, offset: CFrame, onHead: boolean?)
		p.Parent = m
		table.insert(if onHead == false then parts else headParts, { p, offset })
		return p
	end
	local function col(name: string): Color3
		return C[name] or hex("#999999")
	end
	local mat = skinMat(skin, true)
	if typ == "modifier" then
		local c = C.Blue
		for key, v in MOD_COLOURS do
			if string.find(kind, key) then
				c = v
			end
		end
		add(disc(0.9, 0.25, c, { Material = mat }), CFrame.new(0, 0.45, 0) * UPRIGHT, false)
		local cross = if string.find(kind, "Exchange") then hex("#1b1b1b") else Color3.new(1, 1, 1)
		add(part({ Size = Vector3.new(1.0, 0.08, 0.22), Color = cross }), CFrame.new(0, 0.6, 0), false)
		add(part({ Size = Vector3.new(0.22, 0.08, 1.0), Color = cross }), CFrame.new(0, 0.6, 0), false)
		if string.find(kind, "Big") or kind == "Beacon" then
			add(disc(1.12, 0.12, C.Gold, { Material = Enum.Material.Neon }), CFrame.new(0, 0.38, 0) * UPRIGHT, false)
		end
		return m, nil, parts, headParts
	end
	if kind == "Blue" then
		add(disc(1.0, 0.4, C.Blue, { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(part({ Size = Vector3.new(1.1, 0.35, 1.2), Color = hex("#a8bedb") }), CFrame.new(0, 0.7, 0))
		add(part({ Size = Vector3.new(1.6, 0.4, 0.52), Color = hex("#2b2b2b") }), CFrame.new(1.0, 0.75, 0))
	elseif kind == "Green" then
		add(disc(1.0, 0.4, C.Green, { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(part({ Size = Vector3.new(1.1, 0.35, 1.0), Color = hex("#e1f0e2") }), CFrame.new(-0.05, 0.7, 0))
		add(part({ Size = Vector3.new(1.3, 0.4, 0.7), Color = hex("#1d7a2b") }), CFrame.new(0.95, 0.72, 0))
		add(part({ Size = Vector3.new(0.3, 0.42, 0.4), Color = hex("#c8ffbd"), Material = Enum.Material.Neon }), CFrame.new(1.55, 0.72, 0))
	elseif kind == "Red" then
		add(part({ Size = Vector3.new(2.1, 0.4, 2.1), Color = hex("#2f2f2f") }), CFrame.new(0, 0.5, 0))
		add(part({ Size = Vector3.new(1.8, 0.45, 1.8), Color = C.Red, Material = mat }), CFrame.new(0, 0.6, 0))
		for i = 0, 2 do
			for j = 0, 2 do
				add(disc(0.19, 0.1, hex("#ffd23f")), CFrame.new(-0.55 + i * 0.55, 0.86, -0.55 + j * 0.55) * UPRIGHT)
			end
		end
	elseif kind == "Yellow" then
		for i = 0, 7 do
			local a = i * math.pi / 4
			add(part({ Size = Vector3.new(0.5, 0.3, 0.4), Color = hex("#535353") }), CFrame.Angles(0, -a, 0) * CFrame.new(1.05, 0.5, 0))
		end
		add(disc(0.95, 0.45, C.Yellow, { Material = mat }), CFrame.new(0, 0.55, 0) * UPRIGHT)
		add(disc(0.4, 0.5, hex("#6b5300")), CFrame.new(0, 0.6, 0) * UPRIGHT)
	elseif kind == "Sniper" then
		add(disc(1.2, 0.4, hex("#565656"), { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(part({ Size = Vector3.new(2.7, 0.3, 0.4), Color = hex("#202020") }), CFrame.new(1.35, 0.75, 0))
		add(part({ Size = Vector3.new(1.2, 0.4, 1.2), Color = hex("#c2c2c2") }), CFrame.new(0, 0.75, 0))
	elseif kind == "Fusion" then
		add(disc(1.2, 0.4, hex("#7a3cc2"), { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Color = C.Yellow, Material = Enum.Material.Neon }), CFrame.new(0, 0.75, 0))
		add(part({ Size = Vector3.new(1.6, 0.4, 0.6), Color = hex("#333333") }), CFrame.new(1.4, 0.7, 0))
	elseif kind == "Railgun" then
		add(disc(1.2, 0.4, hex("#2d6a7a"), { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(part({ Size = Vector3.new(2.5, 0.3, 0.3), Color = hex("#1e1e1e") }), CFrame.new(1.25, 0.75, -0.3))
		add(part({ Size = Vector3.new(2.5, 0.3, 0.3), Color = hex("#1e1e1e") }), CFrame.new(1.25, 0.75, 0.3))
		add(part({ Size = Vector3.new(2.1, 0.2, 0.2), Color = hex("#77ffff"), Material = Enum.Material.Neon }), CFrame.new(1.25, 0.75, 0))
	elseif kind == "Targeter" then
		add(disc(0.9, 0.4, hex("#444444"), { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(disc(0.6, 0.45, hex("#ff4d4d"), { Material = Enum.Material.Neon, Transparency = 0.3 }), CFrame.new(0, 0.55, 0) * UPRIGHT)
		add(part({ Size = Vector3.new(1.4, 0.12, 0.12), Color = hex("#ff4d4d"), Material = Enum.Material.Neon }), CFrame.new(0.7, 0.8, 0))
	elseif kind == "Combonly" then
		add(disc(1.0, 0.3, hex("#666666"), { Material = mat }), CFrame.new(0, 0.45, 0) * UPRIGHT)
		add(disc(0.7, 0.45, col(colour or ""), { Material = Enum.Material.Neon, Name = "Core" }), CFrame.new(0, 0.55, 0) * UPRIGHT)
		add(part({ Size = Vector3.new(1.4, 0.35, 0.5), Color = hex("#222222") }), CFrame.new(1.0, 0.65, 0))
	elseif kind == "Orange" then
		add(disc(1.05, 0.45, C.Orange, { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(part({ Size = Vector3.new(1.1, 0.7, 0.8), Color = hex("#4a3420") }), CFrame.new(0.55, 0.9, 0) * CFrame.Angles(0, 0, math.rad(25)))
	elseif kind == "Cyan" then
		add(disc(1.0, 0.4, C.Cyan, { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		for i = 0, 2 do
			add(part({ Size = Vector3.new(1.4, 0.1, 0.16), Color = hex("#e9fdff"), Material = Enum.Material.Neon }), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, i * math.pi / 3, 0))
		end
	elseif kind == "Violet" then
		add(disc(1.0, 0.4, C.Violet, { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(part({ Size = Vector3.new(0.18, 1.0, 0.18), Color = hex("#d8c8ff") }), CFrame.new(0, 1.0, 0))
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = hex("#e6d6ff"), Material = Enum.Material.Neon }), CFrame.new(0, 1.55, 0))
	elseif kind == "Vault" then
		add(part({ Size = Vector3.new(1.7, 0.9, 1.7), Color = C.Gold, Material = Enum.Material.Foil }), CFrame.new(0, 0.75, 0), false)
		add(disc(0.45, 0.1, hex("#7a5a10")), CFrame.new(0, 1.22, 0) * UPRIGHT, false)
		return m, nil, parts, headParts
	elseif kind == "Orbital" then
		add(disc(1.4, 0.4, hex("#e8edf2"), { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
		add(disc(1.0, 0.15, hex("#9cc9ff"), { Material = Enum.Material.Glass, Transparency = 0.2 }), CFrame.new(0.2, 0.95, 0) * CFrame.Angles(0, 0, math.rad(60)))
	else
		add(disc(1.0, 0.4, hex("#888888"), { Material = mat }), CFrame.new(0, 0.5, 0) * UPRIGHT)
	end
	return m, head, parts, headParts
end

-- Pips under a weapon turret: damage / range / rate progress (like the original's bars)
local PIP_COLOURS = { C.Red, C.Green, C.Blue }
local PIP_STATS = { "damage", "range", "rate" }

-- details: Snapshot.turretDetails list. upMax(kind, stat) comes from the client's data.
function Board:setTurrets(details, upMax, skinOf)
	local seen = {}
	for _, d in details do
		seen[d.id] = true
		local t = self.turrets[d.id]
		local skin = skinOf(d.owner)
		local look = d.kind .. "|" .. skin .. "|" .. tostring(d.colour)
		if t and t.look ~= look then
			t.model:Destroy()
			self.turrets[d.id] = nil
			t = nil
		end
		if not t then
			local m, head, parts, headParts = makeTurret(d.kind, d.type, skin, d.colour)
			local pips = {}
			if d.type == "weapon" then
				for i, c in PIP_COLOURS do
					local back = part({ Size = Vector3.new(1.8, 0.05, 0.16), Color = Color3.new(0, 0, 0), Transparency = 0.6, Parent = m })
					local fill = part({ Size = Vector3.new(0.01, 0.06, 0.16), Color = c, Parent = m })
					pips[i] = { back, fill }
				end
			end
			m.Parent = self.dyn
			t = { model = m, head = head, parts = parts, headParts = headParts, pips = pips, look = look, rot = 0, baseColor = parts[1][1].Color }
			self.turrets[d.id] = t
		end
		t.x, t.y, t.d = d.x, d.y, d
		local origin = CFrame.new(P(d.x, d.y))
		for _, pr in t.parts do
			pr[1].CFrame = origin * pr[2]
		end
		for i, pp in t.pips do
			local stat = PIP_STATS[i]
			local mx = upMax(d.kind, stat)
			local frac = if mx > 0 then d.lvl[stat] / mx else 0
			local y = d.y + 16 + (i - 1) * 3
			pp[1].CFrame = CFrame.new(P(d.x, y, 0.4))
			pp[2].Size = Vector3.new(math.max(0.01, 1.8 * frac), 0.06, 0.16)
			pp[2].CFrame = CFrame.new(P(d.x - 9 + 9 * frac, y, 0.41))
			pp[1].Transparency = if mx > 0 then 0.6 else 1
			pp[2].Transparency = if mx > 0 then 0 else 1
		end
		self:aimTurret(t, t.rot)
	end
	for id, t in self.turrets do
		if not seen[id] then
			t.model:Destroy()
			self.turrets[id] = nil
		end
	end
end
function Board:aimTurret(t, rot: number)
	t.rot = rot
	if not t.head then
		return
	end
	local cf = CFrame.new(P(t.x, t.y)) * CFrame.Angles(0, -math.rad(rot), 0)
	for _, pr in t.headParts do
		pr[1].CFrame = cf * pr[2]
	end
end

-- ================================================================ attackers (9 looks, from the HTML)
local function makeAttacker(typ: number)
	local m = Instance.new("Model")
	local partsList = {}
	local function add(p: Part, offset: CFrame)
		p.Parent = m
		table.insert(partsList, { p, offset })
	end
	if typ == 0 then -- tank
		add(part({ Size = Vector3.new(1.4, 0.6, 1.2), Color = hex("#8d9296") }), CFrame.new(0, 0.4, 0))
		add(part({ Size = Vector3.new(1.6, 0.4, 0.3), Color = hex("#4d5155") }), CFrame.new(0, 0.3, -0.6))
		add(part({ Size = Vector3.new(1.6, 0.4, 0.3), Color = hex("#4d5155") }), CFrame.new(0, 0.3, 0.6))
		add(part({ Size = Vector3.new(0.9, 0.25, 0.4), Color = hex("#cfd3d6") }), CFrame.new(0.25, 0.8, 0))
	elseif typ == 1 then -- red bug
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 0.8, 1.1), Color = hex("#c0342a") }), CFrame.new(0, 0.4, 0))
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = hex("#222222") }), CFrame.new(0.7, 0.45, 0))
		for i = -1, 1 do
			add(part({ Size = Vector3.new(0.08, 0.08, 1.8), Color = hex("#333311") }), CFrame.new(i * 0.35, 0.3, 0))
		end
	elseif typ == 2 then -- white truck
		add(part({ Size = Vector3.new(1.6, 0.7, 1.0), Color = hex("#ececec") }), CFrame.new(0, 0.45, 0))
		add(part({ Size = Vector3.new(0.4, 0.5, 0.8), Color = hex("#7799aa") }), CFrame.new(0.3, 0.6, 0))
	elseif typ == 3 then -- jellyfish
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 0.9, 1.0), Color = hex("#a56bd6") }), CFrame.new(-0.1, 0.5, 0))
		for i = -2, 2 do
			add(part({ Size = Vector3.new(0.8, 0.08, 0.08), Color = hex("#a56bd6") }), CFrame.new(-0.9, 0.35, i * 0.25))
		end
	elseif typ == 4 then -- eyeball
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Color = Color3.new(1, 1, 1) }), CFrame.new(0, 0.6, 0))
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Color = hex("#c0342a") }), CFrame.new(0.5, 0.75, 0))
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = Color3.new(0, 0, 0) }), CFrame.new(0.72, 0.8, 0))
	elseif typ == 5 then -- robot
		add(part({ Size = Vector3.new(1.2, 1.0, 1.4), Color = hex("#7a7f86") }), CFrame.new(0, 0.55, 0))
		add(part({ Size = Vector3.new(0.1, 0.3, 0.3), Color = C.Yellow, Material = Enum.Material.Neon }), CFrame.new(0.62, 0.7, -0.25))
		add(part({ Size = Vector3.new(0.1, 0.3, 0.3), Color = C.Yellow, Material = Enum.Material.Neon }), CFrame.new(0.62, 0.7, 0.25))
	elseif typ == 6 then -- saucer
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 0.5, 1.0), Color = hex("#b9c4cc"), Material = Enum.Material.Metal }), CFrame.new(0, 0.5, 0))
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.6, 0.7), Color = hex("#6fd3ff"), Material = Enum.Material.Glass }), CFrame.new(0, 0.75, 0))
	elseif typ == 7 then -- beetle
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 0.8, 1.2), Color = hex("#4e8f2a") }), CFrame.new(0, 0.45, 0))
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = hex("#222222") }), CFrame.new(0.8, 0.45, 0))
	else -- helicopter
		add(part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 0.7, 0.8), Color = hex("#56603e") }), CFrame.new(0, 0.6, 0))
		add(part({ Size = Vector3.new(0.7, 0.15, 0.15), Color = hex("#56603e") }), CFrame.new(-1.0, 0.6, 0))
		add(part({ Size = Vector3.new(2.2, 0.05, 0.12), Color = hex("#222222"), Name = "Rotor" }), CFrame.new(0, 1.0, 0))
	end
	for _, pr in partsList do
		pr[1].CastShadow = true
	end
	-- HP % label (the original prints it above every attacker)
	local anchor = part({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, Parent = m })
	table.insert(partsList, { anchor, CFrame.new(0, 1.0, -1.1) })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(40, 16)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local label = Ui.new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextColor3 = hex("#111111"), TextStrokeColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5, FontFace = Ui.BOLD, TextSize = 11, Text = "100", Parent = bb,
	})
	return m, partsList, label
end
local ROTATES = { [0] = false, true, false, true, true, true, false, true, true }

-- ================================================================ snapshots and frames
function Board:pushSnapshot(snap)
	snap.at = os.clock()
	table.insert(self.snaps, snap)
	if #self.snaps > 6 then
		table.remove(self.snaps, 1)
	end
end

local function lerpAngle(a: number, b: number, t: number): number
	local d = (b - a + 180) % 360 - 180
	return a + d * t
end

function Board:render(_dt: number)
	local snaps = self.snaps
	if #snaps == 0 then
		self:tickEffects()
		return
	end
	local rt = os.clock() - DELAY
	local a, b = snaps[1], snaps[1]
	for i = 1, #snaps - 1 do
		if snaps[i].at <= rt and snaps[i + 1].at >= rt then
			a, b = snaps[i], snaps[i + 1]
			break
		end
		if snaps[i + 1].at < rt then
			a, b = snaps[i + 1], snaps[i + 1]
		end
	end
	local t = if b.at > a.at then math.clamp((rt - a.at) / (b.at - a.at), 0, 1) else 1
	-- index the earlier snapshot by id
	local prevA = {}
	for _, x in a.attackers do
		prevA[x.id] = x
	end
	local seen = {}
	local now = os.clock()
	for _, x in b.attackers do
		local p0 = prevA[x.id] or x
		local ax, ay = p0.x + (x.x - p0.x) * t, p0.y + (x.y - p0.y) * t
		local rot = lerpAngle(p0.rot, x.rot, t)
		seen[x.id] = true
		local v = self.attackers[x.id]
		if not v then
			local m, partsList, label = makeAttacker(x.type)
			m.Parent = self.dyn
			v = { model = m, parts = partsList, label = label, born = now, type = x.type }
			self.attackers[x.id] = v
		end
		local sc = (1 + ((x.scale or 1) - 1) * 0.06) * (if x.holed then 0.35 else 1)
		local spin = if x.holed then now * 6 else 0
		local cf = CFrame.new(P(ax, ay)) * CFrame.Angles(0, -math.rad(if ROTATES[x.type] then rot else 0) - spin, 0)
		for _, pr in v.parts do
			local off = pr[2]
			pr[1].CFrame = cf * CFrame.new(off.Position * sc) * off.Rotation
		end
		if x.type == 8 then
			local rotor = v.model:FindFirstChild("Rotor")
			if rotor then
				rotor.CFrame = cf * CFrame.new(0, 1.0 * sc, 0) * CFrame.Angles(0, now * 25, 0)
			end
		end
		v.label.Text = tostring(x.hp)
		v.label.TextColor3 = if x.slow > 0 then hex("#0d6f7c") else hex("#111111")
		v.label.Visible = not x.holed
	end
	for id, v in self.attackers do
		if not seen[id] then
			v.model:Destroy()
			self.attackers[id] = nil
		end
	end
	-- turrets aim
	for id, td in b.turrets do
		local tv = self.turrets[id]
		if tv then
			local r0 = a.turrets[id] and a.turrets[id].rot or td.rot
			self:aimTurret(tv, lerpAngle(r0, td.rot, t))
			if tv.d and tv.d.type == "weapon" then
				local glow = td.ready and 0.55 or 0
				local base = tv.parts[1] and tv.parts[1][1]
				if base then
					base.Color = if td.freak >= 2 then C.Red elseif glow > 0 then hex("#ffe58a") else tv.baseColor
				end
			end
		end
	end
	self:renderShots(a, b, t)
	self:tickEffects()
end

-- ================================================================ shots
local VARIANT_COLOURS = {
	nuke = hex("#222222"), napalm = hex("#ff7a00"), poison = hex("#5bd13a"), tazerrocket = C.Yellow, laserrocket = C.Green, rocket = C.Red,
}
function Board:renderShots(a, b, t)
	local prev = {}
	for _, s in a.shots do
		prev[s.id] = s
	end
	local seen = {}
	for _, s in b.shots do
		local p0 = prev[s.id] or s
		local x, y = p0.x + (s.x - p0.x) * t, p0.y + (s.y - p0.y) * t
		seen[s.id] = true
		local v = self.shots[s.id]
		local key = s.k .. ":" .. (if s.k == "rocket" then s.variant else "")
		if v and v.key ~= key then
			v.part:Destroy()
			v = nil
		end
		if not v then
			local p
			if s.k == "rocket" then
				if s.variant == "bfg" or s.variant == "bfgtazer" then
					p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), Color = if s.variant == "bfg" then hex("#3cff5a") else C.Yellow, Material = Enum.Material.Neon, Transparency = 0.15 })
				else
					local big = s.variant ~= "rocket"
					p = part({ Size = if big then Vector3.new(1.3, 0.5, 0.5) else Vector3.new(0.9, 0.3, 0.3), Color = VARIANT_COLOURS[s.variant] or C.Red })
				end
			elseif s.k == "hole" then
				p = disc(1, 0.06, Color3.new(0.05, 0, 0.1), { Material = Enum.Material.Neon, Transparency = 0.1 })
			elseif s.k == "field" then
				p = disc(1, 0.2, C.Violet, { Material = Enum.Material.ForceField, Transparency = 0.2 })
			elseif s.k == "walker" then
				p = disc(0.8, 0.1, hex("#56ff55"), { Material = Enum.Material.Neon, Transparency = 0.3 })
			elseif s.k == "mine" then
				p = disc(if s.big then 0.55 else 0.45, 0.2, hex("#3a3a3a"))
			elseif s.k == "napalm" or s.k == "carpet" or s.k == "rail" then
				p = part({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 }) -- invisible emitters: their effects show as fx
			else -- shell, bomb, mortar
				p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = hex("#222222") })
			end
			p.Parent = self.dyn
			v = { part = p, key = key }
			self.shots[s.id] = v
		end
		local h = if s.k == "mortar" then 1.5 else 0.8
		local cf = CFrame.new(P(x, y, h))
		if s.k == "rocket" then
			cf *= CFrame.Angles(0, -math.rad(s.rot), 0)
		elseif s.k == "hole" or s.k == "field" or s.k == "walker" then
			local r = math.max(0.3, s.r * S)
			v.part.Size = Vector3.new(v.part.Size.X, r * 2, r * 2)
			cf = CFrame.new(P(x, y, 0.06)) * UPRIGHT
		elseif s.k == "mine" then
			cf = CFrame.new(P(x, y, 0.12)) * UPRIGHT
			v.part.Color = if s.planted and (os.clock() * 4) % 2 < 1 then hex("#ff3b30") else hex("#3a3a3a")
		end
		v.part.CFrame = cf
	end
	for id, v in self.shots do
		if not seen[id] then
			v.part:Destroy()
			self.shots[id] = nil
		end
	end
end

-- ================================================================ effects
local function laserStyle(d: number): (Color3, number)
	if d < 400 then
		return hex("#00ff00"), 1.5
	elseif d < 9300 then
		return hex("#ffff00"), 3
	elseif d < 60000 then
		return hex("#ff2020"), 5
	elseif d < 400000 then
		return hex("#660198"), 6
	elseif d < 1e6 then
		return hex("#ff007f"), 7
	end
	return hex("#42c0fb"), 8
end
local BLAST_COLOURS = {
	poison = hex("#78dc3c"), bfg = hex("#50ff78"), shockwave = hex("#82c8ff"), huge = hex("#ff8c28"), tiny = hex("#ff781e"),
}

function Board:beam(key: string, x1, y1, x2, y2, width: number, color: Color3, life: number, h: number?)
	local p = self:pool("beam", function()
		return part({ Material = Enum.Material.Neon, Size = Vector3.new(1, 0.1, 0.1) })
	end)
	local a, b = P(x1, y1, h or 0.9), P(x2, y2, h or 0.9)
	local len = (b - a).Magnitude
	p.Size = Vector3.new(math.max(0.05, len), width * S, width * S)
	p.CFrame = along(a, b)
	p.Color = color
	p.Transparency = 0
	table.insert(self.effects, { pool = "beam", o = p, born = os.clock(), life = life, fade = true, key = key })
end

function Board:popText(text: string, x: number, y: number, color: Color3, size: number, life: number)
	local anchor = self:pool("text", function()
		local a = part({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 })
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(160, 24)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Parent = a
		Ui.new("TextLabel", {
			Name = "L", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = Ui.BOLD, TextSize = 12,
			TextStrokeTransparency = 0.6, TextStrokeColor3 = Color3.new(1, 1, 1), Parent = bb,
		})
		return a
	end)
	local label = anchor:FindFirstChildOfClass("BillboardGui").L
	label.Text, label.TextColor3, label.TextSize, label.TextTransparency = text, color, size, 0
	anchor.CFrame = CFrame.new(P(x, y, 1.5))
	table.insert(self.effects, { pool = "text", o = anchor, born = os.clock(), life = life, rise = true, x = x, y = y, label = label })
end

function Board:ring(x: number, y: number, r0: number, r1: number, color: Color3, life: number, material: Enum.Material?)
	local p = self:pool("ring", function()
		return disc(1, 0.08, Color3.new(1, 1, 1), { Material = Enum.Material.Neon })
	end)
	p.Color = color
	p.Material = material or Enum.Material.Neon
	table.insert(self.effects, { pool = "ring", o = p, born = os.clock(), life = life, grow = { r0, r1 }, x = x, y = y })
end

function Board:blast(x: number, y: number, size: number, typ: string)
	local p = self:pool("blast", function()
		return part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Size = Vector3.new(1, 1, 1) })
	end)
	p.Color = BLAST_COLOURS[typ] or hex("#ffaf32")
	table.insert(self.effects, { pool = "blast", o = p, born = os.clock(), life = if size > 180 then 1.1 else 0.7, sphere = size / 2, x = x, y = y })
end

function Board:spark(x1, y1, x2, y2, look: string?)
	local big = look == "fusion" or look == "shock"
	local color = if big then hex("#bfe8ff") elseif look == "cluster" then hex("#ffe066") elseif look == "arc" then hex("#d6b8ff") else hex("#fff38a")
	local n = math.clamp(math.floor(math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) / 18), 2, 6)
	local px, py = x1, y1
	for i = 1, n do
		local nx = x1 + (x2 - x1) * i / n + (if i < n then (math.random() - 0.5) * 12 else 0)
		local ny = y1 + (y2 - y1) * i / n + (if i < n then (math.random() - 0.5) * 12 else 0)
		self:beam("spark", px, py, nx, ny, if big then 2.5 else 1.5, color, 0.35)
		px, py = nx, ny
	end
end

-- Engine fx (decoded from the snapshot) -> visuals. UI-level kinds (wave, life, gameover...) go to the HUD.
function Board:playFx(list)
	for _, f in list do
		local k = f.k
		if k == "laser" then
			local c, w = laserStyle(f.dmg)
			self:beam("laser", f.x1, f.y1, f.x2, f.y2, w, c, 0.3)
		elseif k == "spark" then
			self:spark(f.x1, f.y1, f.x2, f.y2, f.look)
		elseif k == "rail" then
			self:beam("rail", f.x1, f.y1, f.x2, f.y2, 14, hex("#77ffff"), 0.18)
			self:beam("rail", f.x1, f.y1, f.x2, f.y2, 3, Color3.new(1, 1, 1), 0.18)
		elseif k == "sniper" then
			self:beam("sniper", f.x1, f.y1, f.x2, f.y2, 1, hex("#78783c"), 0.16)
		elseif k == "take" or k == "absorb" then
			self:beam("take", f.x1, f.y1, f.x2, f.y2, 2, C.Gold, 0.45)
		elseif k == "paint" then
			self:beam("paint", f.x1, f.y1, f.x2, f.y2, 1, hex("#ff4d4d"), 0.08)
		elseif k == "blast" then
			self:blast(f.x, f.y, f.size, f.type)
		elseif k == "kill" then
			self:popText("$" .. Ui.fmt(f.b), f.x, f.y - 14, hex("#12541a"), 11, 0.8)
		elseif k == "sell" then
			self:popText("+$" .. Ui.fmt(f.v), f.x, f.y - 16, hex("#12541a"), 13, 0.9)
		elseif k == "vault" then
			self:popText("+$" .. Ui.fmt(f.v), f.x, f.y - 18, hex("#7a5a10"), 13, 1.2)
		elseif k == "combo" then
			self:popText(Ui.comboName(f.name) .. "!", f.x, f.y - 24, hex("#6a0f0f"), 15, 1.4)
			self:ring(f.x, f.y, 14, 64, C.Gold, 0.7)
		elseif k == "cryo" or k == "freezewave" then
			self:ring(f.x, f.y, f.r * 0.3, f.r, C.Cyan, 0.5, Enum.Material.ForceField)
		elseif k == "orbital" then
			local p = self:pool("column", function()
				return disc(1, 60, hex("#96d2ff"), { Material = Enum.Material.Neon })
			end)
			table.insert(self.effects, { pool = "column", o = p, born = os.clock(), life = 0.6, column = true, x = f.x, y = f.y })
		elseif k == "swallow" then
			self:ring(f.x, f.y, 6, 0, hex("#3a0a50"), 0.4)
		end
	end
end

function Board:tickEffects()
	local now = os.clock()
	local keep = {}
	for _, e in self.effects do
		local p = (now - e.born) / e.life
		if p >= 1 then
			if e.label then
				e.label.TextTransparency = 1
			end
			self:release(e.pool, e.o)
			continue
		end
		if e.fade then
			e.o.Transparency = p
		elseif e.rise then
			e.o.CFrame = CFrame.new(P(e.x, e.y - p * 14, 1.5))
			e.label.TextTransparency = p
		elseif e.grow then
			local r = (e.grow[1] + (e.grow[2] - e.grow[1]) * p) * S
			e.o.Size = Vector3.new(0.08, math.max(0.05, r * 2), math.max(0.05, r * 2))
			e.o.CFrame = CFrame.new(P(e.x, e.y, 0.3)) * UPRIGHT
			e.o.Transparency = p
		elseif e.sphere then
			local r = e.sphere * math.min(1, 0.2 + p * 6) * S
			e.o.Size = Vector3.new(r * 2, r * 2, r * 2)
			e.o.CFrame = CFrame.new(P(e.x, e.y, 0))
			e.o.Transparency = 0.25 + 0.75 * p
		elseif e.column then
			local w = (10 * (1 - p) + 1) * S
			e.o.Size = Vector3.new(60, w * 2, w * 2)
			e.o.CFrame = CFrame.new(P(e.x, e.y, 30)) * UPRIGHT
			e.o.Transparency = p
		end
		table.insert(keep, e)
	end
	self.effects = keep
end

-- ================================================================ overlays: placement ghost, range rings
function Board:ensureOverlay()
	if self.overlay then
		return self.overlay
	end
	local o = {}
	o.range = disc(1, 0.04, hex("#cee878"), { Transparency = 0.72, Material = Enum.Material.SmoothPlastic, Parent = self.model })
	o.edge = ringParts(48, hex("#506e14"), 0.35, self.model)
	o.ghost = disc(1.35, 0.4, Color3.new(1, 1, 1), { Transparency = 0.4, Material = Enum.Material.Neon, Parent = self.model })
	o.cone = part({ Size = Vector3.new(1, 0.04, 0.1), Transparency = 1, Color = hex("#ffcf4a"), Material = Enum.Material.Neon, Parent = self.model })
	self.overlay = o
	self:hideOverlay()
	return o
end
function Board:hideOverlay()
	local o = self:ensureOverlay()
	o.range.CFrame, o.ghost.CFrame, o.cone.CFrame = FAR, FAR, FAR
	for _, p in o.edge do
		p.CFrame = FAR
	end
end
-- range ring at (x,y); ghost: nil | true (can build) | false (blocked)
function Board:showRange(x: number, y: number, range: number, ghost: boolean?)
	local o = self:ensureOverlay()
	local r = math.max(0.1, range * S)
	o.range.Size = Vector3.new(0.04, r * 2, r * 2)
	o.range.CFrame = CFrame.new(P(x, y, 0.05)) * UPRIGHT
	placeRing(o.edge, x, y, range, 0.07, 0.15)
	if ghost == nil then
		o.ghost.CFrame = FAR
	else
		o.ghost.Color = if ghost then hex("#7bd88f") else hex("#ff5f57")
		o.ghost.CFrame = CFrame.new(P(x, y, 0.25)) * UPRIGHT
	end
end

function Board:destroy()
	self.model:Destroy()
	self.turrets, self.attackers, self.shots, self.effects = {}, {}, {}, {}
end

return Board
