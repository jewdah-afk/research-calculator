local Framework = require(game.ReplicatedStorage.Framework)
local Rune_Reward = Framework:GetEvent("Rune_Reward")

local Chances = {
	{"Etherborn", 0.0001};
	{"Antimatter", 0.002};
	{"Darkmatter", 0.048};
	{"Lightmatter", 0.95};
}

local GlobalRune = {}

function GlobalRune.Roll(Player : Player)
	local RNG = Random.new()
	local Luck = RNG:NextNumber(1/1e5, 1)
	
	for _ , Info in Chances do
		if Luck <= Info[2] then
			Player.Runes[Info[1]].Value += 1
			Rune_Reward:FireClient(Player, {[Info[1]] = 1})
			return
		end
	end
	
	GlobalRune.Roll(Player)
end

return GlobalRune
