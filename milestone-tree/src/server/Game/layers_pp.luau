--!nocheck
-- transpiled from layers/pp.js by port/build.js: do not edit
return function()
-- transpiled from layers/pp.js
addLayer(nil, "pp", JS.O({
	name = "prestige power",
	symbol = "PP",
	position = 3,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0),
		power = JS.D(0)
	}, {"unlocked", "points", "power"}) end
end,
	color = "#652021",
	requires = function(this)
	do return JS.D("e7e13") end
end,
	softcap = JS.D("e28000000"),
	softcapPower = function(this)
	do return JS.D(0.015) end
end,
	resource = "prestige power",
	baseResource = function(this)
	if hasMalware(nil, "m", 4) then
		do return "<span style='color:red'>infected</span> prestige points" end
	end
	do return "prestige points" end
end,
	baseAmount = function(this)
	do return player.p.points end
end,
	type = "normal",
	gainMult = function(this)
	mult = JS.D(1)
	if hasUpgrade(nil, this.layer, 32) then
		mult = mult:mul(upgradeEffect(nil, this.layer, 32))
	end
	if hasUpgrade(nil, "mp", 11) then
		mult = mult:mul(upgradeEffect(nil, "mp", 11))
	end
	do return mult end
end,
	gainExp = function(this)
	local m = JS.D(1)
	do return m end
