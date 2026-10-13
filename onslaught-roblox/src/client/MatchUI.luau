--[[
	The in-match interface and controls, laid out like the HTML build:
	  top bar     wave + next-wave timer + Send | lives, CASH (largest), kills | speed, pause, menu
	  right panel Build palette (tabs, tiles with price, hotkey, unlock progress) and the selected turret
	              (stats with upgrade buttons, targeting, cone, link, Combonly, queue, move, sell)
	  overlays    menu (settings, boosts, blueprints), revive offer, end screen; toasts and a mode hint
	Every command goes to the server (ctx.send); nothing here changes game state locally.
]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Engine = require(ReplicatedStorage.Shared.Onslaught.Engine)
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local C, new, text, button = Ui.C, Ui.new, Ui.text, Ui.button
local MatchUI = {}
MatchUI.__index = MatchUI

local TOP, SIDE = 64, 330
local TABS = { { "turrets", "Turrets" }, { "mods", "Modifiers" }, { "super", "Super" }, { "plus", "Plus" } }
local STAT_KEYS = { damage = "Q", range = "W", rate = "E" }
local SPREAD_NEXT = { [50] = 30, [30] = 15 }
local SHIFT_DIGITS = { ["!"] = 1, ["@"] = 2, ["#"] = 3, ["$"] = 4, ["%"] = 5, ["^"] = 6, ["&"] = 7, ["*"] = 8, ["("] = 9 }
local DIGIT_CODES = {
	[0] = Enum.KeyCode.Zero, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
	Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}
local MODE_HINTS = {
	airstrike = "Click where the Airstrike lands.",
	move = "Click where to move it ($500). Esc cancels.",
	join = "Click a turret to link to this Targeter. Esc cancels.",
	dir = "Click the direction to aim the cone. Esc cancels.",
	focus = "Click an attacker: every turret targets it. Esc cancels.",
}

local function tabOf(D, k: string): string
	local d = D.turrets[k]
	if d.tab then
		return d.tab
	end
	if d.type == "modifier" then
		return "mods"
	end
	if k == "Blue" or k == "Green" or k == "Red" or k == "Yellow" then
		return "turrets"
	end
	return "super"
end
local function swatch(kind: string, d): Color3
	if C[kind] then
		return C[kind]
	end
	if d.type == "modifier" then
		return if string.find(kind, "Damage") then C.Red elseif string.find(kind, "Range") then C.Green elseif kind == "Beacon" then C.Gold else C.Blue
	end
	local other = { Sniper = "#565656", Fusion = "#7a3cc2", Railgun = "#2d6a7a", Targeter = "#ff4d4d", Combonly = "#888888", Vault = "#e0b23a", Orbital = "#e8edf2" }
	return Ui.hex(other[kind] or "#888888")
end
local function keyCodeFor(key: string?): (Enum.KeyCode?, boolean)
	if not key or key == "" then
		return nil, false
	end
	local shifted = SHIFT_DIGITS[key]
	if shifted then
		return DIGIT_CODES[shifted], true
	end
	local n = tonumber(key)
	if n then
		return DIGIT_CODES[n], false
	end
	local ok, code = pcall(function()
		return (Enum.KeyCode :: any)[string.upper(key)]
	end)
	return if ok then code else nil, false
end
local function describe(D, k: string): string
	local d = D.turrets[k]
	if d.desc then
		return d.desc
	end
	if d.type == "modifier" then
		local p = {}
		if d.modify.range then
			table.insert(p, "+" .. d.modify.range .. " range")
		end
		for _, s in { "damage", "range", "rate" } do
			local v = d.modify[s .. "_mult"]
			if v and v ~= 0 then
				table.insert(p, string.format("%s%d%% %s", if v > 0 then "+" else "", math.floor(v * 100 + 0.5), s))
			end
		end
		return "Turrets within " .. d.range .. "px get " .. table.concat(p, ", ") .. "."
	end
	local special = {
		Targeter = "Paints the fastest attacker; up to 3 linked turrets fire at it, even outside their own range.",
		Combonly = "Absorbs the turrets a combo needs and becomes a permanent combo cannon.",
		Fusion = "Greens and yellows in range fire into it; it stores their power and releases it every 6 s.",
		Railgun = "A 900px beam that hits everything on it.",
	}
	return special[k] or string.format("Damage %s, range %d, %s/min.", Ui.fmt(d.damage), d.range, Ui.fmt(d.rate))
end

-- ================================================================ construction
-- ctx = { gui, board, D, info, pid, send(op, ...), request(op, ...) -> any, profile() -> view, onLeave() }
function MatchUI.new(ctx)
	local self = setmetatable({}, MatchUI)
	self.ctx, self.D, self.board = ctx, ctx.D, ctx.board
	self.header = nil
	self.turrets, self.byId = {}, {}
	self.dyn = {}
	self.tab = "turrets"
	self.buildKind, self.sel, self.mode = nil, nil, nil
	self.showRanges = false
	self.connections = {}
	self.selKey = ""
	-- a local engine game: the road and mines for placement previews (Engine.canBuildAt)
	self.probe = Engine.newGame(self.D, { map = ctx.info.map, mode = ctx.info.mode, players = { "probe" } })
	self.probe.turrets = {}
	self:build()
	self:bindInput()
	return self
end

function MatchUI:build()
	local gui = self.ctx.gui
	local root = new("Frame", { Name = "Match", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	self.root = root
	-- top bar
	local top = new("Frame", { Name = "Top", BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, TOP), Parent = root })
	Ui.stroke(C.line).Parent = top
	local left = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.38, 0, 1, 0), Parent = top })
	Ui.pad(14, 6).Parent = left
	Ui.list(Enum.FillDirection.Horizontal, 14, nil, Enum.VerticalAlignment.Center).Parent = left
	local waveF
	waveF, self.waveV = Ui.stat("Wave", "0", C.ink, 64)
	waveF.LayoutOrder = 1
	waveF.Parent = left
	local timer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 150, 1, 0), LayoutOrder = 2, Parent = left })
	Ui.list(Enum.FillDirection.Vertical, 4, nil, Enum.VerticalAlignment.Center).Parent = timer
	self.nextL = text("NEXT WAVE", 11, C.muted, Ui.BOLD, { LayoutOrder = 1, Parent = timer })
	local bar
	bar, self.waveBar = Ui.bar(C.info, 6)
	bar.LayoutOrder = 2
	bar.Parent = timer
	self.nextV = text("20.0s", 12, C.muted, Ui.MONO, { LayoutOrder = 3, Parent = timer })
	self.sendB = button("Send ▶", "primary", function()
		self.ctx.send("send")
	end, { LayoutOrder = 3, Parent = left })
	local mid = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 360, 1, 0), Parent = top })
	Ui.list(Enum.FillDirection.Horizontal, 22, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = mid
	local f
	f, self.livesV = Ui.stat("Lives", "10", C.ink, 70)
	f.LayoutOrder = 1
	f.Parent = mid
	f, self.cashV = Ui.stat("Cash", "$0", C.gold, 130)
	self.cashV.TextSize = 28
	f.LayoutOrder = 2
	f.Parent = mid
	f, self.killsV = Ui.stat("Kills", "0", C.ink, 90)
	f.LayoutOrder = 3
	f.Parent = mid
	local right = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.3, 0, 1, 0), Parent = top })
	Ui.pad(14, 6).Parent = right
	Ui.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = right
	self.objectiveL = text("", 12, C.muted, Ui.BOLD, { LayoutOrder = 0, Parent = right })
	self.speedB = button("1×", nil, function()
		self:cycleSpeed()
	end, { LayoutOrder = 1, Parent = right })
	self.pauseB = button("❚❚", nil, function()
		if self:isHost() then
			self.ctx.send("pause", not (self.header and self.header.paused))
		end
	end, { LayoutOrder = 2, Parent = right })
	button("☰", nil, function()
		self:openMenu()
	end, { LayoutOrder = 3, Parent = right })

	-- right panel
	local side = Ui.panel({ Name = "Side", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, TOP + 10), Size = UDim2.new(0, SIDE, 1, -TOP - 20), Parent = root })
	Ui.pad(10).Parent = side
	Ui.list(Enum.FillDirection.Vertical, 8).Parent = side
	local ph = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = side })
	text("Build", 16, C.ink, Ui.HEAVY, { Parent = ph })
	text("hotkeys shown", 11, C.dim, Ui.FONT, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = ph })
	self.tabsF = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 2, Parent = side })
	Ui.list(Enum.FillDirection.Horizontal, 6).Parent = self.tabsF
	self.paletteF = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = side })
	Ui.grid(UDim2.new(0.25, -5, 0, 74), 6).Parent = self.paletteF
	new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 4, Parent = side })
	self.selF = Ui.scroll({ Size = UDim2.new(1, 0, 1, -230), LayoutOrder = 5, Parent = side })
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = self.selF
	self.side = side

	-- toasts, mode hint
	self.toastsF = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -SIDE / 2, 0, TOP + 12), Size = UDim2.fromOffset(420, 200), Parent = root })
	Ui.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = self.toastsF
	self.hint = text("", 14, C.ink, Ui.BOLD, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -SIDE / 2, 1, -18), BackgroundTransparency = 0.15,
		BackgroundColor3 = C.panel, Visible = false, Parent = root,
	})
	Ui.pad(12, 8).Parent = self.hint
	Ui.corner(8).Parent = self.hint
	self.overlay = new("Frame", { Name = "Overlay", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Parent = root })
	self:renderPalette()
	self:renderSel()
