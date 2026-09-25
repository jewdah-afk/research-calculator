--!strict
--[[
	Kit: the small builders the per-layer signatures share (packages J1 / J2, plan 2.6). Not a signature itself: it
	returns no `layers`, so Signatures' auto-registration skips it.

	    Kit.live(ctx)                    the context of the running apply / refresh (claims keep the one they were made
	                                     with; the mode or widths may have changed since)
	    Kit.find(store, id, pred, d)     the first node id under id (depth <= d, tree order) whose node passes pred
	    Kit.onPress(button, fn)          wires Activated once; fn is replaced on every call (read the node at press time)
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
function Kit.onPress(b: GuiButton, fn: () -> ())
	handlers[b] = fn
	if b:GetAttribute("KitWired") == true then return end
	b:SetAttribute("KitWired", true)
	b.Activated:Connect(function()
		local f = handlers[b]
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
		if r and type(a) == "table" then r.act(a, false) end
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

-- diagonal stripes (R9 without a texture): a repeating gradient; nothing without TileMode
function Kit.stripes(parent: Instance, color: Color3, alpha: number, radius: number?): Frame?
	if not Theme.caps.TileMode then
		Common.drop(parent, "Stripes")
		return nil
	end
	local f = Common.get(parent, "Stripes", "Frame") :: Frame
	f.Active = false
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	if radius then Common.corner(f, radius) end
	local g = Common.get(f, "Tile", "UIGradient") :: UIGradient
	g.Rotation = 45
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
