--!strict
--[[
	MapPreview: shows the realm map full screen over the current page UI, so the new map and HUD can be tried in
	Studio before the new client replaces the page. It listens to the same View patches as the page (a ViewStore of
	its own), so everything shows the live game: node states and badges, links, plates, edge markers, the points
	capsule, the dock, the READY tray, the portal, toasts, tooltips, the peek and the gate popover.

	    drag / touch-drag      pan            wheel / pinch / double-click / the zoom capsule     zoom
	    click a node           opens that layer: in the new panel preview when it is on, else in the page UI
	    hover / right-click    tooltip / peek (OPEN, hold PRESTIGE)
	    READY gems             tap opens the layer, hold 0.6 s prestiges
	    the portal / the rift  the Multiverse gate (hold to enter / exit / finish)
	    M or the GAME button   switch between the map and the page UI; HOME frames the map again

	App.luau takes all of this over when the new client lands; this script is then deleted.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = script.Parent:WaitForChild("Core")
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Theme = require(Core:WaitForChild("Theme"))
local Recipes = require(Core:WaitForChild("Recipes"))
local ViewStore = require(Core:WaitForChild("ViewStore"))
local Input = require(script.Parent:WaitForChild("Input"):WaitForChild("Input"))
local MapFolder = script.Parent:WaitForChild("Map")
local MapView = require(MapFolder:WaitForChild("MapView"))
local MapInput = require(MapFolder:WaitForChild("MapInput"))
local MapLogic = require(MapFolder:WaitForChild("MapLogic"))
local Nodes = require(MapFolder:WaitForChild("Nodes"))
local Links = require(MapFolder:WaitForChild("Links"))
local Plates = require(MapFolder:WaitForChild("Plates"))
local Markers = require(MapFolder:WaitForChild("Markers"))
local Hud = require(script.Parent:WaitForChild("Hud"):WaitForChild("Hud"))
local Overlay = require(script.Parent:WaitForChild("Overlay"):WaitForChild("Overlay"))

local lp = Players.LocalPlayer
Input.start()

-- above the page UI (its popups use DisplayOrder 20)
local gui, root = Layout.screen("MapGui", 40, Enum.ScreenInsets.None)
local view = MapView.new(gui, root, { tier = MapView.chooseTier() })
local mi = MapInput.new(view, Input)
local markerGui = Layout.screen("MarkerGui", 41, Enum.ScreenInsets.DeviceSafeInsets)
-- the HUD stays under the panel preview (PanelGui 42, src/client/Panel/Preview.luau), the overlays above it
local hudGui = Layout.screen("HudGui", 41, Enum.ScreenInsets.CoreUISafeInsets)
local topbarGui = Layout.screen("TopbarGui", 41, Enum.ScreenInsets.TopbarSafeInsets)
local overlayGui = Layout.screen("OverlayGui", 45, Enum.ScreenInsets.DeviceSafeInsets)
Recipes.holdGate = function(): boolean
	return not mi:busy()
end

local nodes = Nodes.new(view, mi)
local links = Links.new(view)
local plates = Plates.new(view, nodes)
local markers = Markers.new(markerGui, view, nodes)
local hud = Hud.new(topbarGui, hudGui)
local overlay = Overlay.new(overlayGui)

-- ------------------------------------------------------------------------------------------------------ switch
local switchGui = Instance.new("ScreenGui")
switchGui.Name = "PreviewSwitch"
switchGui.ResetOnSpawn = false
switchGui.DisplayOrder = 49
switchGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
Input.BLOCKING.PreviewSwitch = true
local button = Instance.new("TextButton")
button.Name = "Switch"
button.AnchorPoint = Vector2.new(1, 0)
button.Position = UDim2.new(1, -16, 0, 12)
button.Size = UDim2.fromOffset(132, 40)
button.BackgroundColor3 = Theme.C.panel
button.TextColor3 = Theme.C.text
button.AutoButtonColor = true
Theme.text(button, "tab")
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0.5, 0)
bc.Parent = button
local bs = Instance.new("UIStroke")
bs.Color = Theme.hue("t")
bs.Thickness = 2
bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bs.Parent = button
button.Parent = switchGui
switchGui.Parent = lp:WaitForChild("PlayerGui")

local showing = true
local function show(on: boolean)
	showing = on
	gui.Enabled = on
	markerGui.Enabled = on
	overlayGui.Enabled = on
	hud:setVisible(on)
	mi:setEnabled(on)
	view:setAmbient(on)
	if not on then
		overlay:peek(nil)
		overlay:modal(nil)
		overlay:tooltip(nil, nil)
	end
	button.Text = if on then "GAME" else "MAP"
end
button.Activated:Connect(function() show(not showing) end)
UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if io.KeyCode == Enum.KeyCode.M and not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		and not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		show(not showing)
	end
end)
show(true)

view:preload(function() end)
view:frameStart({ intro = true })

-- ------------------------------------------------------------------------------------------------------ live data
local remotes = ReplicatedStorage:WaitForChild("MilestoneTreeRemotes", 30)
local store = ViewStore.new()
local gotFull = false
local lastMs: any = nil

