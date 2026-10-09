--!nonstrict
-- egg_hatch: the reveal, scaled by rarity (Common 1 .. Mythic 6). A = anticipation length (0.6 s .. 2.15 s).
--   0 .. A   anticipation: the egg rocks on its base, faster and wider (and hops on Rare+), a stepped glow charges
--            behind it, sparks are sucked in, a light ramps up. Legendary+: a rune circle draws in under the egg
--            (beam ring trace + spinning rune texture), a light pillar grows, the camera pushes in slowly.
--   A        CRACK (hit-stop impact frame, 0.04 .. 0.14 s frozen): star-burst flipbook, white flash, impact lines (Rare+),
--            shell shards, a ring of toon smoke, ground shockwave (+ echo rings Rare+ / Mythic), shake, colour flash
--            (Epic+), sheen dome (Epic+), pillar flare (Legendary+).
--   A+0.03   REVEAL: the pet pops in (back overshoot + hop), light rays + halo behind it (Uncommon+), confetti
--            (Uncommon+), star bits, twinkles round the pet, sparkle shower (Legendary+). Ends ~A + rays + 0.6.
-- opts: rarity, egg (Model: hidden at the crack, the caller owns it), pet (Model popped in; caller owns it),
--       eggColor (Color3 for shell shards), onCrack(), onReveal(), preview (build a stand-in egg + chick, cleaned up)
-- `where` = the ground point the egg stands on (ignored when opts.egg is given).
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Models = require(Shared:WaitForChild("Models"))
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local seq, curve, steps = Layers.seq, Layers.curve, Layers.steps
local EASE = Layers.EASE

local T_ANT = { 0.6, 0.8, 1.0, 1.25, 1.75, 2.15 }
local T_HIT = { 0.04, 0.05, 0.065, 0.08, 0.11, 0.14 }
local SHAKE = { 0.35, 0.45, 0.6, 0.75, 1.0, 1.25 }
local RAYS = { 0, 1.2, 1.6, 2.0, 2.6, 3.1 }
local CONF = { 0, 12, 20, 30, 42, 60 }
local STARS = { 4, 6, 8, 10, 12, 16 }
local SHOCK_R = { 9, 11, 13, 16, 19, 23 }

local function whiteThen(role, at)
	return function(colorOf) return Layers.colorSteps(colorOf, { "white", at }, role) end
end