end

function MatchUI:insets()
	return { TOP, SIDE + 20, 0, 10 }
end
function MatchUI:isHost(): boolean
	return self.header ~= nil and self.header.host == self.ctx.pid
end
function MatchUI:cash(): number
	return self.header and self.header.cash[self.ctx.pid] or 0
end
function MatchUI:passes()
	local p = self.ctx.profile()
	return p and p.passes or {}
end

-- ================================================================ palette
function MatchUI:renderPalette()
	local D = self.D
	Ui.clear(self.tabsF)
	local have = {}
	for _, k in D.buildOrder do
		have[tabOf(D, k)] = true
	end
	for i, t in TABS do
		if have[t[1]] then
			local on = self.tab == t[1]
			local b = button(t[2], if on then "primary" else "ghost", function()
				self.tab = t[1]
				self:renderPalette()
			end, { LayoutOrder = i, TextSize = 12, Size = UDim2.fromOffset(0, 26) })
			b.Parent = self.tabsF
		end
	end
	Ui.clear(self.paletteF)
	self.tiles = {}
	local order = 0
	for _, k in D.buildOrder do
		if tabOf(D, k) ~= self.tab then
			continue
		end
		order += 1
		local d = D.turrets[k]
		local tile = new("TextButton", { BackgroundColor3 = C.panel2, Text = "", AutoButtonColor = true, LayoutOrder = order, Parent = self.paletteF })
		Ui.corner(8).Parent = tile
		local st = Ui.stroke(C.line)
		st.Parent = tile
		local sw = new("Frame", { BackgroundColor3 = swatch(k, d), Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0.5, -13, 0, 6), Parent = tile })
		Ui.corner(13).Parent = sw
		Ui.stroke(Ui.hex("#4b4f55"), 1.5).Parent = sw
		text(d.label, 10, C.ink, Ui.BOLD, {
			AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -4, 0, 24), Position = UDim2.new(0, 2, 0, 33), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 0.9, Parent = tile,
		})
		text(Ui.money(d.cost), 11, C.gold, Ui.MONO, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Parent = tile })
		text(d.key or "", 10, C.dim, Ui.MONO, { Position = UDim2.fromOffset(4, 2), Parent = tile })
		local lock = new("Frame", { Name = "Lock", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3, Parent = tile })
		Ui.corner(8).Parent = lock
		local lockL = text("", 10, C.ink, Ui.BOLD, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 4, Parent = lock })
		local lb, lf = Ui.bar(C.gold, 4)
		lb.Position = UDim2.new(0, 6, 1, -10)
		lb.Size = UDim2.new(1, -12, 0, 4)
		lb.ZIndex = 4
		lf.ZIndex = 5
		lb.Parent = lock
		tile.Activated:Connect(function()
			if not (self.header and self.header.unlocked[k]) then
				return
			end
			self.buildKind = if self.buildKind == k then nil else k
			self:setMode(nil)
			self:select(nil)
		end)
		self.tiles[k] = { tile = tile, stroke = st, lock = lock, lockL = lockL, lockFill = lf }
	end
	self:refreshTiles()
