-- Match: validation, co-op ownership, host controls, Commander Tools, revive window. lune run test/unit/match_test.luau
local process = require("@lune/process")
local Match = require("../../src/server/Match")

local fails, passes = 0, 0
local function ok(c, msg)
	if c then
		passes += 1
	else
		fails += 1
		print("FAIL: " .. msg)
	end
end
local function mkIO()
	local io = { states = 0, events = {}, endedCount = 0, bp = {} }
	function io.state(buf, header)
		io.states += 1
		io.lastHeader = header
		io.lastBytes = buffer.len(buf)
	end
	function io.event(pid, kind, payload)
		table.insert(io.events, { pid = pid, kind = kind, payload = payload })
	end
	function io.ended(_m, results)
		io.endedCount += 1
		io.results = results
	end
	function io.saveBlueprint(pid, map, bp)
		io.bp[pid .. map] = bp
	end
	function io.loadBlueprint(pid, map)
		return io.bp[pid .. map]
	end
	return io
end
local function info(plus, passes2)
	return {
		mode = "medium", map = "map1", plus = plus, seed = 5, hostPid = "1",
		order = { "1", "2" },
		players = {
			["1"] = { name = "Host", loadout = { level = 99, research = { funds = 2 } }, passes = passes2 or {} },
			["2"] = { name = "Friend", loadout = { level = 1, research = {} }, passes = {} },
		},
	}
end
local function run(m, seconds)
	for _ = 1, math.floor(seconds * 60) do
		m:update(1 / 60)
	end
end

do -- classic: ownership, validation, host controls
	local io = mkIO()
	local m = Match.new(info(false), io)
	local G = m.G
	ok(G.players["1"].cash == 30 and G.players["2"].cash == 30, "classic ignores research (both start with $30)")
	ok(m:action("1", "build", "Blue", 150, 330), "host builds")
	local id = G.turrets[1].id
	ok(not m:action("2", "sell", id), "friend can't sell the host's turret")
	ok(not m:action("2", "build", "Blue", 0 / 0, 330), "NaN rejected")
	ok(not m:action("2", "build", "Blue", 150), "missing arg rejected")
	ok(not m:action("2", "build", "Sniper", 300, 60), "locked turret rejected")
	ok(not m:action("2", "nope"), "unknown op rejected")
	ok(not m:action("2", "speed", 2), "only the host sets speed")
	ok(m:action("1", "speed", 2), "host sets 2x")
	ok(not m:action("1", "speed", 5), "5x needs Speed Demon")
	ok(not m:action("1", "speed", 4), "4x isn't a speed")
	ok(not m:action("1", "upgrade", id, "luck"), "bad stat rejected")
	ok(not m:action("1", "dir", id, 90, 20), "bad spread rejected")
	ok(m:action("1", "send"), "anyone can send a wave")
	run(m, 5)
	ok(io.states > 60 and io.lastHeader.wave == 1, "snapshots flow (" .. io.states .. ")")
	ok(G.now >= 9000, "2x speed runs 2 ms per ms (" .. G.now .. ")")
	local sawTurrets = false
	for _, e in io.events do
		if e.kind == "turrets" then
			sawTurrets = true
		end
	end
	ok(sawTurrets, "turret details sent")
	m:action("1", "pause", true)
	local t0 = G.now
	run(m, 1)
	ok(G.now == t0, "pause stops the clock")
	m:action("1", "pause", false)
	-- rate limit
	local n = 0
	for _ = 1, 100 do
		if m:action("2", "focus", 1, 1) ~= "slow down" then
			n += 1
		end
	end
	local refused = select(2, m:action("2", "send"))
	ok(refused == "slow down", "rate limit kicks in")
	m:leave("1")
	ok(m.hostPid == "2" and G.turrets[1].owner == "2", "host leaves: friend inherits host and turrets")
end
do -- Commander Tools queue and blueprints
	local io = mkIO()
	local m = Match.new(info(false, { commander = true }), io)
	local G = m.G
	m:action("1", "build", "Blue", 150, 330)
	local id = G.turrets[1].id
	ok(not m:action("2", "queue", id, "damage"), "friend has no Commander Tools")
	ok(m:action("1", "queue", id, "damage") and m:action("1", "queue", id, "rate"), "queue upgrades")
	G.players["1"].cash = 1000
	run(m, 0.2)
	ok(G.turrets[1].lvl.damage == 1 and G.turrets[1].lvl.rate == 1, "queue buys upgrades when affordable")
	ok(m:action("1", "blueprintSave"), "save blueprint")
	local m2 = Match.new(info(false, { commander = true }), io)
	ok(m2:action("1", "blueprintLoad"), "load blueprint")
	m2.G.players["1"].cash = 1000
	run(m2, 0.5)
	ok(#m2.G.turrets == 1 and m2.G.turrets[1].lvl.damage == 1, "blueprint rebuilds turret and levels")
end
do -- Onslaught+: research applies, revive window, finish once
	local io = mkIO()
	local m = Match.new(info(true), io)
	local G = m.G
	ok(G.players["1"].cash == 40 and G.players["2"].cash == 30, "plus: host research +$10")
	ok(not m:canUseProduct("revive") and m:canUseProduct("drop_s"), "revive only after losing")
	G.energy = 1e12
	m:action("1", "send")
	m:action("1", "speed", 2)
	for _ = 1, 3600 do
		m:update(1 / 60)
		if G.over then
			break
		end
	end
	ok(G.over and m.state == "reviveWindow", "lost run waits for a revive (" .. m.state .. ")")
	ok(m:canUseProduct("revive"), "revive is offered")
	ok(m:applyProduct("2", "revive"), "revive works")
	run(m, 0.1)
	ok(m.state == "playing" and not G.over and G.lives == 5, "run continues after revive")
	G.energy = 1e12
	run(m, 120)
	ok(m.state == "done" and io.endedCount == 1, "finishes once after the window (" .. m.state .. ", " .. io.endedCount .. ")")
	ok(io.results["1"].assisted and io.results["1"].plus, "results mark assisted plus run")
	run(m, 1)
	ok(io.endedCount == 1, "no double finish")
end
do -- late join
	local io = mkIO()
	local m = Match.new(info(true), io)
	m:join("3", { name = "Late", loadout = { level = 5 }, passes = {} })
	ok(m.G.players["3"] and m.G.players["3"].cash == 0, "late joiner has an empty wallet")
	ok(m:action("3", "send"), "late joiner can act")
end
print(string.format("match: %d passed, %d failed", passes, fails))
process.exit(if fails > 0 then 1 else 0)
