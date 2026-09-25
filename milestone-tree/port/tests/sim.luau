--!nocheck
-- Plays the game through Session the way the Roblox server does: 20 ticks/s, a view every 5 ticks, a greedy bot
-- pressing the buttons on screen and moving between layers through the map's nodes. Then: closing the panel, and a
-- second game that goes into the Prestige Multiverse through the map's gate and back out.
-- usage: luau sim.luau -a SECONDS
local L = require("../lib")
local TN = L.TN
local Session = L.Session
local deps = L.deps()
local args = { ... }
local SECS = tonumber(args[1]) or 60
local now = 1.7e12
local t0 = os.clock()
local s = Session.new(deps, nil, nil, now)
print(string.format("boot %.1f ms", (os.clock() - t0) * 1000))

-- the client's mirror of the screen
local nodes = {}
local function apply(p)
	for _, id in p.del do nodes[id] = nil end
	for id, n in p.set do nodes[id] = n end
end
local function size(v)
	local t = type(v)
	if t == "string" then return #v + 2 end
	if t ~= "table" then return 8 end
	local n = 2
	for k, x in v do n += size(k) + size(x) end
	return n
end
local tickT, viewT, ticks, views, bytes, maxBytes = 0, 0, 0, 0, 0, 0
local pressed = 0
local layerOrder = { "m", "p", "sp", "pb", "pe", "hp", "hb", "se", "ep", "ap", "pp", "t", "mm", "em", "mp", "pm", "pep", "cp", "cm", "ex", "ach" }
local li = 1
for step = 1, SECS * 20 do
	now += 50
	local a = os.clock()
	s:tick(now)
	tickT += os.clock() - a
	ticks += 1
	if step % 5 == 0 then
		a = os.clock()
		local p = s:view()
		viewT += os.clock() - a
		views += 1
		local b = size(p)
		bytes += b
		maxBytes = math.max(maxBytes, b)
		apply(p)
		-- bot: press everything that says "can" on this tab, then move to the next shown layer
		for id, n in nodes do
			if n.t == "btn" and n.a and (n.k == "upg" or n.k == "buy" or n.k == "reset" or n.k == "perk" or n.k == "malware") and n.cls == "can" then
				if s:act(n.a, now) then pressed += 1 end
			end
		end
		if step % 40 == 0 then
			for _ = 1, #layerOrder do
				li = li % #layerOrder + 1
				local want = layerOrder[li]
				local found = false
				for k = 1, 21 do
					local n = nodes["map." .. k]
					if n and n.t == "node" and n.show and n.a and n.id == want then s:act(n.a, now); found = true; break end
				end
				if found then break end
			end
		end
	end
	if step % 400 == 0 then
		local hud = nodes["hud"]
		print(string.format("t=%ds pts: %s | tab %s | nodes %d", step // 20, if hud then tostring(hud.pts) else "?", tostring(s.ENV.player.tab), (function() local c = 0 for _ in nodes do c += 1 end return c end)()))
	end
end
print(string.format("ticks %d avg %.2f ms | views %d avg %.2f ms | patch avg %.1f KB max %.1f KB | presses %d",
	ticks, tickT * 1000 / ticks, views, viewT * 1000 / views, bytes / views / 1024, maxBytes / 1024, pressed))
-- save -> load round trip must give the same screen
local save, opts = s:save()
print("save bytes", #save, "options", opts)
local s2 = Session.new(deps, save, opts, now)
local p1, p2 = s:view(), nil
s:resetView(); p1 = s:view()
p2 = s2:view()
local diff = 0
for id, n in p1.set do if Session.plain and p2.set[id] == nil then diff += 1 end end
print("round trip: ids only in original", diff)
-- saves live in Roblox: no export / import / hard reset path on the Session
assert(Session.export == nil and Session.import == nil, "the Session has no export or import")
assert(select(1, s:act({ "opt", "hardReset" }, now)) == false, "a hard reset is not an action")

local function check(cond: any, what: string)
	if not cond then error("sim: " .. what, 0) end
	print("ok: " .. what)
end

-- the map's close button: the map alone, no tab built
local function mapNode(): any return nodes["map"] end
s:resetView()
nodes = {}
apply(s:view())
s:act(mapNode().close, now)
local pc = s:view()
apply(pc)
check(pc.tab == "none", "map.close leaves patch.tab == \"none\"")
check(nodes["tab"] and #nodes["tab"].c == 0, "map.close leaves an empty tab")
check(mapNode().open == nil, "map.open is nil on the map alone")
check(nodes["map.22"] and nodes["map.22"].t == "gate", "map.22 is the gate")

-- the gate: a game with 190 best milestones and Multiverse Prestige unlocked goes in and back out
local JS = s.JS
local sv = s2:save()
local p = JS.G.JSON.parse(sv)
p.m.best = "190"
p.m.points = "190"
p.mp.unlocked = true
p.tab = "none"
local g = Session.new(deps, JS.G.JSON.stringify(p), nil, now)
nodes = {}
local function step(n: number)
	for _ = 1, n do
		now += 50
		g:tick(now)
	end
	apply(g:view())
end
step(2)
local gate = nodes["map.22"]
check(gate.show == true and gate.inside == false and gate.can == true, "the gate shows and can be used at 190 milestones")
check(g:act(gate.a, now), "the gate's action is on screen")
step(2)
check(mapNode().inside == true and nodes["map.22"].inside == true, "map.inside after going through the gate")
check(mapNode().open == nil, "no panel right after entering (the game moved the tab to a hidden layer)")
local shown = {}
for k = 1, 21 do
	local n = nodes["map." .. k]
	if n and n.show then table.insert(shown, n.id) end
end
print("shown inside: " .. table.concat(shown, " "))
check(table.find(shown, "pm") ~= nil and table.find(shown, "p") == nil, "the rift's layers show inside, the tree's do not")
check(g:act(nodes["map.22"].a, now), "the gate's action is on screen inside")
step(2)
check(mapNode().inside == false, "map.inside is false after leaving")
