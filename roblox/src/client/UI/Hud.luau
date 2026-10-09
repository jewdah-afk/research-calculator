--!nonstrict
-- Hud: the in-game HUD, built 1:1 from the Figma HUD board "HUD at Birb parity (squared)" 213:7 and placed like the
-- screen mock 229:7 (1920x1080, HUD scale 0.82, wallet 0.85, area rail 1.0, 16 px margins). Every piece is the
-- Figma component rendered by UI/Figma/Render (layouts Hud_*.luau). Live data comes from the server State push;
-- anything without a game system yet reads UI/SampleData.
--   top left      area banner, 4x2 menu tiles (MAP TELEPORT FISH PROFILE / SHOP SETTINGS AUTO PETS), COMPANIONS list
--   bottom left   wallet: EGGS main chip + 2-column chips that fill upward (only currencies the player has)
--   top centre    context bar for the current area + toasts under it
--   bottom centre objective (+ UNLOCK for paid gates), area hotbar, context AUTO, down arrow
--   right         area rail (open = coloured key, current = popped out, locked = grey + lock), travel arrows
--   top right     SHOP drawer pull tab (the Eggs / Molt / Seeds upgrade drawer docks on the right)
-- Windows are opened through UI/WindowManager (WindowDefs lists every one and the Figma frames behind it).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GroupService = game:GetService("GroupService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local Shared = RS:WaitForChild("Peckwood")
local Defs = require(Shared:WaitForChild("Defs"))
local World = require(Shared:WaitForChild("World"))
local Kit = require(script.Parent.Kit)
local Sfx = require(script.Parent.Sfx)
local Render = require(script.Parent.Figma.Render)
local FKit = require(script.Parent.Figma.FKit)
local WM = require(script.Parent.WindowManager)
local Binders = require(script.Parent.Binders)
local Screens = require(script.Parent.Screens)
local SampleData = require(script.Parent.SampleData)
local RobuxShop = require(script.Parent.RobuxShop)
local Layouts = script.Parent.Figma.Layouts
local EN = Defs.EN

local Hud = {}
Hud.toast = function(_msg: string, _tone: string?, _icon: string?) end   -- set below (showToast)
local plr = Players.LocalPlayer
local S = {
	chips = require(Layouts.Hud_Chips), tiles = require(Layouts.Hud_Tiles), travel = require(Layouts.Hud_Travel),
	auto = require(Layouts.Hud_Auto), context = require(Layouts.Hud_Context), hotbar = require(Layouts.Hud_Hotbar),
	prompts = require(Layouts.Hud_Prompts), companions = require(Layouts.Hud_Companions),
}

local gui, canvas, scale
local Remotes
local state, derived
Hud.kernelCount = 0
Hud.collapsed = true
Hud.dock = { Visible = false }   -- Main.client reads dock.Visible / collapsed to keep the island clear of the drawer

local function act(kind, a, b, btn)
	Remotes.Action:FireServer(kind, a, b)
	Hud.lastBtn = btn
end
Hud.act = act

local function fmt(v) return EN.short(v) end
local function commas(n)
	n = math.floor(n)
	if n >= 1e6 then return EN.short(n) end
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end
local function amount(v)
	local n = EN.toNumber(v)
	if n == n and n < 1e6 then return commas(n) end
	return EN.short(v)
end
Hud.amount, Hud.commas = amount, commas

-- strip the press wiring from a component that is display-only (wallet chips, banner, bars)
local function inert(ui)
	for _, d in ui.root:GetDescendants() do
		if d.Name == "hit" and d:IsA("TextButton") then d:Destroy() end
	end
end
local function setT(under, name, text)
	local l = under:FindFirstChild(name, true)
	if l and l:IsA("TextLabel") then Render.setText(l, text) end
	return l
end
-- recolour a key face / lip from a gradient layer
local function retint(frame, layer)
	if not (frame and layer) then return end
	for _, g in frame:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
	frame.BackgroundColor3 = Color3.new(1, 1, 1); frame.BackgroundTransparency = 0
	Render.gradient(frame, layer, 1)
end

-- ---------------------------------------------------------------- groups (design space 1920x1080, scaled to height)
local groups = {}
local function group(name, anchor, pos, size, sc)
	local g = Render.new("Frame", { Name = name, BackgroundTransparency = 1, AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 5 }, canvas)
	Render.new("UIScale", { Scale = sc }, g)
	groups[name] = g
	return g
end
local topInset = 0
local function layout()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.max(0.35, vp.Y / 1080)
	scale.Scale = s
	canvas.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
	-- the Roblox top bar covers the top-left corner: the top-left block starts under it
	local inset = GuiService:GetGuiInset()
	topInset = inset.Y / s
	if groups.tl then groups.tl.Position = UDim2.fromOffset(16, 14 + topInset) end
	if groups.pull then groups.pull.Position = UDim2.new(1, -16, 0, 14 + topInset) end
	-- narrow (portrait) screens: shrink the HUD a little so the corners never meet
	local w = vp.X / s
	local k = math.clamp(w / 1700, 0.62, 1)
	for name, g in groups do
		local base = g:GetAttribute("baseScale") or g:FindFirstChildOfClass("UIScale").Scale
		g:SetAttribute("baseScale", base)
		g:FindFirstChildOfClass("UIScale").Scale = base * k
	end
end

-- ---------------------------------------------------------------- top left: banner, tiles, companions
local banner, tiles, companions = nil, {}, nil
local TILE_ORDER = { "map", "teleport", "fish", "profile", "shop", "settings", "auto", "pets" }
local TILE_X, TILE_Y = { 0, 111, 223, 334 }, { 91, 216 }
local companionsOpen = true
local COMPANION_ROWS = {   -- Figma row name -> window id, unlock window (WINDOW_ISLAND gate)
	{ "row/SPARROW", "sparrow", "sparrow" }, { "row/SEAGULL", "seagull", "seagull" }, { "row/BAMBOO", "redpanda", "redpanda" },
	{ "row/CROW", "crow", "mine" }, { "row/DAVE", "dave", "dave" }, { "row/PARROT", "parrot", "parrot" },
}
local function unlockedWindow(w)
	return state ~= nil and (Defs.WINDOW_ISLAND[w] or 1) <= state.island
end
local function layoutCompanions()
	if not companions then return end
	local y = 70
	for _, r in COMPANION_ROWS do
		local row = companions.node:FindFirstChild(r[1])
		if row then
			local show = companionsOpen and unlockedWindow(r[3])
			row.Visible = show
			if show then row.Position = UDim2.fromOffset(0, y); y += 58 end
		end
	end
	-- no companion yet: the header stays (Birb shows COMPANIONS once the Sparrow is unlocked)
	companions.root.Visible = state == nil or unlockedWindow("sparrow")
end
local function toggleCompanions()
	companionsOpen = not companionsOpen
	layoutCompanions()
end
Hud.toggleCompanions = toggleCompanions

local function onAuto()
	if not derived then return end
	if not derived.autoAllowed and derived.groupId and derived.groupId > 0 then
		pcall(function() GroupService:PromptJoinAsync(derived.groupId) end)
	end
	act("auto", not (state and state.auto))
end
Hud.onAuto = onAuto

local TILE_ACTION = {
	map = function()
		local on = not plr.PlayerGui:GetAttribute("PeckwoodMap")
		plr.PlayerGui:SetAttribute("PeckwoodMap", on)
		if on then Hud.toast("Map: every open area. Tap MAP again to return", "info", "map") end
	end,
	teleport = function() WM.toggle("teleport") end,
	fish = function() WM.toggle("fishing") end,
	profile = function() WM.toggle("profile") end,
	shop = function() RobuxShop.toggle() end,
	settings = function() WM.toggle("settings") end,
	auto = onAuto,
	pets = function() toggleCompanions() end,
}

local function buildTopLeft()
	local tl = group("tl", Vector2.new(0, 0), UDim2.fromOffset(16, 14), Vector2.new(440, 780), 0.82)
	banner = Render.component(S.prompts, "hud/banner/the bridge", tl)
	inert(banner)
	local areaL = banner.root:FindFirstChild("area", true)
	if areaL then Render.fit(areaL, 16) end
	for i, id in TILE_ORDER do
		local ui = Render.component(S.tiles, "hud/tile/" .. id, tl)
		ui.root.Position = UDim2.fromOffset(TILE_X[(i - 1) % 4 + 1], TILE_Y[math.floor((i - 1) / 4) + 1])
		ui.on("hud/tile/" .. id, function() TILE_ACTION[id]() end)
		tiles[id] = ui
	end
	companions = Render.component(S.companions, "hud/companions (open)", tl)
	companions.root.Position = UDim2.fromOffset(0, 346)
	companions.on("header key", toggleCompanions)
	-- rows open their companion window (rows are plain plates: make each one a button)
	for _, r in COMPANION_ROWS do
		local row = companions.node:FindFirstChild(r[1])
		if row then
			local hit = Render.new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999 }, row)
			local hl = Render.new("Frame", { Name = "hover", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 998 }, row)
			hit.MouseEnter:Connect(function() hl.BackgroundTransparency = 0.94 end)
			hit.MouseLeave:Connect(function() hl.BackgroundTransparency = 1 end)
			hit.MouseButton1Down:Connect(function() Sfx.press() end)
			hit.Activated:Connect(function() WM.toggle(r[2]) end)
		end
	end
	UIS.InputBegan:Connect(function(io, gp)
		if gp then return end
		if io.KeyCode == Enum.KeyCode.Tab then toggleCompanions() end
	end)
