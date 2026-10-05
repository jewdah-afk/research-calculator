--!nonstrict
-- Player persistence.
--   * Session locking: a save carries { lock = {job, t}, data }. Loading claims the lock via
--     UpdateAsync; another server holding a fresh lock makes us wait/retry, so two servers can
--     never write the same player at once (no rollback/dupe on fast server hops).
--   * Retries with exponential backoff on every DataStore call.
--   * Versioned migrations run inside Economy.deserialize.
--   * Rolling backups: one per player per day in a separate store (restore by hand if needed).
--   * Studio without API access falls back to in-memory data (warns once).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.OrbEconomy)

local DataService = {}

local STORE = "OrbGame_v1"
local BACKUP_STORE = "OrbGame_backup_v1"
local LOCK_STALE_SECONDS = 300 -- a lock older than this is considered abandoned (server crash)
local LOAD_ATTEMPTS = 6
local JOB = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

local store, backup
local ok = pcall(function()
	store = DataStoreService:GetDataStore(STORE)
	backup = DataStoreService:GetDataStore(BACKUP_STORE)
end)
if not ok then
	warn("[DataService] DataStores unavailable (enable Studio API access). Using in-memory saves.")
end
DataService.available = store ~= nil

local function retry(label: string, fn)
	local delay = 1
	for attempt = 1, 5 do
		local okCall, result = pcall(fn)
		if okCall then
			return true, result
		end
		warn(string.format("[DataService] %s failed (attempt %d): %s", label, attempt, tostring(result)))
		task.wait(delay)
		delay = math.min(delay * 2, 16)
	end
	return false, nil
end

local function key(userId: number): string
	return "p_" .. userId
end

-- Load and lock. Returns data (always; falls back to fresh data) and whether it's safe to save.
function DataService.load(player: Player)
	if not store then
		return Economy.newData("orig"), false
	end
	for attempt = 1, LOAD_ATTEMPTS do
		local claimed, payload = false, nil
		local okCall = retry("load " .. player.UserId, function()
			store:UpdateAsync(key(player.UserId), function(old)
				old = type(old) == "table" and old or {}
				local lock = old.lock
				if lock and lock.job ~= JOB and os.time() - (lock.t or 0) < LOCK_STALE_SECONDS then
					claimed = false
					payload = nil
					return nil -- leave it alone; another server owns this player
				end
				claimed = true
				payload = old.data
				old.lock = { job = JOB, t = os.time() }
				return old
			end)
		end)
		if okCall and claimed then
			return Economy.deserialize(payload), true
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(math.min(2 ^ attempt, 15)) -- other server is still saving; give it time
	end
	-- couldn't get the lock: let them play but never save over the other session
	warn("[DataService] could not lock", player.UserId, "- playing without saving")
	return Economy.newData("orig"), false
end

-- Save; `release` drops the session lock (on leave).
function DataService.save(player: Player, data, release: boolean?)
	if not (store and data) then
		return false
	end
	local serialized = Economy.serialize(data)
	local okCall = retry("save " .. player.UserId, function()
		store:UpdateAsync(key(player.UserId), function(old)
			old = type(old) == "table" and old or {}
			local lock = old.lock
			if lock and lock.job ~= JOB and os.time() - (lock.t or 0) < LOCK_STALE_SECONDS then
				return nil -- we lost the lock; never overwrite another session
			end
			old.data = serialized
			old.lock = if release then nil else { job = JOB, t = os.time() }
			old.savedAt = os.time()
			return old
		end)
	end)
	return okCall
end

-- One backup per player per day (cheap insurance against bad updates).
local lastBackupDay = {}
function DataService.backup(player: Player, data)
	if not (backup and data) then
		return
	end
	local day = os.date("!%Y%m%d")
	if lastBackupDay[player.UserId] == day then
		return
	end
	lastBackupDay[player.UserId] = day
	task.spawn(retry, "backup " .. player.UserId, function()
		backup:SetAsync(key(player.UserId) .. "_" .. day, Economy.serialize(data))
	end)
end

DataService.isStudio = RunService:IsStudio()
return DataService
