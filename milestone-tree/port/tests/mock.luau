--!nocheck
--[[
	A small stand-in for the Roblox engine, enough to run the port's Roblox scripts (client and server) from the
	command line: Instances with properties, children, events and attributes; the datatypes the UI uses; Enum;
	services (Players, ReplicatedStorage, RunService, UserInputService, DataStoreService in memory, ...); Actors
	with SendMessage / BindToMessage; RemoteEvents that carry calls between a fake server and client; task.*.

	Nothing is drawn: GuiObjects just keep their properties, which the tests inspect. AutomaticSize etc. are
	properties like any other. Property names are not checked here (luau-lsp does that against the real API).
]]
local M = {}

-- --------------------------------------------------------------------------------------------------------- signals
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ handlers = {}, parallel = {} }, Signal) end
function Signal:Connect(f)
	local h = { f = f, on = true }
	table.insert(self.handlers, h)
	return { Disconnect = function() h.on = false end, Connected = true }
end
function Signal:ConnectParallel(f) return self:Connect(f) end
function Signal:Once(f)
	local c
	c = self:Connect(function(...) c.Disconnect(); f(...) end)
	return c
end
function Signal:Fire(...)
	-- like the engine: every handler in its own thread, so handlers may yield
	for _, h in table.clone(self.handlers) do
		if h.on then M.spawn(h.f, ...) end
	end
end
function Signal:Wait() return nil end
M.Signal = Signal

-- ------------------------------------------------------------------------------------------------------ datatypes
local function dt(name, fields)
	return setmetatable(fields, { __tostring = function() return name end, __index = function(_, k) error(name .. " has no " .. tostring(k), 2) end })
