local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")


local Module = {
	-- How much it costs
	Currency = "Droplets";
	Base_Price = 100;
	Price_Scale = 7.5;
	Price_Exponential = 7.5;

	-- What it gives you 
	Gives_Currency = "Water";
	Base_Effect = 1;
	Effect_Scale = 3;
	Effect_Exponential = 3;
	
	Formula = Formulas.Water	
} 


Module.GetHighestEffect = function(Player : Player, percentage : number)
	local PlayerWater = Player.Stats.Water.Value
	local level = math.floor(EN.toNumber(EN.log(PlayerWater,Module.Price_Exponential)))

	return EN.mul(percentage, EN.pow(Module.Effect_Exponential, level))
end

Module.OnPurchase = function(Player : Player, button : Model, amount : number)
	local currency = Player.Stats.Water

	if typeof(currency.Value) == "number" then
		currency.Value += EN.toNumber(amount)
	elseif typeof(currency.Value) == "string" then
		currency.Value = EN.toString(EN.add(currency.Value, amount))
	end
end

Module.Update = function(Player : Player) : string -- VISUAL ONLY!!
	return -- // Possibly use for tweening button
end

Module.HasRequirement = function(Player : Player) -- BOOLEAN CHECK
	return true	
end

return Module