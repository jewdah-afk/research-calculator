--!nonstrict
-- Client entry: builds the HUD (Figma "Clean Dark Blocky" layout on a 1280x720 canvas),
-- runs the plinko board, and talks to the server through OrbRemotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.OrbConfig)
local F = require(Shared.OrbFormulas)
local Economy = require(Shared.OrbEconomy)
local Big = require(Shared.Big)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Balance = require(Shared.Balance)
local Events = require(Shared.Events)
local Tutorial = require(Shared.Tutorial)
local Prestige = require(Shared.Prestige)

local Kit = require(script.Parent.UI.Kit)
local SkillText = require(script.Parent.UI.SkillText)
local MegaBoardClient = require(script.Parent.World.MegaBoardClient)
local Stands = require(script.Parent.World.Stands)
local RuneAltarUI = require(script.Parent.World.RuneAltarUI)
local Unlocks = require(Shared.Unlocks)
local Runes = require(Shared.Runes)

local C, Fonts = Kit.Colors, Kit.Fonts
local new, text = Kit.new, Kit.text
local R = Remotes.client()
local player = Players.LocalPlayer

local data = nil -- latest deserialized state from the server
local refreshers = {} -- functions run on every state update

local function onState(fn)
	table.insert(refreshers, fn)
end

local function act(name, ...)
	local args = table.pack(...)
	task.spawn(function()
		R.Action:InvokeServer(name, table.unpack(args, 1, args.n))
	end)
end

local fmt, fmtLog = F.format, F.formatLog
local function rarityColor(k)
	local c = Progression.Rarities[k].color
	return Color3.fromRGB(c[1], c[2], c[3])
end

---------------------------------------------------------------- root canvas

local gui = new("ScreenGui", { Name = "OrbHUD", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local canvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, Size = UDim2.fromOffset(1280, 720), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = gui })
local uiScale = new("UIScale", { Parent = canvas })
local function rescale()
	local vp = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(vp.X / 1280, vp.Y / 720)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local M, CX = 16, 640

---------------------------------------------------------------- top bar

local currencyRow = new("Frame", { Name = "Currencies", BackgroundTransparency = 1, Position = UDim2.fromOffset(M, M), Size = UDim2.fromOffset(440, 48), Parent = canvas }, { Kit.list(Enum.FillDirection.Horizontal, 10) })
local function currencyChip(icon, label, c1, order)
	local chip = new("Frame", { Name = label, BackgroundColor3 = C.Panel, BackgroundTransparency = 0.16, Size = UDim2.fromOffset(136, 48), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, Parent = currencyRow }, {
		Kit.corner(6), Kit.stroke(3), Kit.padding(4, 12, 0, 0), Kit.list(Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center),
	})
	Kit.icon(icon, 44, { parent = chip, order = 1 })
	local col = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(80, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = chip }, { Kit.list(Enum.FillDirection.Vertical, -2) })
	text({ text = label, size = 10, color = c1, font = Fonts.Bold, auto = Enum.AutomaticSize.X, dim = UDim2.fromOffset(0, 12), parent = col })
	local v = text({ text = "0", size = 20, font = Fonts.HeavyItalic, outline = 2.5, auto = Enum.AutomaticSize.X, dim = UDim2.fromOffset(0, 24), order = 2, parent = col })
	return chip, v
end
local _, cashValue = currencyChip("cash", "CASH", C.Cash, 1)
local _, gemValue = currencyChip("gem", "GEMS", C.Gem, 2)
local stormChip, stormValue = currencyChip("storm", "STORM", C.Storm, 3)

local income = new("Frame", { Name = "IncomeSlab", BackgroundColor3 = Color3.fromRGB(5, 2, 13), BackgroundTransparency = 0.28, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(CX, M), Size = UDim2.fromOffset(340, 128), Parent = canvas }, {
	Kit.corner(4), Kit.stroke(1.5, C.Cyan, 0.5), Kit.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center), Kit.padding(12, 12, 4, 8),
})
local incomeText = text({ text = "$0/s", size = 42, font = Fonts.HeavyItalic, outline = 3, alignX = Enum.TextXAlignment.Center, gradient = { Color3.fromRGB(27, 108, 122), C.Cyan }, dim = UDim2.new(1, 0, 0, 48), parent = income })
new("Frame", { BackgroundColor3 = C.White, BackgroundTransparency = 0.4, BorderSizePixel = 0, Size = UDim2.new(0.9, 0, 0, 2), LayoutOrder = 1, Parent = income })
local statLuck = text({ text = "", rich = true, size = 14, font = Fonts.HeavyItalic, outline = 2, alignX = Enum.TextXAlignment.Center, order = 2, parent = income })
local statCash = text({ text = "", rich = true, size = 14, font = Fonts.HeavyItalic, outline = 2, alignX = Enum.TextXAlignment.Center, order = 3, parent = income })
local statBonus = text({ text = "", rich = true, size = 14, font = Fonts.HeavyItalic, outline = 2, alignX = Enum.TextXAlignment.Center, order = 4, parent = income })

local settingsBtn = Kit.button({ text = "", color1 = C.Steel, color2 = C.SteelDark, dim = UDim2.fromOffset(48, 48), pos = UDim2.fromOffset(1280 - M - 48, M), parent = canvas })
Kit.icon("gear", 40, { parent = settingsBtn, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), z = 4 })

-- toast stack (right of income, left of settings)
local toastHost = new("Frame", { Name = "Toasts", BackgroundTransparency = 1, Position = UDim2.fromOffset(1280 - M - 48 - 12 - 300, M - 6), Size = UDim2.fromOffset(300, 200), Parent = canvas }, { Kit.list(Enum.FillDirection.Vertical, 6) })
local function toast(title, big, sub, color)
	local t = new("Frame", { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(300, 64), Parent = toastHost }, { Kit.corner(8), Kit.stroke(4) })
	local orb = new("Frame", { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(16, 13), BackgroundColor3 = color or C.Gold, Parent = t }, { Kit.corner(999), Kit.stroke(3) })
	text({ text = title, size = 11, font = Fonts.Bold, color = C.Gold, pos = UDim2.fromOffset(66, 8), dim = UDim2.new(1, -76, 0, 14), parent = t })
	text({ text = big, size = 24, font = Fonts.HeavyItalic, outline = 3, color = color or C.Gold, pos = UDim2.fromOffset(66, 22), dim = UDim2.new(1, -76, 0, 28), parent = t })
	if sub then
		text({ text = sub, size = 12, font = Fonts.HeavyItalic, outline = 2, alignX = Enum.TextXAlignment.Right, pos = UDim2.new(1, -12, 0, 40), anchor = Vector2.new(1, 0), dim = UDim2.fromOffset(120, 16), parent = t })
	end
	orb.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(orb, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(38, 38) }):Play()
	task.delay(4, function()
		t:Destroy()
	end)
end

---------------------------------------------------------------- columns

local COL_TOP = M + 128 + 16
local DOCK_H = 76
local COL_H = 720 - M - DOCK_H - 16 - COL_TOP
local PW = 360

---------------------------------------------------------------- left: upgrades panel

local upgradesPanel, upBody = Kit.panel({ name = "UpgradesPanel", title = "UPGRADES", color1 = C.Pink, color2 = C.Purple, dim = UDim2.fromOffset(PW, COL_H), pos = UDim2.fromOffset(M, COL_TOP), parent = canvas })
local tabRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = upBody }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
local pages = {}
local tabButtons = {}
local function showTab(name)
	for n, p in pages do
		p.Visible = n == name
	end
	for n, b in tabButtons do
		if n == name then
			Kit.setButtonColors(b, C.Pink, C.RedDark)
		else
			Kit.setButtonColors(b, C.Tab, C.TabDark)
		end
	end
end
for i, name in { "MAIN", "SPAWNERS", "GEMS" } do
	tabButtons[name] = Kit.button({ text = name, size = 13, dim = UDim2.new(1 / 3, -4, 1, 0), order = i, parent = tabRow, onClick = function()
		showTab(name)
	end })
	pages[name] = Kit.scroll({ name = name, dim = UDim2.new(1, 0, 1, -38), pos = UDim2.fromOffset(0, 38), parent = upBody })
end

-- generic upgrade card: icon | title + level + effect + bar | buy button
local function upgradeCard(parent, icon, title, order, onBuy)
	local card = Kit.card({ name = title, dim = UDim2.new(1, -6, 0, 62), order = order, parent = parent })
	local ic = new("Frame", { BackgroundColor3 = Color3.fromRGB(20, 15, 33), Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(8, 8), Parent = card }, { Kit.corner(6), Kit.stroke(2.5) })
	Kit.icon(icon, 58, { parent = ic, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), z = 3 })
	local t = text({ text = title, size = 15, outline = 2, pos = UDim2.fromOffset(62, 6), dim = UDim2.new(1, -160, 0, 18), parent = card })
	local lvl = text({ text = "", size = 10, font = Fonts.Bold, color = C.Cash, pos = UDim2.fromOffset(62, 6), dim = UDim2.new(1, -160, 0, 18), alignX = Enum.TextXAlignment.Right, parent = card })
	local eff = text({ text = "", rich = true, size = 13, font = Fonts.HeavyItalic, pos = UDim2.fromOffset(62, 24), dim = UDim2.new(1, -160, 0, 16), parent = card })
	local barFrame, setBar = Kit.bar({ dim = UDim2.new(1, -160, 0, 9), parent = card })
	barFrame.Position = UDim2.fromOffset(62, 44)
	local btn = Kit.button({ text = "$0", size = 14, dim = UDim2.fromOffset(86, 34), anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -8, 0.5, 0), parent = card, onClick = onBuy })
	return { card = card, title = t, level = lvl, effect = eff, setBar = setBar, button = btn }
end

-- MAIN tab
local mainCards = {
	upgradeCard(pages.MAIN, "cash", "CASH BOOST", 1, function()
		act("buyMain", 1)
	end),
	upgradeCard(pages.MAIN, "clover", "LUCKY ORB", 2, function()
		act("buyMain", 2)
	end),
	upgradeCard(pages.MAIN, "gem", "GEM DRILL", 3, function()
		act("buyMain", 3)
	end),
}
local mainMax = Kit.button({ text = "BUY MAX", size = 16, color1 = C.Gold, color2 = C.GoldDark, dim = UDim2.new(1, -6, 0, 36), order = 10, parent = pages.MAIN, onClick = function()
	act("maxBuyMain")
end })
local allMax = Kit.button({ text = "BUY EVERYTHING", size = 16, color1 = C.Cyan, color2 = C.GemDark, dim = UDim2.new(1, -6, 0, 36), order = 11, parent = pages.MAIN, onClick = function()
	act("maxBuyAll")
end })

