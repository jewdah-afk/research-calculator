--!strict
-- GATE-05 docs/ARCHITECTURE.md rule 1: every Sim module is pure Luau and loads
-- under the plain luau CLI (no Roblox globals, no yields).
local T = require("./_harness")

local modules: { [string]: any } = {
	Rng = require("../src/shared/Sim/Rng"),
	DataAccess = require("../src/shared/Sim/DataAccess"),
	Stats = require("../src/shared/Sim/Stats"),
	Experience = require("../src/shared/Sim/Experience"),
	WeaponLevels = require("../src/shared/Sim/WeaponLevels"),
	Damage = require("../src/shared/Sim/Damage"),
	LevelUp = require("../src/shared/Sim/LevelUp"),
	Chests = require("../src/shared/Sim/Chests"),
	Pickups = require("../src/shared/Sim/Pickups"),
	Waves = require("../src/shared/Sim/Waves"),
	EnemyStats = require("../src/shared/Sim/EnemyStats"),
}

T.test("GATE-05 ARCHITECTURE.md: all 11 Sim modules load headless and export tables", function()
	local n = 0
	for name, m in modules do
		T.eq(type(m), "table", name)
		n += 1
	end
	T.eq(n, 11, "module count")
end)

return T.finish()
