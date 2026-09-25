--!nocheck
-- transpiled from layers/cp.js by port/build.js: do not edit
return function()
-- transpiled from layers/cp.js
formatRoman = function(this, num)
	local roman, str, i, q
	roman = JS.O({
		["M̅̅"] = 1000000000,
		["L̅̅M̅̅"] = 900000000,
		["L̅̅"] = 500000000,
		["C̅̅L̅̅"] = 400000000,
		["C̅̅"] = 100000000,
		["L̅̅C̅̅"] = 90000000,
		["L̅̅"] = 50000000,
		["X̅̅L̅̅"] = 40000000,
		["X̅̅"] = 10000000,
		["M̅X̅̅"] = 9000000,
		["V̅̅"] = 5000000,
		["M̅V̅̅"] = 4000000,
		["M̅"] = 1000000,
		["C̅M̅"] = 900000,
		["D̅"] = 500000,
		["C̅D̅"] = 400000,
		["C̅"] = 100000,
		["X̅C̅"] = 90000,
		["L̅"] = 50000,
		["X̅L̅"] = 40000,
		["X̅"] = 10000,
		["MX̅"] = 9000,
		["V̅"] = 5000,
		["MV̅"] = 4000,
		M = 1000,
		CM = 900,
		D = 500,
		CD = 400,
		C = 100,
		XC = 90,
		L = 50,
		XL = 40,
		X = 10,
		IX = 9,
		V = 5,
		IV = 4,
		I = 1
	}, {"M̅̅", "L̅̅M̅̅", "L̅̅", "C̅̅L̅̅", "C̅̅", "L̅̅C̅̅", "L̅̅", "X̅̅L̅̅", "X̅̅", "M̅X̅̅", "V̅̅", "M̅V̅̅", "M̅", "C̅M̅", "D̅", "C̅D̅", "C̅", "X̅C̅", "L̅", "X̅L̅", "X̅", "MX̅", "V̅", "MV̅", "M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"})
	str = ""
	for _, __k1 in JS.vals(Object.keys(roman)) do
		i = __k1
		q = Math.floor((JS.tonum(num) / JS.tonum(roman[JS.k(i)])))
		num = (JS.tonum(num) - (JS.tonum(q) * JS.tonum(roman[JS.k(i)])))
		str = (JS.str(str) .. JS.str(JS.m(i, "repeat", q)))
	end
	do return str end
end
checkCorruptions = function(this)
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return (JS.tonum(player.cp.grid[JS.k(x)].level) > 0) end
	end)
	do return slots end
end
checkMinimum = function(this)
	local rangeMul = Math.floor((JS.tonum(player.cp.totalCorrupt) / 4))
	local addLevel = (Math.floor((JS.tonum(player.cp.totalCorrupt) / 5)) * 1.5)
	local ranType = Math.floor((Math.random() * 1.5))
	local range = (JS.tonum(JS.add(10, addLevel)) - JS.tonum((if player.pm.best:gte(13) then tmp.pm.pMilestone13Effect else 0)))
	local start = (JS.D(1)):add(rangeMul)
	local minCorrupt = 1000
	for _, __k2 in JS.keys(player.cp.grid) do
		l = __k2
		if (not JS.eq(player.cp.grid[l].level, 0)) then
			minCorrupt = Math.min(minCorrupt, (JS.tonum(player.cp.grid[l].level) - JS.tonum(start)))
		end
	end
	do return minCorrupt end
end
antiCorrupt = function(this)
	local base = JS.add(40, (if player.cm.best:gte(4) then 8 else 0))
	if player.cm.best:gte(5) then
		base = JS.add(base, 38)
	end
	do return base end
end
formatScale = function(this, num, precision)
	ends = JS.A(4, "", "st", "nd", "rd")
	ex = num:toNumber()
	value = Math.floor(math.fmod(JS.tonum(ex), 10))
	if (JS.tonum(value) <= 3) then
		ret = ends[JS.k(value)]
	else
		ret = "th"
	end
	do return (JS.str(JS.m(ex, "toFixed", precision)) .. JS.str(ret)) end
end
activeCorruptions = function(this)
	local grid = player.cp.grid
	local slots = JS.m(Object.keys(grid), "filter", function(_, x)
		do return JS.eq(grid[JS.k(x)].active, true) end
	end)
	do return slots end
end
corruptEffect = function(this)
	local eff = JS.D(1)
	eff = eff:add(player.cp.formatted:add(1):log10():mul(1.27):pow(1.5))
	if hasUpgrade(nil, "cp", 12) then
		eff = eff:mul(upgradeEffect(nil, "cp", 12))
	end
	if (JS.eq(player.mp.modeP, true) and (JS.tonum(tmp.pm.count) >= 7)) then
		eff = eff:mul(tmp.pm.pChalReward2)
	end
	if player.cp.buyables[21]:gte(1) then
		eff = eff:mul(buyableEffect(nil, "cp", 21))
	end
	do return eff end
