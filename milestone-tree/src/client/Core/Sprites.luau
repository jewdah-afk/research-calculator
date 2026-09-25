--!strict
--[[
	Sprites: the UI atlas regions and tile textures of Assets.ui (DESIGN.md 14, plan 3.4), with the procedural
	fallback of plan 3.5 for every sprite whose image is not uploaded yet (Assets ids are nil until then).

	    Sprites.image("glow_circle", parent, { tint = c, alpha = .5 })   -- always an ImageLabel
	    Sprites.slice("bevel_card", label, scale)                         -- 9-slice setup of an atlas label
	    Sprites.texture("tile_stripes")                                   -- a standalone tile texture id, or nil
	    Sprites.has(name), Sprites.tier / Sprites.setTier("LOW")

	The fallback keeps the same ImageLabel (so callers size and place it the same way) and draws with its background
	instead: a Radial gradient blob for glows and auras, a gradient lip overlay for bevels, a dashed stroke for the
	dashed ring, a filled disc for circles, one Latin-1 glyph (or a small dot) for icons, nothing for rays.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent:WaitForChild("Theme"))

local Sprites = {}

Sprites.tier = "HIGH" :: string

type Region = { x: number, y: number, w: number, h: number, scale: number?, slice: { number }?, tint: boolean? }
type Ui = {
	atlas: { HIGH: string?, LOW: string? },
	size: { HIGH: { number }?, LOW: { number }? }?,
	regions: { [string]: Region },
	textures: { [string]: { id: string?, w: number, h: number } }?,
}

local ui: Ui? = nil
local loaded = false
local function assetsUi(): Ui?
	if loaded then return ui end
	loaded = true
	local ok, assets = pcall(function(): any
		local m: any = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Assets"))
		return m
	end)
	if ok and type(assets) == "table" and type(assets.ui) == "table" and type(assets.ui.regions) == "table" then
		ui = assets.ui :: Ui
	end
	return ui
end

function Sprites.setTier(t: string)
	Sprites.tier = if t == "LOW" then "LOW" else "HIGH"
end

local function atlasId(): string?
	local u = assetsUi()
	if u == nil or type(u.atlas) ~= "table" then return nil end
	local id = if Sprites.tier == "LOW" then u.atlas.LOW or u.atlas.HIGH else u.atlas.HIGH
	return if type(id) == "string" and id ~= "" then id else nil
end
local function region(name: string): Region?
	local u = assetsUi()
	if u == nil then return nil end
	local r = u.regions[name]
	return if type(r) == "table" then r else nil
end

-- the atlas is uploaded and has this region
function Sprites.has(name: string): boolean
	return atlasId() ~= nil and region(name) ~= nil
end

-- a standalone tile texture id (R9), nil when not uploaded
function Sprites.texture(name: string): string?
	local u = assetsUi()
	if u == nil or type(u.textures) ~= "table" then return nil end
	local t = (u.textures :: any)[name]
	if type(t) ~= "table" or type(t.id) ~= "string" or t.id == "" then return nil end
	return t.id
end

-- the fallback glyph per icon: Montserrat's Latin-1 set only (DESIGN.md P11); anything else is a small dot
Sprites.FALLBACK_GLYPH = {
	plus = "+", minus = "–", x = "×", warn = "!", info = "i", chev = "›", chevr = "›", right = "›", left = "‹",
	star = "*", sparkle = "*", coin_star = "*", export = "›", import = "‹", copy = "+", trash = "×", check = "·",
	bolt = "!", badge_bolt = "!", badge_bang = "!", up = "+", down = "–", sort = "…", text = "A", target = "·",
} :: { [string]: string }
local ICONS: { [string]: boolean } = {}
for _, n in {
	"gear", "star", "home", "bell", "lock", "plus", "minus", "x", "save", "export", "import", "copy", "trash", "warn", "info",
	"check", "chev", "chevr", "up", "down", "left", "right", "bolt", "sparkle", "swirl", "moon", "bug", "flame", "hand", "clock",
	"eye", "sort", "grid", "motion", "map", "text", "target", "disk", "badge_bolt", "badge_bang", "coin_star", "hex",
	"ember", "sparkle_small",
} do
	ICONS[n] = true
end

local function child<T>(parent: Instance, name: string, class: string): T
	local c = parent:FindFirstChild(name)
	if c and c.ClassName == class then return (c :: any) :: T end
	if c then c:Destroy() end
	local n = Instance.new(class :: any)
	n.Name = name
	n.Parent = parent
	return (n :: any) :: T
end
Sprites.child = child

local function clearFallback(l: ImageLabel)
	for _, n in { "FbCorner", "FbGradient", "FbStroke", "FbGlyph", "FbDot" } do
		local c = l:FindFirstChild(n)
		if c then c:Destroy() end
	end
end

local function fallback(name: string, l: ImageLabel, tint: Color3, alpha: number)
	l.Image = ""
	l.BackgroundTransparency = 1
	l.BackgroundColor3 = tint
	local caps = Theme.caps
	if name == "glow_rr" or name == "glow_circle" or name == "aura" or string.sub(name, 1, 7) == "radial_" then
		if caps.Radial then
			local corner = child(l, "FbCorner", "UICorner") :: UICorner
			corner.CornerRadius = UDim.new(0.5, 0)
			local g = child(l, "FbGradient", "UIGradient") :: UIGradient
			g.Type = Enum.GradientType.Radial
			local a0 = 1 - alpha
			g.Transparency = if name == "aura"
				then NumberSequence.new({
					NumberSequenceKeypoint.new(0, a0),
					NumberSequenceKeypoint.new(0.55, 1 - alpha * 0.27),
					NumberSequenceKeypoint.new(1, 1),
				})
				else NumberSequence.new({
					NumberSequenceKeypoint.new(0, a0),
					NumberSequenceKeypoint.new(0.5, 1 - alpha * 0.45),
					NumberSequenceKeypoint.new(1, 1),
				})
			l.BackgroundTransparency = 0
		end
	elseif name == "bevel_button" or name == "bevel_card" or name == "bevel_ring" then
		-- white lip at the top, clear middle, black lip at the bottom (the same UICorner as the target)
		l.BackgroundColor3 = Color3.new(1, 1, 1)
		l.BackgroundTransparency = 0
		local parent = l.Parent
		local pc = if parent then parent:FindFirstChildWhichIsA("UICorner") else nil
		local corner = child(l, "FbCorner", "UICorner") :: UICorner
		corner.CornerRadius = if name == "bevel_ring" then UDim.new(0.5, 0) elseif pc then pc.CornerRadius else UDim.new(0, 8)
		local g = child(l, "FbGradient", "UIGradient") :: UIGradient
		g.Rotation = 90
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.51, Color3.new(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
		})
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(0.12, 1),
			NumberSequenceKeypoint.new(0.8, 1),
			NumberSequenceKeypoint.new(1, 0.7),
		})
	elseif name == "ring_dashed" then
		local corner = child(l, "FbCorner", "UICorner") :: UICorner
		corner.CornerRadius = UDim.new(0.5, 0)
		local st = child(l, "FbStroke", "UIStroke") :: UIStroke
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Color = tint
		st.Thickness = 3
		st.Transparency = if caps.TileMode then 1 - alpha else math.max(1 - alpha, 0.3)
		if caps.TileMode then
			local g = child(st, "Dash", "UIGradient") :: UIGradient
			g.Rotation = 45
			g.TileMode = Enum.GradientTileMode.Repeat
			g.Scale = 0.08
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.6, 0),
				NumberSequenceKeypoint.new(0.61, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	elseif name == "circle" or name == "halfdisc" or name == "chip" or name == "keycap" or name == "hex" then
		local corner = child(l, "FbCorner", "UICorner") :: UICorner
		corner.CornerRadius = if name == "chip" or name == "keycap" then UDim.new(0.3, 0) else UDim.new(0.5, 0)
		l.BackgroundTransparency = 1 - alpha
	elseif name == "shadow_card" then
		local corner = child(l, "FbCorner", "UICorner") :: UICorner
		corner.CornerRadius = UDim.new(0, 16)
		l.BackgroundColor3 = Color3.new(0, 0, 0)
		l.BackgroundTransparency = 1 - alpha * 0.35
	elseif ICONS[name] then
		local glyph = Sprites.FALLBACK_GLYPH[name]
		if glyph then
			local t = child(l, "FbGlyph", "TextLabel") :: TextLabel
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = glyph
			t.TextScaled = true
			t.TextColor3 = tint
			t.TextTransparency = 1 - alpha
			t.FontFace = Theme.font("small")
			t.Active = false
		else
			-- a small dot in the tint
			local dot = child(l, "FbDot", "Frame") :: Frame
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromScale(0.5, 0.5)
			dot.Size = UDim2.fromScale(0.36, 0.36)
			dot.BorderSizePixel = 0
			dot.BackgroundColor3 = tint
			dot.BackgroundTransparency = 1 - alpha * 0.9
			dot.Active = false
			local corner = child(dot, "FbCorner", "UICorner") :: UICorner
			corner.CornerRadius = UDim.new(0.5, 0)
		end
	end
	-- rays and anything unknown: nothing drawn
end

local function applyRegion(l: ImageLabel, id: string, r: Region)
	local k = if Sprites.tier == "LOW" then 0.5 else 1
	l.Image = id
	l.ImageRectOffset = Vector2.new(r.x * k, r.y * k)
	l.ImageRectSize = Vector2.new(r.w * k, r.h * k)
	l.BackgroundTransparency = 1
end

-- An ImageLabel showing a sprite (get-or-create by the parent's child named `name` when a parent is given).
-- o.tint colours white regions and the fallback; o.alpha is the opacity (1 - transparency).
function Sprites.image(name: string, parent: Instance?, o: { tint: Color3?, alpha: number?, key: string? }?): ImageLabel
	local opts: { tint: Color3?, alpha: number?, key: string? } = o or {}
	local key = opts.key or ("Sprite_" .. name)
	local l: ImageLabel
	local existing = if parent then parent:FindFirstChild(key) else nil
	if existing and existing:IsA("ImageLabel") then
		l = existing
	else
		if existing then existing:Destroy() end
		l = Instance.new("ImageLabel")
		l.Name = key
		l.BorderSizePixel = 0
		l.BackgroundTransparency = 1
		l.Active = false
		l.Size = UDim2.fromScale(1, 1)
	end
	local tint = opts.tint or Color3.new(1, 1, 1)
	local alpha = if opts.alpha ~= nil then opts.alpha else 1
	local id = atlasId()
	local r = region(name)
	if id and r then
		clearFallback(l)
		applyRegion(l, id, r)
		l.ImageColor3 = if r.tint == false then Color3.new(1, 1, 1) else tint
		l.ImageTransparency = 1 - alpha
	else
		l.ImageTransparency = 1
		if l.Parent == nil and parent then l.Parent = parent end
		fallback(name, l, tint, alpha)
	end
	if parent and l.Parent ~= parent then l.Parent = parent end
	return l
end

-- 9-slice: SliceCenter from the region spec, SliceScale (the @2x regions display at half size)
function Sprites.slice(name: string, f: ImageLabel, scale: number?)
	local r = region(name)
	if r == nil or atlasId() == nil then return end
	local sl = r.slice
	if sl == nil then return end
	local k = if Sprites.tier == "LOW" then 0.5 else 1
	f.ScaleType = Enum.ScaleType.Slice
	f.SliceCenter = Rect.new(sl[1] * k, sl[2] * k, sl[3] * k, sl[4] * k)
	f.SliceScale = (scale or 1) * (r.scale or 1) / k
end

return Sprites
