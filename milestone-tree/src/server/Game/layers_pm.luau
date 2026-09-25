--!nocheck
-- transpiled from layers/pm.js by port/build.js: do not edit
return function()
-- transpiled from layers/pm.js
addLayer(nil, "pm", JS.O({
	name = "prestige-milestone",
	symbol = "PM",
	position = 0,
	startData = function(this)
	do return JS.O({
		unlocked = true,
		points = JS.D(0),
		essence = JS.D(0),
		best = JS.D(0),
		challengeTimer = JS.D(0)
	}, {"unlocked", "points", "essence", "best", "challengeTimer"}) end
end,
	color = "#f71c50",
	requires = function(this)
	local b = JS.D(25)
	do return b end
end,
	resource = function(this)
	if player[JS.k(this.layer)].best:gte(15) then
		if (math.fmod(JS.tonum(Date.now()), 1400) < 350) then
			do return "p███t█ge m██e█to██s." end
		end
		if (math.fmod(JS.tonum(Date.now()), 1400) < 700) then
			do return "p██s██g█ █i███ton██" end
		end
	end
	do return "prestige milestones" end
end,
	baseResource = "points",
	baseAmount = function(this)
	do return player.points end
end,
	type = "static",
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	canReset = function(this)
	do return (player.points:gte(tmp.pm.nextAt) and JS.isnil(player.pm.activeChallenge)) end
end,
	gain = function(this)
	local i
	local gain = JS.D(0)
	if player.pm.best:gte(1) then
		gain = gain:add(tmp.pm.reduce)
	end
	if JS.eq(player.mp.modeE, true) then
		gain = gain:mul(buyableEffect(nil, "mp", 22).eff)
	end
	if player.pm.best:gte(4) then
		gain = gain:mul(tmp.pm.pMilestone4Effect)
	end
	if player.pep.buyables[11]:gte(1) then
		gain = gain:mul(tmp.pep.prOneEffect)
	end
	if player.cp.formatted:gte(1) then
		gain = gain:mul(corruptEffect(nil))
	end
	local s = JS.D(1)
	for _, __k1 in JS.keys(player.cp.grid) do
		i = __k1
		if (JS.eq(getGridData(nil, "cp", i).active, true) and (getGridData(nil, "cp", i).type == "pm")) then
			s = (if gridEffect(nil, "cp", i):gte(s) then gridEffect(nil, "cp", i) else s)
		end
	end
	if JS.eq(player.pm.activeChallenge, 11) then
		gain = gain:pow((0.3 * JS.tonum(player.pm.challengeTimer:add(1):log10():add(1))))
	end
	if (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13)) then
		do return player.pm.challengeTimer:add(1):pow(2.75):add(1) end
	end
	if (JS.tonum(challengeCompletions(nil, "pm", 11)) >= 1) then
		gain = gain:mul(challengeEffect(nil, "pm", 11))
	end
	if hasUpgrade(nil, "sp", 51) then
		gain = gain:mul(upgradeEffect(nil, "sp", 51))
	end
	do return gain:div(s) end
end,
	reduce = function(this)
	local base = 0.5
	if player.mp.buyables[23]:gte(1) then
		base = JS.add(base, buyableEffect(nil, "mp", 23):toNumber())
	end
	local eff = player.mp.points:add(1):log2():add(1):pow(base)
	if player.pm.best:gte(3) then
		eff = eff:mul(5)
	end
	if player.pep.buyables[11]:gte(1) then
		eff = eff:mul(tmp.pep.prOneEffect:pow(0.5))
	end
	if (JS.eq(player.mp.modeP, true) and (JS.tonum(tmp.pm.count) >= 11)) then
		eff = eff:div(tmp.pm.pChalReward3)
	end
	if (JS.eq(player.mp.modeE, true) and (JS.tonum(tmp.pm.count) >= 11)) then
		eff = eff:mul(tmp.pm.pChalReward3)
	end
	do return eff end
end,
	essenceBoost = function(this)
	local eff = player.pm.essence:add(1):log2():pow(2):mul(0.1)
	eff = eff:mul(buyableEffect(nil, "mp", 22).eff)
	if JS.eq(player.mp.modeP, true) then
		eff = eff:mul(buyableEffect(nil, "mp", 22).eff:div(2):add(3))
	end
	if (not JS.isnil(player.pm.activeChallenge)) then
		eff = eff:mul((1.5 * JS.tonum(player.pm.challengeTimer:add(1):log10())))
	end
	do return eff:max(1) end
end,
	gainExp = function(this)
	do return JS.D(1) end
end,
	newRow = 0,
	row = 0,
	base = JS.D(12),
	exponent = function(this)
	if JS.eq(player.pm.points, 14) then
		do return player.pm.points:div(10):add(0.291) end
	end
	if player.pm.points:gte(9) then
		do return player.pm.points:div(10):add(0.31) end
	end
	if player.pm.points:gte(7) then
		do return JS.D(1.25) end
	else
		do return JS.D(1) end
	end
end,
	hotkeys = JS.A(1, JS.O({
	key = "ctrl+p",
	description = "Ctrl+P: Get Prestige Milestone",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return JS.eq(player.mp.activeChallenge, 21) end
end,
	resetsNothing = function(this)
	do return true end
end,
	milestones = JS.A(16, JS.O({
	requirementDescription = "1st Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(0) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	effectDescription = function(this)
	do return "Get prestige essence/s based on how much points gain was reduced." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "2nd Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(1) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	effectDescription = function(this)
	do return "Unlock more Multiverse Fusioners." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "3rd Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(2) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	effectDescription = function(this)
	do return "Make 1st milestone reducing effect 5.00x stronger." end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "4th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(3) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	effectDescription = function(this)
	do return (("Points affects prestige essence gain. Currently: " .. JS.str(format(nil, tmp.pm.pMilestone4Effect))) .. "x") end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription"}), JS.O({
	requirementDescription = "5th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(4) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	effectDescription = function(this)
	do return "Prestigify Exotic Prestige Points. (Unlock the layer again but with new content)" end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 4) then
		do return JS.O({
			background = "#3C2D15",
			["border-color"] = "#c89646",
			color = "#c89646",
			width = "100%",
			["border-image-slice"] = "1"
		}, {"background", "border-color", "color", "width", "border-image-slice"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "6th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(5) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(6) end
end,
	effectDescription = function(this)
	do return "Unlock a new layer." end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 5) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "7th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(6) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(7) end
end,
	effectDescription = function(this)
	do return "Unlock 1 more upgrade on row 1 layers." end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 6) then
		do return JS.O({
			background = "linear-gradient(to right, #00520b 0%, #3C2D15 50%)",
			["border-color"] = "transparent",
			["background-color"] = "transparent",
			["border-image"] = "linear-gradient(to right, lime 0%, lime 20%,#c89646 50%)",
			color = "white",
			width = "100%",
			["border-image-slice"] = "1"
		}, {"background", "border-color", "background-color", "border-image", "color", "width", "border-image-slice"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "8th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(7) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(8) end
end,
	effectDescription = function(this)
	do return "Unlock 1 more upgrade on row 1 layers." end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 7) then
		do return JS.O({
			background = "linear-gradient(to right, #00520b 0%, #3C2D15 50%)",
			["border-color"] = "transparent",
			["background-color"] = "transparent",
			["border-image"] = "linear-gradient(to right, lime 0%, lime 20%,#c89646 50%)",
			color = "white",
			width = "100%",
			["border-image-slice"] = "1"
		}, {"background", "border-color", "background-color", "border-image", "color", "width", "border-image-slice"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "9th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(8) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(9) end
end,
	effectDescription = function(this)
	do return "Massively reduce post-15th level Trojan corruption goals and slightly reduce Backdoor corruption goals." end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 8) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "10th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(9) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(10) end
end,
	effectDescription = function(this)
	do return "Unlock Corruption Milestones." end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 9) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = function(this)
	if player[JS.k(this.layer)].best:gte(15) then
		if (math.fmod(JS.tonum(Date.now()), 1400) < 350) then
			do return "11th Pres████ ██l█s██n█." end
		end
		if (math.fmod(JS.tonum(Date.now()), 1400) < 700) then
			do return "11th P███████ M███s█o██." end
		end
	end
	do return "11th Prestige Milestone" end
end,
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(10) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(11) end
end,
	effectDescription = function(this)
	do return "Unlock 1 more upgrade on row 1 layers." end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 10) then
		do return JS.O({
			background = "linear-gradient(to right, #00520b 0%, #3C2D15 50%)",
			["border-color"] = "transparent",
			["background-color"] = "transparent",
			["border-image"] = "linear-gradient(to right, lime 0%, lime 20%,#c89646 50%)",
			color = "white",
			width = "100%",
			["border-image-slice"] = "1"
		}, {"background", "border-color", "background-color", "border-image", "color", "width", "border-image-slice"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = function(this)
	if player[JS.k(this.layer)].best:gte(15) then
		if (math.fmod(JS.tonum(Date.now()), 1400) < 350) then
			do return "12th Pres████ ██l█s██n█." end
		end
		if (math.fmod(JS.tonum(Date.now()), 1400) < 700) then
			do return "12th P███████ M███s█o██." end
		end
	end
	do return "12th Prestige Milestone" end
end,
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(11) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(12) end
end,
	effectDescription = function(this)
	do return (("Scaled Essence Fusioners starts +" .. JS.str(format(nil, tmp.pm.pMilestone11Effect, 3))) .. " later based on Prestige Essence. Unlock Prestige Universe Challenges.") end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 11) then
		do return JS.O({
			background = "rgba(208, 56, 0,0.1)",
			["border-color"] = "rgb(208, 56, 0)",
			color = "rgb(208, 56, 0)",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = function(this)
	if player[JS.k(this.layer)].best:gte(15) then
		if (math.fmod(JS.tonum(Date.now()), 1400) < 350) then
			do return "13th Pres████ M███st██e." end
		end
		if (math.fmod(JS.tonum(Date.now()), 1400) < 700) then
			do return "13th P███████ M███s██ne." end
		end
	end
	do return "13th Prestige Milestone" end
end,
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(12) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(13) end
end,
	effectDescription = function(this)
	do return (("Reduce maximum corruption level that can spawn by -" .. JS.str(format(nil, tmp.pm.pMilestone13Effect, 3))) .. " based on Prestige Milestones.") end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 12) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = function(this)
	if player[JS.k(this.layer)].best:gte(15) then
		if (math.fmod(JS.tonum(Date.now()), 1400) < 350) then
			do return "14th Pres████ M█s█o█e." end
		end
		if (math.fmod(JS.tonum(Date.now()), 1400) < 700) then
			do return "14th P███████ ███es█o██." end
		end
	end
	do return "14th Prestige Milestone" end
end,
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(13) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(14) end
end,
	effectDescription = function(this)
	do return (("Reduce corruption goals by /" .. JS.str(format(nil, tmp.pm.pMilestone14Effect, 3))) .. " based on Prestige Milestones and Prestige Essences.") end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 13) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "15th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(14) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(15) end
end,
	effectDescription = function(this)
	if player[JS.k(this.layer)].best:gte(15) then
		if (math.fmod(JS.tonum(Date.now()), 1400) < 350) then
			do return "S̖̗̮̖̠̏̈̆̈́õ͖̯͚̗̊m̜̱̎e̹͙̫̬ͥ̌ͦ̓ͪ̔t̲͕̽ͥ͆́ͨͫĥ̳̣̦̟̟͗̄̂ḭ̠̌̎͌ͫn͆͑̽g̓͌ ͙͗̊̒͌ͨ̚î̻̜͓͖͇̝̲̓̿̇ͪͨ͌ṡ͚̼̒̔ͮ ͓̈͑͊̌̇ͨw͕̲̏̿ͣ̈ͭ̿r̞̉o̘̝̱̗͙ͬn̺̜̤͐ͭͯ̽g̖͚̩̓̌̅͋̌̿̽ in Prestige Universe...<br>Prestige Essences effect is applied in Normal Universe (after the softcap)." end
		end
		if (math.fmod(JS.tonum(Date.now()), 1400) < 700) then
			do return "S̮̠̫̭͉͗͋o͖̤̖̗͎̪͊̍ͬ̏̌̚m̙̰̜ͤ̉̓̈̉͑ͫ̀e̖̪̜ͨ͛ͫ͛ͤt͇̦̥̦̭̳̺ͫ̈ḣ͂͊͗͐i̺̟̳̓͊͋n̩̼̹̠̲̆͒̿ͯg͍͈̅̐͑ͯ̚ͅ ͈̪̠̳͕̣͍̓̈ͯ͐̇̿̽ͭ̐i͚͚͊s̹͇͆̋ ͚̝̺͖̦̐̽̅ͬ̄ͭw̭̾ͣ͂̇͌ͫͅr̺͚̤̞̎̀ͤͥ̚o̬̣͇̱ͮ͒ṉ̮̭̟̍͋ͫͬ͂̾ͥǧ̪̞͇͓̥ͤ́͐̇̏ in Prestige Universe...<br>Prestige Essences effect is applied in Normal Universe (after the softcap)." end
		end
		if (math.fmod(JS.tonum(Date.now()), 1400) < 1050) then
			do return "S͉̯̦͔̟̬͙ͦ̋̂̓̎ͤ̓ͣ̇̚ͅͅọ͎͎͈͈̙̘ͪ̿̍̋m̳̪̖̮̻̻͔̱̰̦̬͈̦͓̳͚̬̞ͬ̃ͮ͛ͤ̌̍ͮ͐̄ë͙̙̞̼̮̰̩̗͛̂̇̄̓͗̿̏̽̈ͦ͛t̙͈̗̩͛ͧ͂̄͊͗ͮ̂̾̑̌h̬̳͍̥̺̣̙̹̬̤̣͎ͧ̑̾́ͭͩ̊͑ͬ̽̅́́̍̇̔ͭi̘̹̹̙̺̞̠͍̗̖̪̮̽̇͑͆̒ͭ̋͋͑̏ͧͅn̺̙̺̖̬̘̱̠̠̺̻͑̌̅ͪ́̉̒͊ͧ̈́ͦͥͦ̏͊g̠͍̠͖̖͙͉̮͉͍͚͈͎͗͐ͫ̀ͣ̀̿̾ͦ̉͐́ͦ̍̔ͨͥ͆ ̻̫͈̼̣͖̫͕͎̿͛̈́͗̆̍̊̂ͬ̓̍ͥ̄̆̌i̗̞̤͇͎̪͈͙̦͕̟̬͍ͭ͂ͧ́̐̇͆ͅs͓̰͍͖̭̭ͨ͌̎ͭ̊̓̓͐̔ͫ̓̊ͭͅ ͇̗̹̮̪̼̳͎̹̔͂̂̔̉̓ͦ̊͂̋́ͤ̍̂̚̚ẇ̼͙̼̟̪̇̄͑ͫͤ̒ͧ̈́̐͒͑̌̀̉ͤ̓ͮr̞͔̖͔̩͉̻͖̙̺̪̯͙͓̞ͯ̈͛ͮͨͯͪ͐ͨ̅͋̇͑ͫ́̓ͯͪ͆ŏ̞̺͎͍̟̭̞͍̯̩̣͉̦͚͚̥ͭ̊ͮ̈̈́̐̄̚ṅ̬͔̠̫̣̺̫͖̺͕͖̰̗͔̗̌̒̀̏ͬ̏̓͌̊͒̄̉̌̅͆̋͛͗ͅg͈͖̳͉̳͍ͨ̽ͩ̽̑̓ͥ̍̈ͩ̈͐̄͒́͗ͦ in Prestige Universe...<br>Prestige Essences effect is applied in Normal Universe (after the softcap)." end
		end
	end
	do return "Something is wrong in Prestige Universe...<br>Prestige Essences effect is applied in Normal Universe (after the softcap)." end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 14) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"}), JS.O({
	requirementDescription = "16th Prestige Milestone",
	unlocked = function(this)
	do return player[JS.k(this.layer)].best:gte(15) end
end,
	done = function(this)
	do return player[JS.k(this.layer)].best:gte(16) end
end,
	effectDescription = function(this)
	do return "4th Pr-Exotic Prestige effect is slightly better." end
end,
	style = function(this)
	if hasMilestone(nil, "pm", 15) then
		do return JS.O({
			background = "#00520b",
			["border-color"] = "lime",
			color = "lime",
			width = "100%"
		}, {"background", "border-color", "color", "width"}) end
	end
end
}, {"requirementDescription", "unlocked", "done", "effectDescription", "style"})),
	challenges = JS.O({
	[11] = JS.O({
	levelScale = function(this)
	local scale = (JS.D(35)):add((JS.D((if (JS.tonum(challengeCompletions(nil, "pm", 11)) >= 3) then 4 else 5))):add((if (JS.tonum(challengeCompletions(nil, "pm", 11)) >= 5) then 2.75 else 0)):mul(challengeCompletions(nil, "pm", 11)):floor())
	do return scale end
end,
	onEnter = function(this)
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return ((JS.tonum(player.cp.grid[JS.k(x)].level) < 1) and (not JS.eq(x, 101))) end
	end)
	JS.set(player.cp.grid, JS.k(slots[0]), JS.O({
		level = this:levelScale(),
		active = true,
		fixed = false,
		type = "div"
	}, {"level", "active", "fixed", "type"}))
	JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
	JS.setk(player.cp, "peInCorrupt", JS.D(0))
	JS.setk(player.cp, "cooldown", math.huge)
	JS.setk(player.cp, "cooldown2", math.huge)
	JS.setk(player.cp, "trojanChosen", nil)
	JS.setk(player.cp, "chosenBackdoor", nil)
end,
	onExit = function(this)
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return JS.eq(player.cp.grid[JS.k(x)].active, true) end
	end)
	JS.set(player.cp.grid, JS.k(slots[0]), JS.O({
		level = 0,
		active = false,
		fixed = false,
		type = "div"
	}, {"level", "active", "fixed", "type"}))
	JS.setk(player.pm, "challengeTimer", JS.D(0))
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
	JS.setk(player.cp, "peInCorrupt", JS.D(0))
	JS.setk(player.cp, "cooldown", buyableEffect(nil, "cp", 33))
	JS.setk(player.cp, "cooldown2", buyableEffect(nil, "cp", 34))
	JS.setk(player.cp, "trojanChosen", nil)
	JS.setk(player.cp, "chosenBackdoor", nil)
end,
	name = "Corrupted Essences",
	completionLimit = function(this)
	local comps = JS.D(5)
	if hasMalware(nil, "m", 14) then
		comps = comps:add(5)
	end
	do return comps end
end,
	challengeDescription = function(this)
	do return (((((((JS.str((if JS.eq(player.pm.activeChallenge, 11) then (("You spent " .. JS.str(formatTime(nil, player.pm.challengeTimer))) .. " in this challenge.") else "")) .. "<br>You are trapped in Level ") .. JS.str(format(nil, this:levelScale()))) .. " Trojan Corruption, Prestige Essences gain formula is much weaker, but increases over time.") .. "<br>") .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 0))) .. JS.str((if hasMalware(nil, "m", 14) then "/10 completions." else "/5 completions."))) .. "<br>At 2 completions, unlock a new challenge!") end
end,
	unlocked = function(this)
	do return player.pm.best:gte(12) end
end,
	goal = function(this)
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return JS.eq(player.cp.grid[JS.k(x)].active, true) end
	end)
	if (JS.eq(player.pm.activeChallenge, 11) and (JS.len(slots) > 0)) then
		do return gridCost(nil, "cp", slots[0]) end
	else
		do return JS.D(math.huge) end
	end
end,
	canComplete = function(this)
	do return (player.points:gte(tmp.pm.challenges[JS.k(this.id)].goal) and JS.eq(player.pm.activeChallenge, 11)) end
end,
	rewardEffect = function(this)
	local ret = (7.39 ^ JS.tonum(player.pm.challenges[11]))
	do return ret end
end,
	goalDescription = function(this)
	do return ("Fix the corruption" .. JS.str((if JS.eq(player.pm.activeChallenge, 11) then ((" (Reach " .. JS.str(format(nil, this:goal()))) .. " Points in this challenge)") else ""))) end
end,
	currencyDisplayName = "Points",
	rewardDescription = function(this)
	do return (("Multiply Prestige Essences gain.<br>Currently: " .. JS.str(format(nil, challengeEffect(nil, "pm", 11)))) .. "x") end
end,
	style = function(this)
	if (not JS.t(this:canComplete())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "lime",
			["background-color"] = "black",
			border = "2px solid lime",
			height = "330px",
			width = "330px",
			transition = " border 3s"
		}, {"border-radius", "color", "background-color", "border", "height", "width", "transition"}) end
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
			color = "lime",
			["background-color"] = "rgba(0,0,0,0)",
			border = "2px solid lime",
			transition = " all 1s"
		}, {"border-radius", "color", "background-color", "border", "transition"}) end
	end
	do return JS.O({
		["border-radius"] = "0%",
		color = "gold",
		["background-color"] = "rgba(0,0,0,0)",
		border = "2px solid gold"
	}, {"border-radius", "color", "background-color", "border"}) end
