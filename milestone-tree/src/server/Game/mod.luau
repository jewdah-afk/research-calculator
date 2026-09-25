--!nocheck
-- transpiled from mod.js by port/build.js: do not edit
return function()
-- transpiled from mod.js
getStartPoints = function(this)
	do return JS.D(modInfo.initialStartPoints) end
end
canGenPoints = function(this)
	do return true end
end
getPointGen = function(this)
	local b, sc
	b = getPointGenBeforeSoftcap(nil)
	sc = getPointSoftcapStart(nil):log10()
	if b:gte(getPointSoftcapStart(nil)) then
		if (JS.eq(player.t.activeChallenge, 22) or JS.eq(player.t.activeChallenge, 32)) then
			do return getPointSoftcapStart(nil) end
		end
		local __g1 = 0
		while b:log10():gte(sc) do
			__g1 += 1; if __g1 > 5000000 then JS.runaway() end
			local potency = 0.4
			if hasUpgrade(nil, "t", 53) then
				potency = (JS.tonum(potency) * 0.9)
			end
			b = Decimal.pow(10, b:log10():div(sc):pow((1 - JS.tonum(potency))):mul(sc)):mul(corruptEffect(nil))
			sc = sc:mul(20)
		end
	end
	local prEsEffect = tmp.pm.essenceBoost:pow(10000000000000000000):pow((if hasUpgrade(nil, "ex", 11) then upgradeEffect(nil, "ex", 11) else 1))
	if hasMilestone(nil, "m", 185) then
		prEsEffect = prEsEffect:pow(milestoneEffect(nil, "m", 185))
	end
	if (player.pm.essence:gte(1) and (((JS.isnil(player.ap.activeChallenge) and JS.isnil(player.t.activeChallenge)) and JS.isnil(player.mp.activeChallenge)) and JS.isnil(player.pm.activeChallenge))) then
		b = b:mul(prEsEffect)
	end
	if hasMalware(nil, "m", 1) then
		b = b:mul(milestoneEffect(nil, "m", 1))
	end
	if hasUpgrade(nil, "p", 15) then
		b = b:mul(upgradeEffect(nil, "p", 15))
	end
	if JS.eq(player.sp.activeChallenge, 11) then
		b = b:max(1):slog(JS.D(1.15)):add(1)
		if hasUpgrade(nil, "p", 51) then
			b = b:mul(upgradeEffect(nil, "p", 51))
		end
		if hasUpgrade(nil, "p", 52) then
			b = b:pow(upgradeEffect(nil, "p", 52))
		end
		if hasMilestone(nil, "sp", 0) then
			b = b:mul(milestoneEffect(nil, "sp", 0))
		end
	end
	if (hasMilestone(nil, "cm", 1) and JS.eq(player.mp.activeChallenge, 21)) then
		b = b:mul(1000)
	end
	do return (if (not JS.eq(player.sp.activeChallenge, 11)) then b:mul(corruptEffect(nil)) else b) end
