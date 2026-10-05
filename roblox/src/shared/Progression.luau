--!nonstrict
-- Endless progression tables, built once at require time.
--   * Rarities: the 50 hand-tuned rarities from OrbConfig, then generated ones forever after.
--     Every rarity carries log10 odds/value so nothing overflows a double.
--   * Tiers: the 4 hand-tuned tier requirements, then generated ones.

local Config = require(script.Parent.OrbConfig)

local Progression = {}

local GENERATED = 1950 -- rarities after the hand-tuned 50 (raise freely; ~2k rows is still tiny)
local PREFIXES = { "Eternal", "Omega", "Primordial", "Singularity", "Paradox", "Apex", "Mythos", "Zenith", "Oblivion", "Genesis" }
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

local function roman(n: number): string
	if n <= #ROMAN then
		return ROMAN[n]
	end
	return tostring(n)
end

-- Hand-tuned rarity colours (cycle for generated ones via HSV)
local BASE_COLORS = {
	"#bbbbbb", "#bbbbbb", "#45bb45", "#45bb45", "#4545bb", "#4545bb", "#8845bb", "#8845bb", "#ff8800", "#ff8800",
	"#ff0000", "#ff0000", "#ff7b00", "#bb24bb", "#4800ff", "#000000", "#8200ff", "#000042", "#00c8ff", "#0084ff",
	"#82ff49", "#14c98d", "#ffffff", "#ffe500", "#ff0000", "#5c0000", "#333333", "#111111", "#c307eb", "#11053a",
	"#d946ff", "#ffffff", "#0ba67f", "#07fbdd", "#ef9a1f", "#fcf046", "#52e5f6", "#ffffff", "#0c1381", "#635cdd",
	"#9f0811", "#fb0102", "#fe4dfe", "#e167cf", "#ffa700", "#ff4000", "#1cd328", "#03660f", "#ffd600", "#ffc800",
}

local function hexToRGB(h: string): { number }
	h = h:gsub("#", "")
	return { tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16) }
end

local function hsv(h: number, s: number, v: number): { number }
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local r, g, b
	i = i % 6
	if i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	else r, g, b = v, p, q end
	return { math.floor(r * 255), math.floor(g * 255), math.floor(b * 255) }
end

-- Rarity list: { name, oneInLog, valueLog, radius, color = {r,g,b} }
local rarities = {}
for i, r in Config.Rarities do
	table.insert(rarities, {
		name = r.name,
		oneInLog = math.log10(r.oneIn),
		valueLog = math.log10(r.value),
		radius = r.radius,
		color = hexToRGB(BASE_COLORS[i] or "#ffffff"),
	})
end

-- Generated rarities keep the late-game rhythm of the hand-tuned table:
-- odds grow ~2.5 orders of magnitude per step (slowly accelerating), value ~2.0 per step,
-- so each new rarity is rarer than it is valuable (money/luck upgrades must keep pace).
do
	local last = rarities[#rarities]
	local oddsLog, valueLog = last.oneInLog, last.valueLog
	for k = 1, GENERATED do
		oddsLog += 2.5 + 0.02 * k
		valueLog += 2.0 + 0.012 * k
		local prefix = PREFIXES[((k - 1) % #PREFIXES) + 1]
		local cycle = math.floor((k - 1) / #PREFIXES) + 1
		table.insert(rarities, {
			name = prefix .. " " .. roman(cycle),
			oneInLog = oddsLog,
			valueLog = valueLog,
			radius = 15,
			color = hsv((k * 0.137) % 1, 0.75, 1),
		})
	end
end
Progression.Rarities = rarities
Progression.HandTunedRarities = #Config.Rarities

-- Tier requirements.
-- Tiers 1-4 (hand-tuned): own `count` of rarity `rarity` (lifetime counts, as in the original).
-- Tiers 5+ (generated, RELATIVE): when you tier up we remember your luck (tierLuckLog). The next
-- tier asks for TIER_COUNT orbs of a rarity at least TIER_DELTA orders of magnitude beyond that
-- luck, collected since the last tier. The target follows the player's real progress, so it can
-- never wall (it is always a fixed distance ahead) and never trivialise (you must out-grow your
-- previous peak after the tier reset) — no matter what future content changes about growth speed.
Progression.TIER_DELTA = 5 -- minimum orders of magnitude beyond your luck at the last tier-up
Progression.TIER_DELTA_SHARE = 0.15 -- ...or this share of that luck (log10), whichever is larger (tuned by QA)
Progression.TIER_DELTA_EASE = 30 -- share halves by generated tier 30, thirds by 60 ...
Progression.TIER_DELTA_GROWTH = 0.05 -- extra orders per generated tier
Progression.TIER_MIN_STEP = 1.5 -- target always moves at least this far past the previous one
Progression.TIER_COUNT = 10
-- Pacing floor for generated tiers: you must spend at least this long in a tier (UI shows a countdown).
-- Late-game growth snowballs (bulk rebirth + rebirth keep), so without a floor tiers would shrink to minutes.
Progression.TIER_MIN_MINUTES = 10
Progression.TIER_MIN_MINUTES_GROWTH = 0.5
Progression.TIER_MIN_MINUTES_MAX = 60

function Progression.tierMinSeconds(nextTier: number): number
	if nextTier <= #Config.Tiers.Requirements then
		return 0
	end
	local n = nextTier - #Config.Tiers.Requirements
	return 60 * math.min(Progression.TIER_MIN_MINUTES + Progression.TIER_MIN_MINUTES_GROWTH * (n - 1), Progression.TIER_MIN_MINUTES_MAX)
end

local function rarityAtOdds(oddsLog: number): number
	for k, r in rarities do
		if r.oneInLog >= oddsLog then
			return k
		end
	end
	return #rarities
end
Progression.rarityAtOdds = rarityAtOdds

function Progression.isRelativeTier(nextTier: number): boolean
	return nextTier > #Config.Tiers.Requirements
end

-- Called when a player reaches `tier`; returns the odds target for tier+1 (relative tiers only).
function Progression.nextTierOdds(tier: number, luckLogAtTier: number, prevOdds: number?): number
	local n = tier + 1 - #Config.Tiers.Requirements
	local base = prevOdds or rarities[Config.Tiers.Requirements[#Config.Tiers.Requirements].rarity].oneInLog
	-- share eases off slowly with tier count so growth requirements stay sub-linear forever (no walls)
	local share = Progression.TIER_DELTA_SHARE / (1 + n / Progression.TIER_DELTA_EASE)
	local delta = math.max(Progression.TIER_DELTA, share * math.max(luckLogAtTier, 0))
	return math.max(base + Progression.TIER_MIN_STEP, luckLogAtTier + delta + Progression.TIER_DELTA_GROWTH * n)
end

-- Requirement for the player's NEXT tier. `data` needed for relative tiers.
function Progression.tierRequirement(nextTier: number, data)
	local hand = Config.Tiers.Requirements[nextTier]
	if hand then
		return { rarity = hand.rarity, count = hand.count, relative = false }
	end
	local odds = data and data.tierReqOdds or (rarities[Config.Tiers.Requirements[#Config.Tiers.Requirements].rarity].oneInLog + 7)
	return { rarity = rarityAtOdds(odds), count = Progression.TIER_COUNT, relative = true }
end

-- Which board layout a tier uses (layouts 0..4 exist; tiers beyond 4 reuse 4).
function Progression.boardForTier(tier: number): number
	return math.min(tier, Config.Tiers.Max)
end

return Progression
