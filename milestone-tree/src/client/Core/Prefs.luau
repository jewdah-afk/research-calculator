--!strict
--[[
	Prefs: the device options (DESIGN.md 6 Options THIS DEVICE, plan 1.10): Motion, Map Detail, Map Labels,
	Interface Size, Weather, Guide, the Music / SFX / Ambience volumes and the first-prestige memory (seenPrestige).
	The keys, choices and defaults are shared/PrefsSchema, the same table the server validates with. They are not
	part of the game save.

	The server keeps them in its own DataStore key and mirrors them into the LocalPlayer attribute MT_Prefs (JSON)
	before the first view. Prefs.set updates at once on this client and sends the table on the Prefs remote (at most
	once a second; the server validates it). Prefs.changed fires (key) for every value that changed.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(script.Parent:WaitForChild("Signal"))
local Schema = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("PrefsSchema"))

type Prefs = Types.Prefs

local Prefs = {}

local ALLOWED: { [string]: { any } } = Schema.CHOICES
Prefs.ALLOWED = ALLOWED
local current: Prefs = Schema.defaults() :: any
Prefs.changed = Signal.new() :: Signal.Signal<string>

local function valid(key: string, value: any): boolean
	return Schema.valid(key, value)
end

local function sameList(a: { string }, b: { string }): boolean
	if #a ~= #b then return false end
	for i, v in a do
		if b[i] ~= v then return false end
	end
	return true
end

-- apply a table of values; fires changed for each key that moved
local function merge(t: { [string]: any })
	local moved = {}
	for key in ALLOWED do
		local v = t[key]
		if v ~= nil and valid(key, v) and (current :: any)[key] ~= v then
			(current :: any)[key] = v
			table.insert(moved, key)
		end
	end
	local seen = t.seenPrestige
	if seen ~= nil and valid("seenPrestige", seen) and not sameList(current.seenPrestige, seen) then
		current.seenPrestige = table.clone(seen)
		table.insert(moved, "seenPrestige")
	end
	for _, k in moved do Prefs.changed:Fire(k) end
end

local started = false
local function readAttribute()
	local lp = Players.LocalPlayer
	if lp == nil then return end
	local raw = lp:GetAttribute("MT_Prefs")
	if type(raw) ~= "string" or raw == "" then return end
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and type(t) == "table" then merge(t) end
end
local function start()
	if started then return end
	started = true
	local lp = Players.LocalPlayer
	if lp == nil then return end
	readAttribute()
	lp:GetAttributeChangedSignal("MT_Prefs"):Connect(readAttribute)
end

function Prefs.get(): Prefs
	start()
	local t = table.clone(current)
	t.seenPrestige = table.clone(current.seenPrestige)
	return t
end

-- one send a second at most: the last value wins
local sendQueued = false
local lastSend = -math.huge
local function send()
	local remotes = ReplicatedStorage:FindFirstChild("MilestoneTreeRemotes")
	local remote = if remotes then remotes:FindFirstChild("Prefs") else nil
	if remote == nil or not remote:IsA("RemoteEvent") then return end
	lastSend = os.clock()
	remote:FireServer(Prefs.get())
end
local function queueSend()
	if sendQueued then return end
	local wait = 1 - (os.clock() - lastSend)
	if wait <= 0 then
		send()
		return
	end
	sendQueued = true
	task.delay(wait, function()
		sendQueued = false
		send()
	end)
end

function Prefs.set(key: string, value: any)
	start()
	if key == "seenPrestige" or not valid(key, value) or (current :: any)[key] == value then return end
	(current :: any)[key] = value
	Prefs.changed:Fire(key)
	queueSend()
end

-- has this layer's first prestige already played its big moment on this account?
function Prefs.seen(layer: string): boolean
	start()
	return table.find(current.seenPrestige, layer) ~= nil
end

-- remember that it has (the oldest entry goes once the list is full)
function Prefs.markSeen(layer: string)
	start()
	if Prefs.seen(layer) or not string.match(layer, "^%l+$") or #layer > 4 then return end
	local list = table.clone(current.seenPrestige)
	table.insert(list, layer)
	while #list > Schema.MAX_SEEN do table.remove(list, 1) end
	current.seenPrestige = list
	Prefs.changed:Fire("seenPrestige")
	queueSend()
end

return Prefs
