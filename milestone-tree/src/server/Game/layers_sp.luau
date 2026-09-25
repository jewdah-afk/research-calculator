--!nocheck
-- transpiled from layers/sp.js by port/build.js: do not edit
return function()
-- transpiled from layers/sp.js
helper = function(this, num)
	local endings = JS.A(10, "th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th")
	do return endings[JS.k(math.fmod(JS.tonum(num), 10))] end
end
fetchTimer = function(this, id, burnTimer)
	JS.set(player.sp.timer, JS.k(id), burnTimer)
end
maxMilestones = function(this)
	local max = 3
	if hasMalware(nil, "m", 18) then
		max = JS.add(max, 1)
	end
	do return max end
end
countPermanent = function(this)
	local x = 0
	for _, __k1 in JS.keys(tmp.sp.milestones) do
		i = __k1
		if JS.eq(tmp.sp.milestones[i].permanent, true) then
			x = (JS.tonum(x) + 1)
		end
	end
	do return x end
end
checkFirstUnPermSpark = function(this)
	local min = 100
	for _, __k2 in JS.vals(tmp.sp.milestones) do
		i = __k2
		if (JS.eq(i.permanent, false) and (JS.tonum(player.sp.timer[JS.k(i.id)]) < 240)) then
			min = Math.min(min, i.id)
		end
	end
	do return min end
end
checkLastUnPermSpark = function(this)
	local min = 0
	for _, __k3 in JS.vals(tmp.sp.milestones) do
		i = __k3
		if JS.eq(i.permanent, false) then
			min = Math.max(min, i.id)
		end
	end
	do return min end
end
checkLastPermSpark = function(this)
	local min = 0
	for _, __k4 in JS.vals(tmp.sp.milestones) do
		i = __k4
		if JS.eq(i.permanent, true) then
			min = Math.max(min, i.id)
		end
	end
	do return min end
end
handleBurnDisplay = function(this, checkId)
	if ((JS.D(checkId)):lt(player.sp.sparkMilestones) and JS.eq(tmp.sp.milestones[JS.k(checkId)].permanent, false)) then
		do return JS.A(2, "display-text", ((("<div if=\"new Decimal(player.sp.chosenSparkMil+1).lt(player.sp.sparkMilestones)\" style=\"border:2px solid white; width:300px; height:44px; background:linear-gradient(to right,rgb(174, 113, 42) " .. JS.str((if (not JS.isnil(player.sp.timer[JS.k(checkId)])) then ((1 - Math.max(0, ((240 - JS.tonum(player.sp.timer[JS.k(checkId)])) / 240))) * 300) else 300)) .. "px,rgb(30, 30, 30) 0px); display:flexflex-wrap: wrap; align-content: center; justify-content: center; align-items: center;\"><span style='font-size:14px'>\n\tMilestone " .. JS.str((if JS.eq(player.sp.timer[JS.k(checkId)], 0) then " Ashed" else " is Burning")) .. "</span><hr color=\"#4f4f4f\"><span style=\"font-size:14px\">Burning power: </span><span style='color:  rgb(249, 147, 30); text-shadow: rgb(249, 147, 30) 0px 0px 10px; font-size:16px'>") .. JS.str(format(nil, (if (not JS.isnil(player.sp.timer[JS.k(checkId)])) then ((1 - Math.max(0, ((240 - JS.tonum(player.sp.timer[JS.k(checkId)])) / 240))) * 100) else 100), 3))) .. ("%</span></div>"))) end
	end
	if ((JS.D(checkId)):lt(player.sp.sparkMilestones) and JS.eq(tmp.sp.milestones[JS.k(checkId)].permanent, true)) then
		do return JS.A(2, "display-text", ("<div if=\"new Decimal(player.sp.chosenSparkMil+1).lt(player.sp.sparkMilestones)\" style=\"border:2px solid white; width:300px; height:44px; background:linear-gradient(to right,rgb(174, 113, 42) 300px,rgb(30, 30, 30) 0px); display:flexflex-wrap: wrap; align-content: center; justify-content: center; align-items: center;\"><span style='font-size:14px'>\n\tMilestone is Permanent</span><hr color=\"#4f4f4f\"><span style='font-size:12px'>This milestone will be skipped when burning</span></div>")) end
	end
end
handleBasicMilestoneDisplay = function(this, id)
	do return JS.A(2, "row", JS.A(2, JS.A(2, "milestone", JS.A(1, id)), handleBurnDisplay(nil, id))) end
end
handleDisplay = function(this)
	local table1 = handleBasicMilestoneDisplay(nil, player.sp.chosenSparkMil)
	local table2 = JS.A(2, "column", JS.A(5, handleBasicMilestoneDisplay(nil, player.sp.chosenSparkMil), JS.A(2, "blank", "5px"), handleBasicMilestoneDisplay(nil, JS.add(player.sp.chosenSparkMil, 1)), JS.A(2, "blank", "5px"), handleBasicMilestoneDisplay(nil, JS.add(player.sp.chosenSparkMil, 2))))
	local table3 = JS.A(2, "column", JS.A(9, handleBasicMilestoneDisplay(nil, player.sp.chosenSparkMil), JS.A(2, "blank", "5px"), handleBasicMilestoneDisplay(nil, JS.add(player.sp.chosenSparkMil, 1)), JS.A(2, "blank", "5px"), handleBasicMilestoneDisplay(nil, JS.add(player.sp.chosenSparkMil, 2)), JS.A(2, "blank", "5px"), handleBasicMilestoneDisplay(nil, JS.add(player.sp.chosenSparkMil, 3)), JS.A(2, "blank", "5px"), handleBasicMilestoneDisplay(nil, JS.add(player.sp.chosenSparkMil, 4))))
	if JS.eq(player.sp.showSparkAmt, 1) then
		do return table1 end
	end
	if JS.eq(player.sp.showSparkAmt, 3) then
		do return table2 end
	end
	if JS.eq(player.sp.showSparkAmt, 5) then
		do return table3 end
	end
end
addLayer(nil, "sp", JS.O({
	name = "super-prestige",
	symbol = "SP",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0),
		timer = JS.A(0),
		ambers = JS.D(0),
		sparkFill = JS.D(0),
		ambersDbg = JS.D(0),
		sparkMilestones = JS.D(0),
		maxMilestone = 3,
		showSparkAmt = 1,
		chalCooldown = JS.D(0),
		chosenSparkMil = 0,
		burningTimer = 0,
		ashedMilestones = 0,
		sparkPage = 1,
		fillActive = false,
		perkUpgs = JS.A(0)
	}, {"unlocked", "points", "timer", "ambers", "sparkFill", "ambersDbg", "sparkMilestones", "maxMilestone", "showSparkAmt", "chalCooldown", "chosenSparkMil", "burningTimer", "ashedMilestones", "sparkPage", "fillActive", "perkUpgs"}) end
end,
	color = function(this)
	if hasMalware(nil, "m", 15) then
		do return "rgb(238, 112, 112)" end
	end
	do return "#65A0B0" end
end,
	requires = function(this)
	do return JS.D(1e98) end
end,
	resource = function(this)
	if hasMalware(nil, "m", 15) then
		do return "<span style='color:red'>infected</span> super prestige points" end
	end
	do return "super-prestige points" end
end,
	baseResource = "prestige points",
	baseAmount = function(this)
	do return player.p.points end
