--!strict
-- Overload Celestialarchy v1: headless Lune sim of the core rules (seeding, grammar,
-- obstacle certification, 120 Hz controller, escalation, sensory load, death/rebirth).
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local TWO32 = 4294967296
local function mul32(a: number, b: number): number
	local al, ah = a % 65536, a // 65536
	local bl, bh = b % 65536, b // 65536
	return (al * bl + ((ah * bl + al * bh) % 65536) * 65536) % TWO32
end
local function mix(h: number, k: number): number
	k = mul32(k % TWO32, 0xcc9e2d51)
	k = mul32(bit32.lrotate(k, 15), 0x1b873593)
	h = bit32.lrotate(bit32.bxor(h, k), 13)
	return (mul32(h, 5) + 0xe6546b64) % TWO32
end
local function H32(...: number): number
	local h = 0x9747b28c
	for _, v in { ... } do
		h = mix(h, v)
	end
	h = mul32(bit32.bxor(h, bit32.rshift(h, 16)), 0x85ebca6b)
	h = mul32(bit32.bxor(h, bit32.rshift(h, 13)), 0xc2b2ae35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end
local function stream(seed: number)
	local x = if seed == 0 then 1 else seed
	return function(): number
		x = bit32.bxor(x, bit32.lshift(x, 13))
		x = bit32.bxor(x, bit32.rshift(x, 17))
		x = bit32.bxor(x, bit32.lshift(x, 5))
		return x / TWO32
	end
end

local CONTENT = 1
local S_GEOM, S_HAZ, S_BOT = 1, 2, 99
local DT = 1 / 120
local SEC = 64
local HALF = 32
local RADIUS = 1.5
local LAT_A, LAT_V = 96, 24
local RESTART_ON_ROUTE = true

local PHRASES = {
	"OOBBBOBOBBBOQOQO", "BBWWWBWBWWBWQBOQ", "WWSSSWSWSSWCQWOQ", "WFFCFCFCFFCWQOOQ", "SRRSRSRSRRCWQOOQ",
	"SMMSMSMSMMCWQOOQ", "SIIWIWIWIICWQOOQ", "SGGWGWGWGGCWQOOQ", "RRWCFFCWMMSCQOOQ", "IIWCFFCWGGWCQOOQ",
}
local function vL(L: number) return math.min(120, 60 + 6 * (L - 1)) end
local function gapL(L: number) return math.max(12, 24 - 4 / 3 * (L - 1)) end
local function clamp(x: number, a: number, b: number) return math.max(a, math.min(b, x)) end
local function q2(x: number) return math.floor(x / 2 + 0.5) * 2 end

-- max lateral travel from rest in time t under 96 stud/s^2, 24 stud/s
local function maxTravel(t: number): number
	if t <= 0 then return 0 end
	local ta = LAT_V / LAT_A
	if t <= ta then return 0.5 * LAT_A * t * t end
	return 0.5 * LAT_A * ta * ta + LAT_V * (t - ta)
end

type Obstacle = { z: number, c: number, gap: number, kind: string, sec: number, tries: number, fallback: boolean }

local function buildRun(seed: number)
	local obstacles: { Obstacle } = {}
	local sections = {}
	local prevC, prevZ = 0, -1e9
	for s = 0, 159 do
		local L = s // 16 + 1
		local kind = string.sub(PHRASES[L], s % 16 + 1, s % 16 + 1)
		local geo = stream(H32(CONTENT, seed, s, S_GEOM, 0))
		table.insert(sections, { s = s, L = L, kind = kind, warp = q2(geo() * 4) })
		if kind ~= "O" and kind ~= "Q" and kind ~= "B" then
			local gap = gapL(L)
			local placed: Obstacle? = nil
			for attempt = 0, 7 do
				local r = stream(H32(CONTENT, seed, s, S_HAZ, attempt))
				local z = s * SEC + 32 + q2((r() - 0.5) * 16)
				local lim = HALF - gap / 2 - 2
				local c = clamp(q2((r() * 2 - 1) * lim), -lim, lim)
				local dc = math.abs(c - prevC)
				local t = (z - prevZ) / (vL(L) + 4)
				if dc <= 20 and maxTravel(math.min(t, 1.2) - 0.2) >= dc then
					placed = { z = z, c = c, gap = gap, kind = kind, sec = s, tries = attempt + 1, fallback = false }
					break
				end
			end
			if not placed then
				placed = { z = s * SEC + 32, c = prevC, gap = gap, kind = kind, sec = s, tries = 8, fallback = true }
			end
			local p = placed :: Obstacle
			table.insert(obstacles, p)
			prevC, prevZ = p.c, p.z
		end
	end
	return obstacles, sections
end

-- independent re-check of every route certificate
local function verifyCertificates(obs: { Obstacle }): number
	local bad, pc, pz = 0, 0, -1e9
	for _, o in obs do
		local L = o.sec // 16 + 1
		local dc = math.abs(o.c - pc)
		local t = (o.z - pz) / (vL(L) + 4)
		if dc > 20 or maxTravel(math.min(t, 1.2) - 0.2) < dc or o.gap < 12 then bad += 1 end
		if math.abs(o.c) + o.gap / 2 > HALF then bad += 1 end
		pc, pz = o.c, o.z
	end
	return bad
end

local function simulate(seed: number, slider: number, trace: boolean)
	local obstacles, sections = buildRun(seed)
	local bot = stream(H32(CONTENT, seed, 0, S_BOT, 0))
	local st = { x = 0, vx = 0, z = 0, v = 0, tick = 0 }
	local finishZ = 160 * SEC
	local nextObs = 1
	local P, lastPEvent = 0.5, 0
	local streak, deaths, lastDeathT = 0, 0, -1
	local safeMisses: { number } = {}
	local nearDeaths: { number } = {}
	local pendingMiss: { { t: number, cl: number } } = {}
	local boostUntil, boostCd = -1, -1
	local survivalStart = 0
	local I, K = 0.12, 0.5
	local suppressUntil = -1
	local frozenUntil = -1
	local aim: { [number]: number } = {}
	local lateUntil: { [number]: number } = {}
	local samples, events = {}, {}
	local maxLoadViolation, loadFrames = 0, 0
	local lastSec = 0
	local load, cap = 0, 0
	local gains = { lines = 0, palette = 0, accent = 0, roll = 0 }
	local nearMissCount, nearDeathCount = 0, 0

	local function ev(kind: string, t: number, extra: { [string]: any }?)
		if not trace then return end
		local e: { [string]: any } = { k = kind, t = math.floor(t * 1000) / 1000, z = math.floor(st.z) }
		if extra then for a, b in extra do e[a] = b end end
		table.insert(events, e)
	end
	local function pUpdate(t: number, x: number)
		P += (x - P) * (1 - math.exp(-(t - lastPEvent) / 20))
		lastPEvent = t
	end

	while st.z < finishZ and st.tick < 120 * 600 do
		st.tick += 1
		local t = st.tick * DT
		local sIdx = math.min(159, st.z // SEC)
		local L = sIdx // 16 + 1
		if t < frozenUntil then
			-- death fade: controller held
		else
			-- forward
			local target = vL(L) + (if t < boostUntil then 4 else 0)
			if st.v < target then st.v = math.min(target, st.v + 72 * DT) else st.v = target end
			if st.tick > 120 then st.v = clamp(st.v, 42, 120) end
			-- bot steering: only sees obstacles inside 1.2 s telegraph
			local o = obstacles[nextObs]
			local tx = st.x
			if o and (o.z - st.z) <= 1.2 * st.v then
				if aim[nextObs] == nil then
					local spread = o.gap / 2 - RADIUS - 0.8
					aim[nextObs] = o.c + (bot() * 2 - 1) * spread
					if bot() < 0.05 then lateUntil[nextObs] = t + 0.35 + bot() * 0.4 end -- pilot mistake
				end
				if t >= (lateUntil[nextObs] or 0) then tx = aim[nextObs] end
			end
			-- lateral PD to target with accel/speed caps
			local stop = st.vx * st.vx / (2 * LAT_A)
			local err = tx - st.x
			local want = clamp(err * 6, -LAT_V, LAT_V)
			if math.abs(err) <= stop and math.sign(err) == math.sign(st.vx) then want = 0 end
			st.vx += clamp(want - st.vx, -LAT_A * DT, LAT_A * DT)
			local oz = st.z
			st.x = clamp(st.x + st.vx * DT, -HALF + 2, HALF - 2)
			st.z += st.v * DT
			-- swept crossing test
			if o and oz < o.z and st.z >= o.z then
				local frac = (o.z - oz) / (st.z - oz)
				local xc = st.x - st.vx * DT * (1 - frac)
				local cl = o.gap / 2 - math.abs(xc - o.c) - RADIUS
				nextObs += 1
				if cl < 0 then
					deaths += 1
					streak = 0
					lastDeathT = t
					pUpdate(t, 0)
					local bar = (o.sec // 4) * 4
					ev("death", t, { sec = o.sec, cl = math.floor(cl * 100) / 100, restart = bar })
					st.z = bar * SEC
					st.vx, st.v = 0, 42
					frozenUntil = t + 0.5
					survivalStart = t + 0.5
					while obstacles[nextObs - 1] and obstacles[nextObs - 1].z > st.z do
						nextObs -= 1
						aim[nextObs] = nil
						lateUntil[nextObs] = nil
					end
					-- restart on the certified route: align with the bar's first gap, because a
					-- bar-start spawn can sit < 1.2 s before it (unwinnable death loop otherwise)
					local nextO = obstacles[nextObs]
					st.x = if RESTART_ON_ROUTE and nextO then nextO.c else 0
					lastSec = bar
				elseif cl < 0.5 then
					nearDeathCount += 1
					table.insert(nearDeaths, t)
					ev("neardeath", t, { cl = math.floor(cl * 100) / 100 })
				elseif cl <= 2.5 then
					table.insert(pendingMiss, { t = t, cl = cl })
				end
			end
		end
		-- validated near misses after 1 s survival
		for i = #pendingMiss, 1, -1 do
			local m = pendingMiss[i]
			if lastDeathT >= m.t then
				table.remove(pendingMiss, i)
			elseif t - m.t >= 1 then
				table.remove(pendingMiss, i)
				nearMissCount += 1
				table.insert(safeMisses, t)
				if t >= boostCd then
					boostUntil, boostCd = t + 0.75, t + 2
					ev("boost", t)
				else
					ev("nearmiss", t)
				end
			end
		end
		-- section clears
		local cur = st.z // SEC
		if cur > lastSec then
			for _ = lastSec + 1, cur do
				streak += 1
				pUpdate(t, 1)
			end
			lastSec = cur
		end
		-- 10 Hz skill + intensity
		if st.tick % 12 == 0 then
			while safeMisses[1] and t - safeMisses[1] > 10 do table.remove(safeMisses, 1) end
			while nearDeaths[1] and t - nearDeaths[1] > 8 do table.remove(nearDeaths, 1) end
			local N = clamp(#safeMisses / 4, 0, 1)
			local S = clamp(streak / 12, 0, 1)
			local V = clamp((st.v - 60) / 60, 0, 1)
			K = clamp(0.5 * P + 0.15 * N + 0.2 * S + 0.15 * V, 0, 1)
			local B = 1 - math.exp(-(L - 1) / 5)
			local D = if lastDeathT >= 0 then 0.35 * math.exp(-(t - lastDeathT) / 20) else 0
			local Q = math.min(0.35, 0.12 * #nearDeaths)
			if #nearDeaths >= 3 then suppressUntil = t + 8 end
			local surv = math.max(0, t - survivalStart)
			local Istar = clamp(0.12 + 0.56 * B + 0.12 * (1 - math.exp(-surv / 180)) + 0.2 * K - D - Q, 0, 1)
			I = if Istar > I then math.min(Istar, I + 0.04 * 0.1) else math.max(Istar, I - 0.35 * 0.1)
		end
		-- 20 Hz sensory allocation: propose, compose, reduce in priority order
		if st.tick % 6 == 0 then
			cap = slider * (0.35 + 0.65 * K)
			local quiet = sections[sIdx + 1].kind == "Q"
			local deco = if t < suppressUntil or t < frozenUntil then 0 else 1
			local g = { roll = I * deco, accent = I * deco, lines = I, palette = I * deco }
			if quiet then g = { roll = 0, accent = 0, lines = math.min(I, 0.15), palette = 0 } end
			local function compose()
				local sp = clamp((st.v - 42) / 78, 0, 1)
				local M = clamp((0.10 * g.lines) * (0.6 * sp + 0.2) / 0.25, 0, 1)
				local C = clamp(0.18 * g.palette / 0.25, 0, 1)
				local F = clamp(0.05 * 0.3 * 2 * g.accent / 0.10, 0, 1)
				local roll = 6 * g.roll * math.abs(st.vx) / LAT_V
				local R = clamp(0.5 * roll / 6 + 0.5 * (roll * 2) / 12, 0, 1)
				return 0.45 * M + 0.25 * C + 0.2 * F + 0.1 * R, M, C, F, R
			end
			load = compose()
			for _, key in { "roll", "accent", "lines", "palette" } do
				if load <= cap then break end
				local before = g[key]
				g[key] = 0
				local without = compose()
				if without < cap then
					-- bisect partial gain
					local lo, hi = 0, before
					for _ = 1, 12 do
						local mid = (lo + hi) / 2
						g[key] = mid
						if compose() <= cap then lo = mid else hi = mid end
					end
					g[key] = lo
				end
				load = compose()
			end
			loadFrames += 1
			if load > cap + 1e-9 then maxLoadViolation = math.max(maxLoadViolation, load - cap) end
			gains = g
			if trace and st.tick % 12 == 0 then
				table.insert(samples, {
					math.floor(t * 100) / 100, math.floor(st.z), math.floor(st.x * 10) / 10, math.floor(st.v * 10) / 10,
					math.floor(I * 1000) / 1000, math.floor(K * 1000) / 1000, math.floor(load * 1000) / 1000,
					math.floor(cap * 1000) / 1000, L,
				})
			end
		end
	end
	local _ = gains
	return {
		seed = seed, time = st.tick * DT, finished = st.z >= finishZ, deaths = deaths,
		nearMisses = nearMissCount, nearDeaths = nearDeathCount, maxLoadViolation = maxLoadViolation,
		loadFrames = loadFrames, samples = samples, events = events, obstacles = obstacles, sections = sections,
		certBad = verifyCertificates(obstacles),
		fallbacks = (function() local n = 0 for _, o in obstacles do if o.fallback then n += 1 end end return n end)(),
	}
end

-- spec arithmetic checks
local checks = {}
local function check(name: string, got: number, want: number)
	table.insert(checks, { name = name, got = got, want = want, ok = math.abs(got - want) < 1e-3 })
end
check("Section triangles", 4800 + 384 + 384 + 192, 5760)
check("Section positions", 9600 + 768 + 768 + 384, 11520)
check("Phone ms subtotal", 0.65 + 0.55 + 0.65 + 0.35 + 0.35 + 0.2 + 0.7 + 0.25 + 0.15 + 0.2 + 1 + 2 + 0.4, 7.45)
check("Desktop ms subtotal", 0.25 + 0.25 + 0.28 + 0.15 + 0.15 + 0.1 + 0.3 + 0.12 + 0.07 + 0.1 + 0.4 + 1.2 + 0.2, 3.57)
check("Submitted triangles", 23040 + 256 + 128 + 336 + 192 + 160 + 1536, 25648)
check("Position writes/frame", 512 + 768 + 768 + 384, 2432)
check("Mutation records/frame", 2432 + 256 + 256, 2944)
check("Input packet bytes", 18 * 3 + 10, 64)
check("Snapshot bytes", 8 * 16 + 12, 140)
check("Raw section bytes", 11520 * 12 + 5760 * 3 * 4 + 96 * 16 + 192 * 12 + 5760 * 3 * 8, 349440)
check("Frames to insert max section", math.ceil(11520 / 512), 23)
check("Lateral reach in 1.0 s (>=20)", math.min(20, maxTravel(1.0)), 20)
local levels = {}
for L = 1, 10 do
	local B = 1 - math.exp(-(L - 1) / 5)
	table.insert(levels, {
		L = L, v = vL(L), gap = gapL(L), bpm = 60 * vL(L) / 64, dur = 1024 / vL(L),
		I = 0.12 + 0.56 * B + 0.1, phrase = PHRASES[L],
	})
end
check("I* L1 (table 0.220)", math.floor(levels[1].I * 1000 + 0.5) / 1000, 0.220)
check("I* L10 (table 0.687)", math.floor(levels[10].I * 1000 + 0.5) / 1000, 0.687)

-- main run + determinism
local SEED = tonumber((require("@lune/process").args)[1]) or 0x5EED1
local run = simulate(SEED, 1.0, true)
local again = simulate(SEED, 1.0, true)
local det = serde.encode("json", run.samples) == serde.encode("json", again.samples)
	and serde.encode("json", run.events) == serde.encode("json", again.events)

-- fuzz: 300 seeds x 3 slider settings
local fuzz = { seeds = 0, finished = 0, deaths = 0, certBad = 0, fallbacks = 0, loadViol = 0, nearMisses = 0, times = {} }
for i = 1, 300 do
	for _, sl in { 0, 0.35, 1 } do
		local r = simulate(H32(777, i), sl, false)
		fuzz.seeds += 1
		if r.finished then fuzz.finished += 1 end
		fuzz.deaths += r.deaths
		fuzz.certBad += r.certBad
		fuzz.fallbacks += r.fallbacks
		fuzz.nearMisses += r.nearMisses
		if r.maxLoadViolation > 0 then fuzz.loadViol += 1 end
		if sl == 1 then table.insert(fuzz.times, math.floor(r.time * 10) / 10) end
	end
end

local out = {
	seed = SEED, h32 = { H32(1, 2, 3), H32(CONTENT, SEED, 0, S_GEOM, 0) },
	deterministic = det, checks = checks, levels = levels, run = run, fuzz = fuzz,
}
fs.writeFile("out.json", serde.encode("json", out))
print(string.format("run: %.1fs finished=%s deaths=%d nearMisses=%d nearDeaths=%d certBad=%d fallbacks=%d loadViol=%.4f det=%s",
	run.time, tostring(run.finished), run.deaths, run.nearMisses, run.nearDeaths, run.certBad, run.fallbacks, run.maxLoadViolation, tostring(det)))
print(string.format("fuzz: %d runs finished=%d deaths=%d certBad=%d fallbacks=%d loadViolRuns=%d nearMisses=%d",
	fuzz.seeds, fuzz.finished, fuzz.deaths, fuzz.certBad, fuzz.fallbacks, fuzz.loadViol, fuzz.nearMisses))
for _, c in checks do if not c.ok then print("CHECK FAIL", c.name, c.got, c.want) end end
