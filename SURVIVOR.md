# Survivor: Birb's combat loop for a quick roguelike

Module: `roblox/src/shared/Survivor.luau` (pure Luau, reuses `BirbSystems.enemyStats` / `parrotXpNeeded`).
Source: birbplay.com bundles re-pulled 2026-10-13 (`game-F2YVtiJe.js`, `main-DBqk1gka.js`, `editors-Bk1jOShp.js`, `maps-DNqux_gr.js`).

## What Birb actually has
Birb has no Vampire Survivors mode. The closest thing is the **expedition**, an auto-battler:
- You walk; the **Parrot** auto-targets enemies inside a **450px leash circle** around you and melees them.
- Enemies are placed in **depth bands** per floor (deeper = more HP), not spawned in timed waves.
- Kills give **skill points**, which also count 1:1 as parrot **XP**. A level-up refreshes stats and fully heals. There is no "pick 1 of 3" screen.
- **Run artifacts** (max 5, 6% drop per kill, rarity by floor) exist in the code (`checkArtifactDrop`), but nothing calls them in the live build. Players only use equipped artifacts now. That dead path is the roguelike pickup system, so the module exposes it.

## 1:1 with the original (in the module)
| Piece | Values |
|---|---|
| Parrot base | 100 HP, 100 dmg, speed 90 (chasing ×1.1), player speed 150, pickup radius 30 |
| Swing | 4 frames × 0.1s + 0.6s wait, all ÷ attack speed, sim at dt×2 → **0.5s / attackSpeed** per hit; hit on frame 2. Attack speed min 0.2, move min 0.25 |
| Stat stack | `(base + skill + artAdd) × equip × (1+art%) × (1+prog%) × (1+ext%) × final` (`tb`) |
| Hits on enemies | Generic enemies stunned 0.3s per hit; bosses/scripted ones not |
| Contact damage | Generic enemies within 25px: `0.5 × attack × dmgTaken`, 2s i-frames, 0.3s stun if not attacking |
| Regen | ×0.25 for 3s after a hit (Divine Symbol relieves 20%/power) |
| Artifact effects | Redline (Blood Beak), Opening Strike, Focused Assault, Storm Chain (every 6th hit, 90%, 2 targets, 110px), Resonant Recovery, Splitter Haste (every 5th hit, +30% AS 3s), Hunter Momentum (on kill +20% AS/MS 3s), Point Hoard (10/15% ×3 SP + buff), SP gain, scale per floor/kill/artifact. Best 2 copies count |
| Artifact stats | Run pickups × `1 + 0.08·(floor−1)^0.6`; equipped × `1 + 0.12·infusion` |
| Enemies | Floor scaling, elites (×5.5 HP, ×1.42 atk, ×1.14 spd, ×9.5 XP, ×4.5 SP), shiny, night = floor+9, respawns 480/300s. 43 types in `birb-data/data/` |
| Drops | Artifact 6%, rarity weights 55/25/12/6/2 (floor 1 common only, floor 2 up to uncommon), potion 2% |
| XP curve | `floor(10^(2 − s/6 + 11s²/6))`, s = log10(level) |

## Not ported
- Each enemy type's scripted AI (cobra venom, anubis summons, harpy dives, and so on). Only the generic chase-and-touch enemy is covered. Scripted types deal damage through their own attacks, not contact.
- Parrot pathing details (`parrotTactics`, strike anchors, wall checks). Use Roblox `MoveTo`/steering instead.
- Equipment chests from bosses/elites: the rarity table was only partly read.

## Suggested roguelike layer (our design, not Birb)
1. Arena around the player. Spawn generic enemies on a timer from the floor's enemy list, with `enemyStats(floor)` and minute ramps that bump the floor.
2. Parrot = auto-weapon, using `attackCycleSeconds`, the leash and the hit multipliers.
3. On level-up (`xpToNext`), offer 3 artifacts from `rollRarity` and apply them through `artifactBonuses` (cap 5).
4. Elite every N minutes, boss at the end, 2% potion drops.
