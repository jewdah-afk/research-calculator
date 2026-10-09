--!nocheck
-- Headless UI harness (lune, no Studio): loads the real client UI modules on lune's Roblox instance model with
-- small service mocks, starts the HUD, pushes a real save state (server Game.fresh + MAXED-style numbers), opens
-- every window / tab / view, presses keys, and reports errors + instance counts per window.
-- Run from roblox/:  lune run tools/ui_harness/run.luau
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local task = require("@lune/task")
local process = require("@lune/process")

local Instance = roblox.Instance
local V2 = roblox.Vector2

-- ---------------------------------------------------------------- signals + missing engine members
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ fns = {} }, Signal) end
function Signal:Connect(fn) table.insert(self.fns, fn); local s = self; return { Disconnect = function() table.remove(s.fns, table.find(s.fns, fn) or 0) end, Connected = true } end
function Signal:Once(fn) return self:Connect(fn) end
function Signal:Wait() return nil end
function Signal:Fire(...) for _, f in table.clone(self.fns) do local ok, e = pcall(f, ...); if not ok then error(e, 0) end end end
-- lune hands out a new userdata per access, so instances are keyed by a uid attribute
local sigs = {}
local nextUid = 0
local function uid(inst)
	local u = inst:GetAttribute("__uid")
	if not u then nextUid += 1; u = nextUid; inst:SetAttribute("__uid", u) end
	return u
end
local function sig(inst, name)
	local k = uid(inst)
	local t = sigs[k]; if not t then t = {}; sigs[k] = t end
	local s = t[name]; if not s then s = Signal.new(); t[name] = s end
	return s
end
local GUI = { "Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ScrollingFrame", "CanvasGroup", "TextBox" }
for _, cls in GUI do
	for _, ev in { "MouseEnter", "MouseLeave", "InputBegan", "InputEnded" } do roblox.implementProperty(cls, ev, function(i) return sig(i, ev) end) end
