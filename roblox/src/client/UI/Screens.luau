--!nonstrict
-- Screens: windows that have no squared Figma frame yet (FIGMA_INVENTORY: Profile / Settings / Leaderboards /
-- Offline exist only in the older UI v2 style on the Missing screens board 177:*, Fast Travel is game-only).
-- Built in code with FKit, the Luau port of docs/figma/kit.js, so they use the exact recipes every Figma window was
-- made from (square-top WINDOW, segmented TABS, STEEL rows, WELL values, Kit keys, BODY text). When the squared
-- frames are designed, export them like the others and point WindowDefs at the layouts instead.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Defs = require(Shared:WaitForChild("Defs"))
local World = require(Shared:WaitForChild("World"))
local Render = require(script.Parent.Figma.Render)
local FKit = require(script.Parent.Figma.FKit)
local Kit = require(script.Parent.Kit)
local SampleData = require(script.Parent.SampleData)
local EN = Defs.EN

local Screens = {}
local Hud, WM

local PAL = FKit.PAL
local function add(p, c) p.k = p.k or {}; table.insert(p.k, c); return c end
local function fmt(v) return EN.short(v) end

local TABS = { { label = "PROFILE", icon = "birb", id = "profile" }, { label = "SETTINGS", icon = "settings", id = "settings" }, { label = "LEADERBOARDS", icon = "trophy", id = "leaderboards" } }
local function profileTabs(L, win, active)
	local t = {}
	for i, tb in TABS do t[i] = { label = tb.label, icon = tb.icon, active = tb.id == active } end
	add(win, FKit.TABSn(L, 16, 86, win.w - 32, t))
end

