--!nonstrict
-- Client-side 2D plinko board: tiny custom physics (gravity, circles, segments, orb-orb),
-- one layout per tier, rendered with GUI objects inside a 400x600 logical play area.
--
--   local board = Board.new(parentFrame)
--   board:setLayout(tier, obstaclesRemoved, enhanced)
--   board:spawn(list, data)          -- list from the server's Spawn event
--   board:duplicate(pairs, data)     -- { {newId, sourceId} }
--   board:clear()
--   board.onCollect = function(id, x, orb) end

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.OrbConfig)
local Progression = require(Shared.Progression)
local F = require(Shared.OrbFormulas)
local Kit = require(script.Parent.UI.Kit)

local W, H = Config.Board.Width, Config.Board.Height
local GRAVITY = 1250
local MAX_SPEED = 900
local STEP = 1 / 120
local ORB_ORB_LIMIT = 220 -- skip orb-orb collisions above this count (perf)

local Board = {}
Board.__index = Board

---------------------------------------------------------------- layouts

-- rectangle (centre, length, thickness, angle deg) -> segment
local function bar(cx, cy, len, thick, deg)
	local a = math.rad(deg)
	local dx, dy = math.cos(a) * len / 2, math.sin(a) * len / 2
	return { kind = "seg", x1 = cx - dx, y1 = cy - dy, x2 = cx + dx, y2 = cy + dy, half = thick / 2, rest = 0.5, deg = deg, len = len, cx = cx, cy = cy }
end

local function pegGrid(rows, top, bottom, cols, rest)
	local out = {}
	local sx = W / cols
	for r = 0, rows - 1 do
		local y = if rows == 1 then (top + bottom) / 2 else top + r * (bottom - top) / (rows - 1)
		local off = (r % 2 == 1) and sx / 2 or 0
		local n = (r % 2 == 1) and cols - 1 or cols
		for c = 0, n - 1 do
			table.insert(out, { kind = "peg", x = off + sx / 2 + c * sx, y = y, r = 5, rest = rest or 0.5 })
		end
	end
	return out
end

local function concat(...)
	local out = {}
	for _, t in { ... } do
		for _, v in t do
			table.insert(out, v)
		end
	end
	return out
end

-- Returns list of static colliders for a board layout.
local LAYOUTS = {
	[0] = function(removed, enhanced)
		local rows = enhanced and 1 or (removed and 4 or 9)
		return pegGrid(rows, 110, 520, 7)
	end,
	[1] = function(removed, enhanced)
		local out = pegGrid(enhanced and 1 or 5, 260, 520, 7)
		table.insert(out, { kind = "peg", x = 200, y = 200, r = 25, rest = 1.2, big = true })
		if not removed then
			table.insert(out, bar(320, 105, 200, 15, -45))
			table.insert(out, bar(80, 105, 200, 15, 45))
		end
		return out
	end,
	[2] = function(removed, enhanced)
		local out = { bar(320, 105, 200, 15, -45), bar(80, 105, 200, 15, 45), bar(40, 470, 125, 15, 60), bar(175, 470, 125, 15, -60) }
		if not removed then
			out = concat(out, { bar(230, 225, 125, 15, 60), bar(360, 225, 125, 15, -60), bar(80, 338, 200, 20, 45), bar(320, 338, 200, 20, -45) })
		end
		if not enhanced then
			out = concat(out, { bar(40, 225, 125, 15, 60), bar(175, 225, 125, 15, -60), bar(230, 470, 125, 15, 60), bar(360, 470, 125, 15, -60) })
		end
		return out
	end,
	[3] = function(removed, enhanced)
		local out = { bar(320, 105, 200, 15, -45), bar(80, 105, 200, 15, 45),
			{ kind = "peg", x = 200, y = 262, r = 25, rest = 1.33, big = true },
			bar(66, 300, 175, 15, 90), bar(334, 300, 175, 15, 90), bar(44, 378, 40, 15, 0), bar(356, 378, 40, 15, 0) }
		out = concat(out, pegGrid(enhanced and 1 or (removed and 2 or 4), 420, 540, 6))
		return out
	end,
	[4] = function(removed, enhanced)
		local cols = enhanced and 2 or (removed and 3 or 4)
		return pegGrid(8, 120, 530, cols + 3)
	end,
}

