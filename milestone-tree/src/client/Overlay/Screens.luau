--!strict
--[[
	Screens: the full-screen states of DESIGN.md 7.10-7.12 (mock j).

	    loading    the ReplicatedFirst BootScreen (src/first) when the place has it: status + progress go to it, and
	               leaving "loading" fades it out; else the fallback card: THE MILESTONE TREE, a progress bar, LOADING…
	    fatal      the error text with "Your save is safe on the server."
	    outOfSync  OUT OF SYNC · the screen stopped updating · RESYNC (fires `resync`)
	    end        the star emblem, YOU BEAT THE GAME!, the win text on a scrim band, IT TOOK YOU <took>,
	               PLAY AGAIN (2 s hold) and KEEP GOING (their actions come from the view's end screen)
	    firstRun   drawn on the map by Nodes (the START HERE cue); nothing here

	    local screens = Screens.new(root)
	    screens:show(kind?, data?)     nil hides; loading data = { done, total } or a status string
	    screens:flash(color)           a full-screen colour flash (universe change, hard reset)
	    screens.act (action), screens.resync ()
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

export type Screens = {
	frame: Frame,
	act: Signal.Signal<Types.Action>,
	resync: Signal.Signal<>,
	show: (self: Screens, kind: string?, data: any?) -> (),
	flash: (self: Screens, color: Color3) -> (),
	current: (self: Screens) -> string?,
	destroy: (self: Screens) -> (),
}

local Screens = {}

local GOLD = Color3.fromHex("ffc233")

function Screens.new(root: GuiObject): Screens
	local self = {} :: Screens
	self.act = Signal.new() :: Signal.Signal<Types.Action>
	self.resync = Signal.new() :: Signal.Signal<>

	local f = Kit.button(root, "Screen")
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 80
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = Theme.C.void
	f.Visible = false
	if Theme.caps.InputSink then
		pcall(function() (f :: any).InputSink = (Enum :: any).InputSink.All end)
	end
	self.frame = f :: any

	local flashF = Kit.frame(root, "Flash", 90)
	flashF.Size = UDim2.fromScale(1, 1)
	flashF.BackgroundTransparency = 1
	flashF.Visible = false
	pcall(function() flashF.Interactable = false end)

	local kind: string? = nil
	local holds: { Recipes.Hold } = {}
	local bar: Frame? = nil
	local barPct: TextLabel? = nil
	local statusL: TextLabel? = nil

	local function clear()
		for _, h in holds do h:destroy() end
		table.clear(holds)
		for _, c in f:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		bar, barPct, statusL = nil, nil, nil
	end

	local function card(name: string, w: number, hue: Color3): Frame
		local c = Kit.frame(f, name, 2)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromScale(0.5, 0.5)
		c.AutomaticSize = Enum.AutomaticSize.Y
		c.Size = UDim2.fromOffset(math.min(w, Layout.canvas.X - 32), 0)
		c.BackgroundColor3 = Color3.new(1, 1, 1)
		c.BackgroundTransparency = 0
		Kit.corner(c, UDim.new(0, 0)) -- Sleek: square
		Kit.grad(c, { Theme.C.panel2, Theme.C.panel }, 90, nil, "Back")
		Kit.stroke(c, 2, hue, 1, "Rim")
		Kit.pad(c, 24, 28, 24, 28)
		Kit.list(c, "y", 14, Enum.HorizontalAlignment.Left)
		return c
	end
	local function title(parent: Instance, order: number, text: string, hue: Color3, role: string, size: number?): TextLabel
		local t = Kit.label(parent, "Title", role, "", Color3.new(1, 1, 1))
		t.LayoutOrder = order
		t.Size = UDim2.new(1, 0, 0, (size or Theme.size(role)) + 8)
		t.TextXAlignment = Enum.TextXAlignment.Left
		Recipes.title(t, { text = string.upper(text), role = role, from = Color3.new(1, 1, 1), to = Theme.lift(hue, 0.45),
			stroke = if (size or Theme.size(role)) >= 40 then 6 else 4, shadow = if (size or Theme.size(role)) >= 40 then 4 else 3, size = size })
		return t
	end
	local function text(parent: Instance, order: number, s: string, role: string?, color: Color3?): TextLabel
		local l = Kit.label(parent, "Text" .. order, role or "body", s, color or Theme.C.text)
		l.LayoutOrder = order
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.fromScale(1, 0)
		l.TextWrapped = true
		l.RichText = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		return l
	end

	-- ReplicatedFirst.MilestoneTreeBoot.BootScreen (the first-frame loading screen), when the place has it
	local bootMod: any = nil
	local function bootScreen(): any
		if bootMod ~= nil then return if bootMod == false then nil else bootMod end
		local rf = game:GetService("ReplicatedFirst")
		local folder = rf:FindFirstChild("MilestoneTreeBoot")
		local m = folder and folder:FindFirstChild("BootScreen")
		if m and m:IsA("ModuleScript") then
			local ok, mod = pcall(require, m)
			bootMod = if ok then mod else false
		else
			bootMod = false
		end
		return if bootMod == false then nil else bootMod
	end
	local function buildLoading(data: any)
		f.BackgroundColor3 = Theme.C.void
		f.BackgroundTransparency = 0
		local c = card("Card", 620, Theme.hue("m"))
		title(c, 1, "The Milestone Tree", Theme.hue("m"), "title", if Layout.mode == "COMPACT" then 27 else 40)
		local b = Kit.frame(c, "Bar")
		b.LayoutOrder = 2
		b.Size = UDim2.new(1, 0, 0, 20)
		local track = Kit.frame(b, "Track")
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.fromScale(0, 0.5)
		track.Size = UDim2.new(1, -64, 0, 10)
		track.BackgroundColor3 = Theme.C.deep
		track.BackgroundTransparency = 0
		Kit.corner(track)
		local fill = Kit.frame(track, "Fill")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.BackgroundTransparency = 0
		Kit.grad(fill, { Theme.hue("m"), Theme.lift(Theme.hue("m"), 0.3) }, 0)
		Kit.corner(fill)
		local pct = Kit.label(b, "Pct", "number", "", Theme.C.text)
		pct.AnchorPoint = Vector2.new(1, 0.5)
		pct.Position = UDim2.fromScale(1, 0.5)
		pct.Size = UDim2.fromOffset(60, 20)
		pct.TextXAlignment = Enum.TextXAlignment.Right
		bar, barPct = fill, pct
		statusL = text(c, 3, Rich.caps("Loading the realm…"), "caps", Theme.C.soft)
		local _ = data
	end
	local function setLoading(data: any)
		local fill, pct = bar, barPct
		if type(data) == "table" and type(data.done) == "number" and type(data.total) == "number" and fill and pct then
			local p = if data.total > 0 then math.clamp(data.done / data.total, 0, 1) else 1
			fill.Size = UDim2.fromScale(p, 1)
			pct.Text = Rich.pct(p)
		elseif type(data) == "string" and statusL then
			(statusL :: TextLabel).Text = Rich.caps(data)
		end
	end

	local function buildFatal(data: any)
		f.BackgroundColor3 = Theme.C.void
		f.BackgroundTransparency = 0.05
		local c = card("Card", 620, Theme.C.danger)
		title(c, 1, "Something went wrong", Theme.C.danger, "section")
		text(c, 2, Rich.html(tostring(data or ""), Theme.size("body"), nil))
		text(c, 3, "Your save is safe on the server.", "small", Theme.C.soft)
	end

	local function buildOutOfSync()
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 0.35
		local c = card("Card", 560, Theme.C.info)
		title(c, 1, "Out of sync", Theme.C.info, "section")
		text(c, 2, "The screen stopped updating.\nYour save is safe on the server.")
		local row = Kit.frame(c, "Buttons")
		row.LayoutOrder = 3
		row.Size = UDim2.new(1, 0, 0, 52)
		local b = Kit.action(row, "Primary", Rich.caps("Resync"), { style = "primary", hue = Theme.C.info, role = "cta" })
		b.Size = UDim2.new(1, 0, 0, 52)
		b.AutomaticSize = Enum.AutomaticSize.None
		b.Activated:Connect(function() self.resync:Fire() end)
	end

	local function buildEnd(data: any)
		f.BackgroundColor3 = Color3.fromHex("0c0812")
		f.BackgroundTransparency = 0
		local g = Kit.grad(f, { Color3.fromHex("2a2008"), Color3.fromHex("0c0812") }, 90, nil, "Back")
		local _ = g
		local col = Kit.frame(f, "End", 2)
		col.AnchorPoint = Vector2.new(0.5, 0.5)
		col.Position = UDim2.fromScale(0.5, 0.5)
		col.AutomaticSize = Enum.AutomaticSize.Y
		col.Size = UDim2.fromOffset(math.min(820, Layout.canvas.X - 32), 0)
		Kit.list(col, "y", 16, Enum.HorizontalAlignment.Center)
		local star = Kit.frame(col, "Emblem", 2)
		star.LayoutOrder = 1
		star.Size = UDim2.fromOffset(96, 96)
		Kit.gem(star, GOLD, { hi = 0.6, lo = 0.5 })
		Kit.stroke(star, 3, Color3.fromHex("fff1b8"), 1, "Rim")
		local sg = Kit.glyph(star, "Star", "star", Color3.new(1, 1, 1))
		sg.AnchorPoint = Vector2.new(0.5, 0.5)
		sg.Position = UDim2.fromScale(0.5, 0.5)
		sg.Size = UDim2.fromScale(0.5, 0.5)
		sg.ZIndex = 4
		local compact = Layout.mode == "COMPACT"
		local t = title(col, 2, "You beat the game!", GOLD, "title", if compact then 36 else 64)
		t.TextXAlignment = Enum.TextXAlignment.Center
		for _, n in { "Shadow", "Fill" } do
			local x = t:FindFirstChild(n) :: TextLabel?
			if x then x.TextXAlignment = Enum.TextXAlignment.Center end
		end
		local d = if type(data) == "table" then data else {}
		local band = Kit.frame(col, "Band", 2)
		band.LayoutOrder = 3
		band.AutomaticSize = Enum.AutomaticSize.Y
		band.Size = UDim2.new(0.8, 0, 0, 0)
		band.BackgroundColor3 = Color3.new(0, 0, 0)
		band.BackgroundTransparency = 0.5
		Kit.corner(band, UDim.new(0, 0)) -- Sleek: square
		Kit.pad(band, 12, 18, 12, 18)
		local win = Kit.label(band, "Win", "body", "", Theme.C.text)
		win.AutomaticSize = Enum.AutomaticSize.Y
		win.Size = UDim2.fromScale(1, 0)
		win.TextWrapped = true
		win.RichText = true
		win.Text = Rich.html(if type(d.win) == "string" then d.win else "You have reached the end.", Theme.size("body"), nil)
		if type(d.took) == "string" then
			local chip = Kit.frame(col, "Took", 2)
			chip.LayoutOrder = 4
			chip.AutomaticSize = Enum.AutomaticSize.X
			chip.Size = UDim2.fromOffset(0, 30)
			chip.BackgroundColor3 = Theme.C.deep
			chip.BackgroundTransparency = 0.1
			Kit.corner(chip)
			Kit.stroke(chip, 1.5, GOLD, 1, "Rim")
			Kit.pad(chip, 0, 14, 0, 14)
			Kit.list(chip, "x", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
			local k = Kit.label(chip, "Key", "caps", Rich.caps("It took you"), Color3.fromHex("ffe9a3"))
			k.LayoutOrder = 1
			k.AutomaticSize = Enum.AutomaticSize.X
			k.Size = UDim2.fromScale(0, 1)
			local v = Kit.label(chip, "Value", "number", "", Color3.new(1, 1, 1))
			v.LayoutOrder = 2
			v.AutomaticSize = Enum.AutomaticSize.X
			v.Size = UDim2.fromScale(0, 1)
			v.RichText = true
			v.Text = Rich.num(d.took, { size = Theme.size("number"), unit = Theme.C.soft })
		end
		local row = Kit.frame(col, "Buttons", 2)
		row.LayoutOrder = 5
		row.AutomaticSize = Enum.AutomaticSize.X
		row.Size = UDim2.fromOffset(0, 56)
		Kit.list(row, "x", 16, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		if type(d.again) == "table" then
			local again = d.again
			local b, l = Kit.action(row, "Again", Rich.caps("Play again"), { style = "quiet", h = 52 })
			b.LayoutOrder = 1
			local content = l.Parent :: Instance
			local rg = Kit.glyph(content, "RingGlyph", "ring", Color3.new(1, 1, 1))
			rg.LayoutOrder = 1
			rg.Size = UDim2.fromOffset(18, 18)
			local chip, cl = Kit.chip(content, "Time", "badge", "2 s", { h = 24, pad = 7, fg = Color3.new(1, 1, 1), bg = Theme.C.deep, bgA = 0.6 })
			chip.LayoutOrder = 3
			local _ = cl
			table.insert(holds, Recipes.hold(b, { dur = 2, ring = false, color = Color3.new(0, 0, 0), onDone = function()
				self.act:Fire(again)
			end }))
		end
		if type(d.keep) == "table" then
			local keep = d.keep
			local b = Kit.action(row, "Keep", Rich.caps("Keep going"), { style = "gold", h = 52, role = "cta" })
			b.LayoutOrder = 2
			b.Activated:Connect(function() self.act:Fire(keep) end)
		end
	end

	function self.show(_: Screens, k: string?, data: any?)
		-- the loading screen is the ReplicatedFirst one (up since the first frame); the card below is its fallback
		local boot = bootScreen()
		if boot then
			if k == "loading" then
				boot.claim()
				boot.set(data)
				kind = "loading"
				clear()
				f.BackgroundTransparency = 1
				f:SetAttribute("Kind", k)
				f.Visible = true
				return
			elseif boot.visible() then
				boot.hide()
			end
		end
		if k == "loading" and kind == "loading" then
			setLoading(data)
			return
		end
		if k == nil or k == "firstRun" then
			kind = nil
			clear()
			f.Visible = false
			return
		end
		clear()
		local old = f:FindFirstChild("Back")
		if old then old:Destroy() end
		kind = k
		if k == "loading" then
			buildLoading(data)
			setLoading(data)
		elseif k == "fatal" then
			buildFatal(data)
		elseif k == "outOfSync" then
			buildOutOfSync()
		elseif k == "end" then
			buildEnd(data)
		end
		f:SetAttribute("Kind", k)
		f.Visible = true
	end
	function self.flash(_: Screens, color: Color3)
		flashF.BackgroundColor3 = color
		flashF.BackgroundTransparency = 0.4
		flashF.Visible = true
		Motion.tween(flashF, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }, "screenFlash", true)
		task.delay(0.65, function() flashF.Visible = false end)
	end
	function self.current(_: Screens): string?
		return kind
	end
	function self.destroy(s: Screens)
		clear()
		s.act:DisconnectAll()
		s.resync:DisconnectAll()
		f:Destroy()
		flashF:Destroy()
	end
	return self
end

return Screens
