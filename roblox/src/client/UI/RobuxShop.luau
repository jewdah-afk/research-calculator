--!nonstrict
-- RobuxShop: the Robux shop board (passes, boosts, crates). Figma "Shop v3 / Robux shop - CURRENT" 130:7 is a copy
-- of this code's output (owner-approved), so it is kept as is; opened from the HUD SHOP tile.
-- Buying: a real PromptGamePass/ProductPurchase when the item has a Creator Hub id; in Studio / for devs it grants
-- through the server test path. The server applies every effect (never trust the client).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.Kit)
local hex = Kit.hex
local plr = Players.LocalPlayer

local Hud = {}          -- (kept the old name inside so the moved code reads the same)
local gameRight = 1440  -- right edge of the game area (design px), set by RobuxShop.reflow
local panelScale
local function fitScale() return math.min(1, (gameRight - 48) / 1080, (1080 - 48) / 980) end
local canvas, showToast, act
local derived = nil
local Spec = {
	popcorn = { hdr = "ffd27a:0 f7a634:30 e07a1c:72 9e4a0c:100" }, molt = { hdr = "e9c4ff:0 b06cff:30 8a3fe6:72 4f1d9c:100" },
	golden = { hdr = "ffefc4:0 e6bb44:30 bb9324:72 6e440e:100" }, echo = { hdr = "ff5ed8:0 a05cff:50 ff8ff0:100" },
	rods = { hdr = "e53935:0 ffc93a:50 2f6fe0:100" }, seagull = { hdr = "8aa4c4:0 f4f7fb:33 ffcf2e:67 ff8a2e:100" },
}

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
local GREEN = "7dff86:0 2bd04a:42 15962f:86 15962f:100"
local function buyItem(it)
	local c = shopCards[it.id]
	if c and c.owned then return end
	local MPS = game:GetService("MarketplaceService")
	if it.assetId > 0 then
		pcall(function()
			if it.kind == "pass" then MPS:PromptGamePassPurchase(plr, it.assetId) else MPS:PromptProductPurchase(plr, it.assetId) end
		end)
	elseif derived and derived.shop and derived.shop.testGrants then
		act("shoptest", it.id); showToast(it.name .. " granted (Studio test)", "golden", it.icon)
	else
		showToast(it.name .. " is coming soon", "golden", it.icon)
	end
end
-- a diagonal white shine that sweeps across a frame every few seconds (CanvasGroup-clipped by the caller)
local shineList = {}
local function addShine(clipParent, w, h, z)
	local s = Kit.frame(clipParent, -80, -10, 46, h + 20, Color3.new(1, 1, 1), { Rotation = 18, ZIndex = z })
	Kit.grad(s, { { "ffffff", 0, 0 }, { "ffffff", 0.5, 0.55 }, { "ffffff", 1, 0 } }, 0)
	table.insert(shineList, { f = s, w = w, t = math.random() * 3 })
	return s
