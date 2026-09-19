# Vampire Survivors — Passives & Evolutions (base game, no DLC)

Retrieved 2026-09-19. Schema: /research/vs/SCHEMA.md. Times in seconds; percentages as fractional deltas per level.

## Sources

- `vs-gamefiles-v1.16` — https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json — Verbatim rip of the game's own Weapon.json, base-game folder, game v1.16 (repo README).
- `official-wiki` — https://vampire.survivors.wiki/w/Evolution — Page NOT directly fetchable from this session (egress proxy blocks vampire.survivors.wiki and vampire-survivors.fandom.com). Statements attributed to it come from search-engine summaries of that page, not the page text.
- `fandom-wiki` — https://vampire-survivors.fandom.com/wiki/Passive_items — Same limitation as above.
- `vst` — https://raw.githubusercontent.com/jerek/vampire-survivors-tools/main/src/js/VST/VS/Weapon.js — Community tool mirroring wiki data; used only to cross-check the evolution recipe list.

**Access caveat:** `vampire.survivors.wiki`, `vampire-survivors.fandom.com`, Steam Community and all community-spreadsheet domains are blocked by this session's egress proxy. Numeric data below therefore comes from the game's own shipped data file (`Weapon.json`, v1.16 rip), which is strictly more authoritative than any wiki table. Wiki-only claims (chest timing rules) are marked as unverified.

## 1. Passive items

| Passive | Stat key | Per level | Max level | Total at max | Enables evolution | Source |
|---|---|---|---|---|---|---|
| Spinach | `might` | 0.1, 0.1, 0.1, 0.1, 0.1 | 5 | 0.5 | Hellfire | vs-gamefiles-v1.16 |
| Armor | `armor` | 1, 1, 1, 1, 1 | 5 | 5 | NO FUTURE | vs-gamefiles-v1.16 |
| Hollow Heart | `maxHealth` | 0.2, 0.2, 0.2, 0.2, 0.2 | 5 | 1.0 | Bloody Tear | vs-gamefiles-v1.16 |
| Pummarola | `recovery` | 0.2, 0.2, 0.2, 0.2, 0.2 | 5 | 1.0 | Soul Eater | vs-gamefiles-v1.16 |
| Empty Tome | `cooldown` | -0.08, -0.08, -0.08, -0.08, -0.08 | 5 | -0.4 | Holy Wand | vs-gamefiles-v1.16 |
| Candelabrador | `area` | 0.1, 0.1, 0.1, 0.1, 0.1 | 5 | 0.5 | Death Spiral | vs-gamefiles-v1.16 |
| Bracer | `speed` | 0.1, 0.1, 0.1, 0.1, 0.1 | 5 | 0.5 | Thousand Edge | vs-gamefiles-v1.16 |
| Spellbinder | `duration` | 0.1, 0.1, 0.1, 0.1, 0.1 | 5 | 0.5 | Unholy Vespers | vs-gamefiles-v1.16 |
| Duplicator | `amount` | 1, 1 | 2 | 2 | Thunder Loop | vs-gamefiles-v1.16 |
| Wings | `moveSpeed` | 0.1, 0.1, 0.1, 0.1, 0.1 | 5 | 0.5 | Valkyrie Turner | vs-gamefiles-v1.16 |
| Attractorb | `magnet` | 0.5, 0.33, 0.25, 0.2, 0.33 | 5 | 1.61 | La Borra | vs-gamefiles-v1.16 |
| Clover | `luck` | 0.1, 0.1, 0.1, 0.1, 0.1 | 5 | 0.5 | Heaven Sword | vs-gamefiles-v1.16 |
| Crown | `growth` | 0.08, 0.08, 0.08, 0.08, 0.08 | 5 | 0.4 | Gorgeous Moon | vs-gamefiles-v1.16 |
| Stone Mask | `greed` | 0.1, 0.1, 0.1, 0.1, 0.1 | 5 | 0.5 | Vicious Hunger | vs-gamefiles-v1.16 |
| Skull O'Maniac | `curse` | 0.1, 0.1, 0.1, 0.1, 0.1 | 5 | 0.5 | Mannajja | vs-gamefiles-v1.16 |
| Tiragisú | `revival` | 1, 1 | 2 | 2 | Phieraggi | vs-gamefiles-v1.16 |

In-game descriptions (level 1):

