local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local RuneStarring = {}

if RunService:IsClient() then
	local Player = game:GetService("Players").LocalPlayer
	local RuneStarring = Player.PlayerGui.RuneStarring

	RunService.RenderStepped:Connect(function()
		--// Teleporter RayCast
		local hmrp = Player.Character:FindFirstChild("HumanoidRootPart")

		local teleporterRaycast = RaycastParams.new()
		teleporterRaycast.FilterType = Enum.RaycastFilterType.Include
		teleporterRaycast.FilterDescendantsInstances = {CollectionService:GetTagged("RuneStarring")}

		local Result = workspace:Raycast(hmrp.Position, Vector3.new(0,-15,0), teleporterRaycast)
		RuneStarring.Enabled = Result
	end)
end

return RuneStarring