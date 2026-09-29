--[Cookie's Stat Popup System]--
-- Version 0.1 Experimental
local Framework = require(game.ReplicatedStorage.Framework)
local Debris = Framework:GetService("Debris")
local TweenService = Framework:GetService("TweenService")
local Stat_Popup = Framework:GetEvent("Stat_Popup")
local EN = Framework:GetLibrary("EternityNum")
local RichText = Framework:GetLibrary("RichText")

local Template = script.Template
local Container = script.Parent.Container
local Colors = require(script.Colors)

--[ Animation Settings ]--
local Factor = 1.5 -- How much it grows in size
local PopupInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, true)
local ShrinkInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Original_X = Template.Size.X.Scale
local Original_Y = Template.Size.Y.Scale
local New_X = Template.Size.X.Scale * Factor
local New_Y = Template.Size.Y.Scale * Factor

--[ Active Popup Tracker ]--
local ActivePopups = {}
local MAX_POPUPS = 2

--[ Animation Functions ]--
local function AnimatePopup(Popup_Label : TextLabel)
	local Animation = TweenService:Create(Popup_Label, PopupInfo, {Size = UDim2.new(Original_X, 0, New_Y, 0)})
	Animation:Play()
end

local function ShrinkPopup(Popup_Label : TextLabel)
	local Animation = TweenService:Create(Popup_Label, ShrinkInfo, {Size = UDim2.new(1, 0, 0, 0)})
	Animation:Play()
	Animation.Completed:Wait()
end

--[ Main Popup Creation ]--
local function MakePopup(Type : string, Stat : string, Gained : string)
	-- If we already have 2 popups, remove the oldest
	if #ActivePopups >= MAX_POPUPS then
		local OldestPopup = table.remove(ActivePopups, 1)
		OldestPopup:Destroy()
	end

	-- Create a new popup label
	local Popup_Label = Template:Clone()
	Popup_Label.Name = "Notification"

	-- Set up stat text and color
	local Stat_Text = Stat
	local Stat_Color = Colors[Stat]
	if Stat_Color then
		Stat_Text = RichText(Stat_Text)
		Stat_Text:Colored(Colors[Stat])
		Stat_Text = Stat_Text:Return()
	end

	-- Format the gained value and the message
	Gained = EN.Format(Gained)
	local Original_Message = `+{Gained} {Stat}`
	local Gain_Message = `+{Gained} {Stat_Text}`
	Popup_Label.Text = Gain_Message
	Popup_Label.Shadow.Text = Original_Message

	-- Set the gradient color for the popup
	local Gradient = (script:FindFirstChild(Stat or "Normal") or script.Normal):Clone()
	Gradient.Parent = Popup_Label
	Popup_Label.Parent = Container

	-- Animate the popup and add to active popups
	AnimatePopup(Popup_Label)
	table.insert(ActivePopups, Popup_Label)

	-- Shrink and destroy the popup after delay
	task.delay(2, function()
		ShrinkPopup(Popup_Label)
		Popup_Label:Destroy()
		-- Remove from active popups after it's destroyed
		for i, activePopup in ipairs(ActivePopups) do
			if activePopup == Popup_Label then
				table.remove(ActivePopups, i)
				break
			end
		end
	end)
end

--[ Event Listener ]--
Stat_Popup.OnClientEvent:Connect(function(Type : string, Stat : string, Gained : number)
	MakePopup(Type, Stat, Gained)
end)