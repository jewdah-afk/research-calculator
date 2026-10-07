--!nonstrict
-- Hud: Figma HUD frame 8:271 (1920x1080) - map banner, toast, wallet capsules, objective bar, docked shop window -
-- plus the window menu, the AUTO button (group perk) and the dev save panel (Regular / Maxed / Next island).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GroupService = game:GetService("GroupService")
local Shared = RS:WaitForChild("Peckwood")
local Defs = require(Shared:WaitForChild("Defs"))
local World = require(game:GetService("ReplicatedStorage"):WaitForChild("Peckwood"):WaitForChild("World"))
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
-- face colour per currency (the 3D key itself)
local CAP_FACE = { popcorn = "9fe36a:0 3fae3a:100", goldenFeathers = "c9a2ff:0 7f4fd8:100", sunflowerSeeds = "b8e86a:0 5fa83a:100",
	goldenPopcorn = "ffe07a:0 d89a1a:100", bruteOre = "8fe4ff:0 2f8fd8:100", twigs = "e0b07a:0 9a6232:100", echoPopcorn = "ffa8ec:0 d04fb8:100",
	moneta = "ffe88a:0 d8a020:100", skillPoints = "ff9a8a:0 d04a4a:100" }
-- the number sits in a recessed well, Figma style: a deep shade of the capsule's own colour (not black), an inner
-- shadow along the top, halftone texture and a lit bottom edge, so it reads as pressed INTO the key
local function well(parent, x, w, h, faceStops, rad)
	rad = rad or h / 2
	local deep = Kit.shadeStops(Kit.stops(faceStops), 0.3)
	local rim = Kit.shadeStops(Kit.stops(faceStops), 0.16)
	local wl = Kit.frame(parent, x, 0, w, h, Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 0), ZIndex = 10 })
	Kit.corner(wl, rad)
	local d1, d2 = deep[1][1], (deep[2] or deep[1])[1]
	Kit.grad(wl, { { d2, 0, 1 }, { d1, 1, 1 } }, 90)
	local tx = Kit.texture(wl, "halftone", 0.84, 16, 10); Kit.corner(tx, rad)
	-- inner shadow: the same pill as the well (so its edges always follow the shape), dark at the top lip of the
	-- recess and fully clear from just past the middle
	local sh = Kit.frame(wl, 0, 0, w, h, Color3.new(0, 0, 0), { ZIndex = 11 }); Kit.corner(sh, rad)
	Kit.grad(sh, { { "000000", 0, 0.6 }, { "000000", 0.3, 0.22 }, { "000000", 0.6, 0 }, { "000000", 1, 0 } }, 90)
	Kit.stroke(wl, 2, Color3.fromHex((rim[2] or rim[1])[1]), 0)
	return wl
end
-- fit a title inside a box (scale down only)
local function fitInto(title, box, pad)
	local sc = Kit.new("UIScale", {}, title.holder)
	local function fit()
		local bw, tw = box.AbsoluteSize.X, title.holder.AbsoluteSize.X / math.max(0.01, sc.Scale)
		if bw <= 0 or tw <= 0 then return end
		local want = math.min(1, (bw - pad) / tw)
		if math.abs(want - sc.Scale) > 0.01 then sc.Scale = want end
	end
	title.holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	box:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
