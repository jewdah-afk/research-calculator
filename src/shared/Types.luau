--!strict
--[[
	Types.luau — the interface contract every module implements against.

	Modules are built in parallel by separate authors. Anything two modules
	must agree on lives here, and here only. Change a type here and every
	consumer is re-checked by `luau-lsp analyze` (tools/check_all.sh), which
	is the integration gate.

	Coordinates: the arena is the XZ plane in studs; Y is up and fixed.
	Time: seconds since the run started. The run clock STOPS while paused.
	Handles: enemies, projectiles and gems are integer indices into
	structure-of-arrays pools, never Instances, so 2048+ of each stay cheap.
]]

-- ------------------------------------------------------------------ stats
export type StatKey =
	"maxHealth"
	| "recovery"
	| "armor"
	| "moveSpeed"
	| "might"
	| "area"
	| "speed"
	| "duration"
	| "amount"
	| "cooldown"
	| "luck"
	| "growth"
	| "greed"
	| "magnet"
	| "revival"
	| "curse"

-- Effective player stats after character, level bonuses and passives.
-- Conventions match research/vs/SCHEMA.md: maxHealth/armor/amount/revival are
-- absolute; the rest are multipliers where 1.0 = 100% (cooldown 0.9 = -10%).
export type StatBlock = {
	maxHealth: number,
	recovery: number,
	armor: number,
	moveSpeed: number,
	might: number,
	area: number,
	speed: number,
	duration: number,
	amount: number,
	cooldown: number,
	luck: number,
	growth: number,
	greed: number,
	magnet: number,
	revival: number,
	curse: number,
}

-- ----------------------------------------------------------------- player
export type PlayerState = {
	characterId: string,
	level: number,
	xp: number, -- progress within the current level
	xpToNext: number,
	health: number,
	stats: StatBlock,
	weapons: { [string]: number }, -- weaponId -> level (1..maxLevel)
	weaponOrder: { string }, -- acquisition order, for slot display
	passives: { [string]: number }, -- passiveId -> level
	passiveOrder: { string },
	gold: number,
	kills: number,
	revivalsUsed: number,
	rerolls: number,
	skips: number,
	banishes: number,
	banished: { [string]: boolean }, -- itemIds removed from the offer pool
}

-- --------------------------------------------------------------- weapons
-- Absolute weapon numbers at a given weapon level (deltas already folded in),
-- BEFORE player stats are applied.
export type WeaponLevelStats = {
	damage: number,
	area: number,
	speed: number,
	amount: number,
	duration: number,
	cooldown: number,
	pierce: number,
	knockback: number,
	poolLimit: number,
	projectileInterval: number,
	critChance: number,
	critMultiplier: number,
	hitboxDelay: number,
}

-- The same numbers with the player's StatBlock applied. This is what a
-- behaviour reads every tick. `amount` is already an integer >= 1.
export type WeaponInstanceStats = WeaponLevelStats

export type EnemyHandle = number
export type ProjectileHandle = number

-- Read-only spatial queries over live enemies. Implemented by EnemyManager.
-- Every function is safe to call many times per tick; none allocate.
export type EnemyQuery = {
	count: () -> number,
	isAlive: (EnemyHandle) -> boolean,
	position: (EnemyHandle) -> (number, number), -- x, z
	-- Nearest living enemy to (x, z) within maxDist (studs); nil if none.
	closest: (x: number, z: number, maxDist: number) -> EnemyHandle?,
	-- Uniformly random living enemy within maxDist; nil if none.
	random: (x: number, z: number, maxDist: number, rng: Rng) -> EnemyHandle?,
	-- Fills `out` (cleared first) with handles within radius; returns count.
	inRadius: (x: number, z: number, radius: number, out: { EnemyHandle }) -> number,
	-- Fills `out` with handles inside an axis-aligned box centred on (x, z).
	inBox: (x: number, z: number, halfW: number, halfD: number, out: { EnemyHandle }) -> number,
}

-- Everything a weapon behaviour may do to the world. Implemented by WeaponRunner.
export type WeaponContext = {
	time: number,
	dt: number,
	playerX: number,
	playerZ: number,
	-- Unit facing vector (last non-zero movement direction), never zero.
	facingX: number,
	facingZ: number,
	-- Current movement input, may be zero.
	moveX: number,
	moveZ: number,
	query: EnemyQuery,
	rng: Rng,
	-- Apply damage. Crit is rolled by the caller via Damage.roll so the
	-- behaviour decides when to roll. Returns true if the enemy died.
	damage: (enemy: EnemyHandle, amount: number, knockback: number, weaponId: string) -> boolean,
	-- Server-simulated projectile pools (positions replicated by the presenter).
	spawnProjectile: (spec: ProjectileSpec) -> ProjectileHandle?,
	despawnProjectile: (ProjectileHandle) -> (),
	projectileAlive: (ProjectileHandle) -> boolean,
	projectilePosition: (ProjectileHandle) -> (number, number),
	setProjectilePosition: (ProjectileHandle, x: number, z: number) -> (),
	setProjectileVelocity: (ProjectileHandle, vx: number, vz: number) -> (),
	-- Fire-and-forget visual (aura pulse, slash arc, sky-drop zone, lightning
	-- strike). Rendered by clients; carries no gameplay state.
	visual: (spec: VisualSpec) -> (),
}

