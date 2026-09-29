--[ COOKIE FRAMEWORK ]--
-- Version 0.8 Build Version 100
-- Last Updated : Feb 13th, 2025

local Framework = {}
Framework.__index = Framework
Framework = setmetatable({}, Framework)

--[	GENERAL SERVICES ]--
Framework.Services = {
	BadgeService = game:GetService("BadgeService");
	CollectionService = game:GetService("CollectionService");
	ContentProvider = game:GetService("ContentProvider");
	Debris = game:GetService("Debris");
	HttpService = game:GetService("HttpService");
	Lighting = game:GetService("Lighting");
	Players = game:GetService("Players");
	MarketplaceService = game:GetService("MarketplaceService");
	ReplicatedStorage = game:GetService("ReplicatedStorage");
	RunService = game:GetService("RunService");
	SoundService = game:GetService("SoundService");
	TextChatService = game:GetService("TextChatService");
	TweenService = game:GetService("TweenService");
	UserInputService = game:GetService("UserInputService");
}


--[	EVENTS ]--
Framework.Events = {}
for _ , Event in script.Events:GetChildren() do
	Framework.Events[Event.Name] = Event
end


--[	GENERAL FUNCTIONS ]--
function Framework:GetService(Service_Name : string)
	return self.Services[Service_Name]
end

function Framework:GetClientModule(Module_Name : string) : ModuleScript
	return require(self.Client.Modules[Module_Name])
end

function Framework:GetSharedModule(Module_Name : string) : ModuleScript
	return require(self.Shared.Modules[Module_Name])
end

function Framework:GetLibrary(Library_Name)
	return require(script.Libraries[Library_Name])
end

function Framework:SendClientMessage(msg : string)
	Framework.Services.TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage(msg)
end


--[ EVENT RETRIEVAL ]--
function Framework:GetEvent(Event_Name : string) : RemoteEvent
	local Event = self.Events[Event_Name]

	if not Event then
		warn(`Missing Event "{Event_Name}", Creating Event..`)
		Event = Instance.new("RemoteEvent")
		Event.Name = Event_Name
		Event.Parent = script.Events
		self.Events[Event_Name] = Event
		warn(`New Remote Event Created, {Event_Name}`)
	end

	return Event
end

function Framework:GetRemoteFunction(Function_Name : string) : RemoteFunction
	local Event = self.Events[Function_Name]

	if not Event then
		warn(`Missing Remote Function "{Function_Name}", Creating Remote Function..`)
		Event = Instance.new("RemoteFunction")
		Event.Name = Function_Name
		Event.Parent = script.Events
		self.Events[Function_Name] = Event
		warn(`New Remote Function Created, {Function_Name}`)
	end

	return Event
end

function Framework:GetBindableEvent(Bindable_Name : string) : BindableEvent
	local Event = self.Events[Bindable_Name]

	if not Event then
		warn(`Missing Bindable Event "{Bindable_Name}", Creating Bindable..`)
		Event = Instance.new("RemoteFunction")
		Event.Name = Bindable_Name
		Event.Parent = script.Events
		self.Events[Bindable_Name] = Event
		warn(`New Bindable Event Created, {Bindable_Name}`)
	end

	return Event
end


--[ SHARED MODULES ]--
Framework.Shared = script.Shared
local EN = Framework:GetLibrary("EternityNum")

--[	RUN SERVICE ]--
local RunService = Framework.Services.RunService


--[	FRAMEWORK CALLED FROM SERVER ]--
if RunService:IsServer() then

	--[ SERVER-ONLY FUNCTIONS ]--
	function Framework:GetServerModule(Module_Name : string)
		return require(self.Server.Modules[Module_Name])
	end


	function Framework:LoadServer()
		local ProcessingTimes = {}
		for _ , Script in self.Server.Scripts:GetChildren() do
			local Start_Time = tick()
			local Script_Name = Script.Name
			task.spawn(function()
				if Script_Name == "Codes" then return end
				Script = require(Script)
				if not Script then print("err") return end
				if Script.init then
					Script.init()
				end

			end)

			ProcessingTimes[Script_Name] = `{EN.Format(tick() - Start_Time)}s`
		end
		--print(`SERVER | FRAMEWORK | PROCESSING TIMES: `, ProcessingTimes)
	end

	--[ SERVER INITIALIZATION ]--
	Framework.Services.DataStoreService = game:GetService("DataStoreService")
	Framework.Services.ServerStorage = game:GetService("ServerStorage")
	Framework.Services.TeleportService = game:GetService("TeleportService")
	Framework.Services.MessagingService = game:GetService("MessagingService")
	Framework.Services.MemoryStoreService = game:GetService("MemoryStoreService")
	Framework.Server = Framework.Services.ServerStorage:FindFirstChild("Framework")

	--[ AUTO CREATE FRAMEWORK ]--
	if not Framework.Server then
		warn(`Server Framework missing, creating new one..`)
		local Folder = Instance.new("Folder")
		Folder.Name = "Framework"

		local Modules = Instance.new("Folder")
		Modules.Name = "Modules"
		Modules.Parent = Folder

		local Scripts = Instance.new("Folder")
		Scripts.Name = "Scripts"
		Scripts.Parent = Folder

		Folder.Parent = Framework.Services.ServerStorage
		Framework.Server = Folder
		warn(`Server Framework has been created.`)
	end

	Framework.Environment = "Server"

	return Framework
