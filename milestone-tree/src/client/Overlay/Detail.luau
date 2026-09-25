--!strict
--[[
	Detail: the touch detail sheet (DESIGN.md 7.4). A long-press on an upgrade (or on a buyable) in the panel opens a
	full-width bottom sheet: the whole text (never clamped), CURRENTLY / COST / LEVEL rows, the progress bar, and the
	big action (BUY; HOLD TO BUY repeats for buyables that repeat). Holds happen here, away from the scroll list.
	Dismiss: a tap outside, the handle, or a drag down of 60 du.

	    local d = Detail.new(root)
	    d:show(card?)      card = { id, kind, node, layer, get = fn(id) -> node? }; nil closes
	    d:refresh()        re-reads the card's node (a patch changed the tab)
	    d:isOpen() -> id?
	    d.act (action, hold)     the node's own `a`, read from the store at press time (plan 1.11)
]]

local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))

export type Card = { id: string, kind: string, node: any, layer: string?, get: ((id: string) -> any)? }
export type Detail = {
	frame: Frame,
	act: Signal.Signal<Types.Action, boolean>,
	show: (self: Detail, card: Card?) -> (),
	refresh: (self: Detail) -> (),
	isOpen: (self: Detail) -> string?,
	destroy: (self: Detail) -> (),
}

local Detail = {}

local WHITE = Color3.new(1, 1, 1)

local function str(v: any): string?
	if type(v) == "string" and v ~= "" then return v end
	if type(v) == "number" then return tostring(v) end
	return nil
end
local function plain(html: string): string
	local s = string.gsub(html, "<br%s*/?>", " ")
	s = string.gsub(s, "<[^>]*>", "")
	s = string.gsub(s, "&nbsp;", " ")
	return (string.gsub(s, "%s+", " "))
end

