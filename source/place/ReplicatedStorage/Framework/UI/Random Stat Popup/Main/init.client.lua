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

--[ Animation ]--
function GetRandomPosition()
	local ContainerSize = Container.AbsoluteSize
	
	local Random_X = math.random(0, ContainerSize.X - (Template.Size.X.Offset * 2))
	local Random_Y = math.random(0, ContainerSize.Y - (Template.Size.Y.Offset * 2))
	
	return UDim2.new(0, Random_X, 0, Random_Y)
end

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
function MakePopup(Type : string, Stat : string, Gained : string)
	local Popup_Label = script.Template:Clone()
	Popup_Label.Name = "Notification"
	
	local Stat_Text = Stat
	local Stat_Color = Colors[Stat]
	if Stat_Color then
		Stat_Text = RichText(Stat_Text)
		Stat_Text:Colored(Colors[Stat])
		Stat_Text = Stat_Text:Return()
	end
	
	Gained = EN.Format(Gained)
	local Original_Message = `+{Gained} {Stat}`
	local Gain_Message = `+{EN.Format(Gained)} {Stat_Text}`
	Popup_Label.Text = Gain_Message
	Popup_Label.Shadow.Text = Original_Message
	
	local Gradient = (script:FindFirstChild(Stat or "Normal") or script.Normal):Clone()
	Gradient.Parent = Popup_Label
	
	Popup_Label.Position = GetRandomPosition()
	Popup_Label.Parent = Container
	
	AnimatePopup(Popup_Label)
	
	task.delay(1, function()
		ShrinkPopup(Popup_Label)
		Popup_Label:Destroy()
	end)
end


--[ Event Track ]--
Stat_Popup.OnClientEvent:Connect(function(Type : string, Stat : string, Gained : number)
	MakePopup(Type, Stat, Gained)
end)

--[Testing]--
while true do
	MakePopup("Normal", "Test", 100)
	task.wait(0.25)
end