local Framework = require(game.ReplicatedStorage.Framework)
local SoundService = Framework:GetService("SoundService")
local SFX_Event = Framework:GetEvent("Play_SFX")
local Player = Framework:GetPlayer()

local module = {}

function module.init()
	SFX_Event.OnClientEvent:Connect(function(SFX_Name : string)
		if not Player.Settings.SoundEffects.Value then return end
		
		local SFX = SoundService:FindFirstChild(SFX_Name)
		if SFX then
			SFX:Play()
			return
		end
		
		warn(`CLIENT | ERROR | Sound "{SFX_Name}" not found.`)
	end)
end

return module