end
local function capsule(cur, big)
	local w, h = if big then 336 else 160, if big then 80 else 58
	local ic = if big then 98 else 66   -- icons a touch bigger (owner); centring below keeps them on the key face
	local depth = if big then 9 else 7
	local KX = 30
	local f = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w + KX, h + 12), ZIndex = 10, LayoutOrder = CAP_UNLOCK[cur] or 0 }, if big then capBig else capGrid)
	local stops = CAP_FACE[cur] or CAP_FACE.popcorn
	-- soft drop shadow under the key
	-- soft drop shadow: tucked under the key's footprint (no smear past the left cap / icon), short and light
	Kit.soft(f, KX + 10, 12, w - 20, h - 8, 8, "shadow", Color3.new(0, 0, 0), 0.62, 1)   -- below the key (root ZIndex 3)
	local key = Kit.button(f, KX, 4, w, h, { text = "", stops = Kit.stops(stops), silent = true, depth = depth })
	key.root.Active = false; pcall(function() key.root.Interactable = false end)
	local fw, fh = w - 6, h - 6 - depth
	-- the well starts where the icon ends (icon spans 0..ic in the capsule; the face starts at KX + 3)
	local wellX = ic - KX - 3 + 4
	local wh = fh - 14
	-- concentric corners: the well's radius is the face radius minus its inset, so both curves run parallel
	local faceR = math.clamp(math.floor(h * 0.3), 9, 18) - 3
	local wl = well(key.face, wellX, fw - wellX - 8, wh, stops, math.max(3, faceR - 7))
	-- centred on the key face (key at y 4, face 3 px in, fh tall), a touch low so it sits on the well's centre line
	local icon = Kit.icon(f, KX - ic / 2 + 2, 4 + 3 + fh / 2 - ic / 2 + 1, ic, Defs.CUR[cur].icon, { ZIndex = 12 })
	-- the stat's name, engraved into the right end of the well (soft caps in clear space after the value, never under it)
	local tag = Kit.text(wl, string.upper(Defs.CUR[cur].name), 12, Color3.new(1, 1, 1), { AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0.5), Position = if big then UDim2.new(1, -16, 0.3, 0) else UDim2.new(1, -8, 0.5, 1),
		Size = if big then UDim2.new(0.34, 0, 0.32, 0) else UDim2.new(0.44, 0, 0.62, 0),
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.5, ZIndex = 12 })
	Kit.new("UITextSizeConstraint", { MaxTextSize = if big then 15 else 12, MinTextSize = 6 }, tag)
	local val = Kit.title(wl, "0", if big then 36 else 22, Color3.new(1, 1, 1), if big then 3.2 else 2.6, if big then 3 else 2,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, if big then 16 else 12, 0.5, -1), ZIndex = 12 })
	Kit.grad(val.label, Kit.stops(CAP_GRAD[cur]))
	local rate
	if big then
		rate = Kit.title(wl, "", 15, hex("9dffae"), 2.2, 0, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.68, 0), ZIndex = 12 })   -- under the engraved name
		fitInto(val, wl, 130)
	else
		fitInto(val, wl, 74)   -- leave the right end clear for the engraved stat name
	end
	capsules[cur] = { frame = f, cap = key.root, value = val, rate = rate, icon = icon, big = big }
	return capsules[cur]
end
local function buildWallet()
	capBig = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -16), Size = UDim2.fromOffset(366, 92), ZIndex = 10 }, canvas)
	capGrid = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -112), Size = UDim2.fromOffset(392, 284), ZIndex = 10 }, canvas)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(190, 70), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder,
		StartCorner = Enum.StartCorner.BottomLeft, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom }, capGrid)
	for _, cur in Defs.CUR_ORDER do capsule(cur, cur == "popcorn").frame.Visible = cur == "popcorn" end
end
local lastVals = {}
local function wiggle(cur)
	local c = capsules[cur]; if not c then return end
	Kit.shake(c.cap, 5, 0.22)
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
	-- the goal plate: a slate 3D key (same build as the wallet keys) with the text in a recessed well
	local SLATE = "5a6478:0 343b4a:100"
	local key = Kit.button(canvas, 0, 0, 640, 64, { text = "", stops = Kit.stops(SLATE), silent = true, depth = 8 })
	key.root.Active = false; pcall(function() key.root.Interactable = false end)
	key.root.AnchorPoint = Vector2.new(0.5, 1); key.root.Position = UDim2.new(0.5, 0, 1, -22)   -- centred: progression reads at a glance
	local wl = well(key.face, 50, 640 - 6 - 50 - 9, 64 - 6 - 8 - 14, SLATE, math.max(3, math.clamp(math.floor(64 * 0.3), 9, 18) - 3 - 7))
	local bang = Kit.frame(key.face, 10, 0, 32, 32, Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 13 })
	Kit.corner(bang, 16); Kit.grad(bang, Kit.stops("ffe07a:0 c27a10:100")); Kit.stroke(bang, 2.5)
	Kit.title(bang, "!", 21, Color3.new(1, 1, 1), 2, 0, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 14 })
	local t = Kit.title(wl, "", 20, hex("ffe8a8"), 2.4, 2, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, -1), ZIndex = 13 })
	objective = { frame = key.root, text = t }
	unlockBtn = Kit.button(canvas, 0, 0, 220, 56, { text = "UNLOCK", size = 20, stops = Kit.GOLD, icon = "popcorn", iconSize = 34 })
	unlockBtn.root.AnchorPoint = Vector2.new(0, 1); unlockBtn.root.Position = UDim2.new(0.5, 332, 1, -24)
	unlockBtn.root.Visible = false
	unlockBtn.root.Activated:Connect(function() act("unlock", nil, nil, unlockBtn) end)
	-- AUTO: group perk. Locked players get the in-game join prompt, then the server re-checks.
	autoBtn = Kit.button(canvas, 0, 0, 190, 56, { text = "AUTO", size = 22, stops = Kit.GREY, icon = "clock", iconSize = 34 })
	autoBtn.root.Visible = false   -- AUTO lives in the left bar now (tile); kept for the state code
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
local DOCK_IN, DOCK_OUT = 0, 500
local DOCK_Y = -5
local WIN_MAX_H = 730   -- tall windows scale down a touch so the bookmark deck fits under them   -- top outline just past the screen top: the header runs into the corner   -- flush to the screen edge; tucked = fully out, the bookmarks stay
local function groupOf(id) return Spec.GROUP_OF[id] end
local function slideDock(x, t, style)
	if Hud.qa then return nil end
	if Kit.reduced() then Hud.dock.Position = UDim2.new(1, x, 0, DOCK_Y); return nil end
	local tw = TweenService:Create(Hud.dock, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, x, 0, DOCK_Y) })
	tw:Play()
	return tw
