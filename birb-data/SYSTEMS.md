# Birb: systems reference (taken from the game source)

This covers every system outside the core popcorn and rebirb loop. That loop is in `CORE_FORMULAS.md`.

It uses the same source build as `CORE_FORMULAS.md`, from birbplay.com, pulled on 2026-10-06.

Large tables are in `data/`:

| File | Contents |
|---|---|
| `fish.json` | Fish |
| `rods.json` | Rods |
| `baits.json` | Baits |
| `artifacts.json` | Parrot artifacts |
| `enemy_base_stats.json` | Enemy base stats |
| `enemy_type_modifiers.json` | Per-enemy-type multipliers |
| `sacrifice_milestones.json` | Sacrifice milestone tiers |
| `quests.json` | Quest Merchant quests |

`L` is the level. "Floor" means expedition floor.

## Mining

### Helper tables

| Table | Values |
|---|---|
| `POWER_ANCHORS` | 240, 14400, 967680, 65028096, 4369888051, 293656477041, 19733715257131, 1326105665279205, then a 9th entry = 36 × the 8th |
| `VALUE_ANCHORS` | 180, 9e3, 504e3, 28224e3, 1580544e3, 88510464e3, 4956585984e3, 277568815104000 |
| `HP_TABLE` (normal ore HP per area) | 10, 100, 1e3, 1e4, 1e5, 1e6, 1e7 |
| `GIANT_TABLE` (giant HP per area) | 360, 2600, 13e4, 18e5, 21e6, 285e6, 18e8 |
| `MILESTONE_LEVELS` | 7, 17, 34, 47, 60, 73, 86 |
| `k` | 1.1 / 1.15 |
| `J[a]` | `k^(MILESTONE_LEVELS[a] − 1)` |

Helper functions:

```
anchor(table, n, g)  = table[n] if n < len, else table[last] · g^(n − len + 1)
stepped(table, L, step, g):
    lo = anchor(table, floor(L/step), g)
    hi = anchor(table, floor(L/step) + 1, g)
    return ceil( lo · (hi/lo)^((L mod step)/step) )        (geometric interpolation inside each step)
areaCurve(table, a) = max(1, table[min(a,6)] · J[min(a,6)] · 5.8^(a − min(a,6)))
```

### Mine shop upgrade costs

`n = L − 1`, where L is the current level.

| Upgrade | Cost | Effect |
|---|---|---|
| Mining Power | `stepped(POWER_ANCHORS, n, 12, 400)` | `1.1^(L−1)` |
| Ore Value | `stepped(VALUE_ANCHORS, n, 10, 30)` | `1.1^(L−1)` |
| Rupture | `ceil(2e6 · 2.7^n)` (max level 16) | full-break bonus = `0.25 + 0.05·min(15, L−1)` |
| Charged Strike | `4800 · 24^n` (max level 4) | charged-peck multiplier = `3 + min(3, L−1)` |

Mine tree node cost is `ceil(anchor(POWER_ANCHORS, area−1, 36) · (6 + branch))`, unless the node lists its own cost.

### Ores

**HP per area `a`.** For areas 0–1 it is `areaCurve(HP_TABLE, a)`. For later areas it is `areaCurve(GIANT_TABLE, a) / 32`.
- Each spawn rolls the HP between `ceil(0.9·HP)` and `floor(1.1·HP)`.
- The final HP (in hits) is `round(rolledHP · rarity.hp)`.
- A giant's HP is `areaCurve(GIANT_TABLE, a)`.

**Ore tier by area:**

| Area | 0 | 1 | 2 | 3 | 4 | 5 | 6+ |
|---|---|---|---|---|---|---|---|
| Ore | Brute | Iron | Silver | Crystal | Obsidian | Luminite | Royal |
| Crow XP base | 1 | 3 | 8 | 20 | 48 | 110 | 260 |

**Rarity.** Each ore rolls a rarity from this table. The weights are percentages for common / uncommon / rare / epic / legendary.

| Area | Weights |
|---|---|
| 0 | 88 / 12 / 0 / 0 / 0 |
| 1 | 78 / 18 / 4 / 0 / 0 |
| 2 | 68 / 24 / 8 / 0 / 0 |
| 3 | 64 / 24 / 10 / 2 / 0 |
| 4 | 58 / 27 / 12 / 3 / 0 |
| 5 | 54 / 28 / 13 / 4 / 1 |
| 6+ | 48 / 30 / 15 / 5 / 2 |

Rarity stats:

| Rarity | HP mult | Reward mult | Pity after N breaks | Unlocks at area |
|---|---|---|---|---|
| Common | 1 | 1 | — | 0 |
| Uncommon | 1.15 | 3 | 8 | 0 |
| Rare | 1.35 | 8 | 30 | 1 |
| Epic | 1.6 | 20 | 100 | 3 |
| Legendary | 2 | 50 | 250 | 5 |

