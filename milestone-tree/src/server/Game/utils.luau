--!nocheck
-- transpiled from utils.js by port/build.js: do not edit
return function()
-- transpiled from utils.js
respecBuyables = function(this, layer)
	if (not JS.t(layers[JS.k(layer)].buyables)) then
		do return end
	end
	if (not JS.t(layers[JS.k(layer)].buyables.respec)) then
		do return end
	end
	if ((not JS.t(player[JS.k(layer)].noRespecConfirm)) and (not JS.t(confirm(nil, (if JS.t(tmp[JS.k(layer)].buyables.respecMessage) then tmp[JS.k(layer)].buyables.respecMessage else (("Are you sure you want to respec? This will force you to do a \"" .. JS.str((if JS.t(tmp[JS.k(layer)].name) then tmp[JS.k(layer)].name else layer))) .. "\" reset as well!")))))) then
		do return end
	end
	run(nil, layers[JS.k(layer)].buyables.respec, layers[JS.k(layer)].buyables)
	updateBuyableTemp(nil, layer)
	document.activeElement:blur()
end
canAffordUpgrade = function(this, layer, id)
	local upg = tmp[JS.k(layer)].upgrades[JS.k(id)]
	if JS.t(tmp[JS.k(layer)].deactivated) then
		do return false end
	end
	if (tmp[JS.k(layer)].upgrades[JS.k(id)].canAfford == false) then
		do return false end
	end
	local cost = tmp[JS.k(layer)].upgrades[JS.k(id)].cost
	if (not (cost == nil)) then
		do return canAffordPurchase(nil, layer, upg, cost) end
	end
	do return true end
end
canBuyBuyable = function(this, layer, id)
	local b = temp[JS.k(layer)].buyables[JS.k(id)]
	do return JS.and_(JS.and_((if JS.t(b.unlocked) then run(nil, b.canAfford, b) else b.unlocked), function() return player[JS.k(layer)].buyables[JS.k(id)]:lt(b.purchaseLimit) end), function() return (not JS.t(tmp[JS.k(layer)].deactivated)) end) end
end
canAffordPurchase = function(this, layer, thing, cost)
	if JS.t(thing.currencyInternalName) then
		local name = thing.currencyInternalName
		if JS.t(thing.currencyLocation) then
			do return (not thing.currencyLocation[JS.k(name)]:lt(cost)) end
		elseif JS.t(thing.currencyLayer) then
			local lr = thing.currencyLayer
			do return (not player[JS.k(lr)][JS.k(name)]:lt(cost)) end
		else
			do return (not player[JS.k(name)]:lt(cost)) end
		end
	else
		do return (not player[JS.k(layer)].points:lt(cost)) end
	end
end
buyUpgrade = function(this, layer, id)
	buyUpg(nil, layer, id)
end
buyUpg = function(this, layer, id)
	if ((not JS.t(tmp[JS.k(layer)].upgrades)) or (not JS.t(tmp[JS.k(layer)].upgrades[JS.k(id)]))) then
		do return end
	end
	local upg = tmp[JS.k(layer)].upgrades[JS.k(id)]
	if ((not JS.t(player[JS.k(layer)].unlocked)) or JS.t(player[JS.k(layer)].deactivated)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].upgrades[JS.k(id)].unlocked)) then
		do return end
	end
	if JS.m(player[JS.k(layer)].upgrades, "includes", id) then
		do return end
	end
	if (upg.canAfford == false) then
		do return end
	end
	local pay = layers[JS.k(layer)].upgrades[JS.k(id)].pay
	if (not (pay == nil)) then
		run(nil, pay, layers[JS.k(layer)].upgrades[JS.k(id)])
	else
		local cost = tmp[JS.k(layer)].upgrades[JS.k(id)].cost
		if JS.t(upg.currencyInternalName) then
			local name = upg.currencyInternalName
			if JS.t(upg.currencyLocation) then
				if upg.currencyLocation[JS.k(name)]:lt(cost) then
					do return end
				end
				JS.set(upg.currencyLocation, JS.k(name), upg.currencyLocation[JS.k(name)]:sub(cost))
			elseif JS.t(upg.currencyLayer) then
				local lr = upg.currencyLayer
				if player[JS.k(lr)][JS.k(name)]:lt(cost) then
					do return end
				end
				JS.set(player[JS.k(lr)], JS.k(name), player[JS.k(lr)][JS.k(name)]:sub(cost))
			else
				if player[JS.k(name)]:lt(cost) then
					do return end
				end
				JS.set(player, JS.k(name), player[JS.k(name)]:sub(cost))
			end
		else
			if player[JS.k(layer)].points:lt(cost) then
				do return end
			end
			JS.setk(player[JS.k(layer)], "points", player[JS.k(layer)].points:sub(cost))
		end
	end
	JS.m(player[JS.k(layer)].upgrades, "push", id)
	if (not JS.isnil(upg.onPurchase)) then
		run(nil, upg.onPurchase, upg)
	end
	needCanvasUpdate = true
