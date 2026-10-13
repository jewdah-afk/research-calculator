--!optimize 2
--[[
	Onslaught 2 engine: a 1:1 simulation of Onslaught 2.2 (build 2350-gaby).

	Line-for-line port of onslaught-html/engine.js (same functions, same order of random rolls),
	so the HTML prototype and the Roblox game play the same game. Spec: onslaught-data/MECHANICS.md.

	Pure Luau: no Roblox services, no `script` requires. Runs on the server (authoritative) and in Lune for tests.
	Time is integer milliseconds of game time; Engine.step(G) advances 1 ms.

	JS semantics kept on purpose:
	  * `%` from JS is math.fmod here (sign of the dividend), Math.round is floor(x + 0.5).
	  * arrays are 1-based; the road list is road[1..n] (the original's waypoint_list[1..n]).
]]

local Engine = {}

local floor, abs, sqrt, max, min, fmod, huge = math.floor, math.abs, math.sqrt, math.max, math.min, math.fmod, math.huge
local insert = table.insert

local function jsRound(x: number): number
	return floor(x + 0.5)
end
local function trunc(x: number): number
	return if x >= 0 then floor(x) else -floor(-x)
end
local function split(s: string, sep: string): { string }
	local out = {}
	for part in string.gmatch(s, "([^" .. sep .. "]+)") do
		insert(out, part)
	end
	return out
end
local function copyList(t)
	local o = table.create(#t)
	for i = 1, #t do
		o[i] = t[i]
	end
	return o
end

-- ================================================================ RNG (xorshift32; identical to the JS)
local function rngNew(seed: number)
	local s = (seed or 0) % 4294967296
	if s == 0 then
		s = 0x9e3779b9
	end
	return { s = s }
end
local function rnd(G): number
	local x = G.rng.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	G.rng.s = x
	return x / 4294967296
end

-- ================================================================ math, as the original does it
-- ================================================================ deterministic trig
-- fdlibm kernels with + - * / only, so the JS and Luau engines give the same bits on every platform
-- (math.sin/atan2 differ by an ulp between libms, and the error grows over a game).
local PIO2_1, PIO2_1T, INVPIO2 = 1.57079632673412561417e+00, 6.07710050650619224932e-11, 6.36619772367581382433e-01
local S1, S2, S3 = -1.66666666666666324348e-01, 8.33333333332248946124e-03, -1.98412698298579493134e-04
local S4, S5, S6 = 2.75573137070700676789e-06, -2.50507602534068634195e-08, 1.58969099521155010221e-10
local C1, C2, C3 = 4.16666666666666019037e-02, -1.38888888888741095749e-03, 2.48015872894767294178e-05
local C4, C5, C6 = -2.75573143513906633035e-07, 2.08757232129817482790e-09, -1.13596475577881948265e-11
local function kSin(x: number, y: number): number
	local z = x * x
	local w = z * z
	local r = S2 + z * (S3 + z * S4) + z * w * (S5 + z * S6)
	local v = z * x
	return x - ((z * (0.5 * y - v * r) - y) - v * S1)
end
local function kCos(x: number, y: number): number
	local z = x * x
	local w = z * z
	local r = z * (C1 + z * (C2 + z * C3)) + w * w * (C4 + z * (C5 + z * C6))
	local hz = 0.5 * z
	local q = 1 - hz
	return q + (((1 - q) - hz) + (z * r - x * y))
end
local function trig(x: number, wantCos: boolean): number
	local n = floor(x * INVPIO2 + 0.5)
	local r = x - n * PIO2_1
	local w = n * PIO2_1T
	local y0 = r - w
	local y1 = (r - y0) - w
	local q = (n % 4 + (if wantCos then 1 else 0)) % 4
	if q == 0 then
		return kSin(y0, y1)
	elseif q == 1 then
		return kCos(y0, y1)
	elseif q == 2 then
		return -kSin(y0, y1)
	end
	return -kCos(y0, y1)
end
local function dsin(x: number): number
	return trig(x, false)
end
local function dcos(x: number): number
	return trig(x, true)
end
local ATANHI = { 4.63647609000806093515e-01, 7.85398163397448278999e-01, 9.82793723247329054082e-01, 1.57079632679489655800e+00 }
local ATANLO = { 2.26987774529616870924e-17, 3.06161699786838301793e-17, 1.39033110312309984516e-17, 6.12323399573676603587e-17 }
local AT = {
	3.33333333333329318027e-01, -1.99999999998764832476e-01, 1.42857142725034663711e-01, -1.11111104054623557880e-01,
	9.09088713343650656196e-02, -7.69187620504482999495e-02, 6.66107313738753120669e-02, -5.83357013379057348645e-02,
	4.97687799461593236017e-02, -3.65315727442169155270e-02, 1.62858201153657823623e-02,
}
local function datan(v: number): number
	local neg = v < 0
	local x = if neg then -v else v
	local id
	if x >= 7.378697629483821e19 then
		return if neg then -(ATANHI[4] + ATANLO[4]) else ATANHI[4] + ATANLO[4]
	end
	if x < 0.4375 then
		if x < 7.450580596923828e-9 then
			return v
		end
		id = 0
	elseif x < 1.1875 then
		if x < 0.6875 then
			id = 1
			x = (2 * x - 1) / (2 + x)
		else
			id = 2
			x = (x - 1) / (x + 1)
		end
	elseif x < 2.4375 then
		id = 3
		x = (x - 1.5) / (1 + 1.5 * x)
	else
		id = 4
		x = -1 / x
	end
	local z = x * x
	local w = z * z
	local s1 = z * (AT[1] + w * (AT[3] + w * (AT[5] + w * (AT[7] + w * (AT[9] + w * AT[11])))))
	local s2 = w * (AT[2] + w * (AT[4] + w * (AT[6] + w * (AT[8] + w * AT[10]))))
	if id == 0 then
		return x - x * (s1 + s2)
	end
	local r = ATANHI[id] - ((x * (s1 + s2) - ATANLO[id]) - x)
	return if neg then -r else r
end
local PI, PI_LO = 3.1415926535897931160e+00, 1.2246467991473531772e-16
local function datan2(y: number, x: number): number
	if x == 1 then
		return datan(y)
	end
	if y == 0 then
		return if x >= 0 then 0 else PI
	end
	if x == 0 then
		return if y > 0 then PI / 2 else -PI / 2
	end
	local z = datan(abs(y / x))
	if x > 0 then
		return if y > 0 then z else -z
	end
	return if y > 0 then PI - (z - PI_LO) else (z - PI_LO) - PI
end

local DEG = 57.296
local function degTo(a, b): number
	return datan2(b.y - a.y, b.x - a.x) * DEG
end
local function dist(a, b): number
	local dx, dy = b.x - a.x, b.y - a.y
	return sqrt(dx * dx + dy * dy)
end
local function dist2(a, b): number
	local dx, dy = b.x - a.x, b.y - a.y
	return dx * dx + dy * dy
end
local function wrap180(r: number): number
	r = fmod(r, 360)
	if r > 180 then
		r -= 360
	elseif r <= -180 then
		r += 360
	end
	return r
end
local function qsin(q)
	return if q >= -3.14 and q <= 3.14 then dsin(q) else floor(dsin(q) * 100) / 100
end
local function qcos(q)
	return if q >= -3.14 and q <= 3.14 then dcos(q) else floor(dcos(q) * 100) / 100
end
local function fwd(deg: number, hyp: number)
	local q = floor(deg * 0.0174498255 * 100) / 100
	return { x = qcos(q) * hyp, y = qsin(q) * hyp }
end
local function modStat(added, mult, v)
	return max(0, (v + added) * max(mult, 0.2))
end

-- ================================================================ constants
local TICK = { turret = 70, fusion = 64, combonlyIdle = 1000, manager = 200, spawner = 200, shell = 32, tween = 32,
	frame = 32, mine = 150, hole = 200, walker = 32, napalm = 75 }
local MODES = { "near", "far", "weak", "strong", "slow", "fast", "old", "young" }
local MODE_TITLES = { near = "Nearest", far = "Furthest", weak = "Weakest", strong = "Strongest", slow = "Slowest",
	fast = "Fastest", old = "Oldest", young = "Youngest" }
local MUZZLE = { Blue = 14, Green = 14, Red = 0, Yellow = 0, Sniper = 20, Fusion = 10, Railgun = 12, Targeter = 10, Combonly = 0 }
local COLOURS = { "Red", "Green", "Blue", "Yellow" }
local COLOUR_ORDER = { "Red", "Green", "Blue", "Yellow", "Orange", "Cyan", "Violet" }
local PLAY = { x0 = 18, x1 = 702, y0 = 18, y1 = 462 }
local BUILD_SPACING, BUILD_PROBE, ROAD_HALF = 36, 19, 15.5

local function fx(G, e)
	e.t = G.now
	insert(G.fx, e)
end

-- forward declarations
local attackerAdvance, attackerMove, hit, poison, checkUnlocks, limitReached, gameOver
local modifyUpdate, comboCanFire, comboFire, comboFireNamed, normalFire, linkFire, turretFire
local addShot, newRocket, spawnBlast, laserNow, sparkNow, arrayPick, acquire, walkerAdvance

-- ================================================================ setup
local function addPlayer(G, pid, cash)
	if G.players[pid] then
		return G.players[pid]
	end
	G.players[pid] = { id = pid, cash = cash, kills = 0, spent = 0, earned = 0 }
	insert(G.playerOrder, pid)
	return G.players[pid]
end

function Engine.newGame(D, opts)
	opts = opts or {}
	local mapKey = opts.map or "map1"
	local map = D.maps[mapKey]
	local mode = opts.mode or "medium"
	local ch = opts.challenge
	local diff = if ch then ch.difficulty elseif (mode == "sandbox" or mode == "sandbox2") then "easy" else mode
	local S = D.settings
	local road = {}
	for i, p in map.road do
		road[i] = { x = p.x, y = p.y }
	end
	local mines = {}
	for i = 2, #road do
		local a, b = road[i - 1], road[i]
		local n = floor(dist(a, b) / 4)
		for s = 1, n do
			insert(mines, { x = jsRound(a.x + s / n * (b.x - a.x)), y = jsRound(a.y + s / n * (b.y - a.y)) })
		end
	end
	local hp, hpRate = D.hpRate[diff], {}
	for i = 1, #hp.wave do
		hpRate[hp.wave[i]] = hp.rate[i]
	end
	local G = {
		D = D, rng = rngNew(opts.seed or 1), now = 0, mode = mode, diff = diff, mapKey = mapKey, map = map,
		road = road, mines = mines, challenge = ch,
		lives = opts.lives or S.lives, kills = 0, over = false, won = false, lost = false,
		waveNum = 0, energy = S.attackerEnergy, upRate = 1.125, value = 0, hpRate = hpRate,
		speed = D.speed[diff], waveSpacing = opts.waveSpacing or S.waveSpacing, waveFollow = opts.waveFollow == true,
		waveLast = 0, mgrNext = TICK.manager, waves = {}, noMoreWaves = false,
		waveSizeList = nil, waveSizeCur = 0, speedList = nil, speedCur = 0,
		waveLimit = nil, killTarget = nil, timeLimit = nil, turretLimit = nil, limitHit = false, winNext = nil,
		attackers = {}, turrets = {}, shots = {}, blasts = {}, fx = {},
		players = {}, playerOrder = {}, nextId = 1, unlocked = {}, stats = { shots = 0, combos = 0, spent = 0 },
		mods = opts.mods,
	}
	if ch then
		if ch.objective then
			local p = split(ch.objective, ",")
			if p[1] == "w" then
				G.waveLimit = tonumber(p[2])
			else
				G.killTarget = tonumber(p[2])
			end
		end
		if ch.timelimit then
			G.timeLimit = ch.timelimit * 1000
		end
		if ch.turretlimit then
			G.turretLimit = ch.turretlimit
		end
		local ws = {}
		for _, v in split(tostring(ch.wavesize), ",") do
			insert(ws, tonumber(v))
		end
		if #ws > 1 or ws[1] ~= 10 then
			G.waveSizeList = ws
		end
		local sp = {}
		for _, v in split(tostring(ch.wavespeed), ",") do
			insert(sp, tonumber(v))
		end
		G.speedList = sp
	end
	local startCash = if ch then ch.cash elseif D.startingCash[mode] ~= nil then D.startingCash[mode] else 30
	local pids = if opts.players and #opts.players > 0 then opts.players else { "p1" }
	for _, pid in pids do
		addPlayer(G, pid, startCash + ((opts.bonusCash and opts.bonusCash[pid]) or 0))
	end
	for _, k in D.buildOrder do
		local u = D.turrets[k].unlock
		G.unlocked[k] = (u == nil or u == 0)
	end
	if mode == "sandbox" or mode == "sandbox2" or opts.unlockAll then
		for _, k in D.buildOrder do
			G.unlocked[k] = true
		end
	end
	if G.mods and G.mods.init then
		G.mods.init(G)
	end
	return G
end
Engine.addPlayer = addPlayer

function Engine.removePlayer(G, pid)
	if not G.players[pid] or #G.playerOrder <= 1 then
		return
	end
	local heir
	for _, p in G.playerOrder do
		if p ~= pid then
			heir = p
			break
		end
	end
	for _, t in G.turrets do
		if t.owner == pid then
			t.owner = heir
		end
	end
	G.players[heir].cash += G.players[pid].cash
	G.players[pid] = nil
	local order = {}
	for _, p in G.playerOrder do
		if p ~= pid then
			insert(order, p)
		end
	end
	G.playerOrder = order
end

local function cashWin(G, amount)
	if G.mods and G.mods.bounty then
		amount = G.mods.bounty(G, amount)
	end
	local n = #G.playerOrder
	for _, pid in G.playerOrder do
		local p = G.players[pid]
		p.cash += amount / n
		p.earned += amount / n
	end
end
local function cashSpend(G, pid, amount)
	local p = G.players[pid]
	if not p or p.cash < amount then
		return false
	end
	p.cash -= amount
	p.spent += amount
	G.stats.spent += amount
	return true
end

-- ================================================================ waves
local function waveSend(G)
	if G.over or G.noMoreWaves or G.limitHit then
		return false
	end
	if G.waveLimit ~= nil and G.waveNum >= G.waveLimit then
		limitReached(G, "wave")
		return false
	end
	G.waveNum += 1
	if G.hpRate[G.waveNum] ~= nil then
		G.upRate = G.hpRate[G.waveNum]
	end
	G.value = G.waveNum
	G.energy *= G.upRate
	G.waveLast = G.now
	local size = G.D.settings.waveSize
	if G.waveSizeList then
		size = G.waveSizeList[G.waveSizeCur + 1]
		G.waveSizeCur = fmod(G.waveSizeCur + 1, #G.waveSizeList)
	end
	local bump = 10 / size
	local speed = G.speed
	if G.speedList then
		speed = G.speedList[G.speedCur + 1]
		G.speedCur = fmod(G.speedCur + 1, #G.speedList)
	end
	local energy = G.energy * bump
	if G.mods and G.mods.waveEnergy then
		energy = G.mods.waveEnergy(G, energy)
	end
	insert(G.waves, { num = G.waveNum, size = size, sent = 0, last = 0, next = G.now + TICK.spawner,
		energy = energy, value = jsRound(G.value * bump), speed = speed, scale = bump })
	fx(G, { k = "wave", n = G.waveNum })
	if G.mods and G.mods.waveSent then
		G.mods.waveSent(G)
	end
	return true
end
Engine.waveSend = waveSend

local function updateManager(G)
	if G.timeLimit ~= nil and G.now >= G.timeLimit and not G.limitHit then
		limitReached(G, "time")
		if G.over then
			return
		end
	end
	if G.noMoreWaves then
		return
	end
	if G.now - G.waveLast > G.waveSpacing then
		waveSend(G)
	end
	if #G.attackers == 0 and #G.waves == 0 and G.waveFollow then
		waveSend(G)
	end
end

local function spawnAttacker(G, w)
	local p, j = G.road[1], 19
	local a = { id = G.nextId, type = fmod(w.num - 1, 9), wave = w.num, x = 0, y = 0, wp = 1,
		energy = w.energy, start = w.energy, bounty = w.value, speed = w.speed, speedInit = w.speed, scale = w.scale,
		born = G.now, tw = nil, rep = nil, dead = false, holed = nil, rot = 0 }
	G.nextId += 1
	a.x = p.x + jsRound(rnd(G) * j - j / 2)
	a.y = p.y + jsRound(rnd(G) * j - j / 2)
	insert(G.attackers, a)
	attackerAdvance(G, a)
	return a
end
local function updateSpawner(G, w)
	if G.now - w.last > G.D.settings.attackerSpacing then
		w.last = G.now
		spawnAttacker(G, w)
		w.sent += 1
	end
end

function limitReached(G, why)
	G.noMoreWaves = true
	G.limitHit = true
	if why == "time" then
		local ok = true
		if G.killTarget ~= nil and G.kills < G.killTarget then
			ok = false
		end
		if G.waveLimit ~= nil and G.waveNum < G.waveLimit then
			ok = false
		end
		if not ok then
			gameOver(G, "time")
			return
		end
	end
	G.winNext = G.now + 1000
	fx(G, { k = "limit", why = why })
end
local function winCheck(G)
	local ok = not (G.killTarget ~= nil and G.kills < G.killTarget)
	if #G.attackers > 0 or #G.waves > 0 then
		ok = false
	end
	if ok then
		G.over = true
		G.won = true
		fx(G, { k = "win" })
	else
		G.winNext = G.now + 1000
	end
end
function gameOver(G, why)
	if G.over then
		return
	end
	G.over = true
	G.lost = true
	fx(G, { k = "gameover", why = why })
end

-- ================================================================ attackers
function attackerAdvance(G, a)
	a.wp += 1
	if a.wp > #G.road then
		a.dead = true
		G.lives -= 1
		fx(G, { k = "life", lives = G.lives })
		if G.lives <= 0 then
			gameOver(G, "lives")
		end
		return
	end
	attackerMove(G, a)
end
function attackerMove(G, a)
	local wp = G.road[a.wp]
	local dur = dist(a, wp) / a.speed * 1000
	local j = 19
	local tx = wp.x + jsRound(rnd(G) * j - j / 2)
	local ty = wp.y + jsRound(rnd(G) * j - j / 2)
	a.rot = degTo(a, wp)
	a.tw = { sx = a.x, sy = a.y, tx = tx, ty = ty, t0 = G.now, dur = dur, next = G.now + TICK.tween }
	if a.speed < a.speedInit and not a.rep then
		a.rep = { t0 = G.now, next = G.now + TICK.tween }
	end
end
local function updateAttacker(G, a)
	if a.holed then
		local h = a.holed
		if G.now >= h.next then
			h.next += TICK.tween
			local r = if h.dur > 0 then (G.now - h.t0) / h.dur else 1
			if r >= 1 then
				a.x, a.y = h.tx, h.ty
				a.dead = true
				fx(G, { k = "holed", x = a.x, y = a.y })
				return
			end
			a.x = h.sx + (h.tx - h.sx) * r
			a.y = h.sy + (h.ty - h.sy) * r
		end
		return
	end
	if a.rep and G.now >= a.rep.next then
		a.rep.next += TICK.tween
		if G.now - a.rep.t0 >= 1000 then
			a.rep = nil
			a.speed += 2
			if a.speed >= a.speedInit then
				a.speed = a.speedInit
			end
			attackerMove(G, a)
		end
	end
	local t = a.tw
	if t and G.now >= t.next then
		t.next += TICK.tween
		local r = if t.dur > 0 then (G.now - t.t0) / t.dur else 1
		if r >= 1 then
			a.x, a.y = t.tx, t.ty
			a.tw = nil
			attackerAdvance(G, a)
		else
			a.x = t.sx + (t.tx - t.sx) * r
			a.y = t.sy + (t.ty - t.sy) * r
		end
	end
end

function hit(G, a, dmg, src)
	if not a or a.dead then
		return
	end
	if a.isTurret then
		if a.kind == "Fusion" then
			a.store += dmg * 1.15
		end
		return
	end
	if a.holed then
		return
	end
	a.energy -= dmg
	if a.energy <= 0 then
		a.dead = true
		if src and src.isTurret then
			src.kills += 1
			if G.players[src.owner] then
				G.players[src.owner].kills += 1
			end
		end
		G.kills += 1
		cashWin(G, a.bounty)
		fx(G, { k = "kill", x = a.x, y = a.y, b = a.bounty })
		checkUnlocks(G)
		if G.killTarget ~= nil and G.kills >= G.killTarget and not G.limitHit then
			limitReached(G, "kills")
		end
	end
end
function poison(G, a, p, minus)
	if not a or a.dead then
		return
	end
	if a.isTurret then
		if a.kind == "Fusion" then
			a.storeP += p * 1.15
		end
		return
	end
	if a.holed then
		return
	end
	if minus then
		a.speed -= p
	else
		a.speed /= p
	end
	a.speed = max(a.speed, 5)
	attackerMove(G, a)
end
function checkUnlocks(G)
	for _, k in G.D.buildOrder do
		local u = G.D.turrets[k].unlock
		if u and u ~= 0 and not G.unlocked[k] and G.kills == u then
			G.unlocked[k] = true
			fx(G, { k = "unlock", kind = k })
		end
	end
end
local function alive(o)
	return o ~= nil and not o.dead
end

-- ================================================================ targeting
local function inBox(src, a, r)
	return a.x >= src.x - r and a.x <= src.x + r and a.y >= src.y - r and a.y <= src.y + r
end
local function dirOk(t, a)
	if not t.dir then
		return true
	end
	local d = fmod(t.dir.deg + 360 - (fmod(degTo(t, a) + 720, 360) + 360), 360)
	return abs(d) <= t.dir.spread
end
local function inRange(G, src, a, range)
	if not alive(a) then
		return false
	end
	if not inBox(src, a, range) then
		return false
	end
	if dist(src, a) > range then
		return false
	end
	return dirOk(src, a)
end
function acquire(G, src, range, mode)
	if not MODE_TITLES[mode] then
		mode = "near"
	end
	local lowest = mode == "weak" or mode == "near" or mode == "slow" or mode == "young"
	local best, lo, hi = nil, 1e38, 0
	local r2 = range * range
	for _, a in G.attackers do
		if a.dead or not inBox(src, a, range) or not dirOk(src, a) then
			continue
		end
		local d2 = dist2(src, a)
		if not (d2 < r2) then
			continue
		end
		local v
		if mode == "weak" or mode == "strong" then
			v = a.energy
		elseif mode == "slow" or mode == "fast" then
			v = a.speed
		elseif mode == "near" or mode == "far" then
			v = d2
		else
			v = G.now - a.born
		end
		if lowest then
			if v < lo then
				lo = v
				best = a
			end
		elseif v > hi then
			hi = v
			best = a
		end
	end
	return best
end
local function availOrAcquire(G, cur, src, range, mode)
	if inRange(G, src, cur, range) then
		return cur
	end
	return acquire(G, src, range, mode)
end
local function inBoxList(G, src, r)
	local out = {}
	for _, a in G.attackers do
		if not a.dead and inBox(src, a, r) then
			insert(out, a)
		end
	end
	return out
end
function arrayPick(G, list, qty)
	local n = #list
	if n == qty then
		return copyList(list)
	end
	if qty == 1 then
		return { list[floor(rnd(G) * n) + 1] }
	end
	if qty == 2 then
		local i, j = 0, 0
		while i == j do
			i = floor(rnd(G) * n)
			j = floor(rnd(G) * n)
		end
		return { list[i + 1], list[j + 1] }
	end
	if n <= 2 then
		return copyList(list)
	end
	local l = copyList(list)
	for i = n - 1, 1, -1 do
		local k = floor(rnd(G) * (i + 1))
		l[i + 1], l[k + 1] = l[k + 1], l[i + 1]
	end
	local out = {}
	for i = 1, qty do
		out[i] = l[i]
	end
	return out
end

-- ================================================================ turrets
local function def(G, kind)
	return G.D.turrets[kind]
end
local function upMax(t, s)
	return if t.up[s] then #t.up[s].cost else 0
end
local function upCost(t, s)
	return if t.lvl[s] < upMax(t, s) then t.up[s].cost[t.lvl[s] + 1] else nil
end
local function upPct(t, s)
	local m = upMax(t, s)
	return if m > 0 then floor(t.lvl[s] / m * 100) else 0
end
local function upAmountMax(t, s)
	local m = upMax(t, s)
	return if m > 0 then t.up[s].amount[m] else t.base[s]
end
local function freshMod()
	return { damage_added = 0, range_added = 0, rate_added = 0, poison_added = 0, damage_mult = 1, range_mult = 1, rate_mult = 1, poison_mult = 1 }
end

function modifyUpdate(G, t)
	local m, f = t.mod, t.freakGain
	t.eff.damage = modStat(m.damage_added, m.damage_mult + f.damage, t.base.damage)
	t.eff.range = modStat(m.range_added, m.range_mult + f.range, t.base.range)
	t.eff.rate = modStat(m.rate_added, m.rate_mult + f.rate, t.base.rate)
	t.eff.poison = modStat(m.poison_added, m.poison_mult, t.base.poison)
	if G.mods and G.mods.effective then
		G.mods.effective(G, t)
	end
	t.eff.msec = if t.eff.rate > 0 then 1000 / (t.eff.rate / 60) else huge
end

local function makeTurret(G, kind, x, y, owner)
	local d = def(G, kind)
	local t = {
		id = G.nextId, kind = kind, owner = owner, x = x, y = y, isTurret = true, active = true, dead = false,
		type = d.type, modifiable = d.modifiable ~= false, comboNever = d.comboNever == true,
		lvl = { damage = 0, range = 0, rate = 0 },
		base = { damage = d.damage, range = d.range, rate = d.rate, poison = d.poison or 0 },
		up = d.up, value = d.cost, kills = 0,
		mod = freshMod(), freakGain = { damage = 0, range = 0, rate = 0 },
		eff = { damage = 1, range = 1, rate = 1, poison = 0, msec = 0 },
		rot = 0, rotSpeed = d.rotate, mustFace = d.mustFace ~= false,
		fired = 0, timeLast = G.now,
		next = G.now + (if kind == "Fusion" then TICK.fusion elseif kind == "Combonly" then TICK.combonlyIdle else TICK.turret),
		target = nil, bearTo = nil, bearIgnore = false, modeNum = 0, targetMode = "near", reacquire = false, dir = nil,
		comboCapable = false, comboNext = 0, comboRecharge = 0,
		freakCapable = d.freak == true, freakAvail = false, freakNext = nil, freak = nil,
	}
	G.nextId += 1
	if kind == "Yellow" or kind == "Targeter" then
		t.targetMode = "fast"
		t.modeNum = 5
	end
	if kind == "Targeter" then
		t.reacquire = true
		t.joins = {}
	end
	if kind == "Sniper" then
		t.freakAvail = true -- TurretSniper declares freak_available = true (no stat effect)
	end
	if kind == "Green" then
		t.offered = false
	end
	if kind == "Yellow" then
		t.charge, t.chargeMax, t.chargeRate = 0, 100, 10
	end
	if kind == "Red" then
		t.holdingPattern = false
		t.holding = {}
	end
	if kind == "Fusion" then
		t.store, t.storeP, t.fired, t.feedList = 0, 0, G.now, nil
	end
	if kind == "Combonly" then
		t.combo, t.comboCapable, t.comboNext, t.fired, t.armedAt, t.active = nil, true, G.now, G.now, nil, true
	end
	if d.type == "modifier" then
		t.modify = d.modify
	end
	modifyUpdate(G, t)
	if G.mods and G.mods.turretCreated then
		G.mods.turretCreated(G, t)
	end
	return t
end

local function recalcMods(G)
	for _, t in G.turrets do
		if not t.modifiable then
			continue
		end
		local m = freshMod()
		for _, s in G.turrets do
			if s.type ~= "modifier" or s == t or not s.active then
				continue
			end
			if dist(s, t) > s.base.range then
				continue
			end
			m.damage_added += s.modify.damage
			m.range_added += s.modify.range
			m.rate_added += s.modify.rate
			m.damage_mult += s.modify.damage_mult
			m.range_mult += s.modify.range_mult
			m.rate_mult += s.modify.rate_mult
		end
		if G.mods and G.mods.auras then
			G.mods.auras(G, t, m)
		end
		local o = t.mod
		if o.damage_added ~= m.damage_added or o.range_added ~= m.range_added or o.rate_added ~= m.rate_added
			or o.damage_mult ~= m.damage_mult or o.range_mult ~= m.range_mult or o.rate_mult ~= m.rate_mult
			or o.poison_added ~= m.poison_added or o.poison_mult ~= m.poison_mult then
			t.mod = m
			modifyUpdate(G, t)
		end
	end
end

local function onRoad(G, x, y)
	local r = G.road
	for i = 2, #r do
		local a, b = r[i - 1], r[i]
		local dx, dy = b.x - a.x, b.y - a.y
		local l2 = dx * dx + dy * dy
		local k = if l2 ~= 0 then ((x - a.x) * dx + (y - a.y) * dy) / l2 else 0
		k = max(0, min(1, k))
		local ex, ey = x - (a.x + k * dx), y - (a.y + k * dy)
		if ex * ex + ey * ey <= ROAD_HALF * ROAD_HALF then
			return true
		end
	end
	return false
end
local S45 = dsin(45 * 0.017453117987018096) * BUILD_PROBE
local C45 = dcos(45 * 0.017453117987018096) * BUILD_PROBE
local PROBES = { { 0, BUILD_PROBE }, { 0, -BUILD_PROBE }, { BUILD_PROBE, 0 }, { -BUILD_PROBE, 0 }, { S45, C45 }, { S45, -C45 }, { -S45, C45 }, { -S45, -C45 } }
local function canBuildAt(G, kind, x, y, ignore)
	if x < PLAY.x0 or x > PLAY.x1 or y < PLAY.y0 or y > PLAY.y1 then
		return false
	end
	if G.turretLimit ~= nil and #G.turrets >= G.turretLimit then
		return false
	end
	local p = { x = x, y = y }
	for _, t in G.turrets do
		if t ~= ignore and dist(t, p) < BUILD_SPACING then
			return false
		end
	end
	for _, pr in PROBES do
		if onRoad(G, x + pr[1], y + pr[2]) then
			return false
		end
	end
	return true
end
local function turretCost(G, pid, kind)
	local c = def(G, kind).cost
	return if G.mods and G.mods.cost then G.mods.cost(G, pid, kind, c) else c
end

-- ---------------------------------------------------------------- aiming and firing
local function bearTowards(G, t, target, dt)
	local want = degTo(t, target)
	local step = dt / 1000 * t.rotSpeed
	local diff = want + 360 - (t.rot + 360)
	if abs(diff) < 1 or abs(diff) < abs(step) then
		t.rot = wrap180(want)
		if t.bearIgnore then
			t.bearTo = nil
		end
		return true
	end
	local a, b = fmod(diff + 360, 360), fmod(360 - diff, 360)
	t.rot = wrap180(if b < a then t.rot - step else t.rot + step)
	return false
end
local function canFire(G, t)
	return not (G.now - t.fired <= t.eff.msec)
end
local function muzzle(t)
	local m = MUZZLE[t.kind] or 0
	local f = fwd(t.rot, m)
	return { x = t.x + f.x, y = t.y + f.y }
end

function turretFire(G, t, target, dmg, poisonOverride)
	t.fired = G.now
	G.stats.shots += 1
	local m = muzzle(t)
	local p = if poisonOverride ~= nil then poisonOverride else t.eff.poison
	local shot = nil
	local k = t.kind
	if k == "Blue" then
		shot = addShot(G, { k = "shell", x = m.x, y = m.y, target = target, dmg = dmg, speed = 900, src = t, tier = t.lvl.damage })
	elseif k == "Red" then
		local hc = t.holdingRound == true or t.holdingPattern == true
		shot = newRocket(G, m.x, m.y, t.rot, target, dmg, t, { holdingCapable = hc, holdingInitially = t.holdingRound == true, tier = t.lvl.damage })
	elseif k == "Green" then
		laserNow(G, m, target, dmg, t)
	elseif k == "Yellow" or k == "Fusion" then
		sparkNow(G, m, target, dmg, p, t, if k == "Fusion" then "fusion" else nil)
	elseif k == "Sniper" then
		if alive(target) then
			hit(G, target, dmg, t)
			fx(G, { k = "sniper", x1 = m.x, y1 = m.y, x2 = target.x, y2 = target.y })
		end
	elseif k == "Railgun" then
		if alive(target) then
			local d = dist(t, target)
			if d == 0 then
				d = 1
			end
			local sc = 900 / d
			local x2, y2 = t.x + (target.x - t.x) * sc, t.y + (target.y - t.y) * sc
			addShot(G, { k = "rail", next = G.now + 32, x1 = t.x, y1 = t.y, x2 = x2, y2 = y2, dmg = dmg, src = t })
			fx(G, { k = "rail", x1 = t.x, y1 = t.y, x2 = x2, y2 = y2, dmg = dmg })
		end
	elseif G.mods and G.mods.fire then
		shot = G.mods.fire(G, t, target, dmg, p)
	end
	if t.reacquire then
		t.target = nil
	end
	return shot
end
function laserNow(G, from, target, dmg, src)
	if not alive(target) then
		return
	end
	fx(G, { k = "laser", x1 = from.x, y1 = from.y, x2 = target.x, y2 = target.y, dmg = dmg })
	hit(G, target, dmg, src)
end
function sparkNow(G, from, target, dmg, p, src, look, blast)
	if not alive(target) then
		return
	end
	fx(G, { k = "spark", x1 = from.x, y1 = from.y, x2 = target.x, y2 = target.y, dmg = dmg, look = look })
	if blast then
		spawnBlast(G, blast.type, target.x, target.y, blast.dmg, blast.poison, src, { target = target, angle = 0 })
	end
	poison(G, target, p, true)
	hit(G, target, dmg, src)
end

-- ---------------------------------------------------------------- per-kind updates
local function freakoutNow(G, t)
	if t.freakAvail then
		t.freakNext = G.now + 80000 / 2 + rnd(G) * 40000 - t.lvl.rate * 4 * 1000
	end
	t.freak = { stage = 0, timer = 0, next = G.now + TICK.frame }
end
local function updateFreak(G, t)
	local f = t.freak
	if not f or G.now < f.next then
		return
	end
	f.next += TICK.frame
	if f.stage == 0 then
		f.timer = G.now
		f.stage = 1
		fx(G, { k = "freakwarn", id = t.id })
	elseif f.stage == 1 then
		if G.now - f.timer > 3000 then
			f.stage = 2
		end
	elseif f.stage == 2 then
		if t.modifiable then
			t.freakGain.damage += 3
			t.freakGain.rate += 4
			modifyUpdate(G, t)
		end
		f.timer = G.now
		f.stage = 3
		fx(G, { k = "freak", id = t.id })
	elseif f.stage == 3 then
		if G.now - f.timer > 5000 then
			f.stage = 4
		end
	elseif f.stage == 4 then
		if t.modifiable then
			t.freakGain.damage -= 3
			t.freakGain.rate -= 4
			modifyUpdate(G, t)
		end
		t.freak = nil
	end
end
local function freakCheck(G, t)
	if t.freakAvail and (t.freakNext == nil or G.now >= t.freakNext) then
		freakoutNow(G, t)
	end
end
local function chargeAccumulate(t, dt)
	if t.charge >= t.chargeMax then
		return
	end
	t.charge = max(t.charge, 0)
	t.charge = min(t.charge + t.chargeRate * (dt / 1000), t.chargeMax)
end
local function chargeFire(G, t, target)
	local c = t.charge / 100
	local p = modStat(t.mod.poison_added + c * 3, t.mod.poison_mult, t.base.poison)
	local shot = turretFire(G, t, target, t.eff.damage, p)
	t.charge = max(t.charge - 50, 0)
	return shot
end
local function fusionFire(G, t, target)
	local e = t.eff.damage
	local add = min(e, t.store)
	local p = min(100, t.storeP)
	turretFire(G, t, target, add + e, p)
	t.store -= add
	t.storeP -= p
end

local function tryFiring(G, t, target, dt)
	if not alive(target) then
		return true
	end
	if bearTowards(G, t, target, dt) ~= true and t.mustFace then
		return false
	end
	if canFire(G, t) then
		if comboCanFire(G, t) then
			comboFire(G, t, target)
		else
			normalFire(G, t, target)
		end
	end
	return true
end
function normalFire(G, t, target)
	if t.kind == "Green" then
		return linkFire(G, t, target, t.eff.damage, true)
	end
	if t.kind == "Yellow" and t.charge > 0 then
		return chargeFire(G, t, target)
	end
	if t.kind == "Fusion" then
		return fusionFire(G, t, target)
	end
	return turretFire(G, t, target, t.eff.damage)
end
function linkFire(G, t, target, dmg, lead)
	local inRangeGreens = {}
	for _, o in G.turrets do
		if o ~= t and o.kind == "Green" and o.active and dist(t, o) <= t.eff.range then
			insert(inRangeGreens, o)
		end
	end
	if #inRangeGreens == 0 then
		if t.kind == "Green" then
			turretFire(G, t, target, dmg)
		end
		return dmg
	end
	t.offered = false
	local total = t.eff.damage
	local offered = {}
	for _, o in inRangeGreens do
		if o.offered then
			o.offered = false
			insert(offered, o)
		end
	end
	if #offered == 0 then
		if t.kind == "Green" then
			turretFire(G, t, target, total)
		end
		return total
	end
	for _, o in offered do
		o.rot = wrap180(degTo(o, t))
		total += linkFire(G, o, t, 0, false) * G.D.settings.linkMult
	end
	if t.kind == "Green" then
		turretFire(G, t, target, total)
	end
	return total
end

local function updateStandard(G, t, dt)
	freakCheck(G, t)
	if t.kind == "Yellow" then
		chargeAccumulate(t, dt)
	end
	t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode)
	if alive(t.target) then
		t.bearTo = nil
		tryFiring(G, t, t.target, dt)
	elseif alive(t.bearTo) then
		bearTowards(G, t, t.bearTo, dt)
	end
end
local function updateGreen(G, t, dt)
	t.offered = canFire(G, t)
	t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode)
	if alive(t.target) then
		t.bearTo = nil
		tryFiring(G, t, t.target, dt)
	elseif alive(t.bearTo) then
		bearTowards(G, t, t.bearTo, dt)
	end
end
local function updateRed(G, t, dt)
	t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode)
	if alive(t.target) then
		tryFiring(G, t, t.target, dt)
		for _, r in t.holding do
			if not r.dead then
				r.target = t.target
				r.holdingInitially = false
			end
		end
		t.holding = {}
	elseif alive(t.bearTo) then
		bearTowards(G, t, t.bearTo, dt)
	end
	if t.holdingPattern and canFire(G, t) then
		local n = 0
		for _, r in t.holding do
			if not r.dead then
				n += 1
			end
		end
		if n < 4 then
			t.holdingRound = true
			local r = turretFire(G, t, nil, t.eff.damage)
			t.holdingRound = false
			if r then
				insert(t.holding, r)
			end
		end
	end
end
local function updateFusion(G, t, dt)
	local feeders = {}
	for _, o in G.turrets do
		if o ~= t and o.active and (o.kind == "Green" or o.kind == "Yellow") and dist(t, o) <= t.eff.range then
			insert(feeders, o)
		end
	end
	if not t.feedList then
		t.feedList = arrayPick(G, feeders, #feeders)
	end
	local fed = false
	for _, o in t.feedList do
		if fed then
			break
		end
		if not o.dead and o.active and canFire(G, o) then
			turretFire(G, o, t, o.eff.damage)
			fed = true
		end
	end
	if not fed then
		t.feedList = nil
	end
	t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode)
	if alive(t.target) then
		if bearTowards(G, t, t.target, dt) ~= true and t.mustFace then
			return true
		end
		if G.now - t.fired > 6000 then
			tryFiring(G, t, t.target, dt)
		end
	elseif alive(t.bearTo) then
		bearTowards(G, t, t.bearTo, dt)
	end
	return false
end
local function updateTargeter(G, t, dt)
	t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode)
	if alive(t.target) then
		if bearTowards(G, t, t.target, dt) then
			fx(G, { k = "paint", x1 = t.x, y1 = t.y, x2 = t.target.x, y2 = t.target.y })
			if canFire(G, t) then
				t.fired = G.now
				local tg = t.target
				for _, o in t.joins do
					if not o.dead and o.active then
						tryFiring(G, o, tg, G.now - o.timeLast)
						if alive(tg) then
							o.bearTo = tg
							o.bearIgnore = false
						end
					end
				end
				if t.reacquire then
					t.target = nil
				end
			end
		end
	else
		t.rot = wrap180(t.rot + dt / 1000 * 90)
	end
