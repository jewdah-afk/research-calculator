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
-- zoom = half the visible height in tiles. Default frames the WHOLE island, level and square-on; zooming in slides
-- the focus from the island centre onto the bird (ZOOM_FOLLOW and closer = full follow)
local ZOOM_MIN, ZOOM_MAX, ZOOM_ALL, ZOOM_FOLLOW = 4, 20, 16, 8
local zoom = ZOOM_ALL
local zoomTarget = ZOOM_ALL
local PARK_CENTRE = Vector3.new(0, 0, 2)
local mapFocus: Vector3? = nil
local mapZoom: number? = nil
local function vpAspect(): number local v = workspace.CurrentCamera.ViewportSize; return v.Y / math.max(1, v.X) end
local ISLAND_CENTRE = PARK_CENTRE
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
		zoomTarget = math.clamp(zoomTarget * (if io.Position.Z < 0 then 1.12 else 1 / 1.12), ZOOM_MIN, ZOOM_MAX)
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

local World = require(Shared:WaitForChild("World"))
local IslandView = require(script.Parent:WaitForChild("IslandView"))
local Nav = require(script.Parent:WaitForChild("Nav"))
local lastOpen = 0
Remotes:WaitForChild("State").OnClientEvent:Connect(function(s, d)
	if d and d.speed then speedMul = d.speed end
	if s and s.island and s.island ~= lastOpen then
		-- animate only a real step forward (one unlock); dev save switches rebuild instantly
		local animate = lastOpen > 0 and s.island == lastOpen + 1
		lastOpen = s.island
		task.spawn(IslandView.sync, s.island, animate)
	end
end)
-- "Go to ..." buttons: drop the bird on that island (the client owns the body; the server reads the position)
Nav.handler = function(id: string)
	local isl = World.byId[id]
	if not (isl and World.isOpen(isl) and body) then return false end
	local i, j = World.arrival(isl)
	-- walk there hands-free (bridges included); falls back to a hop if no route exists
	if Controller.travel(body :: Controller.Body, i * 16, j * 16) then return true end
	local b = body :: Controller.Body
	b.x, b.y, b.z, b.vx, b.vy, b.vz = i * 16, j * 16, 0, 0, 0, 0
	b.target = nil
	dust(b.x, b.y, 0, 0, 0, 8)
	return true
end

-- click the ground to walk there (View3D.click -> Game.click); HOLD to keep following the pointer (mouse, finger,
-- or gamepad R2 with the virtual cursor). Ray onto the ground plane at the bird's height.
local holding: InputObject? = nil
local holdT = 0
local function pointerGround(pos: Vector2): (number?, number?)
	local ray = cam:ScreenPointToRay(pos.X, pos.Y)   -- input coords exclude the topbar inset
	if math.abs(ray.Direction.Y) < 1e-4 then return nil, nil end
	local t = -ray.Origin.Y / ray.Direction.Y
	if t <= 0 then return nil, nil end
	local x, y = Controller.fromWorld(ray.Origin + ray.Direction * t)
	return x, y
end
local function pointerPos(): Vector2
	if holding and holding.UserInputType == Enum.UserInputType.Touch then return Vector2.new(holding.Position.X, holding.Position.Y) end
	return UIS:GetMouseLocation() - Vector2.new(0, game:GetService("GuiService"):GetGuiInset().Y)
end
UIS.InputBegan:Connect(function(io, gp)
	if gp or not body then return end
	local t = io.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch and io.KeyCode ~= Enum.KeyCode.ButtonR2 then return end
	holding = io; holdT = 0
	local x, y = pointerGround(pointerPos())
	if x then Controller.click(body :: Controller.Body, x, y :: number) end
end)
UIS.InputEnded:Connect(function(io)
	if holding and (io == holding or io.UserInputType == holding.UserInputType and io.KeyCode == holding.KeyCode) then holding = nil end
end)
local function holdStep(dt: number)
	if not (holding and body) then return end
	holdT += dt
	if holdT < 0.18 then return end   -- a quick click stays a click; holding re-aims 6x a second
	holdT = 0.06
	local x, y = pointerGround(pointerPos())
	if not x then return end
	local b = body :: Controller.Body
	-- short hops: steer straight at the pointer (slides along walls); A* only when the straight line is blocked
	b.target = { x = x, y = y :: number, path = { { x = x, y = y :: number } }, st = 0 }
	local dx, dy = x - b.x, (y :: number) - b.y
	local d = math.sqrt(dx * dx + dy * dy)
	local n = math.max(1, math.floor(d / 6))
	for k = 1, n do
		local px, py = b.x + dx * k / n, b.y + dy * k / n
		if not Controller.canStand(px, py, Controller.heightAt(px, py), 4) and Controller.heightAt(px, py) < 15 then
			Controller.click(b, x, y :: number); break
		end
	end
