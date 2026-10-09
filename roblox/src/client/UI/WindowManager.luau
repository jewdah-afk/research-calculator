--!nonstrict
-- WindowManager: opens / closes every window (WindowDefs), builds each Figma variant lazily (or pre-builds it in
-- spare frames after load), switches tabs and in-window views, and calls the live-data binders (UI/Binders) for the
-- visible variant only.
-- Placement follows Birb (UI/Layout): the upgrades drawer is a permanent full-height RIGHT SIDEBAR (open by default,
-- collapse tab on its left edge); every other window opens inside the GAME AREA left of it, never over it, docked
-- where Birb puts it (WindowDefs `dock`: "center" default, "bl" bottom-left, "popup" above the button that opened
-- it), scaled down when it does not fit. One window at a time; opening / closing windows and Esc never touch the
-- sidebar. Motion (UI/Motion): pop out of the HUD button, rows cascade, close shrinks back into the button, tabs
-- crossfade without re-popping, idle loops only on the open window.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Render = require(script.Parent.Figma.Render)
local Layouts = script.Parent.Figma.Layouts
local Defs = require(script.Parent.WindowDefs)
local Sfx = require(script.Parent.Sfx)
local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Motion)

local WM = {}
WM.defs = Defs
WM.built = {}           -- id -> window record
WM.binders = {}         -- id -> { bind(rec, ui, variant), update(rec, ui, variant, s, d) }
WM.screens = nil        -- hand-built screens module (set by Hud)
WM.state, WM.derived = nil, nil
WM.modal = nil          -- id of the open window (game area)
WM.drawerOpen = true    -- the sidebar (mirrors Layout.sidebarOpen)
WM.onChanged = nil      -- fn() when a window opens / closes or the sidebar moves (HUD / camera)
WM.anchors = {}         -- id -> fn() -> design-px point a "popup" window opens above (set by Hud)
WM.sources = {}         -- id -> fn() -> design-px point of the HUD button a window pops out of / shrinks into
WM.beforeOpen = nil     -- fn(id) before a window opens (Hud closes the Robux shop: one window at a time)
WM.onEscape = nil       -- fn() -> true when Esc was used by something else (Robux shop)
WM.onSidebarView = nil  -- fn(variant) when the sidebar shows another view (Hud badges)

local gui, canvas, scale, modalLayer, drawerLayer
local sidebarTab        -- collapse tab ui on the sidebar's left edge
local S = Layout.S

local function label(name)
	local s = string.gsub(name, "^tab/", "")
	s = string.gsub(s, "%s*%b()$", "")
	s = string.gsub(s, "%s+%d+$", "")
	return string.upper(s)
end
WM.tabLabel = label
-- the def tab a tab layer / tab name means: "tab/OWNED 6 (active)", "OWNED 6", "OWNED" and "NIGHT  ·  FLOOR 1" all match
local function tabOf(def, name)
	if not (def.tabs and name) then return nil end
	local full = string.upper((string.gsub(string.gsub(name, "^tab/", ""), "%s*%b()$", "")))
	local short = string.gsub(full, "%s+%d+$", "")
	for _, tb in def.tabs do
		local u = string.upper(tb[1])
		if u == full or tb[2] == name then return tb end
	end
	for _, tb in def.tabs do
		if string.upper(tb[1]) == short then return tb end
	end
	return nil
end
WM.tabOf = tabOf

local function layoutOf(variant)
	local m = Layouts:FindFirstChild(variant)
	assert(m, "no layout " .. tostring(variant))
	return require(m)
end

-- ---------------------------------------------------------------- placement (design px, see UI/Layout)
local SLIDE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local function move(inst, props, animate)
	if animate and not Kit.reduced() then TweenService:Create(inst, SLIDE, props):Play()
	else for k, v in props do inst[k] = v end end
end