end
getPointGenBeforeSoftcap = function(this)
	local b
	b = JS.D(0)
	if JS.eq(player.mp.activeChallenge, 21) then
		b = (JS.D(1)):mul((if player.pep.buyables[11]:gte(2) then tmp.pep.prTwoEffect else 1)):div(tmp.pm.reduce)
	end
	if (not JS.eq(player.mp.activeChallenge, 21)) then
		if player.m.best:gte(1) then
			b = b:add(3)
		end
		if player.m.best:gte(2) then
			b = b:mul(3)
		end
		if player.m.best:gte(3) then
			b = b:mul(tmp.m.milestone3Effect)
		end
		if hasAchievement(nil, "ach", 12) then
			b = b:mul(achievementEffect(nil, "ach", 12))
		end
		if hasAchievement(nil, "ach", 11) then
			b = b:mul(tmp.ach.achBoost)
		end
		if hasUpgrade(nil, "p", 11) then
			b = b:mul(upgradeEffect(nil, "p", 11))
		end
		if hasUpgrade(nil, "p", 12) then
			b = b:mul(upgradeEffect(nil, "p", 12))
		end
		if hasUpgrade(nil, "sp", 11) then
			b = b:mul(upgradeEffect(nil, "sp", 11))
		end
		if hasUpgrade(nil, "sp", 12) then
			b = b:mul(upgradeEffect(nil, "sp", 12))
		end
		if hasUpgrade(nil, "hp", 11) then
			b = b:mul(upgradeEffect(nil, "hp", 11))
		end
		if hasUpgrade(nil, "hp", 12) then
			b = b:mul(upgradeEffect(nil, "hp", 12))
		end
		if hasUpgrade(nil, "ap", 11) then
			b = b:mul(upgradeEffect(nil, "ap", 11))
		end
	end
	if ((JS.eq(player.t.activeChallenge, 11) or JS.eq(player.t.activeChallenge, 21)) or JS.eq(player.t.activeChallenge, 31)) then
		b = b:pow(tmp.t.dilationEffect)
	end
	if ((JS.eq(player.ap.activeChallenge, 22) or JS.eq(player.ap.activeChallenge, 41)) or JS.eq(player.ap.activeChallenge, 42)) then
		b = b:add(1):log10():pow((if player.m.best:gte(122) then player.m.points else 100))
	end
	if (player.pm.essence:gte(1) and (not JS.eq(player.sp.activeChallenge, 11))) then
		b = b:mul(tmp.pm.essenceBoost)
	end
	if JS.eq(player.mp.modeP, true) then
		b = b:mul(buyableEffect(nil, "mp", 22).eff)
	end
	if (JS.tonum(challengeCompletions(nil, "pm", 12)) >= 1) then
		b = b:mul(challengeEffect(nil, "pm", 12))
	end
	if (player.m.best:gte(3) and (JS.eq(player.pm.activeChallenge, 12) or JS.eq(player.pm.activeChallenge, 13))) then
		b = b:mul(tmp.m.milestone3Effect)
	end
	local s = JS.D(1)
	local slots = activeCorruptions(nil)
	for i = 0, JS.cap(0, (JS.len(slots)) - 1, 1) do
		if (getGridData(nil, "cp", slots[JS.k(i)]).type == "div") then
			s = (if gridEffect(nil, "cp", slots[JS.k(i)]):gte(s) then gridEffect(nil, "cp", slots[JS.k(i)]) else s)
		else
			s = s
		end
	end
	b = b:div(s)
	do return b end
end
getPointGenString = function(this)
	do return (("(" .. JS.str(format(nil, getPointGen(nil)))) .. "/sec)") end
end
getPointSoftcapStart = function(this)
	local sc
	sc = JS.D("ee9")
	if player.m.best:gte(105) then
		sc = sc:pow(tmp.m.milestone105Effect)
	end
	if ((JS.eq(player.t.activeChallenge, 12) or JS.eq(player.t.activeChallenge, 22)) or JS.eq(player.t.activeChallenge, 32)) then
		sc = sc:pow(0.0001)
	end
	sc = sc:pow(tmp.t.challenges[12].rewardEffect)
	sc = sc:pow(tmp.t.challenges[22].rewardEffect)
	sc = sc:pow(tmp.t.challenges[32].rewardEffect)
	if hasUpgrade(nil, "ap", 32) then
		sc = sc:pow(upgradeEffect(nil, "ap", 32))
	end
	if hasUpgrade(nil, "hb", 11) then
		sc = sc:pow(upgradeEffect(nil, "hb", 11))
	end
	if hasUpgrade(nil, "pb", 31) then
		sc = sc:pow(upgradeEffect(nil, "pb", 31))
	end
	if hasUpgrade(nil, "t", 54) then
		sc = sc:pow(upgradeEffect(nil, "t", 54))
	end
	sc = sc:pow(tmp.p.buyables[11].effect)
	if hasUpgrade(nil, "pe", 11) then
		sc = sc:pow(upgradeEffect(nil, "pe", 11))
	end
	sc = sc:pow(tmp.sp.buyables[12].effect)
	sc = sc:pow(layers.t:getSpecialEffect(12))
	if hasUpgrade(nil, "t", 73) then
		sc = sc:pow(upgradeEffect(nil, "t", 73))
	end
	if hasUpgrade(nil, "se", 11) then
		sc = sc:pow(upgradeEffect(nil, "se", 11))
	end
	sc = sc:pow(layers.t:getSpecialEffect(22))
	if hasUpgrade(nil, "se", 22) then
		sc = sc:pow(upgradeEffect(nil, "se", 22))
	end
	if hasUpgrade(nil, "pp", 11) then
		sc = sc:pow(upgradeEffect(nil, "pp", 11))
	end
	do return sc end
end
getCostOverflowStart = function(this)
	local sc
	if JS.eq(player.ap.activeChallenge, 42) then
		do return JS.D(player.points:log(10):pow(0.585)) end
	end
	sc = JS.D(170)
	if player.m.best:gte(174) then
		sc = sc:add(2)
	end
	do return sc end
