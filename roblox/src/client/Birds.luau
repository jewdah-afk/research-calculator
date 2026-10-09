--!strict
-- Birds — every character's bird drawn locally, animated with src/three/View3D.js animBird() 1:1:
--   turn toward travel (rate dt*14) · ~2.4 hops per tile: s = |sin(phase*pi)|, hop = 0.22 s tiles, sy = 0.86 + 0.24 s
--   landing squash (1, or 1.4 after a jump) decaying at dt*6, sy -= squash*0.18 · idle breathing 1 + 0.025 sin(3t)
--   airborne sy = 1.12 · punch on pickup · xz = 1 + (1-sy)*0.6 · wings flap (air sin(30t)*0.7, run sin(24t)*0.35)
--   blink 0.12 s every 3.1 s.
-- Squash/stretch moves each part's OFFSET by the scale (no per-frame Part.Size changes — perf rule).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Models = require(Shared:WaitForChild("Models"))
local WorldTree = require(Shared:WaitForChild("WorldTree"))
local S = Models.S
local PX = 1 / 16   -- game px -> tiles

local Birds = {}

type PartRest = { part: BasePart, rest: CFrame, kind: string }
type Bird = { model: Model, parts: { PartRest }, heading: number, phase: number, lastS: number?, squash: number, prevAir: boolean,
	punch: number, eyes: { BasePart }, eyeSize: Vector3, blinking: boolean, shadow: BasePart }
local birds: { [Model]: Bird } = {}
local folder = Instance.new("Model"); folder.Name = "Birds"; folder.Parent = WorldTree.get("Actors")
do   -- cel look (owner 2026-10-09): the hen gets the same solid ink outline as the rest of the world
	local h = Instance.new("Highlight")
	h.OutlineColor = Color3.fromHex("#16181e"); h.OutlineTransparency = 0; h.FillTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded; h.Adornee = folder; h.Parent = folder
end
local shadows = Instance.new("Folder"); shadows.Name = "BirdShadows"; shadows.Parent = WorldTree.get("Actors")

local function build(): Bird
	local m = Models.bird()
	m.WorldPivot = CFrame.new(); m:ScaleTo(m:GetScale() * 1.25)   -- View3D bird scale (multiply: Models.bird already sized the asset)
	local parts: { PartRest } = {}
	local eyes = {}
	for _, p in m:GetChildren() do
		local bp = p :: BasePart
		bp.CastShadow = true
		local kind = if bp.Name == "wingL" then "wingL" elseif bp.Name == "wingR" then "wingR" else "body"
		table.insert(parts, { part = bp, rest = bp.CFrame, kind = kind })
		if bp.Name == "eyeL" or bp.Name == "eyeR" then table.insert(eyes, bp) end
	end
	m.Parent = folder
	-- contact shadow that stays on the ground while the bird hops / jumps (shrinks + fades with height)
	local sh = Instance.new("Part"); sh.Name = "Shadow"; sh.Shape = Enum.PartType.Cylinder; sh.Size = Vector3.new(0.02, 0.62 * S, 0.62 * S)
	sh.Color = Color3.fromHex("#1d2a17"); sh.Material = Enum.Material.SmoothPlastic; sh.Transparency = 0.62
	sh.Anchored = true; sh.CanCollide = false; sh.CanQuery = false; sh.CanTouch = false; sh.CastShadow = false; sh.Parent = shadows
	return { model = m, parts = parts, heading = 0, phase = 0, squash = 0, prevAir = false, punch = 0, eyes = eyes,
		eyeSize = if eyes[1] then eyes[1].Size else Vector3.one, blinking = false, shadow = sh }
end

-- the local player's punch (kernel collected)
local localBird: Bird? = nil
function Birds.punch() if localBird then localBird.punch = 1 end end

