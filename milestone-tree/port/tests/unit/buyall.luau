--!nocheck
-- buyall: the Buy All action on a Session (rbx/view.js rbx_buyAll): open once the layer after is reached, on screen
-- as the upgrades component's ba action, buys every affordable upgrade and never an Upgrade Perk one.
-- Run from port/: luau tests/unit/buyall.luau
local L = require("../../lib")
local Session = L.Session
local fails, n = 0, 0
local function check(ok, what)
	n += 1
	if not ok then fails += 1; print("  FAIL  " .. what) else print("  ok    " .. what) end
end
local states = L.JSRT(L.TN, L.BEcore).G.JSON.parse(L.data("fz", "fz_states"))
local t0 = 1.7e12

-- the owned upgrades of layer l, asked of the game (hasUpgrade) for every id of its grid
local function upgs(s, l)
	local out = {}
	for r = 1, 9 do
		for c = 1, 9 do
			local id = r * 10 + c
			if s.ENV.layers[l].upgrades[id] ~= nil and s.ENV.hasUpgrade(nil, l, id) == true then out[tostring(id)] = true end
		end
	end
	return out
end
local function count(t) local k = 0; for _ in t do k += 1 end; return k end
local function ids(s, l) local a = s.ENV.rbx_buyAllIds(nil, l); return s.JS.LEN[a] end
local function on(s, l) return s.ENV.rbx_buyAllOn(nil, l) == true end
local function openTab(s, l)
	s.ENV.showTab(nil, l)
	s:view()
end
local key = Session.actionKey({ "buyall", "p" })

-- a save where p's Buy All is open with something to buy; a new game, where it is still closed
local open, closed = nil, Session.new(L.deps(), nil, nil, t0)
for i = 1, #states do
	local s = Session.new(L.deps(), states[i].save, nil, t0)
	-- (the fuzz saves are generated: a layer is only unlocked by its first reset in real play)
	s.JS.setk(s.ENV.player.p, "unlocked", true)
	s.ENV.updateTemp(nil)
	if on(s, "p") and ids(s, "p") > 0 then open = s; break end
end
check(not on(closed, "p") and ids(closed, "p") == 0, "a new game: p's Buy All is closed")
check(open ~= nil and closed ~= nil, "saves with p's Buy All open and closed")

if open then
	local s = open
	openTab(s, "p")
	check(s.allowed[key] == true, "open: BUY ALL is on screen (an allowed action)")
	local before = upgs(s, "p")
	local want = ids(s, "p")
	local ok, err = s:act({ "buyall", "p" }, t0 + 50)
	check(ok, "the action runs (" .. tostring(err) .. ")")
	local after = upgs(s, "p")
	check(count(after) >= count(before) + want, string.format("bought at least the %d affordable (%d -> %d)", want, count(before), count(after)))
	check(ids(s, "p") == 0, "nothing affordable is left")
	local perk = false
	for id in after do
		if not before[id] and s.ENV.layers.p.upgrades[tonumber(id)].perkUnl ~= nil then perk = true end
	end
	check(not perk, "no Upgrade Perk upgrade was bought")
	-- the view: the count follows
	openTab(s, "p")
	check(s.allowed[key] == true, "BUY ALL stays on screen with nothing to buy")
end

if closed then
	local s = closed
	openTab(s, "p")
	check(s.allowed[key] ~= true, "closed: no BUY ALL on screen before sp is reached")
	local before = count(upgs(s, "p"))
	local ok = s:act({ "buyall", "p" }, t0 + 50)
	check(not ok and count(upgs(s, "p")) == before, "closed: the action is refused and buys nothing")
	check(s.ENV.rbx_buyAll(nil, "p") == 0, "closed: rbx_buyAll itself buys nothing")
end

print(string.format("buyall: %d checks, %d failures", n, fails))
if fails > 0 then error("buyall unit test failed", 0) end
