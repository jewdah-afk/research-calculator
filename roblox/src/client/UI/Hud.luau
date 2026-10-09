--!nonstrict
-- Hud: the in-game HUD, built from the Figma HUD board 213:7 (every piece is the Figma component rendered by
-- UI/Figma/Render) and placed the way the owner asked (2026-10-09 screenshot direction) on Birb's screen split
-- (UI/Layout): the upgrades sidebar is a permanent right column and the HUD lives in the game area left of it,
-- re-flowing when the sidebar collapses. Every spacing value comes from Layout.S (8 px grid at 1080p).
--   top-left      area banner (the area name), then ONE column of currency chips going down in progression order
--                 (eggs big, then plumes, seeds, twigs, moneta, golden, ore, echo, skill points): value right-aligned,
--                 rate under it. The column shrinks before it ever reaches the bottom.
--   top-centre    the area meter (every area, the Park too), up arrow under it, toasts under that
--   top-right     COMPANIONS [TAB] against the sidebar: a pull-down board on a roller (UI/CompanionsBoard), AUTO
--                 under the tucked roller, the area rail under AUTO
--   mid-left/-right  travel arrows named after their destination (locked: dimmed + padlock, the requirement in a
--                 tooltip); the left one clears the wallet column, the right one the rail
--   bottom-centre one row of icon keys (labels on hover), the objective just above it, the hotbar above that, the
--                 down arrow left of the objective
-- Windows open in the WINDOW REGION between those bands (Layout.setRegion). Feel: counters roll, "+N" floaters fly
-- icons into the wallet, badges (max 2), toasts stack with a spring above any window, a centred banner for big
-- moments, keyboard: Tab companions, Q objectives, P profile. Anything without a game system reads UI/SampleData.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GroupService = game:GetService("GroupService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local Shared = RS:WaitForChild("Peckwood")
local Defs = require(Shared:WaitForChild("Defs"))
local World = require(Shared:WaitForChild("World"))
local Icons = require(Shared:WaitForChild("Icons"))
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
local Board = require(script.Parent.CompanionsBoard)
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
local overlay            -- toasts, big moments and tooltips: above every window
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

-- display-only components built from key layouts (wallet chips, banner, meters): no press wiring
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
local function deep(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in t do o[k] = deep(v) end
	return o
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
local function group(name, size, sc, parent)
	local g = Render.new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 5 }, parent or canvas)
	local u = Render.new("UIScale", { Scale = sc }, g)
	g:SetAttribute("baseScale", sc)
	groups[name] = g
	return g, u
end
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

-- ---------------------------------------------------------------- tooltips (labels on hover / tap)
local tip, tipLabel, tipToken = nil, nil, 0
local function buildTip()
	tip = Render.new("Frame", { Name = "tooltip", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 32), AnchorPoint = Vector2.new(0.5, 1), Visible = false, ZIndex = 200 }, overlay)
	Render.gradient(tip, FKit.vgrad({ "3a4455", "232a35" }), 1)
	Render.new("UICorner", { CornerRadius = UDim.new(0, 3) }, tip)
	Render.new("UIStroke", { Thickness = 2, Color = Render.INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tip)
	Render.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tip)
	tipLabel = Render.new("TextLabel", { Name = "text", BackgroundTransparency = 1, FontFace = Render.FONT, TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), Text = "", ZIndex = 201 }, tip)
	Render.new("UIStroke", { Thickness = 1.4, Color = Render.INK, LineJoinMode = Enum.LineJoinMode.Round }, tipLabel)
end
-- show a tooltip over (or under, near the top) a GuiObject; seconds = auto-hide (tap)
function Hud.showTip(inst, text, seconds)
	if not (tip and inst and text and text ~= "") then return end
	tipToken += 1
	local token = tipToken
	local s = scale.Scale
	local x = (inst.AbsolutePosition.X + inst.AbsoluteSize.X / 2) / s
	local topY = inst.AbsolutePosition.Y / s
	tipLabel.Text = text
	local w = Render.textWidth(tipLabel, text, 16) + 24
	x = math.clamp(x, w / 2 + SP.GAP, Layout.W - w / 2 - SP.GAP)
	if topY < 60 then
		tip.AnchorPoint = Vector2.new(0.5, 0)
		tip.Position = UDim2.fromOffset(x, (inst.AbsolutePosition.Y + inst.AbsoluteSize.Y) / s + 6)
	else
		tip.AnchorPoint = Vector2.new(0.5, 1)
		tip.Position = UDim2.fromOffset(x, topY - 6)
	end
	tip.Visible = true
	if seconds then task.delay(seconds, function() if tipToken == token then tip.Visible = false end end) end
end
function Hud.hideTip() if tip then tipToken += 1; tip.Visible = false end end
-- a hover tooltip on a key (its Motion.key hit); textFn() -> text or nil
function Hud.tooltip(inst, textFn)
	local api = Motion.keyOf(inst)
	local hit = (api and api.hit) or inst:FindFirstChild("hit")
	if not hit then return end
	hit.MouseEnter:Connect(function() Hud.showTip(inst, textFn()) end)
	hit.MouseLeave:Connect(Hud.hideTip)
end

-- ---------------------------------------------------------------- top-left: banner + the wallet column
local banner
-- progression order: Birb's column (eggs, plumes, seeds, twigs, moneta; evolution_3/map0.jpg), then ours
local WALLET_ORDER = { "popcorn", "goldenFeathers", "sunflowerSeeds", "twigs", "moneta", "goldenPopcorn", "bruteOre", "echoPopcorn", "skillPoints" }
local CHIP = { popcorn = "chip-main/popcorn", goldenFeathers = "chip/plume", sunflowerSeeds = "chip/seed", moneta = "chip/moneta", twigs = "chip/twig",
	goldenPopcorn = "chip/egg_golden", bruteOre = "chip/ore", echoPopcorn = "chip/echo", skillPoints = "chip/skill_point" }
