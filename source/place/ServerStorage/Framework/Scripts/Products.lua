local Framework = require(game.ReplicatedStorage.Framework)
--[ Services ]--
local Players = Framework:GetService("Players") :: Players
local MarketplaceService = Framework:GetService("MarketplaceService") :: MarketplaceService
local ReplicatedStorage = Framework:GetService("ReplicatedStorage") :: ReplicatedStorage
--[ Events ]--
local Purchase_Product = Framework:GetEvent("Purchase_Product")
local Purchase_Gamepass = Framework:GetEvent("Purchase_Gamepass")
local Popup = Framework:GetEvent("Popup")
local Request_Gifting = Framework:GetRemoteFunction("Request_Gifting")
--[ Libraries ]--
local ProductHandler = Framework:GetLibrary("ProductHandler")
local RichText = Framework:GetLibrary("RichText")
local EN = Framework:GetLibrary("EternityNum")

local Products = {}

function Products.init()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local RobuxSpent = receiptInfo.CurrencySpent
		local PlayerID = receiptInfo.PlayerId
		print(PlayerID)
		local ProductID = receiptInfo.ProductId
		local Player = Players:GetPlayerByUserId(PlayerID)
		
		Player.Stats.RobuxSpent.Value += RobuxSpent
		--if Player.Stats.Tier.Value >= 12 then
		--	local old = ReplicatedStorage.GlobalGoals.Server.Robux.Value
		--	ReplicatedStorage.GlobalGoals.Server.Robux.Value = EN.toString(EN.add(old, RobuxSpent))
		--end
		
		local giftinfo, giftedPlayer
		if Player:GetAttribute("Gifted") then
			giftinfo = Player:GetAttribute("Gifted")
			giftedPlayer = game.Players:GetPlayerByUserId(tonumber(giftinfo))
		end
		
		ProductHandler.OnPurchase(Player, ProductID, giftedPlayer)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player : Player, GamepassID : number, Purchased : boolean)
		if not Purchased then return end
		local Info = MarketplaceService:GetProductInfo(GamepassID, Enum.InfoType.GamePass)
		local RobuxSpent = Info.PriceInRobux
		Player.Stats.RobuxSpent.Value += RobuxSpent
		--if Player.Stats.Tier.Value >= 12 then
		--	local old = ReplicatedStorage.GlobalGoals.Server.Robux.Value
		--	ReplicatedStorage.GlobalGoals.Server.Robux.Value = EN.toString(EN.add(old, RobuxSpent))
		--end
		local giftinfo, giftedPlayer
		if Player:GetAttribute("Gifted") then
			giftinfo = Player:GetAttribute("Gifted")
			giftedPlayer = game.Players:GetPlayerByUserId(tonumber(giftinfo))
		end
		ProductHandler.OnPurchase(Player, GamepassID, giftedPlayer)
	end)
	
	Purchase_Product.OnServerEvent:Connect(function(Player : Player, ProductID : number)
		ProductHandler.Purchase(Player, ProductID)
	end)
	
	Purchase_Gamepass.OnServerEvent:Connect(function(Player : Player, GamepassID : number)
		ProductHandler.PurchaseGamepass(Player, GamepassID)
	end)
	
	Request_Gifting.OnServerInvoke = function(Player, Gamepass_Name)
		local Eligible = {}

		for _, OtherPlayer in Players:GetPlayers() do
			if OtherPlayer ~= Player then continue end
			
			if not OtherPlayer:GetAttribute("Loaded") then continue end
			if not OtherPlayer.Settings.Gifting.Value then continue end
			if not Gamepass_Name or OtherPlayer.Gamepasses[Gamepass_Name].Value == true then continue end

			table.insert(Eligible, OtherPlayer.Name)
		end

		if #Eligible < 1 then
			Popup:FireClient(Player, "Error", "There are no eligible recipients at the moment!")
		end

		return Eligible
	end
end

return Products