end
local function updateCombonly(G, t, dt)
	if not t.combo then
		return
	end
	if t.armedAt ~= nil and G.now < t.armedAt then
		return
	end
	t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode)
	if alive(t.target) then
		t.bearTo = nil
		if bearTowards(G, t, t.target, dt) and comboCanFire(G, t) then
			comboFireNamed(G, t, t.combo, nil, t.target, true)
		end
	elseif alive(t.bearTo) then
		bearTowards(G, t, t.bearTo, dt)
	end
end
local function updateTurret(G, t)
	local dt = G.now - t.timeLast
	local keepTime = false
	if dt > 0 and t.active then
		local ty = t.type
		if ty == "modifier" then
			-- static
		elseif ty == "targeter" then
			updateTargeter(G, t, dt)
		elseif ty == "combonly" then
			updateCombonly(G, t, dt)
		elseif t.kind == "Green" then
			updateGreen(G, t, dt)
		elseif t.kind == "Red" then
			updateRed(G, t, dt)
		elseif t.kind == "Fusion" then
			keepTime = updateFusion(G, t, dt)
		elseif G.mods and G.mods.update and G.mods.update(G, t, dt) then
			-- expansion turret
		else
			updateStandard(G, t, dt)
		end
	end
	if not keepTime then
		t.timeLast = G.now
	end
