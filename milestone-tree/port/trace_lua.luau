--!nocheck
-- Luau side of trace_js.js: luau trace_lua.luau -a DIR STATE 'luau expression over ENV / JS'
local L = require("./lib")
local args = { ... }
local states = L.JSRT(L.TN, L.BEcore).G.JSON.parse(L.data(args[1], "fz_states"))
local st = states[tonumber(args[2])]
local JS, ENV = L.harnessEnv(function(JS, ENV)
	JS.seed(st.seed); JS.NOW = 1.7e12; ENV.u__RESUME = st.save
	L.withDump(JS, ENV)
end)
local ex = loadstring("local ENV, JS = ...; return " .. args[3])
print("load", ex(ENV, JS))
for i = 0, JS.len(st.acts) - 1 do
	local a = st.acts[i]
	local t = os.clock()
	ENV.u__act(nil, JS.A(1, a))
	print(JS.G.JSON.stringify(a), ex(ENV, JS), string.format("%.2fs", os.clock() - t))
end
