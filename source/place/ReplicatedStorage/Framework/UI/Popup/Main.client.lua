--[Cookie's Popup System]--
-- Version 0.1 Experimental
local Framework = require(game.ReplicatedStorage.Framework)
local Debris = Framework:GetService("Debris")
local TweenService = Framework:GetService("TweenService")
local Popup = Framework:GetEvent("Popup")

local Template = script.Template
local Container = script.Parent.Container

--[ Animation Settings ]--
local Factor = 1.5 -- How much it grows in size
local PopupInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, true)
local ShrinkInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Original_X = Template.Size.X.Scale
local Original_Y = Template.Size.Y.Scale
local New_X = Template.Size.X.Scale * Factor
local New_Y = Template.Size.Y.Scale * Factor

--[ Animation ]--
function AnimatePopup(Popup_Label : TextLabel)
	local Animation = TweenService:Create(Popup_Label, PopupInfo, {Size = UDim2.new(Original_X,0,New_Y,0)})
	Animation:Play()
end

function ShrinkPopup(Popup_Label : TextLabel)
	local Animation = TweenService:Create(Popup_Label, ShrinkInfo, {Size = UDim2.new(1,0,0,0)})
	Animation:Play()
	Animation.Completed:Wait()
end

--[ Main ]--
function MakePopup(Type : string, Msg : string, OriginalMsg : string)
	local Popup_Label = script.Template:Clone()
	Popup_Label.Name = "Notification"
	Popup_Label.Text = Msg or ""
	Popup_Label.Shadow.Text = OriginalMsg or Popup_Label.Text
	
	local Gradient = (script:FindFirstChild(Type or "Normal") or script.Normal):Clone()
	Gradient.Parent = Popup_Label
	
	Popup_Label.Parent = Container
	
	AnimatePopup(Popup_Label)
	
	task.delay(2.5, function()
		ShrinkPopup(Popup_Label)
		Popup_Label:Destroy()
	end)
end


--[ Event Track ]--
Popup.OnClientEvent:Connect(function(Type : string, Msg : string, OriginalMsg : string)
	MakePopup(Type, Msg)
end)