local CHIP_UNLOCK = { goldenFeathers = 2, sunflowerSeeds = 3, moneta = 5, twigs = 6, bruteOre = 7, goldenPopcorn = 8, skillPoints = 9, echoPopcorn = 10 }
local CHIP_W = 300          -- every chip the same width (design px, before the wallet scale)
local chips = {}
local walletW, walletH = CHIP_W, 92
-- a Figma chip re-laid for the column: same look, CHIP_W wide, value right-aligned with the rate under it (Birb), no
-- engraved name. The main (eggs) chip stays taller with bigger numbers.
local RATE_TF
local function chipNode(comp, main)
	local n = deep(S.chips.C["hud/" .. comp])
	local key = Render.findNode(n, "key (Kit.button)")
	local face = Render.findNode(key, "face")
	local well = Render.findNode(face, "well")
	local dh = if main then 0 else 8
	n.w = CHIP_W; n.h += dh
	for _, c in n.k do if c.n == "soft shadow" then c.w = CHIP_W - 50; c.h += dh end end
	key.w = CHIP_W - key.x; key.h += dh
	for _, c in key.k do
		if c.n == "ink body" then c.w = key.w; c.h += dh
		elseif c.n == "lip" or c.n == "face" then c.w = key.w - 6; c.h += dh end
	end
	for _, c in face.k do if c.n == "gloss cap" then c.w = face.w - 2 * c.x end end
	well.w = face.w - well.x - 8; well.h += dh
	local kept, rate = {}, nil
	for _, c in well.k do
		if c.n == "inner shadow" then c.w = well.w; c.h = well.h; table.insert(kept, c)
		elseif c.n == "value" then
			c.x = 8; c.w = well.w - 16; c.ax = "R"
			if main then c.y = 0; c.fs = 32; c.h = 38 else c.y = 1; c.fs = 20; c.h = 24 end
			table.insert(kept, c)
		elseif c.n == "rate" then rate = c
		elseif c.n ~= "name tag" then table.insert(kept, c) end
	end
	if main and rate then RATE_TF = rate.tf end
	rate = rate or { t = "T", n = "rate", tx = "", ay = "T", tf = RATE_TF, sw = 1.6, sh = { 0, 1 } }
	rate.x = 8; rate.w = well.w - 16; rate.ax = "R"
	if main then rate.y = 34; rate.h = 16; rate.fs = 14 else rate.y = 24; rate.h = 14; rate.fs = 12 end
	table.insert(kept, rate)
	well.k = kept
	for _, c in n.k do if c.t == "I" then c.y += dh / 2 end end
	return n, key
end
local function chipApi(ui, main, node, key)
	local value, rate = setT(ui.root, "value", "0"), ui.root:FindFirstChild("rate", true)
	local x0, y0 = Layout.bounds(node)
	local c = { ui = ui, value = value, rate = rate, main = main, shown = 0, x0 = x0, iconTop = y0, keyTop = key.y, keyBottom = key.y + key.h,
		valueY = value and value.Position.Y.Offset, wellH = node and Render.findNode(key, "well").h }
	if value then Render.fit(value, 12) end
	if rate then Render.fit(rate, 9) end
	for _, d in ui.root:GetDescendants() do
		if d:IsA("ImageLabel") and d.Name:sub(1, 4) == "ico/" then c.icon = d end
	end
	return c
end
local function buildTopLeft()
	local tl = group("banner", Vector2.new(372, 82), SP.HUD)
	banner = Render.component(S.prompts, "hud/banner/the bridge", tl)
	inert(banner)
	-- the banner is just the area name now (the egg count moved to the area meter, top-centre)
	local cnt = banner.root:FindFirstChild("egg count", true)
	if cnt then cnt.Visible = false end
	local areaL = banner.root:FindFirstChild("area", true)
	if areaL then
		areaL.Size = UDim2.fromOffset(372 - 36, areaL.Size.Y.Offset)
		local sh = Render.SHADOW[areaL]; if sh then sh.Size = areaL.Size end
		Render.fit(areaL, 16)
	end
	local w = group("wallet", Vector2.new(CHIP_W, 600), SP.WALLET)
	for _, cur in WALLET_ORDER do
		local main = cur == "popcorn"
		local node, key = chipNode(CHIP[cur], main)
		local ui = Render.build({ P = S.chips.P, root = node }, w, node)
		inert(ui)
		ui.root.Visible = main
		chips[cur] = chipApi(ui, main, node, key)
	end
end
-- one column: visual left edges on 0, the keys GAP apart, the first chip's icon overhang inside the top
local function walletRate(cur)
	if not derived then return nil end
	if cur == "popcorn" then return derived.popPerSec elseif cur == "sunflowerSeeds" then return derived.seedsPerSec
	elseif cur == "twigs" then return derived.twigsPerSec elseif cur == "bruteOre" then return derived.orePerSec end
	return nil
end
local function layoutWallet()
	local sc = SP.WALLET
	local y = 0
	local first = true
	for _, cur in WALLET_ORDER do
		local c = chips[cur]
		local show = cur == "popcorn" or (state ~= nil and (CHIP_UNLOCK[cur] or 99) <= state.island and EN.me(state[cur], 0))
		if cur == "goldenFeathers" and state and state.island >= 2 then show = true end
		c.ui.root.Visible = show
		if show then
			if first then y = c.keyTop - c.iconTop end   -- room for the eggs icon above the first key
			first = false
			c.ui.root.Position = UDim2.fromOffset(-c.x0, y - c.keyTop)
			y += (c.keyBottom - c.keyTop) + SP.GAP / sc
			-- rate under the value; a currency without a rate centres its value in the well
			local r = walletRate(cur)
			if c.rate then
				local has = r ~= nil and EN.toNumber(r) > 0
				c.rate.Visible = has
				local sh = Render.SHADOW[c.rate]; if sh then sh.Visible = has end
				if has then Render.setText(c.rate, "+" .. fmt(r) .. "/s") end
				if c.value and c.valueY and not c.main then
					local vy = if has then c.valueY else math.floor((c.wellH - c.value.Size.Y.Offset) / 2)
					if c.value.Position.Y.Offset ~= vy then
						c.value.Position = UDim2.fromOffset(c.value.Position.X.Offset, vy)
						local vsh = Render.SHADOW[c.value]
						if vsh then vsh.Position = c.value.Position + UDim2.fromOffset(0, 1) end
					end
				end
			end
		end
	end
	walletH = math.max(1, y - SP.GAP / sc)
	groups.wallet.Size = UDim2.fromOffset(walletW, walletH)
end

