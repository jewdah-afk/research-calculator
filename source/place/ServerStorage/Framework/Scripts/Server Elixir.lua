local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players") :: Players

local ServerElixir = {}

function UpdatePlayers(boolean)
	for _ , Player in Players:GetPlayers() do
		Player:SetAttribute("ServerBoosted", boolean)
	end
end

function CheckElixirs()
	local Duration = 0
	local DurationUpdated = false
	
	for _ , Player in Players:GetPlayers() do
		if not Player:GetAttribute("Loaded") then continue end
		if not DurationUpdated and Player.Stats.ServerElixirDuration.Value > 0 then
			Player.Stats.ServerElixirDuration.Value -= 1
			DurationUpdated = true
		end
		Duration += Player.Stats.ServerElixirDuration.Value
	end
	game.ReplicatedStorage.ServerElixirDuration.Value = Duration
	UpdatePlayers(Duration > 0)
end

function ServerElixir.init()
	task.spawn(function()
		while task.wait(1) do
			CheckElixirs()
		end
	end)
end


return ServerElixir