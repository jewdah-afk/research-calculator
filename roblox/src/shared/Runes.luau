--!nonstrict
-- Starter Runes: an altar beside the Mega Board that rolls 10 runes for $10 each.
--
--   Runes 1-5  -> small CASH boosts per copy, capped (copies past the cap just stay maxed)
--   Runes 6-10 -> POINT boosts only (rebirth points / AP / TrP). They never cap: each LEVEL
--                 needs x1.25 more copies than the last, so they keep growing forever but slowly.
--
-- How many runes you get per second:
--   rolls/s = BASE_RATE x 1.05^(orb-drop milestones) x gem Speed x (x2 with the Auto-Roll pass)
--   runes per roll (bulk) = (1 + opening milestones(max +4) + gem Bulk + playtime(+1..+4))
--                           x 1.15^(opening milestones) x playtime bulk multipliers
--   luck = 1.10^(orb-drop milestones) x gem Luck x playtime luck multipliers (x Lucky Tick)
-- Free auto-roll works while standing on the altar pad; the Robux pass rolls anywhere at x2.
-- Everything here is pure math so the browser preview can port it 1:1.

local Big = require(script.Parent.Big)

local Runes = {}

Runes.COST = 10 -- cash per rune opened
Runes.BASE_RATE = 0.5 -- rolls per second on the pad (one roll every 2s)
Runes.PASS_SPEED = 2 -- Auto-Roll gamepass speed multiplier
Runes.PAD_RADIUS = 14 -- studs from the altar centre that count as "standing on it"
Runes.AUTO_PASS_ID = 0 -- TODO: Robux gamepass id for Auto-Roll (x2 speed, rolls anywhere)

-- level for uncapped runes: +1 level each time copies grow x1.25 (1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 19, ...)
Runes.LEVEL_GROWTH = 1.25

Runes.LIST = {
	{ id = 1, name = "Spark", oneIn = 1, stat = "cash", per = 0.005, cap = 50, color = { 255, 214, 74 } },
	{ id = 2, name = "Pebble", oneIn = 3, stat = "cash", per = 0.01, cap = 40, color = { 200, 196, 210 } },
	{ id = 3, name = "Breeze", oneIn = 10, stat = "cash", per = 0.02, cap = 30, color = { 124, 255, 200 } },
	{ id = 4, name = "Tide", oneIn = 40, stat = "cash", per = 0.03, cap = 30, color = { 70, 160, 255 } },
	{ id = 5, name = "Ember", oneIn = 150, stat = "cash", per = 0.05, cap = 30, color = { 255, 106, 31 } },
	{ id = 6, name = "Echo", oneIn = 1e3, stat = "rebirth", perLevel = 0.015, color = { 92, 242, 255 } },
	{ id = 7, name = "Prism", oneIn = 1e4, stat = "rebirth", perLevel = 0.025, color = { 255, 92, 170 } },
	{ id = 8, name = "Halo", oneIn = 1e5, stat = "ap", perLevel = 0.02, color = { 255, 240, 160 } },
	{ id = 9, name = "Crown", oneIn = 1e6, stat = "ap", perLevel = 0.03, color = { 255, 196, 60 } },
	{ id = 10, name = "Eternity", oneIn = 1e7, stat = "trp", perLevel = 0.03, color = { 227, 166, 255 } },
}

-- Gem upgrades (the Rune Forge). cost = base * growth^level gems; the last level of each sits near 1M.
Runes.FORGE = {
	{ id = "bulk", name = "Rune Bulk", desc = "+1 rune per roll", base = 1, growth = 2.5, max = 16 },
	{ id = "speed", name = "Rune Speed", desc = "x1.08 rolls per second", base = 5, growth = 2.6, max = 13 },
	{ id = "luck", name = "Rune Luck", desc = "x1.12 rune luck", base = 2, growth = 2.5, max = 16 },
	{ id = "clone", name = "Rune Clone", desc = "+2% chance each rune is doubled", base = 25, growth = 2.8, max = 11 },
	{ id = "tick", name = "Lucky Tick", desc = "every 25th roll gets +50% luck", base = 50, growth = 3, max = 10 },
}
Runes.forgeById = {}
for _, u in Runes.FORGE do
	Runes.forgeById[u.id] = u
end

