local Framework = require(game.ReplicatedStorage.Framework)
local Rune_Reward = Framework:GetEvent("Rune_Reward")

local Chances = {
	{ "Eternal", 1/1.75e4};
	{ "Primordial", 0.0002};
	{ "Boundless", 0.001};
	{ "Almighty", 0.0088};
	{ "Omnipotent", 0.09};
	{ "Omniscient", 0.9};

}

local UltraRune = {}

function UltraRune.Roll(Player : Player)
	local RNG = Random.new()
	local Luck = RNG:NextNumber(1/1e5, 1)

	for _ , Info in Chances do
		if Luck <= Info[2] then
			Player.Runes[Info[1]].Value += 1
			Rune_Reward:FireClient(Player, {[Info[1]] = 1})
			return
		end
	end

	UltraRune.Roll(Player)
end

return UltraRune
