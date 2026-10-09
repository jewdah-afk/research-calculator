--!nonstrict
-- Portals: the teleporter hub on the Park plaza (owner 2026-10-09: "a teleporter like Roblox, an animated portal in
-- the colour of its area, labelled nicely"). One portal per unlocked area stands in an arc on the plaza; each open
-- area also gets a "Park" portal by its arrival spot. Walking into a portal fires the existing teleport hop
-- (PlayerGui attribute PeckwoodTP), so the server sees the same move as the left-bar Teleport.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Map = require(Shared:WaitForChild("MapData"))
local Models = require(Shared:WaitForChild("Models"))
local World = require(Shared:WaitForChild("World"))
local S = Models.S

local Portals = {}
local plr = Players.LocalPlayer
local root
local list = {}   -- { id, dest, pos, model, ring, swirl, built }
local COL = { park = "7cc35a", garden = "ff8fc0", castle = "6aa8ff", bridge = "4fd2ff", forest = "4fd06a",
	mine = "ffb14a", desert = "ffd84a", expedition = "7dff86", echo = "b06cff" }
local HUB = if World.LAYOUT == "ascent" then Vector2.new(8, 38) else Vector2.new(20, 23)   -- plaza centre (world tile): Ascent plaza / inside the Park
local function hx(h) return Color3.fromHex(h) end
local function tileToWorld(i, j) return Vector3.new((i - Map.COLS / 2) * S, World.base(math.floor(i), math.floor(j)), (j - Map.ROWS / 2) * S) end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

-- an upright ring of glowing segments around a swirling disc, on a round stone pad, with a name sign
local PortalAsset = RS:WaitForChild("PortalAsset", 10)
local H = 7.5   -- arch height (studs)
local function build(id, name, pos, facing)
	local col = hx(COL[id] or "ffffff")
	local m = Instance.new("Model"); m.Name = "Portal_" .. id
	local cf = CFrame.lookAt(pos, pos + facing)
	-- the arch: generated stone portal model (falls back to a plain ring if the asset is missing)
	local holeW, holeY = 3.2, H * 0.6
	if PortalAsset then
		local a = PortalAsset:Clone()
		local bcf, bsz = a:GetBoundingBox()
		a.WorldPivot = CFrame.new(bcf.Position - Vector3.new(0, bsz.Y / 2, 0))
		a:ScaleTo(a:GetScale() * H / bsz.Y)
		local _, s2 = a:GetBoundingBox()
		holeW = s2.X * 0.6   -- round opening of the stone ring
		a:PivotTo(cf)
		for _, d in a:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end end
		a.Parent = m
	end
	local pad = part(m, { Name = "Pad", Size = Vector3.new(1, 0.2, 1), Transparency = 1, CFrame = cf * CFrame.new(0, 0.1, 0) })
	-- the swirl filling the opening: a thin disc in the area colour that turns slowly and breathes
	local swirl = part(m, { Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, holeW, holeW), Color = col,
		Material = Enum.Material.Neon, Transparency = 0.35, CastShadow = false,
		CFrame = cf * CFrame.new(0, holeY, 0) * CFrame.Angles(0, math.pi / 2, 0) })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"; pe.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
	pe.LightEmission = 1; pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.8, 1.4); pe.Rate = 10; pe.Speed = NumberRange.new(0.5, 1.5); pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = swirl
	local light = Instance.new("PointLight"); light.Color = col; light.Range = 10; light.Brightness = 1.2; light.Shadows = false; light.Parent = swirl
	-- name plate: fixed above the arch, sized in the world
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(6, 1.4); bb.StudsOffsetWorldSpace = Vector3.new(0, H + 1.4, 0); bb.LightInfluence = 0
	bb.MaxDistance = 160; bb.Adornee = pad; bb.Parent = m
	local f = Instance.new("Frame"); f.Size = UDim2.fromScale(1, 1); f.BackgroundColor3 = hx("1c2233"); f.BackgroundTransparency = 0.08; f.Parent = bb
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.3, 0)
	local st = Instance.new("UIStroke"); st.Color = col; st.Thickness = 3; st.Parent = f
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Font = Enum.Font.FredokaOne
	t.Text = name; t.TextScaled = true; t.TextColor3 = Color3.new(1, 1, 1); t.Parent = f
	local tp = Instance.new("UIPadding"); tp.PaddingLeft = UDim.new(0.08, 0); tp.PaddingRight = UDim.new(0.08, 0); tp.PaddingTop = UDim.new(0.14, 0); tp.PaddingBottom = UDim.new(0.14, 0); tp.Parent = f
	m.Parent = root
	return { model = m, swirl = swirl, swirlHome = swirl.CFrame, centre = (cf * CFrame.new(0, holeY, 0)).Position }
end

local function placements()
	local out = {}
	-- hub arc on the plaza: areas in unlock order, facing the plaza centre
	local areas = {}
	for _, isl in World.list do if not isl.park then table.insert(areas, isl) end end
	-- portal gate: one tidy row along the back (north) edge of the Park, facing the camera, out of the egg field
	for k, isl in areas do
		local i, j = 20 + (k - (#areas + 1) / 2) * 3.6, 4
		local p = tileToWorld(i, j)
		table.insert(out, { key = "hub:" .. isl.id, id = isl.id, dest = isl.id, need = isl, name = string.gsub(isl.name, "^THE ", ""), pos = p,
			facing = Vector3.new(0, 0, 1) })
	end
	-- a way home from every area: beside its arrival spot
	for _, isl in areas do
		local ai, aj = World.arrival(isl)
		local p = tileToWorld(ai + 2.5, aj)
		table.insert(out, { key = "home:" .. isl.id, id = "park", dest = "park", need = isl, name = "PARK", pos = p, facing = Vector3.new(0, 0, 1) })
	end
	return out
end

function Portals.init()
	root = Instance.new("Folder"); root.Name = "Portals"; root.Parent = workspace
	list = placements()
	local cool = 0
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		cool = math.max(0, cool - dt)
		-- build / remove with the unlock state (2 Hz is plenty)
		if acc > 0.5 then
			acc = 0
			for _, p in list do
				local open = World.isOpen(p.need)
				if open and not p.built then
					p.built = build(p.id, p.name, p.pos, p.facing)
				elseif not open and p.built then
					p.built.model:Destroy(); p.built = nil
				end
			end
		end
		-- spin + walk-in
		local t = os.clock()
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		for _, p in list do
			local b = p.built
			if not b then continue end
			b.swirl.CFrame = b.swirlHome * CFrame.Angles(t * 2.4, 0, 0)
			b.swirl.Transparency = 0.3 + math.sin(t * 2.2 + p.pos.X) * 0.12
			if hrp and cool <= 0 then
				local d = Vector3.new(hrp.Position.X - p.pos.X, 0, hrp.Position.Z - p.pos.Z).Magnitude
				if d < 1.8 and math.abs(hrp.Position.Y - p.pos.Y) < 8 then
					cool = 2.5
					plr.PlayerGui:SetAttribute("PeckwoodTP", p.dest .. "#" .. os.clock())
				end
			end
		end
	end)
end

return Portals
