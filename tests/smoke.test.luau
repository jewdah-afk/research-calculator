--!strict
-- Proves the harness runs and that the generated data modules load headlessly.
local T = require("./_harness")
local Weapons = require("../src/shared/Data/Weapons")
local CoreLoop = require("../src/shared/Data/CoreLoop")

T.test("data modules load under plain luau", function()
	T.eq(Weapons.data.whip.baseDamage, 10, "whip baseDamage")
	T.eq(#Weapons.data.whip.levels, 8, "whip has 8 level entries")
	T.truthy(CoreLoop.data, "core loop data present")
end)

T.test("UNKNOWN sentinel is distinguishable from 0 and nil", function()
	T.truthy(Weapons.UNKNOWN ~= nil, "not nil")
	T.truthy(Weapons.UNKNOWN ~= 0, "not zero")
	T.eq(tostring(Weapons.UNKNOWN), "UNKNOWN", "tostring")
end)

return T.finish()
