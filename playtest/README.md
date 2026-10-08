# Peckwood playtest (HTML/CSS copy of Birb's gameplay)

A plain HTML/CSS/JS copy of **Birb's** game rules with Peckwood's names and icons, so we can playtest the real structure and compare it with the Figma screens and the Roblox build.

- **Source of truth:** the live birbplay.com build (bundles `game-Cwl23x5W.js`, `editors-BtUaWY01.js`, `maps-CcKoUYtq.js`, pulled 2026-10-08). The code here is written fresh from that logic. Comments name the Birb function each part copies. No Birb code or art is included.
- **Big numbers:** `break_eternity.js` 2.1.2 (the same library Birb uses), loaded from jsDelivr.
- **Data:** `js/data.js` is generated from `birb-data/` by `python3 playtest/tools/build_data.py`. It holds the 160 upgrades and the sunflower-tree station layout (`tools/sunflower_stations.json`, the 134 station positions taken from Birb's `initSunflowerUpgradeStations`).

## Run it
Open `playtest/index.html` in a browser from the repo, so the icons at `../birb-icons/final/` resolve. It needs internet once, for the font and `break_eternity.js`. You can also serve the repo root (`python3 -m http.server`) and open `/playtest/`.

Controls: WASD or arrow keys, or click to move. E buys the sunflower station you are standing on. The side arrows travel between maps. The **DEV** tab has x10/x100/x1000 speed, give currency, export/import save and wipe. The **STATS** tab shows every live multiplier.

## Phase status
| Phase | Systems | State |
|---|---|---|
| 1 | Park field (spawn timer, cap, 6 egg types and their weights, pickup radius, magnet, Gravity Field), egg shop, Molt (Plume formula and reset), Plume keepsakes, seed shop, sunflower platform and seed ticks, the walkable sunflower tree (134 stations, parent/chain/visibility rules), Sparrow (egg collecting on the Park while you're away, XP by egg type, seed feeder, resonance drain, mitosis, rebirb, milestones, autos), Castle (feeding 10%/s, requirements per evolution, evolution reset and what it keeps) | **Done** |
| 2 | Bridge and fishing: casting, 426 fish rolls, rods, bait, hooks, lures, Moneta, fish buffs, aquarium, fish market, Seagull | Next. Evolution 2 needs 1,000 Moneta, so this is the blocker |
| 3 | Nest and forest: twigs, trees, nest tiers, cultivation, riverside, carpentry, Red Panda | Later |
| 4 | Mine and crow: ores, areas, giants, coffers, mine tree, crow rebirbs, forge | Later |
| 5 | Desert: golden eggs, sandstorm, desert tree, Dave | Later |
| 6 | Expedition: Parrot combat, floors, enemies, gear, artifacts, chests, quests, sacrifice | Later |
| 7 | Echo field and archivist tree | Later |

Not copied on purpose: multiplayer, chat, Steam achievements, hats, tutorials and dialogue, sounds. Offline earnings come with the Red Panda phase.

See `DIFFERENCES.md` for every place where our Roblox/Figma build differs from Birb's structure.
