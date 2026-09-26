--!nocheck
--[[
	Preload (src/client/Core/Preload.luau) on the mock engine: the asset list, PreloadAsync in batches with the
	per-asset progress, a PreloadAsync that throws or never returns (the timeout), and the ReplicatedFirst loading
	screen's 45 s safety net when the client never claims it.

	Run from port/: python3 tools/wrap_scripts.py && luau tests/unit/preload.luau
]]
local M = require("../mock")
local E = require("../engine")(M)
local game = M.game
local task = M.G.task

local failures = 0
local function check(ok, what)
	if ok then print("  ok    " .. what) else failures += 1; print("  FAIL  " .. what) end
end

local client = E.buildClient()
local p = M.addPlayer("Tester", 1)
game:GetService("Players").__props.LocalPlayer = p
local Preload = M.require(client.Core.Preload)

-- run Preload.run in its own thread and step frames until it returns (or `limit` s)
local function run(list, opts, limit)
	local calls, res = {}, nil
	local t0 = M.now
	task.spawn(function()
		res = table.pack(Preload.run(list, function(done, total) table.insert(calls, { done, total }) end, opts))
	end)
	local t = 0
	while res == nil and t < (limit or 30) do
		E.frames(0.1)
		t += 0.1
	end
	return res, calls, M.now - t0
end
local function ids(n)
	local out = {}
	for i = 1, n do out[i] = "rbxassetid://" .. (1000 + i) end
	return out
end

print("== the list")
local list = Preload.list({ "rbxassetid://1", "rbxassetid://2", "rbxassetid://1", "" }, "HIGH")
local seen, dup, strings, labels = {}, false, 0, 0
for _, x in list do
	if type(x) == "string" then
		if seen[x] then dup = true end
		seen[x] = true
		strings += 1
	elseif x.__class == "TextLabel" then
		labels += 1
	end
end
check(list[1] == "rbxassetid://1" and list[2] == "rbxassetid://2", "the map's own tiles come first")
check(not dup and not seen[""], "deduped, no empty ids")
local UiKit = require("../../../src/shared/UiKit")
local NodeAtlas = require("../../../src/shared/NodeAtlas")
check(seen[UiKit.id] and seen[NodeAtlas.id], "the UI kit and the node atlas")
check(labels >= 2, "a label per font face (" .. labels .. ")")

print("== PreloadAsync at once")
E.preload = nil
E.preloads = {}
local res, calls, took = run(ids(20), { batch = 8 })
check(res and res[1] == 20 and res[2] == 20 and res[3] == false, "20 of 20, no timeout")
check(#E.preloads == 3 and #E.preloads[1] == 8 and #E.preloads[3] == 4, "in batches of 8 (" .. #E.preloads .. " calls)")
local mono = true
for i = 2, #calls do
	if calls[i][1] < calls[i - 1][1] then mono = false end
end
check(#calls == 20 and calls[#calls][1] == 20 and mono, "one progress call per asset, counting up to the total")
check(took < 0.2, "no waiting when every batch is back")

print("== slow assets")
E.preload, E.preloadDelay = "slow", 0.2
E.preloads = {}
res, calls, took = run(ids(16), { batch = 8 })
check(res and res[1] == 16 and res[3] == false, "16 of 16")
check(took >= 1.5 and took < 2.5, string.format("the batches load side by side (%.1f s for 8 x 0.2 s)", took))

print("== a PreloadAsync that throws")
E.preload = "error"
res, calls, took = run(ids(10), { batch = 4 })
check(res and res[1] == 10 and res[2] == 10 and res[3] == false, "its assets count as settled: 10 of 10")
check(#calls >= 1 and calls[#calls][1] == 10, "the progress reaches the total")
check(took < 0.2, "at once")

print("== a PreloadAsync that never returns")
E.preload = "hang"
res, calls, took = run(ids(10), { batch = 4, timeout = 2 }, 10)
check(res ~= nil and res[3] == true, "Preload.run returns at the timeout")
check(took >= 1.9 and took < 2.3, string.format("after %.1f s (timeout 2 s)", took))
local n = #calls
E.frames(1)
check(#calls == n, "no progress after it gave up")

print("== nothing to load")
E.preload = nil
res, calls = run({})
check(res and res[1] == 0 and res[2] == 0 and #calls == 1 and calls[1][2] == 0, "0 of 0, reported once")

print("== the loading screen's safety net")
E.runMain("Boot")
E.frames(1)
check(p.PlayerGui:FindFirstChild("MilestoneBoot") ~= nil, "the loading screen shows")
E.frames(43)
check(p.PlayerGui:FindFirstChild("MilestoneBoot") ~= nil, "it stays while the client may still claim it")
E.frames(2.5)
check(p.PlayerGui:FindFirstChild("MilestoneBoot") == nil, "unclaimed after 45 s: it fades out and is gone")

check((M.errors or 0) == 0, "no script errors (" .. tostring(M.errors or 0) .. ")")
if failures > 0 then error(failures .. " preload check(s) failed") end
print("preload: all passed")
