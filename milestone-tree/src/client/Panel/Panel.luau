--!strict
--[[
	Panel: the layer panel (DESIGN.md 5, plan 2.4 / 2.5 / 1.12): sheet geometry and lifecycle, the shell (rim, header
	band, emblem, title, sub row, tabs, close), the pinned hero, the body with the Render tab tree, the skeleton and
	the scroll memory.

	    local panel = Panel.new(gui, { store = store, tip = fn? })   -- gui: the PanelGui (Layout.screen, order 20)
	    panel:open(key, node)          key = layer | "options-tab"; the shell draws at once from the map node
	    panel:update(store, changes)   applies changes.tabPatch to the panel's own Render, then header, hero, sections
	    panel:close(); panel:isOpen() -> key?
	    panel:geometry() -> { mode = "side" | "full", sx = abs px of the strip edge?, card = Rect }
	    panel:setBand(on)              COMPACT: the Hud band carries the title and close (the panel then hides its own)
	    panel.content                  the Render tab root (Body.Scroll.TabRoot)
	    panel.render                   the panel's Renderer (skins / claims / hero hooks installed)
	    panel.closeRequested, panel.act (action, hold), panel.detail (card), panel.flyTo (layer), panel.geometryChanged

	Protocol (plan 1.12): the panel never sends ["tab", id] itself: App fires the node's action once and calls open.
	The body shows a skeleton until a patch arrives with patch.tab == key. Every button fires its node's `a` as sent
	(panel.act); the hero CTA fires the prestige-button node's own action. Sounds: a subtab switch plays "tab", the
	close button's hover the hover tick (opening and closing sound in App, which knows why the panel moved).
	When the shown layer or subtab changes, the tab tree is rebuilt from the store, so no skin or claim keeps the
	previous layer's state.
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Sleek = require(Core:WaitForChild("Sleek"))
local Skin = require(Core:WaitForChild("Skin"))
local Layout = require(Core:WaitForChild("Layout"))
local Signal = require(Core:WaitForChild("Signal"))
local Audio = require(Core:WaitForChild("Audio"))
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Render = require(script.Parent.Parent:WaitForChild("Render"))
local Signatures = require(script.Parent.Parent:WaitForChild("Signatures"):WaitForChild("Signatures"))
local Common = require(script.Parent:WaitForChild("Skins"):WaitForChild("Common"))
local Skins = require(script.Parent:WaitForChild("Skins"):WaitForChild("Skins"))
local Sections = require(script.Parent:WaitForChild("Sections"))
local Hero = require(script.Parent:WaitForChild("Hero"))
local Virtual = require(script.Parent:WaitForChild("Virtual"))

type ARect = Types.Rect

local Panel = {}
Panel.__index = Panel

local C = Theme.C
local WHITE = Color3.new(1, 1, 1)

export type Geometry = { mode: string, sx: number?, card: ARect }

export type Panel = typeof(setmetatable({} :: {
	gui: ScreenGui,
	root: Frame,
	store: any,
	render: any,
	content: Frame,
	key: string?,
	node: any,
	layer: string, -- the layer the tab tree currently shows (store.tab)
	sub: string?,
	ready: boolean,
	band: boolean,
	hug: boolean,
	seen: { [string]: boolean },
	scrollMem: { [string]: number },
	restoring: boolean,
	parts: { [string]: any },
	hero: any,
	ctxCache: any,
	geo: Geometry,
	closeRequested: Signal.Signal<>,
	act: Signal.Signal<any, boolean?>,
	detail: Signal.Signal<any>,
	flyTo: Signal.Signal<string>,
	geometryChanged: Signal.Signal<Geometry>,
}, Panel))

-- ------------------------------------------------------------------------------------------------------ helpers
local function frame(parent: Instance, name: string): Frame
	local f = Common.get(parent, name, "Frame") :: Frame
	f.Active = false
	return f
end

-- the current subtab: the text of the "cur" button of the top-level tabs node
local function subOf(store: any): string?
	local root = store:get("tab")
	if type(root) ~= "table" or type(root.c) ~= "table" then return nil end
	for _, cid in root.c do
		local n = store:get(cid)
		if type(n) == "table" and n.t == "tabs" and type(n.c) == "table" then
			for _, tid in n.c do
				local b = store:get(tid)
				if type(b) == "table" and b.cls == "cur" then return Common.plain(b.h) end
			end
		end
	end
	return nil
end

-- every tab.* node of the store, as a full patch (a rebuild for a new layer / subtab)
local function fullTabPatch(store: any): any
	local set = {}
	for id, n in store.nodes do
		if id == "tab" or string.sub(id, 1, 4) == "tab." then set[id] = n end
	end
	return { full = true, set = set, del = {} }
end

-- ------------------------------------------------------------------------------------------------------ build
function Panel.new(gui: ScreenGui, deps: { store: any?, tip: ((html: string?, over: GuiObject?) -> ())?, root: Frame? }): Panel
	local root = deps.root or (gui:FindFirstChild("Root") :: Frame?) or (gui :: any)
	local self = setmetatable({
		gui = gui,
		root = root,
		store = deps.store,
		render = nil :: any,
		content = nil :: any,
		key = nil,
		node = nil,
		layer = "none",
		sub = nil,
		ready = false,
		band = false,
		hug = false,
		seen = {},
		scrollMem = {},
		restoring = false,
		parts = {},
		hero = nil :: any,
		ctxCache = nil,
		geo = { mode = "side", sx = nil, card = { x = 0, y = 0, w = 0, h = 0 } },
		closeRequested = Signal.new() :: Signal.Signal<>,
		act = Signal.new() :: Signal.Signal<any, boolean?>,
		detail = Signal.new() :: Signal.Signal<any>,
		flyTo = Signal.new() :: Signal.Signal<string>,
		geometryChanged = Signal.new() :: Signal.Signal<Geometry>,
	}, Panel)
	self:build()
	local tip = deps.tip or function(_: string?, _o: GuiObject?) end
	self.hero = Hero.new(self.parts.hero, function(a: any, hold: boolean?)
		self.act:Fire(a, hold)
	end)
	self.render = Render.new({ tab = self.content }, {
		press = function(a: any, hold: boolean)
			self.act:Fire(a, hold)
		end,
		tip = tip,
		ctx = function(): any
			return self:ctx()
		end,
		skin = function(rec: any, n: any, ctx: any): boolean
			return Skins.apply(rec, n, ctx)
		end,
		claim = function(id: string, n: any, ctx: any): any
			return self:claimFor(id, n, ctx)
		end,
		store = deps.store,
		detail = function(rec: any)
			if rec.kind == "btn:upg" or rec.kind == "btn:buy" then
				self.detail:Fire({ id = rec.id, kind = rec.kind, node = rec.node, layer = self.layer })
			end
		end,
	})
	Layout.changed:Connect(function()
		self:layout()
		if self.key then self.render:refresh() end
		self:drawHero()
	end)
	local hugQueued = false
	self.content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if not self.hug or self.key == nil or hugQueued then return end
		hugQueued = true
		task.defer(function()
			hugQueued = false
			if self.hug and self.key then self:layout() end
		end)
	end)
	self:layout()
	self:showOpen(false, false)
	return self
end

function Panel.build(self: Panel)
	local root = self.root
	local p = self.parts
	-- the backdrop over the map right of the strip
	local back = frame(root, "Backdrop")
	back.BackgroundColor3 = C.void
	back.BackgroundTransparency = 0.04
	back.ZIndex = 1
	back.Active = true
	local ramp = Common.get(back, "Ramp", "UIGradient") :: UIGradient
	ramp.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.02, 0.04),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	p.back = back
	-- the sheet
	local sheet = frame(root, "Sheet")
	sheet.ZIndex = 2
	sheet.Active = true
	sheet.ClipsDescendants = false
	p.sheet = sheet
	local band = frame(sheet, "HeaderBand")
	band.ZIndex = 2
	p.band = band
	local rule = frame(sheet, "HeaderRule")
	rule.ZIndex = 3
	p.rule = rule
	local emblem = frame(sheet, "Emblem")
	emblem.ZIndex = 6
	p.emblem = emblem
	local sym = Common.get(emblem, "Symbol", "TextLabel") :: TextLabel
	sym.ZIndex = 7
	p.sym = sym
	local title = Common.get(sheet, "Title", "TextLabel") :: TextLabel
	title.ZIndex = 6
	p.title = title
	local subRow = frame(sheet, "SubRow")
	subRow.ZIndex = 6
	p.subRow = subRow
	local tabs = frame(sheet, "Tabs")
	tabs.ZIndex = 6
	p.tabs = tabs
	local readout = frame(sheet, "Readout")
	readout.ZIndex = 6
	p.readout = readout
	local close = Common.get(sheet, "Close", "TextButton") :: TextButton
	close.ZIndex = 20
	close.AutoButtonColor = false
	close.Text = ""
	p.close = close
	close.Activated:Connect(function()
		self.closeRequested:Fire()
	end)
	close.MouseEnter:Connect(function()
		Audio.play("hover")
		Motion.tween(close, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.88 }, "panel:close")
	end)
	close.MouseLeave:Connect(function()
		Motion.tween(close, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.97 }, "panel:close")
	end)
	local hero = frame(sheet, "Hero")
	hero.ZIndex = 5
	p.hero = hero
	local divider = frame(sheet, "Divider")
	divider.ZIndex = 3
	p.divider = divider
	local body = frame(sheet, "Body")
	body.ZIndex = 3
	body.ClipsDescendants = true
	p.body = body
	local scroll = Common.get(body, "Scroll", "ScrollingFrame") :: ScrollingFrame
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 6
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scroll.ZIndex = 3
	scroll.Active = true
	p.scroll = scroll
	local tabRoot = frame(scroll, "TabRoot")
	tabRoot.Size = UDim2.new(1, 0, 0, 0)
	tabRoot.AutomaticSize = Enum.AutomaticSize.Y
	tabRoot.ZIndex = 3
	self.content = tabRoot
	local fade = frame(body, "BottomFade")
	fade.AnchorPoint = Vector2.new(0, 1)
	fade.Position = UDim2.fromScale(0, 1)
	fade.Size = UDim2.new(1, 0, 0, 80)
	fade.ZIndex = 9
	fade.BackgroundTransparency = 0
	fade.Active = false
	p.fade = fade
	local fg = Common.get(fade, "Fade", "UIGradient") :: UIGradient
	fg.Rotation = 90
	fg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if self.key and self.ready and not self.restoring then
			self.scrollMem[self:memKey()] = scroll.CanvasPosition.Y
		end
	end)
