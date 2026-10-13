--!optimize 2
--[[
	Server -> client game state, packed into buffers.

	A snapshot carries what moves every frame (attackers, shots, turret aim) as compact binary, plus the
	visual events (fx) the engine produced since the last snapshot. Turret details (levels, modes, owners)
	only change on player actions, so the server sends them separately when they change (see Match).

	Pure Luau (buffer library only), so it runs in Lune tests and on both Roblox sides.
]]

local Snapshot = {}

-- ================================================================ writer / reader
type Writer = { b: buffer, n: number }

local function newWriter(cap: number): Writer
	return { b = buffer.create(cap), n = 0 }
end
local function ensure(w: Writer, k: number)
	local len = buffer.len(w.b)
	if w.n + k > len then
		local nb = buffer.create(math.max(len * 2, w.n + k))
		buffer.copy(nb, 0, w.b, 0, w.n)
		w.b = nb
	end
end
local function u8(w: Writer, v: number)
	ensure(w, 1)
	buffer.writeu8(w.b, w.n, v)
	w.n += 1
end
local function u16(w: Writer, v: number)
	ensure(w, 2)
	buffer.writeu16(w.b, w.n, v)
	w.n += 2
end
local function u32(w: Writer, v: number)
	ensure(w, 4)
	buffer.writeu32(w.b, w.n, v)
	w.n += 4
end
local function i16(w: Writer, v: number)
	ensure(w, 2)
	buffer.writei16(w.b, w.n, math.clamp(v, -32768, 32767))
	w.n += 2
end
local function f32(w: Writer, v: number)
	ensure(w, 4)
	buffer.writef32(w.b, w.n, v)
	w.n += 4
end
local function f64(w: Writer, v: number)
	ensure(w, 8)
	buffer.writef64(w.b, w.n, v)
	w.n += 8