- **Spinach** (`spinach`, vsId `POWER`, rarity 100): Raises inflicted damage by 10%.
- **Armor** (`armor`, vsId `ARMOR`, rarity 100): Reduces incoming Damage by 1. Increases retaliatory Damage by 10%.
- **Hollow Heart** (`hollow_heart`, vsId `MAXHEALTH`, rarity 90): Augments Max Health by 20%.
- **Pummarola** (`pummarola`, vsId `REGEN`, rarity 90): Character recovers 0.2 HP per second.
- **Empty Tome** (`empty_tome`, vsId `COOLDOWN`, rarity 50): Reduces weapon cooldown by 8%.
- **Candelabrador** (`candelabrador`, vsId `AREA`, rarity 100): Augments area of attacks by 10%.
- **Bracer** (`bracer`, vsId `SPEED`, rarity 100): Increases projectile speed by 10%.
- **Spellbinder** (`spellbinder`, vsId `DURATION`, rarity 100): Increases duration of weapon effects by 10%.
- **Duplicator** (`duplicator`, vsId `AMOUNT`, rarity 50): Weapons fire more projectiles.
- **Wings** (`wings`, vsId `MOVESPEED`, rarity 50): Character moves 10% faster.
- **Attractorb** (`attractorb`, vsId `MAGNET`, rarity 100): Character picks up items from further away.
- **Clover** (`clover`, vsId `LUCK`, rarity 100): Character gets 10% luckier.
- **Crown** (`crown`, vsId `GROWTH`, rarity 70): Character gains 8% more experience.
- **Stone Mask** (`stone_mask`, vsId `GREED`, rarity 70): Character earns 10% more Gold coins.
- **Skull O'Maniac** (`skull_omaniac`, vsId `CURSE`, rarity 40): Increases enemy speed, health, quantity, and frequency by 10%.
- **Tiragisú** (`tiragisu`, vsId `REVIVAL`, rarity 40): Revives once with 50% Health.

Also base-game passive items outside the 16 requested, needed for two evolutions: Silver Ring, Gold Ring, Metaglio Left, Metaglio Right (all max level 9, stage-item only, no stat bonus fields in the data file).

## 2–3. Evolution / union recipes and conditions

| Evolved weapon | From | Required passive(s) | Must be MAX level | Union? | Source |
|---|---|---|---|---|---|
| Bloody Tear | Whip | Hollow Heart | — | no | vs-gamefiles-v1.16 |
| Holy Wand | Magic Wand | Empty Tome | — | no | vs-gamefiles-v1.16 |
| Thousand Edge | Knife | Bracer | — | no | vs-gamefiles-v1.16 |
| Death Spiral | Axe | Candelabrador | — | no | vs-gamefiles-v1.16 |
| Heaven Sword | Cross | Clover | — | no | vs-gamefiles-v1.16 |
| Unholy Vespers | King Bible | Spellbinder | — | no | vs-gamefiles-v1.16 |
| Hellfire | Fire Wand | Spinach | — | no | vs-gamefiles-v1.16 |
| Soul Eater | Garlic | Pummarola | — | no | vs-gamefiles-v1.16 |
| La Borra | Santa Water | Attractorb | — | no | vs-gamefiles-v1.16 |
| NO FUTURE | Runetracer | Armor | — | no | vs-gamefiles-v1.16 |
| Thunder Loop | Lightning Ring | Duplicator | — | no | vs-gamefiles-v1.16 |
| Gorgeous Moon | Pentagram | Crown | — | no | vs-gamefiles-v1.16 |
| Vandalier | Peachone, Ebony Wings | — | Peachone | yes | vs-gamefiles-v1.16 |
| Phieraggi | Phiera Der Tuphello, Eight The Sparrow | Tiragisú | Phiera Der Tuphello | yes | vs-gamefiles-v1.16 |
| Vicious Hunger | Gatti Amari | Stone Mask | — | no | vs-gamefiles-v1.16 |
| Mannajja | Song of Mana | Skull O'Maniac | — | no | vs-gamefiles-v1.16 |
| Infinite Corridor | Clock Lancet | Silver Ring, Gold Ring | Silver Ring, Gold Ring | no | vs-gamefiles-v1.16 |
| Crimson Shroud | Laurel | Metaglio Left, Metaglio Right | Metaglio Left, Metaglio Right | no | vs-gamefiles-v1.16 |

