--!nonstrict
-- TreeBinder: the Trees window (Figma 239:309 SUNFLOWER / 246:3851 DESERT) bound to Birb's sunflower tree.
-- Every station of Birb's Sunflower Field (shared/Birb/Data STATIONS, 82 base + 51 desert nodes) becomes a node built
-- from the frame's own node templates (owned / buy / need / locked / unexplored) at its Birb map position, scaled to
-- the Figma grid (260 x 120 Birb px -> 108 x 80). Visibility, chain and costs come from shared/Birb/Rules (the parity
-- checked port): a node shows when Birb shows its station, "?" marks the next hidden layer. Orthogonal connectors in
-- the frame's edge styles (gold = owned path, pale = open, dark = unexplored). The map pans by drag, zooms by wheel
-- and the zoom keys; the detail panel follows the selected node; BUY sends "tree" through the Action remote (the
-- server checks visibility, gates and the wallet). The ARCHIVIST tab stays Figma's sample until Phase 7.
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Defs = require(RS:WaitForChild("Peckwood"):WaitForChild("Defs"))
local Render = require(script.Parent.Figma.Render)
local FKit = require(script.Parent.Figma.FKit)
local Sfx = require(script.Parent.Sfx)
local R = Defs.R
local EN = Defs.EN
local D = R.Data

local TreeBinder = {}
local WM, act

local KX, KY = 108 / 260, 80 / 120      -- Birb station px -> Figma px
local PADX, PADY = 36, 22
local NODE_W, NODE_H = 58, 64
local ZMIN, ZMAX = 0.45, 1.6

local CUR_ICON = { popcorn = "egg", goldenFeathers = "plume", sunflowerSeeds = "seed", monetariaMoneta = "moneta", goldenPopcorn = "egg_golden",
	echoPopcorn = "echo", bruteOre = "ore", twigs = "twig", strange_key = "legendary_key", gold_ore = "goldore", totalFishCaught = "fish",
	spirit_trash = "aura", archivist_book = "book" }
local CUR_NAME = { popcorn = "eggs", goldenFeathers = "plumes", sunflowerSeeds = "seeds", monetariaMoneta = "moneta", goldenPopcorn = "golden eggs",
	echoPopcorn = "echo eggs", bruteOre = "brute ore", twigs = "twigs", strange_key = "Legendary Keys", gold_ore = "gold ore", totalFishCaught = "fish caught" }

local function fmt(v) return EN.short(v) end
-- Birb's words with Peckwood's names (playtest main.js words): popcorn -> eggs, feathers -> plumes, rebirth -> molt
local function words(t0: string?): string
	local t: string = t0 or ""
	local function sub(str, pat, rep) return (string.gsub(str, pat, rep)) end
	for _, p in { { "GOLDEN FEATHERS?", "PLUMES" }, { "[Gg]olden [Ff]eathers?", "Plumes" }, { "FEATHERS?", "PLUMES" }, { "Feathers?", "Plumes" }, { "feathers?", "plumes" },
		{ "POPCORNS", "EGGS" }, { "POPCORN", "EGG" }, { "Popcorns", "Eggs" }, { "Popcorn", "Egg" }, { "popcorns", "eggs" }, { "popcorn", "eggs" },
		{ "REBIRTH", "MOLT" }, { "REBIRB", "MOLT" }, { "Rebirth", "Molt" }, { "rebirth", "molt" } } do
		t = sub(t, p[1], p[2])
	end
	return t
end
TreeBinder.words = words
local function short(id: string) return string.sub(id, 3) end   -- "d_seed_synergy" -> "seed_synergy"
local function nodeIcon(id: string) return "node_" .. short(id) end

-- which stations a tab shows (playtest visibleStations: the desert view holds d_desert_* and the archivist key node)
local function isDesert(id: string) return string.sub(id, 1, 9) == "d_desert_" or id == "d_unlock_archivist_tree" end
local VIEWS = { Tree_Sunflower = function(id) return not isDesert(id) end, Tree_Desert = isDesert }

