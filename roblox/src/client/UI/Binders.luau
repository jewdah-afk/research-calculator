--!nonstrict
-- Binders: live data + actions for the windows that already have a game system. Each binder gets the Figma-built
-- variant (UI/Figma/Render ui) and fills it from the server state; buttons send intents through the one Action
-- remote (the server validates every purchase). Windows without a binder show Figma's sample save (placeholder).
--
-- Upgrade lists (shop drawer EGGS / MOLT / SEEDS / golden, Mine SHOP) are rebuilt from the Figma row templates
-- (row/<id> (buy) / (need) / (max)) inside a ScrollingFrame, one row per Defs.UP id, so they scroll and grow with
-- the game. Row state changes swap the template; values update in place.
local RS = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Defs = require(RS:WaitForChild("Peckwood"):WaitForChild("Defs"))
local Render = require(script.Parent.Figma.Render)
local FKit = require(script.Parent.Figma.FKit)
local Kit = require(script.Parent.Kit)
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
	for i, it in items do
		local w = if it:IsA("TextLabel") then textW(it, (string.gsub(it.Text, "<[^>]+>", ""))) else it.Size.X.Offset
		widths[i] = w
		total += w + (if i > 1 then gap else 0)
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

local function fillRow(row, s, id)
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
		if y < 40 and x < rowW * 0.6 then Render.setText(t, string.upper(d.name))
		elseif y > 90 and x < rowW * 0.6 then Render.setText(t, d.desc) end
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
		for _, t in Render.childTexts(lvl) do Render.setText(t, "LV " .. shown .. " / " .. shownMax) end
		local fill = lvl:FindFirstChild("fill")
		if fill then fill.Size = UDim2.fromOffset(math.floor(lvl.Size.X.Offset * (if shownMax > 0 then math.clamp(shown / shownMax, 0, 1) else 1) + 0.5), fill.Size.Y.Offset) end
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
	-- price: BUY key face or the Mine price tag
	local priceText = fmt(cost)
	for _, c in row:GetChildren() do
		if string.sub(c.Name, 1, 7) == "btn/buy" then
			local face = c:FindFirstChild("face")
			if face then
				local its = kids(face)
				for _, it in its do
					if it:IsA("TextLabel") then Render.setText(it, priceText) end
					if it:IsA("ImageLabel") then it.Image = FKit.icon(Defs.CUR[d.cur].icon) end
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
		if y > 90 and x >= rowW * 0.6 and string.find(t.Text, "^Need") and not isMax then
			local have = EN.toNumber(s[d.cur])
			Render.setText(t, "Need " .. fmt(math.max(0, cost - have)) .. " more")
		end
	end
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
	local api = { sf = sf, rows = {}, ids = ids, family = family, x = first.x, h = first.h, gap = gap }
	return api
end
local function refreshList(api, s, onBuy)
	if not api then return end
	local y = 8
	for _, id in api.ids do
		if Defs.UP[id] then
			local st = rowState(s, id)
			local r = api.rows[id]
			if not r or r.state ~= st then
				if r then r.ui.root:Destroy() end
				local tp = templates[api.family][st] or templates[api.family].buy or templates[api.family].need
				local ui = Render.buildNode(tp.layout, tp.node, api.sf, 2)
				ui.root.Name = "row/" .. id
				-- icon slot shows this upgrade's icon (Figma names it ico/up_<thing>; keep the template art otherwise)
				r = { ui = ui, state = st }
				api.rows[id] = r
				ui.onAny(function(name, inst)
					if string.sub(name, 1, 7) == "btn/buy" then onBuy(id, false, inst)
					elseif name == "btn/max" then onBuy(id, true, inst) end
				end)
				if st == "buy" and r.wasState and r.wasState ~= "buy" then Kit.pop(ui.root, 1.04) end
			end
			r.ui.root.Position = UDim2.fromOffset(api.x, y)
			fillRow(r.ui.node, s, id)
			y += api.h + api.gap
		end
	end
	api.sf.CanvasSize = UDim2.fromOffset(0, y)
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
		ui.on("btn/molt", function(inst) act("molt", nil, nil, inst) end)
		ui.onAny(function(name)
			if string.sub(name, 1, 13) == "btn/auto-buy " then act("auto", not (WM.state and WM.state.auto)) end
		end)
	end,
	update = function(rec, ui, variant, s, d)
		refreshList(rec.lists and rec.lists[variant], s, buy)
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
B.fishing = {
	bind = function(rec, ui, variant)
		ui.on("btn/view in collection", function() WM.show(rec, "Fishing_Collection") end)
	end,
}

-- a purchase went through: the bought row's level bar / values are refreshed by the next state push; give the
-- buttery thock + a small pop on the open drawer row
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
