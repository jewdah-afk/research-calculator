--!nocheck
-- Replays data/str/cases (node str_gen.js makes them) through the port's new Decimal(string).
local L = require("./lib")
local JS = L.JSRT(L.TN, L.BEcore)
local cases = L.data("str", "cases")
local function num(x) if x == "Infinity" then return math.huge elseif x == "-Infinity" then return -math.huge elseif x == "NaN" then return 0/0 end return tonumber(x) end
local function close(x, y) if x == y then return true end if x ~= x and y ~= y then return true end return math.abs(x - y) <= 1e-12 * math.max(1, math.abs(x), math.abs(y)) end
local bad, tot = 0, 0
for line in string.gmatch(cases, "[^\n]+") do
	local str, exp = string.match(line, "^(.*)|([^|]*)$")
	local s, l, m = string.match(exp, "^([^,]+),([^,]+),([^,]+)$")
	s, l, m = num(s), num(l), num(m)
	local t = JS.beFromString(str)
	tot += 1
	if not (close(t.s, s) and close(t.l, l) and close(t.m, m)) then
		bad += 1
		if bad <= 25 then print(string.format("%q  js=%s  lua=%s,%s,%s", str, exp, JS.numToString(t.s), JS.numToString(t.l), JS.numToString(t.m))) end
	end
end
print(tot .. " strings, " .. bad .. " differ")