end,
	type = "normal",
	gainMult = function(this)
	mult = JS.D(1)
	if (JS.eq(player.ap.activeChallenge, 12) or JS.eq(player.ap.activeChallenge, 41)) then
		do return JS.D(0) end
	end
	if player.m.best:gte(27) then
		mult = mult:mul(tmp.m.milestone27Effect)
	end
	if hasAchievement(nil, "ach", 19) then
		mult = mult:mul(achievementEffect(nil, "ach", 19))
	end
	if hasUpgrade(nil, "sp", 21) then
		mult = mult:mul(upgradeEffect(nil, "sp", 21))
	end
	if hasUpgrade(nil, "sp", 22) then
		mult = mult:mul(upgradeEffect(nil, "sp", 22))
	end
	if hasUpgrade(nil, "hp", 21) then
		mult = mult:mul(upgradeEffect(nil, "hp", 21))
	end
	if hasUpgrade(nil, "hp", 22) then
		mult = mult:mul(upgradeEffect(nil, "hp", 22))
	end
	if hasUpgrade(nil, "ap", 13) then
		mult = mult:mul(upgradeEffect(nil, "ap", 13))
	end
	mult = mult:mul(tmp.hp.buyables[12].effect)
	do return mult end
end,
	gainExp = function(this)
	mult = JS.D(1)
	if player.m.best:gte(27) then
		mult = mult:mul(tmp.ap.challenges[12].rewardEffect)
	end
	if hasUpgrade(nil, "t", 13) then
		mult = mult:mul(1.005)
	end
	if hasUpgrade(nil, "t", 33) then
		mult = mult:mul(1.005)
	end
	if JS.eq(player.t.activeChallenge, 31) then
		mult = mult:mul(tmp.t.dilationEffect)
	end
	do return mult end
end,
	row = 2,
	exponent = 0.1,
	hotkeys = JS.A(1, JS.O({
	key = "s",
	description = "S: Reset for super-prestige points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	reigniteCostCurrent = function(this)
	local cost = (JS.D(240)):sub(player.sp.timer[JS.k(player.sp.ashedMilestones)]):div(15.175):mul(JS.add(player.sp.ashedMilestones, 1)):mul((if JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, true) then player.sp.ashedMilestones else 1))
	if JS.eq(player.sp.timer[JS.k(player.sp.ashedMilestones)], 0) then
		cost = cost:mul(1.5)
	end
	do return cost end
end,
	reigniteCostNext = function(this)
	local cost = (JS.D(480)):sub(player.sp.timer[JS.k(player.sp.ashedMilestones)]):div(15.175):mul(JS.add(player.sp.ashedMilestones, 1)):mul((if JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, true) then player.sp.ashedMilestones else 1))
	if JS.eq(player.sp.timer[JS.k(player.sp.ashedMilestones)], 0) then
		cost = cost:mul(1.5)
	end
	do return cost end
end,
	ambersGain = function(this)
	local eff = player.points:max(1):log(10):pow(0.5):mul(player.m.points:div(player.points:max(1):log(2):pow(0.015):add(1)))
	do return eff end
end,
	SparkUnlReq = function(this)
	local base = JS.D(20)
	if player.sp.sparkMilestones:gte(2) then
		base = base:mul(1.17)
	end
	local cost = base:mul(player.sp.sparkMilestones:add(1):pow(1.367):mul(1.45))
	do return cost end
end,
	layerShown = function(this)
	do return (((player.m.best:gte(25) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	clickables = JS.O({
	[11] = JS.O({
	title = function(this)
	do return ("<span style=\"color:orange; font-size:16px\">Ignite the Milestone.</span>") end
end,
	display = function(this)
	do return ("<span style=\"font-size:14px\">Auto-fill: " .. JS.str((if JS.t(player.sp.fillActive) then "ON" else "OFF")) .. "</span> <hr color=\"#4f4f4f\"><span style=\"font-size:10px\"><i>Turn your prestige ashes into something that will light you the way from the fall of the Milestone universes</span>") end
end,
	canClick = function(this)
	do return player.sp.ambers:gt(0) end
end,
	onClick = function(this)
	JS.setk(player.sp, "fillActive", (not JS.t(player.sp.fillActive)))
end,
	style = function(this)
	if (not JS.t(this.canClick)) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			background = ("linear-gradient(to right, rgb(174, 113, 42) " .. JS.str(player.sp.sparkFill:div(tmp.sp.SparkUnlReq):mul(250)) .. "px ,rgb(30, 30, 30) 0px)"),
			border = "2px solid",
			width = "250px",
			["min-height"] = "100px"
		}, {"border-radius", "color", "background", "border", "width", "min-height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			background = ("linear-gradient(to right, rgb(174, 113, 42) " .. JS.str(player.sp.sparkFill:div(tmp.sp.SparkUnlReq):mul(250)) .. "px ,rgb(66, 66, 66) 0px)"),
			border = "2px solid",
			["min-height"] = "100px",
			width = "250px"
		}, {"border-radius", "color", "background", "border", "min-height", "width"}) end
	end
end,
	unlocked = function(this)
	do return true end
end
}, {"title", "display", "canClick", "onClick", "style", "unlocked"}),
	[12] = JS.O({
	title = function(this)
	do return ("<") end
end,
	canClick = function(this)
	do return (JS.D(player.sp.chosenSparkMil)):gt(0) end
end,
	onClick = function(this)
	if JS.eq(player.sp.showSparkAmt, 1) then
		JS.setk(player.sp, "chosenSparkMil", (JS.tonum(player.sp.chosenSparkMil) - 1))
	end
	if JS.eq(player.sp.showSparkAmt, 3) then
		JS.setk(player.sp, "chosenSparkMil", (JS.tonum(player.sp.chosenSparkMil) - 3))
	end
	if JS.eq(player.sp.showSparkAmt, 5) then
		JS.setk(player.sp, "chosenSparkMil", (JS.tonum(player.sp.chosenSparkMil) - 5))
	end
	JS.setk(player.sp, "sparkPage", (JS.tonum(player.sp.sparkPage) - 1))
end,
	style = function(this)
	if (JS.D(player.sp.chosenSparkMil)):gt(0) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = ("grey"),
			border = "2px solid",
			["min-height"] = "44px",
			width = "40px"
		}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = ("rgb(20, 20, 20)"),
			border = "2px solid",
			["min-height"] = "44px",
			width = "40px"
		}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
	end
end
}, {"title", "canClick", "onClick", "style"}),
	[13] = JS.O({
	title = function(this)
	do return (">") end
end,
	canClick = function(this)
	do return (JS.D(player.sp.chosenSparkMil)):lt(player.sp.sparkMilestones:sub(player.sp.showSparkAmt)) end
end,
	onClick = function(this)
	if JS.eq(player.sp.showSparkAmt, 1) then
		JS.setk(player.sp, "chosenSparkMil", (JS.tonum(player.sp.chosenSparkMil) + 1))
	end
	if JS.eq(player.sp.showSparkAmt, 3) then
		JS.setk(player.sp, "chosenSparkMil", JS.add(player.sp.chosenSparkMil, 3))
	end
	if JS.eq(player.sp.showSparkAmt, 5) then
		JS.setk(player.sp, "chosenSparkMil", JS.add(player.sp.chosenSparkMil, 5))
	end
	JS.setk(player.sp, "sparkPage", (JS.tonum(player.sp.sparkPage) + 1))
end,
	style = function(this)
	if (JS.D(player.sp.chosenSparkMil)):lt(player.sp.sparkMilestones:sub(player.sp.showSparkAmt)) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = ("grey"),
			border = "2px solid",
			["min-height"] = "44px",
			width = "40px"
		}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = ("rgb(20, 20, 20)"),
			border = "2px solid",
			["min-height"] = "44px",
			width = "40px"
		}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
	end
end
}, {"title", "canClick", "onClick", "style"}),
	[14] = JS.O({
	canClick = function(this)
	do return true end
end,
	display = function(this)
	do return ("<h3>Show Multiple Milestones</h3><hr><b>Currently: " .. JS.str(format(nil, player.sp.showSparkAmt, 0)) .. " Spark Milestone" .. JS.str((if JS.eq(player.sp.showSparkAmt, 1) then "" else "s")) .. "</b>") end
end,
	onClick = function(this)
	if JS.eq(player.sp.showSparkAmt, 1) then
		JS.setk(player.sp, "showSparkAmt", 3)
	elseif JS.eq(player.sp.showSparkAmt, 3) then
		JS.setk(player.sp, "showSparkAmt", 5)
	elseif JS.eq(player.sp.showSparkAmt, 5) then
		JS.setk(player.sp, "showSparkAmt", 1)
	end
	JS.setk(player.sp, "sparkPage", 1)
	JS.setk(player.sp, "chosenSparkMil", 0)
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		["background-color"] = ("grey"),
		border = "2px solid",
		["min-height"] = "50px",
		width = "150px"
	}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
end
}, {"canClick", "display", "onClick", "style"}),
	[15] = JS.O({
	title = function(this)
	do return ("<<") end
end,
	canClick = function(this)
	do return (JS.D(player.sp.chosenSparkMil)):gt(0) end
end,
	onClick = function(this)
	JS.setk(player.sp, "chosenSparkMil", 0)
	JS.setk(player.sp, "sparkPage", 1)
end,
	style = function(this)
	if (JS.D(player.sp.chosenSparkMil)):gt(0) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = ("grey"),
			border = "2px solid",
			["min-height"] = "44px",
			width = "40px"
		}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = ("rgb(20, 20, 20)"),
			border = "2px solid",
			["min-height"] = "44px",
			width = "40px"
		}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
	end
