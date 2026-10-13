-- Onslaught+ checks (Luau mirror of onslaught-html/test/expansion_test.js). lune run test/expansion_test.luau
local process = require("@lune/process")
local E = require("../src/shared/Onslaught/Engine")
local X = require("../src/shared/Onslaught/Expansion")
local GAME = require("../src/shared/Onslaught/Data")

local passes, fails = 0, 0
local function ok(c, msg)
	if c then
		passes += 1
	else
		fails += 1
		print("FAIL: " .. msg)
	end
end
local maxed = { level = 99, research = {}, passes = {} }
local function plus(o, L)
	L = L or maxed
	local opts = { map = "map1", mode = "sandbox", seed = 9, players = { "p1" } }
	for k, v in o or {} do
		opts[k] = v
	end
	return E.newGame(X.data(GAME, L), X.gameOpts(opts, { p1 = L }))
end

do -- data merge and level locks
	local G = plus({}, { level = 1, research = {}, passes = {} })
	ok(G.D.turrets.Orange ~= nil and table.find(G.D.buildOrder, "Orbital") ~= nil, "expansion towers merged")
	ok(not G.unlocked.Orange and G.D.turrets.Orange.levelLocked == 2, "Orange is level-locked at level 1")
	local H = plus({}, { level = 1, research = {}, passes = { arsenal = true } })
	ok(H.unlocked.Orange and H.D.turrets.Beacon.unlock == 900, "Arsenal Pass: no level locks, Beacon at 900 kills")
	ok(GAME.turrets.Orange == nil, "classic data untouched")
end
do -- vault
	local G = plus()
	ok(E.build(G, "p1", "Vault", 150, 290) ~= nil, "build vault")
	G.players.p1.cash = 10000
	E.waveSend(G)
	ok(G.players.p1.cash == 10060, "vault pays min(cap 60, 2% of 10,000) = 60 (" .. G.players.p1.cash .. ")")
	E.build(G, "p1", "Vault", 230, 290)
	E.build(G, "p1", "Vault", 310, 290)
	ok(E.build(G, "p1", "Vault", 390, 290) == nil, "max 3 vaults per player")
end
do -- cryo ignores damage modifiers
	local G = plus()
	local c = E.build(G, "p1", "Cyan", 150, 335)
	E.upgrade(G, "p1", c.id, "damage", true)
	ok(c.eff.damage == 2, "cryo strength 2 at max")
	E.build(G, "p1", "DamageUp", 150, 285)
	ok(c.eff.damage == 2, "damage enhancer doesn't boost cryo strength")
end
do -- beacon and research change combos
	local G = plus({}, { level = 99, research = { theory = 10 }, passes = { combomaster = true } })
	local r = E.build(G, "p1", "Red", 150, 345)
	E.upgrade(G, "p1", r.id, "damage", true)
	E.build(G, "p1", "Beacon", 150, 290)
	local m = G.mods.rechargeMult(G, r)
	ok(math.abs(m - (1 - 0.15) * 0.85 * 0.75) < 1e-9, "recharge = theory x combo master x beacon (" .. m .. ")")
	ok(G.mods.comboDamage(G, r) == 1.2, "beacon +20% combo damage")
end
do -- research and passes on economy
	local L = { level = 30, research = { funds = 10, salvage = 10, bunker = 5, bounty = 10 }, passes = { supply = true } }
	local G = plus({ mode = "medium" }, L)
	ok(G.players.p1.cash == 30 + 50 + 50, "starting cash 30 + research 50 + supply 50")
	ok(G.lives == 15, "bunker +5 lives")
	local b = E.build(G, "p1", "Blue", 150, 330)
	ok(E.sell(G, "p1", b.id) == 8, "salvage 80% resale: ceil(10*0.8) = 8")
	ok(math.abs(G.mods.bounty(G, 10) - 12) < 1e-9, "bounty +10% research +10% supply")
end
do -- products
	local G = plus({ mode = "medium" })
	G.waveNum = 20
	local c0 = G.players.p1.cash
	X.useProduct(G, "drop_m", "p1")
	ok(G.players.p1.cash - c0 == 3000, "supply drop M = 10 x wave 20 x 15")
	for _ = 1, 5 do
		X.useProduct(G, "life", "p1")
	end
	ok(G.lives == 15 and not X.useProduct(G, "life", "p1"), "extra lives capped at 5 per game")
	ok(not X.canUseProduct(G, "life"), "canUseProduct refuses a 6th life before purchase")
	G.lives, G.lost, G.over = 1, true, true
	ok(X.canUseProduct(G, "revive") and not X.canUseProduct(G, "drop_s"), "only revive is offered after game over")
	ok(X.useProduct(G, "revive", "p1") and G.lives == 5 and not G.over, "second chance revives with 5 lives")
	ok(X.revivePrice(G) == 199, "revive price doubles (" .. X.revivePrice(G) .. ")")
	ok(G.assisted, "products mark the run assisted")
end
do -- progression maths (same numbers as the JS suite)
	ok(X.xpToNext(1) == 140, "level 1 -> 2 needs 140 XP")
	local meta = { level = 1, xp = 0, passes = {} }
	local G = { waveNum = 40, kills = 400, mode = "medium", challenge = nil, won = false }
	local r = X.gameRewards(G, meta, 0)
	ok(r.xp == E.jsRound(820 * 1.3 * 0.1 + 80), "medium wave 40 = 107 + 80 XP (" .. r.xp .. ")")
	ok(r.intel == math.floor(40 ^ 1.4 * 1.3 / 4 + 20), "intel formula (" .. r.intel .. ")")
	local ups = X.addXP(meta, 1000)
	ok(meta.level >= 4 and ups >= 3, "1000 XP from level 1 reaches level " .. meta.level)
	ok(X.researchCost("funds", 0) == 40 and X.researchCost("funds", 10) == nil, "research costs and caps")
	ok(X.gameRewards({ waveNum = 50, kills = 500, mode = "sandbox" }, meta, 0).xp == 0, "sandbox gives no XP")
	local m2 = { intel = 100, research = {} }
	ok(X.buyResearch(m2, "funds") and m2.intel == 60 and m2.research.funds == 1, "buy research spends intel")
	local q = X.dailyQuests({}, "2026-10-13")
	ok(#q.list == 3 and q.list[1].id ~= q.list[2].id, "3 distinct daily quests")
end
do -- JS and Luau agree on the meta formulas (the server is Luau, the HTML preview is JS)
	local expect = process.args[1]
	if expect then
		local got = {}
		for l = 1, 60 do
			table.insert(got, X.xpToNext(l))
		end
		for _, r in X.XD.research do
			for l = 0, r.max - 1 do
				table.insert(got, X.researchCost(r.id, l))
			end
		end
		for _, d in { "2026-01-01", "2026-10-13", "2027-02-28" } do
			for _, it in X.dailyQuests({}, d).list do
				table.insert(got, it.id)
			end
		end
		ok(table.concat(got, ",") == expect, "meta formulas match the JS")
	end
end
print(string.format("%d passed, %d failed", passes, fails))
process.exit(if fails > 0 then 1 else 0)
