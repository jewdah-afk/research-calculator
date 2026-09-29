local Framework = require(game.ReplicatedStorage.Framework)
--[ Libraries ]--
local EN = Framework:GetLibrary("EternityNum")
--[ Modules ]--
local Formulas = Framework:GetSharedModule("Formulas")

local module = {}
module.__index = module

function module:init(UI : Frame)
	local self = setmetatable({}, module)
	self.Energy_UI = UI
	self.Energy_Container = self.Energy_UI.Container
	self.Energy_Goal = self.Energy_Container.Goal
	self.Energy_Percentage = self.Energy_Container.Percentage
	self.Energy_Progress = self.Energy_Container.Progress
	self.Energy_Bar = self.Energy_Container.Background.Bar :: Frame
	
	self.Droplets_UI = game.Players.LocalPlayer.PlayerGui.TierBar2
	self.Droplets_Container = self.Droplets_UI.Container
	self.Droplets_Goal = self.Droplets_Container.Goal
	self.Droplets_Percentage = self.Droplets_Container.Percentage
	self.Droplets_Progress = self.Droplets_Container.Progress
	self.Droplets_Bar = self.Droplets_Container.Background.Bar :: Frame
	
	self.Chroma_UI = game.Players.LocalPlayer.PlayerGui.TierBar3
	self.Chroma_Container = self.Chroma_UI.Container
	self.Chroma_Goal = self.Chroma_Container.Goal
	self.Chroma_Percentage = self.Chroma_Container.Percentage
	self.Chroma_Progress = self.Chroma_Container.Progress
	self.Chroma_Bar = self.Chroma_Container.Background.Bar :: Frame
	
	return self
end

function module:Update(Currency : number, Tier : number)
	--// Calculations \\--
	local Req = Formulas.Tier_Cost(Tier)

	self.Energy_UI.Enabled = true
	self.Droplets_UI.Enabled = false
	self.Chroma_UI.Enabled = false

	local Percentage = 0
	if EN.me(Currency, 0) then
		Percentage = EN.toNumber(EN.div(EN.log10(Currency), EN.log10(Req)))
	end

	if EN.me(Percentage, 0) then
		Percentage = math.clamp(Percentage, 0, 1)
	end

	local Enough = EN.meeq(Currency, Req)
	local Next_Tier = EN.Format(Tier+1)
	--// Visual \\--
	Currency = EN.Format(Currency)
	self.Energy_Goal.Text = `{Currency}/{EN.Format(Req)} ENERGY`
	self.Energy_Percentage.Text = `{EN.Format(Percentage*100)}%`
	if not Enough then
		self.Energy_Progress.Text = `Progress to Tier {Next_Tier}`
	else
		self.Energy_Progress.Text = `You may now Tier Up to {Next_Tier}`
	end

	self.Energy_Bar:TweenSize(UDim2.new(Percentage,0,1,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.2, true)		
end

function module:UpdateTierBar2(Currency : number, Tier : number)
	--// Calculations \\--
	local Req = Formulas.Tier_Cost(Tier)

	self.Energy_UI.Enabled = false 
	self.Chroma_UI.Enabled = false
	self.Droplets_UI.Enabled = true

	local Percentage = 0
	if EN.me(Currency, 0) then
		Percentage = EN.toNumber(EN.div(EN.log10(Currency), EN.log10(Req)))
	end

	if EN.me(Percentage, 0) then
		Percentage = math.clamp(Percentage, 0, 1)
	end

	local Enough = EN.meeq(Currency, Req)
	local Next_Tier = EN.Format(Tier+1)
	--// Visual \\--
	Currency = EN.Format(Currency)
	self.Droplets_Goal.Text = `{Currency}/{EN.Format(Req)} DROPLETS`
	self.Droplets_Percentage.Text = `{EN.Format(Percentage*100)}%`
	if not Enough then
		self.Droplets_Progress.Text = `Progress to Tier {Next_Tier}`
	else
		self.Droplets_Progress.Text = `You may now Tier Up to {Next_Tier}`
	end

	self.Droplets_Bar:TweenSize(UDim2.new(Percentage,0,1,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.2, true)		
end

function module:UpdateTierBar3(Currency : number, Tier : number)
	--// Calculations \\--
	local Req = Formulas.Tier_Cost(Tier)

	self.Energy_UI.Enabled = false 
	self.Droplets_UI.Enabled = false
	self.Chroma_UI.Enabled = true

	local Percentage = 0
	if EN.me(Currency, 0) then
		Percentage = EN.toNumber(EN.div(EN.log10(Currency), EN.log10(Req)))
	end

	if EN.me(Percentage, 0) then
		Percentage = math.clamp(Percentage, 0, 1)
	end

	local Enough = EN.meeq(Currency, Req)
	local Next_Tier = EN.Format(Tier+1)
	--// Visual \\--
	Currency = EN.Format(Currency)
	self.Chroma_Goal.Text = `{Currency}/{EN.Format(Req)} Chroma`
	self.Chroma_Percentage.Text = `{EN.Format(Percentage*100)}%`
	if not Enough then
		self.Chroma_Progress.Text = `Progress to Tier {Next_Tier}`
	else
		self.Chroma_Progress.Text = `You may now Tier Up to {Next_Tier}`
	end

	self.Chroma_Bar:TweenSize(UDim2.new(Percentage,0,1,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.2, true)		
end

return module