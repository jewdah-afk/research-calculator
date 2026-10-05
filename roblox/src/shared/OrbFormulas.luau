--!nonstrict
-- Pure balance math. Functions read a player data table (see OrbEconomy.newData) and never mutate it.
-- Luck and rarity odds are handled in log10 space so progression is endless without overflow.
-- Money/diamond amounts are Big (EternityNum) values.

local Config = require(script.Parent.OrbConfig)
local Progression = require(script.Parent.Progression)
local Big = require(script.Parent.Big)
local Balance = require(script.Parent.Balance)
local Prestige = require(script.Parent.Prestige)
require(script.Parent.Bonuses) -- registers weather/storm/event bonus sources

local F = {}
local Rarities = Progression.Rarities
local LOG2, LOG3 = math.log10(2), math.log10(3)

F.DIAMOND_CHANCE_CAP = 0.25 -- endless-balance guard: diamond chance upgrade stops at 25%
F.MIN_AUTOMATION_SECONDS = 0.5

---------------------------------------------------------------- skill tree

local skillIndex = {}
for cat, def in Config.SkillTree do
	for idx, upg in def.upgrades do
		skillIndex[upg.id] = { cat = cat, idx = idx }
	end
end

function F.skill(data, id: string): number
	local ref = skillIndex[id]
	return ref and data.skills[ref.cat][ref.idx] or 0
end

function F.skillDef(id: string)
	local ref = skillIndex[id]
	return Config.SkillTree[ref.cat].upgrades[ref.idx], ref.cat, ref.idx
end

function F.skillMaxLevel(upg): number
	if upg.infinite then
		return math.huge
	end
	if upg.costs then
		return #upg.costs
	end
	return upg.max or 1
end

function F.skillCost(upg, level: number): number
	if upg.costs then
		return upg.costs[level + 1] or math.huge
	end
	return upg.cost
end

---------------------------------------------------------------- weather

function F.weatherMults(data): (number, number, number)
	local luck, money, dia = 1, 1, 1
	for i, w in Config.Weather do
		if (data.weatherDuration[i] or 0) > 0 then
			luck += w.luck
			money += w.money
			dia += w.diamonds
		end
	end
	return luck, money, dia
end

function F.diamondChance(data): number
	return math.min(data.diamondChance, F.DIAMOND_CHANCE_CAP)
end

function F.weatherOrbChance(data): number
	return F.diamondChance(data) / Config.WeatherShop.OrbChanceDivisor * (1 + 0.1 * math.log(data.weatherPower + 1, 2))
end

function F.spawnCap(data): number
	return Config.Board.BaseSpawnCap + F.skill(data, "SPW-2") * 25 + math.floor(math.log(data.weatherPower + 1) / math.log(3) * 2)
end

function F.weatherRollPrice(data): number
	return math.round(data.weatherCosts.roll)
end

---------------------------------------------------------------- luck (log10)

-- Returns (current total luck log10, new best luck log10)
function F.totalLuckLog(data): (number, number)
	local l = data.baseLuckLog + data.diamondLuckLog + Prestige.luckLog(data)
	if data.boostTimes.luck > 0 then
		l += LOG2
	end
	if data.tiers >= 1 then
		l += F.skill(data, "MN-2") * math.log10(1.1) + F.skill(data, "MN-5") * math.log10(1.3)
	end
	-- everything non-core (weather, storm level, events, future content) goes through the bonus budget
	l += Balance.bonusLog(data, "luck", l)
	-- RL-2: when below best luck, close the gap (never exceeding best)
	local rl2 = F.skill(data, "RL-2")
	if rl2 > 0 and l < data.bestLuckLog then
		local eff = 1 + math.log(math.max(l, 2), 2) / 20 * rl2
		l = math.min(l + math.log10(eff), data.bestLuckLog)
	end
	return l, math.max(data.bestLuckLog, l)
end

function F.spawnerLuckLog(data, s: number): number
	return math.log10(Config.Spawners.BaseLuck[s]) + data.spawnerLuckLevels[s] * math.log10(Config.Spawners.LuckFactor)
