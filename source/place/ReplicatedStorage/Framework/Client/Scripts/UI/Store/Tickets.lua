--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Modules ]]--
local Formulas = Framework:GetSharedModule("Formulas")
local EternityNum = Framework:GetLibrary("EternityNum")

local Functions = require(script.Parent.Functions)

--[[ Variables ]]--
local Player = Framework:GetPlayer()

local ScreenGui = Framework.Gui.Store
local TicketGui = ScreenGui.Holder.Content.Tickets

local Multipliers = {
	["1"] = 50,
	["2"] = 250,
	["3"] = 500,
	["4"] = 1500,
	["5"] = 5e3,
	["6"] = 2.5e4,
	["7"] = 1.25e5,
}

local Tickets = {}

--[[ Code ]]--
function Tickets.init()
	Functions.AddProduct(TicketGui["7"])

	for _, Ticket in TicketGui.Tickets:GetChildren() do
		if Ticket:IsA("Frame") then 
			Functions.AddProduct(Ticket) 
		end
	end

	task.spawn(function()
		while task.wait(1) do
			local Multiplier = Formulas.Tickets(Player)	

			for Id, Value in Multipliers do
				local TicketFrame = if Id == "7" then TicketGui["7"] else TicketGui.Tickets:FindFirstChild(Id)
				if TicketFrame then
					TicketFrame.Title.Text = string.format("%s TICKETS!", EternityNum.Format(EternityNum.mul(Value, Multiplier)))
				end
			end
		end
	end)
end


return Tickets