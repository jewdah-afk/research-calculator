local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()

--// Layer \\--
local Obj = workspace.Layers.Flame
local Button = Obj.Flame
local Board = Obj.FlameBoard
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
	Board.SurfaceGui.Main.Amount.Text = EN.Format(Currency)
	Board.SurfaceGui.Main.EnergyMulti.Text = `x{EN.Format(Formulas.Flame_Energy(Currency))} ENERGY`
	Multiplier.SurfaceGui.Main.Amount.Text = `x{EN.Format(Formulas.Flame(Framework:GetPlayer()))} FLAME`
	Button.Button.BillboardGui.Flame.Text = `+{EN.Format(Formulas.Flame(Player))} FLAME`
	
	if EN.le(Currency, 1e6) then
		Board.SurfaceGui.Main.XPMulti.Text = `XP MULTI UNLOCKED AT 1M FLAME`
	else
		Board.SurfaceGui.Main.XPMulti.Text = `x{EN.Format(Formulas.Flame_XP(Currency))} XP`
	end
end

return module
