# Onslaught 2.2: exact mechanics (1:1 spec)

This spec comes from the decompiled original, build `2350-gaby` (see `README.md` for how it was extracted). The HTML remake (`onslaught-html/engine.js`) and the Roblox port (`onslaught-roblox/src/shared/Onslaught/Engine.luau`) follow it line by line. Where the code and `defaults.json` disagree, **the code wins**, because the game only applies `ModDefaults` when a mod is turned on.

Units: pixels on a 720×480 board, milliseconds of game time, and rates in rounds per minute.

## 1. Clock and update timers
The game clock advances every frame (31 fps) by real time × `game_speed/100`. Everything else runs on its own interval:

| Thing | Updates every |
|---|---|
| Turret (`Turret.update`) | 70 ms (Fusion 64 ms, Combonly 1000 ms until armed) |
| Attacker manager (wave clock) | 200 ms |
| Wave spawner (`WaveManager`) | 200 ms |
| Shell (Blue/Sniper bullet), tweens, Shockwave walker | 32 ms |
| Rocket | 32 + rand·10 ms (rolled once per rocket) |
| Landmine trigger check | 150 ms |
| Black hole | 200 ms |
| Napalm sub-blasts | 75 ms |

Turrets can only fire on their own 70 ms ticks. A turret fires when `now − last_fire > 60000/rate` (strictly greater).

## 2. Waves and attackers
- The first wave is sent 20 000 ms after the game starts (`wave_spacing`, adjustable in prefs). Each later wave comes 20 000 ms after the previous one was sent. **Space / Next wave** sends one immediately and resets the clock. An optional pref, "wave follow", sends the next wave as soon as the field is empty.
- `_waveNext`: `wave += 1`. If the difficulty table has an entry for this wave, `rate = table[wave]`. Then `energy *= rate` (energy starts at 10, so wave 1 = 13 HP on Medium) and `value = wave`.
- Wave size is 10. HP and bounty are scaled by `10/size` (challenges change the size). Bounty is `round(value · 10/size)`, so a normal wave pays $wave per kill.
- Spawner: the first attacker appears on the spawner's first 200 ms tick, then whenever `now − last > 700`. Because of the 200 ms ticks, attackers end up **800 ms apart**.
- There are 9 attacker types, cycling: `type = (wave−1) % 9`. Types 1, 3, 4, 5, 7 and 8 rotate to face their heading (cosmetic).
- Movement is linear between waypoints at `move_speed` px/s (Easy and Medium 60, Hard and Extreme 80). Each waypoint target gets ±9.5 px of jitter. The spawn point is road[0] ± jitter. Reaching the last waypoint costs **1 life**, and you start with **10**.
- HP tables (wave → rate; each rate holds until the next listed wave):
  - Easy: 1→1.3, 10→1.2, 30→1.15, 40→1.1, 60→1.09, 80→1.05, 100→1.04, 120→1.03, 200→1.02
  - Medium: 1→1.3, 10→1.2, 20→1.25, 30→1.15, 40→1.1, 60→1.09, 80→1.05, 100→1.04, 120→1.03, 200→1.02
  - Hard: 1→1.4, 10→1.3, 30→1.2, 40→1.1, 60→1.05, 100→1.04, 120→1.03, 200→1.02
  - Extreme: 1.125 every wave
- **Slow (poison):** a spark subtracts from speed (`speed -= p`), and a blast divides it (`speed /= p`). Speed never drops below 5. A slowed attacker regains +2 speed every 1000 ms until it is back to its starting speed.

