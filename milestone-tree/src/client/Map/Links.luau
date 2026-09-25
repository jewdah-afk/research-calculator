--!strict
--[[
	Links: the live connections between nodes (DESIGN.md 3.8). Existence comes from the view's `br` (both ends shown),
	geometry from Realm.edges (the Figma control points plus the MP -> PM bridge), colour from the child's (edge
	`to`) hue, danger for an infected link. Everything is in view.links, in world Scale units.

	    lit      four stacked strokes (Recipes.curve: Path2D halo / glow / core / hot, or segment frames without
	             Path2D), widths from k = max(z, floor), rewritten when the zoom moves by more than 2%. LOW and phones
	             drop the hot stroke. Secondary links (theme slot 3) draw halo and glow at half alpha.
	    locked   HIGH: dots every 15 world px of arc length (at most 400 in all); LOW, phones and past the cap: one
	             thin thread
	    sparks   one glowing spark per edge into a pulse node, a 1.6 s loop (HIGH, not reduced; at most 6)

	    local links = Links.new(view)
	    links:update(ms)        links:onCamera(cam)     -- onCamera is connected to view.cameraChanged already
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))
local MapView = require(script.Parent:WaitForChild("MapView"))
local MapLogic = require(script.Parent:WaitForChild("MapLogic"))

type MapState = Types.MapState
type Camera = Types.Camera

export type Links = {
	update: (self: Links, ms: MapState) -> (),
	onCamera: (self: Links, cam: Camera) -> (),
	count: (self: Links) -> (number, number, number), -- lit curves, dots, sparks (tests / budgets)
	destroy: (self: Links) -> (),
}

local Links = {}

local DOT_STEP = 15
local DOT_CAP = 400
local SPARK_CAP = 6
local LOCKED_COLOR = Theme.C.lockedLink

-- the cubic's point at t
local function bez(p: { number }, t: number): (number, number)
	local u = 1 - t
	local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
	return a * p[1] + b * p[3] + c * p[5] + d * p[7], a * p[2] + b * p[4] + c * p[6] + d * p[8]
end
-- n + 1 points equally spaced by arc length (a 64-step table, then interpolated)
local function arcPoints(p: { number }, step: number?, count: number?): { Vector2 }
	local N = 64
	local xs, ys, len = table.create(N + 1), table.create(N + 1), table.create(N + 1)
	local total = 0
	for i = 0, N do
		local x, y = bez(p, i / N)
		xs[i + 1], ys[i + 1] = x, y
		if i > 0 then total += math.sqrt((x - xs[i]) ^ 2 + (y - ys[i]) ^ 2) end
		len[i + 1] = total
	end
	local n = count or math.max(1, math.floor(total / (step or DOT_STEP)))
	local out: { Vector2 } = {}
	local j = 1
	for k = 0, n do
		local target = total * k / n
		while j < N + 1 and len[j + 1] < target do j += 1 end
		local a, b = len[j], len[math.min(j + 1, N + 1)]
		local f = if b > a then (target - a) / (b - a) else 0
		local jj = math.min(j + 1, N + 1)
		table.insert(out, Vector2.new(xs[j] + (xs[jj] - xs[j]) * f, ys[j] + (ys[jj] - ys[j]) * f))
	end
	return out
end
Links.arcPoints = arcPoints

type Rec = {
	key: string,
	link: MapLogic.Link,
	mode: string, -- "lit" | "dots" | "thread"
	curve: Recipes.Curve?,
	dots: Frame?,
	ndots: number,
	spark: Frame?,
	sig: string,
}

