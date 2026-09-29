local Framework = require(game.ReplicatedStorage.Framework)
local Messenger = Framework:GetLibrary("Messenger")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ElixirDuration = ReplicatedStorage.GlobalElixirDuration

local MemoryStoreService = game:GetService("MemoryStoreService")
local ElixirData = MemoryStoreService:GetSortedMap("GlobalElixir")
local ElixirDurationKey = "GlobalDuration"

local ElixirEvent = Framework:GetEvent("Use_Global")

local function AddElixirDuration()
	local succ, err = pcall(function()
		ElixirData:UpdateAsync(ElixirDurationKey, function(Old_Data)
			Old_Data = Old_Data or tick()
			
			local Time_Elapsed = Old_Data - tick()
			if Time_Elapsed < 0 then
				Old_Data = tick()
			end
			
			Old_Data += (15 * 60)
			return Old_Data
		end, 86400)
	end)
	if err then warn(err) end
end

local function UpdateElixirDuration()
	local succ, Duration = pcall(function()
		return ElixirData:GetAsync(ElixirDurationKey)
	end)
	Duration = Duration or tick()
	ElixirDuration.Value = math.max(Duration - tick(), 0)
end

local GlobalElixir = {}

function GlobalElixir.init()
	ElixirEvent.OnServerEvent:Connect(function(Player : Player)
		if Player.Stats.GlobalElixir.Value <= 0 then return end
		
		Player.Stats.GlobalElixir.Value -= 1
		AddElixirDuration()
		UpdateElixirDuration()
		
		Messenger.Publish({
			Sender = Player.Name;
			Type = "GlobalElixir"
		})
	end)
	
	task.spawn(function()
		while task.wait(6) do
			UpdateElixirDuration()
		end
	end)
	
	task.spawn(function()
		while task.wait(1) do
			ElixirDuration.Value = math.max(ElixirDuration.Value - 1, 0)
		end
	end)
end

return GlobalElixir
