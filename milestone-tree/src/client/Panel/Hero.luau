--!strict
--[[
	Hero: the pinned hero of a panel (DESIGN.md 5.3, 5.4, 5.10; plan 2.5). It claims the first main-display,
	prestige-button and resource-display of the current tab (depth <= 3) and draws them from their structured fields:

	    resource block   YOU HAVE, the amount (hero: Sarpanch Heavy with gradient, outline, shadow and a round glow blob;
	                     steps 56 -> 48 -> 40 to fit), the resource name (resource: heavy italic caps), the effect line
	    CTA              the signature's word (PRESTIGE / GET +1 MILESTONE / COLLECT ...), the gain in a value well; static
	                     layers with a pr show the bar and %; the locked variant is grey with the bar, % and
	                     "need X <resource>"; the hotkey keycap only with keyboard and mouse
	    stat chips       resource-display lines: <RESOURCE> have, PASSIVE +gen/s, BEST, TOTAL
	WIDE: the block at the left, the CTA at the right, chips under the CTA. COMPACT: one 226 du column with the chips
	stacked and the CTA pinned at the bottom.

	The CTA fires the prestige-button node's own action (read from the store at press time) and plays the prestige
	juice: press squash, burst ring, a "+gain" floater into the amount, the amount bump. Reduced motion keeps a short
	colour flash only. The press asks the one "first prestige?" question (Prefs.claimFirstPrestige) and hands the
	answer to the sound (Audio.prestige: big or small) and to juice(gain, unit, first), where the VFX pass keys its big
	and residual versions. A locked CTA answers with the soft error; hovering a ready CTA plays the hover tick.
]]

local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Sleek = require(Core:WaitForChild("Sleek"))
local Layout = require(Core:WaitForChild("Layout"))
local Prefs = require(Core:WaitForChild("Prefs"))
local Audio = require(Core:WaitForChild("Audio"))
local Common = require(script.Parent:WaitForChild("Skins"):WaitForChild("Common"))
local Signatures = require(script.Parent.Parent:WaitForChild("Signatures"):WaitForChild("Signatures"))

local Hero = {}
Hero.__index = Hero

local C = Theme.C
local WHITE = Color3.new(1, 1, 1)

local CN = { ["main-display"] = true, ["prestige-button"] = true, ["resource-display"] = true }

export type Hero = typeof(setmetatable({} :: {
	frame: Frame,
	ids: { [string]: string },
	dirty: boolean,
	visible: boolean,
	store: any,
	ctx: any,
	act: (action: any, hold: boolean?) -> (),
	shine: any?,
	lastGain: string?,
}, Hero))

function Hero.new(frame: Frame, act: (action: any, hold: boolean?) -> ()): Hero
	local self = setmetatable({
		frame = frame,
		ids = {},
		dirty = false,
		visible = false,
		store = nil,
		ctx = nil,
		act = act,
		shine = nil,
		lastGain = nil,
	}, Hero)
	frame.Visible = false
	return self
end

-- forget the claimed ids (a new panel opened, or a full patch)
function Hero.reset(self: Hero)
	table.clear(self.ids)
	self.dirty = true
end

