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
local Sleek = require(Core:WaitForChild("Sleek"))
local Skin = require(Core:WaitForChild("Skin"))
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
	local p = Common.surface(b, state, ctx.hue)
	Common.glow(b, if state == "can" then ctx.hue else nil, 0.2, 14)

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
	local idxColor = if state == "owned" then Sleek.C.good elseif state == "can" then ctx.hue else Sleek.C.micro
	local parts: { string } = {}
	table.insert(parts, Common.run(Common.esc(idx), "index", idxColor, if state == "owned" then 0.2 else 0))
	local title = Common.str(n.ti)
	if title then table.insert(parts, Common.title(Common.plain(title), "card", p.title)) end
	local ds = Common.html(n.ds, "body", ctx.layer)
	if ds ~= "" then
		table.insert(parts, string.format('<font transparency="%.2f">%s</font>', p.textT, ds))
	end
	local ef = Common.str(n.ef)
	if ef and state ~= "owned" then table.insert(parts, Common.caps("Currently", p.soft)) end
	Common.setText(label, table.concat(parts, "\n"))
	-- Sleek: the BUY card gets a lit top edge and its two top corner ticks. The card lays its children out in a list,
	-- so the marks hang off the first item (the label) with the card's padding as offsets; the bottom pair hangs off
	-- the BUY bar below. The other states stay quiet (instance budget).
	local padT, padX = if compact then 12 else 14, if compact then 12 else 16
	if state == "can" then
		local top = Common.get(label, "TopLine", "Frame") :: Frame
		top.Position = UDim2.fromOffset(-padX, -padT)
		top.Size = UDim2.new(1, 2 * padX, 0, 2)
		top.BackgroundColor3 = ctx.hue
		top.BackgroundTransparency = 0
		top.ZIndex = 5
		local tick = Theme.lift(ctx.hue, 0.55)
		for i, spec in { { 0, -padX }, { 1, padX } } do
			local ax, dx = spec[1], spec[2]
			local v = Common.get(label, "TickV" .. i, "Frame") :: Frame
			v.AnchorPoint = Vector2.new(ax, 0)
			v.Position = UDim2.new(ax, dx, 0, -padT)
			v.Size = UDim2.fromOffset(2, 9)
			v.BackgroundColor3 = tick
			v.BackgroundTransparency = 0
			v.ZIndex = 5
		end
	else
		for _, n in { "TopLine", "TickV1", "TickV2" } do Common.drop(label, n) end
	end

	-- the chip at the top right: BUY / OWNED / pr % / LOCKED
	local pr = Common.pr(n.pr)
	-- the tag: an outlined caps word (BUY in the hue, pr % in rose), or a bare ✓ OWNED / LOCKED
	local chipText, chipColor, chipLine = Rich.caps("Buy"), Theme.lift(ctx.hue, 0.55), ctx.hue :: Color3?
	if state == "owned" then
		chipText, chipColor, chipLine = "✓ " .. Rich.caps("Owned"), Sleek.C.good, nil
	elseif state == "notyet" then
		chipText, chipColor, chipLine = if pr then Rich.pct(pr) else Rich.caps("Not yet"), C.notYet, C.locked
	elseif state == "locked" then
		chipText, chipColor, chipLine = Rich.caps("Locked"), Sleek.C.lockText, nil
	end
	local chip = Common.chip(label, "Chip", chipText, { color = chipColor, bgT = 1, h = if compact then 22 else 24, stroke = chipLine,
		role = if state == "notyet" and pr then "badge" else "caps" })
	chip.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold)
	local cb = chip:FindFirstChild("Border") :: UIStroke?
	if cb then cb.Transparency = 0.3 end
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
			eff.BackgroundTransparency = 0.62
			eff.Size = UDim2.fromOffset(0, 30)
			Common.drop(eff, "Corner")
			Common.stroke(eff, 1, C.white, 0.92).LineJoinMode = Enum.LineJoinMode.Miter
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
		Common.drop(eff, "Border")
		Common.setText(eff, "✓  Active")
	else
		Common.drop(b, "Eff")
	end

	-- the pr bar (not yet) and the cost line
	if state == "notyet" and pr then
		local bar = Common.bar(b, "Bar", pr, C.notYet, 2)
		bar.LayoutOrder = 3
	else
		Common.drop(b, "Bar")
	end
	local co = Common.str(n.co)
	if co and state ~= "owned" and state ~= "locked" then
		local foot = Common.get(b, "Foot", "TextLabel") :: TextLabel
		foot.LayoutOrder = 4
		Common.text(foot, "caps", p.soft)
		foot.AutomaticSize = Enum.AutomaticSize.None
		foot.TextYAlignment = Enum.TextYAlignment.Center
		foot.TextWrapped = false
		foot.TextTruncate = Enum.TextTruncate.AtEnd
		if state == "can" then
			local ink = Sleek.C.ink
			foot.Size = UDim2.new(1, 0, 0, if compact then 36 else 42)
			foot.TextXAlignment = Enum.TextXAlignment.Right
			foot.BackgroundColor3 = C.white
			foot.BackgroundTransparency = 0
			local g = Common.get(foot, "Fill", "UIGradient") :: UIGradient
			g.Rotation = 90
			g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.lift(ctx.hue, 0.25)), ColorSequenceKeypoint.new(1, ctx.hue) })
			Common.drop(foot, "Pad")
			local verb = Common.get(foot, "Verb", "TextLabel") :: TextLabel
			Common.text(verb, "cta", ink)
			verb.TextSize = 16
			verb.Position = UDim2.fromOffset(12, 0)
			verb.Size = UDim2.new(1, -12, 1, 0)
			verb.TextXAlignment = Enum.TextXAlignment.Left
			verb.TextYAlignment = Enum.TextYAlignment.Center
			Common.setText(verb, "BUY")
			verb.ZIndex = foot.ZIndex + 1
			local cost = Common.get(foot, "Cost", "TextLabel") :: TextLabel
			Common.text(cost, "numberHeavy", ink)
			cost.RichText = true
			cost.Position = UDim2.new()
			cost.Size = UDim2.new(1, -12, 1, 0)
			cost.TextXAlignment = Enum.TextXAlignment.Right
			cost.TextYAlignment = Enum.TextYAlignment.Center
			cost.ZIndex = foot.ZIndex + 1
			Common.setText(cost, Common.num(co, "numberHeavy", ink, Signatures.unit(n.cur), true))
			Common.setText(foot, "")
			if Skin.apply(foot, "cta", { tint = Theme.lift(ctx.hue, 0.15), scale = if compact then 0.4 else 0.45 }) then
				Common.drop(foot, "Fill") -- the skin is the surface (instance budget)
			end
		else
			foot.Size = UDim2.new(1, 0, 0, 24)
			foot.TextXAlignment = Enum.TextXAlignment.Left
			foot.BackgroundTransparency = 1
			Common.drop(foot, "Fill")
			Common.drop(foot, "Pad")
			Common.drop(foot, "Verb")
			Common.drop(foot, "Cost")
			Skin.clear(foot)

			Common.setText(foot, Common.caps("Cost", p.soft) .. "   " .. Common.num(co, "numberHeavy", C.notYet, Signatures.unit(n.cur)))
		end
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
	spine.Size = UDim2.new(0, 1, 1, 12)
	spine.BackgroundColor3 = col
	spine.BackgroundTransparency = 0.6
	local badge = Common.get(rail, "Badge", "TextLabel") :: TextLabel
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 14)
	badge.Size = UDim2.fromOffset(30, 30)
	badge.BackgroundColor3 = col
	badge.BackgroundTransparency = 0.86
	Common.text(badge, "badge", C.text)
	badge.TextSize = math.max(badge.TextSize, 16)
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.TextYAlignment = Enum.TextYAlignment.Center
	badge.ZIndex = 2
	Common.drop(badge, "Corner")
	Common.stroke(badge, 1, col, 0.25).LineJoinMode = Enum.LineJoinMode.Miter
	Common.setText(badge, tierNo)
	if owned then
		local check = Common.get(rail, "Check", "Frame") :: Frame
		check.AnchorPoint = Vector2.new(0.5, 0)
		check.Position = UDim2.new(0.5, 0, 0, 54)
		check.Size = UDim2.fromOffset(7, 7)
		check.Rotation = 45
		check.BackgroundColor3 = C.bought
		check.BackgroundTransparency = 0
		check.ZIndex = 2
		Common.drop(check, "Corner")
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
	Common.surface(row, "owned", C.bought)
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