end

-- ---------------------------------------------------------------- wallet (bottom left)
-- currency -> Figma chip; popcorn is the EGGS main chip. Chips show only for currencies the player has.
local CHIP = { goldenFeathers = "plume", sunflowerSeeds = "seed", moneta = "moneta", twigs = "twig", goldenPopcorn = "egg_golden",
	bruteOre = "ore", echoPopcorn = "echo", skillPoints = "skill_point" }
local CHIP_ORDER = { "goldenFeathers", "sunflowerSeeds", "moneta", "twigs", "goldenPopcorn", "bruteOre", "echoPopcorn", "skillPoints" }
local CHIP_UNLOCK = { goldenFeathers = 2, sunflowerSeeds = 3, moneta = 5, twigs = 6, bruteOre = 7, goldenPopcorn = 8, skillPoints = 9, echoPopcorn = 10 }
local chips = {}
local WALLET_H = 520
local function chipApi(ui, main)
	local wellF = ui.root:FindFirstChild("well", true)
	local value, name, rate = setT(ui.root, "value", "0"), wellF and wellF:FindFirstChild("name tag"), wellF and wellF:FindFirstChild("rate")
	local c = { ui = ui, value = value, name = name, rate = rate, icon = ui.root:FindFirstChildWhichIsA("ImageLabel"), main = main }
	-- value fits by shrinking; when it needs the room the engraved name hides (never overlaps)
	if value then
		Render.fit(value, 14)
		local function hideName()
			if not (name and wellF) then return end
			local room = (name.Position.X.Offset - value.Position.X.Offset)
			name.Visible = value.TextBounds.X < room - 6
			if rate then rate.Visible = name.Visible or main end
		end
		value:GetPropertyChangedSignal("TextBounds"):Connect(hideName)
	end
	for _, d in ui.root:GetDescendants() do
		if d:IsA("ImageLabel") and d.Name:sub(1, 4) == "ico/" then c.icon = d end
	end
	return c
