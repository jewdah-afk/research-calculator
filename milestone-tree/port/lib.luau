--!nocheck
-- What the command-line runners load: TowerNum, the runtime, the Session and the transpiled game, straight from the
-- Roblox project (so the tests run exactly what the game ships), plus the harness-only chunks in ./gen.
local L = {}
L.TN = require("../vendor/TowerNum")
L.JSRT = require("../src/server/Runtime/JSRT")
L.BEcore = require("../src/server/Runtime/BEcore")
L.Session = require("../src/server/Session")
L.Html = nil -- tests that need it require ../src/shared/Html themselves (it wants Color3)

local function split(s)
	local t = {}
	for n in string.gmatch(s, "[^,]+") do table.insert(t, n) end
	return t
end
-- the Roblox game instance: game files, stubs, rbx_session, rbx_view
L.rbxNames = split(require("../src/server/Game/Manifest"))
L.rbx = {}
for i, n in L.rbxNames do L.rbx[i] = require("../src/server/Game/" .. n) end
-- the headless harness (boot.js resumes from __RESUME, bot.js drives the fuzz): game files, stubs, boot, bot
L.harnessNames, L.harness = {}, {}
for i, n in L.rbxNames do
	if n ~= "rbx_session" and n ~= "rbx_view" then
		table.insert(L.harnessNames, n)
		table.insert(L.harness, L.rbx[i])
	end
end
table.insert(L.harnessNames, "boot"); table.insert(L.harness, require("./gen/boot"))
table.insert(L.harnessNames, "bot"); table.insert(L.harness, require("./gen/bot"))
L.dump = require("./gen/dump")

-- a fresh game environment with the harness loaded (boot runs __RESUME if set by `before`)
function L.harnessEnv(before)
	local JS = L.JSRT(L.TN, L.BEcore)
	local ENV = JS.ENV
	if before then before(JS, ENV) end
	for i, n in L.harnessNames do
		if n == "boot" then JS.overrides() end
		setfenv(L.harness[i], ENV)
		L.harness[i]()
	end
	return JS, ENV
end
function L.withDump(JS, ENV)
	setfenv(L.dump, ENV)
	L.dump()
end
-- the deps table Session.new wants
function L.deps()
	return { TN = L.TN, JSRT = L.JSRT, BEcore = L.BEcore, chunks = L.rbx }
end
-- a data file written by the JS side (states, cases): data/<dir>/<name>.luau returns a string
function L.data(dir, name)
	return require("./data/" .. (dir or ".") .. "/" .. name)
end
return L
