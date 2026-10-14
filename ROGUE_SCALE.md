# Peckwood Rogue: can it get as big and as balanced as Megabonk or Vampire Survivors?

Short answer: **yes.** The current system already has the right bones. `ROGUELIKE_DESIGN.md` copies Megabonk's build structure (weapons, tomes, items, rarity multipliers, stacking rules), and `Survivor.luau` holds Birb's verified combat math. Getting to that size takes content plus tooling, not a redesign. What makes those games feel bottomless is three things: lots of content, interactions between items, and a balance process that keeps all of it fair. Below is how we get each one.

## 1. Content targets (the "big" part)

Counts are targets for a 1.0. Neither game publishes a fixed spec, so these are our own goals at roughly their scale.

| Pool | Launch (vertical slice) | 1.0 target | Notes |
|---|---|---|---|
| Characters | 3 (Birb, Crow, Sparrow) | 15–20 | Each has a passive, a starting weapon and one stat bias. Birb companions (Parrot, Seagull, Dave, Red Panda) are natural picks |
| Weapons | 6 (current set) | 30–40 | Spread over behaviour families: orbit, projectile, aura, strike, summon, trail, bounce, beam |
| Tomes | 21 (already listed) | 21–25 | Already Megabonk-sized |
| Items | 10 (Birb artifacts) | 60–80 | Birb has 47 artifacts in `birb-data/data/` to mine: effects, art and names |
| Evolutions / synergies | 0 | 20+ | Weapon + item (or tome) at max level → evolved weapon. This is the biggest "one more run" driver |
| Biomes | 2 references | 6–8 | One procedural generator, with a different theme table, enemy list and boss per biome |
| Enemies | 43 Birb types | 60+ | Birb's 43 already have floor scaling and elite modifiers |
| Bosses | 1 | one per biome + a final | |
| Meta unlocks | ~6 | 100+ | Unlocks, achievements and challenges; each unlock should be visible in its 3D render |

## 2. Balance (the "balanced" part)

Balance at this size needs **data-driven tables plus a simulator**. Tuning by hand stops working past about 20 weapons.

1. **Everything is data.** Weapons, tomes, items, enemies and spawn timelines live in JSON tables (like `birb-data/upgrades.json`), never in code. Designers change numbers without touching code.
2. **One stat pipeline.** All damage goes through the stacking rules in `ROGUELIKE_DESIGN.md` §2 (weapon × character × tome × shrine; armor `i/(0.75+i)`; evasion `i/(1+i)`). Nothing bypasses it, so every new item composes with the rest.
3. **A power budget.** Give every card a power score: expected DPS gained, or EHP gained for defence. Rarity multiplies it (×1, 1.2, 1.4, 1.6, 2). New content must land inside the budget band of its rarity. Outliers are flagged automatically.
4. **A headless simulator.** It is pure Luau, like `Survivor.luau`, with no rendering. It plays thousands of runs per build with simple bot policies: greedy DPS, random, and "sticks to one item".
5. **What it reports:**
   - Pick rate and win rate per card.
   - Time-to-kill curves against the enemy HP ramp.
   - Death minute.
   - Which builds break the curve.

   A card that wins far above or below the average gets retuned. This is how a game can ship hundreds of items without obvious traps.
6. **The difficulty curve is a table.** Spawn rate, enemy floor and elite chance are set per minute. Birb's `enemyStats(floor)` already gives HP and attack scaling that we have verified. The simulator tunes the table so a median build dies around minute 12–15 without upgrades, and survives with good picks.
7. **Live tuning.** Ship the tables as a ModuleScript that can be hot-swapped, then track pick and death telemetry in DataStores. Patch numbers without republishing code.

## 3. The 2.5D Blender pipeline: what it means for gameplay and UI

- **Characters and enemies** become pre-rendered 3D sprites: billboards in 8 directions for idle, run, attack and hit, rendered in Blender with the same toon shader and studs as the world. A batch script renders every character × animation × direction × biome-lighting variant. Roblox plays them as flipbook sprites, cheap enough for hundreds of enemies on screen, which a survivors game needs.
- **Icons and cards** come from the same renders, so a weapon's card icon is literally the model used in the game. The current Figma AI icons are placeholders for that look, and the card, slot and badge layouts are already sized for square renders.
- **Procedural studded world:** generate the island layout in code (seeded noise for terrain heights, then a stud grid snapped to it, then props scattered on Poisson discs, then guaranteed clearings and paths). Build it from a library of pre-baked stud tiles and props rendered in Blender. That way "random every run" never costs us art quality. The Meadow and Twilight references show the target look for two biome palettes.

## 4. What to build next, in order

1. Data schema for weapons, tomes, items and enemies, plus the stat pipeline module (extend `Survivor.luau`).
2. A headless simulator with bot policies, and a balance report (pick and win rates, TTK curves).
3. The vertical slice: 3 characters, 6 weapons, 21 tomes, 10 items, 1 biome, 1 boss. All the UI frames for it already exist on the Figma "Rogue UI" page.
4. The Blender sprite-render batch script, and a first character in 8 directions.
5. The procedural map generator, with seeds, tiles and prop scatter.
6. Content waves: each wave adds 1 biome, 5 weapons, 10 items and 3 evolutions, all of which must pass the simulator budget.
