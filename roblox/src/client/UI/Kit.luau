--!nonstrict
-- Kit: Roblox GUI rebuild of the Figma "Peckwood UI v2" window template (board 8:7, Golden tab 49:10 as the source).
-- Every number here is the Figma layer's own geometry at 1080p (window 500 wide). Do not redraw; change specs instead.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Icons = require(RS:WaitForChild("Peckwood"):WaitForChild("Icons"))

local Kit = {}

local INK = Color3.fromHex("0b0c10")
Kit.INK = INK
local TITLE = Font.fromEnum(Enum.Font.FredokaOne)
local BODY = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
Kit.TITLE, Kit.BODY = TITLE, BODY

local function hex(h) return Color3.fromHex(h) end
Kit.hex = hex

function Kit.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local new = Kit.new

function Kit.frame(parent, x, y, w, h, color, props)
	local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0,
		BackgroundColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = if color then 0 else 1 }, parent)
	if props then for k, v in props do f[k] = v end end
	return f
end
-- Peckwood style is SQUARE (owner 2026-10-07: "the square corners look sweet, we are not using the bubbly style"):
-- every corner in the HUD goes through here and is capped to a crisp 4 px
Kit.CORNER = 4
function Kit.corner(p, r) new("UICorner", { CornerRadius = UDim.new(0, math.min(r, Kit.CORNER)) }, p) end
-- Figma INSIDE stroke: Roblox strokes sit on the border, so inset by half and use the Inner position when available
function Kit.stroke(p, w, color, transp)
	local s = new("UIStroke", { Thickness = w, Color = color or INK, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	pcall(function() s.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
	return s
end
function Kit.textStroke(p, w, color)
	return new("UIStroke", { Thickness = w, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round }, p)
end

-- "c1:0 c2:30 ..." or { {hex, pos, alpha?}, ... } -> UIGradient (vertical by default: Figma [[0,1,0],[-1,0,1]])
function Kit.grad(p, stops, rotation)
	local cs, ts = {}, {}
	for _, st in stops do
		table.insert(cs, ColorSequenceKeypoint.new(st[2], hex(st[1])))
		table.insert(ts, NumberSequenceKeypoint.new(st[2], 1 - (st[3] or 1)))
	end
	if cs[1].Time > 0 then table.insert(cs, 1, ColorSequenceKeypoint.new(0, cs[1].Value)); table.insert(ts, 1, NumberSequenceKeypoint.new(0, ts[1].Value)) end
	if cs[#cs].Time < 1 then table.insert(cs, ColorSequenceKeypoint.new(1, cs[#cs].Value)); table.insert(ts, NumberSequenceKeypoint.new(1, ts[#ts].Value)) end
	return new("UIGradient", { Color = ColorSequence.new(cs), Transparency = NumberSequence.new(ts), Rotation = rotation or 90 }, p)
end
-- parse the compact export format "ffd27a:0 f7a634:30 e07a1c:72 9e4a0c:100" (alpha as "rrggbb@95")
function Kit.stops(str)
	local out = {}
	for tok in string.gmatch(str, "%S+") do
		local c, a, pos = string.match(tok, "^(%x+)@?(%d*):(%d+)$")
		table.insert(out, { c, tonumber(pos) / 100, if a ~= "" then tonumber(a) / 100 else 1 })
	end
	return out
end

function Kit.image(parent, x, y, w, h, id, props)
	local i = new("ImageLabel", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1,
		Image = id or "", ScaleType = Enum.ScaleType.Fit, BorderSizePixel = 0 }, parent)
	if props then for k, v in props do i[k] = v end end
	return i
end
-- missing art never leaves an empty slot: fish/rod/bait ids fall back to their family icon
local FISH_IDS
local FAMILY = { { "^fish_", "fish" }, { "^rod_", "rod" }, { "^shiny_bait_", "bait" }, { "^bait_", "bait" }, { "^hook_", "rod" }, { "^lure_", "bait" }, { "^tank_", "aquarium" } }
function Kit.iconId(name)
	if not name then return "" end
	if Icons[name] then return Icons[name] end
	for _, f in FAMILY do if string.find(name, f[1]) then return Icons[f[2]] or "" end end
	if not FISH_IDS then
		FISH_IDS = {}
		local ok, Defs = pcall(require, RS:WaitForChild("Peckwood"):WaitForChild("Defs"))
		if ok then for _, f in Defs.FISH do FISH_IDS[f.id] = true end end
	end
	if FISH_IDS[name] then return Icons.fish or "" end   -- species art not uploaded yet
	return ""
end
function Kit.icon(parent, x, y, s, name, props)
	return Kit.image(parent, x, y, s, s, Kit.iconId(name), props)
end
-- 9-slice soft image (glow / shadow) spilling `m` px around a box
function Kit.soft(parent, x, y, w, h, m, which, color, transp, z)
	return Kit.image(parent, x - m, y - m, w + 2 * m, h + 2 * m, Icons["ui/" .. which], {
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(128, 128, 128, 128), SliceScale = math.max(0.05, m / 64),
		ImageColor3 = color or Color3.new(1, 1, 1), ImageTransparency = transp or 0, ZIndex = z or 0 })
end
-- texture overlay (halftone / glitter) tiled across a frame
function Kit.texture(parent, which, transp, tile, z)
	return new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Icons["ui/" .. which],
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(tile or 32, tile or 32), ImageTransparency = transp, ZIndex = z or 1 }, parent)
end

-- Figma text. size = Figma font size; Fredoka One renders a hair larger in Roblox, so 0.96.
function Kit.text(parent, str, size, color, props)
	local t = new("TextLabel", { BackgroundTransparency = 1, Text = str, TextSize = math.floor(size * 0.96 + 0.5), FontFace = TITLE,
		TextColor3 = color or Color3.new(1, 1, 1), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }, parent)
	if props then for k, v in props do t[k] = v end end
	return t
end
-- display text: white fill, ink outline, hard ink drop shadow (Figma DS y=dy, r=0)
function Kit.title(parent, str, size, color, strokeW, dy, props)
	local holder = new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0) }, parent)
	if props then for k, v in props do holder[k] = v end end
	local sh
	if dy and dy > 0 then
		sh = Kit.text(holder, str, size, INK, { Position = UDim2.fromOffset(0, dy), ZIndex = (props and props.ZIndex or 1) })
		Kit.textStroke(sh, strokeW or 2, INK)
	end
	local t = Kit.text(holder, str, size, color or Color3.new(1, 1, 1), { ZIndex = (props and props.ZIndex or 1) + 1 })
	Kit.textStroke(t, strokeW or 2, INK)
	holder:SetAttribute("isTitle", true)
	local api = { holder = holder, label = t, shadow = sh }
	function api.set(s) t.Text = s; if sh then sh.Text = s end end
	function api.color(c) t.TextColor3 = c; if t:GetAttribute("NopeBase") then t:SetAttribute("NopeBase", c) end end
	return api