-- the sidebar view stretches to the full screen height: the window body, its outline and the upgrade list grow,
-- whatever sits below the list (footer note) moves down. Base sizes live in attributes so this is repeatable.
local function stretch(v, baseH, targetH)
	local node = v.ui.node
	local extra = math.max(0, targetH - baseH)
	local function grow(inst)
		if not inst then return end
		local b = inst:GetAttribute("baseH") or inst.Size.Y.Offset
		inst:SetAttribute("baseH", b)
		inst.Size = UDim2.fromOffset(inst.Size.X.Offset, b + extra)
	end
	local function shift(inst)
		local b = inst:GetAttribute("baseY") or inst.Position.Y.Offset
		inst:SetAttribute("baseY", b)
		inst.Position = UDim2.fromOffset(inst.Position.X.Offset, b + extra)
	end
	grow(v.ui.root); grow(node)
	grow(node:FindFirstChild("window outline"))
	for _, c in v.ui.root:GetChildren() do if c.Name == "shadow" or c.Name == "drop" then grow(c) end end
	local list = node:FindFirstChild("upgrade list")
	if list then
		local listBottom = (list:GetAttribute("baseY") or list.Position.Y.Offset) + (list:GetAttribute("baseH") or list.Size.Y.Offset)
		grow(list)
		local rows = list:FindFirstChild("rows")
		if rows then grow(rows) end
		for _, c in node:GetChildren() do
			if c:IsA("GuiObject") and c ~= list and (c:GetAttribute("baseY") or c.Position.Y.Offset) >= listBottom - 1 then shift(c) end
		end
	end
end

local function placeSidebar(animate)
	local rec = WM.built.shop
	local s = Layout.sidebarScale()
	local fullH = Layout.H / s
	if rec then
		rec.fit.Scale = s
		rec.H = fullH
		rec.holder.AnchorPoint = Vector2.new(0, 0)
		rec.holder.Size = UDim2.fromOffset(rec.W, fullH)
		rec.inner.Size = UDim2.fromOffset(rec.W, fullH)
		local v = rec.current and rec.variants[rec.current]
		if v then stretch(v, rec.baseH, fullH); v.ui.root.Position = UDim2.fromOffset(0, 0) end
		if Layout.sidebarOpen then rec.holder.Visible = true end
		move(rec.holder, { Position = UDim2.fromOffset(if Layout.sidebarOpen then Layout.gameRight() else Layout.W + 8, 0) }, animate)
		if not Layout.sidebarOpen then
			task.delay(if animate then 0.24 else 0, function() if not Layout.sidebarOpen then rec.holder.Visible = false end end)
		end
	end
	if sidebarTab then
		move(sidebarTab.root, { Position = UDim2.new(0, Layout.gameRight(), 0.5, 0) }, animate)
		for _, g in sidebarTab.root:GetDescendants() do
			if g.Name == "glyph/right" then g.Visible = Layout.sidebarOpen elseif g.Name == "glyph/left" then g.Visible = not Layout.sidebarOpen end
		end
	end
end

local function fitWindow(rec)
	if not rec or not rec.holder or rec.def.drawer then return end
	-- windows scale into the window region (game area minus the HUD bands): the banner, the wallet column and the
	-- bottom row always stay visible (Birb keeps its currency stack in view); the popup list keeps its own size
	local x0, y0, x1, y1 = Layout.windowRegion()
	local s = if rec.def.dock == "popup" then math.min(1, (Layout.H - 2 * S.WIN) / rec.H) else math.min(1, (y1 - y0) / rec.H, (x1 - x0) / rec.W)
	rec.fit.Scale = math.max(0.3, s)
end
-- where a window sits in the window region (Birb anchors)
local function placeWindow(rec, animate)
	if not rec or rec.def.drawer then return end
	fitWindow(rec)
	local s = rec.fit.Scale
	local dock = rec.def.dock or "center"
	local x0, y0, x1, y1 = Layout.windowRegion()
	if dock == "bl" then
		rec.holder.AnchorPoint = Vector2.new(0, 1)
		move(rec.holder, { Position = UDim2.fromOffset(x0, y1) }, animate)
	elseif dock == "popup" and WM.anchors[rec.id] then
		-- a small list right above the HUD key that opened it, kept inside the game area
		local p = WM.anchors[rec.id]()
		local w, h = rec.W * s, rec.H * s
		local x = math.clamp(p.X, S.WIN + w / 2, Layout.gameRight() - S.TAB_W - S.GAP - w / 2)
		local y = math.max(p.Y - S.GAP, S.WIN + h)
		rec.holder.AnchorPoint = Vector2.new(0.5, 1)
		move(rec.holder, { Position = UDim2.fromOffset(x, y) }, animate)
	else
		rec.holder.AnchorPoint = Vector2.new(0.5, 0.5)
		move(rec.holder, { Position = UDim2.fromOffset((x0 + x1) / 2, (y0 + y1) / 2) }, animate)
	end
end
WM.placeWindow = placeWindow