end
buyMaxBuyable = function(this, layer, id)
	if (not JS.t(player[JS.k(layer)].unlocked)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].buyables[JS.k(id)].unlocked)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].buyables[JS.k(id)].canBuy)) then
		do return end
	end
	if (not JS.t(layers[JS.k(layer)].buyables[JS.k(id)].buyMax)) then
		do return end
	end
	run(nil, layers[JS.k(layer)].buyables[JS.k(id)].buyMax, layers[JS.k(layer)].buyables[JS.k(id)])
	updateBuyableTemp(nil, layer)
end
buyBuyable = function(this, layer, id)
	if (not JS.t(player[JS.k(layer)].unlocked)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].buyables[JS.k(id)].unlocked)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].buyables[JS.k(id)].canBuy)) then
		do return end
	end
	run(nil, layers[JS.k(layer)].buyables[JS.k(id)].buy, layers[JS.k(layer)].buyables[JS.k(id)])
	updateBuyableTemp(nil, layer)
end
clickClickable = function(this, layer, id)
	if ((not JS.t(player[JS.k(layer)].unlocked)) or JS.t(tmp[JS.k(layer)].deactivated)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].clickables[JS.k(id)].unlocked)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].clickables[JS.k(id)].canClick)) then
		do return end
	end
	run(nil, layers[JS.k(layer)].clickables[JS.k(id)].onClick, layers[JS.k(layer)].clickables[JS.k(id)])
	updateClickableTemp(nil, layer)
end
clickGrid = function(this, layer, id)
	if ((not JS.t(player[JS.k(layer)].unlocked)) or JS.t(tmp[JS.k(layer)].deactivated)) then
		do return end
	end
	if (not JS.t(run(nil, layers[JS.k(layer)].grid.getUnlocked, layers[JS.k(layer)].grid, id))) then
		do return end
	end
	if (not JS.t(gridRun(nil, layer, "getCanClick", player[JS.k(layer)].grid[JS.k(id)], id))) then
		do return end
	end
	gridRun(nil, layer, "onClick", player[JS.k(layer)].grid[JS.k(id)], id)
end
inChallenge = function(this, layer, id)
	local challenge = player[JS.k(layer)].activeChallenge
	if (not JS.t(challenge)) then
		do return false end
	end
	id = toNumber(nil, id)
	if JS.eq(challenge, id) then
		do return true end
	end
	if JS.t(layers[JS.k(layer)].challenges[JS.k(challenge)].countsAs) then
		do return (JS.m(tmp[JS.k(layer)].challenges[JS.k(challenge)].countsAs, "includes", id) or false) end
	end
	do return false end
