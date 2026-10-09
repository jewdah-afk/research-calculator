--!nonstrict
-- island_unlock: rides IslandView.unlockIsland's rise. Times are seconds after the unlock animation starts.
-- HERO = the magic circle, SUPPORT = the light wave + coast bursts, AMBIENT = sparkle / feather shower at the end.
-- All ground pieces are FLAT PARTICLES (VelocityPerpendicular): no flat beams anywhere (they stood up in QA).
--   S = max(0.15, waveStart - 0.45)
--   S .. S+0.4     rune circle drops in over the new island's centre (from 118 % size, alpha in three hard steps) while
--                  the swirl flipbook, lying flat, traces round it once; a summon pillar rises (FaceCamera beams)
--   waveStart ..   SWEEPING LIGHT WAVE: an uneven flat wave grows from the landing in step with the tile wave
--                  (radius = (t - waveStart) / step tiles), glints flash on sampled tiles as they rise, and every
--                  sampled coast tile bursts toon dust + tumbling leaves as it breaks the surface (<= 56)
--   waveEnd        FINALE: the circle flashes out (widens + steps away), a wave sweeps the island from the centre,
--                  sparkle + feather + confetti shower, a star burst, shake, soft colour flash, gentle push-in
-- opts.info (from Vfx/Hooks.unlockInfo): { centre (y = land top), radius, landing, waveStart, waveEnd, step, maxD,
--   edge = { { pos, at, out } }, tiles = { { pos, at } }, dust: Color3? }. Without it (dev preview) a synthetic
--   round island of opts.radius (default 34) round `where` is used.
local Vfx = script.Parent.Parent
local Layers = require(Vfx:WaitForChild("Layers"))
local Palette = require(Vfx:WaitForChild("Palette"))
local R = require(Vfx:WaitForChild("Recipes"))
local seq, vary = Layers.seq, Layers.vary
local EASE = Layers.EASE
local S = 4 -- studs per tile (Models.S)

local RUNE = { tex = "rune_circle", orient = "flat", life = 3, size = 1, rotSpeed = { 8, 8 }, color = "mid", light = 0.35, z = 0.4, noScale = true }
local TRACE = { tex = "swirl_arc", orient = "flat", life = 0.7, size = 1, color = "hi", light = 1, bright = 1.9, z = 0.5, noScale = true }
local WAVE = { tex = "ring_wave", orient = "flat", life = 1, size = 1, color = "hi", light = 0.7, bright = 1.4, z = 0.5, noScale = true }
local GLINT = {
	tex = "glow_step", orient = "flat", life = 0.35, size = Layers.pop(6, 0.25, 0.4, 0), color = "hi",
	light = 0.8, bright = 1.4, z = 0.45,
}
local LEAF = {
	tex = "leaf", orient = "face", life = { 1.3, 1.9 }, speed = { 9, 15 }, spread = 40, accel = Vector3.new(2, -10, 1),
	drag = 1.1, size = vary(seq(0, 1.0, 1, 1.0), 0.3), rotSpeed = { -120, 120 }, fps = { 12, 18 }, startRandom = true,
	color = "white", z = 1.1,
}
local SHOWER = {
	tex = "sparkle", orient = "face", life = { 1.6, 2.4 }, speed = { 0.5, 2 }, dir = Enum.NormalId.Bottom, spread = 30,
	accel = Vector3.new(0, -7, 0), drag = 0.3, size = vary(seq(0, 2.2, 1, 2.2), 0.3), color = "hi", z = 2,
}
local DROP = { -- feathers / confetti falling from above for the finale
	tex = "feather", orient = "face", life = { 2.2, 3 }, speed = { 1, 3 }, dir = Enum.NormalId.Bottom, spread = 60,
	accel = Vector3.new(1, -6, 0), drag = 1.2, size = vary(seq(0, 1.6, 1, 1.6), 0.35), rotSpeed = { -60, 60 },
	fps = { 8, 12 }, startRandom = true, color = "hi", z = 2.1,
}
local PILLAR = {
	tex = "beam_core", texMode = Enum.TextureMode.Wrap, texLen = 10, texSpeed = 1.4, color = "base",
	light = 1, bright = 1.6, trans = seq(0, 0.1, 0.6, 0.45, 1, 1), z = -0.5,
}
local PILLAR_CORE = { color = "white", light = 1, bright = 2.2, trans = seq(0, 0.05, 0.55, 0.35, 1, 1), z = -0.4 }

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.xAxis
end

