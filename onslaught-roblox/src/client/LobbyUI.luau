--[[
	The lobby: pick a run and play solo or with a party (up to 4), and manage the account.
	  left   Play: Classic / Onslaught+, difficulty (or a challenge), map, then Solo / Create party / Join
	  right  tabs: Research (Onslaught+ lab), Quests (3 a day), Store (passes and account products),
	         Leaderboards, Profile (lifetime stats, skins)
	All changes go through ctx.request; the server answers with the updated profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GAME = require(ReplicatedStorage.Shared.Onslaught.Data)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Ui = require(script.Parent.Ui)

local C, new, text, button = Ui.C, Ui.new, Ui.text, Ui.button
local LobbyUI = {}
LobbyUI.__index = LobbyUI

-- ctx = { gui, request(op, ...) -> any, profile() -> view, userId, toast(msg, color) }
function LobbyUI.new(ctx)
	local self = setmetatable({}, LobbyUI)
	self.ctx = ctx
	self.choice = { mode = "medium", map = "map1", plus = false, challengeIndex = nil }
	self.tab = "research"
	self.parties = { list = {}, mine = nil }
	self.boards = {}
	self:build()
	return self
end

local function wrapText(str: string, size: number, color: Color3?, order: number?, parent: Instance?)
	return text(str, size, color or C.muted, Ui.FONT, {
		TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -6, 0, 0), LayoutOrder = order or 0, Parent = parent,
	})
end
local function section(title: string, order: number, parent: Instance)
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent })
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = f
	text(title, 15, C.ink, Ui.HEAVY, { LayoutOrder = 0, Parent = f })
	return f
end

-- A tiny drawing of a map's road for the map picker.
local function mapPreview(map, w: number, h: number)
	local f = new("Frame", { BackgroundColor3 = Ui.hex("#e9c79a"), Size = UDim2.fromOffset(w, h), ClipsDescendants = true })
	Ui.corner(6).Parent = f
	local s = w / 720
	for i = 2, #map.road do
		local a, b = map.road[i - 1], map.road[i]
		local dx, dy = (b.x - a.x) * s, (b.y - a.y) * s
		local len = math.sqrt(dx * dx + dy * dy)
		new("Frame", {
			BackgroundColor3 = Ui.hex("#8c6a44"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((a.x + b.x) / 2 * s, (a.y + b.y) / 2 * s), Size = UDim2.fromOffset(len + 4, math.max(3, 28 * s)),
			Rotation = math.deg(math.atan2(dy, dx)), Parent = f,
		})
	end
	local base = new("Frame", { BackgroundColor3 = Ui.hex("#4b7a19"), BorderSizePixel = 0, Position = UDim2.fromOffset(map.base.x * s, (map.base.y + 12) * s), Size = UDim2.fromOffset(100 * s, 70 * s), Parent = f })
	Ui.corner(2).Parent = base
	return f
end

function LobbyUI:build()
	local root = new("Frame", { Name = "Lobby", BackgroundColor3 = C.bg, BackgroundTransparency = 0.08, Size = UDim2.fromScale(1, 1), Parent = self.ctx.gui })
	self.root = root
	-- header: title + account strip
	local top = new("Frame", { BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 72), Parent = root })
	Ui.stroke(C.line).Parent = top
	Ui.pad(18, 10).Parent = top
	text("ONSLAUGHT 2", 30, C.gold, Ui.HEAVY, { Position = UDim2.fromOffset(0, 2), Parent = top })
	text("Destroy them all. Build, kill, upgrade, combo.", 13, C.muted, Ui.FONT, { Position = UDim2.fromOffset(2, 36), Parent = top })
	local acct = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 560, 1, 0), Parent = top })
	Ui.list(Enum.FillDirection.Horizontal, 22, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = acct
	local lvlF = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 190, 1, 0), LayoutOrder = 1, Parent = acct })
	Ui.list(Enum.FillDirection.Vertical, 4, nil, Enum.VerticalAlignment.Center).Parent = lvlF
	self.levelL = text("LEVEL 1", 12, C.muted, Ui.BOLD, { LayoutOrder = 1, Parent = lvlF })
	local xb
	xb, self.xpFill = Ui.bar(C.gold, 6)
	xb.LayoutOrder = 2
	xb.Parent = lvlF
	self.xpL = text("0 / 140 XP", 11, C.dim, Ui.MONO, { LayoutOrder = 3, Parent = lvlF })
	local f
	f, self.intelV = Ui.stat("Intel", "0", C.info, 90)
	f.LayoutOrder = 2
	f.Parent = acct
	f, self.prestigeV = Ui.stat("Clearance", "0", C.ink, 90)
	f.LayoutOrder = 3
	f.Parent = acct

	-- body
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72), Parent = root })
	Ui.pad(16).Parent = body
	local play = Ui.panel({ Size = UDim2.new(0.56, -8, 1, 0), Parent = body })
	Ui.pad(14).Parent = play
	self.playS = Ui.scroll({ Size = UDim2.fromScale(1, 1), Parent = play })
	Ui.list(Enum.FillDirection.Vertical, 12).Parent = self.playS
	local side = Ui.panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.44, -8, 1, 0), Parent = body })
	Ui.pad(14).Parent = side
	self.tabsF = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = side })
	Ui.list(Enum.FillDirection.Horizontal, 6).Parent = self.tabsF
	self.sideS = Ui.scroll({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), Parent = side })
	Ui.list(Enum.FillDirection.Vertical, 8).Parent = self.sideS
	self:render()
