--[[ FRAMEWORK ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ SERVICES ]]--
local TweenService = Framework:GetService("TweenService")
local Lighting = Framework:GetService("Lighting")

--[[ VARIABLES ]]--
local FrameInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false)

local TweenHandler = {}

--[[ FUNCTIONS ]]--
function TweenHandler.Blur()
	local BlurEffect = TweenService:Create(Lighting.Blur, FrameInfo, {Size = 9})
	local FieldOfView = TweenService:Create(workspace.CurrentCamera, FrameInfo, {FieldOfView = 100})
	
	BlurEffect:Play()
	FieldOfView:Play()
	
	BlurEffect.Completed:Wait()
end

function TweenHandler.Unblur()
	local BlurEffect = TweenService:Create(Lighting.Blur, FrameInfo, {Size = 0})
	local FieldOfView = TweenService:Create(workspace.CurrentCamera, FrameInfo, {FieldOfView = 70})
	
	BlurEffect:Play()
	FieldOfView:Play()
end

function TweenHandler.TweenFrame(Frame, Size, Callback)
	local Tween = TweenService:Create(Frame, FrameInfo, {Size = Size})
	
	Tween:Play()
	
	if Callback then
		Tween.Completed:Connect(Callback)
	end
end

function TweenHandler.Fade(Frame, Transparency, Callback)
	local Tween = TweenService:Create(Frame, FrameInfo, {BackgroundTransparency = Transparency})
	
	Tween:Play()
	
	if Callback then
		Tween.Completed:Connect(Callback)
	end
end

return TweenHandler