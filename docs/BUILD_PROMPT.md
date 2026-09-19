# Build prompt — 1:1 mechanical port

Paste everything below the line into a fresh session opened on this repo.
(This supersedes the earlier "vertical slice" prompt: the target is now a faithful
mechanical port, reskinned.)

---

Port the core loop of Vampire Survivors into Roblox (Luau) as a **1:1 mechanical
port**: identical stat math, curves, timings and behaviours, with entirely original
names, art and text. Mechanics first, to the decimal; art is placeholder and will be
replaced. The reference data and the verification toolchain already exist in this
repo — read them before writing any code.

## Read first, in order
1. `docs/ARCHITECTURE.md` — module map, ownership, interfaces, data flow
2. `src/shared/Types.luau` — the interface contract; build against it exactly
3. `research/vs/SUMMARY.md` — the loop, the 24 known conflicts, the gaps
4. `docs/DATA_CONVENTIONS.md` and `research/vs/SCHEMA.md`
5. The research `.md` for whatever you are building — it is the oracle

## What "1:1" means here
- Stat values, formulas, curves, wave timings, spawn rules, weapon behaviours,
  level-up rules, chest odds: **identical to the reference data**. These are
  functional systems, not protected expression, and copying them is the point.
- Names, art, audio, player-facing text: **entirely ours**. `Data.*.name` is a
  reference label. Anything a player sees comes from `src/shared/DisplayNames.luau`.
  `tools/check_no_verbatim_text.py` already guards the data; do not undo it.

## Non-negotiables
1. **Never invent a balance number.** Every constant comes from `src/shared/Data/`.
   Engine constants the research does not define (stud scale, spawn ring, cell size)
   live in `src/shared/Tuning.luau`, each with a comment saying it is NOT from the
   research. Nowhere else.
2. **`UNKNOWN` is not zero.** Read fields that can be absent through
   `Sim/DataAccess.num(value, defaultKey)`. Never `or 0`.
3. **`Sim/` is pure Luau.** No Roblox APIs. It must run under the plain `luau` CLI.
4. **Weapon `levels` are deltas**, folded by `Sim/WeaponLevels.statsAt` only.
5. **Where the research is silent or conflicted, do not guess silently.** Pick the
   value the `conflicts` entry marks authoritative (shipped data over wiki), put the
   choice in `Tuning.luau` or a comment citing the conflict, and list it in your
   final report. The 24 conflicts in `SUMMARY.md` are known; new ones are findings.
6. **Never hand-edit `src/shared/Data/*.luau`.** Regenerate from the JSON.
7. **`bash tools/check_all.sh` must exit 0 before every commit.** It runs the data
   gates, stylua, `luau-lsp analyze` in strict mode with Roblox definitions, and the
   headless mechanics tests. It passes now; keep it passing.
8. **Tests are the oracle, and their author is not the implementer.** Every `Sim/`
   function gets tests written from the research `.md` formulas, not from the code.
   A test that reads the implementation to decide what to assert is worthless.

## Scope of the port
Everything in the base-game core loop except evolutions:
- Player: all 16 stats from `Characters.luau`, per-level bonuses, recovery, armor,
  i-frames, revival, moveSpeed. One character wired; all six loadable.
- XP: gem tiers, magnet, gem merge cap, the piecewise curve with the Lv20/Lv40
  jumps, level-up pause, 3 options (4th by luck), 6 weapon + 6 passive slots,
  reroll/skip/banish plumbing (counts start at 0 — the shop is out of scope).
- All 11 base weapons with their real targeting behaviours and Lv1–8 tables.
- All 16 passives, data-driven.
- Spawner driven by every one of the 31 waves: min-on-screen, interval, roster,
  events (bat/ghost swarms, flower walls with their real chances), bosses on
  schedule, the Reaper at 1800s with one more every minute.
- Enemies: all 21 statlines, HP scaling, knockback-taken, contact damage, gems on
  death. 2048+ concurrent, structure-of-arrays, no per-enemy Instances.
- Chests from bosses with the per-minute 1/3/5 odds and Luck rule; treasure grants
  levels to owned items (no evolutions yet).
- Floor pickups and light sources with the shipped drop weights.
- HUD (timer, level, XP, HP, kills, gold, slots) and level-up UI.

**Out of scope:** evolutions, Arcanas, PowerUp shop, save data, other stages, co-op.
Leave the seams (a `WeaponBehavior` with a new id is an evolution).

## Performance
2048+ enemies at a stable frame rate. Structure-of-arrays, spatial hash, pooled
anchored parts flushed with `BulkMoveTo`, zero allocation in per-enemy loops, no
Instances in the simulation. If a research value produces something the engine cannot
sustain, keep the value and report the bottleneck — do not quietly tune it down.

## How to work
1. State the architecture you will follow (it is `docs/ARCHITECTURE.md`; say where
   you deviate and why, before deviating).
2. Build `Sim/` and its tests before anything that touches Roblox.
3. Commit in logical pieces, `tools/check_all.sh` green each time.
4. Finish with a report: every place the research was silent or conflicted and
   what you chose; every `Tuning` constant and why; and what you could not verify
   headless and therefore needs a Studio playtest.

## What I care about
Mechanical fidelity you can prove — a test per formula, citing the research line it
came from. Then that it runs at 2048 enemies. Then that it is honest about the gaps.
Fun is a playtest question and comes after; do not claim it.
