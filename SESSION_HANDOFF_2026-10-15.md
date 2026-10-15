# Session handoff: Cursed Survivors algorithms (2026-10-15)

Branch: **`claude/vs-algorithm-prep`** (repo `jewdah-afk/research-calculator`). Everything from this session is on it. `main` was not changed.
Read this first, then `ideas/README.md`.

## What the project is (as understood this session)
- **Cursed Survivors** is the owner's game: a 1:1 Vampire Survivors remake in Roblox. Its look is a dark pixel-art forest, a knight with a lantern, a gold-framed HUD and level-up cards with crests. See `session/uploads/`.
- **It is already built.** The game code is **not in this repo**. Nor are the existing effect modules (`PixelCore.luau`, `PixelSims.luau`) or `PROCEDURAL_BIBLE.md`. Ask the owner to push them before integrating anything.
- **Existing effects:** about 89 procedural EditableImage effects, shown in the artifact https://claude.ai/artifact/L2VLi2c41hTdvKf3LNYQa9. That artifact belongs to another account and is read-only for us. Its effect names are in `prep/NEW_ALGORITHMS.md`.
- **Goal:** the most impressive-looking game on Roblox, "AAA" quality. It keeps the VS look and 1:1 numbers and is made better with procedural algorithms. It must run at endgame crowd sizes.
- **Enemies today** are static PNGs that wobble toward the player at 60 fps.
- **Note:** the CLAUDE.md and `HANDOUT.md` in this repo describe a different project (Peckwood, a Birb remake). The handout marker `CS-HANDOUT-2026-10-15` that the owner mentioned was not found on any branch.

## What exists now (all on this branch)
| Path | Contents |
|---|---|
| `ideas/algorithm-lab.html` | **Algorithm Lab: 200 live generative algorithms**, each with its maths and its use in the game. Live page: https://claude.ai/artifact/9weFU6Rw4EARoebm2uT6YG (shared by link; republish from the same file). The owner loved this and asked for more each time. |
| `ideas/ALGORITHMS_CORE.md` | 100 core algorithms (maths → what it builds) |
| `ideas/EDITABLEIMAGE_ALGORITHMS.md` | 1000 idea list (uses of algorithms; only about 150 are distinct algorithms) |
| `ideas/PICKS.md` | Best-of lists: the top 10 to build first, the best 40, the top 100 |
| `ideas/AAA_ROADMAP.md` | The **improvement roadmap for the existing build**: flags, an A/B loop, tracks A–F. The owner rejected long time frames: "we're using you", so plan in sprints and work around the real bottlenecks (Studio tests, art, moderation) |
| `ideas/README.md` | Vision and ground rules |
| `pixelfx/` | **15 Luau modules built for EditableImage** (Core, Lichtenberg, Physarum, WaveRing, FrostDLA, JumpFloodOutline, BlueNoiseDissolve, Bloom, PaletteDither, Phyllotaxis, OrbitTrails, FabrikChain, CaveCA, SlotReel, EnemyBake, Crowd), plus a headless QA harness in `pixelfx/qa/`. Not yet tested in Studio. |
| `research/vs-fx/*.md` | Six research files from sub-agents: weapons (142 entries), enemies (109), pickups (186), UI (195), stages (128), hierarchy and QA pipeline (77 algorithms + z-order + metrics) |
| `prep/NEW_ALGORITHMS.md` | The first candidate list, and the artifact's 89 names |
| `session/screens/` | Contact sheets of every lab batch, PixelFX output, the 1000-enemy crowd test, enemy bake frames, and frames from the owner's video |
| `session/uploads/` | The owner's screenshots (in-game, level-up cards before and after) and screen recording |
| `session/qa/` | `lab_check.py` (runs all 200 plates headless), Playwright screenshot scripts, and tool notes |

## The owner's preferences (learned this session)
- **Wants raw volume and complexity:** "as many algorithms as possible", "keep going". The Algorithm Lab format (live plate, one-line maths, use in the game) is what landed. Effect-hierarchy lists did not: they want **maths algorithms that build things**.
- **Scope:** only this game, the VS style, 2D pixel art. Go deep.
- **Ideas first:** when they say "ideas", list them; don't build.
- **Hierarchy matters:** see the readability notes in the roadmap (Track B), taken from their screenshot. Enemies blend into the grass; the damage numbers are too small; empty and filled slots look alike; level-up cards need the selected card to win.
- **Copyright:** flagged once. Using extracted VS assets is a takedown risk; prefer original art, names and audio.
- **Declined:** a request to pool multiple Claude accounts through a proxy (against the terms). Offered Team, Max or API instead.

## Lab engineering notes (for adding plates 201+)
- Each plate is an object `{ name, math, use, w, h, init(s), step(s, px) }` in the `DEMOS` array. `px` is a `Uint32Array`; colours come from `RGB(r, g, b)` and the ramps `sh(EMBER|CURSE|FROST|MOSS, t)`. `scene(w, h, t, out)` gives a test image for filters.
- `ramp()` is memoised. Never build a LUT per pixel without it (that was the cause of 40 ms plates).
- To add plates: insert them before `\n];\n\nconst grid`, run `python3 session/qa/lab_check.py`, screenshot to check the look, then publish the same file to the artifact URL and commit.
- Interlace (half the rows per frame) any plate over about 15 ms.
- Plate ideas not yet built: Lattice-Boltzmann thermal flow, vorticity smoke, SmoothLife variants, Langton's loops, Wave Function Collapse (overlapping model), radiance cascades, a leaf-venation (Runions) dedicated plate, Kleinian (Riley slice), Rayleigh–Taylor, Belousov 3-variable, a Barnes–Hut galaxy collision, a dual-contouring plate, straight-skeleton roofs, a hydraulic-erosion river network, a sand / water / fire Noita multi-material grid.

## Next steps
1. Get the game code (or a Studio MCP connection) from the owner, then run step 0 of `ideas/AAA_ROADMAP.md` (read and measure).
2. Swap enemy rendering to `pixelfx/fx/EnemyBake` + `Crowd`, with `EditableImage:DrawImage` for the blits.
3. Port the owner's favourite lab plates to Luau, following the `pixelfx` module style.
4. Keep extending the lab if they ask; they will.
