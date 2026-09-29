return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `x{Effect_1} >> x{Effect_2}`
		end
		
		return `x{Effect_1}`
	end,
	--// Levels \\--
	Levels = 400;
	--// Price \\--
	Currency = "Realm Points";
	Base_Price = 3;
	Price_Scale = 1.5;
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 1.5;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 2; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 15; -- How many levels per milestone reached
}