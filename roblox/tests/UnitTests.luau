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

	-- tutorial -------------------------------------------------------------------------
	test("tutorial advances only when the real action happened", function()
		local T = Shared.Tutorial
		local d = E.newData()
		eq(d.tutorialStep, 1)
		eq(T.advance(d), false, "nothing done yet")
		d.totalMoney = Big.new(100)
		eq(T.advance(d), true)
		eq(d.tutorialStep, 2)
		d.mainLevels[1] = 1
		d.mainLevels[2] = 1
		T.advance(d)
		eq(d.tutorialStep, 4, "skips through already-satisfied steps")
		T.finish(d)
		eq(T.current(d), nil)
	end)
	test("tutorial final step never auto-advances past itself", function()
		local T = Shared.Tutorial
		local d = E.newData()
		d.tutorialStep = #T.STEPS
		T.advance(d)
		eq(d.tutorialStep, #T.STEPS)
	end)

	-- prestige layers --------------------------------------------------------------------
	test("ascension is tier-like: 1 AP each, requirement climbs x1.1", function()
		local Pr = Shared.Prestige
		local d = E.newData()
		d.rebirths = 249
		eq(Pr.pending(d, "ascension"), 0, "below threshold")
		d.rebirths = 10 ^ 6
		eq(Pr.pending(d, "ascension"), 1, "always exactly 1, however far past")
		eq(Pr.requirement(d, "ascension"), 250)
		d.prestige.ascension.count = 2
		eq(Pr.requirement(d, "ascension"), 303)
	end)
	test("ascending banks 1 AP, resets the run, keeps tiers", function()
		local d = E.newData()
		d.rebirths = 1000
		d.tiers = 3
		d.money = Big.pow(10, 50)
		d.mainLevels[1] = 40
		eq(E.prestige(d, "ascension"), true)
		eq(d.prestige.ascension.points, 1)
		eq(d.prestige.ascension.lifetime, 1)
		eq(d.rebirths, 0)
		eq(d.tiers, 3, "ascension keeps tiers")
		eq(d.mainLevels[1], 0)
		truthy(Big.lt(d.money, 1))
		eq(E.prestige(d, "ascension"), false, "nothing pending right after")
	end)
	test("each lifetime AP gives +0.1x rebirths per click", function()
		local d = E.newData()
		d.mechanics = 1
		d.prestige.ascension.lifetime = 10 -- 1 + 0.1*10 = 2x
		d.money = Big.mul(F.rebirthCost(d, 0), 1.01)
		eq(E.rebirth(d), true)
		eq(d.rebirths, 2)
	end)
	test("first shop levels cost 1 AP; lines scale differently", function()
		local Pr = Shared.Prestige
		local d = E.newData()
		eq(Pr.cost(d, "AS-MOMENTUM"), 1)
		eq(Pr.cost(d, "AS-LUCK"), 1)
		eq(Pr.cost(d, "AS-CASH"), 1)
		d.prestige.ascension.shop = { ["AS-MOMENTUM"] = 3, ["AS-LUCK"] = 3, ["AS-CASH"] = 3 }
		eq(Pr.cost(d, "AS-MOMENTUM"), 8, "soft: (1+3)^1.5")
		eq(Pr.cost(d, "AS-LUCK"), 4, "linear: 1+3")
		eq(Pr.cost(d, "AS-CASH"), 8, "exp: 2^3")
	end)
	test("spending AP never lowers the passive", function()
		local Pr = Shared.Prestige
		local d = E.newData()
		d.prestige.ascension.points, d.prestige.ascension.lifetime = 10, 10
		local before = Pr.rebirthGainMult(d)
		eq(E.buyPrestigeUpgrade(d, "AS-LUCK"), true)
		truthy(Pr.rebirthGainMult(d) >= before)
		eq(d.prestige.ascension.points, 9)
	end)
	test("ascension shop luck is core luck (cache invalidates on buy)", function()
		local d = E.newData()
		E.refresh(d)
		local base = d.totalLuckLog
		d.prestige.ascension.points = 1
		E.buyPrestigeUpgrade(d, "AS-LUCK")
		near(d.totalLuckLog, base + math.log10(2), 1e-9)
	end)
	test("rebirth memory keeps a slice of rebirths on ascend", function()
		local d = E.newData()
		d.rebirths = 1000
		d.prestige.ascension.shop["AS-MEMORY"] = 2
		eq(E.prestige(d, "ascension"), true)
		eq(d.rebirths, 100)
	end)
	test("transcension: 1 TrP, magnifies AP gain, resets ascension + tiers", function()
		local Pr = Shared.Prestige
		local d = E.newData()
		d.prestige.ascension.lifetime = 44
		eq(Pr.pending(d, "transcension"), 0, "needs 45 lifetime AP")
		d.prestige.ascension.lifetime = 45
		d.tiers = 5
		d.skills.main[1] = 3
		eq(Pr.pending(d, "transcension"), 1)
		eq(E.prestige(d, "transcension"), true)
		eq(d.prestige.ascension.lifetime, 0)
		eq(d.tiers, 0)
		eq(d.skills.main[1], 0, "TP trees refunded with tiers")
		d.prestige.transcension.lifetime = 4 -- 1 + 0.25*4 = 2
		d.rebirths = 250
		eq(Pr.pending(d, "ascension"), 2)
	end)
	test("mega board slots: x0.8 centre, x100 far edge, later tiers pay more", function()
		eq(F.slotMult(0, 200), 0.8)
		eq(F.slotMult(0, 223), 1.5)
		eq(F.slotMult(0, 2), 100)
		eq(F.slotMult(0, 398), 100)
		eq(F.slotMult(3, 398), 220)
	end)
	-- starter runes ------------------------------------------------------------------------
	test("runes: milestones 10, 100, 500, 1K, 5K, 10K", function()
		local Ru = Shared.Runes
		eq(Ru.milestone(1), 10)
		eq(Ru.milestone(2), 100)
		eq(Ru.milestone(3), 500)
		eq(Ru.milestone(4), 1000)
		eq(Ru.milestone(5), 5000)
		eq(Ru.milestone(6), 10000)
		eq(Ru.milestonesReached(9), 0)
		eq(Ru.milestonesReached(1000), 4)
	end)
	test("runes: bulk = (1 + up to 4) x 1.15^milestones", function()
		local Ru = Shared.Runes
		local d = E.newData()
		eq(Ru.stats(d).bulk, 1)
		d.runes.opened = 1000 -- 4 milestones: (1+4) * 1.15^4 = 8.7
		eq(Ru.stats(d).bulk, 8)
		d.runes.opened = 10000 -- 6 milestones: (1+4) * 1.15^6 = 11.6
		eq(Ru.stats(d).bulk, 11)
	end)
	test("runes: playtime bonuses unlock in order and save", function()
		local Ru = Shared.Runes
		local d = E.newData()
		d.runes.padSeconds = 24 * 3600
		local st = Ru.stats(d)
		-- (1 + 4) * 1.1 * 1.25 * 1.5 * 2 = 20.6
		eq(st.bulk, 20)
		near(st.luck, 1.05 * 1.10 * 1.25 * 1.5, 1e-9)
	end)
	test("runes 1-5 cap and stay maxed; 6-10 never cap (x1.25 copies per level)", function()
		local Ru = Shared.Runes
		local spark, echo = Ru.LIST[1], Ru.LIST[6]
		near(Ru.boost(spark, 50), 0.25, 1e-9)
		near(Ru.boost(spark, 5000), 0.25, 1e-9)
		eq(Ru.level(1), 1)
		eq(Ru.level(2), 4)
		eq(Ru.level(100), 21)
		truthy(Ru.level(1e6) > Ru.level(1e5))
		truthy(Ru.boost(echo, 1e9) > Ru.boost(echo, 1e6))
	end)
	test("runes: clone chance + amount, tickrate speeds opening", function()
		local Ru = Shared.Runes
		local d = E.newData()
		d.runes.forge.cloneChance, d.runes.forge.cloneAmount, d.runes.forge.tickrate = 5, 2, 3
		local st = Ru.stats(d)
		near(st.clone, 0.15, 1e-9)
		eq(st.cloneAmount, 3)
		near(st.rate, 0.5 * 1.1 ^ 3, 1e-9)
		d.runes.forge = { clone = 4, tick = 2 } -- old save
		Ru.ensure(d)
		eq(d.runes.forge.cloneChance, 4)
		eq(d.runes.forge.tickrate, 2)
	end)
	test("runes cost $10 each and stop when cash runs out", function()
		local Ru = Shared.Runes
		local d = E.newData()
		d.money = Big.new(35)
		local _, n = Ru.open(d, 10, false)
		eq(n, 3)
		truthy(Big.lt(d.money, 10))
		eq(d.runes.opened, 3)
	end)
	test("rebirth-point runes add whole rebirths via carry", function()
		local d = E.newData()
		d.mechanics = 1
		d.runes.counts[6] = 2 -- Echo LV 4 = +6% rebirth points
		local total = 0
		for _ = 1, 25 do
			d.money = Big.mul(F.rebirthCost(d, d.rebirths), 1.01)
			local before = d.rebirths
			eq(E.rebirth(d), true)
			total += d.rebirths - before
		end
		eq(total, 26, "25 rebirths x 1.06 = 26.5 -> 26 whole, 0.5 carried")
	end)
	test("halo runes boost AP per ascension", function()
		local Pr = Shared.Prestige
		local d = E.newData()
		d.rebirths = 250
		d.runes.counts[8] = 1e6 -- Halo LV 62 = +124%
		eq(Pr.pending(d, "ascension"), 2)
	end)
	-- rarity names + effects --------------------------------------------------------------
	test("2000 rarities, every name unique", function()
		local seen = {}
		for k, r in P.Rarities do
			truthy(not seen[r.name], "duplicate name " .. r.name .. " at #" .. k)
			seen[r.name] = true
		end
		truthy(#P.Rarities >= 2000)
		eq(P.Rarities[1].name, "Pebble")
		eq(P.Rarities[50].name, "The Absolute")
	end)
	test("effects never get worse as rarity climbs", function()
		local keys = { "glow", "sparkles", "rings", "moons", "starburst" }
		for k = 2, #P.Rarities do
			local a, b = P.Rarities[k - 1].fx, P.Rarities[k].fx
			truthy(b.level >= a.level, "level drops at #" .. k)
			for _, key in keys do
				truthy(b[key] >= a[key], key .. " drops at #" .. k)
			end
		end
		eq(P.Rarities[2000].fx.horizon, true)
	end)
	-- progressive reveal ------------------------------------------------------------------
	test("new player sees only the board: every stand hidden", function()
		local U = Shared.Unlocks
		local d = E.newData()
		for _, st in U.STANDS do
			eq(U.state(d, st.id), "hidden", st.id)
		end
	end)
	test("cash stand: ??? after first cash, open once you can buy", function()
		local U = Shared.Unlocks
		local d = E.newData()
		d.totalMoney = Big.new(5)
		eq(U.state(d, "cash"), "teaser")
		d.totalMoney = Big.new(50)
		eq(U.state(d, "cash"), "open")
	end)
	test("ascension pops up 10 rebirths before it's ready", function()
		local U = Shared.Unlocks
		local d = E.newData()
		d.rebirths = 239
		eq(U.state(d, "ascension"), "hidden")
		d.rebirths = 240
		eq(U.state(d, "ascension"), "teaser")
		d.rebirths = 250
		eq(U.state(d, "ascension"), "open")
	end)
	test("opened stands stay open after resets", function()
		local U = Shared.Unlocks
		local d = E.newData()
		d.totalMoney = Big.new(100)
		local opened = U.update(d)
		eq(opened[1], "cash")
		d.totalMoney = Big.new(0)
		eq(U.state(d, "cash"), "open")
		eq(#U.update(d), 0, "no repeat unlock")
	end)
	test("old saves get prestige state", function()
		local d = E.newData()
		local s = E.serialize(d)
		s.version = 3
		s.prestige = nil
		local d2 = E.deserialize(s)
		truthy(d2.prestige and d2.prestige.ascension and d2.prestige.transcension)
	end)

	-- formatting -------------------------------------------------------------------------
	test("format handles tiny, huge and zero", function()
		eq(F.format(0), "0")
		eq(F.format(1234), "1,234")
		truthy(F.format(Big.pow(10, 9000)):find("e9000"))
	end)

	return results
end
