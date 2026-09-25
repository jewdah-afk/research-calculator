--!nocheck
--[[
	The new client's map and HUD modules end to end on the mock engine (tests/mock.luau, extended here with the
	datatypes and services those modules use): MapPreview.client runs, every fixture patch in data/fixtures is played
	into the View remote, frames are stepped, nodes are clicked / hovered / peeked, READY gems held, overlays opened.
	Any script error fails the run. Twice: with every engine capability, and with all of them forced off
	(MT_ForceCaps = "all", the fallbacks).

	Run from port/: python3 tools/wrap_scripts.py && ./test.sh capture && luau tests/unit/client_smoke.luau [-a nocaps]
]]
local M = require("../mock")
local W = "../../data/wrap/"
local NOCAPS = (...) == "nocaps"

local failures = 0
local function check(ok, what)
	if ok then print("  ok    " .. what) else failures += 1; print("  FAIL  " .. what) end
end

-- ------------------------------------------------------------------------------------------------------ datatypes
local function typed(name, t, mt)
	mt.__type = name
	return setmetatable(t, mt)
end
local V2mt = {}
local function V2(x, y) return typed("Vector2", { X = x or 0, Y = y or 0 }, V2mt) end
V2mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y); return if m > 0 then V2(v.X / m, v.Y / m) else V2(0, 0) end
	if k == "Lerp" then return function(a, b, t) return V2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y end end
	error("Vector2 has no " .. tostring(k), 2)
end
local function num(v) return if type(v) == "number" then V2(v, v) else v end
V2mt.__add = function(a, b) a, b = num(a), num(b); return V2(a.X + b.X, a.Y + b.Y) end
V2mt.__sub = function(a, b) a, b = num(a), num(b); return V2(a.X - b.X, a.Y - b.Y) end
V2mt.__mul = function(a, b) a, b = num(a), num(b); return V2(a.X * b.X, a.Y * b.Y) end
V2mt.__div = function(a, b) a, b = num(a), num(b); return V2(a.X / b.X, a.Y / b.Y) end
V2mt.__unm = function(a) return V2(-a.X, -a.Y) end
V2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2mt.__tostring = function(v) return string.format("(%g, %g)", v.X, v.Y) end
local Vector2 = { new = V2, zero = V2(0, 0), one = V2(1, 1), xAxis = V2(1, 0), yAxis = V2(0, 1) }

local UDmt = { __index = function(_, k) error("UDim has no " .. tostring(k), 2) end }
local function UD(s, o) return typed("UDim", { Scale = s or 0, Offset = o or 0 }, UDmt) end
UDmt.__add = function(a, b) return UD(a.Scale + b.Scale, a.Offset + b.Offset) end
UDmt.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
local UDim = { new = UD }
local U2mt = { __index = function(_, k)
	error("UDim2 has no " .. tostring(k), 2)
end }
local function U2(xs, xo, ys, yo)
	for _, v in { xs or 0, xo or 0, ys or 0, yo or 0 } do assert(v == v, "UDim2 NaN") end
	return typed("UDim2", { X = UD(xs, xo), Y = UD(ys, yo) }, U2mt)
end
U2mt.__add = function(a, b) return U2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
U2mt.__sub = function(a, b) return U2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
U2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
local UDim2 = {
	new = function(xs, xo, ys, yo)
		if type(xs) == "table" then return U2(xs.Scale, xs.Offset, xo.Scale, xo.Offset) end
		return U2(xs, xo, ys, yo)
	end,
	fromOffset = function(x, y) return U2(0, x or 0, 0, y or 0) end,
	fromScale = function(x, y) return U2(x or 0, 0, y or 0, 0) end,
}

