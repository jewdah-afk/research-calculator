# Orb game – Luau balance core

Original Luau implementation of the rarity-orb idle game's mechanics and balance numbers.
UI, art, sounds, board geometry and saving are not included. Build them in Studio/Figma.

| File | What it is |
|---|---|
| `src/shared/OrbConfig.luau` | Every tuning number: rarities (odds, value, radius), upgrades, spawners, boosts, weather, tiers, skill tree, difficulties |
| `src/shared/OrbFormulas.luau` | Pure math: luck, rarity roll, variants, payouts, slot multipliers, rebirth cost, TP/QP, number formatting |
| `src/shared/Big.luau` | Wrapper around **EternityNum**. Place the EternityNum ModuleScript at `ReplicatedStorage.Modules.EternityNum` |
| `src/shared/OrbEconomy.luau` | Server-side state and actions (`newData`, `rollSpawn`, `collect`, `buyMain`, `rebirth`, `tier`, `buyBoost`, `rollWeather`, `buySkill`, …) |

## Wiring it up
- **Spawn loop:** each unlocked spawner `s` waits `data.spawnIntervals[s]` ms, then calls `Economy.rollSpawn(data, s, orbsOnBoard)` and drops what it returns at a random x between 50 and 350 and y = 30. The board is 400×800 and y increases downward, so rescale to your world.
- **Collection:** when `Formulas.isCollected(tier, x, y)` is true, call `Economy.collect(data, orb, x)` and destroy the orb.
- **Timers:** call `Economy.tickSecond(data, {onObstacleChange = rebuildBoard})` every second and `Economy.tickAutomation(data, dt)` every frame.
- **Duplicate boost (id 5):** after `buyBoost` succeeds, clone every orb on the board. The orb cap doesn't apply.
- **Obstacle remover (id 6):** rebuild the board while `Economy.obstaclesRemoved(data)` is true.
- **Board layouts:** these are level design. Build one board per tier (0–4); the source boards use peg grids, funnels and a deflector ball. Payouts only depend on the slot x-ranges in `OrbConfig.Tiers.Slots`.

## Quirks kept on purpose so the balance matches the original
Change any of these if you want the intended design instead:
1. Collected orbs get **no money from weather or MN-5**. Those multipliers only show in the original's UI.
2. Diamond orbs **ignore MN-3 and weather diamond multipliers**. The tier bonus is **added** (`+0.15 × tier`), not multiplied.
3. Diamonds get the slot multiplier only from Tier 1 up.
4. Tier 3 has **no unique slot table**: the original's branch for it is unreachable, so tiers 3 and 4 share the same slot multipliers. The tier-3 side pockets still collect orbs.
5. The weather unlock caps at **9 of 10**: Meteor Shower can never be unlocked.
6. Spawners 6 and 7 come only from skill SPW-1, which unlocks them for free.
7. AUTO-1 and AUTO-2 cost scaling is randomised once per save, between 1.8 and 1.9.

Left out: tutorial, statistics/history graphs and the BST-4 auto-potion (it's only a UI toggle in the source).

## Big numbers (EternityNum)
`money`, `totalMoney`, `diamonds`, `totalDiamonds`, `moneyMultiplier`, every money cost, the rebirth cost and TP costs are EternityNum values, used only through `Big`. Luck, odds and weather stay as plain numbers because the rarity table stops at 1e70.
- Display: `Formulas.format(x)` calls `EternityNum.short` for Big values.
- Saving: `Big.serialize(x)` returns a string for the DataStore, and `Big.deserialize(s)` turns it back.
- `Big` uses `add/sub/mul/div/pow/me/meeq/le/leeq/short/toString`. If your EternityNum build also has `convert`, `log10`, `floor`, `toNumber` or `fromString`, `Big` picks them up automatically and otherwise falls back.