end

function Kit.ellipse(parent, x, y, w, h, color, transp)
	local e = Kit.frame(parent, x, y, w, h, color, { BackgroundTransparency = transp or 0 })
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, e)
	return e
end

local sparkleList = {}
function Kit.sparkle(parent, x, y, s, color)
	local i = Kit.image(parent, x - s * 0.5, y - s * 0.5, s * 2, s * 2, Icons["ui/sparkle"], { ImageColor3 = hex(color or "fff5d8"), ZIndex = 8 })
	table.insert(sparkleList, { i = i, base = s * 2, x = x, y = y, ph = math.random() * 2.4, per = 1.2 + math.random() * 1.2 })
	return i
end
Kit.sparkles = sparkleList

-- glass streak pair (fx/glass streak): wide + thin bands at -35 deg, screen-ish white
function Kit.streaks(parent, x1, w1, x2, w2, y, h)
	for _, b in { { x1, w1 }, { x2, w2 } } do
		local f = Kit.frame(parent, b[1], y, b[2], h, Color3.new(1, 1, 1), { Rotation = -35, ZIndex = 2 })
		Kit.grad(f, { { "ffffff", 0, 0 }, { "fff7d9", 0.5, 0.16 }, { "ffffff", 1, 0 } }, 0)
	end
end

