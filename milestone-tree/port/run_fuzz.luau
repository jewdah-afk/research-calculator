--!nocheck
-- Luau side of the game differential test: luau run_fuzz.luau -a DIR [from] [to]   (reads data/DIR/fz_states, fz_skip)
-- Every state gets its own runtime + environment from the same required chunks, which also checks that separate
-- game instances (one per player on a server) stay isolated.
local L = require("./lib")
local args = { ... }
local dir = args[1] or "fz"
local states = L.JSRT(L.TN, L.BEcore).G.JSON.parse(L.data(dir, "fz_states"))
local skip = {}
for n in string.gmatch(L.data(dir, "fz_skip"), "[^,]+") do skip[tonumber(n)] = true end
local from, to = tonumber(args[2]) or 0, tonumber(args[3]) or 1e9
local t0 = os.clock()
local count = 0
for i = from, math.min(to, L.JSRT(L.TN, L.BEcore).len(states)) - 1 do
	if skip[i] then continue end
	local st = states[i]
	local ok, JS, ENV = pcall(L.harnessEnv, function(JS, ENV)
		JS.seed(st.seed); JS.NOW = 1.7e12; ENV.u__RESUME = st.save
		L.withDump(JS, ENV)
	end)
	if not ok then print("##S" .. i .. " BOOTERR " .. tostring(JS)) continue end
	local ok1, d1 = pcall(ENV.u__dumpAll, nil, "S" .. i .. " load")
	print(if ok1 then d1 else "##S" .. i .. " load DUMPERR " .. tostring(d1))
	local ok2, e2 = pcall(ENV.u__act, nil, st.acts)
	if ok2 then print(ENV.u__dumpAll(nil, "S" .. i .. " acts")) else print("##S" .. i .. " acts ERR " .. tostring(e2)) end
	count += 1
	print(string.format("-- S%d %.2fs", i, os.clock() - t0))
end
print(string.format("-- %d states in %.1fs", count, os.clock() - t0))