-- one bird, given its feet position (world), velocity in game px/s, height above ground (px)
local function animate(b: Bird, feet: Vector3, vx: number, vy: number, airZ: number, t: number, dt: number)
	local sp = math.sqrt(vx * vx + vy * vy)
	if sp > 3 then
		local target = math.atan2(-vx, -vy)   -- Roblox model front is -Z
		local d = target - b.heading; d = math.atan2(math.sin(d), math.cos(d))
		b.heading += d * math.min(1, dt * 14)
	end
	local grounded = math.abs(airZ) < 0.5
	local hop, sy = 0, 1
	if sp > 5 and grounded then
		b.phase += sp * PX * dt * 2.4
		local s = math.abs(math.sin(b.phase * math.pi))
		hop = s * 0.22; sy = 0.86 + s * 0.24
		if b.lastS ~= nil and (b.lastS :: number) > 0.15 and s < 0.15 then b.squash = 1 end
		b.lastS = s
	else
		b.phase = 0; sy = 1 + math.sin(t * 3) * 0.025
	end
	if b.prevAir and grounded then b.squash = 1.4 end
	b.prevAir = not grounded
	b.squash = math.max(0, b.squash - dt * 6)
	sy -= b.squash * 0.18
	if not grounded then sy = 1.12 end
	if b.punch > 0 then b.punch = math.max(0, b.punch - dt * 5); sy += math.sin(b.punch * 9) * 0.12 * b.punch end
	local k = 1 + (1 - sy) * 0.6
	local flap = if not grounded then math.sin(t * 30) * 0.7 elseif sp > 70 then math.sin(t * 24) * 0.35 else 0

	local pivot = CFrame.new(feet) * CFrame.Angles(0, b.heading, 0) * CFrame.new(0, hop * S, 0)
	local lift = (hop * S + math.max(0, airZ) / 16 * S) / S          -- tiles above the ground
	local ground = feet - Vector3.new(0, math.max(0, airZ) / 16 * S, 0)
	b.shadow.CFrame = CFrame.new(ground + Vector3.new(0, 0.075 * S, 0)) * CFrame.Angles(0, 0, math.rad(90))
	b.shadow.Transparency = 0.62 + math.min(0.3, lift * 0.35)
	for _, pr in b.parts do
		local o = pr.rest.Position
		local rotOnly = pr.rest - o
		local cf = pivot * CFrame.new(o.X * k, o.Y * sy, o.Z * k) * rotOnly
		if pr.kind == "wingL" then cf *= CFrame.Angles(0, 0, -flap - 0.02)
		elseif pr.kind == "wingR" then cf *= CFrame.Angles(0, 0, flap + 0.02) end
		pr.part.CFrame = cf
	end
	-- blink (a size swap only at the blink edges, not per frame)
	local blink = (t % 3.1) < 0.12
	if blink ~= b.blinking then
		b.blinking = blink
		for _, e in b.eyes do e.Size = if blink then Vector3.new(b.eyeSize.X, b.eyeSize.Y * 0.15, b.eyeSize.Z) else b.eyeSize end
	end
end

-- per frame: local body (exact sim state) + every other character (from its replicated root)
function Birds.step(t: number, dt: number, localChar: Model?, body: any?)
	local seen: { [Model]: boolean } = {}
	for _, plr in Players:GetPlayers() do
		local ch = plr.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (ch and hrp) then continue end
		seen[ch] = true
		local b = birds[ch]
		if not b then b = build(); birds[ch] = b end
		if ch == localChar and body then
			localBird = b
			local feet = hrp.Position - Vector3.new(0, hrp.Size.Y / 2, 0)
			animate(b, feet, body.vx, body.vy, body.z - body.groundZ, t, dt)
		else
			local v = hrp.AssemblyLinearVelocity
			local feet = hrp.Position - Vector3.new(0, hrp.Size.Y / 2, 0)
			animate(b, feet, v.X / S * 16, v.Z / S * 16, feet.Y / S * 16, t, dt)
		end
	end
	for ch, b in birds do
		if not seen[ch] then b.model:Destroy(); b.shadow:Destroy(); birds[ch] = nil end
	end
end

return Birds
