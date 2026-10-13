-- Parity trace (Luau side). lune run test/parity/trace.luau [scenario] > lua.jsonl ; mirrors trace.js.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local E = require("../../src/shared/Onslaught/Engine")
local GAME = require("../../src/shared/Onslaught/Data")

local SC = serde.decode("json", fs.readFile("test/parity/scenarios.json"))
local only = process.args[1]
local Q = { { 0, 0 }, { -36, -8 }, { 36, -8 }, { 0, -36 }, { -36, -44 }, { 36, -44 } }
local STATS = { "damage", "rate", "range" }

local function spots(G, range)
	local out = {}
	for y = 24, 456, 12 do
		for x = 24, 696, 12 do
			if E.canBuildAt(G, "Blue", x, y, nil) then
				local cover = 0
				for _, m in G.mines do
					local dx, dy = m.x - x, m.y - y
					if math.sqrt(dx * dx + dy * dy) <= range then
						cover += 1
					end
				end
				table.insert(out, { x = x, y = y, cover = cover, i = #out })
			end
		end
	end
	table.sort(out, function(a, b)
		if a.cover ~= b.cover then
			return a.cover > b.cover
		end
		return a.i < b.i
	end)
	return out
end

local function botTick(G, st, kinds)
	for _, pid in table.clone(G.playerOrder) do
		local p = G.players[pid]
		for _ = 1, 50 do
			local best = nil
			for _, t in G.turrets do
				if t.owner == pid then
					for _, s in STATS do
						local c = E.upCost(t, s)
						if c ~= nil and (best == nil or c < best.c) then
							best = { t = t, st = s, c = c }
						end
					end
				end
			end
			local kind = kinds[(#G.turrets % #kinds) + 1]
			if #G.turrets == 0 and p.cash < G.D.turrets[kind].cost then
				kind = "Blue"
			end
			local cost = G.D.turrets[kind].cost * (1 + #G.turrets * 0.5)
			local built = false
			if (best == nil or cost < best.c) and p.cash >= G.D.turrets[kind].cost and #G.turrets < 24 then
				while st.next <= #st.cand and not E.canBuildAt(G, kind, st.cand[st.next].x, st.cand[st.next].y, nil) do
					st.next += 1
				end
				if st.next <= #st.cand and E.build(G, pid, kind, st.cand[st.next].x, st.cand[st.next].y) then
					built = true
				end
			end
			if not built then
				if best and p.cash >= best.c then
					E.upgrade(G, pid, best.t.id, best.st)
				else
					break
				end
			end
		end
	end
end

local function act(G, a)
	local op = a[2]
	local function T(i)
		return G.turrets[i + 1]
	end
	local function own(i)
		return T(i) and T(i).owner
	end
	if op == "tmax" then
		if T(a[3]) then
			E.upgrade(G, own(a[3]), T(a[3]).id, a[4], true)
		end
	elseif op == "mode" then
		if T(a[3]) then
			E.setTargetMode(G, own(a[3]), T(a[3]).id, a[4])
		end
	elseif op == "lock" then
		if T(a[3]) then
			E.toggleLock(G, own(a[3]), T(a[3]).id)
		end
	elseif op == "dir" then
		if T(a[3]) then
			E.setDirectional(G, own(a[3]), T(a[3]).id, a[4], a[5])
		end
	elseif op == "join" then
		if T(a[3]) and T(a[4]) then
			E.join(G, own(a[3]), T(a[3]).id, T(a[4]).id)
		end
	elseif op == "focus" then
		E.focus(G, a[3], a[4])
	elseif op == "move" then
		if T(a[3]) then
			E.move(G, own(a[3]), T(a[3]).id, a[4], a[5])
		end
	elseif op == "sell" then
		if T(a[3]) then
			E.sell(G, own(a[3]), T(a[3]).id)
		end
	elseif op == "leave" then
		E.removePlayer(G, a[3])
	elseif op == "prefs" then
		E.setPrefs(G, { waveSpacing = a[3], waveFollow = a[4] })
	elseif op == "build" then
		E.build(G, a[3], a[4], a[5], a[6])
	elseif op == "upgrade" then
		E.upgrade(G, a[3], a[4], a[5], a[6])
	elseif op == "waveSend" then
		E.waveSend(G)
	elseif op == "combonly" then
		for _, t in G.turrets do
			if t.type == "combonly" then
				E.combonlyChoose(G, "p1", t.id, a[3])
				break
			end
		end
	elseif op == "group" then
		for i, k in a[5] do
			local t = E.build(G, "p1", k, a[3] + Q[i][1], a[4] + Q[i][2])
			if t then
				if t.type ~= "combonly" then
					E.upgrade(G, "p1", t.id, "damage", true)
				end
				if i > 1 then
					E.setDirectional(G, "p1", t.id, -90, 15)
				end
			end
		end
	end
end

local function snap(G)
	local hp, xs, ys, sp = 0, 0, 0, 0
	for _, a in G.attackers do
		hp += a.energy
		xs += a.x
		ys += a.y
		sp += a.speed
	end
	local rot, val = 0, 0
	for _, t in G.turrets do
		rot += t.rot or 0
		val += t.value
	end
	local c = {}
	for i, p in G.playerOrder do
		c[i] = G.players[p].cash
	end
	return {
		t = G.now, w = G.waveNum, k = G.kills, l = G.lives, c = c, r = G.rng.s,
		na = #G.attackers, hp = hp, xs = xs, ys = ys, sp = sp, nt = #G.turrets, rot = rot, val = val,
		ns = #G.shots, nb = #G.blasts, sh = G.stats.shots, co = G.stats.combos, over = G.over,
	}
end

local lines = {}
for _, sc in SC do
	if only and sc.name ~= only then
		continue
	end
	local o = { players = { "p1" } }
	for k, v in sc.opts do
		o[k] = v
	end
	if o.challengeIndex ~= nil then
		o.challenge = GAME.challenges[o.challengeIndex + 1]
		o.challengeIndex = nil
	end
	local G = E.newGame(GAME, o)
	if sc.energy then
		G.energy = sc.energy
	end
	local bot = if sc.bot then { cand = spots(G, 110), next = 1 } else nil
	local script = table.clone(sc.script or {})
	local si = 1
	local fxKinds = {}
	local t = 0
	while t <= sc.ms and not G.over do
		while si <= #script and script[si][1] <= G.now do
			act(G, script[si])
			si += 1
		end
		if bot and G.now % 1000 == 0 then
			botTick(G, bot, sc.bot)
		end
		E.step(G)
		t += 1
		for _, f in G.fx do
			local key = if f.k == "combo" then "combo:" .. f.name else f.k
			fxKinds[key] = (fxKinds[key] or 0) + 1
		end
		table.clear(G.fx)
		if G.now % 500 == 0 or G.over then
			local s = snap(G)
			s.sc = sc.name
			s.fx = fxKinds
			fxKinds = {}
			table.insert(lines, serde.encode("json", s))
		end
	end
end
print(table.concat(lines, "\n"))