end

-- ================================================================ combos
function comboCanFire(G, t)
	if not t.active or not t.comboCapable then
		return false
	end
	if G.now - t.fired < t.eff.msec then
		return false
	end
	return G.now >= t.comboNext
end
local function countColours(G, t, regardless)
	local c = { Red = {}, Green = {}, Blue = {}, Yellow = {} }
	if G.D.extraColours then
		for _, k in G.D.extraColours do
			c[k] = {}
		end
	end
	for _, o in G.turrets do
		if o == t or o.comboNever or not o.active or not c[o.kind] then
			continue
		end
		if dist(o, t) > G.D.settings.comboRange then
			continue
		end
		if (if regardless then o.comboCapable else comboCanFire(G, o)) then
			insert(c[o.kind], o)
		end
	end
	return c
end
local function counts(c)
	local n = {}
	for k, v in c do
		n[k] = #v
	end
	return n
end
local RULES = {
	Red = {
		{ function(c) return c.Blue >= 2 end, "nuke" },
		{ function(c) return c.Red >= 1 and c.Yellow >= 1 and c.Blue >= 1 end, "napalm" },
		{ function(c) return c.Blue >= 1 and c.Green >= 1 end, "poison_rocket" },
		{ function(c) return c.Yellow >= 1 end, "tazer_rocket" },
		{ function(c) return c.Green >= 1 end, "laser_rocket" },
	},
	Green = {
		{ function(c) return c.Red >= 2 and c.Blue >= 1 end, "rocket_bfg" },
		{ function(c) return c.Red >= 1 and c.Blue >= 1 end, "bfg" },
	},
	Blue = {
		{ function(c) return c.Red >= 2 and c.Green >= 1 and c.Blue >= 1 end, "big_laser_cluster_landmine" },
		{ function(c) return c.Red >= 2 and c.Blue >= 1 end, "big_cluster_landmine" },
		{ function(c) return c.Red >= 2 and c.Green >= 1 end, "big_laser_clusterbomb" },
		{ function(c) return c.Red >= 2 end, "big_clusterbomb" },
		{ function(c) return c.Blue >= 1 and c.Yellow >= 1 end, "sparky_landmine" },
		{ function(c) return c.Red >= 1 and c.Yellow >= 1 end, "sparky_clusterbomb" },
		{ function(c) return c.Red >= 1 and c.Green >= 1 end, "laser_clusterbomb" },
		{ function(c) return c.Red >= 1 and c.Blue >= 1 end, "big_landmine" },
		{ function(c) return c.Red >= 1 end, "clusterbomb" },
		{ function(c) return c.Blue >= 1 end, "landmine" },
	},
	Yellow = {
		{ function(c) return c.Yellow >= 2 and c.Green == 1 end, "blackhole" },
		{ function(c) return c.Yellow >= 1 and c.Blue == 1 and c.Green == 1 end, "shockwave" },
		{ function(c) return c.Red >= 1 and c.Blue == 1 end, "tazer_bfg" },
	},
}
local COMBONLY = {
	{ function(c) return c.Blue >= 2 end, "Blue", "landmine", { Blue = 2 } },
	{ function(c) return c.Red >= 1 and c.Blue >= 1 end, "Blue", "clusterbomb", { Blue = 1, Red = 1 } },
	{ function(c) return c.Green >= 1 and c.Red >= 1 end, "Red", "laser_rocket", { Green = 1, Red = 1 } },
	{ function(c) return c.Yellow >= 1 and c.Red >= 1 end, "Red", "tazer_rocket", { Yellow = 1, Red = 1 } },
	{ function(c) return c.Red >= 1 and c.Blue >= 2 end, "Blue", "big_landmine", { Blue = 2, Red = 1 } },
	{ function(c) return c.Blue >= 2 and c.Yellow >= 1 end, "Blue", "sparky_landmine", { Blue = 2, Yellow = 1 } },
	{ function(c) return c.Red >= 2 and c.Blue >= 1 end, "Blue", "big_clusterbomb", { Red = 2, Blue = 1 } },
	{ function(c) return c.Blue >= 2 and c.Red >= 1 end, "Red", "nuke", { Blue = 2, Red = 1 } },
	{ function(c) return c.Yellow >= 3 and c.Green >= 1 end, "Yellow", "blackhole", { Yellow = 3, Green = 1 } },
	{ function(c) return c.Red >= 1 and c.Green >= 1 and c.Blue >= 1 end, "Blue", "laser_clusterbomb", { Red = 1, Green = 1, Blue = 1 } },
	{ function(c) return c.Red >= 1 and c.Blue >= 1 and c.Yellow >= 1 end, "Yellow", "tazer_bfg", { Red = 1, Yellow = 1, Blue = 1 } },
	{ function(c) return c.Red >= 1 and c.Blue >= 1 and c.Green >= 1 end, "Green", "bfg", { Red = 1, Green = 1, Blue = 1 } },
	{ function(c) return c.Blue >= 1 and c.Green >= 1 and c.Red >= 1 end, "Red", "poison_rocket", { Red = 1, Green = 1, Blue = 1 } },
	{ function(c) return c.Red >= 1 and c.Yellow >= 1 and c.Blue >= 1 end, "Blue", "sparky_clusterbomb", { Red = 1, Yellow = 1, Blue = 1 } },
	{ function(c) return c.Yellow >= 2 and c.Blue >= 1 and c.Green >= 1 end, "Yellow", "shockwave", { Yellow = 2, Green = 1, Blue = 1 } },
	{ function(c) return c.Red >= 2 and c.Blue >= 1 and c.Green >= 1 end, "Blue", "big_laser_clusterbomb", { Red = 2, Green = 1, Blue = 1 } },
	{ function(c) return c.Red >= 2 and c.Blue >= 1 and c.Green >= 1 end, "Green", "rocket_bfg", { Red = 2, Green = 1, Blue = 1 } },
	{ function(c) return c.Red >= 2 and c.Blue >= 1 and c.Yellow >= 1 end, "Red", "napalm", { Red = 2, Yellow = 1, Blue = 1 } },
	{ function(c) return c.Red >= 2 and c.Blue >= 2 end, "Blue", "big_cluster_landmine", { Red = 2, Blue = 2 } },
	{ function(c) return c.Red >= 2 and c.Blue >= 2 and c.Green >= 1 end, "Blue", "big_laser_cluster_landmine", { Red = 2, Blue = 2, Green = 1 } },
}
local TAKES = {
	clusterbomb = { Red = 1 }, sparky_clusterbomb = { Red = 1, Yellow = 1 }, big_clusterbomb = { Red = 2 },
	big_sparky_clusterbomb = { Red = 2, Yellow = 1 }, laser_clusterbomb = { Red = 1 }, big_laser_clusterbomb = { Red = 2 },
	landmine = { Blue = 1 }, big_landmine = { Red = 1, Blue = 1 }, sparky_landmine = { Red = 1, Blue = 1, Yellow = 1 },
	big_cluster_landmine = { Red = 2, Blue = 1 }, big_laser_cluster_landmine = { Red = 2, Blue = 1, Green = 1 },
	bfg = { Red = 1, Blue = 1 }, tazer_bfg = { Red = 1, Blue = 1 }, rocket_bfg = { Red = 1, Blue = 1 }, laser_rocket = {},
	tazer_rocket = {}, poison_rocket = { Green = 1, Blue = 1 }, nuke = { Blue = 2 }, blackhole = { Yellow = 2, Green = 1 },
	shockwave = { Yellow = 1, Blue = 1 }, napalm = { Yellow = 1, Blue = 1, Red = 1 },
}
local TAKE_ORDER = {
	sparky_clusterbomb = { "Red", "Yellow" }, big_sparky_clusterbomb = { "Red", "Yellow" }, big_landmine = { "Red", "Blue" },
	sparky_landmine = { "Red", "Blue", "Yellow" }, big_cluster_landmine = { "Red", "Blue" },
	big_laser_cluster_landmine = { "Red", "Blue", "Green" }, bfg = { "Red", "Blue" }, tazer_bfg = { "Red", "Blue" },
	rocket_bfg = { "Red", "Blue" }, poison_rocket = { "Green", "Blue" }, blackhole = { "Yellow", "Green" },
	shockwave = { "Yellow", "Blue" }, napalm = { "Yellow", "Blue", "Red" },
}