Tree nodes add guaranteed rarities:
- **Rich Vein:** every 5th ore is rare or better, and uncommon-or-better ores are worth +50%.
- **Deep Survey:** every 3rd ore is rare or better, and every 12th is epic or better.
- **Crown Survey:** every 20th ore is legendary.

**Reward multiplier** = `areaReward(a) · rarity.reward · (rich bonus) · rolledHP/finalHits`, where:

```
areaReward(a) = (a<2 ? 1 : 0.8) / J[min(a,6)]
              · (1 + min(5, max(0, a−6)/12))
              · 2^min(1,a)
              · 1.6^max(0, min(6,a)−1)
              · (8.8/5.8)^max(0, a−6)
```

**Brute Ore paid per break** = `max(1, oreValue) · rewardMult · HP`.
- A golden ore with no rarity pays ×0.25.
- Giants pay through a separate formula (below).

**Ore value** = Ore Value effect × crowContracts × `1.12^crowLegacyRebirbs` × `1.05^(Royal Core Cache level)` × (2 at 6 or more evolutions) × Abyssal Treasure.
- `crowContracts` multiplies `(1 + x)` for each owned node: Crow Contract 0.10, Anvil Perch 0.12, Core Mark 0.15, Bellowed Refinery 0.18, Load-Bearing Rivets 0.20, Core-Set Armor 0.25.
- Abyssal Treasure = `1.15^L · 2^floor(L/10)`.

**Golden ore chance** = `min(0.10, min(0.06, 0.01·milestoneLevel) + 0.005·crowLegacyRebirbs)`.
- After 30 work points with no golden ore, the next one is guaranteed golden.
- A golden ore needs at least `4 · reserve` hits.

### Crow damage and speed

**Damage multiplier** =

```
(1 + damageTrack) · 1.1^(PowerLvl−1)
 · (1 + 0.04·min(4, area milestones))
 · treeDamage
 · crowRebirbDamage
 · speedOverflow
```

- `damageTrack = min(8, floor(damageTrackLevel/10))`
- `treeDamage` multiplies: Impact Transfer 1.25, Mineral Temper 1.08, Royal Impact 2, and Abyssal Forge `1.2^L · 2^floor(L/10)`.
- `crowRebirbDamage = 1.25^min(8, R) · 2^max(0, R−8)`

**Hit interval:**

```
base = max(0.24 − 0.01·min(8, R), 0.55 / ((1 + 0.015·(crowLevel−1)) · 1.06^R))
speedMult = 1.35 (Peck Rhythm) · 1.25 (Unbroken Rhythm) · 1.05 (Work Pulse)
interval = max(0.18, base / speedMult)
speedOverflow = interval / (base / speedMult)
```

Speed beyond the 0.18s floor turns into extra damage through `speedOverflow`.

**Crow XP:**
- XP needed per level = `floor(60·L^1.55 + 120·max(0, L−25)^1.25)`.
- XP per ore = `ceil(xpBase · reserve · (1 + 0.5·rank) · areaXp · (2 if golden) · (1 + 0.15·milestone) · 1.25^R · (1.25 if Field Training) · hatBonus)`.
- `areaXp = [1, 1, 2, 3, 4, 5, 6][min(a,6)] · (1 + min(2, max(0, a−6)/24))`.

**Crow rebirb** resets crow level and XP to 1 and 0.

| Rebirb # | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | then (needs Deep Rebirb) |
|---|---|---|---|---|---|---|---|---|---|
| Crow level | 3 | 5 | 7 | 7 | 10 | 12 | 16 | 20 | `20 + 5·(R−8)` |
| Giants beaten | 1 | 2 | 3 | 3 | 4 | 5 | 6 | 7 | `10 + 3·(R−8)` |

Rebirb display multipliers: `1 + 0.1·R` and `1 + 0.15·R`.

**Crow forge tracks** (armor, damage, regen):
- XP cost for the next level = `ceil(1.25e6 · (L+1)^2 · 1.1^floor(L/10))`.
- Bonus = `0.025·√L + 0.0025·L`.
- Legendary aura cost = `max(100, ceil(100 · 1.08^L))`.
- The Gold Temper split pays 60% of that in aura and the rest in gold ore at 25:1.

### Giants
- A giant respawns 60s after it is beaten.
- Brute Ore paid for a giant = `bossReward(a) · (2 at 6 or more evolutions)`:

```
bossReward(a) = a ≥ 7 ? bossReward(6) · 8^(a−6)
              : floor(nodeCost(a+1, 0) · (a < 2 ? 1 : 0.5))
```

- A first-time kill also pays gold ore.
- **Mineral Coffers:** every 6 ore breaks, a coffer pays `cofferBonus` × the income from those 6.
- After a normal break, the next ore respawns in 0.5s (0.25s with Unbroken Rhythm).
- **Idle claim:** a passive mine reward can be claimed every 15s. It pays the normal-ore reward × `min(1, 0.5 / secondsPerBreak)`.