local function effectText(cur, nxt, color)
	return string.format('<font color="#7d7696">%s</font> <font color="%s">▶ %s</font>', cur, color, nxt)
end

onState(function(d)
	local lv = d.mainLevels
	local mm = F.orbMoneyMult(d)
	local c1 = mainCards[1]
	c1.level.Text = "LV " .. lv[1]
	c1.effect.Text = effectText("x" .. fmt(d.moneyMultiplier, 2), "x" .. fmt(Big.mul(d.moneyMultiplier, Config.Main.Money.effect), 2), "#7cff5b")
	c1.setBar((lv[1] % 10) / 10)
	local cost1 = Economy.mainUpgradeCost(d, 1)
	Kit.setLabel(c1.button, "$" .. fmt(cost1))
	Kit.setAffordable(c1.button, Big.gte(d.money, cost1))

	local c2 = mainCards[2]
	local luckNow = d.mainLevels[2] * math.log10(Config.Main.Luck.effect)
	c2.level.Text = "LV " .. lv[2]
	c2.effect.Text = effectText("x" .. fmtLog(luckNow, 2), "x" .. fmtLog(luckNow + math.log10(Config.Main.Luck.effect), 2), "#ffe14a")
	c2.setBar((lv[2] % 10) / 10)
	local cost2 = Economy.mainUpgradeCost(d, 2)
	Kit.setLabel(c2.button, "$" .. fmt(cost2))
	Kit.setAffordable(c2.button, Big.gte(d.money, cost2))

	local c3 = mainCards[3]
	local dc = F.diamondChance(d)
	c3.level.Text = "LV " .. lv[3]
	local capped = dc >= F.DIAMOND_CHANCE_CAP
	c3.effect.Text = capped and '<font color="#5cf2ff">MAXED 25%</font>' or effectText(string.format("%.1f%%", dc * 100), string.format("%.1f%%", (dc + Config.Main.Diamond.effect) * 100), "#5cf2ff")
	c3.setBar(dc / F.DIAMOND_CHANCE_CAP)
	local cost3 = Economy.mainUpgradeCost(d, 3)
	Kit.setLabel(c3.button, capped and "MAX" or "$" .. fmt(cost3))
	Kit.setAffordable(c3.button, not capped and Big.gte(d.money, cost3))

	mainMax.Visible = F.skill(d, "MAX-1") >= 1
	allMax.Visible = F.skill(d, "MAX-4") >= 1
	local _ = mm
end)

-- SPAWNERS tab
local spawnerRows = {}
for s = 1, 7 do
	local card = Kit.card({ name = "Spawner" .. s, dim = UDim2.new(1, -6, 0, 96), order = s, parent = pages.SPAWNERS })
	local title = text({ text = "SPAWNER " .. s, size = 15, outline = 2, pos = UDim2.fromOffset(10, 6), dim = UDim2.new(1, -20, 0, 18), parent = card })
	local info = text({ text = "", rich = true, size = 12, font = Fonts.HeavyItalic, pos = UDim2.fromOffset(10, 24), dim = UDim2.new(1, -20, 0, 16), parent = card })
	local speed = Kit.button({ text = "", size = 12, dim = UDim2.new(0.5, -14, 0, 40), pos = UDim2.fromOffset(10, 46), parent = card, onClick = function()
		act("buyInterval", s)
	end })
	local luck = Kit.button({ text = "", size = 12, dim = UDim2.new(0.5, -14, 0, 40), pos = UDim2.new(0.5, 4, 0, 46), parent = card, onClick = function()
		act("buySpawnerLuck", s)
	end })
	local unlock = Kit.button({ text = "", size = 15, color1 = C.Gold, color2 = C.GoldDark, dim = UDim2.new(1, -20, 0, 40), pos = UDim2.fromOffset(10, 46), parent = card, onClick = function()
		act("buySpawner", s)
	end })
	local maxBtn = Kit.button({ text = "MAX", size = 11, color1 = C.Gold, color2 = C.GoldDark, dim = UDim2.fromOffset(52, 20), anchor = Vector2.new(1, 0), pos = UDim2.new(1, -8, 0, 6), parent = card, onClick = function()
		act("maxBuySpawner", s)
	end })
	spawnerRows[s] = { card = card, title = title, info = info, speed = speed, luck = luck, unlock = unlock, max = maxBtn }
end
onState(function(d)
	for s, row in spawnerRows do
		local unlocked = s <= d.spawnersUnlocked
		local nextUp = s == d.spawnersUnlocked + 1
		row.card.Visible = unlocked or nextUp
		row.speed.Visible, row.luck.Visible = unlocked, unlocked
		row.max.Visible = unlocked and F.skill(d, "MAX-2") >= 1
		row.unlock.Visible = nextUp
		if unlocked then
			row.info.Text = string.format('<font color="#7d7696">every</font> <font color="#5cf2ff">%.2fs</font>  <font color="#7d7696">luck</font> <font color="#ffe14a">x%s</font>', d.spawnIntervals[s] / 1000, fmtLog(F.spawnerLuckLog(d, s), 2))
			local atMin = d.spawnIntervals[s] <= Config.Spawners.MinInterval
			local ic = Economy.intervalCost(d, s)
			Kit.setLabel(row.speed, atMin and "SPEED MAXED" or "SPEED  $" .. fmt(ic))
			Kit.setAffordable(row.speed, not atMin and Big.gte(d.money, ic))
			local lc = Economy.spawnerLuckCost(d, s)
			Kit.setLabel(row.luck, "LUCK  $" .. fmt(lc))
			Kit.setAffordable(row.luck, Big.gte(d.money, lc))
		elseif nextUp then
			local cost = Config.Spawners.UnlockCost[s]
			if cost then
				row.info.Text = '<font color="#7d7696">locked</font>'
				Kit.setLabel(row.unlock, "UNLOCK  $" .. fmt(cost))
				row.unlock.Active = true
			else
				row.info.Text = '<font color="#7d7696">unlocks from the Skill Tree (Expansion)</font>'
				Kit.setLabel(row.unlock, "SKILL TREE")
			end
		end
	end
end)

-- GEMS tab: mechanic unlocks, gem luck, boosts
local mechCard = Kit.card({ name = "Mechanic", dim = UDim2.new(1, -6, 0, 70), order = 1, parent = pages.GEMS })
local mechTitle = text({ text = "", size = 15, outline = 2, pos = UDim2.fromOffset(10, 6), dim = UDim2.new(1, -120, 0, 18), parent = mechCard })
local mechInfo = text({ text = "", size = 12, font = Fonts.Bold, color = C.Sub, pos = UDim2.fromOffset(10, 26), dim = UDim2.new(1, -120, 0, 36), wrap = true, parent = mechCard })
local mechBtn = Kit.button({ text = "", size = 14, dim = UDim2.fromOffset(96, 40), anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -8, 0.5, 0), parent = mechCard, onClick = function()
	act("unlockMechanic")
end })
local MECH_TEXT = {
	"Rebirth: reset cash for permanent x2 luck per rebirth.",
	"Boosts: spend gems on timed potions.",
	"Rarity Bonus: x1.06 money per rarity discovered.",
	"Tiers: big resets with new boards, perks and skill points.",
	"Weather: storm orbs, weather rolls and their boosts.",
}
local gemLuck = upgradeCard(pages.GEMS, "clover", "GEM LUCK", 2, function()
	act("buyDiamondLuck")
end)

local boostRows = {}
local BOOST_NAMES = { "2x CASH · 1m", "2x CASH · 5m", "2x LUCK · 1m", "2x LUCK · 5m", "DUPLICATE ORBS", "CLEAR PATH" }
local BOOST_ICONS = { "cash", "cash", "clover", "clover", "spawn", "fastdrop" }
for id = 1, 6 do
	local card = Kit.card({ name = "Boost" .. id, dim = UDim2.new(1, -6, 0, 48), order = 10 + id, parent = pages.GEMS })
	Kit.icon(BOOST_ICONS[id], 40, { parent = card, pos = UDim2.fromOffset(6, 4) })
	local t = text({ text = BOOST_NAMES[id], size = 14, outline = 2, pos = UDim2.fromOffset(52, 4), dim = UDim2.new(1, -160, 0, 18), parent = card })
	local timer = text({ text = "", size = 12, font = Fonts.HeavyItalic, color = C.Cash, pos = UDim2.fromOffset(52, 24), dim = UDim2.new(1, -160, 0, 16), parent = card })
	local b = Kit.button({ text = "", size = 13, dim = UDim2.fromOffset(92, 34), anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -8, 0.5, 0), parent = card, onClick = function()
		act("buyBoost", id)
	end })
	boostRows[id] = { card = card, title = t, timer = timer, button = b }
end
local potionRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 32), LayoutOrder = 30, Parent = pages.GEMS }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
local potionBtns = {}
for i, which in { "money", "luck" } do
	potionBtns[which] = Kit.button({ text = "", size = 12, dim = UDim2.new(0.5, -3, 1, 0), order = i, parent = potionRow, onClick = function()
		act("setAutoPotion", which, not (data and data.autoPotion[which]))
	end })
end

local function clock(sec)
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