end
typeName = JS.O({
	div = "Trojan",
	pm = "Backdoor"
}, {"div", "pm"})
addLayer(nil, "cp", JS.O({
	name = "prestige points",
	symbol = "CP",
	position = (-1),
	startData = function(this)
	do return JS.O({
		unlocked = true,
		points = JS.D(0),
		formatted = JS.D(0),
		chosenTrojan = 0,
		pointsInCorrupt = JS.D(0),
		peInCorrupt = JS.D(0),
		cooldown = 0,
		cooldown2 = 0,
		pool = JS.A(2, "div", "pm"),
		totalCorrupt = 0
	}, {"unlocked", "points", "formatted", "chosenTrojan", "pointsInCorrupt", "peInCorrupt", "cooldown", "cooldown2", "pool", "totalCorrupt"}) end
end,
	tooltip = function(this)
	do return (JS.str(format(nil, player.cp.points, 0)) .. " corrupted prestige points") end
end,
	cap = function(this)
	local cap = 0
	cap = (JS.tonum(tmp.cp.grid.rows) * JS.tonum(tmp.cp.grid.cols))
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return ((JS.tonum(player.cp.grid[JS.k(x)].level) > 0) and ((Math.floor((JS.tonum(x) / 100)) <= JS.tonum(tmp.cp.grid.rows)) and (math.fmod(JS.tonum(x), 10) <= JS.tonum(tmp.cp.grid.cols)))) end
	end)
	do return (JS.tonum(cap) - JS.len(slots)) end
end,
	canBuyMax = function(this)
	do return true end
end,
	nodeStyle = function(this)
	do return JS.O({
		border = "5px solid green",
		["border-style"] = "dashed",
		color = "green"
	}, {"border", "border-style", "color"}) end
end,
	canReset = function(this)
	do return ((JS.tonum(tmp.cp.resetGain) > 0) and JS.isnil(player.pm.activeChallenge)) end
end,
	color = "black",
	componentStyles = JS.O({
	["prestige-button"] = function(this)
	do return JS.O({
		["background-image"] = "url(\"resources/corrupt_active.png\")",
		width = "255px",
		height = "55px",
		color = "lime",
		["border-radius"] = "0%"
	}, {"background-image", "width", "height", "color", "border-radius"}) end
end
}),
	doReset = function(this, l)
	if (l == "cp") then
		for i = 0, JS.cap(0, (JS.tonum(tmp.cp.resetGain)) - 1, 1) do
			local grid = player.cp.grid
			local slots = JS.m(Object.keys(grid), "filter", function(_, x)
				do return ((JS.tonum(grid[JS.k(x)].level) < 1) and ((Math.floor((JS.tonum(x) / 100)) <= JS.tonum(tmp.cp.grid.rows)) and (math.fmod(JS.tonum(x), 10) <= JS.tonum(tmp.cp.grid.cols)))) end
			end)
			if JS.t(JS.len(slots)) then
				local slot = slots[JS.k(Math.floor((Math.random() * JS.len(slots))))]
				if (JS.tonum(player.cp.grid[JS.k(slot)].level) >= 1) then
					slot = slots[JS.k(Math.floor((Math.random() * JS.len(slots))))]
				end
				local rangeMul = Math.floor((JS.tonum(player.cp.totalCorrupt) / 4))
				local addLevel = (Math.floor((JS.tonum(player.cp.totalCorrupt) / 5)) * 1.5)
				local ranType = Math.floor((Math.random() * 1.5))
				local range = (JS.tonum(JS.add(10, addLevel)) - JS.tonum((if player.pm.best:gte(13) then tmp.pm.pMilestone13Effect else 0)))
				local start = (JS.D(1)):add(rangeMul)
				local tier = JS.add((Math.random() * (JS.tonum(start) - JS.tonum(range))), range)
				if JS.eq(tier, 0) then
					tier = 1
				end
				JS.set(player.cp.grid, JS.k(slot), JS.O({
					level = tier,
					active = false,
					fixed = false,
					type = player.cp.pool[JS.k(ranType)],
					cautPower = getGridData(nil, "cp", slot).cautPower
				}, {"level", "active", "fixed", "type", "cautPower"}))
			end
		end
	end
end,
	requires = function(this)
	local b = JS.D(2000000)
	if player.cp.points:gte(250) then
		b = JS.D(1e29)
	end
	do return b end
end,
	resource = " prestige points",
	baseResource = "points",
	baseAmount = function(this)
	do return player.points end
end,
	type = "static",
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	gainExp = function(this)
	do return JS.D(1) end
end,
	row = 1,
	base = JS.D(12),
	exponent = function(this)
	if (JS.tonum(player.ex.a2Unl) >= 2) then
		do return JS.D(0.79) end
	end
	do return JS.D(0.65) end
end,
	hotkeys = JS.A(1, JS.O({
	key = "ctrl+c",
	description = "Ctrl+C: Corrupt prestige points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	gainInCorrupt = function(this)
	local gain = getPointGen(nil):mul((if player.cp.buyables[31]:gt(0) then buyableEffect(nil, "cp", 31) else 1))
	local slow = (if (not JS.isnil(player.cp.trojanChosen)) then gridEffect(nil, "cp", player.cp.trojanChosen) else JS.D(1))
	if gain:div(slow):lte(1) then
		do return JS.D(0) end
	end
	do return (if (not JS.isnil(player.cp.trojanChosen)) then gain:div(slow) else JS.D(0)) end
end,
	peGainInCorrupt = function(this)
	local gain = tmp.pm.gain:mul((if player.cp.buyables[31]:gt(0) then buyableEffect(nil, "cp", 31) else 1))
	local slow = (if (not JS.isnil(player.cp.chosenBackdoor)) then gridEffect(nil, "cp", player.cp.chosenBackdoor) else JS.D(1))
	if gain:div(slow):lte(1) then
		do return JS.D(0) end
	end
	do return (if (not JS.isnil(player.cp.chosenBackdoor)) then gain:div(slow) else JS.D(0)) end
end,
	clickables = JS.O({
	[11] = JS.O({
	display = "Change Essence & Recharge mode to Prestige Essence boost, but lose ^0.5 of Prestige Essences.",
	canClick = function(this)
	do return JS.eq(player.mp.modeE, false) end
end,
	onClick = function(this)
	JS.setk(player.mp, "modeP", false)
	JS.setk(player.mp, "modeE", true)
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
end,
	style = function(this)
	if JS.eq(player.mp.modeE, true) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "50px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "50px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end,
	unlocked = function(this)
	do return player.pm.best:gte(2) end
end
}, {"display", "canClick", "onClick", "style", "unlocked"}),
	[12] = JS.O({
	canClick = function(this)
	do return JS.eq(player.mp.modeP, false) end
end,
	display = "Change Essence & Recharge mode to Points boost, but nullify Prestige Essences.",
	onClick = function(this)
	JS.setk(player.mp, "modeP", true)
	JS.setk(player.mp, "modeE", false)
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
end,
	style = function(this)
	if JS.eq(player.mp.modeP, true) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "50px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "50px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end,
	unlocked = function(this)
	do return player.pm.best:gte(2) end
end
}, {"canClick", "display", "onClick", "style", "unlocked"})
}),
	upgrades = JS.O({
	rows = function(this)
	local rows = 4
	do return rows end
end,
	cols = function(this)
	local cols = 4
	do return cols end
end,
	[11] = JS.O({
	title = "Corrupted Upgrade 11",
	description = "You can fix 2 corruptions at the same time.<br>(Point divider will be the highest from active ones).",
	unlocked = function(this)
	do return player.pm.best:gte(7) end
end,
	cost = JS.D(100),
	currencyDisplayName = "corruption essences",
	currencyInternalName = "formatted",
	currencyLayer = "cp",
	style = function(this)
	if hasUpgrade(nil, "cp", 11) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			["border-radius"] = "0%"
		}, {"background", "border-color", "color", "border-radius"}) end
	elseif player.cp.formatted:gte(this.cost) then
		do return JS.O({
			background = "#444",
			["border-color"] = "lime",
			color = "lime",
			["border-radius"] = "0%",
			cursor = "pointer"
		}, {"background", "border-color", "color", "border-radius", "cursor"}) end
	else
		do return JS.O({
			background = "#0f0f0f",
			["border-color"] = "lime",
			color = "lime",
			["border-radius"] = "0%"
		}, {"background", "border-color", "color", "border-radius"}) end
	end
end
}, {"title", "description", "unlocked", "cost", "currencyDisplayName", "currencyInternalName", "currencyLayer", "style"}),
	[12] = JS.O({
	title = "Corrupted Upgrade 12",
	description = "Prestige Milestones boosts Corruption's Reward and corruption essences effect.",
	costDescription = function(this)
	do return "Cost: 150 corruption essences<br>1e16 Points" end
end,
	unlocked = function(this)
	do return player.pm.best:gte(8) end
end,
	cost = JS.D(150),
	effect = function(this)
	local base = 2
	local ret = player.pm.best:div(20):add(1):add(player.pm.best:mul((if player.cm.points:gte(1) then tmp.cm.cMilestone1Effect else 0)))
	do return ret end
end,
	canAfford = function(this)
	do return (player.points:gte(10000000000000000) and player.cp.formatted:gte(this.cost)) end
end,
	pay = function(this)
	JS.setk(player.cp, "formatted", player.cp.formatted:sub(this.cost))
	JS.setk(player, "points", player.points:sub(10000000000000000))
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end,
	style = function(this)
	if hasUpgrade(nil, "cp", 12) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			["border-radius"] = "0%"
		}, {"background", "border-color", "color", "border-radius"}) end
	end
	if JS.t(this:canAfford()) then
		do return JS.O({
			background = "#444",
			["border-color"] = "lime",
			color = "lime",
			["border-radius"] = "0%",
			cursor = "pointer"
		}, {"background", "border-color", "color", "border-radius", "cursor"}) end
	end
	do return JS.O({
		background = "#0f0f0f",
		["border-color"] = "lime",
		color = "lime",
		["border-radius"] = "0%"
	}, {"background", "border-color", "color", "border-radius"}) end
end
}, {"title", "description", "costDescription", "unlocked", "cost", "effect", "canAfford", "pay", "effectDisplay", "style"}),
	[13] = JS.O({
	title = "Corrupted Upgrade 13",
	description = "Prestige Milestones and Points reduces Essence Fusioner <b>Scaled</b> scaling strength.",
	costDescription = function(this)
	do return "Cost: 5000 corruption essences<br>1e23 Points" end
end,
	unlocked = function(this)
	do return player.pm.best:gte(11) end
end,
	cost = JS.D(5000),
	effect = function(this)
	local ret = player.pm.best:pow(0.375):div(10):mul(player.points:add(1):log10():add(1):log(5))
	do return ret:min(0.9) end
end,
	canAfford = function(this)
	do return (player.points:gte(1e23) and player.cp.formatted:gte(this.cost)) end
end,
	pay = function(this)
	JS.setk(player.cp, "formatted", player.cp.formatted:sub(this.cost))
	JS.setk(player, "points", player.points:sub(1e23))
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect():mul(100))) .. "%") end
end,
	style = function(this)
	if hasUpgrade(nil, "cp", 13) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			["border-radius"] = "0%"
		}, {"background", "border-color", "color", "border-radius"}) end
	end
	if JS.t(this:canAfford()) then
		do return JS.O({
			background = "#444",
			["border-color"] = "lime",
			color = "lime",
			["border-radius"] = "0%",
			cursor = "pointer"
		}, {"background", "border-color", "color", "border-radius", "cursor"}) end
	end
	do return JS.O({
		background = "#0f0f0f",
		["border-color"] = "lime",
		color = "lime",
		["border-radius"] = "0%"
	}, {"background", "border-color", "color", "border-radius"}) end
