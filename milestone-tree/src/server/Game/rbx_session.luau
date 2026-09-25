--!nocheck
-- transpiled from rbx/session.js by port/build.js: do not edit
return function()
-- transpiled from rbx/session.js
rbx_boot = function(this, saveStr, optionsStr)
	if JS.t(saveStr) then
		player = Object.assign(getStartPlayer(nil), JSON.parse(saveStr))
		fixSave(nil)
	else
		player = getStartPlayer(nil)
	end
	options = getStartOptions(nil)
	if JS.t(optionsStr) then
		options = Object.assign(getStartOptions(nil), JSON.parse(optionsStr))
		fixData(nil, options, getStartOptions(nil))
	end
	JS.setk(options, "forceOneTab", true)
	if JS.t(options.offlineProd) then
		if (player.offTime == nil) then
			JS.setk(player, "offTime", JS.O({
				remain = 0
			}))
		end
		JS.setk(player.offTime, "remain", JS.add(player.offTime.remain, ((JS.tonum(Date.now()) - JS.tonum(player.time)) / 1000)))
	end
	JS.setk(player, "time", Date.now())
	versionCheck(nil)
	updateLayers(nil)
	setupModInfo(nil)
	setupTemp(nil)
	updateTemp(nil)
	updateTemp(nil)
	updateTabFormats(nil)
end
rbx_updateWidth = function(this)
	JS.setk(tmp.other, "screenWidth", 1280)
	JS.setk(tmp.other, "screenHeight", 720)
	JS.setk(tmp.other, "splitScreen", false)
	JS.setk(tmp.other, "lastPoints", player.points)
end
rbx_tick = function(this)
	local now, diff, trueDiff, offlineDiff
	if (JS.t(tmp.gameEnded) and (not JS.t(player.keepGoing))) then
		do return end
	end
	now = Date.now()
	diff = ((JS.tonum(now) - JS.tonum(player.time)) / 1000)
	trueDiff = diff
	if (not (player.offTime == nil)) then
		if (JS.tonum(player.offTime.remain) > (JS.tonum(modInfo.offlineLimit) * 3600)) then
			JS.setk(player.offTime, "remain", (JS.tonum(modInfo.offlineLimit) * 3600))
		end
		if (JS.tonum(player.offTime.remain) > 0) then
			offlineDiff = Math.max((JS.tonum(player.offTime.remain) / 10), diff)
			JS.setk(player.offTime, "remain", (JS.tonum(player.offTime.remain) - JS.tonum(offlineDiff)))
			diff = JS.add(diff, offlineDiff)
		end
		if ((not JS.t(options.offlineProd)) or (JS.tonum(player.offTime.remain) <= 0)) then
			JS.setk(player, "offTime", nil)
		end
	end
	if JS.t(player.devSpeed) then
		diff = (JS.tonum(diff) * JS.tonum(player.devSpeed))
	end
	JS.setk(player, "time", now)
	updateTemp(nil)
	updateOomps(nil, diff)
	rbx_updateWidth(nil)
	gameLoop(nil, diff)
	fixNaNs(nil)
	adjustPopupTime(nil, trueDiff)
