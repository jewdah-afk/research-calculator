--!strict
--[[
	Sp: Super Prestige (DESIGN.md 6 row sp, 6.1 "sp furnace").

	    Main              the tier board (P.skin: Hide owned)
	    malware tabs      an ember rim over the sheet (Prestige Ashes, Spark Milestones); an infected layer (the resource
	                      name says so) rings the emblem in danger
	    hero              PRESTIGE ASHES as a stat chip under the CTA (the game's highlighted number, as sent)
	    Spark Milestones  the FURNACE: the game's unlock box as a titled card (ember orb, ASHES FILLED with the bar,
	                      "3 / 3 unlocked", IGNITE with its auto-fill state, REIGNITE #n with its cost);
	                      SPARK MILESTONES: one card per milestone with its burn bar (BURNING in flame colours with the
	                      burning %, ASHED grey, PERMANENT gold "Skipped when burning"), the "Show: N" cycler in the title
	                      row (one press, the clickable's own action); the pager « ‹ Page a / b › », hidden on one page
	Every button fires its clickable's own action.
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Rich = require(Core:WaitForChild("Rich"))
local Layout = require(Core:WaitForChild("Layout"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Sections = require(PanelF:WaitForChild("Sections"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P
local M = require(script.Parent:WaitForChild("M")) :: any

local C = Theme.C
local SPARK = "Spark Milestones"

local function trim(s: string): string
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end
local function plainOf(n: any): string
	return trim(Common.plain(if type(n) == "table" then n.h else ""))
end
-- a clickable node's action at press time
local function fire(ctx: any, store: any, id: string)
	local n = store:get(id)
	if type(n) == "table" and type(n.a) == "table" then ctx.act(n.a, false) end
end

-- ------------------------------------------------------------------------------------------------------ furnace
local function furnace(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	ph.Size = UDim2.new(1, 0, 0, 0)
	ph.AutomaticSize = Enum.AutomaticSize.Y
	function claim.update(_: any, st: any)
		store = st or store
		local compact = Layout.mode == "COMPACT"
		local ember = C.ember
		local card = Kit.card(ph, "Furnace", { gap = 12, pad = if compact then 12 else 18, fill = Theme.mix(C.panel, ember, 0.14),
			stroke = ember, strokeT = 0.2, radius = 16 })
		-- the game's texts: the unlock line, the ashes pair and the unlocked pair (as sent)
		local info, have, need, unl, tot = "", nil :: string?, nil :: string?, nil :: string?, nil :: string?
		local buttons: { string } = {}
		for _, cid in st:kids(id) do
			local n = st:get(cid)
			if type(n) ~= "table" then continue end
			if n.t == "btn" and n.k == "click" then
				table.insert(buttons, cid)
			elseif n.t == "html" then
				local t = plainOf(n)
				if t ~= "" then
					local a, b = string.match(t, "([%d%.,e%+]+)%s*/%s*([%d%.,e%+]+)%s*Prestige Ashes")
					if a then have, need = a, b end
					local u, v = string.match(t, "Unlocked%s+(%d+)%s*/%s*(%d+)")
					if u then unl, tot = u, v end
					local head = string.match(t, "^(.-):")
					if head and info == "" then info = trim(head) end
				end
			end
		end
		-- the head: ember orb, the title and ASHES FILLED
		local head = Common.label(card, "Head", "body", C.text, { order = 1 })
		Common.pad(head, 0, if unl then 130 else 0, 0, 62, "Clear")
		local lines = { Common.title(if info ~= "" then info else "Spark furnace", "card", C.text) }
		if have and need then
			table.insert(lines, Common.caps("Ashes filled", C.soft) .. "   " .. Common.num(have .. " / " .. need, "number", C.text, "ashes"))
		end
		Common.setText(head, table.concat(lines, "\n"))
		local orb = Common.get(head, "Orb", "Frame") :: Frame
		orb.Active = false
		orb.Size = UDim2.fromOffset(48, 48)
		orb.Position = UDim2.fromOffset(-62, 0)
		Common.corner(orb, 0.5)
		orb.BackgroundColor3 = ember
		orb.BackgroundTransparency = 0
		Common.stroke(orb, 2, Theme.lift(ember, 0.45), 0)
		Common.glow(orb, ember, 0.55, 14)
		local core = Common.get(orb, "Core", "Frame") :: Frame
		core.Active = false
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		core.Position = UDim2.fromScale(0.5, 0.58)
		core.Size = UDim2.fromOffset(18, 22)
		core.BackgroundColor3 = C.ready
		core.BackgroundTransparency = 0
		Common.corner(core, 0.5)
		if unl and tot then
			local chip = Common.chip(head, "Unlocked", unl .. " / " .. tot .. " unlocked", { color = C.ink, bg = C.gold, bgT = 0, h = 28 })
			chip.AnchorPoint = Vector2.new(1, 0)
			chip.Position = UDim2.new(1, 130, 0, 0)
		else
			Common.drop(head, "Unlocked")
		end
		-- the ashes bar
		local p = 0
		local hn, nn = tonumber((string.gsub(have or "", ",", ""))), tonumber((string.gsub(need or "", ",", "")))
		if hn and nn and nn > 0 then p = math.clamp(hn / nn, 0, 1) end
		if have then
			local bar = Common.bar(card, "Bar", p, Theme.lift(ember, 0.15), 8)
			bar.LayoutOrder = 2
		else
			Common.drop(card, "Bar")
		end
		-- IGNITE (with its auto-fill state) and REIGNITE #n (with its cost)
		local row = Kit.stack(card, "Buttons", true, 10, 3)
		local list = row:FindFirstChild("List") :: UIListLayout?
		if list then list.Wraps = true end
		local used: { [string]: boolean } = { List = true }
		for i, cid in buttons do
			local n = st:get(cid)
			local t = Common.plain(Common.str(n.ti) or n.h or "")
			local num = string.match(t, "#(%d+)")
			local can = n.cls == "can"
			local text: string
			local fill: Color3
			if num then
				local cost = string.match(n.h or "", "<b>([^<]+)</b>")
				text = Common.run(Common.esc(Rich.caps("Reignite") .. " #" .. num), "label", C.text)
				if cost then text ..= "   " .. Common.num(trim(cost), "number", C.text, "ashes") end
				fill = if can then Theme.mix(C.panel, ember, 0.45) else C.panel3
			else
				local auto = string.match(Common.plain(n.h or ""), "Auto%-fill:%s*(%u+)")
				text = Common.run(Common.esc("IGNITE"), "tab", if can then C.ink else C.text)
				if auto then
					text ..= "    " .. Common.run(Common.esc("Auto-fill " .. auto), "label", if can then C.ink else C.soft)
				end
				fill = if can then ember else C.panel3
			end
			local name = "B" .. i
			used[name] = true
			local b = Kit.button(row, name, text, { fill = fill, stroke = if can then Theme.lift(ember, 0.4) else C.stroke, h = 42, order = i })
			Common.state(b, if can then "can" else "notyet")
			Kit.onPress(b, function()
				fire(ctx, store, cid)
			end)
		end
		for _, c in row:GetChildren() do
			if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
		end
	end
	function claim.destroy(_: any)
		Common.drop(ph, "Furnace")
	end
	return claim
end

-- ------------------------------------------------------------------------------------------------------ sparks
local STATE_COL = { burning = C.ember, ashed = C.muted, permanent = C.gold }

local function sparkList(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	ph.Size = UDim2.new(1, 0, 0, 0)
	ph.AutomaticSize = Enum.AutomaticSize.Y
	Common.list(ph, false, 12)
	function claim.update(_: any, st: any)
		store = st or store
		local compact = Layout.mode == "COMPACT"
		-- each row: a spark milestone and its burn bar
		local items: { { ms: any, bar: any, key: string } } = {}
		for _, rid in st:kids(id) do
			local r = st:get(rid)
			if type(r) ~= "table" then continue end
			local ms, bar = nil, nil
			local function take(x: any)
				if type(x) ~= "table" then return end
				if x.t == "ms" then ms = x elseif x.t == "bar" then bar = x end
			end
			take(r)
			for _, kid in st:kids(rid) do take(st:get(kid)) end
			if ms then table.insert(items, { ms = ms, bar = bar, key = rid }) end
		end
		local ashed, perm = 0, 0
		for _, it in items do
			local s8 = if it.bar then it.bar.st8 else nil
			if s8 == "ashed" then ashed += 1 elseif s8 == "permanent" then perm += 1 end
		end
		local chips: { any } = { { text = ashed .. " / " .. #items .. " ashed", color = C.text, bg = Theme.mix(C.deep, C.ember, 0.3), bgT = 0 } }
		if perm > 0 then table.insert(chips, { text = perm .. " permanent", color = C.ink, bg = C.gold, bgT = 0 }) end
		local header = Sections.header(ph, { name = "Head", order = 0, text = "SPARK MILESTONES", hue = C.ember, chips = chips })
		-- the SHOW cycler: the "Show Multiple Milestones" clickable next to the list (one press)
		local showId = Kit.find(st, Common.parentId(id) or "tab", function(n: any): boolean
			return n.t == "btn" and n.k == "click" and string.find(Common.plain(n.h or ""), "Show Multiple", 1, true) ~= nil
		end, 1)
		if showId then
			local sn = st:get(showId)
			local cur = string.match(Common.plain(sn.h or ""), "Currently:%s*(%d+)") or "?"
			local b = Kit.headerControl(header, "Show", Common.run(Common.esc("Show: "), "label", C.soft)
				.. Common.num(cur, "number", C.text) .. Common.run("  ›", "label", C.soft), 110, { fill = C.panel2, stroke = C.stroke })
			Common.state(b, "can")
			Kit.onPress(b, function()
				fire(ctx, store, showId)
			end)
		else
			Common.drop(header, "Show")
		end
		local used: { [string]: boolean } = { Head = true, List = true }
		for i, it in items do
			local name = "S" .. i
			used[name] = true
			local s8 = if it.bar then (it.bar.st8 or "burning") else "none"
			local col = STATE_COL[s8] or ctx.hue
			local card = Common.get(ph, name, "Frame") :: Frame
			card.LayoutOrder = i
			card.Active = false
			card.Size = UDim2.new(1, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.BackgroundColor3 = if s8 == "ashed" then C.panel2 else Theme.mix(C.panel, col, 0.12)
			card.BackgroundTransparency = 0
			Common.corner(card, 14)
			Common.stroke(card, if s8 == "ashed" then 1 else 1.5, col, if s8 == "ashed" then 0.5 else 0.3)
			Common.pad(card, 14, 16, 14, if compact then 60 else 76)
			-- the milestone: title, effect, "Currently"
			local barW = if compact then 180 else 320
			local t = Common.label(card, "Text", "body", C.text, { order = 1 })
			t.Size = UDim2.new(1, -(barW + 16), 0, 0)
			local ms = it.ms
			local parts = { Common.title(Common.plain(Common.str(ms.ti) or ""), "card", C.text) }
			local ds = Common.html(ms.ds, "body", ctx.layer)
			if ds ~= "" then table.insert(parts, string.format('<font transparency="%.2f">%s</font>', if s8 == "ashed" then 0.18 else 0.08, ds)) end
			local tip = Common.plain(Common.str(ms.tip) or "")
			if tip ~= "" then
				local v = string.match(tip, "^Currently:%s*(.*)$")
				table.insert(parts, Common.caps("Currently", C.soft) .. "   " .. Common.num(trim(v or tip), "number", C.text))
			end
			Common.setText(t, table.concat(parts, "\n"))
			-- the number disc
			local disc = Common.get(card, "Disc", "TextLabel") :: TextLabel
			disc.Active = false
			disc.Size = UDim2.fromOffset(if compact then 40 else 52, if compact then 40 else 52)
			disc.Position = UDim2.fromOffset(if compact then -50 else -64, 0)
			Common.text(disc, "label", if s8 == "ashed" then C.soft else C.ink)
			disc.TextXAlignment = Enum.TextXAlignment.Center
			disc.TextYAlignment = Enum.TextYAlignment.Center
			disc.BackgroundColor3 = if s8 == "ashed" then C.panel3 else col
			disc.BackgroundTransparency = 0
			Common.corner(disc, 0.5)
			Common.setText(disc, "#" .. (string.match(Common.plain(Common.str(ms.ti) or ""), "#(%d+)") or tostring(i)))
			-- the burn state and bar
			local bar = it.bar
			if bar then
				local state = Common.get(card, "State", "TextLabel") :: TextLabel
				state.Active = false
				Common.text(state, "caps", col)
				state.AnchorPoint = Vector2.new(1, 0)
				state.Position = UDim2.new(1, 0, 0, 2)
				state.Size = UDim2.fromOffset(barW, 20)
				state.TextXAlignment = Enum.TextXAlignment.Left
				state.TextYAlignment = Enum.TextYAlignment.Center
				local word = if s8 == "permanent" then "Permanent" elseif s8 == "ashed" then "Ashed" else "Burning"
				local right = ""
				if s8 == "permanent" then
					right = Common.run(Common.esc("Skipped when burning"), "small", C.soft)
				else
					local bp = Common.pr(bar.bp)
					right = Common.num(Rich.pct(if s8 == "ashed" then 0 else (bp or 0)), "number", C.text)
				end
				Common.setText(state, Common.caps(word, if s8 == "ashed" then C.soft else Theme.lift(col, 0.2)))
				local r = Common.get(state, "Right", "TextLabel") :: TextLabel
				r.Active = false
				Common.text(r, "number", C.text)
				r.Size = UDim2.fromScale(1, 1)
				r.TextXAlignment = Enum.TextXAlignment.Right
				r.TextYAlignment = Enum.TextYAlignment.Center
				Common.setText(r, right)
				local p = if s8 == "permanent" then 1 elseif s8 == "ashed" then 0 else (Common.pr(bar.bp) or math.clamp(tonumber(bar.p) or 0, 0, 1))
				local b = Common.bar(card, "Burn", p, if s8 == "permanent" then C.gold else C.ember, 8)
				b.AnchorPoint = Vector2.new(1, 0)
				b.Position = UDim2.new(1, 0, 0, 30)
				b.Size = UDim2.fromOffset(barW, 8)
				if s8 == "burning" and p > 0.001 and p < 0.999 then
					local g = b:FindFirstChild("Fill") :: UIGradient?
					if g then
						local track = Color3.fromRGB(52, 46, 72)
						g.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, C.gold),
							ColorSequenceKeypoint.new(p * 0.6, C.ember),
							ColorSequenceKeypoint.new(p, C.danger),
							ColorSequenceKeypoint.new(math.min(1, p + 0.001), track),
							ColorSequenceKeypoint.new(1, track),
						})
					end
				end
			else
				Common.drop(card, "State")
				Common.drop(card, "Burn")
			end
			Common.state(card, if s8 == "ashed" then "notyet" else "owned")
		end
		for _, c in ph:GetChildren() do
			if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
		end
	end
	function claim.destroy(_: any)
		for _, c in ph:GetChildren() do c:Destroy() end
	end
	return claim
end

-- ------------------------------------------------------------------------------------------------------ pager
local function pager(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	function claim.update(_: any, st: any)
		store = st or store
		local keys: { string } = {}
		local page, pages = "1", "1"
		for _, cid in st:kids(id) do
			local n = st:get(cid)
			if type(n) ~= "table" then continue end
			if n.t == "btn" and n.k == "click" then
				table.insert(keys, cid)
			elseif n.t == "html" then
				local a, b = string.match(plainOf(n), "(%d+)%s*/%s*(%d+)")
				if a and b then page, pages = a, b end
			end
		end
		-- hidden when there is one page
		if pages == "1" or #keys == 0 then
			ph.Visible = false
			ph.Size = UDim2.new()
			ph.AutomaticSize = Enum.AutomaticSize.None
			for _, c in ph:GetChildren() do c:Destroy() end
			return
		end
		ph.Visible = true
		ph.Size = UDim2.new(1, 0, 0, 44)
		ph.AutomaticSize = Enum.AutomaticSize.None
		Common.list(ph, true, 8, { align = Enum.HorizontalAlignment.Center, valign = Enum.VerticalAlignment.Center })
		local half = #keys // 2
		for i, cid in keys do
			local n = st:get(cid)
			local t = trim(Common.plain(Common.str(n.ti) or n.h or ""))
			local b = Kit.button(ph, "K" .. i, Common.esc(t), { fill = if n.cls == "can" then Theme.mix(C.panel, ctx.hue, 0.4) else C.panel3,
				stroke = C.stroke, h = 44, w = 52, order = if i <= half then i else i + 1 })
			Common.state(b, if n.cls == "can" then "can" else "notyet")
			Kit.onPress(b, function()
				fire(ctx, store, cid)
			end)
		end
		local label = Common.label(ph, "Page", "label", C.text, { autoX = true, wrap = false, order = half + 1 })
		Common.setText(label, Common.esc("Page ") .. Common.num(page .. " / " .. pages, "number", C.text))
	end
	function claim.destroy(_: any)
		for _, c in ph:GetChildren() do c:Destroy() end
	end
	return claim
end

-- the Spark tab's display-text lines: the ashes line moves into the hero; the rest stay notes
local function sparkNote(ph: Frame, id: string, store: any, ctx: any): any
	local inner = M.noteClaim(ph, id, store, ctx)
	local claim = {}
	function claim.update(_: any, st: any)
		local n = st:get(id)
		local h = if type(n) == "table" and type(n.h) == "string" then n.h else ""
		if string.find(h, "<h2", 1, true) and string.find(h, "Prestige Ashes", 1, true) then
			ph.Visible = false
			ph.Size = UDim2.new()
			ph.AutomaticSize = Enum.AutomaticSize.None
			Common.drop(ph, "Text")
			return
		end
		inner.update(inner, st)
	end
	function claim.destroy(_: any)
		inner.destroy(inner)
	end
	return claim
end

-- the Spark tab's lone "Show Multiple Milestones" clickable: drawn in the SPARK MILESTONES title row instead
local function hidden(ph: Frame, id: string, store: any, ctx: any): any
	ph.Visible = false
	ph.Size = UDim2.new()
	ph.AutomaticSize = Enum.AutomaticSize.None
	return { update = function(_: any, _s: any) end, destroy = function(_: any) end }
end

-- ------------------------------------------------------------------------------------------------------ hero
local function hero(f: Frame, store: any, ctx: any)
	local a = Kit.accent(f, "Sp")
	-- PRESTIGE ASHES as a stat chip under the CTA and the stat chips
	local aid = Kit.find(store, "tab", function(n: any): boolean
		return n.cn == "display-text" and type(n.h) == "string" and string.find(n.h, "Prestige Ashes", 1, true) ~= nil
			and string.find(n.h, "<h2", 1, true) ~= nil
	end, 3)
	local ashes = if aid then Kit.h2(store:get(aid).h)[1] else nil
	if ashes and Layout.mode ~= "COMPACT" then
		local cta = f:FindFirstChild("Cta") :: GuiObject?
		local stats = f:FindFirstChild("Stats") :: GuiObject?
		local y = (if cta then cta.Size.Y.Offset + 10 else 0) + (if stats and stats.Visible then 42 else 0)
		local chip = Common.chip(a, "Ashes", Common.caps("Prestige ashes", C.soft) .. "   " .. Common.num(ashes, "number", Theme.lift(C.ember, 0.3)),
			{ rich = true, bg = C.panel2, bgT = 0, h = 34 })
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(1, 0, 0, y)
	else
		Common.drop(a, "Ashes")
	end
	-- the malware tabs: an ember rim over the sheet; an infected layer rings the emblem in danger
	local sheet = f.Parent
	if sheet == nil then return end
	local malwareTab = ctx.sub ~= nil and ctx.sub ~= "Main"
	local md = Kit.find(store, "tab", function(n: any): boolean
		return n.cn == "main-display"
	end, 3)
	local infected = md ~= nil and string.find(string.lower(Common.plain(store:get(md).res or "")), "infected", 1, true) ~= nil
	if not malwareTab and not infected then
		Common.drop(sheet, "Accent")
		return
	end
	local sa = Kit.accent(sheet, "SpRim")
	if malwareTab and Layout.mode ~= "COMPACT" then
		local rim = Common.get(sa, "Rim", "Frame") :: Frame
		rim.Active = false
		rim.BackgroundTransparency = 1
		rim.Size = UDim2.fromScale(1, 1)
		rim.ZIndex = 4
		Common.corner(rim, 22)
		Common.stroke(rim, 3, C.ember, 0.1)
		Common.glow(rim, C.ember, 0.35, 22)
	else
		Common.drop(sa, "Rim")
	end
	local emblem = sheet:FindFirstChild("Emblem") :: GuiObject?
	if infected and emblem then
		local ring = Common.get(sa, "Infected", "Frame") :: Frame
		ring.Active = false
		ring.BackgroundTransparency = 1
		ring.ZIndex = 7
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromOffset(emblem.Position.X.Offset + emblem.Size.X.Offset / 2, emblem.Position.Y.Offset + emblem.Size.Y.Offset / 2)
		ring.Size = UDim2.fromOffset(emblem.Size.X.Offset + 10, emblem.Size.Y.Offset + 10)
		Common.corner(ring, 0.5)
		Common.stroke(ring, 3, C.danger, 0)
		Common.glow(ring, C.danger, 0.5, 14)
	else
		Common.drop(sa, "Infected")
	end
end

return {
	layers = { "sp" },
	skin = P.skin,
	hero = hero,
	claims = ({
		{ match = { cn = "row", ci = 9, sub = SPARK }, make = furnace },
		{ match = { cn = "column", sub = SPARK }, make = sparkList },
		{ match = { cn = "row", ci = 15, sub = SPARK }, make = pager },
		{ match = { cn = "display-text", sub = SPARK, depth = 2 }, make = sparkNote },
		{ match = { cn = "clickable", sub = SPARK, depth = 2 }, make = hidden },
	} :: { any }),
}
