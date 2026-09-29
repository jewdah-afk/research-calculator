local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()

--// Layer \\--
local Obj = workspace.Layers["Realm Points"]
local Button = Obj["Realm Points"]
local Board = Obj.RPBoard

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

function module.Update(Currency : number)
	Board.SurfaceGui.Main.Amount.Text = EN.Format(Currency)

	local Gain = Formulas.RealmPoints(Player)
	Board.SurfaceGui.Main.Multiplier.Text = `x{EN.Format(Gain)} RP`
	Button.Button.BillboardGui.RP.Text = `+{EN.Format(Gain)} RP`
end

return module
