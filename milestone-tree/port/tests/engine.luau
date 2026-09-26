--!nocheck
--[[
	The mock engine (tests/mock.luau) grown for the new client (App, the map, the HUD, the panel, the overlays): the
	datatypes with arithmetic and the engine's checks (sequence keypoints, tween goal types, text sizes, NaN), the
	extra instance events and defaults, the services' client side (TweenService, GuiService, ContentProvider,
	PreRender, UserInputService), and a builder for StarterPlayerScripts.MilestoneTree from the wrapped sources.

	    local E = require("./engine")(M)          once, right after requiring the mock
	    E.buildClient()                           -> the client Folder (every wrapped client file, listed by
	                                                 tools/wrap_scripts.py in data/wrap/files.luau)
	    E.runMain(name?)                          starts a LocalScript it built ("Main")
	    E.frames(seconds)                         steps time at 60 fps: due tasks, actor messages, PreRender, Heartbeat
	    E.tweens, E.warnings                      counters ([MilestoneTree] warnings count as failures in the tests)
	    E.Vector2, E.rtypeof
]]
return function(M)
local E = {}
local W = "../data/wrap/" -- relative to this file
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
local CLASS_ISA_GUI
local function viewport()
	local cam = M.game:GetService("Workspace").CurrentCamera
	return cam and rawget(cam, "__props").ViewportSize or V2(1920, 1080)