end
local layoutBookmarks   -- defined with the bookmarks below
local function refreshTiles()
	local g = docked and groupOf(docked)
	for gid, t in groupTiles do t.select(g ~= nil and g.id == gid and not collapsed) end
	if layoutBookmarks then layoutBookmarks(); task.delay(0.4, layoutBookmarks) end   -- again once the window has settled
end
local function setCollapsed(c)
	if collapsed == c then return end
	collapsed = c; Hud.collapsed = c
	Kit.sfx(if c then "close" else "open")
	slideDock(if c then DOCK_OUT else DOCK_IN, if c then 0.22 else 0.3, if c then Enum.EasingStyle.Quad else nil)
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
	if old and old ~= api and not (sameGroup and not collapsed) then old.root.Visible = false end
	if collapsed then
		Window.open(api, "slide")
		setCollapsed(false)
	elseif not old then
		Window.open(api, "slide")
		Hud.dock.Position = UDim2.new(1, DOCK_OUT, 0, DOCK_Y)
		slideDock(DOCK_IN, 0.34)
	elseif sameGroup then
		Window.morph(old, api)
	else
		-- new feature group: drawer slides in fresh from the right edge with the new window (one motion)
		Kit.sfx("open")
		Hud.dock.Position = UDim2.new(1, DOCK_IN + 140, 0, DOCK_Y)
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
	local lead = g.theme or Spec[g.members[1]]
	local W, H = g.w or 92, g.h or 104
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 10, Size = UDim2.fromOffset(W, H + 12) }, parent)
	-- centre-pivoted so press / select scaling stays even on every side (a top-left pivot pulls the right side in)
	local lift = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, (H + 8) / 2), Size = UDim2.fromOffset(W, H + 8), ZIndex = 10 }, holder)
	local glow = Kit.soft(lift, 0, 0, W, H, 22, "glow", hex(lead.buyGlow or lead.glow or "ffffff"), 1, 9)
	-- drop: a small, dark undertone of the tile's own strip colour (not a black slab)
	local hs = Kit.stops(lead.hdr)
	local under = Color3.fromHex(hs[#hs][1]):Lerp(Kit.INK, 0.55)
	-- 3D base like the keys: soft contact shadow, then a 6 px lip in the strip's own deep tone with an ink edge
	Kit.soft(lift, 6, 10, W - 12, H - 2, 10, "shadow", Color3.new(0, 0, 0), 0.55, 9)
	local drop = Kit.frame(lift, 0, 6, W, H, under, { ZIndex = 10 }); Kit.corner(drop, 18)
	Kit.stroke(drop, 3, Kit.INK)
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
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -0.5), ZIndex = 15 })   -- optically centred in the strip
	-- top gloss
	local gl = Kit.frame(card, 6, 4, W - 12, 18, Color3.new(1, 1, 1), { ZIndex = 16 }); Kit.corner(gl, 9)
	Kit.grad(gl, { { "ffffff", 0, 0.16 }, { "ffffff", 1, 0 } })
	local rim = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), ZIndex = 17 }, lift)
	Kit.corner(rim, 18)
	local rs = Kit.stroke(rim, 3, Kit.INK)
	local icon = Kit.icon(lift, W / 2, 40, g.iconSize or 64, g.icon, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 18 })
	local isc = Kit.new("UIScale", {}, icon)
	local lsc = Kit.new("UIScale", {}, lift)
	local hit = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), ZIndex = 20 }, holder)

	local hovered, selected, pressed = false, false, false
	local function pose()
		local q = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local out = if g.bookmark then (if selected then -16 elseif hovered then -8 else 0) else 0
		TweenService:Create(lift, q, { Position = UDim2.fromOffset(W / 2 + out, (H + 8) / 2 + (if g.bookmark then 0 elseif pressed then 2 elseif hovered then -4 else 0)) }):Play()
		TweenService:Create(lsc, q, { Scale = if pressed then 0.94 elseif selected then 1.04 else 1 }):Play()
		TweenService:Create(isc, q, { Scale = if hovered then 1.14 elseif selected then 1.06 else 1 }):Play()
		TweenService:Create(icon, q, { Rotation = if hovered then -6 else 0 }):Play()
		TweenService:Create(burst, TweenInfo.new(0.2), { ImageTransparency = if selected then 0.35 elseif hovered then 0.55 else 0.8 }):Play()
		TweenService:Create(glow, TweenInfo.new(0.2), { ImageTransparency = if selected then 0.45 elseif hovered then 0.7 else 1 }):Play()
		if not selected then icon.Position = UDim2.fromOffset(W / 2, 40) end
		rs.Color = if selected then Color3.new(1, 1, 1) else Kit.INK
		rs.Thickness = if selected then 3.5 else 3
	end
	hit.MouseEnter:Connect(function() hovered = true; Kit.sfx("hover"); pose() end)
	hit.MouseLeave:Connect(function() hovered = false; pressed = false; pose() end)
	hit.MouseButton1Down:Connect(function() pressed = true; Kit.sfx("click"); pose() end)
	hit.MouseButton1Up:Connect(function() pressed = false; pose() end)
	hit.Activated:Connect(function()
		if g.onClick then g.onClick(); return end
		-- clicking the open feature tucks the drawer away; otherwise open the group's first unlocked window
		local cur = docked and groupOf(docked)
		if cur == g then setCollapsed(not collapsed); return end
		for _, m in g.members do
			if not state or (Defs.WINDOW_ISLAND[m] or 1) <= state.island then Windows.open(m); return end
		end
	end)
	local t = { holder = holder, btn = { root = hit }, icon = icon, burst = burst, glow = glow, iconY = 40, W = W }
	function t.select(on)
		if on == selected then return end
		selected = on
		pose()
		if on then Kit.pop(icon, 1.25) end
	end
	function t.isSelected() return selected end
	return t
