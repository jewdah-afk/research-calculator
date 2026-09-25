--!nocheck
-- transpiled from layers/ap.js by port/build.js: do not edit
return function()
-- transpiled from layers/ap.js
addLayer(nil, "ap", JS.O({
	name = "atomic-prestige",
	symbol = "AP",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = "#A0E0E0",
	requires = JS.D("1e1997"),
	resource = "atomic-prestige points",
	baseResource = "hyper-prestige points",
	baseAmount = function(this)
	do return player.hp.points end
end,
	type = "normal",
	gainMult = function(this)
	mult = JS.D(1)
	if hasUpgrade(nil, "ap", 21) then
		mult = mult:mul(upgradeEffect(nil, "ap", 21))
	end
	if hasUpgrade(nil, "t", 62) then
		mult = mult:mul(upgradeEffect(nil, "t", 62))
	end
	do return mult end
end,
	gainExp = function(this)
	m = JS.D(1)
	if hasUpgrade(nil, "t", 22) then
		m = m:mul(1.01)
	end
	do return m end
end,
	row = 4,
	exponent = 0.005,
	hotkeys = JS.A(1, JS.O({
	key = "a",
	description = "A: Reset for atomic-prestige points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(80) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	branches = JS.A(1, JS.A(2, "hp", 3)),
	softcap = JS.D(math.huge),
	softcapPower = JS.D(1),
	upgrades = JS.O({
	rows = 3,
	cols = 4,
	[11] = JS.O({
	title = "Atomic-Prestige Upgrade 11",
	description = "First Milestone's effect is boosted by your atomic-prestige points.",
	cost = JS.D(1),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = JS.D("1e2000")
	if player.m.best:gte(84) then
		base = base:mul("1e4000")
	end
	if player.m.best:gte(94) then
		base = base:mul("1e4000")
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret:mul("1e48000"):mul(Decimal.pow("1e500", player[JS.k(this.layer)].points:min(140))) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Atomic-Prestige Upgrade 12",
	description = "Prestige Point gain is boosted by your atomic-prestige points.",
	cost = JS.D(4),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = JS.D("1e1000")
	if player.m.best:gte(84) then
		base = base:mul("1e2000")
	end
	if player.m.best:gte(94) then
		base = base:mul("1e2000")
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret:mul("1e39000"):mul(Decimal.pow("1e150", player[JS.k(this.layer)].points:min(500))) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Atomic-Prestige Upgrade 13",
	description = "Super-Prestige Point gain is boosted by your atomic-prestige points.",
	cost = JS.D(5000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = JS.D("1e5000")
	if player.m.best:gte(84) then
		base = base:mul("1e1000")
	end
	if player.m.best:gte(94) then
		base = base:mul("1e1000")
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret:mul("1e20000"):mul(Decimal.pow("1e30", player[JS.k(this.layer)].points:sqrt():min(2300))) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[14] = JS.O({
	title = "Atomic-Prestige Upgrade 14",
	description = "Hyper-Prestige Point gain is boosted by your atomic-prestige points.",
	cost = JS.D(50000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = JS.D("1e15")
	if player.m.best:gte(84) then
		base = base:mul("1e10")
	end
	if player.m.best:gte(94) then
		base = base:mul("1e10")
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[21] = JS.O({
	title = "Atomic-Prestige Upgrade 21",
	description = "Atomic-Prestige Point gain is boosted by your atomic-prestige points.",
	cost = JS.D(200000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 1.4
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[22] = JS.O({
	title = "Atomic-Prestige Upgrade 22",
	description = "Each upgrade in this row unlocks an Atomic-Prestige challenge.",
	cost = JS.D(2000000000),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[23] = JS.O({
	title = "Atomic-Prestige Upgrade 23",
	description = "Milestone Cost Scaling is weaker based on your atomic-prestige points.",
	cost = JS.D(3000000000000000000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local p = player.ap.points:add(100000000000000000000):log10():log10():div(200)
	if hasUpgrade(nil, "ap", 24) then
		p = p:mul(4)
	end
	if hasUpgrade(nil, "ap", 33) then
		p = p:mul(2)
	end
	if hasUpgrade(nil, "ap", 34) then
		p = p:mul(1.2)
	end
	do return p:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x weaker") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[24] = JS.O({
	title = "Atomic-Prestige Upgrade 24",
	description = "Atomic-Prestige Upgrade 23 is boosted.",
	cost = JS.D(2e35),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[31] = JS.O({
	title = "Atomic-Prestige Upgrade 31",
	description = "The Second Hyper-Prestige buyable's effect ^1.5.",
	cost = JS.D("1e5470"),
	unlocked = function(this)
	do return hasUpgrade(nil, "t", 44) end
end
}, {"title", "description", "cost", "unlocked"}),
	[32] = JS.O({
	title = "Atomic-Prestige Upgrade 32",
	description = "1st Milestone's softcap starts later based on your atomic-prestige points.",
	cost = JS.D("1e5613"),
	unlocked = function(this)
	do return hasUpgrade(nil, "t", 44) end
end,
	effect = function(this)
	local p = player.ap.points:add(100000000000000000000):log10():log10():div(57)
	if hasUpgrade(nil, "ap", 33) then
		p = p:mul(2)
	end
	if hasUpgrade(nil, "ap", 34) then
		p = p:mul(1.2)
	end
	do return p:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[33] = JS.O({
	title = "Atomic-Prestige Upgrade 33",
	description = "Atomic-Prestige Upgrade 23 and 32 are boosted.",
	cost = JS.D("3e6045"),
	unlocked = function(this)
	do return hasUpgrade(nil, "t", 44) end
end
}, {"title", "description", "cost", "unlocked"}),
	[34] = JS.O({
	title = "Atomic-Prestige Upgrade 34",
	description = "Atomic-Prestige Upgrade 23 and 32 are boosted.",
	cost = JS.D("3e6951"),
	unlocked = function(this)
	do return hasUpgrade(nil, "t", 44) end
end
}, {"title", "description", "cost", "unlocked"})
}, {"rows", "cols"}),
	challenges = JS.O({
	rows = 4,
	cols = 2,
	[11] = JS.O({
	name = "No Prestige Boost",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (("You can't gain prestige boosts.<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return (hasUpgrade(nil, "ap", 22) and hasUpgrade(nil, "ap", 21)) end
end,
	goal = function(this)
	if player.m.best:gte(120) then
		do return this:goalAfter120(Math.ceil(JS.add(player.ap.challenges[11], 0.001))) end
	end
	if (JS.tonum(player.ap.challenges[11]) >= 5) then
		do return (JS.D("1e46730000")):pow(Decimal.pow(1.3, Decimal.pow((JS.tonum(player.ap.challenges[11]) - 5), 1.5))) end
	end
	do return (JS.A(5, JS.D("1e1960000"), JS.D("1e3550000"), JS.D("1e4950000"), JS.D("1e8150000"), JS.D("e21640000")))[JS.k(player.ap.challenges[11])] end
end,
	currencyDisplayName = "points",
	currencyInternalName = "points",
	rewardDescription = function(this)
	do return "Prestige Boost's effect is better." end
end,
	completionsAfter120 = function(this)
	local p = player.points
	if player.m.best:gte(130) then
		if p:lte("1e1000000") then
			do return 0 end
		end
		do return p:log10():div((1000000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.3):pow((1 / 1.3)):toNumber() end
	end
	if p:lte("1e1400000") then
		do return 0 end
	end
	do return p:log10():div((1400000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.32):pow((1 / 1.3)):toNumber() end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.ap.challenges[11] end
	if player.m.best:gte(130) then
		do return Decimal.pow(10, Decimal.pow(1.3, Decimal.pow(x, 1.3)):mul((1000000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	do return Decimal.pow(10, Decimal.pow(1.32, Decimal.pow(x, 1.3)):mul((1400000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.ap.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "currencyDisplayName", "currencyInternalName", "rewardDescription", "completionsAfter120", "goalAfter120", "canComplete"}),
	[12] = JS.O({
	name = "No Super-Prestige",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (("You can't gain super-prestige points.<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return (hasUpgrade(nil, "ap", 22) and hasUpgrade(nil, "ap", 22)) end
end,
	goal = function(this)
	if player.m.best:gte(120) then
		do return this:goalAfter120(Math.ceil(JS.add(player.ap.challenges[12], 0.001))) end
	end
	if (JS.tonum(player.ap.challenges[12]) >= 5) then
		do return (JS.D("1e60560000")):pow(Decimal.pow(1.3, Decimal.pow((JS.tonum(player.ap.challenges[12]) - 5), 1.5))) end
	end
	do return (JS.A(5, JS.D("1e2300000"), JS.D("1e4870000"), JS.D("1e7000000"), JS.D("e12500000"), JS.D("e28880000")))[JS.k(player.ap.challenges[12])] end
end,
	currencyDisplayName = "points",
	currencyInternalName = "points",
	rewardEffect = function(this)
	local ret = (1 + (JS.tonum(player.ap.challenges[12]) * 0.05))
	if (JS.tonum(player.ap.challenges[12]) >= 5) then
		ret = (1.2 + (JS.tonum(player.ap.challenges[12]) * 0.01))
		if player.m.best:gte(122) then
			ret = (1.175 + (JS.tonum(player.ap.challenges[12]) * 0.015))
		end
		if player.m.best:gte(138) then
			ret = (1.15 + (JS.tonum(player.ap.challenges[12]) * 0.02))
		end
		if player.m.best:gte(144) then
			ret = (1.125 + (JS.tonum(player.ap.challenges[12]) * 0.025))
		end
	end
	do return ret end
end,
	rewardDisplay = function(this)
	do return ("Super-Prestige points ^" .. JS.str(format(nil, this:rewardEffect()))) end
end,
	rewardDescription = function(this)
	do return "Super-Prestige points is boosted based on this challenge's completions." end
end,
	completionsAfter120 = function(this)
	local p = player.points
	if player.m.best:gte(130) then
		if p:lte("1e1500000") then
			do return 0 end
		end
		do return p:log10():div((1500000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.31):pow((1 / 1.3)):toNumber() end
	end
	if p:lte("1e1700000") then
		do return 0 end
	end
	do return p:log10():div((1700000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.32):pow((1 / 1.3)):toNumber() end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.ap.challenges[12] end
	if player.m.best:gte(130) then
		do return Decimal.pow(10, Decimal.pow(1.31, Decimal.pow(x, 1.3)):mul((1500000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	do return Decimal.pow(10, Decimal.pow(1.32, Decimal.pow(x, 1.3)):mul((1700000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.ap.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "currencyDisplayName", "currencyInternalName", "rewardEffect", "rewardDisplay", "rewardDescription", "completionsAfter120", "goalAfter120", "canComplete"}),
	[21] = JS.O({
	name = "No Self-Boost",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (("3rd milestone's effect is always 1.<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return (hasUpgrade(nil, "ap", 22) and hasUpgrade(nil, "ap", 23)) end
end,
	goal = function(this)
	if player.m.best:gte(120) then
		do return this:goalAfter120(Math.ceil(JS.add(player.ap.challenges[21], 0.001))) end
	end
	if (JS.tonum(player.ap.challenges[21]) >= 5) then
		do return (JS.D("1e57090000")):pow(Decimal.pow(1.3, Decimal.pow((JS.tonum(player.ap.challenges[21]) - 5), 1.5))) end
	end
	do return (JS.A(5, JS.D("1e1615000"), JS.D("1e4130000"), JS.D("1e7150000"), JS.D("e18060000"), JS.D("e34850000")))[JS.k(player.ap.challenges[21])] end
end,
	currencyDisplayName = "points",
	currencyInternalName = "points",
	rewardDescription = function(this)
	do return "3rd milestone's effect is better." end
end,
	completionsAfter120 = function(this)
	local p = player.points
	if player.m.best:gte(130) then
		if p:lte("1e1000000") then
			do return 0 end
		end
		do return p:log10():div((1000000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.3):pow((1 / 1.34)):toNumber() end
	end
	if p:lte("1e1140000") then
		do return 0 end
	end
	do return p:log10():div((1140000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.3):pow((1 / 1.36)):toNumber() end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.ap.challenges[21] end
	if player.m.best:gte(130) then
		do return Decimal.pow(10, Decimal.pow(1.3, Decimal.pow(x, 1.34)):mul((1000000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	do return Decimal.pow(10, Decimal.pow(1.3, Decimal.pow(x, 1.36)):mul((1140000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.ap.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "currencyDisplayName", "currencyInternalName", "rewardDescription", "completionsAfter120", "goalAfter120", "canComplete"}),
	[22] = JS.O({
	name = "Reduced Points",
	completionLimit = math.huge,
	challengeDescription = function(this)
	if player.m.best:gte(122) then
		do return (("1st milestone's effect is replaced by (log10(1st milestone's effect+1))^(milestones)<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
	end
	do return (("1st milestone's effect is replaced by (log10(1st milestone's effect+1))^100<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return (hasUpgrade(nil, "ap", 22) and hasUpgrade(nil, "ap", 24)) end
end,
	goal = function(this)
	if player.m.best:gte(120) then
		do return this:goalAfter120(Math.ceil(JS.add(player.ap.challenges[22], 0.001))) end
	end
	if (JS.tonum(player.ap.challenges[22]) >= 5) then
		do return (JS.D("1e740")):pow(Decimal.pow(1.035, (JS.tonum(player.ap.challenges[22]) - 5))) end
	end
	do return (JS.A(5, JS.D("1e614"), JS.D("1e627"), JS.D("1e671"), JS.D("1e713"), JS.D("1e725")))[JS.k(player.ap.challenges[22])] end
end,
	currencyDisplayName = "points",
	currencyInternalName = "points",
	rewardDescription = function(this)
	do return "3rd milestone's effect is better, again." end
end,
	completionsAfter120 = function(this)
	local p = player.points:add(10):log10():div((600 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.035)
	if p:gte(75) then
		do return (function() local __v1 = player.points:add(10):log10():div((1000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.55); p = __v1 return __v1 end)() end
	end
	if p:gte(50) then
		do return (function() local __v2 = player.points:add(10):log10():div((1000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.5); p = __v2 return __v2 end)() end
	end
	if p:lte(3) then
		do return ((p:toNumber() / 2) + 3) end
	end
	do return p:toNumber() end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.ap.challenges[22] end
	if (JS.tonum(player.ap.challenges[22]) >= 75) then
		do return Decimal.pow(10, Decimal.pow(1.55, x):mul((1000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	if (JS.tonum(player.ap.challenges[22]) >= 50) then
		do return Decimal.pow(10, Decimal.pow(1.5, x):mul((1000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	if (JS.tonum(player.ap.challenges[22]) <= 3) then
		do return Decimal.pow(10, Decimal.pow(1.035, ((JS.tonum(x) * 2) - 3)):mul((600 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	do return Decimal.pow(10, Decimal.pow(1.035, x):mul((600 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.ap.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "currencyDisplayName", "currencyInternalName", "rewardDescription", "completionsAfter120", "goalAfter120", "canComplete"}),
	[31] = JS.O({
	name = "No Prestige",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (("You can't gain prestige points.<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(95) end
end,
	goal = function(this)
	if player.m.best:gte(120) then
		do return this:goalAfter120(Math.ceil(JS.add(player.ap.challenges[31], 0.001))) end
	end
	if (JS.tonum(player.ap.challenges[31]) >= 5) then
		do return (JS.D("1e18040000")):pow(Decimal.pow(1.3, Decimal.pow((JS.tonum(player.ap.challenges[31]) - 5), 1.5))) end
	end
	do return (JS.A(5, JS.D("1e3891000"), JS.D("1e4171000"), JS.D("1e6322000"), JS.D("1e8035000"), JS.D("1e9196000")))[JS.k(player.ap.challenges[31])] end
end,
	currencyDisplayName = "points",
	currencyInternalName = "points",
	rewardDescription = function(this)
	do return "Prestige Boost's effect is better." end
end,
	completionsAfter120 = function(this)
	local p = player.points
	if player.m.best:gte(136) then
		if p:lte("1e1600000") then
			do return 0 end
		end
		do return p:log10():div((1600000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.2):pow((1 / 1.35)):toNumber() end
	end
	if p:lte("1e1700000") then
		do return 0 end
	end
	do return p:log10():div((1700000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.2):pow((1 / 1.36)):toNumber() end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.ap.challenges[31] end
	if player.m.best:gte(136) then
		do return Decimal.pow(10, Decimal.pow(1.2, Decimal.pow(x, 1.35)):mul((1600000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	do return Decimal.pow(10, Decimal.pow(1.2, Decimal.pow(x, 1.36)):mul((1700000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.ap.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "currencyDisplayName", "currencyInternalName", "rewardDescription", "completionsAfter120", "goalAfter120", "canComplete"}),
	[32] = JS.O({
	name = "Disabled Buyables",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (("All Prestige, Super-Prestige and Hyper-Prestige buyables have no effect.<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(128) end
end,
	goal = function(this)
	do return this:goalAfter120(Math.ceil(JS.add(player.ap.challenges[32], 0.002))) end
end,
	currencyDisplayName = "points",
	currencyInternalName = "points",
	rewardEffect = function(this)
	local ret = (1 + (JS.tonum(player.ap.challenges[32]) * 0.05))
	do return ret end
end,
	rewardDisplay = function(this)
	do return ("Effect of All Prestige, Super-Prestige and Hyper-Prestige Buyables ^" .. JS.str(format(nil, this:rewardEffect()))) end
end,
	rewardDescription = function(this)
	do return "Effect of All Prestige, Super-Prestige and Hyper-Prestige Buyables is better." end
end,
	completionsAfter120 = function(this)
	local p = player.points
	if player.m.best:gte(141) then
		if p:lte("e1e10") then
			do return 0 end
		end
		do return p:log10():div((10000000000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.2):pow((1 / 1.5)):toNumber() end
	end
	if player.m.best:gte(130) then
		if p:lte("e2e10") then
			do return 0 end
		end
		do return p:log10():div((20000000000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.2):pow((1 / 1.5)):toNumber() end
	end
	if p:lte("e3e10") then
		do return 0 end
	end
	do return p:log10():div((30000000000 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.2):pow((1 / 1.5)):toNumber() end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.ap.challenges[31] end
	if player.m.best:gte(141) then
		do return Decimal.pow(10, Decimal.pow(1.2, Decimal.pow(x, 1.5)):mul((10000000000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	if player.m.best:gte(130) then
		do return Decimal.pow(10, Decimal.pow(1.2, Decimal.pow(x, 1.5)):mul((20000000000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	do return Decimal.pow(10, Decimal.pow(1.2, Decimal.pow(x, 1.5)):mul((30000000000 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.ap.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "currencyDisplayName", "currencyInternalName", "rewardEffect", "rewardDisplay", "rewardDescription", "completionsAfter120", "goalAfter120", "canComplete"}),
	[41] = JS.O({
	name = "Hyper Dilation",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (("All Atomic-Prestige challenges at once.<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(158) end
end,
	goal = function(this)
	do return this:goalAfter120(Math.ceil(JS.add(player.ap.challenges[41], 0.002))) end
end,
	currencyDisplayName = "points",
	currencyInternalName = "points",
	rewardEffect = function(this)
	local ret = (JS.D(player.ap.challenges[41])):add(1):times(2.42):pow(1.65):max(1)
	if player.ep.buyables[11]:gte(1) then
		ret = ret:times(tmp.ep.oneEffect)
	end
	do return softcap(nil, ret, JS.D("1e520"), 0.05) end
end,
	rewardDisplay = function(this)
	do return (("154th Milestone effect is x" .. JS.str(format(nil, this:rewardEffect()))) .. " better") end
end,
	rewardDescription = function(this)
	do return "154th Milestone effect is better." end
end,
	completionsAfter120 = function(this)
	local p = player.points
	if player.m.best:gte(141) then
		if p:lte("e1820") then
			do return 0 end
		end
		do return p:log10():div((1820 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.02):pow((1 / 1.15)):toNumber() end
	end
	if player.m.best:gte(130) then
		if p:lte("e1860") then
			do return 0 end
		end
		do return p:log10():div((1860 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.02):pow((1 / 1.15)):toNumber() end
	end
	if p:lte("e1950") then
		do return 0 end
	end
	do return p:log10():div((1950 / JS.tonum(buyableEffect(nil, "ap", 11)))):log(1.02):pow((1 / 1.15)):toNumber() end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.ap.challenges[41] end
	if player.m.best:gte(141) then
		do return Decimal.pow(10, Decimal.pow(1.02, Decimal.pow(x, 1.15)):mul((1820 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	if player.m.best:gte(130) then
		do return Decimal.pow(10, Decimal.pow(1.02, Decimal.pow(x, 1.15)):mul((1860 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
	end
	do return Decimal.pow(10, Decimal.pow(1.02, Decimal.pow(x, 1.15)):mul((1950 / JS.tonum(buyableEffect(nil, "ap", 11))))) end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.ap.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "currencyDisplayName", "currencyInternalName", "rewardEffect", "rewardDisplay", "rewardDescription", "completionsAfter120", "goalAfter120", "canComplete"}),
	[42] = JS.O({
	name = "Over-overflowed Milestones",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (("[No Self-Boost] and Milestone Overflow starts immediately, but its effect is weaker. Also on enter sets milestones and points to 0.<br>" .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(178) end
end,
	onEnter = function(this)
	JS.setk(player.m, "points", JS.D(0))
end,
	goal = function(this)
	do return this:goalAfter120(Math.ceil(JS.add(player.ap.challenges[42], 0.002))) end
end,
	currencyDisplayName = "points",
	currencyInternalName = "points",
	rewardEffect = function(this)
	local ret = (JS.D(player.ap.challenges[42])):add(1):pow(0.15):sub(1)
	do return softcap(nil, ret, JS.D("1e1500"), 0.05) end
end,
	rewardDisplay = function(this)
	do return (("5th Exotic Fusioner <br> effect is +" .. JS.str(format(nil, this:rewardEffect()))) .. " better") end
end,
	rewardDescription = function(this)
	do return "5th Exotic Fusioner effect is better." end
end,
	completionsAfter120 = function(this)
	local p = player.points
	if p:lte("e600") then
		do return 0 end
	end
	do return p:log10():div(700):log(1.01):pow((1 / 1.01)):toNumber() end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.ap.challenges[42] end
	do return Decimal.pow(10, Decimal.pow(1.01, Decimal.pow(x, 1.01)):mul(700)) end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.ap.challenges[JS.k(this.id)].goal) and player.m.best:lt(110)) end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "onEnter", "goal", "currencyDisplayName", "currencyInternalName", "rewardEffect", "rewardDisplay", "rewardDescription", "completionsAfter120", "goalAfter120", "canComplete"})
}, {"rows", "cols"}),
	buyables = JS.O({
	[11] = JS.O({
	title = function(this)
	do return "<h3 class='hr'>Challenge Slayer</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Reduce Challenges 1-7 base costs by /") .. JS.str(format(nil, data.effect, 4))) .. " (based on exotic prestige points)<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Prestige points") end
end,
	cost = function(this)
	local a = player[JS.k(this.layer)].buyables[JS.k(this.id)]
	local cost = JS.D(1)
	a = Decimal.pow((if player[JS.k(this.layer)].buyables[11]:gte(25) then 1.3 else 1.25), a)
	do return cost:mul(Decimal.pow("e1.5e10", a)) end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
end,
	effect = function(this)
	local b = 0.135
	if player.m.best:gte(180) then
		b = JS.add(b, 0.005)
	end
	local eff = (JS.D(1)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b)):pow(player.ep.points:add(1):log10():add(1):log10():pow(0.5))
	if hasMalware(nil, "m", 2) then
		eff = eff:mul(milestoneEffect(nil, "m", 2))
	end
	do return eff end
end,
	unlocked = function(this)
	do return player.m.best:gte(161) end
end,
	style = function(this)
	if player.ap.points:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"})
}),
	passiveGeneration = function(this)
	if player.m.best:gte(135) then
		do return 10000000000 end
	end
	if player.m.best:gte(90) then
		do return 5 end
	end
	do return 0 end
end,
	doReset = function(this, l)
	if (l == "ap") then
		do return end
	end
	if (l == "t") then
		if player.m.best:gte(102) then
			layerDataReset(nil, "ap", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "ap", JS.A(0))
		end
	end
end,
	update = function(this)
	local i
	if (player.m.best:gte(103) and (not JS.t(player.t.activeChallenge))) then
		local keep = 3
		if player.m.best:gte(108) then
			keep = 6
		end
		if player.m.best:gte(114) then
			keep = 9
		end
		if player.m.best:gte(121) then
			keep = 12
		end
		if player.m.best:gte(131) then
			keep = 15
		end
		if hasAchievement(nil, "ach", 27) then
			keep = JS.add(keep, 3)
		end
		JS.set(player.ap.challenges, 11, Math.max(player.ap.challenges[11], keep))
		JS.set(player.ap.challenges, 12, Math.max(player.ap.challenges[12], keep))
		JS.set(player.ap.challenges, 21, Math.max(player.ap.challenges[21], keep))
		JS.set(player.ap.challenges, 22, Math.max(player.ap.challenges[22], keep))
		JS.set(player.ap.challenges, 31, Math.max(player.ap.challenges[31], keep))
	end
	if (player.m.best:gte(110) and player.m.points:lt(120)) then
		if JS.t(player.ap.activeChallenge) then
			if player.points:gte(layers.ap.challenges[JS.k(player.ap.activeChallenge)]:goal()) then
				JS.set(player.ap.challenges, JS.k(player.ap.activeChallenge), (JS.tonum(player.ap.challenges[JS.k(player.ap.activeChallenge)]) + 1))
			end
		end
	end
	if player.m.best:gte(120) then
		if JS.t(player.ap.activeChallenge) then
			JS.set(player.ap.challenges, JS.k(player.ap.activeChallenge), Math.max(player.ap.challenges[JS.k(player.ap.activeChallenge)], layers.ap.challenges[JS.k(player.ap.activeChallenge)]:completionsAfter120()))
		end
	end
	if player.m.best:gte(140) then
		for _, __k3 in JS.keys(player.ap.challenges) do
			i = __k3
			JS.set(player.t.highestAPC[JS.k((if JS.t(player.t.activeChallenge) then player.t.activeChallenge else 0))], i, Math.max(player.t.highestAPC[JS.k((if JS.t(player.t.activeChallenge) then player.t.activeChallenge else 0))][i], player.ap.challenges[i]))
			JS.set(player.ap.challenges, i, Math.max(player.t.highestAPC[JS.k((if JS.t(player.t.activeChallenge) then player.t.activeChallenge else 0))][i], player.ap.challenges[i]))
		end
	end
	if player.m.best:gte(145) then
		if player.points:gte(tmp.ap.challenges[11].goal) then
			JS.set(player.ap.challenges, 11, Math.max(player.ap.challenges[11], layers.ap.challenges[11]:completionsAfter120()))
		end
		if player.points:gte(tmp.ap.challenges[12].goal) then
			JS.set(player.ap.challenges, 12, Math.max(player.ap.challenges[12], layers.ap.challenges[12]:completionsAfter120()))
		end
		if player.points:gte(tmp.ap.challenges[21].goal) then
			JS.set(player.ap.challenges, 21, Math.max(player.ap.challenges[21], layers.ap.challenges[21]:completionsAfter120()))
		end
	end
	if player.m.best:gte(150) then
		if player.points:gte(tmp.ap.challenges[31].goal) then
			JS.set(player.ap.challenges, 31, Math.max(player.ap.challenges[31], layers.ap.challenges[31]:completionsAfter120()))
		end
		if player.points:gte(tmp.ap.challenges[32].goal) then
			JS.set(player.ap.challenges, 32, Math.max(player.ap.challenges[32], layers.ap.challenges[32]:completionsAfter120()))
		end
	end
	if player.em.best:gte(8) then
		if player.points:gte(tmp.ap.challenges[22].goal) then
			JS.set(player.ap.challenges, 22, Math.max(player.ap.challenges[22], layers.ap.challenges[22]:completionsAfter120()))
		end
	end
	if (player.m.best:gte(175) and player.ap.points:gte(layers.ap.buyables[11]:cost())) then
		layers.ap.buyables[11]:buy()
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "exponent", "hotkeys", "layerShown", "branches", "softcap", "softcapPower", "upgrades", "challenges", "buyables", "passiveGeneration", "doReset", "update"}))

end
