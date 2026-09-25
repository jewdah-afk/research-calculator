--!nocheck
-- Headless Luau run of the port with the deterministic bot (compare with: node js_run.js TICKS DT EVERY)
-- usage: luau run.luau -a TICKS DT EVERY
local L = require("./lib")
local args = { ... }
local TICKS, DT, EVERY = tonumber(args[1]) or 2000, tonumber(args[2]) or 0.05, tonumber(args[3]) or 200
local t0 = os.clock()
local JS, ENV = L.harnessEnv(function(JS) JS.NOW = 1.7e12 end)
local t1 = os.clock()
for i = 1, TICKS do
	JS.NOW += DT * 1000
	local ok, err = xpcall(ENV.u__tick, debug.traceback, nil, DT)
	if not ok then print("TICK " .. i .. " FAIL: " .. tostring(err)); return end
	if i % EVERY == 0 then print(ENV.u__snap(nil, i)) end
end
print(string.format("-- load %.2fs, %d ticks %.2fs (%.2f ms/tick)", t1 - t0, TICKS, os.clock() - t1, (os.clock() - t1) * 1000 / TICKS))
