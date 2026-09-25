--!strict
--[[
	Cp: Corrupted Prestige, symbol CR (DESIGN.md 6 row cp, 6.1 "cp terminal"). The Panel draws the corrupted shell
	(dashed lime rim, terminal body, breadcrumb); this adds:

	    hero      CAUSED / FIXED counters (the game's two highlighted numbers, Sarpanch 52), the essences as two stat
	              rows, and a black glossy CORRUPT with lime scanlines whose well reads "n charges" and a "next at"
	              chip (the prestige button's own gain / next, as sent). The source lines leave the body.
	    MODE      ESSENCE & RECHARGE MODE: the two mode clickables as a radio (one press, the clickable's own action)
	    DISKS     the grid as a terminal window (C:\CORRUPTION\DISKS, cols x rows, corrupted / fixing counts): 104 du
	              tiles from gs / lv / kind (empty = quiet slot id, Trojan lime dashed, Backdoor crimson dashed, active
	              or chosen gold with the fix bar), a legend, and the INSPECTOR: the selected disk's fix / debuff /
	              reward (gx), the fix progress once as the game's ASCII bar, ACTIVATE / DEACTIVATE (the tile's own
	              action). Mouse: a click fires the tile, hovering selects it; touch: a tap selects, the inspector acts.
	At most 36 tiles, each at most 8 instances.
]]

local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Rich = require(Core:WaitForChild("Rich"))
local Layout = require(Core:WaitForChild("Layout"))
local Recipes = require(Core:WaitForChild("Recipes"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Sections = require(PanelF:WaitForChild("Sections"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P

local C = Theme.C
local LIME = Theme.hue("cp")

local function trim(s: string): string
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end

-- the display-text lines the hero takes over (they carry the game's highlighted numbers)
local function heroLine(h: any): string?
	if type(h) ~= "string" or not string.find(h, "<h2", 1, true) then return nil end
	if string.find(h, "caused", 1, true) then return "counts" end
	if string.find(h, "corruption essences", 1, true) then return "essences" end
	return nil
end

-- ------------------------------------------------------------------------------------------------------ hero
local function hero(f: Frame, store: any, ctx: any)
	local a = Kit.accent(f, "Cp")
	local compact = Layout.mode == "COMPACT"
	local counts: { string } = {}
	local ess, boost = nil :: string?, nil :: string?
	for _, id in Kit.findAll(store, "tab", function(n: any): boolean
		return n.cn == "display-text" and heroLine(n.h) ~= nil
	end, 4) do
		local n = store:get(id)
		local kind = heroLine(n.h)
		if kind == "counts" then
			counts = Kit.h2(n.h)
		elseif kind == "essences" then
			ess = Kit.h2(n.h)[1]
			local plain = Common.plain(n.h)
			boost = string.match(plain, "gain by%s+([^%s%(]+)")
		end
	end
	-- the counters and the essences rows (WIDE: left block; COMPACT: the column's top)
	local block = Common.get(a, "Block", "Frame") :: Frame
	block.Active = false
	block.Position = UDim2.new()
	block.Size = UDim2.new(if compact then 1 else 0, if compact then 0 else 560, 0, 0)
	block.AutomaticSize = Enum.AutomaticSize.Y
	Common.list(block, false, if compact then 4 else 6)
	local row = Common.get(block, "Counts", "Frame") :: Frame
	row.Active = false
	row.LayoutOrder = 1
	row.Size = UDim2.new(1, 0, 0, if compact then 40 else 64)
	Common.list(row, true, if compact then 14 else 28, { valign = Enum.VerticalAlignment.Bottom })
	local labels = { "Caused", "Fixed" }
	for i = 1, 2 do
		local v = counts[i]
		local name = labels[i]
		if v then
			local cap = Common.get(row, name .. "Cap", "TextLabel") :: TextLabel
			cap.Active = false
			cap.LayoutOrder = i * 2 - 1
			Common.text(cap, "caps", C.termDim)
			cap.AutomaticSize = Enum.AutomaticSize.X
			cap.Size = UDim2.fromOffset(0, 20)
			cap.TextYAlignment = Enum.TextYAlignment.Bottom
			Common.setText(cap, Common.esc(Rich.caps(name)))
			local num = Common.get(row, name, "TextLabel") :: TextLabel
			num.LayoutOrder = i * 2
			num.AutomaticSize = Enum.AutomaticSize.X
			num.Size = UDim2.fromOffset(0, if compact then 36 else 60)
			num.TextXAlignment = Enum.TextXAlignment.Left
			local sig = v .. "|" .. tostring(compact)
			if num:GetAttribute("Sig") ~= sig then
				num:SetAttribute("Sig", sig)
				Recipes.number(num, { text = v, size = if compact then 30 else 52, from = C.white, mid = Theme.lift(LIME, 0.4),
					to = if i == 1 then LIME else C.bought, stroke = if compact then 4 else 6, shadow = if compact then 2 else 4, role = "big" })
			end
		else
			Common.drop(row, name .. "Cap")
			Common.drop(row, name)
		end
	end
	local rows: { { string } } = {}
	if ess then table.insert(rows, { "Corruption essences", ess }) end
	if boost then table.insert(rows, { "Points & PE gain", "×" .. boost }) end
	for i = 1, 2 do
		local r = rows[i]
		local name = "Stat" .. i
		if r then
			local l = Common.label(block, name, "small", C.termDim, { order = 1 + i, wrap = false })
			Common.setText(l, Common.esc(r[1]) .. "   " .. Common.num(if compact then Rich.short(r[2]) else r[2], "numberHeavy", C.termLime))
		else
			Common.drop(block, name)
		end
	end
	-- CORRUPT: black gloss, lime rim and scanlines; the well reads the charges, a chip the next charge
	local cta = f:FindFirstChild("Cta") :: GuiObject?
	local pb = Kit.resetNode(store)
	if cta and pb then
		local fill = cta:FindFirstChild("Fill")
		if fill and fill:IsA("UIGradient") then
			fill.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 44, 36)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 14, 9)),
				ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
			})
		end
		local rim = cta:FindFirstChild("Rim")
		if rim and rim:IsA("UIStroke") then
			local rg = rim:FindFirstChild("RimGradient")
			if rg and rg:IsA("UIGradient") then rg.Color = ColorSequence.new(Theme.lift(LIME, 0.3), Theme.shade(LIME, 0.6)) end
		end
		Common.glow(cta, if pb.cls == "can" then LIME else nil, 0.5, 18)
		local scan = Kit.stripes(cta, LIME, 0.06, 16, 90, "Scan")
		if scan then
			scan.ZIndex = 9
			Kit.tether(a, "ScanGuard", scan)
		end
		local well = cta:FindFirstChild("Well") :: TextLabel?
		local gain = Common.str(pb.gain)
		if well and gain and pb.cls == "can" then
			Common.setText(well, Common.num(gain, "ctaSub", C.text, "charges", true))
		end
		local nextAt = Common.str(pb.next)
		if nextAt and not compact then
			local stats = f:FindFirstChild("Stats") :: GuiObject?
			local y = cta.Size.Y.Offset + 10 + (if stats and stats.Visible then 42 else 0)
			local chip = Common.chip(a, "Next", Common.caps("Next charge at", C.termDim) .. "   "
				.. Common.num(nextAt, "number", C.termLime, Common.plain(Common.str(pb.bres) or "")), { rich = true, bg = Color3.new(0, 0, 0), bgT = 0.2, h = 34 })
			chip.AnchorPoint = Vector2.new(1, 0)
			chip.Position = UDim2.new(1, 0, 0, y)
		else
			Common.drop(a, "Next")
		end
	else
		Common.drop(a, "Next")
	end
end

-- the hero's source lines leave the body; the explainer stays a note (terminal text)
local function noteClaim(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	function claim.update(_: any, st: any)
		local n = st:get(id)
		local h = if type(n) == "table" then n.h else nil
		local text = Common.plain(h)
		if heroLine(h) or not string.find(text, "%S") then
			ph.Visible = false
			ph.Size = UDim2.new()
			ph.AutomaticSize = Enum.AutomaticSize.None
			Common.drop(ph, "Text")
			return
		end
		ph.Visible = true
		ph.Size = UDim2.new(1, 0, 0, 0)
		ph.AutomaticSize = Enum.AutomaticSize.Y
		ph.BackgroundColor3 = Color3.fromRGB(4, 16, 6)
		ph.BackgroundTransparency = 0.2
		Common.corner(ph, 10)
		Common.stroke(ph, 1, C.stableId, 0.4)
		Common.pad(ph, 10, 14, 10, 14)
		local l = Common.label(ph, "Text", "terminal", C.termLime)
		Common.setText(l, Common.esc("> ") .. Common.html(h, "terminal", ctx.layer))
	end
	function claim.destroy(_: any)
		Common.drop(ph, "Text")
	end
	return claim
end

-- ------------------------------------------------------------------------------------------------------ mode radio
local function modeClaim(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	ph.Size = UDim2.new(1, 0, 0, 0)
	ph.AutomaticSize = Enum.AutomaticSize.Y
	Common.list(ph, false, 12)
	function claim.update(_: any, st: any)
		store = st or store
		local compact = Layout.mode == "COMPACT"
		local ids = Kit.findAll(st, id, function(n: any): boolean
			return n.t == "btn" and n.k == "click"
		end, 3)
		Sections.header(ph, { name = "Head", order = 0, text = "ESSENCE & RECHARGE MODE", hue = LIME })
		local row = Kit.stack(ph, "Options", true, 12, 1)
		local used: { [string]: boolean } = { List = true }
		for i, cid in ids do
			local n = st:get(cid)
			local plain = trim(Common.plain(n.h or ""))
			local mode = string.match(plain, "mode to (.-),") or string.match(plain, "mode to (.-)%.") or plain
			local rest = string.match(plain, ",%s*(.*)$")
			local current = n.cls ~= "can" -- the game locks the mode you are already in
			local name = "O" .. i
			used[name] = true
			local b = Common.get(row, name, "TextButton") :: TextButton
			b.LayoutOrder = i
			b.AutoButtonColor = false
			b.Size = UDim2.fromOffset(if compact then math.floor((Kit.live(ctx).contentW - 12) / 2) else 420, 0)
			b.AutomaticSize = Enum.AutomaticSize.Y
			b.BackgroundColor3 = if current then Color3.fromRGB(12, 40, 14) else Color3.fromRGB(6, 18, 8)
			b.BackgroundTransparency = 0
			Common.corner(b, 12)
			Common.stroke(b, if current then 2 else 1, if current then LIME else C.stableId, if current then 0 else 0.3)
			Common.pad(b, 12, 14, 12, 44)
			Common.text(b, "small", C.termLime)
			b.TextWrapped = true
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.TextYAlignment = Enum.TextYAlignment.Top
			local text = Common.run(Common.esc(mode), "label", if current then C.text else C.termLime)
			if rest and rest ~= "" then text ..= "\n" .. Common.run(Common.esc(rest), "small", C.termDim) end
			Common.setText(b, text)
			-- the radio dot
			local dot = Common.get(b, "Dot", "Frame") :: Frame
			dot.Active = false
			dot.Position = UDim2.fromOffset(-30, 1)
			dot.Size = UDim2.fromOffset(18, 18)
			dot.BackgroundColor3 = if current then LIME else Color3.new(0, 0, 0)
			dot.BackgroundTransparency = 0
			Common.corner(dot, 0.5)
			Common.stroke(dot, 2, LIME, if current then 0 else 0.4)
			Common.state(b, if current then "owned" else "can")
			Kit.onPress(b, function()
				local x = store:get(cid)
				if type(x) == "table" and type(x.a) == "table" and x.cls == "can" then ctx.act(x.a, false) end
			end)
		end
		for _, c in row:GetChildren() do
			if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
		end
	end
	function claim.destroy(_: any)
		for _, c in ph:GetChildren() do c:Destroy() end
	end
	return claim
end

-- ------------------------------------------------------------------------------------------------------ disks
local selected: { [string]: string } = {} -- the inspected disk per layer (its action id), for the session

local function tileLook(b: TextButton, n: any, size: number)
	local gs = n.gs
	local backdoor = n.kind == "backdoor"
	local rim = if gs == "active" or gs == "chosen" then C.complete elseif backdoor then C.danger else C.termLime
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundTransparency = 0
	Common.corner(b, 12)
	Common.text(b, "small", C.termLime)
	b.TextWrapped = true
	b.TextXAlignment = Enum.TextXAlignment.Center
	b.TextYAlignment = Enum.TextYAlignment.Center
	local slot = Common.str(n.id) or ""
	if gs == "empty" then
		b.BackgroundColor3 = Color3.fromRGB(6, 16, 8)
		local s = Common.stroke(b, 1, C.stableId, 0.5)
		Common.drop(s, "Dash")
		Common.setText(b, Common.run(Common.esc(slot), "label", C.stableId))
		Common.drop(b, "Bar")
		return
	end
	b.BackgroundColor3 = if gs == "active" or gs == "chosen" then Color3.fromRGB(34, 30, 8) else Color3.fromRGB(8, 28, 12)
	local s = Common.stroke(b, 2, rim, 0)
	if gs == "corrupted" then Recipes.dashed(s, { color = rim }) else Common.drop(s, "Dash") end
	local lv = math.floor(tonumber(n.lv) or 0)
	local kind = if backdoor then "Backdoor" else "Trojan"
	Common.setText(b, Common.caps(kind, rim) .. "\n" .. Common.caps("Lv", C.termDim) .. " "
		.. Common.num(tostring(lv), if size >= 100 then "numberHeavy" else "number", C.text) .. "\n" .. Common.run(Common.esc(slot), "label", C.termDim))
	local gp = Common.pr(n.gp)
	if gp and (gs == "active" or gs == "chosen") then
		local bar = Common.bar(b, "Bar", gp, C.complete, 5)
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, -8)
		bar.Size = UDim2.new(1, -20, 0, 5)
	else
		Common.drop(b, "Bar")
	end
end

-- the game's ASCII progress bar (the fix progress, shown once)
local function ascii(p: number): string
	local k = math.clamp(math.floor(p * 10 + 0.5), 0, 10)
	return "[" .. string.rep("#", k) .. string.rep("=", 10 - k) .. "]  -< " .. Rich.pct(p) .. " >-"
end

local function gridClaim(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	ph.Size = UDim2.new(1, 0, 0, 0)
	ph.AutomaticSize = Enum.AutomaticSize.Y
	local layer = ctx.layer
	local draw: (st: any) -> () = nil :: any
	local function inspect(key: string)
		selected[layer] = key
		draw(store)
	end
	draw = function(st: any)
		store = st or store
		local compact = Layout.mode == "COMPACT"
		local tiles: { string } = {}
		local cols = 0
		for _, rid in st:kids(id) do
			local r = st:get(rid)
			if type(r) ~= "table" then continue end
			local c = 0
			for _, tid in st:kids(rid) do
				local t = st:get(tid)
				if type(t) == "table" and t.t == "btn" and t.k == "grid" and #tiles < 36 then
					table.insert(tiles, tid)
					c += 1
				end
			end
			cols = math.max(cols, c)
		end
		local rowsN = if cols > 0 then math.ceil(#tiles / cols) else 0
		local corrupted, fixing = 0, 0
		for _, tid in tiles do
			local t = st:get(tid)
			if t.gs == "active" or t.gs == "chosen" then fixing += 1 elseif t.gs ~= "empty" then corrupted += 1 end
		end
		-- the terminal window
		local win = Kit.card(ph, "Window", { gap = 12, pad = if compact then 10 else 16, fill = Color3.fromRGB(2, 10, 3), stroke = LIME,
			strokeT = 0.45, radius = 14 })
		local head = Common.label(win, "Head", "terminalBold", C.termLime, { order = 1, wrap = false })
		Common.setText(head, Common.esc("C:\\CORRUPTION\\DISKS")
			.. "   " .. Common.run(Common.esc(cols .. " × " .. rowsN .. " · " .. corrupted .. " corrupted · " .. fixing .. " fixing"), "small", C.termDim))
		local body = Common.get(win, "Body", "Frame") :: Frame
		body.LayoutOrder = 2
		body.Active = false
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		Common.list(body, not compact, 16, { valign = Enum.VerticalAlignment.Top })
		local size = if compact then 84 else 104
		local gap = 10
		local grid = Common.get(body, "Grid", "Frame") :: Frame
		grid.LayoutOrder = 1
		grid.Active = false
		grid.Size = UDim2.fromOffset(math.max(1, cols) * (size + gap) - gap, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		local gl = Common.get(grid, "Layout", "UIGridLayout") :: UIGridLayout
		gl.CellSize = UDim2.fromOffset(size, size)
		gl.CellPadding = UDim2.fromOffset(gap, gap)
		gl.FillDirection = Enum.FillDirection.Horizontal
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		pcall(function()
			gl.FillDirectionMaxCells = math.max(1, cols)
		end)
		-- the selection: the kept one if it is still a disk, else the first fixing / corrupted disk
		local sel = selected[layer]
		local selId: string? = nil
		for _, tid in tiles do
			local t = st:get(tid)
			if tostring(t.id) == sel then selId = tid end
		end
		if selId == nil then
			for _, tid in tiles do
				local t = st:get(tid)
				if t.gs == "active" or t.gs == "chosen" then
					selId = tid
					break
				end
			end
		end
		if selId == nil then
			for _, tid in tiles do
				if st:get(tid).gs ~= "empty" then
					selId = tid
					break
				end
			end
		end
		local used: { [string]: boolean } = { Layout = true }
		for i, tid in tiles do
			local t = st:get(tid)
			local name = "D" .. tostring(t.id)
			used[name] = true
			local b = Common.get(grid, name, "TextButton") :: TextButton
			b.LayoutOrder = i
			tileLook(b, t, size)
			if tid == selId then
				local s = b:FindFirstChild("Border")
				if s and s:IsA("UIStroke") then s.Thickness = 3 end
			end
			Common.state(b, if t.gs == "empty" then "notyet" else "can")
			local key = tostring(t.id)
			Kit.onPress(b, function()
				local touch = false
				pcall(function()
					touch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
				end)
				if touch then
					inspect(key)
					return
				end
				local x = store:get(tid)
				if type(x) == "table" and type(x.a) == "table" then ctx.act(x.a, false) end
			end)
			if b:GetAttribute("Hover") ~= true then
				b:SetAttribute("Hover", true)
				b.MouseEnter:Connect(function()
					if selected[layer] ~= key then inspect(key) end
				end)
			end
		end
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
		end
		-- the inspector
		local ins = Kit.card(body, "Inspector", { order = 2, gap = 8, pad = 14, fill = Color3.fromRGB(4, 18, 6), stroke = LIME, strokeT = 0.5,
			w = if compact then nil else 300, radius = 12 })
		local s = if selId then st:get(selId) else nil
		local lines: { string } = {}
		if s then
			local kind = if s.kind == "backdoor" then "Backdoor" else "Trojan"
			table.insert(lines, Common.run(Common.esc("> DISK " .. tostring(s.id)), "terminalBold", C.termLime))
			if s.gs == "empty" then
				table.insert(lines, Common.run(Common.esc("Stable. No corruptions detected."), "small", C.termDim))
			else
				table.insert(lines, Common.caps(kind, if s.kind == "backdoor" then Theme.lift(C.danger, 0.3) else C.termLime) .. "  "
					.. Common.caps("Lv", C.termDim) .. " " .. Common.num(tostring(math.floor(tonumber(s.lv) or 0)), "number", C.text))
				local gx = if type(s.gx) == "table" then s.gx else nil
				if gx then
					local fres = Common.plain(Common.str(gx.fres) or "")
					if gx.fix then table.insert(lines, Common.run("To fix, get", "small", C.termDim) .. "  " .. Common.num(tostring(gx.fix), "number", C.termLime, fres)) end
					if gx.deb then table.insert(lines, Common.run("While active,", "small", C.termDim) .. "  " .. Common.num("/" .. tostring(gx.deb), "number", C.termLime, fres .. " gain")) end
					if gx.rew then table.insert(lines, Common.run("Reward", "small", C.termDim) .. "  " .. Common.num(tostring(gx.rew), "number", C.termLime, "essences")) end
				end
				local gp = Common.pr(s.gp)
				if gp then table.insert(lines, Common.run(Common.esc(ascii(gp)), "terminal", C.complete)) end
			end
		else
			table.insert(lines, Common.run(Common.esc("> no disk selected"), "terminal", C.termDim))
		end
		local info = Common.label(ins, "Info", "small", C.termLime, { order = 1 })
		info.LineHeight = Theme.lineHeight("terminal")
		Common.setText(info, table.concat(lines, "\n"))
		if s and s.gs ~= "empty" and type(s.a) == "table" then
			local active = s.gs == "active" or s.gs == "chosen"
			local b = Kit.button(ins, "Act", Common.esc(if active then "DEACTIVATE" else "ACTIVATE"), { fill = if active then Color3.fromRGB(40, 34, 8) else Color3.fromRGB(10, 44, 14),
				ink = if active then C.complete else C.termLime, stroke = if active then C.complete else LIME, h = 40, w = 1, order = 2 })
			Common.state(b, "can")
			local sid = selId :: string
			Kit.onPress(b, function()
				local x = store:get(sid)
				if type(x) == "table" and type(x.a) == "table" then ctx.act(x.a, false) end
			end)
		else
			Common.drop(ins, "Act")
		end
		-- the legend
		local legend = Common.label(win, "Legend", "small", C.termDim, { order = 3, wrap = true })
		local function dot(c: Color3): string
			return Common.run("•", "label", c)
		end
		Common.setText(legend, dot(C.termLime) .. " Trojan     " .. dot(C.danger) .. " Backdoor     " .. dot(C.complete) .. " Fixing     "
			.. dot(C.stableId) .. " Stable")
	end
	function claim.update(_: any, st: any)
		draw(st)
	end
	function claim.destroy(_: any)
		Common.drop(ph, "Window")
	end
	return claim
end

-- scanlines over the header band
local function accent(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	local a = Kit.accent(band, "Cp")
	Kit.stripes(a, LIME, 0.05, 22, 90)
end

return {
	layers = { "cp" },
	corrupted = true,
	skin = P.skin,
	hero = hero,
	accent = accent,
	claims = ({
		{ match = { cn = "display-text" }, make = noteClaim },
		{ match = { cn = "clickables" }, make = modeClaim },
		{ match = { cn = "grid" }, make = gridClaim },
	} :: { any }),
}
