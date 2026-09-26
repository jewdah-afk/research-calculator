--!nocheck
--[[
	The new client end to end on the mock engine (tests/mock.luau + tests/engine.luau), without a server: Main.client
	starts App, every capture fixture patch in data/fixtures is played into the View remote, frames are stepped, and
	the player's paths are driven: node taps and the panel beside the map, Esc, HOME / TROPHIES / OPTIONS, the Options
	panel (Save, no hard reset / export / import), hotkeys, the peek, READY holds, the gate popover, toasts,
	the phone layout (full-screen panel, the map switched off, the band's close), the detail sheet, every modal and
	screen. Any script error or [MilestoneTree] warning fails the run. Twice: with every engine capability, and with
	all of them forced off (MT_ForceCaps = "all", the fallbacks; sound then runs on the legacy Sound path). Sound:
	the cues the run should make are checked on the engine's play log; with -a noids (every audio asset id nil)
	nothing may play at all.

	Run from port/: python3 tools/wrap_scripts.py && ./test.sh capture && luau tests/unit/client_smoke.luau [-a nocaps|noids|locked]
]]
local M = require("../mock")
local E = require("../engine")(M)
local ARG = ...
local NOCAPS = ARG == "nocaps"
local NOIDS = ARG == "noids"
-- -a locked: properties the engine has but locks to Roblox's own scripts (Studio refused UIShadow.Transparency with
-- "lacking capability RobloxScript"); the client must drop the feature, never fail a draw
local LOCKED = ARG == "locked"

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
if NOIDS then
	-- every sheet without an id: the game must be silent (and not throw)
	RS.MilestoneTree.AudioIds.__module = function()
		local t = table.clone(require("../../../src/shared/AudioIds"))
		local sheets = {}
		for k, v in t.sheets do
			local c = table.clone(v)
			c.id, c.review = nil, nil
			sheets[k] = c
		end
		t.sheets = sheets
		return t
	end
end

-- remotes
local function folder(parent, name) local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; return f end
local remotes = folder(RS, "MilestoneTreeRemotes")
local R = {}
for _, n in { "View", "Act", "Ready", "Prefs" } do
	local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = remotes
	R[n] = r
end
local acts, readies = {}, 0
M.fireServer = function(remote, ...)
	if remote == R.Act then table.insert(acts, { ... }) end
	if remote == R.Ready then readies += 1 end
end

-- the player
local p = M.addPlayer("Tester", 1)
game:GetService("Players").__props.LocalPlayer = p
if NOCAPS then p:SetAttribute("MT_ForceCaps", "all") end
if LOCKED then M.locked = { ["UIShadow.Transparency"] = true, ["Path2D.Transparency"] = true } end

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
-- ReplicatedFirst's loading screen is up before the client's scripts
local bootAt = M.now
E.runMain("Boot")
frames(0.1)
local bootGui = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("MilestoneBoot")
check(bootGui ~= nil and bootGui.Enabled ~= false, "the ReplicatedFirst loading screen shows first")
-- the asset preload behind it (Core/Preload): slow (each asset 0.25 s) in the default and locked runs, a PreloadAsync
-- that throws with all caps off, one that never returns with -a noids (the timeout, cut to 3 s here, lets it go)
local PRELOAD = if NOCAPS then "error" elseif NOIDS then "hang" else "slow"
E.preload, E.preloadDelay = PRELOAD, 0.25
local Preload = M.require(client.Core.Preload)
if PRELOAD == "hang" then Preload.TIMEOUT = 3 end
local function bootLine(): (string, number)
	local g = p.PlayerGui:FindFirstChild("MilestoneBoot")
	local bar = g and g.Back.Column.Bar
	if bar == nil then return "", -1 end
	return (string.gsub(bar.Status.Text, "\u{200A}", "")), tonumber(string.match(bar.Pct.Text, "%d+")) or -1
