--!strict
--[[
	Common: the small builders every panel skin shares. Everything is get-or-create by name and writes every property
	it owns on each call, so a skin can run on every update without leaving stale styling (plan 2.5).

	    Common.get(parent, "Chip", "TextLabel")     get-or-create a child of a class
	    Common.drop(parent, "Chip")                 remove it when the state no longer needs it
	    Common.text(l, "body", color)               a role's font, size and LineHeight (Theme.text) plus colour
	    Common.run("Prestige Boost I", "card", c)   one RichText run in a role's family / weight / size / colour
	    Common.surface(f, state, hue)               the card surface of a state (DESIGN.md 5.7): fill, rim, corner
	    Common.chip(parent, "Chip", "BUY", o)       a 28 du chip; Common.bar(parent, "Bar", p, color) a thin pr bar
	    Common.state(root, "can")                   the State attribute the tests read (can / owned / notyet / locked)

	Text rules (DESIGN.md 9): Sarpanch only for numeral runs, italic only on display and short title roles, no
	outline on text under 20 du, reading text never below the floors (Theme.size holds them).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Rich = require(Core:WaitForChild("Rich"))
local Html = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Html"))

local Common = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- ------------------------------------------------------------------------------------------------------ instances
function Common.get(parent: Instance, name: string, class: string): any
	local c = parent:FindFirstChild(name)
	if c and c.ClassName == class then return c end
	if c then c:Destroy() end
	local n = Instance.new(class :: any)
	n.Name = name
	if n:IsA("GuiObject") then
		local g = n :: GuiObject
		g.BorderSizePixel = 0
		g.BackgroundTransparency = 1
	end
	n.Parent = parent
	return n
end
function Common.drop(parent: Instance, name: string)
	local c = parent:FindFirstChild(name)
	if c then c:Destroy() end
end

-- Sleek: panels are square. Scale radii (circles, pills: r < 1) stay; pixel radii become sharp corners
function Common.corner(f: GuiObject, r: number, name: string?)
	if r >= 1 or r <= 0 then
		Common.drop(f, name or "Corner")
		return
	end
	local c = Common.get(f, name or "Corner", "UICorner") :: UICorner
	c.CornerRadius = UDim.new(r, 0)
end
function Common.stroke(f: GuiObject, thickness: number, color: Color3, transparency: number?, name: string?): UIStroke
	local s = Common.get(f, name or "Border", "UIStroke") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = thickness
	s.Color = color
	s.Transparency = transparency or 0
	s.LineJoinMode = Enum.LineJoinMode.Round
	return s
end
function Common.pad(f: GuiObject, top: number, right: number, bottom: number, left: number, name: string?)
	local p = Common.get(f, name or "Pad", "UIPadding") :: UIPadding
	p.PaddingTop, p.PaddingRight = UDim.new(0, top), UDim.new(0, right)
	p.PaddingBottom, p.PaddingLeft = UDim.new(0, bottom), UDim.new(0, left)
end
-- a vertical (or horizontal) list layout named List
export type ListOpts = { align: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?, wraps: boolean?, name: string? }
function Common.list(f: GuiObject, horizontal: boolean, gap: number, o: ListOpts?): UIListLayout
	local opts: ListOpts = o or ({} :: ListOpts)
	local l = Common.get(f, opts.name or "List", "UIListLayout") :: UIListLayout
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.HorizontalAlignment = opts.align or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = opts.valign or Enum.VerticalAlignment.Top
	l.Wraps = opts.wraps == true
	return l
end
-- a vertical top-to-bottom two/three-stop fill on a white background (the surface gradients)
function Common.fill(f: GuiObject, top: Color3, bottom: Color3, mid: Color3?, name: string?)
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 0
	local g = Common.get(f, name or "Fill", "UIGradient") :: UIGradient
	g.Rotation = 90
	g.Color = if mid
		then ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.5, mid), ColorSequenceKeypoint.new(1, bottom) })
		else ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(1, bottom) })
	g.Transparency = NumberSequence.new(0)
end
-- a soft glow around a surface: UIShadow where the engine has it, nothing otherwise (the rim already carries the hue)
function Common.glow(f: GuiObject, color: Color3?, alpha: number?, blur: number?)
	if color == nil or not Theme.caps.UIShadow then
		Common.drop(f, "Glow")
		return
	end
	local s = Common.get(f, "Glow", "UIShadow") :: any
	pcall(function()
		s.Color = color
		s.Transparency = 1 - (alpha or 0.5)
		s.BlurRadius = UDim.new(0, blur or 18)
		s.Offset = UDim2.new()
	end)
