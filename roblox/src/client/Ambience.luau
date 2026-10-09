--!nonstrict
-- Ambience: subtle life in the air around wherever the camera is looking.
--   * wind streaks: faint stretched wisps drifting with the shared gust signal (IslandView.wind)
--   * island air: what drifts on each island (park leaves + petals, garden petals, forest leaves, desert sand, mine dust,
--     bridge spray, castle petals, expedition leaves, echo motes rising)
--   * weather: shared by every player (from server time): mostly clear, sometimes breezy, now and then a light shower
--     (never on the Desert); rain greys the light a touch and blends in/out over ~20 s
-- QA: PlayerGui:SetAttribute("PeckwoodWeather", "clear" | "breezy" | "rain") forces a state.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local World = require(RS:WaitForChild("Peckwood"):WaitForChild("World"))
local WorldTree = require(RS:WaitForChild("Peckwood"):WaitForChild("WorldTree"))
local IslandView = require(script.Parent:WaitForChild("IslandView"))

local Ambience = {}
local S = 4
local DOT = "rbxasset://textures/whiteCircle.png"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function seq(...) local a = { ... }; local k = {}; for n = 1, #a, 2 do table.insert(k, NumberSequenceKeypoint.new(a[n], a[n + 1])) end; return NumberSequence.new(k) end
local function cols(list)
	if #list == 1 then return ColorSequence.new(Color3.fromHex(list[1])) end
	-- particles pick colours across the sequence; a stepped sequence gives a few distinct tints
	local k = {}
	for n, h in list do
		local c = Color3.fromHex(h)
		table.insert(k, ColorSequenceKeypoint.new((n - 1) / #list, c))
		table.insert(k, ColorSequenceKeypoint.new(math.min(1, n / #list - 0.001), c))
	end
	k[#k] = ColorSequenceKeypoint.new(1, Color3.fromHex(list[#list]))
	return ColorSequence.new(k)
end

local AIR = {   -- colours, size, rate per wind, rise (+up) or fall, spin, texture
	park = { c = { "8fc46a", "fff1a8", "f2c6d8" }, size = 0.35, rate = 5, vy = -1.2 },
	garden = { c = { "ffcf3a", "ffffff", "ff9fc0" }, size = 0.35, rate = 7, vy = -1 },
	castle = { c = { "c9b6ff", "ffffff" }, size = 0.3, rate = 4, vy = -1 },
	bridge = { c = { "e8f7ff" }, size = 0.3, rate = 6, vy = 0.4 },
	forest = { c = { "6fa553", "d88a3a", "c8b040" }, size = 0.42, rate = 9, vy = -1.6 },
	mine = { c = { "b0a89c" }, size = 0.9, rate = 4, vy = 0.2, tex = SMOKE },
	desert = { c = { "ecd9a2", "e2cc92" }, size = 0.25, rate = 14, vy = -0.2, streak = true },
	expedition = { c = { "7fbf55", "ff6fa0" }, size = 0.4, rate = 7, vy = -1.4 },
	echo = { c = { "9fd8ff", "c79fff" }, size = 0.28, rate = 6, vy = 2.2, glow = true },
}

local anchor, wind, air, rain, cc
local cur, state, blend = nil, "clear", { breezy = 0, rain = 0 }

-- Each effect emits from ONE attachment that jumps to a random point of the 150 x 26 x 120 volume every frame
-- (same spread as a Box volume). A big invisible box part over the island blocked every Occluded Highlight outline
-- behind it (hen, eggs, fence lost their ink lines, 2026-10-09), so the anchor is a tiny part now.
local VOL = Vector3.new(150, 26, 120)
local rng = Random.new()
local atts = {}
local function emitter(name, props)
	local att = Instance.new("Attachment"); att.Name = name; att.Parent = anchor
	table.insert(atts, att)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.LockedToPart = false; pe.Rate = 0
	for k, v in props do pe[k] = v end
	pe.Parent = att
	return pe
end

function Ambience.start()
	anchor = Instance.new("Part")
	anchor.Name = "Ambience"; anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
	anchor.Transparency = 1; anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.Parent = WorldTree.get("Atmosphere")
	wind = emitter("Wind", {
		Texture = DOT, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 0.2,
		Size = seq(0, 0, 0.2, 0.22, 0.8, 0.22, 1, 0), Squash = seq(0, 4, 1, 4),
		Transparency = seq(0, 1, 0.25, 0.86, 0.75, 0.86, 1, 1),
		Lifetime = NumberRange.new(1.6, 2.6), Speed = NumberRange.new(26, 40), SpreadAngle = Vector2.new(4, 6),
		EmissionDirection = Enum.NormalId.Right, Orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	air = emitter("Air", {
		Texture = DOT, LightEmission = 0, Size = seq(0, 0.3, 1, 0.3),
		Transparency = seq(0, 1, 0.15, 0.15, 0.85, 0.2, 1, 1),
		Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(25, 25),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120), Squash = seq(0, 0.6, 1, 0.6),
		EmissionDirection = Enum.NormalId.Right, Drag = 0.4,
	})
	rain = emitter("Rain", {
		Texture = DOT, Color = ColorSequence.new(Color3.fromHex("cfe0f2")), LightEmission = 0.15,
		Size = seq(0, 0.09, 1, 0.09), Squash = seq(0, 7, 1, 7), Transparency = seq(0, 1, 0.1, 0.45, 1, 0.55),
		Lifetime = NumberRange.new(0.5, 0.7), Speed = NumberRange.new(70, 85), SpreadAngle = Vector2.new(2, 2),
		EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	cc = Instance.new("ColorCorrectionEffect"); cc.Name = "Weather"; cc.Parent = Lighting
	RunService.RenderStepped:Connect(Ambience.step)
end

-- shared weather: 8-minute slots (8 game hours), each slot picks clear / breezy / rain from a hash of its index
local function weatherAt(t)
	local slot = math.floor(t / 480)
	local h = math.sin(slot * 12.9898) * 43758.5453; h -= math.floor(h)
	return if h < 0.62 then "clear" elseif h < 0.86 then "breezy" else "rain"
end

local acc = 0
function Ambience.step(dt)
	local cam = workspace.CurrentCamera
	local focus = cam.Focus.Position
	anchor.CFrame = CFrame.new(focus + Vector3.new(-40, 10, 0))
	for _, att in atts do
		att.Position = Vector3.new((rng:NextNumber() - 0.5) * VOL.X, (rng:NextNumber() - 0.5) * VOL.Y, (rng:NextNumber() - 0.5) * VOL.Z)
	end
	local t = workspace:GetServerTimeNow()
	local w = IslandView.wind(t)
	acc += dt
	if acc < 0.2 then return end   -- emitter settings at 5 Hz
	acc = 0
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local forced = pg and pg:GetAttribute("PeckwoodWeather")
	state = if typeof(forced) == "string" then forced else weatherAt(t)
	local isl = World.nearest(focus.X / S + 20, focus.Z / S + 15)
	if isl.id == "desert" and state == "rain" then state = "breezy" end
	for _, k in { "breezy", "rain" } do
		local target = if state == k then 1 else 0
		blend[k] += (target - blend[k]) * math.min(1, 0.2 / 4)   -- ~20 s blend at 5 Hz
		if math.abs(blend[k] - target) < 0.01 then blend[k] = target end
	end
	local hour = IslandView.hour()
	local night = if hour >= 20 or hour < 5 then 1 elseif hour > 18.5 then (hour - 18.5) / 1.5 elseif hour < 6.5 then 1 - (hour - 5) / 1.5 else 0
	local gust = w + blend.breezy * 0.5
	-- wind wisps: few, faint, more in a breeze; fewer at night
	wind.Rate = (1.5 + gust * 4) * (1 - night * 0.6)
	wind.Speed = NumberRange.new(24 + gust * 10, 36 + gust * 14)
	-- island air
	if isl.id ~= cur then
		cur = isl.id
		local a = AIR[cur] or AIR.park
		air.Texture = a.tex or DOT
		air.Color = cols(a.c)
		air.Size = if a.tex then seq(0, a.size, 1, a.size * 2.5) else seq(0, a.size, 1, a.size)
		air.Transparency = if a.tex then seq(0, 1, 0.3, 0.8, 1, 1) else seq(0, 1, 0.15, 0.15, 0.85, 0.2, 1, 1)
		air.LightEmission = if a.glow then 0.8 else 0
		air.Squash = if a.streak then seq(0, 3, 1, 3) else seq(0, 0.6, 1, 0.6)
		air.Orientation = if a.streak then Enum.ParticleOrientation.VelocityParallel else Enum.ParticleOrientation.FacingCamera
		air.RotSpeed = if a.streak then NumberRange.new(0, 0) else NumberRange.new(-120, 120)
	end
	local a = AIR[cur] or AIR.park
	air.Rate = a.rate * (0.4 + gust * 0.6) * (if a.glow then 0.5 + night else 1 - night * 0.7) * (1 - blend.rain * 0.7)
	air.Acceleration = Vector3.new(gust * 2, a.vy, 0)
	air.Speed = NumberRange.new(3 + gust * 4, 6 + gust * 8)
	-- rain
	rain.Rate = 260 * blend.rain
	rain.Acceleration = Vector3.new(gust * 10, 0, 0)
	cc.Brightness = -0.035 * blend.rain
	cc.Saturation = -0.12 * blend.rain
	cc.Contrast = 0.03 * blend.rain
end

return Ambience
