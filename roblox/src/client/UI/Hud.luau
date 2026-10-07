--!nonstrict
-- Hud: Figma HUD frame 8:271 (1920x1080) - map banner, toast, wallet capsules, objective bar, docked shop window -
-- plus the window menu, the AUTO button (group perk) and the dev save panel (Regular / Maxed / Next island).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GroupService = game:GetService("GroupService")
local Shared = RS:WaitForChild("Peckwood")
local Defs = require(Shared:WaitForChild("Defs"))
local Kit = require(script.Parent.Kit)
local Spec = require(script.Parent.Spec)
local Window = require(script.Parent.Window)
local Windows = require(script.Parent.Windows)
local EN = Defs.EN
local hex = Kit.hex

local Hud = {}
local plr = Players.LocalPlayer

local gui, canvas, scale
local state, derived
local Remotes
local docked = nil          -- id of the window docked on the right
local capsules = {}         -- currency -> { frame, value, rate, icon }
local menuButtons = {}

local function act(kind, a, b, btn)
	Remotes.Action:FireServer(kind, a, b)
	Hud.lastBtn = btn
end

-- ---------------------------------------------------------------- canvas: 1920x1080 design space, scaled to the screen height
local function layout()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.max(0.4, vp.Y / 1080)
	scale.Scale = s
	canvas.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
end

-- ---------------------------------------------------------------- banner (map banner 28,26,330,66)
local banner
local function buildBanner()
	-- island plate: the same 3D key as every button (ink outline, themed face, darker lip, gloss, stripes), not clickable
	local key = Kit.button(canvas, 30, 60, 304, 70, { text = "", stops = Kit.stops(Spec.popcorn.hdr), silent = true, depth = 7 })
	key.root.Active = false; pcall(function() key.root.Interactable = false end)
	local name = Kit.title(key.face, "THE PARK", 27, Color3.new(1, 1, 1), 3, 3, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), ZIndex = 10 })
	local k = Kit.frame(key.face, 298 - 116, 0, 106, 32, Kit.INK, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -116, 0.5, 0), BackgroundTransparency = 0.4, ZIndex = 10 }); Kit.corner(k, 16)
	Kit.icon(k, 3, 1, 30, "popcorn", { ZIndex = 11 })
	local kt = Kit.title(k, "0 / 0", 16, Color3.new(1, 1, 1), 2, 0, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(67, 16), ZIndex = 11 })
	banner = { key = key, name = name, kernels = kt, kbox = k }
end

-- ---------------------------------------------------------------- toast (397,96,644,69)
local toastQ, toastBusy = {}, false
local function showToast(msg, theme, icon)
	table.insert(toastQ, { msg, theme or "molt", icon or "plume" })
	if toastBusy then return end
	toastBusy = true
	task.spawn(function()
		while #toastQ > 0 do
			local t = table.remove(toastQ, 1)
			local sp = Spec[t[2]] or Spec.molt
			local holder = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -241, 0, 96), Size = UDim2.fromOffset(644, 69), BackgroundTransparency = 1, ZIndex = 30 }, canvas)
			local sh = Kit.frame(holder, 0, 5, 644, 69, Color3.new(0, 0, 0), { BackgroundTransparency = 0.45, ZIndex = 30 }); Kit.corner(sh, 20)
			local f = Kit.frame(holder, 0, 0, 644, 69, Color3.new(1, 1, 1), { ZIndex = 31, ClipsDescendants = true }); Kit.corner(f, 20)
			Kit.grad(f, Kit.stops(sp.hdr)); Kit.texture(f, "halftone", 0.75, 32, 31)
			local dome = Kit.ellipse(f, 18, 12 - 40, 741, 76, Color3.new(1, 1, 1)); dome.ZIndex = 32
			Kit.grad(dome, { { "ffffff", 0, 0.4 }, { "ffffff", 1, 0 } })
			local row = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 33 }, f)
			Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }, row)
			Kit.icon(row, 0, 0, 44, t[3], { ZIndex = 34 })
			Kit.title(row, t[1], 24, Color3.new(1, 1, 1), 3, 3, { ZIndex = 34 })
			Kit.stroke(f, 3.5)
			local sc = Kit.new("UIScale", { Scale = 0.6 }, holder)
			TweenService:Create(sc, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.wait(2.4)
			TweenService:Create(sc, TweenInfo.new(0.18), { Scale = 0.85 }):Play()
			for _, d in holder:GetDescendants() do
				if d:IsA("GuiObject") then TweenService:Create(d, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play() end
				if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(0.18), { TextTransparency = 1 }):Play() end
				if d:IsA("ImageLabel") then TweenService:Create(d, TweenInfo.new(0.18), { ImageTransparency = 1 }):Play() end
				if d:IsA("UIStroke") then TweenService:Create(d, TweenInfo.new(0.18), { Transparency = 1 }):Play() end
			end
			task.wait(0.2)
			holder:Destroy()
		end
		toastBusy = false
	end)
