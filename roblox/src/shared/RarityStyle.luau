--!nonstrict
-- Names and looks for all 2000 rarities.
--   * 1-50: hand-named in OrbConfig (Pebble -> The Absolute), with their own base colours.
--   * 51+:  generated titles ("Gilded Requiem", "Crown of Ten Suns", ...), unique, deterministic.
--   * Every rarity gets an `fx` table. Its LEVEL climbs every 5 rarities early and every 130
--     later, and each level adds or strengthens an effect, so every new best orb looks better
--     than anything you've had before.
-- Pure math only (no Roblox APIs): the browser preview ports this file 1:1.

local RarityStyle = {}

-- deterministic 0..1 noise per (index, salt); exact in doubles, easy to port
local function rand(i: number, salt: number): number
	return ((i * 2654435761 + salt * 40503 + 12345) % 4294967296) / 4294967296
end
RarityStyle.rand = rand

local function pick(list, i, salt)
	return list[math.floor(rand(i, salt) * #list) + 1]
end

local function hsv(h: number, s: number, v: number): { number }
	h = h % 1
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
	return { math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5) }
end
RarityStyle.hsv = hsv

local function toHSV(c): (number, number, number)
	local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6
		elseif mx == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h /= 6
	end
	return h, (mx > 0 and d / mx or 0), mx
end

---------------------------------------------------------------- names (51+)

local ADJ = {
	"Shattered", "Gilded", "Hollow", "Crimson", "Silent", "Burning", "Frozen", "Eternal", "Forgotten", "Radiant",
	"Cursed", "Blessed", "Thundering", "Whispering", "Sunken", "Ascendant", "Fractured", "Infinite", "Wandering", "Sovereign",
	"Obsidian", "Prismatic", "Spectral", "Molten", "Celestine", "Abyssal", "Lunar", "Solar", "Verdant", "Feral",
	"Gleaming", "Shrouded", "Arcane", "Runic", "Iron", "Velvet", "Neon", "Lucid", "Primal", "Stellar",
	"Vengeful", "Hallowed", "Distant", "Endless", "Scarlet", "Azure", "Golden", "Midnight",
}
local NOUN = {
	"Crown", "Throne", "Halo", "Tide", "Storm", "Oracle", "Sigil", "Relic", "Bloom", "Pulse",
	"Requiem", "Dynasty", "Monolith", "Cathedral", "Lantern", "Serpent", "Dragon", "Colossus", "Empress", "Warden",
	"Harbinger", "Sentinel", "Spire", "Citadel", "Rift", "Vortex", "Mirage", "Echo", "Cinder", "Tempest",
	"Maw", "Zenith", "Nexus", "Prism", "Covenant", "Anthem", "Oath", "Legend", "Myth", "Star",
	"Moon", "Sun", "Dream", "Heart", "Soul", "Wing", "Gate", "Key",
}
local PLACE = {
	"the Void", "the Deep", "Ten Suns", "the First Light", "the End", "Lost Stars", "the Pale Moon", "Broken Time",
	"the Last King", "Forever", "the Abyss", "Silver Rain", "the Old Gods", "the Northern Sky", "Endless Night", "the Hollow Sea",
	"the Burning Sky", "the Crown", "a Thousand Worlds", "the Dawn", "the Eclipse", "the Great Tide", "Starlight", "the Forgotten",
	"Glass Skies", "the Infinite", "the Machine", "the Dragon", "the Storm", "the Ancients", "the Veil", "Creation",
}
local ROMAN = { "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

local used = {}
-- every (adjective, noun) pair is used once: q walks a full permutation of the 48x48 pairs
local function generatedName(i: number): string
	local j = i - 51
	local q = (j * 1013) % (#ADJ * #NOUN)
	local a, n = ADJ[q % #ADJ + 1], NOUN[math.floor(q / #ADJ) + 1]
	local p = PLACE[(j * 13 + math.floor(j / 32)) % #PLACE + 1]
	local form = (j * 7) % 20
	local name
	if form < 9 then
		name = a .. " " .. n
	elseif form < 14 then
		name = n .. " of " .. p
	elseif form < 17 then
		name = "The " .. a .. " " .. n
	else
		name = a .. " " .. n .. " of " .. p
	end
	local base, k = name, 0
	while used[name] do
		k += 1
		name = base .. " " .. (ROMAN[k] or tostring(k + 1))
	end
	used[name] = true
	return name
end

---------------------------------------------------------------- effects

-- effect level: +1 every 5 rarities up to #50, then +1 every 130 (level 24 at #2000)
function RarityStyle.level(i: number): number
	if i <= 50 then
		return math.floor((i - 1) / 5)
	end
	return 10 + math.floor((i - 51) / 130)
end

-- what each level adds (shown in the index as the orb's "effects" line)
RarityStyle.LEVEL_NAMES = {
	[0] = "Plain", "Polished", "Glowing", "Tri-tone", "Sparkling", "Neon Core", "Comet Trail", "Ringed", "Aura",
	"Pulsing", "Moons", "Rainbow", "Twin Rings", "Lightning", "Supercharged", "Starburst", "Overdrive", "Triple Rings",
	"Outlined", "Radiant", "Event Horizon", "Godlight", "Reality Tear", "Cosmic Crown", "Singular",
}

function RarityStyle.fx(i: number, baseColor): { [string]: any }
	local L = RarityStyle.level(i)
	local c1 = baseColor
	if i > 50 then
		c1 = hsv(rand(i, 5), 0.7 + 0.3 * rand(i, 6), 1)
	end
	local h, s, v = toHSV(c1)
	local fx = {
		level = L,
		levelName = RarityStyle.LEVEL_NAMES[math.min(L, #RarityStyle.LEVEL_NAMES)],
		colors = { c1, hsv(h + 0.06, math.min(1, s + 0.1), v * 0.55) }, -- light-to-dark gradient
		material = "Plastic",
		shine = 0, glow = 0, sparkles = 0, trail = false, rings = 0, aura = false, pulse = 0,
		moons = 0, rainbow = 0, lightning = false, starburst = 0, outline = false, horizon = false,
	}
	if L >= 1 then fx.material = "Glass"; fx.shine = math.min(0.6, 0.25 + 0.03 * L) end
	if L >= 2 then fx.glow = math.min(6, 0.6 + 0.25 * L) end
	if L >= 3 then fx.colors[3] = hsv(h + 0.33 + 0.2 * rand(i, 7), 0.8, 1) end
	if L >= 4 then fx.sparkles = math.min(40, 4 + 2 * L) end
	if L >= 5 then fx.material = "Neon" end
	if L >= 6 then fx.trail = true end
	if L >= 7 then fx.rings = if L >= 17 then 3 elseif L >= 12 then 2 else 1 end
	if L >= 8 then fx.aura = true end
	if L >= 9 then fx.pulse = math.min(0.25, 0.08 + 0.01 * (L - 9)) end
	if L >= 10 then fx.moons = math.min(5, 1 + math.floor((L - 10) / 3)) end
	if L >= 11 then fx.rainbow = 0.1 + 0.02 * (L - 11) end
	if L >= 13 then fx.lightning = true end
	if L >= 15 then fx.starburst = math.min(30, 6 + 2 * (L - 15)) end
	if L >= 18 then fx.outline = true end
	if L >= 20 then fx.horizon = true end -- dark core, blazing rim
	return fx
end

-- name for a generated rarity (call in index order; names stay stable across runs)
function RarityStyle.name(i: number): string
	return generatedName(i)
end

return RarityStyle
