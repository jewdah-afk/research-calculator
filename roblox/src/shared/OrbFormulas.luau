--!nonstrict
-- Pure balance math. Every function takes a player data table (see OrbEconomy.newData)
-- and returns numbers; nothing here mutates state.

local Config = require(script.Parent.OrbConfig)
local Big = require(script.Parent.Big)

local F = {}

local Rarities = Config.Rarities

-- Skill level lookup by id ("MN-1" etc.)
local skillIndex: { [string]: { cat: string, idx: number } } = {}
for cat, def in Config.SkillTree do
	for idx, upg in def.upgrades do
		skillIndex[upg.id] = { cat = cat, idx = idx }
	end
end

function F.skill(data, id: string): number
	local ref = skillIndex[id]
	if not ref then
		return 0
	end
	return data.skills[ref.cat][ref.idx]
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

function F.skillCost(upg, currentLevel: number): number
	if upg.costs then
		return upg.costs[currentLevel + 1]
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

function F.weatherOrbChance(data): number
	local base = data.diamondChance / Config.WeatherShop.OrbChanceDivisor
	return base * (1 + 0.1 * math.log(data.weatherPower + 1, 2))
end

function F.spawnCap(data): number
	local cap = Config.Board.BaseSpawnCap + F.skill(data, "SPW-2") * 25
	return cap + math.floor(math.log(data.weatherPower + 1) / math.log(3) * 2)
end

function F.weatherRollPrice(data): number
	return math.round(data.weatherCosts.roll)
end

---------------------------------------------------------------- luck

-- Total luck. Also returns the new best luck so the caller can store it.
function F.totalLuck(data): (number, number)
	local luck = data.baseLuck * (data.boostTimes.luck > 0 and 2 or 1) * data.diamondLuck
	if data.tiers >= 1 then
		luck *= 1.1 ^ F.skill(data, "MN-2")
		luck *= 1.3 ^ F.skill(data, "MN-5")
	end
	if data.mechanics >= 5 then
		local wl = F.weatherMults(data)
		luck *= wl
	end
	-- RL-2: when below best luck, boost toward (never above) best
	local rl2 = F.skill(data, "RL-2")
	local eff = 1 + math.log(math.log10(math.max(luck, 100)), 2) / 20 * rl2
	local best = data.bestLuck
	if luck < best then
		luck = math.min(luck * eff, best)
	end
	return luck, math.max(best, luck)
end

---------------------------------------------------------------- rarity rolls

-- Effective luck for a spawner = totalLuck * spawnerLuck[i]
-- Rarity k (k >= 2) is awarded when r < luck / oneIn[k], checked from the top down,
-- starting at the first rarity whose oneIn >= luck * 1e6.
function F.rollRarity(effLuck: number, r: number): number
	local top = #Rarities
	for k, rar in Rarities do
		if rar.oneIn >= effLuck * 1e6 then
			top = k
			break
		end
	end
	for k = top, 2, -1 do
		if r < effLuck / Rarities[k].oneIn then
			return k
		end
	end
	return 1
end

-- Display odds (1 in N) for rarity k at the given luck. Matches the in-game index.
function F.oneIn(effLuck: number, k: number): number
	local function t(i)
		return math.min(1, effLuck / Rarities[i].oneIn)
	end
	local p
	if k == #Rarities then
		p = t(k)
	elseif k == 1 then
		p = math.max(0, 1 - t(2))
	else
		p = math.max(0, t(k) - t(k + 1))
	end
	return if p > 0 then 1 / p else math.huge
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
	if variant and Config.Variants[variant] then
		return Config.Variants[variant].mult
	end
	return 1
end

function F.orbRadius(data, rarity: number): number
	return Rarities[rarity].radius * (100 - F.skill(data, "SPW-5") * 5) / 100
end

---------------------------------------------------------------- board

function F.slotMult(tier: number, x: number): number
	local slot = Config.Tiers.Slots[math.min(tier, Config.Tiers.Max)]
	for _, z in slot.zones do
		if x > z[1] and x < z[2] then
			return z[3]
		end
	end
	return slot.default
end

-- Whether an orb at (x, y) (board pixels, y down) should be cashed in.
function F.isCollected(tier: number, x: number, y: number): boolean
	if y > Config.Board.CollectY then
		return true
	end
	if tier == 3 then
		local p = Config.Tiers.Tier3Pockets
		if (x <= p.leftX or x >= p.rightX) and y >= p.yMin and y <= p.yMax then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- payouts

