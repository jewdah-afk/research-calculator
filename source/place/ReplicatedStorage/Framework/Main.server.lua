local Framework = require(script.Parent)
local ReplicatedStorage = Framework:GetService("ReplicatedStorage")
local Run_Client = Framework:GetEvent("Run_Client")

local player = game.Players.LocalPlayer
--local runeStarring_UI = player.PlayerGui:WaitForChild("RuneStarring")
--local runeStarring_Trigger = workspace.Starring:WaitForChild("Trigger")
local debounce = false

local dropletBoard = workspace.Areas.Arctic:WaitForChild("DropletBoard")
local AmountDisplay = dropletBoard.SurfaceGui.Main:WaitForChild("Amount")
local Content = dropletBoard.SurfaceGui.Main.Content

local dropletsModule = Framework:GetClientModule("DropletsBoard")

Run_Client.OnClientEvent:Connect(function()
	Framework:LoadClient()
end)

--runeStarring_Trigger.Touched:Connect(function(hit)
--	if debounce then return end
--	if hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
--		debounce = true
--		runeStarring_UI.Enabled = true
--	end
--end)

--runeStarring_Trigger.TouchEnded:Connect(function(hit)
--	if not debounce then return end
--	if hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
--		runeStarring_UI.Enabled = false
--		task.wait(1)
--		debounce = false
--	end
--end)

dropletsModule.init()

for i, v in Content:GetChildren() do
	if not v:IsA("Frame") then continue end
	if not v:FindFirstChild("Buy") then return end
	
	v.Buy.Activated:Connect(function()
		--print("activated")
		local call = dropletsModule[v.Name]
	end)
end