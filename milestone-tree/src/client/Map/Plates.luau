--!strict
--[[
	Plates: the nameplates under the nodes (DESIGN.md 3.9). They live in view.plates (the full Box, sized Box / s under
	UIScale s), so they keep a constant UI size and the type floors of DESIGN.md 9.5.

	    Plate_<id>  Frame (AutomaticSize XY, AnchorPoint .5 / 0, panel2 -> deep at .95, UIStroke 1.5 lift(c, .25))
	      Label     the name: `plate` role, caps with hair spaces, W -> lift(c, .45), a thin outline
	      AmountRow Amount: `plateNum` (Montserrat Bold, lift(c, .55); Rich.num units); locked: lock + requirement + unit
	      Sub       bolt + "READY" (`plateSub`, #ffe08a) on pulse nodes, else "+1.23e45/s" (green) while it generates passively

	Level of detail FULL / CHIP (the amount alone) / NONE by zoom with +-.02 hysteresis (MapLogic.lod); the selected,
	hovered and peeked nodes always get FULL; Options Map Labels ALWAYS / OFF (setMode). Placement is greedy in
	priority order: below the ring, else above it, else the chip, else hidden, never over a HUD rect (Layout.rects),
	past the side sheet's edge, or over another plate by more than 4 du (MapLogic.place). Positions are written on
	every camera frame; placement reruns when the zoom moves 2%, the camera 8 pt, the HUD rects or the node set
	change. Text is written at most 5 times a second and only when it changed.

	    local plates = Plates.new(view, nodes)
	    plates:update(ms)       plates:onCamera(cam)      plates:setMode(labels)   -- AUTO | ALWAYS | OFF
	onCamera is connected to view.cameraChanged already.
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Rich = require(Core:WaitForChild("Rich"))
local Prefs = require(Core:WaitForChild("Prefs"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))
local MapView = require(script.Parent:WaitForChild("MapView"))
local Nodes = require(script.Parent:WaitForChild("Nodes"))
local MapLogic = require(script.Parent:WaitForChild("MapLogic"))

type MapState = Types.MapState
type Camera = Types.Camera
type ARect = Types.Rect

export type Plates = {
	update: (self: Plates, ms: MapState) -> (),
	onCamera: (self: Plates, cam: Camera) -> (),
	setMode: (self: Plates, labels: string) -> (),
	destroy: (self: Plates) -> (),
}

local Plates = {}

local READY = Theme.C.ready
local GAIN = Color3.fromHex("7ee0a0") -- the passive gain line (the capsule's rate green)

type Plate = {
	layer: string,
	frame: Frame,
	label: TextLabel,
	row: Frame,
	amount: TextLabel,
	lock: Frame,
	sub: Frame,
	stroke: UIStroke,
	strokeGrad: UIGradient,
	labelGrad: UIGradient,
	want: { name: string, amount: string, locked: boolean, ready: boolean, gen: string?, hasAmount: boolean }?,
	written: string,
	form: string, -- FULL | CHIP | NONE (as shown)
	slot: number, -- 1 below the ring, 2 above
	sizeFull: Vector2, -- du
	sizeChip: Vector2,
}

local function escape(t: string): string
	return (string.gsub(string.gsub(string.gsub(t, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end
-- caps with hair spaces; pm's redacted blocks at alpha .6
local function nameRich(name: string): string
	local out = escape(Rich.caps(name))
	out = string.gsub(out, "(█+)", '<font transparency="0.4">%1</font>')
	return out
end

function Plates.new(view: MapView.MapView, nodes: Nodes.Nodes): Plates
	local self = {} :: Plates
	local plates: { [string]: Plate } = {}
	local ms: MapState? = nil
	local mode = Prefs.get().labels
	local cam: Camera = view:camera()
	local lod = "FULL"
	local lastPlace = { x = math.huge, y = math.huge, z = 0 }
	local dirty = true
	local lastText = 0
	local textPending = false

	local function compact(): boolean
		return Layout.mode == "COMPACT"
	end

	local function build(layer: string): Plate
		local hue = Theme.hue(layer)
		local f = Kit.frame(view.plates, "Plate_" .. layer, 2)
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.AutomaticSize = Enum.AutomaticSize.XY
		f.Size = UDim2.fromOffset(0, 0)
		f.Visible = false
		-- Sleek: a near-black slab, a white hairline, upright tracked caps and the value in the layer hue
		f.BackgroundColor3 = Color3.fromHex("06090f")
		f.BackgroundTransparency = 0.2
		local st = Kit.stroke(f, 1, Color3.new(1, 1, 1), 0.12, "Rim")
		st.LineJoinMode = Enum.LineJoinMode.Miter
		local sg = Kit.grad(st, { Color3.new(1, 1, 1) }, 90, { { 0, 0.2 }, { 1, 0.1 } }, "RimGrad")
		local list = Kit.list(f, "y", 1, Enum.HorizontalAlignment.Center)
		local _ = list
		local label = Kit.label(f, "Label", "plate", "", Color3.new(1, 1, 1))
		label.LayoutOrder = 1
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(0, 0)
		label.RichText = true
		label.TextXAlignment = Enum.TextXAlignment.Center
		local lg = Kit.grad(label, { Color3.new(1, 1, 1) }, 90, nil, "Fill")
		Kit.textStroke(label, 0)
		local over = Kit.child(label, "Overhang", "UIPadding") :: UIPadding
		over.PaddingRight = UDim.new(0, math.ceil(0.1 * label.TextSize))

		local row = Kit.frame(f, "AmountRow")
		row.LayoutOrder = 2
		row.AutomaticSize = Enum.AutomaticSize.XY
		row.Size = UDim2.fromOffset(0, 0)
		Kit.list(row, "x", 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		local lock = Kit.glyph(row, "Lock", "lock", Theme.C.gold, Theme.C.deep)
		lock.LayoutOrder = 1
		lock.Size = UDim2.fromOffset(12, 12)
		lock.Visible = false
		local amount = Kit.label(row, "Amount", "plateNum", "", Theme.lift(hue, 0.45))
		amount.LayoutOrder = 2
		amount.AutomaticSize = Enum.AutomaticSize.XY
		amount.Size = UDim2.fromOffset(0, 0)
		amount.RichText = true

		local sub = Kit.frame(f, "Sub")
		sub.LayoutOrder = 3
		sub.AutomaticSize = Enum.AutomaticSize.XY
		sub.Size = UDim2.fromOffset(0, 0)
		Kit.list(sub, "x", 3, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		local bolt = Kit.glyph(sub, "Bolt", "bolt", READY)
		bolt.LayoutOrder = 1
		bolt.Size = UDim2.fromOffset(11, 11)
		local rl = Kit.label(sub, "Text", "plateSub", Rich.caps("Ready"), READY)
		rl.LayoutOrder = 2
		rl.AutomaticSize = Enum.AutomaticSize.XY
		rl.Size = UDim2.fromOffset(0, 0)
		sub.Visible = false

		local p: Plate = {
			layer = layer, frame = f, label = label, row = row, amount = amount, lock = lock, sub = sub, stroke = st,
			strokeGrad = sg, labelGrad = lg, want = nil, written = "", form = "NONE", slot = 1,
			sizeFull = Vector2.new(140, 46), sizeChip = Vector2.new(80, 26),
		}
		plates[layer] = p
		return p
	end
	for _, layer in MapLogic.ORDER do build(layer) end

	local function restyle(p: Plate)
		local c = compact()
		Theme.text(p.label, "plate")
		Theme.text(p.amount, "plateNum")
		local rl = p.sub:FindFirstChild("Text") :: TextLabel?
		if rl then Theme.text(rl, "plateSub") end
		if c then Kit.pad(p.frame, 4, 9, 5, 9) else Kit.pad(p.frame, 5, 12, 6, 12) end
		local g = math.floor(Theme.size("plateNum") * 0.8 + 0.5)
		p.lock.Size = UDim2.fromOffset(g, g)
		local b = p.sub:FindFirstChild("Bolt") :: Frame?
		if b then
			local bs = math.floor(Theme.size("plateSub") * 0.85 + 0.5)
			b.Size = UDim2.fromOffset(bs, bs)
		end
	end
	for _, p in plates do restyle(p) end

	-- ------------------------------------------------------------------------------------------ text
	local function amountText(layer: string, node: Types.MapNode): (string, boolean)
		local v = node.val
		if v == nil then return "", false end
		if not v.lit then
			local req = v.req or ""
			local unit = MapLogic.unit(v.rres)
			return Rich.num(req .. " " .. unit, { size = Theme.size("plateNum"), unit = Theme.C.soft }), req ~= ""
		end
		local pts = v.pts or ""
		if layer == "ach" and v.tot then pts = pts .. " / " .. v.tot end
		if pts == "" then return "", false end
		return Rich.num(pts, { size = Theme.size("plateNum"), unit = Theme.C.soft }), true
	end

	local function writeText(force: boolean)
		local now = os.clock()
		if not force and now - lastText < 0.2 then
			if not textPending then
				textPending = true
				task.delay(0.21 - (now - lastText), function()
					textPending = false
					writeText(true)
				end)
			end
			return
		end
		lastText = now
		for layer, p in plates do
			local w = p.want
			if w == nil then continue end
			local key = w.name .. "|" .. w.amount .. "|" .. tostring(w.locked) .. "|" .. tostring(w.ready) .. "|" .. tostring(w.gen)
			if key == p.written then continue end
			p.written = key
			p.label.Text = nameRich(w.name)
			p.amount.Text = w.amount
			-- the second line: READY, or the passive gain ("+1.23e45/s") once the layer generates on its own
			local rl = p.sub:FindFirstChild("Text") :: TextLabel?
			local bolt = p.sub:FindFirstChild("Bolt") :: GuiObject?
			if rl then
				rl.RichText = true
				if w.ready or w.gen == nil then
					rl.Text = Rich.caps("Ready")
					rl.TextColor3 = READY
				else
					rl.Text = Rich.num("+" .. w.gen .. "/s", { size = Theme.size("plateSub"), unit = Theme.C.soft })
					rl.TextColor3 = GAIN
				end
			end
			if bolt then bolt.Visible = w.ready end
			p.lock.Visible = false -- Sleek: a locked plate is grey; no lock coin in the value row
			local hue = Theme.hue(layer)
			-- Sleek: white hairline plates; a READY node's plate takes the hue on its hairline
			if w.locked then
				p.labelGrad.Color = ColorSequence.new(Theme.C.lockedTitle)
				p.amount.TextColor3 = Theme.C.lockedTitle
				p.strokeGrad.Color = ColorSequence.new(Color3.new(1, 1, 1))
			else
				p.labelGrad.Color = ColorSequence.new(Color3.new(1, 1, 1))
				p.amount.TextColor3 = Theme.lift(hue, 0.45)
				p.strokeGrad.Color = ColorSequence.new(if w.ready then Theme.lift(hue, 0.3) else Color3.new(1, 1, 1))
			end
			p.stroke.Transparency = if w.ready then 0.35 else 0.12
			p.stroke.Thickness = 1
			dirty = true
		end
	end

	-- ------------------------------------------------------------------------------------------ placement
	local function nodeBox(layer: string): (number, number)
		local p = nodes:worldPos(layer)
		return cam.m * (cam.V.X / 2 + cam.z * (p.X - cam.C.X)), cam.m * (cam.V.Y / 2 + cam.z * (p.Y - cam.C.Y))
	end
	-- the plate-local slot rect (du): below the ring (1) or above it (2)
	local function slotRect(layer: string, size: Vector2, slot: number): ARect
		local s = Layout.s
		local bx, by = nodeBox(layer)
		local r = nodes:ringRadius() * cam.z * cam.m
		local x = bx / s - size.X / 2
		local y = if slot == 1 then (by + r) / s + 2 else (by - r) / s - 18 - size.Y
		return { x = x, y = y, w = size.X, h = size.Y }
	end
	local function blockedRects(): { ARect }
		local s = Layout.s
		local bp = view.box.AbsolutePosition
		local out: { ARect } = {}
		for _, r in Layout.rects() do
			table.insert(out, { x = (r.x - bp.X) / s, y = (r.y - bp.Y) / s, w = r.w / s, h = r.h / s })
		end
		local sx = Layout.sheet()
		if sx then table.insert(out, { x = (sx - bp.X) / s, y = -1e5, w = 1e6, h = 2e5 }) end
		return out
	end
	local function measure(p: Plate)
		local a = p.frame.AbsoluteSize
		if a.X > 1 and a.Y > 1 and p.frame.Visible then
			local s = Layout.s
			local d = Vector2.new(a.X / s, a.Y / s)
			if p.form == "FULL" then p.sizeFull = d elseif p.form == "CHIP" then p.sizeChip = d end
		end
	end

	local function place()
		local state = ms
		if state == nil then return end
		local sel, hov, pk = nodes:selected(), nodes:hovered(), nodes:peeked()
		local c = compact()
		local items: { MapLogic.PlateItem } = {}
		for layer, p in plates do
			local w = p.want
			if w == nil then continue end
			measure(p)
			local keep = layer == sel or layer == hov or layer == pk
			local level = lod
			if mode == "ALWAYS" then level = "FULL" elseif mode == "OFF" then level = "NONE" end
			if keep then level = "FULL" end
			if level == "NONE" and not w.ready then continue end
			local full = if level == "FULL" then { slotRect(layer, p.sizeFull, 1), slotRect(layer, p.sizeFull, 2) } else nil
			local chip = if w.hasAmount or w.ready then { slotRect(layer, p.sizeChip, 1), slotRect(layer, p.sizeChip, 2) } else nil
			if level == "NONE" and w.ready then full = nil end
			local _ = c
			table.insert(items, { id = layer, rank = nodes:rank(layer), y = nodes:worldPos(layer).Y, full = full, chip = chip, keep = keep })
		end
		local placed = MapLogic.place(items, blockedRects(), 4)
		for layer, p in plates do
			local pl = placed[layer]
			local form = if pl then pl.form else "NONE"
			local slot = if pl then pl.slot else 1
			local w = p.want
			if form ~= p.form then
				p.form = form
				if form == "NONE" or w == nil then
					p.frame.Visible = false
				else
					p.frame.Visible = true
					p.label.Visible = form == "FULL"
					-- COMPACT FULL shows the amount only on READY, CAN BUY and the selected node (DESIGN.md 3.9)
					local showAmount = form == "CHIP" or not c or w.ready or layer == sel or nodes:state(layer) == "glow"
					p.row.Visible = w.hasAmount and showAmount
					p.sub.Visible = w.ready or (w.gen ~= nil and form == "FULL")
				end
			elseif w and form ~= "NONE" then
				p.sub.Visible = w.ready or (w.gen ~= nil and form == "FULL")
				p.row.Visible = w.hasAmount and (form == "CHIP" or not c or w.ready or layer == sel or nodes:state(layer) == "glow")
			end
			p.slot = slot
			nodes:setPlateRect(layer, if pl and pl.rect then pl.rect else nil)
		end
		lastPlace = { x = cam.C.X, y = cam.C.Y, z = cam.z }
		dirty = false
	end

	local function writePositions()
		local s = Layout.s
		for layer, p in plates do
			if p.form == "NONE" then continue end
			local bx, by = nodeBox(layer)
			local r = nodes:ringRadius() * cam.z * cam.m
			local size = if p.form == "FULL" then p.sizeFull else p.sizeChip
			local y = if p.slot == 1 then (by + r) / s + 2 else (by - r) / s - 18 - size.Y
			p.frame.Position = UDim2.fromOffset(math.floor(bx / s + 0.5), math.floor(y + 0.5))
		end
	end

	-- ------------------------------------------------------------------------------------------ API
	function self.update(_: Plates, newMs: MapState)
		ms = newMs
		local sel = nodes:selected()
		for _, layer in MapLogic.ORDER do
			local p = plates[layer]
			local node = newMs.nodes[layer]
			local st = nodes:state(layer)
			if node == nil or not node.show or node.val == nil or st == "sealed" or st == "frontier" or st == "dormant" then
				p.want = nil
				if p.form ~= "NONE" then
					p.form = "NONE"
					p.frame.Visible = false
				end
				continue
			end
			local amt, has = amountText(layer, node)
			p.want = {
				name = MapLogic.plateName(node, layer),
				amount = amt,
				locked = st == "locked",
				ready = st == "pulse",
				gen = if node.val and type(node.val.gen) == "string" and st ~= "locked" then node.val.gen else nil,
				hasAmount = has,
			}
			local _ = sel
		end
		writeText(false)
		dirty = true
		place()
		writePositions()
	end

	function self.onCamera(_: Plates, c: Camera)
		cam = c
		local newLod = MapLogic.lod(c.z, Layout.mode, lod)
		if newLod ~= lod then
			lod = newLod
			dirty = true
		end
		local moved = math.abs(c.C.X - lastPlace.x) * c.z > 8 or math.abs(c.C.Y - lastPlace.y) * c.z > 8
			or math.abs(c.z - lastPlace.z) > 0.02 * lastPlace.z
		if dirty or moved then place() end
		writePositions()
	end

	function self.setMode(_: Plates, labels: string)
		if labels == mode then return end
		mode = labels
		dirty = true
		place()
		writePositions()
	end

	local conns: { any } = {}
	table.insert(conns, view.cameraChanged:Connect(function(c: Camera)
		self:onCamera(c)
	end))
	table.insert(conns, Layout.rectsChanged:Connect(function()
		dirty = true
		task.defer(function()
			if dirty then
				place()
				writePositions()
			end
		end)
	end))
	table.insert(conns, Layout.changed:Connect(function()
		for _, p in plates do
			restyle(p)
			p.written = ""
		end
		writeText(true)
		dirty = true
	end))
	table.insert(conns, nodes.changed:Connect(function()
		dirty = true
	end))
	table.insert(conns, nodes.hover:Connect(function()
		dirty = true
		task.defer(function()
			if dirty then
				place()
				writePositions()
			end
		end)
	end))
	table.insert(conns, Prefs.changed:Connect(function(key: string)
		if key == "labels" then self:setMode(Prefs.get().labels) end
	end))

	function self.destroy(_: Plates)
		for _, c in conns do c:Disconnect() end
		for _, p in plates do p.frame:Destroy() end
		table.clear(plates)
	end
	return self
end

return Plates
