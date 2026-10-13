--[[
	Lobby and parties (1-4 players), plus every lobby request (profile, research, quests, store, leaderboards).

	Public servers are lobbies. A party leader picks the run (mode or challenge, map, Classic or Onslaught+)
	and starts it: the server reserves a private server, writes the run settings to a MemoryStore map keyed
	by that server's PrivateServerId (so clients can't forge them), and teleports the party there. The
	reserved server reads its settings, waits for the party, and runs the match (MatchService).
	In Studio there are no reserved servers, so Start runs the match right here.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules)
local GAME = require(ReplicatedStorage.Shared.Onslaught.Data)
local X = require(ReplicatedStorage.Shared.Onslaught.Expansion)
local EN = require(ReplicatedStorage.Shared.Onslaught.EternityNum)
local Engine = require(ReplicatedStorage.Shared.Onslaught.Engine)
local Profiles = require(script.Parent.Profiles)
local Monetization = require(script.Parent.Monetization)
local Leaderboards = require(script.Parent.Leaderboards)
local MatchService = require(script.Parent.MatchService)

local PartyService = {}

local settingsMap = MemoryStoreService:GetSortedMap("OnslaughtRuns_v1")
local parties: { [number]: any } = {} -- [leaderUserId] = { leader, members = { Player }, settings, open }
local partyOf: { [Player]: number } = {}

local function fire(player: Player, kind: string, payload: any)
	Net.get("Event"):FireClient(player, kind, payload)
end

-- ================================================================ party list
local function partyView(party)
	local members = {}
	for _, m in party.members do
		table.insert(members, { userId = m.UserId, name = m.DisplayName })
	end
	return { leader = party.leader.UserId, leaderName = party.leader.DisplayName, members = members, settings = party.settings, open = party.open }
end
local function broadcastParties()
	local list = {}
	for _, party in parties do
		table.insert(list, partyView(party))
	end
	for _, pl in Players:GetPlayers() do
		fire(pl, "parties", { list = list, mine = partyOf[pl] })
	end
end
local function leaveParty(player: Player)
	local id = partyOf[player]
	if not id then
		return
	end
	partyOf[player] = nil
	local party = parties[id]
	if not party then
		return
	end
	if party.leader == player then
		parties[id] = nil
		for _, m in party.members do
			if m ~= player then
				partyOf[m] = nil
				fire(m, "toast", { text = "The party leader left." })
			end
		end
	else
		local i = table.find(party.members, player)
		if i then
			table.remove(party.members, i)
		end
	end
	broadcastParties()
end

-- ================================================================ profile view (what the lobby UI shows)
local function profileView(player: Player)
	local p = Profiles.get(player)
	if not p then
		return nil
	end
	Rules.dailyQuestsFor(p)
	local quests = {}
	for _, it in p.quests.list do
		for _, def in X.XD.quests do
			if def.id == it.id then
				table.insert(quests, { id = it.id, text = def.text, progress = it.progress, goal = def.goal, done = it.done, intel = def.intel, xp = def.xp })
			end
		end
	end
	local research = {}
	for _, r in X.XD.research do
		local lvl = p.research[r.id] or 0
		table.insert(research, { id = r.id, label = r.label, desc = r.desc, level = lvl, max = r.max, cost = X.researchCost(r.id, lvl) })
	end
	return {
		level = p.level, xp = p.xp, xpNeed = X.xpToNext(p.level), intel = p.intel, prestige = p.prestige,
		canPrestige = X.canPrestige(p), lifetimeKills = EN.short(Profiles.total(p, "lifetimeKills"), 2),
		lifetimeXP = EN.short(Profiles.total(p, "lifetimeXP"), 2), lifetimeBounty = EN.short(Profiles.total(p, "lifetimeBounty"), 2),
		unlocks = p.unlocks, best = p.best, chal = p.chal, quests = quests, research = research, rerolls = p.rerolls,
		credits = p.credits, skin = p.skin, games = p.games, wins = p.wins, settings = p.settings,
		xpBoostLeft = math.max(0, math.floor(((p.xpBoostUntil or 0) - os.time() * 1000) / 1000)),
		passes = Monetization.passes(player), catalog = Monetization.catalog(player),
		partyBoostLeft = math.max(0, Monetization.partyBoostUntil - os.time()),
	}
