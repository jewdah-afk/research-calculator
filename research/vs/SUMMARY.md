# Vampire Survivors — mechanics reference summary

Reference data for designing an original Roblox roguelite. **Mechanics only** — no names,
art, audio or assets were copied, and none should be. All numbers are reference points for
deriving our own balance, not values to ship verbatim.

Scope: base game, v1.16, no DLC. Retrieved 2026-09-19.

| File | Topic | State |
|---|---|---|
| `core_loop.md` / `.json` | Run timer, XP curve, level-up, slots | Complete |
| `characters.md` / `.json` | 6 base starters | Complete |
| `weapons.md` / `.json` | 11 base weapons, Lv1–8 tables | Complete, cross-validated |
| `passives_evolutions.md` / `.json` | 16 passives, 32 evolutions | Complete |
| `enemies_waves.md` / `.json` | Mad Forest 31 waves, 21 enemies | Complete |
| `pickups_meta.md` / `.json` | Pickups, chests, gold, 29 PowerUps, Arcanas | Complete |
| `SCHEMA.md` | Shared JSON conventions | — |

---

## Sourcing — read this before trusting a number

This session's egress policy returned **403 on every wiki, Fandom, Steam and community
domain**. The research pivoted to the game's **shipped balance data**, mirrored on
`raw.githubusercontent.com` at `SurvivatonsAndMore/VampireSurvivorsFiles`,
`Data/Vampire Survivors/` (`Weapon.json`, `Enemy.json`, `Stage.json`, `Item.json`,
`PowerUp.json`, `Props.json`) — a community rip, ripped with VampireUnpacker, game v1.16.

This is a **better** source than the wikis: it is the data the game actually runs on, and it
corrected several wiki errors (see below). Every value carries a `sourceIds` tag, so
shipped-data values (`game-data-v1.16`) are distinguishable from wiki-derived ones
(`websearch-*`, which were never fetched as full pages, only as search summaries).

Where a field is tagged only to a `websearch-*` source, treat it as **unverified**.

---

## Core loop in one page

- **Run**: 1800 s (30:00). At 1800 s a Reaper spawns, +1 each further minute, unbounded.
  Reaper is not meant to be killed. Surviving pays 500 gold, +100 per unused Revival.
- **XP**: gems dropped per kill, scaled by Growth. Curve is piecewise —
  `5 + 10(n-1)` to Lv20, `195 + 13(n-20)` to Lv40, `455 + 16(n-40)` beyond,
  plus one-off jumps of +600 at Lv20 and +2400 at Lv40. Full table to Lv100 in `core_loop`.
- **Level-up**: pauses the game, offers 3 options (4th at roughly `luck/(100+luck)`).
  Reroll / Skip / Banish are unlocked as meta PowerUps, +2 uses per rank, 5 ranks each.
- **Slots**: 6 weapons + 6 passives. Full slots means upgrades only. Weapons max at Lv8,
  passives at Lv5 (Duplicator and Tiragisú at 2).
- **Evolution**: max-level weapon + its passive, claimed from a boss treasure chest.
  The common "only after 10:00" rule is **not universal** — see below.
- **Pressure curve** (Mad Forest): min enemies on screen ramps 10 → 300, spawn interval
  tightens 1.0 s → 0.1 s from minute 14. Six deliberate spikes to 300 concurrent enemies.
- **Meta**: gold from coins and chests (scaled by Greed) buys 29 PowerUps across 125 ranks.

---

## Flagged conflicts

24 recorded across the six files. The ones that change design decisions:

### Unresolved — decide before building

1. **The ×10 display scale.** Wikis give Zombie HP 10, shipped data says 1. Wikis give
   Reaper 655350, shipped says 65535. Independently, weapon `power` is stored as a
   multiplier where displayed damage = `power × 10` (Knife 0.65 → 6.5). Two agents found
   the same factor in different files. **Inference, not stated by any source:** the shipped
   data uses a uniform ÷10 internal scale for both damage and health, so the two sets are
   consistent with each other and this is display scaling rather than disagreement.
   Both values are stored. Pick one convention globally and apply it to damage *and* health.
2. **Crit is innate, not Arcana-granted.** Shipped: Whip 20%/2×, Axe 30%/2×, Knife 30%/3×
   as base weapon properties. Wikis describe 20%/4× and 30%/4× via the Slash (XVI) Arcana,
   and never mention Knife crit. Affects whether crit belongs in the weapon layer or the
   meta layer.
3. **Vandalier / Phieraggi union requirements.** Shipped data marks only *one* source
   weapon as needing max level; wiki and community say *both* do.
4. **Hollow Heart stacking.** Shipped: additive +20%/level (+100% at max).
   Fandom: ×1.2/level compounding (+148.8%). Additive taken as authoritative.