onState(function(d)
	local m = Config.Mechanics[d.mechanics + 1]
	mechCard.Visible = m ~= nil
	if m then
		mechTitle.Text = "UNLOCK " .. string.upper(m.name)
		local req = {}
		if m.minRebirths then
			table.insert(req, "needs " .. m.minRebirths .. " rebirths")
		end
		if m.minTiers then
			table.insert(req, "needs tier " .. m.minTiers)
		end
		mechInfo.Text = MECH_TEXT[d.mechanics + 1] .. (#req > 0 and (" (" .. table.concat(req, ", ") .. ")") or "")
		Kit.setLabel(mechBtn, fmt(m.cost) .. " GEMS")
		Kit.setAffordable(mechBtn, Big.gte(d.diamonds, m.cost) and (not m.minRebirths or d.rebirths >= m.minRebirths) and (not m.minTiers or d.tiers >= m.minTiers))
	end
	gemLuck.level.Text = "x" .. fmtLog(d.diamondLuckLog, 2)
	gemLuck.effect.Text = effectText("x" .. fmtLog(d.diamondLuckLog, 2), "x" .. fmtLog(d.diamondLuckLog + math.log10(1.1), 2), "#ffe14a") .. ' <font color="#7d7696">(kept on tier)</font>'
	Kit.setLabel(gemLuck.button, fmt(d.diamondLuckCost) .. " ◆")
	Kit.setAffordable(gemLuck.button, Big.gte(d.diamonds, d.diamondLuckCost))
	local b = d.boostTimes
	for id, row in boostRows do
		local visible = d.mechanics >= 2 and (id ~= 6 or F.skill(d, "BST-3") >= 1)
		row.card.Visible = visible
		if visible then
			local cost = F.boostCost(d, id)
			Kit.setLabel(row.button, cost .. " ◆")
			local blocked = (id == 5 and b.duplicate > 0) or (id == 6 and b.obstacle > 0)
			Kit.setAffordable(row.button, not blocked and Big.gte(d.diamonds, cost))
			if id <= 2 then
				row.timer.Text = b.money > 0 and ("active " .. clock(b.money)) or ""
			elseif id <= 4 then
				row.timer.Text = b.luck > 0 and ("active " .. clock(b.luck)) or ""
			elseif id == 5 then
				row.timer.Text = b.duplicate > 0 and ("cooldown " .. clock(b.duplicate)) or "ready"
			else
				row.timer.Text = b.obstacle > Config.Boosts[6].downtime and ("active " .. clock(b.obstacle - Config.Boosts[6].downtime)) or (b.obstacle > 0 and "cooldown" or "ready")
			end
		end
	end
	potionRow.Visible = F.skill(d, "BST-4") >= 1
	for which, btn in potionBtns do
		local on = d.autoPotion[which]
		Kit.setLabel(btn, "AUTO " .. string.upper(which) .. (on and " ON" or " OFF"))
		Kit.setButtonColors(btn, on and C.Cash or C.Tab, on and C.CashDark or C.TabDark)
	end
end)
showTab("MAIN")

---------------------------------------------------------------- right: rarities

local rarityPanel, rBody = Kit.panel({ name = "RarityPanel", title = "RARITIES", color1 = Color3.fromRGB(43, 47, 85), color2 = Color3.fromRGB(27, 30, 58), dim = UDim2.fromOffset(PW, COL_H), pos = UDim2.fromOffset(1280 - M - PW, COL_TOP), parent = canvas })
local discovered = text({ text = "", rich = true, size = 12, font = Fonts.Bold, color = C.Sub, dim = UDim2.new(1, 0, 0, 16), parent = rBody })
local rarityList = Kit.scroll({ name = "List", dim = UDim2.new(1, 0, 1, -86), pos = UDim2.fromOffset(0, 20), gap = 2, parent = rBody })
local bestStrip = new("Frame", { BackgroundColor3 = C.White, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 1, -56), Parent = rBody }, {
	Kit.corner(5), Kit.stroke(2.5), Kit.gradient(Color3.fromRGB(42, 27, 68), Color3.fromRGB(26, 17, 41)),
})
text({ text = "BEST", size = 10, font = Fonts.Bold, color = C.Sub, pos = UDim2.fromOffset(12, 8), dim = UDim2.fromOffset(100, 12), parent = bestStrip })
local bestText = text({ text = "", size = 17, font = Fonts.HeavyItalic, outline = 2, color = C.GoldDark, pos = UDim2.fromOffset(12, 22), dim = UDim2.new(0.6, -12, 0, 22), parent = bestStrip })
text({ text = "LUCK", size = 10, font = Fonts.Bold, color = C.Sub, pos = UDim2.new(0.6, 0, 0, 8), dim = UDim2.fromOffset(100, 12), parent = bestStrip })
local luckText = text({ text = "", size = 17, font = Fonts.HeavyItalic, outline = 2, color = C.Cyan, pos = UDim2.new(0.6, 0, 0, 22), dim = UDim2.new(0.4, -12, 0, 22), parent = bestStrip })

local rarityRows = {}
local function rarityRow(k)
	local row = new("Frame", { Name = "R" .. k, BackgroundColor3 = C.White, BackgroundTransparency = k % 2 == 0 and 0.97 or 1, Size = UDim2.new(1, -6, 0, 24), LayoutOrder = k, Parent = rarityList }, { Kit.corner(4) })
	local dot = new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(6, 5), BackgroundColor3 = rarityColor(k), Parent = row }, { Kit.corner(3), Kit.stroke(2) })
	local name = text({ text = "", size = 14, outline = 2, pos = UDim2.fromOffset(28, 0), dim = UDim2.new(1, -130, 1, 0), parent = row })
	local odds = text({ text = "", size = 13, font = Fonts.HeavyItalic, alignX = Enum.TextXAlignment.Right, pos = UDim2.new(1, -8, 0, 0), anchor = Vector2.new(1, 0), dim = UDim2.fromOffset(100, 24), parent = row })
	rarityRows[k] = { row = row, dot = dot, name = name, odds = odds }
	return rarityRows[k]
end
onState(function(d)
	local show = math.min(math.max(d.highestRarity + 3, 10), #Progression.Rarities)
	local luck = d.totalLuckLog + F.spawnerLuckLog(d, 1)
	local found = 0
	for k = 1, show do
		local r = rarityRows[k] or rarityRow(k)
		local got = (d.orbsObtained[k] or 0) > 0
		if got then
			found += 1
		end
		local c = rarityColor(k)
		r.name.Text = got and string.upper(Progression.Rarities[k].name) or "???"
		r.name.TextColor3 = got and c or C.Dim
		r.dot.BackgroundColor3 = got and c or Color3.fromRGB(42, 37, 56)
		r.odds.Text = "1/" .. fmtLog(F.oneInLog(luck, k), 1)
		r.odds.TextColor3 = got and c or C.Dim
	end
	for k, r in rarityRows do
		r.row.Visible = k <= show
	end
	discovered.Text = string.format('DISCOVERED <font color="#5cf2ff">%d/%d</font>', found, #Progression.Rarities)
	bestText.Text = d.highestRarity > 0 and string.upper(Progression.Rarities[d.highestRarity].name) or "-"
	bestText.TextColor3 = d.highestRarity > 0 and rarityColor(d.highestRarity) or C.Sub
	luckText.Text = "x" .. fmtLog(d.totalLuckLog, 2)
end)

---------------------------------------------------------------- board

local BOARD_W = 1280 - 2 * (M + PW) - 2 * 64
local boardFrame = new("Frame", { Name = "Board", BackgroundColor3 = C.Panel, BackgroundTransparency = 0.16, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(CX, COL_TOP), Size = UDim2.fromOffset(BOARD_W, COL_H), Parent = canvas }, {
	Kit.corner(8), Kit.stroke(4),
})
local playArea = new("Frame", { Name = "PlayAreaHolder", BackgroundColor3 = C.White, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), ClipsDescendants = true, Parent = boardFrame }, {
	Kit.corner(4), Kit.gradient(Color3.fromRGB(34, 18, 74), Color3.fromRGB(18, 11, 36)),
})
-- the board now lives in the world (shared Mega Board); this GUI frame only holds the orb counter
boardFrame.BackgroundTransparency = 1
playArea.Visible = false
boardFrame.Size = UDim2.fromOffset(BOARD_W, 40)
local board = MegaBoardClient.new(workspace:WaitForChild("OrbWorld"))
local capLabel = text({ text = "", rich = true, size = 12, font = Fonts.HeavyItalic, outline = 1.5, alignX = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 0), pos = UDim2.new(1, -14, 0, 12), dim = UDim2.fromOffset(160, 16), parent = boardFrame })
capLabel.ZIndex = 10

-- floating "+$" popups over the slot your orb landed in
local function popup(x, msg, color)
	board:popup(x, msg, color)
end

local collectQueue = {}
board.onCollect = function(id, x, orb)
	table.insert(collectQueue, { id, x })
	if data then
		local slot = F.slotMult(data.tiers, x)
		if orb.kind == "orb" then
			popup(x, "+$" .. fmt(F.orbMoney(data, orb.rarity, slot, orb.variant)), C.Cash)
		elseif orb.kind == "diamond" then
			popup(x, "+" .. fmt(F.diamondGain(data, slot, orb.variant), 1) .. "◆", C.Gem)
		else
			popup(x, "+" .. F.variantMult(orb.variant) .. "ϟ", C.Storm)
		end
	end
end
task.spawn(function()
	while true do
		task.wait(0.1)
		if #collectQueue > 0 then
			local batch = collectQueue
			collectQueue = {}
			R.Collect:FireServer(batch)
		end
	end
end)

local function rebuildBoard()
	if data then
		board:setLayout(data.tiers)
	end
end

-- other players' orbs (visual only, never collide with yours)
R.Ghost.OnClientEvent:Connect(function(userId, name, list)
	if userId ~= player.UserId and type(list) == "table" then
		board:ghosts(tostring(name), list)
	end
end)

R.Spawn.OnClientEvent:Connect(function(list)
	if data then
		board:spawn(list, data)
	end
end)
R.Board.OnClientEvent:Connect(function(kind, payload)
	if kind == "clear" then
		board:clear()
	elseif kind == "rebuild" then
		rebuildBoard()
	elseif kind == "duplicate" and data then
		board:duplicate(payload, data)
	end
end)
onState(function(d)
	capLabel.Text = string.format('<font color="#7d7696">ORBS</font> <font color="#5cf2ff">%d / %d</font>', board.count, F.spawnCap(d))
end)

---------------------------------------------------------------- modals

local modalLayer = new("Frame", { Name = "Modals", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = canvas })
local dim = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.Black, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50, Parent = modalLayer })
local modals = {}
local function openModal(name)
	for n, m in modals do
		m.Visible = n == name
	end
	dim.Visible = name ~= nil
end
dim.Activated:Connect(function()
	openModal(nil)
end)
local function modal(name, title, c1, c2)
	local p, body = Kit.panel({ name = name, title = title, color1 = c1, color2 = c2, dim = UDim2.fromOffset(700, 470), anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), z = 51, parent = modalLayer, onClose = function()
		openModal(nil)
	end })
	p.Visible = false
	modals[name] = p
	return body
end

-- STORM (weather)
local stormBody = modal("Storm", "STORM", C.StormDark, C.Purple)
local stormLocked = text({ text = "Unlock Weather in the GEMS tab (needs Tier 2).", size = 16, outline = 2, color = C.Sub, alignX = Enum.TextXAlignment.Center, dim = UDim2.fromScale(1, 1), parent = stormBody })
local stormContent = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = stormBody })
local weatherList = Kit.scroll({ dim = UDim2.new(0.58, 0, 1, 0), gap = 4, parent = stormContent })
local weatherRows = {}
for i, w in Config.Weather do
	local row = Kit.card({ dim = UDim2.new(1, -6, 0, 44), order = i, parent = weatherList })
	local n = text({ text = string.upper(w.name), size = 14, outline = 2, pos = UDim2.fromOffset(10, 4), dim = UDim2.new(1, -20, 0, 18), parent = row })
	local info = text({ text = "", rich = true, size = 11, font = Fonts.Bold, color = C.Sub, pos = UDim2.fromOffset(10, 22), dim = UDim2.new(1, -20, 0, 16), parent = row })
	weatherRows[i] = { row = row, name = n, info = info }
