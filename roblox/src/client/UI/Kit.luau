--!nonstrict
-- UI kit that rebuilds the Figma "Clean Dark Blocky" style with native Roblox UI objects.
-- Everything is laid out on a 1280x720 reference canvas and scaled by a UIScale.

local Assets = require(script.Parent.Assets)

local Kit = {}

Kit.Colors = {
	Panel = Color3.fromRGB(14, 10, 24),
	Card = Color3.fromRGB(26, 21, 38),
	CardDark = Color3.fromRGB(23, 18, 31),
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1),
	Sub = Color3.fromRGB(125, 118, 150),
	Dim = Color3.fromRGB(74, 69, 96),
	Cash = Color3.fromRGB(124, 255, 91),
	CashDark = Color3.fromRGB(24, 184, 58),
	Gem = Color3.fromRGB(127, 227, 255),
	GemDark = Color3.fromRGB(44, 123, 255),
	Storm = Color3.fromRGB(227, 166, 255),
	StormDark = Color3.fromRGB(155, 61, 255),
	Gold = Color3.fromRGB(255, 225, 74),
	GoldDark = Color3.fromRGB(255, 122, 0),
	Red = Color3.fromRGB(255, 74, 61),
	RedDark = Color3.fromRGB(196, 20, 11),
	Pink = Color3.fromRGB(255, 61, 110),
	Purple = Color3.fromRGB(122, 31, 255),
	Cyan = Color3.fromRGB(92, 242, 255),
	Steel = Color3.fromRGB(124, 134, 166),
	SteelDark = Color3.fromRGB(63, 71, 102),
	Tab = Color3.fromRGB(58, 53, 80),
	TabDark = Color3.fromRGB(33, 29, 48),
}
local C = Kit.Colors

Kit.Fonts = {
	Heavy = Font.new("rbxasset://fonts/families/Rubik.json", Enum.FontWeight.Heavy),
	HeavyItalic = Font.new("rbxasset://fonts/families/Rubik.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	Bold = Font.new("rbxasset://fonts/families/Rubik.json", Enum.FontWeight.ExtraBold),
}

function Kit.new(class: string, props: { [string]: any }?, children: { Instance }?): Instance
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = Kit.new

function Kit.corner(px: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, px) })
end

function Kit.stroke(thickness: number, color: Color3?, transparency: number?): UIStroke
	return new("UIStroke", {
		Thickness = thickness,
		Color = color or C.Black,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Kit.textStroke(thickness: number): UIStroke
	return new("UIStroke", { Thickness = thickness, Color = C.Black, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

function Kit.gradient(a: Color3, b: Color3, rotation: number?): UIGradient
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90 })
end

function Kit.padding(l: number, r: number?, t: number?, b: number?): UIPadding
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingRight = UDim.new(0, r or l),
		PaddingTop = UDim.new(0, t or l),
		PaddingBottom = UDim.new(0, b or t or l),
	})
end

function Kit.list(dir: Enum.FillDirection, gap: number, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return new("UIListLayout", {
		FillDirection = dir,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	})
end

-- Text label with optional black outline and gradient fill.
function Kit.text(props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = props.font or Kit.Fonts.Heavy,
		Text = props.text or "",
		TextSize = props.size or 16,
		TextColor3 = props.color or C.White,
		TextXAlignment = props.alignX or Enum.TextXAlignment.Left,
		TextYAlignment = props.alignY or Enum.TextYAlignment.Center,
		Size = props.dim or UDim2.new(1, 0, 0, (props.size or 16) + 4),
		Position = props.pos or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		AutomaticSize = props.auto or Enum.AutomaticSize.None,
		RichText = props.rich or false,
		TextWrapped = props.wrap or false,
		LayoutOrder = props.order or 0,
		Name = props.name or "Text",
		Parent = props.parent,
	})
	if props.outline then
		Kit.textStroke(props.outline).Parent = t
	end
	if props.gradient then
		t.TextColor3 = C.White
		Kit.gradient(props.gradient[1], props.gradient[2], 90).Parent = t
	end
	return t
