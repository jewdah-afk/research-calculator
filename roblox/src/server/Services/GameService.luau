--!nonstrict
-- Core game loop per player: spawners, orb validation, actions, tutorial, state sync.
-- The client only simulates the board physics and reports where each orb landed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.OrbEconomy)
local F = require(Shared.OrbFormulas)
local Balance = require(Shared.Balance)
local Events = require(Shared.Events)
local Tutorial = require(Shared.Tutorial)
local Unlocks = require(Shared.Unlocks)
local Progression = require(Shared.Progression)

local GameService = {}

local MIN_FALL_SECONDS = 0.4 -- an orb can't be collected faster than this after spawning
local MAX_PENDING = 600 -- hard cap on tracked orbs per player (duplicates can exceed spawn cap)
local ACTIONS_PER_SECOND = 40
local STATE_PUSH_HZ = 5
local ORB_TIMEOUT = 120 -- forget orbs that never came back (lag / tab-out)
local GHOST_FLUSH = 0.25 -- how often other players' orbs are relayed to spectators
local GHOST_PER_FLUSH = 6 -- per player per flush (rares always go through)
local RARE_MIN_ONE_IN_LOG = 4 -- announce + effects only for 1/10,000 and rarer...
local RARE_TOP = 2 -- ...that are within 2 of the player's best rarity ever

local R -- remotes
local DataService, LeaderboardService
local sessions = {} -- [Player] = session

---------------------------------------------------------------- helpers

local function pushState(player)
	local s = sessions[player]
	if s and s.data then
		R.State:FireClient(player, Economy.serialize(s.data))
		s.dirty = false
	end
end

local function notify(player, kind, payload)
	R.Notify:FireClient(player, kind, payload)
end

local function track(s, orb)
	if s.pendingCount >= MAX_PENDING then
		return nil
	end
	s.nextId += 1
	s.pending[s.nextId] = { orb = orb, t = os.clock() }
	if orb.kind == "orb" then
		s.pendingCount += 1
	end
	return s.nextId
end

local function clearBoard(player)
	local s = sessions[player]
	if s then
		s.pending = {}
		s.pendingCount = 0
		R.Board:FireClient(player, "clear")
	end
end

-- rare = worth a server-wide moment: hard odds AND near the top of what this player has found
local function isRare(data, orb)
	if orb.kind ~= "orb" then
		return false
	end
	local r = Progression.Rarities[orb.rarity]
	return r.oneInLog >= RARE_MIN_ONE_IN_LOG and orb.rarity >= data.highestRarity - RARE_TOP
end

local function queueGhosts(s, out)
	local q = s.ghostQueue
	for _, o in out do
		if o.rare then
			table.insert(q.rare, o)
		elseif #q.common < GHOST_PER_FLUSH * 4 then
			table.insert(q.common, o)
		end
	end
end

