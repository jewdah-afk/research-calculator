--!strict
--[[
	Modals: the modal chrome and its four uses (DESIGN.md 7.5-7.8; mocks i, j).

	    ModalDimmer  black alpha .6, takes every input (InputSink All); a tap closes (not during a hold)
	    Modal        the card: panel2 -> panel, a hue rim, the head (icon disc + R3 title + a hue sub line), the body,
	                 the Buttons row. Opens with scale .96 -> 1 (0.2 s).
	      export     Well > Box: a read-only monospace TextBox (`terminal`), focused and all selected on open; the
	                 "22,204 characters · all selected" chip, the copy hint, SELECT ALL (primary) / DONE. Touch-only
	                 devices get an editable box whose text is restored on every change (select + copy still work).
	      import     Well > Box: editable, placeholder in `small` soft; IMPORT is off while the box is empty; after a
	                 press a ring counts the server's ImportCooldown; the result shows inline (danger) or closes the
	                 modal (ok)
	      hardReset  HARD RESET?, what is lost, EXPORT FIRST · CANCEL · HOLD TO RESET (2 s ring): the reset action
	                 fires twice
	      gate       the Multiverse gate: PRESTIGE MULTIVERSE, the context, the GOAL box (+ Goal met chip), what
	                 happens (the reset list / completes / returns), STAY + HOLD TO ENTER | EXIT | FINISH (1.2 s);
	                 locked: "Unlock Multiverse (MP) first"; sealed: the requirement with its bar

	    local modals = Modals.new(root)
	    modals:open(kind?, data?)      nil closes. data: export = the string; import = { cooldown }; hardReset =
	                                   { action, export? }; gate = Gate
	    modals:importResult(imp)       modals:isOpen() -> kind?
	    modals.act (action, hold?), modals.importText (text), modals.closed (), modals.notice (text)
]]

local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))

type Action = Types.Action

export type Modals = {
	frame: Frame,
	act: Signal.Signal<Action>,
	importText: Signal.Signal<string>,
	closed: Signal.Signal<>,
	notice: Signal.Signal<string>,
	open: (self: Modals, kind: string?, data: any?) -> (),
	importResult: (self: Modals, imp: Types.ImportResult) -> (),
	isOpen: (self: Modals) -> string?,
	destroy: (self: Modals) -> (),
}

local Modals = {}

local CRIMSON = Color3.fromHex("ff2e63")
local LAYER_NAMES = {
	m = "Milestone", mm = "Meta-Milestone", em = "Extra-Milestone", p = "Prestige", pe = "Prestige Energy", sp = "Super Prestige",
	pb = "Prestige Boost", pp = "Prestige Power", se = "Super Energy", hp = "Hyper Prestige", ep = "Exotic Prestige",
	hb = "Hyper Boost", ap = "Atomic Prestige", mp = "Multiverse", t = "Transcend",
} :: { [string]: string }

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

