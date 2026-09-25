--!nocheck
--[[
	The Roblox scripts end to end on the mock engine (tests/mock.luau): the real Main.server, Worker (in an Actor),
	Store, Session, the game, Main.client, Render and Style. A player joins, plays through button presses on the
	drawn screen, leaves (the save goes to the in-memory DataStore), rejoins (the save comes back), and the server
	shuts down. Every remote payload is checked against Roblox's rules for what a RemoteEvent can carry.
	Run tools/wrap_scripts.py first (test.sh roblox does).
]]
local M = require("./mock")
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

local client = Instance.new("Folder"); client.Name = "MilestoneTree"; client.Parent = SPS
scriptModule(client, "Style", "client/Style")
scriptModule(client, "Render", "client/Render")
local clientMain = Instance.new("LocalScript"); clientMain.Name = "Main"; clientMain.Parent = client

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
M.fireClient = function(remote, player, ...)
	if player ~= localPlayer then return end
	local args = table.pack(...)
	for i = 1, args.n do args[i] = carry(args[i], remote.Name .. "#" .. i) end
	sent += 1
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

print("== server starts")
mainScript.Parent = server
M.runScript(mainScript, require(W .. "server/Main"))
check(RS:FindFirstChild("MilestoneTreeRemotes") ~= nil, "remotes created")

local function join()
	local p = M.addPlayer("Tester", 1)
	localPlayer = p
	Players.__props.LocalPlayer = p
	M.step(0.2)
	M.runScript(clientMain, require(W .. "client/Main"))
	return p
end

print("== player joins")
local p = join()
if STUDIO then
	M.step(1.5)
	local pg0 = p:FindFirstChild("PlayerGui")
	local scr = pg0 and pg0:FindFirstChild("MilestoneTree")
	local n = 0
	if scr then for _, d in scr.Page.Menu.MenuRoot:GetDescendants() do if d.ClassName == "TextButton" then n += 1 end end end
	check(n >= 4, "without DataStores the game is on screen within 1.5 s (" .. n .. " menu buttons)")
	check(scr and not scr.Page.Main.Status.Visible, "the loading message is gone")
	local ov = pg0:FindFirstChild("MilestoneTreeOverlay")
	check(ov and ov.Unsaved.Visible, "the not-saved banner is up")
	check((M.errors or 0) == 0, "no script errors (" .. tostring(M.errors or 0) .. ")")
	print(if failures == 0 then "roblox (studio, no DataStore): all checks passed" else ("roblox (studio): " .. failures .. " checks FAILED"))
	return
end
M.step(3)
local pg = p:FindFirstChild("PlayerGui")
local screen = pg and pg:FindFirstChild("MilestoneTree")
check(screen ~= nil, "client built its ScreenGui")
local actor = SSS.MilestoneTree:FindFirstChild("Sessions") and SSS.MilestoneTree.Sessions:FindFirstChild("Player_1")
check(actor ~= nil, "the player's Actor is running")
check(sent > 0, "views reached the client (" .. sent .. " patches)")

local function all(root, pred)
	local out = {}
	for _, d in root:GetDescendants() do if pred(d) then table.insert(out, d) end end
	return out
end
local function textOf(b)
	local l = b:FindFirstChild("Label")
	return l and l.Text or ""