end
function MatchUI:refreshTiles()
	local h = self.header
	if not self.tiles then
		return
	end
	for k, v in self.tiles do
		local d = self.D.turrets[k]
		local open = h ~= nil and h.unlocked[k] == true
		v.lock.Visible = not open
		if not open then
			if d.levelLocked and d.levelLocked ~= 0 then
				v.lockL.Text = "🔒 Level " .. d.levelLocked
				v.lockFill.Size = UDim2.fromScale(0, 1)
			else
				v.lockL.Text = "🔒 " .. Ui.fmt(d.unlock) .. " kills"
				v.lockFill.Size = UDim2.fromScale(math.clamp((h and h.kills or 0) / math.max(1, d.unlock), 0, 1), 1)
			end
		end
		local active = self.buildKind == k
		v.stroke.Color = if active then C.gold elseif open and self:cash() >= d.cost then C.line else Ui.hex("#3a2a2a")
		v.stroke.Thickness = if active then 2 else 1
	end
end

-- ================================================================ selection panel
function MatchUI:select(id: number?)
	self.sel = id
	self.selKey = ""
	self.combonlyOpts = nil
	local t = id and self.byId[id]
	if t and t.type == "combonly" and not t.combo then
		task.spawn(function()
			local opts = self.ctx.request("combonlyOptions", id)
			if self.sel == id then
				self.combonlyOpts = opts
				self.selKey = ""
				self:renderSel()
			end
		end)
	end
	self:renderSel()
end

local function upMax(D, kind: string, stat: string): number
	local up = D.turrets[kind].up and D.turrets[kind].up[stat]
	return if up and up.cost then #up.cost else 0
end
local function upCost(D, t, stat: string): number?
	local up = D.turrets[t.kind].up and D.turrets[t.kind].up[stat]
	if up and up.cost and t.lvl[stat] < #up.cost then
		return up.cost[t.lvl[stat] + 1]
	end
	return nil
end
MatchUI.upMax = upMax

