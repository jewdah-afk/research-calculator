return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `-{Effect_1}s >> -{Effect_2}S SPAWN TIME`
		end
		
		return `-{Effect_1}S SPAWN TIME`
	end,
	--// Levels \\--
	Levels = 20;
	--// Price \\--
	Currency = "Orbs";
	Base_Price = 5e3;
	Price_Scale = 5;
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 0;
	Effect_Scale = 0.5;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 0; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 0; -- How many levels per milestone reached
	Exponential = nil;
}