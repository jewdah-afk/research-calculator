# birb-data

Formulas and balance data for the Roblox remake of Birb. Everything here was taken from the live web build at birbplay.com, pulled on 2026-10-06.

| File | What it is |
|---|---|
| `CORE_FORMULAS.md` | The core loop: upgrade costs, popcorn spawning and odds, popcorn value, golden popcorn, and rebirb feathers |
| `SYSTEMS.md` | Every other system: mining and the crow, the nest (twigs, cultivation, carpentry), fishing, Sparrow, Seagull, Dave, Red Panda, evolution, Parrot combat and enemies, equipment, sacrifice, the Quest Merchant, and the Echo field |
| `UPGRADES.md` / `upgrades.json` | All 160 shop and tree upgrades, with currency, base cost, growth, max level and effect |
| `data/*.json` | Raw game tables: fish (426), rods, baits, artifacts (47), enemy base stats (43), enemy type modifiers, sacrifice milestones, and quests (33) |
| `BirbFormulas.luau` | Luau port of the core loop |
| `BirbSystems.luau` | Luau port of the system formulas: mining, nest, companions, fishing, enemies, equipment, evolution and echo |

## How it was checked

Each Luau module was run against the game's own functions, copied word for word out of the bundles:

- **`BirbFormulas.cost`:** 4,960 values (every upgrade at levels 0–30). All match exactly.
- **`BirbSystems`:** 3,347 values. All match.
  - Mine costs (levels 1–200), ore and giant HP, rewards and XP (areas 0–20), and mine node costs.
  - Nest twig, peck, tree-box and carpentry costs.
  - Parrot and Seagull XP curves.
  - Every enemy type on floors 1–12, normal and boss.

## Not covered

- **Rendering, animation and multiplayer code.** These aren't game balance.
- **Per-enemy attack patterns.** Those are AI behavior, not stats.
- **The aquarium.** Its modifier table is used through `getModifierMultiplier`, but the table itself isn't exported.
- **Artifact infusion caps.** These come from the wiki and weren't checked against the code.

## Note for Roblox

The original game uses big-number math. Roblox numbers top out around 1.8e308, so late-game values may need a big-number library.
