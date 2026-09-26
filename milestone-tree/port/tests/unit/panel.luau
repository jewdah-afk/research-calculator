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
M.module(shared, "PrefsSchema", function() return require("../../../src/shared/PrefsSchema") end)
local client = Instance.new("Folder"); client.Name = "MilestoneTree"; client.Parent = SPS
local function folder(parent, name)
	local f = Instance.new("Folder"); f.Name = name; f.Parent = parent
	return f
end
scriptModule(client, "Types", "client/Types")
scriptModule(client, "Style", "client/Style")
scriptModule(client, "Render", "client/Render")
local core = folder(client, "Core")
for _, n in { "Signal", "Prefs", "Layout", "Theme", "Motion", "Sprites", "Recipes", "Rich", "Sleek", "ViewStore", "Audio" } do
	scriptModule(core, n, "client/Core/" .. n)
end
local panelF = folder(client, "Panel")
for _, n in { "Panel", "Hero", "Sections", "Virtual" } do scriptModule(panelF, n, "client/Panel/" .. n) end
local skins = folder(panelF, "Skins")
for _, n in { "Common", "Skins", "Generic", "Upgrade", "CompactOwned", "Buyable", "Milestone", "Challenge", "Achievement", "GridTile",
	"Clickable", "Perk", "Opt" } do
	scriptModule(skins, n, "client/Panel/Skins/" .. n)
end
local sigF = folder(client, "Signatures")
scriptModule(sigF, "Signatures", "client/Signatures/Signatures")
-- the per-layer signatures (packages J1 / J2): every sibling module, auto-registered by Signatures on first use
local SIGS = { "Kit", "M", "P", "Sp", "Cp", "Ex", "Ach", "Options", "Effects", "Badges", "Pp", "Energy", "Ap", "Mp", "T" }
for _, n in SIGS do scriptModule(sigF, n, "client/Signatures/" .. n) end

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
	-- the map root's own close / opt actions (plan 1.11: the Options button of a ladder fires map.opt)
	local mapRoot = store.nodes.map
	if type(mapRoot) == "table" then
		if type(mapRoot.opt) == "table" then table.insert(out, mapRoot.opt) end
		if type(mapRoot.close) == "table" then table.insert(out, mapRoot.close) end
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

REPORT = {}
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
	if caps and w == 1920 then table.insert(REPORT, name .. " " .. n) end
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