---------------------------------------------------------------- construction

function Board.new(parent: GuiObject)
	local self = setmetatable({}, Board)
	self.root = Kit.new("Frame", {
		Name = "PlayArea",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		Parent = parent,
	})
	self.staticLayer = Kit.new("Frame", { Name = "Static", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.root })
	self.orbLayer = Kit.new("Frame", { Name = "Orbs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = self.root })
	self.colliders = {}
	self.orbs = {}
	self.count = 0
	self.tier = 0
	self.onCollect = nil
	self.acc = 0
	self.slotFrames = {}
	self.conn = RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)
	return self
end

local function toUDim(x, y)
	return UDim2.fromScale(x / W, y / H)
end

function Board:setLayout(tier: number, removed: boolean, enhanced: boolean)
	self.tier = tier
	for _, c in self.staticLayer:GetChildren() do
		c:Destroy()
	end
	local board = Progression.boardForTier(tier)
	self.colliders = LAYOUTS[board](removed, enhanced)
	for _, c in self.colliders do
		if c.kind == "peg" then
			local f = Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = toUDim(c.x, c.y),
				Size = UDim2.fromScale(c.r * 2 / W, c.r * 2 / H),
				BackgroundColor3 = c.big and Kit.Colors.Gold or Color3.fromRGB(233, 228, 255),
				Rotation = c.big and 0 or 45,
				Parent = self.staticLayer,
			}, { Kit.stroke(c.big and 3 or 1.5) })
			if c.big then
				Kit.corner(999).Parent = f
				Kit.gradient(Kit.Colors.Gold, Kit.Colors.GoldDark).Parent = f
			else
				Kit.corner(2).Parent = f
			end
		else
			Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = toUDim(c.cx, c.cy),
				Size = UDim2.fromScale(c.len / W, c.half * 2 / H),
				Rotation = c.deg,
				BackgroundColor3 = Kit.Colors.White,
				Parent = self.staticLayer,
			}, { Kit.corner(3), Kit.stroke(2.5), Kit.gradient(Kit.Colors.Gold, Kit.Colors.GoldDark) })
		end
	end
	self:_buildSlots(board)
end

