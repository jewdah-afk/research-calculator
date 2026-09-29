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
	Currency = "Droplets";
	Base_Price = "1e183";
	Price_Scale = 3;
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 3;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = false; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = nil; -- How many levels per milestone reached
	Exponential = 3;

	HasRequirement = function(Player : Player) -- BOOLEAN CHECK
		return Player.Upgrades.Freeze9.Value >= 1
	end;
}