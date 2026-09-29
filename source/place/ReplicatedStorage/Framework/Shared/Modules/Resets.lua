local Framework = require(game.ReplicatedStorage.Framework)
local Upgrades = game.ReplicatedStorage.Framework.Libraries.Upgrades
local Mob_Info = Framework:GetSharedModule("Mob_Info")
local Merger = Framework:GetLibrary("Merger")
local RuneInfo = Framework:GetSharedModule("RuneInfo")

local Resets = {}

function Resets.Tier(Player : Player)
	Player:SetAttribute("Tiering", true)
	
	--[ SPHERES ]--
	Player.Stats.Spheres.Value = "0"
	Player.Stats.Sphere_Levels.Value = 0
	for _ , Upgrade in Upgrades.Spheres:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end
	
	--[ MERGER ]--
	local Player_Merger = Merger(Player)
	Player_Merger:Reset()
	Player.Stats.Cube_Level.Value = 1
	Player.Upgrades.Orbs_SpawnLevel.Value = 0
	Player.Upgrades.Orbs_SpawnTime.Value = 0
	
	--[ ACCELERATOR ]--
	Player.Stats.Accelerator.Value = 0
	
	if Player.Stats.Tier.Value > 10 then
		Player.Stats.Droplets.Value = 0
		Player.Stats.Water.Value = 0
		Player.Stats.Ice.Value = 0
		Player.Stats.Chromium.Value = 0
		Player.Stats.Icicles.Value = 0
		Player.Upgrades.Freeze1.Value = false
		Player.Upgrades.Freeze2.Value = false
		Player.Upgrades.Freeze3.Value = false
		Player.Upgrades.Freeze4.Value = false
		Player.Upgrades.Freeze5.Value = false
		Player.Upgrades.Freeze6.Value = false
		Player.Upgrades.Freeze7.Value = false
		Player.Upgrades.Freeze8.Value = false
		Player.Upgrades.Freeze9.Value = false
		
		Player.Upgrades.Droplets_Droplets1.Value = 0
		Player.Upgrades.Droplets_Water1.Value = 0
		Player.Upgrades.Droplets_Spheres1.Value = 0
		Player.Upgrades.Droplets_Chromium1.Value = 0
		Player.Upgrades.Droplets_AP1.Value = 0
	end
	
	
	--[ ORBS ]--
	Player.Stats.Orbs.Value = "0"
	Player.Upgrades.Orbs_Energy.Value = 0
	Player.Upgrades.Orbs_Flame.Value = 0
	Player.Upgrades.Orbs_Orbs.Value = 0
	
	
	--[ PRISMS ]--


	--[ GEARS ]--
	Player.Stats.Gears.Value = 0


	--[ MOBS + FLESH ]--
	local Player_Mob_Info = Mob_Info[Player.UserId]
	Player.Stats.Mobs_Level.Value = 1
	Player.Stats.Mobs_SetLevel.Value = 1
	Player.Stats.Flesh.Value = "0"
	Player.Stats.Mobs_Killed.Value = 0
	Player_Mob_Info:Respawn()
	
	for _ , Upgrade in Upgrades.Flesh:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end	
	
	--[ POWER ]--
	Player.Stats.Power.Value = "0"
	for _ , Upgrade in Upgrades.Power:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end
	
	--[ FLAME ]--
	Player.Stats.Flame.Value = "0"
	
	--[ ENERGY ]--
	Player.Stats.Energy.Value = "0"
	
	Player:SetAttribute("Tiering", false)
end

function Resets.C1(Player : Player)
	Resets.Tier(Player)
	
	Player:SetAttribute("Challenging", true)
	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value

	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5
	
	--[ REALM POINTS ]--
	Player.Stats["Realm Points"].Value = "0"
	for _ , Upgrade in Upgrades["Realm Points"]:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end
	
	Player.Stats.Prisms.Value = "0"
	Player.Stats.Tier.Value = 0
	Player:SetAttribute("Challenging", false)
end

function Resets.C2(Player : Player)
	Resets.Tier(Player)
	
	Player:SetAttribute("Challenging", true)
	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value

	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5

	--[ REALM POINTS ]--
	Player.Stats["Realm Points"].Value = "0"
	for _ , Upgrade in Upgrades["Realm Points"]:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end
	
	Player.Stats.Prisms.Value = "0"
	Player.Stats.Tier.Value = 0
	Player:SetAttribute("Challenging", false)
end

function Resets.C3(Player : Player)
	Resets.Tier(Player)
	
	Player:SetAttribute("Challenging", true)
	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value

	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5

	--[ REALM POINTS ]--
	Player.Stats["Realm Points"].Value = "0"
	for _ , Upgrade in Upgrades["Realm Points"]:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Stats.Prisms.Value = "0"
	Player.Stats.Tier.Value = 0
	Player:SetAttribute("Challenging", false)
end

