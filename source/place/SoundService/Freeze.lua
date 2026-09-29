local module = {}

local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")

local Freeze_Tiers = Framework:GetEvent("Freeze_Tiers")
local Main = Framework:GetServerModule("Freeze")

function module.init()
	Freeze_Tiers.OnServerEvent:Connect(function(Player, Tier)
		print(Tier)
		Main.Freeze(Player, Tier)
	end)
end

return module
