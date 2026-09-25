--!nocheck
-- transpiled from layers/pe.js by port/build.js: do not edit
return function()
-- transpiled from layers/pe.js
addLayer(nil, "pe", JS.O({
	name = "prestige energy",
	symbol = "PE",
	position = (-1),
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = "#FF8800",
	requires = JS.D(10),
	resource = "prestige energy",
	baseResource = "prestige points",
	baseAmount = function(this)
	do return player.p.points end
end,
	type = "static",
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	gainExp = function(this)
	do return JS.D(1) end
end,
	row = 2,
	hotkeys = JS.A(1, JS.O({
	key = "e",
	description = "E: Collect Prestige Energy",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(125) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	branches = JS.A(1, "p"),
	base = function(this)
	local b = JS.D("10")
	if player.mm.best:gte(26) then
		b = b:sqrt()
	end
	if player.mm.best:gte(27) then
		b = b:sqrt()
	end
	if player.mm.best:gte(28) then
		b = b:sqrt()
	end
	if player.mm.best:gte(29) then
		b = b:sqrt()
	end
	do return b end
end,
	exponent = function(this)
	local b = JS.D(1)
	if player.ep.buyables[11]:gte(8) then
		b = b:sub(tmp.ep.eightEffect)
	end
	do return b end
end,
	resetsNothing = true,
	doReset = function(this, l)

end,
	canBuyMax = true,
	autoPrestige = function(this)
	do return player.m.best:gte(126) end
end,
	upgrades = JS.O({
	rows = 2,
	cols = 4,
	[11] = JS.O({
	title = "Prestige Energy Softcap Delayer I",
	description = "1st Milestone's softcap starts later based on your prestige energy.",
	cost = function(this)
	if inChallenge(nil, "pm", 13) then
		do return JS.D(60) end
	else
		do return JS.D(248000000000) end
	end
end,
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local b = player.pe.points:add(1):log10():div(100)
	if (hasUpgrade(nil, "pe", 13) and (not inChallenge(nil, "pm", 13))) then
		b = b:mul(1.5)
	end
	if hasUpgrade(nil, "pe", 23) then
		b = b:mul(1.5)
	end
	do return b:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Prestige Energy Scaling Reducer I",
	description = "Milestone Cost Scaling is weaker based on your prestige energy.",
	cost = function(this)
	if inChallenge(nil, "pm", 13) then
		do return JS.D(70) end
	else
		do return JS.D(277000000000) end
	end
end,
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local b = player.pe.points:add(1):log10():div(200)
	if inChallenge(nil, "pm", 13) then
		b = b:mul(100)
	end
	if (hasUpgrade(nil, "pe", 13) and inChallenge(nil, "pm", 13)) then
		b = b:mul(300)
	end
	if hasUpgrade(nil, "pe", 14) then
		b = b:mul(1.5)
	end
	if hasUpgrade(nil, "pe", 22) then
		b = b:mul(1.5)
	end
	do return b:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Prestige Energy Upgrade 11 Boost I",
	description = function(this)
	if inChallenge(nil, "pm", 13) then
		do return "Prestige Energy Upgrade 12 is greately boosted." end
	else
		do return "Prestige Energy Upgrade 11 is boosted." end
	end
end,
	cost = function(this)
	if inChallenge(nil, "pm", 13) then
		do return JS.D(80) end
	else
		do return JS.D(598000000000) end
	end
end,
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[14] = JS.O({
	title = "Prestige Energy Upgrade 12 Boost I",
	description = "Prestige Energy Upgrade 12 is boosted.",
	cost = function(this)
	if inChallenge(nil, "pm", 13) then
		do return JS.D(89) end
	else
		do return JS.D(794000000000) end
	end
end,
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[21] = JS.O({
	title = "Prestige Energy Transcend Boost I",
	description = "Transcend point gain is boosted based on your prestige energy.",
	cost = JS.D(1340000000000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 1.1
	if hasUpgrade(nil, "pe", 24) then
		base = JS.add(base, 0.05)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[22] = JS.O({
	title = "Prestige Energy Upgrade 12 Boost II",
	description = "Prestige Energy Upgrade 12 is boosted.",
	cost = JS.D(1420000000000),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[23] = JS.O({
	title = "Prestige Energy Upgrade 11 Boost II",
	description = "Prestige Energy Upgrade 11 is boosted.",
	cost = JS.D(3380000000000),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[24] = JS.O({
	title = "Prestige Energy Upgrade 21 Boost I",
	description = "Prestige Energy Upgrade 21 is boosted.",
	cost = JS.D(6860000000000),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"})
}, {"rows", "cols"}),
	resetDescription = "Collect ",
	tabFormat = JS.A(4, "main-display", "prestige-button", JS.A(2, "display-text", function(this)
	local peroom = (JS.D(10)):log(tmp.pe.base)
	local power = (JS.D(1)):div(tmp.pe.exponent)
	do return (((("(" .. JS.str(format(nil, peroom))) .. " per OoM of prestige points, then raised to a power of ") .. JS.str(format(nil, power))) .. ")") end
end), "upgrades")
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "hotkeys", "layerShown", "branches", "base", "exponent", "resetsNothing", "doReset", "canBuyMax", "autoPrestige", "upgrades", "resetDescription", "tabFormat"}))

end