-- ---------------------------------------------------------------- buttons (btn/*)
-- Figma: ink base offset 3 below, face (stroke 3 inside, inner top white), depth band, gloss, bevel, centred content.
local GREY = Kit.stops("5c6676:0 444c59:42 323844:86 323844:100")
local BLUE = Kit.stops("7fd2ff:0 3a9cf0:42 1f6bc4:86 1f6bc4:100")
local GOLD = Kit.stops("ffe07a:0 f2b331:42 c27a10:86 c27a10:100")
Kit.GREY, Kit.BLUE, Kit.GOLD = GREY, BLUE, GOLD

local function darken(c, f) return Color3.new(c.R * f, c.G * f, c.B * f) end

-- Peckwood 3D key button. h = total height. Layers (back to front):
--   glow (lit only) -> ink body (the one outline + the drop under the key) -> lip (darker shade of the face gradient,
--   rounded, shows under and around the bottom corners) -> face (gradient, diagonal stripes, gloss cap) -> content.
-- Press sinks the face into the lip; hover brightens and lifts 1 px. No hairlines anywhere.
local function shadeStops(st, f)
	local out = {}
	for i, s in st do
		local c = hex(s[1])
		out[i] = { string.format("%02x%02x%02x", math.floor(c.R * 255 * f), math.floor(c.G * 255 * f), math.floor(c.B * 255 * f)), s[2], s[3] }
	end
	return out
end
Kit.shadeStops = shadeStops

function Kit.button(parent, x, y, w, h, opts)
	local o = 3                                               -- ink outline
	local d = opts.depth or math.clamp(math.floor(h * 0.13 + 0.5), 4, 8)   -- lip depth
	local cr = opts.cr or math.clamp(math.floor(h * 0.3), 9, 18)
	local fw, fh = w - 2 * o, h - 2 * o - d
	local root = new("TextButton", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, parent)
	local glow = Kit.soft(root, 0, 0, w, h, 18, "glow", Color3.new(1, 1, 1), 1, 2)
	local body = Kit.frame(root, 0, 0, w, h, INK, { ZIndex = 3 }); Kit.corner(body, cr)
	-- lip = the face shape shifted down by the depth, so it only ever shows BELOW the face (never above it when pressed)
	local lip = Kit.frame(root, o, o + d, fw, fh, Color3.new(1, 1, 1), { ZIndex = 4 }); Kit.corner(lip, cr - o)
	local face = Kit.frame(root, o, o, fw, fh, Color3.new(1, 1, 1), { ZIndex = 5 })
	Kit.corner(face, cr - o)
	local stops = opts.stops or GREY
	local g = Kit.grad(face, stops)
	local lg = Kit.grad(lip, shadeStops(stops, 0.58))
	-- stripes (clipped to the face by a CanvasGroup so the rounded corners stay clean)
	-- (a rounded ImageLabel clips its own tiled image: no CanvasGroup, which live clients downsample once too many exist)
	local tex = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Icons["ui/stripes"] or "", ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(32, 32), ImageTransparency = 0.88, ZIndex = 6 }, face)
	Kit.corner(tex, cr - o)
	-- gloss cap: soft white pill on the upper half
	local gh = math.max(6, math.floor(fh * 0.42))
	local gloss = Kit.frame(face, math.max(4, cr * 0.45), 3, fw - 2 * math.max(4, cr * 0.45), gh, Color3.new(1, 1, 1), { ZIndex = 7 })
	Kit.corner(gloss, gh / 2)
	Kit.grad(gloss, { { "ffffff", 0, 0.5 }, { "ffffff", 1, 0.06 } })
	local hl = Kit.frame(face, 0, 0, fw, fh, Color3.new(1, 1, 1), { BackgroundTransparency = 1, ZIndex = 7 }); Kit.corner(hl, cr - o)
	-- content row: icon + label, centred on the face
	local content = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 8 }, face)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, opts.gap or 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	local ico
	if opts.icon then ico = Kit.icon(content, 0, 0, opts.iconSize or math.floor(fh * 0.8), opts.icon, { ZIndex = 9, LayoutOrder = 1 }) end
	local size = opts.size or 20
	local label = Kit.title(content, opts.text or "", size, opts.textColor, opts.strokeW or (if size >= 24 then 2.6 elseif size >= 16 then 2.4 else 1.8), if size >= 16 then 2 else 1.5, { ZIndex = 9, LayoutOrder = 2 })
	label.holder.Visible = (opts.text or "") ~= ""
	-- content always keeps 8 px padding inside the face: shrink to fit when icon + label are too wide
	local csc = new("UIScale", {}, content)
	local function fitContent()
		local fwAbs = face.AbsoluteSize.X
		if fwAbs <= 0 then return end
		local natural = content.AbsoluteSize.X / csc.Scale
		local want = math.min(1, (fwAbs - 16 * fwAbs / fw) / math.max(1, natural))
		if math.abs(want - csc.Scale) > 0.01 then csc.Scale = want end
	end
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitContent)
	face:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitContent)
	local api = { root = root, face = face, grad = g, glowImg = glow, label = label, iconImg = ico, h = h, w = w, state = "", lit = false }
	function api.setStops(st)
		g:Destroy(); g = Kit.grad(face, st); api.grad = g
		lg:Destroy(); lg = Kit.grad(lip, shadeStops(st, 0.58))
	end
	function api.setIcon(name) if ico then ico.Image = Kit.iconId(name) end end
	function api.setText(s) label.set(s); label.holder.Visible = s ~= "" end
	-- look: "lit" (theme stops + optional glow), "grey" (can't afford), "blue" (BUY ALL), "gold" (MAXED)
	function api.look(kind, st, glowColor)
		st = st or opts.litStops or opts.stops
		local key = kind .. tostring(st) .. tostring(glowColor)
		if api.state == key then return end
		api.state = key
		if kind == "grey" then api.setStops(GREY); label.color(hex("cdd3dd")); glow.ImageTransparency = 1
		elseif kind == "blue" then api.setStops(BLUE); label.color(Color3.new(1, 1, 1)); glow.ImageTransparency = 1
		elseif kind == "gold" then api.setStops(GOLD); label.color(Color3.new(1, 1, 1)); glow.ImageTransparency = 1
		else
			if st then api.setStops(st) end
			label.color(Color3.new(1, 1, 1))
			if glowColor then glow.ImageColor3 = hex(glowColor); glow.ImageTransparency = 0.72 else glow.ImageTransparency = 1 end   -- soft halo, not a bloom
		end
		if ico then ico.ImageTransparency = if kind == "grey" then 0.25 else 0 end
		api.lit = kind == "lit" and glowColor ~= nil
	end
	-- motion: hover brighten + lift 1, press sinks into the lip, release springs back
	local scale = new("UIScale", { Scale = 1 }, root)
	local q = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	root.MouseEnter:Connect(function()
		if not opts.silent then Kit.sfx("hover") end
		TweenService:Create(face, q, { Position = UDim2.fromOffset(o, o - 1) }):Play()
		TweenService:Create(hl, q, { BackgroundTransparency = 0.88 }):Play()
	end)
	root.MouseLeave:Connect(function()
		TweenService:Create(face, q, { Position = UDim2.fromOffset(o, o) }):Play()
		TweenService:Create(body, q, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(w, h) }):Play()
		TweenService:Create(hl, q, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(scale, q, { Scale = 1 }):Play()
	end)
	root.MouseButton1Down:Connect(function()
		if not opts.silent then Kit.sfx(opts.sound or "click") end
		-- the whole cap sinks: face and the top of the ink outline go down together, the lip stays put
		TweenService:Create(face, TweenInfo.new(0.06), { Position = UDim2.fromOffset(o, o + d - 1) }):Play()
		TweenService:Create(body, TweenInfo.new(0.06), { Position = UDim2.fromOffset(0, d - 1), Size = UDim2.fromOffset(w, h - d + 1) }):Play()
		-- no squash: a UIScale shrinks toward the top-left anchor (right side pulled in); the cap sinking IS the press
	end)
	root.MouseButton1Up:Connect(function()
		TweenService:Create(face, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(o, o) }):Play()
		TweenService:Create(body, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(w, h) }):Play()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	api.scale = scale
	if opts.stops then api.look("lit", opts.stops) end
	return api
end

-- can't afford: a smooth decaying shake (~0.28 s, RenderStepped) around the button's HOME position, which is captured
-- once, so spamming restarts the shake instead of stacking offsets and walking the button out of place
local RunServiceKit = game:GetService("RunService")
local shaking = {}
function Kit.shake(gui, amp, dur)
	local home = gui:GetAttribute("ShakeHome")
	if not home then home = gui.Position; gui:SetAttribute("ShakeHome", home) end
	if Kit.reduced() then gui.Position = home; return end
	local st = shaking[gui]
	if st then st.t = 0; return end
	st = { t = 0 }; shaking[gui] = st
	st.conn = RunServiceKit.RenderStepped:Connect(function(dt)
		st.t += dt
		local k = st.t / (dur or 0.28)
		if k >= 1 or not gui.Parent then
			gui.Position = home; st.conn:Disconnect(); shaking[gui] = nil; return
		end
		local dx = math.sin(k * math.pi * 6) * (amp or 6) * (1 - k) ^ 1.5
		gui.Position = home + UDim2.fromOffset(dx, 0)
	end)
end
function Kit.nope(api)
	Kit.shake(api.root, 6, 0.28)
	local l = api.label.label
	local c = l:GetAttribute("NopeBase") or l.TextColor3
	l:SetAttribute("NopeBase", c)
	l.TextColor3 = hex("ff4d4d")
	local tw = TweenService:Create(l, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.12), { TextColor3 = c })
	tw:Play()
	tw.Completed:Once(function(state) if state == Enum.PlaybackState.Completed then l:SetAttribute("NopeBase", nil) end end)
end

function Kit.pop(gui, from)
	local s = gui:FindFirstChildOfClass("UIScale") or new("UIScale", {}, gui)
	s.Scale = from or 1.25
	TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- ---------------------------------------------------------------- progress bar (progress)
function Kit.progress(parent, x, y, w, h, fillStops)
	local bg = Kit.frame(parent, x, y, w, h, hex("0f1115"), { ZIndex = 3, ClipsDescendants = true }); Kit.corner(bg, h / 2)
	local inner = Kit.frame(bg, 0, 0, w, 2, Color3.new(0, 0, 0), { BackgroundTransparency = 0.4, ZIndex = 4 })
	local fill = Kit.frame(bg, 0, 0, 0, h, Color3.new(1, 1, 1), { ZIndex = 4 }); Kit.corner(fill, h / 2)
	local fg = Kit.grad(fill, fillStops or Kit.stops("fffbd0:0 f5d06b:50 b28d34:100"))
	local hl = Kit.frame(fill, 2, 1, 0, 2, Color3.new(1, 1, 1), { BackgroundTransparency = 0.55, ZIndex = 5, Size = UDim2.new(1, -4, 0, 2) })
	local lbl = Kit.text(bg, "", 13, Color3.new(1, 1, 1), { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	Kit.textStroke(lbl, 1.6)
	Kit.stroke(bg, 2, INK)
	local api = { bg = bg, fill = fill, label = lbl, frac = -1 }
	function api.set(frac, text)
		frac = math.clamp(frac, 0, 1)
		lbl.Text = text
		if math.abs(frac - api.frac) > 1e-4 then
			api.frac = frac
			TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(if w * frac >= h then w * frac else 0, h) }):Play()   -- no stub knob below one pill width
		end
	end
	function api.setStops(st) fg:Destroy(); fg = Kit.grad(fill, st) end
	return api
end

-- ---------------------------------------------------------------- sound (keycap: crisp plastic attack, cushioned thock)
-- One short dry slice of a real keyboard take, re-pitched per action. Played once per action, never per frame.
local SoundService = game:GetService("SoundService")
local KEY = "rbxassetid://9113869921"   -- Pro Sound Effects "Computer Keyboard 8": first keystroke only
local SFX = {
	click = { speed = 1.0, vol = 0.55, len = 0.1 },
	thock = { speed = 0.78, vol = 0.5, len = 0.12 },    -- buy / confirm: lower, softer
	open = { speed = 0.92, vol = 0.45, len = 0.11 },
	close = { speed = 0.84, vol = 0.4, len = 0.11 },
	hover = { speed = 1.35, vol = 0.07, len = 0.05 },   -- desktop only
	nope = { speed = 0.62, vol = 0.45, len = 0.09 },
}
Kit.muted = false
Kit.uiVolume = 1
local UIS = game:GetService("UserInputService")
local lastPlay = {}
function Kit.sfx(kind)
	local d = SFX[kind]; if not d or Kit.muted then return end
	if kind == "hover" and not UIS.MouseEnabled then return end
	local now = os.clock()
	if lastPlay[kind] and now - lastPlay[kind] < 0.04 then return end
	lastPlay[kind] = now
	local snd = new("Sound", { SoundId = KEY, Volume = d.vol * Kit.uiVolume, PlaybackSpeed = d.speed * (0.97 + math.random() * 0.06) }, SoundService)
	snd:Play()
	task.delay(d.len / d.speed, function() snd:Stop(); snd:Destroy() end)
end
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({ KEY }) end) end)

-- reduced motion: Roblox setting when available
function Kit.reduced()
	local ok, v = pcall(function() return game:GetService("UserGameSettings").ReducedMotion end)
	if ok and v ~= nil then return v end
	ok, v = pcall(function() return game:GetService("GuiService").ReducedMotionEnabled end)
	return ok and v == true
end

return Kit
