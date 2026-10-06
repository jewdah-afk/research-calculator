--!nonstrict
-- Builds the plaza once at server start (static, anchored, replicated once):
--   * a 512x512 grid baseplate, fenced with stone walls + pillars, landscape outside
--   * the shared Mega Board at the north end (backboard, frame, pegs, slot dividers)
--   * one stand per Unlocks.STANDS entry, in order down the path towards spawn
-- Clients decide locally what each stand looks like (hidden / ??? silhouette / open).

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MB = require(Shared.MegaBoard)
local Unlocks = require(Shared.Unlocks)

local MapBuilder = {}

local GRID_TEXTURE = "rbxassetid://6372755229" -- Roblox's default baseplate grid
local HALF = 256

local root

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or root
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

---------------------------------------------------------------- ground + fence + landscape

local function buildGround()
	local base = part({ Name = "Baseplate", Size = Vector3.new(HALF * 2, 4, HALF * 2), Position = Vector3.new(0, -2, 0), Color = Color3.fromRGB(70, 74, 92), Material = Enum.Material.SmoothPlastic })
	local tex = Instance.new("Texture")
	tex.Texture = GRID_TEXTURE
	tex.Face = Enum.NormalId.Top
	tex.StudsPerTileU, tex.StudsPerTileV = 8, 8
	tex.Transparency = 0.6
	tex.Parent = base
	-- grass outside the fence
	part({ Name = "Grass", Size = Vector3.new(1100, 4, 1100), Position = Vector3.new(0, -2.2, 0), Color = Color3.fromRGB(78, 140, 70), Material = Enum.Material.Grass })
	-- central path from spawn to the board
	part({ Name = "Path", Size = Vector3.new(26, 0.2, 380), Position = Vector3.new(0, 0.1, 0), Color = Color3.fromRGB(50, 44, 70) })
end

local function buildFence()
	local f = folder("Fence")
	local H, T = 14, 3
	local stone, cap = Color3.fromRGB(96, 92, 110), Color3.fromRGB(150, 140, 170)
	local sides = {
		{ Vector3.new(0, 0, -HALF), Vector3.new(HALF * 2, 0, 0) },
		{ Vector3.new(0, 0, HALF), Vector3.new(HALF * 2, 0, 0) },
		{ Vector3.new(-HALF, 0, 0), Vector3.new(0, 0, HALF * 2) },
		{ Vector3.new(HALF, 0, 0), Vector3.new(0, 0, HALF * 2) },
	}
	for _, s in sides do
		local c, len = s[1], s[2]
		local along = len.X > 0
		local size = if along then Vector3.new(len.X, H, T) else Vector3.new(T, H, len.Z)
		part({ Name = "Wall", Size = size, Position = c + Vector3.new(0, H / 2, 0), Color = stone, Material = Enum.Material.Cobblestone, Parent = f })
		part({ Name = "Cap", Size = size + Vector3.new(along and 0 or 1.5, -H + 1.5, along and 1.5 or 0), Position = c + Vector3.new(0, H + 0.75, 0), Color = cap, Parent = f })
		-- pillars every 32 studs
		local n = math.floor((along and len.X or len.Z) / 32)
		for i = 0, n do
			local t = -HALF + i * 32
			local pos = if along then Vector3.new(t, 0, c.Z) else Vector3.new(c.X, 0, t)
			part({ Name = "Pillar", Size = Vector3.new(5, H + 4, 5), Position = pos + Vector3.new(0, (H + 4) / 2, 0), Color = cap, Material = Enum.Material.Slate, Parent = f })
		end
	end
end

