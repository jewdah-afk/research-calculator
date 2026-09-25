--!strict
--[[
	Markers: the edge markers in MarkerGui (DESIGN.md 3.10). A pulse or glow node whose ring is outside the free map
	rect F gets a marker: a Ø50 (Ø38 COMPACT) emblem with a white pointer toward the node and its bolt or "!" badge,
	where the ray from F's centre crosses F inset by 14 du, pushed out of the HUD rects. At most 4, pulse first. A tap
	fires `activated` (the owner flies to the node). Pop-in: Back Out 0.2 s.

	    local markers = Markers.new(gui, view, nodes)
	    markers:update(ms)      markers:onCamera(cam)      markers.activated (layer)
	onCamera is connected to view.cameraChanged already.
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))
local MapView = require(script.Parent:WaitForChild("MapView"))
local Nodes = require(script.Parent:WaitForChild("Nodes"))
local MapLogic = require(script.Parent:WaitForChild("MapLogic"))
local NodeWidget = require(script.Parent:WaitForChild("NodeWidget"))

type MapState = Types.MapState
type Camera = Types.Camera
type ARect = Types.Rect

export type Markers = {
	activated: Signal.Signal<string>,
	update: (self: Markers, ms: MapState) -> (),
	onCamera: (self: Markers, cam: Camera) -> (),
	setEnabled: (self: Markers, on: boolean) -> (),
	destroy: (self: Markers) -> (),
}

local Markers = {}
local MAX = 4

type Rec = { layer: string, frame: Frame, emblem: Frame, pointer: Frame, badge: Frame, kind: string, shown: boolean }

