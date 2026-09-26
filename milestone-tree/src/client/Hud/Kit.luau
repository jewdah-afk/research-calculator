--!strict
--[[
	Kit: the small construction helpers the map widgets, the HUD and the overlays share (packages F and G).

	    Kit.frame(parent, name, z?)                 a transparent, inert Frame (get-or-create by name)
	    Kit.label(parent, name, role, text, color)  a TextLabel with the role's type (Theme.text), no background
	    Kit.corner(f, r) / Kit.stroke(f, px, color, a?) / Kit.grad(f, colors, rot?, alphas?) / Kit.pad(f, t, r, b, l)
	    Kit.list(f, dir, gap, h?, v?)               a UIListLayout (SortOrder LayoutOrder)
	    Kit.blob(parent, name, color, alpha)        a soft round glow; the radial fade ends at t = .7 and a UICorner
	                                                keeps it round (a Radial UIGradient on a square frame reaches the
	                                                corners, so a fade to 1 draws a square). nil without Radial.
	    Kit.gem(f, c, dark?)                        the gem fill of nodes, gems and emblems (radial, same rule)
	    Kit.glyph(parent, name, kind, color, bg?)   an icon built from frames (no emoji, no font glyphs): bolt, bang,
	                                                lock, moon, star, home, gear, plus, minus, x, check, up, down,
	                                                chev, swirl, bell, warn, clock, save, ring. Scale units of a
	                                                square holder; size and place the returned Frame.
	    Kit.spin(inst, seconds, dir?)               a rotation loop (none with reduced motion)
	    Kit.button(parent, name)                    a transparent TextButton hit area (AutoButtonColor off)
	    Kit.rect(g)                                 a GuiObject's abs rect (Types.Rect)

	Everything is idempotent where it takes a name: a second call reuses the child.
]]

local TweenService = game:GetService("TweenService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Theme = require(Core:WaitForChild("Theme"))
local Motion = require(Core:WaitForChild("Motion"))

type ARect = Types.Rect

local Kit = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
Kit.WHITE, Kit.BLACK = WHITE, BLACK

local function child<T>(parent: Instance, name: string, class: string): T
	local c = parent:FindFirstChild(name)
	if c and c.ClassName == class then return (c :: any) :: T end
	if c then c:Destroy() end
	local n = Instance.new(class :: any)
	n.Name = name
	n.Parent = parent
	return (n :: any) :: T
end
Kit.child = child

function Kit.frame(parent: Instance, name: string, z: number?): Frame
	local f = child(parent, name, "Frame") :: Frame
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	if z then f.ZIndex = z end
	return f
end

function Kit.label(parent: Instance, name: string, role: string, text: string?, color: Color3?): TextLabel
	local l = child(parent, name, "TextLabel") :: TextLabel
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Active = false
	Theme.text(l, role)
	l.TextColor3 = color or Theme.C.text
	if text ~= nil then l.Text = text end
	return l
end

function Kit.corner(f: GuiObject, r: UDim?): UICorner
	local c = child(f, "Corner", "UICorner") :: UICorner
	c.CornerRadius = r or UDim.new(0.5, 0)
	return c
end

function Kit.stroke(f: GuiObject, px: number, color: Color3, a: number?, name: string?): UIStroke
	local s = child(f, name or "Stroke", "UIStroke") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = px
	s.Color = color
	s.Transparency = 1 - (if a ~= nil then a else 1)
	s.LineJoinMode = Enum.LineJoinMode.Round
	return s
end

-- a black outline on text (UIStroke Contextual): the display and thin-label strokes of DESIGN.md 9.2
function Kit.textStroke(l: GuiObject, px: number, a: number?): UIStroke?
	if px <= 0 then
		local old = l:FindFirstChild("TextStroke")
		if old then old:Destroy() end
		return nil
	end
	local s = child(l, "TextStroke", "UIStroke") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Color = BLACK
	s.Thickness = px
	s.Transparency = 1 - (if a ~= nil then a else 1)
	return s
end

-- colors: 1+ colours spread evenly (at: their positions instead); alphas: opacity keypoints { {t, a} }
function Kit.grad(f: Instance, colors: { Color3 }, rot: number?, alphas: { { number } }?, name: string?, at: { number }?): UIGradient
	local g = child(f, name or "Grad", "UIGradient") :: UIGradient
	g.Rotation = rot or 90
	local keys = {}
	local n = #colors
	for i, c in colors do
		local t = if at then at[i] else if n == 1 then 0 else (i - 1) / (n - 1)
		table.insert(keys, ColorSequenceKeypoint.new(t, c))
	end
	if #keys == 1 then table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value)) end
	g.Color = ColorSequence.new(keys)
	if alphas then
		local tk = {}
		for _, p in alphas do table.insert(tk, NumberSequenceKeypoint.new(p[1], 1 - math.clamp(p[2], 0, 1))) end
		g.Transparency = NumberSequence.new(tk)
	else
		g.Transparency = NumberSequence.new(0)
	end
	return g
end

function Kit.pad(f: GuiObject, t: number, r: number, b: number, l: number): UIPadding
	local p = child(f, "Pad", "UIPadding") :: UIPadding
	p.PaddingTop, p.PaddingRight, p.PaddingBottom, p.PaddingLeft = UDim.new(0, t), UDim.new(0, r), UDim.new(0, b), UDim.new(0, l)
	return p
end

function Kit.list(f: GuiObject, dir: string, gap: number, h: Enum.HorizontalAlignment?, v: Enum.VerticalAlignment?): UIListLayout
	local l = child(f, "List", "UIListLayout") :: UIListLayout
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if dir == "x" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap)
	l.HorizontalAlignment = h or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = v or Enum.VerticalAlignment.Top
	return l