end
local stormSide = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), Parent = stormContent }, { Kit.list(Enum.FillDirection.Vertical, 8) })
local stormPts = text({ text = "", size = 22, font = Fonts.HeavyItalic, outline = 3, color = C.Storm, order = 1, parent = stormSide })
local stormMult = text({ text = "", rich = true, size = 13, font = Fonts.HeavyItalic, wrap = true, dim = UDim2.new(1, 0, 0, 52), order = 2, parent = stormSide })
local rollBtn = Kit.button({ text = "", size = 15, color1 = C.Storm, color2 = C.StormDark, dim = UDim2.new(1, 0, 0, 44), order = 3, parent = stormSide, onClick = function()
	act("rollWeather")
end })
local unlockWBtn = Kit.button({ text = "", size = 13, dim = UDim2.new(1, 0, 0, 38), order = 4, parent = stormSide, onClick = function()
	act("unlockWeather")
end })
local wMoneyBtn = Kit.button({ text = "", size = 13, dim = UDim2.new(1, 0, 0, 38), order = 5, parent = stormSide, onClick = function()
	act("buyWeatherMoney")
end })
local stormLvlBtn = Kit.button({ text = "", size = 13, color1 = C.Storm, color2 = C.StormDark, dim = UDim2.new(1, 0, 0, 38), order = 6, parent = stormSide, onClick = function()
	act("buyStormLevel")
end })
onState(function(d)
	if d.mechanics < 5 then
		return
	end
	local cost = Economy.stormLevelCost(d)
	Kit.setLabel(stormLvlBtn, string.format("STORM LV %d  %s ϟ", d.stormLevel + 1, fmt(cost)))
	Kit.setAffordable(stormLvlBtn, d.weatherPoints >= cost)
end)
onState(function(d)
	local unlocked = d.mechanics >= 5
	stormLocked.Visible = not unlocked
	stormContent.Visible = unlocked
	stormChip.Visible = unlocked
	if not unlocked then
		return
	end
	local odds = Config.WeatherOdds[d.weatherUnlocked]
	for i, row in weatherRows do
		local w = Config.Weather[i]
		local open = i <= d.weatherUnlocked
		row.name.Text = open and string.upper(w.name) or "???"
		local fx = {}
		if w.luck > 0 then table.insert(fx, '<font color="#9bff3d">+' .. w.luck .. "x luck</font>") end
		if w.money > 0 then table.insert(fx, '<font color="#7cff5b">+' .. w.money .. "x cash</font>") end
		if w.diamonds > 0 then table.insert(fx, '<font color="#5cf2ff">+' .. w.diamonds .. "x gems</font>") end
		local active = d.weatherDuration[i] > 0 and ('  <font color="#ffe14a">' .. clock(d.weatherDuration[i]) .. "</font>") or ""
		row.info.Text = open and (string.format("%.2f%%  ", (odds[i] or 0) * 100) .. table.concat(fx, " ") .. active) or "locked"
	end
	stormPts.Text = d.weatherPoints .. " ϟ"
	local wl, wm, wd = F.weatherMults(d)
	stormMult.Text = string.format('<font color="#9bff3d">x%.2f luck</font>  <font color="#7cff5b">x%.2f cash</font>  <font color="#5cf2ff">x%.2f gems</font>', wl, wm, wd)
	local price = F.weatherRollPrice(d)
	Kit.setLabel(rollBtn, d.weatherRollCooldown > 0 and ("ROLL  (" .. d.weatherRollCooldown .. "s)") or ("ROLL  " .. price .. " ϟ"))
	local maxed = d.weatherUnlocked >= Config.WeatherShop.MaxUnlockable
	Kit.setLabel(unlockWBtn, maxed and "ALL WEATHER UNLOCKED" or ("NEW WEATHER  " .. d.weatherCosts.unlock .. " ϟ"))
	Kit.setAffordable(unlockWBtn, not maxed and d.weatherPoints >= d.weatherCosts.unlock)
	Kit.setLabel(wMoneyBtn, string.format("x%.2f CASH  %d ϟ", d.weatherMoney * 1.1, d.weatherCosts.money))
	Kit.setAffordable(wMoneyBtn, d.weatherPoints >= d.weatherCosts.money)
end)

-- SKILLS
local skillBody = modal("Skills", "SKILL TREE", C.Cash, C.CashDark)
local skillHeader = text({ text = "", rich = true, size = 16, font = Fonts.HeavyItalic, outline = 2, dim = UDim2.new(1, 0, 0, 20), parent = skillBody })
local skillLocked = text({ text = "Reach Tier 1 to open the Skill Tree.", size = 16, outline = 2, color = C.Sub, alignX = Enum.TextXAlignment.Center, dim = UDim2.fromScale(1, 1), parent = skillBody })
local skillGrid = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -110), Parent = skillBody }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
local skillButtons = {}
local CAT_ORDER = { "main", "spawner", "boost", "max", "rless" }
local CAT_TITLE = { main = "MULTIPLIERS", spawner = "SPAWNERS", boost = "BOOSTS", max = "MAX BUY (QP)", rless = "KEEP (QP)" }
for ci, cat in CAT_ORDER do
	local col = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.2, -5, 1, 0), LayoutOrder = ci, Parent = skillGrid }, { Kit.list(Enum.FillDirection.Vertical, 5) })
	text({ text = CAT_TITLE[cat], size = 12, font = Fonts.Bold, color = C.Sub, alignX = Enum.TextXAlignment.Center, parent = col })
	for idx, upg in Config.SkillTree[cat].upgrades do
		local info = SkillText[upg.id] or { upg.id, "" }
		local card = new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = C.White, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = idx + 1, Parent = col }, {
			Kit.corner(5), Kit.stroke(2.5), Kit.gradient(C.Card, C.CardDark),
		})
		local nm = text({ text = info[1], size = 12, outline = 1.5, pos = UDim2.fromOffset(6, 3), dim = UDim2.new(1, -12, 0, 14), parent = card })
		local lv = text({ text = "", size = 11, font = Fonts.HeavyItalic, color = C.Gold, pos = UDim2.fromOffset(6, 18), dim = UDim2.new(1, -12, 0, 13), parent = card })
		local cost = text({ text = "", size = 11, font = Fonts.Bold, color = C.Sub, pos = UDim2.fromOffset(6, 33), dim = UDim2.new(1, -12, 0, 13), parent = card })
		card.Activated:Connect(function()
			act("buySkill", upg.id)
		end)
		local tip = info[2]
		card.MouseEnter:Connect(function()
			skillHeader.Text = '<font color="#ffe14a">' .. info[1] .. "</font>  " .. tip
		end)
		skillButtons[upg.id] = { card = card, level = lv, cost = cost, upg = upg, cat = cat }
	end
end
local skillFooter = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -76), Size = UDim2.new(1, 0, 0, 76), Parent = skillBody }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
local tpButtons = {}
for i, src in { "Money", "Diamonds", "WeatherRolls", "OrbsSpawned" } do
	tpButtons[src] = Kit.button({ text = "", size = 11, color1 = C.Cyan, color2 = C.GemDark, dim = UDim2.new(1 / 6, -5, 0, 70), order = i, parent = skillFooter, onClick = function()
		act("gainTP", src)
	end })
	tpButtons[src].Label.TextWrapped = true
end
local qpBtn = Kit.button({ text = "", size = 11, color1 = C.Storm, color2 = C.StormDark, dim = UDim2.new(1 / 6, -5, 0, 70), order = 5, parent = skillFooter, onClick = function()
	act("gainQP")
end })
qpBtn.Label.TextWrapped = true
local respecBtn = Kit.button({ text = "RESPEC\n-2 rebirths", size = 11, color1 = C.Red, color2 = C.RedDark, dim = UDim2.new(1 / 6, -5, 0, 70), order = 6, parent = skillFooter, onClick = function()
	act("respec")
end })
respecBtn.Label.TextWrapped = true
local TP_LABEL = { Money = "TP for $%s", Diamonds = "TP for %s ◆", WeatherRolls = "TP at %s rolls", OrbsSpawned = "TP at %s orbs" }
onState(function(d)
	local open = d.tiers >= 1
	skillLocked.Visible = not open
	skillGrid.Visible, skillFooter.Visible = open, open
	if not open then
		skillHeader.Text = ""
		return
	end
	local pts = Economy.points(d)
	if skillHeader.Text == "" or skillHeader.Text:find("TP ") then
		skillHeader.Text = string.format('<font color="#5cf2ff">%d / %d TP</font>   <font color="#e3a6ff">%d / %d QP</font>', pts.tp, pts.maxTP, pts.qp, pts.maxQP)
	end
	for id, b in skillButtons do
		local lvl = d.skills[b.cat][table.find(Config.SkillTree[b.cat].upgrades, b.upg)]
		local maxL = F.skillMaxLevel(b.upg)
		b.level.Text = maxL == math.huge and ("LV " .. lvl) or (lvl .. "/" .. maxL)
		local locked = b.upg.tier4 and d.tiers < 4
		local cur = Config.SkillTree[b.cat].currency
		b.cost.Text = locked and "TIER 4" or (lvl >= maxL and "MAXED" or (F.skillCost(b.upg, lvl) .. " " .. cur))
		local reqOk = true
		for _, req in b.upg.req or {} do
			reqOk = reqOk and F.skill(d, req) >= 1
		end
		b.card.BackgroundTransparency = (locked or not reqOk) and 0.5 or 0
	end
	for src, btn in tpButtons do
		local s = Config.TPSources[src]
		local gated = s.unlockMaxTP and F.maxTP(d) < s.unlockMaxTP
		local cost = F.tpSourceCost(src, d.tpBought[src])
		Kit.setLabel(btn, gated and ("needs " .. s.unlockMaxTP .. " max TP") or string.format(TP_LABEL[src], fmt(cost)))
	end
	local q = Config.QPSources.HighestRarity
	local need = q.baseCost + q.step * d.qpBought
	Kit.setLabel(qpBtn, "QP at rarity #" .. need)
end)

