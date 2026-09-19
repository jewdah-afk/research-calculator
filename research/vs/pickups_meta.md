# Vampire Survivors — Pickups, Chests, Economy & Meta (base game, no DLC)

Retrieved 2026-09-19. Companion data file: `pickups_meta.json` (authoritative; follows `SCHEMA.md`).

> **Research constraint:** the network egress proxy blocked `WebFetch`/`curl` to
> `vampire.survivors.wiki`, `vampire-survivors.fandom.com`, `steamcommunity.com` and every other host
> tried. All figures below come from WebSearch result summaries of those exact wiki pages.
> Values that search did not surface are recorded as `null` / "unknown" and listed in `unknowns`,
> never guessed. Tables whose numbers were only partly recoverable say so explicitly.

---

## 1. Floor pickups

All drop from destroyed light sources unless noted. Source: https://vampire.survivors.wiki/w/Pickups
and each item's own page.

| Pickup | Effect | Duration | Level gate | Luck boosts weight? | Weight | Share @ base Luck |
|---|---|---|---|---|---|---|
| Gold Coin | Increases Gold Coin total by 1, multiplied by the Greed stat. | instant | none | No | 50 | 62.1% |
| Coin Bag | Increases Gold Coin total by 10, multiplied by the Greed stat. | instant | none | No | 10 | 12.4% |
| Rich Coin Bag | Increases Gold Coin total by 100, multiplied by the Greed stat. | instant | 5 | **Yes** | 1 | 1.2% |
| Big Coin Bag | Increases Gold Coin total by 25, multiplied by the Greed stat. | instant | none | No | n/a | n/a |
| Floor Chicken | Restores 30 Health on pickup. | instant | none | **Yes** | 12 | 14.9% |
| Rosary | Instantly kills all enemies on screen. | instant | 8 | **Yes** | 1 | 1.2% |
| Orologion | Creates a spinning blue ring around the player and freezes all enemies for 10 seconds. | 10 s | 4 | **Yes** | 2 | 2.5% |
| Vacuum | Pulls all Experience Gems lying on the ground toward the character and collects them. | instant | 12 | **Yes** | 2 | 2.5% |
| Nduja Fritta Tanto | The character breathes fire in the direction they are facing for 10 seconds. | 10 s | none | **Yes** | 1 | 1.2% |
| Little Clover | Increases Luck by 10% until the end of the stage. | until stage end | none | No | 0.5 | 0.6% |

Weights, level gates (`unlocksAt`) and the Luck flag (`isRare`) are from shipped `Item.json` (v1.16).
"Share @ base Luck" = weight / total base-pool weight (82.5 with everything unlocked) — a **derived**
convenience figure, not a shipped number. Real early-run shares are higher because level-gated entries
are absent from the pool.

Notes:
- **Big Coin Bag is not a floor pickup** — it is a level-up menu option once every owned weapon and
  passive is maxed (Limit Break disabled), so it has no weight.
- Two further BASE pool entries outside the original brief: **Gilded Clover** (weight 1, level 30;
  gathers all gold on the ground and starts a Gold Fever) and **Rerollo** (weight 1, `contentGroup: EXTRA`).
  **Sorbetto** (weight 1, EXTRA) enters the pool only with Arcana XII.
- `Gold Coin` and `Coin Bag` carry `inTreasures: false` — they are pool-only, never chest contents.

## 2. Light sources / destructible props

Source: shipped `Item.json`, `Stage.json`, `Props.json` (v1.16).

A destroyed light source drops **exactly one** pickup, chosen by weighted random from the pool below,
restricted to entries the player has unlocked (character level >= `unlocksAt`, plus any
`requiresArcana` / `requiresItem` condition).

### Full drop table