end
-- a round radial blob (never a square: the fade reaches 1 by t = .7 and a UICorner keeps it round); nil without Radial
function Common.blob(parent: Instance, name: string, color: Color3, alpha: number): Frame?
	if not Theme.caps.Radial then
		Common.drop(parent, name)
		return nil
	end
	local f = Common.get(parent, name, "Frame") :: Frame
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	f.Active = false
	Common.corner(f, 0.5, "Round")
	local g = Common.get(f, "Radial", "UIGradient") :: UIGradient
	g.Type = Enum.GradientType.Radial
	g.Color = ColorSequence.new(color)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - alpha),
		NumberSequenceKeypoint.new(0.3, 1 - alpha * 0.55),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	return f
end

-- ------------------------------------------------------------------------------------------------------ text
local FAMILY: { [string]: string } = {
	Montserrat = "rbxasset://fonts/families/Montserrat.json",
	Sarpanch = "rbxasset://fonts/families/Sarpanch.json",
	RobotoMono = "rbxasset://fonts/families/RobotoMono.json",
}
Common.FAMILY = FAMILY

function Common.esc(s: string): string
	return Html.escape(s)
end
function Common.plain(html: any): string
	if type(html) ~= "string" then return "" end
	return Html.plain(html)
end
function Common.hex(c: Color3): string
	return "#" .. Theme.toHex(c)
end
function Common.words(s: string): number
	local n = 0
	for _ in string.gmatch(s, "%S+") do n += 1 end
	return n
end

-- a label's type (Theme.text) and colour; RichText on, no stroke
function Common.text(label: GuiObject, role: string, color: Color3?, transparency: number?)
	local l = label :: any
	Theme.text(label, role)
	l.TextColor3 = color or Theme.C.text
	l.TextTransparency = transparency or 0
	l.RichText = true
	l.TextStrokeTransparency = 1
end

-- a plain text label (transparent, RichText, AutomaticSize Y by default)
export type LabelOpts = { wrap: boolean?, autoX: boolean?, align: Enum.TextXAlignment?, order: number? }
function Common.label(parent: Instance, name: string, role: string, color: Color3?, o: LabelOpts?): TextLabel
	local opts: LabelOpts = o or ({} :: LabelOpts)
	local l = Common.get(parent, name, "TextLabel") :: TextLabel
	Common.text(l, role, color)
	l.TextWrapped = opts.wrap ~= false
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Active = false
	if opts.autoX then
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.new()
	else
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.new(1, 0, 0, 0)
	end
	if opts.order then l.LayoutOrder = opts.order end
	return l
end

-- one RichText run in a role (text must already be RichText-safe: escaped or from Rich)
function Common.run(text: string, role: string, color: Color3?, transparency: number?): string
	local r = Theme.ROLES[role] or Theme.ROLES.body
	local attrs = string.format('family="%s" weight="%d" size="%d"', FAMILY[r.family] or FAMILY.Montserrat, r.weight.Value,
		Theme.size(role))
	if color then attrs ..= string.format(' color="%s"', Common.hex(color)) end
	if transparency and transparency > 0 then attrs ..= string.format(' transparency="%.2f"', transparency) end
	local body = if r.italic then "<i>" .. text .. "</i>" else text
	return "<font " .. attrs .. ">" .. body .. "</font>"
end
-- a caps label run (upper case with hair spaces, DESIGN.md 9.1)
function Common.caps(text: string, color: Color3?, role: string?): string
	return Common.run(Common.esc(Rich.caps(text)), role or "caps", color or Theme.C.soft)
end
-- a card / section title run: italic only when it is at most 4 words (DESIGN.md 9.1)
function Common.title(text: string, role: string, color: Color3?): string
	local r = Theme.ROLES[role] or Theme.ROLES.card
	local size = Theme.size(role)
	local attrs = string.format('family="%s" weight="%d" size="%d"', FAMILY[r.family] or FAMILY.Montserrat, r.weight.Value, size)
	if color then attrs ..= string.format(' color="%s"', Common.hex(color)) end
	local body = Common.esc(text)
	if r.italic and Common.words(text) <= 4 then body = "<i>" .. body .. "</i>" end
	return "<font " .. attrs .. ">" .. body .. "</font>"