end
local function lazyDefaults(o, k)
	if k == "AbsoluteSize" then
		-- a ScreenGui covers the viewport; Scale sizes follow the parent (UIScale is not applied)
		if rawget(o, "__class") == "ScreenGui" then return viewport() end
		local s = rawget(o, "__props").Size
		if s then
			local parent = rawget(o, "__props").Parent
			local ps = if parent and (parent.__class == "ScreenGui" or CLASS_ISA_GUI[parent.__class]) then parent.AbsoluteSize else V2(400, 300)
			return V2(math.max(1, s.X.Offset + s.X.Scale * ps.X), math.max(1, s.Y.Offset + s.Y.Scale * ps.Y))
		end
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
CLASS_ISA_GUI = { Frame = true, ScrollingFrame = true, TextLabel = true, TextButton = true, ImageButton = true, TextBox = true,
	ImageLabel = true, CanvasGroup = true }
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
E.tweens = 0
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
	E.tweens += 1
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
-- a small real JSON (objects, arrays, strings, numbers, booleans, null), like the engine's: the device prefs round
-- trip (client -> Prefs remote -> the MT_Prefs attribute -> client) runs for real
local function jsonEncode(v)
	local t = type(v)
	if v == nil then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then
		assert(v == v and v ~= math.huge and v ~= -math.huge, "JSONEncode: a number that is not finite")
		return if v == math.floor(v) and math.abs(v) < 2 ^ 53 then string.format("%d", v) else string.format("%.17g", v)
	end
	if t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[c] or string.format("\\u%04x", string.byte(c))
		end) .. '"'
	end
	assert(t == "table", "JSONEncode: cannot encode a " .. t)
	if #v > 0 or next(v) == nil then
		local parts = {}
		for i = 1, #v do parts[i] = jsonEncode(v[i]) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do table.insert(keys, tostring(k)) end
	table.sort(keys)
	local parts = {}
	for _, k in keys do table.insert(parts, jsonEncode(k) .. ":" .. jsonEncode(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function jsonDecode(s)
	local i = 1
	local function ws() i = string.find(s, "[^ \t\r\n]", i) or #s + 1 end
	local value
	local function str()
		local out, j = {}, i + 1
		while true do
			local c = string.sub(s, j, j)
			assert(c ~= "", "JSONDecode: unterminated string")
			if c == '"' then break end
			if c == "\\" then
				local e = string.sub(s, j + 1, j + 1)
				if e == "u" then
					table.insert(out, utf8.char(tonumber(string.sub(s, j + 2, j + 5), 16)))
					j += 6
				else
					table.insert(out, ({ n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" })[e] or e)
					j += 2
				end
			else
				table.insert(out, c)
				j += 1
			end
		end
		i = j + 1
		return table.concat(out)
	end
	function value()
		ws()
		local c = string.sub(s, i, i)
		if c == "{" then
			local o = {}
			i += 1
			ws()
			if string.sub(s, i, i) == "}" then i += 1; return o end
			while true do
				ws()
				local k = str()
				ws()
				assert(string.sub(s, i, i) == ":", "JSONDecode: expected ':'")
				i += 1
				o[k] = value()
				ws()
				local d = string.sub(s, i, i)
				i += 1
				if d == "}" then return o end
				assert(d == ",", "JSONDecode: expected ',' or '}'")
			end
		elseif c == "[" then
			local a = {}
			i += 1
			ws()
			if string.sub(s, i, i) == "]" then i += 1; return a end
			while true do
				table.insert(a, value())
				ws()
				local d = string.sub(s, i, i)
				i += 1
				if d == "]" then return a end
				assert(d == ",", "JSONDecode: expected ',' or ']'")
			end
		elseif c == '"' then
			return str()
		elseif string.sub(s, i, i + 3) == "true" then i += 4; return true
		elseif string.sub(s, i, i + 4) == "false" then i += 5; return false
		elseif string.sub(s, i, i + 3) == "null" then i += 4; return nil
		end
		local num = string.match(s, "^-?%d+%.?%d*[eE]?[-+]?%d*", i)
		assert(num and num ~= "", "JSONDecode: unexpected '" .. c .. "' at " .. i)
		i += #num
		return tonumber(num)
	end
	local v = value()
	ws()
	assert(i > #s, "JSONDecode: trailing characters")
	return v
end
function HS:JSONDecode(s) return jsonDecode(s) end
function HS:JSONEncode(t) return jsonEncode(t) end
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
M.G.os = { clock = function() return M.now end, time = os.time, date = os.date }
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
E.warnings = 0
M.G.warn = function(...)
	local parts = table.pack(...)
	for i = 1, parts.n do parts[i] = tostring(parts[i]) end
	local s = table.concat(parts, " ")
	print("[warn] " .. s)
	if string.find(s, "MilestoneTree", 1, true) then E.warnings += 1 end
end
M.G.print = function(...) end

-- ------------------------------------------------------------------------------------------------------ audio
-- the wired Audio API (AudioPlayer, faders, Wire) and the legacy Sound: Play / Stop are methods only while
-- E.audio.api / E.audio.sound is on (off, Instance.new still works but the probes fail, like an engine without the
-- API). Every Play is logged in E.audio.plays { class, name, region, speed, volume, t }.
E.audio = { api = true, sound = true, plays = {}, stops = 0 }
local NRmt = { __index = function(_, k) error("NumberRange has no " .. tostring(k), 2) end }
M.G.NumberRange = { new = function(a, b)
	assert(type(a) == "number" and a == a, "NumberRange min")
	b = if b == nil then a else b
	assert(type(b) == "number" and b >= a, "NumberRange max < min")
	return typed("NumberRange", { Min = a, Max = b }, NRmt)
end }
local function audioPlay(self)
	local p = rawget(self, "__props")
	p.IsPlaying, p.Playing = true, true
	table.insert(E.audio.plays, { class = self.__class, name = p.Name, region = p.PlaybackRegion, loop = p.LoopRegion,
		speed = p.PlaybackSpeed, volume = p.Volume, t = M.now })
end
local function audioStop(self)
	local p = rawget(self, "__props")
	p.IsPlaying, p.Playing = false, false
	E.audio.stops += 1
end
local AUDIO_METHOD = { Play = audioPlay, Stop = audioStop, Pause = audioStop, Resume = audioPlay }
local AUDIO_CLASS = { AudioPlayer = "api", Sound = "sound" }
local indexBeforeAudio = Inst.__index
Inst.__index = function(o, k)
	local kind = AUDIO_CLASS[rawget(o, "__class")]
	if kind and AUDIO_METHOD[k] and E.audio[kind] then return AUDIO_METHOD[k] end
	if kind and (k == "IsPlaying" or k == "Playing") then
		local v = rawget(o, "__props")[k]
		return v == true
	end
	if k == "Connected" and rawget(o, "__class") == "Wire" then
		local p = rawget(o, "__props")
		return p.SourceInstance ~= nil and p.TargetInstance ~= nil
	end
	return indexBeforeAudio(o, k)
end
local SoundService = game:GetService("SoundService")
function SoundService:GetMixerTime() return M.now end


E.Vector2 = Vector2
E.rtypeof = rtypeof

-- ------------------------------------------------------------------------------------------------------ the client
function E.buildClient()
	local Instance = M.G.Instance
	local SP = game:GetService("StarterPlayer")
	local SPS = SP:FindFirstChild("StarterPlayerScripts")
	if SPS == nil then
		SPS = Instance.new("Folder"); SPS.Name = "StarterPlayerScripts"; SPS.Parent = SP
	end
	local RS = game:GetService("ReplicatedStorage")
	local shared = RS:FindFirstChild("MilestoneTree")
	if shared == nil then
		shared = Instance.new("Folder"); shared.Name = "MilestoneTree"; shared.Parent = RS
	end
	local function scriptModule(parent, name, wrapPath)
		local inst
		inst = M.module(parent, name, function() return M.withScript(inst, require(W .. wrapPath)) end)
		return inst
	end
	for _, pair in { { "Html", "shared/Html" } } do
		if shared:FindFirstChild(pair[1]) == nil then scriptModule(shared, pair[1], pair[2]) end
	end
	for _, n in { "Realm", "Assets", "ZoneMaps", "PrefsSchema", "Flags", "AudioIds", "NodeAtlas" } do
		if shared:FindFirstChild(n) == nil then
			M.module(shared, n, function() return require("../../src/shared/" .. n) end)
		end
	end
	local client = Instance.new("Folder"); client.Name = "MilestoneTree"; client.Parent = SPS
	local folders = {}
	local mains = {}
	for _, path in require(W .. "files") do
		if string.sub(path, 1, 7) == "client/" then
			local rest = string.sub(path, 8)
			local parent = client
			local parts = string.split(rest, "/")
			for i = 1, #parts - 1 do
				local key = table.concat(parts, "/", 1, i)
				local f = folders[key]
				if f == nil then
					f = Instance.new("Folder"); f.Name = parts[i]; f.Parent = parent
					folders[key] = f
				end
				parent = f
			end
			local name = parts[#parts]
			local cls = string.match(name, "%.(%a+)$")
			if cls == "client" then
				local ls = Instance.new("LocalScript"); ls.Name = string.gsub(name, "%.client$", ""); ls.Parent = parent
				mains[ls.Name] = { inst = ls, path = string.gsub(path, "%.client$", "") }
			else
				scriptModule(parent, name, path)
			end
		end
	end
	E.mains = mains
	return client
end

-- start a client LocalScript built by buildClient ("Main")
function E.runMain(name)
	local m = E.mains[name or "Main"]
	return M.runScript(m.inst, require(W .. m.path))
end

function E.frames(seconds)
	local RunService = game:GetService("RunService")
	local dt = 1 / 60
	local t = 0
	while t < seconds do
		M.now += dt
		t += dt
		M.runQueue()
		M.pump()
		RunService.PreRender:Fire(dt)
		RunService.Heartbeat:Fire(dt)
	end
end

return E
end
