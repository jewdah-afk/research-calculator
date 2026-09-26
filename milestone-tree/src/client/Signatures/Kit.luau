--!strict
--[[
	Kit: the small builders the per-layer signatures share (packages J1 / J2, plan 2.6). Not a signature itself: it
	returns no `layers`, so Signatures' auto-registration skips it.

	    Kit.live(ctx)                    the context of the running apply / refresh (claims keep the one they were made
	                                     with; the mode or widths may have changed since)
	    Kit.find(store, id, pred, d)     the first node id under id (depth <= d, tree order) whose node passes pred
	    Kit.onPress(button, fn, quiet?)  wires Activated once; fn is replaced on every call (read the node at press time);
	                                     plays the press sound unless quiet (a control that sounds its own feedback)
	    Kit.repeatPress(button, get, act) press + hold-to-repeat (0.25 s, then 20 a second while the pointer stays within
	                                     10 px and the list does not scroll), like Render's hold buttons
	    Kit.button(parent, name, text, o) a pill button whose own Text carries the RichText (2-3 instances)
	    Kit.card(parent, name, o)        a quiet panel2 card with a vertical list (corner, stroke, padding)
	    Kit.accent(parent, key)          the "Accent" holder a signature draws its accent / hero idea into; Panel and
	                                     Hero drop it when another layer opens, a different key clears it
	    Kit.stripes(parent, c, a)        diagonal stripes from a repeating gradient (needs TileMode; nothing otherwise)
	    Kit.watermark(parent, text, c)   a big faint display glyph ("M²") at the right of the header band
	    Kit.scrollTo(ctx, obj, margin)   scroll the body so obj sits near the top
	    Kit.h2(html)                     the texts of the game's <h2> runs (the numbers the game highlights, verbatim)

	Every action a signature fires is a node's own `a`, read from the store at press time, through ctx.act.
]]

local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Audio = require(Core:WaitForChild("Audio"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))

local Kit = {}

local C = Theme.C

-- ------------------------------------------------------------------------------------------------------ context
function Kit.live(ctx: any): any
	local r = ctx.render
	local now = if r then r.ctxNow else nil
	return now or ctx
end
function Kit.compact(): boolean
	return Layout.mode == "COMPACT"
end

-- ------------------------------------------------------------------------------------------------------ the store
function Kit.find(store: any, id: string, pred: (n: any, id: string) -> boolean, maxDepth: number): string?
	local function walk(x: string, d: number): string?
		local n = store:get(x)
		if type(n) ~= "table" then return nil end
		if x ~= id and pred(n, x) then return x end
		if d >= maxDepth or type(n.c) ~= "table" then return nil end
		for _, cid in n.c do
			if type(cid) == "string" then
				local hit = walk(cid, d + 1)
				if hit then return hit end
			end
		end
		return nil
	end
	return walk(id, 0)
end
function Kit.findAll(store: any, id: string, pred: (n: any, id: string) -> boolean, maxDepth: number): { string }
	local out: { string } = {}
	local function walk(x: string, d: number)
		local n = store:get(x)
		if type(n) ~= "table" then return end
		if x ~= id and pred(n, x) then
			table.insert(out, x)
			return
		end
		if d >= maxDepth or type(n.c) ~= "table" then return end
		for _, cid in n.c do
			if type(cid) == "string" then walk(cid, d + 1) end
		end
	end
	walk(id, 0)
	return out
end
-- the tab's prestige-button node (the hero's CTA), nil when the tab has none
function Kit.resetNode(store: any): any?
	local pid = Kit.find(store, "tab", function(n: any): boolean
		return n.cn == "prestige-button"
	end, 4)
	return if pid then store:get(pid) else nil
end
-- the texts of the game's <h2> runs, in order ("You caused <h2>23</h2> corruptions" -> { "23" })
function Kit.h2(html: any): { string }
	local out: { string } = {}
	if type(html) ~= "string" then return out end
	for inner in string.gmatch(html, "<h2[^>]*>(.-)</h2>") do
		local t = Common.plain(inner)
		t = string.gsub(string.gsub(t, "^%s+", ""), "%s+$", "")
		table.insert(out, t)
	end
	-- an unterminated last run ("... fixed <h2 ...>18" at the end of the string)
	local tail = string.match(html, "<h2[^>]*>([^<]*)$")
	if tail then
		local t = string.gsub(string.gsub(tail, "^%s+", ""), "%s+$", "")
		if t ~= "" then table.insert(out, t) end
	end
	return out
