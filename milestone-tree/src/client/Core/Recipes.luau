--!strict
--[[
	Recipes: the construction recipes R1-R14 of DESIGN.md 13.2. Every builder is idempotent (children are
	get-or-create by name and every property it owns is written on each call), and every one reads Theme.caps and
	falls back when an engine feature is missing (UIShadow, Radial / Conical gradients, TileMode, Path2D) or a sprite
	is not uploaded (Sprites).

	    R1 bevel   R2 glow   R3 title   R4 number   R5 shine   R6 ring   R7 radial
	    R8 dashed  R9 tile   R10 glass  R11 curve   R12 glitch R13 hold  R14 scrim

	Text recipes (R3, R4, R12) keep the text on the label itself (transparent, so its TextBounds and AutomaticSize
	still work) and draw it with child labels: a hard shadow, then the fill with its gradient and stroke. Children
	draw above their parent, so this is how a shadow can sit behind the text. Set the text through the recipe (or the
	label's Text: the children follow it).
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Sprites = require(script.Parent:WaitForChild("Sprites"))
local Layout = require(script.Parent:WaitForChild("Layout"))

type Handle = Types.Handle
type ARect = Types.Rect

local Recipes = {}

-- set by App: false while the map is gliding or pinching (DESIGN.md 3.4 hold safety)
Recipes.holdGate = nil :: (() -> boolean)?

local child = Sprites.child
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function remove(parent: Instance, name: string)
	local c = parent:FindFirstChild(name)
	if c then c:Destroy() end
end
local function corner(f: GuiObject, r: UDim)
	local c = child(f, "Corner", "UICorner") :: UICorner
	c.CornerRadius = r
end
local function seq3(a: Color3, b: Color3, c: Color3): ColorSequence
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(0.5, b), ColorSequenceKeypoint.new(1, c) })
end
local function seq2(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) })
end
local function nseq(points: { { number } }): NumberSequence
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], math.clamp(p[2], 0, 1))) end
	return NumberSequence.new(k)
end

-- one connection per (object, purpose), replaced on each call
local conns: { [Instance]: { [string]: RBXScriptConnection } } = setmetatable({}, { __mode = "k" }) :: any
local function hook(inst: Instance, purpose: string, c: RBXScriptConnection)
	local t = conns[inst]
	if t == nil then
		t = {}
		conns[inst] = t
	end
	local tt = t :: { [string]: RBXScriptConnection }
	local old = tt[purpose]
	if old then old:Disconnect() end
	tt[purpose] = c
end

-- ------------------------------------------------------------------------------------------------------ R1 bevel
export type BevelOpts = { radius: number, top: Color3, mid: Color3, bottom: Color3, stroke: number?, strokeFrom: Color3?,
	strokeTo: Color3?, sprite: string? }
function Recipes.bevel(f: GuiObject, o: BevelOpts)
	corner(f, UDim.new(0, o.radius))
	f.BackgroundColor3 = WHITE
	if f.BackgroundTransparency >= 1 then f.BackgroundTransparency = 0 end
	f.BorderSizePixel = 0
	local g = child(f, "Fill", "UIGradient") :: UIGradient
	g.Rotation = 90
	g.Color = seq3(o.top, o.mid, o.bottom)
	if o.stroke and o.stroke > 0 then
		local s = child(f, "Rim", "UIStroke") :: UIStroke
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = o.stroke
		s.Color = WHITE
		s.Transparency = 0
		local sg = child(s, "RimGradient", "UIGradient") :: UIGradient
		sg.Rotation = 90
		sg.Color = seq2(o.strokeFrom or Theme.lift(o.mid, 0.3), o.strokeTo or Theme.shade(o.mid, 0.6))
	else
		remove(f, "Rim")
	end
	-- the bevel lips: a 9-slice overlay (atlas) or the gradient overlay fallback
	local name = if o.sprite == "button" then "bevel_button" else "bevel_card"
	local lip = Sprites.image(name, f, { key = "Bevel" })
	lip.Size = UDim2.fromScale(1, 1)
	lip.Position = UDim2.fromScale(0, 0)
	lip.ZIndex = 8
	Sprites.slice(name, lip, 0.5 * o.radius / 16)
end

