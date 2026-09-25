--!nocheck
-- transpiled from layers/ep.js by port/build.js: do not edit
return function()
-- transpiled from layers/ep.js
addLayer(nil, "ep", JS.O({
	name = "exotic prestige",
	symbol = "EP",
	position = 1,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = function(this)
	do return "#648c11" end
end,
	requires = function(this)
	do return JS.D(1000000000000000) end
end,
	resource = function(this)
	do return "exotic prestige points" end
end,
	baseResource = function(this)
	do return "prestige power" end
end,
	baseAmount = function(this)
	do return player.pp.points end
end,
	type = function(this)
	do return "normal" end
end,
	gainMult = function(this)
	mult = JS.D(1)
	if (player.p.buyables[12]:gte(1) and (not JS.eq(player.mp.activeChallenge, 21))) then
		mult = mult:mul(buyableEffect(nil, "p", 12))
	end
	if (player.mp.buyables[11]:gte(1) and (not JS.eq(player.mp.activeChallenge, 21))) then
		mult = mult:mul(buyableEffect(nil, "mp", 11))
	end
	do return mult end
end,
	gainExp = function(this)
	local m = JS.D(1)
	do return m end
end,
	exponent = function(this)
	do return JS.D(1) end
end,
	oneEffect = function(this)
	local eff = (JS.D(player.ep.points:add(1):pow((if player.m.best:gte(165) then 4 else 3.25)))):max(1)
	if player.m.best:gte(167) then
		eff = eff:pow(1.1)
	end
	if player.m.best:gte(168) then
		eff = eff:pow(1.1)
	end
	if JS.eq(player.mp.activeChallenge, 13) then
		do return JS.D(1) end
	end
	eff = softcap(nil, eff, JS.D("1e1000000"), 0.075)
	eff = softcap(nil, eff, JS.D("1e2500000"), 0.075)
	eff = softcap(nil, eff, JS.D("1e5000000"), 0.015)
	do return softcap(nil, eff, JS.D("ee9"), (1 / 10000000000)) end
end,
	twoEffect = function(this)
	local eff = player.ep.points:add(1):pow((if player.m.best:gte(166) then 2.5 else 2.2)):mul(4):max(1)
	eff = softcap(nil, eff, JS.D("1e100"), 0.075)
	soft = (if player.mp.buyables[12]:gte(1) then (JS.D("1e25000")):mul((JS.D("1e25000")):mul(player.mp.buyables[12]):max(1)) else JS.D("1e25000"))
	if JS.eq(player.mp.activeChallenge, 13) then
		do return JS.D(1) end
	end
	eff = softcap(nil, eff, soft, 0.075)
	eff = softcap(nil, eff, JS.D("1e100000"), 0.22)
	eff = softcap(nil, eff, JS.D("1e200000"), 0.02)
	eff = eff:min(("ee11"))
	if eff:gte(("ee11")) then
		eff = eff:pow(player.ep.points:max(1):log10():max(1):log10())
	end
	do return eff end
end,
	threeEffect = function(this)
	local eff = player.ep.points:add(1):log10():max(1):pow(0.01):div(500)
	if player.m.best:gte(171) then
		eff = eff:mul(1.075)
	end
	if player.m.best:gte(172) then
		eff = eff:mul(1.1)
	end
	if player.mp.buyables[12]:gte(2) then
		eff = eff:mul(4)
	end
	if JS.eq(player.mp.activeChallenge, 13) then
		do return JS.D(0) end
	end
	eff = softcap(nil, eff, JS.D(0.02), 0.05)
	do return eff:toNumber() end
end,
	fourEffect = function(this)
	local eff = player.ep.points:add(1):pow(0.35):max(1)
	if player.m.best:gte(173) then
		eff = eff:pow(1.05)
	end
	if JS.eq(player.mp.activeChallenge, 13) then
		do return JS.D(1) end
	end
	if JS.eq(player.mp.activeChallenge, 11) then
		eff = eff:pow(0.15)
		eff = softcap(nil, eff, JS.D("1e40000"), 0.275)
	end
	eff = softcap(nil, eff, JS.D("1e100000"), 0.075)
	do return softcap(nil, eff, JS.D("1e600000"), 0.005) end
end,
	fiveEffect = function(this)
	local eff = player.ep.points:add(1):log10():add(1):log(10):pow(0.5):max(1)
	if player.mp.buyables[12]:gte(3) then
		eff = eff:mul(2)
	end
	if hasUpgrade(nil, "p", 45) then
		eff = eff:mul(upgradeEffect(nil, "p", 45))
	end
	local start = (JS.D("e5.6e12")):mul(player.ep.points:add(1):log10():add(1):log(10):pow(0.5))
	if player.m.best:gte(174) then
		start = start:pow(0.1)
	end
	if JS.eq(player.mp.activeChallenge, 13) then
		eff = JS.D(1)
	end
	start = start:add(tmp.ap.challenges[42].effect)
	eff = softcap(nil, eff, JS.D(2.75), 0.5)
	do return JS.O({
		eff = softcap(nil, eff, JS.D(5), 0.15),
		start = start
	}, {"eff", "start"}) end
end,
	sixEffect = function(this)
	local eff = player.ep.points:add(1):log(1.1):pow(2.15)
	if (JS.tonum(player.mp.challenges[11]) > 0) then
		eff = eff:mul(tmp.mp.challenges[11].rewardEffect)
	end
	if player.mp.buyables[12]:gte(3) then
		eff = eff:pow(2.5)
	end
	if player.mp.buyables[12]:gte(4) then
		eff = eff:pow(1.015)
	end
	if JS.eq(player.mp.activeChallenge, 13) then
		do return JS.D(1) end
	end
	do return eff:max(1) end
end,
	sevenEffect = function(this)
	local eff = player.ep.points:add(1):log10():max(1):pow(0.1):mul(0.382):div(20)
	if (JS.tonum(player.mp.challenges[12]) > 0) then
		eff = eff:add(tmp.mp.challenges[12].rewardEffect)
	end
	if player.mp.buyables[12]:gte(4) then
		eff = eff:mul(2.56)
	end
	if player.mp.buyables[12]:gte(5) then
		eff = eff:mul(1.055)
	end
	if JS.eq(player.mp.activeChallenge, 13) then
		do return JS.D(0) end
	end
	do return softcap(nil, eff, JS.D(4.5), 0.01) end
end,
	eightEffect = function(this)
	local eff = player.ep.points:add(1):log10():max(1):pow(0.1):div(10)
	if player.mp.buyables[12]:gte(5) then
		eff = eff:mul(5)
	end
	if player.mp.buyables[12]:gte(6) then
		eff = eff:mul(1.155)
	end
	if JS.eq(player.mp.activeChallenge, 13) then
		do return JS.D(0) end
	end
	do return softcap(nil, eff, JS.D(0.5), 0.1) end
end,
	row = 3,
	newRow = 1,
	exponent = 0.5,
	hotkeys = JS.A(1, JS.O({
	key = "x",
	description = "X: Reset for exotic prestige points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(160) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	upgrades = JS.O({
	rows = 4,
	cols = 4,
	[11] = JS.O({
	title = "Exotic Prestige Upgrade 11",
	description = "4th Milestone's effect is boosted by your exotic prestige points.<br>Req: Fusion Tier 2",
	cost = JS.D(25),
	unlocked = function(this)
	do return (not JS.eq(player.mp.activeChallenge, 21)) end
end,
	effect = function(this)
	local base = 1.2
	local effAfter1e20 = player.ep.points:max(1):log(10):max(1):log(2):pow(4.65)
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.275):add(1)):max(1)
	ret = softcap(nil, ret, JS.D(1000000000), 0.1)
	ret = ret:min(100000000000000000000)
	if ret:gte(100000000000000000000) then
		ret = ret:mul(effAfter1e20)
	end
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Exotic Prestige Upgrade 12",
	description = "179th milestone effect is better based on Exotic Booster level",
	cost = JS.D("e890360"),
	unlocked = function(this)
	do return (player.mp.buyables[21]:gte(1) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	effect = function(this)
	local base = 1.82
	local ret = player.p.buyables[12]:mul(100):pow(base)
	do return ret end
end,
	effectDisplay = function(this)
	do return ("^" .. JS.str(format(nil, this:effect()))) end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Exotic Prestige Upgrade 13",
	description = "Apply weaker Challenge Slayer effect to Exotic Booster cost base.",
	cost = JS.D("e1560000"),
	unlocked = function(this)
	do return (player.mp.buyables[21]:gte(1) and (not JS.eq(player.mp.activeChallenge, 21))) end
end,
	effect = function(this)
	local ret = buyableEffect(nil, "ap", 11):max(1):div(150):add(0.4)
	do return ret end
end,
	effectDisplay = function(this)
	do return ("/" .. JS.str(format(nil, this:effect()))) end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[14] = JS.O({
	title = "Exotic Prestige Upgrade 14",
	description = "Change the formula for Power Scaler.",
	cost = JS.D("e4650000"),
	unlocked = function(this)
	do return (player.mp.buyables[21]:gte(2) and (not JS.eq(player.mp.activeChallenge, 21))) end
end
}, {"title", "description", "cost", "unlocked"}),
	[21] = JS.O({
	title = "Exotic Prestige Upgrade 21",
	description = "Reduce goal scaling of <b>Dilation</b> challenges by sum of this challenge completions and Exotic Prestige Points",
	cost = JS.D("e7490000"),
	effect = function(this)
	local ret = ((((JS.tonum(player.t.challenges[11]) * 2) + (JS.tonum(player.t.challenges[21]) * 10)) + (JS.tonum(player.t.challenges[31]) * 10)) + player.ep.points:add(1):log(10):add(1):pow(0.5):toNumber())
	if hasUpgrade(nil, "ep", 22) then
		ret = (JS.tonum(ret) * 2.5)
	end
	do return softcap(nil, JS.D(ret), JS.D(1000000), 0.25) end
end,
	effectDisplay = function(this)
	do return ("-" .. JS.str(format(nil, this:effect()))) end
end,
	unlocked = function(this)
	do return (player.mp.buyables[21]:gte(2) and (not JS.eq(player.mp.activeChallenge, 21))) end
end
}, {"title", "description", "cost", "effect", "effectDisplay", "unlocked"}),
	[22] = JS.O({
	title = "Exotic Prestige Upgrade 22",
	description = "Exotic Prestige Upgrade 21 is better",
	cost = JS.D("e1.39e9"),
	unlocked = function(this)
	do return (player.mp.buyables[21]:gte(3) and (not JS.eq(player.mp.activeChallenge, 21))) end
end
}, {"title", "description", "cost", "unlocked"})
}, {"rows", "cols"}),
	buyables = JS.O({
	rows = 2,
	cols = 2,
	[11] = JS.O({
	title = function(this)
	do return "<h3 class='ef'>Exotic Fusioner</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("<h4 class='ef'>Tier: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)], 0))) .. "<br></h4>") .. "Unlocking ") .. JS.str(format(nil, data.effect, 0))) .. " more effects<br>") .. "Cost for Next Tier: ") .. JS.str(format(nil, data.cost, 0))) .. " Exotic Prestige points") end
