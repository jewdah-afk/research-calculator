# Peckwood Rogue: full system layout (world, assets, runs, difficulty)

The goal is a 30-minute run in a deep, balanced 2.5D roguelike, set in an endless, seeded, studded, cel-shaded world. Build **Easy** completely first. Medium and Hard are mostly tables layered on top of Easy.

---

## 1. World generation (prototype: `rogue/worldgen/worldgen.py`)

**Tested on seed 1337:** the same seed always gives the same world, the largest step between walkable tiles is 0.5, and chunks join with no seams. Previews are in `design/rogue-ui/worldgen/`.

| Rule | How |
|---|---|
| **Chunks** | 64×64 tiles. One tile is a 4×4-stud plate. The camera sees about 2×2 chunks, so keep a 3×3 ring loaded around the player |
| **Endless + saved** | Everything is a pure function of (seed, world x, z). Chunks outside the ring are dropped. Coming back regenerates them exactly, so only *changes* (opened chests, broken props) are saved, as a small diff per chunk |
| **Height** | Domain-warped noise, rounded to 0.5 steps (−2 … +2). Every 0.5 step is one plate thickness in the art |
| **Never jump** | `enforce_walkable`: neighbouring walkable tiles never differ by more than 0.5. Only water and walls can be real cliffs |
| **Below zones** (crypts, bunkers, sunken ruins) | Square-ish rings step down **−0.5 per ring** (2–3 rings). The material changes (grass → stone → crypt purple) and there are 4 ramps in. It's all floor, with no actual caves and no jumping. The lighting and music change when you enter |
| **Structures** | Placed per 128×128 **region** using a hash, so a house that crosses a chunk edge is identical from both sides. Kinds: below zone, village (2–4 houses with doors), shrine, chests |
| **Roads** | Connect each region's main landmark to its neighbours, with a wobble. Some links are skipped so the roads don't form a grid. Roads are how players find things |
| **Props** | A jittered grid (cheap Poisson disc) on grass. Trees, rocks and bushes are picked by hash. Below zones stay clear arenas |
| **Spawn** | A 10-tile clearing at the origin |
| **Wave terrain** (later) | An optional ripple outside the play ring that animates on load (tiles pop up in a wave), so new chunks never just appear |

**Port to Roblox:** the same functions in Luau. Build each chunk as one merged mesh per material (generated, or as tile instances on a grid with greedy merging), then add props as instances from the kit.

## 2. Blender asset system (art)

One **toon kit**, rendered or exported in a single style:
- **Shader:** 3-tone cel ramp (top / left / right, like the iso preview), plus an **inverted-hull outline** (the "hull outline": a duplicated mesh, flipped normals, solid ink, about 2px) and a stud bevel highlight.
- **Tile kit:** plate 4×4 in 8 materials, plate edge pieces (outer and inner corners) for every 0.5 step, ramp pieces, water, and road edges.
- **Building kit:** walls (3 lengths), corner, door, window, roof (gable and flat), crypt arch, bunker hatch, stairs-down plate, pillars, fence. Every house is assembled from these by the generator, so there are unlimited variants.
- **Prop kit:** 5 tree types, rocks, bushes, flowers, lanterns, barrels, crystals, gravestones, chest (×6 rarities), shrine (×4 types).
- **Characters and enemies:** voxel / stud models with a 4–8 frame run cycle, rendered as **2.5D sprites in 8 directions** for crowds of hundreds. Heroes and bosses can be real 3D models.
- **Pipeline:** a Python script in Blender loops over every asset × direction × frame × biome palette and renders a sprite sheet. The same shader is used everywhere, so the whole game reads as one style.

## 3. Biomes (one generator, a different table each)

