--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Variables ]]--
local ScreenGui = Framework.Gui.Store
local ContainerGui = ScreenGui.Holder.Content
local ButtonsGui = ScreenGui.Holder.Buttons

local Positions = {
	Packs = 0,
	Bundles = 616,
	Rune = 2156,
	Offer = 2590,
	Featured = 2950,
	Gamepasses = 3960,
	Elixirs = 4920,
	Tickets = 6555,
	Donations = 8400,
	Codes = 9545
}

local Buttons = {}

function Buttons.init()
	for Name, Position in Positions do
		if ButtonsGui:FindFirstChild(Name,true) then
			ButtonsGui[Name].Activated:Connect(function()
				ContainerGui.CanvasPosition = Vector2.new(0, Position)
			end)
		end
	end
end

return Buttons