export type ProjectileSpec = {
	weaponId: string,
	x: number,
	z: number,
	vx: number,
	vz: number,
	-- Collision radius in studs (weapon area already applied by the caller).
	radius: number,
	-- Seconds until auto-despawn; <= 0 means until pierce is exhausted.
	lifetime: number,
	pierce: number, -- remaining enemies it may pass through; -1 = infinite
	damage: number,
	knockback: number,
	critChance: number,
	critMultiplier: number,
	-- Optional per-projectile behaviour flags read by WeaponRunner's mover.
	gravity: number?, -- studs/s^2 along -Z screen-up axis for Axe arcs
	bounces: number?, -- Runetracer: remaining wall bounces
	returnsToPlayer: boolean?, -- Cross boomerang
	visualKind: string,
}

export type VisualSpec = {
	kind: string,
	x: number,
	z: number,
	radius: number?,
	angle: number?, -- radians, for directional visuals
	duration: number?,
	weaponId: string?,
}

-- Per-weapon mutable state owned by the behaviour. Behaviours store whatever
-- they need under `state`; WeaponRunner only touches the typed fields.
export type WeaponRuntime = {
	weaponId: string,
	level: number,
	stats: WeaponInstanceStats,
	cooldownRemaining: number,
	state: { [string]: any },
}

-- A weapon behaviour module. One per base weapon in src/server/Weapons/.
-- `tick` is called every Heartbeat while unpaused. Behaviours must not hold
-- Instances, must not yield, and must read all numbers from `rt.stats`.
export type WeaponBehavior = {
	id: string,
	create: (rt: WeaponRuntime) -> (),
	-- Called on level-up and whenever player stats change; `rt.stats` is
	-- already updated. Behaviours re-derive any cached values here.
	onStatsChanged: (rt: WeaponRuntime) -> (),
	tick: (rt: WeaponRuntime, ctx: WeaponContext) -> (),
}

-- --------------------------------------------------------------- enemies
export type EnemyScaledStats = {
	health: number,
	power: number,
	speed: number, -- studs per second, after Tuning conversion
	knockbackTaken: number,
	xp: number,
	isBoss: boolean,
}

-- ---------------------------------------------------------------- waves
export type WaveEvent = {
	eventType: string,
	time: number,
	chancePercent: number,
	amount: number?,
	repeatCount: number?,
	delay: number?,
	duration: number?,
}

export type ActiveWave = {
	index: number, -- 1-based wave index into the stage table
	startTime: number,
	minEnemiesOnScreen: number,
	spawnIntervalSeconds: number,
	enemies: { string },
	bosses: { string },
	treasure: TreasureConfig?,
}

export type TreasureConfig = {
	chancePercent5Item: number,
	chancePercent3Item: number,
	chancePercent1Item: number,
	level: number,
	fixedPrizes: { string },
}

-- --------------------------------------------------------------- level-up
export type OptionKind = "weapon" | "passive"

export type LevelUpOption = {
	kind: OptionKind,
	itemId: string,
	-- Level the item will be at if chosen (1 = new acquisition).
	toLevel: number,
	isNew: boolean,
}

export type LevelUpOffer = {
	options: { LevelUpOption },
	rerollsLeft: number,
	skipsLeft: number,
	banishesLeft: number,
}

-- ----------------------------------------------------------------- chests
export type ChestResult = {
	itemCount: number, -- 1, 3 or 5
	gold: number,
	-- Items granted, in order. An evolution appears as kind "evolution".
	grants: { { kind: string, itemId: string, toLevel: number } },
}

-- -------------------------------------------------------------------- rng
-- Seeded, deterministic, allocation-free. Implemented by Sim/Rng.
export type Rng = {
	next: (self: Rng) -> number, -- [0, 1)
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number, -- inclusive
	chance: (self: Rng, p: number) -> boolean, -- p in [0, 1]
	pick: <T>(self: Rng, list: { T }) -> T,
}

-- ------------------------------------------------------------------ net
-- Server -> client HUD snapshot. Small, reliable, ~5 Hz.
export type HudState = {
	time: number,
	level: number,
	xp: number,
	xpToNext: number,
	health: number,
	maxHealth: number,
	kills: number,
	gold: number,
	weapons: { { id: string, level: number } },
	passives: { { id: string, level: number } },
	paused: boolean,
}

return nil
