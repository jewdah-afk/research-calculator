local Framework = require(game.ReplicatedStorage.Framework)
--// Services \\--
local Run_Service = Framework:GetService("RunService")
local Tween_Service = Framework:GetService("TweenService")
local Lighting = Framework:GetService("Lighting")
--// Modules \\--
local TweenHandler = Framework:GetLibrary("TweenHandler")
local Tickets = Framework:GetClientModule("Tickets")
local Tickets_Obj = Tickets.GetLayers()
--// Variables \\--
local Player = Framework:GetPlayer()
local Player_Gui = Framework.Gui
local Grey_Frame = Player_Gui.GreyFrame.Holder
local Buttons = Player_Gui.Buttons

local Topbar = Player_Gui.TopBar

local UI = {}
local Systems = {
	TierBar = require(script.TierBar):init(Player_Gui.TierBar);
	Options = require(script.Options):init();
	Runes = require(script.Runes):init();
	Profile = require(script.Profile);
	LoadingScreen = require(script.LoadingScreen):init();
	Store = require(script.Store):init();
	Stats = require(script.Stats):init();
	Telepoter = require(script.Teleporter);
	RuneStarring = require(script.RuneStarring);
	--FollowRewards = require(script.FollowRewards):init();
	AscensionOne = require(script.AscensionOne);
	Index = require(script.Index):init();
	FollowRewards = require(script.FollowRewards).init()	
}

--// Animations for Frames \\--
local Animated = false
local Frame_Info = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false)
local Blur = Tween_Service:Create(Lighting.Blur, Frame_Info, {Size=9})
local Unblur = Tween_Service:Create(Lighting.Blur, Frame_Info, {Size=0})
local CurrentFrame = nil
local db = false

local function CloseFrame(Frame : string)
	local Screen = Player_Gui:WaitForChild(Frame)
	local Holder = Screen:FindFirstChild("Holder") :: Frame
	if not Holder or not Screen.Enabled then return end

	TweenHandler.Fade(Grey_Frame, 1)
	TweenHandler.TweenFrame(Holder, UDim2.new(0,0,0,0), function()
		Screen.Enabled = false
	end)
end

local function CloseOtherFrames()
	for _ , Gui in Player_Gui:GetChildren() do
		if Gui ~= CurrentFrame then
			CloseFrame(Gui.Name)
		end
	end
end

local function OpenFrame(Frame : string)
	local Screen = Player_Gui:WaitForChild(Frame)
	local Holder = Screen.Holder

	if CurrentFrame then 
		if CurrentFrame == Screen then
			CurrentFrame = nil
			TweenHandler.Unblur()
			CloseFrame(Frame)
			db = false
			return
		end
		CloseFrame(CurrentFrame.Name)
	end

	CurrentFrame = Screen
	TweenHandler.Fade(Grey_Frame, 0.5)
	CurrentFrame.Enabled = true
	TweenHandler.TweenFrame(Holder, UDim2.new(0.5,0,0.6,0))
	TweenHandler.Blur()
	db = false
end

function UI.init()
	for _ , Button in Buttons.Holder1:GetChildren() do
		if Button.ClassName ~= "ImageButton" then continue end
		
		Button.Activated:Connect(function()
			if not db then
				db = true
				OpenFrame(Button.Name)
			end
		end)
	end
	
	for _ , Button in Buttons.Holder2:GetChildren() do
		if Button.ClassName ~= "ImageButton" then continue end

		Button.Activated:Connect(function()
			if not db then
				db = true
				OpenFrame(Button.Name)
			end
		end)
	end
	
	for _, Button in Topbar.Holder:GetChildren() do
		if Button.ClassName ~= "ImageButton" then continue end
		
		Button.Activated:Connect(function()
			if not db then
				db = true
				OpenFrame(Button.Name)
			end
		end)
	end
	
	for _, obj in Tickets_Obj do 
		obj.TicketBoard.SurfaceGui.Main.Shop.Activated:Connect(function()
			if not db then
				db = true
				OpenFrame("Store")
			end
		end)
	end
	
	
	Player_Gui.Runes.Holder.Global.Shop.Shop.Activated:Connect(function()
		if not db then
			db = true
			OpenFrame("Store")
		end
	end)
	
	--// Random Popup Setting \\--
	local StatPopup  = Player_Gui["Stat Popup"]
	StatPopup.Enabled = Player.Settings.Popups.Value
	Player.Settings.Popups:GetPropertyChangedSignal("Value"):Connect(function()
		StatPopup.Enabled = Player.Settings.Popups.Value
	end)
	
	--// UI Updater \\--
	local Timer = 0
	Run_Service.RenderStepped:Connect(function(delta : number)
		Timer += delta
		if Timer >= 1/8 then
			Timer = 0
			if Player.Stats.Tier.Value < 10 then
				Systems.TierBar:Update(Player.Stats.Energy.Value, Player.Stats.Tier.Value)
			else 
				Systems.TierBar:UpdateTierBar2(Player.Stats.Droplets.Value, Player.Stats.Tier.Value)
			end 
			Systems.Profile.Update()
		end
	end)
end

return UI
