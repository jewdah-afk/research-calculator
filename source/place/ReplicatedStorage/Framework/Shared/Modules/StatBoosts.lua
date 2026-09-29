local Framework = require(game.ReplicatedStorage.getFramework)
local Stat = Framework.Shared.Classes.Stat

local StatBoosts = {}

for _ , Stat_Mod in Stat:GetChildren() do
	Stat_Name = Stat_Mod.Name
	if Stat_Name == "DOCUMENTATION" then continue end
	Stat_Mod = require(Stat_Mod)
	
	local Table = {}
	Table.Upgrades = Stat_Mod.Upgrades or {}
	Table.Fishes = {}
	
	StatBoosts[Stat_Name] = Table
end

print(StatBoosts)
return StatBoosts