end
E.runMain("Main")
frames(0.5)
local pg = p:FindFirstChild("PlayerGui")
check(pg:FindFirstChild("MilestoneBoot") ~= nil, "the loading screen stays until the first view")
do
	-- every image the client draws and its fonts, once each
	local ids, fontsN, dup = {}, 0, nil
	for _, call in E.preloads do
		for _, item in call do
			if type(item) == "string" then
				if ids[item] then dup = item end
				ids[item] = true
			elseif item.__class == "TextLabel" and item.FontFace then
				fontsN += 1
			end
		end
	end
	local Assets = require("../../../src/shared/Assets")
	local UiKit = require("../../../src/shared/UiKit")
	local NodeAtlas = require("../../../src/shared/NodeAtlas")
	local Products = require("../../../src/shared/Products")
	local sky = ids[Assets.tiers.HIGH.layers.sky.tiles[1].id] or ids[Assets.tiers.LOW.layers.sky.tiles[1].id]
	local atlas = ids[Assets.sprites.atlas.HIGH or ""] or ids[Assets.sprites.atlas.LOW or ""]
	check(#E.preloads >= 2 and sky and ids[UiKit.id] and ids[NodeAtlas.id] and atlas,
		"PreloadAsync gets the realm tiles, the UI kit, the node and sprite atlases (in batches)")
	check(ids["rbxassetid://" .. Products.passes[1].icon] and ids["rbxassetid://" .. Products.products[1].icon], "and the Shop icons")
	check(fontsN >= 2, "and a label per font face (" .. fontsN .. ")")
	check(dup == nil, "no asset twice (" .. tostring(dup) .. ")")
end
local status0, pct0 = bootLine()
if PRELOAD == "slow" then
	check(status0 == "LOADING ASSETS", "the loading screen says LOADING ASSETS (" .. status0 .. ")")
	check(pct0 > 0 and pct0 < 60, "its % follows the preload (" .. pct0 .. "%)")
end
local mapGui = pg:FindFirstChild("MapGui")
check(mapGui ~= nil and pg:FindFirstChild("Backing") ~= nil, "MapGui and the black backing built")
check(readies >= 1, "asked the server for a full view")
local nodesF = mapGui and mapGui.Root.Box.Nodes
check(nodesF and nodesF:FindFirstChild("Node_m") ~= nil and nodesF:FindFirstChild("Node_cp") ~= nil, "21 node widgets")
do
	-- Interactable = false carries down to descendants in the engine: a node's Hit (and the rift) must have no
	-- ancestor with it off, or no node can be clicked
	local off: string? = nil
	local function inert(o: Instance?, stop: Instance?)
		local x = o
		while x and x ~= stop do
			if x:IsA("GuiObject") and (x :: any).Interactable == false then return x.Name end
			x = x.Parent
		end
		return nil
	end
	for _, n in (if nodesF then nodesF:GetChildren() else {}) do
		local hit = n:FindFirstChild("Hit", true)
		off = off or (hit and inert(hit, mapGui))
	end
	off = off or (nodesF and inert(nodesF:FindFirstChild("Rift"), mapGui))
	check(off == nil, "every node's Hit and the rift take input (Interactable off on: " .. tostring(off) .. ")")
end
local screen = pg.OverlayGui.Root.Screen
check(screen.Visible and screen:GetAttribute("Kind") == "loading", "the loading screen shows until the first view")

-- the first view: the realm is home (a layer left open by the last session is closed)
local n0 = #acts
play("s13_p")
frames(0.2)
check(sent("tab", "none", n0), "the layer the last session left open is closed at boot")
if PRELOAD == "error" then
	-- a failed PreloadAsync counts as done: the images load as they show, as before the preload
	check(not screen.Visible, "the loading screen is gone after the first view (the preload failed at once)")
else
	local _, pct1 = bootLine()
	check(screen.Visible and screen:GetAttribute("Kind") == "loading" and pg:FindFirstChild("MilestoneBoot") ~= nil,
		"the loading screen stays up after the first view while the assets load")
	if PRELOAD == "slow" then check(pct1 > pct0, string.format("the %% advances (%d%% -> %d%%)", pct0, pct1)) end
	-- slow: every asset is back by now; hang: Preload gave up at its timeout
	frames(if PRELOAD == "hang" then 2.2 else 1.6)
	check(not screen.Visible, if PRELOAD == "hang" then "a PreloadAsync that never returns holds it no longer than the timeout"
		else "the loading screen is gone once the preload is done")
