-- Snapshot round trip on a real mid-game state. lune run test/unit/snapshot_test.luau
local process = require("@lune/process")
local E = require("../../src/shared/Onslaught/Engine")
local GAME = require("../../src/shared/Onslaught/Data")
local Snapshot = require("../../src/shared/Snapshot")

local fails = 0
local function ok(c, msg)
	if not c then
		fails += 1
		print("FAIL: " .. msg)
	end
end
local G = E.newGame(GAME, { map = "map1", mode = "sandbox", seed = 3, players = { "111", "222" } })
G.energy = 1e7
local Q = { { 0, 0 }, { -36, -8 }, { 36, -8 } }
for i, k in { "Red", "Blue", "Blue" } do
	local t = E.build(G, "111", k, 150 + Q[i][1], 345 + Q[i][2])
	E.upgrade(G, "111", t.id, "damage", true)
	if i > 1 then
		E.setDirectional(G, "111", t.id, -90, 15)
	end
end
E.build(G, "222", "Yellow", 400, 200)
E.waveSend(G)
local fxAll, maxBytes, frames = {}, 0, 0
local kinds = {}
for _ = 1, 400 do -- 400 snapshots of 66 ms
	for _ = 1, 66 do
		E.step(G)
	end
	local b = Snapshot.encode(G, G.fx)
	maxBytes = math.max(maxBytes, buffer.len(b))
	local s = Snapshot.decode(b)
	frames += 1
	ok(s.now == G.now, "now")
	ok(#s.attackers == #G.attackers, "attacker count")
	for i, a in G.attackers do
		local d = s.attackers[i]
		ok(d.id == a.id and math.abs(d.x - a.x) < 1e-3 and math.abs(d.y - a.y) < 1e-3, "attacker position")
	end
	for _, t in G.turrets do
		ok(s.turrets[t.id] and math.abs(s.turrets[t.id].rot - t.rot) <= 0.051, "turret rot " .. tostring(t.rot))
	end
	ok(#s.fx == #G.fx, "fx count " .. #s.fx .. " vs " .. #G.fx)
	for i, f in G.fx do
		local d = s.fx[i]
		ok(d.k == f.k, "fx kind")
		if f.dmg then
			ok(d.dmg == f.dmg, "fx damage exact")
		end
		kinds[f.k] = true
	end
	table.clear(G.fx)
end
local sig1 = Snapshot.turretSignature(G)
E.upgrade(G, "222", G.turrets[4].id, "range")
ok(Snapshot.turretSignature(G) ~= sig1, "signature changes on upgrade")
ok(#Snapshot.turretDetails(G) == 4, "details list")
local k = {}
for n in kinds do
	table.insert(k, n)
end
table.sort(k)
print(string.format("snapshot: %d frames, max %d bytes, fx kinds seen: %s", frames, maxBytes, table.concat(k, ",")))
print(if fails == 0 then "snapshot ok" else fails .. " failed")
process.exit(if fails > 0 then 1 else 0)
