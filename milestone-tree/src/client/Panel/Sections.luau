--!strict
--[[
	Sections: the client's section titles over the tab's components (DESIGN.md 5.6, plan 2.5).

	    Sections.decorate(rec, n, ctx)   a component frame whose cn is in the table gets a SectionTitle child at
	                                     LayoutOrder -1; it hides when the previous visible sibling has the same cn
	    Sections.refresh(ctx)            recount the chips of every decorated section (after each apply: the counts
	                                     come from cards whose patches never touch the component node itself)
	    Sections.header(parent, o)       the title row itself (hue bar, heavy italic title, chips, hairline), for
	                                     claims that draw their own section (the virtual milestone list)

	Titles and chips are derived from cn and counts only (plan 1.13). No hint text is invented.
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Layout = require(Core:WaitForChild("Layout"))
local Rich = require(Core:WaitForChild("Rich"))
local Sleek = require(Core:WaitForChild("Sleek"))
local Common = require(script.Parent:WaitForChild("Skins"):WaitForChild("Common"))

local Sections = {}

-- the milestone ladder's name per layer (DESIGN.md 5.6)
local LADDER: { [string]: string } = {
	m = "MILESTONE LADDER", mm = "META LADDER", em = "EXTRA LADDER", pm = "MILESTONE LADDER", cm = "CORRUPTED LADDER",
}
local TITLE: { [string]: string } = {
	buyables = "BUYABLES", upgrades = "UPGRADES", milestones = "MILESTONES", challenges = "CHALLENGES",
	achievements = "TROPHY SHELF", clickables = "CONTROLS", grid = "DISKS",
}
Sections.TITLE = TITLE

function Sections.titleOf(cn: string, layer: string): string?
	if cn == "milestones" then return LADDER[layer] or TITLE.milestones end
	return TITLE[cn]
end

-- ------------------------------------------------------------------------------------------------------ counting
type Counts = { total: number, ready: number, owned: number }
local function count(store: any, id: string, depthLeft: number, want: (n: any) -> string?, out: Counts)
	if depthLeft < 0 then return end
	local n = store:get(id)
	if type(n) ~= "table" then return end
	local k = want(n)
	if k then
		out.total += 1
		if k == "ready" then out.ready += 1 elseif k == "owned" then out.owned += 1 end
		return
	end
	if type(n.c) == "table" then
		for _, cid in n.c do
			if type(cid) == "string" then count(store, cid, depthLeft - 1, want, out) end
		end
	end
end
local WANT: { [string]: (n: any) -> string? } = {
	upgrades = function(n: any): string?
		if n.t ~= "btn" or n.k ~= "upg" then return nil end
		return if n.cls == "bought" then "owned" elseif n.cls == "can" then "ready" else "other"
	end,
	buyables = function(n: any): string?
		if n.t ~= "btn" or n.k ~= "buy" then return nil end
		return if n.cls == "can" then "ready" else "other"
	end,
	milestones = function(n: any): string?
		if n.t ~= "ms" then return nil end
		return if n.done then "owned" else "other"
	end,
	challenges = function(n: any): string?
		if n.t ~= "chal" then return nil end
		return if n.st8 == "done" or n.cls == "done" then "owned" else "other"
	end,
	achievements = function(n: any): string?
		if n.t ~= "ach" then return nil end
		return if n.done then "owned" else "other"
	end,
	grid = function(n: any): string?
		if n.t ~= "btn" or n.k ~= "grid" then return nil end
		return if n.gs == "empty" then "other" else "ready"
	end,
}
local function counts(store: any, id: string, cn: string): Counts?
	local want = WANT[cn]
	if want == nil then return nil end
	local out: Counts = { total = 0, ready = 0, owned = 0 }
	count(store, id, 5, want, out)
	return out
end

-- ------------------------------------------------------------------------------------------------------ the row
export type Chip = { text: string, color: Color3?, bg: Color3?, bgT: number?, seg: { number }? }
export type HeaderOpts = { name: string?, text: string, hue: Color3, chips: { Chip }?, order: number? }
-- the section title row (Sleek): a hue marker, the tracked caps title, a segment meter and caps counts, a hairline
function Sections.header(parent: Instance, o: HeaderOpts): Frame
	local compact = Layout.mode == "COMPACT"
	local f = Common.get(parent, o.name or "SectionTitle", "Frame") :: Frame
	f.LayoutOrder = o.order or -1
	f.Size = UDim2.new(1, 0, 0, if compact then 28 else 32)
	f.ClipsDescendants = true
	f.Active = false
	Common.list(f, true, 12, { valign = Enum.VerticalAlignment.Center })
	local bar = Common.get(f, "HueBar", "Frame") :: Frame
	bar.LayoutOrder = 1
	bar.Size = UDim2.fromOffset(6, 6)
	bar.Rotation = 45
	bar.BackgroundColor3 = o.hue
	bar.BackgroundTransparency = 0
	Common.drop(bar, "Corner")
	local t = Common.get(f, "Title", "TextLabel") :: TextLabel
	t.LayoutOrder = 2
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromOffset(0, if compact then 24 else 28)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	local size = if compact then 14 else 15
	local sig = o.text .. "|" .. tostring(size) .. "|sleek"
	if t:GetAttribute("Sig") ~= sig then
		t:SetAttribute("Sig", sig)
		Recipes.title(t, { text = Rich.caps(o.text), role = "label", size = size, stroke = 0, shadow = 0 })
	end
	local chips = o.chips or {}
	for i = 1, 2 do
		local c = chips[i]
		if c then
			local l = Common.chip(f, "Chip" .. i, c.text, { color = c.color, bgT = 1, h = if compact then 22 else 24, role = "caps" })
			l.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold)
			l.LayoutOrder = 3 + i * 2
			if c.seg then
				local many = c.seg[1] > 8
				local sg = Sleek.seg(f, "Seg" .. i, c.seg[1], c.seg[2], { w = if many then 3 else 10, h = if many then 12 else 3, gap = if many then 2 else 3 })
				sg.LayoutOrder = 2 + i * 2
			else
				Common.drop(f, "Seg" .. i)
			end
		else
			Common.drop(f, "Chip" .. i)
			Common.drop(f, "Seg" .. i)
		end
	end
	local rule = Common.get(f, "Rule", "Frame") :: Frame
	rule.LayoutOrder = 10
	rule.Size = UDim2.fromOffset(1400, 1)
	rule.BackgroundColor3 = Color3.new(1, 1, 1)
	rule.BackgroundTransparency = 0
	local g = Common.get(rule, "Fade", "UIGradient") :: UIGradient
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.74),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0.95),
	})
	return f
