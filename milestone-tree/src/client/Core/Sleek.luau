--!strict
--[[
	Sleek: the Style 1 "sleek sci-fi" vocabulary (art/ui/clean/styles.js, STYLES[1]) as idempotent builders. The HUD,
	the panel shell, the cards and the overlays all draw with these, so the look lives in one place.

	    Sleek.plate(f, o?)                 translucent dark slab: a vertical gradient, a 1 px hairline, a lighter top edge
	    Sleek.ticks(f, o?)                 four L-shaped corner ticks drawn just outside (or on) a frame's edge
	    Sleek.accent(f, color, x, w)       the short lit bar on a plate's top edge (one accent per plate)
	    Sleek.reg(parent, name, x, y)      a registration mark (+)
	    Sleek.micro(parent, name, text, c) an index number ("01", "02/04") in Sarpanch, tracked
	    Sleek.caps(parent, name, text, o?) a tracked caps micro label (the `caps` role)
	    Sleek.seg(parent, name, n, k, o?)  a segment meter: n cells, k lit
	    Sleek.rule(parent, name, o?)       a 1 px hairline (optionally fading out)
	    Sleek.diamond(parent, name, c, d)  the emblem: a rotated outlined square with a faint fill
	    Sleek.spark(parent, name, values, color, o?)  a sparkline (Path2D when the engine has it, bars otherwise)
	    Sleek.mag(s)                       a sortable magnitude of a formatted game number ("e6.424e23" -> 23.8...)

	Colours: Sleek.C (the neutral cool greys of the style; the layer hue stays the only accent).
]]

local Theme = require(script.Parent:WaitForChild("Theme"))
local Rich = require(script.Parent:WaitForChild("Rich"))

local Sleek = {}

local WHITE = Color3.new(1, 1, 1)

Sleek.C = {
	top = Color3.fromHex("0a0e16"),
	bottom = Color3.fromHex("06090f"),
	text = Color3.fromHex("f3f6fb"),
	soft = Color3.fromHex("aab4c4"),
	micro = Color3.fromHex("6d7686"),
	microHi = Color3.fromHex("7d8797"),
	ink = Color3.fromHex("06101b"),
	good = Color3.fromHex("7fe6a0"),
	goodHi = Color3.fromHex("8ff0ad"),
	goodText = Color3.fromHex("d7f7e1"),
	goodDeep = Color3.fromHex("4be07a"),
	lockText = Color3.fromHex("b9aec3"),
	gold = Color3.fromHex("ffd34d"),
	goldText = Color3.fromHex("ffe08a"),
}
local C = Sleek.C
Sleek.LINE = 0.88 -- the hairline: white at 12 %
Sleek.LINE_HI = 0.74 -- a brighter hairline: white at 26 %

local function get(parent: Instance, name: string, class: string): any
	local c = parent:FindFirstChild(name)
	if c and c.ClassName == class then return c end
	if c then c:Destroy() end
	local n = Instance.new(class :: any)
	n.Name = name
	if n:IsA("GuiObject") then
		local g = n :: GuiObject
		g.BorderSizePixel = 0
		g.BackgroundTransparency = 1
		g.Active = false
	end
	n.Parent = parent
	return n
end
Sleek.get = get
local function drop(parent: Instance, name: string)
	local c = parent:FindFirstChild(name)
	if c then c:Destroy() end
end
Sleek.drop = drop

-- ------------------------------------------------------------------------------------------------------ surfaces
export type PlateOpts = { alpha: number?, top: Color3?, bottom: Color3?, line: number?, edge: boolean?, radius: number?,
	strokeName: string?, tint: Color3?, tintAlpha: number? }