end
}, {"levelScale", "onEnter", "onExit", "name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "rewardEffect", "goalDescription", "currencyDisplayName", "rewardDescription", "style", "buttonStyle"}),
	[12] = JS.O({
	levelScaleTrojan = function(this)
	local scale = (JS.D(30)):add((JS.D(30)):mul(challengeCompletions(nil, "pm", 12)))
	do return scale:toNumber() end
end,
	levelScalePE = function(this)
	local scale = (JS.D(30)):add((JS.D(20)):mul(challengeCompletions(nil, "pm", 12)))
	do return scale:toNumber() end
end,
	onEnter = function(this)
	layerDataReset(nil, "pp")
	layerDataReset(nil, "p")
	layerDataReset(nil, "sp")
	layerDataReset(nil, "pe")
	layerDataReset(nil, "hp")
	layerDataReset(nil, "ap", JS.A(1, "challenges"))
	layerDataReset(nil, "pb")
	layerDataReset(nil, "hb")
	layerDataReset(nil, "se")
	layerDataReset(nil, "ep", JS.A(0))
	layerDataReset(nil, "em", JS.A(0))
	layerDataReset(nil, "mm", JS.A(0))
	layerDataReset(nil, "m", JS.A(0))
	layerDataReset(nil, "t", JS.A(1, "challenges"))
	JS.setk(player.m, "best", JS.D(129))
	JS.setk(player.mm, "best", JS.D(1))
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return ((JS.tonum(player.cp.grid[JS.k(x)].level) < 1) and (not JS.eq(x, 101))) end
	end)
	JS.set(player.cp.grid, JS.k(slots[0]), JS.O({
		level = this:levelScaleTrojan(),
		active = true,
		fixed = false,
		type = "div"
	}, {"level", "active", "fixed", "type"}))
	JS.set(player.cp.grid, JS.k(slots[1]), JS.O({
		level = this:levelScalePE(),
		active = true,
		fixed = false,
		type = "pm"
	}, {"level", "active", "fixed", "type"}))
end,
	onExit = function(this)
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return JS.eq(player.cp.grid[JS.k(x)].active, true) end
	end)
	JS.set(player.cp.grid, JS.k(slots[0]), JS.O({
		level = 0,
		active = false,
		fixed = false,
		type = "div"
	}, {"level", "active", "fixed", "type"}))
	JS.set(player.cp.grid, JS.k(slots[1]), JS.O({
		level = 0,
		active = false,
		fixed = false,
		type = "pm"
	}, {"level", "active", "fixed", "type"}))
	JS.setk(player.pm, "challengeTimer", JS.D(0))
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.m, "best", JS.D(185))
	JS.setk(player.m, "points", JS.D(185))
