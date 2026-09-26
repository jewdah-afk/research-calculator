--!strict
--[[
	Challenge: the challenge card (Figma 5:173, DESIGN.md 5.7) and its action button.

	    idle         hue surface, the game's button word (START) in a hue pill
	    active       gold surface; EXIT EARLY
	    completable  gold surface + glow; FINISH
	    done         quiet green, the completions chip
	    locked       mauve, the requirement
	The card's text comes from the structured fields (ti, ds, goal, rw, cur, cmp, lim); the game's own title / body
	html children are hidden (Skins/Generic). The button is the chal's `chalbtn` child, fired as sent.
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Skin = require(Core:WaitForChild("Skin"))
local Common = require(script.Parent:WaitForChild("Common"))

local Challenge = {}

local C = Theme.C

local function stateOf(n: any): (string, string)
	local st8 = n.st8
	if st8 == "done" or (st8 == nil and n.cls == "done") then return "owned", "done" end
	if st8 == "completable" then return "gold", "completable" end
	if st8 == "active" or n.active then return "gold", "active" end
	if st8 == "locked" then return "locked", "locked" end
	-- idle: a completed-before challenge (cls done) still reads as done; the rest can start
	if n.cls == "done" then return "owned", "done" end
	return "can", "idle"
end
Challenge.stateOf = stateOf

function Challenge.skin(rec: any, n: any, ctx: any): boolean
	local root = rec.root :: Frame
	local l = root:FindFirstChild("Label") :: TextLabel?
	local kids = root:FindFirstChild("Kids") :: Frame?
	if l == nil or kids == nil then return false end
	local label = l :: TextLabel
	local compact = ctx.mode == "COMPACT"
	local surface, st8 = stateOf(n)
	local p = Common.surface(root, surface, ctx.hue, 16)
	Common.glow(root, if st8 == "completable" then C.complete elseif surface == "can" then ctx.hue else nil, 0.45, 16)
	Common.drop(root, "Gradient")
	-- the row's cards share its width evenly (a fixed 330 left a ragged gap on the right)
	local gap = if compact then 10 else 12
	local per = math.max(1, math.floor((ctx.contentW + gap) / ((if compact then 200 else 300) + gap)))
	local w = math.floor((ctx.contentW - gap * (per - 1)) / per)
	root.Size = UDim2.fromOffset(w, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.Visible = true
	Common.drop(root, "Limit")
	Common.pad(root, 14, 16, 14, 16)
	Common.list(root, false, 10)
	Common.text(label, "small", p.text)
	label.LayoutOrder = 0
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Visible = true
	local parts: { string } = {}
	table.insert(parts, Common.title(Common.plain(Common.str(n.ti) or ""), "card", p.title))
	local ds = Common.html(n.ds, "body", ctx.layer)
	if ds ~= "" then table.insert(parts, string.format('<font transparency="%.2f">%s</font>', p.textT, ds)) end
	local goal = Common.str(n.goal)
	if goal then
		table.insert(parts, Common.caps("Goal", p.soft) .. "  " .. Common.html(goal, "small", ctx.layer))
	end
	local rw = Common.str(n.rw)
	if rw then
		table.insert(parts, Common.caps("Reward", p.soft) .. "  " .. Common.html(rw, "small", ctx.layer))
	end
	local cur = Common.str(n.cur)
	if cur then
		table.insert(parts, Common.caps("Currently", p.soft) .. "  " .. Common.num(cur, "number", p.value))
	end
	Common.setText(label, table.concat(parts, "\n"))
	-- completions chip (cmp / lim; one-shot challenges show none)
	local cmp, lim = Common.str(n.cmp), Common.str(n.lim)
	if cmp and cmp ~= "0" then
		local text = if lim and lim ~= "Infinity" then cmp .. " / " .. lim else cmp .. " done"
		local chip = Common.chip(label, "Chip", text, { color = C.ownedValue, bg = Theme.mix(C.deep, C.bought, 0.25), bgT = 0,
			h = if compact then 26 else 28 })
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(1, 0, 0, 0)
		chip.ZIndex = 4
	else
		Common.drop(label, "Chip")
	end
	kids.LayoutOrder = 1
	Common.list(kids, true, 8, { wraps = true })
	rec.text, rec.textT, rec.base = p.text, 0, Theme.size("small")
	Common.state(root, if surface == "gold" then "can" else surface)
	return true
end

-- the chal's action button: coloured by the card's state, the game's word in caps
function Challenge.button(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local pid = Common.parentId(rec.id)
	local owner = if pid then Common.parentId(pid) else nil
	local chal = if pid then ctx.store:get(pid) else nil
	if type(chal) ~= "table" or chal.t ~= "chal" then
		chal = if owner then ctx.store:get(owner) else nil
	end
	local _, st8 = stateOf(if type(chal) == "table" then chal else {})
	local fill: Color3
	local ink: Color3 = C.text
	if st8 == "done" then
		fill, ink = Theme.mix(C.panel, C.bought, 0.28), C.ownedTitle
	elseif st8 == "completable" or st8 == "active" then
		fill, ink = C.complete, C.ink
	elseif st8 == "locked" then
		fill, ink = Theme.mix(C.panel, C.locked, 0.3), C.lockedTitle
	else
		fill = ctx.hue
		ink = if Theme.darkOnFill(ctx.layer) then C.ink else C.text
	end
	b.AutoButtonColor = false
	b.Visible = true
	b.BackgroundColor3 = fill
	b.BackgroundTransparency = 0
	for _, name in { "Gradient", "Glow", "Num", "Limit" } do Common.drop(b, name) end
	Common.corner(b, 10)
	Common.stroke(b, 1.5, Theme.lift(fill, 0.3), 0.1)
	Common.pad(b, 0, 16, 0, 16)
	b.Size = UDim2.fromOffset(0, if ctx.mode == "COMPACT" then 38 else 42)
	b.AutomaticSize = Enum.AutomaticSize.X
	Common.glow(b, if st8 == "completable" then C.complete else nil, 0.6, 14)
	-- the Substance kit: the hue plate for the live states, the dark plate for done / locked
	local lit = not (st8 == "done" or st8 == "locked")
	if Skin.apply(b, if lit then "cta" else "button", { tint = if lit then Theme.lift(fill, 0.1) else nil, scale = 0.4 }) and lit then
		ink = C.ink
	end
	Common.text(label, "label", ink)
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = UDim2.new(0, 0, 1, 0)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Visible = true
	local word = Common.plain(n.h)
	word = string.upper((string.gsub(string.gsub(word, "^%s+", ""), "%s+$", "")))
	Common.setText(label, Common.esc(word))
	Common.state(b, if st8 == "locked" then "locked" elseif st8 == "done" then "owned" else "can")
	return true
end

return Challenge