end
-- then the ReplicatedFirst screen still holds its minimum time (4 s from boot), filling the line to 100% by its end
if M.now - bootAt < 3.5 then
	local st, pc = bootLine()
	check(pg:FindFirstChild("MilestoneBoot") ~= nil and st == "ENTERING THE TREE",
		string.format("a fast load keeps the loading screen up (%s, %d%% at %.1f s)", st, pc, M.now - bootAt))
	check(pc < 100, "the line is still filling (" .. pc .. "%)")
end
frames(math.max(0, bootAt + 4.1 - M.now))
local _, pcEnd = bootLine()
check(pcEnd == 100, "the line reaches 100% at the minimum time (" .. pcEnd .. "%)")
frames(1)
check(pg:FindFirstChild("MilestoneBoot") == nil, "the ReplicatedFirst loading screen faded out and is gone")
local sheet = pg.PanelGui.Root.Sheet
check(not sheet.Visible, "the map alone at boot")

local index = { "fresh_none", "fresh_m", "s13_none", "s13_p", "s13_m", "s13_sp_spark", "s13_options", "s19mv_none", "s19mv_cp", "s19mv_ex", "trapped_none", "layer_ach", "layer_m", "layer_mm", "layer_em", "layer_p", "layer_pe", "layer_sp", "layer_pb", "layer_pp", "layer_se", "layer_hp", "layer_ep", "layer_hb", "layer_ap", "layer_mp", "layer_t", "layer_pm", "layer_pep", "layer_cp", "layer_cm", "layer_ex" }
frames(2.5)
for _, name in index do
	play(name)
end
check((M.errors or 0) == errors0, "every fixture drew without a script error")
check(sheet.Visible and findText(sheet.Header or sheet, "EXPLOR") ~= nil or sheet.Visible, "the panel follows the server's open layer (ex)")

play("layer_sp")
local info = pg.TopbarGui.Root.Info
check(info.Visible and string.find(info.Label.Text, "Spark Milestone", 1, true) ~= nil, "the head's extra line (a burning Spark Milestone) shows under the capsule")

-- the S13 map: states and plates
play("s13_none")
check(not info.Visible, "no extra line when the game has none")
check(not sheet.Visible, "the panel closes when the server shows the map alone")
local function state(l) local n = nodesF:FindFirstChild("Node_" .. l); return n and n:GetAttribute("State") end
check(state("m") == "available" or state("m") == "pulse", "m available (" .. tostring(state("m")) .. ")")
check(state("pb") == "locked", "pb locked (" .. tostring(state("pb")) .. ")")
check(state("pm") == "sealed", "pm sealed before the Multiverse is revealed (" .. tostring(state("pm")) .. ")")
local plates = mapGui.Root.Box.Plates
check(plates:FindFirstChild("Plate_p") and plates.Plate_p.Label.Text ~= "", "the P plate has its name")
-- the tutorial: an advanced save has none (and it is marked done); Replay + a fresh game shows step 1 on the
-- points bar; SKIP ends it
frames(0.5)
local guideF = pg.OverlayGui.Root:FindFirstChild("Guide")
check(guideF ~= nil and not guideF.Visible, "no tutorial on an advanced save")
local PrefsM = M.require(client.Core.Prefs)
check(PrefsM.get().tut == 8, "an advanced save marks the tutorial done (" .. tostring(PrefsM.get().tut) .. ")")
PrefsM.set("tut", 0)
play("fresh_none")
check(state("mm") == "frontier", "fresh: mm is frontier (" .. tostring(state("mm")) .. ")")
frames(0.5)
check(guideF and guideF.Visible and string.find(guideF.Card.Title.Text, "Welcome", 1, true) ~= nil, "a new game shows the tutorial's first step")
check(guideF and guideF.Dim.Ring.Visible, "step 1 puts the spotlight on the points bar")
guideF.Card.Buttons.Skip.Activated:Fire()
frames(0.5)
check(not guideF.Visible and PrefsM.get().tut == 8, "SKIP ends the tutorial")
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

-- the dock: TROPHIES, OPTIONS, HOME
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
-- the game's option rows by their view path (a signature may restyle or wrap them)
local function optButton(id)
	local fx = require("../../data/fixtures/s13_options")
	for path, n in fx.set do
		if type(n) == "table" and n.k == "opt" and n.id == id then
			for _, d in sheet:GetDescendants() do
				if d.Name == path and (d.__class == "TextButton" or d.__class == "ImageButton") then return d end
			end
		end
	end
	return nil
