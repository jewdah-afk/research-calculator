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
	Base_Price = 2,5e313;
	Price_Scale = 1.5;
	Price_Jump = {10, 1}; -- {Every x, Scale}
	Price_Jump2 = {24, 1}; -- {Every x, Scale}
	Additive_Scale = true; -- Instead of exponentially scaling, it just does Base * x * Level

	Stay_Visible = true;
}

Module.CustomEffect = function(Player : Player)
	Resets.Freeze(Player)

end

Module.Update = function(Player : Player) -- VISUAL ONLY!!
	return 
end

Module.HasRequirement = function(Player : Player) -- BOOLEAN CHECK
	return Player.Upgrades.Freeze8.Value >= 1 and Player.Stats.Tier.Value >= 13
end

return Module