end
Hud.toast = showToast
Windows.toast = function(msg) showToast(msg, docked or "popcorn", Spec.MENU_ICON[docked or "popcorn"]) end

-- ---------------------------------------------------------------- wallet capsules (money/popcorn 360x86, money/plume 180x64)
local CAP_GRAD = { popcorn = "eaff9a:0 62e83c:55 2bb52a:100", goldenFeathers = "f3e6ff:0 c79bff:100", sunflowerSeeds = "e8ffd0:0 8fe04a:100",
	goldenPopcorn = "fff3c4:0 f5c84a:100", bruteOre = "e0f6ff:0 4fd2ff:100", twigs = "fdf2dc:0 d2a062:100", echoPopcorn = "ffe0f6:0 ff8ff0:100",
	moneta = "fff7d0:0 f2c033:100", skillPoints = "ffe0e0:0 ff6a6a:100" }
local CAP_UNLOCK = { popcorn = 1, goldenFeathers = 2, sunflowerSeeds = 3, moneta = 5, twigs = 6, bruteOre = 7, goldenPopcorn = 8, skillPoints = 9, echoPopcorn = 10 }
local capBig, capGrid
-- popcorn = the big Figma capsule (money/popcorn 360x86); every other currency = a money/plume-style capsule,
-- in a 2-column grid that fills upward from just above it, so it never runs into the menu.
local function capsule(cur, big)
	local w, h = if big then 330 else 150, if big then 70 else 48
	local ic = if big then 92 else 64
	local f = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w + 30, h + 16), ZIndex = 10, LayoutOrder = CAP_UNLOCK[cur] or 0 }, if big then capBig else capGrid)
	local c = Kit.frame(f, 30, 8, w, h, Color3.new(1, 1, 1), { ZIndex = 10 })
	Kit.corner(c, h / 2); Kit.grad(c, { { "20242c", 0, 0.92 }, { "12141a", 1, 0.92 } }); Kit.stroke(c, 3.5)
	Kit.frame(c, h / 2, 2, w - h, 2, Color3.new(1, 1, 1), { BackgroundTransparency = 0.9, ZIndex = 11 })
	local icon = Kit.icon(f, 0, if big then -3 else 0, ic, Defs.CUR[cur].icon, { ZIndex = 12 })
	-- value is vertically centred on the capsule
	local val = Kit.title(f, "0", if big then 43.4 else 26, Color3.new(1, 1, 1), if big then 3.5 else 3, if big then 3 else 2,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(if big then 94 else 68, 8 + h / 2 - 1), ZIndex = 12 })
	Kit.grad(val.label, Kit.stops(CAP_GRAD[cur]))
	local rate
	if big then
		rate = Kit.title(f, "", 17, hex("7dff96"), 2, 0, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(30 + w - 22, 8 + h / 2 + 2), ZIndex = 12 })
	end
	capsules[cur] = { frame = f, cap = c, value = val, rate = rate, icon = icon, big = big }
	return capsules[cur]
end
local function buildWallet()
	capBig = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -20), Size = UDim2.fromOffset(360, 86), ZIndex = 10 }, canvas)
	capGrid = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -110), Size = UDim2.fromOffset(372, 256), ZIndex = 10 }, canvas)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(180, 64), CellPadding = UDim2.fromOffset(12, 0), SortOrder = Enum.SortOrder.LayoutOrder,
		StartCorner = Enum.StartCorner.BottomLeft, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom }, capGrid)
	for _, cur in Defs.CUR_ORDER do capsule(cur, cur == "popcorn").frame.Visible = cur == "popcorn" end
end
local lastVals = {}
local function wiggle(cur)
	local c = capsules[cur]; if not c then return end
	local x0 = c.frame.Position
	task.spawn(function() for _, dx in { 5, -5, 4, -4, 0 } do c.cap.Position = UDim2.fromOffset(30 + dx, 8); task.wait(0.035) end end)
end
Hud.wiggle = wiggle

