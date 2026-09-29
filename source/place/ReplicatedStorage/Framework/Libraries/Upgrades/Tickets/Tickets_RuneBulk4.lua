return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `^{Effect_1} >> ^{Effect_2}`
		end

		return `^{Effect_1}`
	end,
	--// Levels \\--
	Levels = 1;
	--// Price \\--
	Currency = "Tickets";
	Base_Price = "2.5e234";
	Price_Scale = 1.6;
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 0.01;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 1.15; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 5; -- How many levels per milestone reached

	HasRequirement = function(Player : Player) -- BOOLEAN CHECK
		return Player.Runes.Torrent.Value >= 1
	end;
}