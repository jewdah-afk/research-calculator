--!nocheck
-- locked: the upgrades a late game has open but locked by the game (cost Infinity until a challenge condition is met:
-- p / sp / pb / hb / hp 41-44, open from milestone 124 to 142) and the layers that cannot reset inside a challenge
-- (pb in AP challenge 1, t in any T challenge). No panel fails ("[upgrades failed: ... stack overflow]" once), and no
-- player-facing text says Infinity: the card reads LOCKED (n.lk), the prestige button "Locked in this challenge".
-- Run from port/: luau tests/unit/locked.luau
local L = require("../../lib")
local fails, n = 0, 0
local function check(ok, what)
	n += 1
	if not ok then fails += 1; print("  FAIL  " .. what) end
end
local found = {}
local function scan(v, path, tag)
	if type(v) == "string" then
		if string.find(v, "failed:", 1, true) or string.find(v, "Infinity", 1, true) then
			table.insert(found, tag .. " " .. path .. " " .. string.sub(v, 1, 100))
		end
	elseif type(v) == "table" and v.cls ~= "bought" then
		for k, x in v do
			-- st: styles; a: actions; lim: a challenge's completion limit (the client reads "Infinity" as no limit)
			if k ~= "st" and k ~= "a" and k ~= "lim" then scan(x, path .. "." .. tostring(k), tag) end
		end
	end
end
local locked = 0
-- two fuzz saves (data/fz, ./test.sh game) past milestone 124, as they are and inside AP challenge 1
local JSON = L.JSRT(L.TN, L.BEcore).G.JSON
local states = JSON.parse(L.data("fz", "fz_states"))
local skip = {}
for k in string.gmatch(L.data("fz", "fz_skip"), "[^,]+") do skip[tonumber(k)] = true end
local used = 0
for i = 0, 59 do
	if used >= 2 then break end
	local st = states[i]
	if st == nil or skip[i] or st.mv then continue end
	local probe = L.Session.new(L.deps(), st.save, nil, 1.7e12)
	if probe.ENV.player.m.best:lt(124) then continue end
	used += 1
	for _, chal in { "", "ap11" } do
		local s = if chal == "" then probe else L.Session.new(L.deps(), st.save, nil, 1.7e12)
		s:setNotation("SUFFIX")
		local P = s.ENV.player
		if chal == "ap11" then P.ap.activeChallenge = 11 end
		for _, l in { "p", "sp", "pb", "hp", "hb", "t" } do
			local ok, v = pcall(function()
				P.tab = l
				s.ENV.updateTemp(nil)
				return s:view()
			end)
			check(ok, "S" .. i .. " " .. chal .. " " .. l .. " builds: " .. tostring(not ok and v))
			if ok then
				scan(v, "", "S" .. i .. "/" .. chal .. "/" .. l)
				local function count(x)
					if type(x) == "table" then
						if x.lk == true then locked += 1 end
						for k, y in x do if k ~= "st" then count(y) end end
					end
				end
				count(v)
			end
		end
	end
end
check(used == 2, "two late saves found (" .. used .. ")")
for _, f in found do print("  " .. f) end
check(#found == 0, "no panel fails and no player-facing Infinity (" .. #found .. ")")
check(locked > 0, "the locked upgrades read LOCKED (" .. locked .. ")")
print(string.format("locked: %d checks, %d failures", n, fails))
if fails > 0 then error("locked failed") end