end
local UDim = { new = function(s, o) return dt("UDim", { Scale = s or 0, Offset = o or 0 }) end }
local UDim2
UDim2 = {
	new = function(xs, xo, ys, yo) return dt("UDim2", { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }) end,
	fromOffset = function(x, y) return UDim2.new(0, x or 0, 0, y or 0) end,
	fromScale = function(x, y) return UDim2.new(x or 0, 0, y or 0, 0) end,
}
local Vector2 = { new = function(x, y) return dt("Vector2", { X = x or 0, Y = y or 0 }) end, zero = nil }
Vector2.zero = Vector2.new(0, 0)
local Color3
Color3 = {
	new = function(r, g, b) return dt("Color3", { R = r or 0, G = g or 0, B = b or 0 }) end,
	fromRGB = function(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHex = function(h)
		h = string.gsub(h, "^#", "")
		assert(#h == 6 or #h == 3, "bad hex " .. h)
		if #h == 3 then h = string.gsub(h, ".", "%0%0") end
		return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
	end,
}
local ColorSequenceKeypoint = { new = function(t, c) assert(t >= 0 and t <= 1, "keypoint time " .. t); return dt("ColorSequenceKeypoint", { Time = t, Value = c }) end }
local ColorSequence = { new = function(pts)
	assert(type(pts) == "table" and #pts >= 2 and #pts <= 20, "ColorSequence needs 2..20 keypoints")
	assert(pts[1].Time == 0 and pts[#pts].Time == 1, "ColorSequence must start at 0 and end at 1")
	for i = 2, #pts do assert(pts[i].Time > pts[i - 1].Time, "ColorSequence times must increase") end
	return dt("ColorSequence", { Keypoints = pts })
end }
local Font = { new = function(family, weight) return dt("Font", { Family = family, Weight = weight }) end }
local DateTime = { now = function() return { UnixTimestampMillis = M.clockMs() } end }

-- Enum: Enum.X.Y is an item; KeyCode letters and digits get their real Values (A = 97...)
local function enumItem(enum, name, value) return setmetatable({ Name = name, Value = value, EnumType = enum }, { __tostring = function() return "Enum." .. enum .. "." .. name end }) end
local KEYS = { A = 97, Z = 122, Zero = 48, Nine = 57, Up = 273, Down = 274, Right = 275, Left = 276, Return = 13, Space = 32, Escape = 27, Tab = 9, LeftShift = 304, RightShift = 303, LeftControl = 306, RightControl = 305 }
for i = 0, 25 do KEYS[string.char(65 + i)] = 97 + i end
for i, n in { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" } do KEYS[n] = 47 + i end
local Enum
Enum = setmetatable({}, { __index = function(t, enum)
	local e = setmetatable({}, { __index = function(et, name)
		local item = enumItem(enum, name, if enum == "KeyCode" then KEYS[name] or 0 else 0)
		rawset(et, name, item)
		return item
	end })
	rawset(t, enum, e)
	return e
end })

-- --------------------------------------------------------------------------------------------------------- Instances
local ISA = {
	Frame = { "GuiObject", "GuiBase2d" }, ScrollingFrame = { "GuiObject", "GuiBase2d" }, TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" }, TextBox = { "GuiObject", "GuiBase2d" }, ImageLabel = { "GuiObject", "GuiBase2d" },
	ScreenGui = { "LayerCollector", "GuiBase2d" }, Script = { "BaseScript", "LuaSourceContainer" }, LocalScript = { "Script", "BaseScript" },
	ModuleScript = { "LuaSourceContainer" }, UIListLayout = { "UIGridStyleLayout", "UIComponent" }, UICorner = { "UIComponent" },
	UIStroke = { "UIComponent" }, UIPadding = { "UIComponent" }, UIScale = { "UIComponent" }, UIGradient = { "UIComponent" },
	UISizeConstraint = { "UIConstraint", "UIComponent" }, RemoteEvent = {}, Folder = {}, Actor = { "Model", "PVInstance" },
}
local EVENTS = { "MouseEnter", "MouseLeave", "Activated", "InputBegan", "InputEnded", "InputChanged", "OnServerEvent", "OnClientEvent", "Changed", "ChildAdded", "Destroying" }

local Inst = {}
local function newInstance(class)
	local o = { __class = class, __props = { Name = class, ClassName = class }, __kids = {}, __attrs = {}, __events = {}, __propSignals = {} }
	return setmetatable(o, Inst)
end
Inst.__index = function(o, k)
	local m = rawget(Inst, k)
	if m then return m end
	local props = rawget(o, "__props")
	local v = props[k]
	if v ~= nil then return v end
	if k == "Parent" then return nil end
	for _, ev in EVENTS do
		if ev == k then
			local s = o.__events[k] or Signal.new()
			o.__events[k] = s
			return s
		end
	end
	-- a child by name (script.Parent.Config)
	for _, c in o.__kids do if c.Name == k then return c end end
	return nil
end
Inst.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = o.__props.Parent
		if old == v then return end
		if old then
			for i, c in old.__kids do if c == o then table.remove(old.__kids, i); break end end
		end
		o.__props.Parent = v
		if v then
			table.insert(v.__kids, o)
			if v.__events.ChildAdded then v.__events.ChildAdded:Fire(o) end
			if M.onParented then M.onParented(o) end
		end
		return
	end
	o.__props[k] = v
	local s = o.__propSignals[k]
	if s then s:Fire() end
end
Inst.__tostring = function(o) return o.__props.Name end
function Inst:FindFirstChild(name) for _, c in self.__kids do if c.Name == name then return c end end return nil end
function Inst:WaitForChild(name)
	local c = self:FindFirstChild(name)
	if c == nil then error("[mock] WaitForChild: " .. tostring(self.Name) .. " has no " .. tostring(name), 2) end
	return c
end
function Inst:FindFirstChildOfClass(cls) for _, c in self.__kids do if c.ClassName == cls then return c end end return nil end
function Inst:GetChildren() return table.clone(self.__kids) end
function Inst:GetDescendants()
	local out = {}
	local function walk(o) for _, c in o.__kids do table.insert(out, c); walk(c) end end
	walk(self)
	return out
end
function Inst:IsA(cls)
	if self.__class == cls or cls == "Instance" then return true end
	for _, b in ISA[self.__class] or {} do if b == cls then return true end end
	return false
end
function Inst:Destroy()
	if self.__events.Destroying then self.__events.Destroying:Fire() end
	for _, c in table.clone(self.__kids) do c:Destroy() end
	self.Parent = nil
	self.__destroyed = true
end
function Inst:Clone()
	local c = newInstance(self.__class)
	for k, v in self.__props do if k ~= "Parent" then c.__props[k] = v end end
	for k, v in self.__attrs do c.__attrs[k] = v end
	c.__source = self.__source
	c.__module = self.__module
	for _, k in self.__kids do k:Clone().Parent = c end
	return c
end
function Inst:GetAttribute(k) return self.__attrs[k] end
function Inst:SetAttribute(k, v) self.__attrs[k] = v end
function Inst:GetPropertyChangedSignal(k)
	local s = self.__propSignals[k] or Signal.new()
	self.__propSignals[k] = s
	return s
end
function Inst:GetFullName()
	local parts, o = {}, self
	while o do table.insert(parts, 1, o.Name); o = o.Parent end
	return table.concat(parts, ".")
end
-- RemoteEvents: the test wires server and client together
function Inst:FireServer(...) if M.fireServer then M.fireServer(self, ...) end end
function Inst:FireClient(player, ...) if M.fireClient then M.fireClient(self, player, ...) end end
function Inst:FireAllClients(...) if M.fireClient then M.fireClient(self, nil, ...) end end
-- Actors: messages are queued and delivered by M.pump (like the engine does between frames)
function Inst:SendMessage(topic, ...)
	table.insert(M.messages, { actor = self, topic = topic, args = table.pack(...) })
end
function Inst:BindToMessage(topic, f) self.__bound = self.__bound or {}; self.__bound[topic] = f end
function Inst:BindToMessageParallel(topic, f) self:BindToMessage(topic, f) end
function Inst:GetActor()
	local o = self.Parent
	while o and o.__class ~= "Actor" do o = o.Parent end
	return o
end
-- TextBox
function Inst:CaptureFocus() end
function Inst:ReleaseFocus() end

local Instance
Instance = { new = function(class, parent)
	local o = newInstance(class)
	if parent then o.Parent = parent end
	return o
end }
M.newInstance = newInstance

-- ------------------------------------------------------------------------------------------------------------ task
function M.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	local ok, err = coroutine.resume(co, ...)
	if not ok then M.errors = (M.errors or 0) + 1; print("[mock] error: " .. tostring(err) .. "\n" .. debug.traceback(co)) end
	return co
end
M.now = 0
M.queue = {}
M.messages = {}
function M.clockMs() return 1.7e12 + M.now * 1000 end
local task
task = {
	wait = function(s) local co = coroutine.running(); table.insert(M.queue, { t = M.now + (s or 0), co = co }); return coroutine.yield() end,
	delay = function(s, f, ...) table.insert(M.queue, { t = M.now + (s or 0), f = f, args = table.pack(...) }) end,
	spawn = function(f, ...) return M.spawn(f, ...) end,
	defer = function(f, ...) table.insert(M.queue, { t = M.now, f = f, args = table.pack(...) }) end,
	synchronize = function() end,
	desynchronize = function() end,
}
function M.runQueue()
	local ready = {}
	for i = #M.queue, 1, -1 do
		if M.queue[i].t <= M.now then table.insert(ready, 1, table.remove(M.queue, i)) end
	end
	for _, j in ready do
		if j.co then
			if coroutine.status(j.co) == "suspended" then
				local ok, err = coroutine.resume(j.co)
				if not ok then M.errors = (M.errors or 0) + 1; print("[mock] resumed task error: " .. tostring(err) .. "\n" .. debug.traceback(j.co)) end
			end
		else
			task.spawn(j.f, table.unpack(j.args, 1, j.args.n))
		end
	end
end
-- deliver actor messages (each in its own thread, like the engine)
function M.pump()
	local msgs = M.messages
	M.messages = {}
	for _, m in msgs do
		local f = m.actor.__bound and m.actor.__bound[m.topic]
		if f then task.spawn(f, table.unpack(m.args, 1, m.args.n)) else table.insert(M.messages, m) end
	end
end

-- -------------------------------------------------------------------------------------------------------- services
local services = {}
local game = newInstance("DataModel")
game.Name = "game"
game.__props.JobId = ""
function game:GetService(name)
	local s = services[name]
	if s == nil then
		s = newInstance(name)
		s.Name = name
		s.Parent = game
		services[name] = s
	end
	return s
end
local closers = {}
function game:BindToClose(f) table.insert(closers, f) end
M.closers = closers
M.game = game

local RunService = game:GetService("RunService")
RunService.__events.Heartbeat = Signal.new()
RunService.__props.Heartbeat = RunService.__events.Heartbeat
function RunService:IsServer() return M.side == "server" end
function RunService:IsClient() return M.side == "client" end
function RunService:IsStudio() return true end

local Players = game:GetService("Players")
Players.__props.PlayerAdded = Signal.new()
Players.__props.PlayerRemoving = Signal.new()
function Players:GetPlayers() local out = {} for _, c in Players.__kids do if c.__class == "Player" then table.insert(out, c) end end return out end

local UIS = game:GetService("UserInputService")
UIS.__props.InputBegan = Signal.new()
UIS.__props.InputChanged = Signal.new()
UIS.__props.InputEnded = Signal.new()
UIS.keysDown = {}
function UIS:GetMouseLocation() return Vector2.new(100, 100) end
function UIS:IsKeyDown(k) return UIS.keysDown[k] == true end
function UIS:GetFocusedTextBox() return nil end

local StarterGui = game:GetService("StarterGui")
function StarterGui:SetCoreGuiEnabled() end

local Workspace = game:GetService("Workspace")
local cam = newInstance("Camera")
cam.__props.ViewportSize = Vector2.new(1920, 1080)
Workspace.__props.CurrentCamera = cam

-- DataStore in memory (UpdateAsync with the real "return nil cancels" rule)
M.stores = {}
M.failStore = false
local DSS = game:GetService("DataStoreService")
function DSS:GetDataStore(name)
	local data = M.stores[name] or {}
	M.stores[name] = data
	return {
		UpdateAsync = function(_, key, f)
			if M.failStore then error("DataStore request failed (mock)") end
			local old = data[key]
			local new = f(if old then M.deep(old) else nil)
			if new ~= nil then data[key] = M.deep(new); return M.deep(new) end
			return old and M.deep(old)
		end,
		GetAsync = function(_, key) return data[key] and M.deep(data[key]) end,
		SetAsync = function(_, key, v) data[key] = M.deep(v) end,
	}
end
function M.deep(v)
	if type(v) ~= "table" then return v end
	local o = {}
	for k, x in v do o[k] = M.deep(x) end
	return o
end

-- a player
function M.addPlayer(name, userId)
	local p = newInstance("Player")
	p.Name = name
	p.__props.UserId = userId
	local gui = newInstance("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = p
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end
function M.removePlayer(p)
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
end

-- ------------------------------------------------------------------------------------------------ scripts & modules
-- a ModuleScript instance backed by a real module (the test requires the file and hands its result over)
function M.module(parent, name, loader)
	local m = newInstance("ModuleScript")
	m.Name = name
	m.__module = loader
	m.Parent = parent
	return m
end
local realRequire = require
local cache = {}
function M.require(x)
	if type(x) == "table" and x.__module then
		local c = cache[x.__module]
		if c == nil then c = { v = x.__module() }; cache[x.__module] = c end
		return c.v
	end
	return realRequire(x)
end
-- run a script file's function body as a Script with `script` = inst (the file must be wrapped by the test)
-- the globals a Roblox script sees (the CLI keeps each module's globals to itself, so they are handed in)
M.G = {
	UDim = UDim, UDim2 = UDim2, Vector2 = Vector2, Color3 = Color3, ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint, Font = Font, DateTime = DateTime, Enum = Enum, Instance = Instance,
	task = task, game = game, workspace = Workspace, warn = function(...) print("[warn]", ...) end,
}
local function envFor(inst)
	return setmetatable({ script = inst, require = M.require }, { __index = function(_, k)
		local v = M.G[k]
		if v ~= nil then return v end
		return (_G :: any)[k]
	end })
end
function M.runScript(inst, fn)
	setfenv(fn, envFor(inst))
	return task.spawn(fn)
end
-- load a module file with its own `script` (for modules that use script.Parent or Roblox datatypes)
function M.withScript(inst, fn)
	setfenv(fn, envFor(inst))
	return fn()
end

-- advance time: heartbeats at 60 fps, running due tasks and delivering messages
function M.step(seconds)
	local dt = 1 / 60
	local t = 0
	while t < seconds do
		M.now += dt
		t += dt
		M.runQueue()
		M.pump()
		RunService.Heartbeat:Fire(dt)
	end
end

return M
