--!strict
--[[
	Capsule: the points capsule (DESIGN.md 4.3), in TopbarGui centred under the Roblox top bar.

	    Capsule   400 x 58 (COMPACT 300 x 44), dark gradient, gold rim and glow
	      Coin    Ø68 gold disc breaking out on the left, a spinning star (6 s / rev)
	      Label   "POINTS · NORMAL UNIVERSE" (`caps`, #ffe9a3; not on COMPACT)
	      Row     Amount (R4 gold gradient number, `capsule` role, steps 34 -> 30 -> 26 past 250 du, left anchored)
	              + Unit ("points" / "pts")
	      GenPill the rate (Rich.num) on a dark green pill hanging from the rim; hidden when hud.gen is nil
	      Warn    a chip right of the capsule with the first warning value; tap -> warnTap (the tooltip lists all)
	      Status  SAVING... / SAVED / NOT SAVING / RECONNECTING... under the pill
	      Info    the game's other head lines under them (hud.x: sp challenge 11's ashes, a burning Spark Milestone;
	              hud.off offline time; hud.dev dev speed), `small` on a glass chip; bottom() counts it

	    local part = Capsule.new(parent)
	    part:update(h)   part:setStatus(kind)   part:setUniverse(inside)   part:setFirstRun(b)   part.warnTap
	    part:rects() -> { capsule, pill?, warn?, status? } (abs space; Hud registers them with Layout)
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Sleek = require(Core:WaitForChild("Sleek"))
local Kit = require(script.Parent:WaitForChild("Kit"))

type ARect = Types.Rect

export type Capsule = {
	frame: Frame,
	pill: Frame,
	warn: Frame,
	status: Frame,
	info: Frame,
	warnTap: Signal.Signal<Vector2>,
	changed: Signal.Signal<>, -- a part moved, appeared or disappeared (Hud re-registers the rects)
	update: (self: Capsule, h: Types.HudState) -> (),
	setStatus: (self: Capsule, kind: string?) -> (),
	setUniverse: (self: Capsule, inside: boolean) -> (),
	setFirstRun: (self: Capsule, b: boolean) -> (),
	bottom: (self: Capsule) -> number, -- du below the Root top where things can hang (pill / status)
	destroy: (self: Capsule) -> (),
}

local Capsule = {}

local GOLD = Color3.fromHex("ffc233")
local GOLD_D = Color3.fromHex("ffd34d")
local CREAM = Color3.fromHex("ffe9a3")
local GOOD = Color3.fromHex("8ff0ad")

local STATUS: { [string]: { text: string, color: Color3, glyph: string } } = {
	saving = { text = "Saving…", color = GOLD, glyph = "clock" },
	saved = { text = "Saved", color = Theme.C.bought, glyph = "check" },
	off = { text = "Not saving", color = Theme.C.danger, glyph = "warn" },
	reconnecting = { text = "Reconnecting…", color = Theme.C.info, glyph = "swirl" },
}

function Capsule.new(parent: GuiObject): Capsule
	local self = {} :: Capsule
	self.warnTap = Signal.new() :: Signal.Signal<Vector2>
	self.changed = Signal.new() :: Signal.Signal<>

	-- Sleek: a translucent slab with a hairline, corner ticks and a gold accent; a gold diamond instead of the coin
	local f = Kit.frame(parent, "Capsule", 5)
	f.AnchorPoint = Vector2.new(0.5, 0)
	Sleek.plate(f, { alpha = 0.88, line = 0.86 })
	Sleek.ticks(f, { len = 10, th = 2, out = 1, color = Color3.new(1, 1, 1), alpha = 0.8, z = 9 })
	Sleek.accent(f, GOLD_D, 24, 64, { name = "Accent" })
	self.frame = f

	local coin = Sleek.diamond(f, "Coin", GOLD_D, 44, { fill = 0, inner = false })
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.ZIndex = 6
	local core = Kit.frame(coin, "Core", 7)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromOffset(8, 8)
	core.Rotation = 45
	core.BackgroundColor3 = GOLD_D
	core.BackgroundTransparency = 0

	local label = Kit.label(f, "Label", "caps", "", Sleek.C.soft)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.fromOffset(300, 13)

	local row = Kit.frame(f, "Row", 6)
	row.AutomaticSize = Enum.AutomaticSize.X
	Kit.list(row, "x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)
	local amount = Kit.label(row, "Amount", "capsule", "0", Color3.new(1, 1, 1))
	amount.LayoutOrder = 1
	amount.AutomaticSize = Enum.AutomaticSize.X
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.TextYAlignment = Enum.TextYAlignment.Bottom
	local unit = Kit.label(row, "Unit", "small", "points", Sleek.C.soft)
	unit.LayoutOrder = 2
	unit.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold)
	unit.AutomaticSize = Enum.AutomaticSize.X
	unit.TextYAlignment = Enum.TextYAlignment.Bottom

	-- the rate: a hairline divider, then a sparkline of the last minute over the "↑ rate" line (inside the slab)
	local divider = Kit.frame(f, "Divider", 6)
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = Sleek.LINE
	local pill = Kit.frame(parent, "GenPill", 7)
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.AutomaticSize = Enum.AutomaticSize.X
	Kit.list(pill, "x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local up = Kit.glyph(pill, "Up", "up", GOOD)
	up.LayoutOrder = 1
	local pillLabel = Kit.label(pill, "Label", "number", "", GOOD)
	pillLabel.LayoutOrder = 2
	pillLabel.RichText = true
	pillLabel.AutomaticSize = Enum.AutomaticSize.X
	pill.Visible = false
	self.pill = pill
	local spark = Kit.frame(parent, "Spark", 7)
	spark.AnchorPoint = Vector2.new(0.5, 0)
	spark.Visible = false
	local history: { number } = {}
	local lastSample = -math.huge

	-- the warning chip
	local warn = Kit.frame(parent, "Warn", 6)
	warn.AnchorPoint = Vector2.new(0, 0.5)
	warn.AutomaticSize = Enum.AutomaticSize.X
	Sleek.plate(warn, { alpha = 0.88, line = 0.86, edge = false })
	Kit.stroke(warn, 1, GOLD, 0.5, "Rim").LineJoinMode = Enum.LineJoinMode.Miter
	local wContent = Kit.frame(warn, "Content")
	wContent.AutomaticSize = Enum.AutomaticSize.X
	wContent.Size = UDim2.fromScale(0, 1)
	Kit.list(wContent, "x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local wIcon = Kit.glyph(wContent, "Icon", "warn", GOLD)
	wIcon.LayoutOrder = 1
	local wLabel = Kit.label(wContent, "Label", "badge", "", Color3.new(1, 1, 1))
	wLabel.LayoutOrder = 2
	wLabel.RichText = true
	wLabel.AutomaticSize = Enum.AutomaticSize.X
	local wHit = Kit.button(warn, "Hit")
	wHit.Size = UDim2.new(1, 0, 1, 12)
	wHit.Position = UDim2.fromOffset(0, -6)
	wHit.ZIndex = 5
	wHit.Activated:Connect(function()
		local p, s = warn.AbsolutePosition, warn.AbsoluteSize
		self.warnTap:Fire(Vector2.new(p.X + s.X / 2, p.Y + s.Y))
	end)
	warn.Visible = false
	self.warn = warn

	-- the status chip
	local status = Kit.frame(parent, "Status", 6)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.AutomaticSize = Enum.AutomaticSize.X
	Sleek.plate(status, { alpha = 0.88, line = 0.86, edge = false })
	local sRim = Kit.stroke(status, 1, GOLD, 0.6, "Rim")
	sRim.LineJoinMode = Enum.LineJoinMode.Miter
	Kit.list(status, "x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local sLabel = Kit.label(status, "Label", "label", "", Color3.new(1, 1, 1))
	sLabel.LayoutOrder = 2
	sLabel.AutomaticSize = Enum.AutomaticSize.X
	status.Visible = false
	self.status = status

	-- the game's other head lines (sp challenge 11's ashes, a burning Spark Milestone, offline time, dev speed)
	local info = Kit.frame(parent, "Info", 6)
	info.AnchorPoint = Vector2.new(0.5, 0)
	info.AutomaticSize = Enum.AutomaticSize.Y
	Sleek.plate(info, { alpha = 0.88, line = 0.86, edge = false })
	local iLabel = Kit.label(info, "Label", "small", "", Theme.C.text)
	iLabel.AutomaticSize = Enum.AutomaticSize.Y
	iLabel.Size = UDim2.fromScale(1, 0)
	iLabel.TextWrapped = true
	iLabel.RichText = true
	iLabel.TextXAlignment = Enum.TextXAlignment.Center
	info.Visible = false
	self.info = info
	info:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self.changed:Fire()
	end)

	-- ------------------------------------------------------------------------------------------ layout
	local compact = false
	local inside = false
	local firstRun = false
	local hud: Types.HudState? = nil
	local statusKind: string? = nil
	local savedToken = 0

	local W_WIDE, H_WIDE, W_COMPACT, H_COMPACT = 540, 62, 340, 44
	local function place()
		compact = Layout.mode == "COMPACT"
		local w, h = if compact then W_COMPACT else W_WIDE, if compact then H_COMPACT else H_WIDE
		f.Size = UDim2.fromOffset(w, h)
		f.Position = UDim2.new(0.5, 0, 0, 4)
		local cd = if compact then 30 else 40
		Sleek.diamond(f, "Coin", GOLD_D, cd, { fill = 0, inner = false })
		coin.Position = UDim2.new(0, if compact then 10 else 16, 0.5, 0)
		core.Size = UDim2.fromOffset(if compact then 6 else 8, if compact then 6 else 8)
		local x0 = (if compact then 10 else 16) + cd + (if compact then 10 else 16)
		label.Visible = not compact
		label.Position = UDim2.fromOffset(x0, 10)
		Theme.text(label, "caps")
		row.Position = UDim2.fromOffset(x0, if compact then 4 else 23)
		row.Size = UDim2.fromOffset(0, 36)
		amount.Size = UDim2.fromScale(0, 1)
		unit.Size = UDim2.fromScale(0, 1)
		Theme.text(unit, if compact then "label" else "small")
		unit.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold)
		local pad = Kit.child(unit, "Pad", "UIPadding") :: UIPadding
		pad.PaddingBottom = UDim.new(0, if compact then 5 else 6)
		-- the rate column on the right of the slab
		local rx = if compact then 110 else 174 -- the column's width from the right edge
		divider.Position = UDim2.new(1, -rx - 14, 0, 12)
		divider.Size = UDim2.new(0, 1, 1, -24)
		divider.Visible = true
		pill.Size = UDim2.fromOffset(0, 18)
		pill.AnchorPoint = Vector2.new(0, 0)
		pill.Position = UDim2.new(0.5, w / 2 - rx, 0, 4 + (if compact then 13 else 36))
		Theme.text(pillLabel, "number")
		pillLabel.TextSize = if compact then 13 else 14
		pillLabel.Size = UDim2.fromScale(0, 1)
		local gs = if compact then 11 else 12
		up.Size = UDim2.fromOffset(gs, gs)
		spark.AnchorPoint = Vector2.new(0, 0)
		spark.Position = UDim2.new(0.5, w / 2 - rx, 0, 4 + 10)
		spark.Size = UDim2.fromOffset(rx - 16, 22)
		-- warn: right of the capsule
		warn.Size = UDim2.fromOffset(0, if compact then 26 else 30)
		warn.Position = UDim2.new(0.5, w / 2 + 14, 0, 4 + h / 2)
		Kit.pad(warn, 0, 10, 0, 8)
		wIcon.Size = UDim2.fromOffset(16, 16)
		Theme.text(wLabel, "badge")
		wLabel.Size = UDim2.fromScale(0, 1)
		-- status: under the capsule
		status.Size = UDim2.fromOffset(0, 28)
		Kit.pad(status, 0, 10, 0, 8)
		Theme.text(sLabel, "label")
		sLabel.Size = UDim2.fromScale(0, 1)
		info.Size = UDim2.fromOffset(if compact then 340 else 460, 0)
		Kit.pad(info, 6, 12, 6, 12)
		Theme.text(iLabel, "small")
		self.changed:Fire()
	end
	-- the sparkline: one sample of the points' magnitude every 2 s, the last 30 (one minute)
	local function sample(pts: string)
		local now = os.clock()
		if now - lastSample < 2 and #history > 0 then
			history[#history] = Sleek.mag(pts) or history[#history]
		else
			lastSample = now
			local m = Sleek.mag(pts)
			if m then
				table.insert(history, m)
				if #history > 30 then table.remove(history, 1) end
			end
		end
		local show = not compact and not firstRun and pill.Visible and #history >= 1
		spark.Visible = show
		if show then
			Sleek.spark(spark, "Line", history, GOOD, { w = spark.Size.X.Offset, h = 22, thick = 1.6 })
		end
	end

	local function statusY(): number
		local h = if compact then H_COMPACT else H_WIDE
		return 4 + h + 8
	end

	local function infoY(): number
		local y = statusY()
		if status.Visible then y += 28 + 6 end
		return y
	end
	local infoText = ""
	local function writeInfo(h: Types.HudState?)
		local parts = {}
		if h and not firstRun then
			if type(h.x) == "string" and h.x ~= "" then table.insert(parts, Rich.html(h.x, Theme.size("small"), nil)) end
			if type(h.off) == "string" then table.insert(parts, Rich.caps("Offline time") .. "  " .. Rich.num(h.off, { size = Theme.size("small") })) end
			if type(h.dev) == "string" then table.insert(parts, Rich.caps("Dev speed") .. "  " .. Rich.num(h.dev, { size = Theme.size("small") })) end
		end
		local t = table.concat(parts, "\n")
		if t ~= infoText then
			infoText = t
			iLabel.Text = t
		end
		local show = t ~= ""
		info.Position = UDim2.new(0.5, 0, 0, infoY())
		if info.Visible ~= show then
			info.Visible = show
			self.changed:Fire()
		end
	end

	local function writeLabel()
		label.Text = Rich.caps(if inside then "Points · Prestige Multiverse" else "Points · Normal Universe")
		Sleek.accent(f, if inside then Theme.hue("pm") else GOLD_D, 24, 64, { name = "Accent" })
	end

	local lastPts = ""
	local lastBump = 0
	function self.update(c: Capsule, h: Types.HudState)
		hud = h
		local pts = h.pts
		if pts ~= lastPts then
			local grew = lastPts ~= ""
			lastPts = pts
			local size = Theme.size("capsule")
			Recipes.number(amount, { text = pts, size = size, from = Color3.new(1, 1, 1), to = Color3.new(1, 1, 1),
				stroke = 0, shadow = 0, role = "capsule" })
			local steps = if compact then { 28, 26, 22 } else { 34, 30, 26 }
			Rich.fit(amount, steps, if compact then 140 else 230)
			if grew and os.clock() - lastBump >= 1 then
				lastBump = os.clock()
				Motion.bump(row, 0.05)
			end
		end
		local name = h.name
		local unitText = if compact then (if name == "points" then "pts" else name) else name
		if unit.Text ~= unitText then unit.Text = unitText end
		local gen = h.gen
		local showPill = gen ~= nil and gen ~= "" and not firstRun and f.Visible
		if showPill then
			local g = gen :: string
			if compact then g = string.gsub(string.gsub(Rich.short(g), "OOMs/sec", "OOM/s"), "/sec", "/s") end
			local t = Rich.num(g, { size = if compact then 12 else 14, unit = GOOD })
			if pillLabel.Text ~= t then pillLabel.Text = t end
		end
		if pill.Visible ~= showPill then
			pill.Visible = showPill
			c.changed:Fire()
		end
		sample(pts)
		local w = h.w[1]
		local showWarn = w ~= nil and f.Visible
		if w then
			local t = Rich.num(string.upper(w.k) .. " " .. w.v, { size = Theme.size("badge"), unit = CREAM })
			if wLabel.Text ~= t then wLabel.Text = t end
		end
		if warn.Visible ~= showWarn then
			warn.Visible = showWarn
			c.changed:Fire()
		end
		status.Position = UDim2.new(0.5, 0, 0, statusY())
		writeInfo(h)
	end

	function self.setStatus(c: Capsule, kind: string?)
		if kind == "saved" then
			savedToken += 1
			local token = savedToken
			task.delay(1.5, function()
				if savedToken == token and statusKind == "saved" then c:setStatus(nil) end
			end)
		end
		if kind == statusKind then return end
		statusKind = kind
		local spec = if kind then STATUS[kind] else nil
		if spec == nil then
			status.Visible = false
			writeInfo(hud)
			c.changed:Fire()
			return
		end
		sRim.Color = spec.color
		sLabel.Text = spec.text
		sLabel.TextColor3 = Theme.lift(spec.color, 0.35)
		local g = Kit.glyph(status, "Icon", spec.glyph, spec.color, Theme.C.deep)
		g.LayoutOrder = 1
		g.Size = UDim2.fromOffset(14, 14)
		status.Position = UDim2.new(0.5, 0, 0, statusY())
		status.Visible = true
		writeInfo(hud)
		c.changed:Fire()
	end

	function self.setUniverse(_: Capsule, b: boolean)
		inside = b
		writeLabel()
	end
	function self.setFirstRun(c: Capsule, b: boolean)
		if firstRun == b then return end
		firstRun = b
		local h = hud
		if h then c:update(h) end
	end
	function self.bottom(_: Capsule): number
		local y = infoY()
		if info.Visible then y += math.max(28, info.AbsoluteSize.Y / math.max(Layout.s, 0.01)) + 6 end
		return y
	end
	function self.destroy(c: Capsule)
		c.warnTap:DisconnectAll()
		c.changed:DisconnectAll()
		for _, x in { f, pill, spark, warn, status, info } do x:Destroy() end
	end

	place()
	writeLabel()
	-- the phone band hides the capsule; its detached parts (rate, sparkline, warning) follow it
	f:GetPropertyChangedSignal("Visible"):Connect(function()
		local h = hud
		if h then self:update(h) end
		if not f.Visible then spark.Visible = false end
	end)
	Layout.changed:Connect(function()
		place()
		lastPts = ""
		local h = hud
		if h then self:update(h) end
	end)
	return self
end

return Capsule
