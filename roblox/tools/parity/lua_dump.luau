--!nonstrict
-- Lua side of the Peckwood parity harness (lune). Loads Game.luau and the Birb systems straight from roblox/src,
-- maps each scenario's Birb save into Peckwood's save (fromBirb below: the documented mapping), computes the same
-- keys playtest_dump.js writes for every value Phase 1 owns, runs the same action programs through Game.stepPhase1
-- and writes out/lua.json. Keys the Lua side does not produce yet (later phases) are simply absent.
-- Run from roblox/:  lune run tools/parity/lua_dump.luau
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local G = require("../../src/server/Game")
local R, Park, Sparrow, Shops = G.R, G.Park, G.Sparrow, G.Shops
local EN = R.EN
local D = R.Data

local HERE = string.match(debug.info(1, "s"), "^(.*)[\\/]")
local OUT = HERE .. "/out"
local CFG = serde.decode("json", fs.readFile(OUT .. "/scenarios.json"))
local ONLY = (require("@lune/process") :: any).env.ONLY

-- Park-Miller LCG, twin of headless.js lcg(): every product stays below 2^53, so the doubles match bit for bit
local function lcg(seed: number)
	local x = math.max(1, math.floor(seed) % 2147483647)
	return function()
		x = (x * 48271) % 2147483647
		return x / 2147483647
	end
end

-- big values: plain numbers while they fit a double, else { L = log10, s = sign } (playtest_dump.js big())
local function big(x)
	if type(x) == "number" then return x end
	local n = EN.toNumber(x)
	if n == n and n ~= math.huge and n ~= -math.huge then return n end
	return { L = EN.toNumber(EN.log10(EN.abs(x))), s = x[1] }
end

-- ---------------------------------------------------------------- Birb save -> Peckwood v3 save (the mapping)
-- resources.<cur>            -> s.<cur> (EN); monetariaMoneta -> s.moneta; non-wallet currencies (wood ...) are dropped
-- upgrades / sunflowerUpgrades -> s.upgrades / s.sunflowerUpgrades (same id -> level maps)
-- rebirthCount -> s.rebirbCount; evolutionCount; playTime -> s.stats.playTime; totalFishCaught -> s.stats.fishCaught;
-- totalPopcornCollected -> s.stats.totalPopcorn
-- sparrow.{unlocked, level, xp, maxLevelReached} -> s.sparrow.*; sparrowCount -> s.sparrow.count;
-- sparrowPrestigeCount -> prestigeCount; sparrowResonanceXP -> resonanceXP; sparrowTotalEnergyDrained -> totalEnergyDrained;
-- sparrowSeedFeedRatePercent -> feedRatePercent; isFeedingSparrow / isDrainingSparrow -> feeding / draining;
-- sparrowAutoMitosisEnabled / sparrowAutoRebirbEnabled -> autoMitosis / autoRebirb
-- monster{Popcorn,Feathers,Seeds,Fish,Twigs,Moneta}Fed -> s.evo.fed.{popcorn,feathers,seeds,fish,twigs,moneta};
-- monsterFeedProgress -> s.evo.progress; hasTalkedToMonster -> s.evo.talked
-- hasUnlockedEvolve / hasEnteredDungeon / hasUnlockedDesertMap -> same names
-- nest.tier -> s.nest.tier; mine.highestArea -> s.crow.area; parrot.rebirbCount / strangeKeys -> s.parrot.*;
-- expedition.hasRescuedCastleMonster -> s.expedition.hasRescuedCastleMonster
local function copy(t) local o = {}; for k, v in t or {} do o[k] = v end; return o end
local function fromBirb(st)
	local s = G.fresh()
	for k, v in st.resources or {} do
		local wk = R.wkey(k)
		if R.WALLET[wk] then s[wk] = EN.fromNumber(v) end
	end
	s.upgrades = copy(st.upgrades)
	s.sunflowerUpgrades = copy(st.sunflowerUpgrades)
	s.rebirbCount = st.rebirthCount or 0
	s.evolutionCount = st.evolutionCount or 0
	s.stats.playTime = st.playTime or 0
	s.stats.fishCaught = st.totalFishCaught or 0
	s.stats.totalPopcorn = st.totalPopcornCollected or 0
	s.hasUnlockedEvolve = st.hasUnlockedEvolve == true
	s.hasEnteredDungeon = st.hasEnteredDungeon == true
	s.hasUnlockedDesertMap = st.hasUnlockedDesertMap == true
	local sp = s.sparrow
	local b = st.sparrow or {}
	if b.unlocked ~= nil then sp.unlocked = b.unlocked end
	if b.level ~= nil then sp.level = b.level end
	if b.xp ~= nil then sp.xp = b.xp end
	if b.maxLevelReached ~= nil then sp.maxLevelReached = b.maxLevelReached end
	sp.count = st.sparrowCount or 1
	sp.prestigeCount = st.sparrowPrestigeCount or 0
	sp.resonanceXP = st.sparrowResonanceXP or 0
	sp.totalEnergyDrained = st.sparrowTotalEnergyDrained or 0
	sp.feedRatePercent = st.sparrowSeedFeedRatePercent or 25
	sp.feeding = st.isFeedingSparrow == true
	sp.draining = st.isDrainingSparrow == true
	sp.autoMitosis = st.sparrowAutoMitosisEnabled == true
	sp.autoRebirb = st.sparrowAutoRebirbEnabled == true
	local f = s.evo.fed
	f.popcorn, f.feathers, f.seeds = st.monsterPopcornFed or 0, st.monsterFeathersFed or 0, st.monsterSeedsFed or 0
	f.fish, f.twigs, f.moneta = st.monsterFishFed or 0, st.monsterTwigsFed or 0, st.monsterMonetaFed or 0
	s.evo.progress = st.monsterFeedProgress or 0
	s.evo.talked = st.hasTalkedToMonster == true
	s.nest.tier = (st.nest and st.nest.tier) or 0
	s.crow.area = math.floor((st.mine and st.mine.highestArea) or 0)
	s.parrot.rebirbCount = (st.parrot and st.parrot.rebirbCount) or 0
	s.parrot.strangeKeys = (st.parrot and st.parrot.strangeKeys) or 0
	s.expedition = { hasRescuedCastleMonster = st.expedition ~= nil and st.expedition.hasRescuedCastleMonster == true }
	return s