end

-- Tiled texture overlay (no-op if the asset id isn't set yet)
function Kit.texture(parent: GuiObject, key: string, transparency: number?, tile: number?)
	local image = Assets.Textures[key]
	if image == "" then
		return nil
	end
	return new("ImageLabel", {
		Name = "Tex_" .. key,
		BackgroundTransparency = 1,
		Image = image,
		ImageTransparency = transparency or 0.4,
		ScaleType = if tile then Enum.ScaleType.Tile else Enum.ScaleType.Stretch,
		TileSize = UDim2.fromOffset(tile or 64, tile or 64),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
end

-- Icon: uploaded Blender render if available, else a gradient tile with a glyph.
local FALLBACK = {
	cash = { "$", C.Cash, C.CashDark },
	gem = { "◆", C.Gem, C.GemDark },
	storm = { "ϟ", C.Storm, C.StormDark },
	clover = { "♣", C.Cash, C.CashDark },
	bolt = { "ϟ", C.Gold, C.GoldDark },
	fastdrop = { "»", C.Storm, C.StormDark },
	star = { "★", C.Gold, C.GoldDark },
	tier = { "▲", C.Pink, C.RedDark },
	spawn = { "●", C.Gem, C.GemDark },
	rebirth = { "↻", C.Gold, C.GoldDark },
	gear = { "⚙", C.Steel, C.SteelDark },
}
function Kit.icon(name: string, size: number, props)
	props = props or {}
	local image = Assets.Icons[name] or ""
	if image ~= "" then
		return new("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(size, size),
			Position = props.pos or UDim2.new(),
			AnchorPoint = props.anchor or Vector2.zero,
			LayoutOrder = props.order or 0,
			ZIndex = props.z or 2,
			Parent = props.parent,
		})
	end
	local fb = FALLBACK[name] or { "?", C.Steel, C.SteelDark }
	local f = new("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(size * 0.78, size * 0.78),
		Position = props.pos or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = C.White,
		LayoutOrder = props.order or 0,
		ZIndex = props.z or 2,
		Parent = props.parent,
	}, { Kit.corner(6), Kit.stroke(2.5), Kit.gradient(fb[2], fb[3]) })
	Kit.text({ text = fb[1], size = size * 0.5, alignX = Enum.TextXAlignment.Center, dim = UDim2.fromScale(1, 1), outline = 2, parent = f })
	return f
end

-- Dark slab panel with gradient header (title + optional close X). Returns panel, body.
function Kit.panel(props)
	local panel = new("Frame", {
		Name = props.name or "Panel",
		Size = props.dim,
		Position = props.pos,
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.16,
		ClipsDescendants = true,
		ZIndex = props.z or 1,
		Parent = props.parent,
	}, { Kit.corner(8), Kit.stroke(4) })
	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, props.headerHeight or 52),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = (props.z or 1) + 1,
		Parent = panel,
	}, { Kit.gradient(props.color1, props.color2, 0) })
	Kit.texture(header, "studTile", 0.55, 48)
	Kit.texture(header, "sheen", 0.4)
	Kit.text({ text = props.title, size = 26, outline = 3.5, dim = UDim2.new(1, -70, 1, 0), pos = UDim2.fromOffset(14, 0), parent = header }).ZIndex = (props.z or 1) + 2
	new("Frame", { Name = "Rule", Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Black, BorderSizePixel = 0, ZIndex = (props.z or 1) + 2, Parent = header })
	local close
	if props.onClose then
		close = new("TextButton", {
			Name = "Close",
			Text = "",
			AutoButtonColor = true,
			Size = UDim2.new(0, props.headerHeight or 52, 1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = C.White,
			ZIndex = (props.z or 1) + 3,
			Parent = header,
		}, { Kit.gradient(C.Red, C.RedDark) })
		Kit.texture(close, "studTile", 0.55, 48)
		Kit.text({ text = "X", size = 28, outline = 3, alignX = Enum.TextXAlignment.Center, dim = UDim2.fromScale(1, 1), parent = close }).ZIndex = (props.z or 1) + 4
		close.Activated:Connect(props.onClose)
	end
	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -((props.headerHeight or 52) + 4)),
		Position = UDim2.fromOffset(0, (props.headerHeight or 52) + 4),
		ZIndex = (props.z or 1) + 1,
		Parent = panel,
	}, { Kit.padding(10, 10, 10, 12) })
	return panel, body