end

---------------------------------------------------------------- rarity rolls

-- Rarity k (k >= 2) when r < luck / oneIn[k], checked top-down from the first rarity rarer than luck*1e6.
function F.rollRarity(effLuckLog: number, r: number): number
	local top = #Rarities
	for k, rar in Rarities do
		if rar.oneInLog >= effLuckLog + 6 then
			top = k
			break
		end
	end
	local lr = math.log10(math.max(r, 1e-300))
	for k = top, 2, -1 do
		if lr < effLuckLog - Rarities[k].oneInLog then
			return k
		end
	end
	return 1
end

-- Display odds as log10 of "1 in N" for rarity k (math.huge if impossible).
function F.oneInLog(effLuckLog: number, k: number): number
	local function t(i)
		return math.min(1, 10 ^ (effLuckLog - Rarities[i].oneInLog))
	end
	local p
	if k == #Rarities then
		p = t(k)
	elseif k == 1 then
		p = 1 - t(2)
	else
		p = t(k) - t(k + 1)
	end
	if p <= 0 then
		-- underflow: approximate with the raw ratio
		return Rarities[k].oneInLog - effLuckLog
	end
	return -math.log10(p)
end

function F.rollVariant(data, r: number): string?
	if F.skill(data, "SPW-3") <= 0 then
		return nil
	end
	local mn4 = F.skill(data, "MN-4")
	local V = Config.Variants
	if mn4 >= V.Rainbow.requiresMN4 and r < V.Rainbow.chance then
		return "Rainbow"
	elseif r < V.Glowing.baseThreshold + V.Glowing.perMN4 * mn4 then
		return "Glowing"
	elseif r < V.Shiny.baseThreshold + V.Shiny.perMN4 * mn4 then
		return "Shiny"
	end
	return nil
end

function F.variantMult(variant: string?): number
	return variant and Config.Variants[variant] and Config.Variants[variant].mult or 1
end

function F.orbRadius(data, rarity: number): number
	return Rarities[rarity].radius * (100 - F.skill(data, "SPW-5") * 5) / 100
end

---------------------------------------------------------------- board

function F.slotMult(tier: number, x: number): number
	local slot = Config.Tiers.Slots[Progression.boardForTier(tier)]
	for _, z in slot.zones do
		if x > z[1] and x < z[2] then
			return z[3]
		end
	end
	return slot.default
end

function F.isCollected(tier: number, x: number, y: number): boolean
	if y > Config.Board.CollectY then
		return true
	end
	if Progression.boardForTier(tier) == 3 then
		local p = Config.Tiers.Tier3Pockets
		return (x <= p.leftX or x >= p.rightX) and y >= p.yMin and y <= p.yMax
	end
	return false
end

---------------------------------------------------------------- payouts (Big)

-- Money multiplier actually applied to orbs (faithful to original: no weather money / MN-5 here).
function F.orbMoneyMult(data)
	local m = Big.mul(data.moneyMultiplier, data.weatherMoney * (data.boostTimes.money > 0 and 2 or 1))
	if data.mechanics >= 3 then
		m = Big.mul(m, Big.pow(Config.Base.RarityMoneyBonus, data.highestRarity))
	end
	if data.tiers >= 1 then
		m = Big.mul(m, Big.pow(1.05, F.skill(data, "MN-1")))
	end
	m = Big.mul(m, Big.pow(10, Prestige.cashLog(data)))
	local coreLog = Big.log10(m)
	return Big.mul(m, Big.pow(10, Balance.bonusLog(data, "cash", coreLog)))
end

function F.rarityValue(k: number)
	return Big.pow(10, Rarities[k].valueLog)
end

function F.orbMoney(data, rarity: number, slot: number, variant: string?)
	return Big.mul(Big.mul(F.orbMoneyMult(data), F.rarityValue(rarity)), slot * F.variantMult(variant))
end

