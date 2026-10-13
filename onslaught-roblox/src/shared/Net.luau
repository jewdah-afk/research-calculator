--[[
	Remote names and the action protocol. The server creates the remotes; clients wait for them.

	Client -> server
	  Action:FireServer(op, ...)          in-match commands (build, upgrade, ...), validated and rate-limited by Match
	  Request:InvokeServer(op, ...)       lobby, profile, research, store; returns a result table
	Server -> client
	  State:FireClient(buffer)            Snapshot.encode, SNAPSHOT_HZ times a second
	  Event:FireClient(kind, payload)     match start/end, turret details, header, toasts, profile updates
]]

-- `game` is absent under Lune (tests use only Net.ACTIONS and Net.check)
local RunService = if game then game:GetService("RunService") else nil
local ReplicatedStorage = if game then game:GetService("ReplicatedStorage") else nil

local Net = {}

local NAMES = { Action = "RemoteEvent", State = "RemoteEvent", Event = "RemoteEvent", Request = "RemoteFunction" }

-- Every in-match op and its argument types. Match validates against this before touching the engine.
-- n = finite number, s = short string, b = boolean, ? = optional.
Net.ACTIONS = {
	build = { "s", "n", "n" }, -- kind, x, y
	upgrade = { "n", "s", "b?" }, -- turretId, stat, maxOut
	sell = { "n" },
	move = { "n", "n", "n" },
	mode = { "n", "s" }, -- target mode
	lock = { "n" },
	dir = { "n", "n", "n" }, -- deg, spread (0 = off, 50/30/15)
	join = { "n", "n" }, -- targeterId, turretId
	focus = { "n", "n" },
	combonly = { "n", "s" }, -- combonlyId, colour
	send = {}, -- next wave now
	speed = { "n" }, -- host
	pause = { "b" }, -- host
	prefs = { "n", "b" }, -- host: wave spacing (s), send when clear
	queue = { "n", "s" }, -- Commander Tools: queue an upgrade (stat or "clear")
	blueprintSave = {}, -- Commander Tools
	blueprintLoad = {},
	product = { "s", "n?", "n?" }, -- prompt an in-game product (id, x, y for Airstrike)
	useCredit = { "s", "n?", "n?" }, -- spend a product credit (bought earlier, not used)
}

local folder: Folder
function Net.init()
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("OnslaughtNet") :: Folder
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "OnslaughtNet"
			for name, class in NAMES do
				local r = Instance.new(class)
				r.Name = name
				r.Parent = folder
			end
			folder.Parent = ReplicatedStorage
		end
	else
		folder = ReplicatedStorage:WaitForChild("OnslaughtNet") :: Folder
		for name in NAMES do
			folder:WaitForChild(name)
		end
	end
	return Net
end
function Net.get(name: string): any
	return folder:FindFirstChild(name)
end

-- Validate remote arguments against a spec like { "n", "s", "b?" }. Returns the cleaned args or nil.
function Net.check(spec, args)
	if #args > #spec then
		return nil
	end
	local out = {}
	for i, t in spec do
		local v = args[i]
		local optional = string.sub(t, -1) == "?"
		local base = if optional then string.sub(t, 1, 1) else t
		if v == nil then
			if not optional then
				return nil
			end
		elseif base == "n" then
			if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
				return nil
			end
		elseif base == "s" then
			if type(v) ~= "string" or #v > 40 then
				return nil
			end
		elseif base == "b" then
			if type(v) ~= "boolean" then
				return nil
			end
		end
		out[i] = v
	end
	return out
end

return Net