end
PartyService.profileView = profileView

-- ================================================================ start a run
local function startRun(party)
	local leader = party.leader
	local p = Profiles.get(leader)
	local ok, why = Rules.validSettings(GAME, p, Monetization.passes(leader), party.settings)
	if not ok then
		return false, why
	end
	local s = party.settings
	local settings = { mode = s.mode, map = s.map, challengeIndex = s.challengeIndex, plus = s.plus == true }
	local members = table.clone(party.members)
	if RunService:IsStudio() then
		for _, m in members do
			partyOf[m] = nil
		end
		parties[leader.UserId] = nil
		broadcastParties()
		MatchService.start(settings, members)
		return true
	end
	local okR, code, serverId = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
	if not okR then
		return false, "Couldn't open a match server. Try again."
	end
	local ids = {}
	for _, m in members do
		table.insert(ids, m.UserId)
	end
	settings.members = ids
	settings.leader = leader.UserId
	local okW = pcall(settingsMap.SetAsync, settingsMap, serverId, settings, 600)
	if not okW then
		return false, "Couldn't save the run settings. Try again."
	end
	local opts = Instance.new("TeleportOptions")
	opts.ReservedServerAccessCode = code
	local okT, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, members, opts)
	if not okT then
		warn("[Party] teleport failed", err)
		return false, "Teleport failed. Try again."
	end
	return true
end

-- ================================================================ match servers
function PartyService.isMatchServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end
function PartyService.runMatchServer()
	local settings
	for _ = 1, 10 do
		local ok, v = pcall(settingsMap.GetAsync, settingsMap, game.PrivateServerId)
		if ok and v then
			settings = v
			break
		end
		task.wait(1)
	end
	if not settings then
		for _, pl in Players:GetPlayers() do
			pl:Kick("This match server has no settings. Please rejoin the game.")
		end
		return
	end
	-- wait for the party (loaded profiles), up to PARTY_ARRIVE_TIMEOUT
	local t0 = os.clock()
	local function arrived()
		local list = {}
		for _, id in settings.members do
			local pl = Players:GetPlayerByUserId(id)
			if pl and Profiles.get(pl) then
				table.insert(list, pl)
			end
		end
		return list
	end
	while #arrived() < #settings.members and os.clock() - t0 < Config.PARTY_ARRIVE_TIMEOUT do
		task.wait(0.5)
	end
	local list = arrived()
	if #list == 0 then
		return
	end
	-- the leader hosts if they made it; otherwise the first to arrive
	table.sort(list, function(a, b)
		return (a.UserId == settings.leader and 0 or 1) < (b.UserId == settings.leader and 0 or 1)
	end)
	MatchService.start(settings, list)
	-- late arrivals from the same party join the running match
	Players.PlayerAdded:Connect(function(pl)
		if table.find(settings.members, pl.UserId) then
			while pl.Parent and not Profiles.get(pl) do
				task.wait(0.5)
			end
			if pl.Parent then
				MatchService.addPlayer(pl)
			end
		end
	end)
end

-- ================================================================ requests
local handlers = {}
function handlers.profile(player)
	return profileView(player)
end
function handlers.partyCreate(player, settings)
	leaveParty(player)
	parties[player.UserId] = { leader = player, members = { player }, settings = type(settings) == "table" and settings or { mode = "medium", map = "map1" }, open = true }
	partyOf[player] = player.UserId
	broadcastParties()
	return { ok = true }
end
function handlers.partyJoin(player, leaderId)
	local party = type(leaderId) == "number" and parties[leaderId]
	if not party or not party.open then
		return { ok = false, msg = "That party is closed." }
	end
	if #party.members >= Config.MAX_PARTY then
		return { ok = false, msg = "That party is full." }
	end
	leaveParty(player)
	table.insert(party.members, player)
	partyOf[player] = leaderId
	broadcastParties()
	return { ok = true }
end
function handlers.partyLeave(player)
	leaveParty(player)
	return { ok = true }
end
function handlers.partyKick(player, userId)
	local party = parties[player.UserId]
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not party or not target or target == player then
		return { ok = false }
	end
	leaveParty(target)
	fire(target, "toast", { text = "You were removed from the party." })
	return { ok = true }