end


--[	FRAMEWORK CALLED FROM CLIENT ]--
if RunService:IsClient() then

	--[	CLIENT-ONLY FUNCTIONS ]--
	function Framework:GetPlayer()
		return self.Services.Players.LocalPlayer
	end

	--[ CLIENT INITIALIZATION ]--
	Framework.Client = script.Client
	Framework.Player = Framework:GetPlayer()
	Framework.Gui = Framework.Player:WaitForChild("PlayerGui")
end

function Framework:LoadClient()
	--[ LOADING SCREEN SYSTEM INITIALIZATION ]--
	--print("Initializing Loading Screen")
	local LoadingScreen = script.UI["Loading Screen"]
	LoadingScreen.Parent = Framework.Gui
	LoadingScreen.Canvas.BG.Bar.Loading.Text = "Initializing UI"

	--[ POPUP SYSTEM INITIALIZATION ]--
	--print("Initializing Popups")
	local Popup = script.UI.Popup
	Popup.Parent = Framework.Gui
	Popup.Main.Enabled = true

	--[ OPTIONS SYSTEM INITIALIZATION ]--
	--print("Initializing Options")
	local Options = script.UI.Options
	Options.Parent = Framework.Gui

	--[ RUNES SYSTEM INITIALIZATION ]--
	--print("Initializing Runes")
	local Runes = script.UI.Runes
	Runes.Parent = Framework.Gui

	--[ PROFILE SYSTEM INITIALIZATION ]--
	--print("Initializing Profile")
	local Profile = script.UI.Profile
	Profile.Parent = Framework.Gui

	--[ STORE SYSTEM INITIALIZATION ]--
	--print("Initializing Store")
	local Store = script.UI.Store
	Store.Parent = Framework.Gui

	--[[ STATS SYSTEM INITIALIZATION ]]--
	--print("Initializing Stats")
	local Stats = script.UI.Stats
	Stats.Parent = Framework.Gui

	--[ STAT POPUP SYSTEM INITIALIZATION ]--
	--print("Initializing Stat Popups")
	local StatPopup = script.UI["Stat Popup"]
	StatPopup.Parent = Framework.Gui
	StatPopup.Main.Enabled = true

	--print("Initializing Stat Popups")
	--local StatPopup = script.UI["Random Stat Popup"]
	--StatPopup.Parent = Framework.Gui
	--StatPopup.Main.Enabled = true

	--[ MARKET TEST INITIALIZATION ]--
	--print("Initializing Market Test")
	--local MarketTest = script.UI["Market Test"]
	--MarketTest.Parent = Framework.Gui
	--MarketTest.Main.Enabled = true

	--[ BUTTONS INITIALIZATION ]--
	--print("Initializing Buttons")
	local Buttons = script.UI.Buttons
	Buttons.Parent = Framework.Gui

	--[[ TOPBAR INITIALIZATION ]]--
	--print("Initializing Topbar")
	local Topbar = script.UI.TopBar
	Topbar.Parent = Framework.Gui

	--[[ UPDATELOG INITLIAIZATION ]]--
	local UpdateLog = script.UI.UpdateLog
	UpdateLog.Parent = Framework.Gui

	--[ FOLLOW REWARDS INITIALIZATION ]--
	local FollowRewards = script.UI.FollowRewards
	FollowRewards.Parent = Framework.Gui

	Framework.Environment = "Client"

	--[ CLIENT SCRIPT INITIALIZATION ]--
	LoadingScreen.Canvas.BG.Bar.Loading.Text = "Initializing Client Scripts"
	local ProcessingTimes = {}
	for _ , Script in self.Client.Scripts:GetChildren() do
		if not Script:GetAttribute("Enabled") then continue end
		local Start_Time = tick()
		local Script_Name = Script.Name

		LoadingScreen.Canvas.BG.Bar.Loading.Text = `Initializing Script: {Script_Name}`
		if Script_Name ~= "Codes" then
			if RunService:IsStudio() then
				Script = require(Script)
				if Script.init then
					Script.init()
				end
			else 
				local success, result = pcall(function()
					Script = require(Script)
					if Script.init then
						Script.init()
					end
				end)
				if not success and RunService:IsStudio() then
					warn(result)
				end
			end
				
		end
		local Time_Taken = tick() - Start_Time
		ProcessingTimes[Script_Name] = `{EN.Format(Time_Taken)}s`
		--stops
		LoadingScreen.Canvas.BG.Bar.Loading.Text = `{Script_Name} initialized in {string.format("%.2f", Time_Taken)}s`
		task.wait(.25)
	end

	print(`CLIENT | FRAMEWORK | PROCESSING TIMES: `, ProcessingTimes)


	--[ Loading Screen Animation Setup ]--
	local TweenService = Framework.Services.TweenService
	local FadeInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	--local Goal = {Size = UDim2.new(0,0,0,0), GroupTransparency = 1}
	local Goal = {GroupTransparency = 1}
	local Tween = TweenService:Create(LoadingScreen.Canvas, FadeInfo, Goal)


	--[ Interact with Loading Screen ]--
	local UIS = Framework.Services.UserInputService
	Tween:Play()
	Tween.Completed:Wait()
	LoadingScreen.Enabled = false
end


return Framework