function Resets.C4(Player : Player)
	Resets.Tier(Player)
	
	Player:SetAttribute("Challenging", true)
	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value

	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5

	--[ REALM POINTS ]--
	Player.Stats["Realm Points"].Value = "0"
	for _ , Upgrade in Upgrades["Realm Points"]:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Stats.Prisms.Value = "0"
	Player.Stats.Tier.Value = 0
	Player:SetAttribute("Challenging", false)
end

function Resets.AscensionOne(Player : Player)
	Player:SetAttribute("Ascending", true)
	Resets.Tier(Player)

	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value

	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5

	--[ REALM POINTS ]--
	Player.Stats["Realm Points"].Value = "0"
	for _ , Upgrade in Upgrades["Realm Points"]:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end
	
	--[ Runes ]--
	for Rune , Chance in RuneInfo do
		if Chance >= 1/1e8 then
			Player.Runes[Rune].Value = 0
		end
	end
	
	Player.Stats.Prisms.Value = "0"
	Player.Stats.Tier.Value = 0
	Player.Stats.XP.Value = "0"
	Player.Stats.Level.Value = 0
	Player.Stats.Highest_Tier.Value = 0
	
	Player.Stats.C1.Value = false
	Player.Stats.C2.Value = false
	Player.Stats.C3.Value = false
	Player.Stats.C4.Value = false
	
	Player:SetAttribute("Ascending", false)
end

function Resets.Freeze(Player : Player)
	
	--[ SPHERES ]--
	Player.Stats.Spheres.Value = "0"
	Player.Stats.Sphere_Levels.Value = 0
	for _ , Upgrade in Upgrades.Spheres:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	--[ MERGER ]--
	local Player_Merger = Merger(Player)
	Player_Merger:Reset()
	Player.Stats.Cube_Level.Value = 1
	Player.Upgrades.Orbs_SpawnLevel.Value = 0
	Player.Upgrades.Orbs_SpawnTime.Value = 0

	--[ ACCELERATOR ]--
	Player.Stats.Accelerator.Value = 0


	--[ ORBS ]--
	Player.Stats.Orbs.Value = "0"
	Player.Upgrades.Orbs_Energy.Value = 0
	Player.Upgrades.Orbs_Flame.Value = 0
	Player.Upgrades.Orbs_Orbs.Value = 0


	--[ PRISMS ]--
	Player.Stats.Prisms.Value = 0

	--[ GEARS ]--
	Player.Stats.Gears.Value = 0


	--[ MOBS + FLESH ]--
	local Player_Mob_Info = Mob_Info[Player.UserId]
	Player.Stats.Mobs_Level.Value = 1
	Player.Stats.Mobs_SetLevel.Value = 1
	Player.Stats.Flesh.Value = "0"
	Player.Stats.Mobs_Killed.Value = 0
	
	task.spawn(function()
		Player_Mob_Info:Respawn()
	end)
	
	for _ , Upgrade in Upgrades.Flesh:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end	

	--[ POWER ]--
	Player.Stats.Power.Value = "0"
	for _ , Upgrade in Upgrades.Power:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	--[ FLAME ]--
	Player.Stats.Flame.Value = "0"

	--[ ENERGY ]--
	Player.Stats.Energy.Value = "0"
		
	Player.Stats.Droplets.Value = "0"
	Player.Stats.Ice.Value = "0"
	Player.Stats.Water.Value = "0"
	
	-- droplets reset
	for i, Upgrade in Upgrades.Droplets:GetChildren() do 
		Player.Upgrades[Upgrade.Name].Value = 0
	end
	
	-- talents resets
	
	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value

	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5

	Player.Stats.Chromium.Value = "0"
	
end

function Resets.Chromatize(Player : Player)
	local Talents_Folder = workspace.Layers.TalentTree.Talents
	local Talents_Folder2 = workspace.Areas.Arctic["Upgrade Tree Island 2"]

	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	

	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value

	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5

	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = 1
	Player.Stats.Prisms.Value = "0"
	Player.Stats.Chromium.Value = "0"
	Player.Stats.Chroma.Value = "0"
end

function Resets.Chromify(Player : Player)
	local Talents_Folder = workspace.Layers.TalentTree.Talents
	local Talents_Folder2 = workspace.Areas.Arctic["Upgrade Tree Island 2"]
	
	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 


	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value
	local Chromium_RPS9 = Player.Upgrades.Chromium_RPS9.Value
	local Chromium_Shine1 = Player.Upgrades.Chromium_Shine1.Value
	local Chromium_Shine2 = Player.Upgrades.Chromium_Shine2.Value

	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5
	Player.Upgrades.Chromium_RPS9.Value = Chromium_RPS9
	Player.Upgrades.Chromium_Shine1.Value = Chromium_Shine1
	Player.Upgrades.Chromium_Shine2.Value = Chromium_Shine2

	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = 1
	Player.Stats.Prisms.Value = "0"
	Player.Stats.Chromium.Value = "0"
	Player.Stats.Chroma.Value = "0"
	Player.Stats.Light.Value = "0"
	Player.Stats.Reflection.Value = "0"
	Player.Stats.Shine.Value = "0"
	Player.Upgrades.Light_Light.Value = 0
	Player.Upgrades.Light_Chrome1.Value = 0
	Player.Upgrades.Light_Chrome2.Value = 0
	Player.Upgrades.Reflection_Chrome1.Value = 0
	Player.Upgrades.Reflection_Light1.Value = 0
	Player.Upgrades.Reflection_RPS1.Value = 0
