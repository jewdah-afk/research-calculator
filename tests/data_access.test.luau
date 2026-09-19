--!strict
-- Sim/DataAccess. docs/DATA_CONVENTIONS.md "null in the source becomes the
-- sentinel Module.UNKNOWN -- never 0"; docs/ARCHITECTURE.md rule 3: UNKNOWN is
-- substituted from Tuning.defaults, never `or 0`.
local T = require("./_harness")
local DataAccess = require("../src/shared/Sim/DataAccess")
local Tuning = require("../src/shared/Tuning")
local Weapons = require("../src/shared/Data/Weapons")

T.test("DA-01 DATA_CONVENTIONS.md: num(UNKNOWN, key) substitutes Tuning.defaults[key]", function()
	T.eq(DataAccess.num(Weapons.UNKNOWN, "weaponPierce"), Tuning.defaults.weaponPierce, "pierce default")
	T.eq(DataAccess.num(Weapons.UNKNOWN, "weaponDuration"), Tuning.defaults.weaponDuration, "duration default")
	T.eq(DataAccess.num(Weapons.UNKNOWN, "weaponCritChance"), Tuning.defaults.weaponCritChance, "crit default")
	T.eq(DataAccess.num(Weapons.UNKNOWN, "enemyKnockbackTaken"), Tuning.defaults.enemyKnockbackTaken, "kb default")
end)

T.test("DA-01 DATA_CONVENTIONS.md: real zeros and real numbers pass through untouched", function()
	T.eq(DataAccess.num(0, "weaponPierce"), 0, "zero stays zero")
	T.eq(DataAccess.num(5, "weaponPierce"), 5, "five stays five")
	T.eq(DataAccess.num(-0.5, "enemyKnockbackTaken"), -0.5, "negative stays")
	-- weapons.md L36: Garlic ships knockback 0 (a real zero, not UNKNOWN).
	T.eq(DataAccess.num(Weapons.data.garlic.knockback, "weaponKnockback"), 0, "garlic knockback 0")
end)

T.test("DA-01 ARCHITECTURE.md rule 3: an unregistered defaultKey is an error, never a guess", function()
	T.throws(function()
		DataAccess.num(Weapons.UNKNOWN, "noSuchKey")
	end, "unknown key")
end)

T.test("DA-01 DATA_CONVENTIONS.md: isUnknown is true only for the sentinel", function()
	T.eq(DataAccess.isUnknown(Weapons.UNKNOWN), true, "sentinel")
	T.eq(DataAccess.isUnknown(0), false, "zero")
	T.eq(DataAccess.isUnknown(nil), false, "nil")
	T.eq(DataAccess.isUnknown(false), false, "false")
	T.eq(DataAccess.isUnknown({}), false, "other table")
end)

T.test("DA-01 weapons.md L291-311: the shipped unknowns really are the sentinel", function()
	T.eq(DataAccess.isUnknown(Weapons.data.whip.pierce), true, "whip pierce")
	T.eq(DataAccess.isUnknown(Weapons.data.whip.duration), true, "whip duration")
	T.eq(DataAccess.isUnknown(Weapons.data.magic_wand.critChance), true, "wand crit")
	T.eq(DataAccess.isUnknown(Weapons.data.knife.knockback), false, "knife knockback is 0.5")
end)

return T.finish()
