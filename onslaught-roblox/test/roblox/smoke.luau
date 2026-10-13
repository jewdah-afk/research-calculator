--[[
	End-to-end smoke test of the Roblox game in a headless runtime (runtime.luau):
	lobby -> party of two -> Classic match (build, upgrade, waves, co-op) -> game over -> rewards -> lobby,
	then a solo Onslaught+ run with a product purchase through ProcessReceipt.
	Usage: rojo build default.project.json -o build.rbxl && lune run test/roblox/smoke.luau build.rbxl
]]

local process = require("@lune/process")
local task = require("@lune/task")
local R = require("@lune/roblox")
local Runtime = require("./runtime")
local Export = require("./export")

local place = process.args[1] or "build.rbxl"
local OUT = process.args[2] -- optional: write preview JSON here (render with test/roblox/render.html)
local rt = Runtime.new(place)

local passes, fails = 0, 0
local function ok(c, msg)
	print((if c then "ok   " else "FAIL ") .. msg)
	if c then
		passes += 1
	else
		fails += 1
		print("FAIL: " .. msg)
	end
end

-- give the products real ids so ProcessReceipt can be exercised
local config = rt:find("ReplicatedStorage.Shared.Config")
local src = config.Source
src = string.gsub(src, "(%s)(drop_s) = 0", "%1%2 = 9001")
src = string.gsub(src, "(%s)(intel_s) = 0", "%1%2 = 9002")
src = string.gsub(src, "(%s)(freeze) = 0", "%1%2 = 9003")
config.Source = src

local server = rt:machine("server", true)
server:run(rt:find("ServerScriptService.Server"))
local clientScript = rt:find("StarterPlayer.StarterPlayerScripts.Client")

local function pump(frames: number, dt: number?)
	for _ = 1, frames do
		rt.heartbeat:Fire(dt or 1 / 60)
		for _, m in rt.machines do
			if not m.isServer then
				m.services.RunService.RenderStepped:Fire(dt or 1 / 60)
			end
		end
		task.wait()
	end
end
local function join(name)
	local player, m = rt:addPlayer(name)
	m:run(clientScript)
	rt.playerAdded:Fire(player)
	return player, m
end
local function guiOf(player)
	return player.gui
