--!optimize 2
--[[
	Onslaught+ : the post-release expansion layer (new towers, combos, account progression, passes and products).
	Classic mode never touches this module. Line-for-line port of onslaught-html/expansion.js parts A and B;
	the data is ExpansionData (generated from onslaught-data/expansion.json). Design notes: onslaught-data/DESIGN.md.

	Part A (sim) plugs into Engine through G.mods hooks. Part B (progression) is pure and works on a profile
	table: { level, xp, intel, prestige, research = {id = lvl}, passes = {id = true}, quests, xpBoostUntil }.
]]

-- Roblox resolves siblings through `script`; Lune (tests) resolves the same files by path.
local Engine = if script then require(script.Parent.Engine) else require("./Engine")
local XD = if script then require(script.Parent.ExpansionData) else require("./ExpansionData")

local Expansion = {}
Expansion.XD = XD

local floor, max, min, huge = math.floor, math.max, math.min, math.huge
local E = Engine

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local o = {}
	for k, x in v do
		o[k] = deepCopy(x)
	end
	return o
end
local function concat(a, b)
	local o = table.clone(a)
	for _, x in b do
		table.insert(o, x)
	end
	return o
end
local function find(list, id)
	for _, q in list do
		if q.id == id then
			return q
		end
	end
	return nil
end

-- Unlocks never relock: any Clearance tier counts as the Clearance level (50).
function Expansion.unlockLevel(L): number
	if (L.prestige or 0) > 0 then
		return max(L.level or 1, XD.progression.prestige.level)
	end
	return L.level or 1
end
-- Clearance perks for a tier: { quests, cash, resale, bounty, lives }, summed over every reward at or below it.
function Expansion.clearancePerks(tier: number?)
	local out = { quests = 0, cash = 0, resale = 0, bounty = 0, lives = 0 }
	for _, rw in XD.progression.prestige.rewards do
		if rw.perks and rw.tier <= (tier or 0) then
			for k, v in rw.perks do
				out[k] += v
			end
		end
	end
	return out
end
local clearancePerks = Expansion.clearancePerks

-- ================================================================ A. sim
-- Merge the expansion into a copy of the classic data. `loadout` = { level, research = {id = lvl}, passes = {id = true} }.
function Expansion.data(GAME, loadout)
	loadout = loadout or { level = 1, research = {}, passes = {} }
	local D = deepCopy(GAME)
	local arsenal = loadout.passes ~= nil and loadout.passes.arsenal == true
	for _, k in XD.buildOrder do
		local s = XD.turrets[k]
		local t = { unlock = 0, freak = false, freakLevel = { damage = 4, range = 0, rate = 4 }, modifiable = true, comboNever = false, poison = 0 }
		for key, v in deepCopy(s) do
			t[key] = v
		end
		if arsenal and t.unlock ~= 0 then
			t.unlock = floor(t.unlock / 2)
		end
		local need = if arsenal then 0 else (s.requires and s.requires.level) or 0
		t.levelLocked = if Expansion.unlockLevel(loadout) < need then need else 0
		if t.levelLocked ~= 0 then
			t.unlock = huge -- never unlocks inside this game
		end
		D.turrets[k] = t
	end
	D.buildOrder = concat(GAME.buildOrder, XD.buildOrder)
	D.extraColours = table.clone(XD.extraColours)
	for k, c in XD.combos do
		D.combos[k] = c
	end
	return D
end

local function parseRule(str: string)
	local parts = {}
	for part in string.gmatch(str, "[^&]+") do
		local c, op, v = string.match(part, "^(%w+)([>=]=)(%d+)$")
		assert(c, "bad combo rule " .. str)
		table.insert(parts, { c, op, tonumber(v) })
	end
	return function(n)
		for _, p in parts do
			local have = n[p[1]] or 0
			if p[2] == ">=" then
				if have < p[3] then
					return false
				end
			elseif have ~= p[3] then
				return false
			end
		end
		return true
	end
end
local RULES = {}
for lead, list in XD.rules do
	RULES[lead] = {}
	for i, r in list do
		RULES[lead][i] = { parseRule(r[1]), r[2] }
	end