-- currency particles arc from a button to its wallet capsule (6-10 icons)
local function flyTo(cur, fromGui, n)
	local c = capsules[cur]; if not (c and fromGui and c.frame.Visible) then return end
	local s = scale.Scale
	local a = (fromGui.AbsolutePosition + fromGui.AbsoluteSize / 2) / s
	local b = (c.icon.AbsolutePosition + c.icon.AbsoluteSize / 2) / s
	for i = 1, n or 8 do
		local img = Kit.icon(canvas, a.X - 14, a.Y - 14, 28, Defs.CUR[cur].icon, { ZIndex = 60 })
		local mid = Vector2.new((a.X + b.X) / 2 + math.random(-80, 80), math.min(a.Y, b.Y) - 120 - math.random(0, 80))
		task.delay(i * 0.03, function()
			local t0 = os.clock()
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local t = math.min(1, (os.clock() - t0) / 0.55)
				local e = t * t * (3 - 2 * t)
				local p = a:Lerp(mid, e):Lerp(mid:Lerp(b, e), e)
				img.Position = UDim2.fromOffset(p.X - 14, p.Y - 14)
				img.Rotation = t * 180
				if t >= 1 then conn:Disconnect(); img:Destroy(); Kit.pop(c.icon, 1.18) end
			end)
		end)
	end
end
Hud.flyTo = flyTo

-- ---------------------------------------------------------------- objective (399,1000,634,56) + AUTO
local objective, autoBtn, unlockBtn
local function buildObjective()
	local o = Kit.frame(canvas, 0, 0, 634, 56, Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -244, 1, -24), ZIndex = 10, AutomaticSize = Enum.AutomaticSize.X })
	Kit.corner(o, 26); Kit.grad(o, { { "20242c", 0, 0.88 }, { "12141a", 1, 0.88 } }); Kit.stroke(o, 3)
	local bang = Kit.frame(o, 15, 11, 34, 34, Color3.new(1, 1, 1), { ZIndex = 11 }); Kit.corner(bang, 17); Kit.grad(bang, Kit.stops("ffe07a:0 c27a10:100")); Kit.stroke(bang, 2.5)
	Kit.title(bang, "!", 22, Color3.new(1, 1, 1), 2, 0, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 12 })
	local t = Kit.title(o, "", 20, hex("ffe8a8"), 2.4, 2, { Position = UDim2.fromOffset(61, 13), ZIndex = 12 })
	Kit.new("UIPadding", { PaddingRight = UDim.new(0, 24) }, o)
	objective = { frame = o, text = t }
	unlockBtn = Kit.button(canvas, 0, 0, 220, 56, { text = "UNLOCK", size = 20, stops = Kit.GOLD, icon = "popcorn", iconSize = 34 })
	unlockBtn.root.AnchorPoint = Vector2.new(0.5, 1); unlockBtn.root.Position = UDim2.new(0.5, 230, 1, -24)
	unlockBtn.root.Visible = false
	unlockBtn.root.Activated:Connect(function() act("unlock", nil, nil, unlockBtn) end)
	-- AUTO: group perk. Locked players get the in-game join prompt, then the server re-checks.
	autoBtn = Kit.button(canvas, 0, 0, 190, 56, { text = "AUTO", size = 22, stops = Kit.GREY, icon = "clock", iconSize = 34 })
	autoBtn.root.AnchorPoint = Vector2.new(1, 1); autoBtn.root.Position = UDim2.new(1, -540, 1, -24)
	autoBtn.root.Activated:Connect(function()
		if not derived then return end
		if not derived.autoAllowed and derived.groupId and derived.groupId > 0 then
			pcall(function() GroupService:PromptJoinAsync(derived.groupId) end)
		end
		act("auto", not (state and state.auto))
	end)
end

-- ---------------------------------------------------------------- window menu (left column) + docking drawer
-- The drawer (dock) slides in from the right edge when the feature group changes; tabs inside a group just swap.
-- Collapsing tucks it into a narrow right-edge tab that keeps the feature icon and a reopen chevron.
local groupTiles = {}
local collapsed = false
local edgeTab
local DOCK_IN, DOCK_OUT = -22, 560
local function groupOf(id) return Spec.GROUP_OF[id] end
local function slideDock(x, t, style)
	if Hud.qa then return nil end
	if Kit.reduced() then Hud.dock.Position = UDim2.new(1, x, 0, 26); return nil end
	local tw = TweenService:Create(Hud.dock, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, x, 0, 26) })
	tw:Play()
	return tw
end
local function refreshTiles()
	local g = docked and groupOf(docked)
	for gid, t in groupTiles do t.select(g ~= nil and g.id == gid and not collapsed) end