-- ---------------------------------------------------------------- PROFILE
local STATS = {
	{ "Eggs", "egg", function(s) return fmt(s.popcorn) end }, { "Plumes", "plume", function(s) return fmt(s.goldenFeathers) end },
	{ "Seeds", "seed", function(s) return fmt(s.sunflowerSeeds) end }, { "Golden eggs", "egg_golden", function(s) return fmt(s.goldenPopcorn) end },
	{ "Brute ore", "ore", function(s) return fmt(s.bruteOre) end }, { "Twigs", "twig", function(s) return fmt(s.twigs) end },
	{ "Echo eggs", "echo", function(s) return fmt(s.echoPopcorn) end }, { "Moneta", "moneta", function(s) return fmt(s.moneta) end },
	{ "Molts", "plume", function(s) return tostring(s.rebirbCount) end }, { "Evolutions", "monster", function(s) return tostring(s.evolutionCount) end },
	{ "Crow", "crow", function(s) return "LV " .. s.crow.level end }, { "Parrot", "parrot", function(s) return "LV " .. s.parrot.level end },
	{ "Sparrows", "sparrow", function(s) return tostring(s.sparrow.count) end }, { "Migrations", "seagull", function(s) return tostring(s.seagull.migrations) end },
	{ "Fish caught", "fish", function(s) return Hud.commas(s.stats.fishCaught) end }, { "Quests", "quest_scroll", function(s) return tostring(s.stats.questsDone) end },
	{ "Best floor", "parrot", function(s) return tostring(s.parrot.best) end }, { "Play time", "clock", function(s) return math.floor(s.stats.playTime / 3600) .. "h" end },
}
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII" }
local function buildProfile(parent)
	local W, H = 1000, 800
	local L = FKit.layout()
	local win = FKit.WINDOWn(L, "Window / Profile", W, H, "gold", "PROFILE")
	profileTabs(L, win, "profile")
	-- hero
	local hero = add(win, FKit.STEELn(L, "hero panel", 16, 156, W - 32, 140))
	local iw = add(hero, FKit.WELLn(L, "icon well", 14, 14, 112, 112))
	add(iw, FKit.ICOn("birb", 96, 8, 8, L))
	add(hero, FKit.Tn(L, Players.LocalPlayer.DisplayName, 32, { name = "player name", x = 144, y = 24, w = 520 }))
	add(hero, FKit.BODYn(L, "0 Molts  ·  0 Evolutions  ·  best floor 1", 17, { name = "hero sub", x = 144, y = 72, w = 560 }))
	add(hero, FKit.BTNn(L, "btn/leaderboards", W - 32 - 14 - 240, 34, 240, 72, PAL.blue, "LEADERBOARDS", { icon = "trophy", size = 20 }))
	-- records (left column)
	local REC = { { "FISH INDEX", "index", "Fish discovered" }, { "HIGHEST FLOOR", "parrot", "Expedition record" }, { "SACRIFICE", "altar", "Highest altar tier" } }
	for i, r in REC do
		local row = add(win, FKit.STEELn(L, "record/" .. i, 16, 308 + (i - 1) * 132, 470, 120))
		local w = add(row, FKit.WELLn(L, "icon well", 12, 12, 96, 96))
		add(w, FKit.ICOn(r[2], 80, 8, 8, L))
		add(row, FKit.Tn(L, r[1], 21, { name = "title", x = 122, y = 12, w = 330 }))
		add(row, FKit.BODYn(L, r[3], 14, { name = "desc", x = 122, y = 44, w = 330 }))
		add(row, FKit.BARn(L, "bar", 122, 76, 330, 26, 0.3, PAL.gold, "0 / 0"))
	end
	-- all stats (right column)
	local panel = add(win, FKit.STEELn(L, "all stats", 498, 308, W - 498 - 16, 384))
	add(panel, FKit.Tn(L, "ALL STATS", 18, { x = 16, y = 10, w = 200, col = "ffd36b" }))
	for i, st in STATS do
		local col, rw = (i - 1) % 2, math.floor((i - 1) / 2)
		local chip = add(panel, FKit.WELLn(L, "stat/" .. st[1], 12 + col * 236, 42 + rw * 37, 226, 31, { op = 0.55 }))
		add(chip, FKit.ICOn(st[2], 24, 4, 3, L))
		add(chip, FKit.BODYn(L, st[1], 13, { name = "name", x = 32, y = 7, w = 110 }))
		add(chip, FKit.Tn(L, "0", 14, { name = "value", x = 120, y = 6, w = 100, ax = "R", sw = 1.4, sh = 1 }))
	end
	add(win, FKit.BODYn(L, "Records show on the leaderboards  ·  stats update live", 14, { x = 0, y = H - 40, w = W, ax = "C", col = "8d94a3" }))
	FKit.OUTLINEn(L, win)
	local ui = FKit.build(L, win, parent)
	ui.on("btn/leaderboards", function() WM.open("leaderboards") end)
	ui.update = function(s, d)
		Render.setText(ui.find("hero sub"), Hud.commas(s.rebirbCount) .. " Molts  ·  " .. s.evolutionCount .. " Evolutions  ·  best floor " .. s.parrot.best)
		local recs = {
			{ d.discovered, #Defs.FISH, d.discovered .. " / " .. #Defs.FISH },
			{ s.parrot.best, 12, "Floor " .. s.parrot.best },
			{ s.sacrifice.tier, 18, if s.sacrifice.tier > 0 then "Tier " .. ROMAN[s.sacrifice.tier] .. " / 18" else "None yet" },
		}
		for i, r in recs do
			local row = ui.find("record/" .. i)
			local bar = row and row:FindFirstChild("bar", true)
			if bar then
				local fill = bar:FindFirstChild("fill")
				if fill then fill.Size = UDim2.fromOffset(math.floor(330 * math.clamp(r[1] / r[2], 0, 1) + 0.5), 26) end
				for _, t in Render.childTexts(bar) do Render.setText(t, r[3]) end
			end
		end
		for _, st in STATS do
			local chip = ui.find("stat/" .. st[1])
			local v = chip and chip:FindFirstChild("value", true)
			if v then Render.setText(v, st[3](s)) end
		end
	end
	return ui, W, H
end

-- ---------------------------------------------------------------- SETTINGS
local SETTINGS = {
	{ id = "sound", title = "SOUND", desc = "Buttery keycap clicks and effect cues", icon = "settings", get = function() return not Kit.muted end, set = function(v) Kit.muted = not v end },
	{ id = "music", title = "MUSIC", desc = "Area theme per island (coming with the music set)", icon = "sparrow", local_ = true },
	{ id = "motion", title = "REDUCED MOTION", desc = "Fades instead of bounces", icon = "clock", local_ = true, off = true },
	{ id = "numbers", title = "NUMBERS", desc = "1.2Qa letters or 1.2e15", icon = "index", choice = { "SHORT", "SCIENTIFIC" } },
	{ id = "graphics", title = "GRAPHICS", desc = "Props, fog and fireflies", icon = "map", choice = { "HIGH", "LOW" } },
	{ id = "offline", title = "OFFLINE EARNINGS", desc = "Welcome back summary (8h cap)", icon = "redpanda", open = "offline" },
}
local localPrefs = {}
local function buildSettings(parent)
	local W, H = 1000, 800
	local L = FKit.layout()
	local win = FKit.WINDOWn(L, "Window / Settings", W, H, "crow", "SETTINGS")
	profileTabs(L, win, "settings")
	for i, st in SETTINGS do
		local row = add(win, FKit.STEELn(L, "setting/" .. st.id, 16, 156 + (i - 1) * 96, W - 32, 86))
		local w = add(row, FKit.WELLn(L, "icon well", 12, 10, 66, 66))
		add(w, FKit.ICOn(st.icon, 54, 6, 6, L))
		add(row, FKit.Tn(L, st.title, 22, { name = "title", x = 94, y = 14, w = 500 }))
		add(row, FKit.BODYn(L, st.desc, 15, { name = "desc", x = 94, y = 50, w = 600 }))
		add(row, FKit.BTNn(L, "btn/" .. st.id, W - 32 - 14 - 200, 12, 200, 62, PAL.green, if st.open then "VIEW" else "ON", { size = 22 }))
	end
	add(win, FKit.BODYn(L, "Sound applies now  ·  other settings are placeholders until their systems land", 14, { x = 0, y = H - 40, w = W, ax = "C", col = "8d94a3" }))
	FKit.OUTLINEn(L, win)
	local ui = FKit.build(L, win, parent)
	local function paint(st)
		local key = ui.find("btn/" .. st.id)
		if not key then return end
		local label, on
		if st.open then label, on = "VIEW", true
		elseif st.choice then
			local i = localPrefs[st.id] or 1
			label, on = st.choice[i], i == 1
		else
			on = if st.get then st.get() elseif localPrefs[st.id] ~= nil then localPrefs[st.id] else not st.off
			label = if on then "ON" else "OFF"
		end
		local face = key:FindFirstChild("face")
		for _, t in Render.childTexts(face) do Render.setText(t, label) end
		local cols = if on then PAL.green else PAL.steel
		for _, part in { { face, 1 }, { key:FindFirstChild("lip"), 0.58 } } do
			local f = part[1]
			for _, g in f:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
			Render.gradient(f, FKit.vgrad(cols, if part[2] ~= 1 then part[2] else nil), 1)
		end
	end
	for _, st in SETTINGS do
		paint(st)
		ui.on("btn/" .. st.id, function()
			if st.open then WM.open(st.open); return end
			if st.choice then localPrefs[st.id] = (localPrefs[st.id] or 1) % #st.choice + 1
			elseif st.set then st.set(not st.get())
			else
				local cur = if localPrefs[st.id] ~= nil then localPrefs[st.id] else not st.off
				localPrefs[st.id] = not cur
			end
			paint(st)
		end)
	end
	return ui, W, H
end

-- ---------------------------------------------------------------- LEADERBOARDS (sample rows)
local function buildLeaderboards(parent)
	local W, H = 1000, 800
	local L = FKit.layout()
	local win = FKit.WINDOWn(L, "Window / Leaderboards", W, H, "gold", "LEADERBOARDS")
	profileTabs(L, win, "leaderboards")
	local list = add(win, FKit.STEELn(L, "board", 16, 156, W - 32, H - 156 - 56, { cols = { "18202c", "0e131b" } }))
	add(list, FKit.Tn(L, "MOST EGGS EVER", 20, { x = 16, y = 12, w = 400, col = "ffd36b" }))
	for i, r in SampleData.leaderboards do
		local you = r[1] == "you"
		local row = add(list, FKit.WELLn(L, "rank/" .. i, 12, 48 + (i - 1) * 64, W - 32 - 24, 56, { op = if you then 0.35 else 0.7 }))
		local medal = if i <= 3 then ({ PAL.gold, PAL.stone, PAL.amber })[i] else PAL.steel
		add(row, FKit.BTNn(L, "badge/" .. i, 8, 6, 52, 44, medal, tostring(i), { d = 4, size = 18, shadow = false }))
		add(row, FKit.ICOn(if you then "birb" else "egg", 36, 72, 10, L))
		add(row, FKit.Tn(L, if you then Players.LocalPlayer.DisplayName .. " (you)" else r[1], 20, { x = 118, y = 14, w = 500, col = if you then "9dffae" else "ffffff" }))
		add(row, FKit.Tn(L, r[2], 22, { x = W - 32 - 24 - 260, y = 12, w = 240, ax = "R" }))
	end
	add(win, FKit.BODYn(L, "Sample board: live OrderedDataStore boards arrive with the live servers", 14, { x = 0, y = H - 40, w = W, ax = "C", col = "8d94a3" }))
	FKit.OUTLINEn(L, win)
	local ui = FKit.build(L, win, parent)
	for _, k in ui.keys do if string.sub(k.node.n, 1, 6) == "badge/" then k.hit:Destroy() end end
	return ui, W, H
end

-- ---------------------------------------------------------------- FAST TRAVEL
local AREA_ICON = { park = "egg", garden = "seed", castle = "monster", bridge = "rod_simple", forest = "nest", mine = "crow", desert = "egg_golden", expedition = "parrot", echo = "echo" }
local function buildTeleport(parent)
	local areas = {}
	for _, isl in World.list do if AREA_ICON[isl.id] then table.insert(areas, isl) end end
	local W = 1000
	local H = 156 + #areas * 76 + 64
	local L = FKit.layout()
	local win = FKit.WINDOWn(L, "Window / Fast Travel", W, H, "fishing", "FAST TRAVEL")
	add(win, FKit.BODYn(L, "Hop to any open area. Locked areas show what opens them.", 16, { x = 0, y = 96, w = W, ax = "C" }))
	for i, isl in areas do
		local row = add(win, FKit.STEELn(L, "area/" .. isl.id, 16, 136 + (i - 1) * 76, W - 32, 68))
		local w = add(row, FKit.WELLn(L, "icon well", 10, 8, 52, 52))
		add(w, FKit.ICOn(AREA_ICON[isl.id], 44, 4, 4, L))
		add(row, FKit.Tn(L, string.upper(isl.name), 22, { name = "name", x = 78, y = 8, w = 500 }))
		add(row, FKit.BODYn(L, "Open", 14, { name = "status", x = 78, y = 40, w = 600 }))
		add(row, FKit.BTNn(L, "btn/go " .. isl.id, W - 32 - 12 - 170, 8, 170, 54, PAL.green, "GO", { size = 22, glyph = nil }))
	end
	FKit.OUTLINEn(L, win)
	local ui = FKit.build(L, win, parent)
	for _, isl in areas do
		ui.on("btn/go " .. isl.id, function()
			if World.isOpen(isl) then WM.close() end
			Hud.travelTo(isl.id)
		end)
	end
	ui.update = function(s)
		for _, isl in areas do
			local row = ui.find("area/" .. isl.id)
			if row then
				local open = World.isOpen(isl)
				local st = row:FindFirstChild("status", true)
				local goal = "Open"
				if not open then for _, x in Defs.ISLANDS do if x.id == isl.id then goal = "Locked  ·  " .. x.goal end end end
				if st then Render.setText(st, goal); st.TextColor3 = if open then Color3.fromHex("9dffae") else Color3.fromHex("ff9a8a") end
				local key = row:FindFirstChild("btn/go " .. isl.id, true)
				if key then
					local cols = if open then PAL.green else PAL.steel
					for _, part in { { key:FindFirstChild("face"), nil }, { key:FindFirstChild("lip"), 0.58 } } do
						for _, g in part[1]:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
						Render.gradient(part[1], FKit.vgrad(cols, part[2]), 1)
					end
				end
			end
		end
	end
	return ui, W, H
end

-- ---------------------------------------------------------------- OFFLINE (welcome back)
local function buildOffline(parent)
	local W, H = 760, 520
	local SD = SampleData.offline
	local L = FKit.layout()
	local win = FKit.WINDOWn(L, "Window / Welcome back", W, H, "gold", "WELCOME BACK")
	local hero = add(win, FKit.STEELn(L, "hero", 16, 88, W - 32, 120))
	local w = add(hero, FKit.WELLn(L, "icon well", 14, 14, 92, 92))
	add(w, FKit.ICOn("clock", 76, 8, 8, L))
	add(hero, FKit.Tn(L, "You were away " .. SD.hours .. "h", 28, { x = 124, y = 18, w = 560 }))
	add(hero, FKit.BARn(L, "away bar", 124, 66, 560, 26, SD.hours / SD.cap, PAL.gold, SD.hours .. "h / " .. SD.cap .. "h cap"))
	local GAINS = { { "egg", "EGGS", SD.eggs }, { "twig", "TWIGS (Red Panda " .. SD.panda .. ")", SD.twigs } }
	for i, g in ipairs(GAINS) do
		local row = add(win, FKit.WELLn(L, "gain/" .. i, 16, 220 + (i - 1) * 76, W - 32, 66, { op = 0.6 }))
		add(row, FKit.ICOn(g[1], 50, 10, 8, L))
		add(row, FKit.Tn(L, g[2], 20, { x = 74, y = 18, w = 380 }))
		add(row, FKit.Tn(L, "+" .. g[3], 26, { x = W - 32 - 300, y = 14, w = 280, ax = "R", col = "9dffae" }))
	end
	add(win, FKit.BTNn(L, "btn/collect", (W - 300) / 2, H - 140, 300, 84, PAL.green, "COLLECT", { size = 30, icon = "chest" }))
	add(win, FKit.BODYn(L, "Sample numbers: offline earnings are computed by the server when that system lands", 13, { x = 0, y = H - 40, w = W, ax = "C", col = "8d94a3" }))
	FKit.OUTLINEn(L, win)
	local ui = FKit.build(L, win, parent)
	ui.on("btn/collect", function() WM.close() end)
	return ui, W, H
end

local BUILD = { profile = buildProfile, settings = buildSettings, leaderboards = buildLeaderboards, teleport = buildTeleport, offline = buildOffline }
function Screens.build(id, parent, rec)
	local ui, W, H = BUILD[id](parent)
	-- these windows bind themselves: refresh on open and on every state push while visible
	WM.binders[id] = WM.binders[id] or { update = function(_, u, _, s, d) if u.update then u.update(s, d) end end }
	return ui, W, H
end
function Screens.init(hud, wm) Hud, WM = hud, wm end

return Screens
