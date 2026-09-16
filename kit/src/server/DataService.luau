--!nonstrict
--[[
	DataService — DataStore persistence with retries, session locking, autosave
	and a migration hook.

	Deliberately dependency-free so the kit runs with nothing installed. If you
	would rather use a battle-tested library, ProfileStore is a drop-in mental
	model for this API (get / release / autosave) and is what I would move to
	before a real launch:  https://madstudioroblox.github.io/ProfileStore/
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

local SAVE_ENABLED = not RunService:IsStudio() or Config.StudioSaves
local AUTOSAVE_SECONDS = 120
local SESSION_TIMEOUT = 90          -- another server's lock is stale after this
local LOAD_ATTEMPTS = 5

local store = DataStoreService:GetDataStore(Config.DataStoreKey)
local profiles = {}                 -- [player] = data table
local loading = {}                  -- [player] = true while a load is in flight

local TEMPLATE = {
	version = 1,
	coins = Config.StartingCoins,
	vault = 0,
	rebirths = 0,
	hatches = 0,
	upgrades = { speed = 0, luck = 0, storage = 0, pads = 0 },
	inventory = {},      -- array of { uid, biome, pet, tier }
	placed = {},         -- [tostring(padIndex)] = uid
	locks = {},          -- [tostring(padIndex)] = lockLevel
	shieldUntil = 0,
	luckBoostUntil = 0,
	dailyStreak = 0,
	dailyClaimedAt = 0,
	lastSeen = 0,
	stolenFromMe = 0,
	stolenByMe = 0,
	receipts = {},       -- [purchaseId] = true, so a refunded reconnect cannot double-grant
}

local function deepCopy(source)
	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- Fills in anything the template gained since this save was written.
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = type(value) == "table" and deepCopy(value) or value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

-- Bump this and add a branch when the shape changes in a breaking way.
local function migrate(data)
	if data.version == nil then
		data.version = 1
	end
	return data
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function retry(attempts, fn)
	local delayFor = 0.5
	local lastError
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < attempts then
			task.wait(delayFor)
			delayFor *= 2
		end
	end
	return false, lastError
end

function DataService.get(player)
	return profiles[player]
end

-- Yields until the profile exists (or the player leaves). Services use this
-- instead of assuming load order.
function DataService.await(player, timeout)
	local deadline = os.clock() + (timeout or 20)
	while os.clock() < deadline do
		if profiles[player] then
			return profiles[player]
		end
		if not player.Parent then
			return nil
		end
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.load(player)
	if profiles[player] or loading[player] then
		return
	end
	loading[player] = true

	local data
	if SAVE_ENABLED then
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, result = retry(3, function()
				return store:UpdateAsync(keyFor(player), function(stored)
					stored = stored or deepCopy(TEMPLATE)

					local session = stored.session
					local locked = session
						and session.jobId ~= game.JobId
						and (os.time() - (session.time or 0)) < SESSION_TIMEOUT

					if locked then
						return nil -- someone else owns it; back off and try again
					end

					stored.session = { jobId = game.JobId, time = os.time() }
					return stored
				end)
			end)

			if ok and result then
				data = result
				break
			end

			if attempt < LOAD_ATTEMPTS then
				task.wait(2 * attempt)
			end
		end

		if not data then
			-- Never hand the player a fresh profile over a locked/erroring key:
			-- that is how saves get silently wiped. Kick instead.
			loading[player] = nil
			player:Kick("Couldn't load your data. Please rejoin in a moment.")
			return
		end
	else
		data = deepCopy(TEMPLATE)
	end

	data = reconcile(migrate(data), TEMPLATE)
	profiles[player] = data
	loading[player] = nil
	return data
end

function DataService.save(player, release)
	local data = profiles[player]
	if not data or not SAVE_ENABLED then
		return
	end

	data.lastSeen = os.time()
	local snapshot = deepCopy(data)
	snapshot.session = release and nil or { jobId = game.JobId, time = os.time() }

	local ok, err = retry(3, function()
		return store:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)

	if not ok then
		warn(("[DataService] save failed for %s: %s"):format(player.Name, tostring(err)))
	end
	return ok
end

function DataService.release(player)
	DataService.save(player, true)
	profiles[player] = nil
end

function DataService.start()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in pairs(profiles) do
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if not SAVE_ENABLED then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)
end

return DataService
