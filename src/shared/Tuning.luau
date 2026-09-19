--!strict
--[[
	Tuning.luau — engine constants that are NOT in the research.

	Every number here is something the reference data does not define (it has no
	notion of studs, Roblox walk speed, or how many enemies to spawn per tick).
	Each is a playtest tunable and says so. Nothing from research/vs belongs here:
	balance numbers come from src/shared/Data.

	Ownership: seeded by the architect; any module may APPEND a constant under a
	clearly named section with a "NOT from research" comment. Never rewrite or
	reorder existing entries — other agents are appending concurrently.
]]

local Tuning = {
	-- ---------------------------------------------------------- world scale
	-- NOT from research. Roblox default Humanoid.WalkSpeed; player moveSpeed
	-- stat (1.0 = 100%) multiplies this.
	baseWalkSpeed = 16,
	-- NOT from research. Studs/second per unit of the reference `speed` field.
	-- Reference enemies at speed 100 should be slower than the player at
	-- moveSpeed 1.0; 0.12 puts them at 12 studs/s. Tune by feel.
	enemySpeedScale = 0.12,
	-- NOT from research. Studs per unit of reference `area` / hitbox radius.
	areaScale = 4,
	-- NOT from research. Studs/second per unit of reference projectile `speed`.
	projectileSpeedScale = 30,
	-- NOT from research. Studs per unit of reference `magnet` radius.
	magnetScale = 0.5,

	-- ------------------------------------------------------------- spawner
	-- The wave data gives min-on-screen and interval but no count per tick
	-- (research gap, see docs/ARCHITECTURE.md). These shape our model.
	spawnRingRadius = 70, -- NOT from research. Spawn distance from player (studs)
	despawnRadius = 110, -- NOT from research. Beyond this, recycle to the ring
	maxSpawnPerTick = 40, -- NOT from research. Cap per spawn interval
	enemyCapacity = 2500, -- NOT from research. Pool size; >= 2048 target
	projectileCapacity = 1024, -- NOT from research. Pool size
	gemCapacity = 400, -- research: gem cap on map (core_loop.md); merge beyond

	-- ---------------------------------------------------------- simulation
	spatialCellSize = 8, -- NOT from research. Grid cell (studs)
	enemyRadius = 1.5, -- NOT from research. Contact radius (studs)
	playerRadius = 2, -- NOT from research. Contact radius (studs)
	knockbackDecay = 8, -- NOT from research. Knockback velocity decay (1/s)
	knockbackScale = 10, -- NOT from research. Studs/s per unit knockback

	-- ------------------------------------------------------- data defaults
	-- Engine defaults substituted by Sim/DataAccess.num when a Data field is
	-- UNKNOWN. Keyed by the defaultKey the caller passes. Each is NOT from
	-- research: the shipped record simply omits the field.
	defaults = {
		weaponDuration = 0, -- weapon has no duration concept
		weaponPierce = 1, -- hits one enemy unless the record says otherwise
		weaponKnockback = 1, -- neutral knockback multiplier
		weaponHitboxDelay = 0,
		weaponProjectileInterval = 0,
		weaponCritChance = 0,
		weaponCritMultiplier = 1,
		enemyKnockbackTaken = 1,
		enemyXp = 1,
		-- NOT from research (sim-waves). Chance for a wave event whose shipped
		-- entry omits `chance` (enemies_waves.md §4: "Blank cells are fields the
		-- shipped wave entry omits (the event's own defaults apply)"; the
		-- default itself is not in the data). 100 = such an event always fires;
		-- the 300 s FLOWER_WALL ships an explicit 0 and is untouched by this.
		eventChancePercent = 100,
	},

	-- --------------------------------------------------------- sim-weapons
	-- NOT from research. Floor for contact damage after armor (Sim/Damage
	-- .toPlayer). The research states only "Reduces incoming Damage by 1" per
	-- Armor point (passives_evolutions.md §1); what happens when armor >= power
	-- is open question OQ-10. 0 = the hit is fully absorbed. Playtest tunable.
	contactDamageFloor = 0,

	-- ------------------------------------------------------------ sim-core
	-- NOT from research. The research has no random number generator, only
	-- probabilities. Sim/Rng is a Lehmer (MINSTD) linear congruential
	-- generator, state' = state * multiplier mod modulus, next() = state /
	-- modulus. Every product stays below 2^53, so the stream is exact in
	-- doubles and identical on every platform. These pick the stream, never
	-- a balance value.
	rng = {
		multiplier = 48271, -- NOT from research. Park-Miller MINSTD multiplier
		modulus = 2147483647, -- NOT from research. 2^31 - 1, prime
	},

	-- ----------------------------------------------------- sim-progression
	-- Percent <-> fraction scale for shipped percent fields. research/vs/
	-- pickups_meta.md §3 states the chest roll as
	-- "successChance = levelChance * totalLuck" with chances shipped as raw
	-- percents (chances [3, 10, 50]) and "totalLuck = 1 + (displayed Luck % /
	-- 100)"; research/vs/core_loop.md §2 states the 4th-option roll as
	-- "Luck / (100 + Luck)" in percentage points. This is that 100: a unit
	-- conversion, not a balance value.
	percentScale = 100, -- research/vs/pickups_meta.md §3, research/vs/core_loop.md §2
	-- NOT from research. research/vs/pickups_meta.md §2: "Luck multiplies
	-- only their [isRare entries'] weight ... The exact multiplier applied to
	-- the weight is still unknown." Sim/Pickups uses
	-- weight * (1 + (luck - 1) * rareDropLuckScale), linear in Luck and
	-- exactly 1.0 at base Luck (1.0). 1 = the weight scales with Luck itself.
	rareDropLuckScale = 1, -- NOT from research. Linear Luck scale on isRare weights

	-- ------------------------------------------------------- server-enemies
	-- Half-width (studs) of the player-centred uniform grid behind
	-- server/SpatialHash. Enemies past despawnRadius are recycled to the spawn
	-- ring each step, so everything alive fits inside; anything farther is
	-- clamped into an edge cell (still found, only slower). Must exceed
	-- despawnRadius plus the largest knockback excursion.
	spatialGridHalfExtent = 256, -- NOT from research. Grid half-width (studs)
	-- NOT from research. Placeholder enemy art for server/EnemyPresenter; the
	-- pooled anchored parts are ours, the reference has no stud sizes.
	enemyPresenter = {
		partSize = 3, -- NOT from research. Trash enemy part edge (studs)
		bossPartScale = 2, -- NOT from research. isBoss parts are this many times larger
		hiddenY = -500, -- NOT from research. Parking height for pooled parts not in use
	},

	-- ----------------------------------------------------- server-weapons-a
	-- NOT from research. Collision radius (studs) of a projectile at weapon
	-- area 1.0; behaviours multiply it by rt.stats.area. The reference sizes
	-- bullets by sprite, which has no stud equivalent.
	projectileRadius = 1.5,
	-- NOT from research. Whip slash hitbox at area 1.0, scaled by
	-- rt.stats.area: a rectangle reaching whipHalfLength * 2 studs outward
	-- from the player along facing, whipHalfWidth * 2 studs across. The
	-- reference hitbox is sprite-sized.
	whipHalfLength = 8, -- NOT from research. Half the slash reach (studs)
	whipHalfWidth = 2, -- NOT from research. Half the slash thickness (studs)
	-- research/vs/weapons.md, Axe: "Character Area is multiplied by 1.3 for
	-- this weapon" (OQ-13). Research-stated, but no Data field carries it.
	axeAreaMultiplier = 1.3, -- research/vs/weapons.md Axe targeting text
	-- NOT from research. Gravity (studs/s^2) pulling an axe back along +Z
	-- after its -Z (screen-up) launch; the reference value is pixel-space.
	axeGravity = 40,
	-- NOT from research. Sideways launch speed per extra axe, as a fraction
	-- of the upward launch speed, toward the facing side ("progressively
	-- wider arcs"). Axe k (k = 0 first) gets k * this sideways.
	axeSpreadStep = 0.35,
	-- NOT from research. Cross deceleration (studs/s^2) along its launch
	-- line: outward distance = v0^2 / (2 * this), so "Speed sets how far out
	-- it travels before reversing" (weapons.md, Cross) holds.
	crossDeceleration = 30,
	-- NOT from research. Angular spacing (radians) between neighbouring
	-- fireballs of one Fire Wand cast ("extra fireballs widen the ends of the
	-- arc", weapons.md). The arc is centred on the target.
	fireWandArcStep = 0.2,
	-- NOT from research. Radius (studs) within which Fire Wand picks its
	-- random target; stands in for "on screen" (spawnRingRadius is just off).
	fireWandTargetRadius = 60,
	-- NOT from research. Player-centred box (studs) that projectiles flagged
	-- `bounces` reflect off inside server/WeaponRunner (Runetracer: "bounces
	-- off screen edges"). Stands in for the screen edges.
	projectileBounce = {
		halfWidth = 48, -- NOT from research. Half-width along X (studs)
		halfDepth = 32, -- NOT from research. Half-depth along Z (studs)
	},
	-- NOT from research. Placeholder projectile art for server/ProjectilePool;
	-- parts park at enemyPresenter.hiddenY when unused.
	projectilePresenter = {
		partSize = 1.5, -- NOT from research. Projectile part edge (studs)
		flightHeight = 3, -- NOT from research. Height of the part centre (studs)
	},
	-- ------------------------------------------------------ server-weapons-b
	-- The Runetracer's "screen edges" are the projectileBounce box above
	-- (server-weapons-a); nothing here duplicates it.
	kingBible = {
		-- research/vs/weapons.md King Bible: "Area = orbit radius (capped) and
		-- bible hitbox size"; the cap and the stud sizes are not in the data.
		orbitRadiusCap = 12, -- NOT from research. Max orbit radius (studs)
		hitRadius = 1.5, -- NOT from research. Bible hitbox radius at Area 1.0 (studs); scales with Area
		-- research/vs/weapons.md King Bible: "Speed = rotation rate"; the
		-- base rate is not in the data.
		revolutionsPerSecond = 0.75, -- NOT from research. Orbit rate at Speed 1.0 (rev/s)
	},
	runetracer = {
		hitRadius = 1.5, -- NOT from research. Tracer hitbox radius at Area 1.0 (studs); scales with Area
	},
	santaWater = {
		-- research/vs/weapons.md Santa Water: "Below 4 total Amount the first
		-- bottle of a cast aims at the CLOSEST enemy; at Amount 4+ the bottles
		-- land in a clockwise, roughly circular pattern around the player."
		-- The threshold is research-stated; Weapons.data carries no field.
		circlePatternMinAmount = 4, -- research/vs/weapons.md (Santa Water targeting)
		ringRadius = 10, -- NOT from research. Landing-circle radius at Amount >= 4 (studs)
		fallTime = 0.4, -- NOT from research. Seconds a bottle is in the air before its zone opens
	},
	lightningRing = {
		targetRadius = 48, -- NOT from research. "on-screen" random-target radius around the player (studs)
	},
}

return Tuning