5. **Luck's effect on drop weights.** Shipped data flags `isRare` on 7 of 13 light-source
   drops — and *not* on Little Clover, contradicting the wiki's "everything except Gold Coin
   and Coin Bag". The data says *which* entries Luck affects, never *by how much*.

### Resolved in favour of shipped data (wikis were wrong)

- Santa Water cooldown **4.5 s**, not 3.0. Fire Wand base amount **3**, not 1.
- Santa Water duration deltas **+0.5 / +0.25 / +0.25**.
- Max Health PowerUp is **additive +10%/rank**, not ×1.1 compounding.
- Magnet PowerUp is **additive +25%/rank**, not ×1.25 compounding.
- Runetracer pool limit 50, not 25.
- Treasure chest odds are configured **per stage-minute**, not per boss as the wiki states.
- Attractorb's per-level magnet is **non-uniform** (0.5, 0.33, 0.25, 0.2, 0.33), not a flat
  +20%/level.

### Scope ambiguity — yours to decide

PowerUp count is 24 / 27 / 29 depending on version. The v1.16 set includes Omni, Charm,
Defang, Recycle, Antipiretic, Invul Time and four Seals — later base-game updates, not DLC.
A strict "launch base game" reading gives a smaller set. Total cost to max all is
7.8M / 27.1M / 31.2M across those versions; the fee term dominates at 125 ranks.

---

## Known gaps

Everything below is `null` in the JSON and listed in each file's `unknowns`. Nothing was guessed.

- **Spawn count per tick** is not an explicit field — spawning is driven by the
  `minimum` (enemies on screen) + `frequency` (interval) pair. Our engine needs its own model.
- **Swarm and wall internals**: BAT_SWARM / GHOST_SWARM enemy counts, FLOWER_WALL geometry.
- **The `HP_x_Level` formula** and how each enemy's own `level` field feeds it.
- **The Luck → chest-tier and Luck → rare-drop multipliers** (the *shape* is known:
  `successChance = levelChance × totalLuck`, `totalLuck = displayed% + 100`).
- **End-of-run payout formula** beyond `500 + 100 per unused Revival` (wiki-sourced).
- **The 10:00 chest rule and its exceptions** — not present in the data files, unverified.
- Per-rank effects of Antipiretic and Invul Time (empty description strings in shipped data).
- XP per individual gem sprite (only tier ranges recovered).

Two non-blocking notes: `Arcana.json` contains `//` comments and is not strict JSON.
The shipped per-enemy `knockback` field is knockback-**taken** (higher = knocked further,
0 = immune) — the inverse of what `SCHEMA.md`'s `knockbackResistance` key implies. The raw
value is stored under that key. **Rename the key before generating Luau**, or the sign will
be inverted throughout.

---

## Recommendations — what actually drives the feel

Ranked by how much each contributes to the VS core loop, for prioritising our own systems.

1. **The pressure curve, not the enemy stats.** The 10 → 300 concurrent ramp with the
   interval tightening to 0.1 s is what creates the power-fantasy arc. Enemy statlines are
   almost trivially simple (Zombie: 1 HP, 10 power, 100 speed) — the feel comes from
   *density over time*. Our engine already handles 2048+ enemies, so this is where to spend
   tuning effort. Replicate the curve shape; the numbers can be ours.
2. **The XP curve's deliberate stalls.** The one-off +600 at Lv20 and +2400 at Lv40 are the
   pacing skeleton — they gate the mid-run power spike. Reproduce the *shape* (smooth ramp
   punctuated by two hard walls) even with different magnitudes.
3. **Weapon behaviour over weapon numbers.** Each weapon's targeting rule (closest enemy,
   random, facing direction, orbit, aura, sky-drop, bounce, boomerang) is what makes builds
   feel distinct. The per-level deltas matter far less than having 6+ genuinely different
   *motion patterns*. This is the highest-leverage design work.
4. **Evolutions as the run's payoff.** The max-weapon + passive + chest structure gives the
   run a goal beyond survival. Note the shipped data confirms Mad Forest's minute-one chest
   carries `EVOLUTION` in slot 0 with a guaranteed `AMOUNT` prize — so an evolution at 60 s
   is possible. The "10:00 gate" is a per-minute config, not a global rule; treat it as a
   tunable, which is more flexible than the wiki framing suggests.
5. **The 6+6 slot limit.** Forced scarcity is what makes level-up choices meaningful.
   Cheap to implement, disproportionate effect on decision quality. Do not raise it.
6. **Meta progression last.** The PowerUp shop is a retention layer, not a feel layer. Its
   fee formula (`initialPrice × rank` + `floor(20 × 1.1^totalBought)`) is order-independent
   in total, so it is safe to implement late without disturbing anything else.

One shipped-data curiosity worth copying deliberately or not at all: Mad Forest's 300 s
Flower Wall event has `chance: 0` and **never fires**. Anyone reconstructing the stage from
wiki descriptions would include an event the game does not run.