end

-- ---------------------------------------------------------------- values
local TYPES, ROLL_U, MILESTONES, EVO_KEYS = CFG.types, CFG.rollU, CFG.milestones, CFG.evoKeys
local function typeIndex(t) for i, x in TYPES do if x == t then return i - 1 end end; return -1 end
local ALL_UP = { "p_golden_popcorn_value", "p_auric_silo", "p_value", "p_speed", "p_capacity", "p_move_speed", "pr_golden_popcorn_mult", "pr_popcorn_mult",
	"pr_radius_mult", "pr_respawn_mult", "s_more_popcorn", "s_more_feathers", "s_more_seeds", "m_ore_value", "m_mining_power", "m_rupture", "m_charged_strike" }
local MILESTONE_BY = {}
for _, m in R.SPARROW_MILESTONES do MILESTONE_BY[m.id] = m end

local function probeValues(s, sc, put)
	for _, id in ALL_UP do
		put("upgrade " .. id .. " level", function() return R.level(s, id) end)
		put("upgrade " .. id .. " max", function() return R.maxLevel(s, id) end)
		put("upgrade " .. id .. " effect", function() return R.effect(s, id) end)
		if id:sub(1, 2) ~= "m_" then put("upgrade " .. id .. " cost", function() return R.discounted(s, D.UP_BY_ID[id], R.level(s, id)) end) end
	end
	put("egg cap", function() return R.maxPopcorn(s) end)
	put("spawn interval", function() return R.spawnInterval(s) end)
	put("total multiplier", function() return R.totalMultiplier(s) end)
	put("molt plumes", function() return (R.prestige(s)) end)
	put("playtime mult", function() return R.playtimeMult(s) end)
	put("molt payout mult", function() return R.prestigePayoutMult(s) end)
	put("pickup radius", function() return R.pickupProfile(s).collectRadius end)
	put("can evolve", function() return R.canEvolveStage(s) end)
	for _, L in { 1, 2, 10, 50 } do put("sparrow xp needed L" .. L, function() return R.sparrowXpNeeded(L) end) end
	for _, st in D.STATIONS do
		if st.id:sub(1, 2) ~= "__" then
			put("tree " .. st.id .. " unlocked", function() return R.sunUnlocked(s, st.id) end)
			put("tree " .. st.id .. " visible", function() return R.sunVisible(s, st.id) end)
			put("tree " .. st.id .. " cost", function() return R.sunCost(s, st.id) end)
		end
	end
	if sc.echo then
		for _, st in D.ARCHIVIST_STATIONS do
			put("tree " .. st.id .. " unlocked", function() return R.sunUnlocked(s, st.id) end)
			put("tree " .. st.id .. " visible", function() return R.sunVisible(s, st.id) end)
			put("tree " .. st.id .. " cost", function() return R.sunCost(s, st.id) end)
		end
		put("tree d_unlock_archivist_tree unlocked", function() return R.sunUnlocked(s, "d_unlock_archivist_tree") end)
		put("tree d_unlock_archivist_tree visible", function() return R.sunVisible(s, "d_unlock_archivist_tree") end)
	end
