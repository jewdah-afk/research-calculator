--!nocheck
-- Luau side of probe.js: luau probe_run.luau -a STATE NACTS DIR
local L = require("./lib")
local args = { ... }
local states = L.JSRT(L.TN, L.BEcore).G.JSON.parse(L.data(args[3] or "fz", "fz_states"))
local st = states[tonumber(args[1])]
local nacts = tonumber(args[2]) or 0
local JS, ENV = L.harnessEnv(function(JS, ENV)
	JS.seed(st.seed); JS.NOW = 1.7e12; ENV.u__RESUME = st.save
	L.withDump(JS, ENV)
end)
local p = require("./gen/probe"); setfenv(p, ENV); p()
for k = 0, nacts - 1 do ENV.u__act(nil, JS.A(1, st.acts[k])) end
print(ENV.u__probe(nil))