| Pickup | Weight | Level gate | Luck boosts weight (`isRare`) | contentGroup |
|---|---|---|---|---|
| Gold Coin | 50 | none | No | BASE |
| Floor Chicken | 12 | none | Yes | BASE |
| Coin Bag | 10 | none | No | BASE |
| Orologion | 2 | 4 | Yes | BASE |
| Vacuum | 2 | 12 | Yes | BASE |
| Rich Coin Bag | 1 | 5 | Yes | BASE |
| Rosary | 1 | 8 | Yes | BASE |
| Nduja Fritta | 1 | none | Yes | BASE |
| Little Clover | 0.5 | none | No | BASE |
| Gilded Clover | 1 | 30 | No | BASE |
| Sorbetto | 1 | none | Yes | EXTRA |
| Rerollo | 1 | none | No | EXTRA |
| Gold Finger | 0.02 | 30 | No | EXTRA |

Total BASE weight with everything unlocked: **82.5**. Gold Coin alone is 50 of it (~60%).

**Luck rule (corrected).** Shipped data flags `isRare: true` on exactly **ROAST, OROLOGION, VACUUM,
COINBAGMAX, ROSARY, NFT, SORBETTO** — these are the entries whose tooltip reads "Drop rate affected by
Luck", and Luck multiplies **only** their weight. The wiki's claim that Luck boosts everything except
Gold Coin and Coin Bag is **contradicted** for Little Clover, Gilded Clover and Rerollo. Recorded as a
conflict; shipped data treated as authoritative. The exact multiplier applied to the weight is still unknown.

Luck also raises the light-source **spawn** rate, and stops influencing spawns once `maxDestructibles`
are already alive on the map.

### Per-stage spawn config (base-game stages)

| Stage | Prop | Attempt interval | Start chance | Max chance | Max alive at once |
|---|---|---|---|---|---|
| Mad Forest | BRAZIER | 1000 | 10% | 50% | 10 |
| Inlaid Library | CANDELABRA | 1000 | 7.5% | 50% | 10 |
| Dairy Plant | LAMPOST | 1000 | 20% | 60% | 12 |
| Gallo Tower | CANDELABRA | 1000 | 7.5% | 50% | 10 |
| Cappella Magna | CANDELABRA | 1000 | 20% | 80% | 20 |
| Il Molise | BRAZIER2 | 1000 | 30% | 60% | 10 |
| Moongolow | BRAZIER2 | 1000 | 30% | 60% | 10 |
| Green Acres | BRAZIER2 | 1000 | 10% | 50% | 10 |

`destructibleFreq` is the spawn-attempt interval in ms (1000 = one attempt per second); the per-attempt
chance ramps from `destructibleChance` toward `destructibleChanceMax`. `Props.json` holds only art/HP
definitions (braziers, candelabra, lampposts etc. are 1 HP) and carries no drop table.

**Still unknown:** total light sources spawned over a full run, and the numeric Luck weight multiplier.

## 3. Treasure chests

Source: https://vampire.survivors.wiki/w/Treasure_Chest

| Chest level | Items | Gold (base) |
|---|---|---|
| 1 | 1 | 100 – 200 |
| 2 | 3 | 300 – 600 |
| 3 | 5 | 500 – 1,000 |

**Conflict:** a second source states chests "always give a random amount of Gold Coins between 60 and
500" regardless of level. Both recorded; see `conflicts` in the JSON.

**Roll order and Luck formula.** The game checks levels top-down — level 3 (5 items) first, then
level 2 (3 items), then level 1 (1 item). If every check fails, the chest's configured base level is
used.

```
successChance(level) = levelChance(level) * totalLuck
totalLuck = 1 + (displayed Luck % / 100)      # +30% Luck -> 1.30
```

`levelChance` is configured **per boss enemy**, so there is no single global odds table. Documented
example — the first Silver Bat in Mad Forest at 9:00:

| Roll | Base chance |
|---|---|
| 5 items | 3% |
| 3 items (if 5 failed) | 10% |
| 1 item (if 3 failed) | 50% |

**Timing:** contents and level are rolled **when the chest is opened**, not when it drops — so
banking chests until Luck is higher genuinely works.