function MatchUI:renderSel()
	local D = self.D
	local t = self.sel and self.byId[self.sel]
	local cash = self:cash()
	if not t then
		self.sel = nil
		local key = "none:" .. tostring(self.buildKind)
		if key == self.selKey then
			return
		end
		self.selKey = key
		Ui.clear(self.selF)
		if self.buildKind then
			text(D.turrets[self.buildKind].label, 16, C.ink, Ui.HEAVY, { LayoutOrder = 1, Parent = self.selF })
			text(describe(D, self.buildKind), 12, C.muted, Ui.FONT, { LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), Parent = self.selF })
			text("Click the map to build. Hold <b>Shift</b> to keep building. <b>Esc</b> cancels.", 12, C.dim, Ui.FONT, { LayoutOrder = 3, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), Parent = self.selF })
		else
			text("Pick a turret, then click the map to build it. Click a turret to upgrade, retarget, move or sell it.", 13, C.muted, Ui.FONT, { LayoutOrder = 1, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), Parent = self.selF })
		end
		return
	end
	local d = D.turrets[t.kind]
	local dyn = self.dyn[t.id] or {}
	local mine = t.owner == self.ctx.pid or #(self.ctx.info.roster or {}) <= 1
	local q = self.queues and self.queues[t.id]
	local key = table.concat({
		t.id, t.lvl.damage, t.lvl.range, t.lvl.rate, math.floor(cash), math.floor(t.eff.damage), math.floor(t.eff.range), math.floor(t.eff.rate),
		t.targetMode, tostring(t.reacquire), tostring(t.dir ~= nil), tostring(dyn.ready), tostring(dyn.freak), tostring(t.joins), tostring(t.combo),
		tostring(self.mode), t.kills, tostring(self.combonlyOpts ~= nil), tostring(q and #q),
	}, "|")
	if key == self.selKey then
		return
	end
	self.selKey = key
	local F = self.selF
	Ui.clear(F)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	-- header
	local hdr = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = nextOrder(), Parent = F })
	local sw = new("Frame", { BackgroundColor3 = swatch(t.kind, d), Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(0, 3), Parent = hdr })
	Ui.corner(17).Parent = sw
	text(d.label, 16, C.ink, Ui.HEAVY, { Position = UDim2.fromOffset(44, 2), Parent = hdr })
	local ownerName = ""
	for _, r in self.ctx.info.roster or {} do
		if r.pid == t.owner then
			ownerName = r.name
		end
	end
	text(string.format("%s%d kills · worth %s", if #(self.ctx.info.roster or {}) > 1 then ownerName .. " · " else "", t.kills, Ui.money(t.value)), 12, C.muted, Ui.FONT, { Position = UDim2.fromOffset(44, 22), Parent = hdr })
	-- stat rows
	local L = d.statLabels or {}
	local function row(stat: string, label: string, base: number, eff: number, unit: string?)
		local m = upMax(D, t.kind, stat)
		local c = upCost(D, t, stat)
		local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = nextOrder(), Parent = F })
		text(string.upper(label), 11, C.muted, Ui.BOLD, { Position = UDim2.fromOffset(0, 2), Parent = r })
		local diff = eff - base
		local bonus = if math.abs(diff) > 1e-9 then string.format(' <font color="#%s" size="12">%s%s</font>', if diff < 0 then "ff5f57" else "6ad46a", if diff > 0 then "+" else "", Ui.fmt(diff)) else ""
		text(Ui.fmt(eff) .. (unit or "") .. bonus, 17, C.ink, Ui.HEAVY, { Position = UDim2.fromOffset(0, 16), Parent = r })
		if m > 0 then
			local pips = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(92, 22), Size = UDim2.fromOffset(90, 10), Parent = r })
			Ui.list(Enum.FillDirection.Horizontal, 2).Parent = pips
			for i = 1, m do
				local pip = new("Frame", { BackgroundColor3 = if i <= t.lvl[stat] then C.gold else Ui.hex("#2f3542"), BorderSizePixel = 0, Size = UDim2.fromOffset(math.max(4, math.floor(88 / m) - 2), 8), LayoutOrder = i, Parent = pips })
				Ui.corner(2).Parent = pip
			end
			local btns = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(130, 32), Parent = r })
			Ui.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right).Parent = btns
			if c == nil then
				text("MAX", 12, C.good, Ui.BOLD, { Parent = btns })
			elseif mine then
				local b = button(Ui.money(c) .. " <font size='10' color='#5c4a10'>" .. STAT_KEYS[stat] .. "</font>", "primary", function()
					self.ctx.send("upgrade", t.id, stat, false)
				end, { LayoutOrder = 1, TextSize = 13, Size = UDim2.fromOffset(0, 30), Parent = btns })
				if cash < c then
					b.BackgroundColor3 = Ui.hex("#5a4c1f")
				end
				button("Max", nil, function()
					self.ctx.send("upgrade", t.id, stat, true)
				end, { LayoutOrder = 2, TextSize = 12, Size = UDim2.fromOffset(0, 30), Parent = btns })
			end
		end
	end
	if t.type == "modifier" then
		row("range", "Range", t.baseRange, t.baseRange)
	elseif t.type == "economy" then
		row("damage", L.damage or "Cap", t.eff.damage, t.eff.damage)
		row("rate", L.rate or "Interest", t.eff.rate, t.eff.rate, "%")
	else
		if t.type == "weapon" then
			row("damage", L.damage or "Damage", t.eff.damage, t.eff.damage, L.damageUnit)
		end
		if upMax(D, t.kind, "range") > 0 or t.baseRange < 1000 then
			row("range", L.range or "Range", t.baseRange, t.eff.range)
		end
		if t.type ~= "combonly" then
			row("rate", L.rate or "Rate", t.eff.rate, t.eff.rate, "/m")
		end
	end
	-- tags
	local tags = {}
	if t.type == "weapon" and not t.comboNever then
		table.insert(tags, if t.comboCapable then (if dyn.ready then "<font color='#6ad46a'>combo ready</font>" else "combo recharging") else "max damage to combo")
	end
	if t.freakCapable then
		table.insert(tags, if (dyn.freak or 0) > 0 then "<font color='#ff5f57'>FREAKOUT</font>" else "freakout at dmg 4 + rate 4")
	end
	if t.type == "combonly" and t.combo then
		table.insert(tags, "<font color='#6ad46a'>" .. Ui.comboName(t.combo) .. " cannon</font>")
	end
	if #tags > 0 then
		text(table.concat(tags, "  ·  "), 12, C.muted, Ui.BOLD, { LayoutOrder = nextOrder(), Parent = F })
	end
	local function chipRow(h: number?)
		local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h or 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = F })
		local l = Ui.list(Enum.FillDirection.Horizontal, 4)
		l.Wraps = true
		l.Parent = r
		return r
	end
	if mine and t.type ~= "modifier" and t.type ~= "combonly" and t.type ~= "economy" then
		local chips = chipRow()
		for i, m in Engine.MODES do
			local on = t.targetMode == m
			button(Engine.MODE_TITLES[m], if on then "primary" else "ghost", function()
				self.ctx.send("mode", t.id, m)
			end, { LayoutOrder = i, TextSize = 11, Size = UDim2.fromOffset(0, 24), Parent = chips })
		end
		local acts = chipRow()
		button(if t.reacquire then "Lock off" else "Lock on", nil, function()
			self.ctx.send("lock", t.id)
		end, { LayoutOrder = 1, TextSize = 12, Size = UDim2.fromOffset(0, 28), Parent = acts })
		button(if t.dir then "Cone ±" .. t.dir.spread .. "°" else "Aim cone", nil, function()
			self:act("dir")
		end, { LayoutOrder = 2, TextSize = 12, Size = UDim2.fromOffset(0, 28), Parent = acts })
		if t.type == "targeter" then
			button(string.format("Link turret (%d/3)", t.joins or 0), if self.mode == "join" then "primary" else nil, function()
				self:act("join")
			end, { LayoutOrder = 3, TextSize = 12, Size = UDim2.fromOffset(0, 28), Parent = acts })
		end
	end
	if t.type == "combonly" and not t.combo and mine then
		local opts = self.combonlyOpts
		text(if opts == nil then "Checking combos…" elseif #opts > 0 then "Pick a combo. It absorbs the turrets it needs:" else "Place combo-capable turrets (max damage) within 70px.", 12, C.muted, Ui.FONT, { LayoutOrder = nextOrder(), TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), Parent = F })
		if opts and #opts > 0 then
			local chips = chipRow()
			for i, o in opts do
				local needs = {}
				for col, n in o.needs do
					table.insert(needs, n .. string.sub(col, 1, 1))
				end
				local b = button(o.colour .. ": " .. Ui.comboName(o.combo) .. " (" .. table.concat(needs, " ") .. ")", "ghost", function()
					self.ctx.send("combonly", t.id, o.colour)
				end, { LayoutOrder = i, TextSize = 11, Size = UDim2.fromOffset(0, 26), Parent = chips })
				b:FindFirstChildOfClass("UIStroke").Color = C[o.colour] or C.line
			end
		end
	end
	-- Commander Tools: upgrade queue
	if mine and self:passes().commander and t.type ~= "combonly" then
		local qr = chipRow()
		text("Queue" .. (if q and #q > 0 then " (" .. #q .. ")" else "") .. ":", 12, C.muted, Ui.BOLD, { LayoutOrder = 0, Parent = qr })
		for i, stat in { "damage", "range", "rate" } do
			if upMax(D, t.kind, stat) > 0 then
				button("+" .. string.upper(string.sub(stat, 1, 1)) .. string.sub(stat, 2), "ghost", function()
					self.ctx.send("queue", t.id, stat)
				end, { LayoutOrder = i, TextSize = 11, Size = UDim2.fromOffset(0, 24), Parent = qr })
			end
		end
		button("Clear", "ghost", function()
			self.ctx.send("queue", t.id, "clear")
		end, { LayoutOrder = 9, TextSize = 11, Size = UDim2.fromOffset(0, 24), Parent = qr })
	end
	-- move / sell
	if mine then
		local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(), Parent = F })
		button("Move ($" .. D.settings.moveCost .. ")", if self.mode == "move" then "primary" else nil, function()
			self:act("move")
		end, { TextSize = 12, Parent = r })
		local resale = D.settings.resale
		if self.ctx.info.plus then -- Salvage Rights research: +1% per level
			local p = self.ctx.profile()
			for _, rr in (p and p.research) or {} do
				if rr.id == "salvage" then
					resale += 0.01 * rr.level
				end
			end
		end
		button("Sell " .. Ui.money(math.ceil(t.value * resale)), "danger", function()
			self:act("sell")
		end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), TextSize = 12, Parent = r })
	end
