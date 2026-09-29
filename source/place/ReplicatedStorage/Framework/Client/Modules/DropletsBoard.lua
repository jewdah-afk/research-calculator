local dropletBoard = workspace.Areas.Arctic:WaitForChild("DropletBoard")
local StatsBoard = workspace.Areas.Arctic:WaitForChild("StatsBoard")
local AmountDisplay = dropletBoard.SurfaceGui.Main:WaitForChild("Amount")

local Player = game.Players.LocalPlayer
local Stats = Player:WaitForChild("Stats")

local Framework = require(game:GetService("ReplicatedStorage").Framework)
local EN = Framework:GetLibrary("EternityNum")
local droplets_DATA = Stats.Droplets
local Formulas = Framework:GetSharedModule("Formulas")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Upgrades = Framework:GetLibrary("Upgrades")


local Droplets_Module = {}

function Droplets_Module.init()
	
	AmountDisplay.Text = EN.Format(Player.Stats.Droplets.Value)
	
	droplets_DATA.Changed:Connect(function(afterValue)
		AmountDisplay.Text = EN.Format(Player.Stats.Droplets.Value)
	end)
end

function Droplets_Module.Update()
	local iceAmount = Player.Stats.Ice.Value
	local waterValue = Player.Stats.Water.Value
	local unlockedIce = Player.Upgrades.Freeze2.Value >= 1
	
	local GainDroplets = EN.mul(1, EN.add(1, EN.mul(0.5, waterValue)))
	StatsBoard.SurfaceGui.Main.DropletsMulti.Text = `x{EN.Format(GainDroplets)} DROPLETS`
	StatsBoard.SurfaceGui.Main.Water.Text = `WATER [{EN.toSuffix(waterValue)}]`

	local GainSpheres = EN.mul(Player.Stats.Droplets.Value, Upgrades("Droplets_Spheres1"):GetEffect(Player.Upgrades.Droplets_Spheres1.Value, Player))	
	dropletBoard.SurfaceGui.Main.SpheresMulti.Text = `x{EN.Format(GainSpheres)} SPHERES`
	
	StatsBoard.SurfaceGui.Main.Ice.Text = `ICE [{EN.Format(iceAmount)}]`
	StatsBoard.SurfaceGui.Main.Ice.Visible = unlockedIce
	
	local IceGainWater = EN.mul(1, EN.add(1, iceAmount))
	StatsBoard.SurfaceGui.Main.WaterMulti.Text = `x{EN.Format(IceGainWater)} WATER`
	StatsBoard.SurfaceGui.Main.WaterMulti.Visible = unlockedIce
	
	local IceGainSpheres = EN.mul(1, EN.add(1, EN.mul(0.1, iceAmount)))
	StatsBoard.SurfaceGui.Main.SpheresMulti.Text = `x{EN.Format(IceGainSpheres)} SPHERES`
	StatsBoard.SurfaceGui.Main.SpheresMulti.Visible = unlockedIce

	dropletBoard.SurfaceGui.Main.Generation.Text = `[+{EN.Format(Formulas.Droplets(Player))} / {EN.Format(Cooldowns.Droplets(Player))}s]`
end

return Droplets_Module