end

-- selected tile: the sunburst turns slowly (30 Hz, it sits in the CanvasGroup), the halo breathes and the icon floats
-- a couple of pixels (60 Hz, both outside the CanvasGroup, so they cost nothing to redraw)
local burstAcc, tclock = 0, 0
game:GetService("RunService").RenderStepped:Connect(function(dt)
	tclock += dt
	burstAcc += dt
	local slow = burstAcc >= 1 / 30
	for _, t in groupTiles do
		if not (t.isSelected() and t.holder.Visible) then continue end
		if slow and not Kit.reduced() then t.burst.Rotation += burstAcc * 9 end
		local b = (math.sin(tclock * math.pi * 2 / 2.8) + 1) / 2
		t.glow.ImageTransparency = 0.42 + 0.18 * b
		if not Kit.reduced() then t.icon.Position = UDim2.new(t.icon.Position.X, UDim.new(0, t.iconY - 1.5 + 3 * b)) end
	end
	if slow then burstAcc = 0 end
end)

-- left bar: the game's tools in the same tile style. Bookmarks (the feature groups) live on the drawer (see start).
local LEFT_THEMES = {
	map = { card = "2c3f3a:0 1b2622:100", hdr = "7fd8c8:0 2f9a8a:100", glow = "7fd8c8" },
	teleport = { card = "332d48:0 1f1b2e:100", hdr = "b89cff:0 6a4fd0:100", glow = "b89cff" },
	shop = { card = "45282a:0 2a1719:100", hdr = "ff8a7a:0 d0443a:100", glow = "ff8a7a" },
	settings = { card = "2e333f:0 1b1f27:100", hdr = "b8c4d8:0 5f6f8c:100", glow = "b8c4d8" },
	auto = { card = "2c3b28:0 1a2417:100", hdr = "9fe36a:0 3fae3a:100", glow = "9fe36a" },
}
local leftTiles = {}
local bookmarkCol
local function buildMenu()
	-- visual hierarchy: SHOP is the hero (double-wide, gold), AUTO beside it; the navigation row (MAP / TELEPORT /
	-- PROFILE) under them; SETTINGS is a small gear key by the island banner
	local col = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 152), Size = UDim2.fromOffset(330, 260), ZIndex = 10 }, canvas)
	local SLOT = { shop = { 0, 0 }, auto = { 208, 0 }, map = { 0, 128 }, teleport = { 104, 128 }, profile = { 208, 128 } }
	local profileG
	for _, g in Spec.GROUPS do if g.id == "profile" then profileG = g end end
	local LEFT = {
		{ id = "map", name = "MAP", icon = "map", members = {}, theme = LEFT_THEMES.map, onClick = function() Hud.onMap() end },
		{ id = "teleport", name = "TELEPORT", icon = "teleport", members = {}, theme = LEFT_THEMES.teleport, onClick = function() Hud.onTeleport() end },
		profileG,
		{ id = "shop", name = "SHOP", icon = "shop", w = 196, iconSize = 84, members = {}, theme = LEFT_THEMES.shop, onClick = function() Hud.openShop() end },
		{ id = "settings", name = "SETTINGS", icon = "settings", members = {}, theme = LEFT_THEMES.settings, onClick = function() Hud.onSettings() end },
		{ id = "auto", name = "AUTO", icon = "auto", members = {}, theme = LEFT_THEMES.auto, onClick = function()
			if not derived then return end
			if not derived.autoAllowed and derived.groupId and derived.groupId > 0 then pcall(function() GroupService:PromptJoinAsync(derived.groupId) end) end
			act("auto", not (state and state.auto))
		end },
	}
	for i, g in LEFT do
		if g.id == "settings" then
			-- small gear key beside the banner (low priority, still one tap away)
			local k = Kit.button(canvas, 344, 30, 56, 56, { icon = "settings", iconSize = 34, stops = Kit.stops(LEFT_THEMES.settings.hdr) })
			k.root.Activated:Connect(g.onClick)
			leftTiles.settings = { holder = k.root, btn = k, icon = k.iconImg }
			continue
		end
		local t = heroTile(col, g, i)
		local sl = SLOT[g.id]
		if sl then t.holder.Position = UDim2.fromOffset(sl[1], sl[2]) end
		leftTiles[g.id] = t
		if g == profileG then
			groupTiles[g.id] = t
			for _, m in g.members do menuButtons[m] = { holder = t.holder, btn = t.btn, group = g } end
		end
	end