end
showTab = function(this, name, prev)
	local toTreeTab
	if (not JS.eq(player.tab, name)) then
		clearParticles(nil, function(this, p)
			do return JS.eq(p.layer, player.tab) end
		end)
	end
	if ((JS.t(tmp[JS.k(name)]) and JS.eq(player.tab, name)) and isPlainObject(nil, tmp[JS.k(name)].tabFormat)) then
		JS.setk(player.subtabs[JS.k(name)], "mainTabs", Object.keys(layers[JS.k(name)].tabFormat)[0])
	end
	toTreeTab = (name == "none")
	JS.setk(player, "tab", name)
	if ((JS.t(tmp[JS.k(name)]) and (not (tmp[JS.k(name)].row == "side"))) and (not (tmp[JS.k(name)].row == "otherside"))) then
		JS.setk(player, "lastSafeTab", name)
	end
	updateTabFormats(nil)
	needCanvasUpdate = true
	document.activeElement:blur()
end
showNavTab = function(this, name, prev)
	local toTreeTab
	console.log(prev)
	if (JS.m(LAYERS, "includes", name) and (not layerunlocked(nil, name))) then
		do return end
	end
	if (not JS.eq(player.navTab, name)) then
		clearParticles(nil, function(this, p)
			do return JS.eq(p.layer, player.navTab) end
		end)
	end
	if (JS.t(tmp[JS.k(name)]) and (not (tmp[JS.k(name)].previousTab == nil))) then
		prev = tmp[JS.k(name)].previousTab
	end
	toTreeTab = (name == "tree-tab")
	console.log(JS.add(name, prev))
	if (((not (name == "none")) and JS.t(prev)) and JS.eq((not JS.t((function() local __c1 = (tmp)[JS.k(prev)]; if JS.isnil(__c1) then return nil end; return (__c1).leftTab end)())), (not JS.t((function() local __c2 = (tmp)[JS.k(name)]; if JS.isnil(__c2) then return nil end; return (__c2).leftTab end)())))) then
		JS.setk(player[JS.k(name)], "prevTab", prev)
	elseif JS.t(player[JS.k(name)]) then
		JS.setk(player[JS.k(name)], "prevTab", "")
	end
	JS.setk(player, "navTab", name)
	updateTabFormats(nil)
	needCanvasUpdate = true
end
goBack = function(this, layer)
	local nextTab = "none"
	if JS.t(player[JS.k(layer)].prevTab) then
		nextTab = player[JS.k(layer)].prevTab
	end
	if ((player.navTab == "none") and (((function() local __c3 = (tmp)[JS.k(layer)]; if JS.isnil(__c3) then return nil end; return (__c3).row end)() == "side") or (tmp[JS.k(layer)].row == "otherside"))) then
		nextTab = player.lastSafeTab
	end
	if JS.t(tmp[JS.k(layer)].leftTab) then
		showNavTab(nil, nextTab, layer)
	else
		showTab(nil, nextTab, layer)
	end
end
layOver = function(this, obj1, obj2)
	for _, __k4 in JS.keys(obj2) do
		local x = __k4
		if JS.instanceof(obj2[x], Decimal) then
			JS.set(obj1, x, JS.D(obj2[x]))
		elseif JS.instanceof(obj2[x], Object) then
			layOver(nil, obj1[x], obj2[x])
		else
			JS.set(obj1, x, obj2[x])
		end
	end
end
prestigeNotify = function(this, layer)
	if JS.t(layers[JS.k(layer)].prestigeNotify) then
		do return layers[JS.k(layer)]:prestigeNotify() end
	end
	if isPlainObject(nil, tmp[JS.k(layer)].tabFormat) then
		for _, __k5 in JS.keys(tmp[JS.k(layer)].tabFormat) do
			subtab = __k5
			if JS.t(subtabResetNotify(nil, layer, "mainTabs", subtab)) then
				do return true end
			end
		end
	end
	for _, __k6 in JS.keys(tmp[JS.k(layer)].microtabs) do
		family = __k6
		for _, __k7 in JS.keys(tmp[JS.k(layer)].microtabs[family]) do
			subtab = __k7
			if JS.t(subtabResetNotify(nil, layer, family, subtab)) then
				do return true end
			end
		end
	end
	if (JS.t(tmp[JS.k(layer)].autoPrestige) or JS.t(tmp[JS.k(layer)].passiveGeneration)) then
		do return false end
	elseif (tmp[JS.k(layer)].type == "static") then
		do return tmp[JS.k(layer)].canReset end
	elseif (tmp[JS.k(layer)].type == "normal") then
		do return (if JS.t(tmp[JS.k(layer)].canReset) then tmp[JS.k(layer)].resetGain:gte(player[JS.k(layer)].points:div(10)) else tmp[JS.k(layer)].canReset) end
	else
		do return false end
	end
