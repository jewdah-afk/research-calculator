--!nocheck
--[[
	Map/MapLogic.luau (pure): node states on every fixture, the plate names and units, the LOD hysteresis, the drawn
	links, the edge-marker candidates and the greedy plate placement.
	Run from port/ (after ./test.sh capture): luau tests/unit/map_nodes.luau
]]
local L = require("../../../src/client/Map/MapLogic")
local Realm = require("../../../src/shared/Realm")

local failures, checks = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failures += 1
		print("  FAIL  " .. what)
	end
end

-- a MapState from a fixture patch (the parts ViewStore.map builds that MapLogic reads)
local function mapState(name: string)
	local patch = require("../../data/fixtures/" .. name)
	local set = patch.set
	local root = set.map
	local ms = { inside = root.inside == true, open = root.open, nodes = {}, gate = nil, ready = {}, canBuy = {} }
	for _, cid in root.c do
		local n = set[cid]
		if n.t == "node" then
			local node = { show = n.show == true, dor = n.dor == true, col = n.col, name = n.name, ch = n.ch, br = n.br, val = nil }
			if type(n.br) == "table" and #n.br == 0 then node.br = {} end
			for _, vid in n.c or {} do
				local v = set[vid]
				if v and v.t == "val" then node.val = { lit = v.lit == true, glow = v.glow == true, pulse = v.pulse == true } end
			end
			ms.nodes[n.id] = node
		elseif n.t == "gate" then
			ms.gate = { show = n.show == true }
		end
	end
	for _, l in L.ORDER do
		local n = ms.nodes[l]
		if n and n.show and n.val then
			if n.val.pulse then table.insert(ms.ready, l) elseif n.val.glow then table.insert(ms.canBuy, l) end
		end
	end
	return ms
end

local STATES = { sealed = true, frontier = true, dormant = true, locked = true, available = true, glow = true, pulse = true }
local fixtures = { "fresh_none", "fresh_m", "s13_none", "s13_p", "s13_m", "s19mv_none", "s19mv_cp", "s19mv_ex", "trapped_none",
	"layer_ach", "layer_m", "layer_p", "layer_cp", "layer_ex", "layer_t" }
