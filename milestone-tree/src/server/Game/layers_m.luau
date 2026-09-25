--!nocheck
-- transpiled from layers/m.js by port/build.js: do not edit
return function()
-- transpiled from layers/m.js
addLayer(nil, "m", JS.O({
	name = "milestone",
	symbol = "M",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = true,
		pseudoBuys = JS.A(0),
		points = JS.D(0)
	}, {"unlocked", "pseudoBuys", "points"}) end
end,
	color = function(this)
	if hasMalware(nil, "m", 4) then
		do return "#9f2846" end
	end
	do return "#793784" end
end,
	requires = function(this)
	do return JS.D(10) end
end,
	resource = "milestones",
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
	row = 0,
	base = JS.D(1.5),
	milestonePopups = function(this)
	do return (not JS.eq(player.mp.activeChallenge, 21)) end
end,
	exponent = function(this)
	local base, firstScaling
	if player.m.points:lt(5) then
		do return JS.D(1.7) end
	end
	base = JS.D(2)
	firstScaling = player.m.points:sub(tmp.m.getScalingStart):max(0)
	if tmp.m.getScalingStart:lte(25) then
		if firstScaling:gte(Decimal.sub(25, tmp.m.getScalingStart)) then
			firstScaling = Decimal.pow(1.03, firstScaling:sub(Decimal.sub(25, tmp.m.getScalingStart))):sub(1):mul(100):add(Decimal.sub(25, tmp.m.getScalingStart))
		end
		firstScaling = firstScaling:div(100)
	else
		firstScaling = Decimal.pow(1.03, firstScaling):sub(1)
	end
	if hasUpgrade(nil, "p", 31) then
		firstScaling = firstScaling:div(upgradeEffect(nil, "p", 31))
	end
	if hasUpgrade(nil, "sp", 31) then
		firstScaling = firstScaling:div(upgradeEffect(nil, "sp", 31))
	end
	if hasUpgrade(nil, "hp", 23) then
		firstScaling = firstScaling:div(upgradeEffect(nil, "hp", 23))
	end
	if hasUpgrade(nil, "ap", 23) then
		firstScaling = firstScaling:div(upgradeEffect(nil, "ap", 23))
	end
	if hasUpgrade(nil, "pe", 12) then
		firstScaling = firstScaling:div(upgradeEffect(nil, "pe", 12))
	end
	if hasUpgrade(nil, "se", 12) then
		firstScaling = firstScaling:div(upgradeEffect(nil, "se", 12))
	end
	if player.m.points:gte(185) then
		do return (JS.D(5)):mul(getCostOverflowEff(nil)) end
	end
	do return (JS.D(2)):add(firstScaling):add((if (player.m.points:gte(145) and player.m.points:lte(170)) then 0.5 else 0)):mul((if player.m.points:gte(getCostOverflowStart(nil)) then getCostOverflowEff(nil) else 1)):div((if hasUpgrade(nil, "p", 53) then upgradeEffect(nil, "p", 53) else 1)) end
end,
	getScalingStart = function(this)
	local start = JS.D(14)
	if hasAchievement(nil, "ach", 13) then
		start = start:add(achievementEffect(nil, "ach", 13))
	end
	if hasUpgrade(nil, "t", 52) then
		start = start:add(upgradeEffect(nil, "t", 52))
	end
	do return start end
end,
	hotkeys = JS.A(1, JS.O({
	key = "m",
	description = "M: Get Milestone",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (((not JS.eq(player.mp.activeChallenge, 21)) or JS.eq(player.pm.activeChallenge, 12)) or JS.eq(player.pm.activeChallenge, 13)) end
end,
	resetsNothing = function(this)
	do return true end
end,
	autoPrestige = function(this)
	do return player.mm.best:gte(1) end
end,
	milestones = JS.A(187, JS.O({
	requirementDescription = "1st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(0) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	effectDescription = function(this)
	local table_ = (("Gain " .. JS.str(format(nil, (JS.D(1)):max(getPointGen(nil))))) .. " points per second.")
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. (("<hr color='darkred' size='3'>Exotic Booster effect base is ^" .. JS.str(format(nil, tmp.m.milestones[0].effect))) .. " better based on points gain."))
	end
	do return table_ end
end,
	effect = function(this)
	local eff = JS.D(1)
	eff = getPointGen(nil):add(1):log10():add(1):pow(0.35):max(1)
	do return eff end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e1.31e21")) end
end,
	pseudoCost = JS.D(("e1.31e21")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			color = "white",
			width = "100%"
		}, {"animation", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "effect", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "2nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	effectDescription = function(this)
	local table_ = "Triple the first Milestone's effect."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. (("<hr color='darkred' size='3'>First Milestone's second effect applies to point gain after softcap at greatly boosted rate.<br>Currently: x" .. JS.str(format(nil, tmp.m.milestones[1].effect))) .. " to points gain (reduced when in challenge)"))
	end
	do return table_ end
end,
	effect = function(this)
	local eff = JS.D(1)
	if ((((not JS.isnil(player.ap.activeChallenge)) or (not JS.isnil(player.t.activeChallenge))) or (not JS.isnil(player.mp.activeChallenge))) or (not JS.isnil(player.pm.activeChallenge))) then
		do return (JS.D(10)):pow(tmp.m.milestones[0].effect:add(1):pow(0.2)) end
	end
	eff = (JS.D(("ee20"))):pow(tmp.m.milestones[0].effect:add(1):pow(0.2))
	do return eff end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e1.3505e21")) end
end,
	pseudoCost = JS.D(("e1.3505e21")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			color = "white",
			width = "100%"
		}, {"background", "animation", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "effect", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "3rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	effectDescription = function(this)
	local table_ = (("First Milestone's effect is boosted by your points. Currently: " .. JS.str(format(nil, tmp.m.milestone3Effect))) .. "x")
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. (("<hr color='darkred' size='3'>Points boosts Challenge Slayer effect. Currently: " .. JS.str(format(nil, tmp.m.milestones[2].effect))) .. "x"))
	end
	do return table_ end
end,
	effect = function(this)
	local eff = JS.D(1)
	eff = player.points:add(1):pow(0.1):add(1):log10():add(1):log2():add(1):pow(0.15)
	do return eff end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e6.755e21")) end
end,
	pseudoCost = JS.D(("e6.755e21")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			color = "white",
			width = "100%"
		}, {"background", "animation", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "effect", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "4th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	effectDescription = function(this)
	local table_ = ("Third Milestone's effect is better based on your milestones. Currently: 3rd Milestone's base effect base +" .. JS.str(format(nil, tmp.m.milestone4Effect)))
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. (("<hr color='darkred' size='3'>Add +" .. JS.str(format(nil, tmp.m.milestones[3].effect))) .. " to Prestige Power Upgrade 12 after softcap (based on best milestones and points).<br>Auto-complete Multiverse Challenges outside."))
	end
	do return table_ end
end,
	effect = function(this)
	local eff = JS.D(1)
	eff = player.m.best:add(1):pow(0.5):div(100):add(player.points:add(1):log10():add(1):log10():add(1):pow(0.15):div(5))
	do return eff end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e7.605e21")) end
end,
	pseudoCost = JS.D(("e7.605e21")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			color = "white",
			width = "100%"
		}, {"background", "animation", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "effect", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "5th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	effectDescription = function(this)
	local table_ = "Unlock the next layer. Milestones don't reset on all resets."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Unlock Prestige Perk Upgrades.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e8.011e21")) end
end,
	pseudoCost = JS.D(("e8.011e21")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			color = "white",
			width = "100%"
		}, {"background", "animation", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "6th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(6) end
end,
	effectDescription = function(this)
	local table_ = (("Prestige Point gain is boosted by your milestones. Currently: " .. JS.str(format(nil, tmp.m.milestone6Effect))) .. "x")
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>This milestone's effect is greately stronger.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e8.18e21")) end
end,
	pseudoCost = JS.D(("e8.18e21")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			color = "white",
			width = "100%"
		}, {"background", "animation", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "7th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(6) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(7) end
end,
	effectDescription = function(this)
	local table_ = "6th Milestone's effect is powered by 1.5"
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>6th Milestone's effect is powered by 1.35.<br>Exotic Prestige no longer resets on row 5 reset.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e1.57e22")) end
end,
	pseudoCost = JS.D(("e1.57e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			color = "white",
			width = "100%"
		}, {"background", "animation", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "8th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(7) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(8) end
end,
	effectDescription = function(this)
	local table_ = "6th Milestone's effect is powered by 1.2"
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Add 15 free Hyper Boosts.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e2.175e22")) end
end,
	pseudoCost = JS.D(("e2.175e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			color = "white",
			width = "100%"
		}, {"background", "animation", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "9th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(8) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(9) end
end,
	effectDescription = function(this)
	local table_ = "6th Milestone's effect is powered by 1.1."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>3rd Milestone applies to Prestige Points gain at reduced rate.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e2.395e22")) end
end,
	pseudoCost = JS.D(("e2.395e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "10th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(9) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(10) end
end,
	effectDescription = function(this)
	local table_ = "Unlock 2 new Prestige Upgrades."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Unlock a new layer in Prestige Universe.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return hasUpgrade(nil, "mp", 21) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e2.53e22")) end
end,
	pseudoCost = JS.D(("e2.53e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "11th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(10) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(11) end
end,
	effectDescription = function(this)
	local table_ = "Prestige Upgrade 11's effect is better."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Prestige Upgrade 35's effect is better.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return (JS.tonum(player.ex.dotUnl) >= 2) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e2.655e22")) end
end,
	pseudoCost = JS.D(("e2.655e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "12th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(11) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(12) end
end,
	effectDescription = function(this)
	local table_ = "Prestige Upgrade 12's effect is better."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Prestige Upgrade 45's effect is better.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return (JS.tonum(player.ex.dotUnl) >= 2) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e2.68e22")) end
end,
	pseudoCost = JS.D(("e2.68e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "13th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(12) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(13) end
end,
	effectDescription = function(this)
	local table_ = "Prestige Upgrade 13's effect is better."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Prestige Upgrade 25's effect is better.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return (JS.tonum(player.ex.dotUnl) >= 2) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e3.325e22")) end
end,
	pseudoCost = JS.D(("e3.325e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "14th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(13) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(14) end
end,
	effectDescription = function(this)
	local table_ = "Prestige Upgrade 14's effect is better."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Prestige Upgrade 15's effect is better.")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return (JS.tonum(player.ex.dotUnl) >= 2) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e3.465e22")) end
end,
	pseudoCost = JS.D(("e3.465e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "15th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(14) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(15) end
end,
	effectDescription = function(this)
	local table_ = "Unlock 2 new Prestige Upgrades."
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Unlock Exploration Upgrades and Portals.<br>Add +5 to [Corrupted Essence] Challenge Completions")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return (JS.tonum(player.ex.dotUnl) >= 2) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e3.69e22")) end
end,
	pseudoCost = JS.D(("e3.69e22")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "16th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(15) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(16) end
end,
	effectDescription = function(this)
	table_ = "3rd Milestone's effect ^1.016"
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. "<hr color='darkred' size='3'>Unlock Milestone Ambers (in Super Prestige).")
	end
	do return table_ end
end,
	pseudoUnl = function(this)
	do return (JS.tonum(player.ex.dotUnl) >= 3) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e9.3e23")) end
end,
	pseudoCost = JS.D(("e9.3e23")),
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "style"}), JS.O({
	requirementDescription = "17th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(16) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(17) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 1)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e6.215e23")) end
end,
	pseudoCost = JS.D(("e6.215e23")),
	effectDescription = function(this)
	table_ = "3rd Milestone's effect ^1.017"
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. ("<hr color='darkred' size='3'>Reduce Milestone Overflow effect by amount of Spark Milestones and points.<br>Currently: -" .. JS.str(format(nil, this:effect())) .. " to overflow effect"))
	end
	do return table_ end
end,
	effect = function(this)
	local eff = player.sp.sparkMilestones:max(1):div(4.37):add(1):mul(player.points:max(1):slog(20):max(1):log(6):add(1))
	do return eff end
end,
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription", "effect", "style"}), JS.O({
	requirementDescription = "18th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(17) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(18) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 2)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e1.605e24")) end
end,
	pseudoCost = JS.D(("e1.605e24")),
	effectDescription = function(this)
	table_ = "3rd Milestone's effect ^1.018"
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. ("<hr color='darkred' size='3'>Boost [Prestige Essence Boost I] by unspent super prestige points.<br>Currently: ^" .. JS.str(format(nil, this:effect()))))
	end
	do return table_ end
end,
	effect = function(this)
	local eff = player.sp.points:max(1):log10():max(1):log10():max(1):log10()
	do return eff end
end,
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription", "effect", "style"}), JS.O({
	requirementDescription = "19th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(18) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(19) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 3)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e5.555e25")) end
end,
	pseudoCost = JS.D(("e5.555e25")),
	effectDescription = function(this)
	table_ = "3rd Milestone's effect ^1.019"
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		table_ = (JS.str(table_) .. ("<hr color='darkred' size='3'>Increase Maximum Unlockable Spark Milestones by +1."))
	end
	do return table_ end
end,
	style = function(this)
	if JS.m(player.m.pseudoBuys, "includes", this.id) then
		do return JS.O({
			background = "red",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running inf_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription", "style"}), JS.O({
	requirementDescription = "20th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(19) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(20) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 4)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e5e26")) end
end,
	pseudoCost = JS.D(("e5e26")),
	effectDescription = function(this)
	if player[JS.k(this.layer)].best:gte(135) then
		do return "Gain 1e12% of Prestige Point gain per second." end
	end
	do return "Gain 10000% of Prestige Point gain per second." end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription"}), JS.O({
	requirementDescription = "21st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(20) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(21) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 5)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e9e27")) end
end,
	pseudoCost = JS.D(("e9e27")),
	effectDescription = function(this)
	do return "Unlock 2 new Prestige Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription"}), JS.O({
	requirementDescription = "22nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(21) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(22) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 6)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e2.39e28")) end
end,
	pseudoCost = JS.D(("e2.39e28")),
	effectDescription = function(this)
	do return "Prestige Point Gain is multiplied by 22" end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription"}), JS.O({
	requirementDescription = "23rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(22) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(23) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 7)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e1.28e29")) end
end,
	pseudoCost = JS.D(("e1.28e29")),
	effectDescription = function(this)
	do return "Prestige Upgrade 23's effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription"}), JS.O({
	requirementDescription = "24th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(23) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(24) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 8)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e1e33")) end
end,
	pseudoCost = JS.D(("e1e33")),
	effectDescription = function(this)
	do return "Prestige Upgrade 24's effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription"}), JS.O({
	requirementDescription = "25th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(24) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(25) end
end,
	pseudoUnl = function(this)
	do return (hasMilestone(nil, "sp", 2) and (JS.tonum(milestoneEffect(nil, "sp", 2)) >= 9)) end
end,
	pseudoReq = function(this)
	do return (("To infect a milestone, get " .. JS.str(format(nil, this.pseudoCost))) .. " points.") end
end,
	pseudoCan = function(this)
	do return player.points:gte(("e3.838e38")) end
end,
	pseudoCost = JS.D(("e3.838e38")),
	effectDescription = function(this)
	do return "Unlock a new layer." end
end
}, {"requirementDescription", "unlocked", "done", "pseudoUnl", "pseudoReq", "pseudoCan", "pseudoCost", "effectDescription"}), JS.O({
	requirementDescription = "26th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(25) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(26) end
end,
	effectDescription = function(this)
	do return "Keep Prestige upgrades on Super-Prestige." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "27th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(26) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(27) end
end,
	effectDescription = function(this)
	do return (("Super-Prestige Point gain is boosted by your milestones. Currently: " .. JS.str(format(nil, tmp.m.milestone27Effect))) .. "x") end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "28th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(27) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(28) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect is powered by 1.5" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "29th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(28) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(29) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect is powered by 1.2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "30th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(29) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(30) end
end,
	effectDescription = function(this)
	do return "Unlock 2 new Super-Prestige Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "31st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(30) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(31) end
end,
	effectDescription = function(this)
	do return "Prestige and Super-Prestige Upgrade 11's effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "32nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(31) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(32) end
end,
	effectDescription = function(this)
	do return "Prestige and Super-Prestige Upgrade 12's effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "33rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(32) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(33) end
end,
	effectDescription = function(this)
	do return "Prestige and Super-Prestige Upgrade 13's effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "34th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(33) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(34) end
end,
	effectDescription = function(this)
	do return "Prestige and Super-Prestige Upgrade 14's effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "35th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(34) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(35) end
end,
	effectDescription = function(this)
	do return "Unlock 2 new Super-Prestige Upgrades, 6th Milestone's effect ^3.5." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "36th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(35) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(36) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's effect ^1.036" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "37th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(36) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(37) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's effect ^1.037" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "38th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(37) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(38) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's effect ^1.038" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "39th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(38) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(39) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's effect ^1.039" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "40th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(39) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(40) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer. Unlock 2 new Super-Prestige Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "41st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(40) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(41) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.003" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "42nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(41) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(42) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^(1+(meta-milestones))." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "43rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(42) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(43) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "44th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(43) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(44) end
end,
	effectDescription = function(this)
	do return "First row of Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "45th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(44) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(45) end
end,
	effectDescription = function(this)
	do return "Unlock a new row of Prestige Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "46th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(45) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(46) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.001" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "47th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(46) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(47) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^(1+(meta-milestones^0.25))." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "48th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(47) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(48) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "49th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(48) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(49) end
end,
	effectDescription = function(this)
	do return "First row of Super-Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "50th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(49) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(50) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "51st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(50) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(51) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.00175" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "52nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(51) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(52) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^(1+(meta-milestones^0.1))." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "53rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(52) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(53) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "54th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(53) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(54) end
end,
	effectDescription = function(this)
	do return "First row of Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "55th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(54) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(55) end
end,
	effectDescription = function(this)
	do return "Unlock a new row of Super-Prestige Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "56th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(55) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(56) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.00078" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "57th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(56) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(57) end
end,
	effectDescription = function(this)
	if player[JS.k(this.layer)].best:gte(135) then
		do return "Gain 1e12% of Super-Prestige Point gain per second." end
	end
	do return "Gain 100% of Super-Prestige Point gain per second." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "58th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(57) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(58) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "59th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(58) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(59) end
end,
	effectDescription = function(this)
	do return "First row of Super-Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "60th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(59) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(60) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer. Keep Prestige upgrades on Prestige Boost." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "61st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(60) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(61) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.0005" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "62nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(61) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(62) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^(meta-milestones^0.129)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "63rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(62) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(63) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "64th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(63) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(64) end
end,
	effectDescription = function(this)
	do return "First row of Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "65th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(64) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(65) end
end,
	effectDescription = function(this)
	do return "Prestige Boost doesn't reset anything. Keep Prestige and Super-Prestige upgrades on Hyper-Prestige. Unlock 2 new Hyper-Prestige Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "66th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(65) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(66) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.0005" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "67th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(66) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(67) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^(meta-milestones^0.147)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "68th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(67) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(68) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "69th Milestone lol",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(68) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(69) end
end,
	effectDescription = function(this)
	do return "First row of Super-Prestige and Hyper-Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "70th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(69) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(70) end
end,
	effectDescription = function(this)
	do return "Keep Prestige Boost upgrades on Hyper-Prestige. Unlock a new row of Hyper-Prestige Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "71st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(70) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(71) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.001236" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "72nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(71) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(72) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^(meta-milestones^0.1)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "73rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(72) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(73) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "74th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(73) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(74) end
end,
	effectDescription = function(this)
	do return "First row of Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "75th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(74) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(75) end
end,
	effectDescription = function(this)
	if player[JS.k(this.layer)].best:gte(135) then
		do return "Gain 1e12% of Hyper-Prestige Point gain per second." end
	end
	do return "Gain 10000% of Hyper-Prestige Point gain per second." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "76th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(75) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(76) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.00157" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "77th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(76) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(77) end
end,
	effectDescription = function(this)
	do return "Unlock a Super-Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "78th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(77) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(78) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "79th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(78) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(79) end
end,
	effectDescription = function(this)
	do return "First row of Super-Prestige and Hyper-Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "80th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(79) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(80) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer. Autoget Prestige Boosts." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "81st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(80) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(81) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.0005. You keep Prestige, Super-Prestige and Prestige Boost Upgrades on Atomic-Prestige." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "82nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(81) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(82) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^(meta-milestones^0.2). You keep Hyper-Prestige Upgrades on Atomic-Prestige." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "83rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(82) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(83) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted. Autobuy the first Super-Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "84th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(83) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(84) end
end,
	effectDescription = function(this)
	do return "First row of Prestige and Atomic-Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "85th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(84) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(85) end
end,
	effectDescription = function(this)
	do return "Unlock a Hyper-Prestige buyable. Unlock a new row of Hyper-Prestige upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "86th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(85) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(86) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.0005." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "87th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(86) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(87) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^(meta-milestones^0.3)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "88th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(87) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(88) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "89th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(88) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(89) end
end,
	effectDescription = function(this)
	do return "First row of Super-Prestige and Hyper-Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "90th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(89) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(90) end
end,
	effectDescription = function(this)
	if player[JS.k(this.layer)].best:gte(135) then
		do return "Gain 1e12% of Atomic-Prestige Point gain per second." end
	end
	do return "Gain 500% of Atomic-Prestige Point gain per second." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "91st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(90) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(91) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.0005." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "92nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(91) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(92) end
end,
	effectDescription = function(this)
	do return "6th Milestone's effect ^(meta-milestones^0.3)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "93rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(92) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(93) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "94th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(93) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(94) end
end,
	effectDescription = function(this)
	do return "First row of Prestige and Atomic-Prestige Upgrades is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "95th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(94) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(95) end
end,
	effectDescription = function(this)
	do return "Unlock an Atomic-Prestige Challenge. Autobuy the first Hyper-Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "96th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(95) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(96) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.0005." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "97th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(96) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(97) end
end,
	effectDescription = function(this)
	do return "27th Milestone's effect ^(meta-milestones^0.4)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "98th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(97) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(98) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "99th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(98) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(99) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "100th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(99) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(100) end
end,
	effectDescription = function(this)
	do return "Keep Prestige and Super-Prestige upgrades on Transcend" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "101st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(100) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(101) end
end,
	effectDescription = function(this)
	do return "Keep Hyper-Prestige and Prestige Boost upgrades on Transcend" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "102nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(101) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(102) end
end,
	effectDescription = function(this)
	do return "Keep Atomic-Prestige upgrades on Transcend" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "103rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(102) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(103) end
end,
	effectDescription = function(this)
	do return "Autocomplete AP challenge 1-5 3 times on Transcend. This milestone is disabled when you're in a Transcend challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "104th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(103) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(104) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted. Unlock a new layer. Unlock 4 new Transcend upgrades. Unlock a Hyper-Prestige buyable. Unlock a Transcend challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "105th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(104) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(105) end
end,
	effectDescription = function(this)
	do return (("1st milestone's softcap starts later based on your milestones. Currently: " .. JS.str(format(nil, tmp.m.milestone105Effect))) .. "x later") end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "106th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(105) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(106) end
end,
	effectDescription = function(this)
	do return "6th and 27th milestone's effect ^(meta-milestones^0.5)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "107th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(106) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(107) end
end,
	effectDescription = function(this)
	do return "3rd Milestone's base effect exponent ^1.002. Autobuy the second Hyper-Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "108th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(107) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(108) end
end,
	effectDescription = function(this)
	do return "Autocomplete AP challenge 1-5 6 times on Transcend. This milestone is disabled when you're in a Transcend challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "109th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(108) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(109) end
end,
	effectDescription = function(this)
	do return "4th Milestone is boosted. Unlock a Transcend challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "110th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(109) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(110) end
end,
	effectDescription = function(this)
	do return "Gain 0.2% of Transcend Point gain per second. Transcend challenge 1's base goal is decreased to x^2. You can complete an AP challenge without exiting it." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "111th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(110) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(111) end
end,
	effectDescription = function(this)
	do return "Hyper Boost doesn't reset anything. Prestige boost is cheaper, and Unlock a new row of Prestige Boost upgrades. Unlock a new row of Transcend upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "112th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(111) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(112) end
end,
	effectDescription = function(this)
	do return "Transcend Challenge 2's reward is enabled while you're in Transcend Challenge 2." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "113th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(112) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(113) end
end,
	effectDescription = function(this)
	do return "Gain additional 0.3% of Transcend Point gain per second (total 0.5%). 6th and 27th milestone's effect ^(meta-milestones^0.3)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "114th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(113) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(114) end
end,
	effectDescription = function(this)
	do return "Autocomplete AP challenge 1-5 9 times on Transcend. This milestone is disabled when you're in a Transcend challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "115th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(114) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(115) end
end,
	effectDescription = function(this)
	do return "Gain additional 0.5% of Transcend Point gain per second (total 1%). Unlock a Transcend challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "116th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(115) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(116) end
end,
	effectDescription = function(this)
	do return "Gain additional 1% of Transcend Point gain per second (total 2%). Autoget Hyper Boosts." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "117th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(116) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(117) end
end,
	effectDescription = function(this)
	do return "Gain additional 3% of Transcend Point gain per second (total 5%). Prestige boost is cheaper." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "118th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(117) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(118) end
end,
	effectDescription = function(this)
	do return "Gain additional 5% of Transcend Point gain per second (total 10%). 4th Milestone is boosted." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "119th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(118) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(119) end
end,
	effectDescription = function(this)
	do return "Gain additional 10% of Transcend Point gain per second (total 20%). Hyper boost is cheaper." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "120th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(119) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(120) end
end,
	effectDescription = function(this)
	do return "Gain additional 10% of Transcend Point gain per second (total 30%). AP challenge 1-5 goals are reduced, and you can complete an AP challenge a non-integer number of times." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "121st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(120) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(121) end
end,
	effectDescription = function(this)
	do return "Autocomplete AP challenge 1-5 12 times on Transcend. This milestone is disabled when you're in a Transcend challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "122nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(121) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(122) end
end,
	effectDescription = function(this)
	do return "AP challenge 4 (Reduced Points)'s formula is changed. AP challenge 2 (No Super-Prestige) completions past-5 add the reward by 0.015 each instead of 0.01." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "123rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(122) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(123) end
end,
	effectDescription = function(this)
	do return "Gain additional 15% of Transcend Point gain per second (total 45%). Unlock a Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "124th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(123) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(124) end
end,
	effectDescription = function(this)
	do return "Unlock a new row of Prestige upgrades. Autobuy the first Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "125th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(124) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(125) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer. Reset on this layer doesn't reset anything. This layer doesn't reset on all resets except 7th row reset. Unlock a Transcend Challenge. Unlock a new row of Transcend upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "126th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(125) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(126) end
end,
	effectDescription = function(this)
	do return "Auto-collect Prestige Energy." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "127th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(126) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(127) end
end,
	effectDescription = function(this)
	do return "Gain additional 15% of Transcend Point gain per second (total 60%). Unlock a new row of Super-Prestige upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "128th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(127) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(128) end
end,
	effectDescription = function(this)
	do return "Transcend Upgrade 54 is boosted. Unlock an AP challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "129th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(128) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(129) end
end,
	effectDescription = function(this)
	do return "Unlock a Super-Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "130th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(129) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(130) end
end,
	effectDescription = function(this)
	do return "Gain additional 20% of Transcend Point gain per second (total 80%). Autobuy the second Super-Prestige buyable. AP challenge 1-3 and 6 goals are reduced. Unlock a new tab in Transcend." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "131st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(130) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(131) end
end,
	effectDescription = function(this)
	do return "Autocomplete AP challenge 1-5 15 times on Transcend. This milestone is disabled when you're in a Transcend challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "132nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(131) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(132) end
end,
	effectDescription = function(this)
	do return "The second Super-Prestige buyable's effect is better. Unlock a new row of Prestige Boost upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "133rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(132) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(133) end
end,
	effectDescription = function(this)
	do return "Gain additional 20% of Transcend Point gain per second (total 100%). The 105th milestone's effect ^1.2" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "134th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(133) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(134) end
end,
	effectDescription = function(this)
	do return "Keep Hyper Boost upgrades on Transcend." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "135th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(134) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(135) end
end,
	effectDescription = function(this)
	do return "20th Milestone, 57th Milestone, 75th Milestone and 90th Milestone's effects are 1e12%." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "136th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(135) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(136) end
end,
	effectDescription = function(this)
	do return "Unlock a new row of Transcend Upgrades. AP challenge 5's goal is reduced." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "137th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(136) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(137) end
end,
	effectDescription = function(this)
	do return "Unlock a Transcend Challenge. Transcend's requirement is 1e640 instead of 1e850 (doesn't affect Transcend Point gain)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "138th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(137) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(138) end
end,
	effectDescription = function(this)
	do return "AP challenge 2 (No Super-Prestige) completions past-5 add the reward by 0.02 each instead of 0.015." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "139th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(138) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(139) end
end,
	effectDescription = function(this)
	do return "Base effect formulas of 4th, 6th and 27th milestones are better (linear -> exponential)." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "140th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(139) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(140) end
end,
	effectDescription = function(this)
	do return "Keep AP challenge completions on Transcend (per T challenge, AP challenge completions will reset on 7th row reset). You can complete a T challenge without exiting it. Unlock a new layer." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "141st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(140) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(141) end
end,
	effectDescription = function(this)
	do return "AP challenge 6's goal is reduced." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "142nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(141) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(142) end
end,
	effectDescription = function(this)
	do return "Unlock a new row of Hyper-Prestige Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "143rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(142) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(143) end
end,
	effectDescription = function(this)
	do return "The 105th milestone's effect ^1.1" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "144th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(143) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(144) end
end,
	effectDescription = function(this)
	do return "AP challenge 2 (No Super-Prestige) completions past-5 add the reward by 0.025 each instead of 0.02." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "145th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(144) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(145) end
end,
	effectDescription = function(this)
	do return "You can complete AP Challenge 1-3 outside of it." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "146th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(145) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(146) end
end,
	effectDescription = function(this)
	do return "Unlock more Super Energy upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "147th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(146) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(147) end
end,
	effectDescription = function(this)
	do return "You can complete T Challenge 1-2 outside of it." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "148th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(147) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(148) end
end,
	effectDescription = function(this)
	do return "Double Super-Energy gain." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "149th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(148) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(149) end
end,
	effectDescription = function(this)
	do return "Double Super-Energy gain." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "150th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(149) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(150) end
end,
	effectDescription = function(this)
	do return "You can complete AP Challenge 5-6 outside of it." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "151st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(150) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(151) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "152nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(151) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(152) end
end,
	effectDescription = function(this)
	do return "Double Super-Energy gain." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "153rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(152) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(153) end
end,
	effectDescription = function(this)
	do return "Keep Prestige upgrades on PP reset." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "154th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(153) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(154) end
end,
	effectDescription = function(this)
	do return (("Power Scaler's effect is boosted by Prestige Power amount.<br>Currently: " .. JS.str(format(nil, tmp.m.milestone154Effect))) .. "x") end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "155th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(154) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(155) end
end,
	effectDescription = function(this)
	do return "Unlock More Prestige Power upgrades" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "156th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(155) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(156) end
end,
	effectDescription = function(this)
	do return "Requirement for Special Points is 1e400" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "157th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(156) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(157) end
end,
	effectDescription = function(this)
	do return "Passively generate 30% of Prestige Power gain" end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "158th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(157) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(158) end
end,
	effectDescription = function(this)
	do return "Unlock an Atomic Prestige challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "159th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(158) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(159) end
end,
	effectDescription = function(this)
	do return "Unlock last row of Prestige Power upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "160th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(159) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(160) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "161st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(160) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(161) end
end,
	effectDescription = function(this)
	do return "Unlock an Atomic Prestige buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "162nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(161) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(162) end
end,
	effectDescription = function(this)
	do return "Keep Prestige Power upgrades on Exotic Prestige reset." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "163rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(162) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(163) end
end,
	effectDescription = function(this)
	do return "Power Scaler is ^1.5 better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "164th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(163) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(164) end
end,
	effectDescription = function(this)
	do return "Power Scaler is ^1.5 better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "165th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(164) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(165) end
end,
	effectDescription = function(this)
	do return "1st Exotic Effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "166th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(165) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(166) end
end,
	effectDescription = function(this)
	do return "2nd Exotic Effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "167th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(166) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(167) end
end,
	effectDescription = function(this)
	do return "1st Exotic Effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "168th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(167) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(168) end
end,
	effectDescription = function(this)
	do return "1st Exotic Effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "169th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(168) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(169) end
end,
	effectDescription = function(this)
	do return "Increase the hardcap of Transcend Points 1e70 => 1e90." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "170th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(169) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(170) end
end,
	effectDescription = function(this)
	do return "Autoget Extra-Milestones." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "171st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(170) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(171) end
end,
	effectDescription = function(this)
	do return "3rd Exotic Effect is x1.3 better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "172nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(171) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(172) end
end,
	effectDescription = function(this)
	do return "3rd Exotic Effect is x1.1 better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "173rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(172) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(173) end
end,
	effectDescription = function(this)
	do return "4th Exotic Effect is ^1.05 better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "174th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(173) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(174) end
end,
	effectDescription = function(this)
	do return "Hyper-Prestige inflation starts ^0.1 earlier, Milestone Overflow starts 2 later." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "175th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(174) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(175) end
end,
	effectDescription = function(this)
	do return "Automate Challenge Slayer buyable." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "176th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(175) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(176) end
end,
	effectDescription = function(this)
	do return "Milestone Overflow Scale starts 1 later." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "177th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(176) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(177) end
end,
	effectDescription = function(this)
	do return "Milestone Overflow Scale starts 1 later." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "178th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(177) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(178) end
end,
	effectDescription = function(this)
	do return "Unlock last Atomic Prestige Challenge and a row of Hyper Boost Upgrades." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "179th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(178) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(179) end
end,
	effectDescription = function(this)
	do return (("Exotic Booster effect is better by Milestones amount<b> After Overflow</b> and Exotic Prestige Points amount.<br>Currently: " .. JS.str(format(nil, tmp.m.milestone179Effect))) .. "x") end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "180th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(179) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(180) end
end,
	effectDescription = function(this)
	do return "<b>Challenge Slayer'</b> effect is better." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "181st Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(180) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(181) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "182nd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(181) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(182) end
end,
	effectDescription = function(this)
	do return "Add Exotic Fusioner Tier to 179th milestone effect." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "183rd Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(182) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(183) end
end,
	effectDescription = function(this)
	do return "Unlock a Multiverse Challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "184th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(183) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(184) end
end,
	effectDescription = function(this)
	do return "<b>Unlock another Multiverse Challenge." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "185th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(184) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(185) end
end,
	effectDescription = function(this)
	do return "<b>Unlock Prestige Milestone Tree." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "186th Milestone",
	unlocked = function(this)
	do return hasMalware(nil, "m", 16) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(186) end
end,
	effectDescription = function(this)
	do return ("<b>Prestige Ashes boosts Prestige Essences effect.<br>Currently: ^" .. JS.str(format(nil, this:effect()))) end
end,
	effect = function(this)
	local eff = player.sp.ambers:max(1):log(10):pow(0.675):add(1)
	do return eff end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "effect"}), JS.O({
	requirementDescription = "187th Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(187) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(187) end
end,
	effectDescription = function(this)
	do return ("<b>Unlock a new layer in Prestige Universe.") end
end,
	style = function(this)
	if player[JS.k(this.layer)].best:gte(187) then
		do return JS.O({
			background = "green",
			color = "white",
			animation = " 3s cubic-bezier(0.4, 0, 1, 1) 0s infinite normal none running rank_milestone",
			width = "100%"
		}, {"background", "color", "animation", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"})),
	milestone4EffectExponent = function(this)
	if player.m.best:gte(118) then
		do return 0.8 end
	end
	if player.m.best:gte(109) then
		do return 0.76 end
	end
	if player.m.best:gte(104) then
		do return 0.75 end
	end
	if player.m.best:gte(98) then
		do return 0.72 end
	end
	if player.m.best:gte(93) then
		do return 0.7 end
	end
	if player.m.best:gte(88) then
		do return 0.67 end
	end
	if player.m.best:gte(83) then
		do return 0.66 end
	end
	if player.m.best:gte(78) then
		do return 0.6426 end
	end
	if player.m.best:gte(73) then
		do return 0.62 end
	end
	if player.m.best:gte(68) then
		do return 0.61 end
	end
	if player.m.best:gte(63) then
		do return 0.5875 end
	end
	if player.m.best:gte(58) then
		do return 0.57 end
	end
	if player.m.best:gte(53) then
		do return 0.5687 end
	end
	if player.m.best:gte(48) then
		do return 0.55 end
	end
	if player.m.best:gte(43) then
		do return 0.533 end
	end
	do return 0.5 end
end,
	milestone4Effect = function(this)
	if player.m.best:gte(139) then
		do return Decimal.pow(1.05, player.m.best):pow(layers.m:milestone4EffectExponent()):mul((if hasUpgrade(nil, "se", 21) then upgradeEffect(nil, "se", 21) else 1)):mul((if hasUpgrade(nil, "ep", 11) then upgradeEffect(nil, "ep", 11) else 1)) end
	end
	do return player.m.best:sub(2):pow(layers.m:milestone4EffectExponent()) end
end,
	milestone3Effect = function(this)
	local m, b
	if ((JS.eq(player.ap.activeChallenge, 21) or JS.eq(player.ap.activeChallenge, 41)) or (JS.eq(player.mp.activeChallenge, 21) and JS.eq(player.pm.activeChallenge, 11))) then
		do return JS.D(1) end
	end
	m = Decimal.log10(player.points:add(20)):pow(0.9)
	if player.m.best:gte(41) then
		m = m:pow(1.003)
	end
	if player.m.best:gte(46) then
		m = m:pow(1.001)
	end
	if player.m.best:gte(51) then
		m = m:pow(1.00175)
	end
	if player.m.best:gte(56) then
		m = m:pow(1.00078)
	end
	if player.m.best:gte(61) then
		m = m:pow(1.0005)
	end
	if player.m.best:gte(66) then
		m = m:pow(1.0005)
	end
	if player.m.best:gte(71) then
		m = m:pow(1.001236)
	end
	if player.m.best:gte(76) then
		m = m:pow(1.00157)
	end
	if player.m.best:gte(81) then
		m = m:pow(1.0005)
	end
	if player.m.best:gte(86) then
		m = m:pow(1.0005)
	end
	if player.m.best:gte(91) then
		m = m:pow(1.0005)
	end
	if player.m.best:gte(96) then
		m = m:pow(1.0005)
	end
	if player.m.best:gte(107) then
		m = m:pow(1.002)
	end
	if player.em.best:gte(2) then
		m = m:pow(1.01)
	end
	b = JS.D(2)
	if player.m.best:gte(4) then
		b = b:add(layers.m:milestone4Effect())
	end
	if player.m.best:gte(16) then
		m = m:mul(1.016)
	end
	if player.m.best:gte(17) then
		m = m:mul(1.017)
	end
	if player.m.best:gte(18) then
		m = m:mul(1.018)
	end
	if player.m.best:gte(19) then
		m = m:mul(1.019)
	end
	if player.m.best:gte(36) then
		m = m:mul(1.036)
	end
	if player.m.best:gte(37) then
		m = m:mul(1.037)
	end
	if player.m.best:gte(38) then
		m = m:mul(1.038)
	end
	if player.m.best:gte(39) then
		m = m:mul(1.039)
	end
	if hasUpgrade(nil, "t", 11) then
		m = m:mul(1.005)
	end
	if hasUpgrade(nil, "t", 23) then
		m = m:mul(1.005)
	end
	if hasUpgrade(nil, "t", 31) then
		m = m:mul(1.005)
	end
	m = m:mul(layers.t:getSpecialEffect(11))
	if hasUpgrade(nil, "pb", 42) then
		m = m:mul(upgradeEffect(nil, "pb", 42))
	end
	if hasUpgrade(nil, "p", 23) then
		b = b:mul(player.p.points:add(100000000000000000000):log10():add(1):log10():div((if player.m.best:gte(23) then 28 else 30)):add(1))
	end
	if hasUpgrade(nil, "p", 24) then
		b = b:mul(player.p.points:add(100000000000000000000):log10():log10():div((if player.m.best:gte(24) then 20 else 30)):add(1))
	end
	if hasUpgrade(nil, "sp", 24) then
		b = b:mul(player.sp.points:add(100000000000000000000):log10():log10():div(30):add(1))
	end
	if player.mm.best:gte(5) then
		b = b:mul(player.mm.best:sub(2):max(1):pow(0.5):div(75):add(1))
	end
	if player.mm.best:gte(10) then
		b = b:mul(player.mm.best:sub(2):max(1):pow(0.5):div(100):add(1))
	end
	if player.mm.best:gte(15) then
		b = b:mul(player.mm.best:sub(2):max(1):pow(0.5):div(125):add(1))
	end
	if player.mm.best:gte(20) then
		b = b:mul(player.mm.best:sub(2):max(1):pow(0.5):div(150):add(1))
	end
	b = b:mul(Decimal.pow(1.05, JS.add(JS.add(JS.add(JS.add(player.ap.challenges[21], player.ap.challenges[22]), player.t.challenges[11]), player.t.challenges[21]), player.t.challenges[31])))
	if (JS.tonum(player.ap.challenges[21]) >= 1) then
		b = b:mul((1.1 / 1.05))
	end
	if (JS.tonum(player.ap.challenges[22]) >= 1) then
		b = b:mul((1.06 / 1.05))
	end
	if (JS.tonum(player.ap.challenges[21]) >= 5) then
		b = b:mul((1.1 / 1.05))
	end
	if (JS.tonum(player.t.challenges[11]) >= 3) then
		b = b:mul(1.05)
	end
	if (JS.tonum(player.ap.challenges[21]) >= 10) then
		b = b:mul(1.1)
	end
	if (JS.tonum(player.ap.challenges[22]) >= 9) then
		b = b:mul(1.1)
	end
	if hasUpgrade(nil, "p", 41) then
		b = b:mul(player.p.points:add(100000000000000000000):log10():log10():div(30):add(1))
	end
	if hasUpgrade(nil, "p", 42) then
		b = b:mul(player.p.points:add(100000000000000000000):log10():log10():div(30):add(1))
	end
	if hasUpgrade(nil, "sp", 41) then
		b = b:mul(player.sp.points:add(100000000000000000000):log10():log10():div(30):add(1))
	end
	if hasUpgrade(nil, "sp", 42) then
		b = b:mul(player.sp.points:add(100000000000000000000):log10():log10():div(30):add(1))
	end
	if (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13)) then
		b = b:add(1):log2():add(1):log(5):pow(1.5)
	end
	if (hasUpgrade(nil, "p", 23) and inChallenge(nil, "pm", 13)) then
		b = b:mul(player.p.points:add(1e50):log2():add(1):log2():div((if player.m.best:gte(23) then 28 else 30)):add(1))
	end
	do return Decimal.pow(b, m) end
end,
	milestone6Effect = function(this)
	local p
	p = player.m.best
	if player.m.best:gte(139) then
		p = Decimal.pow(1.05, p)
	end
	if player.m.best:gte(7) then
		p = p:pow(1.5)
	end
	if player.m.best:gte(8) then
		p = p:pow(1.2)
	end
	if player.m.best:gte(9) then
		p = p:pow(1.1)
	end
	if hasUpgrade(nil, "p", 21) then
		p = p:pow(1.5)
	end
	if hasUpgrade(nil, "p", 22) then
		p = p:pow(1.5)
	end
	if player.m.best:gte(35) then
		p = p:pow(3.5)
	end
	if hasUpgrade(nil, "sp", 23) then
		p = p:pow(player.mm.best:add(JS.add(2, (if hasAchievement(nil, "ach", 21) then achievementEffect(nil, "ach", 21) else 0))))
	end
	if player.m.best:gte(42) then
		p = p:pow(player.mm.best:add(1))
	end
	if player.m.best:gte(52) then
		p = p:pow(player.mm.best:pow(0.1):add(1))
	end
	if player.mm.best:gte(9) then
		p = p:pow(1.5)
	end
	if player.m.best:gte(62) then
		p = p:pow(player.mm.best:pow(0.129))
	end
	if player.mm.best:gte(13) then
		p = p:pow(1.2)
	end
	if player.m.best:gte(72) then
		p = p:pow(player.mm.best:pow(0.1))
	end
	if player.mm.best:gte(14) then
		p = p:pow(1.2)
	end
	if player.m.best:gte(82) then
		p = p:pow(player.mm.best:pow(0.2))
	end
	if player.mm.best:gte(17) then
		p = p:pow(1.7)
	end
	if player.m.best:gte(92) then
		p = p:pow(player.mm.best:pow(0.3))
	end
	if player.m.best:gte(106) then
		p = p:pow(player.mm.best:pow(0.5))
	end
	if player.m.best:gte(113) then
		p = p:pow(player.mm.best:pow(0.3))
	end
	if player.m.best:gte(156) then
		p = p:pow(player.mm.best:pow(layers.t:getSpecialEffect(32)))
	end
	if hasMalware(nil, "m", 5) then
		p = p:pow(10000000000)
	end
	if hasUpgrade(nil, "p", 25) then
		p = p:pow(upgradeEffect(nil, "p", 25))
	end
	if hasMalware(nil, "m", 6) then
		p = p:pow(1.35)
	end
	do return softcap(nil, p, JS.D("ee10"), 0.15) end
end,
	milestone27Effect = function(this)
	local p
	p = player.m.best
	if player.m.best:gte(139) then
		p = Decimal.pow(1.05, p)
	end
	if player.m.best:gte(28) then
		p = p:pow(1.5)
	end
	if player.m.best:gte(29) then
		p = p:pow(1.2)
	end
	if hasUpgrade(nil, "sp", 23) then
		p = p:pow(player.mm.best:add(2))
	end
	if player.mm.best:gte(2) then
		p = p:pow(2)
	end
	if player.mm.best:gte(3) then
		p = p:pow(2)
	end
	if player.mm.best:gte(4) then
		p = p:pow(2)
	end
	if player.m.best:gte(47) then
		p = p:pow(player.mm.best:pow(0.25):add(1))
	end
	if player.mm.best:gte(6) then
		p = p:pow(1.5)
	end
	if player.mm.best:gte(7) then
		p = p:pow(1.5)
	end
	if player.mm.best:gte(8) then
		p = p:pow(1.5)
	end
	if player.mm.best:gte(11) then
		p = p:pow(1.2)
	end
	if player.mm.best:gte(12) then
		p = p:pow(1.2)
	end
	if player.m.best:gte(67) then
		p = p:pow(player.mm.best:pow(0.147))
	end
	if player.mm.best:gte(16) then
		p = p:pow(1.2)
	end
	if player.m.best:gte(87) then
		p = p:pow(player.mm.best:pow(0.3))
	end
	if player.mm.best:gte(18) then
		p = p:pow(1.8)
	end
	if player.mm.best:gte(19) then
		p = p:pow(1.9)
	end
	if player.m.best:gte(97) then
		p = p:pow(player.mm.best:pow(0.4))
	end
	if player.m.best:gte(106) then
		p = p:pow(player.mm.best:pow(0.5))
	end
	if player.m.best:gte(113) then
		p = p:pow(player.mm.best:pow(0.3))
	end
	do return p end
end,
	milestone105Effect = function(this)
	local p
	p = player.m.best:div(100)
	if player.m.best:gte(133) then
		p = p:pow(1.2)
	end
	if player.m.best:gte(143) then
		p = p:pow(1.1)
	end
	do return p end
end,
	milestone154Effect = function(this)
	local p
	p = player.pp.points
	if player.m.best:gte(152) then
		p = Decimal.mul(0.1, p):add(1):pow(0.85)
	end
	if hasUpgrade(nil, "pp", 21) then
		p = p:pow(layers.t:getSpecialEffect(31))
	end
	p = p:mul(tmp.ap.challenges[41].rewardEffect):max(1)
	p = softcap(nil, p, JS.D("1e800"), 0.1)
	do return softcap(nil, p, JS.D("1e1000"), 0.01) end
end,
	milestone179Effect = function(this)
	local p
	p = player.m.best:add((if player.m.best:gte(182) then player.ep.buyables[11] else 0)):sub(getCostOverflowStart(nil)):pow(25):pow(player.ep.points:add(1):log10():add(1):log(2)):max(1)
	if JS.eq(player.ap.activeChallenge, 42) then
		do return JS.D(1) end
	end
	if hasUpgrade(nil, "ep", 12) then
		p = p:pow(upgradeEffect(nil, "ep", 12))
	end
	p = softcap(nil, p, JS.D("1e800"), 0.1)
	do return softcap(nil, p, JS.D("1e1000"), 0.01) end
end,
	resetDescription = "Get ",
	doReset = function(this)

end,
	tabFormat = JS.A(7, "main-display", "prestige-button", "resource-display", JS.A(2, "display-text", function(this)
	if (not hasUpgrade(nil, "mp", 14)) then
		do return ("Milestone cost scaling starts at " .. JS.str(format(nil, tmp.m.getScalingStart, 4))) end
	end
end), JS.A(2, "display-text", function(this)
	do return ("Milestone cost exponent is " .. JS.str(format(nil, tmp.m.exponent, 4))) end
end), JS.A(2, "display-text", function(this)
	if (player.pm.essence:gte(1) and player.pm.best:gte(15)) then
		local prEsEffect = tmp.pm.essenceBoost:pow(10000000000000000000):pow((if hasUpgrade(nil, "ex", 11) then upgradeEffect(nil, "ex", 11) else 1))
		if hasMilestone(nil, "m", 185) then
			prEsEffect = prEsEffect:pow(milestoneEffect(nil, "m", 185))
		end
		do return (("Prestige Essences boosts points after softcap by " .. JS.str(format(nil, prEsEffect, 4))) .. "x") end
	end
end), "milestones")
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "gainExp", "row", "base", "milestonePopups", "exponent", "getScalingStart", "hotkeys", "layerShown", "resetsNothing", "autoPrestige", "milestones", "milestone4EffectExponent", "milestone4Effect", "milestone3Effect", "milestone6Effect", "milestone27Effect", "milestone105Effect", "milestone154Effect", "milestone179Effect", "resetDescription", "doReset", "tabFormat"}))

end
