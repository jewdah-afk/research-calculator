--!nonstrict
--[[
	Server bootstrap.

	Order matters: data first, then the world, then the systems that decorate it.
	Every service exposes .start() and nothing does work at require time, so this
	file is the only place that decides sequencing.
]]

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Create the remotes before any client can ask for them.
for _, name in pairs(Remotes.Names) do
	Remotes.event(name)
end

local DataService = require(script:WaitForChild("DataService"))
local PlotService = require(script:WaitForChild("PlotService"))
local PlayerService = require(script:WaitForChild("PlayerService"))
local CarryService = require(script:WaitForChild("CarryService"))
local PetService = require(script:WaitForChild("PetService"))
local NestService = require(script:WaitForChild("NestService"))
local StealService = require(script:WaitForChild("StealService"))
local ShopService = require(script:WaitForChild("ShopService"))

DataService.start()
PlotService.start()
CarryService.start()
PetService.start()
StealService.start()
NestService.start()
ShopService.start()
PlayerService.start()   -- last: players may already be waiting to be set up

-- A flat, unobtrusive lobby floor so nobody falls out of the world.
local baseplate = Instance.new("Part")
baseplate.Name = "Lobby"
baseplate.Anchored = true
baseplate.Size = Vector3.new(900, 2, 900)
baseplate.Position = Vector3.new(0, -1, 0)
baseplate.Color = Color3.fromRGB(46, 50, 60)
baseplate.Material = Enum.Material.Concrete
baseplate.TopSurface = Enum.SurfaceType.Smooth
baseplate.Parent = workspace

print(("[%s] server ready — %d biomes, %d plots")
	:format(Config.GameName, #Config.Biomes, #PlotService.plots()))
