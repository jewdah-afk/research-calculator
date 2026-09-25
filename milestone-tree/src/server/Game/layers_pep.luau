--!nocheck
-- transpiled from layers/pep.js by port/build.js: do not edit
return function()
-- transpiled from layers/pep.js
addLayer(nil, "pep", JS.O({
	name = "prestiged-exotic prestige",
	symbol = "PEP",
	position = 2,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = function(this)
	do return "#c89646" end
end,
	requires = function(this)
	do return (JS.D(20000000)):pow(player.pep.points:sub(3):div(3):add(1):max(1)) end
end,
	resource = function(this)
	do return "prestiged-exotic prestige points" end
end,
	baseResource = function(this)
	do return "prestige essence" end
end,
	baseAmount = function(this)
	do return player.pm.essence end
end,
	type = function(this)
	do return "static" end
end,
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	gainExp = function(this)
	local m = JS.D(0.3)
	do return m end
end,
	exponent = function(this)
	do return JS.D(1) end
end,
	prOneEffect = function(this)
	local eff = player.pep.points:add(1):mul(3):pow(1.5)
	if hasUpgrade(nil, "pep", 11) then
		eff = eff:mul(upgradeEffect(nil, "pep", 11))
	end
	if (JS.eq(player.mp.modeP, false) and (JS.tonum(tmp.pm.count) >= 7)) then
		eff = eff:mul(tmp.pm.pChalReward2)
	end
	do return eff end
end,
	prTwoEffect = function(this)
	local eff = player.pep.points:add(1):mul(2):pow(0.6)
	if hasUpgrade(nil, "pep", 12) then
		eff = eff:mul(upgradeEffect(nil, "pep", 12))
	end
	do return eff end
end,
	prThreeEffect = function(this)
	local eff = player.pep.points:add(1):log10():pow(0.35):mul(player.pep.points:div(100))
	do return eff end
end,
	prFourEffect = function(this)
	local eff = player.pep.points:add(1):log10():pow(0.85):mul(player.pep.points:div(10))
	if player.pm.best:gte(16) then
		eff = eff:mul(1.374)
	end
	do return eff end
end,
	prFiveEffect = function(this)
	local eff = player.pep.points:add(1):pow(1.35):mul(player.pep.points:add(1):root(1.25):mul(10))
	do return eff end
end,
	row = 1,
	exponent = 0.5,
	hotkeys = JS.A(1, JS.O({
	key = "ctrl+x",
	description = "Ctrl+X: Reset for prestiged-exotic prestige points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (player.pm.best:gte(5) and JS.eq(player.mp.activeChallenge, 21)) end
end,
	upgrades = JS.O({
	rows = 4,
	cols = 4,
	[11] = JS.O({
	title = "Prestiged-Exotic Prestige Upgrade 11",
	description = "Prestige Milestones boosts 1st effect at reduced rate",
	cost = JS.D(6),
	costDescription = function(this)
	do return "Cost: 6 pr-exotic prestige points<br>1e13 Prestige Essences" end
end,
	unlocked = function(this)
	do return player.pm.best:gte(7) end
end,
	effect = function(this)
	local base = 5
	local ret = player.pm.best:div(10):mul(base):add(1)
	do return ret end
end,
	canAfford = function(this)
	do return (player.pm.essence:gte(10000000000000) and player.pep.points:gte(this.cost)) end
end,
	pay = function(this)
	JS.setk(player.pep, "points", player.pep.points:sub(this.cost))
	JS.setk(player.pm, "essence", player.pm.essence:sub(10000000000000))
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "costDescription", "unlocked", "effect", "canAfford", "pay", "effectDisplay"}),
	[12] = JS.O({
	title = "Prestiged-Exotic Prestige Upgrade 12",
	description = "Prestige Milestones boosts 2nd effect at reduced rate",
	cost = JS.D(7),
	costDescription = function(this)
	do return "Cost: 7 pr-exotic prestige points<br>3e16 Prestige Essences" end
end,
	unlocked = function(this)
	do return player.pm.best:gte(8) end
end,
	effect = function(this)
	local base = 3
	if hasUpgrade(nil, "pep", 13) then
		base = (JS.tonum(base) * JS.tonum((JS.D(1)):add(upgradeEffect(nil, "pep", 13))))
	end
	local ret = player.pm.best:div(20):mul(base):add(1)
	do return ret end
end,
	canAfford = function(this)
	do return (player.pm.essence:gte(30000000000000000) and player.pep.points:gte(this.cost)) end
end,
	pay = function(this)
	JS.setk(player.pep, "points", player.pep.points:sub(this.cost))
	JS.setk(player.pm, "essence", player.pm.essence:sub(30000000000000000))
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "costDescription", "unlocked", "effect", "canAfford", "pay", "effectDisplay"}),
	[13] = JS.O({
	title = "Prestiged-Exotic Prestige Upgrade 13",
	description = "Prestige Essences boosts Pr-Exotic Upgrade 12 effect's base.",
	cost = JS.D(10),
	costDescription = function(this)
	do return "Cost: 10 pr-exotic prestige points<br>5e24 Prestige Essences" end
end,
	unlocked = function(this)
	do return player.pm.best:gte(11) end
end,
	effect = function(this)
	local base = 3
	local ret = player.pm.essence:add(1):log10():add(1):log(10):div(3)
	do return ret end
end,
	canAfford = function(this)
	do return (player.pm.essence:gte(5e24) and player.pep.points:gte(this.cost)) end
end,
	pay = function(this)
	JS.setk(player.pep, "points", player.pep.points:sub(this.cost))
	JS.setk(player.pm, "essence", player.pm.essence:sub(5e24))
end,
	effectDisplay = function(this)
	do return (("+" .. JS.str(format(nil, (JS.tonum(this:effect()) * 100), 4))) .. "%") end
end
}, {"title", "description", "cost", "costDescription", "unlocked", "effect", "canAfford", "pay", "effectDisplay"})
}, {"rows", "cols"}),
	buyables = JS.O({
	rows = 1,
	cols = 1,
	[11] = JS.O({
	title = function(this)
	do return "<h3 class='pef'>(Pr) Exotic Fusioner</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("<h4 class='pef'>Tier: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)], 0))) .. "<br></h4>") .. "Unlocking ") .. JS.str(format(nil, data.effect, 0))) .. " more effects<br>") .. "Cost for Next Tier: ") .. JS.str(format(nil, data.cost, 0))) .. " Exotic Prestige points") end