local function buildLandscape()
	local f = folder("Landscape")
	local rng = Random.new(7)
	local leafColors = { Color3.fromRGB(56, 128, 64), Color3.fromRGB(80, 150, 70), Color3.fromRGB(44, 110, 80) }
	-- ring of trees + rocks just outside the fence
	for i = 1, 90 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(285, 420)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if math.abs(x) < 275 and math.abs(z) < 275 then
			continue
		end
		if rng:NextNumber() < 0.7 then
			local h = rng:NextNumber(14, 30)
			part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 3, 3), CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(105, 72, 48), Material = Enum.Material.Wood, CanCollide = false, Parent = f })
			local s = rng:NextNumber(14, 24)
			part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Position = Vector3.new(x, h + s * 0.3, z), Color = leafColors[rng:NextInteger(1, 3)], Material = Enum.Material.Grass, CanCollide = false, Parent = f })
		else
			local s = rng:NextNumber(6, 16)
			part({ Name = "Rock", Size = Vector3.new(s, s * 0.7, s * 1.2), CFrame = CFrame.new(x, s * 0.25, z) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(120, 118, 128), Material = Enum.Material.Rock, Parent = f })
		end
	end
	-- low hills on the horizon
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		local r = 520
		local s = rng:NextNumber(120, 200)
		part({ Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.6, s, s * 1.6), Position = Vector3.new(math.cos(a) * r, -s * 0.25, math.sin(a) * r), Color = Color3.fromRGB(70, 128, 66), Material = Enum.Material.Grass, CanCollide = false, Parent = f })
	end
end

---------------------------------------------------------------- the Mega Board

local function buildBoard()
	local f = folder("MegaBoard")
	local S = MB.STUD
	local w, h = MB.W * S, MB.H * S
	local cf = MB.CF
	-- backboard + frame
	part({ Name = "Backboard", Size = Vector3.new(w + 8, h + 8, 2), CFrame = cf * CFrame.new(0, h / 2, -2), Color = Color3.fromRGB(24, 14, 50), Parent = f })
	for _, side in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(6, h + 14, 8), CFrame = cf * CFrame.new(side * (w / 2 + 3), h / 2, 1), Color = Color3.fromRGB(255, 196, 60), Material = Enum.Material.Metal, Parent = f })
	end
	part({ Name = "TopRail", Size = Vector3.new(w + 18, 6, 8), CFrame = cf * CFrame.new(0, h + 6, 1), Color = Color3.fromRGB(255, 196, 60), Material = Enum.Material.Metal, Parent = f })
	-- legs down to the ground behind the lean
	for _, side in { -1, 1 } do
		part({ Name = "Leg", Size = Vector3.new(8, MB.BOTTOM.Y + 4, 8), Position = Vector3.new(side * (w / 2 + 3), (MB.BOTTOM.Y + 4) / 2 - 2, MB.BOTTOM.Z), Color = Color3.fromRGB(60, 52, 80), Parent = f })
	end
	-- pegs: cylinders sticking out of the board
	local pegs = folder("Pegs", f)
	for _, p in MB.pegs() do
		local d = p.r * 2 * S
		part({
			Name = p.big and "Bumper" or "Peg",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(p.big and 5 or 4, d, d),
			CFrame = CFrame.new(MB.toWorld(p.x, p.y, (p.big and 5 or 4) / 2)) * (cf - cf.Position) * CFrame.Angles(0, math.rad(90), 0),
			Color = p.big and Color3.fromRGB(255, 196, 60) or Color3.fromRGB(233, 228, 255),
			Material = p.big and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
			Parent = pegs,
		})
	end
	-- slot strip: dividers + one panel per slot (clients write their own multipliers on them)
	local slots = folder("Slots", f)
	local edges = MB.slotEdges()
	for i, x in edges do
		part({ Name = "Divider", Size = Vector3.new(2, MB.SLOT_H * S, 4), CFrame = (cf - cf.Position) + MB.toWorld(x, MB.H - MB.SLOT_H / 2, 2), Color = Color3.fromRGB(255, 196, 60), Material = Enum.Material.Metal, Parent = slots })
		if i < #edges then
			local x2 = edges[i + 1]
			local panel = part({ Name = "Slot" .. i, Size = Vector3.new((x2 - x) * S - 2, MB.SLOT_H * S, 1), CFrame = (cf - cf.Position) + MB.toWorld((x + x2) / 2, MB.H - MB.SLOT_H / 2, 0.5), Color = Color3.fromRGB(46, 30, 90), Parent = slots })
			panel:SetAttribute("X0", x)
			panel:SetAttribute("X1", x2)
		end
	end
	-- title sign
	local sign = part({ Name = "Title", Size = Vector3.new(160, 22, 2), CFrame = cf * CFrame.new(0, h + 22, 1), Color = Color3.fromRGB(24, 14, 50), Parent = f })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 8
	sg.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "THE MEGA BOARD"
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 214, 74)
	t.Parent = sg
