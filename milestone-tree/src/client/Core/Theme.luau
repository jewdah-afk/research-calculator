--!strict
--[[
	Theme: colour tokens and layer hues (DESIGN.md 11.1), the colour rules (11.2: lift / shade / mix, the game colour
	remap, contrast lifts), the type roles (9) and the engine capability flags (13.1).

	    Theme.C.panel, Theme.hue("m"), Theme.lift(c, .45), Theme.remap("#793784", "p"), Theme.remapper("p")
	    Theme.font("title"), Theme.size("title")           -- the size for the current Layout mode and scale (floors held)
	    Theme.text(label, "body")                          -- FontFace + TextSize + LineHeight of a role (DESIGN.md 9.2)
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
	-- base: the cool neutral greys of the Sleek style (Core/Sleek.luau); the layer hue is the only accent
	void = hex("05070c"),
	deep = hex("070a11"),
	panel = hex("0c111a"),
	panel2 = hex("131a25"),
	panel3 = hex("1c2533"),
	stroke = hex("2b3444"),
	strokeHi = hex("4b5668"),
	text = hex("f3f6fb"),
	soft = hex("aab4c4"), -- secondary text, labels, hints (DESIGN.md 9.6; >= 8.4:1 on every dark surface)
	muted = hex("8a94a6"), -- tertiary only, >= 15 du on dark surfaces
	faint = hex("4d5566"), -- never text
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
	-- fixed text colours of the type table (DESIGN.md 9.2 / 9.6, 11.1)
	ownedTitle = hex("d7f7e1"),
	ownedValue = hex("a5efbc"),
	lockedTitle = hex("c9bfd0"),
	notYet = hex("d9b3be"),
	ready = hex("ffe08a"),
	dangerText = hex("f2d7dd"),
	ink = hex("06101b"), -- dark text on light hue fills
	termLime = hex("caffbf"),
	termDim = hex("9fdc92"),
	stableId = hex("5f8a58"),
	glass = hex("06090f"),
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
-- DESIGN.md 9.2: family, weight, italic, WIDE size (MEDIUM too; Theme.size lifts the floor roles when s < 1), COMPACT
-- size, LineHeight, and the rendered floor class ("caps" = 12 px, "text" = 13 px; DESIGN.md 9.5)
export type FloorClass = "caps" | "text"
export type Role = {
	family: string,
	weight: Enum.FontWeight,
	italic: boolean,
	wide: number,
	compact: number,
	lh: number,
	floor: FloorClass,
}
local function role(family: string, weight: Enum.FontWeight, italic: boolean, wide: number, compact: number, lh: number,
	floor: FloorClass?): Role
	return { family = family, weight = weight, italic = italic, wide = wide, compact = compact, lh = lh, floor = floor or "text" }
end
local W = Enum.FontWeight
local ROLES: { [string]: Role } = {
	-- display: Heavy / Sarpanch Heavy with outline + shadow (the loved look; nothing here shrank)
	hero = role("Sarpanch", W.Heavy, false, 56, 38, 1),
	title = role("Montserrat", W.Heavy, true, 44, 27, 1),
	big = role("Sarpanch", W.Heavy, false, 44, 30, 1),
	capsule = role("Sarpanch", W.Heavy, false, 34, 28, 1),
	index = role("Sarpanch", W.Heavy, false, 28, 22, 1),
	cta = role("Montserrat", W.Heavy, true, 26, 20, 1),
	section = role("Montserrat", W.Heavy, true, 24, 22, 1),
	resource = role("Montserrat", W.Heavy, true, 22, 18, 1),
	-- titles and labels: ExtraBold (Heavy fuses letters below 20 du); italic only on short titles
	card = role("Montserrat", W.ExtraBold, true, 20, 18, 1.1),
	toast = role("Montserrat", W.ExtraBold, true, 18, 16, 1),
	cardSmall = role("Montserrat", W.ExtraBold, true, 17, 16, 1.1),
	tab = role("Montserrat", W.ExtraBold, true, 16, 15, 1),
	plate = role("Montserrat", W.ExtraBold, false, 13, 12, 1.1, "caps"),
	label = role("Montserrat", W.ExtraBold, false, 14, 13, 1),
	-- numbers: Sarpanch for numeral runs only (words and units go through Rich.num)
	numberHeavy = role("Sarpanch", W.ExtraBold, false, 18, 17, 1),
	ctaSub = role("Sarpanch", W.Bold, false, 17, 15, 1),
	number = role("Sarpanch", W.Bold, false, 16, 15, 1),
	plateNum = role("Sarpanch", W.Bold, false, 15, 14, 1.1),
	badge = role("Sarpanch", W.ExtraBold, false, 14, 13, 1),
	-- reading text: upright, no outline, real line spacing
	body = role("Montserrat", W.SemiBold, false, 16, 15, 1.3),
	small = role("Montserrat", W.SemiBold, false, 14, 13, 1.25),
	caps = role("Montserrat", W.Bold, false, 13, 12, 1, "caps"),
	plateSub = role("Montserrat", W.ExtraBold, false, 13, 12, 1.1, "caps"),
	terminal = role("RobotoMono", W.Medium, false, 15, 14, 1.35),
	terminalBold = role("RobotoMono", W.Bold, false, 15, 14, 1.35),
}
Theme.ROLES = ROLES
-- rendered floors in px (TextSize x UI scale) on every device row, DESIGN.md 9.5
-- text floors in device points: with aspect scaling (Layout.compute) the design sizes hold down to s .55, so the floors
-- only catch text the design already sets very small
Theme.FLOOR = { caps = 7, text = 8, body = 8 }
Theme.COMPACT_FLOOR = 12

local fonts: { [string]: Font } = {}
function Theme.font(name: string): Font
	local hit = fonts[name]
	if hit then return hit end
	local r = ROLES[name] or ROLES.body
	local f = Font.fromName(r.family, r.weight, if r.italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
	fonts[name] = f
	return f
end

local layoutModule: any = nil
local function layout(): any
	if layoutModule == nil then layoutModule = require(script.Parent:WaitForChild("Layout")) :: any end
	return layoutModule
end
-- the TextSize of a role. mode defaults to Layout.mode; s to Layout.s when the mode is the current one, else 1.
-- COMPACT has s >= 1, so its table size is already on screen. WIDE / MEDIUM lift a role until size x s reaches its
-- floor: at s .90 the floor roles (small, label, badge, caps, plateSub) are written one du larger.
function Theme.size(name: string, mode: string?, s: number?): number
	local r = ROLES[name] or ROLES.body
	local floorPx = if r.floor == "caps" then Theme.FLOOR.caps else Theme.FLOOR.text
	local m: string = mode or layout().mode
	if m == "COMPACT" then return math.max(r.compact, floorPx) end
	local sc: number = s or (if mode == nil then layout().s else 1)
	return math.max(r.wide, math.ceil(floorPx / math.max(sc, 0.01) - 1e-6))
end
-- the role's LineHeight: 1 for single-line roles, 1.1 for titles that wrap, 1.25-1.35 for running text
function Theme.lineHeight(name: string): number
	return (ROLES[name] or ROLES.body).lh
end
-- FontFace + TextSize + LineHeight of a role on a TextLabel / TextButton / TextBox: the one way a label gets its type
function Theme.text(l: GuiObject, name: string, mode: string?)
	local t = l :: any
	t.FontFace = Theme.font(name)
	t.TextSize = Theme.size(name, mode)
	t.LineHeight = Theme.lineHeight(name)
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
	-- features that are a Studio-only beta stay off unless shared/Flags says they are live (so Studio shows what
	-- players see)
	pcall(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local shared = ReplicatedStorage:FindFirstChild("MilestoneTree")
		local mod = if shared then shared:FindFirstChild("Flags") else nil
		local flags: any = if mod and mod:IsA("ModuleScript") then require(mod) :: any else nil
		if not (flags and flags.BETA_GRADIENTS == true) then
			caps.Radial, caps.Conical, caps.TileMode = false, false, false
		end
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