end
local function buildWallet()
	local g = group("wallet", Vector2.new(0, 1), UDim2.new(0, 10, 1, -10), Vector2.new(520, WALLET_H), 0.852)
	local main = Render.component(S.chips, "hud/chip-main/popcorn", g)
	main.root.Position = UDim2.fromOffset(0, WALLET_H - 92)
	inert(main)
	chips.popcorn = chipApi(main, true)
	for cur, chipName in CHIP do
		local ui = Render.component(S.chips, "hud/chip/" .. chipName, g)
		inert(ui)
		ui.root.Visible = false
		chips[cur] = chipApi(ui, false)
	end
end
local function layoutWallet()
	local i = 0
	for _, cur in CHIP_ORDER do
		local c = chips[cur]
		local show = state ~= nil and (CHIP_UNLOCK[cur] or 99) <= state.island and EN.me(state[cur], 0)
		if cur == "goldenFeathers" and state and state.island >= 2 then show = true end
		c.ui.root.Visible = show
		if show then
			c.ui.root.Position = UDim2.fromOffset(2 + 253 * (i % 2), WALLET_H - 155 - 67 * math.floor(i / 2))
			i += 1
		end
	end
end

-- currency icons arc from a point to their wallet chip (collected eggs, buys)
local function flyFrom(cur, a: Vector2, n, size)
	local c = chips[cur]; if not (c and c.icon and c.ui.root.Visible) then return end
	local s = scale.Scale
	local b = (c.icon.AbsolutePosition + c.icon.AbsoluteSize / 2) / s
	local id = c.icon.Image
	for i = 1, n or 1 do
		local img = Render.new("ImageLabel", { BackgroundTransparency = 1, Image = id, Size = UDim2.fromOffset(size, size), ZIndex = 60 }, canvas)
		local mid = Vector2.new((a.X + b.X) / 2 + math.random(-60, 60), math.min(a.Y, b.Y) - 90 - math.random(0, 60))
		task.delay((i - 1) * 0.04, function()
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local t = math.min(1, (os.clock() - t0) / 0.6)
				local e = t * t * (3 - 2 * t)
				local p = a:Lerp(mid, e):Lerp(mid:Lerp(b, e), e)
				local sz = size - size / 3 * e
				img.Size = UDim2.fromOffset(sz, sz); img.Position = UDim2.fromOffset(p.X - sz / 2, p.Y - sz / 2)
				if t >= 1 then conn:Disconnect(); img:Destroy(); Kit.pop(c.icon, 1.18); Kit.shake(c.ui.root, 5, 0.22) end
			end)
		end)
	end
end
function Hud.flyFromScreen(cur, screenPt: Vector2, n)
	flyFrom(cur, screenPt / scale.Scale, n, 36)
end
function Hud.flyTo(cur, fromGui, n)
	if not fromGui then return end
	flyFrom(cur, (fromGui.AbsolutePosition + fromGui.AbsoluteSize / 2) / scale.Scale, n or 8, 28)
end
function Hud.wiggle(cur) local c = chips[cur]; if c then Kit.shake(c.ui.root, 5, 0.22) end end

-- ---------------------------------------------------------------- top centre: context bar + toasts
local context, contextKind = nil, nil
local AREA_CONTEXT = { bridge = "fishing", mine = "mine", expedition = "expedition", echo = "echo", desert = "desert", forest = "nest" }
local CONTEXT_WINDOW = { fishing = "fishing", mine = "mine", expedition = "expedition", echo = "trees", desert = "trees", nest = "nest" }
local CONTEXT_TAB = { echo = "ARCHIVIST", desert = "DESERT" }
local function buildContext(kind)
	if context then context.root:Destroy(); context = nil end
	contextKind = kind
	if not kind then return end
	context = Render.component(S.context, "hud/context/" .. kind, groups.tc)
	context.root.Position = UDim2.fromOffset(0, 0)
	inert(context)
	-- the whole bar opens the area's window
	local hit = Render.new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999 }, context.root)
	hit.MouseButton1Down:Connect(function() Sfx.press() end)
	hit.Activated:Connect(function() WM.toggle(CONTEXT_WINDOW[kind], CONTEXT_TAB[kind]) end)
	context.fill = context.root:FindFirstChild("fill", true)
	context.fillW = context.fill and context.fill.Parent.Size.X.Offset
	for _, d in context.root:GetDescendants() do
		if d:IsA("TextLabel") and d.RichText and d.Parent.Name == "info strip" then
			context.info = context.info or {}
			table.insert(context.info, d)
		end
	end
	if context.info then table.sort(context.info, function(a, b) return a.Position.X.Offset < b.Position.X.Offset end) end
end
local function setContextBar(frac, label)
	if not context then return end
	setT(context.root, "bar label", label)
	if context.fill then
		local w = math.max(0, math.floor(context.fillW * math.clamp(frac, 0, 1) + 0.5))
		TweenService:Create(context.fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(w, context.fill.Size.Y.Offset) }):Play()
		local edge = context.fill:FindFirstChild("fx/leading edge")
		if edge then edge.Visible = w > 6 end
	end
end
local function setInfo(i, num, rest)
	local l = context and context.info and context.info[i]
	if not l then return end
	local hi, lo = string.match(l.Text, '^<font color="#(%x+)">.-</font><font color="#(%x+)">')
	if hi then
		Render.setText(l, string.format('<font color="#%s">%s</font><font color="#%s">%s</font>', hi, num, lo, rest))
	else
		Render.setText(l, num .. rest)
	end