end
}, {"title", "canClick", "onClick", "style"}),
	[16] = JS.O({
	title = function(this)
	do return (">>") end
end,
	canClick = function(this)
	do return (JS.D(player.sp.chosenSparkMil)):lt(player.sp.sparkMilestones:sub(player.sp.showSparkAmt)) end
end,
	onClick = function(this)
	JS.setk(player.sp, "chosenSparkMil", (JS.D(player.sp.showSparkAmt)):mul(player.sp.sparkMilestones:div(player.sp.showSparkAmt):sub((if JS.eq(player.sp.showSparkAmt, 1) then 1 else 0)):floor()):toNumber())
	JS.setk(player.sp, "sparkPage", (JS.D(player.sp.sparkMilestones:div(player.sp.showSparkAmt):ceil():max(1))):toNumber())
end,
	style = function(this)
	if (JS.D(player.sp.chosenSparkMil)):lt(player.sp.sparkMilestones:sub(player.sp.showSparkAmt)) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = ("grey"),
			border = "2px solid",
			["min-height"] = "44px",
			width = "40px"
		}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = ("rgb(20, 20, 20)"),
			border = "2px solid",
			["min-height"] = "44px",
			width = "40px"
		}, {"border-radius", "color", "background-color", "border", "min-height", "width"}) end
	end
end
}, {"title", "canClick", "onClick", "style"}),
	[21] = JS.O({
	title = function(this)
	do return ("<span style=\"color:orange; font-size:16px\">Regnite the Milestone #" .. JS.str((if JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, true) then JS.add(checkFirstUnPermSpark(nil), 1) else JS.add(player.sp.ashedMilestones, 1))) .. ".</span>") end
end,
	display = function(this)
	do return (("<hr color=\"#4f4f4f\"><span style=\"font-size:12px\">Spend <b>" .. JS.str(format(nil, tmp.sp.reigniteCostCurrent)) .. "</b> filled prestige ashes to reignite the Spark Milestone ") .. JS.str((if ((JS.tonum(player.sp.ashedMilestones) > 0) and JS.eq(player.sp.ashedMilestones, (JS.tonum(checkFirstUnPermSpark(nil)) - 1))) then ("will burn Spark Milestone #" .. JS.str((if JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, true) then checkFirstUnPermSpark(nil) else player.sp.ashedMilestones)) .. " to 10% power)</span>") else ""))) end
end,
	canClick = function(this)
	do return player.sp.sparkFill:gte(tmp.sp.reigniteCostCurrent) end
end,
	onClick = function(this)
	if player.sp.sparkFill:gte(tmp.sp.reigniteCostCurrent) then
		JS.setk(player.sp, "sparkFill", player.sp.sparkFill:sub(tmp.sp.reigniteCostCurrent))
	end
	if (JS.tonum(player.sp.ashedMilestones) >= 0) then
		JS.set(player.sp.timer, JS.k(player.sp.ashedMilestones), 240)
		if (JS.eq(player.sp.timer[JS.k((JS.tonum(player.sp.ashedMilestones) - 1))], 0) and (JS.tonum(player.sp.ashedMilestones) > 0)) then
			JS.set(player.sp.timer, JS.k((JS.tonum(player.sp.ashedMilestones) - 1)), 36)
		end
		if (JS.eq(player.sp.timer[JS.k(player.sp.ashedMilestones)], 240) and (JS.tonum(player.sp.ashedMilestones) > 0)) then
			JS.setk(player.sp, "ashedMilestones", (JS.tonum(player.sp.ashedMilestones) - 1))
		end
		JS.setk(player.sp, "burningTimer", player.sp.timer[JS.k(player.sp.ashedMilestones)])
		local min = 100
		if JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, true) then
			for _, __k5 in JS.vals(tmp.sp.milestones) do
				i = __k5
				if (JS.eq(i.permanent, false) and (JS.tonum(player.sp.timer[JS.k(i.id)]) < 240)) then
					min = Math.min(min, i.id)
					JS.setk(player.sp, "ashedMilestones", min)
					if (JS.tonum(player.sp.timer[JS.k(min)]) < 1) then
						JS.set(player.sp.timer, JS.k(min), 36)
					end
					JS.setk(player.sp, "burningTimer", 240)
					console.log((JS.str(min) .. ", " .. JS.str(i.id) .. ", " .. JS.str(player.sp.ashedMilestones)))
				end
			end
		end
	end
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		background = ("linear-gradient(to right, rgb(66, 66, 66) 0px)"),
		border = "2px solid",
		["min-height"] = "100px",
		width = "250px"
	}, {"border-radius", "color", "background", "border", "min-height", "width"}) end
end,
	unlocked = function(this)
	do return ((JS.tonum(player.sp.burningTimer) > 0) or (JS.tonum(player.sp.ashedMilestones) > 0)) end
