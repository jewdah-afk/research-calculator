local Framework = require(game.ReplicatedStorage.Framework)
--[ Libraries ]--
local EN = Framework:GetLibrary("EternityNum")
local Upgrades = Framework:GetLibrary("Upgrades")
--[ Modules ]--
local Formulas = Framework:GetSharedModule("Formulas")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")

local Cooldowns = {}

function Cooldowns.Energy(Player : Player)
	local Timer = .25
	Timer -= Formulas.Gears_Speed(Player.Stats.Gears.Value)
	
	if Player.Gamepasses.MoreAttackSpeed.Value then
		Timer -= 0.04
	end
	
	return math.clamp(Timer, 0, 1)
end

function Cooldowns.XP(Player : Player)
	local Timer = .25
	Timer -= Formulas.Gears_Speed(Player.Stats.Gears.Value)
	
	if Player.Gamepasses.MoreAttackSpeed.Value then
		Timer -= 0.04
	end
	
	return math.clamp(Timer, 0, 1)
end

function Cooldowns.Flame(Player : Player)
	local Timer = .25
	return math.clamp(Timer, 0.05, 1)
end

function Cooldowns.Power(Player : Player)
	local Timer = .25
	return math.clamp(Timer, 0.05, 1)
end

function Cooldowns.Reflection(Player : Player)
	local Timer = .25
	return math.clamp(Timer, 0.05, 1)
end

function Cooldowns.RealmPoints(Player : Player)
	local Timer = 1
	
	if EN.meeq(Player.Stats.Spheres.Value, 2.5e14) then
		Timer /= 3
	end
	
	return math.clamp(Timer, 0.05, 1)
end

function Cooldowns.Ascender_XP(Player : Player)
	local Timer = .25
	Timer -= Formulas.Gears_Speed(Player.Stats.Gears.Value)
	return math.clamp(Timer, 0.05, 1)
end

function Cooldowns.Tier(Player : Player)
	local Timer = 1
	return math.clamp(Timer, 0.25, 1)
end

function Cooldowns.Chromatizer(Player : Player)
	local Timer = 1
	return math.clamp(Timer, 0.25, 1)
end

function Cooldowns.Chromifier(Player : Player)
	local Timer = 1
	return math.clamp(Timer, 0.25, 1)
end

function Cooldowns.Mobs(Player : Player)
	local Timer = 3
	
	if Player.Gamepasses.MoreAttackSpeed.Value then
		Timer /= 1.5
	end
	
	return math.clamp(Timer, 0.25, 3)
end

function Cooldowns.IceButton(Player : Player)
	local Timer = 0.5 
	return math.clamp(Timer, 0.05, 1)
end

function Cooldowns.WaterButton(Player : Player)
	local Timer = 0.5 
	return math.clamp(Timer, 0.05, 1)
end

function Cooldowns.Runes(Player : Player)
	local Timer = Formulas.Rune_Speed(Player)
	return math.clamp(Timer, 1/60, 1)
end

function Cooldowns.Prisms(Player : Player)
	local Timer = 15
	
	local Reduction = Upgrades("Prisms_Prisms3"):GetEffect(Player.Upgrades.Prisms_Prisms3.Value, Player)
	Timer += Reduction
	Timer /= Formulas.Accelerator_PrismSpeed(Player.Stats.Accelerator.Value)
	
	if Player:GetAttribute("Prisms_X2") then
		Timer /= 2
	end
	
	return math.clamp(Timer, 1/60, 15)
end

function Cooldowns.Orbs(Player : Player)
	local Timer = 1
	
	return math.clamp(Timer, 1/60, 1)
end

function Cooldowns.Cubes(Player : Player)
	local Timer = 20
	
	local Reduction = Upgrades("Orbs_SpawnTime"):GetEffect(Player.Upgrades.Orbs_SpawnTime.Value)
	Timer -= Reduction
	Timer /= Formulas.Accelerator_CubeSpeed(Player.Stats.Accelerator.Value)
	
	if Player.Stats.Cube_Level.Value >= 20 then
		Timer /= 2
	end
	
	return math.clamp(Timer, 2, 20)
end

