local Framework = require(game.ReplicatedStorage.Framework)
--// Services \\--
local Run_Service = Framework:GetService("RunService")
--// Classes \\--
local EN = Framework:GetLibrary("EternityNum")
--// Events \\--
local Rune_Reward = Framework:GetEvent("Rune_Reward")
--// Variables \\--
local Display = script.Parent
local Rune_Tracker = {}
local Loop = nil
--// Settings \\--
local Timer = 3

local function AddRune(Rune : string)
	local Label = script.Template:Clone()

	local Gradient = script:FindFirstChild(Rune) or script.Basic
	Label.UIGradient.Color = Gradient.Color
	Label.Name = Rune
	Label.Parent = Display
	table.insert(Rune_Tracker, Label)
end

local function UpdateRune(Rune : string, Amount : number)
	local Label = Display:FindFirstChild(Rune) :: TextLabel
	if not Label then return end

	Label:SetAttribute("Amount", EN.toString(EN.add((Label:GetAttribute("Amount") or 0),Amount)))
	Label:SetAttribute("Last_Updated", tick())
	Label.Text = `+{EN.Format(Label:GetAttribute("Amount"))} {Rune}`

	if Label:GetAttribute("Animating") then return end
	Label:SetAttribute("Animating", true)
	Label:TweenSize(UDim2.new(Label.Size.X.Scale, 0, Label.Size.Y.Scale * 1.12, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.15, false, function()
		Label:TweenSize(UDim2.new(Label.Size.X.Scale, 0, 0.15, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.15)
		Label:SetAttribute("Animating", false)
	end)
end

local function Stop()
	Loop:Disconnect()
	Loop = nil
end

local function Start()
	if Loop then return end
	Loop = Run_Service.RenderStepped:Connect(function(delta: number) 
		if #Rune_Tracker <= 0 then Stop() return end

		for i , Rune in Rune_Tracker do
			local TimeElapsed = tick() - (Rune:GetAttribute("Last_Updated") or tick())
			if TimeElapsed >= Timer then
				Rune_Tracker[i] = nil
				Rune:Destroy()
				continue
			end
		end
	end)
end

Rune_Reward.OnClientEvent:Connect(function(Rewards : {})
	for Rune , Amount in Rewards do
		if not Display:FindFirstChild(Rune) then
			AddRune(Rune)
		end
		UpdateRune(Rune , Amount)
	end

	game.SoundService.Tier:Play()

	if not Loop then Start() end
end)



