--!strict
--[[
	Leaderboards: one OrderedDataStore per board of shared/Boards ("LB_<key>_v1", user id -> a whole number).

	    Leaderboards.submit(userId, keys)    keys = { [board] = stored key }: each board keeps the highest ever sent
	    Leaderboards.addRobux(userId, n)     Robux spent (a granted product, a bought pass) adds to the robux board
	    Leaderboards.page(board)             { ok, board, entries = { { rank, id, name, value } }, error? }: the top
	                                         Config.LB_TOP, names resolved, cached Config.LB_CACHE seconds
	    Leaderboards.mine(board, userId)     the player's own stored value as the board reads it, or nil

	Only the server writes: the Worker sends each player's stats from their own game (Worker "lb"), Shop the Robux. The
	values are what the server's game holds, so a client cannot post one. Config.LB_BANNED ids are never written or
	shown. Every DataStore call is guarded: without DataStores (Studio without API access) a page says so.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent:WaitForChild("Config"))
local Boards = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Boards"))

export type Entry = { rank: number, id: number, name: string, value: string }
export type Page = { ok: boolean, board: string, entries: { Entry }, error: string? }

local Leaderboards = {}

local stores: { [string]: OrderedDataStore } = {}
local function store(board: string): OrderedDataStore
	local s: OrderedDataStore? = stores[board]
	if s == nil then
		local made = DataStoreService:GetOrderedDataStore("LB_" .. board .. "_v1")
		stores[board] = made
		return made
	end
	return s :: OrderedDataStore
end

local banned: { [number]: boolean } = {}
for _, id in Config.LB_BANNED do banned[id] = true end
Leaderboards.banned = banned

-- the highest value ever sent stays (a reset in the game never lowers a board); returns how many boards were written
function Leaderboards.submit(userId: number, keys: { [string]: number }): number
	if banned[userId] then return 0 end
	local n = 0
	for board, key in keys do
		if Boards.get(board) == nil or type(key) ~= "number" or key <= 0 or key ~= key then continue end
		local ok = pcall(function()
			store(board):UpdateAsync(tostring(userId), function(old: any): any
				local was = tonumber(old) or 0
				if key <= was then return nil end
				return key
			end)
		end)
		if ok then n += 1 end
	end
	return n
end

function Leaderboards.addRobux(userId: number, amount: number)
	if banned[userId] or type(amount) ~= "number" or amount <= 0 then return end
	local ok, err = pcall(function()
		store("robux"):UpdateAsync(tostring(userId), function(old: any): any
			return (tonumber(old) or 0) + math.floor(amount)
		end)
	end)
	if not ok then warn("[MilestoneTree] could not add Robux spent for " .. userId .. ": " .. tostring(err)) end
end

-- display names, cached for the server's life
local names: { [number]: string } = {}
local function resolve(ids: { number })
	local missing = {}
	for _, id in ids do
		if names[id] == nil then table.insert(missing, id) end
	end
	if #missing == 0 then return end
	local ok, infos = pcall(function()
		return game:GetService("UserService"):GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and type(infos) == "table" then
		for _, info in infos do
			if type(info) == "table" and type(info.Id) == "number" then
				names[info.Id] = if type(info.DisplayName) == "string" and info.DisplayName ~= "" then info.DisplayName else info.Username
			end
		end
	end
	for _, id in missing do
		if names[id] == nil then
			local p = Players:GetPlayerByUserId(id)
			if p then
				names[id] = p.DisplayName
			else
				local okName, name = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
				names[id] = if okName and type(name) == "string" then name else "Player " .. id
			end
		end
	end
end

local pages: { [string]: { t: number, page: Page } } = {}
local loading: { [string]: boolean } = {}
function Leaderboards.page(board: string): Page
	local b = Boards.get(board)
	if b == nil then return { ok = false, board = board, entries = {}, error = "No such board." } end
	local hit = pages[board]
	if hit and os.clock() - hit.t < Config.LB_CACHE then return hit.page end
	-- one read per board at a time: the others wait for it (or take the last page)
	if loading[board] then
		local t0 = os.clock()
		while loading[board] and os.clock() - t0 < 8 do task.wait(0.1) end
		local again = pages[board]
		if again then return again.page end
	end
	loading[board] = true
	local ok, result = pcall(function()
		local sorted = store(board):GetSortedAsync(false, math.min(100, Config.LB_TOP + #Config.LB_BANNED))
		return sorted:GetCurrentPage()
	end)
	local page: Page
	if not ok then
		warn("[MilestoneTree] leaderboard " .. board .. " could not be read: " .. tostring(result))
		page = { ok = false, board = board, entries = {}, error = "Leaderboards are unavailable right now." }
		-- a failed read is kept a short while (not the full cache time), so a hiccup clears soon
		pages[board] = { t = os.clock() - Config.LB_CACHE + 10, page = page }
	else
		local ids = {}
		local rows = {}
		for _, row in result do
			local id = tonumber(row.key)
			if id and not banned[id] and #rows < Config.LB_TOP then
				table.insert(rows, { id = id, key = tonumber(row.value) or 0 })
				table.insert(ids, id)
			end
		end
		resolve(ids)
		local entries: { Entry } = {}
		for i, r in rows do
			table.insert(entries, { rank = i, id = r.id, name = names[r.id] or ("Player " .. r.id), value = Boards.show(b, r.key) })
		end
		page = { ok = true, board = board, entries = entries }
		pages[board] = { t = os.clock(), page = page }
	end
	loading[board] = nil
	return page
end

local mineCache: { [string]: { t: number, v: string? } } = {}
function Leaderboards.mine(board: string, userId: number): string?
	local b = Boards.get(board)
	if b == nil then return nil end
	local ck = board .. ":" .. userId
	local hit = mineCache[ck]
	if hit and os.clock() - hit.t < Config.LB_CACHE then return hit.v end
	local ok, v = pcall(function(): any
		local got = store(board):GetAsync(tostring(userId))
		return got
	end)
	local n = if ok then tonumber(v) else nil
	local out = if n then Boards.show(b, n) else nil
	mineCache[ck] = { t = os.clock(), v = out }
	return out
end
-- a player's own value changed (the Worker just wrote it): read it again next time
function Leaderboards.forget(userId: number)
	for ck in mineCache do
		if string.match(ck, ":(%d+)$") == tostring(userId) then mineCache[ck] = nil end
	end
end

return Leaderboards
