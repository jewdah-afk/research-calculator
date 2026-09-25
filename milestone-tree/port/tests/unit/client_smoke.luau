--!nocheck
--[[
	The new client end to end on the mock engine (tests/mock.luau + tests/engine.luau), without a server: Main.client
	starts App, every capture fixture patch in data/fixtures is played into the View remote, frames are stepped, and
	the player's paths are driven: node taps and the panel beside the map, Esc, HOME / TROPHIES / OPTIONS, the Options
	panel's hard reset (the confirm modal), export / import, hotkeys, the peek, READY holds, the gate popover, toasts,
	the phone layout (full-screen panel, the map switched off, the band's close), the detail sheet, every modal and
	screen. Any script error or [MilestoneTree] warning fails the run. Twice: with every engine capability, and with
	all of them forced off (MT_ForceCaps = "all", the fallbacks).

	Run from port/: python3 tools/wrap_scripts.py && ./test.sh capture && luau tests/unit/client_smoke.luau [-a nocaps]
]]
local M = require("../mock")
local E = require("../engine")(M)
local NOCAPS = (...) == "nocaps"

local failures = 0
local function check(ok, what)
	if ok then print("  ok    " .. what) else failures += 1; print("  FAIL  " .. what) end
end
local Vector2 = E.Vector2
local game = M.game
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Enum = M.G.Enum
local Instance = M.G.Instance

-- ------------------------------------------------------------------------------------------------------ the tree
local RS = game:GetService("ReplicatedStorage")
local client = E.buildClient()

-- remotes
local function folder(parent, name) local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; return f end
local remotes = folder(RS, "MilestoneTreeRemotes")
local R = {}
for _, n in { "View", "Act", "Import", "Ready", "Prefs" } do
	local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = remotes
	R[n] = r
end
remotes:SetAttribute("ImportCooldown", 10)
local acts, readies, imports = {}, 0, {}
M.fireServer = function(remote, ...)
	if remote == R.Act then table.insert(acts, { ... }) end
	if remote == R.Ready then readies += 1 end
	if remote == R.Import then table.insert(imports, (...)) end
end

-- the player
local p = M.addPlayer("Tester", 1)
game:GetService("Players").__props.LocalPlayer = p
if NOCAPS then p:SetAttribute("MT_ForceCaps", "all") end

-- ------------------------------------------------------------------------------------------------------ helpers
local frames = E.frames
local function play(name, extra)
	local patch = require("../../data/fixtures/" .. name)
	if extra then
		patch = table.clone(patch)
		for k, v in extra do patch[k] = v end
	end
	R.View.OnClientEvent:Fire(patch)
	frames(0.3)
end
local function sent(kind, a2, from)
	for i = (from or 0) + 1, #acts do
		local a = acts[i][1]
		if a[1] == kind and (a2 == nil or a[2] == a2) then return true end
	end
	return false
end
local function count(kind, a2, from)
	local n = 0
	for i = (from or 0) + 1, #acts do
		local a = acts[i][1]
		if a[1] == kind and (a2 == nil or a[2] == a2) then n += 1 end
	end
	return n
end
local function key(code, down)
	local io = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = code, Position = Vector2.new(0, 0) }
	UIS.InputBegan:Fire(io, false)
	frames(0.05)
end
local function findText(root, text)
	for _, d in root:GetDescendants() do
		if (d.__class == "TextLabel" or d.__class == "TextButton") and string.find(d.Text or "", text, 1, true) then return d end
	end
	return nil
end
local function buttonWith(root, text)
	local l = findText(root, text)
	while l and l.__class ~= "TextButton" and l.__class ~= "ImageButton" do l = l.Parent end
	return l
end

