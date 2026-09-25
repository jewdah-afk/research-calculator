--!nocheck
-- transpiled from layers/hp.js by port/build.js: do not edit
return function()
-- transpiled from layers/hp.js
addLayer(nil, "hp", JS.O({
	name = "hyper-prestige",
	symbol = "HP",
	position = (-1),
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = "#80C0D0",
	requires = JS.D("1e13820"),
	resource = "hyper-prestige points",
	baseResource = "super-prestige points",
	baseAmount = function(this)
	do return player.sp.points end
end,
	type = "normal",
	gainMult = function(this)
	mult = JS.D(1)
	if hasUpgrade(nil, "hp", 22) then
		mult = mult:mul(upgradeEffect(nil, "hp", 22))
	end
	if hasUpgrade(nil, "ap", 14) then
		mult = mult:mul(upgradeEffect(nil, "ap", 14))
	end
	do return mult end
end,
	gainExp = function(this)
	mult = layers.hb:effect()
	if hasUpgrade(nil, "t", 14) then
		mult = mult:mul(1.005)
	end
	if hasUpgrade(nil, "t", 34) then
		mult = mult:mul(1.005)
	end
	if (player.ep.buyables[11]:gte(5) and player.hp.points:gte(tmp.ep.fiveEffect.start)) then
		mult = mult:pow(tmp.ep.fiveEffect.eff)
	end
	do return mult end
end,
	row = 3,
	exponent = 0.001,
	hotkeys = JS.A(1, JS.O({
	key = "h",
	description = "H: Reset for hyper-prestige points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(60) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	branches = JS.A(1, JS.A(2, "sp", 3)),
	softcap = JS.D(math.huge),
	softcapPower = JS.D(1),
	upgrades = JS.O({
	rows = 4,
	cols = 4,
	[11] = JS.O({
	title = "Hyper-Prestige Upgrade 11",
	description = "First Milestone's effect is boosted by your hyper-prestige points.",
	cost = JS.D(1),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 100000000000000000000
	if player.m.best:gte(69) then
		base = JS.add(base, 1e30)
	end
	if player.m.best:gte(79) then
		base = JS.add(base, 1e45)
	end
	if player.m.best:gte(89) then
		base = JS.add(base, 1e60)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Hyper-Prestige Upgrade 12",
	description = "First Milestone's effect is boosted by your hyper-prestige points.",
	cost = JS.D(2),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 10000000000
	if player.m.best:gte(69) then
		base = JS.add(base, 300000000000000000000)
	end
	if player.m.best:gte(79) then
		base = JS.add(base, 1e35)
	end
	if player.m.best:gte(89) then
		base = JS.add(base, 1e50)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Hyper-Prestige Upgrade 13",
	description = "Prestige Point gain is boosted by your hyper-prestige points.",
	cost = JS.D(3e38),
	unlocked = function(this)
	do return player.m.best:gte(65) end
end,
	effect = function(this)
	local base = 1000000000000000
	if player.m.best:gte(69) then
		base = JS.add(base, 100000000000000000000)
	end
	if player.m.best:gte(79) then
		base = JS.add(base, 1e30)
	end
	if player.m.best:gte(89) then
		base = JS.add(base, 1e40)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret:mul("1e450") end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[14] = JS.O({
	title = "Hyper-Prestige Upgrade 14",
	description = "Prestige Point gain is boosted by your hyper-prestige points.",
	cost = JS.D(1e93),
	unlocked = function(this)
	do return player.m.best:gte(65) end
end,
	effect = function(this)
	local base = 1000000000000
	if player.m.best:gte(69) then
		base = JS.add(base, 1000000000000000)
	end
	if player.m.best:gte(79) then
		base = JS.add(base, 1e25)
	end
	if player.m.best:gte(89) then
		base = JS.add(base, 1e30)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[21] = JS.O({
	title = "Hyper-Prestige Upgrade 21",
	description = "Super-Prestige Point gain is boosted by your hyper-prestige points.",
	cost = JS.D(1e160),
	unlocked = function(this)
	do return player.m.best:gte(70) end
end,
	effect = function(this)
	local base = 1000000000000000000
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret:mul("1e965") end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[22] = JS.O({
	title = "Hyper-Prestige Upgrade 22",
	description = "Super-Prestige Point and Hyper-Prestige Point gain is boosted by your hyper-prestige points.",
	cost = JS.D(1e173),
	unlocked = function(this)
	do return player.m.best:gte(70) end
end,
	effect = function(this)
	local base = 3
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret:mul("1e91") end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[23] = JS.O({
	title = "Hyper-Prestige Upgrade 23",
	description = "Milestone Cost Scaling is weaker based on your hyper-prestige points.",
	cost = JS.D("1e496"),
	unlocked = function(this)
	do return player.m.best:gte(70) end
end,
	effect = function(this)
	local p = player.hp.points:add(100000000000000000000):log10():log10():div(56.17)
	if hasUpgrade(nil, "hp", 24) then
		p = p:mul(2)
	end
	if hasUpgrade(nil, "hp", 33) then
		p = p:mul(1.5)
	end
	if hasUpgrade(nil, "hp", 34) then
		p = p:mul(1.2)
	end
	if hasAchievement(nil, "ach", 23) then
		p = p:add(achievementEffect(nil, "ach", 23))
	end
	do return p:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x weaker") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[24] = JS.O({
	title = "Hyper-Prestige Upgrade 24",
	description = "Hyper-Prestige Upgrade 23 is boosted.",
	cost = JS.D("1e751"),
	unlocked = function(this)
	do return player.m.best:gte(70) end
end
}, {"title", "description", "cost", "unlocked"}),
	[31] = JS.O({
	title = "Hyper-Prestige Upgrade 31",
	description = "The first Super-Prestige buyable's effect ^1.05",
	cost = JS.D("1e11540"),
	unlocked = function(this)
	do return player.m.best:gte(85) end
end
}, {"title", "description", "cost", "unlocked"}),
	[32] = JS.O({
	title = "Hyper-Prestige Upgrade 32",
	description = "The first Hyper-Prestige buyable's effect ^1.1",
	cost = JS.D("1e12800"),
	unlocked = function(this)
	do return player.m.best:gte(85) end
end
}, {"title", "description", "cost", "unlocked"}),
	[33] = JS.O({
	title = "Hyper-Prestige Upgrade 33",
	description = "Hyper-Prestige Upgrade 23 is boosted.",
	cost = JS.D("1e20000"),
	unlocked = function(this)
	do return player.m.best:gte(85) end
end
}, {"title", "description", "cost", "unlocked"}),
	[34] = JS.O({
	title = "Hyper-Prestige Upgrade 34",
	description = "Hyper-Prestige Upgrade 23 is boosted.",
	cost = JS.D("1e27000"),
	unlocked = function(this)
	do return player.m.best:gte(85) end
end
}, {"title", "description", "cost", "unlocked"}),
	[41] = JS.O({
	title = "Hyper-Prestige Upgrade 41",
	description = "First Hyper-Prestige buyable is cheaper. You can buy this upgrade while you're in AP challenge 6.",
	cost = function(this)
	if (not JS.eq(player.ap.activeChallenge, 32)) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e176e7") end
end,
	unlocked = function(this)
	do return player.m.best:gte(142) end
end
}, {"title", "description", "cost", "unlocked"}),
	[42] = JS.O({
	title = "Hyper-Prestige Upgrade 42",
	description = "Hyper Boost effect is boosted. To buy this upgrade, you need to complete AP challenge 5 20.96 times.",
	cost = function(this)
	if (JS.tonum(player.ap.challenges[31]) < 20.96) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e235e8") end
end,
	unlocked = function(this)
	do return player.m.best:gte(142) end
end
}, {"title", "description", "cost", "unlocked"}),
	[43] = JS.O({
	title = "Hyper-Prestige Upgrade 43",
	description = "The second Hyper-Prestige buyable's effect base is boosted.",
	cost = JS.D("e450e11"),
	effect = function(this)
	local p = player.hp.points:log10():log(2)
	if hasUpgrade(nil, "hp", 44) then
		do return p:mul((if hasUpgrade(nil, "hp", 44) then tmp.hp.upgrades[44].effect else 0)) end
	else
		do return softcap(nil, p, JS.D(15), 0.25) end
	end
end,
	effectDisplay = function(this)
	do return ("^" .. JS.str(format(nil, this:effect()))) end
end,
	unlocked = function(this)
	do return player.m.best:gte(142) end
end
}, {"title", "description", "cost", "effect", "effectDisplay", "unlocked"}),
	[44] = JS.O({
	title = "Hyper-Prestige Upgrade 44",
	description = "Remove Previous upgrade's effect softcap and the effect is stronger.",
	cost = JS.D("e149e12"),
	effect = function(this)
	local p = player.hp.points:max(1):log10():max(1):log(10):add(1):log(2):max(1)
	do return p end
end,
	effectDisplay = function(this)
	do return ("x" .. JS.str(format(nil, this:effect()))) end
end,
	unlocked = function(this)
	do return player.m.best:gte(142) end
end
}, {"title", "description", "cost", "effect", "effectDisplay", "unlocked"})
}, {"rows", "cols"}),
	buyables = JS.O({
	rows = 1,
	cols = 2,
	[11] = JS.O({
	title = function(this)
	do return "<h3 class='hr'>Prestige Multiplier</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Prestige Point is multiplied by ") .. JS.str(format(nil, data.effect))) .. "<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Hyper-Prestige points") end
end,
	cost = function(this)
	local a = player[JS.k(this.layer)].buyables[JS.k(this.id)]
	if a:gte(3) then
		local p = 1.5
		if hasUpgrade(nil, "hp", 41) then
			p = (JS.tonum(p) - 0.1)
		end
		a = a:div(3):pow(p):mul(3)
	end
	do return (JS.D("1e8150")):mul(Decimal.pow("1e500", a)) end
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
	local eff = (JS.D("1e50000")):pow(player[JS.k(this.layer)].buyables[JS.k(this.id)])
	if hasUpgrade(nil, "hp", 32) then
		eff = eff:pow(1.1)
	end
	if hasUpgrade(nil, "t", 51) then
		eff = eff:pow(2.1)
	end
	eff = eff:pow(tmp.ap.challenges[32].rewardEffect)
	do return eff end
end,
	unlocked = function(this)
	do return player.m.best:gte(85) end
end,
	style = function(this)
	if player.hp.points:lt(this:cost()) then
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
}, {"title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[12] = JS.O({
	title = function(this)
	do return "<h3 class='hr'>Super-Multiplier</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Super-Prestige Point is multiplied by ") .. JS.str(format(nil, data.effect))) .. "<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Hyper-Prestige points") end
end,
	cost = function(this)
	local a = player[JS.k(this.layer)].buyables[JS.k(this.id)]
	if a:gte(3) then
		a = a:div(3):pow(1.5):mul(3)
	end
	do return (JS.D("1e690000")):mul(Decimal.pow("1e10000", a)) end
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
	local eff = (JS.D("1e1000000")):pow((if hasUpgrade(nil, "hp", 43) then tmp.hp.upgrades[43].effect else 1)):pow(player[JS.k(this.layer)].buyables[JS.k(this.id)])
	if hasUpgrade(nil, "ap", 31) then
		eff = eff:pow(1.5)
	end
	eff = eff:pow(tmp.ap.challenges[32].rewardEffect)
	do return eff end
end,
	unlocked = function(this)
	do return player.m.best:gte(104) end
end,
	style = function(this)
	if player.hp.points:lt(this:cost()) then
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
	passiveGeneration = function(this)
	if player.m.best:gte(135) then
		do return 10000000000 end
	end
	if player.m.best:gte(75) then
		do return 100 end
	end
	do return 0 end
end,
	resetsNothing = function(this)
	do return (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	doReset = function(this, l)
	if (l == "hp") then
		do return end
	end
	if (l == "ap") then
		if player.m.best:gte(82) then
			layerDataReset(nil, "hp", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "hp", JS.A(0))
		end
	end
	if (l == "t") then
		if player.m.best:gte(101) then
			layerDataReset(nil, "hp", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "hp", JS.A(0))
		end
	end
	if (l == "hb") then
		if player.m.best:gte(104) then
			layerDataReset(nil, "hp", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "hp", JS.A(0))
		end
	end
end,
	update = function(this)
	local target
	if player.m.best:gte(95) then
		target = player.hp.points:add(1):div("1e8150"):log("1e500")
		if target:gte(3) then
			local p = 1.5
			if hasUpgrade(nil, "hp", 41) then
				p = (JS.tonum(p) - 0.1)
			end
			target = target:div(3):pow((1 / JS.tonum(p))):mul(3)
		end
		target = target:add(1):floor()
		if target:gt(player.hp.buyables[11]) then
			JS.set(player.hp.buyables, 11, target)
		end
	end
	if player.m.best:gte(107) then
		target = player.hp.points:add(1):div("1e690000"):log("1e10000")
		if target:gte(3) then
			target = target:div(3):pow((1 / 1.5)):mul(3)
		end
		target = target:add(1):floor()
		if target:gt(player.hp.buyables[12]) then
			JS.set(player.hp.buyables, 12, target)
		end
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "exponent", "hotkeys", "layerShown", "branches", "softcap", "softcapPower", "upgrades", "buyables", "passiveGeneration", "resetsNothing", "doReset", "update"}))

end
