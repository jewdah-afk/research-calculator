--!nonstrict
-- Admin commands (events, announcements). Every call is verified on the server:
-- the client admin panel is only a convenience and grants nothing by itself.

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local AdminService = {}

-- EDIT ME: who can drop events.
AdminService.USER_IDS = {
	-- 123456789, -- your Roblox UserId
}
AdminService.GROUP_ID = 0 -- set to your group id to allow ranks >= MIN_RANK
AdminService.MIN_RANK = 254

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Events)

local cache = {}
function AdminService.isAdmin(player: Player): boolean
	if cache[player.UserId] ~= nil then
		return cache[player.UserId]
	end
	local ok = table.find(AdminService.USER_IDS, player.UserId) ~= nil
	if not ok and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		ok = true -- the place owner is always an admin
	end
	if not ok and AdminService.GROUP_ID > 0 then
		local s, rank = pcall(player.GetRankInGroup, player, AdminService.GROUP_ID)
		ok = s and rank >= AdminService.MIN_RANK
	end
	cache[player.UserId] = ok
	return ok
end

function AdminService.init(remotes, EventService, broadcast)
	local lastCall = {}
	remotes.Admin.OnServerInvoke = function(player: Player, command, a, b)
		if not AdminService.isAdmin(player) then
			return false, "not an admin"
		end
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.5 then
			return false, "slow down"
		end
		lastCall[player] = now
		if command == "isAdmin" then
			return true
		elseif command == "types" then
			local out = {}
			for id, def in Events.TYPES do
				table.insert(out, { id = id, name = def.name, minutes = def.minutes, color = def.color })
			end
			table.sort(out, function(x, y)
				return x.name < y.name
			end)
			return true, out
		elseif command == "list" then
			return true, EventService.list()
		elseif command == "start" and type(a) == "string" then
			local ok, err = EventService.start(a, tonumber(b), player.Name)
			if ok then
				broadcast("event", { id = a, by = player.Name })
			end
			return ok, err
		elseif command == "stop" then
			return EventService.stop(type(a) == "string" and a or nil)
		elseif command == "announce" and type(a) == "string" and #a > 0 and #a <= 120 then
			local okF, filtered = pcall(function()
				return TextService:FilterStringAsync(a, player.UserId):GetNonChatStringForBroadcastAsync()
			end)
			if okF then
				broadcast("announce", filtered)
				return true
			end
			return false, "filter failed"
		end
		return false, "unknown command"
	end
	Players.PlayerRemoving:Connect(function(p)
		lastCall[p] = nil
		cache[p.UserId] = nil
	end)
end

return AdminService
