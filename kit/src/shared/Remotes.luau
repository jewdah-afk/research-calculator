--!nonstrict
--[[
	Remotes — one place that knows every remote's name.

	The server calls Remotes.event/Remotes.func during boot (creating them); the
	client calls the same functions and waits. Nothing else in the codebase ever
	types a remote name as a string literal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "SparkRemotes"

local function container()
	if IS_SERVER then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
end

local function get(className, name)
	local folder = container()
	assert(folder, "Remotes: remote folder never replicated")

	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	return folder:WaitForChild(name, 30)
end

function Remotes.event(name)
	return get("RemoteEvent", name)
end

function Remotes.func(name)
	return get("RemoteFunction", name)
end

-- Canonical names. Client -> server unless noted.
Remotes.Names = {
	Hatch = "Hatch",             -- carry an egg home and open it
	PlacePet = "PlacePet",       -- put an inventory pet on a pad
	StorePet = "StorePet",       -- take a pad pet back to inventory
	Collect = "Collect",         -- empty the vault into coins
	BuyUpgrade = "BuyUpgrade",
	BuyLock = "BuyLock",
	Rebirth = "Rebirth",
	Fuse = "Fuse",
	ClaimDaily = "ClaimDaily",
	StateChanged = "StateChanged",   -- server -> client, full profile snapshot
	Notify = "Notify",               -- server -> client, toast text
	HatchResult = "HatchResult",     -- server -> client, drives the reveal
	StealProgress = "StealProgress", -- server -> client, drives the steal bar
}

return Remotes
