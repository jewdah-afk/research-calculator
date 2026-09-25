--!strict
--[[
	M: the milestone ladders of m, mm, em, cm and pm (DESIGN.md 6 rows m / mm / em / cm, 6.1 "m / mm / em ladder").

	The layer's `milestones` component is claimed and drawn as a ladder on a glowing spine:
	    NEXT       the spotlight card (Ø78 number disc, NEXT MILESTONE, title, effect) with REQUIRES: the need, the unit
	               and the pr bar of the tab's own prestige button (refreshed through the hero hook, which runs whenever
	               the button changes)
	    done       the 4 newest done rows (quiet green: title, then the effect on its own line; infected rows get a
	               danger rim and the malware effect split at the game's <hr>)
	    folds      the older done rows in decade folds ("151 – 160", the count, the decade's first unlock line as sent);
	               a tap opens one decade; the rest folds into "1 – N  SHOW ALL"
	    SHOW ALL   every row in a virtualised pool (Panel/Virtual; the pool is the viewport + 2 rows)
	WIDE adds a right column: NOTES (the tab's display-text lines, claimed and moved here), JUMP TO (NEXT, 25-row blocks,
	MALWARE) and an "Order" button that opens Options (the map's own `opt` action). COMPACT keeps one column with the
	notes on top. m's MALWARE section lists every row that has an INFECT button (the malware node's own action).
	The game's Milestone Showing Mode and Order decide which rows arrive and in which order; the ladder keeps that order
	(newest first reads top-down from NEXT, oldest first is the same ladder upside down).
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Rich = require(Core:WaitForChild("Rich"))
local Motion = require(Core:WaitForChild("Motion"))
local Layout = require(Core:WaitForChild("Layout"))
local Recipes = require(Core:WaitForChild("Recipes"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Sections = require(PanelF:WaitForChild("Sections"))
local Virtual = require(PanelF:WaitForChild("Virtual"))
local Signatures = require(script.Parent:WaitForChild("Signatures"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local C = Theme.C

-- session memory per layer: SHOW ALL, and the open decade fold
local showAll: { [string]: boolean } = {}
local openFold: { [string]: number } = {}

type Row = { id: string, n: any, num: number }
type Entry = { kind: string, key: string, row: Row?, lo: number?, hi: number?, count: number?, fact: string?, fold: number? }

-- ------------------------------------------------------------------------------------------------------ data
local function numOf(n: any, i: number): number
	local v = tonumber(n.id)
	return if v then v + 1 else i
end

local function collect(store: any, id: string): ({ Row }, number?)
	local rows: { Row } = {}
	local ids = Kit.findAll(store, id, function(n: any): boolean
		return n.t == "ms"
	end, 2)
	for i, cid in ids do
		local n = store:get(cid)
		table.insert(rows, { id = cid, n = n, num = numOf(n, i) })
	end
	local nextIdx: number? = nil
	for i, r in rows do
		if not r.n.done then
			nextIdx = i
			break
		end
	end
	return rows, nextIdx
end

-- the first line of a decade that unlocks something (as sent), else nil
local function factOf(rows: { Row }): string?
	for _, r in rows do
		local t = Common.plain(Common.str(r.n.ds) or "")
		t = string.gsub(string.gsub(t, "^%s+", ""), "%s+$", "")
		if string.find(string.lower(t), "^unlock") then
			t = string.gsub(t, "\n.*$", "")
			return t
		end
	end
	return nil
end

-- the collapsed ladder (newest-first semantics; reversed for oldest-first)
local function entries(rows: { Row }, nextIdx: number?, layer: string): ({ Entry }, boolean)
	local out: { Entry } = {}
	local newestFirst = #rows < 2 or rows[1].num > rows[#rows].num
	local byNum = table.clone(rows)
	table.sort(byNum, function(a: Row, b: Row): boolean
		return a.num > b.num
	end)
	local nextRow = if nextIdx then rows[nextIdx] else nil
	-- future rows past NEXT: the two nearest, faint
	if nextRow then
		local ahead: { Row } = {}
		for _, r in byNum do
			if not r.n.done and r ~= nextRow then table.insert(ahead, r) end
		end
		for i = math.max(1, #ahead - 1), #ahead do
			local r = ahead[i]
			if r then table.insert(out, { kind = "future", key = "U" .. r.num, row = r }) end
		end
		table.insert(out, { kind = "next", key = "Next", row = nextRow })
	end
	local done: { Row } = {}
	for _, r in byNum do
		if r.n.done then table.insert(done, r) end
	end
	for i = 1, math.min(4, #done) do
		table.insert(out, { kind = "done", key = "D" .. done[i].num, row = done[i] })
	end
	-- decade folds for the rest: the first three decades, then everything older in one fold
	local rest: { Row } = {}
	for i = 5, #done do table.insert(rest, done[i]) end
	local decades = 0
	local i = 1
	while i <= #rest do
		local dec = (rest[i].num - 1) // 10
		local group: { Row } = {}
		while i <= #rest and (rest[i].num - 1) // 10 == dec do
			table.insert(group, rest[i])
			i += 1
		end
		decades += 1
		if decades > 3 then
			-- the remaining rows (this group and older) in one fold
			local count = #group + (#rest - i + 1)
			local lo = rest[#rest].num
			table.insert(out, { kind = "rest", key = "Rest", lo = lo, hi = group[1].num, count = count })
			break
		end
		local open = openFold[layer] == dec
		table.insert(out, { kind = "fold", key = "F" .. dec, lo = group[#group].num, hi = group[1].num, count = #group,
			fact = factOf(group), fold = dec })
		if open then
			for _, r in group do table.insert(out, { kind = "done", key = "D" .. r.num, row = r }) end
		end
	end
	if not newestFirst then
		local rev: { Entry } = {}
		for k = #out, 1, -1 do table.insert(rev, out[k]) end
		out = rev
	end
	return out, newestFirst
end

-- ------------------------------------------------------------------------------------------------------ row looks
local function dims(): (number, number)
	-- the number gutter, and the NEXT disc
	if Layout.mode == "COMPACT" then return 56, 46 end
	return 92, 78
end

-- NEXT keeps REQUIRES in its own right-hand block only when the card is wide enough (WIDE); else inline
local function narrow(ctx: any): boolean
	return Layout.mode == "COMPACT" or (Kit.live(ctx).contentW or 0) < 1000
end

-- the effect text of a row (the infected split at the game's <hr>)
local function effect(n: any, role: string, layer: string, color: Color3, t: number): string
	local ds = Common.str(n.ds) or ""
	if n.mal and string.find(ds, "<hr", 1, true) then
		local a, b = string.match(ds, "^(.-)<hr[^>]*>(.*)$")
		if a and b then
			local base = Common.html(a, role, layer)
			local mal = Common.html(b, role, layer)
			local parts: { string } = {}
			if base ~= "" then table.insert(parts, string.format('<font color="%s" transparency="%.2f">%s</font>', Common.hex(color), t, base)) end
			if mal ~= "" then table.insert(parts, string.format('<font color="%s">%s</font>', Common.hex(Theme.lift(C.danger, 0.35)), mal)) end
			return table.concat(parts, "\n")
		end
	end
	local body = Common.html(ds, role, layer)
	if body == "" then return "" end
	return string.format('<font color="%s" transparency="%.2f">%s</font>', Common.hex(color), t, body)
end

-- the number pill in the gutter (a child of the card, stepped back out of its padding). NEXT is a glowing radial disc
-- (a Frame: a gradient on a TextLabel would tint its text too) with the number on it; done / future are small pills.
local function pill(card: GuiObject, kind: string, num: number, hue: Color3, padL: number, top: number?)
	local gutter, disc = dims()
	local cx = -padL - gutter / 2
	if kind == "next" then
		Common.drop(card, "Pill")
		local d = Common.get(card, "Disc", "Frame") :: Frame
		d.Active = false
		d.ZIndex = 5
		d.AnchorPoint = Vector2.new(0.5, 0)
		d.Size = UDim2.fromOffset(disc, disc)
		d.Position = UDim2.new(0, cx, 0, top or -6)
		Common.corner(d, 0.5)
		Recipes.radial(d, { { t = 0, c = Theme.lift(hue, 0.55) }, { t = 0.5, c = hue }, { t = 1, c = Theme.shade(hue, 0.5) } })
		Common.corner(d, 0.5)
		Common.stroke(d, 3, Theme.lift(hue, 0.55), 0)
		Common.glow(d, hue, 0.6, 16)
		local t = Common.get(d, "Num", "TextLabel") :: TextLabel
		t.Active = false
		t.ZIndex = 6
		t.Size = UDim2.fromScale(1, 1)
		Common.text(t, "index", C.text)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.TextYAlignment = Enum.TextYAlignment.Center
		t.TextWrapped = false
		local st = Common.stroke(t, 2, C.black, 0, "Stroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		Common.setText(t, tostring(num))
		return
	end
	Common.drop(card, "Disc")
	local p = Common.get(card, "Pill", "TextLabel") :: TextLabel
	p.Active = false
	p.ZIndex = 5
	p.TextXAlignment = Enum.TextXAlignment.Center
	p.TextYAlignment = Enum.TextYAlignment.Center
	p.TextWrapped = false
	p.AnchorPoint = Vector2.new(0.5, 0)
	Common.text(p, "badge", if kind == "done" then C.ownedValue else C.soft)
	p.Size = UDim2.fromOffset(if Layout.mode == "COMPACT" then 40 else 48, 28)
	p.Position = UDim2.new(0, cx, 0, top or 2)
	p.BackgroundColor3 = if kind == "done" then Theme.mix(C.deep, C.bought, 0.22) else C.panel2
	p.BackgroundTransparency = 0
	Common.corner(p, 14)
	Common.stroke(p, 1.5, if kind == "done" then C.bought else C.stroke, if kind == "done" then 0.25 else 0)
	Common.setText(p, tostring(num))
end

-- a quiet row card (done / future): one TextLabel is the card
local function rowCard(parent: Instance, e: Entry, ctx: any, order: number): TextLabel
	local r = e.row :: Row
	local n = r.n
	local done = e.kind == "done"
	local c = Common.get(parent, e.key, "TextLabel") :: TextLabel
	c.LayoutOrder = order
	c.Active = false
	Common.text(c, "small", C.text)
	c.TextWrapped = true
	c.TextXAlignment = Enum.TextXAlignment.Left
	c.TextYAlignment = Enum.TextYAlignment.Top
	c.Size = UDim2.new(1, 0, 0, 0)
	c.AutomaticSize = Enum.AutomaticSize.Y
	Common.drop(c, "Fill")
	c.BackgroundColor3 = if done then Theme.mix(C.panel, C.bought, 0.14) else C.panel2
	c.BackgroundTransparency = 0
	Common.corner(c, 12)
	if n.mal then
		Common.stroke(c, 2, C.danger, 0.1)
	else
		Common.stroke(c, 1, if done then C.bought else C.stroke, if done then 0.6 else 0.3)
	end
	local compact = Layout.mode == "COMPACT"
	local padL = if compact then 12 else 16
	Common.pad(c, 9, 14, 10, padL)
	local title = Common.plain(Common.str(n.ti) or "")
	local parts = { Common.title(title, "cardSmall", if done then C.ownedTitle else C.text) }
	local eff = effect(n, "small", ctx.layer, if done then C.text else C.soft, if done then 0.18 else 0.05)
	if eff ~= "" then table.insert(parts, eff) end
	Common.setText(c, table.concat(parts, "\n"))
	pill(c, e.kind, r.num, ctx.hue, padL)
	Common.state(c, if done then "owned" else "notyet")
	return c
end

-- ------------------------------------------------------------------------------------------------------ the claim
local Ladder = {}
Ladder.__index = Ladder

type LadderT = {
	ph: Frame,
	id: string,
	ctx: any,
	layer: string,
	store: any,
	root: Frame,
	left: Frame,
	rows: Frame,
	side: Frame?,
	virtual: any?,
	conns: { RBXScriptConnection },
	nextId: string?,
	data: { Row },
	nextIdx: number?,
	newestFirst: boolean,
}

local current: any = nil -- the ladder on screen (the hero hook refreshes its REQUIRES block)

-- the NEXT spotlight card
local function nextCard(self: any, parent: Instance, e: Entry, order: number): TextLabel
	local ctx = self.ctx
	local r = e.row :: Row
	local n = r.n
	local compact = Layout.mode == "COMPACT"
	local hue = ctx.hue :: Color3
	local c = Common.get(parent, "Next", "TextLabel") :: TextLabel
	c.LayoutOrder = order
	c.Active = false
	Common.text(c, "body", C.text)
	c.TextWrapped = true
	c.TextXAlignment = Enum.TextXAlignment.Left
	c.TextYAlignment = Enum.TextYAlignment.Top
	c.Size = UDim2.new(1, 0, 0, 0)
	c.AutomaticSize = Enum.AutomaticSize.Y
	Common.drop(c, "Fill")
	c.BackgroundColor3 = Theme.mix(C.panel, hue, 0.34)
	c.BackgroundTransparency = 0
	Common.corner(c, 16)
	Common.stroke(c, 2, if n.mal then C.danger else Theme.lift(hue, 0.35), 0)
	Common.glow(c, hue, 0.45, 18)
	local padL = if compact then 14 else 20
	local isNarrow = narrow(ctx)
	c:SetAttribute("Narrow", isNarrow)
	local reqW = if isNarrow then 0 else 230
	Common.pad(c, 14, 18 + reqW, 14, padL)
	local title = Common.plain(Common.str(n.ti) or "")
	local parts = { Common.caps("Next milestone", C.text), Common.title(title, "card", C.text) }
	local eff = effect(n, "body", ctx.layer, C.text, 0.08)
	if eff ~= "" then table.insert(parts, eff) end
	c:SetAttribute("Base", table.concat(parts, "\n"))
	pill(c, "next", r.num, hue, padL, if compact then -4 else -6)
	Common.state(c, "can")
	self:drawReq(c)
	return c
end

function Ladder.drawReq(self: any, card: TextLabel?)
	local c = card or (self.rows:FindFirstChild("Next") :: TextLabel?)
	if c == nil then return end
	local compact = c:GetAttribute("Narrow") == true
	local pb = Kit.resetNode(self.store)
	local base = c:GetAttribute("Base")
	local text = if type(base) == "string" then base else ""
	local need = if pb then Common.str(pb.next) else nil
	local unit = if pb then Common.plain(Common.str(pb.bres) or "") else ""
	local can = pb ~= nil and pb.cls == "can"
	local pr = if can then 1 elseif pb then Common.pr(pb.pr) else nil
	if compact or need == nil then
		Common.drop(c, "Req")
		Common.drop(c, "Bar")
		Common.drop(c, "Pct")
		if need then
			text ..= "\n" .. Common.caps("Requires", C.text) .. "  " .. Common.num(Rich.short(need), "number", C.text, unit)
			if pr then text ..= "   " .. Common.num(Rich.pct(pr), "number", C.text) end
		end
		Common.setText(c, text)
		return
	end
	Common.setText(c, text)
	local req = Common.get(c, "Req", "TextLabel") :: TextLabel
	req.Active = false
	Common.text(req, "numberHeavy", C.text)
	req.RichText = true
	req.LineHeight = 1.25
	req.AnchorPoint = Vector2.new(1, 0)
	req.Position = UDim2.new(1, 230, 0, 0)
	req.Size = UDim2.fromOffset(214, 48)
	req.TextXAlignment = Enum.TextXAlignment.Right
	req.TextYAlignment = Enum.TextYAlignment.Top
	req.TextWrapped = true
	Common.setText(req, Common.caps("Requires", C.text) .. "\n" .. Common.num(need :: string, "numberHeavy", C.text, unit))
	if pr then
		local bar = Common.bar(c, "Bar", pr, Theme.lift(self.ctx.hue, 0.35), 6)
		bar.AnchorPoint = Vector2.new(1, 0)
		bar.Position = UDim2.new(1, 230 - 60, 0, 60)
		bar.Size = UDim2.fromOffset(150, 6)
		local pct = Common.get(c, "Pct", "TextLabel") :: TextLabel
		pct.Active = false
		Common.text(pct, "number", C.text)
		pct.AnchorPoint = Vector2.new(1, 0)
		pct.Position = UDim2.new(1, 230, 0, 52)
		pct.Size = UDim2.fromOffset(52, 22)
		pct.TextXAlignment = Enum.TextXAlignment.Right
		pct.TextYAlignment = Enum.TextYAlignment.Center
		Common.setText(pct, Common.esc(Rich.pct(pr)))
	else
		Common.drop(c, "Bar")
		Common.drop(c, "Pct")
	end
end

-- a decade fold / the rest fold: one button
local function foldRow(self: any, parent: Instance, e: Entry, order: number): TextButton
	local ctx = self.ctx
	local compact = Layout.mode == "COMPACT"
	local b = Common.get(parent, e.key, "TextButton") :: TextButton
	b.LayoutOrder = order
	b.AutoButtonColor = false
	Common.text(b, "small", C.soft)
	b.TextWrapped = false
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextYAlignment = Enum.TextYAlignment.Center
	b.Size = UDim2.new(1, 0, 0, if compact then 44 else 48)
	b.AutomaticSize = Enum.AutomaticSize.None
	b.BackgroundColor3 = C.panel
	b.BackgroundTransparency = 0
	Common.corner(b, 12)
	local s = Common.stroke(b, 1, C.strokeHi, 0.2)
	Recipes.dashed(s, { color = C.strokeHi, alpha = 0.8 })
	local padL = if compact then 12 else 16
	Common.pad(b, 0, 14, 0, padL)
	local open = e.kind == "fold" and openFold[ctx.layer] == e.fold
	local chev = Common.run(if open then "–" else "›", "label", Theme.lift(ctx.hue, 0.45))
	local range = Common.num((e.lo :: number) .. " – " .. (e.hi :: number), "number", C.text)
	local count = Common.run(tostring(e.count), "badge", C.ownedValue)
	local text = chev .. "   " .. range .. "   " .. count
	if e.kind == "rest" then
		text ..= "      " .. Common.run(Common.esc("Show all"), "label", Theme.lift(ctx.hue, 0.45))
	elseif e.fact and not compact then
		text ..= "    " .. Common.esc(e.fact :: string)
	end
	Common.setText(b, text)
	-- the dot on the spine
	local gutter = (dims())
	local dot = Common.get(b, "Dot", "Frame") :: Frame
	dot.Active = false
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(0, -padL - gutter / 2, 0.5, 0)
	dot.Size = UDim2.fromOffset(10, 10)
	dot.BackgroundColor3 = C.bought
	dot.BackgroundTransparency = 0.2
	dot.ZIndex = 5
	Common.corner(dot, 0.5)
	Common.state(b, "owned")
	local layer = ctx.layer
	Kit.onPress(b, function()
		if e.kind == "rest" then
			showAll[layer] = true
		elseif openFold[layer] == e.fold then
			openFold[layer] = nil
		else
			openFold[layer] = e.fold :: number
		end
		self:draw()
	end)
	return b
end

function Ladder.new(ph: Frame, id: string, store: any, ctx: any): any
	local self = setmetatable({
		ph = ph,
		id = id,
		ctx = ctx,
		layer = ctx.layer,
		store = store,
		virtual = nil,
		conns = {},
		nextId = nil,
		data = {},
		nextIdx = nil,
		newestFirst = true,
	}, Ladder) :: any
	ph.Size = UDim2.new(1, 0, 0, 0)
	ph.AutomaticSize = Enum.AutomaticSize.Y
	ph.BackgroundTransparency = 1
	Common.list(ph, false, if Layout.mode == "COMPACT" then 10 else 14)
	current = self
	return self
end

-- the body: [left: spine + rows] [side] (WIDE) or one column (COMPACT)
function Ladder.frame(self: any)
	local compact = Layout.mode == "COMPACT"
	local ph = self.ph
	local body = Common.get(ph, "Body", "Frame") :: Frame
	body.LayoutOrder = 2
	body.Active = false
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	Common.list(body, true, 22, { valign = Enum.VerticalAlignment.Top })
	local sideW = if compact then 0 else 290
	local left = Common.get(body, "Left", "Frame") :: Frame
	left.LayoutOrder = 1
	left.Active = false
	left.AutomaticSize = Enum.AutomaticSize.None
	left.ClipsDescendants = true
	local rows = Common.get(left, "Rows", "Frame") :: Frame
	rows.Active = false
	rows.ZIndex = 2
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	local gutter = (dims())
	Common.list(rows, false, 10)
	Common.pad(rows, 8, 0, 8, gutter)
	-- the left column follows the rows' height (no automatic size, so the spine can use Scale)
	self.sideW = sideW
	local function fit()
		local s = math.max(Layout.s, 0.01)
		local sw = self.sideW :: number
		left.Size = UDim2.new(1, -(sw + (if sw > 0 then 22 else 0)), 0, math.ceil(rows.AbsoluteSize.Y / s))
	end
	if #self.conns == 0 then
		table.insert(self.conns, rows:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	end
	fit()
	-- the spine: behind the rows, glowing in the hue
	local spine = Common.get(left, "Spine", "Frame") :: Frame
	spine.Active = false
	spine.ZIndex = 1
	spine.AnchorPoint = Vector2.new(0.5, 0)
	spine.Position = UDim2.fromOffset(gutter / 2, 30)
	spine.Size = UDim2.new(0, 3, 1, -50)
	spine.BackgroundColor3 = self.ctx.hue
	spine.BackgroundTransparency = 0
	local sg = Common.get(spine, "Fade", "UIGradient") :: UIGradient
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	Common.glow(spine, self.ctx.hue, 0.5, 10)
	self.left, self.rows = left, rows
	if compact then
		Common.drop(body, "Side")
		self.side = nil
	else
		local side = Common.get(body, "Side", "Frame") :: Frame
		side.LayoutOrder = 2
		side.Active = false
		side.Size = UDim2.fromOffset(sideW, 0)
		side.AutomaticSize = Enum.AutomaticSize.Y
		Common.list(side, false, 14)
		self.side = side
	end
end

-- the notes: the display-text siblings of the ladder (their own frames are claimed away, see M.note)
local function notesOf(store: any, id: string): { string }
	local out: { string } = {}
	local pid = Common.parentId(id)
	if pid == nil then return out end
	for _, cid in store:kids(pid) do
		local n = store:get(cid)
		if type(n) == "table" and n.cn == "display-text" and type(n.h) == "string" and string.find(Common.plain(n.h), "%S") then
			table.insert(out, n.h)
		end
	end
	return out
end

function Ladder.drawNotes(self: any, parent: Instance, order: number)
	local notes = notesOf(self.store, self.id)
	if #notes == 0 then
		Common.drop(parent, "Notes")
		return
	end
	local card = Kit.card(parent, "Notes", { order = order, gap = 8, pad = 14 })
	local head = Common.label(card, "Head", "caps", C.soft, { order = 1, wrap = false })
	Common.setText(head, Common.caps("Notes"))
	local body = Common.label(card, "Text", "body", C.text, { order = 2 })
	Theme.text(body, "small")
	local bullet = Common.run("•", "label", Theme.textHue(self.layer))
	local lines: { string } = {}
	for _, h in notes do
		table.insert(lines, bullet .. "  " .. Common.html(h, "small", self.layer))
	end
	Common.setText(body, table.concat(lines, "\n"))
end

-- JUMP TO (WIDE): NEXT, the 25-row blocks, MALWARE; then the order button
function Ladder.drawSide(self: any, malware: boolean)
	local side = self.side
	if side == nil then return end
	self:drawNotes(side, 1)
	local card = Kit.card(side, "Jump", { order = 2, gap = 6, pad = 12 })
	local head = Common.label(card, "Head", "caps", C.soft, { order = 1, wrap = false })
	Common.setText(head, Common.caps("Jump to"))
	local hue = self.ctx.hue :: Color3
	local used: { [string]: boolean } = { Head = true }
	local k = 1
	local function jump(name: string, text: string, lit: boolean, fn: () -> ())
		k += 1
		used[name] = true
		local b = Kit.button(card, name, text, { fill = if lit then Theme.mix(C.panel, hue, 0.55) else C.panel3, ink = C.text,
			stroke = if lit then Theme.lift(hue, 0.35) else nil, h = 38, w = 1, order = k, align = Enum.TextXAlignment.Left })
		Common.state(b, "can")
		Kit.onPress(b, fn)
	end
	local nextRow = if self.nextIdx then self.data[self.nextIdx] else nil
	if nextRow then
		jump("Next", Common.run(Common.esc("Next"), "label", C.text) .. Common.run(" · ", "label", C.soft)
			.. Common.num(tostring(nextRow.num), "number", C.text), true, function()
			Kit.scrollTo(self.ctx, self.rows:FindFirstChild("Next") :: GuiObject?, 16)
		end)
	end
	-- 25-row blocks under the newest done row (the last block takes the rest)
	local top = 0
	for _, r in self.data do
		if r.n.done and r.num > top then top = r.num end
	end
	local blocks = 0
	local hi = top
	while hi >= 1 and blocks < 5 do
		blocks += 1
		local lo = math.max(1, ((hi - 1) // 25) * 25 + 1)
		if blocks == 5 then lo = 1 end
		local bhi = hi
		jump("B" .. blocks, Common.num(lo .. " – " .. bhi, "number", C.text), false, function()
			self:jumpTo(bhi)
		end)
		hi = lo - 1
	end
	if malware then
		jump("Malware", Common.run(Common.esc("Malware"), "label", Theme.lift(C.danger, 0.35)), false, function()
			Kit.scrollTo(self.ctx, self.ph:FindFirstChild("Malware") :: GuiObject?, 16)
		end)
	end
	for _, c in card:GetChildren() do
		if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
	end
	-- the order button: opens Options (the map's own `opt` action)
	local opt = self.store:map().opt
	if opt then
		local order = if self.newestFirst then "Newest first" else "Oldest first"
		local b = Kit.button(side, "Order", Common.run(Common.esc("Order: "), "label", C.soft) .. Common.run(Common.esc(order), "label", C.text)
			.. Common.run("  ›", "label", C.soft), { fill = C.panel2, stroke = C.stroke, h = 40, w = 1, order = 3, align = Enum.TextXAlignment.Left })
		Common.state(b, "can")
		Kit.onPress(b, function()
			local a = self.store:map().opt
			if a then self.ctx.act(a, false) end
		end)
	else
		Common.drop(side, "Order")
	end
end

-- open SHOW ALL and scroll to a milestone number
function Ladder.jumpTo(self: any, num: number)
	showAll[self.layer] = true
	self:draw()
	task.defer(function()
		local v = self.virtual
		local sf = self.ctx.scroll :: ScrollingFrame?
		if v == nil or sf == nil or not self.ph.Parent then return end
		local idx = 1
		for i, r in self.data do
			if r.num == num then idx = i end
		end
		local order = self:allOrder()
		for i, k in order do
			if k == idx then idx = i end
		end
		local s = math.max(Layout.s, 0.01)
		local host = v.o.host :: Frame
		local y = sf.CanvasPosition.Y + (host.AbsolutePosition.Y - sf.AbsolutePosition.Y) / s + (idx - 1) * v:pitch() - 12
		sf.CanvasPosition = Vector2.new(0, math.max(0, y))
	end)
end

-- SHOW ALL order: every row but NEXT, in the game's order
function Ladder.allOrder(self: any): { number }
	local out: { number } = {}
	for i = 1, #self.data do
		if i ~= self.nextIdx then table.insert(out, i) end
	end
	return out
end

-- the expanded list: NEXT, the virtual pool, "Show less"
function Ladder.drawAll(self: any)
	local rows = self.rows
	local used: { [string]: boolean } = {}
	local nextRow = if self.nextIdx then self.data[self.nextIdx] else nil
	local order = 0
	if nextRow and self.newestFirst then
		order += 1
		used.Next = true
		nextCard(self, rows, { kind = "next", key = "Next", row = nextRow }, order)
	end
	order += 1
	used.All = true
	local host = Common.get(rows, "All", "Frame") :: Frame
	host.LayoutOrder = order
	host.Active = false
	local list = self:allOrder()
	if self.virtual == nil then
		local compact = Layout.mode == "COMPACT"
		self.virtual = Virtual.new({
			scroll = self.ctx.scroll,
			host = host,
			top = 0,
			rowH = if compact then 60 else 64,
			gap = 8,
			count = #list,
			draw = function(row: Frame, i: number)
				local idxs = self:allOrder()
				local r = self.data[idxs[i]]
				if r == nil then
					row.Visible = false
					return
				end
				self:drawVirtualRow(row, r)
			end,
		})
	else
		self.virtual:setCount(#list)
		self.virtual:redraw()
	end
	if nextRow and not self.newestFirst then
		order += 1
		used.Next = true
		nextCard(self, rows, { kind = "next", key = "Next", row = nextRow }, order)
	end
	order += 1
	used.Less = true
	local less = Kit.button(rows, "Less", Common.run("–", "label", Theme.lift(self.ctx.hue, 0.45)) .. "   "
		.. Common.run(Common.esc("Show less"), "label", C.text), { fill = C.panel, stroke = C.strokeHi, h = 44, order = order })
	Common.state(less, "can")
	Kit.onPress(less, function()
		showAll[self.layer] = false
		self:draw()
	end)
	for _, c in rows:GetChildren() do
		if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
	end
end

-- one pooled row of SHOW ALL (the pool frame is the card)
function Ladder.drawVirtualRow(self: any, row: Frame, r: Row)
	local n = r.n
	local done = n.done == true
	row.BackgroundColor3 = if done then Theme.mix(C.panel, C.bought, 0.14) else C.panel2
	row.BackgroundTransparency = 0
	Common.corner(row, 12)
	Common.stroke(row, if n.mal then 2 else 1, if n.mal then C.danger elseif done then C.bought else C.stroke, if n.mal then 0.1 elseif done then 0.6 else 0.3)
	local t = Common.get(row, "Text", "TextLabel") :: TextLabel
	t.Active = false
	Common.text(t, "small", C.text)
	t.Position = UDim2.fromOffset(16, 6)
	t.Size = UDim2.new(1, -30, 1, -12)
	t.AutomaticSize = Enum.AutomaticSize.None
	t.TextWrapped = true
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	local title = Common.plain(Common.str(n.ti) or "")
	local parts = { Common.title(title, "cardSmall", if done then C.ownedTitle else C.text) }
	local eff = effect(n, "small", self.layer, if done then C.text else C.soft, if done then 0.18 else 0.05)
	if eff ~= "" then table.insert(parts, eff) end
	Common.setText(t, table.concat(parts, "\n"))
	pill(row, if done then "done" else "future", r.num, self.ctx.hue, 0, 18)
end

-- the collapsed ladder
function Ladder.drawCollapsed(self: any)
	if self.virtual then
		self.virtual:destroy()
		self.virtual = nil
	end
	local rows = self.rows
	local list = entries(self.data, self.nextIdx, self.layer)
	local used: { [string]: boolean } = {}
	for i, e in list do
		used[e.key] = true
		if e.kind == "next" then
			nextCard(self, rows, e, i)
		elseif e.kind == "fold" or e.kind == "rest" then
			foldRow(self, rows, e, i)
		else
			rowCard(rows, e, self.ctx, i)
		end
	end
	for _, c in rows:GetChildren() do
		if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
	end
end

-- MALWARE (m): the rows with an INFECT button, each firing the malware node's own action
function Ladder.drawMalware(self: any): boolean
	local store = self.store
	local found: { { row: Row, mid: string, m: any } } = {}
	for _, r in self.data do
		for _, kid in store:kids(r.id) do
			local k = store:get(kid)
			if type(k) == "table" and k.t == "btn" and k.k == "malware" then
				table.insert(found, { row = r, mid = kid, m = k })
				break
			end
		end
	end
	if #found == 0 then
		Common.drop(self.ph, "Malware")
		return false
	end
	local compact = Layout.mode == "COMPACT"
	local sec = Common.get(self.ph, "Malware", "Frame") :: Frame
	sec.LayoutOrder = 3
	sec.Active = false
	sec.Size = UDim2.new(1, 0, 0, 0)
	sec.AutomaticSize = Enum.AutomaticSize.Y
	Common.list(sec, false, 10)
	local infectable = 0
	for _, f in found do
		if f.m.cls ~= "pseudo" then infectable += 1 end
	end
	Sections.header(sec, { name = "Head", text = "MALWARE", hue = C.danger, order = 0,
		chips = { { text = infectable .. " infectable", color = C.dangerText, bg = Theme.mix(C.deep, C.danger, 0.3), bgT = 0 } } })
	local used: { [string]: boolean } = { Head = true }
	for i, f in found do
		local name = "M" .. f.row.num
		used[name] = true
		local row = Common.get(sec, name, "Frame") :: Frame
		row.LayoutOrder = i
		row.Active = false
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundColor3 = C.panel2
		row.BackgroundTransparency = 0
		Common.corner(row, 12)
		local infected = f.m.cls == "pseudo"
		local can = f.m.cls == "can"
		Common.stroke(row, if can then 2 else 1, C.danger, if can then 0.1 elseif infected then 0.35 else 0.6)
		Common.pad(row, 10, 14, 10, 16)
		local t = Common.label(row, "Text", "small", C.text, { order = 1 })
		local btnW = if compact then 150 else 190
		t.Size = UDim2.new(1, -(btnW + 12), 0, 0)
		local title = Common.plain(Common.str(f.row.n.ti) or "")
		local eff = effect(f.row.n, "small", self.layer, C.soft, 0)
		Common.setText(t, Common.title(title, "cardSmall", C.text) .. (if eff ~= "" then "\n" .. eff else ""))
		local b = Common.get(row, "Infect", "TextButton") :: TextButton
		b.AutoButtonColor = false
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, 0, 0, 0)
		b.Size = UDim2.fromOffset(btnW, 44)
		Common.text(b, "label", C.text)
		b.TextWrapped = false
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.TextYAlignment = Enum.TextYAlignment.Center
		b.BackgroundColor3 = if infected then Theme.mix(C.panel, C.danger, 0.3) elseif can then C.danger else Theme.mix(C.panel, C.locked, 0.3)
		b.BackgroundTransparency = 0
		Common.corner(b, 10)
		local co = Common.str(f.m.co)
		local label = if infected then Common.esc("INFECTED") else Common.esc("INFECT")
		if co and not infected then label ..= "  " .. Common.num(Rich.short(co), "number", C.text) end
		Common.setText(b, label)
		Common.state(b, if infected then "owned" elseif can then "can" else "notyet")
		local mid = f.mid
		Kit.onPress(b, function()
			local m = self.store:get(mid)
			if type(m) == "table" and type(m.a) == "table" then self.ctx.act(m.a, false) end
		end)
	end
	for _, c in sec:GetChildren() do
		if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
	end
	return true
end

function Ladder.draw(self: any)
	if not self.ph.Parent then return end
	local compact = Layout.mode == "COMPACT"
	local rows, nextIdx = collect(self.store, self.id)
	self.data, self.nextIdx = rows, nextIdx
	self.newestFirst = #rows < 2 or rows[1].num > rows[#rows].num
	-- the header: the ladder's name and done / total
	local done = 0
	for _, r in rows do
		if r.n.done then done += 1 end
	end
	Sections.header(self.ph, { name = "Head", order = 1, text = Sections.titleOf("milestones", self.layer) or "MILESTONES", hue = self.ctx.hue,
		chips = { { text = done .. " / " .. #rows .. " DONE", color = C.ownedValue, bg = Theme.mix(C.deep, C.bought, 0.16), bgT = 0 } } })
	self:frame()
	-- COMPACT: the notes sit on top of the ladder
	if compact then
		self:drawNotes(self.ph, 0)
	else
		Common.drop(self.ph, "Notes")
	end
	if showAll[self.layer] then self:drawAll() else self:drawCollapsed() end
	local malware = self:drawMalware()
	self:drawSide(malware)
	-- a new milestone: the NEXT card flashes (keyed by the layer, never on the first sight)
	local nextRow = if nextIdx then rows[nextIdx] else nil
	local nid = if nextRow then tostring(nextRow.n.id) else nil
	local key = "ladder:" .. self.layer
	local first = self.ctx.firstSeen(key)
	if nid ~= self.nextId then
		local had = self.nextId ~= nil
		self.nextId = nid
		local card = self.rows:FindFirstChild("Next") :: GuiObject?
		if had and not first and card then
			Motion.flash(card)
			Motion.bump(card, 0.05)
		end
	end
	current = self
end

function Ladder.update(self: any, store: any)
	self.store = store or self.store
	local ok, err = Common.try(function()
		self:draw()
	end)
	if not ok then warn("[MilestoneTree] ladder failed: " .. tostring(err)) end
end

function Ladder.destroy(self: any)
	for _, c in self.conns do c:Disconnect() end
	table.clear(self.conns)
	if self.virtual then
		self.virtual:destroy()
		self.virtual = nil
	end
	if current == self then current = nil end
	for _, name in { "Head", "Body", "Notes", "Malware" } do Common.drop(self.ph, name) end
end

-- ------------------------------------------------------------------------------------------------------ notes claim
-- the ladder's display-text siblings move into its NOTES card; a display-text with no ladder next to it stays a
-- NOTES row (drawn here, the look of Skins/Generic)
local function note(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	local function hasLadder(st: any): boolean
		local pid = Common.parentId(id)
		if pid == nil then return false end
		for _, cid in st:kids(pid) do
			local n = st:get(cid)
			if type(n) == "table" and n.cn == "milestones" then return true end
		end
		return false
	end
	function claim.update(_: any, st: any)
		local n = st:get(id)
		local text = if type(n) == "table" then Common.plain(n.h) else ""
		if hasLadder(st) or not string.find(text, "%S") then
			ph.Visible = false
			ph.Size = UDim2.new()
			ph.AutomaticSize = Enum.AutomaticSize.None
			Common.drop(ph, "Text")
			return
		end
		ph.Visible = true
		ph.Size = UDim2.new(1, 0, 0, 0)
		ph.AutomaticSize = Enum.AutomaticSize.Y
		ph.BackgroundColor3 = C.panel2
		ph.BackgroundTransparency = 0
		Common.corner(ph, 10)
		Common.pad(ph, 10, 14, 10, 16)
		local l = Common.label(ph, "Text", "body", C.text)
		l.TextTransparency = 0.08
		Common.setText(l, Common.html(n.h, "body", ctx.layer))
	end
	function claim.destroy(_: any)
		Common.drop(ph, "Text")
	end
	claim.update(claim, store)
	return claim
end

-- ------------------------------------------------------------------------------------------------------ signatures
local function ladderClaim(ph: Frame, id: string, store: any, ctx: any): any
	return Ladder.new(ph, id, store, ctx)
end

-- the hero hook runs whenever the prestige button changes: the NEXT card's REQUIRES follows it
local function hero(_: Frame, store: any, ctx: any)
	local l = current
	if l and l.ph.Parent and l.layer == ctx.layer then
		l.store = store
		l:drawReq()
	end
end

local function accent(mark: string?): ((sheet: Frame, ctx: any) -> ())?
	if mark == nil then return nil end
	return function(sheet: Frame, ctx: any)
		local band = Kit.band(sheet)
		if band == nil then return end
		local a = Kit.accent(band, "M" .. (mark :: string))
		Kit.watermark(a, mark :: string, Theme.lift(ctx.hue, 0.3), 0.09)
	end
end

-- pm: the glitch title (R12): red / cyan clones behind the real title (in the band's accent, so they draw under it)
local function glitch(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	local title = sheet:FindFirstChild("Title")
	if band == nil or title == nil or not title:IsA("TextLabel") then return end
	local a = Kit.accent(band, "Mpm")
	Kit.stripes(a, Theme.lift(ctx.hue, 0.2), 0.05, 22)
	local g = Common.get(a, "Glitch", "TextLabel") :: TextLabel
	g.Active = false
	g.Position = title.Position
	g.Size = title.Size
	g.AutomaticSize = title.AutomaticSize
	g.FontFace = title.FontFace
	g.TextSize = title.TextSize
	g.TextXAlignment = title.TextXAlignment
	g.TextYAlignment = title.TextYAlignment
	g.TextWrapped = false
	g.Text = title.Text
	Recipes.glitch(g, { min = 2, max = 4 })
	local fill = g:FindFirstChild("Fill")
	if fill and fill:IsA("TextLabel") then fill.TextTransparency = 1 end
end

local CLAIMS = {
	{ match = { cn = "milestones" }, make = ladderClaim },
	{ match = { cn = "display-text" }, make = note },
}

local function sig(layers: { string }, mark: string?, extra: { [string]: any }?): any
	local s: any = {
		layers = layers,
		claims = CLAIMS,
		hero = hero,
		accent = accent(mark),
	}
	if extra then
		for k, v in extra do s[k] = v end
	end
	return s
end

local M = {
	sig({ "m" }, nil),
	sig({ "mm" }, "M²"),
	sig({ "em" }, "M³"),
	sig({ "cm" }, nil, { corrupted = true, hug = true }),
	sig({ "pm" }, nil, { accent = glitch }),
}
M.Ladder = Ladder
M.ladderClaim = ladderClaim
M.noteClaim = note
M.hero = hero
-- forget the session memory (tests)
function M.resetMemory()
	table.clear(showAll)
	table.clear(openFold)
end
M.unit = Signatures.unit
return M