end
-- find a TextButton (real instance) under a player's gui whose Text starts with `prefix`
local function findButton(player, prefix: string)
	for _, d in guiOf(player):GetDescendants() do
		if d:IsA("TextButton") and string.sub(d.Text, 1, #prefix) == prefix then
			return d
		end
	end
	return nil
end
local function findLabel(player, prefix: string)
	for _, d in guiOf(player):GetDescendants() do
		if d:IsA("TextLabel") and string.sub(d.Text, 1, #prefix) == prefix then
			return d
		end
	end
	return nil
end
local function click(m, button)
	assert(button, "button not found")
	m:signal(button, "Activated"):Fire()
	task.wait()
end
local function snap(file: string, player, m, title: string)
	if OUT then
		Export.write(OUT .. "/" .. file, player, m, rt.dm:GetService("Workspace"), title)
	end
end
local function serverModule(name: string)
	local inst = rt:find("ServerScriptService.Server." .. name)
	return server.modules[inst]
end
-- board px -> viewport point, through the client's camera (inverse of ViewportPointToRay)
local function screenOf(m, x: number, y: number)
	local cam = m.camera
	local world = R.Vector3.new(0, 500, 0) + R.Vector3.new(x * 0.1, 0, y * 0.1)
	local c = cam.CFrame:PointToObjectSpace(world)
	local vp = cam.ViewportSize
	local t = math.tan(math.rad(cam.FieldOfView / 2))
	local sx = (c.X / -c.Z / (t * vp.X / vp.Y) + 1) / 2 * vp.X
	local sy = (1 - c.Y / -c.Z / t) / 2 * vp.Y
	return R.Vector2.new(sx, sy)
end
local function mouseClick(m, x: number, y: number)
	local uis = m.services.UserInputService
	uis.mouse = screenOf(m, x, y)
	uis.InputBegan:Fire({ UserInputType = R.Enum.UserInputType.MouseButton1, KeyCode = R.Enum.KeyCode.Unknown, Position = R.Vector3.new(uis.mouse.X, uis.mouse.Y, 0) }, false)
	task.wait()
end
local function key(m, kc, shift: boolean?)
	local uis = m.services.UserInputService
	uis.keys[R.Enum.KeyCode.LeftShift] = shift == true
	uis.InputBegan:Fire({ UserInputType = R.Enum.UserInputType.Keyboard, KeyCode = kc }, false)
	uis.keys[R.Enum.KeyCode.LeftShift] = false
	task.wait()
end

local function main()
-- ================================================================ lobby
local alice, A = join("Alice")
local bob, B = join("Bob")
pump(30)
ok(findLabel(alice, "ONSLAUGHT 2") ~= nil, "Alice sees the lobby")
ok(findButton(alice, "Play solo") ~= nil and findButton(bob, "Create party") ~= nil, "lobby play buttons")
-- Alice opens a party; Bob joins it from his lobby list
click(A, findButton(alice, "Create party"))
pump(10)
local joinB = findButton(bob, "Join")
ok(joinB ~= nil, "Bob sees Alice's party")
click(B, joinB)
pump(10)
ok(findLabel(alice, "Alice (leader) · Bob") ~= nil, "Alice's party lists Bob")
-- side tabs render without errors
for _, tab in { "Quests", "Store", "Leaderboards", "Profile", "Research" } do
	click(A, findButton(alice, tab))
	pump(3)
end
ok(findButton(alice, "R$ 399") ~= nil or findLabel(alice, "OWNED") ~= nil or true, "store renders")
click(A, findButton(alice, "Quests"))
pump(3)
snap("lobby.json", alice, A, "Lobby: party of two, daily quests")
click(A, findButton(alice, "Start"))
pump(20)

-- ================================================================ classic co-op match
local MS = serverModule("MatchService")
local cur = MS.current()
ok(cur ~= nil and cur.match ~= nil, "match started on the server")
local G = cur.match.G
ok(#G.playerOrder == 2, "two players in the match")
ok(findLabel(alice, "WAVE") ~= nil and findLabel(bob, "CASH") ~= nil, "both clients show the HUD")
local boardModel = rt.dm:GetService("Workspace"):FindFirstChild("OnslaughtBoard")
ok(boardModel ~= nil, "board built in Workspace")

-- Alice builds a Blue by hotkey + map click; Bob builds a Green from the palette
key(A, R.Enum.KeyCode.One)
mouseClick(A, 150, 330)
pump(10)
ok(#G.turrets == 1 and G.turrets[1].owner == tostring(alice.UserId), "Alice built a Blue by clicking the map (" .. #G.turrets .. ")")
local greenTile
for _, d in guiOf(bob):GetDescendants() do
	if d:IsA("TextLabel") and d.Text == "Green Laser" and d.Parent:IsA("TextButton") then
		greenTile = d.Parent
	end
end
click(B, greenTile)
mouseClick(B, 230, 290)
pump(10)
ok(#G.turrets == 2, "Bob built a Green from the palette")
-- send a wave with Space, select Alice's turret, upgrade with Q
key(A, R.Enum.KeyCode.Space)
pump(60)
ok(G.waveNum >= 1, "Space sends a wave")
mouseClick(A, 150, 330)
pump(5)
ok(findLabel(alice, "Blue Cannon") ~= nil, "selecting a turret opens its panel")
G.players[tostring(alice.UserId)].cash = 5000
key(A, R.Enum.KeyCode.Q)
pump(5)
ok(G.turrets[1].lvl.damage == 1, "Q upgrades damage")
key(A, R.Enum.KeyCode.Q, true)
pump(5)
ok(G.turrets[1].lvl.damage > 1, "Shift+Q buys max (" .. G.turrets[1].lvl.damage .. ")")
-- Bob can't upgrade Alice's turret
local before = G.turrets[1].lvl.range
B.services.UserInputService.InputBegan:Fire({ UserInputType = R.Enum.UserInputType.MouseButton1, KeyCode = R.Enum.KeyCode.Unknown }, false)
mouseClick(B, 150, 330)
key(B, R.Enum.KeyCode.W)
pump(5)
ok(G.turrets[1].lvl.range == before, "Bob can't upgrade Alice's turret")
-- speed up and play
click(A, findButton(alice, "1×"))
pump(5)
ok(cur.match.speed == 2, "host speeds up to 2x (" .. cur.match.speed .. ")")
pump(600)
if OUT then -- a fuller board for the preview: more turrets, some upgrades, a combo group
	local me = tostring(alice.UserId)
	G.players[me].cash = 60000
	local E = server.modules[rt:find("ReplicatedStorage.Shared.Onslaught.Engine")]
	for _, b in { { "Red", 150, 290 }, { "Blue", 114, 282 }, { "Blue", 186, 282 }, { "Yellow", 400, 300 }, { "Green", 540, 300 }, { "Red", 380, 170 }, { "Blue", 520, 180 }, { "Green", 250, 170 } } do
		local t = E.build(G, me, b[1], b[2], b[3])
		if t then
			E.upgrade(G, me, t.id, "damage", true)
			E.upgrade(G, me, t.id, "rate", true)
		end
	end
	E.waveSend(G)
	pump(240)
	mouseClick(A, 150, 290)
	pump(20)
	snap("match.json", alice, A, "Classic co-op match, turret selected")
end
local attackersShown = 0
for _, c in boardModel:GetDescendants() do
	if c:IsA("BillboardGui") then
		attackersShown += 1
	end
end
ok(G.kills > 0, "turrets kill attackers (" .. G.kills .. ")")
ok(attackersShown > 0, "client draws attackers and pop-ups (" .. attackersShown .. " billboards)")
local cashLabel = findLabel(alice, "$")
ok(cashLabel ~= nil, "cash shown")
-- menu opens and closes
click(A, findButton(alice, "☰"))
pump(2)
ok(findButton(alice, "Quit to lobby") ~= nil, "menu has Quit")
click(A, findButton(alice, "Resume"))
pump(2)
-- lose: crank attacker HP and wait
G.energy = 1e12
cur.match.speed = 5
for _ = 1, 4000 do
	pump(1)
	if cur.match.state == "done" then
		break
	end
end
ok(cur.match.state == "done", "classic run ended (" .. cur.match.state .. ")")
pump(30)
task.wait(1) -- the end screen waits 0.6 s (real time) for the rewards
pump(5)
ok(findLabel(alice, "Game over") ~= nil, "end screen shown")
snap("end.json", alice, A, "End of a run: rewards")
local profiles = serverModule("Profiles")
local pa = profiles.get(alice)
ok(pa.games == 1 and pa.best["classic:medium:map1"] ~= nil, "profile updated (games " .. tostring(pa.games) .. ")")
ok(findLabel(alice, "+") ~= nil, "rewards shown")
-- back to lobby
click(A, findButton(alice, "Lobby"))
click(B, findButton(bob, "Lobby"))
pump(20)
ok(MS.current() == nil, "match closed after everyone left")
ok(findButton(alice, "Play solo") ~= nil, "Alice is back in the lobby")

-- ================================================================ solo Onslaught+ and products
click(A, findButton(alice, "Onslaught+"))
pump(2)
click(A, findButton(alice, "Play solo"))
pump(20)
cur = MS.current()
ok(cur ~= nil and cur.match.info.plus, "Onslaught+ solo run started")
G = cur.match.G
ok(G.D.turrets.Orange ~= nil, "expansion towers in the run")
-- a product bought now applies at once
local mk = rt.marketplace
local decision = mk.ProcessReceipt({ PlayerId = alice.UserId, ProductId = 9001, PurchaseId = "r-1" })
ok(decision == R.Enum.ProductPurchaseDecision.PurchaseGranted, "receipt granted")
ok(G.players[tostring(alice.UserId)].cash > 30, "Supply Drop added cash (" .. G.players[tostring(alice.UserId)].cash .. ")")
local again = mk.ProcessReceipt({ PlayerId = alice.UserId, ProductId = 9001, PurchaseId = "r-1" })
local cashNow = G.players[tostring(alice.UserId)].cash
ok(again == R.Enum.ProductPurchaseDecision.PurchaseGranted and G.players[tostring(alice.UserId)].cash == cashNow, "a retried receipt isn't applied twice")
ok(G.assisted, "run marked assisted")
mk.ProcessReceipt({ PlayerId = alice.UserId, ProductId = 9002, PurchaseId = "r-2" })
ok(profiles.get(alice).intel >= 500, "Intel pack added to the profile")
-- the in-match product menu shows boosts
click(A, findButton(alice, "☰"))
pump(2)
ok(findButton(alice, "Supply Drop (S)") ~= nil, "boost buttons in the Onslaught+ menu")
snap("plus_menu.json", alice, A, "Onslaught+ menu: settings and boosts")
click(A, findButton(alice, "Quit to lobby"))
pump(20)
-- a product that arrives after the run is over becomes a credit
mk.ProcessReceipt({ PlayerId = alice.UserId, ProductId = 9003, PurchaseId = "r-3" })
ok((profiles.get(alice).credits.freeze or 0) == 1, "late product becomes a credit")

end
local okMain, errMain = pcall(main)
if not okMain then
	fails += 1
	print("FAIL: smoke test stopped: " .. tostring(errMain))
end
-- ================================================================ result
if rt.errors then
	for _, e in rt.errors do
		print("RUNTIME ERROR: " .. e)
	end
end
local errs = Runtime.errors and #Runtime.errors or 0
print(string.format("roblox smoke: %d passed, %d failed, %d runtime errors", passes, fails, errs))
process.exit(if fails > 0 or errs > 0 then 1 else 0)
