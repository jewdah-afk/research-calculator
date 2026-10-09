--!nonstrict
-- Peckwood server. Owns every number: wallets, upgrades, the popcorn field (per player), pickups (server-side
-- distance check), purchases, resets, companions, fishing, expedition, saves, AUTO (group perk) and the dev saves.
-- Clients only render and ask through the single Action remote.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = RS:WaitForChild("Peckwood")
local Map = require(Shared:WaitForChild("MapData"))
local Models = require(Shared:WaitForChild("Models"))
local Config = require(Shared:WaitForChild("Config"))
local Island = require(script.Parent:WaitForChild("Island"))
local G = require(script.Parent:WaitForChild("Game"))
local Defs = G.Defs
local F, EN = Defs.F, Defs.EN
local S = Models.S

Island.build()

-- ---------------------------------------------------------------- remotes
local Remotes = Instance.new("Folder"); Remotes.Name = "Remotes"; Remotes.Parent = Shared
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Remotes; return r
end
local StateEv, FishEv, SpawnEv, CollectEv, ActionEv, ToastEv = remote("State"), remote("Fish"), remote("Spawn"), remote("Collect"), remote("Action"), remote("Toast")

-- ---------------------------------------------------------------- character: a bare root the client drives (unchanged from birb(test))
do
	local char = Instance.new("Model"); char.Name = "StarterCharacter"
	local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(0.5 * S, 0.5 * S, 0.5 * S); hrp.Transparency = 1; hrp.CanCollide = false; hrp.CanQuery = false; hrp.CanTouch = false
	hrp.Anchored = false; hrp.Parent = char; char.PrimaryPart = hrp
	local hum = Instance.new("Humanoid"); hum.RigType = Enum.HumanoidRigType.R15; hum.HipHeight = 0
	hum.WalkSpeed = 0; hum.JumpPower = 0; hum.UseJumpPower = true; hum.PlatformStand = true; hum.RequiresNeck = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None; hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = char
	char.Parent = StarterPlayer
end

-- ---------------------------------------------------------------- spawn tiles: grass / dirt clear of scenery
local spawnTiles = {}
local blocked = {}
for _, o in Map.objects do table.insert(blocked, Island.toWorld(o[2], o[3])) end
for j = 0, Map.ROWS - 1 do
	for i = 0, Map.COLS - 1 do
		local t = Map.tile(i, j)
		local px, py = (i + 0.5) * Map.PX, (j + 0.5) * Map.PX
		if (t == 1 or t == 2) and Map.height(i, j) == 0 and px >= 40 and px <= 600 and py >= 40 and py <= 440 then
			if Map.tile(i + 1, j) ~= 0 and Map.tile(i - 1, j) ~= 0 and Map.tile(i, j + 1) ~= 0 and Map.tile(i, j - 1) ~= 0 then
				local c = Island.tileCenter(i, j); local ok = true
				for _, b in blocked do if (b - c).Magnitude < 1.2 * S then ok = false; break end end
				if ok then table.insert(spawnTiles, c) end
			end
		end
	end
end

-- desert spawn tiles: walkable desert-island tiles clear of props (golden drops while you stand on the Desert)
local World = require(Shared:WaitForChild("World"))
local desertTiles = {}
do
	local d = World.byId.desert
	for j = d.oj + 1, d.oj + d.N - 2 do
		for i = d.oi + 1, d.oi + d.W - 2 do
			local c, own = World.rawTile(i, j)
			if own == d and (c == 1 or c == 2 or c == 4) and World.height(i, j) == 0 then
				local ok = true
				for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do local c2 = World.rawTile(i + o[1], j + o[2]); if c2 == 0 or c2 == 3 then ok = false end end
				if World.inProp(i + 0.5, j + 0.5, 0.6) then ok = false end
				if ok then table.insert(desertTiles, Vector3.new((i + 0.5 - Map.COLS / 2) * S, World.base(i, j), (j + 0.5 - Map.ROWS / 2) * S)) end   -- on its terrace
			end
		end
	end