end

-- ------------------------------------------------------------------------------------------------------ context
function Panel.memKey(self: Panel): string
	return tostring(self.layer) .. "|" .. tostring(self.sub or "")
end

-- the body's content width in du and the upgrade card width
function Panel.widths(self: Panel): (number, number)
	local compact = Layout.mode == "COMPACT"
	local bodyW = self.parts.body.Size.X.Offset
	if bodyW <= 0 then bodyW = if compact then 580 else 1080 end
	local pad = if compact then 6 + 14 else 16 + 24
	local contentW = math.max(200, bodyW - pad)
	local cardW = if compact then math.max(200, math.floor((contentW - 10) / 2)) else 237
	return contentW, cardW
end

function Panel.ctx(self: Panel): any
	local store = self.store
	local layer = self.layer
	local contentW, cardW = self:widths()
	local ctx: Signatures.Ctx = {
		layer = layer,
		sub = self.sub,
		hue = Theme.hue(layer),
		mode = Layout.mode,
		signature = Signatures.get(layer),
		act = function(a: any, hold: boolean?)
			self.act:Fire(a, hold)
		end,
		store = store,
		render = self.render,
		s = Layout.s,
		contentW = contentW,
		cardW = cardW,
		corrupted = Signatures.corrupted(layer),
		detail = function(card: any)
			self.detail:Fire(card)
		end,
		firstSeen = function(key: string): boolean
			if self.seen[key] then return false end
			self.seen[key] = true
			return true
		end,
		cache = {},
		scroll = self.parts.scroll,
	}
	self.ctxCache = ctx
	return ctx
