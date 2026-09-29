local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")

local Module = {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `x{Effect_1} >> x{Effect_2}`
		end

		return `x{Effect_1}`
	end,
	--// Levels \\--
	Levels = 24;
	--// Price \\--
	Currency = "RobuxTokens";
	Base_Price = 25;
	Price_Scale = 1.1;
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level
	
	--// Effect | IGNORE THIS SECTION FOR TALENT TREE \\--
	Base_Effect = 1;
	Effect_Scale = 1;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 0; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = nil; -- How many levels per milestone reached
	Exponential = nil;
}

Module.CustomEffect = function(Player : Player)
	local Level = Player.Upgrades[script.Name].Value
	local Effect = (Module.Effect_Scale * Level)

	return `+{EN.Format(Effect)} RPS`
end

Module.Update = function(Player : Player) -- VISUAL ONLY!!
	
end

Module.HasRequirement = function(Player : Player) -- BOOLEAN CHECK
	return Player.Runes.Rocket.Value > 0
end

return Module