end

---------------------------------------------------------------- stands

-- two rows down the path, starting next to the board: cash, gems | spawners, rebirth | ...
local function standPosition(i)
	local row = math.floor((i - 1) / 2)
	local side = (i % 2 == 1) and -1 or 1
	return Vector3.new(side * 34, 0, -150 + row * 60)
end

local function buildStands()
	local f = folder("Stands")
	for i, s in Unlocks.STANDS do
		local m = Instance.new("Model")
		m.Name = s.id
		m:SetAttribute("StandId", s.id)
		local pos = standPosition(i)
		local facing = CFrame.lookAt(pos, Vector3.new(0, 0, pos.Z)) -- face the path
		local col = rgb(s.color)
		part({ Name = "Base", Size = Vector3.new(18, 1.5, 18), CFrame = facing * CFrame.new(0, 0.75, 0), Color = Color3.fromRGB(40, 32, 60), Parent = m })
		part({ Name = "Pedestal", Size = Vector3.new(10, 5, 10), CFrame = facing * CFrame.new(0, 4, 0), Color = Color3.fromRGB(60, 50, 90), Parent = m })
		local display = part({ Name = "Display", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = facing * CFrame.new(0, 10, 0), Color = col, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
		display:SetAttribute("Spin", true)
		for _, sx in { -7, 7 } do
			part({ Name = "Post", Size = Vector3.new(1.2, 14, 1.2), CFrame = facing * CFrame.new(sx, 7, 7), Color = col, Parent = m })
		end
		local roof = part({ Name = "Roof", Size = Vector3.new(17, 1.5, 6), CFrame = facing * CFrame.new(0, 14.5, 6), Color = col, Parent = m })
		-- name sign (client swaps text for "???" while it's a silhouette)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Sign"
		bb.Size = UDim2.fromOffset(220, 60)
		bb.StudsOffset = Vector3.new(0, 4, 0)
		bb.MaxDistance = 160
		bb.AlwaysOnTop = false
		bb.Parent = roof
		local t = Instance.new("TextLabel")
		t.Name = "Label"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = s.name
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = col
		t.TextStrokeTransparency = 0
		t.Parent = bb
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = s.name
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false -- clients enable it once the stand is open for them
		prompt.Parent = display
		m.PrimaryPart = m:FindFirstChild("Base")
		m.Parent = f
	end
end

local function buildSpawn()
	local sp = Instance.new("SpawnLocation")
	sp.Anchored = true
	sp.Size = Vector3.new(16, 1, 16)
	sp.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 190), Vector3.new(0, 0.5, -200))
	sp.Color = Color3.fromRGB(255, 196, 60)
	sp.Material = Enum.Material.SmoothPlastic
	sp.Duration = 0
	sp.Parent = root
end

function MapBuilder.build()
	if workspace:FindFirstChild("OrbWorld") then
		return workspace.OrbWorld
	end
	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "OrbWorld"
	buildGround()
	buildFence()
	buildLandscape()
	buildBoard()
	buildStands()
	buildSpawn()
	root.Parent = workspace
	Lighting.ClockTime = 15
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 120, 160)
	return root
end

return MapBuilder
