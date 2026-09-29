local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Formulas = Framework:GetSharedModule("Formulas")

--// Layer \\--
local Obj = workspace.Layers.Tier
local Ascender = Obj.Ascender
local Button = Obj.Button
local Board = Obj.TierBoard
local XpBar = Obj.XpBar
local Previous = nil

local maxTier = 13

local module = {}

function module.Update(Player : Player)
	local Tier
	if Player.Stats.Tier.Value > maxTier then
		Tier = 13
	else
		Tier = Player.Stats.Tier.Value 
	end
	
	if Player.Stats.Tier.Value < 10 then
		Button.Detail.BillboardGui.Tier.Text = `Tier {EN.Format(Tier + 1)}:`
		
		Button.Detail.BillboardGui.Requirement2.Visible = false
		Button.Detail.BillboardGui.Requirement.Visible = true
		Button.Detail.BillboardGui.Requirement.Text = `{EN.Format(Formulas.Tier_Cost(Tier))} ENERGY`
		
		Ascender.Part.SurfaceGui.Main.currentTier.Text = `Tier {EN.Format(Player.Stats.Tier.Value)}`
		Ascender.Part.SurfaceGui.Main.Energy.Text = `{EN.Format(Formulas.Energy(Player))} ENERGY / {EN.Format(Cooldowns.Energy(Player))}s`
	else 	
		Button.Detail.BillboardGui.Tier.Text = `Tier {EN.Format(Tier + 1)}:`
		
		Button.Detail.BillboardGui.Requirement2.Visible = true
		Button.Detail.BillboardGui.Requirement.Visible = false
		Button.Detail.BillboardGui.Requirement2.Text = `{EN.Format(Formulas.Tier_Cost(Tier))} DROPLETS`

		Ascender.Part.SurfaceGui.Main.currentTier.Text = `Tier {EN.Format(Player.Stats.Tier.Value)}`
		Ascender.Part.SurfaceGui.Main.Energy.Text = `{EN.Format(Formulas.Droplets(Player))} DROPLETS / {EN.Format(Cooldowns.Droplets(Player))}s`

	end 
	
	--// Board Display \\--
	local New
	if Player.Stats.Tier.Value > maxTier then
		New = Board.SurfaceGui.Main.Tier_Displays["12"]
	else
		New = Board.SurfaceGui.Main.Tier_Displays[tostring(Player.Stats.Tier.Value)]
	end
	if Previous ~= New then
		if Previous then Previous.Visible = false end
		Previous = New
		Previous.Visible = true
	end
	
	if Player.Stats.Tier.Value < 4 then
		Ascender.Part.SurfaceGui.Main.XP.Text = `XP unlocked at Tier 4`
	else
		Ascender.Part.SurfaceGui.Main.XP.Text = `{EN.Format(Formulas.XP(Player))} XP / {EN.Format(Cooldowns.Energy(Player))}s`
	end
	
	--// XP Display \\--
	local Current_Level = Player.Stats.Level.Value
	--if Current_Level > maxTier then return end
	local Next_Level = Current_Level + 1
	local Req = Formulas.Level_Req(Current_Level)
	local Current_XP = Player.Stats.XP.Value
	local Progress = EN.div(Current_XP, Req)
	if EN.leeq(Progress, 0) then
		Progress = 0
	else
		Progress = EN.toNumber(Progress)
	end
	
	local Percentage = math.clamp(Progress, 0, 0.99)
	XpBar.SurfaceGui.Current.Text = `Current ({EN.Format(Current_Level)})`
	XpBar.SurfaceGui.Next.Text = `Next ({EN.Format(Next_Level)})`
	XpBar.SurfaceGui.Background.Bar.Size = UDim2.new(Percentage, 0, .85, 0)
	XpBar.SurfaceGui.Background.Display.Text = `{EN.Format(Current_XP)}/{EN.Format(Req)} XP`
	XpBar.SurfaceGui.Boost.Text = `x{EN.Format(Formulas.Level_Energy(Current_Level))} ENERGY`
end

return module
