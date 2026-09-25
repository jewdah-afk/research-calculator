--!nocheck
-- Luau side of the view parity test: luau view_run.luau -a DIR [from] [to]   (reads data/DIR/fz_states, fz_skip)
local L = require("./lib")
local args = { ... }
local dir = args[1] or "fz"
local vd = require("./gen/view_dump")
local states = L.JSRT(L.TN, L.BEcore).G.JSON.parse(L.data(dir, "fz_states"))
local skip = {}
for n in string.gmatch(L.data(dir, "fz_skip"), "[^,]+") do skip[tonumber(n)] = true end
local from, to = tonumber(args[2]) or 0, tonumber(args[3]) or 1e9
local t0 = os.clock()
for i = from, math.min(to, L.JSRT(L.TN, L.BEcore).len(states)) - 1 do
	if skip[i] then continue end
	local st = states[i]
	local JS = L.JSRT(L.TN, L.BEcore)
	local ENV = JS.ENV
	JS.seed(st.seed); JS.NOW = 1.7e12
	for _, f in L.rbx do setfenv(f, ENV); f() end
	setfenv(vd, ENV); vd()
	JS.overrides()
	local ok, err = pcall(ENV.rbx_boot, nil, st.save, "")
	if not ok then print("##S" .. i .. " BOOTERR " .. tostring(err)) continue end
	local ok1, d1 = pcall(ENV.rbx_viewDump, nil, "S" .. i)
	print(if ok1 then d1 else "##S" .. i .. " DUMPERR " .. tostring(d1))
	local ok2, d2 = pcall(ENV.rbx_viewActs, nil, "S" .. i, st.acts)
	print(if ok2 then d2 else "##S" .. i .. " ACTERR " .. tostring(d2))
	print(string.format("-- S%d %.2fs", i, os.clock() - t0))
end
