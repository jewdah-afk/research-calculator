--!strict
--[[
	MapView: the realm map's GUI tree and camera (art/REALM.md 9, DESIGN.md 3.1-3.6).

	    local view = MapView.new(gui, root, { tier = "HIGH" })
	    view.box / view.links / view.nodes / view.plates        containers the node widgets, links and plates go in
	    view.cameraChanged:Connect(function(cam) ... end)        after the writes of every frame the camera moved
	    view:setCamera(C, z, rubber?)   view:flyTo(C, z, { time, ease })   view:focusWorld(p)   view:frameWorld(bbox)
	    view:frameStart({ mode, focus, focusY, intro })          the HUD-safe start framing (DESIGN.md 3.3)
	    view:setRect(absRect?, { animate })                      the Box-resize strip beside a side sheet (3.6)
	    view:worldToAbs(p), view:absToWorld(q), view:absToMap(q)
	    view:setTier("LOW"), view:setReduced(b), view:setAmbient(on), view:setForegroundOpen(open), view:preload(cb)
	    view:step(dt)                                            once a frame (App's PreRender loop)

	The tree (REALM.md 9.1, siblings take ZIndex = their place in the list):
	    Root (black) > Box (whole device px, ClipsDescendants, no UIScale)
	      L0_sky, L1_clouds, L2_far, L3_mid     planes: Back (clouds only), Tile_i_j..., Sprites (the moving container)
	      Wash, L4_near (Back, tiles, Sprites), F_motesFar, L5_world, L6_fg, F_motesNear
	      Links, Nodes                          moving containers with the world transform (x / 3840, y / 2560 inside)
	      F_particles, Vignette
	      Plates                                full Box, sized Box / s in offset under UIScale s (constant UI size)
	Positions are Scale units of the Box; only tiles are written in offset, snapped to whole device pixels (9.3).
	At rest nothing is written except the particle fields (they drift). Tiles with no asset id are skipped; a missing
	sky or world gets the procedural fallback (Fallback.luau); without the realm atlas there are no ambient sprites.
]]

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Prefs = require(Core:WaitForChild("Prefs"))
local MapCamera = require(script.Parent:WaitForChild("MapCamera"))
local Ambient = require(script.Parent:WaitForChild("Ambient"))
local Fields = require(script.Parent:WaitForChild("Fields"))
local Fallback = require(script.Parent:WaitForChild("Fallback"))

type Camera = Types.Camera
type ARect = Types.Rect
type Pt = MapCamera.Pt
type Size = MapCamera.Size
type Weights = MapCamera.Weights

local MapView = {}

local WORLD = MapCamera.WORLD
local FIELD_ORDER = { motesFar = "F_motesFar", motesNear = "F_motesNear", particles = "F_particles" }

local function quintInOut(u: number): number
	return if u < 0.5 then 16 * u ^ 5 else 1 - ((-2 * u + 2) ^ 5) / 2
end
local EASES: { [string]: (number) -> number } = {
	linear = MapCamera.EASE.linear,
	quadOut = MapCamera.EASE.quadOut,
	quintOut = MapCamera.EASE.quintOut,
	sineInOut = MapCamera.EASE.sineInOut,
	quintInOut = quintInOut,
	quadIn = function(u: number): number return u * u end,
}

-- REALM.md 9.5: LOW on touch-only devices, small displays and low graphics quality; Options can override
function MapView.chooseTier(): string
	local detail = Prefs.get().detail
	if detail == "HIGH" or detail == "LOW" then return detail end
	local low = false
	pcall(function()
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then low = true end
		if GuiService.ViewportDisplaySize == Enum.DisplaySize.Small then low = true end
	end)
	pcall(function()
		local settings = UserSettings():GetService("UserGameSettings")
		local q = settings.SavedQualityLevel
		if q == Enum.SavedQualitySetting.QualityLevel1 or q == Enum.SavedQualitySetting.QualityLevel2
			or q == Enum.SavedQualitySetting.QualityLevel3 then
			low = true
		end
	end)
	return if low then "LOW" else "HIGH"
end

type TileRec = { gui: ImageLabel, i: number, j: number }
type LayerRec = {
	def: any, -- Realm layer { id, depth, f, w, h, ax, ay, zHide, zShow, opaque, back, tint }
	plane: Frame,
	sprites: Frame,
	back: Frame?,
	tiles: { TileRec },
	xs: { [number]: number },
	ys: { [number]: number },
	tintKey: string,
	alpha: number, -- last written tile alpha (fg fade)
}
type Flight = {
	mode: string, -- "damp" | "ease"
	C: Pt,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	smooth: number,
	C0: Pt,
	z0: number,
	t: number,
	time: number,
	ease: (number) -> number,
}
type RectAnim = { from: ARect, to: ARect?, t: number, time: number, ease: (number) -> number }

export type MapView = {
	gui: ScreenGui,
	root: Frame,
	box: Frame,
	links: Frame,
	nodes: Frame,
	plates: Frame,
	cameraChanged: Signal.Signal<Camera>,
	tier: string,
	art: { tiles: number, uploaded: number, atlas: boolean },
	inputActive: boolean, -- set by MapInput while a finger, mouse or wheel is driving the camera

	camera: (self: MapView) -> Camera,
	setCamera: (self: MapView, C: Vector2, z: number, rubber: boolean?) -> (),
	flyTo: (self: MapView, C: Vector2, z: number, o: { time: number?, ease: string? }?) -> (),
	cancelFly: (self: MapView) -> (),
	isFlying: (self: MapView) -> boolean,
	focusWorld: (self: MapView, p: Vector2, o: { zoom: number?, time: number? }?) -> (),
	frameWorld: (self: MapView, bbox: ARect, o: { time: number? }?) -> (),
	frameStart: (self: MapView, o: { mode: string?, focus: Vector2?, focusY: number?, intro: boolean? }?) -> (),
	setRect: (self: MapView, r: ARect?, o: { animate: boolean?, time: number?, ease: string? }?) -> (),
	setTier: (self: MapView, t: string) -> (),
	setReduced: (self: MapView, b: boolean) -> (),
	setAmbient: (self: MapView, on: boolean) -> (),
	setForegroundOpen: (self: MapView, open: boolean) -> (),
	setRiftHover: (self: MapView, on: boolean) -> (),
	worldToAbs: (self: MapView, p: Vector2) -> Vector2,
	absToWorld: (self: MapView, q: Vector2) -> Vector2,
	absToMap: (self: MapView, q: Vector2) -> Vector2,
	safeRect: (self: MapView) -> MapCamera.Rect,
	freeRect: (self: MapView) -> MapCamera.Rect,
	preload: (self: MapView, onProgress: ((done: number, total: number) -> ())?) -> (),
	step: (self: MapView, dt: number) -> (),
	destroy: (self: MapView) -> (),
}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(math.clamp(math.floor(t[1] + 0.5), 0, 255), math.clamp(math.floor(t[2] + 0.5), 0, 255),
		math.clamp(math.floor(t[3] + 0.5), 0, 255))
end
local function frame(parent: Instance, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	f.ZIndex = z
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = parent
	return f
end
local function hasId(id: any): boolean
	return type(id) == "string" and id ~= ""
end

function MapView.new(gui: ScreenGui, root: Frame, o: { assets: any?, realm: any?, tier: string? }?): MapView
	local opts: { assets: any?, realm: any?, tier: string? } = o or {}
	local realm: any = opts.realm or require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Realm"))
	local assets: any = opts.assets
	if assets == nil then
		local ok, a = pcall(function(): any
			local m: any = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Assets"))
			return m
		end)
		assets = if ok then a else nil
	end
	local lp = Players.LocalPlayer
	local assume = lp ~= nil and lp:GetAttribute("MT_AssumeAssets") == true
	Theme.detect()

	local self = {} :: MapView
	self.gui = gui
	self.root = root
	self.cameraChanged = Signal.new() :: Signal.Signal<Camera>
	self.tier = opts.tier or MapView.chooseTier()
	self.art = { tiles = 0, uploaded = 0, atlas = false }
	self.inputActive = false

	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 0
	local box = frame(root, "Box", 1)
	box.ClipsDescendants = true
	self.box = box

	-- ------------------------------------------------------------------------------------------ state
	local C: Pt = { x = MapCamera.START.x, y = MapCamera.START.y }
	local z = 0.6
	local V: Size = { w = 1920, h = 1080 }
	local m = 1
	local boxW, boxH = 1920, 1080
	local rect: ARect? = nil -- the available area (abs); nil = the whole root
	local rectAnim: RectAnim? = nil
	local flight: Flight? = nil
	local dirty = true
	local reduced = Motion.reduced()
	local ambientOn = true
	local fgOpen = true
	local fgK = 1 -- the side-sheet factor of fg + motesNear, eased over 0.2 s
	local w: Weights = { rift = 0, corrupt = 0, cover = 0 }
	local wTarget: Weights = { rift = 0, corrupt = 0, cover = 0 }
	local wWritten = { rift = -1, corrupt = -1 }
	local lastColorCam = { x = math.huge, y = math.huge, z = 0 }
	local clock0 = os.clock()
	local spring = { x = 0, y = 0, z = 0 } -- SmoothDamp velocities of the spring back

	local layers: { LayerRec } = {}
	local byId: { [string]: LayerRec } = {}
	local fieldFrames: { [string]: Frame } = {}
	local ambient: Ambient.Ambient? = nil
	local fields: Fields.Fields? = nil
	local fallbackWorld: Fallback.World? = nil
	local fallbackTweens: { Tween } = {}
	local fallbackMade: { Instance } = {}
	local tileCount = 0

	-- ------------------------------------------------------------------------------------------ the tree
	local z0 = 0
	local function nextZ(): number
		z0 += 1
		return z0
	end
	local names = { sky = "L0_sky", clouds = "L1_clouds", far = "L2_far", mid = "L3_mid", near = "L4_near", world = "L5_world", fg = "L6_fg" }
	local wash: Frame
	local vignette: ImageLabel? = nil
	local vignetteFrame: Frame? = nil
	local links: Frame
	local nodesF: Frame
	local plates: Frame
	local platesScale: UIScale
	for _, def in realm.layers do
		local plane = frame(box, names[def.id] or ("L_" .. def.id), nextZ())
		local back: Frame? = nil
		if def.back then
			back = frame(plane, "Back", 1)
		end
		local sprites = frame(plane, "Sprites", 3)
		local rec: LayerRec = { def = def, plane = plane, sprites = sprites, back = back, tiles = {}, xs = {}, ys = {}, tintKey = "", alpha = -1 }
		table.insert(layers, rec)
		byId[def.id] = rec
		if def.id == "mid" then
			wash = frame(box, "Wash", nextZ())
			wash.BackgroundTransparency = 1
		elseif def.id == "near" then
			fieldFrames.motesFar = frame(box, FIELD_ORDER.motesFar, nextZ())
		elseif def.id == "fg" then
			fieldFrames.motesNear = frame(box, FIELD_ORDER.motesNear, nextZ())
		end
	end
	links = frame(box, "Links", nextZ())
	nodesF = frame(box, "Nodes", nextZ())
	fieldFrames.particles = frame(box, FIELD_ORDER.particles, nextZ())
	local vz = nextZ()
	plates = frame(box, "Plates", nextZ())
	platesScale = Instance.new("UIScale")
	platesScale.Parent = plates
	self.links, self.nodes, self.plates = links, nodesF, plates
	-- nodes and the rift hotspot take input; everything else in the map is inert. Interactable = false carries down to
	-- descendants, so it goes on each layer beside Nodes, never on the Box that holds Nodes.
	local function inert(c: Instance)
		if c ~= nodesF and c:IsA("GuiObject") then
			pcall(function() c.Interactable = false end)
		end
	end
	for _, c in box:GetChildren() do inert(c) end
	box.ChildAdded:Connect(inert)

	-- ------------------------------------------------------------------------------------------ art
	local function tierLayer(id: string): (any?, string)
		local tiers = assets and assets.tiers
		if tiers == nil then return nil, self.tier end
		local want = tiers[self.tier]
		local other = tiers[if self.tier == "LOW" then "HIGH" else "LOW"]
		local function uploaded(t: any): number
			if t == nil or t.layers[id] == nil then return 0 end
			local n = 0
			for _, tile in t.layers[id].tiles do
				if hasId(tile.id) then n += 1 end
			end
			return n
		end
		if assume or uploaded(want) > 0 or uploaded(other) == 0 then
			return if want then want.layers[id] else nil, self.tier
		end
		return other.layers[id], if self.tier == "LOW" then "HIGH" else "LOW"
	end
	local function atlasInfo(): Ambient.Atlas?
		local sp = assets and assets.sprites
		if sp == nil then return nil end
		local idWant = sp.atlas[self.tier]
		local id, k = idWant, if self.tier == "LOW" then 0.5 else 1
		if not hasId(id) then
			local otherTier = if self.tier == "LOW" then "HIGH" else "LOW"
			id = sp.atlas[otherTier]
			k = if otherTier == "LOW" then 0.5 else 1
		end
		if not hasId(id) then
			if assume then return { id = "", regions = sp.regions, k = if self.tier == "LOW" then 0.5 else 1 } end
			return nil
		end
		return { id = id, regions = sp.regions, k = k }
	end

	local function clearArt()
		if ambient then ambient:destroy() end
		ambient = nil
		if fields then fields:destroy() end
		fields = nil
		for _, t in fallbackTweens do t:Cancel() end
		table.clear(fallbackTweens)
		for _, inst in fallbackMade do inst:Destroy() end
		table.clear(fallbackMade)
		fallbackWorld = nil
		for _, rec in layers do
			for _, t in rec.tiles do t.gui:Destroy() end
			table.clear(rec.tiles)
			table.clear(rec.xs)
			table.clear(rec.ys)
			rec.tintKey = ""
			rec.alpha = -1
		end
		if vignette then vignette:Destroy() end
		vignette = nil
		if vignetteFrame then vignetteFrame:Destroy() end
		vignetteFrame = nil
		tileCount = 0
	end

	local function buildArt()
		clearArt()
		local gutter = (assets and assets.gutter) or 2
		local total, have = 0, 0
		local missing: { [string]: boolean } = {}
		for _, rec in layers do
			local id = rec.def.id
			local tl, usedTier = tierLayer(id)
			if tl == nil then
				missing[id] = true
				continue
			end
			local anyMissing = false
			-- layers grow around their centre (the pan margin, REALM.md 2.5): tiles cut for a different layer size (an
			-- Assets.luau older than Realm.luau) stay centred on the anchor, so the art keeps its registration
			local dx = if tl.w then (rec.def.w - tl.w) / 2 else 0
			local dy = if tl.h then (rec.def.h - tl.h) / 2 else 0
			for _, t in tl.tiles do
				total += 1
				rec.xs[t.i + 1] = t.x + dx
				rec.xs[t.i + 2] = t.x + t.w + dx
				rec.ys[t.j + 1] = t.y + dy
				rec.ys[t.j + 2] = t.y + t.h + dy
				local ok = hasId(t.id)
				if ok then have += 1 end
				if not ok and not assume then
					anyMissing = true
					continue
				end
				local img = Instance.new("ImageLabel")
				img.Name = string.format("Tile_%d_%d", t.i, t.j)
				img.BackgroundTransparency = 1
				img.BorderSizePixel = 0
				img.Active = false
				img.ZIndex = 2
				img.ScaleType = Enum.ScaleType.Stretch
				img.Image = if ok then t.id else ""
				img.ImageRectOffset = Vector2.new(gutter, gutter)
				img.ImageRectSize = Vector2.new(t.rw, t.rh)
				if assume then img:SetAttribute("Asset", string.format("%s/%s_%d_%d", usedTier, id, t.i, t.j)) end
				img.Parent = rec.plane
				table.insert(rec.tiles, { gui = img, i = t.i, j = t.j })
				tileCount += 1
			end
			if anyMissing then missing[id] = true end
		end
		self.art.tiles, self.art.uploaded = total, have
		-- the procedural look where the sky or the world has holes (plan 3.5)
		local sky, world = byId.sky, byId.world
		if sky and missing.sky then
			for _, inst in Fallback.sky(sky.plane, sky.sprites, { w = sky.def.w, h = sky.def.h }) do table.insert(fallbackMade, inst) end
		end
		if world and missing.world then
			local fw = Fallback.world(world.sprites, realm)
			fallbackWorld = fw
			for _, inst in fw.made do table.insert(fallbackMade, inst) end
			for _, t in Fallback.breathe(fw, reduced) do table.insert(fallbackTweens, t) end
		end
		-- sprites, blooms and fields need the realm atlas
		local atlas = atlasInfo()
		self.art.atlas = atlas ~= nil
		local infos = {}
		local containers, backs = {}, {}
		for _, rec in layers do
			local d = rec.def
			infos[d.id] = { id = d.id, f = d.f, w = d.w, h = d.h, ax = d.ax, ay = d.ay }
			containers[d.id] = rec.sprites
			if rec.back then backs[d.id] = rec.back end
		end
		ambient = Ambient.new({ realm = realm, layers = infos, containers = containers, backs = backs, atlas = atlas, tier = self.tier, reduced = reduced })
		fields = Fields.new({ realm = realm, frames = fieldFrames, atlas = atlas, tier = self.tier })
		if fields then
			fields:setReduced(reduced)
			fields:setEnabled(ambientOn)
		end
		if ambient then ambient:setPaused(not ambientOn) end
		-- the vignette: the atlas region (sampled through its inset rect) or a radial darkening
		if atlas and atlas.id ~= "" and atlas.regions.vignette then
			local v = Instance.new("ImageLabel")
			v.Name = "Vignette"
			v.BackgroundTransparency = 1
			v.BorderSizePixel = 0
			v.Active = false
			v.Size = UDim2.fromScale(1, 1)
			v.ZIndex = vz
			local r = (assets.sprites.sample and assets.sprites.sample.vignette) or atlas.regions.vignette
			v.Image = atlas.id
			v.ImageRectOffset = Vector2.new(r[1] * atlas.k, r[2] * atlas.k)
			v.ImageRectSize = Vector2.new(r[3] * atlas.k, r[4] * atlas.k)
			v.ImageColor3 = rgb(realm.biome.vignette.color)
			v.ImageTransparency = 1 - realm.biome.vignette.alpha
			v.Parent = box
			vignette = v
		elseif Theme.caps.Radial then
			local f = frame(box, "Vignette", vz)
			f.BackgroundTransparency = 0
			f.BackgroundColor3 = rgb(realm.biome.vignette.color)
			local g = Instance.new("UIGradient")
			g.Type = Enum.GradientType.Radial
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.62, 1),
				NumberSequenceKeypoint.new(1, 1 - realm.biome.vignette.alpha * 0.8),
			})
			g.Parent = f
			vignetteFrame = f
		end
		dirty = true
		wWritten.rift, wWritten.corrupt = -1, -1
		lastColorCam.x = math.huge
	end

	-- ------------------------------------------------------------------------------------------ box layout
	local function rootSize(): Vector2
		local s = root.AbsoluteSize
		if s.X < 2 or s.Y < 2 then
			local cam = workspace.CurrentCamera
			s = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
		end
		return s
	end
	-- the available rect in root-local px
	local function available(r: ARect?): (number, number, number, number)
		local rs = rootSize()
		if r == nil then return 0, 0, rs.X, rs.Y end
		local ro = root.AbsolutePosition
		local x0 = math.clamp(r.x - ro.X, 0, rs.X)
		local y0 = math.clamp(r.y - ro.Y, 0, rs.Y)
		local x1 = math.clamp(r.x + r.w - ro.X, x0 + 1, rs.X)
		local y1 = math.clamp(r.y + r.h - ro.Y, y0 + 1, rs.Y)
		return x0, y0, x1 - x0, y1 - y0
	end
	-- REALM.md 9.1: Box = the letterboxed mapScale box on whole device px; V = Box / m
	local function layoutBox(r: ARect?)
		local ax, ay, aw, ah = available(r)
		local ms = MapCamera.mapScale({ w = math.max(aw, 1), h = math.max(ah, 1) })
		local bw, bh = math.max(1, math.round(ms.box.w)), math.max(1, math.round(ms.box.h))
		box.Size = UDim2.fromOffset(bw, bh)
		box.Position = UDim2.fromOffset(ax + math.floor((aw - bw) / 2), ay + math.floor((ah - bh) / 2))
		boxW, boxH, m = bw, bh, ms.scale
		V = { w = bw / m, h = bh / m }
		local s = Layout.s
		platesScale.Scale = s
		plates.Size = UDim2.fromOffset(math.floor(bw / s + 0.5), math.floor(bh / s + 0.5))
		dirty = true
	end

	-- ------------------------------------------------------------------------------------------ camera
	local function applyClamp(rubber: boolean)
		local c = MapCamera.clampCamera(C, z, V, rubber)
		C = { x = c.x, y = c.y }
		z = c.z
	end
	function self.camera(_: MapView): Camera
		return { C = Vector2.new(C.x, C.y), z = z, V = Vector2.new(V.w, V.h), m = m }
	end
	function self.setCamera(_: MapView, c: Vector2, zz: number, rubber: boolean?)
		C = { x = c.X, y = c.Y }
		z = zz
		applyClamp(rubber == true and not reduced)
		dirty = true
	end
	function self.cancelFly(_: MapView)
		flight = nil
	end
	function self.isFlying(_: MapView): boolean
		return flight ~= nil
	end
	function self.flyTo(_: MapView, c: Vector2, zz: number, fo: { time: number?, ease: string? }?)
		local target = MapCamera.clampCamera({ x = c.X, y = c.Y }, zz, V, false)
		if reduced then
			flight = nil
			C = { x = target.x, y = target.y }
			z = target.z
			dirty = true
			return
		end
		local ease = fo and fo.ease
		if ease then
			flight = {
				mode = "ease", C = { x = target.x, y = target.y }, z = target.z, vx = 0, vy = 0, vz = 0, smooth = 0,
				C0 = { x = C.x, y = C.y }, z0 = z, t = 0, time = math.max(0.01, (fo and fo.time) or 0.35),
				ease = EASES[ease] or quintInOut,
			}
		else
			local vx, vy, vzz = 0, 0, 0
			if flight and flight.mode == "damp" then vx, vy, vzz = flight.vx, flight.vy, flight.vz end
			flight = {
				mode = "damp", C = { x = target.x, y = target.y }, z = target.z, vx = vx, vy = vy, vz = vzz,
				smooth = (fo and fo.time) or realm.feel.flySmoothTime, C0 = { x = C.x, y = C.y }, z0 = z, t = 0, time = 0,
				ease = quintInOut,
			}
		end
	end

	-- abs space <-> Box map points <-> world
	function self.absToMap(_: MapView, q: Vector2): Vector2
		local bp = box.AbsolutePosition
		return (q - bp) / m
	end
	function self.worldToAbs(_: MapView, p: Vector2): Vector2
		local bp = box.AbsolutePosition
		return Vector2.new(bp.X + m * (V.w / 2 + z * (p.X - C.x)), bp.Y + m * (V.h / 2 + z * (p.Y - C.y)))
	end
	function self.absToWorld(_: MapView, q: Vector2): Vector2
		local bp = box.AbsolutePosition
		return Vector2.new(C.x + ((q.X - bp.X) / m - V.w / 2) / z, C.y + ((q.Y - bp.Y) / m - V.h / 2) / z)
	end
	-- a Layout rect (abs) as Box map points, clipped to the Box
	local function toMapRect(r: ARect): MapCamera.Rect
		local bp = box.AbsolutePosition
		local x0 = math.clamp((r.x - bp.X) / m, 0, V.w)
		local y0 = math.clamp((r.y - bp.Y) / m, 0, V.h)
		local x1 = math.clamp((r.x + r.w - bp.X) / m, x0 + 1, V.w)
		local y1 = math.clamp((r.y + r.h - bp.Y) / m, y0 + 1, V.h)
		return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
	end
	function self.safeRect(_: MapView): MapCamera.Rect
		return toMapRect(Layout.safeStartRect())
	end
	function self.freeRect(_: MapView): MapCamera.Rect
		return toMapRect(Layout.free())
	end
	-- fly so world point p sits at the centre of the free rect, at zoom max(current, .9) (REALM.md 9.4, DESIGN.md 3.5)
	function self.focusWorld(_: MapView, p: Vector2, fo: { zoom: number?, time: number? }?)
		local zz = (fo and fo.zoom) or math.max(z, realm.feel.flyZoom)
		local target, tz = MapCamera.flyTarget({ x = p.X, y = p.Y }, zz, V, self:freeRect())
		self:flyTo(Vector2.new(target.x, target.y), tz, { time = fo and fo.time })
	end
	-- frameNodes (DESIGN.md 3.3): fit a world rect into the safe rect; a timed quintInOut flight when o.time is given
	function self.frameWorld(_: MapView, bbox: ARect, fo: { time: number? }?)
		local target, tz = MapCamera.frameRect(bbox, V, self:safeRect())
		local t = fo and fo.time
		self:flyTo(Vector2.new(target.x, target.y), tz, if t then { time = t, ease = "quintInOut" } else nil)
	end
	-- the HUD-safe start with the intro dolly-out from min(1.12 z0, zMax) over 1.6 s quintOut (none when reduced)
	function self.frameStart(_: MapView, fo: { mode: string?, focus: Vector2?, focusY: number?, intro: boolean? }?)
		local mode = (fo and fo.mode) or Layout.mode
		local focus = fo and fo.focus
		local C0, zs = MapCamera.startFraming(V, self:safeRect(), mode,
			if focus then { x = focus.X, y = focus.Y } else nil, fo and fo.focusY)
		flight = nil
		if fo and fo.intro and not reduced and not Motion.snapshot() then
			local zi = math.min(realm.camera.introFactor * zs, MapCamera.Z_MAX)
			local ci = MapCamera.clampCamera(C0, zi, V, false, MapCamera.NO_MARGIN)
			C, z = { x = ci.x, y = ci.y }, ci.z
			dirty = true
			self:flyTo(Vector2.new(C0.x, C0.y), zs, { time = realm.camera.introSeconds, ease = "quintOut" })
		else
			C, z = C0, zs
			dirty = true
		end
	end

	-- the Box-resize strip (DESIGN.md 3.6): C' = C + (Vc_new - Vc_old) / z keeps the world plane still
	local function resizeTo(r: ARect?)
		local oldVc = { x = V.w / 2, y = V.h / 2 }
		layoutBox(r)
		C = { x = C.x + (V.w / 2 - oldVc.x) / z, y = C.y + (V.h / 2 - oldVc.y) / z }
		if flight then
			flight.C.x += (V.w / 2 - oldVc.x) / z
			flight.C.y += (V.h / 2 - oldVc.y) / z
		end
		applyClamp(true)
	end
	local function fullRect(): ARect
		local ro, rs = root.AbsolutePosition, rootSize()
		return { x = ro.X, y = ro.Y, w = rs.X, h = rs.Y }
	end
	local function currentRect(): ARect
		if rect then return rect :: ARect end
		return fullRect()
	end
	function self.setRect(_: MapView, r: ARect?, ro: { animate: boolean?, time: number?, ease: string? }?)
		local from = currentRect()
		rect = r
		if ro and ro.animate and not reduced then
			rectAnim = { from = from, to = r, t = 0, time = ro.time or 0.24, ease = EASES[ro.ease or "quintOut"] or MapCamera.EASE.quintOut }
		else
			rectAnim = nil
			resizeTo(r)
		end
	end

	-- ------------------------------------------------------------------------------------------ switches
	function self.setTier(_: MapView, t: string)
		local nt = if t == "LOW" then "LOW" else "HIGH"
		if nt == self.tier and tileCount > 0 then return end
		self.tier = nt
		buildArt()
	end
	function self.setReduced(_: MapView, b: boolean)
		if b == reduced then return end
		reduced = b
		if b then
			flight = nil
			rectAnim = nil
			resizeTo(rect)
		end
		buildArt()
	end
	function self.setAmbient(_: MapView, on: boolean)
		if on == ambientOn then return end
		ambientOn = on
		if ambient then ambient:setPaused(not on) end
		if fields then fields:setEnabled(on) end
		for _, t in fallbackTweens do
			if on then t:Play() else t:Pause() end
		end
	end
	-- open = false while a side sheet is up: fg and motesNear fade out over 0.2 s (DESIGN.md 3.6)
	function self.setForegroundOpen(_: MapView, open: boolean)
		fgOpen = open
		if reduced then fgK = if open then 1 else 0 end
		dirty = true
	end
	function self.setRiftHover(_: MapView, on: boolean)
		if ambient then ambient:setRiftBoost(if on then 0.15 else 0) end
		local fw = fallbackWorld
		if fw and fw.core then
			Motion.tween(fw.core, TweenInfo.new(0.2), { BackgroundTransparency = if on then 0 else 0.15 }, "riftHover")
		end
	end

	-- ------------------------------------------------------------------------------------------ per frame
	local X: { [number]: number } = {}
	local Y: { [number]: number } = {}
	local function writeLayer(rec: LayerRec, zoomAlpha: number)
		local d = rec.def
		local ox, oy, s = MapCamera.layerOffset(d, C, z, V)
		local pos = UDim2.fromScale(ox / V.w, oy / V.h)
		local size = UDim2.fromScale(d.w * s / V.w, d.h * s / V.h)
		rec.sprites.Position = pos
		rec.sprites.Size = size
		local back = rec.back
		if back then
			back.Position = pos
			back.Size = size
		end
		local alpha = zoomAlpha
		local visible = alpha > 0.001
		if rec.plane.Visible ~= visible then rec.plane.Visible = visible end
		if not visible then return end
		if #rec.tiles > 0 then
			table.clear(X)
			table.clear(Y)
			MapCamera.snapEdges(rec.xs, m, ox, s, X)
			MapCamera.snapEdges(rec.ys, m, oy, s, Y)
			local writeAlpha = alpha ~= rec.alpha
			for _, t in rec.tiles do
				local x0, x1 = X[t.i + 1], X[t.i + 2]
				local y0, y1 = Y[t.j + 1], Y[t.j + 2]
				if x0 == nil or x1 == nil or y0 == nil or y1 == nil then continue end
				local on = x1 > 0 and x0 < boxW and y1 > 0 and y0 < boxH
				if t.gui.Visible ~= on then t.gui.Visible = on end
				if on then
					t.gui.Position = UDim2.fromOffset(x0, y0)
					t.gui.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
				end
				if writeAlpha then t.gui.ImageTransparency = 1 - alpha end
			end
		end
		rec.alpha = alpha
	end
	local function writeColors(force: boolean)
		local moved = math.abs(w.rift - wWritten.rift) > 0.01 or math.abs(w.corrupt - wWritten.corrupt) > 0.01
		if not moved and not force then return end
		if moved then
			for _, rec in layers do
				local tint = rec.def.tint
				if tint then
					local col = rgb(MapCamera.biomeTint(tint, w))
					for _, t in rec.tiles do t.gui.ImageColor3 = col end
				end
			end
			local c, a = MapCamera.biomeWash(realm.biome.wash, w)
			wash.BackgroundColor3 = rgb(c)
			wash.BackgroundTransparency = 1 - a
		end
		local returning = wWritten.corrupt > 0 and w.corrupt == 0
		local camMoved = math.abs(C.x - lastColorCam.x) * z > 24 or math.abs(C.y - lastColorCam.y) * z > 24
			or math.abs(z - lastColorCam.z) > 0.02 * z
		if ambient and (moved or returning or (w.corrupt > 0 and camMoved) or force) then
			ambient:recolor(w, C, z, V)
			lastColorCam.x, lastColorCam.y, lastColorCam.z = C.x, C.y, z
		end
		if moved then wWritten.rift, wWritten.corrupt = w.rift, w.corrupt end
	end
	local function place()
		for _, rec in layers do
			local d = rec.def
			local a = 1
			if d.zShow > d.zHide and d.zShow > 0 then a = MapCamera.smoothstep(d.zHide, d.zShow, z) end
			if d.id == "fg" then a *= fgK end
			writeLayer(rec, a)
			if d.id == "fg" and ambient then ambient:setLayerAlpha("fg", a) end
		end
		-- Links and Nodes: the world transform
		local ox, oy = V.w / 2 - z * C.x, V.h / 2 - z * C.y
		local pos = UDim2.fromScale(ox / V.w, oy / V.h)
		local size = UDim2.fromScale(WORLD.w * z / V.w, WORLD.h * z / V.h)
		links.Position, links.Size = pos, size
		nodesF.Position, nodesF.Size = pos, size
		wTarget = MapCamera.biome(C, realm.biome, z, V)
		if fields then fields:setAlpha("motesNear", fgK) end
	end

	function self.step(_: MapView, dt: number)
		-- the Box-resize animation
		local ra = rectAnim
		if ra then
			ra.t += dt
			local u = math.clamp(ra.t / ra.time, 0, 1)
			local e = ra.ease(u)
			local to = ra.to or fullRect()
			local r = {
				x = ra.from.x + (to.x - ra.from.x) * e,
				y = ra.from.y + (to.y - ra.from.y) * e,
				w = ra.from.w + (to.w - ra.from.w) * e,
				h = ra.from.h + (to.h - ra.from.h) * e,
			}
			if u >= 1 then
				rectAnim = nil
				resizeTo(ra.to)
			else
				resizeTo(r)
			end
		end
		-- flights
		local fl = flight
		if fl then
			if fl.mode == "ease" then
				fl.t += dt
				local u = math.clamp(fl.t / fl.time, 0, 1)
				local e = fl.ease(u)
				C = { x = fl.C0.x + (fl.C.x - fl.C0.x) * e, y = fl.C0.y + (fl.C.y - fl.C0.y) * e }
				z = math.exp(math.log(fl.z0) + (math.log(fl.z) - math.log(fl.z0)) * e)
				if u >= 1 then flight = nil end
			else
				local x, vx = MapCamera.smoothDamp(C.x, fl.C.x, fl.vx, fl.smooth, dt)
				local y, vy = MapCamera.smoothDamp(C.y, fl.C.y, fl.vy, fl.smooth, dt)
				local lz, vzz = MapCamera.smoothDamp(math.log(z), math.log(fl.z), fl.vz, fl.smooth, dt)
				fl.vx, fl.vy, fl.vz = vx, vy, vzz
				C = { x = x, y = y }
				z = math.exp(lz)
				if math.abs(x - fl.C.x) < 0.05 and math.abs(y - fl.C.y) < 0.05 and math.abs(lz - math.log(fl.z)) < 1e-4 then
					C = { x = fl.C.x, y = fl.C.y }
					z = fl.z
					flight = nil
				end
			end
			applyClamp(true)
			dirty = true
		elseif not self.inputActive and rectAnim == nil then
			-- at rest outside the hard envelope (after a rubber band or a strip change): spring back
			local hard = MapCamera.clampCamera(C, z, V, false)
			if math.abs(hard.x - C.x) > 1e-3 or math.abs(hard.y - C.y) > 1e-3 or math.abs(hard.z - z) > 1e-6 then
				if reduced then
					C, z = { x = hard.x, y = hard.y }, hard.z
				else
					local st = realm.feel.rubberReturn
					local sx = spring
					local x, vx = MapCamera.smoothDamp(C.x, hard.x, sx.x, st, dt)
					local y, vy = MapCamera.smoothDamp(C.y, hard.y, sx.y, st, dt)
					local lz, vzz = MapCamera.smoothDamp(math.log(z), math.log(hard.z), sx.z, st, dt)
					sx.x, sx.y, sx.z = vx, vy, vzz
					C, z = { x = x, y = y }, math.exp(lz)
					if math.abs(x - hard.x) < 0.05 and math.abs(y - hard.y) < 0.05 and math.abs(lz - math.log(hard.z)) < 1e-4 then
						C, z = { x = hard.x, y = hard.y }, hard.z
						spring.x, spring.y, spring.z = 0, 0, 0
					end
				end
				dirty = true
			end
		end
		-- the side-sheet fade of fg and motesNear
		local fgGoal = if fgOpen then 1 else 0
		if fgK ~= fgGoal then
			fgK = if reduced then fgGoal elseif fgGoal > fgK then math.min(fgGoal, fgK + dt / 0.2) else math.max(fgGoal, fgK - dt / 0.2)
			dirty = true
		end
		local moved = dirty
		if dirty then
			place()
			dirty = false
		end
		-- biome weights ease toward the camera's (tau .35 s; instant when reduced)
		local k = if reduced then 1 else 1 - math.exp(-dt / 0.35)
		local wr = w.rift + (wTarget.rift - w.rift) * k
		local wc = w.corrupt + (wTarget.corrupt - w.corrupt) * k
		if math.abs(wr - wTarget.rift) < 1e-3 then wr = wTarget.rift end
		if math.abs(wc - wTarget.corrupt) < 1e-3 then wc = wTarget.corrupt end
		w = { rift = wr, corrupt = wc, cover = wTarget.cover }
		writeColors(false)
		-- particles drift all the time
		if fields and ambientOn then fields:step(os.clock() - clock0, C, z, V, w) end
		if moved then self.cameraChanged:Fire(self:camera()) end
	end

	-- ------------------------------------------------------------------------------------------ preload
	-- PreloadAsync behind the splash, farthest layers first, then the atlas (yields)
	function self.preload(_: MapView, onProgress: ((done: number, total: number) -> ())?)
		local list: { string } = {}
		for _, rec in layers do
			for _, t in rec.tiles do
				if t.gui.Image ~= "" then table.insert(list, t.gui.Image) end
			end
		end
		local atlas = atlasInfo()
		if atlas and atlas.id ~= "" then table.insert(list, atlas.id) end
		local total = #list
		if total == 0 then
			if onProgress then onProgress(0, 0) end
			return
		end
		local done = 0
		pcall(function()
			ContentProvider:PreloadAsync(list, function()
				done += 1
				if onProgress then onProgress(done, total) end
			end)
		end)
	end

	-- a sky or world whose painted tiles have not come in after 10 s (a failed or still-moderated upload) gets the
	-- procedural look (plan 3.4), but only while NONE of its tiles has loaded: the fallback sits in the layer's own
	-- container over the tiles, so it must never cover painted art. It goes away as soon as a tile arrives (checked
	-- every 2 s for 2 minutes).
	local function watchdog()
		task.delay(10, function()
			if box.Parent == nil then return end
			local recs: { LayerRec } = {}
			if byId.sky then table.insert(recs, byId.sky) end
			if byId.world then table.insert(recs, byId.world) end
			for _, rec in recs do
				local function anyLoaded(): boolean
					for _, t in rec.tiles do
						if t.gui.Image ~= "" and t.gui.IsLoaded then return true end
					end
					return false
				end
				if #rec.tiles == 0 or anyLoaded() then continue end
				if rec.sprites:FindFirstChild("FallbackStars") or rec.sprites:FindFirstChild("FallbackWorld") then continue end
				local made: { Instance }, tweens: { Tween } = {}, {}
				if rec == byId.sky then
					made = Fallback.sky(rec.plane, rec.sprites, { w = rec.def.w, h = rec.def.h })
				else
					local fw = Fallback.world(rec.sprites, realm)
					fallbackWorld = fw
					made = fw.made
					tweens = Fallback.breathe(fw, reduced)
				end
				for _, inst in made do table.insert(fallbackMade, inst) end
				for _, t in tweens do table.insert(fallbackTweens, t) end
				dirty = true
				task.spawn(function()
					for _ = 1, 60 do
						task.wait(2)
						local first: Instance? = made[1]
						if not box.Parent or not first or not first.Parent then return end
						if anyLoaded() then
							for _, t in tweens do t:Cancel() end
							for _, inst in made do inst:Destroy() end
							if rec == byId.world then fallbackWorld = nil end
							dirty = true
							return
						end
					end
				end)
			end
		end)
	end

	function self.destroy(_: MapView)
		clearArt()
		box:Destroy()
		self.cameraChanged:DisconnectAll()
	end

	-- ------------------------------------------------------------------------------------------ start
	layoutBox(nil)
	do
		local s = MapCamera.startCamera(V) -- REALM.md 2.8: inside the world (no pan margin)
		C, z = { x = s.x, y = s.y }, s.z
	end
	buildArt()
	if tileCount > 0 then watchdog() end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if rectAnim == nil then resizeTo(rect) end
	end)
	Layout.changed:Connect(function()
		layoutBox(if rectAnim then nil else rect)
	end)
	Motion.changed:Connect(function(r: boolean)
		self:setReduced(r)
	end)
	return self
end

return MapView
