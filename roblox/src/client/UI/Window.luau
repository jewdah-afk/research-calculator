--!nonstrict
-- Window: one Peckwood v2 window (Figma "Shop v2 / *", template 49:10).
-- The static art (body, header, tabs bar, hero card + art, row cards, progress tracks, rim glow) is the Figma frame itself,
-- rendered with its live layers hidden (shared/FigmaArt). Live layers are drawn on top at the Figma layer coordinates:
-- titles, icons, growth values, progress fills, buttons (Figma-rendered faces + live label), sparkles, footer.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Kit = require(script.Parent.Kit)
local Art = require(RS:WaitForChild("Peckwood"):WaitForChild("FigmaArt"))
local ArtSize = require(RS:WaitForChild("Peckwood"):WaitForChild("FigmaArtSize"))
local hex, frame, text = Kit.hex, Kit.frame, Kit.text

local Window = {}
local live = {}
local reduced = false   -- reduced-motion setting, polled
task.spawn(function() while true do reduced = Kit.reduced(); task.wait(2) end end)

local W = 500
local ROW_H, ROW_PITCH = 116, 126
local MARGIN = 150   -- rim-glow margin baked around each window render (1x px)

local function btnArt(id, kind)
	if kind == "buy" then return { lit = Art["btn/" .. id .. "_buy"], grey = Art["btn/grey_buy"], gold = Art["btn/gold_maxed"] } end
	if kind == "all" then return { lit = Art["btn/blue_all"], blue = Art["btn/blue_all"], grey = Art["btn/grey_all"] } end
	if kind == "maxed" then return { lit = Art["btn/gold_maxed"], gold = Art["btn/gold_maxed"] } end
	return { lit = Art["btn/" .. id .. "_" .. kind] }
end

