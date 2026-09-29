local Framework = require(game.ReplicatedStorage.Framework)
--// Services \\--
local Sound_Service = Framework:GetService("SoundService")
--// Variables \\--
local Client_Player = Framework:GetPlayer()

local VolumeControl = {}

function UpdateVolume(Toggled : boolean)
	if Toggled then
		Sound_Service.Click.Volume = 0.25
		Sound_Service.Flame.Volume = 0.25
		Sound_Service.Hover.Volume = 0.25
		Sound_Service.Power.Volume = 0.25
		Sound_Service["Realm Points"].Volume = 0.25
		Sound_Service.Tier.Volume = 0.25
		Sound_Service.Upgrade.Volume = 0.25
		return
	end
	
	Sound_Service.Click.Volume = 0
	Sound_Service.Flame.Volume = 0
	Sound_Service.Hover.Volume = 0
	Sound_Service.Power.Volume = 0
	Sound_Service["Realm Points"].Volume = 0
	Sound_Service.Tier.Volume = 0
	Sound_Service.Upgrade.Volume = 0
end

function UpdateMusic(Toggled : boolean)
	if Toggled then

		return
	end
end

function VolumeControl.init()
	UpdateVolume(Client_Player.Settings.SoundEffects.Value)
	Client_Player.Settings.SoundEffects:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateVolume(Client_Player.Settings.SoundEffects.Value)
	end)
	
	UpdateMusic(Client_Player.Settings.Music.Value)
	Client_Player.Settings.Music:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateMusic(Client_Player.Settings.Music.Value)
	end)
end

return VolumeControl
