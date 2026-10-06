--!nonstrict
-- Global leaderboards (OrderedDataStore) + in-game leaderstats.
-- Ordered stores need integers, so huge values are stored as log10 * 100 (e.g. cash 1e250 -> 25000).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Big = require(Shared.Big)
local F = require(Shared.OrbFormulas)
local Progression = require(Shared.Progression)

local LeaderboardService = {}

local BOARDS = {
	-- id, title, value(data) -> integer, display(integer) -> string
	{ id = "cash", title = "TOTAL CASH", value = function(d)
		local l = Big.log10(d.totalMoney)
		return (l == l and l > 0) and math.floor(l * 100) or 0
	end, display = function(v)
		return "$" .. F.formatLog(v / 100)
	end },
	{ id = "tiers", title = "TIERS", value = function(d)
		return d.tiers
	end, display = tostring },
	{ id = "rebirths", title = "REBIRTHS", value = function(d)
		return math.min(d.rebirths, 2 ^ 52)
	end, display = function(v)
		return F.format(v)
	end },
	{ id = "runes", title = "RUNES OPENED", value = function(d)
		return d.runes and math.min(d.runes.opened, 2 ^ 52) or 0
	end, display = function(v)
		return F.format(v)
	end },
	{ id = "rarity", title = "BEST RARITY", value = function(d)
		return d.highestRarity
	end, display = function(v)
		local r = Progression.Rarities[v]
		return r and r.name or "-"
	end },
}
LeaderboardService.BOARDS = BOARDS

local stores = {}
pcall(function()
	for _, b in BOARDS do
		stores[b.id] = DataStoreService:GetOrderedDataStore("OrbLB_" .. b.id .. "_v1")
	end
end)

local cache = {} -- [boardId] = { {name, value, display}, ... }
local listeners = {}

function LeaderboardService.onUpdated(fn)
	table.insert(listeners, fn)
end

function LeaderboardService.get()
	return cache
end

-- leaderstats shown in the Roblox player list
function LeaderboardService.attach(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in { "Cash", "Tier", "Rebirths" } do
		local v = Instance.new("StringValue")
		v.Name = n
		v.Value = "0"
		v.Parent = ls
	end
	ls.Parent = player
end

function LeaderboardService.updateStats(player: Player, d)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	ls.Cash.Value = "$" .. F.format(d.money)
	ls.Tier.Value = tostring(d.tiers)
	ls.Rebirths.Value = F.format(d.rebirths)
end

function LeaderboardService.submit(player: Player, d)
	for _, b in BOARDS do
		local st = stores[b.id]
		if st then
			local value = b.value(d)
			task.spawn(pcall, function()
				st:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

local nameCache = {}
local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or ("#" .. userId)
	return nameCache[userId]
end

function LeaderboardService.refresh()
	for _, b in BOARDS do
		local st = stores[b.id]
		if st then
			local ok, pages = pcall(function()
				return st:GetSortedAsync(false, 50)
			end)
			if ok and pages then
				local rows = {}
				for i, entry in pages:GetCurrentPage() do
					table.insert(rows, { rank = i, name = nameOf(tonumber(entry.key)), value = entry.value, display = b.display(entry.value) })
				end
				cache[b.id] = { title = b.title, rows = rows }
			end
		end
	end
	for _, fn in listeners do
		task.spawn(fn, cache)
	end
end

function LeaderboardService.init()
	task.spawn(function()
		while true do
			LeaderboardService.refresh()
			task.wait(120)
		end
	end)
end

return LeaderboardService