end
-- small popup card beside the left bar (teleport list / settings); one open at a time, click the tile again to close
local popup
local function closePopup() if popup then popup:Destroy(); popup = nil end end
local function openPopup(title, rows)
	closePopup()
	local h = 70 + #rows * 58
	local root = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(372, 152), Size = UDim2.fromOffset(260, h), ZIndex = 30 }, canvas)
	local drop = Kit.frame(root, 0, 3, 260, h, Kit.INK, { ZIndex = 30 }); Kit.corner(drop, 18)
	local card = Kit.frame(root, 0, 0, 260, h, Color3.new(1, 1, 1), { ZIndex = 31 }); Kit.corner(card, 18)
	Kit.grad(card, Kit.stops("2a2f3a:0 15181f:100")); Kit.stroke(card, 3.5)
	local tx = Kit.texture(card, "halftone", 0.9, 20, 31); Kit.corner(tx, 18)
	Kit.title(card, title, 22, Color3.new(1, 1, 1), 2.6, 2, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), ZIndex = 33 })
	for k, r in rows do
		local b = Kit.button(card, 16, 56 + (k - 1) * 58, 228, 50, { text = r.text, size = 18, stops = r.stops or Kit.stops(Spec.popcorn.tab), icon = r.icon, iconSize = 34 })
		b.root.ZIndex = 34
		b.root.Activated:Connect(function() r.click(b) end)
	end
	local sc = Kit.new("UIScale", { Scale = 0.85 }, root)
	TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	popup = root
	return root
end
local ISLAND_ICON = { park = "popcorn", garden = "seed", castle = "monster", bridge = "rod", forest = "nest", mine = "crow", desert = "golden", expedition = "parrot", echo = "echo" }
function Hud.onTeleport()
	if popup and popup.Name == "Teleport" then closePopup(); return end
	local rows = {}
	for _, isl in World.list do
		if World.isOpen(isl) then
			table.insert(rows, { text = string.gsub(isl.name, "^THE ", ""), icon = ISLAND_ICON[isl.id], click = function()
				closePopup(); plr.PlayerGui:SetAttribute("PeckwoodTP", isl.id .. "#" .. os.clock())
			end })
		end
	end
	openPopup("TELEPORT", rows).Name = "Teleport"
end
function Hud.onSettings()
	if popup and popup.Name == "Settings" then closePopup(); return end
	local rows = {
		{ text = if Kit.muted then "Sound: OFF" else "Sound: ON", icon = "settings", stops = Kit.stops(LEFT_THEMES.settings.hdr), click = function(b)
			Kit.muted = not Kit.muted; b.setText(if Kit.muted then "Sound: OFF" else "Sound: ON")
		end },
	}
	openPopup("SETTINGS", rows).Name = "Settings"
