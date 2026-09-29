--[[ FRAMEWORK ]]--
local Framework = require(game.ReplicatedStorage.Framework)
local StatsEvent = Framework:GetEvent("Toggle_Tag")

local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")

--[[ VARIABLES ]]--
local Player = Framework:GetPlayer()
local PlayerGui = Framework.Gui
local ScreenGui = PlayerGui:WaitForChild("Stats")
local Holder = ScreenGui.Holder

local StatsUI = {}

function StatsUI:init()
	Holder.Stats_Toggle.Activated:Connect(function()
		Holder.Stats.Visible = not Holder.Stats.Visible
		Holder.Tags.Visible = false
	end)

	Holder.Tags_Toggle.Activated:Connect(function()
		Holder.Stats.Visible = false
		Holder.Tags.Visible = not Holder.Tags.Visible
	end)

	for _ , Stat in Holder.Stats:GetChildren() do
		if Stat.ClassName ~= "Frame" then continue end

		local StatName = Stat.Name.."_Pin"
		local Pin = Player.OverheadPins[StatName]

		local function Update()
			if Pin.Value then
				Stat.Toggle.UIGradient.Color = script.Disabled.Color
				Stat.Toggle.Pin.Text = "UNPIN"
				return
			end
			Stat.Toggle.UIGradient.Color = script.Enabled.Color
			Stat.Toggle.Pin.Text = "PIN"
		end

		Stat.Toggle.Activated:Connect(function()
			StatsEvent:FireServer(StatName)
		end)

		Update()
		Pin:GetPropertyChangedSignal("Value"):Connect(Update)
	end

	task.spawn(function()
		while task.wait(1/8) do
			Holder.Stats.Damage.Stat.Text = `DMG >> {EN.Format(Formulas.Damage(Player))}`
			Holder.Stats.Energy.Stat.Text = `ENERGY >> {EN.Format(Player.Stats.Energy.Value)}`
			Holder.Stats.Flame.Stat.Text = `FLAME >> {EN.Format(Player.Stats.Flame.Value)}`
			Holder.Stats.Flesh.Stat.Text = `FLESH >> {EN.Format(Player.Stats.Flesh.Value)}`
			Holder.Stats.Orbs.Stat.Text = `ORBS >> {EN.Format(Player.Stats.Orbs.Value)}`
			Holder.Stats.Power.Stat.Text = `POWER >> {EN.Format(Player.Stats.Power.Value)}`
			Holder.Stats.Prisms.Stat.Text = `PRISMS >> {EN.Format(Player.Stats.Prisms.Value)}`
			Holder.Stats.RealmPoints.Stat.Text = `RP >> {EN.Format(Player.Stats["Realm Points"].Value)}`
			Holder.Stats.Spheres.Stat.Text = `SPHERES >> {EN.Format(Player.Stats.Spheres.Value)}`

			Holder.Stats.ArcticPoints.Stat.Text = `AP >> {EN.Format(Player.Stats.ArcticPoints.Value)}`
			Holder.Stats.Chromium.Stat.Text = `CHROMIUM >> {EN.Format(Player.Stats.Chromium.Value)}`
			Holder.Stats.Droplets.Stat.Text = `DROPLETS >> {EN.Format(Player.Stats.Droplets.Value)}`
			Holder.Stats.Ice.Stat.Text = `ICE >> {EN.Format(Player.Stats.Ice.Value)}`
			Holder.Stats.Icicles.Stat.Text = `ICICLES >> {EN.Format(Player.Stats.Icicles.Value)}`
			Holder.Stats.Water.Stat.Text = `WATER >> {EN.Format(Player.Stats.Water.Value)}`


			Holder.Stats.Damage.Visible = Player.Stats.Tier.Value >= 4
			Holder.Stats.Energy.Visible = Player.Stats.Tier.Value >= 0
			Holder.Stats.Flame.Visible = Player.Stats.Tier.Value >= 1
			Holder.Stats.Flesh.Visible = Player.Stats.Tier.Value >= 4
			Holder.Stats.Orbs.Visible = Player.Stats.Tier.Value >= 7
			Holder.Stats.Power.Visible = Player.Stats.Tier.Value >= 2
			Holder.Stats.Prisms.Visible = Player.Stats.Tier.Value >= 5
			Holder.Stats.RealmPoints.Visible = Player.Stats.Tier.Value >= 1
			Holder.Stats.Spheres.Visible = Player.Stats.Tier.Value >= 9

			Holder.Stats.ArcticPoints.Visible = Player.Upgrades.Prisms_AP1.Value >= 1
			Holder.Stats.Chromium.Visible = Player.Stats.Chromatize.Value >= 1
			Holder.Stats.Droplets.Visible = Player.Stats.AscensionOne.Value
			Holder.Stats.Ice.Visible = Player.Upgrades.Freeze2.Value >= 1
			Holder.Stats.Icicles.Visible = Player.Stats.Tier.Value >= 13
			Holder.Stats.Water.Visible = Player.Stats.AscensionOne.Value

		end
	end)
end

return StatsUI