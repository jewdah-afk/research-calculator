--!nonstrict
-- level_up: ~1.6 s round the player, follows the hen. HERO = the light column, SUPPORT = spiral ribbons + the "ding",
-- AMBIENT = rising sparkles. Gentle camera push-in; sizes follow the camera distance.
--   t 0       one uneven ground wave (0.34 s) + a 3-band glow under the feet; light column (streaked beam + white core)
--             SHOOTS up in 0.14 s; point light swells; hen punch; small shake; gentle push-in starts
--   0 - 1.1   rising inked sparkles from a ring round the feet (every 0.1 s) + speed lines streaking up the column
--   0 - 1.25  three ribbon trails spiral up the column (wide, additive)
--   0.95      column starts to thin; gone at 1.45
--   0.9       DING at head height: crisp 4-point flash (tinted rim + white-hot core) with a squash gleam, 3 star bits,
--             2 feathers drifting off
-- opts: color / rarity / palette (default gold), scale, follow (Instance or () -> Vector3), punch()
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local Palette = require(Vfx:WaitForChild("Palette"))
local R = require(Vfx:WaitForChild("Recipes"))
local seq, steps, vary = Layers.seq, Layers.steps, Layers.vary
local EASE = Layers.EASE

local RISE = {
	tex = "sparkle", orient = "face", life = { 0.7, 1.0 }, speed = { 7, 12 }, spread = 8, drag = 1,
	size = vary(seq(0, 1.3, 1, 1.3), 0.25), color = "hi", z = 2,
}
local STREAK = {
	tex = "speed_line", orient = "vel", life = { 0.26, 0.34 }, speed = { 28, 40 }, spread = 4, drag = 2,
	size = seq(0, 1.6, 0.6, 1.4, 1, 0.4), squash = seq(0, 2.2, 1, 1.4), color = "hi", light = 1, bright = 1.8, z = 2.2,
}
local DING_RIM = {
	tex = "flash_star", orient = "face", life = 0.32, size = Layers.pop(6.5, 0.18, 0.45, 0), color = "mid",
	light = 1, bright = 1.7, z = 4, rotSpeed = 0, squash = seq(0, -0.5, 0.5, 0.3, 1, 0.6), noHold = true,
}
local DING_CORE = {
	tex = "flash_star", orient = "face", life = 0.3, size = Layers.pop(4.2, 0.18, 0.45, 0), color = "white",
	light = 1, bright = 2.8, z = 4.2, rotSpeed = 0, squash = seq(0, -0.5, 0.5, 0.3, 1, 0.6), noHold = true,
}
local COL = {
	tex = "beam_core", texMode = Enum.TextureMode.Wrap, texLen = 6, texSpeed = 2.2, color = "mid",
	light = 1, bright = 1.6, trans = seq(0, 0.05, 0.7, 0.35, 1, 1), z = -0.3,
}
local COL_CORE = { color = "white", light = 1, bright = 2.2, trans = seq(0, 0, 0.6, 0.25, 1, 1), z = -0.2 }
local TRAIL = {
	life = 0.45, color = { "hi", "mid" }, light = 1, bright = 1.6, trans = seq(0, 0, 0.6, 0.25, 1, 1),
}

local function colWidth(t: number): number -- 0..1 envelope of the column
	if t < 0.14 then return EASE.out(t / 0.14) end
	if t < 0.95 then return 1 end
	return math.max(0, 1 - EASE["in"]((t - 0.95) / 0.5))
end

return {
	name = "level_up",
	cap = 4,
	replaceOldest = true,
	needs = { "sparkle", "ring_wave", "flash_star" },
	run = function(fx, _cf, opts)
		if not (opts.palette or opts.rarity or opts.color) then fx.pal = Palette.get("Legendary") end
		local amount = fx:frame(fx:pos() + Vector3.new(0, 6, 0), 30, 0.06, 0.3, 0.35, 0.9, 0.7, 0.5)
		fx.view = fx:viewFor(fx.camDist * (1 - amount))
		fx.scale *= fx.view
		local sc = fx.scale
		local H = 24 * sc
		local function feet() return fx:pos() end
		-- ground
		fx:emit(R.WAVE, feet() + Vector3.new(0, 0.2, 0), 1, { size = R.waveSize(12), trans = R.waveTrans(0.6), life = 0.34 })
		fx:emit(R.GLOW_FLAT, feet() + Vector3.new(0, 0.15, 0), 1, {
			size = seq(0, 3, 0.25, 7.5, 1, 6), trans = steps({ 0.55, 0.6 }, { 0.8, 1 }),
		})
		-- HERO: the column shoots up, holds, thins
		local col = fx:beam(COL, feet(), feet())
		local core = fx:beam(COL_CORE, feet(), feet())
		local light = fx:light(feet() + Vector3.new(0, 3, 0), "base", 14 * sc, 0)
		fx:tick(function(t)
			local k = colWidth(t)
			local up = EASE.out(math.clamp(t / 0.14, 0, 1))
			local p0, p1 = feet() + Vector3.new(0, 0.2, 0), feet() + Vector3.new(0, 0.2 + H * up, 0)
			if col then col.set(p0, p1, 5 * k * sc, 6.5 * k * sc) end
			if core then core.set(p0, p1, 1.6 * k * sc, 2.1 * k * sc) end
			if light then
				light.att.WorldCFrame = CFrame.new(feet() + Vector3.new(0, 3, 0))
				light.light.Brightness = 4 * math.sin(math.clamp(t / 1.3, 0, 1) * math.pi)
			end
			if t >= 1.45 then
				if col then col.beam.Enabled = false end
				if core then core.beam.Enabled = false end
				return true
			end
			return nil
		end)
		-- AMBIENT: rising sparkles + SUPPORT speed lines up the column
		for k = 0, 11 do
			fx:at(k * 0.1, function()
				for _ = 1, fx:n(2, true) do
					local a = math.random() * math.pi * 2
					local r = 2.2 * sc
					fx:emit(RISE, feet() + Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r), 1)
				end
				if k % 2 == 0 and k <= 8 then
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
				local u = math.clamp(t / 1.25, 0, 1)
				local a = a0 + t * 7
				local r = 2.6 * sc * (1 - 0.35 * u)
				local p = feet() + Vector3.new(math.cos(a) * r, 0.4 + H * 0.75 * EASE.out2(u), math.sin(a) * r)
				tr.a0.WorldPosition = p
				tr.a1.WorldPosition = p + Vector3.new(0, 0.9 * sc, 0)
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
		fx:at(0.9, function()
			local head = feet() + Vector3.new(0, 4.8 * sc, 0)
			local rot = math.random(-8, 8)
			fx:emit(DING_RIM, head, 1, { rot = rot })
			fx:emit(DING_CORE, head, 1, { rot = rot })
			fx:emit(R.STAR, head, fx:n(3, true))
			fx:emit(R.FEATHER, head, fx:n(2))
		end)
		fx:extend(1.6)
		fx:shake(0.22, 0.3)
		if opts.punch then task.spawn(opts.punch) end
	end,
}