end,
	row = 2,
	exponent = 1e-14,
	hotkeys = JS.A(1, JS.O({
	key = "W",
	description = "W: Reset for prestige power",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(151) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	upgrades = JS.O({
	rows = 4,
	cols = 4,
	[11] = JS.O({
	title = "Prestige Power Softcap Delayer I",
	description = "First Milestone's softcap starts later by your prestige power strength.",
	cost = JS.D(23),
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp",
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 0.51
	if hasUpgrade(nil, "pp", 23) then
		base = JS.add(base, 0.15)
	end
	local ret = Decimal.mul(base, Decimal.log10(player[JS.k(this.layer)].power:add(1)):pow(0.5):add(1))
	do return softcap(nil, ret, JS.D(1.05), 0.1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "currencyDisplayName", "currencyInternalName", "currencyLayer", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Prestige Power Prestige Upgrade 11 Boost I",
	description = "Prestige Upgrade 11 is boosted by your prestige power strength.",
	cost = JS.D(1600),
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp",
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 0.3
	local ret = Decimal.mul(base, Decimal.log10(player[JS.k(this.layer)].power:add(1)):pow(0.5):add(1)):add(0.1):max(1)
	ret = softcap(nil, ret, (JS.D(1.25)):add((if (JS.tonum(player.mp.challenges[13]) > 0) then challengeEffect(nil, "mp", 13) else 0)), JS.D(0.001))
	if hasMalware(nil, "m", 3) then
		ret = ret:add(milestoneEffect(nil, "m", 3))
	end
	do return ret end
end,
	effectDisplay = function(this)
	do return ("^" .. JS.str(format(nil, this:effect(), 4))) end
end
}, {"title", "description", "cost", "currencyDisplayName", "currencyInternalName", "currencyLayer", "unlocked", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Prestige Power Prestige Buyable 2 Boost I",
	description = "Prestige Softcap Delayer effect is boosted by your prestige power strength.",
	cost = JS.D(10000),
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp",
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 1.05
	local effAfter1000 = player.pp.points:max(1):slog(10):max(1):pow(6)
	if hasUpgrade(nil, "pp", 31) then
		base = JS.add(base, 0.15)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].power:add(1)):add(1))
	ret = softcap(nil, ret, JS.D(3), JS.D(0.001))
	ret = softcap(nil, ret, JS.D(4.5), JS.D(0.001))
	ret = ret:min(1000)
	if ret:gte(1000) then
		ret = ret:add(effAfter1000)
	end
	do return ret end
end,
	effectDisplay = function(this)
	do return ("x" .. JS.str(format(nil, this:effect()))) end
end
}, {"title", "description", "cost", "currencyDisplayName", "currencyInternalName", "currencyLayer", "unlocked", "effect", "effectDisplay"}),
	[21] = JS.O({
	unlocked = function(this)
	do return player.m.best:gte(155) end
end,
	title = "Transcend Special Points Unlock I",
	description = "Unlock Super-Dilated Transcend Points effect.",
	cost = JS.D(100000),
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp"
}, {"unlocked", "title", "description", "cost", "currencyDisplayName", "currencyInternalName", "currencyLayer"}),
	[22] = JS.O({
	unlocked = function(this)
	do return player.m.best:gte(155) end
end,
	title = "Transcend Special Points Unlock II",
	description = "Unlock Prestige-Hardcapped Transcend Points effect.<br>Req: Power Scaler -<br> [11 Lvl]",
	cost = JS.D(3600000),
	canAfford = function(this)
	do return (player.pp.buyables[11]:gte(11) and player.pp.power:gte(3600000)) end
end,
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp"
}, {"unlocked", "title", "description", "cost", "canAfford", "currencyDisplayName", "currencyInternalName", "currencyLayer"}),
	[23] = JS.O({
	unlocked = function(this)
	do return player.m.best:gte(155) end
end,
	title = "Prestige Power Upgrade 11 Boost I",
	description = "Prestige Power 11 upgrade is better.<br>Req: Power Scaler -<br> [12 Lvl]",
	cost = JS.D(50000000),
	canAfford = function(this)
	do return (player.pp.buyables[11]:gte(12) and player.pp.power:gte(20000000)) end
end,
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp"
}, {"unlocked", "title", "description", "cost", "canAfford", "currencyDisplayName", "currencyInternalName", "currencyLayer"}),
	[31] = JS.O({
	unlocked = function(this)
	do return player.m.best:gte(159) end
end,
	title = "Prestige Power Upgrade 13 Boost I",
	description = "Prestige Power 13 upgrade is better.<br>Req: Power Scaler - [17 Lvl]",
	cost = JS.D(10000000000),
	canAfford = function(this)
	do return (player.pp.buyables[11]:gte(17) and player.pp.power:gte(10000000000)) end
end,
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp"
}, {"unlocked", "title", "description", "cost", "canAfford", "currencyDisplayName", "currencyInternalName", "currencyLayer"}),
	[32] = JS.O({
	unlocked = function(this)
	do return player.m.best:gte(159) end
end,
	title = "Prestige Power Exotic Prestige Boost I",
	description = "Exotic Prestige Points boosts Prestige Power gain.<br>Req: Power Scaler - [35 Lvl]",
	cost = JS.D(1e21),
	canAfford = function(this)
	do return (player.pp.buyables[11]:gte(35) and player.pp.power:gte(1e21)) end
end,
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp",
	effect = function(this)
	local ret = player.ep.points:add(1):pow((if hasUpgrade(nil, "pp", 33) then 0.8 else 0.75)):mul(1.5):add(1)
	ret = softcap(nil, ret, JS.D("1e800"), 0.1)
	ret = softcap(nil, ret, JS.D("1e20000"), 0.1)
	do return softcap(nil, ret, JS.D("ee10"), 0.0000067) end
end,
	effectDisplay = function(this)
	do return ("x" .. JS.str(format(nil, this:effect()))) end
end
}, {"unlocked", "title", "description", "cost", "canAfford", "currencyDisplayName", "currencyInternalName", "currencyLayer", "effect", "effectDisplay"}),
	[33] = JS.O({
	unlocked = function(this)
	do return player.m.best:gte(159) end
end,
	title = "Prestige Power Upgrade 32 Boost I",
	description = "Prestige Power upgrade 32 is better.",
	cost = JS.D("1e1910"),
	currencyDisplayName = "Hz of Prestige Power",
	currencyInternalName = "power",
	currencyLayer = "pp"
}, {"unlocked", "title", "description", "cost", "currencyDisplayName", "currencyInternalName", "currencyLayer"})
}, {"rows", "cols"}),
	buyables = JS.O({
	rows = 1,
	cols = 1,
	[11] = JS.O({
	title = function(this)
	do return "<h3 class='ps'>Power Scaler</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Strenghens Prestige Power by ") .. JS.str(format(nil, data.effect))) .. " Hz/s (based on milestones)<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Prestige power") end
end,
	cost = function(this, x)
	do return Decimal.pow(2, x:pow(1.03)) end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.setk(player.pp, "points", player.pp.points:sub(this:cost()))
	setBuyableAmount(nil, this.layer, this.id, getBuyableAmount(nil, this.layer, this.id):add(1))
end,
	effect = function(this)
	local b = 0.23
	local eff = (JS.D(0)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b):mul(player.m.points:pow(0.15))):mul(2)
	if hasUpgrade(nil, "ep", 14) then
		eff = player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(player.m.points:pow(0.35)):pow(player[JS.k(this.layer)].buyables[JS.k(this.id)]:pow(0.75))
	end
	if player.m.best:gte(154) then
		eff = eff:times(tmp.m.milestone154Effect)
	end
	if player.m.best:gte(163) then
		eff = eff:pow(1.5)
	end
	if player.m.best:gte(164) then
		eff = eff:pow(1.5)
	end
	eff = softcap(nil, eff, JS.D("e10000000"), 0.1)
	eff = softcap(nil, eff, JS.D("e13000000"), 0.1)
	do return softcap(nil, eff, JS.D("e20000000"), 0.1) end
end,
	unlocked = function(this)
	do return player.m.best:gte(123) end
end,
	style = function(this)
	if player.pp.points:lt(this:cost()) then
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
}, {"rows", "cols"}),
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(6, "main-display", "prestige-button", "resource-display", JS.A(2, "display-text", function(this)
	do return (("Your Prestige Power is " .. JS.str(format(nil, player.pp.power))) .. " Hz powerful") end
end), "buyables", "upgrades")
})
}),
	branches = JS.A(1, "p"),
	passiveGeneration = function(this)
	if player.em.best:gte(5) then
		do return 100 end
	end
	if player.em.best:gte(4) then
		do return 1 end
	end
	if player.m.best:gte(157) then
		do return 0.3 end
	end
	if player.em.best:gte(3) then
		do return 0.1 end
	end
	do return 0 end
end,
	doReset = function(this, l)
	if (l == "pp") then
		if player.m.best:gte(153) then
			layerDataReset(nil, "p", JS.A(2, "upgrades", JS.A(1, 4)))
		else
			layerDataReset(nil, "p", JS.A(0))
		end
	end
end,
	update = function(this, diff)
	local a = player.pp.buyables[11]
	x = JS.D(a:add(1):log(2))
	if player.pp.buyables[11]:gte(1) then
		JS.setk(player.pp, "power", player.pp.power:add(buyableEffect(nil, "pp", 11):times(diff)))
	end
	if player.m.best:gte(162) then
		JS.set(player.pp.buyables, 11, player.pp.points:add(1):log(2):pow((1 / 1.03)):add(1):floor())
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "softcap", "softcapPower", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "exponent", "hotkeys", "layerShown", "upgrades", "buyables", "tabFormat", "branches", "passiveGeneration", "doReset", "update"}))

end
