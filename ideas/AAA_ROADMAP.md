# Cursed Survivors: AAA roadmap

**Starting point:** the game is built as a 1:1 Vampire Survivors remake in Roblox. Enemies are static PNGs that wobble toward the player at 60 fps. The HUD is from the screenshot (XP bar top-left, timer, gold and kills top-right, HP and 6 weapon slots bottom). The level-up cards have crests, and there are about 89 procedural effects (PixelCore/PixelSims).
**Goal:** a 2D game that reads as a $60 Steam release. It keeps the VS look and 1:1 numbers, but has a real engine, deep systems, cinematic presentation and studio-grade tooling.
**Identity:** the curse is the theme. Curse is a stat in VS; here it becomes the visual and systemic signature, with a world that corrupts as you get stronger.

Each phase has deliverables and an exit test. A phase doesn't start until the previous phase's exit test passes.

---

## Phase 0: Audit and baseline (1–2 weeks)
**Why:** you can't improve what you haven't measured.
- Push the full game to the repo (PixelCore, PixelSims, `PROCEDURAL_BIBLE.md`, client and server scripts, assets).
- Profile three moments on a mid-range phone and on PC: 0:30, 15:00 (about 150 enemies), and 29:00 with all weapons evolved (300+ enemies). Record frame time, memory and EditableImage count.
- Run the hierarchy checklist (`research/vs-fx/hierarchy_qa.md`) on gameplay, level-up and results screens: squint test, grayscale test, contrast map.
- Capture reference footage from the original game, if you own it, for frame-timing QA.

**Exit test:** a baseline report with the numbers, plus the top 10 performance costs and the top 10 readability problems.

## Phase 1: Engine core (6–10 weeks), the foundation
1. **Fixed-step deterministic simulation** at 60 Hz, with rendering interpolated between steps. All randomness comes from seeded streams (`Core.rng`).
2. **Entity system on buffers.** Enemies, projectiles, pickups, decals and particles are struct-of-arrays, with no Instances per entity. This builds on `pixelfx/fx/Crowd.luau`.
3. **Layered renderer.** Fixed EditableImage layers in hierarchy order: ground, decals, pickups, ground auras, enemies (y-sorted), player, projectiles, flashes, damage numbers, HUD. There's one upload per layer per frame, and only the regions that changed are uploaded.
4. **Sprite pipeline.** Enemy PNGs are baked at load with `EnemyBake` (walk, hit flash, death frames, 32 rotation frames for projectiles). Opaque runs are pre-encoded so blank pixels are skipped when drawing.
5. **Spatial hash and flow field** for all collisions and enemy movement.
6. **Parallel Luau.** Simulation and crowd run on Actors; only uploading the images happens on the main thread.
7. **Frame budget manager and tiered scheduler.** Effects at 60/30/15/8 fps get per-frame cost caps and drop quality gracefully.
8. **Memory monitor.** Tracks the EditableImage budget and falls back to lower quality instead of failing.

**Exit test:** 1000 enemies plus 2000 projectiles at 60 fps on PC and at least 30 fps on a mid-range phone, at the 29:00 moment. A 30-minute run gives identical results from the same seed and inputs.

## Phase 2: Readability and hierarchy (2–3 weeks, can overlap phase 1)
Fixes for the problems in your screenshot:
- **Enemies sink into the grass:** a contrast-adaptive outline (78), threat-colour outlines by danger tier (273), and rim light from `EnemyBake`.
- **Decor competes with threats:** stage backgrounds pushed darker and less saturated. Background desaturation scales with chaos (673).
- **Damage numbers too small and blend in:** a white or gold fill with a 1 px dark outline, crits pop, and numbers on the same enemy stack (320, 321).
- **Filled and empty slots look alike:** empty slots at 30% brightness, filled ones lit (318).
- **Late-game wall of effects:** a density limiter, brightness ceiling, player beacon, and a clutter slider in settings (664, 675, 676, 970).
- **Level-up cards:** dim the unselected cards to 60% with no rays; move rarity into the top band; one motion at a time on the selected card; brighter body text; a visible "evolves with" icon.

**Exit test:** every screen passes the squint, grayscale and contrast tests. In blind tests, players spot the player, the nearest threat and the nearest pickup within 0.5 s at 29:00.

## Phase 3: The curse systems (8–12 weeks), what makes it deep
1. **Elemental field engine.** A coarse world grid (for example 8 px cells) holds heat, frost, wetness, toxin, charge, holiness and curse. Weapons write into the fields and the fields interact:
   - Fire plus frost gives steam, which blocks vision and slows enemies.
   - Charge plus wetness conducts lightning through puddles.
   - Toxin plus heat ignites into an explosion.
   - Holiness and curse annihilate each other in a flash.

   The algorithms are heat diffusion and advection-reaction-diffusion (`ALGORITHMS_CORE.md` 13–14). Base weapon damage stays 1:1; the interactions are bonus effects that can be turned off in Classic mode.
