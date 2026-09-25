--!nocheck
-- transpiled from layers/p.js by port/build.js: do not edit
return function()
-- transpiled from layers/p.js
addLayer(nil, "p", JS.O({
	name = "prestige",
	symbol = "P",
	position = 1,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0),
		perkUpgs = JS.A(0),
		perks = JS.D(0),
		maxPerks = JS.D(0),
		totalPerks = JS.D(0),
		spentPerks = JS.D(0)
	}, {"unlocked", "points", "perkUpgs", "perks", "maxPerks", "totalPerks", "spentPerks"}) end
end,
	color = function(this)
	if hasMalware(nil, "m", 4) then
		do return "#c25757" end
	end
	do return "#658091" end
end,
	requires = function(this)
	do return JS.D(3000) end
end,
	resource = function(this)
	if hasMalware(nil, "m", 4) then
		do return "<span style='color:red'>infected</span> prestige points" end
	end
	do return "prestige points" end
end,
	baseResource = "points",
	baseAmount = function(this)
	do return player.points end
end,
	type = "normal",
	gainMult = function(this)
	mult = JS.D(1)
	if (JS.eq(player.ap.activeChallenge, 31) or JS.eq(player.ap.activeChallenge, 41)) then
		do return JS.D(0) end
	end
	if player.m.best:gte(6) then
		mult = mult:mul(tmp.m.milestone6Effect)
	end
	if hasUpgrade(nil, "p", 13) then
		mult = mult:mul(upgradeEffect(nil, "p", 13))
	end
	if hasUpgrade(nil, "p", 14) then
		mult = mult:mul(upgradeEffect(nil, "p", 14))
	end
	if player.m.best:gte(22) then
		mult = mult:mul(22)
	end
	if hasAchievement(nil, "ach", 15) then
		mult = mult:mul(achievementEffect(nil, "ach", 15))
	end
	if hasUpgrade(nil, "sp", 13) then
		mult = mult:mul(upgradeEffect(nil, "sp", 13))
	end
	if hasUpgrade(nil, "sp", 14) then
		mult = mult:mul(upgradeEffect(nil, "sp", 14))
	end
	if hasUpgrade(nil, "hp", 13) then
		mult = mult:mul(upgradeEffect(nil, "hp", 13))
	end
	if hasUpgrade(nil, "hp", 14) then
		mult = mult:mul(upgradeEffect(nil, "hp", 14))
	end
	if hasUpgrade(nil, "ap", 12) then
		mult = mult:mul(upgradeEffect(nil, "ap", 12))
	end
	mult = mult:mul(tmp.sp.buyables[11].effect)
	mult = mult:mul(tmp.hp.buyables[11].effect)
	if hasMalware(nil, "m", 8) then
		mult = mult:mul(tmp.m.milestone3Effect:pow(0.1))
	end
	if JS.eq(player.sp.activeChallenge, 11) then
		mult = mult:max(1):slog(1.15):add(1)
	end
	do return mult end
end,
	perkCost = function(this)
	local eff = (if JS.eq(player.sp.activeChallenge, 11) then JS.D(1e200) else JS.D(("e2e23")))
	local base = player.p.totalPerks:mul(5):max(1):mul(player.p.totalPerks:sub(3):add(1)):mul(player.p.totalPerks:sub(4):mul(10):max(1))
	if JS.eq(player.sp.activeChallenge, 11) then
		base = (if player.p.totalPerks:lt(1) then 1 else player.p.totalPerks:div(1.75):add(1))
	end
	eff = Decimal.pow(eff, base)
	do return eff end
end,
	gainExp = function(this)
	local m = layers.pb:effect()
	if hasUpgrade(nil, "t", 12) then
		m = m:mul(1.005)
	end
	if hasUpgrade(nil, "t", 32) then
		m = m:mul(1.005)
	end
	if (JS.eq(player.t.activeChallenge, 21) or JS.eq(player.t.activeChallenge, 31)) then
		m = m:mul(tmp.t.dilationEffect)
	end
	m = m:mul(layers.t:getSpecialEffect(21))
	do return m end