end
local function setCollapsed(c)
	if collapsed == c then return end
	collapsed = c
	Kit.sfx(if c then "close" else "open")
	slideDock(if c then DOCK_OUT else DOCK_IN, if c then 0.22 else 0.3, if c then Enum.EasingStyle.Quad else nil)
	edgeTab.icon.Image = Kit.iconId(Spec.MENU_ICON[docked or "popcorn"])
	edgeTab.grad:Destroy()
	edgeTab.grad = Kit.grad(edgeTab.face, Kit.stops(Spec[docked or "popcorn"].tab))
	TweenService:Create(edgeTab.root, TweenInfo.new(if c then 0.25 else 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, if c then 0 else 100, 0.5, 0) }):Play()
	refreshTiles()
end
Hud.setCollapsed = setCollapsed

local function dockWindow(id)
	if docked == id then if collapsed then setCollapsed(false) end; return end
	local old = docked and Windows.built[docked]
	local sameGroup = docked ~= nil and groupOf(docked) == groupOf(id)
	docked = id
	local api = Windows.built[id]
	if not api then return end
	if state and derived then Windows.binders[id].update(api, state, derived) end
	if old and old ~= api then old.root.Visible = false end
	if collapsed then
		Window.open(api, "slide")
		setCollapsed(false)
	elseif not old then
		Window.open(api, "slide")
		Hud.dock.Position = UDim2.new(1, DOCK_OUT, 0, 26)
		slideDock(DOCK_IN, 0.34)
	elseif sameGroup then
		Window.open(api, "tab")
	else
		-- new feature group: drawer slides in fresh from the right edge with the new window (one motion)
		Kit.sfx("open")
		Hud.dock.Position = UDim2.new(1, DOCK_IN + 140, 0, 26)
		Window.open(api, "slide")
		slideDock(DOCK_IN, 0.26)
	end
	refreshTiles()
end
Windows.open = function(id)
	if not Windows.built[id] then return end
	if state and (Defs.WINDOW_ISLAND[id] or 1) > state.island then
		Kit.sfx("nope")
		showToast("Locked: " .. (Defs.ISLANDS[Defs.WINDOW_ISLAND[id]].goal), docked, "crown")
		return
	end
	dockWindow(id)
end

local function heroTile(parent, g, order)
	-- Built like the panels' hero card: dark themed card, sunburst + ground shadow behind the icon (icon stays inside),
	-- coloured header strip along the bottom carrying the name. Hover: lift, icon grows, burst fades in.
	-- Press: squash. Selected: white rim, outer glow, burst spins.
	local lead = Spec[g.members[1]]
	local W, H = 92, 104
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 10 }, parent)
	local lift = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H + 4), ZIndex = 10 }, holder)
	local glow = Kit.soft(lift, 0, 0, W, H, 22, "glow", hex(lead.buyGlow or lead.glow or "ffffff"), 1, 9)
	local drop = Kit.frame(lift, 0, 4, W, H, Kit.INK, { ZIndex = 10 }); Kit.corner(drop, 18)
	local card = Kit.new("CanvasGroup", { Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 11 }, lift)
	Kit.corner(card, 18)
	local bodyF = Kit.frame(card, 0, 0, W, H, Color3.new(1, 1, 1), { ZIndex = 11 })
	Kit.grad(bodyF, Kit.stops(lead.card or lead.body))
	Kit.texture(card, "halftone", 0.9, 20, 12)
	local burst = Kit.image(card, W / 2 - 60, 40 - 60, 120, 120, Kit.iconId("ui/sunburst"), { ImageColor3 = hex(lead.glow or "ffffff"), ImageTransparency = 0.8, ZIndex = 12 })
	Kit.image(card, W / 2 - 30, 62, 60, 14, Kit.iconId("ui/softellipse"), { ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.45, ZIndex = 12 })
	-- header strip (name)
	local strip = Kit.frame(card, 0, H - 26, W, 26, Color3.new(1, 1, 1), { ZIndex = 13 })
	Kit.grad(strip, Kit.stops(lead.hdr))
	Kit.frame(strip, 0, 0, W, 2, Kit.INK, { ZIndex = 14 })
	Kit.frame(strip, 6, 3, W - 12, 4, Color3.new(1, 1, 1), { BackgroundTransparency = 0.6, ZIndex = 14 })
	local lbl = Kit.title(strip, g.name, if #g.name > 7 then 12 else 14, Color3.new(1, 1, 1), 2, 1.5,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 1), ZIndex = 15 })
	-- top gloss
	local gl = Kit.frame(card, 6, 4, W - 12, 18, Color3.new(1, 1, 1), { ZIndex = 16 }); Kit.corner(gl, 9)
	Kit.grad(gl, { { "ffffff", 0, 0.16 }, { "ffffff", 1, 0 } })
	local rim = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), ZIndex = 17 }, lift)
	Kit.corner(rim, 18)
	local rs = Kit.stroke(rim, 3, Kit.INK)
	local icon = Kit.icon(lift, W / 2, 40, 64, g.icon, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 18 })
	local isc = Kit.new("UIScale", {}, icon)
	local lsc = Kit.new("UIScale", {}, lift)
	local hit = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), ZIndex = 20 }, holder)

	local hovered, selected, pressed = false, false, false
	local function pose()
		local q = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(lift, q, { Position = UDim2.fromOffset(0, if pressed then 2 elseif hovered then -4 else 0) }):Play()
		TweenService:Create(lsc, q, { Scale = if pressed then 0.94 elseif selected then 1.04 else 1 }):Play()
		TweenService:Create(isc, q, { Scale = if hovered then 1.14 elseif selected then 1.06 else 1 }):Play()
		TweenService:Create(icon, q, { Rotation = if hovered then -6 else 0 }):Play()
		TweenService:Create(burst, TweenInfo.new(0.2), { ImageTransparency = if selected then 0.35 elseif hovered then 0.55 else 0.8 }):Play()
		TweenService:Create(glow, TweenInfo.new(0.2), { ImageTransparency = if selected then 0.2 elseif hovered then 0.6 else 1 }):Play()
		rs.Color = if selected then Color3.new(1, 1, 1) else Kit.INK
		rs.Thickness = if selected then 3.5 else 3
	end
	hit.MouseEnter:Connect(function() hovered = true; Kit.sfx("hover"); pose() end)
	hit.MouseLeave:Connect(function() hovered = false; pressed = false; pose() end)
	hit.MouseButton1Down:Connect(function() pressed = true; Kit.sfx("click"); pose() end)
	hit.MouseButton1Up:Connect(function() pressed = false; pose() end)
	hit.Activated:Connect(function()
		-- clicking the open feature tucks the drawer away; otherwise open the group's first unlocked window
		local cur = docked and groupOf(docked)
		if cur == g then if collapsed then setCollapsed(false) end; return end
		for _, m in g.members do
			if not state or (Defs.WINDOW_ISLAND[m] or 1) <= state.island then Windows.open(m); return end
		end
	end)
	local t = { holder = holder, btn = { root = hit }, icon = icon, burst = burst }
	function t.select(on)
		if on == selected then return end
		selected = on
		pose()
		if on then Kit.pop(icon, 1.25) end
	end
	function t.isSelected() return selected end
	return t
