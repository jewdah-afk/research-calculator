-- Account rules: mode locks, end-of-game rewards, unlocks, quests, rerolls. lune run test/unit/rules_test.luau
local process = require("@lune/process")
local Rules = require("../../src/shared/Rules")
local GAME = require("../../src/shared/Onslaught/Data")
local EN = require("../../src/shared/Onslaught/EternityNum")

local passes, fails = 0, 0
local function ok(c, msg)
	if c then
		passes += 1
	else
		fails += 1
		print("FAIL: " .. msg)
	end
end
local function profile()
	return {
		level = 1, xp = 0, intel = 0, prestige = 0, research = {}, lifetimeXP = "0", lifetimeKills = "0", lifetimeBounty = "0",
		kills = { normal = 0 }, unlocks = {}, best = {}, chal = {}, rerolls = 0, xpBoostUntil = 0,
	}
end
local p = profile()
ok(Rules.modeOpen(p, {}, "medium") and not Rules.modeOpen(p, {}, "extreme"), "extreme locked by default")
ok(Rules.modeOpen(p, { clearance = true }, "sandbox2"), "Instant Clearance opens everything")
ok(Rules.validSettings(GAME, p, {}, { mode = "medium", map = "map3" }), "valid settings")
ok(not Rules.validSettings(GAME, p, {}, { mode = "extreme", map = "map3" }), "locked mode refused")
ok(not Rules.validSettings(GAME, p, {}, { mode = "medium", map = "tutorial" }), "tutorial map refused")
ok(not Rules.validSettings(GAME, p, {}, { mode = "medium", map = "nope" }), "unknown map refused")
ok(Rules.validSettings(GAME, p, {}, { challengeIndex = 6, map = "map1" }), "challenge accepted")

Rules.dailyQuestsFor(p, 1760313600)
local s = Rules.applyGameEnd(p, {}, {
	settings = { mode = "medium", map = "map1" }, wave = 40, kills = 2100, myKills = 2100, myEarned = 123456.5, won = false,
	lives = 10, startLives = 10, combos = 12, comboCounts = { nuke = 4 }, turretKills = { { kind = "Red", kills = 900 } }, nowMs = 0,
})
ok(p.unlocks.extreme and table.find(s.unlocked, "Extreme"), "2000 kills unlocks Extreme")
ok(p.best["classic:medium:map1"] == 40 and s.newBest, "best wave stored")
ok(s.xp > 0 and s.intel > 0 and p.level > 1, "xp and intel granted (" .. s.xp .. " xp, " .. s.intel .. " intel)")
ok(EN.toNumber(EN.fromSave(p.lifetimeKills)) == 2100, "lifetime kills as EternityNum")
ok(EN.toNumber(EN.fromSave(p.lifetimeBounty)) == 123456, "lifetime bounty")
ok(#s.quests >= 1, "some quests completed (" .. table.concat(s.quests, "; ") .. ")")
local s2 = Rules.applyGameEnd(p, {}, { settings = { mode = "medium", map = "map1", plus = true }, wave = 10, kills = 5000, myKills = 10, won = false, lives = 1, startLives = 10, nowMs = 0 })
ok(not p.unlocks.sandbox, "Onslaught+ runs don't unlock the original's modes")
ok(p.best["plus:medium:map1"] == 10 and s2.newBest, "plus best kept separately")
ok(EN.toNumber(EN.fromSave(p.lifetimeKills)) == 2110, "lifetime kills add up")
local big = profile()
big.lifetimeKills = EN.toString(EN.fromString("1e400"))
Rules.applyGameEnd(big, {}, { settings = { mode = "easy", map = "map1" }, wave = 1, kills = 1, myKills = 1, lives = 10, startLives = 10, nowMs = 0 })
ok(EN.short(EN.fromSave(big.lifetimeKills)) ~= "Inf", "totals keep going past doubles (" .. EN.short(EN.fromSave(big.lifetimeKills)) .. ")")
-- rerolls
local q = profile()
local before = Rules.dailyQuestsFor(q, 1760313600).list[1].id
ok(not Rules.rerollQuest(q, {}, 1, 1760313600), "no reroll without a credit")
ok(Rules.rerollQuest(q, { vip = true }, 1, 1760313600) and q.quests.list[1].id ~= before, "VIP free reroll swaps the quest")
ok(not Rules.rerollQuest(q, { vip = true }, 2, 1760313600), "only one free VIP reroll a day")
q.rerolls = 1
ok(Rules.rerollQuest(q, {}, 2, 1760313600) and q.rerolls == 0, "bought reroll is spent")
local ids = {}
for _, it in q.quests.list do
	ok(not ids[it.id], "no duplicate quests after rerolls")
	ids[it.id] = true
end
print(string.format("rules: %d passed, %d failed", passes, fails))
process.exit(if fails > 0 then 1 else 0)
