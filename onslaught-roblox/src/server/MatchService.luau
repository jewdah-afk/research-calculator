--[[
	Runs the Match for this server and connects it to Roblox: remotes, Heartbeat, players joining and leaving,
	rewards when a run ends, and in-match products.

	A server hosts at most one match. In a live game that is a reserved server created for a party (see
	PartyService); in Studio the lobby server hosts it directly so everything can be tested in one place.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules)
local GAME = require(ReplicatedStorage.Shared.Onslaught.Data)
local Match = require(script.Parent.Match)
local Profiles = require(script.Parent.Profiles)
local Monetization = require(script.Parent.Monetization)
local Leaderboards = require(script.Parent.Leaderboards)

local MatchService = {}

local current = nil -- { match, settings, players = { [pid] = Player }, rewarded = { [pid] = true } }
MatchService.onFinished = function(_players: { Player }) end -- PartyService: what to do after a run (Studio: back to lobby)

local function pidOf(player: Player): string
	return tostring(player.UserId)
end
local function fire(player: Player, kind: string, payload: any)
	Net.get("Event"):FireClient(player, kind, payload)
end

function MatchService.current()
	return current
end
function MatchService.matchOf(player: Player)
	if current and current.players[pidOf(player)] then
		return current.match
	end
	return nil
end

local function playerInfo(player: Player)
	local p = Profiles.get(player)
	return {
		name = player.DisplayName,
		loadout = { level = p and p.level or 1, research = p and p.research or {}, prestige = p and p.prestige or 0 },
		passes = Monetization.passes(player),
		skin = p and p.skin or "default",
	}
end

-- What every client needs to set up its board and UI for this run.
local function matchInfo()
	local m = current.match
	local roster = {}
	for _, pid in m.G.playerOrder do
		local pl = current.players[pid]
		local info = m.info.players[pid]
		table.insert(roster, { pid = pid, name = info and info.name or pid, skin = info and info.skin or "default", userId = pl and pl.UserId or 0 })
	end
	local s = current.settings
	return {
		mode = s.mode, map = s.map, challengeIndex = s.challengeIndex, plus = s.plus == true, seed = m.info.seed,
		host = m.hostPid, roster = roster,
		hostLoadout = if s.plus then m.loadouts[m.info.hostPid] else nil,
	}
end
local function broadcastInfo()
	if not current then
		return
	end
	local info = matchInfo()
	for _, pl in current.players do
		fire(pl, "matchInfo", info)
	end
end

-- ================================================================ rewards
local function reward(pid: string, quit: boolean)
	if not current or current.rewarded[pid] then
		return
	end
	current.rewarded[pid] = true
	local player = current.players[pid]
	local m = current.match
	local G = m.G
	if not player or not Profiles.get(player) then
		return
	end
	local me = G.players[pid]
	local turretKills = {}
	for _, t in G.turrets do
		if t.owner == pid then
			table.insert(turretKills, { kind = t.kind, kills = t.kills })
		end
	end
	local s = table.clone(current.settings)
	s.challenge = if s.challengeIndex then GAME.challenges[s.challengeIndex] else nil
	local run = {
		settings = s, wave = G.waveNum, kills = G.kills, myKills = me and me.kills or 0, myEarned = me and me.earned or 0,
		won = G.won, assisted = G.assisted == true, turretKills = turretKills, comboCounts = G.comboCounts,
		combos = G.stats.combos, lives = G.lives, startLives = G.startLives,
		partyBoost = os.time() < Monetization.partyBoostUntil, nowMs = os.time() * 1000,
	}
	local summary
	Profiles.update(player, function(p)
		Rules.dailyQuestsFor(p)
		summary = Rules.applyGameEnd(p, Monetization.passes(player), run)
	end)
	local profile = Profiles.get(player)
	Leaderboards.submit(player, s, run, Profiles.total(profile, "lifetimeKills"))
	task.spawn(Profiles.save, player, false)
	summary.quit = quit
	summary.wave, summary.kills, summary.myKills, summary.won = run.wave, run.kills, run.myKills, run.won
	summary.level, summary.xpInto, summary.xpNeed = profile.level, profile.xp, nil
	fire(player, "rewards", summary)
end

-- ================================================================ lifecycle
function MatchService.start(settings, players: { Player })
	if current then
		MatchService.stop()
	end
	local info = {
		mode = if settings.challengeIndex then GAME.challenges[settings.challengeIndex].difficulty else settings.mode,
		map = settings.map, challengeIndex = settings.challengeIndex, plus = settings.plus == true,
		seed = math.random(1, 2 ^ 30), hostPid = pidOf(players[1]), order = {}, players = {},
	}
	settings = table.clone(settings)
	settings.mode = info.mode
	local roster = {}
	for _, pl in players do
		local pid = pidOf(pl)
		table.insert(info.order, pid)
		info.players[pid] = playerInfo(pl)
		roster[pid] = pl
	end
	current = { settings = settings, players = roster, rewarded = {} }
	local io = {}
	function io.state(buf, header)
		for _, pl in current.players do
			Net.get("State"):FireClient(pl, buf, header)
		end
	end
	function io.event(pid, kind, payload)
		if pid then
			local pl = current.players[pid]
			if pl then
				fire(pl, kind, payload)
			end
		else
			for _, pl in current.players do
				fire(pl, kind, payload)
			end
		end
	end
	function io.ended(_m, _results)
		for pid in current.players do
			reward(pid, false)
		end
		io.event(nil, "matchEnded", { won = current.match.G.won, wave = current.match.G.waveNum, kills = current.match.G.kills })
	end
	function io.saveBlueprint(pid, mapKey, bp)
		local pl = current.players[pid]
		if pl then
			Profiles.update(pl, function(p)
				p.blueprints[mapKey] = bp
			end)
			fire(pl, "toast", { text = "Blueprint saved for this map (" .. #bp .. " turrets)" })
		end
	end
	function io.loadBlueprint(pid, mapKey)
		local pl = current.players[pid]
		local p = pl and Profiles.get(pl)
		return p and p.blueprints[mapKey]
	end
	current.match = Match.new(info, io)
	-- the host's saved preferences
	local hp = Profiles.get(players[1])
	if hp and hp.settings then
		current.match.G.waveSpacing = math.clamp(hp.settings.waveSpacing or 20, 5, 60) * 1000
		current.match.G.waveFollow = hp.settings.waveFollow == true
	end
	broadcastInfo()
	return current.match
end

function MatchService.stop()
	if not current then
		return
	end
	for pid in current.players do
		reward(pid, true)
	end
	current = nil
end

function MatchService.restart(byPlayer: Player)
	if not current or pidOf(byPlayer) ~= current.match.hostPid or current.match.state ~= "done" then
		return false
	end
	local list = {}
	local host = current.players[current.match.hostPid]
	table.insert(list, host)
	for pid, pl in current.players do
		if pid ~= current.match.hostPid then
			table.insert(list, pl)
		end
	end
	local settings = current.settings
	current = nil
	MatchService.start(settings, list)
	return true
end

function MatchService.addPlayer(player: Player)
	if not current then
		return
	end
	local pid = pidOf(player)
	if current.players[pid] then
		return
	end
	current.players[pid] = player
	current.match:join(pid, playerInfo(player))
	broadcastInfo()
end

function MatchService.removePlayer(player: Player, quit: boolean?)
	if not current then
		return
	end
	local pid = pidOf(player)
	if not current.players[pid] then
		return
	end
	reward(pid, quit ~= false)
	current.match:leave(pid)
	current.players[pid] = nil
	if next(current.players) == nil then
		current = nil -- last one out
	else
		broadcastInfo()
	end
end

-- ================================================================ wiring
function MatchService.init()
	Net.get("Action").OnServerEvent:Connect(function(player, op, ...)
		local m = MatchService.matchOf(player)
		if not m or type(op) ~= "string" then
			return
		end
		local pid = pidOf(player)
		if op == "product" or op == "useCredit" then
			local a = Net.check(Net.ACTIONS[op], { ... })
			if not a or not Monetization.IN_MATCH[a[1]] then
				return
			end
			local arg = if a[2] and a[3] then { x = math.clamp(a[2], 0, 720), y = math.clamp(a[3], 0, 480) } else nil
			if not m:canUseProduct(a[1]) then
				fire(player, "toast", { text = "Can't use that right now.", bad = true })
				return
			end
			if op == "useCredit" then
				local p = Profiles.get(player)
				if p and (p.credits[a[1]] or 0) > 0 and m:applyProduct(pid, a[1], arg) then
					Profiles.update(player, function(pr)
						pr.credits[a[1]] -= 1
					end)
				end
				return
			end
			local key = if a[1] == "revive" then Monetization.reviveProduct(m.G.revives or 0) else a[1]
			local ok, msg = Monetization.promptProduct(player, key, arg)
			if not ok then
				fire(player, "toast", { text = msg, bad = true })
			end
			return
		end
		local ok, msg = m:action(pid, op, ...)
		if not ok and msg and msg ~= "slow down" then
			fire(player, "actionFailed", { op = op, msg = msg })
		end
	end)
	Monetization.applyInMatch = function(player, id, arg)
		local m = MatchService.matchOf(player)
		return m ~= nil and m:applyProduct(pidOf(player), id, arg)
	end
	Monetization.onPassesChanged = function(player, passes)
		if current and current.players[pidOf(player)] then
			current.match.info.players[pidOf(player)].passes = passes
		end
	end
	Monetization.notify = function(player, how, key)
		local text = if how == "credit" then "Saved as a credit: use it in your next Onslaught+ run." else "Thanks! " .. key .. " applied."
		fire(player, "toast", { text = text })
	end
	RunService.Heartbeat:Connect(function(dt)
		if current then
			current.match:update(math.min(dt, 0.25))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		MatchService.removePlayer(player, true)
	end)
end

return MatchService