end

-- the claim hook: header tabs, the signature's claims, the hero, long milestone ladders
local function matches(m: any, id: string, n: any, ctx: any): boolean
	if type(m) ~= "table" or n.cn ~= m.cn then return false end
	if m.ci ~= nil and n.ci ~= m.ci then return false end
	if m.sub ~= nil and ctx.sub ~= m.sub then return false end
	if m.depth ~= nil and Common.depth(id) > m.depth then return false end
	return true
end

function Panel.claimFor(self: Panel, id: string, n: any, ctx: any): any
	if type(n) ~= "table" or ctx == nil then return nil end
	local store = self.store
	if n.t == "tabs" and Common.depth(id) == 1 then
		return function(ph: Frame): any
			return self:tabsClaim(ph, id)
		end
	end
	local sig = ctx.signature
	if sig and type(sig.claims) == "table" then
		for _, rule in sig.claims do
			if matches(rule.match, id, n, ctx) then
				return function(ph: Frame): any
					return rule.make(ph, id, store, ctx)
				end
			end
		end
	end
	if self.hero:wants(id, n) then return self.hero:claim(id, n) end
	if n.cn == "milestones" and #store:kids(id) > Virtual.MS_ROWS then
		return function(ph: Frame): any
			return Virtual.milestones(ph, id, store, ctx)
		end
	end
	return nil
end

-- ------------------------------------------------------------------------------------------------------ header tabs
function Panel.tabsClaim(self: Panel, ph: Frame, id: string): any
	ph.Visible = false
	ph.Size = UDim2.new()
	ph.AutomaticSize = Enum.AutomaticSize.None
	local tabs = self.parts.tabs :: Frame
	local claim = {}
	function claim.update(_: any, store: any)
		self:drawTabs(store, id)
	end
	function claim.destroy(_: any)
		for _, c in tabs:GetChildren() do
			if c:IsA("GuiButton") then c:Destroy() end
		end
		local was = tabs:GetAttribute("Count")
		tabs:SetAttribute("Count", 0)
		if type(was) == "number" and was >= 2 then self:layout() end
	end
	return claim
end