end
notifyLayer = function(this, name)
	if (JS.eq(player.tab, name) or (not layerunlocked(nil, name))) then
		do return end
	end
	JS.set(player.notify, JS.k(name), 1)
end
subtabShouldNotify = function(this, layer, family, id)
	local subtab = JS.O({})
	if (family == "mainTabs") then
		subtab = tmp[JS.k(layer)].tabFormat[JS.k(id)]
	else
		subtab = tmp[JS.k(layer)].microtabs[JS.k(family)][JS.k(id)]
	end
	if (not JS.t(subtab.unlocked)) then
		do return false end
	end
	if JS.t(subtab.embedLayer) then
		do return tmp[JS.k(subtab.embedLayer)].notify end
	else
		do return subtab.shouldNotify end
	end
end
subtabResetNotify = function(this, layer, family, id)
	local subtab = JS.O({})
	if (family == "mainTabs") then
		subtab = tmp[JS.k(layer)].tabFormat[JS.k(id)]
	else
		subtab = tmp[JS.k(layer)].microtabs[JS.k(family)][JS.k(id)]
	end
	if JS.t(subtab.embedLayer) then
		do return tmp[JS.k(subtab.embedLayer)].prestigeNotify end
	else
		do return subtab.prestigeNotify end
	end
end
nodeShown = function(this, layer)
	do return layerShown(nil, layer) end
end
layerunlocked = function(this, layer)
	if (JS.t(tmp[JS.k(layer)]) and (tmp[JS.k(layer)].type == "none")) then
		do return player[JS.k(layer)].unlocked end
	end
	do return JS.and_(JS.m(LAYERS, "includes", layer), function() return (if JS.t(player[JS.k(layer)].unlocked) then player[JS.k(layer)].unlocked else (if JS.t(tmp[JS.k(layer)].canReset) then tmp[JS.k(layer)].layerShown else tmp[JS.k(layer)].canReset)) end) end
end
keepGoing = function(this)
	JS.setk(player, "keepGoing", true)
	needCanvasUpdate = true
end
toNumber = function(this, x)
	if (not (JS.P(x, "mag") == nil)) then
		do return x:toNumber() end
	end
	if (not JS.eq(JS.add(x, 0), x)) then
		do return parseFloat(nil, x) end
	end
	do return x end
end
updateMilestones = function(this, layer)
	if JS.t(tmp[JS.k(layer)].deactivated) then
		do return end
	end
	for _, __k8 in JS.keys(layers[JS.k(layer)].milestones) do
		id = __k8
		if ((not hasMilestone(nil, layer, id)) and JS.t(layers[JS.k(layer)].milestones[id]:done())) then
			JS.m(player[JS.k(layer)].milestones, "push", id)
			if JS.t(layers[JS.k(layer)].milestones[id].onComplete) then
				layers[JS.k(layer)].milestones[id]:onComplete()
			end
			if (JS.t(tmp[JS.k(layer)].milestonePopups) or (tmp[JS.k(layer)].milestonePopups == nil)) then
				doPopup(nil, "milestone", tmp[JS.k(layer)].milestones[id].requirementDescription, "Milestone Gotten!", 3, tmp[JS.k(layer)].color)
			end
			JS.setk(player[JS.k(layer)], "lastMilestone", id)
		end
	end