-- ---------------------------------------------------------------- rows (row/*): live layers only, the card is baked
local function buildRow(api, body, spec, y, r)
	local row = frame(body, 16, y, 468, ROW_H, nil, { ZIndex = 2 })
	local ico = Kit.icon(row, 12, 16, 76, r.icon or "popcorn", { ZIndex = 4 })
	local title = Kit.title(row, r.title or "", 23, hex(spec.tcol), 2.5, 2, { Position = UDim2.fromOffset(104, 10), ZIndex = 5 })
	local growth = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(104, 40), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 27), ZIndex = 5 }, row)
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, growth)
	local from = Kit.title(growth, "", 20, hex("c9ced8"), 2, 0, { ZIndex = 5, LayoutOrder = 1 })
	local chev = Kit.image(growth, 0, 0, 34, 16, Kit.iconId("ui/chevrons"), { ZIndex = 5, LayoutOrder = 2 })
	Kit.grad(chev, Kit.stops(spec.chev or "daaa28@35:0 ffe18d:100"), 0)
	local to = Kit.title(growth, "", 22, Color3.new(1, 1, 1), 2, 0, { ZIndex = 5, LayoutOrder = 3 })
	Kit.grad(to.label, Kit.stops(spec.gcol))
	-- title and growth never run under the buttons: each shrinks to its 196 px column
	local function fitTo(gui, maxDesign)
		local sc = Kit.new("UIScale", {}, gui)
		local function fit()
			local rowW = row.AbsoluteSize.X
			if rowW <= 0 then return end
			local natural = gui.AbsoluteSize.X / sc.Scale
			local want = math.min(1, rowW * maxDesign / 468 / math.max(1, natural))
			if math.abs(want - sc.Scale) > 0.01 then sc.Scale = want end
		end
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end
	fitTo(growth, 196)
	fitTo(title.holder, 196)
	local desc = text(row, (string.gsub(r.desc or "", "%.%s*$", "")), 15, hex("e6eaf0"), { Position = UDim2.fromOffset(104, 61), ZIndex = 5, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(196, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	Kit.textStroke(desc, 1.4)   -- small text reads bold: brighter fill + ink stroke
	-- progress: the baked track (104,88,186,22) sits too close to the card bottom. Erase it with a copy of the clean card
	-- surface beside it (same rows, under the buttons: nothing baked there) and draw a live track 6 px higher.
	if api.art then
		local A = api.art
		local function patch(dx, sx, w)
			Kit.image(body, 16 + dx, y + 86, w, 26, A.image, { ScaleType = Enum.ScaleType.Stretch, ZIndex = 1,
				ImageRectOffset = Vector2.new((MARGIN + 16 + sx) * A.k, (MARGIN + y + 86) * A.k), ImageRectSize = Vector2.new(w * A.k, 26 * A.k) })
		end
		patch(102, 300, 150); patch(252, 300, 40)
	end
	local TY = 82
	local tbg = frame(row, 104, TY, 186, 22, hex("0d0f14"), { ZIndex = 3, BackgroundTransparency = 0.05 }); Kit.corner(tbg, 11)
	Kit.stroke(tbg, 2, Kit.INK)
	frame(tbg, 6, 2, 174, 2, Color3.new(0, 0, 0), { BackgroundTransparency = 0.5, ZIndex = 3 })
	local track = frame(row, 104, TY, 186, 22, nil, { ZIndex = 4, ClipsDescendants = true }); Kit.corner(track, 11)
	local fill = frame(track, 0, 0, 0, 22, Color3.new(1, 1, 1), { ZIndex = 4 }); Kit.corner(fill, 11)
	local fg = Kit.grad(fill, Kit.stops("fffbd0:0 f5d06b:50 b28d34:100"))
	frame(fill, 3, 1, 0, 2, Color3.new(1, 1, 1), { BackgroundTransparency = 0.55, ZIndex = 5, Size = UDim2.new(1, -6, 0, 2) })
	local lbl = text(track, "", 13, Color3.new(1, 1, 1), { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -12, 1, -4), Position = UDim2.fromOffset(6, 2), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	Kit.new("UITextSizeConstraint", { MaxTextSize = 13 }, lbl)
	Kit.textStroke(lbl, 1.6)
	local prog = { frac = -1 }
	function prog.set(f, t)
		f = math.clamp(f, 0, 1); lbl.Text = t
		fill.Visible = f > 0
		if math.abs(f - prog.frac) > 1e-4 then
			prog.frac = f
			TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(if f > 0 then math.max(22, 186 * f) else 0, 22) }):Play()
		end
	end
	function prog.setStops(st) fg:Destroy(); fg = Kit.grad(fill, st) end
	-- buttons: Figma faces (btn/buy 150x57, btn/buy all 150x31) with live label
	local buy = Kit.button(row, 304, 12, 150, 57, { icon = r.buyIcon, text = "", size = 26, iconSize = 40, stops = Kit.GREY, litStops = Kit.stops(spec.buy) })
	local all = Kit.button(row, 304, 74, 150, 31, { text = r.allText or "BUY ALL", size = 14, stops = Kit.BLUE })
	local maxed = Kit.button(row, 304, 30, 150, 57, { text = "MAXED", size = 26, stops = Kit.GOLD })
	maxed.root.Visible = false
	buy.look("grey"); all.look("grey")
	local rapi = { row = row, title = title, from = from, to = to, desc = desc, prog = prog, buy = buy, all = all, maxed = maxed, icon = ico, y = y, upgrade = r.upgrade, growth = growth }
	table.insert(api.bobbers, { ico, 16, math.random() * 6 })
	function rapi.set(t)
		if t.title then title.set(t.title) end
		if t.from then from.set(t.from) end
		if t.to then to.set(t.to) end
		if t.desc then desc.Text = (string.gsub(t.desc, "%.%s*$", "")) end
		if t.icon then ico.Image = Kit.iconId(t.icon) end
		if t.prog then prog.set(t.prog[1], t.prog[2]) end
		local isMax = t.maxed == true
		if isMax ~= rapi.wasMax then
			rapi.wasMax = isMax
			maxed.root.Visible = isMax
			if isMax then Kit.pop(maxed.root, 0.2); prog.setStops(Kit.stops("fff2b0:0 ffd24a:50 c98a12:100")) end
		end
		buy.root.Visible = not isMax
		all.root.Visible = not isMax and t.hideAll ~= true
		if t.cost then buy.setText(t.cost) end
		if t.buyIcon then buy.setIcon(t.buyIcon) end
		if t.allText then all.setText(t.allText) end
		if t.can ~= nil then
			buy.look(if t.can then "lit" else "grey", nil, if t.can then spec.buyGlow else nil)
			if t.can and rapi.wasCan == false then Window.shine(buy) end
			rapi.wasCan = t.can
			local blue = (t.canAll == nil and t.can) or t.canAll
			task.delay(if blue then 0.08 else 0, function() all.look(if blue then "blue" else "grey") end)
		end
	end
	return rapi
end

function Window.shine(btn)
	local f = btn.face
	local s = frame(f, -60, -6, 34, btn.h + 12, Color3.new(1, 1, 1), { Rotation = 20, ZIndex = 9 })
	Kit.grad(s, { { "ffffff", 0, 0 }, { "ffffff", 0.5, 0.7 }, { "ffffff", 1, 0 } }, 0)
	local t = TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(btn.w + 20, -6) })
	t:Play(); t.Completed:Once(function() s:Destroy() end)
end

-- ---------------------------------------------------------------- window
function Window.build(parent, spec)
	local rows = spec.rows or {}
	local hasHero = spec.hero ~= nil
	local y0 = if hasHero then 497 else 158
	local afterRows = y0 + #rows * ROW_PITCH - 10
	local extraH = spec.extraH or 0
	local footerY = afterRows + 12 + (if extraH > 0 then extraH + 14 else 0)
	local H = spec.h or (footerY + 28)
	if not hasHero then footerY = H - 28 end
	-- spec.trim = { from, to }: drop an empty band baked into the render (art drawn as two slices, window shortened)
	local ART_H = H
	local cut = if spec.trim then spec.trim[2] - spec.trim[1] else 0
	H -= cut; footerY -= cut

	local api = { spec = spec, rows = {}, bobbers = {}, H = H }
	local root = Kit.new("Frame", { Name = spec.id, Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5) }, parent)
	api.root = root
	-- the Figma frame render (incl. rim glow), 2x texture drawn at 1x
	-- the render carries a baked colour rim-glow in its 150 px margin; crop it off and sit the window on a neutral shadow
	-- rounded ink drop (same 24 px corner as the window, like the HUD plates); ImageTransparency proxy keeps the tweens simple
	local shadowF = Kit.frame(root, 0, 6, W, H, Kit.INK, { BackgroundTransparency = 0.5, ZIndex = 0 }); Kit.corner(shadowF, 24)
	local shadow = Kit.new("NumberValue", { Value = 0.5 }, shadowF)
	shadow.Changed:Connect(function(v) shadowF.BackgroundTransparency = v end)
	-- animated rim glow in the window's colour: two rounded strokes hugging the window outline

	-- art is clipped to the window's rounded shape so nothing from the old glow margin shows at the corners
	local clip = Kit.new("CanvasGroup", { Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 0 }, root)
	Kit.corner(clip, 24)   -- Figma window radius (measured on the render)
	-- one clean ink outline drawn from 1 px OUTSIDE the art inward, so no anti-aliased sliver of art shows at the edge
	local edge = Kit.frame(root, -1, -1, W + 2, H + 2, nil, { ZIndex = 2 }); Kit.corner(edge, 25)
	Kit.stroke(edge, 6, Kit.INK)
	local bg = Kit.image(clip, 0, 0, W, H, Art[spec.artId or spec.id], { ScaleType = Enum.ScaleType.Stretch, ZIndex = 0 })
	local px = ArtSize[spec.artId or spec.id]
	if px then
		px = px * math.min(1, 1024 / math.max(px.X, px.Y))   -- Roblox stores uploads at most 1024 px on the long side
		-- renders are uniformly scaled (width = 800 design px incl. margins); crop the margin on all four sides
		local k = px.X / (W + 2 * MARGIN)
		bg.ImageRectOffset = Vector2.new(MARGIN * k, MARGIN * k)
		bg.ImageRectSize = Vector2.new(W * k, px.Y - 2 * MARGIN * k)
		if cut > 0 then
			local a, b = spec.trim[1], spec.trim[2]
			bg.Size = UDim2.fromOffset(W, a); bg.ImageRectSize = Vector2.new(W * k, a * k)
			local bg2 = Kit.image(clip, 0, a, W, ART_H - b, bg.Image, { ScaleType = Enum.ScaleType.Stretch, ZIndex = 0,
				ImageRectOffset = Vector2.new(MARGIN * k, (MARGIN + b) * k), ImageRectSize = Vector2.new(W * k, (ART_H - b) * k) })
			bg:GetPropertyChangedSignal("ImageTransparency"):Connect(function() bg2.ImageTransparency = bg.ImageTransparency end)
		end
	else
		bg.Position = UDim2.fromOffset(-MARGIN, -MARGIN); bg.Size = UDim2.fromOffset(W + 2 * MARGIN, H + 2 * MARGIN)
	end
	api.bg = bg; api.shadow = shadow
	if px then api.art = { image = bg.Image, k = px.X / (W + 2 * MARGIN) } end
	-- the baked tabs bar ends in a 2 px light highlight (y 144-145) the owner reads as a stray line: cover it with the clean
	-- body surface just below it (same columns, so the side shading lines up)
	if px then
		local k = px.X / (W + 2 * MARGIN)
		local strip = Kit.image(clip, 4, 144, W - 8, 2, bg.Image, { ScaleType = Enum.ScaleType.Stretch, ZIndex = 0,
			ImageRectOffset = Vector2.new((MARGIN + 4) * k, (MARGIN + 148) * k), ImageRectSize = Vector2.new((W - 8) * k, 2 * k) })
		bg:GetPropertyChangedSignal("ImageTransparency"):Connect(function() strip.ImageTransparency = bg.ImageTransparency end)
		-- the render also bakes a 2 px coloured rim + light bevel down both sides (x 4-9): replace it with the body
		-- surface just inside it, same rows, so header/tabs/body colours carry on to the ink outline
		if cut == 0 then
			for _, side in { { 4, 10 }, { W - 10, W - 16 } } do
				local sideImg = Kit.image(clip, side[1], 0, 6, H, bg.Image, { ScaleType = Enum.ScaleType.Stretch, ZIndex = 0,
					ImageRectOffset = Vector2.new((MARGIN + side[2]) * k, MARGIN * k), ImageRectSize = Vector2.new(6 * k, H * k) })
				bg:GetPropertyChangedSignal("ImageTransparency"):Connect(function() sideImg.ImageTransparency = bg.ImageTransparency end)
			end
		end
	end
	local body = Kit.new("CanvasGroup", { Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1 }, root)
	Kit.corner(body, 22)
	api.body = body

	-- header: centred title (no icon, user rule) + sparkles
	api.title = Kit.title(body, spec.title, 34, Color3.new(1, 1, 1), 3, 3, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(250, 33), ZIndex = 6 })   -- glyphs centred on the bright band (y 5-58); holder includes the 3 px drop
	Kit.sparkle(body, 384.5, 44.5, 9)
	-- collapse control (drawer tucks into a right-edge tab)
	local col = Kit.button(body, 438, 12, 46, 40, { text = "›", size = 30, stops = Kit.stops("5c6676:0 323844:100"), sound = "close" })
	api.collapse = col
	-- the Fredoka "›" glyph sits low-left in its box: nudge the content onto the face's optical centre
	local cc = col.label.holder.Parent
	cc.Position = UDim2.new(0.5, 1, 0.5, -1)

	-- tabs (16,90,468,54): one tab per member of the window's feature group (Spec.GROUPS), equal widths.
	-- Active = Figma pill face; inactive = icon + grey label (icon only when the group has 4+ members).
	api.tabs = {}
	local tabs = frame(body, 16, 90, 468, 54, nil, { ZIndex = 2 })
	local n = #spec.tabs
	local tw = 468 / n
	for i, t in spec.tabs do
		local x = (i - 1) * tw
		if t.active then
			-- the Figma pill face is drawn for the 2-tab width; narrower pills are built live so corners and icon never squash or clip
			local pill = Kit.button(tabs, x + 6, 7, tw - 12, 42, { icon = t.icon, text = if n >= 4 then "" else t.label, size = if n >= 3 then 17 else 20,
				iconSize = if n >= 4 then 32 else 29, stops = Kit.stops(spec.tab) })
			api.tabs[i] = pill
		else
			local hit = Kit.new("TextButton", { BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(tw, 54), ZIndex = 4 }, tabs)
			local c = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 4 }, hit)
			Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }, c)
			local ic = Kit.icon(c, 0, 0, if n >= 4 then 34 else 28, t.icon, { ZIndex = 5 })
			local lb = if n < 4 then text(c, t.label, if n >= 3 then 16 else 19, hex("8d94a3"), { ZIndex = 5 }) else nil
			local sc = Kit.new("UIScale", {}, c)
			hit.MouseEnter:Connect(function()
				Kit.sfx("hover")
				TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.1 }):Play()
				if lb then lb.TextColor3 = hex("e4e8f0") end
			end)
			hit.MouseLeave:Connect(function()
				TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
				if lb then lb.TextColor3 = hex("8d94a3") end
			end)
			api.tabs[i] = { root = hit, icon = ic, label = lb, id = t.id }
		end
		api.tabs[i].target = t.target
		api.tabs[i].id = t.id
	end

	-- hero (16,158,468,300): art is baked; hero icon, title, subtitle and button are live
	if hasHero then
		local h = spec.hero
		local hero = frame(body, 16, 158, 468, 300, nil, { ZIndex = 2 })
		local hi = Kit.icon(hero, 234, 150, 120, h.icon, { ZIndex = 4, AnchorPoint = Vector2.new(0.5, 1) })
		local ht = Kit.title(hero, h.title, 32, Color3.new(1, 1, 1), 3, 3, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(234, 171), ZIndex = 6 })
		-- subtitle: binders write sub.Text (plain "a  ·  b"); it renders as one outlined line, values in the theme colour,
		-- grey dot separators, shrunk to fit the card
		local subL = text(hero, "", 17, hex("e8ebf2"), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(234, 219), ZIndex = 6, RichText = true })
		Kit.textStroke(subL, 2.2)
		local subS = Kit.new("UIScale", {}, subL)
		local accent; for c in (spec.buy or ""):gmatch("%x%x%x%x%x%x") do accent = c end   -- strongest theme stop
		local vcol = hex(accent or spec.tcol or "ffe18d"):Lerp(Color3.new(1, 1, 1), 0.2):ToHex()
		local raw = ""
		local function fitSub()
			local hw = hero.AbsoluteSize.X / 468
			local wNat = subL.AbsoluteSize.X / math.max(0.01, subS.Scale)
			if wNat > 0 and hw > 0 then
				local want = math.min(1, 432 * hw / wNat)
				if math.abs(want - subS.Scale) > 0.01 then subS.Scale = want end
			end
		end
		subL:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSub)
		hero:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSub)
		local function render(str)
			if str == raw then return end
			raw = str
			local parts = {}
			for part in (str .. "  ·  "):gmatch("(.-)%s*·%s*") do
				if part ~= "" then
					part = part:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
					part = part:gsub("([%+%-]?%d[%d%.,]*%a*%%?)", '<font color="#' .. vcol .. '">%1</font>')
					table.insert(parts, part)
				end
			end
			subL.Text = table.concat(parts, '   <font color="#8d94a3">\u{2022}</font>   ')
		end
		local sub = setmetatable({}, {
			__newindex = function(_, k, v) if k == "Text" then render(v) else subL[k] = v end end,
			__index = function(_, k) if k == "Text" then return raw end return subL[k] end })
		render(h.sub or "")
		local hb = Kit.button(hero, 14, 236, 440, 53, { icon = h.btnIcon, text = h.btn, size = 22, iconSize = 37, stops = Kit.stops(spec.tab) })
		for _, sp in { { 48, 38, 16 }, { 414, 46, 12 }, { 362, 114, 8 }, { 74.5, 124.5, 9 } } do Kit.sparkle(hero, sp[1], sp[2], sp[3]) end
		api.hero = { frame = hero, icon = hi, title = ht, sub = sub, btn = hb }
	end

	if spec.section then
		local sl = text(body, spec.section, 16, hex(spec.sectionColor or "fff2d0"), { Position = UDim2.fromOffset(16, 467), ZIndex = 3 })
		Kit.textStroke(sl, 2)
	end
	for i, r in rows do api.rows[i] = buildRow(api, body, spec, y0 + (i - 1) * ROW_PITCH, r) end
	api.extraY = afterRows + 14
	api.footer = text(body, spec.footer or "", 13, hex("7f8796"), { Position = UDim2.fromOffset(22, footerY), ZIndex = 3, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(456, 16), TextTruncate = Enum.TextTruncate.AtEnd })

	live[api] = true
	return api
end

-- successful upgrade: card brightens, icon pulses, value pops, a few theme-colour sparkles
function Window.celebrate(api, upgradeId)
	for _, r in api.rows do
		if r.upgrade == upgradeId then
			local flash = frame(r.row, -2, -2, 472, ROW_H + 4, Color3.new(1, 1, 1), { BackgroundTransparency = 0.55, ZIndex = 3 }); Kit.corner(flash, 16)
			TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
			task.delay(0.36, function() flash:Destroy() end)
			Kit.pop(r.icon, 1.25); Kit.pop(r.to.holder, 1.2)
			if reduced then return end
			local c = hex(api.spec.buyGlow or "ffffff")
			for _ = 1, 5 do
				local sx, sy = 50 + math.random(-30, 30), 58 + math.random(-30, 30)
				local sp = Kit.image(r.row, sx, sy, 14, 14, Kit.iconId("ui/sparkle"), { ImageColor3 = c, ZIndex = 9 })
				local a = math.random() * math.pi * 2
				TweenService:Create(sp, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(sx + math.cos(a) * 46, sy + math.sin(a) * 34), ImageTransparency = 1, Rotation = 90, Size = UDim2.fromOffset(6, 6) }):Play()
				task.delay(0.46, function() sp:Destroy() end)
			end
			return
		end
	end
end

function Window.destroy(api) live[api] = nil; api.root:Destroy() end

-- ---------------------------------------------------------------- open / close (spec cards OPEN + CLOSE / DISSOLVE)
local function scaleOf(api)
	return api.root:FindFirstChild("OpenScale") or Kit.new("UIScale", { Name = "OpenScale" }, api.root)
end
-- mode: nil = pop open (0.86 -> 1.04 -> 1); "slide" = drawer is sliding, no scale; "tab" = quick fade, no scale
function Window.open(api, mode)
	local root = api.root
	root.Visible = true
	local sc = scaleOf(api)
	if mode then
		sc.Scale = 1
		local t0, dur = if mode == "tab" then 0.6 else 1, if mode == "tab" then 0.1 else 0.18
		api.body.GroupTransparency = t0; api.bg.ImageTransparency = t0; api.shadow.Value = 1
		TweenService:Create(api.body, TweenInfo.new(dur), { GroupTransparency = 0 }):Play()
		TweenService:Create(api.bg, TweenInfo.new(dur), { ImageTransparency = 0 }):Play()
		TweenService:Create(api.shadow, TweenInfo.new(dur + 0.1), { Value = 0.5 }):Play()
		for i, r in api.rows do
			local y = r.y
			r.row.Position = UDim2.fromOffset(16, y + 10)
			task.delay(0.03 + (i - 1) * 0.035, function()
				TweenService:Create(r.row, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(16, y) }):Play()
			end)
		end
		return
	end
	sc.Scale = 0.86
	api.body.GroupTransparency = 1; api.bg.ImageTransparency = 1
	TweenService:Create(api.body, TweenInfo.new(0.12), { GroupTransparency = 0 }):Play()
	TweenService:Create(api.bg, TweenInfo.new(0.12), { ImageTransparency = 0 }):Play()
	api.shadow.Value = 1; TweenService:Create(api.shadow, TweenInfo.new(0.2), { Value = 0.5 }):Play()
	local t1 = TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.04 })
	t1:Play(); t1.Completed:Once(function() TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play() end)
	-- rows: live layers cascade in (40 ms stagger, small overshoot)
	for i, r in api.rows do
		local y = r.y
		r.row.Position = UDim2.fromOffset(16, y + 12)
		task.delay(0.06 + (i - 1) * 0.04, function()
			TweenService:Create(r.row, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(16, y) }):Play()
		end)
	end
end
-- tab switch inside a group: the new window's colours wash in over the old one (art crossfade, no dip to dark),
-- the active pill glides from the old tab to the new one, the hero icon swaps with a springy pop
local morphing = {}
function Window.morph(old, api)
	local slow = if reduced then 0.12 else 0.34
	local ease = TweenInfo.new(slow, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	-- windows sit in their own holders: raise the holder that is a sibling of the old window's holder
	local function layer(a, b)
		local ga = a.root
		while ga.Parent and not b.root:IsDescendantOf(ga.Parent) do ga = ga.Parent end
		return ga
	end
	local newL, oldL = layer(api, old), layer(old, api)
	for a in morphing do layer(a, api).ZIndex = 1 end
	old.root.Visible = true; oldL.ZIndex = 1
	api.root.Visible = true; newL.ZIndex = 2
	morphing[api] = true
	scaleOf(api).Scale = 1; scaleOf(old).Scale = 1
	api.shadow.Value = 0.5
	-- colours: the new art washes in on top of the old
	api.bg.ImageTransparency = 1
	TweenService:Create(api.bg, ease, { ImageTransparency = 0 }):Play()
	-- live layers: old text fades out fast, new fades in behind the wash so nothing reads doubled
	TweenService:Create(old.body, TweenInfo.new(slow * 0.45, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
	api.body.GroupTransparency = 1
	TweenService:Create(api.body, TweenInfo.new(slow * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, slow * 0.25), { GroupTransparency = 0 }):Play()
	-- active pill glides from the tab we came from
	local fromI, toI
	for i, t in api.tabs do
		if t.target == nil and t.face then toI = i end
		if t.id == old.spec.id or t.target == old.spec.id then fromI = i end
	end
	local pill = toI and api.tabs[toI]
	if pill and fromI and fromI ~= toI and not reduced then
		local p = pill.root.Position
		local dx = (fromI - toI) * (468 / #api.tabs)
		pill.root.Position = p + UDim2.fromOffset(dx, 0)
		TweenService:Create(pill.root, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = p }):Play()
	end
	-- hero icon pop
	if api.hero and not reduced then
		local hs = api.hero.icon:FindFirstChild("MorphScale") or Kit.new("UIScale", { Name = "MorphScale" }, api.hero.icon)
		hs.Scale = 0.6
		TweenService:Create(hs, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, slow * 0.2), { Scale = 1 }):Play()
	end
	for i, r in api.rows do
		local y = r.y
		r.row.Position = UDim2.fromOffset(16, y + 8)
		task.delay(slow * 0.3 + (i - 1) * 0.03, function()
			TweenService:Create(r.row, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(16, y) }):Play()
		end)
	end
	task.delay(slow + 0.02, function()
		morphing[api] = nil
		if oldL.ZIndex == 1 and not morphing[old] then old.root.Visible = false; old.body.GroupTransparency = 0 end
	end)
end
function Window.close(api, done)
	local sc = scaleOf(api)
	TweenService:Create(sc, TweenInfo.new(0.16), { Scale = 0.9 }):Play()
	TweenService:Create(api.bg, TweenInfo.new(0.16), { ImageTransparency = 1 }):Play()
	TweenService:Create(api.shadow, TweenInfo.new(0.16), { Value = 1 }):Play()
	local t = TweenService:Create(api.body, TweenInfo.new(0.16), { GroupTransparency = 1 })
	t:Play(); t.Completed:Once(function() api.root.Visible = false; if done then done() end end)
end

-- ---------------------------------------------------------------- idle life
local clock = 0
-- idle motion runs at 30 Hz: the window body is a CanvasGroup, which re-renders its whole texture whenever a child
-- moves, so halving the updates halves that cost (the motion is slow enough to stay smooth)
local idleAcc = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	idleAcc += dt
	if idleAcc < 1 / 30 then return end
	idleAcc = 0
	for api in live do
		if not api.root.Visible then continue end
		if not reduced then for _, bob in api.bobbers do bob[1].Position = UDim2.fromOffset(12, bob[2] + math.sin(clock * math.pi * 2 / 2.2 + bob[3]) * 3) end end
		if api.hero and not reduced then
			-- breathing squash with the feet planted on the shadow, plus a slight sway
			local b = math.sin(clock * math.pi * 2 / 2.6)
			api.hero.icon.Size = UDim2.fromOffset(120 * (1 - 0.025 * b), 120 * (1 + 0.035 * b))
			api.hero.icon.Rotation = math.sin(clock * math.pi * 2 / 5.2) * 2
		end
		local pulse = (math.sin(clock * math.pi * 2 / 1.6) + 1) / 2
		for _, r in api.rows do
			if r.buy.lit then r.buy.glowImg.ImageTransparency = 0.66 + 0.2 * (1 - pulse) end
		end
	end
	if reduced then return end
	for _, sp in Kit.sparkles do
		if sp.i.Parent then
			local t = ((clock + sp.ph) % sp.per) / sp.per
			local s = sp.base * (0.6 + 0.5 * math.sin(t * math.pi))
			sp.i.Size = UDim2.fromOffset(s, s)
			sp.i.Position = UDim2.fromOffset(sp.x - s / 2, sp.y - s / 2)
			sp.i.Rotation = t * 45
		end
	end
end)

return Window
