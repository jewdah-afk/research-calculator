--!nocheck
-- notation: the SUFFIX number format (Session:setNotation) on the game's own format(), and SCIENTIFIC unchanged.
-- Run from port/: luau tests/unit/notation.luau
local L = require("../../lib")
local Session = L.Session
local s = Session.new(L.deps(), nil, nil, 1.7e12)
local ENV, fails, n = s.ENV, 0, 0
local function eq(got, want, what)
	n += 1
	if got ~= want then
		fails += 1
		print(string.format("  FAIL  %s: got %q, want %q", what, tostring(got), tostring(want)))
	end
end
local function f(x, p) return ENV.format(nil, x, p) end

local sci = {}
for _, x in { "999", "1234", "1e9", "1e5000", "1e1329005", "2.19e500" } do sci[x] = f(x) end
s:setNotation("SUFFIX")
for x, want in {
	["0"] = "0.00", ["999"] = "999.00", ["1000"] = "1.00K", ["1234"] = "1.23K", ["12345"] = "12.3K", ["123456"] = "123K",
	["999999"] = "1.00M", ["1e6"] = "1.00M", ["2.5e9"] = "2.50B", ["1e12"] = "1.00T", ["1e15"] = "1.00Qa",
	["1e30"] = "1.00No", ["1e33"] = "1.00Dc", ["1e36"] = "1.00UDc", ["1e63"] = "1.00Vg", ["4.56e302"] = "456NoNog",
	["-1234"] = "-1.23K", ["2.19e500"] = sci["2.19e500"], ["1e23537"] = "e23.54K", ["3e16967"] = "e16.97K",
	["1e10927"] = "e10.93K", ["2e10922"] = "e10.92K", ["4.56e3002"] = "e3.003K", ["1e1329005"] = "e1.329M",
	["1e1.08e25"] = "e10.80Sp", ["1e1e305"] = "e1.00e305",
} do
	eq(f(x), want, x)
end
eq(ENV.formatWhole(nil, "12345"), "12.3K", "formatWhole 12345")
eq(ENV.formatWhole(nil, "164"), "164", "formatWhole 164")
eq(Session.suffix(1), "K", "suffix 1")
eq(Session.suffix(11), "Dc", "suffix 11")
eq(Session.suffix(101), "Ce", "suffix 101")
-- the view builds with suffixes and nothing throws
local v = s:view()
eq(type(v), "table", "a view with SUFFIX")
s:setNotation("SCIENTIFIC")
for x, want in sci do eq(f(x), want, "scientific " .. x) end
-- a recovered session (NaN / error -> last good save) keeps the player's notation
s:setNotation("SUFFIX")
s:_recover(1.7e12 + 1000, "test")
eq(f("1234"), "1.23K", "SUFFIX survives a recover")
print(string.format("notation: %d checks, %d failures", n, fails))
if fails > 0 then error("notation failed") end
