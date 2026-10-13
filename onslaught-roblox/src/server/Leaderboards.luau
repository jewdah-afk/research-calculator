--[[
	Global leaderboards (OrderedDataStore).
	  classic  best wave in a pure Classic run (any map, Medium or harder)
	  plus     best wave in an Onslaught+ run that used no in-game product (assisted runs never count)
	  kills    lifetime kills, an EternityNum encoded with EN.lbencode so it keeps its order past 2^53
	Writes only raise a score (UpdateAsync keeps the max). Reads are cached for two minutes.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EN = require(ReplicatedStorage.Shared.Onslaught.EternityNum)

local Leaderboards = {}

local stores = {}
for board, name in Config.LEADERBOARD_STORES do
	stores[board] = DataStoreService:GetOrderedDataStore(name)
end
local cache = {} -- [board] = { t, rows }
local names = {} -- [userId] = name
local RANKED_MODES = { medium = true, hard = true, extreme = true }

local function raise(board: string, userId: number, value: number)
	local store = stores[board]
	if not store or value <= 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(userId), function(old)
				if old and old >= value then
					return nil
				end
				return math.floor(value)
			end)
		end)
		if not ok then
			warn("[Leaderboards]", board, err)
		end
	end)
end

-- Called once per player when a run is final.
function Leaderboards.submit(player: Player, settings, run, lifetimeKills)
	local ranked = not settings.challengeIndex and RANKED_MODES[settings.mode]
	if ranked and not settings.plus then
		raise("classic", player.UserId, run.wave)
	elseif ranked and settings.plus and not run.assisted then
		raise("plus", player.UserId, run.wave)
	end
	raise("kills", player.UserId, EN.lbencode(lifetimeKills))
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then n else ("#" .. userId)
	return names[userId]
end

function Leaderboards.top(board: string)
	local c = cache[board]
	if c and os.clock() - c.t < 120 then
		return c.rows
	end
	local rows = {}
	local store = stores[board]
	local ok, pages = pcall(store.GetSortedAsync, store, false, 25)
	if ok then
		for rank, e in pages:GetCurrentPage() do
			local value = e.value
			local shown = if board == "kills" then EN.short(EN.lbdecode(value), 2) else tostring(value)
			table.insert(rows, { rank = rank, name = nameOf(tonumber(e.key) or 0), value = shown })
		end
	end
	cache[board] = { t = os.clock(), rows = rows }
	return rows
end

return Leaderboards
