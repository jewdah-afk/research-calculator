--!nocheck
-- Plays the game through Session the way the Roblox server does: 20 ticks/s, a view every 5 ticks, a greedy bot
-- pressing the buttons on screen. usage: luau sim.luau -a SECONDS
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
				for id, n in nodes do
					if n.k == "menu" and n.a and n.a[2] == want then s:act(n.a, now); found = true; break end
				end
				if found then break end
			end
		end
	end
	if step % 400 == 0 then
		local head = nodes["head.1"] and nodes["head.1"].h or ""
		print(string.format("t=%ds pts: %s | tab %s | nodes %d", step // 20, string.sub(string.gsub(head, "<[^>]*>", ""), 1, 60), tostring(s.ENV.player.tab), (function() local c = 0 for _ in nodes do c += 1 end return c end)()))
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
-- export / import
local ex = s:export()
local ok, err = s2:import(ex, now)
print("import of export:", ok, err)
