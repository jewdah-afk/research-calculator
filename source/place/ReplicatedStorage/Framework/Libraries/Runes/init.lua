local Framework = require(game.ReplicatedStorage.Framework)
--// Classes \\--
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local RichText = Framework:GetLibrary("RichText")
local Prefixes = Framework:GetSharedModule("Prefixes")
--// SETTINGS \\--
local luckThreshold = 1e14

local Players = game:GetService("Players")

local Pending = {} -- NEW: For batched reward updates

local Cache = {}
local Runes = {}

task.spawn(function()
	while true do
		for _, player in pairs(Players:GetPlayers()) do
			task.spawn(function()
				local userId = player.UserId
				local playerPending = Pending[userId]

				if playerPending then
					for runeName, amount in playerPending do
						local runeVal = player:FindFirstChild("Runes") and player.Runes:FindFirstChild(runeName)
						if runeVal then
							runeVal.Value += amount
						end
						task.wait(1)
					end
					Pending[userId] = {}
				end
			end)
		end

		task.wait(5) 
	end
end)

Runes.__index = Runes
Runes.__call = function(Table , Key)
	local Spot = Cache[Key]
	
	if not Spot then
		Spot = setmetatable({}, Runes)
		local Spot_Module = require(script[Key])
		
		for Category , Value in Spot_Module do
			Spot[Category] = Value
		end
		
		Spot.Weight = 0
		for _ , Rune in Spot.Runes do
			Spot.Weight += Rune.Chance
		end
		
		Cache[Key] = Spot
	end
	
	return Spot
end

function Runes:CanAfford(Currency : number)
	return EN.meeq(Currency, self.Cost)
end

function Runes:GetRuneTable(Luck : number, Player : Player)
	Luck = Luck or 1
	local Drop_Table = {}
	local Drop_Weight = self.Weight

	for _ , Rune in self.Runes do
		local Chance = Rune.Chance
		local New_Chance = Chance

		if Chance < 0.1 and Luck > 1 then
			New_Chance = Rune.RuneLuck and New_Chance * (Luck ^ 1) or New_Chance
		end

		if Luck > 1 and (Drop_Weight - New_Chance) <= 0 then
			New_Chance = Drop_Weight

			table.insert(Drop_Table, {
				Rune.Name, New_Chance, Chance
			})

			break
		end
		
		if Luck > 1 then Drop_Weight -= New_Chance end

		table.insert(Drop_Table, {
			Rune.Name, New_Chance, Chance, Rune.RuneLuck, Rune.RuneClone 
		})
	end

	table.sort(Drop_Table, function(a, b)
		return a[2] < b[2]
	end)

	return Drop_Table
end

function Runes:GetResult(Luck : number, Bulk : number, Player : Player)
	local Rune_Table = self:GetRuneTable(Luck, Player)
	local Rewards = self:Roll(Luck, Rune_Table, Bulk, Player)
	
	local Total_Cost = EN.mul(Bulk, self.Cost)
	
	return {Rewards = Rewards, Cost = Total_Cost}
end

function Runes:GetRune(Luck : number, Player : Player)
	local RNG = Random.new()
	Luck = RNG:NextNumber(1/luckThreshold, (luckThreshold/Luck) / luckThreshold)
	
	local Counter = 0
	for _ , Rune in self.Runes do
		Counter += Rune.Chance
		if Luck <= Counter then
			self:Broadcast(Rune, Player)
			return Rune
		end
	end
end

function Runes:Broadcast(Rune : {}, Player : Player)

end

function Runes:Roll(Luck : number , Rune_Table : {}, Bulk : number, Player : Player)
	local TimeStart = tick()
	
	local Rewards = {}
	local playerStats = Player.Stats
		
	--[ Bulk Variables ]--
	local Opened = 0
	
	--[ Loop Through Rune Table ]--
	for _ , Info in Rune_Table do
		
		--[ Luck RNG Incorporated ]--
		local RNG = Random.new()
		local RNG_Luck = RNG:NextNumber(1/luckThreshold, (luckThreshold/Luck) / luckThreshold)
	
		--[ Gather Rune Info ]--
		local Name = Info[1]
		local Chance = Info[2]
		local RawChance = Info[3]
		local HasLuck  = Info[4]
		local HasClone = Info[5]
		local PityName = Name.."Pity"
		
		--[ Calc Potential Opens ]--
		local Potential_Opens = Bulk * Chance

		--[ Pity System ]--
		if Potential_Opens < 1 and Name ~= "Bomboclat" then
			local Pity = Player:GetAttribute(PityName) or 0
			Player:SetAttribute(PityName, Pity + Potential_Opens)
			
			if Player:GetAttribute(PityName) >= 1 or RNG_Luck <= Chance then
				Player:SetAttribute(PityName, 0)
				Potential_Opens = 1
			end
		end
		
		--[ Skip Adding to Rewards if not rolled ]--
		if Potential_Opens < 1 then continue end
		
		--[ Round Up to make sure all bulk is used]--
		Potential_Opens = math.round(Potential_Opens)
		
		--[ Add to Reward Table ]--
		local Reward_Amount = Potential_Opens
		if HasClone then 
			if Player.Stats.RuneCloneProduct.Value > 0 and RawChance >= (1 / Formulas.Product_RuneClone(Player)) and Player.Upgrades.Prisms_RuneClone.Value == 0 then
				Reward_Amount *= 2
			end
			if Player.Stats.RuneCloneProduct.Value == 0 and Player.Upgrades.Prisms_RuneClone.Value > 0 then
				Reward_Amount *= 2
			end
			if Player.Stats.RuneCloneProduct.Value > 0 and RawChance >= (1 / Formulas.Product_RuneClone(Player)) and Player.Upgrades.Prisms_RuneClone.Value > 0 then
				Reward_Amount *= 3
			end
		end
		Reward_Amount = math.floor(Reward_Amount)
				
		Rewards[Name] = Reward_Amount
		if not Pending[Player.UserId] then
			Pending[Player.UserId] = {}
		end
		
		Pending[Player.UserId][Name] = math.floor((Pending[Player.UserId][Name] or 0) + Reward_Amount)

		Opened += Potential_Opens
		if Opened >= Bulk then break end
	end
	
	return Rewards
end

return setmetatable({}, Runes)
