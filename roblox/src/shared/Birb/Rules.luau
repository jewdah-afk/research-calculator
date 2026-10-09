--!nonstrict
-- Birb Phase 1 rules (Park, egg shop, Molt, keepsakes, seed shop, sunflower tree, Sparrow formulas, Castle), written
-- fresh in Luau from the playtest (playtest/js/core.js + systems.js), which matches Birb's live engine value for value.
-- Pure functions of the state table: no Instances, no randomness. Server (Game / Systems) and client (UI binders) both
-- read these, so the number the UI shows is the number the server charges. Every function names the playtest function
-- it mirrors; roblox/tools/parity holds the harness that keeps them at 100% parity.
--
-- State (Peckwood v3 save, see Game.migrate): wallet EN values live at the top of the state (s.popcorn, s.moneta, ...),
-- s.upgrades / s.sunflowerUpgrades = Birb's id -> level maps, s.sparrow = Birb's sparrow* fields, s.evo = the castle.
-- Later-phase multipliers (fish, nest, quests, sacrifice, red panda, ...) come in through Rules.hooks (default 1 / 0);
-- Game wires the systems that exist today into them.
local function dep(name: string)
	if script then return require(script.Parent:FindFirstChild(name) or script.Parent.Parent:FindFirstChild(name)) end
	return nil
end
local EN = (dep("EternityNum") or require("../EternityNum")) :: any
local D = (dep("Data") or require("./Data")) :: any

local R = {}
R.EN, R.Data = EN, D
local UP, SUN = D.UP_BY_ID, D.SUN_BY_ID

