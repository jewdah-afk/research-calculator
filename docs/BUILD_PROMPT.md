# Build prompt

Paste everything below the line into a fresh session opened on this repo.

---

Build the first playable vertical slice of an original Vampire-Survivors-style
roguelite in Roblox (Luau). The reference research and the generated data modules
already exist in this repo — read them before writing any code.

## Read first
- `docs/HANDOFF.md` — what exists and where
- `research/vs/SUMMARY.md` — the core loop, known conflicts, and what drives game feel
- `docs/DATA_CONVENTIONS.md` — data conventions
- `src/shared/Data/*.luau` — the six pure-data ModuleScripts you will consume

## Non-negotiables
1. **Mechanics are copied deliberately; expression is not.** Stat values, formulas,
   curves, wave tables and weapon behaviour are carried over 1:1 on purpose — those
   are functional systems, not protected expression, and they are the point of the
   research. What must be entirely ours: **names, art, audio and any player-facing
   text.** Never display a Vampire Survivors weapon, character, item or stage name in
   the game.
   - The shipping data modules have already had all verbatim shipped prose stripped
     (221 strings) and `tools/check_no_verbatim_text.py` gates against it returning.
     Do not reintroduce it, and do not copy prose out of `research/vs/` into the game.
   - `name` fields in the data modules are **reference labels for correlating with the
     research**, not display text. Author a separate display-name table of our own
     names and render from that. A UI that reads `weapon.name` is a bug.
   - `targeting` and `passiveAbility` are our own written analysis, kept because the
     engine needs them. Implement the mechanic they describe; do not print them.
2. **Never invent balance numbers.** Every gameplay constant comes from
   `src/shared/Data/`. If something you need is `UNKNOWN` or absent, surface it and
   ask — do not substitute a plausible value.
3. **`UNKNOWN` is not zero.** It marks data genuinely absent from the source. Check
   it explicitly. Coercing it to `0` silently grants free stats.
4. **Weapon `levels` entries are deltas**, applied on top of the previous level.
5. **Display scale**: damage and health are at displayed scale (raw × 10). Do not mix
   scales; `rawPower` / `rawHealth` are the shipped values, kept for reference only.
6. **Never edit `src/shared/Data/*.luau` by hand.** They are generated. Change
   `research/vs/*.json` and run `python3 tools/gen_luau_data.py research/vs src/shared/Data`.
7. **`bash tools/run_gates.sh` must exit 0 before you commit.** It currently passes;
   keep it passing.

## Scope of this slice
A 5-minute run that is genuinely playable, not a systems skeleton. Ship these and
nothing else:

- **One character.** Our own; derive its stat line from `Characters.luau`.
- **One weapon**, auto-firing, levelling Lv1→Lv8 off `Weapons.luau` deltas. Pick one
  with a distinctive motion pattern — the targeting behaviour matters more than the
  numbers.
- **Enemy spawner** driven by `EnemiesWaves.luau`: honour `minEnemiesOnScreen` and
  `spawnIntervalSeconds` per wave. This is the single most important system for feel.
  Note the wave data has no explicit spawn-count-per-tick — you need your own model
  that satisfies the min-on-screen and interval pair; document what you chose.
- **XP, gems, and level-up**: curve from `CoreLoop.luau`, 3 upgrade options, game
  pauses on level-up, 6 weapon / 6 passive slots enforced.
- **A few passives** from `PassivesEvolutions.luau` that visibly change the weapon.
- **One arena**, flat and readable. Placeholder art.
- **HUD**: timer, level, XP bar, health.

Explicitly **out of scope** for this slice: evolutions, chests, the meta/PowerUp shop,
Arcanas, multiple stages, multiple characters, save data.

## Performance
Target 2000+ concurrent enemies. Design for it from the start — pool everything,
avoid per-enemy scripts, batch movement. Raise it with the client if the engine
approach needs a decision.

## How to work
1. Read the data modules and state the architecture you intend before building.
2. Build server-authoritative; the client renders and predicts.
3. Commit in logical pieces with `tools/run_gates.sh` green.
4. When the slice runs, say plainly what feels wrong. The research says the pressure
   curve and the XP stalls at Lv20/Lv40 are what make this genre work — if they don't
   land, that's the finding worth reporting, not a polished feature list.

## What I care about
Whether it is **fun for five minutes**. Correct data is necessary and already done;
it is not sufficient. Tell me what to change to make it feel better, and be honest if
a number from the research produces bad feel in our engine — the research is a
starting point, not an authority on our game.