## Nest (twigs)

### Tiers

The resource multiplier applies to all twig gains.

| Tier | Name | Twigs to build the next tier | Resource mult | Bird slots |
|---|---|---|---|---|
| 0 | Basic | 1e5 | 1 | 1 |
| 1 | Sturdy | 1e6 | 2 | 2 |
| 2 | Cozy | 1e8 | 5 | 3 |
| 3 | Grand | 2e10 | 10 | 4 |

- **Tier cap by evolution:** you can reach tier 1 with fewer than 3 evolutions, tier 2 with 3–5, and tier 3 with 6 or more.
- Expeditions unlock when tier 1 is complete. Upgrade automation unlocks at tier 2.
- **Twig multiplier** = tierMult × (1 + questMerchant twig bonus) × community goal × (2 with Watering Well) × forestryMult × (1.15 with archivist V5).
- `forestryMult = 1.08^min(40, f) · (1 + 0.08·max(0, f−40)) · 2.5^(toolTier/5) · (1 + expansion/4)^2`

### Forest trees

- **Chop damage per second** = `2.5 · 1.2^tier + axeLevel`, ×1.25 with the Nest Blades mine node.
- **Birb pecking:**
  - Hit rate = chopDPS + `0.2·peckRateLvl` (×1.25 with Nest Blades).
  - Damage per peck = `1 + peckPowerLvl`.
- **Tree spawns:** one tree every `30 / (1 + 0.5·min(4, spawnLvl))` seconds. A tree takes 180s to grow.
- **Tree HP:**

| Tree | Fresh | Growing | Mature |
|---|---|---|---|
| Normal | 12 | 12 | 12 |
| Birch | 1 | 2 | 5 |
| Autumn | 1 | 2 | 7 |

- **Twigs per hit** = `max(0.1, (1 + 0.2·twigValueLvl) · twigMult)`.
- **Offline:**
  - Efficiency = `min(0.8, 0.25 + 0.05·offlineLvl)`.
  - Offline time is capped at 8 hours.
  - The Red Panda assist mode collects at 55%.

### Twig shop

| Upgrade | Max level | Cost at current level L | Effect |
|---|---|---|---|
| Twig Value | 999 | `ceil(15 · 1.06496^L)` | +0.2× twigs per hit per level |
| Peck Rate | 20 (needs Fertilizer) | `ceil(150 · 1.18^L)` | +0.2 hits per second per level |
| Peck Power | 15 (needs Peck Rate 10) | `ceil(5000 · 2.3^L)` | +1 damage per peck per level |

### Cultivation (tree boxes)

**Box costs:**
- Boxes 1–16: `ceil(100 · 1.2^min(15, n))`.
- Evolving the boxes costs 1e9 twigs. Each specialized box then costs `ceil(2·cost16 · 1.2^n)`.
- The quad evolution costs 1e12. Each quad box then costs `ceil(2·specialCost16 · 1.2^n)`.
- Up to 8 extra expansion boxes are available.

**Box output:**
- A box yields 1 tree, 2 when specialized, or 4 when quad.
- Each tree has 12 HP, or 24 with Specialized Fertilizer.
- A tree grows in 60s, or 40s with Fertilizer, plus 3s per cycle.

**Buildings** (one-time, paid in twigs):

| Building | Cost | Effect |
|---|---|---|
| Fertilizer | 500 | Unlocks Peck Rate; trees grow faster |
| Specialized Fertilizer | 25,000 | Doubles box tree HP |
| Cornfield | 35,000 | ×2 popcorn respawn, or ×2.5 with Pollinator |
| Grain Silo | 50,000 | Popcorn ×`(1 + 3.7·log10(1 + twigs/50000))` |
| Sunflower Field | 150,000 | ×2 seeds, or ×2.5 with Pollinator |
| Watering Well | 500,000 (needs 5 evolutions) | ×2 twigs and seeds |

### Riverside

Unlocks at nest tier 3 with 6 evolutions.

| Building | Cost | Effect |
|---|---|---|
| Lumberyard | 5e5 | — |
| Pollinator | 1e7 | Cornfield and Sunflower Field become ×2.5 instead of ×2 |
| Compost | 6e7 | — |
| Grove (4 levels) | 1e8, 1.6e8, 2.4e8, 3.6e8 | — |
| Nursery | 2.5e8 | Fish breeding is ×0.75 faster |

### Carpentry

Unlocks at nest tier 3 with 6 evolutions.

**XP to reach carpentry level n:** cumulative sum of `10·round((150 + 12(n−1) + 6(n−1)^2.2)/10)`, up to level 99.

**Leveled upgrades** use a soft-capped geometric cost. Each starts from a base, with `× (1 + expansion/4)^2` applied:

| Upgrade | Twigs (base × growth) | Wood (base × growth) | Soft cap |
|---|---|---|---|
| Forestry | — | 100 × 1.3^L | 40 |
| Timber | — | 25 × 1.28^L | 25 |
| Saw | 1e6 × 1.16^L | 40 × 1.14^L | 30 |

