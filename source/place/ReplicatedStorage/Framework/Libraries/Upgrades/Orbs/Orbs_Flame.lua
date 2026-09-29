return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `x{Effect_1} >> x{Effect_2} FLAME`
		end
		
		return `x{Effect_1} FLAME`
	end,
	--// Levels \\--
	Levels = 1e6;
	--// Price \\--
	Currency = "Orbs";
	Base_Price = 1e3;
	Price_Scale = 2;
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 0.85;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 0; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 0; -- How many levels per milestone reached
	Exponential = 1.5;
}