end
local function updateContext(area)
	local kind = AREA_CONTEXT[area]
	if kind ~= contextKind then buildContext(kind) end
	if not (context and state) then return end
	local SD = SampleData.context[kind]
	if kind == "fishing" then
		setContextBar(SD.xp / SD.need, fmt(SD.xp) .. " / " .. fmt(SD.need) .. " XP")
		setT(context.root, "level", tostring(SD.level))
		local rod = Defs.ROD_BY_ID[state.fish.rod]
		setInfo(1, commas(state.stats.fishCaught), " caught")
		setInfo(2, tostring(rod and rod.monetaPerCatch or 1), " per catch")
	elseif kind == "mine" then
		local area1 = (state.crow.area or 0) + 1
		setT(context.root, "title", "AREA " .. area1)
		setT(context.root, "level", tostring(area1))
		setContextBar(SD.xp / SD.need, fmt(SD.xp) .. " / " .. fmt(SD.need) .. " " .. SD.unit)
	elseif kind == "expedition" then
		local p = state.parrot
		setT(context.root, "level", tostring(p.level))
		setContextBar(SD.xp / SD.need, fmt(SD.xp) .. " / " .. fmt(SD.need) .. " XP")
	elseif kind == "echo" then
		setContextBar(SD.count / SD.cap, SD.count .. " / " .. SD.cap .. " on the field")
	elseif kind == "desert" then
		setContextBar(Hud.kernelCount / math.max(1, derived.cap), Hud.kernelCount .. " / " .. derived.cap .. " on the field")
		setInfo(1, string.format("%.1f%%", (derived.goldenChance or 0) * 100), " chance")
	elseif kind == "nest" then
		local tier = (state.nest.tier or 0) + 1
		local T = Defs.NEST_TIERS[tier]
		local roman = ({ "I", "II", "III", "IV", "V" })[tier] or tostring(tier)
		setT(context.root, "title", "NEST " .. roman)
		setT(context.root, "level", tostring(tier))
		if T and T.next then
			local tw = EN.toNumber(state.twigs)
			setContextBar(tw / T.next, fmt(tw) .. " / " .. fmt(T.next) .. " twigs")
		end
	end
end

-- toasts: Figma hud/toast/<reward|unlock|error|info>, slide down 0.25 s, hold 2.5 s, fade 0.3 s
local toastQ, toastBusy = {}, false
local function showToast(msg, tone, icon)
	table.insert(toastQ, { msg, tone or "info", icon })
	if toastBusy then return end
	toastBusy = true
	task.spawn(function()
		while #toastQ > 0 do
			local t = table.remove(toastQ, 1)
			local name = "hud/toast/" .. (if S.prompts.C["hud/toast/" .. t[2]] then t[2] else "info")
			local ui = Render.component(S.prompts, name, groups.toast)
			inert(ui)
			local root = ui.root
			local lbl = root:FindFirstChild("label", true)
			if lbl then
				Render.setText(lbl, t[1])
				-- the plate grows to fit the message (Figma widths are per sample text)
				local need = lbl.Position.X.Offset + lbl.TextBounds.X + 24
				local body = ui.node:FindFirstChild("body")
				if body and need > body.Size.X.Offset then
					local dw = need - body.Size.X.Offset
					root.Size += UDim2.fromOffset(dw, 0); ui.node.Size += UDim2.fromOffset(dw, 0); body.Size += UDim2.fromOffset(dw, 0)
					lbl.Size += UDim2.fromOffset(dw, 0)
					for _, d in body:GetChildren() do
						if d:IsA("GuiObject") and (d.Name == "top highlight" or d.Name == "gloss cap" or d.Name == "fx/edge light") then d.Size += UDim2.fromOffset(dw, 0) end
					end
				end
			end
			if t[3] then
				for _, d in root:GetDescendants() do
					if d:IsA("ImageLabel") and d.Name:sub(1, 4) == "ico/" then d.Image = FKit.icon(t[3]) end
					if d:IsA("ImageLabel") and d.Name == "drop" then d.Image = FKit.icon(t[3]) end
				end
			end
			root.AnchorPoint = Vector2.new(0.5, 0)
			root.Position = UDim2.new(0.5, 0, 0, -30)
			TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
			task.wait(2.5)
			local tw = TweenService:Create(root, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -20) })
			for _, d in root:GetDescendants() do
				local ti = TweenInfo.new(0.3)
				if d:IsA("TextLabel") then TweenService:Create(d, ti, { TextTransparency = 1 }):Play()
				elseif d:IsA("ImageLabel") then TweenService:Create(d, ti, { ImageTransparency = 1 }):Play()
				elseif d:IsA("Frame") then TweenService:Create(d, ti, { BackgroundTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then TweenService:Create(d, ti, { Transparency = 1 }):Play() end
			end
			tw:Play()
			task.wait(0.3)
			root:Destroy()
		end
		toastBusy = false
	end)
end
Hud.toast = showToast

-- ---------------------------------------------------------------- bottom centre: objective, hotbar, AUTO, down arrow
local objective, unlockKey, hotbar, autoKey
local function buildObjective()
	objective = Render.component(S.prompts, "hud/objective", groups.bc)
	objective.root.AnchorPoint = Vector2.new(0.5, 1)
	objective.root.Position = UDim2.new(0.5, 0, 1, 0)
	inert(objective)
	local goalL = objective.root:FindFirstChild("goal", true)
	if goalL then Render.fit(goalL, 12) end
	-- UNLOCK key for paid gates (Evolve's 100M eggs): kit gold key right of the objective
	local L = FKit.layout()
	local k = FKit.BTNn(L, "btn/unlock", 0, 0, 230, 64, FKit.PAL.gold, "UNLOCK", { icon = "popcorn", size = 22 })
	unlockKey = FKit.build(L, k, groups.bc)
	unlockKey.root.AnchorPoint = Vector2.new(0, 1)
	unlockKey.root.Position = UDim2.new(0.5, 356, 1, 0)
	unlockKey.root.Visible = false
	unlockKey.on("btn/unlock", function() act("unlock", nil, nil, unlockKey) end)
end
local HOTBAR = { bridge = "fishing", mine = "mine", expedition = "expedition" }
local function buildHotbar(kind, variant)
	if hotbar and hotbar.kind == kind and hotbar.variant == variant then return end
	if hotbar then hotbar.root:Destroy(); hotbar = nil end
	if not kind then return end
	local ui = Render.component(S.hotbar, "hud/hotbar/" .. variant, groups.bc)
	ui.kind, ui.variant = kind, variant
	ui.root.AnchorPoint = Vector2.new(0.5, 1)
	ui.root.Position = UDim2.new(0.5, 0, 1, -76)
	if kind == "fishing" then
		ui.on("cast key", function() act("fish", "go") end)
		for _, d in ui.node:GetChildren() do
			if d.Name:sub(1, 5) == "slot/" then
				local hit = Render.new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999 }, d)
				hit.MouseButton1Down:Connect(function() Sfx.press() end)
				hit.Activated:Connect(function() WM.open("fishing", "EQUIPMENT") end)
			end
		end
	elseif kind == "mine" then
		ui.on("challenge key", function() WM.open("mine", "AREAS") end)
	elseif kind == "expedition" then
		ui.on("reset floor key", function() act("expedition") end)
		for _, d in ui.node:GetChildren() do
			if d.Name:sub(1, 5) == "slot/" then
				local hit = Render.new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999 }, d)
				hit.MouseButton1Down:Connect(function() Sfx.press() end)
				hit.Activated:Connect(function() WM.open("parrot", "EQUIPMENT") end)
			end
		end
	end
	hotbar = ui
