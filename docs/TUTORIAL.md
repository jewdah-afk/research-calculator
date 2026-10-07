# Peckwood: How to play + progression guide

This is the player guide and the script for the future in-game tutorial. Each step lists **what the player does**, **what unlocks**, and a **tutorial hook** (the moment a tip or arrow should appear later). The text is kept short so it can be lifted straight into tooltips.

---

## 1. How to play (the basics)

| Action | How |
|---|---|
| Move | WASD / thumbstick, or **click / tap the ground** to walk there |
| Jump | Space / A button |
| Collect | Walk over popcorn. It's added to your popcorn (bottom-left). |
| Upgrade | Open a window from the bars on the right, press a green **BUY** key. Grey = can't afford yet. **BUY ALL** buys as many as you can. |
| Travel | **TELEPORT** (left) jumps to any open area. **MAP** zooms out to the whole landmass. |
| Shop | **SHOP** (left, the big tile): passes, 2x boosts, popcorn crates. |
| Profile | Your records, stats and leaderboards. |
| AUTO | Group perk: collects for you while you play other windows. |

**The core loop:** collect currency, buy upgrades that make you collect faster, then **reset a layer** (Molt, Evolve, ...) for a permanent currency that makes the next run much faster. Each reset opens a new area of the island.

**Big numbers:** values go K, M, B, T, Qa, Qi ... then composed suffixes. Every number in the game uses the same format.

---

## 2. Progression path

The world starts as one small island, **The Park**, in an ocean. Every unlock **terraforms the sea**: land rises out of the water from your coast and joins the new area to yours. When four areas around a gap are all open, the gap rises into a **snowy mountain range**. By the end you own one big continent.

| # | Area / feature | How to unlock | What you do there | Tutorial hook |
|---|---|---|---|---|
| 1 | **The Park** · Popcorn | Start | Collect popcorn, buy Popcorn Value, Faster Popcorn, Popcorn Cap, Wing Training | First 5 s: arrow to nearest popcorn. First 10 popcorn: point at the POPCORN bar + first BUY key. |
| 2 | **Molt** (Park) | Hold **1,000 popcorn** once | Reset popcorn + popcorn upgrades for **Plumes** (1 Plume per 1,000 popcorn held). Spend Plumes on Plume Keepsakes (permanent). | When 1,000 is reached: pulse the MOLT tab, explain "you lose popcorn, you keep Plumes forever". Hold-to-confirm on the first Molt. |
| 3 | **The Garden** · Seeds, Sparrow | Molt once | Sunflowers make **seeds** while you stand on the platform; Seed upgrades. **Sparrow** levels up from feeding and boosts popcorn spawns; Rebirb it at 16 sparrows. | Land rises toward the Garden: camera follows, then "Stand on the sunflower platform". |
| 4 | **The Castle** · Evolve | Buy **Unlock Evolve (100M popcorn)** | Feed the Castle Monster popcorn, twigs and moneta to **Evolve**. Evolving resets non-permanent upgrades, seeds and sparrows. Each Evolution opens the next area. | First time 100M is affordable: point at the UNLOCK key on the gate. |
| 5 | **The Bridge** · Fishing, Seagull | **Evolution 1** | Cast for fish, sell for **moneta**, craft better rods from fish, buy bait to choose the fish type, fill the **Fish Index**, place fish in the **Aquarium** for boosts. The **Seagull** fishes for you. | First visit: "Tap the water to cast". First catch: open Index. |
| 6 | **The Forest** · Nest, Red Panda | **Evolution 2** | Peck twigs, upgrade the **Nest** (Basic, then Sturdy at 100K twigs). **Red Panda** collects twigs while you're offline (up to 8 h). | First twig: point at NEST. Show the Sturdy goal bar. |
| 7 | **The Mine** · Crow | **Evolution 3** | Mine ore with the Crow: Mining Power, Ore Value, Charged Strike, Rupture. **Brute Ore** is kept through Evolve. | First strike: show the charge meter. |
| 8 | **The Desert** · Golden, Dave | **Evolution 4** | 5% of desert drops are **golden popcorn**. Golden upgrades; **Dave the Dove** forages golden popcorn. | First golden pickup: gold flash + explain "golden is kept through Molt". |
| 9 | **The Expedition** · Parrot, Quests, Sacrifice | **Sturdy nest** (100K twigs) | Fight floors with the **Parrot**, spend skill points (Health, Damage, Regen), collect gear. Daily **Quests** (floor, hunt, boss). **Sacrifice** at the altar for permanent milestone tiers. | First floor: show HP bar + SPEND skill points. |
| 10 | **The Echo Field** · Echo | **Evolution 5** | 25% of pickups **echo** into echo popcorn; Echo Value + Capacity upgrades. | First echo: pink pulse on the pickup. |

### What each reset keeps

| Reset | You lose | You keep |
|---|---|---|
| **Molt** | Popcorn, popcorn upgrades, Golden Value + Auric Silo, Echo upgrades | **Plumes** + keepsakes, golden popcorn, echo popcorn, twigs + nest |
| **Evolve** | Non-permanent upgrades, seeds + seed upgrades, sparrows, feeding progress, mine upgrades | Evolution level, **Brute Ore**, Plumes, twigs + nest, fish + rods |
| **Sparrow Rebirb** (16 sparrows) | Sparrows back to 1 | Rebirb bonus |
| **Seagull Migration** | Gull level | Migrations and their unlocks |
| **Parrot Rebirb** | Level, XP, skills | Gear and artifacts |
| **Dave Rebirb** | Dave level | Branch picks (up to 100 each) |

---

## 3. Tips for new players

1. **Buy the cheapest upgrade first** early on; Popcorn Value pays back fastest.
2. **Molt as soon as you can afford a meaningful Plume count** (start at 1,000 popcorn). Every Molt makes the next run faster.
3. **Don't skip the Sparrow:** more popcorn on the field means faster everything.
4. **Fish early** once the Bridge opens: moneta feeds the Castle Monster, and Aquarium fish are permanent boosts.
5. **Twigs are never reset.** Building the Sturdy nest early opens the Expedition.
6. **Golden and echo popcorn are kept through Molt.** Upgrade their *value* before Molting only if you will stay a while.
7. **Boosts stack with passes** (Shop): a 2x boost doubles every currency for its duration.

---

## 4. Tutorial build notes (for later)

- **Order of the first session:** collect, first BUY, Popcorn Cap fills, 1,000 popcorn, Molt (hold to confirm), land rises to the Garden. Target: the first Molt inside 5 minutes.
- **One tip on screen at a time.** Use the toast at the top; arrows only for the first popcorn, first BUY and first Molt.
- **Never block input.** Tips dismiss on the action they describe.
- **The objective bar** (bottom centre) always shows the next unlock from the table above (`Defs.ISLANDS[n].goal`).
- **Unlock moments are the reward beats:** the terraform camera move plays every time; the first highland (four areas around a gap) gets a one-time "A mountain range rose!" toast.
- **Returning players:** if they have been offline over 1 h, show the Red Panda twig total first.
