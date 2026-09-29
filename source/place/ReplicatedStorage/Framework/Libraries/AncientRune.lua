local Framework = require(game.ReplicatedStorage.Framework)
local Rune_Reward = Framework:GetEvent("Rune_Reward")

local Chances = {
	{ "Omen", 0.00003};
	{ "Ankh", 0.00025};
	{ "Sigil", 0.00175};
	{ "Glyph", 0.018};
	{ "Bone", 0.15};
	{ "Dust", 0.83};

}

local AncientRune = {}

function AncientRune.Roll(Player : Player)
	local RNG = Random.new()
	local Luck = RNG:NextNumber(1/1e5, 1)

	for _ , Info in Chances do
		if Luck <= Info[2] then
			Player.Runes[Info[1]].Value += 1
			Rune_Reward:FireClient(Player, {[Info[1]] = 1})
			return
		end
	end

	AncientRune.Roll(Player)
end

return AncientRune