-- ------------------------------------------------------------------------------------------------------ R2 glow
export type GlowOpts = { color: Color3, alpha: number, blur: number?, spread: number?, shape: string? }
function Recipes.glow(target: GuiObject, o: GlowOpts): Instance?
	local blur = o.blur or 16
	local spread = o.spread or 0
	local key = target.Name .. "_Glow"
	if Theme.caps.UIShadow then
		local parent = target.Parent
		if parent then remove(parent, key) end
		local s = child(target, "Glow", "UIShadow") :: UIShadow
		s.Color = o.color
		s.Transparency = 1 - o.alpha
		s.BlurRadius = UDim.new(0, blur)
		s.Spread = UDim2.fromOffset(spread, spread)
		s.Offset = UDim2.new()
		return s
	end
	remove(target, "Glow")
	local parent = target.Parent
	if parent == nil then return nil end
	if not Theme.caps.Radial and not Sprites.has("glow_rr") then
		remove(parent, key)
		return nil
	end
	local shape = if o.shape == "circle" then "glow_circle" else "glow_rr"
	local l = Sprites.image(shape, parent, { tint = o.color, alpha = o.alpha, key = key })
	local function sync()
		local a = target.AnchorPoint
		local pad = blur + spread
		l.AnchorPoint = a
		l.Position = target.Position + UDim2.fromOffset((2 * a.X - 1) * pad, (2 * a.Y - 1) * pad)
		l.Size = target.Size + UDim2.fromOffset(2 * pad, 2 * pad)
		l.Visible = target.Visible
		l.ZIndex = math.max(0, target.ZIndex - 1)
		l.LayoutOrder = target.LayoutOrder
	end
	sync()
	Sprites.slice(shape, l, blur / 16)
	hook(target, "glowPos", target:GetPropertyChangedSignal("Position"):Connect(sync))
	hook(target, "glowSize", target:GetPropertyChangedSignal("Size"):Connect(sync))
	hook(target, "glowVis", target:GetPropertyChangedSignal("Visible"):Connect(sync))
	hook(target, "glowGone", target.Destroying:Connect(function() l:Destroy() end))
	return l
end

-- ------------------------------------------------------------------------------------------------------ R3 / R4 text
local TEXT_PROPS = { "TextXAlignment", "TextYAlignment", "TextWrapped", "RichText", "TextTruncate", "LineHeight" }
local function textChild(l: TextLabel, name: string, z: number): TextLabel
	local c = child(l, name, "TextLabel") :: TextLabel
	c.BackgroundTransparency = 1
	c.BorderSizePixel = 0
	c.Size = UDim2.fromScale(1, 1)
	c.ZIndex = z
	c.Active = false
	c.Text = l.Text
	c.FontFace = l.FontFace
	c.TextSize = l.TextSize
	for _, p in TEXT_PROPS do
		pcall(function() (c :: any)[p] = (l :: any)[p] end)
	end
	return c
end
local function follow(l: TextLabel, names: { string })
	local function copy()
		for _, n in names do
			local c = l:FindFirstChild(n)
			if c and c:IsA("TextLabel") then
				c.Text = l.Text
				c.TextSize = l.TextSize
				c.FontFace = l.FontFace
			end
		end
	end
	hook(l, "textFollow", l:GetPropertyChangedSignal("Text"):Connect(copy))
	hook(l, "sizeFollow", l:GetPropertyChangedSignal("TextSize"):Connect(copy))
end
local function italicPad(c: TextLabel, italic: boolean)
	if italic then
		local p = child(c, "Overhang", "UIPadding") :: UIPadding
		p.PaddingRight = UDim.new(0, 4)
	else
		remove(c, "Overhang")
	end
end
local function strokeOn(c: TextLabel, thickness: number)
	if thickness > 0 then
		local s = child(c, "Stroke", "UIStroke") :: UIStroke
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Color = BLACK
		s.Thickness = thickness
		s.Transparency = 0
	else
		remove(c, "Stroke")
	end
end

export type TitleOpts = { text: string, role: string, from: Color3?, to: Color3?, stroke: number, shadow: number, size: number? }
-- R3: white (or gradient) heavy text, black contextual stroke, hard shadow clone
function Recipes.title(l: TextLabel, o: TitleOpts)
	local r = Theme.ROLES[o.role]
	l.FontFace = Theme.font(o.role)
	l.TextSize = o.size or Theme.size(o.role)
	l.Text = o.text
	l.TextTransparency = 1
	l.BackgroundTransparency = 1
	l.TextStrokeTransparency = 1
	local italic = r ~= nil and r.italic
	local shadow = textChild(l, "Shadow", 1)
	shadow.Position = UDim2.fromOffset(0, o.shadow)
	shadow.TextColor3 = BLACK
	shadow.TextTransparency = if o.shadow > 0 then 0.25 else 1
	italicPad(shadow, italic)
	strokeOn(shadow, if o.shadow > 0 then o.stroke else 0)
	local fill = textChild(l, "Fill", 2)
	fill.Position = UDim2.new()
	fill.TextColor3 = WHITE
	fill.TextTransparency = 0
	italicPad(fill, italic)
	strokeOn(fill, o.stroke)
	if o.from or o.to then
		local g = child(fill, "Grad", "UIGradient") :: UIGradient
		g.Rotation = 90
		g.Color = seq2(o.from or WHITE, o.to or WHITE)
	else
		remove(fill, "Grad")
	end
	follow(l, { "Shadow", "Fill" })