-- odometer: a chip value rolls to its new number; a gain pulses the value and flashes the +rate green
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
		Kit.pop(c.value, 1.04)
		if c.rate and c.rate.Visible then Motion.flashText(c.rate, "d6ffdd") end
	end
end

-- currency icons arc from a point into their wallet chip, each landing with a tick and a chip bump
local function flyFrom(cur, a: Vector2, n, size)
	local c = chips[cur]; if not (c and c.icon and c.ui.root.Visible) then return end
	local b = centreOf(c.icon)
	local id = c.icon.Image
	for i = 1, n or 1 do
		local img = Render.new("ImageLabel", { BackgroundTransparency = 1, Image = id, Size = UDim2.fromOffset(size, size), ZIndex = 60, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(a.X, a.Y) }, overlay)
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
				Kit.pop(c.icon, 1.08)
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
	Motion.floater(overlay, d, "+" .. (if value then EN.short(value) else "1"), if cur == "goldenPopcorn" then "ffd84a" else "fff1a8", 26)
	task.delay(0.18, function() flyFrom(cur, d, if cur == "goldenPopcorn" then 3 else 2, 30) end)
end

-- ---------------------------------------------------------------- top-right: COMPANIONS board, AUTO, area rail
local companions, autoKey, board
local companionsOpen = false   -- remembered (player pref)
local COMPANION_ROWS = {   -- Figma row name -> window id, unlock window (WINDOW_ISLAND gate)
	{ "row/SPARROW", "sparrow", "sparrow" }, { "row/SEAGULL", "seagull", "seagull" }, { "row/BAMBOO", "redpanda", "redpanda" },
	{ "row/CROW", "crow", "mine" }, { "row/DAVE", "dave", "dave" }, { "row/PARROT", "parrot", "parrot" },
}
local COMP_W, HEADER_H = 300, 57
local rowFrames = {}
local function unlockedWindow(w)
	return state ~= nil and (Defs.WINDOW_ISLAND[w] or 1) <= state.island
end
local reflow   -- forward
local function unlockText(w)
	local i = Defs.WINDOW_ISLAND[w]
	local isl = i and Defs.ISLANDS[i]
	if not isl then return "Unlocks later" end
	return "Unlocks at " .. (string.gsub(string.lower(isl.name), "(%a)([%w]*)", function(x, y) return string.upper(x) .. y end))
end
local rowsPlaced = false
local function rowLook(row, locked, w)
	if row:GetAttribute("locked") == locked then return end
	row:SetAttribute("locked", locked)
	for _, d in row:GetChildren() do
		if d:IsA("ImageLabel") and d.Name:sub(1, 4) == "ico/" then
			d.ImageTransparency = if locked then 0.55 else 0
			d.ImageColor3 = if locked then Color3.fromHex("8d94a3") else Color3.new(1, 1, 1)
		elseif d.Name == "level" then d.Visible = not locked
		elseif d:IsA("TextLabel") and not string.find(d.Name, "drop") and d.Name ~= "unlock note" then
			if d.Text == "\u{203A}" or d.Position.X.Offset > 250 then
				d.Visible = not locked
				local sh = Render.SHADOW[d]; if sh then sh.Visible = not locked end
			else
				-- the name moves up a little to make room for the note
				local base = d:GetAttribute("baseY") or d.Position.Y.Offset
				d:SetAttribute("baseY", base)
				d.Position = UDim2.fromOffset(d.Position.X.Offset, if locked then base - 7 else base)
				Render.setTextColor(d, Color3.fromHex(if locked then "8d94a3" else "ffffff"))
				local sh = Render.SHADOW[d]; if sh then sh.Position = d.Position + UDim2.fromOffset(0, 2) end
			end
		end
	end
	local note = row:FindFirstChild("unlock note")
	if note then note.Visible = locked; Render.setText(note, unlockText(w)) end
	local lock = row:FindFirstChild("lock")
	if lock then lock.Visible = locked end
end
local function layoutCompanions()
	if not companions then return end
	if not rowsPlaced then
		rowsPlaced = true
		local list = {}
		for _, r in COMPANION_ROWS do if rowFrames[r[1]] then table.insert(list, rowFrames[r[1]]) end end
		board:setRows(list)
	end
	for _, r in COMPANION_ROWS do
		local row = rowFrames[r[1]]
		if row and state then rowLook(row, not unlockedWindow(r[3]), r[3]) end
	end
	-- the board covers the AUTO slot (Birb): AUTO hides while it is down
	if autoKey then autoKey.root.Visible = not companionsOpen end
end
local function setCompanions(on, animate, save)
	if on == companionsOpen then return end
	companionsOpen = on
	board:setOpen(on, animate ~= false)
	if autoKey then
		if on then autoKey.root.Visible = false
		else task.delay(if animate ~= false then Board.T.up + 0.1 else 0, function() if not companionsOpen and autoKey then autoKey.root.Visible = true end end) end
	end
	if save ~= false then
		plr:SetAttribute("PeckwoodCompanions", on)
		if Remotes then Remotes.Action:FireServer("pref", "companions", on) end
	end
end
local function toggleCompanions() setCompanions(not companionsOpen, true) end
Hud.toggleCompanions = toggleCompanions

local function onAuto()
	if not derived then return end
	if not derived.autoAllowed and derived.groupId and derived.groupId > 0 then
		pcall(function() GroupService:PromptJoinAsync(derived.groupId) end)
	end
	local on = not (state and state.auto)
	Sfx.toggle(on)
	act("auto", on)
end
Hud.onAuto = onAuto