end
rbx_do = function(this, a)
	local k, l, id, c, hk
	k = a[0]
	l = a[1]
	id = a[2]
	if (k == "opt") then
		do return rbx_option(nil, l) end
	end
	if (JS.t(tmp.gameEnded) and (not JS.t(player.keepGoing))) then
		do return end
	end
	if (k == "upg") then
		buyUpg(nil, l, id)
	elseif (k == "buy") then
		buyBuyable(nil, l, id)
	elseif (k == "click") then
		clickClickable(nil, l, id)
	elseif (k == "hold") then
		c = layers[JS.k(l)].clickables[JS.k(id)]
		if (JS.t(c.onHold) and JS.t(run(nil, c.canClick, c))) then
			run(nil, c.onHold, c)
		end
	elseif (k == "chal") then
		startChallenge(nil, l, id)
	elseif (k == "reset") then
		doReset(nil, l)
	elseif (k == "tab") then
		showTab(nil, l)
	elseif (k == "subtab") then
		JS.set(player.subtabs[JS.k(l)], JS.k(id), a[3])
		updateTabFormats(nil)
	elseif (k == "toggle") then
		toggleAuto(nil, JS.A(2, l, id))
	elseif (k == "perk") then
		unlockUpg(nil, l, id)
	elseif (k == "malware") then
		unlockBuy(nil, l, id)
	elseif (k == "respec") then
		respecBuyables(nil, l)
	elseif (k == "master") then
		run(nil, tmp[JS.k(l)].clickables.masterButtonPress, tmp[JS.k(l)].clickables)
	elseif (k == "sellOne") then
		run(nil, tmp[JS.k(l)].buyables[JS.k(id)].sellOne, tmp[JS.k(l)].buyables[JS.k(id)])
	elseif (k == "sellAll") then
		run(nil, tmp[JS.k(l)].buyables[JS.k(id)].sellAll, tmp[JS.k(l)].buyables[JS.k(id)])
	elseif (k == "grid") then
		clickGrid(nil, l, id)
	elseif (k == "gridHold") then
		if (JS.t(layers[JS.k(l)].grid.onHold) and JS.t(gridRun(nil, l, "getCanClick", player[JS.k(l)].grid[JS.k(id)], id))) then
			gridRun(nil, l, "onHold", player[JS.k(l)].grid[JS.k(id)], id)
		end
	elseif (k == "infobox") then
		JS.set(player.infoboxes[JS.k(l)], JS.k(id), (not JS.t(player.infoboxes[JS.k(l)][JS.k(id)])))
	elseif (k == "key") then
		hk = hotkeys[JS.k(l)]
		if ((JS.t(hk) and JS.t(player[JS.k(hk.layer)].unlocked)) and JS.t(tmp[JS.k(hk.layer)].hotkeys[JS.k(hk.id)].unlocked)) then
			hk:onPress()
		end
	end
end
rbx_option = function(this, name)
	if (((name == "offlineProd") or (name == "hideChallenges")) or (name == "reverseMilestones")) then
		toggleOpt(nil, name)
	elseif (name == "msDisplay") then
		adjustMSDisp(nil)
	elseif (name == "cctp") then
		adjustCCTP(nil)
	elseif (name == "keepGoing") then
		keepGoing(nil)
	end
end
rbx_saveData = function(this)
	NaNcheck(nil, player)
	if JS.t(NaNalert) then
		do return JS.NULL end
	end
	do return JS.A(2, JSON.stringify(player), JSON.stringify(options)) end
end
rbx_popups = function(this, since)
	local out, i, p
	out = JS.A(0)
	for i = 0, JS.cap(0, (JS.len(activePopups)) - 1, 1) do
		p = activePopups[JS.k(i)]
		if JS.cmp(p.id, ">=", since) then
			JS.m(out, "push", JS.O({
				id = p.id,
				title = ("" .. JS.str(p.title)),
				message = ("" .. JS.str(p.message)),
				type = ("" .. JS.str(p.type)),
				color = (if JS.t(p.color) then ("" .. JS.str(p.color)) else ""),
				bColor = (if JS.t(p.bColor) then ("" .. JS.str(p.bColor)) else "")
			}, {"id", "title", "message", "type", "color", "bColor"}))
		end
	end
	do return out end
end
updateMilestones = function(this, layer)
	if JS.t(tmp[JS.k(layer)].deactivated) then
		do return end
	end
	for _, __k1 in JS.keys(layers[JS.k(layer)].milestones) do
		id = __k1
		if ((not hasMilestone(nil, layer, id)) and JS.t(layers[JS.k(layer)].milestones[id]:done())) then
			JS.m(player[JS.k(layer)].milestones, "push", id)
			if JS.t(layers[JS.k(layer)].milestones[id].onComplete) then
				layers[JS.k(layer)].milestones[id]:onComplete()
			end
			if (JS.t(tmp[JS.k(layer)].milestonePopups) or (tmp[JS.k(layer)].milestonePopups == nil)) then
				doPopup(nil, "milestone", rbx_v(nil, tmp[JS.k(layer)].milestones[id], layers[JS.k(layer)].milestones[id], "requirementDescription"), "Milestone Gotten!", 3, tmp[JS.k(layer)].color)
			end
			JS.setk(player[JS.k(layer)], "lastMilestone", id)
		end
	end
end
rbx_displayOnly = JS.A(18, "style", "tooltip", "tooltipStyle", "title", "description", "challengeDescription", "rewardDescription", "requirementDescription", "goalDescription", "costDescription", "buttonStyle", "nodeStyle", "respecMessage", "prestigeButtonText", "currencyDisplayName", "markNodes", "pseudoReq", "perkReq")
for rbx_i = 0, JS.cap(0, (JS.len(rbx_displayOnly)) - 1, 1) do
	JS.m(activeFunctions, "push", rbx_displayOnly[JS.k(rbx_i)])
end

end
