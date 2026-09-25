--!strict
--[[
	Render: view nodes (see the server's Session and rbx/view.js) -> GUI objects, kept in step with patches.

	Every node has an id that is its path ("tab.3.1"), so its parent and its place among its siblings come from the
	id: a patch only has to carry the nodes that changed. A node whose kind is unchanged is updated in place;
	otherwise it is rebuilt and its children move over to the new object.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("MilestoneTree")
local Html = require(shared:WaitForChild("Html"))
local ZoneMaps = require(shared:WaitForChild("ZoneMaps"))
local Style = require(script.Parent:WaitForChild("Style"))

export type Hooks = {
	press: (action: any, hold: boolean) -> (),
	tip: (html: string?, over: GuiObject?) -> (),
}

type Rec = {
	id: string,
	kind: string,
	node: any,
	root: GuiObject,
	content: GuiObject,     -- where children go
	autoW: boolean,         -- sized by its content (inside a row) rather than by its parent's width
	text: Color3,           -- text colour children inherit
	textT: number,
	base: number,           -- text size children inherit
	conns: { RBXScriptConnection },
	sig: string?,           -- what the object currently shows (skip redundant updates)
}

local Render = {}
Render.__index = Render

export type Renderer = typeof(setmetatable({} :: {
	roots: { [string]: GuiObject },
	recs: { [string]: Rec },
	kids: { [string]: { [string]: boolean } },
	hooks: Hooks,
}, Render))

function Render.new(roots: { [string]: GuiObject }, hooks: Hooks): Renderer
	local self = setmetatable({ roots = roots, recs = {}, kids = {}, hooks = hooks }, Render)
	return self
end

local function parentOf(id: string): (string?, number)
	local p, i = string.match(id, "^(.*)%.(%d+)$")
	if p == nil then return nil, 0 end
	return p, tonumber(i) :: number
end

local function depth(id: string): number
	local _, n = string.gsub(id, "%.", "")
	return n
end

local function kindOf(n: any): string
	if n.t == "html" and type(n.h) == "string" and string.find(n.h, "<svg", 1, true) then return "svg" end
	if n.t == "btn" then return "btn:" .. tostring(n.k) end
	return tostring(n.t)
end

-- --------------------------------------------------------------------------------------------------------- helpers
local function label(parent: Instance?, name: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.RichText = true
	l.TextWrapped = true
	l.FontFace = Style.FONT
	l.TextColor3 = Style.TEXT
	l.TextSize = 16
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Text = ""
	l.Parent = parent
	return l
end

local function frame(name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	return f
end

local function list(obj: GuiObject, horizontal: boolean, pad: number, wraps: boolean?): UIListLayout
	local l = Style.child(obj, "UIListLayout", "List") :: UIListLayout
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, pad)
	l.Wraps = wraps == true
	return l
end

local function sizeConstraint(obj: GuiObject, minX: number?, minY: number?, maxX: number?)
	if minX == nil and minY == nil and maxX == nil then Style.drop(obj, "Limit"); return end
	local c = Style.child(obj, "UISizeConstraint", "Limit") :: UISizeConstraint
	c.MinSize = Vector2.new(minX or 0, minY or 0)
	c.MaxSize = Vector2.new(maxX or math.huge, math.huge)
end

local function px(v: any, base: number?): number?
	if type(v) == "number" then return v end
	if type(v) == "string" then return Html.px(v, base) end
	return nil
end

-- ------------------------------------------------------------------------------------------------------- the nodes
function Render._inherit(self: Renderer, parentId: string?): (boolean, Color3, number, number)
	if parentId and self.recs[parentId] then
		local p = self.recs[parentId]
		return p.autoW or p.kind == "row" or p.kind == "tabs", p.text, p.textT, p.base
	end
	return false, Style.TEXT, 0, 16
end

function Render._build(self: Renderer, id: string, n: any): Rec
	local parentId = parentOf(id)
	local autoW, text, textT, base = self:_inherit(parentId)
	local kind = kindOf(n)
	local rec: Rec = { id = id, kind = kind, node = n, root = nil :: any, content = nil :: any, autoW = autoW, text = text, textT = textT, base = base, conns = {} }
	local t = n.t
	if t == "col" or t == "row" or t == "tabs" then
		local f = frame(id)
		if autoW then
			f.Size = UDim2.new(0, 0, 0, 0)
			f.AutomaticSize = Enum.AutomaticSize.XY
		end
		rec.root, rec.content = f, f
	elseif t == "html" or t == "svg" or kind == "svg" then
		local f = frame(id)
		if autoW then f.Size = UDim2.new(0, 0, 0, 0); f.AutomaticSize = Enum.AutomaticSize.XY end
		rec.root, rec.content = f, f
	elseif t == "blank" or t == "hr" then
		local f = Instance.new("Frame")
		f.Name = id
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		rec.root, rec.content = f, f
	elseif t == "btn" then
		local b = Instance.new("TextButton")
		b.Name = id
		b.AutoButtonColor = false
		b.Text = ""
		b.BorderSizePixel = 0
		b.ClipsDescendants = false
		local l = label(b, "Label")
		l.ZIndex = 3
		rec.root, rec.content = b, b
		self:_wireButton(rec, b)
	elseif t == "ms" or t == "chal" or t == "ach" or t == "info" or t == "bar" then
		local f = frame(id)
		f.BackgroundTransparency = 0
		f.Size = UDim2.new(0, 0, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		local l = label(f, "Label")
		l.LayoutOrder = 0
		local kids = frame("Kids")
		kids.LayoutOrder = 1
		kids.Parent = f
		list(kids, t ~= "chal", 6, true)
		rec.root, rec.content = f, kids
		if t == "info" then
			local b = Instance.new("TextButton")
			b.Name = "Title"
			b.AutoButtonColor = false
			b.LayoutOrder = -1
			b.Size = UDim2.new(1, 0, 0, 0)
			b.AutomaticSize = Enum.AutomaticSize.Y
			b.Text = ""
			b.Parent = f
			label(b, "Label")
			self:_wireButton(rec, b)
		elseif t == "bar" then
			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.BorderSizePixel = 0
			fill.ZIndex = 0
			fill.Parent = f
		end
		self:_wireTip(rec, f)
	else
		local f = frame(id)
		rec.root, rec.content = f, f
	end
	return rec
end

function Render._wireTip(self: Renderer, rec: Rec, obj: GuiObject)
	table.insert(rec.conns, obj.MouseEnter:Connect(function()
		local tip = rec.node.tip
		if type(tip) == "string" and tip ~= "" then self.hooks.tip(tip, obj) end
	end))
	table.insert(rec.conns, obj.MouseLeave:Connect(function() self.hooks.tip(nil, obj) end))
end

function Render._wireButton(self: Renderer, rec: Rec, b: GuiButton)
	local holding = 0
	local scale = Style.child(b, "UIScale", "Hover") :: UIScale
	table.insert(rec.conns, b.Activated:Connect(function()
		local a = rec.node.a
		if a then self.hooks.press(a, false) end
	end))
	-- hold to repeat (buyables, and clickables / grid tiles that have onHold): after 0.25 s, 20 presses a second
	table.insert(rec.conns, b.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not rec.node.hold then return end
		holding += 1
		local mine = holding
		task.delay(0.25, function()
			while holding == mine and rec.root.Parent do
				local a = rec.node.a
				if a then self.hooks.press(a, true) end
				task.wait(0.05)
			end
		end)
	end))
	table.insert(rec.conns, b.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then holding += 1 end
	end))
	table.insert(rec.conns, b.MouseEnter:Connect(function()
		if rec.node.cls == "can" or rec.node.cls == "perk" or rec.node.cls == "pseudo" then scale.Scale = 1.06 end
		local tip = rec.node.tip
		if type(tip) == "string" and tip ~= "" then self.hooks.tip(tip, b) end
	end))
	table.insert(rec.conns, b.MouseLeave:Connect(function()
		holding += 1
		scale.Scale = 1
		self.hooks.tip(nil, b)
	end))
end

-- the text of a node, drawn into a label (svg blocks become little canvases next to it)
local function setRich(l: TextLabel, html: string?, base: number, preLine: boolean?)
	local r = Html.rich(html or "", base, preLine)
	if l.Text ~= r then l.Text = r end
	l.TextSize = base
	l.Visible = r ~= ""
end

local function drawSvg(parent: GuiObject, svg: any, order: number): Frame
	local canvas = Instance.new("Frame")
	canvas.Name = "Svg" .. order
	canvas.LayoutOrder = order
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromOffset(svg.w, svg.h)
	canvas.ClipsDescendants = true
	local lines = svg.bg and ZoneMaps[svg.bg]
	if lines then
		for _, ln in lines do
			local x1, y1, x2, y2, col, w = ln[1], ln[2], ln[3], ln[4], ln[5], ln[6]
			local dx, dy = x2 - x1, y2 - y1
			local len = math.sqrt(dx * dx + dy * dy)
			local seg = Instance.new("Frame")
			seg.BorderSizePixel = 0
			seg.BackgroundColor3 = Color3.fromHex(col)
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
			seg.Size = UDim2.fromOffset(math.max(len, w), w)
			seg.Rotation = math.deg(math.atan2(dy, dx))
			seg.Parent = canvas
		end
	end
	for _, t in svg.texts do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0, 1)
		l.Position = UDim2.fromOffset(t.x, t.y + t.size * 0.2)
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.fromOffset(0, 0)
		l.FontFace = Style.FONT
		l.TextSize = t.size
		l.TextColor3 = if t.color then Color3.fromHex(t.color) else Style.TEXT
		l.Text = t.text
		l.Parent = canvas
	end
	canvas.Parent = parent
	return canvas
end

local function btnKind(k: string?): Style.Kind
	return Style.KIND[k or ""] or Style.KIND.upg
end

function Render._update(self: Renderer, rec: Rec, n: any)
	rec.node = n
	local t, root = n.t, rec.root
	local extraStyle = n.cst
	if t == "col" or t == "row" or t == "tabs" then
		list(root, t ~= "col", if t == "col" then 6 else 8, t ~= "col" and not rec.autoW)
		local a = Style.apply(root, n.st)
		if n.st and (n.st["border-style"] or n.st.border) and not n.st.border then Style.stroke(root, 2, Style.TEXT, 0.4) end
		if a.w then root.Size = UDim2.new(0, a.w, root.Size.Y.Scale, root.Size.Y.Offset); root.AutomaticSize = Enum.AutomaticSize.Y end
		if extraStyle then Style.apply(root, extraStyle) end
	elseif rec.kind == "svg" then
		for _, c in root:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
		list(root, false, 4)
		local order = 0
		for _, part in Html.split(n.h) do
			order += 1
			if type(part) == "string" then
				if string.find(part, "%S") then
					local l = label(root, "Text" .. order)
					l.LayoutOrder = order
					l.TextColor3, l.TextTransparency = rec.text, rec.textT
					setRich(l, part, rec.base)
				end
			else
				drawSvg(root, part, order)
			end
		end
	elseif t == "html" then
		local l = root:FindFirstChild("Text") :: TextLabel?
		if not l then l = label(root, "Text") end
		local lbl = l :: TextLabel
		local a = Style.apply(root, extraStyle)
		lbl.TextColor3 = a.text or rec.text
		lbl.TextTransparency = a.textT or rec.textT
		if rec.autoW then
			lbl.Size = UDim2.new(0, 0, 0, 0)
			lbl.AutomaticSize = Enum.AutomaticSize.XY
			lbl.TextWrapped = true
			sizeConstraint(lbl, nil, nil, 640)
		end
		setRich(lbl, n.h, a.font or rec.base)
		lbl.Visible = lbl.Text ~= ""
		root.Visible = lbl.Visible
	elseif t == "blank" then
		root.Size = UDim2.fromOffset(px(n.w, rec.base) or 8, px(n.hh, rec.base) or 17)
	elseif t == "hr" then
		root.BackgroundTransparency = 0.5
		root.BackgroundColor3 = Style.TEXT
		local w = px(n.w, rec.base)
		root.Size = if w then UDim2.fromOffset(w, 2) else UDim2.new(if rec.autoW then 0 else 0.95, if rec.autoW then 300 else 0, 0, 2)
	elseif t == "btn" then
		self:_updateButton(rec, n)
	elseif t == "ms" then
		root.Size = UDim2.new(0, 600, 0, 0)
		root.BackgroundColor3 = if n.done then Style.BOUGHT else Style.LOCKED
		root.BackgroundTransparency = 0
		Style.corner(root, 4)
		Style.stroke(root, 4)
		Style.pad(root, 6)
		list(root, false, 4)
		local a = Style.apply(root, n.st)
		if a.w then root.Size = UDim2.fromOffset(math.max(a.w, 120), 0) end
		rec.text, rec.textT, rec.base = a.text or Style.DARK, a.textT or 0.5, a.font or 14
		local l = root:FindFirstChild("Label") :: TextLabel
		l.TextColor3, l.TextTransparency = rec.text, rec.textT
		setRich(l, n.h, rec.base)
		sizeConstraint(root, nil, 35, nil)
	elseif t == "chal" then
		root.Size = UDim2.fromOffset(310, 0)
		root.BackgroundColor3 = if n.cls == "canComplete" then Style.COMPLETE elseif n.cls == "done" then Style.BOUGHT else Style.LOCKED
		root.BackgroundTransparency = 0
		Style.corner(root, 0.2)
		Style.stroke(root, 4)
		Style.glow(root, if n.active then Color3.new(1, 1, 1) else nil)
		Style.pad(root, 14)
		list(root, false, 8)
		local a = Style.apply(root, n.st)
		rec.text, rec.textT, rec.base = a.text or Style.DARK, a.textT or 0.5, a.font or 14
		local l = root:FindFirstChild("Label") :: TextLabel
		l.Visible = false
		sizeConstraint(root, nil, 310, nil)
		for _, kid in self:_children(rec.id) do
			local kr = self.recs[kid]
			if kr then kr.text, kr.textT, kr.base = rec.text, rec.textT, rec.base; kr.sig = nil; self:_update(kr, kr.node) end
		end
	elseif t == "ach" then
		root.Size = UDim2.fromOffset(90, 90)
		root.AutomaticSize = Enum.AutomaticSize.None
		root.BackgroundColor3 = if n.done then Style.BOUGHT else Style.LOCKED
		root.BackgroundTransparency = 0
		Style.corner(root, 0.1)
		Style.stroke(root, 2)
		Style.pad(root, 4)
		Style.apply(root, n.st)
		local l = root:FindFirstChild("Label") :: TextLabel
		l.TextColor3 = Color3.new(1, 1, 1)
		local stroke = Style.child(l, "UIStroke", "Shadow") :: UIStroke
		stroke.Thickness = 1
		stroke.Transparency = 0.3
		setRich(l, n.h, 10)
		local num = Style.child(root, "TextLabel", "Num") :: TextLabel
		num.BackgroundTransparency = 1
		num.Size = UDim2.fromOffset(30, 14)
		num.Position = UDim2.new(1, -30, 1, -14)
		num.FontFace = Style.FONT
		num.TextSize = 10
		num.TextColor3 = Color3.new(1, 1, 1)
		num.Text = tostring(n.num or "")
	elseif t == "info" then
		local color = Html.color(n.color) or Style.TEXT
		root.Size = UDim2.fromOffset(600, 0)
		root.BackgroundColor3 = Style.BG
		root.BackgroundTransparency = 0
		Style.stroke(root, 4, color, 0)
		Style.corner(root, if n.shut then 0 else 8)
		list(root, false, 4)
		local title = root:FindFirstChild("Title") :: TextButton
		title.BackgroundColor3 = color
		local tl = title:FindFirstChild("Label") :: TextLabel
		tl.TextColor3 = Style.DARK
		tl.TextXAlignment = Enum.TextXAlignment.Left
		setRich(tl, (if n.shut then "+ " else "- ") .. (n.title or ""), 24)
		local l = root:FindFirstChild("Label") :: TextLabel
		l.TextXAlignment = Enum.TextXAlignment.Left
		setRich(l, if n.shut then "" else n.body, 16)
	elseif t == "bar" then
		local w, h = px(n.w) or 200, px(n.hh) or 50
		root.Size = UDim2.fromOffset(w, h)
		root.AutomaticSize = Enum.AutomaticSize.None
		root.BackgroundColor3 = Style.BG
		Style.stroke(root, 2, Style.TEXT, 0)
		Style.apply(root, n.base)
		local fill = root:FindFirstChild("Fill") :: Frame
		local p = math.clamp(tonumber(n.p) or 0, 0, 1)
		local dir = n.dir
		fill.BackgroundColor3 = Style.TEXT
		Style.apply(fill, n.fill)
		if dir == 0 then fill.Size = UDim2.fromScale(1, p); fill.Position = UDim2.fromScale(0, 1 - p)
		elseif dir == 1 then fill.Size = UDim2.fromScale(1, p); fill.Position = UDim2.fromScale(0, 0)
		elseif dir == 2 then fill.Size = UDim2.fromScale(p, 1); fill.Position = UDim2.fromScale(1 - p, 0)
		else fill.Size = UDim2.fromScale(p, 1); fill.Position = UDim2.fromScale(0, 0) end
		local l = root:FindFirstChild("Label") :: TextLabel
		l.Size = UDim2.fromScale(1, 1)
		l.AutomaticSize = Enum.AutomaticSize.None
		l.ZIndex = 2
		setRich(l, n.h, 14)
	end
end

function Render._updateButton(self: Renderer, rec: Rec, n: any)
	local b = rec.root :: TextButton
	local k = btnKind(n.k)
	local w = k.w
	-- class colours, then the game's style on top
	local base = Style.classColor(n.k, n.cls)
	if base then b.BackgroundColor3 = base; b.BackgroundTransparency = 0 else b.BackgroundTransparency = 1 end
	Style.corner(b, k.radius)
	Style.stroke(b, k.stroke)
	Style.pad(b, if n.k == "tab" then 6 else 5)
	local a = Style.apply(b, n.st)
	if n.cst then
		local a2 = Style.apply(b, n.cst)
		a.w, a.h, a.minH, a.font, a.text = a2.w or a.w, a2.h or a.h, a2.minH or a.minH, a2.font or a.font, a2.text or a.text
	end
	if n.k == "tab" then
		local c = n.st and Html.color(n.st["border-color"])
		Style.stroke(b, 2, c or Style.TEXT, 0)
		b.BackgroundTransparency = if n.cls == "cur" then 0.75 else 1
		b.BackgroundColor3 = c or Style.TEXT
	elseif n.k == "menu" and n.cls == "cur" then
		Style.stroke(b, 3, Color3.new(1, 1, 1), 0)
	end
	Style.glow(b, if n.glow then (Html.color(n.glow) or Color3.new(1, 0, 0)) elseif n.pulse then Color3.new(1, 1, 1) else nil)
	local width = a.w or w
	local minH = a.minH or a.h or k.h
	if width then
		b.Size = UDim2.fromOffset(width, if k.grow then 0 else (a.h or k.h))
		b.AutomaticSize = if k.grow then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	else
		b.Size = UDim2.fromOffset(0, a.h or k.h)
		b.AutomaticSize = Enum.AutomaticSize.X
	end
	sizeConstraint(b, nil, if k.grow then minH else nil, nil)
	local l = b:FindFirstChild("Label") :: TextLabel
	l.TextColor3 = a.text or k.text
	l.TextTransparency = a.textT or 0
	l.TextXAlignment = k.align or Enum.TextXAlignment.Center
	if width then
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.TextWrapped = true
	else
		l.Size = UDim2.new(0, 0, 1, 0)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.TextWrapped = false
	end
	if not k.grow then
		l.Size = UDim2.new(if width then 1 else 0, 0, 1, 0)
		l.AutomaticSize = if width then Enum.AutomaticSize.None else Enum.AutomaticSize.X
		l.TextScaled = false
	end
	setRich(l, n.h, a.font or k.font, n.k == "buy" or n.k == "click" or n.k == "grid")
	-- the upgrade's number, big and faint behind the text (upgNum)
	if n.n ~= nil and n.k == "upg" then
		local num = Style.child(b, "TextLabel", "Num") :: TextLabel
		num.BackgroundTransparency = 1
		num.Position = UDim2.fromOffset(1, 50)
		num.Size = UDim2.fromOffset(80, 60)
		num.TextXAlignment = Enum.TextXAlignment.Left
		num.FontFace = Style.FONT
		num.TextSize = 60
		num.TextColor3 = Style.DARK
		num.TextTransparency = 0.65
		num.ZIndex = 2
		num.Text = tostring(n.n)
	else
		Style.drop(b, "Num")
	end
	b.Active = n.a ~= nil
	b.Visible = not a.hidden
end

-- ---------------------------------------------------------------------------------------------------------- patches
function Render._children(self: Renderer, id: string): { string }
	local out = {}
	local set = self.kids[id]
	if set then for k in set do table.insert(out, k) end end
	return out
end

function Render._destroy(self: Renderer, id: string, keepKids: boolean?)
	local rec = self.recs[id]
	if not rec then return end
	if not keepKids then
		for _, k in self:_children(id) do self:_destroy(k) end
		self.kids[id] = nil
	end
	for _, c in rec.conns do c:Disconnect() end
	rec.root:Destroy()
	self.recs[id] = nil
	local p = parentOf(id)
	if p and self.kids[p] then self.kids[p][id] = nil end
end

function Render._place(self: Renderer, rec: Rec)
	local p, index = parentOf(rec.id)
	local parentObj: GuiObject? = nil
	if p == nil then
		parentObj = self.roots[rec.id]
	elseif self.recs[p] then
		parentObj = self.recs[p].content
	end
	rec.root.LayoutOrder = index
	rec.root.Parent = parentObj
	if p then
		self.kids[p] = self.kids[p] or {}
		self.kids[p][rec.id] = true
	end
end

function Render.apply(self: Renderer, patch: any)
	if patch.full then
		for id in self.recs do
			if parentOf(id) == nil then self:_destroy(id) end
		end
	end
	for _, id in patch.del or {} do self:_destroy(id) end
	local ids = {}
	for id in patch.set or {} do table.insert(ids, id) end
	table.sort(ids, function(a, b)
		local da, db = depth(a), depth(b)
		if da ~= db then return da < db end
		return a < b
	end)
	for _, id in ids do
		local n = patch.set[id]
		local rec: Rec? = self.recs[id]
		if rec and rec.kind ~= kindOf(n) then
			-- rebuilt: keep the children and move them to the new object
			local kids = self:_children(id)
			self:_destroy(id, true)
			local built = self:_build(id, n)
			rec = built
			self.recs[id] = built
			self:_place(built)
			self.kids[id] = {}
			for _, k in kids do
				local kr = self.recs[k]
				if kr then self:_place(kr) end
			end
		elseif not rec then
			local built = self:_build(id, n)
			rec = built
			self.recs[id] = built
			self:_place(built)
		end
		self:_update(rec :: Rec, n)
	end
end

function Render.clear(self: Renderer)
	for id in self.recs do
		if parentOf(id) == nil then self:_destroy(id) end
	end
end

return Render
