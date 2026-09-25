--!nocheck
-- tick / view cost on fuzz states: luau perf.luau -a i1 i2 ...
local L = require("../lib")
local TN = L.TN
local Session = L.Session
local deps = L.deps()
local states = L.JSRT(TN, L.BEcore).G.JSON.parse(L.data("fz", "fz_states"))
for _, a in { ... } do
	local st = states[tonumber(a)]
	local now = 1.7e12
	local s = Session.new(deps, st.save, nil, now)
	local t0 = os.clock()
	for i = 1, 100 do now += 50; s:tick(now) end
	local tt = (os.clock() - t0) * 10
	t0 = os.clock()
	local v = 0
	for _, l in { "m", "p", "sp", "hp", "t", "mp", "pm", "cp" } do s:act({ "tab", l }, now); s:view() end
	print(string.format("S%s stage %.2f: tick %.2f ms, view %.2f ms  err=%s", a, st.stage, tt, (os.clock() - t0) * 1000 / 8, tostring(s.lastError)))
end
