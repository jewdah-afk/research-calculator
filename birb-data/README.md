# birb-data

Formulas and balance data for the Roblox remake of Birb. Everything here was taken from the live web build at birbplay.com, pulled on 2026-10-06.

| File | What it is |
|---|---|
| `CORE_FORMULAS.md` | The core loop with exact formulas: cost curves, popcorn spawning and type odds, popcorn value, golden popcorn, and rebirb feathers |
| `UPGRADES.md` | Readable table of all 160 upgrades, with currency, base cost, growth, max level and effect |
| `upgrades.json` | The same upgrade data in machine-readable form. Load it in Roblox as the source of truth |
| `BirbFormulas.luau` | Luau port of the core formulas, ready to drop into a ModuleScript |

**How it was checked:** `BirbFormulas.cost` was compared against the game's own cost function for every upgrade at levels 0–30. All 4,960 values match exactly.

**Not covered yet:** mining curves, the nest, fishing and companion XP, combat and evolution bosses, expeditions, and the Echo field. `CORE_FORMULAS.md` §7 lists them.

**Note for Roblox:** the original game uses big-number math. Roblox numbers top out around 1.8e308, so late-game values may need a big-number library.