function comboFire(G, t, target)
	local c = countColours(G, t, false)
	local n = counts(c)
	local rules = RULES[t.kind] or (G.mods and G.mods.rules and G.mods.rules[t.kind]) or {}
	for _, r in rules do
		if r[1](n) then
			return comboFireNamed(G, t, r[2], c, target, false)
		end
	end
	return normalFire(G, t, target)
end
local function comboTake(G, lead, list)
	for _, o in list do
		if not o then
			continue
		end
		o.comboNext = G.now + lead.comboRecharge - 1
		o.bearTo = lead
		o.bearIgnore = true
		fx(G, { k = "take", x1 = o.x, y1 = o.y, x2 = lead.x, y2 = lead.y })
	end
end
local function takeColour(G, lead, list, qty)
	if list and #list > 0 then
		comboTake(G, lead, if qty == 2 then arrayPick(G, list, 2) else arrayPick(G, list, 1))
	end
end
local function takeLink(G, lead, greens, silent)
	if silent or not greens or #greens == 0 then
		return 0
	end
	local g = arrayPick(G, greens, 1)[1]
	if not g or g.dead then
		return 0
	end
	local d = linkFire(G, g, lead, 0, false)
	d += g.eff.damage
	g.rot = wrap180(degTo(g, lead))
	comboTake(G, lead, { g })
	return d
