--!nocheck
--[[
	The Roblox scripts end to end on the mock engine (tests/mock.luau + tests/engine.luau): the real Main.server,
	Worker (in an Actor), Store, Session, the game, and the whole client (Main.client -> App: the map, the HUD, the
	panel with Render and the skins, the overlays). A player joins and plays through the new UI the way a player
	would (DESIGN.md 16 anchors): taps a node, presses the cards and the hero's CTA, switches layers, closes with Esc,
	exports from OPTIONS, leaves (the save goes to the in-memory DataStore), rejoins (the save comes back), imports
	through the modal; a phone-sized screen gets the full-screen panel; the server shuts down. Every remote payload
	is checked against Roblox's rules for what a RemoteEvent can carry.
	Run tools/wrap_scripts.py first (test.sh roblox does). `-a studio`: every DataStore call fails.
]]
local M = require("./mock")
local E = require("./engine")(M)
local L = require("../lib")
local W = "../data/wrap/"

local failures = 0
local function check(ok, what)
	if ok then print("  ok    " .. what) else failures += 1; print("  FAIL  " .. what) end
end

-- ------------------------------------------------------------------------------------ the DataModel (default.project.json)
local game = M.game
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local SP = game:GetService("StarterPlayer")
local Instance = M.G.Instance
local task = M.G.task
local SPS = Instance.new("Folder"); SPS.Name = "StarterPlayerScripts"; SPS.Parent = SP
local Players = game:GetService("Players")

local tn = M.module(RS, "TowerNum", function() return L.TN end)
M.module(tn, "Hyper", function() return nil end)
local shared = Instance.new("Folder"); shared.Name = "MilestoneTree"; shared.Parent = RS
local htmlInst
htmlInst = M.module(shared, "Html", function() return M.withScript(htmlInst, require(W .. "shared/Html")) end)
M.module(shared, "ZoneMaps", function() return require("../../src/shared/ZoneMaps") end)

local server = Instance.new("Folder"); server.Name = "MilestoneTree"; server.Parent = SSS
local function scriptModule(parent, name, wrapPath)
	local inst
	inst = M.module(parent, name, function() return M.withScript(inst, require(W .. wrapPath)) end)
	return inst
end
scriptModule(server, "Config", "server/Config")
scriptModule(server, "Store", "server/Store")
M.module(server, "Session", function() return L.Session end)
local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = server
M.module(runtime, "JSRT", function() return L.JSRT end)
M.module(runtime, "BEcore", function() return L.BEcore end)
local gameFolder = Instance.new("Folder"); gameFolder.Name = "Game"; gameFolder.Parent = server
M.module(gameFolder, "Manifest", function() return require("../../src/server/Game/Manifest") end)
for i, n in L.rbxNames do
	M.module(gameFolder, n, function() return L.rbx[i] end)
end
local mainScript = Instance.new("Script"); mainScript.Name = "Main"
local workerTemplate = Instance.new("Actor"); workerTemplate.Name = "MilestoneTreeWorker"; workerTemplate.Parent = SS
local workerScript = Instance.new("Script"); workerScript.Name = "Worker"; workerScript.Parent = workerTemplate
workerScript.__run = W .. "worker/Worker"

-- a Script starts when it (or an Actor holding it) lands under ServerScriptService
local function under(o, ancestor)
	while o do if o == ancestor then return true end o = o.Parent end
	return false
end
M.onParented = function(o)
	local list = { o }
	for _, d in o:GetDescendants() do table.insert(list, d) end
	for _, s in list do
		if s.__class == "Script" and s.__run and not s.__started and under(s, SSS) then
			s.__started = true
			M.runScript(s, require(s.__run))
		end
	end
end

-- -------------------------------------------------------------------------------------------- remotes, both ways
local payloadErrors = {}
local function carry(v, path, depth)
	-- what a RemoteEvent can carry: nil/bool/number/string/Instance, and tables that are either arrays 1..n or
	-- string-keyed dictionaries (mixed tables lose data), no functions, no metatables, no cycles
	depth = depth or 0
	local t = type(v)
	if t == "function" or t == "thread" or t == "userdata" then table.insert(payloadErrors, path .. ": " .. t); return nil end
	if t ~= "table" then return v end
	if v.__class then return v end
	if getmetatable(v) ~= nil then table.insert(payloadErrors, path .. ": has a metatable") end
	if depth > 60 then table.insert(payloadErrors, path .. ": too deep"); return nil end
	local n, count, strs = #v, 0, 0
	for k in v do
		count += 1
		if type(k) == "string" then strs += 1 end
	end
	if count > 0 and not (count == n or strs == count) then table.insert(payloadErrors, path .. ": mixed table (" .. n .. " array, " .. count .. " keys)") end
	local out = {}
	for k, x in v do out[k] = carry(x, path .. "." .. tostring(k), depth + 1) end
	return out