end
}, {"title", "description", "costDescription", "unlocked", "cost", "effect", "canAfford", "pay", "effectDisplay", "style"})
}, {"rows", "cols"}),
	grid = JS.O({
	maxRows = 7,
	maxCols = 7,
	rows = function(this)
	local rows = 4
	if (JS.tonum(player.ex.a2Unl) >= 2) then
		rows = JS.add(rows, 2)
	end
	do return rows end
end,
	cols = function(this)
	local cols = 4
	if player.cm.points:gte(2) then
		cols = JS.add(cols, 1)
	end
	if (JS.tonum(player.ex.a2Unl) >= 2) then
		cols = JS.add(cols, 1)
	end
	do return cols end
end,
	getStartData = function(this, id)
	do return JS.O({
		level = 0,
		active = false,
		fixed = false,
		type = "div",
		cautPower = 0
	}, {"level", "active", "fixed", "type", "cautPower"}) end
end,
	getUnlocked = function(this, id)
	do return true end
end,
	getCanClick = function(this, data, id)
	do return true end
end,
	getStyle = function(this, data, id)
	if (JS.tonum(data.level) < 1) then
		do return JS.O({
			background = "#3b3939",
			width = "100px",
			height = "100px",
			["border-radius"] = "0%"
		}, {"background", "width", "height", "border-radius"}) end
	elseif JS.eq(data.active, true) then
		do return JS.O({
			background = "#0f0f0f",
			["border-color"] = "yellow",
			color = "lime",
			width = "100px",
			height = "100px",
			["border-radius"] = "0%"
		}, {"background", "border-color", "color", "width", "height", "border-radius"}) end
	elseif (JS.eq(player.cp.trojanChosen, id) and (data.type == "div")) then
		do return JS.O({
			background = "#0f0f0f",
			["border-color"] = "yellow",
			color = "lime",
			width = "100px",
			height = "100px",
			["border-radius"] = "0%"
		}, {"background", "border-color", "color", "width", "height", "border-radius"}) end
	elseif (JS.eq(player.cp.chosenBackdoor, id) and (data.type == "pm")) then
		do return JS.O({
			background = "#0f0f0f",
			["border-color"] = "yellow",
			color = "lime",
			width = "100px",
			height = "100px",
			["border-radius"] = "0%"
		}, {"background", "border-color", "color", "width", "height", "border-radius"}) end
	else
		do return JS.O({
			background = "#0f0f0f",
			["border-color"] = "lime",
			color = "lime",
			width = "100px",
			height = "100px",
			["border-radius"] = "0%"
		}, {"background", "border-color", "color", "width", "height", "border-radius"}) end
	end
end,
	getTooltipStyle = function(this, data, id)
	if (JS.tonum(data.level) < 1) then
		do return JS.O({
			background = "rgba(0,0,0,0)"
		}) end
	else
		do
			local __sw3 = options.changeCorruptTooltipPlace
			local __ft4 = false
			repeat
				if __ft4 or JS.eq(__sw3, "right") then
					__ft4 = true
					do return JS.O({
						border = "2px solid transparent",
						["border-image"] = "linear-gradient(to right, lime 0%, #52f552 50%,lime 100%)",
						background = "#0f0f0f",
						right = "0%",
						left = "260%",
						bottom = "5%",
						width = "300px",
						["border-image-slice"] = "1"
					}, {"border", "border-image", "background", "right", "left", "bottom", "width", "border-image-slice"}) end
				end
				if __ft4 or JS.eq(__sw3, "left") then
					__ft4 = true
					do return JS.O({
						border = "2px solid lime",
						["border-image"] = "linear-gradient(to right, lime 0%, #52f552 50%,lime 100%)",
						background = "#0f0f0f",
						right = "0%",
						left = "-160%",
						bottom = "5%",
						width = "300px",
						["border-image-slice"] = "1"
					}, {"border", "border-image", "background", "right", "left", "bottom", "width", "border-image-slice"}) end
				end
				if __ft4 or JS.eq(__sw3, "bottom") then
					__ft4 = true
					do return JS.O({
						border = "2px solid lime",
						["border-image"] = "linear-gradient(to right, lime 0%, #52f552 50%,lime 100%)",
						background = "#0f0f0f",
						right = "0%",
						bottom = "-100%",
						width = "300px",
						["border-image-slice"] = "1"
					}, {"border", "border-image", "background", "right", "bottom", "width", "border-image-slice"}) end
				end
				if __ft4 or JS.eq(__sw3, "top") then
					__ft4 = true
					do return JS.O({
						border = "2px solid lime",
						["border-image"] = "linear-gradient(to right, lime 0%, #52f552 50%,lime 100%)",
						background = "#0f0f0f",
						right = "0%",
						bottom = "100%",
						width = "300px",
						["border-image-slice"] = "1"
					}, {"border", "border-image", "background", "right", "bottom", "width", "border-image-slice"}) end
				end
			until true
		end
	end
end,
	getCost = function(this, data, id)
	local eff = JS.D(1)
	eff = (JS.D(100000000000000000)):div(data.level):pow(0.5):pow((JS.D(player.cp.totalCorrupt)):div(85):add(1)):pow((JS.D((JS.tonum(data.level) / 100))):add(math.fmod(JS.tonum(data.level), 100)):div(50):add(1)):div((if player.cp.buyables[22]:gte(1) then buyableEffect(nil, "cp", 22) else 1))
	if (data.type == "pm") then
		eff = (JS.D(100000000000000000)):mul(data.level):pow(0.75):div((if player.cp.buyables[22]:gte(1) then buyableEffect(nil, "cp", 22) else 1))
	end
	if ((JS.tonum(data.level) >= 15) and (data.type == "div")) then
		eff = eff:div((if player.cm.points:gte(2) then (5 ^ 4) else 5))
	end
	if ((player.cm.best:gte(3) and (JS.tonum(data.level) >= 40)) and (data.type == "div")) then
		eff = eff:div((JS.D(data.level)):pow((JS.tonum(player.cp.totalCorrupt) / 40)))
	end
	if ((player.cm.best:gte(3) and (JS.tonum(data.level) >= 100)) and (data.type == "div")) then
		eff = eff:mul((JS.D(data.level)):pow((JS.tonum(player.cp.totalCorrupt) / 50)))
	end
	if ((player.cm.best:gte(3) and (JS.tonum(data.level) >= 40)) and (data.type == "pm")) then
		eff = eff:mul((JS.D((JS.tonum(data.level) / 10))):pow((JS.tonum(player.cp.totalCorrupt) / 20)))
	end
	if ((player.cm.best:gte(3) and (JS.tonum(data.level) >= 60)) and (data.type == "pm")) then
		eff = eff:mul((JS.D((JS.tonum(data.level) / 10))):pow((JS.tonum(player.cp.totalCorrupt) / 100)):mul((JS.tonum(data.level) - 59)))
	end
	if ((JS.tonum(data.level) >= 15) and (data.type == "pm")) then
		eff = eff:div((if player.cm.points:gte(2) then (5 ^ 2) else 1.25))
	end
	if ((player.cm.best:gte(3) and (JS.tonum(data.level) >= 80)) and (data.type == "pm")) then
		eff = eff:mul((JS.D((JS.tonum(data.level) / 5))):pow((JS.tonum(player.cp.totalCorrupt) / 15)):pow((((JS.tonum(data.level) - 79) / 1000) + 1)))
	end
	if ((player.cm.best:gte(3) and (JS.tonum(data.level) >= 90)) and (data.type == "pm")) then
		eff = eff:mul((JS.D((JS.tonum(data.level) / 25))):pow((JS.tonum(player.cp.totalCorrupt) / 40)))
	end
	if (player.pm.best:gte(14) and (data.type == "div")) then
		eff = eff:div((if player.pm.best:gte(14) then tmp.pm.pMilestone14Effect else 0))
	end
	if (player.pm.best:gte(14) and (data.type == "pm")) then
		eff = eff:div((if player.pm.best:gte(14) then tmp.pm.pMilestone14Effect:pow(0.15) else 0))
	end
	do return eff:div((JS.D(data.cautPower)):add(1)) end
end,
	getEssence = function(this, data, id)
	local gain = JS.D(0)
	if (data.type == "pm") then
		gain = (JS.D(1)):mul(data.level):pow(1.5):add(1)
	else
		gain = (JS.D(1)):mul(data.level):mul(1.5):add(1)
	end
	if hasUpgrade(nil, "cp", 12) then
		gain = gain:mul(upgradeEffect(nil, "cp", 12))
	end
	if (JS.tonum(player.ex.dotUnl) >= 1) then
		gain = gain:mul(tmp.ex.exOneEffect)
	end
	do return gain:div((JS.D(data.cautPower)):div(2):add(1)) end
end,
	getTooltip = function(this, data, id)
	if (JS.tonum(data.level) < 1) then
		do return "" end
	else
		do return ((((((((((("<h5>To fix, get " .. JS.str(format(nil, gridCost(nil, "cp", id)))) .. JS.str((if (data.type == "pm") then " prestige essences" else " points"))) .. " while corruption is active.<br>When active, ") .. "/") .. JS.str(format(nil, gridEffect(nil, "cp", id), 5))) .. " to") .. JS.str((if (data.type == "pm") then " prestige essences" else " points"))) .. "  gain.<br>") .. "Reward: Get ") .. JS.str(format(nil, gridEssence(nil, "cp", id), 0))) .. " corruption essences on fix.") end
	end
end,
	getMark = function(this, data, id)
	if (JS.tonum(data.cautPower) > 0) then
		do return "resources/warning.png" end
	end
end,
	getEffect = function(this, data, id)
	local eff = JS.D(1)
	if (data.type == "div") then
		eff = (JS.D(data.level)):add(1):mul(3):pow((1 + (JS.tonum(data.level) / 10)))
	end
	if (data.type == "pm") then
		eff = (JS.D(data.level)):add(1):mul(1.5):pow((1 + (JS.tonum(data.level) / 10)))
	end
	if ((JS.tonum(data.level) >= 15) and (data.type == "pm")) then
		eff = eff:mul(25)
	end
	if ((JS.tonum(data.level) >= 20) and (data.type == "pm")) then
		eff = eff:mul((JS.D(data.level)):div(2):pow(5))
	end
	if ((JS.tonum(data.level) >= 30) and (data.type == "pm")) then
		eff = eff:mul((JS.D(data.level)):div(2):pow(3))
	end
	if (((JS.tonum(data.level) >= 50) and (data.type == "pm")) and (not JS.eq(player.pm.activeChallenge, 12))) then
		eff = (function() local __v5 = eff:mul((JS.tonum((JS.D(data.level)):div(2):pow(1.35):pow((JS.tonum(data.level) - 49))) / JS.tonum(data.level))); eff = __v5 return __v5 end)()
	end
	if (((JS.tonum(data.level) >= 55) and (data.type == "pm")) and (not JS.eq(player.pm.activeChallenge, 12))) then
		eff = (function() local __v6 = eff:mul((JS.tonum((JS.D(data.level)):div(2):div((JS.tonum(data.level) - 54))) ^ (JS.tonum(data.level) / 2))); eff = __v6 return __v6 end)()
	end
	if ((JS.tonum(data.level) >= 85) and (data.type == "pm")) then
		eff = eff:mul((JS.D(data.level)):div(2):pow(8))
	end
	if ((JS.tonum(data.level) >= 10) and (data.type == "div")) then
		eff = eff:mul((JS.D(data.level)):div((if (JS.tonum(data.level) >= 25) then 20 else 10))):div(10)
	end
	if ((JS.tonum(data.level) >= 30) and (data.type == "div")) then
		eff = eff:div(1000)
	end
	if (((JS.tonum(data.level) >= 50) and (data.type == "div")) and (not JS.eq(player.pm.activeChallenge, 12))) then
		eff = eff:mul((JS.tonum((JS.D(data.level)):div(2):pow(2):pow((JS.tonum(data.level) - 49))) / JS.tonum(data.level)))
	end
	if ((JS.tonum(data.level) >= 100) and (data.type == "div")) then
		eff = eff:mul(1e42)
	end
	if ((JS.tonum(data.level) >= 110) and (data.type == "div")) then
		eff = eff:div(1000000000000)
	end
	do return eff:mul((JS.D(data.cautPower)):add(1)) end
end,
	onClick = function(this, data, id)
	if JS.isnil(player.pm.activeChallenge) then
		if (JS.tonum(data.level) >= 1) then
			JS.setk(player[JS.k(this.layer)].grid[JS.k(id)], "active", (not JS.t(player[JS.k(this.layer)].grid[JS.k(id)].active)))
			if (data.type == "pm") then
				JS.setk(player.pm, "essence", JS.D(1))
			end
			if (data.type == "div") then
				JS.setk(player, "points", JS.D(0))
			end
			local slots = activeCorruptions(nil)
			local activeNum = 1
			if hasUpgrade(nil, "cp", 11) then
				activeNum = (JS.tonum(activeNum) + 1)
			end
			for i = 0, JS.cap(0, (JS.len(slots)) - 1, 1) do
				if ((not JS.eq(slots[JS.k(i)], id)) and (not JS.eq(activeNum, JS.len(slots)))) then
					JS.set(player.cp.grid, JS.k(slots[JS.k(i)]), JS.O({
						level = getGridData(nil, "cp", slots[JS.k(i)]).level,
						active = false,
						fixed = false,
						type = getGridData(nil, "cp", slots[JS.k(i)]).type,
						cautPower = getGridData(nil, "cp", slots[JS.k(i)]).cautPower
					}, {"level", "active", "fixed", "type", "cautPower"}))
				end
			end
		end
	end
end,
	getDisplay = function(this, data, id)
	table_ = ""
	if (JS.tonum(data.level) < 1) then
		table_ = "This hard drive is stable. No corruptions detected."
	else
		table_ = (((((("<h3>" .. JS.str(typeName[JS.k(data.type)]) .. "</h3>") .. JS.str((if (JS.tonum(data.cautPower) > 0) then (("<br>(Caution " .. JS.str(formatRoman(nil, data.cautPower))) .. ")<br>") else "<br>"))) .. ("Corruption")) .. "<br>Level: <h3>") .. JS.str(formatRoman(nil, data.level))) .. JS.str((if JS.eq(data.active, true) then "</h3><br>Progress to fix: [==========]" else "")))
	end
	for i = 1, (11) - 1 do
		if ((JS.eq(data.active, true) or JS.eq(player.cp.trojanChosen, id)) and (data.type == "div")) then
			if (JS.eq(player.cp.trojanChosen, id) and player.cp.pointsInCorrupt:gte(gridCost(nil, "cp", player.cp.trojanChosen):mul((JS.D(0.1)):mul(i)))) then
				table_ = JS.m(table_, "replace", "=", "█")
			end
			if (JS.eq(data.active, true) and player.points:gte(gridCost(nil, "cp", id):mul((JS.D(0.1)):mul(i)))) then
				table_ = JS.m(table_, "replace", "=", "█")
			end
		end
		if ((JS.eq(data.active, true) or JS.eq(player.cp.chosenBackdoor, id)) and (data.type == "pm")) then
			if (JS.eq(player.cp.chosenBackdoor, id) and player.cp.peInCorrupt:gte(gridCost(nil, "cp", player.cp.chosenBackdoor):mul((JS.D(0.1)):mul(i)))) then
				table_ = JS.m(table_, "replace", "=", "█")
			end
			if (JS.eq(data.active, true) and player.pm.essence:gte(gridCost(nil, "cp", id):mul((JS.D(0.1)):mul(i)))) then
				table_ = JS.m(table_, "replace", "=", "█")
			end
		elseif (JS.eq(data.active, true) and (data.type == "pm")) then
			if player.pm.essence:gte(gridCost(nil, "cp", id):mul((JS.D(0.1)):mul(i))) then
				table_ = JS.m(table_, "replace", "=", "█")
			end
		end
	end
	if ((JS.eq(data.active, true) or JS.eq(player.cp.trojanChosen, id)) and (data.type == "div")) then
		if JS.eq(player.cp.trojanChosen, id) then
			table_ = (JS.str(table_) .. (("<br>-< " .. JS.str(format(nil, player.cp.pointsInCorrupt:add(1):div(gridCost(nil, "cp", id)):mul(100):min(100)))) .. "% >-"))
		else
			table_ = (JS.str(table_) .. (("<br>-< " .. JS.str(format(nil, player.points:div(gridCost(nil, "cp", id)):mul(100):min(100)))) .. "% >-"))
		end
	end
	if ((JS.eq(data.active, true) or JS.eq(player.cp.chosenBackdoor, id)) and (data.type == "pm")) then
		if JS.eq(player.cp.chosenBackdoor, id) then
			table_ = (JS.str(table_) .. (("<br>-< " .. JS.str(format(nil, player.cp.peInCorrupt:add(1):div(gridCost(nil, "cp", id)):mul(100):min(100)))) .. "% >-"))
		else
			table_ = (JS.str(table_) .. (("<br>-< " .. JS.str(format(nil, player.pm.essence:div(gridCost(nil, "cp", id)):mul(100):min(100)))) .. "% >-"))
		end
	elseif (JS.eq(data.active, true) and (data.type == "pm")) then
		table_ = (JS.str(table_) .. (("<br>-< " .. JS.str(format(nil, player.pm.essence:div(gridCost(nil, "cp", id)):mul(100):min(100)))) .. "% >-"))
	end
	do return table_ end
end
}, {"maxRows", "maxCols", "rows", "cols", "getStartData", "getUnlocked", "getCanClick", "getStyle", "getTooltipStyle", "getCost", "getEssence", "getTooltip", "getMark", "getEffect", "onClick", "getDisplay"}),
	buyables = JS.O({
	[11] = JS.O({
	title = function(this)
	do return "<h3 class='corr'>Increase Caution Level</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return ((((("Total buyed: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Increase Caution Level on random corruption. <br>Cost: ") .. JS.str(format(nil, data.cost))) .. " Corruption Essences") end
end,
	cost = function(this, x)
	do return (JS.D(1000000)):mul(x:add(1):pow((JS.tonum(x) / 10))) end
end,
	canAfford = function(this)
	do return player.cp.formatted:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.cp, "formatted", player.cp.formatted:sub(cost))
	local grid = player.cp.grid
	local slots = JS.m(Object.keys(grid), "filter", function(_, x)
		do return (JS.tonum(grid[JS.k(x)].level) > 0) end
	end)
	if JS.t(JS.len(slots)) then
		local slot = slots[JS.k(Math.floor((Math.random() * JS.len(slots))))]
		JS.set(player.cp.grid, JS.k(slot), JS.O({
			level = getGridData(nil, "cp", slots[JS.k(i)]).level,
			active = false,
			fixed = false,
			type = getGridData(nil, "cp", slots[JS.k(i)]).type,
			cautPower = 1
		}, {"level", "active", "fixed", "type", "cautPower"}))
	end
end,
	unlocked = function(this)
	do return player.pm.best:gte(15) end
end,
	style = function(this)
	if player.cp.formatted:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "200px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "200px",
			cursor = "pointer"
		}, {"border-radius", "color", "background-color", "border", "height", "width", "cursor"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "unlocked", "style"}),
	[21] = JS.O({
	sellOne = function(this)
	JS.set(player.cp.buyables, 21, player.cp.buyables[21]:sub(1):max(0))
	local cost = (JS.D(100000)):mul(player.cp.buyables[21]:add(1):pow((JS.D((JS.tonum(player.cp.buyables[21]) / 5))):add(1))):pow((if player.cp.buyables[21]:gte(6) then 1.15 else 1))
	JS.setk(player.cp, "formatted", player.cp.formatted:add(cost))
end,
	canSellOne = function(this)
	do return player.cp.buyables[21]:gt(0) end
end,
	title = function(this)
	do return "<h3 class='corr'>Corruption Booster</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Total buyed: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Boosts corruption essences effect. <br>Cost: ") .. JS.str(format(nil, data.cost))) .. " Corruption Essences") .. "<br>Currently: ") .. JS.str(format(nil, this:effect()))) .. "x") end
