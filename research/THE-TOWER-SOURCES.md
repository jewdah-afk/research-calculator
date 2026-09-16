# The Tower: Idle Tower Defense — formula & upgrade sourcebook

Research notes backing `tower.html` and `data/tower-data.js`.
Game: *The Tower — Idle Tower Defense* by Tech Tree Games (Android/iOS).

Everything below is sorted by **how close it sits to the game's own numbers**.
Tier A is extracted from the game; Tier B is community-maintained and
cross-checked; Tier C is prose that explains but should not be used as data.

---

## Tier A — primary data (what we actually build on)

### A1. TowerSmith "GOD tables" — the authoritative upgrade tables
- Repo: <https://github.com/AngryBrit/tower-smith> (AngryBrit, CC BY-NC-SA 4.0)
- Path: `tables/workshop/{attack,defense,utility}/*.json`, `tables/labs/**/*.json`,
  plus `tables/guardians/`, and `tables/workshop/formulas/` for stat combination.
- Shape, per Workshop stat: `{name, category, maxLevel, levels:[{level, value,
  nextCoins:{coins}, totalCoins, nextCash, cashToTarget, cashToMax}]}`
- Shape, per Lab: `{name, maxLevel, levels:[{level, value, time:{seconds},
  gems, coins, totalTime, totalGems, totalCoins}]}`
- Coverage we import: **48 base Workshop stats** and **217 Lab researches**.
- These are per-level tables, not curve fits — no interpolation anywhere.
- Refreshed upstream by `scripts/sync-lab-god-tables.mjs`.

**This is the root data source for this project.** `tools/build-tower-data.js`
reduces it to `data/tower-data.js`.

Spot-checks against the game's own upgrade display:
| Check | Expected | Ours |
|---|---|---|
| Workshop Damage L0 value | 3 | 3 |
| Workshop Damage L0→L1 cost | 30 coins | 30 |
| Workshop Damage max level | 6000 | 6000 |
| Lab Attack Speed L1 | 30 coins / 14s / 1 gem | 30 / 14 / 1 |

### A2. The game bundle, deobfuscated (via mytower.app)
The lab cost/time/gem model is not a table — it is code. It was recovered from
`index-fMZW9TWk.deobfuscated.js` and is transcribed character-for-character in
`the-tower-unified-tools/Development/tools/regression/gate-a4-lab-formula.js`,
where it is regression-tested against the published wiki tables. Identifiers
below are the bundle's own.

```js
// time-unit constants
lb=1, ub=60, db=3600, fb=86400, pb=604800, mb=2592e3, hb=7776e3, gb=31104e3

// lab speed divisor: e = Labs Speed lab level, t = relic lab-speed bonus (%)
vb = (e, t) => (1 + .02 * e) * (1 + t / 100)

// gem cost to rush a lab with t seconds remaining (piecewise linear, then ceil)
_b = t => Math.ceil(
    t > gb ? 25e3
  : t > hb ? 17e3 / (gb - hb) * (t - hb) + 8e3
  : t > mb ? 4450 / (hb - mb) * (t - mb) + 3550
  : t > pb ? 2550 / (mb - pb) * (t - pb) + 1e3
  : t > fb ?  837 / (pb - fb) * (t - fb) +  163
  : t > db ? 155.5 / (fb - db) * (t - db) +  7.5
  : t > ub ? 7.375 / (db - ub) * (t - ub) +  .125
  : t > lb ? .122917 / (ub - lb) * (t - lb) + .002083
  : 0)

// gold-box gem discount: e = gold boxes opened
$ne = .015
Sb = e => 1 + e * $ne
Cb = e => 1 / Sb(e)

// the whole lab quote
wb = ({DURATION, COST, labId: n, labSpeed: r, labDiscount: i,
       labSpeedRelicBonus: a, goldBoxes: o, percentComplete: s = 0,
       includeGems: c = !0}) => {
  let f = DURATION / vb(n === 36 ? 0 : r, a) * (1 - s)
  return {
    time:  f,
    coins: COST * (n === 35 ? 1 : 1 - i * .3 / 100),
    gems:  c ? Math.ceil(_b(f) * Cb(o)) : 0
  }
}

// Elite Cell speed-up multiplier -> 1-hour cost
bb = {1:0, 1.5:15, 2:100, 3:840, 4:3360, 5:11900, 6:6e4, 7:25e4, 8:1e6}
```

