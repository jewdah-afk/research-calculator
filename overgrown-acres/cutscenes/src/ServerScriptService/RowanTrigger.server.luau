-- Starts "Rowan at the Fire" when a player who has finished the Abandoned
-- Orchard talks to Rowan at the campsite.

local Workspace = game:GetService("Workspace")

local CutsceneService = require(script.Parent.CutsceneService)

local CUTSCENE_ID = "RowanAtTheFire"

local rowan = Workspace:WaitForChild("Campsite"):WaitForChild("NPCs"):WaitForChild("Rowan")
local anchor = rowan:WaitForChild("HumanoidRootPart")

-- STORY HOOK: swap this for the game's own progress check.
local function isReady(player: Player): boolean
	return player:GetAttribute("OrchardComplete") == true and not CutsceneService.HasSeen(player, CUTSCENE_ID)
end

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "RowanTalkPrompt"
prompt.ActionText = "Show the note"
prompt.ObjectText = "Rowan"
prompt.HoldDuration = 0.3
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Parent = anchor

prompt.Triggered:Connect(function(player)
	if isReady(player) and not CutsceneService.IsPlaying(player) then
		CutsceneService.Play(player, CUTSCENE_ID)
	end
end)

CutsceneService.Finished:Connect(function(player, id, result)
	if id ~= CUTSCENE_ID or result == "Failed" then
		return
	end
	-- STORY HOOK: advance the story and hand over Theo's seed here, e.g.
	--   Inventory.Give(player, "TheosSeed", 1)
	player:SetAttribute("StoryStage", "Thornveil")
end)
