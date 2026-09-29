local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")

--// Layer \\--
local Obj = workspace.Layers.Gears
local Board = Obj.Gears
local Active = false

local module = {}

function module.Toggle(HasReq : boolean)
	if HasReq then
		Active = true
		Obj.Parent = workspace.Layers
		return
	end
	Active = false
	Obj.Parent = game.ReplicatedStorage.Layers_Storage
end

function module.Update(Currency : number)
	if not Active then return end
	Board.SurfaceGui.Main.GearsAmount.Text = `{EN.Format(Currency)}/8`
	Board.SurfaceGui.Main.Buy.Visible = Currency < 8	
	Board.SurfaceGui.Main.Price.Text = `{EN.Format(Formulas.Gears_Cost(Currency))} ENERGY`
	Board.SurfaceGui.Main.Reduce.Text = `-{EN.Format(Formulas.Gears_Speed(Currency))}s Generation Time`
end

Board.SurfaceGui.Main.Buy.Activated:Connect(function()
	Framework.Events.Buy_Gears:FireServer()
end)

return module
