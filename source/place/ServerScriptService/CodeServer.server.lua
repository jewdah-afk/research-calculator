local DataStoreService = game:GetService("DataStoreService")
local HTTPService = game:GetService("HttpService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local CodeDataStore = DataStoreService:GetDataStore("Codes_2")

local frameWork = require(replicatedStorage.Framework)
local codeData = require(serverStorage.Framework.Modules.CodeData)
local redeem_Code = frameWork:GetEvent("Redeem_Code") ::RemoteFunction
local popUp = frameWork:GetEvent("Popup")

local EN = frameWork:GetLibrary("EternityNum")

local redeeming = {}
local redeemedCodes = {}

local Redeeming = {}
local codesRedeemed = {}

local debounceTime = 5

local function rewardPlayer(Player, CodeData)
	local Reward = CodeData.Rewards
	
	for Stat, Value in Reward.Stats or {} do
		local Player_Stat = Player.Stats:FindFirstChild(Stat)
		
		if not Player_Stat then warn("Error with: "..Stat) continue end
		
		if typeof(Player_Stat.Value) == "boolean" then
			Player_Stat.Value = Value
		end

		if typeof(Player_Stat.Value) == "number" then
			Player_Stat.Value += Value
			continue
		end

		if typeof(Player_Stat.Value) == "string" then
			Player_Stat.Value = EN.toString(EN.add(Player_Stat.Value, Value))
			continue
		end
	end
	
	for Potion , Value in Reward.Potions or {} do
		Player.Stats[Potion].Value += Value
	end

	for Rune , Value in Reward.Runes or {} do
		Player.Runes[Rune].Value += Value
	end

	for Gamepass , Value in Reward.Gamepasses or {} do
		Player.Gamepasses[Gamepass].Value = Value
	end
	
	popUp:FireClient(Player, "Success", CodeData.RedeemText)	
end

game.Players.PlayerAdded:Connect(function(Player)
	local Data = CodeDataStore:GetAsync(Player.UserId)
	if Data and Data ~= "null" then 
		codesRedeemed[Player] = HTTPService:JSONDecode(Data)
	else
		codesRedeemed[Player] = {}
	end
end)

redeem_Code.OnServerEvent:Connect(function(plr, Code)	
--	if Redeeming[plr] then popUp:FireClient(plr, "Error", "Please wait at least "..tostring(debounceTime).." seconds") return end
	if Code then
		
		if not codesRedeemed[plr] then 
			return
		end
		
		if Code == nil or Code == "" or Code == " " then
			popUp:FireClient(plr, "Error", "Code textbox is empty, please enter a code!")
			return
		end
		Redeeming[plr] = true 
		
		local code_Info = codeData[Code]
		
		if not table.find(codesRedeemed[plr], Code) then
			if not codeData[Code] then
				popUp:FireClient(plr, "Error", "Code does not exist")
				print("Code does not exist")
				task.wait(debounceTime)
				Redeeming[plr] = nil
				return
			end
			rewardPlayer(plr, code_Info)
			table.insert(codesRedeemed[plr], Code)
		else
			popUp:FireClient(plr, "Error", "Already redeemed!")
		end
		task.wait(debounceTime)
		Redeeming[plr] = nil -- end the cooldown
	end	
end)

game.Players.PlayerRemoving:Connect(function(Player)	
	CodeDataStore:SetAsync(Player.UserId, HTTPService:JSONEncode(codesRedeemed[Player]))
end)	