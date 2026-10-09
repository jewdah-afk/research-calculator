--!nonstrict
-- Binders: live data + actions for the windows that already have a game system. Each binder gets the Figma-built
-- variant (UI/Figma/Render ui) and fills it from the server state; buttons send intents through the one Action
-- remote (the server validates every purchase). Windows without a binder show Figma's sample save (placeholder).
--
-- Upgrade lists (shop drawer EGGS / MOLT / SEEDS / golden, Mine SHOP) are rebuilt from the Figma row templates
-- (row/<id> (buy) / (need) / (max)) inside a ScrollingFrame, one row per Defs.UP id, so they scroll and grow with
-- the game. Row state changes swap the template; values update in place.
-- Hierarchy: ONE primary per list (the cheapest affordable row gets the green BUY, a small "recommended" sparkle and,
-- in the sidebar, the single breathing attention glow); other affordable rows are steel keys with a white price and
-- "Can buy"; unaffordable rows are steel with the cost in red. Feel: hold BUY to repeat (accelerating), Shift-click
-- = MAX, LV bar eases, "+1 LV" pops off the icon, a row reaching MAX pops gold with sparkles and shimmers.
local RS = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Defs = require(RS:WaitForChild("Peckwood"):WaitForChild("Defs"))
local Render = require(script.Parent.Figma.Render)
local FKit = require(script.Parent.Figma.FKit)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local Sfx = require(script.Parent.Sfx)
local Layouts = script.Parent.Figma.Layouts
local EN = Defs.EN

local Binders = {}
local WM, act, Hud
Binders.fish = nil

local function fmt(v) return EN.short(v) end

-- ---------------------------------------------------------------- text helpers
local function textW(label: TextLabel, s: string)
	local ok, v = pcall(function() return TextService:GetTextSize(s, label.TextSize, Enum.Font.FredokaOne, Vector2.new(10000, 1000)).X end)
	return if ok then v else #s * label.TextSize * 0.6
end
local function moveLabel(label, x)
	local sh = Render.SHADOW[label]
	local dx = x - label.Position.X.Offset
	label.Position += UDim2.fromOffset(dx, 0)
	if sh then sh.Position += UDim2.fromOffset(dx, 0) end
end
-- lay a row of labels / chevrons out centred in their frame, Figma gaps (6 px), measured with the real font
local function centreRow(frame: Frame, items, gap)
	gap = gap or 6
	local widths, total = {}, 0
	local function measure()
		total = 0
		for i, it in items do
			local w = if it:IsA("TextLabel") then textW(it, (string.gsub(it.Text, "<[^>]+>", ""))) else it.Size.X.Offset
			widths[i] = w
			total += w + (if i > 1 then gap else 0)
		end
	end
	for _, it in items do
		if it:IsA("TextLabel") then
			local b = it:GetAttribute("baseSize") or it.TextSize
			it:SetAttribute("baseSize", b)
			it.TextSize = b
		end
	end
	measure()
	-- zero clipping: long live values shrink the row's text until it fits (min 10)
	local avail = frame.Size.X.Offset - 12
	if total > avail and avail > 0 then
		local f = avail / total
		for _, it in items do
			if it:IsA("TextLabel") then
				it.TextSize = math.max(10, math.floor(it.TextSize * f))
				local sh = Render.SHADOW[it]
				if sh then sh.TextSize = it.TextSize end
			end
		end
		measure()
	end
	local x = (frame.Size.X.Offset - total) / 2
	for i, it in items do
		if it:IsA("TextLabel") then
			it.Size = UDim2.fromOffset(widths[i] + 4, it.Size.Y.Offset)
			it.TextXAlignment = Enum.TextXAlignment.Left
			local sh = Render.SHADOW[it]
			if sh then sh.Size = it.Size; sh.TextXAlignment = Enum.TextXAlignment.Left end
			moveLabel(it, x)
		else
			it.Position = UDim2.fromOffset(x, it.Position.Y.Offset)
		end
		x += widths[i] + gap
	end
end
Binders.centreRow = centreRow
local function kids(frame)   -- texts + chevrons + icons of a frame in x order
	local out = {}
	for _, c in frame:GetChildren() do
		if (c:IsA("TextLabel") and not string.find(c.Name, "  %(drop%)$")) or c.Name == "growth chevrons" or (c:IsA("ImageLabel") and c.Name:sub(1, 4) == "ico/") then
			table.insert(out, c)
		end
	end
	table.sort(out, function(a, b) return a.Position.X.Offset < b.Position.X.Offset end)
	return out
end

