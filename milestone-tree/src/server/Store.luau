--!strict
--[[
	Store: one DataStore record per player, { save = JSON, options = JSON, time = os.time(), lock = { job, t } }.

	The lock keeps two servers from playing the same save at once (a quick server hop): load takes it (waiting for
	a live lock elsewhere to be released, and taking over one older than LOCK_TTL), every save refreshes it, and
	the last save on leaving releases it. A save only writes while this server still holds the lock.

	The device options (motion, map detail, labels, interface size) live apart, under "client_<userId>" in the same
	DataStore: never part of the game save or the export string, and last write wins (no lock).
]]
local DataStoreService = game:GetService("DataStoreService")
local Config = require(script.Parent.Config)

local Store = {}

export type Record = { save: string?, options: string?, time: number?, lock: { job: string, t: number }? }

local store: DataStore? = nil
local function ds(): DataStore
	if store == nil then store = DataStoreService:GetDataStore(Config.STORE_NAME) end
	return store :: DataStore
end

local function key(userId: number): string
	return "player_" .. userId
end

local function jobId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

-- errors no retry fixes: Studio without API access, a place that was never published (a .rbxlx opened from disk).
-- After one of those the store is off for this server, so nobody waits on it again.
local unavailable: string? = nil
local function permanent(err: any): boolean
	local s = string.lower(tostring(err))
	return string.find(s, "studioaccesstoapisnotallowed", 1, true) ~= nil or string.find(s, "publish", 1, true) ~= nil
		or string.find(s, "api services", 1, true) ~= nil or string.find(s, "not allowed", 1, true) ~= nil
		or string.find(s, "403", 1, true) ~= nil
end

local function retry<T...>(f: () -> T...): (boolean, any)
	if unavailable then return false, unavailable end
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(f)
		if ok then return true, err end
		if permanent(err) then
			unavailable = tostring(err)
			warn("[MilestoneTree] saving is off on this server: " .. tostring(err)
				.. " (publish the place and turn on Game Settings > Security > Enable Studio Access to API Services)")
			return false, err
		end
		task.wait(attempt)
	end
	return false, err
end

-- -> record (empty for a new player), or nil + reason when the save could not be read
function Store.load(userId: number): (Record?, string?)
	for _ = 1, 10 do
		local blocked = false
		local ok, result = retry(function()
			return ds():UpdateAsync(key(userId), function(old: Record?): Record?
				local rec: Record = old or {}
				local lock = rec.lock
				if lock and lock.job ~= jobId() and os.time() - lock.t < Config.LOCK_TTL then
					blocked = true
					return nil
				end
				rec.lock = { job = jobId(), t = os.time() }
				return rec
			end)
		end)
		if not ok then return nil, tostring(result) end
		if not blocked then return (result or {}) :: Record, nil end
		task.wait(6) -- another server still has this save open: give it time to save and let go
	end
	-- the other server never let go: take the save over as it is
	local ok, result = retry(function()
		return ds():UpdateAsync(key(userId), function(old: Record?): Record?
			local rec: Record = old or {}
			rec.lock = { job = jobId(), t = os.time() }
			return rec
		end)
	end)
	if not ok then return nil, tostring(result) end
	return (result or {}) :: Record, nil
end

-- write the game; release = true on leaving. false if the lock was lost (another server took the save over).
function Store.save(userId: number, save: string, options: string?, release: boolean?): (boolean, string?)
	local lost = false
	local ok, err = retry(function()
		return ds():UpdateAsync(key(userId), function(old: Record?): Record?
			local rec: Record = old or {}
			if rec.lock and rec.lock.job ~= jobId() then
				lost = true
				return nil
			end
			rec.save = save
			rec.options = options
			rec.time = os.time()
			rec.lock = if release then nil else { job = jobId(), t = os.time() }
			return rec
		end)
	end)
	if not ok then return false, tostring(err) end
	if lost then return false, "another server has this save open" end
	return true, nil
end

-- the player's device options, or nil (none saved yet, or the store could not be read)
function Store.loadPrefs(userId: number): { [string]: any }?
	local ok, result = retry(function()
		return ds():GetAsync("client_" .. userId)
	end)
	if ok and type(result) == "table" then return result end
	return nil
end

function Store.savePrefs(userId: number, prefs: { [string]: any }): (boolean, string?)
	local ok, err = retry(function()
		return ds():SetAsync("client_" .. userId, prefs)
	end)
	if not ok then return false, tostring(err) end
	return true, nil
end

return Store