function Board:_buildSlots(board: number)
	local slot = Config.Tiers.Slots[board]
	-- visual slot strip across the bottom, split at zone edges
	local edges = { 0 }
	for _, z in slot.zones do
		table.insert(edges, math.clamp(z[1], 0, W))
		table.insert(edges, math.clamp(z[2], 0, W))
	end
	table.insert(edges, W)
	table.sort(edges)
	local h = 36
	for i = 1, #edges - 1 do
		local a, b = edges[i], edges[i + 1]
		if b - a > 4 then
			local mult = F.slotMult(self.tier, (a + b) / 2)
			local hot = mult > slot.default or (mult >= 2 and #slot.zones == 0)
			local f = Kit.new("Frame", {
				Position = UDim2.new(a / W, 2, 1, -h - 2),
				Size = UDim2.new((b - a) / W, -4, 0, h),
				BackgroundColor3 = Kit.Colors.White,
				ZIndex = 3,
				Parent = self.staticLayer,
			}, { Kit.corner(4), Kit.stroke(2.5), hot and Kit.gradient(Kit.Colors.Pink, Kit.Colors.RedDark) or Kit.gradient(Kit.Colors.Tab, Kit.Colors.TabDark) })
			Kit.text({ text = "x" .. tostring(mult), font = Kit.Fonts.HeavyItalic, size = 16, outline = 2.5, alignX = Enum.TextXAlignment.Center, dim = UDim2.fromScale(1, 1), parent = f }).ZIndex = 4
		end
	end
end

---------------------------------------------------------------- orbs

local VARIANT_STROKE = { Shiny = Color3.fromRGB(255, 255, 255), Glowing = Color3.fromRGB(255, 230, 90) }

function Board:_makeOrbGui(orb)
	local r = orb.r
	local f = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(r * 2 / W, r * 2 / H),
		BackgroundColor3 = Kit.Colors.White,
		ZIndex = 6,
		Parent = self.orbLayer,
	})
	if orb.kind == "diamond" then
		f.Rotation = 45
		Kit.corner(3).Parent = f
		Kit.gradient(Kit.Colors.Gem, Kit.Colors.GemDark).Parent = f
	elseif orb.kind == "weather" then
		Kit.corner(999).Parent = f
		Kit.gradient(Kit.Colors.Storm, Kit.Colors.StormDark).Parent = f
	else
		Kit.corner(999).Parent = f
		local c = Progression.Rarities[orb.rarity].color
		local col = Color3.fromRGB(c[1], c[2], c[3])
		local h, s, v = col:ToHSV()
		Kit.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromHSV(h, s * 0.6, math.min(v + 0.25, 1)), Color3.fromHSV(h, s, v * 0.6)),
			Rotation = 60,
			Parent = f,
		})
	end
	local stroke = Kit.stroke(orb.variant and 2.5 or 1.5, VARIANT_STROKE[orb.variant] or Kit.Colors.Black)
	stroke.Parent = f
	if orb.variant == "Rainbow" then
		stroke.Color = Kit.Colors.White
		Kit.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 255)),
			}),
			Parent = stroke,
		})
		orb.rainbow = stroke:FindFirstChildOfClass("UIGradient")
	end
	-- gloss dot
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.35, 0.3),
		Size = UDim2.fromScale(0.32, 0.22),
		BackgroundColor3 = Kit.Colors.White,
		BackgroundTransparency = 0.35,
		ZIndex = 7,
		Parent = f,
	}, { Kit.corner(999) })
	orb.gui = f
end

local REST = { orb = 0.9, diamond = 0.6, weather = 0.7 }

function Board:_add(id, info, x, y, vx, vy, data)
	if self.orbs[id] then
		return
	end
	local r = if info.kind == "orb" then F.orbRadius(data, info.rarity) else Config.Board.SpecialOrbRadius
	local orb = {
		id = id, kind = info.kind, rarity = info.rarity, variant = info.variant,
		x = x, y = y, vx = vx or 0, vy = vy or 0, r = r, rest = REST[info.kind] or 0.9,
		stillT = 0,
	}
	self:_makeOrbGui(orb)
	self.orbs[id] = orb
	self.count += 1
end

function Board:spawn(list, data)
	local B = Config.Board
	for _, info in list do
		self:_add(info.id, info, B.SpawnXMin + math.random() * (B.SpawnXMax - B.SpawnXMin), B.SpawnY, (math.random() - 0.5) * 40, 0, data)
	end
end

function Board:duplicate(pairs_, data)
	for _, p in pairs_ do
		local src = self.orbs[p[2]]
		if src then
			self:_add(p[1], src, src.x + (math.random() - 0.5) * 6, src.y, -src.vx, src.vy, data)
		end
	end
end

function Board:clear()
	for _, o in self.orbs do
		o.gui:Destroy()
	end
	self.orbs = {}
	self.count = 0
end

---------------------------------------------------------------- physics

local function resolve(o, nx, ny, pen, rest)
	o.x += nx * pen
	o.y += ny * pen
	local vn = o.vx * nx + o.vy * ny
	if vn < 0 then
		local e = math.max(o.rest, rest or 0)
		o.vx -= (1 + e) * vn * nx
		o.vy -= (1 + e) * vn * ny
		-- light tangential friction
		o.vx *= 0.995
	end
end