-- the claim hook's question: is this the hero's component?
function Hero.wants(self: Hero, id: string, n: any): boolean
	if type(n) ~= "table" or not CN[n.cn or ""] then return false end
	if Common.depth(id) > 3 then return false end
	local cn = n.cn :: string
	-- a resource-display with no structured value (the game's empty "<br><br>") stays in the body (hidden there)
	if cn == "resource-display" and n.have == nil and n.gen == nil and n.best == nil and n.total == nil then return false end
	local held = self.ids[cn]
	return held == nil or held == id
end

function Hero.claim(self: Hero, id: string, n: any): (ph: Frame) -> any
	local cn = n.cn :: string
	return function(ph: Frame): any
		ph.Visible = false
		ph.Size = UDim2.new()
		ph.AutomaticSize = Enum.AutomaticSize.None
		self.ids[cn] = id
		self.dirty = true
		local claim = {}
		function claim.update(_: any, store: any)
			self.store = store
			self.dirty = true
		end
		function claim.destroy(_: any)
			if self.ids[cn] == id then self.ids[cn] = nil end
			self.dirty = true
		end
		return claim
	end
end

-- ------------------------------------------------------------------------------------------------------ drawing
local function keyboard(): boolean
	local ok, kbm = pcall(function(): boolean
		return (UserInputService :: any).PreferredInput == (Enum :: any).PreferredInput.KeyboardAndMouse
	end)
	if ok then return kbm end
	return UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
end

local function gainZero(s: string?): boolean
	return s == nil or string.find(s, "^[%+]?0[%.0]*$") ~= nil
end

function Hero.draw(self: Hero, store: any, ctx: any)
	self.dirty = false
	self.store = store
	self.ctx = ctx
	local f = self.frame
	local md = if self.ids["main-display"] then store:get(self.ids["main-display"]) else nil
	local pb = if self.ids["prestige-button"] then store:get(self.ids["prestige-button"]) else nil
	local rd = if self.ids["resource-display"] then store:get(self.ids["resource-display"]) else nil
	if type(md) ~= "table" then md = nil end
	if type(pb) ~= "table" then pb = nil end
	if type(rd) ~= "table" then rd = nil end
	self.visible = md ~= nil or pb ~= nil or rd ~= nil
	f.Visible = self.visible
	if not self.visible then return end
	local compact = Layout.mode == "COMPACT"
	local hue = ctx.hue :: Color3
	f.ClipsDescendants = false

	-- the resource block
	local res = Common.get(f, "Res", "Frame") :: Frame
	res.Active = false
	Common.list(res, false, if compact then 2 else 6)
	if compact then
		res.Position = UDim2.fromOffset(0, 0)
		res.Size = UDim2.new(1, 0, 0, 0)
		Common.drop(f, "Spine")
	else
		res.Position = UDim2.fromOffset(20, 0)
		res.Size = UDim2.new(1, if pb then -460 else -20, 0, 0)
		local spine = Common.get(f, "Spine", "Frame") :: Frame
		spine.Position = UDim2.fromOffset(0, 4)
		spine.Size = UDim2.fromOffset(2, 112)
		spine.BackgroundColor3 = hue
		spine.BackgroundTransparency = 0
		spine.Visible = md ~= nil
		local sg = Common.get(spine, "Fade", "UIGradient") :: UIGradient
		sg.Rotation = 90
		sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9) })
	end
	res.AutomaticSize = Enum.AutomaticSize.Y
	res.Visible = md ~= nil or (compact and rd ~= nil)
	local you = Common.label(res, "YouHave", "caps", C.soft, { order = 1, wrap = false })
	you.Visible = md ~= nil
	Common.setText(you, Common.esc(Rich.caps("You have")))
	local amountText = if md then Common.str(md.pts) or "0" else "0"
	local amount = Common.get(res, "Amount", "TextLabel") :: TextLabel
	amount.LayoutOrder = 2
	amount.Visible = md ~= nil
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.TextYAlignment = Enum.TextYAlignment.Center
	amount.TextWrapped = false
	amount.AutomaticSize = Enum.AutomaticSize.None
	local steps = if compact then { 38, 34, 30 } else { 56, 48, 40 }
	amount.Size = UDim2.new(1, 0, 0, steps[1] + 8)
	local sig = amountText .. "|" .. Theme.toHex(hue) .. "|" .. tostring(compact)
	if amount:GetAttribute("Sig") ~= sig then
		amount:SetAttribute("Sig", sig)
		Recipes.number(amount, { text = amountText, size = steps[1], from = WHITE, to = WHITE, stroke = 0, shadow = 0, role = "hero" })
		Rich.fit(amount, steps, if compact then 216 else 560)
	end
	-- the round glow blob behind the amount (never a square: Common.blob)
	local blob = if md and not compact then Common.blob(f, "AmountGlow", hue, 0.16) else nil
	if blob then
		blob.ZIndex = 0
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.fromOffset(200, 58)
		blob.Size = UDim2.fromOffset(470, 150)
	elseif not (md and not compact) then
		Common.drop(f, "AmountGlow")
	end
	local resName = Common.get(res, "ResName", "TextLabel") :: TextLabel
	resName.LayoutOrder = 3
	resName.Visible = md ~= nil
	resName.TextXAlignment = Enum.TextXAlignment.Left
	resName.TextYAlignment = Enum.TextYAlignment.Center
	resName.TextWrapped = false
	resName.AutomaticSize = Enum.AutomaticSize.None
	local name = string.upper(Common.plain(if md then md.res else ""))
	name = string.gsub(string.gsub(name, "^%s+", ""), "%s+$", "")
	local long = utf8.len(name) ~= nil and (utf8.len(name) :: number) > 20
	local rsize = if compact then (if long then 16 else 18) else (if long then 18 else 22)
	resName.Size = UDim2.new(1, 0, 0, rsize + 6)
	local rsig = name .. "|" .. tostring(rsize) .. "|" .. Theme.toHex(hue)
	if resName:GetAttribute("Sig") ~= rsig then
		resName:SetAttribute("Sig", rsig)
		Recipes.title(resName, { text = name, role = "resource", size = if compact then rsize - 2 else rsize - 2, from = Theme.lift(hue, 0.55),
			to = Theme.lift(hue, 0.55), stroke = 0, shadow = 0 })
	end
	local eff = Common.label(res, "Eff", "body", C.soft, { order = 4 })
	local effText = if md and not compact then Common.html(md.eff, "body", ctx.layer) else ""
	eff.Visible = effText ~= ""
	eff.TextTruncate = Enum.TextTruncate.AtEnd
	local effLim = Common.get(eff, "Lines", "UISizeConstraint") :: UISizeConstraint
	effLim.MaxSize = Vector2.new(math.huge, math.floor(Theme.size("body") * Theme.lineHeight("body") * 2 + 2))
	Common.setText(eff, effText)

	-- the stat chips
	local stats = Common.get(f, "Stats", "Frame") :: Frame
	stats.Active = false
	local rows: { { string } } = {}
	if rd then
		local have, bres = Common.str(rd.have), Common.str(rd.bres)
		if have then table.insert(rows, { string.upper(Common.plain(bres or "")), have }) end
		local gen = Common.str(rd.gen)
		if gen and not gainZero(gen) then table.insert(rows, { "PASSIVE", "+" .. gen .. "/s" }) end
		local best = Common.str(rd.best)
		if best then table.insert(rows, { "BEST", best }) end
		local total = Common.str(rd.total)
		if total then table.insert(rows, { "TOTAL", total }) end
	end
	if compact then
		stats.Parent = res
		stats.LayoutOrder = 10
		stats.Position = UDim2.new()
		stats.AnchorPoint = Vector2.new()
		stats.Size = UDim2.new(1, 0, 0, 0)
		stats.AutomaticSize = Enum.AutomaticSize.Y
		Common.list(stats, false, 6)
	else
		stats.Parent = f
		stats.AnchorPoint = Vector2.new(1, 0)
		stats.Size = UDim2.fromOffset(0, 34)
		stats.AutomaticSize = Enum.AutomaticSize.X
		Common.list(stats, true, 8, { align = Enum.HorizontalAlignment.Right, valign = Enum.VerticalAlignment.Center })
	end
	stats.Visible = #rows > 0
	for i = 1, 4 do
		local row = rows[i]
		if row then
			local label = if row[1] ~= "" then row[1] else "HAVE"
			local tone = if label == "PASSIVE" then Sleek.C.goodHi else C.text
			local text = Common.caps(label, Sleek.C.soft) .. "      " .. Common.num(if compact then Rich.short(row[2]) else row[2], "number", tone)
			local chip = Common.chip(stats, "Stat" .. i, text, { rich = true, bg = WHITE, bgT = 0.97, h = if compact then 32 else 34,
				stroke = WHITE })
			Common.drop(chip, "Corner")
			local b = chip:FindFirstChild("Border") :: UIStroke?
			if b then
				b.Transparency = 0.89
				b.LineJoinMode = Enum.LineJoinMode.Miter
			end
			chip.LayoutOrder = i
			chip.TextXAlignment = if compact then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
			if compact then
				chip.AutomaticSize = Enum.AutomaticSize.None
				chip.Size = UDim2.new(1, 0, 0, 32)
			end
		else
			Common.drop(stats, "Stat" .. i)
		end
	end

	-- the CTA
	if pb then
		self:drawCta(pb, ctx, compact)
	else
		Common.drop(f, "Cta")
		if self.shine then
			self.shine:stop()
			self.shine = nil
		end
	end
	local cta = f:FindFirstChild("Cta") :: GuiObject?
	if not compact then
		local ctaH = if cta then cta.Size.Y.Offset else 0
		stats.Position = UDim2.new(1, 0, 0, if cta then ctaH + 14 else 0)
	end

	-- the signature's hero idea
	local sigT = ctx.signature
	if sigT and sigT.hero then
		local ok, err = pcall(sigT.hero, f, store, ctx)
		if not ok then warn("[MilestoneTree] signature hero failed: " .. tostring(err)) end
	else
		-- a signature's hero idea lives in the hero's "Accent" child: gone on a layer without one
		Common.drop(f, "Accent")
	end