-- ---------------------------------------------------------------- layer recipes (studs at scale 1)
local GLOW_BUILD = {
	tex = "glow_disc", orient = "face", life = 1,
	size = seq(0, 1.6, 0.32, 1.6, 0.33, 2.6, 0.62, 2.6, 0.63, 3.8, 0.88, 3.8, 0.89, 5.0, 1, 5.4), -- stepped charge
	trans = seq(0, 0.6, 0.6, 0.4, 1, 0.2), color = "base", light = 1, bright = 1.3, z = -0.6,
}
local SUCK = {
	tex = "sparkle", orient = "face", life = 0.4, speed = 8.5, size = 1.2, color = "hi", light = 0.6, z = 0.4, noScale = true,
}
local IMPACT = {
	tex = "impact_star", orient = "face", life = 0.36, size = seq(0, 3, 0.18, 8, 1, 9),
	color = whiteThen("mid", 0.3), z = 2,
}
local FLASH = {
	tex = "glow_disc", orient = "face", life = 0.15, size = seq(0, 5, 0.35, 11, 1, 0),
	color = "white", light = 1, bright = 2.2, z = 2.5,
}
local LINES = {
	tex = "burst_lines", orient = "face", life = 0.22, size = seq(0, 10, 1, 13.5),
	trans = steps({ 0.62, 1 }), color = "hi", z = 1.8,
}
local SHARDS = {
	tex = "shell_shards", orient = "face", life = { 0.75, 1.05 }, speed = { 16, 24 }, spread = 62,
	accel = Vector3.new(0, -60, 0), drag = 0.5, size = seq(0, 1.3, 0.8, 1.3, 1, 0), rotSpeed = { -300, 300 },
	fps = { 10, 16 }, startRandom = true, color = "fff4dc", z = 1,
}
local SMOKE = {
	tex = "smoke_puff", orient = "face", life = { 0.6, 0.8 }, speed = { 10, 14 }, drag = 4.5,
	accel = Vector3.new(0, 3, 0), size = seq(0, 2.4, 1, 4.2), rotSpeed = { -30, 30 }, color = "fff8ee", z = 0.6,
}
local SHOCK = {
	tex = "ring_shock", orient = "flat", life = 0.44, size = 1,
	trans = steps({ 0.55, 0.4 }, { 0.8, 1 }), color = "mid", light = 0.15, z = 0.25,
}
local SHOCK2 = {
	tex = "ring_thin", orient = "flat", life = 0.55, size = 1,
	trans = steps({ 0.5, 0.5 }, { 0.78, 1 }), color = "hi", light = 0.45, z = 0.3,
}
local SHOCK3 = {
	tex = "ring_shock", orient = "flat", life = 0.6, size = 1,
	trans = steps({ 0.5, 0.45 }, { 0.8, 1 }), color = "accent", light = 0.3, z = 0.35,
}
local RAY_T = seq(0, 1, 0.1, 0.3, 0.72, 0.3, 0.725, 0.6, 0.88, 0.6, 0.885, 1, 1, 1)
local RAYS_L = {
	tex = "light_rays", orient = "face", life = 2, size = seq(0, 4, 0.15, 10.5, 1, 12), trans = RAY_T,
	rotSpeed = { 16, 20 }, color = "mid", light = 1, bright = 1.2, z = -1,
}
local RAYS_L2 = {
	tex = "light_rays", orient = "face", life = 2, size = seq(0, 3, 0.15, 8.5, 1, 9.5), trans = RAY_T,
	rotSpeed = { -22, -18 }, color = "accent", light = 1, bright = 1.1, z = -0.95,
}
local HALO = {
	tex = "glow_disc", orient = "face", life = 2, size = seq(0, 3, 0.12, 7, 1, 7.5), trans = RAY_T,
	color = "base", light = 1, bright = 1.2, z = -1.2,
}
local CONFETTI = {
	tex = "confetti", orient = "face", life = { 1.4, 2.2 }, speed = { 17, 27 }, spread = 40,
	accel = Vector3.new(0, -26, 0), drag = 1.5, size = 1.0, rotSpeed = { -80, 80 }, fps = { 14, 22 },
	startRandom = true, z = 0.8,
}
local STAR = {
	tex = "star", orient = "face", life = { 0.75, 1.05 }, speed = { 13, 21 }, spread = 62,
	accel = Vector3.new(0, -34, 0), drag = 1.1, size = seq(0, 1.2, 0.75, 1.2, 1, 0), rotSpeed = { -240, 240 },
	color = "mid", z = 1,
}
local TWINKLE = { tex = "sparkle", orient = "face", life = 0.55, speed = 0, size = 1.6, color = "hi", light = 0.5, z = 1.6 }
local SHOWER = {
	tex = "sparkle", orient = "face", life = { 1.3, 1.9 }, speed = { 0.5, 2 }, dir = Enum.NormalId.Bottom, spread = 25,
	accel = Vector3.new(0, -9, 0), drag = 0.4, size = 1.5, color = "hi", light = 0.5, z = 1.2,
}
local RUNE = {
	tex = "rune_circle", orient = "flat", life = 3, size = 1, rotSpeed = { 24, 24 }, rot = { 0, 360 },
	color = "mid", light = 0.3, z = 0.15,
}
local POOF = {
	tex = "smoke_puff", orient = "face", life = { 0.45, 0.6 }, speed = { 3, 6 }, spread = 180, drag = 3,
	size = seq(0, 1.6, 1, 2.8), color = "white", z = 1,
}
local RING_INK = { width = 0.95, color = "ink", light = 0, z = -0.05, segments = 40 }
local RING_LINE = { width = 0.45, color = "hi", light = 0.6, bright = 1.3, z = 0.05, segments = 40 }
local PILLAR = {
	tex = "beam_streak", texMode = Enum.TextureMode.Wrap, texLen = 7, texSpeed = 1.6, color = "base",
	light = 1, bright = 1.4, trans = seq(0, 0.1, 0.65, 0.45, 1, 1), z = -0.5,
}
local PILLAR_CORE = { color = "white", light = 1, bright = 2, trans = seq(0, 0, 0.6, 0.3, 1, 1), z = -0.4 }

