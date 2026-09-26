--!strict
--[[
	Toasts: the coalescing toasts at the top right of the free map rect, the "+N more" chip and the notification list
	(DESIGN.md 4.7, 7.3; mock h). The bookkeeping is ToastModel (pure).

	    Toast_<id>  400 x 72 (COMPACT 260 x 56): a horizontal hue gradient, hue rim, icon disc, title (`toast`, thin
	                outline) + ×N chip, sub (`small`), a 3 du life bar. Click-through. Enter: slide 60 du, Back Out.
	    More        "+N more" glass chip (bell); opens the list
	    Notify      the last 20: rows (title `cardSmall`, sub `small`), "EARLIER N", CLEAR; a row flies to its layer

	    local toasts = Toasts.new(root)
	    toasts:push(pops?, notices?)     toasts:setCollapsed(b)    toasts.flyTo (layer)
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Sleek = require(Core:WaitForChild("Sleek"))
local Skin = require(Core:WaitForChild("Skin"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))
local ToastModel = require(script.Parent:WaitForChild("ToastModel"))

export type Toasts = {
	frame: Frame,
	flyTo: Signal.Signal<string>,
	push: (self: Toasts, pops: { Types.Popup }?, notices: { string }?) -> (),
	setCollapsed: (self: Toasts, b: boolean) -> (),
	destroy: (self: Toasts) -> (),
}

local Toasts = {}
local instances = 0

local KIND: { [string]: { color: Color3, glyph: string } } = {
	milestone = { color = Color3.fromHex("ffc233"), glyph = "star" },
	achievement = { color = Theme.C.info, glyph = "star" },
	corruption = { color = Theme.hue("cp"), glyph = "check" },
	challenge = { color = Color3.fromHex("ffc233"), glyph = "star" },
	notice = { color = Theme.C.muted, glyph = "info" },
	other = { color = Theme.C.system, glyph = "bell" },
}

-- the HUD glass (R10) at alpha .88
local function glass(f: Frame)
	Sleek.plate(f, { alpha = 0.88, line = 0.86, strokeName = "GlassRim" })
end

local function iconDisc(parent: Instance, name: string, kind: string, d: number): Frame
	local spec = KIND[kind] or KIND.other
	-- Sleek: the kind's glyph in its colour, no disc
	local disc = Kit.frame(parent, name, 3)
	disc.Size = UDim2.fromOffset(d, d)
	local g = Kit.glyph(disc, "Icon", spec.glyph, spec.color, Sleek.C.top)
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.5)
	g.Size = UDim2.fromScale(0.62, 0.62)
	g.ZIndex = 4
	return disc
end
Toasts.iconDisc = iconDisc

function Toasts.new(root: GuiObject): Toasts
	local self = {} :: Toasts
	self.flyTo = Signal.new() :: Signal.Signal<string>
	local model = ToastModel.new()
	instances += 1
	local rectKey = "overlay.toasts" .. (if instances > 1 then tostring(instances) else "")
	local holder = Kit.frame(root, "Toasts", 20)
	holder.AnchorPoint = Vector2.new(1, 0)
	pcall(function() holder.Interactable = false end)
	self.frame = holder
	local views: { [number]: Frame? } = {}
	local collapsed = false
	local listOpen = false

	-- the "+N more" chip and the notification list (these take input)
	local more = Kit.frame(root, "More", 21)
	more.AnchorPoint = Vector2.new(1, 0)
	more.AutomaticSize = Enum.AutomaticSize.X
	glass(more)

	local mc = Kit.frame(more, "Content")
	mc.AutomaticSize = Enum.AutomaticSize.X
	mc.Size = UDim2.fromScale(0, 1)
	Kit.list(mc, "x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local bell = Kit.glyph(mc, "Bell", "bell", Color3.new(1, 1, 1))
	bell.LayoutOrder = 1
	bell.Size = UDim2.fromOffset(14, 14)
	local moreLabel = Kit.label(mc, "Label", "label", "", Color3.new(1, 1, 1))
	moreLabel.LayoutOrder = 2
	moreLabel.AutomaticSize = Enum.AutomaticSize.X
	moreLabel.Size = UDim2.fromScale(0, 1)
	local moreHit = Kit.button(more, "Hit")
	moreHit.Size = UDim2.new(1, 0, 1, 12)
	moreHit.Position = UDim2.fromOffset(0, -6)
	more.Visible = false

	local list = Kit.frame(root, "NotifyList", 22)
	list.AnchorPoint = Vector2.new(1, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	Sleek.plate(list, { alpha = 0.94, line = 0.86 })
	list.BackgroundTransparency = 0.04

	Kit.pad(list, 12, 12, 12, 12)
	Kit.list(list, "y", 6, Enum.HorizontalAlignment.Left)
	list.Visible = false

	local lastPush = 0
	local function width(): number
		return if Layout.mode == "COMPACT" then 260 else 400
	end
	local function maxShown(): number
		if Layout.mode == "COMPACT" then return 1 end
		if listOpen or collapsed then return if collapsed then 1 else 2 end
		return 3
	end

	local function place()
		local compact = Layout.mode == "COMPACT"
		local F = Layout.free()
		local s = Layout.s
		local ra = root.AbsolutePosition
		local x = (F.x + F.w - ra.X) / s - 16
		local y = if compact then 58 else 68
		holder.Position = UDim2.fromOffset(x, y)
		holder.Size = UDim2.fromOffset(width(), 0)
		local now = os.clock()
		local act = model:active(now)
		local shown = 0
		local pitch = if compact then 64 else 84
		for i, t in act do
			local v = views[t.id]
			if v == nil then continue end
			if i <= maxShown() then
				shown += 1
				v.Visible = true
				Motion.tween(v, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Position = UDim2.fromOffset(0, (shown - 1) * pitch) }, "toastY" .. t.id)
			else
				v.Visible = false
			end
		end
		local hidden = #model:history() - shown
		more.Visible = hidden > 0 and now - lastPush < 10 or listOpen
		moreLabel.Text = if listOpen then "Close" else "+" .. math.max(0, hidden) .. " more"
		Theme.text(moreLabel, "label")
		more.Size = UDim2.fromOffset(0, if compact then 30 else 34)
		Kit.pad(more, 0, 12, 0, 10)
		more.Position = UDim2.fromOffset(x, y + shown * pitch)
		-- the visible toasts are a HUD rect for the plates and markers
		if shown > 0 then
			Layout.setRect(rectKey, { x = ra.X + (x - width()) * s, y = ra.Y + y * s, w = width() * s, h = (shown * pitch) * s })
		else
			Layout.setRect(rectKey, nil)
		end
		list.Position = UDim2.fromOffset(x, y + shown * pitch + 42)
		list.Size = UDim2.fromOffset(width(), 0)
	end

	local function makeToast(t: ToastModel.Toast): Frame
		local compact = Layout.mode == "COMPACT"
		local spec = KIND[t.kind] or KIND.other
		local k = spec.color
		local w, h = width(), if compact then 56 else 72
		local f = Kit.frame(holder, "Toast_" .. t.id, 1)
		-- the holder is anchored at its top right (x is the free rect's right edge); a toast fills the holder's width
		f.AnchorPoint = Vector2.new(0, 0)
		f.Size = UDim2.fromOffset(w, h)
		f.Position = UDim2.fromOffset(0, 0)
		-- Sleek: a dark slab, a 3 du kind-colour bar on the left, corner ticks, the life line along the bottom
		Sleek.plate(f, { alpha = 0.9, line = 0.86 })
		Sleek.ticks(f, { len = 10, th = 2, out = 1, color = Color3.new(1, 1, 1), alpha = 0.8, z = 6 })
		Skin.apply(f, "plate", { scale = 0.5 })
		local side = Kit.frame(f, "Side", 4)
		side.Size = UDim2.new(0, 3, 1, 0)
		side.BackgroundColor3 = k
		side.BackgroundTransparency = 0
		local disc = iconDisc(f, "Icon", t.kind, if compact then 26 else 30)
		disc.AnchorPoint = Vector2.new(0, 0.5)
		disc.Position = UDim2.new(0, 18, 0.5, 0)
		local x0 = 18 + (if compact then 26 else 30) + 14
		local top = Kit.frame(f, "Top", 3)
		top.Position = UDim2.fromOffset(x0, if compact then 8 else 12)
		top.Size = UDim2.new(1, -x0 - 12, 0, if compact then 20 else 24)
		Kit.list(top, "x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		local title = Kit.label(top, "Title", "toast", t.title, Color3.new(1, 1, 1))
		title.LayoutOrder = 1
		title.AutomaticSize = Enum.AutomaticSize.X
		title.Size = UDim2.fromScale(0, 1)
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic)
		Kit.textStroke(title, 0)
		local over = Kit.child(title, "Overhang", "UIPadding") :: UIPadding
		over.PaddingRight = UDim.new(0, 2)
		local chip, cl = Kit.chip(top, "Count", "badge", "", { h = if compact then 18 else 20, pad = 6, fg = Theme.lift(k, 0.4),
			bgA = 0, line = k, lineA = 0.9 })
		chip.LayoutOrder = 2
		chip.Visible = false
		cl.RichText = true
		local sub = Kit.label(f, "Sub", "small", t.sub, Sleek.C.soft)
		sub.TextTransparency = 0
		sub.Position = UDim2.fromOffset(x0, if compact then 30 else 40)
		sub.Size = UDim2.new(1, -x0 - 12, 0, 18)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		local bar = Kit.frame(f, "Life", 4)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 3, 1, 0)
		bar.Size = UDim2.new(1, -3, 0, 2)
		bar.BackgroundColor3 = k
		bar.BackgroundTransparency = 0.2
		pcall(function() f.Interactable = false end)
		return f
	end

	local function refresh(t: ToastModel.Toast)
		local v = views[t.id]
		if v == nil then return end
		local top = v:FindFirstChild("Top")
		local chip = top and top:FindFirstChild("Count") :: Frame?
		if chip then
			chip.Visible = t.count > 1
			local cl = chip:FindFirstChild("Label") :: TextLabel?
			if cl then cl.Text = "×" .. t.count end
		end
		local sub = v:FindFirstChild("Sub") :: TextLabel?
		if sub then sub.Text = t.sub end
		local bar = v:FindFirstChild("Life") :: Frame?
		if bar then
			bar.Size = UDim2.new(1, -3, 0, 2)
			local life = if Motion.snapshot() then 0 else t.life
			Motion.tween(bar, TweenInfo.new(life, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }, "toastLife" .. t.id, true)
		end
	end

	local function expire(id: number)
		local v = views[id]
		if v == nil then return end
		views[id] = nil
		Motion.tween(v, TweenInfo.new(0.2), { Position = v.Position + UDim2.fromOffset(60, 0) }, "toastY" .. id)
		task.delay(0.22, function() v:Destroy() end)
	end

	local function sweep()
		local now = os.clock()
		local alive: { [number]: boolean } = {}
		for _, t in model:active(now) do alive[t.id] = true end
		for id in views do
			if not alive[id] then expire(id) end
		end
		place()
	end

	local function add(item: ToastModel.Item)
		local now = os.clock()
		lastPush = now
		local t, merged = model:push(item, now)
		if merged then
			refresh(t)
			local v = views[t.id]
			if v then Motion.bump(v, 0.06) end
		else
			local v = makeToast(t)
			views[t.id] = v
			refresh(t)
			local target = UDim2.fromOffset(0, 0)
			v.Position = target + UDim2.fromOffset(60, 0)
			Motion.tween(v, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target }, "toastY" .. t.id)
		end
		task.delay(t.life + 0.05, sweep)
		task.delay(10.1, place)
		place()
	end

	local function rebuildList()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		local hist = model:history()
		local head = Kit.frame(list, "Head")
		head.LayoutOrder = 0
		head.Size = UDim2.new(1, 0, 0, 24)
		local cap = Kit.label(head, "Earlier", "caps", Rich.caps("Earlier") .. "  " .. #hist, Theme.C.soft)
		cap.Size = UDim2.fromScale(0.6, 1)
		cap.TextXAlignment = Enum.TextXAlignment.Left
		local clear = Kit.button(head, "Clear")
		clear.AnchorPoint = Vector2.new(1, 0.5)
		clear.Position = UDim2.new(1, 0, 0.5, 0)
		clear.Size = UDim2.fromOffset(64, 44)
		local cl = Kit.label(clear, "Label", "label", "Clear", Theme.C.info)
		cl.Size = UDim2.fromScale(1, 1)
		cl.TextXAlignment = Enum.TextXAlignment.Right
		clear.Activated:Connect(function()
			model:clear()
			listOpen = false
			list.Visible = false
			place()
		end)
		for i, t in hist do
			local row = Kit.button(list, "Row" .. i)
			row.LayoutOrder = i
			row.Size = UDim2.new(1, 0, 0, 56)
			row.BackgroundTransparency = 0
			row.BackgroundColor3 = Theme.C.panel2
			Kit.corner(row, UDim.new(0, 0)) -- Sleek: square
			local disc = iconDisc(row, "Icon", t.kind, 32)
			disc.AnchorPoint = Vector2.new(0, 0.5)
			disc.Position = UDim2.new(0, 10, 0.5, 0)
			local title = Kit.label(row, "Title", "cardSmall", t.title .. (if t.count > 1 then "  ×" .. t.count else ""), Theme.C.text)
			title.Position = UDim2.fromOffset(54, 8)
			title.Size = UDim2.new(1, -64, 0, 20)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextTruncate = Enum.TextTruncate.AtEnd
			local sub = Kit.label(row, "Sub", "small", t.sub, Theme.C.soft)
			sub.Position = UDim2.fromOffset(54, 30)
			sub.Size = UDim2.new(1, -64, 0, 18)
			sub.TextXAlignment = Enum.TextXAlignment.Left
			sub.TextTruncate = Enum.TextTruncate.AtEnd
			local layer = t.layer
			row.Activated:Connect(function()
				if layer then self.flyTo:Fire(layer) end
			end)
		end
	end
	moreHit.Activated:Connect(function()
		listOpen = not listOpen
		list.Visible = listOpen
		if listOpen then rebuildList() end
		place()
	end)

	function self.push(_: Toasts, pops: { Types.Popup }?, notices: { string }?)
		for _, p in (pops or {}) :: { Types.Popup } do
			if type(p) ~= "table" then continue end
			local kind = ToastModel.kindOf(p :: any)
			local title = ToastModel.plain(p.title)
			if title == "" then title = if kind == "achievement" then "Achievement Gotten!" else "Notice" end
			add({ kind = kind, title = title, sub = ToastModel.plain(p.message), layer = p.layer })
		end
		for _, n in (notices or {}) :: { string } do
			if type(n) == "string" and n ~= "" then add({ kind = "notice", title = "Notice", sub = ToastModel.plain(n), layer = nil }) end
		end
	end
	function self.setCollapsed(_: Toasts, b: boolean)
		collapsed = b
		place()
	end
	function self.destroy(t: Toasts)
		t.flyTo:DisconnectAll()
		Layout.setRect(rectKey, nil)
		holder:Destroy()
		more:Destroy()
		list:Destroy()
	end
	-- HUD rects move the free rect's edge (a side sheet): follow on the next frame, never re-entrantly
	local queued = false
	local function soon()
		if queued then return end
		queued = true
		task.defer(function()
			queued = false
			if holder.Parent then place() end
		end)
	end
	Layout.changed:Connect(soon)
	Layout.rectsChanged:Connect(soon)
	place()
	return self
end

return Toasts
