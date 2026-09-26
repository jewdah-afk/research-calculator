--!strict
--[[
	Hud: the facade over the HUD (DESIGN.md 4, 12). TopbarGui (TopbarSafeInsets) holds the points capsule with the
	rate pill, warning and status chips, the universe tag and the COMPACT panel band; HudGui (CoreUISafeInsets) holds
	the dock (HOME / TROPHIES / OPTIONS), the zoom capsule, the READY tray / pill and the Multiverse portal. Every part
	registers its rect with Layout.setRect (hud.capsule, hud.pill, ...) so plates and markers keep clear.

	    local hud = Hud.new(topbarGui, hudGui)
	    hud:updateHud(h)   hud:updateMap(ms)   hud:setStatus(kind)   hud:setPanel(p)   hud:setFirstRun(b)   hud:setZoomPct(z)
	    hud:setVisible(b)
	    hud.home, hud.trophies, hud.options, hud.portal, hud.zoomIn, hud.zoomOut, hud.bandClose   ()
	    hud.bandSwitch (layer)                              -- a READY gem in the COMPACT band
	    hud.readyTap (layer), hud.readyHold (layer)        -- the hold already passed the hold safety
	    hud.readyMore ()                                    -- "+N more" in the tray
	    hud.gateHold ()                                     -- the universe tag FINISH / EXIT hold completed
	    hud.warnTap (abs)
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Layout = require(Core:WaitForChild("Layout"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Capsule = require(script.Parent:WaitForChild("Capsule"))
local UniverseTag = require(script.Parent:WaitForChild("UniverseTag"))
local Band = require(script.Parent:WaitForChild("Band"))
local Dock = require(script.Parent:WaitForChild("Dock"))
local Ready = require(script.Parent:WaitForChild("Ready"))
local Portal = require(script.Parent:WaitForChild("Portal"))

type HudState = Types.HudState
type MapState = Types.MapState
type ARect = Types.Rect

export type PanelInfo = { layer: string?, mode: string, strip: ARect?, title: string? } -- mode: "side" | "full"
export type Hud = {
	home: Signal.Signal<>,
	trophies: Signal.Signal<>,
	options: Signal.Signal<>,
	shop: Signal.Signal<>,
	portal: Signal.Signal<>,
	zoomIn: Signal.Signal<>,
	zoomOut: Signal.Signal<>,
	bandClose: Signal.Signal<>,
	bandSwitch: Signal.Signal<string>,
	readyTap: Signal.Signal<string>,
	readyHold: Signal.Signal<string>,
	readyMore: Signal.Signal<>,
	gateHold: Signal.Signal<>,
	warnTap: Signal.Signal<Vector2>,
	updateHud: (self: Hud, h: HudState) -> (),
	updateMap: (self: Hud, ms: MapState) -> (),
	setStatus: (self: Hud, kind: string?) -> (), -- "saving" | "saved" | "off" | "reconnecting" | nil
	setPanel: (self: Hud, p: PanelInfo?) -> (),
	setFirstRun: (self: Hud, b: boolean) -> (),
	setZoomPct: (self: Hud, z: number) -> (),
	setVisible: (self: Hud, b: boolean) -> (),
	destroy: (self: Hud) -> (),
}

local Hud = {}

function Hud.new(topbar: ScreenGui, hud: ScreenGui): Hud
	local self = {} :: Hud
	self.home = Signal.new() :: Signal.Signal<>
	self.trophies = Signal.new() :: Signal.Signal<>
	self.options = Signal.new() :: Signal.Signal<>
	self.shop = Signal.new() :: Signal.Signal<>
	self.portal = Signal.new() :: Signal.Signal<>
	self.zoomIn = Signal.new() :: Signal.Signal<>
	self.zoomOut = Signal.new() :: Signal.Signal<>
	self.bandClose = Signal.new() :: Signal.Signal<>
	self.bandSwitch = Signal.new() :: Signal.Signal<string>
	self.readyTap = Signal.new() :: Signal.Signal<string>
	self.readyHold = Signal.new() :: Signal.Signal<string>
	self.readyMore = Signal.new() :: Signal.Signal<>
	self.gateHold = Signal.new() :: Signal.Signal<>
	self.warnTap = Signal.new() :: Signal.Signal<Vector2>

	local topRoot = (topbar:FindFirstChild("Root") or topbar) :: GuiObject
	local hudRoot = (hud:FindFirstChild("Root") or hud) :: GuiObject

	local capsule = Capsule.new(topRoot)
	local tag = UniverseTag.new(topRoot)
	local band = Band.new(topRoot)
	local dock = Dock.new(hudRoot)
	local ready = Ready.new(hudRoot)
	local portal = Portal.new(hudRoot)

	capsule.warnTap:Connect(function(abs: Vector2) self.warnTap:Fire(abs) end)
	tag.hold:Connect(function() self.gateHold:Fire() end)
	band.close:Connect(function() self.bandClose:Fire() end)
	band.switch:Connect(function(l: string) self.bandSwitch:Fire(l) end)
	dock.home:Connect(function() self.home:Fire() end)
	dock.trophies:Connect(function() self.trophies:Fire() end)
	dock.options:Connect(function() self.options:Fire() end)
	dock.shop:Connect(function() self.shop:Fire() end)
	dock.zoomIn:Connect(function() self.zoomIn:Fire() end)
	dock.zoomOut:Connect(function() self.zoomOut:Fire() end)
	ready.tap:Connect(function(l: string) self.readyTap:Fire(l) end)
	ready.hold:Connect(function(l: string) self.readyHold:Fire(l) end)
	ready.more:Connect(function() self.readyMore:Fire() end)
	portal.tap:Connect(function() self.portal:Fire() end)

	local firstRun = false
	local panel: PanelInfo? = nil
	local visible = true
	local lastMs: MapState? = nil

	-- ------------------------------------------------------------------------------------------ rects
	local parts: { [string]: GuiObject } = {
		capsule = capsule.frame, pill = capsule.pill, warn = capsule.warn, status = capsule.status, info = capsule.info, unitag = tag.frame,
		band = band.frame, dock = dock.frame, zoom = dock.zoom, ready = ready.frame, readyPill = ready.pill,
		banner = ready.banner, portal = portal.frame,
	}
	local pending = false
	local function shownOnScreen(g: GuiObject): boolean
		if not g.Visible then return false end
		local p = g.Parent
		while p and p:IsA("GuiObject") do
			if not (p :: GuiObject).Visible then return false end
			p = p.Parent
		end
		local gui = g:FindFirstAncestorWhichIsA("ScreenGui")
		return gui == nil or gui.Enabled
	end
	local function register()
		pending = false
		for key, g in parts do
			if visible and shownOnScreen(g) and g.AbsoluteSize.X > 1 then
				Layout.setRect("hud." .. key, Kit.rect(g))
			else
				Layout.setRect("hud." .. key, nil)
			end
		end
		Layout.setRect("hud.topbar", if visible then Layout.topbar() else nil)
	end
	local function soon()
		if pending then return end
		pending = true
		task.defer(register)
	end
	for _, g in parts do
		g:GetPropertyChangedSignal("AbsoluteSize"):Connect(soon)
		g:GetPropertyChangedSignal("AbsolutePosition"):Connect(soon)
		g:GetPropertyChangedSignal("Visible"):Connect(soon)
	end
	for _, s in { capsule.changed, dock.changed, ready.changed, portal.changed } do s:Connect(soon) end
	Layout.changed:Connect(soon)

	-- ------------------------------------------------------------------------------------------ modes
	local function apply()
		local compact = Layout.mode == "COMPACT"
		local p = panel
		local side = p ~= nil and p.mode == "side"
		local full = p ~= nil and p.mode == "full"
		capsule.frame.Visible = not (full and compact)
		-- beside a side sheet the capsule (and the universe tag) centre over the map strip (DESIGN.md 4.2)
		local strip = if side and p then p.strip else nil
		if strip then
			local ro = topRoot.AbsolutePosition
			local s = math.max(Layout.s, 0.01)
			capsule:setCentre((strip.x + strip.w / 2 - ro.X) / s)
		else
			capsule:setCentre(nil)
		end
		tag:setTop(capsule:bottom(), capsule:centre())
		local bl = if full and compact and p then p.layer else nil
		local bn = if bl and lastMs then (lastMs :: MapState).nodes[bl] else nil
		band:show(bl, if p then p.title else nil, if bn and type(bn.sym) == "string" then bn.sym else nil)
		dock:setSmall(side)
		dock:setZoomVisible(not firstRun and p == nil)
		ready:setMode(if side then "strip" elseif compact then "pill" else "tray")
		ready:setHidden(firstRun or full)
		portal:setHidden(firstRun or side or full)
		local ms = lastMs
		if ms then ready:update(ms) end
		soon()
	end

	function self.updateHud(_: Hud, h: HudState)
		capsule:update(h)
		tag:setTop(capsule:bottom(), capsule:centre())
		soon()
	end
	function self.updateMap(_: Hud, ms: MapState)
		lastMs = ms
		capsule:setUniverse(ms.inside)
		tag:update(ms.gate)
		tag:setTop(capsule:bottom(), capsule:centre())
		ready:update(ms)
		portal:update(ms.gate)
		local list = {}
		for _, l in ms.ready do
			local n = ms.nodes[l]
			table.insert(list, { layer = l, sym = if n and type(n.sym) == "string" then n.sym else string.upper(l) })
		end
		band:setReady(list)
		local ach = ms.nodes.ach
		local v = ach and ach.val
		dock:setTrophies(if ach and ach.show and v and v.pts then v.pts .. "/" .. (v.tot or "18") else nil)
		dock:setActive(if ms.open == "ach" then "Trophies" elseif ms.open == "options-tab" then "Options" else nil)
		soon()
	end
	function self.setStatus(_: Hud, kind: string?)
		capsule:setStatus(kind)
		dock:setUnsaved(kind == "off")
		tag:setTop(capsule:bottom(), capsule:centre())
		soon()
	end
	function self.setPanel(_: Hud, p: PanelInfo?)
		panel = p
		apply()
	end
	function self.setFirstRun(_: Hud, b: boolean)
		if b == firstRun then return end
		firstRun = b
		capsule:setFirstRun(b)
		apply()
	end
	function self.setZoomPct(_: Hud, z: number)
		dock:setZoomPct(z)
	end
	function self.setVisible(_: Hud, b: boolean)
		visible = b
		topbar.Enabled = b
		hud.Enabled = b
		register()
	end
	function self.destroy(h: Hud)
		for _, s in { h.home, h.trophies, h.options, h.shop, h.portal, h.zoomIn, h.zoomOut, h.bandClose, h.gateHold, h.readyMore } do
			s:DisconnectAll()
		end
		h.readyTap:DisconnectAll()
		h.bandSwitch:DisconnectAll()
		h.readyHold:DisconnectAll()
		h.warnTap:DisconnectAll()
		for key in parts do Layout.setRect("hud." .. key, nil) end
		Layout.setRect("hud.topbar", nil)
		capsule:destroy()
		tag:destroy()
		band:destroy()
		dock:destroy()
		ready:destroy()
		portal:destroy()
	end
	apply()
	return self
end

return Hud