end,
	name = "Corrupted Normal Universe",
	completionLimit = JS.D(3),
	challengeDescription = function(this)
	do return (((((((((JS.str((if JS.eq(player.pm.activeChallenge, 12) then (("You spent " .. JS.str(formatTime(nil, player.pm.challengeTimer))) .. " in this challenge.") else "")) .. "<br>You are trapped in Level ") .. JS.str(format(nil, this:levelScaleTrojan()))) .. " Trojan") .. " and in Level ") .. JS.str(format(nil, this:levelScalePE()))) .. " Prestige Essence Corruptions, All upgrades that affect First Milestone are much weaker, you're trapped in Normal Universe.") .. "<br>") .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 0))) .. "/3 completions.<br>At 3 completions, unlock a new challenge!") end
end,
	unlocked = function(this)
	do return (JS.tonum(challengeCompletions(nil, "pm", 11)) >= 2) end
end,
	goal = function(this)
	local goal = (JS.D(10000000000000)):pow((JS.D((JS.tonum(challengeCompletions(nil, "pm", 12)) / 2.5))):add(1))
	do return goal end
end,
	canComplete = function(this)
	do return (player.p.points:gte(tmp.pm.challenges[JS.k(this.id)].goal) and JS.eq(player.pm.activeChallenge, 12)) end
