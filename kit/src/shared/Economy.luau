--!nonstrict
--[[
	Economy — pure functions over a save file.

	Nothing here touches Instances, so the server, the client HUD and the
	balancing calculator in tools/ all agree on the maths by construction. If you
	change a formula, change it once, here.
]]

local Config = require(script.Parent:WaitForChild("Config"))

local Economy = {}

-- The income of a single owned pet, including its fuse tier.
function Economy.petIncome(record)
	local def = Config.petById(record.biome, record.pet)
	if not def then
		return 0
	end
	return def.income * Config.Fuse.incomeMultiplier ^ (record.tier or 0)
end

function Economy.rebirthMultiplier(data)
	return 1 + (data.rebirths or 0) * Config.Rebirth.incomeBonus
end

-- Coins per second across everything standing on the plot.
function Economy.income(data, flags)
	flags = flags or {}
	local placedUids = {}
	for _, uid in pairs(data.placed or {}) do
		placedUids[uid] = true
	end

	local total = 0
	for _, record in ipairs(data.inventory or {}) do
		if placedUids[record.uid] then
			total += Economy.petIncome(record)
		end
	end

	return total * Economy.rebirthMultiplier(data) * (flags.incomeMultiplier or 1)
end

function Economy.storageCap(data)
	return Config.Upgrades.storage.apply(data.upgrades and data.upgrades.storage or 0)
end

function Economy.padCount(data)
	local fromUpgrade = Config.Upgrades.pads.apply(data.upgrades and data.upgrades.pads or 0)
	local fromRebirths = math.floor((data.rebirths or 0) / Config.Rebirth.padEvery)
	return math.floor(fromUpgrade + fromRebirths)
end

function Economy.walkSpeed(data, flags)
	flags = flags or {}
	local base = Config.Upgrades.speed.apply(data.upgrades and data.upgrades.speed or 0)
	return base + (flags.speedBonus or 0)
end

function Economy.luck(data, flags, now)
	flags = flags or {}
	now = now or os.time()

	local luck = Config.Upgrades.luck.apply(data.upgrades and data.upgrades.luck or 0)
	luck *= (flags.luckMultiplier or 1)

	if (data.luckBoostUntil or 0) > now then
		luck *= Config.Products.luckBoost.luckMultiplier
	end

	local window = Economy.limitedWindow(now)
	if window.active then
		luck *= Config.Limited.luckBonus
	end

	return luck
end

function Economy.rebirthCost(data)
	return Config.rebirthCost(data.rebirths or 0)
end

function Economy.canRebirth(data)
	return (data.coins or 0) >= Economy.rebirthCost(data)
end

-- Which biomes this player may enter, given their speed.
function Economy.unlockedBiomes(data, flags)
	local speed = Economy.walkSpeed(data, flags)
	local unlocked = {}
	for _, biome in ipairs(Config.Biomes) do
		if speed >= biome.speedGate then
			table.insert(unlocked, biome.id)
		end
	end
	return unlocked
end

function Economy.canEnter(data, flags, biomeId)
	local biome = Config.biomeById(biomeId)
	if not biome then
		return false
	end
	return Economy.walkSpeed(data, flags) >= biome.speedGate
end

--[[
	The limited egg rotates on wall-clock time, so every server in the game
	agrees without any cross-server messaging. Returns the current window and
	which pet is boosted.
]]
function Economy.limitedWindow(now)
	now = now or os.time()
	local cycle = Config.Limited.cycleSeconds
	local elapsed = now % cycle
	local index = (math.floor(now / cycle) % #Config.Limited.pool) + 1

	return {
		active = elapsed < Config.Limited.windowSeconds,
		petId = Config.Limited.pool[index],
		secondsLeft = elapsed < Config.Limited.windowSeconds
			and (Config.Limited.windowSeconds - elapsed)
			or (cycle - elapsed),
	}
end

-- Offline pay, capped so it is a reason to come back rather than a reason to quit.
function Economy.offlineEarnings(data, flags, now)
	now = now or os.time()
	local away = math.max(now - (data.lastSeen or now), 0)
	local capped = math.min(away, Config.OfflineEarningsCapHours * 3600)
	local earned = Economy.income(data, flags) * capped * Config.OfflineEarningsRate
	return math.floor(earned), capped
end

function Economy.dailyReward(streak)
	local rewards = Config.Daily.rewards
	local index = math.clamp(streak + 1, 1, #rewards)
	return rewards[index]
end

return Economy
