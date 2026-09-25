--!strict
--[[
	Theme: colour tokens and layer hues (DESIGN.md 11.1), the colour rules (11.2: lift / shade / mix, the game colour
	remap, contrast lifts), the type roles (9) and the engine capability flags (13.1).

	    Theme.C.panel, Theme.hue("m"), Theme.lift(c, .45), Theme.remap("#793784", "p"), Theme.remapper("p")
	    Theme.font("title"), Theme.size("title")           -- the size for the current Layout mode
	    Theme.detect(); Theme.caps.Radial                  -- pcall probes, once at start (App)

	Colour maths uses Color3.new with the channels, so it runs on the test engine too.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Html = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Html"))

local Theme = {}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

-- ------------------------------------------------------------------------------------------------------ tokens
Theme.C = {
	-- base
	void = hex("07060d"),
	deep = hex("0d0b16"),
	panel = hex("14111f"),
	panel2 = hex("1c1829"),
	panel3 = hex("262138"),
	stroke = hex("3a3352"),
	strokeHi = hex("6a5f8f"),
	text = hex("f2f0ff"),
	muted = hex("9a94b8"),
	faint = hex("5c5775"),
	-- state
	bought = hex("4be07a"),
	locked = hex("8a6f7a"),
	complete = hex("ffc233"),
	danger = hex("ff3b5c"),
	gold = hex("ffd34d"),
	-- extra
	info = hex("7a8cff"),
	lockedLink = hex("c7b8f2"),
	ember = hex("ff7a2e"),
	system = hex("9d8cff"),
	-- fixed text colours of the type table (DESIGN.md 9)
	ownedTitle = hex("d7f7e1"),
	lockedTitle = hex("c9bfd0"),
	notYet = hex("d9b3be"),
	termLime = hex("caffbf"),
	termDim = hex("9fdc92"),
	glass = hex("090711"),
	white = Color3.new(1, 1, 1),
	black = Color3.new(0, 0, 0),
}

-- layer hues, keyed by game id (DESIGN.md 11.1)
local HUES: { [string]: string } = {
	m = "b35cff", mm = "d17aff", em = "e88af2", p = "6fc3ff", pe = "ff9a2e", sp = "5fe0ff", pb = "57e0b0", pp = "ff4d6d",
	se = "ff6a1f", hp = "7fd9ff", ep = "9be02c", hb = "6dffb0", ap = "8ff3f3", mp = "ff5a1f", t = "ffe93a", pm = "ff2e63",
	pep = "f2b04d", cp = "39ff14", cm = "1fbf4a", ex = "45e07f", ach = "ffc93c",
}
local hueCache: { [string]: Color3 } = {}
-- a layer's hue; "cp" is the corrupted lime, "options-tab" the system violet, unknown keys the text colour
function Theme.hue(layer: string?): Color3
	if layer == nil then return Theme.C.text end
	local hit = hueCache[layer]
	if hit then return hit end
	local h = HUES[layer]
	local c: Color3 = if h then hex(h) elseif layer == "options-tab" then Theme.C.system else Theme.C.text
	hueCache[layer] = c
	return c
end
Theme.LAYERS = HUES

-- ------------------------------------------------------------------------------------------------------ colour maths
function Theme.mix(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
-- toward white by t (the Figma lift)
function Theme.lift(c: Color3, t: number): Color3
	return Theme.mix(c, Color3.new(1, 1, 1), t)
end
-- darker by factor k (c * k)
function Theme.shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
function Theme.rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end
function Theme.toHex(c: Color3): string
	local function b(x: number): number return math.clamp(math.floor(x * 255 + 0.5), 0, 255) end
	return string.format("%02x%02x%02x", b(c.R), b(c.G), b(c.B))
end

-- WCAG relative luminance and contrast ratio
local function lin(x: number): number
	return if x <= 0.03928 then x / 12.92 else ((x + 0.055) / 1.055) ^ 2.4
end
function Theme.luminance(c: Color3): number
	return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end
function Theme.contrast(a: Color3, b: Color3): number
	local la, lb = Theme.luminance(a), Theme.luminance(b)
	if la < lb then la, lb = lb, la end
	return (la + 0.05) / (lb + 0.05)
end

-- rule 3: the smallest lift that makes coloured text readable on the panel (precomputed; others need none)
local TEXT_LIFT: { [string]: number } = { m = 0.25, pp = 0.20, mp = 0.20, se = 0.10, pm = 0.35 }
function Theme.textLift(layer: string?): number
	return if layer then TEXT_LIFT[layer] or 0 else 0
end
-- a layer's hue as body text on the panel
function Theme.textHue(layer: string?): Color3
	return Theme.lift(Theme.hue(layer), Theme.textLift(layer))
end

-- rule 4: small text on these hue fills is dark, without a stroke
local LIGHT_FILL: { [string]: boolean } = {
	t = true, ach = true, cp = true, hb = true, ap = true, sp = true, hp = true, ep = true, pb = true, p = true, pep = true,
	ex = true, em = true,
}
function Theme.darkOnFill(layer: string?): boolean
	return layer ~= nil and LIGHT_FILL[layer] == true
end

-- ------------------------------------------------------------------------------------------------------ the remap
-- rule 2: game colours become tokens wherever they arrive. Keys are CSS names (checked first, lower case) or hex.
local REMAP_NAME: { [string]: string } = {
	black = "@cp", darkgreen = "@cm", gold = "@ach", red = "danger", lime = "@cp", green = "bought", yellow = "complete",
}
local REMAP_HEX: { [string]: string } = {
	["793784"] = "@m",
	["9f2846"] = "danger", c25757 = "danger", ee7070 = "danger", c86a6a = "danger",
	["652021"] = "@pp",
	["648c11"] = "@ep",
	d03800 = "@mp",
	ffff00 = "@t",
	["000000"] = "@cp",
	["006400"] = "@cm",
	ffd700 = "@ach",
	ff0000 = "danger",
	["00ff00"] = "@cp",
	["008000"] = "bought",
}
local function token(key: string): (Color3, string?)
	if string.sub(key, 1, 1) == "@" then
		local layer = string.sub(key, 2)
		return Theme.hue(layer), layer
	end
	return (Theme.C :: any)[key] :: Color3, nil
end
local function lookup(css: string): string?
	local s = string.lower((string.gsub(css, "^%s+", "")))
	s = string.gsub(s, "%s*!important%s*$", "")
	s = string.gsub(s, "%s+$", "")
	local byName = REMAP_NAME[s]
	if byName then return byName end
	local h = Html.hex(s)
	if h then return REMAP_HEX[string.lower(h)] end
	return nil
end
-- a game colour -> the client colour (unknown colours: lift(c, .35)); nil when the CSS is not a colour
function Theme.remap(css: string?, layer: string?): Color3?
	if css == nil then return nil end
	local key = lookup(css)
	if key then return (token(key)) end
	local c = Html.color(css)
	if c == nil then return nil end
	return Theme.lift(c, 0.35)
end
-- the same for backgrounds: black backgrounds are removed (nil)
function Theme.remapBg(css: string?, layer: string?): Color3?
	if css == nil then return nil end
	local h = Html.hex(css)
	if h == nil then return nil end
	local c = Color3.fromHex(h)
	if c.R + c.G + c.B < 0.09 then return nil end
	return Theme.remap(css, layer)
end
-- for Html.rich's remap argument: "rrggbb" -> "rrggbb", with the contrast lift of the target layer applied
local remappers: { [string]: (string) -> string } = {}
function Theme.remapper(layer: string?): (hex: string) -> string
	local k = layer or ""
	local hit = remappers[k]
	if hit then return hit end
	local memo: { [string]: string } = {}
	local f = function(h: string): string
		local hit = memo[h]
		if hit then return hit end
		local key = REMAP_HEX[string.lower(h)]
		local out: Color3
		if key then
			local c, owner = token(key)
			out = if owner then Theme.lift(c, Theme.textLift(owner)) else c
		else
			local ok, c = pcall(Color3.fromHex, h)
			out = if ok then Theme.lift(c, 0.35) else Theme.C.text
		end
		local r = Theme.toHex(out)
		memo[h] = r
		return r
	end
	remappers[k] = f
	return f
end

-- ------------------------------------------------------------------------------------------------------ type roles
-- DESIGN.md 9: family, weight, italic, WIDE size (MEDIUM uses it too under the smaller UI scale), COMPACT size
type Role = { family: string, weight: Enum.FontWeight, italic: boolean, wide: number, compact: number }
local function role(family: string, weight: Enum.FontWeight, italic: boolean, wide: number, compact: number): Role
	return { family = family, weight = weight, italic = italic, wide = wide, compact = compact }
end
local W = Enum.FontWeight
local ROLES: { [string]: Role } = {
	title = role("Montserrat", W.Heavy, true, 44, 22),
	hero = role("Sarpanch", W.Heavy, false, 56, 36),
	capsule = role("Sarpanch", W.Heavy, false, 34, 26),
	cta = role("Montserrat", W.Heavy, true, 26, 18),
	section = role("Montserrat", W.Heavy, true, 22, 15),
	resource = role("Montserrat", W.Heavy, true, 20, 14),
	card = role("Montserrat", W.Heavy, true, 16, 14),
	toast = role("Montserrat", W.Heavy, true, 15, 13),
	tab = role("Montserrat", W.Heavy, true, 14, 13),
	plate = role("Montserrat", W.Heavy, true, 13, 11),
	big = role("Sarpanch", W.Heavy, false, 44, 28),
	index = role("Sarpanch", W.Heavy, false, 26, 20),
	number = role("Sarpanch", W.Bold, false, 15, 12),
	numberHeavy = role("Sarpanch", W.Heavy, false, 15, 12),
	body = role("Montserrat", W.SemiBold, false, 13, 12),
	small = role("Montserrat", W.Bold, false, 13, 12),
	caps = role("Montserrat", W.ExtraBold, false, 12, 11),
	terminal = role("RobotoMono", W.Medium, false, 13, 12),
	terminalBold = role("RobotoMono", W.Bold, false, 13, 12),
}
Theme.ROLES = ROLES
Theme.COMPACT_FLOOR = 11

local fonts: { [string]: Font } = {}
function Theme.font(name: string): Font
	local hit = fonts[name]
	if hit then return hit end
	local r = ROLES[name] or ROLES.body
	local f = Font.fromName(r.family, r.weight, if r.italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
	fonts[name] = f
	return f
end
-- the size of a role for a layout mode (default: the current Layout.mode)
local layoutModule: any = nil
function Theme.size(name: string, mode: string?): number
	local r = ROLES[name] or ROLES.body
	local m = mode
	if m == nil then
		if layoutModule == nil then layoutModule = require(script.Parent:WaitForChild("Layout")) :: any end
		m = layoutModule.mode
	end
	if m == "COMPACT" then return math.max(Theme.COMPACT_FLOOR, r.compact) end
	return r.wide
end

-- ------------------------------------------------------------------------------------------------------ capabilities
export type Caps = {
	UIShadow: boolean,
	Radial: boolean,
	Conical: boolean,
	TileMode: boolean,
	BorderStrokePosition: boolean,
	Path2D: boolean,
	PerCorner: boolean,
	InputSink: boolean,
}
-- every flag false until detect() ran: the plain fallbacks are always safe
Theme.caps = {
	UIShadow = false,
	Radial = false,
	Conical = false,
	TileMode = false,
	BorderStrokePosition = false,
	Path2D = false,
	PerCorner = false,
	InputSink = false,
} :: Caps
local detected = false

local function probe(fn: () -> ()): boolean
	local ok = pcall(fn)
	return ok
end
-- pcall probes on throwaway instances (DESIGN.md 13.1). In Studio, the LocalPlayer attribute MT_ForceCaps
-- ("Radial,Path2D" or "all") forces flags off to check the fallbacks.
function Theme.detect(force: boolean?): Caps
	if detected and not force then return Theme.caps end
	detected = true
	local caps = Theme.caps
	caps.UIShadow = probe(function()
		local s = Instance.new("UIShadow")
		s.BlurRadius = UDim.new(0, 8)
		s:Destroy()
	end)
	caps.Radial = probe(function()
		local g = Instance.new("UIGradient")
		g.Type = Enum.GradientType.Radial
		g:Destroy()
	end)
	caps.Conical = probe(function()
		local g = Instance.new("UIGradient")
		g.Type = Enum.GradientType.Conical
		g:Destroy()
	end)
	caps.TileMode = probe(function()
		local g = Instance.new("UIGradient")
		g.TileMode = Enum.GradientTileMode.Repeat
		g.Scale = 0.1
		g:Destroy()
	end)
	caps.BorderStrokePosition = probe(function()
		local s = Instance.new("UIStroke")
		s.BorderStrokePosition = Enum.BorderStrokePosition.Outer
		s:Destroy()
	end)
	caps.Path2D = probe(function()
		local p = Instance.new("Path2D")
		p:SetControlPoints({ Path2DControlPoint.new(UDim2.fromScale(0, 0)), Path2DControlPoint.new(UDim2.fromScale(1, 1)) })
		p:Destroy()
	end)
	caps.PerCorner = probe(function()
		local c = Instance.new("UICorner")
		c.TopLeftRadius = UDim.new(0, 4)
		c:Destroy()
	end)
	caps.InputSink = probe(function()
		local f = Instance.new("Frame")
		f.InputSink = Enum.InputSink.None
		f:Destroy()
	end)
	-- Studio only: force flags off
	pcall(function()
		local RunService = game:GetService("RunService")
		if not RunService:IsStudio() then return end
		local lp = game:GetService("Players").LocalPlayer
		local forced = if lp then lp:GetAttribute("MT_ForceCaps") else nil
		if type(forced) ~= "string" or forced == "" then return end
		for name in string.gmatch(forced, "[%w]+") do
			if name == "all" then
				for k in caps :: any do (caps :: any)[k] = false end
			elseif (caps :: any)[name] ~= nil then
				(caps :: any)[name] = false
			end
		end
	end)
	local list = {}
	for _, k in { "UIShadow", "Radial", "Conical", "TileMode", "BorderStrokePosition", "Path2D", "PerCorner", "InputSink" } do
		table.insert(list, k .. "=" .. tostring((caps :: any)[k]))
	end
	print("[MilestoneTree] caps " .. table.concat(list, " "))
	return caps
end

return Theme