end
local function str(w: Writer, s: string)
	local n = math.min(#s, 255)
	u8(w, n)
	ensure(w, n)
	buffer.writestring(w.b, w.n, s, n)
	w.n += n
end
local function finish(w: Writer): buffer
	local out = buffer.create(w.n)
	buffer.copy(out, 0, w.b, 0, w.n)
	return out
end

type Reader = { b: buffer, n: number }
local function ru8(r: Reader): number
	local v = buffer.readu8(r.b, r.n)
	r.n += 1
	return v
end
local function ru16(r: Reader): number
	local v = buffer.readu16(r.b, r.n)
	r.n += 2
	return v
end
local function ru32(r: Reader): number
	local v = buffer.readu32(r.b, r.n)
	r.n += 4
	return v
end
local function ri16(r: Reader): number
	local v = buffer.readi16(r.b, r.n)
	r.n += 2
	return v
end
local function rf32(r: Reader): number
	local v = buffer.readf32(r.b, r.n)
	r.n += 4
	return v
end
local function rf64(r: Reader): number
	local v = buffer.readf64(r.b, r.n)
	r.n += 8
	return v
end
local function rstr(r: Reader): string
	local n = ru8(r)
	local s = buffer.readstring(r.b, r.n, n)
	r.n += n
	return s
end

-- ================================================================ schemas
local SHOT_KINDS = { "shell", "rocket", "bomb", "mine", "hole", "walker", "napalm", "rail", "mortar", "carpet", "field" }
local VARIANTS = { "rocket", "bfg", "bfgtazer", "nuke", "napalm", "poison", "tazerrocket", "laserrocket" }
local function index(list)
	local m = {}
	for i, v in list do
		m[v] = i
	end
	return m
end
local SHOT_INDEX, VARIANT_INDEX = index(SHOT_KINDS), index(VARIANTS)

-- fx kind -> fields: f = f32, d = f64 (damage and money can pass 3e38... and need exact display), s = string, u = u32
local FX = {
	{ "laser", { { "x1", "f" }, { "y1", "f" }, { "x2", "f" }, { "y2", "f" }, { "dmg", "d" } } },
	{ "spark", { { "x1", "f" }, { "y1", "f" }, { "x2", "f" }, { "y2", "f" }, { "dmg", "d" }, { "look", "s" } } },
	{ "rail", { { "x1", "f" }, { "y1", "f" }, { "x2", "f" }, { "y2", "f" }, { "dmg", "d" } } },
	{ "sniper", { { "x1", "f" }, { "y1", "f" }, { "x2", "f" }, { "y2", "f" } } },
	{ "take", { { "x1", "f" }, { "y1", "f" }, { "x2", "f" }, { "y2", "f" } } },
	{ "absorb", { { "x1", "f" }, { "y1", "f" }, { "x2", "f" }, { "y2", "f" } } },
	{ "paint", { { "x1", "f" }, { "y1", "f" }, { "x2", "f" }, { "y2", "f" } } },
	{ "blast", { { "type", "s" }, { "x", "f" }, { "y", "f" }, { "size", "f" } } },
	{ "kill", { { "x", "f" }, { "y", "f" }, { "b", "d" } } },
	{ "sell", { { "x", "f" }, { "y", "f" }, { "v", "d" } } },
	{ "vault", { { "x", "f" }, { "y", "f" }, { "v", "d" } } },
	{ "combo", { { "name", "s" }, { "x", "f" }, { "y", "f" }, { "id", "u" } } },
	{ "comboready", { { "id", "u" } } },
	{ "freak", { { "id", "u" } } },
	{ "freakwarn", { { "id", "u" } } },
	{ "focus", { { "id", "u" } } },
	{ "cryo", { { "x", "f" }, { "y", "f" }, { "r", "f" } } },
	{ "freezewave", { { "x", "f" }, { "y", "f" }, { "r", "f" } } },
	{ "orbital", { { "x", "f" }, { "y", "f" } } },
	{ "swallow", { { "x", "f" }, { "y", "f" } } },
	{ "holed", { { "x", "f" }, { "y", "f" } } },
	{ "mine", { { "x", "f" }, { "y", "f" } } },
	{ "wave", { { "n", "u" } } },
	{ "life", { { "lives", "u" } } },
	{ "gameover", { { "why", "s" } } },
	{ "limit", { { "why", "s" } } },
	{ "unlock", { { "kind", "s" } } },
	{ "freeze", {} },
	{ "win", {} },
}
local FX_INDEX = {}
for i, e in FX do
	FX_INDEX[e[1]] = i
end
Snapshot.FX_KINDS = FX_INDEX

local function writeField(w: Writer, t: string, v: any)
	if t == "f" then
		f32(w, v or 0)
	elseif t == "d" then
		f64(w, v or 0)
	elseif t == "u" then
		u32(w, math.clamp(math.floor(v or 0), 0, 4294967295))
	else
		str(w, tostring(v or ""))
	end
end
local function readField(r: Reader, t: string): any
	if t == "f" then
		return rf32(r)
	elseif t == "d" then
		return rf64(r)
	elseif t == "u" then
		return ru32(r)
	end
	return rstr(r)
end

-- ================================================================ encode (server)
-- `fxList` is G.fx (the caller clears it). Unknown fx kinds are skipped, so new engine fx never break old clients.
function Snapshot.encode(G, fxList): buffer
	local w = newWriter(2048)
	f64(w, G.now)
	-- attackers
	local atk = G.attackers
	local na = 0
	for _, a in atk do
		if not a.dead then
			na += 1
		end
	end
	u16(w, na)
	for _, a in atk do
		if a.dead then
			continue
		end
		u32(w, a.id)
		u8(w, a.type)
		f32(w, a.x)
		f32(w, a.y)
		i16(w, math.floor(a.rot + 0.5))
		u8(w, math.clamp(math.ceil(a.energy / a.start * 100), 1, 100))
		u8(w, if a.speed < a.speedInit - 0.01 then math.clamp(math.floor((1 - a.speed / a.speedInit) * 255), 1, 255) else 0)
		f32(w, a.scale or 1)
		u8(w, if a.holed then 1 else 0)
	end
	-- shots
	local ns = 0
	for _, s in G.shots do
		if not s.dead and SHOT_INDEX[s.k] then
			ns += 1
		end
	end
	u16(w, ns)
	for _, s in G.shots do
		local k = SHOT_INDEX[s.k]
		if s.dead or not k then
			continue
		end
		u32(w, s.id)
		u8(w, k)
		u8(w, VARIANT_INDEX[s.variant or "rocket"] or 1)
		f32(w, s.x or s.x1 or 0)
		f32(w, s.y or s.y1 or 0)
		i16(w, math.floor((s.rot or s.angle or 0) + 0.5))
		f32(w, s.r or s.tier or 0)
		u8(w, (if s.big then 1 else 0) + (if s.planted then 2 else 0) + (if s.closing then 4 else 0))
	end
	-- turret aim and state
	u16(w, #G.turrets)
	for _, t in G.turrets do
		u32(w, t.id)
		i16(w, math.floor((t.rot or 0) * 10 + 0.5))
		local ready = t.comboCapable and G.now >= (t.comboNext or 0)
		local stage = if t.freak then math.clamp(t.freak.stage or 1, 1, 3) else 0
		u8(w, (if ready then 1 else 0) + stage * 2)
	end
	-- fx
	local nfx = 0
	for _, f in fxList do
		if FX_INDEX[f.k] then
			nfx += 1
		end
	end
	u16(w, nfx)
	for _, f in fxList do
		local i = FX_INDEX[f.k]
		if not i then
			continue
		end
		u8(w, i)
		for _, field in FX[i][2] do
			writeField(w, field[2], f[field[1]])
		end
	end
	return finish(w)
end

-- ================================================================ decode (client)
function Snapshot.decode(b: buffer)
	local r: Reader = { b = b, n = 0 }
	local out = { now = rf64(r), attackers = {}, shots = {}, turrets = {}, fx = {} }
	for i = 1, ru16(r) do
		out.attackers[i] = {
			id = ru32(r), type = ru8(r), x = rf32(r), y = rf32(r), rot = ri16(r), hp = ru8(r),
			slow = ru8(r) / 255, scale = rf32(r), holed = ru8(r) == 1,
		}
	end
	for i = 1, ru16(r) do
		local s = { id = ru32(r), k = SHOT_KINDS[ru8(r)], variant = VARIANTS[ru8(r)], x = rf32(r), y = rf32(r), rot = ri16(r), r = rf32(r) }
		local flags = ru8(r)
		s.big, s.planted, s.closing = bit32.btest(flags, 1), bit32.btest(flags, 2), bit32.btest(flags, 4)
		out.shots[i] = s
	end
	for _ = 1, ru16(r) do
		local id = ru32(r)
		local rot = ri16(r) / 10
		local flags = ru8(r)
		out.turrets[id] = { rot = rot, ready = bit32.btest(flags, 1), freak = bit32.rshift(flags, 1) }
	end
	for i = 1, ru16(r) do
		local e = FX[ru8(r)]
		local f = { k = e[1] }
		for _, field in e[2] do
			f[field[1]] = readField(r, field[2])
		end
		out.fx[i] = f
	end
	return out
end

-- ================================================================ details (tables; sent when they change)
-- Everything the client UI needs about a turret: what it is, who owns it, levels, modes, combo state.
function Snapshot.turretDetails(G)
	local list = {}
	for i, t in G.turrets do
		list[i] = {
			id = t.id, kind = t.kind, owner = t.owner, x = t.x, y = t.y, type = t.type,
			lvl = { damage = t.lvl.damage, range = t.lvl.range, rate = t.lvl.rate },
			eff = { damage = t.eff.damage, range = t.eff.range, rate = t.eff.rate, poison = t.eff.poison },
			baseRange = t.base.range, value = t.value, kills = t.kills, targetMode = t.targetMode,
			reacquire = t.reacquire, dir = t.dir and { deg = t.dir.deg, spread = t.dir.spread } or nil,
			comboCapable = t.comboCapable, comboNever = t.comboNever, combo = t.combo, colour = t.colour,
			joins = t.joins and #t.joins or nil, freakCapable = t.freakCapable,
		}
	end
	return list
end
-- A cheap fingerprint of turretDetails, so the server only resends when something changed.
function Snapshot.turretSignature(G): string
	local parts = table.create(#G.turrets)
	for i, t in G.turrets do
		parts[i] = string.format(
			"%d|%s|%g,%g|%d%d%d|%s|%s|%s|%s|%s|%g|%g|%g|%d|%s",
			t.id, t.owner, t.x, t.y, t.lvl.damage, t.lvl.range, t.lvl.rate, t.targetMode, tostring(t.reacquire),
			if t.dir then t.dir.deg .. "/" .. t.dir.spread else "-", tostring(t.comboCapable), tostring(t.combo),
			t.eff.damage, t.eff.range, t.eff.rate, t.kills, if t.joins then tostring(#t.joins) else "-"
		)
	end
	return table.concat(parts, ";")
end
-- Header: the HUD numbers. Cash is per player (co-op wallets).
function Snapshot.header(G)
	local cash = {}
	for pid, p in G.players do
		cash[pid] = p.cash
	end
	return {
		now = G.now, wave = G.waveNum, lives = G.lives, kills = G.kills, energy = G.energy,
		waveLast = G.waveLast, waveSpacing = G.waveSpacing, waveFollow = G.waveFollow,
		over = G.over, won = G.won, lost = G.lost, noMoreWaves = G.noMoreWaves, cash = cash,
		waveLimit = G.waveLimit, killTarget = G.killTarget, timeLimit = G.timeLimit, turretLimit = G.turretLimit,
		unlocked = table.clone(G.unlocked), assisted = G.assisted, freeze = G.freeze, revives = G.revives or 0,
		livesBought = G.livesBought or 0,
	}
end

return Snapshot
