--!nonstrict
-- Client side of the shared Mega Board.
--
-- No orb ever collides with another player's orb, and nothing is replicated per frame:
--   * YOUR orbs: full physics (pegs + your own orbs), and they decide your payout (same as before:
--     the server validates the id + timing, the x picks the slot).
--   * OTHER players' orbs ("ghosts"): the server relays a sample of their spawns; each client
--     simulates them locally against pegs only. Purely visual, so they're cheap and capped.
-- Rendering: pooled anchored parts (no collision/query/touch/shadows) moved with one BulkMoveTo
-- per frame, so hundreds of orbs cost about the same as one.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.OrbConfig)
local Progression = require(Shared.Progression)
local F = require(Shared.OrbFormulas)
local MB = require(Shared.MegaBoard)

local STEP = 1 / 120
local ORB_ORB_LIMIT = 220
local GHOST_CAP = 120 -- other players' orbs alive at once on this client
local TAG_CAP = 12 -- name tags on rare ghost orbs
local POPUP_GAP = 0.08
local HIDE = CFrame.new(0, -1000, 0)
local DEPTH = 2 -- orbs roll 2 studs in front of the backboard

local W = MB.W
local REST = { orb = 0.9, diamond = 0.6, weather = 0.7 }
local VARIANT = {
	Shiny = { material = Enum.Material.Glass, reflectance = 0.4 },
	Glowing = { material = Enum.Material.Neon },
}

local Mega = {}
Mega.__index = Mega

function Mega.new(world: Instance)
	local self = setmetatable({}, Mega)
	self.world = world
	self.board = world:WaitForChild("MegaBoard")
	self.pegs = MB.pegs()
	self.grid = MB.buckets(self.pegs)
	self.rot = MB.CF - MB.CF.Position
	self.orbs = {} -- [key] = orb ; own ids are numbers, ghosts are "g"..n strings
	self.count = 0 -- own orbs only (HUD cap label)
	self.ghostCount = 0
	self.ghostSeq = 0
	self.tier = 0
	self.onCollect = nil
	self.acc = 0
	self.lastPopup = 0
	self.tags = 0
	self.folder = Instance.new("Folder")
	self.folder.Name = "MegaOrbs"
	self.folder.Parent = workspace
	self.pool = {}
	self.popups = {}
	self.bursts = self:_makeBurst()
	self.conn = RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end)
	return self
end

---------------------------------------------------------------- slot labels (per player)

function Mega:setLayout(tier: number)
	self.tier = tier
	for _, panel in self.board:WaitForChild("Slots"):GetChildren() do
		local x0, x1 = panel:GetAttribute("X0"), panel:GetAttribute("X1")
		if x0 then
			local sg = panel:FindFirstChild("Mult") or Instance.new("SurfaceGui")
			sg.Name = "Mult"
			sg.Face = Enum.NormalId.Front
			sg.PixelsPerStud = 6
			sg.Parent = panel
			local t = sg:FindFirstChild("T") or Instance.new("TextLabel")
			t.Name = "T"
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextStrokeTransparency = 0
			local m = F.slotMult(tier, (x0 + x1) / 2)
			t.Text = "x" .. tostring(m)
			t.TextColor3 = if m >= 2 then Color3.fromRGB(255, 92, 170) else Color3.new(1, 1, 1)
			t.Parent = sg
		end
	end
end

---------------------------------------------------------------- parts

function Mega:_part()
	local p = table.remove(self.pool)
	if not p then
		p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = self.folder
	end
	return p
end

function Mega:_release(o)
	local p = o.part
	if o.tag then
		o.tag:Destroy()
		self.tags -= 1
	end
	p.CFrame = HIDE
	p.Reflectance = 0
	table.insert(self.pool, p)
end

local function rarityColor(k)
	local c = Progression.Rarities[k].color
	return Color3.fromRGB(c[1], c[2], c[3])
end

