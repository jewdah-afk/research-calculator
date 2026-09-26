--!strict
--[[
	Peek: the node peek (DESIGN.md 7.2, mock j). A long-press (touch) or right-click on a node shows a scrim with a
	soft round hole over the node, and a 360 du card beside it: the emblem, the name (`card`), the amount (`number` +
	unit), the node's line as body text (have / need and the progress bar when locked), OPEN (`tab`) and the
	PRESTIGE hold (0.6 s, a ring glyph before the verb, the gain in a `badge` chip) when val.ra exists.
	Dismiss: a tap on the scrim, Esc, or the camera moving.

	The scrim is 4 dark frames around a square frame with a Radial transparency hole. The ramp can run to the square's
	corners, so the hole is fully transparent inside and reaches the scrim's alpha by t = .7 (the inscribed circle),
	staying there: the square never shows.

	    local peek = Peek.new(root)
	    peek:show(layer?, node?, ring?)      ring: the node's ring rect (abs); nil layer closes
	    peek.open (layer), peek.act (action), peek.closed ()
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))
local Ready = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Ready"))
local MapLogic = require(script.Parent.Parent:WaitForChild("Map"):WaitForChild("MapLogic"))

type ARect = Types.Rect
type MapNode = Types.MapNode

export type Peek = {
	frame: Frame,
	open: Signal.Signal<string>,
	act: Signal.Signal<Types.Action>,
	closed: Signal.Signal<>,
	show: (self: Peek, layer: string?, node: MapNode?, ring: ARect?) -> (),
	isOpen: (self: Peek) -> string?,
	destroy: (self: Peek) -> (),
}

local Peek = {}

local SCRIM_A = 0.62
local TITLES = {
	m = "Milestone", mm = "Meta-Milestone", em = "Extra-Milestone", p = "Prestige", pe = "Prestige Energy", sp = "Super Prestige",
	pb = "Prestige Boost", pp = "Prestige Power", se = "Super Energy", hp = "Hyper Prestige", ep = "Exotic Prestige",
	hb = "Hyper Boost", ap = "Atomic Prestige", mp = "Multiverse", t = "Transcend", pep = "Prestiged Exotic",
	cp = "Corrupted", cm = "Corrupted Milestone", ex = "Exploration", ach = "Achievements",
} :: { [string]: string }