function Detail.new(root: GuiObject): Detail
	local self = {} :: Detail
	self.act = Signal.new() :: Signal.Signal<Types.Action, boolean>

	local dimmer = Kit.button(root, "DetailDimmer")
	dimmer.Size = UDim2.fromScale(1, 1)
	dimmer.BackgroundColor3 = Color3.new(0, 0, 0)
	dimmer.BackgroundTransparency = 0.5
	dimmer.ZIndex = 55
	dimmer.Visible = false
	local sheet = Kit.frame(root, "Detail", 56)
	sheet.AnchorPoint = Vector2.new(0.5, 1)
	sheet.Position = UDim2.fromScale(0.5, 1)
	sheet.AutomaticSize = Enum.AutomaticSize.Y
	sheet.BackgroundColor3 = WHITE
	sheet.BackgroundTransparency = 0
	sheet.Active = true
	sheet.Visible = false
	Kit.corner(sheet, UDim.new(0, 20))
	Kit.grad(sheet, { Theme.C.panel2, Theme.C.panel }, 90, nil, "Back")
	local rim = Kit.stroke(sheet, 2, Theme.C.strokeHi, 1, "Rim")
	Kit.list(sheet, "y", 12, Enum.HorizontalAlignment.Left)
	self.frame = sheet

	local card: Card? = nil
	local conns: { RBXScriptConnection } = {}
	local holding: InputObject? = nil -- the press of a HOLD TO BUY in progress
	local dirty = false -- a refresh came in while holding: redraw on release

	local function close()
		card = nil
		holding = nil
		dirty = false
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		sheet.Visible = false
		dimmer.Visible = false
	end
	dimmer.Activated:Connect(close)

	local function node(): any
		local c = card
		if c == nil then return nil end
		local n = if c.get then c.get(c.id) else nil
		if type(n) == "table" then return n end
		return c.node
	end

	local function row(parent: Instance, order: number, key: string, value: string)
		local r = Kit.frame(parent, "Row" .. order)
		r.LayoutOrder = order
		r.Size = UDim2.new(1, 0, 0, 24)
		local k = Kit.label(r, "Key", "caps", Rich.caps(key), Theme.C.soft)
		k.Size = UDim2.fromScale(0.35, 1)
		k.TextXAlignment = Enum.TextXAlignment.Left
		local v = Kit.label(r, "Value", "number", "", WHITE)
		v.AnchorPoint = Vector2.new(1, 0)
		v.Position = UDim2.fromScale(1, 0)
		v.Size = UDim2.fromScale(0.65, 1)
		v.TextXAlignment = Enum.TextXAlignment.Right
		v.RichText = true
		v.Text = Rich.num(value, { size = Theme.size("number"), unit = Theme.C.soft })
	end

	local function draw()
		local c = card
		local n = node()
		if c == nil or n == nil then return end
		for _, x in sheet:GetChildren() do
			if x:IsA("GuiObject") then x:Destroy() end
		end
		for _, x in conns do x:Disconnect() end
		table.clear(conns)
		local compact = Layout.mode == "COMPACT"
		local hue = Theme.hue(c.layer)
		rim.Color = Theme.lift(hue, 0.25)
		sheet.Size = UDim2.fromOffset(math.min(Layout.canvas.X - 24, 760), 0)
		Kit.pad(sheet, 10, if compact then 18 else 24, 18, if compact then 18 else 24)
		-- the handle (a tap or a drag down of 60 du closes)
		local handle = Kit.button(sheet, "Handle")
		handle.LayoutOrder = 1
		handle.Size = UDim2.new(1, 0, 0, 24)
		local bar = Kit.frame(handle, "Bar")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(56, 5)
		bar.BackgroundColor3 = Theme.C.soft
		bar.BackgroundTransparency = 0.3
		Kit.corner(bar)
		handle.Activated:Connect(close)
		table.insert(conns, handle.InputBegan:Connect(function(io: InputObject)
			if io.UserInputType ~= Enum.UserInputType.Touch and io.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			local y0 = io.Position.Y
			local moveConn: RBXScriptConnection
			moveConn = UserInputService.InputChanged:Connect(function(m: InputObject)
				if m ~= io and m.UserInputType ~= Enum.UserInputType.MouseMovement then return end
				if m.Position.Y - y0 > 60 * Layout.s then
					moveConn:Disconnect()
					close()
				end
			end)
			table.insert(conns, moveConn)
			table.insert(conns, UserInputService.InputEnded:Connect(function(e: InputObject)
				if e == io or e.UserInputType == Enum.UserInputType.MouseButton1 then moveConn:Disconnect() end
			end))
		end))
		-- the title and the whole text
		local h = str(n.h) or ""
		local titleText = str(n.ti) or plain(string.match(h, "^(.-)<br") or h)
		local title = Kit.label(sheet, "Title", "card", titleText, Theme.lift(hue, 0.55))
		title.LayoutOrder = 2
		title.AutomaticSize = Enum.AutomaticSize.Y
		title.Size = UDim2.fromScale(1, 0)
		title.TextWrapped = true
		title.TextXAlignment = Enum.TextXAlignment.Left
		local text = str(n.ds) or h
		local body = Kit.label(sheet, "Body", "body", "", Theme.C.text)
		body.LayoutOrder = 3
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.Size = UDim2.fromScale(1, 0)
		body.TextWrapped = true
		body.RichText = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.Text = Rich.html(text, Theme.size("body"), c.layer, true)
		-- the numbers
		local rows = Kit.frame(sheet, "Rows")
		rows.LayoutOrder = 4
		rows.AutomaticSize = Enum.AutomaticSize.Y
		rows.Size = UDim2.fromScale(1, 0)
		Kit.list(rows, "y", 6, Enum.HorizontalAlignment.Left)
		local order = 0
		local function add(k: string, v: string?)
			if v == nil then return end
			order += 1
			row(rows, order, k, v)
		end
		add("Currently", str(n.ef))
		if str(n.lv) then add("Level", (str(n.lv) :: string) .. (if str(n.max) then " / " .. (str(n.max) :: string) else "")) end
		if str(n.co) then add("Cost", (str(n.co) :: string) .. (if str(n.cur) then " " .. (str(n.cur) :: string) else "")) end
		rows.Visible = order > 0
		local pr = n.pr
		if type(pr) == "number" then
			local track = Kit.frame(sheet, "Bar")
			track.LayoutOrder = 5
			track.Size = UDim2.new(1, 0, 0, 8)
			track.BackgroundColor3 = Theme.C.deep
			track.BackgroundTransparency = 0
			Kit.corner(track)
			local fill = Kit.frame(track, "Fill")
			fill.Size = UDim2.fromScale(math.clamp(pr / 1000, 0, 1), 1)
			fill.BackgroundColor3 = Theme.lift(hue, 0.1)
			fill.BackgroundTransparency = 0
			Kit.corner(fill)
		end
		-- the big action
		local buttons = Kit.frame(sheet, "Buttons")
		buttons.LayoutOrder = 6
		buttons.Size = UDim2.new(1, 0, 0, 56)
		Kit.list(buttons, "x", 12, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		local cls = str(n.cls) or ""
		local can = cls == "can"
		local word = if cls == "bought" then "Owned" elseif not can then "Not affordable" elseif n.hold then "Hold to buy" else "Buy"
		local b = Kit.action(buttons, "Primary", Rich.caps(word), { style = if can then "primary" else "quiet", hue = hue, h = 56, role = "cta" })
		b:SetAttribute("State", if can then "can" else cls)
		local done = Kit.action(buttons, "Done", Rich.caps("Done"), { style = "quiet", h = 56 })
		done.LayoutOrder = -1
		done.Activated:Connect(close)
		if can then
			b.Activated:Connect(function()
				local cur = node()
				local a = cur and cur.a
				if type(a) == "table" then self.act:Fire(a, false) end
			end)
			if n.hold then
				-- hold to repeat: after 0.25 s, 20 presses a second while the pointer stays down (as in the panel)
				table.insert(conns, b.InputBegan:Connect(function(io: InputObject)
					if io.UserInputType ~= Enum.UserInputType.Touch and io.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					holding = io
					task.delay(0.25, function()
						while holding == io and sheet.Visible do
							local cur = node()
							local a = cur and cur.a
							if type(a) ~= "table" or cur.cls ~= "can" then break end
							self.act:Fire(a, true)
							task.wait(0.05)
						end
					end)
				end))
			end
		end
	end

	local endConn = UserInputService.InputEnded:Connect(function(io: InputObject)
		local h = holding
		if h == nil then return end
		if io == h or io.UserInputType == h.UserInputType and io.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = nil
			if dirty then
				dirty = false
				draw()
			end
		end
	end)

	function self.show(_: Detail, c: Card?)
		if c == nil then
			close()
			return
		end
		card = c
		draw()
		dimmer.Visible = true
		sheet.Visible = true
		if not Motion.reduced() then
			sheet.Position = UDim2.new(0.5, 0, 1, 40)
			Motion.tween(sheet, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 1) }, "detailOpen")
		else
			sheet.Position = UDim2.fromScale(0.5, 1)
		end
	end
	function self.refresh(_: Detail)
		if card == nil then return end
		local n = node()
		local sig = if n then tostring(n.cls) .. "|" .. tostring(n.h) .. "|" .. tostring(n.pr) .. "|" .. tostring(n.lv) else ""
		if sheet:GetAttribute("Sig") == sig then return end
		sheet:SetAttribute("Sig", sig)
		if holding then
			dirty = true
		else
			draw()
		end
	end
	function self.isOpen(_: Detail): string?
		return if card then card.id else nil
	end
	function self.destroy(d: Detail)
		close()
		endConn:Disconnect()
		d.act:DisconnectAll()
		sheet:Destroy()
		dimmer:Destroy()
	end
	return self
end

return Detail