end

-- selected tile's sunburst turns slowly
game:GetService("RunService").RenderStepped:Connect(function(dt)
	for _, t in groupTiles do if t.isSelected() and t.holder.Visible then t.burst.Rotation += dt * 20 end end
end)

local function buildMenu()
	local col = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 152), Size = UDim2.fromOffset(330, 380), ZIndex = 10 }, canvas)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 112), CellPadding = UDim2.fromOffset(12, 8), SortOrder = Enum.SortOrder.LayoutOrder }, col)
	for i, g in Spec.GROUPS do
		groupTiles[g.id] = heroTile(col, g, i)
		for _, m in g.members do menuButtons[m] = { holder = groupTiles[g.id].holder, btn = groupTiles[g.id].btn, group = g } end
	end
	-- right-edge tab shown while the drawer is collapsed
	local root = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 100, 0.5, 0), Size = UDim2.fromOffset(74, 132), ZIndex = 40 }, canvas)
	local face = Kit.frame(root, 0, 0, 96, 132, Color3.new(1, 1, 1), { ZIndex = 40 }); Kit.corner(face, 22)
	local gr = Kit.grad(face, Kit.stops(Spec.popcorn.tab))
	Kit.texture(face, "halftone", 0.78, 24, 40); Kit.stroke(face, 3.5)
	local ic = Kit.icon(root, 9, 12, 56, "popcorn", { ZIndex = 42 })
	Kit.title(root, "‹", 40, Color3.new(1, 1, 1), 3, 2, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(37, 68), ZIndex = 42 })
	edgeTab = { root = root, face = face, grad = gr, icon = ic }
	root.MouseEnter:Connect(function() Kit.sfx("hover"); TweenService:Create(root, TweenInfo.new(0.12), { Position = UDim2.new(1, -8, 0.5, 0) }):Play() end)
	root.MouseLeave:Connect(function() if collapsed then TweenService:Create(root, TweenInfo.new(0.12), { Position = UDim2.new(1, 0, 0.5, 0) }):Play() end end)
	root.Activated:Connect(function() setCollapsed(false) end)
end

