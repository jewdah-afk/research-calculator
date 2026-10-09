--!nonstrict
-- Hud: the in-game HUD, built 1:1 from the Figma HUD board 213:7 (every piece is the Figma component rendered by
-- UI/Figma/Render) and PLACED LIKE BIRB (UI/Layout): the upgrades sidebar is a permanent right column and the HUD
-- lives in the game area left of it, re-flowing when the sidebar collapses. Every spacing value comes from
-- Layout.S (8 px grid at 1080p); alignment uses each component's visual bounds.
--   top-left      area banner, wallet under it (EGGS main chip, then the other currencies in 2 columns)  [Birb]
--   top-right     COMPANIONS [TAB] (drops its list down), context AUTO under it, area rail under that      [Birb]
--   top-centre    context bar (fishing level / mine area ...), up arrow, toast stack                         [Birb]
--   mid-left/-right  travel arrows with their destination                                                    [Birb]
--   bottom-centre hotbar (CAST ...), objective under it, down arrow left of the hotbar                       [Birb]
--   bottom-right  the 4x2 tile block (Birb's icon row: Fast Travel pops up above TELEPORT)                  [Birb]
-- Feel: counters roll, "+N" floaters fly icons into the wallet, notification badges (max 2), toasts stack with a
-- spring and an auto-dismiss line, a centred banner for big moments, keyboard hints (Q objectives, P profile, Tab
-- companions). Anything without a game system reads UI/SampleData.
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
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Motion)
local WM = require(script.Parent.WindowManager)
local Binders = require(script.Parent.Binders)
local Screens = require(script.Parent.Screens)
local SampleData = require(script.Parent.SampleData)
local RobuxShop = require(script.Parent.RobuxShop)
local Layouts = script.Parent.Figma.Layouts
local EN = Defs.EN
local SP = Layout.S

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
Hud.collapsed = false
Hud.dock = { Visible = true }   -- Main.client keeps the island clear of the sidebar while it is open

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
	local n = if type(v) == "number" then v else EN.toNumber(v)
	if n == n and n < 1e6 then return commas(n) end
	return EN.short(v)
end
Hud.amount, Hud.commas = amount, commas

-- strip the press wiring from a component that is display-only (wallet chips, banner, bars)
local function inert(ui)
	for _, d in ui.root:GetDescendants() do
		if Motion.isKey(d) then Motion.unkey(d) end
	end
	for _, d in ui.root:GetDescendants() do
		if d.Name == "hit" and d:IsA("TextButton") then d:Destroy() end
	end
end
local function setT(under, name, text)
	local l = under:FindFirstChild(name, true)
	if l and l:IsA("TextLabel") then Render.setText(l, text) end
	return l
end
local function retint(frame, layer)
	if not (frame and layer) then return end
	for _, g in frame:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
	frame.BackgroundColor3 = Color3.new(1, 1, 1); frame.BackgroundTransparency = 0
	Render.gradient(frame, layer, 1)
end
local function centreOf(inst)   -- design-px centre of any on-screen GuiObject
	if not (inst and scale) then return nil end
	local s = scale.Scale
	return (inst.AbsolutePosition + inst.AbsoluteSize / 2) / s
end
Hud.centreOf = centreOf
local function button(parent, onClick, kind)   -- the one press (Motion.key): flat press-in, hover veil, keycap sounds
	return Motion.key(parent, kind or "plain", { onActivate = onClick }).hit
end

-- open a window out of the HUD element that asked for it (the window pops from / shrinks back into it)
local sourceOf = {}
local function openFrom(id, inst, tab)
	local p = centreOf(inst)
	if p then sourceOf[id] = p end
	WM.toggle(id, tab)
end
Hud.openFrom = openFrom

-- ---------------------------------------------------------------- groups (each one UIScale'd Figma component)
local groups = {}
local function group(name, size, sc)
	local g = Render.new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 5 }, canvas)
	local u = Render.new("UIScale", { Scale = sc }, g)
	g:SetAttribute("baseScale", sc)
	groups[name] = g
	return g, u
end
local function gscale(name) local g = groups[name]; return g and g:FindFirstChildOfClass("UIScale").Scale or 1 end
local function place(name, anchor, x, y, animate)
	local g = groups[name]; if not g then return end
	g.AnchorPoint = anchor
	local p = UDim2.fromOffset(x, y)
	if animate and not Kit.reduced() then TweenService:Create(g, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = p }):Play()
	else g.Position = p end
end
-- component visual bounds (Layout.bounds) scaled by its group
local function vb(sec, name, sc)
	local x0, y0, x1, y1 = Layout.bounds(sec.C[name])
	return x0 * sc, y0 * sc, x1 * sc, y1 * sc
end

-- ---------------------------------------------------------------- top-left: banner + wallet
local banner
local CHIP = { goldenFeathers = "plume", sunflowerSeeds = "seed", moneta = "moneta", twigs = "twig", goldenPopcorn = "egg_golden",
	bruteOre = "ore", echoPopcorn = "echo", skillPoints = "skill_point" }
local CHIP_ORDER = { "goldenFeathers", "sunflowerSeeds", "moneta", "twigs", "goldenPopcorn", "bruteOre", "echoPopcorn", "skillPoints" }
local CHIP_UNLOCK = { goldenFeathers = 2, sunflowerSeeds = 3, moneta = 5, twigs = 6, bruteOre = 7, goldenPopcorn = 8, skillPoints = 9, echoPopcorn = 10 }
local chips = {}
local function chipApi(ui, main)
	local wellF = ui.root:FindFirstChild("well", true)
	local value, name, rate = setT(ui.root, "value", "0"), wellF and wellF:FindFirstChild("name tag"), wellF and wellF:FindFirstChild("rate")
	local c = { ui = ui, value = value, name = name, rate = rate, main = main, shown = 0 }
	if value then
		Render.fit(value, 14)
		-- the value fits by shrinking; when it needs the room the engraved name hides (never overlaps)
		local function hideName()
			if not (name and wellF) then return end
			name.Visible = Render.textWidth(value) < (name.Position.X.Offset - value.Position.X.Offset) - 6
			if rate then rate.Visible = name.Visible or main end
		end
		value:GetPropertyChangedSignal("Text"):Connect(hideName)
		value:GetPropertyChangedSignal("TextSize"):Connect(hideName)
	end
	for _, d in ui.root:GetDescendants() do
		if d:IsA("ImageLabel") and d.Name:sub(1, 4) == "ico/" then c.icon = d end
	end
	return c
end
local function buildTopLeft()
	local tl = group("banner", Vector2.new(372, 82), SP.HUD)
	banner = Render.component(S.prompts, "hud/banner/the bridge", tl)
	inert(banner)
	local areaL = banner.root:FindFirstChild("area", true)
	if areaL then Render.fit(areaL, 16) end
	local w = group("wallet", Vector2.new(640, 520), SP.WALLET)
	local main = Render.component(S.chips, "hud/chip-main/popcorn", w)
	inert(main)
	chips.popcorn = chipApi(main, true)
	for cur, chipName in CHIP do
		local ui = Render.component(S.chips, "hud/chip/" .. chipName, w)
		inert(ui)
		ui.root.Visible = false
		chips[cur] = chipApi(ui, false)
	end
