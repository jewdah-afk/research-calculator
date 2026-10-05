--!nonstrict
-- Authoritative game server: saving, per-player spawn loops, orb validation, and every purchase.
-- The client only simulates the board physics and reports where each orb landed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.OrbEconomy)
local F = require(Shared.OrbFormulas)
local Remotes = require(Shared.Remotes)

local STORE_NAME = "OrbGame_v1"
local AUTOSAVE_SECONDS = 60
local MIN_FALL_SECONDS = 0.4 -- an orb can't be collected faster than this after spawning
local MAX_PENDING = 600 -- hard cap on tracked orbs per player (duplicates can exceed spawn cap)
local ACTIONS_PER_SECOND = 40
local STATE_PUSH_HZ = 5

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local R = Remotes.server()

type Session = {
	data: any,
	pending: { [number]: { orb: any, t: number } },
	pendingCount: number, -- rarity orbs only (spawn cap)
	nextId: number,
	spawnAcc: { number },
	secondAcc: number,
	stateAcc: number,
	dirty: boolean,
	actionBudget: number,
	rng: Random,
	loaded: boolean,
}
local sessions: { [Player]: Session } = {}

---------------------------------------------------------------- persistence

local function load(player: Player)
	local saved
	if store then
		local ok, res = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		if ok then
			saved = res
		else
			warn("[OrbGame] load failed for", player.Name, res)
		end
	end
	return if saved then Economy.deserialize(saved) else Economy.newData("orig")
end

local function save(player: Player)
	local s = sessions[player]
	if not (s and s.loaded and store) then
		return
	end
	local payload = Economy.serialize(s.data)
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), payload)
	end)
	if not ok then
		warn("[OrbGame] save failed for", player.Name, err)
	end
end

---------------------------------------------------------------- state sync

local function pushState(player: Player)
	local s = sessions[player]
	if s then
		R.State:FireClient(player, Economy.serialize(s.data))
		s.dirty = false
	end
end

local function notify(player: Player, kind: string, payload: any)
	R.Notify:FireClient(player, kind, payload)
end

---------------------------------------------------------------- orbs

local function track(s: Session, orb)
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

local function clearBoard(player: Player)
	local s = sessions[player]
	if s then
		s.pending = {}
		s.pendingCount = 0
		R.Board:FireClient(player, "clear")
	end
end

local function spawnFor(player: Player, s: Session, spawner: number)
	local before = s.data.highestRarity
	local orbs = Economy.rollSpawn(s.data, spawner, s.pendingCount, s.rng)
	if #orbs == 0 then
		return
	end
	local out = {}
	for _, orb in orbs do
		local id = track(s, orb)
		if id then
			table.insert(out, { id = id, kind = orb.kind, rarity = orb.rarity, variant = orb.variant, spawner = spawner })
		end
	end
	if #out > 0 then
		R.Spawn:FireClient(player, out)
	end
	if s.data.highestRarity > before then
		notify(player, "newRarity", s.data.highestRarity)
	end
	s.dirty = true
end

R.Collect.OnServerEvent:Connect(function(player: Player, batch)
	local s = sessions[player]
	if not (s and type(batch) == "table") then
		return
	end
	local now = os.clock()
	for i, entry in batch do
		if i > 200 then
			break
		end
		if type(entry) == "table" and type(entry[1]) == "number" and type(entry[2]) == "number" then
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

---------------------------------------------------------------- actions

local function num(x, lo, hi)
	return type(x) == "number" and x == x and x >= lo and x <= hi and math.floor(x) == x
end

-- name -> handler(player, session, ...) -> boolean
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
			-- duplicate every tracked orb; the client clones them at the source position
			local pairs_ = {}
			local snapshot = {}
			for oid, entry in s.pending do
				table.insert(snapshot, { oid, entry.orb })
			end
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
}

R.Action.OnServerInvoke = function(player: Player, name, ...)
	local s = sessions[player]
	local handler = type(name) == "string" and ACTIONS[name]
	if not (s and s.loaded and handler) then
		return false
	end
	if s.actionBudget <= 0 then
		return false
	end
	s.actionBudget -= 1
	local ok, result = pcall(handler, player, s, ...)
	if not ok then
		warn("[OrbGame] action", name, "errored:", result)
		return false
	end
	if result then
		Economy.refresh(s.data)
		pushState(player)
	end
	return result == true
end

---------------------------------------------------------------- lifecycle

local function onJoin(player: Player)
	local s: Session = {
		data = nil,
		pending = {},
		pendingCount = 0,
		nextId = 0,
		spawnAcc = table.create(7, 0),
		secondAcc = 0,
		stateAcc = 0,
		dirty = true,
		actionBudget = ACTIONS_PER_SECOND,
		rng = Random.new(),
		loaded = false,
	}
	sessions[player] = s
	s.data = load(player)
	Economy.refresh(s.data)
	s.loaded = true
	pushState(player)
	R.Board:FireClient(player, "rebuild")
end

Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do
	task.spawn(onJoin, p)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessions[player] = nil
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	for player in sessions do
		save(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player in sessions do
			task.spawn(save, player)
		end
	end
end)

---------------------------------------------------------------- main loop

RunService.Heartbeat:Connect(function(dt)
	for player, s in sessions do
		if not s.loaded then
			continue
		end
		local d = s.data
		-- spawners
		for sp = 1, d.spawnersUnlocked do
			s.spawnAcc[sp] += dt * 1000
			local interval = d.spawnIntervals[sp]
			local guard = 0
			while s.spawnAcc[sp] >= interval and guard < 20 do
				s.spawnAcc[sp] -= interval
				guard += 1
				spawnFor(player, s, sp)
			end
		end
		-- automation
		Economy.tickAutomation(d, dt)
		-- once per second
		s.secondAcc += dt
		if s.secondAcc >= 1 then
			s.secondAcc -= 1
			s.actionBudget = ACTIONS_PER_SECOND
			Economy.tickSecond(d, {
				onObstacleChange = function()
					R.Board:FireClient(player, "rebuild")
				end,
			})
			-- forget orbs that never came back (lag / tab-out) so the cap frees up
			local now = os.clock()
			for id, p in s.pending do
				if now - p.t > 120 then
					s.pending[id] = nil
					if p.orb.kind == "orb" then
						s.pendingCount -= 1
					end
				end
			end
			s.dirty = true
		end
		-- state push
		s.stateAcc += dt
		if s.dirty and s.stateAcc >= 1 / STATE_PUSH_HZ then
			s.stateAcc = 0
			pushState(player)
		end
	end
end)