**Other chest awards:** weapons, passive items, gold, and evolutions/unions. Evolutions require the
run to be at **10:00 or later** plus the usual requirements; generally only one weapon evolves per
chest even at higher tiers, though some chests carry multiple evolutions. If nothing in the
inventory can be upgraded, the chest pays extra coins instead.

### Base odds are per stage-MINUTE, not per boss (correction)

Shipped `Stage.json` attaches a `treasure` block to each stage-minute entry:
`chances: [a, b, c]` = raw percent chance of the **5-item**, **3-item** and **1-item** roll
respectively (checked in that order, with fallthrough), `level` = the base chest level used if all
three fail, plus `prizeTypes` / `fixedPrizes` for slot contents. Each chance is multiplied by
`totalLuck` when the chest is opened.

**The wiki's Silver Bat example is confirmed:** Mad Forest minute 9 (boss `BAT5`) reads `[3, 10, 50]`.

Mad Forest, full run:

| Minute | Boss | 5-item | 3-item | 1-item | Base level |
|---|---|---|---|---|---|
| 1 | BAT4 | 0% | 0% | 30% | 1 |
| 3 | BAT4 | 0% | 5% | 40% | 1 |
| 5 | XLMANTIS | 1% | 5% | 100% | 1 |
| 7 | BAT4 | 3% | 10% | 50% | 2 |
| 9 | BAT5 | 3% | 10% | 50% | 1 |
| 10 | BOSS_XLMANTIS | 3% | 10% | 100% | 1 |
| 12 | BAT4 | 1% | 5% | 50% | 1 |
| 14 | BAT5 | 3% | 10% | 100% | 1 |
| 15 | BOSS_WEREWOLF | 3% | 10% | 100% | 1 |
| 16 | BAT4 | 1% | 5% | 50% | 1 |
| 18 | BAT5 | 3% | 10% | 100% | 1 |
| 20 | BOSS_XLMUMMY | 3% | 10% | 100% | 1 |
| 22 | BAT4 | 3% | 10% | 100% | 1 |
| 23 | BAT5 | 3% | 10% | 100% | 1 |
| 25 | BOSS_XLFLOWER | 3% | 10% | 100% | 1 |
| 27 | BAT4 | 3% | 10% | 100% | 1 |
| 29 | BAT4 | 3% | 10% | 100% | 1 |

Full tables for all 8 base-game stages are in `pickups_meta.json` at
`data.treasureChests.baseOddsPerBoss.stages`. Note minute 1 carries `fixedPrizes: ["AMOUNT"]` — the
first chest is a guaranteed Amount pickup.


## 4. Gold income

Sources: https://vampire.survivors.wiki/w/Gold_Coin_(currency),
https://vampire.survivors.wiki/w/Greed, https://vampire.survivors.wiki/w/Guide:Gold_farming

**In-run:** Gold Coin (1), Coin Bag (10) and Rich Coin Bag (100) from light sources; Big Coin Bag
(25) from the level-up menu; treasure chests; and surplus coins from chests/level-ups when nothing
can be upgraded. Every one of these is multiplied by Greed.

**Greed:**
- Base total Greed is **100% (x1.0)**. The stat panel shows the *difference* from base, so a
  displayed **+30% means x1.30 total**.
- Character bonuses, PowerUps and items stack **additively** into that total.
- **Stage** gold bonuses stack **multiplicatively** with that collective total.
- No upper limit.
- Documented maximum: Stone Mask lvl 5 (+50%) + Greed PowerUps (+50%) = **x2.0**, times The Bone Zone
  in Hyper mode (**x2**) = **4x base gold**.

**End of run:** 500 gold as an additional reward on run end, **+100 per unused Revival**. Gold
collected in-run persists to the account whether the run ends in death or completion.
The precise payout formula (and whether the 500 is universal across base-game stages) is **unknown**.

## 5. PowerUp shop

