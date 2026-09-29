local Framework = require(game.ReplicatedStorage.Framework)
local ReplicatedStorage = Framework:GetService("ReplicatedStorage")
local EN = Framework:GetLibrary("EternityNum")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Formulas = Framework:GetSharedModule("Formulas")

local Player = Framework:GetPlayer()

local Obj = workspace.Areas["Spawn Island"].Tickets
local ArcticObj = workspace.Areas.Arctic.Tickets
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

function module.GetLayers()
	return {Obj, ArcticObj}
end

function module.Update()
	if not Active then return end
	Obj.TicketBoard.SurfaceGui.Main.TicketsAmount.Text = `{EN.Format(Player.Stats.Tickets.Value)}`
	ArcticObj.TicketBoard.SurfaceGui.Main.TicketsAmount.Text = `{EN.Format(Player.Stats.Tickets.Value)}`
end

return module
