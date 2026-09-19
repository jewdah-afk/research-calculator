# Architecture

Server-authoritative survivors-like. Mechanics are a **1:1 port** of the reference
data in `research/vs/` (see `SUMMARY.md`); everything player-facing (names, art,
audio, text) is ours. The mechanics layer is pure Luau and runs headless, so every
formula is unit-tested against the research before it ever runs in Studio.

```
src/shared/Types.luau       the interface contract (read this first)
src/shared/Tuning.luau      engine constants NOT in the research (stud scale etc.)
src/shared/Data/*.luau      generated reference data — never hand-edit
src/shared/Sim/*.luau       pure mechanics: no Roblox APIs, no Instances, no yields
src/server/*.luau           simulation, pools, weapon runner, game loop
src/server/Weapons/*.luau   one behaviour module per base weapon
src/client/*.luau           camera, HUD, level-up UI, visuals
tests/*.test.luau           headless tests (plain `luau`), research as oracle
tools/check_all.sh          THE gate: data fidelity + format + types + tests
```

## Non-negotiable rules

1. **`Sim/` is pure.** No `game`, `workspace`, `Instance`, `task`, `RunService`. Takes
   numbers and tables, returns numbers and tables. This is what makes it testable.
2. **Every number comes from `Data/` or `Tuning.luau`.** A numeric literal in `Sim/`
   or `server/` that is not `0`, `1`, `-1` or `2` and is not read from `Data/` must
   live in `Tuning.luau` with a comment saying it is NOT from the research and why
   it exists. Reviewers reject anything else.
3. **`UNKNOWN` is not zero.** `Data` marks absent source values with a sentinel.
   Every read of a field that can be `UNKNOWN` goes through `Sim/DataAccess.luau`,
   which substitutes the documented engine default from `Tuning.luau` and records
   which default was used. Never `or 0`.
4. **Weapon `levels` are deltas.** `Sim/WeaponLevels.statsAt` folds them.
   Nothing else touches `Data.Weapons.data[id].levels` directly.
5. **Interfaces live in `Types.luau` only.** Change a type there and every consumer
   is re-checked by `luau-lsp analyze` — that is the integration gate.
6. **String requires.** `require("./Sibling")`, `require("../Data/Weapons")`. Same
   file runs under plain `luau` and in Studio. `tools/convert_requires.py` exists as
   a fallback if a place cannot resolve them.
7. **Display names are ours.** `Data.*.data[id].name` is a reference label. Anything
   shown to a player reads `src/shared/DisplayNames.luau`, authored by us.

## Module map and ownership

Each row is one build agent. Files outside your row are read-only to you.