end,
	cost = function(this, x)
	do return (JS.D(100000)):mul(x:add(1):pow((JS.D((JS.tonum(x) / 5))):add(1))):pow((if x:gte(6) then 1.15 else 1)) end
end,
	canAfford = function(this)
	do return player.cp.formatted:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.cp, "formatted", player.cp.formatted:sub(cost))
end,
	unlocked = function(this)
	do return player.cm.best:gte(4) end
end,
	effect = function(this, x)
	local eff = (((JS.tonum(x) * 100.56) * (3 ^ JS.tonum(JS.add(x, 1)))) + 1)
	if hasUpgrade(nil, "ex", 12) then
		eff = (((JS.tonum(x) * 119.56) * ((3.25 ^ JS.tonum(JS.add(x, 1))) * 5)) + 1)
	end
	do return softcap(nil, JS.D(eff), JS.D(100000000000000), 0.5) end
end,
	style = function(this)
	if player.cp.formatted:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "200px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "200px",
			cursor = "pointer"
		}, {"border-radius", "color", "background-color", "border", "height", "width", "cursor"}) end
	end
end
}, {"sellOne", "canSellOne", "title", "display", "cost", "canAfford", "buy", "unlocked", "effect", "style"}),
	[22] = JS.O({
	sellOne = function(this)
	JS.set(player.cp.buyables, 22, player.cp.buyables[22]:sub(1):max(0))
	local cost = (JS.D(190000)):mul(player.cp.buyables[22]:add(1):pow((JS.D((JS.tonum(player.cp.buyables[22]) / 5))):add(1))):pow((if player.cp.buyables[22]:gte(3) then 1.25 else 1))
	JS.setk(player.cp, "formatted", player.cp.formatted:add(cost))
end,
	canSellOne = function(this)
	do return player.cp.buyables[22]:gt(0) end
end,
	title = function(this)
	do return "<h3 class='corr'>Corruption Simplifier</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return ((((((("Total buyed: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Reduces corruptions goals. <br>Cost: ") .. JS.str(format(nil, data.cost))) .. " Corruption Essences") .. "<br>Currently: /") .. JS.str(format(nil, this:effect()))) end
end,
	cost = function(this, x)
	do return (JS.D(190000)):mul(x:add(1):pow((JS.D((JS.tonum(x) / 5))):add(1))):pow((if x:gte(3) then 1.25 else 1)) end
end,
	canAfford = function(this)
	do return player.cp.formatted:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.cp, "formatted", player.cp.formatted:sub(cost))
end,
	unlocked = function(this)
	do return player.cm.best:gte(4) end
end,
	effect = function(this, x)
	local eff = (((JS.tonum(x) * 20.85) * (2.5 ^ JS.tonum(JS.add(x, 1)))) + 1)
	do return softcap(nil, JS.D(eff), JS.D(1000000), 0.25) end
end,
	style = function(this)
	if player.cp.formatted:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "125px",
			width = "200px"
		}, {"border-radius", "color", "background-color", "border", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "125px",
			width = "200px",
			cursor = "pointer"
		}, {"border-radius", "color", "background-color", "border", "height", "width", "cursor"}) end
	end
