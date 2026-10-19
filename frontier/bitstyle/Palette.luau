--!native
--!optimize 2
-- Bit-style scene palette: one 256-entry LUT for IndexedFrame.
--   0..191   lit material ramps: 8 materials x 4 light tints x 6 levels (index = mat*24 + tint*6 + level)
--   192..255 fixed (self-lit) colours for sprites, effects and UI
-- Light is quantised to a ramp level with a 4x4 Bayer threshold, so every light falloff becomes flat
-- bands joined by a checkerboard transition (never a smooth gradient).

local Palette = {}

Palette.LEVELS = 6
Palette.TINTS = 4
Palette.RAMP = 24 -- entries per material

-- Materials
Palette.GRASS = 0
Palette.PATH = 1
Palette.COBBLE = 2
Palette.CSTONE = 3 -- corrupted void stone
Palette.TOMB = 4
Palette.LEAF = 5
Palette.TRUNK = 6
Palette.DEAD = 7 -- trees after corruption

-- Light tints
Palette.NIGHT = 0
Palette.WARM = 1
Palette.COLD = 2
Palette.VOID = 3

-- Fixed colours (index -> sRGB)
local FIXED: { [string]: { number } } = {
	BLACK = { 192, 7, 5, 14 },
	WHITE = { 193, 244, 240, 228 },
	VOID0 = { 194, 9, 3, 17 },
	VOID1 = { 195, 36, 14, 58 },
	RIM = { 196, 146, 84, 222 },
	RIM_HI = { 197, 214, 186, 255 },
	FLAME_HI = { 198, 255, 251, 214 },
	FLAME = { 199, 255, 196, 72 },
	FLAME_LO = { 200, 228, 108, 38 },
	WAX = { 201, 238, 226, 190 },
	WAX_SH = { 202, 186, 162, 126 },
	WAX_OUT = { 203, 96, 72, 62 },
	KNIGHT_HI = { 204, 236, 238, 246 },
	KNIGHT = { 205, 160, 166, 190 },
	KNIGHT_OUT = { 206, 46, 44, 78 },
	CAPE = { 207, 70, 112, 214 },
	CAPE_SH = { 208, 40, 58, 140 },
	VISOR = { 209, 24, 22, 46 },
	LANTERN = { 210, 255, 226, 110 },
	GHOST0 = { 211, 38, 54, 120 },
	GHOST1 = { 212, 92, 128, 214 },
	GHOST2 = { 213, 164, 200, 255 },
	GHOST3 = { 214, 236, 246, 255 },
	ROBE0 = { 215, 20, 10, 36 },
	ROBE1 = { 216, 40, 22, 66 },
	ROBE2 = { 217, 64, 36, 102 },
	ROBE3 = { 218, 96, 58, 144 },
	ROBE4 = { 219, 140, 94, 196 },
	EYE = { 220, 255, 56, 64 },
	EYE_HI = { 221, 255, 196, 170 },
	STAFF_SH = { 222, 80, 92, 130 },
	STAFF = { 223, 132, 148, 186 },
	BLADE = { 224, 196, 196, 214 },
	BLADE_HI = { 225, 246, 246, 255 },
	BLADE_SH = { 226, 104, 100, 132 },
	RED0 = { 227, 92, 10, 30 },
	RED1 = { 228, 206, 32, 52 },
	RED2 = { 229, 255, 92, 92 },
	RED3 = { 230, 255, 176, 160 },
	BOLT0 = { 231, 98, 132, 255 },
	BOLT1 = { 232, 186, 208, 255 },
	TITLE_RED = { 234, 238, 64, 70 },
	TITLE_GOLD = { 235, 255, 214, 92 },
	TEXT_DIM = { 236, 124, 112, 160 },
	BOX_EDGE = { 237, 52, 44, 76 },
	BONE = { 238, 226, 218, 200 },
	BONE_SH = { 239, 150, 140, 130 },
	SHROOM = { 240, 90, 200, 210 },
	SHROOM_SH = { 241, 40, 110, 140 },
	-- reaper cloak: bone-white with cold ice-blue shading (the brightest thing on screen besides the
	-- hero), outlined in near-black navy
	CLOAK0 = { 242, 12, 14, 32 },
	CLOAK1 = { 243, 92, 116, 168 },
	CLOAK2 = { 244, 146, 172, 214 },
	CLOAK3 = { 245, 198, 214, 238 },
	CLOAK4 = { 246, 240, 240, 232 },
	RIM_COLD = { 247, 150, 176, 236 },
	RIM_WARM = { 248, 214, 128, 92 },
	BLADE_OUT = { 249, 30, 30, 48 },
	STAFF_OUT = { 250, 12, 14, 32 },
	SPARK = { 251, 255, 236, 250 },
	STEEL = { 252, 142, 140, 168 },
	CLOCK = { 253, 58, 70, 108 },
}