end

function Resets.Reflection(Player : Player)
	local Talents_Folder2 = workspace.Areas.Arctic["Upgrade Tree Island 2"]

	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 


	local runeStarringLevel = Player.Upgrades.Chromium_RuneStarring.Value 
	local Prisms_Chromatizer = Player.Upgrades.Prisms_Chromatizer.Value
	local Prisms_RuneBulk2 = Player.Upgrades.Prisms_RuneBulk2.Value
	local Prisms_RuneClone = Player.Upgrades.Prisms_RuneClone.Value
	local Prisms_RuneBulk3 = Player.Upgrades.Prisms_RuneBulk3.Value
	local Prisms_RuneSpeed2 = Player.Upgrades.Prisms_RuneSpeed2.Value
	local Chromium_UltraRunes = Player.Upgrades.Chromium_UltraRunes.Value
	local Prisms_RuneBulk4 = Player.Upgrades.Prisms_RuneBulk4.Value
	local Prisms_RTokens = Player.Upgrades.Prisms_RTokens.Value
	local Prisms_RuneSpeed3 = Player.Upgrades.Prisms_RuneSpeed3.Value
	local Prisms_RPS = Player.Upgrades.Prisms_RPS.Value
	local Prisms_RPS2 = Player.Upgrades.Prisms_RPS2.Value
	local Prisms_Tickets2 = Player.Upgrades.Prisms_Tickets2.Value
	local Chromium_Chromifier = Player.Upgrades.Chromium_Chromifier.Value
	local Chromium_Hail1 = Player.Upgrades.Chromium_Hail1.Value
	local Chromium_RPS5 = Player.Upgrades.Chromium_RPS5.Value
	local Chromium_RPS9 = Player.Upgrades.Chromium_RPS9.Value
	local Chromium_Shine1 = Player.Upgrades.Chromium_Shine1.Value
	local Chromium_Shine2 = Player.Upgrades.Chromium_Shine2.Value


	for _ , Upgrade in Upgrades.Talent:GetChildren() do
		Player.Upgrades[Upgrade.Name].Value = 0
	end

	Player.Upgrades.Prisms_RuneBulk2.Value = Prisms_RuneBulk2
	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = Prisms_Chromatizer
	Player.Upgrades.Prisms_RuneClone.Value = Prisms_RuneClone
	Player.Upgrades.Prisms_RuneBulk3.Value = Prisms_RuneBulk3
	Player.Upgrades.Prisms_RuneSpeed2.Value = Prisms_RuneSpeed2
	Player.Upgrades.Chromium_UltraRunes.Value = Chromium_UltraRunes
	Player.Upgrades.Prisms_RuneBulk4.Value = Prisms_RuneBulk4
	Player.Upgrades.Prisms_RTokens.Value = Prisms_RTokens
	Player.Upgrades.Prisms_RuneSpeed3.Value = Prisms_RuneSpeed3
	Player.Upgrades.Prisms_RPS.Value = Prisms_RPS
	Player.Upgrades.Prisms_RPS2.Value = Prisms_RPS2
	Player.Upgrades.Prisms_Tickets2.Value = Prisms_Tickets2
	Player.Upgrades.Chromium_Chromifier.Value = Chromium_Chromifier
	Player.Upgrades.Chromium_Hail1.Value = Chromium_Hail1
	Player.Upgrades.Chromium_RPS5.Value = Chromium_RPS5
	Player.Upgrades.Chromium_RPS9.Value = Chromium_RPS9
	Player.Upgrades.Chromium_Shine1.Value = Chromium_Shine1
	Player.Upgrades.Chromium_Shine2.Value = Chromium_Shine2

	Player.Upgrades.Chromium_RuneStarring.Value = runeStarringLevel
	Player.Upgrades.Prisms_Chromatizer.Value = 1
	Player.Stats.Chromium.Value = "0"
	Player.Stats.Chroma.Value = "0"
	Player.Stats.Light.Value = "0"
	Player.Upgrades.Light_Light.Value = 0
	Player.Upgrades.Light_Chrome1.Value = 0
	Player.Upgrades.Light_Chrome2.Value = 0
end

function Resets.Icicles(Player : Player)
	
end

return Resets