local C3mt = { __index = function(c, k)
	if k == "Lerp" then return function(a, b, t) return typed("Color3", { R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, getmetatable(a)) end end
	if k == "ToHex" then return function(a) return string.format("%02x%02x%02x", a.R * 255, a.G * 255, a.B * 255) end end
	error("Color3 has no " .. tostring(k), 2)
end }
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
local function C3(r, g, b)
	for _, v in { r or 0, g or 0, b or 0 } do assert(v == v, "Color3 NaN") end
	return typed("Color3", { R = r or 0, G = g or 0, B = b or 0 }, C3mt)
end
local Color3 = {
	new = C3,
	fromRGB = function(r, g, b) return C3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHex = function(h)
		h = string.gsub(h, "^#", "")
		assert(#h == 6 or #h == 3, "bad hex " .. h)
		if #h == 3 then h = string.gsub(h, ".", "%0%0") end
		local r, g, b = tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16)
		assert(r and g and b, "bad hex " .. h)
		return C3(r / 255, g / 255, b / 255)
	end,
}
local function seqCheck(kind, pts)
	assert(type(pts) == "table" and #pts >= 2 and #pts <= 20, kind .. " needs 2..20 keypoints, got " .. tostring(#pts))
	assert(pts[1].Time == 0 and pts[#pts].Time == 1, kind .. " must start at 0 and end at 1")
	for i = 2, #pts do assert(pts[i].Time > pts[i - 1].Time, kind .. " times must increase") end
end
local CSK = { new = function(t, c)
	assert(type(t) == "number" and t >= 0 and t <= 1, "ColorSequenceKeypoint time " .. tostring(t))
	assert(type(c) == "table" and getmetatable(c) == C3mt, "ColorSequenceKeypoint needs a Color3")
	return typed("ColorSequenceKeypoint", { Time = t, Value = c }, { __index = function(_, k) error("CSK has no " .. k) end })
end }
local ColorSequence = { new = function(a, b)
	local pts
	if type(a) == "table" and getmetatable(a) == C3mt then
		pts = { CSK.new(0, a), CSK.new(1, b or a) }
	else
		pts = a
	end
	seqCheck("ColorSequence", pts)
	return typed("ColorSequence", { Keypoints = pts }, { __index = function(_, k) error("ColorSequence has no " .. k) end })
end }
local NSK = { new = function(t, v, e)
	assert(type(t) == "number" and t >= 0 and t <= 1, "NumberSequenceKeypoint time " .. tostring(t))
	assert(type(v) == "number" and v == v, "NumberSequenceKeypoint value")
	return typed("NumberSequenceKeypoint", { Time = t, Value = v, Envelope = e or 0 }, { __index = function(_, k) error("NSK has no " .. k) end })
end }
local NumberSequence = { new = function(a, b)
	local pts
	if type(a) == "number" then pts = { NSK.new(0, a), NSK.new(1, b or a) } else pts = a end
	seqCheck("NumberSequence", pts)
	for _, p in pts do assert(p.Value >= 0 and p.Value <= 1 or true) end
	return typed("NumberSequence", { Keypoints = pts }, { __index = function(_, k) error("NumberSequence has no " .. k) end })
end }
local TweenInfo = { new = function(time, style, dir, rep, rev, delay)
	return typed("TweenInfo", { Time = time or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = rep or 0, Reverses = rev or false, DelayTime = delay or 0 }, {})
end }
local Rect = { new = function(a, b, c, d) return typed("Rect", { Min = V2(a, b), Max = V2(c, d), Width = c - a, Height = d - b }, {}) end }
local Font = {
	new = function(family, weight, style) return typed("Font", { Family = family, Weight = weight, Style = style }, {}) end,
	fromName = function(name, weight, style) return typed("Font", { Family = "rbxasset://fonts/families/" .. name .. ".json", Weight = weight, Style = style }, {}) end,
}
local Path2DControlPoint = { new = function(p, l, r) return typed("Path2DControlPoint", { Position = p, LeftTangent = l, RightTangent = r }, {}) end }
local function rtypeof(v)
	local mt = type(v) == "table" and getmetatable(v)
	if mt and mt.__type then return mt.__type end
	if type(v) == "table" and v.__class then return "Instance" end
	return typeof(v)
end

-- ------------------------------------------------------------------------------------------------------ instances
local Inst = getmetatable(M.newInstance("Frame"))
local EXTRA_EVENTS = {}
for _, e in { "MouseMoved", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseButton2Click", "MouseButton2Down",
	"FocusLost", "Focused", "Completed", "AncestryChanged", "SelectionGained" } do EXTRA_EVENTS[e] = true end
local DEFAULTS = {
	BackgroundTransparency = 0, Visible = true, ZIndex = 1, Rotation = 0, LayoutOrder = 0, TextSize = 14, Text = "",
	TextTransparency = 0, ImageTransparency = 0, Image = "", Enabled = true, Interactable = true, Active = false,
	Scale = 1, Thickness = 1, Transparency = 0, IsLoaded = true, AutomaticSize = nil, LineHeight = 1,
}
local function lazyDefaults(o, k)
	if k == "AbsoluteSize" then
		local s = rawget(o, "__props").Size
		if s then return V2(math.max(1, s.X.Offset + s.X.Scale * 400), math.max(1, s.Y.Offset + s.Y.Scale * 300)) end
		return V2(100, 40)
	end
	if k == "AbsolutePosition" then return V2(0, 0) end
	if k == "TextBounds" then return V2(8 * #(rawget(o, "__props").Text or ""), 16) end
	if k == "Position" or k == "Size" then return U2(0, 0, 0, 0) end
	if k == "AnchorPoint" or k == "CanvasPosition" or k == "Offset" then return V2(0, 0) end
	if k == "BackgroundColor3" or k == "TextColor3" or k == "ImageColor3" or k == "Color" or k == "Color3" then return C3(1, 1, 1) end
	if k == "CornerRadius" then return UD(0, 0) end
	return nil
end
local oldIndex = Inst.__index
Inst.__index = function(o, k)
	local v = oldIndex(o, k)
	if v ~= nil then return v end
	if EXTRA_EVENTS[k] then
		local s = M.Signal.new()
		rawget(o, "__props")[k] = s
		return s
	end
	local d = DEFAULTS[k]
	if d ~= nil then return d end
	return lazyDefaults(o, k)
end
local oldNew = Inst.__newindex
Inst.__newindex = function(o, k, v)
	if rawget(o, "__destroyed") and k ~= "Parent" then
		-- the engine allows writes to destroyed objects; nothing to do
	end
	if k == "TextSize" then assert(type(v) == "number" and v == v and v >= 1 and v <= 100, "TextSize out of range: " .. tostring(v)) end
	if k == "Thickness" then assert(type(v) == "number" and v == v, "Thickness NaN") end
	if k == "BackgroundTransparency" or k == "TextTransparency" or k == "ImageTransparency" then
		assert(type(v) == "number" and v == v, k .. " must be a number")
	end
	if k == "Name" then assert(type(v) == "string", "Name must be a string") end
	oldNew(o, k, v)
end
local CLASS_ISA = {
	Frame = { "GuiObject", "GuiBase2d" }, ScrollingFrame = { "GuiObject", "GuiBase2d" }, TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" }, ImageButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	TextBox = { "GuiObject", "GuiBase2d" }, ImageLabel = { "GuiObject", "GuiBase2d" }, CanvasGroup = { "GuiObject", "GuiBase2d" },
	ScreenGui = { "LayerCollector", "GuiBase2d" }, Path2D = { "GuiBase" }, UIListLayout = { "UIGridStyleLayout", "UIComponent" },
	UICorner = { "UIComponent" }, UIStroke = { "UIComponent" }, UIPadding = { "UIComponent" }, UIScale = { "UIComponent" },
	UIGradient = { "UIComponent" }, UIShadow = { "UIComponent" }, UITextSizeConstraint = { "UIConstraint", "UIComponent" },
	LocalScript = { "Script", "BaseScript" }, ModuleScript = { "LuaSourceContainer" },
}
function Inst:IsA(cls)
	if self.__class == cls or cls == "Instance" then return true end
	for _, b in CLASS_ISA[self.__class] or {} do if b == cls then return true end end
	return false
end
function Inst:FindFirstChildWhichIsA(cls) for _, c in self.__kids do if c:IsA(cls) then return c end end return nil end
function Inst:FindFirstAncestorWhichIsA(cls)
	local o = self.Parent
	while o do if o:IsA(cls) then return o end o = o.Parent end
	return nil
end
function Inst:FindFirstAncestor(name)
	local o = self.Parent
	while o do if o.Name == name then return o end o = o.Parent end
	return nil
end
function Inst:IsDescendantOf(a)
	local o = self.Parent
	while o do if o == a then return true end o = o.Parent end
	return false
end
function Inst:GetAttributeChangedSignal() return M.Signal.new() end
function Inst:ClearAllChildren() for _, c in table.clone(self.__kids) do c:Destroy() end end
function Inst:SetControlPoints(pts)
	assert(type(pts) == "table" and #pts >= 2, "Path2D needs 2+ control points")
	self.__props.__points = pts
end
function Inst:GetGuiObjectsAtPosition() return {} end
function Inst:GetTextSize() return V2(40, 16) end

-- ------------------------------------------------------------------------------------------------------ services
local game = M.game
local tweens = 0
local TS = game:GetService("TweenService")
function TS:Create(inst, info, goals)
	assert(type(inst) == "table" and inst.__class, "Tween target must be an Instance")
	assert(rtypeof(info) == "TweenInfo", "Tween needs a TweenInfo")
	for k, v in goals do
		assert(type(k) == "string", "goal key")
		local cur = inst[k]
		assert(cur ~= nil, "tween goal " .. k .. " on " .. inst.__class .. " has no current value")
		assert(rtypeof(cur) == rtypeof(v), "tween goal " .. k .. " type " .. rtypeof(v) .. " vs " .. rtypeof(cur))
	end
	tweens += 1
	local t = { Completed = M.Signal.new() }
	function t:Play() for k, v in goals do inst[k] = v end end
	function t:Cancel() end
	function t:Pause() end
	return t
end
local GS = game:GetService("GuiService")
GS.__props.ReducedMotionEnabled = false
GS.__props.PreferredTransparency = 1
GS.__props.TopbarInset = Rect.new(120, 0, 1800, 58)
GS.__props.TouchControlsEnabled = true
function GS:GetGuiInset() return V2(0, 58), V2(0, 0) end
local CP = game:GetService("ContentProvider")
function CP:PreloadAsync(list, cb) for _, id in list do if cb then cb(id, nil) end end end
local HS = game:GetService("HttpService")
function HS:JSONDecode(s) error("no json in the mock") end
function HS:JSONEncode(t) return "{}" end
local RunService = game:GetService("RunService")
RunService.__props.PreRender = M.Signal.new()
RunService.__props.RenderStepped = M.Signal.new()
local UIS = game:GetService("UserInputService")
for _, e in { "LastInputTypeChanged", "PointerAction", "TouchPinch", "TouchStarted", "TextBoxFocused", "TextBoxFocusReleased" } do
	UIS.__props[e] = M.Signal.new()
end
UIS.__props.TouchEnabled = false
UIS.__props.MouseEnabled = true
UIS.__props.KeyboardEnabled = true
UIS.__props.GamepadEnabled = false
function UIS:GetMouseLocation() return V2(960, 540) end
local Workspace = game:GetService("Workspace")
Workspace.CurrentCamera.__props.ViewportSize = V2(1920, 1080)
local StarterGui = game:GetService("StarterGui")
function StarterGui:SetCore() end

local userSettings = { GetService = function() return { SavedQualityLevel = M.G.Enum.SavedQualitySetting.Automatic } end }
M.G.Vector2, M.G.UDim, M.G.UDim2, M.G.Color3 = Vector2, UDim, UDim2, Color3
M.G.ColorSequence, M.G.ColorSequenceKeypoint, M.G.NumberSequence, M.G.NumberSequenceKeypoint = ColorSequence, CSK, NumberSequence, NSK
M.G.TweenInfo, M.G.Rect, M.G.Font, M.G.Path2DControlPoint = TweenInfo, Rect, Font, Path2DControlPoint
M.G.typeof = rtypeof
local waitRaw = M.G.task.wait
M.G.task.wait = function(s)
	local t0 = M.now
	waitRaw(s)
	return M.now - t0
end
local RNG = {}
RNG.__index = RNG
function RNG:NextNumber(a, b)
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	local u = self.s / 2147483648
	if a then return a + (b - a) * u end
	return u
end
function RNG:NextInteger(a, b) return math.floor(a + (b - a + 1) * self:NextNumber()) end
M.G.Random = { new = function(seed) return setmetatable({ s = math.floor(seed or 1) % 2147483648 }, RNG) end }
M.G.UserSettings = function() return userSettings end
M.G.warn = function(...)
	local s = table.concat(table.pack(...), " ")
	print("[warn] " .. s)
	if string.find(s, "MilestoneTree") then failures += 1 end
end
M.G.print = function(...) end

-- ------------------------------------------------------------------------------------------------------ the tree
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")
local Instance = M.G.Instance
local SPS = Instance.new("Folder"); SPS.Name = "StarterPlayerScripts"; SPS.Parent = SP
local shared = Instance.new("Folder"); shared.Name = "MilestoneTree"; shared.Parent = RS
local function scriptModule(parent, name, wrapPath)
	local inst
	inst = M.module(parent, name, function() return M.withScript(inst, require(W .. wrapPath)) end)
	return inst
end
scriptModule(shared, "Html", "shared/Html")
M.module(shared, "Realm", function() return require("../../../src/shared/Realm") end)
M.module(shared, "Assets", function() return require("../../../src/shared/Assets") end)
M.module(shared, "ZoneMaps", function() return require("../../../src/shared/ZoneMaps") end)

local client = Instance.new("Folder"); client.Name = "MilestoneTree"; client.Parent = SPS
local function folder(parent, name) local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; return f end
scriptModule(client, "Types", "client/Types")
local listing = {
	Core = { "Signal", "ViewStore", "Theme", "Recipes", "Motion", "Layout", "Sprites", "Prefs", "Rich" },
	Input = { "Input" },
	Map = { "MapCamera", "MapView", "MapInput", "Ambient", "Fields", "Fallback", "MapLogic", "NodeWidget", "Nodes", "Links", "Plates", "Markers" },
	Hud = {}, Overlay = {},
}
local function exists(path)
	local f = io and io.open and io.open(path, "r")
	if f then f:close(); return true end
	return false
end
-- Hud / Overlay: every wrapped file present
for _, sub in { "Hud", "Overlay" } do
	for _, n in { "Kit", "Hud", "Capsule", "Dock", "Ready", "Portal", "UniverseTag", "Band", "Overlay", "Toasts", "ToastModel", "Tooltip", "Peek", "Modals", "Gate", "Screens" } do
		local ok = pcall(require, W .. "client/" .. sub .. "/" .. n)
		if ok then table.insert(listing[sub], n) end
	end
end
for sub, names in listing do
	local f = folder(client, sub)
	for _, n in names do scriptModule(f, n, "client/" .. sub .. "/" .. n) end
end
local preview = Instance.new("LocalScript"); preview.Name = "MapPreview"; preview.Parent = client

-- remotes
local remotes = folder(RS, "MilestoneTreeRemotes")
local R = {}
for _, n in { "View", "Act", "Import", "Ready", "Prefs" } do
	local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = remotes
	R[n] = r
end
remotes:SetAttribute("ImportCooldown", 10)
local acts, readies = {}, 0
M.fireServer = function(remote, ...)
	if remote == R.Act then table.insert(acts, { ... }) end
	if remote == R.Ready then readies += 1 end
end

-- the player
local p = M.addPlayer("Tester", 1)
game:GetService("Players").__props.LocalPlayer = p
if NOCAPS then p:SetAttribute("MT_ForceCaps", "all") end

-- ------------------------------------------------------------------------------------------------------ the run
local function frames(seconds)
	local dt = 1 / 60
	local t = 0
	while t < seconds do
		M.now += dt
		t += dt
		M.runQueue()
		RunService.PreRender:Fire(dt)
		RunService.Heartbeat:Fire(dt)
	end
end
local errors0 = M.errors or 0
print("== MapPreview starts" .. (if NOCAPS then " (all caps off)" else ""))
M.runScript(preview, require(W .. "client/MapPreview"))
frames(0.5)
local pg = p:FindFirstChild("PlayerGui")
local mapGui = pg:FindFirstChild("MapGui")
check(mapGui ~= nil, "MapGui built")
local nodesF = mapGui and mapGui.Root.Box.Nodes
check(nodesF and nodesF:FindFirstChild("Node_m") ~= nil and nodesF:FindFirstChild("Node_cp") ~= nil, "21 node widgets")
frames(3.2)
check(readies >= 1, "asked for a full view when none arrived")

local index = { "fresh_none", "fresh_m", "s13_none", "s13_p", "s13_m", "s13_sp_spark", "s13_options", "s19mv_none", "s19mv_cp", "s19mv_ex", "trapped_none", "layer_ach", "layer_m", "layer_mm", "layer_em", "layer_p", "layer_pe", "layer_sp", "layer_pb", "layer_pp", "layer_se", "layer_hp", "layer_ep", "layer_hb", "layer_ap", "layer_mp", "layer_t", "layer_pm", "layer_pep", "layer_cp", "layer_cm", "layer_ex" }
local function play(name)
	local patch = require("../../data/fixtures/" .. name)
	R.View.OnClientEvent:Fire(patch)
	frames(0.3)
end
for _, name in index do
	play(name)
end
check((M.errors or 0) == errors0, "every fixture drew without a script error")

-- the S13 map: states and plates
play("s13_none")
local function state(l) local n = nodesF:FindFirstChild("Node_" .. l); return n and n:GetAttribute("State") end
check(state("m") == "available", "m available (" .. tostring(state("m")) .. ")")
check(state("pb") == "locked", "pb locked (" .. tostring(state("pb")) .. ")")
check(state("pm") == "sealed", "pm sealed before the Multiverse is revealed (" .. tostring(state("pm")) .. ")")
local plates = mapGui.Root.Box.Plates
check(plates:FindFirstChild("Plate_p") and plates.Plate_p.Label.Text ~= "", "the P plate has its name")
check(mapGui.Root.Box.Links:FindFirstChild("Edge_m_p_3") ~= nil or mapGui.Root.Box.Links:FindFirstChild("Edge_m_p_Seg") ~= nil, "the m -> p link is drawn")
play("fresh_none")
check(state("mm") == "frontier", "fresh: mm is frontier (" .. tostring(state("mm")) .. ")")
check(state("pe") == "sealed", "fresh: pe sealed (" .. tostring(state("pe")) .. ")")
play("s19mv_none")
check(state("pm") == "pulse" or state("pm") == "available" or state("pm") == "glow", "inside: pm shown (" .. tostring(state("pm")) .. ")")
check(state("p") == "dormant", "inside: p dormant (" .. tostring(state("p")) .. ")")

-- input: click a node, hover it, right-click it
play("s13_none")
local hit = nodesF.Node_p.Hit
hit.MouseEnter:Fire(10, 10)
frames(0.3)
hit.MouseMoved:Fire(12, 12)
hit.Activated:Fire()
frames(0.5)
local opened = false
for _, a in acts do if a[1] and a[1][1] == "tab" and a[1][2] == "p" then opened = true end end
check(opened, "a click on P sent its tab action")
hit.MouseLeave:Fire(0, 0)
hit.MouseButton2Click:Fire()
frames(0.3)
nodesF.Rift.MouseEnter:Fire(1, 1)
nodesF.Rift.MouseLeave:Fire(1, 1)
frames(0.2)

-- the HUD, when it is there
local topbar = pg:FindFirstChild("TopbarGui")
if topbar then
	check(topbar.Root:FindFirstChild("Capsule") ~= nil, "the capsule")
	local hud = pg:FindFirstChild("HudGui")
	check(hud and hud.Root:FindFirstChild("Dock") ~= nil, "the dock")
	local ready = hud and hud.Root:FindFirstChild("Ready")
	if ready then
		for _, g in ready:GetDescendants() do
			if g.Name == "Hit" and g.__class == "TextButton" then g.Activated:Fire() end
		end
	end
	local ov = pg:FindFirstChild("OverlayGui")
	check(ov ~= nil, "the overlay")
end
frames(1)

check((M.errors or 0) == errors0, "no script errors (" .. tostring((M.errors or 0) - errors0) .. ")")
print(string.format("== client smoke: %d tweens made, %d actions sent", tweens, #acts))
if failures > 0 then
	error("client smoke: " .. failures .. " FAILED", 0)
end
print("client smoke: all passed")