end,
	rewardEffect = function(this)
	local ret = ((15.46 ^ JS.tonum(player.pm.challenges[12])) * JS.tonum((if (JS.tonum(challengeCompletions(nil, "pm", 12)) >= 1) then player.pm.essence:add(1):log2():add(1):log2():pow(1.5) else 1)))
	do return (JS.D((JS.tonum(ret) * JS.tonum((if (JS.tonum(challengeCompletions(nil, "pm", 13)) >= 1) then challengeEffect(nil, "pm", 13) else 1))))):max(1) end
end,
	goalDescription = function(this)
	local req = " Prestige Points"
	do return (("Get " .. JS.str(format(nil, this:goal()))) .. JS.str(req)) end
end,
	currencyDisplayName = "Points",
	rewardDescription = function(this)
	do return (("Multiply Points gain (Affected by Prestige Essences).<br>Currently: " .. JS.str(format(nil, challengeEffect(nil, "pm", 12)))) .. "x") end
end,
	style = function(this)
	if (not JS.t(this:canComplete())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "lime",
			["background-color"] = "black",
			border = "2px solid lime",
			height = "330px",
			width = "330px",
			transition = " border 3s"
		}, {"border-radius", "color", "background-color", "border", "height", "width", "transition"}) end
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
			color = "lime",
			["background-color"] = "rgba(0,0,0,0)",
			border = "2px solid lime",
			transition = " all 1s"
		}, {"border-radius", "color", "background-color", "border", "transition"}) end
	end
	do return JS.O({
		["border-radius"] = "0%",
		color = "gold",
		["background-color"] = "rgba(0,0,0,0)",
		border = "2px solid gold"
	}, {"border-radius", "color", "background-color", "border"}) end
