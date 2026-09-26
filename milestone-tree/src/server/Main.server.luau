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
	  Prefs   client -> server   the device options (shared/PrefsSchema: motion, detail, labels, size, weather,
	                             guide, the volumes, seenPrestige); mirrored as JSON in the player's MT_Prefs
	                             attribute and saved apart from the game (Store.savePrefs)
	  Board   client -> server   (RemoteFunction) a leaderboard page: (board key) -> Leaderboards.page + the
	                             player's own value

	Cheating: the game runs here; the client only sends button presses, and an action is carried out only when it
	is on the player's screen (Session:act). The remotes are limited per player (presses: a token bucket; resyncs
	and board pages: one per interval) and a player who keeps flooding past the limits is kicked. Leaderboards are
	written by the server from the server's own game.

	Updates: BindToClose on a live server sends everyone to a holding server while their games save, and the holding
	server sends them back to the new version (SoftShutdown).
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local root = script.Parent
local Config = require(root:WaitForChild("Config"))
local Store = require(root:WaitForChild("Store"))
local Shop = require(root:WaitForChild("Shop"))
local Leaderboards = require(root:WaitForChild("Leaderboards"))
local SoftShutdown = require(root:WaitForChild("SoftShutdown"))
local Boards = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Boards"))

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
local boardRemote = Instance.new("RemoteFunction")
boardRemote.Name = "Board"
boardRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local sessionsFolder = Instance.new("Folder")
sessionsFolder.Name = "Sessions"
sessionsFolder.Parent = root

local template = ServerStorage:WaitForChild("MilestoneTreeWorker") :: Actor

type Prefs = { [string]: any }
type Entry = {
	actor: Actor, tokens: number, last: number,
	drops: number, dropsAt: number, resyncAt: number, resyncHeld: boolean, boardAt: number,
	prefsAt: number, prefsPending: Prefs?, prefsSet: boolean, prefsDirty: boolean, prefsSaveAt: number,
}
local entries: { [Player]: Entry } = {}

local function fatal(player: Player, text: string)
	warn("[MilestoneTree] " .. player.Name .. ": " .. text)
	viewRemote:FireClient(player, { fatal = text })
end

-- ---------------------------------------------------------------------------------------------- device options
-- the keys, choices and defaults are shared/PrefsSchema (the client's table too); a missing key takes its default and
-- a wrong value falls back, so an old stored record still loads
local PrefsSchema = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("PrefsSchema"))

-- a valid options table from the client or the store, or nil
local function validPrefs(p: any): Prefs?
	return PrefsSchema.clean(p)
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
	a:SetAttribute("TickShare", Config.TICK_CPU_SHARE)
	a.Name = "Player_" .. player.UserId
	a.Parent = sessionsFolder
	local entry: Entry = {
		actor = a, tokens = Config.ACTIONS_PER_SECOND, last = os.clock(),
		drops = 0, dropsAt = os.clock(), resyncAt = 0, resyncHeld = false, boardAt = 0,
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
	-- the player's passes (perks go to the Actor, which keeps them for the session)
	task.spawn(Shop.refresh, player)
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

Shop.start(function(player: Player): Actor?
	local entry = entries[player]
	return if entry then entry.actor else nil
end)
-- each game's share of a core: a full server shares its cores (Worker reads the Actor's TickShare)
local function shareCpu()
	local n = 0
	for _ in entries do n += 1 end
	local share = math.clamp(Config.SERVER_CPU / math.max(n, 1), Config.MIN_CPU_SHARE, Config.TICK_CPU_SHARE)
	for _, e in entries do e.actor:SetAttribute("TickShare", share) end
end
-- a holding server (players waiting out an update, see SoftShutdown): no games, just a message and the way back
local HOLDING = SoftShutdown.holding()
local function say(player: Player, text: string)
	viewRemote:FireClient(player, { status = text })
end
Players.PlayerAdded:Connect(function(player: Player)
	if HOLDING then
		-- the client asks for its screen (Ready) once it runs: tell it again then
		SoftShutdown.hold(player, say)
		return
	end
	task.defer(shareCpu)
	start(player)
end)
Players.PlayerRemoving:Connect(function(player: Player)
	stop(player)
	shareCpu()
end)
for _, p in Players:GetPlayers() do
	if HOLDING then SoftShutdown.hold(p, say) else task.spawn(start, p) end
end
task.defer(shareCpu)

-- a token bucket per player: holding a buyable fires 20 presses a second, a burst of clicks a few more
-- a dropped request counts towards the flood limit: FLOOD_DROPS within FLOOD_WINDOW seconds is not a player
local function dropped(player: Player, entry: Entry)
	local now = os.clock()
	if now - entry.dropsAt > Config.FLOOD_WINDOW then
		entry.drops, entry.dropsAt = 0, now
	end
	entry.drops += 1
	if entry.drops == Config.FLOOD_DROPS then
		warn("[MilestoneTree] " .. player.Name .. " (" .. player.UserId .. ") flooded the remotes and was kicked")
		player:Kick("Too many requests. Rejoin to keep playing.")
	end
end
local function allow(player: Player, entry: Entry): boolean
	local now = os.clock()
	entry.tokens = math.min(Config.ACTIONS_PER_SECOND, entry.tokens + (now - entry.last) * Config.ACTIONS_PER_SECOND)
	entry.last = now
	if entry.tokens < 1 then
		dropped(player, entry)
		return false
	end
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
	if not entry then return end
	if not validAction(a) then
		dropped(player, entry)
		return
	end
	if not allow(player, entry) then return end
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
	if HOLDING then
		say(player, "Updating to the new version")
		return
	end
	local entry = entries[player]
	if not entry then return end
	-- a whole screen is costly to build: one per RESYNC_EVERY. A quicker ask is held and sent when the interval is
	-- over (the client asks again at boot when its first ask came before the game was up); a third one meanwhile is
	-- spam
	local now = os.clock()
	local wait = entry.resyncAt + Config.RESYNC_EVERY - now
	if wait > 0 then
		if entry.resyncHeld then
			dropped(player, entry)
			return
		end
		entry.resyncHeld = true
		task.delay(wait, function()
			entry.resyncHeld = false
			entry.resyncAt = os.clock()
			if entries[player] == entry and not entry.actor:GetAttribute("Error") then entry.actor:SendMessage("resync") end
		end)
		return
	end
	entry.resyncAt = now
	if entry.actor:GetAttribute("Error") then
		fatal(player, tostring(entry.actor:GetAttribute("Error")))
	else
		entry.actor:SendMessage("resync")
	end
end)

-- a leaderboard page, and the player's own value on that board
boardRemote.OnServerInvoke = function(player: Player, board: any): any
	local entry = entries[player]
	if not entry or type(board) ~= "string" or #board > 16 or Boards.get(board) == nil then return nil end
	local now = os.clock()
	if now - entry.boardAt < Config.BOARD_EVERY then
		dropped(player, entry)
		return { ok = false, board = board, entries = {}, error = "Slow down a little." }
	end
	entry.boardAt = now
	local page = Leaderboards.page(board)
	return { ok = page.ok, board = page.board, entries = page.entries, error = page.error,
		you = if page.ok then Leaderboards.mine(board, player.UserId) else nil }
end

game:BindToClose(function()
	-- an update: the players go to a holding server and come back to the new version (SoftShutdown); their games
	-- are saved here meanwhile
	SoftShutdown.closing(Players:GetPlayers(), function()
		for player in entries do task.spawn(stop, player) end
		local t0 = os.clock()
		task.wait(0.1)
		while stopping > 0 and os.clock() - t0 < 25 do task.wait(0.1) end
	end)
end)