local function canAfford(s, n, cost)
	local cur = n.costCurrency
	if cur == "totalFishCaught" then return (s.stats.fishCaught or 0) >= cost end
	if cur == "strange_key" then return R.hooks.strangeKeys(s) >= cost end
	local k = R.wkey(cur)
	if not R.WALLET[k] then return false end
	return EN.meeq(s[k] or EN.ZERO, cost)
end
local function haveOf(s, cur)
	if cur == "totalFishCaught" then return s.stats.fishCaught or 0 end
	if cur == "strange_key" then return R.hooks.strangeKeys(s) end
	local k = R.wkey(cur)
	return if R.WALLET[k] then (s[k] or EN.ZERO) else 0
end

-- node state for the map: owned / buy / need / locked / unexplored / nil (hidden)
local function stateOf(s, id, shownParent)
	local n = D.SUN_BY_ID[id]
	if not n then return nil end
	if R.sunLevel(s, id) >= (n.maxLevel or 1) then return "owned" end
	if R.sunVisible(s, id) then
		if not R.sunUnlocked(s, id) then return "locked" end
		return if canAfford(s, n, R.sunCost(s, id)) then "buy" else "need"
	end
	return if shownParent then "unexplored" else nil
end

-- the first gate a node still needs (detail panel)
local function requirementOf(s, id, st)
	local n = D.SUN_BY_ID[id]
	if st == "owned" then return "Owned", true end
	if (n.mineAreaRequired or 0) > R.hooks.mineArea(s) then return "Needs mine area " .. n.mineAreaRequired, false end
	if (n.evolutionRequired or 0) > (s.evolutionCount or 0) then return "Needs Evolution " .. n.evolutionRequired, false end
	if (n.nestTierRequired or 0) > R.hooks.nestTier(s) + 1 then return "Needs Nest level " .. n.nestTierRequired, false end
	if (n.parrotRebirbRequired or 0) > R.hooks.parrotRebirbs(s) then return "Needs Parrot Rebirb " .. n.parrotRebirbRequired, false end
	for _, p in n.parents do
		if not R.hasSun(s, p) then
			local pn = D.SUN_BY_ID[p]
			return "Needs " .. string.upper(words(pn and pn.name or p)), false
		end
	end
	if st == "need" then
		local cost = R.sunCost(s, id)
		local have = haveOf(s, n.costCurrency)
		return "Needs " .. fmt(EN.sub(cost, have)) .. " more " .. (CUR_NAME[n.costCurrency] or n.costCurrency), false
	end
	if not R.WALLET[R.wkey(n.costCurrency)] and n.costCurrency ~= "totalFishCaught" and n.costCurrency ~= "strange_key" then
		return "Paid in " .. (CUR_NAME[n.costCurrency] or n.costCurrency) .. " (arrives with its phase)", false
	end
	return "Ready to buy", true
end

