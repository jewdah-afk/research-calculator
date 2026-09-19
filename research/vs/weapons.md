# Vampire Survivors - Base-Game Weapons (Mechanics Reference)

Scope: base game only, no DLC. Companion data file: `weapons.json` (authoritative; follows `SCHEMA.md`). Retrieved 2026-09-19.

## Source

Primary source for every table on this page is the game's own shipped balance file:

- `Data/Vampire Survivors/Weapon.json`, **game version 1.16**, base-game folder (DLC data lives in separate folders)
- URL: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json
- **This is a community rip of the shipped game file, not an official published page.** It is more authoritative than the wikis for numbers because it *is* the balance data, but it carries no editorial description of behaviour.

Behavioural/targeting descriptions are cross-checked against the official wiki (https://vampire.survivors.wiki/w/Weapons) and the Fandom wiki, which were reachable only through WebSearch result summaries because the network egress proxy blocks direct fetches of those domains.

Cross-validation: the Lv2-Lv8 deltas below sum to exactly the max-level totals the wikis quote for all 11 weapons (e.g. Whip +30 damage / +20% Area / +1 Amount; Knife +10 / +5 Amount / +2 Pierce / -0.06s interval). The two sources agree.

## Conventions

- The shipped file stores `power` as a damage multiplier where **displayed damage = power x 10**. `baseDamage` in the JSON is the displayed value; `rawPower` keeps the shipped multiplier.
- Absolute percent stats are multipliers (`area: 1.0` = 100%); percent *changes* are additive fractions (`areaDelta: 0.1` = +10%).
- All times in seconds (the shipped file uses milliseconds). `interval` -> `cooldown`, `repeatInterval` -> `projectileInterval`, `penetrating` -> `pierce`, `critMul` -> `critMultiplier`.
- Level entries are **deltas applied on top of the previous level**, exactly as shipped. Lv1 is the base row.
- Fields absent from a weapon's shipped record are `null`, never 0 and never guessed; they are listed in `unknowns`.

## Base stats

| Weapon | Dmg (power) | Area | Speed | Amount | Duration | Cooldown | Pierce | Knockback | Pool | Proj. interval | Hitbox delay | Crit |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Whip | 10 (1) | 1 | 1 | 1 | - | 1.35 | - | - | 30 | 0.1 | - | 20% / 2x |
| Magic Wand | 10 (1) | 1 | 1 | 1 | - | 1.2 | 1 | - | 60 | 0.1 | - | - |
| Knife | 6.5 (0.65) | 1 | 1 | 1 | - | 1 | 1 | 0.5 | 70 | 0.1 | - | 30% / 3x |
| Axe | 20 (2) | 1 | 1 | 1 | 2 | 4 | 3 | - | 70 | 0.2 | - | 30% / 2x |
| Runetracer | 10 (1) | 1 | 1 | 1 | 2.25 | 3 | - | - | 50 | 0.2 | 0.5 | - |
| Fire Wand | 20 (2) | 1 | 0.75 | 3 | 0.1 | 3 | - | - | 30 | 0.02 | - | - |
| King Bible | 10 (1) | 1 | 1 | 1 | 3 | 3 | - | - | 50 | 0 | 1.7 | - |
| Garlic | 5 (0.5) | 1 | 1 | 1 | 1.3 | 1.3 | - | 0 | 50 | 0 | - | - |
| Santa Water | 10 (1) | 1 | 1 | 1 | 2 | 4.5 | - | 0 | 20 | 0.3 | 0.5 | - |
| Lightning Ring | 15 (1.5) | 1 | 1 | 2 | - | 4.5 | - | - | 50 | 0.05 | - | - |
| Cross | 5 (0.5) | 1 | 1 | 1 | - | 2 | - | - | 100 | 0.1 | - | - |

`-` = field absent from the shipped record (null in JSON).

## Per-weapon detail

### Whip

**Targeting.** Slashes horizontally from the character's torso in the facing direction; area-of-effect, passes through all enemies in the rectangle. Extra slashes from Amount alternate between firing toward and away from the facing direction, each placed progressively higher. Ignores Speed and Duration.

Shipped tips field: `Ignores: Speed, Duration.`

**Max-level totals (Lv1 -> Lv8):** amount +1, areaDelta +0.2, baseDamage +30

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +1 Amount. |
| 3 | +5 Damage. |
| 4 | +5 Damage, +10% Area. |
| 5 | +5 Damage. |
| 6 | +5 Damage, +10% Area. |
| 7 | +5 Damage. |
| 8 | +5 Damage, unlocks evolution (VAMPIRICA). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Magic Wand

**Targeting.** Fires a magic missile at the CLOSEST enemy; unlimited range, retargets every shot. Extra projectiles fire in quick succession (repeatInterval 0.1s) at nearest targets. Ignores Duration.

Shipped tips field: `Ignores: Duration.`

**Max-level totals (Lv1 -> Lv8):** amount +3, baseDamage +20, cooldown -0.2, pierce +1

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +1 Amount. |
| 3 | -0.2 s Cooldown. |
| 4 | +1 Amount. |
| 5 | +10 Damage. |
| 6 | +1 Amount. |
| 7 | +1 Pierce. |
| 8 | +10 Damage, unlocks evolution (HOLY_MISSILE). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Knife

**Targeting.** Throws knives in a straight line in the FACING direction (movement direction, or last-moved when idle); unlimited range. Extra knives fire as a volley spaced by repeatInterval. Ignores Duration.

Shipped tips field: `Ignores: Duration.`

**Max-level totals (Lv1 -> Lv8):** amount +5, baseDamage +10, pierce +2, projectileInterval -0.06

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +1 Amount. |
| 3 | +5 Damage, +1 Amount. |
| 4 | +1 Amount, -0.02 s Projectile Interval. |
| 5 | +1 Pierce. |
| 6 | +1 Amount, -0.02 s Projectile Interval. |
| 7 | +5 Damage, +1 Amount. |
| 8 | +1 Pierce, -0.02 s Projectile Interval, unlocks evolution (THOUSAND). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Axe

**Targeting.** Thrown upward above the player, arcing back down under gravity. First axe goes straight up; extra axes are thrown toward the facing direction in progressively wider arcs. Character Area is multiplied by 1.3 for this weapon. Ignores Duration.

Shipped tips field: `Ignores: Duration.`

**Max-level totals (Lv1 -> Lv8):** amount +2, baseDamage +60, pierce +4

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +1 Amount. |
| 3 | +20 Damage. |
| 4 | +2 Pierce. |
| 5 | +1 Amount. |
| 6 | +20 Damage. |
| 7 | +2 Pierce. |
| 8 | +20 Damage, unlocks evolution (SCYTHE). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Runetracer

**Targeting.** Straight-line projectile that BOUNCES off screen edges and obstacles until its Duration expires. Infinite pierce, gated by a 0.5s per-enemy hitbox delay. Best with Speed and Duration.

Shipped tips field: `Best with: Speed, Duration.`

**Max-level totals (Lv1 -> Lv8):** amount +2, baseDamage +20, duration +1, speedDelta +0.4

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +5 Damage, +20% Projectile Speed. |
| 3 | +5 Damage, +0.25 s Duration. |
| 4 | +1 Amount. |
| 5 | +5 Damage, +20% Projectile Speed. |
| 6 | +5 Damage, +0.25 s Duration. |
| 7 | +1 Amount. |
| 8 | +0.5 s Duration, unlocks evolution (ROCHER). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Fire Wand

**Targeting.** Fires an arc of fireballs toward a RANDOM enemy; all fireballs of a cast launch near-simultaneously (repeatInterval 0.02s) and extra fireballs widen the ends of the arc. Ignores Duration.

Shipped tips field: `Ignores: Duration.`

**Max-level totals (Lv1 -> Lv8):** baseDamage +70, speedDelta +0.6

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +10 Damage. |
| 3 | +10 Damage, +20% Projectile Speed. |
| 4 | +10 Damage. |
| 5 | +10 Damage, +20% Projectile Speed. |
| 6 | +10 Damage. |
| 7 | +10 Damage, +20% Projectile Speed. |
| 8 | +10 Damage, unlocks evolution (HELLFIRE). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### King Bible

**Targeting.** Bibles orbit the player clockwise for the weapon's Duration, then the weapon goes on cooldown. Speed = rotation rate, Area = orbit radius (capped) and bible hitbox size, Amount = evenly spaced extras. intervalDependsOnDuration is true, so the effective cycle = cooldown + duration (3.0 + 3.0 = 6.0s at Lv1). Per-enemy hitbox delay 1.7s.

Shipped tips field: `Best with: Speed, Duration, Area.`

`intervalDependsOnDuration: true` - the cooldown clock only starts after the effect ends, so the effective cycle is cooldown + duration.

**Max-level totals (Lv1 -> Lv8):** amount +3, areaDelta +0.5, baseDamage +20, duration +1, speedDelta +0.6

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +1 Amount. |
| 3 | +25% Area, +30% Projectile Speed. |
| 4 | +10 Damage, +0.5 s Duration. |
| 5 | +1 Amount. |
| 6 | +25% Area, +30% Projectile Speed. |
| 7 | +10 Damage, +0.5 s Duration. |
| 8 | +1 Amount, unlocks evolution (VESPERS). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Garlic

**Targeting.** Permanent damaging aura centred on the player; no aiming. The cooldown (interval) doubles as the per-enemy hitbox delay: an enemy is hit on entry, then not again until the cooldown elapses even if it leaves and re-enters. Each hit lowers the target's knockback and freeze resistance. Ignores Amount, Duration and Speed.

Shipped tips field: `Ignores: Amount, Duration, Speed.`

**Max-level totals (Lv1 -> Lv8):** areaDelta +1, baseDamage +10, cooldown -0.3

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +2 Damage, +40% Area. |
| 3 | +1 Damage, -0.1 s Cooldown. |
| 4 | +1 Damage, +20% Area. |
| 5 | +2 Damage, -0.1 s Cooldown. |
| 6 | +1 Damage, +20% Area. |
| 7 | +1 Damage, -0.1 s Cooldown. |
| 8 | +2 Damage, +20% Area, unlocks evolution (VORTEX). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Santa Water

**Targeting.** Bottles fall from the sky and shatter into stationary damaging ground zones lasting the weapon's Duration. Below 4 total Amount the first bottle of a cast aims at the CLOSEST enemy; at Amount 4+ the bottles land in a clockwise, roughly circular pattern around the player. Per-enemy hitbox delay 0.5s. Ignores Speed.

Shipped tips field: `Ignores: Speed.`

**Max-level totals (Lv1 -> Lv8):** amount +3, areaDelta +0.8, baseDamage +30, duration +1

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +20% Area, +1 Amount. |
| 3 | +10 Damage, +0.5 s Duration. |
| 4 | +20% Area, +1 Amount. |
| 5 | +10 Damage, +0.25 s Duration. |
| 6 | +20% Area, +1 Amount. |
| 7 | +5 Damage, +0.25 s Duration. |
| 8 | +5 Damage, +20% Area, unlocks evolution (BORA). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Lightning Ring

**Targeting.** Calls lightning down on RANDOM on-screen enemies. The bolt itself is cosmetic; damage comes from the circular ground-impact hitbox, scaled by Area. Ignores Speed and Duration.

Shipped tips field: `Ignores: Speed, Duration.`

**Max-level totals (Lv1 -> Lv8):** amount +4, areaDelta +3, baseDamage +50

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +1 Amount. |
| 3 | +10 Damage, +100% Area. |
| 4 | +1 Amount. |
| 5 | +20 Damage, +100% Area. |
| 6 | +1 Amount. |
| 7 | +20 Damage, +100% Area. |
| 8 | +1 Amount, unlocks evolution (LOOP). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

### Cross

**Targeting.** Spinning cross thrown at the CLOSEST enemy; it decelerates, boomerangs back through the player and continues off screen. Damages every enemy it contacts on both legs. Speed sets how far out it travels before reversing. Ignores Duration.

Shipped tips field: `Ignores: Duration.`

**Max-level totals (Lv1 -> Lv8):** amount +2, areaDelta +0.2, baseDamage +30, speedDelta +0.5

| Lv | Change |
|---|---|
| 1 | Base weapon. |
| 2 | +10 Damage. |
| 3 | +10% Area, +25% Projectile Speed. |
| 4 | +1 Amount. |
| 5 | +10 Damage. |
| 6 | +10% Area, +25% Projectile Speed. |
| 7 | +1 Amount. |
| 8 | +10 Damage, unlocks evolution (HEAVENSWORD). |

Source: https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json

## Conflicts

- **data.santa_water.cooldown** - values [4.5, 3.0] (sources: game-data-v1.16, official-wiki). RESOLVED in favour of the shipped data: interval 4500 ms = 4.5 s. The 3.0 s figure came from a wiki search summary.
- **data.fire_wand.amount** - values [3, 1] (sources: game-data-v1.16, fandom-wiki). RESOLVED in favour of the shipped data: base amount is 3.
- **data.santa_water.levels[*].changes.duration** - values [[0.5, 0.25, 0.25], [0.5, 0.5, 0.3]] (sources: game-data-v1.16, progameguides-santa-water). RESOLVED in favour of the shipped data: Lv3 +0.5s, Lv5 +0.25s, Lv7 +0.25s, summing to the +1.0 s max-level total. The tertiary guide's +0.5/+0.5/+0.3 was wrong.
- **data.runetracer.poolLimit** - values [50, 25] (sources: game-data-v1.16, official-wiki). Shipped data says 50; a wiki search summary said 25. Shipped value is authoritative; the wiki figure may predate a balance patch.
- **data.whip.critChance / data.whip.critMultiplier** - values [[0.2, 2], [0.2, 4]] (sources: game-data-v1.16, official-wiki). Shipped data gives Whip an INNATE 20% crit chance at 2x damage. Wiki summaries described 20%/4x as granted by the Slash (XVI) Arcana. Both recorded; the 2x innate value is the shipped one.
- **data.axe.critMultiplier** - values [2, 4] (sources: game-data-v1.16, official-wiki). Shipped data: innate 30% chance at 2x. Wiki described 30%/4x via Slash (XVI).
- **data.knife.critChance** - values [0.3, null] (sources: game-data-v1.16, official-wiki). Shipped data gives Knife an innate 30% crit at 3x; no wiki summary mentioned Knife crits.
- **data.whip.evolution** - values ["VAMPIRICA", "Bloody Tear"] (sources: game-data-v1.16, official-wiki). Internal id vs display name; not a real disagreement.

## Still unknown

- data.whip.duration
- data.whip.pierce
- data.whip.knockback
- data.magic_wand.duration
- data.magic_wand.knockback
- data.knife.duration
- data.axe.knockback
- data.runetracer.pierce
- data.runetracer.knockback
- data.fire_wand.pierce
- data.fire_wand.knockback
- data.king_bible.pierce
- data.king_bible.knockback
- data.garlic.pierce
- data.santa_water.pierce
- data.lightning_ring.duration
- data.lightning_ring.pierce
- data.lightning_ring.knockback
- data.cross.duration
- data.cross.pierce
- data.cross.knockback
- Weapons whose record omits 'penetrating' are area-of-effect or infinite-pierce in behaviour; the shipped file carries no numeric pierce for them, so it is null rather than 1.
- Weapons whose record omits 'knockback' use an engine default not present in the shipped file.
