--!strict
--[[
	MapPreview: shows the realm map full screen over the current page UI, so the new map (nodes, links, plates, edge
	markers) can be tried in Studio before the new client replaces the page. It listens to the same View patches as
	the page (a ViewStore of its own), so the map shows the live game: node states, READY badges, plates.

	    drag / touch-drag      pan            wheel / pinch / double-click     zoom
	    click a node           opens that layer in the page UI (the panel comes with the new client)
	    M or the GAME button   switch between the map and the page UI

	App.luau takes the map over when the new client lands; this script is then deleted.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = script.Parent:WaitForChild("Core")
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Theme = require(Core:WaitForChild("Theme"))
local ViewStore = require(Core:WaitForChild("ViewStore"))
local Input = require(script.Parent:WaitForChild("Input"):WaitForChild("Input"))
local MapFolder = script.Parent:WaitForChild("Map")
local MapView = require(MapFolder:WaitForChild("MapView"))
local MapInput = require(MapFolder:WaitForChild("MapInput"))
local Nodes = require(MapFolder:WaitForChild("Nodes"))
local Links = require(MapFolder:WaitForChild("Links"))
local Plates = require(MapFolder:WaitForChild("Plates"))
local Markers = require(MapFolder:WaitForChild("Markers"))

local lp = Players.LocalPlayer
Input.start()

-- above the page UI (its popups use DisplayOrder 20)
local gui, root = Layout.screen("MapGui", 40, Enum.ScreenInsets.None)
local view = MapView.new(gui, root, { tier = MapView.chooseTier() })
local mi = MapInput.new(view, Input)
local markerGui = Layout.screen("MarkerGui", 41, Enum.ScreenInsets.DeviceSafeInsets)

local nodes = Nodes.new(view, mi)
local links = Links.new(view)
local plates = Plates.new(view, nodes)
local markers = Markers.new(markerGui, view, nodes)

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
	mi:setEnabled(on)
	view:setAmbient(on)
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
end
local function onHud()
	local h = store:hud()
	if h then nodes:setFirstRun(h.fr) end
end

if remotes then
	local viewRemote = remotes:WaitForChild("View") :: RemoteEvent
	local actRemote = remotes:WaitForChild("Act") :: RemoteEvent
	local readyRemote = remotes:WaitForChild("Ready") :: RemoteEvent
	viewRemote.OnClientEvent:Connect(function(patch: any)
		if type(patch) ~= "table" or patch.fatal or patch.status then return end
		local ok, err = pcall(function()
			local changes = store:apply(patch)
			if changes.full then gotFull = true end
			if changes.map then onMap() end
			if changes.hud then onHud() end
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
	-- a node opens its layer in the page UI (the side sheet comes with the new client)
	nodes.activated:Connect(function(layer: string)
		local ms = lastMs
		local node = if ms then ms.nodes[layer] else nil
		if node == nil or not node.show then return end
		fire(node.a)
		view:focusWorld(nodes:worldPos(layer))
		task.delay(0.35, function()
			if showing then show(false) end
		end)
	end)
	markers.activated:Connect(function(layer: string)
		view:focusWorld(nodes:worldPos(layer))
	end)
	nodes.rift:Connect(function(event: string)
		if event == "click" then view:focusWorld(Vector2.new(3150, 1350)) end
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