end
-- wallet rows: main chip first, then 2 columns, visual edges aligned, GAP between rows and columns
local function layoutWallet()
	local sc = SP.WALLET
	local mx0, my0 = Layout.bounds(S.chips.C["hud/chip-main/popcorn"])
	local cx0, cy0, cx1, cy1 = Layout.bounds(S.chips.C["hud/chip/plume"])
	local _, _, _, my1 = Layout.bounds(S.chips.C["hud/chip-main/popcorn"])
	-- local (unscaled) coordinates: visual left edge at 0
	chips.popcorn.ui.root.Position = UDim2.fromOffset(-mx0, -my0)
	local top = (my1 - my0) + SP.GAP / sc
	local colW = (cx1 - cx0) + SP.GAP / sc
	local rowH = (cy1 - cy0) + SP.GAP / sc
	local i = 0
	for _, cur in CHIP_ORDER do
		local c = chips[cur]
		local show = state ~= nil and (CHIP_UNLOCK[cur] or 99) <= state.island and EN.me(state[cur], 0)
		if cur == "goldenFeathers" and state and state.island >= 2 then show = true end
		c.ui.root.Visible = show
		if show then
			c.ui.root.Position = UDim2.fromOffset(-cx0 + colW * (i % 2), top - cy0 + rowH * math.floor(i / 2))
			i += 1
		end
	end
end

-- odometer: a chip value rolls to its new number; a gain pulses the chip and flashes the +rate green
local function setChip(cur, v)
	local c = chips[cur]; if not (c and c.value) then return end
	local n = EN.toNumber(v)
	local prev = c.shown
	if prev == n then return end
	c.shown = n
	if n ~= n or n >= 1e15 or prev ~= prev or prev >= 1e15 or not c.ui.root.Visible then
		Render.setText(c.value, amount(v))
	else
		Motion.roll(c.value, prev, n, function(x) return amount(math.floor(x + 0.5)) end, function(s) local sh = Render.SHADOW[c.value]; if sh then sh.Text = s end end)
	end
	if n > prev and prev > 0 and c.ui.root.Visible then
		Kit.pop(c.value, 1.06)
		if c.rate then Motion.flashText(c.rate, "d6ffdd") end
	end
end

-- currency icons arc from a point into their wallet chip, each landing with a tick and a chip bump
local function flyFrom(cur, a: Vector2, n, size)
	local c = chips[cur]; if not (c and c.icon and c.ui.root.Visible) then return end
	local b = centreOf(c.icon)
	local id = c.icon.Image
	for i = 1, n or 1 do
		local img = Render.new("ImageLabel", { BackgroundTransparency = 1, Image = id, Size = UDim2.fromOffset(size, size), ZIndex = 60, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(a.X, a.Y) }, canvas)
		local mid = Vector2.new((a.X + b.X) / 2 + math.random(-60, 60), math.min(a.Y, b.Y) - 90 - math.random(0, 60))
		-- a quadratic curve driven by one NumberValue tween (event driven, ends by itself)
		local nv = Instance.new("NumberValue")
		nv.Changed:Connect(function(t)
			local p = a:Lerp(mid, t):Lerp(mid:Lerp(b, t), t)
			local sz = size - size / 3 * t
			img.Size = UDim2.fromOffset(sz, sz); img.Position = UDim2.fromOffset(p.X, p.Y)
		end)
		task.delay((i - 1) * 0.05, function()
			local tw = TweenService:Create(nv, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
			tw.Completed:Once(function()
				img:Destroy(); nv:Destroy()
				Sfx.coinLand(i)
				Kit.pop(c.icon, 1.12)
			end)
			tw:Play()
		end)
	end
end
function Hud.flyFromScreen(cur, screenPt: Vector2, n)
	flyFrom(cur, screenPt / scale.Scale, n, 36)
end
function Hud.flyTo(cur, fromGui, n)
	local p = centreOf(fromGui)
	if p then flyFrom(cur, p, n or 6, 28) end
end
function Hud.wiggle(cur) local c = chips[cur]; if c then Kit.shake(c.ui.root, 5, 0.22) end end
-- a collected egg: "+N" rises from the spot, then a few icons curve into the chip (Vfx.onLabel can call this)
function Hud.onLabel(pos, value, cur)
	cur = cur or "popcorn"
	local p = pos
	if typeof(pos) == "Vector3" then
		local v, on = workspace.CurrentCamera:WorldToViewportPoint(pos)
		if not on then return end
		p = Vector2.new(v.X, v.Y)
	end
	if typeof(p) ~= "Vector2" then return end
	local d = p / scale.Scale
	Sfx.collect()
	Motion.floater(canvas, d, "+" .. (if value then EN.short(value) else "1"), if cur == "goldenPopcorn" then "ffd84a" else "fff1a8", 26)
	task.delay(0.18, function() flyFrom(cur, d, if cur == "goldenPopcorn" then 3 else 2, 30) end)
end

-- ---------------------------------------------------------------- top-right: COMPANIONS [TAB], AUTO, area rail
local companions, autoKey
local companionsOpen = false   -- Birb: the list drops down on [TAB]
local COMPANION_ROWS = {   -- Figma row name -> window id, unlock window (WINDOW_ISLAND gate)
	{ "row/SPARROW", "sparrow", "sparrow" }, { "row/SEAGULL", "seagull", "seagull" }, { "row/BAMBOO", "redpanda", "redpanda" },
	{ "row/CROW", "crow", "mine" }, { "row/DAVE", "dave", "dave" }, { "row/PARROT", "parrot", "parrot" },
}
local function unlockedWindow(w)
	return state ~= nil and (Defs.WINDOW_ISLAND[w] or 1) <= state.island
end
local reflow   -- forward
local function layoutCompanions()
	if not companions then return end
	local y = 58 + SP.GAP / SP.HUD
	for _, r in COMPANION_ROWS do
		local row = companions.node:FindFirstChild(r[1])
		if row then
			local show = companionsOpen and unlockedWindow(r[3])
			row.Visible = show
			if show then row.Position = UDim2.fromOffset(0, y); y += 52 + SP.GAP / SP.HUD end
		end
	end
	-- always shown like Birb; dimmed (locked) until the first companion joins
	local locked = state ~= nil and not unlockedWindow("sparrow")
	local shade = companions.node:FindFirstChild("locked shade", true)
	if shade then shade.Visible = locked end
	-- the dropdown covers the AUTO slot (Birb): AUTO hides while the list is open
	if autoKey then autoKey.root.Visible = not companionsOpen end
end
local function toggleCompanions()
	companionsOpen = not companionsOpen
	layoutCompanions()
	if reflow then reflow(false) end
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

local function buildCompanions()
	local g = group("companions", Vector2.new(300, 420), SP.HUD)
	companions = Render.component(S.companions, "hud/companions (open)", g)
	companions.on("header key", function()
		if state and not unlockedWindow("sparrow") then
			Sfx.deny(); Hud.toast("Companions join as you progress (Sparrow at the Garden)", "info", "sparrow")
			return
		end
		toggleCompanions()
	end)
	do
		local face = companions.node:FindFirstChild("header key") and companions.node:FindFirstChild("header key"):FindFirstChild("face")
		if face then
			local sh = Render.new("Frame", { Name = "locked shade", BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("0b0c10"), BackgroundTransparency = 0.45,
				Size = UDim2.fromScale(1, 1), ZIndex = 900, Visible = false }, face)
			Render.new("UICorner", { CornerRadius = UDim.new(0, 2.5) }, sh)
		end
	end
	for _, r in COMPANION_ROWS do
		local row = companions.node:FindFirstChild(r[1])
		if row then
			button(row, function() Sfx.rowSelect(); openFrom(r[2], row) end, "row")
		end
	end
	g.ZIndex = 8   -- the dropdown overlays the AUTO slot and the rail
	group("auto", Vector2.new(196, 66), SP.HUD)
end
-- context AUTO under COMPANIONS: the area's variant (fishing / mine / expedition / forest), the plain one elsewhere
local AUTO_AREA = { bridge = "fish", mine = "mine", expedition = "expedition", forest = "forest" }
local function buildAuto(kind, st)
	local name = "hud/auto/" .. kind .. " " .. st
	if not S.auto.C[name] then name = "hud/auto/" .. kind .. (if st == "locked" then " locked" else " on") end
	if autoKey and autoKey.name == name then return end
	if autoKey then autoKey.root:Destroy(); autoKey = nil end
	if not S.auto.C[name] then return end
	local ui = Render.component(S.auto, name, groups.auto)
	ui.name = name
	ui.on("key", onAuto)
	autoKey = ui
	autoKey.root.Visible = not companionsOpen
end

-- area rail (our addition): docked under COMPANIONS / AUTO on the sidebar's edge; open = coloured key, current =
-- popped out, locked = grey + lock; click = travel
local RAIL = { { "PARK", "park" }, { "GARDEN", "garden" }, { "FISHING", "bridge" }, { "FOREST", "forest" }, { "MINE", "mine" },
	{ "DESERT", "desert" }, { "EXPEDITION", "expedition" }, { "ECHO", "echo" } }
local RAIL_BOOK = { park = "park (active)", garden = "garden", bridge = "fishing", forest = "forest", mine = "mine", desert = "desert", expedition = "expedition", echo = "echo" }
local RAIL_ICON = { park = "egg", garden = "seed", bridge = "rod_simple", forest = "nest", mine = "crow", desert = "egg_golden", expedition = "parrot", echo = "echo" }
local rail, railSlots, railActive, railArea = nil, {}, nil, nil
local lockedLook, openLook = nil, nil
local function areaColours(area)
	local bm = S.tiles.C["hud/bookmark/" .. (RAIL_BOOK[area] or "")]
	if not bm then return nil end
	local face, lip = Render.findNode(bm, "body"), Render.findNode(bm, "lip")
	return { face = face and face.f and S.tiles.P[face.f][1], lip = lip and lip.f and S.tiles.P[lip.f][1] }
end
local function iconOf(face)
	if not face then return nil end
	for _, c in face:GetChildren() do if c:IsA("ImageLabel") and c.Name:sub(1, 4) == "ico/" then return c end end
	return nil
end
local function slotLook(slot, look, area)
	local face, lip = slot:FindFirstChild("face"), slot:FindFirstChild("lip")
	local ico = iconOf(face)
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
-- arrow destinations that are rooms / stations open their window instead of hopping
local ROOM = { aquarium = "AQUARIUM", market = "FISH MARKET", treasure = "TREASURE ROOM", trees = "SUNFLOWER TREE", sacrifice = "SACRIFICE ROOM", evolve = "THE MONSTER" }
local function travelTo(id, fromInst)
	if ROOM[id] then
		if fromInst then openFrom(id, fromInst) else WM.open(id) end
		return
	end
	local isl = World.byId[id]
	if not isl then return end
	if not World.isOpen(isl) then
		Sfx.deny()
		local goal = "keep going"
		for _, x in Defs.ISLANDS do if x.id == id then goal = x.goal end end
		Hud.toast("Locked: " .. goal, "error", "map")
		return
	end
	plr.PlayerGui:SetAttribute("PeckwoodTP", id .. "#" .. os.clock())
end
Hud.travelTo = travelTo
local function setTopLeft(inst, x, y, animate)   -- keys are centre-anchored
	local p = UDim2.fromOffset(x + inst.AnchorPoint.X * inst.Size.X.Offset, y + inst.AnchorPoint.Y * inst.Size.Y.Offset)
	if animate and not Kit.reduced() then TweenService:Create(inst, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = p }):Play()
	else inst.Position = p end
