--!nocheck
-- transpiled from layers/t.js by port/build.js: do not edit
return function()
-- transpiled from layers/t.js
addLayer(nil, "t", JS.O({
	name = "transcend",
	symbol = "T",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0),
		choose = JS.D(0),
		dChoose = false,
		sChoose = false,
		pdChoose = false,
		hChoose = false,
		sdChoose = false,
		phChoose = false,
		specialPoints = JS.O({
		[11] = JS.D(0),
		[12] = JS.D(0),
		[21] = JS.D(0),
		[22] = JS.D(0),
		[31] = JS.D(0),
		[32] = JS.D(0)
	}),
		highestAPC = JS.O({
		[0] = JS.O({
		[11] = 0,
		[12] = 0,
		[21] = 0,
		[22] = 0,
		[31] = 0,
		[32] = 0,
		[41] = 0,
		[42] = 0
	}),
		[11] = JS.O({
		[11] = 0,
		[12] = 0,
		[21] = 0,
		[22] = 0,
		[31] = 0,
		[32] = 0,
		[41] = 0,
		[42] = 0
	}),
		[12] = JS.O({
		[11] = 0,
		[12] = 0,
		[21] = 0,
		[22] = 0,
		[31] = 0,
		[32] = 0,
		[41] = 0,
		[42] = 0
	}),
		[21] = JS.O({
		[11] = 0,
		[12] = 0,
		[21] = 0,
		[22] = 0,
		[31] = 0,
		[32] = 0,
		[41] = 0,
		[42] = 0
	}),
		[22] = JS.O({
		[11] = 0,
		[12] = 0,
		[21] = 0,
		[22] = 0,
		[31] = 0,
		[32] = 0,
		[41] = 0,
		[42] = 0
	}),
		[31] = JS.O({
		[11] = 0,
		[12] = 0,
		[21] = 0,
		[22] = 0,
		[31] = 0,
		[32] = 0,
		[41] = 0,
		[42] = 0
	}),
		[32] = JS.O({
		[11] = 0,
		[12] = 0,
		[21] = 0,
		[22] = 0,
		[31] = 0,
		[32] = 0,
		[41] = 0,
		[42] = 0
	})
	})
	}, {"unlocked", "points", "choose", "dChoose", "sChoose", "pdChoose", "hChoose", "sdChoose", "phChoose", "specialPoints", "highestAPC"}) end
end,
	color = "#FFFF00",
	requires1 = function(this)
	if player.m.best:gte(156) then
		do return JS.D("1e400") end
	end
	if player.m.best:gte(137) then
		do return JS.D("1e640") end
	end
	do return JS.D("1e850") end
end,
	requires = function(this)
	if JS.t(player.t.activeChallenge) then
		do return JS.D(math.huge) end
	end
	do return tmp.t.requires1 end
end,
	resource = "transcend points",
	baseResource = "atomic-prestige points",
	baseAmount = function(this)
	do return player.ap.points end