Palette.C = {} :: { [string]: number }
for name, v in FIXED do
	Palette.C[name] = v[1]
end

-- Material albedo (sRGB at full neutral light)
local ALBEDO = {
	[0] = { 96, 168, 80 }, -- grass
	{ 156, 108, 76 }, -- path
	{ 146, 148, 170 }, -- cobble
	{ 84, 96, 140 }, -- corrupted / drained stone (slate navy)
	{ 176, 176, 196 }, -- tomb / rock
	{ 84, 178, 84 }, -- leaf
	{ 146, 94, 64 }, -- trunk
	{ 168, 160, 198 }, -- dead tree
}

-- Light colour per tint (linear multipliers), and brightness per level.
local TINT = {
	[0] = { 0.5, 0.62, 1.0 }, -- night (moonlit)
	{ 1.0, 0.7, 0.3 }, -- warm (lantern, candles)
	{ 0.72, 0.88, 1.1 }, -- cold (ghost, lightning)
	{ 0.92, 0.5, 1.15 }, -- void purple
}
local LEVEL = { [0] = 0.03, 0.075, 0.16, 0.32, 0.58, 0.95 }
-- Lit levels also add some of the light colour itself, so warm pools read yellow, not lime.
local WASH = { [0] = 0, 0, 0.02, 0.07, 0.15, 0.27 }
local TINTMIX = { [0] = 0.0, 0.3, 0.65, 0.95, 1.0, 1.0 }
-- Shadows sink toward deep violet instead of black; the drained world (void stone, dead trees)
-- sinks to deep navy instead.
local SHADOW = { 0.010, 0.004, 0.026 }
local DRAIN_SHADOW = { 0.0015, 0.005, 0.02 }

local function toLin(c: number): number
	return (c / 255) ^ 2.2
end
local function toS(c: number): number
	return math.floor(255 * math.clamp(c, 0, 1) ^ (1 / 2.2) + 0.5)
end

-- Returns sRGB for a lit material entry.
function Palette.rgb(mat: number, tint: number, level: number): (number, number, number)
	local a = ALBEDO[mat]
	local n, tc = TINT[0], TINT[tint]
	local m = if tint == 0 then 0 else TINTMIX[level]
	local s = LEVEL[level] * 1.7
	local k = 1 - level / 5
	local sh = if mat == 3 or mat == 7 then DRAIN_SHADOW else SHADOW
	local rgb = table.create(3, 0)
	for ch = 1, 3 do
		local lc = n[ch] + (tc[ch] - n[ch]) * m
		rgb[ch] = toLin(a[ch]) * lc * s + sh[ch] * k + (if tint == 0 then 0 else tc[ch] * WASH[level] * m)
	end
	-- Soft clip: spill overflow into the other channels (hot highlights go toward white).
	local mx = math.max(rgb[1], rgb[2], rgb[3])
	if mx > 1 then
		local over = (mx - 1) * 0.5
		for ch = 1, 3 do
			rgb[ch] = math.min(1, rgb[ch] / mx + over)
		end
	end
	return toS(rgb[1]), toS(rgb[2]), toS(rgb[3])
end

function Palette.index(mat: number, tint: number, level: number): number
	return mat * 24 + tint * 6 + level
end

-- Load every colour into an IndexedFrame LUT.
function Palette.apply(frame: any)
	for mat = 0, 7 do
		for tint = 0, 3 do
			for lv = 0, 5 do
				local r, g, b = Palette.rgb(mat, tint, lv)
				frame:setColor(mat * 24 + tint * 6 + lv, r, g, b)
			end
		end
	end
	for _, v in FIXED do
		frame:setColor(v[1], v[2], v[3], v[4])
	end
end

-- Ordered dither ------------------------------------------------------------------------------

local B4 = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
local BAYER = table.create(16, 0)
for i = 1, 16 do
	BAYER[i] = (B4[i] + 0.5) / 16
end
Palette.BAYER = BAYER -- index (y%4)*4 + x%4 + 1, values in (0,1)

function Palette.bayer(x: number, y: number): number
	return BAYER[(y % 4) * 4 + x % 4 + 1]
end

-- Bands: the fractional part is contrast-stretched before the threshold, so most of a falloff is
-- flat colour and only a narrow band in between is checkerboarded.
Palette.SHARP = 2.6

function Palette.level(L: number, b: number): number
	local base = math.floor(L)
	local f = (L - base - 0.5) * 2.6 + 0.5
	return if f > b then base + 1 else base
end

return Palette
