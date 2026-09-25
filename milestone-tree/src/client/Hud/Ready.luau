--!strict
--[[
	Ready: the READY tray (desktop) or pill (phones, and the strip beside a side sheet) of DESIGN.md 4.5.

	    Ready      glass tray, gold rim, right edge at W - 170 (left of the portal)
	      Header   bolt + "3 READY" (`toast`, #ffe08a) + "· 4 can buy" (`label`, #ffb3c0) + the gesture hint
	      Gems     Gem_<id>: a 52 du gem (radial hue, symbol), the chip below ("+gain" gold / "BUY" danger rim),
	               96 du pitch, at most 6 + "+N more"; READY gems hold 0.6 s to prestige (a conical ring fills)
	      Banner   while a hold runs: "HOLDING · PRESTIGE <LAYER>  +gain" over "Release to cancel"
	    ReadyPill  up to 3 mini gems + "N READY" over "Tap to list" / "Tap a gem to switch"; a tap opens the tray
	               above it (COMPACT) - in the strip each gem opens its layer

	Entries: every shown node with val.pulse (READY, gain chip), then every node with val.glow (CAN BUY), in the fixed
	map order (MapState.ready / canBuy), so nothing jumps. Hidden when both are empty.

	    local part = Ready.new(parent)
	    part:update(ms)   part:setMode("tray" | "pill" | "strip")   part:setHidden(b)
	    part.tap (layer), part.hold (layer), part.more ()
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Kit = require(script.Parent:WaitForChild("Kit"))

type MapState = Types.MapState

export type Ready = {
	frame: Frame,
	pill: Frame,
	banner: Frame,
	tap: Signal.Signal<string>,
	hold: Signal.Signal<string>,
	more: Signal.Signal<>,
	changed: Signal.Signal<>,
	update: (self: Ready, ms: MapState) -> (),
	setMode: (self: Ready, mode: string) -> (),
	setHidden: (self: Ready, b: boolean) -> (),
	destroy: (self: Ready) -> (),
}

local Ready = {}

local MAX_GEMS = 6
local GOLD = Color3.fromHex("ffc233")
local READY_TEXT = Theme.C.ready
local CANBUY_TEXT = Color3.fromHex("ffb3c0")
local SYMS = {
	ach = "★", m = "M", mm = "MM", em = "EM", p = "P", pe = "PE", sp = "SP", pb = "PB", pp = "PP", se = "SE", hp = "HP",
	ep = "EP", hb = "HB", ap = "AP", mp = "MP", t = "T", pm = "PM", pep = "PEP", cp = "CR", cm = "CM", ex = "EX",
} :: { [string]: string }
local NAMES = {
	m = "Milestone", mm = "Meta", em = "Extra", p = "Prestige", pe = "Energy", sp = "Super", pb = "Boost", pp = "Power",
	se = "Super Energy", hp = "Hyper", ep = "Exotic", hb = "Hyper Boost", ap = "Atomic", mp = "Multiverse", t = "Transcend",
	pm = "Multiverse", pep = "Prestiged Exotic", cp = "Corrupted", cm = "Corrupted Milestone", ex = "Explore", ach = "Achievements",
} :: { [string]: string }

type Entry = { layer: string, ready: boolean, gain: string?, sym: string }

-- a gem: disc + symbol (Sarpanch Heavy) in `size` du
local function gem(parent: Instance, name: string, layer: string, sym: string, size: number): Frame
	local g = Kit.frame(parent, name, 3)
	g.Size = UDim2.fromOffset(size, size)
	Kit.gem(g, Theme.hue(layer))
	Kit.stroke(g, 2, Theme.lift(Theme.hue(layer), 0.5), 0.9, "Rim")
	if sym == "★" then
		local st = Kit.glyph(g, "Star", "star", Color3.new(1, 1, 1))
		st.AnchorPoint = Vector2.new(0.5, 0.5)
		st.Position = UDim2.fromScale(0.5, 0.5)
		st.Size = UDim2.fromScale(0.5, 0.5)
		st.ZIndex = 4
	else
		local l = Kit.label(g, "Symbol", "index", sym, Color3.new(1, 1, 1))
		l.Size = UDim2.fromScale(1, 1)
		l.ZIndex = 4
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextSize = math.max(13, math.floor(size * (if #sym >= 3 then 0.3 elseif #sym == 2 then 0.36 else 0.44)))
		Kit.textStroke(l, if size >= 40 then 2 else 1.5, 1)
	end
	return g
end
Ready.gem = gem

function Ready.new(parent: GuiObject): Ready
	local self = {} :: Ready
	self.tap = Signal.new() :: Signal.Signal<string>
	self.hold = Signal.new() :: Signal.Signal<string>
	self.more = Signal.new() :: Signal.Signal<>
	self.changed = Signal.new() :: Signal.Signal<>

	-- ------------------------------------------------------------------------------------------ the tray
	local tray = Kit.frame(parent, "Ready", 5)
	tray.AnchorPoint = Vector2.new(1, 1)
	tray.AutomaticSize = Enum.AutomaticSize.XY
	tray.BackgroundColor3 = Color3.new(1, 1, 1)
	tray.BackgroundTransparency = 0.06
	tray.Visible = false
	Kit.corner(tray, UDim.new(0, 16))
	Kit.grad(tray, { Color3.fromHex("231b33"), Theme.C.deep }, 90, nil, "Back")
	Kit.stroke(tray, 2, GOLD, 0.75, "Rim")
	Kit.pad(tray, 10, 16, 10, 16)
	Kit.list(tray, "y", 8, Enum.HorizontalAlignment.Left)
	self.frame = tray

	local header = Kit.frame(tray, "Header")
	header.LayoutOrder = 1
	header.AutomaticSize = Enum.AutomaticSize.X
	header.Size = UDim2.fromOffset(0, 22)
	Kit.list(header, "x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local hb = Kit.glyph(header, "Bolt", "bolt", READY_TEXT)
	hb.LayoutOrder = 1
	hb.Size = UDim2.fromOffset(16, 16)
	local count = Kit.label(header, "Count", "toast", "", READY_TEXT)
	count.LayoutOrder = 2
	count.AutomaticSize = Enum.AutomaticSize.X
	count.Size = UDim2.fromScale(0, 1)
	local buy = Kit.label(header, "CanBuy", "label", "", CANBUY_TEXT)
	buy.LayoutOrder = 3
	buy.AutomaticSize = Enum.AutomaticSize.X
	buy.Size = UDim2.fromScale(0, 1)
	local hint = Kit.label(header, "Hint", "small", "Tap to open · hold to prestige", Theme.C.soft)
	hint.LayoutOrder = 4
	hint.AutomaticSize = Enum.AutomaticSize.X
	hint.Size = UDim2.fromScale(0, 1)
	local hinted = true

	local gems = Kit.frame(tray, "Gems")
	gems.LayoutOrder = 2
	gems.AutomaticSize = Enum.AutomaticSize.X
	gems.Size = UDim2.fromOffset(0, 82)
	Kit.list(gems, "x", 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)

	-- the hold banner
	local banner = Kit.frame(parent, "HoldBanner", 6)
	banner.AnchorPoint = Vector2.new(1, 1)
	banner.AutomaticSize = Enum.AutomaticSize.XY
	banner.BackgroundColor3 = Color3.fromHex("2a200a")
	banner.BackgroundTransparency = 0.04
	banner.Visible = false
	Kit.corner(banner, UDim.new(0, 12))
	Kit.stroke(banner, 2, GOLD, 1, "Rim")
	Kit.pad(banner, 8, 16, 9, 16)
	Kit.list(banner, "y", 4, Enum.HorizontalAlignment.Left)
	local bTop = Kit.frame(banner, "Top")
	bTop.LayoutOrder = 1
	bTop.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(bTop, "x", 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local bTitle = Kit.label(bTop, "Title", "toast", "", READY_TEXT)
	bTitle.LayoutOrder = 1
	bTitle.AutomaticSize = Enum.AutomaticSize.XY
	Kit.textStroke(bTitle, 1.5, 0.8)
	local bGain = Kit.label(bTop, "Gain", "number", "", Color3.new(1, 1, 1))
	bGain.LayoutOrder = 2
	bGain.AutomaticSize = Enum.AutomaticSize.XY
	bGain.RichText = true
	local bSub = Kit.label(banner, "Sub", "small", "Release to cancel", Color3.fromHex("ffe9a3"))
	bSub.LayoutOrder = 2
	bSub.AutomaticSize = Enum.AutomaticSize.XY
	self.banner = banner

	-- ------------------------------------------------------------------------------------------ the pill
	local pill = Kit.frame(parent, "ReadyPill", 5)
	pill.AnchorPoint = Vector2.new(1, 1)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.BackgroundTransparency = 0.06
	pill.Visible = false
	Kit.corner(pill)
	Kit.grad(pill, { Color3.fromHex("231b33"), Theme.C.deep }, 90, nil, "Back")
	Kit.stroke(pill, 2, GOLD, 0.75, "Rim")
	local pillRow = Kit.frame(pill, "Row")
	pillRow.AutomaticSize = Enum.AutomaticSize.X
	pillRow.Size = UDim2.fromScale(0, 1)
	Kit.list(pillRow, "x", 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local mini = Kit.frame(pillRow, "Gems")
	mini.LayoutOrder = 1
	mini.AutomaticSize = Enum.AutomaticSize.X
	Kit.list(mini, "x", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local pText = Kit.frame(pillRow, "Text")
	pText.LayoutOrder = 2
	pText.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(pText, "y", 4, Enum.HorizontalAlignment.Left)
	local pCount = Kit.label(pText, "Count", "toast", "", READY_TEXT)
	pCount.LayoutOrder = 1
	pCount.AutomaticSize = Enum.AutomaticSize.XY
	local pSub = Kit.label(pText, "Sub", "small", "Tap to list", Theme.C.soft)
	pSub.LayoutOrder = 2
	pSub.AutomaticSize = Enum.AutomaticSize.XY
	local pillHit = Kit.button(pill, "Hit")
	pillHit.Size = UDim2.fromScale(1, 1)
	pillHit.ZIndex = 2

	-- ------------------------------------------------------------------------------------------ state
	local mode = "tray"
	local hidden = false
	local expanded = false
	local entries: { Entry } = {}
	local sig = ""
	local holds: { [string]: Recipes.Hold } = {}
	local gains: { [string]: string } = {}

	local function clearGems()
		for _, h in holds do h:destroy() end
		table.clear(holds)
		for _, c in gems:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		for _, c in mini:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end

	local function chipFor(slot: Frame, e: Entry)
		local compact = Layout.mode == "COMPACT"
		local h = if compact then 24 else 26
		if e.ready then
			local text = "+" .. Rich.short(e.gain or "1")
			local c, l = Kit.chip(slot, "Chip", "badge", "", { h = h, pad = 8, fg = GOLD, bg = Color3.fromHex("2a200a"), bgA = 1,
				line = GOLD, lineA = 0.8 })
			l.RichText = true
			l.Text = Rich.num(text, { size = Theme.size("badge"), unit = Color3.fromHex("ffe9a3") })
			c.AnchorPoint = Vector2.new(0.5, 0)
			c.Position = UDim2.new(0.5, 0, 0, 56)
		else
			local c = Kit.chip(slot, "Chip", "label", Rich.caps("Buy"), { h = h, pad = 10, fg = Color3.new(1, 1, 1),
				bg = Theme.C.deep, bgA = 1, line = Theme.C.danger, lineA = 1 })
			c.AnchorPoint = Vector2.new(0.5, 0)
			c.Position = UDim2.new(0.5, 0, 0, 56)
		end
	end

	local function buildGems()
		clearGems()
		local shown = math.min(#entries, MAX_GEMS)
		for i = 1, shown do
			local e = entries[i]
			local slot = Kit.frame(gems, "Gem_" .. e.layer)
			slot.LayoutOrder = i
			slot.Size = UDim2.fromOffset(96, 82)
			local g = gem(slot, "Disc", e.layer, e.sym, 52)
			g.AnchorPoint = Vector2.new(0.5, 0)
			g.Position = UDim2.fromScale(0.5, 0)
			chipFor(slot, e)
			local hit = Kit.button(slot, "Hit")
			hit.AnchorPoint = Vector2.new(0.5, 0)
			hit.Position = UDim2.fromScale(0.5, 0)
			hit.Size = UDim2.fromOffset(62, 62)
			hit.ZIndex = 6
			local layer = e.layer
			if e.ready then
				local h = Recipes.hold(hit, { dur = 0.6, ring = true, color = GOLD, onDone = function()
					if hinted then
						hinted = false
						hint.Visible = false
					end
					self.hold:Fire(layer)
				end })
				local ring = hit:FindFirstChild("Ring") :: Frame?
				if ring then ring.Size = UDim2.fromOffset(62, 62) end
				holds[layer] = h
			end
			hit.Activated:Connect(function()
				local h = holds[layer]
				if h and h:consumed() then return end
				self.tap:Fire(layer)
			end)
		end
		if #entries > MAX_GEMS then
			local slot = Kit.frame(gems, "More")
			slot.LayoutOrder = 100
			slot.Size = UDim2.fromOffset(96, 82)
			local c, _ = Kit.chip(slot, "Chip", "label", "+" .. (#entries - MAX_GEMS) .. " more", { h = 28, pad = 10,
				fg = Theme.C.soft, bg = Theme.C.panel3, bgA = 1, line = Theme.C.strokeHi, lineA = 1 })
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromOffset(48, 26)
			local hit = Kit.button(slot, "Hit")
			hit.Size = UDim2.fromScale(1, 1)
			hit.Activated:Connect(function() self.more:Fire() end)
		end
		-- the pill's mini gems
		local compact = Layout.mode == "COMPACT"
		local ms = if compact then 30 else 34
		for i = 1, math.min(3, #entries) do
			local e = entries[i]
			local g = gem(mini, "Mini_" .. e.layer, e.layer, e.sym, ms)
			g.LayoutOrder = i
			local hit = Kit.button(g, "Hit")
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 6
			hit.Visible = mode == "strip"
			local layer = e.layer
			hit.Activated:Connect(function() self.tap:Fire(layer) end)
		end
	end

	local function layout()
		local compact = Layout.mode == "COMPACT"
		local nReady, nBuy = 0, 0
		for _, e in entries do
			if e.ready then nReady += 1 else nBuy += 1 end
		end
		local any = #entries > 0
		local usePill = mode == "strip" or (mode == "pill" and not expanded)
		tray.Visible = any and not hidden and not usePill
		pill.Visible = any and not hidden and usePill
		-- positions
		local right = if mode == "tray" then -170 else -14
		local bottom = if compact then -6 else -8
		tray.Position = UDim2.new(1, if mode == "pill" then -14 else right, 1, if mode == "pill" then bottom - 64 else bottom)
		pill.Position = UDim2.new(1, if mode == "strip" then -14 else (if compact then -110 else -170), 1, bottom)
		pill.Size = UDim2.fromOffset(0, if compact then 50 else 56)
		Kit.pad(pill, 0, 14, 0, 8)
		banner.Position = UDim2.new(1, if mode == "tray" then -170 else -14, 1, bottom - 150)
		-- texts
		count.Text = if nReady > 0 then Rich.caps(nReady .. " ready") else Rich.caps(nBuy .. " can buy")
		buy.Text = if nReady > 0 and nBuy > 0 then "· " .. nBuy .. " can buy" else ""
		buy.Visible = nReady > 0 and nBuy > 0
		hint.Visible = hinted and nReady > 0 and not compact
		Theme.text(count, "toast")
		Theme.text(pCount, "toast")
		pCount.Text = if nReady > 0 then Rich.caps(nReady .. " ready") else Rich.caps(nBuy .. " can buy")
		pSub.Text = if mode == "strip" then "Tap a gem to switch" else "Tap to list"
		self.changed:Fire()
	end

	-- the banner follows any running hold
	Motion.loop(tray, function()
		local holding: string? = nil
		for layer, h in holds do
			if h.holding then holding = layer end
		end
		local on = holding ~= nil
		if on and holding then
			local name = NAMES[holding] or string.upper(holding)
			bTitle.Text = Rich.caps("Holding") .. " · " .. string.upper("Prestige " .. name)
			local g = gains[holding]
			bGain.Text = if g then Rich.num("+" .. g, { size = Theme.size("number"), unit = Color3.fromHex("ffe9a3") }) else ""
		end
		if banner.Visible ~= on then banner.Visible = on end
	end)

	pillHit.Activated:Connect(function()
		if mode == "pill" then
			expanded = true
			layout()
			task.delay(6, function()
				if expanded then
					expanded = false
					layout()
				end
			end)
		end
	end)

	function self.update(_: Ready, ms: MapState)
		local list: { Entry } = {}
		for _, l in ms.ready do
			local n = ms.nodes[l]
			local v = n and n.val
			table.insert(list, { layer = l, ready = true, gain = if v then v.gain else nil, sym = (n and n.sym) or SYMS[l] or l })
			if v and v.gain then gains[l] = v.gain else gains[l] = nil end
		end
		for _, l in ms.canBuy do
			local n = ms.nodes[l]
			table.insert(list, { layer = l, ready = false, gain = nil, sym = (n and n.sym) or SYMS[l] or l })
		end
		local parts = {}
		for _, e in list do table.insert(parts, e.layer .. (if e.ready then "!" else "?") .. (e.gain or "")) end
		local nsig = table.concat(parts, ",") .. "|" .. mode .. "|" .. Layout.mode
		entries = list
		if nsig ~= sig then
			-- the gain text alone changed: rewrite the chips, keep the gems (and any running hold)
			local sameSet = true
			local a = string.gsub(sig, "!([^,|]*)", "!")
			local b = string.gsub(nsig, "!([^,|]*)", "!")
			if a ~= b then sameSet = false end
			sig = nsig
			if sameSet then
				for _, e in list do
					local slot = gems:FindFirstChild("Gem_" .. e.layer) :: Frame?
					if slot and e.ready then chipFor(slot, e) end
				end
			else
				buildGems()
			end
		end
		layout()
	end
	function self.setMode(_: Ready, m: string)
		if m == mode then return end
		mode = m
		expanded = false
		sig = ""
		buildGems()
		layout()
	end
	function self.setHidden(_: Ready, b: boolean)
		if b == hidden then return end
		hidden = b
		layout()
	end
	function self.destroy(r: Ready)
		clearGems()
		for _, s in { r.more, r.changed } do s:DisconnectAll() end
		r.tap:DisconnectAll()
		r.hold:DisconnectAll()
		tray:Destroy()
		pill:Destroy()
		banner:Destroy()
	end
	Layout.changed:Connect(function()
		sig = ""
		buildGems()
		layout()
	end)
	return self
end

return Ready