end

export type NumberOpts = { text: string, size: number, from: Color3, mid: Color3?, to: Color3, stroke: number, shadow: number,
	glow: Color3?, role: string? }
-- R4: Sarpanch Heavy with a gradient, stroke and shadow; the glow is a soft blob behind the text bounds (never
-- UIShadow on text)
function Recipes.number(l: TextLabel, o: NumberOpts)
	l.FontFace = Theme.font(o.role or "hero")
	l.TextSize = o.size
	l.Text = o.text
	l.TextTransparency = 1
	l.BackgroundTransparency = 1
	local shadow = textChild(l, "Shadow", 1)
	shadow.Position = UDim2.fromOffset(0, o.shadow)
	shadow.TextColor3 = BLACK
	shadow.TextTransparency = if o.shadow > 0 then 0.2 else 1
	strokeOn(shadow, if o.shadow > 0 then o.stroke else 0)
	local fill = textChild(l, "Fill", 2)
	fill.Position = UDim2.new()
	fill.TextColor3 = WHITE
	fill.TextTransparency = 0
	strokeOn(fill, o.stroke)
	local g = child(fill, "Grad", "UIGradient") :: UIGradient
	g.Rotation = 90
	g.Color = if o.mid then seq3(o.from, o.mid, o.to) else seq2(o.from, o.to)
	follow(l, { "Shadow", "Fill" })
	if o.glow then
		local b = math.max(8, o.size * 0.35)
		local glow = Sprites.image("glow_rr", l, { tint = o.glow, alpha = 0.45, key = "Glow" })
		glow.ZIndex = 0
		local function place()
			local tb = l.TextBounds
			local xa = l.TextXAlignment
			local ax = if xa == Enum.TextXAlignment.Left then 0 elseif xa == Enum.TextXAlignment.Right then 1 else 0.5
			glow.AnchorPoint = Vector2.new(ax, 0.5)
			glow.Position = UDim2.new(ax, (2 * ax - 1) * b, 0.5, 0)
			glow.Size = UDim2.fromOffset(tb.X + 2 * b, tb.Y + 2 * b)
		end
		place()
		Sprites.slice("glow_rr", glow, b / 16)
		hook(l, "glowBounds", l:GetPropertyChangedSignal("TextBounds"):Connect(place))
	else
		remove(l, "Glow")
	end
end

-- ------------------------------------------------------------------------------------------------------ R5 shine
-- a soft white band sweeping across the object every `every` seconds (none with reduced motion)
function Recipes.shine(f: GuiObject, o: { every: number?, dur: number? }?): Handle
	local every = (o and o.every) or 2.8
	local dur = (o and o.dur) or 0.9
	local band = child(f, "Shine", "Frame") :: Frame
	band.Size = UDim2.fromScale(1, 1)
	band.BackgroundColor3 = WHITE
	band.BackgroundTransparency = 0
	band.BorderSizePixel = 0
	band.ZIndex = 9
	band.Active = false
	local pc = f:FindFirstChildWhichIsA("UICorner")
	local bc = child(band, "Corner", "UICorner") :: UICorner
	bc.CornerRadius = if pc then pc.CornerRadius else UDim.new(0, 0)
	local g = child(band, "Sweep", "UIGradient") :: UIGradient
	g.Rotation = 105
	g.Transparency = nseq({ { 0, 1 }, { 0.5, 0.72 }, { 1, 1 } })
	g.Offset = Vector2.new(-1, 0)
	local alive = true
	local h = {} :: Handle
	function h.stop(_: Handle)
		alive = false
		g.Offset = Vector2.new(-1, 0)
	end
	task.spawn(function()
		task.wait(math.random() * every)
		while alive and band.Parent ~= nil do
			if not Motion.reduced() and f.Visible then
				g.Offset = Vector2.new(-1, 0)
				Motion.tween(g, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) })
			end
			task.wait(every)
		end
	end)
	return h
end