end

-- the chips of a component (DESIGN.md 5.6 table): caps counts, OWNED with a segment meter when it fits
local function chipsOf(cn: string, c: Counts?, hue: Color3): { Chip }
	if c == nil or c.total == 0 then return {} end
	local C = Theme.C
	local seg = if c.total <= 24 then { c.total, c.owned } else nil
	if cn == "upgrades" then
		local out: { Chip } = {}
		if c.ready > 0 then
			table.insert(out, { text = Rich.caps(c.ready .. " ready"), color = Theme.lift(hue, 0.55) })
		end
		table.insert(out, { text = Rich.caps(c.owned .. " / " .. c.total .. " owned"), color = C.soft, seg = seg })
		return out
	elseif cn == "milestones" or cn == "challenges" or cn == "achievements" then
		return { { text = Rich.caps(c.owned .. " / " .. c.total .. (if cn == "achievements" then "" else " done")), color = C.soft,
			seg = seg } }
	elseif cn == "grid" then
		return { { text = Rich.caps(c.ready .. " corrupted"), color = Theme.lift(hue, 0.4) } }
	end
	return { { text = tostring(c.total), color = C.soft } }
end

-- ------------------------------------------------------------------------------------------------------ decorate
local decorated: { [GuiObject]: { id: string, cn: string } } = setmetatable({}, { __mode = "k" }) :: any

-- the previous visible sibling of id (by the store's child order) has the same cn
local function sameAsPrevious(store: any, id: string, cn: string): boolean
	local pid = Common.parentId(id)
	if pid == nil then return false end
	local kids = store:kids(pid)
	local idx = table.find(kids, id)
	if idx == nil then return false end
	for i = idx - 1, 1, -1 do
		local prev = store:get(kids[i])
		if type(prev) == "table" then
			if prev.cn == "blank" or prev.t == "blank" then continue end
			return prev.cn == cn
		end
	end
	return false
end

function Sections.decorate(rec: any, n: any, ctx: any)
	local cn = n.cn
	local title = if type(cn) == "string" then Sections.titleOf(cn, ctx.layer) else nil
	local root = rec.root :: GuiObject
	if title == nil or sameAsPrevious(ctx.store, rec.id, cn) then
		Common.drop(root, "SectionTitle")
		decorated[root] = nil
		return
	end
	decorated[root] = { id = rec.id, cn = cn }
	Sections.header(root, { text = title, hue = ctx.hue, chips = chipsOf(cn, counts(ctx.store, rec.id, cn), ctx.hue) })
end

function Sections.refresh(ctx: any)
	for root, d in decorated do
		if root.Parent == nil then
			decorated[root] = nil
			continue
		end
		local title = Sections.titleOf(d.cn, ctx.layer)
		if title then
			Sections.header(root, { text = title, hue = ctx.hue, chips = chipsOf(d.cn, counts(ctx.store, d.id, d.cn), ctx.hue) })
		end
	end
end

return Sections
