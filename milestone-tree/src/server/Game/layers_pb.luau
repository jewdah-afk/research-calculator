--!nocheck
-- transpiled from layers/pb.js by port/build.js: do not edit
return function()
-- transpiled from layers/pb.js
addLayer(nil, "pb", JS.O({
	name = "prestige boost",
	symbol = "PB",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = "#70C0A0",
	requires = function(this)
	if JS.eq(player.ap.activeChallenge, 11) then
		do return JS.D(math.huge) end
	end
	do return JS.D("1e13760") end
end,
	resource = "prestige boosts",
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
	key = "b",
	description = "B: Reset for prestige boosts",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(50) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	branches = JS.A(1, "p"),
	softcap = JS.D(math.huge),
	softcapPower = JS.D(1),
	base = JS.D("1e13630"),
	exponent = function(this, x)
	if (x == nil) then
		x = player.pb.points
	end
	local p = JS.D(1.1311)
	if x:gte(15) then
		local scaling = x:sub(15):pow(2):div(2600)
		if hasUpgrade(nil, "t", 24) then
			scaling = scaling:div(1.1)
		end
		if player.m.best:gte(111) then
			scaling = scaling:div(1.048)
		end
		if player.m.best:gte(117) then
			scaling = scaling:div(1.02)
		end
		if hasUpgrade(nil, "pb", 41) then
			scaling = scaling:div(upgradeEffect(nil, "pb", 41))
		end
		p = p:add(scaling)
	end
	do return p end
end,
	effect = function(this)
	local p = 0.5
	local m = 0.05
	local e = JS.D(0)
	if hasUpgrade(nil, "pb", 11) then
		p = JS.add(p, 0.1)
		m = JS.add(m, 0.011)
	end
	if hasUpgrade(nil, "pb", 12) then
		p = JS.add(p, 0.05)
		m = JS.add(m, 0.005)
	end
	if hasUpgrade(nil, "pb", 13) then
		p = JS.add(p, 0.01)
		m = JS.add(m, 0.00251)
	end
	if hasUpgrade(nil, "pb", 14) then
		p = JS.add(p, 0.005)
		m = JS.add(m, 0.001)
	end
	if hasUpgrade(nil, "pb", 21) then
		p = JS.add(p, 0.005)
	end
	if hasUpgrade(nil, "pb", 22) then
		m = JS.add(m, 0.00275)
	end
	if hasUpgrade(nil, "pb", 23) then
		p = JS.add(p, 0.01)
		m = JS.add(m, 0.001004)
	end
	if hasUpgrade(nil, "pb", 24) then
		m = JS.add(m, 0.00201)
	end
	if (JS.tonum(player.ap.challenges[11]) >= 1) then
		p = JS.add(p, 0.01)
	end
	if (JS.tonum(player.ap.challenges[11]) >= 2) then
		m = JS.add(m, 0.001)
	end
	if (JS.tonum(player.ap.challenges[11]) >= 3) then
		p = JS.add(p, 0.01)
		m = JS.add(m, (0.002 * (JS.tonum(player.ap.challenges[11]) - 3)))
	end
	m = JS.add(m, (0.002 * JS.tonum(player.ap.challenges[31])))
	if (JS.tonum(player.ap.challenges[31]) >= 17) then
		m = JS.add(m, 0.0003)
	end
	if hasUpgrade(nil, "hb", 12) then
		e = e:add(upgradeEffect(nil, "hb", 12))
	end
	if hasUpgrade(nil, "pb", 44) then
		m = JS.add(m, 0.002)
	end
	x = (JS.D(1)):add(player.pb.points:add(e):pow(p):mul(m)):pow(layers.hb:effect())
	do return softcap(nil, x, (JS.D(30)):add((if player.ep.buyables[11]:gte(7) then tmp.ep.sevenEffect else 0)), 0.1) end
end,
	effectDescription = function(this)
	do return ("prestige points is powered by " .. JS.str(format(nil, layers.pb:effect(), 4))) end
end,
	upgrades = JS.O({
	rows = 4,
	cols = 4,
	[11] = JS.O({
	title = "Prestige Boost Effect Boost I",
	description = "Prestige Boost's effect is better.",
	cost = JS.D(3),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[12] = JS.O({
	title = "Prestige Boost Effect Boost II",
	description = "Prestige Boost's effect is better.",
	cost = JS.D(7),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[13] = JS.O({
	title = "Prestige Boost Effect Boost III",
	description = "Prestige Boost's effect is better.",
	cost = JS.D(11),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[14] = JS.O({
	title = "Prestige Boost Effect Boost IV",
	description = "Prestige Boost's effect is better.",
	cost = JS.D(22),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[21] = JS.O({
	title = "Prestige Boost Effect Boost V",
	description = "Prestige Boost's effect is better.",
	cost = JS.D(31),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[22] = JS.O({
	title = "Prestige Boost Effect Boost VI",
	description = "Prestige Boost's effect is better.",
	cost = JS.D(34),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[23] = JS.O({
	title = "Prestige Boost Effect Boost VII",
	description = "Prestige Boost's effect is better.",
	cost = JS.D(40),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[24] = JS.O({
	title = "Prestige Boost Effect Boost VIII",
	description = "Prestige Boost's effect is better.",
	cost = JS.D(48),
	unlocked = function(this)
	do return true end
end
}, {"title", "description", "cost", "unlocked"}),
	[31] = JS.O({
	title = "Prestige Boost Softcap Delayer I",
	description = "Prestige Boost affects the 1st Milestone's softcap at a reduced rate.",
	cost = JS.D(90),
	unlocked = function(this)
	do return player.m.best:gte(111) end
end,
	effect = function(this)
	local e = 0.1
	if hasUpgrade(nil, "pb", 32) then
		e = JS.add(e, 0.1)
	end
	if hasUpgrade(nil, "pb", 33) then
		e = JS.add(e, 0.1)
	end
	if hasUpgrade(nil, "pb", 34) then
		e = JS.add(e, 0.1)
	end
	if hasUpgrade(nil, "pb", 43) then
		e = JS.add(e, 0.1)
	end
	local p = tmp.pb.effect:pow(e)
	do return p end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[32] = JS.O({
	title = "Prestige Boost Upgrade 31 Boost I",
	description = "Prestige Boost Upgrade 31 is boosted.",
	cost = JS.D(92),
	unlocked = function(this)
	do return player.m.best:gte(111) end
end
}, {"title", "description", "cost", "unlocked"}),
	[33] = JS.O({
	title = "Prestige Boost Upgrade 31 Boost II",
	description = "Prestige Boost Upgrade 31 is boosted.",
	cost = JS.D(95),
	unlocked = function(this)
	do return player.m.best:gte(111) end
end
}, {"title", "description", "cost", "unlocked"}),
	[34] = JS.O({
	title = "Prestige Boost Upgrade 31 Boost III",
	description = "Prestige Boost Upgrade 31 is boosted.",
	cost = JS.D(98),
	unlocked = function(this)
	do return player.m.best:gte(111) end
end
}, {"title", "description", "cost", "unlocked"}),
	[41] = JS.O({
	title = "Prestige Boost Scaling Reducer I",
	description = "Prestige Boost cost scaling is weaker based on your super-prestige points. You can buy this upgrade while you're in AP challenge 2.",
	cost = function(this)
	if (not JS.eq(player.ap.activeChallenge, 12)) then
		do return JS.D(math.huge) end
	end
	do return JS.D(102) end
end,
	unlocked = function(this)
	do return player.m.best:gte(132) end
end,
	effect = function(this)
	local p = player.sp.points:add(100000000000000000000):log10():log10():div(200)
	do return p:add(1) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[42] = JS.O({
	title = "Prestige Boost Milestone Boost I",
	description = "3rd Milestone's effect is boosted based on your prestige boosts. You can buy this upgrade while you're in AP challenge 3.",
	cost = function(this)
	if (not JS.eq(player.ap.activeChallenge, 21)) then
		do return JS.D(math.huge) end
	end
	do return JS.D(109) end
end,
	unlocked = function(this)
	do return player.m.best:gte(132) end
end,
	effect = function(this)
	local e = 0.01
	local p = tmp.pb.effect:pow(e)
	do return p end
end,
	effectDisplay = function(this)
	do return ("^" .. JS.str(format(nil, this:effect(), 4))) end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[43] = JS.O({
	title = "Prestige Boost Upgrade 31 Boost IV",
	description = "Prestige Boost Upgrade 31 is boosted. You can buy this upgrade while you're in T challenge 2.",
	cost = function(this)
	if (not JS.eq(player.t.activeChallenge, 12)) then
		do return JS.D(math.huge) end
	end
	do return JS.D(77) end
end,
	unlocked = function(this)
	do return player.m.best:gte(132) end
end
}, {"title", "description", "cost", "unlocked"}),
	[44] = JS.O({
	title = "Prestige Boost Effect Boost IX",
	description = "Prestige Boost's effect is better. To buy this upgrade, You need to complete AP challenge 5 18 times.",
	cost = function(this)
	if (JS.tonum(player.ap.challenges[31]) < 18) then
		do return JS.D(math.huge) end
	end
	do return JS.D(112) end
end,
	unlocked = function(this)
	do return player.m.best:gte(132) end
end
}, {"title", "description", "cost", "unlocked"})
}, {"rows", "cols"}),
	resetsNothing = function(this)
	do return player.m.best:gte(65) end
end,
	doReset = function(this, l)
	if (l == "pb") then
		do return end
	end
	if (l == "hp") then
		if player.m.best:gte(70) then
			layerDataReset(nil, "pb", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "pb", JS.A(0))
		end
	end
	if (l == "ap") then
		if player.m.best:gte(81) then
			layerDataReset(nil, "pb", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "pb", JS.A(0))
		end
	end
	if (l == "t") then
		if player.m.best:gte(101) then
			layerDataReset(nil, "pb", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "pb", JS.A(0))
		end
	end
	if (l == "hb") then
		if player.m.best:gte(104) then
			layerDataReset(nil, "pb", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "pb", JS.A(0))
		end
	end
end,
	update = function(this)
	if (player.m.best:gte(80) and (not JS.eq(player.ap.activeChallenge, 11))) then
		local __g1 = 0
		while true do
			__g1 += 1; if __g1 > 5000000 then JS.runaway() end
			local req = layers.pb:requires():mul(layers.pb.base:pow(Decimal.pow(player.pb.points, layers.pb:exponent())))
			if player.p.points:gt(req) then
				JS.setk(player.pb, "points", player.pb.points:add(1))
			else
				break
			end
		end
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "hotkeys", "layerShown", "branches", "softcap", "softcapPower", "base", "exponent", "effect", "effectDescription", "upgrades", "resetsNothing", "doReset", "update"}))

end
