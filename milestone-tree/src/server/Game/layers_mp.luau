--!nocheck
-- transpiled from layers/mp.js by port/build.js: do not edit
return function()
-- transpiled from layers/mp.js
addLayer(nil, "mp", JS.O({
	name = "multiverse prestige",
	symbol = "MP",
	position = 3,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0),
		best = JS.D(0),
		perkPoints = JS.D(0),
		totalF = JS.D(0),
		modeE = true,
		modeP = false
	}, {"unlocked", "points", "best", "perkPoints", "totalF", "modeE", "modeP"}) end
end,
	color = "#d03800",
	requires = function(this)
	do return JS.D("1e20000") end
end,
	resource = "multiverse prestige points",
	baseResource = "exotic prestige",
	baseAmount = function(this)
	do return player.ep.points end
end,
	type = "static",
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	gainExp = function(this)
	local m = JS.D(1)
	do return m end
end,
	row = 4,
	newRow = 2,
	exponent = function(this)
	if player.mp.points:gte(29) then
		do return (JS.D(7)):add(player.mp.points:div(25)) end
	end
	do return JS.D(7.5) end
end,
	hotkeys = JS.A(1, JS.O({
	key = "v",
	description = "V: Reset for Multiverse Prestige points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (player.m.best:gte(181) or player.pm.best:gte(1)) end
end,
	upgrades = JS.O({
	rows = 4,
	cols = 4,
	[11] = JS.O({
	title = "Multiverse Prestige Upgrade 11",
	description = "Prestige Power Strength boost Prestige Power gain",
	cost = JS.D(5),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 0.2
	local ret = player.pp.power:add(1):div("1e1000"):pow(base):max(1)
	do return softcap(nil, ret, JS.D(("ee10")), 0.00025) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Multiverse Prestige Upgrade 12",
	description = "Multiverse Prestige Points reduces Milestone Overflow effect",
	cost = JS.D(6),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 0.15
	local ret = player.mp.best:add(1):pow(base):sub(1)
	do return ret:add((if hasUpgrade(nil, "mp", 13) then upgradeEffect(nil, "mp", 13) else 0)) end
end,
	effectDisplay = function(this)
	do return ("-" .. JS.str(format(nil, this:effect()))) end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Multiverse Prestige Upgrade 13",
	description = "Unlock Multiverse Fusioners. Previous upgrade is better based on Multiverse Points",
	cost = JS.D(7),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 0.05
	local ret = player.mp.best:add(1):pow(base):sub(1)
	if hasUpgrade(nil, "mp", 14) then
		ret = ret:mul(5)
	end
	do return ret:max(0) end
end,
	effectDisplay = function(this)
	do return ("+" .. JS.str(format(nil, this:effect()))) end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[14] = JS.O({
	title = "Multiverse Prestige Upgrade 14",
	description = "Milestone Cost Scaling is disabled, and 5.00x prev. upgrade effect",
	cost = JS.D(11),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[21] = JS.O({
	title = "Multiverse Prestige Upgrade 21",
	description = "<i>Prestige Universe is corrupting Milestone Universe...</i><br>Unlock Malware Milestones",
	cost = JS.D(13),
	unlocked = function(this)
	do return player.pm.best:gte(15) end
end
}, {"title", "description", "cost", "unlocked"})
}, {"rows", "cols"}),
	challenges = JS.O({
	[11] = JS.O({
	onEnter = function(this)
	JS.setk(player.t, "points", JS.D(0))
	JS.setk(player.p, "points", JS.D(0))
	JS.setk(player.t, "dChoose", false)
	JS.setk(player.t, "sChoose", false)
	JS.setk(player.t, "pdChoose", false)
	JS.setk(player.t, "hChoose", false)
	JS.setk(player.t, "sdChoose", false)
	JS.setk(player.t, "phChoose", false)
	JS.setk(player.mp, "perkPoints", player.mp.buyables[13])
end,
	name = "Ex-Dilation",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return ((("4th Exotic Fusioner effect is ^0.15 weaker." .. "<br>") .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return true end
end,
	goal = function(this)
	if player.m.best:gte(120) then
		do return this:goalAfter120(Math.ceil(JS.add(player.mp.challenges[11], 0.001))) end
	end
end,
	canComplete = function(this)
	do return (player.ep.points:gte(tmp.mp.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end,
	completionsAfter120 = function(this)
	local p = player.ep.points
	if player.m.best:gte(130) then
		if p:lte("1e4500") then
			do return 0 end
		end
		do return p:log10():div(4500):log(1.1):pow((1 / 1.1)):toNumber() end
	end
	if p:lte("1e45000") then
		do return 0 end
	end
	do return p:log10():div(45000):log(1.1):pow((1 / 1.1)):toNumber() end
end,
	rewardEffect = function(this)
	local ret = (JS.tonum(JS.add(player.mp.challenges[11], (1 * 1.46))) ^ 1.75)
	do return ret end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.mp.challenges[11] end
	if player.m.best:gte(130) then
		do return Decimal.pow(10, Decimal.pow(1.1, Decimal.pow(x, 1.1)):mul(4500)) end
	end
	do return Decimal.pow(10, Decimal.pow(1.1, Decimal.pow(x, 1.1)):mul(45000)) end
end,
	currencyDisplayName = "Exotic Prestige Points",
	rewardDescription = function(this)
	do return (("6th Exotic Fusioner effect is x" .. JS.str(format(nil, this:rewardEffect()))) .. " better.") end
end
}, {"onEnter", "name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "completionsAfter120", "rewardEffect", "goalAfter120", "currencyDisplayName", "rewardDescription"}),
	[12] = JS.O({
	onEnter = function(this)
	layerDataReset(nil, "t", JS.A(2, "challenges", "upgrades"))
	layerDataReset(nil, "ep", JS.A(1, "buyables"))
	doReset(nil, "hp")
	JS.setk(player.t, "choose", JS.D(2))
end,
	onExit = function(this)
	JS.setk(player.t, "dChoose", false)
	JS.setk(player.t, "sChoose", false)
	JS.setk(player.t, "pdChoose", false)
	JS.setk(player.t, "hChoose", false)
	JS.setk(player.t, "sdChoose", false)
	JS.setk(player.t, "phChoose", false)
	JS.setk(player.mp, "perkPoints", player.mp.buyables[13])
end,
	name = "Weaker Transcend",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return ((("While entering this challenge, you should choose 2 Special Transcend Points (others will be unable to get)." .. "<br>") .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions.") end
end,
	unlocked = function(this)
	do return (player.m.best:gte(183) or player.pm.best:gte(1)) end
end,
	goal = function(this)
	if player.m.best:gte(120) then
		do return this:goalAfter120(Math.ceil(JS.add(player.mp.challenges[12], 0.001))) end
	end
end,
	canComplete = function(this)
	do return (player.ep.points:gte(tmp.mp.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end,
	completionsAfter120 = function(this)
	local p = player.ep.points
	if player.m.best:gte(130) then
		if p:lte("1e3000") then
			do return 0 end
		end
		do return p:log10():div(3000):log(1.15):pow((1 / 1.15)):toNumber() end
	end
	if p:lte("1e30000") then
		do return 0 end
	end
	do return p:log10():div(30000):log(1.15):pow((1 / 1.15)):toNumber() end
end,
	rewardEffect = function(this)
	local ret = (JS.tonum(JS.add(player.mp.challenges[12], 1)) / 5000)
	do return ret end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.mp.challenges[12] end
	if player.m.best:gte(130) then
		do return Decimal.pow(10, Decimal.pow(1.15, Decimal.pow(x, 1.15)):mul(3000)) end
	end
	do return Decimal.pow(10, Decimal.pow(1.15, Decimal.pow(x, 1.15)):mul(30000)) end
end,
	currencyDisplayName = "Exotic Prestige Points",
	rewardDescription = function(this)
	do return (("7th Exotic Fusioner effect is +" .. JS.str(format(nil, this:rewardEffect()))) .. " better.") end
end
}, {"onEnter", "onExit", "name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "completionsAfter120", "rewardEffect", "goalAfter120", "currencyDisplayName", "rewardDescription"}),
	[13] = JS.O({
	onEnter = function(this)
	JS.setk(player.t, "points", JS.D(0))
	JS.setk(player.p, "points", JS.D(0))
	JS.setk(player.ep, "points", JS.D(0))
	JS.setk(player.pp, "points", JS.D(0))
	JS.setk(player.t, "dChoose", false)
	JS.setk(player.t, "sChoose", false)
	JS.setk(player.t, "pdChoose", false)
	JS.setk(player.t, "hChoose", false)
	JS.setk(player.t, "sdChoose", false)
	JS.setk(player.t, "phChoose", false)
	JS.setk(player.mp, "perkPoints", player.mp.buyables[13])
end,
	name = "Exotic-less and No Transcend",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return ((("All of Exotic Fusioner effects are useless, Transcend Points hardcap is always at 1e10." .. "<br>") .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 4))) .. " completions") end
end,
	unlocked = function(this)
	do return (player.m.best:gte(184) or player.pm.best:gte(1)) end
end,
	goal = function(this)
	if player.m.best:gte(120) then
		do return this:goalAfter120(Math.ceil(JS.add(player.mp.challenges[13], 0.001))) end
	end
end,
	canComplete = function(this)
	do return (player.pep.points:gte(tmp.mp.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end,
	completionsAfter120 = function(this)
	local p = player.ep.points
	if player.m.best:gte(130) then
		if p:lte("1e950000") then
			do return 0 end
		end
		do return p:log10():div(950000):log(1.01):pow((1 / 2.5)):toNumber() end
	end
	if p:lte("1e9500000") then
		do return 0 end
	end
	do return p:log10():div(9500000):log(1.01):pow((1 / 2.5)):toNumber() end
end,
	rewardEffect = function(this)
	local ret = (JS.tonum(player.mp.challenges[13]) * 0.55)
	ret = softcap(nil, JS.D(ret), JS.D(7), 0.25)
	do return softcap(nil, JS.D(ret), JS.D(7.5), 0.5) end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.mp.challenges[13] end
	if player.m.best:gte(130) then
		do return Decimal.pow(10, Decimal.pow(1.01, Decimal.pow(x, 2.5)):mul(950000)) end
	end
	do return Decimal.pow(10, Decimal.pow(1.01, Decimal.pow(x, 2.5)):mul(9500000)) end
end,
	currencyDisplayName = "Exotic Prestige Points",
	rewardDescription = function(this)
	do return (("Prestige Power Upgrade 12 softcap starts " .. JS.str(format(nil, this:rewardEffect()))) .. " later.") end
end
}, {"onEnter", "name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "completionsAfter120", "rewardEffect", "goalAfter120", "currencyDisplayName", "rewardDescription"}),
	[21] = JS.O({
	onEnter = function(this)
	layerDataReset(nil, "pp", JS.A(1, "upgrades"))
	layerDataReset(nil, "p", JS.A(1, "upgrades"))
	if (not hasMalware(nil, "m", 15)) then
		layerDataReset(nil, "sp", JS.A(1, "upgrades"))
	end
	layerDataReset(nil, "pe", JS.A(1, "upgrades"))
	layerDataReset(nil, "hp", JS.A(1, "upgrades"))
	layerDataReset(nil, "ap", JS.A(2, "upgrades", "challenges"))
	layerDataReset(nil, "pb", JS.A(1, "upgrades"))
	layerDataReset(nil, "hb", JS.A(1, "upgrades"))
	layerDataReset(nil, "se", JS.A(1, "upgrades"))
	layerDataReset(nil, "ep", JS.A(0))
	layerDataReset(nil, "em", JS.A(0))
	layerDataReset(nil, "mm", JS.A(0))
	layerDataReset(nil, "m", JS.A(0))
	layerDataReset(nil, "t", JS.A(2, "upgrades", "challenges"))
	JS.setk(player.cp, "trojanChosen", nil)
	JS.setk(player.cp, "chosenBackdoor", nil)
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.cp, "cooldown", buyableEffect(nil, "cp", 33))
	JS.setk(player.cp, "cooldown2", buyableEffect(nil, "cp", 34))
end,
	onExit = function(this)
	local grid = player.cp.grid
	local slots = JS.m(Object.keys(grid), "filter", function(_, x)
		do return JS.eq(grid[JS.k(x)].active, true) end
	end)
	for i = 0, JS.cap(0, (JS.len(slots)) - 1, 1) do
		JS.set(player.cp.grid, JS.k(slots[JS.k(i)]), JS.O({
			level = getGridData(nil, "cp", slots[JS.k(i)]).level,
			active = false,
			fixed = false,
			type = getGridData(nil, "cp", slots[JS.k(i)]).type
		}, {"level", "active", "fixed", "type"}))
		JS.setk(player, "points", JS.D(0))
		JS.setk(player.pm, "essence", JS.D(0))
		JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
		JS.setk(player.cp, "peInCorrupt", JS.D(0))
		JS.setk(player.cp, "cooldown", buyableEffect(nil, "cp", 33))
		JS.setk(player.cp, "cooldown2", buyableEffect(nil, "cp", 34))
		JS.setk(player.cp, "trojanChosen", nil)
		JS.setk(player.cp, "chosenBackdoor", nil)
	end
	setInterval(nil, 100000000)
	JS.setk(player.mp, "perkPoints", player.mp.buyables[13])
	JS.setk(player, "tab", "m")
end,
	name = "Enter The Prestige Multiverse",
	completionLimit = JS.D(1),
	challengeDescription = function(this)
	do return ((("On enter resets all progress except for Milestones, 1st Milestone now divides points gain based on Multiverse Points." .. "<br>") .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id)))) .. "/1 completions") end
end,
	unlocked = function(this)
	do return (player.m.best:gte(185) or player.pm.best:gte(1)) end
end,
	goal = function(this)
	if (player.m.best:gte(120) or player.pm.best:gte(1)) then
		do return this:goalAfter120(Math.ceil(JS.add(player.mp.challenges[21], 0.001))) end
	end
end,
	canComplete = function(this)
	do return (player.pep.points:gte(tmp.mp.challenges[JS.k(this.id)].goal) and player.m.points:lt(110)) end
end,
	completionsAfter120 = function(this)
	local p = player.pep.points
	if (player.m.best:gte(130) or player.pm.best:gte(1)) then
		if p:lte("1e20") then
			do return 0 end
		end
		do return p:log10():div(20):log(1.01):pow((1 / 1.01)):toNumber() end
	end
end,
	rewardEffect = function(this)
	local ret = (JS.tonum(player.mp.challenges[21]) * 4)
	do return softcap(nil, JS.D(ret), JS.D(5), 0.25) end
end,
	goalAfter120 = function(this, x)
	if x == nil then x = player.mp.challenges[21] end
	if (player.m.best:gte(130) or player.pm.best:gte(1)) then
		do return Decimal.pow(10, Decimal.pow(1.01, Decimal.pow(x, 1.01)):mul(20)) end
	end
end,
	goalDescription = function(this)
	do return (("Goal: " .. JS.str(format(nil, this:goalAfter120()))) .. " Prestiged-Exotic Prestige Points in this challenge") end
end,
	currencyDisplayName = "Exotic Prestige Points",
	rewardDescription = function(this)
	do return "Unlock Ascensions<br><hr color='black'><i>You've reached the limit of Milestones Power. Travel into <b>Prestige Dimension</b> to get some kind of better Milestones... <br>Or even <b>Ascend</b>?</i>" end
end
}, {"onEnter", "onExit", "name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "completionsAfter120", "rewardEffect", "goalAfter120", "goalDescription", "currencyDisplayName", "rewardDescription"})
}),
	buyables = JS.O({
	rows = 2,
	cols = 3,
	respec = function(this)
	JS.setk(player.mp, "points", JS.D(7))
	JS.setk(player.mp, "perkPoints", JS.D(0))
	for _, __k1 in JS.keys(player.mp.buyables) do
		i = __k1
		JS.set(player.mp.buyables, i, JS.D(0))
	end
	JS.setk(player.mp, "totalF", JS.D(0))
	JS.setk(player.t, "dChoose", false)
	JS.setk(player.t, "sChoose", false)
	JS.setk(player.t, "pdChoose", false)
	JS.setk(player.t, "hChoose", false)
	JS.setk(player.t, "sdChoose", false)
	JS.setk(player.t, "phChoose", false)
	JS.setk(player.t, "choose", JS.D(0))
end,
	respecMessage = "Are you sure you want to respec Multiversal Fusioners? This will reset all of multiversal progress to pre-Fusioners stage!",
	respecText = "Respec Multiversal Fusioners",
	[11] = JS.O({
	title = function(this)
	do return "<h3 class='mr'>Milestone Fusioner</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Based on Milestones, get a boost to Exotic Prestige Points. <br>Effect: x") .. JS.str(format(nil, data.effect))) .. "<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Multiversal Prestige Points") end
end,
	cost = function(this, x)
	do return (JS.D(6)):add(x):add(player.mp.totalF:div(2)) end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.mp, "totalF", player.mp.totalF:add(1))
end,
	effect = function(this, x)
	local eff = x:add(1):pow(player.m.best:max(1):pow(2.5)):pow((JS.D(2)):pow(x))
	eff = softcap(nil, eff, JS.D(("ee10")), 0)
	if eff:gte(("ee10")) then
		eff = eff:pow(player.m.best:max(1):pow(0.75)):pow((JS.D(1.15)):pow(x))
	end
	do return eff end
end,
	unlocked = function(this)
	do return hasUpgrade(nil, "mp", 13) end
end,
	style = function(this)
	if player.mp.points:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[12] = JS.O({
	purchaseLimit = JS.D(6),
	title = function(this)
	do return "<h3 class='mr'>Exotic Fusioner II</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Per level, change Exotic Fusioner's effect's formulas or make effect's softcaps weaker. <br>Currently: ") .. JS.str(format(nil, data.effect, 0))) .. " / 6 effects boosted (starting at second).<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Multiversal Prestige Points") end
end,
	cost = function(this, x)
	do return (JS.D(7)):add(x:div(5)):add(player.mp.totalF:mul(2):div(3)) end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.mp, "totalF", player.mp.totalF:add(1))
end,
	effect = function(this, x)
	local eff = x
	do return eff end
end,
	unlocked = function(this)
	do return hasUpgrade(nil, "mp", 13) end
end,
	style = function(this)
	if player.mp.buyables[12]:gte(this.purchaseLimit) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "darkgreen",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
	if player.mp.points:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
end
}, {"purchaseLimit", "title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[13] = JS.O({
	purchaseLimit = JS.D(6),
	title = function(this)
	do return "<h3 class='mr'>Transcend Fusioner</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Per level, get a Perk Point, that can be used to strenghen Special Transcend Points's effect (chosen ones resets on enter Weaker Transcend). <br>Currently: ") .. JS.str(format(nil, data.effect, 0))) .. " / 6 more Perk Points.<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Multiversal Prestige Points") end
end,
	cost = function(this, x)
	do return (JS.D(7)):add(x:mul(2)):add(player.mp.totalF:div(2)) end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.mp, "perkPoints", player.mp.perkPoints:add(1))
	JS.setk(player.mp, "totalF", player.mp.totalF:add(1))
end,
	effect = function(this, x)
	local eff = x
	do return eff end
end,
	unlocked = function(this)
	do return hasUpgrade(nil, "mp", 13) end
end,
	style = function(this)
	if player.mp.buyables[13]:gte(this.purchaseLimit) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "darkgreen",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
	if player.mp.points:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
end
}, {"purchaseLimit", "title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[21] = JS.O({
	purchaseLimit = JS.D(3),
	title = function(this)
	do return "<h3 class='mr'>Upgrading Fusioner</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "(This fusioner's cost is not affected by amount of buyed Fusioners) Per level, unlock 2 more Exotic Prestige upgrades. <br>Currently: ") .. JS.str(format(nil, data.effect, 0))) .. " / 5 more upgrades.<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Multiversal Prestige Points") end
end,
	cost = function(this, x)
	if x:gte(1) then
		do return (JS.D(10)):mul(x) end
	else
		do return JS.D(8) end
	end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
end,
	effect = function(this, x)
	local eff = x:mul(2)
	if x:gte(3) then
		do return JS.D(5) end
	end
	do return eff end
end,
	unlocked = function(this)
	do return hasUpgrade(nil, "mp", 13) end
end,
	style = function(this)
	if player.mp.buyables[21]:gte(this.purchaseLimit) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "darkgreen",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
	if player.mp.points:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
end
}, {"purchaseLimit", "title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[22] = JS.O({
	scaled = function(this)
	local a = JS.D(20)
	if player.pm.points:gte(12) then
		a = a:add(tmp.pm.pMilestone11Effect)
	end
	do return a end
end,
	ultraScaled = function(this)
	local a = JS.D(33)
	if player.pep.buyables[11]:gte(4) then
		a = a:add(tmp.pep.prFourEffect)
	end
	do return a end
end,
	title = function(this)
	local table_ = ""
	if player[JS.k(this.layer)].buyables[JS.k(this.id)]:gte(this:scaled()) then
		table_ = "<h3>[ Scaled ] </h3> "
	end
	if player[JS.k(this.layer)].buyables[JS.k(this.id)]:gte(this:ultraScaled()) then
		table_ = "<h3>[ Ultra Scaled ] </h3> "
	end
	do return (JS.str(table_) .. "<h3 class='pmr'>Essence Fusioner</h3>") end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. JS.str(format(nil, data.effect.base))) .. "x ") .. JS.str((if JS.eq(player.mp.modeE, true) then "Prestige Essences" else "Points"))) .. " gain and double Prestige Essence effect.") .. "<br>Currently: ") .. JS.str(format(nil, data.effect.eff))) .. "x.<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Prestige Essence") end
end,
	cost = function(this, x)
	local pow = JS.D(1)
	if x:gte(this:scaled()) then
		pow = (JS.D(0.75)):add(x:add(1):sub(this:scaled()):div(15):mul((if hasUpgrade(nil, "cp", 13) then (JS.D(1)):sub(upgradeEffect(nil, "cp", 13)) else 1)))
	end
	if x:gte(this:ultraScaled()) then
		pow = (JS.D(1)):add(x:add(1):sub(this:ultraScaled()):div(10))
	end
	local cost = (JS.D(500)):mul(x:max(1)):pow(x:div(5):add(1)):mul(x:sub(5):add(1):mul(5):max(1)):pow(pow)
	do return cost end
end,
	canAfford = function(this)
	do return player.pm.essence:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.pm, "essence", player.pm.essence:sub(cost))
end,
	effect = function(this, x)
	local eff = JS.D(1)
	local base = JS.D(3)
	if JS.eq(player.mp.modeP, true) then
		base = JS.D(2)
	end
	if player.pep.buyables[11]:gte(3) then
		base = base:add(tmp.pep.prThreeEffect)
	end
	eff = base:pow(x)
	do return JS.O({
		eff = eff,
		base = base
	}, {"eff", "base"}) end
end,
	unlocked = function(this)
	do return player.pm.best:gte(2) end
end,
	style = function(this)
	if player.pm.essence:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
end
}, {"scaled", "ultraScaled", "title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[23] = JS.O({
	scaled = function(this)
	local a = JS.D(20)
	do return a end
end,
	ultraScaled = function(this)
	local a = JS.D(33)
	do return a end
end,
	title = function(this)
	local table_ = ""
	if player[JS.k(this.layer)].buyables[JS.k(this.id)]:gte(this:scaled()) then
		table_ = "<h3>[ Scaled ] </h3> "
	end
	if player[JS.k(this.layer)].buyables[JS.k(this.id)]:gte(this:ultraScaled()) then
		table_ = "<h3>[ Ultra Scaled ] </h3> "
	end
	do return (JS.str(table_) .. "<h3 class='pmr'>Recharge Fusioner</h3>") end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Add +") .. JS.str(format(nil, (if JS.eq(player.mp.modeE, true) then 0.25 else 0.05)))) .. " to exponent of 1st milestone reducing effect. <br>Currently: ") .. JS.str(format(nil, data.effect))) .. ".<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Prestige Essence") end
end,
	cost = function(this, x)
	local pow = JS.D(1)
	if x:gte(this:scaled()) then
		pow = (JS.D(1)):add(x:add(1):sub(this:scaled()):div(25):mul((if hasUpgrade(nil, "cp", 13) then (JS.D(1)):sub(upgradeEffect(nil, "cp", 13)) else 1)))
	end
	if x:gte(this:ultraScaled()) then
		pow = (JS.D(1.5)):add(x:add(1):sub(this:ultraScaled()):div(10))
	end
	do return (JS.D(5500)):mul(x:max(1)):pow(x:div(2):add(1)):pow(pow) end
end,
	canAfford = function(this)
	do return (player.pm.essence:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) and JS.eq(player.mp.activeChallenge, 21)) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.pm, "essence", player.pm.essence:sub(cost))
end,
	effect = function(this, x)
	local base = JS.D(0.25)
	if JS.eq(player.mp.modeP, true) then
		base = JS.D(0.05)
	end
	local eff = base:mul(x)
	if tmp.pm.count:gte(1) then
		eff = (if JS.eq(player.mp.modeP, true) then eff:sub(tmp.pm.pChalReward1) else eff:add(tmp.pm.pChalReward1))
	end
	do return eff end
end,
	unlocked = function(this)
	do return player.pm.best:gte(2) end
end,
	style = function(this)
	if player.pm.essence:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "300px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	end
end
}, {"scaled", "ultraScaled", "title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"})
}, {"rows", "cols", "respec", "respecMessage", "respecText"}),
	clickables = JS.O({
	[11] = JS.O({
	display = "Change Essence & Recharge mode to Prestige Essence boost, but lose ^0.5 of Prestige Essences.",
	canClick = function(this)
	do return JS.eq(player.mp.modeE, false) end
end,
	onClick = function(this)
	JS.setk(player.mp, "modeP", false)
	JS.setk(player.mp, "modeE", true)
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
end,
	style = function(this)
	if JS.eq(player.mp.modeE, true) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "50px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "50px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end,
	unlocked = function(this)
	do return player.pm.best:gte(2) end
end
}, {"display", "canClick", "onClick", "style", "unlocked"}),
	[12] = JS.O({
	canClick = function(this)
	do return JS.eq(player.mp.modeP, false) end
end,
	display = "Change Essence & Recharge mode to Points boost, but nullify Prestige Essences.",
	onClick = function(this)
	JS.setk(player.mp, "modeP", true)
	JS.setk(player.mp, "modeE", false)
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
end,
	style = function(this)
	if JS.eq(player.mp.modeP, true) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "50px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "50px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end,
	unlocked = function(this)
	do return player.pm.best:gte(2) end
end
}, {"canClick", "display", "onClick", "style", "unlocked"})
}),
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(4, "main-display", "prestige-button", "resource-display", JS.A(2, "challenges", JS.A(2, 1, 2)))
}),
	Upgrades = JS.O({
	content = JS.A(4, "main-display", "prestige-button", "resource-display", "upgrades")
}),
	Fusioners = JS.O({
	content = JS.A(5, "main-display", "prestige-button", "resource-display", "buyables", "clickables"),
	unlocked = function(this)
	do return hasUpgrade(nil, "mp", 13) end
end
}, {"content", "unlocked"}),
	Scalings = JS.O({
	content = JS.A(1, JS.A(2, "display-text", function(this)
	local base = player.mp.buyables[22]
	local x = player.mp.buyables[22]
	local table_ = "<h2>Scaling Levels</h2><br><div style='width:100%'>"
	if base:gte(tmp.mp.buyables[22].scaled) then
		table_ = (JS.str(table_) .. ("<button class='scale' style=\"text-align:center\"><h3>[ Scaled ]</h3><br><span style='font-size:12px'>Starts at " .. JS.str(formatScale(nil, tmp.mp.buyables[22].scaled, 2)) .. " Essence Fusioner level<br> Power: ^" .. JS.str(format(nil, (JS.D(0.75)):add(x:add(1):sub(tmp.mp.buyables[22].scaled):div(15):mul((if hasUpgrade(nil, "cp", 13) then (JS.D(1)):sub(upgradeEffect(nil, "cp", 13)) else 1))))) .. "</span></button>"))
	end
	if base:gte(tmp.mp.buyables[22].ultraScaled) then
		table_ = (JS.str(table_) .. ("<button style=\"text-align:center\" class='scale'><h3>[ Ultra Scaled ]</h3><br><span style='font-size:12px'>Starts at " .. JS.str(formatScale(nil, tmp.mp.buyables[22].ultraScaled, 2)) .. " Essence Fusioner level<br> Power: ^" .. JS.str(format(nil, (JS.D(1)):add(x:add(1):sub(tmp.mp.buyables[22].ultraScaled):div(10)))) .. "</span></button>"))
	end
	do return (JS.str(table_) .. "</div>") end
end)),
	unlocked = function(this)
	do return player.mp.buyables[22]:gte(tmp.mp.buyables[22].scaled) end
end
}, {"content", "unlocked"})
}, {"Main", "Upgrades", "Fusioners", "Scalings"}),
	branches = function(this)
	if (JS.eq(player.mp.activeChallenge, 21) and JS.isnil(player.pm.activeChallenge)) then
		do return JS.A(2, "ep", "pm") end
	end
	do return JS.A(1, "ep") end
