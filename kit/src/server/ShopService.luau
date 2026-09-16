--!nonstrict
--[[
	ShopService — upgrades, rebirth, game passes and developer products.

	Monetisation ids live in Config and default to 0. A 0 id simply means the
	feature is skipped, so the kit runs end-to-end before you have created
	anything on the Creator Dashboard.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local PlayerService = require(script.Parent:WaitForChild("PlayerService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local ShopService = {}

-- ------------------------------------------------------------- upgrades ----

function ShopService.buyUpgrade(player, key)
	local def = Config.Upgrades[key]
	local data = DataService.get(player)
	if not def or not data then
		return false
	end

	local level = data.upgrades[key] or 0
	if level >= def.max then
		PlayerService.notify(player, def.label .. " is maxed.", "warn")
		return false
	end

	local cost = Config.upgradeCost(key, level)
	if (data.coins or 0) < cost then
		PlayerService.notify(player, ("Need %s coins for %s."):format(Format.short(cost), def.label), "warn")
		return false
	end

	data.coins -= cost
	data.upgrades[key] = level + 1

	if key == "speed" then
		PlayerService.refreshSpeed(player)
	elseif key == "pads" then
		local plot = PlotService.plotOf(player)
		if plot then
			PlotService.setActivePads(plot, Economy.padCount(data))
		end
	end

	PlayerService.syncLeaderstats(player)
	PlayerService.notify(player, ("%s → level %d"):format(def.label, level + 1), "good")
	PlayerService.pushState(player)
	return true
end

-- -------------------------------------------------------------- rebirth ----

function ShopService.rebirth(player)
	local data = DataService.get(player)
	if not data then
		return false
	end

	local cost = Economy.rebirthCost(data)
	if (data.coins or 0) < cost then
		PlayerService.notify(player, ("Rebirth needs %s coins."):format(Format.short(cost)), "warn")
		return false
	end

	-- Take everything off the pads first so no model is orphaned.
	local plot = PlotService.plotOf(player)
	if plot then
		for index = 1, PlotService.MaxPads do
			if plot.pads[index].uid then
				PetService.store(player, index)
			end
		end
	end

	data.coins = 0
	data.vault = 0
	data.inventory = {}
	data.placed = {}
	data.locks = {}
	data.rebirths = (data.rebirths or 0) + 1

	if not Config.Rebirth.keepsUpgrades then
		for _, key in ipairs(Config.UpgradeOrder) do
			data.upgrades[key] = 0
		end
	end

	if plot then
		PlotService.setActivePads(plot, Economy.padCount(data))
	end
	PlayerService.refreshSpeed(player)
	PlayerService.syncLeaderstats(player)

	local bonus = math.floor(data.rebirths * Config.Rebirth.incomeBonus * 100)
	PlayerService.notify(player, ("Rebirth %d — permanent +%d%% income."):format(data.rebirths, bonus), "good")

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			PlayerService.notify(other, ("%s hit rebirth %d!"):format(player.DisplayName, data.rebirths), "info")
		end
	end

	PlayerService.pushState(player)
	return true
end

-- ---------------------------------------------------------- game passes ----

local function passOwned(player, passId)
	if passId == 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns
end

local function refreshPasses(player)
	for key, pass in pairs(Config.GamePasses) do
		player:SetAttribute("GP_" .. key, passOwned(player, pass.id))
	end
	PlayerService.refreshSpeed(player)
	PlayerService.pushState(player)
end

-- ----------------------------------------------------- developer products ---

local function grantProduct(player, data, productKey)
	local product = Config.Products[productKey]
	if not product then
		return false
	end

	if product.coins then
		PlayerService.addCoins(player, product.coins)
		PlayerService.notify(player, ("+%s coins!"):format(Format.short(product.coins)), "good")
	end
	if product.shield then
		data.shieldUntil = math.max(data.shieldUntil or 0, os.time()) + product.shield
		PlayerService.notify(player, ("Plot shielded for %s."):format(Format.duration(product.shield)), "good")
	end
	if product.luckSeconds then
		data.luckBoostUntil = math.max(data.luckBoostUntil or 0, os.time()) + product.luckSeconds
		PlayerService.notify(player, ("%dx luck for %s!")
			:format(product.luckMultiplier, Format.duration(product.luckSeconds)), "good")
	end

	PlayerService.pushState(player)
	return true
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Persistent dedup: a rejoin mid-purchase must not grant twice.
	data.receipts = data.receipts or {}
	if data.receipts[tostring(info.PurchaseId)] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key
	for productKey, product in pairs(Config.Products) do
		if product.id == info.ProductId and product.id ~= 0 then
			key = productKey
			break
		end
	end
	if not key then
		warn("[ShopService] unknown product id " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok = grantProduct(player, data, key)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.receipts[tostring(info.PurchaseId)] = true
	-- Save immediately so the grant survives a crash on the next tick.
	task.spawn(DataService.save, player, false)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.start()
	table.insert(PlayerService.profileReady, function(player)
		task.spawn(refreshPasses, player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			refreshPasses(player)
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	Remotes.event(Remotes.Names.BuyUpgrade).OnServerEvent:Connect(function(player, key)
		if type(key) == "string" and PlayerService.rateLimit(player, "buy") then
			ShopService.buyUpgrade(player, key)
		end
	end)

	Remotes.event(Remotes.Names.Rebirth).OnServerEvent:Connect(function(player)
		if PlayerService.rateLimit(player, "buy") then
			ShopService.rebirth(player)
		end
	end)
end

return ShopService
