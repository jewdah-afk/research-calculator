--!optimize 2
--[[
	One running game for 1-4 players: owns the engine state G, steps it in fixed 1 ms steps, applies validated
	player actions, and hands snapshots to its `io`. It touches no Roblox service directly, so Lune tests can
	drive it (test/unit/match_test.luau). MatchService wires it to Players, remotes and MarketplaceService.

	io = {
	  state(buf, header)                 snapshot to every player in the match
	  event(pid | nil, kind, payload)    nil pid = everyone in the match
	  ended(match, results)              the run is final (after the revive window)
	  saveBlueprint(pid, mapKey, bp)     Commander Tools
	  loadBlueprint(pid, mapKey) -> bp?
	}
	info = { mode, map, challengeIndex?, plus, seed, hostPid, players = { [pid] = { name, loadout, passes } }, order = { pid... } }
]]

local RS = if script then game:GetService("ReplicatedStorage") else nil
local E = if RS then require(RS.Shared.Onslaught.Engine) else require("../shared/Onslaught/Engine")
local GAME = if RS then require(RS.Shared.Onslaught.Data) else require("../shared/Onslaught/Data")
local X = if RS then require(RS.Shared.Onslaught.Expansion) else require("../shared/Onslaught/Expansion")
local Config = if RS then require(RS.Shared.Config) else require("../shared/Config")
local Net = if RS then require(RS.Shared.Net) else require("../shared/Net")
local Snapshot = if RS then require(RS.Shared.Snapshot) else require("../shared/Snapshot")

local Match = {}
Match.__index = Match

local STATS = { damage = true, range = true, rate = true }
local SPREADS = { [0] = true, [15] = true, [30] = true, [50] = true }
local REVIVE_WINDOW = 20 -- seconds a lost Onslaught+ run waits for a Second Chance before it is final

local function loadoutOf(p)
	return { level = p.loadout and p.loadout.level or 1, research = p.loadout and p.loadout.research or {}, passes = p.passes or {} }
end

function Match.new(info, io)
	local self = setmetatable({}, Match)
	self.info, self.io = info, io
	local opts = {
		map = info.map, mode = info.mode, seed = info.seed or 1, players = table.clone(info.order),
		challenge = if info.challengeIndex then GAME.challenges[info.challengeIndex] else nil,
	}
	if info.plus then
		self.loadouts = {}
		for _, pid in info.order do
			self.loadouts[pid] = loadoutOf(info.players[pid])
		end
		local D = X.data(GAME, self.loadouts[info.hostPid])
		self.G = E.newGame(D, X.gameOpts(opts, self.loadouts))
	else
		self.G = E.newGame(GAME, opts) -- Classic: the 1:1 game; no pass or product changes the simulation
	end
	self.G.startLives = self.G.lives
	self.G.comboCounts = {}
	self.hostPid = info.hostPid
	self.speed, self.paused = 1, false
	self.acc, self.snapAcc = 0, 0
	self.fx = {}
	self.sig = nil
	self.queues = {} -- [turretId] = { stat, ... }   Commander Tools
	self.pending = {} -- [pid] = { blueprint entries }
	self.bucket = {} -- [pid] = { tokens, t }
	self.clock = 0
	self.state = "playing" -- playing | reviveWindow | done
	return self
end

function Match:passes(pid)
	local p = self.info.players[pid]
	return p and p.passes or {}
end
function Match:isHost(pid)
	return pid == self.hostPid
end

-- ================================================================ time
function Match:update(dt: number)
	if self.state == "done" then
		return
	end
	self.clock += dt
	local G = self.G
	if self.state == "reviveWindow" then
		if not G.over then
			self.state = "playing" -- revived
		elseif self.clock >= self.reviveUntil then
			self:finish()
			return
		end
	end
	if not self.paused and not G.over then
		self.acc += dt * 1000 * self.speed
		local steps = math.min(math.floor(self.acc), Config.MAX_STEPS_PER_FRAME)
		self.acc = if steps == Config.MAX_STEPS_PER_FRAME then 0 else self.acc - steps -- never spiral: drop time we can't catch up
		for _ = 1, steps do
			E.step(G)
			if #G.fx > 0 then
				for _, f in G.fx do
					table.insert(self.fx, f)
					if f.k == "combo" then
						G.comboCounts[f.name] = (G.comboCounts[f.name] or 0) + 1
					end
				end
				table.clear(G.fx)
			end
			if G.over then
				break
			end
		end
		if steps > 0 then
			self:runQueues()
		end
	end
	self.snapAcc += dt
	if self.snapAcc >= 1 / Config.SNAPSHOT_HZ then
		self.snapAcc = 0
		self:broadcast()
	end
	if G.over and self.state == "playing" then
		if G.lost and self.info.plus and (G.revives or 0) < 3 then
			self.state = "reviveWindow"
			self.reviveUntil = self.clock + REVIVE_WINDOW
			self.io.event(nil, "reviveOffer", { seconds = REVIVE_WINDOW, price = X.revivePrice(G) })
		else
			self:finish()
		end
	end
