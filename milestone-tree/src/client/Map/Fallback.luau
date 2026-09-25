--!strict
--[[
	Fallback: the procedural realm drawn while the painted tiles have no asset ids (plan 3.5), so the map looks
	designed, not broken, before the art upload.

	    Fallback.sky(plane, sprites, layer)       the L0 plane: a void -> deep violet gradient over the whole Box, and in
	                                              the moving sky container (so it parallaxes) a soft sun, two nebula
	                                              glows and 60 seeded stars
	    Fallback.world(sprites, realm)            the L5 world container: a glass socket per node with a rim glow in
	                                              its hue, and the rift's crimson ellipse
	    Fallback.breathe(handle, reduced)         the rift glow's breathing (the rift_glow sprite's curve)

	Everything is Frames with UIGradient / UICorner / UIStroke, in Scale units of its container. Radial gradients are
	used when the engine has them (Theme.caps.Radial); otherwise the glows are flat soft discs or left out.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Theme"))
local MapCamera = require(script.Parent:WaitForChild("MapCamera"))

local Fallback = {}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end
local function frame(parent: Instance, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Active = false
	f.ZIndex = z
	f.Parent = parent
	return f
end
local function round(f: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
end
-- a soft radial blob (colour, peak alpha) in the container's scale units; nil without Radial gradients
local function blob(parent: Instance, name: string, cx: number, cy: number, w: number, h: number, color: Color3,
	alpha: number, z: number, hard: boolean?): Frame?
	local f = frame(parent, name, z)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx, cy)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	if Theme.caps.Radial then
		f.BackgroundTransparency = 0
		local g = Instance.new("UIGradient")
		g.Type = Enum.GradientType.Radial
		g.Transparency = if hard
			then NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - alpha),
				NumberSequenceKeypoint.new(0.35, 1 - alpha * 0.8),
				NumberSequenceKeypoint.new(1, 1),
			})
			else NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - alpha),
				NumberSequenceKeypoint.new(0.45, 1 - alpha * 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
		g.Parent = f
	else
		if not hard then
			f:Destroy()
			return nil
		end
		f.BackgroundTransparency = 1 - alpha * 0.5
		round(f)
	end
	return f
end

export type Layer = { w: number, h: number }

-- the sky: `plane` is the non-moving L0 plane (full Box), `sprites` the moving L0 container (layer-local scale units)
function Fallback.sky(plane: Frame, sprites: Frame, layer: Layer): { Instance }
	local made: { Instance } = {}
	local back = frame(plane, "FallbackSky", 0)
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundTransparency = 0
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 5, 13)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 10, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 16, 70)),
	})
	g.Parent = back
	table.insert(made, back)
	-- the cosmic sun at (0.36 w, 0.26 h) of the sky, and two nebula glows: violet over the tree, crimson toward the rift
	local aspect = layer.w / layer.h
	local sun = blob(sprites, "FallbackSun", 0.36, 0.26, 0.34, 0.34 * aspect, Color3.fromRGB(255, 214, 150), 0.32, 0)
	local halo = blob(sprites, "FallbackSunHalo", 0.36, 0.26, 0.09, 0.09 * aspect, Color3.fromRGB(255, 240, 210), 0.55, 0, true)
	local neb1 = blob(sprites, "FallbackNebulaA", 0.3, 0.55, 0.62, 0.5, Color3.fromRGB(120, 60, 220), 0.22, 0)
	local neb2 = blob(sprites, "FallbackNebulaB", 0.78, 0.5, 0.5, 0.6, Color3.fromRGB(200, 30, 90), 0.2, 0)
	for _, b in { sun, halo, neb1, neb2 } do
		if b then table.insert(made, b) end
	end
	-- 60 seeded stars, 2-3 local px, alpha .3-.7
	local rng = MapCamera.rng(7)
	local holder = frame(sprites, "FallbackStars", 0)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	for i = 1, 60 do
		local d = 2 + rng()
		local s = frame(holder, "Star" .. i, 1)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(rng(), rng() * 0.92)
		s.Size = UDim2.fromScale(d / layer.w, d / layer.h)
		s.BackgroundColor3 = if rng() < 0.3 then Color3.fromRGB(210, 190, 255) else Color3.fromRGB(255, 250, 240)
		s.BackgroundTransparency = 1 - (0.3 + rng() * 0.4)
		round(s)
	end
	table.insert(made, holder)
	return made