end
local function buildAuto(kind, st)
	local name = if kind then "hud/auto/" .. kind .. " " .. st else nil
	if name and not S.auto.C[name] then name = "hud/auto/" .. kind .. (if st == "locked" then " locked" else " on") end
	if autoKey and autoKey.name == name then return end
	if autoKey then autoKey.root:Destroy(); autoKey = nil end
	if not (name and S.auto.C[name]) then return end
	local ui = Render.component(S.auto, name, groups.bc)
	ui.name = name
	ui.root.AnchorPoint = Vector2.new(0, 1)
	ui.on("key", onAuto)
	autoKey = ui
end

-- ---------------------------------------------------------------- right: area rail + travel arrows
local RAIL = { { "PARK", "park" }, { "GARDEN", "garden" }, { "FISHING", "bridge" }, { "FOREST", "forest" }, { "MINE", "mine" },
	{ "DESERT", "desert" }, { "EXPEDITION", "expedition" }, { "ECHO", "echo" } }
local RAIL_BOOK = { park = "park (active)", garden = "garden", bridge = "fishing", forest = "forest", mine = "mine", desert = "desert", expedition = "expedition", echo = "echo" }
local RAIL_ICON = { park = "egg", garden = "seed", bridge = "rod_simple", forest = "nest", mine = "crow", desert = "egg_golden", expedition = "parrot", echo = "echo" }
local rail, railSlots, railActive, railArea = nil, {}, nil, nil
local lockedLook, openLook = nil, nil
local function areaColours(area)
	local bm = S.tiles.C["hud/bookmark/" .. RAIL_BOOK[area]]
	if not bm then return nil end
	local face = Render.findNode(bm, "body")
	local lip = Render.findNode(bm, "lip")
	return { face = face and face.f and S.tiles.P[face.f][1], lip = lip and lip.f and S.tiles.P[lip.f][1] }
end
local function slotLook(slot, look, area)
	local face, lip = slot:FindFirstChild("face"), slot:FindFirstChild("lip")
	local ico = face and face:FindFirstChildWhichIsA("ImageLabel")
	local lock = slot:FindFirstChild("ico/lock")
	if look == "locked" then
		retint(face, lockedLook.face); retint(lip, lockedLook.lip)
		if ico then ico.ImageTransparency = 0.3 end
		if lock then lock.Visible = true end
	else
		local cols = areaColours(area) or openLook
		retint(face, cols.face); retint(lip, cols.lip)
		if ico then ico.ImageTransparency = 0 end
		if lock then lock.Visible = false end
	end
	slot:SetAttribute("look", look)
end
local function travelTo(id)
	if id == "aquarium" or id == "market" then WM.open(id); return end
	local isl = World.byId[id]
	if not isl then return end
	if not World.isOpen(isl) then
		Sfx.deny()
		local idx
		for i, x in Defs.ISLANDS do if x.id == id then idx = i end end
		Hud.toast("Locked: " .. (if idx then Defs.ISLANDS[idx].goal else "keep going"), "error", "map")
		return
	end
	plr.PlayerGui:SetAttribute("PeckwoodTP", id .. "#" .. os.clock())
end
Hud.travelTo = travelTo
local function buildRail()
	local g = group("rail", Vector2.new(1, 0.5), UDim2.new(1, 0, 0.5, 0), Vector2.new(100, 616), 1)
	rail = Render.component(S.tiles, "hud/area rail", g)
	local face = rail.root:FindFirstChild("rail face", true)
	-- reference looks (open = the Park slot, locked = the Forest slot) taken from the Figma layout itself
	local railNode = S.tiles.C["hud/area rail"]
	local function looksOf(name)
		local n = Render.findNode(railNode, name)
		local fN, lN = Render.findNode(n, "face"), Render.findNode(n, "lip")
		return { face = S.tiles.P[fN.f][1], lip = S.tiles.P[lN.f][1] }
	end
	openLook, lockedLook = looksOf("slot/PARK"), looksOf("slot/FOREST (locked)")
	-- the Figma rail has FISHING popped out; the plain FISHING slot is a copy of the GARDEN slot in its place
	local garden = face:FindFirstChild("slot/GARDEN")
	local fishing = Render.buildNode(S.tiles, Render.findNode(railNode, "slot/GARDEN"), face, garden.ZIndex)
	fishing.root.Name = "slot/FISHING (holder)"; fishing.node.Name = "slot/FISHING"
	fishing.root.Position = UDim2.fromOffset(4, 156)
	setT(fishing.root, "label", "FISHING")
	local fi = fishing.node:FindFirstChild("face"):FindFirstChildWhichIsA("ImageLabel")
	if fi then fi.Image = FKit.icon("rod_simple") end
	-- the lock badge every slot can show
	railActive = rail.node:FindFirstChild("slot/FISHING (active)")
	for i, r in RAIL do
		local slot = face:FindFirstChild("slot/" .. r[1]) or face:FindFirstChild("slot/" .. r[1] .. " (locked)") or (r[1] == "FISHING" and fishing.node)
		if slot then
			if not slot:FindFirstChild("ico/lock") then
				local L = FKit.layout()
				local lk = FKit.build(L, FKit.ICOn("lock", 22, 50, -5, L), slot)
				lk.root.Name = "ico/lock"; lk.root.Position = UDim2.fromOffset(50, -5); lk.root.Visible = false
			end
			railSlots[r[2]] = slot
			-- every slot travels (keys are wired by Render; plain copies get a hit here)
			local hit = slot:FindFirstChild("hit") or Render.new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999 }, slot)
			hit.Activated:Connect(function() travelTo(r[2]) end)
		end
	end
	local ah = railActive and railActive:FindFirstChild("hit")
	if ah then ah.Activated:Connect(function() if railArea then WM.toggle(CONTEXT_WINDOW[AREA_CONTEXT[railArea] or ""] or "profile") end end) end