end

function LobbyUI:setVisible(v: boolean)
	self.root.Visible = v
end
function LobbyUI:setParties(p)
	self.parties = p
	self:renderPlay()
end
function LobbyUI:render()
	self:renderHeader()
	self:renderPlay()
	self:renderSide()
end

function LobbyUI:renderHeader()
	local p = self.ctx.profile()
	if not p then
		return
	end
	self.levelL.Text = "LEVEL " .. p.level
	self.xpFill.Size = UDim2.fromScale(math.clamp(p.xp / math.max(1, p.xpNeed), 0, 1), 1)
	self.xpL.Text = string.format("%s / %s XP", Ui.fmt(p.xp), Ui.fmt(p.xpNeed))
	self.intelV.Text = Ui.fmt(p.intel)
	self.prestigeV.Text = tostring(p.prestige)
end

-- ================================================================ play column
function LobbyUI:renderPlay()
	local S = self.playS
	Ui.clear(S)
	local p = self.ctx.profile()
	local passes = p and p.passes or {}
	local ch = self.choice
	-- party (if in one)
	local myParty
	for _, party in self.parties.list do
		if party.leader == self.parties.mine then
			myParty = party
		end
	end
	if myParty then
		local sec = section("Your party", 1, S)
		local names = {}
		for _, m in myParty.members do
			table.insert(names, m.name .. (if m.userId == myParty.leader then " (leader)" else ""))
		end
		wrapText(table.concat(names, " · ") .. string.format("   %d/4", #myParty.members), 13, C.ink, 1, sec)
		local s = myParty.settings or {}
		wrapText(string.format("%s · %s · %s map", if s.plus then "Onslaught+" else "Classic", Rules.runLabel(GAME, s.mode, s.challengeIndex), GAME.maps[s.map] and GAME.maps[s.map].name or "?"), 12, C.muted, 2, sec)
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3, Parent = sec })
		Ui.list(Enum.FillDirection.Horizontal, 8).Parent = row
		if myParty.leader == self.ctx.userId then
			button("Start ▶", "primary", function()
				local r = self.ctx.request("partyStart")
				if r and not r.ok then
					self.ctx.toast(r.msg or "Couldn't start", C.bad)
				end
			end, { Parent = row })
			button("Use selected settings", nil, function()
				self.ctx.request("partySettings", ch)
			end, { Parent = row })
		end
		button("Leave party", "danger", function()
			self.ctx.request("partyLeave")
		end, { Parent = row })
	end
	-- mode: Classic or Onslaught+
	local secM = section("Game", 2, S)
	local kindRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = secM })
	Ui.list(Enum.FillDirection.Horizontal, 6).Parent = kindRow
	button("Classic (1:1)", if not ch.plus then "primary" else "ghost", function()
		ch.plus = false
		self:renderPlay()
	end, { Parent = kindRow })
	button("Onslaught+", if ch.plus then "primary" else "ghost", function()
		ch.plus = true
		self:renderPlay()
	end, { Parent = kindRow })
	wrapText(if ch.plus then "New towers, combos, research and boosts. Your account level unlocks the new towers." else "The original Onslaught 2.2, exactly. Only cosmetic and convenience passes apply.", 12, C.muted, 2, secM)
	local tiles = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = secM })
	Ui.grid(UDim2.new(0.25, -6, 0, 56), 6).Parent = tiles
	for i, m in Rules.MODES do
		local open = m.id == "challenge" or (p ~= nil and Rules.modeOpen(p, passes, m.id))
		local on = (m.id == "challenge" and ch.challengeIndex ~= nil) or (ch.challengeIndex == nil and ch.mode == m.id)
		local b = new("TextButton", { BackgroundColor3 = if on then Ui.hex("#2a2410") else C.panel2, Text = "", AutoButtonColor = open, LayoutOrder = i, Parent = tiles })
		Ui.corner(8).Parent = b
		Ui.stroke(if on then C.gold else C.line).Parent = b
		Ui.pad(8, 6).Parent = b
		text((if open then "" else "🔒 ") .. m.label, 14, if open then C.ink else C.dim, Ui.BOLD, { Parent = b })
		text(m.sub, 10, C.muted, Ui.FONT, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = b })
		b.Activated:Connect(function()
			if not open then
				self.ctx.toast("Locked. " .. m.sub .. " (or get Instant Clearance).", C.muted)
				return
			end
			if m.id == "challenge" then
				ch.challengeIndex = ch.challengeIndex or 1
			else
				ch.mode, ch.challengeIndex = m.id, nil
			end
			self:renderPlay()
		end)
	end
	-- challenges
	if ch.challengeIndex then
		local secC = section("Challenges", 3, S)
		local list = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = secC })
		Ui.grid(UDim2.new(0.5, -4, 0, 46), 6).Parent = list
		for i, c in GAME.challenges do
			local won = p and p.chal and p.chal[tostring(i)]
			local obj = if c.objective then (if string.sub(c.objective, 1, 1) == "w" then "Beat " .. string.sub(c.objective, 3) .. " waves" else "Make " .. string.sub(c.objective, 3) .. " kills") else "Last as long as you can"
			local on = ch.challengeIndex == i
			local b = new("TextButton", { BackgroundColor3 = if on then Ui.hex("#2a2410") else C.panel2, Text = "", LayoutOrder = i, Parent = list })
			Ui.corner(8).Parent = b
			Ui.stroke(if on then C.gold else C.line).Parent = b
			Ui.pad(8, 5).Parent = b
			text((if won then "✔ " else "") .. c.name, 13, C.ink, Ui.BOLD, { Parent = b })
			text(string.format("%s · %s · $%s%s%s", obj, c.difficulty, Ui.fmt(c.cash), if c.timelimit then " · " .. math.floor(c.timelimit / 60) .. " min" else "", if c.turretlimit then " · " .. c.turretlimit .. " turrets" else ""), 10, C.muted, Ui.FONT, { Position = UDim2.fromOffset(0, 18), Parent = b })
			b.Activated:Connect(function()
				ch.challengeIndex = i
				self:renderPlay()
			end)
		end
	end
	-- maps
	local secMap = section("Map", 4, S)
	local maps = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = secMap })
	Ui.grid(UDim2.fromOffset(150, 128), 8).Parent = maps
	for i, key in GAME.mapOrder do
		local m = GAME.maps[key]
		local on = ch.map == key
		local b = new("TextButton", { BackgroundColor3 = if on then Ui.hex("#2a2410") else C.panel2, Text = "", LayoutOrder = i, Parent = maps })
		Ui.corner(8).Parent = b
		Ui.stroke(if on then C.gold else C.line, if on then 2 else 1).Parent = b
		local prev = mapPreview(m, 138, 92)
		prev.Position = UDim2.fromOffset(6, 6)
		prev.Parent = b
		local best = p and p.best and p.best[Rules.bestKey({ plus = ch.plus, challengeIndex = ch.challengeIndex, mode = ch.mode, map = key })]
		text(m.name, 12, C.ink, Ui.BOLD, { Position = UDim2.fromOffset(8, 101), Parent = b })
		if best then
			text("best " .. best, 10, C.gold, Ui.MONO, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 103), Parent = b })
		end
		b.Activated:Connect(function()
			ch.map = key
			self:renderPlay()
		end)
	end
	-- play buttons + open parties
	local secP = section("Play", 5, S)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = secP })
	Ui.list(Enum.FillDirection.Horizontal, 8).Parent = row
	button("Play solo ▶", "primary", function()
		local r = self.ctx.request("solo", ch)
		if r and not r.ok then
			self.ctx.toast(r.msg or "Couldn't start", C.bad)
		end
	end, { TextSize = 16, Size = UDim2.fromOffset(0, 40), Parent = row })
	if not myParty then
		button("Create party", nil, function()
			self.ctx.request("partyCreate", ch)
			self.ctx.request("partySettings", ch)
		end, { Size = UDim2.fromOffset(0, 40), Parent = row })
	end
	local open = 0
	for _, party in self.parties.list do
		if party.leader ~= self.parties.mine and party.open and #party.members < 4 then
			open += 1
			local s = party.settings or {}
			local r = new("Frame", { BackgroundColor3 = C.panel2, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 10 + open, Parent = secP })
			Ui.corner(8).Parent = r
			Ui.pad(10, 0).Parent = r
			text(string.format("<b>%s</b>'s party  ·  %d/4  ·  %s %s", party.leaderName, #party.members, if s.plus then "Onslaught+" else "Classic", Rules.runLabel(GAME, s.mode, s.challengeIndex)), 13, C.ink, Ui.FONT, { Position = UDim2.fromOffset(0, 11), Parent = r })
			button("Join", nil, function()
				local res = self.ctx.request("partyJoin", party.leader)
				if res and not res.ok then
					self.ctx.toast(res.msg or "Couldn't join", C.bad)
				end
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(0, 28), Parent = r })
		end
	end
	if open == 0 then
		wrapText("No open parties in this server. Create one and your friends can join it here.", 12, C.dim, 9, secP)
	end
end

-- ================================================================ side tabs
local TABS = { { "research", "Research" }, { "quests", "Quests" }, { "store", "Store" }, { "boards", "Leaderboards" }, { "profile", "Profile" } }
function LobbyUI:renderSide()
	Ui.clear(self.tabsF)
	for i, t in TABS do
		button(t[2], if self.tab == t[1] then "primary" else "ghost", function()
			self.tab = t[1]
			self:renderSide()
		end, { LayoutOrder = i, TextSize = 12, Size = UDim2.fromOffset(0, 28), Parent = self.tabsF })
	end
	local S = self.sideS
	Ui.clear(S)
	local p = self.ctx.profile()
	if not p then
		wrapText("Loading your profile…", 13, C.muted, 1, S)
		return
	end
	if self.tab == "research" then
		wrapText("Spend Intel on small, permanent bonuses. They apply in Onslaught+ only; Classic stays 1:1.", 12, C.muted, 0, S)
		for i, r in p.research do
			local row = new("Frame", { BackgroundColor3 = C.panel2, Size = UDim2.new(1, -6, 0, 52), LayoutOrder = i, Parent = S })
			Ui.corner(8).Parent = row
			Ui.pad(10, 6).Parent = row
			text(string.format("%s  <font color='#98a1b0' size='12'>%d/%d</font>", r.label, r.level, r.max), 14, C.ink, Ui.BOLD, { Parent = row })
			text(r.desc, 11, C.muted, Ui.FONT, { Position = UDim2.fromOffset(0, 20), Parent = row })
			if r.cost then
				local b = button(Ui.fmt(r.cost) .. " Intel", if p.intel >= r.cost then "primary" else nil, function()
					local res = self.ctx.request("research", r.id)
					if res and not res.ok then
						self.ctx.toast("Not enough Intel.", C.bad)
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), TextSize = 12, Size = UDim2.fromOffset(0, 30), Parent = row })
				b.AutoButtonColor = p.intel >= r.cost
			else
				text("MAX", 12, C.good, Ui.BOLD, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Parent = row })
			end
		end
		if p.canPrestige then
			button("Clearance: reset to level 1 for +5% XP and Intel forever", "primary", function()
				self.ctx.request("prestige")
			end, { LayoutOrder = 100, TextSize = 12, Parent = S })
		end
	elseif self.tab == "quests" then
		wrapText("Three new quests every day (UTC). Progress counts in both modes.", 12, C.muted, 0, S)
		for i, q in p.quests do
			local row = new("Frame", { BackgroundColor3 = C.panel2, Size = UDim2.new(1, -6, 0, 64), LayoutOrder = i, Parent = S })
			Ui.corner(8).Parent = row
			Ui.pad(10, 6).Parent = row
			text((if q.done then "✔ " else "") .. q.text, 13, if q.done then C.good else C.ink, Ui.BOLD, { Parent = row })
			text(string.format("+%d Intel  ·  +%d XP", q.intel, q.xp), 11, C.info, Ui.FONT, { Position = UDim2.fromOffset(0, 20), Parent = row })
			local bar, fill = Ui.bar(C.gold, 5)
			bar.Position = UDim2.fromOffset(0, 42)
			bar.Size = UDim2.new(1, -90, 0, 5)
			bar.Parent = row
			fill.Size = UDim2.fromScale(math.clamp(q.progress / q.goal, 0, 1), 1)
			if not q.done then
				button("Reroll", "ghost", function()
					local res = self.ctx.request("reroll", i)
					if res and not res.ok then
						self.ctx.toast(res.msg or "Can't reroll", C.bad)
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), TextSize = 11, Size = UDim2.fromOffset(0, 26), Parent = row })
			end
		end
		wrapText(string.format("Rerolls: %d%s", p.rerolls or 0, if p.passes.vip then " (+1 free a day with VIP)" else ""), 12, C.dim, 50, S)
	elseif self.tab == "store" then
		local cat = p.catalog
		text("Game passes", 15, C.ink, Ui.HEAVY, { LayoutOrder = 0, Parent = S })
		for i, g in cat.passes do
			local row = new("Frame", { BackgroundColor3 = C.panel2, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = S })
			Ui.corner(8).Parent = row
			Ui.pad(10, 8).Parent = row
			Ui.list(Enum.FillDirection.Vertical, 2).Parent = row
			text(string.format("%s  <font color='#98a1b0' size='11'>%s</font>", g.name, if g.classic then "Classic + Plus" else "Onslaught+"), 14, C.ink, Ui.BOLD, { LayoutOrder = 1, Parent = row })
			text(g.effect, 11, C.muted, Ui.FONT, { LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -110, 0, 0), Parent = row })
			if g.owned then
				text("OWNED", 12, C.good, Ui.BOLD, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Parent = row })
			else
				button(string.format("R$ %d", g.robux), if g.onSale then "primary" else nil, function()
					local res = self.ctx.request("buyPass", g.id)
					if res and not res.ok then
						self.ctx.toast(res.msg or "Not on sale yet", C.muted)
					end
				end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), TextSize = 12, Size = UDim2.fromOffset(0, 28), Parent = row })
			end
		end
		text("Account items", 15, C.ink, Ui.HEAVY, { LayoutOrder = 50, Parent = S })
		local n = 50
		for _, prod in cat.products do
			if not prod.plusOnly then
				n += 1
				local row = new("Frame", { BackgroundColor3 = C.panel2, Size = UDim2.new(1, -6, 0, 44), LayoutOrder = n, Parent = S })
				Ui.corner(8).Parent = row
				Ui.pad(10, 6).Parent = row
				text(prod.name, 13, C.ink, Ui.BOLD, { Parent = row })
				text(prod.effect, 10, C.muted, Ui.FONT, { Position = UDim2.fromOffset(0, 18), Parent = row })
				button(string.format("R$ %d", prod.robux), if prod.onSale then "primary" else nil, function()
					local res = self.ctx.request("buyProduct", prod.id)
					if res and not res.ok then
						self.ctx.toast(res.msg or "Not on sale yet", C.muted)
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), TextSize = 12, Size = UDim2.fromOffset(0, 28), Parent = row })
			end
		end
		wrapText("In-game boosts (Supply Drops, Extra Life, Second Chance, Airstrike, Time Freeze) are sold from the menu during an Onslaught+ run. A run that uses one is marked assisted and stays off the Onslaught+ leaderboard. Classic ignores every boost and every balance pass.", 11, C.dim, 99, S)
	elseif self.tab == "boards" then
		for i, b in { { "classic", "Best wave: Classic" }, { "plus", "Best wave: Onslaught+" }, { "kills", "Lifetime kills" } } do
			local sec = section(b[2], i, S)
			local rows = self.boards[b[1]]
			if not rows then
				wrapText("Loading…", 12, C.dim, 1, sec)
				task.spawn(function()
					self.boards[b[1]] = self.ctx.request("leaderboard", b[1]) or {}
					if self.tab == "boards" then
						self:renderSide()
					end
				end)
			elseif #rows == 0 then
				wrapText("No scores yet. Be the first.", 12, C.dim, 1, sec)
			else
				for j, r in rows do
					if j > 10 then
						break
					end
					text(string.format("<font color='#6b7383'>%2d</font>  %s  <font color='#ffcf4a'>%s</font>", r.rank, r.name, r.value), 13, C.ink, Ui.MONO, { LayoutOrder = j, Parent = sec })
				end
			end
		end
	elseif self.tab == "profile" then
		local lines = {
			string.format("Games played: <b>%d</b>  ·  wins: <b>%d</b>", p.games or 0, p.wins or 0),
			string.format("Lifetime kills: <b>%s</b>", p.lifetimeKills),
			string.format("Lifetime XP: <b>%s</b>", p.lifetimeXP),
			string.format("Lifetime bounty: <b>$%s</b>", p.lifetimeBounty),
		}
		if p.xpBoostLeft > 0 then
			table.insert(lines, string.format("<font color='#ffcf4a'>XP Boost: %d min left</font>", math.ceil(p.xpBoostLeft / 60)))
		end
		if p.partyBoostLeft > 0 then
			table.insert(lines, string.format("<font color='#6fb6ff'>Party Boost in this server: %d min left</font>", math.ceil(p.partyBoostLeft / 60)))
		end
		text(table.concat(lines, "\n"), 13, C.ink, Ui.FONT, { LayoutOrder = 1, Parent = S })
		local sec = section("Turret skin", 2, S)
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = sec })
		Ui.list(Enum.FillDirection.Horizontal, 6).Parent = row
		for i, sk in { { "default", "Standard", true }, { "gold", "Gold (VIP)", p.passes.vip }, { "retro", "Retro", p.passes.skins_retro }, { "neon", "Neon", p.passes.skins_neon } } do
			button(sk[2], if p.skin == sk[1] then "primary" elseif sk[3] then nil else "ghost", function()
				local res = self.ctx.request("skin", sk[1])
				if res and not res.ok then
					self.ctx.toast(res.msg or "Locked", C.muted)
				end
			end, { LayoutOrder = i, TextSize = 12, Parent = row })
		end
		local credits = {}
		for id, n in p.credits or {} do
			if n > 0 then
				table.insert(credits, id .. " ×" .. n)
			end
		end
		if #credits > 0 then
			wrapText("Boost credits (use them in an Onslaught+ run): " .. table.concat(credits, ", "), 12, C.info, 3, S)
		end
	end
end

function LobbyUI:destroy()
	self.root:Destroy()
end

return LobbyUI