| Owner | Files | Depends on |
|---|---|---|
| `sim-core` | `Sim/Rng`, `Sim/DataAccess`, `Sim/Stats`, `Sim/Experience`, `shared/Tuning` | Data |
| `sim-weapons` | `Sim/WeaponLevels`, `Sim/Damage` | Data, Tuning, DataAccess |
| `sim-progression` | `Sim/LevelUp`, `Sim/Chests`, `Sim/Pickups` | Data, Stats, Rng |
| `sim-waves` | `Sim/Waves`, `Sim/EnemyStats` | Data, Tuning, DataAccess |
| `tests` | `tests/*.test.luau` for every `Sim/` module | research/vs/*.md as oracle |
| `server-enemies` | `server/EnemyManager`, `server/EnemyPresenter`, `server/SpatialHash` | Types, Tuning |
| `server-weapons-a` | `server/WeaponRunner`, `server/ProjectilePool`, `Weapons/{Whip,MagicWand,Knife,Axe,Cross,FireWand}` | Types, Sim/WeaponLevels, Sim/Damage |
| `server-weapons-b` | `Weapons/{KingBible,Garlic,SantaWater,Runetracer,LightningRing}` | Types (WeaponContext only) |
| `server-loop` | `server/GameLoop.server`, `server/PlayerSession`, `server/PickupManager`, `server/Spawner`, `shared/Net` | everything above, via Types |
| `client` | `client/Camera.client`, `client/Hud.client`, `client/LevelUpUi.client`, `client/Visuals.client`, `shared/DisplayNames` | Net, Types |

`sim-core` and `sim-weapons` interfaces are consumed by everyone; they are specified
below precisely enough to build against without waiting.

## Sim interfaces (in addition to Types.luau)

```lua
-- Sim/Rng
Rng.new(seed: number): Rng

-- Sim/DataAccess
DataAccess.num(value: any, defaultKey: string): number   -- UNKNOWN -> Tuning.defaults[defaultKey]
DataAccess.isUnknown(value: any): boolean

-- Sim/Stats
Stats.base(characterId: string): StatBlock                -- character base line
Stats.forLevel(characterId: string, level: number): StatBlock  -- + per-level bonuses
Stats.apply(stats: StatBlock, passives: {[string]: number}): StatBlock  -- + passives
Stats.effective(characterId, level, passives): StatBlock  -- the three above composed

-- Sim/Experience
Experience.xpToNext(level: number): number                -- research/vs/core_loop.md formula
Experience.cumulativeAt(level: number): number
Experience.gemValue(baseXp: number, growth: number): number
Experience.addXp(state: PlayerState, amount: number): number  -- mutates, returns levels gained

-- Sim/WeaponLevels
WeaponLevels.statsAt(weaponId: string, level: number): WeaponLevelStats
WeaponLevels.effective(base: WeaponLevelStats, player: StatBlock): WeaponInstanceStats
WeaponLevels.maxLevel(weaponId: string): number

-- Sim/Damage
Damage.roll(base: number, critChance: number, critMultiplier: number, rng: Rng): (number, boolean)
Damage.toPlayer(power: number, armor: number): number     -- armor rule per research
Damage.knockback(weaponKnockback: number, enemyKnockbackTaken: number): number

-- Sim/LevelUp
LevelUp.offer(state: PlayerState, rng: Rng): LevelUpOffer
LevelUp.apply(state: PlayerState, option: LevelUpOption): ()
LevelUp.canOffer(state: PlayerState): boolean            -- false when nothing is left
LevelUp.reroll / skip / banish(state, offer, rng)

-- Sim/Chests
Chests.roll(treasure: TreasureConfig, luck: number, rng: Rng, state: PlayerState, time: number): ChestResult

-- Sim/Pickups
Pickups.gemTier(xp: number): number
Pickups.floorEffect(itemId: string, state: PlayerState): ()

-- Sim/Waves
Waves.at(time: number): ActiveWave
Waves.eventsBetween(t0: number, t1: number): { WaveEvent }   -- due in (t0, t1]
Waves.bossesBetween(t0: number, t1: number): { { enemyId: string, time: number, treasure: TreasureConfig? } }
Waves.spawnCount(wave: ActiveWave, alive: number, sinceLast: number): number  -- see Spawner note

-- Sim/EnemyStats
EnemyStats.scaled(enemyId: string, time: number, playerLevel: number, curse: number): EnemyScaledStats
```

## Data flow (server, one Heartbeat)

```
GameLoop.step(dt)
  if paused: return                      -- run clock stops on level-up
  time += dt
  Spawner.step   -> Waves.at(time), spawnCount, EnemyManager.spawn(...)
                 -> Waves.eventsBetween / bossesBetween fire swarms and bosses
  EnemyManager.step(dt, playerX, playerZ)
                 -> move toward player, apply knockback decay, contact damage
                 -> deaths call back: PickupManager.dropGem, PlayerSession.kills++
  WeaponRunner.step(dt, ctx)             -- ticks every WeaponBehavior, moves projectiles
  PickupManager.step(dt, playerX, playerZ, magnet)
                 -> pulls gems, collects -> Experience.addXp -> queue level-ups
  PlayerSession.step(dt)                 -- recovery, i-frames, death/revival
  if levelUpsPending: pause; Net.LevelUpOffer:FireClient(LevelUp.offer(...))
  Presenters flush (BulkMoveTo) at Heartbeat; HUD at ~5 Hz
```

Client `ChooseOption` -> `LevelUp.apply` -> recompute `Stats.effective`,
`WeaponRunner.onStatsChanged` -> unpause (or offer the next pending level-up).

## Enemy simulation and presentation

`EnemyManager` is structure-of-arrays: parallel arrays `x, z, vx, vz, hp, typeIdx,
knockX, knockZ, alive` indexed by handle, with a free list. A uniform grid
(`SpatialHash`, cell = Tuning) answers `EnemyQuery`. Nothing per-enemy is an
Instance in the simulation.

Presentation is a **swappable seam**: `EnemyPresenter` owns a pool of anchored parts
and flushes positions with `workspace:BulkMoveTo` each Heartbeat, relying on Roblox's
native replication. If the place already has an enemy renderer, implement the same
`EnemyPresenter` interface over it and swap the require in `GameLoop`. The mechanics
do not change.

```lua
-- server/EnemyPresenter
Presenter.new(capacity: number): Presenter
Presenter:show(handle, typeId)      Presenter:hide(handle)
Presenter:flush(x: {number}, z: {number}, alive: {boolean}, facing: {number})
```

Projectiles follow the same pattern through `ProjectilePool`.

## Spawner note (documented model)

The wave data gives `minEnemiesOnScreen` and `spawnIntervalSeconds` but **no spawn
count per tick** (research gap). Model: every `spawnIntervalSeconds`, spawn
`max(0, minEnemiesOnScreen - alive)` capped at `Tuning.maxSpawnPerTick`, at random
points on a ring of radius `Tuning.spawnRingRadius` around the player. Enemies
farther than `Tuning.despawnRadius` are recycled and respawned on the ring, which
keeps the on-screen count meaningful. All four constants are in `Tuning` and flagged
as not-from-research.

## Player

Default Roblox character with a top-down locked camera (`Camera.client`). Server reads
`HumanoidRootPart.Position` for the simulation and sets `Humanoid.WalkSpeed` from
`stats.moveSpeed * Tuning.baseWalkSpeed`. Facing = last non-zero move direction.
Health is simulated by `PlayerSession`, not `Humanoid.Health` (armor, recovery,
i-frames and revival are all research rules).

## Out of scope for the first port

Evolutions, Arcanas, the PowerUp shop, save data, more than one stage, co-op. The
weapon system must leave room for evolutions (a `WeaponBehavior` with a different id)
without redesign.