end
-- a game number string in a Sarpanch role, words / units as a Montserrat run (Rich.num)
function Common.num(s: string, role: string, color: Color3?, unit: string?, onFill: boolean?): string
	local r = Theme.ROLES[role] or Theme.ROLES.number
	local size = Theme.size(role)
	local text = if unit and unit ~= "" then s .. " " .. unit else s
	local body = Rich.num(text, { size = size, onFill = onFill, unit = color })
	local attrs = string.format('family="%s" weight="%d" size="%d"', FAMILY[r.family] or FAMILY.Sarpanch, r.weight.Value, size)
	if color then attrs ..= string.format(' color="%s"', Common.hex(color)) end
	return "<font " .. attrs .. ">" .. body .. "</font>"
end
-- the game's HTML as body RichText with the layer's colour remap (DESIGN.md 11.2)
function Common.html(html: any, role: string, layer: string?): string
	if type(html) ~= "string" or html == "" then return "" end
	return Rich.html(html, Theme.size(role), layer)
end
function Common.setText(label: GuiObject, s: string)
	local l = label :: any
	if l.Text ~= s then l.Text = s end
end
-- pcall for functions that return nothing (the result is ok, err)
function Common.try(f: (...any) -> ...any, ...: any): (boolean, any)
	return pcall(function(...: any): any
		f(...)
		return nil
	end, ...)
end

-- ------------------------------------------------------------------------------------------------------ surfaces
export type Palette = { top: Color3, bottom: Color3, rim: Color3, rimT: number, title: Color3, text: Color3, textT: number,
	soft: Color3, value: Color3 }
-- the card surface of each state (DESIGN.md 5.7, 11.2): the layer hue paints only the actionable state
function Common.palette(state: string, hue: Color3): Palette
	local C = Theme.C
	-- Sleek (art/ui/clean STYLES[1]): translucent near-black slabs with a 1 du hairline; the hue tints only the
	-- actionable card, owned is a faint green, locked and not-yet stay neutral
	local top, bottom = Color3.fromHex("0c1119"), Color3.fromHex("080b12")
	if state == "can" then
		return { top = Theme.mix(top, hue, 0.2), bottom = Theme.mix(bottom, hue, 0.05), rim = hue, rimT = 0.5,
			title = C.text, text = C.text, textT = 0.1, soft = C.soft, value = C.text }
	elseif state == "owned" then
		return { top = Theme.mix(top, C.bought, 0.085), bottom = Theme.mix(bottom, C.bought, 0.025), rim = C.bought, rimT = 0.72,
			title = C.ownedTitle, text = C.text, textT = 0.22, soft = C.soft, value = C.ownedValue }
	elseif state == "gold" then
		return { top = Theme.mix(top, C.complete, 0.2), bottom = Theme.mix(bottom, C.complete, 0.05), rim = C.complete, rimT = 0.35,
			title = C.text, text = C.text, textT = 0.1, soft = C.soft, value = C.text }
	elseif state == "locked" then
		return { top = Color3.fromHex("07090e"), bottom = Color3.fromHex("05070b"), rim = C.white, rimT = 0.92,
			title = C.lockedTitle, text = C.text, textT = 0.3, soft = C.soft, value = C.notYet }
	end
	-- notyet: unlocked, not affordable (a trace of mauve)
	return { top = Theme.mix(top, C.locked, 0.1), bottom = Theme.mix(bottom, C.locked, 0.03), rim = C.locked, rimT = 0.55,
		title = C.text, text = C.text, textT = 0.14, soft = C.soft, value = C.notYet }
end
-- fill + hairline of a card in a state (square corners; the radius argument is kept for signatures that ask for one)
function Common.surface(f: GuiObject, state: string, hue: Color3, radius: number?): Palette
	local p = Common.palette(state, hue)
	Common.fill(f, p.top, p.bottom)
	if radius and radius > 0 and radius <= 6 then
		Common.corner(f, radius)
	else
		Common.drop(f, "Corner")
	end
	local st = Common.stroke(f, 1, p.rim, p.rimT)
	st.LineJoinMode = Enum.LineJoinMode.Miter
	Common.drop(f, "Gradient") -- Style.apply's game gradient, if an old look was ever applied
	return p