local function buildCompanions()
	local g = group("companions", Vector2.new(COMP_W, HEADER_H + Board.closedFootprint()), SP.HUD)
	g.ZIndex = 8   -- the board drops over the AUTO slot and the rail
	companions = Render.component(S.companions, "hud/companions (open)", g)
	companions.root.ZIndex = 3   -- the header sits over the board's top edge (the roller tucks under it)
	companions.on("header key", toggleCompanions)
	-- the rows' Figma drop shadows are siblings in the component: they would stay behind as black blocks when the
	-- rows move onto the board, so the board draws its own depth instead
	for _, c in companions.node:GetChildren() do
		if (c.Name == "drop" or c.Name == "shadow") and c:IsA("GuiObject") and c.Position.Y.Offset > HEADER_H then c:Destroy() end
	end
	board = Board.new(g, 0, HEADER_H - 2, COMP_W, toggleCompanions, Icons)
	for _, r in COMPANION_ROWS do
		local row = companions.node:FindFirstChild(r[1])
		if row then
			rowFrames[r[1]] = row
			local note = Render.new("TextLabel", { Name = "unlock note", BackgroundTransparency = 1, FontFace = Render.FONT, TextSize = 13, TextColor3 = Color3.fromHex("c9d2e3"),
				TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(118, 29), Size = UDim2.fromOffset(150, 16), Text = "", Visible = false, ZIndex = 20 }, row)
			Render.new("UIStroke", { Thickness = 1.2, Color = Render.INK, LineJoinMode = Enum.LineJoinMode.Round }, note)
			Render.new("ImageLabel", { Name = "lock", BackgroundTransparency = 1, Image = FKit.icon("lock"), Position = UDim2.fromOffset(262, 13), Size = UDim2.fromOffset(26, 26),
				Visible = false, ZIndex = 20 }, row)
			button(row, function()
				if not unlockedWindow(r[3]) then Sfx.denied(); Hud.showTip(row, unlockText(r[3]), 2.2); return end
				Sfx.rowSelect(); openFrom(r[2], row)
			end, "row")
		end
	end
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

-- area rail (our addition): under AUTO against the sidebar; open = coloured key, current = popped out, locked =
-- grey + lock; click = travel
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
local function goalOf(id)
	for _, x in Defs.ISLANDS do if x.id == id then return x.goal end end
	return "Keep going"
end
Hud.goalOf = goalOf
local function travelTo(id, fromInst)
	if ROOM[id] then
		if fromInst then openFrom(id, fromInst) else WM.open(id) end
		return
	end
	local isl = World.byId[id]
	if not isl then return end
	if not World.isOpen(isl) then
		Sfx.denied()
		if fromInst then Hud.showTip(fromInst, goalOf(id), 2.4) else Hud.toast("Locked: " .. goalOf(id), "error", "map") end
		return
	end
	plr.PlayerGui:SetAttribute("PeckwoodTP", id .. "#" .. os.clock())
end
Hud.travelTo = travelTo
local function setTopLeft(inst, x, y, animate)   -- keys are centre-anchored
	local p = UDim2.fromOffset(x + inst.AnchorPoint.X * inst.Size.X.Offset, y + inst.AnchorPoint.Y * inst.Size.Y.Offset)
	if animate and not Kit.reduced() then TweenService:Create(inst, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = p }):Play()
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
			local api = Motion.keyOf(slot) or Motion.key(slot, "rail")
			Motion.setKind(slot, "rail")
			api.hit.Activated:Connect(function() travelTo(r[2], slot) end)
			Hud.tooltip(slot, function()
				local isl = World.byId[r[2]]
				return if isl and not World.isOpen(isl) then goalOf(r[2]) else nil
			end)
		end
	end
	local aapi = railActive and (Motion.keyOf(railActive) or Motion.key(railActive, "rail"))
	if railActive then Motion.setKind(railActive, "rail") end
	local CONTEXT_WIN = { bridge = "fishing", mine = "mine", expedition = "expedition", echo = "trees", desert = "trees", forest = "nest" }
	if aapi then aapi.hit.Activated:Connect(function() if railArea and CONTEXT_WIN[railArea] then openFrom(CONTEXT_WIN[railArea], railActive) end end) end
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
			-- the current area's slot slides out (no overshoot: classy)
			setTopLeft(railActive, 0, 4 + 76 * (idx - 1) + 3 - 4, true)
		end
	end
end

-- ---------------------------------------------------------------- top-centre: the area meter, up arrow, toasts
local context, contextKind = nil, nil
-- every area has a meter (Birb): the egg field (Park / Garden / Castle) uses the echo-field bar, retinted
local AREA_CONTEXT = { bridge = "fishing", mine = "mine", expedition = "expedition", echo = "echo", desert = "desert", forest = "nest",
	park = "field", garden = "field", castle = "field" }
local CONTEXT_WINDOW = { fishing = "fishing", mine = "mine", expedition = "expedition", echo = "trees", desert = "trees", nest = "nest", field = "objectives" }
local CONTEXT_TAB = { echo = "ARCHIVIST", desert = "DESERT" }
local FIELD_ICONS = { "popcorn", "clock", "plume" }
local function buildContext(kind, area)
	if context then context.root:Destroy(); context = nil end
	contextKind = kind
	if not kind then return end
	context = Render.component(S.context, "hud/context/" .. (if kind == "field" then "echo" else kind), groups.context)
	inert(context)
	button(context.root, function() openFrom(CONTEXT_WINDOW[kind], context.root, CONTEXT_TAB[kind]) end)
	context.fill = context.root:FindFirstChild("fill", true)
	context.fillW = context.fill and context.fill.Parent.Size.X.Offset
	context.info = {}
	for _, d in context.root:GetDescendants() do
		if d:IsA("TextLabel") and d.RichText and d.Parent.Name == "info strip" then table.insert(context.info, d) end
	end
	table.sort(context.info, function(a, b) return a.Position.X.Offset < b.Position.X.Offset end)
	if kind == "field" then
		-- eggs on the field: gold fill, the area's colour on the badge, egg / clock / plume info icons
		if context.fill then retint(context.fill, FKit.vgrad(FKit.PAL.gold)) end
		local badge = context.root:FindFirstChild("level badge", true)
		local cols = areaColours(area)
		if badge and cols then retint(badge:FindFirstChild("face"), cols.face); retint(badge:FindFirstChild("lip"), cols.lip) end
		local strip = context.root:FindFirstChild("info strip", true)
		local icons = {}
		for _, d in (strip and strip:GetChildren() or {}) do if d:IsA("ImageLabel") and d.Name:sub(1, 4) == "ico/" then table.insert(icons, d) end end
		table.sort(icons, function(a, b) return a.Position.X.Offset < b.Position.X.Offset end)
		for i, d in icons do d.Image = FKit.icon(FIELD_ICONS[i] or "popcorn") end
		for _, d in (badge and badge:GetDescendants() or {}) do
			if d:IsA("ImageLabel") and (d.Name:sub(1, 4) == "ico/" or d.Name == "drop") then d.Image = FKit.icon("popcorn") end
		end
		local title = context.root:FindFirstChild("title", true)
		if title then Render.fit(title, 10) end
	end
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
		-- level up: badge punch + sparkles + the bar shimmers (an outcome)
		local badge = context.root:FindFirstChild("level badge", true)
		if badge then Kit.pop(badge, 1.1); Motion.burst(overlay, centreOf(badge), 6, 22) end
		if context.fill then Motion.shimmer(context.fill.Parent) end
		Sfx.levelUp()
	end
	lastLevel[kind] = lv