end
local function buildRail()
	local g = group("rail", Vector2.new(100, 616), SP.RAIL)
	rail = Render.component(S.tiles, "hud/area rail", g)
	local face = rail.root:FindFirstChild("rail face", true)
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
	for _, d in fishing.node:FindFirstChild("face"):GetChildren() do
		if d:IsA("ImageLabel") then d.Image = FKit.icon("rod_simple") end
	end
	railActive = rail.node:FindFirstChild("slot/FISHING (active)")
	for _, r in RAIL do
		local slot = face:FindFirstChild("slot/" .. r[1]) or face:FindFirstChild("slot/" .. r[1] .. " (locked)") or (r[1] == "FISHING" and fishing.node)
		if slot then
			if not slot:FindFirstChild("ico/lock") then
				local L = FKit.layout()
				local lk = FKit.build(L, FKit.ICOn("lock", 22, 50, -5, L), slot)
				lk.root.Name = "ico/lock"; lk.root.Position = UDim2.fromOffset(50, -5); lk.root.Visible = false
			end
			railSlots[r[2]] = slot
			local hit = slot:FindFirstChild("hit") or button(slot, function() end)
			hit.Activated:Connect(function() travelTo(r[2], slot) end)
		end
	end
	local ah = railActive and railActive:FindFirstChild("hit")
	local CONTEXT_WIN = { bridge = "fishing", mine = "mine", expedition = "expedition", echo = "trees", desert = "trees", forest = "nest" }
	if ah then ah.Activated:Connect(function() if railArea then openFrom(CONTEXT_WIN[railArea] or "profile", railActive) end end) end
end
local function updateRail(area)
	if not rail then return end
	for _, r in RAIL do
		local slot = railSlots[r[2]]
		if slot then
			local isl = World.byId[r[2]]
			local look = if isl ~= nil and World.isOpen(isl) then "open" else "locked"
			if slot:GetAttribute("look") ~= look then slotLook(slot, look, r[2]) end
			slot.Visible = r[2] ~= area
		end
	end
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
			-- the active slot slides out with a small overshoot
			setTopLeft(railActive, 0, 4 + 76 * (idx - 1) + 3 - 4, true)
		end
	end
end

