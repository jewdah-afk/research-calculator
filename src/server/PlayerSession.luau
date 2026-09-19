--!strict
--[[
	server/PlayerSession.luau -- the player's own state for one run: health,
	recovery, armor, the invulnerability window, revivals, XP and the
	level-up queue.

	Everything here is a research rule, so none of it is Humanoid.Health.
	docs/ARCHITECTURE.md, Player: "Health is simulated by PlayerSession, not
	Humanoid.Health (armor, recovery, i-frames and revival are all research
	rules)." The Humanoid only carries WalkSpeed, which walkSpeed() derives.

	Oracle:
	  * Armor. research/vs/passives_evolutions.md §1, Armor: "Reduces
	    incoming Damage by 1" per point -- applied by Sim/Damage.toPlayer,
	    which also owns the floor when armor exceeds the hit (OQ-10).
	  * Recovery. passives_evolutions.md §1, Pummarola: "Character recovers
	    0.2 HP per second", and pickups_meta.md §5, Recovery: "Recovers 0.1
	    HP per rank per second". So stats.recovery is flat HP PER SECOND and
	    accrues continuously, clamped at maxHealth. Nothing in the research
	    ties it to a tick, so it is scaled by dt rather than granted whole.
	  * Revival. pickups_meta.md §5, Revival: "Revives once with 50% health."
	    stats.revival is the count; each death spends one and restores
	    Tuning.revivalHealthFraction of maxHealth. Out of revivals, the run
	    ends. core_loop.md §1 also pays "+100 Gold per unused Revival" at the
	    end of a run; that is end-of-run scoring, not this module.
	  * XP and level-ups. Sim/Experience.addXp carries overflow across as
	    many levels as the gem buys and returns how many; each one queues an
	    offer, and core_loop.md §2 "Game pauses on level up" is why the queue
	    exists at all -- the loop stays paused until it drains.

	  RESEARCH GAP, not guessed: the invulnerability window. The research
	  states contact `power` (enemies_waves.md §2) and says nothing at all
	  about how often a touching enemy lands it, while server/EnemyManager
	  reports a contact every step for every enemy in reach. Without a window
	  one enemy would deal power x 60 per second. Tuning.invulnerabilitySeconds
	  is therefore ours and flagged; damage() returns false while it runs, so
	  the caller can tell an absorbed touch from a landed one.

	Pure Luau by construction: no Roblox APIs, no yields, no Instances. It
	lives under src/server because it is server-authoritative state, not
	because it needs the engine -- which is also what makes it testable.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require. The aliases below restate
	Types.PlayerState / StatBlock / LevelUpOption structurally; keep them in
	step with Types.luau.
]]

local Tuning = require("../shared/Tuning")
local CoreLoop = require("../shared/Data/CoreLoop")
local Stats = require("../shared/Sim/Stats")
local Damage = require("../shared/Sim/Damage")
local Experience = require("../shared/Sim/Experience")
local LevelUp = require("../shared/Sim/LevelUp")

export type StatBlock = Stats.StatBlock
export type PlayerState = LevelUp.PlayerState
export type LevelUpOption = LevelUp.LevelUpOption
export type LevelUpOffer = LevelUp.LevelUpOffer

-- Mirrors Types.Rng.
export type Rng = {
	next: (self: Rng) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
}

export type PlayerSession = {
	state: PlayerState,
	-- Seconds of invulnerability left; 0 means a touch lands.
	invulnerable: number,
	-- Level-up offers owed to the player. The loop stays paused until 0.
	pendingLevelUps: number,
	-- True once a death could not be revived. The run is over.
	finished: boolean,

	-- Hooks, settable at any time. None fire during new().
	onDamage: ((amount: number, health: number) -> ())?,
	onLevelUp: ((level: number) -> ())?,
	onRevive: ((revivalsUsed: number, health: number) -> ())?,
	onFinish: ((time: number) -> ())?,
	-- The StatBlock changed (level-up, chest, passive). The caller re-syncs
	-- WeaponRunner and the Humanoid's WalkSpeed.
	onStatsChanged: ((stats: StatBlock) -> ())?,

	-- Recovery and the invulnerability window. Not called while paused.
	step: (self: PlayerSession, dt: number) -> (),
	-- Contact damage from an enemy of `power`. Returns true if it landed
	-- (false while invulnerable, or once the run has finished).
	damage: (self: PlayerSession, power: number, time: number) -> boolean,
	-- Banks collected XP; returns the levels gained, already queued.
	addXp: (self: PlayerSession, amount: number) -> number,
	-- The next offer, or nil when nothing is pending or nothing is left to
	-- give. Does NOT consume the pending count -- applyOption does.
	nextOffer: (self: PlayerSession, rng: Rng) -> LevelUpOffer?,
	-- Applies a chosen option and consumes one pending level-up.
	applyOption: (self: PlayerSession, option: LevelUpOption) -> (),
	-- Consumes one pending level-up without granting an item (skip, or
	-- nothing left to offer).
	dropPending: (self: PlayerSession) -> (),
	-- Re-derives the StatBlock from character, level and passives, clamps
	-- health and fires onStatsChanged.
	refreshStats: (self: PlayerSession) -> (),
	-- Humanoid.WalkSpeed for the current stats (studs/s).
	walkSpeed: (self: PlayerSession) -> number,
	-- Pickup radius in studs for server/PickupManager.
	magnetRadius: (self: PlayerSession) -> number,
}

type Internal = PlayerSession & {}

local PlayerSession = {}
PlayerSession.__index = PlayerSession

