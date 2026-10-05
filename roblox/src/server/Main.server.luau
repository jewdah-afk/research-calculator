--!nonstrict
-- Server bootstrap: creates remotes and starts every service in dependency order.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local EventService = require(Services.EventService)
local LeaderboardService = require(Services.LeaderboardService)
local AdminService = require(Services.AdminService)
local GameService = require(Services.GameService)

local R = Remotes.server()

EventService.init()
LeaderboardService.init()
GameService.init(R, { DataService = DataService, LeaderboardService = LeaderboardService })
AdminService.init(R, EventService, GameService.broadcast)

-- push event + leaderboard changes to every client
EventService.onChanged(function(list)
	R.Events:FireAllClients(list)
end)
LeaderboardService.onUpdated(function(boards)
	R.Leaderboards:FireAllClients(boards)
end)
game:GetService("Players").PlayerAdded:Connect(function(p)
	task.wait(3)
	R.Leaderboards:FireClient(p, LeaderboardService.get())
end)

game:BindToClose(function()
	GameService.saveAll(true)
	task.wait(2) -- let UpdateAsync calls finish
end)