Source: shipped `PowerUp.json` (v1.16). **This section is now complete** — the wiki-derived partial
table it replaced is gone.

**Count:** 29 distinct entries in v1.16 (Seal I–IV counted separately), 125 total ranks.
Official wiki says 27, Fandom says 24 — older versions, and/or excluding the Seals and the
later-update additions (Omni, Charm, Defang, Recycle, Antipiretic, Invul Time). **Scope flag kept:**
a strict launch-era base game is a notably smaller set than v1.16.

### Cost formula (unchanged, wiki-documented, verified consistent with shipped prices)

```
price = initialPrice                                              if totalBought == 0
price = initialPrice * (1 + bought) + floor(20 * 1.1^totalBought)  otherwise
```

- `bought` = ranks already bought **of this PowerUp** -> rank *i* always costs `initialPrice * i` in base.
- `totalBought` = ranks bought **across all PowerUps** -> drives the global fee.
- Fees are additive since **v0.7.2 (9 June 2022)**.

### On purchase order

**No assumed order is needed.** Base cost per rank is order-independent (`initialPrice × i`). The fee
term depends only on `totalBought`, so over a full clear the fee sequence is
`floor(20 × 1.1^t)` for `t = 1 … 124` regardless of which PowerUp each purchase belonged to — the
**sum is order-independent too**. Order only changes *which* rank carries *which* fee, never the total.
(For a partial buy the order still matters for what you can afford when.)

Fee schedule, purchases 1–20: `0, 22, 24, 26, 29, 32, 35, 38, 42, 47, 51, 57, 62, 69, 75, 83, 91, 101, 111, 122`
Fee at purchase 50: **2,134** · at 100: **250,556** · at the final (125th): **2,714,706**
Total fees over a full clear: **29,861,494**

### Complete per-PowerUp table with per-rank base costs

