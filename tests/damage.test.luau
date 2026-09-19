--!strict
-- Sim/Damage. Oracle: research/vs/weapons.md L284-286 (innate crits, shipped
-- data authoritative over the Slash Arcana reading), passives_evolutions.md
-- L38 (Armor: "Reduces incoming Damage by 1"), enemies_waves.md L219-221
-- (knockback-taken multiplier; 0 = immune; the Reaper's -0.5 is negative).
local T = require("./_harness")
local Damage = require("../src/shared/Sim/Damage")
local Rng = require("../src/shared/Sim/Rng")
local Tuning = require("../src/shared/Tuning")

T.test("DMG-01 weapons.md L284: chance 0 never crits, returns (base, false)", function()
	local rng = Rng.new(11)
	for _ = 1, 100 do
		local dmg, crit = Damage.roll(10, 0, 1, rng)
		T.eq(dmg, 10, "damage")
		T.eq(crit, false, "crit flag")
	end
end)

T.test("DMG-01 weapons.md L286: chance 1 always crits at base x multiplier", function()
	local rng = Rng.new(12)
	for _ = 1, 100 do
		local dmg, crit = Damage.roll(10, 1, 3, rng)
		T.eq(dmg, 30, "damage")
		T.eq(crit, true, "crit flag")
	end
end)

T.test("DMG-01 weapons.md L31 (Knife 30% / 3x): crit fraction 0.30 +- 0.02 over 20000 rolls", function()
	local rng = Rng.new(2024)
	local crits = 0
	local n = 20000
	for _ = 1, n do
		local dmg, crit = Damage.roll(10, 0.3, 3, rng)
		if crit then
			crits += 1
			T.eq(dmg, 30, "crit value")
		else
			T.eq(dmg, 10, "non-crit value")
		end
	end
	local frac = crits / n
	T.truthy(math.abs(frac - 0.3) <= 0.02, "crit fraction " .. frac)
end)

T.test("DMG-01 weapons.md L29 (Whip 20% / 2x): crit fraction 0.20 +- 0.02", function()
	local rng = Rng.new(77)
	local crits = 0
	local n = 20000
	for _ = 1, n do
		local dmg, crit = Damage.roll(10, 0.2, 2, rng)
		if crit then
			crits += 1
			T.eq(dmg, 20, "crit value")
		end
	end
	local frac = crits / n
	T.truthy(math.abs(frac - 0.2) <= 0.02, "crit fraction " .. frac)
end)

T.test("DMG-02 passives_evolutions.md L38: armor subtracts 1 per point when power > armor", function()
	T.eq(Damage.toPlayer(10, 1), 9, "10 - 1")
	T.eq(Damage.toPlayer(20, 0), 20, "no armor")
	T.eq(Damage.toPlayer(65535, 5), 65530, "Reaper 65535 - 5 (core_loop.md L17)")
	T.eq(Damage.toPlayer(14, 5), 9, "werewolf 14 - 5")
end)

T.test("DMG-02 OQ-10: armor >= power never goes negative and floors at Tuning.contactDamageFloor", function()
	T.truthy(Damage.toPlayer(1, 5) >= 0, "never negative")
	T.truthy(Damage.toPlayer(5, 5) >= 0, "equal never negative")
	T.eq(Damage.toPlayer(1, 5), Tuning.contactDamageFloor, "floor constant")
	T.eq(Damage.toPlayer(0, 0), 0, "zero power")
end)

T.test("DMG-03 enemies_waves.md L219-221: knockback = weapon x enemy knockbackTaken", function()
	T.eq(Damage.knockback(0.5, 0.8), 0.4, "knife 0.5 x zombie 0.8")
	T.eq(Damage.knockback(0, 1), 0, "garlic 0 (weapons.md L36)")
	T.eq(Damage.knockback(1, 0), 0, "ghost immune (L286)")
	T.eq(Damage.knockback(1, -0.5), -0.5, "Reaper sign preserved (L299)")
	T.eq(Damage.knockback(1, 1), 1, "neutral")
end)

return T.finish()