function Panel.drawTabs(self: Panel, store: any, id: string)
	local tabs = self.parts.tabs :: Frame
	local kids = store:kids(id)
	local compact = Layout.mode == "COMPACT"
	local hue = Theme.hue(self.layer)
	local count = 0
	for i, tid in kids do
		local n = store:get(tid)
		if type(n) ~= "table" or n.t ~= "btn" then continue end
		count += 1
		local b = Common.get(tabs, "Tab" .. i, "TextButton") :: TextButton
		b.LayoutOrder = i
		b.AutoButtonColor = false
		b.Text = ""
		b.ZIndex = 7
		b.Size = UDim2.fromOffset(0, if compact then 36 else 46)
		b.AutomaticSize = Enum.AutomaticSize.X
		local active = n.cls == "cur"
		-- Sleek tabs: an index number, the caps word, a count; the active one gets a hue floor and a 2 du hue line
		Common.drop(b, "Corner")
		Common.drop(b, "Border")
		Common.glow(b, nil)
		if active then
			b.BackgroundColor3 = hue
			b.BackgroundTransparency = 0
			local g = Common.get(b, "Fill", "UIGradient") :: UIGradient
			g.Rotation = 90
			g.Color = ColorSequence.new(WHITE)
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.84) })
			local line = Common.get(b, "Line", "Frame") :: Frame
			line.AnchorPoint = Vector2.new(0, 1)
			line.Position = UDim2.fromScale(0, 1)
			line.Size = UDim2.new(1, 0, 0, 2)
			line.BackgroundColor3 = hue
			line.BackgroundTransparency = 0
			line.ZIndex = 9
		else
			Common.drop(b, "Fill")
			Common.drop(b, "Line")
			b.BackgroundTransparency = 1
		end
		-- the index, word and mark sit in a Row (the button also holds the floor line, which a list would lay out)
		Common.drop(b, "Pad")
		Common.drop(b, "List")
		local rowF = Common.get(b, "Row", "Frame") :: Frame
		rowF.AutomaticSize = Enum.AutomaticSize.X
		rowF.Size = UDim2.fromScale(0, 1)
		rowF.ZIndex = 8
		Common.pad(rowF, 0, if compact then 12 else 22, 0, if compact then 12 else 22)
		Common.list(rowF, true, 9, { valign = Enum.VerticalAlignment.Center })
		local idx = Sleek.micro(rowF, "Index", string.format("%02d", count), if active then hue else Sleek.C.micro)
		idx.LayoutOrder = 1
		idx.ZIndex = 8
		idx.Visible = not compact
		Common.drop(b, "Index")
		Common.drop(b, "Label")
		Common.drop(b, "Dot")
		local l = Common.get(rowF, "Label", "TextLabel") :: TextLabel
		l.ZIndex = 8
		l.LayoutOrder = 2
		Common.text(l, "tab", if active then C.text else C.soft)
		l.TextSize = if compact then 14 else 15
		l.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, if active then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
		l.Size = UDim2.new(0, 0, 1, 0)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextYAlignment = Enum.TextYAlignment.Center
		l.TextWrapped = false
		Common.drop(l, "Stroke")
		Common.setText(l, Common.esc(Rich.caps(Common.plain(n.h))))
		-- a notify mark: a small gold diamond after the word
		if n.glow or n.pulse then
			local dot = Common.get(rowF, "Dot", "Frame") :: Frame
			dot.Position = UDim2.new()
			dot.Size = UDim2.fromOffset(7, 7)
			dot.Rotation = 45
			dot.LayoutOrder = 3
			dot.BackgroundColor3 = Sleek.C.gold
			dot.BackgroundTransparency = 0
			dot.ZIndex = 9
			Common.drop(dot, "Corner")
		else
			Common.drop(rowF, "Dot")
		end
		b:SetAttribute("TabId", tid)
		b:SetAttribute("State", if active then "owned" else "can")
		if b:GetAttribute("Wired") ~= true then
			b:SetAttribute("Wired", true)
			b.Activated:Connect(function()
				local t = b:GetAttribute("TabId")
				local node = if type(t) == "string" then self.store:get(t) else nil
				if type(node) == "table" and type(node.a) == "table" and node.cls ~= "cur" then
					Audio.play("tab")
					self.act:Fire(node.a, false)
				end
			end)
		end
	end
	-- drop buttons past the list
	for _, c in tabs:GetChildren() do
		if c:IsA("GuiButton") then
			local i = tonumber(string.match(c.Name, "^Tab(%d+)$"))
			if i == nil or i > #kids then c:Destroy() end
		end
	end
	local was = tabs:GetAttribute("Count")
	tabs:SetAttribute("Count", count)
	-- a single-tab bar (Main only) is hidden; the tab row moves the hero and body, so the sheet re-lays out
	tabs.Visible = count >= 2
	if (type(was) == "number" and was >= 2) ~= (count >= 2) then self:layout() end
end

-- ------------------------------------------------------------------------------------------------------ geometry
function Panel.geometry(self: Panel): Geometry
	return self.geo
end

function Panel.setBand(self: Panel, on: boolean)
	self.band = on
	self:layout()
end