function Mega:_dress(o)
	local p = self:_part()
	local d = o.r * 2 * MB.STUD
	if o.kind == "diamond" then
		p.Shape = Enum.PartType.Block
		p.Size = Vector3.new(d * 0.8, d * 0.8, d * 0.8)
		p.Color = Color3.fromRGB(92, 242, 255)
		p.Material = Enum.Material.Neon
	else
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(d, d, d)
		p.Color = if o.kind == "weather" then Color3.fromRGB(167, 110, 255) else rarityColor(o.rarity)
		local v = VARIANT[o.variant]
		p.Material = if o.rare then Enum.Material.Neon elseif v then v.material else Enum.Material.SmoothPlastic
		p.Reflectance = v and v.reflectance or 0
	end
	p.Transparency = if o.ghost and not o.rare then 0.25 else 0
	o.part = p
	o.rainbow = o.variant == "Rainbow"
	if o.ghost and o.rare and o.owner and self.tags < TAG_CAP then
		self.tags += 1
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(160, 36)
		bb.StudsOffset = Vector3.new(0, d / 2 + 2, 0)
		bb.MaxDistance = 300
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextStrokeTransparency = 0
		t.TextColor3 = p.Color
		t.Text = o.owner .. "\n" .. (o.kind == "orb" and Progression.Rarities[o.rarity].name or "")
		t.Parent = bb
		bb.Adornee = p
		bb.Parent = self.folder
		o.tag = bb
	end
end

---------------------------------------------------------------- adding orbs

function Mega:_add(key, info, x, y, vx, vy, data, ghost, owner)
	if self.orbs[key] then
		return
	end
	local base = if info.kind == "orb" then (data and F.orbRadius(data, info.rarity) or Progression.Rarities[info.rarity].radius) else Config.Board.SpecialOrbRadius
	local o = {
		key = key, id = key, kind = info.kind, rarity = info.rarity, variant = info.variant,
		x = x, y = y, vx = vx or 0, vy = vy or 0, r = base * MB.ORB_SCALE, rest = REST[info.kind] or 0.9,
		stillT = 0, ghost = ghost, owner = owner, rare = info.rare,
	}
	self:_dress(o)
	self.orbs[key] = o
	if ghost then
		self.ghostCount += 1
	else
		self.count += 1
	end
end

local function spawnX()
	local B = Config.Board
	return B.SpawnXMin + math.random() * (B.SpawnXMax - B.SpawnXMin)
end

function Mega:spawn(list, data)
	for _, info in list do
		self:_add(info.id, info, spawnX(), MB.SPAWN_Y, (math.random() - 0.5) * 30, 0, data, false)
	end
end

function Mega:duplicate(pairs_, data)
	for _, p in pairs_ do
		local src = self.orbs[p[2]]
		if src then
			self:_add(p[1], src, src.x + (math.random() - 0.5) * 4, src.y, -src.vx, src.vy, data, false)
		end
	end
end

-- other players' orbs: { {kind, rarity, variant, rare}, ... }
function Mega:ghosts(owner: string, list)
	for _, info in list do
		if self.ghostCount >= GHOST_CAP and not info.rare then
			continue
		end
		self.ghostSeq += 1
		self:_add("g" .. self.ghostSeq, info, spawnX(), MB.SPAWN_Y, (math.random() - 0.5) * 30, 0, nil, true, owner)
	end
end

function Mega:clear()
	for key, o in self.orbs do
		if not o.ghost then
			self:_release(o)
			self.orbs[key] = nil
		end
	end
	self.count = 0
end

---------------------------------------------------------------- effects

function Mega:_makeBurst()
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.CFrame = HIDE
	p.Parent = self.folder
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Speed = NumberRange.new(20, 50)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 1
	e.Parent = p
	return { part = p, emitter = e }
end

function Mega:burst(x, y, color)
	local b = self.bursts
	b.part.CFrame = CFrame.new(MB.toWorld(x, y, DEPTH + 2))
	b.emitter.Color = ColorSequence.new(color)
	b.emitter:Emit(40)
end