end
}, {"title", "display", "canClick", "onClick", "style", "unlocked"}),
	[22] = JS.O({
	title = function(this)
	local count = 0
	local finCount = 0
	if JS.isnil(tmp.sp.milestones[JS.k(JS.add(player.sp.ashedMilestones, 2))]) then
		do return ("<span style=\"color:orange; font-size:16px\">No milestones to Reignite.</span>") end
	elseif (not JS.isnil(tmp.sp.milestones[JS.k(JS.add(player.sp.ashedMilestones, 2))])) then
		if JS.eq(tmp.sp.milestones[JS.k(JS.add(player.sp.ashedMilestones, 1))].permanent, false) then
			do return ("<span style=\"color:orange; font-size:16px\">Regnite the Milestone #" .. JS.str(JS.add(player.sp.ashedMilestones, 2)) .. ".</span>") end
		end
		if JS.eq(tmp.sp.milestones[JS.k(JS.add(player.sp.ashedMilestones, 1))].permanent, true) then
			for _, __k6 in JS.vals(tmp.sp.milestones) do
				i = __k6
				if JS.eq(i.permanent, true) then
					count = (JS.tonum(count) + 1)
				end
				if JS.eq(i.permanent, false) then
					finCount = count
					count = 0
				end
			end
			do return ("<span style=\"color:orange; font-size:16px\">Regnite the Milestone #" .. JS.str(JS.add(JS.add(player.sp.ashedMilestones, finCount), 2)) .. ".</span>") end
		end
	end
end,
	display = function(this)
	if (not JS.isnil(tmp.sp.milestones[JS.k(JS.add(player.sp.ashedMilestones, 1))])) then
		do return (("<hr color=\"#4f4f4f\"><span style=\"font-size:12px\">Spend <b>" .. JS.str(format(nil, tmp.sp.reigniteCostNext)) .. "</b> filled prestige ashes to reignite the Spark Milestone ") .. JS.str((if ((JS.tonum(player.sp.ashedMilestones) > 0) and JS.eq(player.sp.ashedMilestones, (JS.tonum(checkFirstUnPermSpark(nil)) - 1))) then ("will burn Spark Milestone #" .. JS.str((if JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, true) then checkFirstUnPermSpark(nil) else player.sp.ashedMilestones)) .. " to 10% power)</span>") else ""))) end
	else
		do return ("<hr color=\"#4f4f4f\"><span style=\"font-size:12px\">No milestones to Reignite") end
	end
end,
	canClick = function(this)
	do return (player.sp.sparkFill:gte(tmp.sp.reigniteCostNext) and ((not JS.isnil(tmp.sp.milestones[JS.k(JS.add(player.sp.ashedMilestones, 1))])) and (JS.tonum(player.sp.timer[JS.k(JS.add(player.sp.ashedMilestones, 1))]) <= 240))) end
end,
	onClick = function(this)
	if player.sp.sparkFill:gte(tmp.sp.reigniteCostNext) then
		JS.setk(player.sp, "sparkFill", player.sp.sparkFill:sub(tmp.sp.reigniteCostNext))
	end
	if ((JS.tonum(player.sp.ashedMilestones) >= 0) and (not JS.isnil(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)]))) then
		JS.set(player.sp.timer, JS.k(JS.add(player.sp.ashedMilestones, 1)), 240)
		JS.setk(player.sp, "burningTimer", 240)
		JS.setk(player.sp, "ashedMilestones", (JS.tonum(player.sp.ashedMilestones) + 1))
	end
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		background = ("linear-gradient(to right, rgb(66, 66, 66) 0px)"),
		border = "2px solid",
		["min-height"] = "100px",
		width = "250px"
	}, {"border-radius", "color", "background", "border", "min-height", "width"}) end
end,
	unlocked = function(this)
	do return ((JS.tonum(player.sp.burningTimer) > 0) or (JS.tonum(player.sp.ashedMilestones) > 0)) end
