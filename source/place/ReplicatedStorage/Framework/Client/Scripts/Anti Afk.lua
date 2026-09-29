local Framework = require(game.ReplicatedStorage.Framework)
local Player: Player = Framework:GetPlayer()
local AFK_Remote = Framework:GetEvent("AFK")
local debounce = false
local AntiAFK = {}

function AntiAFK.init()
	Player.Idled:Connect(function(delta)
		if delta > 500 then -- 900 Seconds = 15 Minutes
			while task.wait(1) do
				AFK_Remote:FireServer()
			end  
		end
	end)
end

return AntiAFK
