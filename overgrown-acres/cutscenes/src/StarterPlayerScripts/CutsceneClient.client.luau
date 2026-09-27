-- Plays cutscenes when the server asks, then reports back how it ended.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cutscene = require(ReplicatedStorage:WaitForChild("Cutscene"))
local definitions = ReplicatedStorage.Cutscene:WaitForChild("Cutscenes")
local remotes = ReplicatedStorage:WaitForChild("CutsceneRemotes")

remotes:WaitForChild("PlayCutscene").OnClientEvent:Connect(function(id: string, options)
	local module = definitions:FindFirstChild(id)
	if not module then
		warn("[Cutscene] No cutscene named " .. tostring(id))
		remotes.CutsceneFinished:FireServer(id, "Failed")
		return
	end
	local result = Cutscene.Play(require(module), options)
	remotes.CutsceneFinished:FireServer(id, result)
end)
