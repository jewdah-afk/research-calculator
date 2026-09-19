# Vampire Survivors — Enemies, Waves & Bosses (Mad Forest) — BASE GAME ONLY

Retrieved 2026-09-19. Times in SECONDS per SCHEMA.md.

**Primary source: the shipped game data itself**, community-ripped with VampireUnpacker from
Vampire Survivors **v1.16**, base-game folder (DLC lives in separate folders):
- https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Stage.json  (source id `game-data-v1.16`)
- https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Enemy.json  (source id `game-data-v1.16-enemy`)

This is a community extraction, not an official page. It is used because
vampire.survivors.wiki, vampire-survivors.fandom.com, its BreezeWiki mirror,
steamcommunity.com and en.namu.wiki are all blocked by this environment's egress proxy
(403 on CONNECT) for both WebFetch and curl; only search-engine snippets of those pages
were obtainable, and they are cited as such where used.

Mad Forest is internal stage key `FOREST`, "Stage 1", time limit 1800s.

## Conventions
- Wave `time` = minute x 60 and is the START of the wave; the wave runs until the next one.
- `spawnIntervalSeconds` is the shipped `frequency` field (ms) converted to seconds.
- `minEnemiesOnScreen` is the shipped `minimum`: the game tops the field up to at least this many.
- Event `delay`/`duration` converted ms -> s; `chance` is a 0-100 percentage as shipped.
- Treasure `chances` ships as [5-item%, 3-item%, 1-item%].
- **Knockback caveat (unchanged from the earlier pass):** the shipped `knockback` field, stored
  here under the schema key `knockbackResistance`, is a knockback-TAKEN multiplier — HIGHER means
  knocked back FURTHER, i.e. LESS resistance. 0 = immune. The Reaper's -0.5 is negative.

## 1. Mad Forest wave table (source: `game-data-v1.16`)

Stage-wide: startingSpawns 10, destructibles = BRAZIER (freq 1s, chance 10% rising to 50%, max 10),
day/night cycle on. Stage mods: playerPxSpeed 1.1, enemySpeed 1.1, everything else neutral.
Hyper: playerPxSpeed 0.9, enemySpeed 0.9, projectileSpeed 0.25, goldMultiplier 0.5 ("50% Gold bonus"),
startingSpawns 15. Inverse: gold x2, enemy health x2, luck +0.2, +5% HP and +0.005 speed per minute.