function Mega:popup(x, msg, color)
	local now = os.clock()
	if now - self.lastPopup < POPUP_GAP then
		return
	end
	self.lastPopup = now
	local a = table.remove(self.popups)
	if not a then
		a = Instance.new("Part")
		a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
		a.Size = Vector3.one
		a.Parent = self.folder
		local bb = Instance.new("BillboardGui")
		bb.Name = "BB"
		bb.Size = UDim2.fromOffset(180, 40)
		bb.MaxDistance = 400
		bb.Parent = a
		local t = Instance.new("TextLabel")
		t.Name = "T"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextStrokeTransparency = 0
		t.Parent = bb
	end
	a.CFrame = CFrame.new(MB.toWorld(x, MB.H - MB.SLOT_H - 4, DEPTH + 3))
	local bb, t = a.BB, a.BB.T
	t.Text, t.TextColor3, t.TextTransparency, t.TextStrokeTransparency = msg, color, 0, 0
	bb.StudsOffset = Vector3.zero
	TweenService:Create(bb, TweenInfo.new(0.9), { StudsOffset = Vector3.new(0, 14, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.95, function()
		a.CFrame = HIDE
		table.insert(self.popups, a)
	end)
end

---------------------------------------------------------------- physics (logical units)

local function resolve(o, nx, ny, pen, rest)
	o.x += nx * pen
	o.y += ny * pen
	local vn = o.vx * nx + o.vy * ny
	if vn < 0 then
		local e = math.max(o.rest, rest or 0)
		o.vx -= (1 + e) * vn * nx
		o.vy -= (1 + e) * vn * ny
		o.vx *= 0.995
	end
end

function Mega:_physics(dt)
	local grid, cell = self.grid, MB.CELL
	local own = {}
	for _, o in self.orbs do
		o.vy += MB.GRAVITY * dt
		local sp = math.sqrt(o.vx * o.vx + o.vy * o.vy)
		if sp > MB.MAX_SPEED then
			o.vx, o.vy = o.vx / sp * MB.MAX_SPEED, o.vy / sp * MB.MAX_SPEED
		end
		o.x += o.vx * dt
		o.y += o.vy * dt
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
		local bucket = grid[math.floor(o.y / cell) * 64 + math.floor(o.x / cell)]
		if bucket then
			for _, c in bucket do
				local dx, dy = o.x - c.x, o.y - c.y
				local rr = o.r + c.r
				local d2 = dx * dx + dy * dy
				if d2 < rr * rr and d2 > 1e-6 then
					local d = math.sqrt(d2)
					resolve(o, dx / d, dy / d, rr - d, c.rest)
				end
			end
		end
		if not o.ghost then
			table.insert(own, o)
		end
	end
	-- orb-orb only between YOUR orbs (never across players)
	if #own <= ORB_ORB_LIMIT then
		table.sort(own, function(a, b)
			return a.x < b.x
		end)
		for i = 1, #own do
			local a = own[i]
			for j = i + 1, #own do
				local b = own[j]
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
						local jimp = -1.8 * rv / 2
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

local parts, cframes = {}, {}

function Mega:_update(dt)
	self.acc = math.min(self.acc + dt, 0.1)
	while self.acc >= STEP do
		self.acc -= STEP
		self:_physics(STEP)
	end
	table.clear(parts)
	table.clear(cframes)
	local done = {}
	local hue = (os.clock() * 0.5) % 1
	for key, o in self.orbs do
		if math.abs(o.vx) + math.abs(o.vy) < 6 then
			o.stillT += dt
			if o.stillT > 0.5 then
				o.vx += (math.random() - 0.5) * 80
				o.vy -= 30
				o.stillT = 0
			end
		else
			o.stillT = 0
		end
		if o.y > MB.COLLECT_Y then
			table.insert(done, o)
		else
			table.insert(parts, o.part)
			table.insert(cframes, self.rot + MB.toWorld(o.x, o.y, DEPTH))
			if o.rainbow then
				o.part.Color = Color3.fromHSV(hue, 0.8, 1)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for _, o in done do
		self.orbs[o.key] = nil
		if o.rare then
			self:burst(o.x, o.y, o.part.Color)
		end
		self:_release(o)
		if o.ghost then
			self.ghostCount -= 1
		else
			self.count -= 1
			if self.onCollect then
				self.onCollect(o.id, o.x, o)
			end
		end
	end
end

function Mega:destroy()
	self.conn:Disconnect()
	self.folder:Destroy()
end

return Mega