-- live effect cards for nodes whose value grows with a resource (Birb's own formulas, Rules)
local function logCurve(x, t, i, a) return a + i * EN.toNumber(EN.log10(EN.add(EN.div(x, t), 1))) end
local LIVE = {
	d_seed_synergy = { "AT YOUR SEEDS", "egg", "Eggs", function(s) return 1 + 1.3 * math.log10(1 + EN.toNumber(s.sunflowerSeeds) / 5e4) end },
	d_golden_butter = { "AT YOUR PLUMES", "egg", "Eggs", function(s) return 1 + 0.5 * math.log10(EN.toNumber(s.goldenFeathers) + 1) end },
	d_seed_multiplier = { "AT YOUR PLUMES", "seed", "Seeds", function(s) return logCurve(s.goldenFeathers, 2e4, 0.8, 1) end },
	d_fish_seeds = { "AT YOUR CATCHES", "seed", "Seeds", function(s) return logCurve(s.stats.fishCaught or 0, 10, 1.4, 1) end },
	d_rebirth_playtime = { "AT YOUR PLAYTIME", "plume", "Plumes", function(s) return math.min(10, 1 + 0.01 * (s.stats.playTime / 60)) end },
}

-- ---------------------------------------------------------------- per-variant map
local function setNodeText(frame, text)
	local t = Render.childTexts(frame)[1]
	if t then Render.setText(t, text) end
	return t
end

local function buildMap(rec, ui, variant)
	local L = WM.layoutOf(variant)
	local fallback = WM.layoutOf("Tree_Sunflower")
	local tpl = {}
	local function grab(layout)
		for _, n in Render.findNodes(layout.root, function(x) return string.sub(x.n, 1, 5) == "node/" end) do
			local st = string.match(n.n, "%((%w+)%)$")
			if st and not tpl[st] then tpl[st] = { layout = layout, node = n } end
		end
	end
	grab(L)
	if fallback ~= L then grab(fallback) end
	local edgeTpl = { layout = L, ink = Render.findNode(L.root, "edge ink"), edge = Render.findNode(L.root, "edge") }
	local viewport = ui.find("map viewport")
	if not viewport then return nil end
	local nodesF, edgesF = viewport:FindFirstChild("nodes"), viewport:FindFirstChild("edges")
	if not (nodesF and edgesF) then return nil end
	local ring = nodesF:FindFirstChild("selected ring")
	for _, c in nodesF:GetChildren() do if c ~= ring and c:IsA("GuiObject") and string.sub(c.Name, 1, 5) == "node/" then c:Destroy() end end
	for _, c in nodesF:GetChildren() do if c:IsA("GuiObject") and c ~= ring and (c.Name == "drop" or c.Name == "shadow") then c:Destroy() end end
	edgesF:ClearAllChildren()
	-- node positions from Birb's stations
	local ids, pos = {}, {}
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local want = VIEWS[variant]
	for _, st in D.STATIONS do
		if st.id ~= "__platform" and string.sub(st.id, 1, 12) ~= "d_archivist_" and want(st.id) and D.SUN_BY_ID[st.id] then
			table.insert(ids, st.id)
			minX, minY, maxX, maxY = math.min(minX, st.x), math.min(minY, st.y), math.max(maxX, st.x), math.max(maxY, st.y)
		end
	end
	for _, st in D.STATIONS do
		if table.find(ids, st.id) then pos[st.id] = Vector2.new(PADX + (st.x - minX) * KX, PADY + (st.y - minY) * KY) end
	end
	local cw, ch = PADX * 2 + (maxX - minX) * KX + NODE_W, PADY * 2 + (maxY - minY) * KY + NODE_H + 24
	-- content holder (pans / zooms): the Figma edges + nodes frames move into it
	local content = Render.new("Frame", { Name = "content", BackgroundTransparency = 1, Size = UDim2.fromOffset(cw, ch), ZIndex = 2 }, viewport)
	local zoom = Render.new("UIScale", { Name = "Zoom", Scale = 1 }, content)
	edgesF.Parent = content; nodesF.Parent = content
	edgesF.ZIndex, nodesF.ZIndex = 1, 2
	edgesF.Size = UDim2.fromOffset(cw, ch); nodesF.Size = UDim2.fromOffset(cw, ch)
	edgesF.Position = UDim2.new(); nodesF.Position = UDim2.new()
	for _, keep in { "zoom controls", "minimap" } do local f = viewport:FindFirstChild(keep); if f then f.ZIndex = 5 end end
	local map = { ids = ids, pos = pos, tpl = tpl, edgeTpl = edgeTpl, nodesF = nodesF, edgesF = edgesF, content = content, zoom = zoom, ring = ring,
		viewport = viewport, cw = cw, ch = ch, nodes = {}, states = {}, sel = nil, edgesKey = "" }
	return map
end

local function clampPan(map)
	local vp, z = map.viewport, map.zoom.Scale
	local vw, vh = vp.Size.X.Offset, vp.Size.Y.Offset
	local w, h = map.cw * z, map.ch * z
	local p = map.content.Position
	local x = if w <= vw then (vw - w) / 2 else math.clamp(p.X.Offset, vw - w, 0)
	local y = if h <= vh then (vh - h) / 2 else math.clamp(p.Y.Offset, vh - h, 0)
	map.content.Position = UDim2.fromOffset(x, y)
	-- minimap viewport rect
	local mm = vp:FindFirstChild("minimap")
	local rect = mm and mm:FindFirstChild("viewport rect")
	if rect then
		local mw, mh = mm.Size.X.Offset - 10, mm.Size.Y.Offset - 10
		local fx, fy = math.clamp(-x / w, 0, 1), math.clamp(-y / h, 0, 1)
		local fw, fh = math.clamp(vw / w, 0.05, 1), math.clamp(vh / h, 0.05, 1)
		rect.Position = UDim2.fromOffset(5 + fx * mw, 5 + fy * mh)
		rect.Size = UDim2.fromOffset(math.max(6, fw * mw), math.max(6, fh * mh))
	end
end
local function centreOn(map, id)
	local p = map.pos[id]
	if not p then return end
	local z = map.zoom.Scale
	map.content.Position = UDim2.fromOffset(map.viewport.Size.X.Offset / 2 - (p.X + NODE_W / 2) * z, map.viewport.Size.Y.Offset / 2 - (p.Y + NODE_H / 2) * z)
	clampPan(map)
end
local function setZoom(map, z, around: Vector2?)
	local old = map.zoom.Scale
	z = math.clamp(z, ZMIN, ZMAX)
	if math.abs(z - old) < 1e-3 then return end
	local vp = map.viewport
	local c = around or Vector2.new(vp.Size.X.Offset / 2, vp.Size.Y.Offset / 2)
	local p = map.content.Position
	local wx, wy = (c.X - p.X.Offset) / old, (c.Y - p.Y.Offset) / old
	map.zoom.Scale = z
	map.content.Position = UDim2.fromOffset(c.X - wx * z, c.Y - wy * z)
	clampPan(map)
end

-- pan by drag, zoom by wheel (design px: screen px / the window's on-screen scale)
local function wireInput(map, ui)
	local vp = map.viewport
	local dragging, last = false, nil
	local function scaleOf() return math.max(1e-3, vp.AbsoluteSize.X / math.max(1, vp.Size.X.Offset)) end
	vp.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			dragging, last = true, Vector2.new(io.Position.X, io.Position.Y)
		end
	end)
	UIS.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	UIS.InputChanged:Connect(function(io)
		if not dragging or not vp.Parent then return end
		if io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch then
			local p = Vector2.new(io.Position.X, io.Position.Y)
			local d = (p - last) / scaleOf()
			last = p
			local cp = map.content.Position
			map.content.Position = UDim2.fromOffset(cp.X.Offset + d.X, cp.Y.Offset + d.Y)
			clampPan(map)
		end
	end)
	vp.InputChanged:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseWheel then
			local sc = scaleOf()
			local at = Vector2.new((io.Position.X - vp.AbsolutePosition.X) / sc, (io.Position.Y - vp.AbsolutePosition.Y) / sc)
			setZoom(map, map.zoom.Scale * (if io.Position.Z > 0 then 1.12 else 1 / 1.12), at)
		end
	end)
	ui.on("btn/zoom in", function() setZoom(map, map.zoom.Scale * 1.2) end)
	ui.on("btn/zoom out", function() setZoom(map, map.zoom.Scale / 1.2) end)