end
local function updateRail(area)
	if not rail then return end
	for i, r in RAIL do
		local slot = railSlots[r[2]]
		if slot then
			local isl = World.byId[r[2]]
			local open = isl ~= nil and World.isOpen(isl)
			local look = if open then "open" else "locked"
			if slot:GetAttribute("look") ~= look then slotLook(slot, look, r[2]) end
			slot.Visible = r[2] ~= area
		end
	end
	-- the current area pops out of the rail (Figma "slot/FISHING (active)"), retinted and relabelled
	if railActive then
		local idx
		for i, r in RAIL do if r[2] == area then idx = i end end
		railActive.Visible = idx ~= nil
		if idx and railArea ~= area then
			railArea = area
			local cols = areaColours(area) or openLook
			retint(railActive:FindFirstChild("face"), cols.face); retint(railActive:FindFirstChild("lip"), cols.lip)
			for _, d in railActive:GetDescendants() do
				if d:IsA("TextLabel") and not d.Name:find("drop") then Render.setText(d, RAIL[idx][1]) end
				if d:IsA("ImageLabel") and (d.Name:sub(1, 4) == "ico/" or d.Name == "drop") then d.Image = FKit.icon(RAIL_ICON[area]) end
			end
			local y = 4 + 76 * (idx - 1) + 3 - 4
			TweenService:Create(railActive, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, y) }):Play()
		end
	end
end

-- travel arrows (Birb map arrows): left / right along the chain, up / down to rooms
local TRAVEL = {
	park = { left = "forest", right = "garden", up = "desert" }, garden = { left = "park", right = "bridge" },
	bridge = { left = "garden", right = "castle", down = "aquarium" }, castle = { left = "bridge" },
	forest = { left = "expedition", right = "park" }, expedition = { right = "forest", down = "mine" }, mine = { up = "expedition" },
	desert = { left = "forest", right = "garden", down = "park" }, echo = { right = "garden" },
}
local arrows = {}
local function destName(id)
	if id == "aquarium" then return "AQUARIUM" elseif id == "market" then return "FISH MARKET" end
	local isl = World.byId[id]
	return if isl then string.upper(isl.name) else string.upper(id)
end
local function buildArrows()
	group("travelL", Vector2.new(0, 0), UDim2.new(0, 16, 0.5, 116), Vector2.new(260, 70), 0.82)
	group("travelR", Vector2.new(1, 0), UDim2.new(1, -110, 0.5, -29), Vector2.new(260, 70), 0.82)
	group("travelU", Vector2.new(0.5, 0), UDim2.new(0.5, 400, 0, 14), Vector2.new(260, 70), 0.82)
	for _, dir in { "left", "right", "up", "down" } do
		local parent = if dir == "down" then groups.bc else groups["travel" .. string.upper(dir:sub(1, 1))]
		local open = Render.component(S.travel, "hud/travel/" .. dir, parent)
		local lockedName = "hud/travel/" .. dir .. " (locked)"
		local locked = if S.travel.C[lockedName] then Render.component(S.travel, lockedName, parent) else nil
		for _, ui in { open, locked } do
			if ui then
				ui.root.Visible = false
				if dir == "right" then ui.root.AnchorPoint = Vector2.new(1, 0); ui.root.Position = UDim2.new(1, 0, 0, 0) end
				if dir == "down" then ui.root.AnchorPoint = Vector2.new(0, 1); ui.root.Position = UDim2.new(0.5, 435, 1, -6) end
				ui.onAny(function() if arrows[dir].target then travelTo(arrows[dir].target) end end)
			end
		end
		arrows[dir] = { open = open, locked = locked }
	end
end
local function setArrowLabel(ui, text)
	if not ui then return end
	local face = ui.node:FindFirstChild("face")
	if not face then return end
	for _, l in Render.childTexts(face) do Render.setText(l, text) end
end
local function updateArrows(area)
	local t = TRAVEL[area] or {}
	for dir, a in arrows do
		local id = t[dir]
		a.target = id
		local open = id ~= nil and (id == "aquarium" or id == "market" or (World.byId[id] and World.isOpen(World.byId[id])))
		a.open.root.Visible = id ~= nil and open
		if a.locked then a.locked.root.Visible = id ~= nil and not open end
		if id then
			setArrowLabel(a.open, destName(id))
			if a.locked and not open then
				local req = "LOCKED"
				for i, x in Defs.ISLANDS do
					if x.id == id then req = string.upper((string.gsub(string.gsub(x.goal, "^Reach ", ""), " to open.*$", ""))) end
				end
				setArrowLabel(a.locked, req)
			end
		end
	end
end

