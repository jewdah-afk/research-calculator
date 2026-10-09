--!nonstrict
-- Vfx/Palette: cel colour ladders for effects. Each palette has five steps used by role:
--   hi     = near-white tint (hot cores, sparkles)        mid  = the main flat colour (bodies, rings)
--   base   = saturated step (glows, pillars)               deep = shade step (rarely; dark accents)
--   accent = a contrasting pop (second ring, confetti)     + "white" / "ink" (#16181e) are always available
-- Rarity hues follow the parity build's ladder (playtest RARITY_COLOR: grey / green / blue / purple / gold / pink),
-- pushed to pastel cel steps so they read on the bright island. Textures are greyscale and multiply by these.
local Palette = {}

local INK = Color3.fromHex("16181e")
local WHITE = Color3.new(1, 1, 1)

Palette.ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local RAW = {
	Common = { tier = 1, hi = "ffffff", mid = "e9eff6", base = "bccada", deep = "7e8ca3", accent = "fff1c2" },
	Uncommon = { tier = 2, hi = "eeffe2", mid = "aef08a", base = "62d35a", deep = "2f9a4a", accent = "fff6a6" },
	Rare = { tier = 3, hi = "e6f7ff", mid = "98d9ff", base = "4ea9ff", deep = "2b62d4", accent = "c9fbff" },
	Epic = { tier = 4, hi = "f7ebff", mid = "d6a9ff", base = "aa68f5", deep = "6a33c7", accent = "ffb6ee" },
	Legendary = { tier = 5, hi = "fff8d8", mid = "ffe066", base = "ffb22e", deep = "e06c1a", accent = "ffffff" },
	Mythic = {
		tier = 6, hi = "ffe8f5", mid = "ffa6d4", base = "ff52a2", deep = "b8227a", accent = "a2f4ff",
		rainbow = { "ff6b6b", "ffb84d", "ffe95c", "6be675", "5cc8ff", "b98bff" },
	},
	-- non-rarity palettes
	egg = { tier = 1, hi = "ffffff", mid = "fff3cf", base = "ffd98a", deep = "e0a64a", accent = "ffffff" },
	golden = { tier = 3, hi = "fff8d8", mid = "ffe066", base = "ffc93a", deep = "e08a1a", accent = "ffffff" },
	unlock = { tier = 5, hi = "fffbe8", mid = "ffeaa6", base = "ffd36b", deep = "e0a03a", accent = "b8f0ff" },
}

local cache = {}
local function build(raw)
	local p = { tier = raw.tier, white = WHITE, ink = INK }
	for _, role in { "hi", "mid", "base", "deep", "accent" } do p[role] = Color3.fromHex(raw[role]) end
	if raw.rainbow then
		p.rainbow = {}
		for i, h in raw.rainbow do p.rainbow[i] = Color3.fromHex(h) end
	end
	return p
end
for name, raw in RAW do cache[string.lower(name)] = build(raw) end

-- a five-step palette from one colour (companion colours, island themes)
local function fromColor(c: Color3)
	local h, s, v = c:ToHSV()
	return {
		tier = 3, white = WHITE, ink = INK,
		hi = WHITE:Lerp(c, 0.22),
		mid = Color3.fromHSV(h, s * 0.62, math.min(1, v * 0.35 + 0.68)),
		base = c,
		deep = Color3.fromHSV(h, math.min(1, s * 1.1), v * 0.62),
		accent = WHITE,
	}
end

-- palette from a rarity name (any case) / palette name / tier number (1-6) / Color3 / hex string / palette table
function Palette.get(x: any)
	if type(x) == "table" and x.mid then return x end
	if typeof(x) == "Color3" then return fromColor(x) end
	if type(x) == "number" then
		local name = Palette.ORDER[math.clamp(math.floor(x), 1, #Palette.ORDER)]
		return cache[string.lower(name)]
	end
	if type(x) == "string" then
		local p = cache[string.lower(x)]
		if p then return p end
		local ok, c = pcall(Color3.fromHex, x)
		if ok then return fromColor(c) end
	end
	return cache.common
end

function Palette.tier(x: any): number
	return Palette.get(x).tier or 1
end

-- role name -> Color3 (also accepts a Color3 or a hex string)
function Palette.color(p, role: any): Color3
	if typeof(role) == "Color3" then return role end
	if role == nil then return p.mid end
	local c = p[role]
	if typeof(c) == "Color3" then return c end
	if type(role) == "string" then
		local ok, hc = pcall(Color3.fromHex, role)
		if ok then return hc end
	end
	return p.mid
end

Palette.INK = INK
return Palette