function Links.new(view: MapView.MapView): Links
	local realm: any = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Realm"))
	local edges: { MapLogic.Edge } = realm.edges
	local self = {} :: Links
	local recs: { [string]: Rec } = {}
	local z, m = 0.5, 1
	local lastK = -1
	local sparkPts: { [string]: { Vector2 } } = {}
	local camConn: { Disconnect: (any) -> () }

	local function lowTier(): boolean
		return view.tier == "LOW" or Layout.mode == "COMPACT"
	end
	local function floorK(): number
		return 36 / 132
	end
	local function widths(): { number }
		local k = math.max(z, floorK())
		return {
			math.max(10, 24 * k) * m,
			math.max(6, 14 * k) * m,
			math.max(2.5, 4 * k) * m,
			math.max(1, 1.5 * k) * m,
		}
	end
	local function strokes(link: MapLogic.Link): { Recipes.CurveStroke }
		local c = if link.infected then Theme.C.danger else Theme.hue(link.to)
		local half = if link.secondary then 0.5 else 1
		local w = widths()
		local list: { Recipes.CurveStroke } = {
			{ c = c, a = 0.14 * half, w = w[1] },
			{ c = c, a = 0.32 * half, w = w[2] },
			{ c = Theme.lift(c, 0.3), a = 1, w = w[3] },
		}
		if not lowTier() then table.insert(list, { c = Color3.new(1, 1, 1), a = 0.85, w = w[4] }) end
		return list
	end
	local function pts(link: MapLogic.Link): { Vector2 }
		local p = link.p
		return { Vector2.new(p[1], p[2]), Vector2.new(p[3], p[4]), Vector2.new(p[5], p[6]), Vector2.new(p[7], p[8]) }
	end

	local function clear(r: Rec)
		if r.curve then (r.curve :: Recipes.Curve):destroy() end
		r.curve = nil
		if r.dots then (r.dots :: Frame):Destroy() end
		r.dots = nil
		r.ndots = 0
		if r.spark then (r.spark :: Frame):Destroy() end
		r.spark = nil
	end

	local function buildDots(r: Rec, budget: number): boolean
		local list = arcPoints(r.link.p, DOT_STEP)
		-- the ends sit under the rings: drop the first and last 3 (about 45 world px)
		local from, to = 4, #list - 3
		local n = math.max(0, to - from + 1)
		if n > budget then return false end
		local holder = Kit.frame(view.links, "Dots_" .. r.key, 1)
		holder.Size = UDim2.fromScale(1, 1)
		local d = math.max(2, math.floor(3 * m + 0.5))
		for i = from, to do
			local p = list[i]
			local dot = Instance.new("Frame")
			dot.Name = "D"
			dot.BorderSizePixel = 0
			dot.Active = false
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromScale(p.X / 3840, p.Y / 2560)
			dot.Size = UDim2.fromOffset(d, d)
			dot.BackgroundColor3 = LOCKED_COLOR
			dot.BackgroundTransparency = 0.55
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = dot
			dot.Parent = holder
		end
		r.dots = holder
		r.ndots = n
		return true
	end

	local function buildThread(r: Rec)
		r.curve = Recipes.curve(view.links, pts(r.link), { { c = LOCKED_COLOR, a = 0.42, w = 2.5 * m } },
			{ name = "Thread_" .. r.key, z = 1 })
	end

	local function buildLit(r: Rec)
		r.curve = Recipes.curve(view.links, pts(r.link), strokes(r.link), { name = "Edge_" .. r.key, z = 2 })
	end

	-- the flow spark along an edge into a pulse node (HIGH only)
	local function buildSpark(r: Rec)
		local key = r.key
		if sparkPts[key] == nil then sparkPts[key] = arcPoints(r.link.p, nil, 32) end
		local f = Kit.frame(view.links, "Spark_" .. key, 8)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		local size = math.floor(26 * math.max(z, floorK()) * m + 0.5)
		f.Size = UDim2.fromOffset(size, size)
		local hue = Theme.hue(r.link.to)
		local g = Kit.blob(f, "Glow", Theme.lift(hue, 0.4), 0.95)
		if g then g.Size = UDim2.fromScale(1, 1) end
		local core = Kit.frame(f, "Core", 2)
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		core.Position = UDim2.fromScale(0.5, 0.5)
		core.Size = UDim2.fromScale(0.34, 0.34)
		core.BackgroundColor3 = Color3.new(1, 1, 1)
		core.BackgroundTransparency = 0
		Kit.corner(core)
		r.spark = f
		local phase = math.random()
		Motion.loop(f, function(_dt: number)
			local list = sparkPts[key]
			if list == nil or #list < 2 then return end
			local t = ((os.clock() / 1.6) + phase) % 1
			local fi = t * (#list - 1) + 1
			local i = math.floor(fi)
			local fr = fi - i
			local a, b = list[i], list[math.min(i + 1, #list)]
			local p = a:Lerp(b, fr)
			f.Position = UDim2.fromScale(p.X / 3840, p.Y / 2560)
			local fade = math.min(1, t / 0.15, (1 - t) / 0.15)
			f.Visible = true
			if g then g.BackgroundTransparency = 1 - fade end
			core.BackgroundTransparency = 1 - fade * 0.9
		end)
	end

	function self.update(_: Links, ms: MapState)
		local list = MapLogic.edges(ms, edges)
		local want: { [string]: MapLogic.Link } = {}
		for _, l in list do want[l.from .. "_" .. l.to] = l end
		-- drop the gone
		for key, r in recs do
			if want[key] == nil then
				clear(r)
				recs[key] = nil
			end
		end
		local low = lowTier()
		local reduced = Motion.reduced() or Motion.snapshot()
		-- dots budget: every locked edge in map order until the cap
		local dotBudget = DOT_CAP
		for key, r in recs do
			if r.mode == "dots" and want[key] and not want[key].lit then dotBudget -= r.ndots end
		end
		local sparks = 0
		for key, r in recs do
			if r.spark then sparks += 1 end
		end
		for _, link in list do
			local key = link.from .. "_" .. link.to
			local toNode = ms.nodes[link.to]
			local pulse = toNode ~= nil and toNode.val ~= nil and (toNode.val :: Types.Val).pulse
			local sig = table.concat({ tostring(link.lit), tostring(link.secondary), tostring(link.infected), tostring(low) }, "|")
			local r = recs[key]
			if r == nil or r.sig ~= sig then
				if r then
					if r.mode == "dots" then dotBudget += r.ndots end
					if r.spark then sparks -= 1 end
					clear(r)
				end
				local nr: Rec = { key = key, link = link, mode = "lit", curve = nil, dots = nil, ndots = 0, spark = nil, sig = sig }
				if link.lit then
					buildLit(nr)
				elseif not low and buildDots(nr, dotBudget) then
					nr.mode = "dots"
					dotBudget -= nr.ndots
				else
					nr.mode = "thread"
					buildThread(nr)
				end
				recs[key] = nr
				r = nr
			end
			local rr = r :: Rec
			rr.link = link
			-- sparks into pulse nodes
			local wantSpark = pulse and link.lit and not low and not reduced
			if wantSpark and rr.spark == nil and sparks < SPARK_CAP then
				buildSpark(rr)
				sparks += 1
			elseif not wantSpark and rr.spark then
				(rr.spark :: Frame):Destroy()
				rr.spark = nil
				sparks -= 1
			end
		end
	end

	function self.onCamera(_: Links, cam: Camera)
		z, m = cam.z, cam.m
		local k = math.max(z, floorK()) * m
		if lastK > 0 and math.abs(k - lastK) <= 0.02 * lastK then return end
		lastK = k
		local w = widths()
		for _, r in recs do
			if r.mode == "lit" and r.curve then
				(r.curve :: Recipes.Curve):setWidths(w)
			elseif r.mode == "thread" and r.curve then
				(r.curve :: Recipes.Curve):setWidths({ 2.5 * m })
			end
			local sp = r.spark
			if sp then
				local size = math.floor(26 * math.max(z, floorK()) * m + 0.5)
				sp.Size = UDim2.fromOffset(size, size)
			end
		end
	end

	function self.count(_: Links): (number, number, number)
		local lit, dots, sparks = 0, 0, 0
		for _, r in recs do
			if r.mode == "lit" then lit += 1 end
			dots += r.ndots
			if r.spark then sparks += 1 end
		end
		return lit, dots, sparks
	end

	function self.destroy(_: Links)
		camConn:Disconnect()
		for _, r in recs do clear(r) end
		table.clear(recs)
	end
	camConn = view.cameraChanged:Connect(function(cam: Camera)
		self:onCamera(cam)
	end)
	self:onCamera(view:camera())
	return self
end

return Links