-- Money multiplier (Big) actually applied when an orb is collected.
-- NOTE: the original applies neither weather money nor MN-5 here (they only show in the UI).
function F.orbMoneyMult(data)
	local m = data.weatherMoney * (data.boostTimes.money > 0 and 2 or 1)
	if data.mechanics >= 3 then
		m *= Config.Base.RarityMoneyBonus ^ data.highestRarity
	end
	if data.tiers >= 1 then
		m *= 1.05 ^ F.skill(data, "MN-1")
	end
	return Big.mul(data.moneyMultiplier, m)
end

function F.orbMoney(data, rarity: number, slot: number, variant: string?)
	return Big.mul(F.orbMoneyMult(data), Rarities[rarity].value * slot * F.variantMult(variant))
end

-- Difficulty and rebirth part of the diamond multiplier.
function F.diamondBaseMult(data): number
	local m = Config.Difficulties[data.difficulty].diamondMult
	local R = Config.Rebirth
	if data.rebirths >= R.ScaleStart then
		m *= 0.025 * data.rebirths - 0.15
	end
	if data.rebirths >= R.ExpStart then
		m *= 1.01 ^ (data.rebirths - R.ExpStart)
	end
	return m
end

-- Diamonds from one diamond orb. Faithful to the original formula: the tier bonus is ADDED
-- (+0.15 per tier), and slot mult only applies from Tier 1. MN-3 / weather diamonds are not used.
function F.diamondGain(data, slot: number, variant: string?): number
	local base = Config.Base.DiamondValue * F.diamondBaseMult(data) * F.variantMult(variant)
	if data.tiers >= 1 then
		base *= slot
	end
	return base + 0.15 * data.tiers
end

---------------------------------------------------------------- rebirth / tier

function F.rebirthCost(data, rebirths: number?)
	local d = Config.Difficulties[data.difficulty]
	local n = rebirths or data.rebirths
	return Big.mul(Big.pow(d.rebScaling, n), d.rebBase / 2 ^ F.skill(data, "MN-5"))
end

-- Rebirths gained by a bulk rebirth (MAX-3) with current money (>= 1).
function F.bulkRebirths(data): number
	local d = Config.Difficulties[data.difficulty]
	local base = d.rebBase / 2 ^ F.skill(data, "MN-5")
	local target = math.floor((Big.log10(data.money) - math.log10(base)) / math.log10(d.rebScaling) + 1)
	return math.max(target - data.rebirths, 1)
end

function F.canTier(data): boolean
	local req = Config.Tiers.Requirements[data.tiers + 1]
	if not req then
		return false
	end
	return (data.orbsObtained[req.rarity] or 0) >= req.count
end

---------------------------------------------------------------- spawners

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
	return Config.Automation.BaseSeconds * Config.Automation.IntervalFactor ^ level
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
			local lvl = data.skills[cat][idx]
			local spent = 0
			for l = 0, lvl - 1 do
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
	return Big.mul(Big.pow(s.costMult, bought), s.baseCost)
end

---------------------------------------------------------------- formatting

local SUFFIX = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc",
	"SxDc", "SpDc", "OcDc", "NoDc", "Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg", "Tg",
	"UTg", "DTg", "TTg", "QaTg", "QiTg", "SxTg", "SpTg", "OcTg", "NoTg", "Qag", "UQag", "DQag", "TQag", "QaQag",
	"QiQag", "SxQag", "SpQag", "OcQag", "NoQag", "Qtg", "UQtg", "DQtg", "TQtg", "QaQtg", "QiQtg", "SxQtg", "SpQtg",
	"OcQtg", "NoQtg", "Sxg", "USxg", "DSxg", "TSxg", "QaSxg", "QiSxg", "SxSxg", "SpSxg", "OcSxg", "NoSxg", "Spg",
	"USpg", "DSpg", "TSpg", "QaSpg", "QiSpg", "SxSpg", "SpSpg", "OcSpg", "NoSpg", "Og", "UOg", "DOg", "TOg", "QaOg",
	"QiOg", "SxOg", "SpOg", "OcOg", "NoOg", "Ng", "UNg", "DNg", "TNg", "QaNg", "QiNg", "SxNg", "SpNg", "OcNg", "NoNg",
	"Ce", "UCe" }

function F.format(x: any, decimals: number?): string
	if type(x) == "table" then
		return Big.format(x)
	end
	if x == math.huge then
		return "Infinity"
	end
	if x >= 1e9 then
		local e = math.floor(math.log10(x) / 3)
		local s = SUFFIX[e]
		if s then
			return string.format("%.2f%s", x / 1000 ^ e, s)
		end
		return string.format("%.2fe%d", x / 10 ^ math.floor(math.log10(x)), math.floor(math.log10(x)))
	end
	if x >= 1000 then
		local s = tostring(math.floor(x))
		return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
	end
	return string.format("%." .. tostring(decimals or 0) .. "f", x)
end

return F