-- ---------------------------------------------------------------- upgrade rows from Figma templates
local templates = {}       -- state -> { layout, node } (collected from every shop-type layout)
local units = {}           -- upgrade id -> unit text shown after the next value (from the Figma rows)
local function stateOf(name)
	local st = string.match(name, "%(([^)]+)%)$") or ""
	if string.find(st, "max") then return "max" elseif string.find(st, "buy") and not string.find(st, "cannot") then return "buy" end
	return "need"
end
local function collect(modName, family)
	local L = require(Layouts[modName])
	for _, n in Render.findNodes(L.root, function(x) return string.sub(x.n, 1, 4) == "row/" end) do
		local st = stateOf(n.n)
		templates[family] = templates[family] or {}
		templates[family][st] = templates[family][st] or { layout = L, node = n }
		local id = string.match(n.n, "^row/([%w_]+)")
		local eff = Render.findNode(n, "effect")
		if id and eff and eff.k then
			local big = 0
			for _, t in eff.k do if t.t == "T" then big = math.max(big, t.fs or 0) end end
			for _, t in eff.k do if t.t == "T" and (t.fs or 0) < big - 3 then units[id] = t.tx end end
		end
	end
end
local collected = false
local function collectAll()
	if collected then return end
	collected = true
	for _, m in { "Shop_Eggs", "Shop_Eggs_Golden", "Shop_Molt", "Shop_Seeds" } do collect(m, "drawer") end
	collect("Mine_Shop", "mine")
end

local function rowState(s, id)
	local L = Defs.level(s, id)
	local maxL = Defs.maxLevel(s, id)
	if L >= maxL then return "max" end
	local d = Defs.UP[id]
	return if EN.meeq(s[d.cur], Defs.cost(s, id, L)) then "buy" else "need"
end
-- the list's one primary: the cheapest affordable row
local function primaryOf(s, ids)
	local best, bestCost
	for _, id in ids do
		if Defs.UP[id] and rowState(s, id) == "buy" then
			local c = Defs.cost(s, id, Defs.level(s, id))
			local n = if type(c) == "number" then c else EN.toNumber(c)
			if not bestCost or n < bestCost then best, bestCost = id, n end
		end
	end
	return best
end

