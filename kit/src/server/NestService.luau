--!nonstrict
--[[
	NestService — the biomes and the eggs sitting in them.

	Biomes are speed-gated: an upgrade buys WalkSpeed, WalkSpeed opens the next
	biome, the next biome pays an order of magnitude more. That is the whole
	progression spine, and it is why "Speed" is the first upgrade in the shop.
]]

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared:WaitForChild("Build"))
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))

local CarryService = require(script.Parent:WaitForChild("CarryService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlayerService = require(script.Parent:WaitForChild("PlayerService"))

local NestService = {}

local BIOME_SIZE = Vector3.new(120, 2, 120)

local function buildGate(biome, folder)
	if biome.speedGate <= 0 then
		return
	end

	local gate = Build.part({
		Name = "Gate",
		Size = Vector3.new(BIOME_SIZE.X, 14, 2),
		Color = biome.color,
		Material = Enum.Material.ForceField,
		Transparency = 0.5,
		CanCollide = false,
		CFrame = CFrame.new(biome.origin + Vector3.new(0, 7, -BIOME_SIZE.Z / 2)),
		Parent = folder,
	})
	Build.billboard(gate, ("%s — needs %d speed"):format(biome.id, biome.speedGate), 9, 16)

	gate.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local data = DataService.get(player)
		if not data then
			return
		end
		if Economy.canEnter(data, PlayerService.flags(player), biome.id) then
			return
		end

		-- Bounce them back out rather than teleporting them somewhere confusing.
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = root.CFrame * CFrame.new(0, 0, 12)
		end
		if PlayerService.rateLimit(player, "collect") then
			PlayerService.notify(player, ("%s needs %d speed. Buy Speed in the shop.")
				:format(biome.id, biome.speedGate), "warn")
		end
	end)
end

local function spawnEgg(nest, biome)
	if nest.model then
		nest.model:Destroy()
	end
	local model = Build.eggModel(biome.color, biome.id)
	model:PivotTo(CFrame.new(nest.position + Vector3.new(0, 3.2, 0)))
	model.Parent = nest.folder
	nest.model = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take Egg"
	prompt.ObjectText = biome.id .. " Nest"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	nest.prompt = prompt

	prompt.Triggered:Connect(function(player)
		if not PlayerService.rateLimit(player, "hatch") then
			return
		end
		local data = DataService.get(player)
		if not data then
			return
		end
		if not Economy.canEnter(data, PlayerService.flags(player), biome.id) then
			PlayerService.notify(player, ("You need %d speed for %s."):format(biome.speedGate, biome.id), "warn")
			return
		end

		if CarryService.give(player, { kind = "egg", biome = biome.id }) then
			PlayerService.notify(player, "Run it back to your plot to hatch it!", "info")
			nest.model:Destroy()
			nest.model = nil
			task.delay(biome.respawn, function()
				spawnEgg(nest, biome)
			end)
		end
	end)
end

local function buildBiome(biome)
	local folder = Instance.new("Folder")
	folder.Name = "Biome_" .. biome.id
	folder.Parent = workspace

	Build.part({
		Name = "Ground",
		Size = BIOME_SIZE,
		Color = biome.color,
		Material = Enum.Material.Grass,
		CFrame = CFrame.new(biome.origin),
		Parent = folder,
	})

	local sign = Build.part({
		Name = "Sign",
		Size = Vector3.new(12, 6, 1),
		Color = Color3.fromRGB(30, 34, 42),
		CFrame = CFrame.new(biome.origin + Vector3.new(0, 5, 0)),
		Parent = folder,
	})
	Build.billboard(sign, biome.id, 5, 14)

	buildGate(biome, folder)

	for index = 1, biome.nests do
		local angle = (index / biome.nests) * math.pi * 2
		local position = biome.origin + Vector3.new(
			math.cos(angle) * (BIOME_SIZE.X / 2 - 22),
			1,
			math.sin(angle) * (BIOME_SIZE.Z / 2 - 22)
		)

		Build.part({
			Name = "Pedestal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 7, 7),
			Color = Color3.fromRGB(48, 52, 62),
			CFrame = CFrame.new(position + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = folder,
		})

		local nest = { position = position, folder = folder }
		spawnEgg(nest, biome)
	end
end

function NestService.start()
	for _, biome in ipairs(Config.Biomes) do
		buildBiome(biome)
	end
end

return NestService
