-- LocalScript (StarterPlayerScripts). Single-player merge mode rendered in a ScreenGui.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("BallGuys")
local Config = require(Modules.Config)
local MergeGame = require(Modules.MergeGame)
local SimpleSim = require(Modules.SimpleSim)

local CUP_W, CUP_H = 30, 40
local DANGER_Y, SPAWN_Y = CUP_H - 2, CUP_H + 2

local gui = Instance.new("ScreenGui")
gui.Name = "MergeGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(214, 218, 224)
bg.Parent = gui

-- Cup area (studs -> pixels via `scale`, recomputed on resize)
local cup = Instance.new("Frame")
cup.AnchorPoint = Vector2.new(0.5, 1)
cup.BackgroundColor3 = Color3.fromRGB(235, 237, 241)
cup.BorderSizePixel = 0
cup.Parent = bg
local cupStroke = Instance.new("UIStroke")
cupStroke.Thickness = 6
cupStroke.Color = Color3.fromRGB(25, 28, 36)
cupStroke.Parent = cup

local line = Instance.new("Frame")
line.BackgroundColor3 = Color3.fromRGB(230, 90, 120)
line.BorderSizePixel = 0
line.Parent = cup

local aim = Instance.new("Frame")
aim.BackgroundColor3 = Color3.new(1, 1, 1)
aim.BackgroundTransparency = 0.5
aim.BorderSizePixel = 0
aim.Parent = cup

local function label(text, pos, anchor)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(25, 28, 36)
	l.Size = UDim2.fromScale(0.3, 0.06)
	l.Position = pos
	l.AnchorPoint = anchor or Vector2.zero
	l.Text = text
	l.Parent = bg
	return l
end
local scoreLabel = label("0", UDim2.fromScale(0.5, 0.02), Vector2.new(0.5, 0))
local comboLabel = label("", UDim2.fromScale(0.5, 0.08), Vector2.new(0.5, 0))
comboLabel.TextColor3 = Color3.fromRGB(230, 90, 150)

local function button(text, pos)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.14, 0.06)
	b.Position = pos
	b.AnchorPoint = Vector2.new(1, 0)
	b.BackgroundColor3 = Color3.fromRGB(255, 120, 165)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Text = text
	Instance.new("UICorner").Parent = b
	b.Parent = bg
	return b
end
local swapBtn = button("Swap", UDim2.fromScale(0.98, 0.2))
local sniperBtn = button("Sniper", UDim2.fromScale(0.98, 0.28))

local nextBox = Instance.new("Frame")
nextBox.Size = UDim2.fromScale(0.1, 0.1)
nextBox.Position = UDim2.fromScale(0.98, 0.04)
nextBox.AnchorPoint = Vector2.new(1, 0)
nextBox.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
Instance.new("UICorner").Parent = nextBox
nextBox.Parent = bg
local nextDot = Instance.new("Frame")
nextDot.AnchorPoint = Vector2.new(0.5, 0.5)
nextDot.Position = UDim2.fromScale(0.5, 0.5)
nextDot.Parent = nextBox
local nextCorner = Instance.new("UICorner")
nextCorner.CornerRadius = UDim.new(1, 0)
nextCorner.Parent = nextDot

local overFrame = Instance.new("TextButton")
overFrame.Size = UDim2.fromScale(1, 1)
overFrame.BackgroundColor3 = Color3.new(0, 0, 0)
overFrame.BackgroundTransparency = 0.4
overFrame.TextColor3 = Color3.new(1, 1, 1)
overFrame.Font = Enum.Font.GothamBlack
overFrame.TextSize = 36
overFrame.Visible = false
overFrame.ZIndex = 10
overFrame.Parent = bg

-- State
local scale = 10
local sim, game_
local visuals = {}
local aimX = 0
local sniperArmed = false

local function circleFrame(tier)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Config.Tiers[tier].color
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(25, 28, 36)
	s.Parent = f
	return f
end

local function toGui(p: Vector2)
	return UDim2.fromOffset((p.X + CUP_W / 2) * scale, (CUP_H - p.Y) * scale)
end

local function layout()
	local vp = bg.AbsoluteSize
	scale = math.min(vp.X * 0.8 / CUP_W, vp.Y * 0.7 / (CUP_H + 6))
	cup.Size = UDim2.fromOffset(CUP_W * scale, CUP_H * scale)
	cup.Position = UDim2.new(0.5, 0, 0.95, 0)
	line.Size = UDim2.fromOffset(CUP_W * scale, 3)
	line.Position = UDim2.fromOffset(0, (CUP_H - DANGER_Y) * scale)
	aim.Size = UDim2.fromOffset(2, CUP_H * scale)