function Panel.layout(self: Panel)
	local p = self.parts
	local root = self.root
	local s = math.max(Layout.s, 0.01)
	local W = root.Size.X.Offset
	local H = root.Size.Y.Offset
	if W <= 0 or H <= 0 then
		W, H = Layout.canvas.X, Layout.canvas.Y
	end
	local mode = Layout.mode
	local key = self.key or self.layer
	local hue = Theme.hue(key)
	local corrupted = Signatures.corrupted(key)
	-- where the device top is in the root's space (D coordinates are screen du from the device top-left)
	local origin = Layout.deviceOrigin()
	local topInset = math.max(0, (root.AbsolutePosition.Y - origin.Y) / s)
	local full = mode == "COMPACT"
	local x, y, w, h = 0, 0, W, H
	if not full then
		if mode == "WIDE" then
			w = math.min(1112, W - 48)
			x = W - 24 - w
			if x - 24 < Layout.STRIP_MIN then full = true end
		else
			w = math.clamp(0.62 * W, 900, 1112)
			w = math.min(w, W - 32)
			x = W - 16 - w
			if W - w - 24 < Layout.STRIP_MIN then full = true end
		end
		y = math.max(8, 70 - topInset)
		h = math.min(994, H - y - 16)
		-- small panels hug their content (DESIGN.md 5.1, the signature's `hug`), never under 560 du
		if self.hug and self.key and self.ready then
			local contentH = self.content.AbsoluteSize.Y / s
			if contentH > 1 then
				local heroOn = self.hero ~= nil and self.hero.visible
				h = math.min(h, math.max(560, 144 + 22 + (if heroOn then 168 else 0) + contentH + 16))
			end
		end
	end
	if full then
		x, y, w, h = 0, 0, W, H
	end
	w, h = math.floor(w), math.floor(h)
	local compact = mode == "COMPACT"
	local sheet = p.sheet :: Frame
	sheet.Position = UDim2.fromOffset(x, y)
	sheet.Size = UDim2.fromOffset(w, h)
	-- the backdrop covers everything right of the strip (the whole screen when full)
	local back = p.back :: Frame
	local bx = if full then 0 else x - 24
	back.Position = UDim2.fromOffset(bx, 0)
	back.Size = UDim2.fromOffset(W - bx, H)
	-- the sheet: a translucent dark slab with a hairline, corner ticks and one lit accent on the top edge (Sleek)
	Common.drop(sheet, "Corner")
	Common.drop(sheet, "Rim")
	Common.glow(sheet, nil)
	Sleek.plate(sheet, { alpha = if corrupted then 0.96 else 0.93, line = if full then 1 else 0.9,
		top = if corrupted then Color3.fromHex("020a03") else nil, bottom = if corrupted then Color3.fromHex("010401") else nil })
	if full then
		Common.drop(sheet, "Ticks")
		Common.drop(sheet, "TopAccent")
	else
		Sleek.ticks(sheet, { len = 22, th = 2, out = 1, color = if corrupted then C.termLime else WHITE, alpha = 0.85, z = 8 })
		Sleek.accent(sheet, hue, 40, 88, { name = "TopAccent" })
	end
	-- the Substance kit's frame under everything (the corrupted layers keep their terminal slab)
	if not corrupted and not full then
		local sk = Skin.apply(sheet, "panel", { scale = 0.6, z = 1 })
		if sk then sk.ImageTransparency = 0.04 end
	else
		Skin.clear(sheet)
	end
	if corrupted then
		local rim = Common.stroke(sheet, 1, C.termLime, 0.35, "Hair")
		Recipes.dashed(rim, { color = C.termLime })
	else
		Common.drop(sheet:FindFirstChild("Hair") or sheet, "Dash")
	end
	-- header: a faint hue haze from the top-left (no band fill)
	local tabsOn = (p.tabs :: Frame):GetAttribute("Count") ~= nil and ((p.tabs :: Frame):GetAttribute("Count") :: number) >= 2
	local titleH = if compact then (if self.band then 0 else 56) else 96
	local headerH = if compact then titleH else titleH + (if tabsOn then 48 else 0)
	local band = p.band :: Frame
	band.Visible = headerH > 0
	band.Position = UDim2.new()
	band.Size = UDim2.new(1, 0, 0, headerH + 60)
	Common.drop(band, "Corner")
	band.BackgroundColor3 = hue
	band.BackgroundTransparency = 0
	local haze = Common.get(band, "Fill", "UIGradient") :: UIGradient
	if Theme.caps.Radial then
		haze.Type = Enum.GradientType.Radial
		haze.Offset = Vector2.new(-0.32, -0.5)
		haze.Rotation = 0
		haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.45, 0.95),
			NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 1) })
	else
		haze.Rotation = 90
		haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1) })
	end
	haze.Color = ColorSequence.new(WHITE)
	-- the tabs row sits on a hairline; registration marks where it meets the sheet's edges
	local rule = p.rule :: Frame
	rule.Visible = headerH > 0 and not compact
	rule.Position = UDim2.fromOffset(40, headerH - 1)
	rule.Size = UDim2.new(1, -80, 0, 1)
	rule.BackgroundColor3 = WHITE
	rule.BackgroundTransparency = Sleek.LINE
	Common.drop(rule, "Fade")
	if not compact and not full and headerH > 0 then
		Sleek.reg(sheet, "RegL", 20, headerH)
		Sleek.reg(sheet, "RegR", w - 20, headerH)
	else
		Common.drop(sheet, "RegL")
		Common.drop(sheet, "RegR")
	end
	-- emblem (a diamond), title, sub row, layer readout, tabs, close
	local emblem = p.emblem :: Frame
	local ed = if compact then 40 else 58
	emblem.Visible = headerH > 0
	emblem.Size = UDim2.fromOffset(ed, ed)
	emblem.Position = if compact then UDim2.fromOffset(10, 8) else UDim2.fromOffset(40, 22)
	Common.drop(emblem, "Corner")
	Common.drop(emblem, "Radial")
	Common.drop(emblem, "Border")
	Common.glow(emblem, nil)
	emblem.BackgroundTransparency = 1
	local dia = Sleek.diamond(emblem, "Diamond", if corrupted then C.termLime else hue, ed)
	dia.Position = UDim2.new()
	dia.ZIndex = 6
	local titleX = if compact then 60 else 120
	local title = p.title :: TextLabel
	title.Visible = headerH > 0
	title.Position = UDim2.fromOffset(titleX, if compact then 8 else 20)
	title.Size = UDim2.new(0, 0, 0, if compact then 32 else 48)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextWrapped = false
	local subRow = p.subRow :: Frame
	subRow.Visible = headerH > 0 and not compact
	subRow.Position = UDim2.fromOffset(titleX + 2, 70)
	subRow.Size = UDim2.new(1, -titleX - 260, 0, 24)
	local readout = p.readout :: Frame
	readout.Visible = headerH > 0 and not compact
	readout.AnchorPoint = Vector2.new(1, 0)
	readout.Position = UDim2.new(1, -100, 0, 28)
	readout.Size = UDim2.fromOffset(140, 40)
	local tabs = p.tabs :: Frame
	if compact then
		tabs.AnchorPoint = Vector2.new(1, 0)
		tabs.Position = UDim2.new(1, -64, 0, 10)
		tabs.Size = UDim2.fromOffset(0, 36)
		tabs.AutomaticSize = Enum.AutomaticSize.X
		Common.list(tabs, true, 4, { align = Enum.HorizontalAlignment.Right, valign = Enum.VerticalAlignment.Center })
	else
		tabs.AnchorPoint = Vector2.new(0, 0)
		tabs.Position = UDim2.fromOffset(40, titleH)
		tabs.Size = UDim2.fromOffset(0, 47)
		tabs.AutomaticSize = Enum.AutomaticSize.X
		Common.list(tabs, true, 0, { align = Enum.HorizontalAlignment.Left, valign = Enum.VerticalAlignment.Bottom })
	end
	local close = p.close :: TextButton
	close.Visible = not (compact and self.band)
	local cs = if compact then 40 else 40
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Size = UDim2.fromOffset(cs, cs)
	close.Position = if compact then UDim2.new(1, -32, 0, 28) else UDim2.new(1, -60, 0, 48)
	Common.drop(close, "Corner")
	Common.drop(close, "Bevel")
	for _, c in close:GetChildren() do
		if c:IsA("UIGradient") or c:IsA("ImageLabel") then c:Destroy() end
	end
	close.BackgroundColor3 = WHITE
	close.BackgroundTransparency = 0.97
	Common.stroke(close, 1, WHITE, 0.78, "Border").LineJoinMode = Enum.LineJoinMode.Miter
	Skin.apply(close, "button", { scale = 0.35 })
	Common.drop(close, "X")
	local cross = Common.get(close, "Cross", "Frame") :: Frame
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.Size = UDim2.fromOffset(16, 16)
	cross.ZIndex = 21
	for i, r in { 45, -45 } do
		local bar = Common.get(cross, "Bar" .. i, "Frame") :: Frame
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(1.2, 0, 0, 2)
		bar.Rotation = r
		bar.BackgroundColor3 = WHITE
		bar.BackgroundTransparency = 0
		bar.ZIndex = 21
	end
	-- hero and body
	local hero = p.hero :: Frame
	local heroOn = self.hero ~= nil and self.hero.visible
	local divider = p.divider :: Frame
	local body = p.body :: Frame
	local top = headerH + (if compact then 8 else 22)
	if compact then
		hero.Position = UDim2.fromOffset(10, top)
		hero.Size = UDim2.fromOffset(226, h - top - 10)
		divider.Visible = false
		local bx0 = if heroOn then 248 else 10
		body.Position = UDim2.fromOffset(bx0, top)
		body.Size = UDim2.fromOffset(w - bx0 - 8, h - top - 8)
	else
		hero.Position = UDim2.fromOffset(40, top)
		hero.Size = UDim2.fromOffset(w - 80, 152)
		divider.Visible = heroOn
		divider.Position = UDim2.fromOffset(40, top + 160)
		divider.Size = UDim2.new(1, -80, 0, 1)
		divider.BackgroundColor3 = WHITE
		divider.BackgroundTransparency = Sleek.LINE
		local by = if heroOn then top + 168 else top
		body.Position = UDim2.fromOffset(16, by)
		body.Size = UDim2.fromOffset(w - 32, h - by - 16)
	end
	-- the body: a styled frame holding the transparent scroll
	-- the body is the sheet itself (no inner card); the corrupted layers keep their terminal green
	Common.drop(body, "Corner")
	if corrupted then
		Common.fill(body, Color3.new(0, 0, 0), Color3.fromHex("062b0a"), Color3.fromHex("041a06"))
		local fill = body:FindFirstChild("Fill") :: UIGradient?
		if fill then fill.Transparency = NumberSequence.new(0.25) end
	else
		Common.drop(body, "Fill")
		body.BackgroundTransparency = 1
	end
	local scroll = p.scroll :: ScrollingFrame
	scroll.ScrollBarImageColor3 = Theme.lift(hue, 0.3)
	Common.pad(self.content, if compact then 10 else 20, if compact then 14 else 24, 90, if compact then 6 else 16, "Pad")
	local fade = p.fade :: Frame
	fade.BackgroundColor3 = if corrupted then Color3.fromHex("031305") else Sleek.C.bottom
	-- abs geometry for App (strip edge, card rect)
	local o = root.AbsolutePosition
	self.geo = {
		mode = if full then "full" else "side",
		sx = if full then nil else o.X + bx * s,
		card = { x = o.X + x * s, y = o.Y + y * s, w = w * s, h = h * s },
	}
	self.geometryChanged:Fire(self.geo)
