local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players") :: Players
local EN = Framework:GetLibrary("EternityNum")
local AscensionOneR = Framework:GetEvent("AscensionOne")
local Resets = Framework:GetSharedModule("Resets")
local Popup = Framework:GetEvent("Popup")

local ArcticTeleporter = workspace.Areas.Arctic.Teleporter.Main
local debounce = {}

local AscensionOne = {}

function AscensionOne.init()
	AscensionOneR.OnServerEvent:Connect(function(Player : Player)
		--print("activated")
		local character = Player.Character or Player.CharacterAdded:Wait()
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
		if Player:GetAttribute("Ascending") then return end
		if Player.Stats.AscensionOne.Value == true then 
			task.wait(0.05)
			return 
		end
		if EN.leeq(Player.Stats.Energy.Value, "1e2283") then return end
		
		Popup:FireClient(Player, "Success", "Congratulations on reaching Ascension 1!")
		Player.Stats.AscensionOne.Value = true
		Resets.AscensionOne(Player)
		task.wait(0.05)
		debounce[Player] = nil
	end)
end

return AscensionOne