end

function Hero.drawCta(self: Hero, pb: any, ctx: any, compact: boolean)
	local f = self.frame
	local hue = ctx.hue :: Color3
	local can = pb.cls == "can"
	local static = pb.static == true
	local pr = Common.pr(pb.pr)
	local tall = (not can) or (static and pr ~= nil)
	local w = if compact then 200 else 400
	local h = if compact then (if tall then 96 else 80) else (if tall then 110 else 96)
	local cta = Common.get(f, "Cta", "TextButton") :: TextButton
	cta.Text = ""
	cta.AutoButtonColor = false
	cta.ClipsDescendants = false
	if compact then
		cta.AnchorPoint = Vector2.new(0.5, 1)
		cta.Position = UDim2.new(0.5, 0, 1, 0)
	else
		cta.AnchorPoint = Vector2.new(1, 0)
		cta.Position = UDim2.new(1, 0, 0, 0)
	end
	cta.Size = UDim2.fromOffset(w, h)
	-- Sleek: the one solid light surface of the panel (ink type), corner ticks just outside; locked is a dark plate
	for _, n in { "Corner", "Rim", "Bevel" } do Common.drop(cta, n) end
	local ink = Sleek.C.ink
	if can then
		cta.BackgroundColor3 = WHITE
		cta.BackgroundTransparency = 0
		local g = Common.get(cta, "Fill", "UIGradient") :: UIGradient
		g.Rotation = 90
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.lift(hue, 0.3)), ColorSequenceKeypoint.new(0.6, hue),
			ColorSequenceKeypoint.new(1, Theme.shade(hue, 0.92)) })
		g.Transparency = NumberSequence.new(0)
		local edge = Common.get(cta, "Edge", "Frame") :: Frame
		edge.Size = UDim2.new(1, 0, 0, 1)
		edge.BackgroundColor3 = WHITE
		edge.BackgroundTransparency = 0.3
		edge.ZIndex = 9
		Sleek.ticks(cta, { len = 12, th = 2, out = 6, color = Theme.lift(hue, 0.55), alpha = 1, z = 9 })
		Common.glow(cta, hue, 0.3, 26)
		if self.shine == nil then self.shine = Recipes.shine(cta, { every = 2.8 }) end
	else
		Sleek.plate(cta, { alpha = 0.9, line = 0.8 })
		Common.drop(cta, "Edge")
		Sleek.ticks(cta, { len = 10, th = 2, out = 6, color = WHITE, alpha = 0.35, z = 9 })
		Common.glow(cta, nil)
		if self.shine then
			self.shine:stop()
			self.shine = nil
		end
		Common.drop(cta, "Shine")
	end
	-- the word (display: white, outline, hard shadow), step-fit to keep 12 du side padding
	local word = Common.get(cta, "Word", "TextLabel") :: TextLabel
	word.ZIndex = 10
	word.AnchorPoint = Vector2.new(0, 0)
	word.Position = UDim2.new(0, if compact then 14 else 28, 0, if compact then 10 else 18)
	word.Size = UDim2.new(1, if compact then -28 else -120, 0, if compact then 24 else 32)
	word.TextXAlignment = Enum.TextXAlignment.Left
	word.TextYAlignment = Enum.TextYAlignment.Center
	word.TextWrapped = false
	local text = Signatures.cta(ctx.layer)
	local sizes = if compact then { 20, 18, 16 } else { 30, 26, 22 }
	local wsig = text .. "|" .. tostring(compact) .. "|" .. tostring(can) .. "|" .. Theme.toHex(hue)
	if word:GetAttribute("Sig") ~= wsig then
		word:SetAttribute("Sig", wsig)
		Recipes.title(word, { text = text, role = "cta", size = sizes[1], stroke = 0, shadow = 0 })
		Rich.fit(word, sizes, w - (if compact then 28 else 120))
	end
	local fillText = word:FindFirstChild("Fill") :: TextLabel?
	if fillText then fillText.TextColor3 = if can then ink else Sleek.C.soft end
	-- the value line: +gain in ink under the word, or "need X res" when locked
	local well = Common.get(cta, "Well", "TextLabel") :: TextLabel
	well.ZIndex = 10
	well.AnchorPoint = Vector2.new(0, 1)
	well.AutomaticSize = Enum.AutomaticSize.X
	well.TextWrapped = false
	well.TextXAlignment = Enum.TextXAlignment.Left
	well.TextYAlignment = Enum.TextYAlignment.Center
	well.BackgroundTransparency = 1
	Common.drop(well, "Corner")
	Common.pad(well, 0, 0, 0, 0)
	local unit = Signatures.unit(pb.res)
	local barShown = pr ~= nil and (static or not can)
	if can then
		Common.text(well, "ctaSub", ink)
		well.Size = UDim2.fromOffset(0, 22)
		well.Position = UDim2.new(0, if compact then 14 else 28, 1, if barShown then -34 else -16)
		Common.setText(well, Common.num("+" .. (Common.str(pb.gain) or "0"), "ctaSub", ink, unit, true))
	else
		Common.text(well, "small", Sleek.C.soft)
		well.Size = UDim2.fromOffset(0, 22)
		well.Position = UDim2.new(0, if compact then 14 else 28, 1, -12)
		local need = Common.str(pb.next)
		local bres = Common.plain(Common.str(pb.bres) or "")
		if need then
			Common.setText(well, Common.esc("need ") .. Common.num(if compact then Rich.short(need) else need, "number", C.text, bres, true))
		else
			Common.setText(well, Common.esc("Not ready"))
		end
	end
	-- the pr bar + %
	if barShown then
		local p = pr :: number
		local bar = Common.bar(cta, "Bar", p, if can then ink else hue, 2)
		bar.ZIndex = 10
		bar.AnchorPoint = Vector2.new(0, 0)
		bar.Position = UDim2.new(0, if compact then 14 else 28, 0, if compact then 42 else 58)
		bar.Size = UDim2.new(1, if compact then -84 else -112, 0, 2)
		local pct = Common.get(cta, "Pct", "TextLabel") :: TextLabel
		pct.ZIndex = 10
		Common.text(pct, "number", if can then ink else C.text)
		pct.AnchorPoint = Vector2.new(1, 0)
		pct.Position = UDim2.new(1, if compact then -14 else -28, 0, if compact then 33 else 49)
		pct.Size = UDim2.fromOffset(60, 20)
		pct.TextXAlignment = Enum.TextXAlignment.Right
		pct.TextYAlignment = Enum.TextYAlignment.Center
		Common.setText(pct, Common.esc(Rich.pct(p)))
	else
		Common.drop(cta, "Bar")
		Common.drop(cta, "Pct")
	end
	-- the hotkey keycap (keyboard and mouse only)
	local hk = Common.str(pb.hk)
	if hk and keyboard() then
		local key = Common.get(cta, "Key", "TextLabel") :: TextLabel
		key.ZIndex = 11
		Common.text(key, "label", if can then ink else C.text)
		key.AnchorPoint = Vector2.new(1, 0.5)
		key.Position = UDim2.new(1, -52, 0.5, if barShown then -14 else 0)
		key.AutomaticSize = Enum.AutomaticSize.X
		key.Size = UDim2.fromOffset(30, 30)
		key.BackgroundTransparency = 1
		key.TextXAlignment = Enum.TextXAlignment.Center
		key.TextYAlignment = Enum.TextYAlignment.Center
		Common.drop(key, "Corner")
		Common.stroke(key, 1.5, if can then ink else WHITE, if can then 0 else 0.6).LineJoinMode = Enum.LineJoinMode.Miter
		Common.pad(key, 0, 8, 0, 8)
		local chev = Common.get(cta, "Chev", "Frame") :: Frame
		chev.AnchorPoint = Vector2.new(0.5, 0.5)
		chev.Position = UDim2.new(1, -30, 0.5, if barShown then -14 else 0)
		chev.Size = UDim2.fromOffset(9, 9)
		chev.Rotation = 45
		chev.ZIndex = 11
		for i, spec in { { UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 2) }, { UDim2.new(1, -2, 0, 0), UDim2.new(0, 2, 1, 0) } } do
			local seg = Common.get(chev, "S" .. i, "Frame") :: Frame
			seg.Position = spec[1]
			seg.Size = spec[2]
			seg.BackgroundColor3 = if can then ink else WHITE
			seg.BackgroundTransparency = if can then 0 else 0.4
			seg.ZIndex = 11
		end
		Common.setText(key, Common.esc(hk))
	else
		Common.drop(cta, "Key")
		Common.drop(cta, "Chev")
	end
	cta:SetAttribute("State", if can then "can" else "locked")
	if cta:GetAttribute("Wired") ~= true then
		cta:SetAttribute("Wired", true)
		cta.Activated:Connect(function()
			self:press()
		end)
		cta.MouseEnter:Connect(function()
			if cta:GetAttribute("State") == "can" then Audio.play("hover") end
		end)
	end
