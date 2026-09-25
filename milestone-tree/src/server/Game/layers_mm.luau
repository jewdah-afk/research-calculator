--!nocheck
-- transpiled from layers/mm.js by port/build.js: do not edit
return function()
-- transpiled from layers/mm.js
addLayer(nil, "mm", JS.O({
	name = "meta-milestone",
	symbol = "MM",
	position = (-1),
	startData = function(this)
	do return JS.O({
		unlocked = true,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	milestonePopups = function(this)
	do return (not JS.eq(player.mp.activeChallenge, 21)) end
end,
	color = "#A057B0",
	requires = function(this)
	local b = JS.D(40)
	if hasUpgrade(nil, "t", 72) then
		b = b:div(upgradeEffect(nil, "t", 72))
	end
	do return b end
end,
	resource = "meta-milestones",
	baseResource = "milestones",
	baseAmount = function(this)
	do return player.m.points end
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
	base = JS.D(1.047),
	exponent = function(this)
	do return JS.D(1) end
end,
	hotkeys = JS.A(1, JS.O({
	key = "M",
	description = "Shift+M: Get Meta-Milestone",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.m.best:gte(40) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	resetsNothing = function(this)
	do return true end
end,
	autoPrestige = function(this)
	do return player.em.best:gte(1) end
end,
	milestones = JS.A(30, JS.O({
	requirementDescription = "1st Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(0) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	effectDescription = function(this)
	do return "Autoget Milestones." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "2nd Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "3rd Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "4th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "5th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	effectDescription = function(this)
	do return "Third Milestone's effect is better based on your meta-milestones." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "6th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(6) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^1.5" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "7th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(6) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(7) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^1.5" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "8th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(7) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(8) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^1.5" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "9th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(8) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(9) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^1.5" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "10th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(9) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(10) end
end,
	effectDescription = function(this)
	do return "Third Milestone's effect is better based on your meta-milestones." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "11th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(10) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(11) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^1.2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "12th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(11) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(12) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^1.2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "13th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(12) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(13) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^1.2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "14th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(13) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(14) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^1.2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "15th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(14) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(15) end
end,
	effectDescription = function(this)
	do return "Third Milestone's effect is better based on your meta-milestones." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "16th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(15) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(16) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^1.2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "17th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(16) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(17) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^1.7" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "18th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(17) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(18) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^1.8" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "19th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(18) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(19) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^1.9" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "20th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(19) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(20) end
end,
	effectDescription = function(this)
	do return "Third Milestone's effect is better based on your meta-milestones." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "21st Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(20) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(21) end
end,
	effectDescription = function(this)
	do return "Transcend Point gain is doubled" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "22nd Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(21) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(22) end
end,
	effectDescription = function(this)
	do return "Transcend Point gain is doubled" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "23rd Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(22) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(23) end
end,
	effectDescription = function(this)
	do return "Transcend Point gain is doubled" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "24th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(23) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(24) end
end,
	effectDescription = function(this)
	do return "Transcend Point gain is doubled" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "25th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(24) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(25) end
end,
	effectDescription = function(this)
	do return (("Transcend Point gain is boosted based on your meta-milestones. Currently: " .. JS.str(format(nil, tmp.mm.meta25Effect))) .. "x") end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "26th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(25) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(26) end
end,
	effectDescription = function(this)
	do return "Prestige Energy gain is doubled" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "27th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(26) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(27) end
end,
	effectDescription = function(this)
	do return "Prestige Energy gain is doubled" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "28th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(27) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(28) end
end,
	effectDescription = function(this)
	do return "Prestige Energy gain is doubled" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "29th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(28) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(29) end
end,
	effectDescription = function(this)
	do return "Prestige Energy gain is doubled" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "30th Meta-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(29) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(30) end
end,
	effectDescription = function(this)
	do return "25th Meta-Milestone's effect ^2, Unlock a new layer." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"})),
	resetDescription = "Get ",
	branches = JS.A(1, "m"),
	doReset = function(this)

end,
	meta25Effect = function(this)
	local ret = player.mm.points:div(10)
	if player.mm.best:gte(30) then
		ret = ret:pow(2)
	end
	do return ret end
end
}, {"name", "symbol", "position", "startData", "milestonePopups", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "base", "exponent", "hotkeys", "layerShown", "resetsNothing", "autoPrestige", "milestones", "resetDescription", "branches", "doReset", "meta25Effect"}))

end
