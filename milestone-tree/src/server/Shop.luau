--!strict
--[[
	Shop: game passes and developer products on the server (shared/Products lists them).

	    Shop.start(actorOf)   actorOf(player) -> the player's worker Actor while they play, else nil
	    Shop.refresh(player)  read the player's passes again (on join, after a purchase)

	Passes -> perks: the player's Actor gets ("perks", { speed = 2? }) and the player's MT_Perks attribute holds the
	owned pass keys as JSON (the client's Shop and the SUPPORTER tag read it). A pass bought in game counts at once
	(PromptGamePassPurchaseFinished); ownership is read again on every join.

	Products -> ProcessReceipt: a Time Warp goes to the player's Actor ("warp", seconds, name). A receipt is granted
	once: Store.receiptGranted / markReceipt. The answer is NotProcessedYet (Roblox retries later, also on the
	player's next join) while the player has no running game or the grant could not be recorded. In Studio without
	DataStores a test purchase is granted without the record.
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Store = require(script.Parent:WaitForChild("Store"))
local Products = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Products"))

local Shop = {}

local actorOf: (Player) -> Actor? = function() return nil end
local owned: { [Player]: { [string]: boolean } } = {}

local function perksOf(set: { [string]: boolean }): { [string]: any }
	local perks: { [string]: any } = {}
	for _, p in Products.passes do
		if set[p.key] and p.speed then perks.speed = math.max(perks.speed or 1, p.speed) end
	end
	return perks
end

local function push(player: Player)
	local set: { [string]: boolean } = owned[player] or {}
	local keys = {}
	for k, v in set do
		if v then table.insert(keys, k) end
	end
	table.sort(keys)
	player:SetAttribute("MT_Perks", HttpService:JSONEncode(keys))
	local a = actorOf(player)
	if a then a:SendMessage("perks", perksOf(set)) end
end

function Shop.refresh(player: Player)
	local set = owned[player] or {}
	for _, p in Products.passes do
		local id = p.id
		if id and not set[p.key] then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and has then set[p.key] = true end
		end
	end
	-- the pass checks yield: a player who left meanwhile is not stored again (PlayerRemoving already cleared them)
	if player.Parent then
		owned[player] = set
		push(player)
	end
end

-- a developer product purchase: grant it once
local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local product = Products.productById(info.ProductId)
	if product == nil then
		warn("[MilestoneTree] a receipt for an unknown product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local a = if player then actorOf(player) else nil
	-- only a game that has loaded and can save keeps a warp (Worker sets CanGrant); else Roblox retries later
	if player == nil or a == nil or a:GetAttribute("CanGrant") ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local done, err = Store.receiptGranted(purchaseId)
	local studio = RunService:IsStudio() and not Store.available()
	if done == nil and not studio then
		warn("[MilestoneTree] could not check receipt " .. purchaseId .. ": " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if done then return Enum.ProductPurchaseDecision.PurchaseGranted end
	if not studio then
		local ok, e = Store.markReceipt(purchaseId, info.PlayerId, info.ProductId)
		if not ok then
			warn("[MilestoneTree] could not record receipt " .. purchaseId .. ": " .. tostring(e))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	if product.warp then a:SendMessage("warp", product.warp, product.name) end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.start(of: (Player) -> Actor?)
	actorOf = of
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then return end
		local p = Products.passById(passId)
		if p == nil then return end
		local set = owned[player] or {}
		set[p.key] = true
		owned[player] = set
		push(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		owned[player] = nil
	end)
end

return Shop
