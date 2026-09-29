local Framework = require(game.ReplicatedStorage.Framework)
--// Services \\--
local Debris = Framework:GetService("Debris")
local Teleport_Service = Framework:GetService("TeleportService")
--// Classes \\--
--local Codes = Framework:GetLibrary("Codes")
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Upgrades = Framework:GetLibrary("Upgrades")
local Resets = Framework:GetSharedModule("Resets")
local Messenger = Framework:GetLibrary("Messenger")
--// Events \\--
local Events = Framework.Events
local AFK_Event = Framework:GetEvent("AFK") :: RemoteEvent
local Upgrade_Event = Framework:GetEvent("Buy_Upgrade") :: RemoteEvent
local Buy_Accelerator = Framework:GetEvent("Buy_Accelerator")
local Upgrade_Spheres = Framework:GetEvent("Upgrade_Spheres")
local Enter_Challenge = Framework:GetEvent("Enter_Challenge")
local Toggle_Tag = Framework:GetEvent("Toggle_Tag")
local Use_Elixir = Framework:GetEvent("Use_Elixir")
local RToken = Framework:GetEvent("RTokenToggle")
local Rbx = Framework:GetEvent("RobuxToggle")
local Popup = Framework:GetEvent("Popup")
local Redeem_Code = Framework:GetRemoteFunction("Redeem_Code")
local AscensionOne = Framework:GetEvent("AscensionOne")
local Remotes = {}

function Remotes.init()
	AFK_Event.OnServerEvent:Connect(function(Player : Player)
		if Player:FindFirstChild("Teleporting") then return end

		local afkValue = Instance.new('BoolValue')
		afkValue.Name = "Teleporting"
		afkValue.Parent = Player
		Debris:AddItem(afkValue, 3) -- Allows players to retry in case it fails

		local succ, err = pcall(function()
			Teleport_Service:TeleportAsync(game.PlaceId, {Player})
		end)
		if err then warn(`SERVER | ERROR | ANTI-AFK REMOTE | {err}`) end
	end)
	
	Upgrade_Event.OnServerEvent:Connect(function(Player : Player, Upgrade_Name : string, Max : boolean)
		if not Player:GetAttribute("Loaded") then return end
		local Upgrade = Upgrades(Upgrade_Name)
		local Level = Player.Upgrades[Upgrade_Name]
		Upgrade:Buy(Level, Max, Player)
	end)
	
	AscensionOne.OnServerEvent:Connect(function(Player: Player)
		
	end)
	
	Events.Buy_Gears.OnServerEvent:Connect(function(Player : Player)
		if not Player:GetAttribute("Loaded") then return end
		if Player.Stats.Gears.Value >= 8 then return end -- Already max gears
		
		local Cost = Formulas.Gears_Cost(Player.Stats.Gears.Value)
		if EN.le(Player.Stats.Energy.Value, Cost) then return end -- Not enough energy
		
		Player.Stats.Gears.Value += 1
		Player.Stats.Energy.Value = EN.toString(EN.sub(Player.Stats.Energy.Value, Cost))
	end)
	
	Buy_Accelerator.OnServerEvent:Connect(function(Player : Player)
		if not Player:GetAttribute("Loaded") then return end
		local Cap = Formulas.Accelerator_Levels(Player)
		if Player.Stats.Accelerator.Value >= Cap then return end -- Already max Accel

		local Cost = Formulas.Accelerator_Cost(Player.Stats.Accelerator.Value)
		if EN.le(Player.Stats.Power.Value, Cost) then return end -- Not enough energy

		Player.Stats.Accelerator.Value += 1
		Player.Stats.Power.Value = EN.toString(EN.sub(Player.Stats.Power.Value, Cost))
	end)
	
	Upgrade_Spheres.OnServerEvent:Connect(function(Player : Player)
		if not Player:GetAttribute("Loaded") then return end

		local Cost = Formulas.Spheres_Cost(Player)
		if EN.le(Player.Stats.Spheres.Value, Cost) then Popup:FireClient(Player, "Error", "You do not have enough Spheres to upgrade!") return end -- Not enough energy

		Player.Stats.Sphere_Levels.Value += 1
		Player.Stats.Spheres.Value = EN.toString(EN.sub(Player.Stats.Spheres.Value, Cost))
		Popup:FireClient(Player, "Success", "You have successfully upgraded your Spheres multiplier!")
	end)
	
	Enter_Challenge.OnServerEvent:Connect(function(Player : Player, Challenge : string)
		if not Player:GetAttribute("Loaded") then return end
		if Player:GetAttribute("Tiering") then return end
		
		if Player.Stats[Challenge].Value then Popup:FireClient(Player, "Error", "You have already completed this challenge!") return end
		if Player.Stats.Highest_Tier.Value < 10 then Popup:FireClient(Player, "Error", "You need Highest Tier 10 to enter a challenge!") return end
		
		if Player.Stats.InChallenge.Value then
			Player.Stats.InChallenge.Value = false
			Player.Stats.CurrentChallenge.Value = ""
			Popup:FireClient(Player, "Success", "You have successfully exited the challenge!")
			return
		end
		
		if Player.Stats.Tier.Value < 10 then Popup:FireClient(Player, "Error", "You need Tier 10 to enter a challenge!") return end
		--if Player.Stats.InChallenge.Value then Popup:FireClient(Player, "Error", "You are actively in a challenge!") return end
		
		Player.Stats.InChallenge.Value = true
		Player.Stats.CurrentChallenge.Value = Challenge
		Resets[Challenge](Player)
		Popup:FireClient(Player, "Success", "You have successfully began the challenge!")
	end)
	
	Toggle_Tag.OnServerEvent:Connect(function(Player : Player, Tag : string)
		if not Player:GetAttribute("Loaded") then return end
		Player.OverheadPins[Tag].Value = not Player.OverheadPins[Tag].Value
	end)
	
	Use_Elixir.OnServerEvent:Connect(function(Player : Player, Elixir : string)
		if not Player:GetAttribute("Loaded") then return end
		if Elixir == "GlobalElixir" then return end
		local Elixir_Obj = Player.Stats[Elixir]
		local Duration = Player.Stats[Elixir.."Duration"]
		if Elixir_Obj.Value <= 0 then return end
		
		Elixir_Obj.Value -= 1
		if Elixir == "ServerElixir" then
			Duration.Value += (60 * 60)
		else
			Duration.Value += (60 * 20)
		end
	end)
	
	RToken.OnServerEvent:Connect(function(Player : Player)
		Player:SetAttribute("RTokens", true)
		Popup:FireClient(Player, "Success", "You are now using Robux Tokens for Store Purchases!")
	end)
	
	Rbx.OnServerEvent:Connect(function(Player : Player)
		Player:SetAttribute("RTokens", false)
		Popup:FireClient(Player, "Success", "You are now using Robux for Store Purchases!")
	end)
end

return Remotes
