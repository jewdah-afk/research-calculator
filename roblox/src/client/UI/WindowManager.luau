--!nonstrict
-- WindowManager: opens / closes every window (WindowDefs), builds each Figma variant lazily on first view, switches
-- tabs and in-window views, runs the shared motion (pop-in 0.86 -> 1.04 -> 1, close = quick shrink, drawer slides
-- from the right) and calls the live-data binders (UI/Binders.luau) for the visible variant only.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Render = require(script.Parent.Figma.Render)
local Layouts = script.Parent.Figma.Layouts
local Defs = require(script.Parent.WindowDefs)
local Sfx = require(script.Parent.Sfx)
local Kit = require(script.Parent.Kit)

local WM = {}
WM.defs = Defs
WM.built = {}           -- id -> window record
WM.binders = {}         -- id -> { bind(rec, ui, variant), update(rec, ui, variant, s, d) }
WM.screens = nil        -- hand-built screens module (set by Hud)
WM.state, WM.derived = nil, nil
WM.modal = nil          -- id of the open centred window
WM.drawerOpen = false
WM.onChanged = nil      -- fn() when a window opens/closes (HUD dims / camera)

local gui, canvas, scale, backdrop, modalLayer, drawerLayer
local RAIL_W = 116      -- the area rail + its margin on the right edge stay clear of the drawer

local function label(name)
	local s = string.gsub(name, "^tab/", "")
	s = string.gsub(s, "%s*%b()$", "")
	s = string.gsub(s, "%s+%d+$", "")
	return string.upper(s)
end
WM.tabLabel = label

local function layoutOf(variant)
	local m = Layouts:FindFirstChild(variant)
	assert(m, "no layout " .. tostring(variant))
	return require(m)
end

-- ---------------------------------------------------------------- canvas (1920x1080 design space, fit to height)
local function fitWindow(rec)
	if not rec or not rec.holder then return end
	local vp = canvas.AbsoluteSize / math.max(0.01, scale.Scale)
	local W, H = rec.W, rec.H
	local availW = if rec.def.drawer then vp.X - RAIL_W - 24 else vp.X - 48
	local s = math.min(1, (vp.Y - 32) / H, availW / W)
	rec.fit.Scale = math.max(0.3, s)
end
local function layout()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.max(0.35, vp.Y / 1080)
	scale.Scale = s
	canvas.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
	for _, rec in WM.built do fitWindow(rec) end
end

