--!nocheck
-- transpiled from layers/hb.js by port/build.js: do not edit
return function()
-- transpiled from layers/hb.js
addLayer(nil, "hb", JS.O({
	name = "hyper boost",
	symbol = "HB",
	position = 1,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = "#90FFC0",
	requires = function(this)
	r = JS.D("1e473950")
	if hasUpgrade(nil, "t", 41) then
		r = r:div("1e60000")
	end
	if hasUpgrade(nil, "t", 64) then
		r = r:div("1e300000")
	end
	if hasUpgrade(nil, "t", 71) then
		r = r:div("1e30000")
	end
	do return r end
end,
	resource = "hyper boosts",
	baseResource = "hyper-prestige points",
	baseAmount = function(this)
	do return player.hp.points end
end,
	type = "static",
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	gainExp = function(this)
	do return JS.D(1) end
end,
	row = 4,
	hotkeys = JS.A(1, JS.O({
	key = "B",
	description = "Shift+B: Reset for hyper boosts",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(104) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	branches = JS.A(2, "hp", "pb"),
	softcap = JS.D(math.huge),
	softcapPower = JS.D(1),
	base = JS.D("1e100000"),
	exponent = function(this, x)
	if (x == nil) then
		x = player.hb.points
	end
	local p = JS.D(1.25)
	if x:gte(10) then
		local scaling = x:sub(10):pow(2):div(1000)
		if player.m.best:gte(119) then
			scaling = scaling:div(1.2)
		end
		p = p:add(scaling)
	end
	do return p end
end,
	effect = function(this)
	local p = 0.5
	local m = 0.02
	local e = 0
	local extra = 0
	if hasUpgrade(nil, "t", 42) then
		e = (JS.tonum(e) + 1)
	end
	if hasUpgrade(nil, "t", 43) then
		m = JS.add(m, 0.02)
	end
	if hasUpgrade(nil, "hb", 13) then
		m = JS.add(m, 0.004)
	end
	if hasUpgrade(nil, "hb", 14) then
		m = JS.add(m, 0.003)
	end
	if hasUpgrade(nil, "hp", 42) then
		m = JS.add(m, 0.003)
	end
	if hasUpgrade(nil, "hb", 32) then
		m = JS.add(m, 0.001)
	end
	if player.ep.buyables[11]:gte(3) then
		m = JS.add(m, tmp.ep.threeEffect)
	end
	if hasUpgrade(nil, "hb", 34) then
		m = JS.add(m, 0.02)
	end
	if hasMalware(nil, "m", 7) then
		extra = 15
	end
	do return (JS.D(1)):add(player.hb.points:add(extra):add(e):pow(p):mul(m)):add((if hasAchievement(nil, "ach", 28) then 0.015 else 0)) end
end,
	effectDescription = function(this)
	do return ("hyper-prestige points and prestige boost effect is powered by " .. JS.str(format(nil, layers.hb:effect(), 4))) end
end,
	upgrades = JS.O({
	rows = 3,
	cols = 4,
	[11] = JS.O({
	title = "Hyper Boost Upgrade 11",
	description = "Hyper Boost effect affects the 1st Milestone's softcap.",
	cost = JS.D(7),
	effect = function(this)
	local p = tmp.hb.effect
	do return p end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Hyper Boost Upgrade 12",
	description = "Non-Extra Hyper Boosts provide extra Prestige Boosts.",
	cost = JS.D(12),
	effect = function(this)
	local exp = 0.7
	if hasUpgrade(nil, "hb", 21) then
		exp = JS.add(exp, 0.05)
	end
	if hasUpgrade(nil, "hb", 22) then
		exp = JS.add(exp, 0.05)
	end
	if hasUpgrade(nil, "hb", 23) then
		exp = JS.add(exp, 0.05)
	end
	if hasUpgrade(nil, "hb", 24) then
		exp = JS.add(exp, 0.05)
	end
	if hasUpgrade(nil, "hb", 31) then
		exp = JS.add(exp, tmp.hb.upgrades[31].effect)
	end
	local p = player.hb.points:pow(exp):mul((if hasUpgrade(nil, "hb", 33) then upgradeEffect(nil, "hb", 33) else 1))
	do return p end
end,
	effectDisplay = function(this)
	do return ("+" .. JS.str(format(nil, this:effect(), 4))) end
end
}, {"title", "description", "cost", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Hyper Boost Upgrade 13",
	description = "Hyper Boost's effect is better.",
	cost = JS.D(20)
}, {"title", "description", "cost"}),
	[14] = JS.O({
	title = "Hyper Boost Upgrade 14",
	description = "Hyper Boost's effect is better.",
	cost = JS.D(26)
}, {"title", "description", "cost"}),
	[21] = JS.O({
	title = "Hyper Boost Upgrade 21",
	description = "Hyper Boost Upgrade 12 is boosted.",
	cost = JS.D(33)
}, {"title", "description", "cost"}),
	[22] = JS.O({
	title = "Hyper Boost Upgrade 22",
	description = "Hyper Boost Upgrade 12 is boosted.",
	cost = JS.D(35)
}, {"title", "description", "cost"}),
	[23] = JS.O({
	title = "Hyper Boost Upgrade 23",
	description = "Hyper Boost Upgrade 12 is boosted.",
	cost = JS.D(40)
}, {"title", "description", "cost"}),
	[24] = JS.O({
	title = "Hyper Boost Upgrade 24",
	description = "Hyper Boost Upgrade 12 is boosted.",
	cost = JS.D(42)
}, {"title", "description", "cost"}),
	[31] = JS.O({
	title = "Hyper Boost Upgrade 31",
	unlocked = function(this)
	do return player.m.best:gte(178) end
end,
	description = "Hyper Boost Upgrade 12 is boosted by Hyper Boosts effect. To buy this upgrade, complete 8th AP Challenge 10 times.",
	effect = function(this)
	local exp = 0.3
	local p = layers.hb:effect():pow(exp):sub(1)
	do return p:toNumber() end
end,
	effectDisplay = function(this)
	do return ("+" .. JS.str(format(nil, this:effect(), 4))) end
end,
	cost = function(this)
	if (JS.tonum(player.ap.challenges[41]) < 10) then
		do return JS.D(math.huge) end
	else
		do return JS.D(78) end
	end
end
}, {"title", "unlocked", "description", "effect", "effectDisplay", "cost"}),
	[32] = JS.O({
	title = "Hyper Boost Upgrade 32",
	description = "Hyper Boosts effect is better. You can buy this upgrade while you're in AP challenge 8<br> and reached 1e790 Points.",
	cost = function(this)
	if (not JS.eq(player.ap.activeChallenge, 42)) then
		do return JS.D(math.huge) end
	elseif player.points:gte("1e790") then
		do return JS.D(79) end
	else
		do return JS.D(math.huge) end
	end
end,
	unlocked = function(this)
	do return player.m.best:gte(178) end
end
}, {"title", "description", "cost", "unlocked"}),
	[33] = JS.O({
	title = "Hyper Boost Upgrade 33",
	description = "Hyper Boost Upgrade 12 is boosted. To buy this upgrade, complete 8th AP Challenge 15.8 times.",
	cost = function(this)
	if (JS.tonum(player.ap.challenges[42]) < 15.8) then
		do return JS.D(math.huge) end
	else
		do return JS.D(80) end
	end
end,
	effect = function(this)
	local exp = 1.05
	local p = layers.hb:effect():pow(exp)
	do return p end
end,
	effectDisplay = function(this)
	do return ("x" .. JS.str(format(nil, this:effect(), 4))) end
end,
	unlocked = function(this)
	do return player.m.best:gte(178) end
end
}, {"title", "description", "cost", "effect", "effectDisplay", "unlocked"}),
	[34] = JS.O({
	title = "Hyper Boost Upgrade 34",
	description = "Hyper Boosts effect is better. You can buy this upgrade while you're in AP challenge 8<br> and reached 1e875 Points.",
	cost = function(this)
	if (not JS.eq(player.ap.activeChallenge, 42)) then
		do return JS.D(math.huge) end
	elseif player.points:gte("1e875") then
		do return JS.D(83) end
	else
		do return JS.D(math.huge) end
	end
end,
	unlocked = function(this)
	do return player.m.best:gte(178) end
end
}, {"title", "description", "cost", "unlocked"})
}, {"rows", "cols"}),
	resetsNothing = function(this)
	do return ((player.m.best:gte(111) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	doReset = function(this, l)
	if (l == "hb") then
		do return end
	end
	if (l == "t") then
		if player.m.best:gte(134) then
			layerDataReset(nil, "hb", JS.A(1, "upgrades"))
		else
			layerDataReset(nil, "hb", JS.A(0))
		end
	end
end,
	update = function(this)
	if player.m.best:gte(116) then
		local __g1 = 0
		while true do
			__g1 += 1; if __g1 > 5000000 then JS.runaway() end
			local req = layers.hb:requires():mul(layers.hb.base:pow(Decimal.pow(player.hb.points, layers.hb:exponent())))
			if player.hp.points:gt(req) then
				JS.setk(player.hb, "points", player.hb.points:add(1))
			else
				break
			end
		end
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "hotkeys", "layerShown", "branches", "softcap", "softcapPower", "base", "exponent", "effect", "effectDescription", "upgrades", "resetsNothing", "doReset", "update"}))

end
