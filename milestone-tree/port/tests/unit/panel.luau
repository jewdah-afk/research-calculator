--!nocheck
--[[
	The panel (package H) on the mock engine: every capture fixture's tab is built through Panel + Render + skins +
	claims + the hero, at WIDE (1920 x 1080) and COMPACT (844 x 390), with the engine capabilities all off and all on.

	Checks per fixture: no script error and no warning from a skin / claim / hero, at most 450 instances under the
	PanelGui, cards carry a State attribute, section titles exist where the tab has sections, no raw game colour in
	rendered text, and every button press fires an action that is a node's own `a` from the ViewStore (the action
	whitelist, plan 1.11). Also: the open protocol (shell at once, skeleton until patch.tab == key), claim routing
	(a later patch under a claimed id only marks the claim dirty) and the virtual ladder's pool size.

	Run from port/: python3 tools/wrap_scripts.py && luau tests/unit/panel.luau
]]
local M = require("../mock")
local W = "../../data/wrap/"

local failures, checks = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failures += 1
		if failures <= 40 then print("  FAIL  " .. what) end
	end
end

-- ------------------------------------------------------------------------------------------------ a richer engine
-- datatypes the panel uses that the base mock lacks (arithmetic, sequences, tween info, fonts)
local function dt(name, fields, mt)
	mt = mt or {}
	mt.__tostring = function() return name end
	mt.__index = function(t, k)
		if mt.methods and mt.methods[k] then return mt.methods[k] end
		error(name .. " has no " .. tostring(k), 2)
	end
	return setmetatable(fields, mt)
end
local Vector2
local v2mt = {}
Vector2 = {
	new = function(x, y)
		return dt("Vector2", { X = x or 0, Y = y or 0, Magnitude = math.sqrt((x or 0) ^ 2 + (y or 0) ^ 2) }, v2mt)
	end,
}
v2mt.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
v2mt.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
v2mt.__mul = function(a, b)
	if type(a) == "number" then return Vector2.new(a * b.X, a * b.Y) end
	if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
v2mt.__div = function(a, b)
	if type(b) == "number" then return Vector2.new(a.X / b, a.Y / b) end
	return Vector2.new(a.X / b.X, a.Y / b.Y)
end
v2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
v2mt.__unm = function(a) return Vector2.new(-a.X, -a.Y) end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

