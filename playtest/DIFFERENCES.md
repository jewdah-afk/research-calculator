# Birb vs Peckwood: structural differences

Found while copying Birb into the playtest. Each row names what Birb does, what our Roblox build (`roblox/src`) or Figma does now, and the fix to make Peckwood match. Updated per phase.

| # | Area | Birb (source of truth) | Peckwood now | Fix |
|---|---|---|---|---|
| 1 | Sparrow unlock | Unlocks at **Evolution 1** (`onEvolutionReset` sets `sparrow.unlocked`) | Unlocks with the Garden, after the first Molt (`Defs.ISLANDS` garden row) | Move the Sparrow window to the Evolution 1 unlock |
| 2 | Map order | Park → Sunflower Field (needs 1 Molt) → Dungeon (needs Unlock Evolve) → Castle (enter through the dungeon). Nest is left of the Park (Evolution 3). The Desert is reached from the Park after the Desert tree key | Islands joined by bridges in `Defs.ISLANDS` order, no dungeon step | Keep our island layout but use Birb's gates for each island |
| 3 | Seeds | Seeds only come from **standing on the platform** (1 tick/s), or always with Auto Generator. Each tick pays a whole number of ticks × multipliers | A flat 3/s rate once the Garden is open (`G.seedsPerSec`) | Platform + Auto Generator gate, tick-based payout |
| 4 | Sunflower tree | A walkable map of 134 stations; you buy by standing on one. Nodes show only when a parent is owned and the evolution gate is at most one ahead | Only ~10 `d_*` unlocks are used, no tree screen | Build the tree screen (Figma `176:873` is a first pass) with these visibility rules |
| 5 | Evolution cost | Per evolution: 1e7 eggs; 1e10 eggs + 1,000 Moneta; 2.5e11 eggs + 3e7 seeds; 1e15 eggs + 1e5 twigs + 1e4 Moneta; 1e18 eggs + 1e6 twigs. Fed by holding (10% of each need per second) | `Defs.EVO` matches | None (keep the 10%/s hold) |
| 6 | Evolution reset | Keeps only permanent upgrades (not mine), permanent sunflower nodes plus Unlock Evolve, Desert key, Double Catch and Seagull Synergy. Clears eggs, golden, echo, Plumes, seeds, Moneta, twigs, fish inventory, bait, nest progress. Sparrow back to LV 0, 1 sparrow, resonance 0 | `G.evolve` resets "non-permanent upgrades, sparrows and feeding" | Match the keep list exactly |
| 7 | Sparrow rebirb | Needs 16 sparrows **and the nest's first tier** (`nestManager.canMigrate`) | 16 sparrows only | Add the nest gate |
| 8 | Sparrow features | Drain, resonance and milestones only work from **Evolution 2** | Not gated | Gate on Evolution 2 |
| 9 | Egg pickup | Collect radius 40 × Magnetic Field × Vacuum × Focus × quests; the magnet only pulls when a fish buff raises `pickup_mult` | `G.reachPx` = 14 × ... (a different base) | Use 40 px world units (scale to studs) |
| 10 | Field while away | The Park keeps spawning while you're elsewhere once the Sparrow is unlocked, and sparrows keep collecting | The field only runs on the Park | Keep the Park field ticking |
