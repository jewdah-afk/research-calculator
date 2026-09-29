local Framework = require(game.ReplicatedStorage.Framework)
local Tween_Service = Framework:GetService("TweenService")
local ToggleSetting = Framework:GetEvent("Toggle_Setting")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()
local Gui = Framework.Gui
local Screen = Gui.Options
repeat task.wait() until Player:GetAttribute("Loaded")

local Bool_Info = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local Enabled_Goal = {BackgroundColor3 = Color3.fromRGB(61, 255, 67)}
local Disabled_Goal = {BackgroundColor3 = Color3.fromRGB(255, 57, 57)}

local Options = {}

function AddBoolSetting(Player_Setting : ValueBase, Setting : Frame)
	local function Update()
		if Player_Setting.Value then
			local Anim = Tween_Service:Create(Setting.Toggle, Bool_Info, Enabled_Goal)
			Anim:Play()
			Anim.Completed:Wait()
			Setting.Toggle.Display.Text = "On"
			Setting.Toggle.Active = true
			return
		end

		local Anim = Tween_Service:Create(Setting.Toggle, Bool_Info, Disabled_Goal)
		Anim:Play()
		Anim.Completed:Wait()
		Setting.Toggle.Display.Text = "Off"
		Setting.Toggle.Active = true
	end

	Update()
	Player_Setting:GetPropertyChangedSignal("Value"):Connect(Update)

	Setting.Toggle.Activated:Connect(function()
		Setting.Toggle.Active = false
		ToggleSetting:FireServer(Setting.Name)
	end)
end

function AddNumberSetting(Player_Setting : ValueBase, Setting : Frame)
	local TextBox = Setting:FindFirstChild("Text").TextBox

	local function Update()
		TextBox.Text = Player_Setting.Value
	end

	TextBox:GetPropertyChangedSignal("Text"):Connect(function()
		local Input = tonumber(TextBox.Text)
		local MaxInput = 1
		local Min = 1

		if Setting.Name == "SetRuneLuck" then
			MaxInput = Formulas.Rune_Luck(Player)
		end

		if Setting.Name == "SetWalkSpeed" then
			Min = 10
			MaxInput = Formulas.Walkspeed(Player)
		end

		if not Input then return end

		local Formula = math.clamp(Input, 1, MaxInput)

		if Input ~= Formula then
			TextBox.Text = tostring(Formula)
		end
	end)

	TextBox.FocusLost:Connect(function(Enter)
		if not Enter then return end

		local Input = tonumber(TextBox.Text)
		local MaxInput = 1
		local Min = 1
		
		if Setting.Name == "SetRuneLuck" then
			MaxInput = Formulas.Rune_Luck(Player)
		end

		if Setting.Name == "SetWalkSpeed" then
			Min = 16
			MaxInput = Formulas.Walkspeed(Player)
		end

		Input = math.clamp(Input, Min, MaxInput)

		ToggleSetting:FireServer(Setting.Name, Input)
	end)
	
	Update()
	
	Player_Setting:GetPropertyChangedSignal("Value"):Connect(function()
		Update()
	end)
end

function Options:init()
	for _ , v in Screen.Holder.General.Content:GetChildren() do
		if v.ClassName ~= "Frame" then continue end
		AddBoolSetting(Player.Settings[v.Name], v)
	end

	for _, v in Screen.Holder.Game.Content:GetChildren() do
		if v.ClassName ~= "Frame" then continue end

		if v:FindFirstChild("Toggle") then
			AddBoolSetting(Player.Settings[v.Name], v)
		else
			AddNumberSetting(Player.Settings[v.Name], v)
		end
	end
end

return Options