-- a translucent slab: gradient body (alpha is the body's opacity), a 1 px hairline and a 1 px lighter top edge
function Sleek.plate(f: GuiObject, o: PlateOpts?)
	local opts: PlateOpts = o or ({} :: PlateOpts)
	local a = opts.alpha or 0.86
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 1 - a
	f.BorderSizePixel = 0
	local g = get(f, "Fill", "UIGradient") :: UIGradient
	g.Rotation = 90
	local top, bottom = opts.top or C.top, opts.bottom or C.bottom
	if opts.tint then
		top = Theme.mix(top, opts.tint, opts.tintAlpha or 0.1)
		bottom = Theme.mix(bottom, opts.tint, (opts.tintAlpha or 0.1) * 0.35)
	end
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(1, bottom) })
	g.Transparency = NumberSequence.new(0)
	local s = get(f, opts.strokeName or "Hair", "UIStroke") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Thickness = 1
	s.Color = WHITE
	s.Transparency = opts.line or Sleek.LINE
	if opts.radius and opts.radius > 0 then
		local c = get(f, "Corner", "UICorner") :: UICorner
		c.CornerRadius = UDim.new(0, opts.radius)
	else
		drop(f, "Corner")
	end
	if opts.edge ~= false then
		local e = get(f, "Edge", "Frame") :: Frame
		e.Size = UDim2.new(1, 0, 0, 1)
		e.Position = UDim2.new()
		e.BackgroundColor3 = WHITE
		e.BackgroundTransparency = math.max(0, (opts.line or Sleek.LINE) - 0.08)
		e.ZIndex = f.ZIndex
	else
		drop(f, "Edge")
	end
end

export type TickOpts = { len: number?, th: number?, color: Color3?, alpha: number?, out: number?, name: string?, z: number? }
-- four L-shaped corner ticks: 8 thin frames in a holder that is `out` du larger than the frame on every side
function Sleek.ticks(f: GuiObject, o: TickOpts?): Frame
	local opts: TickOpts = o or ({} :: TickOpts)
	local len, th, out = opts.len or 10, opts.th or 2, opts.out or 1
	local color, a = opts.color or WHITE, opts.alpha or 0.85
	local h = get(f, opts.name or "Ticks", "Frame") :: Frame
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.fromScale(0.5, 0.5)
	h.Size = UDim2.new(1, 2 * out, 1, 2 * out)
	h.ZIndex = opts.z or (f.ZIndex + 1)
	local i = 0
	for _, cx in { 0, 1 } do
		for _, cy in { 0, 1 } do
			i += 1
			local hb = get(h, "H" .. i, "Frame") :: Frame
			hb.AnchorPoint = Vector2.new(cx, cy)
			hb.Position = UDim2.fromScale(cx, cy)
			hb.Size = UDim2.fromOffset(len, th)
			hb.BackgroundColor3 = color
			hb.BackgroundTransparency = 1 - a
			hb.ZIndex = h.ZIndex
			local vb = get(h, "V" .. i, "Frame") :: Frame
			vb.AnchorPoint = Vector2.new(cx, cy)
			vb.Position = UDim2.fromScale(cx, cy)
			vb.Size = UDim2.fromOffset(th, len)
			vb.BackgroundColor3 = color
			vb.BackgroundTransparency = 1 - a
			vb.ZIndex = h.ZIndex
		end
	end
	return h
end

-- the lit bar on a plate's top edge (glow where UIShadow exists)
function Sleek.accent(f: GuiObject, color: Color3, x: number, w: number, o: { name: string?, h: number?, glow: boolean? }?): Frame
	local name = if o and o.name then o.name else "Accent"
	local b = get(f, name, "Frame") :: Frame
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = UDim2.fromOffset(x, 0)
	b.Size = UDim2.fromOffset(w, if o and o.h then o.h else 3)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0
	b.ZIndex = f.ZIndex + 2
	if (o == nil or o.glow ~= false) and Theme.caps.UIShadow then
		local s = get(b, "Glow", "UIShadow") :: any
		pcall(function()
			s.Color = color
			s.Transparency = 0.35
			s.BlurRadius = UDim.new(0, 10)
			s.Offset = UDim2.new()
		end)
	end
	return b