end
function handlers.partySettings(player, s)
	local party = parties[player.UserId]
	if not party or type(s) ~= "table" then
		return { ok = false }
	end
	party.settings = {
		mode = type(s.mode) == "string" and s.mode or "medium", map = type(s.map) == "string" and s.map or "map1",
		challengeIndex = type(s.challengeIndex) == "number" and s.challengeIndex or nil, plus = s.plus == true,
	}
	party.open = s.open ~= false
	broadcastParties()
	return { ok = true }
end
function handlers.partyStart(player)
	local party = parties[player.UserId]
	if not party then
		return { ok = false, msg = "Only the party leader can start." }
	end
	local ok, msg = startRun(party)
	return { ok = ok, msg = msg }
end
-- Solo: a party of one, started at once.
function handlers.solo(player, s)
	handlers.partyCreate(player, s)
	handlers.partySettings(player, s)
	return handlers.partyStart(player)
end
function handlers.research(player, id)
	local done
	Profiles.update(player, function(p)
		done = type(id) == "string" and X.buyResearch(p, id)
	end)
	return { ok = done == true, profile = profileView(player) }
end
function handlers.prestige(player)
	local done
	Profiles.update(player, function(p)
		done = X.prestige(p)
	end)
	return { ok = done == true, profile = profileView(player) }
end
function handlers.reroll(player, index)
	local ok, msg
	Profiles.update(player, function(p)
		ok, msg = Rules.rerollQuest(p, Monetization.passes(player), type(index) == "number" and index or 0)
	end)
	return { ok = ok, msg = msg, profile = profileView(player) }
end
function handlers.buyPass(player, key)
	local ok, msg = Monetization.promptPass(player, tostring(key))
	return { ok = ok, msg = msg }
end
function handlers.buyProduct(player, key)
	if type(key) ~= "string" or Monetization.IN_MATCH[key] then
		return { ok = false, msg = "Buy that during an Onslaught+ run." }
	end
	local ok, msg = Monetization.promptProduct(player, key)
	return { ok = ok, msg = msg }
end
function handlers.leaderboard(_player, board)
	if board ~= "classic" and board ~= "plus" and board ~= "kills" then
		return {}
	end
	return Leaderboards.top(board)
end
local SKINS = { default = true, gold = "vip", retro = "skins_retro", neon = "skins_neon" }
function handlers.skin(player, skin)
	local need = SKINS[skin]
	if not need or (need ~= true and not Monetization.passes(player)[need]) then
		return { ok = false, msg = "You don't own that skin." }
	end
	Profiles.update(player, function(p)
		p.skin = skin
	end)
	return { ok = true }
end
function handlers.settings(player, s)
	if type(s) ~= "table" then
		return { ok = false }
	end
	Profiles.update(player, function(p)
		p.settings.waveSpacing = math.clamp(tonumber(s.waveSpacing) or 20, 5, 60)
		p.settings.waveFollow = s.waveFollow == true
		p.settings.showRanges = s.showRanges == true
	end)
	return { ok = true }
end
-- In-match buttons that need the server: back to lobby, play again (host)
function handlers.quitMatch(player)
	MatchService.removePlayer(player, true)
	if PartyService.isMatchServer() then
		pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player })
	else
		fire(player, "toLobby", {})
	end
	return { ok = true }
end
-- Combonly: which combos it could become right now (needs the full engine state, so the server answers)
function handlers.combonlyOptions(player, id)
	local m = MatchService.matchOf(player)
	if not m or type(id) ~= "number" then
		return {}
	end
	local out = {}
	for _, o in Engine.combonlyOptions(m.G, id) do
		table.insert(out, { colour = o.colour, combo = o.combo, needs = o.needs })
	end
	return out
end
function handlers.playAgain(player)
	return { ok = MatchService.restart(player) }
end

function PartyService.init()
	Net.get("Request").OnServerInvoke = function(player, op, ...)
		local h = type(op) == "string" and handlers[op]
		if not h or not Profiles.get(player) then
			return { ok = false, msg = "Not ready yet." }
		end
		local ok, res = pcall(h, player, ...)
		if not ok then
			warn("[Request]", op, res)
			return { ok = false, msg = "Something went wrong." }
		end
		return res
	end
	Players.PlayerRemoving:Connect(leaveParty)
end
PartyService.broadcastParties = broadcastParties

return PartyService
