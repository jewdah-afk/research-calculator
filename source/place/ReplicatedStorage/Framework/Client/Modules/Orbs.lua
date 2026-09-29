local Framework = require(game.ReplicatedStorage.Framework)
local Collection_Service = Framework:GetService("CollectionService")
local Tween_Service = Framework:GetService("TweenService")
local EN = Framework:GetLibrary("EternityNum")
local Upgrades = Framework:GetLibrary("Upgrades")
local Formulas = Framework:GetSharedModule("Formulas")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Player = Framework:GetPlayer()

local Layer = workspace.Layers.Orbs
local Board = Layer.Incrementor

local Orbs_Orbs = Upgrades("Orbs_Orbs")
local Orbs_RuneLuck = Upgrades("Orbs_RuneLuck")
local Orbs_RuneSpeed = Upgrades("Orbs_RuneSpeed")
local Orbs_Energy = Upgrades("Orbs_Energy")
local Orbs_Flame = Upgrades("Orbs_Flame")

local TalentTree = {}

function TalentTree.Toggle(HasReq)
	if HasReq then
		Layer.Parent = workspace.Layers
		return
	end
	Layer.Parent = game.ReplicatedStorage.Layers_Storage
end

function UpdateUpgrade(UpgradeName : string)
	local Gui = Layer[UpgradeName].Button.BillboardGui
	local Upg_Class = Upgrades(UpgradeName)
	
	local Current = Player.Upgrades[UpgradeName].Value
	local CurrentEffect = Upg_Class:GetEffect(Current)

	if Upg_Class:IsMaxed(Current) then
		Gui.Price.Text = "MAXED"
		Gui.Display.Text = Upg_Class.Effect_Display(EN.Format(CurrentEffect))
		return
	end
	
	local Next = Current + 1
	local NextEffect = Upg_Class:GetEffect(Next)
	Gui.Price.Text = `Price: {EN.Format(Upg_Class:GetCost(Current))} Orbs`
	Gui.Display.Text = Upg_Class.Effect_Display(EN.Format(CurrentEffect), EN.Format(NextEffect))
end

function TalentTree.Update()
	local Orbs = Player.Stats.Orbs.Value
	Board.SurfaceGui.Main.Amount.Text = EN.Format(Orbs)
	Board.SurfaceGui.Main.Gain.Text = `{EN.Format(Formulas.Orbs(Player))} / {Cooldowns.Orbs(Player)}S`
	
	
	Board.SurfaceGui.Main.EnergyMulti.Text = `X{EN.Format(Formulas.Orbs_Energy(Orbs))} ENERGY`
	Board.SurfaceGui.Main.FlameMulti.Text = `X{EN.Format(Formulas.Orbs_Flame(Orbs))} FLAME`
	Board.SurfaceGui.Main.PowerMulti.Text = `X{EN.Format(Formulas.Orbs_Power(Orbs))} POWER`
	Board.SurfaceGui.Main.RPMulti.Text = `X{EN.Format(Formulas.Orbs_RealmPoints(Orbs, Player))} RP`
	Board.SurfaceGui.Main.FleshMulti.Text = `X{EN.Format(Formulas.Orbs_Flesh(Orbs))} FLESH`
	Board.SurfaceGui.Main.RuneBulk.Text = `+{EN.Format(Formulas.Orbs_RuneBulk(Orbs))} RUNE BULK`
	
	UpdateUpgrade("Orbs_Orbs")
	UpdateUpgrade("Orbs_RuneLuck")
	UpdateUpgrade("Orbs_RuneSpeed")
	UpdateUpgrade("Orbs_Energy")
	UpdateUpgrade("Orbs_Flame")
end

return TalentTree
