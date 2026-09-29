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
	Levels = 1;
	--// Price \\--
	Currency = "Prisms";
	Base_Price = 2e19;
	Price_Scale = 1.5;
	Price_Jump = {10, 1}; -- {Every x, Scale}
	Price_Jump2 = {24, 1}; -- {Every x, Scale}
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level
	
	--// Effect | IGNORE THIS SECTION FOR TALENT TREE \\--
	Base_Effect = 1;
	Effect_Scale = 0.85;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 2; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 15; -- How many levels per milestone reached
	Exponential = nil;
}

Module.CustomEffect = function(Player : Player)
	
end

Module.Update = function(Player : Player) -- VISUAL ONLY!!
	
end

Module.HasRequirement = function(Player : Player) -- BOOLEAN CHECK
	return Player.Upgrades.Prisms_RuneLuck2.Value >= 1 and Player.Stats.AscensionOne.Value and EN.meeq(Player.Stats.Spheres.Value, 1e202)
end

return Module