-- ------------------------------------------------------------------------------------------------------ the run
local errors0 = M.errors or 0
print("== the client starts" .. (if NOCAPS then " (all caps off)" else ""))
E.runMain("Main")
frames(0.5)
local pg = p:FindFirstChild("PlayerGui")
local mapGui = pg:FindFirstChild("MapGui")
check(mapGui ~= nil and pg:FindFirstChild("Backing") ~= nil, "MapGui and the black backing built")
check(readies >= 1, "asked the server for a full view")
local nodesF = mapGui and mapGui.Root.Box.Nodes
check(nodesF and nodesF:FindFirstChild("Node_m") ~= nil and nodesF:FindFirstChild("Node_cp") ~= nil, "21 node widgets")
local screen = pg.OverlayGui.Root.Screen
check(screen.Visible and screen:GetAttribute("Kind") == "loading", "the loading screen shows until the first view")

-- the first view: the realm is home (a layer left open by the last session is closed)
local n0 = #acts
play("s13_p")
frames(0.2)
check(sent("tab", "none", n0), "the layer the last session left open is closed at boot")
check(not screen.Visible, "the loading screen is gone after the first view")
local sheet = pg.PanelGui.Root.Sheet
check(not sheet.Visible, "the map alone at boot")

local index = { "fresh_none", "fresh_m", "s13_none", "s13_p", "s13_m", "s13_sp_spark", "s13_options", "s19mv_none", "s19mv_cp", "s19mv_ex", "trapped_none", "layer_ach", "layer_m", "layer_mm", "layer_em", "layer_p", "layer_pe", "layer_sp", "layer_pb", "layer_pp", "layer_se", "layer_hp", "layer_ep", "layer_hb", "layer_ap", "layer_mp", "layer_t", "layer_pm", "layer_pep", "layer_cp", "layer_cm", "layer_ex" }
frames(2.5)
for _, name in index do
	play(name)
end
check((M.errors or 0) == errors0, "every fixture drew without a script error")
check(sheet.Visible and findText(sheet.Header or sheet, "EXPLOR") ~= nil or sheet.Visible, "the panel follows the server's open layer (ex)")

-- the S13 map: states and plates
play("s13_none")
check(not sheet.Visible, "the panel closes when the server shows the map alone")
local function state(l) local n = nodesF:FindFirstChild("Node_" .. l); return n and n:GetAttribute("State") end
check(state("m") == "available" or state("m") == "pulse", "m available (" .. tostring(state("m")) .. ")")
check(state("pb") == "locked", "pb locked (" .. tostring(state("pb")) .. ")")
check(state("pm") == "sealed", "pm sealed before the Multiverse is revealed (" .. tostring(state("pm")) .. ")")
local plates = mapGui.Root.Box.Plates
check(plates:FindFirstChild("Plate_p") and plates.Plate_p.Label.Text ~= "", "the P plate has its name")
play("fresh_none")
check(state("mm") == "frontier", "fresh: mm is frontier (" .. tostring(state("mm")) .. ")")
play("s19mv_none")
check(state("p") == "dormant", "inside: p dormant (" .. tostring(state("p")) .. ")")

