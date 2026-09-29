local Framework = require(game.ReplicatedStorage.Framework)
--// Services \\--
local Run_Service = Framework:GetService("RunService")
--// Classes \\--
local EN = Framework:GetLibrary("EternityNum")
local SystemMessages = Framework:GetSharedModule("SystemMessages")
local Formulas = Framework:GetSharedModule("Formulas")
local Tier = Framework:GetClientModule("Tier")
local Chromatize = Framework:GetClientModule("Chromatize")
local Chromify = Framework:GetClientModule("Chromify")
local Flame = Framework:GetClientModule("Flame")
local RP = Framework:GetClientModule("Realm Points")
local Power = Framework:GetClientModule("Power")
local Reflection = Framework:GetClientModule("Reflection")
local Gears = Framework:GetClientModule("Gears")
local AP = Framework:GetClientModule("Arctic Points")

local Mobs = Framework:GetClientModule("Mobs")
Mobs.init()
local Runes = Framework:GetClientModule("Runes")
local TalentTree = Framework:GetClientModule("Talent Tree")
local Orbs = Framework:GetClientModule("Orbs")
local Cubes = Framework:GetClientModule("Cubes")
local Accelerator = Framework:GetClientModule("Accelerator")
local Spheres = Framework:GetClientModule("Spheres")
local Challenges = Framework:GetClientModule("Challenges")
local Tickets = Framework:GetClientModule("Tickets")
local DropletsBoard = Framework:GetClientModule("DropletsBoard")
local Icicles = Framework:GetClientModule("Icicles")
local PlaytimeRewards = Framework:GetClientModule("PlaytimeRewards")
local RuneStarring = Framework:GetClientModule("RuneStarring")
--local GlobalGoals = Framework:GetClientModule("GlobalGoals")
local Freeze = Framework:GetClientModule("Freeze")

local MultiplierButtons = Framework:GetClientModule("MultiplierButtons")
local IceButtons = Framework:GetClientModule("IceButtons")
local Haze = Framework:GetClientModule("Haze")
local Hail = Framework:GetClientModule("Hail")
local Loot = Framework:GetClientModule("Loot")
local Chroma = Framework:GetClientModule("Chroma")
local Shine = Framework:GetClientModule("Shine")
local Ascended = Framework:GetClientModule("Ascended")
local Light = Framework:GetClientModule("Light")

--// Variables \\--
local Client_Player = Framework:GetPlayer()
local Gui = Framework.Gui
local PlayerGui = Client_Player.PlayerGui
local Starting_WS = game.StarterPlayer.CharacterWalkSpeed
local FavoritesBoard = workspace.Rewards

local Main = {}
--// Mob Zone \\--
local Mob_Raycast = RaycastParams.new()
Mob_Raycast.FilterType = Enum.RaycastFilterType.Include
Mob_Raycast.FilterDescendantsInstances = {workspace.Areas["Spawn Island"].Map.Bases.Mob_Zone}

--// Ascension One Zone \\--
local Ascension1 = workspace.Areas["Spawn Island"].Map.Ascension1
local Ascension1_Raycast = RaycastParams.new()
Ascension1_Raycast.FilterType = Enum.RaycastFilterType.Include
Ascension1_Raycast.FilterDescendantsInstances = {Ascension1}

local Teleporter = game:GetService("ReplicatedStorage"):FindFirstChild("Teleporter") or workspace:FindFirstChild("Teleporter")

local Favorite_Count = game.ReplicatedStorage.Favorites
local Like_Count = game.ReplicatedStorage.Likes

local RPS_Timer = 0

