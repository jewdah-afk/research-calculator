--!nonstrict
-- Global admin events. Source of truth is a DataStore key; MessagingService pushes changes to
-- every live server instantly, and each server also re-reads the key every 60s as a fallback.
-- Events feed Balance (bonus budget), so any number of stacked events stays safe.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Events = require(Shared.Events)

local EventService = {}
local TOPIC = "OrbEvents_v1"
local KEY = "active"

local store
pcall(function()
	store = DataStoreService:GetDataStore("OrbGame_events_v1")
end)

local active = {} -- list of { id, endsAt, by, uid }
local listeners = {}

local function prune()
	local now = os.time()
	local out = {}
	for _, ev in active do
		if (ev.endsAt or 0) > now and Events.TYPES[ev.id] then
			table.insert(out, ev)
		end
	end
	active = out
end

local function publishLocal()
	prune()
	Balance.setEvents(active)
	Balance.ctx.now = os.time()
	for _, fn in listeners do
		task.spawn(fn, active)
	end
end

function EventService.onChanged(fn)
	table.insert(listeners, fn)
end

function EventService.list()
	prune()
	return active
end

local function readStore()
	if not store then
		return
	end
	local ok, res = pcall(function()
		return store:GetAsync(KEY)
	end)
	if ok and type(res) == "table" then
		active = res
		publishLocal()
	end
end

local function mutate(fn)
	-- apply to the shared store, then broadcast
	if store then
		local ok = pcall(function()
			store:UpdateAsync(KEY, function(old)
				local list = type(old) == "table" and old or {}
				return fn(list)
			end)
		end)
		if ok then
			readStore()
		end
	else
		active = fn(active)
		publishLocal()
	end
	pcall(function()
		MessagingService:PublishAsync(TOPIC, "changed")
	end)
end

function EventService.start(id: string, minutes: number?, by: string)
	local def, m = Events.validate(id, minutes)
	if not def then
		return false, m
	end
	mutate(function(list)
		local now = os.time()
		-- extending an event of the same type adds time instead of stacking a duplicate
		for _, ev in list do
			if ev.id == id and (ev.endsAt or 0) > now then
				ev.endsAt += m * 60
				return list
			end
		end
		table.insert(list, { id = id, endsAt = now + m * 60, by = by, uid = tostring(now) .. id })
		return list
	end)
	return true
end

function EventService.stop(id: string?)
	mutate(function(list)
		local out = {}
		for _, ev in list do
			if id and ev.id ~= id then
				table.insert(out, ev)
			end
		end
		return out
	end)
	return true
end

function EventService.init()
	readStore()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function()
			readStore()
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			readStore()
			publishLocal() -- also expires finished events
		end
	end)
	publishLocal()
end

return EventService
