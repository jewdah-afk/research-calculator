# Peckwood parity harness (playtest vs Game.luau)

Holds Peckwood's Luau game logic to the playtest (`playtest/js`), which itself matches Birb's live engine on
80,461 / 80,461 values. Every phase ported into Roblox must reach 100% here before it ships.

## Run it (one command)

```
node roblox/tools/parity/run.js
```

From anywhere in the repo. Needs node 18+ and lune (rokit: `~/.rokit/bin/lune`, run.js finds it and runs it from
`roblox/` so the rokit manifest resolves). About 1.5 minutes: the playtest side runs the playtest's real loop for
every simulated second; the Lua side takes under a second. Exit code 0 = the Phase 1 gate is 100%.

`ONLY="p1 sparrow" node roblox/tools/parity/run.js` runs a subset (scenario name substring); REPORT.md then covers
only that subset, so run the full set before committing.

Output: `REPORT.md` (pass count, per-scenario table, every mismatch) and `out/*.json` (git-ignored).

## What runs

| Step | File | What it does |
|---|---|---|
| 1 | `gen_data.js` | Regenerates `roblox/src/shared/Birb/Data.luau` from the playtest's runtime tables: the 19 leveled upgrades, all 163 tree nodes with their effective gates (data.js merged with archivist_data.js), each node's parents and all-parents rule, the 134 sunflower-field stations. Numbers and structure only. |
| 2 | `playtest_dump.js` | Loads the playtest headless (`headless.js`: node `vm`, `vendor/break_eternity.js` 2.1.2, a do-nothing DOM stub so `main.js` loads; one line appended in memory hands out its private `step`). Per scenario it dumps (a) every value `playtest/parity/parity.js` compares, using parity.js's own `probe` read at run time, (b) extra Phase 1 values (`p1 ...`), (c) for Phase 1 scenarios a simulated run (`sim <tag> ...`) driven through the playtest's own `step`. Writes `out/playtest.json` and `out/scenarios.json`. |
| 3 | `lua_dump.luau` | Lune. Requires `roblox/src/server/Game.luau` (and through it `Systems/*`, `shared/Birb/*`, `Defs`), maps each scenario's Birb save into Peckwood's save (below), computes the same keys and runs the same programs through `Game.stepPhase1`. Writes `out/lua.json`. |
| 4 | `compare.js` | Diffs the two and writes `REPORT.md`. |

Scenarios: the 61 in `playtest/parity/scenarios.js` (Birb save shape, the same states parity.js loads into Birb)
plus the Phase 1 ones in `p1_scenarios.js` (types and limit breakers, free seeds, sparrow flock / rebirb, castle
feeding and evolutions, Gravity Field, a fresh run). Each Phase 1 scenario gets an action program
(`p1_scenarios.js` lists the ops: wait, walk onto eggs, buy, MAX, Molt, tree nodes, seed platform, sparrow feeder /
drain / mitosis / rebirb / autos, castle talk / hold / evolve, grants, snapshots).

## Comparing

- Numbers: relative tolerance 1e-9, `|a - b| <= 1e-9 * max(1, |a|, |b|)`.
- Big values: both sides write a plain number while it fits a double, else `{ L = log10, s = sign }`
  (break_eternity / EternityNum mantissa and exponent); compared on sign + log10 with the same tolerance.
- Booleans and strings: equal.
- Randomness: the playtest's `Math.random` is split into three seeded Park-Miller streams (egg type rolls, egg spots,
  sparrow wander; everything else draws from a fourth). The Lua side feeds the same streams to `rt.rng.type / pos /
  sparrow`. Products stay below 2^53, so both languages produce the same doubles. Sparrow flight uses a port of V8's
  `Math.hypot` so positions round the same way.

### The Phase 1 gate

Every key belongs to a phase (`compare.js` `phaseOf`). The gate is:
- every Phase 1 key in every Phase 1 scenario (the playtest's 7 Phase 1 saves + `p1 *`), including the simulated runs;
- the Phase 1 keys that only read state (every sunflower / desert tree node's unlocked / visible / cost, egg cap, the
  shop rows' level / max / effect / cost, playtime, can evolve, the sparrow XP table) in all 70 scenarios.

Phase 1 values in later-phase scenarios that multiply in a later system (fish buffs, nest, sacrifice, quests, red
panda, ...) are listed as "blocked by later systems": they turn green as those phases are ported. Later-phase keys
are counted per phase ("Produced by Lua" = how many the Luau side already computes).

## Birb save -> Peckwood save (the scenario mapping, `lua_dump.luau` `fromBirb`)

| Birb (playtest) | Peckwood v3 save |
|---|---|
| `resources.<cur>` | `s.<cur>` (EternityNum); `monetariaMoneta` -> `s.moneta`; non-wallet currencies (wood) are dropped |
| `upgrades`, `sunflowerUpgrades` | `s.upgrades`, `s.sunflowerUpgrades` (same id -> level maps) |
| `rebirthCount`, `evolutionCount` | `s.rebirbCount`, `s.evolutionCount` |
| `playTime`, `totalFishCaught`, `totalPopcornCollected` | `s.stats.playTime`, `s.stats.fishCaught`, `s.stats.totalPopcorn` |
| `sparrow.{unlocked, level, xp, maxLevelReached}` | `s.sparrow.*` |
| `sparrowCount`, `sparrowPrestigeCount`, `sparrowResonanceXP`, `sparrowTotalEnergyDrained`, `sparrowSeedFeedRatePercent` | `s.sparrow.count`, `prestigeCount`, `resonanceXP`, `totalEnergyDrained`, `feedRatePercent` |
| `isFeedingSparrow`, `isDrainingSparrow`, `sparrowAutoMitosisEnabled`, `sparrowAutoRebirbEnabled` | `s.sparrow.feeding`, `draining`, `autoMitosis`, `autoRebirb` |
| `monster{Popcorn,Feathers,Seeds,Fish,Twigs,Moneta}Fed`, `monsterFeedProgress`, `hasTalkedToMonster` | `s.evo.fed.{popcorn,feathers,seeds,fish,twigs,moneta}`, `s.evo.progress`, `s.evo.talked` |
| `hasUnlockedEvolve`, `hasEnteredDungeon`, `hasUnlockedDesertMap` | same names |
| `nest.tier`, `mine.highestArea`, `parrot.rebirbCount` / `strangeKeys`, `expedition.hasRescuedCastleMonster` | `s.nest.tier`, `s.crow.area`, `s.parrot.*`, `s.expedition.*` (read by the tree gates and the evolution cap) |
| `currentMap`, `player.{x,y}` | runtime only: `rt.map`, `rt.player` (Birb field px), `rt.onPlatform` |

Geometry: the harness runs the field in Birb's own box (`Park.BIRB_GEOM`: 1056 x 792 px, 40 px margin, centre
528, 396). In game, Main passes Peckwood's Park (the fenced egg yard's bounding box in MapData px, a spawnOk test
per yard tile and a fallback spot), so spawn spots and sparrow flights differ by map only; the rules, timers, rolls,
radii (Birb px; studs = px / Map.PX * S) and every number are the same code.

## Adding to it (next phases)

1. Port the system into `roblox/src/server/Systems/` (pure Luau, requires through the `script` / string-path pattern
   so lune can load it) and its formulas into `shared/Birb/Rules.luau` or a sibling module.
2. Emit the playtest's keys for it in `lua_dump.luau` (parity.js already dumps them on the playtest side; extra values
   go in `playtest_dump.js` `p1Values` style).
3. Move the keys to the new phase's gate in `compare.js` and add scenarios / program ops for its dynamics.
