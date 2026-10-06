--!nonstrict
-- Birb non-core systems, ported 1:1 from the birbplay.com build (see SYSTEMS.md).
-- Pure math only: every function takes plain numbers/tables and returns numbers.

local S = {}

local MAX = 1.7976931348623157e308
local function cap(x: number): number return math.min(MAX, x) end
local function nn(x: number?): number -- non-negative floor (game helper `na`)
	if x == nil or x ~= x or x == math.huge or x == -math.huge then return 0 end
	return math.max(0, math.floor(x))
end

--------------------------------------------------------------------------- Mining
S.POWER_ANCHORS = { 240, 14400, 967680, 65028096, 4369888051, 293656477041, 19733715257131, 1326105665279205 }
S.VALUE_ANCHORS = { 180, 9e3, 504e3, 28224e3, 1580544e3, 88510464e3, 4956585984e3, 277568815104000 }
S.HP_TABLE = { 10, 100, 1e3, 1e4, 1e5, 1e6, 1e7 }
S.GIANT_TABLE = { 360, 2600, 13e4, 18e5, 21e6, 285e6, 18e8 }
S.MILESTONE_LEVELS = { 7, 17, 34, 47, 60, 73, 86 }
local K = 1.1 / 1.15
local J = {}
for i, lvl in S.MILESTONE_LEVELS do J[i] = K ^ (lvl - 1) end

local POWER_ANCHORS_EXT = table.clone(S.POWER_ANCHORS)
table.insert(POWER_ANCHORS_EXT, 36 * S.POWER_ANCHORS[8])

