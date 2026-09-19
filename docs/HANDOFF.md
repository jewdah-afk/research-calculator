# Handoff — getting this into Roblox Studio

Everything below is on branch `claude/vampire-survivors-mechanics-y1l323`
of `jewdah-afk/research-calculator`.

---

## 1. What exists, and where

### Reference research — `research/vs/`
Mechanics data for an original roguelite. Numbers are **reference points for deriving
our own balance**, not values to ship verbatim. No names, art or audio were copied.

| File | Contents |
|---|---|
| `SUMMARY.md` | **Start here.** Core loop on one page, all 24 conflicts, gaps, and a ranked view of what drives game feel |
| `SCHEMA.md` | Key-naming conventions shared by every JSON file |
| `core_loop.{md,json}` | 30-min run, XP formula + table to Lv100, level-up, slot limits |
| `characters.{md,json}` | 6 starters: base stats, per-level bonuses, unlocks |
| `weapons.{md,json}` | 11 weapons: base stats + full Lv1–8 delta tables |
| `passives_evolutions.{md,json}` | 16 passives, 32 evolutions with evolved stat lines |
| `enemies_waves.{md,json}` | 31 Mad Forest waves, 21 enemies, events, boss/chest schedule |
| `pickups_meta.{md,json}` | Pickups, drop weights, chest odds, 29 PowerUps, Arcanas |
| `PIPELINE.md` | How the multi-agent build/QA loop works and what it can't judge |

The `.md` files are for reading. The `.json` files are the **source of truth** the
Luau modules are generated from — edit JSON, never the `.luau`.

### Generated game data — `src/shared/Data/`
Six pure-data ModuleScripts. All six pass every gate.

`Characters.luau` · `CoreLoop.luau` · `EnemiesWaves.luau` ·
`PassivesEvolutions.luau` · `PickupsMeta.luau` · `Weapons.luau`

Each returns a frozen table shaped:
```lua
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
Weapons.data.whip.baseDamage        --> 10
Weapons.data.whip.levels            --> per-level DELTA entries
Weapons.UNKNOWN                     --> sentinel for "absent in source data"
Weapons.conflicts / .unknowns / .sources / .notes   --> provenance
```

### Tooling — `tools/`
| File | Purpose |
|---|---|
| `run_gates.sh` | **The single entrypoint.** Runs all six gates, exits non-zero on any failure |
| `gen_luau_data.py` | Regenerates the Luau from the JSON. `python3 tools/gen_luau_data.py research/vs src/shared/Data` |
| `check_luau_fidelity.py` | Every numeric literal must exist in the source JSON |
| `check_coverage.py` | Every source value must survive into the module |
| `check_structure.py` | Shape + referential integrity (ids resolve) |
| `check_determinism.py` | Regeneration must be byte-identical |
| `luau_dump.py` | Parses generated Luau back into Python (used by the gates) |

### Pipeline — `.claude/workflows/build-qa-loop.js`
Reusable multi-agent build + QA loop. See `research/vs/PIPELINE.md`.

---

## 2. Getting it into Studio

`default.project.json` (repo root) is a Rojo config mapping
`src/shared` → `ReplicatedStorage.Shared`.

**Recommended — Rojo:**
1. Install Rojo: https://rojo.space/docs/v7/getting-started/installation/
   (VS Code extension, or `cargo install rojo`, or the Aftman/Rokit toolchain)
2. Install the **Rojo plugin** in Studio (Plugins → Marketplace → "Rojo").
3. Clone the repo and check out the branch:
   ```
   git clone https://github.com/jewdah-afk/research-calculator.git
   cd research-calculator
   git checkout claude/vampire-survivors-mechanics-y1l323
   ```
4. `rojo serve` in the repo root.
5. In Studio: Rojo plugin → **Connect**. `ReplicatedStorage.Shared.Data` appears with
   the six ModuleScripts, and stays live-synced as files change.

**Without Rojo (quick look):** create `ReplicatedStorage → Shared → Data` folders by
hand, add a ModuleScript per file, paste the contents in. Fine for a look; painful to
maintain, and you lose regeneration.

**Sanity check once connected** — run in the command bar:
```lua
local W = require(game.ReplicatedStorage.Shared.Data.Weapons)
print(W.data.whip.name, W.data.whip.baseDamage, #W.data.whip.levels)
```

---

## 3. Before you build

Two conventions the data relies on. Both are already applied consistently; breaking
either silently corrupts balance.

- **Display scale.** Damage and health are stored at displayed scale (shipped raw × 10).
  `rawPower` / `rawHealth` keep the shipped values. Pick one and never mix.
- **`UNKNOWN` is not zero.** It marks a value genuinely absent from the source. Never
  coerce it to `0` — check it explicitly, or the weapon gets free stats.
- **Weapon `levels` are deltas**, applied on top of the previous level, not absolutes.
- **`name` is a reference label, not display text.** All verbatim shipped prose has
  been stripped from `src/shared/Data/` (it remains in `research/vs/` for reference).
  Mechanics and numbers are copied deliberately; names, art, audio and player-facing
  text must be entirely ours. `tools/check_no_verbatim_text.py` gates this.

Per `SUMMARY.md`, the things that actually drive the feel, in order: the **pressure
curve** (10 → 300 enemies, spawn interval 1.0s → 0.1s), the **XP curve's two stalls**
at Lv20/Lv40, and **distinct weapon motion patterns**. Enemy stats are nearly trivial —
density over time is the game.

---

## 4. The build prompt

Paste `docs/BUILD_PROMPT.md` into a fresh session opened on this repo.
