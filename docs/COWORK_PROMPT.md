# Handoff prompt — 2D renderer + remaining systems

Everything below the line is self-contained. Paste it into a fresh chat.

---

## ROLE
You are a senior game engineer. Continue building a **1:1 mechanical clone of
Vampire Survivors in Roblox (Luau)**, rendered as **2D pixel sprites via
EditableImage**. Mechanics and numbers must match the reference exactly.
Presentation is original: our own art, names, text and audio. The plan is to get
everything working 1:1 first, then reskin the look afterwards — so do NOT
substitute or "improve" any mechanic or number.

## REPO
https://github.com/jewdah-afk/research-calculator
Branch: `claude/vampire-survivors-mechanics-y1l323`

```
git clone https://github.com/jewdah-afk/research-calculator.git
cd research-calculator
git checkout claude/vampire-survivors-mechanics-y1l323
```

## READ FIRST, IN ORDER
1. `docs/ARCHITECTURE.md` — module map, ownership, interfaces, data flow
2. `src/shared/Types.luau` — the interface contract; build against it exactly
3. `research/vs/SUMMARY.md` — the core loop, 24 recorded source conflicts, known gaps
4. `docs/DATA_CONVENTIONS.md` and `research/vs/SCHEMA.md`
5. `src/shared/RenderConfig.luau` and `assets/manifest.json` — the 2D contract
6. The research `.md` for whatever you touch — it is the oracle

## WHAT ALREADY EXISTS AND IS VERIFIED

**Reference data** (`research/vs/`) — mechanics extracted from the game's own
shipped balance files (v1.16, community rip), NOT from wikis: 11 weapons with
full Lv1–8 delta tables, 6 characters, 16 passives, 32 evolutions, all 31 Mad
Forest waves with events and boss/chest schedules, 21 enemy statlines, floor
pickups with drop weights, chest odds, 29 PowerUps, the XP curve. Both `.md`
(readable) and `.json` (source of truth). 24 source conflicts and ~50 unknowns
are recorded explicitly — nothing was guessed.

**Generated Luau data** (`src/shared/Data/`) — six modules generated from that
JSON by `tools/gen_luau_data.py`. **Never hand-edit them**; edit the JSON and
regenerate.

**Pure mechanics** (`src/shared/Sim/`) — Rng, DataAccess, Stats, Experience,
WeaponLevels, Damage, LevelUp, Chests, Pickups, Waves, EnemyStats. No Roblox
APIs at all, so they run headless under the plain `luau` CLI.

**Server** (`src/server/`) — EnemyManager (structure-of-arrays pools + spatial
hash), WeaponRunner + ProjectilePool, all 11 weapon behaviours, GameLoop,
Spawner, PlayerSession, PickupManager, Net.

**Client** (`src/client/`) — Hud, LevelUpUi, Camera, Visuals. These are written
for the OLD 3D presentation and are what you are replacing.

**Tests** (`tests/`) — 17 files, ~179 assertions, written independently from the
research tables by an agent forbidden from reading the implementations. They are
the oracle: if a test and the code disagree, the code is wrong unless you can
show from the research that the test misreads the source.

## THE VERIFICATION GATE — THIS IS THE ONLY THING THAT MATTERS

```
bash tools/check_all.sh     # must exit 0 before every commit
```

It runs, in order: data fidelity vs source JSON, value coverage, structure and
referential integrity, no verbatim shipped text, byte-identical regeneration,
stylua format, module-return validity, **place build (proves requires resolve in
the Roblox instance tree)**, `luau-lsp analyze` in strict mode with Roblox
definitions, and the headless mechanics tests. It passes right now. Keep it
passing. Never weaken a gate or a test to get green.

Toolchain (install if missing): `rojo`, `stylua`, `luau`, `luau-analyze`,
`luau-lsp`. Roblox type definitions are committed at `tools/types/`.

## VERIFIED EditableImage FACTS

Measured on the target machine (Roblox 0.739.0.7390687) by a probe — these are
facts, not assumptions, and the official docs are unreachable from the build
environment:

```lua
local img = AssetService:CreateEditableImage({ Size = Vector2.new(480, 270) })
imageLabel.ImageContent = Content.fromObject(img)
img:WritePixelsBuffer(Vector2.zero, size, buf)   -- buffer of RGBA u8
-- DrawImage and DrawRectangle are both present.
imageLabel.ResampleMode = Enum.ResamplerMode.Pixelated
```

**Measured throughput: 500 8px sprites composited into a 512×288 buffer per
frame → 151 fps, worst frame 2.8 ms.** The 2048-enemy target has headroom.

## YOUR TASK

### 1. The 2D renderer (the critical path)
Replace the 3D presentation with an EditableImage pixel renderer.

- **Delete/replace**: `src/server/EnemyPresenter.luau`, `GemPresenter.luau`, the
  visual half of `ProjectilePool.luau`, `src/client/Camera.client.luau`,
  `Visuals.client.luau`.
- **Keep untouched**: everything in `Sim/`, `EnemyManager`, `WeaponRunner`, the
  weapon behaviours, `GameLoop`, `Spawner`, `PlayerSession`, `PickupManager`.
  The simulation is already 2D — it works in flat X/Z world units and has no
  idea anything was ever 3D.
