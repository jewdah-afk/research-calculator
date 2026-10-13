# Onslaught 2: data from the original game

This data comes from the original game's own code, not from wikis. It is the starting point for a Roblox remake.

- **Source:** *Onslaught 2.2* by slipcor (the original Playr developer), released free as a Windows Flash projector at https://slipcor.itch.io/onslaught-2. The build version is `2350-gaby`.
  - `Onslaught2.exe` sha256: `c9b67590…bbd77`
  - Embedded SWF (AS2, Flash 9) sha256: `630012c1…86ba`
- **How it was extracted:** the SWF trailer was cut out of the exe, then decompiled with JPEXS FFDec 22.0.2.
- **`source/`:** all 168 game classes (the Flash `mx` UI library is left out). The key files are `mods/ModDefaults.as` (every turret number), `Combos.as` (combo stats), `turrets/Turret{Red,Green,Blue,Yellow}.as` → `comboFire` (combo recipes), and `AttackerManager.as` / `WaveManager.as` (waves).
- **`defaults.json`:** `ModDefaults.as` and `Combos.as` converted by `to_json.py`. Regenerate it; don't edit it by hand.

Old web info (playr.co.uk/onslaught/about.php) describes **Onslaught 1**, which has only Red, Green and Blue, and an older combo list. Onslaught 2 adds the Yellow Tazer, the super turrets, and new combos (Napalm, Black Hole, Shockwave, the Tazer ones).

## Units
- **range:** pixels
- **rate:** rounds per minute
- **time:** ms
- **poison:** movement speed removed per second
- **upgrade_\* `amount`:** the absolute new stat at that level, not an increment. Level *n* costs `cost[n-1]`.

## Base turrets
| Turret | Cost | Damage | Range | Rate | Notes |
|---|---|---|---|---|---|
| Blue Cannon | 10 | 15 | 130 | 100 | must face target, rotates 270°/s |
| Green Laser | 15 | 25 | 100 | 60 | chains with nearby greens (`linkFire`) |
| Red Rocket | 20 | 50 | 200 | 50 | homing, no need to face |
| Yellow Tazer | 50 | 50 | 70 | 60 | poison 1, rotates 720°/s, charge shot |

Upgrade tables (max level = length of the list):

- **Blue**
  - Damage: cost 20,50,100,250,600,1000,1100,1200,1500 → 30,60,150,400,1200,3100,8500,19400,46000
  - Range: cost 30,100,200,500,950 → 140,150,165,180,220
  - Rate: cost 50,150,300,450,950,1000,1450 → 110,125,140,160,180,200,240
- **Green**
  - Damage: cost 20,50,125,300,700,850,950,1000 → 50,120,400,1500,3900,9300,19500,35000
  - Range: cost 15,25,40,65,105,170,275,445,720,1100 → 110,125,140,160,180,205,230,255,285,320
  - Rate: cost 30,75,180,300,450,600,800,900,1000 → 65,70,80,90,105,120,135,160,190
- **Red**
  - Damage: cost 50,100,200,350,650,1200,1300,1500,1500 → 120,350,800,1950,6050,11500,27000,48900,65000
  - Range: cost 35,80,160,400,900,1100,1300,1500 → 210,220,230,250,275,300,325,350
  - Rate: cost 30,60,115,200,340,600,900,1050,1150 → 60,70,85,100,115,135,155,180,210
- **Yellow**
  - Damage: cost 40,80,190,300,600,1000,1100 → 75,125,200,800,3500,11000,30000
  - Range: cost 50,100,300,600,1000 → 75,85,105,130,155
  - Rate: cost 50,100,225,390,650,1100,1450 → 70,80,90,100,120,150,180

**Freakout** (Blue and Yellow only). It unlocks at damage level 4 and rate level 4. While active, the turret gets ×3 damage and ×4 rate for 5000 ms, with at least 80000 ms between freakouts.

## Unlocks (by total kills) and modifier turrets
Modifiers have base range 80, and one range upgrade (cost 1500) raises it to 130.

| Kills | Turret | Cost | Effect on turrets in range |
|---|---|---|---|
| 300 | Range Enhancer | 2000 | +100 range |
| 450 | Damage Enhancer | 5000 | +40% damage |
| 550 | Rate Exchanger | 1200 | +60% rate, −40% damage, −10% range |
| 700 | Range Exchanger | 1000 | +100 range, −25% rate |
| 850 | Rate Enhancer | 3000 | +120% rate |
| 1000 | Big Damage Enhancer | 8500 | +100% damage |
| 1100 | Big Damage Exchanger | 3500 | +100% damage, −30% range, −30% rate |
| 1200 | Targeter | 1400 | targeting helper |
| 1300 | Sniper | 12000 | damage 3M, range 300, rate 30 |
| 1400 | Fusion Cannon | 12000 | damage 4M, range 300, rate 30 |
| 1500 | Railgun | 12000 | damage 4M, range 300, rate 30 |
| 1600 | Combonly | 5000 | combo-only plate |

