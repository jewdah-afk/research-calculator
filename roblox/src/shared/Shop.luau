--!strict
-- Shop catalogue: game passes (permanent) and developer products (repeatable). Design + pricing rationale:
-- Obsidian "Peckwood/Shop design". `assetId` = the Creator Hub id; 0 until the owner creates it (Studio grants through
-- the dev path so everything is testable). Effects are applied server-side only (Game.shopMult / Game.speed / reach).
local Shop = {}

export type Item = { id: string, kind: "pass" | "product", name: string, desc: string, icon: string, robux: number,
	assetId: number, tag: string?, section: string, theme: string }

Shop.ITEMS = {
	-- hero: every pass in one purchase (sum 1,394 R$ -> 899 R$, ~35% off)
	{ id = "bundle", kind = "pass", section = "BUNDLE", name = "Ultimate Bundle", desc = "All 6 passes, forever", icon = "shop_bundle", robux = 899, assetId = 0, theme = "golden", grants = { "x2popcorn", "vip", "swift", "beak", "goldtouch", "angler" } },
	-- game passes
	{ id = "x2popcorn", kind = "pass", section = "GAME PASSES", name = "2x Eggs", desc = "Double eggs from every pickup, forever", icon = "shop_x2popcorn", robux = 249, assetId = 0, theme = "popcorn", tag = "POPULAR" },
	{ id = "vip", kind = "pass", section = "GAME PASSES", name = "Royal Birb", desc = "x1.5 every currency + crown tag", icon = "shop_vip", robux = 499, assetId = 0, theme = "golden", tag = "BEST" },
	{ id = "swift", kind = "pass", section = "GAME PASSES", name = "Swift Wings", desc = "+50% walk speed", icon = "shop_swift", robux = 99, assetId = 0, theme = "seagull" },
	{ id = "beak", kind = "pass", section = "GAME PASSES", name = "Big Beak", desc = "+50% pickup reach", icon = "shop_beak", robux = 149, assetId = 0, theme = "molt" },
	{ id = "goldtouch", kind = "pass", section = "GAME PASSES", name = "Golden Touch", desc = "x2 golden eggs", icon = "shop_goldtouch", robux = 199, assetId = 0, theme = "golden" },
	{ id = "angler", kind = "pass", section = "GAME PASSES", name = "Lucky Angler", desc = "x2 moneta from fishing", icon = "shop_angler", robux = 199, assetId = 0, theme = "rods" },
	-- boosts (stack time)
	{ id = "boost15", kind = "product", section = "BOOSTS", name = "2x Boost · 15 min", desc = "x2 every currency, stacks", icon = "shop_boost15", robux = 39, assetId = 0, theme = "echo", minutes = 15 },
	{ id = "boost60", kind = "product", section = "BOOSTS", name = "2x Boost · 1 hour", desc = "x2 every currency, stacks", icon = "shop_boost60", robux = 99, assetId = 0, theme = "echo", minutes = 60, tag = "BEST VALUE" },
	-- crates (scale with your production)
	{ id = "crateS", kind = "product", section = "CRATES", name = "Egg Crate", desc = "10 min of your eggs", icon = "shop_crateS", robux = 25, assetId = 0, theme = "popcorn", seconds = 600 },
	{ id = "crateM", kind = "product", section = "CRATES", name = "Big Crate", desc = "1 hour of your eggs", icon = "shop_crateM", robux = 79, assetId = 0, theme = "popcorn", seconds = 3600 },
	{ id = "crateL", kind = "product", section = "CRATES", name = "Mega Crate", desc = "8 hours of your eggs", icon = "shop_crateL", robux = 299, assetId = 0, theme = "golden", seconds = 28800, tag = "POPULAR" },
} :: { any }

Shop.BY_ID = {}
Shop.BY_ASSET = {}
for _, it in Shop.ITEMS do
	Shop.BY_ID[it.id] = it
	if it.assetId > 0 then Shop.BY_ASSET[it.assetId] = it end
end

-- bundle "was" price and SAVE tag come from the real pass prices, so they can never drift out of date
for _, it in Shop.ITEMS do
	if it.grants then
		local sum = 0
		for _, g in it.grants do sum += Shop.BY_ID[g].robux end
		it.was = sum
		it.tag = "SAVE " .. math.floor((sum - it.robux) / sum * 100 + 0.5) .. "%"
	end
end

-- multiplier for one currency from passes + an active boost (server state `s.shop`)
function Shop.mult(s: any, cur: string, now: number): number
	local sh = s.shop
	if not sh then return 1 end
	local p = sh.passes or {}
	if cur == "skillPoints" then return 1 end   -- progression gate: never boosted
	local m = 1
	if p.vip then m *= 1.5 end
	if (sh.boostUntil or 0) > now then m *= 2 end
	if cur == "popcorn" and p.x2popcorn then m *= 2 end
	if cur == "goldenPopcorn" and p.goldtouch then m *= 2 end
	if cur == "moneta" and p.angler then m *= 2 end
	return m
end

return Shop
