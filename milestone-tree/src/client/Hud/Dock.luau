--!strict
--[[
	Dock: HOME / TROPHIES / OPTIONS at the bottom left (DESIGN.md 4.4) and the zoom capsule after it (mouse only).

	    Dock      Home, Trophies (+ Badge "13/18"), Options (+ Dot while the server cannot save): ImageButtons with the
	              hue bevel, a glyph with a hard shadow, the caption pill below (`label`, Title Case)
	    Zoom      glass: Minus, Pct ("51%", `number`), Plus

	    local part = Dock.new(parent)
	    part:setTrophies(text?)  part:setUnsaved(b)  part:setActive(key?)  part:setZoomPct(z)  part:setCompactStrip(...)
	    part.home, part.trophies, part.options, part.zoomIn, part.zoomOut   ()
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Input = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("Input"))
local Kit = require(script.Parent:WaitForChild("Kit"))

export type Dock = {
	frame: Frame,
	zoom: Frame,
	home: Signal.Signal<>,
	trophies: Signal.Signal<>,
	options: Signal.Signal<>,
	zoomIn: Signal.Signal<>,
	zoomOut: Signal.Signal<>,
	changed: Signal.Signal<>,
	setTrophies: (self: Dock, text: string?) -> (),
	setUnsaved: (self: Dock, b: boolean) -> (),
	setActive: (self: Dock, key: string?) -> (),
	setZoomPct: (self: Dock, z: number) -> (),
	setZoomVisible: (self: Dock, b: boolean) -> (),
	setSmall: (self: Dock, b: boolean) -> (), -- 56 du buttons while a side sheet is open
	destroy: (self: Dock) -> (),
}

local Dock = {}

local BUTTONS = {
	{ key = "Home", caption = "Home", hue = Color3.fromHex("2fcf8f"), glyph = "home" },
	{ key = "Trophies", caption = "Trophies", hue = Color3.fromHex("ffb020"), glyph = "star" },
	{ key = "Options", caption = "Options", hue = Color3.fromHex("8a7cff"), glyph = "gear" },
}

function Dock.new(parent: GuiObject): Dock
	local self = {} :: Dock
	self.home = Signal.new() :: Signal.Signal<>
	self.trophies = Signal.new() :: Signal.Signal<>
	self.options = Signal.new() :: Signal.Signal<>
	self.zoomIn = Signal.new() :: Signal.Signal<>
	self.zoomOut = Signal.new() :: Signal.Signal<>
	self.changed = Signal.new() :: Signal.Signal<>

	local f = Kit.frame(parent, "Dock", 5)
	f.AnchorPoint = Vector2.new(0, 1)
	self.frame = f
	local small = false
	local active: string? = nil
	local buttons: { [string]: ImageButton } = {}
	local captions: { [string]: Frame } = {}

	for i, spec in BUTTONS do
		local b = Kit.child(f, spec.key, "ImageButton") :: ImageButton
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 0
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Image = ""
		b.ZIndex = 3
		Kit.corner(b, UDim.new(0.25, 0))
		local c = spec.hue
		Kit.grad(b, { Theme.lift(c, 0.2), c, Theme.shade(c, 0.55) }, 90, nil, "Back", { 0, 0.55, 1 })
		Kit.stroke(b, 2.5, Theme.lift(c, 0.55), 1, "Rim")
		local lip = Kit.frame(b, "Lip", 4)
		lip.Size = UDim2.fromScale(1, 1)
		lip.BackgroundColor3 = Color3.new(1, 1, 1)
		lip.BackgroundTransparency = 0
		Kit.corner(lip, UDim.new(0.25, 0))
		Kit.grad(lip, { Color3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 90,
			{ { 0, 0.3 }, { 0.14, 0 }, { 0.8, 0 }, { 1, 0.35 } }, "Lips", { 0, 0.5, 0.51, 1 })
		local shadow = Kit.glyph(b, "IconShadow", spec.glyph, Color3.new(0, 0, 0), Theme.shade(c, 0.75))
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.new(0.5, 0, 0.5, 2)
		shadow.Size = UDim2.fromScale(0.48, 0.48)
		shadow.ZIndex = 5
		for _, d in shadow:GetDescendants() do
			if d:IsA("GuiObject") then d.BackgroundTransparency = 0.6 end
		end
		local icon = Kit.glyph(b, "Icon", spec.glyph, Color3.new(1, 1, 1), c)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.48, 0.48)
		icon.ZIndex = 6
		local press = Kit.child(b, "Press", "UIScale") :: UIScale
		b.MouseButton1Down:Connect(function()
			Motion.tween(press, TweenInfo.new(0.08), { Scale = 0.94 }, "dockPress" .. spec.key, true)
		end)
		b.MouseButton1Up:Connect(function()
			Motion.tween(press, TweenInfo.new(0.12), { Scale = 1 }, "dockPress" .. spec.key, true)
		end)
		b.MouseLeave:Connect(function()
			press.Scale = 1
		end)
		b.Activated:Connect(function()
			if spec.key == "Home" then
				self.home:Fire()
			elseif spec.key == "Trophies" then
				self.trophies:Fire()
			else
				self.options:Fire()
			end
		end)
		buttons[spec.key] = b
		local cap, cl = Kit.chip(f, spec.key .. "Caption", "label", spec.caption, { h = 22, pad = 8, fg = Color3.new(1, 1, 1),
			bg = Theme.C.deep, bgA = 0.8 })
		cap.AnchorPoint = Vector2.new(0.5, 0)
		cap.ZIndex = 3
		cl.ZIndex = 3
		captions[spec.key] = cap
		local _ = i
	end
	-- the trophies badge and the options dot
	local badge, badgeLabel = Kit.chip(buttons.Trophies, "Badge", "badge", "", { h = 22, pad = 7, fg = Color3.new(1, 1, 1),
		bg = Color3.fromHex("b8860b"), bgA = 1, line = Color3.fromHex("ffe08a"), lineA = 0.9 })
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0)
	badge.ZIndex = 8
	badgeLabel.ZIndex = 8
	Kit.textStroke(badgeLabel, 1.5, 0.7)
	badge.Visible = false
	local dot = Kit.frame(buttons.Options, "Dot", 8)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.9, 0.1)
	dot.Size = UDim2.fromOffset(14, 14)
	dot.BackgroundColor3 = Theme.C.danger
	dot.BackgroundTransparency = 0
	Kit.corner(dot)
	Kit.stroke(dot, 2, Color3.new(1, 1, 1), 1)
	dot.Visible = false

	-- the zoom capsule
	local zoom = Kit.frame(parent, "Zoom", 5)
	zoom.AnchorPoint = Vector2.new(0, 1)
	Recipes.glass(zoom)
	zoom.BackgroundTransparency = math.min(zoom.BackgroundTransparency, 0.12)
	Kit.corner(zoom)
	self.zoom = zoom
	local function zbtn(name: string, glyph: string, x: number, sig: Signal.Signal<>): TextButton
		local b = Kit.button(zoom, name)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(x, 0, 0.5, 0)
		b.Size = UDim2.fromOffset(40, 40)
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = Theme.C.panel3
		Kit.corner(b)
		Kit.stroke(b, 1.5, Theme.C.strokeHi, 1)
		local g = Kit.glyph(b, "Icon", glyph, Color3.new(1, 1, 1))
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(0.5, 0.5)
		b.Activated:Connect(function() sig:Fire() end)
		return b
	end
	zbtn("Minus", "minus", 0, self.zoomOut)
	zbtn("Plus", "plus", 1, self.zoomIn)
	local pct = Kit.label(zoom, "Pct", "number", "", Color3.new(1, 1, 1))
	pct.AnchorPoint = Vector2.new(0.5, 0.5)
	pct.Position = UDim2.fromScale(0.5, 0.5)
	pct.Size = UDim2.new(1, -90, 1, 0)
	pct.TextXAlignment = Enum.TextXAlignment.Center
	local zoomWanted = true

	local function place()
		local compact = Layout.mode == "COMPACT"
		local bs = if small then 56 elseif compact then 50 else 64
		local gap = if compact then 18 else 20
		local capH = if compact then 20 else 22
		f.Position = UDim2.new(0, if compact then 12 else 20, 1, if compact then -6 else -8)
		f.Size = UDim2.fromOffset(3 * bs + 2 * gap, bs + 2 + capH)
		for i, spec in BUTTONS do
			local b = buttons[spec.key]
			b.Size = UDim2.fromOffset(bs, bs)
			b.Position = UDim2.fromOffset((i - 1) * (bs + gap), 0)
			local cap = captions[spec.key]
			cap.Size = UDim2.fromOffset(0, capH)
			cap.Position = UDim2.fromOffset((i - 1) * (bs + gap) + bs / 2, bs + 2)
			local cl = cap:FindFirstChild("Label") :: TextLabel?
			if cl then Theme.text(cl, "label") end
			Kit.halo(b, spec.hue, 0.4, 10)
			local st = b:FindFirstChild("Rim") :: UIStroke?
			if st then
				st.Thickness = if active == spec.key then 3 else 2.5
				st.Color = if active == spec.key then Color3.new(1, 1, 1) else Theme.lift(spec.hue, 0.55)
			end
		end
		Theme.text(badgeLabel, "badge")
		badge.Size = UDim2.fromOffset(0, if compact then 20 else 22)
		zoom.Size = UDim2.fromOffset(176, 54)
		zoom.Position = UDim2.new(0, (if compact then 12 else 20) + 3 * bs + 2 * gap + 20, 1, -(if compact then 6 else 8) - capH - 2 - (bs - 54) / 2)
		Theme.text(pct, "number")
		zoom.Visible = zoomWanted and not compact and Input.kind() == "mouse"
		self.changed:Fire()
	end
	place()
	Layout.changed:Connect(place)
	Input.kindChanged:Connect(place)

	function self.setTrophies(_: Dock, text: string?)
		badge.Visible = text ~= nil
		if text then badgeLabel.Text = text end
	end
	function self.setUnsaved(_: Dock, b: boolean)
		dot.Visible = b
	end
	function self.setActive(_: Dock, key: string?)
		active = key
		place()
	end
	function self.setZoomPct(_: Dock, z: number)
		local t = string.format("%d%%", math.floor(z * 100 + 0.5))
		if pct.Text ~= t then pct.Text = t end
	end
	function self.setZoomVisible(_: Dock, b: boolean)
		zoomWanted = b
		place()
	end
	function self.setSmall(_: Dock, b: boolean)
		if small == b then return end
		small = b
		place()
	end
	function self.destroy(d: Dock)
		for _, s in { d.home, d.trophies, d.options, d.zoomIn, d.zoomOut, d.changed } do s:DisconnectAll() end
		f:Destroy()
		zoom:Destroy()
	end
	return self
end

return Dock
