# Cursed Survivors: improvement roadmap (from the existing build)

**Starting point:** the game is built and playable as a 1:1 Vampire Survivors remake. It has PNG enemies wobbling toward the player, the HUD from the screenshot, level-up cards with crests, and about 89 procedural effects (PixelCore/PixelSims).
**Goal:** get it to a $60-release level of quality without breaking what works.

## The rules for improving a live game
1. **No rewrites.** Each upgrade replaces one subsystem, behind a flag (`Config.Upgrades.X = true/false`), and the old path stays until the new one wins.
2. **The game is shippable after every step.** If an upgrade isn't ready, its flag stays off.
3. **Measure before and after.** Every upgrade has a number it must improve (frame time, a readability score, playtest feedback) and must not make anything else worse.
4. **Gameplay numbers stay 1:1.** Upgrades change how the game looks and runs, not its balance. New systems that do affect gameplay are opt-in modes; Classic mode is always available.
5. **Small diffs.** Each upgrade is one pull request, synced into Studio and tested by you, then merged.

## The loop for each upgrade
```
1. Read the existing code for that subsystem       (me)
2. Write the replacement behind a flag, with tests (me, agents in parallel for independent upgrades)
3. Sync into Studio and A/B it: flag off vs on     (you, or me if Studio is connected)
4. Compare numbers and screenshots                 (me)
5. Merge, then flip the default to on
```

**Needed once:** push the current game to the repo. Connecting Studio to this session (MCP) lets me do step 3 myself.

---

## Step 0: Read the game and measure it (first session)
- I read the whole codebase and map how it's structured: enemies, weapons, renderer, HUD, effects, saves.
- I add a debug overlay showing frame time, entity counts, EditableImage memory and draw-call proxies, plus a profiling scene that jumps to 29:00 with all weapons evolved.
- You run it once on PC and once on your phone.
- **Output:** a ranked list of the slowest and least readable parts. That list decides the order of everything below. The list below is my best guess until then.

## Track A: Performance (in order of expected payoff)
| # | Upgrade | Replaces | Pass |
|---|---|---|---|
| A1 | Enemy batch renderer (`Crowd` + `EnemyBake`) | One ImageLabel per enemy, moved every frame | Enemy render cost down 5× or more at 300 enemies |
| A2 | Wobble and animation from baked frames | Per-frame Rotation and Position tweens | Zero per-enemy property writes |
| A3 | Spatial hash for hits and collisions | Checking every enemy against every projectile | Collision cost scales roughly linearly with enemy count |
| A4 | Pools for projectiles, gems and damage numbers | Creating and destroying Instances | No GC spikes at 29:00 |
| A5 | Tiered effect scheduler and frame budget | Every effect at 60 fps | Frame-time spikes capped |
| A6 | Uploading only the changed regions | Full-image writes | Upload cost proportional to what changed |
| A7 | Parallel Luau for simulation | Single thread | Main-thread time down |
| A8 | Memory monitor and quality tiers | A crash or blank image when phone memory runs out | Stable on a low-end phone |

## Track B: Readability (from your screenshot)
| # | Upgrade | Pass |
|---|---|---|
| B1 | Contrast-adaptive and threat-colour enemy outlines | Enemies pass the contrast map against the grass |
| B2 | Darker, less saturated stage background that gets quieter as chaos rises | The grayscale test separates threats from decor |
| B3 | Damage numbers: white or gold fill, outline, crit pop, stacking per enemy | Readable at 29:00 |
| B4 | Empty HUD slots dimmed | Filled slots stand out instantly |
| B5 | Level-up cards: dim unselected, rarity in the top band, one motion at a time, brighter body text, visible "evolves with" icon | The squint test lands on the selected card, then its rarity |
| B6 | Density limiter, brightness ceiling, player beacon, clutter slider | The player is findable at 29:00 within 0.5 s |

## Track C: Feel and polish (cheap, high impact)
| # | Upgrade | Pass |
|---|---|---|
| C1 | Hit flash with the game's 30/60/120 ms timings, plus hit stop on big hits | Hits feel heavier in an A/B test |
| C2 | Enemy squash and lean from `EnemyBake`, varied per enemy type (bat flap, zombie lurch, plant sway) | Enemies stop looking like stickers |
| C3 | Death variety: blue-noise dissolve, shatter, overkill gibs | Deaths read clearly and vary |
| C4 | Gem merge animation, gems spiralling in on magnet pull, diegetic XP | Collection feels satisfying |
| C5 | HP bar damage ghost and low-HP heartbeat vignette | Damage taken is readable |
| C6 | Evolution fusion moment and chest roulette polish | The best moments get spectacle |

## Track D: Signature systems (new depth, opt-in modes)
| # | Upgrade | Pass |
|---|---|---|
| D1 | Elemental field grid (heat, frost, wetness, toxin, charge, holiness, curse) with interactions; Classic mode turns it off | 20 readable interactions |
| D2 | Ground material layer: burn, flood, melt, persistent decals | The battlefield shows the history of the fight |
| D3 | Living curse: veins, palette shift and cursed enemy variants as the Curse stat rises | The world visibly corrupts |
| D4 | Enemy director using formations within the 1:1 wave tables | Runs have rhythm |
| D5 | Procedural cursed bosses with a bullet-pattern grammar | Unique final bosses |
| D6 | Codex of discovered combos | Players chase discoveries |

## Track E: Presentation
- **E1:** 2D lighting (the lantern lights the forest; SDF shadows; radiance cascades on high settings).
- **E2:** Cinematic boss, evolution and Reaper moments.
- **E3:** A HUD that reacts to game state (cracks, freezes, burns).
- **E4:** Beat-synced UI and layered music (needs music stems).
- **E5:** An art direction bible with automated palette and outline checks.
- **E6:** Replace any VS-derived art, names and audio with originals before a big launch (copyright).

## Track F: Studio-grade infrastructure (adds safety to every other track)
- **F1:** Golden-image screenshots per screen and effect, with SSIM diffs on every upgrade.
- **F2:** The profiling scene as an automated regression check.
- **F3:** Replays (seed plus inputs), once the simulation is deterministic, plus leaderboard verification.
- **F4:** Telemetry: death heatmaps, weapon picks, per-device frame times.
- **F5:** Editors in Studio for weapons, waves and stages.
- **F6:** Daily seeded challenges and weekly curse modifiers.

---

## Order
1. **Step 0** (read and measure).
2. **A1, A2, B1, B3, C1** together: one session, 5 flags, one Studio test. This is the biggest visible jump: fast, readable and punchy.
3. **The rest of A and B** in the order the step 0 measurements give.
4. **C**, then **D1–D3** (the curse identity), then **E**.
5. **F1–F2** from the very first upgrade, so nothing regresses. F3–F6 once the core is stable.

Tracks are independent, so parallel agents can build A, B and C upgrades at the same time; each is a separate flag and a separate pull request.

## Right now
Push the current game to the repo, or connect Studio to this session. Step 0 starts the moment I can read the code.