end

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
	IslandView.birdPos = feet
	feet -= Vector3.new(0, IslandView.bridgeDip, 0)   -- rope bridges sink under the bird
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
IslandView.build()
require(script.Parent:WaitForChild("Ambience")).start()
outline(IslandView.scenery, "#24331f", 0.5)                                         -- scenery: quiet tinted outline
-- dev/QA hook: PlayerGui:SetAttribute("PeckwoodBuild", tick()) replays the unlock build-in; PeckwoodHour freezes the sky
-- (a string island id replays that island's build-in from its bridge, e.g. "garden")
plr:WaitForChild("PlayerGui"):GetAttributeChangedSignal("PeckwoodBuild"):Connect(function()
	local v = plr.PlayerGui:GetAttribute("PeckwoodBuild")
	if typeof(v) == "string" and v ~= "park" then IslandView.replay(v) else IslandView.play() end
end)
plr.PlayerGui:GetAttributeChangedSignal("PeckwoodGo"):Connect(function() Nav.go(plr.PlayerGui:GetAttribute("PeckwoodGo")) end)
-- Teleport (left bar): instant hop to an open island; value is "<id>#<nonce>" so the same island can be picked twice
plr.PlayerGui:GetAttributeChangedSignal("PeckwoodTP"):Connect(function()
	local v = plr.PlayerGui:GetAttribute("PeckwoodTP")
	if typeof(v) ~= "string" or not body then return end
	local id = string.match(v, "^([^#]+)")
	local isl = World.byId[id or ""]
	if not (isl and World.isOpen(isl)) then return end
	local i, j = World.arrival(isl)
	local b = body :: Controller.Body
	dust(b.x, b.y, b.z, 0, 0, 8)
	b.x, b.y, b.z, b.vx, b.vy, b.vz = i * 16, j * 16, 0, 0, 0, 0
	b.target = nil
	dust(b.x, b.y, 0, 0, 0, 10)
	plr.PlayerGui:SetAttribute("PeckwoodMap", false)
end)
-- QA camera: PlayerGui:SetAttribute("PeckwoodCam", Vector3) frames the island from there (nil = normal camera)
plr.PlayerGui:GetAttributeChangedSignal("PeckwoodCam"):Connect(function()
	local p = plr.PlayerGui:GetAttribute("PeckwoodCam")
	IslandView.camCF = if typeof(p) == "Vector3" then CFrame.lookAt(p, Vector3.new(0, -8, 2)) else nil
end)
plr.PlayerGui:GetAttributeChangedSignal("PeckwoodHour"):Connect(function() IslandView.timeOverride = plr.PlayerGui:GetAttribute("PeckwoodHour") end)
type K = { model: Model, halo: Part, pos: Vector3, born: number, golden: boolean, homing: number?, parts: { BasePart }, offs: { CFrame } }
local kernels: { [number]: K } = {}
local frameN = 0
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
	-- cache the puff parts relative to the pivot so every kernel moves in one BulkMoveTo per frame
	local pv = m:GetPivot()
	local parts, offs = {}, {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= halo then
			d.CastShadow = false   -- 180 moving shadow casters re-render the shadow map every frame; the halo grounds them
			table.insert(parts, d); table.insert(offs, pv:ToObjectSpace(d.CFrame))
		end
	end
	kernels[id] = { model = m, halo = halo, pos = pos, born = clock, golden = golden, parts = parts, offs = offs }
	local n = 0; for _, kk in kernels do if not kk.homing then n += 1 end end; Hud.kernelCount = n   -- flying-in kernels no longer count
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

local bulkParts: { BasePart } = {}
local bulkCFs: { CFrame } = {}
local function kernelsStep(dt: number)
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	table.clear(bulkParts); table.clear(bulkCFs)
	local function place(k: K, cf: CFrame)
		for n, p in k.parts do table.insert(bulkParts, p); table.insert(bulkCFs, cf * k.offs[n]) end
	end
	for id, k in kernels do
		if not k.model.Parent then continue end
		local age = clock - k.born
		if k.homing and hrp then
			k.homing += dt
			local t = math.min(1, k.homing / 0.18)
			local target = hrp.Position + Vector3.new(0, 0.2 * S, 0)
			local p = k.pos:Lerp(target, t * t) + Vector3.new(0, math.sin(t * math.pi) * 0.8 * S, 0)
			place(k, CFrame.new(p) * CFrame.Angles(0, clock * 12, 0))
		else
			-- pop-in (rise out of the ground with easeOutBack), then spin + bob like View3D; settled kernels
			-- only update every other frame (half the work, invisible at this bob speed)
			if age > 0.4 and (id + frameN) % 2 == 0 then continue end
			local e = easeOutBack(math.min(1, age / 0.35))
			local y = (e - 1) * 0.6 * S + math.sin(clock * 3 + id) * 0.06 * S + 0.08 * S
			place(k, CFrame.new(k.pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, clock * 1.6 + id, 0))
			if k.halo.Parent then k.halo.Transparency = 0.5 + math.sin(clock * 4 + id) * 0.12 end
		end
	end
	if #bulkParts > 0 then workspace:BulkMoveTo(bulkParts, bulkCFs, Enum.BulkMoveMode.FireCFrameChanged) end
end

-- ---------------------------------------------------------------- frame
RunService:BindToRenderStep("Peckwood", Enum.RenderPriority.Camera.Value + 1, function(dt)
	clock += dt; frameN += 1
	holdStep(dt); bodyStep(dt); Birds.step(clock, dt, plr.Character, body); kernelsStep(dt)
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mapOn0 = plr.PlayerGui:GetAttribute("PeckwoodMap") == true
	zoom += ((if mapOn0 and mapZoom then mapZoom else zoomTarget) - zoom) * (1 - math.exp(-dt * (if mapOn0 then 4 else 10)))   -- smooth wheel zoom
	local follow = 1   -- zooming in or out always stays on the bird (owner)
	local mapOn = plr.PlayerGui:GetAttribute("PeckwoodMap") == true
	if mapOn then
		local mn, mx = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
		for _, isl in World.list do
			if World.isOpen(isl) then
				mn = mn:Min(Vector2.new(isl.oi, isl.oj)); mx = mx:Max(Vector2.new(isl.oi + isl.W, isl.oj + isl.N))
			end
		end
		local c = (mn + mx) / 2
		mapFocus = Vector3.new((c.X - 20) * S, 0, (c.Y - 15) * S)
		mapZoom = math.max((mx.Y - mn.Y) * 0.62, (mx.X - mn.X) * 0.62 * vpAspect() / 0.7, 14)   -- /0.7: the drawer covers ~30 % on the right
	end
	local bird = if hrp then Vector3.new(hrp.Position.X, 0, hrp.Position.Z) else ISLAND_CENTRE
	if hrp then
		local isl = World.nearest(hrp.Position.X / S + 20, hrp.Position.Z / S + 15)
		ISLAND_CENTRE = if isl.park then PARK_CENTRE else Vector3.new((isl.cx - 20) * S, 0, (isl.cz - 15) * S)
	end
	-- keep the island centred in the free space left of the shop drawer when it is open
	local vp = cam.ViewportSize
	local drawerShift = if Hud.dock and Hud.dock.Visible and not Hud.collapsed then 0.3 * zoom * S * vp.X / math.max(1, vp.Y) else 0
	local mapShift = if Hud.dock and Hud.dock.Visible and not Hud.collapsed then 0.3 * zoom * S * vp.X / math.max(1, vp.Y) else 0
	local want = if mapOn and mapFocus then mapFocus + Vector3.new(mapShift, 0, 0) else ISLAND_CENTRE:Lerp(bird, follow) + Vector3.new(drawerShift * (1 - follow), 0, 0)
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
