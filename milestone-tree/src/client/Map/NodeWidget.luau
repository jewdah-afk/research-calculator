--!strict
--[[
	NodeWidget: one map node's instance tree (DESIGN.md 3.7, Figma Map Node 4:40). The widget sits in view.nodes at
	its socket in Scale units of the world (x / 3840, y / 2560), so it zooms with the map; below the floor zoom
	(36 / 132 mouse, 44 / 132 touch) its UIScale holds the ring at the floor size.

	    Node_<id>  Frame 200 x 200 world px, centred on the socket          attribute State (test anchor)
	      Floor    UIScale  max(1, k / z)
	      Body     Frame (+ UIScale Hover: 1.08 hover, .94 press)
	        Glow   soft round glow 2 x the ring, hue (alpha .45; .9 pulse / selected)
	        Ring   Frame 132, 135 deg gradient lift / hue / shade
	          Gem  Frame 104, radial gem, Shine ellipse, Symbol (Sarpanch Heavy; the star glyph for ach)
	      Hit      ImageButton over the ring (InputSink None: the map drag still sees the press)
	    lazy, created on first need and then toggled: Rays, Aura, Select, ChalRing (+ chip), Badge, Lock

	Strokes and the symbol size are pixels, so setZoom(z, m) rewrites them when the zoom moves (Nodes calls it).

	    local w = NodeWidget.new(parent, layer, worldPos)
	    w:update(node, state, flags)     state: sealed | frontier | dormant | locked | available | glow | pulse
	    w:setZoom(z, m, floorK)          w:setHover(b)   w:setPress(b)   w:setRays(b)
	    w.frame, w.hit, w.ring, w.state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Theme = require(Core:WaitForChild("Theme"))
local Motion = require(Core:WaitForChild("Motion"))
local Layout = require(Core:WaitForChild("Layout"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))
local NodeAtlas = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("NodeAtlas"))

type MapNode = Types.MapNode

export type Flags = { selected: boolean, challenge: boolean, infected: boolean }
export type NodeWidget = {
	layer: string,
	frame: Frame,
	body: Frame,
	ring: Frame,
	hit: ImageButton,
	state: string,
	flags: Flags,
	update: (self: NodeWidget, node: MapNode?, state: string, flags: Flags) -> (),
	setSelected: (self: NodeWidget, b: boolean) -> (),
	setFloor: (self: NodeWidget, k: number) -> (),
	setZoom: (self: NodeWidget, z: number, m: number, k: number) -> (),
	setRays: (self: NodeWidget, on: boolean) -> (),
	setHover: (self: NodeWidget, on: boolean) -> (),
	setPress: (self: NodeWidget, on: boolean) -> (),
	setPeek: (self: NodeWidget, on: boolean) -> (),
	destroy: (self: NodeWidget) -> (),
}

local NodeWidget = {}

local W = 200 -- the frame, world px
local RING, GEM = 132, 104
local function sc(px: number): number
	return px / W
end

-- symbols of the sockets whose node the view does not send (hidden nodes)
NodeWidget.SYMS = {
	ach = "★", m = "M", mm = "MM", em = "EM", p = "P", pe = "PE", sp = "SP", pb = "PB", pp = "PP", se = "SE", hp = "HP",
	ep = "EP", hb = "HB", ap = "AP", mp = "MP", t = "T", pm = "PM", pep = "PEP", cp = "CR", cm = "CM", ex = "EX",
} :: { [string]: string }

-- the crystal node (art/ui/clean lib.js drawNode, approved): a Blender gem from the node atlas inside an energy ring
-- whose state is a function of time. Without an atlas id the drawn discs below stay.
local ATLAS: string? = NodeAtlas.id
local RING_IMG = RING / (2 * NodeAtlas.ringR) -- the ring sprite's size (world px) that puts its ring on the socket
local CRYSTAL = 128
local LOCK_RING = Color3.fromHex("a39cb3")
local function frac(x: number): number return x - math.floor(x) end
local function hash(i: number): number return frac(math.sin(i * 12.9898 + 78.233) * 43758.5453) end
local function smooth(x: number): number return x * x * (3 - 2 * x) end
-- the CAN BUY flicker: value noise at 13 Hz with occasional dips
local function flicker(t: number): number
	local f = t * 13
	local i = math.floor(f)
	local v = hash(i) + (hash(i + 1) - hash(i)) * smooth(f - i)
	local dip = if hash(math.floor(t * 5.3) + 31) < 0.22 then 0.55 else 1
	return (0.62 + 0.38 * v) * dip
end
NodeWidget.flicker = flicker

local GREY_RING = { Color3.fromHex("898598"), Color3.fromHex("4a4360"), Color3.fromHex("1e1b26") }
local GREY_GEM = Color3.fromHex("3a3352")
local GOLD = Color3.fromHex("ffc233")
local INK = Color3.fromHex("2a1a00")

local function ringGradient(ring: Frame, top: Color3, mid: Color3, bottom: Color3)
	Kit.grad(ring, { top, top, mid, bottom, bottom }, 135, nil, nil, { 0, 0.1, 0.5, 0.9, 1 })
end

function NodeWidget.new(parent: Frame, layer: string, pos: Vector2): NodeWidget
	local f = Kit.frame(parent, "Node_" .. layer)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(pos.X / 3840, pos.Y / 2560)
	f.Size = UDim2.fromScale(W / 3840, W / 2560)
	f:SetAttribute("State", "sealed")
	f:SetAttribute("Layer", layer)
	local floor = Kit.child(f, "Floor", "UIScale") :: UIScale
	floor.Scale = 1

	local body = Kit.frame(f, "Body")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromScale(1, 1)
	local hover = Kit.child(body, "Hover", "UIScale") :: UIScale
	hover.Scale = 1

	local ring = Kit.frame(body, "Ring", 4)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(sc(RING), sc(RING))
	ring.BackgroundColor3 = Color3.new(1, 1, 1)
	ring.BackgroundTransparency = 0
	Kit.corner(ring)
	local rim = Kit.stroke(ring, 1, Color3.new(0, 0, 0), 0.55, "Rim")

	local gem = Kit.frame(ring, "Gem", 5)
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromScale(GEM / RING, GEM / RING)
	local gemStroke = Kit.stroke(gem, 2, Color3.new(0, 0, 0), 1, "GemStroke")

	local shine = Kit.frame(gem, "Shine", 6)
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(0.5, 0.5 - 31 / GEM)
	shine.Size = UDim2.fromScale(60 / GEM, 26 / GEM)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0
	Kit.corner(shine)
	Kit.grad(shine, { Color3.new(1, 1, 1) }, 90, { { 0, 0.55 }, { 1, 0 } })

	local symbol = Kit.label(gem, "Symbol", "index", "", Color3.new(1, 1, 1))
	symbol.AnchorPoint = Vector2.new(0.5, 0.5)
	symbol.Position = UDim2.fromScale(0.5, 0.52)
	symbol.Size = UDim2.fromScale(1, 1)
	symbol.ZIndex = 7
	symbol.TextXAlignment = Enum.TextXAlignment.Center
	symbol.TextYAlignment = Enum.TextYAlignment.Center
	symbol.FontFace = Font.fromName("Sarpanch", Enum.FontWeight.Heavy)
	symbol.LineHeight = 1
	local symStroke = Kit.textStroke(symbol, 3, 1) :: UIStroke

	local hit = Kit.child(f, "Hit", "ImageButton") :: ImageButton
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.fromScale(sc(RING), sc(RING))
	hit.BackgroundTransparency = 1
	hit.ImageTransparency = 1
	hit.Image = ""
	hit.AutoButtonColor = false
	hit.BorderSizePixel = 0
	hit.ZIndex = 20
	hit.Selectable = false
	Kit.corner(hit)
	if Theme.caps.InputSink then
		pcall(function() (hit :: any).InputSink = (Enum :: any).InputSink.None end)
	end

	-- crystal parts (made on first use): Pool (light in the socket), Halo (soft ring), Crystal (the gem), Energy (the
	-- ring's core line), Comet (CAN BUY), Ripple (READY)
	local cr: { [string]: ImageLabel }? = nil
	local crMode = "" -- the ring state the loop animates: locked | idle | buy | ready | "" (off)
	local crHue = Color3.new(1, 1, 1)
	local phase = hash(#layer * 7 + string.byte(layer, 1)) * 6
	local function atlasImage(name: string, key: string, size: number, z: number): ImageLabel
		local im = Kit.child(body, name, "ImageLabel") :: ImageLabel
		im.BackgroundTransparency = 1
		im.BorderSizePixel = 0
		im.Active = false
		im.Image = ATLAS or ""
		im.AnchorPoint = Vector2.new(0.5, 0.5)
		im.Position = UDim2.fromScale(0.5, 0.5)
		im.Size = UDim2.fromScale(sc(size), sc(size))
		im.ZIndex = z
		local r = NodeAtlas.rects[key]
		im.ImageRectOffset = Vector2.new(r[1], r[2])
		im.ImageRectSize = Vector2.new(r[3], r[4])
		return im
	end
	local function crystalParts(): { [string]: ImageLabel }
		local c = cr
		if c then return c end
		local made = {
			Pool = atlasImage("Pool", "disc", 150, 2),
			Halo = atlasImage("Halo", "glow", RING_IMG, 3),
			Crystal = atlasImage("Crystal", layer, CRYSTAL, 5),
			Energy = atlasImage("Energy", "ring", RING_IMG, 6),
			Comet = atlasImage("Comet", "comet", RING_IMG, 7),
			Ripple = atlasImage("Ripple", "ring", RING_IMG, 6),
		}
		cr = made
		-- the ring's life: every state is a function of time (reduced motion holds a still frame)
		Motion.loop(f, function()
			local p = made
			if crMode == "" then return end
			local t = if Motion.reduced() then 1.5 else Motion.now() + phase
			local hue = crHue
			local core, glow, pool = 0.34, 0, 0
			p.Comet.Visible = crMode == "buy"
			p.Ripple.Visible = crMode == "ready"
			if crMode == "locked" then
				core = 0.34
			elseif crMode == "idle" then
				local q = 0.5 + 0.5 * math.sin(t / 3 * math.pi * 2)
				core, glow, pool = 0.62 + 0.28 * q, 0.16 + 0.34 * q, 0.1 + 0.08 * q
			elseif crMode == "buy" then
				local fl = flicker(t)
				core, glow, pool = 0.5 + 0.3 * fl, 0.14 + 0.3 * fl, 0.16 + 0.12 * fl
				p.Comet.Rotation = (t / 1.5) * 360 % 360
				p.Comet.ImageTransparency = 1 - (0.6 + 0.4 * fl)
			else
				local ph = frac(t)
				local q = math.exp(-3.2 * ph)
				core, glow, pool = 0.88 + 0.12 * q, 0.45 + 0.5 * q, 0.28 + 0.3 * q
				local k = 1 + 0.42 * smooth(math.min(1, ph * 1.15))
				p.Ripple.Size = UDim2.fromScale(sc(RING_IMG * k), sc(RING_IMG * k))
				p.Ripple.ImageTransparency = 1 - 0.8 * (1 - ph) ^ 2
			end
			p.Energy.ImageTransparency = 1 - core
			p.Halo.ImageTransparency = 1 - math.min(1, glow)
			p.Pool.ImageTransparency = 1 - pool
			local _ = hue
		end)
		return made
	end
	local function setCrystal(mode: string, hue: Color3, locked: boolean)
		if mode == "" then
			crMode = ""
			local c = cr
			if c then
				for _, im in c do im.Visible = false end
			end
			return
		end
		local p = crystalParts()
		crMode = mode
		crHue = hue
		local key = if locked then layer .. "_locked" else layer
		local r = NodeAtlas.rects[key] or NodeAtlas.rects[layer]
		if r then
			p.Crystal.ImageRectOffset = Vector2.new(r[1], r[2])
			p.Crystal.ImageRectSize = Vector2.new(r[3], r[4])
		end
		p.Crystal.Visible = true
		p.Crystal.ImageTransparency = if mode == "locked" then 0.1 else 0
		p.Energy.Visible = true
		p.Energy.ImageColor3 = if mode == "locked" then LOCK_RING else Theme.lift(hue, if mode == "ready" then 0.7 else 0.4)
		p.Halo.Visible = mode ~= "locked"
		p.Halo.ImageColor3 = hue
		p.Pool.Visible = mode ~= "locked"
		p.Pool.ImageColor3 = hue
		p.Comet.ImageColor3 = Theme.lift(hue, 0.55)
		p.Ripple.ImageColor3 = Theme.lift(hue, 0.55)
		p.Comet.Visible = mode == "buy"
		p.Ripple.Visible = mode == "ready"
		if Motion.reduced() or Motion.snapshot() then
			-- one still frame now (the loop keeps it; snapshots are deterministic)
			p.Energy.ImageTransparency = if mode == "locked" then 0.66 else 0.2
			p.Halo.ImageTransparency = if mode == "ready" then 0.2 else 0.6
		end
	end

	local self = {} :: NodeWidget
	self.layer = layer
	self.frame = f
	self.body = body
	self.ring = ring
	self.hit = hit
	self.state = "sealed"
	self.flags = { selected = false, challenge = false, infected = false }

	-- zoom-dependent pixel sizes
	local pz = 0.5 -- device px per world px (z * m)
	local symSize = 44
	local symText = ""
	local isStar = false
	local compact = Layout.mode == "COMPACT"
	local raysOn = false
	local hovered, pressed, peeked = false, false, false
	local lastSel = false

	-- lazy parts
	local glow: Frame? = nil
	local rays: Frame? = nil
	local aura: Frame? = nil
	local select: Frame? = nil
	local chal: Frame? = nil
	local chalChip: Frame? = nil
	local badge: Frame? = nil
	local badgeKind = ""
	local lock: Frame? = nil

	local function writeZoomed()
		local bd = badge
		if bd then
			local sz = math.max(8, math.floor(math.min((if compact then 22 else 26) * Layout.s, RING * pz * floor.Scale * 0.4) + 0.5))
			bd.Size = UDim2.fromOffset(sz, sz)
		end
		symbol.TextSize = math.clamp(math.floor(symSize * pz + 0.5), 1, 100)
		symStroke.Thickness = math.max(1, 4 * pz * 0.8)
		rim.Thickness = math.max(1, 2 * pz)
		gemStroke.Thickness = math.max(1, 3 * pz)
		local s = select
		if s then
			local st = s:FindFirstChild("Line") :: UIStroke?
			if st then st.Thickness = math.max(1.5, 3.5 * pz) end
		end
		local c = chal
		if c then
			local st = c:FindFirstChild("Line") :: UIStroke?
			if st then st.Thickness = math.max(1.5, 3 * pz) end
		end
	end

	local function setSymbol(text: string, color: Color3, a: number)
		local star = text == "★"
		if star ~= isStar then
			isStar = star
			local g = gem:FindFirstChild("Star")
			if g then g:Destroy() end
		end
		if star then
			symbol.Text = ""
			local g = Kit.glyph(gem, "Star", "star", color)
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
			g.Size = UDim2.fromScale(0.5, 0.5)
			g.ZIndex = 7
			for _, c in g:GetDescendants() do
				if c:IsA("GuiObject") then
					c.ZIndex = 7
					c.BackgroundTransparency = 1 - a
				end
			end
			return
		end
		if text ~= symText then
			symText = text
			local n = utf8.len(text) or #text
			symSize = if n <= 1 then 44 elseif n == 2 then 40.5 else 31.7
			symbol.Text = text
			writeZoomed()
		end
		symbol.TextColor3 = color
		symbol.TextTransparency = 1 - a
		symStroke.Transparency = 1 - a
	end

	local function ensureGlow(): Frame?
		if glow == nil then
			glow = Kit.blob(body, "Glow", Color3.new(1, 1, 1), 1, 1)
			local g = glow
			if g then
				g.AnchorPoint = Vector2.new(0.5, 0.5)
				g.Position = UDim2.fromScale(0.5, 0.5)
				g.Size = UDim2.fromScale(sc(2 * RING), sc(2 * RING))
			end
		end
		return glow
	end
	local function setGlow(c: Color3?, alpha: number)
		if c == nil or alpha <= 0 then
			if glow then (glow :: Frame).Visible = false end
			return
		end
		local g = ensureGlow()
		if g == nil then return end
		g.Visible = true
		g.BackgroundColor3 = c
		g.BackgroundTransparency = 1 - alpha
		local grad = g:FindFirstChild("Radial") :: UIGradient?
		if grad then grad.Color = ColorSequence.new(c) end
	end

	local function setAura(c: Color3?, breathe: boolean)
		if c == nil then
			if aura then
				Kit.still(aura :: Frame);
				(aura :: Frame).Visible = false
			end
			return
		end
		if aura == nil then
			aura = Kit.blob(body, "Aura", c, 0.7, 2)
			local a = aura
			if a then
				a.AnchorPoint = Vector2.new(0.5, 0.5)
				a.Position = UDim2.fromScale(0.5, 0.5)
				a.Size = UDim2.fromScale(sc(220), sc(220))
			end
		end
		local a = aura
		if a == nil then return end
		a.Visible = true
		a.BackgroundColor3 = c
		local grad = a:FindFirstChild("Radial") :: UIGradient?
		if grad then grad.Color = ColorSequence.new(c) end
		if breathe then
			Kit.breathe(a, "BackgroundTransparency", 0, 0.45, 1.2)
		else
			Kit.still(a)
			a.BackgroundTransparency = 0.2
		end
	end

	local function setRaysVisible(c: Color3?)
		if c == nil then
			if rays then
				Kit.unspin(rays :: Frame);
				(rays :: Frame).Visible = false
			end
			return
		end
		if rays == nil then
			local r = Kit.frame(body, "Rays", 1)
			r.AnchorPoint = Vector2.new(0.5, 0.5)
			r.Position = UDim2.fromScale(0.5, 0.5)
			r.Size = UDim2.fromScale(sc(300), sc(300))
			for i = 0, 5 do
				local b = Kit.frame(r, "Ray" .. i)
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.Position = UDim2.fromScale(0.5, 0.5)
				b.Size = UDim2.fromScale(1, 0.07)
				b.Rotation = i * 30
				b.BackgroundColor3 = Color3.new(1, 1, 1)
				b.BackgroundTransparency = 0
				Kit.corner(b)
				Kit.grad(b, { Color3.new(1, 1, 1) }, 0, { { 0, 0 }, { 0.3, 0.3 }, { 0.5, 0.9 }, { 0.7, 0.3 }, { 1, 0 } })
			end
			rays = r
		end
		local r = rays :: Frame
		r.Visible = true
		for _, b in r:GetChildren() do
			if b:IsA("Frame") then
				b.BackgroundColor3 = c
				b.BackgroundTransparency = 0.45
			end
		end
		Kit.spin(r, 12)
	end

	local function dashedRing(name: string, d: number, color: Color3, seconds: number, dir: number): Frame
		local fr = Kit.frame(body, name, 3)
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.Position = UDim2.fromScale(0.5, 0.5)
		fr.Size = UDim2.fromScale(sc(d), sc(d))
		Kit.corner(fr)
		local st = Kit.stroke(fr, 3, color, 1, "Line")
		Recipes.dashed(st, { color = color, alpha = 0.95 })
		Kit.spin(fr, seconds, dir)
		return fr
	end

	local function badgeSize(): number
		-- never more than 40 % of the ring as drawn (a zoomed-out map would otherwise get badges bigger than its gems)
		local ringPx = RING * pz * floor.Scale
		return math.max(8, math.floor(math.min((if compact then 22 else 26) * Layout.s, ringPx * 0.4) + 0.5))
	end
	local function setBadge(kind: string?)
		if kind == nil then
			if badge then (badge :: Frame).Visible = false end
			badgeKind = ""
			return
		end
		if badge == nil then
			local b = Kit.frame(body, "Badge", 9)
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.fromScale(0.5 + 0.72 * sc(RING / 2), 0.5 - 0.72 * sc(RING / 2))
			b.BackgroundTransparency = 0
			Kit.corner(b)
			Kit.stroke(b, 2, Color3.new(1, 1, 1), 1, "Line")
			badge = b
		end
		local b = badge :: Frame
		local size = badgeSize()
		b.Size = UDim2.fromOffset(size, size)
		local line = b:FindFirstChild("Line") :: UIStroke?
		if line then line.Thickness = math.max(1.5, size / 13) end
		if kind ~= badgeKind then
			local fresh = badgeKind == "" or not b.Visible
			badgeKind = kind
			local g: Frame
			if kind == "bolt" then
				b.BackgroundColor3 = GOLD
				Kit.grad(b, { Color3.fromHex("ffe89a"), GOLD, Color3.fromHex("c98a12") }, 90)
				g = Kit.glyph(b, "Icon", "bolt", INK)
			elseif kind == "bang" then
				b.BackgroundColor3 = Theme.C.danger
				Kit.grad(b, { Theme.lift(Theme.C.danger, 0.25), Theme.C.danger, Theme.shade(Theme.C.danger, 0.7) }, 90)
				g = Kit.glyph(b, "Icon", "bang", Color3.new(1, 1, 1))
			else
				b.BackgroundColor3 = Theme.C.panel2
				Kit.grad(b, { Theme.C.panel3, Theme.C.panel2 }, 90)
				g = Kit.glyph(b, "Icon", "moon", Color3.fromHex("c9c3e6"), Theme.C.panel2)
			end
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
			g.Size = UDim2.fromScale(0.62, 0.62)
			b.Visible = true
			if fresh then Motion.pop(b) end
		end
		b.Visible = true
	end

	local function setLock(on: boolean)
		if not on then
			if lock then (lock :: Frame).Visible = false end
			return
		end
		if lock == nil then
			local l = Kit.frame(body, "Lock", 9)
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5 + 0.62 * sc(RING / 2), 0.5 + 0.62 * sc(RING / 2))
			l.BackgroundColor3 = Theme.C.deep
			l.BackgroundTransparency = 0.15
			Kit.corner(l)
			local g = Kit.glyph(l, "Icon", "lock", GOLD, Theme.C.deep)
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
			g.Size = UDim2.fromScale(0.64, 0.64)
			lock = l
		end
		local l = lock :: Frame
		local size = math.floor((if compact then 19 else 22) * Layout.s + 0.5)
		l.Size = UDim2.fromOffset(size, size)
		l.Visible = true
	end

	local function setSelectRing(c: Color3?)
		if c == nil then
			if select then
				Kit.unspin(select :: Frame);
				(select :: Frame).Visible = false
			end
			return
		end
		if select == nil then
			select = dashedRing("Select", 164, c, 20, 1)
		else
			local s = select :: Frame
			s.Visible = true
			local st = s:FindFirstChild("Line") :: UIStroke?
			if st then Recipes.dashed(st, { color = c, alpha = 0.95 }) end
			Kit.spin(s, 20, 1)
		end
		writeZoomed()
	end

	local function setChallenge(id: number?)
		if id == nil then
			if chal then
				Kit.unspin(chal :: Frame);
				(chal :: Frame).Visible = false
			end
			if chalChip then (chalChip :: Frame).Visible = false end
			return
		end
		if chal == nil then
			chal = dashedRing("ChalRing", 150, GOLD, 14, -1)
		else
			(chal :: Frame).Visible = true
			Kit.spin(chal :: Frame, 14, -1)
		end
		local chip, l = Kit.chip(body, "ChalChip", "badge", "C" .. tostring(id), { h = math.floor(22 * Layout.s), pad = 7,
			fg = INK, bg = GOLD, bgA = 1 })
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = UDim2.fromScale(0.5 - 0.7 * sc(RING / 2), 0.5 + 0.7 * sc(RING / 2))
		chip.ZIndex = 9
		l.ZIndex = 9
		l.TextSize = math.floor(Theme.size("badge") * Layout.s + 0.5)
		chip.Visible = true
		chalChip = chip
		writeZoomed()
	end

	local function applyHover()
		local target = if pressed then 0.94 elseif peeked then 1.25 elseif hovered then 1.08 else 1
		local t = if pressed then 0.08 else 0.12
		if Motion.reduced() and target ~= 1 and not pressed then target = 1.04 end
		Motion.tween(hover, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = target }, "nodeHover_" .. layer)
	end

	function self.update(w: NodeWidget, node: MapNode?, state: string, flags: Flags)
		w.state = state
		w.flags = flags
		f:SetAttribute("State", state)
		f:SetAttribute("Selected", flags.selected)
		compact = Layout.mode == "COMPACT"
		local hue = Theme.hue(layer)
		if flags.infected then hue = Theme.C.danger end
		local sym = (node and node.sym) or NodeWidget.SYMS[layer] or string.upper(layer)
		if sym == "" then sym = NodeWidget.SYMS[layer] or "?" end

		local crystalState = if ATLAS == nil then nil
			elseif state == "locked" or state == "dormant" then "locked"
			elseif state == "available" then "idle"
			elseif state == "glow" then "buy"
			elseif state == "pulse" then "ready"
			else nil
		if crystalState then
			-- the crystal node: no drawn disc or letters (the nameplate names it); the ring says the state
			ring.Visible = false
			setCrystal(crystalState, hue, crystalState == "locked")
			setGlow(nil, 0)
			setBadge(if state == "pulse" then "bolt" elseif state == "dormant" then "moon" else nil)
			setLock(false) -- the grey gem and ring say it
			hit.Visible = true
		else
			setCrystal("", hue, false)
		end
		if crystalState then
			-- (drawn below: rays, aura, selection, challenge)
		elseif state == "sealed" or state == "frontier" then
			ring.Visible = true
			ring.BackgroundTransparency = 1
			rim.Transparency = 1
			Kit.gem(gem, Theme.C.deep, { flat = true })
			Kit.grad(gem, { Theme.C.panel2, Theme.C.deep }, 90, nil, "Gem")
			gem.BackgroundTransparency = if state == "frontier" then 0 else 0.3
			gemStroke.Color = if state == "frontier" then Theme.C.strokeHi else Theme.C.stroke
			gemStroke.Transparency = if state == "frontier" then 0 else 0.4
			shine.Visible = false
			if state == "frontier" then
				setSymbol("?", Color3.fromHex("8d86a8"), 1)
			else
				setSymbol("", Color3.new(1, 1, 1), 0)
			end
			setGlow(nil, 0)
			setBadge(nil)
			setLock(false)
			hit.Visible = state == "frontier"
		elseif state == "dormant" then
			ring.Visible = true
			ring.BackgroundTransparency = 0.2
			rim.Transparency = 0.55
			ringGradient(ring, GREY_RING[1], GREY_RING[2], GREY_RING[3])
			Kit.gem(gem, Color3.fromHex("2a2540"), { hi = 0.25, lo = 0.5 })
			gem.BackgroundTransparency = 0.2
			gemStroke.Color = Theme.C.stroke
			gemStroke.Transparency = 0.3
			shine.Visible = false
			setSymbol(sym, Color3.fromHex("5b5572"), 1)
			setGlow(nil, 0)
			setBadge("moon")
			setLock(false)
			hit.Visible = true
		elseif state == "locked" then
			ring.Visible = true
			ring.BackgroundTransparency = 0
			rim.Transparency = 0.45
			ringGradient(ring, GREY_RING[1], GREY_RING[2], GREY_RING[3])
			Kit.gem(gem, GREY_GEM, { hi = 0.18, lo = 0.4 })
			gem.BackgroundTransparency = 0
			gemStroke.Color = Theme.C.panel
			gemStroke.Transparency = 0.2
			shine.Visible = true
			shine.BackgroundTransparency = 0.6
			setSymbol(sym, Theme.C.lockedTitle, 1)
			setGlow(nil, 0)
			setBadge(nil)
			setLock(true)
			hit.Visible = true
		else
			ring.Visible = true
			ring.BackgroundTransparency = 0
			rim.Transparency = 0.5
			ringGradient(ring, Theme.lift(hue, 0.35), hue, Theme.shade(hue, 0.4))
			Kit.gem(gem, hue)
			gem.BackgroundTransparency = 0
			gemStroke.Color = Theme.shade(hue, 0.28)
			gemStroke.Transparency = 0
			shine.Visible = true
			shine.BackgroundTransparency = 0
			setSymbol(sym, Color3.new(1, 1, 1), 1)
			local strong = state == "pulse" or flags.selected
			setGlow(hue, if strong then 0.9 else 0.45)
			setBadge(if state == "pulse" then "bolt" elseif state == "glow" then "bang" else nil)
			setLock(false)
			hit.Visible = true
		end

		local live = state == "available" or state == "glow" or state == "pulse" or state == "locked"
		-- rays: pulse only, and at most 4 at once (Nodes decides through setRays); the crystal ring replaces both
		setRaysVisible(if raysOn and state == "pulse" and not crystalState then hue else nil)
		setAura(if live and not crystalState and (state == "pulse" or flags.selected) then hue else nil, state == "pulse")
		setSelectRing(if flags.selected then Theme.lift(hue, 0.3) else nil)
		setChallenge(if live and node and node.ch then node.ch else nil)
		if flags.selected ~= lastSel then lastSel = flags.selected end
	end

	function self.setSelected(w: NodeWidget, b: boolean)
		local fl = table.clone(w.flags)
		fl.selected = b
		w:update(nil, w.state, fl)
	end
	function self.setFloor(_: NodeWidget, k: number)
		floor.Scale = k
	end
	function self.setZoom(_: NodeWidget, z: number, m: number, k: number)
		pz = z * m
		local fs = math.max(1, k / math.max(z, 1e-3))
		if math.abs(floor.Scale - fs) > 1e-3 then floor.Scale = fs end
		writeZoomed()
	end
	function self.setRays(w: NodeWidget, on: boolean)
		if on == raysOn then return end
		raysOn = on
		local hue = if w.flags.infected then Theme.C.danger else Theme.hue(layer)
		setRaysVisible(if on and w.state == "pulse" and ATLAS == nil then hue else nil)
	end
	function self.setHover(_: NodeWidget, on: boolean)
		if on == hovered then return end
		hovered = on
		applyHover()
	end
	function self.setPress(_: NodeWidget, on: boolean)
		if on == pressed then return end
		pressed = on
		applyHover()
	end
	function self.setPeek(_: NodeWidget, on: boolean)
		if on == peeked then return end
		peeked = on
		applyHover()
	end
	function self.destroy(w: NodeWidget)
		for _, inst in { rays, aura, select, chal } :: { Frame? } do
			if inst then
				Kit.unspin(inst)
				Kit.still(inst)
			end
		end
		w.frame:Destroy()
	end
	writeZoomed()
	return self
end

return NodeWidget
