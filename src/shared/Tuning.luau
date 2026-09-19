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
		-- Reserved: no DataAccess.num call site passes this defaultKey yet (an
		-- AC-U02 exception, recorded here). Kept because Tuning is append-only
		-- under AC-N03 and this entry predates the current pass; 0 = a weapon
		-- with no shipped projectile interval fires its shots unspaced.
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
		-- NOT from research (server-loop). Repeats and spacing for a wave
		-- event whose shipped entry omits them (enemies_waves.md §4: "Blank
		-- cells are fields the shipped wave entry omits (the event's own
		-- defaults apply)"; the defaults themselves are not in the data).
		-- 1 = the entry happens once; 0 = its repeats are not spaced out.
		eventRepeatCount = 1,
		eventDelaySeconds = 0,
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

	-- NOT from research. Placeholder look of the pooled gem parts in
	-- server/GemPresenter; parts park at enemyPresenter.hiddenY when unused.
	gemPresenter = {
		partSize = 1, -- NOT from research. Gem part edge (studs)
		floatHeight = 1, -- NOT from research. Height of the part centre (studs)
		tierHueStep = 0.33, -- NOT from research. Hue difference between gem tiers
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
	-- ----------------------------------------------------------- server-loop
	-- NOT from research. Seconds between HUD pushes (server/GameLoop). The
	-- HUD is a snapshot, not a simulation input, so ~5 Hz is plenty and keeps
	-- the remote quiet; the run itself steps every Heartbeat regardless.
	hudPushInterval = 0.2, -- NOT from research. HUD push period (seconds), ~5 Hz
	-- NOT from research (server-loop): anti-teleport slack on the per-tick
	-- move clamp in server/GameLoop. A frame's displacement may exceed
	-- moveSpeed * dt by this factor -- enough for frame jitter and a
	-- dash-like burst, tight enough that a teleport never lands.
	moveStepMargin = 3,
	-- NOT from research. Invulnerability window (seconds) after the player
	-- takes contact damage, in server/PlayerSession. server/EnemyManager
	-- reports a contact EVERY step for every enemy in reach, and the research
	-- states no hit cadence at all (core_loop.md and enemies_waves.md give
	-- contact `power` and nothing about how often it lands), so without a
	-- window a single enemy would deal power x 60 damage per second. Open
	-- question: the reference's real cadence. Playtest tunable.
	invulnerabilitySeconds = 0.5,
	-- research/vs/pickups_meta.md §5 (PowerUp shop, Revival): "Revives once
	-- with 50% health." Research-stated, but no Data field carries it -- the
	-- shipped record holds the revival COUNT, not the health restored.
	revivalHealthFraction = 0.5, -- research/vs/pickups_meta.md §5
	-- NOT from research. Gem pull speed (studs/s) once a gem is inside the
	-- magnet radius, in server/PickupManager. The reference pulls gems in
	-- pixel space; this is its stud equivalent. Comfortably faster than the
	-- player at baseWalkSpeed so a gem in range is never outrun.
	gemPullSpeed = 40,
	-- NOT from research. Distance (studs) at which a pulled gem counts as
	-- collected. Small enough to look like a pickup, large enough that one
	-- Heartbeat of gemPullSpeed cannot step over it.
	gemCollectRadius = 1.5,
	-- NOT from research. Studs the gem for a kill is offset from the corpse,
	-- picked uniformly in [-this, this] on each axis, so a stacked swarm does
	-- not drop every gem on one point. Cosmetic scatter only; no value moves.
	gemDropScatter = 1,
	-- NOT from research. Slack on the weapon cooldown comparison in
	-- server/WeaponRunner. A cooldown counted down by a fixed dt lands on the
	-- boundary with float residue of either sign (1.35 - 27 x 0.05 evaluates
	-- to -5.4e-16, 1.0 - 10 x 0.1 to +1.1e-16), so an exact comparison lets
	-- rounding, not the data, decide whether the tick that exactly consumes
	-- the cooldown fires. A tick that lands on the boundary must fire. Far
	-- below the smallest real interval in the data (0.02 s) and far above
	-- double-precision noise at these magnitudes.
	cooldownEpsilon = 1e-9, -- NOT from research. Cooldown boundary tolerance (seconds)

	-- ---------------------------------------------------------------- client
	-- NOT from research. Everything below is presentation: camera framing, HUD
	-- geometry and placeholder visual-effect sizes. The reference is a 2D
	-- pixel-art game with no notion of studs, Roblox GUI units or field of
	-- view, so none of these can come from research/vs. They are look-and-feel
	-- tunables and carry no balance meaning. Colours are stored as r/g/b
	-- components in [0, 1] rather than Color3 so this module stays pure Luau
	-- and keeps loading under the plain luau CLI.

	-- Fraction used for centring anchor points and midpoints in client layout.
	-- A unit constant, not a tunable; it lives here only because a bare 0.5
	-- literal is not permitted outside Data/Tuning.
	uiHalf = 0.5, -- NOT from research. Centre fraction for UI anchors

	-- Seconds in a minute, for formatting the run clock as mm:ss and for the
	-- one-Reaper-per-further-minute cadence the research states in
	-- research/vs/core_loop.md ("At 1800 s a Reaper spawns, +1 each further
	-- minute"). A unit conversion, not a balance value.
	secondsPerMinute = 60, -- research/vs/core_loop.md §1 (run structure)

	camera = {
		-- NOT from research. Top-down locked follow: the camera sits this many
		-- studs above the player and this many studs back along +Z, looking at
		-- the player. Height dominates so the view reads as top-down while the
		-- small setback keeps the character sprite readable.
		height = 90, -- NOT from research. Camera height above the player (studs)
		backDistance = 30, -- NOT from research. Camera setback along +Z (studs)
		fieldOfView = 55, -- NOT from research. Camera FOV (degrees)
		-- NOT from research. Exponential follow rate (1/s). The camera closes
		-- this fraction of the remaining gap per second, so it trails the player
		-- slightly instead of snapping. Higher = stiffer.
		followRate = 12,
	},

	hud = {
		-- NOT from research. Push rate the client assumes for HudState; the
		-- run timer is interpolated between pushes so it ticks smoothly.
		updateInterval = 0.2, -- NOT from research. Seconds between HUD refreshes
		margin = 12, -- NOT from research. Screen-edge margin (pixels)
		padding = 8, -- NOT from research. Inner padding (pixels)
		cornerRadius = 6, -- NOT from research. Rounded-corner radius (pixels)
		textSize = 18, -- NOT from research. Body text size (pixels)
		titleTextSize = 28, -- NOT from research. Run-timer text size (pixels)
		barWidth = 420, -- NOT from research. XP / health bar width (pixels)
		xpBarHeight = 14, -- NOT from research. XP bar height (pixels)
		healthBarHeight = 18, -- NOT from research. Health bar height (pixels)
		statRowHeight = 24, -- NOT from research. Height of one stat line (pixels)
		slotSize = 44, -- NOT from research. Weapon / passive slot edge (pixels)
		slotGap = 6, -- NOT from research. Gap between slots (pixels)
		-- research/vs/core_loop.md: 6 weapon + 6 passive slots. The HUD draws one
		-- box per slot, so the row length is that research value, not a tunable.
		-- Read from Data.CoreLoop at runtime; this is only the fallback used if
		-- the field is UNKNOWN there.
		slotCountFallback = 6, -- research/vs/core_loop.md (6 weapon + 6 passive slots)
		backgroundTransparency = 0.35, -- NOT from research. Panel transparency
		barBackgroundTransparency = 0.5, -- NOT from research. Bar trough transparency
		-- NOT from research. Health fraction below which the health bar turns to
		-- the low colour. Purely a readability cue; no mechanic reads it.
		lowHealthFraction = 0.3,
		colors = {
			panel = { r = 0.06, g = 0.07, b = 0.1 }, -- NOT from research
			text = { r = 0.93, g = 0.95, b = 1 }, -- NOT from research
			dimText = { r = 0.6, g = 0.64, b = 0.72 }, -- NOT from research
			xp = { r = 0.35, g = 0.72, b = 1 }, -- NOT from research
			health = { r = 0.35, g = 0.82, b = 0.45 }, -- NOT from research
			lowHealth = { r = 0.9, g = 0.35, b = 0.32 }, -- NOT from research
			slotEmpty = { r = 0.13, g = 0.14, b = 0.18 }, -- NOT from research
			slotWeapon = { r = 0.62, g = 0.45, b = 0.85 }, -- NOT from research
			slotPassive = { r = 0.85, g = 0.68, b = 0.35 }, -- NOT from research
		},
	},

	levelUpUi = {
		backdropTransparency = 0.4, -- NOT from research. Dim behind the panel
		panelWidth = 520, -- NOT from research. Panel width (pixels)
		panelPadding = 16, -- NOT from research. Panel inner padding (pixels)
		cornerRadius = 8, -- NOT from research. Rounded-corner radius (pixels)
		titleHeight = 40, -- NOT from research. Title row height (pixels)
		titleTextSize = 26, -- NOT from research. Title text size (pixels)
		optionHeight = 64, -- NOT from research. One option button height (pixels)
		optionGap = 8, -- NOT from research. Gap between options (pixels)
		optionTextSize = 20, -- NOT from research. Option name text size (pixels)
		optionSubTextSize = 15, -- NOT from research. Option detail text size (pixels)
		buttonHeight = 34, -- NOT from research. Reroll / skip / banish button height
		buttonGap = 8, -- NOT from research. Gap between those buttons (pixels)
		buttonTextSize = 16, -- NOT from research. Button text size (pixels)
		-- NOT from research. The footer holds exactly the three research-defined
		-- level-up actions (core_loop.md: Reroll / Skip / Banish), so the button
		-- row is divided three ways. A layout divisor, not a balance number.
		footerButtonCount = 3,
		colors = {
			backdrop = { r = 0, g = 0, b = 0 }, -- NOT from research
			panel = { r = 0.09, g = 0.1, b = 0.14 }, -- NOT from research
			option = { r = 0.16, g = 0.17, b = 0.23 }, -- NOT from research
			optionNew = { r = 0.2, g = 0.28, b = 0.2 }, -- NOT from research
			button = { r = 0.22, g = 0.23, b = 0.3 }, -- NOT from research
			buttonDisabled = { r = 0.14, g = 0.14, b = 0.17 }, -- NOT from research
			text = { r = 0.95, g = 0.96, b = 1 }, -- NOT from research
			dimText = { r = 0.62, g = 0.65, b = 0.72 }, -- NOT from research
			banishArmed = { r = 0.75, g = 0.3, b = 0.3 }, -- NOT from research
		},
	},

	visuals = {
		-- NOT from research. Pool size for transient effect parts on the client.
		-- Effects are short-lived; this bounds the worst-case simultaneous count
		-- so the client never calls Instance.new inside the render loop.
		poolSize = 256,
		hiddenY = -500, -- NOT from research. Parking height for unused effect parts
		groundY = 0.2, -- NOT from research. Height of ground-flat effects (studs)
		-- NOT from research. Default lifetime (seconds) for an effect whose spec
		-- carries no duration. Long enough to read, short enough not to stack up.
		defaultDuration = 0.25,
		slashThickness = 3, -- NOT from research. Whip slash arc thickness (studs)
		slashHeight = 3, -- NOT from research. Whip slash arc height (studs)
		auraThickness = 0.4, -- NOT from research. Garlic aura ring thickness (studs)
		zoneThickness = 0.3, -- NOT from research. Santa Water zone disc thickness (studs)
		dropRadius = 0.6, -- NOT from research. Santa Water falling-bottle radius (studs)
		dropHeight = 24, -- NOT from research. Height a bottle drops from (studs)
		strikeRadius = 1.2, -- NOT from research. Lightning bolt column radius (studs)
		strikeHeight = 40, -- NOT from research. Lightning bolt column height (studs)
		startTransparency = 0.25, -- NOT from research. Effect transparency at spawn
		colors = {
			slash = { r = 0.95, g = 0.9, b = 0.55 }, -- NOT from research
			aura = { r = 0.55, g = 0.95, b = 0.6 }, -- NOT from research
			zone = { r = 0.5, g = 0.8, b = 1 }, -- NOT from research
			drop = { r = 0.7, g = 0.9, b = 1 }, -- NOT from research
			strike = { r = 0.85, g = 0.85, b = 1 }, -- NOT from research
		},
	},

	-- NOT from research. Presentation-only constants for the on-screen
	-- diagnostics overlay (src/server/Diagnostics.server.luau). They describe a
	-- debug label's size and colours, nothing in the simulation.
	diagnostics = {
		waitTimeout = 10, -- NOT from research. Seconds to wait for Instances on join
		widthInset = -40, -- NOT from research. Label width inset from screen edge (px)
		offsetX = 20, -- NOT from research. Label offset from left edge (px)
		offsetY = 60, -- NOT from research. Label offset below top inset (px)
		backgroundTransparency = 0.15, -- NOT from research
		textSize = 22, -- NOT from research. Label text size (px)
		paddingY = 14, -- NOT from research. Label vertical padding (px)
		paddingX = 16, -- NOT from research. Label horizontal padding (px)
		colors = {
			ok = { r = 20, g = 60, b = 30 }, -- NOT from research (0-255)
			fail = { r = 80, g = 25, b = 25 }, -- NOT from research (0-255)
			text = { r = 255, g = 255, b = 255 }, -- NOT from research (0-255)
		},
	},
}

return Tuning