end

-- a registration mark (+), centred on (x, y) in the parent's offset space
function Sleek.reg(parent: GuiObject, name: string, x: number, y: number, o: { s: number?, alpha: number? }?): Frame
	local s = if o and o.s then o.s else 9
	local a = if o and o.alpha then o.alpha else 0.4
	-- the vertical stroke is the holder, the horizontal one its child (two instances)
	local v = get(parent, name, "Frame") :: Frame
	v.AnchorPoint = Vector2.new(0.5, 0.5)
	v.Position = UDim2.fromOffset(x, y)
	v.Size = UDim2.fromOffset(1, s)
	v.BackgroundColor3 = WHITE
	v.BackgroundTransparency = 1 - a
	v.ZIndex = parent.ZIndex + 1
	local hz = get(v, "H", "Frame") :: Frame
	hz.AnchorPoint = Vector2.new(0.5, 0.5)
	hz.Position = UDim2.fromScale(0.5, 0.5)
	hz.Size = UDim2.fromOffset(s, 1)
	hz.BackgroundColor3 = WHITE
	hz.BackgroundTransparency = 1 - a
	hz.ZIndex = v.ZIndex
	drop(v, "V")
	return v
end

-- ------------------------------------------------------------------------------------------------------ type
-- an index number: Sarpanch Bold, auto width
function Sleek.micro(parent: Instance, name: string, text: string, color: Color3?, size: number?): TextLabel
	local l = get(parent, name, "TextLabel") :: TextLabel
	l.FontFace = Font.fromName("Sarpanch", Enum.FontWeight.Bold)
	l.TextSize = size or 13
	l.LineHeight = 1
	l.TextColor3 = color or C.micro
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, size or 13)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = false
	l.RichText = false
	if l.Text ~= text then l.Text = text end
	return l
end

-- hair spaces between letters: the tracked caps of the style (Roblox text has no letter spacing)
function Sleek.track(s: string): string
	return Rich.caps(s)
end

export type CapsOpts = { color: Color3?, role: string?, weight: Enum.FontWeight?, size: number?, h: number? }
-- a tracked caps micro label: Montserrat Bold 12-13, soft, auto width
function Sleek.caps(parent: Instance, name: string, text: string, o: CapsOpts?): TextLabel
	local opts: CapsOpts = o or ({} :: CapsOpts)
	local l = get(parent, name, "TextLabel") :: TextLabel
	Theme.text(l, opts.role or "caps")
	if opts.size then l.TextSize = opts.size end
	if opts.weight then l.FontFace = Font.fromName("Montserrat", opts.weight) end
	l.TextColor3 = opts.color or C.soft
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, opts.h or l.TextSize)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = false
	l.RichText = false
	local t = Sleek.track(text)
	if l.Text ~= t then l.Text = t end
	return l
end

-- ------------------------------------------------------------------------------------------------------ data
export type SegOpts = { w: number?, h: number?, gap: number?, on: Color3?, off: number? }
-- a segment meter: a horizontal row of n cells, the first k lit
function Sleek.seg(parent: Instance, name: string, n: number, k: number, o: SegOpts?): Frame
	local opts: SegOpts = o or ({} :: SegOpts)
	local w, h, gap = opts.w or 3, opts.h or 12, opts.gap or 2
	n = math.clamp(math.floor(n), 0, 40)
	local f = get(parent, name, "Frame") :: Frame
	f.Size = UDim2.fromOffset(math.max(0, n * w + (n - 1) * gap), h)
	for i = 1, n do
		local c = get(f, "S" .. i, "Frame") :: Frame
		c.Position = UDim2.fromOffset((i - 1) * (w + gap), 0)
		c.Size = UDim2.fromOffset(w, h)
		c.BackgroundColor3 = if i <= k then opts.on or C.good else WHITE
		c.BackgroundTransparency = if i <= k then 0 else (opts.off or 0.82)
	end
	for _, c in f:GetChildren() do
		local i = tonumber(string.match(c.Name, "^S(%d+)$"))
		if i and i > n then c:Destroy() end
	end
	return f
