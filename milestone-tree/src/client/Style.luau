--!strict
--[[
	Style: the page's CSS as Roblox GUI properties. The look of each kind of button comes from the game's
	style.css (TMT + NG+): sizes, the locked / bought / can colours, borders and corners. The per-thing style objects
	the game sets (st in a view node) are applied on top with Style.apply.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Html = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Html"))

local Style = {}

Style.FONT = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
Style.BG = Color3.fromRGB(15, 15, 15)            -- --background
Style.TEXT = Color3.fromRGB(223, 223, 223)       -- --color
Style.POINTS = Color3.fromRGB(255, 255, 255)     -- --points
Style.LOCKED = Color3.fromHex("bf8f8f")
Style.BOUGHT = Color3.fromHex("77bf5f")
Style.COMPLETE = Color3.fromHex("ffbf00")
Style.PERK = Color3.fromHex("fdbc30")
Style.PSEUDO = Color3.fromHex("fd3030")
Style.DARK = Color3.new(0, 0, 0)

-- per button kind: w / h (px, h = minimum height when grow), font (px), radius (px or scale when < 1),
-- stroke (px, rgba(0,0,0,0.125)), grow (height follows the text), text colour
export type Kind = { w: number?, h: number, font: number, radius: number, stroke: number, grow: boolean, text: Color3, align: Enum.TextXAlignment? }
local K: { [string]: Kind } = {
	upg = { w = 200, h = 115, font = 10, radius = 0, stroke = 2, grow = true, text = Style.DARK },
	perk = { w = 200, h = 115, font = 10, radius = 0, stroke = 2, grow = true, text = Color3.new(1, 1, 1) },
	click = { w = 200, h = 115, font = 10, radius = 0, stroke = 2, grow = true, text = Style.DARK },
	buy = { w = 200, h = 200, font = 10, radius = 0.25, stroke = 2, grow = true, text = Style.DARK },
	grid = { w = 80, h = 80, font = 10, radius = 0.15, stroke = 2, grow = true, text = Style.DARK },
	reset = { w = 250, h = 90, font = 13, radius = 0, stroke = 4, grow = true, text = Style.DARK },
	tab = { w = nil, h = 38, font = 20, radius = 10, stroke = 2, grow = false, text = Style.TEXT },
	toggle = { w = 40, h = 40, font = 12, radius = 0.25, stroke = 2, grow = false, text = Style.DARK },
	respec = { w = 120, h = 50, font = 10, radius = 0.1, stroke = 2, grow = true, text = Style.DARK },
	master = { w = 120, h = 50, font = 10, radius = 0.1, stroke = 2, grow = true, text = Style.DARK },
	sell = { w = 120, h = 50, font = 10, radius = 0.1, stroke = 2, grow = true, text = Style.DARK },
	chalbtn = { w = 120, h = 50, font = 12, radius = 0.1, stroke = 2, grow = true, text = Style.DARK },
	malware = { w = 260, h = 40, font = 12, radius = 0, stroke = 2, grow = true, text = Color3.new(1, 1, 1) },
	menu = { w = 285, h = 35, font = 18, radius = 0, stroke = 2, grow = false, text = Style.DARK },
	opt = { w = 250, h = 60, font = 13, radius = 0, stroke = 0, grow = true, text = Color3.new(1, 1, 1), align = Enum.TextXAlignment.Left },
}
Style.KIND = K

-- the background a button's class gives it (the game's own style / layer colour comes on top)
function Style.classColor(kind: string, cls: string?): Color3?
	if cls == "locked" or cls == "plocked" then return Style.LOCKED end
	if cls == "bought" then return Style.BOUGHT end
	if cls == "perk" then return Style.PERK end
	if cls == "perked" then return Style.DARK end
	if cls == "pseudo" then return Style.PSEUDO end
	if kind == "opt" then return Color3.fromRGB(22, 22, 22) end
	if kind == "menu" then return Color3.fromHex("a3a3a3") end
	if kind == "tab" then return nil end
	return Style.POINTS
end

local function child<T>(obj: Instance, class: string, name: string): any
	local c = obj:FindFirstChild(name)
	if c and c.ClassName == class then return c end
	if c then c:Destroy() end
	local n = Instance.new(class :: any)
	n.Name = name
	n.Parent = obj
	return n
end
Style.child = child

local function drop(obj: Instance, name: string)
	local c = obj:FindFirstChild(name)
	if c then c:Destroy() end
end
Style.drop = drop

function Style.corner(obj: GuiObject, r: number?)
	if r == nil or r == 0 then drop(obj, "Corner"); return end
	local c = child(obj, "UICorner", "Corner") :: UICorner
	c.CornerRadius = if r < 1 then UDim.new(r, 0) else UDim.new(0, r)   -- < 1: CSS percent / 100
end

function Style.stroke(obj: GuiObject, px: number?, color: Color3?, transparency: number?)
	if px == nil or px <= 0 then drop(obj, "Border"); return end
	local s = child(obj, "UIStroke", "Border") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = math.min(px, 6)
	s.Color = color or Style.DARK
	s.Transparency = transparency or 0.875
end

-- a glow for notify / resetNotify (the page uses a blurred box-shadow)
function Style.glow(obj: GuiObject, color: Color3?)
	if color == nil then drop(obj, "Glow"); return end
	local s = child(obj, "UIStroke", "Glow") :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = 3
	s.Color = color
	s.Transparency = 0.1
end

function Style.pad(obj: GuiObject, px: number)
	local p = child(obj, "UIPadding", "Pad") :: UIPadding
	p.PaddingTop, p.PaddingBottom = UDim.new(0, px), UDim.new(0, px)
	p.PaddingLeft, p.PaddingRight = UDim.new(0, px), UDim.new(0, px)
end

-- linear-gradient(...) -> UIGradient. Stops in px (the game's progress-bar trick: colour A up to Npx, then B) are
-- turned into fractions of the element's width.
function Style.gradient(obj: GuiObject, css: string?, widthPx: number?)
	if css == nil or not string.find(css, "gradient") then drop(obj, "Gradient"); return false end
	local stops = Html.gradient(css)
	if #stops == 0 then drop(obj, "Gradient"); return false end
	local w = widthPx or 200
	local pts: { ColorSequenceKeypoint } = {}
	local lastT = -1
	local function add(t: number, c: Color3)
		t = math.clamp(t, 0, 1)
		if t <= lastT then t = math.min(1, lastT + 0.0005) end
		if t <= lastT then return end
		table.insert(pts, ColorSequenceKeypoint.new(t, c))
		lastT = t
	end
	for i, s in stops do
		local t: number
		if (s :: any).px ~= nil then t = (s :: any).px / w
		elseif s.stop ~= nil then t = s.stop
		else t = if #stops == 1 then 0 else (i - 1) / (#stops - 1) end
		if i > 1 and t < lastT then t = lastT end
		add(if i == 1 then 0 else t, s.c)
		if i == 1 and t > 0 then add(t, s.c) end
	end
	if lastT < 1 then add(1, stops[#stops].c) end
	if #pts < 2 then drop(obj, "Gradient"); obj.BackgroundColor3 = stops[1].c; return true end
	while #pts > 20 do table.remove(pts, (#pts - 1)) end -- keep the last stop
	local g = child(obj, "UIGradient", "Gradient") :: UIGradient
	g.Color = ColorSequence.new(pts)
	local dir = string.lower(css)
	g.Rotation = if string.find(dir, "to bottom") then 90 elseif string.find(dir, "to left") then 180 elseif string.find(dir, "to top") then 270 else 0
	obj.BackgroundColor3 = Color3.new(1, 1, 1)
	obj.BackgroundTransparency = 0
	return true
end

export type Applied = { w: number?, h: number?, minH: number?, font: number?, text: Color3?, textT: number?, hidden: boolean }

-- the game's style object on a GUI object: colours, border, corners; sizes and text are returned for the caller
function Style.apply(obj: GuiObject, st: { [string]: string }?, widthPx: number?): Applied
	local out: Applied = { hidden = false }
	if st == nil then drop(obj, "Gradient"); return out end
	local bgc = st["background-color"]
	local bg = st.background or st["background-image"]
	local w = Html.px(st.width, 16) or Html.px(st["min-width"], 16)
	out.w = w
	out.h = Html.px(st.height, 16)
	out.minH = Html.px(st["min-height"] or st.minHeight, 16)
	out.font = Html.px(st["font-size"], 16)
	if not Style.gradient(obj, bg, w or widthPx) then
		local c, t = Html.color(bgc or bg)
		if c then
			obj.BackgroundColor3 = c
			obj.BackgroundTransparency = t
		end
	end
	if st.color then
		local c, t = Html.color(st.color)
		if c then out.text = c; out.textT = t end
	end
	local border = st.border or st["border-width"]
	if border or st["border-color"] then
		local px = if border then (Html.px(string.match(border, "[%d%.]+px") or border, 16) or 2) else 2
		if border and string.find(border, "none") then px = 0 end
		local c, t = Html.color(st["border-color"] or border)
		Style.stroke(obj, px, c or Style.TEXT, if c then t else 0)
	end
	local r = st["border-radius"]
	if r then
		local pct = string.match(r, "^%s*([%d%.]+)%%")
		if pct then Style.corner(obj, math.clamp((tonumber(pct) or 0) / 100, 0, 0.5))
		else Style.corner(obj, Html.px(r, 16)) end
	end
	if st.opacity then
		local o = tonumber(st.opacity)
		if o then obj.BackgroundTransparency = 1 - (1 - obj.BackgroundTransparency) * o end
	end
	if st.visibility == "hidden" or st.display == "none" then out.hidden = true end
	return out
end

return Style
