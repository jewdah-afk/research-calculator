--!nonstrict
-- Defs: every buyable row in the Peckwood windows, bound to the verified Birb math
-- (BirbFormulas / BirbSystems / Data/Upgrades.json). Server and client both read this,
-- so the price the client shows is the price the server charges.
-- loads in Roblox (ModuleScripts) and in lune (roblox/tools/parity): sibling modules by name, Data/*.json via @lune/fs
local function sib(name: string)
	if script then return require(script.Parent:WaitForChild(name)) end
	return require("./" .. name)
end
local F = sib("BirbFormulas")
local S = sib("BirbSystems")
local R = (if script then require(script.Parent:WaitForChild("Birb"):WaitForChild("Rules")) else require("./Birb/Rules")) :: any
local EN = F.EN
local function json(name: string)
	if script then return require(script.Parent.Data[name]) end
	local fs, serde = require("@lune/fs") :: any, require("@lune/serde") :: any
	local dir = string.match(debug.info(1, "s"), "^(.*)[\\/]")
	return serde.decode("json", fs.readFile(dir .. "/Data/" .. name .. ".json"))
end

local Defs = {}
Defs.F, Defs.S, Defs.EN = F, S, EN

-- currency key -> HUD name + icon
Defs.CUR = {
	popcorn = { name = "Eggs", icon = "popcorn" },
	goldenFeathers = { name = "Plumes", icon = "plume" },
	sunflowerSeeds = { name = "Seeds", icon = "seed" },
	goldenPopcorn = { name = "Golden", icon = "golden" },
	bruteOre = { name = "Brute Ore", icon = "ore" },
	twigs = { name = "Twigs", icon = "twig" },
	echoPopcorn = { name = "Echo", icon = "echo" },
	moneta = { name = "Moneta", icon = "moneta" },
	skillPoints = { name = "Skill Points", icon = "skill_point" },
}
Defs.CUR_ORDER = { "popcorn", "goldenFeathers", "sunflowerSeeds", "goldenPopcorn", "bruteOre", "twigs", "echoPopcorn", "moneta", "skillPoints" }

-- raw upgrades.json rows by id
local RAW = {}
for _, d in json("Upgrades") do RAW[d.id] = d end
Defs.RAW = RAW

-- big-safe multipliers: plain decimals below 1e6, EternityNum short form above (never a 300-digit string)
local function x2(n: any) if type(n) ~= "number" or n >= 1e6 then return "x" .. EN.short(n) end return string.format("x%.2f", n) end
local function x1(n: any) if type(n) ~= "number" or n >= 1e6 then return "x" .. EN.short(n) end return string.format("x%.1f", n) end
local function short(n: any) return EN.short(n) end

-- Shop rows. cost(L) is charged at the CURRENT internal level L (F.level semantics).
-- fx(L) returns the display string of the effect AT level L.
local UP = {}
Defs.UP = UP
Defs.R = R
local NO_STATE = { upgrades = {}, sunflowerUpgrades = {} }
local function up(id: string, t)
	t.id = id
	local raw = RAW[id]
	local birb = R.Data.UP_BY_ID[id]
	if birb and birb.tree ~= "M" and id:sub(1, 7) ~= "p_echo_" then
		-- Birb Phase 1 rows: price, level and max come from shared/Birb/Rules (the parity-checked port)
		t.cur = t.cur or R.wkey(birb.costCurrency)
		t.max = t.max or birb.maxLevel or 1
		t.raw = raw or birb
		t.birb = birb
		t.cost = t.cost or function(L, s) return R.discounted(s or NO_STATE, birb, L) end
	elseif raw then
		t.cur = t.cur or raw.costCurrency
		t.max = t.max or raw.maxLevel or 1
		t.raw = raw
		t.cost = t.cost or function(L, s) return F.discountedCost(s or {}, raw, L) end
	end
	UP[id] = t
	return t
end

-- Popcorn (layer 0, Molt resets)
up("p_value", { name = "Egg Value", desc = "Each egg is worth more.", icon = "popcorn", fx = function(L) return tostring(L) end, layer = "popcorn" })
up("p_speed", { name = "Faster Eggs", desc = "Eggs pop up more often.", icon = "clock", fx = function(L) return string.format("%.1fs", F.spawnTime(L)) end, layer = "popcorn" })
up("p_capacity", { name = "Egg Cap", desc = "More eggs on the field.", icon = "popcorn", fx = function(L) return "+" .. F.capacity(L) end, layer = "popcorn" })
up("p_move_speed", { name = "Wing Training", desc = "Hop around quicker.", icon = "wing", fx = function(L) return math.floor(100 * F.wingSpeed(L)) .. "%" end, layer = "popcorn" })
-- Molt keepsakes (permanent)
up("pr_popcorn_mult", { name = "Golden Down", desc = "Egg gain, forever.", icon = "plume", fx = function(L) return "x" .. short(F.popcornMult(L)) end })
up("pr_radius_mult", { name = "Long Neck", desc = "Pickup radius, forever.", icon = "magnet", fx = function(L) return x2(1 + 0.2 * math.max(0, L - 1)) end })
up("pr_respawn_mult", { name = "Quick Pop", desc = "Eggs respawn faster.", icon = "clock", fx = function(L) return x2(F.respawnMult(L)) end })
-- Seeds (Evolve resets)
up("s_more_popcorn", { name = "More Eggs", desc = "Egg gain per pickup.", icon = "popcorn", fx = function(L) return x1(F.morePopcorn(L)) end, layer = "seeds" })
up("s_more_feathers", { name = "More Plumes", desc = "Plumes from every Molt.", icon = "plume", fx = function(L) return x1(F.moreFeathers(L)) end, layer = "seeds" })
up("s_more_seeds", { name = "More Seeds", desc = "Sunflowers grow more seeds.", icon = "seed", fx = function(L) return "x" .. F.moreSeeds(L) end, layer = "seeds" })
-- Golden (desert)
up("p_golden_popcorn_value", { name = "Golden Value", desc = "More golden per drop.", icon = "golden", fx = function(L) return tostring(L) end, layer = "popcorn" })
up("p_auric_silo", { name = "Auric Silo", desc = "Raises the egg cap.", icon = "popcorn", fx = function(L) return "+" .. 2 * L end, layer = "popcorn" })
up("d_desert_field_notes_plus", { name = "Gilded Margins", desc = "+33% golden per level.", icon = "golden", fx = function(L) return x2(1 + L / 3) end })
-- Mine (Evolve resets); verified stepped-anchor costs from BirbSystems
local function mineCost(id) return function(L) return S.mineCost(id, L) end end
up("m_mining_power", { name = "Mining Power", desc = "Birb and Crow hit ore harder.", icon = "pickaxe", cost = mineCost("m_mining_power"), fx = function(L) return x2(EN.pow(1.1, math.max(0, L - 1))):sub(2) end, layer = "mine" })
up("m_ore_value", { name = "Ore Value", desc = "More ore per HP removed.", icon = "ore", cost = mineCost("m_ore_value"), fx = function(L) return x2(EN.pow(1.1, math.max(0, L - 1))) end, layer = "mine" })
up("m_charged_strike", { name = "Charged Strike", desc = "+1x to Crow's charged peck.", icon = "crow", cost = mineCost("m_charged_strike"), fx = function(L) return "x" .. S.chargedStrikeEffect(L) end, layer = "mine" })
up("m_rupture", { name = "Rupture", desc = "+5% break bonus per level.", icon = "sword", cost = mineCost("m_rupture"), fx = function(L) return "+" .. math.round(100 * S.ruptureEffect(L)) .. "%" end, layer = "mine" })
-- Nest twig shop (kept through Molt and Evolve). Internal level starts at 0.
up("n_twig_value", { name = "Twig Value", desc = "More twigs per hit.", icon = "twig", cur = "twigs", max = 999, start = 0, cost = function(L) return S.twigValueCost(L) end, fx = function(L) return x1(1 + 0.2 * L) end })
up("n_peck_rate", { name = "Peck Rate", desc = "Birb pecks trees faster.", icon = "clock", cur = "twigs", max = 20, start = 0, cost = function(L) return S.peckRateCost(L) end, fx = function(L) return "+" .. string.format("%g", 0.2 * L) .. "/s" end })
up("n_peck_power", { name = "Peck Power", desc = "+1 damage per peck.", icon = "wood", cur = "twigs", max = 15, start = 0, cost = function(L) return S.peckPowerCost(L) end, fx = function(L) return tostring(1 + L) end })
-- Echo field (Molt resets)
up("p_echo_value", { name = "Echo Value", desc = "More echo eggs per echo.", icon = "echo", cur = "echoPopcorn", max = 999, cost = function(L) return F.cost({ id = "p_echo_value" }, L) end, fx = function(L) return tostring(L) end, layer = "popcorn" })
up("e_echo_capacity", { name = "Echo Capacity", desc = "Raises the echo egg cap.", icon = "mushroom", cur = "echoPopcorn", max = 10, start = 1, cost = function(L) return math.floor(20 * 1.65 ^ (L - 1)) end, fx = function(L) return "+" .. (2 + 2 * (L - 1)) end, layer = "popcorn" })
-- Dave seed training (seeds)
up("dave_training", { name = "Seed Training", desc = "Dave forages faster.", icon = "seed", cur = "sunflowerSeeds", max = 50, start = 0, cost = function(L) return S.daveSeedTrainingCost(L) end, fx = function(L) return x2(1 + 0.02 * math.min(50, L)) end })

-- internal level for any row (F.level handles the p_/pr_/s_/m_ start-at-1 rule)
function Defs.level(s, id: string): number
	local d = UP[id]
	if d and d.birb then return R.level(s, id) end
	if id:sub(1, 2) == "d_" then return R.sunLevel(s, id) end   -- leveled tree nodes (Gilded Margins)
	if d and d.start ~= nil then
		local v = s.upgrades and s.upgrades[id]
		return if v ~= nil then v else d.start
	end
	return F.level(s, id)
end
function Defs.maxLevel(s, id: string): number
	local d = UP[id]
	if d.birb then return R.maxLevel(s, id) end
	if d.raw then return F.maxLevel(s, d.raw) end
	return d.max
end
function Defs.cost(s, id: string, L: number?): number
	local d = UP[id]
	return d.cost(L or Defs.level(s, id), s)
end
-- display level (Peckwood shows internal - 1 for the start-at-1 trees)
function Defs.shownLevel(s, id: string): (number, number)
	local d = UP[id]
	local startsAt1 = (d.start == nil and (id:sub(1, 2) == "p_" or id:sub(1, 3) == "pr_" or id:sub(1, 2) == "s_" or id:sub(1, 2) == "m_")) or d.start == 1
	local off = if startsAt1 then 1 else 0
	return Defs.level(s, id) - off, Defs.maxLevel(s, id) - off
end

-- ---------------------------------------------------------------- data tables
Defs.FISH = json("fish")
Defs.RODS = json("rods")
Defs.BAITS = json("baits")
Defs.QUESTS = json("quests")
Defs.SACRIFICE = json("sacrifice_milestones")
Defs.FISH_BY_ID = {}
for i, f in Defs.FISH do Defs.FISH_BY_ID[f.id] = f; f.index = i end
Defs.ROD_BY_ID = {}
for i, r in Defs.RODS do Defs.ROD_BY_ID[r.id] = r; r.index = i end

-- Evolution feed table (SYSTEMS.md "Evolution"; the live one is Rules.EVO_REQ, keyed popcorn / feathers / seeds /
-- fish / twigs / moneta). Kept in the wallet-key shape for older readers.
Defs.EVO = {
	{ popcorn = 1e7 },
	{ popcorn = 1e10, moneta = 1000 },
	{ popcorn = 2.5e11, sunflowerSeeds = 3e7 },
	{ popcorn = 1e15, twigs = 1e5, moneta = 1e4 },
	{ popcorn = 1e18, twigs = 1e6 },
}
Defs.NEST_TIERS = {
	{ name = "Basic", next = 1e5, mult = 1 }, { name = "Sturdy", next = 1e6, mult = 2 },
	{ name = "Cozy", next = 1e8, mult = 5 }, { name = "Grand", next = 2e10, mult = 10 },
}

-- ---------------------------------------------------------------- progression ("islands")
-- The order the dev "Next island" toggle walks, and the order the HUD reveals windows.
-- Order follows the original game (Park -> Molt -> Garden -> Evolve -> Bridge -> Nest -> Mine -> Desert -> Expedition -> Echo).
-- goal = the objective line shown while this island is the next one; gate(s) = unlocked?
local function evo(s) return s.evolutionCount or 0 end
Defs.ISLANDS = {
	{ id = "park", name = "THE PARK", windows = { "popcorn", "profile" }, goal = "Collect eggs", gate = function() return true end },
	{ id = "molt", name = "THE PARK", windows = { "molt" }, goal = "Hold 1,000 eggs to unlock Molt", gate = function(s) return (s.stats.bestPopcorn or 0) >= 1000 or (s.rebirbCount or 0) > 0 end },
	{ id = "garden", name = "THE GARDEN", windows = { "seeds", "trees" }, goal = "Molt for Plumes: 1 Plume per 1,000 eggs you hold", gate = function(s) return (s.rebirbCount or 0) > 0 end },
	-- Birb: the way to the castle opens with Unlock Evolve, a sunflower-tree node (100M eggs, after Golden Harvest)
	{ id = "castle", name = "THE CASTLE", windows = { "evolve" }, goal = "Buy Unlock Evolve in the sunflower tree", gate = function(s) return R.hasSun(s, "d_unlock_evolve") end },
	-- Birb unlocks the Sparrow at Evolution 1
	{ id = "bridge", name = "THE BRIDGE", windows = { "rods", "baits", "index", "aquarium", "seagull", "sparrow" }, goal = "Evolve once to open the Bridge", gate = function(s) return evo(s) >= 1 end },
	{ id = "forest", name = "THE FOREST", windows = { "nest", "redpanda" }, goal = "Reach Evolution 2 to open the Forest", gate = function(s) return evo(s) >= 2 end },
	{ id = "mine", name = "THE MINE", windows = { "mine" }, goal = "Reach Evolution 3 to open the Mine", gate = function(s) return evo(s) >= 3 end },
	{ id = "desert", name = "THE DESERT", windows = { "golden", "dave" }, goal = "Reach Evolution 4 to open the Desert", gate = function(s) return evo(s) >= 4 end },
	{ id = "expedition", name = "THE EXPEDITION", windows = { "parrot", "quests", "sacrifice" }, goal = "Build the Sturdy nest (100K twigs) for expeditions", gate = function(s) return (s.nest.tier or 0) >= 1 end },
	{ id = "echo", name = "THE ECHO FIELD", windows = { "echo" }, goal = "Reach Evolution 5 to open the Echo Field", gate = function(s) return evo(s) >= 5 end },
}
Defs.WINDOW_ISLAND = {}
for i, isl in Defs.ISLANDS do for _, w in isl.windows do Defs.WINDOW_ISLAND[w] = i end end

return Defs
