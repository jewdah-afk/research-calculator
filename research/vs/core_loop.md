# Vampire Survivors — Core Loop & XP (base game, no DLC)

Retrieved 2026-09-19. **Note on sourcing:** the official wiki (`vampire.survivors.wiki`), Fandom
(`vampire-survivors.fandom.com`) and `steamcommunity.com` are all blocked by this environment's
network egress proxy for direct page fetches. All figures below come from indexed search-engine
extracts of those exact pages; the canonical page URL is cited for each table, but the pages could
not be opened and read in full. Anything not present in those extracts is recorded as `null`.

## 1. Run structure

| Item | Value | Notes |
|---|---|---|
| Standard stage time limit | 1800 s (30:00) | Base-game stages |
| What happens at 30:00 | A Reaper ("Red Death") spawns | Unless Endless mode is enabled |
| Extra Reapers | 1 additional Reaper spawns every subsequent minute (2 at 31:00, 3 at 32:00, …), unbounded | |
| Reaper HP | 655350, further multiplied by the player's level at spawn time | |
| Reaper contact damage | 65535 | Effectively an instant kill |
| Reaper behaviour | Rushes directly at the player at high speed; not intended to be killable (dev-confirmed), though it is possible | |
| After killing the Red Reaper | Screen zooms in, bells toll 12 times, an unstoppable/unhittable "White Hand" reaper kills the player | |
| Survival reward | 500 Gold for surviving to the time limit | |
| Revival | Player may revive if Revivals remain; each stacking revive adds +100 Gold to the bonus | |