-- ------------------------------------------------------------------------------------------------------ R6 ring
export type Ring = { frame: Frame, set: (self: Ring, p: number) -> (), setColor: (self: Ring, c: Color3) -> (), destroy: (self: Ring) -> () }
local SEGMENTS = 24
-- a progress ring: a stroked circle whose Conical gradient hides the part past p; without Conical, 24 dots
function Recipes.ring(parent: GuiObject, o: { size: number, thick: number, color: Color3, track: number? }): Ring
	local f = child(parent, "Ring", "Frame") :: Frame
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(o.size, o.size)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	f.ZIndex = 6
	corner(f, UDim.new(0.5, 0))
	local ring = {} :: Ring
	ring.frame = f
	local p = 0
	if Theme.caps.Conical then
		remove(f, "Dots")
		local track = child(f, "Track", "UIStroke") :: UIStroke
		track.Thickness = o.thick
		track.Color = o.color
		track.Transparency = o.track or 0.82
		track.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local arcFrame = child(f, "Arc", "Frame") :: Frame
		arcFrame.Size = UDim2.fromScale(1, 1)
		arcFrame.BackgroundTransparency = 1
		arcFrame.Active = false
		local ac = child(arcFrame, "Corner", "UICorner") :: UICorner
		ac.CornerRadius = UDim.new(0.5, 0)
		local arc = child(arcFrame, "Stroke", "UIStroke") :: UIStroke
		arc.Thickness = o.thick
		arc.Color = o.color
		arc.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local g = child(arc, "Sweep", "UIGradient") :: UIGradient
		g.Type = Enum.GradientType.Conical
		local function draw()
			if p <= 0.001 then
				arc.Transparency = 1
			elseif p >= 0.999 then
				arc.Transparency = 0
				g.Transparency = NumberSequence.new(0)
			else
				arc.Transparency = 0
				g.Transparency = nseq({ { 0, 0 }, { p, 0 }, { math.min(0.999, p + 0.001), 1 }, { 1, 1 } })
			end
		end
		function ring.set(_: Ring, v: number)
			p = math.clamp(v, 0, 1)
			draw()
		end
		function ring.setColor(_: Ring, c: Color3)
			track.Color = c
			arc.Color = c
		end
		draw()
	else
		remove(f, "Track")
		remove(f, "Arc")
		local holder = child(f, "Dots", "Frame") :: Frame
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.Active = false
		local dots: { Frame } = {}
		local d = math.max(3, o.thick * 1.4)
		for i = 1, SEGMENTS do
			local a = (i - 0.5) / SEGMENTS * 2 * math.pi
			local dot = child(holder, "Dot" .. i, "Frame") :: Frame
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromScale(0.5 + 0.5 * math.sin(a), 0.5 - 0.5 * math.cos(a))
			dot.Size = UDim2.fromOffset(d, d)
			dot.BackgroundColor3 = o.color
			dot.BorderSizePixel = 0
			dot.Active = false
			local dc = child(dot, "Corner", "UICorner") :: UICorner
			dc.CornerRadius = UDim.new(0.5, 0)
			dots[i] = dot
		end
		local trackA = o.track or 0.82
		local function draw()
			for i, dot in dots do
				dot.BackgroundTransparency = if (i - 0.5) / SEGMENTS <= p then 0 else trackA
			end
		end
		function ring.set(_: Ring, v: number)
			p = math.clamp(v, 0, 1)
			draw()
		end
		function ring.setColor(_: Ring, c: Color3)
			for _, dot in dots do dot.BackgroundColor3 = c end
		end
		draw()
	end
	function ring.destroy(_: Ring)
		f:Destroy()
	end
	return ring
end

