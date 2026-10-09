--!nonstrict
-- Save migration check (lune): a v2 save (the pre-port shape) loads into v3 with every Phase 1 field carried over,
-- and a v3 save survives serialize -> deserialize unchanged. Run from roblox/:  lune run tools/parity/migration_check.luau
local G = require("../../src/server/Game")
local EN = G.R.EN
local fails = 0
local function check(name, ok)
	if not ok then fails += 1; print("FAIL " .. name) end
end

-- a v2 save as the old Game.serialize wrote it
local v2 = {
	v = 2, upgrades = { p_value = 40, pr_popcorn_mult = 3, s_more_seeds = 5, d_desert_field_notes_plus = 2, n_twig_value = 7 },
	owned = { d_unlock_evolve = true, d_sunflower_machine = true, d_desert_auric_blueprints = true },
	rebirbCount = 6, evolutionCount = 2, island = 6,
	stats = { totalPopcorn = 1234, bestPopcorn = 999, fishCaught = 12, kills = 0, questsDone = 0, playTime = 3600, goldenCollected = 0 },
	zone = "park", evo = { fed = { popcorn = 5e9, sunflowerSeeds = 1e6, moneta = 300 } },
	sparrow = { level = 33, xp = 12.5, count = 4, rebirbs = 1, resonance = 2500, draining = true, mitosisXp = 99, autoMitosis = true },
	popcorn = EN.toString(EN.fromNumber(2e9)), goldenFeathers = EN.toString(EN.fromNumber(5e4)), sunflowerSeeds = EN.toString(EN.fromNumber(7e5)),
	moneta = EN.toString(EN.fromNumber(10)),
}
local s = G.deserialize(v2)
check("version", s.v == 3)
check("owned -> sunflowerUpgrades", s.sunflowerUpgrades.d_unlock_evolve == 1 and s.sunflowerUpgrades.d_sunflower_machine == 1 and s.owned == nil)
check("gilded margins moved", s.sunflowerUpgrades.d_desert_field_notes_plus == 2 and s.upgrades.d_desert_field_notes_plus == nil)
check("upgrades kept", s.upgrades.p_value == 40 and s.upgrades.n_twig_value == 7)
local sp = s.sparrow
check("sparrow", sp.unlocked == true and sp.level == 33 and sp.xp == 12.5 and sp.count == 4 and sp.prestigeCount == 1
	and sp.resonanceXP == 2500 and sp.draining == true and sp.autoMitosis == true and sp.feedRatePercent == 25 and sp.feeding == false)
check("castle fed", s.evo.fed.popcorn == 5e9 and s.evo.fed.seeds == 1e6 and s.evo.fed.moneta == 300 and s.evo.fed.feathers == 0 and s.evo.talked == true)
check("castle progress", math.abs(s.evo.progress - G.R.feedProgress(s)) < 1e-9)
check("hasUnlockedEvolve", s.hasUnlockedEvolve == true)
check("wallet", EN.toNumber(s.popcorn) == 2e9 and EN.toNumber(s.goldenFeathers) == 5e4 and EN.toNumber(s.moneta) == 10)
check("rules read it", G.R.level(s, "p_value") == 40 and G.R.hasSun(s, "d_unlock_evolve"))

-- v3 round trip
local s2 = G.deserialize(G.serialize(s))
check("round trip sparrow", s2.sparrow.level == 33 and s2.sparrow.prestigeCount == 1)
check("round trip tree", s2.sunflowerUpgrades.d_sunflower_machine == 1)
check("round trip wallet", EN.eq(s2.popcorn, s.popcorn))
-- an unknown / older version starts fresh
check("unknown version", G.deserialize({ v = 1 }).rebirbCount == 0)

print(if fails == 0 then "migration: OK (v2 -> v3, v3 round trip)" else ("migration: " .. fails .. " FAILED"))
if fails > 0 then (require("@lune/process") :: any).exit(1) end