| time (s) | min | interval (s) | enemies | boss | events | chest 5/3/1 % |
|---|---|---|---|---|---|---|
| 0 | 15 | 1.0 | BAT3 | - | - | - |
| 60 | 30 | 1.0 | ZOMBIE, BAT1 | BAT4 | - | 0/0/30 |
| 120 | 50 | 0.5 | BAT1, BAT2, BAT3 | - | BAT_SWARM delay 5s x2 | - |
| 180 | 40 | 0.25 | SKELETON | BAT4 | BAT_SWARM delay 5s x1 10% | 0/5/40 |
| 240 | 30 | 0.5 | SKELETON, GHOST | - | BAT_SWARM delay 5s x1 10% | - |
| 300 | 10 | 1.0 | MUDMAN2 | XLMANTIS | FLOWER_WALL 0% dur 30s | 1/5/100 |
| 360 | 20 | 0.5 | ZOMBIE, MUDMAN2 | - | BAT_SWARM delay 5s x1 10% | - |
| 420 | 80 | 0.5 | BAT2, BAT3, MUDMAN1 | BAT4 | BAT_SWARM delay 5s x5 80% | 3/10/50 |
| 480 | 100 | 1.5 | ZOMBIE | XLBAT | BAT_SWARM delay 15s x2 80% | - |
| 540 | 30 | 0.5 | XLBAT, ZOMBIE | BAT5 | BAT_SWARM delay 15s x2 70% | 3/10/50 |
| 600 | 10 | 0.5 | MUDMAN1, MUDMAN2 | BOSS_XLMANTIS | FLOWER_WALL | 3/10/100 |
| 660 | 300 | 0.1 | SKELETON |  | arcana holder BAT4 | BAT_SWARM delay 5s x1 10% |  (arcana 0/0/100) |
| 720 | 20 | 0.25 | WEREWOLF, GHOST, SKELETON | BAT4 | BAT_SWARM delay 5s x1 10% | 1/5/50 |
| 780 | 150 | 0.5 | WEREWOLF, GHOST, GHOST | - | GHOST_SWARM delay 1.2s x20 70%; GHOST_SWARM delay 2.3s x20 70% | - |
| 840 | 20 | 0.1 | XLBAT, WEREWOLF | BAT5 | - | 3/10/100 |
| 900 | 100 | 0.1 | WEREWOLF, XLBAT, MUDMAN2 | BOSS_WEREWOLF | FLOWER_WALL 80% | 3/10/100 |
| 960 | 100 | 0.1 | XLMANTIS, MUDMAN1, MUDMAN2 | BAT4 | - | 1/5/50 |
| 1020 | 20 | 1.0 | XLMUMMY | - | - | - |
| 1080 | 60 | 0.5 | XLMUMMY, MUDMAN1 | BAT5 | - | 3/10/100 |
| 1140 | 100 | 0.5 | XLMUMMY, MUDMAN1 | - | - | - |
| 1200 | 100 | 0.1 | XLMUMMY, MUDMAN2, XLBAT | BOSS_XLMUMMY | BAT_SWARM delay 1.2s x20 70%; BAT_SWARM delay 2.3s x20 70% | 3/10/100 |
| 1260 | 300 | 0.1 | FLOWER | XLFLOWER | arcana holder BAT4 | - |  (arcana 0/0/100) |
| 1320 | 200 | 0.1 | FLOWER, XLMUMMY | BAT4 | - | 3/10/100 |
| 1380 | 300 | 0.1 | FLOWER, XLMUMMY | BAT5 | - | 3/10/100 |
| 1440 | 300 | 0.1 | FLOWER, XLMUMMY | XLFLOWER | - | - |
| 1500 | 100 | 0.1 | XLFLOWER | BOSS_XLFLOWER | FLOWER_WALL delay 10s x5 dur 10s | 3/10/100 |
| 1560 | 150 | 0.1 | XLFLOWER, FLOWER | - | - | - |
| 1620 | 300 | 0.1 | XLMUMMY, MUDMAN1, MUDMAN2 | BAT4 | GHOST_SWARM; GHOST_SWARM delay 3s x19 | 3/10/100 |
| 1680 | 300 | 0.1 | XLBAT, BAT4 | - | - | - |
| 1740 | 300 | 0.1 | BAT4, BAT5 | BAT4 | BAT_SWARM; BAT_SWARM delay 3s x19 | 3/10/100 |
| 1800 | 1 | 10.0 | - | BOSS_XLDEATH | CYCLE_COMPLETE | - |

Spawn count per tick is not an explicit field in the shipped data (spawning is driven by
`minimum` + `frequency`), so it is recorded as unknown.

Prize-slot detail per wave lives in the JSON (`waves[].treasure.prizeTypes`). Notable:
minute 1 (60s) and minute 10 (600s) chests have `EVOLUTION` in slot 0 — this is the data-level
reason an evolution is possible at 60s on Mad Forest; minutes 11 and 21 use an `arcanaHolder`
(BAT4) whose chest is `EVO_ARCANA` at 100% 1-item.

## 2. Enemy statlines (source: `game-data-v1.16-enemy`)

Raw shipped values. `kbTaken` is the knockback caveat above. `lvl` is the record's own `level`
field; `HP_x_Level` marks enemies whose health is multiplied by a level factor at spawn.