-- a stand-in island for the dev preview: round island of radius R round c, wave from the west shore
local function synth(c: Vector3, Rad: number)
	local step = 0.05
	local landing = c + Vector3.new(-Rad, 0, Rad * 0.25)
	local waveStart = 1.0
	local maxD = (2 * Rad) / S
	local edge, tiles = {}, {}
	for i = 1, 64 do
		local a = i / 64 * math.pi * 2
		local r = Rad * (0.9 + 0.1 * math.noise(i * 0.37, 1.3))
		local p = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		table.insert(edge, { pos = p, at = waveStart + ((p - landing).Magnitude / S) * step, out = flat(p - c) })
	end
	for _ = 1, 60 do
		local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * Rad * 0.9
		local p = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		table.insert(tiles, { pos = p, at = waveStart + ((p - landing).Magnitude / S) * step })
	end
	return { centre = c, radius = Rad, landing = landing, waveStart = waveStart, waveEnd = waveStart + maxD * step + 0.8,
		step = step, maxD = maxD, edge = edge, tiles = tiles }
end

return {
	name = "island_unlock",
	cap = 2,
	replaceOldest = true,
	needs = { "rune_circle", "ring_wave" },
	run = function(fx, cf, opts)
		if not (opts.palette or opts.rarity or opts.color) then fx.pal = Palette.get("unlock") end
		fx.scale *= fx.view -- small pieces read at the island-wide camera; island geometry stays in world studs
		local info = opts.info or synth(cf.Position, opts.radius or 34)
		local C = info.centre
		local Rad = info.radius
		local D = 2 * math.clamp(Rad * 0.55, 12, 44)
		local y = C.Y + 0.4
		local cc = Vector3.new(C.X, y, C.Z)
		local start = math.max(0.15, info.waveStart - 0.45)
		local finale = info.waveEnd
		local dust = info.dust or Color3.fromHex("f1e6cf")
		-- ---------------------------------------------------------------- HERO: the magic circle (one particle)
		fx:at(start, function()
			local L = finale + 0.45 - start
			local hold = (L - 0.45) / L
			fx:emit(RUNE, cc, 1, {
				life = L,
				size = seq(0, D * 1.18, 0.25 / L, D, hold, D, 1, D * 1.3),
				trans = seq(0, 1, 0.12 / L, 0.6, 0.2 / L, 0.6, 0.204 / L, 0.25, 0.3 / L, 0.25, 0.304 / L, 0,
					hold, 0, hold + 0.004, 0.45, hold + 0.5 * (1 - hold), 0.45, hold + 0.5 * (1 - hold) + 0.004, 1, 1, 1),
			})
			-- a glowing arc wall lying on the circle sweeps once round it as it appears (the flat swirl flipbook if no mesh)
			if not fx:mesh("arc", { at = cc, face = "flat", lift = true, roll = 0, spin = 10, spinEnd = 6, r = { D * 0.52, D * 0.52 },
				z = { 3, 0.2 }, life = 0.75, color = "hi", alpha = { { 0, 0 }, { 0.7, 0.45 }, { 0.88, 1 } } }) then
				fx:emit(TRACE, cc + Vector3.new(0, 0.05, 0), 1, { size = D * 1.04 })
			end
		end)
		-- summon pillar
		local pillarEnd = math.max(start + 1.6, info.waveStart + 0.8)
		fx:at(start + 0.1, function()
			-- a big spiral cone winds up round the pillar while the circle is drawn
			fx:mesh("tornado", { at = cc, face = "up", lift = true, spin = 3.5, spinEnd = 2, r = { D * 0.18, D * 0.26 }, rInT = 1,
				zFn = function(u) return 46 * (if u < 0.25 then EASE.out(u / 0.25) elseif u < 0.75 then 1 else 1 - EASE["in"]((u - 0.75) / 0.25)) end,
				life = pillarEnd - start - 0.1, color = "base", alpha = { { 0, 0.25 }, { 0.8, 0.55 }, { 0.92, 1 } } })
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
		-- ---------------------------------------------------------------- SUPPORT: light wave + glints from the landing
		local waveDur = math.max(0.3, info.maxD * info.step)
		fx:at(info.waveStart, function()
			local Dmax = 2 * info.maxD * S
			local lp = Vector3.new(info.landing.X, y + 0.1, info.landing.Z)
			if fx:mesh("wallring", { at = lp, face = "flat", lift = true, spin = 0.3, r = { 1, Dmax / 2 }, rEase = "lin", rInT = 1,
				z = { 3.2, 1 }, zEase = "lin", life = waveDur, color = "hi", alpha = { { 0, 0.35 }, { 0.85, 0.6 }, { 0.95, 1 } } }) then
				return
			end
			fx:emit(WAVE, Vector3.new(info.landing.X, y + 0.2, info.landing.Z), 1, {
				life = waveDur + 0.25,
				size = seq(0, 2, waveDur / (waveDur + 0.25), Dmax, 1, Dmax * 1.04),
				trans = seq(0, 0.35, 0.8, 0.35, 0.804, 0.6, 0.92, 0.6, 0.924, 1, 1, 1),
			})
		end)
		local tiles = info.tiles or {}
		local maxGl = fx:n(60)
		local everyT = math.max(1, math.ceil(#tiles / math.max(1, maxGl)))
		for i = 1, #tiles, everyT do
			local tl = tiles[i]
			fx:at(tl.at + 0.12, function() fx:emit(GLINT, Vector3.new(tl.pos.X, y + 0.3, tl.pos.Z), 1) end)
		end
		-- coast bursts as the land breaks the surface
		local edge = info.edge or {}
		local maxBursts = fx:n(56)
		local every = math.max(1, math.ceil(#edge / math.max(1, maxBursts)))
		for i = 1, #edge, every do
			local e = edge[i]
			fx:at(e.at + 0.2, function()
				local dir = (e.out or flat(e.pos - C)) * 0.9 + Vector3.new(0, 0.7, 0)
				local p = Vector3.new(e.pos.X, y + 0.4, e.pos.Z)
				fx:emit(R.DUST, Layers.upTo(p, dir), 2, { color = dust })
				fx:emit(LEAF, Layers.upTo(p, dir), math.random(1, 2))
			end)
		end
		-- ---------------------------------------------------------------- finale
		fx:at(finale, function()
			if not fx:mesh("wallring", { at = cc, face = "flat", lift = true, spin = -0.4, r = { 2, Rad * 1.05 }, rInT = 1,
				z = { 4, 0.2 }, life = 0.55, color = "hi", alpha = { { 0, 0.35 }, { 0.6, 0.6 }, { 0.85, 1 } } }) then
				fx:emit(WAVE, cc + Vector3.new(0, 0.1, 0), 1, {
					life = 0.55, size = Layers.curve(4, Rad * 2.1, "out", 10), trans = R.waveTrans(0.6), tag = "sweep",
				})
			end
			-- a translucent toon dome blooms over the new island and flattens away (clip3's dome, our palette)
			fx:mesh("dome", { at = cc, face = "up", lift = true, spin = 0.3, r = { Rad * 0.3, Rad * 1.1 }, rInT = 0.6,
				zFn = function(u, r) return r * 0.5 * (1 - 0.6 * u * u) end, life = 0.85, color = "hi",
				alpha = { { 0, 0.5 }, { 0.5, 0.7 }, { 0.8, 1 } } })
			fx:emit(R.STAR, cc + Vector3.new(0, 2, 0), fx:n(6, true))
			for _ = 1, fx:n(16, true) do
				local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * Rad * 0.8
				fx:emit(SHOWER, cc + Vector3.new(math.cos(a) * r, 20 + math.random() * 8, math.sin(a) * r), 1)
			end
			for _ = 1, fx:n(8) do
				local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * Rad * 0.75
				fx:emit(DROP, cc + Vector3.new(math.cos(a) * r, 22 + math.random() * 6, math.sin(a) * r), 1)
			end
			local cols = { "mid", "accent", "white" }
			for i, c in cols do
				for _ = 1, fx:n(3) do
					local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * Rad * 0.75
					fx:emit(R.CONFETTI, cc + Vector3.new(math.cos(a) * r, 22 + math.random() * 6, math.sin(a) * r), 1,
						{ color = c, tag = "conf" .. i, accel = Vector3.new(0, -9, 0), speed = { 1, 4 } })
				end
			end
			fx:shake(0.6, 0.45)
			fx:flash("hi", 0.18, 0.55)
			fx:push(cc, 0.14, 0.5, 0.8, 1.0, 0.4)
		end)
		fx:extend(finale + 3.2)
	end,
}
