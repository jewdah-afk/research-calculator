local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()

--// Layer \\--
local Obj = workspace.Areas.Arctic.Reflection
local Button = Obj.Reflection
local Board = Obj.ReflectionBoard
local Active = false

local module = {}

function module.Toggle(HasReq : boolean)
	if HasReq then
		if Active then return end
		Active = true
		Obj.Parent = workspace.Areas.Arctic
		return
	end
	if not HasReq then
		Active = false
		Obj.Parent = game.ReplicatedStorage.Layers_Storage
	end
end

function module.Update(Currency : number)
	if not Active then return end
	local Multi = Formulas.Reflection(Player)
	local Multi_Formatted = EN.Format(Multi)
	Button.Button.BillboardGui.Reflection.Text = `+{Multi_Formatted} Reflection`
end

--[ Memory Saver ]--
local function UpdateCurrency(Currency : number)
	Board.SurfaceGui.Main.Amount.Text = `{EN.Format(Currency)} Reflection`
end

Player.Stats.Reflection:GetPropertyChangedSignal("Value"):Connect(function()
	UpdateCurrency(Player.Stats.Reflection.Value)
end)

return module