-- ---------------------------------------------------------------- dev panel (Studio / owner only)
local devPanel, devLabel
local function buildDev()
	devPanel = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -241, 0, 26), Size = UDim2.fromOffset(644, 60), ZIndex = 20, Visible = false }, canvas)
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }, devPanel)
	local function db(label, op, stops)
		local h = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 46), ZIndex = 20 }, devPanel)
		local b = Kit.button(h, 0, 0, 150, 46, { text = label, size = 17, stops = stops })
		b.root.Activated:Connect(function() act("dev", op) end)
		return b
	end
	db("REGULAR", "regular", Kit.stops("7dff86:0 2bd04a:42 15962f:86 15962f:100"))
	db("MAXED", "maxed", Kit.GOLD)
	db("NEXT ISLAND", "next", Kit.stops(Spec.molt.tab))
	local lh = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 46), ZIndex = 20 }, devPanel)
	devLabel = Kit.title(lh, "", 15, hex("ffe8a8"), 2, 0, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(0, 23), ZIndex = 21 })
end

-- ---------------------------------------------------------------- full fish index overlay (Open Full Index)
local indexOverlay
function Windows.openIndex()
	if indexOverlay then indexOverlay.Visible = not indexOverlay.Visible; return end
	indexOverlay = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 80 }, canvas)
	local spec = table.clone(Spec.index); spec.rows = {}; spec.hero = nil; spec.section = nil; spec.h = 905
	spec.title = "FISH INDEX"; spec.footer = "Tap anywhere outside to close."
	local api = Window.build(indexOverlay, spec)
	api.root.Position = UDim2.fromScale(0.5, 0.5); api.root.ZIndex = 81
	local sf = Kit.new("ScrollingFrame", { Position = UDim2.fromOffset(16, 158), Size = UDim2.fromOffset(468, 700), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5 }, api.body)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 96), CellPadding = UDim2.fromOffset(12, 10) }, sf)
	api.cells = {}
	for i, f in Defs.FISH do
		local c = Kit.frame(sf, 0, 0, 84, 96, Color3.new(0, 0, 0), { BackgroundTransparency = 0.6, ZIndex = 5, LayoutOrder = i }); Kit.corner(c, 12)
		local im = Kit.icon(c, 10, 4, 64, f.id, { ZIndex = 6 })
		local q = Kit.title(c, "?", 30, hex("8d94a3"), 2, 0, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(42, 36), ZIndex = 7 })
		local n = Kit.text(c, Windows.fishName(f.id), 11, hex("bcc3cf"), { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(80, 14), Position = UDim2.fromOffset(2, 76), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6 })
		api.cells[f.id] = { im = im, q = q, n = n }
	end
	Hud.indexApi = api
	Hud.refreshIndex()
	Window.open(api)
	indexOverlay.Activated:Connect(function() indexOverlay.Visible = false end)
end
function Hud.refreshIndex()
	local api = Hud.indexApi; if not api then return end
	local disc = Windows.fishDisc or {}
	for id, c in api.cells do
		local d = disc[id]
		c.im.ImageColor3 = if d then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		c.im.ImageTransparency = if d then 0 else 0.35
		c.q.holder.Visible = not d
		c.n.Text = if d then Windows.fishName(id) else "???"
	end
end

