# Onslaught+: expansion design

There are two ways to play.

- **Classic** is the 1:1 remake of Onslaught 2.2 (`MECHANICS.md`). Nothing in this document changes it. Its leaderboards are "pure": only cosmetic and convenience passes apply.
- **Onslaught+** loads `expansion.json` on top of Classic. It adds:
  - 6 towers
  - 7 combos (the new colours lead them; the original recipes are untouched)
  - account progression
  - passes and products that change balance

All numbers below are in `expansion.json`. The code is `onslaught-html/expansion.js` (Luau mirror: `Expansion.luau`), and it is tested by `onslaught-html/test/expansion_test.js`.

## 1. How the balance was set
1. **Measure the originals at max level** (`test/balance.js` prints this):

   | Tower | Total cost | DPS at max | DPS per $ |
   |---|---|---|---|
   | Blue | 11 960 | 184 000 | 15.4 |
   | Green | 11 305 | 110 833 | 9.8 (+ chain) |
   | Red | 16 790 | 227 500 | 13.5 |
   | Yellow | 9 375 | 90 000 | 9.6 (+ slow) |
   | Sniper / Fusion / Railgun | ~55 000 | 37–55 M | 700–1000 |

2. **Price the new towers into the same band.** Single-target DPS per dollar for each new tower, at max:

   | Tower | DPS per $ | Effective after its gimmick |
   |---|---|---|
   | Orange Mortar | ≈ 5 | ≈ 2.5 targets per blast, so ≈ 13 |
   | Violet Arc | ≈ 6 | chain multiplier up to ≈ 2.7 |
   | Cyan Cryo | – | does no damage |
   | Gold Vault | – | does no damage |