end
}, {"levelScaleTrojan", "levelScalePE", "onEnter", "onExit", "name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "rewardEffect", "goalDescription", "currencyDisplayName", "rewardDescription", "style", "buttonStyle"}),
	[13] = JS.O({
	levelScaleTrojan = function(this)
	local scale = (JS.D(50)):add((JS.D(5)):mul(challengeCompletions(nil, "pm", 13)))
	do return scale end
end,
	onEnter = function(this)
	layerDataReset(nil, "pp")
	layerDataReset(nil, "p")
	layerDataReset(nil, "sp")
	layerDataReset(nil, "pe")
	layerDataReset(nil, "hp")
	layerDataReset(nil, "ap", JS.A(1, "challenges"))
	layerDataReset(nil, "pb")
	layerDataReset(nil, "hb")
	layerDataReset(nil, "se")
	layerDataReset(nil, "ep", JS.A(0))
	layerDataReset(nil, "em", JS.A(0))
	layerDataReset(nil, "mm", JS.A(0))
	layerDataReset(nil, "m", JS.A(0))
	layerDataReset(nil, "t", JS.A(1, "challenges"))
	JS.setk(player.m, "best", JS.D(0))
	JS.setk(player.mm, "best", JS.D(1))
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return ((JS.tonum(player.cp.grid[JS.k(x)].level) < 1) and (not JS.eq(x, 101))) end
	end)
	JS.set(player.cp.grid, JS.k(slots[0]), JS.O({
		level = this:levelScaleTrojan(),
		active = true,
		fixed = false,
		type = "div"
	}, {"level", "active", "fixed", "type"}))
end,
	onExit = function(this)
	local slots = JS.m(Object.keys(player.cp.grid), "filter", function(_, x)
		do return JS.eq(player.cp.grid[JS.k(x)].active, true) end
	end)
	JS.set(player.cp.grid, JS.k(slots[0]), JS.O({
		level = 0,
		active = false,
		fixed = false,
		type = "div"
	}, {"level", "active", "fixed", "type"}))
	JS.setk(player.pm, "challengeTimer", JS.D(0))
	JS.setk(player.pm, "essence", JS.D(0))
	JS.setk(player, "points", JS.D(0))
	JS.setk(player.m, "best", JS.D(185))
	JS.setk(player.m, "points", JS.D(185))
end,
	name = "Corrupted Normal Universe II",
	completionLimit = JS.D(3),
	challengeDescription = function(this)
	do return (((((((JS.str((if JS.eq(player.pm.activeChallenge, 13) then (("You spent " .. JS.str(formatTime(nil, player.pm.challengeTimer))) .. " in this challenge.") else "")) .. "<br>You are trapped in Level ") .. JS.str(format(nil, this:levelScaleTrojan()))) .. " Trojan") .. " Corruption, All upgrades that affect First Milestone are much weaker, you're trapped in Normal Universe.") .. "<br>") .. JS.str(format(nil, challengeCompletions(nil, this.layer, this.id), 0))) .. "/3 completions.") end
end,
	unlocked = function(this)
	do return (JS.tonum(challengeCompletions(nil, "pm", 12)) >= 3) end
end,
	goal = function(this)
	local goal = (JS.D(55)):div((JS.D(challengeCompletions(nil, "pm", 13))):div(4):add(1)):floor()
	if JS.eq(challengeCompletions(nil, "pm", 13), 2) then
		goal = JS.D(32)
	end
	do return goal end
end,
	canComplete = function(this)
	do return (player.pe.points:gte(tmp.pm.challenges[JS.k(this.id)].goal) and JS.eq(player.pm.activeChallenge, 13)) end
end,
	rewardEffect = function(this)
	local ret = ((15.46 ^ JS.tonum(player.pm.challenges[13])) * JS.tonum((if (JS.tonum(challengeCompletions(nil, "pm", 12)) >= 1) then player.pm.essence:add(1):log2():add(1):log2():pow(1.5) else 1)))
	do return ret end
end,
	goalDescription = function(this)
	local req = " Prestige Energy"
	do return (("Get " .. JS.str(format(nil, this:goal()))) .. JS.str(req)) end
end,
	currencyDisplayName = "Points",
	rewardDescription = function(this)
	do return (("Multiply CNU I reward (Affected by Prestige Essences).<br>Currently: " .. JS.str(format(nil, challengeEffect(nil, "pm", 13)))) .. "x") end
end,
	style = function(this)
	if (not JS.t(this:canComplete())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "lime",
			["background-color"] = "black",
			border = "2px solid lime",
			height = "330px",
			width = "330px",
			transition = " border 3s"
		}, {"border-radius", "color", "background-color", "border", "height", "width", "transition"}) end
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
			color = "lime",
			["background-color"] = "rgba(0,0,0,0)",
			border = "2px solid lime",
			transition = " all 1s"
		}, {"border-radius", "color", "background-color", "border", "transition"}) end
	end
	do return JS.O({
		["border-radius"] = "0%",
		color = "gold",
		["background-color"] = "rgba(0,0,0,0)",
		border = "2px solid gold"
	}, {"border-radius", "color", "background-color", "border"}) end
