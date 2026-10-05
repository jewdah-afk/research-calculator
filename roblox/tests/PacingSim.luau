--!nonstrict
-- Long-run pacing simulator (QA). Plays a greedy bot through the REAL economy code using
-- expected values per step, so hundreds of hours simulate in seconds.
-- Fails (returns ok=false) if any tier lands outside the pacing band.
--
-- Run outside Roblox:  luau tests/run.luau        (see tests/README)

return function(Shared, opts)
	opts = opts or {}
	local Config = Shared.OrbConfig
	local F = Shared.OrbFormulas
	local E = Shared.OrbEconomy
	local P = Shared.Progression
	local Big = Shared.Big
	local R = P.Rarities

	local STEP = opts.step or 10 -- seconds of game time per step
	local MAX_HOURS = opts.maxHours or 1500
	local TARGET_TIER = opts.tiers or 30
	local BAND_MIN, BAND_MAX = opts.bandMin or 9.5, opts.bandMax or 300 -- minutes per tier (tier 5+)

	-- first rarity with oddsL >= x (binary search; rarities sorted by odds)
	local function firstAtLeast(x)
		local lo, hi = 1, #R
		while lo < hi do
			local mid = (lo + hi) // 2
			if R[mid].oneInLog >= x then
				hi = mid
			else
				lo = mid + 1
			end
		end
		return lo
	end

	local function logAdd(a, b)
		if a == -math.huge then return b end
		if b == -math.huge then return a end
		local m = math.max(a, b)
		return m + math.log10(10 ^ (a - m) + 10 ^ (b - m))
	end

	-- expected log10(value) per rarity orb, and per-rarity probability function, at luck effL
	local function rollStats(effL)
		local t = function(k)
			return math.min(1, 10 ^ (effL - R[k].oneInLog))
		end
		local top = math.min(firstAtLeast(effL + 6), #R)
		local ev = -math.huge
		local k = top
		while k >= 1 do
			local p = (k == 1) and (1 - (#R >= 2 and t(2) or 0)) or (t(k) - (k < #R and t(k + 1) or 0))
			if p > 0 then
				ev = logAdd(ev, math.log10(p) + R[k].valueLog)
			end
			if t(k) >= 1 then
				break
			end
			k -= 1
		end
		return ev, function(i)
			return (i == 1) and (1 - t(2)) or math.max(t(i) - (i < #R and t(i + 1) or 0), 0)
		end
	end

	local data = E.newData("orig")
	data.tutorialStep = 0
	local time = 0
	local tierTimes, lastTierAt = {}, 0
	local rebirthsAtTier = {}
	local fails = {}

	local function spendSkills()
		for _ = 1, 50 do
			local bought = false
			for _, id in (opts.skills or { "MAX-1", "MAX-2", "MAX-3", "MAX-4", "RL-1", "RL-3", "RL-4", "SPW-1", "SPW-2", "SPW-4", "MN-5", "BST-1", "MN-2", "MN-1", "MN-3" }) do
				if E.buySkill(data, id) then
					bought = true
				end
			end
			for _, src in { "Money", "Diamonds", "WeatherRolls", "OrbsSpawned" } do
				if E.gainTP(data, src) then
					bought = true
				end
			end
			if E.gainQP(data) then
				bought = true
			end
			if not bought then
				break
			end
		end
	end

	while time < MAX_HOURS * 3600 and data.tiers < TARGET_TIER do
		E.refresh(data)
		-- income over one step
		local slot = 1.4
		local cashMultL = Big.log10(F.orbMoneyMult(data))
		local dc = F.diamondChance(data)
		for s = 1, data.spawnersUnlocked do
			local spawns = STEP * 1000 / data.spawnIntervals[s]
			local effL = data.totalLuckLog + F.spawnerLuckLog(data, s)
			local ev, pk = rollStats(effL)
			local orbs = spawns * (1 - dc)
			local gainL = ev + cashMultL + math.log10(slot) + math.log10(orbs)
			data.money = Big.add(data.money, Big.pow(10, gainL))
			data.totalMoney = Big.add(data.totalMoney, Big.pow(10, gainL))
			data.diamonds = Big.add(data.diamonds, Big.mul(F.diamondGain(data, slot, nil), spawns * dc))
			data.orbsSpawned += orbs
			-- track tier requirement rarity counts + best rarity
			local req = F.tierRequirement(data)
			if req.relative then
				-- this rarity or rarer: P = luck/oneIn (capped at 1)
				data.tierProgress += orbs * math.min(1, 10 ^ (effL - R[req.rarity].oneInLog))
			else
				data.orbsObtained[req.rarity] = (data.orbsObtained[req.rarity] or 0) + orbs * pk(req.rarity)
			end
			local top = firstAtLeast(effL)
			if top > data.highestRarity then
				data.highestRarity = top
			end
		end
		if data.mechanics >= 5 then
			data.weatherPoints += math.floor(STEP / 30)
			while E.rollWeather(data) do end
			while E.buyStormLevel(data) do end
		end
		data.automationPoints += (data.tiers >= 2) and STEP or 0
		time += STEP
		data.timePlayed = time

		-- greedy bot
		E.maxBuyMain(data)
		E.maxBuyAllSpawners(data)
		while E.buySpawner(data, data.spawnersUnlocked + 1) do end
		while E.unlockMechanic(data) do end
		for _ = 1, 20 do
			if not E.buyDiamondLuck(data) then break end
		end
		E.tickSecond(data) -- timers (approximate: one tick per step)
		if data.mechanics >= 1 and Big.gt(data.money, F.rebirthCost(data)) then
			E.rebirth(data)
		end
		if F.canTier(data) and E.tier(data) then
			local mins = (time - lastTierAt) / 60
			tierTimes[data.tiers] = mins
			rebirthsAtTier[data.tiers] = data.rebirths
			lastTierAt = time
			-- tier 5 follows the original 27h tier 4, so the band starts at tier 6
			if data.tiers >= 6 and (mins < BAND_MIN or mins > BAND_MAX) then
				table.insert(fails, string.format("tier %d took %.1f min (band %d-%d)", data.tiers, mins, BAND_MIN, BAND_MAX))
			end
			spendSkills()
		end
		if data.tiers >= 1 then
			spendSkills()
		end
	end

	if data.tiers < TARGET_TIER then
		table.insert(fails, string.format("stalled at tier %d after %d hours", data.tiers, MAX_HOURS))
	end
	return {
		ok = #fails == 0,
		fails = fails,
		tierTimes = tierTimes,
		hours = time / 3600,
		final = data,
	}
end
