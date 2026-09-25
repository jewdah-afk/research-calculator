--!strict
--[[
	Markers: the edge markers in MarkerGui (DESIGN.md 3.10): at most 4 arrows at the screen edge pointing at
	off-screen READY and CAN BUY nodes, pushed out of the HUD rects; a tap flies to the node and opens it.

	    local markers = Markers.new(gui, view, nodes)
	    markers:update(ms)      markers:onCamera(cam)      markers.activated (layer)

	SKELETON (package D, wave 1): the public API with empty bodies. Owner: package F (wave 2).
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Signal"))
local MapView = require(script.Parent:WaitForChild("MapView"))
local Nodes = require(script.Parent:WaitForChild("Nodes"))

type MapState = Types.MapState
type Camera = Types.Camera

export type Markers = {
	activated: Signal.Signal<string>,
	update: (self: Markers, ms: MapState) -> (),
	onCamera: (self: Markers, cam: Camera) -> (),
	destroy: (self: Markers) -> (),
}

local Markers = {}

function Markers.new(gui: ScreenGui, view: MapView.MapView, nodes: Nodes.Nodes): Markers
	local self = {} :: Markers
	self.activated = Signal.new() :: Signal.Signal<string>
	function self.update(_: Markers, _ms: MapState) end
	function self.onCamera(_: Markers, _cam: Camera) end
	function self.destroy(m: Markers)
		m.activated:DisconnectAll()
	end
	return self
end

return Markers
