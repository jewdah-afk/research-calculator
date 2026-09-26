--!nocheck
-- boards: the leaderboard list and number format (shared/Boards), and the stored keys (TowerNum.sortKey).
-- Run from port/ after tools/wrap_scripts.py: luau tests/unit/boards.luau
local M = require("../mock")
local L = require("../../lib")
local fails, n = 0, 0
local function check(ok, what)
	n += 1
	if not ok then fails += 1; print("  FAIL  " .. what) else print("  ok    " .. what) end
end
local RS = M.game:GetService("ReplicatedStorage")
M.module(RS, "TowerNum", function() return L.TN end)
local shared = M.G.Instance.new("Folder"); shared.Name = "MilestoneTree"; shared.Parent = RS
local inst
inst = M.module(shared, "Boards", function() return M.withScript(inst, require("../../data/wrap/shared/Boards")) end)
local Boards = M.require(inst)
local TN = L.TN

local function eq(x, want)
	local got = Boards.format(x)
	check(got == want, string.format("%s -> %s (got %s)", tostring(x), want, got))
end
print("== the leaderboard format")
eq(0, "0"); eq(57, "57"); eq(12.5, "12.5"); eq(999, "999")
eq(1000, "1.00K"); eq(84150, "84.2K"); eq(1.5e6, "1.50M"); eq(4.56e303, "4.56Ce")
eq("1e306", "1.00UCe"); eq("4.56e2997", "4.56OcNogNoce"); eq("4.56e3000", "4.56NoNogNoce"); eq("1.5e3002", "150NoNogNoce")
-- from e3,003: scientific, the exponent with commas, then the exponent suffixed with 4 figures
eq("1e3003", "e3,003"); eq("1e10000", "e10,000"); eq("1e100000", "e100,000"); eq("1e999999", "e999,999")
eq("1e1000000", "e1.000M"); eq("1e10000000", "e10.00M"); eq("1e1.08e25", "e10.80Sp")
eq("ee198188918", "ee198.2M"); eq("ee3500", "ee3,500"); eq("ee1e3003", "eee3,003")
check(string.find(Boards.format(TN.tetrate10(20)), "e^", 1, true) ~= nil, "a tall tower reads in TowerNum's (e^n) form (" .. Boards.format(TN.tetrate10(20)) .. ")")

print("== keys")
local p = Boards.get("points")
local k1, k2 = Boards.keyOf(p, "1e1000"), Boards.keyOf(p, "ee198188918")
check(k1 > 0 and k2 > k1 and k2 < 2^63, "big keys sort like the values and fit an OrderedDataStore")
check(Boards.keyOf(p, "1.5e20") ~= Boards.keyOf(p, "1.6e20"), "close values keep apart")
check(Boards.show(p, k2) == "ee198.2M", "a stored key reads back (" .. Boards.show(p, k2) .. ")")
check(Boards.show(p, Boards.keyOf(p, 84150)) == "84.2K", "a small value reads back (" .. Boards.show(p, Boards.keyOf(p, 84150)) .. ")")
check(Boards.keyOf(p, 0) == 0 and Boards.keyOf(p, -5) == 0, "nothing and negatives store 0")
local m = Boards.get("m")
check(Boards.keyOf(m, 57) == 57 and Boards.show(m, 57) == "57", "counts are stored as they are")
check(Boards.show(Boards.get("time"), 3 * 86400 + 4 * 3600) == "3d 4h" and Boards.show(Boards.get("time"), 5 * 3600 + 12 * 60) == "5h 12m",
	"playtime reads as days / hours / minutes")
check(Boards.show(Boards.get("robux"), 1234) == "R$ 1,234", "robux read as R$")
check(#Boards.list == 24 and Boards.get("pep") ~= nil and Boards.get("time") ~= nil, "24 boards: points, every layer, achievements, playtime, robux")

print(string.format("boards: %d checks, %d failures", n, fails))
if fails > 0 then error("boards unit test failed", 0) end
