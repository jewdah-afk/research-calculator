--!strict
--[[
	Prefs: the device options (DESIGN.md 6 Options THIS DEVICE, plan 1.10): Motion, Map Detail, Map Labels and
	Interface Size. They are not part of the game save or the export string.

	The server keeps them in its own DataStore key and mirrors them into the LocalPlayer attribute MT_Prefs (JSON)
	before the first view. Prefs.set updates at once on this client and sends the table on the Prefs remote (at most
	once a second; the server validates it). Prefs.changed fires (key) for every value that changed.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(script.Parent:WaitForChild("Signal"))

type Prefs = Types.Prefs

local Prefs = {}

local ALLOWED: { [string]: { any } } = {
	motion = { "SYSTEM", "FULL", "REDUCED" },
	detail = { "AUTO", "HIGH", "LOW" },
	labels = { "AUTO", "ALWAYS", "OFF" },
	size = { 90, 100, 115 },
}
Prefs.ALLOWED = ALLOWED
local current: Prefs = { motion = "SYSTEM", detail = "AUTO", labels = "AUTO", size = 100 }
Prefs.changed = Signal.new() :: Signal.Signal<string>

local function valid(key: string, value: any): boolean
	local list = ALLOWED[key]
	if list == nil then return false end
	return table.find(list, value) ~= nil
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
	return table.clone(current)
end

-- one send a second at most: the last value wins
local sendQueued = false
local lastSend = -math.huge
local function send()
	local remotes = ReplicatedStorage:FindFirstChild("MilestoneTreeRemotes")
	local remote = if remotes then remotes:FindFirstChild("Prefs") else nil
	if remote == nil or not remote:IsA("RemoteEvent") then return end
	lastSend = os.clock()
	remote:FireServer(table.clone(current))
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
	if not valid(key, value) or (current :: any)[key] == value then return end
	(current :: any)[key] = value
	Prefs.changed:Fire(key)
	queueSend()
end

return Prefs