| # | Biome | Palette | Below zone | Enemy family (from Birb's 43) |
|---|---|---|---|---|
| 1 | **Meadow** (Easy home) | Greens, orange roads | Mossy crypt | Twig blight, forest spirit, giant fly, flower monster, elven assassin |
| 2 | Twilight Woods | Purple, orange lanterns | Haunted cellar | Ghoul, witch, ghost, skeleton, zombie cultist |
| 3 | Dune Ruins | Sand, gold | Tomb | Mummy, cobra, anubis warrior, anubis |
| 4 | Frost Peak | White, ice blue | Ice cave floor | Frost wisp, frozy cube, ice harpy, arctic whisper |
| 5 | Coral Coast | Teal, coral | Flooded bunker | Fishfolk (6 types), sea horror |
| 6 | Hellforge | Black, magma | Furnace pit | Imp, hell critter, cacodaemon, cultist brute |
| 7 | The Archive (final) | Ink, parchment | Library vault | Doppelganger, shardsoul, the Archivist (Birb's real boss, 980 HP) |

The Meadow enemy icon set is already generated: `birb-icons/final/en_*.png` (16 icons) and the sheet `birb-icons/sheets/rogue_enemies_meadow.png`.

## 4. Enemy tiers (the same for every biome)

| Tier | Example (Meadow) | Role | HP vs basic | Visual cue |
|---|---|---|---|---|
| Swarm | Bee swarm, slime sprout | Fodder, comes in packs of 10–30 | ×0.5 | Small |
| Basic | Twig blight, giant fly | Main body of a wave | ×1 | Normal |
| Special | Flower monster (ranged), beetle (charger), assassin (dash) | One mechanic each | ×1.5–2 | Distinct silhouette |
| Brute | Mushroom brute | Tanky, slow | ×4 | Big |
| **Elite** | Elite twig blight, elite flower | Buffed version + drops a chest | ×5.5 (Birb's elite numbers) | Crown + coloured glow |
| **Miniboss** | Bramble golem, hornet queen | Arena moment at minutes 10 and 20 | ×40 | Health bar, screen intro |
| **Boss** | Treant Elder | Minute 30 finale | ×200 | Full boss UI |
| Cursed | Corrupted scarecrow, shadow wolf | Night / curse events, risk for reward | ×3 | Purple aura |

Stats come from `BirbSystems.enemyStats(floor)`. The "floor" rises with the minute, so scaling is already verified math.

## 5. The 30-minute run (Easy)

| Minute | What happens |
|---|---|
| 0–3 | Swarm + basic. Learn the build, get the first chest |
| 3–8 | Specials join. The first below zone spawns an elite |
| 10 | **Miniboss 1** + a ring of swarm |
| 10–18 | Density ramps up. Shrines matter. "Night" event at 15 (cursed enemies, +50% gold) |
| 20 | **Miniboss 2** (or two elites at once) |
| 20–28 | Peak waves. Evolutions should be online |
| 28–30 | Everything spawns |
| **30** | **Boss**. Kill it to clear the stage, unlock the next biome and earn Silver ×2 |
| 30+ | **Endless**: optional. The timer keeps going, floors keep scaling, leaderboard |

Spawning is a **director**, not fixed waves: a budget per second that rises each minute buys enemies from the biome table. It keeps a minimum on-screen count and spawns outside the camera in the direction the player is moving.

## 6. Difficulty: Easy → Medium → Hard

Build and tune Easy fully first. Medium and Hard are **modifier tables**:

| Knob | Easy | Medium | Hard |
|---|---|---|---|
| Enemy floor offset | +0 | +4 | +9 (Birb's night = floor + 9) |
| Spawn budget | ×1 | ×1.35 | ×1.8 |
| Elite chance | base | ×1.5 | ×2.5 |
| Extra boss mechanic | none | phase 2 | phase 2 + adds |
| Healing | ×1 | ×0.8 | ×0.6 |
| Silver | ×1 | ×1.75 | ×3 |
| Rarity luck | +0 | +5% | +12% |

Then **Molt levels** (see `ROGUE_PROGRESSION.md`) stack on top for endless depth.

## 7. Balance

- Every run is data: weapons, items, tomes, enemies, the director curve and the difficulty tables.
- The headless simulator (`ROGUE_SCALE.md`) replays 1000s of bot runs per difficulty. The target is a median death around minute 22 on a fresh Easy save, and around 40% of runs clearing Easy once the meta shop is mid-way.

## 8. Build order (no Lua until the base is locked)

1. ✅ World generator prototype (Python) and look test
2. ✅ Meadow enemy roster art
3. ⏭ Data tables: biome, enemies, director curve, difficulty (JSON)
4. ⏭ Headless simulator (Python), then tune Easy Meadow to the 30-minute target
5. ⏭ Blender toon kit v1 (tiles + 5 props + 1 house) with the outline shader, and a render-script test
6. ⏭ Port worldgen + director to Luau (only when 3–5 are locked)
7. Content waves: one biome at a time, then Medium, then Hard
