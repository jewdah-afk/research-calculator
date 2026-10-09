--!nonstrict
-- Park (Birb map 0): the egg field, pickups, awards, seed ticks, income rates and the Phase 1 step, written fresh from
-- the playtest (playtest/js/systems.js PT.Field / PT.award, main.js step). Server only; pure Luau (no Instances), so
-- the lune parity harness (roblox/tools/parity) runs it unchanged.
--
-- Coordinates are Birb field px. Birb's Park field is 1056 x 792 with a 40 px margin (eggs spawn in x 40 + u * 976,
-- y 40 + u * 712); Peckwood's Park is MapData px (40 x 30 tiles of 16 px), so Main passes its own spawn box (x0, sx,
-- y0, sy = origin and span), a spawnOk test (the fenced egg yard) and a fallback spot in rt.geom.
-- Radii stay Birb px; studs = px / Map.PX * S.
--
-- rt = the per-player runtime (never saved): see Park.newRuntime. rt.rng.type / pos / sparrow are uniform [0, 1)
-- sources; the harness feeds them seeded streams, the server one Random each.
local function shared(name)
	if script then return require(game:GetService("ReplicatedStorage"):WaitForChild("Peckwood"):WaitForChild("Birb"):WaitForChild(name)) end
	return nil
end
local R = (shared("Rules") or require("../../shared/Birb/Rules")) :: any
local EN = R.EN

local Park = {}
Park.R = R

-- V8's Math.hypot (max-normalised Kahan sum): sparrow flight must round exactly like the playtest
local function hypot(a: number, b: number): number
	a, b = math.abs(a), math.abs(b)
	if a ~= a or b ~= b then return 0 / 0 end
	local m = math.max(a, b)
	if m == math.huge then return math.huge end
	if m == 0 then return 0 end
	local sum, comp = 0, 0
	local n = a / m
	local summand = n * n - comp
	local pre = sum + summand
	comp = (pre - sum) - summand
	sum = pre
	n = b / m
	summand = n * n - comp
	pre = sum + summand
	sum = pre
	return math.sqrt(sum) * m
end
Park.hypot = hypot

-- ---------------------------------------------------------------- runtime
Park.BIRB_GEOM = { x0 = 40, sx = 1056 - 2 * 40, y0 = 40, sy = 792 - 2 * 40, cx = 528, cy = 396 }
function Park.newRuntime(geom, rng)
	return {
		geom = geom or Park.BIRB_GEOM,
		rng = rng,
		field = { lists = {}, timers = {}, nextId = 1, byId = {} },
		sparrows = {}, anchor = nil, sparrowAcc = 0, defaultAnchor = { x = (geom or Park.BIRB_GEOM).cx, y = (geom or Park.BIRB_GEOM).cy },
		rates = {}, gainAcc = {}, rateT = 0,
		seedTimer = 0, holdFeed = false,
		map = 0, player = { x = (geom or Park.BIRB_GEOM).cx, y = (geom or Park.BIRB_GEOM).cy }, onPlatform = false,
		events = nil,          -- set to a table to receive { kind, ... } records (server replication)
		claimed = {},          -- reused scratch (no per-frame allocations)
		moved = false,         -- Gravity Field moved eggs since the last replication
		s = nil,               -- the state this runtime last stepped (the collect callbacks read it)
	}
end
local function bindCallbacks(rt)
	if rt.onPlayer then return end
	rt.onPlayer = function(p) Park.award(rt.s, rt, p, "player") end
end
local function emit(rt, a, b, c, d, e)
	local ev = rt.events
	if ev then table.insert(ev, { a, b, c, d, e }) end
end
function Park.gain(rt, k: string, v)
	rt.gainAcc[k] = (rt.gainAcc[k] or 0) + (if type(v) == "number" then v else EN.toNumber(v))
end

-- ---------------------------------------------------------------- field (PT.Field)
local function list(rt, m)
	local f = rt.field
	local l = f.lists[m]
	if not l then l = {}; f.lists[m] = l end
	return l
