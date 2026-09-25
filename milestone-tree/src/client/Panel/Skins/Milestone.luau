--!strict
--[[
	Milestone: a milestone row (DESIGN.md 5.7 "Milestone row").

	    NEXT (the first not-done row in ladder order, plan 1.13)  spotlight card: hue surface, NEXT MILESTONE caps,
	                                                              title (card), the effect (body)
	    done                                                      quiet green row: title (cardSmall) + effect (small)
	    future                                                    faint row: title + effect in soft
	    infected (mal)                                            danger rim; the effect splits at the game's <hr> into
	                                                              the base effect and the malware effect (plan 1.4)
	A row's children (the INFECT button of the malware ladder) sit under the text, skinned as small buttons.
	Long ladders are virtualised by the panel (Panel/Virtual); this skin draws the short ones.
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Common = require(script.Parent:WaitForChild("Common"))

local Milestone = {}

local C = Theme.C

-- the id of the NEXT milestone among the row's siblings (cached per apply)
function Milestone.nextOf(ctx: any, pid: string?): string?
	if pid == nil then return nil end
	local key = "next:" .. pid
	local hit = ctx.cache[key]
	if hit ~= nil then return if hit == false then nil else hit end
	local found: string? = nil
	for _, cid in ctx.store:kids(pid) do
		local k = ctx.store:get(cid)
		if type(k) == "table" and k.t == "ms" and not k.done then
			found = cid
			break
		end
	end
	ctx.cache[key] = found or false
	return found
end

-- the row text: NEXT / done / future, with the infected split
function Milestone.text(n: any, kind: string, ctx: any): string
	local title = Common.plain(Common.str(n.ti) or "")
	local ds = Common.str(n.ds) or ""
	local parts: { string } = {}
	if kind == "next" then
		table.insert(parts, Common.caps("Next milestone", C.text))
		table.insert(parts, Common.title(title, "card", C.text))
	else
		table.insert(parts, Common.title(title, "cardSmall", if kind == "done" then C.ownedTitle else C.text))
	end
	local role = if kind == "next" then "body" else "small"
	if n.mal and string.find(ds, "<hr", 1, true) then
		local a, b = string.match(ds, "^(.-)<hr[^>]*>(.*)$")
		if a and b then
			local base = Common.html(a, role, ctx.layer)
			local mal = Common.html(b, role, ctx.layer)
			if base ~= "" then table.insert(parts, string.format('<font transparency="0.1">%s</font>', base)) end
			if mal ~= "" then table.insert(parts, string.format('<font color="%s">%s</font>', Common.hex(Theme.lift(C.danger, 0.3)), mal)) end
			return table.concat(parts, "\n")
		end
	end
	local body = Common.html(ds, role, ctx.layer)
	if body ~= "" then
		local t = if kind == "next" then 0.08 elseif kind == "done" then 0.15 else 0.1
		local color = if kind == "future" then C.soft else C.text
		table.insert(parts, string.format('<font color="%s" transparency="%.2f">%s</font>', Common.hex(color), t, body))
	end
	return table.concat(parts, "\n")
end

function Milestone.skin(rec: any, n: any, ctx: any): boolean
	local root = rec.root :: Frame
	local l = root:FindFirstChild("Label") :: TextLabel?
	local kids = root:FindFirstChild("Kids") :: Frame?
	if l == nil or kids == nil then return false end
	local label = l :: TextLabel
	local isNext = not n.done and Milestone.nextOf(ctx, Common.parentId(rec.id)) == rec.id
	local kind = if n.done then "done" elseif isNext then "next" else "future"
	local state = if n.done then "owned" else "notyet"
	root.Visible = true
	Common.drop(root, "Gradient")
	Common.drop(root, "Glow")
	root.Size = UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	Common.drop(root, "Limit")
	if kind == "next" then
		Common.surface(root, "can", ctx.hue, 16)
		Common.glow(root, ctx.hue, 0.45, 18)
		Common.pad(root, 14, 18, 14, 18)
	else
		Common.drop(root, "Fill")
		root.BackgroundTransparency = 0
		root.BackgroundColor3 = if kind == "done" then Theme.mix(C.panel, C.bought, 0.14) else C.panel2
		Common.corner(root, 12)
		Common.pad(root, 10, 16, 10, 16)
		if n.mal then
			Common.stroke(root, 2, C.danger, 0.1)
		elseif kind == "done" then
			Common.stroke(root, 1, C.bought, 0.6)
		else
			Common.stroke(root, 1, C.stroke, 0.35)
		end
	end
	if kind == "next" and n.mal then Common.stroke(root, 2, C.danger, 0.1) end
	Common.list(root, false, 8)
	Common.text(label, if kind == "next" then "body" else "small", C.text)
	label.LayoutOrder = 0
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Visible = true
	Common.setText(label, Milestone.text(n, kind, ctx))
	-- children (the malware INFECT button): a row under the text, hidden when empty
	kids.LayoutOrder = 1
	local hasKids = #ctx.store:kids(rec.id) > 0
	kids.Visible = hasKids
	if hasKids then Common.list(kids, true, 8, { wraps = true }) end
	rec.text, rec.textT, rec.base = C.text, 0, Theme.size("small")
	Common.state(root, state)
	return true
end

return Milestone