end
}, {"title", "display", "canClick", "onClick", "style", "unlocked"})
}),
	upgrades = JS.O({
	rows = 5,
	cols = 4,
	[11] = JS.O({
	title = "Super-Prestige Delayer I",
	description = "First Milestone's effect is boosted by your super-prestige points.",
	cost = JS.D(1),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 50
	if player.m.best:gte(31) then
		base = JS.add(base, 5)
	end
	if player.m.best:gte(49) then
		base = JS.add(base, 5)
	end
	if player.m.best:gte(59) then
		base = JS.add(base, 5)
	end
	if player.m.best:gte(69) then
		base = JS.add(base, 5)
	end
	if player.m.best:gte(79) then
		base = JS.add(base, 10)
	end
	if player.m.best:gte(89) then
		base = JS.add(base, 5)
	end
	if hasUpgrade(nil, "sp", 44) then
		base = JS.add(base, 10)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[12] = JS.O({
	title = "Super-Prestige Delayer II",
	description = "First Milestone's effect is boosted by your super-prestige points.",
	cost = JS.D(4),
	unlocked = function(this)
	do return true end
end,
	effect = function(this)
	local base = 10
	if player.m.best:gte(32) then
		base = JS.add(base, 1)
	end
	if player.m.best:gte(49) then
		base = JS.add(base, 1)
	end
	if player.m.best:gte(59) then
		base = JS.add(base, 2)
	end
	if player.m.best:gte(69) then
		base = JS.add(base, 1)
	end
	if player.m.best:gte(79) then
		base = JS.add(base, 2)
	end
	if player.m.best:gte(89) then
		base = JS.add(base, 1)
	end
	if hasUpgrade(nil, "sp", 44) then
		base = JS.add(base, 2)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return softcap(nil, ret, JS.D("e5e14"), 0.2) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[13] = JS.O({
	title = "Super-Prestige Prestige Boost I",
	description = "Prestige Point gain is boosted by your super-prestige points.",
	cost = JS.D(1000000000000000),
	unlocked = function(this)
	do return player.m.best:gte(30) end
end,
	effect = function(this)
	local base = 3
	if player.m.best:gte(33) then
		base = JS.add(base, 0.5)
	end
	if player.m.best:gte(49) then
		base = JS.add(base, 0.5)
	end
	if player.m.best:gte(59) then
		base = JS.add(base, 0.92)
	end
	if player.m.best:gte(69) then
		base = JS.add(base, 0.58)
	end
	if player.m.best:gte(79) then
		base = JS.add(base, 1)
	end
	if player.m.best:gte(89) then
		base = JS.add(base, 0.5)
	end
	if hasUpgrade(nil, "sp", 44) then
		base = JS.add(base, 1)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return softcap(nil, ret, JS.D("e5e14"), 0.2) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[14] = JS.O({
	title = "Super-Prestige Prestige Boost II",
	description = "Prestige Point gain is boosted by your super-prestige points.",
	cost = JS.D(1e37),
	unlocked = function(this)
	do return player.m.best:gte(30) end
end,
	effect = function(this)
	local base = 1.5
	if player.m.best:gte(34) then
		base = JS.add(base, 0.5)
	end
	if player.m.best:gte(49) then
		base = JS.add(base, 0.5)
	end
	if player.m.best:gte(59) then
		base = JS.add(base, 0.5)
	end
	if player.m.best:gte(69) then
		base = JS.add(base, 0.5)
	end
	if player.m.best:gte(79) then
		base = JS.add(base, 0.766)
	end
	if player.m.best:gte(89) then
		base = JS.add(base, 0.234)
	end
	if hasUpgrade(nil, "sp", 44) then
		base = JS.add(base, 1)
	end
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return softcap(nil, ret, JS.D("e5e14"), 0.2) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[21] = JS.O({
	title = "Super-Prestige Self Boost I",
	description = "Super-Prestige Point gain is boosted by your super-prestige points.",
	cost = JS.D(1e63),
	unlocked = function(this)
	do return player.m.best:gte(35) end
end,
	effect = function(this)
	local base = 1.3
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[22] = JS.O({
	title = "Super-Prestige Self Boost II",
	description = "Super-Prestige Point gain is boosted by your super-prestige points.",
	cost = JS.D(1e110),
	unlocked = function(this)
	do return player.m.best:gte(35) end
end,
	effect = function(this)
	local base = 1.1
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):pow(0.9):add(1))
	do return ret end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "effectDisplay"}),
	[23] = JS.O({
	title = "Super-Prestige Milestone Boost I",
	description = "6th and 27th Milestone's effect ^(2+(meta-milestones))",
	cost = JS.D(1e185),
	unlocked = function(this)
	do return player.m.best:gte(40) end
end
}, {"title", "description", "cost", "unlocked"}),
	[24] = JS.O({
	title = "Super-Prestige Milestone Boost II",
	description = "Third Milestone's effect is boosted by your super-prestige points.",
	cost = JS.D(1e227),
	unlocked = function(this)
	do return player.m.best:gte(40) end
end
}, {"title", "description", "cost", "unlocked"}),
	[31] = JS.O({
	title = "Super-Prestige Scaling Delayer I",
	description = "Milestone Cost Scaling is weaker based on your super-prestige points.",
	cost = JS.D("1e6864"),
	effect = function(this)
	local p = player.sp.points:add(100000000000000000000):log10():log10():div(65)
	if hasUpgrade(nil, "sp", 32) then
		p = p:mul(2)
	end
	if hasUpgrade(nil, "sp", 33) then
		p = p:mul(1.5)
	end
	if hasUpgrade(nil, "sp", 34) then
		p = p:mul(1.2)
	end
	if hasUpgrade(nil, "t", 21) then
		p = p:mul(1.1)
	end
	do return p:add(1) end
end,
	unlocked = function(this)
	do return player.m.best:gte(55) end
end,
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect(), 4)) .. "x weaker") end
end
}, {"title", "description", "cost", "effect", "unlocked", "effectDisplay"}),
	[32] = JS.O({
	title = "Super-Prestige Upgrade 31 Boost I",
	description = "Super-Prestige Upgrade 31 is boosted.",
	cost = JS.D("1e9617"),
	unlocked = function(this)
	do return player.m.best:gte(55) end
end
}, {"title", "description", "cost", "unlocked"}),
	[33] = JS.O({
	title = "Super-Prestige Upgrade 31 Boost II",
	description = "Super-Prestige Upgrade 31 is boosted.",
	cost = JS.D("1e13713"),
	unlocked = function(this)
	do return player.m.best:gte(55) end
end
}, {"title", "description", "cost", "unlocked"}),
	[34] = JS.O({
	title = "Super-Prestige Upgrade 31 Boost II",
	description = "Super-Prestige Upgrade 31 is boosted.",
	cost = JS.D("1e13839"),
	unlocked = function(this)
	do return player.m.best:gte(55) end
end
}, {"title", "description", "cost", "unlocked"}),
	[41] = JS.O({
	title = "Super-Prestige Milestone Boost III",
	description = "Same as Super-Prestige Upgrade 24. To buy this upgrade, You need to complete AP challenge 2 15 times.",
	cost = function(this)
	if (JS.tonum(player.ap.challenges[12]) < 15) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e447e8") end
end,
	unlocked = function(this)
	do return player.m.best:gte(127) end
end
}, {"title", "description", "cost", "unlocked"}),
	[42] = JS.O({
	title = "Super-Prestige Milestone Boost IV",
	description = "Same as Super-Prestige Upgrade 24. To buy this upgrade, You need to complete AP challenge 4 21 times.",
	cost = function(this)
	if (JS.tonum(player.ap.challenges[22]) < 21) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e478e8") end
end,
	unlocked = function(this)
	do return player.m.best:gte(127) end
end
}, {"title", "description", "cost", "unlocked"}),
	[43] = JS.O({
	title = "Super-Prestige Cost Reducer I",
	description = "First Super-Prestige buyable is cheaper. You can buy this upgrade while you're in AP challenge 6.",
	cost = function(this)
	if (not JS.eq(player.ap.activeChallenge, 32)) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e401e8") end
end,
	unlocked = function(this)
	do return player.m.best:gte(127) end
end
}, {"title", "description", "cost", "unlocked"}),
	[44] = JS.O({
	title = "Super-Prestige Row 1 Boost I",
	description = "First row of Super-Prestige upgrades is boosted. You can buy this upgrade while you're in T challenge 5.",
	cost = function(this)
	if (not JS.eq(player.t.activeChallenge, 31)) then
		do return JS.D(math.huge) end
	end
	do return JS.D("e1293e4") end
end,
	unlocked = function(this)
	do return player.m.best:gte(127) end
end
}, {"title", "description", "cost", "unlocked"}),
	[51] = JS.O({
	title = "Prestige Essence Boost I",
	description = "Prestige Essence gain is boosted by your prestige points.",
	cost = JS.D(("e2.52e14")),
	unlocked = function(this)
	do return JS.m(player[JS.k(this.layer)].perkUpgs, "includes", Number(nil, this.id)) end
end,
	effect = function(this)
	local base = (JS.D(2)):add(player[JS.k(this.layer)].points:add(1):log10():add(1):log10():pow(1.55):div(100))
	local ret = Decimal.pow(base, Decimal.log10(player[JS.k(this.layer)].points:add(1)):add(1):log10():pow(0.9):add(1))
	if player.pep.buyables[11]:gte(5) then
		ret = ret:mul(tmp.pep.prFiveEffect)
	end
	if hasMalware(nil, "m", 17) then
		ret = ret:pow(milestoneEffect(nil, "m", 17))
	end
	do return softcap(nil, ret, JS.D("e5e16"), 0.1) end
end,
	perkReq = function(this)
	do return (("To get this upgrade, get " .. JS.str(format(nil, this.perkCost))) .. " points in T Challenge 6.") end
end,
	perkCan = function(this)
	do return (player.points:gte(("e5.985e14")) and JS.eq(player.t.activeChallenge, 32)) end
end,
	perkUnl = function(this)
	do return (JS.tonum(player.ex.dotUnl) >= 1) end
end,
	perkCost = JS.D(("e5.985e14")),
	effectDisplay = function(this)
	do return (JS.str(format(nil, this:effect())) .. "x") end
end
}, {"title", "description", "cost", "unlocked", "effect", "perkReq", "perkCan", "perkUnl", "perkCost", "effectDisplay"})
}, {"rows", "cols"}),
	challenges = JS.O({
	[11] = JS.O({
	onEnter = function(this)
	for _, __k7 in JS.keys(player) do
		i = __k7
		if ((JS.len(i) < 4) and (not (i == "tab"))) then
			console.log((JS.str(player[i].points)))
		end
	end
	JS.setk(player.p, "perkUpgs", JS.A(4, 15, 25, 35, 45))
	JS.setk(player.em, "points", JS.D(0))
	JS.setk(player.mm, "points", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.sp, "chalCooldown", JS.D(20))
end,
	onExit = function(this)
	if player.sp.chalCooldown:lte(0) then
		JS.setk(player.sp, "ambers", player.sp.ambers:add(tmp.sp.ambersGain))
	end
	JS.setk(player.sp, "ambersDbg", player.sp.ambersDbg:add(tmp.sp.ambersGain))
	JS.setk(player.p, "perkUpgs", JS.A(4, 15, 25, 35, 45))
end,
	name = "Milestone Dilation",
	completionLimit = function(this)
	local comps = JS.D(1)
	do return comps end
end,
	challengeDescription = function(this)
	do return "<br>Points and prestige points gain is slog(1.15). Also unlocks more in-challenge Perk Upgrades." end
end,
	unlocked = function(this)
	do return player.pm.best:gte(12) end
end,
	canComplete = function(this)
	do return false end
end,
	goalDescription = function(this)
	do return "Based on bought milestones amount and points you will produce Milestone Ambers, that can be spent for a temporal boosts for both universes." end
end,
	currencyDisplayName = "Points",
	rewardDescription = function(this)
	do return "The challenge has no rewards, it only produces Milestone Ambers" end
end,
	style = function(this)
	if (not JS.t(this:canComplete())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "rgb(238, 112, 112)",
			["background-color"] = "black",
			border = "2px solid rgb(238, 112, 112)",
			height = "330px",
			["border-radius"] = "33%",
			width = "330px",
			transition = " border 3s"
		}, {"border-radius", "color", "background-color", "border", "height", "border-radius", "width", "transition"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "gold",
			["background-color"] = "black",
			border = "2px solid gold",
			cursor = "pointer",
			height = "330px",
			width = "330px"
		}, {"border-radius", "color", "background-color", "border", "cursor", "height", "width"}) end
	end
end,
	buttonStyle = function(this)
	if (not JS.t(this:canComplete())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "rgb(238, 112, 112)",
			["border-radius"] = "33%",
			["background-color"] = "rgba(0,0,0,0)",
			border = "2px solid rgb(238, 112, 112)",
			transition = " all 1s"
		}, {"border-radius", "color", "border-radius", "background-color", "border", "transition"}) end
	end
	do return JS.O({
		["border-radius"] = "0%",
		color = "gold",
		["background-color"] = "rgba(0,0,0,0)",
		border = "2px solid gold"
	}, {"border-radius", "color", "background-color", "border"}) end
end
}, {"onEnter", "onExit", "name", "completionLimit", "challengeDescription", "unlocked", "canComplete", "goalDescription", "currencyDisplayName", "rewardDescription", "style", "buttonStyle"})
}),
	buyables = JS.O({
	rows = 1,
	cols = 2,
	[11] = JS.O({
	ifNotify = function(this)
	do return (not player.m.best:gte(83)) end
end,
	title = function(this)
	do return "<h3 class='sr'>Prestige Multiplier</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "Prestige Point is multiplied by ") .. JS.str(format(nil, data.effect))) .. "<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Super-Prestige points") end
end,
	cost = function(this)
	local a = player[JS.k(this.layer)].buyables[JS.k(this.id)]
	if a:gte(3) then
		local p = 1.309
		if hasUpgrade(nil, "sp", 43) then
			p = (JS.tonum(p) - 0.029)
		end
		a = a:div(3):pow(p):mul(3)
	end
	do return (JS.D("1e652955")):mul(Decimal.pow("1e12345", a)) end
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
	local eff = (JS.D("1e10000")):pow(player[JS.k(this.layer)].buyables[JS.k(this.id)])
	if hasUpgrade(nil, "hp", 31) then
		eff = eff:pow(1.05)
	end
	eff = eff:pow(tmp.ap.challenges[32].rewardEffect)
	do return eff end
end,
	unlocked = function(this)
	do return player.m.best:gte(77) end
end,
	style = function(this)
	if player.sp.points:lt(this:cost()) then
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
	do return (not player.m.best:gte(130)) end
end,
	title = function(this)
	do return "<h3 class='sr'>Softcap Delayer</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (((((((("Level: " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)]))) .. "<br>") .. "1st Milestone's softcap starts ") .. JS.str(format(nil, data.effect))) .. "x later<br>") .. "Cost for Next Level: ") .. JS.str(format(nil, data.cost))) .. " Super-Prestige points") end
end,
	cost = function(this)
	local a = player[JS.k(this.layer)].buyables[JS.k(this.id)]
	a = Decimal.pow(2, a)
	do return (JS.D(1)):mul(Decimal.pow("ee10", a)) end
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
	local b = 0.02
	if player.m.best:gte(132) then
		b = JS.add(b, 0.01)
	end
	local eff = (JS.D(1)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b))
	eff = eff:pow(tmp.ap.challenges[32].rewardEffect)
	do return eff end
end,
	unlocked = function(this)
	do return player.m.best:gte(129) end
end,
	style = function(this)
	if player.sp.points:lt(this:cost()) then
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
	milestones = JS.A(6, JS.O({
	requirementDescription = function(this)
	do return ("<span class='spark'>Spark Milestone #" .. JS.str((JS.D(this.id)):add(1)) .. "</span>") end
end,
	id = 0,
	unlocked = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	permanent = false,
	tooltip = function(this)
	do return ("Currently: " .. JS.str(format(nil, this:effect())) .. "x") end
end,
	tooltipStyle = function(this)
	do return JS.O({
		border = "2px solid lime",
		background = ("rgb(19, 19, 19)"),
		["font-size"] = "12px",
		["border-width"] = "2px 2px 0 2px",
		["border-image"] = "linear-gradient(to right, orange 0%, rgb(255, 132, 0) 50%,orange 100%)",
		width = "200px",
		["margin-bottom"] = "0px",
		["border-image-slice"] = "1"
	}, {"border", "background", "font-size", "border-width", "border-image", "width", "margin-bottom", "border-image-slice"}) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	effectDescription = function(this)
	do return ("<hr color=\"#4f4f4f\"><span style=\"font-size:11px\">Boost points gain after slog in [Milestone Overflow] by current points.</span>") end
end,
	effect = function(this)
	local base = JS.D(1.155)
	local timerMult = (1 - Math.max(0, ((240 - JS.tonum(player.sp.timer[JS.k(this.id)])) / 240)))
	local thisId = (JS.D(this.id)):toNumber()
	local eff = (JS.D(10)):mul(player.sp.ambers:max(1):log(1.5):pow(base):add(1)):pow(player.points:max(1):log(10):max(1):log(2):max(1):pow(0.25)):mul((if JS.cmp(player.sp.ashedMilestones, ">=", thisId) then timerMult else 1)):max(1)
	do return eff end
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		background = ("rgb(19, 19, 19)"),
		border = "2px solid",
		["min-height"] = "102px"
	}, {"border-radius", "color", "background", "border", "min-height"}) end
end
}, {"requirementDescription", "id", "unlocked", "permanent", "tooltip", "tooltipStyle", "done", "effectDescription", "effect", "style"}), JS.O({
	requirementDescription = function(this)
	do return ("<span class='spark'>Spark Milestone #" .. JS.str((JS.D(this.id)):add(1)) .. "</span>") end
end,
	id = 1,
	unlocked = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	tooltip = function(this)
	do return ("Currently: " .. JS.str(format(nil, this:effect())) .. "x") end
end,
	permanent = false,
	tooltipStyle = function(this)
	do return JS.O({
		border = "2px solid lime",
		background = ("rgb(19, 19, 19)"),
		["font-size"] = "12px",
		["border-width"] = "2px 2px 0 2px",
		["border-image"] = "linear-gradient(to right, orange 0%, rgb(255, 132, 0) 50%,orange 100%)",
		width = "200px",
		["margin-bottom"] = "0px",
		["border-image-slice"] = "1"
	}, {"border", "background", "font-size", "border-width", "border-image", "width", "margin-bottom", "border-image-slice"}) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	effectDescription = function(this)
	do return ("<hr color=\"#4f4f4f\"><span style=\"font-size:11px\">Boost [Alternate Prestige Boost I].</span>") end
end,
	effect = function(this)
	local base = JS.D(10)
	local timerMult = (1 - Math.max(0, ((240 - JS.tonum(player.sp.timer[JS.k(this.id)])) / 240)))
	local thisId = (JS.D(this.id)):toNumber()
	local eff = (JS.D(5)):mul(player.sp.ambers:max(1):log(base):add(1)):mul((if JS.cmp(player.sp.ashedMilestones, ">=", thisId) then timerMult else 1)):max(1)
	do return eff end
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		background = ("rgb(19, 19, 19)"),
		border = "2px solid",
		["min-height"] = "102px"
	}, {"border-radius", "color", "background", "border", "min-height"}) end
end
}, {"requirementDescription", "id", "unlocked", "tooltip", "permanent", "tooltipStyle", "done", "effectDescription", "effect", "style"}), JS.O({
	requirementDescription = function(this)
	do return ("<span class='spark'>Spark Milestone #" .. JS.str((JS.D(this.id)):add(1)) .. "</span>") end
end,
	id = 2,
	unlocked = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	tooltip = function(this)
	do return ("Unlocked: [" .. JS.str(format(nil, this:effect(), 0)) .. " / 9]") end
end,
	permanent = true,
	tooltipStyle = function(this)
	do return JS.O({
		border = "2px solid lime",
		background = ("rgb(19, 19, 19)"),
		["font-size"] = "12px",
		["border-width"] = "2px 2px 0 2px",
		["border-image"] = "linear-gradient(to right, orange 0%, rgb(255, 132, 0) 50%,orange 100%)",
		width = "200px",
		["margin-bottom"] = "0px",
		["border-image-slice"] = "1"
	}, {"border", "background", "font-size", "border-width", "border-image", "width", "margin-bottom", "border-image-slice"}) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	effectDescription = function(this)
	do return ("<hr color=\"#4f4f4f\"><span style=\"font-size:11px\">[Permanent] Unlock more Malware Milestones.</span>") end
end,
	effect = function(this)
	local thisId = (JS.D(this.id)):toNumber()
	local eff = player.sp.ambers:max(1):pow(0.55):max(1):log(2):floor():add(1):min(9)
	do return eff:toNumber() end
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		background = ("rgb(19, 19, 19)"),
		border = "2px solid",
		["min-height"] = "102px"
	}, {"border-radius", "color", "background", "border", "min-height"}) end
end
}, {"requirementDescription", "id", "unlocked", "tooltip", "permanent", "tooltipStyle", "done", "effectDescription", "effect", "style"}), JS.O({
	requirementDescription = function(this)
	do return ("<span class='spark'>Spark Milestone #" .. JS.str((JS.D(this.id)):add(1)) .. "</span>") end
end,
	id = 3,
	unlocked = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	tooltip = function(this)
	do return ("Currently: " .. JS.str((if JS.t(this:done()) then "Unlocked" else "Not Unlocked"))) end
end,
	permanent = true,
	tooltipStyle = function(this)
	do return JS.O({
		border = "2px solid lime",
		background = ("rgb(19, 19, 19)"),
		["font-size"] = "12px",
		["border-width"] = "2px 2px 0 2px",
		["border-image"] = "linear-gradient(to right, orange 0%, rgb(255, 132, 0) 50%,orange 100%)",
		width = "200px",
		["margin-bottom"] = "0px",
		["border-image-slice"] = "1"
	}, {"border", "background", "font-size", "border-width", "border-image", "width", "margin-bottom", "border-image-slice"}) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	effectDescription = function(this)
	do return ("<hr color=\"#4f4f4f\"><span style=\"font-size:11px\">[Permanent] Unlock CNU3 in Prestige Universe [ENDGAME].</span>") end
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		background = ("rgb(19, 19, 19)"),
		border = "2px solid",
		["min-height"] = "102px"
	}, {"border-radius", "color", "background", "border", "min-height"}) end
end
}, {"requirementDescription", "id", "unlocked", "tooltip", "permanent", "tooltipStyle", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = function(this)
	do return ("<span class='spark'>Spark Milestone #" .. JS.str((JS.D(this.id)):add(1)) .. "</span>") end
end,
	id = 4,
	unlocked = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	tooltip = function(this)
	do return ("Currently: " .. JS.str((if JS.t(this:done()) then "Unlocked" else "Not Unlocked"))) end
end,
	permanent = false,
	tooltipStyle = function(this)
	do return JS.O({
		border = "2px solid lime",
		background = ("rgb(19, 19, 19)"),
		["font-size"] = "12px",
		["border-width"] = "2px 2px 0 2px",
		["border-image"] = "linear-gradient(to right, orange 0%, rgb(255, 132, 0) 50%,orange 100%)",
		width = "200px",
		["margin-bottom"] = "0px",
		["border-image-slice"] = "1"
	}, {"border", "background", "font-size", "border-width", "border-image", "width", "margin-bottom", "border-image-slice"}) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	effectDescription = function(this)
	do return ("<hr color=\"#4f4f4f\"><span style=\"font-size:11px\">[Permanent] Unlock CNU3 in Prestige Universe [ENDGAME].</span>") end
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		background = ("rgb(19, 19, 19)"),
		border = "2px solid",
		["min-height"] = "102px"
	}, {"border-radius", "color", "background", "border", "min-height"}) end