-- ---------------------------------------------------------------- top-centre: context bar, up arrow, toasts
local context, contextKind = nil, nil
local AREA_CONTEXT = { bridge = "fishing", mine = "mine", expedition = "expedition", echo = "echo", desert = "desert", forest = "nest" }
local CONTEXT_WINDOW = { fishing = "fishing", mine = "mine", expedition = "expedition", echo = "trees", desert = "trees", nest = "nest" }
local CONTEXT_TAB = { echo = "ARCHIVIST", desert = "DESERT" }
local function buildContext(kind)
	if context then context.root:Destroy(); context = nil end
	contextKind = kind
	if not kind then return end
	context = Render.component(S.context, "hud/context/" .. kind, groups.context)
	inert(context)
	button(context.root, function() openFrom(CONTEXT_WINDOW[kind], context.root, CONTEXT_TAB[kind]) end)
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
		if w ~= context.fill.Size.X.Offset then
			TweenService:Create(context.fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(w, context.fill.Size.Y.Offset) }):Play()
		end
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
local lastLevel = {}
local function setLevel(kind, lv)
	setT(context.root, "level", tostring(lv))
	if lastLevel[kind] and lv > lastLevel[kind] then
		-- level up: badge punch 1.15 + sparkles + the bar flashes white
		local badge = context.root:FindFirstChild("level badge", true)
		if badge then Kit.pop(badge, 1.15); Motion.burst(canvas, centreOf(badge), 6, 22) end
		if context.fill then Motion.shimmer(context.fill.Parent) end
		Sfx.levelUp()
	end
	lastLevel[kind] = lv
end
local function updateContext(area)
	local kind = AREA_CONTEXT[area]
	if kind ~= contextKind then buildContext(kind) end
	if not (context and state) then return end
	local SD = SampleData.context[kind]
	if kind == "fishing" then
		setContextBar(SD.xp / SD.need, fmt(SD.xp) .. " / " .. fmt(SD.need) .. " XP")
		setLevel(kind, SD.level)
		local rod = Defs.ROD_BY_ID[state.fish.rod]
		setInfo(1, commas(state.stats.fishCaught), " caught")
		setInfo(2, tostring(rod and rod.monetaPerCatch or 1), " per catch")
	elseif kind == "mine" then
		local area1 = (state.crow.area or 0) + 1
		setT(context.root, "title", "AREA " .. area1)
		setLevel(kind, area1)
		setContextBar(SD.xp / SD.need, fmt(SD.xp) .. " / " .. fmt(SD.need) .. " " .. SD.unit)
	elseif kind == "expedition" then
		setLevel(kind, state.parrot.level)
		setContextBar(SD.xp / SD.need, fmt(SD.xp) .. " / " .. fmt(SD.need) .. " XP")
	elseif kind == "echo" then
		setContextBar(SD.count / SD.cap, SD.count .. " / " .. SD.cap .. " on the field")
	elseif kind == "desert" then
		setContextBar(Hud.kernelCount / math.max(1, derived.cap), Hud.kernelCount .. " / " .. derived.cap .. " on the field")
		setInfo(1, string.format("%.1f%%", (derived.goldenChance or 0) * 100), " chance")
	elseif kind == "nest" then
		local tier = (state.nest.tier or 0) + 1
		local T = Defs.NEST_TIERS[tier]
		setT(context.root, "title", "NEST " .. (({ "I", "II", "III", "IV", "V" })[tier] or tostring(tier)))
		setLevel(kind, tier)
		if T and T.next then
			local tw = EN.toNumber(state.twigs)
			setContextBar(tw / T.next, fmt(tw) .. " / " .. fmt(T.next) .. " twigs")
		end
	end
end

-- toasts: Figma hud/toast/<reward|unlock|error|info>. They stack (newest on top, the rest spring down), carry a thin
-- auto-dismiss line, hold 2.5 s, and a click dismisses them. At most 3 at once.
local toasts = {}
local TOAST_H = 76
local function restack()
	local y = 0
	for _, t in toasts do
		TweenService:Create(t.ui.root, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, y) }):Play()
		y += TOAST_H + SP.GAP / SP.TOAST
	end
end
local function dismiss(t)
	local i = table.find(toasts, t)
	if not i then return end
	table.remove(toasts, i)
	local root = t.ui.root
	local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(root, ti, { Position = root.Position - UDim2.fromOffset(0, 20) }):Play()
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then TweenService:Create(d, ti, { TextTransparency = 1 }):Play()
		elseif d:IsA("ImageLabel") then TweenService:Create(d, ti, { ImageTransparency = 1 }):Play()
		elseif d:IsA("Frame") then TweenService:Create(d, ti, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then TweenService:Create(d, ti, { Transparency = 1 }):Play() end
	end
	task.delay(0.31, function() root:Destroy() end)
	restack()
end
local function showToast(msg, tone, icon)
	local name = "hud/toast/" .. (if S.prompts.C["hud/toast/" .. (tone or "info")] then tone else "info")
	local ui = Render.component(S.prompts, name, groups.toast)
	inert(ui)
	local root = ui.root
	local body = ui.node:FindFirstChild("body")
	local lbl = root:FindFirstChild("label", true)
	if lbl then
		Render.setText(lbl, msg)
		local need = lbl.Position.X.Offset + Render.textWidth(lbl) + 24
		if body and need > body.Size.X.Offset then
			local dw = need - body.Size.X.Offset
			root.Size += UDim2.fromOffset(dw, 0); ui.node.Size += UDim2.fromOffset(dw, 0); body.Size += UDim2.fromOffset(dw, 0)
			lbl.Size += UDim2.fromOffset(dw, 0)
			for _, d in body:GetChildren() do
				if d:IsA("GuiObject") and (d.Name == "top highlight" or d.Name == "gloss cap" or d.Name == "fx/edge light") then d.Size += UDim2.fromOffset(dw, 0) end
			end
		end
	end
	if icon then
		for _, d in root:GetDescendants() do
			if d:IsA("ImageLabel") and (d.Name:sub(1, 4) == "ico/" or d.Name == "drop") then d.Image = FKit.icon(icon) end
		end
	end
	-- auto-dismiss line along the bottom edge of the plate
	local line
	if body then
		line = Render.new("Frame", { Name = "dismiss line", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45,
			Position = UDim2.new(0, 6, 1, -6), Size = UDim2.new(1, -12, 0, 2), ZIndex = 60 }, body)
	end
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, -30)
	local t = { ui = ui }
	table.insert(toasts, 1, t)
	while #toasts > 3 do dismiss(toasts[#toasts]) end
	restack()
	button(root, function() dismiss(t) end)
	if tone == "unlock" then Sfx.unlock() elseif tone == "error" then Sfx.error() else Sfx.toast() end
	if line then TweenService:Create(line, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play() end
	task.delay(2.5, function() dismiss(t) end)
end
Hud.toast = showToast

-- big moments (area unlocked, evolution, molt): a centred banner in the game area slides in, holds, slides out
local function bigMoment(title, tone, icon)
	local g = groups.moment
	local ui = Render.component(S.prompts, "hud/toast/" .. (tone or "unlock"), g)
	inert(ui)
	local lbl = ui.root:FindFirstChild("label", true)
	if lbl then
		Render.setText(lbl, title)
		local body = ui.node:FindFirstChild("body")
		local need = lbl.Position.X.Offset + Render.textWidth(lbl) + 32
		if body and need > body.Size.X.Offset then
			local dw = need - body.Size.X.Offset
			ui.root.Size += UDim2.fromOffset(dw, 0); ui.node.Size += UDim2.fromOffset(dw, 0); body.Size += UDim2.fromOffset(dw, 0); lbl.Size += UDim2.fromOffset(dw, 0)
			for _, d in body:GetChildren() do
				if d:IsA("GuiObject") and (d.Name == "top highlight" or d.Name == "gloss cap" or d.Name == "fx/edge light") then d.Size += UDim2.fromOffset(dw, 0) end
			end
		end
	end
	if icon then
		for _, d in ui.root:GetDescendants() do
			if d:IsA("ImageLabel") and (d.Name:sub(1, 4) == "ico/" or d.Name == "drop") then d.Image = FKit.icon(icon) end
		end
	end
	ui.root.AnchorPoint = Vector2.new(0.5, 0.5)
	ui.root.Position = UDim2.new(0.5, 0, 0.5, -140)
	TweenService:Create(ui.root, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
	Motion.burst(g, Vector2.new(g.Size.X.Offset / 2, g.Size.Y.Offset / 2), 8, 30)
	task.delay(1.9, function()
		local tw = TweenService:Create(ui.root, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0.5, -160) })
		tw:Play()
		tw.Completed:Once(function() ui.root:Destroy() end)
	end)