-- relay a sample of this player's orbs to everyone else (visual only, pegs-only physics there)
local function flushGhosts(player, s)
	local q = s.ghostQueue
	if #q.rare == 0 and #q.common == 0 then
		return
	end
	table.sort(q.common, function(a, b)
		return (a.rarity or 0) > (b.rarity or 0)
	end)
	local list = {}
	for _, o in q.rare do
		table.insert(list, { kind = o.kind, rarity = o.rarity, variant = o.variant, rare = true })
	end
	for i = 1, math.min(#q.common, GHOST_PER_FLUSH) do
		local o = q.common[i]
		table.insert(list, { kind = o.kind, rarity = o.rarity, variant = o.variant })
	end
	q.rare, q.common = {}, {}
	for other in sessions do
		if other ~= player then
			R.Ghost:FireClient(other, player.UserId, player.DisplayName, list)
		end
	end
end

local function spawnFor(player, s, spawner)
	local before = s.data.highestRarity
	local orbs = Economy.rollSpawn(s.data, spawner, s.pendingCount, s.rng)
	if #orbs == 0 then
		return
	end
	local out = {}
	for _, orb in orbs do
		local id = track(s, orb)
		if id then
			local rare = isRare(s.data, orb)
			table.insert(out, { id = id, kind = orb.kind, rarity = orb.rarity, variant = orb.variant, spawner = spawner, rare = rare or nil })
			if rare and os.clock() - (s.lastAnnounce or 0) > 15 then
				s.lastAnnounce = os.clock()
				GameService.broadcast("rareDrop", { name = player.DisplayName, rarity = orb.rarity, variant = orb.variant })
			end
		end
	end
	if #out > 0 then
		R.Spawn:FireClient(player, out)
		queueGhosts(s, out)
	end
	if s.data.highestRarity > before then
		notify(player, "newRarity", s.data.highestRarity)
	end
	s.dirty = true
end

local function num(x, lo, hi)
	return type(x) == "number" and x == x and x >= lo and x <= hi and math.floor(x) == x
end

---------------------------------------------------------------- actions (whitelist)

local ACTIONS = {
	buyMain = function(_, s, kind, count)
		return num(kind, 1, 3) and Economy.buyMain(s.data, kind, num(count, 1, 1e9) and count or 1)
	end,
	buyInterval = function(_, s, sp)
		return num(sp, 1, 7) and Economy.buyInterval(s.data, sp)
	end,
	buySpawnerLuck = function(_, s, sp)
		return num(sp, 1, 7) and Economy.buySpawnerLuck(s.data, sp)
	end,
	buySpawner = function(_, s, sp)
		return num(sp, 2, 7) and Economy.buySpawner(s.data, sp)
	end,
	maxBuyMain = function(_, s)
		if F.skill(s.data, "MAX-1") < 1 then
			return false
		end
		Economy.maxBuyMain(s.data)
		return true
	end,
	maxBuySpawner = function(_, s, sp)
		if not num(sp, 1, 7) or F.skill(s.data, "MAX-2") < 1 then
			return false
		end
		Economy.maxBuySpawner(s.data, sp)
		return true
	end,
	maxBuyAll = function(_, s)
		if F.skill(s.data, "MAX-4") < 1 then
			return false
		end
		Economy.maxBuyAll(s.data)
		return true
	end,
	buyDiamondLuck = function(_, s)
		return Economy.buyDiamondLuck(s.data)
	end,
	unlockMechanic = function(_, s)
		return Economy.unlockMechanic(s.data)
	end,
	rebirth = function(p, s)
		local ok = Economy.rebirth(s.data)
		if ok then
			clearBoard(p)
		end
		return ok
	end,
	tier = function(p, s)
		local ok = Economy.tier(s.data)
		if ok then
			clearBoard(p)
			R.Board:FireClient(p, "rebuild")
			notify(p, "tier", s.data.tiers)
		end
		return ok
	end,
	buyBoost = function(p, s, id)
		if not num(id, 1, 6) then
			return false
		end
		local ok = Economy.buyBoost(s.data, id)
		if ok and id == 5 then
			local snapshot = {}
			for oid, entry in s.pending do
				table.insert(snapshot, { oid, entry.orb })
			end
			local pairs_ = {}
			for _, it in snapshot do
				local newId = track(s, table.clone(it[2]))
				if newId then
					table.insert(pairs_, { newId, it[1] })
				end
			end
			R.Board:FireClient(p, "duplicate", pairs_)
		elseif ok and id == 6 then
			R.Board:FireClient(p, "rebuild")
		end
		return ok
	end,
	setAutoPotion = function(_, s, which, on)
		return (which == "money" or which == "luck") and type(on) == "boolean" and Economy.setAutoPotion(s.data, which, on)
	end,
	rollWeather = function(p, s)
		local pick = Economy.rollWeather(s.data, s.rng)
		if pick then
			notify(p, "weather", pick)
		end
		return pick ~= nil
	end,
	unlockWeather = function(_, s)
		return Economy.unlockWeather(s.data)
	end,
	buyWeatherMoney = function(_, s)
		return Economy.buyWeatherMoney(s.data)
	end,
	buyStormLevel = function(_, s)
		return Economy.buyStormLevel(s.data)
	end,
	buyAutomation = function(_, s, idx)
		return num(idx, 1, 4) and Economy.buyAutomation(s.data, idx)
	end,
	toggleAutomation = function(_, s, idx)
		return num(idx, 1, 2) and Economy.toggleAutomation(s.data, idx)
	end,
	gainTP = function(_, s, source)
		return type(source) == "string" and Economy.gainTP(s.data, source)
	end,
	gainQP = function(_, s)
		return Economy.gainQP(s.data)
	end,
	buySkill = function(_, s, id)
		return type(id) == "string" and #id < 12 and Economy.buySkill(s.data, id)
	end,
	respec = function(p, s)
		local ok = Economy.respec(s.data)
		if ok then
			clearBoard(p)
			R.Board:FireClient(p, "rebuild")
		end
		return ok
	end,
	setDifficulty = function(_, s, diff)
		return type(diff) == "string" and Economy.setDifficulty(s.data, diff)
	end,
	prestige = function(p, s, layerId)
		if type(layerId) ~= "string" then
			return false
		end
		local ok = Economy.prestige(s.data, layerId)
		if ok then
			clearBoard(p)
			R.Board:FireClient(p, "rebuild")
			notify(p, "prestige", layerId)
		end
		return ok
	end,
	buyPrestigeUpgrade = function(_, s, id)
		return type(id) == "string" and #id < 16 and Economy.buyPrestigeUpgrade(s.data, id)
	end,
	skipTutorial = function(_, s)
		Tutorial.finish(s.data)
		return true
	end,
}
GameService.ACTIONS = ACTIONS -- exposed so new features can register actions

---------------------------------------------------------------- lifecycle

local function onJoin(player)
	local s = {
		data = nil,
		canSave = false,
		pending = {},
		pendingCount = 0,
		nextId = 0,
		spawnAcc = table.create(7, 0),
		secondAcc = 0,
		stateAcc = 0,
		lbAcc = 0,
		dirty = true,
		actionBudget = ACTIONS_PER_SECOND,
		rng = Random.new(),
		ghostQueue = { rare = {}, common = {} },
		ghostAcc = 0,
	}
	sessions[player] = s
	LeaderboardService.attach(player)
	local data, canSave = DataService.load(player)
	if not player.Parent or not data then
		sessions[player] = nil
		return
	end
	s.data, s.canSave = data, canSave
	Economy.refresh(data)
	Unlocks.update(data)
	pushState(player)
	R.Board:FireClient(player, "rebuild")
	R.Events:FireClient(player, Balance.ctx.events)
	if not canSave then
		notify(player, "announce", "Your save couldn't be loaded right now. Progress this session won't be saved — please rejoin in a minute.")
	end
end

local function onLeave(player)
	local s = sessions[player]
	sessions[player] = nil
	if s and s.data and s.canSave then
		DataService.save(player, s.data, true)
		LeaderboardService.submit(player, s.data)
	end
end

function GameService.saveAll(release: boolean)
	for player, s in sessions do
		if s.data and s.canSave then
			DataService.save(player, s.data, release)
		end
	end
end

function GameService.broadcast(kind, payload)
	for player in sessions do
		notify(player, kind, payload)
	end
end

function GameService.init(remotes, services)
	R = remotes
	DataService = services.DataService
	LeaderboardService = services.LeaderboardService

	R.Collect.OnServerEvent:Connect(function(player, batch)
		local s = sessions[player]
		if not (s and s.data and type(batch) == "table") then
			return
		end
		local now = os.clock()
		for i, entry in batch do
			if i > 200 then
				break
			end
			if type(entry) == "table" and type(entry[1]) == "number" and type(entry[2]) == "number" and entry[2] == entry[2] then
				local p = s.pending[entry[1]]
				if p and now - p.t >= MIN_FALL_SECONDS then
					s.pending[entry[1]] = nil
					if p.orb.kind == "orb" then
						s.pendingCount -= 1
					end
					Economy.collect(s.data, p.orb, math.clamp(entry[2], 0, 400), s.rng)
					s.dirty = true
				end
			end
		end
	end)

	R.Action.OnServerInvoke = function(player, name, ...)
		local s = sessions[player]
		local handler = type(name) == "string" and ACTIONS[name]
		if not (s and s.data and handler) or s.actionBudget <= 0 then
			return false
		end
		s.actionBudget -= 1
		local ok, result = pcall(handler, player, s, ...)
		if not ok then
			warn("[GameService] action", name, "errored:", result)
			return false
		end
		if result then
			Economy.refresh(s.data)
			Tutorial.advance(s.data)
			for _, id in Unlocks.update(s.data) do
				notify(player, "unlock", id)
			end
			pushState(player)
		end
		return result == true
	end

	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end

	-- autosave + daily backups
	task.spawn(function()
		while true do
			task.wait(60)
			for player, s in sessions do
				if s.data and s.canSave then
					task.spawn(DataService.save, player, s.data, false)
					DataService.backup(player, s.data)
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		Balance.ctx.now = os.time()
		local speed = Events.spawnSpeed(Balance.ctx)
		for player, s in sessions do
			local d = s.data
			if not d then
				continue
			end
			for sp = 1, d.spawnersUnlocked do
				s.spawnAcc[sp] += dt * 1000 * speed
				local interval = d.spawnIntervals[sp]
				local guard = 0
				while s.spawnAcc[sp] >= interval and guard < 20 do
					s.spawnAcc[sp] -= interval
					guard += 1
					spawnFor(player, s, sp)
				end
			end
			Economy.tickAutomation(d, dt)
			s.secondAcc += dt
			if s.secondAcc >= 1 then
				s.secondAcc -= 1
				s.actionBudget = ACTIONS_PER_SECOND
				Economy.tickSecond(d, {
					onObstacleChange = function()
						R.Board:FireClient(player, "rebuild")
					end,
				})
				Tutorial.advance(d)
				for _, id in Unlocks.update(d) do
					notify(player, "unlock", id)
				end
				local now = os.clock()
				for id, p in s.pending do
					if now - p.t > ORB_TIMEOUT then
						s.pending[id] = nil
						if p.orb.kind == "orb" then
							s.pendingCount -= 1
						end
					end
				end
				LeaderboardService.updateStats(player, d)
				s.lbAcc += 1
				if s.lbAcc >= 300 and s.canSave then
					s.lbAcc = 0
					LeaderboardService.submit(player, d)
				end
				s.dirty = true
			end
			s.ghostAcc += dt
			if s.ghostAcc >= GHOST_FLUSH then
				s.ghostAcc = 0
				flushGhosts(player, s)
			end
			s.stateAcc += dt
			if s.dirty and s.stateAcc >= 1 / STATE_PUSH_HZ then
				s.stateAcc = 0
				pushState(player)
			end
		end
	end)
end

return GameService
