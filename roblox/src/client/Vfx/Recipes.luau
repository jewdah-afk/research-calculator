--!nonstrict
-- Vfx/Recipes: layer recipes shared by the effects, so every effect speaks the same visual language.
--   Hierarchy rule (QA round 1): ONE hero element (the flash / burst), two support layers, an ambient trickle.
--   Ink only on normal-blend pieces (stars, shards, feathers, confetti, smoke, ink swirls); additive / glow pieces
--   (flash, swirls, rays, rings, speed lines, embers) carry no ink and use Brightness > 1 on their hot cores.
--   Sizes are studs at view 1 (camera ~290 studs away); the emitter scales them (and speeds) by fx.scale.
local Layers = require(script.Parent:WaitForChild("Layers"))
local seq, steps, pop, vary = Layers.seq, Layers.steps, Layers.pop, Layers.vary

local R = {}

-- ---------------------------------------------------------------- hero flash: tinted rim behind, white-hot core in front
R.FLASH_RIM = {
	tex = "flash_star", orient = "face", life = 0.09, size = pop(9.5, 0.3, 0.55, 6.5, 3.5), noHold = true,
	color = "base", light = 1, bright = 1.8, z = 5, rotSpeed = 0,
}
R.FLASH_CORE = {
	tex = "flash_star", orient = "face", life = 0.09, size = pop(6.2, 0.3, 0.55, 4, 2.2), noHold = true,
	color = "white", light = 1, bright = 3, z = 5.2, rotSpeed = 0,
}
-- both layers share one rotation so the white core sits inside the coloured rim; `k` scales the pair
function R.flash(fx, pos: Vector3, k: number?, life: number?)
	local rot = math.random(-12, 12)
	local ov = { rot = rot, scale = k or 1, life = life, tag = "flashRim" .. tostring(k) .. tostring(life) }
	fx:emit(R.FLASH_RIM, pos, 1, ov)
	fx:emit(R.FLASH_CORE, pos, 1, { rot = rot, scale = k or 1, life = life, tag = "flashCore" .. tostring(k) .. tostring(life) })
end

-- inked impact needles (QA: keep this look on the crack frame)
R.NEEDLES = {
	tex = "burst_lines", orient = "face", life = 0.2, size = seq(0, 10, 0.4, 12.5, 1, 13.5),
	trans = steps({ 0.62, 1 }), color = "hi", z = 4.6,
}

-- ---------------------------------------------------------------- swirls (clip2): bright crescents + an ink accent
R.SWIRL = {
	tex = "swirl_arc", orient = "face", life = 0.42, size = seq(0, 6.5, 0.35, 9, 1, 10.5),
	color = "base", light = 1, bright = 1.9, z = 4.2, rot = { 0, 360 },
}
R.INK_SWIRL = {
	tex = "ink_swirl", orient = "face", life = 0.5, size = seq(0, 7, 0.4, 9.5, 1, 10.5), color = "white", z = 4,
	rot = { 0, 360 },
}

-- ---------------------------------------------------------------- streaks: speed lines + embers (VelocityParallel)
R.SPEED = {
	tex = "speed_line", orient = "vel", life = { 0.18, 0.26 }, speed = { 45, 70 }, drag = 7, size = seq(0, 2.2, 0.5, 2, 1, 0.6),
	squash = seq(0, 2.4, 1, 1.2), color = "white", light = 1, bright = 2, z = 4.4,
}
R.EMBER = {
	tex = "speed_line", orient = "vel", life = { 0.5, 0.8 }, speed = { 18, 30 }, drag = 2.2,
	accel = Vector3.new(0, -14, 0), size = vary(seq(0, 0.7, 0.2, 0.6, 1, 0), 0.3), squash = seq(0, 1.6, 1, 0.8),
	color = "base", light = 1, bright = 2.2, z = 4.3,
}

