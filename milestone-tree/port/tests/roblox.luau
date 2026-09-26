--!nocheck
--[[
	The Roblox scripts end to end on the mock engine (tests/mock.luau + tests/engine.luau): the real Main.server,
	Worker (in an Actor), Store, Session, the game, and the whole client (Main.client -> App: the map, the HUD, the
	panel with Render and the skins, the overlays). A player joins and plays through the new UI the way a player
	would (DESIGN.md 16 anchors): taps a node, presses the cards and the hero's CTA, switches layers, closes with Esc,
	opens OPTIONS (Save only: no export, import or hard reset), leaves (the save goes to the in-memory DataStore),
	rejoins (the save comes back); a phone-sized screen gets the full-screen panel; the server shuts down. Every remote payload
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
M.module(shared, "PrefsSchema", function() return require("../../src/shared/PrefsSchema") end)
M.module(shared, "Products", function() return require("../../src/shared/Products") end)
local boardsInst
boardsInst = M.module(shared, "Boards", function() return M.withScript(boardsInst, require(W .. "shared/Boards")) end)

local server = Instance.new("Folder"); server.Name = "MilestoneTree"; server.Parent = SSS
local function scriptModule(parent, name, wrapPath)
	local inst
	inst = M.module(parent, name, function() return M.withScript(inst, require(W .. wrapPath)) end)
	return inst
end
scriptModule(server, "Config", "server/Config")
scriptModule(server, "Store", "server/Store")
scriptModule(server, "Shop", "server/Shop")
scriptModule(server, "Leaderboards", "server/Leaderboards")
local softInst = scriptModule(server, "SoftShutdown", "server/SoftShutdown")
M.module(server, "Session", function() return L.Session end)
local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = server
M.module(runtime, "JSRT", function() return L.JSRT end)
M.module(runtime, "BEcore", function() return L.BEcore end)
M.module(runtime, "Fast", function() return L.Fast end)
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
M.invokeServer = function(remote, ...)
	local f = remote.OnServerInvoke
	if f == nil then return nil end
	return M.deep(f(localPlayer, ...))
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

-- the Shop: test ids for the passes and a product; the player owns 2x Speed before joining
local Products = require("../../src/shared/Products")
Products.passes[1].id = 111
Products.passes[2].id = 112
Products.products[1].id = 221
Products.products[2].id = nil -- the SOON state
M.passes[1] = { [111] = true }

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

-- OPTIONS: the Options panel
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
-- saves live in Roblox: Options has Save but no Export, Import or Hard Reset
check(optButton("save") ~= nil, "the Save row")
check(optButton("export") == nil and optButton("import") == nil and optButton("hardReset") == nil,
	"no Export, Import or Hard Reset rows")
key(M.G.Enum.KeyCode.Escape)
frames(0.3)

print("== shop")
local MPS = game:GetService("MarketplaceService")
local perksRaw = p:GetAttribute("MT_Perks")
check(type(perksRaw) == "string" and string.find(perksRaw, "speed", 1, true) ~= nil, "a pass owned before joining is a perk (" .. tostring(perksRaw) .. ")")
local function plain(s) return (string.gsub(string.gsub(s or "", "<[^>]*>", ""), "\u{200A}", "")) end
check(string.find(plain(pg.TopbarGui.Root.Capsule.Label.Text), "SPEED", 1, true) ~= nil, "the capsule label shows 2x SPEED (" .. plain(pg.TopbarGui.Root.Capsule.Label.Text) .. ")")
local infoText = plain(pg.TopbarGui.Root.Info.Label.Text)
check(string.find(infoText, "2× SPEED", 1, true) ~= nil and string.find(infoText, "ACTIVE", 1, true) ~= nil
	and string.find(string.upper(infoText), "DEV", 1, true) == nil, "the speed pass reads 2× SPEED · ACTIVE, never dev speed (" .. infoText .. ")")
pg.HudGui.Root.Dock.Shop.Activated:Fire()
frames(0.4)
local modal = pg.OverlayGui.Root:FindFirstChild("Modal")
check(modal ~= nil and modal.Visible and modal:GetAttribute("Kind") == "shop", "the dock's SHOP opens the Shop")
check(modal and modal:FindFirstChild("Item_speed") and modal.Item_speed:FindFirstChild("Owned") ~= nil, "the owned pass reads OWNED")
check(modal and modal:FindFirstChild("Item_warp8") and modal.Item_warp8:FindFirstChild("Soon") ~= nil, "a product without an id reads SOON")
local icon = modal and modal:FindFirstChild("Item_warp1") and modal.Item_warp1:FindFirstChild("Icon")
check(icon ~= nil and icon.Image == "rbxassetid://" .. tostring(Products.products[1].icon), "a shop row shows the item's icon")
local buy = modal and modal:FindFirstChild("Item_supporter") and modal.Item_supporter:FindFirstChild("Buy")
if buy then buy.Activated:Fire() end
local last = M.prompts[#M.prompts]
check(last ~= nil and last[1] == "pass" and last[3] == 112, "BUY on Supporter opens Roblox's pass prompt")
MPS.PromptGamePassPurchaseFinished:Fire(p, 112, true)
frames(0.5)
check(string.find(p:GetAttribute("MT_Perks") or "", "supporter", 1, true) ~= nil, "a pass bought in game counts at once")
modal = pg.OverlayGui.Root:FindFirstChild("Modal")
check(modal and modal:FindFirstChild("Item_supporter") and modal.Item_supporter:FindFirstChild("Owned") ~= nil, "the open Shop redraws: Supporter OWNED")
check(string.find(plain(pg.TopbarGui.Root.Capsule.Label.Text), "SUPPORTER", 1, true) ~= nil, "the capsule label shows SUPPORTER")
key(M.G.Enum.KeyCode.Escape)
frames(0.2)
-- a Time Warp receipt is granted once, even when Roblox sends it again
local warps = 0
local InstMT = getmetatable(actor)
local send = InstMT.SendMessage
InstMT.SendMessage = function(self2, topic, ...)
	if topic == "warp" then warps += 1 end
	return send(self2, topic, ...)
end
local info = { ProductId = 221, PlayerId = 1, PurchaseId = "r1", CurrencySpent = 29 }
local d1 = MPS.ProcessReceipt(info)
frames(0.5)
local d2 = MPS.ProcessReceipt(info)
frames(0.5)
InstMT.SendMessage = send
local G = M.G.Enum.ProductPurchaseDecision.PurchaseGranted
check(d1 == G and d2 == G, "the receipt is granted (twice asked: " .. tostring(d1) .. ", " .. tostring(d2) .. ")")
check(warps == 1, "the Time Warp went to the game once (" .. warps .. ")")
check(M.stores.MilestoneTreeNG_v1["receipt_r1"] ~= nil, "the receipt is recorded in the DataStore")
check(string.find(textOf(pg.OverlayGui), "on its way", 1, true) ~= nil, "a toast says the Time Warp is on its way")
local w0 = E.warnings
local unknown = MPS.ProcessReceipt({ ProductId = 999, PlayerId = 1, PurchaseId = "r2" })
check(unknown == M.G.Enum.ProductPurchaseDecision.NotProcessedYet and E.warnings == w0 + 1, "an unknown product is not granted (and warns)")
E.warnings = w0

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
-- the leaderboards: the stats went out on leaving (only what the server's game holds), with the real playtime
local lbPoints = M.stores["ordered:LB_points_v1"]
local lbTime = M.stores["ordered:LB_time_v1"]
local lbM = M.stores["ordered:LB_m_v1"]
check(lbPoints ~= nil and type(lbPoints["1"]) == "number" and lbPoints["1"] > 0, "the points board got the player's points (" .. tostring(lbPoints and lbPoints["1"]) .. ")")
check(lbM ~= nil and type(lbM["1"]) == "number", "the Milestones board got a count (" .. tostring(lbM and lbM["1"]) .. ")")
check(lbTime ~= nil and type(lbTime["1"]) == "number" and lbTime["1"] >= 3, "the playtime board got real seconds (" .. tostring(lbTime and lbTime["1"]) .. ")")
check(rec ~= nil and type(rec.played) == "number" and rec.played >= 3, "the save keeps the playtime (" .. tostring(rec and rec.played) .. ")")
local lbRobux = M.stores["ordered:LB_robux_v1"]
check(lbRobux ~= nil and lbRobux["1"] == 29 + 99, "the Robux board counts the Time Warp once and the Supporter pass (R$ 29 + 99 = " .. tostring(lbRobux and lbRobux["1"]) .. ")")

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

-- the new client's panel after the rejoin
sheet = pg.PanelGui.Root.Sheet
tabRoot = sheet.Body.Scroll.TabRoot
ov = pg.OverlayGui.Root
pg.HudGui.Root.Dock.Options.Activated:Fire()
frames(0.5)
check(sheet.Visible, "OPTIONS opens the Options panel after the rejoin")

-- a phone-sized screen: the same layout scaled by aspect ratio (a side sheet beside the map strip)
local Workspace = game:GetService("Workspace")
Workspace.CurrentCamera.__props.ViewportSize = E.Vector2.new(844, 390)
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Fire()
frames(0.5)
nodesF = pg.MapGui.Root.Box.Nodes
sheet = pg.PanelGui.Root.Sheet
openNode("p")
frames(0.5)
check(sheet.Visible and pg.MapGui.Enabled, "844 x 390: the panel opens beside the map (aspect-scaled desktop layout)")
check(sheet.Close.Visible and sheet.Close.Size.X.Offset * 0.55 >= 22, "the close button stays a usable size once scaled")
sheet.Close.Activated:Fire()
frames(0.5)
check(pg.MapGui.Enabled and not sheet.Visible, "the close brings the map back")

check(E.warnings == 0, "no [MilestoneTree] warnings while playing (" .. E.warnings .. ")")

print("== leaderboards")
local boardRemote = RS.MilestoneTreeRemotes:FindFirstChild("Board")
check(boardRemote ~= nil and boardRemote.ClassName == "RemoteFunction", "the Board remote exists")
M.stores["ordered:LB_points_v1"]["777"] = 1 -- another player, far behind
local page = boardRemote and boardRemote:InvokeServer("points")
check(page ~= nil and page.ok and #page.entries == 2, "a board page lists the players (" .. tostring(page and #page.entries) .. ")")
local top = page and page.entries[1]
check(top ~= nil and top.rank == 1 and top.id == 1 and top.name == "Player1" and type(top.value) == "string" and top.value ~= "",
	"rank 1 has the display name and a value (" .. tostring(top and top.name) .. " " .. tostring(top and top.value) .. ")")
check(page ~= nil and page.you == (top and top.value), "the page has the player's own value (" .. tostring(page and page.you) .. ")")
local quick = boardRemote:InvokeServer("time")
check(quick ~= nil and quick.ok == false, "a second page within half a second is refused")
frames(0.6)
local t = boardRemote:InvokeServer("time")
check(t ~= nil and t.ok and t.entries[1] and string.match(t.entries[1].value, "%dm$") ~= nil, "playtime reads as time (" .. tostring(t and t.entries[1] and t.entries[1].value) .. ")")
frames(0.6)
check(boardRemote:InvokeServer("nope") == nil and boardRemote:InvokeServer(123) == nil, "unknown boards and bad arguments get nothing")
print("== the player list")
frames(3.5)
check(type(p:GetAttribute("MT_Pts")) == "string" and p:GetAttribute("MT_Pts") ~= "" and type(p:GetAttribute("MT_PtsKey")) == "number",
	"the server publishes the player's points for the list (" .. tostring(p:GetAttribute("MT_Pts")) .. ")")
check(type(p:GetAttribute("MT_Played")) == "number" and p:GetAttribute("MT_Played") >= 1, "and the playtime (" .. tostring(p:GetAttribute("MT_Played")) .. " s)")
pg.TopbarGui.Root.PlayerList.Chip.Activated:Fire()
frames(0.2)
local plRow = pg.TopbarGui.Root.PlayerList.Panel:FindFirstChild("Row_1")
check(plRow ~= nil and plRow.Points.Text == p:GetAttribute("MT_Pts"), "the open list shows the player's points (" .. tostring(plRow and plRow.Points.Text) .. ")")
pg.TopbarGui.Root.PlayerList.Chip.Activated:Fire()
frames(0.2)

print("== the RANKS window")
frames(0.6)
pg = p:FindFirstChild("PlayerGui")
pg.HudGui.Root.Dock.Ranks.Activated:Fire()
frames(1)
local modal = pg.OverlayGui.Root:FindFirstChild("Modal")
check(modal ~= nil and modal.Visible and modal:GetAttribute("Kind") == "ranks", "the dock's RANKS opens the leaderboards")
local strip = modal and modal:FindFirstChild("Tabs") and modal.Tabs:FindFirstChild("Strip")
local tabsN = 0
if strip then for _, c in strip:GetChildren() do if string.sub(c.Name, 1, 4) == "Tab_" then tabsN += 1 end end end
check(tabsN == 24, "a tab for every board (" .. tabsN .. ")")
local row1 = modal and modal:FindFirstChild("Rows") and modal.Rows:FindFirstChild("Row_1")
check(row1 ~= nil and row1.Name == "Row_1" and row1:FindFirstChild("Name") and row1.Name ~= nil and row1:FindFirstChild("Name").Text == "Player1",
	"the top row shows the leader's name (" .. tostring(row1 and row1:FindFirstChild("Name") and row1:FindFirstChild("Name").Text) .. ")")
check(row1 ~= nil and row1:FindFirstChild("Avatar") ~= nil and string.find(row1.Avatar.Image, "AvatarHeadShot", 1, true) ~= nil, "with the avatar headshot")
check(string.find(modal.Info.You.Text, "YOUR", 1, true) ~= nil or string.find(plain(modal.Info.You.Text), "YOUR", 1, true) ~= nil, "the player's own best shows")
frames(0.6)
modal.Tabs.Next.Activated:Fire()
frames(1)
check(modal.Info.Title.Text == "Milestones", "the arrow steps to the next board (" .. modal.Info.Title.Text .. ")")
check(modal.Tabs.Strip.Tab_m.BackgroundColor3 ~= modal.Tabs.Strip.Tab_points.BackgroundColor3, "the selected tab is lit")
frames(0.6)
modal.Tabs.Strip.Tab_time.Activated:Fire()
frames(1)
check(modal.Info.Title.Text == "Playtime", "a tab opens its board")
pg.OverlayGui.Root.ModalDimmer.Activated:Fire()
frames(0.3)

print("== a flood of requests is kicked")
local kicked0 = #M.kicked
for _ = 1, 450 do RS.MilestoneTreeRemotes.Act:FireServer("not an action") end
check(#M.kicked == kicked0 + 1 and M.kicked[#M.kicked].player == p, "a player flooding the remotes is kicked")
for _ = 1, 50 do RS.MilestoneTreeRemotes.Act:FireServer("not an action") end
check(#M.kicked == kicked0 + 1, "kicked once, not again and again")

print("== a second player joins while the DataStore is down")
store.player_2 = { save = "{\"points\":\"1e100\"}", time = 1 }
M.failStore = true
local p2 = M.addPlayer("Unlucky", 2)
frames(20)
local a2 = SSS.MilestoneTree.Sessions:FindFirstChild("Player_2")
check(a2 ~= nil, "their game still starts")
local d2 = MPS.ProcessReceipt({ ProductId = 221, PlayerId = 2, PurchaseId = "r2", CurrencySpent = 29 })
check(d2 == M.G.Enum.ProductPurchaseDecision.NotProcessedYet, "a Time Warp waits while their game cannot save (" .. tostring(d2) .. ")")
M.failStore = false
M.removePlayer(p2)
frames(2)
check(store.player_2.save == "{\"points\":\"1e100\"}", "their real save was not overwritten")

print("== a live server: a passing DataStore error (502) does not turn saving off")
M.studio = false
M.failMessage = "502: API Services rejected request with error. Error code: 0 Reason: Service unavailable (mock)"
M.failStore = true
local p3 = M.addPlayer("Blip", 3)
frames(1) -- the first load attempt fails
M.failStore = false
M.failMessage = nil
frames(20)
M.removePlayer(p3)
frames(3)
local rec3 = store.player_3
check(rec3 ~= nil and type(rec3.save) == "string", "the save is written once the store answers again (" .. tostring(rec3 and rec3.save and #rec3.save) .. ")")
M.studio = nil

print("== the server shuts down for an update (soft shutdown)")
M.studio = false -- a live server
for _, f in M.closers do task.spawn(f) end
frames(3)
check(store.player_1.lock == nil, "shutdown saved and released the lock")
local tp = M.teleports[1]
check(#M.teleports == 1 and tp.place == 76183483380423 and table.find(tp.players, p) ~= nil, "everyone is sent to a holding server at once")
check(tp and tp.options and tp.options.ShouldReserveServer == true and tp.options:GetTeleportData().mtSoftShutdown == true,
	"to a reserved server, marked as a soft shutdown")
M.studio = nil

print("== the holding server sends them back to the new version")
local Soft = M.require(softInst)
game.__props.PrivateServerId = "reserved-1"
M.joinData[1] = { mtSoftShutdown = true }
check(Soft.holding(), "a reserved server reached by the soft shutdown is a holding server")
local said = {}
local n0 = #M.teleports
Soft.hold(p, function(_, text) table.insert(said, text) end)
check(said[1] == "Updating to the new version", "the loading screen says the game is updating")
frames(Soft.HOLD_SECONDS - 1)
check(#M.teleports == n0, "the players wait while the old server saves")
frames(2)
local back = M.teleports[n0 + 1]
check(back ~= nil and back.place == 76183483380423 and back.options == nil and back.players[1] == p, "then they go back to a public server")
M.failTeleport = true
local n1 = #M.teleports
Soft.hold(p, function(_, text) table.insert(said, text) end)
frames(Soft.HOLD_SECONDS + 4)
M.failTeleport = false
frames(8)
check(#M.teleports == n1 + 1, "a failed teleport back is tried again")
game.__props.PrivateServerId = ""
check(not Soft.holding(), "a public server is not a holding server")

check((M.errors or 0) == 0, "no script errors (" .. tostring(M.errors or 0) .. ")")
print(if failures == 0 then "roblox: all checks passed" else ("roblox: " .. failures .. " checks FAILED"))
if failures > 0 then error("roblox: " .. failures .. " FAILED", 0) end
