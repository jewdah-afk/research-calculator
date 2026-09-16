--!nonstrict
--[[
	PlayerService — join/leave flow, leaderstats, movement, and the single
	snapshot the client renders from.

	The client never computes currency or rarity. It receives a snapshot and
	draws it. Every remote is rate limited here.
]]

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local PlayerService = {}

-- Other services push callbacks here instead of requiring each other, which
-- keeps the module graph a tree and avoids circular requires.
PlayerService.profileReady = {}   -- (player, data)
PlayerService.profileClosing = {} -- (player, data)

local lastCall = {}   -- [player] = { [key] = os.clock() }

function PlayerService.flags(player)
	return {
		incomeMultiplier = player:GetAttribute("GP_doubleIncome") and Config.GamePasses.doubleIncome.multiplier or 1,
		luckMultiplier = player:GetAttribute("GP_luckyRolls") and Config.GamePasses.luckyRolls.luck or 1,
		speedBonus = player:GetAttribute("GP_vipSpeed") and Config.GamePasses.vipSpeed.speedBonus or 0,
		autoCollect = player:GetAttribute("GP_autoCollect") == true,
	}
end

-- Returns false when the player is spamming a remote.
function PlayerService.rateLimit(player, key)
	local cooldown = Config.RateLimits[key] or 0.2
	local bucket = lastCall[player]
	if not bucket then
		bucket = {}
		lastCall[player] = bucket
	end
	local now = os.clock()
	if bucket[key] and now - bucket[key] < cooldown then
		return false
	end
	bucket[key] = now
	return true
end

function PlayerService.notify(player, text, tone)
	Remotes.event(Remotes.Names.Notify):FireClient(player, text, tone or "info")
end

function PlayerService.refreshSpeed(player)
	local data = DataService.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end

	local speed = Economy.walkSpeed(data, PlayerService.flags(player))
	if player:GetAttribute("Carrying") then
		speed *= Config.Steal.carrySpeedPenalty
	end
	humanoid.WalkSpeed = speed
end

local function compactInventory(data)
	local list = {}
	local placedByUid = {}
	for padIndex, uid in pairs(data.placed or {}) do
		placedByUid[uid] = tonumber(padIndex)
	end

	for _, record in ipairs(data.inventory or {}) do
		table.insert(list, {
			uid = record.uid,
			biome = record.biome,
			pet = record.pet,
			tier = record.tier or 0,
			income = Economy.petIncome(record),
			pad = placedByUid[record.uid],
		})
	end
	return list
end

local function upgradeSnapshot(data)
	local out = {}
	for _, key in ipairs(Config.UpgradeOrder) do
		local level = data.upgrades[key] or 0
		out[key] = {
			level = level,
			cost = Config.upgradeCost(key, level),
			maxed = level >= Config.Upgrades[key].max,
			value = Config.Upgrades[key].apply(level),
		}
	end
	return out
end

function PlayerService.pushState(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local flags = PlayerService.flags(player)
	local now = os.time()

	Remotes.event(Remotes.Names.StateChanged):FireClient(player, {
		coins = data.coins,
		vault = data.vault,
		income = Economy.income(data, flags),
		storageCap = Economy.storageCap(data),
		padCount = Economy.padCount(data),
		rebirths = data.rebirths,
		rebirthCost = Economy.rebirthCost(data),
		luck = Economy.luck(data, flags, now),
		walkSpeed = Economy.walkSpeed(data, flags),
		upgrades = upgradeSnapshot(data),
		inventory = compactInventory(data),
		biomes = Economy.unlockedBiomes(data, flags),
		limited = Economy.limitedWindow(now),
		shieldUntil = data.shieldUntil,
		dailyStreak = data.dailyStreak,
		dailyReady = (now - (data.dailyClaimedAt or 0)) >= Config.Daily.resetSeconds,
		dailyReward = Economy.dailyReward(data.dailyStreak or 0),
		hatches = data.hatches,
		stolenByMe = data.stolenByMe,
		stolenFromMe = data.stolenFromMe,
	})
end

local function setupLeaderstats(player, data)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Value = data.coins
	coins.Parent = stats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths
	rebirths.Parent = stats

	stats.Parent = player
end

function PlayerService.syncLeaderstats(player)
	local data = DataService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	stats.Coins.Value = math.floor(data.coins)
	stats.Rebirths.Value = data.rebirths
end

function PlayerService.addCoins(player, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.coins = math.max((data.coins or 0) + amount, 0)
	PlayerService.syncLeaderstats(player)
end

function PlayerService.claimDaily(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = os.time()
	local since = now - (data.dailyClaimedAt or 0)
	if since < Config.Daily.resetSeconds then
		PlayerService.notify(player, "Daily reward isn't ready yet.", "warn")
		return
	end

	data.dailyStreak = since > Config.Daily.graceSeconds and 0 or (data.dailyStreak or 0)
	local reward = Economy.dailyReward(data.dailyStreak)
	data.dailyStreak += 1
	data.dailyClaimedAt = now

	PlayerService.addCoins(player, reward)
	PlayerService.notify(player, ("Day %d streak: +%d coins"):format(data.dailyStreak, reward), "good")
	PlayerService.pushState(player)
end

local function onCharacter(player, character)
	local plot = PlotService.plotOf(player)
	if plot then
		character:PivotTo(plot.spawnCFrame)
	end
	player:SetAttribute("Carrying", false)
	task.defer(PlayerService.refreshSpeed, player)
end

local function onPlayerAdded(player)
	local data = DataService.load(player)
	if not data then
		return -- DataService already kicked them
	end

	local plot = PlotService.assign(player)
	if not plot then
		player:Kick("This server is full. Please join another.")
		return
	end

	setupLeaderstats(player, data)
	PlotService.setActivePads(plot, Economy.padCount(data))

	-- Offline pay: the reason to open the game tomorrow.
	local flags = PlayerService.flags(player)
	if (data.lastSeen or 0) > 0 then
		local earned, seconds = Economy.offlineEarnings(data, flags, os.time())
		if earned > 0 then
			PlayerService.addCoins(player, earned)
			task.delay(3, function()
				if player.Parent then
					PlayerService.notify(player, ("While you were away (%s) your pets earned %d coins.")
						:format(math.floor(seconds / 60) .. "m", earned), "good")
				end
			end)
		end
	end
	data.lastSeen = os.time()

	for _, callback in ipairs(PlayerService.profileReady) do
		task.spawn(callback, player, data)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end

	PlayerService.syncLeaderstats(player)
	PlayerService.pushState(player)
end

function PlayerService.start()
	Players.PlayerAdded:Connect(function(player)
		local ok, err = pcall(onPlayerAdded, player)
		if not ok then
			warn("[PlayerService] join failed: " .. tostring(err))
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local data = DataService.get(player)
		if data then
			data.lastSeen = os.time()
			for _, callback in ipairs(PlayerService.profileClosing) do
				pcall(callback, player, data)
			end
		end
		lastCall[player] = nil
	end)

	Remotes.event(Remotes.Names.ClaimDaily).OnServerEvent:Connect(function(player)
		if PlayerService.rateLimit(player, "buy") then
			PlayerService.claimDaily(player)
		end
	end)

	-- Keeps the HUD's luck/limited-egg pills honest without spamming remotes.
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in ipairs(Players:GetPlayers()) do
				PlayerService.pushState(player)
			end
		end
	end)
end

return PlayerService
