--!strict
-- Peckwood client — presentation only (port of src/three/View3D.js): near-orthographic iso camera looking straight
-- across the island (yaw 0 so the island lies horizontal), bird hop/tilt, kernel pop-in / spin / bob / halo,
-- collect homing + burst + number pop, drifting clouds, screen shake. The server owns every number.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = RS:WaitForChild("Peckwood")
local Models = require(Shared:WaitForChild("Models"))
local Defs = require(Shared:WaitForChild("Defs"))
local Remotes = Shared:WaitForChild("Remotes")
local Hud = require(script.Parent:WaitForChild("UI"):WaitForChild("Hud"))
local S = Models.S

local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- ---------------------------------------------------------------- camera
-- View3D: orthographic, pitch 52 deg. Roblox has no ortho camera, so: a very narrow FOV from far away (~ortho),
-- yaw 0 (looking down -Z) so the 40-tile axis of the island runs left-right across the screen.
local PITCH = math.rad(52)
local FOV = 11
local zoom = 9               -- half the visible height, in tiles (View3D 10.5 ortho; a touch closer reads better in perspective)
local camFocus: Vector3? = nil
local shake = 0
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = FOV

local function distFor(z: number): number   -- distance so the view's half-height is z tiles
	return z * S / math.tan(math.rad(FOV / 2))
end
UIS.InputChanged:Connect(function(io, gp)
	if gp then return end
	if io.UserInputType == Enum.UserInputType.MouseWheel then
		zoom = math.clamp(zoom * (if io.Position.Z < 0 then 1.1 else 1 / 1.1), 4, 16)
	end
end)

-- ---------------------------------------------------------------- player body (HTML controller, fixed 60 Hz)
local Controller = require(script.Parent:WaitForChild("Controller"))
local Birds = require(script.Parent:WaitForChild("Birds"))
local body: Controller.Body? = nil
local speedMul = 1
local STEP = 1 / 60
local simAcc = 0
local bodyChar: Model? = nil

-- dust puffs (World.spawn('dust') + View3D dust: small pale cubes, 0.45 s, drift up and fade)
local function dust(x: number, y: number, z: number, vx: number, vy: number, n: number)
	for _ = 1, n do
		local at = Controller.toWorld(x + (math.random() - 0.5) * 4, y + (math.random() - 0.5) * 2, z + 1)
		local p = Instance.new("Part"); p.Size = Vector3.one * 0.13 * S; p.Color = Color3.fromHex("#f4ead8"); p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.CFrame = CFrame.new(at); p.Parent = workspace
		local drift = Vector3.new((vx + (math.random() - 0.5) * 16) / 16 * S * 0.45, (if n > 1 then 10 else 12) / 16 * S * 0.45, (vy + (math.random() - 0.5) * 10) / 16 * S * 0.45)
		local tw = TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + drift), Transparency = 1 })
		tw:Play(); tw.Completed:Once(function() p:Destroy() end)
	end
end

Remotes:WaitForChild("State").OnClientEvent:Connect(function(_, d) if d and d.speed then speedMul = d.speed end end)

-- click the ground to walk there (View3D.click -> Game.click): ray onto the y = 0 ground plane
UIS.InputBegan:Connect(function(io, gp)
	if gp or not body then return end
	if io.UserInputType ~= Enum.UserInputType.MouseButton1 and io.UserInputType ~= Enum.UserInputType.Touch then return end
	local ray = cam:ScreenPointToRay(io.Position.X, io.Position.Y)   -- input coords exclude the topbar inset
	if math.abs(ray.Direction.Y) < 1e-4 then return end
	local t = -ray.Origin.Y / ray.Direction.Y
	if t <= 0 then return end
	local hit = ray.Origin + ray.Direction * t
	local x, y = Controller.fromWorld(hit)
	Controller.click(body :: Controller.Body, x, y)
end)

local function bodyStep(dt: number)
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (ch and hrp) then return end
	if bodyChar ~= ch or not body then
		local x, y = Controller.fromWorld(hrp.Position)
		body = Controller.new(x, y); bodyChar = ch
	end
	local b = body :: Controller.Body
	simAcc = math.min(simAcc + dt, 0.25)
	while simAcc >= STEP do Controller.step(b, STEP, speedMul, dust); simAcc -= STEP end
	local feet = Controller.toWorld(b.x, b.y, b.z)
	hrp.CFrame = CFrame.new(feet + Vector3.new(0, hrp.Size.Y / 2, 0))
	hrp.AssemblyLinearVelocity = Vector3.new(b.vx / 16 * S, b.vz / 16 * S, b.vy / 16 * S)
