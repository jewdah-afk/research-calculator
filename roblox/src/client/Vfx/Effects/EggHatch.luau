--!nonstrict
-- egg_hatch: the reveal, scaled by rarity (Common 1 .. Mythic 6). A = wind-up length (0.65 .. 2.1 s).
-- Hierarchy: HERO = the crack flash (white-hot core + rarity rim + inked needles), SUPPORT = shell shards + toon smoke
-- (then rays + halo at the reveal), AMBIENT = sparkle trickle. Everything else is a small accent.
--   0 .. A   WIND-UP: an egg (opts.egg, else the game's egg mesh) rocks on its base, faster and wider; crack decals
--            appear in 3 stages (glowing the rarity colour) with a jolt + shell specks each; a 3-band glow charges
--            behind it in steps; ember streaks are sucked in. Rare+: a swirl spirals inward before the burst.
--            Legendary+: rune circle drawn in under the egg + light pillar. Every tier: camera push-in that frames
--            the egg (stronger and longer for higher rarity).
--   A        CRACK (hit-stop 0.05-0.1 s on everything but the flash): hero flash (0.09 s), inked needles (Uncommon+),
--            swirl crescents + ink swirl (Uncommon+ / Rare+), speed lines (Rare+), embers, shell shards, smoke ring,
--            ONE uneven ground wave (two on Epic+), sheen dome + colour flash (Epic+), pillar flare (Legendary+), shake.
--   A+0.04   REVEAL: the pet pops in (back overshoot + hop), ray fan + halo behind it (Uncommon+), a mixed handful of
--            stars / feathers / confetti, sparkle trickle round the pet, sparkle shower (Legendary+).
-- opts: rarity, egg (Model: cracked + hidden at the crack, the caller owns it), pet (Model to pop; caller owns it),
--       noEgg / noPet (skip the stand-ins), eggColor (shard tint), onCrack(), onReveal()
-- `where` = the ground point the egg stands on (ignored when opts.egg is given).
local RS = game:GetService("ReplicatedStorage")
local Models = require(RS:WaitForChild("Peckwood"):WaitForChild("Models"))
local VfxAssets = require(RS:WaitForChild("Peckwood"):WaitForChild("VfxAssets"))
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local R = require(Vfx:WaitForChild("Recipes"))
local seq, steps, pop, vary = Layers.seq, Layers.steps, Layers.pop, Layers.vary
local EASE = Layers.EASE

local T_ANT = { 0.65, 0.8, 1.0, 1.25, 1.7, 2.1 }
local T_HIT = { 0.05, 0.05, 0.06, 0.07, 0.08, 0.1 }
local SHAKE = { 0.3, 0.38, 0.5, 0.62, 0.85, 1.05 }
local RAYS = { 0, 1.0, 1.3, 1.7, 2.2, 2.6 }
local WAVE_D = { 10, 11, 12, 14, 16, 18 }
local CELEB = { { 2, 0, 0 }, { 3, 2, 0 }, { 3, 3, 4 }, { 4, 4, 6 }, { 5, 5, 8 }, { 6, 6, 12 } } -- stars, feathers, confetti
-- push-in framing: half the view height (studs) to aim for, and the FOV fraction clamp
local FRAME_H = { 26, 25, 24, 22, 18, 16 }
local PUSH_MIN = { 0.06, 0.07, 0.08, 0.1, 0.16, 0.2 }
local PUSH_MAX = { 0.45, 0.48, 0.5, 0.55, 0.62, 0.66 }
local CRACK_AT = { 0.3, 0.58, 0.84 } -- fractions of A

local SUCK = {
	tex = "speed_line", orient = "vel", life = 0.32, speed = 13, size = seq(0, 0.5, 0.3, 0.9, 1, 0.3),
	squash = seq(0, 1.8, 1, 1.2), color = "hi", light = 1, bright = 2, z = 1,
}
local SPECK = {
	tex = "shell_shards", orient = "face", life = { 0.35, 0.45 }, speed = { 6, 9 }, spread = 40,
	accel = Vector3.new(0, -40, 0), size = vary(seq(0, 0.55, 1, 0.45), 0.3), rotSpeed = { -300, 300 },
	fps = { 12, 16 }, startRandom = true, color = "fff4dc", z = 1.2,
}
local SHARDS = {
	tex = "shell_shards", orient = "face", life = { 0.75, 1.05 }, speed = { 16, 24 }, spread = 62,
	accel = Vector3.new(0, -60, 0), drag = 0.5, size = vary(pop(1.3, 0.08, 0.8, 0), 0.3), rotSpeed = { -300, 300 },
	fps = { 10, 16 }, startRandom = true, color = "fff4dc", z = 3.5,
}
local GATHER = {
	tex = "swirl_arc", orient = "face", life = 0.4, size = seq(0, 11, 0.6, 8, 1, 6), color = "mid",
	light = 1, bright = 1.6, z = 1.5, rotSpeed = { -300, -260 },
}
local RAYS_L = {
	tex = "rays_fan", orient = "face", life = 2, size = seq(0, 5, 0.12, 10, 0.3, 11.2, 1, 12),
	rotSpeed = { 10, 14 }, color = "warm", light = 1, bright = 1.4, z = -2,
}
local RAYS_L2 = {
	tex = "rays_fan", orient = "face", life = 2, size = seq(0, 4, 0.12, 8, 0.3, 9, 1, 9.5),
	rotSpeed = { -16, -12 }, color = "accent", light = 1, bright = 1.3, z = -1.9,
}
local HALO = {
	tex = "glow_step", orient = "face", life = 2, size = seq(0, 3, 0.12, 6.5, 1, 6),
	trans = steps({ 0.7, 0.35 }, { 0.86, 1 }), color = "base", light = 0.8, bright = 1.2, z = -2.2,
}
local SHOWER = {
	tex = "sparkle", orient = "face", life = { 1.3, 1.9 }, speed = { 0.5, 2 }, dir = Enum.NormalId.Bottom, spread = 25,
	accel = Vector3.new(0, -9, 0), drag = 0.4, size = vary(seq(0, 1.5, 1, 1.5), 0.3), color = "hi", z = 2,
}
local RUNE = {
	tex = "rune_circle", orient = "flat", life = 3, size = 1, rotSpeed = { 24, 24 }, rot = { 0, 360 },
	color = "mid", light = 0.3, z = 0.3,
}
local TRACE = { -- the swirl flipbook lying flat traces round the rune circle once as it appears
	tex = "swirl_arc", orient = "flat", life = 0.6, size = 1, color = "hi", light = 1, bright = 1.8, z = 0.4,
}
local POOF = {
	tex = "smoke_puff", orient = "face", life = { 0.45, 0.6 }, speed = { 3, 6 }, spread = 180, drag = 3,
	size = seq(0, 1.6, 1, 2.8), color = "white", z = 2,
}
local PILLAR = {
	tex = "beam_core", texMode = Enum.TextureMode.Wrap, texLen = 7, texSpeed = 1.6, color = "base",
	light = 1, bright = 1.6, trans = seq(0, 0.05, 0.65, 0.4, 1, 1), z = -0.5,
}
local PILLAR_CORE = { color = "white", light = 1, bright = 2.2, trans = seq(0, 0, 0.6, 0.3, 1, 1), z = -0.4 }

local function hideModel(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
	end
end

local function biggestPart(m: Instance): BasePart?
	local best, bv = nil, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bv then best, bv = d, v end
		end
	end
	return best
end

-- the two faces of `part` that look most at the camera (Decals project per bounding-box face)
local FACES = {
	{ Enum.NormalId.Right, Vector3.xAxis }, { Enum.NormalId.Left, -Vector3.xAxis },
	{ Enum.NormalId.Top, Vector3.yAxis }, { Enum.NormalId.Bottom, -Vector3.yAxis },
	{ Enum.NormalId.Back, Vector3.zAxis }, { Enum.NormalId.Front, -Vector3.zAxis },
}
local function camFaces(part: BasePart)
	local cam = workspace.CurrentCamera
	local dir = if cam then (cam.CFrame.Position - part.CFrame.Position).Unit else Vector3.new(0, 0.79, 0.62)
	local l = part.CFrame:VectorToObjectSpace(dir)
	local list = {}
	for _, f in FACES do table.insert(list, { f[1], l:Dot(f[2]) }) end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	local out = { list[1][1] }
	if list[2][2] > 0.25 then table.insert(out, list[2][1]) end
	return out
end

local function standInParent(): Instance
	return workspace:FindFirstChild("Eggs") or workspace -- the egg field carries the ink outline Highlight
end

return {
	name = "egg_hatch",
	cap = 8,
	needs = { "flash_star", "glow_step", "shell_shards", "sparkle" },
	run = function(fx, cf, opts)
		local T = math.clamp(fx.tier, 1, 6)
		local A = T_ANT[T]
		-- ---------------------------------------------------------------- the egg
		local egg, ownEgg = opts.egg, false
		local ground = cf.Position
		local eggH = 3.4 * (1 + 0.04 * (T - 1))
		if egg then
			local bcf, size = egg:GetBoundingBox()
			ground = bcf.Position - Vector3.new(0, size.Y / 2, 0)
			eggH = size.Y
		elseif not opts.noEgg then
			local ok, m = pcall(Models.kernel, false)
			if ok and m then
				egg = m
				egg.Name = "VfxHatchEgg"
				egg:ScaleTo(egg:GetScale() * eggH / (0.62 * Models.S))
				egg:PivotTo(CFrame.new(ground))
				egg.Parent = standInParent()
				ownEgg = true
				fx:cleanup(function() if egg and ownEgg then egg:Destroy() end end)
			end
		end
		local centre = ground + Vector3.new(0, eggH * 0.5, 0)
		-- ---------------------------------------------------------------- camera: push in to frame the egg
		local amount = fx:frame(centre, FRAME_H[T], PUSH_MIN[T], PUSH_MAX[T], math.max(0.3, A * 0.85),
			0.6 + 0.15 * T, 0.9 + 0.1 * T, 0.85)
		fx.view = fx:viewFor(fx.camDist * (1 - amount)) -- size for the framing we push to
		fx.scale *= fx.view * (1 + (T - 1) * 0.06)
		local sc = fx.scale
		-- ---------------------------------------------------------------- wobble + cracks
		local eggPart = egg and biggestPart(egg)
		local decals = {}
		local jolt = 0
		if egg then
			local base = egg:GetPivot()
			local s0 = egg:GetScale()
			local phase = 0
			fx:tick(function(t, dt)
				if t >= A or not egg then return true end
				local u = t / A
				jolt = math.max(0, jolt - dt * 6)
				phase += (9 + 24 * u * u + 18 * jolt) * dt
				local amp = math.rad(3 + 11 * u ^ 1.4) * (1 + 0.1 * (T - 1)) * (1 + 0.9 * jolt)
				local hop = 0
				if T >= 3 then
					for _, h0 in { 0.55, 0.8 } do
						local w = (u - h0) / 0.07
						if w > 0 and w < 1 then hop = math.max(hop, math.sin(w * math.pi) * 0.35 * sc) end
					end
				end
				egg:PivotTo(base * CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, math.sin(phase) * amp))
				return nil
			end)
			fx:at(A - 0.1, function() if egg then egg:ScaleTo(s0 * 1.08) end end) -- swell before it bursts
			if eggPart then
				fx:cleanup(function() for _, d in decals do d:Destroy() end end)
			end
		end
		for stage, frac in CRACK_AT do
			fx:at(A * frac, function()
				jolt = 1
				local id = VfxAssets.id("crack_" .. stage)
				if eggPart and id and eggPart.Parent then
					if #decals == 0 then
						for _, face in camFaces(eggPart) do
							local d = Instance.new("Decal")
							d.Face = face
							d.Color3 = fx:col("base")
							d.Parent = eggPart
							table.insert(decals, d)
						end
					end
					for _, d in decals do d.Texture = id end
				end
				fx:emit(SPECK, CFrame.new(centre + Vector3.new(0, eggH * 0.25, 0)), stage)
				fx:emit(R.SPARKLE, centre + Vector3.new((math.random() - 0.5) * eggH * 0.6, eggH * 0.2, 0.5), 1, { tag = "crackTw" })
				fx:shake(0.06 + 0.03 * stage, 0.12)
			end)
		end
		-- ---------------------------------------------------------------- charge: stepped glow, light, sparks in
		local c1, c2, c3 = CRACK_AT[1], CRACK_AT[2], CRACK_AT[3]
		fx:emit(R.GLOW, centre, 1, {
			life = A, tag = "charge",
			size = seq(0, 2.2, c1, 2.2, c1 + 0.004, 3, c2, 3, c2 + 0.004, 3.9, c3, 3.9, c3 + 0.004, 5, 1, 5.4),
			trans = seq(0, 0.5, c1, 0.5, c1 + 0.004, 0.4, c2, 0.4, c2 + 0.004, 0.28, c3, 0.28, c3 + 0.004, 0.12, 1, 0.08),
		})
		local light = fx:light(centre, "base", 8, 0)
		if light then
			fx:tick(function(t)
				if t >= A then return true end
				local u = t / A
				light.light.Brightness = 3 * u
				light.light.Range = (8 + 8 * u) * sc
				return nil
			end)
		end
		local nSuck = fx:n(3 + 2 * T, true)
		for k = 1, nSuck do
			fx:at(A * (0.12 + 0.8 * (k - 1) / math.max(1, nSuck - 1)), function()
				local d = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.1, math.random() - 0.5)
				if d.Magnitude < 1e-3 then d = Vector3.xAxis end
				d = d.Unit
				fx:emit(SUCK, Layers.upTo(centre + d * 4.2 * sc, -d), 1)
			end)
		end
		if T >= 3 then
			fx:at(A * 0.62, function() fx:emit(GATHER, centre, 1) end)
		end
		-- ---------------------------------------------------------------- Legendary / Mythic build-up
		local pillar, pillarCore
		if T >= 5 then
			local D = 14 + (T - 5) * 4
			local L = A - 0.2 + 1.6
			local c = (A - 0.2) / L
			fx:at(0.2, function()
				fx:emit(RUNE, ground + Vector3.new(0, 0.15, 0), 1, {
					life = L,
					size = seq(0, D * 1.16, 0.06, D * 0.98, 0.1, D, c + 0.25, D, 1, D * 1.22),
					trans = seq(0, 1, 0.03, 0.6, 0.06, 0.6, 0.064, 0.25, 0.09, 0.25, 0.094, 0, c + 0.25, 0,
						c + 0.252, 0.45, c + 0.33, 0.45, c + 0.332, 1, 1, 1),
					tag = "rune",
				})
				fx:emit(TRACE, ground + Vector3.new(0, 0.2, 0), 1, { size = D * 1.04, tag = "trace" })
			end)
			fx:at(A * 0.3, function()
				pillar = fx:beam(PILLAR, ground, ground + Vector3.new(0, 56 * sc, 0))
				pillarCore = fx:beam(PILLAR_CORE, ground, ground + Vector3.new(0, 56 * sc, 0))
				local t0 = A * 0.3
				fx:tick(function(t)
					local w, wc
					if t < A then
						local u = EASE.out2((t - t0) / (A - t0))
						w, wc = 2.6 * u * sc, 0.9 * u * sc
					elseif t < A + 0.08 then
						local u = (t - A) / 0.08
						w, wc = (2.6 + 5.4 * u) * sc, (0.9 + 2.1 * u) * sc
					else
						local u = math.clamp((t - A - 0.08) / 0.62, 0, 1)
						local k = 1 - EASE["in"](u)
						w, wc = 8 * k * sc, 3 * k * sc
						if u >= 1 then
							if pillar then pillar.beam.Enabled = false end
							if pillarCore then pillarCore.beam.Enabled = false end
							return true
						end
					end
					if pillar then pillar.set(nil, nil, w) end
					if pillarCore then pillarCore.set(nil, nil, wc) end
					return nil
				end)
			end)
		end
		-- ---------------------------------------------------------------- crack
		local foot = ground + Vector3.new(0, 0.2, 0)
		fx:at(A, function()
			if egg then
				if ownEgg then egg:Destroy(); egg = nil
				elseif not opts.onCrack then hideModel(egg) end
			end
			for _, d in decals do d:Destroy() end
			table.clear(decals)
			if opts.onCrack then task.spawn(opts.onCrack) end
			-- HERO
			R.flash(fx, centre, 0.85 + 0.07 * T)
			if T >= 2 then fx:emit(R.NEEDLES, centre, 1) end
			-- swirls (clip2 shape language): bright crescents spinning out + one dark ink accent
			if T >= 2 then fx:emit(R.SWIRL, centre, 1, { rotSpeed = { 380, 440 }, tag = "sw1" }) end
			if T >= 3 then
				fx:emit(R.SWIRL, centre, 1, { rotSpeed = { -380, -320 }, color = if T >= 6 then "accent" else "mid", scale = 1.25, tag = "sw2" })
				fx:emit(R.INK_SWIRL, centre, 1, { rotSpeed = { 280, 320 } })
				fx:emitSphere(R.SPEED, centre, fx:n(5 + T), 0.3)
			end
			if T >= 2 then fx:emitSphere(R.EMBER, centre, fx:n(3 + 2 * T), 0.7, { color = if T >= 6 then "accent" else "base" }) end
			-- SUPPORT: shell shards + toon smoke ring
			fx:emit(SHARDS, centre, fx:n(5 + T, true), { color = opts.eggColor or "fff4dc" })
			fx:emitRadial(R.SMOKE, ground + Vector3.new(0, 0.7, 0), fx:n(4 + T // 2, true), 0.25)
			-- ONE ground wave (two on Epic+), alpha <= 0.6
			fx:emit(R.WAVE, foot, 1, { size = R.waveSize(WAVE_D[T]), trans = R.waveTrans(0.6), tag = "wave1" })
			if T >= 4 then
				fx:at(A + 0.07, function()
					fx:emit(R.WAVE, foot + Vector3.new(0, 0.05, 0), 1, { size = R.waveSize(WAVE_D[T] * 1.3), trans = R.waveTrans(0.4), color = "mid", tag = "wave2" })
				end)
			end
			if light then
				local t0 = fx.t
				light.light.Brightness = 7
				fx:tick(function(t)
					local u = math.clamp((t - t0) / 0.6, 0, 1)
					light.light.Brightness = 7 * (1 - u)
					return u >= 1 or nil
				end)
			end
			if T >= 4 then
				local dome = fx:ball("mid", Enum.Material.ForceField)
				if dome then
					local t0 = fx.t
					fx:tick(function(t)
						local u = math.clamp((t - t0) / 0.34, 0, 1)
						local d = (1.5 + 9.5 * EASE.out(u)) * sc
						dome.Size = Vector3.new(d, d * (1 - 0.3 * u), d)
						dome.CFrame = CFrame.new(centre)
						dome.Transparency = if u < 0.45 then 0.2 elseif u < 0.75 then 0.55 else 1
						return u >= 1 or nil
					end)
				end
				fx:flash(if T >= 5 then "hi" else "mid", 0.16 + 0.07 * (T - 4), 0.45 + 0.05 * (T - 4))
			end
			fx:shake(SHAKE[T], 0.25 + 0.05 * T)
			fx:hitstop(T_HIT[T])
		end)
		-- ---------------------------------------------------------------- reveal
		local pet, ownPet = opts.pet, false
		fx:at(A + 0.04, function()
			if not pet and not opts.noPet then
				local ok, m = pcall(Models.bird)
				if ok and m then
					pet = m
					pet.Name = "VfxHatchChick"
					pet:ScaleTo(pet:GetScale() * 0.55 * (1 + 0.04 * (T - 1)))
					pet.Parent = standInParent()
					ownPet = true
					fx:cleanup(function() if pet and ownPet then pet:Destroy() end end)
				end
			end
			if pet then
				local s0 = pet:GetScale()
				-- caller pets keep their facing; the stand-in chick turns to the camera (bird beaks look down -Z)
				local rot = if ownPet then CFrame.Angles(0, math.pi - 0.45, 0) else (pet:GetPivot() - pet:GetPivot().Position)
				local base = CFrame.new(ground) * rot
				pet:ScaleTo(s0 * 0.05)
				pet:PivotTo(base)
				local t0 = fx.t
				fx:tick(function(t)
					if not pet then return true end
					local u = math.clamp((t - t0) / 0.4, 0, 1)
					pet:ScaleTo(s0 * math.max(0.05, EASE.back(u))) -- only during the 0.4 s pop
					pet:PivotTo(base + Vector3.new(0, math.sin(u * math.pi) * 1.4 * sc, 0))
					if u >= 1 then
						pet:ScaleTo(s0)
						pet:PivotTo(base)
						return true
					end
					return nil
				end)
			end
			if opts.onReveal then task.spawn(opts.onReveal) end
			local petC = centre + Vector3.new(0, 0.4 * sc, 0)
			local rl = RAYS[T]
			if rl > 0 then
				fx:emit(RAYS_L, petC, 1, { life = rl, tag = "rays" })
				fx:emit(HALO, petC, 1, { life = rl, tag = "halo" })
				if T >= 6 then fx:emit(RAYS_L2, petC, 1, { life = rl, tag = "rays2" }) end
			end
			local cb = CELEB[T]
			R.celebrate(fx, centre, cb[1], cb[2], cb[3], if T >= 6 then fx.pal.rainbow else nil)
			local nTw = 2 + math.ceil(T / 2)
			for k = 1, nTw do
				fx:at(fx.t + 0.1 + (k - 1) * (1.1 / nTw), function()
					local a = math.random() * math.pi * 2
					local r = (1.4 + math.random() * 1.6) * sc
					fx:emit(R.SPARKLE, petC + Vector3.new(math.cos(a) * r, (math.random() - 0.3) * 2 * sc, math.sin(a) * r * 0.5), 1)
				end)
			end
			if T >= 5 then
				fx:at(fx.t + 0.2, function()
					for _ = 1, fx:n(8 + (T - 5) * 6) do
						local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * 7 * sc
						fx:emit(SHOWER, ground + Vector3.new(math.cos(a) * r, 14 * sc + math.random() * 4, math.sin(a) * r), 1)
					end
				end)
			end
			if ownPet then
				fx:at(fx.t + math.max(1.4, rl) + 0.3, function()
					if pet then
						fx:emit(POOF, ground + Vector3.new(0, 1, 0), 5)
						pet:Destroy()
						pet = nil
					end
				end)
			end
		end)
	end,
}
