--!strict
-- Animated multi-layer parallax background for the HUD.
-- Export each "BG/L*" frame from the Figma page "v4 – Clean Dark Blocky" as a 2560x720 PNG,
-- upload them and paste the asset ids below. Layers are drawn behind all other UI.
--
-- Per-layer motion:
--   * constant horizontal scroll (seamless: two copies leapfrog)
--   * mouse/touch parallax offset (deeper layers move less)
--   * idle effects: bob, pulse, twinkle, and spawned particles

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LAYERS = {
	-- name, image, scroll speed (px/s at 1280 width), mouse depth, effect
	{ name = "Sky", image = "rbxassetid://0", speed = 0, depth = 0.005, effect = "none" },
	{ name = "Stars", image = "rbxassetid://0", speed = 4, depth = 0.01, effect = "twinkle" },
	{ name = "FarSkyline", image = "rbxassetid://0", speed = 10, depth = 0.02, effect = "none" },
	{ name = "Islands", image = "rbxassetid://0", speed = 24, depth = 0.04, effect = "bob" },
	{ name = "NearCubes", image = "rbxassetid://0", speed = 60, depth = 0.07, effect = "sway" },
	{ name = "RaysFog", image = "rbxassetid://0", speed = 120, depth = 0.1, effect = "pulse" },
	{ name = "Sparkles", image = "rbxassetid://0", speed = 200, depth = 0.14, effect = "pulse" },
}

local SPARKLE_COUNT = 40
local SPARKLE_COLORS = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 210, 74), Color3.fromRGB(92, 242, 255) }

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ParallaxBackground"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -100 -- behind HUD
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(11, 4, 32)
root.BorderSizePixel = 0
root.ClipsDescendants = true
root.Parent = gui

type LayerState = { def: any, holder: Frame, a: ImageLabel, b: ImageLabel, scroll: number, phase: number }
local states: { LayerState } = {}

for i, def in LAYERS do
	local holder = Instance.new("Frame")
	holder.Name = def.name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1.1, 1.1) -- overscan so mouse offset never shows edges
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.ZIndex = i
	holder.Parent = root

	local function copy(): ImageLabel
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = def.image
		img.ScaleType = Enum.ScaleType.Stretch
		img.Size = UDim2.fromScale(2, 1) -- image is 2x screen wide
		img.ZIndex = i
		img.Parent = holder
		return img
	end
	table.insert(states, { def = def, holder = holder, a = copy(), b = copy(), scroll = 0, phase = math.random() * math.pi * 2 })
end

-- Extra live sparkles on top (cheap Frames, recycled)
type Sparkle = { f: Frame, x: number, y: number, vy: number, spin: number, life: number, max: number }
local sparkles: { Sparkle } = {}
local function resetSparkle(s: Sparkle, anywhere: boolean)
	s.x = math.random()
	s.y = if anywhere then math.random() else 1.05
	s.vy = 0.03 + math.random() * 0.08
	s.spin = (math.random() - 0.5) * 240
	s.max = 4 + math.random() * 6
	s.life = if anywhere then math.random() * s.max else 0
	local size = math.random(4, 10)
	s.f.Size = UDim2.fromOffset(size, size)
	s.f.BackgroundColor3 = SPARKLE_COLORS[math.random(#SPARKLE_COLORS)]
end
for _ = 1, SPARKLE_COUNT do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.ZIndex = #LAYERS + 1
	f.Parent = root
	local s = { f = f, x = 0, y = 0, vy = 0, spin = 0, life = 0, max = 1 }
	resetSparkle(s, true)
	table.insert(sparkles, s)
end

-- Mouse / touch target, smoothed
local target, current = Vector2.zero, Vector2.zero
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local vp = workspace.CurrentCamera.ViewportSize
		target = Vector2.new(input.Position.X / vp.X - 0.5, input.Position.Y / vp.Y - 0.5)
	end
end)

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	current = current:Lerp(target, math.min(dt * 4, 1))
	local width = root.AbsoluteSize.X * 1.1 * 2

	for _, s in states do
		local def = s.def
		s.scroll = (s.scroll + def.speed * dt * (root.AbsoluteSize.X / 1280)) % width
		s.a.Position = UDim2.fromOffset(-s.scroll, 0)
		s.b.Position = UDim2.fromOffset(width - s.scroll, 0)

		local ox = -current.X * def.depth * root.AbsoluteSize.X
		local oy = -current.Y * def.depth * root.AbsoluteSize.Y
		local ph = t + s.phase
		if def.effect == "bob" then
			oy += math.sin(ph * 0.9) * 10
		elseif def.effect == "sway" then
			oy += math.sin(ph * 1.4) * 14
			s.holder.Rotation = math.sin(ph * 0.6) * 1.5
		elseif def.effect == "pulse" then
			local a = 0.5 + 0.5 * math.sin(ph * 1.7)
			s.a.ImageTransparency = 0.15 + a * 0.45
			s.b.ImageTransparency = s.a.ImageTransparency
		elseif def.effect == "twinkle" then
			local a = 0.5 + 0.5 * math.sin(ph * 3.1) * math.sin(ph * 1.3)
			s.a.ImageTransparency = a * 0.6
			s.b.ImageTransparency = s.a.ImageTransparency
		end
		s.holder.Position = UDim2.new(0.5, ox, 0.5, oy)
	end

	for _, s in sparkles do
		s.life += dt
		s.y -= s.vy * dt
		if s.life >= s.max or s.y < -0.05 then
			resetSparkle(s, false)
		end
		local fade = math.sin(math.clamp(s.life / s.max, 0, 1) * math.pi)
		s.f.BackgroundTransparency = 1 - fade * 0.9
		s.f.Rotation += s.spin * dt
		s.f.Position = UDim2.new(s.x + math.sin(t + s.x * 10) * 0.01 - current.X * 0.18, 0, s.y - current.Y * 0.18, 0)
	end
end)