end
bg:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

local function refreshQueue()
	local t = Config.Tiers[game_.next]
	nextDot.BackgroundColor3 = t.color
	nextDot.Size = UDim2.fromScale(0.25 + 0.06 * game_.next, 0.25 + 0.06 * game_.next)
	nextDot.SizeConstraint = Enum.SizeConstraint.RelativeYY
end

local function refreshCharges()
	swapBtn.Text = ("Swap (%d)"):format(game_.charges.Swap)
	sniperBtn.Text = sniperArmed and "Tap a ball" or ("Sniper (%d)"):format(game_.charges.Sniper)
end

local function newRun()
	for _, f in visuals do f:Destroy() end
	visuals = {}
	sim = SimpleSim.new(CUP_W, CUP_H)
	game_ = MergeGame.new(sim:Adapter(), DANGER_Y)
	sniperArmed = false
	scoreLabel.Text = "0"
	comboLabel.Text = ""
	overFrame.Visible = false
	game_.onScore.Event:Connect(function(s) scoreLabel.Text = tostring(s) end)
	game_.onQueue.Event:Connect(refreshQueue)
	game_.onCharges.Event:Connect(refreshCharges)
	game_.onMerge.Event:Connect(function(_, _, pts, chain)
		comboLabel.Text = chain > 1 and ("COMBO x%d  +%d"):format(chain, pts) or ("+%d"):format(pts)
	end)
	game_.onGameOver.Event:Connect(function(s)
		overFrame.Text = ("GAME OVER\nScore: %d\n\nTap to play again"):format(s)
		overFrame.Visible = true
	end)
	refreshQueue()
	refreshCharges()
end

-- Input: drag to aim, release to drop. Works for mouse and touch.
local function pointerToCupX(screenX)
	local x = (screenX - cup.AbsolutePosition.X) / scale - CUP_W / 2
	local r = Config.Tiers[game_.current].radius
	return math.clamp(x, -CUP_W / 2 + r, CUP_W / 2 - r)
end

local function nearestBall(screenPos: Vector2)
	local best, bestD = nil, math.huge
	for b in sim.balls do
		local f = visuals[b]
		if f then
			local c = f.AbsolutePosition + f.AbsoluteSize / 2
			local d = (c - screenPos).Magnitude
			if d < bestD and d < f.AbsoluteSize.X then best, bestD = b, d end
		end
	end
	return best
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseMovement
end

UserInputService.InputChanged:Connect(function(input)
	if isPointer(input) and game_ then aimX = pointerToCupX(input.Position.X) end
end)
UserInputService.InputEnded:Connect(function(input, processed)
	if processed or game_.over then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if sniperArmed then
		local b = nearestBall(Vector2.new(input.Position.X, input.Position.Y))
		if b then game_:UseSniper(b) end
		sniperArmed = false
		refreshCharges()
		return
	end
	aimX = pointerToCupX(input.Position.X)
	game_:Drop(aimX, SPAWN_Y)
end)

swapBtn.Activated:Connect(function() game_:UseSwap() end)
sniperBtn.Activated:Connect(function()
	if game_.charges.Sniper > 0 then sniperArmed = not sniperArmed; refreshCharges() end
end)
overFrame.Activated:Connect(newRun)

RunService.RenderStepped:Connect(function(dt)
	if not game_ then return end
	if not game_.over then
		sim:Step(dt)
		game_:Step()
	end
	-- Sync visuals
	for b in sim.balls do
		local f = visuals[b]
		if not f then
			f = circleFrame(b.tier)
			f.Parent = cup
			visuals[b] = f
		end
		f.Size = UDim2.fromOffset(b.r * 2 * scale, b.r * 2 * scale)
		f.Position = toGui(b.pos)
	end
	for b, f in visuals do
		if not sim.balls[b] then f:Destroy(); visuals[b] = nil end
	end
	aim.Position = UDim2.fromOffset((aimX + CUP_W / 2) * scale, 0)
	local d = game_:DangerLevel()
	line.BackgroundTransparency = d > 0 and (math.sin(os.clock() * 20) * 0.5 + 0.5) * (1 - d) or 0.3
end)

layout()
newRun()