end
}, {"levelScaleTrojan", "onEnter", "onExit", "name", "completionLimit", "challengeDescription", "unlocked", "goal", "canComplete", "rewardEffect", "goalDescription", "currencyDisplayName", "rewardDescription", "style", "buttonStyle"})
}),
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(1, function(this)
	if (player.tab == "pm") then
		do return JS.A(2, "column", JS.A(8, "main-display", "prestige-button", "resource-display", JS.A(2, "display-text", (("1st milestone effect reduces your points gain by <h2 style='color:  #f71c50; text-shadow: #f71c50 0px 0px 10px;'> " .. JS.str(exponentialFormat(nil, tmp.pm.reduce, 2))) .. "x</h2>")), JS.A(2, "display-text", (((((("You have <h2 style='color: #f71c50; text-shadow: #f71c50 0px 0px 10px;'>" .. JS.str(format(nil, player.pm.essence))) .. "</h2> (+") .. JS.str(format(nil, tmp.pm.gain))) .. "/s) prestige essences, which multiply points gain by <h2 style='color:  #f71c50; text-shadow: #f71c50 0px 0px 10px;'>") .. JS.str(format(nil, tmp.pm.essenceBoost))) .. "x</h2>")), "blank", "milestones", "blank")) end
	end
end)
}),
	["Prestige Universe Challenges"] = JS.O({
	content = JS.A(8, "main-display", "prestige-button", "resource-display", JS.A(2, "display-text", function(this)
	do return (("You have " .. JS.str(format(nil, tmp.pm.count))) .. " Total Prestige Universe challenge completions.</h2>") end
end), JS.A(2, "display-text", function(this)
	do return (("Reach " .. JS.str(format(nil, tmp.pm.req))) .. " Prestige Universe challenge completions to unlock an effect.</h2>") end
end), "blank", JS.A(2, "display-text", function(this)
	table_ = "<div style=\"width:500px;border: 2px solid white;\"><h2 style=\"color:  #f71c50; text-shadow: #f71c50 0px 0px 10px;\">Current Unlocked Boosts</h2><br>"
	if tmp.pm.count:gte(3) then
		table_ = JS.add(table_, (if JS.eq(player.mp.modeP, true) then (("Points Mode:<br> Reduce Recharge Fusioner effect by <h3 style='color:#f71c50'>-" .. JS.str(format(nil, tmp.pm.pChalReward1))) .. "</h3>") else (("Prestige Essence Mode:<br> Increase Recharge Fusioner effect by <h3 style='color:#f71c50'>+" .. JS.str(format(nil, tmp.pm.pChalReward1))) .. "</h3>")))
	end
	if tmp.pm.count:gte(7) then
		table_ = JS.add(table_, (if JS.eq(player.mp.modeP, true) then (("<br>Corruption Essences effect are boosted by <h3 style='color:#f71c50'>" .. JS.str(format(nil, tmp.pm.pChalReward2))) .. "x</h3>") else (("<br> Boost Prestiged-Exotic Fusioner 1st Effect by <h3 style='color:#f71c50'>" .. JS.str(format(nil, tmp.pm.pChalReward2))) .. "x</h3>")))
	end
	if tmp.pm.count:gte(11) then
		table_ = JS.add(table_, (if JS.eq(player.mp.modeP, true) then (("<br>Second Pr-Exotic Fusioner effect is <h3 style='color:#f71c50'>/" .. JS.str(format(nil, tmp.pm.pChalReward3))) .. "</h3> weaker (boosted by Prestige Essences)") else (("<br>Second Pr-Exotic Fusioner effect is <h3 style='color:#f71c50'>" .. JS.str(format(nil, tmp.pm.pChalReward3))) .. "x</h3> better")))
	end
	do return (JS.str(table_) .. "</div><br>") end
end), JS.A(2, "challenges", JS.A(1, 1))),
	unlocked = function(this)
	do return player.pm.best:gte(12) end
end
}, {"content", "unlocked"})
}, {"Main", "Prestige Universe Challenges"}),
	count = function(this)
	local count = JS.D(0)
	for _, __k2 in JS.keys(player.pm.challenges) do
		i = __k2
		count = count:add(challengeCompletions(nil, "pm", i))
	end
	do return count end
