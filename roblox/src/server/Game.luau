--!nonstrict
-- Game: Peckwood state + every system's math, on the verified Birb formulas (shared/Defs).
-- Pure logic, no Instances: Main.server owns players, remotes, the popcorn field and saving.
-- Wallet keys live at the top of the state table with the original game's names
-- (popcorn, goldenFeathers, sunflowerSeeds, ...) because BirbFormulas reads them there.
local RS = game:GetService("ReplicatedStorage")
local Defs = require(RS:WaitForChild("Peckwood"):WaitForChild("Defs"))
local F, S, EN = Defs.F, Defs.S, Defs.EN
local UP = Defs.UP

local G = {}
G.Defs = Defs

local WALLET = Defs.CUR_ORDER
local function num(x) return EN.toNumber(x) end

-- ---------------------------------------------------------------- state
function G.fresh()
	local s = {
		v = 2,
		upgrades = {}, owned = {},
		rebirbCount = 0, evolutionCount = 0, island = 1,
		stats = { totalPopcorn = 0, bestPopcorn = 0, fishCaught = 0, kills = 0, questsDone = 0, playTime = 0, goldenCollected = 0 },
		zone = "park",
		evo = { fed = {} },
		sparrow = { level = 1, xp = 0, count = 1, rebirbs = 0, resonance = 0, draining = false, mitosisXp = 0, autoMitosis = false },
		seagull = { level = 1, xp = 0, migrations = 0, route = 1, doctrine = 1, out = true, t = 0, autoMigrate = false },
		dave = { level = 1, xp = 0, rebirbs = 0, branch = 0, golden = 0 },
		panda = { assist = false, waiting = 0, leftAt = 0 },
		crow = { level = 1, xp = 0, rebirbs = 0, area = 0 },
		nest = { tier = 0 },
		parrot = { level = 1, xp = 0, hp = 0, dmg = 0, regen = 0, floor = 1, best = 1, kills = 0, active = false },
		fish = { rod = "rod_simple", crafted = { rod_simple = true }, disc = {}, best = {}, have = {}, recent = {}, baits = {}, bait = nil, equipped = nil, tanks = {}, active = false, t = 0 },
		quests = { day = 0, daily = {}, prog = {}, claimed = {}, done = 0, bonus = {} },
		sacrifice = { total = 0, tier = 0 },
		auto = false,
	}
	for _, k in WALLET do s[k] = EN.ZERO end
	return s
end