## 3. Targeting
- **Modes** (cycle with T): Nearest (default), Furthest, Weakest, Strongest, Slowest, Fastest (Yellow's default), Oldest, Youngest. "Weak/near/slow/young" pick the minimum value; the rest pick the maximum.
- **Sticky targets:** a turret keeps its current target while that target is alive and in range. **Lock off** (L) makes it drop the target after every shot.
- **Directional mode** (D): only targets within ±50°/30°/15° of a chosen angle count.
- **Focus** (F + click within 25 px of an attacker): every weapon turret's current target is set to that attacker.
- **Aiming:** turrets turn at `weapon_rotate` °/s. Blue and Green must face the target before firing. Red and Yellow don't need to.

## 4. Turrets
Base stats and upgrade tables are in `defaults.json`, except **Blue damage level 8 = 18 400** (the code value; `ModDefaults` says 19 400). An upgrade sets the stat to `amount[level]` (an absolute value), and `cash_value += cost`. "Upgrade %" is `floor(level/levels·100)`.

| Turret | Cost | Weapon | Notes |
|---|---|---|---|
| Blue Cannon | 10 | shell, 900 px/s | must face, 270°/s |
| Green Laser | 15 | instant laser | must face, chains with other greens |
| Red Rocket | 20 | homing rocket, 250 px/s, 270°/s turn | holding pattern at range 3 + rate 3 |
| Yellow Tazer | 50 | instant spark + slow | charge, target "fast", 720°/s |
| Sniper | 12 000 | instant hit, 3 M | not modifiable, no combos, 90°/s |
| Fusion Cannon | 12 000 | spark, **1 M** base | stores fire from greens/yellows in range |
| Railgun | 12 000 | 900 px beam, 40 px wide, 4 M | hits everything on the beam |
| Targeter | 1 400 | none | range 120 (upgrades 140/170/200/230 for 250/350/500/700), 240/min, links up to 3 turrets |
| Combonly | 5 000 | combo only | absorbs the turrets a chosen combo needs |

Modifiers (base range 80; one upgrade for 1500 raises it to 130) apply to every modifiable turret in range. Their effects stack additively: `effective = (base + Σadded) × max(0.2, 1 + Σmult)`.

**Green chain:** every green "offers" itself on its tick if it is ready to fire. When a green fires, each offering green within its range fires at it, recursively, and adds `its chain damage × 1.25` to the lead's shot.

**Yellow:** slow = `max(1, 10 × damage%/100)`, recomputed after the upgrade, so the cached effective value lags one step (as in the original). Charge grows by `10 + 2·rate_level` per second up to `100 + 10·damage_level`. A charged shot adds `charge/100 × 3` to the slow and uses 50 charge. Its **damage is not boosted**.

**Freakout** (Blue, Yellow): it arms at damage level 4 and rate level 4. The **first freakout fires on the next tick**, because `now >= undefined` is true in AS2 (confirmed by running the original). Each later one comes at `now + 40 000 + rand·40 000 − rate_level·4000`. Sequence: a 3000 ms warning, then `damage_mult += 3` and `rate_mult += 4` for 5000 ms (×4 damage, ×5 rate when nothing else modifies the turret).

**Red holding pattern:** at range level ≥ 3 and rate level ≥ 3, the Red pre-fires up to 4 rockets that circle while it has no target. They are all released at the next target.

**Fusion:** every 64 ms it makes one ready green or yellow in range fire at it. The Fusion stores `damage·1.15` and `slow·1.15`. It fires when `now − last_fire > 6000` and its own 30/min rate allows. Its shot does `eff + min(eff, stored)` damage and `min(100, stored slow)` slow.

**Build rules:** the turret center must be inside x 18–702, y 18–462. It must be ≥ 36 px from every other turret center. None of 8 points at radius 19 around it (N, S, E, W and the diagonals) may touch the road (half-width 15.5). **Moving** a turret costs $500. **Selling** refunds `ceil(cash_value × 0.7)`.

## 5. Combos
A turret becomes combo-capable when its damage is maxed. It can combo when `now − last_fire > its rate msec` and `now ≥ combo_next`. On each shot, it counts the other combo-ready turrets within **70 px** by colour, and the first matching rule for its own colour fires (the table is in `README.md`). The lead's `combo_next` becomes `now + recharge`. Partners it uses get `combo_next = now + recharge − 1`.

| Combo | Lead takes | Projectile | Hit | Blast | Extras |
|---|---|---|---|---|---|
| Clusterbomb | 1R | bomb 750 px/s | 5 M | small 7 M | 6 cluster rockets × 3.3 M |
| Sparky Clusterbomb | 1R 1Y | bomb | 5.5 M | small 4.7 M | 8 sparks × 0.8 M, slow 20 |
| Big Clusterbomb | 2R | bomb | 8 M | large 8 M | 10 rockets × 4.5 M |
| Laser Clusterbomb | 1R + green link | bomb | 2 M | medium 4 M | 5 laser rockets × 2 M, lasers 0.7 M + link |
| Big Laser Clusterbomb | 2R + green link | bomb | 4 M | large 6 M | 5 laser rockets × 2 M, lasers 0.9 M + link |
| Landmine | 1B | mine (flies 1 s) | – | small 9 M | |
| Big Landmine | 1R 1B | mine | – | large 15 M | |
| Sparky Landmine | 1R 1B 1Y | mine | – | small 15 M | 8 sparks × 1 M (default), slow 20 |
| Big Cluster Landmine | 2R 1B | mine | – | large 15 M | 10 rockets × 4.5 M |
| Big Laser Cluster Landmine | 2R 1B 1G | mine | – | large 9 M | 10 laser rockets × 2 M, lasers 1 M |
| BFG | 1R 1B (+ own chain) | orb 60 px/s, straight line | 5.8 M + chain | bfg 7.5 M + chain | laser 4.2 M + chain every 333 ms ≤ 250 px |
| Tazer BFG | 1R 1B | orb | 5.8 M | bfg 7.5 M | spark 4.2 M with slow every 333 ms |
| Rocket BFG | 1R 1B (+ own chain) | orb | 6.5 M + chain | bfg 7.5 M + chain | lasers 4.5 M + rockets 2 M every 500 ms |
| Laser Rocket | green link | rocket 100 px/s | 2 M + link | – | laser 2 M + link every 500 ms ≤ 200 px. The `laserblast_*` values in `Combos.as` are never used by any engine. |
| Tazer Rocket | yellow's slow | rocket 100 px/s | 2 M | – | spark 2 M every 500 ms ≤ 200 px |
| Poison Rocket | 1G 1B | rocket 150 px/s | 1000 | poison 100, ÷2 speed | |
| Nuke | 2B | rocket 150 px/s | 9 M | huge 60 M | |
| Black Hole | 2Y 1G | hole at a road point ≤ 90 px | – | – | pulls everything within 120 px for 3000 ms; **no bounty, no kill** |
| Shockwave | 1Y 1B + green link | spark | 1 M + link, slow −100 | shockwave 1 M ÷75 | 2 walkers along the road for 3 s, 150 px/s, (1−t)·1 M every 32 ms |
| Napalm | 1Y 1B 1R | rocket 250 px/s | Red's own damage | – | 16 tiny blasts × **1 M** (the Projectile default; `blast_damage` 2.5 M never reaches them), 75 ms apart, marching 15 px along the heading ±15 px |

All combo damage goes through the lead's damage modifiers (`modifyDamage`), except the poison blast (100) and the laser-rocket burst (1 M).

Blast diameters: tiny 70, small 100, medium 160, large/poison/bfg 190, huge 250, shockwave 200. Damage lands after the blast's grow time (60–105 ms) on every attacker within the radius.

Partners named in "Lead takes" only get their **combo** put on cooldown. They keep firing normal shots, except a green used for a link, which fires its laser at the lead.

Cluster rockets (Rocket9) circle until they find a target, then home onto the nearest attacker. Landmines take 1000 ms to land on a random road point within the lead's **max** range (±5 px). After that they check a 20 px box every 150 ms.

## 6. Modes and unlocks
- **Modes:** Easy, Medium, Hard, Extreme, Sandbox ($100k, all turrets), Super Sandbox ($1M), Tutorial, and Challenge (14 presets plus a custom builder; see `GameSelectChallenge.as`).
- **Unlocks from kills:** 300 Range Enhancer, 450 Damage Enhancer, 550 Rate Exchanger, 700 Range Exchanger, 850 Rate Enhancer, 1000 Big Damage Enhancer, 1100 Big Damage Exchanger, 1200 Targeter, 1300 Sniper, 1400 Fusion, 1500 Railgun, 1600 Combonly.
- **Account unlocks:**
  - Extreme: 2000 kills in a normal game.
  - Sandbox: 4000 kills on Medium.
  - Super Sandbox: 4000 kills on Hard.
  - Challenges: finish the tutorial.
  - Mods: 4000 kills on Easy, Medium and Hard.
