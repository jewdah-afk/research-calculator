--!nonstrict
-- Endless progression tables, built once at require time.
--   * Rarities: the 50 hand-tuned rarities from OrbConfig, then generated ones forever after.
--     Every rarity carries log10 odds/value so nothing overflows a double.
--   * Tiers: the 4 hand-tuned tier requirements, then generated ones.

local Config = require(script.Parent.OrbConfig)
local RarityStyle = require(script.Parent.RarityStyle)

local Progression = {}

local GENERATED = 1950 -- rarities after the hand-tuned 50 (raise freely; ~2k rows is still tiny)

-- Base colours for rarities 1-50, matched to their names (Pebble grey ... The Absolute white-gold)
local BASE_COLORS = {
	"#9a968f", "#d8d2e6", "#4fbf4f", "#7fd6ff", "#c8733a", "#c9d1dc", "#ffcc33", "#3fae7a", "#ffa21f", "#2f6bff",
	"#e0193a", "#18c46a", "#9b4dff", "#bff6ff", "#8fe8ff", "#ff6a1f", "#ffe14d", "#1fa7d6", "#7dff2e", "#b9b4ff",
	"#2fbf8f", "#ff5a1f", "#1d5f7a", "#d4a64a", "#0e3d8c", "#fff4b0", "#ffb3f0", "#2a1a3d", "#4dffb8", "#9fe4ff",
	"#ff8a3d", "#c6a8ff", "#ff3df0", "#ff5cc8", "#ffb000", "#120a1f", "#7a3dff", "#ff2e63", "#3b2a6b", "#00ffd5",
	"#ffd23d", "#ff4fd8", "#9c8cff", "#ffe066", "#a8f0ff", "#fff07a", "#ffffff", "#ff9ef5", "#7af7ff", "#fff8e0",
}

local function hexToRGB(h: string): { number }
	h = h:gsub("#", "")
	return { tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16) }
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
	rarities[i].fx = RarityStyle.fx(i, rarities[i].color)
end

-- Generated rarities keep the late-game rhythm of the hand-tuned table:
-- odds grow ~2.5 orders of magnitude per step (slowly accelerating), value ~2.0 per step,
-- so each new rarity is rarer than it is valuable (money/luck upgrades must keep pace).
do
	local last = rarities[#rarities]
	local oddsLog, valueLog = last.oneInLog, last.valueLog
	for k = 1, GENERATED do
		-- value grows in a FIXED proportion (0.8) to odds, so income keeps pace with the curve forever
		local step = 2.5 + 0.02 * k
		oddsLog += step
		valueLog += 0.8 * step
		local i = #rarities + 1
		local fx = RarityStyle.fx(i, nil)
		table.insert(rarities, {
			name = RarityStyle.name(i),
			oneInLog = oddsLog,
			valueLog = valueLog,
			radius = 15,
			color = fx.colors[1],
			fx = fx,
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