- **Architecture**: the server simulates and streams entity positions to the
  client; the client composites one canvas per frame and uploads it. Pack the
  stream into a `buffer` (id/x/y/spriteIndex), send over an
  `UnreliableRemoteEvent` at ~20–30 Hz, and interpolate on the client. Never
  send a per-entity table.
- **Canvas**: fixed internal resolution from `RenderConfig` (480×270), scaled to
  the viewport by an **integer** factor, `Pixelated` resampling, letterboxed.
  Pixels must stay square at every window size.
- **Sprites from the manifest only** (`assets/manifest.json`), never hard-coded.
  A sprite with `"sheet": null` renders as a generated placeholder rectangle in
  its palette colour — that is the current state, since the art tool does not
  exist yet. Support real sheets too: fixed cell size (default 32×32,
  per-sheet override), named animations (idle/walk/hurt/death) with per-frame
  durations, so art can be dropped in later with no code change.
- **Hot reload**: re-reading the manifest rebuilds the sprite cache at runtime.
- **F1 debug overlay**: hitboxes, entity counts, sprite ids, fps, reload status.
- **Draw order** per `RenderConfig.layer`. Cull anything off-canvas before
  blitting. Zero allocation in the per-entity blit loop.

### 2. Then, in this order
- Ground: infinite seamlessly tiling stage that scrolls with the camera.
- Damage numbers (toggleable), hit flash, screen shake on big hits, gem-vacuum
  effect, flashing chests.
- Evolutions: data is in `research/vs/passives_evolutions.json` (32 recipes,
  conditions, evolved stat lines) but nothing implements them yet.
- Floor pickups and destructible light sources: data exists, wiring does not.
- Meta: gold persistence, the 29-PowerUp shop with its price-escalation formula,
  character unlocks, achievements, codex, versioned JSON save.
- Results screen: damage dealt per weapon, kills, gold, time survived.
- Audio manager with placeholder beeps.

## NON-NEGOTIABLE RULES
1. **Never invent a balance number.** Every gameplay constant comes from
   `src/shared/Data/`. Engine constants the research does not define (pixels per
   world unit, spawn ring radius, camera deadzone) go in `src/shared/Tuning.luau`
   or `RenderConfig.luau` with a comment saying **NOT from research**. A bare
   numeric literal anywhere else (other than 0, 1, -1, 2) is a defect.
2. **`UNKNOWN` is not zero.** `Data` marks absent source values with a sentinel.
   Read them through `Sim/DataAccess.num(value, defaultKey)`. Never `or 0` — it
   silently grants free stats.
3. **Weapon `levels` entries are deltas**, folded only by
   `Sim/WeaponLevels.statsAt`.
4. **`Sim/` stays pure Luau.** No `game`, `workspace`, `Instance`, `task`,
   `RunService`, no yields. It must keep running under the plain `luau` CLI.
5. **A ModuleScript must return exactly one non-nil value**, or Roblox raises
   "Module code did not return exactly one value" and every requirer fails. The
   `luau` CLI tolerates a nil return, so only `tools/check_module_returns.py`
   catches it.
6. **Requires are filesystem-relative strings** (`require("../shared/Tuning")`)
   so tests and the analyzer work. Rojo splits `src/` across three containers, so
   `tools/build_place.py` rewrites them to absolute instance paths at build time.
   Never hand-write instance paths in `src/`.
7. **Interfaces live in `src/shared/Types.luau`.** Extend it deliberately; when
   you change a type, every consumer is re-checked by the analyzer.
8. **Where the research is silent or conflicted**, take the value its `conflicts`
   entry marks authoritative (shipped data beats wiki), leave a comment citing
   the conflict, and list the choice in your report. Never guess silently.
9. Original names, art and text only. `Data.*.name` is a reference label;
   anything a player sees reads `src/shared/DisplayNames.luau`.
   `tools/check_no_verbatim_text.py` gates this — do not undo it.

## OPEN QUESTIONS — ask, do not invent
- **Weapon archetypes "laser/beam sweep" and "pierce spear/lance"** are not
  base-game Vampire Survivors weapons, so no reference numbers exist for them.
- **Screen extent in world units** — enemies spawn just off-camera, which needs a
  constant the research does not define. See `docs/CALIBRATION.md` §D.
- **The art tool** referenced as "my research calculator" does not exist in this
  repo (`index.html` is an unrelated idle-game calculator). The manifest defines
  the format; real art can be dropped in later.
- ~29 further open questions are listed in the build history — the largest are
  swarm/wall internals, the exact Luck→drop-weight multiplier, and the
  `HP_x_Level` formula. All are recorded as `unknowns` in the research JSON.

## HOW TO WORK
1. State your plan before writing code; say where you deviate from
   `docs/ARCHITECTURE.md` and why.
2. Build the renderer first and get something visibly moving on screen early.
3. Commit in logical pieces with `tools/check_all.sh` green each time.
4. Report at each milestone: fps and entity counts measured, not estimated; every
   `Tuning`/`RenderConfig` constant you added and why; every place the research
   was silent and what you chose; what still needs a human playtest.

## WHAT I CARE ABOUT
Mechanical fidelity you can prove — a test per formula, citing the research line
it came from — then 2000+ enemies at 60 fps, then honesty about the gaps. The
game should look and feel like Vampire Survivors with our own art. Fun is a
playtest question; do not claim it.