end
-- the zone follows where the bird stands: on the Desert island = desert, on the Park = park (bridges keep the last)
local function zoneAt(plr): string?
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local i, j = math.floor(hrp.Position.X / S + Map.COLS / 2), math.floor(hrp.Position.Z / S + Map.ROWS / 2)
	local _, isl = World.rawTile(i, j)
	if not isl then return nil end
	local id = isl.area or isl.id   -- Isle regions count as their area
	return if id == "desert" then "desert" elseif id == "park" then "park" else nil
end

-- ---------------------------------------------------------------- sessions
local store = (function()
	local ok, ds = pcall(function() return DataStoreService:GetDataStore(Config.DATASTORE) end)
	return if ok then ds else nil
end)()

type Kernel = { pos: Vector3, kind: string, golden: boolean }
local sessions = {}
-- session = { real = state (saved), view = state (what the game runs on), mode = "regular"|"maxed"|"step",
--             kernels, nextId, popT, lastAct, rng, dirty, fishDirty, autoAllowed, devAllowed, autoT, buyT }

local function isDev(plr: Player): boolean
	return RunService:IsStudio() or table.find(Config.DEV_USER_IDS, plr.UserId) ~= nil or (game.CreatorType == Enum.CreatorType.User and plr.UserId == game.CreatorId)
end
local function checkGroup(plr: Player): boolean
	if Config.GROUP_ID == 0 then return RunService:IsStudio() end
	local ok, inG = pcall(function() return plr:IsInGroup(Config.GROUP_ID) end)
	return ok and inG
end

local function derived(ss)
	local s = ss.view
	G.syncFactors(s)
	local fs = s.fish
	local rods = {}
	for _, r in G.rodRows(s) do table.insert(rods, r.id) end
	local recentSell = {}
	for i, c in fs.recent do recentSell[i] = G.sellValue(s, c.id) end
	local hp, dmg, regen = G.parrotStats(s)
	local nxt = Defs.ISLANDS[s.island + 1]
	return {
		kernelValue = F.popcornGain(s, 1, G.inDesert(s)), interval = F.spawnInterval(s, G.inDesert(s)), cap = F.maxCapacity(s),
		reach = G.reachPx(s), speed = G.speed(s), plumeGain = G.plumeGain(s), popPerSec = F.popcornGain(s, 1, false) / F.spawnInterval(s, false),
		seedsPerSec = G.seedsPerSec(s), twigsPerSec = G.twigsPerSec(s), orePerSec = G.orePerSec(s),
		goldenValue = G.goldenValue(s), goldenChance = G.desertGoldenChance(s), evoProgress = G.evoProgress(s),
		seagullInterval = G.seagullInterval(s), fishInterval = G.fishInterval(s), tankCount = G.tankCount(s),
		parrot = { hp = hp, dmg = dmg, regen = regen }, rodRows = rods, recentSell = recentSell,
		nextGoal = nxt and nxt.goal or "Every island is open", nextCost = nxt and nxt.cost,
		autoAllowed = ss.autoAllowed, devAllowed = ss.devAllowed, mode = ss.mode, groupId = Config.GROUP_ID,
		discovered = (function() local n = 0; for _ in fs.disc do n += 1 end; return n end)(),
		shop = { passes = (ss.real.shop or {}).passes or {}, boostLeft = math.max(0, ((ss.real.shop or {}).boostUntil or 0) - os.time()),
			testGrants = game:GetService("RunService"):IsStudio() or ss.devAllowed },
	}
end

-- state snapshot without the big fish maps (those go through the Fish remote when they change)
local function snapshot(s)
	local fs = s.fish
	local disc, best, have = fs.disc, fs.best, fs.have
	fs.disc, fs.best, fs.have = nil, nil, nil
	local copy = G.clone(s)
	fs.disc, fs.best, fs.have = disc, best, have
	return copy
end