-- ---------------------------------------------------------------- state
local ISLAND_THEME = { park = "popcorn", molt = "molt", garden = "seeds", castle = "evolve", bridge = "rods", forest = "nest", mine = "mine", desert = "golden", expedition = "parrot", echo = "echo" }
local lastIsland = 0
function Hud.setState(s, d)
	state, derived = s, d
	Windows.state = s
	-- banner: island name + live kernels
	local isl = Defs.ISLANDS[s.island]
	local zoneName = if s.zone == "desert" then "THE DESERT" else (if s.island >= 3 then "THE GARDEN" else "THE PARK")
	banner.name.set(zoneName)
	banner.kernels.set((Hud.kernelCount or 0) .. " / " .. d.cap)
	-- wallet
	for _, cur in Defs.CUR_ORDER do
		local c = capsules[cur]
		local show = cur == "popcorn" or (CAP_UNLOCK[cur] or 99) <= s.island
		c.frame.Visible = show
		if show then
			local v = s[cur]
			local txt = if cur == "popcorn" and EN.toNumber(v) < 1e6 then Windows.commas(EN.toNumber(v)) else EN.short(v)
			c.value.set(txt)
			local prev = lastVals[cur]
			if prev and EN.me(v, prev) and cur ~= "popcorn" then Kit.pop(c.value.holder, 1.08) end
			lastVals[cur] = v
		end
	end
	if capsules.popcorn.rate then capsules.popcorn.rate.set("+" .. EN.short(d.popPerSec) .. "/s") end
	-- objective + unlock
	objective.text.set(d.nextGoal)
	unlockBtn.root.Visible = d.nextCost ~= nil
	if d.nextCost then
		local can = true
		for cur, n in d.nextCost do if not EN.meeq(s[cur], n) then can = false end; unlockBtn.setText(EN.short(n)) end
		unlockBtn.look(if can then "gold" else "grey")
	end
	-- auto
	autoBtn.setText(if not d.autoAllowed then "AUTO  🔒" elseif s.auto then "AUTO ON" else "AUTO")
	autoBtn.look(if s.auto then "lit" else "grey", Kit.stops("7dff86:0 2bd04a:42 15962f:86 15962f:100"), if s.auto then "4dff66" else nil)
	-- dev
	devPanel.Visible = d.devAllowed == true and not Hud.qa
	if d.devAllowed then devLabel.set(string.upper(d.mode) .. "  ·  " .. Defs.ISLANDS[s.island].id) end
	-- menu: unlocked windows only
	for _, g in Spec.GROUPS do
		local open = false
		for _, m in g.members do if (Defs.WINDOW_ISLAND[m] or 1) <= s.island then open = true end end
		groupTiles[g.id].holder.Visible = open
	end
	for _, api in Windows.built do
		for _, t in api.tabs do
			if t.icon and t.id then
				local locked = (Defs.WINDOW_ISLAND[t.id] or 1) > s.island
				t.icon.ImageColor3 = if locked then Color3.fromRGB(70, 74, 84) else Color3.new(1, 1, 1)
				if t.label then t.label.TextTransparency = if locked then 0.5 else 0 end
			end
		end
	end
	if not docked then dockWindow("popcorn") end
	if docked and (Defs.WINDOW_ISLAND[docked] or 1) > s.island then dockWindow("popcorn") end
	if docked then Windows.update(docked, s, d) end
	if s.island > lastIsland and lastIsland > 0 then
		for i = lastIsland + 1, s.island do
			local w = Defs.ISLANDS[i].windows[1]
			local mb = menuButtons[w]; if mb then Kit.pop(mb.holder, 1.4) end
		end
	end
	lastIsland = s.island
	local th = Spec[ISLAND_THEME[isl.id]] or Spec.popcorn
	if banner.theme ~= th then banner.theme = th; banner.key.setStops(Kit.stops(th.hdr)) end
end

