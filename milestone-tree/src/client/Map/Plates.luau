--!strict
--[[
	Plates: the nameplates under the nodes (DESIGN.md 3.9): one Frame + one RichText label each, in view.plates
	(full Box, a constant UI size under UIScale s). Level of detail FULL / CHIP / NONE by zoom with hysteresis,
	occlusion fade (alpha .16) under the HUD rects of Layout.rects(), collision culling. Positions are written every
	moving frame; text at most 5 times a second and only when it changed.

	    local plates = Plates.new(view, nodes)
	    plates:update(ms)       plates:onCamera(cam)      plates:setMode(labels)   -- Prefs labels: AUTO | ALWAYS | OFF

	SKELETON (package D, wave 1): the public API with empty bodies. Owner: package F (wave 2).
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local MapView = require(script.Parent:WaitForChild("MapView"))
local Nodes = require(script.Parent:WaitForChild("Nodes"))

type MapState = Types.MapState
type Camera = Types.Camera

export type Plates = {
	update: (self: Plates, ms: MapState) -> (),
	onCamera: (self: Plates, cam: Camera) -> (),
	setMode: (self: Plates, labels: string) -> (),
	destroy: (self: Plates) -> (),
}

local Plates = {}

function Plates.new(view: MapView.MapView, nodes: Nodes.Nodes): Plates
	local self = {} :: Plates
	function self.update(_: Plates, _ms: MapState) end
	function self.onCamera(_: Plates, _cam: Camera) end
	function self.setMode(_: Plates, _labels: string) end
	function self.destroy(_: Plates) end
	return self
end

return Plates