### Conditions

- Base weapon must be at max level (8 for all evolving base weapons; Clock Lancet and Laurel max at 7).
- Required passive must be owned at level 1+ (any level), EXCEPT: Infinite Corridor (Silver Ring + Gold Ring both max); Crimson Shroud (Metaglio Left + Metaglio Right both max).
- Trigger: treasure chest dropped by a stage/elite boss, earliest 600s (10:00). On standard stages, only chests from bosses that spawn after 10:00 can grant evolutions. Exceptions reported by community sources: Dairy Plant chests can evolve from the start of the run, and the Mad Forest 1:00 glowing-bat chest can evolve early. Evolution consumes the base weapon but NOT the passive item.
- Unions: A union merges two WEAPONS (Vandalier = Peachone + Ebony Wings; Phieraggi = Phiera Der Tuphello + Eight The Sparrow + Tiragisu). Both source weapons are consumed.
- The evolution consumes the base weapon; the passive item is kept.
- Chest timing/stage exceptions are **unverified** here (wiki unreachable) — see `unknowns`.

## 4. Evolved weapon stats

| Weapon | Damage (power) | Cooldown (s) | Repeat int. (s) | Area | Speed | Amount | Duration (s) | Pierce | Knockback | Crit % / mult | Pool | Lvls |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Bloody Tear | 4 | 1.35 | 0.1 | 1.3 | 1 | 2 | — | — | — | 0.1 / 2 | 30 | 1 |
| Holy Wand | 3 | 0.5 | 0.1 | 1 | 2 | 4 | — | 2 | — | — | 60 | 1 |
| Thousand Edge | 1.65 | 0.35 | 0.05 | 1 | 1.5 | 6 | — | 3 | 0.5 | 0.3 / 3 | 70 | 1 |
| Death Spiral | 6 | 4.0 | 0.05 | 1.2 | 0.8 | 9 | — | 1000 | — | 0.3 / 2 | 50 | 1 |
| Heaven Sword | 7.7 | 3.3 | 0.5 | 1.2 | 2 | 1 | — | — | 6 | 0.1 / 2.5 | 20 | 1 |
| Unholy Vespers | 3 | 3.0 | 0.0 | 1.75 | 1.5 | 4 | 3.0 | — | 4 | — | 50 | 1 |
| Hellfire | 10 | 3.0 | 0.2 | 1 | 1 | 2 | 0.1 | — | — | — | 20 | 1 |
| Soul Eater | 2 | 1.0 | 0.0 | 3 | 1 | 1 | 1.3 | — | 0 | — | 50 | 1 |
| La Borra | 4 | 4.0 | 0.3 | 2 | 1 | 4 | 4.0 | — | 0 | — | 30 | 1 |
| NO FUTURE | 3 | 1.0 | 0.0 | 1 | 2.8 | 1 | 3.0 | — | — | — | 50 | 1 |
| Thunder Loop | 6.5 | 4.5 | 0.0 | 4 | 1 | 6 | — | — | — | — | 70 | 1 |
| Gorgeous Moon | 0 | 60.0 | 0.0 | 1 | 1 | 1 | 1.0 | — | 1 | — | — | 1 |
| Vandalier | 2.8 | 1.0 | 0.025 | 2.2 | 1 | 20 | 4.0 | — | 2 | — | 100 | 8 |
| Phieraggi | 1.5 | 1.4 | 0.1 | 1 | 1 | 4 | — | 7 | 0.05 | 0.1 / 2 | 200 | 1 |
| Vicious Hunger | 3 | 8.0 | 0.3 | 1 | 1 | 2 | 7.0 | — | 0.1 | — | 60 | 1 |
| Mannajja | 4 | 4.5 | 0.0 | 6 | 1 | 1 | 2.0 | — | — | — | 30 | 1 |
| Infinite Corridor | 0 | 1.0 | 0.0 | 1 | 1 | 1 | 6.0 | — | 0 | — | 10 | 1 |
| Crimson Shroud | 0 | 8.0 | 0.1 | 2 | 1 | 1 | — | — | 20 | — | 50 | 1 |

Behavior:

- **Bloody Tear**: Evolved Whip. Can deal critical damage and absorb HP. (Requires: Hollow Heart)
- **Holy Wand**: Evolved Magic Wand. Fires with no delay. (Requires: Empty Tome.)
- **Thousand Edge**: Evolved Knife. Fires with no delay. (Requires: Bracer.)
- **Death Spiral**: Evolved Axe. Passes through enemies. (Requires: Candelabrador.)
- **Heaven Sword**: Evolved Cross. Can deal critical damage. (Requires: Clover.)
- **Unholy Vespers**: Evolved King Bible. Never ends. (Requires: Spellbinder.)
- **Hellfire**: Evolved Fire Wand. Passes through enemies. (Requires: Spinach.)
- **Soul Eater**: Evolved Garlic. Steals hearts. Power increases when recovering HP. (Requires: Pummarola.)
- **La Borra**: Evolved Santa Water. Damaging zones follow you and grow when they move. (Requires: Attractorb.)
- **NO FUTURE**: Evolved Runetracer. Explodes when bouncing and in retaliation. (Requires: Armor)
- **Thunder Loop**: Evolved Lightning Ring. Projectiles strike twice. (Requires: Duplicator.)
- **Gorgeous Moon**: Evolved Pentagram. Generates extra gems and gathers all of them. (Requires: Crown.)
- **Vandalier**: Union of Ebony Wings and Peachone. ()
- **Phieraggi**: Union of Phiera Der Tuphello and Eight The Sparrow. Scales with Revivals. (Requires: Tiragisú.)
- **Vicious Hunger**: Evolved Gatti Amari. Might turn anything into gold. (Requires: Stone Mask.)
- **Mannajja**: Evolved Song of Mana. Might slow enemies down. (Requires: Skull O'Maniac)
- **Infinite Corridor**: Evolved Clock Lancet. Halves enemies' health. (Requires: Gold Ring, Silver Ring.)
- **Crimson Shroud**: Evolved Laurel. Caps incoming Damage at 10. Retaliates when losing charges. (Requires: Metaglio Left, Metaglio Right.)

> `pierce` = `penetrating` in the data file (absent = 1 hit / not applicable). Death Spiral's 1000 pierce is the game's stand-in for infinite. Vandalier is the only evolved weapon with more than one level (8): +0.2 area at levels 2/4/6/8, −0.25s interval at 3/5/7.

## Conflicts

- **data.passives.attractorb.valuePerLevel** — values: [[0.5, 0.33, 0.25, 0.2, 0.33], "+100% pickup radius total (+20%/level, commonly quoted by community guides)"] — sources ['vs-gamefiles-v1.16', 'official-wiki'] — Game files give non-uniform per-level magnet values summing to 1.51. Community/wiki text usually says a flat per-level magnet increase. Game files taken as authoritative.
- **data.passives.hollow_heart.totalAtMax** — values: [1.0, "x1.2 per level compounding (= +148.8% at level 5)"] — sources ['vs-gamefiles-v1.16', 'fandom-wiki'] — Game file stores maxHp 0.2 per level; fandom text says 'multiplies Max Health by 1.2 per level' (multiplicative). Additive reading (+100% total) recorded in data.
- **data.evolutions.vandalier.requiresAtMaxLevel** — values: [["Peachone"], ["Peachone", "Ebony Wings"]] — sources ['vs-gamefiles-v1.16', 'official-wiki'] — Game file marks only Peachone in requiresMax; wiki/community state BOTH Peachone and Ebony Wings must be max level. Unresolved.
- **data.evolutions.phieraggi.requiresAtMaxLevel** — values: [["Phiera Der Tuphello"], ["Phiera Der Tuphello", "Eight The Sparrow"]] — sources ['vs-gamefiles-v1.16', 'official-wiki'] — Same pattern as Vandalier.
- **data.passives.armor.maxLevel** — values: [5, 3] — sources ['vs-gamefiles-v1.16', 'vs-gamefiles-v1.16'] — The in-run passive ITEM Armor has 5 levels (+1 each). The meta PowerUp 'Armor' bought with gold has 3 ranks. Do not confuse them; this file documents the in-run item.

## Unknowns

- data.evolutionRules.chestSpawnTimeSeconds (not present in game data files; value below taken from wiki summaries, not verified against a fetched page)
- data.evolutions.*.levels (evolved weapons other than Vandalier have a single level; per-level growth tables for base weapons are out of scope for this file)
- data.passives.*.unlockCondition