end

-- (re)build one node in its state's template at its map spot
local function placeNode(rec, map, s, id, st)
	local old = map.nodes[id]
	if old then old.root:Destroy(); map.nodes[id] = nil end
	if not st then return end
	local t = map.tpl[st] or map.tpl.need
	if not t then return end
	local p = map.pos[id]
	local tn = table.clone(t.node)
	tn.x, tn.y = p.X, p.Y
	local built = Render.buildNode(t.layout, tn, map.nodesF, 3)
	built.root.Name = "node/" .. short(id) .. " (" .. st .. ")"
	for _, img in built.root:GetDescendants() do
		if img:IsA("ImageLabel") and string.sub(img.Name, 1, 9) == "ico/node_" then img.Image = FKit.icon(nodeIcon(id)) end
	end
	built.onAny(function(name)
		if string.sub(name, 1, 5) == "node/" then
			Sfx.rowSelect()
			map.sel = id
			rec.treeDirty = true
			if WM.state then TreeBinder.binder.update(rec, rec.variants[rec.current].ui, rec.current, WM.state, WM.derived) end
		end
	end)
	map.nodes[id] = built
end
local function updateCost(map, s, id, built)
	local cost = built.root:FindFirstChild("cost", true)
	if not cost then return end
	local n = D.SUN_BY_ID[id]
	for _, img in cost:GetChildren() do
		if img:IsA("ImageLabel") and string.sub(img.Name, 1, 4) == "ico/" then img.Image = FKit.icon(CUR_ICON[n.costCurrency] or n.costCurrency) end
	end
	local txt = fmt(R.sunCost(s, id))
	if built.costText == txt then return end
	built.costText = txt
	local t = setNodeText(cost, txt)
	if t then
		local w = math.ceil(Render.textWidth(t, txt)) + 4
		t.Size = UDim2.fromOffset(w, t.Size.Y.Offset)
		local sh = Render.SHADOW[t]
		if sh then sh.Size = t.Size end
		local cw = 27 + w + 6
		cost.Size = UDim2.fromOffset(cw, cost.Size.Y.Offset)
		cost.Position = UDim2.fromOffset(math.floor((NODE_W - cw) / 2), cost.Position.Y.Offset)
		local hl = cost:FindFirstChild("top highlight")
		if hl then hl.Size = UDim2.fromOffset(cw - 8, hl.Size.Y.Offset) end
	end