local function push(plr: Player)
	local ss = sessions[plr]; if not ss then return end
	ss.dirty = false
	StateEv:FireClient(plr, snapshot(ss.view), derived(ss))
	if ss.fishDirty then
		ss.fishDirty = false
		FishEv:FireClient(plr, ss.view.fish.disc, ss.view.fish.best, ss.view.fish.have)
	end
end
local function toast(plr, ...) ToastEv:FireClient(plr, ...) end

local function clearField(plr, ss)
	for id in ss.kernels do CollectEv:FireClient(plr, id, nil, false) end
	ss.kernels = {}
end

local function load(plr: Player)
	if store then
		local ok, data = pcall(function() return store:GetAsync("u" .. plr.UserId) end)
		if ok and data then return G.deserialize(data) end
	end
	return G.fresh()
end
local function save(plr: Player)
	local ss = sessions[plr]; if not (ss and store) then return end
	local data = G.serialize(ss.real)
	pcall(function() store:SetAsync("u" .. plr.UserId, data) end)
end

Players.PlayerAdded:Connect(function(plr)
	local real = load(plr)
	G.refreshDailies(real, os.time())
	-- Red Panda assist: credit offline twigs (55%, capped at 8 hours) into the waiting pile
	if real.panda.assist and real.panda.leftAt > 0 then
		local away = math.min(8 * 3600, os.time() - real.panda.leftAt)
		real.panda.waiting += G.twigsPerSec(real) * 0.55 * away
	end
	local ss = { real = real, view = real, mode = "regular", kernels = {}, nextId = 1, popT = 0, lastAct = 0, rng = Random.new(),
		dirty = true, fishDirty = true, autoAllowed = checkGroup(plr), devAllowed = isDev(plr), autoT = 0, buyT = 0 }
	if not ss.autoAllowed then real.auto = false end
	sessions[plr] = ss
	plr.CharacterAdded:Connect(function(ch)
		task.defer(function()
			local hrp = ch:WaitForChild("HumanoidRootPart") :: BasePart
			pcall(function() hrp:SetNetworkOwner(plr) end)
			hrp.CFrame = CFrame.new(Island.toWorld(320, 250) + Vector3.new(0, hrp.Size.Y / 2, 0))
			local s2 = sessions[plr]; if not s2 then return end
			for id, k in s2.kernels do SpawnEv:FireClient(plr, id, k.pos, k.kind) end
			s2.fishDirty = true
			push(plr)
		end)
	end)
	push(plr)
end)
Players.PlayerRemoving:Connect(function(plr)
	local ss = sessions[plr]
	if ss then ss.real.panda.leftAt = os.time() end
	save(plr); sessions[plr] = nil
end)
game:BindToClose(function() for plr in sessions do save(plr) end end)
task.spawn(function() while true do task.wait(60); for plr in sessions do save(plr) end end end)

-- ---------------------------------------------------------------- the field
local function collect(plr, ss, id, k)
	local s = ss.view
	ss.kernels[id] = nil
	local value
	if k.golden then
		value = G.goldenValue(s)
		value = G.give(s, "goldenPopcorn", value)
		s.stats.goldenCollected += value
		s.dave.golden += value
		if s.island >= 8 then   -- Dave levels from golden pickups (same curve as the Sparrow)
			s.dave.xp += value * (1 + 0.08 * Defs.level(s, "dave_training"))
			while s.dave.level < 1000 and s.dave.xp >= Defs.S.sparrowXpNeeded(s.dave.level) do s.dave.xp -= Defs.S.sparrowXpNeeded(s.dave.level); s.dave.level += 1 end
		end
	else
		local base = 1
		for _, t in F.PopcornTypes do if t.id == k.kind then base = t.value end end
		value = F.popcornGain(s, base, G.inDesert(s))
		value = G.give(s, "popcorn", value)
		if s.island >= 10 and ss.rng:NextNumber() < Defs.S.echoChance(false, false) then
			G.give(s, "echoPopcorn", Defs.level(s, "p_echo_value"))
		end
	end
	CollectEv:FireClient(plr, id, value, k.golden, k.kind)
	ss.dirty = true
