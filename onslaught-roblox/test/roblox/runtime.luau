--[[
	A headless Roblox for smoke tests: runs the real server Script and LocalScript(s) from the Rojo-built place.

	Instances are Lune's @lune/roblox instances (property names and value types are checked against Roblox's
	reflection data, so a typo errors here like it would in Studio), wrapped in proxies that add what Lune
	doesn't have: events, WaitForChild, remotes between "machines", and fake services (Players, RunService,
	UserInputService, DataStoreService, MarketplaceService, ...). Each machine (the server, each client) has
	its own proxies, its own `game`, and its own module cache, like a real server and clients.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local R = require("@lune/roblox")

local Runtime = {}

-- ================================================================ signals
local Signal = {}
Signal.__index = Signal
function Signal.new(name)
	return setmetatable({ name = name, handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local h = { fn = fn, connected = true }
	table.insert(self.handlers, h)
	return {
		Connected = true,
		Disconnect = function(c)
			h.connected = false
			c.Connected = false
		end,
	}
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Fire(...)
	for _, h in table.clone(self.handlers) do
		if h.connected then
			local ok, err = pcall(h.fn, ...)
			if not ok then
				Runtime.errors = Runtime.errors or {}
				table.insert(Runtime.errors, string.format("[%s] %s", tostring(self.name), tostring(err)))
				print("SIGNAL ERROR", self.name, err)
			end
		end
	end
end
function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end
Runtime.Signal = Signal

-- copy values across the "network": tables are deep-copied, buffers copied, instances refused
local function netCopy(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "table" then
		assert(depth < 20, "table too deep to send")
		local o = {}
		for k, x in v do
			assert(type(k) == "string" or type(k) == "number", "bad key type " .. type(k))
			o[k] = netCopy(x, depth + 1)
		end
		return o
	elseif t == "buffer" then
		local b = buffer.create(buffer.len(v))
		buffer.copy(b, 0, v, 0)
		return b
	elseif t == "function" or t == "thread" or t == "userdata" then
		error("can't send a " .. t .. " through a remote")
	end
	return v
end

-- ================================================================ machines and proxies
local EVENT_NAMES = {
	Activated = true, MouseButton1Click = true, MouseEnter = true, MouseLeave = true, ChildAdded = true, ChildRemoved = true,
	OnServerEvent = true, OnClientEvent = true, Changed = true, AncestryChanged = true, Destroying = true, FocusLost = true,
}

local Machine = {}
Machine.__index = Machine

function Runtime.new(placePath: string)
	local self = { machines = {}, players = {}, nextUserId = 1000 }
	self.dm = R.deserializePlace(fs.readFile(placePath))
	self.datastores, self.ordered, self.memory = {}, {}, {}
	self.receipts = {}
	return setmetatable(self, { __index = Runtime })
end

function Runtime:machine(name: string, isServer: boolean, player)
	local m = setmetatable({ rt = self, name = name, isServer = isServer, player = player, proxies = {}, reals = {}, modules = {}, signals = {} }, Machine)
	m.services = {}
	m:makeServices()
	m.env = m:makeEnv()
	self.machines[name] = m
	return m
end

function Machine:wrap(real)
	if real == nil then
		return nil
	end
	if typeof(real) ~= "Instance" then
		return real
	end
	local p = self.proxies[real]
	if p then
		return p
	end
	p = setmetatable({}, {
		__index = function(_, k)
			return self:get(real, k)
		end,
		__newindex = function(_, k, v)
			self:set(real, k, v)
		end,
		__tostring = function()
			return "Proxy(" .. real.ClassName .. " " .. real.Name .. ")"
		end,
	})
	self.proxies[real] = p
	self.reals[p] = real
	return p
end
function Machine:unwrap(v)
	if type(v) == "table" and self.reals[v] then
		return self.reals[v]
	end
	-- a proxy from another machine (shared instances such as remotes)
	if type(v) == "table" then
		for _, m in self.rt.machines do
			if m.reals[v] then
				return m.reals[v]
			end
		end
	end
	return v
end
function Machine:signal(real, k)
	self.signals[real] = self.signals[real] or {}
	local s = self.signals[real][k]
	if not s then
		s = Signal.new(self.name .. ":" .. real.Name .. "." .. k)
		self.signals[real][k] = s
	end
	return s
end
function Machine:wrapAll(list)
	local out = {}
	for i, x in list do
		out[i] = self:wrap(x)
	end
	return out
end

local function machineFor(rt, player)
	for _, m in rt.machines do
		if not m.isServer and m.player == player then
			return m
		end
	end
	return nil
end

function Machine:get(real, k)
	local cls = real.ClassName
	if EVENT_NAMES[k] then
		return self:signal(real, k)
	end
	-- special objects
	if k == "CurrentCamera" and cls == "Workspace" then
		return self.camera
	end
	if k == "OnServerInvoke" or k == "OnClientInvoke" then
		return self.rt.invokers and self.rt.invokers[real]
	end
	-- methods we provide or fix
	if k == "WaitForChild" then
		return function(_, name, timeout)
			local t0 = os.clock()
			while true do
				local c = real:FindFirstChild(name)
				if c then
					return self:wrap(c)
				end
				if os.clock() - t0 > (timeout or 5) then
					error("WaitForChild timed out: " .. real.Name .. "." .. name)
				end
				task.wait(0.01)
			end
		end
	elseif k == "GetPropertyChangedSignal" then
		return function(_, prop)
			return self:signal(real, "Changed:" .. prop)
		end
	elseif k == "PivotTo" or k == "SetCoreGuiEnabled" or k == "SetCore" then
		return function() end
	elseif k == "GetChildren" or k == "GetDescendants" then
		return function()
			return self:wrapAll(real[k](real))
		end
	elseif k == "Destroy" then
		return function()
			real:Destroy()
		end
	elseif k == "FireServer" then
		return function(_, ...)
			assert(not self.isServer, "FireServer from the server")
			local args = netCopy({ ... })
			local server = self.rt.machines.server
			local player = self.player
			task.defer(function()
				server:signal(real, "OnServerEvent"):Fire(player, table.unpack(args))
			end)
		end
	elseif k == "FireClient" then
		return function(_, player, ...)
			assert(self.isServer, "FireClient from a client")
			local args = netCopy({ ... })
			local m = machineFor(self.rt, player)
			if m then
				task.defer(function()
					m:signal(real, "OnClientEvent"):Fire(table.unpack(args))
				end)
			end
		end
	elseif k == "FireAllClients" then
		return function(_, ...)
			local args = netCopy({ ... })
			for _, m in self.rt.machines do
				if not m.isServer then
					task.defer(function()
						m:signal(real, "OnClientEvent"):Fire(table.unpack(args))
					end)
				end
			end
		end
	elseif k == "InvokeServer" then
		return function(_, ...)
			local fn = self.rt.invokers and self.rt.invokers[real]
			assert(fn, "no OnServerInvoke for " .. real.Name)
			return table.unpack(netCopy({ fn(self.player, table.unpack(netCopy({ ... }))) }))
		end
	end
	local v = real[k] -- validated by Lune (errors on unknown members)
	if type(v) == "function" then
		return function(_, ...)
			local args = { ... }
			for i, a in args do
				args[i] = self:unwrap(a)
			end
			local res = { v(real, table.unpack(args)) }
			for i, r in res do
				res[i] = self:wrap(r)
			end
			return table.unpack(res)
		end
	end
	return self:wrap(v)
end

function Machine:set(real, k, v)
	if k == "OnServerInvoke" or k == "OnClientInvoke" then
		self.rt.invokers = self.rt.invokers or {}
		self.rt.invokers[real] = v
		return
	end
	real[k] = self:unwrap(v)
	local s = self.signals[real] and self.signals[real]["Changed:" .. k]
	if s then
		s:Fire()
	end
end

-- ================================================================ fake services
function Machine:makeServices()
	local rt, me = self.rt, self
	local S = self.services
	-- Players (shared list; LocalPlayer per client)
	S.Players = {
		PlayerAdded = rt.playerAdded or Signal.new("PlayerAdded"),
		PlayerRemoving = rt.playerRemoving or Signal.new("PlayerRemoving"),
		CharacterAutoLoads = true,
		LocalPlayer = self.player,
		GetPlayers = function()
			return table.clone(rt.players)
		end,
		GetPlayerByUserId = function(_, id)
			for _, p in rt.players do
				if p.UserId == id then
					return p
				end
			end
			return nil
		end,
		GetNameFromUserIdAsync = function(_, id)
			return "User" .. id
		end,
	}
	rt.playerAdded, rt.playerRemoving = S.Players.PlayerAdded, S.Players.PlayerRemoving
	S.RunService = {
		Heartbeat = rt.heartbeat or Signal.new("Heartbeat"),
		RenderStepped = Signal.new(self.name .. ":RenderStepped"),
		IsServer = function()
			return me.isServer
		end,
		IsClient = function()
			return not me.isServer
		end,
		IsStudio = function()
			return true
		end,
	}
	rt.heartbeat = S.RunService.Heartbeat
	S.UserInputService = {
		InputBegan = Signal.new(self.name .. ":InputBegan"),
		InputEnded = Signal.new(self.name .. ":InputEnded"),
		InputChanged = Signal.new(self.name .. ":InputChanged"),
		mouse = R.Vector2.new(400, 300),
		keys = {},
		GetMouseLocation = function(s)
			return s.mouse
		end,
		IsKeyDown = function(s, kc)
			return s.keys[kc] == true
		end,
		TouchEnabled = false,
	}
	S.GuiService = {
		GetGuiInset = function()
			return R.Vector2.zero, R.Vector2.zero
		end,
	}
	local function store(map, name)
		map[name] = map[name] or { data = {} }
		local st = map[name]
		return {
			UpdateAsync = function(_, key, fn)
				local new = fn(st.data[key])
				if new ~= nil then
					st.data[key] = netCopy(new)
				end
				return st.data[key]
			end,
			GetAsync = function(_, key)
				return st.data[key]
			end,
			SetAsync = function(_, key, v)
				st.data[key] = netCopy(v)
			end,
			GetSortedAsync = function(_, ascending, n)
				local rows = {}
				for k, v in st.data do
					table.insert(rows, { key = k, value = v })
				end
				table.sort(rows, function(a, b)
					return if ascending then a.value < b.value else a.value > b.value
				end)
				local page = {}
				for i = 1, math.min(n, #rows) do
					page[i] = rows[i]
				end
				return {
					GetCurrentPage = function()
						return page
					end,
				}
			end,
		}
	end
	S.DataStoreService = {
		GetDataStore = function(_, name)
			return store(rt.datastores, name)
		end,
		GetOrderedDataStore = function(_, name)
			return store(rt.ordered, name)
		end,
	}
	S.MemoryStoreService = {
		GetSortedMap = function(_, name)
			return store(rt.memory, name)
		end,
	}
	S.MarketplaceService = {
		PromptGamePassPurchaseFinished = Signal.new("PromptGamePassPurchaseFinished"),
		UserOwnsGamePassAsync = function(_, userId, id)
			return rt.ownedPasses and rt.ownedPasses[userId .. ":" .. id] == true
		end,
		PromptGamePassPurchase = function(_, player, id)
			table.insert(rt.receipts, { kind = "pass", player = player, id = id })
		end,
		PromptProductPurchase = function(_, player, id)
			table.insert(rt.receipts, { kind = "product", player = player, id = id })
		end,
	}
	rt.marketplace = rt.marketplace or S.MarketplaceService
	S.MarketplaceService = rt.marketplace
	S.TeleportService = {
		ReserveServer = function()
			error("no reserved servers in tests")
		end,
		TeleportAsync = function() end,
	}
	-- a camera that projects like Roblox's (for picking tests)
	self.camera = {
		CameraType = R.Enum.CameraType.Custom, FieldOfView = 70, CFrame = R.CFrame.new(), ViewportSize = R.Vector2.new(1280, 720),
		GetPropertyChangedSignal = function()
			return Signal.new("cam")
		end,
		ViewportPointToRay = function(c, x, y)
			local vp = c.ViewportSize
			local t = math.tan(math.rad(c.FieldOfView / 2))
			local dx = (2 * x / vp.X - 1) * t * (vp.X / vp.Y)
			local dy = -(2 * y / vp.Y - 1) * t
			local dir = c.CFrame:VectorToWorldSpace(R.Vector3.new(dx, dy, -1)).Unit
			return { Origin = c.CFrame.Position, Direction = dir }
		end,
	}
end

function Machine:makeEnv()
	local me = self
	local dm = self.rt.dm
	local gameProxy = self:wrap(dm)
	local REAL_SERVICES = { ReplicatedStorage = true, Workspace = true, Lighting = true, StarterGui = true, ServerScriptService = true, StarterPlayer = true }
	local game = setmetatable({}, {
		__index = function(_, k)
			if k == "GetService" then
				return function(_, name)
					if me.services[name] then
						return me.services[name]
					end
					assert(REAL_SERVICES[name], "service not in the test runtime: " .. name)
					return me:wrap(dm:GetService(name))
				end
			elseif k == "JobId" then
				return "test-job"
			elseif k == "PlaceId" then
				return 1
			elseif k == "PrivateServerId" then
				return ""
			elseif k == "PrivateServerOwnerId" then
				return 0
			elseif k == "BindToClose" then
				return function() end
			end
			return gameProxy[k]
		end,
	})
	local env = {}
	env.game = game
	env.workspace = game:GetService("Workspace")
	env.Instance = {
		new = function(class, parent)
			local inst = R.Instance.new(class)
			local p = me:wrap(inst)
			if parent then
				p.Parent = parent
			end
			return p
		end,
	}
	for _, k in { "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "UDim", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberRange", "Font", "Enum", "Rect", "BrickColor" } do
		env[k] = (R :: any)[k]
	end
	env.task = task
	env.warn = function(...)
		print("[warn " .. me.name .. "]", ...)
	end
	env.typeof = function(v)
		if type(v) == "table" and me.reals[v] then
			return "Instance"
		end
		return typeof(v)
	end
	env.tick = os.clock
	env.require = function(mod)
		local real = me:unwrap(mod)
		assert(typeof(real) == "Instance", "require expects a ModuleScript")
		if me.modules[real] ~= nil then
			return me.modules[real]
		end
		local fn = luau.load(real.Source, { debugName = real:GetFullName(), environment = me:scriptEnv(real), injectGlobals = true })
		local result = fn()
		me.modules[real] = result
		return result
	end
	return env
end

function Machine:scriptEnv(real)
	local env = table.clone(self.env) -- Lune copies the environment's fields (a metatable would be lost)
	env.script = self:wrap(real)
	return env
end

function Machine:run(scriptInstance)
	local fn = luau.load(scriptInstance.Source, { debugName = scriptInstance:GetFullName(), environment = self:scriptEnv(scriptInstance), injectGlobals = true })
	task.spawn(function()
		local ok, err = pcall(fn)
		if not ok then
			Runtime.errors = Runtime.errors or {}
			table.insert(Runtime.errors, self.name .. " script: " .. tostring(err))
			print("SCRIPT ERROR", self.name, err)
		end
	end)
end

-- ================================================================ helpers for tests
function Runtime:addPlayer(name: string)
	self.nextUserId += 1
	local id = self.nextUserId
	local gui = R.Instance.new("PlayerGui")
	local attrs = {}
	local player
	player = {
		Name = name, DisplayName = name, UserId = id, Parent = true, gui = gui,
		Kick = function(_, msg)
			error("kicked: " .. tostring(msg))
		end,
		SetAttribute = function(_, k, v)
			attrs[k] = v
		end,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
		GetJoinData = function()
			return {}
		end,
	}
	local m = self:machine("client:" .. name, false, player)
	player.WaitForChild = function(_, child)
		assert(child == "PlayerGui")
		return m:wrap(gui)
	end
	table.insert(self.players, player)
	return player, m
end

function Runtime:find(path: string)
	local cur = self.dm
	for part in string.gmatch(path, "[^%.]+") do
		cur = if cur == self.dm then self.dm:GetService(part) else cur:FindFirstChild(part)
		assert(cur, "not in the place: " .. path)
	end
	return cur
end

return Runtime