end

-- ------------------------------------------------------------------------------------------------------ press + juice
function Hero.press(self: Hero)
	local store = self.store
	local id = self.ids["prestige-button"]
	if store == nil or id == nil then return end
	local pb = store:get(id)
	if type(pb) ~= "table" or type(pb.a) ~= "table" then return end
	self.act(pb.a, false)
	if pb.cls == "can" then
		local layer = if self.ctx then self.ctx.layer else nil
		local first = type(layer) == "string" and Prefs.claimFirstPrestige(layer)
		Audio.prestige(layer, first)
		local ok, err = pcall(function()
			self:juice(Common.str(pb.gain), Signatures.unit(pb.res), first)
		end)
		if not ok then warn("[MilestoneTree] prestige juice failed: " .. tostring(err)) end
	else
		Audio.play("error", { volume = 0.8 })
	end
end

-- first: this is the layer's first prestige (the big moment; the VFX pass plays its big version on it)
function Hero.juice(self: Hero, gain: string?, unit: string, first: boolean?)
	local f = self.frame
	local cta = f:FindFirstChild("Cta") :: GuiObject?
	if cta == nil then return end
	local ctaObj = cta :: GuiObject
	if Motion.reduced() then
		Motion.flash(ctaObj)
		return
	end
	-- 1. press squash, then Back Out
	local sc = Motion.scaleOf(ctaObj)
	sc.Scale = 0.94
	Motion.tween(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }, "hero:cta")
	local s = math.max(Layout.s, 0.01)
	local origin = f.AbsolutePosition
	local cc = (ctaObj.AbsolutePosition - origin + ctaObj.AbsoluteSize / 2) / s
	-- 2. a burst ring
	local ring = Instance.new("Frame")
	ring.Name = "Burst"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(cc.X, cc.Y)
	ring.Size = UDim2.fromOffset(120, 120)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 20
	ring.Active = false
	Common.corner(ring, 0.5)
	local rs = Common.stroke(ring, 4, C.gold, 0.4)
	ring.Parent = f
	Motion.tween(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(360, 360) })
	Motion.tween(rs, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 })
	task.delay(0.5, function()
		if ring.Parent then ring:Destroy() end
	end)
	-- 3. the "+gain" floater into the amount
	local resF = f:FindFirstChild("Res")
	local amount: GuiObject? = if resF then resF:FindFirstChild("Amount") :: GuiObject? else nil
	if gain and amount and (amount :: GuiObject).Visible then
		local a = amount :: GuiObject
		local target = (a.AbsolutePosition - origin) / s + Vector2.new(60, a.AbsoluteSize.Y / (2 * s))
		local fl = Instance.new("TextLabel")
		fl.Name = "Floater"
		fl.BackgroundTransparency = 1
		fl.AnchorPoint = Vector2.new(0.5, 0.5)
		fl.Position = UDim2.fromOffset(cc.X, cc.Y)
		fl.Size = UDim2.fromOffset(320, 36)
		fl.ZIndex = 21
		fl.RichText = true
		fl.FontFace = Theme.font("hero")
		fl.TextSize = 28
		fl.TextColor3 = C.gold
		fl.TextStrokeTransparency = 1
		local st = Common.stroke(fl, 3, C.black, 0, "Stroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		fl.Text = Rich.num("+" .. gain .. (if unit ~= "" then " " .. unit else ""), { size = 28, onFill = true })
		fl.Parent = f
		Motion.tween(fl, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(target.X, target.Y) })
		task.delay(0.45, function()
			if fl.Parent then
				Motion.tween(fl, TweenInfo.new(0.2), { TextTransparency = 1 })
				Motion.tween(st, TweenInfo.new(0.2), { Transparency = 1 })
			end
		end)
		task.delay(0.7, function()
			if fl.Parent then fl:Destroy() end
		end)
		-- 4. the amount bumps and its glow flares
		task.delay(0.5, function()
			if a.Parent then Motion.bump(a, 0.12) end
			local blob = f:FindFirstChild("AmountGlow") :: Frame?
			if blob then
				local g = blob:FindFirstChild("Radial")
				blob.BackgroundTransparency = 0
				if g and g:IsA("UIGradient") then
					local sc2 = Motion.scaleOf(blob)
					sc2.Scale = 1.15
					Motion.tween(sc2, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
				end
			end
		end)
	end
end

function Hero.destroy(self: Hero)
	if self.shine then
		self.shine:stop()
		self.shine = nil
	end
	table.clear(self.ids)
end

return Hero