end,
	cost = function(this)
	do return (JS.A(6, JS.D("1"), JS.D("2"), JS.D("8"), JS.D("30"), JS.D("50"), Decimal.dInf))[JS.k(player.pep.buyables[11])] end
end,
	canAfford = function(this)
	do return player.pep.points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	JS.setk(player.pep, "points", player.pep.points:sub(this:cost()))
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
end,
	effect = function(this)
	local b = 1
	local eff = (JS.D(0)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b))
	do return eff end
end,
	unlocked = function(this)
	do return JS.eq(player.mp.activeChallenge, 21) end
end,
	style = function(this)
	if player.pep.points:lt(this:cost()) then
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
	content = JS.A(5, "main-display", "prestige-button", "resource-display", JS.A(2, "display-text", function(this)
	table_ = ""
	if player.pep.buyables[11]:gte(1) then
		table_ = (JS.str(table_) .. (((("1st effect: Boost prestige essences gain by " .. JS.str(format(nil, tmp.pep.prOneEffect))) .. "x and boost 1st milestone reducing effect by ") .. JS.str(format(nil, tmp.pep.prOneEffect:pow(0.5)))) .. "x."))
	end
	if player.pep.buyables[11]:gte(2) then
		table_ = (JS.str(table_) .. (("<br>2nd effect: Multiply points gain <b>before</b> 1st milestone reduce by " .. JS.str(format(nil, tmp.pep.prTwoEffect))) .. "x."))
	end
	if player.pep.buyables[11]:gte(3) then
		table_ = (JS.str(table_) .. (("<br>3rd effect: Add +" .. JS.str(format(nil, tmp.pep.prThreeEffect))) .. " to the base of <b>Essence Fusioner</b> effect."))
	end
	if player.pep.buyables[11]:gte(4) then
		table_ = (JS.str(table_) .. (("<br>4th effect: Ultra Scaled Essence Fusioner starts +" .. JS.str(format(nil, tmp.pep.prFourEffect))) .. " later."))
	end
	if player.pep.buyables[11]:gte(5) then
		table_ = (JS.str(table_) .. (("<br>5th effect: Boost Super Prestige Upgrade 41 effect by x" .. JS.str(format(nil, tmp.pep.prFiveEffect))) .. "."))
	end
	do return table_ end
end), "buyables")
}),
	Upgrades = JS.O({
	unlocked = function(this)
	do return player.pm.best:gte(7) end
end,
	content = JS.A(1, function(this)
	if (player.tab == "pep") then
		do return JS.A(2, "column", JS.A(4, "main-display", "prestige-button", "resource-display", "upgrades")) end
	end
end)
}, {"unlocked", "content"})
}, {"Main", "Upgrades"}),
	branches = JS.A(1, "pm"),
	softcap = function(this)
	do return JS.D(math.huge) end
end,
	softcapPower = function(this)
	do return JS.D(1) end
end,
	doReset = function(this, l)
	if JS.eq(player.mp.activeChallenge, 21) then
		JS.setk(player.pm, "essence", JS.D(0))
	end
end,
	update = function(this)

end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "exponent", "prOneEffect", "prTwoEffect", "prThreeEffect", "prFourEffect", "prFiveEffect", "row", "exponent", "hotkeys", "layerShown", "upgrades", "buyables", "tabFormat", "branches", "softcap", "softcapPower", "doReset", "update"}))

end