Two exemptions worth noting, both in `wb`: lab **36** (Labs Speed) is not
sped up by itself, and lab **35** (Labs Coin Discount) is not discounted by
itself.

Derived constants used by the tool:
- Labs Speed: `+2%/level`, max 99 → duration divisor up to `2.98`
- Labs Coin Discount: `-0.3%/level`, max 99 → `-29.7%` coins
- Workshop Attack/Defense/Utility Discount labs: max 99 each

### A3. Stat-combination formulas (how upgrades turn into a stat)
- Path: `tower-smith/tables/workshop/formulas/{attack,defense,utility}/*.json`
- Each file is a small pipeline spec naming every multiplier and its source,
  with a `source.binaryFunction` pointing at the game function it mirrors.

Damage, for example (`formulas/attack/damage.json`, from
`ModuleManager::get_AttackDamage`):

```
damage = base × chassis × lab × card × (1 + relics) × (1 + cannon%)
               × enhancements × perks  +  berserker
```

UW damage, from the mechanics reference:

```
UW% × (1 + core_module%) × Damage × (1 + CritFactor × CritChance)
    × (1 + SuperCritMult × SuperCritChance × CritChance)
```

---

## Tier B — community datasets, cross-checked

### B1. The Tower Unified Tools
- Repo: <https://github.com/SFleet89/the-tower-unified-tools> (CC BY-NC-SA 4.0)
- The most useful secondary source found. Ships pre-extracted JS tables
  (`The Tower Tool/js/`): `workshop-god-data.js` (per-level marginal coin costs,
  48 stats), `workshop-stat-values.js` (per-level displayed values),
  `workshop-enhance-data.js` (18 Workshop Enhancement stats, cost/value/max),
  `lab-data.js` (`ELAB_DATA`, `STD_LAB_COST`, save-file index maps),
  `tower-module-bot-data.js`, `tower-game-data.js` (cards + guardians),
  `milestone-data.js`, `relic-theme-data.js`, and an image set in
  `tower-game-images.js`.
- `Development/Docs/game-mechanics.md` is a good condensed mechanics reference.
- `Development/tools/regression/` contains the gates that verify the above
  against the bundle and the wiki — that is where A2 came from.
- Maps lab names to save-file slots: `d.researchLevel[]` is 0-indexed by key
  insertion order of the `ke={}` object in the Vite bundle.

### B2. tower-calculator
- Repo: <https://github.com/jacoelt/tower-calculator>
- Scope is narrower: in-run **battle upgrade** tables (cash costs, 13 stats) in
  `src/data/dataStrings.ts`, plus 5 lab multiplier curves. Useful precisely
  because it covers the cash/in-run side that the GOD tables index differently.

### B3. The Tower Optimizer
- Repo: <https://github.com/Tankietank/The-Tower-Optimizer>
- Progression planner with its own game-data update pipeline. Not imported;
  listed as a third independent extraction to diff against.

### B4. mytower.app
- <https://mytower.app/> — reads the same `playerInfo.dat` save. The reference
  for module sub-effects, perk indexing, and the waves↔hours model. Origin of
  the A2 bundle transcription.

---

## Tier C — prose references (mechanics, not data)