end
-- ---------------------------------------------------------------- shop board (passes, boosts, crates)
-- Same window system as every board (cloned golden art), cards in two columns per section. Buying: a real
-- PromptGamePass/ProductPurchase when the item has a Creator Hub id; in Studio / for devs it grants through the
-- server test path so everything can be checked before the ids exist. The server applies every effect.
local ShopData = require(game:GetService("ReplicatedStorage"):WaitForChild("Peckwood"):WaitForChild("Shop"))
local shopOverlay, shopCards = nil, {}
local function fmtTime(sec) sec = math.floor(sec); return string.format("%d:%02d", sec // 60, sec % 60) end
function Hud.refreshShop()
	if not shopOverlay then return end
	local sh = derived and derived.shop or { passes = {}, boostLeft = 0 }
	for id, c in shopCards do
		local it = ShopData.BY_ID[id]
		if it.kind == "pass" then
			local own = sh.passes[id] == true
			if own ~= c.owned then
				c.owned = own
				c.btn.setText(if own then "OWNED" else "R$ " .. it.robux)
				c.btn.look(if own then "gold" else "lit", Kit.stops("7dff86:0 2bd04a:42 15962f:86 15962f:100"))
			end
		elseif it.minutes then
			c.sub.Text = if sh.boostLeft > 0 then "Active · " .. fmtTime(sh.boostLeft) .. " left" else it.desc
		end
	end
end
function Hud.openShop()
	if shopOverlay then shopOverlay.Visible = not shopOverlay.Visible; Hud.refreshShop(); return end
	shopOverlay = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 80 }, canvas)
	local spec = table.clone(Spec.golden); spec.rows = {}; spec.hero = nil; spec.section = nil; spec.h = 905
	spec.title = "SHOP"; spec.footer = "Passes are forever and stack with each other. Boost time stacks."
	spec.tabs = { { id = "shop", icon = "shop", label = "Shop", active = true } }
	local api = Window.build(shopOverlay, spec)
	api.root.Position = UDim2.fromScale(0.5, 0.5); api.root.ZIndex = 81
	if api.collapse then api.collapse.root.Activated:Connect(function() shopOverlay.Visible = false end) end
	local sf = Kit.new("ScrollingFrame", { Position = UDim2.fromOffset(16, 158), Size = UDim2.fromOffset(468, 712), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5 }, api.body)
	Kit.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	local order, curSec, grid = 0, nil, nil
	for _, it in ShopData.ITEMS do
		if it.section ~= curSec then
			curSec = it.section; order += 1
			local hdrL = Kit.title(sf, curSec, 18, hex("fff2d0"), 2.4, 2, { LayoutOrder = order, ZIndex = 6 })
			order += 1
			grid = Kit.new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(460, 0), LayoutOrder = order, ZIndex = 5 }, sf)
			Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(222, 196), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
			local _ = hdrL
		end
		local th = Spec[it.theme] or Spec.golden
		local card = Kit.frame(grid, 0, 0, 222, 196, Color3.new(1, 1, 1), { ZIndex = 6 }); Kit.corner(card, 18)
		Kit.grad(card, Kit.stops(th.card or th.body))
		Kit.stroke(card, 3, Kit.INK)
		local band = Kit.frame(card, 0, 0, 222, 96, Color3.new(1, 1, 1), { ZIndex = 6 }); Kit.corner(band, 18)
		Kit.grad(band, Kit.stops(th.hdr))
		Kit.texture(band, "halftone", 0.82, 18, 6)
		Kit.image(band, 111 - 70, 48 - 70, 140, 140, Kit.iconId("ui/sunburst"), { ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.7, ZIndex = 7 })
		Kit.icon(card, 111 - 40, 8, 80, it.icon, { ZIndex = 9 })
		Kit.title(card, it.name, 19, Color3.new(1, 1, 1), 2.6, 2, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(111, 98), ZIndex = 9 })
		local sub = Kit.text(card, it.desc, 13, hex("d8dde6"), { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(206, 18), Position = UDim2.fromOffset(8, 124),
			TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 9 })
		Kit.new("UITextSizeConstraint", { MaxTextSize = 13 }, sub)
		local btn = Kit.button(card, 16, 146, 190, 42, { text = "R$ " .. it.robux, size = 20, stops = Kit.stops("7dff86:0 2bd04a:42 15962f:86 15962f:100") })
		if it.tag then
			local rib = Kit.frame(card, 222 - 96, -8, 104, 24, hex("ff4d6a"), { ZIndex = 10 }); Kit.corner(rib, 12); Kit.stroke(rib, 2.5, Kit.INK)
			local rl = Kit.title(rib, it.tag, 12, Color3.new(1, 1, 1), 2, 1, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -1), ZIndex = 11 })
			local _ = rl
		end
		shopCards[it.id] = { btn = btn, sub = sub, owned = nil }
		btn.root.Activated:Connect(function()
			local c = shopCards[it.id]
			if c.owned then return end
			local MPS = game:GetService("MarketplaceService")
			if it.assetId > 0 then
				pcall(function()
					if it.kind == "pass" then MPS:PromptGamePassPurchase(plr, it.assetId) else MPS:PromptProductPurchase(plr, it.assetId) end
				end)
			elseif derived and derived.shop and derived.shop.testGrants then
				act("shoptest", it.id)
				showToast(it.name .. " granted (Studio test)", "golden", it.icon)
			else
				showToast(it.name .. " is coming soon", "golden", it.icon)
			end
		end)
	end
	shopOverlay.Activated:Connect(function() shopOverlay.Visible = false end)
	Window.open(api)
	Hud.refreshShop()
end
function Hud.onMap()
	closePopup()
	local on = not plr.PlayerGui:GetAttribute("PeckwoodMap")
	plr.PlayerGui:SetAttribute("PeckwoodMap", on)
	if on then showToast("Map: every open island. Tap MAP again to return", "seeds", "map") end
end

