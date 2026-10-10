--!nonstrict
-- Describe: the description card for every interactive thing (owner 2026-10-10: "descriptions for all").
--   * one card, built once, on its own ScreenGui above every window; styled like the game's plates (steel gradient,
--     4 px ink outline, Fredoka One, 1.2 outline text): TITLE / body line / optional stat line in gold
--   * desktop: hover 0.25 s; touch: long-press 0.4 s (a normal tap still clicks and shows nothing); gamepad: shows
--     while the key is selected. A press, leaving, scrolling or a window change hides it.
--   * Render attaches every btn/ tab/ seg/ by layer name (UI/Descriptions); data rows call Describe.set(inst, spec)
--     with their Defs text. spec = { title, body, stat? } or a function returning one (live values), or nil = none.
-- Never shows over an open window from outside it, never on disabled reduced-information builds (Describe.enabled).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Descriptions = require(script.Parent.Descriptions)

local Describe = {}
Describe.enabled = true
local INK = Color3.fromHex("0b0c10")
local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local GOLD = Color3.fromHex("ffd36b")
local MAXW = 320
local HOVER_DELAY, HOLD_DELAY = 0.25, 0.4

local specs = setmetatable({}, { __mode = "k" })   -- GuiObject -> spec
local gui, card, titleL, bodyL, statL, scaleObj
local shownFor, token = nil, 0

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function label(name, size, color, order, parent)
	local l = new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = FONT, TextSize = size, TextColor3 = color,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order, Text = "" }, parent)
	new("UIStroke", { Thickness = 1.2, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }, l)
	return l
end
local function build()
	if card then return end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = new("ScreenGui", { Name = "PeckwoodDescribe", DisplayOrder = 950, IgnoreGuiInset = true, ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)
	card = new("Frame", { Name = "card", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0) }, gui)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("3a4455"), Color3.fromHex("1f2530")) }, card)
	new("UIStroke", { Thickness = 4, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	new("UISizeConstraint", { MaxSize = Vector2.new(MAXW, 400) }, card)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 10) }, card)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, card)
	-- top highlight: the same single 2 px line every window header uses
	local hi = new("Frame", { Name = "top highlight", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.65, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 0 }, card)
	hi:SetAttribute("decor", true)
	titleL = label("title", 18, Color3.new(1, 1, 1), 1, card)
	bodyL = label("body", 15, Color3.fromHex("d6dce8"), 2, card)
	statL = label("stat", 15, GOLD, 3, card)
	scaleObj = new("UIScale", { Scale = 1 }, card)
end

local function resolve(spec)
	if type(spec) == "function" then local ok, v = pcall(spec); spec = ok and v or nil end
	if type(spec) == "string" then return { body = spec } end
	return spec
end

-- place the card above the GuiObject (below when there is no room), clamped to the screen
local function place(inst)
	local vp = workspace.CurrentCamera.ViewportSize
	local inset = GuiService:GetGuiInset()
	local p, s = inst.AbsolutePosition + inset, inst.AbsoluteSize
	local cs = card.AbsoluteSize
	local x = math.clamp(p.X + s.X / 2 - cs.X / 2, 8, vp.X - cs.X - 8)
	local y = p.Y - cs.Y - 10
	if y < 8 then y = p.Y + s.Y + 10 end
	card.Position = UDim2.fromOffset(x, math.clamp(y, 8, vp.Y - cs.Y - 8))
end

function Describe.show(inst)
	if not Describe.enabled then return end
	local spec = resolve(specs[inst])
	if not spec or not (spec.title or spec.body) then return end
	build()
	token += 1
	shownFor = inst
	titleL.Text = spec.title or ""; titleL.Visible = spec.title ~= nil and spec.title ~= ""
	bodyL.Text = spec.body or ""; bodyL.Visible = spec.body ~= nil and spec.body ~= ""
	statL.Text = spec.stat or ""; statL.Visible = spec.stat ~= nil and spec.stat ~= ""
	card.Visible = true
	place(inst)
	task.defer(function() if shownFor == inst then place(inst) end end)   -- AutomaticSize settles one frame later
	-- a quick 0.94 -> 1 settle (UI only: the keys themselves never squash)
	scaleObj.Scale = 0.94
	TweenService:Create(scaleObj, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
function Describe.hide(inst)
	if inst and shownFor ~= inst then return end
	token += 1
	shownFor = nil
	if card then card.Visible = false end
end

-- attach hover / long-press / gamepad to a key's hit button
local wired = setmetatable({}, { __mode = "k" })
local function wire(inst, hit)
	if wired[inst] or not hit then return end
	wired[inst] = true
	local function later(delay)
		token += 1
		local t = token
		task.delay(delay, function() if t == token and hit.Parent and hit.Visible then Describe.show(inst) end end)
	end
	hit.MouseEnter:Connect(function() later(HOVER_DELAY) end)
	hit.MouseLeave:Connect(function() Describe.hide(inst); token += 1 end)
	hit.MouseButton1Down:Connect(function() Describe.hide(inst); token += 1 end)
	hit.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch then later(HOLD_DELAY) end
	end)
	hit.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch then token += 1; task.delay(1.6, function() Describe.hide(inst) end) end
	end)
	hit.SelectionGained:Connect(function() later(HOVER_DELAY) end)
	hit.SelectionLost:Connect(function() Describe.hide(inst); token += 1 end)
end

-- spec for a GuiObject (data rows, live values); hit defaults to the key's "hit" button
function Describe.set(inst, spec, hit)
	specs[inst] = spec
	wire(inst, hit or inst:FindFirstChild("hit", true))
end

-- the Figma layer name -> description (btn/ tab/ seg/ ; "(state)" suffixes ignored; tab labels may carry counts)
function Describe.lookup(layerName: string)
	local kind, name = string.match(layerName, "^(%a+)/(.+)$")
	if not kind then return nil end
	name = string.gsub(name, "%s*%b()$", "")
	if kind == "btn" then
		local body = Descriptions.keys[name]
		return body and { body = body }
	elseif kind == "tab" or kind == "seg" then
		local t = if kind == "tab" then Descriptions.tabs else Descriptions.segs
		local body = t[name] or t[string.match(name, "^(%a[%a ]-)%s*[%d·]") or ""] or t[string.match(name, "^(%a+)") or ""]
		return body and { title = string.upper((string.gsub(name, "%s+%d+$", ""))), body = body }
	end
	return nil
end
function Describe.attachByName(inst, layerName, hit)
	local spec = Describe.lookup(layerName)
	if spec then Describe.set(inst, spec, hit) end
end

-- hide when anything big happens (window open / close / tab change call this)
function Describe.clear() Describe.hide(nil) end

return Describe