end

-- ------------------------------------------------------------------------------------------------------ presses
local handlers: { [Instance]: () -> () } = setmetatable({}, { __mode = "k" }) :: any
local quietOnes: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function Kit.onPress(b: GuiButton, fn: () -> (), quiet: boolean?)
	handlers[b] = fn
	quietOnes[b] = quiet == true
	if b:GetAttribute("KitWired") == true then return end
	b:SetAttribute("KitWired", true)
	b.Activated:Connect(function()
		local f = handlers[b]
		if f and not quietOnes[b] then Audio.play("press") end
		if f then f() end
	end)
end

-- press, and hold to repeat (the buyable rule of DESIGN.md 3.4); get() returns the node's current action
local repeaters: { [Instance]: { get: () -> any?, act: (a: any, hold: boolean?) -> () } } = setmetatable({}, { __mode = "k" }) :: any
function Kit.repeatPress(b: GuiButton, get: () -> any?, act: (a: any, hold: boolean?) -> ())
	repeaters[b] = { get = get, act = act }
	if b:GetAttribute("KitRepeat") == true then return end
	b:SetAttribute("KitRepeat", true)
	local seq = 0
	local repeated = false
	local startX, startY, startCy = 0, 0, 0
	local touchIo: InputObject? = nil
	local function pointer(): (number, number)
		local io = touchIo
		if io then return io.Position.X, io.Position.Y end
		local m = UserInputService:GetMouseLocation()
		return m.X, m.Y
	end
	local function moved(): boolean
		local x, y = pointer()
		local sf = b:FindFirstAncestorWhichIsA("ScrollingFrame")
		local cy = if sf then sf.CanvasPosition.Y else 0
		return (x - startX) ^ 2 + (y - startY) ^ 2 > 100 or math.abs(cy - startCy) > 2
	end
	b.Activated:Connect(function()
		if repeated then
			repeated = false
			return
		end
		if touchIo and moved() then return end
		local r = repeaters[b]
		local a = if r then r.get() else nil
		if r and type(a) == "table" then
			Audio.play("press")
			r.act(a, false)
		end
	end)
	b.InputBegan:Connect(function(io: InputObject)
		local t = io.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		seq += 1
		local mine = seq
		repeated = false
		touchIo = if t == Enum.UserInputType.Touch then io else nil
		startX, startY = pointer()
		local sf = b:FindFirstAncestorWhichIsA("ScrollingFrame")
		startCy = if sf then sf.CanvasPosition.Y else 0
		task.delay(0.25, function()
			while seq == mine and b.Parent ~= nil do
				if moved() then break end
				local r = repeaters[b]
				local a = if r then r.get() else nil
				if r == nil or type(a) ~= "table" then break end
				repeated = true
				r.act(a, true)
				task.wait(0.05)
			end
		end)
	end)
	b.InputEnded:Connect(function(io: InputObject)
		local t = io.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then seq += 1 end
	end)
	b.MouseLeave:Connect(function()
		seq += 1
	end)
end

-- ------------------------------------------------------------------------------------------------------ builders
export type ButtonOpts = { fill: Color3?, ink: Color3?, stroke: Color3?, strokeT: number?, h: number?, w: number?,
	order: number?, role: string?, radius: number?, align: Enum.TextXAlignment? }
-- a pill button: its own Text carries the (RichText-safe) text; sized from the text unless o.w is given
function Kit.button(parent: Instance, name: string, text: string, o: ButtonOpts?): TextButton
	local opts: ButtonOpts = o or ({} :: ButtonOpts)
	local b = Common.get(parent, name, "TextButton") :: TextButton
	b.AutoButtonColor = false
	Common.text(b, opts.role or "label", opts.ink or C.text)
	b.TextWrapped = false
	b.TextXAlignment = opts.align or Enum.TextXAlignment.Center
	b.TextYAlignment = Enum.TextYAlignment.Center
	b.BackgroundColor3 = opts.fill or C.panel3
	b.BackgroundTransparency = 0
	b.Selectable = true
	local h = opts.h or 40
	if opts.w then
		b.AutomaticSize = Enum.AutomaticSize.None
		b.Size = if opts.w <= 1 then UDim2.new(opts.w, 0, 0, h) else UDim2.fromOffset(opts.w, h)
	else
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, h)
	end
	if opts.order then b.LayoutOrder = opts.order end
	Common.corner(b, opts.radius or 10)
	if opts.stroke then
		Common.stroke(b, 1.5, opts.stroke, opts.strokeT or 0.2)
	else
		Common.drop(b, "Border")
	end
	-- side padding as spaces (a UIPadding per button costs an instance); left-aligned text gets one more
	local padText = if opts.align == Enum.TextXAlignment.Left then "   " else "  "
	Common.setText(b, padText .. text .. "  ")
	return b
