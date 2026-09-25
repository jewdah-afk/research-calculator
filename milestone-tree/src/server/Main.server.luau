--!strict
--[[
	Milestone Tree NG+ on Roblox: server entry point.

	Each player gets their own game (the web game's JavaScript, transpiled to Luau, see Session and Game) running in
	their own Actor (the Worker in ServerStorage), so players' games run in parallel. This script owns the players,
	the remotes and the rate limits; the Worker owns the game and the save.

	Remotes (ReplicatedStorage.MilestoneTreeRemotes):
	  View    server -> client   screen patches (see Session:view)
	  Act     client -> server   (action, hold?) a button on the screen, or { "key", name } for a hotkey
	  Import  client -> server   (text) a pasted save string
	  Ready   client -> server   the client wants the whole screen (first load, UI rebuilt)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local root = script.Parent
local Config = require(root:WaitForChild("Config"))

local remotes = Instance.new("Folder")
remotes.Name = "MilestoneTreeRemotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local viewRemote = remote("View")
local actRemote = remote("Act")
local importRemote = remote("Import")
local readyRemote = remote("Ready")
remotes.Parent = ReplicatedStorage

local sessionsFolder = Instance.new("Folder")
sessionsFolder.Name = "Sessions"
sessionsFolder.Parent = root

local template = ServerStorage:WaitForChild("MilestoneTreeWorker") :: Actor

type Entry = { actor: Actor, tokens: number, last: number, lastImport: number }
local entries: { [Player]: Entry } = {}

local function fatal(player: Player, text: string)
	warn("[MilestoneTree] " .. player.Name .. ": " .. text)
	viewRemote:FireClient(player, { fatal = text })
end

local function start(player: Player)
	if entries[player] then return end
	local a = template:Clone()
	a.Name = "Player_" .. player.UserId
	a.Parent = sessionsFolder
	local entry: Entry = { actor = a, tokens = Config.ACTIONS_PER_SECOND, last = os.clock(), lastImport = 0 }
	entries[player] = entry
	-- the Worker binds its messages when it starts running
	local t0 = os.clock()
	while not a:GetAttribute("Ready") and not a:GetAttribute("Error") and os.clock() - t0 < 30 do task.wait() end
	if a:GetAttribute("Error") then
		fatal(player, tostring(a:GetAttribute("Error")))
		return
	elseif not a:GetAttribute("Ready") then
		fatal(player, "The game did not start on the server within 30 seconds (see the Output window).")
		return
	end
	a:SendMessage("start", player)
end

local stopping = 0 -- saves in flight (BindToClose waits for them)

local function stop(player: Player)
	local entry = entries[player]
	if not entry then return end
	entries[player] = nil
	stopping += 1
	entry.actor:SendMessage("stop")
	local t0 = os.clock()
	while not entry.actor:GetAttribute("Stopped") and os.clock() - t0 < 30 do task.wait(0.1) end
	entry.actor:Destroy()
	stopping -= 1
end

Players.PlayerAdded:Connect(start)
Players.PlayerRemoving:Connect(stop)
for _, p in Players:GetPlayers() do task.spawn(start, p) end

-- a token bucket per player: holding a buyable fires 20 presses a second, a burst of clicks a few more
local function allow(entry: Entry): boolean
	local now = os.clock()
	entry.tokens = math.min(Config.ACTIONS_PER_SECOND, entry.tokens + (now - entry.last) * Config.ACTIONS_PER_SECOND)
	entry.last = now
	if entry.tokens < 1 then return false end
	entry.tokens -= 1
	return true
end

local function validAction(a: any): boolean
	if type(a) ~= "table" or #a < 1 or #a > 4 then return false end
	for k, v in a do
		if type(k) ~= "number" then return false end
		local tv = type(v)
		if tv == "string" then
			if #v > 100 then return false end
		elseif tv == "table" then
			if #v > 2 then return false end
			for _, w in v do if type(w) ~= "number" and type(w) ~= "string" then return false end end
		elseif tv ~= "number" then
			return false
		end
	end
	return type(a[1]) == "string"
end

actRemote.OnServerEvent:Connect(function(player: Player, a: any, hold: any)
	local entry = entries[player]
	if not entry or not validAction(a) or not allow(entry) then return end
	entry.actor:SendMessage("act", a, hold == true)
end)

importRemote.OnServerEvent:Connect(function(player: Player, text: any)
	local entry = entries[player]
	if not entry or type(text) ~= "string" or #text > 3000000 then return end
	if os.clock() - entry.lastImport < Config.IMPORT_COOLDOWN then return end
	entry.lastImport = os.clock()
	entry.actor:SendMessage("import", text)
end)

readyRemote.OnServerEvent:Connect(function(player: Player)
	local entry = entries[player]
	if not entry then return end
	if entry.actor:GetAttribute("Error") then
		fatal(player, tostring(entry.actor:GetAttribute("Error")))
	else
		entry.actor:SendMessage("resync")
	end
end)

game:BindToClose(function()
	for player in entries do task.spawn(stop, player) end
	local t0 = os.clock()
	task.wait(0.1)
	while stopping > 0 and os.clock() - t0 < 25 do task.wait(0.1) end
end)
