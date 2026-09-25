--!strict
--[[
	Virtual: a fixed-row pool for long lists (DESIGN.md 5.8, plan 2.5). The host Frame (a claim's placeholder inside
	the panel's scrolling body) is sized to the whole list; only ceil(viewport / pitch) + 2 row frames exist, moved and
	redrawn as the body scrolls.

	    local v = Virtual.new({ scroll = sf, host = ph, top = 48, rowH = 64, gap = 8, count = n, draw = fn(row, i) })
	    v:setCount(n); v:redraw(); v:destroy()

	Virtual.milestones(ph, id, store, ctx) is the default claim for a milestone ladder longer than Virtual.MS_ROWS:
	a section header, then one row per milestone (NEXT in the hue, done in quiet green, future faint), with the row's
	INFECT button when the game sends one (the button fires the malware node's own action).
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Rich = require(Core:WaitForChild("Rich"))
local Common = require(script.Parent:WaitForChild("Skins"):WaitForChild("Common"))
local Milestone = require(script.Parent:WaitForChild("Skins"):WaitForChild("Milestone"))
local Sections = require(script.Parent:WaitForChild("Sections"))

local Virtual = {}
Virtual.__index = Virtual

-- ladders longer than this are virtualised by default (keeps a panel within its instance budget)
Virtual.MS_ROWS = 24

local C = Theme.C

export type Options = {
	scroll: ScrollingFrame,
	host: Frame,
	top: number, -- du above the first row (a header)
	rowH: number,
	gap: number,
	count: number,
	draw: (row: Frame, i: number) -> (),
}

export type Virtual = typeof(setmetatable({} :: {
	o: Options,
	rows: { Frame },
	first: number,
	conns: { RBXScriptConnection },
	alive: boolean,
}, Virtual))

function Virtual.new(o: Options): Virtual
	local self = setmetatable({ o = o, rows = {}, first = -1, conns = {}, alive = true }, Virtual)
	o.host.AutomaticSize = Enum.AutomaticSize.None
	o.host.ClipsDescendants = false
	table.insert(self.conns, o.scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:place(false) end))
	table.insert(self.conns, o.scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:place(true) end))
	self:setCount(o.count)
	return self
end

function Virtual.pitch(self: Virtual): number
	return self.o.rowH + self.o.gap
end

function Virtual.setCount(self: Virtual, n: number)
	self.o.count = n
	local o = self.o
	o.host.Size = UDim2.new(1, 0, 0, o.top + math.max(0, n * self:pitch() - o.gap))
	self:place(true)
end

-- how many rows fit the viewport, plus two
function Virtual.poolSize(self: Virtual): number
	local s = math.max(Layout.s, 0.01)
	local vh = self.o.scroll.AbsoluteSize.Y / s
	if vh < 1 then vh = 900 end
	return math.ceil(vh / self:pitch()) + 2
end

function Virtual.place(self: Virtual, force: boolean)
	if not self.alive then return end
	local o = self.o
	local s = math.max(Layout.s, 0.01)
	-- where the host's first row is, relative to the visible top of the scroll (du)
	local dy = (o.host.AbsolutePosition.Y - o.scroll.AbsolutePosition.Y) / s + o.top
	local first = math.max(0, math.floor(-dy / self:pitch()))
	local pool = math.min(self:poolSize(), math.max(0, o.count))
	-- grow / shrink the pool
	while #self.rows < pool do
		local row = Instance.new("Frame")
		row.Name = "Row" .. (#self.rows + 1)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, o.rowH)
		row.Parent = o.host
		table.insert(self.rows, row)
		force = true
	end
	while #self.rows > pool do
		local row = table.remove(self.rows) :: Frame
		row:Destroy()
		force = true
	end
	if first == self.first and not force then return end
	self.first = first
	for k, row in self.rows do
		local i = first + k
		if i <= o.count then
			row.Visible = true
			row.Size = UDim2.new(1, 0, 0, o.rowH)
			row.Position = UDim2.fromOffset(0, o.top + (i - 1) * self:pitch())
			local ok, err = Common.try(o.draw, row, i)
			if not ok then warn("[MilestoneTree] virtual row failed: " .. tostring(err)) end
		else
			row.Visible = false
		end
	end
end

function Virtual.redraw(self: Virtual)
	self:place(true)
end

function Virtual.destroy(self: Virtual)
	self.alive = false
	for _, c in self.conns do c:Disconnect() end
	for _, r in self.rows do r:Destroy() end
	table.clear(self.rows)
end

-- ------------------------------------------------------------------------------------------------------ milestones
local function drawRow(row: Frame, n: any, kind: string, ctx: any, mal: any?)
	local bg = if kind == "next" then Theme.mix(C.panel, ctx.hue, 0.38) elseif kind == "done" then Theme.mix(C.panel, C.bought, 0.14) else C.panel2
	row.BackgroundColor3 = bg
	row.BackgroundTransparency = 0
	Common.corner(row, 12)
	Common.stroke(row, if kind == "next" or n.mal then 2 else 1, if n.mal then C.danger elseif kind == "next" then Theme.lift(ctx.hue, 0.35)
		elseif kind == "done" then C.bought else C.stroke, if kind == "done" then 0.6 elseif kind == "future" then 0.35 else 0)
	local t = Common.get(row, "Text", "TextLabel") :: TextLabel
	Common.text(t, "small", C.text)
	t.Position = UDim2.fromOffset(16, 8)
	t.Size = UDim2.new(1, if mal then -200 else -32, 1, -16)
	t.AutomaticSize = Enum.AutomaticSize.None
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextWrapped = true
	t.TextTruncate = Enum.TextTruncate.AtEnd
	local title = Common.plain(Common.str(n.ti) or "")
	local titleRun = Common.title(title, "cardSmall", if kind == "done" then C.ownedTitle else C.text)
	if kind == "next" then titleRun = Common.caps("Next", C.text) .. "  " .. titleRun end
	local ds = Common.html(n.ds, "small", ctx.layer)
	local text = titleRun
	if ds ~= "" then
		text ..= "\n" .. string.format('<font color="%s" transparency="0.1">%s</font>', Common.hex(if kind == "future" then C.soft else C.text), ds)
	end
	Common.setText(t, text)
	-- the INFECT button of the malware ladder (the malware node's own action, read at press time)
	if mal then
		local b = Common.get(row, "Infect", "TextButton") :: TextButton
		b.AutoButtonColor = false
		b.Text = ""
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -12, 0.5, 0)
		b.Size = UDim2.fromOffset(170, 44)
		local infected = mal.cls == "pseudo"
		local can = mal.cls == "can" or mal.cls == "perk"
		b.BackgroundColor3 = if infected then Theme.mix(C.panel, C.danger, 0.35) elseif can then C.danger else Theme.mix(C.panel, C.locked, 0.3)
		b.BackgroundTransparency = 0
		Common.corner(b, 10)
		local bl = Common.get(b, "Label", "TextLabel") :: TextLabel
		Common.text(bl, "label", C.text)
		bl.Size = UDim2.fromScale(1, 1)
		bl.TextXAlignment = Enum.TextXAlignment.Center
		bl.TextYAlignment = Enum.TextYAlignment.Center
		bl.TextWrapped = false
		local co = Common.str(mal.co)
		local label = if infected then "INFECTED" else "INFECT"
		Common.setText(bl, Common.esc(label) .. (if co and not infected then "  " .. Common.num(Rich.short(co), "number", C.text) else ""))
		b:SetAttribute("State", if infected then "owned" elseif can then "can" else "notyet")
		b:SetAttribute("Ms", n.id)
	else
		Common.drop(row, "Infect")
	end
end

function Virtual.milestones(ph: Frame, id: string, store: any, ctx: any): any
	local compact = Layout.mode == "COMPACT"
	local header = 52
	local ids: { string } = {}
	local rowsById: { [Frame]: string } = {}
	local function collect(st: any)
		table.clear(ids)
		for _, cid in st:kids(id) do
			local k = st:get(cid)
			if type(k) == "table" and k.t == "ms" then table.insert(ids, cid) end
		end
	end
	collect(store)
	local current = store
	local v: Virtual
	v = Virtual.new({
		scroll = ctx.scroll,
		host = ph,
		top = header,
		rowH = if compact then 60 else 64,
		gap = 8,
		count = #ids,
		draw = function(row: Frame, i: number)
			local cid = ids[i]
			local n = if cid then current:get(cid) else nil
			if type(n) ~= "table" then
				row.Visible = false
				return
			end
			local nextId = Milestone.nextOf({ cache = {}, store = current }, id)
			local kind = if n.done then "done" elseif cid == nextId then "next" else "future"
			local malId = current:kids(cid)[1]
			local mal = if malId then current:get(malId) else nil
			if type(mal) ~= "table" or mal.k ~= "malware" then mal = nil end
			drawRow(row, n, kind, ctx, mal)
			rowsById[row] = cid
			local b = row:FindFirstChild("Infect")
			if b and b:IsA("TextButton") and b:GetAttribute("Wired") ~= true then
				b:SetAttribute("Wired", true)
				b.Activated:Connect(function()
					local msId = rowsById[row]
					local mid = if msId then current:kids(msId)[1] else nil
					local m = if mid then current:get(mid) else nil
					if type(m) == "table" and type(m.a) == "table" then ctx.act(m.a, false) end
				end)
			end
		end,
	})
	local function head(st: any)
		local done = 0
		for _, cid in ids do
			local k = st:get(cid)
			if type(k) == "table" and k.done then done += 1 end
		end
		Sections.header(ph, { name = "Head", text = Sections.titleOf("milestones", ctx.layer) or "MILESTONES", hue = ctx.hue,
			chips = { { text = done .. " / " .. #ids .. " DONE", color = C.ownedValue, bg = Theme.mix(C.deep, C.bought, 0.16), bgT = 0 } } })
		local h = ph:FindFirstChild("Head") :: Frame?
		if h then h.Position = UDim2.new() end
	end
	head(store)
	local claim = {}
	function claim.update(_: any, st: any)
		current = st or current
		collect(current)
		head(current)
		v:setCount(#ids)
	end
	function claim.destroy(_: any)
		v:destroy()
		Common.drop(ph, "Head")
	end
	return claim
end

return Virtual
