# Vampire Survivors — Base-Game Weapons (Mechanics Reference)

Scope: base game only, no DLC. Companion data file: `weapons.json` (authoritative; follows `SCHEMA.md`).
Retrieved 2026-09-19.

## RESEARCH BLOCKER (read first)

The network egress proxy in this environment blocked **all** WebFetch requests, including
`vampire.survivors.wiki`, `vampire-survivors.fandom.com`, `steamcommunity.com`, and every
tertiary guide site tried. Only WebSearch **result summaries** of those wiki pages were
obtainable. Consequences:

- Base stats, max-level totals, and targeting behaviour below are sourced from search summaries of the two wikis and are reasonably reliable.
- **Exact Lv1–Lv8 per-level delta tables could not be retrieved for 10 of the 11 weapons.** They are `null` in the JSON and listed in `unknowns`. They are NOT guessed.
- Only Santa Water yielded a per-level table, from a tertiary guide, and it does not reconcile with the wiki max-level totals — flagged in `conflicts`.

To finish this file, someone needs direct HTTP access to `https://vampire.survivors.wiki/w/<Weapon>`
(each page carries the full level table) or an allowlist entry for that domain.

## Conventions

- Percent stats stored as multipliers when absolute (`area: 1.0` = 100%); percent *changes* stored as additive fractions (`areaDelta: 0.2` = +20%).
- All times in seconds. `maxLevelTotals` = cumulative bonus gained from Lv1 to Lv8.
- `critChance` / `critMultiplier` are recorded only where a documented source exists. No base-game weapon has innate crit; Whip and Axe gain crit solely from the Slash (XVI) Arcana.

## Summary table

| Weapon | Dmg | Area | Speed | Amount | Duration | Cooldown | Pierce | Knockback | Pool | Max-level totals |
|---|---|---|---|---|---|---|---|---|---|---|
| Whip | 10 | 100% | ? | 1 | – | 1.35 | AoE | 1 | ? | +30 dmg, +20% area, +1 amount |
| Magic Wand | 10 | ? | 100% | 1 | – | 1.2 | 1 | ? | ? | +20 dmg, +3 amount, +1 pierce, −0.2 cd |
| Knife | 6.5 | 100% | 100% | 1 | – | 1.0 | 1 | 0.5 | 70 | +10 dmg, +5 amount, +2 pierce, −0.06 interval |
| Axe | 20 | 100% | 100% | ? | – | 4.0 | 3 | 1 | ? | +60 dmg, +2 amount, +4 pierce |
| Runetracer | 10 | ? | 100% | 1 | 2.25 | 3.0 | ∞ | 1 | 25 | +20 dmg, +2 amount, +40% speed, +1 duration |
| Fire Wand | 20 | 100% | 75% | 3 (disputed) | – | 3.0 | 1 | 1 | 30 | +70 dmg, +60% speed |
| King Bible | 10 | 100% | 100% | ? | 3.0 | 3.0 | AoE | 1 | 50 | +20 dmg, +60% speed, +50% area, +3 amount, +1 duration |
| Garlic | 5 | ? | – | – | – | 1.3 | AoE | 0 | 50 | +10 dmg, +100% area, −0.3 cd |
| Santa Water | 10 | ? | ignored | 1 | 2.0 | 4.5 (or 3.0) | AoE | ? | 20 | +30 dmg, +80% area, +3 amount, +1 duration |
| Lightning Ring | 15 | 100% | ignored | ? | ignored | 4.5 | AoE | ? | ? | +50 dmg, +300% area, +4 amount |
| Cross | 5 | 100% | 100% | 1 | – | 2.0 | ∞ | ? | ? | +30 dmg, +20% area, +50% speed, +2 amount |

`?` = unknown (null in JSON). `–` = stat not used by the weapon.

## Targeting behaviour (the part that matters for reimplementation)

