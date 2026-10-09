--!nonstrict
-- level_up: ~1.7 s round the player, follows the hen. HERO = the light column, SUPPORT = spiral cone + ribbons + the
-- "ding", AMBIENT = rising sparkles. Gentle camera push-in; sizes follow the camera distance.
--   t 0       one ground wave (shock wall mesh, or the flat particle wave) + a small 3-band STEPPED glow under the feet
--             (normal blend, not an airbrushed bloom); dust puffs; the tapered column shoots up in 0.14 s; spiral cone
--             mesh winds up round the hen; point light swells; hen punch; small shake; gentle push-in
--   0 - 1.3   rising inked sparkles (3 per step, tapering to 1) + speed-line streaks up the column (to 1.0)
--   0 - 1.35  three ribbon trails spiral up the column
--   0.85      DING at head height: crisp 4-point flash (tinted rim + white-hot core, squash gleam) + star4 mesh gleam +
--             3 star bits (no feathers: an edge-on feather read as a stray dark stick in QA)
--   1.15-1.6  the column and the cone thin away
-- opts: color / rarity / palette (default gold), scale, follow (Instance or () -> Vector3), punch()
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local Palette = require(Vfx:WaitForChild("Palette"))
local R = require(Vfx:WaitForChild("Recipes"))
local seq, steps, vary, pop = Layers.seq, Layers.steps, Layers.vary, Layers.pop
local EASE = Layers.EASE

local RISE = {
	tex = "sparkle", orient = "face", life = { 0.7, 1.0 }, speed = { 7, 12 }, spread = 8, drag = 1,
	size = vary(pop(1.5, 0.12, 0.7, 0.5), 0.25), color = "hi", z = 2,
}
local STREAK = {
	tex = "speed_line", orient = "vel", life = { 0.26, 0.34 }, speed = { 28, 40 }, spread = 4, drag = 2,
	size = pop(1.8, 0.12, 0.6, 0.4), squash = seq(0, 2.6, 0.6, 1.8, 1, 1.2), trans = steps({ 0.7, 0.4 }),
	color = "hi", light = 0.9, bright = 1.6, z = 2.2,
}
local DING_RIM = {
	tex = "flash_star", orient = "face", life = 0.42, size = Layers.pop(6.5, 0.16, 0.5, 0), color = "mid",
	light = 1, bright = 1.6, z = 4, rotSpeed = 0, squash = seq(0, -0.5, 0.5, 0.3, 1, 0.6), noHold = true,
}
local DING_CORE = {
	tex = "flash_star", orient = "face", life = 0.4, size = Layers.pop(4.2, 0.16, 0.5, 0), color = "white",
	light = 1, bright = 2.4, z = 4.2, rotSpeed = 0, squash = seq(0, -0.5, 0.5, 0.3, 1, 0.6), noHold = true,
}
local TRAIL = {
	life = 0.45, color = { "hi", "mid" }, light = 0.9, bright = 1.5, trans = seq(0, 0, 0.6, 0.25, 1, 1),
}

local function column(t: number): number? -- 0..1 envelope of the column; nil = done
	if t < 0.14 then return EASE.out(t / 0.14) end
	if t < 1.15 then return 1 end
	if t >= 1.6 then return nil end
	return math.max(0, 1 - EASE["in"]((t - 1.15) / 0.45))
end