end
RunService.RenderStepped:Connect(function(dt)
	if not (shopOverlay and shopOverlay.Visible) or Kit.reduced() then return end
	for _, sh in shineList do
		sh.t = (sh.t + dt) % 3.6
		local k = math.clamp(sh.t / 0.7, 0, 1)
		sh.f.Position = UDim2.fromOffset(-80 + (sh.w + 160) * k, -10)
	end
end)
-- a pass / product card, coloured top to bottom in its theme, icon popping over the top edge
local function shopCard(parent, it, w, h, iconSz, nameSz, keyH, order)
	local th = Spec[it.theme] or Spec.golden
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h + iconSz * 0.35), LayoutOrder = order, ZIndex = 83 }, parent)
	local lift = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 83 }, holder)
	local top = iconSz * 0.35
	Kit.soft(lift, 8, top + 12, w - 16, h - 6, 14, "shadow", Color3.new(0, 0, 0), 0.45, 83)
	local base = Kit.frame(lift, 0, top + 7, w, h - 7, Color3.fromHex(Kit.stops(th.hdr)[#Kit.stops(th.hdr)][1]):Lerp(Kit.INK, 0.45), { ZIndex = 83 })
	Kit.corner(base, 22); Kit.stroke(base, 3, Kit.INK)
	local card = Kit.new("Frame", { ClipsDescendants = true, Position = UDim2.fromOffset(0, top), Size = UDim2.fromOffset(w, h - 7), BackgroundTransparency = 1, ZIndex = 84 }, lift)
	Kit.corner(card, 22)
	local f = Kit.frame(card, 0, 0, w, h - 7, Color3.new(1, 1, 1), { ZIndex = 84 }); Kit.corner(f, 22); Kit.grad(f, Kit.stops(th.hdr))
	Kit.corner(Kit.texture(card, "halftone", 0.78, 22, 85), 22)
	Kit.image(card, 12, 6, w - 24, w - 24, Kit.iconId("ui/sunburst"), { ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.62, ZIndex = 85 })
	local shade = Kit.frame(card, 0, 0, w, h - 7, Color3.new(0, 0, 0), { ZIndex = 85 }); Kit.corner(shade, 22)
	Kit.grad(shade, { { "000000", 0, 0 }, { "000000", 0.45, 0 }, { "000000", 1, 0.45 } }, 90)
	Kit.frame(card, 8, 3, w - 16, 3, Color3.new(1, 1, 1), { BackgroundTransparency = 0.4, ZIndex = 86 })
	local ol = Kit.frame(lift, 0, top, w, h - 7, nil, { ZIndex = 87 }); Kit.corner(ol, 22); Kit.stroke(ol, 3, Kit.INK)
	if it.id == "vip" then   -- featured pass: gold rim + breathing gold glow (the only glow among the cards)
		local rim = Kit.frame(lift, 3, top + 3, w - 6, h - 13, nil, { ZIndex = 87 }); Kit.corner(rim, 19); Kit.stroke(rim, 4, hex("ffd54a"))
		local fg = Kit.soft(lift, 0, top, w, h - 7, 22, "glow", hex("ffc93c"), 0.45, 82)
		TweenService:Create(fg, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.8 }):Play()
	end
	-- icon pops over the top edge, grounded by a soft shadow
	Kit.image(lift, w / 2 - iconSz * 0.3, top + iconSz * 0.58, iconSz * 0.6, math.max(10, iconSz * 0.12), Kit.iconId("ui/softellipse"), { ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.35, ZIndex = 88 })   -- contact shadow under the icon base
	local icon = Kit.icon(lift, w / 2 - iconSz / 2, 0, iconSz, it.icon, { ZIndex = 89 })
	local ny = top + iconSz * 0.68
	Kit.title(lift, it.name, nameSz, Color3.new(1, 1, 1), 3, 2.5, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(w / 2, ny), ZIndex = 89 })
	local pill = Kit.frame(lift, 14, ny + nameSz + 10, w - 28, 28, Kit.INK, { BackgroundTransparency = 0.45, ZIndex = 88 }); Kit.corner(pill, 14)
	local sub = Kit.text(pill, it.desc, 15, hex("f1f3f7"), { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3),
		TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 89 })
	Kit.new("UITextSizeConstraint", { MaxTextSize = 16 }, sub)
	local btn = Kit.button(lift, 16, top + h - 7 - keyH - 14, w - 32, keyH, { text = "R$ " .. it.robux, size = math.floor(keyH * 0.48), stops = Kit.stops(GREEN) })
	btn.root.ZIndex = 90
	local keyClip = Kit.new("Frame", { ClipsDescendants = true, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9 }, btn.face); Kit.corner(keyClip, 14)
	addShine(keyClip, w - 32, keyH, 9)
	if it.tag then
		local rw = math.max(100, #it.tag * 10 + 26)
		-- right of the icon, inside the card edge
		local rib = Kit.frame(lift, w - rw - 8, top - 14, rw, 32, hex("ff4d6a"), { ZIndex = 91 }); Kit.corner(rib, 16); Kit.stroke(rib, 3, Kit.INK)
		Kit.grad(rib, Kit.stops("ff8095:0 e8344f:100"))
		Kit.title(rib, it.tag, 15, Color3.new(1, 1, 1), 2.2, 1.5, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -1), ZIndex = 92 })
	end
	-- hover lift + icon pop
	local hit = Kit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 83 }, holder)
	local isc = Kit.new("UIScale", {}, icon)
	hit.MouseEnter:Connect(function()
		TweenService:Create(lift, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(0, -6) }):Play()
		TweenService:Create(isc, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1.08 }):Play()
	end)
	hit.MouseLeave:Connect(function()
		TweenService:Create(lift, TweenInfo.new(0.16), { Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(isc, TweenInfo.new(0.16), { Scale = 1 }):Play()
	end)
	shopCards[it.id] = { btn = btn, sub = sub, owned = nil }
	btn.root.Activated:Connect(function() buyItem(it) end)
	return holder
end
function Hud.openShop()
	if shopOverlay then shopOverlay.Visible = not shopOverlay.Visible; Hud.refreshShop(); return end
	-- the board opens inside the game area (left of the upgrades sidebar), dimming only that area
	shopOverlay = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = hex("06070c"), BackgroundTransparency = 0.35,
		Size = UDim2.new(0, gameRight, 1, 0), ZIndex = 80 }, canvas)
	local PW, PH = 1080, 980
	local panel = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 16), Size = UDim2.fromOffset(PW, PH), ZIndex = 81 }, shopOverlay)
	Kit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 81 }, panel)   -- clicks on the board never close it
	Kit.soft(panel, 12, 20, PW - 24, PH - 12, 28, "shadow", Color3.new(0, 0, 0), 0.3, 81)
	local bodyG = Kit.new("Frame", { ClipsDescendants = true, Size = UDim2.fromOffset(PW, PH), BackgroundTransparency = 1, ZIndex = 81 }, panel); Kit.corner(bodyG, 30)
	local bf = Kit.frame(bodyG, 0, 0, PW, PH, Color3.new(1, 1, 1), { ZIndex = 81 }); Kit.corner(bf, 30); Kit.grad(bf, Kit.stops("3a2a74:0 241b52:45 141233:100"))
	Kit.corner(Kit.texture(bodyG, "halftone", 0.88, 30, 81), 30)
	Kit.image(bodyG, PW / 2 - 420, 30, 840, 840, Kit.iconId("ui/sunburst"), { ImageColor3 = hex("8f7cff"), ImageTransparency = 0.86, ZIndex = 81 })
	local trim = Kit.frame(panel, 10, 10, PW - 20, PH - 20, nil, { ZIndex = 82 }); Kit.corner(trim, 22); Kit.stroke(trim, 2, hex("f5c451"), 0.35)
	local ol = Kit.frame(panel, 0, 0, PW, PH, nil, { ZIndex = 82 }); Kit.corner(ol, 30); Kit.stroke(ol, 6, Kit.INK)
	-- header (Figma "header/SHOP (blocky)"): a crimson banner with gold trim runs behind a gold brick plaque. The band
	-- folds back at each end into lower tails with a stepped swallowtail (two prongs), all square-cornered like the
	-- rest of the HUD. The plaque has a 3D lip, LEGO studs on top, halftone, an edge light and the title in ink.
	local CXH, BW, BY, BH, TY, TH, TW = PW / 2, 320, -16, 60, 20, 58, 104
	local RED, TAIL = Kit.stops("ff7486:0 ec3a54:45 b01b33:100"), Kit.stops("d42a45:0 a8182f:55 7a0f22:100")
	local function block(x, y, w, h, stops, z, sw)
		local f = Kit.frame(panel, x, y, w, h, Color3.new(1, 1, 1), { ZIndex = z }); Kit.corner(f, 4)
		Kit.grad(f, stops)
		if sw then Kit.stroke(f, sw, Kit.INK) end
		return f
	end
	for _, sgn in { -1, 1 } do
		local bandEnd = CXH + sgn * BW
		local tx = if sgn < 0 then bandEnd - TW + 26 else bandEnd - 26
		local px = if sgn < 0 then tx - 24 else tx + TW - 4
		block(px, TY, 28, 24, Kit.stops("d42a45:0 a8182f:100"), 82, 3)               -- swallowtail prongs
		block(px, TY + TH - 24, 28, 24, Kit.stops("a8182f:0 7a0f22:100"), 82, 3)
		block(tx, TY, TW, TH, TAIL, 83, 4)                                            -- tail
		local tx0 = tx + (if sgn < 0 then 8 else 30)
		Kit.frame(panel, tx0, TY + 8, TW - 40, 3, hex("ffd54a"), { BackgroundTransparency = 0.1, ZIndex = 83 })
		Kit.frame(panel, tx0, TY + TH - 11, TW - 40, 3, hex("ffd54a"), { BackgroundTransparency = 0.1, ZIndex = 83 })
		block(if sgn < 0 then bandEnd else bandEnd - 34, BY + BH - 8, 34, TY + TH - (BY + BH) - 6, Kit.stops("4a0814:0 2a040b:100"), 84, 2)   -- fold
	end
	local band = block(CXH - BW, BY, BW * 2, BH, RED, 85, 4)
	Kit.corner(Kit.texture(band, "halftone", 0.8, 20, 85), 4)
	Kit.frame(band, 8, 5, BW * 2 - 16, 4, Color3.new(1, 1, 1), { BackgroundTransparency = 0.5, ZIndex = 86 })
	Kit.frame(band, 12, 13, BW * 2 - 24, 3, hex("ffd54a"), { ZIndex = 86 })
	Kit.frame(band, 12, BH - 16, BW * 2 - 24, 3, hex("ffd54a"), { ZIndex = 86 })
	for _, rx in { 18, BW * 2 - 32 } do
		local rv = block(CXH - BW + rx, BY + BH / 2 - 7, 14, 14, Kit.stops("fff3b0:0 e0a020:60 8a5a0a:100"), 86, 2.5)
		_ = rv
	end
	-- plaque: lip 8 px lower, studs on top, face, title
	local plW, plH, plY = 400, 104, -36
	block(CXH - plW / 2, plY + 8, plW, plH, Kit.stops("d08414:0 8a4a06:100"), 86, 5)
	for k = 0, 3 do
		local sx = CXH - plW / 2 + 44 + k * (plW - 128) / 3
		local stud = block(sx, plY - 12, 40, 16, Kit.stops("fff3b0:0 ffc93c:55 c0700c:100"), 86, 4)
		Kit.frame(stud, 6, 3, 28, 3, Color3.new(1, 1, 1), { BackgroundTransparency = 0.3, ZIndex = 87 })
	end
	local plate = block(CXH - plW / 2, plY, plW, plH, Kit.stops("fff6c4:0 ffd54a:38 f0a020:78 c0700c:100"), 87, 5)
	plate.ClipsDescendants = true
	Kit.corner(Kit.texture(plate, "halftone", 0.78, 18, 87), 4)
	Kit.frame(plate, 10, 6, plW - 20, 8, Color3.new(1, 1, 1), { BackgroundTransparency = 0.3, ZIndex = 88 })      -- edge light
	Kit.frame(plate, 0, plH - 18, plW, 18, hex("a85a08"), { BackgroundTransparency = 0.55, ZIndex = 88 })          -- bottom shade
	local bev = Kit.frame(plate, 8, 8, plW - 16, plH - 16, nil, { ZIndex = 88 }); Kit.corner(bev, 4); Kit.stroke(bev, 2, hex("fff3c0"), 0.45)
	local title = Kit.title(panel, "SHOP", 74, Color3.new(1, 1, 1), 5.5, 6, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CXH, plY + plH / 2 - 4), ZIndex = 89 })
	Kit.grad(title.label, Kit.stops("ffffff:0 ffffff:45 ffe9a0:100"))
	Kit.sparkle(panel, CXH - plW / 2 + 22, plY - 26, 14); Kit.sparkle(panel, CXH + plW / 2 - 18, plY + 78, 10); Kit.sparkle(panel, CXH + plW / 2 + 30, plY - 10, 8)
	local close = Kit.button(panel, PW - 84, 22, 62, 60, { text = "X", size = 30, stops = Kit.stops("ff8a7a:0 d0443a:100"), sound = "close" })
	close.root.ZIndex = 86
	close.root.Activated:Connect(function() shopOverlay.Visible = false end)
	-- category tabs
	local pages, tabs = {}, {}
	local TABS = { { "PASSES", "shop_vip" }, { "BOOSTS", "shop_boost60" }, { "CRATES", "shop_crateL" } }
	local function show(k)
		for i, pg in pages do pg.Visible = i == k end
		for i, t in tabs do t.look(if i == k then "lit" else "grey", Kit.stops("ffe08a:0 f5b93c:45 c97a14:100")) end
	end
	for i, t in TABS do
		local b = Kit.button(panel, PW / 2 - 330 + (i - 1) * 226, 96, 210, 58, { icon = t[2], iconSize = 46, text = t[1], size = 22, stops = Kit.stops("ffe08a:0 f5b93c:45 c97a14:100") })
		b.root.ZIndex = 86
		b.root.Activated:Connect(function() show(i) end)
		tabs[i] = b
	end
	local CW, CY = PW - 72, 172
	local function page()
		local p = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(36, CY), Size = UDim2.fromOffset(CW, PH - CY - 30), ZIndex = 83, Visible = false }, panel)
		table.insert(pages, p)
		return p
	end
	-- PASSES page: hero bundle + 6 pass cards
	local p1 = page()
	local B = ShopData.BY_ID.bundle
	do
		local HH = 236
		local hero = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(CW, HH + 8), ZIndex = 83 }, p1)
		Kit.soft(hero, 8, 14, CW - 16, HH, 16, "shadow", Color3.new(0, 0, 0), 0.4, 83)
		local hb = Kit.frame(hero, 0, 8, CW, HH, hex("8a4c0c"), { ZIndex = 83 }); Kit.corner(hb, 26); Kit.stroke(hb, 3, Kit.INK)
		local hc = Kit.new("Frame", { ClipsDescendants = true, Size = UDim2.fromOffset(CW, HH), BackgroundTransparency = 1, ZIndex = 84 }, hero); Kit.corner(hc, 26)
		local hf = Kit.frame(hc, 0, 0, CW, HH, Color3.new(1, 1, 1), { ZIndex = 84 }); Kit.corner(hf, 26); Kit.grad(hf, Kit.stops("fff2b8:0 ffc94a:40 f08a1c:100"))
		Kit.corner(Kit.texture(hc, "halftone", 0.76, 26, 85), 26)
		Kit.image(hc, 30, 8, HH - 16, HH - 16, Kit.iconId("ui/sunburst"), { ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.45, ZIndex = 85 })
		local hs = Kit.frame(hc, 0, 0, CW, HH, Color3.new(0, 0, 0), { ZIndex = 85 }); Kit.corner(hs, 26); Kit.grad(hs, { { "000000", 0, 0 }, { "000000", 0.5, 0 }, { "000000", 1, 0.4 } }, 90)
		addShine(hc, CW, HH, 86)
		local hol = Kit.frame(hero, 0, 0, CW, HH, nil, { ZIndex = 87 }); Kit.corner(hol, 26); Kit.stroke(hol, 3, Kit.INK)
		Kit.image(hero, 65, 178, 180, 24, Kit.iconId("ui/softellipse"), { ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.3, ZIndex = 88 })   -- contact shadow under the chest
		Kit.icon(hero, 30, -34, 250, B.icon, { ZIndex = 89 })   -- pops out over the top edge
		Kit.title(hero, "ULTIMATE BUNDLE", 46, Color3.new(1, 1, 1), 4, 3.5, { Position = UDim2.fromOffset(300, 34), ZIndex = 89 })
		Kit.title(hero, "Every game pass, forever", 22, hex("5a3006"), 0, 0, { Position = UDim2.fromOffset(300, 94), ZIndex = 89 })
		local row = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(300, 136), Size = UDim2.fromOffset(460, 60), ZIndex = 88 }, hero)
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		for k, g in B.grants do
			local chip = Kit.frame(row, 0, 0, 58, 58, Color3.new(1, 1, 1), { LayoutOrder = k, ZIndex = 88 }); Kit.corner(chip, 16)
			Kit.grad(chip, Kit.stops("ffffff@70:0 ffe7a0@85:100")); Kit.stroke(chip, 3, Kit.INK)
			Kit.icon(chip, 4, 4, 50, ShopData.BY_ID[g].icon, { ZIndex = 89 })
		end
		-- old price: cream on a dark pill so it reads against the gold, red strike through the middle
		local wasPill = Kit.frame(hero, CW - 28 - 136, 62, 0, 40, hex("5a2a06"), { AnchorPoint = Vector2.new(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.25, ZIndex = 88 })
		Kit.corner(wasPill, 20)
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, wasPill)
		local was = Kit.title(wasPill, "R$ " .. B.was, 26, hex("fff1d6"), 0, 0, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 89 })
		local strike = Kit.frame(was.holder, 0, 0, 0, 0, hex("ff4a4a"), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(1, 12, 0, 4), ZIndex = 91 })
		Kit.corner(strike, 2)
		local bw, bh = 272, 104
		local btn = Kit.button(hero, CW - 28 - bw, 90, bw, bh, { text = "R$ " .. B.robux, size = 48, stops = Kit.stops(GREEN) })
		-- the bundle key is the only green glow on the page: it breathes so the main buy reads first
		local bglow = Kit.soft(hero, CW - 28 - bw, 90, bw, bh, 24, "glow", hex("5dff6e"), 0.5, 89)
		TweenService:Create(bglow, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.8 }):Play()
		btn.root.ZIndex = 90
		local kc = Kit.new("Frame", { ClipsDescendants = true, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9 }, btn.face); Kit.corner(kc, 16)
		addShine(kc, bw, bh, 9)
		local rib = Kit.frame(hero, CW - 28 - 136 - 90, -10, 180, 44, Color3.new(1, 1, 1), { ZIndex = 91 }); Kit.corner(rib, 22); Kit.stroke(rib, 4, Kit.INK)
		Kit.grad(rib, Kit.stops("ff8095:0 e8344f:100"))
		Kit.title(rib, B.tag, 24, Color3.new(1, 1, 1), 3, 2, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -1), ZIndex = 92 })
		shopCards.bundle = { btn = btn, sub = Instance.new("TextLabel"), owned = nil }
		btn.root.Activated:Connect(function() buyItem(B) end)
	end
	local g1 = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 262), Size = UDim2.fromOffset(CW, 500), ZIndex = 83 }, p1)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(318, 248), CellPadding = UDim2.fromOffset(math.floor((CW - 3 * 318) / 2), 4), SortOrder = Enum.SortOrder.LayoutOrder }, g1)
	local k = 0
	for _, it in ShopData.ITEMS do
		if it.section == "GAME PASSES" then k += 1; shopCard(g1, it, 318, 212, 100, 26, 48, k) end
	end
	-- BOOSTS page: two big cards + a note on stacking
	local p2 = page()
	local g2 = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(CW / 2 - 360, 40), Size = UDim2.fromOffset(720, 560), ZIndex = 83 }, p2)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(340, 520), CellPadding = UDim2.fromOffset(40, 0), SortOrder = Enum.SortOrder.LayoutOrder }, g2)
	k = 0
	for _, it in ShopData.ITEMS do if it.section == "BOOSTS" then k += 1; shopCard(g2, it, 340, 440, 220, 32, 70, k) end end
	Kit.title(p2, "Boosts double EVERY currency and stack with your passes. Buy more to add time.", 20, hex("d8d2ff"), 2, 0,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(CW / 2, 640), ZIndex = 84 })
	-- CRATES page: three cards that grow with size
	local p3 = page()
	local g3 = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(CW, 560), ZIndex = 83 }, p3)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(310, 520), CellPadding = UDim2.fromOffset(math.floor((CW - 3 * 310) / 2), 0), SortOrder = Enum.SortOrder.LayoutOrder }, g3)
	k = 0
	for _, it in ShopData.ITEMS do if it.section == "CRATES" then k += 1; shopCard(g3, it, 310, 440, 160 + k * 24, 30, 66, k) end end
	Kit.title(p3, "Crates pay out from YOUR current eggs per second, so they stay worth it as you grow.", 20, hex("d8d2ff"), 2, 0,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(CW / 2, 640), ZIndex = 84 })
	Kit.title(panel, "Passes are forever  ·  Boosts stack with passes  ·  Every purchase is checked on the server", 15, hex("a99ce0"), 0, 0,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(PW / 2, PH - 34), ZIndex = 84 })
	show(1)
	shopOverlay.Activated:Connect(function() shopOverlay.Visible = false end)
	panelScale = Kit.new("UIScale", { Scale = 0.9 * fitScale() }, panel)
	TweenService:Create(panelScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fitScale() }):Play()
	Hud.refreshShop()
end

local RobuxShop = {}
function RobuxShop.init(c, toastFn, actFn) canvas, showToast, act = c, toastFn, actFn end
function RobuxShop.setDerived(d) derived = d; Hud.refreshShop() end
function RobuxShop.toggle() Hud.openShop() end
function RobuxShop.isOpen() return shopOverlay ~= nil and shopOverlay.Visible end
function RobuxShop.reflow(right)
	gameRight = right
	if shopOverlay then shopOverlay.Size = UDim2.new(0, gameRight, 1, 0) end
	if panelScale then panelScale.Scale = fitScale() end
end
return RobuxShop