Past the soft cap, cost grows quadratically. The code is `qe` in the maps bundle.

**Other outputs:**
- Timber yield = `1.15^min(25, L) · (1 + 0.15·max(0, L−25)) · (1 + exp/4)^2`.
- Bench output = `min(3, bench) · (1 + 0.1·saw) · (1 + exp/4)^2`.

**Fixed costs:**
- **Tools tiers** (twigs / wood / plank):

| Level | Twigs | Wood | Plank |
|---|---|---|---|
| 10 | 0 | 0 | 100 |
| 15 | 5e5 | 50 | 400 |
| 20 | 2e6 | 100 | 1e3 |
| 25 | 5e6 | 150 | 1.5e3 |
| 30 | 1.25e7 | 200 | 3e3 |
| 34 | 8e6 | 200 | 3e3 |
| 38 | 1.2e7 | 250 | 4e3 |
| 42 | 2e7 | 350 | 5e3 |
| 46 | 3e7 | 500 | 8e3 |
| 50 | 5e7 | 700 | 1e4 |
| 54 | 1.8e8 | 600 | 1.2e4 |
| 58 | 2.4e8 | 800 | 1.6e4 |
| 62 | 3e8 | 1e3 | 2.2e4 |
| 66 | 4.5e8 | 1.5e3 | 3e4 |
| 70 | 6.3e8 | 2.1e3 | 4e4 |

- **Bench tiers:** level 20 costs 8e6 / 250 / 1.5e3, and level 40 costs 6e7 / 1e3 / 1.2e4.
- **Workshop:** 600 wood.
- **Mastery and Expansion:** `(1e9 twigs, 5e3 wood, 2.4e4 plank) · (1 + e/4)^2 · (1 + e/10)`.

## Fishing

The data files list every catchable item:
- `data/fish.json`: 426 fish, with rarity, base weight, sell value, effect, minimum rod tier and type.
- `data/rods.json`: rods, with speed, moneta per catch, tier, and the fish needed to craft each one.
- `data/baits.json`: baits.

### Roll weights

Each fish's chance is its share of the pool's total weight. A fish's weight is its base weight (or its expedition catch chance on an expedition floor), then multiplied by each of these:

| Factor | Multiplier |
|---|---|
| Bridge fish above your rod's tier | ×0.15 (only fish up to rod tier + 1 are in the pool) |
| Bronze hook | uncommon ×2 |
| Iron hook | rare ×2.5 |
| Gold hook | epic ×3 |
| Diamond hook | legendary ×4 |
| Ancient hook | legendary ×4, epic ×2.5, rare ×1.5 |
| Cursed hook | common ×3 |
| Basic lure | ×3 for fish needed for your next rod. Precision Cast multiplies this by a further 1.15 |
| Advanced lure | ×3 for undiscovered fish |
| Pro lure | ×3 for fish not yet in the aquarium |
| Any non-common fish | × fishing luck multiplier |
| Bait | Narrows the pool to the bait's fish type, when that leaves any fish |

### Weight and value

**Default weight range in kg:**

| Type | Min–max |
|---|---|
| coastal | 0.1–2 |
| reef | 0.2–3 |
| freshwater | 0.15–2.5 |
| river | 0.2–4 |
| ocean | 0.5–50 |
| creature | 0.05–5 |
| exotic_reef | 0.3–4 |
| spirit | 0.01–1 |
| cosmic | 0.1–3 |
| mechanical | 1–20 |
| crab | 0.1–5 |
| abyssal | 0.3–15 |

The range is then multiplied by rarity: common 1, uncommon 1.5, rare 2.5, epic 4, legendary 8, mythic 12.

**Weight roll:**

```
l   = ((rodTier+1)/(maxTier+1))^0.9
max = min + (max−min)·l
min ×= 0.6 + 0.4·l
(Master lure ×1.25 to both; a shiny fish ×10 to max)
```

A random roll `u` picks a band `(lo, hi, curve)`:

| Roll `u` | Band | Chance |
|---|---|---|
| below 0.7 | (0.1, 0.5, 1.6) | 70% |
| 0.7–0.9 | (0.35, 0.7, 1.2) | 20% |
| 0.9–0.97 | (0.6, 0.85, 1.05) | 7% |
| 0.97–0.995 | (0.8, 0.95, 0.9) | 2.5% |
| 0.995–0.9995 | (0.92, 1, 0.8) | 0.45% |
| 0.9995 and up | (1, 1.2, 0.7) | 0.05% |

```
f      = lo + (hi−lo)·rand^curve
weight = min + (max−min)·f, clamped to [0.7·min, 1.2·max] (1.35·max if shiny)
```

The result is rounded to 0.01 kg.

**Sell value** = `floor(sellValue · (1 + log10(1 + personal best kg)) · fishValueMult · (10 if shiny))`.
- With Leviathan Mastery, `log10(1 + kg²)` replaces `log10(1 + kg)`.

