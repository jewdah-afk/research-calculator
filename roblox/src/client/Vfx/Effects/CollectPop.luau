--!nonstrict
-- collect_pop: the most frequent effect in the game, so it is the crispest one. 0.35 s, readable at the default zoom
-- (everything scales with the camera distance: clamp(dist / 290, 1, 2.4)).
--   t 0     HERO   white ring snap (broken, tapered) bursts out with an ease-out and steps away (0.24 s)
--   t 0     HERO   tiny colour star flash (egg gold / golden) + white-hot core (0.12 s)
--   t 0     SUPPORT 3-5 inked sparkles flung out, dead stop by drag, drifting up (0.26-0.34 s)
--   t 0.04  opts.onLabel(worldPos): where the UI layer puts its "+N"
--   golden: x1.25, gold, 5 sparkles + 2 star bits
-- opts: golden, groundY, onLabel(pos), palette / rarity / color
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local Palette = require(Vfx:WaitForChild("Palette"))
local seq, pop, vary = Layers.seq, Layers.pop, Layers.vary

local RING = {
	tex = "ring_snap", orient = "face", life = 0.24, size = seq(0, 0.8, 0.12, 2.6, 0.35, 3.4, 0.7, 3.9, 1, 4.2),
	trans = seq(0, 0, 0.55, 0, 0.553, 0.35, 0.78, 0.35, 0.783, 1, 1, 1), color = "white", bright = 1.3, z = 2.5,
}
local FLASH = {
	tex = "flash_star", orient = "face", life = 0.13, size = pop(2.8, 0.28, 0.5, 0.4, 0.5), color = "base",
	light = 0.6, bright = 1.7, z = 2.8,
}
local CORE = {
	tex = "flash_star", orient = "face", life = 0.09, size = pop(1.6, 0.3, 0.5, 0.2, 0.3), color = "white",
	light = 1, bright = 2.6, z = 3,
}
local SPARK = {
	tex = "sparkle", orient = "face", life = { 0.26, 0.34 }, speed = { 9, 13 }, drag = 9, spread = 180,
	accel = Vector3.new(0, 6, 0), size = vary(pop(1.2, 0.12, 0.65, 0.5), 0.2), color = "hi", z = 2.6,
}
local BIT = {
	tex = "star", orient = "face", life = { 0.32, 0.38 }, speed = { 10, 14 }, spread = 30, accel = Vector3.new(0, -40, 0),
	drag = 0.8, size = pop(0.9, 0.15, 0.7, 0), rotSpeed = { -220, 220 }, color = "mid", z = 2.7,
}

return {
	name = "collect_pop",
	cap = 16,
	replaceOldest = true,
	needs = { "ring_snap", "flash_star", "sparkle" },
	palette = "egg",
	run = function(fx, cf, opts)
		local golden = opts.golden == true
		if not (opts.palette or opts.rarity or opts.color) then fx.pal = Palette.get(if golden then "golden" else "egg") end
		fx.scale *= fx.view * (if golden then 1.25 else 1)
		local p = cf.Position
		local rot = math.random(0, 89)
		fx:emit(RING, p, 1)
		fx:emit(FLASH, p, 1, { rot = rot })
		fx:emit(CORE, p, 1, { rot = rot })
		fx:emit(SPARK, p, fx:n(if golden then 5 else math.random(3, 4), true))
		if golden then fx:emit(BIT, p, 2) end
		if opts.onLabel then
			fx:at(0.04, function() opts.onLabel(p + Vector3.new(0, 2.2 * fx.scale, 0)) end)
		end
	end,
}