local function fillRow(row, s, id, st, r)
	local d = Defs.UP[id]
	local L = Defs.level(s, id)
	local maxL = Defs.maxLevel(s, id)
	local shown, shownMax = Defs.shownLevel(s, id)
	local isMax = L >= maxL
	local cost = if isMax then 0 else Defs.cost(s, id, L)
	local texts = Render.childTexts(row)
	local rowW = row.Size.X.Offset
	-- title (top-left text) and description (lower-left text)
	for _, t in texts do
		local x, y = t.Position.X.Offset, t.Position.Y.Offset
		if x < rowW * 0.6 and (y < 40 or y > 90) then
			-- zero clipping: title / description get the room up to the key column and shrink to fit it
			if not t:GetAttribute("fitted") then
				t:SetAttribute("fitted", true)
				t.TextWrapped = false
				t.Size = UDim2.fromOffset(math.floor(rowW * 0.66) - x, t.Size.Y.Offset)
				local sh = Render.SHADOW[t]
				if sh then sh.Size = t.Size; sh.TextWrapped = false end
				Render.fit(t, 10)
			end
			Render.setText(t, if y < 40 then string.upper(d.name) else d.desc)
		end
	end
	-- icon: the upgrade's own painted icon (up_* art falls back to its family icon until uploaded)
	local well = row:FindFirstChild("icon well")
	local ico = well and well:FindFirstChildWhichIsA("ImageLabel")
	if ico then
		local name = ico:GetAttribute("icon")
		if name then ico.Image = FKit.icon(name) end
	end
	-- level
	local lvl = row:FindFirstChild("level bar") or row:FindFirstChild("level")
	if lvl then
		for _, t in Render.childTexts(lvl) do
			Render.setText(t, "LV " .. shown .. " / " .. shownMax)
			if r and r.level and shown > r.level then Kit.pop(t, 1.25) end
		end
		local fill = lvl:FindFirstChild("fill")
		if fill then
			local w = math.floor(lvl.Size.X.Offset * (if shownMax > 0 then math.clamp(shown / shownMax, 0, 1) else 1) + 0.5)
			if r and r.level and w ~= fill.Size.X.Offset then
				TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(w, fill.Size.Y.Offset) }):Play()
			else
				fill.Size = UDim2.fromOffset(w, fill.Size.Y.Offset)
			end
		end
	end
	-- effect: now >>> next (+ unit), or the maxed value
	local eff = row:FindFirstChild("effect")
	if eff then
		local items = kids(eff)
		local vals = {}
		for _, it in items do if it:IsA("TextLabel") then table.insert(vals, it) end end
		local unit = units[id]
		if isMax then
			if vals[1] then Render.setText(vals[1], d.fx(L)) end
			if vals[2] then Render.setText(vals[2], unit or "") end
		else
			if vals[1] then Render.setText(vals[1], d.fx(L)) end
			if vals[2] then Render.setText(vals[2], d.fx(L + 1)) end
			if vals[3] then Render.setText(vals[3], unit or "") end
		end
		local vis = {}
		for _, it in items do if not (it:IsA("TextLabel") and it.Text == "") then table.insert(vis, it) end end
		centreRow(eff, vis)
	end
	-- price: BUY key face or the Mine price tag. Colour = state: white on the primary / affordable, red when short
	local priceText = fmt(cost)
	local priceCol = if st == "need" then Color3.fromHex("ff9a8a") else Color3.new(1, 1, 1)
	for _, c in row:GetChildren() do
		if string.sub(c.Name, 1, 7) == "btn/buy" then
			local face = c:FindFirstChild("face")
			if face then
				local its = kids(face)
				for _, it in its do
					if it:IsA("TextLabel") then Render.setText(it, priceText); Render.setTextColor(it, priceCol) end
					if it:IsA("ImageLabel") then
						it.Image = FKit.icon(Defs.CUR[d.cur].icon)
						it.ImageTransparency = if st == "need" then 0.45 else 0
					end
				end
				centreRow(face, its, 8)
			end
		elseif c.Name == "price tag" then
			local its = kids(c)
			for _, it in its do
				if it:IsA("TextLabel") and not isMax then Render.setText(it, priceText) end
				if it:IsA("ImageLabel") then it.Image = FKit.icon(Defs.CUR[d.cur].icon) end
			end
			centreRow(c, its, 8)
		end
	end
	-- the hint under the key: "Need X more" / "CAN BUY" / "Fully upgraded"
	for _, t in texts do
		local x, y = t.Position.X.Offset, t.Position.Y.Offset
		if y > 90 and x >= rowW * 0.6 and not isMax and (string.find(t.Text, "^Need") or string.find(t.Text, "^Can buy") or string.find(t.Text, "^CAN BUY")) then
			if st == "can" then
				Render.setText(t, "Can buy"); Render.setTextColor(t, Color3.fromHex("9dffae"))
			elseif st == "need" then
				local have = EN.toNumber(s[d.cur])
				Render.setText(t, "Need " .. fmt(math.max(0, cost - have)) .. " more"); Render.setTextColor(t, Color3.fromHex("ff9a8a"))
			end
		end
	end
	if r then r.level = shown end
end

-- turn a Figma "upgrade list" panel into a scrolling list of live rows
local function liveList(ui, family, ids, layoutName)
	collectAll()
	local list = ui.find("upgrade list")
	if not list then return nil end
	local L = require(Layouts[layoutName])
	local listNode = Render.findNode(L.root, "upgrade list")
	local rowNodes = Render.findNodes(listNode, function(x) return string.sub(x.n, 1, 4) == "row/" end)
	if #rowNodes == 0 then return nil end
	local first = rowNodes[1]
	local gap = if rowNodes[2] then rowNodes[2].y - first.y - first.h else 8
	-- remove the static sample rows (and the selection ring), keep headers
	for _, c in list:GetChildren() do
		local nm = c.Name
		if string.sub(nm, 1, 4) == "row/" or nm == "selected ring" then
			c:Destroy()
		elseif (nm == "drop" or nm == "shadow") and c:IsA("GuiObject") and c.Position.Y.Offset >= first.y - 20 then
			c:Destroy()   -- row shadows sit on the list as siblings: drop those below the first row's top
		end
	end
	local sf = Render.new("ScrollingFrame", { Name = "rows", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, first.y - 8),
		Size = UDim2.fromOffset(list.Size.X.Offset, list.Size.Y.Offset - first.y + 8), CanvasSize = UDim2.new(), ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromHex("8d94a3"), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 50 }, list)
	Render.styleScroll(sf, "0e131b")
	local api = { sf = sf, rows = {}, ids = ids, family = family, x = first.x, h = first.h, gap = gap }
	return api
end

-- hold BUY: first buy on release as usual; held past 0.35 s it repeats, faster and faster (server validates each)
local holdToken = nil
local function holdRepeat(fn, k)
	local token = {}
	holdToken = token
	task.delay(0.35, function()
		local iv = 0.22
		while holdToken == token do
			k.suppress = true
			fn()
			task.wait(iv)
			iv = math.max(0.06, iv * 0.8)
		end
	end)