end
local function takePoison(G, lead, yellows, silent)
	if silent or not yellows or #yellows == 0 then
		return 20
	end
	local y = arrayPick(G, yellows, 1)[1]
	if not y then
		return 20
	end
	local p = y.eff.poison
	comboTake(G, lead, { y })
	return p
end

local CLUSTER_BLAST = { clusterbomb = "small", sparky_clusterbomb = "small", big_clusterbomb = "large",
	big_sparky_clusterbomb = "large", laser_clusterbomb = "medium", big_laser_clusterbomb = "large" }

function comboFireNamed(G, t, name, c, target, silent)
	local C = G.D.combos[name]
	local cm = if G.mods and G.mods.comboDamage then G.mods.comboDamage(G, t, name) else 1
	local function md(v)
		return modStat(t.mod.damage_added, t.mod.damage_mult + t.freakGain.damage, v) * cm
	end
	t.comboRecharge = C.recharge * (if G.mods and G.mods.rechargeMult then G.mods.rechargeMult(G, t, name) else 1)
	G.stats.combos += 1
	t.comboNext = G.now + t.comboRecharge
	t.fired = G.now
	fx(G, { k = "combo", name = name, x = t.x, y = t.y, id = t.id })
	local function take()
		if silent then
			return
		end
		local needs = TAKES[name] or (G.D.combos[name] and G.D.combos[name].needs) or {}
		local order = TAKE_ORDER[name]
		if not order then
			order = {}
			for _, k in COLOUR_ORDER do
				if needs[k] then
					insert(order, k)
				end
			end
		end
		for _, col in order do
			takeColour(G, t, c[col], needs[col])
		end
	end
	local m = muzzle(t)
	local link, p = 0, 20
	if G.mods and G.mods.comboStart then
		G.mods.comboStart(G, t, name)
	end
	if CLUSTER_BLAST[name] then
		local laser = string.find(name, "laser", 1, true) ~= nil
		local sparky = string.find(name, "sparky", 1, true) ~= nil
		if laser then
			link = takeLink(G, t, c and c.Green, silent)
		end
		addShot(G, { x = m.x, y = m.y, rot = t.rot, target = target, src = t, k = "bomb", dmg = md(C.bullet_damage), speed = 750,
			next = G.now + TICK.frame, timeLast = G.now,
			blast = { type = CLUSTER_BLAST[name], dmg = md(C.blast_damage), poison = 1 },
			cluster = { type = if sparky then "spark" else "blast", qty = C.cluster_qty, dmg = md(C.cluster_damage),
				holding = C.cluster_holding ~= false, laser = laser,
				laserDmg = if laser then md(link + C.cluster_laser_damage) else 1e6 } })
		take()
	elseif name == "landmine" or name == "big_landmine" or name == "sparky_landmine" or name == "big_cluster_landmine"
		or name == "big_laser_cluster_landmine" then
		if not t.minePts then
			local maxR = upAmountMax(t, "range")
			t.minePts = {}
			for _, q in G.mines do
				if dist(t, q) <= maxR then
					insert(t.minePts, { x = q.x, y = q.y })
				end
			end
		end
		local spot = if #t.minePts > 0 then arrayPick(G, t.minePts, 1)[1] else nil
		local blastType = if (name == "landmine" or name == "sparky_landmine") then "small" else "large"
		local cluster = nil
		if name == "sparky_landmine" then
			cluster = { type = "spark", qty = C.cluster_qty, dmg = 1e6, holding = true, laser = false, laserDmg = 1e6 }
		elseif name == "big_cluster_landmine" then
			cluster = { type = "blast", qty = C.cluster_qty, dmg = md(C.cluster_damage), holding = C.cluster_holding ~= false, laser = false, laserDmg = 1e6 }
		elseif name == "big_laser_cluster_landmine" then
			cluster = { type = "blast", qty = C.cluster_qty, dmg = md(C.cluster_damage), holding = C.cluster_holding ~= false, laser = true, laserDmg = md(C.cluster_laser_damage) }
		end
		if spot then
			spot.x += floor(rnd(G) * 10 - 5)
			spot.y += floor(rnd(G) * 10 - 5)
			addShot(G, { k = "mine", x = t.x, y = t.y, sx = t.x, sy = t.y, tx = spot.x, ty = spot.y, t0 = G.now, planted = false,
				twNext = G.now + TICK.tween, next = G.now + TICK.mine, target = target, src = t, big = blastType == "large",
				blast = { type = blastType, dmg = md(C.blast_damage), poison = 1 }, cluster = cluster })
		end
		take()
	elseif name == "bfg" or name == "tazer_bfg" or name == "rocket_bfg" then
		if name ~= "tazer_bfg" then
			link = linkFire(G, t, t, 0, true)
		end
		local tz = name == "tazer_bfg"
		local tp = 20
		if tz then
			tp = trunc(t.eff.poison)
			if tp <= 0 then
				tp = 20
			end
		end
		newRocket(G, m.x, m.y, t.rot, target, md(C.bullet_damage + link), t, {
			variant = if tz then "bfgtazer" else "bfg", speed = C.move_speed, noRotate = true, holdingCapable = true,
			offRemove = true, offLock = true, impact = 10,
			blast = { type = "bfg", dmg = md(C.blast_damage + link), poison = 1 },
			laser = { dmg = md(C.laser_damage + link), range = C.laser_range, rate = C.laser_rate, spark = tz, poison = tp },
			rocketGun = if name == "rocket_bfg" then { dmg = md(C.rocket_damage + link), rate = 120 } else nil })
		take()
	elseif name == "laser_rocket" then
		link = takeLink(G, t, c and c.Green, silent)
		newRocket(G, m.x, m.y, t.rot, target, md(link + C.bullet_damage), t, { variant = "laserrocket", speed = C.move_speed,
			holdingCapable = true, laser = { dmg = md(link + C.laser_damage), range = C.laser_range, rate = 120, spark = false, poison = 1 } })
	elseif name == "tazer_rocket" then
		p = takePoison(G, t, c and c.Yellow, silent)
		newRocket(G, m.x, m.y, t.rot, target, md(C.bullet_damage), t, { variant = "tazerrocket", speed = C.move_speed,
			holdingCapable = true, laser = { dmg = md(C.laser_damage), range = C.laser_range, rate = 120, spark = true, poison = p } })
	elseif name == "poison_rocket" then
		newRocket(G, m.x, m.y, t.rot, target, md(C.bullet_damage), t, { variant = "poison", speed = C.move_speed, holdingCapable = true,
			blast = { type = "poison", dmg = C.blast_damage, poison = 2 } })
		take()
	elseif name == "nuke" then
		newRocket(G, m.x, m.y, t.rot, target, md(C.bullet_damage), t, { variant = "nuke", speed = C.move_speed, holdingCapable = true,
			blast = { type = "huge", dmg = md(C.blast_damage), poison = 1 } })
		take()
	elseif name == "napalm" then
		newRocket(G, m.x, m.y, t.rot, target, t.eff.damage, t, { variant = "napalm",
			napalm = { qty = C.napalm_quantity, timing = C.napalm_timing, jit = C.napalm_jit } })
		take()
	elseif name == "blackhole" then
		if not t.holePts then
			t.holePts = {}
			for _, q in G.mines do
				if dist(t, q) <= 90 then
					insert(t.holePts, { x = q.x, y = q.y })
				end
			end
		end
		local pts = t.holePts
		if #pts > 0 then
			local spot = arrayPick(G, pts, 1)[1]
			addShot(G, { k = "hole", x = spot.x, y = spot.y, r = C.blackhole_radius, dur = C.blackhole_duration, t0 = G.now,
				open = false, openAt = G.now + 224, next = G.now + 224, closing = false, src = t })
		end
		take()
	elseif name == "shockwave" then
		link = takeLink(G, t, c and c.Green, silent)
		sparkNow(G, m, target, md(link + C.bullet_damage), C.bullet_poison, t, "shock",
			{ type = "shockwave", dmg = md(link + C.blast_damage), poison = C.blast_poison })
		take()
	elseif G.mods and G.mods.comboFire then
		G.mods.comboFire(G, t, name, c, target, silent, { md = md, take = take, m = m, link = function()
			return takeLink(G, t, c and c.Green, silent)
		end })
	end
