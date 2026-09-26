--!strict
--[[
	Generic: the quiet panel look for every node no card skin handles (DESIGN.md 5.6, plan 2.5).

	    containers (col / row / tabs)   panel rhythm: section gap between components, card gap inside them, rows wrap
	                                    left-aligned; an upgrades row becomes a tier-board row (Skins/Upgrade.tier)
	    display-text / raw html         NOTES rows: a quiet panel2 strip with the game's line verbatim (colours remapped)
	    other html                      body text in soft, remapped colours; empty text is hidden
	    blank / hr / h-line / v-line    dropped (the section rhythm replaces them)
	    small buttons                   respec / master / sell / toggle / chalbtn / malware / nested tabs / reset:
	                                    40 du pills, hue when actionable, mauve when not
	    about                           the Options HOTKEYS card (the unlocked hotkeys; no credits in game)
	    bar (rbx-burn)                  a themed bar with the game's text; st8 picks ember / grey / gold
	The game's own per-thing CSS (st) is ignored in the panel: the template sets the look.
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Common = require(script.Parent:WaitForChild("Common"))
local Sections = require(script.Parent.Parent:WaitForChild("Sections"))

local Generic = {}

local C = Theme.C

local HIDDEN_CN: { [string]: boolean } = { blank = true, ["h-line"] = true, ["v-line"] = true }
local NOTE_CN: { [string]: boolean } = { ["display-text"] = true, ["raw-html"] = true }

local function parentRec(ctx: any, id: string): any?
	local pid = Common.parentId(id)
	if pid == nil then return nil end
	return ctx.render.recs[pid]
end

-- ------------------------------------------------------------------------------------------------------ containers
local function container(rec: any, n: any, ctx: any)
	local root = rec.root :: Frame
	local compact = ctx.mode == "COMPACT"
	root.BackgroundTransparency = 1
	Common.drop(root, "Gradient")
	Common.drop(root, "Border")
	Common.drop(root, "Corner")
	Common.drop(root, "Pad")
	local depth = Common.depth(rec.id)
	local parent = parentRec(ctx, rec.id)
	local inUpgrades = parent ~= nil and parent.node and parent.node.cn == "upgrades"
	if n.t == "col" then
		-- the tab root and its direct content column hold components: the section gap; inside a component: the card gap
		local gap = if depth <= 1 then (if compact then 16 else 28) else (if compact then 10 else 12)
		Common.list(root, false, gap, { align = Enum.HorizontalAlignment.Left })
		if rec.autoW then
			root.Size = UDim2.new()
			root.AutomaticSize = Enum.AutomaticSize.XY
		else
			root.Size = UDim2.new(1, 0, 0, 0)
			root.AutomaticSize = Enum.AutomaticSize.Y
		end
	else
		-- row / nested tabs: horizontal, wrapping, left-aligned
		local gap = if compact then 10 else 12
		local l = Common.list(root, true, gap, { align = Enum.HorizontalAlignment.Left, valign = Enum.VerticalAlignment.Top,
			wraps = not rec.autoW })
		-- a row of challenges: centred, and its cards stretched to one height (their buttons then line up)
		local chalRow = false
		for _, cid in ctx.store:kids(rec.id) do
			local c = ctx.store:get(cid)
			if type(c) == "table" and c.t == "chal" then
				chalRow = true
				break
			end
		end
		if chalRow then l.HorizontalAlignment = Enum.HorizontalAlignment.Center end
		pcall(function()
			l.ItemLineAlignment = if inUpgrades or chalRow then Enum.ItemLineAlignment.Stretch else Enum.ItemLineAlignment.Start
		end)
		if rec.autoW then
			root.Size = UDim2.new()
			root.AutomaticSize = Enum.AutomaticSize.XY
		else
			root.Size = UDim2.new(1, 0, 0, 0)
			root.AutomaticSize = Enum.AutomaticSize.Y
		end
	end
	-- the text children inherit (html inside rows / columns)
	rec.text, rec.textT, rec.base = C.soft, 0, Theme.size("body")
	if n.cn and Sections.titleOf(n.cn, ctx.layer) then
		Sections.decorate(rec, n, ctx)
	else
		Common.drop(root, "SectionTitle")
	end
	local Upgrade = require(script.Parent:WaitForChild("Upgrade")) :: any
	if inUpgrades and n.t == "row" then
		Upgrade.tier(rec, n, ctx)
	else
		Common.drop(root, "Rail")
	end
	Upgrade.summary(rec, n, ctx)
	root.Visible = true
end

-- ------------------------------------------------------------------------------------------------------ html
local function textLabel(rec: any): TextLabel
	local root = rec.root :: Frame
	local l = root:FindFirstChild("Text")
	if l and l:IsA("TextLabel") then return l end
	if l then l:Destroy() end
	return Common.label(root, "Text", "body", C.soft)
end

local function html(rec: any, n: any, ctx: any): boolean
	if rec.kind == "svg" then return false end -- the exploration map keeps the old drawing (cached by its html)
	local root = rec.root :: Frame
	local cn = n.cn
	local parent = parentRec(ctx, rec.id)
	local pk = if parent then parent.kind else nil
	-- a challenge draws its own title / text from the structured fields
	if pk == "chal" or cn == "blank" then
		root.Visible = false
		return true
	end
	-- the hero's components when they are not claimed (deeper than the hero looks): a resource-display without text
	if cn == "resource-display" and Common.plain(n.h) == "" then
		root.Visible = false
		return true
	end
	local text = Common.html(n.h, "body", ctx.layer)
	local plain = Common.plain(n.h)
	if not string.find(plain, "%S") then
		root.Visible = false
		return true
	end
	root.Visible = true
	local l = textLabel(rec)
	local note = NOTE_CN[cn] == true or (cn == nil and Common.depth(rec.id) <= 2)
	if note then
		-- NOTES row: panel2 strip, a hue tick at the left, the game's line verbatim
		root.BackgroundColor3 = C.panel2
		root.BackgroundTransparency = 0
		Common.corner(root, 10)
		Common.pad(root, 10, 14, 10, 16)
		local tick = Common.get(root, "Tick", "Frame") :: Frame
		tick.BackgroundColor3 = ctx.hue
		tick.BackgroundTransparency = 0.2
		tick.Size = UDim2.new(0, 3, 1, -6)
		tick.Position = UDim2.fromOffset(-10, 3)
		Common.corner(tick, 2, "TickCorner")
		Common.text(l, "body", C.text)
		l.TextTransparency = 0.08
	else
		root.BackgroundTransparency = 1
		Common.drop(root, "Corner")
		Common.drop(root, "Pad")
		Common.drop(root, "Tick")
		Common.text(l, "body", C.soft)
	end
	l.TextXAlignment = Enum.TextXAlignment.Left
	if rec.autoW then
		root.Size = UDim2.new()
		root.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.new()
		l.AutomaticSize = Enum.AutomaticSize.XY
		local lim = Common.get(l, "Limit", "UISizeConstraint") :: UISizeConstraint
		lim.MaxSize = Vector2.new(if ctx.mode == "COMPACT" then 420 else 640, math.huge)
	else
		root.Size = UDim2.new(1, 0, 0, 0)
		root.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		Common.drop(l, "Limit")
	end
	l.TextWrapped = true
	Common.setText(l, text)
	return true
end

-- ------------------------------------------------------------------------------------------------------ buttons
local SMALL: { [string]: boolean } = {
	respec = true, master = true, sell = true, toggle = true, chalbtn = true, malware = true, tab = true, reset = true,
	click = true, menu = true,
}
function Generic.button(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local k = n.k
	local compact = ctx.mode == "COMPACT"
	local can = n.cls == "can" or n.cls == "cur" or n.cls == "perk" or n.cls == "pseudo"
	local danger = k == "respec" or k == "sell"
	local state = if n.cls == "bought" or n.cls == "pseudo" or n.cls == "done" then "owned" elseif can then "can" else "notyet"
	local fill: Color3
	local ink: Color3
	if state == "owned" then
		fill, ink = Theme.mix(C.panel, C.bought, 0.22), C.ownedTitle
	elseif not can then
		fill, ink = Theme.mix(C.panel, C.locked, 0.22), C.lockedTitle
	elseif danger then
		fill, ink = Theme.mix(C.panel, C.danger, 0.45), C.text
	elseif k == "tab" and n.cls ~= "cur" then
		fill, ink = C.panel2, C.soft
	else
		fill = ctx.hue
		ink = if Theme.darkOnFill(ctx.layer) then C.ink else C.text
	end
	b.AutoButtonColor = false
	b.BackgroundColor3 = fill
	b.BackgroundTransparency = 0
	Common.drop(b, "Gradient")
	Common.drop(b, "Glow")
	Common.drop(b, "Num")
	Common.drop(b, "Limit")
	Common.corner(b, 10)
	Common.stroke(b, 1.5, if can and not danger then Theme.lift(fill, 0.35) else C.stroke, if can then 0.1 else 0.3)
	Common.pad(b, 6, 14, 6, 14)
	local h = if compact then 38 else 40
	b.Size = UDim2.fromOffset(0, h)
	b.AutomaticSize = Enum.AutomaticSize.XY
	local role = "label"
	Common.text(l, role, ink)
	l.TextWrapped = false
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Size = UDim2.new(0, 0, 1, 0)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Visible = true
	-- a single line: the game's first line (plain); the cost line of a malware button becomes a number run
	local text: string
	if k == "malware" then
		local co = Common.str(n.co)
		text = Common.esc(if n.cls == "pseudo" then "INFECTED" else "INFECT")
		if co and n.cls ~= "pseudo" then text ..= "  " .. Common.num(co, "number", ink) end
	else
		local first = Common.plain(n.h)
		first = string.gsub(first, "\n.*$", "")
		first = string.gsub(first, "^%s+", "")
		first = string.gsub(first, "%s+$", "")
		if #first > 40 then
			-- a long clickable text: keep it readable on two lines inside a fixed width
			l.TextWrapped = true
			l.TextXAlignment = Enum.TextXAlignment.Left
			b.AutomaticSize = Enum.AutomaticSize.Y
			b.Size = UDim2.fromOffset(if compact then 260 else 300, h)
			l.Size = UDim2.new(1, 0, 0, 0)
			l.AutomaticSize = Enum.AutomaticSize.Y
			Common.text(l, "small", ink)
			text = Common.esc(first)
		else
			text = Common.esc(if k == "tab" then string.upper(first) else first)
		end
	end
	Common.setText(l, text)
	Common.state(b, state)
	b.Visible = true
	return true
end

-- ------------------------------------------------------------------------------------------------------ about
local function about(rec: any, n: any, ctx: any): boolean
	local root = rec.root :: Frame
	root.BackgroundColor3 = C.panel2
	root.BackgroundTransparency = 0
	root.Size = UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	Common.corner(root, 14)
	Common.stroke(root, 1, C.stroke, 0.2)
	Common.pad(root, 16, 20, 16, 20)
	Common.list(root, false, 8)
	-- the credits are not shown in game (the README keeps them); the card lists the unlocked hotkeys
	Sections.header(root, { text = "HOTKEYS", hue = ctx.hue, order = 0, name = "Head" })
	Common.drop(root, "Body")
	-- the unlocked hotkeys: keycap run + description, one per line
	local keys: { string } = {}
	if type(n.keys) == "table" then
		for _, kk in n.keys do
			if type(kk) == "table" and type(kk.k) == "string" then
				table.insert(keys, Common.run(Common.esc(kk.k), "label", C.gold) .. "   " .. Common.run(Common.esc(tostring(kk.d or "")), "body", C.soft))
			end
		end
	end
	local kl = Common.label(root, "Keys", "body", C.text, { order = 2 })
	kl.Visible = #keys > 0
	Common.setText(kl, table.concat(keys, "\n"))
	root.Visible = #keys > 0
	return true
end

-- ------------------------------------------------------------------------------------------------------ bar
local function bar(rec: any, n: any, ctx: any): boolean
	local root = rec.root :: Frame
	local l = root:FindFirstChild("Label") :: TextLabel?
	local fill = root:FindFirstChild("Fill") :: Frame?
	if l == nil or fill == nil then return false end
	local st8 = n.st8
	local col = if st8 == "permanent" then C.gold elseif st8 == "ashed" then C.muted else C.ember
	local w = if ctx.mode == "COMPACT" then 260 else 320
	root.Size = UDim2.fromOffset(w, 48)
	root.AutomaticSize = Enum.AutomaticSize.None
	root.BackgroundColor3 = C.deep
	root.BackgroundTransparency = 0
	Common.drop(root, "Gradient")
	Common.drop(root, "List")
	Common.corner(root, 10)
	Common.stroke(root, 1.5, col, 0.35)
	root.ClipsDescendants = true
	local p = math.clamp(tonumber(n.p) or 0, 0, 1)
	fill.BackgroundColor3 = col
	fill.BackgroundTransparency = 0.55
	fill.Position = UDim2.new()
	fill.Size = UDim2.fromScale(p, 1)
	fill.ZIndex = 0
	Common.drop(fill, "Gradient")
	Common.text(l, "small", C.text)
	l.Size = UDim2.fromScale(1, 1)
	l.AutomaticSize = Enum.AutomaticSize.None
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.ZIndex = 2
	l.Visible = true
	local word = if st8 == "permanent" then "PERMANENT" elseif st8 == "ashed" then "ASHED" else "BURNING"
	local bp = Common.pr(n.bp)
	local text = Common.caps(word, col)
	if bp and st8 == "burning" then
		text ..= "   " .. Common.num(require(Core:WaitForChild("Rich")).pct(bp), "number", C.text)
	end
	Common.setText(l, text)
	local kids = root:FindFirstChild("Kids")
	if kids and kids:IsA("GuiObject") then kids.Visible = false end
	root.Visible = true
	return true
end

-- ------------------------------------------------------------------------------------------------------ dispatch
function Generic.skin(rec: any, n: any, ctx: any): boolean
	local t = n.t
	if t == "col" or t == "row" then
		container(rec, n, ctx)
		return true
	elseif t == "tabs" then
		container(rec, n, ctx)
		return true
	elseif t == "html" then
		return html(rec, n, ctx)
	elseif t == "blank" or t == "hr" or HIDDEN_CN[n.cn or ""] then
		(rec.root :: GuiObject).Visible = false
		return true
	elseif t == "btn" and SMALL[n.k or ""] then
		return Generic.button(rec, n, ctx)
	elseif t == "about" then
		return about(rec, n, ctx)
	elseif t == "bar" then
		return bar(rec, n, ctx)
	end
	return false
end

return Generic
