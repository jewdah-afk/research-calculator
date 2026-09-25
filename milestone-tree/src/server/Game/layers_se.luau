--!nocheck
-- transpiled from layers/se.js by port/build.js: do not edit
return function()
-- transpiled from layers/se.js
addLayer(nil, "se", JS.O({
	name = "super energy",
	symbol = "SE",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = "#FF6600",
	requires = JS.D(10),
	resource = "super energy",
	baseResource = "super-prestige points",
	baseAmount = function(this)
	do return player.sp.points end
end,
	type = "static",
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	gainExp = function(this)
	local b = JS.D(1)
	do return b end
end,
	row = 3,
	hotkeys = JS.A(1, JS.O({
	key = "E",
	description = "Shift+E: Collect Super Energy",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(140) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	branches = JS.A(1, "pe"),
	base = function(this)
	local b = JS.D("10")
	if player.m.best:gte(148) then
		b = b:sqrt()
	end
	if player.m.best:gte(149) then
		b = b:sqrt()
	end
	if player.m.best:gte(152) then
		b = b:sqrt(tmp.m.milestone152Effect)
	end
	do return b end
end,
	exponent = function(this)
	local b = JS.D(1)
	do return b end
end,
	resetsNothing = true,
	doReset = function(this, l)

end,
	canBuyMax = true,
	autoPrestige = function(this)
	do return player.m.best:gte(140) end
end,
	upgrades = JS.O({
	rows = 2,
	cols = 4,
	[11] = JS.O({
	title = "Super Energy Upgrade 11",
	description = "1st Milestone's softcap starts later based on your super energy.",
	cost = JS.D(1110000000000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local b = player.se.points:add(1):log10():div(100)
	do return b:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Super Energy Upgrade 12",
	description = "Milestone Cost Scaling is weaker based on your super energy.",
	cost = JS.D(1530000000000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local b = player.se.points:add(1):log10():div(200)
	do return b:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[21] = JS.O({
	title = "Super Energy Upgrade 21",
	unlocked = function(this)
	do return player.m.best:gte(146) end
end,
	description = "4th Milestone's effect is better based on your super energy..",
	cost = JS.D(2890000000000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local b = player.se.points:add(1):log10():mul(1.5)
	do return b:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x") end
end
}, {"title", "unlocked", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[22] = JS.O({
	title = "Super Energy Upgrade 22",
	unlocked = function(this)
	do return player.m.best:gte(146) end
end,
	description = "1st Milestone's softcap starts later based on your super energy.",
	cost = JS.D(31000000000000),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local b = player.se.points:add(1):log10():div(120)
	do return b:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "unlocked", "description", "cost", "unlocked", "effect", "effectDisplay"})
}, {"rows", "cols"}),
	resetDescription = "Collect ",
	tabFormat = JS.A(4, "main-display", "prestige-button", JS.A(2, "display-text", function(this)
	local peroom = (JS.D(10)):log(tmp.se.base)
	local power = (JS.D(1)):div(tmp.se.exponent)
	do return (((("(" .. JS.str(format(nil, peroom))) .. " per OoM of super-prestige points, then raised to a power of ") .. JS.str(format(nil, power))) .. ")") end
end), "upgrades")
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "hotkeys", "layerShown", "branches", "base", "exponent", "resetsNothing", "doReset", "canBuyMax", "autoPrestige", "upgrades", "resetDescription", "tabFormat"}))

end