end

-- ================================================================ projectiles
function addShot(G, s)
	s.id = G.nextId
	G.nextId += 1
	s.dead = false
	insert(G.shots, s)
	return s
end
function newRocket(G, x, y, rot, target, dmg, src, o)
	o = o or {}
	local dir = if rnd(G) >= 0.5 then -1 else 1
	local period = floor(32 + rnd(G) * 10)
	local r = { k = "rocket", x = x, y = y, rot = rot, target = target, dmg = dmg, src = src, speed = o.speed or 250, turn = 270,
		impact = o.impact or 8, holdingCapable = o.holdingCapable == true, holdingInitially = o.holdingInitially == true,
		holdDir = dir, noRotate = o.noRotate == true, offRemove = o.offRemove == true, offLock = o.offLock == true,
		blast = o.blast, cluster = o.cluster, napalm = o.napalm, laser = nil, rocketGun = nil,
		variant = o.variant or "rocket", tier = o.tier or 0, period = period, next = G.now + period, timeLast = G.now }
	if o.laser then
		r.laser = { dmg = o.laser.dmg, r2 = o.laser.range * o.laser.range, msec = 1000 / (o.laser.rate / 60), fired = G.now,
			spark = o.laser.spark, poison = o.laser.poison }
	end
	if o.rocketGun then
		r.rocketGun = { dmg = o.rocketGun.dmg, msec = 1000 / (o.rocketGun.rate / 60), fired = G.now }
	end
	return addShot(G, r)
end

local function projectileBlast(G, s, target)
	if s.blast then
		spawnBlast(G, s.blast.type, s.x, s.y, s.blast.dmg, s.blast.poison, s.src, { target = target, angle = s.rot })
	end
	if s.napalm then
		addShot(G, { k = "napalm", x = s.x, y = s.y, angle = s.rot, out = 0, qty = s.napalm.qty, timing = s.napalm.timing,
			jit = s.napalm.jit, next = G.now, src = s.src, fx = fwd(s.rot, 15) })
	end
end
local function projectileCluster(G, s)
	local c = s.cluster
	if not c then
		return
	end
	if c.type == "spark" then
		local list = inBoxList(G, s, 220)
		for i = 0, c.qty - 1 do
			local f = fwd((i + 1) / c.qty * 360, 40)
			local from = { x = s.x + f.x, y = s.y + f.y }
			local tg = if #list > 0 then list[fmod(i, #list) + 1] else nil
			if tg then
				sparkNow(G, from, tg, c.dmg, 20, s.src, "cluster")
			end
		end
	else
		for i = 0, c.qty - 1 do
			local rot = (i + 1) / c.qty * 360
			local f = fwd(rot, 30)
			newRocket(G, s.x + f.x, s.y + f.y, rot, nil, c.dmg, s.src, { holdingCapable = c.holding, tier = 9,
				laser = if c.laser then { dmg = c.laserDmg, range = 200, rate = 120, spark = false, poison = 1 } else nil })
		end
	end
end
local function rocketHit(G, s, target)
	projectileBlast(G, s, target)
	projectileCluster(G, s)
	hit(G, target, s.dmg, s.src)
	s.dead = true
end
local function updateShell(G, s)
	if s.next == nil then
		s.next = G.now + TICK.shell
		s.timeLast = G.now
		return
	end
	if G.now < s.next then
		return
	end
	s.next += TICK.shell
	local dt = G.now - s.timeLast
	s.timeLast = G.now
	if dt == 0 then
		return
	end
	local step = dt / 1000 * s.speed
	if not alive(s.target) then
		s.dead = true
		return
	end
	local d = dist(s, s.target)
	if d < 3 then
		hit(G, s.target, s.dmg, s.src)
		s.dead = true
		return
	end
	s.rot = degTo(s, s.target)
	local f = fwd(s.rot, step)
	if d < step then
		hit(G, s.target, s.dmg, s.src)
		s.dead = true
		return
	end
	s.x += f.x
	s.y += f.y