end

export type CardOpts = { order: number?, gap: number?, pad: number?, fill: Color3?, stroke: Color3?, strokeT: number?,
	w: number?, radius: number? }
-- a quiet card: panel2 surface, 1 du rim, padding, a vertical list; auto height
function Kit.card(parent: Instance, name: string, o: CardOpts?): Frame
	local opts: CardOpts = o or ({} :: CardOpts)
	local f = Common.get(parent, name, "Frame") :: Frame
	f.Active = false
	f.BackgroundColor3 = opts.fill or C.panel2
	f.BackgroundTransparency = 0
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = if opts.w then UDim2.fromOffset(opts.w, 0) else UDim2.new(1, 0, 0, 0)
	if opts.order then f.LayoutOrder = opts.order end
	Common.corner(f, opts.radius or 14)
	Common.stroke(f, 1, opts.stroke or C.stroke, opts.strokeT or 0.2)
	local p = opts.pad or 14
	Common.pad(f, p, p + 2, p, p + 2)
	Common.list(f, false, opts.gap or 8)
	return f
end

-- a frame with a list layout and no surface (rows, columns)
function Kit.stack(parent: Instance, name: string, horizontal: boolean, gap: number, order: number?): Frame
	local f = Common.get(parent, name, "Frame") :: Frame
	f.Active = false
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.new(1, 0, 0, 0)
	if order then f.LayoutOrder = order end
	Common.list(f, horizontal, gap, { valign = if horizontal then Enum.VerticalAlignment.Center else nil })
	return f
end

-- a control at the right end of a section title row (Sections.header): the hairline flexes to leave it room
-- (UIFlexItem); without flex items it follows the chips
function Kit.headerControl(header: Instance, name: string, text: string, w: number, o: ButtonOpts?): TextButton
	local rule = header:FindFirstChild("Rule")
	local flex = false
	if rule then
		flex = pcall(function()
			local f = Common.get(rule, "Flex", "UIFlexItem") :: any
			f.FlexMode = Enum.UIFlexMode.Fill
		end)
	end
	local opts: ButtonOpts = table.clone(o or ({} :: ButtonOpts))
	opts.w = w
	opts.h = opts.h or 30
	opts.order = if flex then 20 else 5
	local b = Kit.button(header, name, text, opts)
	return b
end

-- ------------------------------------------------------------------------------------------------------ accents
-- the holder a signature draws its accent into (the sheet, the header band or the hero); a new key clears it
function Kit.accent(parent: Instance, key: string): Frame
	local f = Common.get(parent, "Accent", "Frame") :: Frame
	if f:GetAttribute("Sig") ~= key then
		for _, c in f:GetChildren() do c:Destroy() end
		f:SetAttribute("Sig", key)
	end
	f.Active = false
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.Position = UDim2.new()
	f.ClipsDescendants = false
	return f
end

-- a decoration that must sit outside an accent holder (inside a reused button, say) goes when the accent's content
-- goes: a guard object in the holder destroys it
function Kit.tether(holder: Instance, name: string, obj: Instance)
	local guard = holder:FindFirstChild(name)
	if guard and guard:GetAttribute("For") == obj:GetFullName() then return end
	if guard then guard:Destroy() end
	local g = Instance.new("Folder")
	g.Name = name
	g:SetAttribute("For", obj:GetFullName())
	g.Destroying:Connect(function()
		if obj.Parent then obj:Destroy() end
	end)
	g.Parent = holder
end