end,
	req = function(this)
	local count = tmp.pm.count
	local req = JS.D(1)
	if count:gte(1) then
		req = req:mul(3)
	end
	if count:gte(3) then
		req = req:add(4)
	end
	if count:gte(7) then
		req = req:add(4)
	end
	if count:gte(11) then
		req = req:add(9)
	end
	do return req end
end,
	pMilestone4Effect = function(this)
	local p = player.points:add(1):log10():mul(1.75)
	do return p end
end,
	pMilestone11Effect = function(this)
	local p = player.pm.essence:add(1):log10():add(1):log(5):mul(1.5)
	do return p end
end,
	pMilestone13Effect = function(this)
	local p = player.pm.points:add(1):log2():add(1)
	do return p end
end,
	pMilestone14Effect = function(this)
	local p = player.pm.points:add(1):pow(5.5):pow(player.pm.points:pow(0.15):mul(player.pm.essence:max(1):log10():pow(0.15)))
	do return p end
end,
	pChalReward1 = function(this)
	local base = tmp.pm.count
	local p = (if JS.eq(player.mp.modeP, true) then base:div(2):pow(1.75) else base:div(1.25):pow(1.75))
	do return p end
end,
	pChalReward2 = function(this)
	local base = tmp.pm.count
	local p = (if JS.eq(player.mp.modeP, true) then base:pow(1.85):div(1.75) else base:pow(1.85):div(3))
	do return p end
