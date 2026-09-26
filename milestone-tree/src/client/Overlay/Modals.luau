--!strict
--[[
	Modals: the modal chrome and its uses (DESIGN.md 7.5-7.8; mock j). Saves live in Roblox, so there is no export,
	import or hard reset.

	    ModalDimmer  black alpha .6, takes every input (InputSink All); a tap closes (not during a hold)
	    Modal        the card: panel2 -> panel, a hue rim, the head (icon disc + R3 title + a hue sub line), the body,
	                 the Buttons row. Opens with scale .96 -> 1 (0.2 s).
	      gate       the Multiverse gate: PRESTIGE MULTIVERSE, the context, the GOAL box (+ Goal met chip), what
	                 happens (the reset list / completes / returns), STAY + HOLD TO ENTER | EXIT | FINISH (1.2 s);
	                 locked: "Unlock Multiverse (MP) first"; sealed: the requirement with its bar
	      ranks      LEADERBOARDS: a tab per board (24, arrows step through), the player's own best, the top 50
	      shop       SHOP: the game passes (OWNED / R$ price / SOON without an id) and the Time Warps; a press opens
	                 Roblox's purchase prompt (the server grants it, see server/Shop.luau); redraws when MT_Perks changes

	    local modals = Modals.new(root)
	    modals:open(kind?, data?)      nil closes. data: gate = Gate; any other kind shows data as text with OK
	    modals:isOpen() -> kind?
	    modals.act (action, hold?), modals.closed (), modals.notice (text)
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
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Products = require(game:GetService("ReplicatedStorage"):WaitForChild("MilestoneTree"):WaitForChild("Products"))
local Boards = require(game:GetService("ReplicatedStorage"):WaitForChild("MilestoneTree"):WaitForChild("Boards"))

type Action = Types.Action

export type Modals = {
	frame: Frame,
	act: Signal.Signal<Action>,
	closed: Signal.Signal<>,
	notice: Signal.Signal<string>,
	open: (self: Modals, kind: string?, data: any?) -> (),
	isOpen: (self: Modals) -> string?,
	destroy: (self: Modals) -> (),
}

local Modals = {}

local CRIMSON = Color3.fromHex("ff2e63")
local CYAN = Color3.fromHex("4fd1ff")
local MEDAL = { Color3.fromHex("ffc93c"), Color3.fromHex("d7e0ea"), Color3.fromHex("e39a5b") } -- gold, silver, bronze
local PAGE_KEEP = 30 -- seconds a board page is kept before it is asked for again
local boardNow = "points" -- the board the RANKS window shows (remembered for the session)
local pageCache: { [string]: { t: number, page: any } } = {}
local GOLD = Color3.fromHex("ffc93c")
local LAYER_NAMES = {
	m = "Milestone", mm = "Meta-Milestone", em = "Extra-Milestone", p = "Prestige", pe = "Prestige Energy", sp = "Super Prestige",
	pb = "Prestige Boost", pp = "Prestige Power", se = "Super Energy", hp = "Hyper Prestige", ep = "Exotic Prestige",
	hb = "Hyper Boost", ap = "Atomic Prestige", mp = "Multiverse", t = "Transcend",
} :: { [string]: string }

function Modals.new(root: GuiObject): Modals
	local self = {} :: Modals
	self.act = Signal.new() :: Signal.Signal<Action>
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
	Kit.corner(card, UDim.new(0, 0)) -- Sleek: square
	Kit.grad(card, { Theme.C.panel2, Theme.C.panel }, 90, nil, "Back")
	local rim = Kit.stroke(card, 2, Theme.C.strokeHi, 1, "Rim")
	Kit.list(card, "y", 14, Enum.HorizontalAlignment.Left)
	self.frame = card

	local kind: string? = nil
	local holds: { Recipes.Hold } = {}
	local conns: { RBXScriptConnection } = {}

	local function clear()
		for _, h in holds do h:destroy() end
		table.clear(holds)
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		for _, c in card:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
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
		Kit.corner(box, UDim.new(0, 0)) -- Sleek: square
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

	-- ------------------------------------------------------------------------------------------ shop
	-- the passes and the Time Warps (shared/Products); owned passes come from the player's MT_Perks attribute. A
	-- press opens Roblox's purchase prompt; the server grants it (Shop.luau) and the list redraws.
	local function owned(): { [string]: boolean }
		local out: { [string]: boolean } = {}
		local lp = Players.LocalPlayer
		local raw = if lp then lp:GetAttribute("MT_Perks") else nil
		if type(raw) == "string" then
			local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok and type(list) == "table" then
				for _, k in list do
					if type(k) == "string" then out[k] = true end
				end
			end
		end
		return out
	end
	local function section(title: string)
		local l = Kit.label(card, "Section_" .. title, "caps", Rich.caps(title), GOLD)
		l.LayoutOrder = nextOrder()
		l.Size = UDim2.new(1, 0, 0, 18)
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	local function item(key: string, name: string, blurb: string, price: number, id: number?, icon: number?, have: boolean,
		buy: (id: number) -> ())
		local r = Kit.frame(card, "Item_" .. key)
		r.LayoutOrder = nextOrder()
		-- tall enough for a two-line blurb in Roblox's text (which runs a little taller than the design's)
		r.Size = UDim2.new(1, 0, 0, 86)
		r.BackgroundColor3 = Theme.C.deep
		r.BackgroundTransparency = 0.2
		Kit.stroke(r, 1, Color3.new(1, 1, 1), 0.12, "Hair").LineJoinMode = Enum.LineJoinMode.Miter
		-- the item's icon (the one Roblox shows for the pass / product), text to its right
		local tx = 16
		if icon then
			local im = Instance.new("ImageLabel")
			im.Name = "Icon"
			im.BackgroundTransparency = 1
			im.Image = "rbxassetid://" .. tostring(icon)
			im.Position = UDim2.fromOffset(9, 15)
			im.Size = UDim2.fromOffset(56, 56)
			im.ZIndex = r.ZIndex
			im.Parent = r
			tx = 78
		end
		local nm = Kit.label(r, "Name", "card", name, Color3.new(1, 1, 1))
		nm.Position = UDim2.fromOffset(tx, 12)
		nm.Size = UDim2.new(1, -174 - tx, 0, 24)
		nm.TextXAlignment = Enum.TextXAlignment.Left
		local bl = Kit.label(r, "Blurb", "small", blurb, Theme.C.soft)
		bl.Position = UDim2.fromOffset(tx, 38)
		bl.Size = UDim2.new(1, -174 - tx, 0, 42)
		bl.TextWrapped = true
		bl.TextXAlignment = Enum.TextXAlignment.Left
		bl.TextYAlignment = Enum.TextYAlignment.Top
		if have then
			local c, _ = Kit.chip(r, "Owned", "caps", Rich.caps("Owned"), { h = 30, pad = 12, fg = Theme.C.bought, bgA = 0,
				line = Theme.C.bought, lineA = 0.6 })
			c.AnchorPoint = Vector2.new(1, 0.5)
			c.Position = UDim2.new(1, -16, 0.5, 0)
		elseif id == nil then
			local c, _ = Kit.chip(r, "Soon", "caps", Rich.caps("Soon"), { h = 30, pad = 12, fg = Theme.C.muted, bgA = 0,
				line = Theme.C.muted, lineA = 0.5 })
			c.AnchorPoint = Vector2.new(1, 0.5)
			c.Position = UDim2.new(1, -16, 0.5, 0)
		else
			local b = Kit.action(r, "Buy", "R$ " .. tostring(price), { style = "gold", h = 44, w = 150, role = "cta" })
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -16, 0.5, 0)
			local pid = id :: number
			b.Activated:Connect(function() buy(pid) end)
		end
	end
	local function buildShop()
		rim.Color = GOLD
		head("Shop", "Every purchase supports the game. Thank you!", GOLD, "bag")
		local have = owned()
		local lp = Players.LocalPlayer
		section("Game passes")
		for _, p in Products.passes do
			item(p.key, p.name, p.blurb, p.price, p.id, p.icon, have[p.key] == true, function(id: number)
				pcall(function() MarketplaceService:PromptGamePassPurchase(lp, id) end)
			end)
		end
		section("Time Warp")
		for _, p in Products.products do
			item(p.key, p.name, p.blurb, p.price, p.id, p.icon, false, function(id: number)
				pcall(function() MarketplaceService:PromptProductPurchase(lp, id) end)
			end)
		end
		local row = buttonRow()
		local ok = Kit.action(row, "Close", Rich.caps("Close"), { style = "quiet" })
		ok.Activated:Connect(close)
	end

	-- the leaderboards (shared/Boards, server/Leaderboards): the boards as a tab strip (arrows step through them),
	-- the board's title and the player's own best, the top 50 (rank, avatar, name, value). A page comes from the
	-- Board remote and is kept PAGE_KEEP seconds here; a page that arrives after the window moved on is dropped
	local function buildRanks()
		rim.Color = CYAN
		head("Leaderboards", "Every stat. Each player's best ever, updated every few minutes.", CYAN, "podium")
		local compact = Layout.mode == "COMPACT"
		local tabs = Kit.frame(card, "Tabs")
		tabs.LayoutOrder = nextOrder()
		tabs.Size = UDim2.new(1, 0, 0, 44)
		local prev = Kit.action(tabs, "Prev", "‹", { style = "quiet", h = 36, w = 38, role = "section" })
		prev.Position = UDim2.fromOffset(0, 4)
		local nxt = Kit.action(tabs, "Next", "›", { style = "quiet", h = 36, w = 38, role = "section" })
		nxt.AnchorPoint = Vector2.new(1, 0)
		nxt.Position = UDim2.new(1, 0, 0, 4)
		local strip = Instance.new("ScrollingFrame")
		strip.Name = "Strip"
		strip.BackgroundTransparency = 1
		strip.BorderSizePixel = 0
		strip.Position = UDim2.fromOffset(46, 0)
		strip.Size = UDim2.new(1, -92, 0, 44)
		strip.ScrollingDirection = Enum.ScrollingDirection.X
		strip.ScrollBarThickness = 0
		strip.CanvasSize = UDim2.new()
		strip.AutomaticCanvasSize = Enum.AutomaticSize.X
		strip.ZIndex = card.ZIndex + 1
		strip.Parent = tabs
		Kit.list(strip, "x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
		Kit.pad(strip, 4, 0, 4, 0)
		local tabOf: { [string]: TextButton } = {}
		for i, b in Boards.list do
			local t = Kit.button(strip, "Tab_" .. b.key)
			t.LayoutOrder = i
			t.Size = UDim2.fromOffset(0, 36)
			t.AutomaticSize = Enum.AutomaticSize.X
			t.BackgroundColor3 = Theme.C.deep
			t.BackgroundTransparency = 0.2
			Kit.pad(t, 0, 12, 0, 12)
			Kit.stroke(t, 1, Color3.new(1, 1, 1), 0.85, "Rim").LineJoinMode = Enum.LineJoinMode.Miter
			local l = Kit.label(t, "Label", "caps", Rich.caps(b.title), Theme.C.soft)
			l.AutomaticSize = Enum.AutomaticSize.X
			l.Size = UDim2.fromScale(0, 1)
			l.TextYAlignment = Enum.TextYAlignment.Center
			tabOf[b.key] = t
		end
		-- the board's title and the player's own best
		local info = Kit.frame(card, "Info")
		info.LayoutOrder = nextOrder()
		info.Size = UDim2.new(1, 0, 0, 30)
		local title = Kit.label(info, "Title", "card", "", Color3.new(1, 1, 1))
		title.Size = UDim2.new(0.55, 0, 1, 0)
		title.TextXAlignment = Enum.TextXAlignment.Left
		local you = Kit.label(info, "You", "label", "", CYAN)
		you.AnchorPoint = Vector2.new(1, 0)
		you.Position = UDim2.fromScale(1, 0)
		you.Size = UDim2.new(0.45, 0, 1, 0)
		you.TextXAlignment = Enum.TextXAlignment.Right
		you.RichText = true
		-- the list
		local list = Instance.new("ScrollingFrame")
		list.Name = "Rows"
		list.LayoutOrder = nextOrder()
		list.BackgroundColor3 = Theme.C.deep
		list.BackgroundTransparency = 0.35
		list.BorderSizePixel = 0
		list.Size = UDim2.new(1, 0, 0, if compact then 220 else 400)
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.ScrollingDirection = Enum.ScrollingDirection.Y
		list.ScrollBarThickness = 4
		list.ScrollBarImageColor3 = CYAN
		list.ZIndex = card.ZIndex + 1
		list.Parent = card
		Kit.stroke(list, 1, Color3.new(1, 1, 1), 0.88, "Rim").LineJoinMode = Enum.LineJoinMode.Miter
		Kit.pad(list, 6, 10, 6, 6)
		Kit.list(list, "y", 4, Enum.HorizontalAlignment.Left)
		local status = Kit.label(card, "Status", "body", "", Theme.C.soft)
		status.LayoutOrder = nextOrder()
		status.Size = UDim2.new(1, 0, 0, 0)
		status.AutomaticSize = Enum.AutomaticSize.Y
		status.TextWrapped = true
		status.Visible = false

		local me = if Players.LocalPlayer then Players.LocalPlayer.UserId else 0
		local token = 0
		local function row(e: any)
			local r = Kit.frame(list, "Row_" .. tostring(e.rank))
			r.LayoutOrder = e.rank
			r.Size = UDim2.new(1, 0, 0, 44)
			r.BackgroundColor3 = if e.id == me then Theme.mix(Theme.C.deep, CYAN, 0.18) else Theme.C.panel2
			r.BackgroundTransparency = if e.id == me then 0.1 else 0.45
			local medal = MEDAL[e.rank]
			local rank = Kit.label(r, "Rank", "numberHeavy", "#" .. tostring(e.rank), medal or Theme.C.soft)
			rank.Position = UDim2.fromOffset(8, 0)
			rank.Size = UDim2.fromOffset(52, 44)
			rank.TextXAlignment = Enum.TextXAlignment.Left
			local av = Instance.new("ImageLabel")
			av.Name = "Avatar"
			av.BackgroundColor3 = Theme.C.deep
			av.BackgroundTransparency = 0.2
			av.BorderSizePixel = 0
			av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(e.id) .. "&w=48&h=48"
			av.Position = UDim2.fromOffset(62, 5)
			av.Size = UDim2.fromOffset(34, 34)
			av.ZIndex = r.ZIndex
			av.Parent = r
			if medal then Kit.stroke(av, 2, medal, 0, "Rim") end
			local name = Kit.label(r, "Name", "card", tostring(e.name), Color3.new(1, 1, 1))
			name.Position = UDim2.fromOffset(106, 0)
			name.Size = UDim2.new(0.55, -106, 1, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextTruncate = Enum.TextTruncate.AtEnd
			local value = Kit.label(r, "Value", "numberHeavy", tostring(e.value), medal or Theme.C.text)
			value.AnchorPoint = Vector2.new(1, 0)
			value.Position = UDim2.new(1, -8, 0, 0)
			value.Size = UDim2.new(0.45, -8, 1, 0)
			value.TextXAlignment = Enum.TextXAlignment.Right
		end
		local function show(key: string, page: any)
			for _, c in list:GetChildren() do
				if c:IsA("GuiObject") then c:Destroy() end
			end
			local b = Boards.get(key)
			title.Text = if b then b.title else key
			local mine = if type(page) == "table" then page.you else nil
			you.Text = if mine then Rich.caps("Your best") .. "   <b>" .. tostring(mine) .. "</b>" else ""
			if type(page) ~= "table" then
				status.Text = "Loading…"
				status.Visible = true
				return
			end
			if not page.ok then
				status.Text = tostring(page.error or "Leaderboards are unavailable right now.")
				status.Visible = true
				return
			end
			if #page.entries == 0 then
				status.Text = "Nobody is on this board yet. Play a little and check back in a few minutes."
				status.Visible = true
				return
			end
			status.Visible = false
			for _, e in page.entries do row(e) end
		end
		local function select(key: string)
			boardNow = key
			for k, t in tabOf do
				local on = k == key
				t.BackgroundColor3 = if on then CYAN else Theme.C.deep
				t.BackgroundTransparency = if on then 0.1 else 0.2
				local l = t:FindFirstChild("Label") :: TextLabel?
				if l then l.TextColor3 = if on then Color3.fromHex("06101b") else Theme.C.soft end
			end
			-- the selected tab in view
			local t = tabOf[key]
			if t then
				local x = t.AbsolutePosition.X - strip.AbsolutePosition.X + strip.CanvasPosition.X
				local s = math.max(Layout.s, 0.01)
				strip.CanvasPosition = Vector2.new(math.max(0, x - strip.AbsoluteSize.X / 2 + t.AbsoluteSize.X / 2), 0)
				local _ = s
			end
			token += 1
			local mine = token
			local hit = pageCache[key]
			if hit and os.clock() - hit.t < PAGE_KEEP then
				show(key, hit.page)
				return
			end
			show(key, nil)
			local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("MilestoneTreeRemotes")
			local fn = remotes and remotes:FindFirstChild("Board")
			if fn == nil or not fn:IsA("RemoteFunction") then
				show(key, { ok = false, error = "Leaderboards are not available on this server." })
				return
			end
			task.spawn(function()
				local ok, page = pcall(function() return (fn :: RemoteFunction):InvokeServer(key) end)
				if kind ~= "ranks" or token ~= mine then return end -- the window closed or moved on
				if not ok or type(page) ~= "table" then page = { ok = false, error = "Leaderboards are unavailable right now." } end
				if page.ok then pageCache[key] = { t = os.clock(), page = page } end
				show(key, page)
			end)
		end
		for key, t in tabOf do
			t.Activated:Connect(function() select(key) end)
		end
		local function step(d: number)
			local i = 1
			for j, b in Boards.list do
				if b.key == boardNow then i = j end
			end
			i = (i - 1 + d) % #Boards.list + 1
			select(Boards.list[i].key)
		end
		prev.Activated:Connect(function() step(-1) end)
		nxt.Activated:Connect(function() step(1) end)
		local rowB = buttonRow()
		local ok = Kit.action(rowB, "Close", Rich.caps("Close"), { style = "quiet" })
		ok.Activated:Connect(close)
		select(if Boards.get(boardNow) then boardNow else "points")
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
		if k == "gate" then
			buildGate(data)
		elseif k == "shop" then
			card.Size = UDim2.fromOffset(if compact then 560 else 680, 0)
			buildShop()
		elseif k == "ranks" then
			card.Size = UDim2.fromOffset(if compact then 600 else 720, 0)
			buildRanks()
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
	-- a pass bought while the Shop is open: redraw it (OWNED)
	local lp = Players.LocalPlayer
	if lp then
		lp:GetAttributeChangedSignal("MT_Perks"):Connect(function()
			if kind == "shop" then self:open("shop") end
		end)
	end
	function self.isOpen(_: Modals): string?
		return kind
	end
	function self.destroy(m: Modals)
		clear()
		m.act:DisconnectAll()
		m.closed:DisconnectAll()
		m.notice:DisconnectAll()
		card:Destroy()
		dimmer:Destroy()
	end
	return self
end

return Modals