| Source | Good for | Note |
|---|---|---|
| [Fandom wiki](https://the-tower-idle-tower-defense.fandom.com/wiki/Workshop_Upgrades) | Workshop Upgrades, Lab Upgrades, Workshop Enhancement, Damage pages | Published gem-rush and Elite-Cell tables here are what A2's regression gate tests against. Blocked by our network proxy — read via mirrors. |
| [Game Vault wiki](https://the-tower-idle-tower-defense.game-vault.net/wiki/Workshop) | Workshop / Lab guides, priority ordering | Guide-grade, not data-grade |
| [Tower Hub](https://www.tower-hub.com/wiki/workshop/workshop-upgrades) | Per-level cost tables in browsable form | Handy for eyeballing a single stat |
| [Tower Lab Calculator](https://alienfusiongenerator.com/tower-lab-calculator/) | Independent lab calculator to sanity-check ours | Closed source |

Recurring warning across these sources, worth repeating: **solve cost formulas
without rounding.** Rounding intermediate steps drifts from the in-game display.

---

## Mechanics summary (condensed from B1 + C)

**Currencies.** Cash (in-run, resets) · Coins (Workshop/Lab/Modules, permanent) ·
Gems (card pulls 20 ea, module draws, lab slots, rushing) · Power Stones (UWs,
Card Mastery) · Medals (bots, event shop) · Elite Cells (lab speed boosts).

**Workshop.** Attack / Defense / Utility, all coin-priced and permanent.
Damage and Health cap at 6000, Defense Absolute 5000, Wall Health 1800,
Enemy Level Skip 699, most others 40–300. **Workshop Enhancements** unlock at
T12W60: 18 stats, ×1.00→×4.00 over 300 levels, starting around 5B coins/level.

**Labs.** 1 lab free, then 100/400/1400/3000 gems (4900 total for 5).
Boostable with Elite Cells (1.5×–5× for 1h/8h/24h; cost +20% per lab already
boosted). Rushable with gems at roughly 7.5 gems/hr, cheaper at long durations
(~5.95/hr at 1 week, ~4.93/hr at 30 days) — that taper is exactly `_b` in A2.

**Ultimate Weapons.** 9 total, bought with Power Stones, cumulative purchase
cost by count: 5, 50, 150, 300, 800, 1250, 1750, 2400, 3000. Each has 3
stone-upgradeable stats; UW+ unlocks once all 9 are owned. F2P priority
GT → BH → SL → DW → CL → SM → ILM → PS → CF.

**Bots.** 4 bots, medal-priced from the Event Shop. Upgrade cost is linear:
100 medals at level 1, +40/level (level *n* costs `60 + 40n`; cumulative to
level 20 = 9,600).

**Modules.** Unlock T2W90. 4 slots (Cannon/Armor/Generator/Core). Draw 20 gems
(200 for ×10). Common 68.5% / Rare 29% / Epic 2.5%, guaranteed Epic at 150
draws. Rare merges to Legendary+, Epic to Ancestral. Boss drops: 15% shard,
2% common, 0.5% rare, 5-wave cooldown (20 in tournaments).

**Cards.** 20 gems/pull. Common 80% / Rare 17% / Epic 3%. 21 slots for 48,400
gems total. Card Mastery at T16W100.

**Tournaments.** Wednesdays and Saturdays 00:00 UTC, 30 per bracket, 6 leagues
Copper→Legend, top 4 promote / bottom 6 demote. Primary Power Stone source.

---

## Licensing

The two datasets we build on — TowerSmith and The Tower Unified Tools — are
both **CC BY-NC-SA 4.0**. Attribution is carried in `data/tower-data.js`,
in `tower.html`, and here. Any redistribution of this project's derived data
must stay non-commercial and share-alike.

The game itself is © Tech Tree Games. This is an unofficial fan tool.

---

## Regenerating the data

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/AngryBrit/tower-smith.git
cd tower-smith && git sparse-checkout set tables src/data && cd ..
node tools/build-tower-data.js ./tower-smith
```

## Known gaps

- Workshop **Enhancements** (18 stats) are extracted upstream but not yet in
  `data/tower-data.js` — B1's `workshop-enhance-data.js` has them ready.
- **Module / bot / card** tables likewise exist in B1 but are not imported.
- The **in-run cash** upgrade curve is present in the GOD tables
  (`nextCash`, `cashToTarget`) but the tool does not surface it yet.
- Enemy health/attack scaling per tier/wave is the least well-sourced area.