end

function MatchUI:act(a: string)
	local t = self.sel and self.byId[self.sel]
	if not t then
		return
	end
	if a == "sell" then
		self.ctx.send("sell", t.id)
		self:select(nil)
		self:setMode(nil)
	elseif a == "dir" then
		if t.dir then
			local n = SPREAD_NEXT[t.dir.spread]
			self.ctx.send("dir", t.id, if n then t.dir.deg else 0, n or 0)
		else
			self:setMode("dir")
		end
	elseif a == "move" or a == "join" then
		self:setMode(if self.mode == a then nil else a)
	end
	self.selKey = ""
	self:renderSel()
end

function MatchUI:setMode(m: string?)
	self.mode = m
	local hint = m and MODE_HINTS[m]
	self.hint.Visible = hint ~= nil
	self.hint.Text = hint or ""
end

function MatchUI:toast(msg: string, color: Color3?)
	local f = new("Frame", { BackgroundColor3 = C.panel2, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = -os.clock() * 1000, Parent = self.toastsF })
	Ui.corner(8).Parent = f
	Ui.stroke(C.line).Parent = f
	Ui.pad(12, 0).Parent = f
	new("Frame", { BackgroundColor3 = color or C.gold, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, -12), Position = UDim2.new(0, -6, 0, 6), Parent = f })
	text(msg, 13, C.ink, Ui.BOLD, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextYAlignment = Enum.TextYAlignment.Center, Parent = f })
	task.delay(3.2, function()
		f:Destroy()
	end)
	local kids = {}
	for _, c in self.toastsF:GetChildren() do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	if #kids > 4 then
		table.sort(kids, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
end

-- ================================================================ server data in
function MatchUI:setHeader(h)
	local prev = self.header
	self.header = h
	self.waveV.Text = tostring(h.wave)
	self.livesV.Text = tostring(h.lives)
	self.livesV.TextColor3 = if h.lives <= 3 then C.bad else C.ink
	self.cashV.Text = Ui.money(h.cash[self.ctx.pid] or 0)
	self.killsV.Text = Ui.fmt(h.kills)
	self.speedB.Text = h.speed .. "×"
	self.pauseB.Text = if h.paused then "▶" else "❚❚"
	local obj = {}
	if h.killTarget then
		table.insert(obj, string.format("Kills %s/%s", Ui.fmt(h.kills), Ui.fmt(h.killTarget)))
	end
	if h.waveLimit then
		table.insert(obj, string.format("Wave %d/%d", h.wave, h.waveLimit))
	end
	if h.timeLimit then
		local left = math.max(0, (h.timeLimit - h.now) / 1000)
		table.insert(obj, string.format("%d:%02d left", left // 60, left % 60))
	end
	if h.turretLimit then
		table.insert(obj, string.format("Turrets %d/%d", #self.turrets, h.turretLimit))
	end
	self.objectiveL.Text = table.concat(obj, "  ·  ")
	self:refreshTiles()
	if h.reviveUntil and not (prev and prev.reviveUntil) then
		self:showRevive(h)
	elseif not h.reviveUntil and self.reviveOpen then
		self:closeOverlay()
	end
	if self.reviveOpen and h.reviveUntil then
		self.reviveTimer.Text = string.format("%d s", math.ceil(h.reviveUntil))
	end
	self:renderSel()
end

function MatchUI:setTurrets(details)
	self.turrets = details
	self.byId = {}
	for _, t in details do
		self.byId[t.id] = t
	end
	self.probe.turrets = details
	if self.sel and not self.byId[self.sel] then
		self:select(nil)
	end
	self.selKey = ""
	self:renderSel()
end

function MatchUI:setDyn(turretDyn)
	self.dyn = turretDyn
end

function MatchUI:onFx(list)
	for _, f in list do
		if f.k == "wave" and f.n % 10 == 0 then
			self:toast("Wave " .. f.n, C.info)
		elseif f.k == "unlock" then
			local d = self.D.turrets[f.kind]
			self:toast("Unlocked: " .. (d and d.label or f.kind), C.good)
		elseif f.k == "life" then
			self:toast("Lives: " .. f.lives, C.bad)
		elseif f.k == "freakwarn" then
			local t = self.byId[f.id]
			if t and t.owner == self.ctx.pid then
				self:toast("Freakout incoming!", C.bad)
			end
		elseif f.k == "freeze" then
			self:toast("Time Freeze!", C.Cyan)
		elseif f.k == "limit" then
			self:toast("Limit reached: " .. tostring(f.why), C.gold)
		end
	end
end

-- ================================================================ speed, menu, revive, end
function MatchUI:cycleSpeed()
	if not self:isHost() then
		self:toast("Only the host changes speed.", C.muted)
		return
	end
	local list = if self:passes().speed then Config.SPEEDS else { 1, 2 }
	local cur = self.header and self.header.speed or 1
	local i = table.find(list, cur) or 0
	self.ctx.send("speed", list[i % #list + 1])
end

function MatchUI:closeOverlay()
	Ui.clear(self.overlay)
	self.overlay.Visible = false
	self.reviveOpen = false
end
local function card(parent, width)
	local c = Ui.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width or 460, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 21, Parent = parent })
	Ui.pad(20).Parent = c
	Ui.list(Enum.FillDirection.Vertical, 10).Parent = c
	return c
end

function MatchUI:openMenu()
	self:closeOverlay()
	self.overlay.Visible = true
	local h = self.header
	local c = card(self.overlay, 480)
	local hdr = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = c })
	text(if h and h.paused then "Paused" else "Menu", 22, C.ink, Ui.HEAVY, { Parent = hdr })
	button("Resume", "primary", function()
		if h and h.paused and self:isHost() then
			self.ctx.send("pause", false)
		end
		self:closeOverlay()
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = hdr })
	local info = self.ctx.info
	local mapName = self.D.maps[info.map] and self.D.maps[info.map].name or info.map
	text(string.format("%s · %s%s · wave %d · %s kills", mapName, info.mode, if info.plus then " · Onslaught+" else "", h and h.wave or 0, Ui.fmt(h and h.kills or 0)), 13, C.muted, Ui.FONT, { LayoutOrder = 2, Parent = c })
	-- settings (host)
	text("Settings", 15, C.ink, Ui.HEAVY, { LayoutOrder = 3, Parent = c })
	local s1 = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 4, Parent = c })
	text("Wave spacing", 13, C.ink, Ui.FONT, { Position = UDim2.fromOffset(0, 6), Parent = s1 })
	local spacing = math.floor((h and h.waveSpacing or 20000) / 1000)
	local follow = h and h.waveFollow or false
	local val = text(spacing .. " s", 14, C.gold, Ui.MONO, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -80, 0, 6), Parent = s1 })
	local function setSpacing(v)
		spacing = math.clamp(v, 5, 60)
		val.Text = spacing .. " s"
		self.ctx.send("prefs", spacing, follow)
		self.ctx.request("settings", { waveSpacing = spacing, waveFollow = follow, showRanges = self.showRanges })
	end
	button("−", nil, function()
		setSpacing(spacing - 5)
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 0), Size = UDim2.fromOffset(32, 30), Parent = s1 })
	button("+", nil, function()
		setSpacing(spacing + 5)
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(32, 30), Parent = s1 })
	local toggles = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 5, Parent = c })
	Ui.list(Enum.FillDirection.Horizontal, 6).Parent = toggles
	button((if follow then "☑" else "☐") .. " Send next wave when clear", nil, function()
		follow = not follow
		setSpacing(spacing)
		self:openMenu()
	end, { TextSize = 12, Parent = toggles })
	button((if self.showRanges then "☑" else "☐") .. " Show all ranges", nil, function()
		self.showRanges = not self.showRanges
		self:openMenu()
	end, { TextSize = 12, Parent = toggles })
	if not self:isHost() then
		text("Only the host can change wave spacing, speed and pause.", 11, C.dim, Ui.FONT, { LayoutOrder = 6, Parent = c })
	end
	-- boosts (Onslaught+ only)
	if info.plus then
		text("Boosts", 15, C.ink, Ui.HEAVY, { LayoutOrder = 7, Parent = c })
		local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 8, Parent = c })
		Ui.grid(UDim2.new(0.5, -4, 0, 46), 8).Parent = grid
		local p = self.ctx.profile()
		local credits = p and p.credits or {}
		for _, prod in (p and p.catalog and p.catalog.products) or {} do
			if prod.plusOnly and prod.id ~= "revive" then
				local have = credits[prod.id] or 0
				local label = string.format("%s\n<font color='#77ccff'>R$%d</font>%s", prod.name, prod.robux, if have > 0 then string.format("  <font color='#6ad46a'>(%d owned)</font>", have) else "")
				local b = button(label, nil, function()
					self:closeOverlay()
					if prod.id == "airstrike" then
						self.pendingProduct = { id = prod.id, credit = have > 0 }
						self:setMode("airstrike")
					elseif have > 0 then
						self.ctx.send("useCredit", prod.id)
					else
						self.ctx.send("product", prod.id)
					end
				end, { TextSize = 12, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.None, Parent = grid })
				b.LineHeight = 1.1
			end
		end
		text("Using a boost marks the run as assisted (it won't count on the Onslaught+ leaderboard).", 11, C.dim, Ui.FONT, { LayoutOrder = 9, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = c })
	end
	if self:passes().commander then
		local bp = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 10, Parent = c })
		Ui.list(Enum.FillDirection.Horizontal, 6).Parent = bp
		button("Save blueprint", nil, function()
			self.ctx.send("blueprintSave")
		end, { TextSize = 12, Parent = bp })
		button("Load blueprint", nil, function()
			self.ctx.send("blueprintLoad")
			self:closeOverlay()
		end, { TextSize = 12, Parent = bp })
	end
	local foot = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 20, Parent = c })
	button("Quit to lobby", "danger", function()
		self.ctx.onLeave()
	end, { Parent = foot })
