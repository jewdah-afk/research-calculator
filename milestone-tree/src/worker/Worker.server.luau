--!nocheck
--[[
	Worker: one player's game, in its own Actor so every player's game runs in parallel (Parallel Luau).

	Main clones this Actor into ServerScriptService.MilestoneTree.Sessions for each player and sends it messages:
	  "start" (player)            load the save, start the game
	  "act"   (action, hold)      a button press / hotkey from the player's screen
	  "resync"                    the client wants the whole screen again
	  "stop"                      save, release the save lock, send the leaderboard stats, then set Stopped
	The leaderboard stats (server/Leaderboards) go out LB_EVERY seconds (and 30 s after joining, and on leaving), only
	the boards whose value went up. The Actor's TickShare attribute (Main: SERVER_CPU / players) caps this game's
	share of a core.
	The game ticks in the parallel phase; sending to the client and DataStore calls happen in the serial phase.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local actor = script:GetActor()
local root = ServerScriptService:WaitForChild("MilestoneTree")
local Config = require(root:WaitForChild("Config"))
local Session = require(root:WaitForChild("Session"))
local Store = require(root:WaitForChild("Store"))
local Leaderboards = require(root:WaitForChild("Leaderboards"))
local Boards = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Boards"))
local TowerNum = require(ReplicatedStorage:WaitForChild("TowerNum")) :: any
local remotes = ReplicatedStorage:WaitForChild("MilestoneTreeRemotes")
local viewRemote: RemoteEvent = remotes:WaitForChild("View")

-- the game: the runtime, TowerNum and the transpiled game files in load order. If any of it fails to load, Main
-- shows the error on the player's screen (the Error attribute) instead of leaving it blank.
local deps
local okLoad, loadErr = pcall(function()
	local runtime = root:WaitForChild("Runtime")
	local gameFolder = root:WaitForChild("Game")
	local chunks = {}
	for name in string.gmatch(require(gameFolder:WaitForChild("Manifest")), "[^,]+") do
		table.insert(chunks, require(gameFolder:WaitForChild(name, 10)))
	end
	deps = {
		TN = require(ReplicatedStorage:WaitForChild("TowerNum")),
		JSRT = require(runtime:WaitForChild("JSRT")),
		BEcore = require(runtime:WaitForChild("BEcore")),
		Fast = require(runtime:WaitForChild("Fast")),
		chunks = chunks,
	}
end)
if not okLoad then
	warn("[MilestoneTree] the game failed to load: " .. tostring(loadErr))
	actor:SetAttribute("Error", "The game failed to load on the server: " .. tostring(loadErr))
	return
end

local player: Player? = nil
local session = nil
local canSave = false        -- false when the save could not be loaded: never overwrite it with a new game
local stopping = false
local tickEvery = Config.TICK
local tickCost = 0           -- running average seconds per tick
local viewEvery = Config.VIEW
local viewCost = 0           -- running average seconds per screen build
local sinceTick, sinceView, sinceSave, sinceSent = 0, 0, 0, 0
local pushNow = false        -- refresh the screen at the next heartbeat (after a button press)
local perks: { [string]: any } = {} -- from the player's passes (Main/Shop)
local pendingWarp = 0        -- Time Warp seconds bought before the session started
local saving = false
local playedBase, loadedAt = 0, os.clock() -- real seconds played before this session (the save), and when it began
local sinceLb = 0
local lbSent: { [string]: number } = {} -- the keys last sent per board (only a higher one is sent again)
local lbBusy = false

local function playedNow(): number
	return playedBase + (os.clock() - loadedAt)
end

local function nowMs(): number
	return DateTime.now().UnixTimestampMillis
end

local function send(patch)
	if player and player.Parent then viewRemote:FireClient(player, patch) end
end

local function notice(text: string)
	if session then table.insert(session.notices, text) end
	pushNow = true
end

-- serial phase only (DataStore yields). The last save (release) waits for an autosave still in flight, so that the
-- autosave cannot take the save lock back after the release.
local function saveNow(release: boolean?)
	if not session or not player or not canSave then return end
	if saving then
		if not release then return end
		local t0 = os.clock()
		while saving and os.clock() - t0 < 30 do task.wait(0.1) end
	end
	saving = true
	local save, options = session:checkpoint()
	if save then
		-- the capsule's SAVING... / SAVED (patch.save, sent once each)
		session.saveEvent = "saving"
		pushNow = true
		local ok, err = Store.save(player.UserId, save, options, release, playedNow())
		if ok then
			session.saveEvent = "saved"
			pushNow = true
		elseif session.saveEvent == "saving" then
			session.saveEvent = nil
		end
		if not ok then
			warn("[MilestoneTree] save failed for " .. player.Name .. ": " .. tostring(err))
			if err == "another server has this save open" then
				canSave = false
				actor:SetAttribute("CanGrant", false)
				notice("Your save was opened on another server, so this server stopped saving it. Rejoin to keep playing.")
			end
		end
	end
	session.wantSave = false
	saving = false
end

-- the player's number notation lives in their device options (MT_Prefs, set by Main after validation)
local HttpService = game:GetService("HttpService")
local function applyNotation()
	local plr = player
	if session == nil or plr == nil then return end
	local mode = "SUFFIX"
	local json = plr:GetAttribute("MT_Prefs")
	if type(json) == "string" then
		local ok, prefs = pcall(HttpService.JSONDecode, HttpService, json)
		if ok and type(prefs) == "table" and (prefs.notation == "SUFFIX" or prefs.notation == "SCIENTIFIC") then
			mode = prefs.notation
		end
	end
	if session.notation ~= mode then
		session:setNotation(mode)
		pushNow = true
	end
end

-- the leaderboard keys of this game (serial phase: reads the game, then DataStore calls)
local function lbKeys(): { [string]: number }
	local out: { [string]: number } = {}
	local JS, ENV = session.JS, session.ENV
	local ok, arr = pcall(ENV.rbx_lbStats, nil)
	if ok and arr and JS.LEN[arr] then
		for i = 0, JS.LEN[arr] - 1 do
			local pair = arr[i]
			local key, v = pair[0], pair[1]
			local board = Boards.get(tostring(key))
			if board then
				local value: any = v
				if type(v) ~= "number" then
					local okD, d = pcall(JS.D, v)
					if okD and d then
						value = TowerNum.fromEN({ Sign = JS.tonum(JS.P(d, "sign")), Layer = JS.tonum(JS.P(d, "layer")),
							Exp = JS.tonum(JS.P(d, "mag")) })
					else
						value = 0
					end
				end
				out[board.key] = Boards.keyOf(board, value)
			end
		end
	end
	out.time = Boards.keyOf(Boards.get("time") :: any, playedNow())
	return out
end
local function sendLb()
	if lbBusy or not session or not player or not canSave or not Store.available() then return end
	lbBusy = true
	local ok, keys = pcall(lbKeys)
	if ok then
		local fresh: { [string]: number } = {}
		for board, key in keys do
			if key > (lbSent[board] or 0) then fresh[board] = key end
		end
		if next(fresh) then
			Leaderboards.submit(player.UserId, fresh)
			for board, key in fresh do lbSent[board] = key end
			Leaderboards.forget(player.UserId)
		end
	else
		warn("[MilestoneTree] leaderboard stats failed: " .. tostring(keys))
	end
	lbBusy = false
end

local function begin(plr: Player)
	player = plr
	plr:GetAttributeChangedSignal("MT_Prefs"):Connect(applyNotation)
	viewRemote:FireClient(plr, { status = "Loading your save..." })
	local rec, err = Store.load(plr.UserId)
	if not plr.Parent then
		if rec then task.spawn(Store.save, plr.UserId, rec.save or "", rec.options, true) end
		actor:SetAttribute("Stopped", true)
		return
	end
	local save, options = nil, nil
	if rec then
		canSave = true
		save, options = rec.save, rec.options
		playedBase = tonumber(rec.played) or 0
	else
		warn("[MilestoneTree] could not load " .. plr.Name .. "'s save: " .. tostring(err))
	end
	local ok, s = pcall(Session.new, deps, save, options, nowMs())
	if not ok then
		warn("[MilestoneTree] " .. plr.Name .. "'s save would not start (" .. tostring(s) .. "); starting a new game without saving")
		canSave = false
		s = Session.new(deps, nil, nil, nowMs())
		table.insert(s.notices, "Your save could not be started, so this is a new game that will NOT be saved. Rejoin to try again.")
	elseif not rec then
		table.insert(s.notices, "Your save could not be loaded (" .. tostring(err) .. "). Playing without saving; rejoin to try again.")
	end
	session = s
	loadedAt = os.clock()
	sinceLb = Config.LB_EVERY - 30 -- the first stats 30 s in, so a new player shows up soon
	applyNotation()
	s:setPerks(perks)
	if pendingWarp > 0 then
		s:addWarp(pendingWarp)
		pendingWarp = 0
	end
	-- Shop grants a Time Warp only while this game can keep it (a game that cannot save would lose it)
	-- (Studio without API access saves nothing: test purchases are still granted there)
	actor:SetAttribute("CanGrant", canSave or (RunService:IsStudio() and not Store.available()))
	pushNow = true
end
-- feed a Time Warp still on its way in full, before a last save (leaving, shutdown): the save then holds all of it
local function drainWarp()
	if not session then return end
	local n = 0
	while (session.warp or 0) > 0 and n < 2000 do
		session:tick(nowMs())
		n += 1
	end
end
actor:BindToMessage("start", function(plr: Player)
	task.spawn(function() -- loading yields (DataStore)
		local ok, err = pcall(begin, plr)
		if not ok then
			warn("[MilestoneTree] could not start " .. plr.Name .. "'s game: " .. tostring(err))
			viewRemote:FireClient(plr, { fatal = "Your game could not start on the server: " .. tostring(err) })
		end
	end)
end)

actor:BindToMessageParallel("act", function(a, hold)
	if not session or stopping then return end
	local ok = session:act(a, nowMs(), hold == true)
	if ok then pushNow = true end
end)

-- passes (Main/Shop): { speed = 2? }; kept for a session that is still loading
actor:BindToMessage("perks", function(p: any)
	perks = if type(p) == "table" then p else {}
	if session then
		session:setPerks(perks)
		pushNow = true
	end
end)
-- a Time Warp bought (a granted developer product): seconds of progress, fed through the next ticks
actor:BindToMessage("warp", function(seconds: any, name: any)
	if type(seconds) ~= "number" or seconds <= 0 then return end
	if session then
		session:addWarp(seconds)
		if stopping then drainWarp() end
		table.insert(session.notices, string.format("%s: %s of progress is on its way!", tostring(name or "Time Warp"),
			if seconds >= 3600 then string.format("%g hour%s", seconds / 3600, if seconds == 3600 then "" else "s") else string.format("%d s", seconds)))
		pushNow = true
	else
		pendingWarp += seconds
	end
end)

actor:BindToMessageParallel("resync", function()
	if not session then return end
	session:resetView()
	pushNow = true
end)

actor:BindToMessage("stop", function()
	stopping = true
	actor:SetAttribute("CanGrant", false)
	task.spawn(function()
		drainWarp()
		saveNow(true)
		sendLb()
		actor:SetAttribute("Stopped", true)
	end)
end)

RunService.Heartbeat:ConnectParallel(function(dt: number)
	if not session or stopping then return end
	sinceTick += dt
	sinceView += dt
	sinceSave += dt
	sinceSent += dt
	sinceLb += dt
	if sinceTick >= tickEvery then
		sinceTick = 0
		local t0 = os.clock()
		session:tick(nowMs())
		local cost = os.clock() - t0
		tickCost = tickCost * 0.9 + cost * 0.1
		-- keep this player's game under its share of a core: slower ticks when they get expensive
		local share = actor:GetAttribute("TickShare")
		tickEvery = math.clamp(tickCost / (if type(share) == "number" and share > 0 then share else Config.TICK_CPU_SHARE),
			Config.TICK, Config.MAX_TICK)
	end
	local wantSave = session.wantSave or sinceSave >= Config.AUTOSAVE
	if not (pushNow or sinceView >= viewEvery or wantSave) then return end
	local patch, changed = nil, false
	if pushNow or sinceView >= viewEvery then
		sinceView = 0
		pushNow = false
		local v0 = os.clock()
		patch, changed = session:view()
		viewCost = viewCost * 0.9 + (os.clock() - v0) * 0.1
		-- refresh less often when building the screen gets expensive (never slower than MAX_VIEW)
		viewEvery = math.clamp(viewCost / Config.VIEW_CPU_SHARE, Config.VIEW, Config.MAX_VIEW)
		if not canSave then patch.unsaved = true end
	end
	task.synchronize()
	if patch and (changed or patch.pop or patch.notice or patch.save or patch.full
		or sinceSent >= Config.KEEPALIVE) then
		sinceSent = 0
		send(patch)
	end
	if wantSave then
		sinceSave = 0
		session.wantSave = false
		task.spawn(saveNow, false)
	end
	if sinceLb >= Config.LB_EVERY then
		sinceLb = 0
		task.spawn(sendLb)
	end
end)

actor:SetAttribute("Ready", true)