end

-- a 1 px hairline: full width of the parent by default, fading out to the right when fade is set
function Sleek.rule(parent: Instance, name: string, o: { alpha: number?, fade: boolean?, color: Color3?, vertical: boolean? }?): Frame
	local r = get(parent, name, "Frame") :: Frame
	r.BackgroundColor3 = if o and o.color then o.color else WHITE
	r.BackgroundTransparency = if o and o.alpha then 1 - o.alpha else Sleek.LINE
	if o and o.vertical then
		r.Size = UDim2.new(0, 1, 1, 0)
	else
		r.Size = UDim2.new(1, 0, 0, 1)
	end
	if o and o.fade then
		local g = get(r, "Fade", "UIGradient") :: UIGradient
		g.Rotation = if o.vertical then 90 else 0
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	else
		drop(r, "Fade")
	end
	return r
end

-- the emblem: an outlined diamond with a faint fill and an inner fine diamond (the symbol goes on top, unrotated)
function Sleek.diamond(parent: Instance, name: string, color: Color3, d: number, o: { fill: number?, inner: boolean? }?): Frame
	local h = get(parent, name, "Frame") :: Frame
	h.Size = UDim2.fromOffset(d, d)
	local k = d / math.sqrt(2)
	local outer = get(h, "Outer", "Frame") :: Frame
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.Position = UDim2.fromScale(0.5, 0.5)
	outer.Size = UDim2.fromOffset(math.floor(k * 0.98), math.floor(k * 0.98))
	outer.Rotation = 45
	outer.BackgroundColor3 = color
	outer.BackgroundTransparency = 1 - (if o and o.fill then o.fill else 0.12)
	outer.ZIndex = h.ZIndex
	local s = get(outer, "Line", "UIStroke") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Thickness = if d >= 40 then 1.5 else 1.25
	s.Color = color
	s.Transparency = 0
	if o == nil or o.inner ~= false then
		local inner = get(h, "Inner", "Frame") :: Frame
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Size = UDim2.fromOffset(math.floor(k * 0.72), math.floor(k * 0.72))
		inner.Rotation = 45
		inner.ZIndex = h.ZIndex
		local si = get(inner, "Line", "UIStroke") :: UIStroke
		si.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		si.LineJoinMode = Enum.LineJoinMode.Miter
		si.Thickness = 1
		si.Color = color
		si.Transparency = 0.65
	else
		drop(h, "Inner")
	end
	return h
end

-- ------------------------------------------------------------------------------------------------------ sparkline
-- a magnitude that sorts formatted game numbers ("1,234", "4.2e56", "e6.4e23", "ee12", "1e1,234") for a sparkline
function Sleek.mag(s: string?): number?
	if type(s) ~= "string" then return nil end
	local t = string.gsub(string.gsub(string.lower(s), ",", ""), "^%s*[%+]?", "")
	local layers = 0
	while string.sub(t, 1, 1) == "e" do
		layers += 1
		t = string.sub(t, 2)
	end
	local n = tonumber(string.match(t, "^[%d%.]+e?[%+%-]?%d*") or "")
	if n == nil then
		n = tonumber(string.match(t, "^[%d%.]+") or "")
	end
	if n == nil or n ~= n then return nil end
	n = math.min(n, 1e300) -- "1e400" parses to inf; keep the maths finite
	-- inside one layer count, log10 keeps the order; each extra "e" dwarfs the previous layers
	local v = if n > 0 then math.log10(n) else 0
	if layers > 0 then v = if v > 0 then math.log10(v + 1) else 0 end
	return layers * 1000 + v
end