Sources: [The Reaper (official wiki)](https://vampire.survivors.wiki/w/The_Reaper) ·
[The Reaper (Fandom)](https://vampire-survivors.fandom.com/wiki/The_Reaper)

## 2. Level-up flow

| Item | Value | Notes |
|---|---|---|
| Options offered | 3, or 4 with a Luck-based chance | Game pauses on level up |
| 4-option chance | `Luck / (100 + Luck)` where Luck is total Luck in percentage points | Community "token bag" model; exact wiki formula not retrievable — flagged |
| Options are unique | Yes — no duplicate entries in one offer | |
| Slot-full behaviour | Once the player holds 6 different weapons, no new weapons are offered (only upgrades to owned ones); same rule independently for 6 passive items | |
| Nothing left to upgrade + Limit Break active | Level-ups offer extra levels on already-maxed weapons | |
| Reroll | Reshuffles the current offer into a new set | From the Reroll PowerUp: +2 per rank, max rank 5 (10 total) after all Reroll achievements; first rank costs 1000 gold |
| Banish | Permanently removes an item from the offer pool for the rest of the run | Banish PowerUp: +2 per rank, max rank 5 (10 total); first rank costs 100 gold |
| Skip | Declines the whole offer and grants XP instead | Skip PowerUp: +2 per rank, max rank 5 (10 total); first rank costs 100 gold |
| XP granted instead of an item | 20% of the XP required for the next level | Wiki extracts attribute the 20% both to Skip and to "Reroll and Banish" — see conflicts |
| PowerUp cost scaling | Each purchased rank raises the base cost of the next rank of that PowerUp by its initial price | |

Sources: [Level up](https://vampire.survivors.wiki/w/Level_up) ·
[Skip](https://vampire.survivors.wiki/w/Skip) · [Reroll](https://vampire.survivors.wiki/w/Reroll) ·
[Banish](https://vampire.survivors.wiki/w/Banish) · [PowerUps](https://vampire.survivors.wiki/w/PowerUps) ·
[Luck](https://vampire.survivors.wiki/w/Luck)

## 3. XP gems

| Tier | Colour | XP value | Notes |
|---|---|---|---|
| 1 | Blue | up to 2 | Exact per-drop value (1 vs 2) not stated in retrievable text |
| 2 | Green | up to 9 | |
| 3 | Red | anything above 9 (unbounded) | Also the tier used for merged/consolidated gems |

Gem values are scaled by the **Growth** stat (base 100% = ×1.0; Growth modifiers stack additively).

Sources: [Experience Gem](https://vampire.survivors.wiki/w/Experience_Gem) ·
[Growth](https://vampire.survivors.wiki/w/Growth)

### Gem merging / consolidation

| Item | Value | Notes |
|---|---|---|
| Max simultaneous gems on the map | 400 | Community-reported (Steam discussions), not confirmed on either wiki |
| Behaviour at the cap | The game picks one existing gem, converts it to a red gem, and adds the value of all further gem drops into it | Gems do **not** despawn; value is never lost |
| Purpose | Sprite-count/performance control | Off-screen missed gems condense into one large red gem, which can grant several levels at once |

Source: [Steam — "are there a cap on the number of gems are out?"](https://steamcommunity.com/app/1794680/discussions/0/3201496371582426598/)

## 4. Magnet / pickup radius

| Item | Value |
|---|---|
| Base Magnet | 30 (world units — radius in which gems and pickups are collected) |
| Stacking | Multiplicative |
| Upper limit | None |
| Visibility | Only shown in-run, not on the character-select screen |

Source: [Magnet](https://vampire.survivors.wiki/w/Magnet)

## 5. XP required per level

Formula (XP to go from level *n* to *n+1*):

```
n <=  20:  base(n) = 5 + 10 * (n - 1)
21 <= n <= 40:  base(n) = 195 + 13 * (n - 20)
n >=  41:  base(n) = 455 + 16 * (n - 40)

req(n) = base(n) + (600 if n == 20 else 2400 if n == 40 else 0)
```

Breakpoints: the per-level increment changes from **+10 → +13 at level 20→21** and from
**+13 → +16 at level 40→41**; one-off surcharges of **+600 XP at level 20** and **+2400 XP at
level 40**. To offset this, characters gain **+100% Growth at levels 20 and 40**, reverted with
−100% Growth at levels 21 and 41.

Source: [Level up](https://vampire.survivors.wiki/w/Level_up) · [Growth](https://vampire.survivors.wiki/w/Growth)

| From Lv | To Lv | XP required | of which one-off surcharge | Cumulative XP from Lv 1 |
|---|---|---|---|---|
| 1 | 2 | 5 | 0 | 5 |
| 2 | 3 | 15 | 0 | 20 |
| 3 | 4 | 25 | 0 | 45 |
| 4 | 5 | 35 | 0 | 80 |
| 5 | 6 | 45 | 0 | 125 |
| 6 | 7 | 55 | 0 | 180 |
| 7 | 8 | 65 | 0 | 245 |
| 8 | 9 | 75 | 0 | 320 |
| 9 | 10 | 85 | 0 | 405 |
| 10 | 11 | 95 | 0 | 500 |
| 11 | 12 | 105 | 0 | 605 |
| 12 | 13 | 115 | 0 | 720 |
| 13 | 14 | 125 | 0 | 845 |
| 14 | 15 | 135 | 0 | 980 |
| 15 | 16 | 145 | 0 | 1125 |
| 16 | 17 | 155 | 0 | 1280 |
| 17 | 18 | 165 | 0 | 1445 |
| 18 | 19 | 175 | 0 | 1620 |
| 19 | 20 | 185 | 0 | 1805 |
| 20 | 21 | 795 | 600 | 2600 |
| 21 | 22 | 208 | 0 | 2808 |
| 22 | 23 | 221 | 0 | 3029 |
| 23 | 24 | 234 | 0 | 3263 |
| 24 | 25 | 247 | 0 | 3510 |
| 25 | 26 | 260 | 0 | 3770 |
| 26 | 27 | 273 | 0 | 4043 |
| 27 | 28 | 286 | 0 | 4329 |
| 28 | 29 | 299 | 0 | 4628 |
| 29 | 30 | 312 | 0 | 4940 |
| 30 | 31 | 325 | 0 | 5265 |
| 31 | 32 | 338 | 0 | 5603 |
| 32 | 33 | 351 | 0 | 5954 |
| 33 | 34 | 364 | 0 | 6318 |
| 34 | 35 | 377 | 0 | 6695 |
| 35 | 36 | 390 | 0 | 7085 |
| 36 | 37 | 403 | 0 | 7488 |
| 37 | 38 | 416 | 0 | 7904 |
| 38 | 39 | 429 | 0 | 8333 |
| 39 | 40 | 442 | 0 | 8775 |
| 40 | 41 | 2855 | 2400 | 11630 |
| 41 | 42 | 471 | 0 | 12101 |
| 42 | 43 | 487 | 0 | 12588 |
| 43 | 44 | 503 | 0 | 13091 |
| 44 | 45 | 519 | 0 | 13610 |
| 45 | 46 | 535 | 0 | 14145 |
| 46 | 47 | 551 | 0 | 14696 |
| 47 | 48 | 567 | 0 | 15263 |
| 48 | 49 | 583 | 0 | 15846 |
| 49 | 50 | 599 | 0 | 16445 |
| 50 | 51 | 615 | 0 | 17060 |
| 51 | 52 | 631 | 0 | 17691 |
| 52 | 53 | 647 | 0 | 18338 |
| 53 | 54 | 663 | 0 | 19001 |
| 54 | 55 | 679 | 0 | 19680 |
| 55 | 56 | 695 | 0 | 20375 |
| 56 | 57 | 711 | 0 | 21086 |
| 57 | 58 | 727 | 0 | 21813 |
| 58 | 59 | 743 | 0 | 22556 |
| 59 | 60 | 759 | 0 | 23315 |
| 60 | 61 | 775 | 0 | 24090 |
| 61 | 62 | 791 | 0 | 24881 |
| 62 | 63 | 807 | 0 | 25688 |
| 63 | 64 | 823 | 0 | 26511 |
| 64 | 65 | 839 | 0 | 27350 |
| 65 | 66 | 855 | 0 | 28205 |
| 66 | 67 | 871 | 0 | 29076 |
| 67 | 68 | 887 | 0 | 29963 |
| 68 | 69 | 903 | 0 | 30866 |
| 69 | 70 | 919 | 0 | 31785 |
| 70 | 71 | 935 | 0 | 32720 |
| 71 | 72 | 951 | 0 | 33671 |
| 72 | 73 | 967 | 0 | 34638 |
| 73 | 74 | 983 | 0 | 35621 |
| 74 | 75 | 999 | 0 | 36620 |
| 75 | 76 | 1015 | 0 | 37635 |
| 76 | 77 | 1031 | 0 | 38666 |
| 77 | 78 | 1047 | 0 | 39713 |
| 78 | 79 | 1063 | 0 | 40776 |
| 79 | 80 | 1079 | 0 | 41855 |
| 80 | 81 | 1095 | 0 | 42950 |
| 81 | 82 | 1111 | 0 | 44061 |
| 82 | 83 | 1127 | 0 | 45188 |
| 83 | 84 | 1143 | 0 | 46331 |
| 84 | 85 | 1159 | 0 | 47490 |
| 85 | 86 | 1175 | 0 | 48665 |
| 86 | 87 | 1191 | 0 | 49856 |
| 87 | 88 | 1207 | 0 | 51063 |
| 88 | 89 | 1223 | 0 | 52286 |
| 89 | 90 | 1239 | 0 | 53525 |
| 90 | 91 | 1255 | 0 | 54780 |
| 91 | 92 | 1271 | 0 | 56051 |
| 92 | 93 | 1287 | 0 | 57338 |
| 93 | 94 | 1303 | 0 | 58641 |
| 94 | 95 | 1319 | 0 | 59960 |
| 95 | 96 | 1335 | 0 | 61295 |
| 96 | 97 | 1351 | 0 | 62646 |
| 97 | 98 | 1367 | 0 | 64013 |
| 98 | 99 | 1383 | 0 | 65396 |
| 99 | 100 | 1399 | 0 | 66795 |
| 100 | 101 | 1415 | 0 | 68210 |

## 6. Slots and caps

| Item | Value | Notes |
|---|---|---|
| Weapon slots | 6 | |
| Passive item slots | 6 | |
| Max weapon level | 8 (typical; a few weapons differ) | |
| Max passive item level | 5 | |
| Slots full | No new items of that type are offered; only upgrades to owned items appear | |
| Limit Break | When nothing is left to upgrade, offers further levels on maxed weapons | Unlocked content; not available by default |

Sources: [Level up](https://vampire.survivors.wiki/w/Level_up) ·
[Weapons](https://vampire-survivors.fandom.com/wiki/Weapons) ·
[Evolution](https://vampire.survivors.wiki/w/Evolution)

## Conflicts

- **XP granted by Skip vs Reroll/Banish** — search extracts of the Skip page state Skip grants 20%
  of the XP needed for the next level; extracts of the same page also phrase it as "Reroll and
  Banish provide 20% of the experience". Both readings recorded; the 20% figure itself is
  consistent.
- **Gem XP values** — the wikis give ranges ("up to 2", "up to 9", "beyond") rather than the exact
  discrete drop values; older community posts claim flat 1 / 5 / 10. Ranges are treated as
  authoritative, the flat values recorded as the conflicting claim.

## Unknowns (null in JSON)

- Exact discrete XP value of each individual blue/green/red gem sprite.
- Exact wiki formula for the 4-option Luck roll (only the community token model was retrievable).
- Reaper move speed.
- Whether the 400-gem cap is current/official (community source only).
- Whether every base-game stage's time limit is exactly 1800 s.
- Magnet's unit definition in engine pixels.
