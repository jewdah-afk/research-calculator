--!strict
--[[
	Dock: HOME / TROPHIES / OPTIONS at the bottom left (DESIGN.md 4.4) and the zoom capsule after it (mouse only).

	    Dock      Home, Trophies (+ Badge "13/18"), Options (+ Dot while the server cannot save), Shop: ImageButtons with the
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
local Rich = require(Core:WaitForChild("Rich"))
local Sleek = require(Core:WaitForChild("Sleek"))
local Skin = require(Core:WaitForChild("Skin"))
local Input = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("Input"))
local Kit = require(script.Parent:WaitForChild("Kit"))

export type Dock = {
	frame: Frame,
	zoom: Frame,
	home: Signal.Signal<>,
	trophies: Signal.Signal<>,
	options: Signal.Signal<>,
	shop: Signal.Signal<>,
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
	{ key = "Shop", caption = "Shop", hue = Color3.fromHex("ffc93c"), glyph = "bag" },
}

function Dock.new(parent: GuiObject): Dock
	local self = {} :: Dock
	self.home = Signal.new() :: Signal.Signal<>
	self.trophies = Signal.new() :: Signal.Signal<>
	self.options = Signal.new() :: Signal.Signal<>
	self.shop = Signal.new() :: Signal.Signal<>
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
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Image = ""
		b.ZIndex = 3
		-- Sleek: a dark slab with a hairline and corner ticks, a white line icon, an index number; the active
		-- button gets the button's hue as a rim and a 2 du floor line
		Sleek.plate(b, { alpha = 0.86, line = 0.86 })
		Sleek.ticks(b, { len = 10, th = 2, out = 1, color = Color3.new(1, 1, 1), alpha = 0.8, z = 7 })
		local icon = Kit.glyph(b, "Icon", spec.glyph, Color3.new(1, 1, 1), Sleek.C.top)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.42, 0.42)
		icon.ZIndex = 6
		local idx = Sleek.micro(b, "Index", string.format("%02d", i), Sleek.C.micro)
		idx.Position = UDim2.fromOffset(6, 5)
		idx.ZIndex = 6
		local floor = Kit.frame(b, "Floor", 6)
		floor.AnchorPoint = Vector2.new(0, 1)
		floor.Position = UDim2.fromScale(0, 1)
		floor.Size = UDim2.new(1, 0, 0, 2)
		floor.BackgroundColor3 = spec.hue
		floor.BackgroundTransparency = 0
		floor.Visible = false
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
			elseif spec.key == "Shop" then
				self.shop:Fire()
			else
				self.options:Fire()
			end
		end)
		buttons[spec.key] = b
		local cap, cl = Kit.chip(f, spec.key .. "Caption", "caps", Rich.caps(spec.caption), { h = 22, pad = 4,
			fg = Color3.fromHex("e6ebf2"), bg = Theme.C.deep, bgA = 0 })
		cap.AnchorPoint = Vector2.new(0.5, 0)
		cap.ZIndex = 3
		cl.ZIndex = 3
		captions[spec.key] = cap
	end
	-- the trophies badge and the options dot
	local badge, badgeLabel = Kit.chip(buttons.Trophies, "Badge", "badge", "", { h = 18, pad = 6, fg = Sleek.C.ink,
		bg = Sleek.C.gold, bgA = 1 })
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, 2, 0, -2) -- inside its own tile, so the next tile never covers it
	local bc = badge:FindFirstChildWhichIsA("UICorner")
	if bc then bc:Destroy() end
	badge.ZIndex = 8
	badgeLabel.ZIndex = 8
	Kit.textStroke(badgeLabel, 0)
	badge.Visible = false
	local dot = Kit.frame(buttons.Options, "Dot", 8)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.9, 0.1)
	dot.Size = UDim2.fromOffset(9, 9)
	dot.Rotation = 45
	dot.BackgroundColor3 = Theme.C.danger
	dot.BackgroundTransparency = 0
	dot.Visible = false

	-- the zoom capsule
	local zoom = Kit.frame(parent, "Zoom", 5)
	zoom.AnchorPoint = Vector2.new(0, 1)
	Sleek.plate(zoom, { alpha = 0.86, line = 0.86 })
	Sleek.ticks(zoom, { len = 10, th = 2, out = 1, color = Color3.new(1, 1, 1), alpha = 0.8, z = 7 })
	-- a ruler under the percentage; the lit part is the zoom level
	local ruler = Kit.frame(zoom, "Ruler", 6)
	ruler.AnchorPoint = Vector2.new(0.5, 1)
	ruler.Position = UDim2.new(0.5, 0, 1, -6)
	ruler.Size = UDim2.fromOffset(60, 3)
	for k = 0, 10 do
		local t = Kit.frame(ruler, "T" .. k, 6)
		t.Position = UDim2.fromOffset(k * 6, 0)
		t.Size = UDim2.fromOffset(1, 3)
		t.BackgroundColor3 = Color3.new(1, 1, 1)
		t.BackgroundTransparency = 0.7
	end
	local lit = Kit.frame(ruler, "Lit", 7)
	lit.Position = UDim2.fromOffset(0, -1)
	lit.Size = UDim2.fromOffset(30, 1)
	lit.BackgroundColor3 = Theme.hue("p")
	lit.BackgroundTransparency = 0
	self.zoom = zoom
	local function zbtn(name: string, glyph: string, x: number, sig: Signal.Signal<>): TextButton
		local b = Kit.button(zoom, name)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(x, 0, 0.5, 0)
		b.Size = UDim2.fromOffset(40, 40)
		b.BackgroundTransparency = 1
		local g = Kit.glyph(b, "Icon", glyph, Color3.new(1, 1, 1))
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(0.42, 0.42)
		b.Activated:Connect(function() sig:Fire() end)
		return b
	end
	zbtn("Minus", "minus", 0, self.zoomOut).Position = UDim2.new(0, 22, 0.5, 0)
	zbtn("Plus", "plus", 1, self.zoomIn).Position = UDim2.new(1, -22, 0.5, 0)
	local pct = Kit.label(zoom, "Pct", "number", "", Color3.new(1, 1, 1))
	pct.AnchorPoint = Vector2.new(0.5, 0.5)
	pct.Position = UDim2.new(0.5, 0, 0.5, -3)
	pct.Size = UDim2.new(1, -90, 0, 20)
	pct.TextXAlignment = Enum.TextXAlignment.Center
	local zoomWanted = true

	local function place()
		local compact = Layout.mode == "COMPACT"
		local bs = if small then 56 elseif compact then 50 else 64
		local gap = if compact then 18 else 24
		local capH = if compact then 20 else 22
		f.Position = UDim2.new(0, if compact then 12 else 20, 1, if compact then -6 else -8)
		f.Size = UDim2.fromOffset(#BUTTONS * bs + (#BUTTONS - 1) * gap, bs + 2 + capH)
		for i, spec in BUTTONS do
			local b = buttons[spec.key]
			b.Size = UDim2.fromOffset(bs, bs)
			b.Position = UDim2.fromOffset((i - 1) * (bs + gap), 0)
			local cap = captions[spec.key]
			cap.Size = UDim2.fromOffset(0, capH)
			cap.Position = UDim2.fromOffset((i - 1) * (bs + gap) + bs / 2, bs + 2)
			local cl = cap:FindFirstChild("Label") :: TextLabel?
			if cl then
				Theme.text(cl, "caps")
				-- phones: no letter tracking, so the three captions fit their 68 du pitch
				cl.Text = if compact then string.upper(spec.caption) else Rich.caps(spec.caption)
			end
			local on = active == spec.key
			Sleek.plate(b, { alpha = 0.86, line = if on then 0.3 else 0.86 })
			Skin.apply(b, "tile", { scale = bs / 150 })
			local hair = b:FindFirstChild("Hair") :: UIStroke?
			if hair then hair.Color = if on then spec.hue else Color3.new(1, 1, 1) end
			local fl = b:FindFirstChild("Floor") :: Frame?
			if fl then fl.Visible = on end
			local ix = b:FindFirstChild("Index") :: TextLabel?
			if ix then ix.TextColor3 = if on then spec.hue else Sleek.C.micro end
			if cl then cl.TextColor3 = if on then Color3.new(1, 1, 1) else Color3.fromHex("e6ebf2") end
		end
		Theme.text(badgeLabel, "badge")
		badge.Size = UDim2.fromOffset(0, if compact then 20 else 22)
		zoom.Size = UDim2.fromOffset(150, 44)
		zoom.Position = UDim2.new(0, (if compact then 12 else 20) + #BUTTONS * bs + (#BUTTONS - 1) * gap + 24, 1, -(if compact then 6 else 8) - capH - 2 - (bs - 44) / 2)
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
		lit.Size = UDim2.fromOffset(math.clamp(math.floor(z * 60 + 0.5), 1, 60), 1)
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
		for _, s in { d.home, d.trophies, d.options, d.shop, d.zoomIn, d.zoomOut, d.changed } do s:DisconnectAll() end
		f:Destroy()
		zoom:Destroy()
	end
	return self
end

return Dock
