--!nocheck
--[[
	Worker: one player's game, in its own Actor so every player's game runs in parallel (Parallel Luau).

	Main clones this Actor into ServerScriptService.MilestoneTree.Sessions for each player and sends it messages:
	  "start" (player)            load the save, start the game
	  "act"   (action, hold)      a button press / hotkey from the player's screen
	  "import"(text)              a pasted save
	  "resync"                    the client wants the whole screen again
	  "stop"                      save, release the save lock, then set the Actor's Stopped attribute
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
local sinceTick, sinceView, sinceSave, sinceSent = 0, 0, 0, 0
local pushNow = false        -- refresh the screen at the next heartbeat (after a button press)
local saving = false

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
		local ok, err = Store.save(player.UserId, save, options, release)
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
				notice("Your save was opened on another server, so this server stopped saving it. Rejoin to keep playing.")
			end
		end
	end
	session.wantSave = false
	saving = false
end

local function begin(plr: Player)
	player = plr
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
	pushNow = true
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

actor:BindToMessageParallel("import", function(text)
	if not session or stopping then return end
	local ok, why = session:import(text, nowMs())
	if not ok then table.insert(session.notices, why) end
	pushNow = true
end)

actor:BindToMessageParallel("resync", function()
	if not session then return end
	session:resetView()
	pushNow = true
end)

actor:BindToMessage("stop", function()
	stopping = true
	task.spawn(function()
		saveNow(true)
		actor:SetAttribute("Stopped", true)
	end)
end)

RunService.Heartbeat:ConnectParallel(function(dt: number)
	if not session or stopping then return end
	sinceTick += dt
	sinceView += dt
	sinceSave += dt
	sinceSent += dt
	if sinceTick >= tickEvery then
		sinceTick = 0
		local t0 = os.clock()
		session:tick(nowMs())
		local cost = os.clock() - t0
		tickCost = tickCost * 0.9 + cost * 0.1
		-- keep this player's game under its share of a core: slower ticks when they get expensive
		tickEvery = math.clamp(tickCost / Config.TICK_CPU_SHARE, Config.TICK, Config.MAX_TICK)
	end
	local wantSave = session.wantSave or sinceSave >= Config.AUTOSAVE
	if not (pushNow or sinceView >= Config.VIEW or wantSave) then return end
	local patch, changed = nil, false
	if pushNow or sinceView >= Config.VIEW then
		sinceView = 0
		pushNow = false
		patch, changed = session:view()
		if not canSave then patch.unsaved = true end
	end
	task.synchronize()
	if patch and (changed or patch.pop or patch.notice or patch.export or patch.askImport or patch.imp or patch.save or patch.full
		or sinceSent >= Config.KEEPALIVE) then
		sinceSent = 0
		send(patch)
	end
	if wantSave then
		sinceSave = 0
		session.wantSave = false
		task.spawn(saveNow, false)
	end
end)

actor:SetAttribute("Ready", true)