`defaults.json` has the super turrets' upgrade tables.

## Combos
A turret becomes combo-capable once its **damage is fully upgraded**. When it fires, it counts the *other* combo-ready turrets in its combo range by colour, and the **first matching rule wins**. The colour of the lead turret decides which list is checked.

| Lead | Rule (others in range) | Combo |
|---|---|---|
| Red | ≥2 Blue | Nuke |
| Red | ≥1 Red, ≥1 Yellow, ≥1 Blue | Napalm |
| Red | ≥1 Blue, ≥1 Green | Poison Rocket |
| Red | ≥1 Yellow | Tazer Rocket |
| Red | ≥1 Green | Laser Rocket |
| Green | ≥2 Red, ≥1 Blue | Rocket BFG |
| Green | ≥1 Red, ≥1 Blue | BFG |
| Blue | ≥2 Red, ≥1 Green, ≥1 Blue | Big Laser Cluster Landmine |
| Blue | ≥2 Red, ≥1 Blue | Big Cluster Landmine |
| Blue | ≥2 Red, ≥1 Green | Big Laser Clusterbomb |
| Blue | ≥2 Red | Big Clusterbomb |
| Blue | ≥1 Blue, ≥1 Yellow | Sparky Landmine |
| Blue | ≥1 Red, ≥1 Yellow | Sparky Clusterbomb |
| Blue | ≥1 Red, ≥1 Green | Laser Clusterbomb |
| Blue | ≥1 Red, ≥1 Blue | Big Landmine |
| Blue | ≥1 Red | Clusterbomb |
| Blue | ≥1 Blue | Landmine |
| Yellow | ≥2 Yellow, exactly 1 Green | Black Hole |
| Yellow | ≥1 Yellow, exactly 1 Blue, exactly 1 Green | Shockwave |
| Yellow | ≥1 Red, exactly 1 Blue | Tazer BFG |

Combo damage and recharge times (for example, Nuke: recharge 7400 ms, bullet 9M, blast 60M) are in `defaults.json` → `combos`. How each combo consumes its partner turrets is in `Turret.as` (`comboFire*`, `comboTake`).

## Waves and enemies
- **Wave size and timing:** 10 attackers per wave, spawned 700 ms apart, with a new wave every 20000 ms. A new wave can also be called early.
- **Enemy types:** 9 types that cycle (`Attacker0..8`; the type is `(wave-1) % 9`).
- **HP:** starts at 10 and is multiplied by `rate` each wave. The rate changes at the listed waves and keeps its value until the next one.
  - Easy: w1 1.3, w10 1.2, w30 1.15, w40 1.1, w60 1.09, w80 1.05, w100 1.04, w120 1.03, w200 1.02
  - Medium: w1 1.3, w10 1.2, w20 1.25, w30 1.15, w40 1.1, w60 1.09, w80 1.05, w100 1.04, w120 1.03, w200 1.02
  - Hard: w1 1.4, w10 1.3, w30 1.2, w40 1.1, w60 1.05, w100 1.04, w120 1.03, w200 1.02
  - Extreme: 1.125 every wave
- **Bounty:** each kill pays **$wave number**. If a wave has a size other than 10, both HP and bounty are scaled by `10 / size`.
- **Speed:** 60 on Easy and Medium, 80 on Hard and Extreme.
- **Starting cash:** $30 (Sandbox $100k, Sandbox 2 $1M).
- **Modes:**
  - Easy, Medium, Hard, Extreme, Sandbox
  - Tutorial and Quick Tutorial
  - Map Tools (a map editor)
  - Mods
  - Challenge games: Warmup, Threetown, Spiffles, Limitations, Bounce, Bludgeon, Longshine, Speedshine, Hardshine, Duration, Clockers, Ripples, Smollocks. Their settings are in `GameSelectChallenge.as`.

## Not extracted yet
- Map/road layouts (`RoadManager.as`, `GameManagerMapping.as`, and map data in the SWF).
- Art and sounds (export them with `ffdec-cli -export image,sound,shape`).
- Exact combo ranges and the targeting-mode logic.
