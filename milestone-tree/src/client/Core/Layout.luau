--!strict
--[[
	Layout: breakpoints and the UI scale (DESIGN.md 10), the ScreenGuis (plan 2.1), coordinate conversion (plan 2.9),
	the HUD-rect registry and the free / safe map rects.

	    Layout.mode ("WIDE" | "MEDIUM" | "COMPACT"), Layout.s, Layout.canvas (du), Layout.viewport (points)
	    Layout.changed                      viewport, Interface Size, PreferredTextSize (re-measure; s ignores it)
	    Layout.screen(name, order, insets)  a ScreenGui + its Root (UIScale s, sized V/s in offset; MapGui: none)
	    Layout.duToAbs(gui, p)              screen du from the device top-left -> abs space px
	    Layout.inputToAbs(p)                InputObject.Position -> abs space (the only such conversion)
	    Layout.setRect(key, r) / rects()    HUD rects for plate occlusion and marker push-out (abs space)
	    Layout.setSheet(sx) / free()        the map's free rect while a side sheet covers [sx, W)
	    Layout.safeStartRect()              the start-framing rect V' (without the top and bottom HUD bands)

	Abs space is the space of GuiObject.AbsolutePosition. Rects are { x, y, w, h } in it.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(script.Parent:WaitForChild("Signal"))
local Prefs = require(script.Parent:WaitForChild("Prefs"))

type ARect = Types.Rect

local Layout = {}

Layout.mode = "WIDE" :: string
Layout.s = 1
Layout.canvas = Vector2.new(1920, 1080)
Layout.viewport = Vector2.new(1920, 1080)
Layout.changed = Signal.new() :: Signal.Signal<>
Layout.rectsChanged = Signal.new() :: Signal.Signal<>

-- the HUD bands of the start framing and the free rect (DESIGN.md 3.3), in du
Layout.TOP_BAND = 100
Layout.TOP_BAND_COMPACT = 76
Layout.BOTTOM_BAND = 96
Layout.BOTTOM_BAND_COMPACT = 64
Layout.STRIP_MIN = 460 -- a side sheet whose map strip is narrower than this (du) goes full screen

-- ------------------------------------------------------------------------------------------------------ the formula
-- the smallest UI scale per mode: text never renders under the DESIGN.md 9.5 floors (Theme.size lifts the rest)
Layout.S_MIN = { COMPACT = 1.0, MEDIUM = 0.90, WIDE = 0.90 } :: { [string]: number }
-- DESIGN.md 10 verbatim. vw, vh: the viewport in points; userSize: .90 / 1 / 1.15. PreferredTextSize does not
-- change s: the engine enlarges text itself (DESIGN.md 9.5).
function Layout.compute(vw: number, vh: number, userSize: number?): (string, number, Vector2)
	local mode = if vh < 500 then "COMPACT" elseif vw < 1500 or vh < 860 then "MEDIUM" else "WIDE"
	local s
	if mode == "COMPACT" then
		s = math.clamp(vh / 390, 1.0, 1.3)
	elseif mode == "MEDIUM" then
		s = math.clamp(math.min(vw / 1600, vh / 900), 0.90, 1.0)
	else
		s = math.clamp(math.min(vw / 1920, vh / 1080), 0.90, 2.0)
	end
	s = math.max(s * (userSize or 1), Layout.S_MIN[mode])
	return mode, s, Vector2.new(vw / s, vh / s)
end
-- the map strip left of a side sheet that is too narrow keeps the sheet full screen (DESIGN.md 3.6)
function Layout.stripIsFull(stripDu: number, mode: string?): boolean
	return (mode or Layout.mode) == "COMPACT" or stripDu < Layout.STRIP_MIN
end

local function viewportSize(): Vector2
	local cam = Workspace.CurrentCamera
	if cam then
		local v = cam.ViewportSize
		if v.X > 1 and v.Y > 1 then return v end
	end
	return Vector2.new(1920, 1080)
end

type Screen = { gui: ScreenGui, root: Frame, scale: UIScale? }
local screens: { [string]: Screen } = {}

local function fitRoot(sc: Screen)
	if sc.scale == nil then return end
	local size = sc.gui.AbsoluteSize
	if size.X < 1 or size.Y < 1 then size = viewportSize() end
	local s = Layout.s
	sc.scale.Scale = s
	sc.root.Size = UDim2.fromOffset(math.floor(size.X / s + 0.5), math.floor(size.Y / s + 0.5))
end

-- the player's text size setting: s ignores it, but text frames re-measure when it changes (Layout.changed)
Layout.textSize = "Medium"
local function refresh()
	local v = viewportSize()
	local textSize = Layout.textSize
	pcall(function()
		textSize = GuiService.PreferredTextSize.Name
	end)
	local mode, s, canvas = Layout.compute(v.X, v.Y, Prefs.get().size / 100)
	local moved = mode ~= Layout.mode or math.abs(s - Layout.s) > 1e-6 or v ~= Layout.viewport or textSize ~= Layout.textSize
	Layout.mode, Layout.s, Layout.canvas, Layout.viewport, Layout.textSize = mode, s, canvas, v, textSize
	for _, sc in screens do fitRoot(sc) end
	if moved then Layout.changed:Fire() end
end
Layout.refresh = refresh

local started = false
local camConn: RBXScriptConnection? = nil
local function watchCamera()
	if camConn then camConn:Disconnect() end
	local cam = Workspace.CurrentCamera
	if cam then camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh) end
end
function Layout.start()
	if started then return end
	started = true
	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		refresh()
	end)
	pcall(function()
		GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(refresh)
	end)
	Prefs.changed:Connect(function(key: string)
		if key == "size" then refresh() end
	end)
	refresh()