end
local function holdStop() holdToken = nil end
-- the ONE attention target on screen (the sidebar's primary BUY breathes); everything else stays still
local attention = { key = nil, stop = nil }
local function setAttention(keyInst)
	if attention.key == keyInst then return end
	if attention.stop then attention.stop() end
	attention.key, attention.stop = keyInst, nil
	if keyInst then attention.stop = Motion.breathe(keyInst, "7dff86") end
end
Binders.setAttention = setAttention
local function refreshList(api, s, onBuy, attentionOn)
	if not api then return end
	local primary = primaryOf(s, api.ids)
	local y = 8
	local primaryKey
	for _, id in api.ids do
		if Defs.UP[id] then
			local st = rowState(s, id)
			if st == "buy" and id ~= primary then st = "can" end
			local r = api.rows[id]
			if not r or r.state ~= st then
				local was = r and r.state
				local level = r and r.level
				if r then r.ui.root:Destroy() end
				local tp = templates[api.family][if st == "can" then "need" else st] or templates[api.family].buy or templates[api.family].need
				local ui = Render.buildNode(tp.layout, tp.node, api.sf, 2)
				ui.root.Name = "row/" .. id
				r = { ui = ui, state = st, level = level }
				api.rows[id] = r
				ui.onAny(function(name, inst)
					local shift = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
					if string.sub(name, 1, 7) == "btn/buy" then onBuy(id, shift, inst)
					elseif name == "btn/max" then onBuy(id, true, inst) end
				end)
				ui.onDown = function(name, inst, k)
					if string.sub(name, 1, 7) == "btn/buy" then holdRepeat(function() onBuy(id, false, inst) end, k) end
				end
				ui.onUp = holdStop
				-- MAX stays a quiet steel key under BUY (the green BUY is the row's only strong element)
				local mx = ui.node:FindFirstChild("btn/max")
				if mx then
					local steel = FKit.PAL.steel
					for _, part in { { mx:FindFirstChild("face"), nil }, { mx:FindFirstChild("lip"), 0.58 } } do
						local f = part[1]
						if f then
							for _, gg in f:GetChildren() do if gg:IsA("UIGradient") then gg:Destroy() end end
							f.BackgroundColor3 = Color3.new(1, 1, 1); f.BackgroundTransparency = 0
							Render.gradient(f, FKit.vgrad(steel, part[2]), 1)
						end
					end
					local cap = mx:FindFirstChild("face") and mx.face:FindFirstChild("gloss cap")
					if cap then cap.BackgroundTransparency = 0.6 end
					for _, l in mx:GetDescendants() do
						if l:IsA("TextLabel") and not string.find(l.Name, "drop") then Render.setTextColor(l, Color3.fromHex("c9d2e3")) end
					end
				end
				-- the primary row: a small static "recommended" sparkle on its BUY key
				if st == "buy" then
					local key = ui.node:FindFirstChild("btn/buy")
					if key then
						Render.new("ImageLabel", { Name = "recommended", BackgroundTransparency = 1, Image = FKit.Icons["ui/sparkle"], ImageColor3 = Color3.fromHex("fff3b0"),
							AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(26, 26), ZIndex = 1000 }, key)
					end
					if was and was ~= "buy" then Kit.pop(ui.root, 1.06) end   -- turned affordable: one pop, no loop
				end
				if st == "max" and was and was ~= "max" then
					Sfx.maxed()
					task.defer(function()
						local plate
						for _, d in ui.node:GetDescendants() do
							if d:IsA("TextLabel") and d.Text == "MAXED" then plate = d.Parent end
						end
						Motion.maxed(plate, ui.node:FindFirstChild("level bar") or ui.node:FindFirstChild("level"), WM.canvas, plate and Hud.centreOf(plate))
					end)
				end
			end
			r.ui.root.Position = UDim2.fromOffset(api.x, y)
			local before = r.level
			fillRow(r.ui.node, s, id, st, r)
			if before and r.level and r.level > before then
				local well = r.ui.node:FindFirstChild("icon well")
				local p = well and Hud.centreOf(well)
				if p then Motion.floater(WM.canvas, p, "+" .. (r.level - before) .. " LV", "9dffae", 20) end
			end
			if st == "buy" then primaryKey = r.ui.node:FindFirstChild("btn/buy") end
			y += api.h + api.gap
		end
	end
	api.sf.CanvasSize = UDim2.fromOffset(0, y)
	if attentionOn then setAttention(primaryKey) end
end

-- upgrade ids per drawer view (Birb rowVisible: golden rows after the Desert, echo after the Echo Field)
local DRAWER_IDS = {
	Shop_Eggs = { "p_value", "p_speed", "p_capacity", "p_move_speed" },
	Shop_Eggs_Golden = { "p_golden_popcorn_value", "p_auric_silo", "d_desert_field_notes_plus" },
	Shop_Molt = { "pr_popcorn_mult", "pr_radius_mult", "pr_respawn_mult" },
	Shop_Seeds = { "s_more_popcorn", "s_more_feathers", "s_more_seeds" },
}
local function buy(id, all, inst) act("buy", id, all, inst) end

-- ---------------------------------------------------------------- per-window binders
local B = {}

B.shop = {
	bind = function(rec, ui, variant)
		rec.lists = rec.lists or {}
		rec.lists[variant] = liveList(ui, "drawer", DRAWER_IDS[variant] or {}, variant)
		-- MOLT is hold-to-confirm: a violet fill runs across the key; let go early and nothing happens
		local fillTween, fillFrame
		ui.onDown = function(name, inst, k)
			if name ~= "btn/molt" then return end
			local face = inst:FindFirstChild("face")
			if not face then return end
			fillFrame = Render.new("Frame", { Name = "hold fill", BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("e3c2ff"), BackgroundTransparency = 0.35,
				Size = UDim2.new(0, 0, 1, 0), ZIndex = 60 }, face)
			fillTween = TweenService:Create(fillFrame, TweenInfo.new(0.9, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			fillTween.Completed:Once(function(st)
				if st ~= Enum.PlaybackState.Completed then return end
				k.suppress = true
				act("molt", nil, nil, inst)
				local gw = ui.find("gain well")
				if gw then Hud.flyTo("goldenFeathers", gw, 8) end
			end)
			fillTween:Play()
		end
		ui.onUp = function()
			if fillTween then fillTween:Cancel(); fillTween = nil end
			if fillFrame then fillFrame:Destroy(); fillFrame = nil end
		end
		ui.on("btn/molt", function() Hud.toast("Hold MOLT to confirm", "info", "plume") end)
		ui.onAny(function(name)
			if string.sub(name, 1, 13) == "btn/auto-buy " then act("auto", not (WM.state and WM.state.auto)) end
		end)
	end,
	update = function(rec, ui, variant, s, d)
		refreshList(rec.lists and rec.lists[variant], s, buy, true)
		if variant == "Shop_Molt" then
			local hero = ui.find("molt hero")
			if hero then
				local gw = hero:FindFirstChild("gain well")
				if gw then
					local its = kids(gw)
					for _, it in its do if it:IsA("TextLabel") then Render.setText(it, "+" .. fmt(d.plumeGain)) end end
					centreRow(gw, its, 8)
				end
				for _, t in Render.childTexts(hero) do
					if string.find(t.Text, "plumes") then
						Render.setText(t, Hud.amount(s.goldenFeathers) .. " plumes  ·  molted " .. s.rebirbCount .. " times  ·  1 plume per 1,000 eggs")
					end
				end
			end
		end
	end,
}

B.mine = {
	bind = function(rec, ui, variant)
		if variant == "Mine_Shop" then
			rec.list = liveList(ui, "mine", { "m_ore_value", "m_mining_power", "m_charged_strike", "m_rupture" }, "Mine_Shop")
			ui.on("btn/buy", function(inst) buy(rec.selected or "m_mining_power", false, inst) end)
			ui.on("btn/max", function(inst) buy(rec.selected or "m_mining_power", true, inst) end)
		end
	end,
	update = function(rec, ui, variant, s, d)
		if variant == "Mine_Shop" then
			refreshList(rec.list, s, buy)
			local status = ui.find("status (header note)")
			if status then
				local vals = {}
				for _, t in Render.childTexts(status) do if t.TextSize >= 22 then table.insert(vals, t) end end
				table.sort(vals, function(a, b) return a.Position.X.Offset < b.Position.X.Offset end)
				if vals[1] then Render.setText(vals[1], tostring((s.crow.area or 0) + 1)) end
			end
			for _, t in Render.childTexts(ui.find("detail panel") or ui.root) do
				if string.find(t.Text, "^You have") then Render.setText(t, "You have " .. Hud.amount(s.bruteOre) .. " brute ore") end
			end
		end
	end,
}

B.evolve = {
	bind = function(rec, ui)
		ui.on("btn/hold to feed", function(inst)
			local s, d = WM.state, WM.derived
			if not s then return end
			if d and d.evoProgress >= 1 then act("evolve", nil, nil, inst); return end
			local need = Defs.EVO[s.evolutionCount + 1] or {}
			for k in need do act("feed", k, true, inst) end
		end)
	end,
}

B.sparrow = {
	bind = function(rec, ui)
		ui.on("btn/feed (on)", function(inst) act("sparrow", "feedall", nil, inst) end)
		ui.on("btn/drain (off)", function(inst) act("sparrow", "drain", nil, inst) end)
		ui.on("btn/mitosis", function(inst) act("sparrow", "split", nil, inst) end)
	end,
}
B.seagull = {
	bind = function(rec, ui)
		ui.on("btn/migrate (not ready)", function(inst) act("seagull", "migrate", nil, inst) end)
		ui.on("btn/frenzy", function() Hud.toast("Frenzy arrives with the Seagull update", "info", "seagull") end)
	end,
}
B.dave = {
	bind = function(rec, ui)
		ui.on("btn/reset", function(inst) act("dave", "rebirb", nil, inst) end)
		ui.on("btn/buy seed snacks", function(inst) act("buy", "dave_training", false, inst) end)
	end,
}
B.redpanda = {
	bind = function(rec, ui, variant)
		ui.on("btn/help (active, pressed)", function() act("panda", "on") end)
		ui.on("btn/switch to nap", function() act("panda", "off") end)
		-- Birb asks you to name the red panda the first time: show the naming card once per session
		if variant == "RedPanda" and not rec.named then
			rec.named = true
			task.defer(function() WM.show(rec, "RedPanda_Naming") end)
		end
	end,
}
B.parrot = {
	bind = function(rec, ui, variant)
		ui.on("btn/spend points", function() WM.show(rec, "Parrot_Upgrade") end)
		ui.on("btn/spend", function(inst) act("spend", "hp", false, inst) end)
		ui.on("btn/max", function(inst) act("spend", "hp", true, inst) end)
	end,
}
B.expedition = {
	bind = function(rec, ui)
		ui.on("btn/start", function(inst) act("expedition", nil, nil, inst); WM.close() end)
	end,
}
B.sacrifice = {
	bind = function(rec, ui)
		ui.on("btn/sacrifice all", function(inst) act("sacrifice", nil, nil, inst) end)
	end,
}
-- ---------------------------------------------------------------- FISHDEX: every species, live (426 fish)
-- The Figma grid (cells 97x130 at a 105 / 138 pitch, rod-tier section headers, "not found" silhouettes, rarity
-- plates) is rebuilt from its own templates inside a ScrollingFrame. Cells are built per tier section as they
-- scroll into view (never all 426 at once); the detail panel follows the clicked cell.
local RARITY = {   -- plate gradient + name colour per rarity (rare / epic / legendary / mythic are the Figma swatches)
	common = { { "4a5262", "262c37" }, "c9d2e3" }, uncommon = { { "2f7a35", "143d18" }, "9dffae" },
	rare = { { "255199", "112452" }, "6cb2ff" }, epic = { { "683599", "2e1259" }, "c893ff" },
	legendary = { { "986207", "4c2407" }, "ffc94a" }, mythic = { { "99254f", "4c0f26" }, "ff7a96" },
}
local function fishName(id)
	local n = string.gsub(string.gsub(id, "^fish_", ""), "_", " ")
	return (string.gsub(n, "(%a)([%w]*)", function(a, b) return string.upper(a) .. b end))
end
Binders.fishName = fishName
local function effectText(f)
	if not (f.effect and f.effect.type) then return "-" end
	local t = string.gsub(string.gsub(f.effect.type, "_mult$", ""), "_", " ")
	t = string.upper(string.sub(t, 1, 1)) .. string.sub(t, 2)
	return string.format("%s x%.2f", t, f.effect.value or 1)
end
local function rightAlign(label, right)
	local w = textW(label, (string.gsub(label.Text, "<[^>]+>", ""))) + 4
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Size = UDim2.fromOffset(w, label.Size.Y.Offset)
	local sh = Render.SHADOW[label]
	moveLabel(label, right - w)
	if sh then sh.Size = label.Size; sh.TextXAlignment = Enum.TextXAlignment.Right end
end
local function retintPlate(plate, cols)
	for _, g in plate:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
	plate.BackgroundColor3 = Color3.new(1, 1, 1); plate.BackgroundTransparency = 0
	Render.gradient(plate, { "g", 90, { { 0, cols[1], 1 }, { 1, cols[2], 1 } } }, 1)
end

local function fishdex(rec, ui)
	local L = require(Layouts.Fishing_Fishdex)
	local gridNode = Render.findNode(L.root, "dex grid")
	local tFound, tMiss, tHead
	for _, c in gridNode.k do
		if string.sub(c.n, 1, 5) == "cell/" then
			if string.find(c.n, "not found") then tMiss = tMiss or c
			elseif not string.find(c.n, "%(") then tFound = tFound or c end
		elseif string.sub(c.n, 1, 12) == "tier header/" and not string.find(c.n, "sticky") then tHead = tHead or c end
	end
	local grid = ui.find("dex grid")
	if not (grid and tFound and tMiss and tHead) then return end
	for _, c in grid:GetChildren() do
		local nm = c.Name
		if string.sub(nm, 1, 5) == "cell/" or string.sub(nm, 1, 12) == "tier header/" or nm == "selected ring" or nm == "scroll track" or nm == "scroll thumb" then
			c:Destroy()
		elseif (nm == "drop" or nm == "shadow") and c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local sf = Render.new("ScrollingFrame", { Name = "fish", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromHex("8d94a3"), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 50 }, grid)
	-- sections by rod tier (fish.minTier), Defs order inside a section
	local tiers, order = {}, {}
	for _, f in Defs.FISH do
		local t = f.minTier or 0
		if not tiers[t] then tiers[t] = {}; table.insert(order, t) end
		table.insert(tiers[t], f)
	end
	table.sort(order)
	local PITCH_X, PITCH_Y, COLS, X0 = 105, 138, 7, tFound.x   -- Figma cell pitch
	local sections, y = {}, 8
	for _, t in order do
		local rows = math.ceil(#tiers[t] / COLS)
		table.insert(sections, { tier = t, fish = tiers[t], y = y, built = false })
		y += tHead.h + 4 + rows * PITCH_Y
	end
	sf.CanvasSize = UDim2.fromOffset(0, y + 8)
	local ring
	local function select(f, cell)
		local disc = Binders.fish and Binders.fish.disc or {}
		local best = Binders.fish and Binders.fish.best or {}
		local found = disc[f.id] ~= nil
		local panel = ui.find("detail panel")
		if not panel then return end
		local hero = panel:FindFirstChild("hero")
		if hero then
			for _, d in hero:GetChildren() do
				if d:IsA("ImageLabel") and (d.Name:sub(1, 4) == "ico/" or d.Name == "drop") then
					d.Image = FKit.icon(f.id)
					if d.Name ~= "drop" then d.ImageColor3 = if found then Color3.new(1, 1, 1) else Color3.new(0, 0, 0) end
				end
			end
			local tag = hero:FindFirstChild("rarity tag")
			if tag then for _, t in Render.childTexts(tag) do Render.setText(t, string.upper(f.rarity)) end end
		end
		local rc = RARITY[f.rarity] or RARITY.common
		for _, t in Render.childTexts(panel) do
			if t.Name == "name" then Render.setText(t, if found then string.upper(fishName(f.id)) else "???") end
			if t.Name == "rarity + type" then
				Render.setText(t, string.upper(string.sub(f.rarity, 1, 1)) .. string.sub(f.rarity, 2) .. "  ·  " .. string.upper(string.sub(f.type or "", 1, 1)) .. string.sub(f.type or "", 2) .. " fish")
				Render.setTextColor(t, Color3.fromHex(rc[2]))
			end
		end
		local heavy = panel:FindFirstChild("heaviest catch")
		if heavy then
			for _, t in Render.childTexts(heavy) do
				if string.find(t.Text, "kg$") then Render.setText(t, if best[f.id] then string.format("%.2f kg", best[f.id]) else "-") end
			end
		end
		local facts = panel:FindFirstChild("facts")
		if facts then
			local labels = Render.childTexts(facts)
			for i, t in labels do
				if t.Position.X.Offset > 120 then
					local prev = labels[i - 1]
					local key = prev and prev.Text or ""
					if key == "Bites from" then Render.setText(t, "rod tier " .. (f.minTier or 0))
					elseif key == "When eaten" then Render.setText(t, effectText(f))
					elseif key == "Sells for" then Render.setText(t, fmt(f.sellValue or 0) .. " each")
					elseif key == "Shiny" then Render.setText(t, if found then "not found yet" else "-") end
					rightAlign(t, 292)
				end
			end
		end
		if cell then
			if not ring then
				local rn = Render.findNode(gridNode, "selected ring")
				if rn then ring = Render.buildNode(L, rn, sf, 60).root end
			end
			if ring then ring.Position = cell.Position - UDim2.fromOffset(5, 5) end
		end
	end
	local function buildSection(sec)
		if sec.built then return end
		sec.built = true
		local disc = Binders.fish and Binders.fish.disc or {}
		local best = Binders.fish and Binders.fish.best or {}
		local head = Render.buildNode(L, tHead, sf, 2)
		head.root.Position = UDim2.fromOffset(0, sec.y)
		local n = 0
		for _, f in sec.fish do if disc[f.id] then n += 1 end end
		local hl = Render.childTexts(head.node)
		if hl[1] then Render.setText(hl[1], "ROD TIER " .. sec.tier) end
		if hl[2] then Render.setText(hl[2], n .. " / " .. #sec.fish) end
		if hl[4] then Render.setText(hl[4], "bites from rod tier " .. sec.tier); rightAlign(hl[4], tHead.w - 4) end
		sec.cells = {}
		for i, f in sec.fish do
			local found = disc[f.id] ~= nil
			local cui = Render.buildNode(L, if found then tFound else tMiss, sf, 4)
			local cell = cui.root
			cell.Name = "cell/" .. f.id
			cell.Position = UDim2.fromOffset(X0 + ((i - 1) % COLS) * PITCH_X, sec.y + tHead.h + 4 + math.floor((i - 1) / COLS) * PITCH_Y)
			local rc = RARITY[f.rarity] or RARITY.common
			local plate = cui.node:FindFirstChild("plate")
			if plate and found then retintPlate(plate, rc[1]) end
			for _, d in (plate or cui.node):GetDescendants() do
				if d:IsA("ImageLabel") and (d.Name:sub(1, 4) == "ico/" or d.Name:sub(1, 11) == "silhouette/" or d.Name == "drop") then
					d.Image = FKit.icon(f.id)
					if not found and d.Name ~= "drop" then d.ImageColor3 = Color3.new(0, 0, 0) end
				end
			end
			local tl = Render.childTexts(cui.node)
			if tl[1] then
				Render.setText(tl[1], if found then fishName(f.id) else "???")
				Render.setTextColor(tl[1], Color3.fromHex(rc[2]))
			end
			if tl[2] then Render.setText(tl[2], if found and best[f.id] then string.format("%.2f kg", best[f.id]) else "not found") end
			local hit = Render.new("TextButton", { Name = "hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999 }, cell)
			hit.MouseButton1Down:Connect(function() Kit.sfx("click") end)
			hit.Activated:Connect(function() select(f, cell) end)
			sec.cells[f.id] = cui
		end
	end
	local function ensure()
		local top = sf.CanvasPosition.Y
		local bottom = top + math.max(grid.Size.Y.Offset, 400) + 300
		for _, sec in sections do
			if sec.y < bottom and sec.y + 2000 > top - 200 then buildSection(sec) end
		end
	end
	sf:GetPropertyChangedSignal("CanvasPosition"):Connect(ensure)
	ensure()
	rec.dex = { rebuild = function()
		for _, sec in sections do sec.built = false end
		for _, c in sf:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
		ring = nil
		ensure()
	end, seen = Binders.fish }
	if sections[1] and sections[1].fish[1] then select(sections[1].fish[1], nil) end
end

B.fishing = {
	bind = function(rec, ui, variant)
		ui.on("btn/view in collection", function() WM.show(rec, "Fishing_Collection") end)
		if variant == "Fishing_Fishdex" then fishdex(rec, ui) end
	end,
	update = function(rec, ui, variant)
		-- discoveries changed (Fish remote): rebuild the visible sections once
		if variant == "Fishing_Fishdex" and rec.dex and rec.dex.seen ~= Binders.fish then
			rec.dex.seen = Binders.fish
			rec.dex.rebuild()
		end
	end,
}

-- a purchase went through: the bought row's level bar / values are refreshed by the next state push; give the
-- buttery thock + a small pop on the open drawer row
-- Molt: the sidebar's rows dissolve and come back
function Binders.molted()
	local rec = WM.built.shop
	local v = rec and rec.current and rec.variants[rec.current]
	if v then
		Motion.collapse(v.ui.root)
		task.delay(0.45, function() Motion.restoreRows(v.ui.root); Motion.cascade(v.ui.root) end)
	end
end
-- Evolve: the feed rows wilt brown and fall away
function Binders.evolved()
	local rec = WM.built.evolve
	local v = rec and rec.holder.Visible and rec.current and rec.variants[rec.current]
	local panel = v and v.ui.root:FindFirstChild("feed panel", true)
	if panel then
		local rows = {}
		for _, c in panel:GetChildren() do if c:IsA("Frame") and c.Size.Y.Offset >= 40 then table.insert(rows, c) end end
		Motion.wilt(rows)
	end
end

function Binders.bought(id)
	for _, wid in { "shop", "mine" } do
		local rec = WM.built[wid]
		if rec then
			for _, l in (rec.lists or {}) do local r = l and l.rows[id]; if r then Kit.pop(r.ui.root, 1.03) end end
			if rec.list and rec.list.rows[id] then Kit.pop(rec.list.rows[id].ui.root, 1.03) end
		end
	end
end

function Binders.install(wm, actFn, hud)
	WM, act, Hud = wm, actFn, hud
	for id, b in B do WM.binders[id] = b end
end

return Binders
