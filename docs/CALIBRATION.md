# Calibration checklist — measuring the real game

Everything in `src/shared/Tuning.luau` marked **NOT from research** is a guess. The
reference data says an enemy has `speed = 100` but not what that looks like on screen.
These measurements, taken in the real game, turn each guess into a number.

Measure in **unit-free** terms — seconds, player-body-widths, fractions of screen width —
so the mapping into studs is a single conversion. Base character: the one with all
stats at baseline (Imelda: every stat 1.0, 100 HP). Minute 0, Mad Forest. Use a
stopwatch; a screen recording you can scrub is better.

Observe mechanics only. Do not extract or copy assets.

## A. Speeds

| # | Measure | Sets |
|---|---|---|
| A1 | Stand still. Time a zombie from **screen edge to touching you** (horizontal). Repeat 3×, average. | `enemySpeedScale` |
| A2 | Time yourself crossing the **full screen width** at base speed, no items. | reference for A1 (player = `baseWalkSpeed` 16 studs/s) |
| A3 | Same as A1 for a bat (minute 1) and a skeleton (minute 2+). | confirms scale is linear in `speed` |
| A4 | Magic Wand: time the missile from you to an enemy at **half screen width**. | `projectileSpeedScale` |
| A5 | Knife: same. Axe: note how high the arc goes in **screen heights**. | projectile scale, axe `gravity` |

Ratio A1/A2 is what matters: it says how much slower than you a zombie is.

## B. Sizes (in player body widths, or fraction of screen width)

| # | Measure | Sets |
|---|---|---|
| B1 | Whip Lv1: how far the slash reaches from your centre, sideways. | `areaScale` |
| B2 | Garlic Lv1: aura radius. | `areaScale` (cross-check) |
| B3 | King Bible Lv1: orbit radius. | `areaScale` (cross-check) |
| B4 | Santa Water Lv1: puddle diameter. | `areaScale` (cross-check) |
| B5 | Base magnet: how close a gem must be before it starts sliding to you. | `magnetScale` |
| B6 | Zombie body width vs your body width. | `enemyRadius` / `playerRadius` |
| B7 | Attractorb Lv1: magnet radius again (should be noticeably larger). | validates magnet stacking |

B1–B4 should agree on one scale. If they don't, note which weapon disagrees — that is a
finding about the reference data, not a measurement error.

## C. Knockback and contact

| # | Measure | Sets |
|---|---|---|
| C1 | Whip hit on a single zombie: how far it is pushed, in player widths. How long until it is walking at you again. | `knockbackScale`, `knockbackDecay` |
| C2 | Garlic on a zombie: pushed at all? how far. | knockback per weapon (research has some values) |
| C3 | Stand in a single zombie. How often does HP tick down (seconds between hits)? | contact damage cadence / i-frames |
| C4 | Stand in a crowd of 10. Same — is it faster, or capped? | whether damage stacks per enemy or per player i-frame |

## D. Spawning and the pressure curve

| # | Measure | Sets |
|---|---|---|
| D1 | Where do enemies appear — just outside the screen edge, or further? Roughly how far, in screen widths. | `spawnRingRadius` |
| D2 | Run away in a straight line for 20 s. Do enemies behind you vanish and reappear ahead? Roughly how far behind before they do. | `despawnRadius` and whether recycling exists |
| D3 | At 0:30, 1:00, 2:00, 5:00: rough count of enemies visible on screen. | validates our spawner model against `minEnemiesOnScreen` |
| D4 | At 1:00 the bat swarm: how many bats, from which side, how long it lasts. | swarm internals (research gap) |
| D5 | Any minute you see a **line/wall of flowers**: time and shape. | flower wall geometry (research gap) |

## E. Pacing (the strongest end-to-end check)

Same character, same weapon, play "normally" for 10 minutes. Note the **clock time** at
which you reach:

Lv 5 __ · Lv 10 __ · Lv 15 __ · Lv 20 __ · Lv 21 __

Then do the same in our port. If the spawner model and XP curve are right, these land
within ~10–15% of each other. If Lv 20→21 is *not* a visible stall in our port, the
+600 jump is broken. This single table validates more than any other measurement.

## F. Level-up UI (behaviour, not looks)

| # | Note |
|---|---|
| F1 | Does the game pause the instant a level is gained, or at the end of the current action? |
| F2 | With 3 options: are all three ever the same kind? Ever the same item twice? |
| F3 | When all 6 weapon slots are full, do new weapons stop appearing entirely? |
| F4 | Gain 2 levels at once (pick up a big gem): two menus back to back, or one? |

## How to send it

Paste the numbers here in a message, or as a photo/screenshot of your notes. Each row
maps to one constant; I will set it, cite the measurement in the comment, and re-run the
gates. Rows you skip stay flagged as guesses.
