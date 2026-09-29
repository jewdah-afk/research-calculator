local module = {}

local Framework = require(game.ReplicatedStorage.Framework)

local Water_Buttons_Event = Framework:GetEvent("Water_Buttons") :: RemoteFunction
local EN = Framework:GetLibrary("EternityNum")

local WaterButtons = workspace.Areas.Arctic.WaterButtons

local debounce = {}

function module.init()
	--Water_Buttons_Event.OnServerInvoke = function(Player, ButtonName)
	--	if WaterButtons:FindFirstChild(ButtonName) then
	--		if debounce[Player] then return end
	--		debounce[Player] = true
	--		task.delay(0.5,function()
	--			debounce[Player] = nil
	--		end)
	--		local PlayerDroplets = EN.toNumber(EN.fromString(Player.Stats.Droplets.Value))
	--		local Button = WaterButtons:FindFirstChild(ButtonName)
	--		if PlayerDroplets >= Button:GetAttribute("Take") then
				
	--			local Loss = PlayerDroplets - Button:GetAttribute("Take")
	--			local WaterGain = EN.fromNumber(Button:GetAttribute("Give") * Player.Stats.Water_Multiplier.Value)
	--			Player.Stats.Droplets.Value = EN.toString(EN.fromNumber(Loss))
	--			Player.Stats.Water.Value = EN.toString(WaterGain)
				
	--		end
	--	end
	--	return
	--end
end

return module
