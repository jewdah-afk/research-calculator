--!nonstrict
-- Shops and resets: the egg / keepsake / seed shops (Birb purchaseUpgrade / purchaseUpgradeMax), Molt (performRebirth)
-- and the sunflower tree (purchaseSunflowerUpgrade). Written fresh from the playtest (core.js PT.buy / PT.buySun,
-- systems.js PT.molt). Server only, pure Luau. Visibility gates (which rows a player can reach) live in Rules.rowVisible.
local function shared(name)
	if script then return require(game:GetService("ReplicatedStorage"):WaitForChild("Peckwood"):WaitForChild("Birb"):WaitForChild(name)) end
	return nil
end
local R = (shared("Rules") or require("../../shared/Birb/Rules")) :: any
local Park = (if script then require(script.Parent.Park) else require("./Park")) :: any
local EN = R.EN

local Shops = {}

-- one level (PT.buy); returns true when bought
function Shops.buy(s, id: string): boolean
	local def = R.Data.UP_BY_ID[id]
	if not def then return false end
	local L = R.level(s, id)
	if L >= R.maxLevel(s, id) then return false end
	if def.requires and R.level(s, def.requires.upgrade) < def.requires.level then return false end
	local c = R.discounted(s, def, L)
	if not R.has(s, def.costCurrency, c) then return false end
	if not R.freeSeeds(s, def.costCurrency) then R.sub(s, def.costCurrency, c) end
	s.upgrades[id] = L + 1
	return true
end
-- PT.buyMax: one level at a time until it can't (capped so a bad row can never spin the server)
function Shops.buyMax(s, id: string): number
	local n = 0
	while n < 10000 and Shops.buy(s, id) do n += 1 end
	return n
end

-- Molt (PT.molt): eggs and the P tree reset, plumes paid. Returns the plumes (EN) or nil.
function Shops.molt(s, rt)
	local final = R.prestige(s)
	if EN.le(final, 1) then return nil end
	s.popcorn = EN.ZERO
	if rt then Park.clearField(rt) end
	for _, def in R.Data.UP do
		if def.tree == "P" and not def.permanent then s.upgrades[def.id] = nil end
	end
	local paid = Park.give(s, "goldenFeathers", final)
	Park.gain(rt or { gainAcc = {} }, "goldenFeathers", paid)
	s.rebirbCount = (s.rebirbCount or 0) + 1
	return paid
end

-- currencies a tree node can cost besides the wallet (PT.altCurrency)
local ALT = {
	strange_key = {
		has = function(s, c) return R.hooks.strangeKeys(s) >= c end,
		sub = function(s, c) s.parrot.strangeKeys = (s.parrot.strangeKeys or 0) - c end,
	},
}
Shops.ALT = ALT
-- PT.buySun: "" on success, else the reason ("owned", "locked", "not enough", "needs <currency>", "unknown")
function Shops.buySun(s, id: string): string
	local n = R.Data.SUN_BY_ID[id]
	if not n then return "unknown" end
	local L = R.sunLevel(s, id)
	if L >= (n.maxLevel or 1) then return "owned" end
	local ps = n.parents
	if #ps > 0 then
		local ok
		if n.needsAll then
			ok = true
			for _, p in ps do if not R.hasSun(s, p) then ok = false; break end end
		else
			ok = false
			for _, p in ps do if R.hasSun(s, p) then ok = true; break end end
		end
		if not ok then return "locked" end
	end
	if not R.sunUnlocked(s, id) then return "locked" end
	local cur, c = n.costCurrency, R.sunCost(s, id)
	if cur == "totalFishCaught" then
		if (s.stats.fishCaught or 0) < c then return "not enough" end
	elseif ALT[cur] then
		if not ALT[cur].has(s, c) then return "not enough" end
		ALT[cur].sub(s, c)
	elseif not R.WALLET[R.wkey(cur)] then
		return "needs " .. cur   -- fish, gold ore, aura, books: their phases add them
	else
		if not R.has(s, cur, c) then return "not enough" end
		if not R.freeSeeds(s, cur) then R.sub(s, cur, c) end
	end
	s.sunflowerUpgrades[id] = L + 1
	if id == "d_unlock_evolve" then s.hasUnlockedEvolve = true end
	if id == "d_unlock_desert_tree" then s.hasUnlockedDesertMap = true end
	return ""
end

return Shops
