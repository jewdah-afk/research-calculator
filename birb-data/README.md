# birb-data

Formulas and balance data for the Roblox remake of Birb. Everything here was taken from the live web build at birbplay.com, pulled on 2026-10-06.

| File | What it is |
|---|---|
| `CORE_FORMULAS.md` | The core loop: upgrade costs, popcorn spawning and odds, popcorn value, golden popcorn, and rebirb feathers |
| `SYSTEMS.md` | Every other system: mining and the crow, the nest (twigs, cultivation, carpentry), fishing, Sparrow, Seagull, Dave, Red Panda, evolution, Parrot combat and enemies, equipment, sacrifice, the Quest Merchant, and the Echo field |
| `UPGRADES.md` / `upgrades.json` | All 160 shop and tree upgrades, with currency, base cost, growth, max level and effect |
| `data/*.json` | Raw game tables: fish (426), rods, baits, artifacts (47), enemy base stats (43), enemy type modifiers, sacrifice milestones, and quests (33) |
| `EternityNum.luau` | Big-number library. Same `{sign, layer, mag}` layout and function names as FoundForces' EternityNum, with break_eternity's math. Adds fast paths for plain numbers, closed-form buy-all helpers, HUD suffix formatting, lossless save strings, and a leaderboard encoder |
| `BirbFormulas.luau` | Luau port of the core loop. Currency balances are EternityNum values; also includes `buy` and `buyAll` |
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

- **`EternityNum.luau`:** 22,629 operations compared against break_eternity.js 2.x (add, sub, mul, div, pow, pow10, log10, ln, sqrt, exp, floor, ceil, cmp), with inputs spanning layers 0–3. Every result's sign, layer and mag match. Also tested: buy-all closed form against a loop, save round-trips, and leaderboard encoding order.

## How to use it in Roblox

1. Put `EternityNum`, `BirbFormulas` and `BirbSystems` as ModuleScripts in the same folder. `BirbFormulas` requires `script.Parent.EternityNum`.
2. Store currencies as EN values. Save them with `EN.toString(x)` and load them with `EN.fromSave(str)`. For an OrderedDataStore leaderboard, store `EN.lbencode(x)`.
3. Costs come back as plain numbers, as in the original. Compare balances against costs with `EN.meeq(balance, cost)`.

**Note on level display:** your Peckwood shop shows the internal level minus 1. Popcorn Value internal level 4 shows as "LV 3 / 998", and Wing Training internal level 20 shows as "LV 19 / 19". The formulas here use internal levels, so subtract 1 when displaying.
