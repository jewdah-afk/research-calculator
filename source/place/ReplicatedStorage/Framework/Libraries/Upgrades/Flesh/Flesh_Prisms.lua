local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")


return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		return "RUNES OPENED BOOST PRISMS"
	end,
	--// Levels \\--
	Levels = 1;
	--// Price \\--
	Currency = "Flesh";
	Base_Price = "1e1383";
	Price_Scale = 2.22;
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 0.85;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 2; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 15; -- How many levels per milestone reached
	Exponential = 1.45;
	
	HasRequirement = function(Player : Player) -- BOOLEAN CHECK
		return EN.meeq(Player.Stats.Spheres.Value, "1e291")
	end;
	
	Spheres = true;
}