end

-- ------------------------------------------------------------------------------------------------------ glows
-- a soft round glow filling `parent` child `name` (size and place it). The fade ends at .7 (see the header).
function Kit.blob(parent: Instance, name: string, color: Color3, alpha: number, z: number?): Frame?
	if not Theme.caps.Radial then
		local old = parent:FindFirstChild(name)
		if old then old:Destroy() end
		return nil
	end
	local f = Kit.frame(parent, name, z)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	local g = child(f, "Radial", "UIGradient") :: UIGradient
	g.Type = Enum.GradientType.Radial
	g.Color = ColorSequence.new(color)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - alpha),
		NumberSequenceKeypoint.new(0.3, 1 - alpha * 0.55),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	Kit.corner(f)
	return f
end

-- a glow around a pill or card: UIShadow where the engine has it, else two soft rims
function Kit.halo(target: GuiObject, color: Color3, alpha: number, blur: number)
	if Theme.caps.UIShadow then
		local ok = pcall(function()
			local s = child(target, "Halo", "UIShadow") :: UIShadow
			s.Color = color
			s.Transparency = 1 - alpha
			s.BlurRadius = UDim.new(0, blur)
			s.Offset = UDim2.new()
		end)
		if ok then return end
	end
	local parent = target.Parent
	if parent == nil then return end
	local pc = target:FindFirstChildWhichIsA("UICorner")
	for i, k in { 0.5, 1 } do
		local name = target.Name .. "_Halo" .. i
		local f = Kit.frame(parent, name)
		local d = math.floor(blur * k + 0.5)
		f.AnchorPoint = target.AnchorPoint
		f.Position = target.Position + UDim2.fromOffset((2 * target.AnchorPoint.X - 1) * d, (2 * target.AnchorPoint.Y - 1) * d)
		f.Size = target.Size + UDim2.fromOffset(2 * d, 2 * d)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 1 - alpha * (if i == 1 then 0.28 else 0.14)
		f.ZIndex = math.max(0, target.ZIndex - 1)
		f.Visible = target.Visible
		local c = Kit.corner(f, if pc then pc.CornerRadius else UDim.new(0, 12))
		if pc and pc.CornerRadius.Scale == 0 then c.CornerRadius = UDim.new(0, pc.CornerRadius.Offset + d) end
	end
