local module = {}

local Framework = require(game.ReplicatedStorage.Framework)
local ProductHandler = Framework:GetLibrary("ProductHandler")
local Request_Gifting = Framework:GetEvent("Request_Gifting") :: RemoteFunction
local MPS = game:GetService("MarketplaceService")
local Popup = Framework:GetEvent("Popup")


function module.init()
	Request_Gifting.OnServerInvoke = function(Gifter: Player, Reciever, Gift)
		local GiftedPlayer = game.Players:GetPlayerByUserId(tonumber(Reciever))
		if GiftedPlayer then
			if not GiftedPlayer.Settings.Gifting.Value and GiftedPlayer.Name ~= Gifter.Name then
				Popup:FireClient(Gifter, "Error", "This player has gifting disabled!")
				return 
			end
			
			Gifter:SetAttribute("Gifted", Reciever)

			local ID = Gift.ID
			if not ID then return end

			local success, productInfo = pcall(function()
				return MPS:GetProductInfo(ID, Enum.InfoType.GamePass)
			end)

			if success then
				ProductHandler.PurchaseGamepass(Gifter, ID)
				warn(GiftedPlayer.Name.. " 1")
			else
				local success2, productInfo2 = pcall(function()
					return MPS:GetProductInfo(ID, Enum.InfoType.Product)
				end)

				if success2 and productInfo2 then
					ProductHandler.Purchase(Gifter, ID)
					warn(GiftedPlayer.Name.. " 2")
				end
			end
		end
		
		return
	end
end

return module
