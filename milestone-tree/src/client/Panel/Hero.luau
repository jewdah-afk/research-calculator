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
	colour flash only.
]]

local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Layout = require(Core:WaitForChild("Layout"))
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
	Common.list(res, false, if compact then 2 else 4)
	if compact then
		res.Position = UDim2.fromOffset(0, 0)
		res.Size = UDim2.new(1, 0, 0, 0)
	else
		res.Position = UDim2.fromOffset(0, 0)
		res.Size = UDim2.new(1, if pb then -440 else 0, 0, 0)
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
		Recipes.number(amount, { text = amountText, size = steps[1], from = WHITE, mid = Theme.lift(hue, 0.5), to = hue,
			stroke = if compact then 5 else 7, shadow = if compact then 3 else 5, role = "hero" })
		Rich.fit(amount, steps, if compact then 216 else 560)
	end
	-- the round glow blob behind the amount (never a square: Common.blob)
	local blob = if md and not compact then Common.blob(f, "AmountGlow", hue, 0.35) else nil
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
		Recipes.title(resName, { text = name, role = "resource", size = rsize, from = Theme.lift(hue, 0.6), to = Theme.lift(hue, 0.6),
			stroke = if compact then 3 else 4, shadow = 2 })
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
			local text = Common.caps(label, C.soft) .. "   " .. Common.num(if compact then Rich.short(row[2]) else row[2], "number", C.text)
			local chip = Common.chip(stats, "Stat" .. i, text, { rich = true, bg = C.panel2, bgT = 0, h = if compact then 32 else 34 })
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
		stats.Position = UDim2.new(1, 0, 0, if cta then ctaH + 10 else 0)
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
	if can then
		Recipes.bevel(cta, { radius = 16, top = Theme.lift(hue, 0.15), mid = hue, bottom = Theme.shade(hue, 0.55), stroke = 2,
			strokeFrom = Theme.lift(hue, 0.5), strokeTo = hue, sprite = "button" })
		Common.glow(cta, hue, 0.6, 20)
		if self.shine == nil then self.shine = Recipes.shine(cta, { every = 2.8 }) end
	else
		Recipes.bevel(cta, { radius = 16, top = C.panel3, mid = C.panel2, bottom = C.deep, stroke = 2, strokeFrom = C.strokeHi,
			strokeTo = C.stroke, sprite = "button" })
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
	word.AnchorPoint = Vector2.new(0.5, 0)
	word.Position = UDim2.new(0.5, 0, 0, if compact then 10 else 12)
	word.Size = UDim2.new(1, -24, 0, if compact then 24 else 32)
	word.TextXAlignment = Enum.TextXAlignment.Center
	word.TextYAlignment = Enum.TextYAlignment.Center
	word.TextWrapped = false
	local text = Signatures.cta(ctx.layer)
	local sizes = if compact then { 20, 18, 16 } else { 26, 22 }
	local wsig = text .. "|" .. tostring(compact) .. "|" .. tostring(can)
	if word:GetAttribute("Sig") ~= wsig then
		word:SetAttribute("Sig", wsig)
		Recipes.title(word, { text = text, role = "cta", size = sizes[1], stroke = if compact then 4 else 6, shadow = 3 })
		Rich.fit(word, sizes, w - 24)
	end
	-- the value well: +gain, or "need X res" when locked
	local well = Common.get(cta, "Well", "TextLabel") :: TextLabel
	well.ZIndex = 10
	well.AnchorPoint = Vector2.new(0.5, 1)
	well.AutomaticSize = Enum.AutomaticSize.X
	well.TextWrapped = false
	well.TextXAlignment = Enum.TextXAlignment.Center
	well.TextYAlignment = Enum.TextYAlignment.Center
	well.BackgroundColor3 = C.black
	well.BackgroundTransparency = 0.45
	Common.corner(well, 8)
	Common.pad(well, 0, 10, 0, 10)
	local unit = Signatures.unit(pb.res)
	local barShown = pr ~= nil and (static or not can)
	if can then
		Common.text(well, "ctaSub", C.text)
		well.Size = UDim2.fromOffset(0, 26)
		well.Position = UDim2.new(0.5, 0, 1, if barShown then -38 else -12)
		Common.setText(well, Common.num("+" .. (Common.str(pb.gain) or "0"), "ctaSub", C.text, unit, true))
	else
		Common.text(well, "small", C.text)
		well.Size = UDim2.fromOffset(0, 26)
		well.Position = UDim2.new(0.5, 0, 1, -10)
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
		local bar = Common.bar(cta, "Bar", p, if can then WHITE else Theme.lift(hue, 0.2), 6)
		bar.ZIndex = 10
		bar.AnchorPoint = Vector2.new(0, 0)
		bar.Position = UDim2.new(0, 20, 0, if compact then 40 else 52)
		bar.Size = UDim2.new(1, -96, 0, 6)
		local pct = Common.get(cta, "Pct", "TextLabel") :: TextLabel
		pct.ZIndex = 10
		Common.text(pct, "number", C.text)
		pct.AnchorPoint = Vector2.new(1, 0)
		pct.Position = UDim2.new(1, -18, 0, if compact then 33 else 45)
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
		Common.text(key, "label", C.ink)
		key.AnchorPoint = Vector2.new(1, 0)
		key.Position = UDim2.new(1, -10, 0, 10)
		key.AutomaticSize = Enum.AutomaticSize.X
		key.Size = UDim2.fromOffset(0, 26)
		key.BackgroundColor3 = Color3.fromRGB(236, 233, 248)
		key.BackgroundTransparency = 0
		key.TextXAlignment = Enum.TextXAlignment.Center
		key.TextYAlignment = Enum.TextYAlignment.Center
		Common.corner(key, 6)
		Common.pad(key, 0, 7, 0, 7)
		Common.setText(key, Common.esc(hk))
	else
		Common.drop(cta, "Key")
	end
	cta:SetAttribute("State", if can then "can" else "locked")
	if cta:GetAttribute("Wired") ~= true then
		cta:SetAttribute("Wired", true)
		cta.Activated:Connect(function()
			self:press()
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
		local ok, err = pcall(function()
			self:juice(Common.str(pb.gain), Signatures.unit(pb.res))
		end)
		if not ok then warn("[MilestoneTree] prestige juice failed: " .. tostring(err)) end
	end
end

function Hero.juice(self: Hero, gain: string?, unit: string)
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