end

function MatchUI:showRevive(h)
	self:closeOverlay()
	self.overlay.Visible = true
	self.reviveOpen = true
	local c = card(self.overlay, 420)
	text("Game over", 26, C.bad, Ui.HEAVY, { LayoutOrder = 1, Parent = c })
	text("Second Chance: back to 5 lives and the field is cleared. Anyone in the party can buy it.", 13, C.muted, Ui.FONT, { LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = c })
	self.reviveTimer = text("", 14, C.gold, Ui.MONO, { LayoutOrder = 3, Parent = c })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 4, Parent = c })
	Ui.list(Enum.FillDirection.Horizontal, 8).Parent = row
	local price = ({ 99, 199, 399 })[math.min(3, (h.revives or 0) + 1)]
	button(string.format("Revive  <font color='#1b1608'>R$%d</font>", price), "primary", function()
		self.ctx.send("product", "revive")
	end, { Parent = row })
	local p = self.ctx.profile()
	local have = p and p.credits and p.credits.revive or 0
	if have > 0 then
		button("Use credit (" .. have .. ")", nil, function()
			self.ctx.send("useCredit", "revive")
		end, { Parent = row })
	end
	button("Give up", "ghost", function()
		self:closeOverlay()
	end, { Parent = row })
end

function MatchUI:showEnd(e, summary)
	self:closeOverlay()
	self.overlay.Visible = true
	local c = card(self.overlay, 460)
	text(if e.won then "Victory!" else "Game over", 28, if e.won then C.good else C.ink, Ui.HEAVY, { LayoutOrder = 1, Parent = c })
	local info = self.ctx.info
	local mapName = self.D.maps[info.map] and self.D.maps[info.map].name or info.map
	text(string.format("%s · %s%s", mapName, info.mode, if info.plus then " · Onslaught+" else ""), 13, C.muted, Ui.FONT, { LayoutOrder = 2, Parent = c })
	local stats = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 3, Parent = c })
	Ui.list(Enum.FillDirection.Horizontal, 18).Parent = stats
	Ui.stat("Wave", tostring(e.wave), C.ink, 80).Parent = stats
	Ui.stat("Kills", Ui.fmt(e.kills), C.ink, 90).Parent = stats
	if summary then
		Ui.stat("Your kills", Ui.fmt(summary.myKills or 0), C.ink, 100).Parent = stats
		local lines = { string.format("<font color='#ffcf4a'>+%s XP</font>   <font color='#6fb6ff'>+%s Intel</font>", Ui.fmt(summary.xp), Ui.fmt(summary.intel)) }
		if summary.levelUps > 0 then
			table.insert(lines, string.format("Level up! You're level %d.", summary.level))
		end
		if summary.newBest then
			table.insert(lines, "New best wave on this map.")
		end
		for _, u in summary.unlocked do
			table.insert(lines, "<font color='#6ad46a'>Unlocked " .. u .. "</font>")
		end
		for _, q in summary.quests do
			table.insert(lines, "Quest done: " .. q)
		end
		text(table.concat(lines, "\n"), 14, C.ink, Ui.BOLD, { LayoutOrder = 4, Parent = c })
	end
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 5, Parent = c })
	Ui.list(Enum.FillDirection.Horizontal, 8).Parent = row
	if self:isHost() then
		button("Play again", "primary", function()
			self.ctx.request("playAgain")
		end, { Parent = row })
	end
	button("Lobby", nil, function()
		self.ctx.onLeave()
	end, { Parent = row })