end
getCostOverflowScale = function(this)
	local sc
	sc = JS.D(172)
	if player.m.best:gte(176) then
		sc = sc:add(1)
	end
	if player.m.best:gte(177) then
		sc = sc:add(1)
	end
	do return sc end
end
getCostOverflowEff = function(this)
	local eff = (JS.D(1)):add(player.m.points:sub(getCostOverflowStart(nil)):add(1.5):div(10)):pow(1.075):sub((if hasUpgrade(nil, "mp", 12) then upgradeEffect(nil, "mp", 12) else 1))
	if player.m.points:gte(getCostOverflowScale(nil)) then
		eff = (JS.D(1)):add(player.m.points:sub(getCostOverflowStart(nil)):add(1.15):div(10)):pow((if player.m.points:gte(181) then (JS.D(1.5)):add(player.m.points:sub(181):div(10)) else 1.2)):sub((if hasUpgrade(nil, "mp", 12) then upgradeEffect(nil, "mp", 12) else 1))
	end
	if hasMalware(nil, "m", 16) then
		eff = eff:sub(milestoneEffect(nil, "m", 16))
	end
	do return eff:add(1) end
end
addedPlayerData = function(this)
	do return JS.O({}) end
end
isEndgame = function(this)
	do return player.points:gte(JS.D("e1e45")) end
end
maxTickLength = function(this)
	do return 3600 end
end
fixOldSave = function(this, oldVersion)
	for _, __k2 in JS.keys(player.cp.grid) do
		p = __k2
		JS.set(player.cp.grid, p, JS.O({
			level = getGridData(nil, "cp", p).level,
			active = false,
			fixed = false,
			type = getGridData(nil, "cp", p).type,
			cautPower = 0
		}, {"level", "active", "fixed", "type", "cautPower"}))
	end