end
updateAchievements = function(this, layer)
	if JS.t(tmp[JS.k(layer)].deactivated) then
		do return end
	end
	for _, __k9 in JS.keys(layers[JS.k(layer)].achievements) do
		id = __k9
		if ((isPlainObject(nil, layers[JS.k(layer)].achievements[id]) and (not hasAchievement(nil, layer, id))) and JS.t(layers[JS.k(layer)].achievements[id]:done())) then
			JS.m(player[JS.k(layer)].achievements, "push", id)
			if JS.t(layers[JS.k(layer)].achievements[id].onComplete) then
				layers[JS.k(layer)].achievements[id]:onComplete()
			end
			if (JS.t(tmp[JS.k(layer)].achievementPopups) or (tmp[JS.k(layer)].achievementPopups == nil)) then
				doPopup(nil, "achievement", tmp[JS.k(layer)].achievements[id].name, "Achievement Gotten!", 3, tmp[JS.k(layer)].color)
			end
		end
	end
end
addTime = function(this, diff, layer)
	local data = player
	local time = data.timePlayed
	if JS.t(layer) then
		data = data[JS.k(layer)]
		time = data.time
	end
	if (not JS.eq(JS.add(time, 0), time)) then
		console.log("Memory leak detected. Trying to fix...")
		time = toNumber(nil, time)
		if (isNaN(nil, time) or JS.eq(time, 0)) then
			console.log("Couldn't fix! Resetting...")
			time = (if JS.t(layer) then player.timePlayed else 0)
			if (not JS.t(layer)) then
				JS.setk(player, "timePlayedReset", true)
			end
		end
	end
	time = JS.add(time, toNumber(nil, diff))
	if JS.t(layer) then
		JS.setk(data, "time", time)
	else
		JS.setk(data, "timePlayed", time)
	end
end
focused = function(this, x)
	onFocused = x
end
isFunction = function(this, obj)
	do return (not (not (((JS.t(obj) and JS.t(JS.get(obj, "constructor"))) and JS.t(JS.get(obj, "call"))) and JS.t(JS.get(obj, "apply"))))) end
end
isPlainObject = function(this, obj)
	do return ((not (not JS.t(obj))) and JS.eq(JS.get(obj, "constructor"), Object)) end
end
toValue = function(this, value, oldValue)
	if JS.instanceof(oldValue, Decimal) then
		value = JS.D(value)
		if JS.t(checkDecimalNaN(nil, value)) then
			do return decimalZero end
		end
		do return value end
	end
	if (not isNaN(nil, oldValue)) then
		do return JS.or_(parseFloat(nil, value), function() return 0 end) end
	end
	do return value end
end
doPopup = function(this, type_, text, title, timer, color, bColor)
	if type_ == nil then type_ = "none" end
	if text == nil then text = "This is a test popup." end
	if title == nil then title = "" end
	if timer == nil then timer = 3 end
	if color == nil then color = "" end
	if bColor == nil then bColor = "" end
	do
		local __sw10 = type_
		local __ft11 = false
		repeat
			if __ft11 or JS.eq(__sw10, "achievement") then
				__ft11 = true
				popupTitle = "Achievement Unlocked!"
				popupType = "achievement-popup"
				break
			end
			if __ft11 or JS.eq(__sw10, "challenge") then
				__ft11 = true
				popupTitle = "Challenge Complete"
				popupType = "challenge-popup"
				break
			end
			if true then
				__ft11 = true
				popupTitle = "Something Happened?"
				popupType = "default-popup"
				break
			end
		until true
	end
	if (not JS.eq(title, "")) then
		popupTitle = title
	end
	popupMessage = text
	popupTimer = timer
	JS.m(activePopups, "push", JS.O({
		time = popupTimer,
		type = popupType,
		title = popupTitle,
		message = (JS.str(popupMessage) .. "\n"),
		id = popupID,
		color = color,
		bColor = bColor
	}, {"time", "type", "title", "message", "id", "color", "bColor"}))
	popupID = (JS.tonum(popupID) + 1)
end
adjustPopupTime = function(this, diff)
	for _, __k12 in JS.keys(activePopups) do
		popup = __k12
		JS.setk(activePopups[popup], "time", (JS.tonum(activePopups[popup].time) - JS.tonum(diff)))
		if (JS.tonum(activePopups[popup]["time"]) < 0) then
			JS.m(activePopups, "splice", popup, 1)
		end
	end
