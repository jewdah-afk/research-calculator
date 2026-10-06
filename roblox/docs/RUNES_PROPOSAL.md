# Proposal: Starter Runes

## Pitch
A rune altar sits near spawn, next to the Cash stand. One roll costs **$10 cash**. Each roll gives one of 10 runes, from 1/1 to 1/10,000,000. Duplicate runes stack, up to a cap per rune.

- **Runes 1–5** give tiny cash boosts. They help early game feel fast.
- **Runes 6–10** are the long chase. They boost **points only**: rebirths per rebirth, AP per ascension and TrP per transcension. Never cash, luck or anything else.

## The runes

| # | Rune | Chance | Boost per copy | Max (copies) | Boosts |
|---|---|---|---|---|---|
| 1 | Spark | 1/1 | +0.5% cash | +25% (50) | cash |
| 2 | Pebble | 1/3 | +1% cash | +40% (40) | cash |
| 3 | Breeze | 1/10 | +2% cash | +60% (30) | cash |
| 4 | Tide | 1/40 | +3% cash | +90% (30) | cash |
| 5 | Ember | 1/150 | +5% cash | +150% (30) | cash |
| 6 | Echo | 1/1,000 | +1% rebirth points | +25% (25) | rebirths gained per rebirth |
| 7 | Prism | 1/10,000 | +2% rebirth points | +40% (20) | rebirths gained per rebirth |
| 8 | Halo | 1/100,000 | +1% AP | +20% (20) | AP per ascension |
| 9 | Crown | 1/1,000,000 | +2% AP | +30% (15) | AP per ascension |
| 10 | Eternity | 1/10,000,000 | +1% TrP | +15% (15) | TrP per transcension |

- **How rolling works:** each roll checks the rarest rune first, like orb rolls. Rune luck is separate from orb luck, so 1/10M stays a real chase.
- **Cash runes all maxed:** +365% cash in total (×4.65). This counts as a bonus, so `Balance.bonusLog` softcaps it like every other bonus. It speeds up the first hour without breaking later balance.

## Keeping it balanced
- **Points stay whole.** Points still come 1 at a time, so percentage boosts build up as a hidden fractional balance. For example, +25% rebirth points means every 4th rebirth gives 1 bonus rebirth. Nothing gets rounded away and nothing breaks the "1 per click" feel.
- **$10 is only a cost in the first minutes.** After that, roll speed is the real limit:

  | Roll speed | How you get it |
  |---|---|
  | 1 roll / 1.5s | base |
  | 2 rolls / s | Auto-Roll, bought with gems after the Gems stand unlocks |
  | up to ×10 per click | "Rune Speed" upgrades, bought with gems |

  At 20 rolls/s, Eternity (1/10M) takes about 6 days of rolling on average. It's a long-term flex, not a requirement.
- **Nothing resets.** Rune collections never reset, not even on Transcension. That's what makes them the "permanent account" layer.

## Presentation
- **The altar:** a stone pedestal with 10 glowing rune slots. Rolling plays a short spin. The won rune flies into its slot, and rare runes (6+) shake the altar.
- **Silhouettes:** runes you haven't found show as black **???** silhouettes, like the stands.
- **Announcements:** finding rune 8, 9 or 10 is announced to the whole server, the same as rare orbs.
- **Panel:** grid of the 10 runes, each with copies / max and its current boost, plus Roll ×1, Auto-Roll and Rune Speed.

## Open questions
1. Should the cap be per rune (as above), or should extra copies past the cap turn into "rune dust" for something else?
2. Should Auto-Roll be bought with gems in-game or with Robux? Or both, with the gems version slower?
3. Should runes show on the leaderboard, for example "rarest rune found"?
