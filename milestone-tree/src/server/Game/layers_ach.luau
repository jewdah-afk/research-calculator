--!nocheck
-- transpiled from layers/ach.js by port/build.js: do not edit
return function()
-- transpiled from layers/ach.js
addLayer(nil, "ach", JS.O({
	name = "achievements",
	symbol = "★",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = true,
		points = JS.D(0)
	}, {"unlocked", "points"}) end
end,
	color = "gold",
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	tooltip = function(this)
	do return (JS.str(format(nil, JS.len(player.ach.achievements), 0)) .. " Achievements.") end
end,
	canReset = function(this)
	do return (player.points:gte(tmp.pm.nextAt) and JS.isnil(player.pm.activeChallenge)) end
end,
	gainExp = function(this)
	do return JS.D(1) end
end,
	achBoost = function(this)
	local eff = (JS.D(JS.len(player.ach.achievements))):add(1):pow(1.275)
	do return eff end
end,
	newRow = 0,
	row = "side",
	layerShown = function(this)
	do return true end
end,
	resetsNothing = function(this)
	do return true end
end,
	achievements = JS.O({
	tooltipStyle = function(this)
	do return JS.O({
		border = "2px solid lime",
		["border-image"] = "linear-gradient(to right, gold 0%, rgb(252, 241, 94) 50%,gold 100%)",
		width = "300px",
		["border-image-slice"] = "1"
	}, {"border", "border-image", "width", "border-image-slice"}) end
end,
	[11] = JS.O({
	name = "Where it all begins",
	done = function(this)
	do return getPointGen(nil):gte(1) end
end,
	tooltip = function(this)
	do return "Start generating points!" end
end
}, {"name", "done", "tooltip"}),
	[12] = JS.O({
	name = "Not the prestige points again!",
	done = function(this)
	do return player.m.best:gte(5) end
end,
	tooltip = function(this)
	do return (("Unlock Prestige Layer.<br>Reward: 1st mlestone is " .. JS.str(format(nil, this:effect()))) .. "x better by prestige points.") end
end,
	effect = function(this)
	do return player.p.points:add(1):log10():pow(0.5):add(1) end
end
}, {"name", "done", "tooltip", "effect"}),
	[13] = JS.O({
	name = "Softcapped already?",
	done = function(this)
	do return player.m.best:gte(tmp.m.getScalingStart) end
end,
	tooltip = function(this)
	do return (("Reach the start of Milestone Scaling.<br>Reward: Milestone Scaling starts +" .. JS.str(format(nil, this:effect()))) .. " later based on best milestones.") end
end,
	effect = function(this)
	do return softcap(nil, player.m.best:div(tmp.m.getScalingStart):pow(1.05), JS.D(3.5), 0.1) end
end
}, {"name", "done", "tooltip", "effect"}),
	[14] = JS.O({
	name = "Would you rather be automated?",
	done = function(this)
	do return player.m.best:gte(20) end
end,
	tooltip = function(this)
	do return "Automate the Prestige Points gain." end
end
}, {"name", "done", "tooltip"}),
	[15] = JS.O({
	name = "Prestige points again? Wait, it's super ones!",
	done = function(this)
	do return player.m.best:gte(25) end
end,
	tooltip = function(this)
	do return (("Unlock Super Prestige Layer.<br>Reward: Prestige Points are " .. JS.str(format(nil, this:effect()))) .. "x better by itself.") end
end,
	effect = function(this)
	do return player.p.points:add(1):log2():pow(0.5):add(1) end
end
}, {"name", "done", "tooltip", "effect"}),
	[16] = JS.O({
	name = "Getting rich!",
	done = function(this)
	do return player.points:gte("1e1000") end
end,
	tooltip = function(this)
	do return "Get 1e1000 points" end
end
}, {"name", "done", "tooltip"}),
	[17] = JS.O({
	name = "Not the another milestones...",
	done = function(this)
	do return player.mm.best:gte(1) end
end,
	tooltip = function(this)
	do return "Get Meta-Milestone" end
end
}, {"name", "done", "tooltip"}),
	[18] = JS.O({
	name = "Getting richer?",
	done = function(this)
	do return player.points:gte("1e10000") end
end,
	tooltip = function(this)
	do return "Get 1e10000 points" end
end
}, {"name", "done", "tooltip"}),
	[19] = JS.O({
	name = "Get boosted for your prestige!",
	done = function(this)
	do return player.pb.points:gte(1) end
end,
	tooltip = function(this)
	do return (("Get a Prestige Boost.<br>Reward: Super Prestige Points are " .. JS.str(format(nil, this:effect()))) .. "x better by prestige boosts.") end
end,
	effect = function(this)
	do return player.pb.points:add(1):pow(2) end
end
}, {"name", "done", "tooltip", "effect"}),
	[21] = JS.O({
	name = "I can handle it without you :)",
	done = function(this)
	do return (JS.eq(JS.len(player.p.upgrades), 0) and player.p.points:gte("1e12500")) end
end,
	tooltip = function(this)
	do return (("Get 1e12500 Prestige Points without prestige upgrades.<br>Reward: Super Prestige Upgrade 23 base is +" .. JS.str(format(nil, this:effect(), 4))) .. " better by prestige points.") end
end,
	effect = function(this)
	do return player.p.points:add(1):log10():add(1):log2():add(1):div(1000) end
end
}, {"name", "done", "tooltip", "effect"}),
	[22] = JS.O({
	name = "Would you rather be automated too?",
	done = function(this)
	do return player.m.best:gte(57) end
end,
	tooltip = function(this)
	do return "Automate the Super Prestige Points gain." end
end
}, {"name", "done", "tooltip"}),
	[23] = JS.O({
	name = "Wooohoooo!!!",
	done = function(this)
	do return (JS.eq(player.ap.activeChallenge, 11) and player.p.points:gte("e3500000")) end
end,
	tooltip = function(this)
	do return (("Get e3,500,000 Prestige Points in Atomic Challenge 11.<br>Reward: Prestige Upgrade 31's effect is +" .. JS.str(format(nil, this:effect(), 4))) .. " better by prestige points.") end
end,
	effect = function(this)
	do return softcap(nil, player.p.points:add(1):log10():add(1):log10():add(1):div(10), JS.D(0.1), 0.1) end
end
}, {"name", "done", "tooltip", "effect"}),
	[24] = JS.O({
	name = "So many boosters!!!",
	done = function(this)
	do return (JS.eq(player.ap.activeChallenge, 12) and player.pb.points:gte(60)) end
end,
	tooltip = function(this)
	do return (("Get 60 Prestige Boosts in Atomic Challenge 12.<br>Reward: Hyper Prestige Upgrade 23's effect is +" .. JS.str(format(nil, this:effect(), 4))) .. " better by super prestige points.") end
end,
	effect = function(this)
	do return player.sp.points:add(1):log10():add(1):log10():add(1):log10():add(1):div(1000) end
end
}, {"name", "done", "tooltip", "effect"}),
	[25] = JS.O({
	name = "Without Prestige???",
	done = function(this)
	do return (JS.tonum(player.ap.challenges[31]) >= 1) end
end,
	tooltip = function(this)
	do return "Get 1 Atomic Prestige 31 completion." end
end
}, {"name", "done", "tooltip"}),
	[26] = JS.O({
	name = "You can be dilated and without prestige! Cool!",
	done = function(this)
	do return ((JS.eq(player.ap.activeChallenge, 31) and JS.eq(player.t.activeChallenge, 11)) and player.points:gte("1e150000")) end
end,
	tooltip = function(this)
	do return (("Get 1e150000 Points while in Transcend Challenge 11 and Atomic Challenge 31.<br>Reward: Transcend Point gain is " .. JS.str(format(nil, this:effect()))) .. "x better based on achievements") end
end,
	effect = function(this)
	do return (JS.D(JS.len(player.ach.achievements))):add(1):log2():pow(1.5) end
end
}, {"name", "done", "tooltip", "effect"}),
	[27] = JS.O({
	name = "Fully Transcended! Or not?",
	done = function(this)
	do return (((JS.m(player.t.upgrades, "includes", 11) and JS.m(player.t.upgrades, "includes", 12)) and JS.m(player.t.upgrades, "includes", 13)) and JS.m(player.t.upgrades, "includes", 14)) end
end,
	tooltip = function(this)
	do return "Buy first row of Transcend Upgrades.<br>Reward: Keep +3 AP challenges completions." end
end
}, {"name", "done", "tooltip"}),
	[28] = JS.O({
	name = "Even more boosters!!",
	done = function(this)
	do return player.hb.points:gte(7) end
end,
	tooltip = function(this)
	do return "Get 7 Hyper Boosts.<br>Reward: Add +0.015 to hyper Boost effect." end
end
}, {"name", "done", "tooltip"}),
	[29] = JS.O({
	name = "I. AM. POWER!!!",
	done = function(this)
	do return player.pp.points:gte(1) end
end,
	tooltip = function(this)
	do return "Get a Prestige Power." end
end
}, {"name", "done", "tooltip"})
}),
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(1, function(this)
	if (player.tab == "ach") then
		do return JS.A(2, "column", JS.A(6, "prestige-button", "resource-display", JS.A(2, "display-text", (((((("You completed <h2 style='color:  gold; text-shadow: gold 0px 0px 10px;'> " .. JS.str(format(nil, JS.len(player.ach.achievements), 0))) .. "/") .. JS.str(format(nil, (JS.len(Object.keys(tmp.ach.achievements)) - 3), 0))) .. "</h2> achievements, that boosts 1st milestone effect by ") .. JS.str(format(nil, tmp.ach.achBoost))) .. "x.")), "blank", "achievements", "blank")) end
	end
end)
})
}),
	doReset = function(this)

end
}, {"name", "symbol", "position", "startData", "color", "gainMult", "tooltip", "canReset", "gainExp", "achBoost", "newRow", "row", "layerShown", "resetsNothing", "achievements", "tabFormat", "doReset"}))

end