end
}, {"requirementDescription", "id", "unlocked", "tooltip", "permanent", "tooltipStyle", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = function(this)
	do return ("<span class='spark'>Spark Milestone #" .. JS.str((JS.D(this.id)):add(1)) .. "</span>") end
end,
	id = 5,
	unlocked = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	tooltip = function(this)
	do return ("Currently: " .. JS.str((if JS.t(this:done()) then "Unlocked" else "Not Unlocked"))) end
end,
	permanent = true,
	tooltipStyle = function(this)
	do return JS.O({
		border = "2px solid lime",
		background = ("rgb(19, 19, 19)"),
		["font-size"] = "12px",
		["border-width"] = "2px 2px 0 2px",
		["border-image"] = "linear-gradient(to right, orange 0%, rgb(255, 132, 0) 50%,orange 100%)",
		width = "200px",
		["margin-bottom"] = "0px",
		["border-image-slice"] = "1"
	}, {"border", "background", "font-size", "border-width", "border-image", "width", "margin-bottom", "border-image-slice"}) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].sparkMilestones:gte((JS.D(this.id)):add(1)) end
end,
	effectDescription = function(this)
	do return ("<hr color=\"#4f4f4f\"><span style=\"font-size:11px\">[Permanent] Unlock CNU3 in Prestige Universe [ENDGAME].</span>") end