-- Birb currency id -> our wallet key (internal ids stay Birb's; only moneta was shortened)
R.CUR = { monetariaMoneta = "moneta" }
local function wkey(cur: string): string return R.CUR[cur] or cur end
R.wkey = wkey
-- the wallet keys a state carries (anything else is not a wallet currency)
R.WALLET = { popcorn = true, goldenFeathers = true, sunflowerSeeds = true, goldenPopcorn = true, bruteOre = true, twigs = true,
	echoPopcorn = true, moneta = true, skillPoints = true }

-- ---------------------------------------------------------------- hooks (later phases plug in here)
local ONE = function() return 1 end
local ZERO = function() return 0 end
R.hooks = {
	fishMult = ONE,              -- (s, type) PT.fishMult
	questBonus = ZERO,           -- (s, key)  PT.questBonus
	sacrificePopcorn = ONE,      -- (s)       PT.sacrificePopcornMult
	redPandaNap = ONE,           -- (s)       PT.redPandaNapMult
	flockCommunity = ONE,        -- (s)       PT.flockCommunityMult
	grainSilo = ONE,             -- (s)       PT.nestGrainSilo
	wateringWell = ONE,          -- (s)       PT.nestWellMult
	nestRespawn = ONE,           -- (s)       PT.nestRespawnMult
	nestSeedProd = ONE,          -- (s)       PT.nestSeedProdMult
	highestFishWeight = ZERO,    -- (s)       PT.highestFishWeight
	flockMemory = ONE,           -- (s, who)  PT.flockMemoryMult
	nestCanMigrate = nil,        -- (s)       PT.nestCanMigrate (nil: nest tier >= 1)
	mineArea = function(s) return (s.crow and s.crow.area) or 0 end,   -- PT.mineArea
	nestTier = function(s) return (s.nest and s.nest.tier) or 0 end,
	parrotRebirbs = function(s) return (s.parrot and s.parrot.rebirbCount) or 0 end,
	strangeKeys = function(s) return (s.parrot and s.parrot.strangeKeys) or 0 end,
	castleRescued = function(s) return s.expedition ~= nil and s.expedition.hasRescuedCastleMonster == true end,
	pickupBonus = ONE,           -- (s)       Peckwood extra on Birb's pickup radius (the Big Beak pass)
}
local H = R.hooks

-- JS `x || d`: 0, NaN, nil and false fall back to d
local function orv(x, d)
	if not x or x == 0 or x ~= x then return d end
	return x
end
R.orv = orv

-- ---------------------------------------------------------------- wallet (PT.res / PT.has / PT.add / PT.sub)
function R.res(s, cur: string) return s[wkey(cur)] or EN.ZERO end
function R.num(x) return EN.toNumber(x) end
function R.has(s, cur: string, v) return EN.meeq(R.res(s, cur), v) end
function R.add(s, cur: string, v) local k = wkey(cur); s[k] = EN.add(s[k] or EN.ZERO, v) end
function R.sub(s, cur: string, v) local k = wkey(cur); s[k] = EN.max(EN.ZERO, EN.sub(s[k] or EN.ZERO, v)) end

-- ---------------------------------------------------------------- sunflower nodes (PT.sunLevel / PT.hasSun)
function R.sunLevel(s, id: string): number
	if not SUN[id] then return 0 end
	return orv(s.sunflowerUpgrades and s.sunflowerUpgrades[id], 0)
end
function R.hasSun(s, id: string): boolean return R.sunLevel(s, id) >= 1 end
local hasSun = R.hasSun

-- ---------------------------------------------------------------- leveled upgrades (PT.maxLevel / level / effect)
function R.maxLevel(s, id: string): number
	local def = UP[id]
	if not def then return 0 end
	local n = def.maxLevel or 0
	if id == "pr_popcorn_mult" and hasSun(s, "d_pop_max_lvl") then n += 2 end
	if id == "p_move_speed" and hasSun(s, "d_wing_mastery_plus") then n += 10 end
	if id == "p_capacity" and hasSun(s, "d_silo_mastery_plus") then n += 10 end
	return n
end
-- p_/pr_/s_/m_ start at level 1 (p_auric_silo only with Auric Blueprints), everything else at 0
function R.level(s, id: string): number
	local def = UP[id]
	local saved = s.upgrades and s.upgrades[id]
	local t
	if def and def.initialLevel ~= nil then
		t = if saved ~= nil then saved else def.initialLevel
	elseif (id:sub(1, 2) == "p_" or id:sub(1, 3) == "pr_" or id:sub(1, 2) == "s_" or id:sub(1, 2) == "m_")
		and (id ~= "p_auric_silo" or hasSun(s, "d_desert_auric_blueprints")) then
		t = orv(saved, 1)
	else
		t = orv(saved, 0)
	end
	local m = R.maxLevel(s, id)
	return if m > 0 then math.min(t, m) else t
end
-- Birb's effect expressions (upgrades.json), level -> value
local EFFECT = {
	p_golden_popcorn_value = function(e) return e end,
	p_auric_silo = function(e) return 2 * e end,
	p_value = function(e) return e end,
	p_speed = function(e) return math.max(0.2, 2.6 - 0.2 * e) end,
	p_capacity = function(e) return 2 * e end,
	p_move_speed = function(e) return 1 + math.max(0, e - 1) * (1 / 19) end,
	pr_golden_popcorn_mult = function(e) return 2 ^ math.max(0, e - 1) end,
	pr_popcorn_mult = function(e) return 2 ^ (e - 1) end,
	pr_radius_mult = function(e) return 1 + 0.2 * e end,
	pr_respawn_mult = function(e) return 1 + 0.5 * math.max(0, e - 1) end,
	s_more_popcorn = function(e) return 1 + 0.2 * math.max(0, e - 1) end,
	s_more_feathers = function(e) return 1 + 0.2 * math.max(0, e - 1) end,
	s_more_seeds = function(e) return e end,
	-- mine rows (Phase 4 prices them; the effects are already Birb's)
	m_ore_value = function(e) return 1.1 ^ (e - 1) end,
	m_mining_power = function(e) return 1.1 ^ (e - 1) end,
	m_rupture = function(e) return 0.25 + 0.05 * math.min(15, e - 1) end,
	m_charged_strike = function(e) return 3 + math.min(3, e - 1) end,
}
R.EFFECT = EFFECT
function R.effect(s, id: string): number
	if not UP[id] then return 0 end
	local f = EFFECT[id]
	if not f then return 1 end   -- mine / echo effects arrive with their phases (playtest core: effectFn = () => 1)
	return f(R.level(s, id))
end

-- cost of the next level, charged at the current level L (PT.cost)
function R.cost(def, L: number): number
	local id = def.id
	if id == "p_echo_value" then
		local t = math.min(999, math.max(1, math.floor(L)))
		return math.floor(10 * 1.35 ^ math.min(24, t - 1) * 1.114 ^ math.min(75, math.max(0, t - 25)) * 1.14 ^ math.max(0, t - 100))
	end
	if id == "m_rupture" then return math.ceil(2e6 * 2.7 ^ (L - 1)) end
	if id == "m_charged_strike" then return 4800 * 24 ^ (L - 1) end
	if id == "p_value" then return if L < 5 then L else math.floor(4 * 1.3312 ^ (L - 4)) end
	local base = def.baseCost or def.cost or 0
	local mult = def.costMultiplier or 1
	local t = def.tree
	if t == "P" or t == "PR" or t == "S" or t == "M" then return math.floor(base * mult ^ math.max(0, L - (def.initialLevel or 1))) end
	return math.floor(base * mult ^ L)
end
-- PT.discounted: Auric Bargain makes golden-egg prices x0.75 (min 1)
function R.discounted(s, def, L: number): number
	local c = R.cost(def, L)
	if c > 0 and def.costCurrency == "goldenPopcorn" and hasSun(s, "d_desert_auric_bargain") then return math.max(1, math.floor(0.75 * c)) end
	return c
end
function R.upCost(s, id: string): number
	local def = UP[id]
	return if def then R.discounted(s, def, R.level(s, id)) else 0
end
-- d_free_seeds: seed purchases cost nothing (the balance is still checked)
function R.freeSeeds(s, cur: string): boolean return cur == "sunflowerSeeds" and hasSun(s, "d_free_seeds") end

-- which shop rows a player can see (playtest rowVisible / Birb's drawer): SEEDS rows once the Sunflower Machine is
-- owned, golden rows with their desert unlocks; the server refuses purchases of rows the drawer would not show
function R.rowVisible(s, id: string): boolean
	if not UP[id] then return false end
	if id == "p_golden_popcorn_value" then return s.hasUnlockedDesertMap == true or hasSun(s, "d_unlock_desert_tree") end
	if id == "p_auric_silo" then return hasSun(s, "d_desert_auric_blueprints") end
	if id == "pr_golden_popcorn_mult" then return hasSun(s, "d_desert_golden_popcorn_mult_unlock") end
	if id:sub(1, 2) == "s_" then return hasSun(s, "d_sunflower_machine") end
	if id:sub(1, 2) == "m_" or id:sub(1, 7) == "p_echo_" then return false end   -- their phases
	return true
end

-- ---------------------------------------------------------------- sunflower tree rules (PT.sunParents ... PT.sunCost)
function R.sunParents(id: string) local n = SUN[id]; return if n then n.parents else {} end
local function chainConnected(s, id: string, memo): boolean
	local m = memo[id]
	if m ~= nil then return m end
	local n = SUN[id]
	if not n then memo[id] = false; return false end
	local ps = n.parents
	local r
	if (n.permanent and (n.mineAreaRequired or id == "d_unlock_archivist_tree") and hasSun(s, id)) or #ps == 0 then
		r = true
	elseif n.needsAll then
		r = true
		for _, p in ps do if not (hasSun(s, p) and chainConnected(s, p, memo)) then r = false; break end end
	else
		r = false
		for _, p in ps do if hasSun(s, p) and chainConnected(s, p, memo) then r = true; break end end
	end
	memo[id] = r
	return r
end
function R.chainConnected(s, id: string): boolean return chainConnected(s, id, {}) end
local function parentsOk(s, n, memo): boolean
	local ps = n.parents
	if n.needsAll then
		for _, p in ps do if not (hasSun(s, p) and chainConnected(s, p, memo)) then return false end end
		return true
	end
	for _, p in ps do if hasSun(s, p) and chainConnected(s, p, memo) then return true end end
	return false
end
function R.sunUnlocked(s, id: string): boolean
	if id == "d_unlock_archivist_tree" and hasSun(s, id) then return true end
	local n = SUN[id]
	if not n then return false end
	if (n.mineAreaRequired or 0) > H.mineArea(s) then return false end
	if orv(n.evolutionRequired, 0) ~= 0 and (s.evolutionCount or 0) < n.evolutionRequired then return false end
	if orv(n.nestTierRequired, 0) ~= 0 and (H.nestTier(s) + 1) < n.nestTierRequired then return false end
	if orv(n.parrotRebirbRequired, 0) ~= 0 and H.parrotRebirbs(s) < n.parrotRebirbRequired then return false end
	if #n.parents == 0 then return true end
	return parentsOk(s, n, {})
end
-- nodes show one evolution early if their parent chain is owned (PT.sunVisible)
function R.sunVisible(s, id: string): boolean
	local t = SUN[id]
	if not t then return false end
	if not t.requires then return true end
	local n, need = s.evolutionCount or 0, t.evolutionRequired or 0
	if need > n + 1 then return false end
	local function parentOk()
		if #t.parents == 0 then return true end
		local memo = {}
		for _, p in t.parents do if hasSun(s, p) and chainConnected(s, p, memo) then return true end end
		return false
	end
	if need > n then return parentOk() end
	if hasSun(s, id) then return R.chainConnected(s, id) end
	return parentOk()
end
function R.sunCost(s, id: string): number
	local n = SUN[id]
	if not n then return 0 end
	return R.discounted(s, n, R.sunLevel(s, id))
end
function R.sunMax(id: string): number local n = SUN[id]; return if n then n.maxLevel or 1 else 0 end

-- ---------------------------------------------------------------- egg types (Birb Wc)
R.TYPES = {
	{ id = "plain", baseValue = 1, weight = 100 },
	{ id = "butter", baseValue = 2, weight = 20 },
	{ id = "caramel", baseValue = 10, weight = 5 },
	{ id = "cheese", baseValue = 25, weight = 1 },
	{ id = "rainbow", baseValue = 100, weight = 0.1 },
	{ id = "red", baseValue = 100, weight = 0.01 },
	{ id = "golden", baseValue = 1, weight = 0 },
}
R.TYPE_BY_ID = {}
for i, t in R.TYPES do t.index = i; R.TYPE_BY_ID[t.id] = t end
-- the roll weights (PT.Field.rollType), in TYPES order, and their sum
function R.typeWeights(s)
	local w, sum = {}, 0
	for i, ty in R.TYPES do
		local t = ty.weight
		if ty.id == "cheese" and hasSun(s, "d_cheese_powder") then t *= 1.5 end
		if ty.id == "rainbow" then t += R.level(s, "f_rainbow_chance"); if hasSun(s, "d_rainbow_aura") then t *= 2 end end
		if ty.id == "butter" and hasSun(s, "d_butter_bonanza") then t *= 1.5 end
		w[i] = t; sum += t
	end
	return w, sum
end
-- one roll from a uniform u in [0, 1)
function R.rollType(s, u: number): string
	local w, sum = R.typeWeights(s)
	local r = u * sum
	for i, ty in R.TYPES do r -= w[i]; if r <= 0 then return ty.id end end
	return "plain"
end

-- ---------------------------------------------------------------- multipliers (PT.totalMultiplier ...)
local function logCurve(x, t: number, i: number, a: number): number   -- Birb fo / $r: a + i * log10(x / t + 1)
	return a + i * EN.toNumber(EN.log10(EN.add(EN.div(x, t), 1)))
end
local function sqrtBoost(x: number, k: number, cap: number?): number    -- Birb yI
	local v = 1 + math.sqrt(math.max(0, x)) * k
	return if cap and cap ~= 0 then math.min(cap, v) else v
end
R.sqrtBoost = sqrtBoost
local function evoMult(s) local e = s.evolutionCount or 0; return if e >= 2 then e else 1 end

local SP = { xpPerLevel = 40, base = 150, growth = 2, max = 2048, full = 16 }
R.SP = SP
local function sparrowFeaturesOn(s) return (s.evolutionCount or 0) >= 2 end   -- Birb KH
function R.sparrowDrainMult(s): number
	return if sparrowFeaturesOn(s) then 1 + (2.5 * math.log(1 + (s.sparrow.resonanceXP or 0) / 5e3)) / math.log(40.6) else 1
end

function R.totalMultiplier(s): number
	local t = 1
	t *= orv(R.effect(s, "p_value"), 1)
	t *= orv(R.effect(s, "pr_popcorn_mult"), 1)
	t *= orv(R.effect(s, "s_more_popcorn"), 1)
	if hasSun(s, "d_butter_hose") then t *= 1.5 end
	if hasSun(s, "d_kernel_polish") then t *= 2 end
	t *= H.fishMult(s, "popcorn_mult")
	if (s.evolutionCount or 0) >= 2 then t *= s.evolutionCount end
	if hasSun(s, "d_seed_synergy") then t *= 1 + 1.3 * math.log10(1 + EN.toNumber(R.res(s, "sunflowerSeeds")) / 5e4) end
	t *= math.max(1, H.grainSilo(s))
	if hasSun(s, "d_trophy_bonus") then t *= 1 + 3 * math.log10(1 + H.highestFishWeight(s)) end
	t *= R.sparrowDrainMult(s)
	if hasSun(s, "d_golden_butter") then t *= 1 + 0.5 * math.log10(EN.toNumber(R.res(s, "goldenFeathers")) + 1) end
	t *= H.sacrificePopcorn(s)
	t *= 1 + H.questBonus(s, "popcorn_gain_mult")
	return t * H.redPandaNap(s) * H.wateringWell(s) * H.flockCommunity(s)
end
function R.collectionMultiplier(s): number
	return R.totalMultiplier(s) * (if hasSun(s, "d_desert_popcorn_gain_x2") then 2 else 1)
end
function R.maxPopcorn(s): number
	local t = orv(R.effect(s, "p_capacity"), 0) + orv(hasSun(s, "d_desert_auric_blueprints") and R.effect(s, "p_auric_silo"), 0)
	local n = if hasSun(s, "d_popcorn_cap") then 2 else 1
	if hasSun(s, "d_void_silo") then n *= 1.1 end
	return math.floor(t * n)
end
function R.spawnInterval(s): number
	local t = orv(R.effect(s, "p_speed"), 2.6) / orv(R.effect(s, "pr_respawn_mult"), 1)
	if hasSun(s, "d_quantum_corn") then t /= 1.2 end
	t /= math.max(sqrtBoost(s.sparrow.prestigeCount or 0, 1.5, 10), 1)
	return t / H.nestRespawn(s)
end
-- pickup radius in Birb px (Peckwood: 1 px = Map.PX / S studs^-1, i.e. px / 16 * 4 studs)
function R.pickupProfile(s, out)
	local e = orv(R.effect(s, "pr_radius_mult"), 1)
	local t = if hasSun(s, "d_pickup_range") then 1.25 else 1
	local i = if hasSun(s, "d_focus_training") then 1.3 else 1
	local a = 1 + H.questBonus(s, "pickup_radius_mult")
	local n = math.max(1, 40 * e * t * i * a)
	local m = math.max(1, H.fishMult(s, "pickup_mult"))
	local lg = math.log(m, 2)
	local r = n * (1 + 0.35 * lg)
	local o = math.max(0, n * m - r)
	local p = out or {}
	p.collectRadius, p.magnetRadius, p.magnetSpeed = r, r + math.min(n, math.sqrt(o * n)), if m > 1 then math.min(420, 160 + 70 * lg) else 0
	return p
end
-- the older 70 px radius Gravity Field pulls within (playtest main.js legacyRadius)
function R.legacyRadius(s): number
	local me = 70
	local ge = R.level(s, "pr_radius_mult")
	if ge > 0 then me *= 1 + 0.2 * (ge - 1) end
	if hasSun(s, "d_pickup_range") then me *= 1.25 end
	return me
end
-- movement (Birb BASE_MAX_SPEED 168 px/s, BASE_ACCELERATION 500)
function R.speedMult(s): number
	return orv(R.effect(s, "s_speed_boost"), 1) * orv(R.effect(s, "p_move_speed"), 1) * (if hasSun(s, "d_swift_wings") then 1.3 else 1)
		* (if hasSun(s, "d_platinum_wings") then 1.15 else 1) * H.fishMult(s, "speed_mult")
end
function R.maxSpeed(s): number return 168 * R.speedMult(s) end

-- ---------------------------------------------------------------- Molt (PT.prestige)
function R.playtimeMult(s): number
	return if hasSun(s, "d_rebirth_playtime") then math.min(10, 1 + 0.01 * (s.stats.playTime / 60)) else 1
end
local function auricRebirb(s): number   -- archivist node (echo phase)
	if not hasSun(s, "d_archivist_auric_rebirb") then return 1 end
	local i = math.log10(EN.toNumber(R.res(s, "goldenPopcorn")) + 1) / 16
	return 1 + (if i <= 1 then 6 * i else 6 * (1 + math.log(1 + (i - 1)) / 10))
end
function R.prestigePayoutMult(s): number
	return H.fishMult(s, "feather_mult") * (if (s.evolutionCount or 0) >= 2 then s.evolutionCount else 1) * auricRebirb(s)
end
-- returns final (EN), plus base (EN), a, pay, play
function R.prestige(s)
	local base = EN.floor(EN.div(R.res(s, "popcorn"), 1000))
	local play = R.playtimeMult(s)
	local fe = orv(R.level(s, "s_more_feathers") > 0 and R.effect(s, "s_more_feathers"), 1)
	local a = play + (fe - 1)
	if hasSun(s, "d_golden_harvest") then a *= 3 end
	if hasSun(s, "d_desert_rebirb_golden_feathers") then a *= 2 end
	a *= 1 + H.questBonus(s, "feather_gain_mult")
	local pay = R.prestigePayoutMult(s)
	return EN.floor(EN.mul(EN.mul(base, a), pay)), base, a, pay, play
end

-- ---------------------------------------------------------------- seeds (PT.seedRate)
function R.seedRate(s, onPlatform: boolean): (number, number)
	if not hasSun(s, "d_sunflower_machine") then return 0, 0 end
	if not (onPlatform or hasSun(s, "d_auto_gen")) then return 0, 0 end
	local a = 1
	if hasSun(s, "d_faster_seeds") then a *= 2 end
	if hasSun(s, "d_seed_pipeline") then a *= 1.25 end
	a *= H.nestSeedProd(s)
	local m = if hasSun(s, "d_seed_multiplier") then logCurve(R.res(s, "goldenFeathers"), 2e4, 0.8, 1) else 1
	local r = R.level(s, "s_more_seeds")
	if r > 0 then m *= r end
	if hasSun(s, "d_golden_harvest") then m *= 3 end
	if hasSun(s, "d_seed_bag") then m *= 1.5 end
	if hasSun(s, "d_fish_seeds") then m *= logCurve(s.stats.fishCaught or 0, 10, 1.4, 1) end
	local desertSeed = 1
	for _, id in { "d_desert_seed_generation_x2", "d_desert_seed_generation_x5", "d_desert_seed_generation_x2_plus", "d_desert_bountiful_harvest" } do
		if hasSun(s, id) then desertSeed *= 2 end
	end
	local perTick = m * H.fishMult(s, "seed_mult") * evoMult(s) * R.sparrowDrainMult(s) * (1 + H.questBonus(s, "seed_gain_mult")) * H.flockCommunity(s)
		* desertSeed * H.redPandaNap(s) * H.grainSilo(s)
	return a, perTick
end

-- ---------------------------------------------------------------- Sparrow formulas (Birb fz, sz, oz, ZH)
R.SPARROW_MILESTONES = {
	{ id = "resonance_flow", name = "Resonance Flow", type = "mitoses", req = 1, eff = "drained_xp_mult", val = 1.25, text = "1 mitosis: drained XP x1.25" },
	{ id = "steady_feeder", name = "Steady Feeder", type = "level", req = 50, eff = "seed_feed_xp_mult", val = 1.5, text = "Reach LV 50: feed XP x1.5" },
	{ id = "mitosis_rhythm", name = "Mitosis Rhythm", type = "mitoses", req = 2, eff = "mitosis_requirement_mult", val = 0.8, text = "2 mitoses: mitosis needs x0.8" },
	{ id = "full_flock", name = "Full Flock", type = "mitoses", req = 3, eff = "seed_feed_xp_mult", val = 1.25, text = "3 mitoses: feed XP x1.25" },
	{ id = "first_rebirb", name = "First Rebirb", type = "rebirbs", req = 1, eff = "drained_xp_mult", val = 1.25, auto = "mitosis", text = "1 rebirb: drained XP x1.25, auto mitosis" },
	{ id = "loop_engine", name = "Loop Engine", type = "rebirbs", req = 5, eff = "mitosis_requirement_mult", val = 0.85, auto = "rebirb", text = "5 rebirbs: mitosis needs x0.85, auto rebirb" },
}
R.sparrowFeaturesOn = sparrowFeaturesOn
function R.mitosisCount(s): number
	local sp = s.sparrow
	return (sp.prestigeCount or 0) * (math.log(SP.full, 2)) + math.max(0, math.floor(math.log(math.max(1, math.min(SP.full, sp.count or 1)), 2)))
end
function R.milestoneMet(s, m): boolean
	if not sparrowFeaturesOn(s) then return false end
	local sp = s.sparrow
	if m.type == "level" then return math.max(sp.level or 1, sp.maxLevelReached or 1) >= m.req end
	if m.type == "mitoses" then return R.mitosisCount(s) >= m.req end
	return (sp.prestigeCount or 0) >= m.req
end
function R.milestoneMult(s, eff: string): number
	local n = 1
	for _, m in R.SPARROW_MILESTONES do if m.eff == eff and R.milestoneMet(s, m) then n *= m.val end end
	return n
end
function R.sparrowXpNeeded(L: number?): number
	local i = math.max(1, math.floor(orv(L, 0)))
	if i <= 100 then return i * SP.xpPerLevel end
	local a = i - 100
	return math.floor(SP.xpPerLevel * (100 + a * a))
end
function R.sparrowTotalXp(L: number, xp: number): number
	local t = xp
	for a = 1, L - 1 do t += R.sparrowXpNeeded(a) end
	return t
end
function R.mitosisNeed(s, count: number?): number
	local t = math.max(1, math.floor(orv(count, 1)))
	local n = if t == 1 then 1e4 elseif t == 2 then 1e5 elseif t == 4 then 1e6 elseif t == 8 then 1e7 elseif t >= SP.full then 16e6 else 5e5 * t
	return math.max(1, math.floor(n * R.milestoneMult(s, "mitosis_requirement_mult")))
end
function R.sparrowSpeed(s): number
	return math.min(SP.base + (s.sparrow.level - 1) * SP.growth, SP.max * (if hasSun(s, "d_hive_mind") then 1.5 else 1))
end
function R.sparrowRebirbBoost(s): number return sqrtBoost(s.sparrow.prestigeCount or 0, 1.5, 10) end
-- Birb uz (seed feed XP per seed) / the pickup XP multiplier (the same minus the feed milestone)
function R.sparrowXpMult(s, feed: boolean): number
	local t = if feed then 0.01 else 1
	if hasSun(s, "d_sparrow_xp_2") then t *= 1.25 end
	if hasSun(s, "d_sparrow_snacks") then t *= 1.5 end
	if hasSun(s, "d_sparrow_wisdom") then t *= 1.5 end
	t *= sqrtBoost(s.sparrow.prestigeCount or 0, 2)
	if feed then t *= R.milestoneMult(s, "seed_feed_xp_mult") end
	t *= H.flockMemory(s, "sparrow")
	return t
end
function R.seedFeedXp(s): number return R.sparrowXpMult(s, true) end
function R.seedCostPerUnit(s): number return if hasSun(s, "d_sparrow_xp_2") then 0.75 else 1 end
-- XP a sparrow gets per egg type it collects
R.SPARROW_EGG_XP = { butter = 2, caramel = 3, cheese = 5, rainbow = 10, golden = 10 }
function R.sparrowRebirbReady(s): boolean
	if H.nestCanMigrate then return H.nestCanMigrate(s) end
	return H.nestTier(s) >= 1
end
function R.sparrowAutoUnlocked(s, kind: string): boolean
	for _, m in R.SPARROW_MILESTONES do if m.auto == kind and R.milestoneMet(s, m) then return true end end
	return false
end

-- ---------------------------------------------------------------- Castle (Birb sR.feedMonster / _h)
R.EVO_REQ = {
	{ popcorn = 1e7, feathers = 0, seeds = 0, fish = 0, twigs = 0, moneta = 0 },
	{ popcorn = 1e10, feathers = 0, seeds = 0, fish = 0, twigs = 0, moneta = 1e3 },
	{ popcorn = 25e10, feathers = 0, seeds = 3e7, fish = 0, twigs = 0, moneta = 0 },
	{ popcorn = 1e15, feathers = 0, seeds = 0, fish = 0, twigs = 1e5, moneta = 1e4 },
	{ popcorn = 1e18, feathers = 0, seeds = 0, fish = 0, twigs = 1e6, moneta = 0 },
}
R.EVO_KEYS = { "popcorn", "feathers", "seeds", "fish", "twigs", "moneta" }   -- feed order
R.EVO_CUR = { popcorn = "popcorn", feathers = "goldenFeathers", seeds = "sunflowerSeeds", twigs = "twigs", moneta = "moneta" }
local ZERO_REQ = { popcorn = 0, feathers = 0, seeds = 0, fish = 0, twigs = 0, moneta = 0 }
function R.evoReq(n: number?)
	return R.EVO_REQ[math.max(0, math.floor(orv(n, 0))) + 1] or ZERO_REQ
end
function R.evoCap(s): number return if H.castleRescued(s) then 6 else 5 end
function R.canEvolveStage(s): boolean
	local e = s.evolutionCount or 0
	return not (e >= R.evoCap(s)) and (e ~= 0 or hasSun(s, "d_unlock_evolve"))
end
function R.feedProgress(s): number
	local e = s.evolutionCount or 0
	if e == 5 then return if H.castleRescued(s) then 100 else 0 end
	local t = R.evoReq(e)
	local fed = s.evo.fed
	local a, r = 0, 0
	for _, k in R.EVO_KEYS do
		local o = t[k]
		if o > 0 then a += math.min(1, math.max(0, orv(tonumber(fed[k]), 0)) / o); r += 1 end
	end
	return if r > 0 then (a / r) * 100 else 0
end
-- ids an evolution keeps besides permanent nodes
R.KEEP_SUN = { d_unlock_evolve = true, d_unlock_desert_tree = true, d_double_catch = true, d_seagull_synergy = true }

return R