-- Playtime on the altar pad (saved forever). Bulk "+N" bonuses replace each other (max +4);
-- every multiplier stacks.
Runes.PLAYTIME = {
	{ minutes = 1, bulkAdd = 1 },
	{ minutes = 5, luck = 1.05 },
	{ minutes = 15, bulk = 1.10 },
	{ minutes = 30, bulkAdd = 2 },
	{ minutes = 60, luck = 1.10 },
	{ minutes = 120, bulk = 1.25 },
	{ minutes = 180, bulkAdd = 3 },
	{ minutes = 360, luck = 1.25 },
	{ minutes = 720, bulk = 1.5 },
	{ minutes = 960, bulkAdd = 4 },
	{ minutes = 1200, luck = 1.5 },
	{ minutes = 1440, bulk = 2 },
}

---------------------------------------------------------------- state

function Runes.newState()
	return {
		counts = table.create(#Runes.LIST, 0),
		opened = 0,
		padSeconds = 0,
		rolls = 0,
		acc = 0,
		carry = { rebirth = 0, ap = 0, trp = 0 },
		forge = { bulk = 0, speed = 0, luck = 0, clone = 0, tick = 0 },
	}
end

function Runes.ensure(data)
	local s = data.runes or {}
	local fresh = Runes.newState()
	for k, v in fresh do
		if type(s[k]) ~= type(v) then
			s[k] = v
		end
	end
	for i = 1, #Runes.LIST do
		s.counts[i] = s.counts[i] or 0
	end
	for k in fresh.carry do
		s.carry[k] = s.carry[k] or 0
	end
	for k in fresh.forge do
		s.forge[k] = s.forge[k] or 0
	end
	data.runes = s
	return s
end

---------------------------------------------------------------- milestones: 10, 100, 500, 1K, 5K, 10K, 50K, ...

function Runes.milestone(n: number): number
	if n == 1 then
		return 10
	end
	-- n=2 -> 100, 3 -> 500, 4 -> 1000, 5 -> 5000, 6 -> 10000, ...
	if n % 2 == 0 then
		return 10 ^ (n / 2 + 1)
	end
	return 5 * 10 ^ ((n + 1) / 2)
end

function Runes.milestonesReached(total: number): number
	if total < 10 then
		return 0
	end
	-- 2 per decade after the first: count directly (cheap, < 40 steps for any double)
	local n = 0
	while total >= Runes.milestone(n + 1) do
		n += 1
	end
	return n
end

---------------------------------------------------------------- derived stats

local function playtime(s)
	local add, bulk, luck = 0, 1, 1
	local minutes = s.padSeconds / 60
	for _, p in Runes.PLAYTIME do
		if minutes >= p.minutes then
			if p.bulkAdd then
				add = math.max(add, p.bulkAdd)
			end
			bulk *= p.bulk or 1
			luck *= p.luck or 1
		end
	end
	return add, bulk, luck
end

function Runes.stats(data, hasPass: boolean?)
	local s = Runes.ensure(data)
	local mOpen = Runes.milestonesReached(s.opened)
	local mBalls = Runes.milestonesReached(data.orbsSpawned or 0)
	local ptAdd, ptBulk, ptLuck = playtime(s)
	local f = s.forge
	return {
		bulk = math.max(1, math.floor((1 + math.min(4, mOpen) + f.bulk + ptAdd) * 1.15 ^ mOpen * ptBulk)),
		rate = Runes.BASE_RATE * 1.05 ^ mBalls * 1.08 ^ f.speed * (hasPass and Runes.PASS_SPEED or 1),
		luck = 1.10 ^ mBalls * 1.12 ^ f.luck * ptLuck,
		clone = math.min(0.5, 0.02 * f.clone),
		tickLuck = 1 + 0.5 * f.tick,
		openMilestones = mOpen,
		ballMilestones = mBalls,
		nextOpen = Runes.milestone(mOpen + 1),
		nextBalls = Runes.milestone(mBalls + 1),
	}
end

-- level of an uncapped rune from its copies
function Runes.level(copies: number): number
	if copies < 1 then
		return 0
	end
	return math.floor(math.log(copies) / math.log(Runes.LEVEL_GROWTH) + 1e-9) + 1
end

-- copies needed for the next level (for the UI)
function Runes.nextLevelAt(copies: number): number
	local L = Runes.level(copies)
	return math.max(copies + 1, math.ceil(Runes.LEVEL_GROWTH ^ L - 1e-9))
end

-- current boost of one rune (fraction, e.g. 0.25 = +25%)
function Runes.boost(r, copies: number): number
	if r.cap then
		return math.min(copies, r.cap) * r.per
	end
	return Runes.level(copies) * r.perLevel
end

-- totals per stat: cash / rebirth / ap / trp (fractions)
function Runes.totals(data)
	local s = data.runes
	local t = { cash = 0, rebirth = 0, ap = 0, trp = 0 }
	if not s then
		return t
	end
	for i, r in Runes.LIST do
		t[r.stat] += Runes.boost(r, s.counts[i] or 0)
	end
	return t
end

-- Whole points from a fractional boost: bonus builds up in `carry` until it makes a full point.
function Runes.applyPoints(data, stat: string, base: number): number
	local s = Runes.ensure(data)
	local raw = base * (1 + Runes.totals(data)[stat]) + s.carry[stat]
	local whole = math.floor(raw + 1e-9)
	s.carry[stat] = raw - whole
	return whole
end

---------------------------------------------------------------- rolling

-- one rune from a uniform roll, rarest first
local function pick(luck: number, u: number): number
	for i = #Runes.LIST, 2, -1 do
		if u < luck / Runes.LIST[i].oneIn then
			return i
		end
	end
	return 1
end
Runes.pick = pick

-- Open `rolls` rolls (each gives `bulk` runes). Pays $10 per rune; opens fewer if cash runs out.
-- Big batches use expected counts per rune so huge bulk never loops thousands of times.
-- Returns { [runeIndex] = copiesGained }, runesOpened
function Runes.open(data, rolls: number, hasPass: boolean?, rng)
	local s = Runes.ensure(data)
	local st = Runes.stats(data, hasPass)
	local want = rolls * st.bulk
	local afford = Big.toNumber(Big.div(data.money, Runes.COST))
	local n = math.floor(math.min(want, afford == afford and afford or 0))
	if n < 1 then
		return {}, 0
	end
	data.money = Big.sub(data.money, Big.mul(Big.new(n), Runes.COST))
	local gained = {}
	local function add(i, c)
		gained[i] = (gained[i] or 0) + c
	end
	local r = rng or Random.new()
	if n <= 250 then
		for k = 1, n do
			local rollIndex = s.rolls + math.ceil(k / st.bulk)
			local luck = st.luck * ((rollIndex % 25 == 0) and st.tickLuck or 1)
			local i = pick(luck, r:NextNumber())
			add(i, (r:NextNumber() < st.clone) and 2 or 1)
		end
	else
		-- expected counts, rarest first, with the fraction resolved randomly
		local left = n
		for i = #Runes.LIST, 2, -1 do
			local p = math.min(1, st.luck / Runes.LIST[i].oneIn)
			local e = left * p
			local c = math.floor(e) + ((r:NextNumber() < e % 1) and 1 or 0)
			c = math.min(c, left)
			if c > 0 then
				add(i, c)
				left -= c
			end
		end
		if left > 0 then
			add(1, left)
		end
		for i, c in gained do
			gained[i] = c + math.floor(c * st.clone + r:NextNumber())
		end
	end
	for i, c in gained do
		s.counts[i] += c
	end
	s.opened += n
	s.rolls += math.ceil(n / st.bulk)
	return gained, n
end

-- Called every second by the server. Auto-rolls while on the pad (free, x1) or anywhere with the pass (x2).
function Runes.tick(data, dt: number, onPad: boolean, hasPass: boolean, rng)
	local s = Runes.ensure(data)
	if onPad then
		s.padSeconds += dt
	end
	if not (onPad or hasPass) then
		s.acc = 0
		return {}, 0
	end
	local st = Runes.stats(data, hasPass)
	s.acc += dt * st.rate
	local rolls = math.floor(s.acc)
	if rolls < 1 then
		return {}, 0
	end
	s.acc -= rolls
	return Runes.open(data, rolls, hasPass, rng)
end

---------------------------------------------------------------- forge

function Runes.forgeCost(data, id: string)
	local u = Runes.forgeById[id]
	local lv = Runes.ensure(data).forge[id]
	if not u or lv >= u.max then
		return nil
	end
	return Big.new(math.floor(u.base * u.growth ^ lv + 0.5))
end

function Runes.buyForge(data, id: string): boolean
	local cost = Runes.forgeCost(data, id)
	if not cost or Big.lt(data.diamonds, cost) then
		return false
	end
	data.diamonds = Big.sub(data.diamonds, cost)
	data.runes.forge[id] += 1
	return true
end

return Runes
