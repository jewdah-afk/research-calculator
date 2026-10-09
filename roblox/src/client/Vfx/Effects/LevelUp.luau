--!nonstrict
-- level_up: a column of light round the player with rings and rising sparkles. ~1.6 s, follows the hen.
--   t 0      flat stepped glow under the feet + ground shockwave; light column (streak beam + white core) snaps up
--            (0.18 s), holds, thins out by 1.15 s; point light swell; small shake; opts.punch() (hen squash)
--   t 0-0.9  rising sparkles from a ring round the feet (every 0.1 s) + 3 ribbon trails spiralling up the column
--   t 0.08   echo ring (thin, wider)
--   t 0.8    "ding" at head height: star-burst flipbook + star bits popping up
-- opts: color / rarity / palette (default gold), scale, follow (Instance or () -> Vector3), punch()
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local Palette = require(Vfx:WaitForChild("Palette"))
local seq, curve, steps = Layers.seq, Layers.curve, Layers.steps
local EASE = Layers.EASE

local GLOW = {
	tex = "glow_disc", orient = "flat", life = 0.6, size = seq(0, 3, 0.3, 9, 1, 10),
	trans = steps({ 0.5, 0.5 }, { 0.8, 1 }), color = "base", light = 1, bright = 1.3, z = 0.1,
}
local SHOCK = {
	tex = "ring_shock", orient = "flat", life = 0.5, size = curve(2, 11, "out", 10),
	trans = steps({ 0.55, 0.4 }, { 0.8, 1 }), color = "mid", light = 0.2, z = 0.2,
}
local ECHO = {
	tex = "ring_thin", orient = "flat", life = 0.62, size = curve(2, 14.5, "out", 10),
	trans = steps({ 0.5, 0.5 }, { 0.8, 1 }), color = "hi", light = 0.5, z = 0.25,
}
local RISE = {
	tex = "sparkle", orient = "face", life = { 0.6, 0.9 }, speed = { 9, 15 }, spread = 8, drag = 1.2,
	size = 1.4, color = "hi", light = 0.6, z = 1,
}
local DING = {
	tex = "impact_star", orient = "face", life = 0.34, size = seq(0, 1.6, 0.2, 5, 1, 5.6),
	color = function(colorOf) return Layers.colorSteps(colorOf, { "white", 0.3 }, "mid") end, z = 2,
}
local STARS = {
	tex = "star", orient = "face", life = { 0.7, 0.95 }, speed = { 12, 18 }, spread = 40,
	accel = Vector3.new(0, -30, 0), drag = 1, size = seq(0, 1.1, 0.75, 1.1, 1, 0), rotSpeed = { -220, 220 },
	color = "mid", z = 1.4,
}
local COL = {
	tex = "beam_streak", texMode = Enum.TextureMode.Wrap, texLen = 6, texSpeed = 2.2, color = "mid",
	light = 1, bright = 1.4, trans = seq(0, 0.1, 0.6, 0.4, 1, 1), z = -0.3,
}
local COL_CORE = { color = "white", light = 1, bright = 2, trans = seq(0, 0, 0.55, 0.25, 1, 1), z = -0.2 }
local TRAIL = {
	life = 0.3, color = { "hi", "mid" }, light = 1, bright = 1.4,
	trans = seq(0, 0, 0.7, 0.3, 1, 1),
}

local function colWidth(t: number): number -- 0..1
	if t < 0.18 then return EASE.out(t / 0.18) end
	if t < 0.7 then return 1 end
	return math.max(0, 1 - EASE["in"]((t - 0.7) / 0.45))
end

return {
	name = "level_up",
	cap = 3,
	replaceOldest = true,
	needs = { "sparkle", "ring_shock" },
	run = function(fx, _cf, opts)
		if not (opts.palette or opts.rarity or opts.color) then fx.pal = Palette.get("Legendary") end
		local sc = fx.scale
		local H = 24 * sc
		local function feet() return fx:pos() end
		fx:emit(GLOW, feet() + Vector3.new(0, 0.1, 0), 1)
		fx:emit(SHOCK, feet() + Vector3.new(0, 0.15, 0), 1)
		fx:at(0.08, function() fx:emit(ECHO, feet() + Vector3.new(0, 0.2, 0), 1) end)
		-- light column
		local col = fx:beam(COL, feet(), feet() + Vector3.new(0, H, 0))
		local core = fx:beam(COL_CORE, feet(), feet() + Vector3.new(0, H, 0))
		local light = fx:light(feet() + Vector3.new(0, 3, 0), "base", 14, 0)
		fx:tick(function(t)
			local k = colWidth(t)
			local p0, p1 = feet() + Vector3.new(0, 0.2, 0), feet() + Vector3.new(0, H, 0)
			if col then col.set(p0, p1, 5 * k * sc, 6.5 * k * sc) end
			if core then core.set(p0, p1, 1.7 * k * sc, 2.2 * k * sc) end
			if light then
				light.att.WorldCFrame = CFrame.new(feet() + Vector3.new(0, 3, 0))
				light.light.Brightness = 4 * math.sin(math.clamp(t / 0.9, 0, 1) * math.pi)
			end
			if t >= 1.15 then
				if col then col.beam.Enabled = false end
				if core then core.beam.Enabled = false end
				return true
			end
			return nil
		end)
		-- rising sparkles from a ring round the feet
		for k = 0, 8 do
			fx:at(k * 0.1, function()
				for _ = 1, fx:n(3, true) do
					local a = math.random() * math.pi * 2
					local r = 2.2 * sc
					fx:emit(RISE, feet() + Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r), 1)
				end
			end)
		end
		-- three ribbon trails spiralling up the column
		for i = 1, 3 do
			local tr = fx:trail(TRAIL)
			if not tr then break end
			local a0 = i / 3 * math.pi * 2
			local started = false
			fx:tick(function(t)
				local u = math.clamp(t / 0.95, 0, 1)
				local a = a0 + t * 8
				local r = 2.4 * sc * (1 - 0.3 * u)
				local p = feet() + Vector3.new(math.cos(a) * r, 0.4 + H * 0.55 * u ^ 0.85, math.sin(a) * r)
				tr.a0.WorldPosition = p
				tr.a1.WorldPosition = p + Vector3.new(0, 0.55 * sc, 0)
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
		fx:at(0.8, function()
			local head = feet() + Vector3.new(0, 4.6 * sc, 0)
			fx:emit(DING, head, 1)
			fx:emit(STARS, head, fx:n(6, true))
		end)
		fx:extend(1.6)
		fx:shake(0.3, 0.3)
		if opts.punch then task.spawn(opts.punch) end
	end,
}
