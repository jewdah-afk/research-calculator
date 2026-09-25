--!strict
--[[
	MapPreview: shows the realm map full screen over the current page UI, so the map's look and feel (parallax, drag,
	zoom, ambient motion) can be tried in Studio before the new client replaces the page. The layer nodes sit in
	their sockets as plain discs; they do nothing yet.

	    drag / touch-drag      pan            wheel / pinch / double-click     zoom
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
local Input = require(script.Parent:WaitForChild("Input"):WaitForChild("Input"))
local MapView = require(script.Parent:WaitForChild("Map"):WaitForChild("MapView"))
local MapInput = require(script.Parent:WaitForChild("Map"):WaitForChild("MapInput"))
local Realm: any = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Realm"))

-- above the page UI (its popups use DisplayOrder 20)
local gui, root = Layout.screen("MapGui", 40, Enum.ScreenInsets.None)
local view = MapView.new(gui, root, { tier = MapView.chooseTier() })
local mi = MapInput.new(view, Input)

-- ------------------------------------------------------------------------------------------------------ nodes
local WORLD_W, WORLD_H = Realm.world.w, Realm.world.h
local DIAMETER = 118
for key, at in Realm.nodes do
	local layer = if key == "cr" then "cp" else key
	local hue = Theme.hue(layer)
	local disc = Instance.new("Frame")
	disc.Name = key
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(at[1] / WORLD_W, at[2] / WORLD_H)
	disc.Size = UDim2.fromScale(DIAMETER / WORLD_W, DIAMETER / WORLD_H)
	disc.BackgroundColor3 = hue
	disc.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.mix(hue, Color3.new(1, 1, 1), 0.55)),
		ColorSequenceKeypoint.new(0.55, hue),
		ColorSequenceKeypoint.new(1, Theme.mix(hue, Color3.new(0, 0, 0), 0.55)),
	})
	if Theme.caps.Radial then
		pcall(function() (grad :: any).Type = (Enum :: any).GradientType.Radial end)
	else
		grad.Rotation = 90
	end
	grad.Parent = disc
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.mix(hue, Color3.new(1, 1, 1), 0.35)
	stroke.Thickness = 2
	stroke.Parent = disc
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = string.upper(key)
	label.TextScaled = true
	label.FontFace = Theme.font("index")
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.2, 0), UDim.new(0.2, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.26, 0), UDim.new(0.26, 0)
	pad.Parent = label
	label.Parent = disc
	disc.Parent = view.nodes
end

-- ------------------------------------------------------------------------------------------------------ switch
local hud = Instance.new("ScreenGui")
hud.Name = "HudGui"
hud.ResetOnSpawn = false
hud.DisplayOrder = 41
hud.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(1, 0)
button.Position = UDim2.new(1, -16, 0, 12)
button.Size = UDim2.fromOffset(132, 40)
button.BackgroundColor3 = Theme.C.panel
button.TextColor3 = Theme.C.text
button.FontFace = Theme.font("tab")
button.TextSize = 16
button.AutoButtonColor = true
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0.5, 0)
bc.Parent = button
local bs = Instance.new("UIStroke")
bs.Color = Theme.hue("t")
bs.Thickness = 2
bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bs.Parent = button
button.Parent = hud
local lp = Players.LocalPlayer
hud.Parent = lp:WaitForChild("PlayerGui")

local showing = true
local function show(on: boolean)
	showing = on
	gui.Enabled = on
	mi:setEnabled(on)
	view:setAmbient(on)
	button.Text = if on then "GAME" else "MAP"
end
button.Activated:Connect(function() show(not showing) end)
UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
	if not processed and io.KeyCode == Enum.KeyCode.M then show(not showing) end
end)
show(true)

view:preload(function() end)
view:frameStart({ intro = true })

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
