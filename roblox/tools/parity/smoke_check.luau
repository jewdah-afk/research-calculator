--!nonstrict
-- Smoke check (lune): the whole server step (Phase 1 + the later, still simplified systems) runs without errors on a
-- fresh save, on every NEXT AREA dev save and on MAXED, with the actions the UI sends. Catches nil fields after
-- state-shape changes. Run from roblox/:  lune run tools/parity/smoke_check.luau
local G = require("../../src/server/Game")
local R, Park = G.R, G.Park

local seed = 12345
local function u() seed = (seed * 48271) % 2147483647; return seed / 2147483647 end
local rng = { NextNumber = function(_, a, b) if a then return a + (b - a) * u() end; return u() end,
	NextInteger = function(_, a, b) return a + math.floor(u() * (b - a + 1)) end }

local function run(name, s, steps)
	local rt = G.newRuntime(Park.BIRB_GEOM, { type = u, pos = u, sparrow = u })
	rt.events = {}
	local ok, err = pcall(function()
		for i = 1, steps do
			rt.map = if i % 400 < 200 then 0 elseif i % 400 < 300 then 1 else 3
			rt.onPlatform = rt.map == 1
			rt.holdFeed = rt.map == 3
			s.evo.talked = true
			G.step(s, 0.05, rng, rt)
			if i % 50 == 0 then
				for _, id in { "p_value", "p_speed", "p_capacity", "pr_popcorn_mult", "s_more_seeds", "n_twig_value", "m_mining_power", "d_desert_field_notes_plus" } do G.buy(s, id, true) end
				for _, n in R.Data.SUN do if R.sunVisible(s, n.id) then G.buySun(s, n.id) end end
				G.molt(s, rt); G.mitosis(s); G.sparrowRebirb(s); G.evolve(s, rt)
				s.sparrow.feeding = not s.sparrow.feeding
			end
			table.clear(rt.events)
		end
		G.serialize(s)
		G.plumeGain(s); G.seedsPerSec(s, true); G.evoProgress(s); G.reachPx(s); G.speed(s); G.goldenValue(s); G.orePerSec(s)
	end)
	if not ok then print("FAIL " .. name .. ": " .. tostring(err)); return false end
	return true
end

local good = 0
local total = 0
local function t(name, s, steps) total += 1; if run(name, s, steps) then good += 1 end end
t("fresh", G.fresh(), 4000)
local s = G.fresh()
for i = 1, #G.Defs.ISLANDS do
	s = G.stepIsland(s)
	t("next area " .. i, G.clone(s), 600)
end
t("maxed", G.maxed(), 1500)
print(string.format("smoke: %d / %d saves stepped without errors", good, total))
if good ~= total then (require("@lune/process") :: any).exit(1) end