-- anchor(table, n, g): table[n] (0-based) or extrapolated by g per step past the end
local function anchor(t, n: number, g: number): number
	local a = nn(n)
	if a < #t then return cap(t[a + 1]) end
	return cap(t[#t] * g ^ (a - #t + 1))
end
S.anchor = anchor

local function stepped(t, L: number, step: number, g: number): number
	local r = math.floor(L / step)
	local lo, hi = anchor(t, r, g), anchor(t, r + 1, g)
	return cap(math.ceil(lo * (hi / lo) ^ ((L % step) / step)))
end

local function areaCurve(t, a: number): number
	local i = nn(a)
	local m = math.min(i, #t - 1)
	return math.max(1, cap(t[m + 1] * J[m + 1] * 5.8 ^ (i - m)))
end

-- Mine shop cost at current level L
function S.mineCost(id: string, L: number): number?
	local n = nn(L - 1)
	if id == "m_mining_power" then return stepped(POWER_ANCHORS_EXT, n, 12, 400) end
	if id == "m_ore_value" then return stepped(S.VALUE_ANCHORS, n, 10, 30) end
	if id == "m_rupture" then return cap(math.ceil(2e6 * 2.7 ^ n)) end
	if id == "m_charged_strike" then return cap(4800 * 24 ^ n) end
	return nil
end

function S.miningPowerEffect(L: number) return cap(1.1 ^ nn(L - 1)) end
function S.oreValueEffect(L: number) return cap(1.1 ^ nn(L - 1)) end
function S.ruptureEffect(L: number) return 0.25 + 0.05 * math.min(15, nn(L - 1)) end
function S.chargedStrikeEffect(L: number) return 3 + math.min(3, nn(L - 1)) end

function S.mineNodeCost(area: number, branch: number): number
	return cap(math.ceil(anchor(S.POWER_ANCHORS, nn(area) - 1, 36) * (6 + branch)))
end

function S.oreHp(area: number): number
	if nn(area) < 2 then return areaCurve(S.HP_TABLE, area) end
	return areaCurve(S.GIANT_TABLE, area) / 32
end
function S.giantHp(area: number): number return areaCurve(S.GIANT_TABLE, area) end

function S.oreAreaReward(area: number): number
	local t = nn(area)
	return cap((if t < 2 then 1 else 0.8) / J[math.min(t, #J - 1) + 1]
		* (1 + math.min(5, math.max(0, t - 6) / 12))
		* 2 ^ math.min(1, t)
		* 1.6 ^ math.max(0, math.min(6, t) - 1)
		* (8.8 / 5.8) ^ math.max(0, t - 6))
end

function S.oreAreaXp(area: number): number
	local t = nn(area)
	local base = ({ 1, 1, 2, 3, 4, 5, 6 })[math.min(6, t) + 1]
	return base * (1 + math.min(2, math.max(0, t - 6) / 24))
end

function S.giantReward(area: number): number
	local i = nn(area)
	if i >= 7 then return cap(S.giantReward(6) * 8 ^ (i - 6)) end
	return math.floor(S.mineNodeCost(i + 1, 0) * (if i < 2 then 1 else 0.5))
end

S.ORE_RARITY_WEIGHTS = { -- per area 0..6+, order common/uncommon/rare/epic/legendary
	{ 88, 12, 0, 0, 0 }, { 78, 18, 4, 0, 0 }, { 68, 24, 8, 0, 0 }, { 64, 24, 10, 2, 0 },
	{ 58, 27, 12, 3, 0 }, { 54, 28, 13, 4, 1 }, { 48, 30, 15, 5, 2 },
}
S.ORE_RARITIES = {
	{ id = "common", hp = 1, reward = 1, guarantee = 0, unlockArea = 0 },
	{ id = "uncommon", hp = 1.15, reward = 3, guarantee = 8, unlockArea = 0 },
	{ id = "rare", hp = 1.35, reward = 8, guarantee = 30, unlockArea = 1 },
	{ id = "epic", hp = 1.6, reward = 20, guarantee = 100, unlockArea = 3 },
	{ id = "legendary", hp = 2, reward = 50, guarantee = 250, unlockArea = 5 },
}

function S.crowXpNeeded(L: number): number
	local t = math.max(1, math.floor(L))
	return math.max(1, math.floor(60 * t ^ 1.55 + 120 * math.max(0, t - 25) ^ 1.25))
end

S.CROW_REBIRB_GATES = { { 3, 1 }, { 5, 2 }, { 7, 3 }, { 7, 3 }, { 10, 4 }, { 12, 5 }, { 16, 6 }, { 20, 7 } } -- {level, giants}
function S.crowRebirbGate(R: number): (number, number)
	if R < 8 then return S.CROW_REBIRB_GATES[R + 1][1], S.CROW_REBIRB_GATES[R + 1][2] end
	return 20 + 5 * (R - 8), 10 + 3 * (R - 8)
end
function S.crowRebirbDamage(R: number) return cap(1.25 ^ math.min(8, R) * 2 ^ math.max(0, R - 8)) end

-- returns interval, overflowDamageMult
function S.crowHitInterval(crowLevel: number, R: number, speedMult: number): (number, number)
	local n = math.max(1, math.floor(crowLevel))
	local base = math.max(math.max(0.24 - 0.01 * 8, 0.24 - 0.01 * R), 0.55 / ((1 + 0.015 * (n - 1)) * 1.06 ^ R))
	local raw = base / math.max(1, speedMult)
	local interval = math.max(0.18, raw)
	return interval, interval / raw
end

function S.crowTrackCost(L: number) return math.max(1, math.ceil(125e4 * (L + 1) ^ 2 * 1.1 ^ math.floor(L / 10))) end
function S.crowTrackBonus(L: number) return if L <= 0 then 0 else 0.025 * math.sqrt(L) + 0.0025 * L end
function S.goldenOreChance(milestone: number, legacyRebirbs: number)
	return math.clamp(math.min(0.06, 0.01 * math.min(6, milestone)) + 0.005 * legacyRebirbs, 0, 0.1)
end

--------------------------------------------------------------------------- Nest
S.NEST_TIER_COST = { 1e5, 1e6, 1e8, 2e10 }
S.NEST_TIER_MULT = { 1, 2, 5, 10 }
function S.nestMaxTier(evolutions: number) return if evolutions < 3 then 1 elseif evolutions < 6 then 2 else 3 end
function S.twigValueCost(L: number) return math.max(1, math.ceil(15 * 1.06496 ^ math.clamp(L, 0, 999))) end
function S.peckRateCost(L: number) return math.max(1, math.ceil(150 * 1.18 ^ math.clamp(L, 0, 20))) end
function S.peckPowerCost(L: number) return math.max(1, math.ceil(5000 * 2.3 ^ math.clamp(L, 0, 15))) end
function S.chopDps(tier: number, axe: number) return 2.5 * 1.2 ^ tier + axe end
function S.treeBoxCost(n: number) return math.ceil(100 * 1.2 ^ math.clamp(math.floor(n), 0, 15)) end
function S.specialBoxCost(n: number) return math.ceil(2 * S.treeBoxCost(15) * 1.2 ^ math.clamp(math.floor(n), 0, 15)) end
function S.quadBoxCost(n: number) return math.ceil(2 * S.specialBoxCost(15) * 1.2 ^ math.clamp(math.floor(n), 0, 15)) end
function S.offlineEfficiency(L: number) return math.min(0.8, 0.25 + 0.05 * L) end

-- carpentry soft-capped geometric sum (game `qe`): cost of buying `count` levels from `from`
function S.softcapCost(base: number, growth: number, softcap: number, from: number, count: number): number
	if base == 0 or count <= 0 then return 0 end
	local total, t = 0, from
	while t < softcap and count > 0 do
		total += math.ceil(base * growth ^ t)
		t += 1
		count -= 1
	end
	if count == 0 then return total end
	local r = math.floor(2 / (growth - 1) + 0.5)
	local o = r + t - softcap
	local a = count
	return total + math.ceil(base * growth ^ softcap / r ^ 2) * (a * o ^ 2 + o * a * (a - 1) + a * (a - 1) * (2 * a - 1) / 6)
end

function S.carpentryXpTable(): { number }
	local t = { 0 }
	for lvl = 1, 98 do
		local A = lvl - 1
		t[lvl + 1] = t[lvl] + 10 * math.floor((150 + 12 * A + 6 * A ^ 2.2) / 10 + 0.5)
	end
	return t
end

--------------------------------------------------------------------------- Companions
function S.sparrowXpNeeded(L: number): number
	local i = math.max(1, math.floor(L))
	if i <= 100 then return i * 40 end
	local a = i - 100
	return math.floor(40 * (100 + a * a))
end
function S.sparrowSpeed(L: number, neuralOverclock: boolean)
	return math.min(150 + (L - 1) * 2, 2048 * (if neuralOverclock then 1.5 else 1))
end
function S.sparrowDrainMultiplier(resonanceXp: number) return 1 + 2.5 * math.log(1 + resonanceXp / 5000) / math.log(40.6) end
function S.mitosisRequirement(count: number): number
	return if count == 1 then 1e4 elseif count == 2 then 1e5 elseif count == 4 then 1e6 elseif count == 8 then 1e7
		elseif count >= 16 then 16e6 else 5e5 * count
end

function S.seagullXpNeeded(L: number) return math.floor(100 * 1.12 ^ (L - 1)) end
function S.seagullInterval(level: number, migrations: number, k: number)
	return 10 * 0.99 ^ level * (1 / (1 + math.clamp(math.floor(migrations), 0, 100) * k))
end
S.SEAGULL_BASE_XP = { common = 10, uncommon = 25, rare = 50, epic = 100, legendary = 250 }

function S.daveSeedTrainingCost(L: number) return math.floor(25e3 * 4e10 ^ (L / 50)) end
function S.daveGoldenMult(L: number) return 1 + math.min(10, 0.01 * L) end

--------------------------------------------------------------------------- Fishing
S.HOOK_MULT = {
	hook_bronze = { uncommon = 2 }, hook_iron = { rare = 2.5 }, hook_gold = { epic = 3 },
	hook_diamond = { legendary = 4 }, hook_ancient = { legendary = 4, epic = 2.5, rare = 1.5 },
	hook_cursed = { common = 3 },
}
function S.hookMultiplier(hook: string?, rarity: string): number
	local h = hook and S.HOOK_MULT[hook]
	return (h and h[rarity]) or 1
end
function S.fishSellValue(sellValue: number, bestKg: number?, valueMult: number, shiny: boolean, leviathan: boolean)
	local m = 1
	if bestKg and bestKg > 0 then
		m *= if leviathan then 1 + math.log10(1 + bestKg * bestKg) else 1 + math.log10(1 + bestKg)
	end
	m *= valueMult
	if shiny then m *= 10 end
	return math.max(1, math.floor(sellValue * m))
end

--------------------------------------------------------------------------- Expedition
function S.parrotXpNeeded(L: number): number
	local s = math.log10(math.max(1, math.floor(L)))
	return math.max(1, math.floor(10 ^ (2 + (-1 / 6) * s + (11 / 6) * s * s)))
end

local function roundMin(x: number, m: number) -- game `py`
	if x ~= x or x == math.huge or x == -math.huge then return m end
	return math.max(m, math.floor(x + 0.5))
end

-- base: {health, attack, defense, speed, xpBase, skillPointReward}; mod: per-type multipliers (hp/atk/xp/sp)
function S.enemyStats(enemyType: string, base, mod, floor: number, isBoss: boolean)
	local r = math.max(1, math.floor(floor))
	mod = mod or { hp = 1, atk = 1, xp = 1, sp = 1 }
	local mini = enemyType == "mini-fly"
	local h = roundMin(base.health * mod.hp * 2.4 ^ (r - 1) * (if isBoss then 8 else 1), 1)
	local a = roundMin(base.attack * mod.atk * 1.35 ^ (r - 1) * (if isBoss then 1.28 else 1), 1)
	local x = if mini then 0 else roundMin(base.xpBase * mod.xp * 2.05 ^ (r - 1) * (if isBoss then 14 else 1), 0)
	local f = roundMin(base.skillPointReward * mod.sp, 0) + math.floor((r - 1) / 2)
	local sp = if mini then 0 else roundMin(f * (if isBoss then 6 else 1), 0)
	local d = math.max(0, r - 1)
	return {
		health = roundMin(h * 1.1483 ^ d * (if isBoss then 1.1 else 1), 1),
		attack = roundMin(a * 1.1112 ^ d * (if isBoss then 1.08 else 1), 1),
		defense = roundMin(base.defense, 0),
		speed = roundMin(base.speed, 1),
		xpBase = roundMin(x * 1.1236 ^ d, 0),
		skillPointReward = roundMin(sp, 0),
	}
end

function S.floorHealthMultiplier(f: number): number
	f = math.max(1, math.floor(f))
	if f <= 1 then return 1 end
	local t = { [2] = 1200, [3] = 25e4, [4] = 3e8, [5] = 6e10, [6] = 18e12, [7] = 54e14, [8] = 1188e15 }
	return t[f] or 54e14 * 1200 ^ (f - 7)
end

function S.roundEnemyHealth(x: number): number
	local t = math.max(1, math.floor(x + 0.5))
	if t < 100 then return t end
	local p = 10 ^ math.max(0, math.floor(math.log10(t)) - 1)
	return math.max(1, math.floor(t / p + 0.5) * p)
end

function S.skillPointsFromHealth(hp: number, minimum: number, isBoss: boolean): number
	local i = math.max(1, hp)
	local a = if i <= 60 then 3 else math.max(3, math.floor(16.61 * math.log10(i) - 23.23 + 0.5))
	local r = if i <= 120 then 1 else (i / 120) ^ 0.14
	a = math.max(3, math.floor(a * r + 0.5))
	if isBoss then a = math.max(a, math.floor(2.5 * a + 0.5)) end
	return math.max(a, math.max(0, math.floor(minimum)))
end

S.EQUIPMENT = {
	beak = { common = { 0.1, 0.325, 0.55, 0.775, 1 }, uncommon = { 1, 2, 3, 4, 5 }, rare = { 5, 8, 12, 17, 25 },
		epic = { 25, 40, 60, 85, 120 }, legendary = { 150, 190, 255, 340, 430 } },
	armor = { common = { 1, 2, 3, 4, 5 }, uncommon = { 5, 7.5, 10, 12.5, 15 }, rare = { 15, 22, 32, 45, 65 },
		epic = { 65, 100, 150, 220, 320 }, legendary = { 400, 520, 720, 1000, 1320 } },
}
S.EQUIPMENT.aura = {}
for rarity, vals in S.EQUIPMENT.beak do
	S.EQUIPMENT.aura[rarity] = table.create(#vals)
	for i, v in vals do S.EQUIPMENT.aura[rarity][i] = v / 2 end
end
function S.refineMultiplier(r: number)
	if r <= 3 then return 1.25 ^ r end
	local i = r - 3
	return 1.25 ^ 3 * (1 + 0.01 * (i + math.floor(i / 3)))
end
function S.equipmentMultiplier(slot: string, rarity: string, level: number, refine: number)
	local t = S.EQUIPMENT[slot][rarity]
	return cap((t[level] or t[1]) * (if rarity == "legendary" then S.refineMultiplier(refine) else 1))
end

function S.parrotSkillPointMultiplier(rebirbs: number, level: number)
	local a = if rebirbs >= 3 then 8 elseif rebirbs >= 2 then 4 elseif rebirbs >= 1 then 2 else 1
	return math.max(1, a * (if rebirbs >= 2 then 1 + 0.001 * math.max(1, level) else 1))
end

--------------------------------------------------------------------------- Evolution
S.EVOLUTION_COSTS = {
	{ popcorn = 1e7 },
	{ popcorn = 1e10, moneta = 1000 },
	{ popcorn = 2.5e11, seeds = 3e7 },
	{ popcorn = 1e15, twigs = 1e5, moneta = 1e4 },
	{ popcorn = 1e18, twigs = 1e6 },
}
function S.evolutionProgress(stage: number, fed): number
	local need = S.EVOLUTION_COSTS[stage + 1]
	if not need then return 0 end
	local sum, n = 0, 0
	for k, req in need do
		sum += math.min(1, math.max(0, fed[k] or 0) / req)
		n += 1
	end
	return if n > 0 then sum / n * 100 else 0
end

--------------------------------------------------------------------------- Echo
function S.echoChance(echoChanceNode: boolean, tuning: boolean)
	return math.min(0.35, 0.25 + (if echoChanceNode then 0.05 else 0) + (if tuning then 0.05 else 0))
end
function S.flockMemory(lifetimeEcho: number)
	local i = math.log10(lifetimeEcho / 1e4 + 1)
	return 1 + math.max(0, i) / (math.max(0, i) + 4)
end

return S