function Modals.new(root: GuiObject): Modals
	local self = {} :: Modals
	self.act = Signal.new() :: Signal.Signal<Action>
	self.importText = Signal.new() :: Signal.Signal<string>
	self.closed = Signal.new() :: Signal.Signal<>
	self.notice = Signal.new() :: Signal.Signal<string>

	local dimmer = Kit.button(root, "ModalDimmer")
	dimmer.Size = UDim2.fromScale(1, 1)
	dimmer.BackgroundColor3 = Color3.new(0, 0, 0)
	dimmer.BackgroundTransparency = 0.4
	dimmer.ZIndex = 50
	dimmer.Visible = false
	if Theme.caps.InputSink then
		pcall(function() (dimmer :: any).InputSink = (Enum :: any).InputSink.All end)
	end

	local card = Kit.frame(root, "Modal", 51)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0
	card.Active = true
	card.Visible = false
	Kit.corner(card, UDim.new(0, 18))
	Kit.grad(card, { Theme.C.panel2, Theme.C.panel }, 90, nil, "Back")
	local rim = Kit.stroke(card, 2, Theme.C.strokeHi, 1, "Rim")
	Kit.list(card, "y", 14, Enum.HorizontalAlignment.Left)
	self.frame = card

	local kind: string? = nil
	local holds: { Recipes.Hold } = {}
	local conns: { RBXScriptConnection } = {}
	local cooldownUntil = 0
	local importTotal = 10
	local importState: { box: TextBox?, result: TextLabel?, button: TextButton?, label: TextLabel?, ring: Recipes.Ring? } = {}

	local function clear()
		for _, h in holds do h:destroy() end
		table.clear(holds)
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		for _, c in card:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		importState = {}
	end

	local function close()
		if kind == nil then return end
		kind = nil
		clear()
		card.Visible = false
		dimmer.Visible = false
		self.closed:Fire()
	end
	dimmer.Activated:Connect(function()
		for _, h in holds do
			if h.holding then return end
		end
		close()
	end)

	-- ------------------------------------------------------------------------------------------ parts
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function head(title: string, sub: string?, hue: Color3, glyph: string?)
		local h = Kit.frame(card, "Head")
		h.LayoutOrder = nextOrder()
		h.AutomaticSize = Enum.AutomaticSize.Y
		h.Size = UDim2.fromScale(1, 0)
		local x0 = 0
		if glyph then
			local disc = Kit.frame(h, "Icon", 2)
			disc.Size = UDim2.fromOffset(48, 48)
			Kit.gem(disc, hue, { hi = 0.5, lo = 0.4 })
			Kit.stroke(disc, 2, Theme.lift(hue, 0.5), 0.9, "Rim")
			local g = Kit.glyph(disc, "Glyph", glyph, Color3.new(1, 1, 1), Theme.shade(hue, 0.6))
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
			g.Size = UDim2.fromScale(0.52, 0.52)
			g.ZIndex = 3
			x0 = 62
		end
		local t = Kit.label(h, "Title", "section", "", Color3.new(1, 1, 1))
		t.Position = UDim2.fromOffset(x0, 0)
		t.Size = UDim2.new(1, -x0, 0, 28)
		t.TextXAlignment = Enum.TextXAlignment.Left
		Recipes.title(t, { text = string.upper(title), role = "section", from = Color3.new(1, 1, 1), to = Theme.lift(hue, 0.45),
			stroke = 4, shadow = 3 })
		if sub then
			local s = Kit.label(h, "Sub", "small", sub, Theme.textHue(nil))
			s.TextColor3 = Theme.lift(hue, 0.35)
			s.Position = UDim2.fromOffset(x0, 32)
			s.Size = UDim2.new(1, -x0, 0, 18)
			s.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	local function para(name: string, text: string, role: string?, color: Color3?): TextLabel
		local l = Kit.label(card, name, role or "body", text, color or Theme.C.text)
		l.LayoutOrder = nextOrder()
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.fromScale(1, 0)
		l.TextWrapped = true
		l.RichText = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		return l
	end
	local function buttonRow(): Frame
		local r = Kit.frame(card, "Buttons")
		r.LayoutOrder = 1000
		r.Size = UDim2.new(1, 0, 0, 52)
		Kit.list(r, "x", 12, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		return r
	end
	local function well(editable: boolean, text: string, hue: Color3): TextBox
		local w = Kit.frame(card, "Well")
		w.LayoutOrder = nextOrder()
		w.Size = UDim2.new(1, 0, 0, if Layout.mode == "COMPACT" then 120 else 170)
		w.BackgroundColor3 = Theme.C.void
		w.BackgroundTransparency = 0
		w.ClipsDescendants = true
		Kit.corner(w, UDim.new(0, 12))
		Kit.stroke(w, 2, hue, 0.9, "Rim")
		local box = Kit.child(w, "Box", "TextBox") :: TextBox
		box.BackgroundTransparency = 1
		box.BorderSizePixel = 0
		box.Position = UDim2.fromOffset(14, 10)
		box.Size = UDim2.new(1, -28, 1, -20)
		Theme.text(box, "terminal")
		box.TextColor3 = Theme.C.text
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top
		box.TextWrapped = true
		box.MultiLine = true
		box.ClearTextOnFocus = false
		box.TextEditable = editable
		box.Text = text
		return box
	end
	local function holdButton(parent: Instance, name: string, text: string, style: string, hue: Color3?, seconds: number,
		onDone: () -> ()): TextButton
		local b, l = Kit.action(parent, name, text, { style = style, hue = hue, h = 52 })
		local content = l.Parent :: Instance
		local ringG = Kit.glyph(content, "RingGlyph", "ring", Color3.new(1, 1, 1))
		ringG.LayoutOrder = 1
		ringG.Size = UDim2.fromOffset(18, 18)
		local chip, cl = Kit.chip(content, "Time", "badge", "", { h = 24, pad = 7, fg = Color3.new(1, 1, 1), bg = Theme.C.deep, bgA = 0.6 })
		chip.LayoutOrder = 3
		cl.RichText = true
		cl.Text = Rich.num(string.format("%g s", seconds), { size = Theme.size("badge"), onFill = true })
		table.insert(holds, Recipes.hold(b, { dur = seconds, ring = false, color = Color3.new(0, 0, 0), onDone = onDone }))
		return b
	end

	-- ------------------------------------------------------------------------------------------ kinds
	local function buildExport(text: string)
		local hue = Theme.C.info
		rim.Color = Theme.lift(hue, 0.2)
		head("Export save", "Your save as one line of text", hue, "save")
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local box = well(touchOnly, text, hue)
		if touchOnly then
			table.insert(conns, box:GetPropertyChangedSignal("Text"):Connect(function()
				if box.Text ~= text then box.Text = text end
			end))
		end
		local chipRow = Kit.frame(card, "Info")
		chipRow.LayoutOrder = nextOrder()
		chipRow.Size = UDim2.new(1, 0, 0, 28)
		local chip, cl = Kit.chip(chipRow, "Chars", "label", "", { h = 28, pad = 10, fg = Theme.C.soft, bg = Theme.C.panel3, bgA = 1 })
		local _ = chip
		cl.RichText = true
		cl.Text = string.format('<font family="%s" weight="800">%s</font> characters · all selected',
			"rbxasset://fonts/families/Sarpanch.json", commas(#text))
		para("Hint", "Press Ctrl+C to copy. On a phone: tap the box, then Select All and Copy. (Roblox games cannot write to your clipboard.)")
		local row = buttonRow()
		local done = Kit.action(row, "Secondary", Rich.caps("Done"), { style = "quiet" })
		done.LayoutOrder = 1
		done.Activated:Connect(close)
		local sel = Kit.action(row, "Primary", Rich.caps("Select all"), { style = "primary", hue = Theme.shade(Color3.fromHex("1fbfa0"), 0.8) })
		sel.LayoutOrder = 2
		local function selectAll()
			pcall(function()
				box:CaptureFocus()
				box.SelectionStart = 1
				box.CursorPosition = #box.Text + 1
			end)
		end
		sel.Activated:Connect(selectAll)
		task.defer(selectAll)
	end

	local function setImportButton()
		local st = importState
		local b, l = st.button, st.label
		if b == nil or l == nil then return end
		local left = cooldownUntil - os.clock()
		local empty = st.box == nil or (st.box :: TextBox).Text == ""
		local enabled = left <= 0 and not empty
		b.Active = enabled
		b.AutoButtonColor = false
		b.BackgroundTransparency = if enabled then 0 else 0.5
		if left > 0 then
			l.Text = "Import · " .. math.ceil(left) .. " s"
			Theme.text(l, "label")
			l.TextColor3 = Theme.C.soft
		else
			l.Text = Rich.caps("Import")
			Theme.text(l, "tab")
			l.TextColor3 = if enabled then Color3.new(1, 1, 1) else Theme.C.soft
		end
		local ring = st.ring
		if ring then
			ring:set(if left > 0 then 1 - left / math.max(1, importTotal) else 0)
			ring.frame.Visible = left > 0
		end
	end

	local function buildImport(data: any)
		local hue = Theme.C.system
		rim.Color = Theme.lift(hue, 0.2)
		head("Import save", "Your current progress is replaced.", hue, "down")
		local box = well(true, "", hue)
		box.PlaceholderText = "Paste a save string (web saves work too)"
		box.PlaceholderColor3 = Theme.C.soft
		local res = para("Result", "", "body", Theme.lift(Theme.C.danger, 0.25))
		res.Visible = false
		local row = buttonRow()
		local cancel = Kit.action(row, "Secondary", Rich.caps("Cancel"), { style = "quiet" })
		cancel.LayoutOrder = 1
		cancel.Activated:Connect(close)
		local imp, il = Kit.action(row, "Primary", Rich.caps("Import"), { style = "primary", hue = hue })
		imp.LayoutOrder = 2
		local ring = Recipes.ring(il.Parent :: GuiObject, { size = 18, thick = 3, color = Color3.new(1, 1, 1), track = 0.7 })
		ring.frame.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.frame.LayoutOrder = 1
		ring.frame.Visible = false
		importState = { box = box, result = res, button = imp, label = il, ring = ring }
		local total = if type(data) == "table" and type(data.cooldown) == "number" then data.cooldown else 10
		importTotal = total
		table.insert(conns, box:GetPropertyChangedSignal("Text"):Connect(setImportButton))
		imp.Activated:Connect(function()
			if cooldownUntil > os.clock() or box.Text == "" then return end
			cooldownUntil = os.clock() + total
			res.Visible = false
			self.importText:Fire(box.Text)
			task.spawn(function()
				while kind == "import" and os.clock() < cooldownUntil do
					setImportButton()
					task.wait(0.1)
				end
				setImportButton()
			end)
		end)
		setImportButton()
	end

	local function buildHardReset(data: any)
		local hue = Theme.C.danger
		rim.Color = hue
		head("Hard reset?", nil, hue, "warn")
		para("Body", "This deletes <b>all progress</b> on this account: every layer, every milestone and the Multiverse. It cannot be undone. Export your save first if you might want it back.")
		local row = buttonRow()
		local exportAction = if type(data) == "table" then data.export else nil
		local ex = Kit.action(row, "Export", Rich.caps("Export first"), { style = "quiet" })
		ex.LayoutOrder = 1
		ex.Activated:Connect(function()
			close()
			if type(exportAction) == "table" then self.act:Fire(exportAction) end
		end)
		local cancel = Kit.action(row, "Secondary", Rich.caps("Cancel"), { style = "quiet" })
		cancel.LayoutOrder = 2
		cancel.Activated:Connect(close)
		local action = if type(data) == "table" then data.action else nil
		local b = holdButton(row, "Primary", Rich.caps("Hold to reset"), "danger", nil, 2, function()
			close()
			if type(action) == "table" then
				-- the game resets on the second press (the first one arms it)
				self.act:Fire(action)
				self.act:Fire(action)
			end
		end)
		b.LayoutOrder = 3
		local foot = para("Foot", "Release early to cancel", "small", Theme.C.soft)
		foot.TextXAlignment = Enum.TextXAlignment.Right
		foot.LayoutOrder = 1001
	end

	local function buildGate(g: Types.Gate?)
		local hue = CRIMSON
		rim.Color = hue
		if g == nil or not g.show then
			head("The rift is sealed", "The Prestige Multiverse", hue, "swirl")
			local req = g and g.req
			para("Body", "Reach 185 milestones to reveal the Prestige Multiverse.")
			if req then
				local rows = Kit.frame(card, "Rows")
				rows.LayoutOrder = nextOrder()
				rows.AutomaticSize = Enum.AutomaticSize.Y
				rows.Size = UDim2.fromScale(1, 0)
				Kit.list(rows, "y", 4)
				for i, kv in { { "Need", req.need .. " milestones" }, { "Have", req.have .. " milestones" } } do
					local r = Kit.frame(rows, "Row" .. i)
					r.LayoutOrder = i
					r.Size = UDim2.new(1, 0, 0, 22)
					local k = Kit.label(r, "Key", "small", kv[1], Theme.C.soft)
					k.Size = UDim2.fromScale(0.4, 1)
					k.TextXAlignment = Enum.TextXAlignment.Left
					local v = Kit.label(r, "Value", "number", "", Theme.C.text)
					v.AnchorPoint = Vector2.new(1, 0)
					v.Position = UDim2.fromScale(1, 0)
					v.Size = UDim2.fromScale(0.6, 1)
					v.TextXAlignment = Enum.TextXAlignment.Right
					v.RichText = true
					v.Text = Rich.num(kv[2], { size = Theme.size("number"), unit = Theme.C.soft })
				end
				local bar = Kit.frame(card, "Bar")
				bar.LayoutOrder = nextOrder()
				bar.Size = UDim2.new(1, 0, 0, 18)
				local track = Kit.frame(bar, "Track")
				track.AnchorPoint = Vector2.new(0, 0.5)
				track.Position = UDim2.fromScale(0, 0.5)
				track.Size = UDim2.new(1, -60, 0, 8)
				track.BackgroundColor3 = Theme.C.deep
				track.BackgroundTransparency = 0
				Kit.corner(track)
				local fill = Kit.frame(track, "Fill")
				fill.Size = UDim2.fromScale(math.clamp(req.pr / 1000, 0, 1), 1)
				fill.BackgroundColor3 = hue
				fill.BackgroundTransparency = 0
				Kit.corner(fill)
				local pct = Kit.label(bar, "Pct", "number", Rich.pct(req.pr / 1000), Theme.C.text)
				pct.AnchorPoint = Vector2.new(1, 0.5)
				pct.Position = UDim2.fromScale(1, 0.5)
				pct.Size = UDim2.fromOffset(56, 18)
				pct.TextXAlignment = Enum.TextXAlignment.Right
			end
			local row = buttonRow()
			local ok = Kit.action(row, "Secondary", Rich.caps("Close"), { style = "quiet" })
			ok.Activated:Connect(close)
			return
		end
		local gate = g :: Types.Gate
		head("Prestige Multiverse", if gate.inside then "MP challenge 21 · you are inside" else "MP challenge 21", hue, "swirl")
		-- the goal box
		local box = Kit.frame(card, "Goal")
		box.LayoutOrder = nextOrder()
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Size = UDim2.fromScale(1, 0)
		box.BackgroundColor3 = Theme.C.deep
		box.BackgroundTransparency = 0
		Kit.corner(box, UDim.new(0, 12))
		Kit.stroke(box, 1.5, Theme.C.stroke, 1, "Rim")
		Kit.pad(box, 12, 14, 12, 14)
		Kit.list(box, "y", 6)
		local top = Kit.frame(box, "Top")
		top.LayoutOrder = 1
		top.Size = UDim2.new(1, 0, 0, 24)
		local cap = Kit.label(top, "Cap", "caps", Rich.caps("Goal"), Theme.C.soft)
		cap.Size = UDim2.fromScale(0.5, 1)
		cap.TextXAlignment = Enum.TextXAlignment.Left
		if gate.inside then
			local met = gate.fin
			local chip = Kit.chip(top, "State", "label", if met then "Goal met" else "Goal not met", { h = 24, pad = 10,
				fg = if met then Theme.C.ownedTitle else Theme.C.soft, bg = if met then Theme.shade(Theme.C.bought, 0.3) else Theme.C.panel3,
				bgA = 1, line = if met then Theme.C.bought else Theme.C.strokeHi, lineA = 1 })
			chip.AnchorPoint = Vector2.new(1, 0)
			chip.Position = UDim2.fromScale(1, 0)
		end
		local goalText = string.gsub(gate.goal or "", "^Goal:%s*", "")
		local gl = Kit.label(box, "Text", "body", "", Theme.C.text)
		gl.LayoutOrder = 2
		gl.AutomaticSize = Enum.AutomaticSize.Y
		gl.Size = UDim2.fromScale(1, 0)
		gl.TextWrapped = true
		gl.RichText = true
		gl.TextXAlignment = Enum.TextXAlignment.Left
		gl.Text = Rich.html(goalText, Theme.size("body"), "mp")
		if gate.done then
			para("Done", "You have completed it before.", "small", Theme.C.soft)
		end
		-- what happens
		local what: string
		local verb: string
		if gate.inside then
			if gate.fin then
				what = "Leaving now completes the challenge (+1) and returns you to the Normal Universe."
				verb = "Finish"
			else
				what = "Leaving now returns you to the Normal Universe without completing the challenge."
				verb = "Exit"
			end
		else
			local names = {}
			for _, l in gate.rs do table.insert(names, LAYER_NAMES[l] or string.upper(l)) end
			what = "Entering resets " .. table.concat(names, ", ") .. "."
			verb = "Enter"
		end
		para("What", what)
		local row = buttonRow()
		local stay = Kit.action(row, "Secondary", Rich.caps("Stay"), { style = "quiet" })
		stay.LayoutOrder = 1
		stay.Activated:Connect(close)
		if not gate.can and not gate.inside then
			local bar, bl = Kit.action(row, "Primary", "Unlock Multiverse (MP) first", { style = "quiet", role = "label" })
			bar.LayoutOrder = 2
			bar.Active = false
			bl.TextColor3 = Theme.C.soft
			return
		end
		local action = gate.a
		local b = holdButton(row, "Primary", Rich.caps("Hold to " .. string.lower(verb)), "gold", nil, 1.2, function()
			close()
			if action then self.act:Fire(action) end
		end)
		b.LayoutOrder = 2
	end

	-- ------------------------------------------------------------------------------------------ API
	function self.open(_: Modals, k: string?, data: any?)
		if k == nil then
			close()
			return
		end
		clear()
		order = 0
		kind = k
		local compact = Layout.mode == "COMPACT"
		card.Size = UDim2.fromOffset(if compact then 520 else 600, 0)
		Kit.pad(card, if compact then 16 else 22, if compact then 18 else 24, if compact then 16 else 22, if compact then 18 else 24)
		if k == "export" then
			buildExport(if type(data) == "string" then data else "")
		elseif k == "import" then
			buildImport(data)
		elseif k == "hardReset" then
			buildHardReset(data)
		elseif k == "gate" then
			buildGate(data)
		else
			para("Body", tostring(data or ""))
			local row = buttonRow()
			local ok = Kit.action(row, "Primary", Rich.caps("OK"), { style = "quiet" })
			ok.Activated:Connect(close)
		end
		card:SetAttribute("Kind", k)
		dimmer.Visible = true
		card.Visible = true
		local sc = Motion.scaleOf(card)
		sc.Scale = 0.96
		Motion.tween(sc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }, "modalOpen")
	end
	function self.importResult(m: Modals, imp: Types.ImportResult)
		if imp.ok then
			if kind == "import" then close() end
			m.notice:Fire(imp.msg ~= "" and imp.msg or "Save imported")
			return
		end
		local res = importState.result
		if kind == "import" and res then
			res.Text = imp.msg ~= "" and imp.msg or "That string is not a valid save (nothing was changed)."
			res.Visible = true
		else
			m.notice:Fire(imp.msg)
		end
	end
	function self.isOpen(_: Modals): string?
		return kind
	end
	function self.destroy(m: Modals)
		clear()
		m.act:DisconnectAll()
		m.importText:DisconnectAll()
		m.closed:DisconnectAll()
		m.notice:DisconnectAll()
		card:Destroy()
		dimmer:Destroy()
	end
	return self
end

return Modals
