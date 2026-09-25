--!strict
--[[
	Nodes: the 21 layer node widgets on the map plus the rift hotspot (DESIGN.md 3.7, 3.11): the state machine of
	sealed / frontier / dormant / locked / available / glow / pulse (+ selected, challenge, infected), taps (never
	after a drag, 300 ms double-click debounce), long-press / right-click peek and hover, and the first-run cue.

	    local nodes = Nodes.new(view, mapInput)
	    nodes:update(ms)                  a new MapState (ViewStore:map())
	    nodes:setSelected(layer?)         the open panel's node (overrides ms.open while set)
	    nodes:setFirstRun(b)              the START HERE cue above M (DESIGN.md 7.12)
	    nodes:setPeek(layer?)             the peeked node grows x1.25
	    nodes.activated (layer), nodes.peek (layer), nodes.hover (layer?, abs), nodes.rift (event, abs)
	    nodes:ringRect(layer), nodes:plateRect(layer), nodes:worldPos(layer), nodes:state(layer), nodes:widget(layer)

	Widgets live in view.nodes (the world transform: Position = fromScale(x / 3840, y / 2560)); every widget sets
	the attribute State (plan D16 test anchors). Art socket keys: the game id cp is the socket cr (Realm.alias).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Rich = require(Core:WaitForChild("Rich"))
local Input = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("Input"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))
local MapView = require(script.Parent:WaitForChild("MapView"))
local MapInput = require(script.Parent:WaitForChild("MapInput"))
local MapLogic = require(script.Parent:WaitForChild("MapLogic"))
local NodeWidget = require(script.Parent:WaitForChild("NodeWidget"))

type MapState = Types.MapState
type ARect = Types.Rect
type Camera = Types.Camera

export type Nodes = {
	activated: Signal.Signal<string>,
	peek: Signal.Signal<string>,
	hover: Signal.Signal<string?, Vector2>,
	rift: Signal.Signal<string, Vector2>, -- "hover" | "leave" | "click"
	changed: Signal.Signal<>, -- after update (states, selection) moved
	update: (self: Nodes, ms: MapState) -> (),
	setSelected: (self: Nodes, layer: string?) -> (),
	setFirstRun: (self: Nodes, b: boolean) -> (),
	setPeek: (self: Nodes, layer: string?) -> (),
	ringRect: (self: Nodes, layer: string) -> ARect?,
	plateRect: (self: Nodes, layer: string) -> ARect?,
	setPlateRect: (self: Nodes, layer: string, r: ARect?) -> (),
	worldPos: (self: Nodes, layer: string) -> Vector2,
	state: (self: Nodes, layer: string) -> string,
	rank: (self: Nodes, layer: string) -> number,
	selected: (self: Nodes) -> string?,
	hovered: (self: Nodes) -> string?,
	peeked: (self: Nodes) -> string?,
	ringRadius: (self: Nodes) -> number, -- world px of the ring radius as drawn (the floor included)
	onCamera: (self: Nodes, cam: Camera) -> (),
	destroy: (self: Nodes) -> (),
}

local Nodes = {}

local MAX_RAYS = 4

function Nodes.new(view: MapView.MapView, mapInput: MapInput.MapInput): Nodes
	local realm: any = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Realm"))
	local edges: { MapLogic.Edge } = realm.edges
	local self = {} :: Nodes
	self.activated = Signal.new() :: Signal.Signal<string>
	self.peek = Signal.new() :: Signal.Signal<string>
	self.hover = Signal.new() :: Signal.Signal<string?, Vector2>
	self.rift = Signal.new() :: Signal.Signal<string, Vector2>
	self.changed = Signal.new() :: Signal.Signal<>

	local function socket(layer: string): Vector2
		local key = realm.alias[layer] or layer
		local p = realm.nodes[key]
		if p == nil then return Vector2.new(realm.camera.start[1], realm.camera.start[2]) end
		return Vector2.new(p[1], p[2])
	end

	local widgets: { [string]: NodeWidget.NodeWidget } = {}
	local states: { [string]: string } = {}
	local ranks: { [string]: number } = {}
	local plateRects: { [string]: ARect } = {}
	local conns: { RBXScriptConnection } = {}
	local ms: MapState? = nil
	local selectedOverride: string? = nil
	local hoveredLayer: string? = nil
	local peekLayer: string? = nil
	local lastTap: { [string]: number } = {}
	local z, m = 0.5, 1
	local floorK = 36 / 132

	-- the pointer in abs space: GetMouseLocation counts from the device's top-left corner
	local function mouseAbs(): Vector2
		return Layout.deviceOrigin() + UserInputService:GetMouseLocation()
	end
	local function floorFor(): number
		return if Input.kind() == "touch" then 44 / 132 else 36 / 132
	end

	-- ------------------------------------------------------------------------------------------ widgets + input
	for i, layer in MapLogic.ORDER do
		local w = NodeWidget.new(view.nodes, layer, socket(layer))
		w.frame.ZIndex = 1
		widgets[layer] = w
		states[layer] = "sealed"
		ranks[layer] = 0
		local hit = w.hit
		local touchDown: InputObject? = nil
		local touchAt = Vector2.zero
		local peekFired = false
		table.insert(conns, hit.Activated:Connect(function()
			if mapInput:wasDrag() then return end
			if peekFired then
				peekFired = false
				return
			end
			local now = os.clock()
			if now - (lastTap[layer] or -1) < Input.DOUBLE_CLICK then return end
			lastTap[layer] = now
			self.activated:Fire(layer)
		end))
		table.insert(conns, hit.MouseEnter:Connect(function()
			if Input.kind() == "touch" then return end
			hoveredLayer = layer
			w:setHover(true)
			self.hover:Fire(layer, mouseAbs())
		end))
		table.insert(conns, hit.MouseMoved:Connect(function()
			if Input.kind() == "touch" or hoveredLayer ~= layer then return end
			self.hover:Fire(layer, mouseAbs())
		end))
		table.insert(conns, hit.MouseLeave:Connect(function()
			if hoveredLayer == layer then hoveredLayer = nil end
			w:setHover(false)
			w:setPress(false)
			self.hover:Fire(nil, mouseAbs())
		end))
		table.insert(conns, hit.MouseButton2Click:Connect(function()
			if Input.kind() == "touch" then return end
			self.peek:Fire(layer)
		end))
		table.insert(conns, hit.InputBegan:Connect(function(io: InputObject)
			local t = io.UserInputType
			if t == Enum.UserInputType.MouseButton1 then
				w:setPress(true)
				peekFired = false
			elseif t == Enum.UserInputType.Touch then
				w:setPress(true)
				peekFired = false
				touchDown = io
				touchAt = Layout.inputToAbs(io.Position)
				local mine = io
				task.delay(Input.LONG_PRESS, function()
					if touchDown ~= mine then return end
					local moved = (Layout.inputToAbs(mine.Position) - touchAt).Magnitude
					if moved < 12 and not mapInput:wasDrag() then
						peekFired = true
						w:setPress(false)
						self.peek:Fire(layer)
					end
				end)
			end
		end))
		table.insert(conns, hit.InputEnded:Connect(function(io: InputObject)
			local t = io.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				w:setPress(false)
				if io == touchDown then touchDown = nil end
			end
		end))
		local _ = i
	end
	-- a press that ends outside the button still releases it
	table.insert(conns, UserInputService.InputEnded:Connect(function(io: InputObject)
		local t = io.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			for _, w in widgets do w:setPress(false) end
		end
	end))

	-- ------------------------------------------------------------------------------------------ the rift hotspot
	local rift = Kit.child(view.nodes, "Rift", "ImageButton") :: ImageButton
	do
		local r = realm.rift
		rift.AnchorPoint = Vector2.new(0.5, 0.5)
		rift.Position = UDim2.fromScale(r.cx / 3840, r.cy / 2560)
		rift.Size = UDim2.fromScale(2 * r.rx / 3840, 2 * r.ry / 2560)
		rift.BackgroundTransparency = 1
		rift.ImageTransparency = 1
		rift.Image = ""
		rift.AutoButtonColor = false
		rift.BorderSizePixel = 0
		rift.Selectable = false
		rift.ZIndex = 0
		Kit.corner(rift)
		if Theme.caps.InputSink then
			pcall(function() (rift :: any).InputSink = (Enum :: any).InputSink.None end)
		end
		table.insert(conns, rift.MouseEnter:Connect(function()
			if Input.kind() == "touch" then return end
			view:setRiftHover(true)
			self.rift:Fire("hover", mouseAbs())
		end))
		table.insert(conns, rift.MouseMoved:Connect(function()
			if Input.kind() == "touch" then return end
			self.rift:Fire("hover", mouseAbs())
		end))
		table.insert(conns, rift.MouseLeave:Connect(function()
			view:setRiftHover(false)
			self.rift:Fire("leave", mouseAbs())
		end))
		table.insert(conns, rift.Activated:Connect(function()
			if mapInput:wasDrag() then return end
			self.rift:Fire("click", mouseAbs())
		end))
	end

	-- ------------------------------------------------------------------------------------------ first-run cue
	local cue: Frame? = nil
	local cueOn = false
	local function placeCue()
		local c = cue
		if c == nil or not cueOn then return end
		local p = socket("m")
		local cam = view:camera()
		local s = Layout.s
		local zz = math.max(cam.z, floorK)
		local x = (cam.V.X / 2 + cam.z * (p.X - cam.C.X)) * cam.m / s
		local y = (cam.V.Y / 2 + cam.z * (p.Y - cam.C.Y) - 66 * zz - 10) * cam.m / s
		c.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	end
	local function buildCue(): Frame
		local c = Kit.frame(view.plates, "FirstRunCue", 30)
		c.AnchorPoint = Vector2.new(0.5, 1)
		c.Size = UDim2.fromOffset(0, 0)
		c.AutomaticSize = Enum.AutomaticSize.XY
		local inner = Kit.frame(c, "Bob")
		inner.AutomaticSize = Enum.AutomaticSize.XY
		inner.Size = UDim2.fromOffset(0, 0)
		Kit.list(inner, "y", 4, Enum.HorizontalAlignment.Center)
		local hue = Theme.hue("m")
		local chip = Kit.frame(inner, "Chip")
		chip.LayoutOrder = 1
		chip.AutomaticSize = Enum.AutomaticSize.XY
		chip.Size = UDim2.fromOffset(0, 0)
		chip.BackgroundColor3 = Theme.shade(hue, 0.35)
		chip.BackgroundTransparency = 0
		Kit.corner(chip, UDim.new(0, 14))
		Kit.stroke(chip, 2, Theme.lift(hue, 0.4), 1)
		Kit.grad(chip, { Theme.shade(hue, 0.42), Theme.shade(hue, 0.3) }, 90)
		local compact = Layout.mode == "COMPACT"
		Kit.pad(chip, 8, 16, 9, 16)
		Kit.list(chip, "y", 2, Enum.HorizontalAlignment.Left)
		local title = Kit.label(chip, "Title", "toast", Rich.caps("Start here"), Color3.new(1, 1, 1))
		title.LayoutOrder = 1
		title.AutomaticSize = Enum.AutomaticSize.XY
		title.Size = UDim2.fromOffset(0, 0)
		Kit.textStroke(title, 1.5, 0.8)
		local sub = Kit.label(chip, "Sub", "body", "Get your first milestone", Color3.new(1, 1, 1))
		sub.LayoutOrder = 2
		sub.AutomaticSize = Enum.AutomaticSize.XY
		sub.Size = UDim2.fromOffset(0, 0)
		local _ = compact
		local arrow = Kit.glyph(inner, "Arrow", "down", Color3.new(1, 1, 1))
		arrow.LayoutOrder = 2
		arrow.Size = UDim2.fromOffset(22, 22)
		return c
	end
	function self.setFirstRun(_: Nodes, b: boolean)
		if b == cueOn then return end
		cueOn = b
		if b then
			if cue == nil then cue = buildCue() end
			local c = cue :: Frame
			c.Visible = true
			local bob = c:FindFirstChild("Bob") :: Frame?
			if bob then Kit.breathe(bob, "Position", UDim2.fromOffset(0, -4), UDim2.fromOffset(0, 4), 1) end
			placeCue()
		elseif cue then
			local c = cue :: Frame
			local bob = c:FindFirstChild("Bob")
			if bob then Kit.still(bob) end
			c.Visible = false
		end
	end

	-- ------------------------------------------------------------------------------------------ state
	local function selectedLayer(): string?
		if selectedOverride then return selectedOverride end
		return if ms then (ms :: MapState).open else nil
	end
	local function refresh()
		local state = ms
		if state == nil then return end
		local sel = selectedLayer()
		local pulses: { string } = {}
		for _, layer in MapLogic.ORDER do
			local w = widgets[layer]
			local st = MapLogic.state(state, layer, edges)
			local fl = MapLogic.flags(state, layer)
			fl.selected = sel == layer and state.nodes[layer] ~= nil and state.nodes[layer].show
			states[layer] = st
			local r = MapLogic.rank(state, layer, edges)
			if fl.selected then r = 100 end
			ranks[layer] = r
			w:update(state.nodes[layer], st, fl)
			w.frame.ZIndex = 1 + math.floor(r / 10)
			if st == "pulse" then table.insert(pulses, layer) end
		end
		-- rays on at most 4 pulse nodes (the selected one first)
		table.sort(pulses, function(a: string, b: string): boolean return ranks[a] > ranks[b] end)
		local on: { [string]: boolean } = {}
		for i, l in pulses do
			if i <= MAX_RAYS then on[l] = true end
		end
		for _, layer in MapLogic.ORDER do widgets[layer]:setRays(on[layer] == true) end
		self.changed:Fire()
	end

	function self.update(_: Nodes, newMs: MapState)
		ms = newMs
		refresh()
	end
	function self.setSelected(_: Nodes, layer: string?)
		selectedOverride = layer
		refresh()
	end
	function self.setPeek(_: Nodes, layer: string?)
		if peekLayer == layer then return end
		local old = peekLayer
		peekLayer = layer
		if old and widgets[old] then widgets[old]:setPeek(false) end
		if layer and widgets[layer] then widgets[layer]:setPeek(true) end
	end
	function self.ringRect(_: Nodes, layer: string): ARect?
		local w = widgets[layer]
		if w == nil or not w.ring.Visible then return nil end
		return Kit.rect(w.ring)
	end
	function self.plateRect(_: Nodes, layer: string): ARect?
		return plateRects[layer]
	end
	function self.setPlateRect(_: Nodes, layer: string, r: ARect?)
		plateRects[layer] = r :: any
	end
	function self.worldPos(_: Nodes, layer: string): Vector2
		return socket(layer)
	end
	function self.state(_: Nodes, layer: string): string
		return states[layer] or "sealed"
	end
	function self.rank(_: Nodes, layer: string): number
		return ranks[layer] or 0
	end
	function self.selected(_: Nodes): string?
		return selectedLayer()
	end
	function self.hovered(_: Nodes): string?
		return hoveredLayer
	end
	function self.peeked(_: Nodes): string?
		return peekLayer
	end
	function self.ringRadius(_: Nodes): number
		return 66 * math.max(1, floorK / math.max(z, 1e-3))
	end

	local lastZ, lastM = -1, -1
	function self.onCamera(_: Nodes, cam: Camera)
		z, m = cam.z, cam.m
		floorK = floorFor()
		if math.abs(z - lastZ) > 0.01 * lastZ or math.abs(m - lastM) > 1e-3 then
			lastZ, lastM = z, m
			for _, w in widgets do w:setZoom(z, m, floorK) end
		end
		placeCue()
	end
	table.insert(conns, (view.cameraChanged :: any):Connect(function(cam: Camera)
		self:onCamera(cam)
	end))
	Input.kindChanged:Connect(function()
		lastZ = -1
		self:onCamera(view:camera())
	end)
	Layout.changed:Connect(function()
		refresh()
	end)
	Motion.changed:Connect(function()
		refresh()
	end)

	function self.destroy(_: Nodes)
		for _, c in conns do c:Disconnect() end
		for _, w in widgets do w:destroy() end
		rift:Destroy()
		if cue then (cue :: Frame):Destroy() end
		self.activated:DisconnectAll()
		self.peek:DisconnectAll()
		self.hover:DisconnectAll()
		self.rift:DisconnectAll()
		self.changed:DisconnectAll()
	end
	self:onCamera(view:camera())
	return self
end

return Nodes