local UDim = { new = function(s, o) return dt("UDim", { Scale = s or 0, Offset = o or 0 }) end }
local UDim2
local u2mt = {}
UDim2 = {
	new = function(xs, xo, ys, yo)
		return dt("UDim2", { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, u2mt)
	end,
	fromOffset = function(x, y) return UDim2.new(0, x or 0, 0, y or 0) end,
	fromScale = function(x, y) return UDim2.new(x or 0, 0, y or 0, 0) end,
}
u2mt.__add = function(a, b) return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
u2mt.__sub = function(a, b) return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
u2mt.__eq = function(a, b) return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset end

local ColorSequenceKeypoint = { new = function(t, c)
	assert(type(t) == "number" and t >= 0 and t <= 1, "ColorSequenceKeypoint time " .. tostring(t))
	return dt("ColorSequenceKeypoint", { Time = t, Value = c })
end }
local ColorSequence = { new = function(a, b)
	if type(a) == "table" and a.R ~= nil then
		return dt("ColorSequence", { Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } })
	end
	assert(type(a) == "table" and #a >= 2 and #a <= 20, "ColorSequence needs 2..20 keypoints")
	assert(a[1].Time == 0 and a[#a].Time == 1, "ColorSequence must start at 0 and end at 1")
	for i = 2, #a do assert(a[i].Time > a[i - 1].Time, "ColorSequence times must increase") end
	return dt("ColorSequence", { Keypoints = a })
end }
local NumberSequenceKeypoint = { new = function(t, v)
	assert(type(t) == "number" and t >= 0 and t <= 1, "NumberSequenceKeypoint time " .. tostring(t))
	assert(type(v) == "number" and v >= 0 and v <= 1, "NumberSequenceKeypoint value " .. tostring(v))
	return dt("NumberSequenceKeypoint", { Time = t, Value = v })
end }
local NumberSequence = { new = function(a, b)
	if type(a) == "number" then
		return dt("NumberSequence", { Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } })
	end
	assert(type(a) == "table" and #a >= 2 and #a <= 20, "NumberSequence needs 2..20 keypoints")
	assert(a[1].Time == 0 and a[#a].Time == 1, "NumberSequence must start at 0 and end at 1")
	for i = 2, #a do assert(a[i].Time > a[i - 1].Time, "NumberSequence times must increase") end
	return dt("NumberSequence", { Keypoints = a })
end }
local TweenInfo = { new = function(t, style, dir, repeatCount) return dt("TweenInfo", { Time = t or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = repeatCount or 0 }) end }
local Rect = { new = function(a, b, c, d) return dt("Rect", { Min = Vector2.new(a, b), Max = Vector2.new(c, d), Width = c - a, Height = d - b }) end }
local Font = {
	new = function(family, weight, style) return dt("Font", { Family = family, Weight = weight, Style = style }) end,
	fromName = function(name, weight, style) return dt("Font", { Family = "rbxasset://fonts/families/" .. name .. ".json", Weight = weight, Style = style }) end,
}
for k, v in {
	Vector2 = Vector2, UDim = UDim, UDim2 = UDim2, ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint,
	NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint, TweenInfo = TweenInfo, Rect = Rect, Font = Font,
} do
	M.G[k] = v
end
-- warnings count as failures: a skin, claim or hero error is caught and warned
local warnings = {}
M.G.warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do table.insert(parts, tostring(select(i, ...))) end
	table.insert(warnings, table.concat(parts, " "))
end
io_print = print
DEBUG = false
M.G.print = function(...) end

-- instance methods and property defaults the panel reads
local Inst = getmetatable(M.newInstance("Frame"))
local baseIndex = Inst.__index
local DEFAULTS = {
	BackgroundTransparency = 0, Visible = true, ZIndex = 1, LayoutOrder = 0, Rotation = 0, TextTransparency = 0, TextSize = 14,
	Text = "", Active = false, ClipsDescendants = false, TextWrapped = false, RichText = false,
}
Inst.__index = function(o, k)
	local v = baseIndex(o, k)
	if v ~= nil then return v end
	if k == "AbsolutePosition" or k == "AnchorPoint" or k == "CanvasPosition" then return Vector2.new(0, 0) end
	if k == "AbsoluteSize" then
		if o.__class == "ScreenGui" then return Vector2.new(1920, 1080) end
		local s = o.__props.Size
		if s then return Vector2.new(s.X.Offset, s.Y.Offset) end
		return Vector2.new(0, 0)
	end
	if k == "Size" or k == "Position" then return UDim2.new(0, 0, 0, 0) end
	if k == "TextBounds" then
		local t = string.gsub(tostring(o.__props.Text or ""), "<[^>]*>", "")
		return Vector2.new(#t * (o.__props.TextSize or 14) * 0.55, (o.__props.TextSize or 14) * 1.2)
	end
	local d = DEFAULTS[k]
	if d ~= nil then return d end
	return nil
end
function Inst:GetAttributeChangedSignal(k)
	self.__attrSignals = self.__attrSignals or {}
	local s = self.__attrSignals[k] or M.Signal.new()
	self.__attrSignals[k] = s
	return s
end
function Inst:FindFirstAncestorWhichIsA(cls)
	local o = self.Parent
	while o do
		if o:IsA(cls) then return o end
		o = o.Parent
	end
	return nil
end
function Inst:FindFirstChildWhichIsA(cls)
	for _, c in self.__kids do if c:IsA(cls) then return c end end
	return nil
end
function Inst:IsDescendantOf(a)
	local o = self.Parent
	while o do
		if o == a then return true end
		o = o.Parent
	end
	return false
end

-- ------------------------------------------------------------------------------------------------ the DataModel
local game = M.game
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local Instance = M.G.Instance
local SPS = Instance.new("Folder"); SPS.Name = "StarterPlayerScripts"; SPS.Parent = SP
local shared = Instance.new("Folder"); shared.Name = "MilestoneTree"; shared.Parent = RS
local function scriptModule(parent, name, wrapPath)
	local inst
	inst = M.module(parent, name, function() return M.withScript(inst, require(W .. wrapPath)) end)
	return inst
end
scriptModule(shared, "Html", "shared/Html")
M.module(shared, "ZoneMaps", function() return require("../../../src/shared/ZoneMaps") end)
M.module(shared, "Assets", function() return require("../../../src/shared/Assets") end)
local client = Instance.new("Folder"); client.Name = "MilestoneTree"; client.Parent = SPS
local function folder(parent, name)
	local f = Instance.new("Folder"); f.Name = name; f.Parent = parent
	return f
end
scriptModule(client, "Types", "client/Types")
scriptModule(client, "Style", "client/Style")
scriptModule(client, "Render", "client/Render")
local core = folder(client, "Core")
for _, n in { "Signal", "Prefs", "Layout", "Theme", "Motion", "Sprites", "Recipes", "Rich", "ViewStore" } do
	scriptModule(core, n, "client/Core/" .. n)
end
local panelF = folder(client, "Panel")
for _, n in { "Panel", "Hero", "Sections", "Virtual", "Preview" } do scriptModule(panelF, n, "client/Panel/" .. n) end
local skins = folder(panelF, "Skins")
for _, n in { "Common", "Skins", "Generic", "Upgrade", "CompactOwned", "Buyable", "Milestone", "Challenge", "Achievement", "GridTile",
	"Clickable", "Perk", "Opt" } do
	scriptModule(skins, n, "client/Panel/Skins/" .. n)
end
local sigF = folder(client, "Signatures")
scriptModule(sigF, "Signatures", "client/Signatures/Signatures")

-- the local player
local lp = M.newInstance("Player")
lp.Name = "Tester"
lp.__props.UserId = 1
local pg = M.newInstance("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = lp
lp.Parent = Players
Players.__props.LocalPlayer = lp

local req = M.require
local Layout = req(core.Layout)
local Theme = req(core.Theme)
local ViewStore = req(core.ViewStore)
local Panel = req(panelF.Panel)
local Virtual = req(panelF.Virtual)

local cam = game:GetService("Workspace").CurrentCamera
local function viewport(w, h)
	cam.__props.ViewportSize = Vector2.new(w, h)
	Layout.refresh()
end

-- ------------------------------------------------------------------------------------------------ helpers
local function descendants(o)
	return o:GetDescendants()
end
local function deepEq(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in a do if not deepEq(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
-- every `a` of the store's nodes
local function allActions(store)
	local out = {}
	for _, n in store.nodes do
		if type(n) == "table" and type(n.a) == "table" then table.insert(out, n.a) end
	end
	return out
end
local RAW = { "793784", "652021", "648c11", "d03800", "9f2846", "c25757" }
local CARD = { ["btn:upg"] = true, ["btn:buy"] = true, ms = true, chal = true, ach = true, ["btn:grid"] = true, ["btn:opt"] = true }

-- data/fixtures/index.json
local index = { "fresh_none", "fresh_m", "s13_none", "s13_p", "s13_m", "s13_sp_spark", "s13_options", "s19mv_none", "s19mv_cp", "s19mv_ex", "trapped_none", "layer_ach", "layer_m", "layer_mm", "layer_em", "layer_p", "layer_pe", "layer_sp", "layer_pb", "layer_pp", "layer_se", "layer_hp", "layer_ep", "layer_hb", "layer_ap", "layer_mp", "layer_t", "layer_pm", "layer_pep", "layer_cp", "layer_cm", "layer_ex" }
local fixtures = {}
for _, name in index do fixtures[name] = require("../../data/fixtures/" .. name) end

local gui, root = Layout.screen("PanelGui", 20, M.G.Enum.ScreenInsets.CoreUISafeInsets)
check(gui ~= nil and root ~= nil, "PanelGui built")
local gui2 = Layout.screen("PanelGuiShell", 21, M.G.Enum.ScreenInsets.CoreUISafeInsets)

local function runFixture(name, caps, w, h)
	local fx = fixtures[name]
	for k in Theme.caps do Theme.caps[k] = caps end
	viewport(w, h)
	local store = ViewStore.new()
	local changes = store:apply(fx)
	local panel = Panel.new(gui, { store = store })
	local fired = {}
	panel.act:Connect(function(a, hold) table.insert(fired, a) end)
	local key = store.tab
	local label = string.format("%s [%s %dx%d]", name, if caps then "caps on" else "caps off", w, h)
	local w0, e0 = #warnings, M.errors or 0
	-- open before the body arrives: the shell draws, the skeleton shows
	local node = store:map().nodes[key]
	if key ~= "none" then
		local s2 = ViewStore.new()
		s2:apply({ full = true, set = { map = fx.set.map }, tab = "none" })
		local p2 = Panel.new(gui2, { store = s2 })
		p2:open(key, node)
		check(p2.parts.sheet.Visible == true, label .. ": the sheet shows at once")
		check(p2.parts.body:FindFirstChild("Skeleton") ~= nil, label .. ": skeleton until the layer's patch")
		check(p2.parts.title:GetAttribute("Sig") ~= nil, label .. ": title drawn from the map node")
		p2:destroy()
	end
	panel:update(store, changes)
	if key ~= "none" then panel:open(key, node) end
	M.step(0.1)
	if key ~= "none" then
		check(panel.parts.body:FindFirstChild("Skeleton") == nil, label .. ": body shown once patch.tab == key")
	end
	local n = #descendants(panel.root)
	if n > 450 and DEBUG then
		local byName = {}
		for _, d in descendants(panel.root) do local k = d.__class .. ":" .. d.Name; byName[k] = (byName[k] or 0) + 1 end
		local list = {}
		for k, v in byName do table.insert(list, { k, v }) end
		table.sort(list, function(a, b) return a[2] > b[2] end)
		for i = 1, 30 do if list[i] then io_print(list[i][1], list[i][2]) end end
	end
	check(n <= 450, label .. ": instances " .. n .. " <= 450")
	-- cards carry State, sections have titles
	local cards, stated = 0, 0
	for id, rec in panel.render.recs do
		if CARD[rec.kind] and not rec.claim then
			cards += 1
			if rec.root:GetAttribute("State") ~= nil then stated += 1 end
		end
	end
	check(stated == cards, label .. ": every card has a State (" .. stated .. "/" .. cards .. ")")
	local sectionCns = 0
	for id, nd in store.nodes do
		if string.sub(id, 1, 3) == "tab" and type(nd) == "table" and (nd.cn == "upgrades" or nd.cn == "buyables" or nd.cn == "milestones"
			or nd.cn == "challenges" or nd.cn == "achievements") then
			sectionCns += 1
		end
	end
	local titles = 0
	for _, d in descendants(panel.root) do
		if d.Name == "SectionTitle" or d.Name == "Head" then titles += 1 end
	end
	if titles == 0 and sectionCns > 0 and DEBUG then
		for id, rec in panel.render.recs do
			if rec.node.cn == "upgrades" or rec.node.cn == "milestones" then
				local names = {}
				for _, c in rec.root:GetChildren() do table.insert(names, c.Name) end
				io_print(id, rec.kind, rec.claim ~= nil, table.concat(names, ","))
			end
		end
	end
	check(sectionCns == 0 or titles > 0, label .. ": section titles present (" .. titles .. " for " .. sectionCns .. " sections)")
	-- no raw game colours in rendered text
	local raw = nil
	for _, d in descendants(panel.root) do
		if d.__class == "TextLabel" then
			local t = string.lower(tostring(d.Text or ""))
			for _, c in RAW do
				if string.find(t, c, 1, true) then raw = c end
			end
		end
	end
	check(raw == nil, label .. ": no raw game colour (" .. tostring(raw) .. ")")
	-- press every button: each fired action is a node's own `a`
	local actions = allActions(store)
	local pressed = 0
	for _, d in descendants(panel.root) do
		if (d.__class == "TextButton" or d.__class == "ImageButton") and d.Name ~= "Close" and d.Name ~= "OwnedRow" and d.Visible ~= false then
			pressed += 1
			d.Activated:Fire()
		end
	end
	M.step(0.1)
	local bad = 0
	for _, a in fired do
		local ok = false
		for _, b in actions do
			if a == b or deepEq(a, b) then ok = true; break end
		end
		if not ok then bad += 1 end
	end
	check(bad == 0, label .. ": " .. #fired .. " presses fired node actions (" .. bad .. " foreign) from " .. pressed .. " buttons")
	local newWarn = #warnings - w0
	if newWarn > 0 then print("    " .. warnings[w0 + 1]) end
	check(newWarn == 0, label .. ": no warnings (" .. newWarn .. ")")
	check((M.errors or 0) == e0, label .. ": no script errors")
	panel:close()
	check(panel:isOpen() == nil and panel.parts.sheet.Visible == false, label .. ": closes")
	panel:destroy()
	return panel
end

print("== panel: every fixture, WIDE and COMPACT, caps off and on")
for _, name in index do
	for _, caps in { false, true } do
		runFixture(name, caps, 1920, 1080)
	end
	runFixture(name, true, 844, 390)
	runFixture(name, false, 1366, 768)
end

print("== claim routing and the open protocol")
do
	for k in Theme.caps do Theme.caps[k] = false end
	viewport(1920, 1080)
	local fx = fixtures.s13_p
	local store = ViewStore.new()
	local changes = store:apply(fx)
	local panel = Panel.new(gui, { store = store })
	panel:update(store, changes)
	panel:open("p", store:map().nodes.p)
	-- the hero claimed the three components
	check(panel.hero.ids["main-display"] ~= nil and panel.hero.ids["prestige-button"] ~= nil, "hero claims main-display and prestige-button")
	check(panel.parts.hero.Visible == true, "hero visible on p")
	local cta = panel.parts.hero:FindFirstChild("Cta")
	check(cta ~= nil, "hero CTA drawn")
	-- a patch on the claimed prestige button only dirties the claim (no subtree is built)
	local pbId = panel.hero.ids["prestige-button"]
	local pb = table.clone(store:get(pbId))
	pb.gain = "123"
	local ch2 = store:apply({ set = { [pbId] = pb }, del = {} })
	panel:update(store, ch2)
	local recs = 0
	for id in panel.render.recs do if string.sub(id, 1, #pbId + 1) == pbId .. "." then recs += 1 end end
	check(recs == 0, "no records under a claimed id")
	local well = cta and cta:FindFirstChild("Well")
	check(well ~= nil and string.find(well.Text, "123", 1, true) ~= nil, "claim update redrew the gain")
	-- the CTA fires the prestige-button's own action
	local got = nil
	panel.act:Connect(function(a) got = a end)
	cta.Activated:Fire()
	M.step(1)
	check(got ~= nil and got[1] == "reset" and got[2] == "p", "CTA fires the node's reset action")
	-- the header tabs claim renders the subtabs; a single tab bar is hidden
	check(panel.parts.tabs.Visible == false, "a single-tab bar is hidden (p has Main only)")
	panel:destroy()
end
do
	local fx = fixtures.s13_m
	local store = ViewStore.new()
	local changes = store:apply(fx)
	local panel = Panel.new(gui, { store = store })
	panel:update(store, changes)
	panel:open("m", store:map().nodes.m)
	local host = nil
	for id, rec in panel.render.recs do if rec.claim and rec.node.cn == "milestones" then host = rec.root end end
	check(host ~= nil, "the 165-row ladder is virtualised")
	local rows = 0
	if host then for _, c in host:GetChildren() do if string.sub(c.Name, 1, 3) == "Row" then rows += 1 end end end
	check(rows > 0 and rows <= 24, "virtual pool " .. rows .. " rows (viewport + 2)")
	check(Virtual.MS_ROWS == 24, "virtual threshold")
	panel:destroy()
end
do
	-- subtabs: sp spark fixture has three tabs in the header
	local fx = fixtures.s13_sp_spark
	local store = ViewStore.new()
	local changes = store:apply(fx)
	local panel = Panel.new(gui, { store = store })
	panel:update(store, changes)
	panel:open("sp", store:map().nodes.sp)
	check(panel.parts.tabs.Visible == true and panel.parts.tabs:GetAttribute("Count") == 3, "three header tabs on sp")
	check(panel.sub == "Spark Milestones", "current subtab read from the tabs node (" .. tostring(panel.sub) .. ")")
	panel:destroy()
end

print("== the Studio preview over the old page")
do
	for k in Theme.caps do Theme.caps[k] = false end
	viewport(1920, 1080)
	local Preview = req(panelF.Preview)
	local sent = {}
	local w0 = #warnings
	local pv = Preview.start({ press = function(a, hold) table.insert(sent, a) end })
	check(pv ~= nil, "preview starts in Studio")
	pv:onPatch(fixtures.layer_p)
	check(pv.panel:isOpen() == "p", "the panel follows map.open (p)")
	pv.panel.parts.close.Activated:Fire()
	check(#sent == 1 and sent[1][1] == "tab" and sent[1][2] == "none", "X sends the map's close action")
	check(pv.panel:isOpen() == nil, "the panel closes at once")
	pv:onPatch({ set = {}, del = {} })
	check(pv.panel:isOpen() == nil, "a stale patch does not reopen it")
	pv:onPatch(fixtures.s13_m)
	check(pv.panel:isOpen() == "m", "another layer opens")
	pv:setOn(false)
	check(pv.panel:isOpen() == nil and pv.panel.gui.Enabled == false, "the toggle hides it")
	pv:setOn(true)
	check(pv.panel:isOpen() == "m", "and brings it back")
	check(#warnings == w0, "preview: no warnings" .. (if #warnings > w0 then ": " .. warnings[w0 + 1] else ""))
end

print(string.format("panel: %d checks, %d failed", checks, failures))
if failures > 0 then
	print("panel: FAILED")
	error("panel unit test failed", 0)
end
print("panel: all checks passed")