end

-- the gem fill: lift(c,.55) at the centre, c, shade(c,.28) at the rim; the ramp ends at .7 (the inscribed circle)
function Kit.gem(f: GuiObject, c: Color3, o: { hi: number?, lo: number?, flat: boolean? }?)
	local hi = (o and o.hi) or 0.55
	local lo = (o and o.lo) or 0.28
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	Kit.corner(f)
	local g = child(f, "Gem", "UIGradient") :: UIGradient
	g.Transparency = NumberSequence.new(0)
	if Theme.caps.Radial and not (o and o.flat) then
		g.Type = Enum.GradientType.Radial
		g.Rotation = 0
		g.Offset = Vector2.new(-0.08, -0.12)
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.lift(c, hi)),
			ColorSequenceKeypoint.new(0.36, c),
			ColorSequenceKeypoint.new(0.7, Theme.shade(c, lo)),
			ColorSequenceKeypoint.new(1, Theme.shade(c, lo)),
		})
	else
		g.Type = Enum.GradientType.Linear
		g.Rotation = 90
		g.Offset = Vector2.zero
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.lift(c, hi * 0.8)),
			ColorSequenceKeypoint.new(0.5, c),
			ColorSequenceKeypoint.new(1, Theme.shade(c, lo)),
		})
	end
end

-- ------------------------------------------------------------------------------------------------------ glyphs
-- one bar from a to b (scale units of a square holder), thickness th (scale), rounded ends
local function bar(h: Frame, name: string, ax: number, ay: number, bx: number, by: number, th: number, color: Color3, round: boolean?): Frame
	local f = child(h, name, "Frame") :: Frame
	f.BorderSizePixel = 0
	f.Active = false
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)
	f.Position = UDim2.fromScale((ax + bx) / 2, (ay + by) / 2)
	f.Size = UDim2.fromScale(len + (if round then th else 0), th)
	f.Rotation = math.deg(math.atan2(dy, dx))
	if round ~= false then Kit.corner(f) end
	return f
end
local function disc(h: Frame, name: string, cx: number, cy: number, d: number, color: Color3): Frame
	local f = child(h, name, "Frame") :: Frame
	f.BorderSizePixel = 0
	f.Active = false
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx, cy)
	f.Size = UDim2.fromScale(d, d)
	Kit.corner(f)
	return f
end
local function box(h: Frame, name: string, cx: number, cy: number, w: number, hh: number, color: Color3, r: number?, rot: number?): Frame
	local f = child(h, name, "Frame") :: Frame
	f.BorderSizePixel = 0
	f.Active = false
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx, cy)
	f.Size = UDim2.fromScale(w, hh)
	f.Rotation = rot or 0
	if r then Kit.corner(f, UDim.new(r, 0)) end
	return f
end
-- a ring whose stroke follows the holder's size (thickness = k x the holder's width)
local function ring(h: Frame, name: string, cx: number, cy: number, w: number, hh: number, k: number, color: Color3): Frame
	local f = child(h, name, "Frame") :: Frame
	f.BorderSizePixel = 0
	f.Active = false
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx, cy)
	f.Size = UDim2.fromScale(w, hh)
	Kit.corner(f)
	local s = child(f, "Line", "UIStroke") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Transparency = 0
	local function fit()
		s.Thickness = math.max(1, h.AbsoluteSize.X * k)
	end
	fit()
	h:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	return f
end