-- group bars: under the open window, every other feature group is a full-width bar styled like a window header
-- (themed header gradient, halftone, gloss, ink outline, icon + name). They share the space down to the screen bottom
-- evenly, so the right side is always filled top to bottom; click one to swap the drawer to that group.
local BAR_GAP, BAR_MIN, BAR_MAX = 5, 34, 64
local bmOrder = {}
local function bookmarkTab(parent, g, order)
	local lead = Spec[g.members[1]]
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.fromOffset(500, 64), ZIndex = 4 }, parent)
	local lift = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, holder)
	local glow = Kit.soft(lift, 0, 0, 500, 64, 16, "glow", hex(lead.glow or "ffffff"), 1, 3)
	glow.Size = UDim2.new(1, 32, 1, 32); glow.Position = UDim2.fromOffset(-16, -16)
	local base = Kit.frame(lift, 0, 5, 0, 0, Color3.fromHex(Kit.stops(lead.hdr)[#Kit.stops(lead.hdr)][1]):Lerp(Kit.INK, 0.5), { Size = UDim2.new(1, 0, 1, -5), ZIndex = 4 })
	Kit.corner(base, 16); Kit.stroke(base, 3, Kit.INK)
	local face = Kit.frame(lift, 0, 0, 0, 0, Color3.new(1, 1, 1), { Size = UDim2.new(1, 0, 1, -5), ZIndex = 5 }); Kit.corner(face, 16)
	Kit.grad(face, Kit.stops(lead.hdr))
	local tx = Kit.texture(face, "halftone", 0.82, 22, 5); Kit.corner(tx, 16)
	local gl = Kit.frame(face, 10, 4, 0, 0, Color3.new(1, 1, 1), { Size = UDim2.new(1, -20, 0.38, 0), ZIndex = 6 }); Kit.corner(gl, 10)
	Kit.grad(gl, { { "ffffff", 0, 0.22 }, { "ffffff", 1, 0 } })
	local st = Kit.stroke(face, 3, Kit.INK)
	local row = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, -2), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 7 }, face)
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local wellF = Kit.new("Frame", { BackgroundColor3 = Kit.INK, BackgroundTransparency = 0.55, Size = UDim2.fromOffset(46, 46), ZIndex = 7, LayoutOrder = 1 }, row)
	Kit.corner(wellF, 23)
	local icon = Kit.icon(wellF, 23, 23, 40, g.icon, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
	local name = Kit.title(row, g.name, 24, Color3.new(1, 1, 1), 3, 2, { ZIndex = 8, LayoutOrder = 2 })
	-- secondary: the group's tabs as small icons (what's inside), right-aligned before the chevron
	local mem = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, -2), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 7 }, face)
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, mem)
	local memIcons = {}
	if #g.members > 1 then
		for k, m in g.members do table.insert(memIcons, Kit.icon(mem, 0, 0, 28, Spec.MENU_ICON[m] or m, { ZIndex = 8, LayoutOrder = k, ImageTransparency = 0.15 })) end
	end
	local chev = Kit.title(face, "‹", 30, Color3.new(1, 1, 1), 3, 2, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, -3), ZIndex = 8 })
	local sc = Kit.new("UIScale", {}, row)
	local hit = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9 }, holder)
	local hovered, selected, pressed = false, false, false
	local function pose()
		local q = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(lift, q, { Position = UDim2.fromOffset(if hovered then -10 else 0, if pressed then 3 else 0) }):Play()
		TweenService:Create(glow, TweenInfo.new(0.2), { ImageTransparency = if hovered then 0.6 else 1 }):Play()
		TweenService:Create(sc, q, { Scale = if hovered then 1.05 else 1 }):Play()
	end
	-- icon + name shrink to fit short bars (the bar height follows the room left under the window)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local h = holder.Size.Y.Offset
		local d = math.clamp(h - 14, 26, 50)
		wellF.Size = UDim2.fromOffset(d, d); wellF.UICorner.CornerRadius = UDim.new(0.5, 0)
		icon.Position = UDim2.fromOffset(d / 2, d / 2); icon.Size = UDim2.fromOffset(d - 6, d - 6)
		name.holder:FindFirstChildOfClass("UIScale")
		for _, mi in memIcons do mi.Size = UDim2.fromOffset(math.clamp(h - 26, 18, 30), math.clamp(h - 26, 18, 30)) end
	end)
	hit.MouseEnter:Connect(function() hovered = true; Kit.sfx("hover"); pose() end)
	hit.MouseLeave:Connect(function() hovered = false; pressed = false; pose() end)
	hit.MouseButton1Down:Connect(function() pressed = true; Kit.sfx("click"); pose() end)
	hit.MouseButton1Up:Connect(function() pressed = false; pose() end)
	hit.Activated:Connect(function()
		local cur = docked and groupOf(docked)
		if cur == g then setCollapsed(not collapsed); return end
		for _, m in g.members do
			if not state or (Defs.WINDOW_ISLAND[m] or 1) <= state.island then Windows.open(m); return end
		end
	end)
	local t = { holder = holder, btn = { root = hit }, icon = icon, burst = Instance.new("Frame"), glow = glow, iconY = 4, gid = g.id, name = name }
	function t.select(on)
		if on == selected then return end
		selected = on
		if layoutBookmarks then layoutBookmarks() end
	end
	function t.isSelected() return selected end
	function t.slideOut(hide) holder.Visible = holder.Visible end
	return t
