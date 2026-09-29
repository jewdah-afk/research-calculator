local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players") :: Players
local TeleportService = Framework:GetService("TeleportService") :: TeleportService
local Follow_Request = Framework:GetEvent("Follow_Request")
local Popup = Framework:GetEvent("Popup")

local FollowRewards = {}

function FollowRewards.init()
	Follow_Request.OnServerEvent:Connect(function(Player : Player, Follow : string)
		if not Player.Stats[Follow].Value  then
			if not Player:GetAttribute(Follow) then Player:SetAttribute(Follow, tick()) end
			
			local Time_Elapsed = tick() - Player:GetAttribute(Follow)
			if Time_Elapsed >= 10 then
				Player.Stats[Follow].Value = true
				Popup:FireClient(Player, "Success", "Your follow request has been verified. Enjoy the bonus!")
				return
			end
			
			Popup:FireClient(Player, "Error", `An error has occurred. Please wait {math.floor(10 - Time_Elapsed)}s before requesting again.`)
			return
		end
		
		Popup:FireClient(Player, "Error", `You have already claimed this follow reward.`)
	end)
end

return FollowRewards
