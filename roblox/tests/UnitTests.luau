--!nonstrict
-- Unit tests for the shared game logic. Each test gets the Shared module table.
-- Runs in the CLI (tests/run.sh) and in Studio (TestRunner.server.luau).

return function(Shared)
	local Config = Shared.OrbConfig
	local F = Shared.OrbFormulas
	local E = Shared.OrbEconomy
	local P = Shared.Progression
	local Big = Shared.Big
	local Balance = Shared.Balance
	local Events = Shared.Events

	local results = { passed = 0, failed = {} }
	local function test(name, fn)
		local ok, err = pcall(fn)
		if ok then
			results.passed += 1
		else
			table.insert(results.failed, name .. ": " .. tostring(err))
		end
	end
	local function eq(a, b, msg)
		if a ~= b then
			error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2)
		end
	end
	local function near(a, b, tol, msg)
		if math.abs(a - b) > (tol or 1e-6) then
			error((msg or "") .. " expected ~" .. tostring(b) .. " got " .. tostring(a), 2)
		end
	end
	local function truthy(v, msg)
		if not v then
			error(msg or "expected truthy", 2)
		end
	end

	-- rarities ---------------------------------------------------------------------------
	test("rarity table is strictly increasing in odds and value", function()
		for k = 2, #P.Rarities do
			truthy(P.Rarities[k].oneInLog > P.Rarities[k - 1].oneInLog, "odds at " .. k)
			truthy(P.Rarities[k].valueLog > P.Rarities[k - 1].valueLog, "value at " .. k)
		end
	end)
	test("hand-tuned rarities match the original table", function()
		near(P.Rarities[5].oneInLog, math.log10(250))
		near(P.Rarities[50].valueLog, math.log10(1.8e49))
	end)
	test("roll at luck 1 is almost always common", function()
		local commons = 0
		for _ = 1, 2000 do
			if F.rollRarity(0, math.random()) == 1 then
				commons += 1
			end
		end
		truthy(commons > 1300, "commons " .. commons)
	end)
	test("roll respects luck (huge luck reaches deep rarities)", function()
		local k = F.rollRarity(500, 0.5)
		truthy(k > 100, "got " .. k)
	end)
	test("display odds of common at luck 1", function()
		near(F.oneInLog(0, 1), -math.log10(1 - 1 / 4), 1e-9)
	end)

	-- costs ------------------------------------------------------------------------------
	test("bulk buy matches buying one at a time", function()
		local a = E.newData()
		a.money = Big.new(1e9)
		local b = E.newData()
		b.money = Big.new(1e9)
		E.buyMain(a, 1, math.huge)
		while E.buyMain(b, 1) do end
		truthy(math.abs(a.mainLevels[1] - b.mainLevels[1]) <= 1, a.mainLevels[1] .. " vs " .. b.mainLevels[1])
	end)
	test("diamond chance caps at 25%", function()
		local d = E.newData()
		d.money = Big.pow(10, 400)
		E.buyMain(d, 3, math.huge)
		truthy(F.diamondChance(d) <= F.DIAMOND_CHANCE_CAP + 1e-9)
		eq(E.buyMain(d, 3), false, "buy past cap")
	end)
	test("spawn interval floors at 100ms", function()
		local d = E.newData()
		d.money = Big.pow(10, 300)
		E.buyInterval(d, 1, math.huge)
		truthy(d.spawnIntervals[1] >= 100)
		eq(E.buyInterval(d, 1), false)
	end)
	test("cannot buy with no money", function()
		local d = E.newData()
		eq(E.buyMain(d, 1), false)
		eq(Big.log10(d.money) <= 0 or Big.lt(d.money, 1), true)
	end)

	-- rebirth / tier ---------------------------------------------------------------------
	test("rebirth requires unlock and money", function()
		local d = E.newData()
		d.money = Big.new(1e6)
		eq(E.rebirth(d), false, "locked")
		d.mechanics = 1
		eq(E.rebirth(d), true)
		eq(d.rebirths, 1)
		truthy(Big.lt(d.money, 1), "money reset")
	end)
	test("bulk rebirth counts correctly", function()
		local d = E.newData()
		d.mechanics = 1
		d.skills.max[1], d.skills.max[2], d.skills.max[3] = 1, 1, 1
		d.money = F.rebirthCost(d, 9) -- exactly the 10th rebirth's cost
		d.money = Big.mul(d.money, 1.0001)
		eq(F.bulkRebirths(d), 10)
	end)
	test("relative tiers: target follows luck, always moves forward", function()
		local prev = nil
		local luck = 40
		for t = 4, 200 do
			local odds = P.nextTierOdds(t, luck, prev)
			truthy(odds >= luck + P.TIER_DELTA - 1e-9, "tier " .. t .. " not ahead of luck")
			if prev then
				truthy(odds >= prev + P.TIER_MIN_STEP - 1e-9, "tier " .. t .. " didn't advance")
			end
			truthy(P.rarityAtOdds(odds) <= #P.Rarities, "beyond table")
			prev = odds
			luck += 3 -- slow grower: still always reachable (fixed distance ahead)
		end
		truthy(P.rarityAtOdds(prev) < #P.Rarities, "rarity table too short for 200 slow tiers")
	end)
	test("relative tier progress counts this rarity or rarer since last tier", function()
		local d = E.newData()
		d.mechanics = 4
		d.tiers = 4
		d.tierReqOdds = P.Rarities[60].oneInLog
		local req = F.tierRequirement(d)
		eq(req.relative, true)
		E.collect(d, { kind = "orb", rarity = 59 }, 200)
		eq(d.tierProgress, 0)
		E.collect(d, { kind = "orb", rarity = 75 }, 200)
		eq(d.tierProgress, 1)
		d.tierProgress = req.count
		eq(F.canTier(d), false, "pacing floor blocks an instant tier")
		d.timePlayed = d.tierStartTime + P.tierMinSeconds(d.tiers + 1)
		eq(F.canTier(d), true)
		eq(E.tier(d), true)
		eq(d.tierProgress, 0)
		truthy(d.tierReqOdds > P.Rarities[60].oneInLog, "target advanced")
	end)
	test("tier resets the right things and keeps lifetime counts", function()
		local d = E.newData()
		d.mechanics = 4
		d.orbsObtained[14] = 50
		d.rebirths = 20
		eq(E.tier(d), true)
		eq(d.tiers, 1)
		eq(d.rebirths, 0)
		eq(d.orbsObtained[14], 50, "lifetime counts kept")
	end)

	-- bonus budget -----------------------------------------------------------------------
	test("bonus budget: small bonuses apply in full", function()
		near(Balance.softcap(0.3, 1), 0.3)
	end)
	test("bonus budget: huge bonuses are compressed", function()
		local applied = Balance.softcap(100, 2)
		truthy(applied < 2 + 10, "applied " .. applied)
	end)
	test("stacking every event can't exceed budget + sqrt", function()
		local d = E.newData()
		local list = {}
		for id in Events.TYPES do
			for _ = 1, 10 do
				table.insert(list, { id = id, endsAt = math.huge })
			end
		end
		Balance.setEvents(list)
		local before = d.totalLuckLog
		E.refresh(d)
		local gained = d.totalLuckLog - before
		local raw = Balance.rawBonusLog(d, "luck")
		local cap = Balance.budget("luck", 0)
		truthy(gained <= cap + math.sqrt(raw - cap) + 1e-9, "gained " .. gained)
		Balance.setEvents({})
	end)
	test("new content registers without touching core", function()
		local d = E.newData()
		E.refresh(d)
		local base = d.totalLuckLog
		Balance.register("test_feature", "luck", function()
			return 50
		end)
		E.refresh(d)
		truthy(d.totalLuckLog < base + Balance.budget("luck", 0) + math.sqrt(50) + 1e-9)
		Balance.unregister("test_feature")
		E.refresh(d)
		near(d.totalLuckLog, base)
	end)
	test("event validation", function()
		local def, m = Events.validate("cash2x", 9999)
		truthy(def)
		eq(m, 24 * 60, "clamped to a day")
		local bad = Events.validate("nope")
		eq(bad, nil)
		eq(Events.spawnSpeed({ events = { { id = "frenzy", endsAt = math.huge }, { id = "frenzy", endsAt = math.huge }, { id = "frenzy", endsAt = math.huge } } }), 2, "frenzy capped")
	end)

	-- weather ----------------------------------------------------------------------------
	test("weather odds sum to 1 for every unlock count", function()
		for n, odds in Config.WeatherOdds do
			local s = 0
			for _, p in odds do
				s += p
			end
			near(s, 1, 1e-9, "unlock " .. n)
		end
	end)
	test("storm level is endless and costs grow", function()
		local d = E.newData()
		d.mechanics = 5
		d.weatherPoints = 1e9
		for _ = 1, 30 do
			truthy(E.buyStormLevel(d))
		end
		eq(d.stormLevel, 30)
		truthy(E.stormLevelCost(d) > 10 * 1.6 ^ 29)
	end)

	-- save / migrate ---------------------------------------------------------------------
	test("serialize round-trip keeps big numbers", function()
		local d = E.newData()
		d.money = Big.pow(10, 1234.5)
		d.orbsObtained[777] = 3
		local d2 = E.deserialize(E.serialize(d))
		near(Big.log10(d2.money), 1234.5, 1e-3)
		eq(d2.orbsObtained[777], 3)
	end)
	test("v1 save migrates: veterans skip tutorial", function()
		local d = E.newData()
		d.rebirths = 3
		local s = E.serialize(d)
		s.version = 1
		s.tutorialStep = nil
		s.stormLevel = nil
		local d2 = E.deserialize(s)
		eq(d2.version, E.SAVE_VERSION)
		eq(d2.tutorialStep, 0)
		eq(d2.stormLevel, 0)
	end)
	test("garbage save doesn't crash and gives fresh data", function()
		local d = E.deserialize({ money = 12, tiers = "x", skills = 5 })
		eq(d.tiers, 0)
		truthy(Big.lt(d.money, 1))
	end)

	-- formatting -------------------------------------------------------------------------
	test("format handles tiny, huge and zero", function()
		eq(F.format(0), "0")
		eq(F.format(1234), "1,234")
		truthy(F.format(Big.pow(10, 9000)):find("e9000"))
	end)

	return results
end