function F.diamondBaseMult(data)
	local m = Big.new(Config.Difficulties[data.difficulty].diamondMult)
	local R = Config.Rebirth
	if data.rebirths >= R.ScaleStart then
		m = Big.mul(m, 0.025 * data.rebirths - 0.15)
	end
	if data.rebirths >= R.ExpStart then
		m = Big.mul(m, Big.pow(1.01, data.rebirths - R.ExpStart))
	end
	return m
end

-- Faithful to original: tier bonus is added (+0.15/tier), slot only from Tier 1.
function F.diamondGain(data, slot: number, variant: string?)
	local base = Big.mul(F.diamondBaseMult(data), Config.Base.DiamondValue * F.variantMult(variant))
	if data.tiers >= 1 then
		base = Big.mul(base, slot)
	end
	base = Big.mul(base, Big.pow(10, Prestige.gemLog(data)))
	local coreLog = Big.log10(base)
	base = Big.mul(base, Big.pow(10, Balance.bonusLog(data, "gems", math.max(coreLog - 1, 0))))
	return Big.add(base, 0.15 * data.tiers)
end

---------------------------------------------------------------- rebirth / tier

-- Rebirth cost (log10):  base + min(r, 25)*log(scale) + max(r - 25, 0)*log(lateScale)
-- The first 25 use the original scaling; after that the endless scale (2.5x) is below the rate
-- income grows per rebirth (~2.86x, derived in README), so rebirths are reachable forever.
F.REBIRTH_LATE_FROM = 25
F.REBIRTH_LATE_SCALE = 3.5 -- Roblox keeps the original scale: tiers (x2 cash, x3 luck each) supply the endless growth

local function rebirthParts(data): (number, number, number)
	local d = Config.Difficulties[data.difficulty]
	return math.log10(d.rebBase) - F.skill(data, "MN-5") * LOG2, math.log10(d.rebScaling), math.log10(F.REBIRTH_LATE_SCALE)
end

local function rebirthCostLog(data, r: number): number
	local b, s, late = rebirthParts(data)
	local early = math.min(r, F.REBIRTH_LATE_FROM)
	return b + early * s + math.max(r - F.REBIRTH_LATE_FROM, 0) * late
end
F.rebirthCostLog = rebirthCostLog

function F.rebirthCost(data, rebirths: number?)
	return Big.pow(10, rebirthCostLog(data, rebirths or data.rebirths))
end

-- How many rebirths current money buys (inverse of the piecewise cost; >= 1)
function F.bulkRebirths(data): number
	local b, s, late = rebirthParts(data)
	local m = Big.log10(data.money)
	local r
	local atLate = b + F.REBIRTH_LATE_FROM * s
	if m < atLate then
		r = math.floor((m - b) / s)
	else
		r = F.REBIRTH_LATE_FROM + math.floor((m - atLate) / late)
	end
	-- r = highest index whose cost is below money; buying up to it means r+1 total rebirths
	return math.max(r + 1 - data.rebirths, 1)
end

function F.tierRequirement(data)
	return Progression.tierRequirement(data.tiers + 1, data)
end

-- progress toward the next tier: lifetime count (hand tiers) or "this rarity or rarer since last tier"
function F.tierProgress(data): number
	local req = F.tierRequirement(data)
	if req.relative then
		return data.tierProgress or 0
	end
	return data.orbsObtained[req.rarity] or 0
end

-- seconds left before a generated tier may be taken (pacing floor); 0 for hand tiers
function F.tierTimeLeft(data): number
	local need = Progression.tierMinSeconds(data.tiers + 1)
	return math.max(need - (data.timePlayed - (data.tierStartTime or 0)), 0)
end

function F.canTier(data): boolean
	return F.tierProgress(data) >= F.tierRequirement(data).count and F.tierTimeLeft(data) <= 0
end

function F.baseLuckLog(data): number
	return data.rebirths * LOG2 + data.tiers * LOG3
end

---------------------------------------------------------------- costs (Big)

function F.scaledCost(base: number, mult: number, level: number)
	return Big.floor(Big.pow(10, math.log10(base) + level * math.log10(mult)))
