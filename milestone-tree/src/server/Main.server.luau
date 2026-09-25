--!strict
--[[
	Milestone Tree NG+ on Roblox: server entry point.

	Each player gets their own game (the web game's JavaScript, transpiled to Luau, see Session and Game) running in
	their own Actor (the Worker in ServerStorage), so players' games run in parallel. This script owns the players,
	the remotes and the rate limits; the Worker owns the game and the save.

	Remotes (ReplicatedStorage.MilestoneTreeRemotes):
	  View    server -> client   screen patches (see Session:view)
	  Act     client -> server   (action, hold?) a button on the screen, or { "key", name } for a hotkey
	  Ready   client -> server   the client wants the whole screen (first load, UI rebuilt, out of sync)
	  Prefs   client -> server   { motion, detail, labels, size } the device options; mirrored as JSON in the
	                             player's MT_Prefs attribute and saved apart from the game (Store.savePrefs)
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local root = script.Parent
local Config = require(root:WaitForChild("Config"))
local Store = require(root:WaitForChild("Store"))

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
local readyRemote = remote("Ready")
local prefsRemote = remote("Prefs")
remotes.Parent = ReplicatedStorage

local sessionsFolder = Instance.new("Folder")
sessionsFolder.Name = "Sessions"
sessionsFolder.Parent = root

local template = ServerStorage:WaitForChild("MilestoneTreeWorker") :: Actor

type Prefs = { motion: string, detail: string, labels: string, size: number }
type Entry = {
	actor: Actor, tokens: number, last: number,
	prefsAt: number, prefsPending: Prefs?, prefsSet: boolean, prefsDirty: boolean, prefsSaveAt: number,
}
local entries: { [Player]: Entry } = {}

local function fatal(player: Player, text: string)
	warn("[MilestoneTree] " .. player.Name .. ": " .. text)
	viewRemote:FireClient(player, { fatal = text })
end

-- ---------------------------------------------------------------------------------------------- device options
local PREF_CHOICES: { [string]: { [any]: boolean } } = {
	motion = { SYSTEM = true, FULL = true, REDUCED = true },
	detail = { AUTO = true, HIGH = true, LOW = true },
	labels = { AUTO = true, ALWAYS = true, OFF = true },
	size = { [90] = true, [100] = true, [115] = true },
}

-- a valid options table from the client or the store, or nil
local function validPrefs(p: any): Prefs?
	if type(p) ~= "table" then return nil end
	local n = 0
	for k, v in p do
		n += 1
		local choices = PREF_CHOICES[k]
		if type(k) ~= "string" or not choices or not choices[v] then return nil end
	end
	if n ~= 4 then return nil end
	return { motion = p.motion, detail = p.detail, labels = p.labels, size = p.size }
end

local function setPrefsAttribute(player: Player, prefs: Prefs)
	player:SetAttribute("MT_Prefs", HttpService:JSONEncode(prefs))
end

local function loadPrefs(player: Player, entry: Entry)
	local saved = validPrefs(Store.loadPrefs(player.UserId))
	-- a change the player made while this was loading wins
	if saved and not entry.prefsSet and entries[player] == entry then setPrefsAttribute(player, saved) end
end

local function savePrefsLater(player: Player, entry: Entry)
	entry.prefsSaveAt = os.clock() + Config.PREFS_SAVE_DELAY
	if entry.prefsDirty then return end
	entry.prefsDirty = true
	task.spawn(function()
		while os.clock() < entry.prefsSaveAt and entries[player] == entry do task.wait(0.5) end
		entry.prefsDirty = false
		local json = player:GetAttribute("MT_Prefs")
		local prefs = if type(json) == "string" then validPrefs(HttpService:JSONDecode(json)) else nil
		if prefs then Store.savePrefs(player.UserId, prefs) end
	end)
end

-- at most one change per PREFS_INTERVAL; a quicker one is held and applied when the interval is over
local function applyPrefs(player: Player, entry: Entry)
	local wait = entry.prefsAt + Config.PREFS_INTERVAL - os.clock()
	if wait > 0 then
		task.delay(wait, function()
			if entries[player] == entry and entry.prefsPending then applyPrefs(player, entry) end
		end)
		return
	end
	local prefs = entry.prefsPending
	if not prefs then return end
	entry.prefsPending = nil
	entry.prefsAt = os.clock()
	entry.prefsSet = true
	setPrefsAttribute(player, prefs)
	savePrefsLater(player, entry)
end

local function start(player: Player)
	if entries[player] then return end
	local a = template:Clone()
	a.Name = "Player_" .. player.UserId
	a.Parent = sessionsFolder
	local entry: Entry = {
		actor = a, tokens = Config.ACTIONS_PER_SECOND, last = os.clock(),
		prefsAt = 0, prefsPending = nil, prefsSet = false, prefsDirty = false, prefsSaveAt = 0,
	}
	entries[player] = entry
	task.spawn(loadPrefs, player, entry)
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

prefsRemote.OnServerEvent:Connect(function(player: Player, p: any)
	local entry = entries[player]
	local prefs = validPrefs(p)
	if not entry or not prefs then return end
	local held = entry.prefsPending ~= nil
	entry.prefsPending = prefs
	if not held then applyPrefs(player, entry) end
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
