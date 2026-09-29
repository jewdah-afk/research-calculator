local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Formulas = Framework:GetSharedModule("Formulas")

--// Layer \\--
local Obj = workspace.Areas.Arctic.Chromifier
local Button = Obj.Chromify.Button
local Board = Obj.Chromifier

local Previous = nil
local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Formulas = Framework:GetSharedModule("Formulas")
local Upgrades = Framework:GetLibrary("Upgrades")

--// Layer \\--

local module = {}
local Active = false

function module.Toggle(HasReq : boolean)
	if HasReq then
		if Active then return end
		Active = true
		Obj.Parent = workspace.Layers
		return
	end
	if not HasReq then
		Active = false
		Obj.Parent = game.ReplicatedStorage.Layers_Storage
	end
end


--[[ function spheresFormula(Player : Player)
	local Value = 1
	
	if Player.Upgrades.Chromium_SpheresEnhance.Value > 0 and EN.me(Player.Stats.Chromium.Value, 0) then -- Chromium >> Spheres Boost
		local Chromium_Offset = EN.pow(Player.Stats.Spheres.Value, 0.75)
		if EN.le(Chromium_Offset, 1) then
			Chromium_Offset = EN(1)
		end
		Value = EN.mul(Value, Chromium_Offset)

	end

	return Value
end

function prismsFormula(Player : Player)
	local Value = 1
	
	Value = EN.mul(Value, EN.add(1, EN.mul(Player.Stats.Chromium.Value, 0.05)))
	
	Value = EN.mul(Value, Upgrades("Chromium_Prisms1"):GetEffect(Player.Upgrades.Chromium_Prisms1.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Prisms2"):GetEffect(Player.Upgrades.Chromium_Prisms2.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Prisms4"):GetEffect(Player.Upgrades.Chromium_Prisms4.Value, Player))
	
	return Value	
end

function runeLuckFormula(Player : Player)
	local Value = 1

	if Player.Upgrades.Chromium_RuneLuck1.Value > 0 and EN.me(Player.Stats.Chromium.Value, 0) then -- Chromium >> Rune Luck Boost

		local Chromium_Offset = EN.add(EN.mul(EN.div(Player.Stats.Chromium.Value, "1e21"),0.01),1)
		if EN.me(Chromium_Offset,2) then
			Chromium_Offset = EN.convert(2)
		end

		Chromium_Offset = EN.toNumber(Chromium_Offset)
		Value *= Chromium_Offset
	end

	return Value
end ]]--



function module.Update(Player : Player)
	local Chromify = Player.Stats["Chromify"].Value
	local ButtonBillboardGui = Button.BillboardGui

	ButtonBillboardGui.Title.Text = `Chromify {EN.Format(Chromify + 1)}:`
	ButtonBillboardGui.Price.Text = `{EN.Format(Formulas.Chromify_Cost(Chromify))} Chroma`
	
	local Cap = Board.SurfaceGui.Main.Cap
	Cap.Text = `[{Chromify}/3]`
	
	--local Milestones = Board.SurfaceGui.Main.Milestones
	--for _, milestone in Milestones:GetChildren() do 
	--	if milestone:IsA("Frame") then 
	--		milestone.Visible = Chromatize < tonumber(milestone.Name)
	--	end
	--end
	
	--[[ local ChromiumBoard = Obj.Chromium
	ChromiumBoard.SurfaceGui.Main.Amount.Text = `{EN.Format(Player.Stats.Chromium.Value)}`

	ChromiumBoard.SurfaceGui.Main.Gain.Text = `[+{EN.Format(Formulas.Chromium(Player))} / {EN.Format(Cooldowns.Chromium(Player))}s]`

	local Boosts = ChromiumBoard.SurfaceGui.Main.Boosts

	local PrismsBoost = Boosts.Prisms
	local currentGain = Formulas.Prisms(Player)
	PrismsBoost.Text = `x{EN.Format(prismsFormula(Player))} PRISMS`

	local SpheresBoost = Boosts.Spheres
	local currentGain = Formulas.Spheres(Player)
	SpheresBoost.Text = `x{EN.Format(spheresFormula(Player))} SPHERES`
	SpheresBoost.Visible = Player.Upgrades.Chromium_SpheresEnhance.Value >= 1
	
	local RuneLuckBoost = Boosts.RuneLuck
	local currentGain = Formulas.Rune_Luck(Player)
	RuneLuckBoost.Text = `x{EN.Format(runeLuckFormula(Player))} RUNE LUCK`
	RuneLuckBoost.Visible = Player.Upgrades.Chromium_RuneLuck1.Value >= 1 ]]--
end

return module
