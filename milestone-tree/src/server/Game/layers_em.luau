--!nocheck
-- transpiled from layers/em.js by port/build.js: do not edit
return function()
-- transpiled from layers/em.js
addLayer(nil, "em", JS.O({
	name = "extra-milestone",
	symbol = "EM",
	position = (-2),
	startData = function(this)
	do return JS.O({
		unlocked = true,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = "#B070C0",
	requires = function(this)
	local b = JS.D(30)
	do return b end
end,
	milestonePopups = function(this)
	do return (not JS.eq(player.mp.activeChallenge, 21)) end
end,
	resource = "extra-milestones",
	baseResource = "meta-milestones",
	baseAmount = function(this)
	do return player.mm.points end
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
	base = JS.D(1.03),
	exponent = function(this)
	do return JS.D(1) end
end,
	hotkeys = JS.A(1, JS.O({
	key = "ctrl+m",
	description = "Ctrl+M: Get Extra-Milestone",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((player.mm.best:gte(30) and (not JS.eq(player.mp.activeChallenge, 21))) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	resetsNothing = function(this)
	do return true end
end,
	autoPrestige = function(this)
	do return player.m.best:gte(170) end
end,
	milestones = JS.A(19, JS.O({
	requirementDescription = "1st Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(0) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	effectDescription = function(this)
	do return "Autoget Meta-Milestones." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "2nd Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	effectDescription = function(this)
	do return "^1.01 3rd milestone effect." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "3rd Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	effectDescription = function(this)
	do return "Passively gain 1% of Prestige Power." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "4th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	effectDescription = function(this)
	do return "Passively gain 100% of Prestige Power." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "5th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	effectDescription = function(this)
	do return "Passively gain 10000% of Prestige Power." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "6th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(6) end
end,
	effectDescription = function(this)
	do return "Passively gain 10% of Exotic Prestige Points." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "7th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(6) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(7) end
end,
	effectDescription = function(this)
	do return "Unlock Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "8th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(7) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(8) end
end,
	effectDescription = function(this)
	do return "Automate 4th Atomic Prestige Challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "9th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(8) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(9) end
end,
	effectDescription = function(this)
	do return "Get Dilated Transcend Points outside of 'Dilation' at reduced rate." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "10th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(9) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(10) end
end,
	effectDescription = function(this)
	do return "Get Softcapped Transcend Points outside of 'Softcapped' at reduced rate." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "11st Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(10) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(11) end
end,
	effectDescription = function(this)
	do return "Get Prestige-Dilated Transcend Points outside of 'Prestige Dilation' at reduced rate." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "12nd Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(11) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(12) end
end,
	effectDescription = function(this)
	do return "Get Hardcapped Transcend Points outside of 'Hardcapped' at reduced rate." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "13rd Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(12) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(13) end
end,
	effectDescription = function(this)
	do return "Get Super-Dilated Transcend Points outside of 'Super Dilation' at reduced rate." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "14th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(13) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(14) end
end,
	effectDescription = function(this)
	do return "Get Prestige-Hardcapped Transcend Points outside of 'Get Prestige-Hardcapped' at reduced rate." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "15th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(14) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(15) end
end,
	effectDescription = function(this)
	do return "'Softcapped' effect is better, but the number of completions are limited at 20." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "16th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(15) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(16) end
end,
	effectDescription = function(this)
	do return "'Hardcapped' effect is better, but the number of completions are limited at 12." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "17th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(16) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(17) end
end,
	effectDescription = function(this)
	do return "'Prestige-Hardcapped' effect is better, but the number of completions are limited at 12." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "18th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(17) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(18) end
end,
	effectDescription = function(this)
	do return "Automate 'Prestige Dilation' T challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "19th Extra-Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(18) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(19) end
end,
	effectDescription = function(this)
	do return "Automate 'Super Dilation' T challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"})),
	branches = JS.A(1, "mm"),
	resetDescription = "Get ",
	doReset = function(this)

end
}, {"name", "symbol", "position", "startData", "color", "requires", "milestonePopups", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "base", "exponent", "hotkeys", "layerShown", "resetsNothing", "autoPrestige", "milestones", "branches", "resetDescription", "doReset"}))

end
