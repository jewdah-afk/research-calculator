--!strict
--!native
--[[
	RarityColor — one source of truth for every rarity colour in the game.

	Colour is derived from the BAND (1..10, from RarityNames), never hand-picked
	per rarity. With 10,000 rarities, per-rarity colours are impossible to author
	and impossible to keep consistent.

	Interpolation happens in OKLCH so steps feel perceptually even instead of
	clumping in the blues — the usual failure of naive HSV ramps.
]]

local RarityColor = {}

-- Band anchors: {L, C, H°}. Lightness stays readable on a dark panel; chroma
-- climbs with band so higher rarities read as more energetic.
local ANCHORS = {
	{0.72, 0.02,  250}, -- 1  mundane      near-grey
	{0.74, 0.11,  145}, -- 2  elemental    green
	{0.80, 0.14,   85}, -- 3  celestial    gold
	{0.70, 0.16,  265}, -- 4  cosmic       blue
	{0.72, 0.15,  195}, -- 5  temporal     cyan
	{0.68, 0.19,  310}, -- 6  dimensional  violet
	{0.74, 0.18,   25}, -- 7  conceptual   coral
	{0.80, 0.20,   95}, -- 8  divine       radiant gold
	{0.70, 0.24,  350}, -- 9  transcendent magenta
	{0.86, 0.26,  200}, -- 10 beyond       prismatic cyan-white
}

local function srgbGamma(c: number): number
	if c <= 0.0031308 then
		return 12.92 * c
	end
	return 1.055 * c ^ (1 / 2.4) - 0.055
end

--- OKLCH -> Color3. L in 0..1, C in 0..~0.4, H in degrees.
function RarityColor.fromOklch(L: number, C: number, Hdeg: number): Color3
	local h = math.rad(Hdeg)
	local a, b = C * math.cos(h), C * math.sin(h)

	local l_ = L + 0.3963377774 * a + 0.2158037573 * b
	local m_ = L - 0.1055613458 * a - 0.0638541728 * b
	local s_ = L - 0.0894841775 * a - 1.2914855480 * b
	local l, m, s = l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_

	local r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	local bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

	return Color3.new(
		math.clamp(srgbGamma(r), 0, 1),
		math.clamp(srgbGamma(g), 0, 1),
		math.clamp(srgbGamma(bb), 0, 1)
	)
end

--- Colour for a rarity index. `t` is position within the band (0..1), which
--- brightens and saturates as you climb inside a band.
function RarityColor.forIndex(index: number): Color3
	local zero = index - 1
	local band = (zero % 10000) // 1000          -- 0..9
	local t = ((zero % 1000) / 999)              -- 0..1 within the band
	local A = ANCHORS[band + 1]
	-- climb slightly in L and C across the band so progress reads even inside one band
	return RarityColor.fromOklch(A[1] + 0.06 * t, A[2] + 0.03 * t, A[3])
end

--- Duration for a colour transition, scaled to how far the player jumped.
--- A one-band step is near-instant; a six-band leap earns a long sweep.
function RarityColor.spikeDuration(fromIndex: number, toIndex: number): number
	local fb = ((fromIndex - 1) % 10000) // 1000
	local tb = ((toIndex - 1) % 10000) // 1000
	local bands = math.abs(tb - fb)
	return math.clamp(0.12 + bands * 0.18, 0.12, 1.6)
end

--- Sweep THROUGH the intermediate band colours rather than cutting straight to
--- the destination — the eye reads the sweep as "I climbed a long way".
--- Returns the colour at progress `alpha` (0..1) along that journey.
function RarityColor.spikeColorAt(fromIndex: number, toIndex: number, alpha: number): Color3
	local a = math.clamp(alpha, 0, 1)
	-- ease-out so it flares fast then settles
	local eased = 1 - (1 - a) ^ 3
	local idx = fromIndex + (toIndex - fromIndex) * eased
	local c = RarityColor.forIndex(math.max(1, math.floor(idx)))
	-- brightness overshoot that settles back, strongest mid-sweep
	local overshoot = math.sin(a * math.pi) * 0.25
	local h, s, v = Color3.toHSV(c)
	return Color3.fromHSV(h, math.clamp(s - overshoot * 0.3, 0, 1), math.clamp(v + overshoot, 0, 1))
end

return RarityColor