**Moneta per catch** = `rod.monetaPerCatch × xp_mult × 1.5 (Moneta Current) × 2 (Moneta Ledger) × 2 (Moneta Mastery)`.
- Catches made by the seagull earn ×0.25.

**Fish effects** come from fish effect types such as `popcorn_mult`, `feather_mult` and `golden_popcorn_mult`.
- The equipped fish, aquarium modifiers, and the equipped bait, lure and hook all multiply in.
- `xp_mult` also adds a fishing-level bonus and ×2 at 6 or more evolutions.

## Sparrow

- **XP per level** = `40·L` up to level 100, then `floor(40·(100 + (L−100)^2))`.
- **Flight speed** = `150 + 2·(L−1)` px/s, capped at 2048 (×1.5 with Neural Overclock).
- **Feeding:**
  - Each seed gives `0.01` XP, multiplied by: Bird Brain ×1.25, Gourmet Snacks ×1.5, Sparrow Wisdom ×1.5, `(1 + 2·√sparrowRebirbs)`, and milestone and hat bonuses.
  - Feeding uses a chosen share of seed income (default 25%), capped at `0.25 · xpNeeded(L) / xpPerSeed` per second.
  - With Bird Brain, the seed cost is ×0.75.
- **Resonance drain** (Sparrow Resonance):
  - The sparrow loses `xpNeeded(L) · max(2, 0.1·L)` XP per second, and can drop levels.
  - The XP removed × drain milestones is added to resonanceXP.
- **Popcorn multiplier from resonance** = `1 + 2.5·ln(1 + resonanceXP/5000)/ln(40.6)`.
- **Mitosis** doubles your sparrow count (1→2→4→8→16) and resets the level to 0.
  - Total XP required: 1e4 at 1 sparrow, 1e5 at 2, 1e6 at 4, 1e7 at 8, and 1.6e7 at 16. Other counts need `5e5·count`.
  - The requirement is multiplied by milestone discounts.
- **Rebirb** is available at 16 sparrows. It goes back to 1 sparrow at level 1, and the sparrow rebirb count goes up by 1.
- **Popcorn spawn boost** = `min(10, 1 + 1.5·√sparrowRebirbs)`.
- **Milestones:**

| Milestone | Effect |
|---|---|
| 1 mitosis | Drained XP ×1.25 |
| Reach level 50 | Feed XP ×1.5 |
| 2 mitoses | Mitosis requirement ×0.8 |
| 3 mitoses | Feed XP ×1.25 |
| 1 rebirb | Drained XP ×1.25, and auto-mitosis |
| 5 rebirbs | Mitosis requirement ×0.85, and auto-rebirb |

A "mitosis" count here is `rebirbs·4 + log2(sparrows)`.

## Seagull

- **Catch interval** = `10 · 0.99^level / (1 + migrations·k)`, where:
  - `k = 0.02`, doubled at 100 migrations (Alpha), and ×(1 + 0.05·Migration Amplifier level).
  - Then × route × doctrine × forecast, ×2.5 for the specialist gull, ÷2 during a frenzy. The minimum is 0.25s.
- **Routes:**

| Route | Interval |
|---|---|
| Bridge | ×1 |
| Expedition floor 1 | ×1.18 |
| Expedition floor 2 | ×1.22 |
| Expedition floor 4 | ×1.28 |
| Expedition floor 6 | ×1.34 |

- **Doctrines:**

| Doctrine | Interval | XP | Sparrow share | Weight | Rare reroll | Rare penalty |
|---|---|---|---|---|---|---|
| Balanced | 1 | 1 | 1 | 1 | — | — |
| Hunter | 1.3 | 0.94 | 0.8 | 1.18 | 72% | — |
| Training | 1.02 | 1.45 | 2 | 0.92 | — | 56% |

- **Forecasts** add bonuses when their favored doctrine is used. Bustling Shoal, for example, gives interval ×0.88.
- **XP per catch** = `floor(baseXp · (1 + migrations·alpha·amp))`, where `baseXp` is common 10, uncommon 25, rare 50, epic 100, legendary 250.
  - Then: ×1.5 with Seagull Training, × the fish xp multiplier with Seagull Synergy, ×(1 + 0.06·Fleet Training level), × hat bonus.
- **XP to level up** = `floor(100 · 1.12^(L−1))`.
- **Level cap and migration:** the cap is 50 (100 after Reborn). Reaching the cap makes a migration available, which raises the migration count.
- **Sparrow sharing:** at 5 or more migrations, the sparrow also gets `floor(XP · (0.05, or 0.1 with Ancestral Radio) · share)`.
- **Milestones:**

| Migrations | Unlock |
|---|---|
| 1 | Frenzy |
| 3 | Second gull |
| 5 | Ancestral wisdom |
| 10 | Instinct |
| 15 | 8% echo double catch |
| 30 | Specialist gull (third gull) |
| 50 | Daily legendary every 24h |
| 75 | +0.4% shiny chance per hour |
| 100 | Alpha (×2) |