end
run = function(this, func, target, args)
	if args == nil then args = JS.NULL end
	if isFunction(nil, func) then
		local bound = JS.m(func, "bind", target)
		do return bound(nil, args) end
	else
		do return func end
	end
end
gridRun = function(this, layer, func, data, id)
	if isFunction(nil, layers[JS.k(layer)].grid[JS.k(func)]) then
		local bound = JS.m(layers[JS.k(layer)].grid[JS.k(func)], "bind", layers[JS.k(layer)].grid)
		do return bound(nil, data, id) end
	else
		do return layers[JS.k(layer)].grid[JS.k(func)] end
	end
end
unlockBuy = function(this, layer, id)
	console.log((JS.str(id)))
	if (not JS.t(player[JS.k(layer)].unlocked)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].milestones[JS.k(id)].pseudoUnl)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].milestones[JS.k(id)].unlocked)) then
		do return end
	end
	if JS.m(player[JS.k(layer)].pseudoBuys, "includes", id) then
		do return end
	end
	local upg = tmp[JS.k(layer)].milestones[JS.k(id)]
	if (not JS.t(upg.pseudoCan)) then
		do return end
	end
	JS.m(player[JS.k(layer)].pseudoBuys, "push", id)
end
unlockUpg = function(this, layer, id)
	if (not JS.t(player[JS.k(layer)].unlocked)) then
		do return end
	end
	if (not JS.t(tmp[JS.k(layer)].upgrades[JS.k(id)].perkUnl)) then
		do return end
	end
	if JS.t(tmp[JS.k(layer)].upgrades[JS.k(id)].unlocked) then
		do return end
	end
	if JS.m(player[JS.k(layer)].perkUpgs, "includes", id) then
		do return end
	end
	local upg = tmp[JS.k(layer)].upgrades[JS.k(id)]
	if (not JS.t(upg.perkCan)) then
		do return end
	end
	JS.m(player[JS.k(layer)].perkUpgs, "push", id)
end
pseudoUnl = function(this, layer, id)
	do return (if JS.t(tmp[JS.k(layer)].milestones[JS.k(id)].pseudoUnl) then tmp[JS.k(layer)].milestones[JS.k(id)].unlocked else tmp[JS.k(layer)].milestones[JS.k(id)].pseudoUnl) end
end
perkUnl = function(this, layer, id)
	do return (if JS.t(tmp[JS.k(layer)].upgrades[JS.k(id)].perkUnl) then (not JS.t(tmp[JS.k(layer)].upgrades[JS.k(id)].unlocked)) else tmp[JS.k(layer)].upgrades[JS.k(id)].perkUnl) end
end
onTreeTab = true
shiftDown = false
ctrlDown = false
JS.setk(document, "onkeydown", function(this, e)
	if (player == nil) then
		do return end
	end
	shiftDown = e.shiftKey
	ctrlDown = e.ctrlKey
	if (JS.t(tmp.gameEnded) and (not JS.t(player.keepGoing))) then
		do return end
	end
	local key = e.key
	if JS.t(ctrlDown) then
		key = ("ctrl+" .. JS.str(key))
	end
	if JS.t(onFocused) then
		do return end
	end
	if (JS.t(ctrlDown) and JS.t(hotkeys[JS.k(key)])) then
		e:preventDefault()
	end
	if JS.t(hotkeys[JS.k(key)]) then
		local k = hotkeys[JS.k(key)]
		if (JS.t(player[JS.k(k.layer)].unlocked) and JS.t(tmp[JS.k(k.layer)].hotkeys[JS.k(k.id)].unlocked)) then
			k:onPress()
		end
	end
end)
JS.setk(document, "onkeyup", function(this, e)
	shiftDown = e.shiftKey
	ctrlDown = e.ctrlKey
end)
onFocused = false
JS.setk(document, "title", modInfo.name)
activePopups = JS.A(0)
popupID = 0

end