end

export type RealmData = { world: { w: number, h: number }, nodes: { [string]: { number } }, alias: { [string]: string },
	rift: { cx: number, cy: number, rx: number, ry: number } }

-- the art socket key -> the game id (the socket cr is the layer cp)
local function gameId(realm: RealmData, key: string): string
	for id, art in realm.alias do
		if art == key then return id end
	end
	return key
end

export type World = { rift: Frame?, core: Frame?, made: { Instance } }

-- the world: `sprites` is the moving L5 container (world scale units: x / 3840, y / 2560)
function Fallback.world(sprites: Frame, realm: RealmData): World
	local W, H = realm.world.w, realm.world.h
	local made: { Instance } = {}
	local holder = frame(sprites, "FallbackWorld", 0)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	table.insert(made, holder)
	-- the rift: a crimson ellipse 1150 x 1553 at the gate, a hotter core and the tear
	local r = realm.rift
	local rift = blob(holder, "FallbackRift", r.cx / W, r.cy / H, 1150 / W, 1553 / H, Color3.fromRGB(255, 46, 99), 0.5, 1, true)
	local core = blob(holder, "FallbackRiftCore", r.cx / W, r.cy / H, 520 / W, 960 / H, Color3.fromRGB(232, 70, 190), 0.45, 2, true)
	local tear = frame(holder, "FallbackTear", 3)
	tear.AnchorPoint = Vector2.new(0.5, 0.5)
	tear.Position = UDim2.fromScale(r.cx / W, r.cy / H)
	tear.Size = UDim2.fromScale(46 / W, 760 / H)
	tear.BackgroundColor3 = Color3.fromRGB(255, 190, 215)
	tear.BackgroundTransparency = 0.15
	round(tear)
	if Theme.caps.Radial then
		local tg = Instance.new("UIGradient")
		tg.Type = Enum.GradientType.Radial
		tg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		tg.Parent = tear
	end
	-- a glass socket per node with a rim glow in its hue
	local keys = {}
	for k in realm.nodes do table.insert(keys, k) end
	table.sort(keys)
	for _, key in keys do
		local p = realm.nodes[key]
		local hue = Theme.hue(gameId(realm, key))
		blob(holder, "Glow_" .. key, p[1] / W, p[2] / H, 230 / W, 230 / H, hue, 0.25, 4, true)
		local disc = frame(holder, "Socket_" .. key, 5)
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(p[1] / W, p[2] / H)
		disc.Size = UDim2.fromScale(150 / W, 150 / H)
		disc.BackgroundColor3 = Theme.C.panel
		disc.BackgroundTransparency = 0.15
		round(disc)
		local st = Instance.new("UIStroke")
		st.Color = Theme.C.stroke
		st.Thickness = 3
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = disc
	end
	return { rift = rift, core = core, made = made }
end

-- the rift glow breathes like the rift_glow sprite: alpha .42 +- .14 and scale 1 +- .035, 2.8 s, in phase
function Fallback.breathe(w: World, reduced: boolean): { Tween }
	local tweens: { Tween } = {}
	local rift = w.rift
	if rift == nil then return tweens end
	local scale = rift:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = rift
	if reduced then
		scale.Scale = 1
		return tweens
	end
	local info = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local base = rift.BackgroundTransparency
	rift.BackgroundTransparency = math.clamp(base + 0.14, 0, 1)
	scale.Scale = 0.965
	local t1 = TweenService:Create(rift, info, { BackgroundTransparency = math.clamp(base - 0.14, 0, 1) })
	local t2 = TweenService:Create(scale, info, { Scale = 1.035 })
	t1:Play()
	t2:Play()
	table.insert(tweens, t1)
	table.insert(tweens, t2)
	return tweens
end

Fallback.rgb = rgb

return Fallback