| name | id | health | power | speed | kbTaken | maxKB | deathKB | xp | lvl | boss | skills |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Pipeestrello | BAT1 | 0.1 | 5 | 140 | 1 | 3 | 2 | 1 | 1 | no | - |
| Pipeestrello (variant) | BAT2 | 0.5 | 5 | 140 | 1 | 3 | 2 | 1 | 1 | no | - |
| Pipeestrello (variant) | BAT3 | 0.5 | 5 | 140 | 1 | 3 | 2 | 1 | 1 | no | - |
| Glowing Bat | BAT4 | 5 | 10 | 140 | 1 | 3 | 2 | 30 | 1 | no | HP_x_Level |
| Silver Bat | BAT5 | 5 | 10 | 140 | 1 | 3 | 2 | 30 | 1 | no | HP_x_Level |
| Zombie | ZOMBIE | 1 | 10 | 100 | 0.8 | 3 | 4 | 1 | 1 | no | - |
| Skeleton | SKELETON | 1.5 | 10 | 100 | 1 | 3 | 5 | 2 | 1 | no | - |
| Ghost | GHOST | 1 | 5 | 200 | 0 | 3 | 0 | 1.5 | 1 | no | - |
| Mudman | MUDMAN1 | 7 | 10 | 100 | 0.3 | 3 | 2 | 2.5 | 1 | no | - |
| Mudman (variant) | MUDMAN2 | 15 | 10 | 100 | 0.3 | 3 | 2 | 2.5 | 1 | no | - |
| Werewolf | WEREWOLF | 18 | 14 | 130 | 0.8 | 3 | 7 | 2 | 1 | no | - |
| Giant Bat | XLBAT | 27 | 10 | 140 | 0.1 | 3 | 2 | 2.5 | 10 | no | - |
| Mantichana | XLMANTIS | 50 | 20 | 80 | 0 | 3 | 0 | 3 | 10 | no | - |
| Big Mummy | XLMUMMY | 50 | 20 | 80 | 0 | 3 | 0 | 3 | 10 | no | - |
| Flower Wall | FLOWER | 3 | 1 | 20 | 1 | 3 | 2 | 2 | 1 | no | HP_x_Level |
| Venus | XLFLOWER | 50 | 20 | 80 | 0 | 3 | 0 | 3 | 10 | no | - |
| Mantichana (boss) | BOSS_XLMANTIS | 15 | 20 | 160 | 0 | 1 | 5 | 50 | 15 | yes | HP_x_Level |
| Werewolf (boss) | BOSS_WEREWOLF | 20 | 20 | 130 | 0.1 | 1 | 7 | 30 | 1 | yes | HP_x_Level |
| Big Mummy (boss) | BOSS_XLMUMMY | 25 | 20 | 80 | 0 | 1 | 5 | 25 | 15 | yes | HP_x_Level |
| Venus (boss) | BOSS_XLFLOWER | 15 | 30 | 160 | 0 | 1 | 1 | 50 | 30 | yes | HP_x_Level |
| The Reaper | BOSS_XLDEATH | 65535 | 65535 | 1200 | -0.5 | 0 | 0 | 0 | 100 | yes | HP_x_Level |

BAT2/BAT3 are unnamed palette variants of Pipeestrello (bVariants: BAT1, BAT2, BAT3, FANGEL1, FANGEL2).
BAT4/BAT5 are the Glowing Bat / Silver Bat chest-carriers (both maxHp 5, power 10, xp 30, HP_x_Level).
Bosses BOSS_XLMANTIS / BOSS_WEREWOLF / BOSS_XLMUMMY / BOSS_XLFLOWER all run scale 1.5, maxKnockback 1
and HP_x_Level; the first, third and fourth also carry res_Freeze 1.1. The Reaper (BOSS_XLDEATH) has
res_Defang / res_Freeze / res_Rosary / res_Knockback / res_Debuffs all at 1 and does not pass through walls.

**Conflicts recorded:** wiki snippets give Zombie health 10 and Reaper health 655350 x player level,
while the shipped data gives maxHp 1 and 65535. Power, speed, knockback and xp agree exactly in both
cases, so the wiki statbox appears to display health at roughly 10x the raw field. Unresolved — both
values are in the JSON `conflicts` array.

## 3. Scaling, bosses, chests

- `HP_x_Level` skill: health multiplied by a level factor at spawn; per the wiki this is the PLAYER's
  level at the moment of spawn, applied once and never updated. Mad Forest entities with it: BAT4,
  BAT5, FLOWER and all four BOSS_ entries plus the Reaper.
- Each enemy record also carries its own `level` (1 trash / 10 XL / 15, 30, 100 bosses). How that
  interacts with HP_x_Level is not stated in the data — unknown, not guessed.
