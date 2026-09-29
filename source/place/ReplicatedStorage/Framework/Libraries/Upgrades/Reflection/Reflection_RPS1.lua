return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `x{Effect_1} >> x{Effect_2}`
		end
		
		return `x{Effect_1}`
	end,
	--// Levels \\--
	Levels = 2;
	--// Price \\--
	Currency = "Reflection";
	Base_Price = 1e12;
	Price_Scale = 1000;
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 0;
	Reverse = false; -- Subtracts from base instead of adds
	Exponential = 2;
	
	HasRequirement = function(Player : Player) -- BOOLEAN CHECK
		return Player.Stats.Chromify.Value >= 3
	end;

}