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
	Currency = "RobuxTokens";
	Base_Price = "350";
	Price_Scale = 1.5;
	Price_Jump = {10, 1}; -- {Every x, Scale}
	Price_Jump2 = {24, 1}; -- {Every x, Scale}
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level

	--// Effect | IGNORE THIS SECTION FOR TALENT TREE \\--
	Base_Effect = 1;
	Effect_Scale = 0;
	Reverse = false; -- Subtracts from base instead of adds
	Effect_Bonus = 2; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
	Bonus_Needed = 15; -- How many levels per milestone reached
	Exponential = 1.5;


} 

Module.CustomEffect = function(Player : Player)
end

Module.Update = function(Player : Player) : string -- VISUAL ONLY!!
	local Level = Player.Upgrades[script.Name].Value
	local Effect = Module.Exponential ^ Level

	return `x{EN.Format(Effect)} Hail`
end

Module.ChromaRequirement = function(Player : Player) 
	return Player.Upgrades.Chromium_Chrome5.Value >= 1
end

Module.HasRequirement = function(Player : Player) -- BOOLEAN CHECK
	--return Player.Stats.Tier.Value >= 5
	return Player.Stats.Chromatize.Value >= 1000 and Player.Runes.Vanguard.Value >= 1e18 and Module.ChromaRequirement(Player)
end

return Module