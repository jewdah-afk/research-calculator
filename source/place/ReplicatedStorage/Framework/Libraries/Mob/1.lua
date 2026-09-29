local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local RandomElixir = Framework:GetSharedModule("RandomElixir")
local Popup = Framework:GetEvent("Stat_Popup")
local Module = {}
Module.Title = "Magma"
local RTokensRatio = 1

local function ChestReward(Player : Player, RNG : number)
	if RNG <= 0.001 then
		Player.Stats.RobuxTokens.Value += (math.random(35, 175)* RTokensRatio) 
		return
	end

	if RNG <= 0.005 then
		for i = 1, 3 do
			RandomElixir(Player, 1)
		end
		return
	end

	if RNG <= 0.139 then
		Player.Stats.RobuxTokens.Value += (math.random(1, 10)* RTokensRatio) 
		return
	end

	if RNG <= 0.25 then
		RandomElixir(Player, 1)
		return
	end
	
	return "Flesh"
end

Module.Reward = function(Player : Player, Mob : number, Type : string)
	--// Give Flesh \\--
	local Min_Flesh = EN.mul(1, EN.pow(1.5, math.max(Mob - 1, 0)))
	local Max_Flesh = EN.mul(3, EN.pow(1.5, math.max(Mob - 1, 0)))
	local Generated = EN.rand(Min_Flesh, Max_Flesh)
	local Total = Formulas.Flesh(Player, Generated)
	
	if Type == "Chest" then
		local Reward = ChestReward(Player, math.random())
		
		if Reward == "Flesh" then
			Total = EN.mul(Total, 100)
		end
	end
	
	local New_Value = EN.add(Player.Stats.Flesh.Value, Total)
	Player.Stats.Flesh.Value = EN.toString(New_Value)
	
	if Player.Upgrades.Prisms_AutoAttack.Value <= 0 then
		Popup:FireClient(Player, "Normal", "Flesh", Total)
	end
end

return Module