-- ---------------------------------------------------------------- toasts from the server
local NAMES = {}
for id, d in Defs.UP do NAMES[id] = d end
function Hud.onToast(kind, a, b, c)
	if kind == "bought" then
		local d = Defs.UP[a]
		Kit.sfx("thock")
		local api = docked and Windows.built[docked]
		if api then Window.celebrate(api, a) end
		if d then local c = capsules[d.cur]; if c then Kit.pop(c.value.holder, 1.06) end end
	elseif kind == "poor" then
		Kit.sfx("nope")
		if Hud.lastBtn then Kit.nope(Hud.lastBtn) end
		local d = Defs.UP[a]
		if d then wiggle(d.cur) end
	elseif kind == "molt" then
		showToast("You molted!  +" .. a .. " Plumes" .. (if b then "  ·  The Garden opens" else ""), "molt", "plume")
		-- violet flash
		local fl = Kit.frame(canvas, 0, 0, 0, 0, hex("b06cff"), { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.35, ZIndex = 90 })
		TweenService:Create(fl, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function() fl:Destroy() end)
	elseif kind == "island" then
		local theme = ISLAND_THEME[a] or "popcorn"
		showToast(b .. " opens!", theme, Spec.MENU_ICON[Spec.MENU[1]] and Spec[theme] and (Spec.MENU_ICON[theme] or "crown") or "crown")
	elseif kind == "evolve" then
		showToast("Evolution " .. a .. "!  The monster grows.", "evolve", "monster")
		local fl = Kit.frame(canvas, 0, 0, 0, 0, hex("ff5a8a"), { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.3, ZIndex = 90 })
		TweenService:Create(fl, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
		task.delay(0.7, function() fl:Destroy() end)
	elseif kind == "fish" then
		showToast("New fish!  " .. Windows.fishName(a) .. "  ·  " .. string.format("%.2f kg", b), "index", a)
	elseif kind == "floor" then showToast("Floor " .. a .. " reached!", "parrot", "parrot")
	elseif kind == "nest" then showToast("The " .. a .. " nest is built!", "nest", "nest")
	elseif kind == "craft" then showToast("Crafted the " .. Windows.fishName(a:gsub("^rod_", "")) .. " Rod!", "rods", a)
	elseif kind == "sacrifice" then showToast("Sacrificed!  Tier " .. a, "sacrifice", "altar")
	elseif kind == "claim" then showToast("Quest claimed!", "quests", "chest")
	elseif kind == "travel" then showToast(if a == "desert" then "Welcome to the Desert" else "Back to the Park", if a == "desert" then "golden" else "popcorn", if a == "desert" then "golden" else "popcorn")
	elseif kind == "auto" then showToast(if a then "AUTO is on" else "AUTO is off", "seeds", "clock")
	elseif kind == "autolocked" then showToast("Join the group to unlock AUTO", "golden", "crown")
	elseif kind == "dev" then showToast("Dev save: " .. string.upper(a) .. "  ·  island " .. b, "molt", "crown")
	elseif kind == "unlocked" then showToast("Unlocked!", "evolve", "crown")
	end
end

-- ---------------------------------------------------------------- start
function Hud.start(remotes)
	Remotes = remotes
	gui = Kit.new("ScreenGui", { Name = "PeckwoodHUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, plr:WaitForChild("PlayerGui"))
	canvas = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080) }, gui)
	scale = Kit.new("UIScale", {}, canvas)
	-- vignette (121729 0 -> 55%)
	local vig = Kit.frame(canvas, 0, 0, 0, 0, hex("121729"), { Size = UDim2.fromScale(1, 1), ZIndex = 0 })
	Kit.grad(vig, { { "121729", 0, 0 }, { "121729", 0.75, 0 }, { "121729", 1, 0.45 } })
	buildBanner(); buildWallet(); buildObjective(); buildMenu(); buildDev()
	-- docked shop column: right edge, 22 px margin, fit to height
	local dock = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 26), Size = UDim2.fromOffset(500, 1028), ZIndex = 5 }, canvas)
	Hud.dock = dock
	local ids = table.clone(Spec.MENU)
	for _, id in { "baits", "index", "aquarium" } do table.insert(ids, id) end
	for _, id in ids do
		-- wrapper carries the fit-to-height scale; the window root keeps its own open/close scale
		local holder = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(500, 100), ZIndex = 5 }, dock)
		local api = Windows.build(holder, id, act)
		holder.Size = UDim2.fromOffset(500, api.H)
		api.root.Position = UDim2.fromScale(0.5, 0.5)
		Kit.new("UIScale", { Scale = math.min(1, 1028 / api.H), Name = "Fit" }, holder)
		api.root.Visible = false
		api.collapse.root.Activated:Connect(function() Hud.setCollapsed(true) end)
	end
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	remotes.State.OnClientEvent:Connect(function(s, d) Hud.setState(s, d) end)
	remotes.Fish.OnClientEvent:Connect(function(disc, best, have)
		Windows.fishDisc, Windows.fishBest, Windows.fishHave = disc, best, have
		Hud.refreshIndex()
	end)
	remotes.Toast.OnClientEvent:Connect(Hud.onToast)
	-- debug hook (Studio tooling / screenshots): PlayerGui:SetAttribute("PeckwoodOpen", "<window id>")
	gui.Parent:GetAttributeChangedSignal("PeckwoodOpen"):Connect(function() Windows.open(gui.Parent:GetAttribute("PeckwoodOpen")) end)
	-- QA rig (Studio screenshots): PeckwoodQA = zoom (0 = off), PeckwoodQAY = scroll in design px.
	-- Hides the rest of the HUD and pins the docked window top-left so every window is checked the same way.
	local function qa()
		local z = gui.Parent:GetAttribute("PeckwoodQA") or 0
		Hud.qa = z > 0
		for _, c in canvas:GetChildren() do if c:IsA("GuiObject") and c ~= dock then c.Visible = not Hud.qa end end
		if Hud.qa then
			scale.Scale = z
			canvas.Size = UDim2.fromOffset(workspace.CurrentCamera.ViewportSize.X / z, workspace.CurrentCamera.ViewportSize.Y / z)
			dock.AnchorPoint = Vector2.new(0, 0)
			dock.Position = UDim2.new(0, 20, 0, 10 - (gui.Parent:GetAttribute("PeckwoodQAY") or 0))
		else
			dock.AnchorPoint = Vector2.new(1, 0); dock.Position = UDim2.new(1, DOCK_IN, 0, 26); layout()
		end
	end
	gui.Parent:GetAttributeChangedSignal("PeckwoodQA"):Connect(qa)
	gui.Parent:GetAttributeChangedSignal("PeckwoodQAY"):Connect(qa)
end

return Hud