2. **Material layer under the map.** A falling-sand style material grid: grass burns into ash, water pools and flows, ice melts, explosions scorch, and blood and frost persist as decals. Simulated at low resolution and drawn into the ground layer.
3. **The curse as a living world.** As your Curse stat rises, the map visibly corrupts:
   - Physarum veins spread across the ground.
   - The palette shifts toward the stage's cursed palette.
   - Enemies gain cursed variants with outlines and tendrils.

   This uses VS's own Curse stat; how it looks is the new part.
4. **Enemy director.** A system that reads tension (HP, enemy density, DPS, time since the last near-death) and adjusts spawn shapes within the VS wave tables. It uses formations (bat lines, flower rings, ghost lines) to create rhythm. The 1:1 wave numbers stay the baseline.
5. **Procedural cursed bosses.** Bosses assembled from parts, with bullet patterns from a pattern grammar (rings, spirals, waves, aimed bursts), telegraph decals and phase changes. They add to the original bosses, not replace them.
6. **Codex and discovery.** Hidden synergies, evolutions and element combos are logged when discovered, so finding combos becomes the long-term goal.

**Exit test:** 20 element interactions working and readable. In playtests, players describe runs as different from each other, not just a different stat build.

## Phase 4: Presentation (8–12 weeks, mostly art and audio)
1. **Lighting.** 2D radiance cascades or SDF soft shadows (`ALGORITHMS_CORE.md` 97–98): the lantern lights the forest, fireballs light their path, and braziers cast shadows. Quality tiers go down to "no shadows" on phones.
2. **Cinematic moments:** boss intros (silhouette, letterbox, title card), evolution showcases (slow motion, fusion animation, zoom punch), and the Reaper's arrival (darkening, music cut, toll).
3. **Living HUD:**
   - The HUD frames crack at low HP, freeze during Orologion and burn during Nduja.
   - XP gems orbit the player before entering the bar.
   - Light from an opened chest travels into the weapon slot it fills.
4. **Dynamic music.** Layered stems driven by intensity, stingers on events, beat-synced UI pulses, and a silence moment before the Reaper.
5. **Art direction bible:**
   - One palette set per stage (normal, cursed and inverse).
   - Light from the top-left everywhere.
   - Fixed animation timings: 60 ms hits, 120 ms pops, 300 ms reveals.
   - A 1 px outline standard.
   - The 13-layer z-order.

   Every new asset must pass the bible.
6. **Commissioned art and audio.** Original pixel art for characters, enemies and stages, plus an original soundtrack. This is the single biggest AAA lever, and it removes the copyright risk of using VS assets.

**Exit test:** side-by-side screenshots and clips beat the original on clarity and spectacle, judged by outside players, not the team.

## Phase 5: Studio-grade infrastructure (ongoing from phase 1)
- **Replays:** a run is stored as its seed plus inputs (a few KB). Players can watch and share them, and the server re-simulates top leaderboard runs to verify them.
- **Automated visual QA:** golden images for every effect and screen, the per-pixel diff and SSIM thresholds from `hierarchy_qa.md`, a failing check if an effect goes over its frame budget, and a headless bot that plays every stage each build.
- **Telemetry:** death heatmaps, weapon pick and win rates, run lengths, and frame-time distribution per device. Balance changes are made from data.
- **Content tools in Studio:** a weapon editor with live preview, a wave and formation editor, a stage palette and decor editor, and a boss pattern editor. All content is data.
- **Live ops:** daily seeded challenges with global leaderboards, weekly curse modifiers, seasonal events and new stages.

## Phase 6: Showpieces (after launch)
- **Co-op for up to 4 players** on one deterministic simulation. Elemental fields are shared, so weapons combine across players. Player colours and outlines come from the VS co-op options.
- **Pixel-level enemy destruction:** enemies lose pixels where they're hit, and big enemies crack apart.
- **End-of-run painting:** each run renders a unique image from its paths, kills and elements, which players can share.
- **Stage and challenge editor** with community sharing.

---

## Order and dependencies
```
Phase 0 audit
   │
   ├─► Phase 1 engine core ──► Phase 3 curse systems ──► Phase 6 showpieces
   │        │                         │
   │        └─► Phase 5 infra (runs alongside from here)
   │
   └─► Phase 2 readability (in parallel with phase 1)
                                      └─► Phase 4 presentation (art and audio can start at phase 0)
```

## Biggest risks
| Risk | Mitigation |
|---|---|
| Phones run out of EditableImage memory | Memory monitor plus quality tiers in phase 1; test phones every week |
| Determinism breaks (floats, ordering) | Fixed step, seeded randomness, stable iteration order, and a replay-match test in CI |
| Effects bury readability | The phase 2 gates apply to every later phase; the clutter slider and Classic mode always ship |
| Copyright (VS data and assets) | Keep the mechanics, but use original art, names and audio before launch |
| Scope | Each phase has an exit test; nothing starts until the previous test passes |

## First 2 weeks, concretely
1. Push the game to the repo.
2. Run the phase 0 profile at 0:30, 15:00 and 29:00 on a phone and on PC.
3. Replace enemy rendering with `EnemyBake` plus the `Crowd` batch renderer (the biggest single performance and look win).
4. Apply the phase 2 readability fixes from your screenshot (outlines, background contrast, damage numbers, slot dimming).
5. Set up the golden-image QA harness, so every change from then on is measured.
