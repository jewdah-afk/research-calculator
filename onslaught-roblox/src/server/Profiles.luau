--[[
	Player profiles in a DataStore, with a session lock so two servers never write the same profile.

	Plain numbers hold everything that stays small (level, XP into the level, Intel, research levels).
	Lifetime totals that only ever grow (total XP, kills, bounty earned) are EternityNum values, saved as
	strings with EN.toString and read back with EN.fromSave, so they never overflow or lose their order.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EN = require(ReplicatedStorage.Shared.Onslaught.EternityNum)

local Profiles = {}

local store = DataStoreService:GetDataStore(Config.DATASTORE)
local LOCK_STALE = 30 * 60 -- a lock older than this belongs to a server that died; take it
local cache: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local listeners = {}

local function defaults()
	return {
		v = 1,
		level = 1, xp = 0, intel = 0, prestige = 0,
		research = {}, passes = {}, quests = nil, xpBoostUntil = 0,
		lifetimeXP = "0", lifetimeKills = "0", lifetimeBounty = "0", -- EternityNum strings
		kills = { normal = 0, medium = 0, hard = 0 }, -- best kills in a single game (the original's unlock rules)
		unlocks = { extreme = false, sandbox = false, sandbox2 = false },
		best = {}, -- ["classic:medium:map1"] = wave
		chal = {}, -- [challengeIndex] = true
		blueprints = {}, -- [mapKey] = { {kind, x, y, lvl} }
		credits = {}, -- [productId] = n  (bought but not usable at the time)
		purchases = {}, -- [receiptId] = os.time()  (idempotent ProcessReceipt)
		rerolls = 0,
		skin = "default",
		games = 0, wins = 0,
		settings = { waveSpacing = 20, waveFollow = false, showRanges = false },
	}
end
local function reconcile(data)
	local d = defaults()
	for k, v in d do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" then
			for k2, v2 in v do
				if data[k][k2] == nil then
					data[k][k2] = v2
				end
			end
		end
	end
	return data
end
local function key(player: Player)
	return "u_" .. player.UserId
end

-- ================================================================ load / save
function Profiles.load(player: Player)
	local jobId = if RunService:IsStudio() then "studio" else game.JobId
	local data
	for attempt = 1, 5 do
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				old = old or defaults()
				local lock = old.lock
				if lock and lock.job ~= jobId and os.time() - (lock.t or 0) < LOCK_STALE and attempt < 4 then
					data = nil -- someone else holds it; retry (and take it after 3 tries: their server is gone or stuck)
					return nil
				end
				old.lock = { job = jobId, t = os.time() }
				data = old
				return old
			end)
		end)
		if ok and data then
			break
		end
		if not ok then
			warn("[Profiles] load failed for", player.Name, err)
		end
		task.wait(1 + attempt)
	end
	if not player.Parent then
		return nil -- left while loading
	end
	if not data then
		player:Kick("Couldn't load your save data. Please rejoin.")
		return nil
	end
	data = reconcile(data)
	data.lock = nil
	cache[player] = data
	return data
end

function Profiles.save(player: Player, release: boolean?): boolean
	local data = cache[player]
	if not data then
		return false
	end
	local jobId = if RunService:IsStudio() then "studio" else game.JobId
	-- trim the receipt log: Roblox retries a receipt for a few days at most
	local now = os.time()
	for id, t in data.purchases do
		if now - t > 14 * 86400 then
			data.purchases[id] = nil
		end
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			if old and old.lock and old.lock.job ~= jobId and now - (old.lock.t or 0) < LOCK_STALE then
				return nil -- another server took over (we were presumed dead): don't overwrite its data
			end
			local out = table.clone(data)
			out.lock = if release then nil else { job = jobId, t = now }
			return out
		end)
	end)
	if ok then
		dirty[player] = nil
	else
		warn("[Profiles] save failed for", player.Name, err)
	end
	return ok
end

function Profiles.get(player: Player)
	return cache[player]
end
-- Change a profile and tell the player's client. `fn(profile)` mutates in place.
function Profiles.update(player: Player, fn)
	local data = cache[player]
	if not data then
		return false
	end
	fn(data)
	dirty[player] = true
	for _, cb in listeners do
		task.spawn(cb, player, data)
	end
	return true
end
function Profiles.onChanged(cb)
	table.insert(listeners, cb)
end
function Profiles.release(player: Player)
	if cache[player] then
		Profiles.save(player, true)
		cache[player] = nil
		dirty[player] = nil
	end
end

-- EternityNum helpers for the lifetime totals
function Profiles.addTotal(data, field: string, amount: number)
	data[field] = EN.toString(EN.add(EN.fromSave(data[field] or "0"), amount))
end
function Profiles.total(data, field: string)
	return EN.fromSave(data[field] or "0")
end

function Profiles.start()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			for player in dirty do
				task.spawn(Profiles.save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		local n = 0
		for player in cache do
			n += 1
			task.spawn(function()
				Profiles.save(player, true)
				n -= 1
			end)
		end
		local t0 = os.clock()
		while n > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
	Players.PlayerRemoving:Connect(Profiles.release)
end

return Profiles