end,
	cost = function(this)
	do return (JS.A(9, JS.D("2"), JS.D("8"), JS.D("512"), JS.D("1e55"), JS.D("1e170"), JS.D("1e2000"), JS.D("1e150000"), JS.D("1e3330000"), Decimal.dInf))[JS.k(player.ep.buyables[11])] end
end,
	canAfford = function(this)
	do return player[JS.k(this.layer)].points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.setk(player.ep, "points", player.ep.points:sub(this:cost()))
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
end,
	effect = function(this)
	local b = 1
	local eff = (JS.D(0)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b))
	do return eff end
end,
	unlocked = function(this)
	do return true end
end,
	style = function(this)
	if player.ep.points:lt(this:cost()) then
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
	table_ = ""
	if player.ep.buyables[11]:gte(1) then
		table_ = (JS.str(table_) .. (("1st effect: AP challenge 41 effect is " .. JS.str(format(nil, tmp.ep.oneEffect))) .. "x better"))
	end
	if player.ep.buyables[11]:gte(2) then
		table_ = JS.add(table_, (if player.mp.buyables[12]:gte(1) then (("<br><span class=\"ef\">2nd effect: Transcend Points gain is " .. JS.str(format(nil, tmp.ep.twoEffect))) .. "x better (only outside of T challenges)</span>") else (("<br>2nd effect: Transcend Points gain is " .. JS.str(format(nil, tmp.ep.twoEffect))) .. "x better (only outside of T challenges)")))
	end
	if player.ep.buyables[11]:gte(3) then
		table_ = JS.add(table_, (if player.mp.buyables[12]:gte(1) then (("<br><span class=\"ef\">3rd effect: Hyper Boost effect base +" .. JS.str(format(nil, tmp.ep.threeEffect, 4))) .. "</span>") else ("<br>3rd effect: Hyper Boost effect base +" .. JS.str(format(nil, tmp.ep.threeEffect, 4)))))
	end
	if player.ep.buyables[11]:gte(4) then
		table_ = (JS.str(table_) .. (("<br>4th effect: Transcend Points hardcap starts " .. JS.str(format(nil, tmp.ep.fourEffect, 4))) .. "x later"))
	end
	if player.ep.buyables[11]:gte(5) then
		table_ = JS.add(table_, (if player.mp.buyables[12]:gte(3) then (((("<br><span class=\"ef\">5th effect: Add an Hyper-Prestige Points inflation (^" .. JS.str(format(nil, tmp.ep.fiveEffect.eff, 4))) .. " to gain), that starts at ") .. JS.str(format(nil, tmp.ep.fiveEffect.start, 4))) .. " Hyper-Prestige Points</span>") else (((("<br>5th effect: Add an Hyper-Prestige Points inflation (^" .. JS.str(format(nil, tmp.ep.fiveEffect.eff, 4))) .. " to gain), that starts at ") .. JS.str(format(nil, tmp.ep.fiveEffect.start, 4))) .. " Hyper-Prestige Points")))
	end
	if player.ep.buyables[11]:gte(6) then
		table_ = JS.add(table_, (if player.mp.buyables[12]:gte(4) then (("<br><span class=\"ef\">6th effect: Transcend Points gain in Transcend Challenges is x" .. JS.str(format(nil, tmp.ep.sixEffect, 4))) .. " better.</span>") else (("<br>6th effect: Transcend Points gain in Transcend Challenges is x" .. JS.str(format(nil, tmp.ep.sixEffect, 4))) .. " better.")))
	end
	if player.ep.buyables[11]:gte(7) then
		table_ = JS.add(table_, (if player.mp.buyables[12]:gte(5) then ((("<br><span class=\"ef\">7th effect: Softcap of Prestige Boost's effect starts +") .. JS.str(format(nil, tmp.ep.sevenEffect, 4))) .. " later.</span>") else (("<br>7th effect: Softcap of Prestige Boost's effect starts +" .. JS.str(format(nil, tmp.ep.sevenEffect, 4))) .. " later.")))
	end
	if player.ep.buyables[11]:gte(8) then
		table_ = JS.add(table_, (if player.mp.buyables[12]:gte(6) then ((("<br><span class=\"ef\">8th effect: Add +") .. JS.str(format(nil, tmp.ep.eightEffect, 4))) .. " to prestige energy gain exponent.</span>") else (("<br>8th effect: Add +" .. JS.str(format(nil, tmp.ep.eightEffect, 4))) .. " to prestige energy gain exponent.")))
	end
	do return table_ end
end), "buyables", "upgrades")
})
}),
	branches = JS.A(1, "pp"),
	passiveGeneration = function(this)
	if player.em.best:gte(6) then
		do return 0.1 end
	end
	do return 0 end
end,
	softcap = function(this)
	do return JS.D(math.huge) end
end,
	softcapPower = function(this)
	do return JS.D(1) end
end,
	doReset = function(this, l)
	if (l == "ep") then
		if player.m.best:gte(162) then
			layerDataReset(nil, "pp", JS.A(2, "upgrades", "buyables"))
		else
			layerDataReset(nil, "pp", JS.A(0))
		end
	end
end,
	update = function(this, diff)

end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "exponent", "oneEffect", "twoEffect", "threeEffect", "fourEffect", "fiveEffect", "sixEffect", "sevenEffect", "eightEffect", "row", "newRow", "exponent", "hotkeys", "layerShown", "upgrades", "buyables", "tabFormat", "branches", "passiveGeneration", "softcap", "softcapPower", "doReset", "update"}))

end
