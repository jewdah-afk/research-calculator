local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Resets = Framework:GetSharedModule("Resets")

local Module = {
	--// Display \\--
	Effect_Display = function(Effect_1 : number, Effect_2)
		if Effect_2 then
			return `x{Effect_1} >> x{Effect_2}`
		end

		return `x{Effect_1}`
	end,
	StaticBoard = true;

	--// Levels \\--
	Levels = 1;
	--// Price \\--
	Currency = "Droplets";
	Base_Price = 5e278;
	Price_Scale = 1.5;
	Price_Jump = {10, 1}; -- {Every x, Scale}
	Price_Jump2 = {24, 1}; -- {Every x, Scale}
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level

	Stay_Visible = true;

	--// Effect | IGNORE THIS SECTION FOR TALENT TREE \\--
	Chromium = {		
		Base_Effect = 1;
		Effect_Scale = 5;
		Reverse = false; -- Subtracts from base instead of adds
		Effect_Bonus = nil; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
		Bonus_Needed = nil; -- How many levels per milestone reached
		Exponential = nil;
	},

	Prisms = {		
		Base_Effect = 1;
		Effect_Scale = 3;
		Reverse = false; -- Subtracts from base instead of adds
		Effect_Bonus = nil; -- How much it multiplies every milestone | EX) 2x per 25 levels | Set to <=1 to disable
		Bonus_Needed = nil; -- How many levels per milestone reached
		Exponential = nil;
	}
}

Module.CustomEffect = function(Player : Player)
	Resets.Freeze(Player)

end

Module.Update = function(Player : Player) -- VISUAL ONLY!!
	return 
end

Module.HasRequirement = function(Player : Player) -- BOOLEAN CHECK
	return Player.Upgrades.Freeze7.Value >= 1 and Player.Stats.Tier.Value >= 13
end

return Module