-- [E] prompt above the player (no proximity system yet): Hud.prompt("aquarium") shows one, Hud.prompt() hides
local promptUi
function Hud.prompt(kind, onUse)
	if promptUi then promptUi.root:Destroy(); promptUi = nil end
	if not kind then return end
	promptUi = Render.component(S.prompts, "hud/prompt/" .. kind, groups.prompt)
	promptUi.root.AnchorPoint = Vector2.new(0.5, 0); promptUi.root.Position = UDim2.new(0.5, 0, 0, 0)
	promptUi.on("E key", function() if onUse then onUse() end end)
end

-- shop drawer pull tab (top right): opens the Eggs / Molt / Seeds drawer; hides while the drawer is out
local pull
local function buildPull()
	local g = group("pull", Vector2.new(1, 0), UDim2.new(1, -16, 0, 14), Vector2.new(230, 72), 0.82)
	local L = FKit.layout()
	local k = FKit.BTNn(L, "btn/shop drawer", 0, 0, 230, 72, FKit.PAL.gold, "UPGRADES", { icon = "shop", size = 21 })
	pull = FKit.build(L, k, g)
	pull.root.AnchorPoint = Vector2.new(1, 0); pull.root.Position = UDim2.new(1, 0, 0, 0)
	pull.on("btn/shop drawer", function() WM.setDrawer(not WM.drawerOpen) end)
end

-- ---------------------------------------------------------------- state
local lastIsland, lastArea = 0, nil
local lastVals = {}
local function currentArea()
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local here = if hrp then World.nearest(hrp.Position.X / 4 + 20, hrp.Position.Z / 4 + 15) else World.byId.park
	return here
end
function Hud.setState(s, d)
	state, derived = s, d
	WM.update(s, d)
	RobuxShop.setDerived(d)
	-- banner: the area the bird stands on + eggs on the field
	local here = currentArea()
	local area = here and (here.area or here.id) or "park"
	if banner then
		setT(banner.root, "area", here and here.name or "THE PARK")
		setT(banner.root, "count", Hud.kernelCount .. " / " .. d.cap)
		if area ~= lastArea then
			local cols = areaColours(area)
			if cols then retint(banner.node:FindFirstChild("body"), cols.face) end
		end
	end
	-- wallet
	for cur, c in chips do
		local v = s[cur]
		if v and c.value then
			Render.setText(c.value, amount(v))
			local prev = lastVals[cur]
			if prev and EN.me(v, prev) and cur ~= "popcorn" and c.ui.root.Visible then Kit.pop(c.value, 1.06) end
			lastVals[cur] = v
		end
	end
	if chips.popcorn.rate then Render.setText(chips.popcorn.rate, "+" .. fmt(d.popPerSec) .. "/s") end
	layoutWallet()
	-- objective + unlock
	if objective then
		setT(objective.root, "goal", d.nextGoal)
		local frac = 0
		if d.nextCost then
			for cur, n in d.nextCost do frac = math.min(1, EN.toNumber(s[cur]) / n) end
		end
		local fill = objective.root:FindFirstChild("fill", true)
		if fill then fill.Size = UDim2.fromOffset(math.floor(600 * frac + 0.5), fill.Size.Y.Offset) end
		unlockKey.root.Visible = d.nextCost ~= nil
		if d.nextCost then
			local can = true
			for cur, n in d.nextCost do
				if not EN.meeq(s[cur], n) then can = false end
				local face = unlockKey.node:FindFirstChild("face")
				for _, l in Render.childTexts(face) do Render.setText(l, "UNLOCK " .. fmt(n)) end
			end
			retint(unlockKey.node:FindFirstChild("face"), FKit.vgrad(if can then FKit.PAL.gold else FKit.PAL.steel))
			retint(unlockKey.node:FindFirstChild("lip"), FKit.vgrad(if can then FKit.PAL.gold else FKit.PAL.steel, 0.58))
		end
	end
	-- tiles: AUTO tile shows on / off by tint, locked tiles do not exist (all 8 are always available)
	-- area pieces
	updateContext(area)
	local hk = HOTBAR[area]
	if hk == "fishing" then buildHotbar("fishing", if s.fish.active then "fishing (reeling)" else "fishing (ready)")
	elseif hk == "mine" then buildHotbar("mine", "mine (challenge)")
	elseif hk == "expedition" then buildHotbar("expedition", "expedition")
	else buildHotbar(nil) end
	if hotbar and hk == "fishing" then
		local bait = s.fish.bait and s.fish.baits[s.fish.bait] or SampleData.hotbar.fishing.baitCount
		setT(hotbar.root, "24", tostring(bait))
	end
	local akind = ({ bridge = "fish", mine = "mine", expedition = "expedition", forest = "forest" })[area]
	buildAuto(akind, if not d.autoAllowed then "locked" elseif s.auto then "on" else "off")
	if autoKey then
		local hw = if hotbar then hotbar.root.Size.X.Offset / 2 else 0
		autoKey.root.Position = UDim2.new(0.5, hw + 14, 1, -82)
		if not d.autoAllowed then
			local lbl = autoKey.root:FindFirstChild("label", true)
			if lbl then Render.setText(lbl, if akind == "fish" then "AUTO " .. SampleData.autoFish.have .. "/" .. SampleData.autoFish.need else "AUTO") end
		end
	end
	updateRail(area)
	updateArrows(area)
	layoutCompanions()
	-- companion levels
	if companions then
		local L = { ["row/SPARROW"] = s.sparrow.level, ["row/SEAGULL"] = s.seagull.level, ["row/BAMBOO"] = SampleData.companions.redpanda,
			["row/CROW"] = s.crow.level, ["row/DAVE"] = s.dave.level, ["row/PARROT"] = s.parrot.level }
		for row, lv in L do
			local r = companions.node:FindFirstChild(row)
			local lvl = r and r:FindFirstChild("level")
			if lvl then for _, l in Render.childTexts(lvl) do Render.setText(l, tostring(lv)) end end
		end
	end
	-- new area unlocked: rail slot pops
	if s.island > lastIsland and lastIsland > 0 then
		for _, r in RAIL do local slot = railSlots[r[2]]; if slot then Kit.pop(slot, 1.2) end end
	end
	lastIsland = s.island
	lastArea = area
