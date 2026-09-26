--!nocheck
local L = require("../lib")
local Session = L.Session
local deps = L.deps()
local states = L.JSRT(L.TN, L.BEcore).G.JSON.parse(L.data("fz", "fz_states"))
local st = states[tonumber(({...})[1] or "10")]
local now = 1.7e12
local s = Session.new(deps, st.save, nil, now)
for i = 1, 1500 do now += 50; s:tick(now) end
