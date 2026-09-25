--!strict
--[[
	MapInput: the map's gestures (art/REALM.md 9.4 camera.feel, DESIGN.md 3.4, Q-M1).

	    local mi = MapInput.new(view, Input)
	    mi:step(dt)                   once a frame before view:step (App's PreRender loop)
	    mi:wasDrag()                  the current / last press became a pan (node taps check it)
	    mi.emptyTap:Connect(fn)       a tap on the map where no node is (App closes a side sheet)
	    mi:zoomStep(dir, abs?)        one wheel notch (the zoom capsule, the - / = keys)
	    mi:busy()                     gliding, pinching or zooming: holds must not start (Recipes.holdGate)
	    mi:setEnabled(b)

	Gestures: drag past 6 pt (mouse) / 12 pt (touch) pans with velocity smoothed over 0.05 s, rubber band at the
	edges, inertia exp(-dt / 0.32) on release (stops under 6 pt/s, capped at 4500 pt/s); wheel x1.12 a notch toward a
	target zoom eased in log space (tau 0.085 s) about the cursor; two-finger pinch about the midpoint with a pan by the
	midpoint (zoom rubber +-6%); double-tap / double-click x1.6 toward the point in 0.35 s; double-tap-and-drag zooms
	(1 pt up = x1.006); gamepad left stick pans (1400 pt/s, deadzone .18, curve 1.6), triggers zoom (x1.8 a second).
	The view springs back into the hard envelope when input stops. Reduced motion: no inertia, a hard clamp while
	dragging, instant zoom steps and no animated double-tap.
	A press starts only when no HUD / panel / overlay element is on top (Input.overUi) and inside the map Box.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Signal = require(Core:WaitForChild("Signal"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local MapCamera = require(script.Parent:WaitForChild("MapCamera"))

local MapInput = {}

type Pt = MapCamera.Pt

export type InputLib = { overUi: (abs: Vector2) -> boolean }
export type MapInput = {
	emptyTap: Signal.Signal<Vector2>,
	wasDrag: (self: MapInput) -> boolean,
	busy: (self: MapInput) -> boolean,
	setEnabled: (self: MapInput, b: boolean) -> (),
	zoomStep: (self: MapInput, dir: number, at: Vector2?) -> (),
	step: (self: MapInput, dt: number) -> (),
	destroy: (self: MapInput) -> (),
}

type Press = { io: InputObject, touch: boolean, start: Vector2, last: Vector2, t0: number }

-- the view's shape as MapInput uses it (MapView.MapView satisfies it)
type View = {
	box: Frame,
	nodes: Frame,
	inputActive: boolean,
	camera: (self: any) -> { C: Vector2, z: number, V: Vector2, m: number },
	setCamera: (self: any, C: Vector2, z: number, rubber: boolean?) -> (),
	flyTo: (self: any, C: Vector2, z: number, o: { time: number?, ease: string? }?) -> (),
	cancelFly: (self: any) -> (),
	absToMap: (self: any, q: Vector2) -> Vector2,
}

function MapInput.new(view: View, input: InputLib?): MapInput
	local Realm: any = require(game:GetService("ReplicatedStorage"):WaitForChild("MilestoneTree"):WaitForChild("Realm"))
	local feel = Realm.feel
	local self = {} :: MapInput
	self.emptyTap = Signal.new() :: Signal.Signal<Vector2>

	local enabled = true
	local presses: { [InputObject]: Press } = {}
	local order: { InputObject } = {}
	local mouse: Vector2? = nil -- the last mouse position (abs)
	local dragging = false
	local dragFrom: { C: Pt, at: Vector2 }? = nil -- the camera and pointer (map pts) where the pan (re)started
	local wasDrag = false
	local vx, vy = 0, 0 -- pointer velocity, map points / s
	local lastPt: Vector2? = nil
	local inertia = false
	local pinch: { d0: number, z0: number, Q: Pt }? = nil
	local zoomDrag: { y0: number, z0: number, at: Vector2 }? = nil
	local wheelZ: number? = nil
	local wheelAt = Vector2.zero
	local lastTap = { t = -math.huge, at = Vector2.zero }
	local stick = Vector2.zero
	local trigR, trigL = 0, 0
	local conns: { RBXScriptConnection } = {}

	local function over(abs: Vector2): boolean
		if input then return input.overUi(abs) end
		return false
	end
	local function inBox(abs: Vector2): boolean
		local p, s = view.box.AbsolutePosition, view.box.AbsoluteSize
		return abs.X >= p.X and abs.Y >= p.Y and abs.X <= p.X + s.X and abs.Y <= p.Y + s.Y
	end
	local function toMap(abs: Vector2): Vector2
		return view:absToMap(abs)
	end
	local function posOf(pr: Press): Vector2
		if pr.touch then return Layout.inputToAbs(pr.io.Position) end
		return mouse or pr.last
	end
	local function reduced(): boolean
		return Motion.reduced()
	end
	local function cam(): (Pt, number, MapCamera.Size, number)
		local c = view:camera()
		return { x = c.C.X, y = c.C.Y }, c.z, { w = c.V.X, h = c.V.Y }, c.m
	end
	local function apply(C: Pt, z: number, rubber: boolean)
		view:setCamera(Vector2.new(C.x, C.y), z, rubber and not reduced())
	end
	-- the pan with the displayed rubber band: overshoot past the hard limit resists (rubberBand of REALM.md 2.5)
	local function rubberPan(C: Pt, z: number, V: MapCamera.Size): Pt
		if reduced() then
			local c = MapCamera.clampCamera(C, z, V, false)
			return { x = c.x, y = c.y }
		end
		local lim = MapCamera.panLimits(z, V, 0)
		local function axis(v: number, lo: number, hi: number): number
			if v < lo then return lo - MapCamera.rubberBand((lo - v) * z) / z end
			if v > hi then return hi + MapCamera.rubberBand((v - hi) * z) / z end
			return v
		end
		return { x = axis(C.x, lim.x0, lim.x1), y = axis(C.y, lim.y0, lim.y1) }
	end
	local function zoomAbout(z2: number, at: Vector2, rubber: boolean)
		local C, z, V = cam()
		local lo, hi = MapCamera.zoomRange(V, rubber and not reduced())
		z2 = math.clamp(z2, lo, hi)
		local S = toMap(at)
		local C2 = MapCamera.zoomAt(C, z, z2, { x = S.X, y = S.Y }, V)
		apply(C2, z2, true)
	end
	local function nodeAt(abs: Vector2): boolean
		local lp = Players.LocalPlayer
		local pg = if lp then lp:FindFirstChildOfClass("PlayerGui") else nil
		if pg == nil then return false end
		local ok, list = pcall(function(): { GuiObject }
			return (pg :: PlayerGui):GetGuiObjectsAtPosition(abs.X, abs.Y)
		end)
		if not ok then return false end
		for _, o in list do
			if o:IsA("GuiButton") and o:IsDescendantOf(view.nodes) then return true end
		end
		return false
	end
	local function count(): number
		return #order
	end
	local function beginPinch()
		local a, b = presses[order[1]], presses[order[2]]
		if a == nil or b == nil then return end
		local pa, pb = toMap(posOf(a)), toMap(posOf(b))
		local C, z, V = cam()
		local mid = (pa + pb) / 2
		pinch = {
			d0 = math.max(8, (pa - pb).Magnitude),
			z0 = z,
			Q = { x = C.x + (mid.X - V.w / 2) / z, y = C.y + (mid.Y - V.h / 2) / z },
		}
		dragging = false
		dragFrom = nil
		zoomDrag = nil
		wasDrag = true
		inertia = false
		vx, vy = 0, 0
	end

	-- ------------------------------------------------------------------------------------------ raw input
	table.insert(conns, UserInputService.InputBegan:Connect(function(io: InputObject, _processed: boolean)
		if not enabled then return end
		local t = io.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local abs = Layout.inputToAbs(io.Position)
		if t == Enum.UserInputType.MouseButton1 then mouse = abs end
		if not inBox(abs) or over(abs) then return end
		view:cancelFly()
		inertia = false
		vx, vy = 0, 0
		wheelZ = nil
		local pr: Press = { io = io, touch = t == Enum.UserInputType.Touch, start = abs, last = abs, t0 = os.clock() }
		presses[io] = pr
		table.insert(order, io)
		if count() == 1 then
			wasDrag = false
			dragging = false
			dragFrom = nil
			-- a second press right after a tap: double-tap-and-drag zoom (touch) or a double click
			if os.clock() - lastTap.t < 0.3 and (abs - lastTap.at).Magnitude < 30 then
				local _, z = cam()
				zoomDrag = { y0 = abs.Y, z0 = z, at = abs }
			else
				zoomDrag = nil
			end
		elseif count() == 2 and pr.touch then
			beginPinch()
		end
		view.inputActive = true
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(io: InputObject, processed: boolean)
		local t = io.UserInputType
		if t == Enum.UserInputType.MouseMovement then
			mouse = Layout.inputToAbs(io.Position)
		elseif t == Enum.UserInputType.MouseWheel then
			if not enabled then return end
			local abs = Layout.inputToAbs(io.Position)
			if not inBox(abs) or over(abs) then return end
			local notch = io.Position.Z
			if notch == 0 then return end
			self:zoomStep(if notch > 0 then 1 else -1, abs)
		elseif t == Enum.UserInputType.Gamepad1 then
			if processed or not enabled then return end
			if io.KeyCode == Enum.KeyCode.Thumbstick1 then
				stick = Vector2.new(io.Position.X, io.Position.Y)
			elseif io.KeyCode == Enum.KeyCode.ButtonR2 then
				trigR = io.Position.Z
			elseif io.KeyCode == Enum.KeyCode.ButtonL2 then
				trigL = io.Position.Z
			end
		end
	end))
	local function finish(io: InputObject)
		local pr = presses[io]
		if pr == nil then return end
		presses[io] = nil
		local i = table.find(order, io)
		if i then table.remove(order, i) end
		local abs = posOf(pr)
		if pinch then
			if count() < 2 then pinch = nil end
			if count() == 1 then
				-- the remaining finger continues as a pan
				local rest = presses[order[1]]
				if rest then
					local C = cam()
					dragFrom = { C = C, at = toMap(posOf(rest)) }
					dragging = true
				end
			end
		elseif zoomDrag then
			local zd = zoomDrag
			zoomDrag = nil
			if (abs - zd.at).Magnitude < 12 then
				-- a double tap: x1.6 toward the point
				local C, z, V = cam()
				local z2 = math.clamp(z * feel.doubleTapFactor, MapCamera.zMin(V), MapCamera.Z_MAX)
				local S = toMap(abs)
				local C2 = MapCamera.zoomAt(C, z, z2, { x = S.X, y = S.Y }, V)
				local hc = MapCamera.clampCamera(C2, z2, V, false)
				view:flyTo(Vector2.new(hc.x, hc.y), hc.z, { time = feel.doubleTapSeconds, ease = "quintOut" })
				lastTap.t = -math.huge
			end
		elseif not dragging and count() == 0 then
			-- a tap
			if not nodeAt(abs) then self.emptyTap:Fire(abs) end
			lastTap.t, lastTap.at = os.clock(), abs
		end
		if count() == 0 then
			if dragging and not reduced() then
				-- inertia, except on an axis that is already past the hard limit (the spring takes it back)
				local C, z, V = cam()
				local hard = MapCamera.clampCamera(C, z, V, false)
				local sp = math.sqrt(vx * vx + vy * vy)
				if sp > feel.maxFling then
					vx, vy = vx / sp * feel.maxFling, vy / sp * feel.maxFling
				end
				if math.abs(hard.x - C.x) > 1e-6 then vx = 0 end
				if math.abs(hard.y - C.y) > 1e-6 then vy = 0 end
				inertia = math.sqrt(vx * vx + vy * vy) > feel.inertiaStop
			end
			dragging = false
			dragFrom = nil
			if not inertia and wheelZ == nil then view.inputActive = false end
		end
	end
	table.insert(conns, UserInputService.InputEnded:Connect(function(io: InputObject)
		local t = io.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			finish(io)
		elseif t == Enum.UserInputType.Gamepad1 then
			if io.KeyCode == Enum.KeyCode.Thumbstick1 then stick = Vector2.zero end
			if io.KeyCode == Enum.KeyCode.ButtonR2 then trigR = 0 end
			if io.KeyCode == Enum.KeyCode.ButtonL2 then trigL = 0 end
		end
	end))
	-- trackpads: two-finger pan and pinch arrive as PointerAction (the wheel comes as MouseWheel above)
	table.insert(conns, UserInputService.PointerAction:Connect(function(_wheel: number, pan: Vector2, pinchDelta: number, processed: boolean)
		if processed or not enabled then return end
		local at = mouse or Vector2.zero
		if not inBox(at) or over(at) then return end
		local C, z, V, m = cam()
		if pan.Magnitude > 0 then
			local p = MapCamera.clampCamera({ x = C.x - pan.X / m / z, y = C.y - pan.Y / m / z }, z, V, false)
			apply({ x = p.x, y = p.y }, z, false)
		end
		if pinchDelta ~= 0 then zoomAbout(z * (1 + pinchDelta), at, false) end
	end))

	-- ------------------------------------------------------------------------------------------ API
	function self.wasDrag(_: MapInput): boolean
		return wasDrag
	end
	function self.busy(_: MapInput): boolean
		return pinch ~= nil or inertia or zoomDrag ~= nil or math.sqrt(vx * vx + vy * vy) > feel.inertiaStop and dragging
	end
	function self.setEnabled(_: MapInput, b: boolean)
		enabled = b
		if not b then
			table.clear(presses)
			table.clear(order)
			dragging, pinch, zoomDrag, inertia, wheelZ = false, nil, nil, false, nil
			view.inputActive = false
		end
	end
	function self.zoomStep(_: MapInput, dir: number, at: Vector2?)
		local _, z, V = cam()
		local bp, bs = view.box.AbsolutePosition, view.box.AbsoluteSize
		wheelAt = at or (bp + bs / 2)
		local base = wheelZ or z
		local target = math.clamp(base * feel.wheelFactor ^ dir, MapCamera.zMin(V), MapCamera.Z_MAX)
		view:cancelFly()
		if reduced() then
			wheelZ = nil
			zoomAbout(target, wheelAt, false)
			return
		end
		wheelZ = target
		view.inputActive = true
	end
	function self.step(_: MapInput, dt: number)
		if dt <= 0 then return end
		local C, z, V, m = cam()
		-- one finger / the mouse: pan, or the double-tap-drag zoom
		if not pinch and count() >= 1 then
			local pr = presses[order[1]]
			if pr then
				local abs = posOf(pr)
				pr.last = abs
				local p = toMap(abs)
				if zoomDrag then
					local zd = zoomDrag
					if (abs - zd.at).Magnitude >= 12 then wasDrag = true end
					local dy = (abs.Y - zd.y0) / m
					zoomAbout(zd.z0 * 1.006 ^ (-dy), zd.at, true)
				else
					local moved = (abs - pr.start).Magnitude / m
					local threshold = if pr.touch then feel.dragTouch else feel.dragMouse
					if not dragging and moved > threshold then
						dragging = true
						wasDrag = true
						dragFrom = { C = C, at = p }
						lastPt = p
					end
					if dragging and dragFrom then
						local df = dragFrom
						local raw = { x = df.C.x - (p.X - df.at.X) / z, y = df.C.y - (p.Y - df.at.Y) / z }
						apply(rubberPan(raw, z, V), z, true)
						-- velocity, exponentially smoothed (tau .05 s)
						local lp = lastPt or p
						local ix, iy = (p.X - lp.X) / dt, (p.Y - lp.Y) / dt
						local k = 1 - math.exp(-dt / feel.velocityTau)
						vx += (ix - vx) * k
						vy += (iy - vy) * k
						lastPt = p
					end
				end
			end
		end
		-- two fingers: pinch about the midpoint, pan by its motion
		if pinch and count() >= 2 then
			local a, b = presses[order[1]], presses[order[2]]
			if a and b then
				local pa, pb = toMap(posOf(a)), toMap(posOf(b))
				local mid = (pa + pb) / 2
				local d = math.max(8, (pa - pb).Magnitude)
				local lo, hi = MapCamera.zoomRange(V, not reduced())
				local z2 = math.clamp(pinch.z0 * d / pinch.d0, lo, hi)
				local C2 = { x = pinch.Q.x - (mid.X - V.w / 2) / z2, y = pinch.Q.y - (mid.Y - V.h / 2) / z2 }
				apply(rubberPan(C2, z2, V), z2, true)
			end
		end
		-- inertia
		if inertia then
			local decay = math.exp(-dt / feel.inertiaTau)
			vx *= decay
			vy *= decay
			if math.sqrt(vx * vx + vy * vy) < feel.inertiaStop then
				inertia = false
				vx, vy = 0, 0
				if count() == 0 and wheelZ == nil then view.inputActive = false end
			else
				local c = MapCamera.clampCamera({ x = C.x - vx * dt / z, y = C.y - vy * dt / z }, z, V, false)
				if math.abs(c.x - (C.x - vx * dt / z)) > 1e-6 then vx = 0 end
				if math.abs(c.y - (C.y - vy * dt / z)) > 1e-6 then vy = 0 end
				apply({ x = c.x, y = c.y }, z, false)
			end
		end
		-- the wheel: ease toward the target zoom in log space about the cursor
		if wheelZ then
			local target = wheelZ :: number
			local _, zNow = cam()
			local k = 1 - math.exp(-dt / feel.wheelTau)
			local lz = math.log(zNow) + (math.log(target) - math.log(zNow)) * k
			local z2 = math.exp(lz)
			if math.abs(lz - math.log(target)) < 1e-4 then
				z2 = target
				wheelZ = nil
				if count() == 0 and not inertia then view.inputActive = false end
			end
			zoomAbout(z2, wheelAt, false)
		end
		-- gamepad: stick pan, trigger zoom
		local mag = stick.Magnitude
		if enabled and mag > feel.padDeadzone then
			local k = ((mag - feel.padDeadzone) / (1 - feel.padDeadzone)) ^ feel.padCurve
			local dir = stick / mag
			local speed = feel.padSpeed * k
			local C3, z3, V3 = cam()
			local c = MapCamera.clampCamera({ x = C3.x + dir.X * speed * dt / z3, y = C3.y - dir.Y * speed * dt / z3 }, z3, V3, false)
			view:cancelFly()
			apply({ x = c.x, y = c.y }, z3, false)
		end
		local trig = trigR - trigL
		if enabled and math.abs(trig) > 0.05 then
			local _, z4 = cam()
			local bp, bs = view.box.AbsolutePosition, view.box.AbsoluteSize
			view:cancelFly()
			zoomAbout(z4 * feel.padZoomRate ^ (trig * dt), bp + bs / 2, false)
		end
	end
	function self.destroy(_: MapInput)
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		self.emptyTap:DisconnectAll()
	end
	return self
end

return MapInput
