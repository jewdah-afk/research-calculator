--[[
	Onslaught server entry. Public servers are lobbies; reserved servers run one party's match.
	Order matters: remotes first, then services, then players.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net).init()
local Profiles = require(script.Profiles)
local Monetization = require(script.Monetization)
local MatchService = require(script.MatchService)
local PartyService = require(script.PartyService)

Profiles.start()
Monetization.start()
MatchService.init()
PartyService.init()

local isMatch = PartyService.isMatchServer()

-- Profile changes reach the client at most twice a second
local pending: { [Player]: boolean } = {}
Profiles.onChanged(function(player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.5, function()
		pending[player] = nil
		if player.Parent then
			Net.get("Event"):FireClient(player, "profile", PartyService.profileView(player))
		end
	end)
end)

local function vipTag(player: Player, passes)
	player:SetAttribute("VIP", passes.vip == true)
end

local function onPlayer(player: Player)
	local profile = Profiles.load(player)
	if not profile then
		return
	end
	local passes = Monetization.loadPasses(player)
	vipTag(player, passes)
	Net.get("Event"):FireClient(player, "hello", { role = if isMatch then "match" else "lobby", profile = PartyService.profileView(player) })
	if not isMatch then
		PartyService.broadcastParties()
	end
end
Monetization.onPassesChanged = (function(prev)
	return function(player, passes)
		prev(player, passes)
		vipTag(player, passes)
		if Profiles.get(player) then
			Net.get("Event"):FireClient(player, "profile", PartyService.profileView(player))
		end
	end
end)(Monetization.onPassesChanged)

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayer, p)
end
if isMatch then
	task.spawn(PartyService.runMatchServer)
end
-- Studio and lobby: when a run ends in this server, players stay on the end screen; "Lobby" sends them back.