end

local function drawEdges(map, shown)
	local key = {}
	for _, id in map.ids do table.insert(key, shown[id] or "-") end
	local k = table.concat(key, ",")
	if k == map.edgesKey then return end
	map.edgesKey = k
	map.edgesF:ClearAllChildren()
	-- the frame's own edge fills (solid palette entries): ink 17 / 32, gold 34, pale 33, dark 35
	local P = map.edgeTpl.layout.P
	local function solid(idx, fbHex, fbA)
		local e = P[idx] and P[idx][1]
		if type(e) == "table" and e[1] == "s" then return Color3.fromHex(e[2]), 1 - (e[3] or 1) end
		return Color3.fromHex(fbHex), 1 - fbA
	end
	local inkLit, inkDim = { solid(17, "0b0c10", 1) }, { solid(32, "0b0c10", 0.55) }
	local GOLD, PALE, DARK = { solid(34, "f2c94c", 1) }, { solid(33, "cfe8d2", 1) }, { solid(35, "3a4a3e", 0.9) }
	local function seg(x, y, w, h, style, inkStyle)
		Render.new("Frame", { Name = "edge ink", BorderSizePixel = 0, BackgroundColor3 = inkStyle[1], BackgroundTransparency = inkStyle[2],
			Position = UDim2.fromOffset(x - 2.5, y - 2.5), Size = UDim2.fromOffset(w + 5, h + 5), ZIndex = 1 }, map.edgesF)
		Render.new("Frame", { Name = "edge", BorderSizePixel = 0, BackgroundColor3 = style[1], BackgroundTransparency = style[2],
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = 2 }, map.edgesF)
	end
	for _, id in map.ids do
		local cs = shown[id]
		if cs then
			local n = D.SUN_BY_ID[id]
			local c = map.pos[id] + Vector2.new(NODE_W / 2, NODE_W / 2)
			for _, pid in n.parents do
				local ps = shown[pid]
				if ps and map.pos[pid] then
					local p = map.pos[pid] + Vector2.new(NODE_W / 2, NODE_W / 2)
					local style = if cs == "unexplored" then DARK elseif cs == "owned" and ps == "owned" then GOLD else PALE
					local ink = if cs == "unexplored" then inkDim else inkLit
					-- horizontal at the parent's height, then vertical into the child (Figma's orthogonal connectors)
					local x0, x1 = math.min(p.X, c.X), math.max(p.X, c.X)
					if x1 - x0 > 0.5 then seg(x0 - 2.5, p.Y - 2.5, x1 - x0 + 5, 5, style, ink) end
					local y0, y1 = math.min(p.Y, c.Y), math.max(p.Y, c.Y)
					if y1 - y0 > 0.5 then seg(c.X - 2.5, y0 - 2.5, 5, y1 - y0 + 5, style, ink) end
				end
			end
		end
	end