end,
	style = function(this)
	do return JS.O({
		["border-radius"] = "0%",
		color = "white",
		background = ("rgb(19, 19, 19)"),
		border = "2px solid",
		["min-height"] = "102px"
	}, {"border-radius", "color", "background", "border", "min-height"}) end
end
}, {"requirementDescription", "id", "unlocked", "tooltip", "permanent", "tooltipStyle", "done", "effectDescription", "style"})),
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(5, "main-display", "prestige-button", "resource-display", "buyables", "upgrades")
}),
	["Prestige Ashes"] = JS.O({
	unlocked = function(this)
	do return hasMalware(nil, "m", 15) end
end,
	content = JS.A(6, "main-display", "prestige-button", "blank", JS.A(2, "display-text", function(this)
	if hasMalware(nil, "m", 15) then
		do return (("You have <h2 style='color:  rgb(249, 147, 30); text-shadow: rgb(249, 147, 30) 0px 0px 10px;'>" .. JS.str(format(nil, player.sp.ambers))) .. "</h2> Prestige Ashes") end
	end
end), "resource-display", "challenges")
}, {"unlocked", "content"}),
	["Spark Milestones"] = JS.O({
	unlocked = function(this)
	do return hasMalware(nil, "m", 15) end
end,
	content = JS.A(15, "main-display", "prestige-button", "blank", JS.A(2, "display-text", function(this)
	if hasMalware(nil, "m", 15) then
		do return ((("You have <h2 style='color:  rgb(249, 147, 30); text-shadow: rgb(249, 147, 30) 0px 0px 10px;'>") .. JS.str(format(nil, player.sp.ambers))) .. "</h2> Prestige Ashes") end
	end
end), JS.A(2, "display-text", function(this)
	if hasMalware(nil, "m", 15) then
		do return "Here you can burn Prestige Ashes to earn Spark Milestones, which will temporarily [Burn]. <br>In order to get the bonuses from these milestones, you should check if they're still burning (working). If they're not, you should burn them by using Prestige Ashes. " end
	end
end), "blank", JS.A(2, "clickable", JS.A(1, 14)), "blank", JS.A(2, "row", JS.A(5, JS.A(2, "display-text", function(this)
	do return ((((("<div style=\"border:2px solid white; width:630px; height:96px; display:flexflex-wrap: wrap; align-content: center; justify-content: center; align-items: center;\"><span style='font-size:20px'>To unlock Spark Milestone:</span><span style='color:  rgb(249, 147, 30); text-shadow: rgb(249, 147, 30) 0px 0px 10px; font-size:16px'><br>") .. JS.str(format(nil, player.sp.sparkFill))) .. " / ") .. JS.str(format(nil, tmp.sp.SparkUnlReq))) .. ("</span> Prestige Ashes (Unlocked " .. JS.str(format(nil, player.sp.sparkMilestones, 0)) .. " / " .. JS.str(format(nil, maxMilestones(nil), 0)) .. " Spark Milestones) <hr color=\"#4f4f4f\">Tip: Tap to the clickable on the right to activate/deactivate auto-fill of Prestige Ashes")) end
end), JS.A(2, "display-text", ("</div>")), JS.A(2, "clickable", JS.A(1, 11)), JS.A(2, "clickable", JS.A(1, 21)), JS.A(2, "clickable", JS.A(1, 22)))), "blank", JS.A(2, "row", JS.A(1, JS.A(2, "display-text", function(this)
	do return ("(" .. JS.str(format(nil, player.sp.ashedMilestones, 0)) .. " / " .. JS.str(format(nil, player.sp.sparkMilestones, 0)) .. " Spark Milestones are Ashed, where " .. JS.str(format(nil, countPermanent(nil), 0)) .. " of them are [Permanent])") end
end))), "blank", function(this)
	do return handleDisplay(nil) end
end, "blank", JS.A(2, "row", JS.A(9, JS.A(2, "clickable", JS.A(1, 15)), "blank", JS.A(2, "clickable", JS.A(1, 12)), "blank", JS.A(2, "display-text", function(this)
	if hasMalware(nil, "m", 15) then
		do return ("Page: " .. JS.str(format(nil, player.sp.sparkPage, 0)) .. "/" .. JS.str(format(nil, player.sp.sparkMilestones:div(player.sp.showSparkAmt):ceil():max(1), 0))) end
	end
end), "blank", JS.A(2, "clickable", JS.A(1, 13)), "blank", JS.A(2, "clickable", JS.A(1, 16)))))
}, {"unlocked", "content"})
}, {"Main", "Prestige Ashes", "Spark Milestones"}),
	branches = JS.A(1, "p"),
	passiveGeneration = function(this)
	if player.m.best:gte(135) then
		do return 10000000000 end
	end
	if player.m.best:gte(57) then
		do return 1 end
	end
	do return 0 end