function Board:_physics(dt)
	local cols = self.colliders
	local list = {}
	for _, o in self.orbs do
		o.vy += GRAVITY * dt
		local sp = math.sqrt(o.vx * o.vx + o.vy * o.vy)
		if sp > MAX_SPEED then
			o.vx, o.vy = o.vx / sp * MAX_SPEED, o.vy / sp * MAX_SPEED
		end
		o.x += o.vx * dt
		o.y += o.vy * dt
		-- walls / ceiling
		if o.x < o.r then
			o.x = o.r
			o.vx = math.abs(o.vx) * o.rest
		elseif o.x > W - o.r then
			o.x = W - o.r
			o.vx = -math.abs(o.vx) * o.rest
		end
		if o.y < o.r then
			o.y = o.r
			o.vy = math.abs(o.vy) * 0.5
		end
		for _, c in cols do
			if c.kind == "peg" then
				local dx, dy = o.x - c.x, o.y - c.y
				local rr = o.r + c.r
				local d2 = dx * dx + dy * dy
				if d2 < rr * rr and d2 > 1e-6 then
					local d = math.sqrt(d2)
					resolve(o, dx / d, dy / d, rr - d, c.rest)
				end
			else
				local ex, ey = c.x2 - c.x1, c.y2 - c.y1
				local t = math.clamp(((o.x - c.x1) * ex + (o.y - c.y1) * ey) / (ex * ex + ey * ey), 0, 1)
				local px, py = c.x1 + ex * t, c.y1 + ey * t
				local dx, dy = o.x - px, o.y - py
				local rr = o.r + c.half
				local d2 = dx * dx + dy * dy
				if d2 < rr * rr and d2 > 1e-6 then
					local d = math.sqrt(d2)
					resolve(o, dx / d, dy / d, rr - d, c.rest)
				end
			end
		end
		table.insert(list, o)
	end
	-- orb-orb (equal mass), sorted sweep on x
	if #list <= ORB_ORB_LIMIT then
		table.sort(list, function(a, b)
			return a.x < b.x
		end)
		for i = 1, #list do
			local a = list[i]
			for j = i + 1, #list do
				local b = list[j]
				if b.x - a.x > a.r + b.r then
					break
				end
				local dx, dy = b.x - a.x, b.y - a.y
				local rr = a.r + b.r
				local d2 = dx * dx + dy * dy
				if d2 < rr * rr and d2 > 1e-6 then
					local d = math.sqrt(d2)
					local nx, ny = dx / d, dy / d
					local pen = (rr - d) / 2
					a.x -= nx * pen
					a.y -= ny * pen
					b.x += nx * pen
					b.y += ny * pen
					local rv = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
					if rv < 0 then
						local jimp = -(1 + 0.8) * rv / 2
						a.vx -= jimp * nx
						a.vy -= jimp * ny
						b.vx += jimp * nx
						b.vy += jimp * ny
					end
				end
			end
		end
	end
end

function Board:_update(dt)
	self.acc = math.min(self.acc + dt, 0.1)
	while self.acc >= STEP do
		self.acc -= STEP
		self:_physics(STEP)
	end
	local collected = {}
	for id, o in self.orbs do
		-- anti-stuck nudge (orb resting on a peg/funnel)
		if math.abs(o.vx) + math.abs(o.vy) < 8 then
			o.stillT += dt
			if o.stillT > 0.5 then
				o.vx += (math.random() - 0.5) * 120
				o.vy -= 40
				o.stillT = 0
			end
		else
			o.stillT = 0
		end
		if F.isCollected(self.tier, o.x, o.y) then
			table.insert(collected, o)
		else
			o.gui.Position = UDim2.fromScale(o.x / W, o.y / H)
			if o.rainbow then
				o.rainbow.Rotation = (os.clock() * 180) % 360
			end
		end
	end
	for _, o in collected do
		self.orbs[o.id] = nil
		self.count -= 1
		o.gui:Destroy()
		if self.onCollect then
			self.onCollect(o.id, o.x, o)
		end
	end
end

function Board:destroy()
	self.conn:Disconnect()
	self.root:Destroy()
end

return Board