end

-- Flat bright button. Returns the TextButton; update text with Kit.setLabel.
function Kit.button(props)
	local b = new("TextButton", {
		Name = props.name or "Button",
		Text = "",
		AutoButtonColor = true,
		Size = props.dim or UDim2.fromOffset(86, 34),
		Position = props.pos or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = C.White,
		LayoutOrder = props.order or 0,
		ClipsDescendants = true,
		ZIndex = props.z or 2,
		Parent = props.parent,
	}, { Kit.corner(5), Kit.stroke(3), Kit.gradient(props.color1 or C.Cash, props.color2 or C.CashDark) })
	Kit.texture(b, "studTile", 0.75, 40)
	local label = Kit.text({
		name = "Label",
		text = props.text or "",
		size = props.size or 15,
		outline = 2.5,
		alignX = Enum.TextXAlignment.Center,
		dim = UDim2.fromScale(1, 1),
		parent = b,
	})
	label.ZIndex = (props.z or 2) + 1
	if props.onClick then
		b.Activated:Connect(props.onClick)
	end
	return b
end

function Kit.setLabel(button: Instance, text: string)
	local l = button:FindFirstChild("Label")
	if l and l.Text ~= text then
		l.Text = text
	end
end

function Kit.setButtonColors(button: Instance, a: Color3, b: Color3)
	local g = button:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(a, b)
	end
end

-- Enabled/disabled look for purchase buttons
function Kit.setAffordable(button: Instance, ok: boolean)
	if ok then
		Kit.setButtonColors(button, Color3.fromRGB(91, 255, 74), Color3.fromRGB(18, 166, 46))
	else
		Kit.setButtonColors(button, C.Tab, C.TabDark)
	end
end

-- Glossy striped progress bar. Returns frame + setter(pct, c1, c2)
function Kit.bar(props)
	local f = new("Frame", {
		Name = "Bar",
		Size = props.dim or UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Color3.fromRGB(28, 24, 40),
		LayoutOrder = props.order or 0,
		ClipsDescendants = true,
		Parent = props.parent,
	}, { Kit.corner(3), Kit.stroke(2) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.White, BorderSizePixel = 0, Parent = f }, {
		Kit.corner(3),
		Kit.gradient(props.color1 or C.Cash, props.color2 or C.CashDark),
	})
	Kit.texture(fill, "stripes", 0.6, 24)
	local function set(pct: number)
		fill.Size = UDim2.fromScale(math.clamp(pct, 0, 1), 1)
	end
	return f, set
end

-- Dark card row (stripes texture inside), auto-height horizontal layout
function Kit.card(props)
	local c = new("Frame", {
		Name = props.name or "Card",
		Size = props.dim or UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = C.White,
		LayoutOrder = props.order or 0,
		ClipsDescendants = true,
		Parent = props.parent,
	}, { Kit.corner(5), Kit.stroke(2.5), Kit.gradient(C.Card, C.CardDark) })
	Kit.texture(c, "stripes", 0.75, 48)
	return c
end

-- Scrolling list container
function Kit.scroll(props)
	local s = new("ScrollingFrame", {
		Name = props.name or "Scroll",
		Size = props.dim or UDim2.fromScale(1, 1),
		Position = props.pos or UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Sub,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	}, { Kit.list(Enum.FillDirection.Vertical, props.gap or 6) })
	return s
end

return Kit
