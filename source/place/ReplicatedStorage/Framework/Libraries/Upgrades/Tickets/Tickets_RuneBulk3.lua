return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `x{Effect_1} >> x{Effect_2}`
		end

		return `x{Effect_1}`
	end,
	--// Levels \\--
	Levels = 75;
	--// Price \\--
	Currency = "Tickets";
	Base_Price = "1e131";
	Price_Scale = 1.6;
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 0.075;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 1.15; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 5; -- How many levels per milestone reached

	HasRequirement = function(Player : Player) -- BOOLEAN CHECK
		return Player.Runes.Squid.Value >= 1
	end;
}