-- TIER (+ automation)
local tierBody = modal("Tier", "TIER UP", C.Pink, C.RedDark)
local tierInfo = text({ text = "", rich = true, size = 18, font = Fonts.HeavyItalic, outline = 2, wrap = true, dim = UDim2.new(1, 0, 0, 70), parent = tierBody })
local tierBarFrame, setTierBar = Kit.bar({ dim = UDim2.new(1, 0, 0, 16), parent = tierBody, color1 = C.Pink, color2 = C.RedDark })
tierBarFrame.Position = UDim2.fromOffset(0, 76)
local tierPerks = text({ text = "", rich = true, size = 13, font = Fonts.Bold, color = C.Sub, wrap = true, pos = UDim2.fromOffset(0, 100), dim = UDim2.new(1, 0, 0, 60), parent = tierBody })
local tierBtn = Kit.button({ text = "TIER UP", size = 20, color1 = C.Pink, color2 = C.RedDark, dim = UDim2.new(1, 0, 0, 46), pos = UDim2.fromOffset(0, 162), parent = tierBody, onClick = function()
	act("tier")
end })
local autoTitle = text({ text = "AUTOMATION", size = 16, outline = 2, pos = UDim2.fromOffset(0, 220), parent = tierBody })
local autoRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 244), Size = UDim2.new(1, 0, 0, 120), Parent = tierBody }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
local AUTO_NAMES = { "AUTO MAIN", "AUTO SPAWNERS", "SMART MAIN", "SMART SPAWNERS" }
local autoButtons, autoToggles = {}, {}
for i = 1, 4 do
	local col = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.25, -5, 1, 0), LayoutOrder = i, Parent = autoRow }, { Kit.list(Enum.FillDirection.Vertical, 4) })
	autoButtons[i] = Kit.button({ text = "", size = 11, color1 = C.Cyan, color2 = C.GemDark, dim = UDim2.new(1, 0, 0, 60), order = 1, parent = col, onClick = function()
		act("buyAutomation", i)
	end })
	autoButtons[i].Label.TextWrapped = true
	if i <= 2 then
		autoToggles[i] = Kit.button({ text = "", size = 11, dim = UDim2.new(1, 0, 0, 26), order = 2, parent = col, onClick = function()
			act("toggleAutomation", i)
		end })
	end
end
local autoPts = text({ text = "", size = 12, font = Fonts.Bold, color = C.Sub, pos = UDim2.fromOffset(160, 222), dim = UDim2.new(1, -160, 0, 16), parent = tierBody })
onState(function(d)
	if d.mechanics < 4 then
		tierInfo.Text = "Unlock Tiers in the GEMS tab (needs 15 rebirths)."
		tierBtn.Visible, tierBarFrame.Visible = false, false
	else
		local req = F.tierRequirement(d)
		local have = F.tierProgress(d)
		local waitLeft = F.tierTimeLeft(d)
		local rName = string.upper(Progression.Rarities[req.rarity].name)
		local c = rarityColor(req.rarity)
		tierInfo.Text = string.format('TIER %d ▶ %d<br/><font color="#7d7696">collect</font> <font color="#%s">%s%s</font> <font color="#5cf2ff">%s / %s</font>%s', d.tiers, d.tiers + 1, c:ToHex(), rName, req.relative and " or rarer" or "", fmt(math.floor(have)), fmt(req.count),
			waitLeft > 0 and string.format('  <font color="#ffe14a">ready in %s</font>', clock(math.ceil(waitLeft))) or "")
		setTierBar(have / req.count)
		tierBtn.Visible, tierBarFrame.Visible = true, true
		Kit.setAffordable(tierBtn, F.canTier(d))
		Kit.setLabel(tierBtn, F.canTier(d) and "TIER UP" or "NOT READY")
	end
	tierPerks.Text = string.format("Each tier: x2 cash, x3 luck, +1 TP, +1 QP, a new board. Resets cash, gems, rebirths, upgrades. Current: x%s cash, x%s luck from tiers.", fmtLog(d.tiers * math.log10(2), 0), fmtLog(d.tiers * math.log10(3), 0))
	local autoOpen = d.tiers >= 2
	autoTitle.Visible, autoRow.Visible, autoPts.Visible = autoOpen, autoOpen, autoOpen
	autoPts.Text = "points: " .. fmt(d.automationPoints) .. "  (10% chance per orb, tier 2+)"
	for i, b in autoButtons do
		local lvl = d.automation.levels[i]
		local oneShot = i >= 3
		local needSkill = (i == 3 and F.skill(d, "MAX-1") < 1) or (i == 4 and F.skill(d, "MAX-2") < 1)
		local label = AUTO_NAMES[i] .. "\n"
		if oneShot and lvl >= 1 then
			label ..= "OWNED"
		elseif needSkill then
			label ..= "needs " .. (i == 3 and "Quick Hands" or "Spawner Rush")
		else
			label ..= fmt(F.automationCost(d, i)) .. " pts" .. (not oneShot and string.format("\nevery %.1fs", F.automationInterval(lvl + 1)) or "")
		end
		Kit.setLabel(b, label)
		Kit.setAffordable(b, not needSkill and not (oneShot and lvl >= 1) and d.automationPoints >= F.automationCost(d, i))
	end
	for i, t in autoToggles do
		local on = d.automation.enabled[i]
		Kit.setLabel(t, d.automation.levels[i] > 0 and (on and "ON" or "OFF") or "-")
		Kit.setButtonColors(t, on and C.Cash or C.Tab, on and C.CashDark or C.TabDark)
	end
end)

-- SETTINGS
local settingsBody = modal("Settings", "SETTINGS", C.Steel, C.SteelDark)
text({ text = "DIFFICULTY (only before your first rebirth)", size = 14, outline = 2, parent = settingsBody })
local diffRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 40), Parent = settingsBody }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
local diffButtons = {}
for i, key in { "baby", "easy", "orig", "hard", "extreme" } do
	diffButtons[key] = Kit.button({ text = string.upper(key == "orig" and "normal" or key), size = 13, dim = UDim2.new(0.2, -5, 1, 0), order = i, parent = diffRow, onClick = function()
		act("setDifficulty", key)
	end })
end
local statsText = text({ text = "", rich = true, size = 14, font = Fonts.Bold, color = C.Sub, wrap = true, pos = UDim2.fromOffset(0, 84), dim = UDim2.new(1, 0, 0, 200), alignY = Enum.TextYAlignment.Top, parent = settingsBody })
onState(function(d)
	for key, b in diffButtons do
		local on = d.difficulty == key
		Kit.setButtonColors(b, on and C.Cyan or C.Tab, on and C.GemDark or C.TabDark)
	end
	statsText.Text = string.format(
		'TIME PLAYED <font color="#ffffff">%s</font><br/>REBIRTHS <font color="#ffffff">%s</font>   TIERS <font color="#ffffff">%d</font><br/>TOTAL CASH <font color="#7cff5b">$%s</font><br/>TOTAL GEMS <font color="#5cf2ff">%s</font><br/>ORBS DROPPED <font color="#ffffff">%s</font><br/>BEST LUCK <font color="#ffe14a">x%s</font>',
		clock(d.timePlayed), fmt(d.rebirths), d.tiers, fmt(d.totalMoney), fmt(d.totalDiamonds), fmt(d.orbsSpawned), fmtLog(d.bestLuckLog, 2))
end)
settingsBtn.Activated:Connect(function()
	openModal("Settings")
end)

---------------------------------------------------------------- dock

local dock = new("Frame", { Name = "Dock", BackgroundColor3 = C.White, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, CX, 0, 720 - M + 2), Size = UDim2.fromOffset(560, DOCK_H), Parent = canvas }, {
	Kit.corner(8), Kit.stroke(4), new("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 31, 168)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(176, 23, 59)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 31, 168)),
	}) }),
})
Kit.texture(dock, "studTile", 0.6, 48)
local function dockTab(i, icon, label, onClick)
	local slot = new("TextButton", { Name = label, Text = "", AutoButtonColor = true, BackgroundColor3 = Color3.fromRGB(18, 11, 32), BackgroundTransparency = 0.15, Size = UDim2.fromOffset(96, 40), Position = UDim2.fromOffset(14 + (i - 1) * 106, 26), Parent = dock }, { Kit.corner(5), Kit.stroke(2) })
	Kit.icon(icon, 64, { parent = slot, anchor = Vector2.new(0.5, 0.5), pos = UDim2.new(0.5, 0, 0, -6), z = 5 })
	text({ text = label, size = 15, outline = 2.5, alignX = Enum.TextXAlignment.Center, dim = UDim2.new(1, 0, 0, 18), pos = UDim2.new(0, 0, 1, -21), parent = slot }).ZIndex = 6
	local badge = new("Frame", { Name = "Badge", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -10, 0, -16), BackgroundColor3 = C.White, Visible = false, ZIndex = 7, Parent = slot }, { Kit.corner(4), Kit.stroke(2.5), Kit.gradient(C.Red, C.RedDark) })
	local bt = text({ text = "!", size = 13, outline = 1.5, alignX = Enum.TextXAlignment.Center, dim = UDim2.fromScale(1, 1), parent = badge })
	bt.ZIndex = 8
	slot.Activated:Connect(onClick)
	return badge, bt