end

-- ------------------------------------------------------------------------------------------------------ ScreenGuis
-- MapGui gets a full-screen black Root with no UIScale (REALM.md 9.1); every other Root carries UIScale s and is sized
-- in offset V / s. IgnoreGuiInset is never set (it rewrites ScreenInsets).
function Layout.screen(name: string, order: number, insets: Enum.ScreenInsets): (ScreenGui, Frame)
	Layout.start()
	local old = screens[name]
	if old and old.gui.Parent then return old.gui, old.root end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.AutoLocalize = false
	gui.DisplayOrder = order
	gui.ScreenInsets = insets
	if insets == Enum.ScreenInsets.None then
		pcall(function() gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None end)
	end
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BorderSizePixel = 0
	root.Active = false
	local sc: Screen = { gui = gui, root = root, scale = nil }
	if name == "MapGui" then
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundColor3 = Color3.new(0, 0, 0)
		root.BackgroundTransparency = 0
		root.ClipsDescendants = true
	else
		root.BackgroundTransparency = 1
		local u = Instance.new("UIScale")
		u.Name = "UIScale"
		u.Parent = root
		sc.scale = u
	end
	root.Parent = gui
	screens[name] = sc
	fitRoot(sc)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() fitRoot(sc) end)
	local lp = Players.LocalPlayer
	local pg = if lp then lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10) else nil
	gui.Parent = pg
	return gui, root
end
function Layout.getScreen(name: string): (ScreenGui?, Frame?)
	local sc = screens[name]
	if sc then return sc.gui, sc.root end
	return nil, nil
end

-- ------------------------------------------------------------------------------------------------------ coordinates
-- where the device's top-left corner is in abs space. MapGui (ScreenInsets None) covers the whole device, so its
-- Root's AbsolutePosition is exactly that; before it exists, the classic top inset is assumed.
function Layout.deviceOrigin(): Vector2
	local map = screens.MapGui
	if map and map.root.Parent then return map.root.AbsolutePosition end
	local ok, tl = pcall(function() return (GuiService:GetGuiInset()) end)
	if ok and typeof(tl) == "Vector2" then return Vector2.new(-tl.X, -tl.Y) end
	return Vector2.zero
end
-- screen du from the device top-left -> abs space px
function Layout.duToAbs(_gui: ScreenGui?, p: Vector2): Vector2
	return Layout.deviceOrigin() + p * Layout.s
end
-- abs space px -> the local offset space of a Root (which is sized in offset under its UIScale)
function Layout.absToLocal(root: GuiObject, p: Vector2): Vector2
	local d = p - root.AbsolutePosition
	local off = root.Size.X.Offset
	local k = if off > 0 and root.AbsoluteSize.X > 0 then root.AbsoluteSize.X / off else 1
	return d / k
end
-- InputObject.Position -> abs space. Roblox reports input positions without the top-bar inset, the same space as
-- AbsolutePosition (checked in Studio, plan 8 item 5), so this is the identity; keep every conversion here.
function Layout.inputToAbs(p: Vector2 | Vector3): Vector2
	if typeof(p) == "Vector3" then
		local v = p :: Vector3
		return Vector2.new(v.X, v.Y)
	end
	return p :: Vector2
end
-- the Roblox top-bar buttons area, abs space
function Layout.topbar(): ARect
	local o = Layout.deviceOrigin()
	local ok, r = pcall(function(): Rect return GuiService.TopbarInset end)
	if ok and typeof(r) == "Rect" then
		return { x = o.X + r.Min.X, y = o.Y + r.Min.Y, w = r.Width, h = r.Height }
	end
	return { x = o.X, y = o.Y, w = 0, h = 58 }
end

-- ------------------------------------------------------------------------------------------------------ HUD rects
local rectMap: { [string]: ARect } = {}
local rectList: { ARect }? = nil
function Layout.setRect(key: string, r: ARect?)
	local old = rectMap[key]
	if old and r and old.x == r.x and old.y == r.y and old.w == r.w and old.h == r.h then return end
	if old == nil and r == nil then return end
	rectMap[key] = r
	rectList = nil
	Layout.rectsChanged:Fire()
end
function Layout.rects(): { ARect }
	local l = rectList
	if l == nil then
		l = {}
		for _, r in rectMap do table.insert(l :: { ARect }, r) end
		rectList = l
	end
	return l :: { ARect }
end

-- ------------------------------------------------------------------------------------------------------ map rects
local sheetX: number? = nil
function Layout.setSheet(sx: number?)
	if sx == sheetX then return end
	sheetX = sx
	Layout.rectsChanged:Fire()
end
function Layout.sheet(): number?
	return sheetX
end
local function topBand(): number
	return (if Layout.mode == "COMPACT" then Layout.TOP_BAND_COMPACT else Layout.TOP_BAND) * Layout.s
end
local function bottomBand(): number
	return (if Layout.mode == "COMPACT" then Layout.BOTTOM_BAND_COMPACT else Layout.BOTTOM_BAND) * Layout.s
end
-- the free map rect F: the device screen (or the strip left of a side sheet) minus the top HUD band (abs space)
function Layout.free(): ARect
	local o = Layout.deviceOrigin()
	local v = Layout.viewport
	local right = if sheetX then sheetX - o.X else v.X
	local top = topBand()
	return { x = o.X, y = o.Y + top, w = math.max(1, right), h = math.max(1, v.Y - top) }
end
-- DESIGN.md 3.3 V': the screen (or strip) minus the top band and the bottom band (abs space)
function Layout.safeStartRect(): ARect
	local f = Layout.free()
	return { x = f.x, y = f.y, w = f.w, h = math.max(1, f.h - bottomBand()) }
end

return Layout