end

-- ------------------------------------------------------------------------------------------------------ the shell
function Panel.drawShell(self: Panel, accent: boolean?)
	local p = self.parts
	local key = self.key or self.layer
	local node = self.node
	local compact = Layout.mode == "COMPACT"
	local hue = Theme.hue(key)
	-- emblem symbol
	local sym = p.sym :: TextLabel
	sym.Size = UDim2.fromScale(1, 1)
	sym.TextXAlignment = Enum.TextXAlignment.Center
	sym.TextYAlignment = Enum.TextYAlignment.Center
	sym.TextWrapped = false
	local symText = if node and type(node.sym) == "string" then node.sym elseif key == "options-tab" then "OPT" else string.upper(key)
	local symSize = if compact then (if #symText > 2 then 11 else 16) else (if #symText > 2 then 16 else 24)
	local ssig = symText .. "|" .. symSize
	if sym:GetAttribute("Sig") ~= ssig then
		sym:SetAttribute("Sig", ssig)
		Recipes.title(sym, { text = symText, role = "index", size = symSize, stroke = 0, shadow = 0 })
	end
	-- title (step-fit to leave the tabs room)
	local title = p.title :: TextLabel
	local text = string.upper(Signatures.title(key, node))
	local sizes = if compact then { 27, 24, 22 } else { 44, 38, 32 }
	local tsig = text .. "|" .. Theme.toHex(hue) .. "|" .. tostring(compact)
	if title:GetAttribute("Sig") ~= tsig then
		title:SetAttribute("Sig", tsig)
		Recipes.title(title, { text = text, role = "title", size = sizes[1], stroke = 0, shadow = 0 })
	end
	local sheetW = (p.sheet :: Frame).Size.X.Offset
	local tabsW = if compact and (p.tabs :: Frame).Visible then (p.tabs :: Frame).AbsoluteSize.X / math.max(Layout.s, 0.01) else 0
	Rich.fit(title, sizes, math.max(160, sheetW - title.Position.X.Offset - tabsW - (if compact then 90 else 280)))
	-- the sub row: ROW chip + the sentence-case line (the corrupted breadcrumb for cp / cm)
	local subRow = p.subRow :: Frame
	Common.list(subRow, true, 10, { valign = Enum.VerticalAlignment.Center })
	local row = Signatures.row(key)
	if row then
		local chip = Common.chip(subRow, "RowChip", Rich.caps("Row " .. row), { color = Theme.lift(hue, 0.55), bgT = 1, h = 24,
			stroke = hue, role = "caps" })
		chip.LayoutOrder = 1
		local b = chip:FindFirstChild("Border") :: UIStroke?
		if b then
			b.Transparency = 0.4
			b.LineJoinMode = Enum.LineJoinMode.Miter
		end
		Common.drop(chip, "Corner")
	else
		Common.drop(subRow, "RowChip")
	end
	local line = Common.label(subRow, "Line", "small", C.soft, { autoX = true, wrap = false, order = 2 })
	local lineText = if Signatures.corrupted(key) then "C:\\MULTIVERSE\\CORRUPTED>_" else (Signatures.subRow(key) or "")
	if Signatures.corrupted(key) then
		line.FontFace = Theme.font("terminal")
		line.TextColor3 = C.termDim
	end
	Common.setText(line, Common.esc(lineText))
	-- the layer readout: LAYER 02 / 21
	local readout = p.readout :: Frame
	Common.list(readout, false, 7, { align = Enum.HorizontalAlignment.Right, valign = Enum.VerticalAlignment.Center })
	local idx = Sleek.layerIndex(key)
	if idx then
		readout.Visible = not compact
		local cap = Sleek.caps(readout, "Cap", "Layer")
		cap.LayoutOrder = 1
		local num = Common.label(readout, "Num", "number", WHITE, { autoX = true, wrap = false, order = 2 })
		num.RichText = true
		Common.setText(num, string.format('%02d <font color="#6d7686">/ %02d</font>', idx, #Sleek.ORDER))
	else
		readout.Visible = false
	end
	-- the signature's accent
	local sig = Signatures.get(key)
	local hug = sig.hug == true
	if hug ~= self.hug then
		self.hug = hug
		task.defer(function()
			if self.key then self:layout() end
		end)
	end
	if accent then
		-- a signature draws its accent into children named "Accent" (the sheet's, the header band's): the previous
		-- layer's accent goes when another panel opens
		Common.drop(p.sheet, "Accent")
		Common.drop(p.band, "Accent")
		if sig.accent then
			local ok, err = Common.try(sig.accent, p.sheet, self.ctxCache or self:ctx())
			if not ok then warn("[MilestoneTree] signature accent failed: " .. tostring(err)) end
		end
	end
end

function Panel.drawHero(self: Panel)
	if self.store == nil then return end
	local was = self.hero.visible
	local ok, err = pcall(function()
		self.hero:draw(self.store, self.ctxCache or self:ctx())
	end)
	if not ok then warn("[MilestoneTree] hero failed: " .. tostring(err)) end
	if was ~= self.hero.visible then self:layout() end
end

-- ------------------------------------------------------------------------------------------------------ lifecycle
-- the skeleton: 3 shimmer bars until the first patch of the opened layer (built only while it shows)
local function shimmer(self: Panel, on: boolean)
	local body = self.parts.body :: Frame
	if not on then
		Common.drop(body, "Skeleton")
		return
	end
	local sk = frame(body, "Skeleton")
	sk.ZIndex = 8
	sk.Size = UDim2.fromScale(1, 1)
	sk.Visible = true
	Common.pad(sk, 24, 24, 24, 24)
	Common.list(sk, false, 16)
	for i = 1, 3 do
		local bar = frame(sk, "Bar" .. i)
		bar.LayoutOrder = i
		bar.ZIndex = 8
		bar.Size = UDim2.new(if i == 3 then 0.6 else 1, 0, 0, if i == 1 then 36 else 120)
		bar.BackgroundColor3 = C.panel3
		bar.BackgroundTransparency = 0
		Common.corner(bar, 14)
		local g = Common.get(bar, "Shimmer", "UIGradient") :: UIGradient
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.35),
		})
		g.Offset = Vector2.new(-1, 0)
		Motion.tween(g, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) },
			"panel:shimmer" .. i)
	end