end

function Match:broadcast()
	local G = self.G
	local sig = Snapshot.turretSignature(G)
	if sig ~= self.sig then
		self.sig = sig
		self.io.event(nil, "turrets", Snapshot.turretDetails(G))
	end
	local h = Snapshot.header(G)
	h.speed, h.paused, h.host = self.speed, self.paused, self.hostPid
	h.reviveUntil = if self.state == "reviveWindow" then self.reviveUntil - self.clock else nil
	self.io.state(Snapshot.encode(G, self.fx), h)
	table.clear(self.fx)
end

function Match:finish()
	if self.state == "done" then
		return
	end
	self.state = "done"
	self:broadcast()
	local G = self.G
	local results = {}
	for pid in G.players do
		results[pid] = { wave = G.waveNum, kills = G.kills, won = G.won, assisted = G.assisted == true, plus = self.info.plus }
	end
	self.io.ended(self, results)
end

-- ================================================================ players
function Match:join(pid, p)
	local G = self.G
	if G.players[pid] then
		return
	end
	self.info.players[pid] = p
	table.insert(self.info.order, pid)
	if self.loadouts then
		self.loadouts[pid] = loadoutOf(p) -- the mods read this table, so research and passes apply at once
	end
	E.addPlayer(G, pid, 0) -- late joiners start with an empty wallet and share bounty from now on
end
function Match:leave(pid)
	local G = self.G
	E.removePlayer(G, pid) -- turrets and cash go to the next player (a no-op if this was the last one)
	if pid == self.hostPid then
		self.hostPid = G.playerOrder[1] ~= pid and G.playerOrder[1] or nil
		self.io.event(nil, "toast", { text = "The host left. New host: " .. tostring(self.hostPid and self.info.players[self.hostPid].name) })
	end
end

-- ================================================================ actions
function Match:allow(pid)
	local b = self.bucket[pid]
	if not b then
		b = { tokens = Config.ACTIONS_PER_SECOND, t = self.clock }
		self.bucket[pid] = b
	end
	b.tokens = math.min(Config.ACTIONS_PER_SECOND, b.tokens + (self.clock - b.t) * Config.ACTIONS_PER_SECOND)
	b.t = self.clock
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Returns ok, message. Every argument is checked here; the engine also re-checks ownership, cost and placement.
function Match:action(pid, op, ...)
	local G = self.G
	local spec = Net.ACTIONS[op]
	if not spec or not G.players[pid] or self.state == "done" then
		return false, "not allowed"
	end
	local a = Net.check(spec, { ... })
	if not a then
		return false, "bad arguments"
	end
	if not self:allow(pid) then
		return false, "slow down"
	end
	if op == "build" then
		local d = G.D.turrets[a[1]]
		if not d or not G.unlocked[a[1]] then
			return false, "locked"
		end
		local t = E.build(G, pid, a[1], a[2], a[3])
		return t ~= nil, if t then nil else "can't build there"
	elseif op == "upgrade" then
		if not STATS[a[2]] then
			return false, "bad stat"
		end
		return E.upgrade(G, pid, a[1], a[2], a[3] == true)
	elseif op == "sell" then
		self.queues[a[1]] = nil
		return E.sell(G, pid, a[1]) > 0
	elseif op == "move" then
		return E.move(G, pid, a[1], a[2], a[3])
	elseif op == "mode" then
		return E.setTargetMode(G, pid, a[1], a[2])
	elseif op == "lock" then
		return E.toggleLock(G, pid, a[1]) ~= nil
	elseif op == "dir" then
		if not SPREADS[a[3]] then
			return false, "bad spread"
		end
		return E.setDirectional(G, pid, a[1], a[2], a[3])
	elseif op == "join" then
		return E.join(G, pid, a[1], a[2])
	elseif op == "focus" then
		return E.focus(G, a[1], a[2]) ~= nil
	elseif op == "combonly" then
		return E.combonlyChoose(G, pid, a[1], a[2])
	elseif op == "send" then
		return E.waveSend(G)
	elseif op == "speed" then
		if not self:isHost(pid) or not table.find(Config.SPEEDS, a[1]) then
			return false, "host only"
		end
		if a[1] > Config.FREE_SPEED and not self:passes(pid).speed then
			return false, "needs Speed Demon"
		end
		self.speed = a[1]
		return true
	elseif op == "pause" then
		if not self:isHost(pid) then
			return false, "host only"
		end
		self.paused = a[1]
		return true
	elseif op == "prefs" then
		if not self:isHost(pid) then
			return false, "host only"
		end
		E.setPrefs(G, { waveSpacing = math.clamp(math.floor(a[1]), 5, 60) * 1000, waveFollow = a[2] })
		return true
	elseif op == "queue" then
		return self:queue(pid, a[1], a[2])
	elseif op == "blueprintSave" then
		return self:blueprintSave(pid)
	elseif op == "blueprintLoad" then
		return self:blueprintLoad(pid)
	end
	return false, "unknown"