- Normal enemies scale with elapsed time (the wave table); bosses and minibosses with time and level.
- Curse raises enemy Max Health, MoveSpeed and spawn frequency (new spawns only).
- Hyper raises min enemy count and speed; Mad Forest's shipped hyper block is listed above.
- Endless: +100% of base Max Health per cycle. Inverse: Mad Forest values listed above.
- Chests: dropped by the wave's `bosses` (and arcana holders). Tier chances are per-wave, listed in
  the table; Luck applies on top. Contents = an owned weapon/passive levelled by one, plus gold,
  plus an evolution/union when the slot allows and requirements are met; generally one evolution per
  chest at any tier. Gold 100-200 / 300-600 / 500-1000 by tier. The first six chests in a save follow
  the fixed sequence 1-1-3-1-1-5. (chest economy facts: https://vampire.survivors.wiki/w/Treasure_Chest,
  via search snippets; per-wave chances: `game-data-v1.16`.)
- Mad Forest boss-with-chest schedule, straight from the data: 60s BAT4 (0/0/30, EVOLUTION slot),
  180s BAT4 (0/5/40), 300s XLMANTIS (1/5/100), 420s BAT4 (3/10/50, chest level 2), 480s XLBAT (no
  chest entry), 540s BAT5 (3/10/50), 600s BOSS_XLMANTIS (3/10/100, EVOLUTION), 660s arcana BAT4,
  720s BAT4 (1/5/50), 840s BAT5 (3/10/100), 900s BOSS_WEREWOLF (3/10/100), 960s BAT4 (1/5/50),
  1080s BAT5 (3/10/100), 1200s BOSS_XLMUMMY (3/10/100), 1260s XLFLOWER + arcana BAT4, 1320s BAT4,
  1380s BAT5, 1440s XLFLOWER (no chest), 1500s BOSS_XLFLOWER (3/10/100), 1620s BAT4, 1740s BAT4,
  1800s BOSS_XLDEATH (The Reaper, no chest).

## 4. Map events on Mad Forest (trigger times, source: `game-data-v1.16`)

| time (s) | event | delay (s) | repeats | chance % | duration (s) |
|---|---|---|---|---|---|
| 120 | BAT_SWARM | 5.0 | 2 | - | - |
| 180 | BAT_SWARM | 5.0 | 1 | 10 | - |
| 240 | BAT_SWARM | 5.0 | 1 | 10 | - |
| 300 | FLOWER_WALL | - | - | 0 | 30.0 |
| 360 | BAT_SWARM | 5.0 | 1 | 10 | - |
| 420 | BAT_SWARM | 5.0 | 5 | 80 | - |
| 480 | BAT_SWARM | 15.0 | 2 | 80 | - |
| 540 | BAT_SWARM | 15.0 | 2 | 70 | - |
| 600 | FLOWER_WALL | - | - | - | - |
| 660 | BAT_SWARM | 5.0 | 1 | 10 | - |
| 720 | BAT_SWARM | 5.0 | 1 | 10 | - |
| 780 | GHOST_SWARM | 1.2 | 20 | 70 | - |
| 780 | GHOST_SWARM | 2.3 | 20 | 70 | - |
| 900 | FLOWER_WALL | - | - | 80 | - |
| 1200 | BAT_SWARM | 1.2 | 20 | 70 | - |
| 1200 | BAT_SWARM | 2.3 | 20 | 70 | - |
| 1500 | FLOWER_WALL | 10.0 | 5 | - | 10.0 |
| 1620 | GHOST_SWARM | - | - | - | - |
| 1620 | GHOST_SWARM | 3.0 | 19 | - | - |
| 1740 | BAT_SWARM | - | - | - | - |
| 1740 | BAT_SWARM | 3.0 | 19 | - | - |
| 1800 | CYCLE_COMPLETE | - | - | - | - |

Three event types occur on Mad Forest: `BAT_SWARM`, `GHOST_SWARM` and `FLOWER_WALL`, plus
`CYCLE_COMPLETE` at 1800s which closes the stage cycle and spawns the Reaper. Blank cells are fields
the shipped wave entry omits (the event's own defaults apply). The internal definitions of these
event types — how many enemies a swarm emits, and the geometry of the flower wall/ring — are not in
Stage.json and remain unknown.

Note the 300s FLOWER_WALL is shipped with `chance: 0`, i.e. it never fires at minute 5 as shipped;
the minute-10 one has no chance field (default), minute 15 is 80%, and minute 25 fires five times
on a 10s delay with a 10s duration.