export type GlyphKind = string
local DRAW: { [string]: (h: Frame, c: Color3, bg: Color3) -> () } = {
	bolt = function(h, c)
		bar(h, "A", 0.66, 0.06, 0.34, 0.52, 0.17, c, false)
		bar(h, "B", 0.3, 0.52, 0.7, 0.48, 0.17, c, false)
		bar(h, "C", 0.66, 0.48, 0.34, 0.94, 0.17, c, false)
	end,
	bang = function(h, c)
		bar(h, "A", 0.5, 0.16, 0.5, 0.56, 0.2, c, true)
		disc(h, "B", 0.5, 0.8, 0.2, c)
	end,
	lock = function(h, c)
		ring(h, "Shackle", 0.5, 0.36, 0.46, 0.5, 0.1, c)
		box(h, "Body", 0.5, 0.68, 0.72, 0.5, c, 0.18)
		disc(h, "Hole", 0.5, 0.66, 0.14, Theme.shade(c, 0.35))
	end,
	moon = function(h, c, bg)
		disc(h, "A", 0.5, 0.5, 0.8, c)
		disc(h, "B", 0.66, 0.36, 0.66, bg)
	end,
	star = function(h, c)
		box(h, "A", 0.5, 0.5, 0.56, 0.56, c, 0.08, 0)
		box(h, "B", 0.5, 0.5, 0.56, 0.56, c, 0.08, 45)
		disc(h, "C", 0.5, 0.5, 0.5, c)
	end,
	home = function(h, c, bg)
		box(h, "Roof", 0.5, 0.44, 0.5, 0.5, c, 0.1, 45)
		box(h, "Body", 0.5, 0.66, 0.56, 0.4, c, 0.08)
		box(h, "Door", 0.5, 0.74, 0.16, 0.24, bg, 0.2)
	end,
	gear = function(h, c, bg)
		for i = 0, 7 do
			local a = i * math.pi / 4
			box(h, "T" .. i, 0.5 + 0.34 * math.cos(a), 0.5 + 0.34 * math.sin(a), 0.2, 0.2, c, 0.2, math.deg(a))
		end
		disc(h, "Body", 0.5, 0.5, 0.66, c)
		disc(h, "Hole", 0.5, 0.5, 0.26, bg)
	end,
	plus = function(h, c)
		bar(h, "A", 0.2, 0.5, 0.8, 0.5, 0.16, c, true)
		bar(h, "B", 0.5, 0.2, 0.5, 0.8, 0.16, c, true)
	end,
	minus = function(h, c)
		bar(h, "A", 0.2, 0.5, 0.8, 0.5, 0.16, c, true)
	end,
	x = function(h, c)
		bar(h, "A", 0.24, 0.24, 0.76, 0.76, 0.14, c, true)
		bar(h, "B", 0.76, 0.24, 0.24, 0.76, 0.14, c, true)
	end,
	check = function(h, c)
		bar(h, "A", 0.18, 0.52, 0.4, 0.74, 0.15, c, true)
		bar(h, "B", 0.4, 0.74, 0.82, 0.28, 0.15, c, true)
	end,
	up = function(h, c)
		bar(h, "A", 0.5, 0.2, 0.5, 0.84, 0.16, c, true)
		bar(h, "B", 0.5, 0.18, 0.22, 0.46, 0.16, c, true)
		bar(h, "C", 0.5, 0.18, 0.78, 0.46, 0.16, c, true)
	end,
	down = function(h, c)
		bar(h, "A", 0.5, 0.16, 0.5, 0.8, 0.16, c, true)
		bar(h, "B", 0.5, 0.82, 0.22, 0.54, 0.16, c, true)
		bar(h, "C", 0.5, 0.82, 0.78, 0.54, 0.16, c, true)
	end,
	chev = function(h, c)
		bar(h, "A", 0.36, 0.2, 0.66, 0.5, 0.15, c, true)
		bar(h, "B", 0.66, 0.5, 0.36, 0.8, 0.15, c, true)
	end,
	swirl = function(h, c)
		ring(h, "Outer", 0.5, 0.5, 0.84, 0.84, 0.09, c)
		ring(h, "Inner", 0.56, 0.5, 0.44, 0.44, 0.09, c)
		disc(h, "Dot", 0.6, 0.5, 0.16, c)
	end,
	bell = function(h, c)
		box(h, "Body", 0.5, 0.5, 0.56, 0.5, c, 0.4)
		box(h, "Rim", 0.5, 0.7, 0.8, 0.12, c, 0.5)
		disc(h, "Clapper", 0.5, 0.84, 0.18, c)
	end,
	warn = function(h, c)
		ring(h, "Ring", 0.5, 0.5, 0.86, 0.86, 0.09, c)
		bar(h, "A", 0.5, 0.26, 0.5, 0.56, 0.13, c, true)
		disc(h, "B", 0.5, 0.74, 0.14, c)
	end,
	clock = function(h, c)
		ring(h, "Ring", 0.5, 0.5, 0.84, 0.84, 0.09, c)
		bar(h, "A", 0.5, 0.5, 0.5, 0.24, 0.1, c, true)
		bar(h, "B", 0.5, 0.5, 0.7, 0.58, 0.1, c, true)
	end,
	save = function(h, c, bg)
		box(h, "Body", 0.5, 0.5, 0.72, 0.72, c, 0.12)
		box(h, "Label", 0.5, 0.64, 0.44, 0.28, bg, 0.1)
		box(h, "Shutter", 0.5, 0.26, 0.36, 0.14, bg, 0.2)
	end,
	ring = function(h, c)
		ring(h, "Ring", 0.5, 0.5, 0.8, 0.8, 0.12, c)
	end,
	info = function(h, c)
		ring(h, "Ring", 0.5, 0.5, 0.86, 0.86, 0.09, c)
		disc(h, "Dot", 0.5, 0.3, 0.14, c)
		bar(h, "Bar", 0.5, 0.46, 0.5, 0.74, 0.13, c, true)
	end,
}
Kit.GLYPHS = DRAW

