# Birb: core formulas (taken from the game source)

**Source:** the live web build at https://birbplay.com, pulled on 2026-10-06. The bundles were `game-C7SSmAJa.js`, `editors-BzRYmPQ2.js` and `maps-CcKoUYtq.js`. Every formula below was read from that code, not from the wiki.

**Conventions:**
- `L` is the upgrade's **current** level. A purchase is charged at the current level, and then the level goes up by 1.
- `floor` means round down, which the game does at the points shown.
- If the game patches, these numbers can drift. The bundle names above pin the exact version.

---

## 1. Upgrade cost function

Upgrades in the `p_`, `pr_`, `s_` and `m_` trees **start at level 1**. The one exception is `p_auric_silo`, which starts at 0 until you own Auric Blueprints. Sunflower and desert (`d_`) upgrades start at 0.

The game checks these rules in order and uses the first one that matches:

1. **Echo Value** (`p_echo_value`):
   `floor(10 · 1.35^min(24, L−1) · 1.114^min(75, max(0, L−25)) · 1.14^max(0, L−100))`, with L clamped to 1..999.
2. **Mine shop:**
   - `m_rupture` = `ceil(2e6 · 2.7^(L−1))`
   - `m_charged_strike` = `4800 · 24^(L−1)`
   - `m_ore_value` and `m_mining_power` use an anchored curve that is not decoded yet.
3. **Sunflower or desert node with `growth`** = `ceil(cost · growth^L)`.
   - **Abyssal Forge** is the one exception: `ceil(cost · 3^min(200, L) · 2.85^max(0, L−200))`.
4. **Popcorn Value** (`p_value`) = `L` when L < 5, otherwise `floor(4 · 1.3312^(L−4))`.
5. **Trees P, PR, S and M** = `floor(baseCost · costMultiplier^(L − initialLevel))`. `initialLevel` defaults to 1.
6. **Everything else** = `floor(baseCost · costMultiplier^L)`.

**Discounts:**
- If you own **Auric Bargain**, anything priced in golden popcorn costs `max(1, floor(0.75 · cost))`.
- If you own **Nature's Subsidy**, upgrades priced in sunflower seeds are free. They are still shown, but nothing is deducted.

## 2. Popcorn spawning

**Spawn interval** in seconds:

```
interval = p_speed_effect / pr_respawn_mult_effect
         / 1.2                            (if Quantum Corn)
         / max(sparrowRebirbBoost, daveBoost)
```

The parts:
- `p_speed_effect = max(0.2, 2.6 − 0.2·L)`. Level 1 gives 2.4s, and level 12 gives 0.2s.
- `pr_respawn_mult_effect = 1 + 0.5·(L−1)`
- `sparrowRebirbBoost = min(10, 1 + 1.5·√sparrowRebirbs)`
- `daveBoost` only applies in the desert: `min(10, 1 + √min(100, daveRebirbs) · 0.9)`. Everywhere else it is 1.

Each frame, the spawn timer is advanced. While `timer ≥ interval` and the field is below its cap, the game spawns a popcorn and subtracts the interval from the timer.

**Field cap:**

```
cap = floor( (2·L_capacity + auricSiloBonus) · (2 if Popcorn Silo) · (1.1 if Void Silo) )
```

- `auricSiloBonus` is `2·L_auricSilo`, and only counts if you own Auric Blueprints.
- **Popcorn Cap** is max level 40. **Silo Mastery** adds 10 levels.
- **Wing Training** is max level 20. **Wing Mastery** adds 10 levels.
- **Popcorn Mult** is max level 7. **Limit Breaker** adds 2 levels.

**Type roll.** The game picks a type with weighted random. Echo is excluded from the roll.

| Type | Base value | Weight |
|---|---|---|
| plain | 1 | 100 |
| butter | 2 | 20 (×1.5 with Butter Bonanza) |
| caramel | 10 | 5 |
| cheese | 25 | 1 (×1.5 with Cheese Factory) |
| rainbow | 100 | (0.1 + level of `f_rainbow_chance`), then ×2 with Rainbow Aura |
| red | 100 | 0.01 |
| golden | 1 | 0, so it only appears in the Desert |

**Desert golden roll.** On the desert map, each spawn is golden with chance `p` and plain otherwise.
- `p = 0` until you own Desert Core.
- With Desert Core, `p = 0.05`.
- Each of these adds **+0.025**: Gilded Kernels, Sunkissed Kernels, Mirage Kernels, Auric Glint and Gilded Dunes. With all five, `p` is 0.175.
- During a sandstorm, `p = 1`.

## 3. Popcorn value

When you collect a popcorn, you get `baseValue × totalMultiplier × collectionMultiplier`.

**Total multiplier** is the product of all of these:

