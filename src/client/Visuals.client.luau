--!strict
--[[
	Visuals.client.luau — renders Types.VisualSpec events.

	The server fires a VisualSpec through WeaponContext.visual for effects that
	have no simulation state of their own: the Whip's slash arc, the Garlic
	aura pulse, the Santa Water bottle and the zone it opens, and the Lightning
	Ring strike. Projectiles are NOT here — those live in server/ProjectilePool
	and replicate as real parts.

	These are placeholder shapes, obviously ours: coloured blocks and cylinders
	that fade out. They carry no gameplay state whatsoever. Every hit was
	already resolved on the server before the spec was sent, so dropping,
	delaying or mis-drawing one of these cannot change the outcome of a run.
	That is what makes it safe to bound the pool and silently drop overflow.

	Pooled: Instance.new is called only while the pool is being filled, never
	in the per-frame loop and never on an incoming event. A spec that arrives
	with the pool exhausted is dropped rather than allocating, which keeps a
	300-enemy spike from stalling the client.

	Sizes, colours and lifetimes are Tuning.visuals, flagged NOT from research:
	the reference is 2D sprite art with no stud equivalent.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require("../shared/Net")
local Tuning = require("../shared/Tuning")

-- Net.VisualPayload mirrors Types.VisualSpec (see shared/Net.luau).
type VisualSpec = Net.VisualPayload

local VISUALS = Tuning.visuals
local COLORS = VISUALS.colors
local HALF = Tuning.uiHalf

-- Kind strings, matching the VISUAL_* constants in src/server/Weapons.
local KIND_SLASH = "slash"
local KIND_AURA = "garlic_aura"
local KIND_DROP = "santa_water_drop"
local KIND_ZONE = "santa_water_zone"
local KIND_STRIKE = "lightning_ring_strike"

local function color(c: { r: number, g: number, b: number }): Color3
	return Color3.new(c.r, c.g, c.b)
end

-- ------------------------------------------------------------------- pool
local folder = Instance.new("Folder")
folder.Name = "SurvivorsLikeVisuals"
folder.Parent = Workspace

-- Structure of arrays, same shape as the server pools: a part per slot plus
-- parallel lifetime columns, and a free list of slot indices.
-- `Part`, not `BasePart`: only Part carries `Shape`.
local parts: { Part } = table.create(VISUALS.poolSize)
local ageCol: { number } = table.create(VISUALS.poolSize, 0)
local lifeCol: { number } = table.create(VISUALS.poolSize, 0)
local activeCol: { boolean } = table.create(VISUALS.poolSize, false)
-- Whether this slot is a Santa Water bottle, which falls as it fades. Kept as
-- its own column so the per-frame loop never reads a property back off a part.
local fallsCol: { boolean } = table.create(VISUALS.poolSize, false)
local free: { number } = table.create(VISUALS.poolSize)
local freeCount = 0

for i = 1, VISUALS.poolSize do
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(0, VISUALS.hiddenY, 0)
	part.Parent = folder

	parts[i] = part
	ageCol[i] = 0
	lifeCol[i] = 0
	activeCol[i] = false
	fallsCol[i] = false

	freeCount += 1
	free[freeCount] = i
end

--- Takes a slot, or nil when the pool is exhausted (the spec is then dropped).
local function acquire(): number?
	if freeCount == 0 then
		return nil
	end
	local slot = free[freeCount]
	freeCount -= 1
	activeCol[slot] = true
	fallsCol[slot] = false
	ageCol[slot] = 0
	return slot
end

local function release(slot: number)
	activeCol[slot] = false
	local part = parts[slot]
	part.CFrame = CFrame.new(0, VISUALS.hiddenY, 0)
	part.Transparency = 1
	freeCount += 1
	free[freeCount] = slot
end

-- ------------------------------------------------------------------ shapes
local function duration(spec: VisualSpec): number
	local d = spec.duration
	if d == nil or d <= 0 then
		return VISUALS.defaultDuration
	end
	return d
end

--- `radius` is already in studs: the server applied the weapon's Area and
--- Tuning.areaScale before sending the spec. Never rescaled here.
local function specRadius(spec: VisualSpec): number
	local r = spec.radius
	if r == nil then
		return VISUALS.strikeRadius
	end
	return r
end

local function draw(spec: VisualSpec)
	local slot = acquire()
	if slot == nil then
		return
	end

	local part = parts[slot]
	local kind = spec.kind
	local radius = specRadius(spec)
	lifeCol[slot] = duration(spec)
	part.Transparency = VISUALS.startTransparency

	if kind == KIND_SLASH then
		-- A flat bar laid along the slash direction. `angle` is the facing
		-- the server swung at; the arc reaches `radius` studs outward.
		part.Shape = Enum.PartType.Block
		part.Color = color(COLORS.slash)
		part.Size = Vector3.new(radius * 2, VISUALS.slashHeight, VISUALS.slashThickness)
		local angle = spec.angle
		local yaw = if angle == nil then 0 else angle
		part.CFrame = CFrame.new(spec.x, VISUALS.slashHeight * HALF, spec.z) * CFrame.Angles(0, yaw, 0)
	elseif kind == KIND_AURA then
		part.Shape = Enum.PartType.Cylinder
		part.Color = color(COLORS.aura)
		-- A Cylinder's length runs along X, so lay it flat to read as a ring.
		part.Size = Vector3.new(VISUALS.auraThickness, radius * 2, radius * 2)
		part.CFrame = CFrame.new(spec.x, VISUALS.groundY, spec.z) * CFrame.Angles(0, 0, math.pi * HALF)
	elseif kind == KIND_ZONE then
		part.Shape = Enum.PartType.Cylinder
		part.Color = color(COLORS.zone)
		part.Size = Vector3.new(VISUALS.zoneThickness, radius * 2, radius * 2)
		part.CFrame = CFrame.new(spec.x, VISUALS.groundY, spec.z) * CFrame.Angles(0, 0, math.pi * HALF)
	elseif kind == KIND_DROP then
		part.Shape = Enum.PartType.Ball
		part.Color = color(COLORS.drop)
		part.Size = Vector3.new(VISUALS.dropRadius * 2, VISUALS.dropRadius * 2, VISUALS.dropRadius * 2)
		part.CFrame = CFrame.new(spec.x, VISUALS.dropHeight, spec.z)
		fallsCol[slot] = true
	elseif kind == KIND_STRIKE then
		part.Shape = Enum.PartType.Cylinder
		part.Color = color(COLORS.strike)
		-- Upright column: rotate the X-aligned cylinder onto Y.
		part.Size = Vector3.new(VISUALS.strikeHeight, radius * 2, radius * 2)
		part.CFrame = CFrame.new(spec.x, VISUALS.strikeHeight * HALF, spec.z) * CFrame.Angles(0, 0, math.pi * HALF)
	else
		-- An unknown kind means the server grew an effect this client does not
		-- know yet. Give the slot back rather than drawing a stray block.
		release(slot)
	end
end

-- ------------------------------------------------------------------- loop
local function step(dt: number)
	for slot = 1, VISUALS.poolSize do
		if activeCol[slot] then
			local age = ageCol[slot] + dt
			local life = lifeCol[slot]
			if age >= life then
				release(slot)
			else
				ageCol[slot] = age
				local part = parts[slot]
				-- Fade from startTransparency to fully invisible over the
				-- effect's lifetime. A Santa Water bottle also falls.
				local t = age / life
				part.Transparency = VISUALS.startTransparency + (1 - VISUALS.startTransparency) * t
				if fallsCol[slot] then
					local position = part.Position
					part.CFrame = CFrame.new(
						position.X,
						VISUALS.dropHeight + (VISUALS.groundY - VISUALS.dropHeight) * t,
						position.Z
					)
				end
			end
		end
	end
end

-- Net.client() yields until the server has published the remotes.
local net = Net.client()

net.visual.OnClientEvent:Connect(function(spec: VisualSpec)
	draw(spec)
end)

RunService.RenderStepped:Connect(step)