end
local function updateRocket(G, s)
	if G.now < s.next then
		return
	end
	s.next += s.period
	local dt = G.now - s.timeLast
	if dt == 0 then
		return
	end
	s.timeLast = G.now
	if s.offRemove or s.offLock then
		if s.x < -10 or s.x > 730 or s.y < -10 or s.y > 490 then
			s.dead = true
			return
		end
	end
	local step, rstep = dt / 1000 * s.speed, dt / 1000 * s.turn
	local f = fwd(s.rot, step)
	s.target = availOrAcquire(G, s.target, s, 1000, "near")
	if s.holdingInitially then
		s.x += f.x
		s.y += f.y
		s.rot = wrap180(s.rot + rstep * s.holdDir)
	elseif s.target then
		local want = degTo(s, s.target)
		local diff = want - s.rot
		local d2 = dist2(s, s.target)
		if not s.noRotate then
			if abs(diff) < abs(rstep) then
				s.rot = want
			else
				local a, b = fmod(diff + 360, 360), fmod(360 - diff, 360)
				s.rot = wrap180(if b < a then s.rot - rstep else s.rot + rstep)
			end
		end
		if d2 < step * step or d2 < s.impact * s.impact then
			s.x, s.y = s.target.x, s.target.y
			rocketHit(G, s, s.target)
			return
		end
		s.x += f.x
		s.y += f.y
		if s.laser and d2 <= s.laser.r2 and G.now - s.laser.fired >= s.laser.msec then
			s.laser.fired = G.now
			if s.laser.spark then
				sparkNow(G, s, s.target, s.laser.dmg, s.laser.poison, s.src, "tazer")
			else
				laserNow(G, s, s.target, s.laser.dmg, s.src)
			end
		end
		if s.rocketGun and G.now - s.rocketGun.fired >= s.rocketGun.msec then
			s.rocketGun.fired = G.now
			newRocket(G, s.x, s.y, degTo(s, s.target), s.target, s.rocketGun.dmg, s.src, { holdingCapable = s.holdingCapable, tier = 9 })
		end
	elseif s.holdingCapable then
		s.offRemove = false
		s.x += f.x
		s.y += f.y
		if not s.noRotate then
			s.rot = wrap180(s.rot + rstep * s.holdDir)
		end
	else
		s.x += f.x
		s.y += f.y
		s.offRemove = true
	end
end
local function bombExplode(G, s)
	projectileBlast(G, s, s.target)
	projectileCluster(G, s)
	s.dead = true
end
local function updateBomb(G, s)
	if G.now < s.next then
		return
	end
	s.next += TICK.frame
	local dt = G.now - s.timeLast
	s.timeLast = G.now
	if dt == 0 then
		return
	end
	local step = dt / 1000 * s.speed
	if alive(s.target) then
		local d = dist(s, s.target)
		if d < 3 then
			hit(G, s.target, s.dmg, s.src)
			return
		end
		s.rot = degTo(s, s.target)
		local f = fwd(s.rot, step)
		if d < step then
			hit(G, s.target, s.dmg, s.src)
			bombExplode(G, s)
			return
		end
		s.x += f.x
		s.y += f.y
	else
		bombExplode(G, s)
	end
end
local function updateMine(G, s)
	if not s.planted and G.now >= s.twNext then
		s.twNext += TICK.tween
		local r = (G.now - s.t0) / 1000
		if r >= 1 then
			s.x, s.y = s.tx, s.ty
			s.planted = true
		else
			s.x = s.sx + (s.tx - s.sx) * r
			s.y = s.sy + (s.ty - s.sy) * r
		end
	end
	if G.now < s.next then
		return
	end
	s.next += TICK.mine
	if not s.planted then
		return
	end
	local list = inBoxList(G, s, 20)
	if #list > 0 then
		arrayPick(G, list, 1)
		projectileBlast(G, s, s.target)
		projectileCluster(G, s)
		s.dead = true
		fx(G, { k = "mine", x = s.x, y = s.y })
	end
end
local function updateHole(G, s)
	if G.now < s.next then
		return
	end
	if s.closing then
		s.dead = true
		return
	end
	s.next += TICK.hole
	s.open = true
	for _, a in inBoxList(G, s, s.r) do
		if a.holed then
			continue
		end
		local d = dist(s, a)
		if d <= s.r then
			a.holed = { sx = a.x, sy = a.y, tx = s.x, ty = s.y, t0 = G.now, dur = d / 500 * 1000, next = G.now + TICK.tween }
			a.bounty = 0
			a.tw = nil
			a.rep = nil
		end
	end
	for _, o in G.shots do
		if o == s or o.dead or o.k == "hole" or o.k == "walker" or o.k == "rail" then
			continue
		end
		if inBox(s, o, s.r) then
			o.dead = true
			fx(G, { k = "swallow", x = o.x, y = o.y })
		end
	end
	for _, b in G.blasts do
		if not b.done and inBox(s, b, s.r) then
			b.done = true
			b.swallowed = true
		end
	end
	if G.now - s.t0 >= s.dur then
		s.closing = true
		s.next = G.now + 224
	end
end
function walkerAdvance(G, s)
	if s.wp == nil then
		return
	end
	s.wp += s.dir
	if s.wp <= 0 or s.wp > #G.road then
		s.dead = true
		return
	end
	local wp = G.road[s.wp]
	s.tw = { sx = s.x, sy = s.y, tx = wp.x, ty = wp.y, t0 = G.now, dur = dist(s, wp) / 150 * 1000, next = G.now + TICK.tween }
end
local function updateWalker(G, s)
	local t = s.tw
	if t and G.now >= t.next then
		t.next += TICK.tween
		local r = if t.dur > 0 then (G.now - t.t0) / t.dur else 1
		if r >= 1 then
			s.x, s.y = t.tx, t.ty
			s.tw = nil
			walkerAdvance(G, s)
			if s.dead then
				return
			end
		else
			s.x = t.sx + (t.tx - t.sx) * r
			s.y = t.sy + (t.ty - t.sy) * r
		end
	end
	if G.now >= s.end_ then
		s.dead = true
		return
	end
	if G.now < s.next then
		return
	end
	s.next += TICK.walker
	local k = 1 - (G.now - s.t0) / 3000
	local dmg, p = max(0, k * s.dmg), max(0, k * s.poison)
	for _, a in inBoxList(G, s, 10) do
		hit(G, a, dmg, nil)
		poison(G, a, p, true)
	end
end
local function updateNapalm(G, s)
	if G.now < s.next then
		return
	end
	s.next += s.timing
	if s.out >= s.qty then
		s.dead = true
		return
	end
	local jx = jsRound(rnd(G) * s.jit - s.jit / 2)
	local jy = jsRound(rnd(G) * s.jit - s.jit / 2)
	spawnBlast(G, "tiny", s.x + jx, s.y + jy, 1e6, 1, s.src, nil)
	s.x += s.fx.x
	s.y += s.fx.y
	s.out += 1
end
local function railHurt(G, s)
	for _, a in G.attackers do
		if a.dead then
			continue
		end
		local dx, dy = s.x2 - s.x1, s.y2 - s.y1
		local l2 = dx * dx + dy * dy
		local k = ((a.x - s.x1) * dx + (a.y - s.y1) * dy) / l2
		k = max(0, min(1, k))
		local ex, ey = a.x - (s.x1 + k * dx), a.y - (s.y1 + k * dy)
		if ex * ex + ey * ey <= 400 then
			hit(G, a, s.dmg, s.src)
		end
	end
end
local function updateShot(G, s)
	local k = s.k
	if k == "shell" then
		updateShell(G, s)
	elseif k == "rocket" then
		updateRocket(G, s)
	elseif k == "bomb" then
		updateBomb(G, s)
	elseif k == "mine" then
		updateMine(G, s)
	elseif k == "hole" then
		updateHole(G, s)
	elseif k == "walker" then
		updateWalker(G, s)
	elseif k == "napalm" then
		updateNapalm(G, s)
	elseif k == "rail" then
		if G.now >= s.next then
			railHurt(G, s)
			s.dead = true
		end
	elseif G.mods and G.mods.updateShot then
		G.mods.updateShot(G, s)
	end
end

-- ---------------------------------------------------------------- blasts
function spawnBlast(G, ty, x, y, dmg, p, src, ctx)
	local shape = G.D.blasts[ty] or { 80, 80 }
	local time, size = shape[1], shape[2]
	local b = { id = G.nextId, type = ty, x = x, y = y, dmg = dmg, poison = p, src = src, size = size, t0 = G.now,
		hitAt = G.now + math.ceil(time / TICK.tween) * TICK.tween, done = false, swallowed = false }
	G.nextId += 1
	insert(G.blasts, b)
	fx(G, { k = "blast", type = ty, x = x, y = y, size = size })
	if ty == "shockwave" and ctx then
		local tg = ctx.target
		local wp = if alive(tg) and tg.wp then tg.wp else nil
		for _, dir in { 1, -1 } do
			local w = { k = "walker", x = x, y = y, dir = dir, wp = if wp == nil then nil elseif dir == 1 then wp - 1 else wp,
				dmg = dmg, poison = p, t0 = G.now, end_ = G.now + 3008, next = G.now + TICK.walker, tw = nil, src = src }
			addShot(G, w)
			walkerAdvance(G, w)
		end
	end
	return b
end
local function updateBlast(G, b)
	if b.done or G.now < b.hitAt then
		return
	end
	b.done = true
	local r = b.size / 2
	for _, a in inBoxList(G, b, r) do
		if dist(b, a) <= r then
			poison(G, a, b.poison, false)
			hit(G, a, b.dmg, b.src)
		end
	end
end

-- ================================================================ main step
local function compact(list, deadKey)
	local any = false
	for i = 1, #list do
		if list[i][deadKey] then
			any = true
			break
		end
	end
	if not any then
		return list
	end
	local out = {}
	for i = 1, #list do
		if not list[i][deadKey] then
			insert(out, list[i])
		end
	end
	return out
end