local function onMap()
	local ms = store:map()
	lastMs = ms
	nodes:update(ms)
	links:update(ms)
	plates:update(ms)
	markers:update(ms)
	hud:updateMap(ms)
end
local function onHud()
	local h = store:hud()
	if h then
		nodes:setFirstRun(h.fr)
		hud:setFirstRun(h.fr)
		hud:updateHud(h)
	end
end

view.cameraChanged:Connect(function(cam: any)
	hud:setZoomPct(cam.z)
end)
hud:setZoomPct(view:camera().z)

-- the tooltip of a node (mouse hover)
local UNIVERSE_WORD = { [true] = "Lives in the Prestige Multiverse", [false] = "Lives in the Normal Universe" }
local function nodeTip(layer: string): any
	local ms = lastMs
	local node = if ms then ms.nodes[layer] else nil
	local st = nodes:state(layer)
	if st == "sealed" or st == "frontier" then
		return { title = "???", body = "Not discovered yet.", layer = layer, hue = Theme.C.muted }
	end
	if st == "dormant" then
		return { title = MapLogic.NAMES[layer] and (string.sub(MapLogic.NAMES[layer], 1, 1) .. string.lower(string.sub(MapLogic.NAMES[layer], 2))) or layer,
			body = UNIVERSE_WORD[MapLogic.MULTIVERSE[layer] == true], layer = layer }
	end
	if node == nil then return nil end
	local v = node.val
	local title = node.name or layer
	if st == "locked" then title ..= " · Locked" end
	local content: any = { title = title, body = v and v.tip, layer = layer, foot = "Click to open · right-click to peek" }
	if v and not v.lit and v.req then
		content.rows = { { "Need", v.req .. " " .. MapLogic.unit(v.rres) } }
		if v.pr then content.pr = v.pr / 1000 end
	end
	return content
end
nodes.hover:Connect(function(layer: string?, abs: Vector2)
	if layer == nil then
		overlay:tooltip("node", nil)
		return
	end
	overlay:tooltip("node", nodeTip(layer), abs)
end)
-- the rift tooltip
nodes.rift:Connect(function(event: string, abs: Vector2)
	local ms = lastMs
	local gate = ms and ms.gate
	if event == "leave" then
		overlay:tooltip("rift", nil)
	elseif event == "hover" then
		if gate and gate.show then
			overlay:tooltip("rift", { title = "Prestige Multiverse", body = gate.h or "The rift is open.",
				foot = "Click to fly there", hue = Color3.fromHex("ff2e63") }, abs)
		else
			local req = gate and gate.req
			overlay:tooltip("rift", { title = "The rift is sealed", body = "Reach 185 milestones to reveal the Prestige Multiverse.",
				rows = if req then { { "Need", req.need .. " milestones" }, { "Have", req.have .. " milestones" } } else nil,
				pr = if req then req.pr / 1000 else nil, foot = "Click to fly there", hue = Color3.fromHex("ff2e63") }, abs)
		end
	end
end)

local function frameReady()
	local ms = lastMs
	if ms == nil or #ms.ready + #ms.canBuy == 0 then return end
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, list in { ms.ready, ms.canBuy } do
		for _, l in list do
			local p = nodes:worldPos(l)
			x0, y0, x1, y1 = math.min(x0, p.X - 110), math.min(y0, p.Y - 110), math.max(x1, p.X + 110), math.max(y1, p.Y + 150)
		end
	end
	view:frameWorld({ x = x0, y = y0, w = x1 - x0, h = y1 - y0 }, { time = 0.9 })
end

