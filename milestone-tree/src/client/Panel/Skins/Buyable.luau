--!strict
--[[
	Buyable: the buyable card (DESIGN.md 5.7): wide (700 du) when a section has at most 2, else a 280 du grid; full
	width on phones.

	    title (card) + LV and the level (big) at the top right
	    the effect lines of the game's text (its <br> lines without the title, level and cost lines: a structural
	    split, no parsing of the numbers)
	    NEXT LEVEL + the cost (numberHeavy + short unit)
	    the hold strip: "HOLD TO BUY" lit when affordable; otherwise "Not enough <unit>" with the pr bar and % inside
	    MAX (green) when the level reached the limit
	The button keeps Render's hold-to-repeat (20 a second after 0.25 s, gated by the 10 px / scroll rule).
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Rich = require(Core:WaitForChild("Rich"))
local Common = require(script.Parent:WaitForChild("Common"))
local Signatures = require(script.Parent.Parent.Parent:WaitForChild("Signatures"):WaitForChild("Signatures"))

local Buyable = {}

local C = Theme.C

local function stateOf(n: any): string
	local lv, max = Common.str(n.lv), Common.str(n.max)
	if n.cls == "bought" or (lv ~= nil and max ~= nil and lv == max) then return "owned" end
	if n.cls == "can" then return "can" end
	return "notyet"
end

-- the game's text lines that describe the effect (drop the title, the level / tier and the cost lines)
local DROP = { "^Level", "^Tier", "^Amount" }
local function effectLines(n: any): string
	local h = Common.str(n.h)
	if h == nil then return "" end
	local parts = string.split((string.gsub(h, "<br%s*/?>", "\0")), "\0")
	local keep: { string } = {}
	for i, part in parts do
		local plain = Common.plain(part)
		plain = string.gsub(plain, "^%s+", "")
		if plain == "" then continue end
		if i == 1 and string.find(part, "<h", 1, true) then continue end
		local drop = false
		for _, pat in DROP do
			if string.find(plain, pat) then drop = true end
		end
		if string.find(plain, "^Cost") and Common.str(n.co) and Common.str(n.cur) then drop = true end
		if not drop then table.insert(keep, part) end
	end
	return table.concat(keep, "<br>")
end

-- how many buyables share this card's component (cached per apply)
local function siblings(ctx: any, id: string): number
	local pid = Common.parentId(id)
	if pid == nil then return 1 end
	local gid = Common.parentId(pid)
	local key = "buyN:" .. (gid or pid)
	local hit = ctx.cache[key]
	if hit then return hit end
	local nBuy = 0
	local function walk(x: string, d: number)
		if d > 2 then return end
		local node = ctx.store:get(x)
		if type(node) ~= "table" then return end
		if node.t == "btn" and node.k == "buy" then nBuy += 1 end
		if type(node.c) == "table" then
			for _, c in node.c do
				if type(c) == "string" then walk(c, d + 1) end
			end
		end
	end
	walk(gid or pid, 0)
	ctx.cache[key] = math.max(1, nBuy)
	return math.max(1, nBuy)
end

function Buyable.skin(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local state = stateOf(n)
	local compact = ctx.mode == "COMPACT"
	b.Visible = true
	b.AutoButtonColor = false
	Common.drop(b, "Num")
	Common.drop(b, "Gradient")
	local p = Common.surface(b, state, ctx.hue, 16)
	Common.glow(b, if state == "can" then ctx.hue else nil, 0.2, 14)
	local w: number
	if compact then
		w = ctx.contentW
	elseif siblings(ctx, rec.id) <= 2 then
		w = math.min(700, ctx.contentW)
	else
		w = 280
	end
	b.Size = UDim2.fromOffset(w, 0)
	b.AutomaticSize = Enum.AutomaticSize.Y
	local lim = Common.get(b, "Limit", "UISizeConstraint") :: UISizeConstraint
	lim.MinSize = Vector2.new(0, if compact then 96 else 132)
	lim.MaxSize = Vector2.new(math.huge, math.huge)
	Common.pad(b, if compact then 12 else 16, if compact then 12 else 18, if compact then 12 else 16, if compact then 12 else 18)
	Common.list(b, false, 8, { name = "CardList" })

	-- title and effect
	Common.text(label, "body", p.text, 0)
	label.LayoutOrder = 1
	label.ZIndex = 3
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Visible = true
	local title = Common.plain(Common.str(n.ti) or "")
	local parts = { Common.title(title, "card", p.title) }
	local eff = Common.html(effectLines(n), "body", ctx.layer)
	if eff ~= "" then table.insert(parts, string.format('<font transparency="%.2f">%s</font>', p.textT, eff)) end
	Common.setText(label, table.concat(parts, "\n"))
	-- the level at the top right
	local lvText = Common.str(n.lv)
	if lvText then
		local lv = Common.get(label, "Lv", "TextLabel") :: TextLabel
		Common.text(lv, "big", C.text)
		-- room for "LV " and the digits; a wide card gives a long level (e.g. 21,543,217) the room it needs
		local clear = math.min(math.max(160, math.floor(w * 0.4)), 28 + 23 * #lvText)
		lv.AnchorPoint = Vector2.new(1, 0)
		lv.Position = UDim2.new(1, clear, 0, -4) -- children sit in the padded box: step back out of the padding
		lv.AutomaticSize = Enum.AutomaticSize.XY
		lv.Size = UDim2.new()
		lv.TextXAlignment = Enum.TextXAlignment.Right
		lv.TextWrapped = false
		lv.ZIndex = 4
		local maxText = Common.str(n.max)
		local big = Common.num(lvText, "big", C.text)
		local text = Common.caps("Lv", p.soft) .. " " .. big
		if maxText then text ..= Common.run(Common.esc(" / ") , "number", p.soft) .. Common.num(maxText, "number", p.soft) end
		Common.setText(lv, text)
		-- keep the title clear of the level
		local pad = Common.get(label, "Clear", "UIPadding") :: UIPadding
		pad.PaddingRight = UDim.new(0, clear)
	else
		Common.drop(label, "Lv")
		Common.drop(label, "Clear")
	end

	-- NEXT LEVEL cost
	local co = Common.str(n.co)
	if co and state ~= "owned" then
		local foot = Common.get(b, "Foot", "TextLabel") :: TextLabel
		foot.LayoutOrder = 2
		Common.text(foot, "caps", p.soft)
		foot.Size = UDim2.new(1, 0, 0, 24)
		foot.AutomaticSize = Enum.AutomaticSize.None
		foot.TextXAlignment = Enum.TextXAlignment.Left
		foot.TextYAlignment = Enum.TextYAlignment.Center
		foot.TextWrapped = false
		foot.TextTruncate = Enum.TextTruncate.AtEnd
		local unit = Signatures.unit(n.cur)
		Common.setText(foot, Common.caps("Next level", p.soft) .. "   " ..
			Common.num(co, "numberHeavy", if state == "can" then C.text else C.notYet, unit))
	else
		Common.drop(b, "Foot")
	end

	-- the hold strip
	local strip = Common.get(b, "Hold", "TextLabel") :: TextLabel
	strip.LayoutOrder = 3
	strip.ZIndex = 3
	Common.text(strip, "label", C.text)
	strip.Size = UDim2.new(1, 0, 0, if compact then 30 else 32)
	strip.AutomaticSize = Enum.AutomaticSize.None
	strip.TextXAlignment = Enum.TextXAlignment.Center
	strip.TextYAlignment = Enum.TextYAlignment.Center
	strip.TextWrapped = false
	strip.BackgroundTransparency = 0
	strip.BackgroundColor3 = Color3.new(1, 1, 1)
	Common.drop(strip, "Corner")
	local g = Common.get(strip, "Fill", "UIGradient") :: UIGradient
	g.Rotation = 0
	local pr = Common.pr(n.pr)
	if state == "owned" then
		g.Color = ColorSequence.new(Theme.mix(C.deep, C.bought, 0.3))
		strip.TextColor3 = C.ownedValue
		Common.setText(strip, "MAX")
	elseif state == "can" then
		-- Sleek: the actionable strip is the light hue surface with ink type, like the BUY bars
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.lift(ctx.hue, 0.25)), ColorSequenceKeypoint.new(1, ctx.hue) })
		strip.TextColor3 = C.ink
		Common.setText(strip, Rich.caps("Hold to buy"))
	else
		local lit = Theme.mix(C.deep, ctx.hue, 0.32)
		local track = Theme.mix(C.deep, C.white, 0.05)
		local q = pr or 0
		if q <= 0.001 then
			g.Color = ColorSequence.new(track)
		else
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, lit),
				ColorSequenceKeypoint.new(math.min(0.998, q), lit),
				ColorSequenceKeypoint.new(math.min(0.999, q + 0.001), track),
				ColorSequenceKeypoint.new(1, track),
			})
		end
		strip.TextColor3 = C.text
		local unit = Signatures.unit(n.cur)
		local reason = if unit ~= "" then "Not enough " .. unit else "Not affordable"
		local text = Common.esc(reason)
		if pr then text ..= "   " .. Common.num(Rich.pct(pr), "number", C.text) end
		Common.setText(strip, text)
	end
	Common.state(b, state)
	Common.transition(ctx, n.a, state, b)
	return true
end

return Buyable
