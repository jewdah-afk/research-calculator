# Peckwood Rogue: design (Megabonk-style UI reference)

A clean 3D survivors-like for Roblox. Mechanics are our own. The structure is taken from Megabonk (genre conventions and public numbers), and the theme is Peckwood/Birb.
Sources: community guides for Megabonk v1.0.7 (GuruGamer, Grindnstrat, Dexerto, Destructoid, Twinfinite) and patch notes. **UI layout notes below come from public descriptions and general familiarity. Confirm them against screenshots before building screens.**

## 1. Core loop (one run ≈ 10–15 min)
1. Third-person 3D character: run, jump, slide. Weapons fire on their own.
2. Enemies swarm from the edges and ramp up every minute. Elites and a timed boss arrive, then a final "everything spawns" phase.
3. Kills drop **XP gems** (pull them in with pickup range) and **gold**.
4. **Level-up → pick 1 of 3** upgrade cards, with Reroll / Banish / Skip.
5. The map has **chests** (gold cost that rises each time you open one), **shrines** (stand in them to charge a stat buff) and vendors.
6. Death or timer end → **Silver** (meta currency) → permanent unlocks: more weapon and tome slots, new weapons, characters.

## 2. Build system (Megabonk structure)
- **Weapons** (start 2 slots, up to 4 with meta unlocks). Each has its own stat pool, and upgrades only affect that weapon.
- **Tomes** (start 2 slots, up to 4). Each is one global stat that affects every weapon. Picking one up gives an immediate common upgrade.
- **Items** come from chests: passive effects with no slots (e.g. "weapon upgrades roll +1 stat").
- **Upgrade cards** have a rarity that scales the common values: Common ×1, Uncommon ×1.2, Rare ×1.4, Epic ×1.6, Legendary ×2. Luck pushes rarity up.
  - Weapon card: Common rolls 1–2 stats from the pool, Uncommon+ always 2.
  - Tome card: always its single stat.

### Stat stacking (use these exact rules)
| Stat | Rule |
|---|---|
| Damage | weaponDmg × (charBase × tome × (1 + shrine)) |
| Projectile count | additive: weapon + tome + shrine |
| Size, pickup range | weapon × charBase × (1 + tome + shrine) |
| Armor | i / (0.75 + i) |
| Evasion | i / (1 + i) |
| Crit damage | base ×2, (1 + weaponCritDmg) × char |

### Starter tome values (common, per pick)
HP +25 · Regen +40 · Shield +25 · Armor +12% · Evasion +10% · Lifesteal +10% · Thorns +15 · Damage +0.08× · Crit +7% · Cooldown +7.5% · Quantity +1 · Size +10% · Proj Speed +15% · Duration +15% · Knockback +20% · Agility +15% · Luck +7% · Curse +3.5% · Attraction +75% · XP +9% · Gold +12%

### Peckwood weapon set (our names, Birb flavour, sample stats `base / common upgrade`)
| Weapon | Behaviour | Stats |
|---|---|---|
| Parrot Strike | homing pet melee (Birb parrot logic: leash, stun, storm chain) | Dmg 11/+2, Count 1/+1, Size 100%/+20% |
| Kernel Pop | popcorn burst AoE around you | Dmg 6/+1.4, Size 100%/+14% |
| Feather Volley | straight piercing projectiles | Dmg 9/+1.8, Count 1/+1, Crit 0/+8% |
| Seed Spitter | fast bouncing shots | Dmg 5/+2.5, Bounces 0/+1, Count 6/+1 |
| Crow Pick | big swing, knockback | Dmg 12/+3, Knockback 2.5/+0.6 |
| Gull Dive | periodic airstrike, duration zone | Dmg 10/+3, Duration 4s/+0.4s |
Birb artifacts (Blood Beak, Storm Locket, Point Hoard…) become **items** using `Survivor.luau` effects.

## 3. UI (Megabonk-style reference, Peckwood UI v2 art)
**HUD**
- **Top-left:** HP bar (shield shown as an overlay), level number, and an XP bar right under it.
- **Top-center:** run timer and kill counter.
- **Top-right:** minimap with gold and current chest price beside it; shrine counter (available/used).
- **Bottom-left:** weapon slot row and tome slot row. Square icons with a level pip and a rarity-coloured border; empty locked slots show a padlock.
- **Center:** damage numbers (crits in a bigger, different colour), pickup magnet trails, boss bar on top when a boss spawns.

**Level-up screen (pauses the game)**
- 3 tall cards side by side. Rarity frame colours: grey / green / blue / purple / gold.
- Each card shows the icon, name, "NEW" or "LV x → y", and the stat lines with deltas (`Damage +2.4`).
- Buttons under the cards: **Reroll (n)**, **Banish (n)**, **Skip**. Gamepad- and touch-friendly, and the selection must not jump from movement input.
- Several stacked level-ups chain one after another. Show "+2 more" badge.

**Chest / shrine popups:** item card reveal with a rarity flash, banish option, and a list of banished items. **Pause menu:** full build (weapons, tomes, items, stats panel, banished list).

**End screen:** time survived, kills, level, damage per weapon, Silver earned, then a meta shop.

Roblox notes: build every screen by duplicating the UI v2 frames in Figma (per CLAUDE.md), keep HUD y<60 clear of the Roblox menu, and use larger tap targets on mobile.

## 4. Build order
1. Character controller, camera and arena map.
2. Enemy spawner (timeline table, per-minute ramp, elites, boss) plus contact damage.
3. Weapons framework (stat pool → behaviour) with 2 weapons.
4. XP gems, levels, level-up card screen (roll, rarity, reroll/banish/skip).
5. Tomes and the stacking rules module.
6. HUD.
7. Chests, gold, shrines.
8. Meta progression (Silver, slots).