function Engine.step(G)
	if G.over then
		return
	end
	G.now += 1
	local now = G.now
	if now >= G.mgrNext then
		G.mgrNext += TICK.manager
		updateManager(G)
		if G.over then
			return
		end
	end
	for _, w in G.waves do
		if now >= w.next then
			w.next += TICK.spawner
			updateSpawner(G, w)
		end
	end
	if #G.waves > 0 then
		local keep, changed = {}, false
		for _, w in G.waves do
			if w.sent < w.size then
				insert(keep, w)
			else
				changed = true
			end
		end
		if changed then
			G.waves = keep
		end
	end
	local atk = G.attackers
	local i = 1
	while i <= #atk do
		if not atk[i].dead then
			updateAttacker(G, atk[i])
		end
		i += 1
	end
	local tur = G.turrets
	i = 1
	while i <= #tur do
		local t = tur[i]
		if not t.dead then
			if t.freak then
				updateFreak(G, t)
			end
			if now >= t.next then
				t.next += if t.type == "combonly" and t.combo then TICK.turret
					elseif t.kind == "Fusion" then TICK.fusion
					elseif t.type == "combonly" then TICK.combonlyIdle
					else TICK.turret
				updateTurret(G, t)
			end
		end
		i += 1
	end
	local sh = G.shots
	i = 1
	while i <= #sh do
		if not sh[i].dead then
			updateShot(G, sh[i])
		end
		i += 1
	end
	local bl = G.blasts
	i = 1
	while i <= #bl do
		updateBlast(G, bl[i])
		i += 1
	end
	if G.winNext ~= nil and now >= G.winNext then
		winCheck(G)
	end
	if G.mods and G.mods.step then
		G.mods.step(G)
	end
	G.attackers = compact(atk, "dead")
	G.shots = compact(sh, "dead")
	G.blasts = compact(bl, "done")
	G.turrets = compact(tur, "dead")
end
function Engine.run(G, ms)
	local i = 0
	while i < ms and not G.over do
		Engine.step(G)
		i += 1
	end
end

-- ================================================================ player actions (validated)
local function owned(G, pid, id)
	for _, t in G.turrets do
		if t.id == id and not t.dead then
			if t.owner == pid or #G.playerOrder == 1 then
				return t
			end
			return nil
		end
	end
	return nil
end
local function upgradeDone(G, t)
	if not t.comboNever and not t.comboCapable and upPct(t, "damage") == 100 then
		t.comboCapable = true
		t.comboNext = G.now
		fx(G, { k = "comboready", id = t.id })
	end
	modifyUpdate(G, t)
	if t.type == "modifier" then
		recalcMods(G)
	end
	if t.kind == "Yellow" then
		t.base.poison = max(1, 10 * (upPct(t, "damage") / 100))
		t.chargeMax = 100 + t.lvl.damage * 10
		t.chargeRate = 10 + t.lvl.rate * 2
	end
	if t.kind == "Red" and t.lvl.range >= 3 and t.lvl.rate >= 3 then
		t.holdingPattern = true
	end
	if t.kind == "Fusion" then
		t.feedList = nil
	end
	if t.freakCapable then
		local fl = def(G, t.kind).freakLevel
		if t.lvl.damage >= fl.damage and t.lvl.range >= fl.range and t.lvl.rate >= fl.rate then
			t.freakAvail = true
		end
	end
end

function Engine.build(G, pid, kind, x, y)
	local d = def(G, kind)
	if not d or G.over or not G.unlocked[kind] then
		return nil
	end
	if not canBuildAt(G, kind, x, y, nil) then
		return nil
	end
	if G.mods and G.mods.canBuild and not G.mods.canBuild(G, pid, kind) then
		return nil
	end
	if not cashSpend(G, pid, turretCost(G, pid, kind)) then
		return nil
	end
	local t = makeTurret(G, kind, x, y, pid)
	insert(G.turrets, t)
	recalcMods(G)
	return t
end
function Engine.upgrade(G, pid, id, stat, maxOut)
	local t = owned(G, pid, id)
	if not t or G.over then
		return false
	end
	local any = false
	repeat
		local c = upCost(t, stat)
		if c == nil or not cashSpend(G, pid, c) then
			break
		end
		t.lvl[stat] += 1
		t.base[stat] = t.up[stat].amount[t.lvl[stat]]
		t.value += c
		upgradeDone(G, t)
		any = true
	until not maxOut
	return any
end
function Engine.sell(G, pid, id)
	local t = owned(G, pid, id)
	if not t or G.over then
		return 0
	end
	local resale = if G.mods and G.mods.resale then G.mods.resale(G, t) else G.D.settings.resale
	local v = math.ceil(t.value * resale)
	G.players[t.owner].cash += v
	G.players[t.owner].spent -= v
	G.stats.spent -= v
	if t.kind == "Red" then
		local w = acquire(G, t, 720, "weak")
		for _, r in t.holding do
			if not r.dead then
				r.target = w
				r.holdingInitially = false
			end
		end
	end
	t.dead = true
	t.active = false
	for _, o in G.turrets do
		if o.joins then
			local keep = {}
			for _, j in o.joins do
				if j ~= t then
					insert(keep, j)
				end
			end
			o.joins = keep
		end
		if o.bearTo == t then
			o.bearTo = nil
		end
	end
	G.turrets = compact(G.turrets, "dead")
	recalcMods(G)
	fx(G, { k = "sell", x = t.x, y = t.y, v = v })
	return v
end
function Engine.move(G, pid, id, x, y)
	local t = owned(G, pid, id)
	if not t or G.over then
		return false
	end
	if not canBuildAt(G, t.kind, x, y, t) then
		return false
	end
	if not cashSpend(G, pid, G.D.settings.moveCost) then
		return false
	end
	t.x, t.y = x, y
	t.minePts, t.holePts = nil, nil
	if t.kind == "Fusion" then
		t.feedList = nil
	end
	recalcMods(G)
	return true
end
function Engine.cycleTargetMode(G, pid, id)
	local t = owned(G, pid, id)
	if not t then
		return nil
	end
	t.modeNum = fmod(t.modeNum + 1, #MODES)
	t.targetMode = MODES[t.modeNum + 1]
	return MODE_TITLES[t.targetMode]
end
function Engine.setTargetMode(G, pid, id, mode)
	local t = owned(G, pid, id)
	if not t or not MODE_TITLES[mode] then
		return false
	end
	t.targetMode = mode
	t.modeNum = (table.find(MODES, mode) or 1) - 1
	return true
end
function Engine.toggleLock(G, pid, id)
	local t = owned(G, pid, id)
	if not t then
		return nil
	end
	t.reacquire = not t.reacquire
	return if t.reacquire then "Lock Off" else "Lock On"
end
function Engine.setDirectional(G, pid, id, deg, spread)
	local t = owned(G, pid, id)
	if not t or t.type == "modifier" then
		return false
	end
	t.dir = if spread and spread ~= 0 then { deg = fmod(deg + 720, 360), spread = spread } else nil
	return true
end
function Engine.focus(G, x, y)
	local a = acquire(G, { x = x, y = y }, 25, "near")
	if not a then
		return nil
	end
	for _, t in G.turrets do
		if t.type ~= "modifier" then
			t.target = a
		end
	end
	fx(G, { k = "focus", id = a.id })
	return a
end
function Engine.join(G, pid, targeterId, id)
	local t = owned(G, pid, targeterId)
	local o
	for _, q in G.turrets do
		if q.id == id and not q.dead then
			o = q
			break
		end
	end
	if not t or not o or t.type ~= "targeter" or o == t or o.type == "modifier" or o.type == "targeter" then
		return false
	end
	if table.find(t.joins, o) then
		return true
	end
	if #t.joins == 3 then
		table.remove(t.joins, 1)
	end
	insert(t.joins, o)
	return true
end
function Engine.combonlyOptions(G, id)
	local t
	for _, q in G.turrets do
		if q.id == id and not q.dead then
			t = q
			break
		end
	end
	if not t or t.type ~= "combonly" or t.combo then
		return {}
	end
	local n = counts(countColours(G, t, true))
	local byColour = {}
	for _, r in COMBONLY do
		if r[1](n) then
			byColour[r[2]] = { colour = r[2], combo = r[3], needs = r[4] }
		end
	end
	local out = {}
	for _, k in COLOURS do
		if byColour[k] then
			insert(out, byColour[k])
		end
	end
	return out
end
function Engine.combonlyChoose(G, pid, id, colour)
	local t = owned(G, pid, id)
	if not t or t.type ~= "combonly" or t.combo then
		return false
	end
	local opt
	for _, o in Engine.combonlyOptions(G, id) do
		if o.colour == colour then
			opt = o
			break
		end
	end
	if not opt then
		return false
	end
	local c = countColours(G, t, true)
	for _, col in COLOUR_ORDER do
		if opt.needs[col] and #c[col] < opt.needs[col] then
			return false
		end
	end
	for _, col in COLOUR_ORDER do
		if not opt.needs[col] then
			continue
		end
		for _, o in arrayPick(G, c[col], opt.needs[col]) do
			t.value += o.value
			o.active = false
			o.dead = true
			fx(G, { k = "absorb", x1 = o.x, y1 = o.y, x2 = t.x, y2 = t.y })
		end
	end
	G.turrets = compact(G.turrets, "dead")
	t.combo = opt.combo
	t.colour = colour
	t.armedAt = G.now + 1500
	t.next = G.now + TICK.turret
	recalcMods(G)
	return true
end
function Engine.setPrefs(G, p)
	if p.waveSpacing ~= nil then
		G.waveSpacing = max(1000, p.waveSpacing)
	end
	if p.waveFollow ~= nil then
		G.waveFollow = p.waveFollow == true
	end
end

-- ================================================================ exports
Engine.TICK, Engine.MODES, Engine.MODE_TITLES, Engine.COLOURS, Engine.RULES, Engine.COMBONLY, Engine.TAKES = TICK, MODES, MODE_TITLES, COLOURS, RULES, COMBONLY, TAKES
Engine.PLAY, Engine.BUILD_SPACING = PLAY, BUILD_SPACING
Engine.canBuildAt, Engine.turretCost, Engine.upCost, Engine.upMax, Engine.upPct, Engine.upAmountMax = canBuildAt, turretCost, upCost, upMax, upPct, upAmountMax
Engine.comboCanFire, Engine.countColours, Engine.counts, Engine.modifyUpdate, Engine.recalcMods = comboCanFire, countColours, counts, modifyUpdate, recalcMods
Engine.rnd, Engine.dist, Engine.degTo, Engine.fwd, Engine.spawnBlast, Engine.hit, Engine.poison = rnd, dist, degTo, fwd, spawnBlast, hit, poison
Engine.acquire, Engine.availOrAcquire, Engine.inRange, Engine.inBoxList, Engine.arrayPick, Engine.addShot, Engine.newRocket = acquire, availOrAcquire, inRange, inBoxList, arrayPick, addShot, newRocket
Engine.laserNow, Engine.sparkNow, Engine.bearTowards, Engine.canFire, Engine.tryFiring, Engine.turretFire, Engine.muzzle, Engine.fx = laserNow, sparkNow, bearTowards, canFire, tryFiring, turretFire, muzzle, fx
Engine.attackerMove, Engine.wrap180, Engine.modStat, Engine.alive, Engine.linkFire, Engine.comboTake, Engine.cashSpend, Engine.cashWin = attackerMove, wrap180, modStat, alive, linkFire, comboTake, cashSpend, cashWin
Engine.jsRound, Engine.dsin, Engine.dcos, Engine.datan2 = jsRound, dsin, dcos, datan2

return Engine