end
Expansion.RULES = RULES

local function rLevel(L, id)
	return (L.research and L.research[id]) or 0
end
local function researchValue(id, lvl)
	local r = find(XD.research, id)
	return if r then r.per * min(lvl, r.max) else 0
end
Expansion.researchValue = researchValue

local function inRing(t, a, r, mn)
	if not a or a.dead then
		return false
	end
	local d = E.dist(t, a)
	return d <= r and d > mn
end
local function acquireRing(G, t, r, mn, mode)
	local saved = G.attackers
	local near = {}
	for _, a in saved do
		if not a.dead and E.dist(t, a) > mn then
			table.insert(near, a)
		end
	end
	G.attackers = near
	local a = E.acquire(G, t, r, mode)
	G.attackers = saved
	return a
end
local function shell(G, t, target, dmg, blast, extra)
	local m = E.muzzle(t)
	local tx, ty = target.x, target.y
	local d = E.dist(m, { x = tx, y = ty })
	local speed = G.D.turrets.Orange.shellSpeed
	return E.addShot(G, {
		k = "mortar", sx = m.x, sy = m.y, x = m.x, y = m.y, tx = tx, ty = ty, t0 = G.now,
		land = G.now + max(1, E.jsRound(d / speed * 1000)), blast = blast, extra = extra, src = t,
	})
end
local function chain(G, t, from, first, dmg, falloff, jumps, range, slow)
	local hitSet = {}
	local cur, src, d = first, from, dmg
	local i = 0
	while i <= jumps and E.alive(cur) do
		hitSet[cur.id] = true
		E.sparkNow(G, src, cur, d, slow, t, "arc")
		src = { x = cur.x, y = cur.y }
		local best, bd = nil, huge
		for _, a in G.attackers do
			if a.dead or a.holed or hitSet[a.id] then
				continue
			end
			local q = E.dist(src, a)
			if q <= range and q < bd then
				bd = q
				best = a
			end
		end
		cur = best
		d *= falloff
		i += 1
	end
end
-- Points along the road, walking backwards (toward the spawn) from the target
local function roadWalk(G, target, n, spacing)
	local pts = {}
	local x, y = target.x, target.y
	local wp = max(1, (target.wp or 2) - 1) -- road index (1-based) behind the target
	for _ = 1, n do
		table.insert(pts, { x = x, y = y })
		local left = spacing
		while left > 0 and wp >= 1 do
			local p = G.road[wp]
			local d = E.dist({ x = x, y = y }, p)
			if d >= left then
				x += (p.x - x) / d * left
				y += (p.y - y) / d * left
				left = 0
			else
				x, y = p.x, p.y
				left -= d
				wp -= 1
			end
		end
	end
	return pts
end
Expansion.roadWalk = roadWalk

