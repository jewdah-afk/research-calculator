--!strict
--[[
	NodeWidget: one map node's instance tree (DESIGN.md 3.7, Figma Map Node 4:40): at most 10 instances, with the
	conditional parts (aura, rays, select ring, badges, chips, challenge ring) created lazily. The widget sits in
	view.nodes at its socket (Scale units of the world: x / 3840, y / 2560) and scales with the world zoom; below
	the floor zoom (36 / 132 mouse, 44 / 132 touch) one UIScale holds it at the floor. `Hit` is the ImageButton that
	takes the tap (InputSink None, so the map drag still sees the press).

	    local w = NodeWidget.new(parent, layer, worldPos)
	    w:update(node, state)            state: sealed | frontier | dormant | locked | available | glow | pulse | ...
	    w:setSelected(b), w:setFloor(k)
	    w.frame, w.hit

	SKELETON (package D, wave 1): the public API with empty bodies. Owner: package F (wave 2).
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))

type MapNode = Types.MapNode

export type NodeWidget = {
	layer: string,
	frame: Frame,
	hit: ImageButton?,
	state: string,
	update: (self: NodeWidget, node: MapNode, state: string) -> (),
	setSelected: (self: NodeWidget, b: boolean) -> (),
	setFloor: (self: NodeWidget, k: number) -> (),
	destroy: (self: NodeWidget) -> (),
}

local NodeWidget = {}

function NodeWidget.new(parent: Frame, layer: string, pos: Vector2): NodeWidget
	local f = Instance.new("Frame")
	f.Name = "Node_" .. layer
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(pos.X / 3840, pos.Y / 2560)
	f.Size = UDim2.fromScale(132 / 3840, 132 / 2560)
	f:SetAttribute("State", "sealed")
	f.Parent = parent
	local self = {} :: NodeWidget
	self.layer = layer
	self.frame = f
	self.hit = nil
	self.state = "sealed"
	function self.update(w: NodeWidget, _node: MapNode, state: string)
		w.state = state
		w.frame:SetAttribute("State", state)
	end
	function self.setSelected(_: NodeWidget, _b: boolean) end
	function self.setFloor(_: NodeWidget, _k: number) end
	function self.destroy(w: NodeWidget)
		w.frame:Destroy()
	end
	return self
end

return NodeWidget