end

local function updateDetail(rec, ui, map, s, id, st)
	local panel = ui.find("detail panel")
	if not panel or not id then return end
	local n = D.SUN_BY_ID[id]
	local hero = panel:FindFirstChild("hero")
	if hero then
		for _, img in hero:GetChildren() do
			if img:IsA("ImageLabel") and string.sub(img.Name, 1, 4) == "ico/" then img.Image = FKit.icon(if st == "unexplored" then "lock" else nodeIcon(id)) end
		end
	end
	local name, desc = panel:FindFirstChild("name"), panel:FindFirstChild("description")
	if name then Render.setText(name, if st == "unexplored" then "???" else string.upper(words(n.name or id))) end
	if desc then Render.setText(desc, if st == "unexplored" then "Buy the node before it to reveal this one." else words(n.description)) end
	local eff = panel:FindFirstChild("effect")
	if eff then
		local off, on = eff:FindFirstChild("off"), eff:FindFirstChild("on")
		local L, M = R.sunLevel(s, id), n.maxLevel or 1
		if M > 1 then
			if off then Render.setText(off, "LV " .. L) end
			if on then Render.setText(on, "LV " .. math.min(M, L + 1)) end
		else
			if off then Render.setText(off, "off") end
			if on then Render.setText(on, "on") end
		end
	end
	local req = panel:FindFirstChild("requirement")
	if req then
		local text, ok = requirementOf(s, id, st)
		local t = Render.childTexts(req)[1]
		if t then
			Render.setText(t, text)
			Render.setTextColor(t, Color3.fromHex(if ok then "9dffae" else "ff9a8a"))
			t.Size = UDim2.fromOffset(req.Size.X.Offset - t.Position.X.Offset, t.Size.Y.Offset)
		end
	end
	local cost = R.sunCost(s, id)
	local buy = panel:FindFirstChild("btn/buy")
	if buy then
		local face = buy:FindFirstChild("face")
		if face then
			for _, c in face:GetChildren() do
				if c:IsA("ImageLabel") and string.sub(c.Name, 1, 4) == "ico/" then c.Image = FKit.icon(CUR_ICON[n.costCurrency] or n.costCurrency); c.Visible = st ~= "owned" end
			end
			local t = Render.childTexts(face)[1]
			if t then
				Render.setText(t, if st == "owned" then "OWNED" elseif st == "unexplored" then "???" else fmt(cost))
				Render.setTextColor(t, Color3.fromHex(if st == "need" or st == "locked" then "ff9a8a" else "ffffff"))
			end
		end
	end
	for _, t in Render.childTexts(panel) do
		if string.sub(t.Text, 1, 8) == "You have" or t:GetAttribute("treeHave") then
			t:SetAttribute("treeHave", true)
			Render.setText(t, "You have " .. fmt(haveOf(s, n.costCurrency)) .. " " .. (CUR_NAME[n.costCurrency] or n.costCurrency))
		elseif string.sub(t.Text, 1, 8) == "One-time" or string.sub(t.Text, 1, 8) == "Levels: " or t:GetAttribute("treeKeep") then
			t:SetAttribute("treeKeep", true)
			local keep = if R.KEEP_SUN[id] or n.permanent then "kept through Molt and Evolution" else "kept through Molt, reset on Evolution"
			Render.setText(t, (if (n.maxLevel or 1) > 1 then "Levels: " .. (n.maxLevel or 1) .. " · " else "One-time unlock · ") .. keep)
		end
	end
	local now = panel:FindFirstChild("effect now")
	if now then
		local live = LIVE[id]
		now.Visible = live ~= nil and st ~= "unexplored"
		if live then
			local ts = Render.childTexts(now)
			if ts[1] then Render.setText(ts[1], live[1]) end
			if ts[2] then Render.setText(ts[2], live[3]) end
			if ts[3] then Render.setText(ts[3], string.format("x%.2f", live[4](s))) end
			for _, img in now:GetChildren() do if img:IsA("ImageLabel") then img.Image = FKit.icon(live[2]) end end
		end
	end
	-- next in this branch: children Birb has not shown yet
	local hidden = 0
	for _, cid in map.ids do
		local cn = D.SUN_BY_ID[cid]
		if table.find(cn.parents, id) and not R.sunVisible(s, cid) and R.sunLevel(s, cid) < 1 then hidden += 1 end
	end
	local nxt = panel:FindFirstChild("next")
	for _, t in Render.childTexts(panel) do
		if t.Text == "NEXT IN THIS BRANCH" then t.Visible = hidden > 0 end
	end
	if nxt then
		nxt.Visible = hidden > 0
		local ts = Render.childTexts(nxt)
		if ts[1] then Render.setText(ts[1], hidden .. (if hidden == 1 then " new unlock" else " new unlocks")) end
		if ts[2] then Render.setText(ts[2], if hidden == 1 then "Buy this to reveal it" else "Buy this to reveal them") end
	end
	-- ring
	local built = map.nodes[id]
	if map.ring and built then
		map.ring.Visible = true
		map.ring.Position = UDim2.fromOffset(built.root.Position.X.Offset - 6, built.root.Position.Y.Offset - 6)
		map.ring.ZIndex = 10
	elseif map.ring then
		map.ring.Visible = false
	end
