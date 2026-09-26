--!strict
--[[
	Tooltip: the one-owner hover tooltip (DESIGN.md 7.1, Figma 4:68). Mouse only, after 250 ms, at the cursor +
	(16, -h - 12), clamped to the screen (it flips below / left when there is no room). One owner at a time; the
	owner's Destroying hides it.

	    Tooltip   360 du (COMPACT 300), panel3 -> panel, rim lift(c, .2), hue glow
	      Title   `cardSmall`, lift(c, .55)
	      Body    `body` RichText (the game's HTML, colours remapped)
	      Rows    two aligned rows ("Need" / "Have": `small` soft labels, `number` values with Rich.num units)
	      Bar     the `pr` progress with its % (Rich.pct)
	      Foot    `small` soft, sentence case ("Click to open · right-click to peek")

	    local tip = Tooltip.new(root)
	    tip:show(owner, content?, at?)   content = { title, body?, rows?, pr?, foot?, hue?, layer? }; nil hides; an empty
	                                     title is left out (the game's own card tooltips)
	    tip:hide(owner?)
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Rich = require(Core:WaitForChild("Rich"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))

export type Content = {
	title: string,
	body: string?, -- game HTML
	rows: { { string } }?, -- { label, value }
	pr: number?, -- 0..1
	foot: string?,
	hue: Color3?,
	layer: string?,
}
export type Tooltip = {
	frame: Frame,
	show: (self: Tooltip, owner: any, content: Content?, at: Vector2?) -> (),
	hide: (self: Tooltip, owner: any?) -> (),
	owner: (self: Tooltip) -> any?,
	destroy: (self: Tooltip) -> (),
}

local Tooltip = {}

function Tooltip.new(root: GuiObject): Tooltip
	local self = {} :: Tooltip
	local f = Kit.frame(root, "Tooltip", 40)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.02
	f.Visible = false
	Kit.corner(f, UDim.new(0, 0)) -- Sleek: square
	Kit.grad(f, { Theme.C.panel3, Theme.C.panel }, 90, nil, "Back")
	local rim = Kit.stroke(f, 1.5, Theme.C.strokeHi, 1, "Rim")
	Kit.pad(f, 14, 16, 14, 16)
	Kit.list(f, "y", 6, Enum.HorizontalAlignment.Left)
	pcall(function() f.Interactable = false end)
	self.frame = f

	local title = Kit.label(f, "Title", "cardSmall", "", Theme.C.text)
	title.LayoutOrder = 1
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.Size = UDim2.fromScale(1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = true
	local body = Kit.label(f, "Body", "body", "", Theme.C.text)
	body.LayoutOrder = 2
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Size = UDim2.fromScale(1, 0)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
	body.RichText = true
	local rows = Kit.frame(f, "Rows")
	rows.LayoutOrder = 3
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.Size = UDim2.fromScale(1, 0)
	Kit.list(rows, "y", 4, Enum.HorizontalAlignment.Left)
	local bar = Kit.frame(f, "Bar")
	bar.LayoutOrder = 4
	bar.Size = UDim2.new(1, 0, 0, 18)
	local track = Kit.frame(bar, "Track")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.fromScale(0, 0.5)
	track.Size = UDim2.new(1, -56, 0, 6)
	track.BackgroundColor3 = Theme.C.deep
	track.BackgroundTransparency = 0
	Kit.corner(track)
	local fill = Kit.frame(track, "Fill")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.C.danger
	fill.BackgroundTransparency = 0
	Kit.corner(fill)
	local pct = Kit.label(bar, "Pct", "number", "", Theme.C.text)
	pct.AnchorPoint = Vector2.new(1, 0.5)
	pct.Position = UDim2.fromScale(1, 0.5)
	pct.Size = UDim2.fromOffset(52, 18)
	pct.TextXAlignment = Enum.TextXAlignment.Right
	local foot = Kit.label(f, "Foot", "small", "", Theme.C.soft)
	foot.LayoutOrder = 5
	foot.AutomaticSize = Enum.AutomaticSize.Y
	foot.Size = UDim2.fromScale(1, 0)
	foot.TextXAlignment = Enum.TextXAlignment.Left
	foot.TextWrapped = true

	local current: any = nil
	local lastSig = ""
	local token = 0
	local destroyConn: RBXScriptConnection? = nil

	local function row(i: number, k: string, v: string)
		local r = Kit.frame(rows, "Row" .. i)
		r.LayoutOrder = i
		r.Size = UDim2.new(1, 0, 0, 20)
		local kl = Kit.label(r, "Key", "small", k, Theme.C.soft)
		kl.Size = UDim2.fromScale(0.4, 1)
		kl.TextXAlignment = Enum.TextXAlignment.Left
		local vl = Kit.label(r, "Value", "number", "", Theme.C.text)
		vl.AnchorPoint = Vector2.new(1, 0)
		vl.Position = UDim2.fromScale(1, 0)
		vl.Size = UDim2.fromScale(0.6, 1)
		vl.TextXAlignment = Enum.TextXAlignment.Right
		vl.RichText = true
		vl.Text = Rich.num(v, { size = Theme.size("number"), unit = Theme.C.soft })
	end

	local function fill_(c: Content)
		local hue = c.hue or Theme.hue(c.layer)
		local compact = Layout.mode == "COMPACT"
		f.Size = UDim2.fromOffset(if compact then 300 else 360, 0)
		rim.Color = Theme.lift(hue, 0.2)
		title.Text = c.title
		title.Visible = c.title ~= "" -- the game's own tooltips (panel cards) come without a title
		title.TextColor3 = Theme.lift(hue, 0.55)
		Theme.text(title, "cardSmall")
		local b = c.body
		body.Visible = b ~= nil and b ~= ""
		if b then body.Text = Rich.html(b, Theme.size("body"), c.layer) end
		Theme.text(body, "body")
		for _, x in rows:GetChildren() do
			if x:IsA("GuiObject") then x:Destroy() end
		end
		local list = (c.rows or {}) :: { { string } }
		rows.Visible = #list > 0
		for i, r in list do row(i, r[1], r[2]) end
		local p = c.pr
		bar.Visible = p ~= nil
		if p then
			fill.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
			fill.BackgroundColor3 = if p >= 1 then Theme.C.bought else Theme.lift(hue, 0.1)
			pct.Text = Rich.pct(p)
		end
		foot.Visible = c.foot ~= nil
		foot.Text = c.foot or ""
		Theme.text(foot, "small")
	end

	local function place(at: Vector2)
		local s = Layout.s
		local ra, rs = root.AbsolutePosition, root.AbsoluteSize
		local lx, ly = (at.X - ra.X) / s, (at.Y - ra.Y) / s
		local w, h = f.Size.X.Offset, math.max(40, f.AbsoluteSize.Y / s)
		local W, H = rs.X / s, rs.Y / s
		local x, y = lx + 16, ly - h - 12
		if x + w > W - 8 then x = lx - 16 - w end
		if y < 8 then y = ly + 24 end
		x = math.clamp(x, 8, math.max(8, W - w - 8))
		y = math.clamp(y, 8, math.max(8, H - h - 8))
		f.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	end

	function self.show(t: Tooltip, owner: any, content: Content?, at: Vector2?)
		if content == nil then
			t:hide(owner)
			return
		end
		local was = current
		current = owner
		token += 1
		local my = token
		if destroyConn then
			destroyConn:Disconnect()
			destroyConn = nil
		end
		if typeof(owner) == "Instance" then
			destroyConn = (owner :: Instance).Destroying:Connect(function()
				if current == owner then t:hide(owner) end
			end)
		end
		local sig = content.title .. "|" .. (content.body or "") .. "|" .. tostring(content.pr) .. "|" .. (content.foot or "")
		for _, r in (content.rows or {}) :: { { string } } do sig ..= "|" .. r[1] .. "=" .. r[2] end
		if sig ~= lastSig or was ~= owner then
			lastSig = sig
			fill_(content)
		end
		local pos = at
		if was == owner and f.Visible then
			if pos then place(pos) end
			return
		end
		-- the 250 ms hover delay (a new owner while one shows switches at once)
		local delay = if f.Visible then 0 else 0.25
		task.delay(delay, function()
			if token ~= my or current ~= owner then return end
			f.Visible = true
			if pos then place(pos) end
			task.defer(function()
				if token == my and pos then place(pos) end
			end)
		end)
	end
	function self.hide(_: Tooltip, owner: any?)
		if owner ~= nil and owner ~= current then return end
		current = nil
		token += 1
		f.Visible = false
	end
	function self.owner(_: Tooltip): any?
		return current
	end
	function self.destroy(_: Tooltip)
		if destroyConn then destroyConn:Disconnect() end
		f:Destroy()
	end
	return self
end

return Tooltip