-- ---------------------------------------------------------------- ambient + celebration (inked, normal blend)
R.SPARKLE = {
	tex = "sparkle", orient = "face", life = { 0.45, 0.6 }, speed = 0, size = vary(seq(0, 1.5, 1, 1.5), 0.25),
	color = "hi", z = 3,
}
R.STAR = {
	tex = "star", orient = "face", life = { 0.8, 1.1 }, speed = { 13, 21 }, spread = 50, accel = Vector3.new(0, -34, 0),
	drag = 1.1, size = vary(pop(1.25, 0.12, 0.7, 0), 0.35), rotSpeed = { -240, 240 }, color = "mid", z = 3.2,
}
R.FEATHER = {
	tex = "feather", orient = "face", life = { 1.6, 2.3 }, speed = { 9, 15 }, spread = 55, accel = Vector3.new(0, -7, 0),
	drag = 2.2, size = vary(pop(1.4, 0.15, 0.8, 0), 0.35), rotSpeed = { -60, 60 }, fps = { 8, 12 }, startRandom = true,
	color = "hi", z = 3.1,
}
R.CONFETTI = {
	tex = "confetti", orient = "face", life = { 1.3, 2 }, speed = { 15, 24 }, spread = 42, accel = Vector3.new(0, -24, 0),
	drag = 1.6, size = vary(pop(1.1, 0.1, 0.8, 0), 0.45), rotSpeed = { -80, 80 }, fps = { 12, 20 }, startRandom = true,
	z = 3,
}

-- fewer, mixed, varied: stars + feathers + a little confetti in the palette (rainbow when given)
function R.celebrate(fx, at: Vector3, nStars: number, nFeathers: number, nConfetti: number, colors: { any }?)
	if nStars > 0 then fx:emit(R.STAR, at, fx:n(nStars, true)) end
	if nFeathers > 0 then fx:emit(R.FEATHER, at, fx:n(nFeathers)) end
	if nConfetti > 0 then
		local cols = colors or { "mid", "base", "white" }
		local per = math.max(1, math.floor(fx:n(nConfetti) / #cols + 0.5))
		for i, c in cols do fx:emit(R.CONFETTI, at, per, { color = c, tag = "conf" .. i }) end
	end
end

-- ---------------------------------------------------------------- ground: one uneven wave, alpha <= 0.6, fast
-- size is set per call (ov.size = R.wave(radius)); it expands in 0.3 s with an ease-out while it thins out (the
-- band is drawn uneven / broken, and the stepped fade drops it before the end)
R.WAVE = {
	tex = "ring_wave", orient = "flat", life = 0.32, size = 1, trans = steps({ 0.5, 0.62 }, { 0.78, 1 }),
	color = "hi", light = 0.45, bright = 1.2, z = 0.4,
}
function R.waveSize(diameter: number): NumberSequence
	return Layers.curve(diameter * 0.18, diameter, "out", 10)
end
function R.waveTrans(alpha: number?): NumberSequence
	local a = 1 - (alpha or 0.6)
	return seq(0, a, 0.5, a, 0.504, math.min(1, a + 0.22), 0.78, math.min(1, a + 0.22), 0.784, 1, 1, 1)
end

R.GLOW = { -- 3-band cel glow (billboard)
	tex = "glow_step", orient = "face", life = 1, size = 4, color = "base", light = 0.75, bright = 1.2, z = -0.6,
}
R.GLOW_FLAT = { tex = "glow_step", orient = "flat", life = 0.7, size = 6, color = "base", light = 0.8, bright = 1.2, z = 0.15 }

-- rendered toon flipbooks (lever B) with the PIL puff as the fallback until they are uploaded
R.SMOKE = {
	tex = { "toon_smoke", "smoke_puff" }, orient = "face", life = { 0.6, 0.8 }, speed = { 9, 13 }, drag = 4.5,
	accel = Vector3.new(0, 3, 0), size = vary(seq(0, 2.2, 0.3, 3.4, 1, 4), 0.2), rotSpeed = { -30, 30 },
	color = "fff8ee", z = 2,
}
R.DUST = {
	tex = { "dust_puff", "smoke_puff" }, orient = "face", life = { 0.6, 0.85 }, speed = { 6, 10 }, drag = 3,
	accel = Vector3.new(0, 2, 0), size = vary(seq(0, 2.6, 0.3, 4, 1, 4.8), 0.25), rotSpeed = { -12, 12 },
	color = "f1e6cf", z = 1,
}
-- the crack cloud: white-hot for its first two frames (2/16 of life), then the rarity pastel
R.BURST = {
	tex = "toon_burst", orient = "face", life = 0.72, speed = 0, size = vary(seq(0, 5, 0.25, 7.5, 1, 8.5), 0.08),
	rot = { -20, 20 }, rotSpeed = { -25, 25 },
	color = function(colorOf) return Layers.colorSteps(colorOf, { "white", 0.125 }, "hi") end, z = 3,
}

return R