end,
	passiveGeneration = function(this)
	do return 0 end
end,
	softcap = function(this)
	do return JS.D(math.huge) end
end,
	softcapPower = function(this)
	do return JS.D(1) end
end,
	doReset = function(this, l)
	if (l == "mp") then
		layerDataReset(nil, "pp", JS.A(1, "upgrades"))
		layerDataReset(nil, "p", JS.A(1, "upgrades"))
		if (not hasMalware(nil, "m", 15)) then
			layerDataReset(nil, "sp", JS.A(1, "upgrades"))
		end
		layerDataReset(nil, "pe", JS.A(1, "upgrades"))
		layerDataReset(nil, "hp", JS.A(1, "upgrades"))
		layerDataReset(nil, "ap", JS.A(2, "upgrades", "challenges"))
		layerDataReset(nil, "pb", JS.A(1, "upgrades"))
		layerDataReset(nil, "hb", JS.A(1, "upgrades"))
		layerDataReset(nil, "se", JS.A(1, "upgrades"))
		if hasMalware(nil, "m", 6) then
			layerDataReset(nil, "ep", JS.A(2, "buyables", "upgrades"))
		else
			layerDataReset(nil, "ep", JS.A(1, "buyables"))
		end
	end
end,
	update = function(this, diff)
	if player.m.best:gte(120) then
		if JS.t(player.mp.activeChallenge) then
			JS.set(player.mp.challenges, JS.k(player.mp.activeChallenge), Math.max(player.mp.challenges[JS.k(player.mp.activeChallenge)], layers.mp.challenges[JS.k(player.mp.activeChallenge)]:completionsAfter120()))
		end
	end
	if hasMalware(nil, "m", 3) then
		if player.ep.points:gte(tmp.mp.challenges[11].goal) then
			JS.set(player.mp.challenges, 11, Math.max(player.mp.challenges[11], layers.mp.challenges[11]:completionsAfter120()))
		end
		if player.ep.points:gte(tmp.mp.challenges[12].goal) then
			JS.set(player.mp.challenges, 12, Math.max(player.mp.challenges[12], layers.mp.challenges[12]:completionsAfter120()))
		end
		if player.ep.points:gte(tmp.mp.challenges[13].goal) then
			JS.set(player.mp.challenges, 13, Math.max(player.mp.challenges[13], layers.mp.challenges[13]:completionsAfter120()))
		end
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "newRow", "exponent", "hotkeys", "layerShown", "upgrades", "challenges", "buyables", "clickables", "tabFormat", "branches", "passiveGeneration", "softcap", "softcapPower", "doReset", "update"}))

end