function WM.init(parentGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "PeckwoodWindows"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.DisplayOrder = 20
	gui.Parent = parentGui
	canvas = Render.new("Frame", { Name = "canvas", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080) }, gui)
	scale = Render.new("UIScale", {}, canvas)
	backdrop = Render.new("TextButton", { Name = "backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("06070c"),
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 1 }, canvas)
	backdrop.Activated:Connect(function() WM.close() end)
	modalLayer = Render.new("Frame", { Name = "modal", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, canvas)
	drawerLayer = Render.new("Frame", { Name = "drawer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, canvas)
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	UIS.InputBegan:Connect(function(io, gp)
		if gp then return end
		if io.KeyCode == Enum.KeyCode.Escape or io.KeyCode == Enum.KeyCode.ButtonB then
			if WM.modal then WM.close() elseif WM.drawerOpen then WM.setDrawer(false) end
		end
	end)
	-- idle twinkle for sparkles outside CanvasGroups (a handful per open window; skipped with reduced motion)
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		if Kit.reduced() then return end
		for _, rec in WM.built do
			local v = rec.holder and rec.holder.Visible and rec.variants[rec.current]
			if v then
				for i, sp in v.twinkle do
					local k = 0.75 + 0.25 * math.sin(t * 2.6 + i * 1.7)
					sp.Size = UDim2.fromOffset(v.twinkleBase[i] * k, v.twinkleBase[i] * k)
					sp.Rotation = math.sin(t * 0.8 + i) * 12
				end
			end
		end
	end)
	return canvas
end
WM.layout = layout

-- ---------------------------------------------------------------- building
local function wireVariant(rec, name, ui)
	local def = rec.def
	-- close key
	ui.on("btn/close", function()
		if def.drawer then WM.setDrawer(false) else WM.close() end
	end)
	-- tabs: every tab/* layer (key or plain) switches to its variant / window
	ui.onAny(function(nodeName, inst)
		if string.sub(nodeName, 1, 4) == "tab/" then
			local lab = label(nodeName)
			for _, tb in def.tabs or {} do
				if string.upper(tb[1]) == lab then
					if tb.go then
						if tb.go ~= rec.id then Sfx.tab(); WM.open(tb.go) end
					elseif tb[2] and tb[2] ~= rec.current then
						Sfx.tab(); WM.show(rec, tb[2])
					end
					return
				end
			end
		elseif def.views and def.views[nodeName] then
			local target = def.views[nodeName]
			if target ~= rec.current then Sfx.tab(); WM.show(rec, target) end
		end
	end)
	-- selection: clicking a row / card / node moves the white selected ring onto it (when the panel has one)
	ui.onAny(function(nodeName, inst)
		local ring = inst.Parent and inst.Parent:FindFirstChild("selected ring")
		if ring and ring ~= inst then
			local d = ring:GetAttribute("inset") or 4
			ring.Position = inst.Position - UDim2.fromOffset(d, d)
			ring.Size = inst.Size + UDim2.fromOffset(2 * d, 2 * d)
		end
	end)
end

local function buildVariant(rec, name)
	local v = rec.variants[name]
	if v then return v end
	local L = layoutOf(name)
	local ui = Render.build(L, rec.inner)
	ui.root.Visible = false
	-- rows / cards / plain list entries become clickable (selection) without changing their look
	for _, d in ui.root:GetDescendants() do
		if d:IsA("Frame") and (string.sub(d.Name, 1, 4) == "row/" or string.sub(d.Name, 1, 5) == "card/" or string.sub(d.Name, 1, 5) == "cell/") and not d:FindFirstChild("hit") then
			-- under the row's own content (z 1): keys inside the row keep their clicks
			local hit = Render.new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, d)
			hit.MouseButton1Down:Connect(function() Sfx.press() end)
			hit.Activated:Connect(function()
				for _, fn in ui.anyHandlers do task.spawn(fn, d.Name, d) end
			end)
		end
		if d.Name == "selected ring" and d:IsA("GuiObject") then
			-- measure the ring's inset around the element it wraps in Figma, so moving it keeps the same gap
			for _, sib in d.Parent:GetChildren() do
				if sib ~= d and sib:IsA("GuiObject") then
					local dp = sib.Position.X.Offset - d.Position.X.Offset
					if dp >= 2 and dp <= 8 and math.abs(sib.Position.Y.Offset - d.Position.Y.Offset - dp) < 0.6 and math.abs(sib.Size.X.Offset + 2 * dp - d.Size.X.Offset) < 0.6 then
						d:SetAttribute("inset", dp)
					end
				end
			end
		end
	end
	v = { ui = ui, name = name, twinkle = {}, twinkleBase = {} }
	for _, sp in ui.sparkles do
		if not sp:FindFirstAncestorOfClass("CanvasGroup") then
			table.insert(v.twinkle, sp); table.insert(v.twinkleBase, sp.Size.X.Offset)
		end
	end
	rec.variants[name] = v
	wireVariant(rec, name, ui)
	local b = WM.binders[rec.id]
	if b and b.bind then b.bind(rec, ui, name) end
	return v
end

local function buildWindow(id)
	local def = Defs[id]
	assert(def, "unknown window " .. tostring(id))
	local rec = { id = id, def = def, variants = {}, current = nil }
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
	rec.W, rec.H = W, H
	local parent = if def.drawer then drawerLayer else modalLayer
	rec.holder = Render.new("Frame", { Name = id, BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Visible = false, ZIndex = 2,
		AnchorPoint = if def.drawer then Vector2.new(1, 0.5) else Vector2.new(0.5, 0.5),
		Position = if def.drawer then UDim2.new(1, -RAIL_W, 0.5, 0) else UDim2.fromScale(0.5, 0.5) }, parent)
	rec.fit = Render.new("UIScale", { Name = "Fit" }, rec.holder)
	-- clicks on the window's empty areas stop here (never reach the backdrop or the world behind)
	Render.new("TextButton", { Name = "blocker", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, rec.holder)
	rec.inner = Render.new("Frame", { Name = "inner", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ZIndex = 2 }, rec.holder)
	rec.pop = Render.new("UIScale", { Name = "Pop" }, rec.inner)
	if def.build then
		local ui, w, h = WM.screens.build(id, rec.inner, rec)
		rec.W, rec.H = w, h
		rec.holder.Size = UDim2.fromOffset(w, h); rec.inner.Size = UDim2.fromOffset(w, h)
		rec.variants.main = { ui = ui, name = "main", twinkle = {}, twinkleBase = {} }
		wireVariant(rec, "main", ui)
		ui.root.Visible = false
	end
	WM.built[id] = rec
	fitWindow(rec)
	return rec
end

-- show one variant of a window (tab switch / view switch)
function WM.show(rec, name)
	local v = if rec.def.build then rec.variants.main else buildVariant(rec, name)
	for vn, vv in rec.variants do vv.ui.root.Visible = vv == v end
	-- variants of one window can differ in size (Fish Market locked is short): centre the smaller one
	local r = v.ui.root
	r.Position = UDim2.fromOffset((rec.W - r.Size.X.Offset) / 2, (rec.H - r.Size.Y.Offset) / 2)
	rec.current = v.name
	local b = WM.binders[rec.id]
	if b and b.update and WM.state then b.update(rec, v.ui, v.name, WM.state, WM.derived) end
end

local POP = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHRINK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SLIDE_IN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

function WM.isOpen(id)
	local rec = WM.built[id]
	return rec ~= nil and rec.holder.Visible
end

-- open a window (optionally on a given tab label or variant name)
function WM.open(id, tab)
	if not Defs[id] then warn("[UI] unknown window", id); return end
	local rec = WM.built[id] or buildWindow(id)
	local def = rec.def
	local target = rec.current
	if tab then
		for _, tb in def.tabs or {} do
			if string.upper(tb[1]) == string.upper(tab) or tb[2] == tab then target = tb[2] end
		end
		if def.views and def.views[tab] then target = def.views[tab] end
	end
	target = target or (def.tabs and def.tabs[1][2]) or "main"
	if def.build then target = "main" end
	if def.drawer then
		WM.show(rec, target)
		if not WM.drawerOpen then WM.setDrawer(true) end
		return rec
	end
	if WM.modal and WM.modal ~= id then
		local old = WM.built[WM.modal]
		if old then old.holder.Visible = false end
	end
	local wasOpen = WM.modal == id and rec.holder.Visible
	WM.modal = id
	WM.show(rec, target)
	rec.holder.Visible = true
	backdrop.Visible = true
	TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.55 }):Play()
	if not wasOpen then
		Sfx.open()
		if Kit.reduced() then rec.pop.Scale = 1 else rec.pop.Scale = 0.86; TweenService:Create(rec.pop, POP, { Scale = 1 }):Play() end
	end
	if WM.onChanged then WM.onChanged() end
	return rec
end

function WM.close()
	local id = WM.modal
	if not id then return end
	local rec = WM.built[id]
	WM.modal = nil
	Sfx.close()
	TweenService:Create(backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	task.delay(0.15, function() if not WM.modal then backdrop.Visible = false end end)
	if rec then
		if Kit.reduced() then rec.holder.Visible = false
		else
			local tw = TweenService:Create(rec.pop, SHRINK, { Scale = 0.9 })
			tw:Play()
			tw.Completed:Once(function() if WM.modal ~= id then rec.holder.Visible = false end end)
		end
	end
	if WM.onChanged then WM.onChanged() end
end

function WM.toggle(id, tab)
	if WM.modal == id then WM.close() else WM.open(id, tab) end
end

-- shop drawer: docked on the right edge (left of the area rail); closing tucks it into the pull tab
function WM.setDrawer(on)
	local rec = WM.built.shop or buildWindow("shop")
	if not rec.current then WM.show(rec, rec.def.tabs[1][2]) end
	WM.drawerOpen = on
	local home = UDim2.new(1, -RAIL_W, 0.5, 0)
	local away = UDim2.new(1, rec.W + 40, 0.5, 0)
	if on then
		Sfx.open()
		rec.holder.Visible = true
		rec.holder.Position = away
		TweenService:Create(rec.holder, SLIDE_IN, { Position = home }):Play()
	else
		Sfx.close()
		local tw = TweenService:Create(rec.holder, SLIDE_OUT, { Position = away })
		tw:Play()
		tw.Completed:Once(function() if not WM.drawerOpen then rec.holder.Visible = false end end)
	end
	if WM.onChanged then WM.onChanged() end
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

-- debug / QA: PlayerGui:SetAttribute("PeckwoodOpen", "<window id>[:<tab>]") opens a window without clicking
function WM.debugHook()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	pg:GetAttributeChangedSignal("PeckwoodOpen"):Connect(function()
		local v = pg:GetAttribute("PeckwoodOpen")
		if typeof(v) ~= "string" or v == "" then WM.close(); return end
		local id, tab = string.match(v, "^([^:]+):?(.*)$")
		WM.open(id, if tab ~= "" then tab else nil)
	end)
end

return WM
