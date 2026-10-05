--!nonstrict
-- Endless progression tables, built once at require time.
--   * Rarities: the 50 hand-tuned rarities from OrbConfig, then generated ones forever after.
--     Every rarity carries log10 odds/value so nothing overflows a double.
--   * Tiers: the 4 hand-tuned tier requirements, then generated ones.

local Config = require(script.Parent.OrbConfig)

local Progression = {}

local GENERATED = 450 -- rarities after the hand-tuned 50 (raise freely; cost is a tiny table)
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

-- Tier requirements: own `count` of rarity index `rarity` (orbsObtained is lifetime, kept across tiers).
-- Tiers 1-4 are hand-tuned; after that each tier asks for a rarity 5 steps further, scaling count.
function Progression.tierRequirement(nextTier: number)
	local hand = Config.Tiers.Requirements[nextTier]
	if hand then
		return hand
	end
	local extra = nextTier - #Config.Tiers.Requirements
	return {
		rarity = math.min(38 + extra * 5, #rarities),
		count = math.floor(25 * 1.5 ^ math.min(extra, 20)),
	}
end

-- Which board layout a tier uses (layouts 0..4 exist; tiers beyond 4 reuse 4).
function Progression.boardForTier(tier: number): number
	return math.min(tier, Config.Tiers.Max)
end

return Progression