end
local spawnBadge = dockTab(1, "spawn", "SPAWN", function()
	upgradesPanel.Visible = not upgradesPanel.Visible
	showTab("SPAWNERS")
end)
local stormBadge = dockTab(2, "storm", "STORM", function()
	openModal("Storm")
end)
local skillBadge, skillBadgeText = dockTab(3, "star", "SKILLS", function()
	openModal("Skills")
end)
local tierBadge = dockTab(4, "tier", "TIER", function()
	openModal("Tier")
end)
local rebirthBtn = Kit.button({ text = "", size = 18, color1 = C.Gold, color2 = C.GoldDark, dim = UDim2.fromOffset(118, 58), anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -10, 0.5, 0), parent = dock, onClick = function()
	act("rebirth")
end })
rebirthBtn.ClipsDescendants = false
Kit.icon("rebirth", 52, { parent = rebirthBtn, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromOffset(-4, -6), z = 5 })
rebirthBtn.Label.Position = UDim2.fromOffset(0, -8)
local rebirthCost = text({ text = "", size = 13, font = Fonts.HeavyItalic, color = Color3.fromRGB(90, 42, 0), alignX = Enum.TextXAlignment.Center, pos = UDim2.new(0, 0, 1, -20), dim = UDim2.new(1, 0, 0, 16), parent = rebirthBtn })
rebirthCost.ZIndex = 4
onState(function(d)
	if d.mechanics < 1 then
		Kit.setLabel(rebirthBtn, "LOCKED")
		rebirthCost.Text = "50 gems"
		Kit.setButtonColors(rebirthBtn, C.Tab, C.TabDark)
	else
		local gained = F.skill(d, "MAX-3") >= 1 and F.bulkRebirths(d) or 1
		Kit.setLabel(rebirthBtn, gained > 1 and ("REBIRTH x" .. fmt(gained)) or "REBIRTH")
		local cost = F.rebirthCost(d, d.rebirths + gained - 1)
		rebirthCost.Text = "$" .. fmt(cost)
		local ok = Big.gt(d.money, cost)
		Kit.setButtonColors(rebirthBtn, ok and C.Gold or C.Tab, ok and C.GoldDark or C.TabDark)
	end
	stormBadge.Visible = d.mechanics >= 5 and d.weatherPoints >= F.weatherRollPrice(d) and d.weatherRollCooldown == 0
	local pts = Economy.points(d)
	skillBadge.Visible = d.tiers >= 1 and (pts.tp > 0 or pts.qp > 0)
	skillBadgeText.Text = tostring(math.max(pts.tp, 0) + math.max(pts.qp, 0))
	tierBadge.Visible = d.mechanics >= 4 and F.canTier(d)
end)

---------------------------------------------------------------- income + stat lines

local lastMoneyLog, lastT, rateLog = nil, os.clock(), -math.huge
onState(function(d)
	cashValue.Text = "$" .. fmt(d.money)
	gemValue.Text = fmt(d.diamonds)
	stormValue.Text = tostring(d.weatherPoints)
	-- income: smoothed growth of total money (never negative across resets)
	local nowLog, now = Big.log10(d.totalMoney), os.clock()
	if lastMoneyLog and now - lastT >= 1 and nowLog > -math.huge then
		local deltaLog = nowLog + math.log10(math.max(1 - 10 ^ ((lastMoneyLog or -math.huge) - nowLog), 1e-12))
		local inst = deltaLog - math.log10(now - lastT)
		rateLog = if rateLog == -math.huge then inst else math.log10(0.7 * 10 ^ (rateLog - inst) + 0.3) + inst
		lastMoneyLog, lastT = nowLog, now
	elseif not lastMoneyLog then
		lastMoneyLog, lastT = nowLog, now
	end
	incomeText.Text = rateLog > -math.huge and ("$" .. fmtLog(rateLog, 2) .. "/s") or "$0/s"
	statLuck.Text = string.format('<font color="#9bff3d">x%s</font> <font color="#22b33a">LUCK</font>', fmtLog(d.totalLuckLog, 2))
	statCash.Text = string.format('<font color="#ff7ae6">x%s</font> <font color="#a33bff">CASH MULTI</font>', fmt(F.orbMoneyMult(d), 2))
	statBonus.Text = d.mechanics >= 3 and string.format('<font color="#ff5a7a">x%s</font> <font color="#c4143b">RARITY BONUS</font>', fmtLog(d.highestRarity * math.log10(Config.Base.RarityMoneyBonus), 2)) or '<font color="#7d7696">rarity bonus locked</font>'
end)


---------------------------------------------------------------- events banner

local eventBar = new("Frame", { Name = "EventBar", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(CX, M + 132), Size = UDim2.fromOffset(600, 26), Parent = canvas }, {
	Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center),
})
local activeEvents = {}
local function renderEvents()
	for _, c in eventBar:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local now = os.time()
	for _, ev in activeEvents do
		local def = Events.TYPES[ev.id]
		if def and (ev.endsAt or 0) > now then
			local col = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
			local chip = new("Frame", { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(150, 26), AutomaticSize = Enum.AutomaticSize.X, Parent = eventBar }, {
				Kit.corner(6), Kit.stroke(2.5, col), Kit.padding(8, 8, 0, 0),
			})
			text({ text = string.format("%s  %s", def.name, clock(ev.endsAt - now)), size = 12, font = Fonts.HeavyItalic, outline = 1.5, color = col, auto = Enum.AutomaticSize.X, dim = UDim2.new(0, 0, 1, 0), parent = chip })
		end
	end
end
R.Events.OnClientEvent:Connect(function(list)
	activeEvents = list or {}
	Balance.setEvents(activeEvents) -- client-side displays (luck, payouts) match the server
	renderEvents()
end)
task.spawn(function()
	while true do
		task.wait(1)
		Balance.ctx.now = os.time()
		renderEvents()
	end
end)

---------------------------------------------------------------- tutorial

local tutor = new("Frame", { Name = "Tutorial", BackgroundColor3 = C.Panel, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, CX, 0, 720 - M - DOCK_H - 26), Size = UDim2.fromOffset(470, 70), Visible = false, ZIndex = 40, Parent = canvas }, {
	Kit.corner(8), Kit.stroke(4, C.Cyan),
})
local tutorText = text({ text = "", size = 15, outline = 2, wrap = true, pos = UDim2.fromOffset(14, 8), dim = UDim2.new(1, -110, 1, -16), parent = tutor })
tutorText.ZIndex = 41
local tutorStep = text({ text = "", size = 11, font = Fonts.Bold, color = C.Cyan, pos = UDim2.new(1, -92, 0, 10), dim = UDim2.fromOffset(80, 14), alignX = Enum.TextXAlignment.Right, parent = tutor })
tutorStep.ZIndex = 41
local tutorSkip = Kit.button({ text = "SKIP", size = 12, color1 = C.Tab, color2 = C.TabDark, dim = UDim2.fromOffset(80, 28), anchor = Vector2.new(1, 1), pos = UDim2.new(1, -10, 1, -10), z = 41, parent = tutor, onClick = function()
	act("skipTutorial")
end })
local highlight = Kit.stroke(4, C.Cyan)
highlight.Name = "TutorialHighlight"
local function targetFrame(name)
	if name == "Board" then return boardFrame end
	if name == "UpgradesPanel" then return upgradesPanel end
	if name == "Dock" then return dock end
	return nil
end
local pulse = 0
RunService.Heartbeat:Connect(function(dt)
	pulse += dt
	highlight.Transparency = 0.25 + 0.5 * (0.5 + 0.5 * math.sin(pulse * 5))
end)
onState(function(d)
	local step, i = Tutorial.current(d)
	tutor.Visible = step ~= nil
	if not step then
		highlight.Parent = nil
		return
	end
	tutorText.Text = step.text
	tutorStep.Text = string.format("STEP %d/%d", i, #Tutorial.STEPS)
	Kit.setLabel(tutorSkip, step.final and "DONE" or "SKIP")
	local target = targetFrame(step.target)
	highlight.Parent = target
end)

---------------------------------------------------------------- leaderboards

local lbBody = modal("Leaders", "LEADERBOARDS", C.Gold, C.GoldDark)
local lbTabs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = lbBody }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
local lbList = Kit.scroll({ dim = UDim2.new(1, 0, 1, -38), pos = UDim2.fromOffset(0, 38), gap = 2, parent = lbBody })
local lbData, lbCurrent = {}, "cash"
local LB_ORDER = { "cash", "tiers", "rebirths", "runes", "rarity" }
local LB_LABEL = { cash = "CASH", tiers = "TIERS", rebirths = "REBIRTHS", runes = "RUNES", rarity = "RARITY" }
local lbTabButtons = {}
local function renderLB()
	for _, c in lbList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for id, b in lbTabButtons do
		Kit.setButtonColors(b, id == lbCurrent and C.Gold or C.Tab, id == lbCurrent and C.GoldDark or C.TabDark)
	end
	local board = lbData[lbCurrent]
	if not board or #board.rows == 0 then
		text({ text = "No scores yet (leaderboards refresh every 2 minutes).", size = 14, color = C.Sub, outline = 1.5, parent = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 30), Parent = lbList }) })
		return
	end
	for _, row in board.rows do
		local r = new("Frame", { BackgroundColor3 = C.White, BackgroundTransparency = row.rank % 2 == 0 and 0.97 or 1, Size = UDim2.new(1, -6, 0, 26), LayoutOrder = row.rank, Parent = lbList }, { Kit.corner(4) })
		local medal = row.rank == 1 and C.Gold or row.rank == 2 and Color3.fromRGB(200, 205, 220) or row.rank == 3 and Color3.fromRGB(255, 154, 80) or C.Sub
		text({ text = "#" .. row.rank, size = 14, font = Fonts.HeavyItalic, outline = 1.5, color = medal, pos = UDim2.fromOffset(8, 0), dim = UDim2.new(0, 44, 1, 0), parent = r })
		text({ text = row.name, size = 14, outline = 1.5, color = row.name == player.Name and C.Cyan or C.White, pos = UDim2.fromOffset(56, 0), dim = UDim2.new(1, -220, 1, 0), parent = r })
		text({ text = row.display, size = 14, font = Fonts.HeavyItalic, outline = 1.5, color = C.Gold, alignX = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 0), pos = UDim2.new(1, -8, 0, 0), dim = UDim2.fromOffset(160, 26), parent = r })
	end
end
for i, id in LB_ORDER do
	lbTabButtons[id] = Kit.button({ text = LB_LABEL[id], size = 13, dim = UDim2.new(0.2, -5, 1, 0), order = i, parent = lbTabs, onClick = function()
		lbCurrent = id
		renderLB()
	end })
end
R.Leaderboards.OnClientEvent:Connect(function(boards)
	lbData = boards or {}
	renderLB()
end)
renderLB()
local lbBtn = Kit.button({ text = "", color1 = C.Gold, color2 = C.GoldDark, dim = UDim2.fromOffset(48, 48), pos = UDim2.fromOffset(1280 - M - 48 - 56, M), parent = canvas, onClick = function()
	openModal("Leaders")
end })
Kit.icon("star", 40, { parent = lbBtn, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), z = 4 })
toastHost.Position -= UDim2.fromOffset(56, 0)

