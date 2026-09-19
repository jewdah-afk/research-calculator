# Vampire Survivors — Enemies, Waves & Bosses (Mad Forest) — BASE GAME ONLY

**Status: SEVERELY INCOMPLETE — network egress blocked.**
Retrieved 2026-09-19. Every primary source for this topic
(https://vampire.survivors.wiki, https://vampire-survivors.fandom.com,
https://antifandom.com mirror, https://steamcommunity.com, https://en.namu.wiki,
rogueranker.com, gameplay.tips) is blocked by this environment's egress proxy for
both WebFetch and curl (403 CONNECT / EGRESS_BLOCKED). Only the WebSearch tool
worked, which returns summarized snippets, not the wiki's Waves/Bestiary tables.

Therefore the minute-by-minute Mad Forest wave table and the per-enemy stat table
**could not be retrieved** and are recorded as `null` rather than guessed.
Re-run this task with `vampire.survivors.wiki` and `vampire-survivors.fandom.com`
allow-listed to complete it.

Times below are in SECONDS per SCHEMA.md.

## 1. Mad Forest wave table (0–1800s+)

NOT RETRIEVED. Source page exists at
https://vampire.survivors.wiki/w/Mad_Forest and
https://vampire-survivors.fandom.com/wiki/Mad_Forest#Waves (both blocked).

Only fragments confirmed via search snippets:

| time (s) | fact | source |
|---|---|---|
| 60 | A Glowing Bat spawns along the wave at 1:00; its chest is notable because it can evolve a weapon even though most evolutions require the 10-minute mark. | https://vampire.survivors.wiki/w/Treasure_Chest (via search snippet) |
| 540 | A Silver Bat appears at 9:00; its chest roll is base 3% for a 5-item chest, else 10% for a 3-item chest, else 50% for a 1-item chest. | https://vampire.survivors.wiki/w/Treasure_Chest (via search snippet) |
| 1800 | Once a stage's time limit is exceeded, The Reaper spawns, and further Reapers are added every minute. | https://en.namu.wiki/w/Vampire%20Survivors/%EC%8A%A4%ED%85%8C%EC%9D%B4%EC%A7%80 (via search snippet) |

Per-minute enemy composition, spawn counts/patterns, minimum enemies on screen,
spawn interval and per-wave modifiers: **unknown**.

Mad Forest enemy roster (20 entries, unordered, no times given) per
https://vampire-survivors.fandom.com/wiki/Category:Mad_Forest_enemies (via search snippet):
Bat Dragon, Bat Drakelet, Big Mummy, Boon Marrabbio, City Atlantean, Flower Wall,
Ghost, Giant Bat, Mantichana, Moon Atlantean, Mudman, Pipeestrello, Skeleton,
Skelewing, Sun Atlantean, The Reaper, Venus, Volcano Atlantean, Werewolf, Zombie.
Note: this category listing may include enemies added by later base-game patches;
the wave minute for each is unknown. Giant Bat first appears as a boss and in later
waves also as a normal enemy (https://vampire.survivors.wiki/w/Giant_Bat, snippet).
The stage opens with bats, zombies and skeletons of roughly 5–15 health (snippet,
unverified range).

## 2. Base enemy stats

Only two concrete statlines were obtainable, neither of them a Mad Forest common enemy
in confirmed form:

| name | health | power | moveSpeed | knockback | xp | source |
|---|---|---|---|---|---|---|
| Zombie | 10 | 10 | 100 | 0.8 | 1 | https://vampire.survivors.wiki/w/Enemies (via search snippet; unconfirmed which Zombie variant) |
| Milk Elemental (not Mad Forest) | 5 | 5 | 140 | 1 (max 3) | 1 | https://vampire.survivors.wiki/w/Enemies (via search snippet) |
| The Reaper | 655350 × player level at spawn | 65535 | 1200 | null | null | https://vampire-survivors.fandom.com/wiki/The_Reaper + https://en.namu.wiki/.../%EB%8A%A5%EB%A0%A5%EC%B9%98 (snippets) |

The remaining ~12 common enemies are unknown. Stat definitions confirmed:
Health = damage required to kill; Power = contact damage to player; MoveSpeed = movement
rate; Knockback = multiplier on knockback taken (final knockback = weapon knockback-dealt
× enemy knockback-taken); XP = experience granted on kill.
(https://vampire.survivors.wiki/w/Enemies, https://vampire.survivors.wiki/w/Knockback)

## 3. Scaling, bosses, chests

- Normal enemies scale primarily with elapsed time; bosses and minibosses scale with both
  time and player level. (community consensus via Steam discussions, cited in search results)
- "HP × Level" multiplies an enemy's health by the player's level, applied at the moment of
  spawn only — it is not updated if the player levels while the enemy is alive.
  (https://vampire.survivors.wiki/w/Enemies, snippet)
- Curse increases enemy Max Health, MoveSpeed and spawn frequency; the health multiplier
  applies immediately to newly spawned enemies only.
  (https://vampire.survivors.wiki/w/Curse)
- Hyper mode increases the minimum number of enemies spawned and enemy movement speed, and
  may increase their max health. (https://vampire.survivors.wiki/w/Stages)
- Endless mode: enemies gain 100% of base Max Health per cycle.
  Inverse mode: enemies start at +200% HP and gain +5% HP and +0.5 move speed per minute.
  (https://vampire-survivors.fandom.com/wiki/Stages, snippet)
- Treasure chests are dropped by bosses. Contents: a random weapon or passive the player
  already owns, levelled up by one; plus gold; plus an evolution/union if its requirements
  are met and the run is at 600s or later.
- Chest sizes are 1, 3 or 5 items, weighted by Luck. The first six chests picked up in a
  save always follow the fixed sequence 1-1-3-1-1-5.
- Gold: 1-item chest 100–200, 3-item 300–600, 5-item 500–1000 (base).
- Generally only one weapon can be evolved per chest, including higher-tier chests.
  (all chest facts: https://vampire.survivors.wiki/w/Treasure_Chest and
  https://vampire-survivors.fandom.com/wiki/Treasure_Chest, via snippets)
- Which specific Mad Forest bosses drop chests, and at which minutes: unknown, except the
  1:00 Glowing Bat and 9:00 Silver Bat noted above.

## 4. Map events on Mad Forest

Not retrieved. Confirmed only that Mad Forest's roster contains a **Flower Wall** entity
(https://vampire-survivors.fandom.com/wiki/Category:Mad_Forest_enemies) and that the only
destructibles on the stage are braziers/light sources which drop random pickups when broken
(https://vampire.survivors.wiki/w/Mad_Forest, snippet). Mad Forest is an open map with a
large area and very few obstacles. Bat-swarm, plant ring and timed-horde trigger times:
unknown.