io_print("    instances (WIDE, caps on): " .. table.concat(REPORT, ", "))
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
	-- the m ladder (Signatures/M): collapsed with NEXT + 4 done + folds, notes and jump column, malware; SHOW ALL is a
	-- virtual pool; both within the instance budget
	for k in Theme.caps do Theme.caps[k] = true end
	viewport(1920, 1080)
	req(sigF.M).resetMemory() -- the fixture loop pressed every fold
	local fx = fixtures.s13_m
	local store = ViewStore.new()
	local changes = store:apply(fx)
	local panel = Panel.new(gui, { store = store })
	local fired = {}
	panel.act:Connect(function(a) table.insert(fired, a) end)
	panel:update(store, changes)
	panel:open("m", store:map().nodes.m)
	local ph = nil
	for id, rec in panel.render.recs do if rec.claim and rec.node.cn == "milestones" then ph = rec.root end end
	check(ph ~= nil, "the ladder claims the 165-row milestones")
	local body = ph and ph:FindFirstChild("Body")
	local rows = body and body:FindFirstChild("Left") and body.Left:FindFirstChild("Rows")
	local n = 0
	if rows then for _, c in rows:GetChildren() do if c:IsA("GuiObject") then n += 1 end end end
	check(rows ~= nil and n >= 6 and n <= 12, "collapsed ladder rows " .. n .. " (NEXT, 4 done, folds)")
	check(rows and rows:FindFirstChild("Next") ~= nil, "NEXT spotlight")
	local nx = rows and rows:FindFirstChild("Next")
	local reqText = nx and nx:FindFirstChild("Req") and string.gsub(nx.Req.Text, "<[^>]*>", "") or ""
	check(string.find(reqText, "e3.243e59", 1, true) ~= nil and nx:FindFirstChild("Bar") ~= nil, "NEXT shows the reset's need and bar (" .. reqText .. ")")
	check(rows and rows:FindFirstChild("Rest") ~= nil, "the rest folds into SHOW ALL")
	local side = body and body:FindFirstChild("Side")
	check(side and side:FindFirstChild("Notes") ~= nil and side:FindFirstChild("Jump") ~= nil, "WIDE side column: notes + jump to")
	local notesHidden = true
	for id, rec in panel.render.recs do
		if rec.node.cn == "display-text" and rec.root.Visible ~= false then notesHidden = false end
	end
	check(notesHidden, "the display-text rows moved into NOTES")
	local mal = ph and ph:FindFirstChild("Malware")
	local infect = 0
	if mal then for _, d in mal:GetDescendants() do if d.Name == "Infect" then infect += 1 end end end
	check(infect == 9, "malware section lists 9 INFECT buttons (" .. infect .. ")")
	local count = #descendants(panel.root)
	check(count <= 450, "m collapsed: instances " .. count .. " <= 450")
	io_print(string.format("    m ladder: collapsed %d instances", count))
	-- an INFECT press fires the malware node's own action
	local b = mal and mal:FindFirstChild("M18") and mal.M18:FindFirstChild("Infect")
	if b then b.Activated:Fire() end
	check(#fired == 1 and fired[1][1] == "malware" and fired[1][3] == "17", "INFECT fires ['malware','m','17']")
	-- SHOW ALL: the virtual pool
	local rest = rows and rows:FindFirstChild("Rest")
	if rest then rest.Activated:Fire() end
	M.step(0.1)
	local host = rows and rows:FindFirstChild("All")
	local pool = 0
	if host then for _, c in host:GetChildren() do if string.sub(c.Name, 1, 3) == "Row" then pool += 1 end end end
	check(host ~= nil and pool > 0 and pool <= 24, "SHOW ALL: virtual pool " .. pool .. " rows")
	count = #descendants(panel.root)
	check(count <= 450, "m SHOW ALL: instances " .. count .. " <= 450")
	io_print(string.format("    m ladder: SHOW ALL %d instances, pool %d", count, pool))
	-- jump to a block, then Show less
	local jump = side and side:FindFirstChild("Jump")
	local b2 = jump and jump:FindFirstChild("B2")
	if b2 then b2.Activated:Fire() end
	M.step(0.1)
	local less = rows and rows:FindFirstChild("Less")
	check(less ~= nil, "Show less offered")
	if less then less.Activated:Fire() end
	check(rows and rows:FindFirstChild("All") == nil and rows:FindFirstChild("Rest") ~= nil, "Show less folds the ladder again")
	-- the Order button opens Options through the map's own action
	local order = side and side:FindFirstChild("Order")
	if order then order.Activated:Fire() end
	check(fired[#fired] and fired[#fired][1] == "tab" and fired[#fired][2] == "options-tab", "Order opens Options (map.opt)")
	-- COMPACT: one column, notes on top
	viewport(844, 390)
	panel.render:refresh()
	check(ph:FindFirstChild("Notes") ~= nil and body:FindFirstChild("Side") == nil, "COMPACT: notes on top, no side column")
	panel:destroy()
	viewport(1920, 1080)
end
do
	-- p (Signatures/P): the Hide owned switch in the UPGRADES title row hides owned cards and owned tiers, and back
	for k in Theme.caps do Theme.caps[k] = false end
	viewport(1920, 1080)
	local fx = fixtures.s13_p
	local store = ViewStore.new()
	local changes = store:apply(fx)
	local panel = Panel.new(gui, { store = store })
	panel:update(store, changes)
	panel:open("p", store:map().nodes.p)
	local sw = nil
	for _, d in descendants(panel.root) do if d.Name == "HideOwned" then sw = d end end
	check(sw ~= nil, "p: Hide owned switch in the UPGRADES row")
	local function shown(cls)
		local k = 0
		for id, rec in panel.render.recs do
			if rec.kind == "btn:upg" and rec.node.cls == cls and rec.root.Visible ~= false then k += 1 end
		end
		return k
	end
	local owned0, can0 = shown("bought"), shown("can")
	if sw then sw.Activated:Fire() end
	check(shown("bought") == 0 and shown("can") == can0, "p: owned hidden (" .. owned0 .. " -> " .. shown("bought") .. "), BUY cards stay")
	for _, d in descendants(panel.root) do if d.Name == "HideOwned" then sw = d end end
	if sw then sw.Activated:Fire() end
	check(shown("bought") == owned0, "p: owned back")
	check(panel.parts.band:FindFirstChild("Accent") ~= nil or not Theme.caps.TileMode, "p: header accent")
	panel:destroy()
end
-- a fixture's panel, opened (the helper of the per-signature checks)
local function openFixture(fx, caps, w, h)
	for k in Theme.caps do Theme.caps[k] = caps end
	viewport(w or 1920, h or 1080)
	local store = ViewStore.new()
	local changes = store:apply(fx)
	local panel = Panel.new(gui, { store = store })
	local fired = {}
	panel.act:Connect(function(a) table.insert(fired, a) end)
	panel:update(store, changes)
	panel:open(store.tab, store:map().nodes[store.tab])
	return panel, store, fired
end
local function findName(root, name)
	for _, d in descendants(root) do if d.Name == name then return d end end
	return nil
end
local function plainText(t) return (string.gsub(tostring(t or ""), "<[^>]*>", "")) end

do
	-- sp (Signatures/Sp): furnace, spark cards with burn bars, the Show cycler in the title row, the pager hidden on 1 page
	local w0 = #warnings
	local panel, store, fired = openFixture(fixtures.s13_sp_spark, true)
	local furnace = findName(panel.root, "Furnace")
	check(furnace ~= nil, "sp: furnace card")
	local btns = 0
	if furnace then for _, d in furnace:GetDescendants() do if d.__class == "TextButton" then btns += 1 end end end
	check(btns == 3, "sp: IGNITE + 2 REIGNITE (" .. btns .. ")")
	check(findName(panel.root, "Unlocked") ~= nil, "sp: the unlocked chip")
	local cards = 0
	for _, d in descendants(panel.root) do if string.match(d.Name, "^S%d$") and findName(d, "Burn") then cards += 1 end end
	check(cards == 3, "sp: 3 spark cards with burn bars (" .. cards .. ")")
	local show = findName(panel.root, "Show")
	check(show ~= nil and string.find(plainText(show.Text), "3", 1, true) ~= nil, "sp: Show: 3 in the title row")
	if show then show.Activated:Fire() end
	check(#fired == 1 and fired[1][1] == "click" and type(fired[1][3]) == "table" and fired[1][3][1] == 14, "sp: Show fires the clickable's action")
	local pagerHidden = false
	for id, rec in panel.render.recs do if rec.claim and rec.node.ci == 15 and rec.root.Visible == false then pagerHidden = true end end
	check(pagerHidden, "sp: the pager hides on one page")
	check(findName(panel.parts.hero, "Ashes") ~= nil, "sp: PRESTIGE ASHES chip in the hero")
	check(findName(panel.parts.sheet, "Rim") ~= nil, "sp: ember rim on the Spark tab")
	check(#warnings == w0, "sp: no warnings" .. (if #warnings > w0 then ": " .. warnings[w0 + 1] else ""))
	panel:destroy()
end
do
	-- cp (Signatures/Cp): counters in the hero, the mode radio, the disk grid (<= 36 tiles x <= 8 instances), the inspector
	local w0 = #warnings
	local panel, store, fired = openFixture(fixtures.s19mv_cp, true)
	local caused = findName(panel.parts.hero, "Caused")
	check(caused ~= nil and plainText(caused.Text) == "23", "cp: CAUSED 23 in the hero")
	local stat = findName(panel.parts.hero, "Stat1")
	check(stat ~= nil and string.find(plainText(stat.Text), "e569,142,978", 1, true) ~= nil, "cp: the essences stat row")
	local grid = findName(panel.root, "Grid")
	local tiles, worst = 0, 0
	if grid then
		for _, c in grid:GetChildren() do
			if c.__class == "TextButton" then
				tiles += 1
				worst = math.max(worst, 1 + #c:GetDescendants())
			end
		end
	end
	check(tiles == 20 and tiles <= 36, "cp: 20 disk tiles (" .. tiles .. ")")
	check(worst <= 8, "cp: a tile is at most 8 instances (" .. worst .. ")")
	check(findName(panel.root, "Inspector") ~= nil and findName(panel.root, "Act") ~= nil, "cp: the inspector with ACTIVATE / DEACTIVATE")
	local d101 = grid and grid:FindFirstChild("D101")
	if d101 then d101.Activated:Fire() end
	check(fired[#fired] and fired[#fired][1] == "grid" and fired[#fired][3] == 101, "cp: a tile click fires its grid action")
	local modes = findName(panel.root, "Options")
	local o2 = modes and modes:FindFirstChild("O2")
	if o2 then o2.Activated:Fire() end
	check(fired[#fired] and fired[#fired][1] == "click" and fired[#fired][3] == 12, "cp: the mode radio fires the free mode's action")
	local visibleNotes = 0
	for id, rec in panel.render.recs do if rec.node.cn == "display-text" and rec.root.Visible ~= false then visibleNotes += 1 end end
	check(visibleNotes == 1, "cp: only the explainer stays in the body (" .. visibleNotes .. ")")
	check(#descendants(panel.root) <= 450, "cp: instances " .. #descendants(panel.root))
	check(#warnings == w0, "cp: no warnings" .. (if #warnings > w0 then ": " .. warnings[w0 + 1] else ""))
	panel:destroy()
end
do
	-- ex (Signatures/Ex): the map is cached by its static svg content; a move only moves the gem
	local w0 = #warnings
	local panel, store, fired = openFixture(fixtures.s19mv_ex, true)
	local map = findName(panel.root, "Map")
	check(map ~= nil and map:GetAttribute("Builds") == 1, "ex: the map built once (" .. tostring(map and map:GetAttribute("Builds")) .. ")")
	local lines0 = map and findName(map, "Static") and #findName(map, "Static"):GetChildren() or 0
	check(lines0 > 0, "ex: map lines and axis numbers drawn (" .. lines0 .. ")")
	local gem = map and findName(map, "Gem")
	local gx0 = gem and gem.Position.X.Offset
	check(gem ~= nil and findName(map, "Goal") ~= nil, "ex: the position gem and the goal")
	-- move the position only
	local svgId = nil
	for id, n in store.nodes do if type(n) == "table" and type(n.h) == "string" and string.find(n.h, "<svg", 1, true) then svgId = id end end
	local moved = table.clone(store:get(svgId))
	moved.h = string.gsub(moved.h, '<text x="131" y="135"', '<text x="151" y="135"')
	local ch = store:apply({ set = { [svgId] = moved }, del = {} })
	panel:update(store, ch)
	M.step(0.5)
	check(map:GetAttribute("Builds") == 1, "ex: a move rebuilds nothing (" .. tostring(map:GetAttribute("Builds")) .. ")")
	check(gem.Parent ~= nil and gem.Position.X.Offset ~= gx0, "ex: the gem moved")
	-- another zone rebuilds
	local other = table.clone(moved)
	other.h = string.gsub(other.h, "zones/a%-3%.svg", "zones/a-2.svg")
	ch = store:apply({ set = { [svgId] = other }, del = {} })
	panel:update(store, ch)
	check(map:GetAttribute("Builds") == 2, "ex: a new zone rebuilds once")
	local keys = 0
	for _, d in descendants(panel.root) do if string.sub(d.Name, 1, 3) == "Key" and d.__class == "TextButton" then keys += 1 end end
	check(keys == 4 and findName(panel.root, "Respec") ~= nil, "ex: D-pad 4 keys + RESPEC (" .. keys .. ")")
	local right = findName(panel.root, "KeyRight")
	if right then right.Activated:Fire() end
	check(fired[#fired] and fired[#fired][1] == "buy" and fired[#fired][3] == 11, "ex: the right key buys Increase X")
	check(findName(panel.parts.hero, "Zone") ~= nil and findName(panel.parts.hero, "Area") ~= nil, "ex: ZONE and AREA chips")
	check(#descendants(panel.root) <= 450, "ex: instances " .. #descendants(panel.root))
	check(#warnings == w0, "ex: no warnings" .. (if #warnings > w0 then ": " .. warnings[w0 + 1] else ""))
	panel:destroy()
end
do
	-- ach (Signatures/Ach): the count, 2 shelves of 18 medallions, the inspector
	local w0 = #warnings
	local panel, store, fired = openFixture(fixtures.layer_ach, true)
	local big = findName(panel.root, "Big")
	check(big ~= nil and big.Text == "1 / 18", "ach: the count 1 / 18 (" .. tostring(big and big.Text) .. ")")
	local medals = 0
	for _, d in descendants(panel.root) do if string.match(d.Name, "^A%d+$") and d.__class == "TextButton" then medals += 1 end end
	check(medals == 18 and findName(panel.root, "Shelf2") ~= nil, "ach: 18 medallions on 2 shelves (" .. medals .. ")")
	local a11 = findName(panel.root, "A11")
	if a11 then a11.Activated:Fire() end
	local ins = findName(panel.root, "Inspect")
	check(ins and string.find(plainText(ins.Text.Text), "Where it all begins", 1, true) ~= nil, "ach: a tap inspects the medallion")
	local shown = 0
	for id, rec in panel.render.recs do if rec.node.cn == "display-text" and rec.root.Visible ~= false then shown += 1 end end
	check(shown == 0, "ach: the count line left the body")
	check(#fired == 0, "ach: medallions fire nothing")
	check(#warnings == w0, "ach: no warnings" .. (if #warnings > w0 then ": " .. warnings[w0 + 1] else ""))
	panel:destroy()
end
do
	-- Options (Signatures/Options): section titles, SAVE / EXPORT / IMPORT tiles, the danger zone hold, THIS DEVICE
	local w0 = #warnings
	local panel, store, fired = openFixture(fixtures.s13_options, true)
	local titles = {}
	for _, d in descendants(panel.root) do
		if d.Name == "SectionTitle" or d.Name == "Head" then
			local t = d:FindFirstChild("Title")
			-- titles are tracked caps (hair spaces between letters, Rich.caps)
			if t then titles[(string.gsub(t.Text, "\u{200A}", ""))] = true end
		end
	end
	check(titles["YOUR SAVE"] and titles["DISPLAY"] and titles["THIS DEVICE"] and not titles["DANGER ZONE"], "options: YOUR SAVE, DISPLAY, THIS DEVICE (no danger zone)")
	local tiles, gone = 0, true
	for id, rec in panel.render.recs do
		if rec.kind == "btn:opt" and rec.node.id == "save" and rec.root.Size.Y.Offset >= 84 then tiles += 1 end
		if rec.node.id == "hardReset" or rec.node.id == "export" or rec.node.id == "import" then gone = false end
	end
	check(tiles == 1, "options: the Save tile (" .. tiles .. ")")
	check(gone and findName(panel.root, "HardReset") == nil, "options: no Hard Reset, Export or Import (saves live in Roblox)")
	local dev = findName(panel.root, "Device")
	local seg = dev and dev:FindFirstChild("Row1") and dev.Row1:FindFirstChild("Seg")
	local reduced = seg and seg:FindFirstChild("O3")
	if reduced then reduced.Activated:Fire() end
	local Prefs = req(core.Prefs)
	check(Prefs.get().motion == "REDUCED", "options: Motion Reduced through Prefs")
	seg = dev and dev:FindFirstChild("Row1") and dev.Row1:FindFirstChild("Seg")
	local sys = seg and seg:FindFirstChild("O1")
	if sys then sys.Activated:Fire() end
	check(Prefs.get().motion == "SYSTEM", "options: back to System")
	local foreign = 0
	for _, a in fired do if a[1] ~= "opt" then foreign += 1 end end
	check(foreign == 0, "options: only opt actions")
	check(#warnings == w0, "options: no warnings" .. (if #warnings > w0 then ": " .. warnings[w0 + 1] else ""))
	panel:destroy()
end
do
	-- the rest of the tree: each signature's hero idea / accent / widget is on screen and the panel stays in budget
	local cases = {
		{ "layer_ep", function(panel) local n = 0; for _, d in descendants(panel.root) do if string.match(d.Name, "^R%d+$") and d:FindFirstChild("Pill") then n += 1 end end; return n >= 5, "ep: effect ladder rungs " .. n end },
		{ "layer_ep", function(panel) return findName(panel.root, "Empowered") ~= nil, "ep: EMPOWERED chips" end },
		{ "layer_pep", function(panel) return findName(panel.parts.sheet, "Core") ~= nil, "pep: fusion core ring" end },
		{ "layer_pb", function(panel) local v = findName(panel.parts.hero, "Value"); return v ~= nil and v.Text == "^28,329", "pb: power badge " .. tostring(v and v.Text) end },
		{ "layer_hb", function(panel) local v = findName(panel.parts.hero, "Value"); return v ~= nil and v.Text == "^1.6298", "hb: power badge " .. tostring(v and v.Text) end },
		{ "layer_pp", function(panel) local v = findName(panel.parts.hero, "Scope"); return v ~= nil and findName(v, "Wave") ~= nil, "pp: Hz over the oscilloscope" end },
		{ "layer_pp", function(panel) local k = 0; for id, rec in panel.render.recs do if rec.node.cn == "display-text" and rec.root.Visible ~= false then k += 1 end end; return k == 0, "pp: the Hz line left the body" end },
		{ "layer_pe", function(panel) local v = findName(panel.parts.hero, "Rate"); return v ~= nil and string.find(plainText(v.Text), "16.00", 1, true) ~= nil and string.find(plainText(v.Text), "PP", 1, true) ~= nil, "pe: RATE chip " .. tostring(v and plainText(v.Text)) end },
		{ "layer_se", function(panel) return findName(panel.parts.hero, "Rate") ~= nil, "se: RATE chip" end },
		{ "layer_ap", function(panel) return findName(panel.parts.sheet, "Orbit") ~= nil, "ap: atom orbit" end },
		{ "layer_mp", function(panel) return findName(panel.root, "Portal") ~= nil and findName(panel.parts.sheet, "Split") ~= nil, "mp: portal card and split rim" end },
		{ "layer_t", function(panel) return findName(panel.parts.sheet, "Rays") ~= nil, "t: crown rays" end },
	}
	for _, c in cases do
		local w0 = #warnings
		local panel = openFixture(fixtures[c[1]], true)
		local ok, what = c[2](panel)
		check(ok, what)
		check(#descendants(panel.root) <= 450, c[1] .. ": instances " .. #descendants(panel.root))
		check(#warnings == w0, c[1] .. ": no warnings" .. (if #warnings > w0 then ": " .. warnings[w0 + 1] else ""))
		panel:destroy()
	end
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

print(string.format("panel: %d checks, %d failed", checks, failures))
if failures > 0 then
	print("panel: FAILED")
	error("panel unit test failed", 0)
end
print("panel: all checks passed")