end

-- ================================================================ Commander Tools
local function owned(G, pid, id)
	for _, t in G.turrets do
		if t.id == id and not t.dead and t.owner == pid then
			return t
		end
	end
	return nil
end
function Match:queue(pid, id, stat)
	if not self:passes(pid).commander then
		return false, "needs Commander Tools"
	end
	local t = owned(self.G, pid, id)
	if not t then
		return false, "not yours"
	end
	if stat == "clear" then
		self.queues[id] = nil
		return true
	end
	if not STATS[stat] then
		return false, "bad stat"
	end
	local q = self.queues[id] or {}
	if #q >= 40 then
		return false, "queue full"
	end
	table.insert(q, stat)
	self.queues[id] = q
	self.io.event(pid, "queue", { id = id, list = q })
	return true
end
function Match:runQueues()
	local G = self.G
	for id, q in self.queues do
		local t
		for _, o in G.turrets do
			if o.id == id and not o.dead then
				t = o
				break
			end
		end
		if not t then
			self.queues[id] = nil
			continue
		end
		while #q > 0 do
			local stat = q[1]
			local cost = E.upCost(t, stat)
			if cost == nil then
				table.remove(q, 1) -- maxed: skip
			elseif G.players[t.owner] and G.players[t.owner].cash >= cost then
				E.upgrade(G, t.owner, t.id, stat, false)
				table.remove(q, 1)
			else
				break
			end
		end
		if #q == 0 then
			self.queues[id] = nil
		end
	end
	-- blueprints: build the next saved turret when its owner can afford it, then queue its saved levels
	for pid, list in self.pending do
		local p = G.players[pid]
		if not p or #list == 0 then
			self.pending[pid] = nil
			continue
		end
		local b = list[1]
		local d = G.D.turrets[b.kind]
		if not d or not G.unlocked[b.kind] or not E.canBuildAt(G, b.kind, b.x, b.y, nil) then
			table.remove(list, 1) -- blocked or locked in this run: skip it
		elseif p.cash >= E.turretCost(G, pid, b.kind) then
			local t = E.build(G, pid, b.kind, b.x, b.y)
			table.remove(list, 1)
			if t then
				local q = {}
				for _, stat in { "damage", "range", "rate" } do
					for _ = 1, b.lvl[stat] or 0 do
						table.insert(q, stat)
					end
				end
				if #q > 0 then
					self.queues[t.id] = q
				end
			end
		end
	end
end
function Match:blueprintSave(pid)
	if not self:passes(pid).commander then
		return false, "needs Commander Tools"
	end
	local bp = {}
	for _, t in self.G.turrets do
		if t.owner == pid and #bp < 60 then
			table.insert(bp, { kind = t.kind, x = t.x, y = t.y, lvl = { damage = t.lvl.damage, range = t.lvl.range, rate = t.lvl.rate } })
		end
	end
	self.io.saveBlueprint(pid, self.G.mapKey, bp)
	return true
end
function Match:blueprintLoad(pid)
	if not self:passes(pid).commander then
		return false, "needs Commander Tools"
	end
	local bp = self.io.loadBlueprint(pid, self.G.mapKey)
	if not bp or #bp == 0 then
		return false, "no blueprint for this map"
	end
	self.pending[pid] = table.clone(bp)
	return true
end

-- ================================================================ products (MatchService handles the Robux side)
function Match:canUseProduct(id)
	return self.info.plus and X.canUseProduct(self.G, id) and self.state ~= "done"
end
function Match:applyProduct(pid, id, arg)
	if not self:canUseProduct(id) then
		return false
	end
	local ok = X.useProduct(self.G, id, pid, arg)
	if ok then
		local label = id
		for _, p in X.XD.products do
			if p.id == id then
				label = p.name
			end
		end
		self.io.event(nil, "toast", { text = (self.info.players[pid] and self.info.players[pid].name or "?") .. " used " .. label })
	end
	return ok
end

return Match
