return {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `+{Effect_1} Base >> +{Effect_2} Base`
		end
		
		return `+{Effect_1} Base`
	end,
	--// Levels \\--
	Levels = 100;
	--// Price \\--
	Currency = "Light";
	Base_Price = 1000;
	Price_Scale = 1.5;
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level
	--// Effect \\--
	Base_Effect = 1;
	Effect_Scale = 1000;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 2; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 20; -- How many levels per milestone reached
	
	HasRequirement = function(Player : Player) -- BOOLEAN CHECK
		return Player.Stats.Chromify.Value >= 1 and Player.Upgrades.Chromium_LightUpgrade1.Value > 0
	end;

}