- **Whip** — horizontal slash from the character's torso extending in the facing direction; AoE, hits everything in the rectangle. Extra slashes from Amount alternate toward/away from facing, each drawn progressively higher. `https://vampire.survivors.wiki/w/Whip`
- **Magic Wand** — homing-at-launch missile aimed at the **closest** enemy; unlimited range, retargets per shot. `https://vampire.survivors.wiki/w/Magic_Wand`
- **Knife** — straight-line projectile in the **facing/last-moved** direction, unlimited range; extra knives fire as a rapid volley at 0.1s spacing. `https://vampire.survivors.wiki/w/Knife`
- **Axe** — thrown upward, arcs back down under gravity. First axe straight up; later axes thrown toward the facing direction in progressively wider arcs. Character Area is multiplied by 1.3 for this weapon. `https://vampire.survivors.wiki/w/Axe`
- **Runetracer** — straight-line projectile that **bounces off screen edges and obstacles** for its Duration. Infinite pierce, gated by a 0.5s per-enemy hitbox delay. `https://vampire.survivors.wiki/w/Runetracer`
- **Fire Wand** — arc of fireballs aimed at a **random** enemy; extra fireballs widen the arc at its ends. 1 hit per fireball. `https://vampire.survivors.wiki/w/Fire_Wand`
- **King Bible** — bibles orbit the player clockwise for Duration, then cooldown. Speed = rotation rate, Area = orbit radius (capped) + hitbox size, Amount = evenly spaced extras. Effective cycle = Cooldown + Duration (6.0s base). Per-enemy hitbox delay 1.7s. `https://vampire.survivors.wiki/w/King_Bible`
- **Garlic** — permanent aura on the player, no aiming. Cooldown acts as the per-enemy hitbox delay. Each hit adds +0.3 knockback vulnerability and −0.1 freeze resistance to non-immune enemies. `https://vampire.survivors.wiki/w/Garlic`
- **Santa Water** — bottles fall from the sky into stationary burning ground puddles lasting Duration. Below 4 total Amount the first bottle aims at the **closest** enemy; at 4+ the bottles land in a clockwise circular pattern around the player. Ignores Speed. `https://vampire.survivors.wiki/w/Santa_Water`
- **Lightning Ring** — strikes **random** on-screen enemies; the ground-impact circle deals the damage, not the bolt. Ignores Speed and Duration. `https://vampire.survivors.wiki/w/Lightning_Ring`
- **Cross** — spinning cross thrown at the **closest** enemy, decelerates, then boomerangs back and off screen. Infinite pierce on both legs; Speed sets the outward travel distance. `https://vampire.survivors.wiki/w/Cross`

## Per-level tables (Lv1–Lv8)

Only Santa Water was obtainable, and it is **unverified** (tertiary source; its duration deltas sum to +1.3s vs the wiki's stated +1.0s max total):

| Lv | Change |
|---|---|
| 1 | 1 projectile, AoE damage on impact |
| 2 | +1 projectile, +20% Area |
| 3 | +10 Damage, +0.5s Duration |
| 4 | +1 projectile, +20% Area |
| 5 | +10 Damage, +0.5s Duration |
| 6 | +1 projectile, +20% Area |
| 7 | +5 Damage, +0.3s Duration |
| 8 | +5 Damage, +20% Area |

Source: https://progameguides.com/vampire-survivors/how-to-evolve-the-santa-water-in-vampire-survivors/

All other weapons: **per-level tables unknown** (`levels: null`).

## Conflicts

1. **Santa Water cooldown** — 3.0s vs 4.5s across two summaries of the same wikis. Both recorded (`cooldown` / `cooldownAlt`).
2. **Fire Wand base Amount** — one summary states 3 (arc of fireballs); other descriptions imply 1. Both recorded.
3. **Santa Water per-level table** — tertiary-source table's Duration deltas do not sum to the wiki's max-level Duration total.

## Sources

- Official wiki (per-weapon pages): https://vampire.survivors.wiki/w/Weapons
- Fandom wiki: https://vampire-survivors.fandom.com/wiki/Weapons
- Pro Game Guides (Santa Water levels): https://progameguides.com/vampire-survivors/how-to-evolve-the-santa-water-in-vampire-survivors/