end,
	pChalReward3 = function(this)
	local base = tmp.pm.count
	local p = (if JS.eq(player.mp.modeP, true) then base:pow(3.45):div(1.75):mul(player.pm.essence:add(1):pow(0.1):add(1):pow(0.25):mul(1.5)) else base:pow(3.85):div(3))
	do return p end
end,
	update = function(this, diff)
	if (player.pm.best:gte(1) and JS.eq(player.mp.activeChallenge, 21)) then
		JS.setk(player.pm, "essence", player.pm.essence:add(tmp.pm.gain:times(diff)))
	end
	if (not JS.isnil(player.pm.activeChallenge)) then
		JS.setk(player.pm, "challengeTimer", player.pm.challengeTimer:add(diff))
	end
end,
	branches = JS.A(1, "m"),
	resetDescription = "Get ",
	doReset = function(this)

end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "canReset", "gain", "reduce", "essenceBoost", "gainExp", "newRow", "row", "base", "exponent", "hotkeys", "layerShown", "resetsNothing", "milestones", "challenges", "tabFormat", "count", "req", "pMilestone4Effect", "pMilestone11Effect", "pMilestone13Effect", "pMilestone14Effect", "pChalReward1", "pChalReward2", "pChalReward3", "update", "branches", "resetDescription", "doReset"}))

end