| Factor | Value |
|---|---|
| Popcorn Value | `L` |
| Popcorn Mult | `2^(L−1)` |
| More Popcorn | `1 + 0.2·(L−1)` |
| Butter Hose | ×1.5 |
| Kernel Polish | ×2 |
| Fish popcorn bonus | `fishMult("popcorn_mult")` |
| Evolutions | ×`evolutionCount`, once you have 2 or more |
| Seed Synergy | `1 + 1.3·log10(1 + seeds/50000)` |
| Grain silo | `max(1, grainSiloMultiplier)` |
| Trophy Bonus | `1 + 3·log10(1 + heaviest fish weight)` |
| Sparrow drain | `sparrowDrainMultiplier` |
| Golden Butter | `1 + 0.5·log10(goldenFeathers + 1)` |
| Sacrifice | `sacrificeMultiplier` |
| Quest | `questPopcornMultiplier` |

**Collection multiplier** = room multiplayer multiplier × 5 (with Desert Fever, desert only) × 2 (with Sandstorm Harvest).

## 4. Golden popcorn value

This is the golden popcorn you get per golden drop. Each step is floored and kept at a minimum of 1.

```
g = floor(L_goldenValue · 2^(L_goldenMult−1))
g = floor(g · fishMult("golden_popcorn_mult"))
g ×= 2                        (with Treasured Harvest)
g = floor(1.5·g)              (with Gold Rush)
g = floor(g · (1 + n/3))      (n = level of Gilded Margins, max 3)
g = floor(g · duneBloom)      duneBloom = 1 + log10(seeds+1) · 2/log10(4e14+1)
g = floor(1.35·g)             (with Bloom Reservoir)
```

The code also applies Signal Smoke and Collared Dove (Dave) bonuses, but I haven't decoded those yet.

On pickup, the result is multiplied by:
- ×2 for a caramelized golden drop
- ×1.15 with archivist node V2
- ×3 with Golden Sand during a sandstorm

## 5. Rebirb (golden feathers)

```
base  = floor(popcorn / 1000)
play  = 1                                  (without Time Is Money)
      = min(10, 1 + 0.01 · playtimeMinutes)   (with Time Is Money; playtime is in seconds, divided by 60)
featherBonus = moreFeathersEffect − 1      (More Feathers effect = 1 + 0.2·(L−1))
a     = play + featherBonus
a    ×= 3   (with Golden Harvest)
a    ×= 2   (with Rebirb Manipulation)
a    ×= 1 + questMerchantBonus("feather_gain_mult")
payout = roomMult · fishMult("feather_mult") · (evolutions if ≥ 2 else 1) · auricRebirb
final  = floor(base · a · payout)
```

You can only rebirb when `final ≥ 1`.

**Auric Rebirb** (archivist node) multiplier = `1 + A(goldenPopcorn)`, where:

```
A(x) = 6·i                         when i ≤ 1
     = 6·(1 + ln(1 + (i−1))/10)    when i > 1
i    = log10(x + 1) / 16
```

**Golden Ascension** (archivist node) multiplies Echo value by `max(2.25, 1 + A(goldenFeathers)/4)`.

**What a rebirb resets:** popcorn is set to 0, the field is cleared, and every non-permanent `P` tree upgrade is wiped. Golden feathers are added, and the rebirb count goes up by 1.

## 6. Other formulas taken from the code

| What | Formula |
|---|---|
| Wing Training speed | `1 + (L−1)/19`. Level 20 gives 200%, and level 30 (with Wing Mastery) gives 252.6% |
| Magnetic Field radius | `1 + 0.2·L` (the in-game text shows `0.2·(L−1)`) |
| Golden Popcorn Mult | `2^(L−1)` |
| More Seeds | `L` |
| Sparrow | 40 XP per level. Flight speed is `150 + 2·level` px/s, capped at 2048 |
| Evolution cap | 5 evolutions, or 6 after rescuing the Castle monster |
| Seed Fertilizer | `1 + 0.8·log10(1 + feathers/20000)` |

## 7. Not decoded yet

These systems exist in the same bundles, but I haven't pulled them apart yet:
- Mine (ore value and mining power anchor curves, crow, giants)
- Nest (twigs and pecks)
- Fishing, Seagull, Parrot, Red Panda and Dave XP curves
- Combat and evolution bosses
- Expeditions, the Quest Merchant and the Sacrifice Room
- Echo field (the archivist tree generator)

---

## Appendix: Research and RLGM (from this repo's `index.html` calculator)

These formulas come from this repo's calculator, not the game source.

- Research rate is `5 · M · 1.01^L` per second.
- A research level costs `1e5 · 1.0100665756^L`.
- An RLGM level costs `1e5 · 1.122^L` and gives `1.01^L` luck.
- `M` is the product of these research boosts, which apply only when maxed:

| Group | Boosts |
|---|---|
| Playtime | 1.15, 1.25, 1.5 |
| Researcher challenge | 1.5 |
| Board upgrades 1–7 | 1.15, 1.25, 1.35, 1.45, 1.55, 1.7, 1.8 |

The achievement multiplier is also part of `M`.