-- core_loop.md §4: "Base Magnet 30 (world units -- radius in which gems and
-- pickups are collected)". Tuning.magnetScale converts world units to studs.
local MAGNET_BASE = CoreLoop.data.magnet.base :: number

function PlayerSession.new(characterId: string, rng: Rng): PlayerSession
	local stats = Stats.effective(characterId, 1, {})
	local state: PlayerState = {
		characterId = characterId,
		level = 1,
		xp = 0,
		xpToNext = Experience.xpToNext(1),
		health = stats.maxHealth,
		stats = stats,
		weapons = {},
		weaponOrder = {},
		passives = {},
		passiveOrder = {},
		gold = 0,
		kills = 0,
		revivalsUsed = 0,
		rerolls = 0,
		skips = 0,
		banishes = 0,
		banished = {},
	}
	local self: Internal = {
		state = state,
		invulnerable = 0,
		pendingLevelUps = 0,
		finished = false,
		onDamage = nil,
		onLevelUp = nil,
		onRevive = nil,
		onFinish = nil,
		onStatsChanged = nil,
		step = PlayerSession.step,
		damage = PlayerSession.damage,
		addXp = PlayerSession.addXp,
		nextOffer = PlayerSession.nextOffer,
		applyOption = PlayerSession.applyOption,
		dropPending = PlayerSession.dropPending,
		refreshStats = PlayerSession.refreshStats,
		walkSpeed = PlayerSession.walkSpeed,
		magnetRadius = PlayerSession.magnetRadius,
	} :: any
	local session = (setmetatable(self, PlayerSession) :: any) :: PlayerSession
	-- rng is not held: offers take theirs from the caller so one stream
	-- drives the whole run (Sim is deterministic, AC-X02).
	return session
end

function PlayerSession.refreshStats(self: PlayerSession)
	local state = self.state
	local stats = Stats.effective(state.characterId, state.level, state.passives)
	state.stats = stats
	-- A raised maxHealth does not heal: the research states no such rule,
	-- so only the clamp is applied when it FALLS.
	if state.health > stats.maxHealth then
		state.health = stats.maxHealth
	end
	local hook = self.onStatsChanged
	if hook ~= nil then
		hook(stats)
	end
end

function PlayerSession.walkSpeed(self: PlayerSession): number
	return self.state.stats.moveSpeed * Tuning.baseWalkSpeed
end

function PlayerSession.magnetRadius(self: PlayerSession): number
	-- characters.md Conventions: "magnet is an additive fractional bonus
	-- (0 = unmodified, 0.25 = +25% pickup radius)". core_loop.md §4 calls
	-- the stacking multiplicative; the SHIPPED convention is authoritative
	-- over the wiki wording (SUMMARY.md conflict policy), and Sim/Stats
	-- already sums the fractions, so the bonus is applied as 1 + magnet.
	return MAGNET_BASE * (1 + self.state.stats.magnet) * Tuning.magnetScale
end

function PlayerSession.step(self: PlayerSession, dt: number)
	if self.finished then
		return
	end
	if self.invulnerable > 0 then
		self.invulnerable -= dt
		if self.invulnerable < 0 then
			self.invulnerable = 0
		end
	end
	local state = self.state
	local recovery = state.stats.recovery
	if recovery > 0 and state.health < state.stats.maxHealth then
		local healed = state.health + recovery * dt
		state.health = math.min(healed, state.stats.maxHealth)
	end
end

function PlayerSession.damage(self: PlayerSession, power: number, time: number): boolean
	if self.finished or self.invulnerable > 0 then
		return false
	end
	local state = self.state
	local amount = Damage.toPlayer(power, state.stats.armor)
	self.invulnerable = Tuning.invulnerabilitySeconds
	if amount <= 0 then
		-- Fully absorbed (Tuning.contactDamageFloor). The window still runs:
		-- the touch happened, it simply did nothing.
		return false
	end
	state.health -= amount
	local hook = self.onDamage
	if hook ~= nil then
		hook(amount, state.health)
	end
	if state.health > 0 then
		return true
	end
	-- pickups_meta.md §5: a revival restores half the player's max health.
	if state.revivalsUsed < state.stats.revival then
		state.revivalsUsed += 1
		state.health = state.stats.maxHealth * Tuning.revivalHealthFraction
		local revived = self.onRevive
		if revived ~= nil then
			revived(state.revivalsUsed, state.health)
		end
		return true
	end
	state.health = 0
	self.finished = true
	local finish = self.onFinish
	if finish ~= nil then
		finish(time)
	end
	return true
end

function PlayerSession.addXp(self: PlayerSession, amount: number): number
	local state = self.state
	local gained = Experience.addXp(state, amount)
	if gained > 0 then
		self.pendingLevelUps += gained
		-- The level itself raises the stat line (characters.md levelBonuses)
		-- before any option is chosen.
		self:refreshStats()
		local hook = self.onLevelUp
		if hook ~= nil then
			hook(state.level)
		end
	end
	return gained
end

function PlayerSession.nextOffer(self: PlayerSession, rng: Rng): LevelUpOffer?
	if self.pendingLevelUps <= 0 or not LevelUp.canOffer(self.state) then
		return nil
	end
	return LevelUp.offer(self.state, rng)
end

function PlayerSession.dropPending(self: PlayerSession)
	if self.pendingLevelUps > 0 then
		self.pendingLevelUps -= 1
	end
end

function PlayerSession.applyOption(self: PlayerSession, option: LevelUpOption)
	LevelUp.apply(self.state, option)
	self:dropPending()
	self:refreshStats()
end

return PlayerSession
