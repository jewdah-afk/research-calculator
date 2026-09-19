--!strict
--[[
	Sim/Damage.luau -- crit rolls, contact damage after armor, knockback.

	Oracle:
	  * Crit is INNATE to the weapon (weapons.md, Conflicts: shipped data gives
	    Whip 20%/2x, Axe 30%/2x, Knife 30%/3x as base weapon properties; the
	    wiki's 4x-via-Arcana figures are the non-authoritative side, see
	    SUMMARY.md conflict #2). The chance and multiplier are therefore
	    passed in from the weapon's stats, never held here.
	  * Armor: "Reduces incoming Damage by 1" per point
	    (passives_evolutions.md §1, Armor). Contact damage = power - armor.
	  * Knockback: the shipped per-enemy field is knockback TAKEN (higher =
	    knocked further, 0 = immune, Reaper -0.5; enemies_waves.md caveat),
	    so it multiplies the weapon's knockback and its sign is preserved.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.

	Types: src/shared/Types.luau returns nil, which the plain `luau` CLI
	refuses to require, so the Rng alias below restates Types.Rng
	structurally. Keep it byte-for-byte in step with Types.luau.
]]

local Tuning = require("../Tuning")

-- Mirrors Types.Rng.
export type Rng = {
	next: (self: Rng) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
}

local Damage = {}

-- Rolls one hit. Crit with probability critChance (0..1) multiplies the base
-- by critMultiplier. Returns (damage, wasCrit).
function Damage.roll(base: number, critChance: number, critMultiplier: number, rng: Rng): (number, boolean)
	if rng:chance(critChance) then
		return base * critMultiplier, true
	end
	return base, false
end

-- Damage the player takes from an enemy of the given power: power minus one
-- per armor point, never below Tuning.contactDamageFloor (the floor when
-- armor >= power is open question OQ-10; the research does not state it).
function Damage.toPlayer(power: number, armor: number): number
	return math.max(Tuning.contactDamageFloor, power - armor)
end

-- Knockback applied to an enemy: the weapon's knockback times the enemy's
-- knockback-taken multiplier. 0 on either side means none.
function Damage.knockback(weaponKnockback: number, enemyKnockbackTaken: number): number
	return weaponKnockback * enemyKnockbackTaken
end

return Damage
