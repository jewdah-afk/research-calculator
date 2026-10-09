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
local function build(id, name, pos, facing)
	local col = hx(COL[id] or "ffffff")
	local m = Instance.new("Model"); m.Name = "Portal_" .. id
	local cf = CFrame.lookAt(pos, pos + facing)
	local R = 2.4   -- ring radius (studs): a doorway, not a pad (owner: portals were huge and in the egg field)
	local pad = part(m, { Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, R * 2.6, R * 2.6), Color = hx("c4bdb0"),
		Material = Enum.Material.SmoothPlastic, CFrame = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	part(m, { Name = "Trim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.64, R * 2.2, R * 2.2), Color = col,
		Material = Enum.Material.Neon, Transparency = 0.2, CFrame = cf * CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	local centre = cf * CFrame.new(0, R + 0.9, 0)
	local ring = Instance.new("Model"); ring.Name = "Ring"; ring.Parent = m
	local SEG = 20
	for k = 0, SEG - 1 do
		local a = k / SEG * math.pi * 2
		local seg = part(ring, { Size = Vector3.new(0.7, R * 2 * math.pi / SEG * 1.05, 0.7), Color = if k % 2 == 0 then col else col:Lerp(Color3.new(1, 1, 1), 0.45),
			Material = Enum.Material.Neon, CFrame = centre * CFrame.Angles(0, 0, a) * CFrame.new(R, 0, 0) })
		seg.CastShadow = false
	end
	ring.WorldPivot = centre
	local swirl = part(m, { Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, R * 1.85, R * 1.85), Color = col,
		Material = Enum.Material.Neon, Transparency = 0.45, CastShadow = false, CFrame = centre * CFrame.Angles(0, math.pi / 2, 0) })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"; pe.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
	pe.LightEmission = 1; pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.8, 1.4); pe.Rate = 18; pe.Speed = NumberRange.new(1, 3); pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = swirl
	local light = Instance.new("PointLight"); light.Color = col; light.Range = 14; light.Brightness = 1.6; light.Shadows = false; light.Parent = swirl
	-- name sign: a rounded plaque above the ring in the area colour
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(7, 1.6); bb.StudsOffsetWorldSpace = Vector3.new(0, 2 * R + 3.2, 0); bb.LightInfluence = 0   -- world-sized sign, stays on its portal
	bb.MaxDistance = 160; bb.Adornee = pad; bb.Parent = m   -- the pad never moves (the swirl spins, which made signs orbit)
	local f = Instance.new("Frame"); f.Size = UDim2.fromScale(1, 1); f.BackgroundColor3 = hx("1c2233"); f.BackgroundTransparency = 0.1; f.Parent = bb
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
	local st = Instance.new("UIStroke"); st.Color = col; st.Thickness = 3; st.Parent = f
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Font = Enum.Font.FredokaOne
	t.Text = name; t.TextScaled = true; t.TextColor3 = Color3.new(1, 1, 1); t.Parent = f
	local tp = Instance.new("UIPadding"); tp.PaddingLeft = UDim.new(0, 12); tp.PaddingRight = UDim.new(0, 12); tp.PaddingTop = UDim.new(0, 6); tp.PaddingBottom = UDim.new(0, 6); tp.Parent = f
	local ts = Instance.new("UIStroke"); ts.Color = col:Lerp(Color3.new(), 0.5); ts.Thickness = 2; ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Parent = t
	m.Parent = root
	return { model = m, ring = ring, ringHome = ring:GetPivot(), swirl = swirl, swirlHome = swirl.CFrame, centre = centre.Position }
end

local function placements()
	local out = {}
	-- hub arc on the plaza: areas in unlock order, facing the plaza centre
	local areas = {}
	for _, isl in World.list do if not isl.park then table.insert(areas, isl) end end
	-- portal gate: one tidy row along the back (north) edge of the Park, facing the camera, out of the egg field
	for k, isl in areas do
		local i, j = 20 + (k - (#areas + 1) / 2) * 3.4, 3
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
			b.ring:PivotTo(b.ringHome * CFrame.Angles(0, 0, t * 0.8))
			b.swirl.CFrame = b.swirlHome * CFrame.Angles(t * 2.4, 0, 0)
			b.swirl.Transparency = 0.42 + math.sin(t * 3 + p.pos.X) * 0.1
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