## Dave (Collared Dove, desert)

- **XP curve:** same as the Sparrow.
- **Level bonuses:**
  - Golden popcorn ×`(1 + min(10, 0.01·L))`.
  - XP gain ×`(1 + 0.08·L)` per training level.
- **Seed training** costs `floor(25000 · 4e10^(L/50))` and gives speed ×`(1 + 0.02·min(50, L))`.
- **Rebirb** needs level 100 and 250 golden popcorn collected in the cycle. Pick one branch each time:

| Branch | Effect per rebirb |
|---|---|
| Scavenger | Speed +0.3× |
| Sweep | Velocity +0.3×, pickup +20 |
| Gilded | Golden multiplier +1× |

  - Counts are capped at 100.
  - Dave rebirbs also speed up desert popcorn spawns: `min(10, 1 + 0.9·√rebirbs)`.
- **Upgrade caps:** Scan 30, Sweep 20, Instinct 15, Storm 12.
- **Forage:** pick delay = `max(0.0005, 0.18/(velocity·speed·(1.25 with Master Forager)))`. Sweep size = `8 + pickup bonus`. Burst = `min(6, 1 + floor(sweepInstinct/10))` picks.

## Red Panda

In Assist mode, the Red Panda collects twigs while you're offline or on another tab, at `0.55 ×` the companion twig rate. Offline time is capped at 8 hours.

## Evolution (feeding the castle monster)

**What it takes.** Each evolution needs you to feed the castle monster these resources:

| Evolution | Requirement |
|---|---|
| 0 → 1 | 1e7 popcorn |
| 1 → 2 | 1e10 popcorn and 1000 moneta |
| 2 → 3 | 2.5e11 popcorn and 3e7 seeds |
| 3 → 4 | 1e15 popcorn, 1e5 twigs and 1e4 moneta |
| 4 → 5 | 1e18 popcorn and 1e6 twigs |
| 5 → 6 | Rescue the Castle monster on an expedition |

- **Progress** is the average across required resources of `min(1, fed/required)`. You can evolve at 100%.
- **Cap:** 5 evolutions, or 6 after the rescue.

**What each evolution gives:**
- **At 2 or more evolutions:** popcorn, feather payout and seed rates are multiplied by `evolutionCount`.
- **Nest tier cap:** see the Nest section.
- **At 6 evolutions:** mine ore value and giant rewards ×2, and fish XP ×2.

**What an evolution resets:**
- Upgrades that are not permanent.
- Sparrow level and count.
- Feeding progress.

## Expedition: Parrot combat

### Parrot stats

```
maxHealth = (100 + hpSkill + artifactHpAdd)       × armorMult × (1+artHp%) × progressionHp × questHp × (1+finalHp) × mythicSacrifice
damage    = (100 + dmgSkill)                      × beakMult  × (1+artDmg%) × progressionDmg × questDmg × (1+finalDmg) × mythicSacrifice
lifeRegen = (0 + regenSkill + artifactRegenAdd)   × auraMult  × (1+artRegen%) × progressionRegen × questRegen × (1+finalRegen)
```

- **Skill points:** each point adds 1 to `hpSkill`, `dmgSkill` or `regenSkill`.
- **Mythic Sacrifice:** ×1.2.
- **Progression multipliers** come from these sources:
  - **Spirit Scouting:** damage +10% per level.
  - **Spirit Shell:** HP +10% per level.
  - **Spirit Momentum:** attack speed and move speed +2% per level.
  - **Oasis Recovery:** regen +10% per level.
  - **Fish effects:** `parrot_hp_mult`, `parrot_damage_mult` and the other parrot effects.
  - **Aquarium modifiers.**
- **Floor scaling:** a floor multiplier of `1 + 0.08·(floor−1)^0.6` also applies to Parrot bonuses.

### Equipment (beak, armor, aura)

Multiplier per rarity, by level 1–5:

| Rarity | Beak | Armor | Aura |
|---|---|---|---|
| Common | 0.1, 0.325, 0.55, 0.775, 1 | 1, 2, 3, 4, 5 | ½ × beak values |
| Uncommon | 1, 2, 3, 4, 5 | 5, 7.5, 10, 12.5, 15 | ½ × beak values |
| Rare | 5, 8, 12, 17, 25 | 15, 22, 32, 45, 65 | ½ × beak values |
| Epic | 25, 40, 60, 85, 120 | 65, 100, 150, 220, 320 | ½ × beak values |
| Legendary | 150, 190, 255, 340, 430 | 400, 520, 720, 1000, 1320 | ½ × beak values |