export type SparkOpts = { w: number, h: number, thick: number?, dot: boolean?, bars: boolean? }
-- values are raw; the line is normalised to the frame (a flat series draws a mid line)
function Sleek.spark(parent: Instance, name: string, values: { number }, color: Color3, o: SparkOpts): Frame
	local f = get(parent, name, "Frame") :: Frame
	f.Size = UDim2.fromOffset(o.w, o.h)
	local n = #values
	local lo, hi = math.huge, -math.huge
	for _, v in values do
		lo = math.min(lo, v)
		hi = math.max(hi, v)
	end
	local span = hi - lo
	local function y01(v: number): number
		if n < 2 or not (span > 1e-12 and span < math.huge) then return 0.5 end
		local y = (v - lo) / span
		return if y == y then math.clamp(y, 0, 1) else 0.5
	end
	-- a dim baseline under the data (and all there is until two samples exist)
	local base = get(f, "Base", "Frame") :: Frame
	base.AnchorPoint = Vector2.new(0, 1)
	base.Position = UDim2.fromScale(0, 1)
	base.Size = UDim2.new(1, 0, 0, 1)
	base.BackgroundColor3 = WHITE
	base.BackgroundTransparency = 0.88
	if n < 2 then
		drop(f, "Line")
		for _, c in f:GetChildren() do
			if string.match(c.Name, "^B%d+$") then c:Destroy() end
		end
		drop(f, "Dot")
		return f
	end
	local usePath = not o.bars and Theme.caps.Path2D == true
	if usePath then
		for _, c in f:GetChildren() do
			if string.match(c.Name, "^B%d+$") then c:Destroy() end
		end
		local p = get(f, "Line", "Path2D") :: any
		pcall(function()
			p.Color3 = color
			p.Thickness = o.thick or 1.6
			p.ZIndex = f.ZIndex + 1
			local pts = {}
			for i, v in values do
				local x = (i - 1) / (n - 1)
				local y = 1 - (0.1 + 0.8 * y01(v))
				table.insert(pts, Path2DControlPoint.new(UDim2.fromScale(x, y)))
			end
			p:SetControlPoints(pts)
		end)
	else
		drop(f, "Line")
		local bw = if n > 0 then o.w / n else o.w
		for i, v in values do
			local b = get(f, "B" .. i, "Frame") :: Frame
			local bh = math.max(2, math.floor((0.15 + 0.85 * y01(v)) * o.h + 0.5))
			b.AnchorPoint = Vector2.new(0, 1)
			b.Position = UDim2.new(0, math.floor((i - 1) * bw), 1, 0)
			b.Size = UDim2.fromOffset(math.max(1, math.floor(bw) - 1), bh)
			b.BackgroundColor3 = color
			b.BackgroundTransparency = if i == n then 0 else 0.72
		end
		for _, c in f:GetChildren() do
			local i = tonumber(string.match(c.Name, "^B(%d+)$"))
			if i and i > n then c:Destroy() end
		end
	end
	if o.dot ~= false and n >= 1 then
		local d = get(f, "Dot", "Frame") :: Frame
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.fromScale(1, 1 - (0.1 + 0.8 * y01(values[n])))
		d.Size = UDim2.fromOffset(5, 5)
		d.BackgroundColor3 = color
		d.BackgroundTransparency = if usePath then 0 else 1
		d.ZIndex = f.ZIndex + 2
		local c = get(d, "Corner", "UICorner") :: UICorner
		c.CornerRadius = UDim.new(0.5, 0)
	else
		drop(f, "Dot")
	end
	return f
end

-- the layer's place in the tree (row, then the game's order): the "LAYER 02 / 21" readout
local ORDER = { "m", "p", "mm", "sp", "pe", "pb", "em", "se", "hp", "pp", "ep", "hb", "ap", "mp", "t", "pm", "pep", "cp", "cm", "ex", "ach" }
Sleek.ORDER = ORDER
function Sleek.layerIndex(key: string): number?
	for i, k in ORDER do
		if k == key then return i end
	end
	return nil
end

return Sleek