-- an icon in a square holder named `name` (size and place the holder). bg: the colour of the surface under it (for
-- the cut-outs of moon, gear, home, lock).
function Kit.glyph(parent: Instance, name: string, kind: string, color: Color3, bg: Color3?): Frame
	local h = Kit.frame(parent, name)
	local key = kind .. "|" .. Theme.toHex(color) .. "|" .. (if bg then Theme.toHex(bg) else "")
	if h:GetAttribute("Glyph") == key then return h end
	for _, c in h:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	h:SetAttribute("Glyph", key)
	local draw = DRAW[kind] or DRAW.ring
	draw(h, color, bg or Theme.C.deep)
	return h
end

-- ------------------------------------------------------------------------------------------------------ motion
local spins: { [Instance]: Tween } = setmetatable({}, { __mode = "k" }) :: any
-- rotate `inst` one turn every `seconds` (dir -1 counter-clockwise); off with reduced motion
function Kit.spin(inst: GuiObject | UIGradient, seconds: number, dir: number?)
	local old = spins[inst]
	if old then
		old:Cancel()
		spins[inst] = nil
	end
	if Motion.reduced() or Motion.snapshot() then return end
	local d = dir or 1
	local obj = inst :: any
	obj.Rotation = 0
	local tw = TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 * d })
	spins[inst] = tw
	tw:Play()
end
function Kit.unspin(inst: Instance)
	local old = spins[inst]
	if old then
		old:Cancel()
		spins[inst] = nil
	end
end
-- a back-and-forth loop on one property (a breathing aura, a bobbing chip); off with reduced motion
local loops: { [Instance]: Tween } = setmetatable({}, { __mode = "k" }) :: any
function Kit.breathe(inst: Instance, prop: string, from: any, to: any, seconds: number)
	local old = loops[inst]
	if old then
		old:Cancel()
		loops[inst] = nil
	end
	local obj = inst :: any
	if Motion.reduced() or Motion.snapshot() then
		obj[prop] = from
		return
	end
	obj[prop] = from
	local tw = TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { [prop] = to })
	loops[inst] = tw
	tw:Play()
end
function Kit.still(inst: Instance)
	local old = loops[inst]
	if old then
		old:Cancel()
		loops[inst] = nil
	end
end