-- ------------------------------------------------------------------------------------------------------ R7 radial
export type Stop = { t: number, c: Color3, a: number? }
-- a radial gradient on the frame's background (gem, aura, vignette, glow blob); without Radial, a soft flat disc
function Recipes.radial(f: GuiObject, stops: { Stop })
	local list = table.clone(stops)
	table.sort(list, function(x: Stop, y: Stop) return x.t < y.t end)
	if #list == 0 then list = { { t = 0, c = WHITE, a = 1 } } end
	if list[1].t > 0 then table.insert(list, 1, { t = 0, c = list[1].c, a = list[1].a }) end
	if list[#list].t < 1 then table.insert(list, { t = 1, c = list[#list].c, a = list[#list].a }) end
	f.BorderSizePixel = 0
	if Theme.caps.Radial then
		f.BackgroundColor3 = WHITE
		f.BackgroundTransparency = 0
		local g = child(f, "Radial", "UIGradient") :: UIGradient
		g.Type = Enum.GradientType.Radial
		local ck, tk = {}, {}
		local last = -1
		for _, s in list do
			local t = math.clamp(s.t, 0, 1)
			if t <= last then t = math.min(1, last + 0.0001) end
			if t <= last then continue end
			last = t
			table.insert(ck, ColorSequenceKeypoint.new(t, s.c))
			table.insert(tk, NumberSequenceKeypoint.new(t, 1 - math.clamp(if s.a ~= nil then s.a else 1, 0, 1)))
		end
		if #ck >= 2 then
			g.Color = ColorSequence.new(ck)
			g.Transparency = NumberSequence.new(tk)
		end
	else
		remove(f, "Radial")
		local inner = list[1]
		f.BackgroundColor3 = inner.c
		f.BackgroundTransparency = 1 - math.clamp((if inner.a ~= nil then inner.a else 1) * 0.55, 0, 1)
		corner(f, UDim.new(0.5, 0))
	end
end

-- ------------------------------------------------------------------------------------------------------ R8 dashed
-- a dashed rim on a stroke; without TileMode a solid stroke at alpha .7
function Recipes.dashed(stroke: UIStroke, o: { color: Color3, alpha: number? })
	local alpha = o.alpha or 1
	stroke.Color = o.color
	if Theme.caps.TileMode then
		stroke.Transparency = 1 - alpha
		local g = child(stroke, "Dash", "UIGradient") :: UIGradient
		g.Rotation = 45
		g.TileMode = Enum.GradientTileMode.Repeat
		g.Scale = 0.08
		g.Transparency = nseq({ { 0, 0 }, { 0.62, 0 }, { 0.63, 1 }, { 1, 1 } })
	else
		remove(stroke, "Dash")
		stroke.Transparency = 1 - alpha * 0.7
	end
end

-- ------------------------------------------------------------------------------------------------------ R9 tile
-- a tiled standalone texture (scanlines, stripes, grid, wave); nil (and nothing drawn) when it is not uploaded
function Recipes.tile(parent: GuiObject, texture: string, o: { alpha: number, tile: number?, tileH: number?, color: Color3? }): ImageLabel?
	local key = "Tex_" .. texture
	local id = Sprites.texture(texture)
	if id == nil then
		remove(parent, key)
		return nil
	end
	local l = child(parent, key, "ImageLabel") :: ImageLabel
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Active = false
	l.Image = id
	l.ScaleType = Enum.ScaleType.Tile
	local tw = o.tile or 32
	l.TileSize = UDim2.fromOffset(tw, o.tileH or tw)
	l.ImageTransparency = 1 - o.alpha
	l.ImageColor3 = o.color or WHITE
	return l
end

-- ------------------------------------------------------------------------------------------------------ R10 glass
-- the HUD glass: a dark translucent fill and a faint white rim (Roblox has no backdrop blur)
function Recipes.glass(f: GuiObject)
	local pt = 1
	pcall(function() pt = GuiService.PreferredTransparency end)
	f.BackgroundColor3 = Theme.C.glass
	f.BackgroundTransparency = math.clamp(0.28 * pt, 0, 1)
	f.BorderSizePixel = 0
	local s = child(f, "GlassRim", "UIStroke") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = WHITE
	s.Thickness = 1
	s.Transparency = 0.86
end

-- ------------------------------------------------------------------------------------------------------ R11 curve
export type CurveStroke = { c: Color3, a: number, w: number }
export type Curve = {
	parts: { Instance },
	setWidths: (self: Curve, widths: { number }) -> (),
	setColors: (self: Curve, strokes: { CurveStroke }) -> (),
	setVisible: (self: Curve, v: boolean) -> (),
	destroy: (self: Curve) -> (),
}
-- A glowing curve: one Path2D per stroke (halo, glow, core, hot) through cubic Bezier segments. pts are 4 points per
-- cubic in the parent's space (o.space, default the 3840 x 2560 world), written in Scale units of the parent.
-- Without Path2D: 24 rotated thin frames along the curve, drawn with the brightest stroke.
function Recipes.curve(parent: GuiObject, pts: { Vector2 }, strokes: { CurveStroke }, o: { name: string?, space: Vector2?, z: number? }?): Curve
	local name = (o and o.name) or "Curve"
	local space = (o and o.space) or Vector2.new(3840, 2560)
	local z0 = (o and o.z) or 1
	local function toScale(p: Vector2): UDim2
		return UDim2.fromScale(p.X / space.X, p.Y / space.Y)
	end
	local curve = {} :: Curve
	curve.parts = {}
	if Theme.caps.Path2D then
		remove(parent, name .. "_Seg")
		-- control points: every cubic endpoint once, tangents to its handles
		local cps = {}
		local n = math.floor(#pts / 4)
		for i = 0, n - 1 do
			local p0, p1, p2, p3 = pts[i * 4 + 1], pts[i * 4 + 2], pts[i * 4 + 3], pts[i * 4 + 4]
			if i == 0 then
				table.insert(cps, { pos = p0, left = Vector2.zero, right = p1 - p0 })
			else
				cps[#cps].right = p1 - p0
			end
			table.insert(cps, { pos = p3, left = p2 - p3, right = Vector2.zero })
		end
		local list = {}
		for _, c in cps do
			table.insert(list, Path2DControlPoint.new(toScale(c.pos), toScale(c.left), toScale(c.right)))
		end
		for k, s in strokes do
			local path = child(parent, name .. "_" .. k, "Path2D") :: Path2D
			path:SetControlPoints(list)
			path.Color3 = s.c
			path.Transparency = 1 - s.a
			path.Thickness = s.w
			path.ZIndex = z0 + k - 1
			curve.parts[k] = path
		end
		function curve.setWidths(_: Curve, widths: { number })
			for k, w in widths do
				local p = curve.parts[k]
				if p then (p :: Path2D).Thickness = w end
			end
		end
		function curve.setColors(_: Curve, s2: { CurveStroke })
			for k, s in s2 do
				local p = curve.parts[k]
				if p then
					(p :: Path2D).Color3 = s.c;
					(p :: Path2D).Transparency = 1 - s.a
				end
			end
		end
		function curve.setVisible(_: Curve, v: boolean)
			for _, p in curve.parts do (p :: Path2D).Visible = v end
		end
	else
		-- the brightest stroke, as straight segments
		local best = 1
		for k, s in strokes do
			if s.a > strokes[best].a then best = k end
		end
		local holder = child(parent, name .. "_Seg", "Frame") :: Frame
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.Active = false
		holder.ZIndex = z0
		local samples = {}
		local n = math.floor(#pts / 4)
		local per = math.max(1, math.floor(24 / math.max(1, n)))
		for i = 0, n - 1 do
			local p0, p1, p2, p3 = pts[i * 4 + 1], pts[i * 4 + 2], pts[i * 4 + 3], pts[i * 4 + 4]
			for j = (if i == 0 then 0 else 1), per do
				local t = j / per
				local u = 1 - t
				table.insert(samples, p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t))
			end
		end
		local segs: { Frame } = {}
		for i = 1, #samples - 1 do
			local a, b = samples[i], samples[i + 1]
			local d = b - a
			local seg = child(holder, "S" .. i, "Frame") :: Frame
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Position = toScale((a + b) / 2)
			seg.Size = UDim2.new(d.Magnitude / space.X, 1, 0, strokes[best].w)
			seg.Rotation = math.deg(math.atan2(d.Y, d.X))
			seg.BackgroundColor3 = strokes[best].c
			seg.BackgroundTransparency = 1 - strokes[best].a
			seg.BorderSizePixel = 0
			seg.Active = false
			segs[i] = seg
		end
		curve.parts = { holder }
		function curve.setWidths(_: Curve, widths: { number })
			local w = widths[best]
			if w == nil then return end
			for _, seg in segs do seg.Size = UDim2.new(seg.Size.X.Scale, 1, 0, w) end
		end
		function curve.setColors(_: Curve, s2: { CurveStroke })
			local s = s2[best]
			if s == nil then return end
			for _, seg in segs do
				seg.BackgroundColor3 = s.c
				seg.BackgroundTransparency = 1 - s.a
			end
		end
		function curve.setVisible(_: Curve, v: boolean)
			holder.Visible = v
		end
	end
	function curve.destroy(_: Curve)
		for _, p in curve.parts do p:Destroy() end
		table.clear(curve.parts)
	end
	return curve
end

-- ------------------------------------------------------------------------------------------------------ R12 glitch
-- glitch text: white text over a crimson and a cyan clone; the clones jump for 60-140 ms every min..max seconds
function Recipes.glitch(l: TextLabel, o: { min: number, max: number }): Handle
	l.TextTransparency = 1
	l.BackgroundTransparency = 1
	local a = textChild(l, "GlitchA", 1)
	a.TextColor3 = Color3.fromHex("ff2e63")
	a.TextTransparency = 0.3
	a.Position = UDim2.fromOffset(-2, 0)
	local b = textChild(l, "GlitchB", 2)
	b.TextColor3 = Color3.fromHex("2ee6ff")
	b.TextTransparency = 0.45
	b.Position = UDim2.fromOffset(2, 0)
	local main = textChild(l, "Fill", 3)
	main.TextColor3 = WHITE
	main.TextTransparency = 0
	main.Position = UDim2.new()
	follow(l, { "GlitchA", "GlitchB", "Fill" })
	local alive = true
	local h = {} :: Handle
	function h.stop(_: Handle)
		alive = false
		a.Position = UDim2.fromOffset(-2, 0)
		b.Position = UDim2.fromOffset(2, 0)
	end
	task.spawn(function()
		while alive and l.Parent ~= nil do
			task.wait(o.min + math.random() * math.max(0, o.max - o.min))
			if not alive or not l.Parent then break end
			if Motion.reduced() or not l.Visible then continue end
			local dx = 2 + math.random() * 2
			a.Position = UDim2.fromOffset(-2 - dx, math.random(-1, 1))
			b.Position = UDim2.fromOffset(2 + dx, math.random(-1, 1))
			task.wait(0.06 + math.random() * 0.08)
			a.Position = UDim2.fromOffset(-2, 0)
			b.Position = UDim2.fromOffset(2, 0)
		end
	end)
	return h
end

-- ------------------------------------------------------------------------------------------------------ R13 hold
export type Hold = {
	progress: number,
	holding: boolean,
	consumed: (self: Hold) -> boolean, -- the last press became a hold or moved: the owner skips its Activated
	cancel: (self: Hold) -> (),
	destroy: (self: Hold) -> (),
}
Recipes.HOLD_DELAY = 0.12
Recipes.HOLD_SLOP = 10
-- A hold button (DESIGN.md 3.4): the fill starts after 120 ms with less than 10 pt of movement, never while the map
-- glides or pinches (Recipes.holdGate), cancels on more movement or a scroll, rewinds in 0.12 s when released
-- early, and calls onDone once it is full. The fill is a ring (o.ring) or a bar growing from the left.
function Recipes.hold(b: GuiButton, o: { dur: number, ring: boolean?, onDone: () -> (), label: TextLabel?, color: Color3? }): Hold
	local color = o.color or WHITE
	local ring: Ring? = nil
	local bar: Frame? = nil
	if o.ring then
		local size = math.max(24, math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y))
		ring = Recipes.ring(b, { size = size, thick = math.max(3, size * 0.08), color = color, track = 1 })
		remove(b, "HoldFill")
	else
		remove(b, "Ring")
		local f = child(b, "HoldFill", "Frame") :: Frame
		f.Size = UDim2.fromScale(0, 1)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 0.72
		f.BorderSizePixel = 0
		f.Active = false
		f.ZIndex = 0
		local pc = b:FindFirstChildWhichIsA("UICorner")
		local fc = child(f, "Corner", "UICorner") :: UICorner
		fc.CornerRadius = if pc then pc.CornerRadius else UDim.new(0, 0)
		bar = f
	end
	local hold = {} :: Hold
	hold.progress = 0
	hold.holding = false
	local consumed = false
	local input: InputObject? = nil
	local startPos = Vector2.zero
	local startT = 0
	local scroll: ScrollingFrame? = nil
	local scrollStart = Vector2.zero
	local rewinding = false
	local step: RBXScriptConnection? = nil

	local function draw()
		local p = hold.progress
		if ring then ring:set(p) end
		if bar then bar.Size = UDim2.fromScale(p, 1) end
	end
	local function pointer(): Vector2
		local i = input
		if i and i.UserInputType == Enum.UserInputType.Touch then return Layout.inputToAbs(i.Position) end
		return UserInputService:GetMouseLocation()
	end
	local function stopLoop()
		if step then
			step:Disconnect()
			step = nil
		end
	end
	local function release()
		input = nil
		hold.holding = false
		if hold.progress > 0 then
			rewinding = true
		else
			stopLoop()
		end
	end
	local function loop(dt: number)
		if input == nil then
			if rewinding then
				hold.progress = math.max(0, hold.progress - dt / 0.12)
				draw()
				if hold.progress <= 0 then
					rewinding = false
					stopLoop()
				end
			else
				stopLoop()
			end
			return
		end
		local moved = (pointer() - startPos).Magnitude
		local scrolled = scroll ~= nil and (scroll.CanvasPosition - scrollStart).Magnitude > 2
		if moved > Recipes.HOLD_SLOP or scrolled then
			consumed = true
			release()
			return
		end
		local held = os.clock() - startT
		if held < Recipes.HOLD_DELAY then return end
		hold.holding = true
		consumed = true
		hold.progress = math.min(1, hold.progress + dt / o.dur)
		draw()
		if hold.progress >= 1 then
			input = nil
			hold.holding = false
			hold.progress = 0
			draw()
			stopLoop()
			task.spawn(o.onDone)
		end
	end
	local began = b.InputBegan:Connect(function(io: InputObject)
		local t = io.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		if input ~= nil then return end
		consumed = false
		local gate = Recipes.holdGate
		if gate and not gate() then return end
		input = io
		rewinding = false
		startT = os.clock()
		startPos = pointer()
		local sf = b:FindFirstAncestorWhichIsA("ScrollingFrame")
		scroll = sf
		scrollStart = if sf then sf.CanvasPosition else Vector2.zero
		if step == nil then step = RunService.Heartbeat:Connect(loop) end
	end)
	local ended = UserInputService.InputEnded:Connect(function(io: InputObject)
		if input == nil then return end
		if io == input or (io.UserInputType == Enum.UserInputType.MouseButton1 and (input :: InputObject).UserInputType == Enum.UserInputType.MouseButton1) then
			release()
		end
	end)
	function hold.consumed(_: Hold): boolean
		return consumed
	end
	function hold.cancel(_: Hold)
		release()
	end
	function hold.destroy(_: Hold)
		began:Disconnect()
		ended:Disconnect()
		stopLoop()
		if ring then ring:destroy() end
		if bar then bar:Destroy() end
	end
	draw()
	return hold
end

-- ------------------------------------------------------------------------------------------------------ R14 scrim
export type Scrim = { frame: Frame, setHole: (self: Scrim, hole: ARect?) -> (), destroy: (self: Scrim) -> () }
-- a dark scrim over the parent with a soft round hole over `hole` (abs space); without Radial a plain scrim
function Recipes.scrim(parent: GuiObject, hole: ARect?): Scrim
	local f = child(parent, "Scrim", "Frame") :: Frame
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	local parts: { [string]: Frame } = {}
	for _, n in { "Top", "Bottom", "Left", "Right", "Hole" } do
		local p = child(f, n, "Frame") :: Frame
		p.BackgroundColor3 = BLACK
		p.BackgroundTransparency = 0.38
		p.BorderSizePixel = 0
		p.Active = false
		parts[n] = p
	end
	local scrim = {} :: Scrim
	scrim.frame = f
	function scrim.setHole(_: Scrim, r: ARect?)
		local top, bottom, left, right, h = parts.Top, parts.Bottom, parts.Left, parts.Right, parts.Hole
		if r == nil or not Theme.caps.Radial then
			top.Position = UDim2.new()
			top.Size = UDim2.fromScale(1, 1)
			for _, p in { bottom, left, right, h } do p.Visible = false end
			top.Visible = true
			return
		end
		local rr = r :: ARect
		local c = Layout.absToLocal(parent, Vector2.new(rr.x + rr.w / 2, rr.y + rr.h / 2))
		local k = 1
		local off = parent.Size.X.Offset
		if off > 0 and parent.AbsoluteSize.X > 0 then k = parent.AbsoluteSize.X / off end
		local side = math.max(rr.w, rr.h) * 1.6 / k
		local x0, y0 = c.X - side / 2, c.Y - side / 2
		top.Position = UDim2.new()
		top.Size = UDim2.new(1, 0, 0, math.max(0, y0))
		bottom.Position = UDim2.fromOffset(0, y0 + side)
		bottom.Size = UDim2.new(1, 0, 1, -(y0 + side))
		left.Position = UDim2.fromOffset(0, y0)
		left.Size = UDim2.fromOffset(math.max(0, x0), side)
		right.Position = UDim2.fromOffset(x0 + side, y0)
		right.Size = UDim2.new(1, -(x0 + side), 0, side)
		h.Position = UDim2.fromOffset(x0, y0)
		h.Size = UDim2.fromOffset(side, side)
		h.BackgroundTransparency = 0
		local g = child(h, "Hole", "UIGradient") :: UIGradient
		g.Type = Enum.GradientType.Radial
		g.Color = seq2(BLACK, BLACK)
		g.Transparency = nseq({ { 0, 1 }, { 0.45, 1 }, { 1, 0.38 } })
		for _, p in { top, bottom, left, right, h } do p.Visible = true end
	end
	function scrim.destroy(_: Scrim)
		f:Destroy()
	end
	scrim:setHole(hole)
	return scrim
end

return Recipes