end

-- How many levels of a geometric cost (base*mult^level) `money` can buy, capped at maxN.
function F.affordableLevels(money, base: number, mult: number, level: number, maxN: number): number
	local cLog = math.log10(base) + level * math.log10(mult)
	local mLog = Big.log10(money)
	if mLog < cLog then
		return 0
	end
	-- sum = c*(mult^n - 1)/(mult - 1) <= money  =>  n = floor(log(money*(mult-1)/c + 1)/log(mult))
	local inner = mLog - cLog + math.log10(mult - 1)
	local n = if inner > 15 then inner / math.log10(mult) else math.log10(10 ^ inner + 1) / math.log10(mult)
	return math.clamp(math.floor(n + 1e-9), 0, maxN)
end

function F.geometricSum(base: number, mult: number, level: number, n: number)
	-- c*(mult^n - 1)/(mult - 1)
	local c = Big.pow(10, math.log10(base) + level * math.log10(mult))
	return Big.div(Big.mul(c, Big.sub(Big.pow(mult, n), 1)), mult - 1)
end

function F.intervalCostMult(spawner: number): number
	return 2.5 + 0.25 * spawner
end

function F.boostCost(data, id: number): number
	local def = Config.Boosts[id]
	local over = F.skill(data, "BST-1") > 0 and Config.BoostsBST1[id] or def
	return over.baseCost + data.boostUses[id] * over.increment
end

function F.automationCost(data, idx: number): number
	local base = Config.Automation.Costs[idx]
	if idx <= 2 then
		return math.floor(base * data.automation.scales[idx] ^ data.automation.levels[idx])
	end
	return base
end

function F.automationInterval(level: number): number
	return math.max(Config.Automation.BaseSeconds * Config.Automation.IntervalFactor ^ level, F.MIN_AUTOMATION_SECONDS)
end

---------------------------------------------------------------- TP / QP

function F.maxTP(data): number
	local t = data.tiers + (data.tiers >= 1 and 1 or 0)
	for _, n in data.tpBought do
		t += n
	end
	return t
end

function F.maxQP(data): number
	return data.tiers + math.floor(F.maxTP(data) / 5) + data.qpBought
end

function F.spentPoints(data): (number, number)
	local tp, qp = 0, 0
	for cat, def in Config.SkillTree do
		for idx, upg in def.upgrades do
			local spent = 0
			for l = 0, data.skills[cat][idx] - 1 do
				spent += F.skillCost(upg, l)
			end
			if def.currency == "QP" then
				qp += spent
			else
				tp += spent
			end
		end
	end
	return tp, qp
end

function F.tpSourceCost(name: string, bought: number)
	local s = Config.TPSources[name]
	return Big.pow(10, math.log10(s.baseCost) + bought * math.log10(s.costMult))
end

---------------------------------------------------------------- formatting

local SUFFIX = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc",
	"SxDc", "SpDc", "OcDc", "NoDc", "Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg", "Tg" }

-- Format from a log10 value (works for any size)
function F.formatLog(l: number, decimals: number?): string
	if l == math.huge then
		return "∞"
	end
	if l < 3 then
		return string.format("%." .. tostring(decimals or 0) .. "f", 10 ^ l)
	end
	if l < 6 then
		local s = tostring(math.floor(10 ^ l + 0.5))
		return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
	end
	local e3 = math.floor(l / 3)
	local suf = SUFFIX[e3]
	if suf then
		return string.format("%.2f%s", 10 ^ (l - e3 * 3), suf)
	end
	local e = math.floor(l)
	return string.format("%.2fe%d", 10 ^ (l - e), e)
end

function F.format(x: any, decimals: number?): string
	if type(x) == "table" then
		local l = Big.log10(x)
		if l ~= l or l == -math.huge then
			return "0"
		end
		return F.formatLog(l, decimals)
	end
	if x <= 0 then
		return string.format("%." .. tostring(decimals or 0) .. "f", x)
	end
	return F.formatLog(math.log10(x), decimals)
end

return F
