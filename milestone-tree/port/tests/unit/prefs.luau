--!nocheck
--[[
	shared/PrefsSchema: the device options the client and the server share. Old stored records (the first four keys
	only) load with defaults, wrong values fall back, unknown keys are dropped, seenPrestige is a short list of layer
	ids.

	Run from port/: luau tests/unit/prefs.luau
]]
local S = require("../../../src/shared/PrefsSchema")

local failures, checks = 0, 0
local function check(ok, what)
	checks += 1
	if not ok then failures += 1; print("  FAIL  " .. what) end
end

check(S.clean(nil) == nil, "nil is not a record")
check(S.clean("x") == nil, "a string is not a record")

local d = S.defaults()
check(d.motion == "SYSTEM" and d.size == 100 and d.weather == "RESETS" and d.guide == "ON", "defaults")
check(type(d.seenPrestige) == "table" and #d.seenPrestige == 0, "seenPrestige defaults to an empty list")

-- a record saved before the new keys existed
local old = S.clean({ motion = "REDUCED", detail = "LOW", labels = "OFF", size = 115 })
check(old.motion == "REDUCED" and old.detail == "LOW" and old.labels == "OFF" and old.size == 115, "old keys kept")
check(old.weather == "RESETS" and old.music == 60 and old.sfx == 70 and old.ambience == 60, "new keys defaulted")

-- wrong values fall back, unknown keys are dropped
local bad = S.clean({ motion = "FAST", size = 101, music = 55, sfx = 100, hack = true, guide = "OFF" })
check(bad.motion == "SYSTEM" and bad.size == 100 and bad.music == 60, "wrong values fall back")
check(bad.sfx == 100 and bad.guide == "OFF", "right values kept")
check(bad.hack == nil, "unknown keys dropped")

-- seenPrestige
check(S.valid("seenPrestige", { "m", "p", "pep" }), "a list of layer ids")
check(not S.valid("seenPrestige", { "M" }), "upper case refused")
check(not S.valid("seenPrestige", { "toolong" }), "long ids refused")
check(not S.valid("seenPrestige", { m = "m" }), "a map refused")
check(not S.valid("seenPrestige", { 1 }), "numbers refused")
local many = {}
for i = 1, S.MAX_SEEN + 1 do many[i] = "m" end
check(not S.valid("seenPrestige", many), "too many refused")
local rec = S.clean({ seenPrestige = { "m", "p" } })
check(#rec.seenPrestige == 2 and rec.seenPrestige[2] == "p", "seenPrestige kept")
local src = { "m" }
local copy = S.clean({ seenPrestige = src })
src[1] = "x"
check(copy.seenPrestige[1] == "m", "seenPrestige is copied")
check(#S.clean({ seenPrestige = "m" }).seenPrestige == 0, "a bad seenPrestige becomes empty")

-- every choice list holds its default
for key, list in S.CHOICES do
	check(table.find(list, S.DEFAULTS[key]) ~= nil, key .. ": the default is a choice")
end

print(("prefs: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error("prefs: failures") end
