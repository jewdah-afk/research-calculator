local Framework = require(game.ReplicatedStorage.Framework)
local Mob = Framework:GetLibrary("Mob")
local Mob_Info = Framework:GetSharedModule("Mob_Info")
local Mobs = {}

function Mobs.GetKillsNeeded(Player : Player)
	--// Gets Current Stage \\--
	return 15
end

function Mobs.NextLevel(Player : Player)
	local Mobs_Needed = Mobs.GetKillsNeeded(Player)
	
	if Player.Stats.Mobs_SetLevel.Value < Player.Stats.Mobs_Level.Value then
		Player.Stats.Mobs_SetLevel.Value += 1
		Mob_Info[Player.UserId]:Respawn()
		return
	end
	
	if Player.Stats.Mobs_SetLevel.Value >= Player.Stats.Mobs_Level.Value then
		if Player.Stats.Mobs_Killed.Value >= Mobs_Needed then
			Player.Stats.Mobs_Killed.Value = 0
			Player.Stats.Mobs_Level.Value += 1
			Player.Stats.Mobs_SetLevel.Value = Player.Stats.Mobs_Level.Value
			Mob_Info[Player.UserId]:Respawn()
		end
	end
end

function Mobs.PreviousLevel(Player : Player)
	local Set_Level = Player.Stats.Mobs_SetLevel
	local Mob_Level = Player.Stats.Mobs_Level
	local New_Level = Set_Level.Value - 1
	
	if New_Level <= 0 then return end
	

	Set_Level.Value = math.clamp(New_Level, 1, Mob_Level.Value)
	Mob_Info[Player.UserId]:Respawn()
end

return Mobs