---------------------------------------------------------------- runes (altar + forge)
local runeTab -- set inside the block below (kept in its own scope: Luau caps top-level locals)
do

	local runeBody = modal("Runes", "STARTER RUNES", Color3.fromRGB(70, 160, 255), Color3.fromRGB(40, 60, 160))
	local runeTabs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = runeBody }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local runePages, runeTabBtns = {}, {}
	runeTab = function(name)
		for n, pg in runePages do
			pg.Visible = n == name
		end
		for n, b in runeTabBtns do
			Kit.setButtonColors(b, n == name and C.Cyan or C.Tab, n == name and C.GemDark or C.TabDark)
		end
	end
	for i, name in { "RUNES", "FORGE", "BONUSES" } do
		runeTabBtns[name] = Kit.button({ text = name, size = 13, dim = UDim2.new(1 / 3, -4, 1, 0), order = i, parent = runeTabs, onClick = function()
			runeTab(name)
		end })
		runePages[name] = Kit.scroll({ name = name, dim = UDim2.new(1, 0, 1, -38), pos = UDim2.fromOffset(0, 38), gap = 6, parent = runeBody })
	end
	-- RUNES page: stats strip, roll buttons, 10 rune cards
	local runeStats = text({ text = "", rich = true, size = 13, font = Fonts.Bold, color = C.Sub, wrap = true, dim = UDim2.new(1, -6, 0, 40), order = 1, parent = runePages.RUNES })
	local rollRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 40), LayoutOrder = 2, Parent = runePages.RUNES }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local rollBtn = Kit.button({ text = "ROLL", size = 15, color1 = C.Cyan, color2 = C.GemDark, dim = UDim2.new(0.5, -3, 1, 0), order = 1, parent = rollRow, onClick = function()
		act("runeRoll")
	end })
	local passBtn = Kit.button({ text = "AUTO-ROLL x2 (R$)", size = 13, color1 = C.Gold, color2 = C.GoldDark, dim = UDim2.new(0.5, -3, 1, 0), order = 2, parent = rollRow, onClick = function()
		act("promptAutoRoll")
	end })
	local runeCards = {}
	for i, r in Runes.LIST do
		local card = Kit.card({ dim = UDim2.new(1, -6, 0, 44), order = 10 + i, parent = runePages.RUNES })
		local dot = new("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12, 9), BackgroundColor3 = Color3.fromRGB(r.color[1], r.color[2], r.color[3]), Rotation = 45, Parent = card }, { Kit.corner(4), Kit.stroke(2) })
		local nm = text({ text = "", size = 15, outline = 2, pos = UDim2.fromOffset(50, 4), dim = UDim2.new(0.5, -50, 0, 18), parent = card })
		local odds = text({ text = "1/" .. fmt(r.oneIn), size = 11, font = Fonts.Bold, color = C.Sub, pos = UDim2.fromOffset(50, 23), dim = UDim2.new(0.5, -50, 0, 16), parent = card })
		local info = text({ text = "", rich = true, size = 12, font = Fonts.Bold, alignX = Enum.TextXAlignment.Right, pos = UDim2.new(0.5, 0, 0, 4), dim = UDim2.new(0.5, -12, 1, -8), wrap = true, parent = card })
		runeCards[i] = { dot = dot, name = nm, info = info, odds = odds }
	end
	-- FORGE page: gem upgrades
	local forgeRows = {}
	for i, u in Runes.FORGE do
		local card = Kit.card({ dim = UDim2.new(1, -6, 0, 50), order = i, parent = runePages.FORGE })
		text({ text = u.name, size = 15, outline = 2, pos = UDim2.fromOffset(14, 4), dim = UDim2.new(1, -160, 0, 18), parent = card })
		local d = text({ text = "", size = 11, font = Fonts.Bold, color = C.Sub, pos = UDim2.fromOffset(14, 26), dim = UDim2.new(1, -160, 0, 16), parent = card })
		local b = Kit.button({ text = "", size = 13, color1 = C.Gem, color2 = C.GemDark, dim = UDim2.fromOffset(130, 34), anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -10, 0.5, 0), parent = card, onClick = function()
			act("buyRuneForge", u.id)
		end })
		forgeRows[u.id] = { desc = d, button = b, def = u }
	end
	-- BONUSES page: milestones + playtime
	local msText = text({ text = "", rich = true, size = 13, font = Fonts.Bold, wrap = true, dim = UDim2.new(1, -6, 0, 92), order = 1, parent = runePages.BONUSES })
	local ptRows = {}
	for i, p in Runes.PLAYTIME do
		local label = p.bulkAdd and ("+" .. p.bulkAdd .. " bulk") or p.bulk and ("x" .. p.bulk .. " bulk") or ("x" .. p.luck .. " luck")
		local when = p.minutes >= 60 and (p.minutes / 60 .. " hour" .. (p.minutes > 60 and "s" or "")) or (p.minutes .. " min")
		ptRows[i] = text({ text = when .. " on the pad: " .. label, rich = true, size = 13, font = Fonts.Bold, dim = UDim2.new(1, -6, 0, 18), order = 10 + i, parent = runePages.BONUSES })
	end
	runeTab("RUNES")

	onState(function(d)
		if not d.runes then
			return
		end
		local sess = d._session or {}
		local st = Runes.stats(d, sess.hasPass)
		local s = d.runes
		runeStats.Text = string.format('Opened <font color="#5cf2ff">%s</font> · bulk <font color="#5cf2ff">%s</font> · <font color="#5cf2ff">%.2f</font> rolls/s · luck <font color="#7cff5b">x%.2f</font> · clone %d%% (+%d)\n%s',
			fmt(s.opened), fmt(st.bulk), st.rate, st.luck, math.floor(st.clone * 100 + 0.5), st.cloneAmount,
			sess.hasPass and '<font color="#ffd64a">AUTO-ROLL x2 active anywhere</font>' or (sess.onPad and '<font color="#7cff5b">On the pad: auto-rolling</font>' or "Stand on the altar pad to auto-roll ($10 per rune)"))
		passBtn.Visible = not sess.hasPass
		for i, r in Runes.LIST do
			local c, card = s.counts[i] or 0, runeCards[i]
			local found = c > 0
			card.name.Text = found and string.upper(r.name) or "???"
			card.dot.BackgroundColor3 = found and Color3.fromRGB(r.color[1], r.color[2], r.color[3]) or Color3.fromRGB(10, 8, 18)
			local boost = Runes.boost(r, c)
			local what = r.stat == "cash" and "cash" or r.stat == "rebirth" and "rebirth pts" or r.stat == "ap" and "AP" or "TrP"
			if r.cap then
				card.info.Text = string.format('x%s · <font color="#7cff5b">+%g%% %s</font>%s', fmt(c), boost * 100, what, c >= r.cap and ' <font color="#ffd64a">MAX</font>' or (" (max +" .. r.cap * r.per * 100 .. "%)"))
			else
				card.info.Text = string.format('x%s · LV %d · <font color="#7cff5b">+%g%% %s</font>\nnext LV at %s', fmt(c), Runes.level(c), boost * 100, what, fmt(Runes.nextLevelAt(c)))
			end
		end
		for id, row in forgeRows do
			local lv = s.forge[id]
			local cost = Runes.forgeCost(d, id)
			row.desc.Text = row.def.desc .. "  ·  LV " .. lv .. "/" .. row.def.max
			Kit.setLabel(row.button, cost and (Big.format(cost) .. " GEMS") or "MAXED")
			Kit.setAffordable(row.button, cost ~= nil and Big.gte(d.diamonds, cost))
		end
		msText.Text = string.format('<font color="#ffd64a">OPENING MILESTONES</font> %d reached · next at %s opened\neach: x1.15 bulk, +1 bulk (first 4)\n<font color="#ffd64a">ORB MILESTONES</font> %d reached · next at %s orbs dropped\neach: x1.05 rune speed, x1.10 rune luck\n<font color="#ffd64a">PAD TIME</font> %s',
			st.openMilestones, fmt(st.nextOpen), st.ballMilestones, fmt(st.nextBalls), F.formatTime and F.formatTime(s.padSeconds) or (math.floor(s.padSeconds / 60) .. " min"))
		for i, p in Runes.PLAYTIME do
			local done = s.padSeconds >= p.minutes * 60
			ptRows[i].TextColor3 = done and C.Cash or C.Sub
		end
	end)
end

---------------------------------------------------------------- world: stands + progressive HUD

-- side panels float over the world only when you're using them
upgradesPanel.Visible = false
rarityPanel.Visible = false
local idxBtn = Kit.button({ text = "", color1 = Color3.fromRGB(43, 47, 85), color2 = Color3.fromRGB(27, 30, 58), dim = UDim2.fromOffset(48, 48), pos = UDim2.fromOffset(1280 - M - 48 - 168, M), parent = canvas, onClick = function()
	rarityPanel.Visible = not rarityPanel.Visible
end })
Kit.icon("star", 40, { parent = idxBtn, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), z = 4 })
toastHost.Position -= UDim2.fromOffset(56, 0)

local STAND_TAB = { cash = "MAIN", gems = "GEMS", spawners = "SPAWNERS" }
Stands.init(workspace:WaitForChild("OrbWorld"), {
	onOpen = function(id)
		if STAND_TAB[id] then
			openModal(nil)
			upgradesPanel.Visible = true
			showTab(STAND_TAB[id])
		elseif id == "rebirth" then
			act("rebirth")
		elseif id == "skills" then
			openModal(data and data.mechanics >= 4 and "Tier" or "Skills")
		elseif id == "weather" then
			openModal("Storm")
		elseif id == "runes" or id == "forge" then
			openModal("Runes")
			runeTab(id == "forge" and "FORGE" or "RUNES")
		else
			openModal("Prestige")
		end
	end,
	onLeave = function()
		upgradesPanel.Visible = false
		openModal(nil)
	end,
})

RuneAltarUI.init(workspace:WaitForChild("OrbWorld"))
onState(RuneAltarUI.refresh)

-- HUD buttons follow the same reveal as the stands: the game starts as just the board
local standsSeen = false
onState(function(d)
	Stands.refresh(d, standsSeen)
	standsSeen = true
	local function open(id)
		return Unlocks.state(d, id) == "open"
	end
	tabButtons.MAIN.Visible = open("cash")
	tabButtons.GEMS.Visible = open("gems")
	tabButtons.SPAWNERS.Visible = open("spawners")
	gemValue.Parent.Parent.Visible = open("gems")
	spawnBadge.Parent.Visible = open("spawners")
	stormBadge.Parent.Visible = open("weather")
	skillBadge.Parent.Visible = open("skills")
	tierBadge.Parent.Visible = open("skills")
	rebirthBtn.Visible = open("rebirth")
	dock.Visible = open("spawners") or open("rebirth") or open("skills")
	prBtn.Visible = Unlocks.state(d, "ascension") ~= "hidden"
end)

---------------------------------------------------------------- admin panel (only shown to admins; server re-checks every call)