end
Hud.bigMoment = bigMoment

-- ---------------------------------------------------------------- bottom: objective, hotbar, tiles
local objective, unlockKey, hotbar
local function buildObjective()
	objective = Render.component(S.prompts, "hud/objective", groups.objective)
	inert(objective)
	local goalL = objective.root:FindFirstChild("goal", true)
	if goalL then Render.fit(goalL, 12) end
	button(objective.root, function() openFrom("objectives", objective.root) end)
	-- UNLOCK key for paid gates (Evolve's 100M eggs): kit gold key, takes the hotbar row above the objective
	local L = FKit.layout()
	local k = FKit.BTNn(L, "btn/unlock", 0, 0, 280, 72, FKit.PAL.gold, "UNLOCK", { icon = "popcorn", size = 24 })
	unlockKey = FKit.build(L, k, groups.hotbar)
	unlockKey.root.Visible = false
	unlockKey.on("btn/unlock", function(inst) act("unlock", nil, nil, inst) end)
end
local HOTBAR = { bridge = "fishing", mine = "mine", expedition = "expedition" }
local function buildHotbar(kind, variant)
	if hotbar and hotbar.kind == kind and hotbar.variant == variant then return end
	if hotbar then hotbar.root:Destroy(); hotbar = nil end
	if not kind then return end
	local ui = Render.component(S.hotbar, "hud/hotbar/" .. variant, groups.hotbar)
	ui.kind, ui.variant = kind, variant
	if kind == "fishing" then
		ui.on("cast key", function() act("fish", "go") end)
		for _, d in ui.node:GetChildren() do
			if d.Name:sub(1, 5) == "slot/" then button(d, function() openFrom("fishing", d, "EQUIPMENT") end) end
		end
	elseif kind == "mine" then
		ui.on("challenge key", function(inst) openFrom("mine", inst, "AREAS") end)
	elseif kind == "expedition" then
		ui.on("reset floor key", function() act("expedition") end)
		for _, d in ui.node:GetChildren() do
			if d.Name:sub(1, 5) == "slot/" then button(d, function() openFrom("parrot", d, "EQUIPMENT") end) end
		end
	end
	hotbar = ui
	if reflow then reflow(false) end
end
local TILE_ORDER = { "map", "teleport", "fish", "profile", "shop", "settings", "auto", "pets" }
local tiles = {}
local TILE_ACTION = {
	map = function()
		local on = not plr.PlayerGui:GetAttribute("PeckwoodMap")
		plr.PlayerGui:SetAttribute("PeckwoodMap", on)
		if on then Hud.toast("Map: every open area. Tap MAP again to return", "info", "map") end
	end,
	teleport = function(inst) openFrom("teleport", inst) end,
	fish = function(inst) openFrom("fishing", inst) end,
	profile = function(inst) openFrom("profile", inst) end,
	shop = function() WM.close(); RobuxShop.toggle() end,
	settings = function(inst) openFrom("settings", inst) end,
	auto = onAuto,
	pets = function() toggleCompanions() end,
}
-- the 4x2 tile block at 75 % of the HUD scale (compact, not in your face); 8 px between keys on screen
local TILE_S = 0.6
local TILE_PITCH_X = 104 + Layout.S.GAP / TILE_S
local TILE_PITCH_Y = 111 + Layout.S.GAP / TILE_S
local function buildTiles()
	local g = group("tiles", Vector2.new(TILE_PITCH_X * 3 + 104, TILE_PITCH_Y + 119), TILE_S)
	for i, id in TILE_ORDER do
		local ui = Render.component(S.tiles, "hud/tile/" .. id, g)
		ui.root.Position = UDim2.fromOffset(((i - 1) % 4) * TILE_PITCH_X, math.floor((i - 1) / 4) * TILE_PITCH_Y)
		ui.on("hud/tile/" .. id, function(inst) TILE_ACTION[id](inst) end)
		tiles[id] = ui
	end
	-- Fast Travel pops up above its tile
	WM.anchors.teleport = function()
		local p = centreOf(tiles.teleport.root)
		local top = (tiles.teleport.root.AbsolutePosition.Y) / scale.Scale
		return Vector2.new(p.X, top)
	end
end

-- travel arrows (Birb map arrows): left / right along the chain, up / down to rooms
local TRAVEL = {
	park = { left = "forest", right = "garden", up = "desert" }, garden = { left = "park", right = "bridge", up = "trees" },
	bridge = { left = "garden", right = "castle", down = "aquarium" }, castle = { left = "bridge", up = "evolve" },
	forest = { left = "expedition", right = "park" }, expedition = { left = "sacrifice", right = "forest", down = "mine" },
	mine = { up = "expedition", down = "treasure" }, desert = { left = "forest", right = "garden", down = "park" }, echo = { right = "garden" },
}
local arrows = {}
local function destName(id)
	if ROOM[id] then return ROOM[id] end
	local isl = World.byId[id]
	return if isl then string.upper(isl.name) else string.upper(id)
end
local function buildArrows()
	for _, dir in { "left", "right", "up", "down" } do
		local g = group("travel " .. dir, Vector2.new(240, 70), SP.HUD)
		local open = Render.component(S.travel, "hud/travel/" .. dir, g)
		local lockedName = "hud/travel/" .. dir .. " (locked)"
		local locked = if S.travel.C[lockedName] then Render.component(S.travel, lockedName, g) else nil
		for _, ui in { open, locked } do
			if ui then
				ui.root.Visible = false
				-- right / up / down arrows hug their group's anchor edge
				if dir == "right" or dir == "down" then ui.root.AnchorPoint = Vector2.new(1, 0); ui.root.Position = UDim2.new(1, 0, 0, 0)
				elseif dir ~= "left" then ui.root.AnchorPoint = Vector2.new(0.5, 0); ui.root.Position = UDim2.new(0.5, 0, 0, 0) end
				ui.onAny(function(_, inst) if arrows[dir].target then travelTo(arrows[dir].target, inst) end end)
			end
		end
		arrows[dir] = { open = open, locked = locked }
	end
end
local function setArrowLabel(ui, text)
	if not ui then return end
	local face = ui.node:FindFirstChild("face")
	if not face then return end
	local glyph
	for _, c in face:GetChildren() do if string.sub(c.Name, 1, 6) == "glyph/" then glyph = c end end
	for _, l in Render.childTexts(face) do
		if not l:GetAttribute("fitted") then
			-- the label owns the face between its start and the chevron (or the face edge): never past it
			l:SetAttribute("fitted", true)
			local x = l.Position.X.Offset
			local right = if glyph and glyph.Position.X.Offset > x then glyph.Position.X.Offset - 6 else face.Size.X.Offset - 8
			l.Size = UDim2.fromOffset(math.max(20, right - x), l.Size.Y.Offset)
			local sh = Render.SHADOW[l]
			if sh then sh.Size = l.Size end
			Render.fit(l, 10)
		end
		Render.setText(l, text)
	end
end
-- short requirement copy for a locked destination (the chip has room for ~12 characters)
local SHORT_REQ = { garden = "MOLT ONCE", castle = "100M EGGS", bridge = "EVOLVE ONCE", forest = "EVOLUTION 2", mine = "EVOLUTION 3",
	desert = "EVOLUTION 4", expedition = "STURDY NEST", echo = "EVOLUTION 5" }
local function updateArrows(area)
	local t = TRAVEL[area] or {}
	for dir, a in arrows do
		local id = t[dir]
		local wasTarget = a.target
		a.target = id
		local open = id ~= nil and (ROOM[id] ~= nil or (World.byId[id] ~= nil and World.isOpen(World.byId[id])))
		a.open.root.Visible = id ~= nil and open
		if a.locked then a.locked.root.Visible = id ~= nil and not open end
		if id then
			setArrowLabel(a.open, destName(id))
			if a.locked and not open then
				setArrowLabel(a.locked, SHORT_REQ[id] or "LOCKED")
			end
			-- an arrow whose destination just unlocked pulses once
			if open and a.wasLocked and wasTarget == id then Kit.pop(a.open.root, 1.12) end
		end
		a.wasLocked = id ~= nil and not open
	end
	if reflow then reflow(false) end
end

-- [E] prompt (no proximity system yet): Hud.prompt("aquarium") shows one, Hud.prompt() hides; the E key bobs 2 px
local promptUi, promptBob
function Hud.prompt(kind, onUse)
	if promptBob then promptBob:Cancel(); promptBob = nil end
	if promptUi then promptUi.root:Destroy(); promptUi = nil end
	if not kind then return end
	promptUi = Render.component(S.prompts, "hud/prompt/" .. kind, groups.prompt)
	promptUi.root.AnchorPoint = Vector2.new(0.5, 0); promptUi.root.Position = UDim2.new(0.5, 0, 0, 0)
	promptUi.on("E key", function() if onUse then onUse() end end)
	local ek = promptUi.root:FindFirstChild("E key", true)
	if ek and not Kit.reduced() then
		promptBob = TweenService:Create(ek, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = ek.Position - UDim2.fromOffset(0, 2) })
		promptBob:Play()
	end
