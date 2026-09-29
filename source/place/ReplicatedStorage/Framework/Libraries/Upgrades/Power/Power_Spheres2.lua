return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `TICKETS BOOST SPHERES`
		end
		
		return `TICKETS BOOST SPHERES`
	end,
	--// Levels \\--
	Levels = 1;
	--// Price \\--
	Currency = "Power";
	Base_Price = "1e4220";
	Price_Scale = 1.75;
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 0.3;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 2; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 20; -- How many levels per milestone reached

	HasRequirement = function(Player : Player) -- BOOLEAN CHECK
		return Player.Stats.AscensionOne.Value and Player.Stats.Cube_Level.Value >= 1440
	end;
	
	Cube_Level_Req = 600;
}