**Upgrading:**
- Levels 1→5 cost 10, 100, 500 and 1000 spirit of the item's rarity.
- Evolving to the next rarity costs 1 spirit of the next tier.
- Evolving epic to legendary costs 3 Legendary Aura, plus a mine-area gate.
- Legendary levels cost 3, 8, 24, 64 and 160 Legendary Aura, and need mine areas 1, 1, 3, 3 and 5.

**Legendary refinement level `r`:**
- **Multiplier:** `1.25^r` for r ≤ 3, otherwise `1.25^3 · (1 + 0.01·((r−3) + floor((r−3)/3)))`.
- **Mine area needed:** `4 + r` for r ≤ 3, otherwise `7 + floor((r−4)/10)`.
- **Mythic Spirit cost:** `ceil(10 · 1.08^(r−33))` once r reaches 33 or more.
- **Legendary Aura cost:** 180, 540, 1620 for the first three, then `ceil(25000 · 1.08^(r−4))`.

### Artifacts

`data/artifacts.json` lists 47 artifacts, with stats, effect IDs and English descriptions.
- **Artifact slots** = `3 + min(2, parrotRebirbs)`.
- **Infusion caps** come from the wiki and are unverified against the code:

| Rarity | Max infusion | Multiplier |
|---|---|---|
| Common | 3 | 1.36× |
| Uncommon | 5 | 1.6× |
| Rare | 7 | 1.84× |
| Epic | 10 | 2.2× |
| Legendary | 15 | 2.8× |

### Parrot XP and rebirb

**XP to the next level** = `floor(10^(2 − s/6 + 11·s²/6))`, where `s = log10(level)`.

**Parrot rebirbs:**

| Rebirb | Requires |
|---|---|
| 1st | 4 evolutions and expedition floor 3 reached |
| 2nd | Floor 7 reached |
| 3rd | The Archivist defeated |

- Each rebirb resets level, XP and skills.
- **Skill point multiplier:** ×2, ×4, ×8 after rebirbs 1, 2 and 3.
- **From rebirb 2 onward:** an extra `×(1 + 0.001·level)` on skill points, and enemy respawn delay ×0.5.

### Enemies

Base stats are in `data/enemy_base_stats.json` (43 types), and per-type multipliers are in `data/enemy_type_modifiers.json`.

Night mode treats floor F as `9 + F`.

```
f = floor
health   = round(base.health · mod.hp  · 2.4^(f−1)  · (boss ? 8    : 1)) · 1.1483^(f−1) · (boss ? 1.1  : 1)
attack   = round(base.attack · mod.atk · 1.35^(f−1) · (boss ? 1.28 : 1)) · 1.1112^(f−1) · (boss ? 1.08 : 1)
xp       = round(base.xpBase · mod.xp  · 2.05^(f−1) · (boss ? 14   : 1)) · 1.1236^(f−1)
skillPts = round(base.sp · mod.sp + floor((f−1)/2)) · (boss ? 6 : 1)
```

**Elites:** HP ×5.5, attack ×1.42, speed ×1.14, XP ×9.5, skill points ×4.5.
**Shiny enemies:** HP ×1.2 and skill points ×10.

**Respawn:** bosses respawn after 480s and elites after 300s.

**Depth-scaled HP.** Spawns deeper in a floor are tougher. A spawn's depth ratio `d` (0–1) picks one of five bands (0–0.2, 0.2–0.4, and so on). HP is rolled uniformly within the band, multiplied by the floor multiplier, and rounded to 2 significant figures.

Floor multipliers:

| Floor | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9+ |
|---|---|---|---|---|---|---|---|---|---|
| Mult | 1 | 1200 | 2.5e5 | 3e8 | 6e10 | 1.8e13 | 5.4e15 | 1.188e18 | 5.4e15 · 1200^(f−7) |

Band HP ranges, in the order 0–0.2 / 0.2–0.4 / 0.4–0.6 / 0.6–0.8 / 0.8–1:

| Floor | Band HP ranges |
|---|---|
| 1 | 18–36 / 360–540 / 1800–2400 / 9000–10000 / 45000–60000 |
| 2 | 18–36 / 100–160 / 430–560 / 1200–1800 / 4500–6000 |
| 3 | 13–17 / 140–220 / 900–1300 / 4500–7000 / 22000–30000 |
| 4 | 6–12 / 48–84 / 360–600 / 1800–2800 / 4600–6200 |
| 5 | 18–36 / 80–120 / 280–420 / 1000–1500 / 3500–5200 |
| 6 | 18–36 / 88–112 / 260–380 / 800–1200 / 2400–3600 |
| 7+ | 18–36 / 72–144 / 288–576 / 1152–2304 / 4608–9216 |

**Skill points from HP.** Base points are 3 if HP ≤ 60. Otherwise:

```
sp = max(3, round(16.61·log10(HP) − 23.23))
sp = round(sp · (HP/120)^0.14)    (when HP > 120)
```

Bosses get ×2.5.

**Floor skill point multiplier.** On floors where the multiplier varies with depth, it scales linearly with `(1−d)`.