end

-- ---------------------------------------------------------------- kernels
local field = Instance.new("Model"); field.Name = "Kernels"; field.Parent = workspace

-- ---------------------------------------------------------------- outline tiers (visual hierarchy)
-- One Highlight per GROUP (Roblox renders at most 31 at once). Strongest on what you control / collect,
-- subtle on scenery, none on the ground so it reads as the stage. Fill stays off except a soft lift on popcorn.
local function outline(target: Instance, color: string, outlineT: number, fill: string?, fillT: number?)
	local h = Instance.new("Highlight")
	h.OutlineColor = Color3.fromHex(color); h.OutlineTransparency = outlineT
	h.FillColor = Color3.fromHex(fill or "#ffffff"); h.FillTransparency = fillT or 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = target; h.Parent = target
	return h
end
outline(field, "#6b4512", 0.12, "#fff6d6", 0.78)                                   -- popcorn: warm rim + soft inner lift
local IslandView = require(script.Parent:WaitForChild("IslandView"))
IslandView.build()
outline(IslandView.scenery, "#24331f", 0.5)                                         -- scenery: quiet tinted outline
-- dev/QA hook: PlayerGui:SetAttribute("PeckwoodBuild", tick()) replays the unlock build-in; PeckwoodHour freezes the sky
plr:WaitForChild("PlayerGui"):GetAttributeChangedSignal("PeckwoodBuild"):Connect(function() IslandView.play() end)
-- QA camera: PlayerGui:SetAttribute("PeckwoodCam", Vector3) frames the island from there (nil = normal camera)
plr.PlayerGui:GetAttributeChangedSignal("PeckwoodCam"):Connect(function()
	local p = plr.PlayerGui:GetAttribute("PeckwoodCam")
	IslandView.camCF = if typeof(p) == "Vector3" then CFrame.lookAt(p, Vector3.new(0, -8, 2)) else nil
end)
plr.PlayerGui:GetAttributeChangedSignal("PeckwoodHour"):Connect(function() IslandView.timeOverride = plr.PlayerGui:GetAttribute("PeckwoodHour") end)
type K = { model: Model, halo: Part, pos: Vector3, born: number, golden: boolean, homing: number? }
local kernels: { [number]: K } = {}
local clock = 0

local function easeOutBack(t: number): number
	local c1 = 1.70158; local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

-- popcorn types (BirbFormulas.PopcornTypes) tint the kernel puffs
local KIND_COLOR = { butter = "#ffe27a", caramel = "#e0913a", cheese = "#ffc93a", rainbow = nil, red = "#ff4a4a" }
local RAINBOW = { "#ff5a5a", "#ffb43a", "#ffe94a", "#5ae86a", "#4ab4ff", "#b06cff" }
Remotes:WaitForChild("Spawn").OnClientEvent:Connect(function(id: number, pos: Vector3, kind: string)
	if kernels[id] then return end
	local golden = kind == "golden"
	local m = Models.kernel(golden)
	if KIND_COLOR[kind] or kind == "rainbow" then
		local i = 0
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Color.R > 0.85 and p.Color.G > 0.8 then
				i += 1
				p.Color = Color3.fromHex(if kind == "rainbow" then RAINBOW[(i - 1) % #RAINBOW + 1] else KIND_COLOR[kind])
			end
		end
	end
	local halo = Instance.new("Part")
	halo.Name = "Halo"; halo.Shape = Enum.PartType.Cylinder; halo.Size = Vector3.new(0.04, 0.68 * S, 0.68 * S)
	halo.Color = if golden then Color3.fromHex("#ffd54a") else Color3.new(1, 1, 1); halo.Material = Enum.Material.Neon
	halo.Transparency = 0.55; halo.Anchored = true; halo.CanCollide = false; halo.CanQuery = false; halo.CastShadow = false
	halo.CFrame = CFrame.new(pos + Vector3.new(0, 0.04 * S, 0)) * CFrame.Angles(0, 0, math.rad(90))
	halo.Parent = m
	m.Parent = field
	kernels[id] = { model = m, halo = halo, pos = pos, born = clock, golden = golden }
	local n = 0; for _ in kernels do n += 1 end; Hud.kernelCount = n
end)

-- collect: number pop + bird punch + burst of little cubes (View3D collect burst)
local function burst(at: Vector3, color: Color3, n: number)
	for _ = 1, n do
		local p = Instance.new("Part"); p.Size = Vector3.one * 0.12 * S; p.Color = color; p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false; p.CFrame = CFrame.new(at); p.Parent = workspace
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.4, math.random() - 0.5).Unit * (0.8 + math.random()) * S
		local tw = TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(at + dir) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Transparency = 1 })
		tw:Play(); tw.Completed:Once(function() p:Destroy() end)
	end