end

local acc, pushAcc = 0, 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt; pushAcc += dt
	for plr, ss in sessions do
		local s = ss.view
		-- systems
		for _, t in G.step(s, dt, ss.rng) do
			if t[1] == "island" then
				local isl = Defs.ISLANDS[t[2]]
				toast(plr, "island", isl.id, isl.name)
			else
				toast(plr, t[1], t[2], t[3])
			end
			ss.fishDirty = ss.fishDirty or t[1] == "fish"
		end
		if s.fish.active or s.seagull.out then ss.fishDirty = true end
		ss.dirty = true
		-- zone from position
		local z = zoneAt(plr)
		if z and z ~= s.zone and (z == "park" or G.windowUnlocked(s, "golden")) then
			s.zone = z
			clearField(plr, ss)
			toast(plr, "travel", z)
		end
		-- popcorn spawns
		ss.popT += dt
		local interval = F.spawnInterval(s, G.inDesert(s))
		if ss.popT >= interval then
			ss.popT -= interval
			local live = 0; for _ in ss.kernels do live += 1 end
			if live < F.maxCapacity(s) and #spawnTiles > 0 then
				local pool = if G.inDesert(s) and #desertTiles > 0 then desertTiles else spawnTiles
				local c = pool[ss.rng:NextInteger(1, #pool)]
				local pos = c + Vector3.new(ss.rng:NextNumber(-0.35, 0.35) * S, 0, ss.rng:NextNumber(-0.35, 0.35) * S)
				local kind = F.rollType(s, G.inDesert(s), ss.rng)
				if G.inDesert(s) and kind ~= "golden" and ss.rng:NextNumber() < G.desertGoldenChance(s) then kind = "golden" end
				local id = ss.nextId; ss.nextId += 1
				ss.kernels[id] = { pos = pos, kind = kind, golden = kind == "golden" }
				SpawnEv:FireClient(plr, id, pos, kind)
			end
		end
		-- AUTO (group perk): collect a kernel every 0.35 s and buy the cheapest affordable upgrade every second
		if s.auto and ss.autoAllowed then
			ss.autoT += dt
			if ss.autoT >= 0.35 then
				ss.autoT = 0
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				local best, bestD
				for id, k in ss.kernels do
					local d = if hrp then (hrp.Position - k.pos).Magnitude else 0
					if not bestD or d < bestD then best, bestD = id, d end
				end
				if best then collect(plr, ss, best, ss.kernels[best]) end
			end
			ss.buyT += dt
			if ss.buyT >= 1 then
				ss.buyT = 0
				local pick, pickCost
				for id, d in Defs.UP do
					local w = G.windowRowOf[id]
					if w and G.windowUnlocked(s, w) and Defs.level(s, id) < Defs.maxLevel(s, id) then
						local c = Defs.cost(s, id)
						if c and EN.meeq(s[d.cur], c) and (not pickCost or c < pickCost) and d.cur ~= "goldenFeathers" then pick, pickCost = id, c end
					end
				end
				if pick then G.buy(s, pick, false) end
			end
		end
	end
	if acc >= 0.1 then
		acc = 0
		for plr, ss in sessions do
			local ch = plr.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then continue end
			local reach = G.reachPx(ss.view) / Map.PX * S + 1.2
			local p = hrp.Position
			local last = ss.lastPos; ss.lastPos = p
			local maxStep = 100 * G.speed(ss.view) * 1.3 / Map.PX * S * 0.1 * 1.6 + 2
			if last and Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude > maxStep then continue end   -- teleport: no pickups this tick
			for id, k in ss.kernels do
				local dx, dz = p.X - k.pos.X, p.Z - k.pos.Z
				if dx * dx + dz * dz < reach * reach then collect(plr, ss, id, k) end
			end
		end
	end
	if pushAcc >= 0.2 then
		pushAcc = 0
		for plr, ss in sessions do if ss.dirty then push(plr) end end
	end
end)

-- ---------------------------------------------------------------- actions (all validated here)
local A = {}

function A.buy(plr, ss, id, all)
	if type(id) ~= "string" or not Defs.UP[id] then return end
	local w = G.windowRowOf[id]
	if w and not G.windowUnlocked(ss.view, w) then return end
	local n = G.buy(ss.view, id, all == true)
	if n > 0 then toast(plr, "bought", id, n) else toast(plr, "poor", id) end
end
function A.molt(plr, ss)
	if not G.windowUnlocked(ss.view, "molt") then return end
	local g = G.molt(ss.view)
	if not g then toast(plr, "poor", "molt"); return end
	clearField(plr, ss)
	toast(plr, "molt", EN.short(g), ss.view.rebirbCount == 1)
end
function A.unlock(plr, ss)
	if G.unlockIsland(ss.view) then toast(plr, "unlocked") else toast(plr, "poor", "unlock") end
end
function A.travel(plr, ss, zone)
	if zone ~= "park" and zone ~= "desert" then return end
	if zone == "desert" and not G.windowUnlocked(ss.view, "golden") then return end
	ss.view.zone = zone
	clearField(plr, ss)
	toast(plr, "travel", zone)
end
function A.feed(plr, ss, res, all)
	if not G.windowUnlocked(ss.view, "evolve") then return end
	if not G.feed(ss.view, res, all == true) then toast(plr, "poor", "feed_" .. tostring(res)) end
end
function A.evolve(plr, ss)
	if not G.windowUnlocked(ss.view, "evolve") then return end
	if G.evolve(ss.view) then clearField(plr, ss); toast(plr, "evolve", ss.view.evolutionCount) else toast(plr, "poor", "evolve") end
end
function A.spend(plr, ss, stat, all)
	if not G.windowUnlocked(ss.view, "parrot") or (stat ~= "hp" and stat ~= "dmg" and stat ~= "regen") then return end
	local s = ss.view
	local have = math.floor(EN.toNumber(s.skillPoints))
	local n = if all then have else math.min(1, have)
	if n <= 0 then toast(plr, "poor", "spend_" .. stat); return end
	s.skillPoints = EN.sub(s.skillPoints, n)
	s.parrot[stat] += n
end
function A.expedition(plr, ss)
	if not G.windowUnlocked(ss.view, "parrot") then return end
	ss.view.parrot.active = not ss.view.parrot.active
end
function A.sparrow(plr, ss, op)
	if not G.windowUnlocked(ss.view, "sparrow") then return end
	local s, ok = ss.view, true
	if op == "feed" then ok = G.sparrowFeedNow(s)
	elseif op == "feedall" then ok = G.sparrowFeedNow(s); while ok and G.sparrowFeedNow(s) do end; ok = true
	elseif op == "drain" then s.sparrow.draining = true
	elseif op == "stop" then s.sparrow.draining = false
	elseif op == "split" then ok = G.mitosis(s)
	elseif op == "auto" then s.sparrow.autoMitosis = not s.sparrow.autoMitosis
	elseif op == "rebirb" then ok = G.sparrowRebirb(s) end
	if not ok then toast(plr, "poor", "sparrow_" .. tostring(op)) end
end
function A.seagull(plr, ss, op)
	if not G.windowUnlocked(ss.view, "seagull") then return end
	local g = ss.view.seagull
	if op == "route" then g.route = g.route % #G.ROUTES + 1
	elseif op == "doctrine" then g.doctrine = g.doctrine % #G.DOCTRINES + 1
	elseif op == "send" then g.out = not g.out
	elseif op == "migrate" then
		if g.level >= G.seagullCap(ss.view) then g.migrations += 1; g.level = 1; g.xp = 0 else toast(plr, "poor", "migrate") end
	elseif op == "auto" then g.autoMigrate = not g.autoMigrate end
end
function A.dave(plr, ss, op)
	if not G.windowUnlocked(ss.view, "dave") then return end
	local d = ss.view.dave
	if op == "rebirb" then
		if d.level >= 100 and d.golden >= 250 then d.level, d.xp, d.golden = 1, 0, 0; d.rebirbs = math.min(100, d.rebirbs + 1) else toast(plr, "poor", "dave_rebirb") end
	elseif op == "branch" then d.branch = (d.branch + 1) % 3 end
end
function A.panda(plr, ss, op)
	if not G.windowUnlocked(ss.view, "redpanda") then return end
	local p = ss.view.panda
	if op == "on" then p.assist = true elseif op == "off" then p.assist = false
	elseif op == "collect" then
		if p.waiting <= 0 then toast(plr, "poor", "panda"); return end
		G.give(ss.view, "twigs", p.waiting); p.waiting = 0
	end
end
function A.nest(plr, ss)
	if not G.windowUnlocked(ss.view, "nest") then return end
	local s = ss.view
	local t = Defs.NEST_TIERS[s.nest.tier + 1]
	if s.nest.tier + 1 > Defs.S.nestMaxTier(s.evolutionCount) or not t or not EN.meeq(s.twigs, t.next) then toast(plr, "poor", "nest"); return end
	s.twigs = EN.sub(s.twigs, t.next); s.nest.tier += 1
	toast(plr, "nest", Defs.NEST_TIERS[s.nest.tier + 1].name)
end
function A.fish(plr, ss, op, arg)
	if not G.windowUnlocked(ss.view, "rods") then return end
	local s = ss.view; local fs = s.fish
	if op == "go" then fs.active = not fs.active
	elseif op == "craft" then if G.craft(s, arg) then toast(plr, "craft", arg) else toast(plr, "poor", "craft_" .. tostring(arg)) end
	elseif op == "bait" or op == "bait10" then
		local b; for _, x in Defs.BAITS do if x.id == arg then b = x end end
		if not b or (b.evolutionRequired or 0) > s.evolutionCount + 1 then toast(plr, "poor", "bait_" .. tostring(arg)); return end
		local n = if op == "bait10" then 10 else 1
		local c = G.baitCost(b) * n
		if not EN.meeq(s.moneta, c) then toast(plr, "poor", "bait_" .. tostring(arg)); return end
		s.moneta = EN.sub(s.moneta, c); fs.baits[arg] = (fs.baits[arg] or 0) + n; fs.bait = arg
	elseif op == "equip" then if fs.have[arg] and fs.have[arg] > 0 then fs.equipped = arg end
	elseif op == "sell" then
		if not fs.have[arg] or fs.have[arg] <= 0 then return end
		fs.have[arg] -= 1
		G.give(s, "moneta", G.sellValue(s, arg))
		if fs.equipped == arg and fs.have[arg] <= 0 then fs.equipped = nil end
	elseif op == "tank" then
		local i = tonumber(arg) or 1
		if i < 1 or i > G.tankCount(s) then toast(plr, "poor", "tank"); return end
		-- place the best not-yet-tanked fish you own (Pro lure rule: fish not yet in the aquarium)
		local pick, pv
		for id, n in fs.have do
			if n > 0 and not table.find(fs.tanks, id) then
				local v = Defs.FISH_BY_ID[id].sellValue or 0
				if not pv or v > pv then pick, pv = id, v end
			end
		end
		if pick then fs.tanks[i] = pick else toast(plr, "poor", "tank") end
	end
	ss.fishDirty = true
end
function A.quest(plr, ss, op, i)
	if not G.windowUnlocked(ss.view, "quests") then return end
	if op == "claim" then if G.claim(ss.view, tonumber(i)) then toast(plr, "claim") else toast(plr, "poor", "claim") end end
end
function A.sacrifice(plr, ss)
	if not G.windowUnlocked(ss.view, "sacrifice") then return end
	if G.sacrifice(ss.view) then toast(plr, "sacrifice", ss.view.sacrifice.tier) else toast(plr, "poor", "sacrifice") end
end
function A.auto(plr, ss, on)
	ss.autoAllowed = ss.autoAllowed or checkGroup(plr)   -- re-check after the in-game join prompt
	if not ss.autoAllowed then toast(plr, "autolocked", Config.GROUP_ID); return end
	ss.view.auto = on == true
	toast(plr, "auto", ss.view.auto)
end
function A.dev(plr, ss, op)
	if not ss.devAllowed then return end
	if op == "regular" then ss.view = ss.real; ss.mode = "regular"
	elseif op == "maxed" then ss.view = G.maxed(); ss.mode = "maxed"
	elseif op == "fresh" then ss.view = G.fresh(); ss.mode = "step"   -- QA: Park only, then NEXT ISLAND plays each unlock
	elseif op == "next" then ss.view = G.stepIsland(if ss.mode == "regular" then ss.real else ss.view); ss.mode = "step"
	elseif op == "grant" then for _, k in Defs.CUR_ORDER do G.give(ss.view, k, EN.mul(EN.add(ss.view[k], 100), 10)) end
	else return end
	ss.view.auto = ss.view.auto and ss.autoAllowed
	G.refreshDailies(ss.view, os.time())
	clearField(plr, ss)
	ss.fishDirty = true
	toast(plr, "dev", ss.mode, ss.view.island)
end

-- ---------------------------------------------------------------- shop (passes + products), server-verified
local MarketplaceService = game:GetService("MarketplaceService")
local Shop = require(RS:WaitForChild("Peckwood"):WaitForChild("Shop"))
local function shopOf(s) s.shop = s.shop or { passes = {}, boostUntil = 0 }; s.shop.passes = s.shop.passes or {}; return s.shop end
local function grant(plr, item)
	local ss = sessions[plr]; if not ss then return false end
	for _, s in { ss.real, ss.view } do
		local sh = shopOf(s)
		if item.grants then for _, g in item.grants do sh.passes[g] = true end; sh.passes[item.id] = true
		elseif item.kind == "pass" then sh.passes[item.id] = true
		elseif item.minutes then sh.boostUntil = math.max(sh.boostUntil or 0, os.time()) + item.minutes * 60
		elseif item.seconds then
			G.syncFactors(s)
			local pps = F.popcornGain(s, 1, false) / F.spawnInterval(s, false)
			G.give(s, "popcorn", math.max(1000, pps * item.seconds * Shop.mult(s, "popcorn", os.time())), true)
		end
		if ss.real == ss.view then break end
	end
	ss.dirty = true
	push(plr)
	return true
end
-- passes owned on Roblox are re-checked every join (never trust saved flags alone for live passes)
Players.PlayerAdded:Connect(function(plr)
	for _, it in Shop.ITEMS do
		if it.kind == "pass" and it.assetId > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, it.assetId)
			if ok and owns then task.defer(grant, plr, it) end
		end
	end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, bought)
	local it = Shop.BY_ASSET[passId]
	if bought and it then grant(plr, it) end
end)
MarketplaceService.ProcessReceipt = function(info)
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	local it = Shop.BY_ASSET[info.ProductId]
	if not plr or not it then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if grant(plr, it) then save(plr); return Enum.ProductPurchaseDecision.PurchaseGranted end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
-- Studio / dev test path: grants without Robux (never available to normal players in live servers)
A.shoptest = function(plr, ss, id)
	if not (game:GetService("RunService"):IsStudio() or ss.devAllowed) then return end
	local it = Shop.BY_ID[id]; if it then grant(plr, it) end
end

ActionEv.OnServerEvent:Connect(function(plr, kind, a, b)
	local ss = sessions[plr]; if not ss or type(kind) ~= "string" then return end
	local fn = A[kind]; if not fn then return end
	local now = os.clock(); if now - ss.lastAct < 0.05 then return end; ss.lastAct = now
	fn(plr, ss, a, b)
	push(plr)
end)