local Automations = {
	["Walkspeed"] = {
		Enabled = true; -- true / false to toggle Loop
		Cooldown = 1/8;
		Timer = 0;
		Perform = function()
			if not Client_Player.Character or not Client_Player.Character.Humanoid then return end
			
			if Client_Player.Settings.SetWalkSpeed.Value >= 10 and Client_Player.Settings.SetWalkSpeed.Value < Formulas.Walkspeed(Client_Player) then
				Client_Player.Character.Humanoid.WalkSpeed = Client_Player.Settings.SetWalkSpeed.Value
				return
			end
			
			Client_Player.Character.Humanoid.WalkSpeed = Formulas.Walkspeed(Client_Player)
		end,
	};
	
	["Favorites"] = {
		Enabled = true; -- true / false to toggle Loop
		Cooldown = 1;
		Timer = 0;
		Perform = function()
			FavoritesBoard.SurfaceGui.Main.FavsCount.Text = `[{EN.Format(Favorite_Count.Value)}]`
			FavoritesBoard.SurfaceGui.Main.RuneLuck.Text = `x{EN.Format(Formulas.Favorites_RuneLuck(Favorite_Count.Value))} RUNE LUCK`

			local Scale = 35
			if Client_Player.Stats.LikeReward.Value > 5 then
				Scale = 75
			end

			if Client_Player.Stats.LikeReward.Value > 10 then
				Scale = 250
			end

			FavoritesBoard.SurfaceGui.Main.Pot.Text = `+1 ELIXIR EVERY {Scale}`
			FavoritesBoard.SurfaceGui.Main.LikesCount.Text = `[{math.floor(Like_Count.Value)} / {math.floor(35 + (Scale * Client_Player.Stats.LikeReward.Value))}]`
		end,
	};
	
	["Realm_One"] = {
		Enabled = true; -- true / false to toggle Loop
		Cooldown = 1/6;
		Timer = 0;
		Perform = function()
			PlaytimeRewards.Toggle(Client_Player.Stats.Tier.Value >= 11)
			PlaytimeRewards.Update(Client_Player)
			Tier.Update(Client_Player)
			Chromatize.Toggle(Client_Player.Upgrades.Prisms_Chromatizer.Value >= 1)
			Chromatize.Update(Client_Player)
			Chromify.Toggle(Client_Player.Upgrades.Chromium_Chromifier.Value >= 1)
			Chromify.Update(Client_Player)
			Flame.Toggle(Client_Player.Stats.Tier.Value >= 1)
			Flame.Update(Client_Player.Stats.Flame.Value)
			RP.Toggle(Client_Player.Stats.Tier.Value >= 1)
			RP.Update(Client_Player.Stats["Realm Points"].Value)
			Power.Toggle(Client_Player.Stats.Tier.Value >= 2)
			Power.Update(Client_Player.Stats.Power.Value)
			Reflection.Toggle(Client_Player.Stats.Chromify.Value >= 3)
			Reflection.Update(Client_Player.Stats.Reflection.Value)
			AP.Toggle(Client_Player.Upgrades.Prisms_AP1.Value >= 1)
			AP.Update(Client_Player.Stats["ArcticPoints"].Value)
			Gears.Toggle(Client_Player.Stats.Tier.Value >= 3)
			Gears.Update(Client_Player.Stats.Gears.Value)
			Tickets.Toggle(Client_Player.Stats.Tier.Value >= 0)
			Tickets.Update()
			Mobs.Toggle(Client_Player.Stats.Tier.Value >= 4)
			Mobs.Update(Client_Player.Stats.Flesh.Value)
			TalentTree.Toggle(Client_Player.Stats.Tier.Value >= 5)
			TalentTree.Update()
			Orbs.Toggle(Client_Player.Stats.Tier.Value >= 7)
			Orbs.Update()
			Cubes.Toggle(Client_Player.Stats.Tier.Value >= 8)
			Cubes.Update()
			Accelerator.Toggle(Client_Player.Stats.Tier.Value >= 9)
			Accelerator.Update(Client_Player.Stats.Accelerator.Value)
			Spheres.Toggle(Client_Player.Stats.Tier.Value >= 9)
			Spheres.Update()
			Challenges.Toggle(Client_Player.Stats.Tier.Value >= 10 or Client_Player.Stats.Highest_Tier.Value >= 10)
			Challenges.Update()
			DropletsBoard.Update()
			Icicles.Toggle(Client_Player.Stats.Tier.Value >= 13)
			Icicles.Update()
			Haze.Toggle(Client_Player.Stats.Tier.Value >= 13)
			Haze.Update()	
			
			Hail.Toggle(Client_Player.Stats.Tier.Value >= 10)
			Hail.Update()	
			

			Shine.Toggle(Client_Player.Upgrades.Chromium_NewStat.Value >= 1)
			Shine.Update()	
			
			Light.Toggle(Client_Player.Stats.Chromify.Value >= 1)
			Light.Update()	
			
			Loot.Toggle(Client_Player.Stats.Tier.Value >= 4)
			Loot.Update()	
			
			Chroma.Toggle(Client_Player.Stats.Chromatize.Value >= 1000 and Client_Player.Runes.Vanguard.Value >= 1e19 and Client_Player.Stats.Chromify.Value < 2)
			Chroma.Update()	
			
			Ascended.Toggle(Client_Player.Stats.Chromify.Value >= 2)
			Ascended.Update()	
			--GlobalGoals.Toggle(Client_Player.Stats.Tier.Value >= 12)
			RuneStarring.Toggle(Client_Player.Upgrades.Chromium_RuneStarring.Value >= 1)
			Freeze.Toggle(Client_Player.Stats.Tier.Value >= 11)
			IceButtons.Toggle(Client_Player.Upgrades.Freeze2.Value >= 1)
		end,
	};
	
	["RPS"] = {
		Enabled = true; -- true / false to toggle Loop
		Cooldown = 1/6;
		Timer = 0;
		Perform = function()
			Runes.UpdateRPS()
			Runes.Toggle()
			Runes.UpdateChances()
		end,
	};
	
	--[[
	["Messages"] = {
		Enabled = true; -- true / false to toggle Loop
		Cooldown = 1;
		Timer = 0;
		Perform = function()
			if #SystemMessages <= 0 then return end
			Framework:SendClientMessage(SystemMessages[math.random(1 , #SystemMessages)])
		end,
	};]]
	
	["Mob_Zone"] = {
		Enabled = true; -- true / false to toggle Loop
		Cooldown = 1/30;
		Timer = 0;
		Perform = function()
			if not Client_Player.Character or not Client_Player.Character.Humanoid then return end
			if Client_Player.Stats.Tier.Value < 4 then return end
			local Result = workspace:Raycast(Client_Player.Character.HumanoidRootPart.Position, Vector3.new(0,-8,0), Mob_Raycast)
			if Result then
				Mobs.Highlight_Zone()
				return
			end
			Mobs.Unhighlight_Zone()
		end,
	};
	
	["Ascension One"] = {
		Enabled = true; -- true / false to toggle Loop
		Cooldown = 1e3;
		Timer = 0;
		Perform = function()
			if (Client_Player.Stats.Tier.Value < 10 and not Client_Player.Stats.AscensionOne.Value) then
				Ascension1.Parent = game.ReplicatedStorage.Layers_Storage
				Teleporter.Parent = game.ReplicatedStorage
				return
			else
				Ascension1.Parent = workspace.Areas["Spawn Island"].Map
				if Teleporter then 
					Teleporter.Parent = workspace.Areas["Spawn Island"].Map
				end		
			end
		end,
	};
}

function Main.init()
	task.spawn(function()
		Run_Service.RenderStepped:Connect(function(delta)
			for Name , Info in Automations do
				if not Info.Enabled then continue end
				Automations[Name].Timer += delta
				if Automations[Name].Timer >= Automations[Name].Cooldown then
					Automations[Name].Timer = 0
					Automations[Name].Perform()
				end
			end
		end)
	end)
end

--local Trigger = workspace.Teleporter.Teleporter.Trigger
--local ArcticTeleport = workspace.Areas.Arctic.Teleporter.Teleporter.Trigger

--Trigger.Touched:Connect(function(hit)
--	if hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
--		if Client_Player.Stats.Tier.Value >= 10 and Client_Player.Stats.AscensionOne.Value == false then return end
--		PlayerGui.Teleporter.Enabled = true
--	end
--end)

--Trigger.TouchEnded:Connect(function(hit)
--	if hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
--		PlayerGui.Teleporter.Enabled = false
--	end
--end)

--ArcticTeleport.Touched:Connect(function(hit)
--	if hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
--		if Client_Player.Stats.Tier.Value >= 10 and Client_Player.Stats.AscensionOne.Value == false then return end
--		PlayerGui.Teleporter.Enabled = true
--	end
--end)

--ArcticTeleport.TouchEnded:Connect(function(hit)
--	if hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
--		PlayerGui.Teleporter.Enabled = false
--	end
--end)

return Main
