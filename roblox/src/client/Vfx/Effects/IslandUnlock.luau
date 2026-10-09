--!nonstrict
-- island_unlock: rides IslandView.unlockIsland's rise. Times are seconds after the unlock animation starts.
--   S = max(0.15, waveStart - 0.45)
--   S .. S+0.8      RUNE CIRCLE draws in over the new island's centre: outer ring traced with a spark on its leading
--                   edge, inner ring, then the hexagram line by line (all flat beams with an ink twin, crisp at any
--                   size), then the rune band (beam_runes) fades in and slowly circulates. A summon pillar rises.
--   waveStart ..    SWEEPING LIGHT WAVE: a flat light ring expands from the landing in step with the tile wave
--                   (radius = (t - waveStart) / step tiles); every coast tile bursts toon dust + tumbling leaves as
--                   it breaks the surface (sampled, <= 56 bursts).
--   waveEnd         FINALE: the rune flashes out (widens + steps away), a big shock ring sweeps the island, sparkle
--                   + confetti shower from above, star burst at the centre, shake + soft colour flash.
-- opts.info (from Vfx/Hooks.unlockInfo, built from IslandView's unlock data):
--   { centre: Vector3 (y = land top), radius, landing: Vector3, waveStart, waveEnd, step, maxD,
--     edge = { { pos, at, out } }, dust: Color3?, leaf: Color3? }
-- Without opts.info (dev preview) a synthetic island round `where` is used (opts.radius, default 34).
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local Palette = require(Vfx:WaitForChild("Palette"))
local seq, steps = Layers.seq, Layers.steps
local EASE = Layers.EASE
local S = 4 -- studs per tile (Models.S)

local RING_INK = { width = 1.6, color = "ink", light = 0, z = -0.1, segments = 64 }
local RING_LINE = { width = 0.75, color = "mid", light = 0.6, bright = 1.4, z = 0.1, segments = 64 }
local RING_THIN_INK = { width = 1.1, color = "ink", light = 0, z = -0.1, segments = 64 }
local RING_THIN = { width = 0.45, color = "hi", light = 0.6, bright = 1.3, z = 0.1, segments = 64 }
local RUNES = {
	tex = "beam_runes", texRequired = true, texMode = Enum.TextureMode.Stretch, texRepeat = 8, texSpeed = 0.05,
	width = 1, color = "mid", light = 0.35, bright = 1.2, z = 0.05, segments = 64,
}
local LINE_INK = { face = false, color = "ink", light = 0, z = -0.1 }
local LINE = { face = false, color = "hi", light = 0.6, bright = 1.3, z = 0.1 }
local WAVE = { width = 4.5, color = "hi", light = 1, bright = 1.6, alpha = 0.15, z = 0.3, segments = 64 }
local WAVE_TRAIL = { width = 1.8, color = "mid", light = 1, bright = 1.3, alpha = 0.35, z = 0.25, segments = 64 }
local SWEEP = { width = 5, color = "hi", light = 1, bright = 1.8, z = 0.4, segments = 64 }
local PILLAR = {
	tex = "beam_streak", texMode = Enum.TextureMode.Wrap, texLen = 10, texSpeed = 1.4, color = "base",
	light = 1, bright = 1.4, trans = seq(0, 0.15, 0.6, 0.5, 1, 1), z = -0.5,
}
local PILLAR_CORE = { color = "white", light = 1, bright = 2, trans = seq(0, 0.05, 0.55, 0.35, 1, 1), z = -0.4 }

local SPARK = { tex = "sparkle", orient = "face", life = 0.5, speed = { 1, 3 }, spread = 180, size = 3, color = "hi", light = 0.6, z = 1, noScale = true }
local DUST = {
	tex = "smoke_puff", orient = "face", life = { 0.6, 0.85 }, speed = { 6, 10 }, drag = 3, accel = Vector3.new(0, 2, 0),
	size = seq(0, 2.4, 1, 4.4), rotSpeed = { -30, 30 }, color = "f1e6cf", z = 0.5, noScale = true,
}
local LEAF = {
	tex = "leaf", orient = "face", life = { 1.3, 1.9 }, speed = { 9, 15 }, spread = 40, accel = Vector3.new(2, -10, 1),
	drag = 1.1, size = 1.0, rotSpeed = { -120, 120 }, fps = { 12, 18 }, startRandom = true, color = "white", z = 0.6, noScale = true,
}
local SHOWER = {
	tex = "sparkle", orient = "face", life = { 1.6, 2.4 }, speed = { 0.5, 2 }, dir = Enum.NormalId.Bottom, spread = 30,
	accel = Vector3.new(0, -7, 0), drag = 0.3, size = 2.4, color = "hi", light = 0.55, z = 1, noScale = true,
}
local CONFETTI = {
	tex = "confetti", orient = "face", life = { 2.2, 3.0 }, speed = { 1, 4 }, dir = Enum.NormalId.Bottom, spread = 70,
	accel = Vector3.new(0, -9, 0), drag = 0.9, size = 1.8, rotSpeed = { -90, 90 }, fps = { 12, 20 }, startRandom = true,
	z = 0.8, noScale = true,
}
local STAR = {
	tex = "star", orient = "face", life = { 0.9, 1.2 }, speed = { 22, 34 }, spread = 55, accel = Vector3.new(0, -36, 0),
	drag = 1, size = seq(0, 2.4, 0.75, 2.4, 1, 0), rotSpeed = { -200, 200 }, color = "mid", z = 1.4, noScale = true,
}
local FLASHGLOW = {
	tex = "glow_disc", orient = "flat", life = 0.5, size = 1, trans = steps({ 0.4, 0.5 }, { 0.7, 1 }),
	color = "hi", light = 1, bright = 1.5, z = 0.5, noScale = true,
}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.xAxis
end

-- a stand-in island for the dev preview: a round island of radius R round c, wave from the west shore
local function synth(c: Vector3, R: number)
	local step = 0.05
	local landing = c + Vector3.new(-R, 0, R * 0.25)
	local waveStart = 1.0
	local maxD = (2 * R) / S
	local edge = {}
	for i = 1, 64 do
		local a = i / 64 * math.pi * 2
		local r = R * (0.9 + 0.1 * math.noise(i * 0.37, 1.3))
		local p = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		table.insert(edge, { pos = p, at = waveStart + ((p - landing).Magnitude / S) * step, out = flat(p - c) })
	end
	return { centre = c, radius = R, landing = landing, waveStart = waveStart, waveEnd = waveStart + maxD * step + 0.8,
		step = step, maxD = maxD, edge = edge }
end

return {
	name = "island_unlock",
	cap = 1,
	replaceOldest = true,
	needs = {}, -- the rings, lines, wave and pillar are beams: they draw even before any texture is uploaded
	run = function(fx, cf, opts)
		if not (opts.palette or opts.rarity or opts.color) then fx.pal = Palette.get("unlock") end
		local info = opts.info or synth(cf.Position, opts.radius or 34)
		local C = info.centre
		local R = info.radius
		local Rc = math.clamp(R * 0.55, 12, 44)
		local y = C.Y + 0.35
		local cc = Vector3.new(C.X, y, C.Z)
		local start = math.max(0.15, info.waveStart - 0.45)
		local finale = info.waveEnd
		local dust = info.dust or Color3.fromHex("f1e6cf")
		-- ---------------------------------------------------------------- rune circle
		local outer = fx:ring({ RING_INK, RING_LINE }, cc, Rc)
		local inner = fx:ring({ RING_THIN_INK, RING_THIN }, cc + Vector3.new(0, 0.02, 0), Rc * 0.8)
		local runes = fx:ring({ RUNES }, cc + Vector3.new(0, 0.04, 0), Rc * 0.9)
		local rings = { outer, inner, runes }
		for _, r in rings do if r then r.trace(0); r.ws0 = 1 end end
		if runes then runes.ws0 = Rc * 0.15; runes.set(nil, nil, runes.ws0) end
		local lastSpark = -1
		fx:tick(function(t)
			local u1 = math.clamp((t - start) / 0.55, 0, 1)
			local u2 = math.clamp((t - start - 0.25) / 0.45, 0, 1)
			if outer then outer.trace(EASE.inout(u1)) end
			if inner then inner.trace(EASE.inout(u2)) end
			if outer and u1 > 0 and u1 < 1 and t - lastSpark > 0.05 then
				lastSpark = t
				fx:emit(SPARK, outer.point(EASE.inout(u1)) + Vector3.new(0, 0.4, 0), 1)
			end
			return u2 >= 1 or nil
		end)
		-- hexagram, line by line (two triangles)
		local lines = {}
		local vr = Rc * 0.74
		for tri = 0, 1 do
			local a0 = if tri == 0 then -math.pi / 2 else math.pi / 2
			local v = {}
			for j = 0, 2 do
				local a = a0 + j * 2 * math.pi / 3
				v[j + 1] = cc + Vector3.new(math.cos(a) * vr, 0.03, math.sin(a) * vr)
			end
			for j = 1, 3 do
				local p0, p1 = v[j], v[j % 3 + 1]
				local tStart = start + 0.45 + (tri * 3 + j - 1) * 0.09
				local ink = fx:beam(LINE_INK, p0, p0)
				local ln = fx:beam(LINE, p0 + Vector3.new(0, 0.01, 0), p0 + Vector3.new(0, 0.01, 0))
				local L = { ink = ink, ln = ln, p0 = p0, p1 = p1, t0 = tStart }
				table.insert(lines, L)
				fx:tick(function(t)
					local u = math.clamp((t - L.t0) / 0.16, 0, 1)
					local q = p0:Lerp(p1, EASE.out2(u))
					if ink then ink.set(p0, q, 1.1) end
					if ln then ln.set(p0 + Vector3.new(0, 0.01, 0), q + Vector3.new(0, 0.01, 0), 0.5) end
					return u >= 1 or nil
				end)
			end
		end
		fx:at(start + 0.95, function()
			if not runes then return end
			local t0 = fx.t
			fx:tick(function(t)
				local u = math.clamp((t - t0) / 0.3, 0, 1)
				runes.trace(1)
				runes.alpha(if u < 0.33 then 0.75 elseif u < 0.66 then 0.4 else 0)
				return u >= 1 or nil
			end)
		end)
		-- summon pillar (bell width) from the drawing of the circle until the land is up
		local pillarEnd = math.max(start + 1.6, info.waveStart + 0.8)
		fx:at(start + 0.1, function()
			local top = cc + Vector3.new(0, 80, 0)
			local outerB = fx:beam(PILLAR, cc, top)
			local coreB = fx:beam(PILLAR_CORE, cc, top)
			local t0 = fx.t
			fx:tick(function(t)
				local u = math.clamp((t - t0) / (pillarEnd - t0), 0, 1)
				local k = if u < 0.2 then EASE.out(u / 0.2) elseif u < 0.75 then 1 else 1 - EASE["in"]((u - 0.75) / 0.25)
				if outerB then outerB.set(nil, nil, 7 * k, 9 * k) end
				if coreB then coreB.set(nil, nil, 2.4 * k, 3 * k) end
				if u >= 1 then
					if outerB then outerB.beam.Enabled = false end
					if coreB then coreB.beam.Enabled = false end
					return true
				end
				return nil
			end)
		end)
		-- ---------------------------------------------------------------- sweeping light wave from the landing
		local Lp = Vector3.new(info.landing.X, y + 0.25, info.landing.Z)
		local waveDur = info.maxD * info.step
		fx:at(info.waveStart, function()
			local wave = fx:ring({ WAVE }, Lp, 0.5)
			local trail = fx:ring({ WAVE_TRAIL }, Lp - Vector3.new(0, 0.05, 0), 0.5)
			local t0 = fx.t
			fx:tick(function(t)
				local u = math.clamp((t - t0) / waveDur, 0, 1)
				local r = math.max(0.5, (t - t0) / info.step * S)
				if wave then wave.set(nil, r) end
				if trail then trail.set(nil, math.max(0.5, r - 3.5)) end
				local fade = math.clamp((u - 0.8) / 0.2, 0, 1)
				if wave then wave.alpha(if fade < 0.5 then fade * 0.6 else 0.6 + fade * 0.4) end
				if trail then trail.alpha(fade) end
				if u >= 1 then
					if wave then wave.alpha(1) end
					if trail then trail.alpha(1) end
					return true
				end
				return nil
			end)
		end)
		-- ---------------------------------------------------------------- coast bursts as the land breaks the surface
		local edge = info.edge or {}
		local maxBursts = fx:n(56)
		local every = math.max(1, math.ceil(#edge / math.max(1, maxBursts)))
		for i = 1, #edge, every do
			local e = edge[i]
			fx:at(e.at + 0.2, function()
				local dir = (e.out or flat(e.pos - C)) * 0.9 + Vector3.new(0, 0.7, 0)
				local p = Vector3.new(e.pos.X, y + 0.4, e.pos.Z)
				fx:emit(DUST, Layers.upTo(p, dir), 2, { color = dust })
				fx:emit(LEAF, Layers.upTo(p, dir), math.random(1, 2), { color = info.leaf or "white" })
			end)
		end
		-- ---------------------------------------------------------------- finale
		fx:at(finale, function()
			-- rune flashes out: widens, then steps away
			local t0 = fx.t
			fx:tick(function(t)
				local u = math.clamp((t - t0) / 0.42, 0, 1)
				local a = if u < 0.35 then 0 elseif u < 0.7 then 0.5 else 1
				for _, r in rings do
					if r then
						r.set(nil, nil, r.ws0 * (1 + 0.9 * EASE.out(u)))
						r.alpha(a)
					end
				end
				for _, L in lines do
					if L.ink then L.ink.beam.Transparency = NumberSequence.new(a) end
					if L.ln then L.ln.beam.Transparency = NumberSequence.new(a) end
				end
				return u >= 1 or nil
			end)
			-- shock ring sweeping the whole island
			local sweep = fx:ring({ SWEEP }, cc + Vector3.new(0, 0.3, 0), 2)
			if sweep then
				fx:tick(function(t)
					local u = math.clamp((t - t0) / 0.65, 0, 1)
					sweep.set(nil, 2 + (R * 1.05 - 2) * EASE.out(u), 1 - 0.8 * u)
					sweep.alpha(if u < 0.6 then 0 elseif u < 0.85 then 0.45 else 1)
					return u >= 1 or nil
				end)
			end
			fx:emit(FLASHGLOW, cc + Vector3.new(0, 0.2, 0), 1, { size = seq(0, R * 0.3, 0.3, R * 0.9, 1, R) })
			fx:emit(STAR, cc + Vector3.new(0, 2, 0), fx:n(12, true))
			-- shower from above
			local n = fx:n(26, true)
			for _ = 1, n do
				local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * R * 0.8
				fx:emit(SHOWER, cc + Vector3.new(math.cos(a) * r, 20 + math.random() * 8, math.sin(a) * r), 1)
			end
			local cols = { "mid", "accent", "white" }
			local per = fx:n(8)
			for i, c in cols do
				for _ = 1, per do
					local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * R * 0.75
					fx:emit(CONFETTI, cc + Vector3.new(math.cos(a) * r, 22 + math.random() * 6, math.sin(a) * r), 1, { color = c, tag = "conf" .. i })
				end
			end
			fx:shake(0.7, 0.45)
			fx:flash("hi", 0.2, 0.55)
		end)
		fx:extend(finale + 3.2)
	end,
}