end
}, {"sellOne", "canSellOne", "title", "display", "cost", "canAfford", "buy", "unlocked", "effect", "style"}),
	[31] = JS.O({
	title = function(this)
	do return ("<h3>Speed Multiplier [" .. JS.str(player.cp.buyables[31]) .. "]</h3>") end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return ((((("Algorithm will fix corruptions faster (based on chosen corruption's level). <br>Cost: " .. JS.str(format(nil, data.cost))) .. " Points") .. "<br>Speed: ") .. JS.str(format(nil, this:effect()))) .. "x") end
end,
	cost = function(this, x)
	do return (JS.D(1e100)):mul(x:add(1):pow((JS.D(x)):add(1):mul(1.85))) end
end,
	canAfford = function(this)
	do return player.points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player, "points", player.points:sub(cost))
end,
	unlocked = function(this)
	do return (JS.tonum(player.ex.a2Unl) >= 1) end
end,
	effect = function(this, x)
	local eff = JS.D(1)
	if (not JS.isnil(player.cp.trojanChosen)) then
		eff = (JS.D((2 * JS.tonum((if (JS.tonum(getGridData(nil, "cp", player.cp.trojanChosen).level) >= 1) then (JS.tonum(x) * ((JS.tonum(getGridData(nil, "cp", player.cp.trojanChosen).level) / 100) + 1)) else 1))))):pow((JS.tonum(x) * ((JS.tonum(getGridData(nil, "cp", player.cp.trojanChosen).level) / 10000) + 1)))
	end
	do return softcap(nil, eff, JS.D(1e38), 0.205) end
end,
	style = function(this)
	if player.points:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			["margin-left"] = "10px",
			height = "75px",
			width = "250px"
		}, {"border-radius", "color", "background-color", "border", "margin-left", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "75px",
			["margin-left"] = "10px",
			width = "250px",
			cursor = "pointer"
		}, {"border-radius", "color", "background-color", "border", "height", "margin-left", "width", "cursor"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "unlocked", "effect", "style"}),
	[33] = JS.O({
	title = function(this)
	do return ("<h3>Cooldown Reduce [" .. JS.str(player.cp.buyables[33]) .. "]</h3>") end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return ((((("Reduce cooldown after fixing a corruption. <br>Cost: " .. JS.str(format(nil, data.cost))) .. " Points") .. "<br>Cooldown: ") .. JS.str(format(nil, this:effect()))) .. "s") end
end,
	cost = function(this, x)
	do return (JS.D(1e115)):mul(x:add(1):pow((JS.D(x)):add(1):mul((5 * (JS.tonum(x) / 1.5))))) end
end,
	canAfford = function(this)
	do return player.points:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player, "points", player.points:sub(cost))
end,
	unlocked = function(this)
	do return (JS.tonum(player.ex.a2Unl) >= 1) end
end,
	effect = function(this, x)
	local eff = (JS.D(120)):mul((JS.D(0.5)):pow(x))
	do return eff end
end,
	style = function(this)
	if player.points:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			["margin-left"] = "10px",
			height = "75px",
			width = "250px"
		}, {"border-radius", "color", "background-color", "border", "margin-left", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "75px",
			["margin-left"] = "10px",
			width = "250px",
			cursor = "pointer"
		}, {"border-radius", "color", "background-color", "border", "height", "margin-left", "width", "cursor"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "unlocked", "effect", "style"}),
	[32] = JS.O({
	title = function(this)
	do return ("<h3>Speed Multiplier [" .. JS.str(player.cp.buyables[32]) .. "]</h3>") end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return ((((("Algorithm will fix corruptions faster. <br>Cost: " .. JS.str(format(nil, data.cost))) .. " Prestige Essences") .. "<br>Speed: ") .. JS.str(format(nil, this:effect()))) .. "x") end
end,
	cost = function(this, x)
	do return (JS.D(1e125)):mul(x:add(1):pow((JS.D(x)):add(1):mul((2 * (JS.tonum(x) / 2))))) end
end,
	canAfford = function(this)
	do return player.pm.essence:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.pm, "essence", player.pm.essence:sub(cost))
end,
	unlocked = function(this)
	do return (JS.tonum(player.ex.a2Unl) >= 1) end
end,
	effect = function(this, x)
	local eff = JS.D(1)
	if (not JS.isnil(player.cp.chosenBackdoor)) then
		eff = (JS.D((2 * JS.tonum((if (JS.tonum(getGridData(nil, "cp", player.cp.chosenBackdoor).level) >= 1) then (JS.tonum(x) * ((JS.tonum(getGridData(nil, "cp", player.cp.chosenBackdoor).level) / 100) + 1)) else 1))))):pow((JS.tonum(x) * JS.tonum((if (JS.tonum(getGridData(nil, "cp", player.cp.chosenBackdoor).level) >= 1) then (JS.tonum(x) * ((JS.tonum(getGridData(nil, "cp", player.cp.chosenBackdoor).level) / 1000) + 1)) else 1))))
	end
	do return softcap(nil, eff, JS.D(100000000000000000000), 0.175) end
end,
	style = function(this)
	if player.pm.essence:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			["margin-left"] = "10px",
			height = "65px",
			width = "250px"
		}, {"border-radius", "color", "background-color", "border", "margin-left", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "65px",
			["margin-left"] = "10px",
			width = "250px",
			cursor = "pointer"
		}, {"border-radius", "color", "background-color", "border", "height", "margin-left", "width", "cursor"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "unlocked", "effect", "style"}),
	[34] = JS.O({
	title = function(this)
	do return ("<h3>Cooldown Reduce [" .. JS.str(player.cp.buyables[34]) .. "]</h3>") end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return ((((("Reduce cooldown after fixing a corruption. <br>Cost: " .. JS.str(format(nil, data.cost))) .. " Prestige Essences") .. "<br>Cooldown: ") .. JS.str(format(nil, this:effect()))) .. "s") end
end,
	cost = function(this, x)
	do return (JS.D(1e125)):mul(x:add(1):pow((JS.D(x)):add(1):mul((2 * (JS.tonum(x) / 2))))) end
end,
	canAfford = function(this)
	do return player.pm.essence:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost) end
end,
	buy = function(this)
	cost = tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	JS.setk(player.pm, "essence", player.pm.essence:sub(cost))
end,
	unlocked = function(this)
	do return (JS.tonum(player.ex.a2Unl) >= 1) end
end,
	effect = function(this, x)
	local eff = (JS.D(120)):mul((JS.D(0.5)):pow(x))
	do return eff end
end,
	style = function(this)
	if player.pm.essence:lt(this:cost()) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			["margin-left"] = "10px",
			height = "65px",
			width = "250px"
		}, {"border-radius", "color", "background-color", "border", "margin-left", "height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "65px",
			["margin-left"] = "10px",
			width = "250px",
			cursor = "pointer"
		}, {"border-radius", "color", "background-color", "border", "height", "margin-left", "width", "cursor"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "unlocked", "effect", "style"})
}),
	layerShown = function(this)
	do return (JS.eq(player.mp.activeChallenge, 21) and player.pm.best:gte(6)) end