local function hideModel(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
	end
end

local function standInParent(): Instance
	return workspace:FindFirstChild("Eggs") or workspace -- the egg field carries the ink outline Highlight
end

return {
	name = "egg_hatch",
	cap = 3,
	needs = { "glow_disc", "impact_star", "ring_shock", "sparkle" },
	run = function(fx, cf, opts)
		local T = math.clamp(fx.tier, 1, 6)
		local A = T_ANT[T]
		fx.scale *= 1 + (T - 1) * 0.1
		local sc = fx.scale
		-- ---------------------------------------------------------------- the egg
		local egg, ownEgg = opts.egg, false
		local ground = cf.Position
		local eggH = 3.4 * sc
		if egg then
			local bcf, size = egg:GetBoundingBox()
			ground = bcf.Position - Vector3.new(0, size.Y / 2, 0)
			eggH = size.Y
		elseif opts.preview then
			egg = Models.kernel(false)
			egg.Name = "VfxHatchEgg"
			egg:ScaleTo(egg:GetScale() * eggH / (0.62 * Models.S))
			egg:PivotTo(CFrame.new(ground))
			egg.Parent = standInParent()
			ownEgg = true
			fx:cleanup(function() if egg then egg:Destroy() end end)
		end
		local centre = ground + Vector3.new(0, eggH * 0.5, 0)
		local eggBase = egg and egg:GetPivot()
		local eggScale = egg and egg:GetScale()
		-- wobble: frequency and amplitude ramp together (calm -> frantic), hops on Rare+
		if egg then
			local phase = 0
			fx:tick(function(t, dt)
				if t >= A then return true end
				local u = t / A
				phase += (9 + 24 * u * u) * dt
				local amp = math.rad(3 + 11 * u ^ 1.4) * (1 + 0.1 * (T - 1))
				local hop = 0
				if T >= 3 then
					for _, h0 in { 0.55, 0.8 } do
						local w = (u - h0) / 0.07
						if w > 0 and w < 1 then hop = math.max(hop, math.sin(w * math.pi) * 0.35 * sc) end
					end
				end
				egg:PivotTo(eggBase * CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, math.sin(phase) * amp))
				return nil
			end)
			fx:at(A - 0.1, function() egg:ScaleTo(eggScale * 1.1) end) -- swell before it bursts
		end
		-- charging glow + light + sparks sucked in
		fx:emit(GLOW_BUILD, centre, 1, { life = A, tag = "glow" })
		local light = fx:light(centre, "base", 8, 0)
		if light then
			fx:tick(function(t)
				if t >= A then return true end
				local u = t / A
				light.light.Brightness = 3 * u
				light.light.Range = 8 + 8 * u
				return nil
			end)
		end
		local nSuck = fx:n(6 + 3 * T, true)
		for k = 1, nSuck do
			local at = A * (0.12 + 0.78 * (k - 1) / math.max(1, nSuck - 1))
			fx:at(at, function()
				local d = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.2, math.random() - 0.5)
				if d.Magnitude < 1e-3 then d = Vector3.xAxis end
				d = d.Unit
				fx:emit(SUCK, Layers.upTo(centre + d * 3.4, -d), 1)
			end)
		end
		-- ---------------------------------------------------------------- Legendary / Mythic build-up
		local rune, pillar, pillarCore
		local D = 14 + (T - 5) * 4 -- rune diameter at scale 1 (particle sizes are scaled by the emitter)
		local Ds = D * sc
		if T >= 5 then
			rune = fx:ring({ RING_INK, RING_LINE }, ground + Vector3.new(0, 0.2, 0), Ds * 0.5)
			if rune then
				rune.trace(0)
				local t0, t1 = 0.05, 0.6
				local lastSpark = -1
				fx:tick(function(t)
					local u = math.clamp((t - t0) / (t1 - t0), 0, 1)
					rune.trace(EASE.inout(u))
					if u > 0 and u < 1 and t - lastSpark > 0.05 then
						lastSpark = t
						fx:emit(TWINKLE, rune.point(EASE.inout(u)) + Vector3.new(0, 0.3, 0), 1, { tag = "runeSpark" })
					end
					return u >= 1 or nil
				end)
			end
			local L = A - 0.2 + 1.6
			local c = (A - 0.2) / L
			fx:at(0.2, function()
				fx:emit(RUNE, ground + Vector3.new(0, 0.12, 0), 1, {
					life = L,
					size = seq(0, 0, 0.08, D * 1.06, 0.12, D, c + 0.25, D, 1, D * 1.22),
					trans = seq(0, 1, 0.06, 0, c + 0.25, 0, c + 0.252, 0.45, c + 0.33, 0.45, c + 0.332, 1, 1, 1),
					tag = "rune",
				})
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
			fx:at(0.15, function() fx:push(centre, if T >= 6 then 0.2 else 0.15, A - 0.15, 0.7, 1.3, 0.6) end)
		end
		-- ---------------------------------------------------------------- crack
		local R = SHOCK_R[T] -- at scale 1 (the emitter scales particle sizes)
		local foot = ground + Vector3.new(0, 0.15, 0)
		fx:at(A, function()
			if egg then
				if ownEgg then egg:Destroy(); egg = nil
				elseif not opts.onCrack then hideModel(egg) end
			end
			if opts.onCrack then task.spawn(opts.onCrack) end
			fx:emit(IMPACT, centre, 1)
			fx:emit(FLASH, centre, 1)
			if T >= 3 then fx:emit(LINES, centre, 1) end
			fx:emit(SHARDS, centre, fx:n(6 + 2 * T, true), { color = opts.eggColor or "fff4dc" })
			fx:emitRadial(SMOKE, ground + Vector3.new(0, 0.7, 0), fx:n(6 + T, true), 0.25)
			fx:emit(SHOCK, foot, 1, { size = curve(2, R, "out", 10), tag = "shock" })
			if T >= 3 then
				fx:at(A + 0.07, function() fx:emit(SHOCK2, foot + Vector3.new(0, 0.05, 0), 1, { size = curve(3, R * 1.35, "out", 10), tag = "shock2" }) end)
			end
			if T >= 6 then
				fx:at(A + 0.16, function() fx:emit(SHOCK3, foot + Vector3.new(0, 0.1, 0), 1, { size = curve(3, R * 1.7, "out", 10), tag = "shock3" }) end)
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
			if rune then
				local t0, r0 = fx.t, rune.radius
				fx:tick(function(t)
					local u = math.clamp((t - t0) / 0.35, 0, 1)
					rune.set(nil, r0 * (1 + 0.6 * EASE.out(u)), 1 + 0.8 * u)
					rune.alpha(if u < 0.5 then 0 elseif u < 0.8 then 0.5 else 1)
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
						dome.Size = Vector3.new(d, d, d)
						dome.CFrame = CFrame.new(centre)
						dome.Transparency = if u < 0.5 then 0.15 elseif u < 0.8 then 0.55 else 1
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
		fx:at(A + 0.03, function()
			if not pet and opts.preview then
				local ok, m = pcall(Models.bird)
				if ok and m then
					pet = m
					pet.Name = "VfxHatchChick"
					pet:ScaleTo(pet:GetScale() * 0.55 * sc)
					pet.Parent = standInParent()
					ownPet = true
					fx:cleanup(function() if pet and ownPet then pet:Destroy() end end)
				end
			end
			if pet then
				local s0 = pet:GetScale()
				-- caller pets keep their facing; the preview chick turns to the camera (bird beaks look down -Z)
				local rot = if ownPet then CFrame.Angles(0, math.pi - 0.45, 0) else (pet:GetPivot() - pet:GetPivot().Position)
				local base = CFrame.new(ground) * rot
				pet:ScaleTo(s0 * 0.05)
				pet:PivotTo(base)
				local t0 = fx.t
				fx:tick(function(t)
					local u = math.clamp((t - t0) / 0.4, 0, 1)
					local s = math.max(0.05, EASE.back(u))
					pet:ScaleTo(s0 * s) -- only during the 0.4 s pop
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
			local nConf = fx:n(CONF[T])
			if nConf > 0 then
				local cols = if T >= 6 then fx.pal.rainbow or { "mid", "base", "hi", "accent" }
					elseif T == 5 then { "mid", "base", "white" }
					else { "mid", "base", "hi" }
				local per = math.max(1, math.floor(nConf / #cols + 0.5))
				for i, c in cols do fx:emit(CONFETTI, centre, per, { color = c, tag = "conf" .. i }) end
			end
			fx:emit(STAR, centre, fx:n(STARS[T], true))
			local nTw = 3 + T
			for k = 1, nTw do
				fx:at(fx.t + 0.08 + (k - 1) * (1.1 / nTw), function()
					local a = math.random() * math.pi * 2
					local r = (1.4 + math.random() * 1.6) * sc
					fx:emit(TWINKLE, petC + Vector3.new(math.cos(a) * r, (math.random() - 0.3) * 2 * sc, math.sin(a) * r * 0.5), 1)
				end)
			end
			if T >= 5 then
				fx:at(fx.t + 0.2, function()
					local n = fx:n(14 + (T - 5) * 10)
					for _ = 1, n do
						local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * 7 * sc
						fx:emit(SHOWER, ground + Vector3.new(math.cos(a) * r, 14 * sc + math.random() * 4, math.sin(a) * r), 1)
					end
				end)
			end
			-- preview chick leaves with a poof once the show is over
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