end,
	resetsNothing = function(this)
	do return (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	softcap = JS.D(math.huge),
	softcapPower = JS.D(1),
	doReset = function(this, l)
	if hasMalware(nil, "m", 15) then
		do return end
	else
		if (l == "sp") then
			do return end
		end
		if (l == "hp") then
			if player.m.best:gte(65) then
				layerDataReset(nil, "sp", JS.A(1, "upgrades"))
			else
				layerDataReset(nil, "sp", JS.A(0))
			end
		end
		if (l == "ap") then
			if player.m.best:gte(81) then
				layerDataReset(nil, "sp", JS.A(1, "upgrades"))
			else
				layerDataReset(nil, "sp", JS.A(0))
			end
		end
		if (l == "t") then
			if player.m.best:gte(100) then
				layerDataReset(nil, "sp", JS.A(1, "upgrades"))
			else
				layerDataReset(nil, "sp", JS.A(0))
			end
		end
		if (l == "hb") then
			if player.m.best:gte(104) then
				layerDataReset(nil, "sp", JS.A(1, "upgrades"))
			else
				layerDataReset(nil, "sp", JS.A(0))
			end
		end
		if (l == "mp") then
			if player.sp.sparkMilestones:gt(0) then
				do return end
			end
		end
	end
end,
	update = function(this, diff)
	local target
	if (JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, true) and (JS.D(JS.add(player.sp.ashedMilestones, 1))):lt(player.sp.sparkMilestones)) then
		JS.setk(player.sp, "ashedMilestones", (JS.tonum(player.sp.ashedMilestones) + 1))
	end
	if (((JS.tonum(player.sp.burningTimer) >= 0) and (JS.D(player.sp.ashedMilestones)):lt(player.sp.sparkMilestones)) and JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, false)) then
		JS.setk(player.sp, "burningTimer", (JS.D(player.sp.burningTimer)):sub(diff):max(0):toNumber())
	end
	if (JS.tonum(player.sp.burningTimer) <= 0) then
		if (JS.D(JS.add(player.sp.ashedMilestones, 1))):lt(player.sp.sparkMilestones) then
			JS.setk(player.sp, "ashedMilestones", (JS.tonum(player.sp.ashedMilestones) + 1))
			JS.setk(player.sp, "burningTimer", player.sp.timer[JS.k(player.sp.ashedMilestones)])
		end
	end
	if (JS.eq(player.sp.activeChallenge, 11) and (JS.tonum(player.sp.chalCooldown) > 0)) then
		JS.setk(player.sp, "chalCooldown", player.sp.chalCooldown:sub(diff):max(0))
	end
	if (player.sp.sparkFill:gte(tmp.sp.SparkUnlReq) and player.sp.sparkMilestones:lt(maxMilestones(nil))) then
		JS.setk(player.sp, "sparkFill", player.sp.sparkFill:min(tmp.sp.SparkUnlReq))
		JS.setk(player.sp, "sparkFill", player.sp.sparkFill:sub(tmp.sp.SparkUnlReq))
		JS.setk(player.sp, "sparkMilestones", player.sp.sparkMilestones:add(1))
		JS.setk(player.sp, "burningTimer", 240)
		JS.set(player.sp.timer, JS.k(player.sp.sparkMilestones), 240)
	end
	if JS.t(player.sp.fillActive) then
		local filler = JS.D(1)
		if player.sp.sparkFill:lt(tmp.sp.SparkUnlReq) then
			JS.setk(player.sp, "ambers", player.sp.ambers:sub((10 * JS.tonum(diff))):max(0))
			if (not JS.eq(player.sp.ambers:toNumber(), 0)) then
				JS.setk(player.sp, "sparkFill", player.sp.sparkFill:add((10 * JS.tonum(diff))))
			end
			if JS.eq(player.sp.ambers:toNumber(), 0) then
				JS.setk(player.sp, "fillActive", false)
			end
		end
	end
	if player.m.best:gte(83) then
		target = player.sp.points:add(1):div("1e652955"):log("1e12345")
		if target:gte(3) then
			local p = 1.309
			if hasUpgrade(nil, "sp", 43) then
				p = (JS.tonum(p) - 0.029)
			end
			target = target:div(3):pow((1 / JS.tonum(p))):mul(3)
		end
		target = target:add(1):floor()
		if target:gt(player.sp.buyables[11]) then
			JS.set(player.sp.buyables, 11, target)
		end
	end
	if player.m.best:gte(130) then
		target = player.sp.points:add(1):div(1):log("ee10"):max(0.1):log(2)
		target = target:add(1):floor()
		if target:gt(player.sp.buyables[12]) then
			JS.set(player.sp.buyables, 12, target)
		end
	end
	for _, __k8 in JS.keys(player.sp.milestones) do
		i = __k8
		if (JS.cmp(player.sp.ashedMilestones, ">", i) and (JS.tonum(player.sp.timer[i]) < 1)) then
			fetchTimer(nil, i, Math.floor(player.sp.timer[i]))
		end
		if JS.eq(player.sp.ashedMilestones, i) then
			fetchTimer(nil, i, player.sp.burningTimer)
		end
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "exponent", "hotkeys", "reigniteCostCurrent", "reigniteCostNext", "ambersGain", "SparkUnlReq", "layerShown", "clickables", "upgrades", "challenges", "buyables", "milestones", "tabFormat", "branches", "passiveGeneration", "resetsNothing", "softcap", "softcapPower", "doReset", "update"}))

end