end,
	type = "normal",
	row = 5,
	hotkeys = JS.A(1, JS.O({
	key = "t",
	description = "T: Reset for transcend points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(99) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	branches = JS.A(1, "ap"),
	softcap = JS.D(math.huge),
	softcapPower = JS.D(1),
	gainMult = function(this)
	local mult = JS.D(1)
	if player.mm.best:gte(21) then
		mult = mult:mul(2)
	end
	if player.mm.best:gte(22) then
		mult = mult:mul(2)
	end
	if player.mm.best:gte(23) then
		mult = mult:mul(2)
	end
	if player.mm.best:gte(24) then
		mult = mult:mul(2)
	end
	if player.mm.best:gte(25) then
		mult = mult:mul(tmp.mm.meta25Effect)
	end
	if hasUpgrade(nil, "pe", 21) then
		mult = mult:mul(upgradeEffect(nil, "pe", 21))
	end
	if hasUpgrade(nil, "t", 63) then
		mult = mult:mul(upgradeEffect(nil, "t", 63))
	end
	if (player.ep.buyables[11]:gte(2) and (not JS.t(player.t.activeChallenge))) then
		mult = mult:mul(tmp.ep.twoEffect)
	end
	if (not JS.isnil(player.t.activeChallenge)) then
		mult = mult:mul(tmp.ep.sixEffect)
	end
	do return mult end
end,
	getResetGain = function(this)
	if player.ap.points:lt(tmp.t.requires1) then
		do return JS.D(0) end
	end
	local amt = Decimal.log10(player.ap.points):sub(600):div(250):pow(2):mul(tmp.t.gainMult)
	amt = amt:floor()
	if JS.t(player.t.activeChallenge) then
		amt = softcap(nil, amt, JS.D(1e300), 0.01)
	end
	do return amt end
end,
	getNextAt = function(this)
	if player.ap.points:lt(tmp.t.requires1) then
		do return JS.D(tmp.t.requires1) end
	end
	local amt = Decimal.log10(player.ap.points):sub(600):div(250):pow(2):mul(tmp.t.gainMult)
	amt = amt:floor():plus(1):div(tmp.t.gainMult)
	amt = Decimal.pow(10, amt:pow((1 / 2)):mul(250):add(600))
	do return amt end
end,
	getNextSPAt = function(this)
	if (not JS.t(player.t.activeChallenge)) then
		do return JS.D(0) end
	end
	local amt = player.t.specialPoints[JS.k(player.t.activeChallenge)]:plus(1):div(tmp.t.gainMult)
	amt = Decimal.pow(10, amt:pow((1 / 2)):mul(250):add(600))
	if amt:lt(tmp.t.requires1) then
		do return JS.D(tmp.t.requires1) end
	end
	do return amt end
end,
	upgrades = JS.O({
	rows = 7,
	cols = 4,
	[11] = JS.O({
	title = "Transcend Upgrade 11",
	description = "Third Milestone's effect ^1.005",
	cost = JS.D(1)
}, {"title", "description", "cost"}),
	[12] = JS.O({
	title = "Transcend Upgrade 12",
	description = "Prestige Point gain ^1.005",
	cost = JS.D(1)
}, {"title", "description", "cost"}),
	[13] = JS.O({
	title = "Transcend Upgrade 13",
	description = "Super-Prestige Point gain ^1.005",
	cost = JS.D(1)
}, {"title", "description", "cost"}),
	[14] = JS.O({
	title = "Transcend Upgrade 14",
	description = "Hyper-Prestige Point gain ^1.005",
	cost = JS.D(1)
}, {"title", "description", "cost"}),
	[21] = JS.O({
	title = "Transcend Upgrade 21",
	description = "Prestige and Super-Prestige Upgrade 31 is boosted.",
	cost = JS.D(5)
}, {"title", "description", "cost"}),
	[22] = JS.O({
	title = "Transcend Upgrade 22",
	description = "Atomic-Prestige Point gain ^1.01",
	cost = JS.D(10)
}, {"title", "description", "cost"}),
	[23] = JS.O({
	title = "Transcend Upgrade 23",
	description = "Third Milestone's effect ^1.005",
	cost = JS.D(15)
}, {"title", "description", "cost"}),
	[24] = JS.O({
	title = "Transcend Upgrade 24",
	description = "Prestige Boost is cheaper",
	cost = JS.D(20)
}, {"title", "description", "cost"}),
	[31] = JS.O({
	title = "Transcend Upgrade 31",
	description = "Third Milestone's effect ^1.005",
	cost = JS.D(50)
}, {"title", "description", "cost"}),
	[32] = JS.O({
	title = "Transcend Upgrade 32",
	description = "Prestige Point gain ^1.005",
	cost = JS.D(75)
}, {"title", "description", "cost"}),
	[33] = JS.O({
	title = "Transcend Upgrade 33",
	description = "Super-Prestige Point gain ^1.005",
	cost = JS.D(100)
}, {"title", "description", "cost"}),
	[34] = JS.O({
	title = "Transcend Upgrade 34",
	description = "Hyper-Prestige Point gain ^1.005",
	cost = JS.D(125)
}, {"title", "description", "cost"}),
	[41] = JS.O({
	title = "Transcend Upgrade 41",
	description = function(this)
	do return ("Hyper Boost cost /" .. JS.str(format(nil, "1e60000"))) end
end,
	cost = JS.D(300),
	unlocked = function(this)
	do return player.m.best:gte(104) end
end
}, {"title", "description", "cost", "unlocked"}),
	[42] = JS.O({
	title = "Transcend Upgrade 42",
	description = function(this)
	do return "Gain an extra Hyper Boost." end
end,
	cost = JS.D(400),
	unlocked = function(this)
	do return player.m.best:gte(104) end
end
}, {"title", "description", "cost", "unlocked"}),
	[43] = JS.O({
	title = "Transcend Upgrade 43",
	description = function(this)
	do return "Hyper Boost's effect is better." end
end,
	cost = JS.D(500),
	unlocked = function(this)
	do return player.m.best:gte(104) end
end
}, {"title", "description", "cost", "unlocked"}),
	[44] = JS.O({
	title = "Transcend Upgrade 44",
	description = function(this)
	do return "Unlock a new row of Atomic-Prestige upgrades." end
end,
	cost = JS.D(600),
	unlocked = function(this)
	do return player.m.best:gte(104) end
end
}, {"title", "description", "cost", "unlocked"}),
	[51] = JS.O({
	title = "Transcend Upgrade 51",
	description = function(this)
	do return "First HP buyable's effect ^2.1" end
end,
	cost = JS.D(30000),
	unlocked = function(this)
	do return player.m.best:gte(111) end
end
}, {"title", "description", "cost", "unlocked"}),
	[52] = JS.O({
	title = "Transcend Upgrade 52",
	description = function(this)
	do return "Milestone cost scaling starts later based on your transcend points." end
end,
	cost = JS.D(60000),
	unlocked = function(this)
	do return player.m.best:gte(111) end
end,
	effect = function(this)
	do return (JS.D(9)):plus(player.t.points:add(10):log10():sqrt():mul(1.2)) end
end,
	effectDisplay = function(this)
	do return ("+" .. JS.str(format(nil, this:effect(), 4))) end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[53] = JS.O({
	title = "Transcend Upgrade 53",
	description = function(this)
	do return "Reduce the 1st Milestone's softcap's potency." end
end,
	cost = JS.D(2000000),
	unlocked = function(this)
	do return player.m.best:gte(111) end
end
}, {"title", "description", "cost", "unlocked"}),
	[54] = JS.O({
	title = "Transcend Upgrade 54",
	description = function(this)
	do return "1st Milestone's softcap starts later based on your transcend points." end
end,
	cost = JS.D(10000000),
	unlocked = function(this)
	do return player.m.best:gte(111) end
end,
	effect = function(this)
	local p = 0.8
	local m = 0.05
	if player.m.best:gte(128) then
		p = JS.add(p, 0.1)
	end
	local eff = player.t.points:add(10):log10():pow(p):mul(m)
	eff = softcap(nil, eff, JS.D(1e70), 0.01)
	do return (JS.D(1)):plus(eff) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[61] = JS.O({
	title = "Transcend Upgrade 61",
	description = function(this)
	do return "All Dilation Effects +0.05" end
end,
	cost = JS.D(10000000000),
	unlocked = function(this)
	do return player.m.best:gte(125) end
end
}, {"title", "description", "cost", "unlocked"}),
	[62] = JS.O({
	title = "Transcend Upgrade 62",
	description = function(this)
	do return "Atomic-Prestige point gain is boosted based on your transcend points." end
end,
	cost = JS.D(100000000000),
	unlocked = function(this)
	do return player.m.best:gte(125) end
end,
	effect = function(this)
	local base = 80
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[63] = JS.O({
	title = "Transcend Upgrade 63",
	description = function(this)
	do return "Transcend point gain is boosted based on your transcend points." end
end,
	cost = JS.D(1000000000000),
	unlocked = function(this)
	do return player.m.best:gte(125) end
end,
	effect = function(this)
	local base = 1.05
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[64] = JS.O({
	title = "Transcend Upgrade 64",
	description = function(this)
	do return ("Hyper Boost cost /" .. JS.str(format(nil, "1e300000"))) end
end,
	cost = JS.D(4000000000000),
	unlocked = function(this)
	do return player.m.best:gte(125) end
end
}, {"title", "description", "cost", "unlocked"}),
	[71] = JS.O({
	title = "Transcend Upgrade 71",
	description = function(this)
	do return ("Hyper Boost cost /" .. JS.str(format(nil, "1e30000"))) end
end,
	cost = JS.D(10000000000000),
	unlocked = function(this)
	do return player.m.best:gte(136) end
end
}, {"title", "description", "cost", "unlocked"}),
	[72] = JS.O({
	title = "Transcend Upgrade 72",
	description = function(this)
	do return "Meta-Milestones are cheaper based on Transcend Points." end
end,
	cost = JS.D(20000000000000),
	unlocked = function(this)
	do return player.m.best:gte(136) end
end,
	effect = function(this)
	local p = 0.5
	local m = 0.01
	if hasUpgrade(nil, "t", 74) then
		m = JS.add(m, 0.01)
	end
	local eff = player.t.points:add(10):log10():pow(p):mul(m)
	do return (JS.D(1)):plus(softcap(nil, eff, JS.D(1.4), 0.25)) end
end,
	effectDisplay = function(this)
	do return ("/" .. JS.str(format(nil, this:effect(), 4))) end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[73] = JS.O({
	title = "Transcend Upgrade 73",
	description = function(this)
	do return "1st Milestone's softcap starts later based on AP challenge completions." end
end,
	cost = JS.D(100000000000000),
	unlocked = function(this)
	do return player.m.best:gte(136) end
end,
	effect = function(this)
	local i
	local c = 0
	for _, __k1 in JS.keys(player.ap.challenges) do
		i = __k1
		c = JS.add(c, player.ap.challenges[i])
	end
	local p = 2
	if hasUpgrade(nil, "t", 74) then
		p = JS.add(p, 0.1)
	end
	local m = 0.00001
	local eff = (JS.D(c)):pow(p):mul(m)
	do return (JS.D(1)):plus(eff) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x later") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[74] = JS.O({
	title = "Transcend Upgrade 74",
	description = function(this)
	do return "Transcend Upgrade 72 and 73 are boosted." end
end,
	cost = JS.D(400000000000000),
	unlocked = function(this)
	do return player.m.best:gte(136) end
end
}, {"title", "description", "cost", "unlocked"})
}, {"rows", "cols"}),
	clickables = JS.O({
	[11] = JS.O({
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 12) or player.mp.buyables[13]:gte(1)) end
end,
	title = function(this)
	do return (if (not JS.eq(player.mp.activeChallenge, 12)) then "Boost Dilated Points" else "Choose Dilated Points") end
end,
	display = function(this)
	do return ("Status:" .. JS.str((if JS.eq(player.t.dChoose, true) then " Chosen" else " Not Chosen"))) end
end,
	canClick = function(this)
	if ((player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) and JS.eq(player.t.dChoose, false)) then
		do return player.mp.perkPoints:gte(1) end
	else
		do return player.t.choose:gte(1) end
	end
end,
	onClick = function(this)
	if (player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) then
		JS.setk(player.mp, "perkPoints", player.mp.perkPoints:sub(1))
	else
		JS.setk(player.t, "choose", player.t.choose:sub(1))
	end
	JS.setk(player.t, "dChoose", true)
end,
	style = JS.O({
	width = "300px",
	minHeight = "30px"
}, {"width", "minHeight"})
}, {"unlocked", "title", "display", "canClick", "onClick", "style"}),
	[12] = JS.O({
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 12) or player.mp.buyables[13]:gte(1)) end
end,
	title = function(this)
	do return (if (not JS.eq(player.mp.activeChallenge, 12)) then "Boost Softcapped Points" else "Choose Softcapped Points") end
end,
	display = function(this)
	do return ("Status:" .. JS.str((if JS.eq(player.t.sChoose, true) then " Chosen" else " Not Chosen"))) end
end,
	canClick = function(this)
	if ((player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) and JS.eq(player.t.sChoose, false)) then
		do return player.mp.perkPoints:gte(1) end
	else
		do return player.t.choose:gte(1) end
	end
end,
	onClick = function(this)
	if (player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) then
		JS.setk(player.mp, "perkPoints", player.mp.perkPoints:sub(1))
	else
		JS.setk(player.t, "choose", player.t.choose:sub(1))
	end
	JS.setk(player.t, "sChoose", true)
end,
	style = JS.O({
	width = "300px",
	minHeight = "30px"
}, {"width", "minHeight"})
}, {"unlocked", "title", "display", "canClick", "onClick", "style"}),
	[21] = JS.O({
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 12) or player.mp.buyables[13]:gte(1)) end
end,
	title = function(this)
	do return (if (not JS.eq(player.mp.activeChallenge, 12)) then "Boost Prestige-Dilated Points" else "Choose Prestige-Dilated Points") end
end,
	display = function(this)
	do return ("Status:" .. JS.str((if JS.eq(player.t.pdChoose, true) then " Chosen" else " Not Chosen"))) end
end,
	canClick = function(this)
	if ((player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) and JS.eq(player.t.pdChoose, false)) then
		do return player.mp.perkPoints:gte(1) end
	else
		do return player.t.choose:gte(1) end
	end
end,
	onClick = function(this)
	if (player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) then
		JS.setk(player.mp, "perkPoints", player.mp.perkPoints:sub(1))
	else
		JS.setk(player.t, "choose", player.t.choose:sub(1))
	end
	JS.setk(player.t, "pdChoose", true)
end,
	style = JS.O({
	width = "300px",
	minHeight = "30px"
}, {"width", "minHeight"})
}, {"unlocked", "title", "display", "canClick", "onClick", "style"}),
	[22] = JS.O({
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 12) or player.mp.buyables[13]:gte(1)) end
end,
	title = function(this)
	do return (if (not JS.eq(player.mp.activeChallenge, 12)) then "Boost Hardcapped Points" else "Choose Hardcapped Points") end
end,
	display = function(this)
	do return ("Status:" .. JS.str((if JS.eq(player.t.hChoose, true) then " Chosen" else " Not Chosen"))) end
end,
	canClick = function(this)
	if ((player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) and JS.eq(player.t.hChoose, false)) then
		do return player.mp.perkPoints:gte(1) end
	else
		do return player.t.choose:gte(1) end
	end
end,
	onClick = function(this)
	if (player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) then
		JS.setk(player.mp, "perkPoints", player.mp.perkPoints:sub(1))
	else
		JS.setk(player.t, "choose", player.t.choose:sub(1))
	end
	JS.setk(player.t, "hChoose", true)
end,
	style = JS.O({
	width = "300px",
	minHeight = "30px"
}, {"width", "minHeight"})
}, {"unlocked", "title", "display", "canClick", "onClick", "style"}),
	[31] = JS.O({
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 12) or player.mp.buyables[13]:gte(1)) end
end,
	title = function(this)
	do return (if (not JS.eq(player.mp.activeChallenge, 12)) then "Boost Super-Dilated Points" else "Choose Super-Dilated Points") end
end,
	display = function(this)
	do return ("Status:" .. JS.str((if JS.eq(player.t.sdChoose, true) then " Chosen" else " Not Chosen"))) end
end,
	canClick = function(this)
	if ((player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) and JS.eq(player.t.sdChoose, false)) then
		do return player.mp.perkPoints:gte(1) end
	else
		do return player.t.choose:gte(1) end
	end
end,
	onClick = function(this)
	if (player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) then
		JS.setk(player.mp, "perkPoints", player.mp.perkPoints:sub(1))
	else
		JS.setk(player.t, "choose", player.t.choose:sub(1))
	end
	JS.setk(player.t, "sdChoose", true)
end,
	style = JS.O({
	width = "300px",
	minHeight = "30px"
}, {"width", "minHeight"})
}, {"unlocked", "title", "display", "canClick", "onClick", "style"}),
	[32] = JS.O({
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 12) or player.mp.buyables[13]:gte(1)) end
end,
	title = function(this)
	do return (if (not JS.eq(player.mp.activeChallenge, 12)) then "Boost Prestige-Hardcapped Points" else "Choose Prestige-Hardcapped Points") end
end,
	display = function(this)
	do return ("Status:" .. JS.str((if JS.eq(player.t.phChoose, true) then " Chosen" else " Not Chosen"))) end
end,
	canClick = function(this)
	if ((player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) and JS.eq(player.t.phChoose, false)) then
		do return player.mp.perkPoints:gte(1) end
	else
		do return player.t.choose:gte(1) end
	end
end,
	onClick = function(this)
	if (player.mp.buyables[13]:gte(1) and (not JS.eq(player.mp.activeChallenge, 12))) then
		JS.setk(player.mp, "perkPoints", player.mp.perkPoints:sub(1))
	else
		JS.setk(player.t, "choose", player.t.choose:sub(1))
	end
	JS.setk(player.t, "phChoose", true)
end,
	style = JS.O({
	width = "300px",
	minHeight = "30px"
}, {"width", "minHeight"})
}, {"unlocked", "title", "display", "canClick", "onClick", "style"}),
	[41] = JS.O({
	unlocked = function(this)
	do return true end
end,
	title = function(this)
	do return "Respec" end
end,
	canClick = function(this)
	do return true end
end,
	onClick = function(this)
	if JS.eq(player.mp.activeChallenge, 12) then
		JS.setk(player.t, "choose", JS.D(2))
		JS.setk(player.t, "dChoose", false)
		JS.setk(player.t, "sChoose", false)
		JS.setk(player.t, "pdChoose", false)
		JS.setk(player.t, "hChoose", false)
		JS.setk(player.t, "sdChoose", false)
		JS.setk(player.t, "phChoose", false)
	else
		layerDataReset(nil, "pp", JS.A(1, "upgrades"))
		layerDataReset(nil, "ep", JS.A(2, "upgrades", "buyables"))
		layerDataReset(nil, "t", JS.A(2, "upgrades", "challenges"))
		JS.setk(player.mp, "perkPoints", player.mp.buyables[13])
	end
end,
	style = JS.O({
	width = "300px",
	minHeight = "30px"
}, {"width", "minHeight"})
}, {"unlocked", "title", "canClick", "onClick", "style"})
}),
	challenges = JS.O({
	rows = 3,
	cols = 2,
	[11] = JS.O({
	name = "Dilation",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (((("1st milestone's effect ^" .. JS.str(format(nil, tmp.t.dilationEffect))) .. "<br>") .. JS.str(challengeCompletions(nil, this.layer, this.id))) .. " completions") end
end,
	unlocked = function(this)
	do return true end
end,
	goal = function(this)
	local x = (JS.tonum(JS.add(player.t.challenges[11], 1)) * JS.tonum(JS.add(player.t.challenges[11], 1)))
	if hasUpgrade(nil, "ep", 21) then
		x = (JS.tonum(x) - JS.tonum(upgradeEffect(nil, "ep", 21)))
	end
	if (JS.tonum(player.t.challenges[11]) >= 19) then
		do return (JS.tonum(x) * 1.15) end
	end
	if player.m.best:gte(110) then
		do return x end
	else
		do return (2 * Math.pow(3, player.t.challenges[11])) end
	end
end,
	canComplete = function(this)
	local i
	local c = 0
	for _, __k2 in JS.keys(player.ap.challenges) do
		i = __k2
		c = JS.add(c, player.ap.challenges[i])
	end
	if JS.cmp(c, ">=", tmp.t.challenges[JS.k(this.id)].goal) then
		do return true end
	end
	do return false end
end,
	currencyDisplayName = "AP challenge completions",
	rewardDescription = function(this)
	do return "3rd milestone's effect is better." end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "currencyDisplayName", "rewardDescription"}),
	[12] = JS.O({
	name = "Softcapped",
	completionLimit = function(this)
	if player.em.points:gte(15) then
		do return JS.D(20) end
	else
		do return math.huge end
	end
end,
	challengeDescription = function(this)
	do return (("1st milestone's softcap starts earlier<br>" .. JS.str(challengeCompletions(nil, this.layer, this.id))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(104) end
end,
	goal = function(this)
	do return (JS.tonum(JS.add(player.t.challenges[12], 1)) * JS.tonum(JS.add(player.t.challenges[12], 1))) end
end,
	canComplete = function(this)
	local i
	local c = 0
	for _, __k3 in JS.keys(player.ap.challenges) do
		i = __k3
		c = JS.add(c, player.ap.challenges[i])
	end
	if JS.cmp(c, ">=", tmp.t.challenges[JS.k(this.id)].goal) then
		do return true end
	end
	do return false end
end,
	rewardEffect = function(this)
	if (player.m.points:lt(112) and JS.eq(player.t.activeChallenge, 12)) then
		do return 1 end
	end
	local ret = (1 + (JS.tonum(player.t.challenges[12]) * 0.1))
	if player.em.best:gte(15) then
		ret = (JS.tonum(ret) * 1.01)
	end
	do return ret end
end,
	rewardDisplay = function(this)
	do return (JS.str(format(nil, this:rewardEffect())) .. "x later") end
end,
	currencyDisplayName = "AP challenge completions",
	rewardDescription = function(this)
	if player.m.points:lt(112) then
		do return "1st milestone's softcap starts later, but the reward is disabled in this challenge." end
	else
		do return "1st milestone's softcap starts later." end
	end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "rewardEffect", "rewardDisplay", "currencyDisplayName", "rewardDescription"}),
	[21] = JS.O({
	name = "Prestige Dilation",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (((("1st milestone's effect and prestige point gain ^" .. JS.str(format(nil, tmp.t.dilationEffect))) .. "<br>") .. JS.str(challengeCompletions(nil, this.layer, this.id))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(109) end
end,
	goal = function(this)
	local x = (JS.tonum(JS.add(player.t.challenges[21], 1)) * JS.tonum(JS.add(player.t.challenges[21], 1)))
	if hasUpgrade(nil, "ep", 21) then
		x = (JS.tonum(x) - JS.tonum(upgradeEffect(nil, "ep", 21)))
	end
	if (JS.tonum(player.t.challenges[21]) >= 19) then
		do return (JS.tonum(x) * 1.15) end
	end
	do return x end
end,
	canComplete = function(this)
	local i
	local c = 0
	for _, __k4 in JS.keys(player.ap.challenges) do
		i = __k4
		c = JS.add(c, player.ap.challenges[i])
	end
	if JS.cmp(c, ">=", tmp.t.challenges[JS.k(this.id)].goal) then
		do return true end
	end
	do return false end
end,
	currencyDisplayName = "AP challenge completions",
	rewardDescription = function(this)
	do return "3rd milestone's effect is better." end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "currencyDisplayName", "rewardDescription"}),
	[22] = JS.O({
	name = "Hardcapped",
	completionLimit = function(this)
	if player.em.points:gte(16) then
		do return JS.D(12) end
	else
		do return math.huge end
	end
end,
	challengeDescription = function(this)
	do return (("'Softcapped' is applied, and 1st milestone's softcap is its hardcap.<br>" .. JS.str(challengeCompletions(nil, this.layer, this.id))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(115) end
end,
	goal = function(this)
	do return (JS.tonum(JS.add(player.t.challenges[22], 1)) * JS.tonum(JS.add(player.t.challenges[22], 1))) end
end,
	canComplete = function(this)
	local i
	local c = 0
	for _, __k5 in JS.keys(player.ap.challenges) do
		i = __k5
		c = JS.add(c, player.ap.challenges[i])
	end
	if JS.cmp(c, ">=", tmp.t.challenges[JS.k(this.id)].goal) then
		do return true end
	end
	do return false end
end,
	rewardEffect = function(this)
	local ret = (1 + (JS.tonum(player.t.challenges[22]) * 0.1))
	if player.em.best:gte(16) then
		ret = (JS.tonum(ret) * 1.05)
	end
	do return ret end
end,
	rewardDisplay = function(this)
	do return (JS.str(format(nil, this:rewardEffect())) .. "x later") end
end,
	currencyDisplayName = "AP challenge completions",
	rewardDescription = function(this)
	do return "1st milestone's softcap starts later." end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "rewardEffect", "rewardDisplay", "currencyDisplayName", "rewardDescription"}),
	[31] = JS.O({
	name = "Super Dilation",
	completionLimit = math.huge,
	challengeDescription = function(this)
	do return (((("1st milestone's effect, prestige point gain and super-prestige point gain ^" .. JS.str(format(nil, tmp.t.dilationEffect))) .. "<br>") .. JS.str(challengeCompletions(nil, this.layer, this.id))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(125) end
end,
	goal = function(this)
	local x = (JS.tonum(JS.add(player.t.challenges[31], 1)) * JS.tonum(JS.add(player.t.challenges[31], 1)))
	if hasUpgrade(nil, "ep", 21) then
		x = (JS.tonum(x) - JS.tonum(upgradeEffect(nil, "ep", 21)))
	end
	if (JS.tonum(player.t.challenges[31]) >= 19) then
		do return (JS.tonum(x) * 1.15) end
	end
	do return x end
end,
	canComplete = function(this)
	local i
	local c = 0
	for _, __k6 in JS.keys(player.ap.challenges) do
		i = __k6
		c = JS.add(c, player.ap.challenges[i])
	end
	if JS.cmp(c, ">=", tmp.t.challenges[JS.k(this.id)].goal) then
		do return true end
	end
	do return false end
end,
	currencyDisplayName = "AP challenge completions",
	rewardDescription = function(this)
	do return "3rd milestone's effect is better." end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "currencyDisplayName", "rewardDescription"}),
	[32] = JS.O({
	name = "Prestige Hardcapped",
	completionLimit = function(this)
	if player.em.points:gte(17) then
		do return JS.D(12) end
	else
		do return math.huge end
	end
end,
	challengeDescription = function(this)
	do return (("'Hardcapped' is applied, and prestige point gain is affected by 1st Milestone's softcap<br>" .. JS.str(challengeCompletions(nil, this.layer, this.id))) .. " completions") end
end,
	unlocked = function(this)
	do return player.m.best:gte(137) end
end,
	goal = function(this)
	do return (JS.tonum(JS.add(player.t.challenges[32], 1)) * JS.tonum(JS.add(player.t.challenges[32], 1))) end
end,
	canComplete = function(this)
	local i
	local c = 0
	for _, __k7 in JS.keys(player.ap.challenges) do
		i = __k7
		c = JS.add(c, player.ap.challenges[i])
	end
	if JS.cmp(c, ">=", tmp.t.challenges[JS.k(this.id)].goal) then
		do return true end
	end
	do return false end
end,
	rewardEffect = function(this)
	local ret = (1 + (JS.tonum(player.t.challenges[32]) * 0.1))
	if player.em.best:gte(17) then
		ret = (JS.tonum(ret) * 1.05)
	end
	do return ret end
end,
	rewardDisplay = function(this)
	do return (JS.str(format(nil, this:rewardEffect())) .. "x later") end
end,
	currencyDisplayName = "AP challenge completions",
	rewardDescription = function(this)
	do return "1st milestone's softcap starts later." end
end
}, {"name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "rewardEffect", "rewardDisplay", "currencyDisplayName", "rewardDescription"})
}, {"rows", "cols"}),
	passiveGeneration = function(this)
	if JS.t(player.t.activeChallenge) then
		do return 0 end
	end
	if player.m.best:gte(133) then
		do return 1 end
	end
	if player.m.best:gte(130) then
		do return 0.8 end
	end
	if player.m.best:gte(127) then
		do return 0.6 end
	end
	if player.m.best:gte(123) then
		do return 0.45 end
	end
	if player.m.best:gte(120) then
		do return 0.3 end
	end
	if player.m.best:gte(119) then
		do return 0.2 end
	end
	if player.m.best:gte(118) then
		do return 0.1 end
	end
	if player.m.best:gte(117) then
		do return 0.05 end
	end
	if player.m.best:gte(116) then
		do return 0.02 end
	end
	if player.m.best:gte(115) then
		do return 0.01 end
	end
	if player.m.best:gte(113) then
		do return 0.005 end
	end
	if player.m.best:gte(110) then
		do return 0.002 end
	end
	do return 0 end
end,
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(7, "main-display", "prestige-button", "resource-display", JS.A(2, "display-text", function(this)
	local cap = JS.D(1e70)
	if player.m.best:gte(169) then
		cap = JS.D(1e90)
	end
	if player.ep.buyables[11]:gte(4) then
		cap = cap:mul(tmp.ep.fourEffect)
	end
	do return ("Transcend point is hardcapped at " .. JS.str(format(nil, cap))) end
end), JS.A(2, "display-text", function(this)
	do return "AP challenge is applied after T challenge, softcap is applied after AP challenge" end
end), JS.A(2, "display-text", function(this)
	local i
	local c = 0
	for _, __k8 in JS.keys(player.ap.challenges) do
		i = __k8
		c = JS.add(c, player.ap.challenges[i])
	end
	do return ("AP challenge completions: " .. JS.str(format(nil, c, 4))) end
end), "challenges")
}),
	Upgrades = JS.O({
	content = JS.A(4, "main-display", "prestige-button", "resource-display", "upgrades")
}),
	["Special Transcend Points"] = JS.O({
	content = JS.A(18, "main-display", JS.A(2, "display-text", function(this)
	do return (("Reach " .. JS.str(format(nil, tmp.t.requires1))) .. " atomic-prestige points in a Transcend Challenge to gain Special Transcend Points!") end
end), function(this)
	if (not JS.t(player.t.activeChallenge)) then
		do return JS.A(2, "display-text", "") end
	end
	do return "resource-display" end
end, JS.A(2, "display-text", function(this)
	if ((not JS.t(player.t.activeChallenge)) or player.t.specialPoints[JS.k(player.t.activeChallenge)]:gte(1000000)) then
		do return "" end
	end
	do return (((("Next " .. JS.str(layers.t:getSpecialTPName(player.t.activeChallenge))) .. " at ") .. JS.str(format(nil, tmp.t.getNextSPAt))) .. " atomic-prestige points") end
end), JS.A(2, "display-text", function(this)
	do return ((("You have " .. JS.str(format(nil, player.t.specialPoints[11]))) .. " Dilated Transcend Points, 3rd Milestone's effect ^") .. JS.str(format(nil, layers.t:getSpecialEffect(11), 4))) end
end), JS.A(2, "clickable", 11), JS.A(2, "display-text", function(this)
	do return (((("You have " .. JS.str(format(nil, player.t.specialPoints[12]))) .. " Softcapped Transcend Points, 1st Milestone's softcap starts ") .. JS.str(format(nil, layers.t:getSpecialEffect(12), 4))) .. "x later") end
end), JS.A(2, "clickable", 12), JS.A(2, "display-text", function(this)
	do return ((("You have " .. JS.str(format(nil, player.t.specialPoints[21]))) .. " Prestige-Dilated Transcend Points, Prestige Point gain ^") .. JS.str(format(nil, layers.t:getSpecialEffect(21), 4))) end
end), JS.A(2, "clickable", 21), JS.A(2, "display-text", function(this)
	do return (((("You have " .. JS.str(format(nil, player.t.specialPoints[22]))) .. " Hardcapped Transcend Points, 1st Milestone's softcap starts ") .. JS.str(format(nil, layers.t:getSpecialEffect(22), 4))) .. "x later") end
end), JS.A(2, "clickable", 22), JS.A(2, "display-text", function(this)
	do return (((("You have " .. JS.str(format(nil, player.t.specialPoints[31]))) .. " Super-Dilated Transcend Points, 154th Milestone effect is ^") .. JS.str(format(nil, layers.t:getSpecialEffect(31), 4))) .. " better") end
end), JS.A(2, "clickable", 31), JS.A(2, "display-text", function(this)
	do return (((("You have " .. JS.str(format(nil, player.t.specialPoints[32]))) .. " Prestige-Hardcapped Transcend Points, 6th Milestone effect is ^") .. JS.str(format(nil, layers.t:getSpecialEffect(32), 4))) .. " better") end
end), JS.A(2, "clickable", 32), "blank", JS.A(2, "clickable", 41)),
	unlocked = function(this)
	do return player.m.best:gte(130) end
end
}, {"content", "unlocked"})
}, {"Main", "Upgrades", "Special Transcend Points"}),
	update = function(this)
	local i
	if player.em.best:gte(9) then
		if player.t.specialPoints[11]:lt(layers.t:getResetGain()) then
			JS.set(player.t.specialPoints, 11, layers.t:getResetGain():add(1):log(5):mul("1e35"):mul(tmp.ep.sixEffect))
		end
	end
	if player.em.best:gte(10) then
		if player.t.specialPoints[12]:lt(layers.t:getResetGain()) then
			JS.set(player.t.specialPoints, 12, layers.t:getResetGain():add(1):log(5):mul("1e30"):mul(tmp.ep.sixEffect))
		end
	end
	if player.em.best:gte(11) then
		if player.t.specialPoints[21]:lt(layers.t:getResetGain()) then
			JS.set(player.t.specialPoints, 21, layers.t:getResetGain():add(1):log(7):mul("1e34"):mul(tmp.ep.sixEffect))
		end
	end
	if player.em.best:gte(12) then
		if player.t.specialPoints[22]:lt(layers.t:getResetGain()) then
			JS.set(player.t.specialPoints, 22, layers.t:getResetGain():add(1):log(3):mul("1e35"):mul(tmp.ep.sixEffect))
		end
	end
	if player.em.best:gte(13) then
		if player.t.specialPoints[31]:lt(layers.t:getResetGain()) then
			JS.set(player.t.specialPoints, 31, layers.t:getResetGain():add(1):log(2):mul("1e30"):mul(tmp.ep.sixEffect))
		end
	end
	if player.em.best:gte(14) then
		if player.t.specialPoints[32]:lt(layers.t:getResetGain()) then
			JS.set(player.t.specialPoints, 32, layers.t:getResetGain():add(1):log(2):mul("1e28"):mul(tmp.ep.sixEffect))
		end
	end
	local cap = JS.D(1e70)
	if player.m.best:gte(169) then
		cap = JS.D(1e90)
	end
	if player.ep.buyables[11]:gte(4) then
		cap = cap:mul(tmp.ep.fourEffect)
	end
	if JS.eq(player.mp.activeChallenge, 13) then
		cap = JS.D(10000000000)
	end
	if player.t.points:gte(cap) then
		JS.setk(player.t, "points", JS.D(cap))
	end
	if (player.m.best:gte(130) and JS.t(player.t.activeChallenge)) then
		if player.t.specialPoints[JS.k(player.t.activeChallenge)]:lt(layers.t:getResetGain()) then
			JS.set(player.t.specialPoints, JS.k(player.t.activeChallenge), layers.t:getResetGain())
		end
	end
	if (player.m.best:gte(140) and JS.t(player.t.activeChallenge)) then
		if (JS.t(layers.t.challenges[JS.k(player.t.activeChallenge)]:canComplete()) and (JS.D(player.t.challenges[JS.k(player.t.activeChallenge)])):lt(tmp.t.challenges[JS.k(player.t.activeChallenge)].completionLimit)) then
			JS.set(player.t.challenges, JS.k(player.t.activeChallenge), (JS.tonum(player.t.challenges[JS.k(player.t.activeChallenge)]) + 1))
		end
	end
	if player.m.best:gte(147) then
		local c = 0
		for _, __k9 in JS.keys(player.ap.challenges) do
			i = __k9
			c = JS.add(c, player.ap.challenges[i])
		end
		if JS.cmp(c, ">=", tmp.t.challenges[11].goal) then
			do return (function() local __v10 = player.t.challenges[11]; JS.set(player.t.challenges, 11, (__v10 + 1)) return __v10 end)() end
		end
		if (JS.cmp(c, ">=", tmp.t.challenges[12].goal) and (JS.D(player.t.challenges[12])):lt(tmp.t.challenges[12].completionLimit)) then
			do return (function() local __v11 = player.t.challenges[12]; JS.set(player.t.challenges, 12, (__v11 + 1)) return __v11 end)() end
		end
	end
	if player.em.best:gte(18) then
		local c = 0
		for _, __k12 in JS.keys(player.ap.challenges) do
			i = __k12
			c = JS.add(c, player.ap.challenges[i])
		end
		if JS.cmp(c, ">=", tmp.t.challenges[21].goal) then
			do return (function() local __v13 = player.t.challenges[21]; JS.set(player.t.challenges, 21, (__v13 + 1)) return __v13 end)() end
		end
	end
	if player.em.best:gte(19) then
		local c = 0
		for _, __k14 in JS.keys(player.ap.challenges) do
			i = __k14
			c = JS.add(c, player.ap.challenges[i])
		end
		if JS.cmp(c, ">=", tmp.t.challenges[31].goal) then
			do return (function() local __v15 = player.t.challenges[31]; JS.set(player.t.challenges, 31, (__v15 + 1)) return __v15 end)() end
		end
	end
end,
	dilationEffect = function(this)
	local eff = 0.45
	if hasUpgrade(nil, "t", 61) then
		eff = JS.add(eff, 0.05)
	end
	do return eff end
end,
	getSpecialTPName = function(this, x)
	if JS.eq(x, 11) then
		do return "Dilated Transcend Point" end
	end
	if JS.eq(x, 12) then
		do return "Softcapped Transcend Point" end
	end
	if JS.eq(x, 21) then
		do return "Prestige-Dilated Transcend Point" end
	end
	if JS.eq(x, 22) then
		do return "Hardcapped Transcend Point" end
	end
	if JS.eq(x, 31) then
		do return "Super-Dilated Transcend Point" end
	end
	if JS.eq(x, 32) then
		do return "Prestige-Hardcapped Transcend Point" end
	end
end,
	getSpecialEffect = function(this, x)
	if JS.eq(x, 11) then
		local effect = player.t.specialPoints[11]:add(1):log10():div(100):add(1)
		if ((not JS.eq(player.t.dChoose, true)) and JS.eq(player.mp.activeChallenge, 12)) then
			do return JS.D(1) end
		end
		if ((JS.eq(player.t.dChoose, true) and player.mp.buyables[13]:gte(1)) and (not JS.eq(player.mp.activeChallenge, 12))) then
			effect = effect:add(5)
		end
		do return softcap(nil, effect, JS.D(1.4), 0.1) end
	end
	if JS.eq(x, 12) then
		local effect = player.t.specialPoints[12]:add(1):log10():div(100):add(1)
		if ((not JS.eq(player.t.sChoose, true)) and JS.eq(player.mp.activeChallenge, 12)) then
			do return JS.D(1) end
		end
		if ((JS.eq(player.t.sChoose, true) and player.mp.buyables[13]:gte(1)) and (not JS.eq(player.mp.activeChallenge, 12))) then
			effect = effect:add(5)
		end
		do return softcap(nil, effect, JS.D(1.4), 0.1) end
	end
	if JS.eq(x, 21) then
		local effect = player.t.specialPoints[21]:add(1):log10():div(100):add(1)
		if ((not JS.eq(player.t.pdChoose, true)) and JS.eq(player.mp.activeChallenge, 12)) then
			do return JS.D(1) end
		end
		if ((JS.eq(player.t.pdChoose, true) and player.mp.buyables[13]:gte(1)) and (not JS.eq(player.mp.activeChallenge, 12))) then
			effect = effect:add(0.1)
		end
		do return effect end
	end
	if JS.eq(x, 22) then
		local effect = player.t.specialPoints[22]:add(1):log10():div(100):add(1)
		if ((not JS.eq(player.t.hChoose, true)) and JS.eq(player.mp.activeChallenge, 12)) then
			do return JS.D(1) end
		end
		if ((JS.eq(player.t.hChoose, true) and player.mp.buyables[13]:gte(1)) and (not JS.eq(player.mp.activeChallenge, 12))) then
			effect = effect:add(0.1)
		end
		do return softcap(nil, effect, JS.D(1.35), 0.1) end
	end
	if JS.eq(x, 31) then
		local effect = player.t.specialPoints[31]:add(1):log10():div(25):add(1)
		if (not hasUpgrade(nil, "pp", 21)) then
			do return JS.D(1) end
		end
		if ((not JS.eq(player.t.sdChoose, true)) and JS.eq(player.mp.activeChallenge, 12)) then
			do return JS.D(1) end
		end
		if ((JS.eq(player.t.sdChoose, true) and player.mp.buyables[13]:gte(1)) and (not JS.eq(player.mp.activeChallenge, 12))) then
			effect = effect:add(0.25)
		end
		do return effect:max(1) end
	end
	if JS.eq(x, 32) then
		local effect = player.t.specialPoints[32]:add(1):log10():div(100):add(1)
		if (not hasUpgrade(nil, "pp", 22)) then
			do return JS.D(1) end
		end
		if ((not JS.eq(player.t.phChoose, true)) and JS.eq(player.mp.activeChallenge, 12)) then
			do return JS.D(1) end
		end
		if ((JS.eq(player.t.phChoose, true) and player.mp.buyables[13]:gte(1)) and (not JS.eq(player.mp.activeChallenge, 12))) then
			effect = effect:add(0.015)
		end
		do return softcap(nil, effect:max(1), JS.D(2.1), 0.1) end
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires1", "requires", "resource", "baseResource", "baseAmount", "type", "row", "hotkeys", "layerShown", "branches", "softcap", "softcapPower", "gainMult", "getResetGain", "getNextAt", "getNextSPAt", "upgrades", "clickables", "challenges", "passiveGeneration", "tabFormat", "update", "dilationEffect", "getSpecialTPName", "getSpecialEffect"}))

end
