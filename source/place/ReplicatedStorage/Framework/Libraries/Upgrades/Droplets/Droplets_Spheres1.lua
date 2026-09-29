return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `x{Effect_1} >> x{Effect_2}`
		end

		return `x{Effect_1}`
	end,
	--// Levels \\--
	Levels = 100;
	--// Price \\--
	Currency = "Droplets";
	Base_Price = "1e15";
	Price_Scale = 25;
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 1.25;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = false; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = nil; -- How many levels per milestone reached
	Exponential = 1.25;

	HasRequirement = function(Player : Player) -- BOOLEAN CHECK
		return Player.Upgrades.Prisms_Droplets2.Value >= 1
	end;
}