--[[
	Game passes and developer products.

	Passes: ownership is checked once at join (UserOwnsGamePassAsync) and updated when a purchase finishes.
	Products: ProcessReceipt is idempotent. Each receipt id is recorded in the buyer's profile before the
	purchase is reported granted, so a retried receipt is never applied twice.
	  * In-match products (Supply Drop, Extra Life, Second Chance, Airstrike, Time Freeze) apply to the buyer's
	    current Onslaught+ match. If they can't apply any more (the run ended in between), they become a credit
	    the player can spend in a later run, so nobody pays for nothing.
	  * Account products (Intel, XP Boost, Quest Reroll, Party Boost) change the profile.
	The client asks before prompting (MatchService checks canUseProduct), so most purchases apply at once.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local XD = require(ReplicatedStorage.Shared.Onslaught.ExpansionData)
local Profiles = require(script.Parent.Profiles)

local Monetization = {}

local owned: { [Player]: { [string]: boolean } } = {}
local passByAsset, productByAsset = {}, {}
for key, id in Config.PASS_IDS do
	if id ~= 0 then
		passByAsset[id] = key
	end
end
for key, id in Config.PRODUCT_IDS do
	if id ~= 0 then
		productByAsset[id] = key
	end
end
local PRODUCT = {}
for _, p in XD.products do
	PRODUCT[p.id] = p
end
local PASS = {}
for _, p in XD.gamepasses do
	PASS[p.id] = p
end
Monetization.PASS, Monetization.PRODUCT = PASS, PRODUCT

-- Hooks MatchService fills in: where an in-match product goes, and who wants to know about pass changes.
Monetization.applyInMatch = function(_player: Player, _id: string, _arg: any): boolean
	return false
end
Monetization.onPassesChanged = function(_player: Player, _passes) end
Monetization.partyBoostUntil = 0 -- Party Boost: x2 Intel for everyone in this server

local IN_MATCH = { drop_s = true, drop_m = true, drop_l = true, life = true, revive = true, airstrike = true, freeze = true }
Monetization.IN_MATCH = IN_MATCH
local pendingArg: { [Player]: any } = {} -- e.g. the Airstrike target, set just before the prompt

-- ================================================================ passes
function Monetization.passes(player: Player)
	return owned[player] or {}
end
function Monetization.loadPasses(player: Player)
	local set = {}
	for key, id in Config.PASS_IDS do
		if RunService:IsStudio() and Config.STUDIO_OWNS_ALL_PASSES then
			set[key] = true
		elseif id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			set[key] = ok and has or false
		end
	end
	owned[player] = set
	Monetization.onPassesChanged(player, set)
	return set
end
function Monetization.promptPass(player: Player, key: string)
	local id = Config.PASS_IDS[key]
	if not id or id == 0 then
		return false, "This pass isn't on sale yet."
	end
	MarketplaceService:PromptGamePassPurchase(player, id)
	return true
end

-- ================================================================ products
-- Second Chance is three products (99, 199, 399 R$), one per use within a run.
local function reviveProduct(revives: number)
	return if revives <= 0 then "revive" elseif revives == 1 then "revive_2" else "revive_3"
end
Monetization.reviveProduct = reviveProduct

function Monetization.promptProduct(player: Player, key: string, arg: any)
	local id = Config.PRODUCT_IDS[key]
	if not id or id == 0 then
		return false, "This item isn't on sale yet."
	end
	pendingArg[player] = arg
	MarketplaceService:PromptProductPurchase(player, id)
	return true
end

-- Apply one unit of a product. Returns how it was delivered: "match", "credit" or "profile".
local function deliver(player: Player, key: string, arg: any)
	local base = if string.sub(key, 1, 6) == "revive" then "revive" else key
	if IN_MATCH[base] then
		if Monetization.applyInMatch(player, base, arg) then
			return "match"
		end
		Profiles.update(player, function(p)
			p.credits[base] = (p.credits[base] or 0) + 1
		end)
		return "credit"
	end
	local def = PRODUCT[base]
	Profiles.update(player, function(p)
		if def and def.intel then
			p.intel += def.intel
		elseif base == "xpboost" then
			p.xpBoostUntil = math.max(p.xpBoostUntil or 0, os.time() * 1000) + 3600 * 1000
		elseif base == "reroll" then
			p.rerolls += 1
		end
	end)
	if base == "partyboost" then
		Monetization.partyBoostUntil = math.max(Monetization.partyBoostUntil, os.time()) + 30 * 60
	end
	return "profile"
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local key = productByAsset[receipt.ProductId]
	if not key then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = player and Profiles.get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they're next in a server
	end
	if profile.purchases[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already applied (a retry)
	end
	local how = deliver(player, key, pendingArg[player])
	pendingArg[player] = nil
	Profiles.update(player, function(p)
		p.purchases[receipt.PurchaseId] = os.time()
	end)
	-- Make it durable before telling Roblox it's done. If the save fails, the in-memory receipt record still
	-- stops a retry in this server from applying it twice, and the next autosave writes it.
	if not Profiles.save(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Monetization.notify(player, how, key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
Monetization.notify = function(_player: Player, _how: string, _key: string) end

function Monetization.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passByAsset[passId]
		if purchased and key then
			owned[player] = owned[player] or {}
			owned[player][key] = true
			Monetization.onPassesChanged(player, owned[player])
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		pendingArg[player] = nil
	end)
end

-- What the store shows: every pass and product with price, effect and whether it's on sale.
function Monetization.catalog(player: Player)
	local passes, products = {}, {}
	local mine = Monetization.passes(player)
	for _, p in XD.gamepasses do
		table.insert(passes, {
			id = p.id, name = p.name, robux = p.robux, effect = p.effect, classic = p.classic,
			owned = mine[p.id] == true, onSale = (Config.PASS_IDS[p.id] or 0) ~= 0,
		})
	end
	for _, p in XD.products do
		table.insert(products, {
			id = p.id, name = p.name, robux = p.robux, effect = p.effect, plusOnly = p.plusOnly,
			onSale = (Config.PRODUCT_IDS[p.id] or 0) ~= 0,
		})
	end
	return { passes = passes, products = products }
end

return Monetization
