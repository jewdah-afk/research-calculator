--!nonstrict
-- Peckwood server. Owns every number: wallets, upgrades, the egg field (per player, Birb's Park rules in
-- Systems/Park), pickups (server-side distance check from the character's position), purchases, resets, companions,
-- fishing, expedition, saves, AUTO (group perk) and the dev saves. Clients only render and ask through the single
-- Action remote (rate-limited, every argument validated here).
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
local World = require(Shared:WaitForChild("World"))
local G = require(script.Parent:WaitForChild("Game"))
local Defs = G.Defs
local F, EN = Defs.F, Defs.EN
local R, Park = G.R, G.Park
local S = Models.S
local STEP = 0.05   -- the Phase 1 step runs at a fixed 20 Hz, like the playtest's 0.05 s sub-steps

Island.build()

-- ---------------------------------------------------------------- remotes
local Remotes = Instance.new("Folder"); Remotes.Name = "Remotes"; Remotes.Parent = Shared
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Remotes; return r
end
local StateEv, FishEv, SpawnEv, CollectEv, ActionEv, ToastEv = remote("State"), remote("Fish"), remote("Spawn"), remote("Collect"), remote("Action"), remote("Toast")
local MoveEv = remote("Move")   -- Gravity Field / magnet drift: ({ id }, { Vector3 }) batches

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

-- ---------------------------------------------------------------- the Park egg field: Birb's field box on our map
-- Birb's Park is a 1056 x 792 px field with a 40 px margin; ours is MapData's 640 x 480 px Park with the eggs kept in
-- the fenced egg yard: Park.spawnEgg draws a spot in the box and re-rolls it (up to 24 times, as the playtest's
-- game3d does) until spawnOk says it is on a yard tile clear of scenery. Radii stay Birb px (studs = px / Map.PX * S).
local yardOk = {}   -- i * 100 + j -> true
local blocked = {}
for _, o in Map.objects do table.insert(blocked, Island.toWorld(o[2], o[3])) end
for j = 0, Map.ROWS - 1 do
	for i = 0, Map.COLS - 1 do
		local t = Map.tile(i, j)
		local px, py = (i + 0.5) * Map.PX, (j + 0.5) * Map.PX
		-- eggs spawn only inside the fenced egg yard (owner 2026-10-09: "a fenced in area where your eggs spawn")
		if t == 1 and Map.inYard(i, j) and Map.inYard(i + 1, j) and Map.inYard(i - 1, j) and Map.inYard(i, j + 1) and Map.inYard(i, j - 1) and Map.height(i, j) == 0 and px >= 40 and px <= 600 and py >= 40 and py <= 440 then
			if Map.tile(i + 1, j) ~= 0 and Map.tile(i - 1, j) ~= 0 and Map.tile(i, j + 1) ~= 0 and Map.tile(i, j - 1) ~= 0 then
				local c = Island.tileCenter(i, j); local ok = true
				for _, b in blocked do if (b - c).Magnitude < 1.2 * S then ok = false; break end end
				if ok then yardOk[i * 100 + j] = true end
			end
		end
	end
end

-- the spawn box = the yard's bounding box; spawnOk = a yard tile; fallback = a random yard tile (never the void)
local yardList = {}
local yi0, yi1, yj0, yj1 = math.huge, -math.huge, math.huge, -math.huge
for key in yardOk do
	local i, j = key // 100, key % 100
	table.insert(yardList, { i, j })
	yi0, yi1, yj0, yj1 = math.min(yi0, i), math.max(yi1, i), math.min(yj0, j), math.max(yj1, j)
end
table.sort(yardList, function(a, b) return a[1] * 100 + a[2] < b[1] * 100 + b[2] end)
local PARK_GEOM = {
	x0 = yi0 * Map.PX, sx = (yi1 - yi0 + 1) * Map.PX, y0 = yj0 * Map.PX, sy = (yj1 - yj0 + 1) * Map.PX, cx = 320, cy = 250,
	spawnOk = function(px: number, py: number) return yardOk[math.floor(px / Map.PX) * 100 + math.floor(py / Map.PX)] == true end,
	fallback = function(u: () -> number)
		local t = yardList[math.clamp(math.floor(u() * #yardList) + 1, 1, #yardList)]
		return (t[1] + 0.15 + 0.7 * u()) * Map.PX, (t[2] + 0.15 + 0.7 * u()) * Map.PX
	end,
}
-- field px -> world position on the rolling ground (the same shape the client terrain and the bird use)
local function fieldToWorld(px: number, py: number): Vector3
	local pos = Island.toWorld(px, py)
	local ti, tj = pos.X / S + Map.COLS / 2, pos.Z / S + Map.ROWS / 2
	return Vector3.new(pos.X, World.base(math.floor(ti), math.floor(tj)) + World.relief(ti, tj), pos.Z)
end

-- desert spawn tiles: walkable desert-island tiles clear of props (golden drops while you stand on the Desert)
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
-- the area under a world position (Isle regions count as their area; bridges / joins give nil)
local function areaAt(pos: Vector3): string?
	local i, j = math.floor(pos.X / S + Map.COLS / 2), math.floor(pos.Z / S + Map.ROWS / 2)
	local _, isl = World.rawTile(i, j)
	if not isl then return nil end
	local id = isl.area or isl.id
	return if type(id) == "string" and not string.find(id, ":") then id else nil
end
-- our areas -> Birb map ids (the Phase 1 step needs 0 Park, 1 Sunflower Field, 3 Castle; the rest are "elsewhere")
local AREA_MAP = { park = 0, garden = 1, bridge = 2, castle = 3, forest = 4, desert = 9, mine = 25, expedition = 18, echo = 30 }
-- the seed platform (Birb's 180 x 80 px pad on the Sunflower Field): a pad at the Garden's centre
local PLATFORM_R = 2.5 * S
local platformAt = (function()
	local g = World.byId.garden
	if not g then return nil end
	return Vector3.new((g.oi + g.W / 2 - Map.COLS / 2) * S, 0, (g.oj + g.N / 2 - Map.ROWS / 2) * S)
end)()
-- the zone for the old golden-drop toggle: desert / park (bridges keep the last)
local function zoneAt(plr): string?
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local id = areaAt(hrp.Position)
	return if id == "desert" then "desert" elseif id == "park" then "park" else nil
end

-- ---------------------------------------------------------------- sessions
local store = (function()
	local ok, ds = pcall(function() return DataStoreService:GetDataStore(Config.DATASTORE) end)
	return if ok then ds else nil
end)()

type Kernel = { pos: Vector3, kind: string, golden: boolean }
local DESERT_ID0 = 1000000   -- desert drops use their own id range (the Park field counts from 1)
local sessions = {}
local sendSfxPicks: (Player) -> ()   -- dev Sound Board picks (defined with the actions below; used on join)
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
		kernelValue = if G.inDesert(s) then F.popcornGain(s, 1, true) else math.floor(R.collectionMultiplier(s)),
		interval = if G.inDesert(s) then F.spawnInterval(s, true) else R.spawnInterval(s), cap = R.maxPopcorn(s),
		reach = G.reachPx(s), speed = G.speed(s), plumeGain = G.plumeGain(s),
		-- live income (Birb currencyRates) + what the seed platform makes
		popPerSec = ss.rt.rates.popcorn or 0, seedsPerSec = ss.rt.rates.sunflowerSeeds or 0, seedsPlatform = G.seedsPerSec(s, true),
		map = ss.rt.map, onPlatform = ss.rt.onPlatform, holdFeed = ss.rt.holdFeed, fieldCount = #Park.list(ss.rt, 0),
		twigsPerSec = G.twigsPerSec(s), orePerSec = G.orePerSec(s),
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

local function clearDesert(plr, ss)
	for id in ss.kernels do CollectEv:FireClient(plr, id, nil, false) end
	ss.kernels = {}
end
local function clearShown(plr, ss)
	for id in ss.shown do CollectEv:FireClient(plr, id, nil, false) end
	table.clear(ss.shown)
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
	local rng = Random.new()
	local function u() return rng:NextNumber() end
	local rt = G.newRuntime(PARK_GEOM, { type = u, pos = u, sparrow = u })
	rt.events = {}
	local ss = { real = real, view = real, mode = "regular", kernels = {}, nextId = DESERT_ID0, popT = 0, lastAct = 0, rng = rng, rt = rt, acc = 0,
		shown = {}, moveT = 0, dirty = true, fishDirty = true, autoAllowed = checkGroup(plr), devAllowed = isDev(plr), autoT = 0, buyT = 0 }
	if not ss.autoAllowed then real.auto = false end
	sessions[plr] = ss
	if ss.devAllowed then task.defer(function() if sendSfxPicks then sendSfxPicks(plr) end end) end
	plr.CharacterAdded:Connect(function(ch)
		task.defer(function()
			local hrp = ch:WaitForChild("HumanoidRootPart") :: BasePart
			pcall(function() hrp:SetNetworkOwner(plr) end)
			hrp.CFrame = CFrame.new(Island.toWorld(320, 250) + Vector3.new(0, hrp.Size.Y / 2, 0))
			local s2 = sessions[plr]; if not s2 then return end
			for id, k in s2.kernels do SpawnEv:FireClient(plr, id, k.pos, k.kind) end
			for _, p in Park.list(s2.rt, 0) do s2.shown[p.id] = true; SpawnEv:FireClient(plr, p.id, fieldToWorld(p.x, p.y), p.type) end
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
-- desert drops (pre-port golden toggle, kept until the Desert phase): collected by the old distance check
local function collectDesert(plr, ss, id, k)
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
		value = G.give(s, "popcorn", F.popcornGain(s, 1, true))
	end
	CollectEv:FireClient(plr, id, value, k.golden, k.kind)
	ss.dirty = true
end

-- replicate what the Park step did: spawns, collections (player and sparrows), clears
local function flushEvents(plr, ss)
	local ev = ss.rt.events
	if #ev == 0 then return end
	for _, e in ev do
		local kind = e[1]
		if kind == "spawn" then
			ss.shown[e[2]] = true
			SpawnEv:FireClient(plr, e[2], fieldToWorld(e[3], e[4]), e[5])
		elseif kind == "collect" then
			local id = e[2]
			if not ss.shown[id] then   -- collected the moment it spawned (inside the reach): show it, then pop it
				SpawnEv:FireClient(plr, id, fieldToWorld(e[6] or ss.rt.player.x, e[7] or ss.rt.player.y), e[5])
			end
			ss.shown[id] = nil
			CollectEv:FireClient(plr, id, e[3], false, e[5], e[4])   -- e[4] = "player" | "sparrow"
		elseif kind == "clear" then
			clearShown(plr, ss)
		end
	end
	table.clear(ev)
	ss.dirty = true
end
-- Gravity Field / magnet moved eggs: send the new spots (10 Hz, only while something moved)
local moveIds, movePos = {}, {}
local function flushMoves(plr, ss)
	local rt = ss.rt
	if not rt.moved then return end
	rt.moved = false
	table.clear(moveIds); table.clear(movePos)
	local reach = 1.2 * math.max(R.legacyRadius(ss.view), G.pickupProfile(ss.view).magnetRadius) + 60
	local px, py = rt.player.x, rt.player.y
	for _, p in Park.list(rt, 0) do
		local dx, dy = p.x - px, p.y - py
		if dx * dx + dy * dy <= reach * reach then table.insert(moveIds, p.id); table.insert(movePos, fieldToWorld(p.x, p.y)) end
	end
	if #moveIds > 0 then MoveEv:FireClient(plr, moveIds, movePos) end
end

-- where the bird is: Birb map id, Park px, seed platform. A jump faster than the bird can move (teleport) gives no
-- pickups that tick (map -1 = nowhere).
local function locate(plr, ss, dt)
	local rt = ss.rt
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then rt.map = -1; return end
	local p = hrp.Position
	local last = ss.lastPos; ss.lastPos = p
	local maxStep = 100 * G.speed(ss.view) * 1.3 / Map.PX * S * math.max(dt, 1 / 60) * 1.6 + 2
	local jumped = last ~= nil and Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude > maxStep
	local area = areaAt(p)
	local map = if area then AREA_MAP[area] else nil
	if map == nil then map = if ss.lastMap ~= nil then ss.lastMap else -1 end   -- bridges keep the last area
	ss.lastMap = map
	rt.player.x = (p.X / S + Map.COLS / 2) * Map.PX
	rt.player.y = (p.Z / S + Map.ROWS / 2) * Map.PX
	rt.map = if jumped then -1 else map
	rt.onPlatform = map == 1 and platformAt ~= nil and Vector3.new(p.X - platformAt.X, 0, p.Z - platformAt.Z).Magnitude <= PLATFORM_R
end

local acc, pushAcc = 0, 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt; pushAcc += dt
	for plr, ss in sessions do
		local s = ss.view
		locate(plr, ss, dt)
		-- systems at a fixed 20 Hz (Phase 1 + the later simplified systems), at most 8 steps per frame
		ss.acc += dt
		local n = 0
		while ss.acc >= STEP and n < 8 do
			ss.acc -= STEP; n += 1
			for _, t in G.step(s, STEP, ss.rng, ss.rt) do
				if t[1] == "island" then
					local isl = Defs.ISLANDS[t[2]]
					toast(plr, "island", isl.id, isl.name)
				else
					toast(plr, t[1], t[2], t[3])
				end
				ss.fishDirty = ss.fishDirty or t[1] == "fish"
			end
		end
		if ss.acc > STEP then ss.acc = 0 end   -- a long hitch drops the backlog instead of spiralling
		flushEvents(plr, ss)
		if s.fish.active or s.seagull.out then ss.fishDirty = true end
		ss.dirty = true
		-- desert drops (pre-port golden toggle) while the bird stands on the Desert
		local z = zoneAt(plr)
		if z and z ~= s.zone and (z == "park" or G.windowUnlocked(s, "golden")) then
			s.zone = z
			clearDesert(plr, ss)
			toast(plr, "travel", z)
		end
		if G.inDesert(s) and #desertTiles > 0 then
			ss.popT += dt
			local interval = F.spawnInterval(s, true)
			if ss.popT >= interval then
				ss.popT -= interval
				local live = 0; for _ in ss.kernels do live += 1 end
				if live < F.maxCapacity(s) then
					local c = desertTiles[ss.rng:NextInteger(1, #desertTiles)]
					local pos = c + Vector3.new(ss.rng:NextNumber(-0.35, 0.35) * S, 0, ss.rng:NextNumber(-0.35, 0.35) * S)
					local kind = if ss.rng:NextNumber() < G.desertGoldenChance(s) then "golden" else "plain"
					local id = ss.nextId; ss.nextId += 1
					ss.kernels[id] = { pos = pos, kind = kind, golden = kind == "golden" }
					SpawnEv:FireClient(plr, id, pos, kind)
				end
			end
		end
		-- AUTO (group perk): collect the nearest egg every 0.35 s and buy the cheapest affordable upgrade every second
		if s.auto and ss.autoAllowed then
			ss.autoT += dt
			if ss.autoT >= 0.35 then
				ss.autoT = 0
				local rt = ss.rt
				local best, bestD
				for _, p in Park.list(rt, 0) do
					local dx, dy = p.x - rt.player.x, p.y - rt.player.y
					local d = dx * dx + dy * dy
					if not bestD or d < bestD then best, bestD = p.id, d end
				end
				if best then
					local p = Park.take(rt, 0, best)
					if p then Park.award(s, rt, p, "player"); flushEvents(plr, ss) end
				elseif G.inDesert(s) then
					local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					local bid, bd
					for id, k in ss.kernels do
						local d = if hrp then (hrp.Position - k.pos).Magnitude else 0
						if not bd or d < bd then bid, bd = id, d end
					end
					if bid then collectDesert(plr, ss, bid, ss.kernels[bid]) end
				end
			end
			ss.buyT += dt
			if ss.buyT >= 1 then
				ss.buyT = 0
				local pick, pickCost
				for id, d in Defs.UP do
					local w = G.windowRowOf[id]
					local visible = if d.birb then R.rowVisible(s, id) else (w ~= nil and G.windowUnlocked(s, w))
					if w and visible and Defs.level(s, id) < Defs.maxLevel(s, id) then
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
			flushMoves(plr, ss)
			-- desert drops: the old server distance check
			if not G.inDesert(ss.view) then continue end
			local ch = plr.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then continue end
			local reach = G.reachPx(ss.view) / Map.PX * S + 1.2
			local p = hrp.Position
			for id, k in ss.kernels do
				local dx, dz = p.X - k.pos.X, p.Z - k.pos.Z
				if dx * dx + dz * dz < reach * reach then collectDesert(plr, ss, id, k) end
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
	local d = Defs.UP[id]
	if d.birb then
		if not R.rowVisible(ss.view, id) then return end   -- Birb's drawer: SEEDS rows need the Sunflower Machine, ...
	else
		local w = G.windowRowOf[id]
		if w and not G.windowUnlocked(ss.view, w) then return end
	end
	local n = G.buy(ss.view, id, all == true)
	if n > 0 then toast(plr, "bought", id, n) else toast(plr, "poor", id) end
end
function A.molt(plr, ss)
	if not G.windowUnlocked(ss.view, "molt") then return end
	local g = G.molt(ss.view, ss.rt)
	if not g then toast(plr, "poor", "molt"); return end
	flushEvents(plr, ss)
	toast(plr, "molt", EN.short(g), ss.view.rebirbCount == 1)
end
-- a sunflower / desert tree node (Birb purchaseSunflowerUpgrade): only nodes the tree shows, in a view the player has
function A.tree(plr, ss, id)
	local s = ss.view
	if type(id) ~= "string" or not R.Data.SUN_BY_ID[id] or not G.windowUnlocked(s, "trees") then return end
	if string.sub(id, 1, 12) == "d_archivist_" or id == "d_unlock_archivist_tree" then toast(plr, "poor", "tree"); return end   -- Phase 7
	if string.sub(id, 1, 9) == "d_desert_" and not R.hasSun(s, "d_unlock_desert_tree") then return end
	if not R.sunVisible(s, id) then return end
	local why = G.buySun(s, id)
	if why == "" then toast(plr, "tree", id) else toast(plr, "poor", "tree", why) end
end
function A.unlock(plr, ss)
	if G.unlockIsland(ss.view) then toast(plr, "unlocked") else toast(plr, "poor", "unlock") end
end
function A.travel(plr, ss, zone)
	if zone ~= "park" and zone ~= "desert" then return end
	if zone == "desert" and not G.windowUnlocked(ss.view, "golden") then return end
	ss.view.zone = zone
	clearDesert(plr, ss)
	toast(plr, "travel", zone)
end
-- castle feeding (Birb): talk to the monster, then HOLD feeds 10% of each requirement per second (the step does it,
-- only while the bird is at the Castle); a click feeds 1%. op = "hold" | "release" | "click"
function A.feed(plr, ss, op)
	local s = ss.view
	if not G.windowUnlocked(s, "evolve") then return end
	if op == "release" then ss.rt.holdFeed = false; return end
	if ss.rt.map ~= 3 then toast(plr, "poor", "feed_castle"); ss.rt.holdFeed = false; return end
	s.evo.talked = true
	if op == "hold" then ss.rt.holdFeed = true
	elseif op == "click" then
		if (s.evolutionCount or 0) >= 5 or (s.evo.progress or 0) >= 100 then return end
		G.feedClick(s)
	end
end
function A.evolve(plr, ss)
	if not G.windowUnlocked(ss.view, "evolve") then return end
	if G.evolve(ss.view, ss.rt) then
		ss.rt.holdFeed = false
		flushEvents(plr, ss)
		toast(plr, "evolve", ss.view.evolutionCount)
	else toast(plr, "poor", "evolve") end
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
-- Birb's Sparrow panel: FEED (seed feeder, a % of seed income) / DRAIN (resonance) toggles, MITOSIS, REBIRB, autos
function A.sparrow(plr, ss, op, arg)
	local s = ss.view
	local sp = s.sparrow
	if not sp.unlocked or type(op) ~= "string" then return end
	local ok = true
	if op == "feed" or op == "feedall" then
		if not R.hasSun(s, "d_seed_feeder") then ok = false else sp.feeding = not sp.feeding; if sp.feeding then sp.draining = false end end
	elseif op == "drain" then
		if not (R.sparrowFeaturesOn(s) and R.hasSun(s, "d_sparrow_drain_power")) then ok = false else sp.draining = not sp.draining; if sp.draining then sp.feeding = false end end
	elseif op == "stop" then sp.draining = false; sp.feeding = false
	elseif op == "split" or op == "mitosis" then ok = G.mitosis(s)
	elseif op == "rebirb" then ok = G.sparrowRebirb(s)
	elseif op == "auto" or op == "automitosis" then
		if R.sparrowAutoUnlocked(s, "mitosis") then sp.autoMitosis = not sp.autoMitosis else ok = false end
	elseif op == "autorebirb" then
		if R.sparrowAutoUnlocked(s, "rebirb") then sp.autoRebirb = not sp.autoRebirb else ok = false end
	elseif op == "rate" then
		local n = tonumber(arg)
		if not n or n ~= n then return end
		sp.feedRatePercent = math.clamp(math.floor(n), 1, 100)
	else return end
	if not ok then toast(plr, "poor", "sparrow_" .. op) end
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
	clearDesert(plr, ss)
	Park.clearField(ss.rt); table.clear(ss.rt.sparrows); ss.rt.holdFeed = false
	flushEvents(plr, ss)
	ss.fishDirty = true
	toast(plr, "dev", ss.mode, ss.view.island)
end

-- UI preferences the client remembers across sessions (whitelisted keys, plain booleans only)
local PREF_KEYS = { companions = true }
function A.pref(plr, ss, key, value)
	if not PREF_KEYS[key] or type(value) ~= "boolean" then return end
	for _, st in { ss.real, ss.view } do
		st.prefs = st.prefs or {}
		st.prefs[key] = value
	end
	ss.dirty = true
end

-- dev Sound Board picks (dev only): one shared dev DataStore key, applied for every dev through a player attribute
local HttpService = game:GetService("HttpService")
local SFX_KEY = "dev_sfx_picks_v1"
local sfxPicks = nil
local function loadSfxPicks()
	if sfxPicks then return sfxPicks end
	sfxPicks = {}
	if store then
		local ok, data = pcall(function() return store:GetAsync(SFX_KEY) end)
		if ok and type(data) == "table" then sfxPicks = data end
	end
	return sfxPicks
end
function sendSfxPicks(plr)
	local ok, json = pcall(function() return HttpService:JSONEncode(loadSfxPicks()) end)
	if ok then plr:SetAttribute("PeckwoodSfxPicks", json) end
end
function A.sfxpick(plr, ss, event, id)
	if not ss.devAllowed or type(event) ~= "string" or #event > 40 or type(id) ~= "number" or id < 0 or id ~= math.floor(id) then return end
	local picks = loadSfxPicks()
	picks[event] = id
	if store then pcall(function() store:SetAsync(SFX_KEY, picks) end) end
	for _, p2 in Players:GetPlayers() do
		local s2 = sessions[p2]
		if s2 and s2.devAllowed then sendSfxPicks(p2) end
	end
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
	-- rate limit: one action per 50 ms (letting go of a held FEED always goes through, so it can never stick)
	local now = os.clock()
	if not (kind == "feed" and a == "release") then
		if now - ss.lastAct < 0.05 then return end
		ss.lastAct = now
	end
	fn(plr, ss, a, b)
	push(plr)
end)