end

-- ---------------------------------------------------------------- toasts from the server
function Hud.onToast(kind, a, b, c)
	if kind == "bought" then
		Sfx.buy()
		local dd = Defs.UP[a]
		if dd then local ch = chips[dd.cur]; if ch and ch.value then Kit.pop(ch.value, 1.06) end end
		Binders.bought(a)
	elseif kind == "poor" then
		Sfx.deny()
		local lb = Hud.lastBtn
		local inst = if typeof(lb) == "Instance" then lb elseif type(lb) == "table" then lb.root else nil
		if inst then Kit.shake(inst, 6, 0.28) end
		local dd = Defs.UP[a]
		if dd then Hud.wiggle(dd.cur) end
	elseif kind == "molt" then
		showToast("You molted!  +" .. a .. " Plumes" .. (if b then "  ·  The Garden opens" else ""), "reward", "plume")
		local fl = Render.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("b06cff"), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 90 }, canvas)
		TweenService:Create(fl, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function() fl:Destroy() end)
	elseif kind == "island" then showToast(b .. " opens!", "unlock", "map")
	elseif kind == "evolve" then
		showToast("Evolution " .. a .. "!  The monster grows.", "reward", "monster")
		local fl = Render.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("ff5a8a"), BackgroundTransparency = 0.3, Size = UDim2.fromScale(1, 1), ZIndex = 90 }, canvas)
		TweenService:Create(fl, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
		task.delay(0.7, function() fl:Destroy() end)
	elseif kind == "fish" then
		local n = string.gsub(string.gsub(a, "^fish_", ""), "_", " ")
		showToast("New fish!  " .. n .. "  ·  " .. string.format("%.2f kg", b), "info", "fish")
	elseif kind == "floor" then showToast("Floor " .. a .. " reached!", "info", "parrot")
	elseif kind == "nest" then showToast("The " .. a .. " nest is built!", "unlock", "nest")
	elseif kind == "craft" then showToast("Crafted a new rod!", "reward", a)
	elseif kind == "sacrifice" then showToast("Sacrificed!  Tier " .. a, "reward", "altar")
	elseif kind == "claim" then showToast("Quest claimed!", "reward", "chest")
	elseif kind == "travel" then showToast(if a == "desert" then "Welcome to the Desert" else "Back to the Park", "info", if a == "desert" then "golden" else "popcorn")
	elseif kind == "auto" then showToast(if a then "AUTO is on" else "AUTO is off", "info", "auto")
	elseif kind == "autolocked" then showToast("Join the group to unlock AUTO", "error", "auto")
	elseif kind == "dev" then showToast("Dev save: " .. string.upper(a) .. "  ·  island " .. b, "info", "crown")
	elseif kind == "unlocked" then showToast("Unlocked!", "unlock", "crown")
	end
end

-- ---------------------------------------------------------------- dev save panel (Studio / owner only)
local devPanel
local function buildDev()
	local L = FKit.layout()
	devPanel = Render.new("Frame", { Name = "dev", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(520, 60), Visible = false, ZIndex = 20 }, canvas)
	local x = 0
	for _, b in { { "REGULAR", "regular", FKit.PAL.green }, { "MAXED", "maxed", FKit.PAL.gold }, { "NEXT AREA", "next", FKit.PAL.violet } } do
		local k = FKit.BTNn(L, "btn/dev " .. b[2], x, 0, 160, 52, b[3], b[1], { size = 17 })
		local ui = FKit.build(L, k, devPanel)
		ui.root.Position = UDim2.fromOffset(x, 0)
		ui.on("btn/dev " .. b[2], function() act("dev", b[2]) end)
		x += 172
	end
end

-- ---------------------------------------------------------------- start
function Hud.start(remotes)
	Remotes = remotes
	local pg = plr:WaitForChild("PlayerGui")
	gui = Render.new("ScreenGui", { Name = "PeckwoodHUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, pg)
	canvas = Render.new("Frame", { Name = "canvas", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080) }, gui)
	scale = Render.new("UIScale", {}, canvas)
	Hud.canvas = canvas
	-- the windows layer and its binders / hand-built screens
	WM.screens = Screens
	Screens.init(Hud, WM)
	Binders.install(WM, act, Hud)
	WM.init(pg)
	WM.debugHook()
	WM.onChanged = function()
		Hud.dock.Visible = WM.drawerOpen
		Hud.collapsed = not WM.drawerOpen
		if pull then pull.root.Visible = not WM.drawerOpen end
	end
	group("tc", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 10), Vector2.new(560, 106), 0.85)
	group("toast", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 112), Vector2.new(1000, 80), 0.78)
	group("bc", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12), Vector2.new(680, 260), 0.82)
	group("prompt", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 640), Vector2.new(600, 62), 0.85)
	buildTopLeft(); buildWallet(); buildObjective(); buildRail(); buildArrows(); buildPull(); buildDev()
	RobuxShop.init(canvas, function(msg, tone, icon) showToast(msg, if tone == "golden" then "reward" else "info", icon) end, act)
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	remotes.State.OnClientEvent:Connect(function(s, d)
		Hud.setState(s, d)
		if devPanel then devPanel.Visible = d.devAllowed == true end
	end)
	remotes.Fish.OnClientEvent:Connect(function(disc, best, have)
		Binders.fish = { disc = disc, best = best, have = have }
	end)
	remotes.Toast.OnClientEvent:Connect(Hud.onToast)
	pg:GetAttributeChangedSignal("PeckwoodShop"):Connect(function() RobuxShop.toggle() end)
	pg:GetAttributeChangedSignal("PeckwoodPrompt"):Connect(function()
		local v = pg:GetAttribute("PeckwoodPrompt")
		Hud.prompt(if typeof(v) == "string" and v ~= "" then v else nil)
	end)
end

return Hud
