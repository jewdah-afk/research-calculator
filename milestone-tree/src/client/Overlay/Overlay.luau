--!strict
--[[
	Overlay: the facade over OverlayGui (DESIGN.md 7): toasts and the notification list, the hover tooltip, the node
	peek, the modals (export, import, hard reset, the Multiverse gate) and the full-screen states.

	    local overlay = Overlay.new(gui)
	    overlay:toasts(pops?, notices?)
	    overlay:tooltip(owner, content?, at?)      content = Tooltip.Content; nil hides that owner's tooltip
	    overlay:peek(layer?, node?, ring?)         the node peek (nil closes)
	    overlay:detail(card?)                      the touch detail sheet: the panel package owns the card; nothing yet
	    overlay:modal(kind?, data?)                "export" | "import" | "hardReset" | "gate" | nil
	    overlay:importResult(imp)
	    overlay:screen(kind?, data?)               "loading" | "fatal" | "outOfSync" | "end" | "firstRun" | nil
	    overlay:flash(color)                       overlay:onCamera(cam)       overlay:busy() -> modal / peek open
	    overlay.act (action, hold?), overlay.flyTo (layer), overlay.importText (text), overlay.resync (),
	    overlay.openLayer (layer), overlay.peekClosed ()
	Esc closes the modal, then the peek.
]]

local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local Tooltip = require(script.Parent:WaitForChild("Tooltip"))
local Peek = require(script.Parent:WaitForChild("Peek"))
local Modals = require(script.Parent:WaitForChild("Modals"))
local Screens = require(script.Parent:WaitForChild("Screens"))

type Action = Types.Action
type ARect = Types.Rect

export type Overlay = {
	act: Signal.Signal<Action, boolean?>,
	flyTo: Signal.Signal<string>,
	importText: Signal.Signal<string>,
	resync: Signal.Signal<>,
	openLayer: Signal.Signal<string>,
	peekClosed: Signal.Signal<>,
	toasts: (self: Overlay, pops: { Types.Popup }?, notices: { string }?) -> (),
	tooltip: (self: Overlay, owner: any, content: Tooltip.Content?, at: Vector2?) -> (),
	peek: (self: Overlay, layer: string?, node: Types.MapNode?, ring: ARect?) -> (),
	detail: (self: Overlay, card: any?) -> (),
	modal: (self: Overlay, kind: string?, data: any?) -> (),
	importResult: (self: Overlay, imp: Types.ImportResult) -> (),
	screen: (self: Overlay, kind: string?, data: any?) -> (),
	flash: (self: Overlay, color: Color3) -> (),
	onCamera: (self: Overlay, cam: Types.Camera) -> (),
	busy: (self: Overlay) -> boolean,
	destroy: (self: Overlay) -> (),
}

local Overlay = {}

function Overlay.new(gui: ScreenGui): Overlay
	local self = {} :: Overlay
	self.act = Signal.new() :: Signal.Signal<Action, boolean?>
	self.flyTo = Signal.new() :: Signal.Signal<string>
	self.importText = Signal.new() :: Signal.Signal<string>
	self.resync = Signal.new() :: Signal.Signal<>
	self.openLayer = Signal.new() :: Signal.Signal<string>
	self.peekClosed = Signal.new() :: Signal.Signal<>

	local root = (gui:FindFirstChild("Root") or gui) :: GuiObject
	local toasts = Toasts.new(root)
	local tip = Tooltip.new(root)
	local peek = Peek.new(root)
	local modals = Modals.new(root)
	local screens = Screens.new(root)

	toasts.flyTo:Connect(function(l: string) self.flyTo:Fire(l) end)
	peek.open:Connect(function(l: string) self.openLayer:Fire(l) end)
	peek.act:Connect(function(a: Action) self.act:Fire(a, false) end)
	peek.closed:Connect(function()
		toasts:setCollapsed(false)
		self.peekClosed:Fire()
	end)
	modals.act:Connect(function(a: Action)
		self.act:Fire(a, false)
	end)
	modals.importText:Connect(function(t: string) self.importText:Fire(t) end)
	modals.notice:Connect(function(t: string) toasts:push(nil, { t }) end)
	screens.act:Connect(function(a: Action) self.act:Fire(a, false) end)
	screens.resync:Connect(function() self.resync:Fire() end)

	function self.toasts(_: Overlay, pops: { Types.Popup }?, notices: { string }?)
		toasts:push(pops, notices)
	end
	function self.tooltip(_: Overlay, owner: any, content: Tooltip.Content?, at: Vector2?)
		if peek:isOpen() or modals:isOpen() then
			tip:hide()
			return
		end
		tip:show(owner, content, at)
	end
	function self.peek(_: Overlay, layer: string?, node: Types.MapNode?, ring: ARect?)
		tip:hide()
		peek:show(layer, node, ring)
		toasts:setCollapsed(layer ~= nil)
	end
	function self.detail(_: Overlay, _card: any?) end
	function self.modal(_: Overlay, kind: string?, data: any?)
		tip:hide()
		if kind then peek:show(nil) end
		modals:open(kind, data)
	end
	function self.importResult(_: Overlay, imp: Types.ImportResult)
		modals:importResult(imp)
	end
	function self.screen(_: Overlay, kind: string?, data: any?)
		screens:show(kind, data)
	end
	function self.flash(_: Overlay, color: Color3)
		screens:flash(color)
	end
	function self.onCamera(_: Overlay, _cam: Types.Camera) end
	function self.busy(_: Overlay): boolean
		return peek:isOpen() ~= nil or modals:isOpen() ~= nil
	end

	local escConn = UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		if io.KeyCode ~= Enum.KeyCode.Escape then return end
		if modals:isOpen() then
			modals:open(nil)
		elseif peek:isOpen() then
			peek:show(nil)
		end
		local _ = processed
	end)

	function self.destroy(o: Overlay)
		escConn:Disconnect()
		toasts:destroy()
		tip:destroy()
		peek:destroy()
		modals:destroy()
		screens:destroy()
		o.act:DisconnectAll()
		o.flyTo:DisconnectAll()
		o.importText:DisconnectAll()
		o.resync:DisconnectAll()
		o.openLayer:DisconnectAll()
		o.peekClosed:DisconnectAll()
	end
	return self
end

return Overlay
