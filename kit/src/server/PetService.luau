--!nonstrict
--[[
	PetService — hatching, pads, income, fusing.

	Every value decision (which pet you rolled, what it earns, how much is in the
	vault) is made here on the server. The client is told, never asked.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared:WaitForChild("Build"))
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CarryService = require(script.Parent:WaitForChild("CarryService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlayerService = require(script.Parent:WaitForChild("PlayerService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local PetService = {}

PetService.padChanged = {}   -- (plot, pad) -> (), StealService hooks its prompts here

local function announcePad(plot, pad)
	for _, callback in ipairs(PetService.padChanged) do
		task.spawn(callback, plot, pad)
	end
end

local function newUid()
	return HttpService:GenerateGUID(false)
end

local function findRecord(data, uid)
	for index, record in ipairs(data.inventory or {}) do
		if record.uid == uid then
			return record, index
		end
	end
	return nil
end

local function isPlaced(data, uid)
	for _, placedUid in pairs(data.placed or {}) do
		if placedUid == uid then
			return true
		end
	end
	return false
end

local function labelFor(record)
	local def = Config.petById(record.biome, record.pet)
	local tierName = Config.Fuse.tierNames[(record.tier or 0) + 1] or ""
	local income = Economy.petIncome(record)
	return ("%s%s\n%s/s"):format(tierName, record.pet, Format.short(income)),
		def and def.color or Color3.new(1, 1, 1)
end

local function clearPad(plot, pad)
	if pad.model then
		pad.model:Destroy()
	end
	pad.model = nil
	pad.uid = nil
	pad.placedAt = 0
	pad.label.Text = "Empty"
	announcePad(plot, pad)
end

local function dressPad(plot, pad, record)
	if pad.model then
		pad.model:Destroy()
	end
	local def = Config.petById(record.biome, record.pet)
	local model = Build.petModel(def or { id = record.pet }, record.tier or 0)
	model:PivotTo(pad.part.CFrame * CFrame.new(0, 1.6, 0))
	model.Parent = plot.model

	pad.model = model
	pad.uid = record.uid
	pad.placedAt = os.clock()

	local text = labelFor(record)
	pad.label.Text = text
	announcePad(plot, pad)
end

function PetService.firstFreePad(player, data)
	local plot = PlotService.plotOf(player)
	if not plot then
		return nil
	end
	local limit = math.min(Economy.padCount(data), PlotService.MaxPads)
	for index = 1, limit do
		local pad = plot.pads[index]
		if pad and not pad.uid then
			return pad, plot
		end
	end
	return nil, plot
end

function PetService.place(player, uid, requestedPad)
	local data = DataService.get(player)
	if not data then
		return false
	end
	local record = findRecord(data, uid)
	if not record or isPlaced(data, uid) then
		return false
	end

	local plot = PlotService.plotOf(player)
	if not plot then
		return false
	end

	local pad
	if requestedPad then
		local candidate = plot.pads[requestedPad]
		if candidate and not candidate.uid and requestedPad <= Economy.padCount(data) then
			pad = candidate
		end
	end
	if not pad then
		pad = PetService.firstFreePad(player, data)
	end
	if not pad then
		PlayerService.notify(player, "No free pads — buy the Pads upgrade or store a pet.", "warn")
		return false
	end

	data.placed[tostring(pad.index)] = uid
	dressPad(plot, pad, record)
	PlayerService.pushState(player)
	return true
end

function PetService.store(player, padIndex)
	local data = DataService.get(player)
	local plot = PlotService.plotOf(player)
	if not data or not plot then
		return false
	end
	local pad = plot.pads[padIndex]
	if not pad or not pad.uid then
		return false
	end

	data.placed[tostring(padIndex)] = nil
	clearPad(plot, pad)
	PlayerService.pushState(player)
	return true
end

-- Used by StealService: take the pet off the pad and hand the record back.
function PetService.takeFromPad(owner, padIndex)
	local data = DataService.get(owner)
	local plot = PlotService.plotOf(owner)
	if not data or not plot then
		return nil
	end
	local pad = plot.pads[padIndex]
	if not pad or not pad.uid then
		return nil
	end

	local record, index = findRecord(data, pad.uid)
	if not record then
		return nil
	end

	table.remove(data.inventory, index)
	data.placed[tostring(padIndex)] = nil
	clearPad(plot, pad)
	data.stolenFromMe = (data.stolenFromMe or 0) + 1
	PlayerService.pushState(owner)
	return record
end

function PetService.addRecord(player, record, autoPlace)
	local data = DataService.get(player)
	if not data then
		return false
	end
	record.uid = newUid()
	table.insert(data.inventory, record)
	if autoPlace ~= false then
		PetService.place(player, record.uid)
	end
	PlayerService.pushState(player)
	return true
end

function PetService.hatch(player, biomeId)
	local data = DataService.get(player)
	local biome = Config.biomeById(biomeId)
	if not data or not biome then
		return false
	end

	local flags = PlayerService.flags(player)
	local luck = Economy.luck(data, flags, os.time())
	local rolled = Rarity.roll(biome.pets, luck)

	local record = { uid = newUid(), biome = biomeId, pet = rolled.id, tier = 0 }
	table.insert(data.inventory, record)
	data.hatches = (data.hatches or 0) + 1

	local tier = Config.rarityFor(rolled.oneIn)
	Remotes.event(Remotes.Names.HatchResult):FireClient(player, {
		pet = rolled.id,
		biome = biomeId,
		income = rolled.income,
		oneIn = rolled.oneIn,
		chance = Rarity.chanceText(rolled.oneIn, luck),
		rarity = tier.id,
		color = tier.color,
		shake = tier.shake,
	})

	-- Rare pulls are the game's free marketing: tell the server about it.
	if rolled.oneIn >= 3000 then
		for _, other in ipairs(Players:GetPlayers()) do
			PlayerService.notify(other, ("%s hatched a %s %s (%s)!")
				:format(player.DisplayName, tier.id, rolled.id, Rarity.chanceText(rolled.oneIn, 1)), "good")
		end
	end

	PetService.place(player, record.uid)
	PlayerService.pushState(player)
	return true
end

-- Three identical, unplaced copies -> one of the next tier.
function PetService.fuse(player, biomeId, petId, tier)
	local data = DataService.get(player)
	if not data then
		return false
	end
	tier = tier or 0
	if tier >= Config.Fuse.maxTier then
		PlayerService.notify(player, "That pet is already at max fusion.", "warn")
		return false
	end

	local matches = {}
	for index, record in ipairs(data.inventory) do
		if record.biome == biomeId and record.pet == petId and (record.tier or 0) == tier
			and not isPlaced(data, record.uid) then
			table.insert(matches, index)
			if #matches == Config.Fuse.copiesRequired then
				break
			end
		end
	end

	if #matches < Config.Fuse.copiesRequired then
		PlayerService.notify(player, ("Need %d unplaced copies to fuse.")
			:format(Config.Fuse.copiesRequired), "warn")
		return false
	end

	table.sort(matches, function(a, b) return a > b end)
	for _, index in ipairs(matches) do
		table.remove(data.inventory, index)
	end

	local fused = { uid = newUid(), biome = biomeId, pet = petId, tier = tier + 1 }
	table.insert(data.inventory, fused)
	PlayerService.notify(player, ("Fused into %s%s!")
		:format(Config.Fuse.tierNames[tier + 2] or "", petId), "good")
	PetService.place(player, fused.uid)
	PlayerService.pushState(player)
	return true
end

function PetService.collect(player)
	local data = DataService.get(player)
	if not data or (data.vault or 0) <= 0 then
		return false
	end
	local amount = math.floor(data.vault)
	data.vault = 0
	PlayerService.addCoins(player, amount)
	PlotService.updateVaultLabel(PlotService.plotOf(player), 0, Economy.storageCap(data))
	PlayerService.notify(player, ("Collected %s coins."):format(Format.short(amount)), "good")
	PlayerService.pushState(player)
	return true
end

local function restore(player, data)
	local plot = PlotService.plotOf(player)
	if not plot then
		return
	end
	PlotService.setActivePads(plot, Economy.padCount(data))

	for padKey, uid in pairs(data.placed or {}) do
		local padIndex = tonumber(padKey)
		local pad = padIndex and plot.pads[padIndex]
		local record = findRecord(data, uid)
		if pad and record and padIndex <= Economy.padCount(data) then
			dressPad(plot, pad, record)
		else
			data.placed[padKey] = nil -- stale entry, e.g. after a pad downgrade
		end
	end
end

local function tick()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		local plot = PlotService.plotOf(player)
		if data and plot then
			local flags = PlayerService.flags(player)
			local cap = Economy.storageCap(data)
			local earned = Economy.income(data, flags) * Config.IncomeTickRate

			if flags.autoCollect then
				PlayerService.addCoins(player, earned)
			else
				data.vault = math.min((data.vault or 0) + earned, cap)
			end

			PlotService.updateVaultLabel(plot, data.vault or 0, cap)
		end
	end
end

function PetService.start()
	table.insert(PlayerService.profileReady, restore)

	-- An egg walked home hatches; a stolen pet walked home is yours.
	table.insert(CarryService.onDeposit, function(player, payload)
		if payload.kind == "egg" then
			PetService.hatch(player, payload.biome)
			return true
		elseif payload.kind == "pet" then
			PetService.addRecord(player, {
				biome = payload.record.biome,
				pet = payload.record.pet,
				tier = payload.record.tier or 0,
			})
			local data = DataService.get(player)
			if data then
				data.stolenByMe = (data.stolenByMe or 0) + 1
			end
			PlayerService.notify(player, "Stolen pet secured!", "good")
			return true
		end
		return false
	end)

	Remotes.event(Remotes.Names.PlacePet).OnServerEvent:Connect(function(player, uid, padIndex)
		if type(uid) == "string" and PlayerService.rateLimit(player, "place") then
			PetService.place(player, uid, tonumber(padIndex))
		end
	end)

	Remotes.event(Remotes.Names.StorePet).OnServerEvent:Connect(function(player, padIndex)
		if PlayerService.rateLimit(player, "place") then
			PetService.store(player, tonumber(padIndex))
		end
	end)

	Remotes.event(Remotes.Names.Collect).OnServerEvent:Connect(function(player)
		if PlayerService.rateLimit(player, "collect") then
			PetService.collect(player)
		end
	end)

	Remotes.event(Remotes.Names.Fuse).OnServerEvent:Connect(function(player, biomeId, petId, tier)
		if PlayerService.rateLimit(player, "fuse") then
			PetService.fuse(player, tostring(biomeId), tostring(petId), tonumber(tier) or 0)
		end
	end)

	-- Vault prompt on every plot.
	for _, plot in ipairs(PlotService.plots()) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect"
		prompt.ObjectText = "Vault"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.CollectRadius
		prompt.RequiresLineOfSight = false
		prompt.Parent = plot.vault

		prompt.Triggered:Connect(function(player)
			if PlotService.plotOf(player) ~= plot then
				PlayerService.notify(player, "That's not your vault.", "warn")
				return
			end
			if PlayerService.rateLimit(player, "collect") then
				PetService.collect(player)
			end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(Config.IncomeTickRate)
			local ok, err = pcall(tick)
			if not ok then
				warn("[PetService] income tick: " .. tostring(err))
			end
		end
	end)
end

return PetService
