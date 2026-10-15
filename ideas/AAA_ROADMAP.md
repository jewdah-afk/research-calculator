# Cursed Survivors: AAA roadmap

**Starting point:** the game is built as a 1:1 Vampire Survivors remake in Roblox. Enemies are static PNGs that wobble toward the player at 60 fps. The HUD is from the screenshot (XP bar top-left, timer, gold and kills top-right, HP and 6 weapon slots bottom). The level-up cards have crests, and there are about 89 procedural effects (PixelCore/PixelSims).
**Goal:** a 2D game that reads as a $60 Steam release. It keeps the VS look and 1:1 numbers, but has a real engine, deep systems, cinematic presentation and studio-grade tooling.
**Identity:** the curse is the theme. Curse is a stat in VS; here it becomes the visual and systemic signature, with a world that corrupts as you get stronger.

## How this actually runs
The code is written by Claude, with parallel agents for independent modules. Code is not the bottleneck. These are:
1. **Testing in Studio and on devices.** Only you can run the place, so every sprint ends with a play test by you.
2. **Art and audio.** Original assets have to be made or commissioned. Start now, alongside the code.
3. **Roblox moderation.** Uploaded images take about an hour to clear, so batch uploads.
4. **Playtesters.** Outside players judge feel and readability.

So the plan is a series of **sprints**. Each sprint is a few sessions of building, then one test by you in Studio. Each one ends with a pass/fail check, and the next sprint starts as soon as it passes.

**Setup needed once:** push the full game to the repo. Optionally connect Studio to this session (MCP), or keep using the `tools/sync.luau` + http-server flow so I can push code straight into the place. With a Studio connection, I can also run the profiler, take screenshots and verify changes myself, which removes most of bottleneck 1.

---

## Sprint 1: Engine swap (the biggest win)
Built in parallel by agents, each owning one module, merged and tested headless:
- Fixed-step deterministic simulation (60 Hz, interpolated rendering, seeded random streams).
- Entity storage as flat buffers, extending `pixelfx/fx/Crowd.luau` to projectiles, pickups, decals and particles.
- Layered EditableImage renderer: 13 layers in hierarchy order, uploading only the regions that changed.
- Sprite pipeline: `EnemyBake` on every enemy PNG, 32 pre-rotated projectile frames, skipping blank pixels when drawing.
- Spatial hash, flow field, frame budget manager, memory monitor, Parallel Luau on Actors.
- A profiling scene: the 29:00 moment with 1000 enemies and 2000 projectiles.

**Your test:** run the profiling scene on PC and on your phone.
**Pass:** 60 fps on PC and at least 30 fps on phone; the same seed gives the same run.

## Sprint 2: Readability (can ship in the same session as sprint 1)
The fixes from your screenshot:
- Contrast-adaptive and threat-colour outlines.
- A darker, less saturated background that gets quieter as chaos rises.
- Damage numbers in white or gold with an outline, crits that pop, and stacking per enemy.
- Dimmed empty slots.
- The density limiter, brightness ceiling, player beacon and clutter slider.
- The level-up card fixes: dim unselected cards, rarity in the top band, one motion at a time, readable body text, a visible "evolves with" icon.

**Your test:** play to 29:00 and take 3 screenshots.
**Pass:** I run the squint, grayscale and contrast checks on them. You can find the player, the nearest threat and the nearest pickup instantly.

## Sprint 3: Curse systems
Built in parallel, one agent per system:
1. **Elemental field engine:** heat, frost, wetness, toxin, charge, holiness and curse on a coarse grid, with diffusion and reaction. Interactions include steam, lightning conducting through water, toxin ignition, and holy/curse annihilation. These are bonuses on top of the 1:1 damage, and can be turned off in Classic mode.
2. **Ground material layer:** grass burns, water flows, ice melts, scorch and frost persist.
3. **Living curse:** Physarum veins spread, the palette shifts and enemies get cursed variants as the Curse stat rises.
4. **Enemy director:** shapes waves within the 1:1 wave tables using formations.
5. **Procedural cursed bosses:** assembled from parts, with a bullet-pattern grammar and telegraphs.
6. **Codex of discovered combos.**

**Your test:** 3 full runs with different builds.
**Pass:** 20 element interactions are readable, and the runs feel different from each other.

## Sprint 4: Presentation
- **Code (me):**
  - 2D lighting: SDF soft shadows, radiance cascades on high settings, the lantern lighting the forest.
  - Cinematic boss, evolution and Reaper moments.
  - A HUD that reacts to game state.
  - Beat-synced UI.
  - The art direction bible, as a document plus automated palette and outline checks.
- **Assets (you or artists):** original sprites and stages to the bible, and stems for a layered soundtrack. Start on these at sprint 1.

**Your test:** record a 60-second clip.
**Pass:** outside players say it beats the original on clarity and spectacle.

## Sprint 5: Studio-grade infrastructure (built alongside sprints 1–4, not after)
- Replays (seed plus inputs) and server-side verification of leaderboard runs.
- Golden-image tests with SSIM thresholds, and failing checks for effects that go over their frame budget.
- A headless bot that plays every stage.
- Telemetry: death heatmaps, weapon pick rates and per-device frame times.
- Editors in Studio for weapons, waves, stages and boss patterns.
- Daily seeded challenges with leaderboards, and weekly curse modifiers.

## Sprint 6: Showpieces
- 4-player co-op on one shared simulation, with elemental combos across players.
- Pixel-level enemy damage.
- An end-of-run painting.
- A stage and challenge editor with sharing.

---

## What runs in parallel
```
you: push game ─► test S1 ─► test S2 ─► test S3 ─► test S4 ...
me:  S1 engine ──► S2 readability ──► S3 curse systems ──► S4 presentation ──► S6
     S5 infra and QA ───────────────────────────────────────────────── (continuous)
art/audio: style bible ─► sprites, stages, music ───────────────────── (start now)
```

## Biggest risks
| Risk | Mitigation |
|---|---|
| Phones run out of EditableImage memory | Memory monitor plus quality tiers in sprint 1; test on phone every sprint |
| Determinism breaks | Fixed step, seeded randomness, stable ordering; a replay-match test in the automated checks |
| Effects bury readability | Sprint 2 checks apply to every later sprint; the clutter slider and Classic mode always ship |
| Copyright (VS data and assets) | Keep the mechanics, but use original art, names and audio before launch |
| Waiting on tests | Connect Studio to this session so I can test and screenshot myself |

## Right now
1. Push the full game to the repo (or connect Studio).
2. I start sprint 1 straight away, with agents building the engine modules in parallel against the existing `pixelfx` core.
3. You or your artist start the art bible and asset list.