end
local function numberPop(at: Vector3, text: string, golden: boolean)
	local a = Instance.new("Part"); a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.Transparency = 1; a.Size = Vector3.one * 0.1
	a.Position = at; a.Parent = workspace
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(160, 50); bb.AlwaysOnTop = true; bb.LightInfluence = 0; bb.Parent = a
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Font = Enum.Font.FredokaOne
	t.TextSize = 30; t.Text = text; t.TextColor3 = if golden then Color3.fromHex("#ffd84a") else Color3.fromHex("#fff1a8"); t.Parent = bb
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromHex("#0b0c10"); st.Parent = t
	local tw = TweenService:Create(a, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = at + Vector3.new(0, 1.4 * S, 0) })
	TweenService:Create(t, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	TweenService:Create(st, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	tw:Play(); tw.Completed:Once(function() a:Destroy() end)
end

Remotes:WaitForChild("Collect").OnClientEvent:Connect(function(id: number, value: any, golden: boolean)
	local k = kernels[id]; if not k then return end
	if value == nil then k.model:Destroy(); kernels[id] = nil; return end   -- cleared by Molt / travel / dev save
	local n = 0; for _, kk in kernels do if not kk.homing then n += 1 end end; Hud.kernelCount = n - 1
	k.homing = 0; k.halo:Destroy()
	task.delay(0.18, function()
		local at = k.model:GetPivot().Position
		k.model:Destroy(); kernels[id] = nil
		burst(at + Vector3.new(0, 0.3 * S, 0), if golden then Color3.fromHex("#ffc93a") else Color3.fromHex("#fff1c9"), if golden then 14 else 8)
		numberPop(at + Vector3.new(0, 1.1 * S, 0), "+" .. Defs.EN.short(value), golden)
		Birds.punch()
		if golden then shake = 0.35 end
	end)
end)

local function kernelsStep(dt: number)
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	for id, k in kernels do
		local age = clock - k.born
		if k.homing and hrp then
			k.homing += dt
			local t = math.min(1, k.homing / 0.18)
			local target = hrp.Position + Vector3.new(0, 0.2 * S, 0)
			local p = k.pos:Lerp(target, t * t) + Vector3.new(0, math.sin(t * math.pi) * 0.8 * S, 0)
			k.model:PivotTo(CFrame.new(p) * CFrame.Angles(0, clock * 12, 0))
		else
			-- pop-in (rise out of the ground with easeOutBack), then spin + bob like View3D
			local e = easeOutBack(math.min(1, age / 0.35))
			local y = (e - 1) * 0.6 * S + math.sin(clock * 3 + id) * 0.06 * S + 0.08 * S
			k.model:PivotTo(CFrame.new(k.pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, clock * 1.6 + id, 0))
			k.halo.CFrame = CFrame.new(k.pos + Vector3.new(0, 0.04 * S, 0)) * CFrame.Angles(0, 0, math.rad(90))
			k.halo.Transparency = 0.5 + math.sin(clock * 4 + id) * 0.12
		end
	end
end

-- ---------------------------------------------------------------- frame
RunService:BindToRenderStep("Peckwood", Enum.RenderPriority.Camera.Value + 1, function(dt)
	clock += dt
	bodyStep(dt); Birds.step(clock, dt, plr.Character, body); kernelsStep(dt)
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local want = if hrp then Vector3.new(hrp.Position.X, 0, hrp.Position.Z) else Vector3.zero
	camFocus = if camFocus then camFocus:Lerp(want, 1 - math.exp(-dt * 8)) else want
	shake = math.max(0, shake - dt)
	local jitter = if shake > 0 then Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake * S * 0.6 else Vector3.zero
	local back = Vector3.new(0, math.sin(PITCH), math.cos(PITCH)) * distFor(zoom)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = FOV
	cam.CFrame = IslandView.camCF or CFrame.lookAt((camFocus :: Vector3) + back + jitter, (camFocus :: Vector3) + jitter)
	cam.Focus = CFrame.new(camFocus :: Vector3)
end)

Hud.start(Remotes)