end
Park.list = list
function Park.clearField(rt)
	local f = rt.field
	table.clear(f.lists); table.clear(f.timers); table.clear(f.byId)
	emit(rt, "clear")
end
function Park.take(rt, m, id)
	if id == nil then return nil end
	local arr = list(rt, m)
	for i, p in arr do
		if p.id == id then
			table.remove(arr, i)
			rt.field.byId[id] = nil
			return p
		end
	end
	return nil
end
-- Birb wI.spawnPopcorn: 40 px margin; a spawn inside the bird's reach is collected at once (its id is still used)
local function spawn(s, rt, m, ctx)
	local g, f = rt.geom, rt.field
	local ty = R.rollType(s, rt.rng.type())
	local p = { id = f.nextId, type = ty, x = 0, y = 0 }
	f.nextId += 1
	p.x = g.x0 + rt.rng.pos() * g.sx
	p.y = g.y0 + rt.rng.pos() * g.sy
	if g.spawnOk then   -- keep eggs on open ground (Peckwood's egg yard), as the playtest's game3d does
		local k = 0
		while k < 24 and not g.spawnOk(p.x, p.y) do
			p.x = g.x0 + rt.rng.pos() * g.sx
			p.y = g.y0 + rt.rng.pos() * g.sy
			k += 1
		end
		if not g.spawnOk(p.x, p.y) and g.fallback then p.x, p.y = g.fallback(rt.rng.pos) end
	end
	if ctx then
		local dx, dy, r = p.x - ctx.px, p.y - ctx.py, ctx.immediateRadius
		if dx * dx + dy * dy <= r * r then ctx.onImmediate(p); return end
	end
	table.insert(list(rt, m), p)
	f.byId[p.id] = p
	emit(rt, "spawn", p.id, p.x, p.y, p.type)
end
-- Birb wI.update: the spawn timer only runs while below the cap; Gravity Field drifts eggs toward the bird
function Park.updateField(s, rt, dt, m, cap, interval, ctx)
	local arr = list(rt, m)
	local c = rt.field.timers[m] or 0
	if #arr < cap then
		c += dt
		local l = math.max(1e-4, interval)
		local room = cap - #arr
		while c >= l and room > 0 do
			c -= l
			spawn(s, rt, m, ctx)
			room -= 1
		end
	end
	rt.field.timers[m] = c
	if ctx and R.hasSun(s, "d_gravity_field") then
		local step, r = 50 * dt, 1.1 * ctx.legacyRadius
		for _, e in arr do
			local dx, dy = ctx.px - e.x, ctx.py - e.y
			local d = hypot(dx, dy)
			if d < r and d > 10 then e.x += (dx / d) * step; e.y += (dy / d) * step; rt.moved = true end
		end
	end
end
-- Birb wI.updatePlayerPickup: collect inside the radius, magnet pulls between radius and magnet radius
function Park.pickup(rt, m, px, py, prof, dt, onCollect)
	local arr = list(rt, m)
	local n = prof.collectRadius
	local i = math.max(n, prof.magnetRadius)
	local a, r, step = n * n, i * i, prof.magnetSpeed * dt
	for c = #arr, 1, -1 do
		local p = arr[c]
		local ox, oy = p.x - px, p.y - py
		local u = ox * ox + oy * oy
		if u <= a then
			table.remove(arr, c); rt.field.byId[p.id] = nil
			onCollect(p)
		elseif step > 0 and u <= r then
			local g = math.sqrt(u)
			local f = math.min(step, math.max(0, g - n))
			if f > 0 and g > 1e-4 then
				p.x -= (ox / g) * f; p.y -= (oy / g) * f
				rt.moved = true
				if g - f <= n + 0.001 then table.remove(arr, c); rt.field.byId[p.id] = nil; onCollect(p) end
			end
		end
	end
end

-- ---------------------------------------------------------------- awards (PT.award)
-- give(s, cur, v) credits a wallet (Game passes its shop-pass multiplier in through Park.give); returns the credited value
Park.give = function(s, cur, v) R.add(s, cur, v); return v end
function Park.award(s, rt, p, who: string)
	local o = R.collectionMultiplier(s)
	if who == "sparrow" then
		local base = R.SPARROW_EGG_XP[p.type] or 1
		s.sparrow.xp += base * R.sparrowXpMult(s, false)
		o *= (if R.hasSun(s, "d_mecha_birb") then 2 else 1) * (if R.hasSun(s, "d_sparrow_hoard") then 5 else 1)
	end
	local v = EN.fromNumber(math.floor(R.TYPE_BY_ID[p.type].baseValue * o))
	local credited = Park.give(s, "popcorn", v)
	s.stats.totalPopcorn = (s.stats.totalPopcorn or 0) + EN.toNumber(credited)   -- Birb totalPopcornCollected
	Park.gain(rt, "popcorn", credited)
	emit(rt, "collect", p.id, credited, who, p.type)
	return credited
end

-- ---------------------------------------------------------------- the Phase 1 step (playtest main.js step, Phase 1 parts)
-- rt.map = Birb map id where the bird stands (0 Park, 1 Sunflower Field, 2 Bridge, 3 Castle, ...), rt.player = its
-- field px on the Park, rt.onPlatform = standing on the seed platform. Sparrow / Castle are passed in to avoid cycles.
local RATE_KEYS = { "popcorn", "sunflowerSeeds", "goldenFeathers", "moneta", "goldenPopcorn", "daveXp" }
local ctxBuf = { px = 0, py = 0, immediateRadius = 0, legacyRadius = 0, onImmediate = nil }
function Park.step(s, rt, dt, Sparrow, Castle)
	rt.s = s
	bindCallbacks(rt)
	s.stats.playTime += dt
	local prof = R.pickupProfile(s, rt.prof)
	rt.prof = prof
	local bonus = R.hooks.pickupBonus(s)
	if bonus ~= 1 then prof.collectRadius *= bonus; prof.magnetRadius *= bonus end
	local here = rt.map == 0
	if here or s.sparrow.unlocked then
		local ctx = nil
		if here then
			ctx = ctxBuf
			ctx.px, ctx.py = rt.player.x, rt.player.y
			ctx.immediateRadius, ctx.legacyRadius = prof.collectRadius, R.legacyRadius(s)
			ctx.onImmediate = rt.onPlayer
		end
		Park.updateField(s, rt, dt, 0, R.maxPopcorn(s), R.spawnInterval(s), ctx)
	end
	if here then Park.pickup(rt, 0, rt.player.x, rt.player.y, prof, dt, rt.onPlayer) end
	-- seeds (Birb seedTimer: whole ticks only)
	local tps, perTick = R.seedRate(s, rt.onPlatform == true)
	if tps > 0 then
		rt.seedTimer += dt * tps
		if rt.seedTimer >= 1 then
			local n = math.floor(rt.seedTimer)
			rt.seedTimer -= n
			local v = Park.give(s, "sunflowerSeeds", n * perTick)
			Park.gain(rt, "sunflowerSeeds", v)
		end
	end
	Sparrow.update(s, rt, dt)
	if rt.holdFeed and rt.map == 3 and s.evo.talked and (s.evolutionCount or 0) < 5 and (s.evo.progress or 0) < 100 then Castle.feed(s, 10 * dt) end
	-- per-second income rates (Birb currencyRates; the seed feeder reads rates.sunflowerSeeds)
	rt.rateT += dt
	if rt.rateT >= 1 then
		for _, k in RATE_KEYS do
			local r = (rt.gainAcc[k] or 0) / rt.rateT
			rt.rates[k] = if rt.rates[k] == nil then r else rt.rates[k] * 0.6 + r * 0.4
			rt.gainAcc[k] = 0
		end
		rt.rateT = 0
	end
end

return Park