-- diagonal stripes (R9 without a texture): a repeating gradient; nothing without TileMode
function Kit.stripes(parent: Instance, color: Color3, alpha: number, radius: number?, rotation: number?, name: string?): Frame?
	local key = name or "Stripes"
	if not Theme.caps.TileMode then
		Common.drop(parent, key)
		return nil
	end
	local f = Common.get(parent, key, "Frame") :: Frame
	f.Active = false
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	if radius then Common.corner(f, radius) end
	local g = Common.get(f, "Tile", "UIGradient") :: UIGradient
	g.Rotation = rotation or 45
	pcall(function()
		g.TileMode = Enum.GradientTileMode.Repeat
		g.Scale = 0.035
	end)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - alpha),
		NumberSequenceKeypoint.new(0.45, 1 - alpha),
		NumberSequenceKeypoint.new(0.46, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	return f
end

-- a big faint display glyph at the right of a header band ("M²", "⚡")
function Kit.watermark(parent: Instance, text: string, color: Color3, alpha: number?): TextLabel
	local l = Common.get(parent, "Watermark", "TextLabel") :: TextLabel
	l.Active = false
	l.AnchorPoint = Vector2.new(1, 0.5)
	l.Position = UDim2.new(1, -140, 0.5, 4)
	l.Size = UDim2.fromOffset(240, 110)
	l.FontFace = Theme.font("title")
	l.TextSize = Theme.size("title") * 2 -- a display decoration (DESIGN.md 9.2 "other display sizes"), never read
	l.TextColor3 = color
	l.TextTransparency = 1 - (alpha or 0.07)
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = false
	l.Text = text
	return l
end

-- the sheet's header band (the accent's usual home)
function Kit.band(sheet: Instance): Frame?
	local b = sheet:FindFirstChild("HeaderBand")
	return if b and b:IsA("Frame") then b else nil
end

-- ------------------------------------------------------------------------------------------------------ hero parts
-- a stat chip under the CTA and the default stat chips (WIDE); index stacks several (1, 2, ...)
function Kit.heroChip(holder: Instance, hero: Frame, name: string, text: string, index: number?): TextLabel?
	if Layout.mode == "COMPACT" then
		Common.drop(holder, name)
		return nil
	end
	local cta = hero:FindFirstChild("Cta") :: GuiObject?
	local stats = hero:FindFirstChild("Stats") :: GuiObject?
	local y = (if cta then cta.Size.Y.Offset + 10 else 0) + (if stats and stats.Visible then 42 else 0) + ((index or 1) - 1) * 42
	local chip = Common.chip(holder, name, text, { rich = true, bg = C.panel2, bgT = 0, h = 34 })
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Position = UDim2.new(1, 0, 0, y)
	return chip
end

-- the free slot between the resource block and the CTA (WIDE): a holder for a badge / scope; nil on phones
function Kit.heroSlot(holder: Instance, name: string, w: number, h: number): Frame?
	if Layout.mode == "COMPACT" then
		Common.drop(holder, name)
		return nil
	end
	local f = Common.get(holder, name, "Frame") :: Frame
	f.Active = false
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(1, 0)
	f.Position = UDim2.new(1, -424, 0, 6)
	f.Size = UDim2.fromOffset(w, h)
	return f
end

-- a claim for display-text lines: the ones `hide` picks leave the body (a signature shows them elsewhere); the
-- others stay NOTES rows (the Skins/Generic look)
function Kit.noteClaim(hide: (h: string) -> boolean): (ph: Frame, id: string, store: any, ctx: any) -> any
	return function(ph: Frame, id: string, store: any, ctx: any): any
		local claim = {}
		function claim.update(_: any, st: any)
			local n = st:get(id)
			local h = if type(n) == "table" and type(n.h) == "string" then n.h else ""
			if hide(h) or not string.find(Common.plain(h), "%S") then
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
			Common.setText(l, Common.html(h, "body", ctx.layer))
		end
		function claim.destroy(_: any)
			Common.drop(ph, "Text")
		end
		return claim
	end
end

-- the first display-text of the tab whose html passes pred, and its html
function Kit.line(store: any, pred: (h: string) -> boolean): string?
	local id = Kit.find(store, "tab", function(n: any): boolean
		return n.cn == "display-text" and type(n.h) == "string" and pred(n.h)
	end, 4)
	return if id then store:get(id).h else nil
end

-- ------------------------------------------------------------------------------------------------------ scrolling
function Kit.scrollTo(ctx: any, obj: GuiObject?, margin: number?)
	local sf = ctx.scroll :: ScrollingFrame?
	if sf == nil or obj == nil then return end
	local s = math.max(Layout.s, 0.01)
	local dy = ((obj :: GuiObject).AbsolutePosition.Y - (sf :: ScrollingFrame).AbsolutePosition.Y) / s
	local y = math.max(0, (sf :: ScrollingFrame).CanvasPosition.Y + dy - (margin or 12))
	;(sf :: ScrollingFrame).CanvasPosition = Vector2.new(0, y)
end

return Kit
