local Framework = require(game.ReplicatedStorage.Framework)
local Rune_Reward = Framework:GetEvent("Rune_Reward")

local Chances = {
	{ "Malevolence", 1/100000};
	{ "Vehemence", 1/25000};
	{ "Violence", 1/7500};
	{ "Rage", 0.005};
	{ "Mad", 0.995};

}

local MadnessRune = {}

function MadnessRune.Roll(Player : Player)
	local RNG = Random.new()
	local Luck = RNG:NextNumber(1/2e5, 1)

	for _ , Info in Chances do
		if Luck <= Info[2] then
			Player.Runes[Info[1]].Value += 1
			Rune_Reward:FireClient(Player, {[Info[1]] = 1})
			return
		end
	end

	MadnessRune.Roll(Player)
end

return MadnessRune
