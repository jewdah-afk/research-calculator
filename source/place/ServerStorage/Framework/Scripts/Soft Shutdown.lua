local Framework = require(game.ReplicatedStorage.Framework)
--// Services \\--
local RunService = Framework:GetService("RunService")
--// Classes \\--
local Datastore = Framework:GetLibrary("Datastore")

local SoftShutdown = {}

function SoftShutdown.init()
	if RunService:IsStudio() then return warn(`SERVER | SOFT SHUTDOWN | Disabled in studio`) end

	game:BindToClose(function()
		Framework.Events.Shutdown:FireAllClients()
		local placeId = game.PlaceId
		local plrs = game.Players:GetPlayers()

		for _, plr in plrs do
			local Data = Datastore(plr)
			if Data then
				local success, err = pcall(function()
					coroutine.wrap(function()
						Data:Save(true)
					end)()
				end)
				if not success then
					warn(`BindToClose Save failed for {plr.Name}: {err}`)
				end
			end
		end

		task.wait(5)

		local teleOptions = Instance.new("TeleportOptions")
		teleOptions.ShouldReserveServer = false

		game:GetService("TeleportService"):TeleportAsync(placeId,plrs,teleOptions)
		task.wait(10) 
	end)
end

return SoftShutdown
