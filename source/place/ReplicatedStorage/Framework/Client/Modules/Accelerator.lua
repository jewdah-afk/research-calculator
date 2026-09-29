local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Player = Framework:GetPlayer()
local Formulas = Framework:GetSharedModule("Formulas")
local Buy_Accelerator = Framework:GetEvent("Buy_Accelerator")
--// Layer \\--
local Obj = workspace.Layers.Accelerator
local Board = Obj.Accelerator

local module = {}

function module.Toggle(HasReq : boolean)
	if HasReq then
		Obj.Parent = workspace.Layers
		return
	end
	Obj.Parent = game.ReplicatedStorage.Layers_Storage
end

function module.Update(Currency : number)
	local Cap = Formulas.Accelerator_Levels(Player)
	Board.SurfaceGui.Main.AccelCap.Text = `{EN.Format(Currency)}/{Cap}`
	Board.SurfaceGui.Main.Buy.Visible = Currency < Cap
	Board.SurfaceGui.Main.Price.Text = `{EN.Format(Formulas.Accelerator_Cost(Currency))} POWER`
	Board.SurfaceGui.Main.ReducePrism.Text = `x{EN.Format(Formulas.Accelerator_PrismSpeed(Currency))} FASTER PRISM GENERATION`
	Board.SurfaceGui.Main.ReduceCube.Text = `x{EN.Format(Formulas.Accelerator_CubeSpeed(Currency))} FASTER CUBE SPAWNING`
end
	
Board.SurfaceGui.Main.Buy.Activated:Connect(function()
	Framework.Events.Buy_Accelerator:FireServer()
end)

return module
