local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")

local Module = {
	--// Display \\--
	Currency = "Water";
	Base_Price = 1e8;
	Price_Exponential = 250;

	Gives_Currency = "Ice";
	Base_Effect = 1;
	Effect_Exponential = 5;

	Formula = Formulas.Ice

} 

Module.OnPurchase = function(Player : Player, button : Model, amount : number )
	Player.Stats.Droplets.Value = 0
	Player.Stats.Water.Value = 0
	
	local currency = Player.Stats.Ice
	
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
	return Player.Upgrades.Freeze2.Value >= 1 	
end

return Module