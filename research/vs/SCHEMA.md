# Shared JSON schema conventions for /research/vs/

All agents MUST follow these rules so the JSON can be converted to Luau ModuleScripts.

## General
- All keys camelCase. No spaces, no hyphens.
- All numeric values are JSON numbers, never strings. No units inside values ("10" not "10s", 1.15 not "+15%").
- Percentages are stored as multipliers where the game treats them as multipliers (e.g. +15% Might -> `might: 1.15`),
  and as fractional deltas where the game treats them as additive bonuses (e.g. `mightBonus: 0.15`).
  State which convention you used in a `notes` field.
- Unknown / not found = `null` (never 0, never a guess). Add an entry to the file's `unknowns` array.
- Every top-level file has:
  ```
  {
    "schemaVersion": 1,
    "game": "Vampire Survivors",
    "scope": "base game (no DLC)",
    "sources": [{"id": "official-wiki", "url": "https://vampire.survivors.wiki/...", "retrieved": "2026-09-19"}],
    "conflicts": [{"field": "...", "values": [...], "sourceIds": [...], "note": "..."}],
    "unknowns": ["dotted.path.to.field"],
    "data": { ... }
  }
  ```
- Every record that came from a specific page carries `"sourceIds": ["official-wiki"]`.

## Canonical stat key names (use these EXACTLY everywhere)
maxHealth, recovery, armor, moveSpeed, might, area, speed, duration, amount, cooldown, luck, growth, greed, magnet, revival, curse

## Canonical weapon/item keys
name, id (snake_case lowercase of name), baseDamage, area, speed, amount, duration, cooldown, pierce, knockback,
poolLimit, critMultiplier, critChance, targeting, maxLevel, levels (array of {level, changes:{}, description})

## Canonical character keys
name, id, startingWeaponId, unlockCondition, unlockCost, baseStats:{<stat keys above>}, levelBonuses:[{level, stat, value}], passiveAbility

## Canonical enemy keys
name, id, health, power, speed, knockbackResistance, xpDropped, isBoss, notes

## Time
All in-run times in SECONDS as numbers (e.g. 10:00 -> 600).
