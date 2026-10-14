# Peckwood Rogue: the long grind (progression basis)

Goal: get the base loop solid first, then stack layers on top of it. Every layer below plugs into the same run loop, so we can ship with a few and add the rest later without redesigning anything. Some layers are bounded (you can finish them); the last ones are endless.

## The run loop (the base, build this first)
Run (10–15 min) → earn **Silver** + XP for the account and the character → spend in the Meta shop → the next run is a bit stronger or has more options.

## Layers, in the order to add them

| # | Layer | What you grind | Length | Notes |
|---|---|---|---|---|
| 1 | **Meta shop** (Silver) | Slots, starting stats, rerolls/banishes per run | ~10–20 h | Already designed (frame 7). Costs grow ×1.6 per level, like the Birb shops |
| 2 | **Unlocks** | Weapons, tomes, items, characters | ~20–40 h | Each unlock has a condition ("kill 500 with Kernel Pop", "reach minute 15 on Twilight"). Unlocking adds to the pool, which keeps runs fresh |
| 3 | **Character mastery** | Levels 1–20 per character | ~5 h each | Each level gives a cosmetic or a small perk, and a Legendary skin at 20. 15–20 characters × 5 h = 75–100 h |
| 4 | **Evolutions (codex)** | Discover weapon + item pairs | Collector goal | Hidden until found once. The codex shows silhouettes, so players hunt the missing ones |
| 5 | **Molt levels** (difficulty) | Molt 1 → 20 per biome | ~50–100 h | Like ascensions: each Molt adds a modifier (elite rate up, healing down, faster boss) and multiplies Silver. Ties into Peckwood's Molt name |
| 6 | **Biomes** | 6–8 procedural biomes | Gated by Molt | Each biome unlocks at a Molt level in the previous one. A new enemy list, a boss and a palette, all from one generator |
| 7 | **Endless mode** (infinite) | Survive past the final boss | Infinite | After minute 15 the timer keeps going and enemy floor scaling continues forever (Birb's `enemyStats(floor)` already scales without a cap). A weekly leaderboard for the longest survival per biome |
| 8 | **Daily and weekly seeds** | The same procedural map and roll seed for everyone | Infinite | One attempt per day, ranked. Cheap to build because maps are already seeded |
| 9 | **Rarity collection** | Find every item at every rarity (Common → Mythic) | Long-tail goal | This is where Mythic lives: 0.5% weight, boosted by Luck and Molt level. The reveal ladder makes every find feel big |

## Why this is long without being a chore
- **Bounded layers come first** (shop, unlocks, mastery) so new players always have a clear next goal.
- **Endless layers come last** (endless mode, seeds, collection) for players who finished everything.
- **Everything is one table per layer** (costs, conditions, modifiers), so adding content is data work, not code.
- **The simulator in `ROGUE_SCALE.md` checks every new layer**, so the power curve never runs away from the enemy curve.

## Ship order
Run loop → Meta shop → Unlocks → Molt 1–5 on one biome → Endless mode → then add characters, biomes and evolutions in content waves.