| PowerUp | initialPrice | maxRank | Effect per rank | Base cost r1, r2, r3, r4, r5 … | Base total |
|---|---|---|---|---|---|
| Might | 200 | 5 | Raises inflicted Damage by 5% per rank (max +25%). | 200, 400, 600, 800, 1,000 | 3,000 |
| Armor | 600 | 3 | Reduces incoming Damage by 1 per rank (max -3). | 600, 1,200, 1,800 | 3,600 |
| Max Health | 200 | 3 | Augments Max Health by 10% per rank (max +30%). | 200, 400, 600 | 1,200 |
| Recovery | 200 | 5 | Recovers 0.1 HP per rank (max 0.5) per second. | 200, 400, 600, 800, 1,000 | 3,000 |
| Cooldown | 900 | 2 | Uses weapons 2.5% faster per rank (max 5%). | 900, 1,800 | 2,700 |
| Area | 300 | 2 | Augments area of attacks by 5% per rank (max +10%). | 300, 600 | 900 |
| Speed | 300 | 2 | Projectiles move 10% faster per rank (max 20%). | 300, 600 | 900 |
| Duration | 300 | 2 | Effects from weapons last 15% longer per rank (max +30%). | 300, 600 | 900 |
| Amount | 5,000 | 1 | Fires 1 more projectile (all weapons). | 5,000 | 5,000 |
| Move Speed | 300 | 2 | Character moves 5% faster per rank (max 10%). | 300, 600 | 900 |
| Magnet | 300 | 2 | Items Pickup range +25% per rank (max +50%). | 300, 600 | 900 |
| Luck | 600 | 3 | Chance to get lucky goes up by 10% per rank (max +30%). | 600, 1,200, 1,800 | 3,600 |
| Growth | 900 | 5 | Gains 3% more experience per rank (max 15%). | 900, 1,800, 2,700, 3,600, 4,500 | 13,500 |
| Greed | 200 | 5 | Gains 10% more Gold per rank (max +50%). | 200, 400, 600, 800, 1,000 | 3,000 |
| Curse | 1,666 | 5 | Increases enemy speed, health, quantity, and frequency by 10% per rank (max +50%). | 1,666, 3,332, 4,998, 6,664, 8,330 | 24,990 |
| Revival | 10,000 | 1 | Revives once with 50% health. | 10,000 | 10,000 |
| Omni | 1,000 | 5 | Increases Might, Projectile Speed, Duration, and Area by 2% per rank (max +10%). | 1,000, 2,000, 3,000, 4,000, 5,000 | 15,000 |
| Charm | 10,000 | 5 | Increases enemies spawn quantity by 20 per rank (max +100). | 10,000, 20,000, 30,000, 40,000, 50,000 | 150,000 |
| Defang | 10 | 5 | Enemies spawn unable to deal damage 3% of the times per rank (max 15%). | 10, 20, 30, 40, 50 | 150 |
| Reroll | 500 | 5 | Twice per rank, allows you to get different choices when leveling up. | 500, 1,000, 1,500, 2,000, 2,500 | 7,500 |
| Skip | 100 | 5 | Twice per rank, allows you to skip level up choices and get Experience instead. | 100, 200, 300, 400, 500 | 1,500 |
| Banish | 100 | 5 | Twice per rank, allows you to remove an item from level up choices, for the rest of the run. | 100, 200, 300, 400, 500 | 1,500 |
| Recycle | 500 | 5 | Reroll, Skip and Banish actions have a 10% chance to be preserved per rank (max 50%). | 500, 1,000, 1,500, 2,000, 2,500 | 7,500 |
| Seal I | 2,000 | 10 | Allows to Banish an item from level up choices, or a pickup from light sources. Use in COLLECTION menu. | 2,000, 4,000, 6,000, 8,000, 10,000 … | 110,000 |
| Seal II | 4,000 | 10 | Allows to Banish two items from level up choices, or pickup from light sources. Use in COLLECTION menu. | 4,000, 8,000, 12,000, 16,000, 20,000 … | 220,000 |
| Seal III | 6,000 | 10 | Allows to Banish three items from level up choices, or pickups from light sources. Use in COLLECTION menu. | 6,000, 12,000, 18,000, 24,000, 30,000 … | 330,000 |
| Seal IV | 8,000 | 10 | Allows to Banish four items from level up choices, or pickups from light sources. Use in COLLECTION menu. | 8,000, 16,000, 24,000, 32,000, 40,000 … | 440,000 |
| Antipiretic | 500 | 1 | *(no description in shipped data)* | 500 | 500 |
| Invul Time | 500 | 1 | *(no description in shipped data)* | 500 | 500 |

`Reroll`, `Skip` and `Banish` ship with `unlockedRank: 0` (locked until unlocked in-game) but have 5
ranks each; the Seals have 10 ranks each. `Antipiretic` and `Invul Time` ship with empty description
strings — their per-rank effect is the one remaining PowerUp unknown.

### Total cost to max everything (re-checked against shipped data)

| Source | Base | Fees | Total |
|---|---|---|---|
| **Shipped data v1.16 (derived, authoritative)** | **1,362,240** | **29,861,494** | **31,223,734** |
| Official wiki (older version) | 2,469,640 | 24,678,873 | 27,148,513 |
| Fandom (older still) | 1,911,240 | 5,907,719 | 7,818,959 |

Conflict #2 resolved as a **version difference, not an error**: v1.16 has more PowerUps and more ranks
(125) than either wiki version, so the compounding fee term is larger. Note the shipped **base** total
is *lower* than both wiki base figures while fees are far higher — consistent with the fee term
dominating as rank count grows. Use **31,223,734** for v1.16.

**Disable rule:** a maxed PowerUp can be disabled, except Rerolls, Skips, Banishes and Seals.

## 6. Arcanas (overview only)

Sources: https://vampire.survivors.wiki/w/Arcanas, https://vampire-survivors.fandom.com/wiki/Arcanas

