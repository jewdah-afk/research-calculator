--!nocheck
-- transpiled from layers/cm.js by port/build.js: do not edit
return function()
-- transpiled from layers/cm.js
addLayer(nil, "cm", JS.O({
	name = "corrupted-milestone",
	symbol = "CM",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = true,
		points = JS.D(0),
		essence = JS.D(0),
		best = JS.D(0)
	}, {"unlocked", "points", "essence", "best"}) end
end,
	nodeStyle = function(this)
	do return JS.O({
		border = "5px solid lime",
		["border-style"] = "dashed",
		color = "lime"
	}, {"border", "border-style", "color"}) end
end,
	color = "darkgreen",
	requires = function(this)
	local b = JS.D(40)
	do return b end
end,
	resource = "corrupted milestones",
	baseResource = "fixed corruptions",
	baseAmount = function(this)
	do return JS.D(player.cp.totalCorrupt) end
end,
	type = "static",
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	gainExp = function(this)
	do return JS.D(1) end
end,
	cMilestone1Effect = function(this)
	local eff = ((Math.log2(player.cp.totalCorrupt) ^ 0.25) * (Math.log2(player.cp.totalCorrupt) / 50))
	do return (JS.D(eff)):max(1) end
end,
	newRow = 0,
	row = 1,
	exponent = function(this)
	do return JS.D(0.8) end
end,
	hotkeys = JS.A(1, JS.O({
	key = "c+m",
	description = "C+M: Get Corrupted Milestone",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (JS.eq(player.mp.activeChallenge, 21) and player.pm.best:gte(10)) end
end,
	resetsNothing = function(this)
	do return true end
end,
	milestones = JS.A(5, JS.O({
	requirementDescription = "1st Corrupted Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(0) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	effectDescription = function(this)
	do return (("Based on total fixed corruptions amount, add +" .. JS.str(format(nil, tmp.cm.cMilestone1Effect, 4))) .. " per prestige milestone to Corruption Upgrade 12 effect") end
end,
	style = function(this)
	if hasMilestone(nil, "cm", 0) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "2nd Corrupted Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	effectDescription = function(this)
	do return "Expand disk amount - Add one more column of disks. Prestige Milestone 9 is much better. Tenfold points gain." end
end,
	style = function(this)
	if hasMilestone(nil, "cm", 1) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "3rd Corrupted Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	effectDescription = function(this)
	do return "Auto-Fix pre-40th level corruptions. Prestige Milestone 9 is much better on post-50th level corruptions." end
end,
	style = function(this)
	if hasMilestone(nil, "cm", 2) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "4th Corrupted Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	effectDescription = function(this)
	do return "Add +8 to auto-fix level range. Unlock Antivirus" end
end,
	style = function(this)
	if hasMilestone(nil, "cm", 3) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "5th Corrupted Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	effectDescription = function(this)
	do return "Add +38 to auto-fix level range." end
end,
	style = function(this)
	if hasMilestone(nil, "cm", 4) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"})),
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(1, function(this)
	if (player.tab == "cm") then
		do return JS.A(2, "column", JS.A(6, "main-display", "prestige-button", "resource-display", "blank", "milestones", "blank")) end
	end
end)
})
}),
	branches = JS.A(2, "cp", "pm"),
	resetDescription = "Get ",
	doReset = function(this)

end
}, {"name", "symbol", "position", "startData", "nodeStyle", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "cMilestone1Effect", "newRow", "row", "exponent", "hotkeys", "layerShown", "resetsNothing", "milestones", "tabFormat", "branches", "resetDescription", "doReset"}))

end