end

function Panel.showOpen(self: Panel, on: boolean, animate: boolean)
	local p = self.parts
	local sheet = p.sheet :: Frame
	local back = p.back :: Frame
	sheet.Visible = on
	back.Visible = on
	if on and animate and not Motion.reduced() then
		local target = sheet.Position
		sheet.Position = target + UDim2.fromOffset(if Layout.mode == "COMPACT" then 0 else 60, if Layout.mode == "COMPACT" then 30 else 0)
		Motion.tween(sheet, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }, "panel:slide")
	end
end

function Panel.open(self: Panel, key: string, node: any?)
	local reopen = self.key == key
	self.key = key
	self.node = node
	if not reopen then self.seen = {} end
	local store = self.store
	self.ready = store ~= nil and store.tab == key
	self:layout()
	self:drawShell(true)
	shimmer(self, not self.ready)
	local scroll = self.parts.scroll :: ScrollingFrame
	scroll.Visible = self.ready
	self:showOpen(true, not reopen)
	if self.ready and store then self:sync(store, true) end
end

function Panel.close(self: Panel)
	if self.key == nil then return end
	if self.ready then self.scrollMem[self:memKey()] = (self.parts.scroll :: ScrollingFrame).CanvasPosition.Y end
	self.key = nil
	self.node = nil
	self.ready = false
	shimmer(self, false)
	self:showOpen(false, false)
