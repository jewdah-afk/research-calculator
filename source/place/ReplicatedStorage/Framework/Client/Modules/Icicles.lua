local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()

--// Layer \\--
local Obj = workspace.Areas.Arctic.Icicles
local Button = Obj.Icicles.Button
local Board = Obj.IciclesBoard
--local Multiplier = Obj.Multiplier
local Active = false

local Module = {}

function Module.Toggle(HasReq : boolean)
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

function Module.Update(Currency : number)
	if not Active then return end

	-- TODO: IMPLEMENT THIS BS WHENEVER THEY ACTUALLY GIVE ME MORE INFO
	
	local Icicles = Player.Stats.Icicles.Value
	local IciclesPlusOne = EN.add(Icicles,1 + 1)
	local Value = 1

	Board.SurfaceGui.Main.Amount.Text = `{EN.Format(Player.Stats.Icicles.Value)}`

	local DropletsBoard = Board.SurfaceGui.Main.Content.Droplets
	local currentGain = EN.mul(Value, EN.pow(Icicles,2))
	local nextGain = EN.mul(Value, EN.pow(IciclesPlusOne,2))
	DropletsBoard.Droplets.Text = `x{EN.Format(currentGain)} DROPLETS >> x{EN.Format(nextGain)} DROPLETS`

	local IceBoard = Board.SurfaceGui.Main.Content.Ice
	local currentGain = EN.mul(Value, EN.pow(Icicles,0.2))
	local nextGain = EN.mul(Value, EN.pow(IciclesPlusOne,0.2))
	IceBoard.Visible = Player.Upgrades.Chromium_Icicles4.Value >= 1
	IceBoard.Ice.Text = `x{EN.Format(currentGain)} ICE >> x{EN.Format(nextGain)} ICE`
	
	local PrismsBoard = Board.SurfaceGui.Main.Content.Prisms
	local currentGain = EN.mul(Value, EN.pow(Icicles,0.5))
	local nextGain = EN.mul(Value, EN.pow(IciclesPlusOne,0.5))
	PrismsBoard.Visible = Player.Upgrades.Chromium_Icicles3.Value >= 1
	PrismsBoard.Prisms.Text = `x{EN.Format(currentGain)} PRISMS >> x{EN.Format(nextGain)} PRISMS`
	
	local WaterBoard = Board.SurfaceGui.Main.Content.Water
	local currentGain = EN.mul(Value, EN.pow(Icicles,1))
	local nextGain = EN.mul(Value, EN.pow(IciclesPlusOne,1))
	WaterBoard.Visible = Player.Upgrades.Chromium_Icicles2.Value >= 1
	WaterBoard.Water.Text = `x{EN.Format(currentGain)} WATER >> x{EN.Format(nextGain)} WATER`	
	
	local IceThreshold = "1e17" -- 100Qn
	local gain = 0
	if EN.me(Player.Stats.Ice.Value, IceThreshold) then
		local ratio = EN.div(Player.Stats.Ice.Value, IceThreshold)
		gain = EN.pow(EN.log10(ratio), 5)
		gain = Formulas.Icicles(Player, gain)
	end	
	Button.BillboardGui.Icicles.Text = `+{EN.Format(gain)} ICICLES`
end

--[ Memory Saver ]--
local function UpdateCurrency(Currency : number)
	Board.SurfaceGui.Main.Amount.Text = `{EN.Format(Currency)}`
end

Player.Stats.Icicles:GetPropertyChangedSignal("Value"):Connect(function()
	UpdateCurrency(Player.Stats.Icicles)
end)

--Module.CustomEffect = function(Player : Player)
--	Player.Stats.Droplets.Value = 0
--end

--Module.CustomEffect = function(Player : Player)
--	Player.Stats.Water.Value = 0
--end

--Module.CustomEffect = function(Player : Player)
--	Player.Stats.Ice.Value = 0
--end

return Module
