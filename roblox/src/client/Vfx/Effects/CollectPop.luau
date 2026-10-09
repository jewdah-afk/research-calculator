--!nonstrict
-- collect_pop: small, snappy, satisfying pickup (eggs / coins). ~0.5 s.
--   t 0     glow pop (cream, squash-in/out 0.17 s) + white hot core + thin pop ring + 6 sparkles flung out (drag stop)
--   t 0.02  2 little star bits hop up and fall
--   t 0.04  opts.onLabel(worldPos) so the UI layer can spawn its "+N" exactly there (3D part only here)
--   golden: gold palette, 1.25x, more sparkles + a flat ground shockwave
-- opts: golden, groundY (ground height under the pickup; default 2 studs below), onLabel(pos), palette/rarity/color
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local Palette = require(Vfx:WaitForChild("Palette"))
local seq, curve, steps = Layers.seq, Layers.curve, Layers.steps

local POP = {
	tex = "glow_disc", orient = "face", life = 0.17, size = seq(0, 0.6, 0.3, 4.4, 1, 0),
	color = "hi", light = 0.75, bright = 1.4, z = 1.2,
}
local CORE = {
	tex = "glow_disc", orient = "face", life = 0.11, size = seq(0, 0.4, 0.35, 2.2, 1, 0),
	color = "white", light = 1, bright = 2, z = 1.4,
}
local RING = {
	tex = "ring_thin", orient = "face", life = 0.3, size = curve(1.2, 6.2, "out", 8),
	trans = steps({ 0.55, 0.45 }, { 0.78, 1 }), color = "mid", light = 0.25, z = 1,
}
local SPARK = {
	tex = "sparkle", orient = "face", life = { 0.34, 0.5 }, speed = { 10, 16 }, drag = 7, spread = 180,
	accel = Vector3.new(0, 5, 0), size = 1.5, rotSpeed = { -90, 90 }, color = "hi", light = 0.35, z = 1.5,
}
local BIT = {
	tex = "star", orient = "face", life = { 0.5, 0.65 }, speed = { 11, 16 }, spread = 32, accel = Vector3.new(0, -40, 0),
	drag = 0.8, size = seq(0, 1.0, 0.7, 1.0, 1, 0), rotSpeed = { -220, 220 }, color = "mid", z = 1.3,
}
local SHOCK = {
	tex = "ring_shock", orient = "flat", life = 0.38, size = curve(1.5, 8.5, "out", 8),
	trans = steps({ 0.5, 0.4 }, { 0.78, 1 }), color = "mid", light = 0.15, z = 0.3,
}

return {
	name = "collect_pop",
	cap = 10,
	replaceOldest = true,
	needs = { "sparkle", "glow_disc" },
	palette = "egg",
	run = function(fx, cf, opts)
		local golden = opts.golden == true
		if not (opts.palette or opts.rarity or opts.color) then fx.pal = Palette.get(if golden then "golden" else "egg") end
		if golden then fx.scale *= 1.25 end
		local p = cf.Position
		local ground = opts.groundY or (p.Y - 2)
		fx:emit(POP, p, 1)
		fx:emit(CORE, p, 1)
		fx:emit(RING, p, 1)
		fx:emit(SPARK, p, fx:n(if golden then 10 else 6, true))
		fx:at(0.02, function() fx:emit(BIT, p, fx:n(if golden then 4 else 2)) end)
		if golden then fx:emit(SHOCK, Vector3.new(p.X, ground + 0.15, p.Z), 1) end
		if opts.onLabel then
			fx:at(0.04, function() opts.onLabel(p + Vector3.new(0, 2.2 * fx.scale, 0)) end)
		end
	end,
}