function Cooldowns.Spheres(Player : Player)
	local Timer = .25
	Timer -= Formulas.Gears_Speed(Player.Stats.Gears.Value)
	
	if Player.Gamepasses.MoreAttackSpeed.Value then
		Timer -= 0.04
	end
	
	return math.clamp(Timer, 0, 1)
end

function Cooldowns.Droplets(Player : Player)
	local Timer = .5
	
	Timer -= RuneFormulas.Icequake_DropletsCD(Player.Runes.Icequake.Value)

	return math.clamp(Timer, 0, 1)
end

function Cooldowns.ArcticPoints(Player : Player)
	local Timer = 1
	
	local Reduction = Upgrades("Chromium_AP2"):GetEffect(Player.Upgrades.Chromium_AP2.Value)
	Timer += Reduction
	
	return math.clamp(Timer, 0.05, 2)
end

function Cooldowns.Ice(Player : Player)
	local Timer = .25
	Timer -= Formulas.Gears_Speed(Player.Stats.Gears.Value)

	if Player.Gamepasses.MoreAttackSpeed.Value then
		Timer -= 0.04
	end

	return math.clamp(Timer, 0, 1)
end

function Cooldowns.Icicles(Player : Player)
	local Timer = 5
	Timer -= Formulas.Gears_Speed(Player.Stats.Gears.Value)

	if Player.Gamepasses.MoreAttackSpeed.Value then
		Timer -= 0.04
	end

	return math.clamp(Timer, 0, 5)
end

function Cooldowns.Water(Player : Player)
	local Timer = .25
	Timer -= Formulas.Gears_Speed(Player.Stats.Gears.Value)

	if Player.Gamepasses.MoreAttackSpeed.Value then
		Timer -= 0.04
	end

	return math.clamp(Timer, 0, 1)
end

function Cooldowns.WaterAuto(Player : Player)
	local Timer = 3

	local Reduction = Upgrades("Chromium_Automation3"):GetEffect(Player.Upgrades.Chromium_Automation3.Value, Player)
	Timer += Reduction

	return math.clamp(Timer, 0, 1)
end

function Cooldowns.Chromium(Player : Player)
	local Timer = 10
	
	local Reduction = Upgrades("Chromium_Chromium2"):GetEffect(Player.Upgrades.Chromium_Chromium2.Value, Player)
	Timer += Reduction
	
	local Reduction = Upgrades("Chromium_Chromium3"):GetEffect(Player.Upgrades.Chromium_Chromium3.Value, Player)
	Timer += Reduction

	
	return math.clamp(Timer, 0, 10)
end

function Cooldowns.AutoPower(Player : Player)
	local Timer = 1
	Timer -= Upgrades("Prisms_AutoPower3"):GetEffect(Player.Upgrades.Prisms_AutoPower3.Value, Player)
	return math.clamp(Timer, 0.05, 1)
end


function Cooldowns.AutoAttack(Player : Player)
	local Timer = 3
	Timer -= Upgrades("Prisms_AutoAttackSpeed"):GetEffect(Player.Upgrades.Prisms_AutoAttackSpeed.Value, Player)
	return math.clamp(Timer, 0.05, 3)
end

function Cooldowns.RobuxTokens(Player : Player)
	local Timer = 360
	
	if Player:GetAttribute("Premium") then Timer -= 30 end
	if Player.Gamepasses.Prime.Value then Timer -= 60 end
	Timer -= RuneFormulas.Refraction_RobuxTokenCD(Player.Runes.Refraction.Value)
	Timer -= RuneFormulas.Mystery_RobuxTokenCD(Player.Runes.Mystery.Value)
	Timer -= RuneFormulas.Etherborn_RobuxTokenCD(Player.Runes.Etherborn.Value)
	Timer -= RuneFormulas.Malevolence_RobuxTokenCD(Player.Runes.Malevolence.Value)
	Timer -= Upgrades("Prisms_RTokens"):GetEffect(Player.Upgrades.Prisms_RTokens.Value, Player)
	
	return math.clamp(Timer, 30, 360)
end

function Cooldowns.Cryo()
	return math.clamp(1, 0.5, 3)
end

return Cooldowns
