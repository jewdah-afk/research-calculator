--!strict
--[[
	App: the client (plan 2.1-2.3, 1.11-1.12; DESIGN.md 3-7). The realm map is the home screen. A node opens its
	layer's panel beside the map (the map shrinks to a strip, DESIGN.md 3.6) or full screen on phones; the HUD and the
	overlays sit on top.

	    App.start()      once, from Main.client

	ScreenGuis (plan 2.1): Backing (-1, a black floor so no 3D sky ever shows), MapGui 0, MarkerGui 5, HudGui 10,
	TopbarGui 12, PanelGui 20, OverlayGui 30.

	Patch routing (plan 2.3): View -> ViewStore:apply -> map widgets, HUD, the panel (its own Render), toasts,
	modals, the status chip, the end screen. One PreRender loop: map input -> map view (+ its camera listeners) ->
	Motion. A drawing error resyncs once (Ready); a second one within 10 s shows OUT OF SYNC. No patch for 6 s shows
	RECONNECTING (the server sends at least one every 2 s).

	Panel protocol (plan 1.12): opening fires the node's own `a` once (never for the layer the server already shows),
	the shell draws at once and the body fills when patch.tab is that layer; closing fires map.close. The client's
	own open / close wins for up to 2 s until map.open confirms it; otherwise the panel follows map.open (a hotkey,
	the Multiverse, the end screen) without a fly-to. At boot the map is home: a layer left open by the last session
	is closed (and remembered for the phone start framing).

	Every action is a node's own `a` from the ViewStore, fired as is; the only one built here is {"key", name}.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Core = script.Parent:WaitForChild("Core")
local Types = require(script.Parent:WaitForChild("Types"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Prefs = require(Core:WaitForChild("Prefs"))
local ViewStore = require(Core:WaitForChild("ViewStore"))
local InputFolder = script.Parent:WaitForChild("Input")
local Input = require(InputFolder:WaitForChild("Input"))
local Hotkeys = require(InputFolder:WaitForChild("Hotkeys"))
local MapFolder = script.Parent:WaitForChild("Map")
local MapCamera = require(MapFolder:WaitForChild("MapCamera"))
local MapView = require(MapFolder:WaitForChild("MapView"))
local MapInput = require(MapFolder:WaitForChild("MapInput"))
local MapLogic = require(MapFolder:WaitForChild("MapLogic"))
local Nodes = require(MapFolder:WaitForChild("Nodes"))
local Links = require(MapFolder:WaitForChild("Links"))
local Plates = require(MapFolder:WaitForChild("Plates"))
local Markers = require(MapFolder:WaitForChild("Markers"))
local Hud = require(script.Parent:WaitForChild("Hud"):WaitForChild("Hud"))
local Overlay = require(script.Parent:WaitForChild("Overlay"):WaitForChild("Overlay"))
local Panel = require(script.Parent:WaitForChild("Panel"):WaitForChild("Panel"))
local Signatures = require(script.Parent:WaitForChild("Signatures"):WaitForChild("Signatures"))

type MapState = Types.MapState
type ARect = Types.Rect

local App = {}

local CRIMSON = Color3.fromHex("ff2e63")
local VIOLET = Color3.fromHex("8a7cff")
local GOLD = Color3.fromHex("ffc233")
local RIFT = Vector2.new(3150, 1350)
local UNIVERSE_WORD = { [true] = "Lives in the Prestige Multiverse", [false] = "Lives in the Normal Universe" }
local INTENT_WAIT = 2 -- seconds the client's own open / close waits for map.open to confirm it
local RECONNECT_AFTER = 6

-- the engine settings the client owns (plan 2.1, 4); each on its own, so one missing API never stops the rest
local function engineSettings()
	pcall(function() GuiService.TouchControlsEnabled = false end)
	pcall(function()
		local cam = Workspace.CurrentCamera
		if cam then cam.CameraType = Enum.CameraType.Scriptable end
	end)
	for _, t in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList } do
		pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end)
	end
end

-- a black floor under everything, covering the whole device (no inset): no 3D sky strip under the top bar, around
-- a phone's notch or behind a full-screen panel
local function backing(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Backing"
	gui.ResetOnSpawn = false
	gui.AutoLocalize = false
	gui.DisplayOrder = -1
	gui.ScreenInsets = Enum.ScreenInsets.None
	pcall(function() gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None end)
	local f = Instance.new("Frame")
	f.Name = "Floor"
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Theme.C.void
	f.Active = false
	f.Parent = gui
	local lp = Players.LocalPlayer
	gui.Parent = lp:WaitForChild("PlayerGui")
	return gui
end

function App.start()
	engineSettings()
	Theme.detect()
	Input.start()
	Layout.start()
	backing()

	-- ------------------------------------------------------------------------------------------ screens
	local mapGui, mapRoot = Layout.screen("MapGui", 0, Enum.ScreenInsets.None)
	local markerGui = Layout.screen("MarkerGui", 5, Enum.ScreenInsets.DeviceSafeInsets)
	local hudGui = Layout.screen("HudGui", 10, Enum.ScreenInsets.CoreUISafeInsets)
	local topbarGui = Layout.screen("TopbarGui", 12, Enum.ScreenInsets.TopbarSafeInsets)
	local panelGui = Layout.screen("PanelGui", 20, Enum.ScreenInsets.CoreUISafeInsets)
	local overlayGui = Layout.screen("OverlayGui", 30, Enum.ScreenInsets.DeviceSafeInsets)

	local overlay = Overlay.new(overlayGui)
	local screenKind: string? = nil
	local function setScreen(kind: string?, data: any?)
		screenKind = kind
		overlay:screen(kind, data)
	end
	setScreen("loading", { done = 0, total = 1 })

	local view = MapView.new(mapGui, mapRoot, { tier = MapView.chooseTier() })
	local mi = MapInput.new(view, Input)
	Recipes.holdGate = function(): boolean
		return not mi:busy()
	end
	local nodes = Nodes.new(view, mi)
	local links = Links.new(view)
	local plates = Plates.new(view, nodes)
	local markers = Markers.new(markerGui, view, nodes)
	local hud = Hud.new(topbarGui, hudGui)
	local store = ViewStore.new()

	-- ------------------------------------------------------------------------------------------ state
	local actRemote: RemoteEvent? = nil
	local readyRemote: RemoteEvent? = nil
	local lastMs: MapState? = nil
	local gotFirst = false -- the first full view arrived
	local firstAt = 0
	local preloaded = false
	local introDone = false
	local fatal = false
	local lastPatchAt = 0
	local reconnecting = false
	local statusOff = false
	local outOfSync = false
	local errorAt = -math.huge
	local wasInside: boolean? = nil
	local endShown = false

	local panelKey: string? = nil -- the layer (or "options-tab") the panel shows
	local intent: { key: string?, at: number }? = nil -- the client's own open / close, until map.open confirms it
	local geoMode: string? = nil -- "side" | "full" while the panel is open
	local appliedSx: number? = nil
	local lastLayer: string? = nil -- the last layer opened (the phone start framing, the fly back)
	local opening = false
	local fullToken = 0

	-- ------------------------------------------------------------------------------------------ actions
	local function fire(a: any, hold: boolean?)
		local r = actRemote
		if r == nil or type(a) ~= "table" or type(a[1]) ~= "string" then return end
		r:FireServer(a, hold == true)
	end
	local lastPress = 0
	local function resync()
		local r = readyRemote
		if r then r:FireServer() end
	end

	-- ------------------------------------------------------------------------------------------ the panel
	local function panelTip(html: string?, over: GuiObject?)
		if html == nil then
			overlay:tooltip(over, nil)
			return
		end
		if Input.kind() ~= "mouse" then return end
		overlay:tooltip(over, { title = "", body = html, layer = panelKey }, Input.pointer())
	end
	local panel = Panel.new(panelGui, { store = store, tip = panelTip })
	panel:setBand(Layout.mode == "COMPACT")

	local function titleOf(key: string): string
		local ms = lastMs
		return Signatures.title(key, if ms then ms.nodes[key] else nil)
	end
	-- the map's input and art run only while it shows (DESIGN.md 3.6: a full-screen sheet disables the map)
	local function mapShown()
		local on = geoMode ~= "full"
		mapGui.Enabled = on
		markerGui.Enabled = on
		markers:setEnabled(on)
		mi:setEnabled(on)
		view:setAmbient(on)
	end
	local function stripRect(sx: number): ARect
		local ro, rs = mapRoot.AbsolutePosition, mapRoot.AbsoluteSize
		return { x = ro.X, y = ro.Y, w = math.max(1, sx - ro.X), h = rs.Y }
	end
	-- the map beside the panel: the strip (side) or nothing (full), or the whole screen again (closed)
	local function applyGeometry(animate: boolean)
		local key = panelKey
		if key == nil then
			local was = geoMode
			geoMode, appliedSx = nil, nil
			Layout.setSheet(nil)
			view:setRect(nil, { animate = animate and was == "side", time = 0.16 })
			view:setForegroundOpen(true)
			hud:setPanel(nil)
			if was == "full" then mapShown() end
			return
		end
		local g = panel:geometry()
		if g.mode == "side" and g.sx then
			local was = geoMode
			geoMode, appliedSx = "side", g.sx
			Layout.setSheet(g.sx)
			local r = stripRect(g.sx :: number)
			view:setRect(r, { animate = animate })
			view:setForegroundOpen(false)
			hud:setPanel({ layer = key, mode = "side", strip = r, title = titleOf(key) })
			if was == "full" then mapShown() end
		else
			local was = geoMode
			geoMode, appliedSx = "full", nil
			Layout.setSheet(nil)
			hud:setPanel({ layer = key, mode = "full", title = titleOf(key) })
			if was ~= "full" then
				-- the map switches off after the sheet's slide
				fullToken += 1
				local my = fullToken
				local function off()
					if fullToken == my and geoMode == "full" then mapShown() end
				end
				if animate and not Motion.reduced() then task.delay(0.24, off) else off() end
			end
		end
	end
	local function showPanel(key: string, node: any?, fly: boolean)
		local was = panelKey
		panelKey = key
		opening = true
		overlay:peek(nil)
		overlay:detail(nil)
		panel:open(key, node)
		opening = false
		nodes:setSelected(if key ~= "options-tab" then key else nil)
		if key ~= "options-tab" then lastLayer = key end
		local g = panel:geometry()
		if was == nil or g.mode ~= geoMode or (g.mode == "side" and g.sx ~= appliedSx) then
			applyGeometry(true)
		else
			hud:setPanel({ layer = key, mode = geoMode or "side", strip = if appliedSx then stripRect(appliedSx :: number) else nil,
				title = titleOf(key) })
		end
		-- fly the node to the centre of the strip (DESIGN.md 3.5); a panel without a node never flies
		if fly and key ~= "options-tab" and geoMode == "side" then view:focusWorld(nodes:worldPos(key)) end
	end
	local function hidePanel(flyBack: boolean)
		local key = panelKey
		if key == nil then return end
		local wasFull = geoMode == "full"
		panelKey = nil
		panel:close()
		overlay:detail(nil)
		nodes:setSelected(nil)
		applyGeometry(true)
		-- closing a full-screen sheet flies back to the node that was open (DESIGN.md 3.3)
		if wasFull and flyBack and key ~= "options-tab" then view:focusWorld(nodes:worldPos(key)) end
	end
	local function requestClose(flyBack: boolean?)
		if panelKey == nil then return end
		local ms = lastMs
		if ms and ms.close and (ms.open ~= nil or intent ~= nil) then fire(ms.close) end
		intent = { key = nil, at = os.clock() }
		hidePanel(flyBack ~= false)
	end
	local function openLayer(layer: string, fly: boolean?)
		local ms = lastMs
		if ms == nil or store.ended then return end
		local node = ms.nodes[layer]
		local st = nodes:state(layer)
		if node == nil or not node.show or st == "dormant" or st == "sealed" or st == "frontier" then
			if st == "dormant" then overlay:toasts(nil, { UNIVERSE_WORD[MapLogic.MULTIVERSE[layer] == true] }) end
			return
		end
		if panelKey == layer then
			-- the selected node: nothing to send; fly back to it if the camera moved away
			overlay:peek(nil)
			if geoMode == "side" then view:focusWorld(nodes:worldPos(layer)) end
			return
		end
		if ms.open ~= layer or intent ~= nil then fire(node.a) end
		intent = { key = layer, at = os.clock() }
		showPanel(layer, node, fly ~= false)
	end
	local function openOptions()
		local ms = lastMs
		if ms == nil or store.ended or panelKey == "options-tab" then return end
		if ms.open ~= "options-tab" or intent ~= nil then fire(ms.opt) end
		intent = { key = "options-tab", at = os.clock() }
		showPanel("options-tab", nil, false)
	end
	-- follow the server's open layer (plan 1.12 "the server moves the tab")
	local function syncPanel(ms: MapState)
		if store.ended or not ms.ok then return end
		local open = ms.open
		local it = intent
		if it then
			if open == it.key then
				intent = nil
			elseif os.clock() - it.at < INTENT_WAIT then
				return
			else
				intent = nil
			end
		end
		if open == panelKey then return end
		if open == nil then
			hidePanel(false)
		else
			showPanel(open, ms.nodes[open], false)
		end
	end

	panel.act:Connect(function(a: any, hold: boolean?)
		if type(a) ~= "table" then return end
		if a[1] == "tab" and type(a[2]) == "string" then
			-- a panel button that moves the panel (a signature's shortcut to Options, a layer link) opens it the
			-- same way a tap does
			if a[2] == "none" then
				requestClose()
			elseif a[2] == "options-tab" then
				openOptions()
			else
				openLayer(a[2])
			end
			return
		end
		if hold ~= true then
			if os.clock() - lastPress < 0.03 then return end
			lastPress = os.clock()
		end
		fire(a, hold)
	end)
	panel.closeRequested:Connect(function() requestClose() end)
	panel.detail:Connect(function(card: any)
		overlay:detail({ id = card.id, kind = card.kind, node = card.node, layer = card.layer, get = function(id: string): any
			return store:get(id)
		end })
	end)
	panel.flyTo:Connect(function(layer: string) openLayer(layer) end)
	panel.geometryChanged:Connect(function(g: any)
		if opening or panelKey == nil then return end
		if g.mode ~= geoMode or (g.mode == "side" and g.sx ~= appliedSx) then applyGeometry(false) end
	end)
	Layout.changed:Connect(function()
		panel:setBand(Layout.mode == "COMPACT")
	end)

	-- ------------------------------------------------------------------------------------------ camera helpers
	local function nodeBox(list: { string }): ARect?
		if #list == 0 then return nil end
		local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
		for _, l in list do
			local p = nodes:worldPos(l)
			x0, y0 = math.min(x0, p.X - 110), math.min(y0, p.Y - 110)
			x1, y1 = math.max(x1, p.X + 110), math.max(y1, p.Y + 150)
		end
		return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
	end
	-- the shown nodes of the current universe (frameNodes, DESIGN.md 3.3)
	local function shownNodes(): { string }
		local out = {}
		local ms = lastMs
		if ms == nil then return out end
		for _, l in ms.order do
			if l ~= "ach" then
				local st = nodes:state(l)
				if st ~= "sealed" and st ~= "frontier" and st ~= "dormant" then table.insert(out, l) end
			end
		end
		return out
	end
	local function vSize(): MapCamera.Size
		local cam = view:camera()
		return { w = cam.V.X, h = cam.V.Y }
	end
	-- the phone start framing's focus (DESIGN.md 3.3): a new player's M at 60 %; the READY centroid; the last layer
	local function homeFocus(): (Vector2?, number?)
		local h = store:hud()
		if h and h.fr then return nodes:worldPos("m"), 0.6 end
		if Layout.mode ~= "COMPACT" then return nil, nil end
		local ms = lastMs
		if ms then
			local sum, n = Vector2.zero, 0
			for _, list in { ms.ready, ms.canBuy } do
				for _, l in list do
					sum += nodes:worldPos(l)
					n += 1
				end
			end
			if n > 0 then return sum / n, nil end
		end
		if lastLayer then return nodes:worldPos(lastLayer), nil end
		return nil, nil
	end
	local function homeTarget(): (Vector2, number)
		local V = vSize()
		local safe = view:safeRect()
		local ms = lastMs
		if ms and ms.inside then
			local bb = nodeBox(shownNodes())
			if bb then
				local c, z = MapCamera.frameRect(bb, V, safe)
				return Vector2.new(c.x, c.y), z
			end
		end
		local focus, fy = homeFocus()
		local c, z = MapCamera.startFraming(V, safe, Layout.mode, if focus then { x = focus.X, y = focus.Y } else nil, fy)
		return Vector2.new(c.x, c.y), z
	end
	-- the first frame of the realm (with the intro dolly-out outside the Multiverse)
	local function frameBoot()
		local ms = lastMs
		if ms and ms.inside then
			local C, z = homeTarget()
			view:setCamera(C, z)
			return
		end
		local focus, fy = homeFocus()
		view:frameStart({ focus = focus, focusY = fy, intro = true })
	end
	-- HOME: fly to the start framing; already there, toggle to the overview (zMin)
	local function flyHome()
		local C, z = homeTarget()
		local cam = view:camera()
		local atHome = (cam.C - C).Magnitude * cam.z < 12 and math.abs(math.log(cam.z / z)) < 0.03
		if atHome then
			local V = vSize()
			view:flyTo(Vector2.new(MapCamera.WORLD.cx, MapCamera.WORLD.cy), MapCamera.zMin(V), { time = 0.6, ease = "quintInOut" })
		else
			view:flyTo(C, z, { time = 0.6, ease = "quintInOut" })
		end
	end
	local function flyToLayer(layer: string)
		if geoMode == "full" then requestClose(false) end
		view:focusWorld(nodes:worldPos(layer))
	end
	local function openGate()
		if geoMode == "full" then requestClose(false) end
		view:focusWorld(RIFT)
		task.delay(0.3, function()
			local ms = lastMs
			overlay:modal("gate", if ms then ms.gate else nil)
		end)
	end

	-- ------------------------------------------------------------------------------------------ tooltips
	local function nodeTip(layer: string): any
		local ms = lastMs
		local node = if ms then ms.nodes[layer] else nil
		local st = nodes:state(layer)
		if st == "sealed" or st == "frontier" then
			return { title = "???", body = "Not discovered yet.", layer = layer, hue = Theme.C.muted }
		end
		if st == "dormant" then
			local nm = MapLogic.NAMES[layer]
			return { title = if nm then string.sub(nm, 1, 1) .. string.lower(string.sub(nm, 2)) else layer,
				body = UNIVERSE_WORD[MapLogic.MULTIVERSE[layer] == true], layer = layer }
		end
		if node == nil then return nil end
		local v = node.val
		local title = node.name or layer
		if st == "locked" then title ..= " · Locked" end
		local content: any = { title = title, body = v and v.tip, layer = layer, foot = "Click to open · right-click to peek" }
		if v and not v.lit and v.req then
			content.rows = { { "Need", v.req .. " " .. MapLogic.unit(v.rres) } }
			if v.pr then content.pr = v.pr / 1000 end
		end
		return content
	end
	nodes.hover:Connect(function(layer: string?, abs: Vector2)
		if layer == nil then
			overlay:tooltip("node", nil)
			return
		end
		overlay:tooltip("node", nodeTip(layer), abs)
	end)
	nodes.rift:Connect(function(event: string, abs: Vector2)
		local ms = lastMs
		local gate = ms and ms.gate
		if event == "leave" then
			overlay:tooltip("rift", nil)
		elseif event == "hover" then
			if gate and gate.show then
				overlay:tooltip("rift", { title = "Prestige Multiverse", body = gate.h or "The rift is open.",
					foot = "Click to fly there", hue = CRIMSON }, abs)
			else
				local req = gate and gate.req
				overlay:tooltip("rift", { title = "The rift is sealed", body = "Reach 185 milestones to reveal the Prestige Multiverse.",
					rows = if req then { { "Need", req.need .. " milestones" }, { "Have", req.have .. " milestones" } } else nil,
					pr = if req then req.pr / 1000 else nil, foot = "Click to fly there", hue = CRIMSON }, abs)
			end
		elseif event == "click" then
			openGate()
		end
	end)
	local warnOpen = false
	hud.warnTap:Connect(function(abs: Vector2)
		local h = store:hud()
		warnOpen = not warnOpen
		if not warnOpen or h == nil then
			overlay:tooltip("warn", nil)
			return
		end
		local rows = {}
		for _, w in h.w do table.insert(rows, { string.upper(string.sub(w.k, 1, 1)) .. string.sub(w.k, 2) .. " from", w.v }) end
		overlay:tooltip("warn", { title = "Point production is slowed", body = h.wh or h.x, rows = rows, hue = GOLD }, abs)
		task.delay(6, function()
			if warnOpen then
				warnOpen = false
				overlay:tooltip("warn", nil)
			end
		end)
	end)

	-- ------------------------------------------------------------------------------------------ map, HUD, overlay
	nodes.activated:Connect(function(layer: string) openLayer(layer) end)
	nodes.peek:Connect(function(layer: string)
		local ms = lastMs
		local st = nodes:state(layer)
		if ms == nil or st == "sealed" or st == "frontier" or st == "dormant" then return end
		nodes:setPeek(layer)
		overlay:peek(layer, ms.nodes[layer], nodes:ringRect(layer))
	end)
	mi.emptyTap:Connect(function()
		-- a tap on the strip's empty map closes the side sheet (DESIGN.md 5.1)
		if panelKey and geoMode == "side" then requestClose() end
	end)
	markers.activated:Connect(function(layer: string) view:focusWorld(nodes:worldPos(layer)) end)
	view.cameraChanged:Connect(function(cam: any) hud:setZoomPct(cam.z) end)
	hud:setZoomPct(view:camera().z)

	hud.home:Connect(function()
		overlay:peek(nil)
		local wasOpen = panelKey ~= nil
		requestClose(false)
		if wasOpen then task.delay(0.26, flyHome) else flyHome() end
	end)
	hud.trophies:Connect(function()
		if panelKey == "ach" then requestClose() else openLayer("ach") end
	end)
	hud.options:Connect(function()
		if panelKey == "options-tab" then requestClose() else openOptions() end
	end)
	hud.portal:Connect(openGate)
	hud.zoomIn:Connect(function() mi:zoomStep(1) end)
	hud.zoomOut:Connect(function() mi:zoomStep(-1) end)
	hud.bandClose:Connect(function() requestClose() end)
	hud.bandSwitch:Connect(function(layer: string) openLayer(layer) end)
	hud.readyTap:Connect(function(layer: string) openLayer(layer) end)
	hud.readyHold:Connect(function(layer: string)
		local ms = lastMs
		local node = if ms then ms.nodes[layer] else nil
		local v = node and node.val
		if v and v.ra then fire(v.ra) end
	end)
	hud.readyMore:Connect(function()
		local ms = lastMs
		if ms == nil then return end
		local list = table.clone(ms.ready)
		for _, l in ms.canBuy do table.insert(list, l) end
		local bb = nodeBox(list)
		if bb then view:frameWorld(bb, { time = 0.9 }) end
	end)
	hud.gateHold:Connect(function()
		local ms = lastMs
		local gate = ms and ms.gate
		if gate and gate.a then fire(gate.a) end
	end)

	overlay.act:Connect(function(a: any, hold: boolean?)
		fire(a, hold)
	end)
	overlay.flyTo:Connect(flyToLayer)
	overlay.openLayer:Connect(function(layer: string) openLayer(layer) end)
	overlay.peekClosed:Connect(function() nodes:setPeek(nil) end)
	overlay.resync:Connect(resync)

	Prefs.changed:Connect(function(key: string)
		if key == "detail" then view:setTier(MapView.chooseTier()) end
	end)

	-- ------------------------------------------------------------------------------------------ patches
	local function onStatus(patch: any)
		local off = patch.unsaved == true
		if reconnecting then return end
		if off then
			hud:setStatus("off")
		elseif patch.save == "saving" or patch.save == "saved" then
			hud:setStatus(patch.save)
		elseif statusOff then
			hud:setStatus(nil)
		end
		statusOff = off
	end
	local function onEnded(first: boolean, changes: any)
		if not (changes.ended or first) then return end
		if store.ended then
			hidePanel(false)
			setScreen("end", store:endScreen())
		elseif endShown and screenKind == "end" then
			setScreen(nil)
		end
		endShown = store.ended
	end
	local function apply(patch: any)
		local changes = store:apply(patch)
		local first = false
		if changes.full then
			if not gotFirst then
				gotFirst, firstAt, first = true, os.clock(), true
			end
			if outOfSync then
				outOfSync = false
				if screenKind == "outOfSync" then setScreen(nil) end
			end
		end
		local ms = store:map()
		if changes.map or changes.full then
			lastMs = ms
			nodes:update(ms)
			links:update(ms)
			plates:update(ms)
			markers:update(ms)
			hud:updateMap(ms)
		end
		if changes.hud or changes.full then
			local h = store:hud()
			if h then
				nodes:setFirstRun(h.fr)
				hud:setFirstRun(h.fr)
				hud:updateHud(h)
			end
		end
		if changes.tab or changes.tabName or changes.full then
			panel:update(store, changes)
			overlay:detailRefresh()
		end
		if first then
			-- the realm is home: a layer the last session left open is closed (and remembered)
			if ms.open and not store.ended then
				if ms.open ~= "options-tab" then lastLayer = ms.open end
				if ms.close then fire(ms.close) end
				intent = { key = nil, at = os.clock() }
			end
		end
		syncPanel(ms)
		onEnded(first, changes)
		-- a universe change: the camera frames the other side, with a flash (DESIGN.md 3.5)
		if ms.ok then
			if wasInside ~= nil and wasInside ~= ms.inside then
				overlay:flash(if ms.inside then CRIMSON else VIOLET)
				if geoMode ~= "full" then
					local bb = nodeBox(shownNodes())
					if bb then view:frameWorld(bb, { time = 0.9 }) end
				end
			end
			wasInside = ms.inside
		end
		-- toasts
		local notices = patch.notice
		if patch.pop or (notices and #notices > 0) then overlay:toasts(patch.pop, notices) end
		onStatus(patch)
	end
	local function onError(err: any)
		warn("[MilestoneTree] drawing the screen failed: " .. tostring(err))
		if os.clock() - errorAt < 10 then
			outOfSync = true
			setScreen("outOfSync")
		else
			resync()
		end
		errorAt = os.clock()
	end
	local function onPatch(patch: any)
		if type(patch) ~= "table" then return end
		lastPatchAt = os.clock()
		if reconnecting then
			reconnecting = false
			hud:setStatus(if statusOff then "off" else nil)
		end
		if patch.fatal then
			fatal = true
			setScreen("fatal", tostring(patch.fatal))
			return
		end
		if patch.status then
			if not gotFirst and not fatal then overlay:screen("loading", tostring(patch.status)) end
			return
		end
		local ok, err = pcall(function()
			apply(patch)
		end)
		if not ok then onError(err) end
	end

	-- ------------------------------------------------------------------------------------------ keyboard
	Hotkeys.start({
		active = function(): boolean
			return not fatal
		end,
		keys = function(): { [string]: true }
			return store.keys
		end,
		send = function(name: string)
			fire({ "key", name })
		end,
		zoom = function(dir: number)
			if geoMode ~= "full" then mi:zoomStep(dir) end
		end,
		escape = function()
			if overlay:escape() then return end
			if panelKey then requestClose() end
		end,
	})

	-- ------------------------------------------------------------------------------------------ the loop
	local function loadingDone(): boolean
		return gotFirst and (preloaded or os.clock() - firstAt > 3)
	end
	local function step(dt: number)
		mi:step(dt)
		view:step(dt)
		Motion.step(dt)
		if not introDone and loadingDone() and not fatal then
			introDone = true
			if screenKind == "loading" then setScreen(nil) end
			frameBoot()
		end
		if gotFirst and not reconnecting and not fatal and os.clock() - lastPatchAt > RECONNECT_AFTER then
			reconnecting = true
			hud:setStatus("reconnecting")
		end
	end
	local okPre = pcall(function()
		(RunService :: any).PreRender:Connect(step)
	end)
	if not okPre then RunService.RenderStepped:Connect(step) end

	task.spawn(function()
		view:preload(function(done: number, total: number)
			if screenKind == "loading" then overlay:screen("loading", { done = done, total = total }) end
		end)
		preloaded = true
	end)

	-- ------------------------------------------------------------------------------------------ the server
	local found: Instance? = nil
	while found == nil do
		found = ReplicatedStorage:WaitForChild("MilestoneTreeRemotes", 10)
		if found == nil and screenKind == "loading" then overlay:screen("loading", "Waiting for the server…") end
	end
	local folder = found :: Instance
	local viewRemote = folder:WaitForChild("View") :: RemoteEvent
	actRemote = folder:WaitForChild("Act") :: RemoteEvent
	readyRemote = folder:WaitForChild("Ready") :: RemoteEvent
	viewRemote.OnClientEvent:Connect(onPatch)
	resync()
	lastPatchAt = os.clock()
end

return App