end
local function updateContext(area, here)
	local kind = AREA_CONTEXT[area]
	if kind ~= contextKind or (kind == "field" and context and context.area ~= area) then
		buildContext(kind, area)
		if context then context.area = area end
		if reflow then reflow(false) end
	end
	if not (context and state) then return end
	local SD = SampleData.context[kind]
	if kind == "field" then
		setT(context.root, "title", string.upper(here and here.name or "THE PARK"))
		setContextBar(Hud.kernelCount / math.max(1, derived.cap), Hud.kernelCount .. " / " .. derived.cap .. " on the field")
		setInfo(1, "+" .. fmt(derived.kernelValue or 1), " per egg")
		setInfo(2, "+" .. fmt(derived.popPerSec or 0), " / s")
		if state.island >= 2 then setInfo(3, "+" .. fmt(derived.plumeGain or 0), " plumes") else setInfo(3, commas(state.rebirbCount or 0), " molts") end
	elseif kind == "fishing" then
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
-- auto-dismiss line, hold 2.5 s, and a click dismisses them. At most 3 at once. They live on the overlay (above windows).
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
	TweenService:Create(ui.root, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
	Motion.burst(g, Vector2.new(g.Size.X.Offset / 2, g.Size.Y.Offset / 2), 8, 30)
	task.delay(1.9, function()
		local tw = TweenService:Create(ui.root, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0.5, -160) })
		tw:Play()
		tw.Completed:Once(function() ui.root:Destroy() end)
	end)
end
Hud.bigMoment = bigMoment

-- ---------------------------------------------------------------- bottom: icon row, objective, hotbar
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
	if not kind then if reflow then reflow(false) end; return end
	local ui = Render.component(S.hotbar, "hud/hotbar/" .. variant, groups.hotbar)
	ui.kind, ui.variant = kind, variant
	if kind == "fishing" then
		ui.on("cast key", function() act("fish", "go") end)
		for _, d in ui.node:GetChildren() do
			if d.Name:sub(1, 5) == "slot/" then button(d, function() openFrom("fishing", d, "EQUIPMENT") end, "cell") end
		end
	elseif kind == "mine" then
		ui.on("challenge key", function(inst) openFrom("mine", inst, "AREAS") end)
	elseif kind == "expedition" then
		ui.on("reset floor key", function() act("expedition") end)
		for _, d in ui.node:GetChildren() do
			if d.Name:sub(1, 5) == "slot/" then button(d, function() openFrom("parrot", d, "EQUIPMENT") end, "cell") end
		end
	end
	hotbar = ui
	if reflow then reflow(false) end
end
-- one row of icon keys centred at the bottom (labels on hover). Birb's core keys (fast travel, map, profile,
-- settings) keep Birb's order at the right end; ours extend it to the left.
local TILE_ORDER = { "fish", "pets", "auto", "shop", "teleport", "map", "profile", "settings" }
local TILE_LABEL = { fish = "FISHING", pets = "COMPANIONS  [TAB]", auto = "AUTO", shop = "SHOP", teleport = "FAST TRAVEL", map = "MAP",
	profile = "PROFILE  [P]", settings = "SETTINGS" }
