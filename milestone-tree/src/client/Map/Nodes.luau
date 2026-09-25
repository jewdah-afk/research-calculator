--!strict
--[[
	Nodes: the 21 layer node widgets on the map plus the rift hotspot (DESIGN.md 3.7, 3.11): the state machine of
	sealed / frontier / dormant / locked / available / glow / pulse / selected / challenge / infected, taps (never
	after a drag, 300 ms double-click debounce), long-press / right-click peek and hover.

	    local nodes = Nodes.new(view, mapInput)
	    nodes:update(ms)                  a new MapState (ViewStore:map())
	    nodes:setSelected(layer?)         the open panel's node
	    nodes:setFirstRun(b)              the first-run cue on M
	    nodes.activated (layer), nodes.peek (layer), nodes.hover (layer?, abs), nodes.rift (event, abs)
	    nodes:ringRect(layer), nodes:plateRect(layer), nodes:worldPos(layer)

	Widgets live in view.nodes (the world transform: Position = fromScale(x / 3840, y / 2560)); every widget sets
	the attribute State (plan D16 test anchors). Art socket keys: the game id cp is the socket cr (Realm.alias).

	SKELETON (package D, wave 1): the public API with empty bodies. Owner: package F (wave 2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Signal"))
local MapView = require(script.Parent:WaitForChild("MapView"))
local MapInput = require(script.Parent:WaitForChild("MapInput"))

type MapState = Types.MapState
type ARect = Types.Rect

export type Nodes = {
	activated: Signal.Signal<string>,
	peek: Signal.Signal<string>,
	hover: Signal.Signal<string?, Vector2>,
	rift: Signal.Signal<string, Vector2>, -- "hover" | "leave" | "click"
	update: (self: Nodes, ms: MapState) -> (),
	setSelected: (self: Nodes, layer: string?) -> (),
	setFirstRun: (self: Nodes, b: boolean) -> (),
	ringRect: (self: Nodes, layer: string) -> ARect?,
	plateRect: (self: Nodes, layer: string) -> ARect?,
	worldPos: (self: Nodes, layer: string) -> Vector2,
	destroy: (self: Nodes) -> (),
}

local Nodes = {}

function Nodes.new(view: MapView.MapView, mapInput: MapInput.MapInput): Nodes
	local realm: any = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Realm"))
	local self = {} :: Nodes
	self.activated = Signal.new() :: Signal.Signal<string>
	self.peek = Signal.new() :: Signal.Signal<string>
	self.hover = Signal.new() :: Signal.Signal<string?, Vector2>
	self.rift = Signal.new() :: Signal.Signal<string, Vector2>
	function self.update(_: Nodes, _ms: MapState) end
	function self.setSelected(_: Nodes, _layer: string?) end
	function self.setFirstRun(_: Nodes, _b: boolean) end
	function self.ringRect(_: Nodes, _layer: string): ARect?
		return nil
	end
	function self.plateRect(_: Nodes, _layer: string): ARect?
		return nil
	end
	-- the node's socket in world px (Realm.nodes; cp is the socket cr)
	function self.worldPos(_: Nodes, layer: string): Vector2
		local key = realm.alias[layer] or layer
		local p = realm.nodes[key]
		if p == nil then return Vector2.new(realm.camera.start[1], realm.camera.start[2]) end
		return Vector2.new(p[1], p[2])
	end
	function self.destroy(_: Nodes)
		self.activated:DisconnectAll()
		self.peek:DisconnectAll()
		self.hover:DisconnectAll()
		self.rift:DisconnectAll()
	end
	return self
end

return Nodes
