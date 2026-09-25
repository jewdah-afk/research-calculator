--!strict
--[[
	Ex: Exploration (DESIGN.md 6 row ex, 6.1 "ex").

	    hero       ZONE, AREA LIMITS and the next feature's spot as chips under the CTA (the game's line, as sent;
	               coordinates "(9;5)" read "9, 5")
	    accent     green cartography: a faint grid over the header band
	    Main       the EXPLORER: the zone map and the D-pad side by side (stacked on phones)
	               map    the ZoneMaps drawing as Frames (cell lines, border, axis numbers), CACHED by the svg's static
	                      content: when only the position or the goal moves, nothing is rebuilt; the green position gem
	                      hops (0.15 s Back Out), the goal is a gold diamond
	               D-pad  the 4 movement buyables as arrow keys around RESPEC POSITION: arrow + direction, the level badge
	                      ("→ 6"), the cost in a well (short unit; "Free" when the game says so); hold to repeat like every
	                      buyable, and the centre key fires the respec node's own action
	The map's display-text line leaves the body (the explorer draws it); the explainer stays a note.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Sections = require(PanelF:WaitForChild("Sections"))
local Signatures = require(script.Parent:WaitForChild("Signatures"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P
local Shared = ReplicatedStorage:WaitForChild("MilestoneTree")
local Html = require(Shared:WaitForChild("Html"))
local ZoneMaps = require(Shared:WaitForChild("ZoneMaps")) :: any

local C = Theme.C
local HUE = Theme.hue("ex")

local function trim(s: string): string
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end
local function isSvg(n: any): boolean
	return type(n) == "table" and type(n.h) == "string" and string.find(n.h, "<svg", 1, true) ~= nil
end

-- ------------------------------------------------------------------------------------------------------ the map
type Explorer = {
	ph: Frame,
	id: string,
	ctx: any,
	store: any,
	lastH: string?,
	lastKey: string?,
	builds: number,
	gemAt: Vector2?,
}

local current: any = nil -- the explorer on screen (the map line's claim wakes it)

local function scaleOf(): number
	return if Layout.mode == "COMPACT" then 0.9 else 1.25
end

-- the static part of a parsed svg (what the cache is keyed by) and its moving marks
local function split(svg: any): (string, { any }, { any })
	local axis: { any } = {}
	local marks: { any } = {}
	local seen: { [string]: boolean } = {}
	for _, t in svg.texts do
		local text = trim(tostring(t.text))
		local key = t.x .. "," .. t.y .. "," .. text
		if seen[key] then continue end
		seen[key] = true
		if string.find(text, "^%d+$") or text == "X" or text == "Y" then
			table.insert(axis, t)
		else
			table.insert(marks, t)
		end
	end
	local parts = { tostring(svg.bg), tostring(svg.w), tostring(svg.h) }
	for _, t in axis do table.insert(parts, t.x .. "," .. t.y .. "," .. t.text) end
	return table.concat(parts, "|"), axis, marks
end

local function lineColor(hex: string): Color3
	local h = string.lower(hex)
	if h == "ff0000" then return C.danger end
	if h == "26ff00" then return HUE end
	return Theme.mix(C.deep, HUE, 0.3)
end

local function buildStatic(canvas: Frame, svg: any, axis: { any }, k: number)
	local st = Common.get(canvas, "Static", "Frame") :: Frame
	for _, c in st:GetChildren() do c:Destroy() end
	st.Active = false
	st.BackgroundTransparency = 1
	st.Size = UDim2.fromScale(1, 1)
	local lines = if svg.bg then ZoneMaps[svg.bg] else nil
	if type(lines) == "table" then
		for i, ln in lines do
			local x1, y1, x2, y2, col, w = ln[1], ln[2], ln[3], ln[4], ln[5], ln[6]
			local f = Instance.new("Frame")
			f.Name = "L" .. i
			f.BorderSizePixel = 0
			f.Active = false
			f.BackgroundColor3 = lineColor(tostring(col))
			f.BackgroundTransparency = if string.lower(tostring(col)) == "262626" then 0.2 else 0
			local ww = math.max(2, w * k)
			f.Position = UDim2.fromOffset(math.min(x1, x2) * k - ww / 2, math.min(y1, y2) * k - ww / 2)
			f.Size = UDim2.fromOffset(math.abs(x2 - x1) * k + ww, math.abs(y2 - y1) * k + ww)
			f.Parent = st
		end
	end
	for i, t in axis do
		local l = Instance.new("TextLabel")
		l.Name = "A" .. i
		l.Active = false
		l.BackgroundTransparency = 1
		Common.text(l, "number", C.termDim)
		if t.text == "X" or t.text == "Y" then Common.text(l, "label", C.termLime) end
		l.AnchorPoint = Vector2.new(0, 1)
		l.Position = UDim2.fromOffset(t.x * k, (t.y + 3) * k)
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.new()
		l.Text = t.text
		l.Parent = st
	end
end

-- a mark's centre in the svg (text baseline -> glyph centre)
local function centre(t: any): Vector2
	local size = tonumber(t.size) or 12
	return Vector2.new(t.x + 0.6 * size, t.y - 0.35 * size)
end

local function drawMap(self: any, parent: Instance, n: any)
	local compact = Layout.mode == "COMPACT"
	local k = scaleOf()
	local card = Common.get(parent, "Map", "Frame") :: Frame
	card.LayoutOrder = 1
	card.Active = false
	if n == nil then
		card.Visible = false
		return
	end
	card.Visible = true
	local h = n.h :: string
	if h == self.lastH and card:FindFirstChild("Canvas") then return end
	self.lastH = h
	local svg: any = nil
	for _, part in Html.split(h) do
		if type(part) == "table" then
			svg = part
			break
		end
	end
	if svg == nil then return end
	local key, axis, marks = split(svg)
	key ..= "|" .. tostring(k)
	card.BackgroundColor3 = Color3.fromRGB(5, 16, 9)
	card.BackgroundTransparency = 0
	card.Size = UDim2.fromOffset(math.floor(svg.w * k) + 24, math.floor(svg.h * k) + 48)
	Common.corner(card, 14)
	Common.stroke(card, 1.5, HUE, 0.45)
	local canvas = Common.get(card, "Canvas", "Frame") :: Frame
	canvas.Active = false
	canvas.BackgroundTransparency = 1
	canvas.Position = UDim2.fromOffset(12, 8)
	canvas.Size = UDim2.fromOffset(math.floor(svg.w * k), math.floor(svg.h * k))
	canvas.ClipsDescendants = true
	if key ~= self.lastKey then
		self.lastKey = key
		self.builds += 1
		card:SetAttribute("Builds", self.builds)
		buildStatic(canvas, svg, axis, k)
	end
	-- the moving marks: the position gem, the goal diamond, anything else (portals) as small discs
	local usedMarks: { [string]: boolean } = {}
	local others = 0
	for _, t in marks do
		local text = trim(tostring(t.text))
		local c = centre(t) * k
		local color = if t.color then Color3.fromHex(t.color) else C.text
		local isGoal = text == "★" or string.find(string.lower(tostring(t.color)), "ffff00", 1, true) ~= nil
		local isGem = not isGoal and (text == "🟢" or color.G > color.R + 0.2)
		if isGem then
			usedMarks.Gem = true
			local gem = Common.get(canvas, "Gem", "Frame") :: Frame
			gem.Active = false
			gem.ZIndex = 4
			gem.AnchorPoint = Vector2.new(0.5, 0.5)
			gem.Size = UDim2.fromOffset(18, 18)
			gem.BackgroundColor3 = Theme.lift(HUE, 0.2)
			gem.BackgroundTransparency = 0
			Common.corner(gem, 0.5)
			Common.stroke(gem, 2, C.white, 0)
			Common.glow(gem, HUE, 0.7, 12)
			local target = UDim2.fromOffset(c.X, c.Y)
			local prev = self.gemAt
			self.gemAt = c
			if prev and prev ~= c then
				Motion.tween(gem, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target }, "ex:gem")
			else
				gem.Position = target
			end
		elseif isGoal then
			usedMarks.Goal = true
			local star = Common.get(canvas, "Goal", "Frame") :: Frame
			star.Active = false
			star.ZIndex = 3
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Rotation = 45
			star.Size = UDim2.fromOffset(15, 15)
			star.Position = UDim2.fromOffset(c.X, c.Y)
			star.BackgroundColor3 = C.gold
			star.BackgroundTransparency = 0
			Common.corner(star, 3)
			Common.glow(star, C.gold, 0.6, 12)
		elseif others < 6 then
			others += 1
			local name = "Mark" .. others
			usedMarks[name] = true
			local m = Common.get(canvas, name, "Frame") :: Frame
			m.Active = false
			m.ZIndex = 3
			m.AnchorPoint = Vector2.new(0.5, 0.5)
			m.Size = UDim2.fromOffset(14, 14)
			m.Position = UDim2.fromOffset(c.X, c.Y)
			m.BackgroundColor3 = Theme.lift(Theme.hue("mp"), 0.2)
			m.BackgroundTransparency = 0
			Common.corner(m, 0.5)
		end
	end
	for _, name in { "Gem", "Goal", "Mark1", "Mark2", "Mark3", "Mark4", "Mark5", "Mark6" } do
		if not usedMarks[name] then Common.drop(canvas, name) end
	end
	-- the legend under the drawing
	local legend = Common.get(card, "Legend", "TextLabel") :: TextLabel
	legend.Active = false
	Common.text(legend, "small", C.soft)
	legend.AnchorPoint = Vector2.new(0, 1)
	legend.Position = UDim2.new(0, 14, 1, -8)
	legend.Size = UDim2.new(1, -28, 0, 22)
	legend.TextXAlignment = Enum.TextXAlignment.Left
	legend.TextYAlignment = Enum.TextYAlignment.Center
	legend.TextWrapped = false
	Common.setText(legend, Common.run("•", "label", Theme.lift(HUE, 0.2)) .. Common.esc(" You are here     ")
		.. Common.run("•", "label", C.gold) .. Common.esc(if compact then " Feature" else " Next feature"))
end

-- ------------------------------------------------------------------------------------------------------ the D-pad
local DIRS: { [string]: { arrow: string, word: string, col: number, row: number } } = {
	["Increase X"] = { arrow = "→", word = "Right", col = 3, row = 2 },
	["Decrease X"] = { arrow = "←", word = "Left", col = 1, row = 2 },
	["Increase Y"] = { arrow = "↓", word = "Down", col = 2, row = 3 },
	["Decrease Y"] = { arrow = "↑", word = "Up", col = 2, row = 1 },
}

local function drawPad(self: any, parent: Instance)
	local st = self.store
	local ctx = self.ctx
	local compact = Layout.mode == "COMPACT"
	local kw, kh, gap = (if compact then 100 else 132), (if compact then 88 else 112), 10
	local pad = Common.get(parent, "Pad", "Frame") :: Frame
	pad.LayoutOrder = 2
	pad.Active = false
	pad.BackgroundTransparency = 1
	pad.Size = UDim2.fromOffset(3 * kw + 2 * gap, 3 * kh + 2 * gap)
	local buys = Kit.findAll(st, self.id, function(n: any): boolean
		return n.t == "btn" and n.k == "buy"
	end, 3)
	local respec = Kit.find(st, self.id, function(n: any): boolean
		return n.t == "btn" and n.k == "respec"
	end, 2)
	local used: { [string]: boolean } = {}
	local function place(g: GuiObject, col: number, row: number)
		g.Position = UDim2.fromOffset((col - 1) * (kw + gap), (row - 1) * (kh + gap))
		g.Size = UDim2.fromOffset(kw, kh)
	end
	for _, bid in buys do
		local n = st:get(bid)
		local ti = trim(Common.plain(Common.str(n.ti) or ""))
		local dir = DIRS[ti]
		if dir == nil then continue end
		local name = "Key" .. dir.word
		used[name] = true
		local can = n.cls == "can"
		local b = Common.get(pad, name, "TextButton") :: TextButton
		b.AutoButtonColor = false
		place(b, dir.col, dir.row)
		b.BackgroundColor3 = if can then Theme.mix(C.panel, HUE, 0.42) else Theme.mix(C.panel, C.locked, 0.22)
		b.BackgroundTransparency = 0
		Common.corner(b, 14)
		Common.stroke(b, if can then 2 else 1.5, if can then Theme.lift(HUE, 0.35) else C.locked, if can then 0 else 0.35)
		Common.glow(b, if can then HUE else nil, 0.45, 12)
		Common.pad(b, if compact then 12 else 16, 6, 0, 6)
		Common.text(b, "label", C.text)
		b.TextWrapped = false
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.TextYAlignment = Enum.TextYAlignment.Top
		b.LineHeight = 1.15
		Common.setText(b, Common.run(dir.arrow, "cta", C.text) .. "\n" .. Common.run(Common.esc(dir.word), "label", C.text))
		-- the level badge and the cost well
		local lv = Common.str(n.lv) or "0"
		local badge = Common.chip(b, "Level", Common.run(dir.arrow, "label", C.soft) .. " " .. Common.num(lv, "badge", C.text),
			{ rich = true, bg = C.deep, bgT = 0.1, h = 24 })
		badge.AnchorPoint = Vector2.new(0, 0)
		badge.Position = UDim2.fromOffset(-2, if compact then -8 else -10)
		local plain = Common.plain(n.h or "")
		local cost: string
		if string.find(plain, "without a cost", 1, true) then
			cost = Common.run(Common.esc("Free"), "label", C.ownedValue)
		else
			local co = Common.str(n.co)
			local unitName = string.match(plain, "Cost:%s*%S+%s+(.-)%s*$")
			cost = if co then Common.num(co, "number", C.text, Signatures.unit(unitName)) else ""
		end
		if cost ~= "" then
			local well = Common.chip(b, "Cost", cost, { rich = true, bg = C.black, bgT = 0.45, h = 26 })
			well.AnchorPoint = Vector2.new(0.5, 1)
			well.Position = UDim2.new(0.5, 0, 1, -8)
		else
			Common.drop(b, "Cost")
		end
		Common.state(b, if can then "can" else "notyet")
		Kit.repeatPress(b, function(): any
			local x = self.store:get(bid)
			return if type(x) == "table" then x.a else nil
		end, ctx.act)
	end
	if respec then
		used.Respec = true
		local n = st:get(respec)
		local b = Common.get(pad, "Respec", "TextButton") :: TextButton
		b.AutoButtonColor = false
		place(b, 2, 2)
		b.BackgroundColor3 = Theme.mix(C.panel, C.danger, 0.3)
		b.BackgroundTransparency = 0
		Common.corner(b, 14)
		Common.stroke(b, 1.5, C.danger, 0.3)
		Common.drop(b, "Pad")
		Common.text(b, "label", C.text)
		b.TextWrapped = true
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.TextYAlignment = Enum.TextYAlignment.Center
		local word = trim(Common.plain(n.h or "Respec position"))
		Common.setText(b, Common.run("R", "cta", C.text) .. "\n" .. Common.run(Common.esc(word), "small", C.dangerText))
		Common.state(b, if n.cls == "can" then "can" else "notyet")
		Kit.onPress(b, function()
			local x = self.store:get(respec)
			if type(x) == "table" and type(x.a) == "table" then ctx.act(x.a, false) end
		end)
	end
	for _, c in pad:GetChildren() do
		if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
	end
end

-- the map's own node: the display-text sibling (or any node) of the tab holding an <svg>
local function svgNode(st: any): any?
	local sid = Kit.find(st, "tab", function(n: any): boolean
		return n.cn == "display-text" and isSvg(n)
	end, 4)
	return if sid then st:get(sid) else nil
end

local function explorer(ph: Frame, id: string, store: any, ctx: any): any
	local self: any = { ph = ph, id = id, ctx = ctx, store = store, lastH = nil, lastKey = nil, builds = 0, gemAt = nil }
	ph.Size = UDim2.new(1, 0, 0, 0)
	ph.AutomaticSize = Enum.AutomaticSize.Y
	Common.list(ph, false, 14)
	function self.update(_: any, st: any)
		self.store = st or self.store
		local compact = Layout.mode == "COMPACT"
		Sections.header(ph, { name = "Head", order = 0, text = "ZONE MAP", hue = HUE })
		local box = Common.get(ph, "Explorer", "Frame") :: Frame
		box.LayoutOrder = 1
		box.Active = false
		box.BackgroundTransparency = 1
		box.Size = UDim2.new(1, 0, 0, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		Common.list(box, not compact, 24, { valign = Enum.VerticalAlignment.Top, align = if compact then Enum.HorizontalAlignment.Center else nil })
		local ok, err = Common.try(drawMap, self, box, svgNode(self.store))
		if not ok then warn("[MilestoneTree] ex map failed: " .. tostring(err)) end
		drawPad(self, box)
		current = self
	end
	function self.destroy(_: any)
		if current == self then current = nil end
		Common.drop(ph, "Explorer")
		Common.drop(ph, "Head")
	end
	return self
end

-- the display-text lines: the map's line is drawn by the explorer (it only wakes it); the others stay notes
local function note(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	function claim.update(_: any, st: any)
		local n = st:get(id)
		if isSvg(n) then
			ph.Visible = false
			ph.Size = UDim2.new()
			ph.AutomaticSize = Enum.AutomaticSize.None
			Common.drop(ph, "Text")
			local e = current
			if e and e.ph.Parent then e:update(st) end
			return
		end
		local text = if type(n) == "table" then Common.plain(n.h) else ""
		if not string.find(text, "%S") then
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
	return claim
end

-- ------------------------------------------------------------------------------------------------------ hero
local function hero(f: Frame, store: any, ctx: any)
	local a = Kit.accent(f, "Ex")
	if Layout.mode == "COMPACT" then
		for _, name in { "Zone", "Area", "Feature" } do Common.drop(a, name) end
		return
	end
	local text = ""
	local tid = Kit.find(store, "tab", function(n: any): boolean
		return n.cn == "display-text" and type(n.h) == "string" and string.find(n.h, "area limits", 1, true) ~= nil
	end, 4)
	if tid then text = Common.plain(store:get(tid).h) end
	local zone = string.match(text, "Current zone:%s*([%w%-]+)")
	local ax, ay = string.match(text, "X axis %-%s*([%d%.,]+),%s*Y axis %-%s*([%d%.,]+)")
	local fx, fy = string.match(text, "feature is at %((%d+);(%d+)%)")
	local chips: { { string } } = {}
	if zone then table.insert(chips, { "Zone", Common.caps("Zone", C.soft) .. "   " .. Common.run(Common.esc(zone), "label", C.text) }) end
	if ax and ay then
		table.insert(chips, { "Area", Common.caps("Area limits", C.soft) .. "   " .. Common.num(ax .. " × " .. ay, "number", C.text) })
	end
	if fx and fy then
		table.insert(chips, { "Feature", Common.caps("Next feature", C.soft) .. "   " .. Common.num(fx .. ", " .. fy, "number", C.gold) })
	end
	local cta = f:FindFirstChild("Cta") :: GuiObject?
	local stats = f:FindFirstChild("Stats") :: GuiObject?
	local y = (if cta then cta.Size.Y.Offset + 10 else 0) + (if stats and stats.Visible then 42 else 0)
	local row = Common.get(a, "Chips", "Frame") :: Frame
	row.Active = false
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, 0, 0, y)
	row.Size = UDim2.fromOffset(0, 34)
	row.AutomaticSize = Enum.AutomaticSize.X
	Common.list(row, true, 8, { align = Enum.HorizontalAlignment.Right, valign = Enum.VerticalAlignment.Center })
	local used: { [string]: boolean } = {}
	for i, c in chips do
		used[c[1]] = true
		local chip = Common.chip(row, c[1], c[2], { rich = true, bg = C.panel2, bgT = 0, h = 34 })
		chip.LayoutOrder = i
	end
	for _, name in { "Zone", "Area", "Feature" } do
		if not used[name] then Common.drop(row, name) end
	end
end

-- green cartography: a faint grid over the header band
local function accent(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	local a = Kit.accent(band, "Ex")
	Kit.stripes(a, Theme.lift(HUE, 0.2), 0.05, 22, 0, "GridV")
	Kit.stripes(a, Theme.lift(HUE, 0.2), 0.05, 22, 90, "GridH")
end

return {
	layers = { "ex" },
	skin = P.skin,
	hero = hero,
	accent = accent,
	claims = ({
		{ match = { cn = "buyables", sub = "Main" }, make = explorer },
		{ match = { cn = "display-text" }, make = note },
	} :: { any }),
}