end
for _, cls in { "TextButton", "ImageButton" } do
	for _, ev in { "Activated", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click" } do roblox.implementProperty(cls, ev, function(i) return sig(i, ev) end) end
end
roblox.implementProperty("NumberValue", "Changed", function(i) return sig(i, "Changed") end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementMethod("Sound", "Stop", function() end)
roblox.implementProperty("Sound", "Ended", function(i) return sig(i, "Ended") end)
roblox.implementMethod("Instance", "WaitForChild", function(i, n) local c = i:FindFirstChild(n); if not c then error("WaitForChild: no " .. n .. " in " .. i:GetFullName()) end; return c end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(i, p) return sig(i, "prop:" .. p) end)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(i, p) return sig(i, "attr:" .. p) end)
local function absSize(i)
	if not i:IsA("GuiObject") then return V2.new(1920, 1080) end
	local p = i.Parent
	local ps = if p and p:IsA("GuiObject") then absSize(p) else V2.new(1920, 1080)
	return V2.new(i.Size.X.Offset + i.Size.X.Scale * ps.X, i.Size.Y.Offset + i.Size.Y.Scale * ps.Y)
end
-- read-only engine values (AbsoluteSize / TextBounds) cannot be computed by lune: new GUI objects get zeros
local GUISET = {}
for _, c in GUI do GUISET[c] = true end
local HarnessInstance = { new = function(cls, parent)
	local i = Instance.new(cls)
	if GUISET[cls] then
		i.AbsoluteSize = V2.new(0, 0); i.AbsolutePosition = V2.new(0, 0)
		if cls == "TextLabel" or cls == "TextButton" or cls == "TextBox" then i.TextBounds = V2.new(0, 0) end
		if cls == "ScrollingFrame" then i.AbsoluteCanvasSize = V2.new(0, 0); i.AbsoluteWindowSize = V2.new(0, 0) end
	end
	if parent then i.Parent = parent end
	return i
end }
local _ = absSize

-- ---------------------------------------------------------------- services
local TweenInfo = { new = function(...) return { ... } end }
-- tweens land on their end values at once; Completed fires on the next resume (chained tweens run to the end), never
-- for a cancelled or looping tween
local function tween(inst, ti, props)
	local t = { Completed = Signal.new(), cancelled = false }
	function t.Play()
		for k, v in props do inst[k] = v end
		if ti and ti[4] and ti[4] ~= 0 then return end   -- TweenInfo.new(time, style, dir, repeatCount, ...)
		task.defer(function() if not t.cancelled then t.Completed:Fire(roblox.Enum.PlaybackState.Completed) end end)
	end
	function t.Cancel() t.cancelled = true end
	return t
end
local camera = { ViewportSize = V2.new(1920, 1080) }
function camera:WorldToViewportPoint(p) return roblox.Vector3.new(960, 540, 10), true end
function camera:GetPropertyChangedSignal() return Signal.new() end
local workspace = { CurrentCamera = camera }
local playerGui = Instance.new("Folder"); playerGui.Name = "PlayerGui"
local player = { DisplayName = "Tester", UserId = 1, Name = "Tester", Character = nil, PlayerGui = playerGui }
function player:WaitForChild(n) if n == "PlayerGui" then return playerGui end end
local playerAttrs, playerAttrSig = {}, {}
function player:GetAttribute(k) return playerAttrs[k] end
function player:SetAttribute(k, v) playerAttrs[k] = v; if playerAttrSig[k] then playerAttrSig[k]:Fire() end end
function player:GetAttributeChangedSignal(k) playerAttrSig[k] = playerAttrSig[k] or Signal.new(); return playerAttrSig[k] end
local RS = Instance.new("Folder"); RS.Name = "ReplicatedStorage"
local SSS = Instance.new("Folder"); SSS.Name = "ServerScriptService"
local services = {
	ReplicatedStorage = RS, ServerScriptService = SSS,
	TweenService = { Create = function(_, i, ti, p) return tween(i, ti, p) end },
	RunService = { RenderStepped = Signal.new(), Heartbeat = Signal.new(), Stepped = Signal.new(), IsStudio = function() return true end, IsClient = function() return true end, IsServer = function() return false end, BindToRenderStep = function() end },
	UserInputService = { InputBegan = Signal.new(), InputEnded = Signal.new(), InputChanged = Signal.new(), MouseEnabled = true, TouchEnabled = false,
		GetMouseLocation = function() return V2.new(0, 0) end, IsKeyDown = function() return false end },
	TextService = { GetTextSize = function(_, s, size) return V2.new(#s * size * 0.55, size) end },
	GuiService = { GetGuiInset = function() return V2.new(0, 58), V2.new(0, 0) end },
	Players = { LocalPlayer = player },
	GroupService = { PromptJoinAsync = function() end },
	ContentProvider = { PreloadAsync = function() end },
	SoundService = Instance.new("Folder"),
	UserGameSettings = { ReducedMotion = false },
	MarketplaceService = { PromptGamePassPurchase = function() end, PromptProductPurchase = function() end },
	HttpService = { JSONEncode = function(_, v) return serde.encode("json", v) end },
	DataStoreService = {}, StarterPlayer = Instance.new("Folder"),
}
local game = { GetService = function(_, n) local s = services[n]; if not s then error("no service mock " .. n) end; return s end, CreatorType = nil, CreatorId = 0 }

-- ---------------------------------------------------------------- module tree (mirrors default.project.json)
local function mount(dir, parent)
	for _, name in fs.readDir(dir) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			local f = Instance.new("Folder"); f.Name = name; f.Parent = parent
			mount(p, f)
		elseif string.sub(name, -5) == ".luau" then
			local base = string.sub(name, 1, -6)
			if not string.find(base, "%.") then
				local m = Instance.new("ModuleScript"); m.Name = base; m.Parent = parent; m:SetAttribute("path", p)
			end
		elseif string.sub(name, -5) == ".json" then
			local m = Instance.new("ModuleScript"); m.Name = string.sub(name, 1, -6); m.Parent = parent; m:SetAttribute("path", p)
		end
	end
end
local shared = Instance.new("Folder"); shared.Name = "Peckwood"; shared.Parent = RS
mount("src/shared", shared)
local client = Instance.new("Folder"); client.Name = "Peckwood"
mount("src/client", client)
local server = Instance.new("Folder"); server.Name = "Peckwood"; server.Parent = SSS
mount("src/server", server)
local Remotes = Instance.new("Folder"); Remotes.Name = "Remotes"; Remotes.Parent = shared

local cache = {}
local env
local function req(m)
	if type(m) == "table" then return m end
	local p = m:GetAttribute("path")
	if not p then error("require: not a module " .. tostring(m)) end
	if cache[p] ~= nil then return cache[p] end
	local src = fs.readFile(p)
	if string.sub(p, -5) == ".json" then cache[p] = serde.decode("json", src); return cache[p] end
	local e = table.clone(env)   -- lune copies the environment's own keys (no __index chain)
	e.script = m
	local fn = luau.load(src, { debugName = p, environment = e })
	local r = fn()
	cache[p] = r
	return r
end
local warnings = {}
env = setmetatable({
	require = req, game = game, workspace = workspace, Instance = HarnessInstance, TweenInfo = TweenInfo, task = task,
	UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, Font = roblox.Font, Rect = roblox.Rect, CFrame = roblox.CFrame, NumberRange = roblox.NumberRange,
	typeof = typeof, warn = function(...) table.insert(warnings, table.concat({ ... }, " ")) end, tick = os.clock,
}, { __index = _G })
setmetatable(env, nil)

-- ---------------------------------------------------------------- run
local errors = {}
local function try(label, fn, ...)
	local ok, e = pcall(fn, ...)
	if not ok then table.insert(errors, label .. ": " .. tostring(e)); print("FAIL " .. label .. "\n  " .. tostring(e)) end
	return ok
end
local function count(i) local n = 0; for _ in i:GetDescendants() do n += 1 end; return n end

-- server state + derived (same fields Main.server derived() sends)
local G = req(server:FindFirstChild("Game"))
local Defs = req(shared:FindFirstChild("Defs"))
local EN = Defs.EN
local s = G.fresh()
s.island = #Defs.ISLANDS
s.evolutionCount = 5
s.rebirbCount = 14
for _, k in Defs.CUR_ORDER do s[k] = EN.fromNumber and EN.fromNumber(1.5e12) or 1.5e12 end
local d = {
	kernelValue = 10, interval = 1, cap = 24, reach = 30, speed = 1, plumeGain = 134, popPerSec = 2.5e11, seedsPerSec = 1000, twigsPerSec = 5, orePerSec = 99,
	goldenValue = 4, goldenChance = 0.045, evoProgress = 0.4, seagullInterval = 10, fishInterval = 4, tankCount = 2,
	parrot = { hp = 120, dmg = 30, regen = 2 }, rodRows = {}, recentSell = {}, nextGoal = "Every island is open", nextCost = nil,
	autoAllowed = true, devAllowed = true, mode = "maxed", groupId = 0, discovered = 60, shop = { passes = {}, boostLeft = 0, testGrants = true },
}
local fired = {}
local function remote(name)
	local r = { Name = name, OnClientEvent = Signal.new() }
	function r:FireServer(...) table.insert(fired, { name, ... }) end
	return r
end
local remotes = { State = remote("State"), Fish = remote("Fish"), Toast = remote("Toast"), Action = remote("Action"), Spawn = remote("Spawn"), Collect = remote("Collect") }

local UI = client:FindFirstChild("UI")
-- stand the bird on an area (default the Bridge, like the Figma HUD mock 229:7) so context bar / hotbar show
do
	local World = req(shared:FindFirstChild("World"))
	World.open = 99   -- IslandView.sync sets this in game (every area unlocked on the MAXED-like save)
	local isl = World.byId[process.env.PECK_AREA or "bridge"]
	if isl then
		local hrp = { Position = roblox.Vector3.new((isl.cx - 20) * 4, 0, (isl.cz - 15) * 4) }
		player.Character = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return hrp end end }
	end
end
local Hud
try("require Hud", function() Hud = req(UI:FindFirstChild("Hud")) end)
if not Hud then for _, e in errors do print(e) end; process.exit(1) end
try("Hud.start", Hud.start, remotes)
try("State push", function() remotes.State.OnClientEvent:Fire(s, d) end)
try("Fish push", function()
	local disc, best, have = {}, {}, {}
	for i, f in Defs.FISH do if i % 3 == 0 then disc[f.id] = true; best[f.id] = i * 0.37; have[f.id] = i % 7 end end
	remotes.Fish.OnClientEvent:Fire(disc, best, have)
end)
local hudGui = playerGui:FindFirstChild("PeckwoodHUD")
print(("HUD built: %d instances"):format(hudGui and count(hudGui) or -1))

-- toasts from the server
for _, t in { { "bought", "p_value" }, { "poor", "p_value" }, { "molt", 134, true }, { "island", "mine", "THE MINE" }, { "fish", "fish_silver", 1.2 }, { "auto", true } } do
	try("toast " .. t[1], function() remotes.Toast.OnClientEvent:Fire(table.unpack(t)) end)
end

-- every window, every tab and view
local WM = req(UI:FindFirstChild("WindowManager"))
local Defs2 = req(UI:FindFirstChild("WindowDefs"))
local ids = {}
for id in Defs2 do table.insert(ids, id) end
table.sort(ids)
local winGui = playerGui:FindFirstChild("PeckwoodWindows")
for _, id in ids do
	local def = Defs2[id]
	local before = winGui and count(winGui) or 0
	if try("open " .. id, WM.open, id) then
		for _, tb in def.tabs or {} do
			if tb[2] then try("tab " .. id .. "/" .. tb[1], WM.open, id, tb[1]) end
		end
		for v, target in def.views or {} do
			local rec = WM.built[id]
			try("view " .. id .. "/" .. v, function() WM.show(rec, target) end)
		end
		try("update " .. id, function() remotes.State.OnClientEvent:Fire(s, d) end)
		-- press every key + click every tab / row once (handlers run; server intents are recorded)
		local rec = WM.built[id]
		local n = 0
		local hits = {}
		for _, h in rec.holder:GetDescendants() do if h.Name == "hit" and h:IsA("TextButton") then table.insert(hits, { h, h.Parent.Name }) end end
		print(("%-13s built: %d instances, %d pressable"):format(id, count(rec.holder), #hits))
		for _, hp in hits do
			local h = hp[1]
			if n < 80 and pcall(function() return h.Parent ~= nil and h.Name end) and h.Parent then
				n += 1
				try("press " .. id .. " " .. hp[2], function()
					sig(h, "MouseEnter"):Fire(); sig(h, "MouseButton1Down"):Fire(); sig(h, "MouseButton1Up"):Fire(); sig(h, "Activated"):Fire(); sig(h, "MouseLeave"):Fire()
				end)
			end
		end
		if id ~= "shop" then try("close " .. id, WM.close) end
		local rec2 = WM.built[id]
		local nv = 0; for _ in rec2.variants do nv += 1 end
		print(("%-13s variants built %d"):format(id, nv))
	end
end
-- ---------------------------------------------------------------- layout + motion checks (Birb placement pass)
local Layout = req(UI:FindFirstChild("Layout"))
local function check(label, ok, msg) if not ok then table.insert(errors, label .. ": " .. (msg or "")); print("FAIL " .. label .. " " .. (msg or "")) end end
local sidebar = WM.built.shop
WM.setDrawer(true)   -- the press-everything pass above also pressed the collapse tab
task.wait(0.3)
check("sidebar open", sidebar and sidebar.holder.Visible and Layout.sidebarOpen)
local function rect(holder, fit)
	local s = fit.Scale
	local w, h = holder.Size.X.Offset * s, holder.Size.Y.Offset * s
	local x = holder.Position.X.Offset + holder.Position.X.Scale * Layout.W - holder.AnchorPoint.X * w
	local y = holder.Position.Y.Offset + holder.Position.Y.Scale * Layout.H - holder.AnchorPoint.Y * h
	return x, y, w, h
end
for _, id in ids do
	local def = Defs2[id]
	if not def.drawer then
		local r0 = Layout.region and table.concat(Layout.region, ",") or "nil"
		WM.open(id)
		if process.env.PECK_DEBUG then print("region", id, r0, Layout.region and table.concat(Layout.region, ",")) end
		local rec = WM.built[id]
		check("sidebar stays open with " .. id, sidebar.holder.Visible and Layout.sidebarOpen)
		local x, y, w, h = rect(rec.holder, rec.fit)
		if def.dock == "popup" then
			check("popup in game area " .. id, x >= -0.5 and x + w <= Layout.gameRight() + 0.5 and y >= -0.5 and y + h <= Layout.H + 0.5,
				("x %.0f..%.0f y %.0f..%.0f"):format(x, x + w, y, y + h))
		else
			-- every other window fits the window region: the banner, the wallet column and the bottom row stay visible
			local rx0, ry0, rx1, ry1 = Layout.windowRegion()
			check("window in window region " .. id, x >= rx0 - 1 and x + w <= rx1 + 1 and y >= ry0 - 1 and y + h <= ry1 + 1,
				("x %.2f..%.2f y %.2f..%.2f region %.2f,%.2f..%.2f,%.2f"):format(x, x + w, y, y + h, rx0, ry0, rx1, ry1))
		end
		-- tab switches: no rebuild of a seen variant, no re-pop
		local pops, tabs = rec.popCount, 0
		for _, tb in def.tabs or {} do
			if tb[2] then tabs += 1; WM.show(rec, tb[2], true) end
		end
		for _, tb in def.tabs or {} do if tb[2] then WM.show(rec, tb[2], true) end end
		local nv = 0; for _ in rec.variants do nv += 1 end
		check("tab switch does not re-pop " .. id, rec.popCount == pops, ("pops %d -> %d"):format(pops, rec.popCount))
		check("tab switch builds each view once " .. id, rec.builds == nv, ("builds %d views %d"):format(rec.builds, nv))
		WM.close()
	end
end
-- tab routing: opening a tab lands on its variant, and clicking every tab layer of every tab variant lands on the
-- variant whose active tab carries that label (QA round 1: Nest OWNED showed RIVERSIDE)
for _, id in ids do
	local def = Defs2[id]
	if not def.build and not def.drawer and def.tabs then
		for _, tb in def.tabs do
			if tb[2] then
				WM.open(id, tb[1])
				local rec = WM.built[id]
				check("open tab " .. id .. "/" .. tb[1], rec.current == tb[2], "current " .. tostring(rec.current))
				local v = rec.variants[rec.current]
				local at = v and (function()
					for _, d in v.ui.root:GetDescendants() do if string.match(d.Name, "^tab/.*%(active%)$") then return d end end
				end)()
				-- the active tab of the shown variant is this tab (Expedition shows one frame for both of its tabs)
				if at and def.tabs[1][2] ~= def.tabs[#def.tabs][2] then
					check("active tab label " .. id .. "/" .. tb[1], WM.tabOf(def, at.Name) == tb, "active " .. at.Name)
				end
				local tabsHit = {}
				for _, d in v.ui.root:GetDescendants() do
					if d.Name == "hit" and d.Parent and string.sub(d.Parent.Name, 1, 4) == "tab/" then table.insert(tabsHit, d) end
				end
				for _, h in tabsHit do
					local lab = WM.tabLabel(h.Parent.Name)
					local target = WM.tabOf(def, h.Parent.Name)
					check("tab layer has a def " .. id .. " " .. h.Parent.Name, target ~= nil)
					if target and target[2] then
						WM.open(id, tb[1])
						sig(h, "Activated"):Fire()
						check("tab click " .. id .. " " .. tb[1] .. " -> " .. lab, rec.current == target[2], "current " .. tostring(rec.current))
					end
				end
			end
		end
		WM.close()
	end
end
-- collapse the sidebar: HUD re-flows to the screen edge, windows widen; open it again
WM.setDrawer(false)
task.wait(0.3)
check("sidebar collapses", not Layout.sidebarOpen and Layout.gameRight() == Layout.W)
local comp = hudGui:FindFirstChild("companions", true)
WM.setDrawer(true)
task.wait(0.3)
check("sidebar reopens", Layout.sidebarOpen and sidebar.holder.Visible)
-- no HUD group crosses into the sidebar
for _, g in hudGui.canvas:GetChildren() do
	if g:IsA("Frame") and g.Visible and g:FindFirstChildOfClass("UIScale") then
		local sc = g:FindFirstChildOfClass("UIScale").Scale
		local w = g.Size.X.Offset * sc
		local x = g.Position.X.Offset - g.AnchorPoint.X * w
		if g.Name ~= "moment" and g.Name ~= "toast" and g.Name ~= "dev" then
			check("HUD clear of the sidebar " .. g.Name, x + w <= Layout.gameRight() + 0.5, ("right edge %.0f > %.0f"):format(x + w, Layout.gameRight()))
		end
	end
end
-- key audit (owner: every button presses in): build every variant of every window, then every node that looks like
-- a button (Kit keys, btn/ tab/ seg/ layers, close keys, rows, cards, cells) must be registered in Motion.key with
-- press-in and sound wired; no Squash UIScale (the old bubbly press) may exist anywhere
do
	local Motion = req(UI:FindFirstChild("Motion"))
	for _, id in ids do
		local def = Defs2[id]
		if not def.build then
			local rec = WM.built[id] or (function() WM.open(id); return WM.built[id] end)()
			for _, tb in def.tabs or {} do if tb[2] then WM.show(rec, tb[2]) end end
			for _, target in def.views or {} do WM.show(rec, target) end
		end
	end
	WM.close()
	local function buttonLike(d)
		if not d:IsA("GuiObject") then return false end
		local n = d.Name
		if d:GetAttribute("keyDepth") then return true end
		for _, p in { "btn/", "tab/", "seg/", "row/", "card/", "cell/" } do if string.sub(n, 1, #p) == p then return true end end
		return false
	end
	local total, bad, kinds = 0, 0, {}
	local roots = { playerGui:FindFirstChild("PeckwoodWindows"), playerGui:FindFirstChild("PeckwoodHUD") }
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d.Name == "Squash" and d:IsA("UIScale") then check("no squash UIScale " .. d.Parent:GetFullName(), false) end
			if buttonLike(d) and not d:FindFirstAncestor("info strip") then
				-- display-only components (wallet chips, banner, context bar) had their wiring removed on purpose
				local inertOk = d:FindFirstAncestor("wallet") or d:FindFirstAncestor("banner") or d:FindFirstAncestor("context") or d:FindFirstAncestor("moment")
				local info = Motion.registry[d]
				-- Render.build holders carry their node's name: the node inside is the key
				local inner = d:FindFirstChild(d.Name)
				if inner and Motion.registry[inner] then inertOk = true end
				if string.sub(d.Name, 1, 4) == "row/" and inner == nil then
					for _, c in d:GetChildren() do if string.sub(c.Name, 1, #d.Name) == d.Name then inner = c end end
					if inner and Motion.registry[inner] then inertOk = true end
				end
				-- a template node inside a wired holder (live list rows, Fishdex cells)
				if d.Parent and Motion.registry[d.Parent] and string.sub(d.Parent.Name, 1, 4) == string.sub(d.Name, 1, 4) then inertOk = true end
				if not inertOk then
					total += 1
					if info then kinds[info.kind] = (kinds[info.kind] or 0) + 1 end
					if not (info and info.pressIn and info.sfx) then
						bad += 1
						if bad <= 12 then check("key wired " .. d:GetFullName(), false, "no Motion.key press-in / sound") end
						if process.env.PECK_AUDIT then print("UNWIRED " .. d:GetFullName()) end
					end
				end
			end
		end
	end
	local kl = {}
	for k, v in kinds do table.insert(kl, k .. " " .. v) end
	table.sort(kl)
	print(("key audit: %d button-like nodes, %d wired, %d unwired  (%s)"):format(total, total - bad, bad, table.concat(kl, ", ")))
	local live = _G.__uiKeys and _G.__uiKeys() or {}
	print(("_G.__uiKeys(): %d live keys"):format(#live))
end
-- COMPANIONS board: drops to its full height (AUTO hidden under it), rolls back up to 0 (AUTO back), every row on it,
-- locked rows show their padlock + unlock note (QA: locked rows rendered as black blocks)
do
	local Hud3 = req(UI:FindFirstChild("Hud"))
	local cg = hudGui.canvas:FindFirstChild("companions")
	local boardF = cg and cg:FindFirstChild("board")
	local autoG = hudGui.canvas:FindFirstChild("auto")
	check("board exists", boardF ~= nil)
	if boardF then
		local rowsF = boardF:FindFirstChild("rows", true)
		local n = 0
		for _, r in rowsF:GetChildren() do if string.sub(r.Name, 1, 4) == "row/" then n += 1 end end
		check("board holds all 6 companion rows", n == 6, "rows " .. n)
		Hud3.toggleCompanions()
		task.wait(0.1)
		local sheet = boardF:FindFirstChild("sheet", true)
		check("board drops to its height", math.abs(boardF.Size.Y.Offset - sheet.Size.Y.Offset) < 1, ("track %d sheet %d"):format(boardF.Size.Y.Offset, sheet.Size.Y.Offset))
		local autoKeyVisible = false
		for _, c in autoG:GetChildren() do if c:IsA("Frame") and c.Visible then autoKeyVisible = true end end
		check("AUTO hides under the board", not autoKeyVisible)
		for _, r in rowsF:GetChildren() do
			if string.sub(r.Name, 1, 4) == "row/" then
				local locked = r:GetAttribute("locked")
				local lock = r:FindFirstChild("lock")
				check("locked row look " .. r.Name, lock ~= nil and lock.Visible == (locked == true))
			end
		end
		Hud3.toggleCompanions()
		task.wait(0.5)
		check("board rolls up", boardF.Size.Y.Offset == 0, "track " .. boardF.Size.Y.Offset)
		autoKeyVisible = false
		for _, c in autoG:GetChildren() do if c:IsA("Frame") and c.Visible then autoKeyVisible = true end end
		check("AUTO back after the roll up", autoKeyVisible)
	end
end
-- feel hooks run
try("onLabel", function() local Hud2 = req(UI:FindFirstChild("Hud")); Hud2.onLabel(roblox.Vector2.new(400, 300), 12345, "popcorn"); Hud2.bigMoment("THE MINE opens!", "unlock", "map") end)
local _ = comp

-- HUD keys
local hudHits = {}
for _, h in hudGui:GetDescendants() do if h.Name == "hit" and h:IsA("TextButton") then table.insert(hudHits, { h, h.Parent.Name }) end end
for _, hp in hudHits do
	local h = hp[1]
	if pcall(function() return h.Parent end) and h.Parent then
		try("hud press " .. hp[2], function() sig(h, "MouseButton1Down"):Fire(); sig(h, "MouseButton1Up"):Fire(); sig(h, "Activated"):Fire() end)
		WM.close()
	end
end
task.wait(0.1)
local acts = {}
for _, f in fired do acts[f[2]] = (acts[f[2]] or 0) + 1 end
local list = {}
for k, v in acts do table.insert(list, tostring(k) .. " x" .. v) end
table.sort(list)
print("server intents sent: " .. table.concat(list, ", "))
print("warnings: " .. #warnings)
for i = 1, math.min(10, #warnings) do print("  " .. warnings[i]) end
local IconAlias = req(UI:FindFirstChild("Figma"):FindFirstChild("IconAlias"))
local miss = 0; for _ in IconAlias.missing do miss += 1 end
local missList = {}; for k in IconAlias.missing do table.insert(missList, k) end; table.sort(missList)
print("icons with no uploaded id: " .. miss .. (if miss > 0 then " (" .. table.concat(missList, ", ") .. ")" else ""))
check("every icon the UI uses has an Icons entry", miss == 0, table.concat(missList, ", "))
-- layout dump for the composite QA mock (tools/ui_harness/mock.py): design-px rects of every HUD piece + windows
do
	local Hud2 = req(UI:FindFirstChild("Hud"))
	remotes.State.OnClientEvent:Fire(s, d)
	local out = { W = Layout.W, H = Layout.H, gameRight = Layout.gameRight(), sidebarW = Layout.sidebarW(), top = Layout.TOP, items = {} }
	local function own(c)
		local u = c:FindFirstChildOfClass("UIScale")
		return if u and u.Name ~= "Pop" and u.Name ~= "Squash" then u.Scale else 1
	end
	-- absolute design-px rect: each GuiObject's size is scaled by its own UIScale and every UIScale above it;
	-- anchor points apply to that scaled size (Roblox rules); scale-sized layers (canvas, layers) fill the canvas
	local function abs(c)
		if c.Name == "canvas" or not c:IsA("GuiObject") then return 0, 0, Layout.W, Layout.H, 1 end
		local px, py, pw, ph, psc = abs(c.Parent)
		local sc = psc * own(c)
		local w = (c.Size.X.Offset + c.Size.X.Scale * pw / psc) * sc
		local h = (c.Size.Y.Offset + c.Size.Y.Scale * ph / psc) * sc
		local x = px + c.Position.X.Offset * psc + c.Position.X.Scale * pw - c.AnchorPoint.X * w
		local y = py + c.Position.Y.Offset * psc + c.Position.Y.Scale * ph - c.AnchorPoint.Y * h
		return x, y, w, h, sc
	end
	local function rectOf(inst)
		local x, y, w, h = abs(inst)
		return { x, y, w, h }
	end
	local function add(name, inst) if inst and inst.Visible then out.items[name] = rectOf(inst) end end
	local hc = hudGui.canvas
	for _, g in hc:GetChildren() do
		if g:IsA("Frame") and g:FindFirstChildOfClass("UIScale") then
			for _, c in g:GetChildren() do
				if c:IsA("Frame") and c.Visible and (string.sub(c.Name, 1, 4) == "hud/" or c.Name:find("btn/")) then add(g.Name .. "|" .. c.Name, c) end
			end
		end
	end
	local sb = WM.built.shop
	add("sidebar|" .. (sb.current or "?"), sb.holder)
	WM.open("fishing")
	add("window|fishing", WM.built.fishing.holder)
	WM.close()
	WM.open("teleport")
	add("window|teleport", WM.built.teleport.holder)
	local f = io and io.open
	require("@lune/fs").writeFile("tools/ui_harness/layout_dump.json", serde.encode("json", out, true))
	local _ = Hud2
end
print(("ERRORS: %d"):format(#errors))
process.exit(if #errors > 0 then 1 else 0)
