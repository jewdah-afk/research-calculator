--!nonstrict
-- CLI entry for the QA suite (built into tests/.build by run.sh).
local Shared = {
	OrbConfig = require("./OrbConfig"),
	Progression = require("./Progression"),
	Big = require("./Big"),
	Balance = require("./Balance"),
	Events = require("./Events"),
	OrbFormulas = require("./OrbFormulas"),
	OrbEconomy = require("./OrbEconomy"),
	Tutorial = require("./Tutorial"),
	Prestige = require("./Prestige"),
}
local tiers = tonumber((...)) or 30

local unit = require("./UnitTests")(Shared)
print(string.format("UNIT  %d passed, %d failed", unit.passed, #unit.failed))
for _, f in unit.failed do
	print("  FAIL " .. f)
end

local t0 = os.clock()
local sim = require("./PacingSim")(Shared, { tiers = tiers })
print(string.format("PACING  reached tier %d in %.1f h of game time (%.1fs to simulate)", sim.final.tiers, sim.hours, os.clock() - t0))
local line = {}
for t = 1, sim.final.tiers do
	table.insert(line, string.format("T%d %.0fm", t, sim.tierTimes[t] or 0))
	if #line == 8 then
		print("  " .. table.concat(line, "  "))
		line = {}
	end
end
if #line > 0 then
	print("  " .. table.concat(line, "  "))
end
print(string.format("  final: rebirths %d, luck 10^%.1f, best rarity #%d (%s)", sim.final.rebirths, sim.final.totalLuckLog, sim.final.highestRarity, Shared.Progression.Rarities[math.max(sim.final.highestRarity, 1)].name))
for _, f in sim.fails do
	print("  FAIL " .. f)
end

if #unit.failed > 0 or not sim.ok then
	error("QA FAILED", 0)
end
print("QA PASSED")