end

local function p1Values(s, rt, put)
	for _, u in ROLL_U do put("p1 roll u=" .. (if u == math.floor(u) then string.format("%d", u) else tostring(u)), function() return typeIndex(R.rollType(s, u)) end) end
	local prof = R.pickupProfile(s)
	put("p1 collect radius", function() return prof.collectRadius end)
	put("p1 magnet radius", function() return prof.magnetRadius end)
	put("p1 magnet speed", function() return prof.magnetSpeed end)
	put("p1 gravity radius", function() return R.legacyRadius(s) end)
	put("p1 collection mult", function() return R.collectionMultiplier(s) end)
	put("p1 max speed", function() return R.maxSpeed(s) end)
	for _, t in TYPES do
		for _, who in { "player", "sparrow" } do
			local pop, tot, xp = s.popcorn, s.stats.totalPopcorn, s.sparrow.xp
			s.popcorn = EN.ZERO; s.sparrow.xp = 0
			local ok, err = pcall(Park.award, s, rt, { id = 0, type = t, x = 0, y = 0 }, who)
			put("p1 award " .. who .. " " .. t, function() if not ok then error(err) end; return s.popcorn end)
			if who == "sparrow" then put("p1 award sparrow xp " .. t, function() return s.sparrow.xp end) end
			s.popcorn, s.stats.totalPopcorn, s.sparrow.xp = pop, tot, xp
			table.clear(rt.gainAcc)
		end
	end
	for _, plat in { true, false } do
		local tps, per = R.seedRate(s, plat)
		local tag = if plat then "platform" else "away"
		put("p1 seed ticks " .. tag, function() return tps end)
		put("p1 seed per tick " .. tag, function() return per end)
	end
	local _, base, a, pay = R.prestige(s)
	put("p1 molt base", function() return base end)
	put("p1 molt a", function() return a end)
	put("p1 molt pay", function() return pay end)
	put("p1 sparrow speed", function() return R.sparrowSpeed(s) end)
	put("p1 sparrow drain mult", function() return R.sparrowDrainMult(s) end)
	put("p1 sparrow rebirb boost", function() return R.sparrowRebirbBoost(s) end)
	put("p1 sparrow seed feed xp", function() return R.seedFeedXp(s) end)
	put("p1 sparrow mitosis count", function() return R.mitosisCount(s) end)
	put("p1 sparrow rebirb ready", function() return R.sparrowRebirbReady(s) end)
	put("p1 sparrow total xp", function() return R.sparrowTotalXp(s.sparrow.level, s.sparrow.xp) end)
	for _, c in { 1, 2, 4, 8, 16 } do put("p1 sparrow mitosis need c" .. c, function() return R.mitosisNeed(s, c) end) end
	for _, id in MILESTONES do put("p1 sparrow milestone " .. id, function() return R.milestoneMet(s, MILESTONE_BY[id]) end) end
	local req = R.evoReq(s.evolutionCount)
	for _, k in EVO_KEYS do put("p1 evo req " .. k, function() return req[k] end) end
	put("p1 feed progress", function() return R.feedProgress(s) end)
	put("p1 evo cap", function() return R.evoCap(s) end)