end
function Common.state(root: Instance, state: string)
	if root:GetAttribute("State") ~= state then root:SetAttribute("State", state) end
end

-- ------------------------------------------------------------------------------------------------------ chips, bars
export type ChipOpts = { bg: Color3?, bgT: number?, color: Color3?, role: string?, h: number?, rich: boolean?, stroke: Color3? }
-- a chip: a TextLabel with a background and corner, sized from its text (two spaces of side padding)
function Common.chip(parent: Instance, name: string, text: string, o: ChipOpts?): TextLabel
	local opts: ChipOpts = o or ({} :: ChipOpts)
	local l = Common.get(parent, name, "TextLabel") :: TextLabel
	local role = opts.role or "label"
	Common.text(l, role, opts.color or Theme.C.text)
	l.TextWrapped = false
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, opts.h or 28)
	l.BackgroundColor3 = opts.bg or BLACK
	l.BackgroundTransparency = if opts.bg == nil and opts.bgT == nil then 0.55 else (opts.bgT or 0)
	l.Active = false
	-- side padding as spaces (a UIPadding per chip costs an instance on every card)
	Common.setText(l, "  " .. (if opts.rich then text else Common.esc(text)) .. "  ")
	Common.drop(l, "Corner")
	Common.drop(l, "Pad")
	if opts.stroke then
		Common.stroke(l, 1, opts.stroke, 0.35).LineJoinMode = Enum.LineJoinMode.Miter
	else
		Common.drop(l, "Border")
	end
	return l
end
-- a thin progress bar (p in 0..1): one Frame whose gradient shows the filled part (no fill child)
function Common.bar(parent: Instance, name: string, p: number, color: Color3, h: number?): Frame
	local f = Common.get(parent, name, "Frame") :: Frame
	f.Size = UDim2.new(1, 0, 0, h or 5)
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 0
	f.Active = false
	Common.drop(f, "Corner")
	local g = Common.get(f, "Fill", "UIGradient") :: UIGradient
	local q = math.clamp(p, 0, 1)
	local track = Color3.fromRGB(38, 44, 56)
	if q <= 0.001 then
		g.Color = ColorSequence.new(track)
	elseif q >= 0.999 then
		g.Color = ColorSequence.new(color)
	else
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(q, color),
			ColorSequenceKeypoint.new(math.min(1, q + 0.001), track),
			ColorSequenceKeypoint.new(1, track),
		})
	end
	g.Rotation = 0
	return f
end

-- ------------------------------------------------------------------------------------------------------ motion
-- the buy feedback (DESIGN.md 5.4): a card that turns owned bumps and its rim flashes; keyed by (layer, the action's
-- id), never by the path id; nothing plays the first time a key is seen after the panel opened
local lastState: { [string]: string } = {}
function Common.transition(ctx: any, a: any, state: string, root: GuiObject)
	if type(a) ~= "table" then return end
	local key = tostring(ctx.layer) .. ":" .. tostring(a[1]) .. ":" .. tostring(a[3])
	local prev = lastState[key]
	lastState[key] = state
	if ctx.firstSeen(key) or prev == nil or prev == state then return end
	if prev == "can" and state == "owned" then
		local Motion = require(Core:WaitForChild("Motion")) :: any
		Motion.bump(root, 0.06)
		local rim = root:FindFirstChild("Border")
		if rim and rim:IsA("UIStroke") then
			local final = rim.Transparency
			rim.Transparency = 0
			rim.Color = Color3.new(1, 1, 1)
			Motion.tween(rim, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = final, Color = Theme.C.bought }, "flash:" .. key)
		end
	end
end

-- a per mille progress value (view: 0..1000) -> 0..1, nil when absent
function Common.pr(v: any): number?
	if type(v) ~= "number" then return nil end
	return math.clamp(v / 1000, 0, 1)
end
-- nil, false and JS null are "none" (plan 1.8)
function Common.str(v: any): string?
	if type(v) == "string" and v ~= "" then return v end
	if type(v) == "number" then return tostring(v) end
	return nil
end

-- the row id's parent ("tab.2.5.1" -> "tab.2.5")
function Common.parentId(id: string): string?
	return string.match(id, "^(.*)%.%d+$")
end
function Common.depth(id: string): number
	local _, n = string.gsub(id, "%.", "")
	return n
end

return Common