function Expansion.makeMods(loadouts, host)
	local function Lof(pid)
		return loadouts[pid] or host
	end
	local function beaconFor(G, t)
		for _, b in G.turrets do
			if b.kind == "Beacon" and b.active and not b.dead and E.dist(b, t) <= b.base.range then
				return b
			end
		end
		return nil
	end
	local mods = {}
	mods.rules = RULES
	function mods.init(G)
		for _, k in XD.buildOrder do
			if G.D.turrets[k].levelLocked ~= 0 then
				G.unlocked[k] = false
			end
		end
		G.assisted = false
		G.vaultPaid = 0
		G.freeze = 0
	end
	function mods.canBuild(G, pid, kind)
		local d = G.D.turrets[kind]
		if d.limitPerPlayer then
			local n = 0
			for _, t in G.turrets do
				if t.kind == kind and t.owner == pid then
					n += 1
				end
			end
			if n >= d.limitPerPlayer then
				return false
			end
		end
		return true
	end
	function mods.bounty(_G, amount)
		-- the pool is split per player in cashWin; the multiplier is the host's (shared bounty)
		local L = host
		return amount
			* (1 + researchValue("bounty", rLevel(L, "bounty")) + (if L.passes and L.passes.supply then 0.1 else 0) + clearancePerks(L.prestige).bounty)
	end
	function mods.resale(G, t)
		local L = Lof(t.owner)
		return G.D.settings.resale + researchValue("salvage", rLevel(L, "salvage")) + clearancePerks(L.prestige).resale
	end
	function mods.effective(G, t)
		local d = G.D.turrets[t.kind]
		if d.behaviour == "cryo" then
			t.eff.damage = t.base.damage -- strength ignores damage modifiers
		end
		local m = researchValue("m_" .. t.kind, rLevel(Lof(t.owner), "m_" .. t.kind))
		if m ~= 0 then
			t.eff.damage *= 1 + m
		end
	end
	function mods.rechargeMult(G, t)
		local L = Lof(t.owner)
		local m = 1 - researchValue("theory", rLevel(L, "theory"))
		if L.passes and L.passes.combomaster then
			m *= 0.85
		end
		if beaconFor(G, t) then
			m *= XD.turrets.Beacon.modify.combo_recharge
		end
		return m
	end
	function mods.comboDamage(G, t)
		return if beaconFor(G, t) then XD.turrets.Beacon.modify.combo_damage else 1
	end
	function mods.waveSent(G) -- Gold Vault interest
		for _, t in G.turrets do
			if t.kind ~= "Vault" or t.dead then
				continue
			end
			local p = G.players[t.owner]
			if not p then
				continue
			end
			local pay = floor(min(t.base.damage, p.cash * t.base.rate / 100))
			if pay > 0 then
				p.cash += pay
				G.vaultPaid += pay
				E.fx(G, { k = "vault", x = t.x, y = t.y, v = pay })
			end
		end
	end
	function mods.update(G, t, dt)
		local d = G.D.turrets[t.kind]
		local b = d.behaviour
		if b == "vault" then
			return true
		elseif b == "mortar" then
			if not inRing(t, t.target, t.eff.range, d.minRange) then
				t.target = acquireRing(G, t, t.eff.range, d.minRange, t.targetMode)
			end
			if E.alive(t.target) then
				t.bearTo = nil
				E.tryFiring(G, t, t.target, dt)
			end
			return true
		elseif b == "cryo" then
			t.target = E.availOrAcquire(G, t.target, t, t.eff.range, t.targetMode)
			if E.alive(t.target) then
				E.tryFiring(G, t, t.target, dt)
			end
			return true
		elseif b == "arc" then
			return false -- the standard update (aim, fire, combo) is right for it
		elseif b == "orbital" then
			if E.canFire(G, t) then
				local tg = E.acquire(G, t, t.eff.range, "strong")
				if tg then
					E.turretFire(G, t, tg, t.eff.damage)
				end
			end
			return true
		end
		return false
	end
	function mods.fire(G, t, target, dmg, _p)
		local d = G.D.turrets[t.kind]
		local b = d.behaviour
		if b == "mortar" then
			return shell(G, t, target, dmg, { type = "small", dmg = dmg, poison = 1 })
		elseif b == "cryo" then
			for _, a in G.attackers do
				if a.dead or a.holed or E.dist(t, a) > t.eff.range then
					continue
				end
				local cap = a.speedInit / t.eff.damage
				if a.speed > cap then
					a.speed = cap
					E.attackerMove(G, a)
				end
			end
			E.fx(G, { k = "cryo", x = t.x, y = t.y, r = t.eff.range })
			return nil
		elseif b == "arc" then
			local jumps = (d.baseJumps or 2) + floor(t.lvl.rate / 2)
			chain(G, t, E.muzzle(t), target, dmg, d.falloff, jumps, d.jumpRange, if t.eff.poison and t.eff.poison ~= 0 then t.eff.poison else d.poison)
			return nil
		elseif b == "orbital" then
			E.spawnBlast(G, d.blast, target.x, target.y, dmg, 1, t, nil)
			E.fx(G, { k = "orbital", x = target.x, y = target.y })
			return nil
		end
		return nil
	end
	function mods.comboFire(G, t, name, c, target, _silent, h)
		local C = XD.combos[name]
		if name == "carpet_bomb" then
			local pts = roadWalk(G, target, C.blasts, C.spacing)
			E.addShot(G, { k = "carpet", pts = pts, i = 0, next = G.now, timing = C.timing, dmg = h.md(C.blast_damage), src = t })
			h.take()
		elseif name == "cryo_shell" then
			shell(G, t, target, 0, { type = "poison", dmg = h.md(C.blast_damage), poison = C.blast_poison })
			h.take()
		elseif name == "ion_mortar" then
			shell(G, t, target, 0, { type = "large", dmg = h.md(C.blast_damage), poison = 1 }, { arcs = C.arcs, arcDmg = h.md(C.arc_damage) })
			h.take()
		elseif name == "absolute_zero" then
			local dmg = h.md(C.damage)
			for _, a in table.clone(G.attackers) do
				if a.dead or a.holed or E.dist(t, a) > C.radius then
					continue
				end
				a.speed = 5
				E.attackerMove(G, a)
				E.hit(G, a, dmg, t)
			end
			E.fx(G, { k = "freezewave", x = t.x, y = t.y, r = C.radius })
			h.take()
		elseif name == "frost_mine" then
			local maxR = E.upAmountMax(t, "range")
			local pts = {}
			for _, q in G.mines do
				if E.dist(t, q) <= maxR then
					table.insert(pts, q)
				end
			end
			if #pts > 0 then
				local spot = E.arrayPick(G, pts, 1)[1]
				E.addShot(G, {
					k = "mine", x = t.x, y = t.y, sx = t.x, sy = t.y, tx = spot.x, ty = spot.y, t0 = G.now, planted = false,
					twNext = G.now + 32, next = G.now + 150, target = target, src = t, big = true,
					blast = { type = "poison", dmg = h.md(C.blast_damage), poison = C.blast_poison }, cluster = nil,
				})
			end
			h.take()
		elseif name == "ion_field" then
			E.addShot(G, { k = "field", x = target.x, y = target.y, r = C.radius, ["end"] = G.now + C.duration, next = G.now, tick = C.tick, dmg = h.md(C.damage), src = t })
			h.take()
		elseif name == "storm" then
			local link = h.link()
			chain(G, t, h.m, target, h.md(link + C.damage), 1, C.jumps, C.jumpRange, 0)
		end
	end
	function mods.updateShot(G, s)
		if s.k == "mortar" then -- lobbed shell: flies to a fixed point
			if G.now < s.land then
				local r = (G.now - s.t0) / (s.land - s.t0)
				s.x = s.sx + (s.tx - s.sx) * r
				s.y = s.sy + (s.ty - s.sy) * r
				return
			end
			s.x, s.y = s.tx, s.ty
			s.dead = true
			if s.blast then
				E.spawnBlast(G, s.blast.type, s.x, s.y, s.blast.dmg, s.blast.poison, s.src, nil)
			end
			if s.extra and s.extra.arcs then
				local near = {}
				for _, a in G.attackers do
					if not a.dead and not a.holed and E.dist(a, s) <= 150 then
						table.insert(near, a)
					end
				end
				for _, a in E.arrayPick(G, near, min(#near, s.extra.arcs)) do
					E.sparkNow(G, s, a, s.extra.arcDmg, 0, s.src, "arc")
				end
			end
		elseif s.k == "carpet" then
			if G.now < s.next then
				return
			end
			s.next += s.timing
			if s.i >= #s.pts then
				s.dead = true
				return
			end
			s.i += 1
			local p = s.pts[s.i]
			E.spawnBlast(G, "medium", p.x, p.y, s.dmg, 1, s.src, nil)
		elseif s.k == "field" then
			if G.now >= s["end"] then
				s.dead = true
				return
			end
			if G.now < s.next then
				return
			end
			s.next += s.tick
			for _, a in G.attackers do
				if not a.dead and not a.holed and E.dist(a, s) <= s.r then
					E.sparkNow(G, s, a, s.dmg, 0, s.src, "arc")
				end
			end
		end
	end
	function mods.step(G) -- Time Freeze product: every attacker's clock stands still
		if G.freeze > 0 then
			G.freeze -= 1
			for _, a in G.attackers do
				if a.tw then
					a.tw.t0 += 1
					a.tw.next += 1
				end
				if a.rep then
					a.rep.t0 += 1
					a.rep.next += 1
				end
			end
		end
	end
	return mods
end

-- Build the per-game options. `loadouts` maps playerId -> loadout (co-op: each player brings their own research).
function Expansion.gameOpts(opts, loadouts)
	local first = if opts.players then opts.players[1] else "p1"
	local host = loadouts[first]
	if not host then
		for _, L in loadouts do
			host = L
			break
		end
	end
	host = host or { research = {}, passes = {} }
	opts.bonusCash = {}
	local bunker = 0
	for pid, L in loadouts do
		local cp = clearancePerks(L.prestige)
		opts.bonusCash[pid] = researchValue("funds", rLevel(L, "funds")) + (if L.passes and L.passes.supply then 50 else 0) + cp.cash
		bunker = max(bunker, researchValue("bunker", rLevel(L, "bunker")) + cp.lives)
	end
	opts.lives = 10 + bunker
	opts.mods = Expansion.makeMods(loadouts, host)
	return opts
end

-- In-game products (the server validates the purchase; these apply it)
function Expansion.useProduct(G, id, pid, arg)
	local p = find(XD.products, id)
	if not p or (G.over and id ~= "revive") then
		return false
	end
	G.assisted = true
	if id == "drop_s" or id == "drop_m" or id == "drop_l" then
		G.players[pid].cash += 10 * max(1, G.waveNum) * p.waves
		return true
	elseif id == "life" then
		G.livesBought = (G.livesBought or 0) + 1
		if G.livesBought > p.maxPerGame then
			return false
		end
		G.lives += 1
		return true
	elseif id == "freeze" then
		G.freeze += 8000
		E.fx(G, { k = "freeze" })
		return true
	elseif id == "airstrike" then
		local hp = G.energy
		E.spawnBlast(G, "huge", arg.x, arg.y, max(6e7, 3 * hp), 1, nil, nil)
		E.fx(G, { k = "orbital", x = arg.x, y = arg.y })
		return true
	elseif id == "revive" then
		if not G.lost then
			return false
		end
		G.over = false
		G.lost = false
		G.lives = 5
		G.revives = (G.revives or 0) + 1
		for _, a in G.attackers do
			a.dead = true
		end
		G.attackers = {}
		G.waves = {}
		G.waveLast = G.now
		return true
	end
	return false
end
-- Whether a product can be used right now (checked before prompting a purchase, so nobody pays for nothing)
function Expansion.canUseProduct(G, id)
	local p = find(XD.products, id)
	if not p then
		return false
	end
	if id == "revive" then
		return G.lost == true
	end
	if G.over then
		return false
	end
	if id == "life" then
		return (G.livesBought or 0) < p.maxPerGame
	end
	return true
end
function Expansion.revivePrice(G)
	local n = G.revives or 0
	return 99 * 2 ^ n + (if n > 0 then 2 ^ n - 1 else 0)
end

-- ================================================================ B. account progression (pure)
local P = XD.progression
function Expansion.xpToNext(level: number): number
	return E.jsRound(P.levelCurve.base + P.levelCurve.coef * level ^ P.levelCurve.power)
end
function Expansion.gameRewards(G, meta, nowMs: number?)
	local W = G.waveNum
	local d = (if G.challenge then P.xp.difficulty[G.challenge.difficulty] else P.xp.difficulty[G.mode]) or 0
	local passes = meta.passes or {}
	local tier = meta.prestige or 0
	local pb = 1 + tier * P.prestige.bonusPerTier
	local xp = (W * (W + 1) / 2) * d * P.xp.perWave + G.kills * P.xp.perKill * (if d > 0 then 1 else 0)
	if G.challenge and G.won then
		xp += P.xp.challengeWin
	end
	local intel = floor(W ^ P.intel.waveExp * d / P.intel.waveDiv + G.kills / P.intel.perKills * (if d > 0 then 1 else 0))
	local vip = if passes.vip then 1.25 else 1
	local now = nowMs or os.time() * 1000
	xp *= vip * pb * (if meta.xpBoostUntil and meta.xpBoostUntil > now then 2 else 1)
	intel *= vip * pb * (if passes.intel2 then 2 else 1)
	return { xp = E.jsRound(xp), intel = E.jsRound(intel) }
end
function Expansion.addXP(meta, xp: number): number
	meta.xp = (meta.xp or 0) + xp
	meta.level = meta.level or 1
	local ups = 0
	while meta.xp >= Expansion.xpToNext(meta.level) do
		meta.xp -= Expansion.xpToNext(meta.level)
		meta.level += 1
		ups += 1
	end
	meta.totalXP = (meta.totalXP or 0) + xp
	return ups
end
function Expansion.canPrestige(meta): boolean
	return (meta.level or 1) >= P.prestige.level
end
function Expansion.prestige(meta): boolean
	if not Expansion.canPrestige(meta) then
		return false
	end
	meta.prestige = (meta.prestige or 0) + 1
	meta.level = 1
	meta.xp = 0
	return true
end
function Expansion.researchCost(id: string, lvl: number): number?
	local r = find(XD.research, id)
	if r and lvl < r.max then
		return E.jsRound(r.base * r.growth ^ lvl)
	end
	return nil
end
function Expansion.buyResearch(meta, id: string): boolean
	meta.research = meta.research or {}
	local lvl = meta.research[id] or 0
	local c = Expansion.researchCost(id, lvl)
	if c == nil or (meta.intel or 0) < c then
		return false
	end
	meta.intel -= c
	meta.research[id] = lvl + 1
	return true
end
function Expansion.dailyQuests(meta, dateKey: string)
	if meta.quests and meta.quests.date == dateKey then
		return meta.quests
	end
	local s = 0
	for i = 1, #dateKey do
		s = (s * 31 + string.byte(dateKey, i)) % 4294967296
	end
	local pool = table.clone(XD.quests)
	local list = {}
	for _ = 1, 3 + clearancePerks(meta.prestige).quests do
		if #pool == 0 then
			break
		end
		s = (s * 1103515245 + 12345) % 4294967296 -- the same doubles as the JS (s * a + c) >>> 0
		local q = table.remove(pool, (s % #pool) + 1)
		table.insert(list, { id = q.id, progress = 0, done = false })
	end
	meta.quests = { date = dateKey, list = list }
	return meta.quests
end
local DIFF_ORDER = { easy = 0, medium = 1, hard = 2, extreme = 3 }
local function questStats(G)
	local st = {
		combos = G.stats.combos,
		challenge_wins = if G.challenge and G.won then 1 else 0,
		wave_nolife = if G.lives >= (G.startLives or 10) then G.waveNum else 0,
	}
	for _, t in G.turrets do
		st["kills_" .. t.kind] = (st["kills_" .. t.kind] or 0) + t.kills
	end
	for k, v in G.comboCounts or {} do
		st["combo_" .. k] = v
	end
	local mi = DIFF_ORDER[if G.challenge then G.challenge.difficulty else G.mode] or -1
	if mi >= 1 then
		st.wave_medium = G.waveNum
	end
	if mi >= 2 then
		st.wave_hard = G.waveNum
	end
	return st
end
function Expansion.applyQuests(meta, G)
	local q = meta.quests
	if not q then
		return {}
	end
	local st = questStats(G)
	local done = {}
	for _, it in q.list do
		if it.done then
			continue
		end
		local def = find(XD.quests, it.id)
		if not def then
			continue
		end
		local v = st[def.stat] or 0
		if string.sub(def.stat, 1, 4) == "wave" or def.stat == "combos" then
			it.progress = max(it.progress, v)
		else
			it.progress += v
		end
		if it.progress >= def.goal then
			it.done = true
			meta.intel = (meta.intel or 0) + def.intel
			Expansion.addXP(meta, def.xp)
			table.insert(done, def)
		end
	end
	return done
end

return Expansion
