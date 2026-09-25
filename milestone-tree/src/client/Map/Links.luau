--!strict
--[[
	Links: the live connections between nodes (DESIGN.md 3.8). Existence and lit state come from the view's `br`,
	geometry from Realm.edges (the Figma control points plus the MP -> PM bridge), colour from the child's hue (the
	malware P -> M link stays red). Lit links are Recipes.curve stacks (Path2D halo / glow / core / hot, thickness
	from the zoom); locked links are dots every 15 world px on HIGH (at most 400) or one thin thread on LOW and phones;
	pulsing edges carry flow sparks (HIGH, at most 6). Everything is in view.links, in world Scale units.

	    local links = Links.new(view)
	    links:update(ms)        links:onCamera(cam)     -- thickness when the zoom moved more than 2%

	SKELETON (package D, wave 1): the public API with empty bodies. Owner: package F (wave 2).
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local MapView = require(script.Parent:WaitForChild("MapView"))

type MapState = Types.MapState
type Camera = Types.Camera

export type Links = {
	update: (self: Links, ms: MapState) -> (),
	onCamera: (self: Links, cam: Camera) -> (),
	destroy: (self: Links) -> (),
}

local Links = {}

function Links.new(view: MapView.MapView): Links
	local self = {} :: Links
	function self.update(_: Links, _ms: MapState) end
	function self.onCamera(_: Links, _cam: Camera) end
	function self.destroy(_: Links) end
	return self
end

return Links
