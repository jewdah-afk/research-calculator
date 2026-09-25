--!nocheck
--[[
	Overlay/ToastModel.luau (pure): coalescing, merged sub lines (a range or a count, never joined names), expiry,
	the history cap and the kind fallback. Run from port/: luau tests/unit/overlay.luau
]]
local T = require("../../../src/client/Overlay/ToastModel")

local failures, checks = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failures += 1
		print("  FAIL  " .. what)
	end
end

-- ranges and counts
check(T.mergedSub("milestone", { "18th Meta-Milestone", "19th Meta-Milestone", "27th Meta-Milestone" }) == "18th – 27th Meta-Milestone", "ordinal range")
check(T.mergedSub("milestone", { "Spark Milestone #2", "Spark Milestone #6" }) == "Spark Milestone #2 – #6", "hash range")
check(T.mergedSub("achievement", { "Getting richer?", "Even more boosters!!", "Get boosted" }) == "3 achievements", "achievements count")
check(T.mergedSub("milestone", { "1st milestone", "Spark Milestone #2" }) == "2 milestones", "mixed milestones count")
check(T.mergedSub("milestone", { "21st Meta-Milestone", "22nd Meta-Milestone", "23rd Meta-Milestone", "111th Meta-Milestone" }) == "21st – 111th Meta-Milestone", "suffixes")

-- coalescing within the life, a fresh toast after it
local m = T.new()
local a, merged = m:push({ kind = "milestone", title = "Milestone Gotten!", sub = "18th Meta-Milestone", layer = "mm" }, 0)
check(not merged and a.count == 1, "first toast")
local b, merged2 = m:push({ kind = "milestone", title = "Milestone Gotten!", sub = "19th Meta-Milestone", layer = "mm" }, 1)
check(merged2 and b == a and a.count == 2 and a.sub == "18th – 19th Meta-Milestone", "merge within the life")
local c = m:push({ kind = "achievement", title = "Achievement Gotten!", sub = "Getting richer?" }, 1.5)
check(c ~= a, "another kind is its own toast")
check(#m:active(2) == 2, "two live toasts")
check(m:active(2)[1] == c, "newest first")
local n1 = m:push({ kind = "notice", title = "Notice", sub = "Saved" }, 2)
local n2, nm = m:push({ kind = "notice", title = "Notice", sub = "Saved" }, 2.1)
check(n1 ~= n2 and not nm, "notices never merge")
check(#m:active(100) == 0, "all expired")
local d, merged3 = m:push({ kind = "milestone", title = "Milestone Gotten!", sub = "20th Meta-Milestone" }, 100)
check(not merged3 and d ~= a, "after the life a new toast starts")
for i = 1, 30 do m:push({ kind = "other", title = "T" .. i, sub = "" }, 200 + i * 10) end
check(#m:history() == T.HISTORY, "history keeps the last 20")
m:clear()
check(#m:history() == 0, "clear")

-- kinds
check(T.kindOf({ kind = "milestone" }) == "milestone", "kind from the view")
check(T.kindOf({ kind = "other", title = "Challenge Complete!" }) == "challenge", "kind guessed")
check(T.kindOf({ title = "Corruption Info", type = "none" }) == "corruption", "corruption")
check(T.plain("You got <b>it</b>&nbsp;now<br>ok") == "You got it now ok", "plain text")

print(string.format("overlay: %d checks, %d failures", checks, failures))
if failures > 0 then error("overlay failed", 0) end