local function layout()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.max(0.35, vp.Y / 1080)
	scale.Scale = s
	canvas.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
	Layout.setCanvas(vp.X / s, vp.Y / s)
end
local function reflow(animate)
	placeSidebar(animate)
	for _, rec in WM.built do
		if rec.holder.Visible then placeWindow(rec, animate) else fitWindow(rec) end
	end
	if WM.onChanged then WM.onChanged() end
end

-- ---------------------------------------------------------------- idle motion: only on the open window
local function idleStart(rec)
	local v = rec.current and rec.variants[rec.current]
	if not v or rec.def.drawer then return end
	if v.idleStop then return end
	v.idleStop = Motion.idle(v.ui.root, v.ui.root:FindFirstChild("header", true))
end
local function idleStop(rec)
	for _, v in rec.variants do
		if v.idleStop then v.idleStop(); v.idleStop = nil end
	end
end

-- ---------------------------------------------------------------- building
local function topLeftOf(inst) return Motion.topLeft(inst) end
local function activeTab(root)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") and string.match(d.Name, "^tab/.*%(active%)$") then return d end
	end
	return nil
end
local function tabIndex(def, variant)
	for i, tb in def.tabs or {} do if tb[2] == variant then return i end end
	return 0
end

local function wireVariant(rec, name, ui)
	local def = rec.def
	ui.on("btn/close", function()
		if def.drawer then WM.setDrawer(false) else WM.close() end
	end)
	-- tabs: every tab/* layer (key or plain) switches to its variant / window
	ui.onAny(function(nodeName)
		if string.sub(nodeName, 1, 4) == "tab/" then
			local tb = tabOf(def, nodeName)
			if not tb then warn("[UI] tab layer with no tab def:", rec.id, nodeName); return end
			if tb.go then
				if tb.go ~= rec.id then Sfx.tab(); WM.open(tb.go) end
			elseif tb[2] and tb[2] ~= rec.current then
				Sfx.tab(); WM.show(rec, tb[2], true)
			end
		elseif def.views and def.views[nodeName] then
			local target = def.views[nodeName]
			if target ~= rec.current then Sfx.tab(); WM.show(rec, target, true) end
		end
	end)
	-- selection: clicking a row / card / node moves the white selected ring onto it (when the panel has one)
	ui.onAny(function(_, inst)
		local ring = inst.Parent and inst.Parent:FindFirstChild("selected ring")
		if ring and ring ~= inst then
			local d = ring:GetAttribute("inset") or 4
			local tl = topLeftOf(inst)
			local home = inst:GetAttribute("homePos")
			if home then tl = Vector2.new(home.X.Offset - inst.AnchorPoint.X * inst.Size.X.Offset, home.Y.Offset - inst.AnchorPoint.Y * inst.Size.Y.Offset) end
			TweenService:Create(ring, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
				Position = UDim2.fromOffset(tl.X - d + ring.AnchorPoint.X * (inst.Size.X.Offset + 2 * d), tl.Y - d + ring.AnchorPoint.Y * (inst.Size.Y.Offset + 2 * d)),
				Size = inst.Size + UDim2.fromOffset(2 * d, 2 * d) }):Play()
		end
	end)
end

-- a variant whose tab carries its own title / header theme (one Figma frame reused for several tabs)
function WM.retitle(ui, title, theme)
	local header = ui.node:FindFirstChild("header")
	if not header then return end
	if title then
		for _, l in header:GetChildren() do
			if l:IsA("TextLabel") and not string.find(l.Name, "  %(drop%)$") then
				local sh = Render.SHADOW[l]
				for _, t in { l, sh } do
					if t then
						t.Position = UDim2.fromOffset(0, t.Position.Y.Offset); t.Size = UDim2.fromOffset(header.Size.X.Offset, t.Size.Y.Offset)
						t.TextXAlignment = Enum.TextXAlignment.Center
					end
				end
				Render.setText(l, title)
			end
		end
	end
	local FKit = require(script.Parent.Figma.FKit)
	local th = theme and FKit.THEME[theme]
	if th then
		local function regrad(f, layer)
			if not f then return end
			for _, g in f:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
			f.BackgroundColor3 = Color3.new(1, 1, 1); f.BackgroundTransparency = 0
			Render.gradient(f, layer, 1)
		end
		regrad(header, { "g", 20, { { 0, th[1], 1 }, { 0.11, th[1], 1 }, { 0.5, th[2], 1 }, { 0.89, th[3], 1 }, { 1, th[3], 1 } } })
		regrad(header:FindFirstChild("glow"), { "g", 90, { { 0, th[2], 0 }, { 1, th[2], 0.55 } } })
	end
end

local function buildVariant(rec, name)
	local v = rec.variants[name]
	if v then return v end
	local L = layoutOf(name)
	if rec.variants[name] then return rec.variants[name] end   -- built meanwhile (a require can yield)
	local ui = Render.build(L, rec.inner)
	ui.root.Visible = false
	rec.builds = (rec.builds or 0) + 1
	-- rows / cards / plain list entries become clickable (selection) and answer hover without changing their look
	for _, d in ui.root:GetDescendants() do
		local nm = d.Name
		if d:IsA("Frame") and (string.sub(nm, 1, 4) == "row/" or string.sub(nm, 1, 5) == "card/" or string.sub(nm, 1, 5) == "cell/") and not d:FindFirstChild("hit") then
			-- under the row's own content (z 1): keys inside the row keep their clicks
			Motion.key(d, if string.sub(nm, 1, 5) == "cell/" then "cell" else "row", { z = 1,
				onActivate = function()
					Sfx.rowSelect()
					for _, fn in ui.anyHandlers do task.spawn(fn, nm, d) end
				end })
		end
		if nm == "selected ring" and d:IsA("GuiObject") then
			-- measure the ring's inset around the element it wraps in Figma, so moving it keeps the same gap
			for _, sib in d.Parent:GetChildren() do
				if sib ~= d and sib:IsA("GuiObject") then
					local a, b = topLeftOf(sib), topLeftOf(d)
					local dp = a.X - b.X
					if dp >= 2 and dp <= 8 and math.abs(a.Y - b.Y - dp) < 0.6 and math.abs(sib.Size.X.Offset + 2 * dp - d.Size.X.Offset) < 0.6 then
						d:SetAttribute("inset", dp)
					end
				end
			end
		end
	end
	v = { ui = ui, name = name }
	rec.variants[name] = v
	for _, tb in rec.def.tabs or {} do
		if tb[2] == name and (tb.title or tb.theme) then WM.retitle(ui, tb.title, tb.theme) end
	end
	wireVariant(rec, name, ui)
	local b = WM.binders[rec.id]
	if b and b.bind then b.bind(rec, ui, name) end
	return v
end

local function buildWindow(id)
	local def = Defs[id]
	assert(def, "unknown window " .. tostring(id))
	local rec = { id = id, def = def, variants = {}, current = nil, builds = 0, popCount = 0 }
	local W, H
	if def.build then
		W, H = 1000, 860
	else
		local L = layoutOf(def.tabs[1][2])
		W, H = L.root.w, L.root.h
		for _, tb in def.tabs do
			if tb[2] then local l2 = layoutOf(tb[2]); W = math.max(W, l2.root.w); H = math.max(H, l2.root.h) end
		end
	end
	rec.W, rec.H, rec.baseH = W, H, H
	local parent = if def.drawer then drawerLayer else modalLayer
	rec.holder = Render.new("Frame", { Name = id, BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Visible = false, ZIndex = 2,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }, parent)
	rec.fit = Render.new("UIScale", { Name = "Fit" }, rec.holder)
	-- clicks on the window's empty areas stop here (never reach the world behind)
	Render.new("TextButton", { Name = "blocker", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, rec.holder)
	rec.inner = Render.new("Frame", { Name = "inner", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ZIndex = 2 }, rec.holder)
	rec.pop = Render.new("UIScale", { Name = "Pop" }, rec.inner)
	rec.canvasScale = function() return scale.Scale end
	if def.build then
		local ui, w, h = WM.screens.build(id, rec.inner, rec)
		rec.W, rec.H, rec.baseH = w, h, h
		rec.holder.Size = UDim2.fromOffset(w, h); rec.inner.Size = UDim2.fromOffset(w, h)
		rec.variants.main = { ui = ui, name = "main" }
		rec.builds = 1
		wireVariant(rec, "main", ui)
		ui.root.Visible = false
	end
	WM.built[id] = rec
	if def.drawer then
		rec.inner.AnchorPoint = Vector2.new(0, 0); rec.inner.Position = UDim2.fromOffset(0, 0)
	end
	fitWindow(rec)
	return rec
end

-- show one variant of a window. `switch` = a tab / view change inside an open window: no re-pop, the old content
-- fades out while the new fades in with an 8 px slide toward the tab, the active tab pill springs, rows cascade.
function WM.show(rec, name, switch)
	local v = if rec.def.build then rec.variants.main else buildVariant(rec, name)
	local old = rec.current and rec.variants[rec.current]
	if rec.transition then rec.transition(); rec.transition = nil end
	local animate = switch and old and old ~= v and old.ui.root.Visible and rec.holder.Visible
	local oldTab = animate and activeTab(old.ui.root)
	local oldTabPos = oldTab and oldTab.Position
	local dir = if animate and tabIndex(rec.def, v.name) < tabIndex(rec.def, old.name) then -1 else 1
	if old and old ~= v then
		if old.idleStop then old.idleStop(); old.idleStop = nil end
	end
	rec.current = v.name
	local r = v.ui.root
	if rec.def.drawer then
		placeSidebar(false)
	else
		r.Position = UDim2.fromOffset((rec.W - r.Size.X.Offset) / 2, (rec.H - r.Size.Y.Offset) / 2)
	end
	if animate then
		r.Visible = true
		rec.transition = Motion.crossfade(old.ui.root, r, dir, function() rec.transition = nil end)
		Motion.springTab(activeTab(r), oldTabPos)
		Motion.cascade(r, dir)
	else
		for _, vv in rec.variants do vv.ui.root.Visible = vv == v end
	end
	if rec.holder.Visible and WM.modal == rec.id then idleStart(rec) end
	local b = WM.binders[rec.id]
	if b and b.update and WM.state then b.update(rec, v.ui, v.name, WM.state, WM.derived) end
	if rec.def.drawer and WM.onSidebarView then WM.onSidebarView(v) end
end

function WM.isOpen(id)
	local rec = WM.built[id]
	return rec ~= nil and rec.holder.Visible
end

local function sourcePoint(id)
	local f = WM.sources[id]
	return if f then f() else nil
end

-- open a window (optionally on a given tab label or variant name)
function WM.open(id, tab)
	if not Defs[id] then warn("[UI] unknown window", id); return end
	local rec = WM.built[id] or buildWindow(id)
	local def = rec.def
	local target = rec.current
	if tab then
		local tb = tabOf(def, tab)
		if tb and tb[2] then target = tb[2] end
		if def.views and def.views[tab] then target = def.views[tab] end
	end
	target = target or (def.tabs and def.tabs[1][2]) or "main"
	if def.build then target = "main" end
	if def.drawer then
		WM.show(rec, target, rec.current ~= nil and target ~= rec.current)
		if not Layout.sidebarOpen then WM.setDrawer(true) end
		return rec
	end
	if WM.beforeOpen then WM.beforeOpen(id) end
	-- one window at a time (never the sidebar)
	if WM.modal and WM.modal ~= id then
		local old = WM.built[WM.modal]
		if old then
			idleStop(old)
			if old.closing then old.closing() end
			old.holder.Visible = false
		end
	end
	local wasOpen = WM.modal == id and rec.holder.Visible
	WM.modal = id
	WM.show(rec, target, wasOpen)
	placeWindow(rec, false)
	rec.holder.Visible = true
	if not wasOpen then
		Sfx.open()
		local v = rec.variants[rec.current]
		Motion.open(rec, sourcePoint(id), v and v.ui.root)
	end
	idleStart(rec)
	if WM.onChanged then WM.onChanged() end
	return rec
end

function WM.close()
	local id = WM.modal
	if not id then return end
	local rec = WM.built[id]
	WM.modal = nil
	Sfx.close()
	if rec then
		idleStop(rec)
		local v = rec.current and rec.variants[rec.current]
		local pt = sourcePoint(id)
		Motion.close(rec, pt, v and v.ui.root, function()
			if WM.modal ~= id then rec.holder.Visible = false end
		end, canvas, pt)
	end
	if WM.onChanged then WM.onChanged() end
end

function WM.toggle(id, tab)
	if WM.modal == id then WM.close() else WM.open(id, tab) end
end

-- the upgrades sidebar: slides away to the right edge (collapse tab stays) and back; never closed by windows / Esc
function WM.setDrawer(on)
	if not WM.built.shop then buildWindow("shop") end
	local rec = WM.built.shop
	if not rec.current then WM.show(rec, rec.def.tabs[1][2]) end
	if on == Layout.sidebarOpen then placeSidebar(false); return end
	WM.drawerOpen = on
	if on then Sfx.open() else Sfx.close() end
	Layout.setSidebar(on)   -- fires reflow: sidebar slide, windows + HUD re-anchor
end

-- live data: called on every server state push; only the visible variant of an open window is refreshed
function WM.update(s, d)
	WM.state, WM.derived = s, d
	for id, rec in WM.built do
		if rec.holder.Visible and rec.current then
			local b = WM.binders[id]
			local v = rec.variants[rec.current]
			if b and b.update and v then b.update(rec, v.ui, v.name, s, d) end
		end
	end
end

-- first open never hitches: after load, build the first view of each unlocked window, one per few frames
function WM.prebuild(ids)
	task.spawn(function()
		task.wait(3)
		for _, id in ids do
			if not WM.built[id] then
				local ok = pcall(function()
					local rec = buildWindow(id)
					if not rec.def.build then buildVariant(rec, rec.def.tabs[1][2]) end
				end)
				if not ok then warn("[UI] prebuild failed", id) end
				for _ = 1, 3 do task.wait() end
			end
		end
	end)
end

function WM.init(parentGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "PeckwoodWindows"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.DisplayOrder = 20
	gui.Parent = parentGui
	canvas = Render.new("Frame", { Name = "canvas", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080) }, gui)
	scale = Render.new("UIScale", {}, canvas)
	WM.canvas = canvas
	-- no dimming backdrop (Birb): the game keeps running and the sidebar stays usable while a window is open
	modalLayer = Render.new("Frame", { Name = "windows", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, canvas)
	drawerLayer = Render.new("Frame", { Name = "sidebar", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, canvas)
	-- collapse tab (Birb: a small tab on the sidebar's left edge at mid-height): steel kit key, right / left glyph
	do
		local FKit = require(script.Parent.Figma.FKit)
		local L = FKit.layout()
		local k = FKit.KEYn(L, "btn/sidebar", 0, 0, S.TAB_W, S.TAB_H, FKit.PAL.steel, { d = 4, gloss = 0.2 })
		local face = k.k[3]
		local g = 14
		table.insert(face.k, FKit.node("G", "glyph/right", (face.w - g) / 2, (face.h - g) / 2, g, g, { kind = "right", col = "ffffff", ink = 5.5, lw = 2.6 }))
		table.insert(face.k, FKit.node("G", "glyph/left", (face.w - g) / 2, (face.h - g) / 2, g, g, { kind = "left", col = "ffffff", ink = 5.5, lw = 2.6 }))
		sidebarTab = FKit.build(L, k, drawerLayer)
		sidebarTab.root.AnchorPoint = Vector2.new(1, 0.5)
		sidebarTab.root.ZIndex = 4
		sidebarTab.on("btn/sidebar", function() WM.setDrawer(not Layout.sidebarOpen) end)
	end
	Layout.onChanged(reflow)
	Layout.onRegion(function()
		for _, rec in WM.built do
			if rec.holder.Visible and not rec.def.drawer then placeWindow(rec, false) else fitWindow(rec) end
		end
	end)
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	UIS.InputBegan:Connect(function(io, gp)
		if gp then return end
		if io.KeyCode == Enum.KeyCode.Escape or io.KeyCode == Enum.KeyCode.ButtonB then
			-- Esc / gamepad B closes the open window; the sidebar is never closed by it
			if WM.onEscape and WM.onEscape() then return end
			if WM.modal then WM.close() end
		end
	end)
	-- the sidebar is open from the start on the EGGS view
	WM.open("shop")
	reflow(false)
	return canvas
end
WM.layout = layout

-- debug / QA: PlayerGui:SetAttribute("PeckwoodOpen", "<window id>[:<tab>]") opens a window without clicking
function WM.debugHook()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	pg:GetAttributeChangedSignal("PeckwoodOpen"):Connect(function()
		local v = pg:GetAttribute("PeckwoodOpen")
		if typeof(v) ~= "string" or v == "" then WM.close(); return end
		local id, tab = string.match(v, "^([^:]+):?(.*)$")
		WM.open(id, if tab ~= "" then tab else nil)
	end)
	pg:GetAttributeChangedSignal("PeckwoodSidebar"):Connect(function()
		WM.setDrawer(pg:GetAttribute("PeckwoodSidebar") ~= false)
	end)
end

return WM