end

-- ---------------------------------------------------------------- notification badges (max 2 visible)
-- a red count bubble on a sidebar tab / tile when something new or affordable appears; pops in with overshoot and
-- bumps when the count rises. Priority: MOLT > FISH > EGGS > SEEDS, only the top 2 show.
local badges = {}
local BADGE_PRIORITY = { "molt", "fish", "eggs", "seeds" }
local function badgeOn(key, host, text)
	local b = badges[key]
	if b and b.host ~= host then if b.frame then b.frame:Destroy() end; b = nil; badges[key] = nil end
	if not b then
		-- inside the host's top-right corner (tab bars clip: zero clipping)
		local f = Render.new("Frame", { Name = "badge", BackgroundColor3 = Color3.fromHex("e8344f"), BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(28, 22), ZIndex = 1000, AutomaticSize = Enum.AutomaticSize.X }, host)
		Render.new("UICorner", { CornerRadius = UDim.new(0, 4) }, f)
		Render.new("UIStroke", { Thickness = 2, Color = Render.INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
		Render.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, f)
		local l = Render.new("TextLabel", { Name = "count", BackgroundTransparency = 1, FontFace = Render.FONT, TextSize = 15, TextColor3 = Color3.new(1, 1, 1),
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), Text = text, ZIndex = 1001 }, f)
		Render.new("UIStroke", { Thickness = 1.4, Color = Render.INK, LineJoinMode = Enum.LineJoinMode.Round }, l)
		b = { frame = f, label = l, host = host, text = text }
		badges[key] = b
		Kit.pop(f, 1.15)
		return
	end
	if b.text ~= text then
		b.text = text
		b.label.Text = text
		Kit.pop(b.frame, 1.1)
	end
end
local function badgeOff(key)
	local b = badges[key]
	if b then if b.frame then b.frame:Destroy() end; badges[key] = nil end
end
local seenFish = nil
local sidebarView = nil
local DRAWER_TAB = { eggs = "tab/EGGS", molt = "tab/MOLT", seeds = "tab/SEEDS" }
local DRAWER_VIEW = { eggs = "Shop_Eggs", molt = "Shop_Molt", seeds = "Shop_Seeds" }
local BADGE_IDS = { eggs = { "p_value", "p_speed", "p_capacity", "p_move_speed" }, seeds = { "s_more_popcorn", "s_more_feathers", "s_more_seeds" } }
local function affordableCount(ids)
	local n = 0
	for _, id in ids do
		local L = Defs.level(state, id)
		if L < Defs.maxLevel(state, id) and EN.meeq(state[Defs.UP[id].cur], Defs.cost(state, id, L)) then n += 1 end
	end
	return n
end
local function updateBadges()
	if not (state and derived) then return end
	local want = {}
	if derived.plumeGain and EN.meeq(derived.plumeGain, 1) and sidebarView ~= "Shop_Molt" and state.island >= 2 then want.molt = "+" .. fmt(derived.plumeGain) end
	local disc = Binders.fish and Binders.fish.disc
	if disc then
		local n = 0; for _ in disc do n += 1 end
		if seenFish == nil then seenFish = n end
		if WM.isOpen("fishing") then seenFish = n end
		if n > seenFish then want.fish = tostring(n - seenFish) end
	end
	for _, k in { "eggs", "seeds" } do
		if sidebarView ~= DRAWER_VIEW[k] and not (k == "seeds" and state.island < 3) then
			local c = affordableCount(BADGE_IDS[k])
			if c > 0 then want[k] = tostring(c) end
		end
	end
	local shown = 0
	local sb = WM.built.shop
	local v = sb and sb.current and sb.variants[sb.current]
	for _, key in BADGE_PRIORITY do
		local host
		if key == "fish" then host = tiles.fish and tiles.fish.node
		elseif v then host = v.ui.root:FindFirstChild(DRAWER_TAB[key], true) end
		if want[key] and host and shown < 2 then
			badgeOn(key, host, want[key]); shown += 1
		else
			badgeOff(key)
		end
	end
end

