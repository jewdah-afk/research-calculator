# Peckwood playtest (HTML/CSS copy of Birb's gameplay)

A plain HTML/CSS/JS copy of **Birb's** game rules with Peckwood's names and icons, so we can playtest the real structure and compare it with the Figma screens and the Roblox build.

- **Source of truth:** the live birbplay.com build (bundles `game-Cwl23x5W.js`, `editors-BtUaWY01.js`, `maps-CcKoUYtq.js`, pulled 2026-10-08). The code here is written fresh from that logic. Comments name the Birb function each part copies. No Birb code or art is included.
- **Big numbers:** `break_eternity.js` 2.1.2 (the same library Birb uses), loaded from jsDelivr.
- **Data:** `js/data.js` is generated from `birb-data/` by `python3 playtest/tools/build_data.py`. It holds the 160 upgrades and the sunflower-tree station layout (`tools/sunflower_stations.json`, the 134 station positions taken from Birb's `initSunflowerUpgradeStations`).

## Run it
Open `playtest/index.html` in a browser from the repo, so the icons at `../birb-icons/final/` resolve. It needs internet once, for the font and `break_eternity.js`. You can also serve the repo root (`python3 -m http.server`) and open `/playtest/`.

Controls: WASD or arrow keys, or click to move. E buys the sunflower station you are standing on. The side arrows travel between maps. The **DEV** tab has x10/x100/x1000 speed, give currency, export/import save and wipe. The **STATS** tab shows every live multiplier.

## Parity test against the real Birb

`parity/parity.js` opens Birb's live game (birbplay.com exposes its engine as `window.game`) and the playtest side by side, loads the same save state into both (`parity/scenarios.js`), and compares every formula both expose: each upgrade's level, max, effect and cost, egg cap, spawn interval, egg multiplier, Molt plumes, playtime and payout multipliers, pickup radius, fish multipliers, sparrow XP, and every sunflower node's unlocked/visible/cost. Results go to `parity/REPORT.md`.

```
NODE_PATH=/opt/node-tools/node_modules node playtest/parity/parity.js
```

Add a scenario to `scenarios.js` for any point in progression you want to check. The same states can be loaded into the Roblox build to compare it with both.

`parity/birb_ui.js`, `parity/birb_windows.js` and the per-area scripts (`birb_aquarium.js`, `birb_nest.js`, `birb_mine.js`, `birb_desert.js`) screenshot Birb's real screens (every map and drawer tab, the companion, fishing, aquarium and fast travel windows, the castle) for a scenario into `parity/birb_ui/`. The playtest layout copies them: wallet stack top-left, map arrows with the next map's name, COMPANIONS [TAB] and AUTO top-right, fishing level bar and the [SPACE] CAST hotbar on the Bridge, utility buttons bottom-right, satisfaction + HOLD TO FEED over the castle map, and the shop drawer with EGGS / MOLT / SEEDS tabs (Birb: POPCORN / REBIRB / SEEDS / MINE).

## Phase status
| Phase | Systems | State |
|---|---|---|
| 1 | Park field (spawn timer, cap, 6 egg types and their weights, pickup radius, magnet, Gravity Field), egg shop, Molt (Plume formula and reset), Plume keepsakes, seed shop, sunflower platform and seed ticks, the walkable sunflower tree (134 stations, parent/chain/visibility rules), Sparrow (egg collecting on the Park while you're away, XP by egg type, seed feeder, resonance drain, mitosis, rebirb, milestones, autos), Castle (feeding 10%/s, requirements per evolution, evolution reset and what it keeps) | **Done** |
| 2 | Bridge and fishing: casting and reeling, fish rolls (tier, bait type, hooks, lures, shiny chance and pity), fish weights and records, rods crafted with fish, bait/hooks/lures, Moneta, fish buffs (eat), fishing XP and levels, auto fishing, sell safe for seeds, castle gate, Seagull (gulls, doctrines, hourly forecast, migrations, frenzy) | **Done** (aquarium and fish market move to Phase 2b) |
| 2b | Aquarium (Evolution 5, down from the Bridge): 9 biomes with completion tiers and stat bonuses, resonance points, 8 milestones (extra buff slot, shiny chance, longer shiny buffs, normal buffs x1.25, market, rerolls), donate / donate shiny / donate all, shiny chance from donated shinies' weights. Fish Market (700 resonance): seeded daily contracts, reputation ranks, accepted and active-buff slots, rerolls, abandon cooldown, timed buffs for fishing speed, XP, luck and shiny chance | **Done** (contract offers match Birb roll for roll) |
| 3 | Nest (Evolution 3, left of the Park): forest of 30 trees (12 hits each, one every 30 s, 3 min to grow), pecking with Twig Value / Pecking Rhythm / Pecking Power, chain falls, auto collect, build bar per nest level (1e5, 1e6, 1e8, 2e10; levels rise on Evolution 4, 5, 6), planting beds (16 boxes → double → quad, expansions), Fertilizer, Specialized Fertilizer, Grain Silo, Cornfield, Sunflower Field, Watering Well, auto egg / seed upgrades at nest level 3, nest interior with the Red Panda (HELP chops trees, also offline up to 8 h; NAP gives eggs and seeds x1.25), fish breeding (Lineage Lake: odds, shiny lineage, fishing speeds up hatching, fuse, active hybrid bonus) | **Done**. Riverside and the sawmill need Evolution 6 and come with the Expedition phase |
| 3b | Riverside (pollinator, wood workshop, compost, grove, nursery) and the sawmill (carpentry) | With Phase 6 |
| 4 | Mine (Birb opens it from the Expedition floor-1 secret room at Parrot Rebirb II + maxed gear; Settings can open it until Phase 6): one ore at a time, 7 tiers x 5 rarities with roll tables, drought guarantees and survey intervals, golden ores and the gold vein, area HP / value / giant formulas, area milestones (+4% damage and Brute Ore), giants (60 s fight, 60 s rest, area up, Brute + first-kill Gold), the Crow (auto-mines everywhere, XP and levels, training speed, rebirbs with level + giant gates), charged pecks, impact transfer, coffers, echo, Mine shop (real Birb costs and effects), the 23-node mine tree in the Treasure Room, evolution reset | **Done**. Metal Drain / forge metalwork is switched off in Birb itself, so it is not copied |
| 5 | Desert (map 9, up from the Park once the Legendary Key opens the desert tree; side arrows to the Nest and the Sunflower Field): its own field of plain / golden eggs (5% with Desert Core, +2.5% per chance node), Golden Eggs per drop with every desert multiplier, Desert Fever, Bloom Netting, Dune Bloom, Bountiful / Feathered Harvest, caramelized golden (Gourmet), sandstorm (30 s, 14 min cooldown, every egg golden, Golden Sand x3), golden shop switch in the EGGS tab, golden auto-buy at nest level 3 / Evolution 6, Dave (forages the desert in clustered swoops, also while you are away; sons at 10 and 75 rebirbs; XP per egg; Seed Snacks; rebirb into Travel / Forage / Gilded with reset and x1 / x10 / MAX; 8 milestones; auto rebirb) | **Done** |
| 6 | Expedition: Parrot combat, floors, enemies, gear, artifacts, chests, quests, sacrifice | Later |
| 7 | Echo field and archivist tree | Later |

Not copied on purpose: multiplayer, chat, Steam achievements, hats, tutorials and dialogue, sounds. Offline earnings come with the Red Panda phase.

See `DIFFERENCES.md` for every place where our Roblox/Figma build differs from Birb's structure.