end
modInfo = JS.O({
	name = "The Milestone Tree NG+",
	id = "c2nv4in9eusojg59bmo",
	author = "Seder3214",
	pointsName = "points",
	modFiles = JS.A(23, "/layers/m.js", "/layers/p.js", "/layers/sp.js", "/layers/hp.js", "/layers/pb.js", "/layers/hb.js", "/layers/ap.js", "/layers/t.js", "/layers/mm.js", "/layers/em.js", "/layers/pe.js", "/layers/se.js", "/layers/pp.js", "/layers/ep.js", "/layers/mp.js", "/layers/pm.js", "/layers/cp.js", "/layers/cm.js", "tree.js", "/layers/pep.js", "/layers/ex.js", "/layers/ach.js", "modal.js"),
	discordName = "",
	discordLink = "",
	initialStartPoints = JS.D(10),
	offlineLimit = 2400
}, {"name", "id", "author", "pointsName", "modFiles", "discordName", "discordLink", "initialStartPoints", "offlineLimit"})
VERSION = JS.O({
	num = "v2.044 - Explorations Revamp",
	name = "Exploring the Destroying Universe..."
}, {"num", "name"})
changelog = ("<h3>Changelog:</h3><br><br>\nNote: v<h3 style=\"color: green\">A</h3>.<h3 style='color: blue'>B</h3><h3 style='color: yellow'>C</h3>  <br>\n<h3 style='color: green'>A</h3> is a number of <h3 style='color:yellow'>major</h3> updates like <h3 class='pmr'>Prestige Milestone Tree</h3>, <br>\n<h3 style='color: blue'>B</h3> is a number of <h3 style=\"color:#793784\">milestones</h3> in current version, <br>\n<h3 style='color: yellow'>C</h3> is a letter that used to show <h3 style='color: cyan'>bugfix/rebalance</h3> updates<br><br>\n<h3 style='color:white'> v2.045.1 - Glow layer fixes</h3><br>\n<span style='color: #808080'>- Removed the glow on layers when the buyables (that are automated) can be bought<br></span>\n<span style='color: #808080'>- Added a glow on exploring layer that appear when you can get a feature on any zone<br></span>\n<span style='color: #808080'>- With an addition to the glow on exploring layer, in the description there will appear a text, saying on which zones you can get a new feature<br></span>\n<h3 class=\"exp\"> v2.044 - Explorations Revamp</h3><br>\n<span style='color: #808080'>- Full Rework of Explorations grid mechanic<br></span>\n<span style='color: #808080'>- More Minor Bugfixes<br></span>\n<span style='color: #808080'>- Made more advanced spark reignite mechanic<br></span>\n<h3 class=\"spark\"> v2.043</h3><br>\n<span style='color: #808080'>- Added 2 Spark Milestones<br></span>\n<span style='color: #808080'>- Normal Milestones go higher?<br></span>\n<span style='color: #808080'>- Added new rewardw for zone b-01 and a-02<br></span>\n<h3 class=\"spark\"> v2.039a</h3><br>\n<span style='color: #808080'>- Fixed burning system and its display<br></span>\n<h3 class=\"spark\"> v2.039 - Exploring Ashes</h3><br>\n<span style='color: #808080'>- Added one more exploration zone<br></span>\n<span style='color: #808080'>- Added Prestige Ashes<br></span>\n<span style='color: #808080'>- Balancing of post-corruption milestones content<br></span>\n<span style='color: #808080'>- Added a new type of milestones (only one for now)<br></span>\n<h3 class=\"corr\"> v2.035 beta I - v2.028d - DESTRUCTION OF MILESTONE TREE</h3><br>\n<i style='color: #808080'> Prestige Universe is slowly destroying itself...<br></i>\n<span style='color: #808080'> - Added a close menu button for Revamped Style Menu<br></span>\n<span style='color: #808080'> - Added limits for Multiverse Fusioners (not Prestige Essence ones)<br></span>\n<span style='color: #808080'> - Reduced all Malware Milestones costs <br></span>\n<span style='color: #808080'> - Added Malware Milestones <br></span>\n<span style='color: #808080'> - Fixed the typos <br></span>\n<span style='color: #808080'> - Nerfed some achievemnts rewards <br></span>\n<span style='color: #808080'> - Added Achievements<br></span>\n\n<span style='color: #808080'> - Fixed game freezing bug<br></span>\n<span style='color: #808080'> - Added 12 more milestones<br></span>\n<span style='color: #808080'> - 2 new challenges!<br></span>\n<span style='color: #808080'> - New milestones type<br></span>\n<span style='color: #808080'> - Rebalanced post-170th milestone content<br></span>\n<span style='color: #808080'> - Reduced Corruptions Level increase based on total fixed corruptions<br></span>\n<span style='color: #808080'> - Reduced Corruption Upgrade 12 cost (350 => 150)<br></span>\n<span style='color: #808080'> - Fixed the whole tree being moved right on default theme<br></span>\n<span style='color: #808080'> - Change the whole game overlay<br></span>\n<span style='color: #808080'> - You can change to default style in options<br></span>\n<span style='color: #808080'> - Added a new mechanic!<br></span>\n<span style='color: #808080'> - A whole new layer is playable now. Corruptions are fully working now!<br></span>\n<span style='color: #808080'> - Most of corruption's style and functional part are finished!<br></span>\n<h3 class='pmr'>v2.005a - Prestige Fusioners</h3><br>\n<span style='color: #808080'> - 2 more Multiverse Fusioners!<br></span>\n<h3 class='pmr'>v2.002 - Prestige Milestones</h3><br>\n<span style='color: #808080'> - Prestige Milestone Tree is here!<br></span>\n<br><h3 class='mr'>v1.185 - Multiverse Fusioners</h3><br>\n<span style='color: #808080'> - Added four new fusioners! <i>Almost the end, huh?</i><br>\n- Added two more challenges</span><br><br>\n<span style='color: gold;'>There was many many updates before...</span><br>\n<span style='color: #808080'> ...........<br></span>")
winText = ("Congratulations! You have reached the end and beaten this game, but for now...")
doNotCallTheseFunctionsEveryTick = JS.A(1, "blowUpEverything")
displayThings = JS.A(2, "Mod Author: Seder3214 / qq1010903229 (loader3229)", function(this)
	local table_ = ""
	if getPointGen(nil):gte(getPointSoftcapStart(nil):sqrt()) then
		table_ = (JS.str(table_) .. ((("1st milestone's effect ^" .. JS.str(format(nil, getPointGen(nil):log(getPointGenBeforeSoftcap(nil)), 4))) .. " because of softcap.<br>1st milestone's softcap starts at ") .. JS.str(format(nil, getPointSoftcapStart(nil)))))
	end
	if player.m.points:gte(getCostOverflowStart(nil)) then
		table_ = (JS.str(table_) .. (((((("<br>Milestone cost exponent is x" .. JS.str(format(nil, getCostOverflowEff(nil), 4))) .. " because of overflow.<br> Starts at ") .. JS.str(format(nil, getCostOverflowStart(nil)))) .. " milestones, scales at ") .. JS.str(format(nil, getCostOverflowScale(nil)))) .. " milestones"))
	end
	do return table_ end
end)
backgroundStyle = JS.O({})

end