end
local page = screen.Page
local menuRoot = page.Menu.MenuRoot
local tabRoot = page.Main.TabRoot
local headRoot = page.Main.HeadRoot
local menuButtons = all(menuRoot, function(d) return d.ClassName == "TextButton" end)
check(#menuButtons >= 4, "menu drawn (" .. #menuButtons .. " buttons)")
local headText = ""
for _, d in headRoot:GetDescendants() do if d.ClassName == "TextLabel" and d.Text ~= "" then headText ..= d.Text .. " | " end end
check(string.find(headText, "points") ~= nil, "header shows points: " .. string.sub(string.gsub(headText, "<[^>]*>", ""), 1, 70))
local tabButtons = all(tabRoot, function(d) return d.ClassName == "TextButton" end)
check(#tabButtons > 0, "the milestone tab has buttons (" .. #tabButtons .. ")")

-- play: press every button that looks affordable, now and then, like a player would
local function pressAffordable()
	local n = 0
	for _, b in all(tabRoot, function(d) return d.ClassName == "TextButton" and d.Active end) do
		local c = b.BackgroundColor3
		-- locked buttons are #bf8f8f and bought ones #77bf5f; anything else on the tab is worth a press
		local locked = c and math.abs(c.R - 0xbf / 255) < 0.01 and math.abs(c.G - 0x8f / 255) < 0.01
		if not locked then b.Activated:Fire(); n += 1 end
	end
	return n
end
local function openLayer(label)
	for _, b in all(menuRoot, function(d) return d.ClassName == "TextButton" end) do
		if string.find(textOf(b), label, 1, true) then b.Activated:Fire(); return true end
	end
	return false
end
for round = 1, 40 do
	pressAffordable()
	M.step(0.5)
	if round % 8 == 0 then
		openLayer(if round % 16 == 0 then "Milestone" else "Prestige Points")
		M.step(0.3)
	end
end
headText = ""
for _, d in headRoot:GetDescendants() do if d.ClassName == "TextLabel" and d.Text ~= "" then headText = headText .. d.Text end end
print("  header now: " .. string.sub(string.gsub(headText, "<[^>]*>", ""), 1, 90))
local session = nil
check(openLayer("Prestige Points"), "the Prestige layer opens from the menu")
M.step(0.5)
local prestigeText = ""
for _, d in tabRoot:GetDescendants() do if d.ClassName == "TextLabel" then prestigeText ..= d.Text end end
check(string.find(prestigeText, "prestige points") ~= nil, "Prestige tab drawn")
check(openLayer("Milestone"), "back to the Milestone layer")
M.step(0.5)
local msText = ""
for _, d in tabRoot:GetDescendants() do if d.ClassName == "TextLabel" then msText ..= d.Text .. "\n" end end
check(string.find(msText, "milestones", 1, true) ~= nil and string.find(msText, "cost exponent", 1, true) ~= nil, "Milestone tab text drawn after switching tabs")
check(not page.Main.Status.Visible, "no drawing errors on screen" .. (if page.Main.Status.Visible then ": " .. page.Main.Status.Text else ""))
check(#payloadErrors == 0, "every remote payload is carryable" .. (if #payloadErrors > 0 then ": " .. payloadErrors[1] else ""))
print(string.format("  %d patches, avg %.1f KB, max %.1f KB", sent, sentBytes / sent / 1024, maxBytes / 1024))

-- hotkeys and options
local optOpened = openLayer("Options")
M.step(0.3)
check(optOpened, "options open")
local optButtons = all(tabRoot, function(d) return d.ClassName == "TextButton" end)
local exportBtn
for _, b in optButtons do if string.find(textOf(b), "Export", 1, true) then exportBtn = b end end
check(exportBtn ~= nil, "Export save button")
if exportBtn then exportBtn.Activated:Fire() end
M.step(0.3)
local overlay = pg:FindFirstChild("MilestoneTreeOverlay")
local modal = overlay and overlay.Modal
check(modal and modal.Visible and #modal:FindFirstChildOfClass("TextBox").Text > 100, "export shows the save string")
local exported = modal and modal:FindFirstChildOfClass("TextBox").Text

print("== player leaves")
local store = M.stores.MilestoneTreeNG_v1
M.removePlayer(p)
M.step(2)
local rec = store and store.player_1
check(rec ~= nil and type(rec.save) == "string" and #rec.save > 1000, "save written to the DataStore")
check(rec ~= nil and rec.lock == nil, "save lock released on leaving")
check(SSS.MilestoneTree.Sessions:FindFirstChild("Player_1") == nil, "the Actor is gone")
local savedPts = rec and string.match(rec.save, '"points":"([^"]+)"')
print("  saved points: " .. tostring(savedPts))

print("== player rejoins")
sent = 0
screen:Destroy()
overlay:Destroy()
-- a rejoin is a new client: drop the old client's handlers
for _, r in RS.MilestoneTreeRemotes:GetChildren() do r.__events.OnClientEvent = nil end
p = join()
M.step(3)
pg = p:FindFirstChild("PlayerGui")
screen = pg:FindFirstChild("MilestoneTree")
headText = ""
for _, d in screen.Page.Main.HeadRoot:GetDescendants() do if d.ClassName == "TextLabel" then headText ..= d.Text end end
check(sent > 0 and string.find(headText, "points") ~= nil, "screen back after rejoin")
local plainHead = string.gsub(headText, "<[^>]*>", "")
check(string.find(plainHead, "You have 10.00 ", 1, true) == nil, "progress restored after rejoin: " .. string.sub(plainHead, 1, 50))
local rec2 = store.player_1
check(rec2.lock ~= nil, "save locked again while playing")

-- import the exported save back (the web export format)
if exported then
	local imp = SSS.MilestoneTree.Sessions:FindFirstChild("Player_1")
	RS.MilestoneTreeRemotes.Import:FireServer(exported)
	M.step(0.5)
	check(true, "import accepted without errors")
end

print("== a second player joins while the DataStore is down")
store.player_2 = { save = "{\"points\":\"1e100\"}", time = 1 }
M.failStore = true
local p2 = M.addPlayer("Unlucky", 2)
M.step(20)
local a2 = SSS.MilestoneTree.Sessions:FindFirstChild("Player_2")
check(a2 ~= nil, "their game still starts")
M.failStore = false
M.removePlayer(p2)
M.step(2)
check(store.player_2.save == "{\"points\":\"1e100\"}", "their real save was not overwritten")

print("== the server shuts down")
for _, f in M.closers do task.spawn(f) end
M.step(3)
check(store.player_1.lock == nil, "shutdown saved and released the lock")

check((M.errors or 0) == 0, "no script errors (" .. tostring(M.errors or 0) .. ")")
print(if failures == 0 then "roblox: all checks passed" else ("roblox: " .. failures .. " checks FAILED"))