for _, name in fixtures do
	local ok, ms = pcall(mapState, name)
	if not ok then
		print("  skip  " .. name .. " (no fixture: run ./test.sh capture)")
		continue
	end
	for _, l in L.ORDER do
		local st = L.state(ms, l, Realm.edges)
		check(STATES[st] == true, name .. ": " .. l .. " has a state (" .. tostring(st) .. ")")
		local n = ms.nodes[l]
		if n and n.show then check(st ~= "sealed" and st ~= "frontier" and st ~= "dormant", name .. ": shown " .. l .. " is live") end
	end
	-- links: both ends shown, every one a Realm edge
	for _, link in L.edges(ms, Realm.edges) do
		check(ms.nodes[link.from].show and ms.nodes[link.to].show, name .. ": link " .. link.from .. "-" .. link.to .. " between shown nodes")
		check(#link.p == 8, name .. ": link geometry")
	end
	local cands = L.markerCandidates(ms, 4)
	check(#cands <= 4, name .. ": at most 4 markers")
	if #ms.ready > 0 then check(cands[1] == ms.ready[1], name .. ": pulse markers first") end
end

-- the fresh game: M ready, MM and P frontier (their parent M is shown), the rift quiet
do
	local ok, ms = pcall(mapState, "fresh_none")
	if ok then
		check(L.state(ms, "m", Realm.edges) == "pulse", "fresh: m pulse")
		check(L.state(ms, "mm", Realm.edges) == "frontier", "fresh: mm frontier")
		check(L.state(ms, "p", Realm.edges) == "frontier", "fresh: p frontier")
		check(L.state(ms, "pe", Realm.edges) == "sealed", "fresh: pe sealed")
		check(L.state(ms, "pm", Realm.edges) == "sealed", "fresh: pm sealed (not dormant before the Multiverse shows)")
	end
	local ok2, s13 = pcall(mapState, "s13_none")
	if ok2 then
		check(L.state(s13, "pb", Realm.edges) == "locked", "s13: pb locked")
		check(L.state(s13, "p", Realm.edges) == "glow", "s13: p can buy")
		local secondary = false
		for _, link in L.edges(s13, Realm.edges) do
			if link.from == "sp" and link.to == "hp" then secondary = link.secondary end
		end
		check(secondary, "s13: sp - hp is a secondary link")
	end
	local ok3, mv = pcall(mapState, "s19mv_none")
	if ok3 then
		check(L.state(mv, "p", Realm.edges) == "dormant", "inside: p dormant")
		check(L.state(mv, "pm", Realm.edges) ~= "dormant", "inside: pm live")
	end
end

-- names and units
check(L.plateName({ name = "Prestige Points" }, "p") == "PRESTIGE", "plate name p")
check(L.plateName(nil, "cm") == "CORRUPTED\nMILESTONE", "long names wrap at the middle space")
check(L.plateName(nil, "se") == "SUPER ENERGY", "12 characters stay on one line")
check(L.unit("hyper-prestige points") == "HP", "unit HP")
check(L.unit("prestige points") == "P", "unit P")
check(L.unit("<span style='color:red'>infected</span> super prestige points") == "SP", "infected unit")
check(L.isInfected("rgb(238, 112, 112)") and L.isInfected("#9F2846") and not L.isInfected("#658091"), "infected colours")

-- LOD with hysteresis
check(L.lod(0.5, "WIDE", nil) == "FULL", "lod full")
check(L.lod(0.39, "WIDE", "FULL") == "FULL", "lod keeps FULL inside the band")
check(L.lod(0.39, "WIDE", "CHIP") == "CHIP", "lod keeps CHIP inside the band")
check(L.lod(0.43, "WIDE", "CHIP") == "FULL", "lod FULL above the band")
check(L.lod(0.2, "WIDE", "CHIP") == "NONE", "lod none")
check(L.lod(0.31, "COMPACT", nil) == "FULL", "lod compact")

-- placement: priority wins the slot, the loser takes the other slot, then the chip, then nothing
do
	local a = { x = 0, y = 0, w = 100, h = 40 }
	local b = { x = 0, y = -50, w = 100, h = 40 }
	local chip = { x = 20, y = 0, w = 60, h = 20 }
	local items = {
		{ id = "hi", rank = 60, y = 10, full = { a, b }, chip = { chip } },
		{ id = "lo", rank = 30, y = 10, full = { a, b }, chip = { chip } },
		{ id = "lo2", rank = 20, y = 12, full = { a }, chip = { chip } },
	}
	local out = L.place(items, {}, 4)
	check(out.hi.form == "FULL" and out.hi.slot == 1, "placement: the higher rank gets slot 1")
	check(out.lo.form == "FULL" and out.lo.slot == 2, "placement: the next takes the slot above")
	check(out.lo2.form == "NONE", "placement: no room left hides the plate")
	local blocked = L.place({ { id = "x", rank = 1, y = 0, full = { a }, chip = { { x = 300, y = 0, w = 10, h = 10 } } } }, { { x = 50, y = 10, w = 10, h = 10 } }, 4)
	check(blocked.x.form == "CHIP", "placement: a HUD rect pushes the plate to its chip")
end

-- the edge point
do
	local x, y = L.edgePoint({ x = 0, y = 0, w = 100, h = 100 }, 200, 50, 10)
	check(x == 90 and y == 50, "edge point on the right side")
	local x2 = L.edgePoint({ x = 0, y = 0, w = 100, h = 100 }, 50, 50, 10)
	check(x2 == nil, "no edge point inside")
end

print(string.format("map_nodes: %d checks, %d failures", checks, failures))
if failures > 0 then error("map_nodes failed", 0) end
