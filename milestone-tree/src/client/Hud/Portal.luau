--!strict
--[[
	Portal: the Multiverse portal at the bottom right (DESIGN.md 4.6).

	    Portal   140 x 160 (COMPACT 92 x 104)
	      Aura   a soft glow in the state colour (breathing when FINISH)
	      Disc   Ø112 (70): a Conical ring (#ff2e63, #b35cff, #ff5a1f, #ffd34d) rotating 8 s / rev; desaturated and still
	             while sealed
	      Void   the inner void (radial #05030b -> #1a0a24) with a swirl, or "?" while sealed
	      Label  a glass pill hanging from the rim: "MULTIVERSE" (`tab`) over the state line (`label` + `number`);
	             COMPACT the state line alone

	    state      from
	    sealed     gate.show == false: "SEALED 164/185" (hidden in first-run mode)
	    locked     show, not can: LOCKED + lock
	    enter      can, outside: ENTER (crimson)
	    exit       inside, not fin: EXIT EARLY (orange)
	    finish     inside, fin: FINISH (gold aura breathing)

	    local part = Portal.new(parent)
	    part:update(gate?)   part:setHidden(b)   part.tap ()
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Rich = require(Core:WaitForChild("Rich"))
local Kit = require(script.Parent:WaitForChild("Kit"))

export type Portal = {
	frame: Frame,
	tap: Signal.Signal<>,
	changed: Signal.Signal<>,
	state: string,
	update: (self: Portal, gate: Types.Gate?) -> (),
	setHidden: (self: Portal, b: boolean) -> (),
	destroy: (self: Portal) -> (),
}

local Portal = {}

local RING = { Color3.fromHex("ff2e63"), Color3.fromHex("b35cff"), Color3.fromHex("ff5a1f"), Color3.fromHex("ffd34d"), Color3.fromHex("ff2e63") }
local GREY = { Color3.fromHex("6a5f8f"), Color3.fromHex("3a3352"), Color3.fromHex("5c5775"), Color3.fromHex("3a3352"), Color3.fromHex("6a5f8f") }
local STATE_COLOR: { [string]: Color3 } = {
	sealed = Color3.fromHex("8d86a8"),
	locked = Color3.fromHex("9a94b8"),
	enter = Color3.fromHex("ff2e63"),
	exit = Color3.fromHex("ff7a2e"),
	finish = Color3.fromHex("ffc233"),
}

function Portal.new(parent: GuiObject): Portal
	local self = {} :: Portal
	self.tap = Signal.new() :: Signal.Signal<>
	self.changed = Signal.new() :: Signal.Signal<>
	self.state = ""

	local f = Kit.frame(parent, "Portal", 5)
	f.AnchorPoint = Vector2.new(1, 1)
	self.frame = f
	local aura = Kit.blob(f, "Aura", STATE_COLOR.enter, 0.55, 1)
	local disc = Kit.frame(f, "Disc", 2)
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.BackgroundTransparency = 0
	Kit.corner(disc)
	local ringGrad = Kit.child(disc, "Ring", "UIGradient") :: UIGradient
	if Theme.caps.Conical then ringGrad.Type = Enum.GradientType.Conical end
	local void = Kit.frame(disc, "Void", 3)
	void.AnchorPoint = Vector2.new(0.5, 0.5)
	void.Position = UDim2.fromScale(0.5, 0.5)
	void.Size = UDim2.fromScale(0.78, 0.78)
	void.BackgroundColor3 = Color3.new(1, 1, 1)
	void.BackgroundTransparency = 0
	Kit.corner(void)
	local vg = Kit.child(void, "Radial", "UIGradient") :: UIGradient
	if Theme.caps.Radial then vg.Type = Enum.GradientType.Radial end
	vg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("05030b")),
		ColorSequenceKeypoint.new(0.7, Color3.fromHex("1a0a24")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("1a0a24")),
	})
	local swirl = Kit.glyph(void, "Swirl", "swirl", Color3.fromHex("ff8fb0"))
	swirl.AnchorPoint = Vector2.new(0.5, 0.5)
	swirl.Position = UDim2.fromScale(0.5, 0.5)
	swirl.Size = UDim2.fromScale(0.5, 0.5)
	swirl.ZIndex = 4
	local q = Kit.label(void, "Question", "big", "?", Color3.fromHex("c9c3e6"))
	q.Size = UDim2.fromScale(1, 1)
	q.TextXAlignment = Enum.TextXAlignment.Center
	q.ZIndex = 4
	Kit.textStroke(q, 3, 1)

	local pill = Kit.frame(f, "Label", 6)
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.fromScale(0.5, 1)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.fromHex("0e0b18")
	pill.BackgroundTransparency = 0.12
	Kit.corner(pill, UDim.new(0, 12))
	local pRim = Kit.stroke(pill, 2, STATE_COLOR.enter, 1, "Rim")
	Kit.list(pill, "y", 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local title = Kit.label(pill, "Title", "tab", Rich.caps("Multiverse"), Color3.new(1, 1, 1))
	title.LayoutOrder = 1
	title.AutomaticSize = Enum.AutomaticSize.XY
	Kit.textStroke(title, 1.5, 0.8)
	local line = Kit.frame(pill, "Line")
	line.LayoutOrder = 2
	line.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(line, "x", 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local lock = Kit.glyph(line, "Lock", "lock", Theme.C.gold, Color3.fromHex("0e0b18"))
	lock.LayoutOrder = 1
	lock.Visible = false
	local word = Kit.label(line, "Word", "label", "", Theme.C.soft)
	word.LayoutOrder = 2
	word.AutomaticSize = Enum.AutomaticSize.XY
	local numL = Kit.label(line, "Num", "number", "", Color3.new(1, 1, 1))
	numL.LayoutOrder = 3
	numL.AutomaticSize = Enum.AutomaticSize.XY

	local hit = Kit.button(f, "Hit")
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 10
	hit.Activated:Connect(function() self.tap:Fire() end)

	local hidden = false
	local gate: Types.Gate? = nil
	local compact = false

	local function place()
		compact = Layout.mode == "COMPACT"
		local w, h = if compact then 92 else 140, if compact then 104 else 160
		local d = if compact then 70 else 112
		f.Size = UDim2.fromOffset(w, h)
		f.Position = UDim2.new(1, if compact then -10 else -16, 1, if compact then -4 else -8)
		disc.Size = UDim2.fromOffset(d, d)
		disc.Position = UDim2.new(0.5, 0, 0, 0)
		if aura then
			aura.AnchorPoint = Vector2.new(0.5, 0.5)
			aura.Position = UDim2.new(0.5, 0, 0, d / 2)
			aura.Size = UDim2.fromOffset(d * 1.9, d * 1.9)
		end
		pill.Size = UDim2.fromOffset(0, if compact then 26 else 46)
		Kit.pad(pill, 0, 12, 0, 12)
		title.Visible = not compact
		Theme.text(title, "tab")
		Theme.text(word, "label")
		Theme.text(numL, "number")
		lock.Size = UDim2.fromOffset(13, 13)
		self.changed:Fire()
	end
	place()

	local function apply()
		local g = gate
		local st: string
		if g == nil or not g.show then
			st = "sealed"
		elseif g.inside then
			st = if g.fin then "finish" else "exit"
		elseif not g.can then
			st = "locked"
		else
			st = "enter"
		end
		local c = STATE_COLOR[st]
		pRim.Color = c
		lock.Visible = st == "locked"
		q.Visible = st == "sealed"
		swirl.Visible = st ~= "sealed"
		numL.Text = ""
		if st == "sealed" then
			local req = g and g.req
			word.Text = if compact then "" else Rich.caps("Sealed")
			numL.Text = if req then req.have .. "/" .. req.need else ""
			word.Visible = not compact
		else
			word.Visible = true
			word.Text = Rich.caps(if st == "locked" then "Locked" elseif st == "enter" then "Enter"
				elseif st == "exit" then "Exit early" else "Finish")
		end
		word.TextColor3 = if st == "sealed" then Theme.C.soft else Theme.lift(c, 0.45)
		numL.Visible = numL.Text ~= ""
		if st ~= self.state then
			self.state = st
			f:SetAttribute("State", st)
			local stops: { Color3 } = if st == "sealed" or st == "locked" then GREY else RING
			local keys = {}
			for i, col in stops do table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#stops - 1), col)) end
			ringGrad.Color = ColorSequence.new(keys)
			if st == "sealed" or st == "locked" then Kit.unspin(ringGrad) else Kit.spin(ringGrad, 8) end
			local a = aura
			if a then
				a.BackgroundColor3 = c
				local ag = a:FindFirstChild("Radial") :: UIGradient?
				if ag then ag.Color = ColorSequence.new(c) end
				a.Visible = st ~= "sealed"
				if st == "finish" then
					Kit.breathe(a, "BackgroundTransparency", 0, 0.5, 1.2)
				else
					Kit.still(a)
					a.BackgroundTransparency = if st == "locked" then 0.7 else 0.2
				end
			end
		end
	end

	function self.update(_: Portal, g: Types.Gate?)
		gate = g
		apply()
	end
	function self.setHidden(p: Portal, b: boolean)
		if b == hidden then return end
		hidden = b
		f.Visible = not b
		p.changed:Fire()
	end
	function self.destroy(p: Portal)
		p.tap:DisconnectAll()
		p.changed:DisconnectAll()
		Kit.unspin(ringGrad)
		f:Destroy()
	end
	Layout.changed:Connect(function()
		place()
		apply()
	end)
	apply()
	return self
end

return Portal