-- deep copy (EN values are plain arrays, so this clones them too)
local function deep(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in t do o[k] = deep(v) end
	return o
end
G.clone = deep

-- DataStore: EN -> strings, everything else plain
function G.serialize(s)
	local o = deep(s)
	for _, k in WALLET do o[k] = EN.toString(s[k]) end
	return o
end
function G.deserialize(d)
	local s = G.fresh()
	if type(d) ~= "table" or d.v ~= 2 then return s end
	for k, v in d do
		if type(s[k]) == "table" and type(v) == "table" and not table.find(WALLET, k) then
			for kk, vv in v do s[k][kk] = vv end
		elseif not table.find(WALLET, k) then
			s[k] = v
		end
	end
	for _, k in WALLET do s[k] = if type(d[k]) == "string" then EN.fromSave(d[k]) else EN.ZERO end
	return s
end

-- ---------------------------------------------------------------- multipliers
local function sacrificeRow(s)
	return Defs.SACRIFICE[s.sacrifice.tier]
end
local function questBonus(s, stat) return s.quests.bonus[stat] or 0 end

-- fish effect multiplier for one effect type: equipped fish x every aquarium fish
local function fishMult(s, kind)
	local m = 1
	local function add(id)
		local f = id and Defs.FISH_BY_ID[id]
		if f and f.effect and f.effect.type == kind then m *= f.effect.value end
	end
	add(s.fish.equipped)
	for _, id in s.fish.tanks do add(id) end
	return m
end
G.fishMult = fishMult

-- sync the "external factor" fields BirbFormulas reads off the state table
function G.syncFactors(s)
	s.seeds = s.sunflowerSeeds
	s.fishPopcornMult = fishMult(s, "popcorn_mult")
	s.fishFeatherMult = fishMult(s, "feather_mult")
	s.sparrowDrainMultiplier = S.sparrowDrainMultiplier(s.sparrow.resonance)
	local sr = sacrificeRow(s)
	s.sacrificeMultiplier = if sr then sr.popcornMultiplier else 1
	s.questPopcornMultiplier = 1 + questBonus(s, "popcorn_gain_mult")
	s.questFeatherBonus = questBonus(s, "feather_gain_mult")
	s.sparrowRebirbs = s.sparrow.rebirbs
	s.daveRebirbs = s.dave.rebirbs
	s.playTimeSeconds = s.stats.playTime
	s.highestFishWeight = 0
	for _, kg in s.fish.best do if kg > s.highestFishWeight then s.highestFishWeight = kg end end
end

function G.evoMult(s) return if s.evolutionCount >= 2 then s.evolutionCount else 1 end

-- ---------------------------------------------------------------- derived (also sent to the client)
function G.reachPx(s) return 14 * (1 + 0.2 * math.max(0, F.level(s, "pr_radius_mult") - 1)) * (1 + questBonus(s, "pickup_radius_mult")) end
function G.speed(s) return F.wingSpeed(F.level(s, "p_move_speed")) end
function G.inDesert(s) return s.zone == "desert" end

function G.goldenValue(s)
	local g = math.floor(F.level(s, "p_golden_popcorn_value") * F.goldenPopcornMult(F.level(s, "pr_golden_popcorn_mult")))
	g = math.floor(g * fishMult(s, "golden_popcorn_mult"))
	g = math.floor(g * (1 + Defs.level(s, "d_desert_field_notes_plus") / 3))
	g = math.floor(g * (1 + num(EN.log10(EN.add(s.sunflowerSeeds, 1))) * 2 / math.log10(4e14 + 1)))
	g = math.floor(g * S.daveGoldenMult(s.dave.level))
	return math.max(1, g)
end

function G.desertGoldenChance(s)
	local c = F.desertGoldenChance(s)
	return if c > 0 then c else 0.05   -- Figma hero: "5% of desert drops are golden" (Desert Core is implied by reaching the desert)
end

function G.seedsPerSec(s)
	if s.island < 3 then return 0 end
	local r = 3 * F.moreSeeds(F.level(s, "s_more_seeds")) * G.evoMult(s)   -- base 3/s: Figma Seeds hero ("+3 / s on the platform")
	local sr = sacrificeRow(s)
	if sr then r *= sr.seedMultiplier end
	r *= 1 + questBonus(s, "seed_gain_mult")
	return r
end

function G.twigMult(s)
	local t = Defs.NEST_TIERS[s.nest.tier + 1]
	return t.mult * (1 + questBonus(s, "twig_gain_mult"))
end
function G.twigsPerSec(s)
	if s.island < 6 then return 0 end
	local hits = S.chopDps(s.nest.tier, 0) * 0 + 1 + 0.2 * Defs.level(s, "n_peck_rate")   -- Birb pecks once a second + Peck Rate
	local perHit = math.max(0.1, (1 + 0.2 * Defs.level(s, "n_twig_value")) * G.twigMult(s)) * (1 + Defs.level(s, "n_peck_power"))
	return hits * perHit
end

function G.crowDamage(s)
	local interval, over = S.crowHitInterval(s.crow.level, s.crow.rebirbs, 1)
	local dmg = S.miningPowerEffect(F.level(s, "m_mining_power")) * S.crowRebirbDamage(s.crow.rebirbs) * over
	return dmg, interval
end
function G.orePerSec(s)
	if s.island < 7 then return EN.ZERO end
	-- EN all the way: power, rebirb damage and ore value are each exponential, so their product overflows a double at max
	local _, interval = G.crowDamage(s)
	local _, over = S.crowHitInterval(s.crow.level, s.crow.rebirbs, 1)
	local R = s.crow.rebirbs
	local reb = EN.mul(EN.pow(1.25, math.min(8, R)), EN.pow(2, math.max(0, R - 8)))
	local pow = EN.pow(1.1, math.max(0, F.level(s, "m_mining_power") - 1))
	local val = EN.pow(1.1, math.max(0, F.level(s, "m_ore_value") - 1))
	local r = EN.mul(EN.mul(pow, reb), val)
	return EN.mul(r, over / interval * (if s.evolutionCount >= 6 then 2 else 1) * S.oreAreaReward(s.crow.area))
end

function G.parrotStats(s)
	local p = s.parrot
	local sr = sacrificeRow(s)
	local hp = (100 + p.hp) * (1 + questBonus(s, "expedition_hp_mult"))
	local dmg = (100 + p.dmg) * (1 + questBonus(s, "expedition_damage_mult"))
	local regen = p.regen
	return hp, dmg, regen, (if sr then sr.skillPointMultiplier else 1)
end

local FLOOR_MULT = { 1, 1200, 2.5e5, 3e8, 6e10, 1.8e13, 5.4e15, 1.188e18 }
function G.floorEnemyHp(f: number)
	local m = FLOOR_MULT[f] or (5.4e15 * 1200 ^ (f - 7))
	return 27 * m   -- floor band 0 (18-36 HP) times the floor multiplier (SYSTEMS.md "Depth-scaled HP")
end

function G.fishInterval(s)
	local rod = Defs.ROD_BY_ID[s.fish.rod]
	return 4 * (rod and rod.speedBonus or 1) / fishMult(s, "reel_speed_mult")
end

function G.evoProgress(s)
	local need = Defs.EVO[s.evolutionCount + 1]
	if not need then return 0 end
	local sum, n = 0, 0
	for k, req in need do sum += math.min(1, (s.evo.fed[k] or 0) / req); n += 1 end
	return sum / n
end

function G.plumeGain(s) G.syncFactors(s); return F.rebirbFeathers(s) end

-- ---------------------------------------------------------------- wallet helpers
local function give(s, cur, n)
	s[cur] = EN.add(s[cur], n)
	if cur == "popcorn" then
		s.stats.totalPopcorn += num(n)
		local p = num(s.popcorn); if p > (s.stats.bestPopcorn or 0) then s.stats.bestPopcorn = p end
	end
end
G.give = give
local function canPay(s, cur, n) return EN.meeq(s[cur], n) end
local function pay(s, cur, n) s[cur] = EN.sub(s[cur], n) end

-- ---------------------------------------------------------------- shop
function G.windowUnlocked(s, w) return (Defs.WINDOW_ISLAND[w] or 99) <= s.island end

function G.buy(s, id, all)
	local d = UP[id]; if not d then return 0 end
	local n = 0
	repeat
		local L = Defs.level(s, id)
		if L >= Defs.maxLevel(s, id) then break end
		local c = Defs.cost(s, id, L)
		if not c or not canPay(s, d.cur, c) then break end
		pay(s, d.cur, c)
		s.upgrades[id] = L + 1
		n += 1
	until not all or n >= 1000
	return n
end

-- ---------------------------------------------------------------- resets
local function resetTree(s, pred)
	for id in s.upgrades do if pred(id) then s.upgrades[id] = nil end end
end
function G.molt(s)
	local g = G.plumeGain(s)
	if EN.le(g, 1) and not EN.eq(g, 1) then return nil end
	give(s, "goldenFeathers", g)
	s.rebirbCount += 1
	s.popcorn = EN.ZERO
	-- Molt resets popcorn and the non-permanent P tree (Popcorn, Golden Value, Auric Silo, Echo rows)
	resetTree(s, function(id) return id:sub(1, 2) == "p_" or id == "e_echo_capacity" end)
	return g
end

function G.evolve(s)
	if s.evolutionCount >= 5 or G.evoProgress(s) < 1 then return false end
	s.evolutionCount += 1
	s.evo.fed = {}
	s.popcorn = EN.ZERO; s.sunflowerSeeds = EN.ZERO
	resetTree(s, function(id) return id:sub(1, 2) == "p_" or id:sub(1, 2) == "s_" or id:sub(1, 2) == "m_" or id == "e_echo_capacity" end)
	s.sparrow.level, s.sparrow.xp, s.sparrow.count, s.sparrow.mitosisXp = 1, 0, 1, 0
	return true
end

function G.feed(s, res, all)
	local need = Defs.EVO[s.evolutionCount + 1]; if not need or not need[res] then return false end
	local want = need[res] - (s.evo.fed[res] or 0)
	if want <= 0 then return false end
	local have = num(s[res])
	local amt = math.min(want, if all then have else math.max(1, math.min(have, want / 10)))
	if amt <= 0 then return false end
	pay(s, res, amt)
	s.evo.fed[res] = (s.evo.fed[res] or 0) + amt
	return true
end

-- ---------------------------------------------------------------- companions
function G.sparrowStep(s, dt, seedIncome)
	local sp = s.sparrow
	if s.island < 3 then return end
	local xpPerSeed = 0.01 * (1 + 2 * math.sqrt(sp.rebirbs)) * (if sp.level >= 50 then 1.5 else 1)
	local need = S.sparrowXpNeeded(sp.level)
	if sp.draining then
		local loss = need * math.max(2, 0.1 * sp.level) * dt
		local taken = math.min(loss, sp.xp + (sp.level > 1 and need or 0))
		sp.xp -= loss
		while sp.xp < 0 and sp.level > 1 do sp.level -= 1; sp.xp += S.sparrowXpNeeded(sp.level) end
		if sp.xp < 0 then sp.xp = 0; sp.draining = false end
		sp.resonance += taken * (if sp.rebirbs >= 1 then 1.25 else 1)
		return
	end
	local share = seedIncome * 0.25
	local cap = 0.25 * need / xpPerSeed
	local seedsUsed = math.min(share, cap) * dt
	if seedsUsed <= 0 or not canPay(s, "sunflowerSeeds", seedsUsed) then return end
	pay(s, "sunflowerSeeds", seedsUsed)
	local gain = seedsUsed * xpPerSeed
	sp.xp += gain; sp.mitosisXp += gain
	while sp.level < 1000 and sp.xp >= S.sparrowXpNeeded(sp.level) do sp.xp -= S.sparrowXpNeeded(sp.level); sp.level += 1 end
	if (sp.autoMitosis or sp.rebirbs >= 1) and sp.count < 16 and sp.mitosisXp >= S.mitosisRequirement(sp.count) then G.mitosis(s) end
end
function G.sparrowFeedNow(s)
	local sp = s.sparrow
	local need = S.sparrowXpNeeded(sp.level)
	local xpPerSeed = 0.01 * (1 + 2 * math.sqrt(sp.rebirbs))
	local seeds = math.min(num(s.sunflowerSeeds), (need - sp.xp) / xpPerSeed)
	if seeds <= 0 then return false end
	pay(s, "sunflowerSeeds", seeds)
	sp.xp += seeds * xpPerSeed; sp.mitosisXp += seeds * xpPerSeed
	while sp.level < 1000 and sp.xp >= S.sparrowXpNeeded(sp.level) - 1e-9 do sp.xp = math.max(0, sp.xp - S.sparrowXpNeeded(sp.level)); sp.level += 1 end
	return true
end
function G.mitosis(s)
	local sp = s.sparrow
	if sp.count >= 16 or sp.mitosisXp < S.mitosisRequirement(sp.count) then return false end
	sp.count *= 2; sp.level = 1; sp.xp = 0; sp.mitosisXp = 0
	return true
end
function G.sparrowRebirb(s)
	local sp = s.sparrow
	if sp.count < 16 then return false end
	sp.count, sp.level, sp.xp, sp.mitosisXp = 1, 1, 0, 0
	sp.rebirbs += 1
	return true
end

G.ROUTES = { { "Bridge", 1 }, { "Floor 1", 1.18 }, { "Floor 2", 1.22 }, { "Floor 4", 1.28 }, { "Floor 6", 1.34 } }
G.DOCTRINES = { { "Balanced", 1, 1, 1 }, { "Hunter", 1.3, 0.94, 1.18 }, { "Training", 1.02, 1.45, 0.92 } }
function G.seagullInterval(s)
	local g = s.seagull
	local k = 0.02 * (if g.migrations >= 100 then 2 else 1)
	return math.max(0.25, S.seagullInterval(g.level, g.migrations, k) * G.ROUTES[g.route][2] * G.DOCTRINES[g.doctrine][2])
end
function G.seagullCap(s) return 50 end

-- ---------------------------------------------------------------- fishing
local RARITY_W = { common = 1, uncommon = 1.5, rare = 2.5, epic = 4, legendary = 8, mythic = 12 }
local TYPE_KG = { coastal = { 0.1, 2 }, reef = { 0.2, 3 }, freshwater = { 0.15, 2.5 }, river = { 0.2, 4 }, ocean = { 0.5, 50 }, creature = { 0.05, 5 },
	exotic_reef = { 0.3, 4 }, spirit = { 0.01, 1 }, cosmic = { 0.1, 3 }, mechanical = { 1, 20 }, crab = { 0.1, 5 }, abyssal = { 0.3, 15 } }
local BANDS = { { 0.7, 0.1, 0.5, 1.6 }, { 0.9, 0.35, 0.7, 1.2 }, { 0.97, 0.6, 0.85, 1.05 }, { 0.995, 0.8, 0.95, 0.9 }, { 0.9995, 0.92, 1, 0.8 }, { 2, 1, 1.2, 0.7 } }

local function rodTier(s)
	local r = Defs.ROD_BY_ID[s.fish.rod]; return r and r.tier or 0
end
function G.rollFish(s, rng)
	local tier = rodTier(s)
	local baitType
	if s.fish.bait and (s.fish.baits[s.fish.bait] or 0) > 0 then
		for _, b in Defs.BAITS do if b.id == s.fish.bait then baitType = b.effect and b.effect.targetType end end
	end
	local pool, total = {}, 0
	local function build(narrow)
		pool, total = {}, 0
		for _, f in Defs.FISH do
			if (f.minTier or 0) <= tier + 1 and f.weight and f.weight > 0 and (not narrow or f.type == baitType) then
				local w = f.weight * (if (f.minTier or 0) > tier then 0.15 else 1)
				table.insert(pool, { f, w }); total += w
			end
		end
	end
	build(baitType ~= nil)
	if total <= 0 then build(false) elseif baitType then s.fish.baits[s.fish.bait] -= 1 end
	if total <= 0 then return nil end
	local r = rng:NextNumber() * total
	local pick = pool[#pool][1]
	for _, e in pool do r -= e[2]; if r <= 0 then pick = e[1]; break end end
	-- weight roll (SYSTEMS.md "Weight roll")
	local base = TYPE_KG[pick.type] or { 0.1, 2 }
	local rm = RARITY_W[pick.rarity] or 1
	local mn, mx = base[1] * rm, base[2] * rm
	local l = ((tier + 1) / (#Defs.RODS)) ^ 0.9
	mx = mn + (mx - mn) * l; mn *= 0.6 + 0.4 * l
	local u = rng:NextNumber()
	local band = BANDS[#BANDS]
	for _, b in BANDS do if u < b[1] then band = b; break end end
	local f = band[2] + (band[3] - band[2]) * rng:NextNumber() ^ band[4]
	local kg = math.clamp(mn + (mx - mn) * f, 0.7 * mn, 1.2 * mx)
	return pick, math.floor(kg * 100 + 0.5) / 100
end

function G.catch(s, pick, kg, byGull)
	local fs = s.fish
	local first = not fs.disc[pick.id]
	fs.disc[pick.id] = true
	fs.have[pick.id] = (fs.have[pick.id] or 0) + 1
	local pb = kg > (fs.best[pick.id] or 0)
	if pb then fs.best[pick.id] = kg end
	table.insert(fs.recent, 1, { id = pick.id, kg = kg })
	while #fs.recent > 3 do table.remove(fs.recent) end
	s.stats.fishCaught += 1
	local rod = Defs.ROD_BY_ID[fs.rod]
	local m = (rod and rod.monetaPerCatch or 1) * fishMult(s, "xp_mult") * (if byGull then 0.25 else 1)
	give(s, "moneta", m)
	return first, pb
end

function G.sellValue(s, id)
	local f = Defs.FISH_BY_ID[id]
	return S.fishSellValue(f.sellValue or 1, s.fish.best[id], fishMult(s, "fish_value_mult"), false, false)
end

-- next three rods the player can work toward (Rods window rows)
function G.rodRows(s)
	local out = {}
	for _, r in Defs.RODS do
		if not s.fish.crafted[r.id] and #r.cost > 0 then table.insert(out, r) end
		if #out >= 3 then break end
	end
	return out
end
function G.craft(s, rodId)
	local r = Defs.ROD_BY_ID[rodId]
	if not r or s.fish.crafted[rodId] then return false end
	for _, c in r.cost do if (s.fish.have[c.fishId] or 0) < c.count then return false end end
	for _, c in r.cost do s.fish.have[c.fishId] -= c.count end
	s.fish.crafted[rodId] = true
	if r.index > (Defs.ROD_BY_ID[s.fish.rod].index or 0) then s.fish.rod = rodId end
	return true
end
function G.baitCost(b)
	for _, c in b.cost or {} do if c.type == "currency" then return c.count end end
	return 1
end
function G.tankCount(s) return math.min(5, 2 + math.floor(s.evolutionCount / 2)) end

-- ---------------------------------------------------------------- quests
local function seededDailies(day)
	local fam = { floor_kill = {}, enemy_hunt = {}, boss_clear = {} }
	for _, q in Defs.QUESTS do if q.questType == "daily" and fam[q.family] then table.insert(fam[q.family], q) end end
	local rng = Random.new(day)
	local out = {}
	for _, k in { "floor_kill", "enemy_hunt", "boss_clear" } do
		local list = fam[k]
		if #list > 0 then table.insert(out, list[rng:NextInteger(1, #list)].id) end
	end
	return out
end
local QUEST_BY_ID = {}
for _, q in Defs.QUESTS do if q.id then QUEST_BY_ID[q.id] = q end end
G.QUEST_BY_ID = QUEST_BY_ID
function G.refreshDailies(s, now)
	local day = math.floor(now / 86400)
	if s.quests.day ~= day or #s.quests.daily < 3 then   -- < 3: saves rolled before the family-name fix
		s.quests.day = day
		s.quests.daily = seededDailies(day)
		s.quests.prog = {}; s.quests.claimed = {}
	end
end
function G.claim(s, i)
	local id = s.quests.daily[i]; local q = id and QUEST_BY_ID[id]
	if not q or s.quests.claimed[id] or (s.quests.prog[id] or 0) < q.target then return false end
	s.quests.claimed[id] = true
	s.quests.done += 1; s.stats.questsDone += 1
	s.quests.bonus[q.rewardStat] = (s.quests.bonus[q.rewardStat] or 0) + q.rewardValue
	return true
end

-- ---------------------------------------------------------------- sacrifice
function G.sacrifice(s)
	local sp = num(s.skillPoints)
	if sp < 1 then return false end
	s.skillPoints = EN.ZERO
	s.sacrifice.total += sp
	local t = 0
	for i, row in Defs.SACRIFICE do if s.sacrifice.total >= row.cost then t = i end end
	s.sacrifice.tier = t
	return true
end

-- ---------------------------------------------------------------- per-second systems
-- Called on the server Heartbeat with real dt. Returns a list of toasts.
function G.step(s, dt, rng)
	local toasts = {}
	s.stats.playTime += dt
	G.syncFactors(s)
	-- seeds + sparrow feeding share
	local seeds = G.seedsPerSec(s)
	if seeds > 0 then give(s, "sunflowerSeeds", seeds * dt) end
	G.sparrowStep(s, dt, seeds)
	-- twigs (nest)
	local tw = G.twigsPerSec(s)
	if tw > 0 then give(s, "twigs", tw * dt) end
	-- ore (crow)
	local ore = G.orePerSec(s)
	if not EN.isZero(ore) then
		give(s, "bruteOre", EN.mul(ore, dt))
		local dmg, interval = G.crowDamage(s)
		local breaks = dmg / interval / S.oreHp(s.crow.area) * dt
		s.crow.xp += breaks * ({ 1, 3, 8, 20, 48, 110, 260 })[math.min(s.crow.area, 6) + 1]
		while s.crow.level < 500 and s.crow.xp >= S.crowXpNeeded(s.crow.level) do s.crow.xp -= S.crowXpNeeded(s.crow.level); s.crow.level += 1 end
	end
	-- fishing (player rod while "Go Fishing" is on) + the seagull
	if s.island >= 5 then
		if s.fish.active then
			s.fish.t += dt
			local iv = G.fishInterval(s)
			while s.fish.t >= iv do
				s.fish.t -= iv
				local pick, kg = G.rollFish(s, rng)
				if pick then
					local first = G.catch(s, pick, kg, false)
					if first then table.insert(toasts, { "fish", pick.id, kg }) end
				end
			end
		end
		local g = s.seagull
		if g.out then
			g.t += dt
			local iv = G.seagullInterval(s)
			while g.t >= iv do
				g.t -= iv
				local pick, kg = G.rollFish(s, rng)
				if pick then
					G.catch(s, pick, kg, true)
					if g.level < G.seagullCap(s) then
						g.xp += math.floor((S.SEAGULL_BASE_XP[pick.rarity] or 10) * G.DOCTRINES[g.doctrine][3] * (1 + g.migrations * 0.02))
						while g.level < G.seagullCap(s) and g.xp >= S.seagullXpNeeded(g.level) do g.xp -= S.seagullXpNeeded(g.level); g.level += 1 end
					end
				end
			end
			if g.autoMigrate and g.level >= G.seagullCap(s) then g.migrations += 1; g.level = 1; g.xp = 0 end
		end
	end
	-- expedition (parrot auto-fights while out)
	local p = s.parrot
	if p.active and s.island >= 9 then
		local _, dmg, _, spMult = G.parrotStats(s)
		local hp = G.floorEnemyHp(p.floor)
		local kills = math.min(2, dmg / hp) * dt
		p.kills += kills; s.stats.kills += kills
		local sp = (3 + math.floor((p.floor - 1) / 2)) * spMult * kills
		give(s, "skillPoints", sp)
		p.xp += kills * 10 * 2.05 ^ (p.floor - 1)
		while p.level < 1000 and p.xp >= S.parrotXpNeeded(p.level) do p.xp -= S.parrotXpNeeded(p.level); p.level += 1 end
		for _, id in s.quests.daily do
			local q = QUEST_BY_ID[id]
			if q and (q.family ~= "floor_kill" or (q.floor or 1) <= p.floor) then
				s.quests.prog[id] = math.min(q.target, (s.quests.prog[id] or 0) + kills * (if q.family == "boss_clear" then 1 / 35 else 1))
			end
		end
		if p.kills >= 35 * p.floor and p.floor < 12 and dmg >= hp * 0.25 then
			p.floor += 1; p.best = math.max(p.best, p.floor)
			table.insert(toasts, { "floor", p.floor })
		end
	end
	-- islands
	while s.island < #Defs.ISLANDS and Defs.ISLANDS[s.island + 1].gate(s) do
		s.island += 1
		table.insert(toasts, { "island", s.island })
	end
	if s.island >= 8 then s.owned.d_desert_auric_blueprints = true end   -- desert opens Auric Silo in the Golden shop
	return toasts
end

-- objective button for gates that cost something (Unlock Evolve)
function G.unlockIsland(s)
	local nxt = Defs.ISLANDS[s.island + 1]
	if not nxt or not nxt.cost then return false end
	for cur, n in nxt.cost do if not canPay(s, cur, n) then return false end end
	for cur, n in nxt.cost do pay(s, cur, n) end
	if nxt.id == "castle" then s.owned.d_unlock_evolve = true end
	return true
end

-- ---------------------------------------------------------------- dev saves (never written to the DataStore)
function G.maxed()
	local s = G.fresh()
	for id in UP do s.upgrades[id] = Defs.maxLevel(s, id) end
	for _, k in WALLET do s[k] = EN.fromNumber(1e30) end
	s.island = #Defs.ISLANDS
	s.rebirbCount, s.evolutionCount = 250, 5
	s.owned.d_unlock_evolve = true
	s.nest.tier = 3
	s.crow.level, s.crow.rebirbs, s.crow.area = 120, 8, 6
	s.sparrow.level, s.sparrow.count, s.sparrow.rebirbs, s.sparrow.resonance = 100, 16, 5, 1e6
	s.seagull.level, s.seagull.migrations = 50, 100
	s.dave.level, s.dave.rebirbs = 100, 100
	s.parrot.level, s.parrot.floor, s.parrot.best, s.parrot.hp, s.parrot.dmg, s.parrot.regen = 200, 12, 12, 500, 500, 100
	for _, r in Defs.RODS do s.fish.crafted[r.id] = true end
	s.fish.rod = Defs.RODS[#Defs.RODS].id
	for _, f in Defs.FISH do s.fish.disc[f.id] = true; s.fish.best[f.id] = 1 + (f.weight or 1) / 10; s.fish.have[f.id] = 99 end
	for _, b in Defs.BAITS do s.fish.baits[b.id] = 99 end
	for i = 1, 5 do s.fish.tanks[i] = Defs.FISH[#Defs.FISH - i + 1].id end
	s.fish.recent = { { id = Defs.FISH[#Defs.FISH].id, kg = 99 }, { id = Defs.FISH[#Defs.FISH - 1].id, kg = 50 }, { id = Defs.FISH[#Defs.FISH - 2].id, kg = 20 } }
	s.sacrifice.tier = #Defs.SACRIFICE; s.sacrifice.total = Defs.SACRIFICE[#Defs.SACRIFICE].cost
	for _, q in Defs.QUESTS do if q.id then s.quests.claimed[q.id] = true end end
	s.quests.done = #Defs.QUESTS; s.stats.questsDone = #Defs.QUESTS
	s.stats.bestPopcorn = 1e30; s.stats.fishCaught = 99999; s.stats.kills = 99999; s.stats.playTime = 360000
	return s
end

-- "Next island": copy, satisfy the next gate, and hand out enough of each new currency to try the new windows.
function G.stepIsland(src)
	local s = deep(src)
	if s.island >= #Defs.ISLANDS then return s end
	local nxt = Defs.ISLANDS[s.island + 1]
	if nxt.id == "molt" then s.stats.bestPopcorn = math.max(s.stats.bestPopcorn, 1000); give(s, "popcorn", 2000)
	elseif nxt.id == "garden" then s.rebirbCount = math.max(1, s.rebirbCount); give(s, "goldenFeathers", 25)
	elseif nxt.id == "castle" then s.owned.d_unlock_evolve = true; give(s, "popcorn", 1e8)
	elseif nxt.id == "bridge" then s.evolutionCount = math.max(1, s.evolutionCount)
	elseif nxt.id == "forest" then s.evolutionCount = math.max(2, s.evolutionCount)
	elseif nxt.id == "mine" then s.evolutionCount = math.max(3, s.evolutionCount)
	elseif nxt.id == "desert" then s.evolutionCount = math.max(4, s.evolutionCount)
	elseif nxt.id == "expedition" then s.nest.tier = math.max(1, s.nest.tier)
	elseif nxt.id == "echo" then s.evolutionCount = math.max(5, s.evolutionCount) end
	s.island += 1
	-- starter wallet for every row the new windows show: 10 levels' worth
	for _, w in nxt.windows do
		for id, d in UP do
			if d.cur and G.windowRowOf and G.windowRowOf[id] == w then
				local c = Defs.cost(s, id)
				if c then give(s, d.cur, c * 10) end
			end
		end
	end
	if nxt.id == "bridge" then give(s, "moneta", 500) end
	if nxt.id == "expedition" then give(s, "skillPoints", 50) end
	return s
end

-- row id -> window id (filled by Main from the client spec order; used by stepIsland)
G.windowRowOf = {
	p_value = "popcorn", p_speed = "popcorn", p_capacity = "popcorn", p_move_speed = "popcorn",
	pr_popcorn_mult = "molt", pr_radius_mult = "molt", pr_respawn_mult = "molt",
	s_more_popcorn = "seeds", s_more_feathers = "seeds", s_more_seeds = "seeds",
	p_golden_popcorn_value = "golden", p_auric_silo = "golden", d_desert_field_notes_plus = "golden",
	m_mining_power = "mine", m_ore_value = "mine", m_charged_strike = "mine", m_rupture = "mine",
	n_twig_value = "nest", n_peck_rate = "nest", n_peck_power = "nest",
	p_echo_value = "echo", e_echo_capacity = "echo", dave_training = "dave",
}

return G
