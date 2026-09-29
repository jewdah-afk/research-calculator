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
	Levels = 100;
	--// Price \\--
	Currency = "Chroma";
	Base_Price = "7.5e15";
	Price_Scale = 1.015; -- {Every x, Scale}
	Additive_Scale = false; -- Instead of exponentially scaling, it just does Base * x * Level

	--// Effect | IGNORE THIS SECTION FOR TALENT TREE \\--
	Base_Effect = 1;
	Effect_Scale = 0;
	Reverse = false; -- Subtracts from base instead of adds -- How many levels per milestone reached
	Exponential = 1.025;


} 

Module.CustomEffect = function(Player : Player)

end

Module.Update = function(Player : Player) : string -- VISUAL ONLY!!
	local Level = Player.Upgrades[script.Name].Value
	local Effect = Module.Exponential ^ Level

	return `x{EN.Format(Effect)} Chroma`
end

Module.ChromaRequirement = function(Player : Player) 
	return Player.Upgrades.Chromium_Chrome10.Value >= 1
end

Module.HasRequirement = function(Player : Player) -- BOOLEAN CHECK
	--return Player.Stats.Tier.Value >= 5
	return Player.Stats.Chromatize.Value >= 1000 and Player.Runes.Vanguard.Value >= 1e18 and Module.ChromaRequirement(Player)
end

return Module