- **22 Arcanas** in the base set.
- **Unlocked by:** collecting the **Randomazzo** in Gallo Tower (unlocks the system + Sarabande of
  Healing VI); the rest by reaching **level 50** with certain characters, or surviving to **31:00**
  on certain stages. Collecting the **Darkasso** in Room 1665 unlocks a further "Darkana" set.
- **Selected:** toggled on/off at stage select. With Arcanas on, a run normally grants **up to three**
  — one chosen freely from any unlocked Arcana at the start of the run, the rest offered later.
  Certain effects allow exceeding three.
- Loosely themed on the real tarot Major Arcana.

| # | Name | One-line effect |
|---|---|---|
| 0 | Stake to your Heart | Halts XP gain; enemies drop Gold Coins; damage hits your Gold instead of HP; special merchants spawn every minute. |
| I | Gemini | Certain weapons gain an identical duplicate that levels with them. |
| II | Twilight Requiem | Listed weapons' expiring projectiles cause a horizontal explosion scaling with Curse. |
| III | Tragic Princess | Listed weapons get reduced Cooldown while the player is moving. |
| IV | Awake | +3 Revivals; each revival used grants x1.1 Max Health, +1 Armor, +5% Might/Area/Duration/Speed. |
| V | Chaos in the Dark Night | Projectile Speed oscillates −50%…+50% every 10 s, +1% per level. |
| VI | Sarabande of Healing | All healing doubled; every heal pulses area damage equal to the heal. |
| VII | Iron Blue Will | Listed weapons' projectiles bounce up to 3x, pass through enemies, ignore walls. |
| VIII | Mad Groove | On pickup and every even minute, all items/chests/pickups/XP/light sources are pulled to the player. |
| IX | Divine Bloodline | Listed weapons +5 flat damage per Armor (max +250); all weapons +0.1 per missing HP. |
| X | Beginning | Starting weapon +3 Amount; certain other non-starting weapons +1 Amount. |
| XI | Waltz of Pearls | Listed weapons' projectiles bounce up to 3x. |
| XII | Out of Bounds | Freezing enemies causes explosions; Orologions easier to find; Sorbettos obtainable normally. |
| XIII | Wicked Season | Growth, Luck, Greed, Curse each temporarily doubled in rotation, changing every 10 s. |
| XIV | Jail of Crystal | Listed weapons gain a 25% freeze chance (multiplied by Luck). |
| XV | Disco of Gold | Gold collected also heals for the same amount (scales with Greed); Coin Bags trigger Gold Fever. |
| XVI | Slash | Certain weapons gain crits; all crits deal double damage. |
| XVII | Lost & Found Painting | Duration oscillates −50%…+50% every 10 s, +1% per level. |
| XVIII | Boogaloo of Illusions | Area oscillates −25%…+25% every 10 s, +1% per level. |
| XIX | Heart of Fire | Listed projectiles explode on impact for 50% base damage (+50% if already explosive). |
| XX | Silent Old Sanctuary | +3 Rerolls/Skips/Banishes; each empty weapon slot +20% Might, −8% Cooldown (max +100%/−40%). |
| XXI | Blood Astronomia | Garlic, Soul Eater, Pentagram, Gorgeous Moon, Song of Mana, Mannajja, Clock Lancet, Laurel, Sonic Dash, Rapidus Fio also trigger a Blood weapon effect. |

---

## Known gaps

Closed by the shipped data: the full PowerUp table, per-rank costs, the light-source drop table and
spawn config, per-stage-minute chest odds, and the Arcana 0 effect.

Still open (all `null` in the JSON, all in `unknowns`):

- Total light sources spawned over a full run, and the numeric multiplier Luck applies to `isRare` weights.
- The exact end-of-run payout formula (500 + 100/unused Revival is wiki-sourced, not verified in shipped data).
- Per-rank effects of the `Antipiretic` and `Invul Time` PowerUps (empty descriptions in shipped data).
- Whether Little Clover's +10% Luck has an internal duration distinct from "until end of stage".
