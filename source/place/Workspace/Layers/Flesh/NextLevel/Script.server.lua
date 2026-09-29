local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players")
local MobsHandler = Framework:GetLibrary("MobsHandler")

script.Parent.PrimaryPart.Touched:Connect(function(hit)
	if not hit.Parent:FindFirstChild("Humanoid") then return end
	
	local Player = Players:GetPlayerFromCharacter(hit.Parent)
	if Player:GetAttribute("Dead") then return end
	if Player:GetAttribute("Advancing") then return end
	
	Player:SetAttribute("Advancing", true)
	MobsHandler.NextLevel(Player)
	task.spawn(function()
		task.wait(.1)
		Player:SetAttribute("Advancing", false)
	end)
end)