-- ---------------------------------------------------------------- layout: everything anchored in game-area terms
local devPanel
function reflow(animate)
	if not canvas then return end
	local H, top, edge = Layout.H, Layout.TOP, SP.EDGE
	local colR = Layout.columnRight()
	local cx = Layout.gameCentre()
	-- top-left stack: banner, wallet (visual edges on EDGE, GAP between)
	local bx0, by0, _, by1 = vb(S.prompts, "hud/banner/the bridge", SP.HUD)
	place("banner", Vector2.new(0, 0), edge - bx0, top - by0, false)
	place("wallet", Vector2.new(0, 0), edge, top + (by1 - by0) + SP.GAP, false)
	-- top-right column (right edge = the rail's): COMPANIONS, AUTO, rail
	local railL = colR - 100 * SP.RAIL
	place("rail", Vector2.new(0, 0), railL, top, animate)
	local colR2 = railL - SP.GAP2   -- COMPANIONS / AUTO column, left of the rail
	local _, _, cx1c = vb(S.companions, "hud/companions (open)", SP.HUD)
	place("companions", Vector2.new(0, 0), colR2 - cx1c, top, animate)
	local compH = 58 * SP.HUD
	local _, _, ax1 = vb(S.auto, "hud/auto/fish on", SP.HUD)
	place("auto", Vector2.new(0, 0), colR2 - ax1, top + compH + SP.GAP, animate)
	-- bottom-right tile block (Birb's icon row)
	local tilesW, tilesH = (TILE_PITCH_X * 3 + 104) * TILE_S, (TILE_PITCH_Y + 111) * TILE_S
	place("tiles", Vector2.new(0, 0), colR - tilesW, H - edge - tilesH, animate)
	local tilesLeft = colR - tilesW
	-- bottom-centre: objective at the bottom, hotbar (or UNLOCK) above it; centred in the game area, nudged left
	-- so it never meets the tile block
	local objW, objH = 680 * SP.HUD, 58 * SP.HUD
	local bcx = math.max(edge + objW / 2, math.min(cx, tilesLeft - SP.GAP2 - objW / 2))
	place("objective", Vector2.new(0.5, 0), bcx, H - edge - objH, animate)
	local hbW = if hotbar then hotbar.root.Size.X.Offset * SP.HUD else 0
	local hbH = if hotbar then (hotbar.node.Size.Y.Offset - 7) * SP.HUD else 72 * SP.HUD
	local hbY = H - edge - objH - SP.GAP - hbH
	place("hotbar", Vector2.new(0.5, 0), bcx, hbY, animate)
	if hotbar then hotbar.root.AnchorPoint = Vector2.new(0.5, 0); hotbar.root.Position = UDim2.new(0.5, 0, 0, 0) end
	if unlockKey then unlockKey.root.AnchorPoint = Vector2.new(0.5, 0); unlockKey.root.Position = UDim2.new(0.5, 0, 0, 0) end
	-- down arrow: left of the hotbar, bottoms aligned
	place("travel down", Vector2.new(1, 0), bcx - hbW / 2 - SP.GAP2, hbY + hbH - 62 * SP.HUD, animate)
	-- top-centre: context bar, up arrow under it, toasts under that
	local ctxH = (if context then 98 else 0) * SP.CONTEXT
	place("context", Vector2.new(0.5, 0), cx, top, animate)
	local upY = top + ctxH + (if ctxH > 0 then SP.GAP2 else 0)
	place("travel up", Vector2.new(0.5, 0), cx, upY, animate)
	local upH = if arrows.up and (arrows.up.open.root.Visible or (arrows.up.locked and arrows.up.locked.root.Visible)) then 62 * SP.HUD + SP.GAP2 else 0
	place("toast", Vector2.new(0.5, 0), cx, upY + upH, animate)
	-- mid-left / mid-right travel arrows (the right one stays left of the rail)
	place("travel left", Vector2.new(0, 0.5), edge, H / 2, animate)
	place("travel right", Vector2.new(1, 0.5), railL - SP.GAP2, H / 2, animate)
	-- [E] prompt and big moments: centre of the game area
	place("prompt", Vector2.new(0.5, 0), cx, Layout.snap(H * 0.6), animate)
	place("moment", Vector2.new(0.5, 0.5), cx, H * 0.4, animate)
	if devPanel then
		devPanel.AnchorPoint = Vector2.new(0.5, 0)
		devPanel.Position = UDim2.fromOffset(cx, SP.GAP)
	end
	Hud.collapsed = not Layout.sidebarOpen
	Hud.dock.Visible = Layout.sidebarOpen
	if RobuxShop.reflow then RobuxShop.reflow(Layout.gameRight()) end
end

local function layoutCanvas()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.max(0.35, vp.Y / 1080)
	scale.Scale = s
	canvas.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
	Layout.setInset(GuiService:GetGuiInset().Y / s)
	Layout.setCanvas(vp.X / s, vp.Y / s)
	reflow(false)
end

-- ---------------------------------------------------------------- state
local lastIsland, lastArea = 0, nil
local function currentArea()
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	return if hrp then World.nearest(hrp.Position.X / 4 + 20, hrp.Position.Z / 4 + 15) else World.byId.park
end
function Hud.currentAreaId()
	local here = currentArea()
	return here and (here.area or here.id) or "park"
end
function Hud.setState(s, d)
	state, derived = s, d
	WM.update(s, d)
	RobuxShop.setDerived(d)
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
	for cur in chips do if s[cur] then setChip(cur, s[cur]) end end
	if chips.popcorn.rate then Render.setText(chips.popcorn.rate, "+" .. fmt(d.popPerSec) .. "/s") end
	layoutWallet()
	if objective then
		setT(objective.root, "goal", d.nextGoal)
		local frac = 0
		if d.nextCost then for cur, n in d.nextCost do frac = math.min(1, EN.toNumber(s[cur]) / n) end end
		local fill = objective.root:FindFirstChild("fill", true)
		if fill then TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(math.floor(600 * frac + 0.5), fill.Size.Y.Offset) }):Play() end
		unlockKey.root.Visible = d.nextCost ~= nil and not hotbar
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
	buildAuto(AUTO_AREA[area] or "fish", if not d.autoAllowed then "locked" elseif s.auto then "on" else "off")
	if autoKey then
		local lbl = autoKey.root:FindFirstChild("label", true)
		if lbl then
			if not d.autoAllowed then
				Render.setText(lbl, if AUTO_AREA[area] == "fish" then "AUTO " .. SampleData.autoFish.have .. "/" .. SampleData.autoFish.need else "AUTO")
			elseif not AUTO_AREA[area] then
				Render.setText(lbl, if s.auto then "AUTO: ON" else "AUTO: OFF")
			end
		end
		if not AUTO_AREA[area] then
			for _, dd in autoKey.root:GetDescendants() do
				if dd:IsA("ImageLabel") and (dd.Name:sub(1, 4) == "ico/" or dd.Name == "drop") then dd.Image = FKit.icon("auto") end
			end
		end
	end
	updateRail(area)
	updateArrows(area)
	layoutCompanions()
	if companions then
		local L = { ["row/SPARROW"] = s.sparrow.level, ["row/SEAGULL"] = s.seagull.level, ["row/BAMBOO"] = SampleData.companions.redpanda,
			["row/CROW"] = s.crow.level, ["row/DAVE"] = s.dave.level, ["row/PARROT"] = s.parrot.level }
		for row, lv in L do
			local r = companions.node:FindFirstChild(row)
			local lvl = r and r:FindFirstChild("level")
			if lvl then for _, l in Render.childTexts(lvl) do Render.setText(l, tostring(lv)) end end
		end
	end
	if s.island > lastIsland and lastIsland > 0 then
		for _, r in RAIL do local slot = railSlots[r[2]]; if slot then Kit.pop(slot, 1.2) end end
	end
	lastIsland = s.island
	lastArea = area
	updateBadges()
