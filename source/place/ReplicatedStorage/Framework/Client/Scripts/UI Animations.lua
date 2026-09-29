local Framework = require(game.ReplicatedStorage.Framework)
local Collection_Service = Framework:GetService("CollectionService")
local Sound = Framework:GetService("SoundService")

local Tween_Service = Framework:GetService("TweenService")
local Fade_Info = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.In,0,false)

local UI_Anims = {}

function Add_Hover(Frame : Frame)
	local Original_Size = Frame.Size
	local Factor = Frame:GetAttribute("Grow_Factor") or 1.15
	local SFX = Sound[Frame:GetAttribute("HoverSFX") or "Hover"]
	local X = Frame.Size.X.Scale
	local Y = Frame.Size.Y.Scale
		
	Frame.MouseEnter:Connect(function()
		SFX:Play()
		Frame:TweenSize(UDim2.new(X * Factor, 0, Y * Factor, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.2, true)
	end)
	
	Frame.MouseLeave:Connect(function()
		Frame:TweenSize(UDim2.new(X, 0, Y, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.2, true)
	end)
end

function Show_Title(Frame : Frame)
	local Orig_Pos = Frame.Title.Position
	local End_Pos = Frame.Title:GetAttribute("EndPos") or UDim2.new(1.048,0,Frame.Title.Position.Y.Scale,0)
	
	
	Frame.MouseEnter:Connect(function()
		--Frame.Title.Position = Start_Pos
		Frame:SetAttribute("Hovering", true)
		Tween_Service:Create(Frame.Title, Fade_Info, {TextTransparency = 0}):Play()
		Tween_Service:Create(Frame.Title.UIStroke, Fade_Info, {Transparency = 0}):Play()
		Frame.Title:TweenPosition(End_Pos, Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.2, true)
	end)

	Frame.MouseLeave:Connect(function()
		Frame:SetAttribute("Hovering", false)
		Tween_Service:Create(Frame.Title, Fade_Info, {TextTransparency = 1}):Play()
		Tween_Service:Create(Frame.Title.UIStroke, Fade_Info, {Transparency = 1}):Play()
		Frame.Title:TweenPosition(Orig_Pos, Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.2, true)
	end)
end

function Button_SFX(Button : TextButton)
	local SFX = Sound[Button:GetAttribute("ButtonSFX") or "Click"]
	local X = Button.Size.X.Scale
	local Y = Button.Size.Y.Scale
	local Factor = Button:GetAttribute("Grow_Factor") or 1.15
	
	Button.Activated:Connect(function()
		SFX:Play()
		Button:TweenSize(UDim2.new(X * 0.85, 0, Y * 0.85, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.2, true, function()
			if Button:GetAttribute("Hovering") then
				Button:TweenSize(UDim2.new(X * Factor, 0, Y * Factor, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.2)
				return
			end
			
			Button:TweenSize(UDim2.new(X, 0, Y, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.2)
		end)
	end)
end

function UI_Anims.init()
	Collection_Service:GetInstanceAddedSignal("Hover"):Connect(Add_Hover)
	for _ , Frame in Collection_Service:GetTagged("Hover") do Add_Hover(Frame) end
	
	Collection_Service:GetInstanceAddedSignal("ShowTitle"):Connect(Show_Title)
	for _ , Frame in Collection_Service:GetTagged("ShowTitle") do Show_Title(Frame) end
	
	Collection_Service:GetInstanceAddedSignal("ButtonSFX"):Connect(Button_SFX)
	for _ , Button in Collection_Service:GetTagged("ButtonSFX") do Button_SFX(Button) end
end

return UI_Anims