end

-- ================================================================ input
local function viewportPos(input: InputObject): Vector2
	if input.UserInputType == Enum.UserInputType.Touch then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X, input.Position.Y) + inset
	end
	return UserInputService:GetMouseLocation()
end

function MatchUI:turretAt(x: number, y: number)
	for _, t in self.turrets do
		if (t.x - x) ^ 2 + (t.y - y) ^ 2 <= 16 * 16 then
			return t
		end
	end
	return nil
end

function MatchUI:click(x: number, y: number, shift: boolean)
	local h = self.header
	if not h or h.over then
		return
	end
	local t = self:turretAt(x, y)
	local sel = self.sel and self.byId[self.sel]
	local m = self.mode
	if m == "move" and sel then
		self.ctx.send("move", sel.id, math.floor(x + 0.5), math.floor(y + 0.5))
		self:setMode(nil)
		return
	elseif m == "join" and sel then
		if t then
			self.ctx.send("join", sel.id, t.id)
		end
		self:setMode(nil)
		return
	elseif m == "dir" and sel then
		self.ctx.send("dir", sel.id, math.atan2(y - sel.y, x - sel.x) * 57.296, 50) -- the original's degrees (DEG = 57.296)
		self:setMode(nil)
		return
	elseif m == "focus" then
		self.ctx.send("focus", x, y)
		self:setMode(nil)
		return
	elseif m == "airstrike" then
		local pp = self.pendingProduct
		self.ctx.send(if pp and pp.credit then "useCredit" else "product", "airstrike", x, y)
		self.pendingProduct = nil
		self:setMode(nil)
		return
	end
	if self.buildKind then
		if t then
			self.buildKind = nil
			self:select(t.id)
			return
		end
		local kind = self.buildKind
		if self:cash() < self.D.turrets[kind].cost then
			self:toast("Not enough cash", C.bad)
			return
		end
		if not Engine.canBuildAt(self.probe, kind, math.floor(x + 0.5), math.floor(y + 0.5), nil) then
			self:toast(if h.turretLimit and #self.turrets >= h.turretLimit then "Turret limit reached" else "Can't build there", C.bad)
			return
		end
		self.ctx.send("build", kind, math.floor(x + 0.5), math.floor(y + 0.5))
		if not shift then
			self.buildKind = nil
		end
		self.selKey = ""
		self:renderSel()
		return
	end
	self:select(t and t.id or nil)
end

function MatchUI:bindInput()
	local function shiftDown()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	end
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local it = input.UserInputType
		if it == Enum.UserInputType.MouseButton1 or it == Enum.UserInputType.Touch then
			local x, y = self.board:toBoard(viewportPos(input))
			if x then
				self:click(x, y, shiftDown())
			end
			return
		elseif it == Enum.UserInputType.MouseButton2 then
			self.buildKind = nil
			self:setMode(nil)
			self.selKey = ""
			self:renderSel()
			return
		end
		if it ~= Enum.UserInputType.Keyboard then
			return
		end
		local kc = input.KeyCode
		local shift = shiftDown()
		-- turret hotkeys (1-9, shifted digits, letters for Onslaught+)
		for _, k in self.D.buildOrder do
			local code, needShift = keyCodeFor(self.D.turrets[k].key)
			if code == kc and needShift == shift then
				if self.header and self.header.unlocked[k] then
					self.buildKind = k
					self:select(nil)
					self:setMode(nil)
					self.tab = tabOf(self.D, k)
					self:renderPalette()
				end
				return
			end
		end
		if kc == Enum.KeyCode.Space then
			self.ctx.send("send")
		elseif kc == Enum.KeyCode.Escape then
			self.buildKind = nil
			self:setMode(nil)
			self:select(nil)
			if self.overlay.Visible and not self.reviveOpen then
				self:closeOverlay()
			end
		elseif kc == Enum.KeyCode.P then
			if self:isHost() then
				self.ctx.send("pause", not (self.header and self.header.paused))
			end
		elseif kc == Enum.KeyCode.F then
			self:setMode("focus")
		elseif kc == Enum.KeyCode.R then
			self.showRanges = not self.showRanges
		elseif self.sel then
			local t = self.byId[self.sel]
			if not t then
				return
			end
			if kc == Enum.KeyCode.Q or kc == Enum.KeyCode.W or kc == Enum.KeyCode.E then
				local stat = if kc == Enum.KeyCode.Q then "damage" elseif kc == Enum.KeyCode.W then "range" else "rate"
				self.ctx.send("upgrade", t.id, stat, shift)
			elseif kc == Enum.KeyCode.T then
				local i = table.find(Engine.MODES, t.targetMode) or 0
				self.ctx.send("mode", t.id, Engine.MODES[i % #Engine.MODES + 1])
			elseif kc == Enum.KeyCode.L then
				self.ctx.send("lock", t.id)
			elseif kc == Enum.KeyCode.D then
				self:act("dir")
			elseif kc == Enum.KeyCode.M then
				self:act("move")
			elseif kc == Enum.KeyCode.J and t.type == "targeter" then
				self:act("join")
			elseif kc == Enum.KeyCode.S or kc == Enum.KeyCode.Delete then
				self:act("sell")
			end
		end
	end))
end

-- Per frame: timer bar, ghost and range rings.
function MatchUI:update(_dt: number)
	local h = self.header
	if h then
		if h.noMoreWaves then
			self.nextL.Text = "NO MORE WAVES"
			self.waveBar.Size = UDim2.fromScale(1, 1)
			self.nextV.Text = ""
		else
			local left = math.max(0, h.waveSpacing - (h.now - h.waveLast))
			self.nextL.Text = "NEXT WAVE"
			self.waveBar.Size = UDim2.fromScale(math.clamp(1 - left / h.waveSpacing, 0, 1), 1)
			self.nextV.Text = string.format("%.1fs", left / 1000)
		end
	end
	-- overlay rings: placement ghost, selection range
	local board = self.board
	local mouse = UserInputService:GetMouseLocation()
	local x, y = board:toBoard(mouse)
	if self.buildKind and x then
		local d = self.D.turrets[self.buildKind]
		local ok = Engine.canBuildAt(self.probe, self.buildKind, math.floor(x + 0.5), math.floor(y + 0.5), nil)
		board:showRange(x, y, d.range, ok)
	elseif self.mode == "move" and x and self.sel and self.byId[self.sel] then
		local t = self.byId[self.sel]
		local ok = Engine.canBuildAt(self.probe, t.kind, math.floor(x + 0.5), math.floor(y + 0.5), t)
		board:showRange(x, y, t.eff.range, ok)
	elseif self.sel and self.byId[self.sel] then
		local t = self.byId[self.sel]
		board:showRange(t.x, t.y, if t.type == "modifier" then t.baseRange else t.eff.range, nil)
	else
		board:hideOverlay()
	end
end

function MatchUI:destroy()
	for _, c in self.connections do
		c:Disconnect()
	end
	self.root:Destroy()
end

return MatchUI
