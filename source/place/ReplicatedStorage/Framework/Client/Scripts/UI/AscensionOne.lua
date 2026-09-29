local Framework = require(game.ReplicatedStorage.Framework)

local Players = Framework:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = game.Players.LocalPlayer
local Stats = Player.Stats
local Ascension = Stats.AscensionOne
local Perform = Framework:GetEvent("AscensionOne")
local RequestData: RemoteFunction = Framework:GetEvent("Request_Data")

local Teleporter = game:GetService("ReplicatedStorage"):FindFirstChild("Teleporter") or workspace:FindFirstChild("Teleporter")

local Gui = Framework.Gui
local Screen = Gui.AscensionOne
local Holder = Screen.Holder
local Button = Holder.Ascend
local RunningEvent = false

local AscensionOne = {}

local function Update()
	local result = RequestData:InvokeServer(Ascension.Name, Ascension.Parent.Name, Ascension.Value)
	if result ~= true then return end
	
	print(Ascension.Value)
	Holder.Visible = Ascension.Value
	if Ascension.Value then
		Button.Buy.Text = "ALREADY ASCENDED"
	else
		Button.Buy.Text = "ASCEND"
		if Teleporter then
			--Teleporter.Parent = game.ReplicatedStorage
		end
	end
end

local function EnableAscension()
	if (not RunningEvent) then
		--// Make Teleporter visible on map
		local ReplicatedStorage = game:GetService("ReplicatedStorage")

		RunService.RenderStepped:Connect(function()
			--// Teleporter RayCast
			local hmrp = Player.Character:FindFirstChild("HumanoidRootPart")

			local teleporterRaycast = RaycastParams.new()
			teleporterRaycast.FilterType = Enum.RaycastFilterType.Include
			teleporterRaycast.FilterDescendantsInstances = {CollectionService:GetTagged("AscensionOne")}

			local Result = workspace:Raycast(hmrp.Position, Vector3.new(0,-15,0), teleporterRaycast)
			Screen.Enabled = Result
		end)

		RunningEvent = true
	end
end

Button.Activated:Connect(function()
	Perform:FireServer()
end)

Update()
EnableAscension()
Ascension:GetPropertyChangedSignal("Value"):Connect(Update)

return AscensionOne