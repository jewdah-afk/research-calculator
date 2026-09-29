local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players") :: Players
local TeleportService = Framework:GetService("TeleportService") :: TeleportService
local AFK = Framework:GetEvent("AFK")

local AntiAFK = {}

function AntiAFK.init()
	AFK.OnServerEvent:Connect(function(Player : Player)
		if Player:GetAttribute("AFK") then return end
		
		Player:SetAttribute("AFK", true)
		
		local plrs = Players:GetPlayers()
		if #plrs >= 2 then -- Enough to tp back into the same server
			local succ, err = pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, {Player})
			end)
			if err then Player:SetAttribute("AFK", false) return end
		end
		
		local teleOptions = Instance.new("TeleportOptions")
		teleOptions.ShouldReserveServer = false
		game:GetService("TeleportService"):TeleportAsync(game.PlaceId, {Player}, teleOptions)
	end)
end

return AntiAFK
