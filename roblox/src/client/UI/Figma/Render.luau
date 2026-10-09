--!nonstrict
-- Figma/Render: turns a generated layout (UI/Figma/Layouts/*.luau, made from the Figma frames by
-- tools/figma_export/build_layouts.py) into Roblox GUI, node for node, at the Figma coordinates. So the in-game UI
-- matches Figma by construction: change Figma, re-export, rebuild.
--   * every instance is named after its Figma layer, so binders find things with FindFirstChild(name, true)
--   * Kit keys (ink body / lip / face) get the owner-approved press: the WHOLE key drops by the lip depth, lip
--     hidden, hover = face +6 % brighter; every press plays Sfx.press()
--   * nodes named tab/* and btn/* are clickable too (ui.on(name, fn))
-- Perf: build once per window (lazily, on first open), no per-frame work here.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Icons = require(RS:WaitForChild("Peckwood"):WaitForChild("Icons"))
local IconAlias = require(script.Parent.IconAlias)
local Sfx = require(script.Parent.Parent.Sfx)

local Render = {}

local INK = Color3.fromHex("0b0c10")
local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local WHITE = Color3.new(1, 1, 1)
local TEX = { stripes = Icons["ui/stripes"], halftone = Icons["ui/halftone"], lattice = Icons["ui/lattice"] }
Render.INK, Render.FONT = INK, FONT

local cc = {}
local function C(hex: string): Color3
	local c = cc[hex]
	if not c then c = Color3.fromHex(hex); cc[hex] = c end
	return c
end
Render.C = C

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
Render.new = new

local function corner(o, r)
	if r and r > 0 then new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
end
local function stroke(o, col, transp, w, align)
	local s = new("UIStroke", { Color = col, Transparency = transp, Thickness = w, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter }, o)
	pcall(function()
		s.BorderStrokePosition = if align == "I" then Enum.BorderStrokePosition.Inner elseif align == "O" then Enum.BorderStrokePosition.Outer else Enum.BorderStrokePosition.Center
	end)
	return s
end
Render.stroke = stroke

-- linear gradient layer {"g", rotation, {{t, hex, alpha}...}} -> UIGradient
local function gradient(parent, L, alpha)
	local cs, ts = table.create(#L[3]), table.create(#L[3])
	for i, s in L[3] do
		cs[i] = ColorSequenceKeypoint.new(s[1], C(s[2]))
		ts[i] = NumberSequenceKeypoint.new(s[1], math.clamp(1 - s[3] * alpha, 0, 1))
	end
	return new("UIGradient", { Color = ColorSequence.new(cs), Transparency = NumberSequence.new(ts), Rotation = L[2] }, parent)
end
Render.gradient = gradient

-- one fill layer drawn as its own full-size child (z 0 = under the node's children)
local function overlay(node, parent, L, alpha, w, h, r)
	local k = L[1]
	if k == "s" then
		local f = new("Frame", { Name = "fill", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(L[2]), BackgroundTransparency = 1 - L[3] * alpha, ZIndex = 0 }, parent)
		corner(f, r)
	elseif k == "g" then
		local f = new("Frame", { Name = "fill", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 0 }, parent)
		corner(f, r); gradient(f, L, alpha)
	elseif k == "t" then
		local id = TEX[L[2]]
		if id then
			local im = new("ImageLabel", { Name = "tex/" .. L[2], BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = id, ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(L[3], L[3]), ImageTransparency = 1 - L[4] * alpha, ZIndex = 0 }, parent)
			corner(im, r)
		end
	elseif k == "r" then
		-- radial gradient: soft ellipse in the centre colour, clipped to the node (linear-only fallback look)
		local clip = new("Frame", { Name = "radial", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 0 }, parent)
		new("ImageLabel", { BackgroundTransparency = 1, Image = Icons["ui/softellipse"], ImageColor3 = C(L[6]), ImageTransparency = 1 - math.min(1, L[7] * alpha * 1.4),
			Position = UDim2.fromOffset((L[2] - L[4]) * w, (L[3] - L[5]) * h), Size = UDim2.fromOffset(2 * L[4] * w, 2 * L[5] * h), ZIndex = 0 }, clip)
	end
end

-- fills: the first solid / linear layer paints the node itself; the rest become overlay children
local function paint(node, inst, layers, alpha, w, h, r, canvas)
	if not layers then return end
	for i, L in layers do
		if i == 1 and not canvas and (L[1] == "s" or L[1] == "g") then
			inst.BorderSizePixel = 0
			if L[1] == "s" then
				inst.BackgroundColor3 = C(L[2]); inst.BackgroundTransparency = 1 - L[3] * alpha
			else
				inst.BackgroundColor3 = WHITE; inst.BackgroundTransparency = 0; gradient(inst, L, alpha)
			end
		else
			overlay(node, inst, L, alpha, w, h, r)
		end
	end
end

-- ---------------------------------------------------------------- glyphs (vector-drawn tiny UI symbols, owner-allowed)
-- drawn as rounded bars on a 24 px grid: all ink bars first, then all colour bars (no ink cutting across a joint)
local GLYPH = {
	x = { { 6, 6, 18, 18 }, { 18, 6, 6, 18 } }, check = { { 4.5, 12.5, 9.5, 17.5 }, { 9.5, 17.5, 19.5, 6.5 } },
	left = { { 15, 4, 7, 12 }, { 7, 12, 15, 20 } }, right = { { 9, 4, 17, 12 }, { 17, 12, 9, 20 } },
	up = { { 4, 15, 12, 7 }, { 12, 7, 20, 15 } }, down = { { 4, 9, 12, 17 }, { 12, 17, 20, 9 } },
	plus = { { 12, 5, 12, 19 }, { 5, 12, 19, 12 } }, minus = { { 5, 12, 19, 12 } },
}
local CHEV = { { 3, 3, 9, 8 }, { 9, 8, 3, 13 }, { 13, 3, 19, 8 }, { 19, 8, 13, 13 }, { 23, 3, 29, 8 }, { 29, 8, 23, 13 } }
local function bar(parent, x1, y1, x2, y2, th, col, transp, z)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(len + th, th), Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = col, BackgroundTransparency = transp, ZIndex = z }, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	return f
end
function Render.glyph(parent, kind, x, y, w, h, col, alpha, inkW, lineW)
	local holder = new("Frame", { Name = "glyph/" .. kind, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	-- "chevron left" (travel keys) = the left glyph; a glyph exported in ink is a white line with an ink outline
	local k = string.gsub(kind, "^chevron%s*", "")
	if k == "" then k = "right" end
	local segs = GLYPH[k] or GLYPH.x
	if col == INK then col = WHITE end
	local s = w / 24
	for _, sg in segs do bar(holder, sg[1] * s, sg[2] * s, sg[3] * s, sg[4] * s, (inkW or 7.5) * s, INK, 1 - alpha, 1) end
	for _, sg in segs do bar(holder, sg[1] * s, sg[2] * s, sg[3] * s, sg[4] * s, (lineW or 3.6) * s, col, 1 - alpha, 2) end
	return holder
end
function Render.chevrons(parent, x, y, w, h, col, alpha)
	local holder = new("Frame", { Name = "growth chevrons", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	local s = w / 34
	for _, sg in CHEV do bar(holder, sg[1] * s, sg[2] * s, sg[3] * s, sg[4] * s, 5 * s, INK, 1 - alpha, 1) end
	for _, sg in CHEV do bar(holder, sg[1] * s, sg[2] * s, sg[3] * s, sg[4] * s, 2.6 * s, col, 1 - alpha, 2) end
	return holder
end

-- ---------------------------------------------------------------- text
local SHADOW = setmetatable({}, { __mode = "k" })   -- label -> its ink drop-shadow label
Render.SHADOW = SHADOW
function Render.setText(label: TextLabel, s: string)
	if label.Text == s then return end
	label.Text = s
	local sh = SHADOW[label]
	if sh then sh.Text = if label.RichText then (string.gsub(s, "<[^>]+>", "")) else s end
end
function Render.setTextColor(label: TextLabel, col: Color3)
	label.TextColor3 = col
	local g = label:FindFirstChildOfClass("UIGradient")
	if g then g:Destroy() end
end

local AX = { L = Enum.TextXAlignment.Left, C = Enum.TextXAlignment.Center, R = Enum.TextXAlignment.Right }
local AY = { T = Enum.TextYAlignment.Top, C = Enum.TextYAlignment.Center, B = Enum.TextYAlignment.Bottom }
local function textNode(n, P, parent, alpha, z)
	local tf = n.tf and P[n.tf]
	local col, grad = WHITE, nil
	local ta = 0
	if tf and tf[1] then
		if tf[1][1] == "s" then col = C(tf[1][2]); ta = 1 - tf[1][3] * alpha
		elseif tf[1][1] == "g" then grad = tf[1]; ta = 1 - alpha end
	else
		ta = 1 - alpha
	end
	-- one line of text (box no taller than ~1.6 lines): centre it vertically like Figma's auto line height
	local single = not string.find(n.tx or "", "\n", 1, true) and n.h < (n.fs or 14) * 1.6
	local size = math.floor((n.fs or 14) * 0.96 + 0.5)
	local props = {
		Name = n.n, BackgroundTransparency = 1, Position = UDim2.fromOffset(n.x, n.y), Size = UDim2.fromOffset(n.w, n.h),
		FontFace = FONT, TextSize = size, Text = n.rich or n.tx, RichText = n.rich ~= nil, TextColor3 = col, TextTransparency = ta,
		TextXAlignment = AX[n.ax] or Enum.TextXAlignment.Left, TextYAlignment = if single then Enum.TextYAlignment.Center else (AY[n.ay] or Enum.TextYAlignment.Top),
		TextWrapped = n.wrap == true, ZIndex = z,
	}
	if n.rot then props.Rotation = -n.rot end
	local label = new("TextLabel", props, parent)
	if grad then gradient(label, grad, alpha) end
	local sw = n.sw
	local sc = if n.sc then C(n.sc[1]) else INK
	local sct = if n.sc then 1 - n.sc[2] * alpha else 1 - alpha
	if sw and sw > 0 then
		new("UIStroke", { Thickness = sw, Color = sc, Transparency = sct, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round }, label)
	end
	if n.sh then
		local shc = if n.shc then C(n.shc[1]) else INK
		local sht = if n.shc then 1 - n.shc[2] * alpha else 1 - alpha
		local sh = new("TextLabel", {
			Name = n.n .. "  (drop)", BackgroundTransparency = 1, Position = UDim2.fromOffset(n.x + n.sh[1], n.y + n.sh[2]), Size = UDim2.fromOffset(n.w, n.h),
			FontFace = FONT, TextSize = size, Text = n.tx, TextColor3 = shc, TextTransparency = sht, TextXAlignment = props.TextXAlignment,
			TextYAlignment = props.TextYAlignment, TextWrapped = props.TextWrapped, ZIndex = z - 1, Rotation = props.Rotation or 0,
		}, parent)
		if sw and sw > 0 then
			new("UIStroke", { Thickness = sw, Color = shc, Transparency = sht, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round }, sh)
		end
		SHADOW[label] = sh
	end
	return label
end

-- ---------------------------------------------------------------- effects drawn behind a node (z - 1)
local function behind(n, P, parent, alpha, z, hasFill)
	local fx = n.e and P[n.e]
	if not fx then return end
	for _, e in fx do
		if e[1] == "d" then
			local dx, dy, blur, col, a, spread = e[2], e[3], e[4], C(e[5]), e[6] * alpha, e[7] or 0
			if blur <= 0.01 then
				if hasFill then
					local f = new("Frame", { Name = "drop", BorderSizePixel = 0, Position = UDim2.fromOffset(n.x + dx - spread, n.y + dy - spread), Size = UDim2.fromOffset(n.w + 2 * spread, n.h + 2 * spread),
						BackgroundColor3 = col, BackgroundTransparency = 1 - a, ZIndex = z - 1, Rotation = if n.rot then -n.rot else 0 }, parent)
					corner(f, n.r)
				elseif n.s then
					local st = P[n.s]
					local f = new("Frame", { Name = "drop", BackgroundTransparency = 1, Position = UDim2.fromOffset(n.x + dx, n.y + dy), Size = UDim2.fromOffset(n.w, n.h), ZIndex = z - 1 }, parent)
					corner(f, n.r); stroke(f, col, 1 - a, st[3], st[4])
				end
			else
				local m = blur + spread
				new("ImageLabel", { Name = "shadow", BackgroundTransparency = 1, Image = Icons["ui/shadow"], ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(128, 128, 128, 128),
					SliceScale = math.max(0.05, blur / 64), ImageColor3 = col, ImageTransparency = 1 - math.min(1, a * 1.15),
					Position = UDim2.fromOffset(n.x + dx - m, n.y + dy - m), Size = UDim2.fromOffset(n.w + 2 * m, n.h + 2 * m), ZIndex = z - 1 }, parent)
			end
		end
	end
end
-- inner shadows: a top band inside the node, above its fills, under its children
local function inner(n, P, inst, alpha)
	local fx = n.e and P[n.e]
	if not fx then return end
	for _, e in fx do
		if e[1] == "i" and n.h > 0 then
			local reach = math.clamp((math.abs(e[3]) + e[4]) / n.h, 0.02, 1)
			local f = new("Frame", { Name = "inner shadow", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(e[5]), ZIndex = 1 }, inst)
			corner(f, n.r)
			new("UIGradient", { Rotation = if e[3] < 0 then 270 else 90, Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - e[6] * alpha), NumberSequenceKeypoint.new(reach, 1), NumberSequenceKeypoint.new(1, 1) }) }, f)
		end
	end
end

local function hasRotated(n)
	if not n.k then return false end
	for _, c in n.k do
		if c.rot or hasRotated(c) then return true end
	end
	return false
end

-- ---------------------------------------------------------------- nodes
local build
function build(n, P, parent, alpha, z, ui)
	alpha = alpha * (n.o or 1)
	local t = n.t
	if t == "T" then
		local l = textNode(n, P, parent, alpha, z)
		behind(n, P, parent, alpha, z, false)
		return l
	elseif t == "I" then
		local id = IconAlias.id(n.icon)
		local fx = n.e and P[n.e]
		if fx then
			for _, e in fx do
				if e[1] == "d" and e[4] <= 0.01 then
					new("ImageLabel", { Name = "drop", BackgroundTransparency = 1, Image = id, ImageColor3 = C(e[5]), ImageTransparency = 1 - e[6] * alpha * (n.ia or 1),
						Position = UDim2.fromOffset(n.x + e[2], n.y + e[3]), Size = UDim2.fromOffset(n.w, n.h), ScaleType = Enum.ScaleType.Fit, ZIndex = z - 1 }, parent)
				end
			end
		end
		local im = new("ImageLabel", { Name = n.n, BackgroundTransparency = 1, Image = id, ImageTransparency = 1 - alpha * (n.ia or 1), ScaleType = Enum.ScaleType.Fit,
			Position = UDim2.fromOffset(n.x, n.y), Size = UDim2.fromOffset(n.w, n.h), ZIndex = z, Rotation = if n.rot then -n.rot else 0 }, parent)
		im:SetAttribute("icon", n.icon)
		return im
	elseif t == "G" then
		local g = Render.glyph(parent, n.kind, n.x, n.y, n.w, n.h, C(n.col or "ffffff"), alpha, n.ink, n.lw)
		g.ZIndex = z
		return g
	elseif t == "C" then
		local g = Render.chevrons(parent, n.x, n.y, n.w, n.h, C(n.col or "5fe06a"), alpha)
		g.ZIndex = z
		return g
	elseif t == "S" then
		local s = math.max(n.w, n.h) * 1.7
		local im = new("ImageLabel", { Name = n.n, BackgroundTransparency = 1, Image = Icons["ui/sparkle"], ImageColor3 = C(n.col or "ffffff"), ImageTransparency = 1 - alpha,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(n.x + n.w / 2, n.y + n.h / 2), Size = UDim2.fromOffset(s, s), ZIndex = z }, parent)
		table.insert(ui.sparkles, im)
		return im
	elseif t == "B" then
		-- blurred ellipse (Figma layer blur): soft ellipse image, grown by the blur radius
		local fx = n.e and P[n.e]
		local blur = 0
		if fx then for _, e in fx do if e[1] == "lb" then blur = e[2] end end end
		local layers = n.f and P[n.f]
		local im = new("ImageLabel", { Name = n.n, BackgroundTransparency = 1, Image = Icons["ui/softellipse"], ImageTransparency = 1 - alpha,
			Position = UDim2.fromOffset(n.x - blur, n.y - blur), Size = UDim2.fromOffset(n.w + 2 * blur, n.h + 2 * blur), ZIndex = z }, parent)
		if layers and layers[1] then
			local L = layers[1]
			if L[1] == "s" then im.ImageColor3 = C(L[2]); im.ImageTransparency = 1 - L[3] * alpha
			elseif L[1] == "g" then gradient(im, L, alpha) end
		end
		return im
	end
	-- frames / rects / ellipses
	local canvas = n.c and hasRotated(n)
	local inst
	if canvas then
		inst = new("CanvasGroup", { Name = n.n, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(n.x, n.y), Size = UDim2.fromOffset(n.w, n.h), ZIndex = z }, parent)
	else
		inst = new("Frame", { Name = n.n, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(n.x, n.y), Size = UDim2.fromOffset(n.w, n.h),
			ClipsDescendants = n.c == true, ZIndex = z }, parent)
	end
	if n.rot then
		inst.Rotation = -n.rot
	end
	local r = n.r
	if t == "E" then new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, inst); r = nil
	else corner(inst, r) end
	local layers = n.f and P[n.f]
	paint(n, inst, layers, alpha, n.w, n.h, r, canvas)
	if t == "E" and layers then
		for _, ch in inst:GetChildren() do
			if ch:IsA("GuiObject") and ch.Name == "fill" then new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ch) end
		end
	end
	inner(n, P, inst, alpha)
	if n.s then
		local st = P[n.s]
		stroke(inst, C(st[1]), 1 - st[2] * alpha, st[3], st[4])
	end
	behind(n, P, parent, alpha, z, layers ~= nil and #layers > 0)
	if n.k then
		for i, c in n.k do build(c, P, inst, alpha, 2 + 2 * i, ui) end
	end
	if n.key then
		inst:SetAttribute("keyDepth", n.key)
		table.insert(ui.keys, { inst = inst, node = n, depth = n.key })
	elseif string.sub(n.n, 1, 4) == "tab/" or string.sub(n.n, 1, 4) == "btn/" then
		table.insert(ui.clicks, { inst = inst, node = n })
	end
	return inst
end

-- ---------------------------------------------------------------- interaction
local Q = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BACK = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- the owner-approved key press: ink body and face drop together by the lip depth D, the body loses D of height and
-- the lip hides (no black band above the face, no lip below while held)
function Render.wireKey(ui, k)
	local inst, D = k.inst, k.depth
	local body, lip, face = inst:FindFirstChild("ink body"), inst:FindFirstChild("lip"), inst:FindFirstChild("face") or inst:FindFirstChild("body")
	if not (body and face) then return end
	local bp, bs, fp = body.Position, body.Size, face.Position
	local hl = new("Frame", { Name = "hover", BorderSizePixel = 0, BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 }, face)
	corner(hl, 2.5)
	local hit = new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999 }, inst)
	k.hit = hit
	local down = false
	local function release()
		if not down then return end
		down = false
		if lip then lip.Visible = true end
		TweenService:Create(body, BACK, { Position = bp, Size = bs }):Play()
		TweenService:Create(face, BACK, { Position = fp }):Play()
	end
	hit.MouseEnter:Connect(function()
		if k.disabled then return end
		TweenService:Create(hl, Q, { BackgroundTransparency = 0.94 }):Play()
	end)
	hit.MouseLeave:Connect(function()
		TweenService:Create(hl, Q, { BackgroundTransparency = 1 }):Play()
		release()
	end)
	hit.MouseButton1Down:Connect(function()
		down = true
		Sfx.press()
		if lip then lip.Visible = false end
		TweenService:Create(body, Q, { Position = bp + UDim2.fromOffset(0, D), Size = bs - UDim2.fromOffset(0, D) }):Play()
		TweenService:Create(face, Q, { Position = fp + UDim2.fromOffset(0, D) }):Play()
	end)
	hit.MouseButton1Up:Connect(function() Sfx.release(); release() end)
	hit.Activated:Connect(function()
		local fns = ui.handlers[k.node.n]
		if fns then for _, fn in fns do task.spawn(fn, inst, k) end end
		for _, fn in ui.anyHandlers do task.spawn(fn, k.node.n, inst, k) end
	end)
end
-- tabs / plain buttons that are not keys: hover brightens, press = keycap sound
function Render.wireClick(ui, c)
	local inst = c.inst
	local hl = new("Frame", { Name = "hover", BorderSizePixel = 0, BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 }, inst)
	corner(hl, c.node.r)
	local hit = new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999 }, inst)
	c.hit = hit
	hit.MouseEnter:Connect(function() TweenService:Create(hl, Q, { BackgroundTransparency = 0.95 }):Play() end)
	hit.MouseLeave:Connect(function() TweenService:Create(hl, Q, { BackgroundTransparency = 1 }):Play() end)
	hit.MouseButton1Down:Connect(function() Sfx.press() end)
	hit.Activated:Connect(function()
		local fns = ui.handlers[c.node.n]
		if fns then for _, fn in fns do task.spawn(fn, inst, c) end end
		for _, fn in ui.anyHandlers do task.spawn(fn, c.node.n, inst, c) end
	end)
end

-- ---------------------------------------------------------------- public
-- Render.build(layout, parent, rootNode?) -> ui
--   ui.root (the frame), ui.keys, ui.clicks, ui.sparkles
--   ui.on(name, fn(inst, key))   -- every key / tab / btn with that Figma name
--   ui.onAny(fn(name, inst, key))
--   ui.find(name[, under]) -> first instance with that Figma layer name (recursive)
function Render.build(layout, parent, node, opts)
	local ui = { keys = {}, clicks = {}, sparkles = {}, handlers = {}, anyHandlers = {}, layout = layout }
	node = node or layout.root
	-- ui.root = a plain holder the size of the node (move / show / hide this one: the node's own drop shadows are
	-- its siblings, so they travel with it); ui.node = the node itself
	ui.root = new("Frame", { Name = node.n, BackgroundTransparency = 1, Size = UDim2.fromOffset(node.w, node.h), ZIndex = (opts and opts.z) or 1 }, parent)
	local rn = table.clone(node)
	rn.x, rn.y = 0, 0
	ui.node = build(rn, layout.P, ui.root, 1, 2, ui)
	for _, k in ui.keys do Render.wireKey(ui, k) end
	for _, c in ui.clicks do Render.wireClick(ui, c) end
	function ui.on(name, fn)
		ui.handlers[name] = ui.handlers[name] or {}
		table.insert(ui.handlers[name], fn)
	end
	function ui.onAny(fn) table.insert(ui.anyHandlers, fn) end
	function ui.find(name, under) return (under or ui.root):FindFirstChild(name, true) end
	function ui.findAll(name, under)
		local out = {}
		for _, d in (under or ui.root):GetDescendants() do if d.Name == name then table.insert(out, d) end end
		return out
	end
	return ui
end

-- build one component of a HUD section layout (Layouts/Hud_*.luau: { P, C = { [name] = node } })
function Render.component(section, name, parent)
	local node = section.C[name]
	assert(node, "no Figma component " .. tostring(name))
	return Render.build({ P = section.P, root = node }, parent, node)
end

-- all text labels under an instance (drop shadows excluded), top-to-bottom then left-to-right
function Render.texts(under)
	local out = {}
	for _, d in under:GetDescendants() do
		if d:IsA("TextLabel") and not string.find(d.Name, "  %(drop%)$") then table.insert(out, d) end
	end
	table.sort(out, function(a, b)
		local pa, pb = a.AbsolutePosition, b.AbsolutePosition
		if math.abs(pa.Y - pb.Y) > 3 then return pa.Y < pb.Y end
		return pa.X < pb.X
	end)
	return out
end
-- direct text children of a frame, in design order (y, then x) without needing AbsolutePosition
function Render.childTexts(under)
	local out = {}
	for _, d in under:GetChildren() do
		if d:IsA("TextLabel") and not string.find(d.Name, "  %(drop%)$") then table.insert(out, d) end
	end
	table.sort(out, function(a, b)
		local pa, pb = a.Position, b.Position
		if math.abs(pa.Y.Offset - pb.Y.Offset) > 3 then return pa.Y.Offset < pb.Y.Offset end
		return pa.X.Offset < pb.X.Offset
	end)
	return out
end

-- find a node table in a layout by exact name, or by name prefix when `prefix` is true
function Render.findNode(n, name, prefix)
	if n.n == name or (prefix and string.sub(n.n, 1, #name) == name) then return n end
	if n.k then
		for _, c in n.k do
			local r = Render.findNode(c, name, prefix)
			if r then return r end
		end
	end
	return nil
end
function Render.findNodes(n, pred, out)
	out = out or {}
	if pred(n) then table.insert(out, n) end
	if n.k then for _, c in n.k do Render.findNodes(c, pred, out) end end
	return out
end
-- build one node of a layout (e.g. a row template) at its own Figma position under `parent`, fully wired
function Render.buildNode(layout, node, parent, z)
	local ui = Render.build({ P = layout.P, root = node }, parent, node, { z = z })
	ui.root.Position = UDim2.fromOffset(node.x, node.y)
	return ui
end

-- shrink a label's text to fit its box (live values longer than the Figma sample)
function Render.fit(label: TextLabel, minSize: number?)
	local base = label:GetAttribute("baseSize") or label.TextSize
	label:SetAttribute("baseSize", base)
	local sh = SHADOW[label]
	local function apply()
		local w = label.AbsoluteSize.X
		if w <= 0 then return end
		local size = base
		local tb = label.TextBounds.X * (base / math.max(1, label.TextSize))
		if tb > w then size = math.max(minSize or 9, math.floor(base * w / tb)) end
		if label.TextSize ~= size then label.TextSize = size; if sh then sh.TextSize = size end end
	end
	label:GetPropertyChangedSignal("Text"):Connect(apply)
	task.defer(apply)
end

return Render