end,
	tabFormat = JS.O({
	Corruptions = JS.O({
	content = JS.A(1, function(this)
	if (player.tab == "cp") then
		do return JS.A(2, "column", JS.A(9, JS.A(2, "display-text", (((("You caused <h2 style='color:  black; text-shadow: white 0px 0px 10px;'> " .. JS.str(format(nil, player.cp.points, 0))) .. "</h2> corruptions, and fixed <h2 style='color:  lime; text-shadow: lime 0px 0px 10px;'>") .. JS.str(format(nil, player.cp.totalCorrupt, 0))) .. "</h2> of them")), "prestige-button", JS.A(2, "display-text", (((("You have <h2 style='color:  green; text-shadow: green 0px 0px 10px;'> " .. JS.str(format(nil, player.cp.formatted))) .. "</h2> corruption essences, which boosts points and Prestige Essences gain by ") .. JS.str(format(nil, corruptEffect(nil)))) .. "x (points boost works outside of prestige universe)")), JS.A(2, "display-text", "When you do a Corruption Reset, a malware will appear on a random disk.<br>Fix corruptions, get essences and get a boost to prior resources! To activate corruption, click on it.<br>And total corruptions amount will scale up all corruptions goals."), "blank", "blank", "clickables", "blank", "grid")) end
	end
end)
}),
	Upgrades = JS.O({
	unlocked = function(this)
	do return player.pm.best:gte(7) end
end,
	content = JS.A(1, function(this)
	if (player.tab == "cp") then
		do return JS.A(2, "column", JS.A(7, JS.A(2, "display-text", (("You caused <h2 style='color:  black; text-shadow: white 0px 0px 10px;'> " .. JS.str(format(nil, player.cp.points, 0))) .. "</h2> corruptions.")), "prestige-button", JS.A(2, "display-text", (((("You have <h2 style='color:  green; text-shadow: green 0px 0px 10px;'> " .. JS.str(format(nil, player.cp.formatted))) .. "</h2> corruption essences, which boosts points and Prestige Essences gain by ") .. JS.str(format(nil, corruptEffect(nil)))) .. "x (points boost works outside of prestige universe)")), JS.A(2, "display-text", "When you do a Corruption Reset, a malware will appear on a random disk.<br>Fix corruptions, get essences and get a boost to prior resources! To activate corruption, click on it."), "blank", "upgrades", "blank")) end
	end
end)
}, {"unlocked", "content"}),
	Caution = JS.O({
	unlocked = function(this)
	do return false end
end,
	content = JS.A(1, function(this)
	if (player.tab == "cp") then
		do return JS.A(2, "column", JS.A(7, JS.A(2, "display-text", (("You caused <h2 style='color:  black; text-shadow: white 0px 0px 10px;'> " .. JS.str(format(nil, player.cp.points, 0))) .. "</h2> corruptions.")), "prestige-button", JS.A(2, "display-text", (((("You have <h2 style='color:  green; text-shadow: green 0px 0px 10px;'> " .. JS.str(format(nil, player.cp.formatted))) .. "</h2> corruption essences, which boosts points and Prestige Essences gain by ") .. JS.str(format(nil, corruptEffect(nil)))) .. "x (points boost works outside of prestige universe)")), JS.A(2, "display-text", "Note: It is highly recommended to NOT get Caution power for now.<br> Caution Power affects corruption's goal, reward, and debuff. Also it stays on disk permanently, even if it has no corruption."), "blank", JS.A(2, "buyable", 11), "blank")) end
	end
end)
}, {"unlocked", "content"}),
	Antivirus = JS.O({
	unlocked = function(this)
	do return player.cm.best:gte(4) end
end,
	content = JS.A(1, function(this)
	if (player.tab == "cp") then
		do return JS.A(2, "column", JS.A(10, JS.A(2, "display-text", (("You caused <h2 style='color:  black; text-shadow: white 0px 0px 10px;'> " .. JS.str(format(nil, player.cp.points, 0))) .. "</h2> corruptions.")), "prestige-button", JS.A(2, "display-text", (((("You have <h2 style='color:  green; text-shadow: green 0px 0px 10px;'> " .. JS.str(format(nil, player.cp.formatted))) .. "</h2> corruption essences, which boosts points and Prestige Essences gain by ") .. JS.str(format(nil, corruptEffect(nil)))) .. "x (points boost works outside of prestige universe)")), JS.A(2, "display-text", (("Antivirus auto-detects and fixes level 0-" .. JS.str(format(nil, antiCorrupt(nil), 0))) .. " corruptions")), "blank", JS.A(2, "buyables", JS.A(1, 2)), "blank", (if (JS.tonum(player.ex.a2Unl) >= 1) then JS.A(2, "row", JS.A(4, JS.A(2, "display-text", ("<div style=\"border:2px solid white; width:450px; height:75px; display:flexflex-wrap: wrap; align-content: center; justify-content: center; align-items: center;\">Security Algorithm: <span style='color:  green; text-shadow: green 0px 0px 10px; font-size:20px'>TrojanFix.scr</span><br>Cooldown: " .. JS.str(format(nil, player.cp.cooldown, 2)) .. "s<hr color=\"#4f4f4f\">Automatically Fixes Trojan Corruptions.<br>")), JS.A(2, "buyable", JS.A(1, 31)), JS.A(2, "display-text", ("</div>")), JS.A(2, "buyable", JS.A(1, 33)))) else JS.A(0)), JS.A(2, "blank", "5px"), (if (JS.tonum(player.ex.a2Unl) >= 1) then JS.A(2, "row", JS.A(4, JS.A(2, "display-text", ("<div style=\"border:2px solid white; width:450px; height:75px; display:flexflex-wrap: wrap; align-content: center; justify-content: center; align-items: center;\">Security Algorithm: <span style='color:  green; text-shadow: green 0px 0px 10px; font-size:16px'>BackdoorRemove.scr</span><br>Cooldown: " .. JS.str(format(nil, player.cp.cooldown2, 2)) .. "s<hr color=\"#4f4f4f\">Automatically Fixes backdoor Corruptions.<br>")), JS.A(2, "buyable", JS.A(1, 32)), JS.A(2, "display-text", ("</div>")), JS.A(2, "buyable", JS.A(1, 34)))) else JS.A(0)))) end
	end
end)
}, {"unlocked", "content"})
}, {"Corruptions", "Upgrades", "Caution", "Antivirus"}),
	branches = JS.A(1, "pm"),
	update = function(this, diff)
	if ((not JS.isnil(player.cp.trojanChosen)) and (JS.tonum(player.ex.a2Unl) >= 1)) then
		JS.setk(player.cp, "pointsInCorrupt", player.cp.pointsInCorrupt:add(tmp.cp.gainInCorrupt:times(diff)))
	end
	if ((not JS.isnil(player.cp.chosenBackdoor)) and (JS.tonum(player.ex.a2Unl) >= 1)) then
		JS.setk(player.cp, "peInCorrupt", player.cp.peInCorrupt:add(tmp.cp.peGainInCorrupt:times(diff)))
	end
	if (JS.tonum(player.cp.cooldown) > 0) then
		JS.setk(player.cp, "cooldown", (JS.tonum(player.cp.cooldown) - JS.tonum(diff)))
	end
	if (JS.tonum(player.cp.cooldown) < 0) then
		JS.setk(player.cp, "cooldown", 0)
	end
	if (JS.tonum(player.cp.cooldown2) > 0) then
		JS.setk(player.cp, "cooldown2", (JS.tonum(player.cp.cooldown2) - JS.tonum(diff)))
	end
	if (JS.tonum(player.cp.cooldown2) < 0) then
		JS.setk(player.cp, "cooldown2", 0)
	end
	if JS.m(player.cp.pool, "includes", "pow") then
		JS.setk(player.cp, "pool", JS.A(2, "div", "pm"))
	end
	local slots = activeCorruptions(nil)
	local all = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return (JS.cmp(player.cp.grid[JS.k(x)].level, "<", antiCorrupt(nil)) and (JS.tonum(player.cp.grid[JS.k(x)].level) > 0)) end
	end)
	for i = 0, JS.cap(0, (JS.len(all)) - 1, 1) do
		if ((player.cm.best:gte(3) and (JS.len(all) > 0)) and JS.isnil(player.pm.activeChallenge)) then
			JS.setk(player.cp, "formatted", player.cp.formatted:add(gridEssence(nil, "cp", all[JS.k(i)])))
			JS.set(player.cp.grid, JS.k(all[JS.k(i)]), JS.O({
				level = 0,
				active = false,
				fixed = false,
				type = getGridData(nil, "cp", all[JS.k(i)]).type,
				cautPower = getGridData(nil, "cp", all[JS.k(i)]).cautPower
			}, {"level", "active", "fixed", "type", "cautPower"}))
			doPopup(nil, "none", "Corruption was fixed!", "Corruption Info", 3, "black", "lime")
			JS.setk(player.cp, "totalCorrupt", JS.add(player.cp.totalCorrupt, 1))
		end
	end
	setTimeout(nil, 100000)
	if ((((JS.eq(player.mp.activeChallenge, 21) and (JS.tonum(player.ex.a2Unl) >= 1)) and (not JS.isnil(player.cp.trojanChosen))) and (player.cp.pointsInCorrupt:gte(gridCost(nil, "cp", player.cp.trojanChosen)) and (getGridData(nil, "cp", player.cp.trojanChosen).type == "div"))) and (JS.tonum(getGridData(nil, "cp", player.cp.trojanChosen).level) >= 1)) then
		JS.setk(player.cp, "formatted", player.cp.formatted:add(gridEssence(nil, "cp", player.cp.trojanChosen)))
		JS.set(player.cp.grid, JS.k(player.cp.trojanChosen), JS.O({
			level = 0,
			active = false,
			fixed = false,
			type = getGridData(nil, "cp", player.cp.trojanChosen).type,
			cautPower = getGridData(nil, "cp", player.cp.trojanChosen).cautPower
		}, {"level", "active", "fixed", "type", "cautPower"}))
		doPopup(nil, "none", "Corruption was fixed!", "Corruption Info", 3, "black", "lime")
		JS.setk(player.cp, "totalCorrupt", JS.add(player.cp.totalCorrupt, 1))
		JS.setk(player.cp, "cooldown", buyableEffect(nil, "cp", 33))
		JS.setk(player.cp, "trojanChosen", nil)
		JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
	end
	if ((((JS.eq(player.mp.activeChallenge, 21) and (JS.tonum(player.ex.a2Unl) >= 1)) and (not JS.isnil(player.cp.chosenBackdoor))) and (player.cp.peInCorrupt:gte(gridCost(nil, "cp", player.cp.chosenBackdoor)) and (getGridData(nil, "cp", player.cp.chosenBackdoor).type == "pm"))) and (JS.tonum(getGridData(nil, "cp", player.cp.chosenBackdoor).level) >= 1)) then
		JS.setk(player.cp, "formatted", player.cp.formatted:add(gridEssence(nil, "cp", player.cp.chosenBackdoor)))
		JS.set(player.cp.grid, JS.k(player.cp.chosenBackdoor), JS.O({
			level = 0,
			active = false,
			fixed = false,
			type = getGridData(nil, "cp", player.cp.chosenBackdoor).type,
			cautPower = getGridData(nil, "cp", player.cp.chosenBackdoor).cautPower
		}, {"level", "active", "fixed", "type", "cautPower"}))
		doPopup(nil, "none", "Corruption was fixed!", "Corruption Info", 3, "black", "lime")
		JS.setk(player.cp, "totalCorrupt", JS.add(player.cp.totalCorrupt, 1))
		JS.setk(player.cp, "cooldown2", buyableEffect(nil, "cp", 34))
		JS.setk(player.cp, "chosenBackdoor", nil)
		JS.setk(player.cp, "peInCorrupt", JS.D(0))
	end
	for i = 0, JS.cap(0, (JS.len(slots)) - 1, 1) do
		if JS.isnil(player.pm.activeChallenge) then
			if ((JS.tonum(player.ex.a2Unl) <= 1) and (player.points:gte(gridCost(nil, "cp", slots[JS.k(i)])) and (getGridData(nil, "cp", slots[JS.k(i)]).type == "div"))) then
				JS.setk(player.cp, "formatted", player.cp.formatted:add(gridEssence(nil, "cp", slots[JS.k(i)])))
				JS.set(player.cp.grid, JS.k(slots[JS.k(i)]), JS.O({
					level = 0,
					active = false,
					fixed = false,
					type = getGridData(nil, "cp", slots[JS.k(i)]).type,
					cautPower = getGridData(nil, "cp", slots[JS.k(i)]).cautPower
				}, {"level", "active", "fixed", "type", "cautPower"}))
				doPopup(nil, "none", "Corruption was fixed!", "Corruption Info", 3, "black", "lime")
				JS.setk(player.cp, "totalCorrupt", JS.add(player.cp.totalCorrupt, 1))
			end
			setTimeout(nil, 100000)
			if (player.pm.essence:gte(gridCost(nil, "cp", slots[JS.k(i)])) and (getGridData(nil, "cp", slots[JS.k(i)]).type == "pm")) then
				JS.setk(player.cp, "formatted", player.cp.formatted:add(gridEssence(nil, "cp", slots[JS.k(i)])))
				JS.set(player.cp.grid, JS.k(slots[JS.k(i)]), JS.O({
					level = 0,
					active = false,
					fixed = false,
					type = getGridData(nil, "cp", slots[JS.k(i)]).type,
					cautPower = getGridData(nil, "cp", slots[JS.k(i)]).cautPower
				}, {"level", "active", "fixed", "type", "cautPower"}))
				doPopup(nil, "none", "Corruption was fixed!", "Corruption Info", 3, "black", "lime")
				JS.setk(player.cp, "totalCorrupt", JS.add(player.cp.totalCorrupt, 1))
			end
		end
	end
	for _, __k7 in JS.keys(player.cp.grid) do
		i = __k7
		local rangeMul = Math.floor((JS.tonum(player.cp.totalCorrupt) / 4))
		local addLevel = (Math.floor((JS.tonum(player.cp.totalCorrupt) / 5)) * 1.5)
		local ranType = Math.floor((Math.random() * 1.5))
		local range = (JS.tonum(JS.add(10, addLevel)) - JS.tonum((if player.pm.best:gte(13) then tmp.pm.pMilestone13Effect else 0)))
		local start = (JS.D(1)):add(rangeMul)
		local minCorrupt = 1000
		for _, __k8 in JS.keys(player.cp.grid) do
			l = __k8
			if ((not JS.eq(player.cp.grid[l].level, 0)) and (player.cp.grid[l].type == "div")) then
				minCorrupt = Math.min(minCorrupt, (JS.tonum(player.cp.grid[l].level) - JS.tonum(start)))
			end
			if (JS.tonum(player.ex.a2Unl) >= 1) then
				if ((((player.cp.grid[i].type == "div") and (JS.tonum(player.cp.grid[i].level) >= 1)) and JS.eq(player.cp.cooldown, 0)) and JS.eq((JS.tonum(player.cp.grid[i].level) - JS.tonum(start)), minCorrupt)) then
					JS.setk(player.cp, "trojanChosen", i)
					break
				end
			end
		end
		if (JS.cmp(player.cp.grid[i].level, ">", range) and JS.isnil(player.pm.activeChallenge)) then
			JS.setk(player.cp.grid[i], "level", (JS.tonum(getGridData(nil, "cp", i).level) - JS.tonum((if player.pm.best:gte(13) then tmp.pm.pMilestone13Effect else 0))))
		end
	end
	for _, __k9 in JS.keys(player.cp.grid) do
		i = __k9
		local rangeMul = Math.floor((JS.tonum(player.cp.totalCorrupt) / 4))
		local addLevel = (Math.floor((JS.tonum(player.cp.totalCorrupt) / 5)) * 1.5)
		local ranType = Math.floor((Math.random() * 1.5))
		local range = (JS.tonum(JS.add(10, addLevel)) - JS.tonum((if player.pm.best:gte(13) then tmp.pm.pMilestone13Effect else 0)))
		local start = (JS.D(1)):add(rangeMul)
		local minCorrupt = 1000
		for _, __k10 in JS.keys(player.cp.grid) do
			l = __k10
			if ((not JS.eq(player.cp.grid[l].level, 0)) and (player.cp.grid[l].type == "pm")) then
				minCorrupt = Math.min(minCorrupt, (JS.tonum(player.cp.grid[l].level) - JS.tonum(start)))
			end
			if (JS.tonum(player.ex.a2Unl) >= 1) then
				if ((((player.cp.grid[i].type == "pm") and (JS.tonum(player.cp.grid[i].level) >= 1)) and JS.eq(player.cp.cooldown2, 0)) and JS.eq((JS.tonum(player.cp.grid[i].level) - JS.tonum(start)), minCorrupt)) then
					JS.setk(player.cp, "chosenBackdoor", i)
					break
				end
			end
		end
		if (JS.cmp(player.cp.grid[i].level, ">", range) and JS.isnil(player.pm.activeChallenge)) then
			JS.setk(player.cp.grid[i], "level", (JS.tonum(getGridData(nil, "cp", i).level) - JS.tonum((if player.pm.best:gte(13) then tmp.pm.pMilestone13Effect else 0))))
		end
	end
end,
	prestigeButtonText = function(this)
	do return (((("CORRUPT" .. JS.str((if player.points:gte(tmp.cp.nextAt) then ((((" (You can corrupt " .. JS.str(format(nil, tmp.cp.resetGain, 0))) .. " / ") .. JS.str(format(nil, tmp.cp.cap, 0))) .. " times)") else " (Not enough points)"))) .. "<br>Next at: ") .. JS.str(format(nil, tmp.cp.nextAtDisp))) .. " points.") end
end
}, {"name", "symbol", "position", "startData", "tooltip", "cap", "canBuyMax", "nodeStyle", "canReset", "color", "componentStyles", "doReset", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "base", "exponent", "hotkeys", "gainInCorrupt", "peGainInCorrupt", "clickables", "upgrades", "grid", "buyables", "layerShown", "tabFormat", "branches", "update", "prestigeButtonText"}))

end
