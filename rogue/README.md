# Peckwood Rogue prototype

Playable single-file build: `design/rogue-ui/peckwood-rogue-prototype.html` (built from `rogue/prototype/`).

| File | What |
|---|---|
| `prototype/data.js` | **All balance**: weapons (10, 8 levels, evolutions), tomes (15), items (15), enemies, biome rosters, the 30-minute event timeline, difficulties, characters, the meta shop |
| `prototype/game.js` | Systems: wave director, weapons, damage/items, enemy behaviours (chase, ranged, charge, split, flyers, bosses), pickups, chests, shrines, level-up (reroll/banish/skip), pause, end, title, Silver save |
| `prototype/engine.js` | Seeded chunk world generator + baked iso renderer (6 biomes, structures) |
| `prototype/head.html` | UI screens and CSS |
| `sim/sim.js` | Headless balance simulator: a kiting bot plays full runs at high speed and reports the death minute, level, build and what dealt the damage. `NODE_PATH=$(npm root -g) node rogue/sim/sim.js easy 1800 5` |

Build after editing: `python3 rogue/prototype/build.py`.

Last balance pass (bot, 5 runs each, 30-minute mode): Easy deaths at minutes 21–30, Medium 20–31, Hard 6–30. A human who dodges should clear Easy regularly.