end

TreeBinder.binder = {
	bind = function(rec, ui, variant)
		if not VIEWS[variant] then return end
		rec.maps = rec.maps or {}
		local map = buildMap(rec, ui, variant)
		if not map then return end
		rec.maps[variant] = map
		wireInput(map, ui)
		ui.on("btn/buy", function(inst)
			local id = map.sel
			if id then act("tree", id, nil, inst) end
		end)
	end,
	update = function(rec, ui, variant, s, d)
		local map = rec.maps and rec.maps[variant]
		if not map then return end
		-- states: shown nodes first (owned / visible), then the hidden layer right after them as "?"
		local shown = {}
		for _, id in map.ids do
			local st = stateOf(s, id, false)
			if st then shown[id] = st end
		end
		for _, id in map.ids do
			if not shown[id] then
				for _, p in D.SUN_BY_ID[id].parents do
					local ps = shown[p]
					if ps and ps ~= "unexplored" then shown[id] = "unexplored"; break end
				end
			end
		end
		for _, id in map.ids do
			local st = shown[id]
			if map.states[id] ~= st then
				map.states[id] = st
				placeNode(rec, map, s, id, st)
			end
			local built = map.nodes[id]
			if built and st ~= "owned" and st ~= "unexplored" then updateCost(map, s, id, built) end
		end
		drawEdges(map, shown)
		-- selection: keep the player's pick; else the cheapest buyable node, else the Sunflower Machine
		if not map.sel or not shown[map.sel] then
			local best, bc
			for _, id in map.ids do
				if shown[id] == "buy" then
					local c = R.sunCost(s, id)
					if not bc or c < bc then best, bc = id, c end
				end
			end
			map.sel = best or (if shown.d_sunflower_machine then "d_sunflower_machine" else nil) or map.ids[1]
			if not map.centred then map.centred = true; centreOn(map, map.sel) end
		end
		updateDetail(rec, ui, map, s, map.sel, shown[map.sel])
		-- footer: unlocked / total
		local owned = 0
		for _, id in map.ids do if shown[id] == "owned" then owned += 1 end end
		local prog = ui.find("progress")
		if prog then
			local t = Render.childTexts(prog)[1]
			if t then Render.setText(t, owned .. " / " .. #map.ids) end
			local fill = prog:FindFirstChild("fill")
			if fill then fill.Size = UDim2.fromOffset(math.floor(prog.Size.X.Offset * owned / math.max(1, #map.ids) + 0.5), fill.Size.Y.Offset) end
		end
	end,
}

function TreeBinder.install(wm, actFn)
	WM, act = wm, actFn
end

return TreeBinder
