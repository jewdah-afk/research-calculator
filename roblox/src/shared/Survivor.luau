--!strict
-- Survivor: the Birb expedition (Parrot combat) rules, pulled out for a quick roguelike.
-- Source: birbplay.com bundles pulled 2026-10-13 (game-F2YVtiJe.js, main-DBqk1gka.js,
-- editors-Bk1jOShp.js, maps-DNqux_gr.js). Original names are in the comments.
-- Pure logic, no Roblox APIs. Distances are Birb pixels; multiply by PX_TO_STUDS for Roblox.
-- See SURVIVOR.md for what is 1:1 and what is a roguelike adaptation.

local BirbSystems = require(script.Parent.BirbSystems)

local S = {}

S.PX_TO_STUDS = 1 / 10 -- tuning knob for the Roblox port, not from Birb

--------------------------------------------------------------------------- Constants (1:1)
S.C = {
	COMBAT_FEEL_SPEED_MULT = 2, -- LI: parrot sim runs at dt*2
	PARROT_BASE_HP = 100, -- Zd
	PARROT_BASE_DAMAGE = 100, -- $d
	PARROT_BASE_SPEED = 90, -- run parrot `speed`
	PARROT_CHASE_SPEED_MULT = 1.1, -- attack/return movement uses 1.1*speed
	PLAYER_SPEED = 150,
	PLAYER_PICKUP_RADIUS = 30,
	LEASH_RADIUS = 450, -- WA: parrot fights only inside this circle around the player
	TARGET_ACQUIRE_INSET = 12,
	ATTACK_FRAME_SECONDS = 0.1, -- per frame, divided by attack speed; hit lands on frame 2 of 4
	ATTACK_WAIT_SECONDS = 0.6, -- pause after the 4-frame swing, divided by attack speed
	MIN_ATTACK_SPEED = 0.2,
	MIN_MOVE_SPEED = 0.25,
	NON_BOSS_HIT_STUN = 0.3, -- generic enemies stunned 0.3s per hit (bosses and scripted enemies 0)
	CONTACT_RADIUS = 25, -- generic enemy body hit, 625 = 25^2
	CONTACT_DAMAGE_RATIO = 0.5, -- contact damage = 0.5 * attack
	CONTACT_HIT_COOLDOWN = 2,
	PARROT_HURT_STUN = 0.3, -- only when not attacking
	COMBAT_REGEN_PENALTY_SECONDS = 3, -- after taking a hit
	COMBAT_REGEN_PENALTY = 0.75, -- regen x(1 - 0.75*(1 - relief)) during the penalty
	POTION_KILL_DROP_CHANCE = 0.02,
	ARTIFACT_DROP_CHANCE = 0.06, -- oa (checkArtifactDrop; unused in live Birb, see SURVIVOR.md)
	RUN_ARTIFACT_CAP = 5,
	ELITE = { health = 5.5, attack = 1.42, speed = 1.14, xp = 9.5, skillPoints = 4.5 },
	SHINY = { health = 1.2, skillPoints = 10 },
	BOSS_RESPAWN = 480,
	ELITE_RESPAWN = 300,
	ENEMY_MIN_SEPARATION = 28,
	-- artifact procs
	SPLITTER_HASTE_DURATION = 3, SPLITTER_HASTE_BONUS = 0.3, -- every 5th hit
	HUNTER_MOMENTUM_DURATION = 3, HUNTER_MOMENTUM_ATK = 0.2, HUNTER_MOMENTUM_MOVE = 0.2, -- on kill
}

-- Ca (main bundle)
S.FX = {
	effectCopyCap = 2,
	statInfusionBonusPerLevel = 0.12,
	effectInfusionBonusPerLevel = 0.04,
	combatRegenPenaltyReductionPerPower = 0.2,
	redlineStartHealthRatio = 0.7, redlineFullPowerHealthRatio = 0.2,
	redlinePrimaryBonus = 0.24, redlineSecondaryBonus = 0.12,
	openingStrikeHealthRatio = 0.85, openingStrikePrimaryBonus = 0.45, openingStrikeSecondaryBonus = 0.225,
	focusBonusPerHit = 0.04, focusMaxHits = 7, focusWindowSeconds = 2.5,
	recoveryStartHealthRatio = 0.6, recoveryFullPowerHealthRatio = 0.2,
	recoveryPrimaryBonus = 0.5, recoverySecondaryBonus = 0.25,
	stormHitInterval = 6, stormPrimaryDamageRatio = 0.9, stormSecondaryDamageRatio = 0.1,
	stormPrimaryTargets = 2, stormRadius = 110,
	pointHoardTripleMult = 3, -- Ta
}

