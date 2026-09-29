return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		return "POWER BOOSTS SPHERES"
	end,
	--// Levels \\--
	Levels = 1;
	--// Price \\--
	Currency = "Spheres";
	Base_Price = 1e82;
	Price_Scale = 2;
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 0.75;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 0; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 0; -- How many levels per milestone reached
	Exponential = nil;
	
	UpgradeReq = "Prisms_Spheres4";
}