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
	end
	if parent then i.Parent = parent end
	return i
end }
local _ = absSize

-- ---------------------------------------------------------------- services
local TweenInfo = { new = function(...) return { ... } end }
local function tween(inst, _, props)
	return { Play = function() for k, v in props do inst[k] = v end end, Cancel = function() end, Completed = Signal.new() }
end
local camera = { ViewportSize = V2.new(1920, 1080) }
function camera:GetPropertyChangedSignal() return Signal.new() end
local workspace = { CurrentCamera = camera }
local playerGui = Instance.new("Folder"); playerGui.Name = "PlayerGui"
local player = { DisplayName = "Tester", UserId = 1, Name = "Tester", Character = nil, PlayerGui = playerGui }
function player:WaitForChild(n) if n == "PlayerGui" then return playerGui end end
local RS = Instance.new("Folder"); RS.Name = "ReplicatedStorage"
local SSS = Instance.new("Folder"); SSS.Name = "ServerScriptService"
local services = {
	ReplicatedStorage = RS, ServerScriptService = SSS,
	TweenService = { Create = function(_, i, ti, p) return tween(i, ti, p) end },
	RunService = { RenderStepped = Signal.new(), Heartbeat = Signal.new(), Stepped = Signal.new(), IsStudio = function() return true end, IsClient = function() return true end, IsServer = function() return false end, BindToRenderStep = function() end },
	UserInputService = { InputBegan = Signal.new(), InputEnded = Signal.new(), InputChanged = Signal.new(), MouseEnabled = true, TouchEnabled = false, GetMouseLocation = function() return V2.new(0, 0) end },
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
local Hud
try("require Hud", function() Hud = req(UI:FindFirstChild("Hud")) end)
if not Hud then for _, e in errors do print(e) end; process.exit(1) end
try("Hud.start", Hud.start, remotes)
try("State push", function() remotes.State.OnClientEvent:Fire(s, d) end)
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
print("icons drawn with a family fallback (not uploaded yet): " .. miss)
print(("ERRORS: %d"):format(#errors))
process.exit(if #errors > 0 then 1 else 0)