end

function Panel.isOpen(self: Panel): string?
	return self.key
end

-- the tree shows another layer / subtab: rebuild it from the store (fresh skins and claims), restore the scroll
function Panel.sync(self: Panel, store: any, force: boolean)
	local layer = store.tab
	local sub = subOf(store)
	if not force and layer == self.layer and sub == self.sub then return end
	if self.ready and self.key then self.scrollMem[self:memKey()] = (self.parts.scroll :: ScrollingFrame).CanvasPosition.Y end
	self.layer = layer
	self.sub = sub
	self.hero:reset()
	local ok, err = pcall(function()
		self.render:apply(fullTabPatch(store))
	end)
	if not ok then warn("[MilestoneTree] panel rebuild failed: " .. tostring(err)) end
	self:after(store)
	-- the scroll position of this layer / subtab, once the layout settled
	local scroll = self.parts.scroll :: ScrollingFrame
	local y = self.scrollMem[self:memKey()] or 0
	self.restoring = true
	scroll.CanvasPosition = Vector2.new(0, y)
	task.defer(function()
		scroll.CanvasPosition = Vector2.new(0, y)
		self.restoring = false
	end)
end

-- after a render apply: hero, sections, header
function Panel.after(self: Panel, store: any)
	if self.hero.dirty then self:drawHero() end
	local ctx = self.ctxCache
	if ctx then
		local ok, err = Common.try(Sections.refresh, ctx)
		if not ok then warn("[MilestoneTree] sections failed: " .. tostring(err)) end
	end
	if self.key then self:drawShell() end
end

function Panel.update(self: Panel, store: any, changes: any)
	self.store = store
	self.render.hooks.store = store
	local layerMoved = store.tab ~= self.layer or subOf(store) ~= self.sub
	if layerMoved or (changes and changes.full) then
		self:sync(store, true)
	elseif changes and changes.tab then
		local ok, err = pcall(function()
			self.render:apply(changes.tabPatch)
		end)
		if not ok then
			warn("[MilestoneTree] panel render failed: " .. tostring(err) .. "; rebuilding")
			self:sync(store, true)
		else
			self:after(store)
		end
	end
	-- the body fills when the opened layer's content has arrived (plan 1.12)
	if self.key then
		local ready = store.tab == self.key
		if ready ~= self.ready then
			self.ready = ready
			shimmer(self, not ready)
			local scroll = self.parts.scroll :: ScrollingFrame
			scroll.Visible = ready
		end
	end
end

function Panel.destroy(self: Panel)
	self.hero:destroy()
	self.render:clear()
	for _, name in { "Backdrop", "Sheet" } do Common.drop(self.root, name) end
end

return Panel
