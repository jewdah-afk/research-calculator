--!nonstrict
--[[
	CarryService — you are holding something, you are slower, and you are a target.

	This is the load-bearing mechanic of the whole genre: value only becomes
	yours once you have physically walked it home. Eggs from a nest and pets
	ripped off someone's pad both go through here.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared:WaitForChild("Build"))
local Config = require(Shared:WaitForChild("Config"))

local PlayerService = require(script.Parent:WaitForChild("PlayerService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local CarryService = {}

local DEPOSIT_RADIUS = 26

local carrying = {}          -- [player] = { kind, biome, record, model }
CarryService.onDeposit = {}  -- (player, payload) -> boolean handled

function CarryService.get(player)
	return carrying[player]
end

local function attach(player, model)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	model.Parent = workspace
	local primary = model.PrimaryPart
	model:PivotTo(root.CFrame * CFrame.new(0, 3.2, 0))

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			if descendant ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = descendant
				weld.Parent = primary
			end
		end
	end

	local hold = Instance.new("WeldConstraint")
	hold.Part0 = root
	hold.Part1 = primary
	hold.Parent = primary

	return true
end

function CarryService.give(player, payload)
	if carrying[player] then
		PlayerService.notify(player, "You're already carrying something — take it home first.", "warn")
		return false
	end

	local model
	if payload.kind == "egg" then
		local biome = Config.biomeById(payload.biome)
		model = Build.eggModel(biome and biome.color or Color3.new(1, 1, 1), payload.biome)
	else
		local def = Config.petById(payload.record.biome, payload.record.pet)
		model = Build.petModel(def or { id = payload.record.pet }, payload.record.tier or 0)
	end
	model.Name = "Carried"

	if not attach(player, model) then
		model:Destroy()
		return false
	end

	payload.model = model
	carrying[player] = payload
	player:SetAttribute("Carrying", true)
	PlayerService.refreshSpeed(player)
	return true
end

function CarryService.clear(player)
	local payload = carrying[player]
	carrying[player] = nil
	player:SetAttribute("Carrying", false)
	if payload and payload.model then
		payload.model:Destroy()
	end
	PlayerService.refreshSpeed(player)
	return payload
end

-- Dropping loses the cargo. Harsh on purpose: that is what makes the run home tense.
function CarryService.drop(player, reason)
	local payload = carrying[player]
	if not payload then
		return
	end
	CarryService.clear(player)
	PlayerService.notify(player, reason or "You dropped what you were carrying!", "bad")
end

local function tryDeposit(player)
	local payload = carrying[player]
	if not payload then
		return
	end

	local plot = PlotService.plotOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not plot or not root then
		return
	end

	if (root.Position - plot.origin).Magnitude > DEPOSIT_RADIUS then
		return
	end

	for _, handler in ipairs(CarryService.onDeposit) do
		local ok, handled = pcall(handler, player, payload)
		if ok and handled then
			CarryService.clear(player)
			return
		end
	end
end

function CarryService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		for player in pairs(carrying) do
			if player.Parent then
				tryDeposit(player)
			else
				carrying[player] = nil
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and Config.Steal.dropOnDeath then
				humanoid.Died:Connect(function()
					CarryService.drop(player, "You died and dropped your cargo!")
				end)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		CarryService.clear(player)
	end)
end

return CarryService
