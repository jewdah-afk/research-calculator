--!nocheck
-- shop: the game-pass perks and Time Warps on a Session (Session:setPerks / addWarp), and the Products table.
-- Run from port/: luau tests/unit/shop.luau
local L = require("../../lib")
local Session = L.Session
local Products = require("../../../src/shared/Products")
local fails, n = 0, 0
local function check(ok, what)
	n += 1
	if not ok then fails += 1; print("  FAIL  " .. what) else print("  ok    " .. what) end
end
local states = L.JSRT(L.TN, L.BEcore).G.JSON.parse(L.data("fz", "fz_states"))
local save = states[5].save
local function played(s) return s.JS.tonum(s.ENV.player.timePlayed) end

-- 2x Speed: the same real time counts twice
local t0 = 1.7e12
local a = Session.new(L.deps(), save, nil, t0)
local b = Session.new(L.deps(), save, nil, t0)
b:setPerks({ speed = 2 })
check(b.ENV.player.devSpeed == 2 and a.ENV.player.devSpeed == nil, "the speed pass sets the game's devSpeed")
local pa0, pb0 = played(a), played(b)
local now = t0
for _ = 1, 40 do now += 50; a:tick(now); b:tick(now) end
local da, db = played(a) - pa0, played(b) - pb0
check(math.abs(da - 2) < 0.2 and math.abs(db - 4) < 0.4, string.format("2 s of real time: %.2f s without, %.2f s with 2x Speed", da, db))
b:setPerks({})
check(b.ENV.player.devSpeed == nil, "no pass, no devSpeed")
b:setPerks({ speed = 2 })
b:_recover(now, "test")
check(b.ENV.player.devSpeed == 2, "the speed survives a recover")

-- a 1 hour Time Warp: done within a few seconds, the game clock stays real
local c = Session.new(L.deps(), save, nil, now)
local pc0 = played(c)
c:addWarp(3600)
local ticks = 0
while (c.warp or 0) > 0 and ticks < 400 do now += 50; c:tick(now); ticks += 1 end
local dc = played(c) - pc0
check(ticks <= 100, "the warp is used up in " .. ticks .. " ticks (" .. ticks * 0.05 .. " s)")
-- (plus the real time and the save's own few seconds of offline catch-up, which the warp waits for)
local extraTime = dc - 3600 - ticks * 0.05
check(extraTime > -0.5 and extraTime < 3, string.format("the warp added an hour of play (%.1f s, %.1f s besides)", dc, extraTime))
check(c.JS.tonum(c.ENV.player.time) == now, "the game clock is the real time after the warp")
check(c.wantSave == true, "a save is asked for once the warp is done")
now += 50; c:tick(now)
local dc2 = played(c) - pc0 - dc
check(dc2 > 0 and dc2 < 0.2, string.format("the next tick is a normal one (%.3f s)", dc2))

-- the Products table
local keys = {}
for _, p in Products.passes do keys[p.key] = p end
for _, p in Products.products do keys[p.key] = p end
check(keys.speed and keys.supporter and keys.warp1 and keys.warp8 and keys.warp24, "passes speed + supporter, warps 1 / 8 / 24 h")
for _, p in Products.products do check(p.price > 0 and p.warp and p.warp > 0, p.key .. " has a price and a warp") end
check(Products.pass("speed").speed == 2, "the speed pass is 2x")

print(string.format("shop: %d checks, %d failures", n, fails))
if fails > 0 then error("shop failed") end
