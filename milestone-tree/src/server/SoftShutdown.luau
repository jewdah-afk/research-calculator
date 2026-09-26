--!strict
--[[
	SoftShutdown: publishing an update and shutting the servers down ("Shut down all servers" / "Migrate to latest
	update") moves the players over instead of kicking them.

	    SoftShutdown.closing(players, stopAll)   BindToClose on a live game server: every player goes to one reserved
	                                             "holding" server at once (teleport data mtSoftShutdown), while
	                                             stopAll() saves their games here
	    SoftShutdown.holding() -> boolean        this server is a holding server (a reserved server the teleport made)
	    SoftShutdown.hold(player, say)           in a holding server: say("Updating...") on the loading screen, then
	                                             after HOLD_SECONDS teleport the player to a public server of the new
	                                             version (again after a failed try, up to TRIES times)

	Not in Studio (no teleports there) and not from a holding server itself. The games are saved by the old server
	(the saves release their locks), so the new server loads them as usual; HOLD_SECONDS gives those saves time.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local SoftShutdown = {}

local HOLD_SECONDS = 6
local TRIES = 4
SoftShutdown.HOLD_SECONDS = HOLD_SECONDS

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

local function teleport(list: { Player }, options: TeleportOptions?): boolean
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, list, options)
	end)
	if not ok then warn("[MilestoneTree] teleport failed: " .. tostring(err)) end
	return ok
end

function SoftShutdown.closing(players: { Player }, stopAll: () -> ())
	if RunService:IsStudio() or game.PrivateServerId ~= "" or #players == 0 then
		stopAll()
		return
	end
	task.spawn(function()
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		options:SetTeleportData({ [FLAG] = true })
		for try = 1, 3 do
			if teleport(players, options) then break end
			task.wait(try)
		end
	end)
	stopAll()
	-- the teleport takes the players out; wait for them (BindToClose allows about 30 s in all)
	local t0 = os.clock()
	while #Players:GetPlayers() > 0 and os.clock() - t0 < 20 do task.wait(0.5) end
end

function SoftShutdown.hold(player: Player, say: (Player, string) -> ())
	say(player, "Updating to the new version")
	task.spawn(function()
		task.wait(HOLD_SECONDS)
		for try = 1, TRIES do
			if player.Parent == nil then return end
			say(player, if try == 1 then "Taking you back" else "Taking you back (try " .. try .. ")")
			if teleport({ player }, nil) then return end
			task.wait(3 * try)
		end
		say(player, "Could not take you back. Please rejoin the game.")
	end)
end

return SoftShutdown