end
local sent, sentBytes, maxBytes = 0, 0, 0
local function size(v)
	local t = type(v)
	if t == "string" then return #v end
	if t ~= "table" then return 4 end
	local n = 0
	for k, x in v do n += size(k) + size(x) end
	return n
end
local localPlayer = nil
M.fireServer = function(remote, ...)
	local args = table.pack(...)
	for i = 1, args.n do args[i] = carry(args[i], remote.Name .. "#" .. i) end
	remote.OnServerEvent:Fire(localPlayer, table.unpack(args, 1, args.n))
end
local optPaths = {}
M.fireClient = function(remote, player, ...)
	if player ~= localPlayer then return end
	local args = table.pack(...)
	for i = 1, args.n do args[i] = carry(args[i], remote.Name .. "#" .. i) end
	sent += 1
	-- where the game's option rows are (their view paths), so the test finds them however a skin draws them
	local patch = args[1]
	if remote.Name == "View" and type(patch) == "table" and type(patch.set) == "table" then
		for path, n in patch.set do
			if type(n) == "table" and n.k == "opt" and type(n.id) == "string" then optPaths[n.id] = path end
		end
	end
	local b = size(args)
	sentBytes += b
	maxBytes = math.max(maxBytes, b)
	remote.OnClientEvent:Fire(table.unpack(args, 1, args.n))
end

-- ------------------------------------------------------------------------------------------------------ the run
-- `luau tests/roblox.luau -a studio`: a place opened from a file in Studio, where every DataStore call fails
local STUDIO = (...) == "studio"
if STUDIO then
	M.failStore = true
	M.failMessage = "StudioAccessToApisNotAllowed: Studio access to APIs is not allowed (mock)"
end

local frames = E.frames
M.G.print = print

print("== server starts")
mainScript.Parent = server
M.runScript(mainScript, require(W .. "server/Main"))
check(RS:FindFirstChild("MilestoneTreeRemotes") ~= nil, "remotes created")

local acts = {}
local fireServer = M.fireServer
M.fireServer = function(remote, ...)
	if remote.Name == "Act" then table.insert(acts, (...)) end
	return fireServer(remote, ...)
end
local function count(kind, a2, from)
	local n = 0
	for i = (from or 0) + 1, #acts do
		local a = acts[i]
		if type(a) == "table" and a[1] == kind and (a2 == nil or a[2] == a2) then n += 1 end
	end
	return n
end

local function join()
	local old = SPS:FindFirstChild("MilestoneTree")
	if old then old:Destroy() end
	E.buildClient()
	local p = M.addPlayer("Tester", 1)
	localPlayer = p
	Players.__props.LocalPlayer = p
	frames(0.2)
	E.runMain("Main")
	return p