3. **Check with the bot** (`node test/balance.js 3`). It plays Medium on Classic map 1 and builds only the listed towers, cheapest upgrade first, with at most 24 towers and no modifiers. Average wave reached:

   | Plan | Wave | | Plan | Wave |
   |---|---|---|---|---|
   | Red only | 37.0 | | Violet only | 37.0 |
   | Blue only | 32.3 | | Orange only | 30.0 |
   | Green only | 31.0 | | Yellow only | 27.7 |
   | Red + 2 Blue | 34.7 | | Orange + 2 Red | 33.0 |
   | Violet + Green | 32.0 | | Blue + Cyan | 28.0 (the bot doesn't value slow) |

   The first pass had Violet at 39.7. Its jump falloff went from 0.75 to 0.65, its base jumps from 2 to 1, and its damage and rate upgrade costs rose ×1.4. Orange went from 29 to 30 with +15% damage, faster shells and a better rate curve.

## 2. New towers
| Tower | Cost | Unlock | What it does |
|---|---|---|---|
| **Orange Mortar** | 45 | Level 2 | Lobs a shell at where the target is now (360 px/s, can't hit within 60 px). Small blast (100 px). Damage 35 → 59 800. Range 230 → 350. Rate 22 → 75/min. |
| **Cyan Cryo** | 60 | Level 4 | Every pulse, everything in range is held to at most `base speed / strength`. Strength 1.25 → 2.0. Doesn't stack, does no damage, and damage modifiers don't affect it. |
| **Violet Arc** | 75 | Level 7 | Chain lightning: 1 extra jump (+1 per 2 rate levels, max 4), 70 px between jumps, 65% damage per jump, 0.5 slow. |
| **Gold Vault** | 250 | Level 10 | When a wave is sent, pays its owner `min(cap, rate% × cash)`. Cap 60 → 40 000; rate 2% → 5%. Max 3 per player. |
| **Command Beacon** | 6 000 | Level 14 + 1 800 kills | Modifier: turrets in range get −25% combo recharge and +20% combo damage. Doesn't stack. |
| **Orbital Strike** | 25 000 | Level 18 + 2 000 kills | Strikes the strongest attacker anywhere: a 190 px blast every 10 s (6 s maxed). 20 M → 160 M. |

## 3. New combos
The new colours lead these. Partners count the same way as in the original: other ready, max-damage turrets within 70 px.

| Lead | Needs | Combo | Effect | Recharge |
|---|---|---|---|---|
| Orange | 2 Red | Carpet Bomb | 10 medium blasts × 6 M walking back up the road, 120 ms apart | 8 s |
| Orange | Cyan | Cryo Shell | poison blast (190 px) 12 M, speed ÷3 | 7 s |
| Orange | Violet | Ion Mortar | large blast 9 M + 8 arcs × 2 M | 6 s |
| Cyan | Yellow + Green | Absolute Zero | everything within 160 px drops to minimum speed (+2/s recovery, as usual) and takes 3 M | 15 s |
| Cyan | Blue | Frost Mine | landmine, poison blast 10 M, speed ÷4 | 6 s |
| Violet | 2 Yellow | Ion Field | a 100 px field for 3 s, arcing 1.5 M at everything inside every 200 ms | 12 s |
| Violet | Green link | Storm | 12-jump chain, no falloff, 3 M + the green's link damage | 5 s |

## 4. Account progression (both modes earn it; only Onslaught+ uses it)
- **XP per game:** `Σ_{w=1..wave} w × diff × 0.1 + kills × 0.2`. Difficulty multipliers: Easy 1, Medium 1.3, Hard 1.7, Extreme 2.2; Sandbox gives 0. Winning a challenge adds +500. Example: Medium to wave 40 with 400 kills ≈ 187 XP.
- **Levels:** level L → L+1 needs `100 + 40 × L^1.6` XP. That's 140 for level 1, about 1 000 by level 10, and about 4 400 by level 40.
- **Clearance (prestige):** at level 50, reset to 1 for a permanent +5% XP and Intel per tier, with no cap. Lifetime totals are stored with EternityNum.
- **Intel (soft currency):** `floor(wave^1.4 × diff / 4 + kills / 20)`. Medium wave 40 gives ≈ 61.
- **Research lab** (Onslaught+ only). Every line is small and capped, so the game keeps its feel:

  | Research | Effect | Max | Cost |
  |---|---|---|---|
  | Field Funds | +$5 start | +$50 | 40 × 1.55^L |
  | Salvage Rights | +1% resale | 80% | 60 × 1.6^L |
  | Bunker | +1 life | +5 | 400 × 2.2^L |
  | Combo Theory | −1.5% recharge | −15% | 120 × 1.65^L |
  | Bounty Hunter | +1% bounty | +10% | 200 × 1.7^L |
  | Colour Mastery ×6 | +1% damage per colour | +10% each | 50 × 1.5^L |

- **Daily quests:** 3 a day from a pool of 8 (kills by colour, combos, nukes, wave targets, challenge wins, flawless runs). Each pays 120–300 Intel and 150–400 XP.
- **The original unlocks are kept:**
  - Extreme: 2 000 kills in a normal game.
  - Sandbox: 4 000 kills on Medium.
  - Super Sandbox: 4 000 kills on Hard.
  - Challenges are open from the start.

## 5. Game passes (Robux)
| Pass | R$ | Applies in | Effect |
|---|---|---|---|
| VIP | 399 | both | +25% XP & Intel, VIP tag/nameplate, gold turret skins, +1 quest reroll a day |
| Speed Demon | 199 | both | 3× and 5× speed (1× and 2× are free) |
| Commander Tools | 249 | both | auto-upgrade queue per turret, saved build blueprints per map |
| Instant Clearance | 349 | both | Extreme, Sandbox and Super Sandbox open now |
| Supply Line | 299 | Plus | +$50 start, +10% bounty |
| Double Intel | 449 | Plus | ×2 Intel forever |
| Combo Master | 499 | Plus | −15% combo recharge (strong) |
| Arsenal Pass | 799 | Plus | all expansion towers from level 1; Beacon/Orbital kill requirements halved (the strongest pass) |
| Retro Flash Skins | 99 | both | the original 2008 look |
| Neon Skins | 199 | both | glowing turrets and beams |

## 6. Developer products
| Product | R$ | Effect |
|---|---|---|
| Supply Drop S / M / L | 29 / 79 / 199 | cash = 10 × wave × 5 / 15 / 40 (scales with the game) |
| Extra Life | 25 | +1 life, max 5 per game |
| Second Chance | 99 → 199 → 399 | on game over: 5 lives, field cleared; price doubles per use in a game |
| Airstrike | 49 | a 250 px blast: max(60 M, 3 × current attacker HP) |
| Time Freeze | 39 | every attacker stops for 8 s |
| Intel ×500 / ×1 500 / ×4 000 / ×12 000 | 49 / 129 / 299 / 799 | |
| XP Boost (1 h) | 59 | ×2 XP |
| Party Boost | 149 | ×2 Intel for everyone in the server, 30 min |
| Quest Reroll | 15 | swap one daily quest |

**Fairness:** a run that used any in-game product is flagged **assisted** and kept off the Plus leaderboard. Classic ignores every balance pass and every product.

## 7. Co-op (1–4 players)
- **Shared:** the map, the waves, and the lives (10 + the best Bunker research among the players).
- **Cash:** each player has a wallet and starts with the mode's starting cash plus their own Field Funds and Supply Line. Kill bounty is split evenly, so a party earns the same total as one player in the original.
- **Turrets:** each turret belongs to whoever built it. Only the owner can upgrade, move or sell it. Combos, chains and modifiers work across owners.
- **Leaving:** if a player leaves, their turrets and cash pass to the next player.
- **Controls:** the host picks the mode and map, and controls speed and pause. Anyone can send the next wave.