end

-- ---------------------------------------------------------------- simulated runs (same ops as playtest_dump.js)
local SIM_DT = CFG.simDt
local REASON = { [""] = 0, owned = 1, locked = 2, ["not enough"] = 3 }
local function isDesertNode(id) return id:sub(1, 9) == "d_desert_" or id == "d_unlock_archivist_tree" end
local function snap(s, rt, tag, put, last)
	local P = "sim " .. tag .. " "
	for _, k in { "popcorn", "goldenFeathers", "sunflowerSeeds", "moneta", "twigs" } do put(P .. "wallet " .. k, function() return s[k] end) end
	put(P .. "playTime", function() return s.stats.playTime end)
	put(P .. "totalPopcorn", function() return s.stats.totalPopcorn end)
	put(P .. "rebirths", function() return s.rebirbCount end)
	put(P .. "evolutions", function() return s.evolutionCount end)
	put(P .. "map", function() return rt.map end)
	local f = Park.list(rt, 0)
	put(P .. "field count", function() return #f end)
	put(P .. "field timer", function() return rt.field.timers[0] or 0 end)
	put(P .. "field nextId", function() return rt.field.nextId end)
	for _, t in TYPES do
		put(P .. "field type " .. t, function() local n = 0; for _, p in f do if p.type == t then n += 1 end end; return n end)
	end
	for i = 1, math.min(8, #f) do
		local p = f[i]
		put(P .. "egg " .. (i - 1) .. " x", function() return p.x end)
		put(P .. "egg " .. (i - 1) .. " y", function() return p.y end)
		put(P .. "egg " .. (i - 1) .. " type", function() return typeIndex(p.type) end)
		put(P .. "egg " .. (i - 1) .. " id", function() return p.id end)
	end
	put(P .. "seedTimer", function() return rt.seedTimer end)
	put(P .. "rate popcorn", function() return rt.rates.popcorn or -1 end)
	put(P .. "rate seeds", function() return rt.rates.sunflowerSeeds or -1 end)
	local sp = s.sparrow
	put(P .. "sparrow unlocked", function() return sp.unlocked == true end)
	put(P .. "sparrow level", function() return sp.level end)
	put(P .. "sparrow xp", function() return sp.xp end)
	put(P .. "sparrow maxLevel", function() return sp.maxLevelReached end)
	put(P .. "sparrow count", function() return sp.count end)
	put(P .. "sparrow prestige", function() return sp.prestigeCount end)
	put(P .. "sparrow resonance", function() return sp.resonanceXP end)
	put(P .. "sparrow drained", function() return sp.totalEnergyDrained end)
	put(P .. "sparrow feeding", function() return sp.feeding == true end)
	put(P .. "sparrow draining", function() return sp.draining == true end)
	put(P .. "bird count", function() return #rt.sparrows end)
	for i = 1, math.min(4, #rt.sparrows) do
		local bd = rt.sparrows[i]
		put(P .. "bird " .. (i - 1) .. " x", function() return bd.x end)
		put(P .. "bird " .. (i - 1) .. " y", function() return bd.y end)
	end
	for _, k in EVO_KEYS do put(P .. "castle fed " .. k, function() return s.evo.fed[k] end) end
	put(P .. "castle progress", function() return s.evo.progress end)
	put(P .. "castle talked", function() return s.evo.talked == true end)
	for _, id in CFG.upP1 do put(P .. "up " .. id, function() return R.level(s, id) end) end
	for _, n in D.SUN do
		local L = s.sunflowerUpgrades[n.id] or 0
		if L > 0 then put(P .. "sun " .. n.id, function() return L end) end
	end
	put(P .. "last", function() if type(last) == "string" then return REASON[last] or -1 end; if last == nil then return -1 end; return last end)
end

local function runProgram(s, prog, put)
	local rt = G.newRuntime(Park.BIRB_GEOM, { type = lcg(1), pos = lcg(2), sparrow = lcg(3) })
	local last = nil
	local platform
	for _, st in D.STATIONS do if st.id == "__platform" then platform = st end end
	for _, o in prog do
		local op = o.op
		if op == "seed" then rt.rng.type, rt.rng.pos, rt.rng.sparrow = lcg(o.type), lcg(o.pos), lcg(o.sparrow)
		elseif op == "map" then rt.map = o.map; rt.player.x = o.x; rt.player.y = o.y; rt.onPlatform = false
		elseif op == "platform" then rt.map = 1; rt.onPlatform = R.hasSun(s, "d_sunflower_machine")
		elseif op == "wait" then
			local n = math.floor(o.t / SIM_DT + 0.5)
			for _ = 1, n do G.stepPhase1(s, SIM_DT, rt) end
		elseif op == "eggs" then
			local eggs = {}
			for i, p in Park.list(rt, 0) do if i <= o.n then table.insert(eggs, { x = p.x, y = p.y }) end end
			rt.map = 0; rt.onPlatform = false
			for _, e in eggs do rt.player.x = e.x; rt.player.y = e.y; G.stepPhase1(s, SIM_DT, rt) end
			last = #eggs
		elseif op == "buy" then
			local n = G.buy(s, o.id, o.max == true)
			last = if o.max then n else n == 1
		elseif op == "buyAll" then
			last = 0
			for _, id in CFG.drawer do
				if id:sub(1, 2) ~= "s_" or R.hasSun(s, "d_sunflower_machine") then last += Shops.buyMax(s, id) end
			end
		elseif op == "molt" then last = G.molt(s, rt) ~= nil
		elseif op == "evolve" then last = G.evolve(s, rt)
		elseif op == "sun" then last = G.buySun(s, o.id)
		elseif op == "sunAll" then
			local ids = {}
			for _, st in D.STATIONS do
				local id = st.id
				if id ~= "__platform" and id:sub(1, 12) ~= "d_archivist_" and not isDesertNode(id) and R.sunVisible(s, id) then table.insert(ids, id) end
			end
			last = 0
			for _, id in ids do if G.buySun(s, id) == "" then last += 1 end end
		elseif op == "sparrow" then
			local w, sp = o.what, s.sparrow
			if w == "feed" then sp.feeding = true; sp.draining = false
			elseif w == "drain" then sp.draining = true; sp.feeding = false
			elseif w == "stop" then sp.draining = false; sp.feeding = false
			elseif w == "mitosis" then last = Sparrow.mitosis(s)
			elseif w == "rebirb" then last = Sparrow.rebirb(s)
			elseif w == "autoMitosis" then sp.autoMitosis = true
			elseif w == "autoRebirb" then sp.autoRebirb = true
			elseif w:sub(1, 5) == "rate:" then sp.feedRatePercent = tonumber(w:sub(6)) end
		elseif op == "talk" then s.evo.talked = true
		elseif op == "hold" then rt.holdFeed = o.on
		elseif op == "give" then R.add(s, o.cur, EN.fromNumber(o.n))
		elseif op == "snap" then snap(s, rt, o.tag, put, last)
		else error("unknown op " .. tostring(op)) end
	end
end

-- ---------------------------------------------------------------- main
local results = {}
local t0 = os.clock()
local count = 0
for _, sc in CFG.scenarios do
	if ONLY and not string.find(sc.name, ONLY, 1, true) then continue end
	local values = {}
	local function put(k, f)
		local ok, v = pcall(f)
		if not ok then values[k] = "ERR " .. string.sub(tostring(v), 1, 80); return end
		if type(v) == "table" then v = big(v) end
		if v ~= v then v = "NaN" end
		if v == math.huge or v == -math.huge then v = if v > 0 then "Infinity" else "-Infinity" end
		values[k] = v
		count += 1
	end
	local s = fromBirb(sc.state or {})
	probeValues(s, sc, put)
	p1Values(s, G.newRuntime(Park.BIRB_GEOM, { type = lcg(1), pos = lcg(2), sparrow = lcg(3) }), put)
	if sc.program then runProgram(s, sc.program, put) end
	table.insert(results, { name = sc.name, values = values })
end
fs.writeFile(OUT .. "/lua.json", serde.encode("json", { results = results }))
print(string.format("lua: %d scenarios, %d values in %.1f s", #results, count, os.clock() - t0))