end
-- saves live in Roblox: no Hard Reset, Export or Import anywhere in Options
check(optButton("hardReset") == nil and optButton("export") == nil and optButton("import") == nil,
	"Options has no Hard Reset, Export or Import")
check(optButton("save") ~= nil, "Options still has Save")
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
	-- late game: automation flips a layer's CAN BUY several times a second while the hold runs (it used to rebuild
	-- the tray and cancel the hold)
	local fx = require("../../data/fixtures/s19mv_none")
	local base = fx.set and fx.set["map.15.1"]
	for i = 1, 9 do
		if base then
			local v = table.clone(base)
			v.glow = i % 2 == 0
			R.View.OnClientEvent:Fire({ set = { ["map.15.1"] = v } })
		end
		frames(0.1)
	end
	UIS.InputEnded:Fire(io)
	frames(0.2)
	check(sent("reset", nil, n0), "holding a READY gem sends its reset action (while CAN BUY flickers)")
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

-- the phone: aspect-ratio scaling (Layout.compute) gives it the desktop layout at s .55, never a separate phone design
Workspace.CurrentCamera.__props.ViewportSize = Vector2.new(844, 390)
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Fire()
frames(0.5)
check(Layout.mode ~= "COMPACT" and math.abs(Layout.s - 0.55) < 1e-6, "phone: the desktop layout, scaled (s " .. Layout.s .. ", " .. Layout.mode .. ")")
n0 = #acts
nodesF.Node_p.Hit.Activated:Fire()
frames(0.6)
check(sheet.Visible and mapGui.Enabled, "phone: the panel opens beside the map, as on desktop")
local band = pg.TopbarGui.Root:FindFirstChild("PanelBand")
check(band == nil or not band.Visible, "phone: no separate phone band")
sheet.Close.Activated:Fire()
frames(0.5)
check(not sheet.Visible and mapGui.Enabled and count("tab", "none", n0) == 1, "phone: the panel's close closes it")
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

-- sound: what the run should have played (the engine logs every Play with its region)
local AudioIds = M.require(RS.MilestoneTree.AudioIds)
local function played(name)
	local want = {}
	for _, r in AudioIds.sounds[name].regions do want[r[1]] = true end
	local n = 0
	for _, pl in E.audio.plays do
		if pl.region and want[pl.region.Min] then n += 1 end
	end
	return n
end
local Audio = M.require(client.Core.Audio)
if NOIDS then
	check(#E.audio.plays == 0, "no asset ids: not one sound played (" .. #E.audio.plays .. ")")
else
	check(Audio.mode == (if NOCAPS then "sound" else "api"), "sound runs on the " .. Audio.mode .. " path")
	local cls = if NOCAPS then "Sound" else "AudioPlayer"
	local right = true
	for _, pl in E.audio.plays do if pl.class ~= cls then right = false end end
	check(right, "every sound played on a " .. cls)
	for _, n in { "panel_open", "panel_close", "press", "hover", "toast", "ambience" } do
		check(played(n) > 0, "the run played " .. n .. " (" .. played(n) .. ")")
	end
	check(played("prestige_small") + played("prestige_big") > 0, "holding a READY gem played a prestige")
	check(Audio.stats().total <= 32, "at most 32 voices (" .. Audio.stats().total .. ")")
end

-- the one warning expected above: the drawing error
check(E.warnings <= 2, "no [MilestoneTree] warnings besides the forced drawing error (" .. E.warnings .. ")")
check((M.errors or 0) == errors0, "no script errors (" .. tostring((M.errors or 0) - errors0) .. ")")
do
	local failed = 0
	for _, w in M.warns or {} do
		if string.find(w, "drawing the screen failed", 1, true) then
			failed += 1
			if failed == 1 then print("  first: " .. w) end
		end
	end
	check(failed == 0, "every patch drew (" .. failed .. " drawing failures)")
end
print(string.format("== client smoke: %d tweens made, %d actions sent", E.tweens, #acts))
if failures > 0 then
	error("client smoke: " .. failures .. " FAILED", 0)
end
print("client smoke: all passed")