end
local function textOf(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if (d.__class == "TextLabel" or d.__class == "TextButton") and (d.Text or "") ~= "" then table.insert(out, d.Text) end
	end
	return string.gsub(table.concat(out, " | "), "<[^>]*>", "")
end
local function nodeCount(pg)
	local n = 0
	local f = pg.MapGui.Root.Box.Nodes
	for _, c in f:GetChildren() do if string.sub(c.Name, 1, 5) == "Node_" and c:GetAttribute("State") then n += 1 end end
	return n
end
local function key(code)
	local UIS = game:GetService("UserInputService")
	UIS.InputBegan:Fire({ UserInputType = M.G.Enum.UserInputType.Keyboard, KeyCode = code, Position = E.Vector2.new(0, 0) }, false)
	frames(0.05)
end

print("== player joins")
local p = join()
frames(1.5)
local pg = p:FindFirstChild("PlayerGui")
local capsuleAmount = pg.TopbarGui.Root.Capsule.Row.Amount
check(capsuleAmount.Text ~= "", "within 1.5 s the points capsule shows the points (" .. capsuleAmount.Text .. ")")
check(nodeCount(pg) >= 2, "the map shows the layer nodes (" .. nodeCount(pg) .. ")")
local screen = pg.OverlayGui.Root.Screen
check(not screen.Visible, "the loading screen is gone")
if STUDIO then
	local status = pg.TopbarGui.Root.Status
	check(status.Visible and string.find(string.lower(status.Label.Text), "not saving", 1, true) ~= nil, "without DataStores the status chip reads NOT SAVING")
	check((M.errors or 0) == 0, "no script errors (" .. tostring(M.errors or 0) .. ")")
	print(if failures == 0 then "roblox (studio, no DataStore): all checks passed" else ("roblox (studio): " .. failures .. " checks FAILED"))
	if failures > 0 then error("roblox (studio): " .. failures .. " FAILED", 0) end
	return
end
frames(1.5)
local actor = SSS.MilestoneTree:FindFirstChild("Sessions") and SSS.MilestoneTree.Sessions:FindFirstChild("Player_1")
check(actor ~= nil, "the player's Actor is running")
check(sent > 0, "views reached the client (" .. sent .. " patches)")
local startPts = capsuleAmount.Text

-- a tap on M opens its panel beside the map; its tab arrives
local nodesF = pg.MapGui.Root.Box.Nodes
local sheet = pg.PanelGui.Root.Sheet
local n0 = #acts
nodesF.Node_m.Hit.Activated:Fire()
frames(0.5)
check(count("tab", "m", n0) == 1, "a tap on M sends {\"tab\", \"m\"} once")
check(sheet.Visible and string.find(textOf(sheet.Title.Parent == sheet and sheet or sheet), "MILESTONE", 1, true) ~= nil, "the panel's title reads MILESTONE")
local tabRoot = sheet.Body.Scroll.TabRoot
check(#tabRoot:GetDescendants() > 5, "the Milestone tab has content")

-- play: press every card that is not locked (and the hero's CTA), now and then, like a player would
-- (one press every 40 ms: the panel drops presses closer than 30 ms apart, like a double tap)
local function pressCards()
	local n = 0
	local cta = sheet.Hero:FindFirstChild("Cta")
	if cta and cta.Visible then
		cta.Activated:Fire()
		n += 1
		frames(0.04)
	end
	for _, d in tabRoot:GetDescendants() do
		if n >= 12 then break end
		-- the game's own cards (Render names them by their view path); a signature's extra buttons move around
		if d.__class == "TextButton" and d.Visible ~= false and d.Parent and string.sub(d.Name, 1, 4) == "tab." then
			local st = d:GetAttribute("State")
			if st == "can" or st == "notyet" then
				d.Activated:Fire()
				n += 1
				frames(0.04)
			end
		end
	end
	return n
end
local function openNode(l)
	local node = nodesF:FindFirstChild("Node_" .. l)
	local st = node and node:GetAttribute("State")
	if node == nil or st == "sealed" or st == "frontier" or st == "dormant" then return false end
	node.Hit.Activated:Fire()
	frames(0.4)
	return true
end
local pressed = 0
for round = 1, 40 do
	pressed += pressCards()
	frames(0.5)
	if round % 8 == 0 then
		openNode(if round % 16 == 0 then "m" else "p")
	end
end
print("  pressed " .. pressed .. " cards; points now " .. capsuleAmount.Text)
check(capsuleAmount.Text ~= startPts, "playing changed the points (" .. startPts .. " -> " .. capsuleAmount.Text .. ")")
check(openNode("p"), "the Prestige layer opens from its node")
frames(0.5)
check(string.find(string.lower(textOf(sheet)), "prestige points", 1, true) ~= nil, "the Prestige panel is drawn")
check(openNode("m"), "back to the Milestone layer")
frames(0.5)
local msText = string.lower(textOf(tabRoot))
check(string.find(msText, "milestone", 1, true) ~= nil, "the Milestone tab is drawn after switching layers")
check(#payloadErrors == 0, "every remote payload is carryable" .. (if #payloadErrors > 0 then ": " .. payloadErrors[1] else ""))
print(string.format("  %d patches, avg %.1f KB, max %.1f KB", sent, sentBytes / sent / 1024, maxBytes / 1024))
local instances = #pg.PanelGui:GetDescendants()
check(instances <= 900, "the panel stays small (" .. instances .. " instances under PanelGui)")

-- Esc closes the panel
n0 = #acts
key(M.G.Enum.KeyCode.Escape)
frames(0.4)
check(count("tab", "none", n0) == 1 and not sheet.Visible, "Esc sends {\"tab\", \"none\"} once and closes the panel")

-- OPTIONS, then Export save: the modal shows the save string
local ov = pg.OverlayGui.Root
pg.HudGui.Root.Dock.Options.Activated:Fire()
frames(0.5)
check(sheet.Visible, "OPTIONS opens the Options panel")
local function optButton(id)
	local path = optPaths[id]
	if path == nil then return nil end
	for _, d in pg.PanelGui:GetDescendants() do
		if d.Name == path and (d.__class == "TextButton" or d.__class == "ImageButton") then return d end
	end
	return nil
end
local exportBtn = optButton("export")
check(exportBtn ~= nil, "the Export save row")
if exportBtn then exportBtn.Activated:Fire() end
frames(0.5)
local modalBox = ov.Modal:FindFirstChild("Well") and ov.Modal.Well.Box
check(ov.Modal.Visible and modalBox and #modalBox.Text >= 100, "Export shows the save string in the modal")
local exported = modalBox and modalBox.Text
key(M.G.Enum.KeyCode.Escape)
key(M.G.Enum.KeyCode.Escape)
frames(0.3)

print("== player leaves")
local store = M.stores.MilestoneTreeNG_v1
M.removePlayer(p)
frames(2)
local rec = store and store.player_1
check(rec ~= nil and type(rec.save) == "string" and #rec.save > 1000, "save written to the DataStore")
check(rec ~= nil and rec.lock == nil, "save lock released on leaving")
check(SSS.MilestoneTree.Sessions:FindFirstChild("Player_1") == nil, "the Actor is gone")
local savedPts = rec and string.match(rec.save, '"points":"([^"]+)"')
print("  saved points: " .. tostring(savedPts))

print("== player rejoins")
sent = 0
-- a rejoin is a new client: drop the old client's handlers
for _, r in RS.MilestoneTreeRemotes:GetChildren() do r.__events.OnClientEvent = nil end
local RunService = game:GetService("RunService")
RunService.PreRender.handlers = {}
local UIS = game:GetService("UserInputService")
for _, e in { "InputBegan", "InputChanged", "InputEnded" } do UIS[e].handlers = {} end
p = join()
frames(3)
pg = p:FindFirstChild("PlayerGui")
capsuleAmount = pg.TopbarGui.Root.Capsule.Row.Amount
check(sent > 0 and capsuleAmount.Text ~= "", "the screen is back after the rejoin")
check(capsuleAmount.Text ~= "10.00" and capsuleAmount.Text ~= startPts, "progress restored after the rejoin (" .. capsuleAmount.Text .. ")")
local rec2 = store.player_1
check(rec2.lock ~= nil, "save locked again while playing")

-- import the exported save back through the modal (the web export format)
if exported then
	sheet = pg.PanelGui.Root.Sheet
	tabRoot = sheet.Body.Scroll.TabRoot
	ov = pg.OverlayGui.Root
	pg.HudGui.Root.Dock.Options.Activated:Fire()
	frames(0.5)
	local function importButton()
		return optButton("import")
	end
	local importBtn = importButton()
	if importBtn then importBtn.Activated:Fire() end
	frames(0.5)
	check(ov.Modal.Visible and ov.Modal:GetAttribute("Kind") == "import", "Import opens the import modal")
	ov.Modal.Well.Box.Text = exported
	ov.Modal.Buttons.Primary.Activated:Fire()
	frames(1)
	check(not ov.Modal.Visible, "a good save imports and closes the modal")
	frames(11)
	if not sheet.Visible then
		pg.HudGui.Root.Dock.Options.Activated:Fire()
		frames(0.5)
	end
	importBtn = importButton()
	check(importBtn ~= nil, "the Options panel is still there after the import")
	if importBtn then importBtn.Activated:Fire() end
	frames(0.5)
	ov.Modal.Well.Box.Text = "garbage"
	ov.Modal.Buttons.Primary.Activated:Fire()
	frames(1)
	check(ov.Modal.Visible and ov.Modal.Result.Visible, "a bad string shows the inline error")
	key(M.G.Enum.KeyCode.Escape)
	key(M.G.Enum.KeyCode.Escape)
end

-- a phone-sized screen: the panel is full screen and the map is off
local Workspace = game:GetService("Workspace")
Workspace.CurrentCamera.__props.ViewportSize = E.Vector2.new(844, 390)
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Fire()
frames(0.5)
nodesF = pg.MapGui.Root.Box.Nodes
sheet = pg.PanelGui.Root.Sheet
openNode("p")
frames(0.5)
check(sheet.Visible and not pg.MapGui.Enabled, "844 x 390: the sheet is full screen and MapGui is off")
local band = pg.TopbarGui.Root.PanelBand
check(band.Visible and band.Close.Size.X.Offset >= 44, "the band's close is at least 44 du")
band.Close.Activated:Fire()
frames(0.5)
check(pg.MapGui.Enabled and not sheet.Visible, "the band's close brings the map back")

check(E.warnings == 0, "no [MilestoneTree] warnings while playing (" .. E.warnings .. ")")

print("== a second player joins while the DataStore is down")
store.player_2 = { save = "{\"points\":\"1e100\"}", time = 1 }
M.failStore = true
local p2 = M.addPlayer("Unlucky", 2)
frames(20)
local a2 = SSS.MilestoneTree.Sessions:FindFirstChild("Player_2")
check(a2 ~= nil, "their game still starts")
M.failStore = false
M.removePlayer(p2)
frames(2)
check(store.player_2.save == "{\"points\":\"1e100\"}", "their real save was not overwritten")

print("== the server shuts down")
for _, f in M.closers do task.spawn(f) end
frames(3)
check(store.player_1.lock == nil, "shutdown saved and released the lock")

check((M.errors or 0) == 0, "no script errors (" .. tostring(M.errors or 0) .. ")")
print(if failures == 0 then "roblox: all checks passed" else ("roblox: " .. failures .. " checks FAILED"))
if failures > 0 then error("roblox: " .. failures .. " FAILED", 0) end
