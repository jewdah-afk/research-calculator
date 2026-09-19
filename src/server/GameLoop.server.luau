--!strict
--[[
	server/GameLoop.server.luau -- the Heartbeat that makes the run happen.

	One Run per player: its own EnemyManager, WeaponRunner, Spawner,
	PickupManager, PlayerSession, presenters and Rng stream. Nothing is
	shared between players, so two runs never interfere and each is
	reproducible from its own seed.

	Order inside one step, straight from docs/ARCHITECTURE.md "Data flow":

	    if paused: return                  -- the run clock STOPS on level-up
	    time += dt
	    Spawner.step        -> waves, events, bosses, the 1800 s Reaper
	    EnemyManager.step   -> movement, knockback decay, contact, deaths
	    WeaponRunner.step   -> every WeaponBehavior, every projectile
	    PickupManager.step  -> magnet pull, collection -> XP -> level-ups
	    PlayerSession.step  -> recovery, the invulnerability window
	    if pending level-ups: pause and send the offer
	    presenters flush (BulkMoveTo); HUD at ~5 Hz

	Pausing is the whole level-up rule (core_loop.md §2, "Game pauses on
	level up") and it is enforced in ONE place: the early return below. While
	paused nothing advances -- not the clock, not a wave, not a cooldown, not
	an enemy -- because none of the steppers are reached.

	This is the only file in the row that touches the engine. Everything it
	calls is pure or pool-based, which is why the mechanics are testable
	without Roblox and why 2048+ enemies stay affordable: the simulation is
	numbers in parallel arrays and the presenters push them out with one
	workspace:BulkMoveTo per flush.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require("../shared/Tuning")
local Net = require("../shared/Net")
local Rng = require("../shared/Sim/Rng")
local Chests = require("../shared/Sim/Chests")
local Waves = require("../shared/Sim/Waves")
local LevelUp = require("../shared/Sim/LevelUp")
local Characters = require("../shared/Data/Characters")

local EnemyManager = require("./EnemyManager")
local EnemyPresenter = require("./EnemyPresenter")
local ProjectilePool = require("./ProjectilePool")
local WeaponRunner = require("./WeaponRunner")
local Spawner = require("./Spawner")
local PickupManager = require("./PickupManager")
local PlayerSession = require("./PlayerSession")

local Axe = require("./Weapons/Axe")
local Cross = require("./Weapons/Cross")
local FireWand = require("./Weapons/FireWand")
local Garlic = require("./Weapons/Garlic")
local KingBible = require("./Weapons/KingBible")
local Knife = require("./Weapons/Knife")
local LightningRing = require("./Weapons/LightningRing")
local MagicWand = require("./Weapons/MagicWand")
local Runetracer = require("./Weapons/Runetracer")
local SantaWater = require("./Weapons/SantaWater")
local Whip = require("./Weapons/Whip")

local BEHAVIOURS = {
	Axe,
	Cross,
	FireWand,
	Garlic,
	KingBible,
	Knife,
	LightningRing,
	MagicWand,
	Runetracer,
	SantaWater,
	Whip,
}

-- The character every run starts as until a select screen exists. Its
-- startingWeaponId comes from Data, never from here.
local DEFAULT_CHARACTER = "antonio"

local net = Net.server()

type Run = {
	player: Player,
	rng: any,
	session: PlayerSession.PlayerSession,
	enemies: EnemyManager.EnemyManager,
	weapons: WeaponRunner.WeaponRunner,
	spawner: Spawner.Spawner,
	pickups: PickupManager.PickupManager,
	enemyPresenter: EnemyPresenter.Presenter,
	projectilePresenter: ProjectilePool.Pool,
	time: number,
	paused: boolean,
	hudDue: number,
	offerId: number,
	offer: LevelUp.LevelUpOffer?,
	facingX: number,
	facingZ: number,
	lastX: number,
	lastZ: number,
	frame: WeaponRunner.PlayerFrame,
	-- Treasure owed by a living boss, by enemy handle.
	bossTreasure: { [number]: Waves.TreasureConfig },
}

local runs: { [Player]: Run } = {}

-- ------------------------------------------------------------------ helpers

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function pushHud(run: Run)
	local state = run.session.state
	local weapons: { { id: string, level: number } } = {}
	for _, id in state.weaponOrder do
		table.insert(weapons, { id = id, level = state.weapons[id] })
	end
	local passives: { { id: string, level: number } } = {}
	for _, id in state.passiveOrder do
		table.insert(passives, { id = id, level = state.passives[id] })
	end
	net.hud:FireClient(
		run.player,
		{
			time = run.time,
			level = state.level,
			xp = state.xp,
			xpToNext = state.xpToNext,
			health = state.health,
			maxHealth = state.stats.maxHealth,
			kills = state.kills,
			gold = state.gold,
			weapons = weapons,
			passives = passives,
			paused = run.paused,
		} :: Net.HudState
	)
end

local function pushRunState(run: Run, reason: string)
	net.runState:FireClient(
		run.player,
		{
			paused = run.paused,
			finished = run.session.finished,
			time = run.time,
			reason = reason,
		} :: Net.RunStatePayload
	)
end

-- Sends the next owed offer, or unpauses when the queue has drained. An
-- offer that cannot be built (nothing left to give, core_loop.md §2
-- slot-full rule) silently consumes its level-up rather than stalling.
local function advanceLevelUps(run: Run)
	local session = run.session
	while session.pendingLevelUps > 0 do
		local offer = session:nextOffer(run.rng)
		if offer == nil then
			session:dropPending()
		else
			run.offerId += 1
			run.offer = offer
			run.paused = true
			net.levelUpOffer:FireClient(
				run.player,
				{
					offerId = run.offerId,
					options = offer.options :: any,
					rerollsLeft = offer.rerollsLeft,
					skipsLeft = offer.skipsLeft,
					banishesLeft = offer.banishesLeft,
				} :: Net.LevelUpOfferPayload
			)
			pushRunState(run, "levelup")
			pushHud(run)
			return
		end
	end
	run.offer = nil
	if run.paused then
		run.paused = false
		pushRunState(run, "running")
	end
end

local function syncWeapons(run: Run)
	run.weapons:onStatsChanged(run.session.state)
	local humanoid = humanoidOf(run.player)
	if humanoid ~= nil then
		humanoid.WalkSpeed = run.session:walkSpeed()
	end
end

local function finish(run: Run, reason: string)
	run.paused = true
	run.offer = nil
	pushRunState(run, reason)
	pushHud(run)
end

-- --------------------------------------------------------------- run setup

local function startRun(player: Player): Run
	local seed = os.time() + player.UserId
	local rng = Rng.new(seed)
	local session = PlayerSession.new(DEFAULT_CHARACTER, rng)
	local enemies = EnemyManager.new(rng)
	local pickups = PickupManager.new(rng)
	local enemyPresenter = EnemyPresenter.new(enemies.capacity)
	local projectilePresenter = ProjectilePool.new(Tuning.projectileCapacity)

	local weapons = WeaponRunner.new({
		query = enemies.query,
		damage = function(handle: number, amount: number, knockback: number, _weaponId: string): boolean
			return enemies:damage(handle, amount, knockback)
		end,
		rng = rng,
		visual = function(spec)
			net.visual:FireClient(player, spec :: any)
		end,
	})
	weapons:registerAll(BEHAVIOURS :: any)

	local spawner = Spawner.new({ enemies = enemies :: any, rng = rng })

	local run: Run = {
		player = player,
		rng = rng,
		session = session,
		enemies = enemies,
		weapons = weapons,
		spawner = spawner,
		pickups = pickups,
		enemyPresenter = enemyPresenter,
		projectilePresenter = projectilePresenter,
		time = 0,
		paused = false,
		hudDue = 0,
		offerId = 0,
		offer = nil,
		facingX = 1,
		facingZ = 0,
		lastX = 0,
		lastZ = 0,
		frame = {
			time = 0,
			playerX = 0,
			playerZ = 0,
			facingX = 1,
			facingZ = 0,
			moveX = 0,
			moveZ = 0,
		},
		bossTreasure = {},
	}

	-- Wiring. Every hook is a plain closure over `run`; none allocate.
	enemies.onSpawn = function(handle: number, typeId: string)
		enemyPresenter:show(handle, typeId)
	end
	enemies.onDeath = function(handle: number, _typeId: string, x: number, z: number, xp: number, _isBoss: boolean)
		enemyPresenter:hide(handle)
		session.state.kills += 1
		local scatter = Tuning.gemDropScatter
		pickups:drop(x + rng:range(-scatter, scatter), z + rng:range(-scatter, scatter), xp)
		local treasure = run.bossTreasure[handle]
		if treasure ~= nil then
			run.bossTreasure[handle] = nil
			-- pickups_meta.md §3: chest odds are per stage-minute and Luck
			-- scales them; Sim/Chests owns the rule and the grants.
			local result = Chests.roll(treasure, session.state.stats.luck, rng, session.state, run.time)
			session.state.gold += result.gold
			syncWeapons(run)
		end
	end
	enemies.onContact = function(_handle: number, power: number)
		if session:damage(power, run.time) then
			pushHud(run)
		end
	end

	weapons.onProjectileSpawn = function(handle: number, weaponId: string, _visualKind: string)
		projectilePresenter:show(handle, weaponId)
	end
	weapons.onProjectileDespawn = function(handle: number)
		projectilePresenter:hide(handle)
	end

	spawner.onBoss = function(handle: number, _enemyId: string, treasure: Waves.TreasureConfig?)
		if treasure ~= nil then
			run.bossTreasure[handle] = treasure
		end
	end
	-- RESEARCH GAP (enemies_waves.md §4): "how many enemies a swarm emits,
	-- and the geometry of the flower wall/ring -- are not in Stage.json and
	-- remain unknown". Spawner schedules the events faithfully; with no
	-- spawn count to port, nothing is attached here rather than invented.
	spawner.onEvent = nil

	pickups.onCollect = function(xp: number, _handle: number)
		session:addXp(xp)
	end

	session.onStatsChanged = function(_stats)
		syncWeapons(run)
	end
	session.onFinish = function()
		finish(run, "dead")
	end

	-- The starting weapon comes from the character record.
	local character = Characters.data[DEFAULT_CHARACTER]
	local startingWeapon = character.startingWeaponId
	LevelUp.apply(session.state, {
		kind = "weapon",
		itemId = startingWeapon,
		toLevel = 1,
		isNew = true,
	})
	session:refreshStats()

	pushRunState(run, "running")
	pushHud(run)
	return run
end

local function endRun(run: Run)
	run.weapons:clear()
	run.pickups:clear()
	run.enemies:clear()
	run.enemyPresenter:destroy()
	run.projectilePresenter:destroy()
end

-- ------------------------------------------------------------------- step

local function stepRun(run: Run, dt: number)
	local session = run.session
	if session.finished then
		return
	end
	-- core_loop.md §2: the game pauses on level up. Nothing below this line
	-- runs while paused, which is what "the run clock stops" means.
	if run.paused then
		return
	end
	local root = rootOf(run.player)
	if root == nil then
		return
	end
	local position = root.Position
	local px, pz = position.X, position.Z

	-- Facing is the last non-zero movement direction (ARCHITECTURE.md,
	-- Player); it never becomes zero, so a standing player still aims.
	local moveX = px - run.lastX
	local moveZ = pz - run.lastZ
	run.lastX, run.lastZ = px, pz
	local moveLen = math.sqrt(moveX * moveX + moveZ * moveZ)
	if moveLen > 0 then
		run.facingX = moveX / moveLen
		run.facingZ = moveZ / moveLen
	end

	run.time += dt

	run.spawner:step(run.time, px, pz, session.state.level, session.state.stats.curse)
	run.enemies:step(dt, px, pz)

	local frame = run.frame
	frame.time = run.time
	frame.playerX = px
	frame.playerZ = pz
	frame.facingX = run.facingX
	frame.facingZ = run.facingZ
	frame.moveX = moveX
	frame.moveZ = moveZ
	run.weapons:step(dt, frame)

	run.pickups:step(dt, px, pz, session:magnetRadius(), session.state.stats.growth)
	session:step(dt)

	if session.pendingLevelUps > 0 then
		advanceLevelUps(run)
	end

	local enemyCols = run.enemies
	run.enemyPresenter:flush(enemyCols.x, enemyCols.z, enemyCols.alive, enemyCols.facing)
	local weaponCols = run.weapons
	run.projectilePresenter:flush(weaponCols.x, weaponCols.z, weaponCols.alive, weaponCols.heading)

	run.hudDue -= dt
	if run.hudDue <= 0 then
		run.hudDue = Tuning.hudPushInterval
		pushHud(run)
	end
end

-- ------------------------------------------------------------- level-up io

net.chooseOption.OnServerEvent:Connect(function(player: Player, payload: any)
	local run = runs[player]
	if run == nil or type(payload) ~= "table" then
		return
	end
	local offer = run.offer
	-- A reply that does not match the offer this server actually sent is
	-- dropped: the offerId is what makes a crafted or stale reply inert.
	if offer == nil or payload.offerId ~= run.offerId then
		return
	end
	local session = run.session
	local action = payload.action
	if action == "choose" then
		local index = payload.index
		if type(index) ~= "number" then
			return
		end
		local option = offer.options[index]
		if option == nil then
			return
		end
		session:applyOption(option)
		advanceLevelUps(run)
	elseif action == "reroll" then
		local rerolled = LevelUp.reroll(session.state, offer, run.rng)
		run.offerId += 1
		run.offer = rerolled
		net.levelUpOffer:FireClient(
			player,
			{
				offerId = run.offerId,
				options = rerolled.options :: any,
				rerollsLeft = rerolled.rerollsLeft,
				skipsLeft = rerolled.skipsLeft,
				banishesLeft = rerolled.banishesLeft,
			} :: Net.LevelUpOfferPayload
		)
	elseif action == "skip" then
		LevelUp.skip(session.state, offer, run.rng)
		session:dropPending()
		advanceLevelUps(run)
	elseif action == "banish" then
		local index = payload.index
		if type(index) ~= "number" then
			return
		end
		local option = offer.options[index]
		if option == nil then
			return
		end
		local remaining = LevelUp.banish(session.state, offer, run.rng, option.itemId)
		run.offerId += 1
		run.offer = remaining
		net.levelUpOffer:FireClient(
			player,
			{
				offerId = run.offerId,
				options = remaining.options :: any,
				rerollsLeft = remaining.rerollsLeft,
				skipsLeft = remaining.skipsLeft,
				banishesLeft = remaining.banishesLeft,
			} :: Net.LevelUpOfferPayload
		)
	end
end)

-- ------------------------------------------------------------- lifecycle

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		if runs[player] == nil then
			runs[player] = startRun(player)
		end
	end)
	if player.Character ~= nil and runs[player] == nil then
		runs[player] = startRun(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	local run = runs[player]
	if run ~= nil then
		runs[player] = nil
		endRun(run)
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	for _, run in runs do
		stepRun(run, dt)
	end
end)
