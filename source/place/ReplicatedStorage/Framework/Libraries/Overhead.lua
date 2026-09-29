local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local RunService = Framework:GetService("RunService")

local ChatData = Framework:GetSharedModule("ChatData")

local GROUP_ID = 16143613

local Cache = {}
local Overhead = {}

function Overhead.New(Player : Player)
	local Char = Player.Character or Player.CharacterAdded:Wait()
	
	--[ Overhead Cloning ]--
	local Player_Overhead = script.Overhead:Clone()
	Player_Overhead.Parent = workspace.Overheads
	
	
	--[ Variables ]--
	local Container = Player_Overhead.Overhead
	local Stat_Container = Container.Stats
	local User_Status = Container.User
	local Group_Status = Container.Tag
	local Connections = {}
	
	--[ Assign Overhead Adornee ]--
	Player_Overhead.Adornee = Char.HumanoidRootPart
	
	--[ Group Role ]--
	local Rank = Player:GetRankInGroup(GROUP_ID)
	local Data = ChatData.Group_Roles[tostring(Rank)]
	
	--[ Stats ]--
	local Energy = Player.Stats.Energy
	local Flame = Player.Stats.Flame
	local Power = Player.Stats.Power
	local RealmPoints = Player.Stats["Realm Points"]
	local Flesh = Player.Stats.Flesh
	local Prisms = Player.Stats.Prisms
	local Orbs = Player.Stats.Orbs
	local Spheres = Player.Stats.Spheres
	local Droplets = Player.Stats.Droplets
	local ArcticPoints = Player.Stats.ArcticPoints
	local Ice = Player.Stats.Ice
	local Icicles = Player.Stats.Icicles
	local Water = Player.Stats.Water
	local Chromium = Player.Stats.Chromium
	
	--[ Gamepasses ]--
	local Prime = Container.Prime
	
	--[ Settings ]--
	local Overhead_Setting = Player.Settings.Overhead
	
	--[ General Functions ]--
	local function Update(Stat : string, Amount : number)
		if Stat == "RealmPoints" then
			Stat_Container[Stat].Text = `{EN.Format(Amount, 2, Player)} RP`
			return
		end
		
		Stat_Container[Stat].Text = `{EN.Format(Amount, 2, Player)} {string.upper(Stat)}`
	end
	
	local function ToggleView()
		Player_Overhead.Enabled = Overhead_Setting.Value
	end
	
	local function Cleanup()
		for _ , conn in Connections do
			conn:Disconnect()
		end
		Connections = nil
		Player_Overhead:Destroy()
	end
	--[ Connection Cleanup ]--
	Player:GetAttributeChangedSignal("Dead"):Once(function()
		Cleanup()
	end)
	
	table.insert(Connections, Player.AncestryChanged:Connect(function()
		Cleanup()
	end))

	--[ Setting Change ]--
	ToggleView()
	table.insert(Connections, Overhead_Setting:GetPropertyChangedSignal("Value"):Connect(function()
		ToggleView()
	end))
	
	local Timer = 0
	table.insert(Connections, RunService.Heartbeat:Connect(function(delta)
		Timer += delta
		if Timer >= 1/8 then
			Timer = 0
			--[ Overhead Pins ]--
			Stat_Container.Energy.Visible = (Player.Stats.Tier.Value >= 0 and Player.OverheadPins.Energy_Pin.Value)
			Stat_Container.Flame.Visible = (Player.Stats.Tier.Value >= 1 and Player.OverheadPins.Flame_Pin.Value)
			Stat_Container.Power.Visible = (Player.Stats.Tier.Value >= 2 and Player.OverheadPins.Power_Pin.Value)
			Stat_Container.RealmPoints.Visible = (Player.Stats.Tier.Value >= 1 and Player.OverheadPins.RealmPoints_Pin.Value)
			Stat_Container.Damage.Visible = (Player.Stats.Tier.Value >= 4 and Player.OverheadPins.Damage_Pin.Value)
			Stat_Container.Flesh.Visible = (Player.Stats.Tier.Value >= 4 and Player.OverheadPins.Flesh_Pin.Value)
			Stat_Container.Prisms.Visible = (Player.Stats.Tier.Value >= 5 and Player.OverheadPins.Prisms_Pin.Value)
			Stat_Container.Orbs.Visible = (Player.Stats.Tier.Value >= 7 and Player.OverheadPins.Orbs_Pin.Value)
			Stat_Container.Spheres.Visible = (Player.Stats.Tier.Value >= 9 and Player.OverheadPins.Spheres_Pin.Value)
		
			Stat_Container.Droplets.Visible = ( Player.Stats.AscensionOne.Value and Player.OverheadPins.Droplets_Pin.Value)
			Stat_Container.ArcticPoints.Visible = (Player.Upgrades.Prisms_AP1.Value >= 1 and Player.OverheadPins.ArcticPoints_Pin.Value)
			Stat_Container.Chromium.Visible = (Player.Stats.Chromatize.Value >= 1 and Player.OverheadPins.Chromium_Pin.Value)
			Stat_Container.Water.Visible = (Player.Stats.AscensionOne.Value and Player.OverheadPins.Water_Pin.Value)
			Stat_Container.Icicles.Visible = (Player.Stats.Tier.Value >= 13 and Player.OverheadPins.Icicles_Pin.Value)
			Stat_Container.Ice.Visible = (Player.Upgrades.Freeze2.Value >= 1 and Player.OverheadPins.Ice_Pin.Value)


			--[ Stat Updates ]--
			Update("Energy", Energy.Value)
			Update("Flame", Flame.Value)
			Update("Power", Power.Value)
			Update("RealmPoints", RealmPoints.Value)
			Update("Damage", Formulas.Damage(Player))
			Update("Flesh", Flesh.Value)
			Update("Prisms", Prisms.Value)
			Update("Orbs", Orbs.Value)
			Update("Spheres", Spheres.Value)
			--Stat_Container["Droplets"].Text = Droplets.Value
			Update("Droplets", Droplets.Value)
			Update("ArcticPoints", ArcticPoints.Value)
			Update("Ice", Ice.Value)
			Update("Chromium", Chromium.Value)
			Update("Icicles", Icicles.Value)
			Update("Water", Water.Value)

			--[ Prime Updates ]--
			
			User_Status.Text = Player.Name
			
			if Player.Gamepasses.Prime.Value == true then
				Prime.Parent = User_Status
			end
			
			Group_Status.Text = Data.Name
			Group_Status.TextColor3 = Color3.fromRGB((Data.Color.R * 255), (Data.Color.G * 255), (Data.Color.B * 255))
		end
	end))
end

return Overhead