-- a node tap opens its panel beside the map; the body fills with the layer's patch
play("s13_none")
frames(0.5)
n0 = #acts
local hit = nodesF.Node_p.Hit
hit.MouseEnter:Fire(10, 10)
frames(0.3)
hit.Activated:Fire()
frames(0.4)
check(count("tab", "p", n0) == 1, "a tap on P sends its tab action once")
check(sheet.Visible, "the panel opens at once (the shell before the patch)")
local Layout = M.require(client.Core.Layout)
check(Layout.sheet() ~= nil, "the map shrinks to the strip beside the sheet (the free rect ends at the sheet)")
play("s13_p")
local tabRoot = sheet.Body.Scroll.TabRoot
check(#tabRoot:GetDescendants() > 5, "the body fills once the layer's patch arrives")
hit.Activated:Fire()
frames(0.4)
check(count("tab", "p", n0) == 1, "a second tap on the open node sends nothing")
-- the panel's own buttons fire their node's action
local pressed = 0
for _, d in tabRoot:GetDescendants() do
	if d.__class == "TextButton" and pressed < 20 then
		d.Activated:Fire()
		pressed += 1
		frames(0.05)
	end
end
check(#acts > n0 + 1, "panel buttons send actions")
-- Esc closes the panel (map.close) and the map gets its width back
n0 = #acts
key(Enum.KeyCode.Escape)
frames(0.5)
check(count("tab", "none", n0) == 1 and not sheet.Visible, "Esc closes the panel with map.close")
check(Layout.sheet() == nil, "the map is full width again")
play("s13_none")

-- hotkeys: a game key is sent as {"key", name}; - / = zoom when the game does not use them
n0 = #acts
key(Enum.KeyCode.P)
check(sent("key", "p", n0), "the P hotkey is sent")
local z0 = pg.HudGui.Root.Zoom:FindFirstChild("Pct") and pg.HudGui.Root.Zoom.Pct.Text
key(Enum.KeyCode.Equals)
frames(0.5)
check(not sent("key", "=", n0), "= zooms the map (not a game key)")

-- the dock: TROPHIES, OPTIONS (+ the hard reset confirm, export, import), HOME
local dock = pg.HudGui.Root.Dock
n0 = #acts
dock.Trophies.Activated:Fire()
frames(0.4)
check(count("tab", "ach", n0) == 1 and sheet.Visible, "TROPHIES opens the achievements")
play("layer_ach")
dock.Trophies.Activated:Fire()
frames(0.4)
check(count("tab", "none", n0) == 1 and not sheet.Visible, "TROPHIES again closes them")
play("s13_none")
n0 = #acts
dock.Options.Activated:Fire()
frames(0.4)
check(count("tab", "options-tab", n0) == 1 and sheet.Visible, "OPTIONS opens the Options panel")
play("s13_options")
local ov = pg.OverlayGui.Root
local hr = buttonWith(sheet, "Hard Reset")
check(hr ~= nil, "the Options panel has Hard Reset")
if hr then
	hr.Activated:Fire()
	frames(0.3)
	check(ov.Modal.Visible and ov.Modal:GetAttribute("Kind") == "hardReset", "Hard Reset opens the confirm modal")
	check(not sent("opt", "hardReset", n0), "nothing is reset before the 2 s hold")
	local ex = ov.Modal.Buttons:FindFirstChild("Export")
	if ex then ex.Activated:Fire() end
	frames(0.3)
	check(sent("opt", "export", n0), "EXPORT FIRST sends the export action")
end
R.View.OnClientEvent:Fire({ set = {}, del = {}, export = string.rep("eyJ0", 600) })
frames(0.3)
check(ov.Modal.Visible and ov.Modal:GetAttribute("Kind") == "export" and #ov.Modal.Well.Box.Text >= 100, "the export modal shows the save string")
key(Enum.KeyCode.Escape)
check(not ov.Modal.Visible and sheet.Visible, "Esc closes the modal first, the panel stays")
local imp = buttonWith(sheet, "Import a save")
if imp then imp.Activated:Fire() end
frames(0.2)
check(sent("opt", "import", n0), "Import a save sends its action")
R.View.OnClientEvent:Fire({ set = {}, del = {}, askImport = true })
frames(0.3)
check(ov.Modal:GetAttribute("Kind") == "import", "the import modal opens")
ov.Modal.Well.Box.Text = "garbage"
ov.Modal.Buttons.Primary.Activated:Fire()
frames(0.3)
check(imports[#imports] == "garbage", "IMPORT sends the pasted text")
R.View.OnClientEvent:Fire({ set = {}, del = {}, imp = { ok = false, msg = "That string is not a valid save (nothing was changed)." },
	notice = { "That string is not a valid save (nothing was changed)." } })
frames(0.3)
check(ov.Modal.Result.Visible, "a bad import shows the inline error")
key(Enum.KeyCode.Escape)
n0 = #acts
dock.Home.Activated:Fire()
frames(0.8)
check(count("tab", "none", n0) == 1 and not sheet.Visible, "HOME closes the panel")
play("s13_none")
dock.Home.Activated:Fire()
frames(1)
dock.Home.Activated:Fire()
frames(1)

-- the peek, READY holds, the gate popover, the warning chip, toasts
nodesF.Node_p.Hit.MouseButton2Click:Fire()
frames(0.3)
local peek = ov:FindFirstChild("Peek")
check(peek and peek.Visible, "right-click opens the peek")
key(Enum.KeyCode.Escape)
check(peek and not peek.Visible, "Esc closes the peek")
nodesF.Node_p.Hit.MouseButton2Click:Fire()
frames(0.3)
n0 = #acts
local ob = peek and peek.Card.Buttons:FindFirstChild("Open")
if ob then ob.Activated:Fire() end
frames(0.5)
check(peek and not peek.Visible and count("tab", "p", n0) == 1, "the peek's OPEN opens the layer")
key(Enum.KeyCode.Escape)
play("s19mv_none")
local hudRoot = pg.HudGui.Root
local ready = hudRoot:FindFirstChild("Ready")
local gem = ready and ready.Gems:FindFirstChild("Gem_pm")
check(gem ~= nil, "the READY tray has PM")
if gem then
	n0 = #acts
	local io = { UserInputType = Enum.UserInputType.Touch, Position = Vector2.new(10, 10) }
	gem.Hit.InputBegan:Fire(io)
	frames(0.9)
	UIS.InputEnded:Fire(io)
	frames(0.2)
	check(sent("reset", nil, n0), "holding a READY gem sends its reset action")
end
hudRoot.Portal.Hit.Activated:Fire()
frames(0.6)
check(ov.Modal.Visible and ov.Modal:GetAttribute("Kind") == "gate", "the portal opens the gate popover")
ov.ModalDimmer.Activated:Fire()
frames(0.2)
play("s13_none")
pg.TopbarGui.Root.Warn.Hit.Activated:Fire()
frames(0.4)
R.View.OnClientEvent:Fire({ set = {}, del = {}, pop = {
	{ id = 1, title = "Milestone Gotten!", message = "18th Meta-Milestone", kind = "milestone", layer = "mm" },
	{ id = 2, title = "Milestone Gotten!", message = "19th Meta-Milestone", kind = "milestone", layer = "mm" },
	{ id = 3, title = "Achievement Gotten!", message = "Getting richer?", kind = "achievement", layer = "ach" },
}, notice = { "Game saved." }, save = "saved" })
frames(0.5)
local n = 0
for _, c in ov.Toasts:GetChildren() do if string.sub(c.Name, 1, 6) == "Toast_" then n += 1 end end
check(n == 3, "3 toasts (two milestones merged): " .. n)
R.View.OnClientEvent:Fire({ set = {}, del = {}, unsaved = true })
frames(0.2)
check(pg.TopbarGui.Root.Status.Visible and string.find(string.lower(pg.TopbarGui.Root.Status.Label.Text), "not saving") ~= nil, "NOT SAVING while the server cannot save")
frames(7)
check(string.find(string.lower(pg.TopbarGui.Root.Status.Label.Text), "reconnecting") ~= nil, "RECONNECTING after 6 s without a view")
play("s13_none")
check(string.find(string.lower(pg.TopbarGui.Root.Status.Label.Text), "reconnecting") == nil, "the next view clears RECONNECTING")

-- the phone: a full-screen panel switches the map off; the band closes it
Workspace.CurrentCamera.__props.ViewportSize = Vector2.new(844, 390)
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Fire()
frames(0.5)
n0 = #acts
nodesF.Node_p.Hit.Activated:Fire()
frames(0.6)
check(sheet.Visible and not mapGui.Enabled, "COMPACT: the panel is full screen and MapGui is off")
local band = pg.TopbarGui.Root:FindFirstChild("PanelBand")
check(band and band.Visible, "COMPACT: the band carries the title and the close")
if band then band.Close.Activated:Fire() end
frames(0.5)
check(not sheet.Visible and mapGui.Enabled and count("tab", "none", n0) == 1, "the band's close closes the panel and the map comes back")
Workspace.CurrentCamera.__props.ViewportSize = Vector2.new(1920, 1080)
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Fire()
frames(0.5)

-- the end screen
R.View.OnClientEvent:Fire({ set = {}, del = {}, ended = true })
frames(0.3)
check(screen.Visible and screen:GetAttribute("Kind") == "end", "the end screen")
R.View.OnClientEvent:Fire({ set = {}, del = {}, ended = false })
frames(0.3)
check(not screen.Visible, "KEEP GOING returns to the map")

-- a drawing error resyncs once, a second one shows OUT OF SYNC
local r0 = readies
R.View.OnClientEvent:Fire({ set = {}, del = {}, pop = 5 })
frames(0.2)
check(readies == r0 + 1, "a drawing error asks for a resync")
R.View.OnClientEvent:Fire({ set = {}, del = {}, pop = 5 })
frames(0.2)
check(screen.Visible and screen:GetAttribute("Kind") == "outOfSync", "a second one within 10 s shows OUT OF SYNC")
screen:FindFirstChild("Card").Buttons.Primary.Activated:Fire()
frames(0.1)
check(readies == r0 + 2, "RESYNC asks for a full view")
play("s13_none")
check(not screen.Visible, "the full view clears OUT OF SYNC")

-- the detail sheet, every modal and screen on a fresh overlay
local Overlay = M.require(client.Overlay.Overlay)
local sg = Instance.new("ScreenGui"); sg.Name = "OverlayTest"; sg.Parent = pg
local r = Instance.new("Frame"); r.Name = "Root"; r.Parent = sg
local ov2 = Overlay.new(sg)
local detailActs = 0
ov2.act:Connect(function() detailActs += 1 end)
ov2:detail({ id = "tab.1", kind = "btn:buy", layer = "p", node = { t = "btn", k = "buy", cls = "can", hold = true, ti = "Prestige Boost",
	h = "<b>Prestige Boost</b><br>Boosts things", ds = "Boosts things", lv = "3", max = "10", co = "1e10", cur = "P", pr = 400, a = { "buy", "p", 11 } } })
frames(0.3)
check(r.Detail.Visible, "the detail sheet opens")
r.Detail.Buttons.Primary.Activated:Fire()
frames(0.1)
check(detailActs == 1, "BUY in the detail sheet sends the node's action")
check(ov2:escape() and not r.Detail.Visible, "Esc closes the detail sheet")
ov2:modal("export", string.rep("eyJ0", 500))
frames(0.3)
ov2:modal("hardReset", { action = { "opt", "hardReset" } })
frames(0.2)
ov2:modal("gate", { t = "gate", show = true, inside = true, can = true, fin = true, done = true, h = "Leave", goal = "Goal: 1e20 PEP",
	a = { "chal", "mp", 21 }, rs = { "p", "m" } })
frames(0.2)
ov2:modal("gate", { t = "gate", show = false, inside = false, can = false, fin = false, done = false, rs = {}, req = { have = "164", need = "185", pr = 886 } })
ov2:modal(nil)
for _, k in { "loading", "fatal", "outOfSync", "end" } do
	ov2:screen(k, if k == "loading" then { done = 3, total = 10 } elseif k == "end" then { win = "You won", took = "12d 4h", again = { "opt", "a" }, keep = { "opt", "b" } } else "text")
	frames(0.1)
end
ov2:screen(nil)
ov2:flash(M.G.Color3.new(1, 0, 0))
frames(1)
ov2:destroy()

-- the one warning expected above: the drawing error
check(E.warnings <= 2, "no [MilestoneTree] warnings besides the forced drawing error (" .. E.warnings .. ")")
check((M.errors or 0) == errors0, "no script errors (" .. tostring((M.errors or 0) - errors0) .. ")")
print(string.format("== client smoke: %d tweens made, %d actions sent", E.tweens, #acts))
if failures > 0 then
	error("client smoke: " .. failures .. " FAILED", 0)
end
print("client smoke: all passed")
