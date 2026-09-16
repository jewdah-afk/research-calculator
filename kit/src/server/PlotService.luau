--!nonstrict
--[[
	PlotService — procedural plots: floor, sign, vault, pads.

	Plots are built once at boot and leased to players. Everything a player owns
	lives on a plot, and every pad knows its index so the rest of the game can
	talk about "pad 3" instead of holding Instance references.
]]

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared:WaitForChild("Build"))
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local PlotService = {}

local PLOT_COUNT = 12
local MAX_PADS = 12
local PLOT_SIZE = Vector3.new(56, 1, 56)
local COLUMNS = 4
local SPACING = 86

local plots = {}          -- array of plot tables
local byPlayer = {}       -- [player] = plot

local function plotPosition(index)
	local column = (index - 1) % COLUMNS
	local row = math.floor((index - 1) / COLUMNS)
	return Vector3.new(
		(column - (COLUMNS - 1) / 2) * SPACING,
		0,
		60 + row * SPACING
	)
end

local function buildPad(plot, index)
	local perRow = MAX_PADS / 2
	local column = (index - 1) % perRow
	local row = math.floor((index - 1) / perRow)

	local offset = Vector3.new(
		(column - (perRow - 1) / 2) * 7.5,
		1.1,
		row == 0 and -9 or 4
	)

	local part = Build.part({
		Name = "Pad" .. index,
		Size = Vector3.new(6, 0.6, 6),
		Color = Color3.fromRGB(58, 64, 78),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(plot.origin + offset),
		Parent = plot.model,
	})
	part:SetAttribute("PadIndex", index)

	local ring = Build.part({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 6.4, 6.4),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CFrame = part.CFrame * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = plot.model,
	})
	ring.CanQuery = false

	local _, label = Build.billboard(part, "Empty", 4.5, 6)

	return {
		index = index,
		part = part,
		ring = ring,
		label = label,
		model = nil,   -- the pet model currently standing here
		uid = nil,     -- the inventory uid of that pet
		placedAt = 0,  -- os.clock when it landed, for the steal grace period
		prompt = nil,  -- the steal prompt, created by StealService
	}
end

local function buildPlot(index)
	local origin = plotPosition(index)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = workspace

	local plot = {
		index = index,
		model = model,
		origin = origin,
		owner = nil,
		pads = {},
		activePads = 4,
	}

	Build.part({
		Name = "Floor",
		Size = PLOT_SIZE,
		Color = Color3.fromRGB(72, 80, 96),
		Material = Enum.Material.Concrete,
		CFrame = CFrame.new(origin),
		Parent = model,
	})

	Build.part({
		Name = "Trim",
		Size = PLOT_SIZE + Vector3.new(2, -0.4, 2),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		CFrame = CFrame.new(origin - Vector3.new(0, 0.35, 0)),
		Parent = model,
	})

	-- The sign: who owns this plot, and how full their vault is.
	local sign = Build.part({
		Name = "Sign",
		Size = Vector3.new(10, 5, 0.6),
		Color = Color3.fromRGB(38, 42, 52),
		CFrame = CFrame.new(origin + Vector3.new(0, 4, -PLOT_SIZE.Z / 2)),
		Parent = model,
	})
	local _, signLabel = Build.billboard(sign, "Unclaimed", 4, 12)
	plot.signLabel = signLabel

	-- The vault: walk up, collect what your pets banked.
	local vault = Build.part({
		Name = "Vault",
		Size = Vector3.new(6, 5, 6),
		Color = Color3.fromRGB(226, 178, 74),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(origin + Vector3.new(0, 2.5, PLOT_SIZE.Z / 2 - 6)),
		Parent = model,
	})
	vault:SetAttribute("PlotIndex", index)
	local _, vaultLabel = Build.billboard(vault, "0", 4, 8)
	plot.vault = vault
	plot.vaultLabel = vaultLabel

	plot.spawnCFrame = CFrame.new(origin + Vector3.new(0, 4, PLOT_SIZE.Z / 2 - 14))

	for padIndex = 1, MAX_PADS do
		plot.pads[padIndex] = buildPad(plot, padIndex)
	end

	return plot
end

function PlotService.plotOf(player)
	return byPlayer[player]
end

function PlotService.plots()
	return plots
end

function PlotService.plotByIndex(index)
	return plots[index]
end

-- Walks up from any part to the plot it belongs to.
function PlotService.plotFromInstance(instance)
	local model = instance
	while model and model.Parent ~= workspace do
		model = model.Parent
	end
	if not model then
		return nil
	end
	local index = tonumber(string.match(model.Name, "^Plot(%d+)$"))
	return index and plots[index] or nil
end

function PlotService.setActivePads(plot, count)
	plot.activePads = math.clamp(count, 1, MAX_PADS)
	for index, pad in ipairs(plot.pads) do
		local active = index <= plot.activePads
		pad.part.Transparency = active and 0 or 0.85
		pad.part.CanCollide = active
		pad.ring.Transparency = active and 0.6 or 0.95
		pad.label.Text = active and (pad.uid and pad.label.Text or "Empty") or "Locked"
	end
end

function PlotService.assign(player)
	if byPlayer[player] then
		return byPlayer[player]
	end
	for _, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			plot.signLabel.Text = player.DisplayName .. "'s Plot"
			return plot
		end
	end
	return nil -- server full; PlayerService kicks with a friendly message
end

function PlotService.release(player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.owner = nil
	plot.signLabel.Text = "Unclaimed"
	plot.vaultLabel.Text = "0"

	for _, pad in ipairs(plot.pads) do
		if pad.model then
			pad.model:Destroy()
		end
		pad.model, pad.uid, pad.placedAt = nil, nil, 0
		pad.label.Text = "Empty"
		if pad.prompt then
			pad.prompt:Destroy()
			pad.prompt = nil
		end
	end
end

function PlotService.updateVaultLabel(plot, stored, cap)
	if plot and plot.vaultLabel then
		plot.vaultLabel.Text = ("%s / %s"):format(Format.short(stored), Format.short(cap))
	end
end

function PlotService.start()
	for index = 1, PLOT_COUNT do
		plots[index] = buildPlot(index)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlotService.release(player)
	end)
end

PlotService.MaxPads = MAX_PADS

return PlotService
