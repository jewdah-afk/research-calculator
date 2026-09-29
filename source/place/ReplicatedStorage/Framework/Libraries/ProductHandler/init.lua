local Framework = require(game.ReplicatedStorage.Framework)
local MarketplaceService = Framework:GetService("MarketplaceService") :: MarketplaceService
--[ Events ]--
local Popup = Framework:GetEvent("Popup")
local SFX = Framework:GetEvent("Play_SFX")
--[ Configuration ]--
local Conditions = require(script.Conditions)
local Messages = require(script.Messages)
local Functions = require(script.Functions)
local RTokenPrices = require(script.RTokenPrices)
local Error_Message_Product = "There was an error purchasing this Product! Please try again."
local Error_Message_Gamepass = "There was an error purchasing this Gamepass! Please try again."

local ProductHandler = {}

function ProductHandler.OnPurchase(Player : Player, ProductID : number, GiftedPlayer: Player)
	local Message = Messages[ProductID](Player)
	Popup:FireClient(Player, "Success", Message, Message)
	SFX:FireClient(Player, "Purchase")
	
	if GiftedPlayer then
		Functions[ProductID](GiftedPlayer)
		Player:SetAttribute("Gifted", nil)
		print(Player.Name.." Gifted "..GiftedPlayer.Name)
		return
	end
	
	Functions[ProductID](Player)
end

function ProductHandler.Purchase(Player : Player, ProductID : number)
	if Conditions[ProductID] then
		local Result = Conditions[ProductID](Player)
		if typeof(Result) == "string" then
			Popup:FireClient(Player, "Error", Result)
			return
		end
	end
	
	if not Messages[ProductID] or not Functions[ProductID] then
		Popup:FireClient(Player, "Error", Error_Message_Product)
		return
	end
	
	if Player:GetAttribute("RTokens") and RTokenPrices[ProductID] then
		local Price = RTokenPrices[ProductID]
		
		local RTokens = Player.Stats.RobuxTokens
		if RTokens.Value >= Price then
			RTokens.Value -= Price
			Functions[ProductID](Player)
			return
		end
		
		Popup:FireClient(Player, "Error", `You need {math.floor((Price - RTokens.Value))} more Robux Tokens!`)
		
		return
	end
	
	MarketplaceService:PromptProductPurchase(Player, ProductID)
end

function ProductHandler.PurchaseGamepass(Player : Player, GamepassID : number)
	if Conditions[GamepassID] then
		local Result = Conditions[GamepassID](Player)
		if typeof(Result) == "string" then
			Popup:FireClient(Player, "Error", Result)
			return
		end
	end
	
	if not Messages[GamepassID] or not Functions[GamepassID] then
		Popup:FireClient(Player, "Error", Error_Message_Gamepass)
		return
	end
	
	if Player:GetAttribute("RTokens") then
		local Price = RTokenPrices[GamepassID]
		if not Price then
			Popup:FireClient(Player, "Error", "Robux Tokens error for this product!")
			return
		end
		
		local RTokens = Player.Stats.RobuxTokens
		if RTokens.Value >= Price then
			RTokens.Value -= Price
			Functions[GamepassID](Player)
			return
		end
		
		Popup:FireClient(Player, "Error", `You need {math.floor((Price - RTokens.Value))} more Robux Tokens!`)
		return
	end
	
	MarketplaceService:PromptGamePassPurchase(Player, GamepassID)
end

return ProductHandler
