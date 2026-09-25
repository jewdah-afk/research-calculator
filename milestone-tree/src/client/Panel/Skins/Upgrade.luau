--!strict
--[[
	Upgrade: the upgrade card (Figma 5:47, DESIGN.md 5.7) and the default tier board (5.7 "Tier board").

	    can     hue surface, glow, BUY chip, "Currently" value in a well, COST in white
	    owned   quiet green surface, OWNED chip, the effect value (or "Active") in the owned green; no glow
	    notyet  mauve surface, the pr % chip and a 5 du bar, COST in the not-yet rose
	    locked  dim mauve, LOCKED chip (never sent for upgrades today; kept for signatures)
	A fully owned tier (every card of a game row bought) uses the compact owned cards (Skins/CompactOwned) and its
	rail turns green. The tier rail (WIDE / MEDIUM) is a badge with the row number on a glowing spine.
	COMPACT folds every owned upgrade into one summary row ("N OWNED · Show") at the top of the section.

	One TextLabel carries the index, title, description and the "Currently" caps (RichText runs, DESIGN.md 9.2), so a
	card stays near 12 instances. Card titles are Title Case as the game sends them; italic only up to 4 words.
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Rich = require(Core:WaitForChild("Rich"))
local Common = require(script.Parent:WaitForChild("Common"))
local CompactOwned = require(script.Parent:WaitForChild("CompactOwned"))
local Signatures = require(script.Parent.Parent.Parent:WaitForChild("Signatures"):WaitForChild("Signatures"))

local Upgrade = {}

local C = Theme.C

-- the COMPACT owned fold, per layer / component, for the session (DESIGN.md 5.7)
local showOwned: { [string]: boolean } = {}

function Upgrade.stateOf(n: any): string
	if n.cls == "bought" then return "owned" end
	if n.cls == "can" then return "can" end
	if n.cls == "plocked" then return "locked" end
	return "notyet"
end

-- every upgrade of the card's game row is bought (a row id's children in the store)
local function tierOwned(store: any, rowId: string?, cache: { [string]: any }): boolean
	if rowId == nil then return false end
	local key = "own:" .. rowId
	local hit = cache[key]
	if hit ~= nil then return hit end
	local kids = store:kids(rowId)
	local any, all = false, true
	for _, cid in kids do
		local k = store:get(cid)
		if type(k) == "table" and k.t == "btn" and k.k == "upg" then
			any = true
			if k.cls ~= "bought" then all = false end
		end
	end
	local r = any and all
	cache[key] = r
	return r
end
Upgrade.tierOwned = tierOwned

local function inUpgradesRow(ctx: any, id: string): string?
	local pid = Common.parentId(id)
	if pid == nil then return nil end
	local gid = Common.parentId(pid)
	local g = if gid then ctx.store:get(gid) else nil
	if type(g) == "table" and g.cn == "upgrades" then return pid end
	return nil
end
-- the upgrades component id above a card (row -> component), nil when the card is not in one
local function componentOf(ctx: any, id: string): string?
	local pid = Common.parentId(id)
	if pid == nil then return nil end
	local p = ctx.store:get(pid)
	if type(p) == "table" and p.cn == "upgrades" then return pid end
	local gid = Common.parentId(pid)
	local g = if gid then ctx.store:get(gid) else nil
	if type(g) == "table" and g.cn == "upgrades" then return gid end
	return nil
end

function Upgrade.skin(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local state = Upgrade.stateOf(n)
	local compact = ctx.mode == "COMPACT"
	local rowId = inUpgradesRow(ctx, rec.id)
	-- COMPACT: owned upgrades fold into the section's summary row unless it is open
	if compact and state == "owned" then
		local comp = componentOf(ctx, rec.id)
		if comp and not showOwned[ctx.layer .. ":" .. comp] then
			b.Visible = false
			Common.state(b, state)
			return true
		end
	end
	if state == "owned" and (compact or (rowId ~= nil and tierOwned(ctx.store, rowId, ctx.cache))) then
		return CompactOwned.skin(rec, n, ctx)
	end
	b.Visible = true
	b.AutoButtonColor = false
	Common.drop(b, "Num")
	Common.drop(b, "Gradient")
	Common.drop(b, "Glow")
	local p = Common.surface(b, state, ctx.hue, 14)
	Common.glow(b, if state == "can" then ctx.hue else nil, 0.55, 16)
	b.Size = UDim2.fromOffset(ctx.cardW, 0)
	b.AutomaticSize = Enum.AutomaticSize.Y
	Common.drop(b, "Limit") -- a tier row stretches its cards to the tallest one
	Common.pad(b, if compact then 12 else 14, if compact then 12 else 16, if compact then 12 else 14, if compact then 12 else 16)
	Common.list(b, false, if compact then 6 else 8, { name = "CardList" })

	-- the text block: index, title, description, "Currently"
	Common.text(label, "body", p.text, 0)
	label.LayoutOrder = 1
	label.ZIndex = 3
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Visible = true
	local idx = Common.str(n.n) or Common.str(n.id) or ""
	local idxColor = if state == "owned" then C.soft else Theme.lift(ctx.hue, 0.5)
	local parts: { string } = {}
	table.insert(parts, Common.run(Common.esc(idx), "index", idxColor, 0.2))
	local title = Common.str(n.ti)
	if title then table.insert(parts, Common.title(Common.plain(title), "card", p.title)) end
	local ds = Common.html(n.ds, "body", ctx.layer)
	if ds ~= "" then
		table.insert(parts, string.format('<font transparency="%.2f">%s</font>', p.textT, ds))
	end
	local ef = Common.str(n.ef)
	if ef and state ~= "owned" then table.insert(parts, Common.caps("Currently", p.soft)) end
	Common.setText(label, table.concat(parts, "\n"))

	-- the chip at the top right: BUY / OWNED / pr % / LOCKED
	local pr = Common.pr(n.pr)
	local chipText, chipColor, chipBg, chipBgT = "BUY", C.text, C.black, 0.45
	if state == "owned" then
		chipText, chipColor, chipBg, chipBgT = "OWNED", C.ownedValue, Theme.mix(C.deep, C.bought, 0.25), 0
	elseif state == "notyet" then
		chipText, chipColor, chipBg, chipBgT = if pr then Rich.pct(pr) else "NOT YET", C.notYet, C.black, 0.5
	elseif state == "locked" then
		chipText, chipColor, chipBg, chipBgT = "LOCKED", C.lockedTitle, C.black, 0.5
	end
	local chip = Common.chip(label, "Chip", chipText, { color = chipColor, bg = chipBg, bgT = chipBgT, h = if compact then 26 else 28 })
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Position = UDim2.new(1, 0, 0, 0)
	chip.ZIndex = 4

	-- "Currently": the value in a well (can / not yet), or the owned effect line
	if ef then
		local eff = Common.get(b, "Eff", "TextLabel") :: TextLabel
		eff.LayoutOrder = 2
		eff.ZIndex = 3
		eff.TextWrapped = false
		eff.TextXAlignment = Enum.TextXAlignment.Center
		eff.TextYAlignment = Enum.TextYAlignment.Center
		eff.AutomaticSize = Enum.AutomaticSize.X
		eff.Active = false
		if state == "owned" then
			Common.text(eff, "numberHeavy", C.ownedValue)
			eff.BackgroundTransparency = 1
			eff.Size = UDim2.fromOffset(0, 24)
			Common.drop(eff, "Corner")
			Common.setText(eff, Common.num(ef, "numberHeavy", C.ownedValue))
		else
			Common.text(eff, "number", C.text)
			eff.BackgroundColor3 = C.black
			eff.BackgroundTransparency = 0.45
			eff.Size = UDim2.fromOffset(0, 28)
			Common.corner(eff, 8)
			Common.setText(eff, "  " .. Common.num(ef, "number", C.text) .. "  ")
		end
	elseif state == "owned" then
		local eff = Common.get(b, "Eff", "TextLabel") :: TextLabel
		eff.LayoutOrder = 2
		Common.text(eff, "label", C.ownedValue)
		eff.BackgroundTransparency = 1
		eff.AutomaticSize = Enum.AutomaticSize.X
		eff.Size = UDim2.fromOffset(0, 22)
		eff.TextXAlignment = Enum.TextXAlignment.Left
		Common.drop(eff, "Corner")
		Common.setText(eff, "Active")
	else
		Common.drop(b, "Eff")
	end

	-- the pr bar (not yet) and the cost line
	if state == "notyet" and pr then
		local bar = Common.bar(b, "Bar", pr, Theme.lift(ctx.hue, 0.15), 5)
		bar.LayoutOrder = 3
	else
		Common.drop(b, "Bar")
	end
	local co = Common.str(n.co)
	if co and state ~= "owned" and state ~= "locked" then
		local foot = Common.get(b, "Foot", "TextLabel") :: TextLabel
		foot.LayoutOrder = 4
		Common.text(foot, "caps", p.soft)
		foot.Size = UDim2.new(1, 0, 0, 24)
		foot.AutomaticSize = Enum.AutomaticSize.None
		foot.TextXAlignment = Enum.TextXAlignment.Left
		foot.TextYAlignment = Enum.TextYAlignment.Center
		foot.TextWrapped = false
		foot.TextTruncate = Enum.TextTruncate.AtEnd
		local valueColor = if state == "can" then C.text else C.notYet
		Common.setText(foot, Common.caps("Cost", p.soft) .. "   " .. Common.num(co, "numberHeavy", valueColor, Signatures.unit(n.cur)))
	else
		Common.drop(b, "Foot")
	end
	Common.state(b, state)
	Common.transition(ctx, n.a, state, b)
	return true
end

-- ------------------------------------------------------------------------------------------------------ tier board
-- a game row inside the upgrades component: the rail at the left (WIDE / MEDIUM), green when the tier is owned
function Upgrade.tier(rec: any, n: any, ctx: any)
	local root = rec.root :: Frame
	if ctx.mode == "COMPACT" then
		Common.drop(root, "Rail")
		return
	end
	local owned = tierOwned(ctx.store, rec.id, ctx.cache)
	local tierNo = string.match(rec.id, "%.(%d+)$") or "?"
	local col = if owned then C.bought else ctx.hue
	local rail = Common.get(root, "Rail", "Frame") :: Frame
	rail.LayoutOrder = 0
	rail.Size = UDim2.fromOffset(44, 0)
	rail.Active = false
	local spine = Common.get(rail, "Spine", "Frame") :: Frame
	spine.AnchorPoint = Vector2.new(0.5, 0)
	spine.Position = UDim2.fromScale(0.5, 0)
	spine.Size = UDim2.new(0, 2, 1, 12)
	spine.BackgroundColor3 = col
	spine.BackgroundTransparency = 0.45
	local badge = Common.get(rail, "Badge", "TextLabel") :: TextLabel
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 14)
	badge.Size = UDim2.fromOffset(34, 34)
	badge.BackgroundColor3 = Theme.mix(C.deep, col, 0.35)
	badge.BackgroundTransparency = 0
	Common.text(badge, "badge", C.text)
	badge.TextSize = math.max(badge.TextSize, 16)
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.TextYAlignment = Enum.TextYAlignment.Center
	badge.ZIndex = 2
	Common.corner(badge, 0.5)
	Common.stroke(badge, 2, col, 0)
	Common.setText(badge, tierNo)
	if owned then
		local check = Common.get(rail, "Check", "Frame") :: Frame
		check.AnchorPoint = Vector2.new(0.5, 0)
		check.Position = UDim2.new(0.5, 0, 0, 54)
		check.Size = UDim2.fromOffset(12, 12)
		check.BackgroundColor3 = C.bought
		check.BackgroundTransparency = 0
		check.ZIndex = 2
		Common.corner(check, 0.5)
	else
		Common.drop(rail, "Check")
	end
end

-- ------------------------------------------------------------------------------------------------------ COMPACT fold
-- the summary row at the top of an upgrades section on phones: "N OWNED" + Show / Hide (one press)
function Upgrade.summary(rec: any, n: any, ctx: any)
	local root = rec.root :: Frame
	if ctx.mode ~= "COMPACT" or n.cn ~= "upgrades" then
		Common.drop(root, "OwnedRow")
		return
	end
	local owned = 0
	local function walk(id: string, d: number)
		if d > 3 then return end
		local x = ctx.store:get(id)
		if type(x) ~= "table" then return end
		if x.t == "btn" and x.k == "upg" and x.cls == "bought" then owned += 1 end
		if type(x.c) == "table" then
			for _, cid in x.c do
				if type(cid) == "string" then walk(cid, d + 1) end
			end
		end
	end
	walk(rec.id, 0)
	if owned == 0 then
		Common.drop(root, "OwnedRow")
		return
	end
	local key = ctx.layer .. ":" .. rec.id
	local open = showOwned[key] == true
	local row = Common.get(root, "OwnedRow", "TextButton") :: TextButton
	row.LayoutOrder = 0
	row.AutoButtonColor = false
	row.Text = ""
	row.Size = UDim2.new(1, 0, 0, 48)
	Common.fill(row, Theme.mix(C.panel, C.bought, 0.16), Theme.mix(C.deep, C.bought, 0.1))
	Common.corner(row, 12)
	Common.stroke(row, 1.5, C.bought, 0.5)
	Common.pad(row, 0, 14, 0, 14)
	local t = Common.label(row, "Text", "cardSmall", C.ownedTitle, { wrap = false })
	t.Size = UDim2.fromScale(1, 1)
	t.AutomaticSize = Enum.AutomaticSize.None
	t.TextYAlignment = Enum.TextYAlignment.Center
	Common.setText(t, Common.title(owned .. " owned", "cardSmall", C.ownedTitle))
	local s = Common.label(row, "Show", "label", C.ownedValue, { wrap = false, align = Enum.TextXAlignment.Right })
	s.Size = UDim2.fromScale(1, 1)
	s.AutomaticSize = Enum.AutomaticSize.None
	s.TextYAlignment = Enum.TextYAlignment.Center
	Common.setText(s, if open then "Hide" else "Show")
	row:SetAttribute("Key", key)
	if row:GetAttribute("Wired") ~= true then
		row:SetAttribute("Wired", true)
		local render = ctx.render
		row.Activated:Connect(function()
			local k = row:GetAttribute("Key")
			if type(k) ~= "string" then return end
			showOwned[k] = not showOwned[k]
			if render then render:refresh() end
		end)
	end
end

return Upgrade
