--!strict
--[[
	Store: one DataStore record per player, { save = JSON, options = JSON, time = os.time(), lock = { job, t } }.

	The lock keeps two servers from playing the same save at once (a quick server hop): load takes it (waiting for
	a live lock elsewhere to be released, and taking over one older than LOCK_TTL), every save refreshes it, and
	the last save on leaving releases it. A save only writes while this server still holds the lock.
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

local function retry<T...>(f: () -> T...): (boolean, any)
	local ok, err
	for attempt = 1, 4 do
		ok, err = pcall(f)
		if ok then return true, err end
		task.wait(attempt * 1.5)
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

return Store