end
-- even stack: from under the open window (or the top while the drawer is tucked) down to the screen bottom
layoutBookmarks = function()
	if not bookmarkCol then return end
	local list = {}
	for _, id in bmOrder do
		local t = groupTiles[id]
		if t and t.unlocked ~= false then
			local show = not t.isSelected()
			t.holder.Visible = show
			if show then table.insert(list, t) end
		end
	end
	local top, width, left = 26, 470, nil
	local api = docked and Windows.built[docked]
	if api and api.root.Visible and scale then
		local r = api.root
		local cs = scale.Scale
		-- the window's outline sits 1 px outside its root: match it so bar edges line up with the board exactly
		width = r.AbsoluteSize.X / cs + 2
		left = (r.AbsolutePosition.X - canvas.AbsolutePosition.X) / cs - 1
		if not collapsed then top = (r.AbsolutePosition.Y + r.AbsoluteSize.Y - canvas.AbsolutePosition.Y) / cs + 8 end
	end
	local bottom = 1080 - 10
	local n = #list
	local h = if n > 0 then math.clamp((bottom - top - BAR_GAP * (n - 1)) / n, BAR_MIN, BAR_MAX) else 0
	local q = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	bookmarkCol.AnchorPoint = Vector2.new(0, 0)
	bookmarkCol.Size = UDim2.fromOffset(width, bottom - top)
	local vw = canvas.AbsoluteSize.X / (if scale then scale.Scale else 1)
	TweenService:Create(bookmarkCol, q, { Position = UDim2.fromOffset(left or (vw - width), top) }):Play()   -- same left/right edges as the open board
	for k, t in list do
		t.holder.Size = UDim2.fromOffset(width, h)
		TweenService:Create(t.holder, q, { Position = UDim2.fromOffset(0, (k - 1) * (h + BAR_GAP)) }):Play()
	end
end
local function buildBookmarks(dock)
	bookmarkCol = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 26), Size = UDim2.fromOffset(470, 1000), ZIndex = 4 }, canvas)
	for i, g in Spec.GROUPS do
		if g.id == "profile" then continue end
		local t = bookmarkTab(bookmarkCol, g, i)
		table.insert(bmOrder, g.id)
		groupTiles[g.id] = t
		for _, m in g.members do menuButtons[m] = { holder = t.holder, btn = t.btn, group = g } end
	end
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
	Hud.refreshShop()
	-- banner: island name + live kernels
	-- banner names (and themes) the island the bird is standing on
	local isl = Defs.ISLANDS[s.island]
	local ch = game:GetService("Players").LocalPlayer.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local here = if hrp then World.nearest(hrp.Position.X / 4 + 20, hrp.Position.Z / 4 + 15) else World.byId.park
	isl = { id = here.id }
	banner.name.set(here.name)
	-- long names shrink to stay clear of the kernel counter (plate face 298 wide, counter starts at 182)
	local nsc = banner.name.holder:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", {}, banner.name.holder)
	nsc.Scale = if #here.name > 12 then 0.8 elseif #here.name > 9 then 0.92 else 1
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
		local t = groupTiles[g.id]
		if t and t.unlocked ~= open then t.unlocked = open; if layoutBookmarks then task.defer(layoutBookmarks) end end
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
	local dock = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, DOCK_IN, 0, DOCK_Y), Size = UDim2.fromOffset(500, 1028), ZIndex = 5 }, canvas)
	Hud.dock = dock
	buildBookmarks(dock)
	local ids = table.clone(Spec.MENU)
	for _, id in { "baits", "index", "aquarium" } do table.insert(ids, id) end
	for _, id in ids do
		-- wrapper carries the fit-to-height scale; the window root keeps its own open/close scale
		-- anchored top-right so a scaled-down window stays in the corner against the wall
		local holder = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(500, 100), ZIndex = 5 }, dock)
		local api = Windows.build(holder, id, act)
		holder.Size = UDim2.fromOffset(500, api.H)
		api.root.Position = UDim2.fromScale(0.5, 0.5)
		Kit.new("UIScale", { Scale = math.min(1, WIN_MAX_H / api.H), Name = "Fit" }, holder)
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
	gui.Parent:GetAttributeChangedSignal("PeckwoodShop"):Connect(function() Hud.openShop() end)   -- QA: toggle the shop
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
			dock.AnchorPoint = Vector2.new(1, 0); dock.Position = UDim2.new(1, DOCK_IN, 0, DOCK_Y); layout()
		end
	end
	gui.Parent:GetAttributeChangedSignal("PeckwoodQA"):Connect(qa)
	gui.Parent:GetAttributeChangedSignal("PeckwoodQAY"):Connect(qa)
end

return Hud