-- ------------------------------------------------------------------------------------------------------ misc
function Kit.button(parent: Instance, name: string): TextButton
	local b = child(parent, name, "TextButton") :: TextButton
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = ""
	b.Active = true
	b.Selectable = true
	return b
end

function Kit.rect(g: GuiObject): ARect
	local p, s = g.AbsolutePosition, g.AbsoluteSize
	return { x = p.X, y = p.Y, w = s.X, h = s.Y }
end

-- a button with a word (DESIGN.md 9.8: one line, >= 12 du side padding). style: "primary" (the hue, a darker gradient
-- so white passes 3:1), "gold" (dark ink), "danger", "quiet" (dark glass with a rim)
function Kit.action(parent: Instance, name: string, text: string, o: { style: string?, hue: Color3?, h: number?, role: string?,
	w: number? }): (TextButton, TextLabel)
	local b = Kit.button(parent, name)
	local h = o.h or 52
	b.Size = if o.w then UDim2.fromOffset(o.w, h) else UDim2.fromOffset(0, h)
	b.AutomaticSize = if o.w then Enum.AutomaticSize.None else Enum.AutomaticSize.X
	b.BackgroundTransparency = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	Kit.corner(b, UDim.new(0, 12))
	Kit.pad(b, 0, 16, 0, 16)
	local style = o.style or "quiet"
	local hue = o.hue or Theme.C.system
	local fg = WHITE
	if style == "primary" then
		Kit.grad(b, { Theme.lift(hue, 0.08), Theme.shade(hue, 0.62) }, 90, nil, "Back")
		Kit.stroke(b, 2, Theme.lift(hue, 0.4), 1, "Rim")
	elseif style == "gold" then
		Kit.grad(b, { Color3.fromHex("b37400"), Color3.fromHex("6b4500") }, 90, nil, "Back")
		Kit.stroke(b, 2, Color3.fromHex("ffd34d"), 1, "Rim")
	elseif style == "danger" then
		Kit.grad(b, { Theme.shade(Theme.C.danger, 0.75), Theme.shade(Theme.C.danger, 0.42) }, 90, nil, "Back")
		Kit.stroke(b, 2, Theme.lift(Theme.C.danger, 0.3), 1, "Rim")
	else
		Kit.grad(b, { Theme.C.panel3, Theme.C.panel2 }, 90, nil, "Back")
		Kit.stroke(b, 1.5, Theme.C.strokeHi, 1, "Rim")
	end
	local row = Kit.frame(b, "Content")
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromScale(if o.w then 1 else 0, 1)
	Kit.list(row, "x", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local l = Kit.label(row, "Label", o.role or "tab", text, fg)
	l.LayoutOrder = 2
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromScale(0, 1)
	Kit.textStroke(l, if style == "quiet" then 0 else 1.5, 0.8)
	local over = child(l, "Overhang", "UIPadding") :: UIPadding
	over.PaddingRight = UDim.new(0, 3)
	return b, l
end

-- a chip: a rounded frame with a label, AutomaticSize X (height h, side padding pad)
function Kit.chip(parent: Instance, name: string, role: string, text: string, o: { h: number, pad: number?, fg: Color3?, bg: Color3?,
	bgA: number?, line: Color3?, lineA: number? }): (Frame, TextLabel)
	local f = Kit.frame(parent, name)
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, o.h)
	f.BackgroundColor3 = o.bg or Theme.C.deep
	f.BackgroundTransparency = 1 - (if o.bgA ~= nil then o.bgA else 1)
	-- Sleek: square chips with a 1 du hairline
	local oc = f:FindFirstChild("Corner")
	if oc then oc:Destroy() end
	local pad = o.pad or 10
	Kit.pad(f, 0, pad, 0, pad)
	if o.line then
		Kit.stroke(f, 1, o.line, o.lineA).LineJoinMode = Enum.LineJoinMode.Miter
	else
		local s = f:FindFirstChild("Stroke")
		if s then s:Destroy() end
	end
	local l = Kit.label(f, "Label", role, text, o.fg)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromScale(0, 1)
	return f, l
end

return Kit