end,
	effectDescription = function(this)
	if hasMalware(nil, "m", 4) then
		do return (((((("You have " .. JS.str(format(nil, player.p.perks:sub(player.p.spentPerks)))) .. " / ") .. JS.str(format(nil, player.p.maxPerks))) .. " Upgrade Perks (Next at ") .. JS.str(format(nil, tmp.p.perkCost))) .. " Prestige Points).<br>") end
	end
end,
	row = 1,
	exponent = 0.5,
	hotkeys = JS.A(1, JS.O({
	key = "p",
	description = "P: Reset for prestige points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(5) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	clickables = JS.O({
	[11] = JS.O({
	unlocked = function(this)
	do return hasMalware(nil, "m", 4) end
end,
	title = function(this)
	do return "Respec Perk Upgrades" end
end,
	canClick = function(this)
	do return true end
end,
	onClick = function(this)
	JS.setk(player, "points", JS.D(0))
	local _ = tmp.t.doReset
	local _ = tmp.mp.doReset
	layerDataReset(nil, "se", JS.A(1, "upgrades"))
	layerDataReset(nil, "pe", JS.A(1, "upgrades"))
	layerDataReset(nil, "hb", JS.A(1, "upgrades"))
	layerDataReset(nil, "pb", JS.A(1, "upgrades"))
	layerDataReset(nil, "sp", JS.A(1, "upgrades"))
	layerDataReset(nil, "hp", JS.A(1, "upgrades"))
	layerDataReset(nil, "ap", JS.A(3, "upgrades", "challenges", "buyables"))
	layerDataReset(nil, "pp", JS.A(1, "upgrades"))
	layerDataReset(nil, "t", JS.A(2, "challenges", "upgrades"))
	layerDataReset(nil, "ep", JS.A(0))
	layerDataReset(nil, "p", JS.A(0))
	JS.setk(player.mp, "perkPoints", player.mp.buyables[13])
	JS.m(player.p.upgrades, "push", "11", "12", "13", "14", "21", "22", "23", "24", "31", "32", "33", "34", "41", "42", "43", "44")
end,
	style = function(this)
	do return JS.O({
		width = "100px",
		["min-height"] = "60px"
	}, {"width", "min-height"}) end
end
}, {"unlocked", "title", "canClick", "onClick", "style"})
}),
	upgrades = JS.O({
	rows = 6,
	cols = 6,
	[11] = JS.O({
	title = "Prestige Boost I",
	description = "First Milestone's effect is boosted by your prestige points.",
	cost = JS.D(1),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 3
	if player.m.best:gte(11) then
		base = JS.add(base, 0.5)
	end
	if player.m.best:gte(31) then
		base = JS.add(base, 0.5)
	end
	if player.m.best:gte(44) then
		base = JS.add(base, 0.2)
	end
	if player.m.best:gte(54) then
		base = JS.add(base, 0.3)
	end
	if player.m.best:gte(64) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(74) then
		base = JS.add(base, 0.244)
	end
	if player.m.best:gte(84) then
		base = JS.add(base, 0.156)
	end
	if player.m.best:gte(94) then
		base = JS.add(base, 0.1)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	if (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13)) then
		ret = ret:add(1):pow(0.85)
	end
	ret = softcap(nil, ret, JS.D("e5e16"), 0.1)
	do return softcap(nil, ret, JS.D("e5e24"), 0.01) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Prestige Boost II",
	description = "First Milestone's effect is boosted by your prestige points.",
	cost = JS.D(4),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 2
	if player.m.best:gte(12) then
		base = JS.add(base, 0.4)
	end
	if player.m.best:gte(32) then
		base = JS.add(base, 0.2)
	end
	if player.m.best:gte(44) then
		base = JS.add(base, 0.2)
	end
	if player.m.best:gte(54) then
		base = JS.add(base, 0.2)
	end
	if player.m.best:gte(64) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(74) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(84) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(94) then
		base = JS.add(base, 0.1)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	if hasUpgrade(nil, "pp", 12) then
		ret = ret:pow(upgradeEffect(nil, "pp", 12))
	end
	if (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13)) then
		ret = ret:add(1):pow(0.95)
	end
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Prestige Self-Synergy II",
	description = "Prestige Point gain is boosted by your prestige points.",
	cost = JS.D(100000000),
	unlocked = function(this)
	do return player.m.best:gte(10) end
end,
	effect = function(this)
	local base = 1.4
	if player.m.best:gte(13) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(33) then
		base = JS.add(base, 0.05)
	end
	if player.m.best:gte(44) then
		base = JS.add(base, 0.05)
	end
	if player.m.best:gte(54) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(64) then
		base = JS.add(base, 0.05)
	end
	if player.m.best:gte(74) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(84) then
		base = JS.add(base, 0.05)
	end
	if player.m.best:gte(94) then
		base = JS.add(base, 0.05)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	if hasUpgrade(nil, "p", 35) then
		ret = ret:mul(upgradeEffect(nil, "p", 35))
	end
	ret = softcap(nil, ret, JS.D("e1e15"), 0.1)
	do return softcap(nil, ret, JS.D("e1e25"), 0.001) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[14] = JS.O({
	title = "Prestige Self-Synergy II",
	description = "Prestige Point gain is boosted by your prestige points.",
	cost = JS.D(100000000000),
	unlocked = function(this)
	do return player.m.best:gte(10) end
end,
	effect = function(this)
	local base = 1.2
	if player.m.best:gte(14) then
		base = JS.add(base, 0.05)
	end
	if player.m.best:gte(34) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(44) then
		base = JS.add(base, 0.05)
	end
	if player.m.best:gte(54) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(64) then
		base = JS.add(base, 0.05)
	end
	if player.m.best:gte(74) then
		base = JS.add(base, 0.1)
	end
	if player.m.best:gte(84) then
		base = JS.add(base, 0.05)
	end
	if player.m.best:gte(94) then
		base = JS.add(base, 0.05)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return softcap(nil, ret, JS.D("e5e14"), 0.1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[15] = JS.O({
	title = "Prestige Boost II",
	description = "First Milestone's effect is boosted by your prestige points.",
	cost = JS.D(("e3.85e24")),
	canAfford = function(this)
	do return ((player.p.spentPerks:lt(player.p.maxPerks) and player.p.points:gte(this.cost)) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	pay = function(this)
	JS.setk(player.p, "spentPerks", player.p.spentPerks:add(1))
	JS.setk(player.p, "points", player.p.points:sub(("e3.85e24")))
end,
	unlocked = function(this)
	do return JS.m(player[JS.k(this.layer)].perkUpgs, "includes", Number(nil, this.id)) end
end,
	effect = function(this)
	local base = 7
	if hasMalware(nil, "m", 13) then
		base = JS.add(base, 10)
	end
	if JS.eq(player.ap.activeChallenge, 42) then
		do return Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):add(1):pow(("1e-10")):pow(0.9):add(1)) end
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return softcap(nil, ret, JS.D("e5e16"), 0.1) end
end,
	perkReq = function(this)
	do return (("To get this perk upgrade, get " .. JS.str(format(nil, this.perkCost))) .. " points in AP Challenge 6.") end
end,
	perkCan = function(this)
	do return (player.points:gte(("e2.715e20")) and JS.eq(player.ap.activeChallenge, 32)) end
end,
	perkUnl = function(this)
	do return hasMalware(nil, "m", 4) end
end,
	perkCost = JS.D(("e2.715e20")),
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "canAfford", "pay", "unlocked", "effect", "perkReq", "perkCan", "perkUnl", "perkCost", "effectDisplay"}),
	[21] = JS.O({
	title = "Exponental Boost I",
	description = "6th Milestone's effect ^1.5",
	cost = JS.D(1e25),
	unlocked = function(this)
	do return player.m.best:gte(15) end
end
}, {"title", "description", "cost", "unlocked"}),
	[22] = JS.O({
	title = "Exponental Boost II",
	description = "6th Milestone's effect ^1.5",
	cost = JS.D(1e33),
	unlocked = function(this)
	do return player.m.best:gte(15) end
end
}, {"title", "description", "cost", "unlocked"}),
	[23] = JS.O({
	title = "Prestige Boost III",
	description = "Third Milestone's effect is boosted by your prestige points.",
	cost = function(this)
	if inChallenge(nil, "pm", 13) then
		do return JS.D(1e57) end
	else
		do return JS.D(1e63) end
	end
end,
	unlocked = function(this)
	do return player.m.best:gte(21) end
end
}, {"title", "description", "cost", "unlocked"}),
	[24] = JS.O({
	title = "Prestige Boost IV",
	description = "Third Milestone's effect is boosted by your prestige points.",
	cost = JS.D(1e80),
	unlocked = function(this)
	do return player.m.best:gte(21) end
end
}, {"title", "description", "cost", "unlocked"}),
	[25] = JS.O({
	title = "Exponential Boost III",
	description = "6th Milestone's effect is better based on your prestige points.",
	cost = JS.D(("e1.31e24")),
	canAfford = function(this)
	do return ((player.p.spentPerks:lt(player.p.maxPerks) and player.p.points:gte(this.cost)) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	pay = function(this)
	JS.setk(player.p, "spentPerks", player.p.spentPerks:add(1))
	JS.setk(player.p, "points", player.p.points:sub(("e1.31e24")))
end,
	effect = function(this)
	local extra = 0
	if hasMalware(nil, "m", 12) then
		extra = JS.add(extra, 0.35)
	end
	local p = player.p.points:add(1):log10():add(1):log10():add(1):pow(0.25)
	do return p:add(1):add(extra) end
end,
	effectDisplay = function(this)
	do return ("^" .. JS.str(format(nil, this:effect(), 4))) end
end,
	unlocked = function(this)
	do return JS.m(player[JS.k(this.layer)].perkUpgs, "includes", Number(nil, this.id)) end
end,
	perkReq = function(this)
	do return (("To get this perk upgrade, get " .. JS.str(format(nil, this.perkCost))) .. " points in AP Challenge 3.") end
end,
	perkCan = function(this)
	do return (player.points:gte(("e5.765e21")) and JS.eq(player.ap.activeChallenge, 21)) end
end,
	perkUnl = function(this)
	do return hasMalware(nil, "m", 4) end
end,
	perkCost = JS.D(("e5.765e21"))
}, {"title", "description", "cost", "canAfford", "pay", "effect", "effectDisplay", "unlocked", "perkReq", "perkCan", "perkUnl", "perkCost"}),
	[31] = JS.O({
	title = "Prestige Scaling Reducer I",
	description = "Milestone Cost Scaling is weaker based on your prestige points.",
	cost = JS.D("1e6810"),
	effect = function(this)
	local p = player.p.points:add(100000000000000000000):log10():log10():div(77)
	if hasUpgrade(nil, "p", 32) then
		p = p:mul(2)
	end
	if hasUpgrade(nil, "p", 33) then
		p = p:mul(1.5)
	end
	if hasUpgrade(nil, "p", 34) then
		p = p:mul(1.2)
	end
	if hasUpgrade(nil, "t", 21) then
		p = p:mul(1.1)
	end
	if hasAchievement(nil, "ach", 22) then
		p = p:add(achievementEffect(nil, "ach", 22))
	end
	do return p:add(1) end
end,
	unlocked = function(this)
	do return player.m.best:gte(45) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x weaker") end
end
}, {"title", "description", "cost", "effect", "unlocked", "effectDisplay"}),
	[32] = JS.O({
	title = "Prestige Scaling Reducer II",
	description = "Prestige Upgrade 31 is boosted.",
	cost = JS.D("1e8740"),
	unlocked = function(this)
	do return player.m.best:gte(45) end
end
}, {"title", "description", "cost", "unlocked"}),
	[33] = JS.O({
	title = "Prestige Scaling Reducer III",
	description = "Prestige Upgrade 31 is boosted.",
	cost = JS.D("1e10927"),
	unlocked = function(this)
	do return player.m.best:gte(45) end
end
}, {"title", "description", "cost", "unlocked"}),
	[34] = JS.O({
	title = "Prestige Scaling Reducer IV",
	description = "Prestige Upgrade 31 is boosted.",
	cost = JS.D("1e16335"),
	unlocked = function(this)
	do return player.m.best:gte(45) end
end
}, {"title", "description", "cost", "unlocked"}),
	[35] = JS.O({
	title = "Prestige Upgrade 13 Boost I",
	description = "Prestige Upgrade 13 is boosted by prestige-points.",
	cost = JS.D(("e3.84e23")),
	unlocked = function(this)
	do return JS.m(player[JS.k(this.layer)].perkUpgs, "includes", Number(nil, this.id)) end
end,
	perkReq = function(this)
	do return (("To get this perk upgrade, get " .. JS.str(format(nil, this.perkCost))) .. " Exotic Prestige.") end
end,
	canAfford = function(this)
	do return ((player.p.spentPerks:lt(player.p.maxPerks) and player.p.points:gte(this.cost)) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	pay = function(this)
	JS.setk(player.p, "spentPerks", player.p.spentPerks:add(1))
	JS.setk(player.p, "points", player.p.points:sub(("e3.84e23")))
end,
	effect = function(this)
	local base = 0.5
	if hasMalware(nil, "m", 10) then
		base = JS.add(base, 0.075)
	end
	local p = player.p.points:pow(0.015):pow(base)
	do return p:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x") end
end,
	perkCan = function(this)
	do return player.ep.points:gte(("e4.02e8")) end
end,
	perkUnl = function(this)
	do return hasMalware(nil, "m", 4) end
end,
	perkCost = JS.D(("e4.02e8"))
}, {"title", "description", "cost", "unlocked", "perkReq", "canAfford", "pay", "effect", "effectDisplay", "perkCan", "perkUnl", "perkCost"}),
	[41] = JS.O({
	title = "Prestige Boost V",
	description = "Same as Prestige Upgrade 23. To buy this upgrade, You need to complete AP challenge 4 19.7 times.",
	cost = function(this)
	if (JS.tonum(player.ap.challenges[22]) < 19.7) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e185e9") end
end,
	unlocked = function(this)
	do return player.m.best:gte(124) end
end
}, {"title", "description", "cost", "unlocked"}),
	[42] = JS.O({
	title = "Prestige Boost VI",
	description = "Same as Prestige Upgrade 23. To buy this upgrade, You need to complete AP challenge 3 14.1 times.",
	cost = function(this)
	if (JS.tonum(player.ap.challenges[21]) < 14.1) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e210e9") end
end,
	unlocked = function(this)
	do return player.m.best:gte(124) end
end
}, {"title", "description", "cost", "unlocked"}),
	[43] = JS.O({
	title = "Prestige Buyable Boost I",
	description = "First Prestige buyable is boosted. You can buy this upgrade while you're in T challenge 2.",
	cost = function(this)
	if (not JS.eq(player.t.activeChallenge, 12)) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e188e6") end
end,
	unlocked = function(this)
	do return player.m.best:gte(124) end
end
}, {"title", "description", "cost", "unlocked"}),
	[44] = JS.O({
	title = "Prestige Buyable Boost II",
	description = "First Prestige buyable is boosted. You can buy this upgrade while you're in T challenge 4.",
	cost = function(this)
	if (not JS.eq(player.t.activeChallenge, 22)) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e501000") end
end,
	unlocked = function(this)
	do return player.m.best:gte(124) end
end,
	currencyDisplayName = function(this)
	do return "points" end
end,
	currencyInternalName = function(this)
	do return "points" end
end
}, {"title", "description", "cost", "unlocked", "currencyDisplayName", "currencyInternalName"}),
	[45] = JS.O({
	title = "Prestige Upgrade 5th Fusioner Boost I",
	description = "5th Exotic Fusioner effect is better based on prestige points.",
	cost = JS.D(("e5.125e23")),
	unlocked = function(this)
	do return JS.m(player[JS.k(this.layer)].perkUpgs, "includes", Number(nil, this.id)) end
end,
	perkReq = function(this)
	do return (("To get this perk upgrade, get " .. JS.str(format(nil, this.perkCost))) .. " points in Multiverse Challenge 3.") end
end,
	canAfford = function(this)
	do return ((player.p.spentPerks:lt(player.p.maxPerks) and player.p.points:gte(this.cost)) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	pay = function(this)
	JS.setk(player.p, "spentPerks", player.p.spentPerks:add(1))
	JS.setk(player.p, "points", player.p.points:sub(("e5.125e23")))
end,
	effect = function(this)
	local extra = 0
	if hasMalware(nil, "m", 11) then
		extra = JS.add(extra, 0.175)
	end
	local p = player.p.points:pow(0.015):add(1):log10():add(1):log10():pow(0.15):div(10):add(extra)
	do return p:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x") end
end,
	perkCan = function(this)
	do return (player.points:gte(("e2.68e19")) and JS.eq(player.mp.activeChallenge, 13)) end
end,
	perkUnl = function(this)
	do return hasMalware(nil, "m", 4) end
end,
	perkCost = JS.D(("e2.68e19"))
}, {"title", "description", "cost", "unlocked", "perkReq", "canAfford", "pay", "effect", "effectDisplay", "perkCan", "perkUnl", "perkCost"}),
	[51] = JS.O({
	title = "Alternate Prestige Boost I",
	description = "Boosts points gain after slog based on Prestige Boost I and points.",
	cost = JS.D(("1e200")),
	unlocked = function(this)
	do return JS.m(player[JS.k(this.layer)].perkUpgs, "includes", Number(nil, this.id)) end
end,
	perkReq = function(this)
	do return (("To get this perk upgrade, get " .. JS.str(format(nil, this.perkCost))) .. " points.") end
end,
	canAfford = function(this)
	do return ((player.p.spentPerks:lt(player.p.maxPerks) and player.p.points:gte(this.cost)) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	pay = function(this)
	JS.setk(player.p, "spentPerks", player.p.spentPerks:add(1))
	JS.setk(player.p, "points", player.p.points:sub(("3000")))
end,
	effect = function(this)
	local extra = player.points:max(1):log(10):div(1.5)
	local p = upgradeEffect(nil, "p", 11):slog(1.25):mul(extra)
	if hasMilestone(nil, "sp", 1) then
		p = p:mul(milestoneEffect(nil, "sp", 1))
	end
	do return p:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x") end
end,
	perkCan = function(this)
	do return player.points:gte(("3000")) end
end,
	perkUnl = function(this)
	do return JS.eq(player.sp.activeChallenge, 11) end
end,
	perkCost = JS.D(("3000"))
}, {"title", "description", "cost", "unlocked", "perkReq", "canAfford", "pay", "effect", "effectDisplay", "perkCan", "perkUnl", "perkCost"}),
	[52] = JS.O({
	title = "Prestige Exponent I",
	description = "Raises points gain based on current milestones amount.",
	cost = JS.D(("1e330")),
	unlocked = function(this)
	do return JS.m(player[JS.k(this.layer)].perkUpgs, "includes", Number(nil, this.id)) end
end,
	perkReq = function(this)
	do return (("To get this perk upgrade, get " .. JS.str(format(nil, this.perkCost))) .. " points.") end
end,
	canAfford = function(this)
	do return ((player.p.spentPerks:lt(player.p.maxPerks) and player.p.points:gte(this.cost)) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	pay = function(this)
	JS.setk(player.p, "spentPerks", player.p.spentPerks:add(1))
	JS.setk(player.p, "points", player.p.points:sub(("3333333")))
end,
	effect = function(this)
	local p = player.m.points:max(1):log(2):pow(0.2965)
	do return p end
end,
	effectDisplay = function(this)
	do return ("^" .. JS.str(format(nil, this:effect(), 4))) end
end,
	perkCan = function(this)
	do return player.points:gte(("3333333")) end
end,
	perkUnl = function(this)
	do return JS.eq(player.sp.activeChallenge, 11) end
end,
	perkCost = JS.D(("3333333"))
}, {"title", "description", "cost", "unlocked", "perkReq", "canAfford", "pay", "effect", "effectDisplay", "perkCan", "perkUnl", "perkCost"}),
	[53] = JS.O({
	title = "Milestone Exponent Weakener",
	description = "Reduces milestone exponent based on current milestones amount.",
	cost = JS.D(("1e430")),
	unlocked = function(this)
	do return JS.m(player[JS.k(this.layer)].perkUpgs, "includes", Number(nil, this.id)) end
end,
	perkReq = function(this)
	do return (("To get this perk upgrade, get " .. JS.str(format(nil, this.perkCost))) .. " points.") end
end,
	canAfford = function(this)
	do return ((player.p.spentPerks:lt(player.p.maxPerks) and player.p.points:gte(this.cost)) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	pay = function(this)
	JS.setk(player.p, "spentPerks", player.p.spentPerks:add(1))
	JS.setk(player.p, "points", player.p.points:sub(this.perkCost))
end,
	effect = function(this)
	local p = player.m.points:max(1):root(10):mul(player.m.points:max(1):log(8))
	p = softcap(nil, p, JS.D(1.25), JS.D(0.25))
	do return p end
end,
	effectDisplay = function(this)
	do return ("x" .. JS.str(format(nil, this:effect(), 4))) end
end,
	perkCan = function(this)
	do return player.points:gte(this.perkCost) end
end,
	perkUnl = function(this)
	do return JS.eq(player.sp.activeChallenge, 11) end
end,
	perkCost = JS.D(("2.5e8"))
}, {"title", "description", "cost", "unlocked", "perkReq", "canAfford", "pay", "effect", "effectDisplay", "perkCan", "perkUnl", "perkCost"})
}, {"rows", "cols"}),
	buyables = JS.O({
	rows = 1,
	cols = 3,
	[11] = JS.O({
	ifNotify = function(this)
	do return (not player.m.best:gte(124)) end
end,
	title = function(this)
	do return "<h3 class='pr'>Softcap Delayer</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "1st Milestone's softcap starts ") .. JS.str(format(nil, data.effect))) .. "x later<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Prestige points") end
end,
	cost = function(this)
	local a = player[JS.k(this.layer)].buyables[JS.k(this.id)]
	local cost = JS.D(1)
	a = Decimal.pow(2, a)
	do return cost:mul(Decimal.pow("ee10", a)) end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
end,
	effect = function(this)
	if (JS.eq(player.ap.activeChallenge, 32) or JS.eq(player.ap.activeChallenge, 41)) then
		do return JS.D(1) end
	end
	local b = 0.03
	if hasUpgrade(nil, "p", 43) then
		b = JS.add(b, 0.011)
	end
	if hasUpgrade(nil, "p", 44) then
		b = JS.add(b, 0.011)
	end
	local eff = (JS.D(1)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b))
	eff = eff:pow(tmp.ap.challenges[32].rewardEffect)
	if hasUpgrade(nil, "pp", 13) then
		eff = eff:mul(upgradeEffect(nil, "pp", 13))
	end
	do return softcap(nil, eff, JS.D(17), 0.25) end
end,
	unlocked = function(this)
	do return player.m.best:gte(123) end
end,
	style = function(this)
	if player.p.points:lt(this:cost()) then
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
}, {"ifNotify", "title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[12] = JS.O({
	ifNotify = function(this)
	do return (not player.m.best:gte(124)) end
end,
	title = function(this)
	do return "<h3 class='ef'>Exotic</h3> <h3 class='pr'>Booster</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Exotic Prestige Points gain ") .. JS.str(format(nil, data.effect))) .. "x better<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Prestige points") end
end,
	cost = function(this)
	local a = player[JS.k(this.layer)].buyables[JS.k(this.id)]:div((if hasUpgrade(nil, "ep", 13) then upgradeEffect(nil, "ep", 13) else 1))
	local cost = JS.D(1)
	a = Decimal.pow(2, a)
	do return cost:mul(Decimal.pow("e4.7e15", a)) end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
end,
	effect = function(this)
	local b = JS.D(5)
	if hasMalware(nil, "m", 0) then
		b = b:pow(milestoneEffect(nil, "m", 0))
	end
	local eff = (JS.D(1)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b):pow(1.05))
	if player.m.best:gte(179) then
		eff = eff:mul(tmp.m.milestone179Effect)
	end
	do return softcap(nil, eff, JS.D("ee10"), 0.001) end
end,
	unlocked = function(this)
	do return player.em.best:gte(7) end
end,
	style = function(this)
	if player.p.points:lt(this:cost()) then
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
}, {"ifNotify", "title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"})
}, {"rows", "cols"}),
	branches = function(this)
	if hasMalware(nil, "m", 4) then
		do return JS.A(1, JS.A(2, "m", "#c86a6a")) end
	else
		do return JS.A(1, "m") end
	end
end,
	passiveGeneration = function(this)
	if player.m.best:gte(135) then
		do return 10000000000 end
	end
	if player.m.best:gte(20) then
		do return 100 end
	end
	if (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13)) then
		do return 1 end
	end
	do return 0 end
end,
	resetsNothing = function(this)
	do return (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	softcap = function(this)
	if JS.eq(player.t.activeChallenge, 32) then
		do return getPointSoftcapStart(nil) end
	end
	do return JS.D(math.huge) end
end,
	softcapPower = function(this)
	if JS.eq(player.t.activeChallenge, 32) then
		do return JS.D(0) end
	end
	do return JS.D(1) end
end,
	doReset = function(this, l)
	if hasMalware(nil, "m", 4) then
		layerDataReset(nil, "p")
		JS.m(player.p.upgrades, "push", "11", "12", "13", "14", "21", "22", "23", "24", "31", "32", "33", "34", "41", "42", "43", "44")
	end
	if (l == "p") then
		do return end
	end
	if (l == "sp") then
		if player.m.best:gte(26) then
			layerDataReset(nil, "p", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "p", JS.A(0))
		end
	end
	if (l == "pb") then
		if player.m.best:gte(60) then
			layerDataReset(nil, "p", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "p", JS.A(0))
		end
	end
	if (l == "hp") then
		if player.m.best:gte(65) then
			layerDataReset(nil, "p", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "p", JS.A(0))
		end
	end
	if (l == "ap") then
		if player.m.best:gte(81) then
			layerDataReset(nil, "p", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "p", JS.A(0))
		end
	end
	if (l == "t") then
		if player.m.best:gte(100) then
			layerDataReset(nil, "p", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "p", JS.A(0))
		end
	end
	if (l == "hb") then
		if player.m.best:gte(104) then
			layerDataReset(nil, "p", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "p", JS.A(0))
		end
	end
end,
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(6, "main-display", "prestige-button", "resource-display", "buyables", "upgrades", "clickables")
})
}),
	update = function(this)
	local target
	if player.m.best:gte(124) then
		target = player.p.points:add(1):div(1):log("ee10"):max(0.1):log(2)
		target = target:add(1):floor()
		if target:gt(player.p.buyables[11]) then
			JS.set(player.p.buyables, 11, target)
		end
	end
	if (player.m.best:gte(124) and player.p.points:gte(layers.p.buyables[12]:cost())) then
		JS.set(player.p.buyables, 12, player.p.points:add(1):div(1):log("e4.7e15"):max(0.1):log(2):mul((if hasUpgrade(nil, "ep", 13) then upgradeEffect(nil, "ep", 13) else 1)):add(1):floor())
	end
	if hasMalware(nil, "m", 4) then
		JS.setk(player.p, "maxPerks", player.p.maxPerks:max(player.p.perks))
		if player.p.points:gte(tmp.p.perkCost) then
			JS.setk(player.p, "perks", player.p.perks:add(1))
			JS.setk(player.p, "totalPerks", player.p.totalPerks:add(1))
		end
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "perkCost", "gainExp", "effectDescription", "row", "exponent", "hotkeys", "layerShown", "clickables", "upgrades", "buyables", "branches", "passiveGeneration", "resetsNothing", "softcap", "softcapPower", "doReset", "tabFormat", "update"}))

end