end

-- ---------------------------------------------------------------- toasts from the server
function Hud.onToast(kind, a, b)
	if kind == "bought" then
		local dd = Defs.UP[a]
		if dd then local ch = chips[dd.cur]; if ch and ch.value then Kit.pop(ch.value, 1.05) end end
		local lb = Hud.lastBtn
		local hero = typeof(lb) == "Instance" and Motion.registry[lb] and Motion.registry[lb].kind == "hero"
		if hero then Sfx.purchaseBig(); Motion.settle(lb) else Sfx.buy() end
		if typeof(lb) == "Instance" and dd then Hud.flyTo(dd.cur, lb, 5) end
		Binders.bought(a)
	elseif kind == "poor" then
		Sfx.deny()
		local lb = Hud.lastBtn
		local inst = if typeof(lb) == "Instance" then lb elseif type(lb) == "table" then lb.root else nil
		if inst then
			Kit.shake(inst, 6, 0.28)
			for _, l in inst:GetDescendants() do if l:IsA("TextLabel") and not l.Name:find("drop") then Motion.flashText(l) end end
		end
		local dd = Defs.UP[a]
		if dd then Hud.wiggle(dd.cur) end
	elseif kind == "molt" then
		Sfx.molt()
		bigMoment("You molted!  +" .. a .. " Plumes", "reward", "plume")
		local fl = Render.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("b06cff"), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 90 }, canvas)
		TweenService:Create(fl, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function() fl:Destroy() end)
		Binders.molted()
		if b then showToast("The Garden opens", "unlock", "seed") end
	elseif kind == "island" then
		Sfx.unlock()
		bigMoment(b .. " opens!", "unlock", "map")
	elseif kind == "evolve" then
		Sfx.evolve()
		bigMoment("Evolution " .. a .. "!", "reward", "monster")
		local fl = Render.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("ff5a8a"), BackgroundTransparency = 0.3, Size = UDim2.fromScale(1, 1), ZIndex = 90 }, canvas)
		TweenService:Create(fl, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
		task.delay(0.7, function() fl:Destroy() end)
		Binders.evolved()
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
local function buildDev()
	local L = FKit.layout()
	devPanel = Render.new("Frame", { Name = "dev", BackgroundTransparency = 1, Size = UDim2.fromOffset(3 * 160 + 2 * SP.GAP, 52), Visible = false, ZIndex = 20 }, canvas)
	Render.new("UIScale", { Scale = 0.55 }, devPanel)
	local x = 0
	for _, b in { { "REGULAR", "regular", FKit.PAL.green }, { "MAXED", "maxed", FKit.PAL.gold }, { "NEXT AREA", "next", FKit.PAL.violet } } do
		local k = FKit.BTNn(L, "btn/dev " .. b[2], 0, 0, 160, 52, b[3], b[1], { size = 17 })
		local ui = FKit.build(L, k, devPanel)
		ui.root.Position = UDim2.fromOffset(x, 0)
		ui.on("btn/dev " .. b[2], function() act("dev", b[2]) end)
		x += 160 + SP.GAP
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
	WM.screens = Screens
	Screens.init(Hud, WM)
	Binders.install(WM, act, Hud)
	-- groups that only hold transient pieces
	group("context", Vector2.new(560, 106), SP.CONTEXT)
	group("toast", Vector2.new(900, 300), SP.TOAST)
	group("moment", Vector2.new(900, 120), 1.15)
	group("objective", Vector2.new(680, 64), SP.HUD)
	group("hotbar", Vector2.new(700, 180), SP.HUD)
	group("prompt", Vector2.new(600, 62), SP.HUD)
	buildTopLeft(); buildCompanions(); buildRail(); buildObjective(); buildTiles(); buildArrows(); buildDev()
	RobuxShop.init(canvas, function(msg, tone, icon) showToast(msg, if tone == "golden" then "reward" else "info", icon) end, act)
	-- windows: pop out of / shrink back into the HUD element that opened them
	for _, id in { "fishing", "profile", "settings", "teleport", "objectives", "sparrow", "seagull", "redpanda", "crow", "dave", "parrot",
		"mine", "nest", "trees", "expedition", "aquarium", "market", "treasure", "sacrifice", "evolve", "leaderboards", "offline" } do
		WM.sources[id] = function() return sourceOf[id] end
	end
	WM.beforeOpen = function() if RobuxShop.isOpen() then RobuxShop.toggle() end end
	WM.onEscape = function() if RobuxShop.isOpen() then RobuxShop.toggle(); return true end; return false end
	WM.onSidebarView = function(v) sidebarView = v.name; task.defer(updateBadges) end
	WM.init(pg)
	WM.debugHook()
	WM.onChanged = function()
		Hud.collapsed = not Layout.sidebarOpen
		Hud.dock.Visible = Layout.sidebarOpen
	end
	Layout.onChanged(function(animate) reflow(animate) end)
	layoutCanvas()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutCanvas)
	-- keyboard (Birb hints): Q objectives, P profile, Tab companions
	UIS.InputBegan:Connect(function(io, gp)
		if gp then return end
		if io.KeyCode == Enum.KeyCode.Tab then toggleCompanions()
		elseif io.KeyCode == Enum.KeyCode.Q then WM.toggle("objectives")
		elseif io.KeyCode == Enum.KeyCode.P then WM.toggle("profile") end
	end)
	remotes.State.OnClientEvent:Connect(function(s, d)
		local first = state == nil
		Hud.setState(s, d)
		if devPanel then devPanel.Visible = d.devAllowed == true end
		if first then
			-- first open never hitches: pre-build the unlocked windows in spare frames
			local ids = {}
			for _, id in { "fishing", "profile", "settings", "teleport", "objectives", "mine", "nest", "parrot", "sparrow", "seagull", "evolve", "aquarium" } do
				local gate = ({ fishing = "rods", mine = "mine", nest = "nest", parrot = "parrot", sparrow = "sparrow", seagull = "seagull", evolve = "evolve", aquarium = "aquarium" })[id]
				if not gate or (Defs.WINDOW_ISLAND[gate] or 1) <= s.island then table.insert(ids, id) end
			end
			WM.prebuild(ids)
		end
	end)
	remotes.Fish.OnClientEvent:Connect(function(disc, best, have)
		Binders.fish = { disc = disc, best = best, have = have }
		updateBadges()
	end)
	remotes.Toast.OnClientEvent:Connect(Hud.onToast)
	pg:GetAttributeChangedSignal("PeckwoodShop"):Connect(function() RobuxShop.toggle() end)
	pg:GetAttributeChangedSignal("PeckwoodPrompt"):Connect(function()
		local v = pg:GetAttribute("PeckwoodPrompt")
		Hud.prompt(if typeof(v) == "string" and v ~= "" then v else nil)
	end)
	pg:GetAttributeChangedSignal("PeckwoodMoment"):Connect(function()
		local v = pg:GetAttribute("PeckwoodMoment")
		if typeof(v) == "string" and v ~= "" then bigMoment(v, "unlock", "map") end
	end)
end

return Hud
