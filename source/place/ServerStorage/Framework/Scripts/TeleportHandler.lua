--[[ FRAMEWORK ]]--
local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")

local TeleportEvent = Framework:GetEvent("Teleport_Realm")



local Teleporter = {

	TeleportBlocks = {
		R1 = workspace.Areas["Spawn Island"].Teleporter.Main;
		R2 = workspace.Areas.Arctic.Teleporter.Main;
	};

	PurchasePrices = {
		R2 = EN.fromNumber(5e31)
	};
}


Teleporter.onTeleportEvent = function(player, realm)
	if not realm:match("^R%d+$") then return end
	local playerStats = player:FindFirstChild("Stats")
	
	local isPurchased = playerStats:FindFirstChild(realm .. "_Purchased").Value
	if isPurchased then
		--// Teleport Player to respective position
		local character = player.Character
		local hmrp = character:FindFirstChild("HumanoidRootPart")

		hmrp.CFrame = Teleporter.TeleportBlocks[realm].CFrame

		return true
	else 	
		--// Prompt the purcahse for specific Realm
		local purchasePrice = Teleporter.PurchasePrices[realm]
		if not purchasePrice then return end
		
		local canAfford = EN.meeq(playerStats.Prisms.Value, purchasePrice) 
		if not canAfford then return false end
		local newValue = EN.sub(playerStats.Prisms.Value, purchasePrice)
		playerStats.Prisms.Value = EN.toString(newValue)
		
		--print("got here")
		
		playerStats[realm .. "_Purchased"].Value = true
		print(playerStats[realm .. "_Purchased"].Value)
	end
end

TeleportEvent.OnServerEvent:Connect(Teleporter.onTeleportEvent)

return Teleporter