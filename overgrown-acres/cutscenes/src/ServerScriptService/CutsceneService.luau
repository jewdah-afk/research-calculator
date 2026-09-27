-- Server side of the cutscene system. Other server scripts call
-- CutsceneService.Play(player, "RowanAtTheFire") and listen to Finished.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Give up on a cutscene the client never reports back on (crash, leave).
local REPORT_TIMEOUT = 300

local remotes = Instance.new("Folder")
remotes.Name = "CutsceneRemotes"
local playRemote = Instance.new("RemoteEvent")
playRemote.Name = "PlayCutscene"
playRemote.Parent = remotes
local finishedRemote = Instance.new("RemoteEvent")
finishedRemote.Name = "CutsceneFinished"
finishedRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local CutsceneService = {}

-- Fires (player, cutsceneId, result) where result is "Completed", "Skipped" or "Failed".
local finished = Instance.new("BindableEvent")
CutsceneService.Finished = finished.Event

local pending: { [Player]: string } = {}

-- Seen flags are attributes, so they reset when the player leaves.
-- Save them with the rest of the player's data to make them stick.
function CutsceneService.HasSeen(player: Player, id: string): boolean
	return player:GetAttribute("SeenCutscene_" .. id) == true
end

function CutsceneService.IsPlaying(player: Player): boolean
	return pending[player] ~= nil
end

function CutsceneService.Play(player: Player, id: string): boolean
	if pending[player] then
		return false
	end
	pending[player] = id
	playRemote:FireClient(player, id, { CanSkip = CutsceneService.HasSeen(player, id) })

	task.delay(REPORT_TIMEOUT, function()
		if pending[player] == id then
			pending[player] = nil
		end
	end)
	return true
end

finishedRemote.OnServerEvent:Connect(function(player: Player, id: unknown, result: unknown)
	if typeof(id) ~= "string" or pending[player] ~= id then
		return
	end
	pending[player] = nil
	local outcome = if result == "Skipped" or result == "Failed" then result else "Completed"
	if outcome ~= "Failed" then
		player:SetAttribute("SeenCutscene_" .. id, true)
	end
	finished:Fire(player, id, outcome)
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
end)

return CutsceneService
