--!nonstrict
-- Single source of truth for the game's remotes (created by the server, awaited by clients).
--   Action  (RemoteFunction) client -> server : (name, ...args) -> success
--   State   (RemoteEvent)    server -> client : serialized player data
--   Spawn   (RemoteEvent)    server -> client : { {id, kind, rarity, variant, spawner} }
--   Collect (RemoteEvent)    client -> server : { {id, x}, ... } orbs that reached the bottom
--   Board   (RemoteEvent)    server -> client : "rebuild" | "clear" | "duplicate", payload
--   Notify  (RemoteEvent)    server -> client : kind, payload (toasts: newRarity, tier, weather, event)
--   Events / Leaderboards / Admin : see SPEC below

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}
local SPEC = {
	Action = "RemoteFunction",
	State = "RemoteEvent",
	Spawn = "RemoteEvent",
	Collect = "RemoteEvent",
	Board = "RemoteEvent",
	Notify = "RemoteEvent",
	Ghost = "RemoteEvent", -- server -> all clients : (ownerUserId, ownerName, { {kind, rarity, variant, rare} }) Mega Board spectators
	Events = "RemoteEvent", -- server -> client : active global events list
	Leaderboards = "RemoteEvent", -- server -> client : { board = { {name, value, display}, ... } }
	Admin = "RemoteFunction", -- client -> server : (command, ...) admin-only, verified server-side
}

function Remotes.server()
	local folder = ReplicatedStorage:FindFirstChild("OrbRemotes") or Instance.new("Folder")
	folder.Name = "OrbRemotes"
	folder.Parent = ReplicatedStorage
	local out = {}
	for name, class in SPEC do
		local r = folder:FindFirstChild(name) or Instance.new(class)
		r.Name = name
		r.Parent = folder
		out[name] = r
	end
	return out
end

function Remotes.client()
	local folder = ReplicatedStorage:WaitForChild("OrbRemotes")
	local out = {}
	for name in SPEC do
		out[name] = folder:WaitForChild(name)
	end
	return out
end

return Remotes