| Floor | Skill point multiplier |
|---|---|
| 2 | ×3 below depth 0.2, ×1.5 below 0.4 |
| 3 | 2.2 to 12.9 |
| 4 | 2.4 to 6.2 |
| 5 | 2.8 to 4.4 |
| 6 | 2.0 to 2.8 |
| 7–8 | ×2 |
| 9+ | ×2.4 |

**Potion drops:** 2% per kill.

### Sacrifice (skill point milestones)

Thresholds are cumulative. The full table, including popcorn, seed, skill point, aura and parrot multipliers, is in `data/sacrifice_milestones.json`. Some tiers:

| Tier | Cost | Popcorn and seeds | Skill points |
|---|---|---|---|
| I | 450 | ×1 | ×1 |
| II | 1e4 | ×1 | ×2 |
| III | 1e5 | ×2 | ×2 |
| V | 5e5 | ×3 | ×2 |
| VIII | 1e7 | ×5 | ×5 |

- **Chest chance bonus** is soft-capped: `0.12 + 0.08·(1 − e^(−(x−0.12)/0.12))` above 0.12.
- **Soft-cap helper:** `t + t·ln(1 + (x−t)/t)`.

### Quest Merchant

`data/quests.json` lists 33 quests (19 main, the rest daily).

- **Bonus per stat** = the sum of `rewardValue` over completed main quests, plus `rewardValue × completions` for dailies.
- **Chest reward bonus** has diminishing returns past 5 completions: `n ≤ 5 → n`, else `2·√5·√n − 5`.
- **Dailies** refresh every 24h, using a seeded shuffle that picks one floor-kill, one hunt and one boss quest.
- **Stats:** seed, popcorn, twig, feather, expedition damage, HP, skill points, chest chance, chest reward, and pickup radius.

## Echo field (archivist tree)

**Echo popcorn shop:**

| Upgrade | Max level | Cost | Effect |
|---|---|---|---|
| Echo Value | 999 | See core §1 | `L` per echo popcorn |
| Echo Capacity | 10, or 20 with the expansion node | `floor(20 · 1.65^(L−1))` | `2 + 2·(L−1)` popcorn cap |

**Echo spawn chance** = `min(0.35, 0.25 + 0.05 (Echo Chance node) + 0.05 (R3 Tuning))`.

**Echo value multiplier:**

```
GoldenAscension · 3^floor(L/25) (with Value Milestones) · (R5 ? 1.4 : R2 ? 1.2 : 1) · (R6 ? 1.25 : 1) · (F1 ? 1.35 : 1) · (F2 ? 1.2 : 1)
```

`GoldenAscension = max(2.25, 1 + A(feathers)/4)` when you own Golden Ascension, otherwise 1.

**Mushroom collectors:** A1 = 1/s, A3 = 2/s, A5 = 3/s, A6 = 4/s. Reach is 320, or 400 with A4.

**Flock Memory** (V1, and V4 for the Parrot) gives XP ×`(1 + i/(i+4))` to the companions, where `i = log10(1 + lifetimeEcho/1e4)`.

**Tree nodes** (cost in echo popcorn, and the nodes each one requires):

| Node | Name | Cost | Requires | Effect |
|---|---|---|---|---|
| R1 | Nearby Response | 160 | E0 | 75% of echo spawns land near your pickup |
| R2 | Duet | 900 | R1 | +20% echo value |
| R3 | Tuning | 2e4 | R2, E3 | Echo chance 30% → 35% |
| R4 | Violet Trail | 1.2e5 | R3 | Attract echoes within 180 |
| R5 | Full Chord | 1.2e6 | R4 | Duet becomes +40% |
| R6 | Tuned Harvest | 1.8e7 | R5, E4 | +25% value |
| A1 | Awakened Mycelium | 1200 | R1 | Collector at 1/s |
| A2 | Meeting Points | 1.2e4 | A1 | Half of plain spawns appear near mushrooms |
| A3 | Underground Network | 8e4 | A2 | 2/s |
| A4 | Long Roots | 6e5 | A3 | Reach 400 |
| A5 | Coordinated Harvest | 8e6 | A4 | 3/s |
| A6 | Perfect Route | 8e7 | A5 | 4/s |
| V1 | Flock Memory | 1.8e4 | E1 | Companion XP bonus |
| V2 | Golden Memories | 9e4 | V1 | +15% desert golden popcorn |
| V3 | Echoes of the Veil | 9e5 | V2 | 10% extra Mythic Aura copy |
| V4 | Shared Knowledge | 6e6 | V2 | Flock Memory applies to the Parrot |
| V5 | Ancient Roots | 4.5e7 | V4 | +15% nest twigs |
| V6 | Deep Memory | 1.8e8 | V5, V3 | Mythic copy chance 20% |
| F1 | Resonant Grove | 1.6e8 | R6, A6 | +35% value |
| F2 | An Echo Forever | 2e8 | F1, V1 | +20% value |