task.spawn(function()
	local ok, isAdmin = pcall(function()
		return R.Admin:InvokeServer("isAdmin")
	end)
	if not (ok and isAdmin) then
		return
	end
	local body = modal("Admin", "ADMIN · EVENTS", C.Red, C.RedDark)
	local status = text({ text = "", size = 12, font = Fonts.Bold, color = C.Sub, dim = UDim2.new(1, 0, 0, 16), parent = body })
	local grid = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 230), Parent = body }, {
		new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 70), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local minutesBox = new("TextBox", { PlaceholderText = "minutes (blank = default)", Text = "", ClearTextOnFocus = false, FontFace = Fonts.Bold, TextSize = 14, TextColor3 = C.White, PlaceholderColor3 = C.Sub, BackgroundColor3 = C.Card, Position = UDim2.fromOffset(0, 262), Size = UDim2.new(0.5, -4, 0, 36), Parent = body }, { Kit.corner(5), Kit.stroke(2.5) })
	Kit.button({ text = "STOP ALL EVENTS", size = 13, color1 = C.Red, color2 = C.RedDark, dim = UDim2.new(0.5, -4, 0, 36), pos = UDim2.new(0.5, 4, 0, 262), parent = body, onClick = function()
		local okStop = R.Admin:InvokeServer("stop")
		status.Text = okStop and "stopped all events" or "failed"
	end })
	local announceBox = new("TextBox", { PlaceholderText = "announcement to every server player", Text = "", ClearTextOnFocus = false, FontFace = Fonts.Bold, TextSize = 14, TextColor3 = C.White, PlaceholderColor3 = C.Sub, BackgroundColor3 = C.Card, Position = UDim2.fromOffset(0, 306), Size = UDim2.new(0.75, -4, 0, 36), Parent = body }, { Kit.corner(5), Kit.stroke(2.5) })
	Kit.button({ text = "SEND", size = 13, color1 = C.Cyan, color2 = C.GemDark, dim = UDim2.new(0.25, -4, 0, 36), pos = UDim2.new(0.75, 4, 0, 306), parent = body, onClick = function()
		local okA, err = R.Admin:InvokeServer("announce", announceBox.Text)
		status.Text = okA and "announced" or ("announce failed: " .. tostring(err))
		if okA then
			announceBox.Text = ""
		end
	end })
	local okT, types = R.Admin:InvokeServer("types")
	if okT then
		for i, t in types do
			local col = Color3.fromRGB(t.color[1], t.color[2], t.color[3])
			Kit.button({ text = t.name .. "\n" .. t.minutes .. " min", size = 13, color1 = col, color2 = col:Lerp(Color3.new(0, 0, 0), 0.45), order = i, parent = grid, onClick = function()
				local okS, err = R.Admin:InvokeServer("start", t.id, tonumber(minutesBox.Text))
				status.Text = okS and ("started " .. t.name) or ("failed: " .. tostring(err))
			end }).Label.TextWrapped = true
		end
	end
	local adminBtn = Kit.button({ text = "ADMIN", size = 12, color1 = C.Red, color2 = C.RedDark, dim = UDim2.fromOffset(64, 28), pos = UDim2.fromOffset(1280 - M - 64, M + 56), parent = canvas, onClick = function()
		openModal("Admin")
	end })
	adminBtn.ZIndex = 30
end)


---------------------------------------------------------------- prestige (ascension, transcension, ...)

local prBody = modal("Prestige", "PRESTIGE", C.Purple, C.Pink)
local prList = Kit.scroll({ dim = UDim2.fromScale(1, 1), gap = 8, parent = prBody })
local prRows = {}
for li, L in Prestige.LAYERS do
	local head = Kit.card({ dim = UDim2.new(1, -6, 0, 74), order = li * 100, parent = prList })
	local title = text({ text = string.upper(L.name), size = 18, outline = 2.5, pos = UDim2.fromOffset(10, 6), dim = UDim2.new(1, -190, 0, 22), parent = head })
	local info = text({ text = "", rich = true, size = 12, font = Fonts.Bold, color = C.Sub, wrap = true, pos = UDim2.fromOffset(10, 30), dim = UDim2.new(1, -190, 0, 38), parent = head })
	local go = Kit.button({ text = "", size = 14, color1 = C.Storm, color2 = C.Purple, dim = UDim2.fromOffset(160, 50), anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -10, 0.5, 0), parent = head, onClick = function()
		act("prestige", L.id)
	end })
	go.Label.TextWrapped = true
	local shop = {}
	for ui, u in L.shop do
		local c = Kit.card({ dim = UDim2.new(1, -6, 0, 46), order = li * 100 + ui, parent = prList })
		text({ text = u.name, size = 14, outline = 2, pos = UDim2.fromOffset(16, 4), dim = UDim2.new(1, -150, 0, 18), parent = c })
		local d2 = text({ text = "", size = 11, font = Fonts.Bold, color = C.Sub, pos = UDim2.fromOffset(16, 24), dim = UDim2.new(1, -150, 0, 16), parent = c })
		local b = Kit.button({ text = "", size = 13, dim = UDim2.fromOffset(110, 32), anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -10, 0.5, 0), parent = c, onClick = function()
			act("buyPrestigeUpgrade", u.id)
		end })
		shop[u.id] = { card = c, desc = d2, button = b, def = u }
	end
	prRows[L.id] = { head = head, title = title, info = info, go = go, shop = shop }
end
onState(function(d)
	if not d.prestige then
		return
	end
	for li, L in Prestige.LAYERS do
		local row, st = prRows[L.id], d.prestige[L.id]
		local below = Prestige.LAYERS[li - 1]
		-- a layer shows once the one below has been used at least once (ascension: once rebirths unlock)
		local visible = (li == 1 and d.mechanics >= 1) or (below and d.prestige[below.id].count > 0) or st.count > 0
		row.head.Visible = visible
		local pending = Prestige.pending(d, L.id)
		local req = Prestige.requirement(d, L.id)
		local need = L.source == "rebirths" and (fmt(req) .. " rebirths") or (fmt(req) .. " lifetime " .. Prestige.LAYERS[li - 1].point)
		row.info.Text = string.format('<font color="#e3a6ff">%s %s</font> · lifetime %s · passive <font color="#7cff5b">+%s%% %s</font> · needs %s',
			fmt(st.points), L.point, fmt(st.lifetime), fmt(L.perPoint * 100 * st.lifetime), L.passiveTarget == "rebirthGain" and "rebirths/click" or "AP gain", need)
		Kit.setLabel(row.go, pending > 0 and string.format("%s\n+%s %s", string.upper(L.name), fmt(pending), L.point) or "NOT READY")
		Kit.setAffordable(row.go, pending > 0)
		for id, sh in row.shop do
			sh.card.Visible = visible
			local lv = st.shop[id] or 0
			local cost = Prestige.cost(d, id)
			sh.desc.Text = sh.def.desc .. "  ·  LV " .. lv
			Kit.setLabel(sh.button, cost and (fmt(cost) .. " " .. L.point) or "MAXED")
			Kit.setAffordable(sh.button, cost ~= nil and st.points >= cost)
		end
	end
end)
local prBtn = Kit.button({ text = "", color1 = C.Storm, color2 = C.Purple, dim = UDim2.fromOffset(48, 48), pos = UDim2.fromOffset(1280 - M - 48 - 112, M), parent = canvas, onClick = function()
	openModal("Prestige")
end })
Kit.icon("tier", 40, { parent = prBtn, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), z = 4 })
toastHost.Position -= UDim2.fromOffset(56, 0)

---------------------------------------------------------------- server events

R.State.OnClientEvent:Connect(function(serialized)
	local first = data == nil
	data = Economy.deserialize(serialized)
	data._session = type(serialized) == "table" and serialized._session or {}
	for _, fn in refreshers do
		local ok, err = pcall(fn, data)
		if not ok then
			warn("[OrbHUD]", err)
		end
	end
	if first then
		rebuildBoard()
	end
end)

R.Notify.OnClientEvent:Connect(function(kind, payload)
	if kind == "newRarity" then
		local r = Progression.Rarities[payload]
		toast("NEW RARITY DISCOVERED", string.upper(r.name), "1/" .. fmtLog(r.oneInLog, 0), rarityColor(payload))
	elseif kind == "tier" then
		toast("TIER UP!", "TIER " .. payload, "new board", C.Pink)
	elseif kind == "weather" then
		toast("WEATHER ROLLED", string.upper(Config.Weather[payload].name), nil, C.Storm)
	elseif kind == "event" then
		local def = Events.TYPES[payload.id]
		if def then
			toast("EVENT STARTED", def.name, "by " .. tostring(payload.by), Color3.fromRGB(def.color[1], def.color[2], def.color[3]))
		end
	elseif kind == "prestige" then
		local L = Prestige.byId[payload]
		toast(string.upper(L.name) .. "!", "+" .. L.point .. " BANKED", "magnified", C.Storm)
	elseif kind == "unlock" then
		local s = Unlocks.byId[payload]
		if s then
			toast("NEW STAND UNLOCKED", s.name, "go check it out!", Color3.fromRGB(s.color[1], s.color[2], s.color[3]))
		end
	elseif kind == "rareDrop" and type(payload) == "table" then
		local r = Progression.Rarities[payload.rarity]
		if r then
			toast(string.upper(tostring(payload.name)) .. " ROLLED", string.upper((payload.variant and payload.variant .. " " or "") .. r.name), "1/" .. fmtLog(r.oneInLog, 0), rarityColor(payload.rarity))
		end
	elseif kind == "runeOpen" then
		RuneAltarUI.opened(payload)
	elseif kind == "rune" and type(payload) == "table" then
		local r = Runes.LIST[payload.id]
		if r then
			toast("RARE RUNE!", string.upper(r.name) .. (payload.count > 1 and (" x" .. payload.count) or ""), "1/" .. fmt(r.oneIn), Color3.fromRGB(r.color[1], r.color[2], r.color[3]))
		end
	elseif kind == "runeDrop" and type(payload) == "table" then
		local r = Runes.LIST[payload.id]
		if r then
			toast(string.upper(tostring(payload.name)) .. " FOUND", string.upper(r.name) .. " RUNE", "1/" .. fmt(r.oneIn), Color3.fromRGB(r.color[1], r.color[2], r.color[3]))
		end
	elseif kind == "announce" then
		toast("ANNOUNCEMENT", tostring(payload), nil, C.Cyan)
	end
end)

-- live timers between state pushes
RunService.Heartbeat:Connect(function()
	if data then
		capLabel.Text = string.format('<font color="#7d7696">ORBS</font> <font color="#5cf2ff">%d / %d</font>', board.count, F.spawnCap(data))
	end
end)
