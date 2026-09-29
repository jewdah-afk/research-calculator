local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()

--// Layer \\--
local Obj = workspace.Layers.Power
local Button = Obj.Power
local Board = Obj.PowerBoard
local Multiplier = Obj.Multiplier
local Active = false

local module = {}

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

function module.Update(Currency : number)
	if not Active then return end
	local Multi = Formulas.Power(Player)
	local Multi_Formatted = EN.Format(Multi)
	Multiplier.SurfaceGui.Main.Amount.Text = `x{Multi_Formatted} POWER`
	Board.SurfaceGui.Main.Damage.Text = `x{EN.Format(Formulas.Power_Damage(Currency, Player))} Damage`
	Button.Button.BillboardGui.Power.Text = `+{Multi_Formatted} POWER`
end

--[ Memory Saver ]--
local function UpdateCurrency(Currency : number)
	Board.SurfaceGui.Main.Amount.Text = `{EN.Format(Currency)} POWER`
end

Player.Stats.Power:GetPropertyChangedSignal("Value"):Connect(function()
	UpdateCurrency(Player.Stats.Power.Value)
end)

return module
