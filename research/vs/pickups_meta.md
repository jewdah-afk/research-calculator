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

| Pickup | Effect | Duration | Level req. | Luck affects drop? | Drop weight | Source |
|---|---|---|---|---|---|---|
| Gold Coin | +1 Gold, x Greed | — | none | **No** | unknown | [Gold_Coin](https://vampire.survivors.wiki/w/Gold_Coin) |
| Coin Bag | +10 Gold, x Greed | — | none | **No** | unknown | [Coin_Bag](https://vampire.survivors.wiki/w/Coin_Bag) |
| Rich Coin Bag | +100 Gold, x Greed | — | **5** | Yes | unknown | [Rich_Coin_Bag](https://vampire.survivors.wiki/w/Rich_Coin_Bag) |
| Big Coin Bag | +25 Gold, x Greed | — | none | n/a | n/a | [Big_Coin_Bag](https://vampire.survivors.wiki/w/Big_Coin_Bag) |
| Floor Chicken | Restore **30 HP** | instant | none | Yes | unknown | [Floor_Chicken](https://vampire.survivors.wiki/w/Floor_Chicken) |
| Rosary | Instantly kills all on-screen enemies | instant | **8** | Yes | unknown | [Rosary](https://vampire.survivors.wiki/w/Rosary) |
| Orologion | Spinning blue ring; freezes all enemies | **10 s** | **4** | Yes | unknown | [Orologion](https://vampire.survivors.wiki/w/Orologion) |
| Vacuum | Pulls in and collects every XP Gem on the ground | instant | **12** | Yes | unknown | [Vacuum](https://vampire.survivors.wiki/w/Vacuum) |
| Nduja Fritta Tanto | Character breathes fire in facing direction | **10 s** | unknown | Yes | unknown | [Nduja](https://vampire.survivors.wiki/w/Nduja_Fritta_Tanto) |
| Little Clover | **+10% Luck until end of stage** | until stage end | unknown | Yes | 2nd rarest | [Little_Clover](https://vampire.survivors.wiki/w/Little_Clover) |

Notes:
- **Big Coin Bag is not a floor pickup.** It appears as one of the two level-up menu options once
  every owned weapon and passive is maxed (with Limit Break disabled).
- Exact numeric drop weights ("rarity" values) exist in wiki tables but were not recoverable.

## 2. Light sources / destructible props

Source: https://vampire.survivors.wiki/w/Light_source, https://vampire.survivors.wiki/w/Luck

- Destructibles that spawn randomly on the stage; each drops **exactly one** pickup when destroyed.
- **Gold Coin is by far the most common drop.**
- **Luck rule:** Luck raises the spawn rate of light sources, and multiplies the weight ("rarity") of
  every pickup in the pool **except Gold Coin and Coin Bag** — so Luck shifts the distribution toward
  rare drops rather than adding a flat bonus.
- **Spawn cap caveat:** while the map already holds the maximum number of light sources, spawn
  attempts stop being influenced by Luck, so they spawn less often.
- Most DLC stages and Capella Magna raise the light-source maximum above the standard stage value.

**Unknown:** the numeric drop table / probabilities, base spawn chance, the Luck spawn formula, the
per-stage maximum, and total light sources per stage.

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

Sources: https://vampire.survivors.wiki/w/PowerUps,
https://vampire.survivors.wiki/w/Calculators/PowerUp_Cost

**Count:** 27 PowerUps per the official wiki (counting the separate Seal PowerUps); Fandom says 24. Conflict recorded.

### Cost formula

```
price = initialPrice                                             if totalBought == 0
price = initialPrice * (1 + bought) + floor(20 * 1.1^totalBought) otherwise
```

- `bought` = ranks already purchased **of this PowerUp**; each rank raises that PowerUp's next base
  cost by its `initialPrice` (initialPrice 200 -> five ranks cost 200+400+600+800+1000 = 3,000 base).
- `totalBought` = ranks purchased **across all PowerUps**; this drives a global fee term.
- No fee is charged while `totalBought == 0`.
- Since **v0.7.2 (9 June 2022)** the fees are additive, so **purchase order no longer affects the total**.

### Total cost to max everything

| Figure | Base | Fees | Total | Source |
|---|---|---|---|---|
| Official wiki | 2,469,640 | 24,678,873 | **27,148,513** | vampire.survivors.wiki |
| Fandom (older version) | 1,911,240 | 5,907,719 | 7,818,959 | fandom |

### Per-PowerUp data (partial — the wiki table itself was not retrievable)

| PowerUp | Effect per rank | Max rank | At max | Initial price |
|---|---|---|---|---|
| Might | +5% Might | 5 | +25% | 200 |
| Max Health | **x1.1** Max Health (multiplicative) | 3 | x1.331 | 200 |
| Armor | unknown | 3 | unknown | 600 |
| Recovery | +0.1 Recovery | 5 | +0.5 | unknown |
| Cooldown | −2.5% Cooldown | 2 | −5% | 900 |
| Growth | +3% Growth | 5 | +15% | 900 |
| Duration | +15% Duration | 2 | +30% | unknown |
| Magnet | **x1.25** Magnet (multiplicative) | 2 | x1.5625 | unknown |
| Curse | +10% Curse | 5 | +50% | unknown |
| Omni | +2% Might / Proj. Speed / Duration / Area | 5 | +10% each | unknown |
| Amount | unknown | 1 | unknown | 5,000 |
| Revival | unknown | 1 | unknown | 10,000 |
| Greed | unknown | unknown | +50% total | unknown |
| Area, Speed, Move Speed, Luck | unknown | unknown | unknown | unknown |
| Reroll, Skip, Banish, Charm, Seal(s) | unknown | unknown | unknown | unknown |

**A per-rank cost table cannot be produced** without every `initialPrice`/`maxRank` plus a fixed
purchase order for the global fee term. The formula above reproduces it exactly once those are known.

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
| 0 | Stake to Your Heart | **unknown** (effect text not retrievable) |
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

Light-source numeric drop table and per-stage counts; floor-pickup drop weights; per-boss chest base
odds beyond the Silver Bat example; the exact end-of-run payout formula; most PowerUp initial prices,
max ranks and per-rank effects; the Arcana 0 effect text. All are `null` in the JSON and enumerated
in its `unknowns` array.