function Peek.new(root: GuiObject): Peek
	local self = {} :: Peek
	self.open = Signal.new() :: Signal.Signal<string>
	self.act = Signal.new() :: Signal.Signal<Types.Action>
	self.closed = Signal.new() :: Signal.Signal<>

	local f = Kit.frame(root, "Peek", 30)
	f.Size = UDim2.fromScale(1, 1)
	f.Visible = false
	self.frame = f
	-- the scrim
	local parts: { [string]: TextButton } = {}
	for _, n in { "Top", "Bottom", "Left", "Right", "Hole" } do
		local p = Kit.button(f, "Scrim" .. n)
		p.BackgroundColor3 = Color3.new(0, 0, 0)
		p.BackgroundTransparency = SCRIM_A
		p.ZIndex = 1
		parts[n] = p
		p.Activated:Connect(function() self:show(nil) end)
	end
	local hg = Kit.child(parts.Hole, "Hole", "UIGradient") :: UIGradient
	if Theme.caps.Radial then
		hg.Type = Enum.GradientType.Radial
		hg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.36, 1),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 0),
		})
	end

	local card = Kit.frame(f, "Card", 5)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0.02
	card.Active = true
	Kit.corner(card, UDim.new(0, 0)) -- Sleek: square
	Kit.grad(card, { Theme.C.panel2, Theme.C.panel }, 90, nil, "Back")
	local rim = Kit.stroke(card, 2, Theme.C.strokeHi, 1, "Rim")
	Kit.pad(card, 16, 18, 16, 18)
	Kit.list(card, "y", 10, Enum.HorizontalAlignment.Left)

	local head = Kit.frame(card, "Head")
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, 52)
	local titleL = Kit.label(head, "Title", "card", "", Color3.new(1, 1, 1))
	titleL.Position = UDim2.fromOffset(64, 4)
	titleL.Size = UDim2.new(1, -64, 0, 24)
	titleL.TextXAlignment = Enum.TextXAlignment.Left
	titleL.TextTruncate = Enum.TextTruncate.AtEnd
	local amountL = Kit.label(head, "Amount", "number", "", Theme.C.text)
	amountL.Position = UDim2.fromOffset(64, 30)
	amountL.Size = UDim2.new(1, -64, 0, 20)
	amountL.TextXAlignment = Enum.TextXAlignment.Left
	amountL.RichText = true
	amountL.TextTruncate = Enum.TextTruncate.AtEnd

	local body = Kit.label(card, "Body", "body", "", Theme.C.text)
	body.LayoutOrder = 2
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Size = UDim2.fromScale(1, 0)
	body.TextWrapped = true
	body.RichText = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextTransparency = 0.08

	local bar = Kit.frame(card, "Bar")
	bar.LayoutOrder = 3
	bar.Size = UDim2.new(1, 0, 0, 18)
	local track = Kit.frame(bar, "Track")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.fromScale(0, 0.5)
	track.Size = UDim2.new(1, -56, 0, 6)
	track.BackgroundColor3 = Theme.C.deep
	track.BackgroundTransparency = 0
	Kit.corner(track)
	local fill = Kit.frame(track, "Fill")
	fill.BackgroundTransparency = 0
	Kit.corner(fill)
	local pct = Kit.label(bar, "Pct", "number", "", Theme.C.text)
	pct.AnchorPoint = Vector2.new(1, 0.5)
	pct.Position = UDim2.fromScale(1, 0.5)
	pct.Size = UDim2.fromOffset(52, 18)
	pct.TextXAlignment = Enum.TextXAlignment.Right

	local buttons = Kit.frame(card, "Buttons")
	buttons.LayoutOrder = 4
	buttons.Size = UDim2.new(1, 0, 0, 52)
	Kit.list(buttons, "x", 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local layer: string? = nil
	local hold: Recipes.Hold? = nil
	local shownAt: ARect? = nil

	local function setHole(r: ARect?)
		local s = Layout.s
		local ra = root.AbsolutePosition
		local top, bottom, left, right, h = parts.Top, parts.Bottom, parts.Left, parts.Right, parts.Hole
		if r == nil or not Theme.caps.Radial then
			top.Position = UDim2.new()
			top.Size = UDim2.fromScale(1, 1)
			for _, p in { bottom, left, right, h } do p.Visible = false end
			return
		end
		local rr = r :: ARect
		local cx, cy = (rr.x + rr.w / 2 - ra.X) / s, (rr.y + rr.h / 2 - ra.Y) / s
		local side = math.max(rr.w, rr.h) * 1.7 / s
		local x0, y0 = cx - side / 2, cy - side / 2
		top.Position = UDim2.new()
		top.Size = UDim2.new(1, 0, 0, math.max(0, y0))
		bottom.Position = UDim2.fromOffset(0, y0 + side)
		bottom.Size = UDim2.new(1, 0, 1, -(y0 + side))
		left.Position = UDim2.fromOffset(0, y0)
		left.Size = UDim2.fromOffset(math.max(0, x0), side)
		right.Position = UDim2.fromOffset(x0 + side, y0)
		right.Size = UDim2.new(1, -(x0 + side), 0, side)
		h.Position = UDim2.fromOffset(x0, y0)
		h.Size = UDim2.fromOffset(side, side)
		h.BackgroundTransparency = 0
		for _, p in { top, bottom, left, right, h } do p.Visible = true end
		-- the hole frame is transparent inside: the scrim's alpha lives in the gradient
		h.BackgroundTransparency = 0
		hg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.36, 1),
			NumberSequenceKeypoint.new(0.7, SCRIM_A),
			NumberSequenceKeypoint.new(1, SCRIM_A),
		})
	end

	local function placeCard(r: ARect?)
		local s = Layout.s
		local ra, rs = root.AbsolutePosition, root.AbsoluteSize
		local W, H = rs.X / s, rs.Y / s
		local w = if Layout.mode == "COMPACT" then 320 else 360
		card.Size = UDim2.fromOffset(w, 0)
		local h = math.max(160, card.AbsoluteSize.Y / s)
		local x, y = (W - w) / 2, (H - h) / 2
		if r then
			local cx, cy = (r.x + r.w / 2 - ra.X) / s, (r.y + r.h / 2 - ra.Y) / s
			local half = math.max(r.w, r.h) / s * 0.85
			x = if cx + half + 16 + w <= W - 8 then cx + half + 16 else cx - half - 16 - w
			y = cy - h / 2
		end
		card.Position = UDim2.fromOffset(math.floor(math.clamp(x, 8, math.max(8, W - w - 8))), math.floor(math.clamp(y, 8, math.max(8, H - h - 8))))
	end

	local function clearButtons()
		if hold then
			(hold :: Recipes.Hold):destroy()
			hold = nil
		end
		for _, c in buttons:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end

	function self.show(p: Peek, l: string?, node: MapNode?, ring: ARect?)
		if l == nil then
			if layer ~= nil then
				layer = nil
				clearButtons()
				f.Visible = false
				p.closed:Fire()
			end
			return
		end
		local lay = l :: string
		layer = lay
		shownAt = ring
		local hue = Theme.hue(lay)
		local v = node and node.val
		rim.Color = Theme.lift(hue, 0.25)
		local old = head:FindFirstChild("Emblem")
		if old then old:Destroy() end
		local g = Ready.gem(head, "Emblem", lay, (node and node.sym) or string.upper(lay), 52)
		g.Position = UDim2.fromOffset(0, 0)
		titleL.Text = string.upper(TITLES[lay] or (node and node.name) or lay)
		Theme.text(titleL, "card")
		local lit = v ~= nil and v.lit
		if v and lit then
			local pts = v.pts or "0"
			if lay == "ach" and v.tot then pts = pts .. " / " .. v.tot end
			local res = MapLogic.plain(v.res)
			amountL.Text = Rich.num(pts .. (if res ~= "" then " " .. res else ""), { size = Theme.size("number"), unit = Theme.C.soft })
		else
			amountL.Text = if v and v.req then Rich.num("Need " .. v.req .. " " .. MapLogic.unit(v.rres), { size = Theme.size("number"), unit = Theme.C.soft }) else ""
		end
		local tip = v and v.tip
		body.Text = if tip then Rich.html(tip, Theme.size("body"), lay) else ""
		body.Visible = body.Text ~= ""
		Theme.text(body, "body")
		local prv = v and v.pr
		bar.Visible = prv ~= nil and not lit
		if prv then
			local pr = math.clamp(prv / 1000, 0, 1)
			fill.Size = UDim2.fromScale(pr, 1)
			fill.BackgroundColor3 = Theme.lift(hue, 0.1)
			pct.Text = Rich.pct(pr)
		end
		clearButtons()
		if node and node.show then
			local ob, ol = Kit.action(buttons, "Open", Rich.caps("Open"), { style = "quiet", h = 52 })
			ob.LayoutOrder = 1
			local chev = Kit.glyph(ol.Parent :: Instance, "Chev", "chev", Color3.new(1, 1, 1))
			chev.LayoutOrder = 3
			chev.Size = UDim2.fromOffset(12, 12)
			ob.Activated:Connect(function()
				p:show(nil)
				p.open:Fire(lay)
			end)
		end
		local ra = v and v.ra
		if ra and node then
			local pb, pl = Kit.action(buttons, "Prestige", Rich.caps("Prestige"), { style = "primary", hue = hue, h = 52 })
			pb.LayoutOrder = 2
			local content = pl.Parent :: Instance
			local ringG = Kit.glyph(content, "RingGlyph", "ring", Color3.new(1, 1, 1))
			ringG.LayoutOrder = 1
			ringG.Size = UDim2.fromOffset(16, 16)
			local gain = v and v.gain
			if gain then
				local chip, cl = Kit.chip(content, "Gain", "badge", "", { h = 26, pad = 8, fg = Color3.new(1, 1, 1), bg = Theme.C.deep,
					bgA = 0.55 })
				chip.LayoutOrder = 3
				cl.RichText = true
				cl.Text = Rich.num("+" .. Rich.short(gain), { size = Theme.size("badge"), onFill = true })
			end
			local action = ra
			hold = Recipes.hold(pb, { dur = 0.6, ring = false, color = Color3.new(0, 0, 0), onDone = function()
				p.act:Fire(action)
				p:show(nil)
			end })
		end
		buttons.Visible = #buttons:GetChildren() > 1
		setHole(ring)
		f.Visible = true
		placeCard(ring)
		task.defer(function()
			if layer == lay then placeCard(shownAt) end
		end)
		local sc = Motion.scaleOf(card)
		sc.Scale = 0.96
		Motion.tween(sc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }, "peekOpen")
	end
	function self.isOpen(_: Peek): string?
		return layer
	end
	function self.destroy(p: Peek)
		clearButtons()
		p.open:DisconnectAll()
		p.act:DisconnectAll()
		p.closed:DisconnectAll()
		f:Destroy()
	end
	return self
end

return Peek