S.RARITY_WEIGHTS = { common = 55, uncommon = 25, rare = 12, epic = 6, legendary = 2 } -- sa
S.RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary" }

local function clamp(x: number, lo: number, hi: number) return math.max(lo, math.min(hi, x)) end

--------------------------------------------------------------------------- Effect power
-- Power = {copies, primaryPower, secondaryPower}. Only the best 2 copies count.
export type Power = { copies: number, primaryPower: number, secondaryPower: number }
S.NO_POWER = { copies = 0, primaryPower = 0, secondaryPower = 0 } :: Power

function S.statInfusionMult(level: number) return 1 + S.FX.statInfusionBonusPerLevel * math.max(0, math.floor(level)) end -- Na
function S.effectInfusionMult(level: number) return 1 + S.FX.effectInfusionBonusPerLevel * math.max(0, math.floor(level)) end -- Ba

-- powers: list of per-copy powers (1 for a run pickup, effectInfusionMult(lvl) for an equipped one)
function S.power(powers: { number }): Power
	local p = table.clone(powers)
	table.sort(p, function(a, b) return a > b end)
	local n = math.min(#p, S.FX.effectCopyCap)
	return { copies = n, primaryPower = if n >= 1 then p[1] else 0, secondaryPower = if n >= 2 then p[2] else 0 }
end

--------------------------------------------------------------------------- Parrot stats (tb)
-- Every *Mult is additive inside its group ("+0.18" = +18%), then groups multiply.
export type StatInput = {
	skill: { hp: number, damage: number, regen: number }?,
	artifactAdd: { hp: number, regen: number }?,
	equipment: { armor: number, beak: number, aura: number }?,
	artifact: { hp: number, damage: number, regen: number, attackSpeed: number, moveSpeed: number }?,
	progression: { hp: number, damage: number, regen: number, attackSpeed: number, moveSpeed: number }?,
	external: { hp: number, damage: number, regen: number, attackSpeed: number, moveSpeed: number }?,
	final: { hp: number, damage: number, regen: number }?,
}
local Z0 = { hp = 0, damage = 0, regen = 0, attackSpeed = 0, moveSpeed = 0 }
function S.parrotStats(i: StatInput)
	local sk = i.skill or Z0 :: any
	local aa = i.artifactAdd or Z0 :: any
	local eq = i.equipment or { armor = 1, beak = 1, aura = 1 }
	local ar, pr, ex = (i.artifact or Z0) :: any, (i.progression or Z0) :: any, (i.external or Z0) :: any
	local fi = i.final or { hp = 1, damage = 1, regen = 1 }
	local function g(k) return math.max(0, 1 + ar[k]) * math.max(0, 1 + pr[k]) * math.max(0, 1 + ex[k]) end
	return {
		maxHealth = (S.C.PARROT_BASE_HP + sk.hp + aa.hp) * eq.armor * g("hp") * fi.hp,
		damage = (S.C.PARROT_BASE_DAMAGE + sk.damage) * eq.beak * g("damage") * fi.damage,
		lifeRegen = (sk.regen + aa.regen) * eq.aura * g("regen") * fi.regen,
		attackSpeed = g("attackSpeed"),
		moveSpeed = g("moveSpeed"),
	}
end

-- calculateParrotBonuses: sum artifact stat lines. Run pickups scale by the floor
-- multiplier; equipped (persistent) ones scale by statInfusionMult.
export type Artifact = { name: string?, effectId: string?, stats: { [string]: number }?, rarity: string? }
function S.floorScale(floor: number) return 1 + 0.08 * math.max(0, floor - 1) ^ 0.6 end

function S.artifactBonuses(runArtifacts: { Artifact }, floor: number, enemiesDefeated: number)
	local b = { damage = 0, hp = 0, hpAdd = 0, regenAdd = 0, regen = 0, attackSpeed = 0, moveSpeed = 0 }
	local fs = S.floorScale(floor)
	local function count(id) local n = 0 for _, a in runArtifacts do if a.effectId == id then n += 1 end end return n end
	for _, a in runArtifacts do
		local t = a.stats
		if t then
			b.damage += (t.damage or 0) * fs
			b.hp += (t.maxHealth or 0) * fs
			b.hpAdd += (t.maxHealthAdd or 0) * fs
			b.regenAdd += (t.lifeRegen or 0) * fs
			b.regen += (t.lifeRegenMult or 0) * fs
			b.attackSpeed += (t.attackSpeed or 0) * fs
			b.moveSpeed += (t.moveSpeed or 0) * fs
		end
	end
	local pf = count("scale_per_floor")
	if pf > 0 then
		local e = (0.08 + (if pf >= 2 then 0.04 else 0)) * math.max(0, floor - 1)
		b.damage += e; b.hp += e
	end
	local pk = count("scale_per_kill")
	if pk > 0 then b.damage += 0.006 * math.floor(math.max(0, enemiesDefeated) / 100) * pk end
	local pa = count("scale_per_artifact")
	if pa > 0 then b.damage += math.max(0, #runArtifacts - pa) * (0.08 + (if pa >= 2 then 0.04 else 0)) end
	return b
end

function S.damageTakenMult(runArtifacts: { Artifact })
	local m = 1
	for _, a in runArtifacts do if a.effectId == "dmg_reduce_5" then m *= 0.95 end end
	return m
end

--------------------------------------------------------------------------- Conditional effects
local function hpRatio(h: number, maxH: number, fallback: number)
	if maxH <= 0 then return fallback end
	return clamp(h / maxH, 0, 1)
end

-- Ka: per-hit damage multiplier (Blood Beak, Predator Instinct, Relentless Hunter)
function S.hitDamageMult(a: {
	health: number, maxHealth: number, targetHealth: number, targetMaxHealth: number,
	isOpeningStrike: boolean, focusHits: number, redline: Power, openingStrike: Power, focus: Power,
}): number
	local F = S.FX
	local red = 1
	if a.redline.copies > 0 then
		local r = clamp((F.redlineStartHealthRatio - hpRatio(a.health, a.maxHealth, 1))
			/ (F.redlineStartHealthRatio - F.redlineFullPowerHealthRatio), 0, 1)
		red = 1 + (F.redlinePrimaryBonus * a.redline.primaryPower + F.redlineSecondaryBonus * a.redline.secondaryPower) * r
	end
	local open = 1
	if a.isOpeningStrike and a.openingStrike.copies > 0
		and hpRatio(a.targetHealth, a.targetMaxHealth, 0) >= F.openingStrikeHealthRatio then
		open = 1 + F.openingStrikePrimaryBonus * a.openingStrike.primaryPower + F.openingStrikeSecondaryBonus * a.openingStrike.secondaryPower
	end
	local foc = 1
	if a.focus.copies > 0 then
		local n = clamp(math.floor(a.focusHits), 0, F.focusMaxHits)
		foc = 1 + n * F.focusBonusPerHit * (a.focus.primaryPower + 0.5 * a.focus.secondaryPower)
	end
	return math.max(1, red * open * foc)
end

-- Wa: regen multiplier from Echo Shell / Watcher's Oath
function S.recoveryRegenMult(health: number, maxHealth: number, p: Power): number
	if p.copies <= 0 then return 1 end
	local F = S.FX
	local r = clamp((F.recoveryStartHealthRatio - hpRatio(health, maxHealth, 1))
		/ (F.recoveryStartHealthRatio - F.recoveryFullPowerHealthRatio), 0, 1)
	return 1 + (F.recoveryPrimaryBonus * p.primaryPower + F.recoverySecondaryBonus * p.secondaryPower) * r
end

-- Da: Storm Locket. Every 6th parrot hit chains to nearby enemies.
function S.stormChain(hitCounter: number, p: Power)
	local F = S.FX
	if not (p.copies > 0 and hitCounter > 0 and hitCounter % F.stormHitInterval == 0) then
		return { active = false, damageRatio = 0, maxTargets = 0, radius = F.stormRadius }
	end
	local r = F.stormPrimaryDamageRatio * p.primaryPower + F.stormSecondaryDamageRatio * p.secondaryPower
	return { active = true, damageRatio = math.round(r * 1e6) / 1e6, maxTargets = F.stormPrimaryTargets + (p.copies - 1), radius = F.stormRadius }
end

-- za: Divine Symbol
function S.regenRelief(p: Power) return clamp(S.FX.combatRegenPenaltyReductionPerPower * (p.primaryPower + p.secondaryPower), 0, 1) end

-- Point Hoard (sp_triple_jackpot): chance per kill to x3 skill points + short buff
function S.pointHoardChance(copies: number) return if copies >= 2 then 0.15 elseif copies == 1 then 0.1 else 0 end -- Ea
function S.pointHoardBuff(copies: number)
	local t = clamp(math.floor(copies), 0, 2)
	if t <= 0 then return { attackSpeed = 0, range = 0, duration = 0 } end
	return { attackSpeed = 0.1 * t, range = 0.05 * t, duration = if t >= 2 then 5 else 3 }
end

function S.skillPointMult(runArtifacts: { Artifact })
	local add = { sp_gain_10 = 0.1, xp_gain_2 = 0.1, sp_gain_15 = 0.15, sp_gain_20 = 0.2, sp_gain_25 = 0.25, sp_gain_30 = 0.3 }
	local m = 1
	for _, a in runArtifacts do m += add[a.effectId or ""] or 0 end
	return m
end

S.POTION_HEAL = { heal_20_pct = 0.2, heal_35_pct = 0.35, heal_60_pct = 0.5, instant_heal_25 = 0.35, instant_heal_50 = 0.5, instant_heal_full = 1 } -- YT

--------------------------------------------------------------------------- Attack timing
-- One parrot swing cycle in real seconds (frames + wait, sim at dt*2).
function S.attackCycleSeconds(attackSpeed: number)
	local m = math.max(S.C.MIN_ATTACK_SPEED, attackSpeed)
	return (4 * S.C.ATTACK_FRAME_SECONDS + S.C.ATTACK_WAIT_SECONDS) / m / S.C.COMBAT_FEEL_SPEED_MULT
end

--------------------------------------------------------------------------- Enemies
S.enemyStats = BirbSystems.enemyStats -- 1:1, see SYSTEMS.md

function S.applyVariant(st, isElite: boolean, isShiny: boolean)
	local E, H = S.C.ELITE, S.C.SHINY
	local o = table.clone(st)
	if isElite then
		o.health *= E.health; o.attack *= E.attack; o.speed *= E.speed
		o.xpBase *= E.xp; o.skillPointReward *= E.skillPoints
	end
	if isShiny then o.health *= H.health; o.skillPointReward *= H.skillPoints end
	return o
end

-- Night mode treats floor F as 9 + F (Yt)
function S.effectiveFloor(floor: number, night: boolean) return if night then 9 + floor else floor end

--------------------------------------------------------------------------- Drops
function S.rollRarity(floor: number, rng: Random): string
	local top = if floor <= 1 then 1 elseif floor == 2 then 2 else 5
	local total = 0
	for i = 1, top do total += S.RARITY_WEIGHTS[S.RARITY_ORDER[i]] end
	local x = rng:NextNumber() * math.max(1, total)
	for i = 1, top do
		local r = S.RARITY_ORDER[i]
		x -= S.RARITY_WEIGHTS[r]
		if x <= 0 then return r end
	end
	return "common"
end

-- pool: artifacts.json rows; returns nil when no drop
function S.rollArtifactDrop(pool: { Artifact }, floor: number, rng: Random): Artifact?
	if rng:NextNumber() > S.C.ARTIFACT_DROP_CHANCE then return nil end
	local r = S.rollRarity(floor, rng)
	local opts = {}
	for _, a in pool :: { any } do
		if a.rarity == r and a.dropSource ~= "mythic-sacrifice" and a.inventoryCategory ~= "material"
			and a.type ~= "consumable" and a.name then
			table.insert(opts, a)
		end
	end
	if #opts == 0 then return nil end
	return opts[rng:NextInteger(1, #opts)]
end

-- XP: skill points earned also feed parrot XP 1:1 (awardProgressFromSkillPoints).
S.xpToNext = BirbSystems.parrotXpNeeded

return S