local tiles = {}
local TILE_ACTION = {
	map = function()
		local on = not plr.PlayerGui:GetAttribute("PeckwoodMap")
		plr.PlayerGui:SetAttribute("PeckwoodMap", on)
		Sfx.toggle(on)
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
local TILE_S = 0.5                          -- 52 px keys at 1080p
local TILE_W, TILE_H = 104, 111            -- the key body (the lip makes the node 119 tall)
local TILE_PITCH = TILE_W + SP.GAP / TILE_S
local function buildTiles()
	local g = group("tiles", Vector2.new(TILE_PITCH * (#TILE_ORDER - 1) + TILE_W, 119), TILE_S)
	for i, id in ipairs(TILE_ORDER) do
		local ui = Render.component(S.tiles, "hud/tile/" .. id, g)
		ui.root.Position = UDim2.fromOffset((i - 1) * TILE_PITCH, 0)
		ui.on("hud/tile/" .. id, function(inst) TILE_ACTION[id](inst) end)
		Motion.setKind(ui.node, "tile")
		-- icon only: the label goes to the hover tooltip, the icon centres and grows into the face
		local body = ui.node:FindFirstChild("body")
		for _, d in (body and body:GetChildren() or {}) do
			if d:IsA("TextLabel") then d.Visible = false end
			if d:IsA("ImageLabel") and (d.Name:sub(1, 4) == "ico/" or d.Name == "drop") then
				local s = 80
				d.Size = UDim2.fromOffset(s, s)
				d.Position = UDim2.fromOffset((body.Size.X.Offset - s) / 2 + (if d.Name == "drop" then 0 else 0), (body.Size.Y.Offset - s) / 2 + (if d.Name == "drop" then 2 else 0))
			end
		end
		Hud.tooltip(ui.node, function() return TILE_LABEL[id] end)
		tiles[id] = ui
	end
	-- Fast Travel pops up right above its key
	WM.anchors.teleport = function()
		local r = tiles.teleport.node
		local p = centreOf(r)
		return Vector2.new(p.X, r.AbsolutePosition.Y / scale.Scale)
	end
end

-- travel arrows (Birb map arrows): left / right along the chain, up / down to rooms. The label is always the
-- destination's name; a locked one is the dimmed Figma chip with its padlock and the requirement in a tooltip.
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
				for _, k in ui.keys do Motion.setKind(k.inst, "arrow") end
			end
		end
		if locked then
			for _, k in locked.keys do
				Hud.tooltip(k.inst, function() local t = arrows[dir].target; return t and goalOf(t) or nil end)
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
local function updateArrows(area)
	local t = TRAVEL[area] or {}
	local changed = false
	for dir, a in arrows do
		local id = t[dir]
		local wasTarget = a.target
		a.target = id
		local open = id ~= nil and (ROOM[id] ~= nil or (World.byId[id] ~= nil and World.isOpen(World.byId[id])))
		local vis = id ~= nil and open
		if a.open.root.Visible ~= vis then changed = true end
		a.open.root.Visible = vis
		if a.locked then a.locked.root.Visible = id ~= nil and not open end
		if id then
			setArrowLabel(a.open, destName(id))
			if a.locked then setArrowLabel(a.locked, destName(id)) end
			-- an arrow whose destination just unlocked pulses once (an outcome)
			if open and a.wasLocked and wasTarget == id then Kit.pop(a.open.root, 1.08) end
		end
		a.wasLocked = id ~= nil and not open
	end
	if changed and reflow then reflow(false) end
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
-- a red count bubble inside a sidebar tab / icon key when something new or affordable appears; it eases in once and
-- bumps when the count rises. Priority: MOLT > FISH > EGGS > SEEDS, only the top 2 show.
local badges = {}
local BADGE_PRIORITY = { "molt", "fish", "eggs", "seeds" }
local function scaleUnder(inst)   -- product of the UIScales between a GuiObject and the HUD / window canvas
	local s, p = 1, inst
	while p and p.Name ~= "canvas" do
		local u = p:FindFirstChildOfClass("UIScale")
		if u and u.Name ~= "Settle" and u.Name ~= "Pop" then s *= u.Scale end
		p = p.Parent
	end
	return s
end
-- the MOLT tab carries its pending plume gain as a violet chip inside the tab under the label (Birb's REBIRB tab)
local function tabLabelUp(host, up)
	for _, c in host:GetChildren() do
		if (c:IsA("TextLabel") or c:IsA("ImageLabel")) and c.Name ~= "badge" then
			local b = c:GetAttribute("baseY") or c.Position.Y.Offset
			c:SetAttribute("baseY", b)
			c.Position = UDim2.fromOffset(c.Position.X.Offset, if up then b - 8 else b)
		end
	end
end
local function badgeOn(key, host, text)
	local b = badges[key]
	if b and b.host ~= host then if b.frame then b.frame:Destroy() end; if key == "molt" and b.host.Parent then tabLabelUp(b.host, false) end; b = nil; badges[key] = nil end
	if not b and key == "molt" then
		local k = 1 / math.max(0.3, scaleUnder(host))
		local f = Render.new("Frame", { Name = "badge", BackgroundColor3 = Color3.fromHex("8a4fe0"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.fromOffset(20 * k, 18), ZIndex = 1000, AutomaticSize = Enum.AutomaticSize.X }, host)
		Render.new("UICorner", { CornerRadius = UDim.new(0, 3) }, f)
		Render.new("UIStroke", { Thickness = 1.5, Color = Render.INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
		Render.new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, f)
		local l = Render.new("TextLabel", { Name = "count", BackgroundTransparency = 1, FontFace = Render.FONT, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), Text = text, ZIndex = 1001 }, f)
		Render.new("UIStroke", { Thickness = 1.2, Color = Render.INK, LineJoinMode = Enum.LineJoinMode.Round }, l)
		tabLabelUp(host, true)
		b = { frame = f, label = l, host = host, text = text }
		badges[key] = b
		return
	end
	if not b then
		-- inside the host's top-right corner (tab bars clip: zero clipping); the same on-screen size in any group
		local k = 1 / math.max(0.3, scaleUnder(host))
		local f = Render.new("Frame", { Name = "badge", BackgroundColor3 = Color3.fromHex("e8344f"), BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3 * k, 0, 3 * k), Size = UDim2.fromOffset(28 * k, 22 * k), ZIndex = 1000, AutomaticSize = Enum.AutomaticSize.X }, host)
		Render.new("UICorner", { CornerRadius = UDim.new(0, 4 * k) }, f)
		Render.new("UIStroke", { Thickness = 2 * k, Color = Render.INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
		Render.new("UIPadding", { PaddingLeft = UDim.new(0, 6 * k), PaddingRight = UDim.new(0, 6 * k) }, f)
		local l = Render.new("TextLabel", { Name = "count", BackgroundTransparency = 1, FontFace = Render.FONT, TextSize = 15 * k, TextColor3 = Color3.new(1, 1, 1),
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22 * k), Text = text, ZIndex = 1001 }, f)
		Render.new("UIStroke", { Thickness = 1.4 * k, Color = Render.INK, LineJoinMode = Enum.LineJoinMode.Round }, l)
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
	if b then
		if b.frame then b.frame:Destroy() end
		if key == "molt" and b.host and b.host.Parent then tabLabelUp(b.host, false) end
		badges[key] = nil
	end
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
local walletScale = SP.WALLET
function reflow(animate)
	if not canvas then return end
	local H, top, edge = Layout.H, Layout.TOP, SP.EDGE
	local colR = Layout.columnRight()
	local cx = Layout.gameCentre()
	-- top-left: banner, then the wallet column (visual edges on EDGE, GAP between); it shrinks before it reaches
	-- the bottom edge
	local bx0, by0, _, by1 = vb(S.prompts, "hud/banner/the bridge", SP.HUD)
	place("banner", Vector2.new(0, 0), edge - bx0, top - by0, false)
	local wTop = top + (by1 - by0) + SP.GAP
	local avail = H - edge - wTop
	walletScale = SP.WALLET
	if walletH * walletScale > avail then walletScale = math.max(0.45, avail / walletH) end
	groups.wallet:FindFirstChildOfClass("UIScale").Scale = walletScale
	place("wallet", Vector2.new(0, 0), edge, wTop, false)
	local walletRight = edge + walletW * walletScale
	local walletBottom = wTop + walletH * walletScale
	-- top-right, against the sidebar: COMPANIONS header + board, AUTO under the tucked roller, the rail under AUTO
	local compW = COMP_W * SP.HUD
	place("companions", Vector2.new(0, 0), colR - compW, top, animate)
	local footY = top + (HEADER_H + Board.closedFootprint()) * SP.HUD
	local _, _, ax1 = vb(S.auto, "hud/auto/fish on", SP.HUD)
	local autoX0 = colR - ax1
	local autoY = footY + SP.GAP
	place("auto", Vector2.new(0, 0), autoX0, autoY, animate)
	local autoBottom = autoY + 64 * SP.HUD
	local railL = colR - 100 * SP.RAIL
	place("rail", Vector2.new(0, 0), railL, autoBottom + SP.GAP2, animate)
	-- bottom-centre: the icon row at the bottom, the objective just above it, the hotbar above that
	local tilesW, tilesH = (TILE_PITCH * (#TILE_ORDER - 1) + TILE_W) * TILE_S, TILE_H * TILE_S
	local tilesTop = H - edge - tilesH
	place("tiles", Vector2.new(0.5, 0), cx, tilesTop, animate)
	local _ = tilesW
	local objW, objH = 680 * SP.HUD, 58 * SP.HUD
	local objY = tilesTop - SP.GAP - objH
	place("objective", Vector2.new(0.5, 0), cx, objY, animate)
	local hbVisible = hotbar ~= nil or (unlockKey ~= nil and unlockKey.root.Visible)
	local hbH = if hotbar then (hotbar.node.Size.Y.Offset - 7) * SP.HUD else 72 * SP.HUD
	local hbY = objY - SP.GAP - hbH
	place("hotbar", Vector2.new(0.5, 0), cx, hbY, animate)
	if hotbar then hotbar.root.AnchorPoint = Vector2.new(0.5, 0); hotbar.root.Position = UDim2.new(0.5, 0, 0, 0) end
	if unlockKey then unlockKey.root.AnchorPoint = Vector2.new(0.5, 0); unlockKey.root.Position = UDim2.new(0.5, 0, 0, 0) end
	-- down arrow: left of the objective, bottoms aligned
	place("travel down", Vector2.new(1, 0), cx - objW / 2 - SP.GAP2, objY + objH - 62 * SP.HUD, animate)
	-- top-centre: the area meter, the up arrow under it
	local ctxH = (if context then 98 else 0) * SP.CONTEXT
	place("context", Vector2.new(0.5, 0), cx, top, animate)
	local upY = top + ctxH + (if ctxH > 0 then SP.GAP2 else 0)
	place("travel up", Vector2.new(0.5, 0), cx, upY, animate)
	local upVisible = arrows.up and (arrows.up.open.root.Visible or (arrows.up.locked and arrows.up.locked.root.Visible))
	local upBottom = if upVisible then upY + 62 * SP.HUD else top + ctxH
	-- toasts (overlay, above windows): under the up arrow
	place("toast", Vector2.new(0.5, 0), cx, upBottom + SP.GAP2, animate)
	-- mid-left / mid-right travel arrows: the left one clears the wallet column, the right one the rail
	local leftX = if walletBottom > H / 2 - 40 then walletRight + SP.GAP2 else edge
	place("travel left", Vector2.new(0, 0.5), leftX, H / 2, animate)
	place("travel right", Vector2.new(1, 0.5), railL - SP.GAP2, H / 2, animate)
	-- [E] prompt and big moments: centre of the game area
	place("prompt", Vector2.new(0.5, 0), cx, Layout.snap(H * 0.6), animate)
	place("moment", Vector2.new(0.5, 0.5), cx, H * 0.4, animate)
	if devPanel then
		devPanel.AnchorPoint = Vector2.new(0.5, 0)
		devPanel.Position = UDim2.fromOffset(cx, SP.GAP)
	end
	-- the window region: between the top band and the bottom band, right of the wallet column, left of the rail.
	-- Two fits are measured (under AUTO with the full width, or under the area meter left of AUTO); the one that
	-- lets a 1200 x 880 window be bigger wins.
	local y1 = (if hbVisible then hbY else objY) - SP.GAP2
	local yA = math.max(top + ctxH, autoBottom) + SP.GAP2
	local yB = top + ctxH + SP.GAP2
	local x0A = if walletBottom > yA + 4 then walletRight + SP.GAP2 else edge
	local x0B = if walletBottom > yB + 4 then walletRight + SP.GAP2 else edge
	local x1A = Layout.windowRight()
	local x1B = math.min(Layout.windowRight(), autoX0 - SP.GAP2)
	local fitA = math.min((x1A - x0A) / 1200, (y1 - yA) / 880)
	local fitB = math.min((x1B - x0B) / 1200, (y1 - yB) / 880)
	if fitB > fitA then Layout.setRegion(x0B, yB, x1B, y1) else Layout.setRegion(x0A, yA, x1A, y1) end
	Hud.collapsed = not Layout.sidebarOpen
	Hud.dock.Visible = Layout.sidebarOpen
	if RobuxShop.reflow then RobuxShop.reflow(Layout.gameRight()) end
end

local function layoutCanvas()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.max(0.35, vp.Y / 1080)
	scale.Scale = s
	canvas.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
	overlay.Size = canvas.Size
	overlay:FindFirstChildOfClass("UIScale").Scale = s
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
local prefsApplied = false
function Hud.setState(s, d)
	state, derived = s, d
	WM.update(s, d)
	RobuxShop.setDerived(d)
	local here = currentArea()
	local area = here and (here.area or here.id) or "park"
	if banner then
		setT(banner.root, "area", here and here.name or "THE PARK")
		if area ~= lastArea then
			local cols = areaColours(area)
			if cols then retint(banner.node:FindFirstChild("body"), cols.face) end
		end
	end
	for cur in chips do if s[cur] then setChip(cur, s[cur]) end end
	local wasH = walletH
	layoutWallet()
	if math.abs(walletH - wasH) > 0.5 then reflow(false) end
	if objective then
		setT(objective.root, "goal", d.nextGoal)
		local frac = 0
		if d.nextCost then for cur, n in d.nextCost do frac = math.min(1, EN.toNumber(s[cur]) / n) end end
		local fill = objective.root:FindFirstChild("fill", true)
		if fill then TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(math.floor(600 * frac + 0.5), fill.Size.Y.Offset) }):Play() end
		local showUnlock = d.nextCost ~= nil and not hotbar
		if unlockKey.root.Visible ~= showUnlock then unlockKey.root.Visible = showUnlock; reflow(false) end
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
	updateContext(area, here)
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
	-- the board remembers its state (saved pref, else this session's attribute)
	if not prefsApplied then
		prefsApplied = true
		local pref = (s.prefs and s.prefs.companions)
		if pref == nil then pref = plr:GetAttribute("PeckwoodCompanions") end
		if pref == true then setCompanions(true, false, false) end
	end
	if companions then
		local L = { ["row/SPARROW"] = s.sparrow.level, ["row/SEAGULL"] = s.seagull.level, ["row/BAMBOO"] = SampleData.companions.redpanda,
			["row/CROW"] = s.crow.level, ["row/DAVE"] = s.dave.level, ["row/PARROT"] = s.parrot.level }
		for row, lv in L do
				local r = rowFrames[row]
			local lvl = r and r:FindFirstChild("level")
			if lvl then for _, l in Render.childTexts(lvl) do Render.setText(l, tostring(lv)) end end
		end
	end
	if s.island > lastIsland and lastIsland > 0 then
		for _, r in RAIL do local slot = railSlots[r[2]]; if slot then Kit.pop(slot, 1.1) end end
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
		local fl = Render.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("b06cff"), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 90 }, overlay)
		TweenService:Create(fl, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function() fl:Destroy() end)
		Binders.molted()
		if b then showToast("The Garden opens", "unlock", "seed") end
	elseif kind == "island" then
		Sfx.islandUnlock()
		bigMoment(b .. " opens!", "unlock", "map")
	elseif kind == "evolve" then
		Sfx.evolve()
		bigMoment("Evolution " .. a .. "!", "reward", "monster")
		local fl = Render.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("ff5a8a"), BackgroundTransparency = 0.3, Size = UDim2.fromScale(1, 1), ZIndex = 90 }, overlay)
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

-- ---------------------------------------------------------------- dev bar (Studio / owner only)
local function buildDev()
	local L = FKit.layout()
	local KEYS = { { "REGULAR", "regular", FKit.PAL.green }, { "MAXED", "maxed", FKit.PAL.gold }, { "NEXT AREA", "next", FKit.PAL.violet }, { "SOUNDS", "sounds", FKit.PAL.blue } }
	devPanel = Render.new("Frame", { Name = "dev", BackgroundTransparency = 1, Size = UDim2.fromOffset(#KEYS * 160 + (#KEYS - 1) * SP.GAP, 52), Visible = false, ZIndex = 20 }, canvas)
	Render.new("UIScale", { Scale = 0.55 }, devPanel)
	local x = 0
	for _, b in KEYS do
		local k = FKit.BTNn(L, "btn/dev " .. b[2], 0, 0, 160, 52, b[3], b[1], { size = 17 })
		local ui = FKit.build(L, k, devPanel)
		ui.root.Position = UDim2.fromOffset(x, 0)
		ui.on("btn/dev " .. b[2], function(inst)
			if b[2] == "sounds" then openFrom("sounds", inst) else act("dev", b[2]) end
		end)
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
	-- toasts, big moments, fly-ins and tooltips sit above every window
	local og = Render.new("ScreenGui", { Name = "PeckwoodOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 30 }, pg)
	overlay = Render.new("Frame", { Name = "canvas", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080) }, og)
	Render.new("UIScale", {}, overlay)
	Hud.overlay = overlay
	buildTip()
	WM.screens = Screens
	Screens.init(Hud, WM)
	Binders.install(WM, act, Hud)
	-- groups that only hold transient pieces
	group("context", Vector2.new(560, 106), SP.CONTEXT)
	group("toast", Vector2.new(900, 300), SP.TOAST, overlay)
	group("moment", Vector2.new(900, 120), 1.15, overlay)
	group("objective", Vector2.new(680, 64), SP.HUD)
	group("hotbar", Vector2.new(700, 180), SP.HUD)
	group("prompt", Vector2.new(600, 62), SP.HUD)
	buildTopLeft(); buildCompanions(); buildRail(); buildObjective(); buildTiles(); buildArrows(); buildDev()
	RobuxShop.init(canvas, function(msg, tone, icon) showToast(msg, if tone == "golden" then "reward" else "info", icon) end, act)
	-- windows: pop out of / shrink back into the HUD element that opened them
	for _, id in { "fishing", "profile", "settings", "teleport", "objectives", "sparrow", "seagull", "redpanda", "crow", "dave", "parrot",
		"mine", "nest", "trees", "expedition", "aquarium", "market", "treasure", "sacrifice", "evolve", "leaderboards", "offline", "sounds" } do
		WM.sources[id] = function() return sourceOf[id] end
	end
	WM.beforeOpen = function() if RobuxShop.isOpen() then RobuxShop.toggle() end end
	WM.onEscape = function() if RobuxShop.isOpen() then RobuxShop.toggle(); return true end; return false end
	WM.onSidebarView = function(v)
		sidebarView = v.name
		-- the Figma sample gain chip on the MOLT tab is replaced by the live one (inside the tab, under its label)
		for _, d in v.ui.root:GetDescendants() do
			if string.sub(d.Name, 1, 10) == "badge/molt" and d:IsA("GuiObject") then d.Visible = false end
		end
		for _, d in v.ui.root:GetDescendants() do
			if (d.Name == "drop" or d.Name == "shadow") and d:IsA("GuiObject") and d.Parent and d.Parent.Name == "drawer tabs" and d.Position.Y.Offset < 0 then d.Visible = false end
		end
		task.defer(updateBadges)
	end
	WM.hintActions = { TAB = function() toggleCompanions() end, Q = function() WM.toggle("objectives") end, P = function() WM.toggle("profile") end }
	WM.init(pg)
	WM.debugHook()
	WM.onChanged = function()
		Hud.collapsed = not Layout.sidebarOpen
		Hud.dock.Visible = Layout.sidebarOpen
	end
	Layout.onChanged(function(animate) reflow(animate) end)
	layoutWallet()
	layoutCanvas()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutCanvas)
	-- keyboard (Birb hints): Tab companions, Q objectives, P profile
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
	-- QA: PeckwoodCompanions (bool) opens / closes the board with its animation
	pg:GetAttributeChangedSignal("PeckwoodCompanions"):Connect(function()
		setCompanions(pg:GetAttribute("PeckwoodCompanions") == true, true)
	end)
end

return Hud