return {
	name = "level_up",
	cap = 4,
	replaceOldest = true,
	needs = { "sparkle", "glow_step", "flash_star" },
	run = function(fx, _cf, opts)
		if not (opts.palette or opts.rarity or opts.color) then fx.pal = Palette.get("Legendary") end
		local amount = fx:frame(fx:pos() + Vector3.new(0, 6, 0), 28, 0.08, 0.32, 0.35, 1.0, 0.8, 0.5)
		fx.view = fx:viewFor(fx.camDist * (1 - amount))
		fx.scale *= fx.view
		local sc = fx.scale
		local H = 22 * sc
		local function feet() return fx:pos() end
		-- ground: one wave + a small stepped glow (normal blend)
		if not fx:mesh("wall", { at = feet() + Vector3.new(0, 0.1, 0), face = "up", lift = true, spin = 0.5,
			r = { 1.2 * sc, 6 * sc }, rInT = 1, z = { 1.4 * sc, 0.05 }, life = 0.36, color = "hi",
			alpha = { { 0, 0.4 }, { 0.5, 0.6 }, { 0.8, 1 } } }) then
			fx:emit(R.WAVE, feet() + Vector3.new(0, 0.2, 0), 1, { size = R.waveSize(12), trans = R.waveTrans(0.6), life = 0.34 })
		end
		fx:emit(R.GLOW_FLAT, feet() + Vector3.new(0, 0.15, 0), 1, {
			life = 1.3, size = seq(0, 2.5, 0.12, 5.5, 1, 5), trans = steps({ 0.75, 0.5 }, { 0.9, 1 }),
		})
		fx:emitRadial(R.DUST, feet() + Vector3.new(0, 0.4, 0), fx:n(4, true), 0.1, { scale = 0.7, speed = { 5, 8 } })
		-- HERO: the tapered column (shoots up, holds, thins), following the hen
		R.pillar(fx, feet, H, 4.4 * sc, column)
		-- SUPPORT: a spiral cone winds up round the hen with the column, spins, then collapses (thins) away
		fx:mesh("tornado", { at = feet, face = "up", lift = true, spin = 6.5, spinEnd = 4, r = { 2.7 * sc, 2.1 * sc }, rInT = 1,
			zFn = function(u)
				local k = if u < 0.18 then EASE.out(u / 0.18) elseif u < 0.7 then 1 else 1 - EASE["in"]((u - 0.7) / 0.3)
				return H * 0.72 * k
			end, life = 1.6, color = "mid", alpha = { { 0, 0.15 }, { 0.8, 0.5 }, { 0.93, 1 } } })
		local light = fx:light(feet() + Vector3.new(0, 3, 0), "base", 14 * sc, 0)
		if light then
			fx:tick(function(t)
				light.att.WorldCFrame = CFrame.new(feet() + Vector3.new(0, 3, 0))
				light.light.Brightness = 4 * math.sin(math.clamp(t / 1.5, 0, 1) * math.pi)
				return t >= 1.5 or nil
			end)
		end
		-- AMBIENT: rising sparkles (a burst first, tapering) + speed lines up the column
		for k = 0, 13 do
			fx:at(k * 0.1, function()
				for _ = 1, fx:n(if k < 3 then 3 elseif k < 8 then 2 else 1, true) do
					local a = math.random() * math.pi * 2
					local r = 2.2 * sc
					fx:emit(RISE, feet() + Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r), 1)
				end
				if k % 2 == 0 and k <= 10 then
					local a = math.random() * math.pi * 2
					fx:emit(STREAK, feet() + Vector3.new(math.cos(a) * 1.4 * sc, 1, math.sin(a) * 1.4 * sc), fx:n(2, true))
				end
			end)
		end
		-- SUPPORT: three wide ribbon trails spiralling up
		for i = 1, 3 do
			local tr = fx:trail(TRAIL)
			if not tr then break end
			local a0 = i / 3 * math.pi * 2
			local started = false
			fx:tick(function(t)
				local u = math.clamp(t / 1.35, 0, 1)
				local a = a0 + t * 7
				local r = 2.6 * sc * (1 - 0.35 * u)
				local p = feet() + Vector3.new(math.cos(a) * r, 0.4 + H * 0.75 * EASE.out2(u), math.sin(a) * r)
				tr.a0.WorldPosition = p
				tr.a1.WorldPosition = p + Vector3.new(0, 1.0 * sc, 0)
				if not started then
					started = true
					tr.trail:Clear()
					tr.trail.Enabled = true -- after the first placement, so no streak from the pool position
				end
				if u >= 1 then
					tr.trail.Enabled = false
					fx:emit(RISE, p, 1, { tag = "trailEnd" })
					return true
				end
				return nil
			end)
		end
		-- the ding
		fx:at(0.85, function()
			local head = feet() + Vector3.new(0, 4.8 * sc, 0)
			local rot = math.random(-8, 8)
			fx:emit(DING_RIM, head, 1, { rot = rot })
			fx:emit(DING_CORE, head, 1, { rot = rot })
			fx:mesh("star4", { at = head, face = "camera", roll = math.rad(rot), spin = 0, r = { 0, 3.4 * sc }, rInT = 0.25,
				rEase = "back", life = 0.45, color = "white",
				xy = function(u) return 1 - 0.5 * u, 1 + 0.3 * u end, alpha = { { 0, 0 }, { 0.75, 0.5 }, { 0.9, 1 } } })
			fx:emit(R.STAR, head, fx:n(3, true))
		end)
		fx:extend(1.7)
		fx:shake(0.22, 0.3)
		if opts.punch then task.spawn(opts.punch) end
	end,
}