if remotes then
	local viewRemote = remotes:WaitForChild("View") :: RemoteEvent
	local actRemote = remotes:WaitForChild("Act") :: RemoteEvent
	local readyRemote = remotes:WaitForChild("Ready") :: RemoteEvent
	local importRemote = remotes:WaitForChild("Import") :: RemoteEvent
	local wasInside: boolean? = nil
	local offShown = false
	viewRemote.OnClientEvent:Connect(function(patch: any)
		if type(patch) ~= "table" or patch.fatal or patch.status then return end
		local ok, err = pcall(function()
			local changes = store:apply(patch)
			if changes.full then gotFull = true end
			if changes.map then onMap() end
			if changes.hud then onHud() end
			if patch.save == "saving" or patch.save == "saved" then hud:setStatus(patch.save) end
			if patch.unsaved == true then
				offShown = true
				hud:setStatus("off")
			elseif offShown and patch.set ~= nil and patch.save == nil then
				offShown = false
				hud:setStatus(nil)
			end
			local ms = lastMs
			if ms and ms.ok then
				if wasInside ~= nil and wasInside ~= ms.inside then
					overlay:flash(if ms.inside then Color3.fromHex("ff2e63") else Color3.fromHex("8a7cff"))
				end
				wasInside = ms.inside
			end
			if showing then
				if patch.pop or patch.notice then overlay:toasts(patch.pop, patch.notice) end
				if type(patch.imp) == "table" then overlay:importResult(patch.imp) end
				if changes.ended then overlay:screen(if store.ended then "end" else nil, store:endScreen()) end
			end
		end)
		if not ok then warn("[MilestoneTree] map preview: " .. tostring(err)) end
	end)
	-- the page asked for the first full view before this script listened: ask again once (a resync is harmless)
	task.delay(3, function()
		if not gotFull then readyRemote:FireServer() end
	end)

	local function fire(a: any)
		if type(a) == "table" and #a > 0 then actRemote:FireServer(a, false) end
	end
	-- the new panel preview (Studio) opens over the map by itself when the server opens a tab; without it the layer
	-- shows in the page UI
	local function panelOn(): boolean
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		local panel = pg and pg:FindFirstChild("PanelGui")
		return panel ~= nil and panel:IsA("ScreenGui") and panel.Enabled
	end
	local function toPage()
		if panelOn() then return end
		task.delay(0.35, function()
			if showing and not panelOn() then show(false) end
		end)
	end
	-- open a layer (the panel preview, else the page UI)
	local function openLayer(layer: string)
		local ms = lastMs
		local node = if ms then ms.nodes[layer] else nil
		if node == nil or not node.show then
			if nodes:state(layer) == "dormant" then
				overlay:toasts(nil, { UNIVERSE_WORD[MapLogic.MULTIVERSE[layer] == true] })
			end
			return
		end
		local ms2 = lastMs
		if not (ms2 and ms2.open == layer) then fire(node.a) end
		view:focusWorld(nodes:worldPos(layer))
		toPage()
	end
	nodes.activated:Connect(openLayer)
	nodes.peek:Connect(function(layer: string)
		local ms = lastMs
		local node = if ms then ms.nodes[layer] else nil
		local st = nodes:state(layer)
		if st == "sealed" or st == "frontier" or st == "dormant" then return end
		nodes:setPeek(layer)
		overlay:peek(layer, node, nodes:ringRect(layer))
	end)
	overlay.peekClosed:Connect(function() nodes:setPeek(nil) end)
	overlay.openLayer:Connect(openLayer)
	overlay.act:Connect(function(a: any) fire(a) end)
	overlay.flyTo:Connect(function(layer: string) view:focusWorld(nodes:worldPos(layer)) end)
	overlay.importText:Connect(function(t: string) importRemote:FireServer(t) end)
	overlay.resync:Connect(function() readyRemote:FireServer() end)
	markers.activated:Connect(function(layer: string)
		view:focusWorld(nodes:worldPos(layer))
	end)
	local function openGate()
		view:focusWorld(Vector2.new(3150, 1350))
		local ms = lastMs
		task.delay(0.3, function()
			overlay:modal("gate", if ms then ms.gate else nil)
		end)
	end
	nodes.rift:Connect(function(event: string)
		if event == "click" then openGate() end
	end)

	-- the HUD
	hud.home:Connect(function()
		overlay:peek(nil)
		local ms = lastMs
		if ms and ms.open and ms.close then fire(ms.close) end
		view:frameStart({})
	end)
	hud.trophies:Connect(function() openLayer("ach") end)
	hud.options:Connect(function()
		local ms = lastMs
		if ms and ms.opt then
			fire(ms.opt)
			toPage()
		end
	end)
	hud.portal:Connect(openGate)
	hud.zoomIn:Connect(function() mi:zoomStep(1) end)
	hud.zoomOut:Connect(function() mi:zoomStep(-1) end)
	hud.readyTap:Connect(openLayer)
	hud.readyHold:Connect(function(layer: string)
		local ms = lastMs
		local node = if ms then ms.nodes[layer] else nil
		local v = node and node.val
		if v and v.ra then fire(v.ra) end
	end)
	hud.readyMore:Connect(frameReady)
	hud.gateHold:Connect(function()
		local ms = lastMs
		local gate = ms and ms.gate
		if gate and gate.a then fire(gate.a) end
	end)
	local warnOpen = false
	hud.warnTap:Connect(function(abs: Vector2)
		local h = store:hud()
		warnOpen = not warnOpen
		if not warnOpen or h == nil then
			overlay:tooltip("warn", nil)
			return
		end
		local rows = {}
		for _, w in h.w do table.insert(rows, { string.upper(string.sub(w.k, 1, 1)) .. string.sub(w.k, 2) .. " from", w.v }) end
		overlay:tooltip("warn", { title = "Point production is slowed", body = h.wh or h.x, rows = rows,
			hue = Color3.fromHex("ffc233") }, abs)
		task.delay(6, function()
			if warnOpen then
				warnOpen = false
				overlay:tooltip("warn", nil)
			end
		end)
	end)
else
	warn("[MilestoneTree] map preview: no remotes, showing the empty map")
end

-- ------------------------------------------------------------------------------------------------------ loop
local function step(dt: number)
	if not showing then return end
	mi:step(dt)
	view:step(dt)
	Motion.step(dt)
end
local ok = pcall(function()
	(RunService :: any).PreRender:Connect(step)
end)
if not ok then RunService.RenderStepped:Connect(step) end