function Markers.new(gui: ScreenGui, view: MapView.MapView, nodes: Nodes.Nodes): Markers
	local self = {} :: Markers
	self.activated = Signal.new() :: Signal.Signal<string>
	local root = gui:FindFirstChild("Root") :: Frame? or gui
	local recs: { [string]: Rec } = {}
	local want: { string } = {}
	local ms: MapState? = nil
	local enabled = true

	local function size(): number
		return if Layout.mode == "COMPACT" then 38 else 50
	end

	local function make(layer: string): Rec
		local hue = Theme.hue(layer)
		local f = Kit.frame(root, "Marker_" .. layer, 5)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		local d = size()
		f.Size = UDim2.fromOffset(d, d)
		local pointer = Kit.frame(f, "Pointer", 1)
		pointer.AnchorPoint = Vector2.new(0.5, 0.5)
		pointer.Position = UDim2.fromScale(0.5, 0.5)
		pointer.Size = UDim2.fromScale(1.5, 1.5)
		local tip = Kit.frame(pointer, "Tip", 1)
		tip.AnchorPoint = Vector2.new(0.5, 0.5)
		tip.Position = UDim2.fromScale(0.93, 0.5)
		tip.Size = UDim2.fromScale(0.2, 0.2)
		tip.Rotation = 45
		tip.BackgroundColor3 = Color3.new(1, 1, 1)
		tip.BackgroundTransparency = 0
		Kit.corner(tip, UDim.new(0.15, 0))
		local emblem = Kit.frame(f, "Emblem", 2)
		emblem.Size = UDim2.fromScale(1, 1)
		Kit.gem(emblem, hue)
		Kit.stroke(emblem, 2.5, Color3.new(1, 1, 1), 0.95, "Line")
		local sym = Kit.label(emblem, "Symbol", "badge", "", Color3.new(1, 1, 1))
		sym.Size = UDim2.fromScale(1, 1)
		sym.FontFace = Font.fromName("Sarpanch", Enum.FontWeight.Heavy)
		sym.TextXAlignment = Enum.TextXAlignment.Center
		sym.ZIndex = 3
		Kit.textStroke(sym, 2, 1)
		local text = NodeWidget.SYMS[layer] or string.upper(layer)
		if text == "★" then
			local g = Kit.glyph(emblem, "Star", "star", Color3.new(1, 1, 1))
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
			g.Size = UDim2.fromScale(0.5, 0.5)
			g.ZIndex = 3
		else
			sym.Text = text
			sym.TextSize = math.max(13, math.floor(d * (if #text >= 3 then 0.3 elseif #text == 2 then 0.36 else 0.44)))
		end
		local badge = Kit.frame(f, "Badge", 4)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.86, 0.14)
		badge.Size = UDim2.fromScale(0.46, 0.46)
		badge.BackgroundTransparency = 0
		Kit.corner(badge)
		Kit.stroke(badge, 1.5, Color3.new(1, 1, 1), 1, "Line")
		local hitB = Kit.button(f, "Hit")
		hitB.Size = UDim2.new(1, 16, 1, 16)
		hitB.Position = UDim2.fromOffset(-8, -8)
		hitB.ZIndex = 10
		hitB.Activated:Connect(function()
			self.activated:Fire(layer)
		end)
		local r: Rec = { layer = layer, frame = f, emblem = emblem, pointer = pointer, badge = badge, kind = "", shown = false }
		f.Visible = false
		recs[layer] = r
		return r
	end

	local function setKind(r: Rec, kind: string)
		if r.kind == kind then return end
		r.kind = kind
		local g: Frame
		if kind == "bolt" then
			r.badge.BackgroundColor3 = Theme.C.complete
			g = Kit.glyph(r.badge, "Icon", "bolt", Color3.fromHex("2a1a00"))
		else
			r.badge.BackgroundColor3 = Theme.C.danger
			g = Kit.glyph(r.badge, "Icon", "bang", Color3.new(1, 1, 1))
		end
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(0.64, 0.64)
	end

	local function layout()
		local state = ms
		local rootAbs = root.AbsolutePosition
		local s = Layout.s
		local F = Layout.free()
		local inset = 14 * s
		local used = 0
		local placed: { ARect } = {}
		for _, layer in want do
			local r = recs[layer] or make(layer)
			local on = false
			if enabled and state and used < MAX then
				local p = view:worldToAbs(nodes:worldPos(layer))
				local ex, ey = MapLogic.edgePoint(F, p.X, p.Y, inset + size() * s / 2)
				if ex and ey then
					-- push out of the HUD rects: slide toward F's centre until clear (a few steps)
					local d = size() * s
					local cx, cy = F.x + F.w / 2, F.y + F.h / 2
					local x, y = ex, ey
					for _ = 1, 12 do
						local rect = { x = x - d / 2, y = y - d / 2, w = d, h = d }
						local hitAny = false
						for _, h in Layout.rects() do
							if MapLogic.overlap(rect, h) > 0 then hitAny = true end
						end
						for _, h in placed do
							if MapLogic.overlap(rect, h) > 0 then hitAny = true end
						end
						if not hitAny then break end
						local dx, dy = cx - x, cy - y
						local len = math.max(1, math.sqrt(dx * dx + dy * dy))
						x += dx / len * d * 0.6
						y += dy / len * d * 0.6
					end
					table.insert(placed, { x = x - d / 2, y = y - d / 2, w = d, h = d })
					r.frame.Position = UDim2.fromOffset((x - rootAbs.X) / s, (y - rootAbs.Y) / s)
					r.pointer.Rotation = math.deg(math.atan2(p.Y - y, p.X - x))
					on = true
					used += 1
				end
			end
			if on ~= r.shown then
				r.shown = on
				r.frame.Visible = on
				if on then Motion.pop(r.frame) end
			end
		end
		for layer, r in recs do
			if r.shown and not table.find(want, layer) then
				r.shown = false
				r.frame.Visible = false
			end
		end
	end

	function self.update(_: Markers, newMs: MapState)
		ms = newMs
		want = MapLogic.markerCandidates(newMs, 21)
		for _, layer in want do
			local r = recs[layer] or make(layer)
			setKind(r, if table.find(newMs.ready, layer) then "bolt" else "bang")
		end
		layout()
	end
	function self.onCamera(_: Markers, _cam: Camera)
		layout()
	end
	function self.setEnabled(_: Markers, on: boolean)
		enabled = on
		layout()
	end
	local conns: { any } = {}
	table.insert(conns, view.cameraChanged:Connect(function(c: Camera) self:onCamera(c) end))
	table.insert(conns, Layout.rectsChanged:Connect(function() task.defer(layout) end))
	table.insert(conns, Layout.changed:Connect(function()
		for _, r in recs do
			local d = size()
			r.frame.Size = UDim2.fromOffset(d, d)
		end
		task.defer(layout)
	end))
	function self.destroy(m: Markers)
		for _, c in conns do c:Disconnect() end
		for _, r in recs do r.frame:Destroy() end
		m.activated:DisconnectAll()
	end
	return self
end

return Markers
