--!strict
--[[
	SoftShutdown: publishing an update and shutting the servers down ("Shut down all servers", "Restart servers")
	moves the players over instead of kicking them.

	    SoftShutdown.closing(players, stopAll, say)   BindToClose: every player goes to one reserved "holding" server
	                                                  (teleport data mtSoftShutdown) while stopAll() saves their games
	                                                  here; a player joining meanwhile is sent there too
	    SoftShutdown.holding() -> boolean             this server is a holding server (a reserved server, no owner)
	    SoftShutdown.hold(player, say)                in a holding server: say("Updating...") on the loading screen,
	                                                  then after HOLD_SECONDS teleport the player to a public server of
	                                                  the new version, again until they are gone (up to TRIES times)

	Each player is teleported on their own: a group TeleportAsync from a server that is shutting down is known to fail
	("The Source Game is invalid") once it holds 2+ players. One ReserveServer code keeps them together in the holding
	server. A teleport that fails after it started (TeleportInitFailed) is tried again. The holding server also sets
	workspace MT_Holding, and the client (first/Boot) teleports itself back if it is still there after a while.

	Not in Studio (no teleports there) and not from a holding server itself. The games are saved by the old server
	(the saves release their locks, and a new server waits for a held lock anyway), so the new server loads them as
	usual; HOLD_SECONDS gives those saves time.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local SoftShutdown = {}

local HOLD_SECONDS = 6
local TRIES = 5
local CLOSE_BUDGET = 27 -- BindToClose gets 30 s in all
SoftShutdown.HOLD_SECONDS = HOLD_SECONDS
SoftShutdown.TRIES = TRIES

local FLAG = "mtSoftShutdown"

-- a reserved server (no owner) that players reached through a soft shutdown
function SoftShutdown.holding(): boolean
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then return false end
	for _, p in Players:GetPlayers() do
		local ok, data = pcall(function() return p:GetJoinData() end)
		local td = if ok and type(data) == "table" then data.TeleportData else nil
		if type(td) == "table" and td[FLAG] then return true end
	end
	-- nobody here yet: a reserved server of this game is only ever made by the soft shutdown
	return #Players:GetPlayers() == 0
end

local function teleport(player: Player, options: TeleportOptions?): boolean
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then warn("[MilestoneTree] teleport of " .. player.Name .. " failed: " .. tostring(err)) end
	return ok
end

-- teleport one player, trying again (a failed call, or a TeleportInitFailed after it) until they are gone
local function here(p: Player): boolean
	return p.Parent ~= nil
end
local failed: { [Player]: number } = {}
TeleportService.TeleportInitFailed:Connect(function(player: Player)
	failed[player] = (failed[player] or 0) + 1
end)
local function send(player: Player, options: TeleportOptions?, tries: number, onTry: ((number) -> ())?)
	for try = 1, tries do
		if not here(player) then return end
		if onTry then onTry(try) end
		local before = failed[player] or 0
		if teleport(player, options) then
			-- started: it either takes them out, or fails with TeleportInitFailed (then try again)
			local t0 = os.clock()
			while here(player) and (failed[player] or 0) == before and os.clock() - t0 < 12 do task.wait(0.25) end
			if not here(player) then return end
		else
			task.wait(math.min(2 * try, 6))
		end
	end
end
SoftShutdown._send = send

function SoftShutdown.closing(players: { Player }, stopAll: () -> (), say: ((Player, string) -> ())?)
	if RunService:IsStudio() or #players == 0 or SoftShutdown.holding() then
		stopAll()
		return
	end
	local t0 = os.clock()
	for _, p in players do
		if say then say(p, "Updating to the new version. Your game is saved, taking you over") end
	end
	-- one reserved server for everyone (a few tries); without it each goes to a public server of the new version
	local code: string? = nil
	for try = 1, 3 do
		local ok, c = pcall(function() return TeleportService:ReserveServer(game.PlaceId) end)
		if ok and type(c) == "string" then
			code = c
			break
		end
		warn("[MilestoneTree] ReserveServer failed: " .. tostring(c))
		task.wait(try * 0.5)
	end
	local options: TeleportOptions? = nil
	if code then
		local o = Instance.new("TeleportOptions")
		o.ReservedServerAccessCode = code
		o:SetTeleportData({ [FLAG] = true })
		options = o
	end
	local function go(p: Player) task.spawn(send, p, options, 3, nil) end
	for _, p in players do go(p) end
	local late = Players.PlayerAdded:Connect(go)
	stopAll()
	-- the teleports take the players out; wait for them within BindToClose's time
	while #Players:GetPlayers() > 0 and os.clock() - t0 < CLOSE_BUDGET do task.wait(0.5) end
	late:Disconnect()
end

function SoftShutdown.hold(player: Player, say: (Player, string) -> ())
	workspace:SetAttribute("MT_Holding", true)
	say(player, "Updating to the new version")
	task.spawn(function()
		task.wait(HOLD_SECONDS)
		send(player, nil, TRIES, function(try: number)
			say(player, if try == 1 then "Taking you back" else "Taking you back (try " .. try .. ")")
		end)
		if here(player) then say(player, "Could not take you back. Please rejoin the game.") end
	end)
end

return SoftShutdown
