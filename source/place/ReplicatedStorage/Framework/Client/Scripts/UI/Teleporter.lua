local Framework = require(game.ReplicatedStorage.Framework)

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Players = Framework:GetService("Players")
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()
local Stats = Player.Stats
local Ascension = Stats.AscensionOne
local Perform = Framework:GetEvent("AscensionOne")

local MainGui = Framework.Gui
local TeleporterGui = MainGui.Teleporter
local Holder = TeleporterGui:WaitForChild("Holder")
local TeleporterContents = Holder:WaitForChild("Content")

local TeleporterObject = game.Workspace.Areas["Spawn Island"].Teleporter.Teleporter

local TeleportEvent = Framework:GetEvent("Teleport_Realm")
local RunningEvent = false

local Teleporter = {}

local function Update(frame)
	local isPurchased = Stats:FindFirstChild(frame.Name .. "_Purchased").Value
	
	local tpButton = frame:FindFirstChild("TP")
	
	if isPurchased then 
		tpButton:FindFirstChild("Buy").Text = "TELEPORT"	
		frame:FindFirstChild("Amount").Visible = false
		return
	end
	
	tpButton:FindFirstChild("Buy").Text = "BUY"	
	frame:FindFirstChild("Amount").Visible = true
end

local function onButtonPress(frame)
	--// Will either teleoport or invoke a purchase request
	TeleportEvent:FireServer(frame.Name)
end

local function EnableTeleporter()
	local AscensionOneValue = Stats["AscensionOne"]
	if AscensionOneValue.Value and (not RunningEvent) then
		--// Make Teleporter visible on map
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		TeleporterObject.Parent = game.Workspace.Areas["Spawn Island"].Teleporter
		
		RunService.RenderStepped:Connect(function()
			--// Teleporter RayCast
			local hmrp = Player.Character:FindFirstChild("HumanoidRootPart")
			
			local teleporterRaycast = RaycastParams.new()
			teleporterRaycast.FilterType = Enum.RaycastFilterType.Include
			teleporterRaycast.FilterDescendantsInstances = {CollectionService:GetTagged("Teleporter")}
			
			local Result = workspace:Raycast(hmrp.Position, Vector3.new(0,-15,0), teleporterRaycast)
			TeleporterGui.Enabled = Result
		end)
		
		RunningEvent = true
	else 
		if not AscensionOneValue.Value then 
			TeleporterObject.Parent = game:GetService("ReplicatedStorage")
		end
	end
end

for index, value in TeleporterContents:GetChildren() do 
	if value:IsA("Frame") and value.Name:match("^R%d+$") then
		Update(value)	
		Stats[value.Name .. "_Purchased"]:GetPropertyChangedSignal("Value"):Connect(function()
			Update(value)
		end)

		local tpButton = value:WaitForChild("TP")
		
		tpButton.Activated:Connect(function()
			onButtonPress(value)
		end)		
	end
end
	
EnableTeleporter()
Stats["AscensionOne"]:GetPropertyChangedSignal("Value"):Connect(EnableTeleporter)
	
	
return Teleporter