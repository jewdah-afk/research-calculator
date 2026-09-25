--!nocheck
-- transpiled from game.js by port/build.js: do not edit
return function()
-- transpiled from game.js
getResetGain = function(this, layer, useType)
	if useType == nil then useType = JS.NULL end
	local type_ = useType
	if (not JS.t(useType)) then
		type_ = tmp[JS.k(layer)].type
		if (not (layers[JS.k(layer)].getResetGain == nil)) then
			do return layers[JS.k(layer)]:getResetGain() end
		end
	end
	if (tmp[JS.k(layer)].type == "none") then
		do return JS.D(0) end
	end
	if tmp[JS.k(layer)].gainExp:eq(0) then
		do return decimalZero end
	end
	if (type_ == "static") then
		if ((not JS.t(tmp[JS.k(layer)].canBuyMax)) or tmp[JS.k(layer)].baseAmount:lt(tmp[JS.k(layer)].requires)) then
			do return decimalOne end
		end
		local gain = tmp[JS.k(layer)].baseAmount:div(tmp[JS.k(layer)].requires):div(tmp[JS.k(layer)].gainMult):max(1):log(tmp[JS.k(layer)].base):times(tmp[JS.k(layer)].gainExp):pow(Decimal.pow(tmp[JS.k(layer)].exponent, (-1)))
		gain = gain:times(tmp[JS.k(layer)].directMult)
		do return (if (JS.tonum(tmp[JS.k(layer)].cap) >= 0) then gain:floor():sub(player[JS.k(layer)].points):add(1):max(1):min(tmp[JS.k(layer)].cap) else gain:floor():sub(player[JS.k(layer)].points):add(1):max(1)) end
	elseif (type_ == "normal") then
		if tmp[JS.k(layer)].baseAmount:lt(tmp[JS.k(layer)].requires) then
			do return decimalZero end
		end
		local gain = tmp[JS.k(layer)].baseAmount:div(tmp[JS.k(layer)].requires):pow(tmp[JS.k(layer)].exponent):times(tmp[JS.k(layer)].gainMult):pow(tmp[JS.k(layer)].gainExp)
		if gain:gte(tmp[JS.k(layer)].softcap) then
			gain = gain:pow(tmp[JS.k(layer)].softcapPower):times(tmp[JS.k(layer)].softcap:pow(decimalOne:sub(tmp[JS.k(layer)].softcapPower)))
		end
		gain = gain:times(tmp[JS.k(layer)].directMult)
		do return gain:floor():max(0) end
	elseif (type_ == "custom") then
		do return layers[JS.k(layer)]:getResetGain() end
	else
		do return decimalZero end
	end
end
getNextAt = function(this, layer, canMax, useType)
	if canMax == nil then canMax = false end
	if useType == nil then useType = JS.NULL end
	local type_ = useType
	if (not JS.t(useType)) then
		type_ = tmp[JS.k(layer)].type
		if (not (layers[JS.k(layer)].getNextAt == nil)) then
			do return layers[JS.k(layer)]:getNextAt(canMax) end
		end
	end
	if (tmp[JS.k(layer)].type == "none") then
		do return JS.D(math.huge) end
	end
	if tmp[JS.k(layer)].gainMult:lte(0) then
		do return JS.D(math.huge) end
	end
	if tmp[JS.k(layer)].gainExp:lte(0) then
		do return JS.D(math.huge) end
	end
	if (type_ == "static") then
		if (not JS.t(tmp[JS.k(layer)].canBuyMax)) then
			canMax = false
		end
		local amt = player[JS.k(layer)].points:plus((if (JS.t(canMax) and tmp[JS.k(layer)].baseAmount:gte(tmp[JS.k(layer)].nextAt)) then tmp[JS.k(layer)].resetGain else 0)):div(tmp[JS.k(layer)].directMult)
		local extraCost = Decimal.pow(tmp[JS.k(layer)].base, amt:pow(tmp[JS.k(layer)].exponent):div(tmp[JS.k(layer)].gainExp)):times(tmp[JS.k(layer)].gainMult)
		local cost = extraCost:times(tmp[JS.k(layer)].requires):max(tmp[JS.k(layer)].requires)
		if JS.t(tmp[JS.k(layer)].roundUpCost) then
			cost = cost:ceil()
		end
		do return cost end
	elseif (type_ == "normal") then
		local next_ = tmp[JS.k(layer)].resetGain:add(1):div(tmp[JS.k(layer)].directMult)
		if next_:gte(tmp[JS.k(layer)].softcap) then
			next_ = next_:div(tmp[JS.k(layer)].softcap:pow(decimalOne:sub(tmp[JS.k(layer)].softcapPower))):pow(decimalOne:div(tmp[JS.k(layer)].softcapPower))
		end
		next_ = next_:root(tmp[JS.k(layer)].gainExp):div(tmp[JS.k(layer)].gainMult):root(tmp[JS.k(layer)].exponent):times(tmp[JS.k(layer)].requires):max(tmp[JS.k(layer)].requires)
		if JS.t(tmp[JS.k(layer)].roundUpCost) then
			next_ = next_:ceil()
		end
		do return next_ end
	elseif (type_ == "custom") then
		do return layers[JS.k(layer)]:getNextAt(canMax) end
	else
		do return decimalZero end
	end
end
softcap = function(this, value, cap, power)
	if power == nil then power = 0.5 end
	if value:lte(cap) then
		do return value end
	else
		do return value:pow(power):times(cap:pow(decimalOne:sub(power))) end
	end
end
shouldNotify = function(this, layer)
	for _, __k1 in JS.keys(tmp[JS.k(layer)].upgrades) do
		id = __k1
		if isPlainObject(nil, layers[JS.k(layer)].upgrades[id]) then
			if ((canAffordUpgrade(nil, layer, id) and (not hasUpgrade(nil, layer, id))) and JS.t(tmp[JS.k(layer)].upgrades[id].unlocked)) then
				do return true end
			end
		end
	end
	for _, __k2 in JS.keys(tmp[JS.k(layer)].buyables) do
		id = __k2
		if isPlainObject(nil, layers[JS.k(layer)].buyables[id]) then
			if (canBuyBuyable(nil, layer, id) and JS.t(layers[JS.k(layer)].buyables[id].ifNotify)) then
				do return true end
			end
		end
	end
	if (JS.t(player[JS.k(layer)].activeChallenge) and canCompleteChallenge(nil, layer, player[JS.k(layer)].activeChallenge)) then
		do return true end
	end
	if JS.t(tmp[JS.k(layer)].shouldNotify) then
		do return true end
	end
	if isPlainObject(nil, tmp[JS.k(layer)].tabFormat) then
		for _, __k3 in JS.keys(tmp[JS.k(layer)].tabFormat) do
			subtab = __k3
			if JS.t(subtabShouldNotify(nil, layer, "mainTabs", subtab)) then
				JS.setk(tmp[JS.k(layer)], "trueGlowColor", (if JS.t(tmp[JS.k(layer)].tabFormat[subtab].glowColor) then tmp[JS.k(layer)].tabFormat[subtab].glowColor else defaultGlow))
				do return true end
			end
		end
	end
	for _, __k4 in JS.keys(tmp[JS.k(layer)].microtabs) do
		family = __k4
		for _, __k5 in JS.keys(tmp[JS.k(layer)].microtabs[family]) do
			subtab = __k5
			if JS.t(subtabShouldNotify(nil, layer, family, subtab)) then
				JS.setk(tmp[JS.k(layer)], "trueGlowColor", tmp[JS.k(layer)].microtabs[family][subtab].glowColor)
				do return true end
			end
		end
	end
	do return false end
end
canReset = function(this, layer)
	if (not (layers[JS.k(layer)].canReset == nil)) then
		do return run(nil, layers[JS.k(layer)].canReset, layers[JS.k(layer)]) end
	elseif (tmp[JS.k(layer)].type == "normal") then
		do return tmp[JS.k(layer)].baseAmount:gte(tmp[JS.k(layer)].requires) end
	elseif (tmp[JS.k(layer)].type == "static") then
		do return tmp[JS.k(layer)].baseAmount:gte(tmp[JS.k(layer)].nextAt) end
	else
		do return false end
	end
end
rowReset = function(this, row, layer)
	for _, __k6 in JS.keys(ROW_LAYERS[JS.k(row)]) do
		lr = __k6
		if JS.t(layers[lr].doReset) then
			if (not isNaN(nil, row)) then
				Vue.set(player[lr], "activeChallenge", JS.NULL)
			end
			run(nil, layers[lr].doReset, layers[lr], layer)
		elseif (JS.cmp(tmp[JS.k(layer)].row, ">", tmp[lr].row) and (not isNaN(nil, row))) then
			layerDataReset(nil, lr)
		end
	end
end
layerDataReset = function(this, layer, keep)
	if keep == nil then keep = JS.A(0) end
	local storedData = JS.O({
		unlocked = player[JS.k(layer)].unlocked,
		forceTooltip = player[JS.k(layer)].forceTooltip,
		noRespecConfirm = player[JS.k(layer)].noRespecConfirm,
		prevTab = player[JS.k(layer)].prevTab,
		best = player[JS.k(layer)].best
	}, {"unlocked", "forceTooltip", "noRespecConfirm", "prevTab", "best"})
	for _, __k7 in JS.keys(keep) do
		thing = __k7
		if (not (player[JS.k(layer)][JS.k(keep[thing])] == nil)) then
			JS.set(storedData, JS.k(keep[thing]), player[JS.k(layer)][JS.k(keep[thing])])
		end
	end
	Vue.set(player[JS.k(layer)], "buyables", getStartBuyables(nil, layer))
	Vue.set(player[JS.k(layer)], "clickables", getStartClickables(nil, layer))
	Vue.set(player[JS.k(layer)], "challenges", getStartChallenges(nil, layer))
	Vue.set(player[JS.k(layer)], "grid", getStartGrid(nil, layer))
	layOver(nil, player[JS.k(layer)], getStartLayerData(nil, layer))
	JS.setk(player[JS.k(layer)], "upgrades", JS.A(0))
	JS.setk(player[JS.k(layer)], "milestones", JS.A(0))
	JS.setk(player[JS.k(layer)], "achievements", JS.A(0))
	for _, __k8 in JS.keys(storedData) do
		thing = __k8
		JS.set(player[JS.k(layer)], thing, storedData[thing])
	end
end
addPoints = function(this, layer, gain)
	JS.setk(player[JS.k(layer)], "points", player[JS.k(layer)].points:add(gain):max(0))
	if JS.t(player[JS.k(layer)].best) then
		JS.setk(player[JS.k(layer)], "best", player[JS.k(layer)].best:max(player[JS.k(layer)].points))
	end
	if JS.t(player[JS.k(layer)].total) then
		JS.setk(player[JS.k(layer)], "total", player[JS.k(layer)].total:add(gain))
	end
end
generatePoints = function(this, layer, diff)
	addPoints(nil, layer, tmp[JS.k(layer)].resetGain:times(diff))
end
doReset = function(this, layer, force)
	if force == nil then force = false end
	if (tmp[JS.k(layer)].type == "none") then
		do return end
	end
	local row = tmp[JS.k(layer)].row
	if (not JS.t(force)) then
		if (tmp[JS.k(layer)].canReset == false) then
			do return end
		end
		if tmp[JS.k(layer)].baseAmount:lt(tmp[JS.k(layer)].requires) then
			do return end
		end
		local gain = tmp[JS.k(layer)].resetGain
		if (tmp[JS.k(layer)].type == "static") then
			if tmp[JS.k(layer)].baseAmount:lt(tmp[JS.k(layer)].nextAt) then
				do return end
			end
			gain = (if JS.t(tmp[JS.k(layer)].canBuyMax) then gain else 1)
		end
		if JS.t(layers[JS.k(layer)].onPrestige) then
			run(nil, layers[JS.k(layer)].onPrestige, layers[JS.k(layer)], gain)
		end
		addPoints(nil, layer, gain)
		updateMilestones(nil, layer)
		updateAchievements(nil, layer)
		if (not JS.t(player[JS.k(layer)].unlocked)) then
			JS.setk(player[JS.k(layer)], "unlocked", true)
			needCanvasUpdate = true
			if JS.t(tmp[JS.k(layer)].increaseUnlockOrder) then
				lrs = tmp[JS.k(layer)].increaseUnlockOrder
				for _, __k9 in JS.keys(lrs) do
					lr = __k9
					if (not JS.t(player[JS.k(lrs[lr])].unlocked)) then
						JS.setk(player[JS.k(lrs[lr])], "unlockOrder", (JS.tonum(player[JS.k(lrs[lr])].unlockOrder) + 1))
					end
				end
			end
		end
	end
	if JS.t(run(nil, layers[JS.k(layer)].resetsNothing, layers[JS.k(layer)])) then
		do return end
	end
	JS.setk(tmp[JS.k(layer)], "baseAmount", decimalZero)
	for _, __k10 in JS.keys(layers) do
		layerResetting = __k10
		if (JS.cmp(row, ">=", layers[layerResetting].row) and ((not JS.t(force)) or (not JS.eq(layerResetting, layer)))) then
			completeChallenge(nil, layerResetting)
		end
	end
	JS.setk(player, "points", (if JS.eq(row, 0) then decimalZero else getStartPoints(nil)))
	for x = JS.tonum(row), JS.cap(JS.tonum(row), 0, -1), -1 do
		rowReset(nil, x, layer)
	end
	for _, __k11 in JS.keys(OTHER_LAYERS) do
		r = __k11
		rowReset(nil, r, layer)
	end
	JS.setk(player[JS.k(layer)], "resetTime", 0)
	updateTemp(nil)
	updateTemp(nil)
end
resetRow = function(this, row)
	if (not (prompt(nil, "Are you sure you want to reset this row? It is highly recommended that you wait until the end of your current run before doing this! Type \"I WANT TO RESET THIS\" to confirm") == "I WANT TO RESET THIS")) then
		do return end
	end
	local pre_layers = ROW_LAYERS[JS.k((JS.tonum(row) - 1))]
	local layers = ROW_LAYERS[JS.k(row)]
	local post_layers = ROW_LAYERS[JS.k(JS.add(row, 1))]
	rowReset(nil, JS.add(row, 1), post_layers[0])
	doReset(nil, pre_layers[0], true)
	for _, __k12 in JS.keys(layers) do
		local layer = __k12
		JS.setk(player[layer], "unlocked", false)
		if JS.t(player[layer].unlockOrder) then
			JS.setk(player[layer], "unlockOrder", 0)
		end
	end
	JS.setk(player, "points", getStartPoints(nil))
	updateTemp(nil)
	resizeCanvas(nil)
end
startChallenge = function(this, layer, x)
	local enter = false
	if ((not JS.t(player[JS.k(layer)].unlocked)) or (not JS.t(tmp[JS.k(layer)].challenges[JS.k(x)].unlocked))) then
		do return end
	end
	if JS.eq(player[JS.k(layer)].activeChallenge, x) then
		completeChallenge(nil, layer, x)
		Vue.set(player[JS.k(layer)], "activeChallenge", JS.NULL)
	else
		enter = true
	end
	doReset(nil, layer, true)
	if JS.t(enter) then
		Vue.set(player[JS.k(layer)], "activeChallenge", x)
		run(nil, layers[JS.k(layer)].challenges[JS.k(x)].onEnter, layers[JS.k(layer)].challenges[JS.k(x)])
	end
	updateChallengeTemp(nil, layer)
end
canCompleteChallenge = function(this, layer, x)
	if (not JS.eq(x, player[JS.k(layer)].activeChallenge)) then
		do return end
	end
	local challenge = tmp[JS.k(layer)].challenges[JS.k(x)]
	if (not (challenge.canComplete == nil)) then
		do return challenge.canComplete end
	end
	if JS.t(challenge.currencyInternalName) then
		local name = challenge.currencyInternalName
		if JS.t(challenge.currencyLocation) then
			do return (not challenge.currencyLocation[JS.k(name)]:lt(challenge.goal)) end
		elseif JS.t(challenge.currencyLayer) then
			local lr = challenge.currencyLayer
			do return (not player[JS.k(lr)][JS.k(name)]:lt(challenge.goal)) end
		else
			do return (not player[JS.k(name)]:lt(challenge.goal)) end
		end
	else
		do return (not player.points:lt(challenge.goal)) end
	end
end
completeChallenge = function(this, layer, x)
	local x = player[JS.k(layer)].activeChallenge
	if (not JS.t(x)) then
		do return end
	end
	local completions = canCompleteChallenge(nil, layer, x)
	if (not JS.t(completions)) then
		Vue.set(player[JS.k(layer)], "activeChallenge", JS.NULL)
		run(nil, layers[JS.k(layer)].challenges[JS.k(x)].onExit, layers[JS.k(layer)].challenges[JS.k(x)])
		do return end
	end
	if JS.cmp(player[JS.k(layer)].challenges[JS.k(x)], "<", tmp[JS.k(layer)].challenges[JS.k(x)].completionLimit) then
		needCanvasUpdate = true
		JS.set(player[JS.k(layer)].challenges, JS.k(x), JS.add(player[JS.k(layer)].challenges[JS.k(x)], completions))
		JS.set(player[JS.k(layer)].challenges, JS.k(x), Math.min(player[JS.k(layer)].challenges[JS.k(x)], tmp[JS.k(layer)].challenges[JS.k(x)].completionLimit))
		if JS.t(layers[JS.k(layer)].challenges[JS.k(x)].onComplete) then
			run(nil, layers[JS.k(layer)].challenges[JS.k(x)].onComplete, layers[JS.k(layer)].challenges[JS.k(x)])
		end
	end
	Vue.set(player[JS.k(layer)], "activeChallenge", JS.NULL)
	run(nil, layers[JS.k(layer)].challenges[JS.k(x)].onExit, layers[JS.k(layer)].challenges[JS.k(x)])
	updateChallengeTemp(nil, layer)
end
autobuyUpgrades = function(this, layer)
	if (not JS.t(tmp[JS.k(layer)].upgrades)) then
		do return end
	end
	for _, __k13 in JS.keys(tmp[JS.k(layer)].upgrades) do
		id = __k13
		if (isPlainObject(nil, tmp[JS.k(layer)].upgrades[id]) and ((layers[JS.k(layer)].upgrades[id].canAfford == nil) or (layers[JS.k(layer)].upgrades[id]:canAfford() == true))) then
			buyUpg(nil, layer, id)
		end
	end
end
gameLoop = function(this, diff)
	if (isEndgame(nil) or JS.t(tmp.gameEnded)) then
		JS.setk(tmp, "gameEnded", true)
		clearParticles(nil)
	end
	if (isNaN(nil, diff) or (JS.tonum(diff) < 0)) then
		diff = 0
	end
	if (JS.t(tmp.gameEnded) and (not JS.t(player.keepGoing))) then
		diff = 0
		clearParticles(nil)
	end
	if JS.t(maxTickLength) then
		local limit = maxTickLength(nil)
		if JS.cmp(diff, ">", limit) then
			diff = limit
		end
	end
	addTime(nil, diff)
	JS.setk(player, "points", player.points:add(tmp.pointGen:times(diff)):max(0))
	for x = 0, JS.cap(0, JS.tonum(maxRow), 1) do
		for _, __k14 in JS.keys(TREE_LAYERS[JS.k(x)]) do
			item = __k14
			local layer = TREE_LAYERS[JS.k(x)][item]
			JS.setk(player[JS.k(layer)], "resetTime", JS.add(player[JS.k(layer)].resetTime, diff))
			if JS.t(tmp[JS.k(layer)].passiveGeneration) then
				generatePoints(nil, layer, (JS.tonum(diff) * JS.tonum(tmp[JS.k(layer)].passiveGeneration)))
			end
			if JS.t(layers[JS.k(layer)].update) then
				layers[JS.k(layer)]:update(diff)
			end
		end
	end
	for _, __k15 in JS.keys(OTHER_LAYERS) do
		row = __k15
		for _, __k16 in JS.keys(OTHER_LAYERS[row]) do
			item = __k16
			local layer = OTHER_LAYERS[row][item]
			JS.setk(player[JS.k(layer)], "resetTime", JS.add(player[JS.k(layer)].resetTime, diff))
			if JS.t(tmp[JS.k(layer)].passiveGeneration) then
				generatePoints(nil, layer, (JS.tonum(diff) * JS.tonum(tmp[JS.k(layer)].passiveGeneration)))
			end
			if JS.t(layers[JS.k(layer)].update) then
				layers[JS.k(layer)]:update(diff)
			end
		end
	end
	for x = JS.tonum(maxRow), JS.cap(JS.tonum(maxRow), 0, -1), -1 do
		for _, __k17 in JS.keys(TREE_LAYERS[JS.k(x)]) do
			item = __k17
			local layer = TREE_LAYERS[JS.k(x)][item]
			if (JS.t(tmp[JS.k(layer)].autoPrestige) and JS.t(tmp[JS.k(layer)].canReset)) then
				doReset(nil, layer)
			end
			if JS.t(layers[JS.k(layer)].automate) then
				layers[JS.k(layer)]:automate()
			end
			if JS.t(tmp[JS.k(layer)].autoUpgrade) then
				autobuyUpgrades(nil, layer)
			end
		end
	end
	for _, __k18 in JS.keys(OTHER_LAYERS) do
		row = __k18
		for _, __k19 in JS.keys(OTHER_LAYERS[row]) do
			item = __k19
			local layer = OTHER_LAYERS[row][item]
			if (JS.t(tmp[JS.k(layer)].autoPrestige) and JS.t(tmp[JS.k(layer)].canReset)) then
				doReset(nil, layer)
			end
			if JS.t(layers[JS.k(layer)].automate) then
				layers[JS.k(layer)]:automate()
			end
			JS.setk(player[JS.k(layer)], "best", player[JS.k(layer)].best:max(player[JS.k(layer)].points))
			if JS.t(tmp[JS.k(layer)].autoUpgrade) then
				autobuyUpgrades(nil, layer)
			end
		end
	end
	for _, __k20 in JS.keys(layers) do
		layer = __k20
		if JS.t(layers[layer].milestones) then
			updateMilestones(nil, layer)
		end
		if JS.t(layers[layer].achievements) then
			updateAchievements(nil, layer)
		end
	end
end
hardReset = function(this, resetOptions)
	player = JS.NULL
	if JS.t(resetOptions) then
		options = JS.NULL
	end
	save(nil, true)
	window.location:reload()
end
needCanvasUpdate = true
TMT_VERSION = JS.O({
	tmtNum = "2.6.6.2",
	tmtName = "Fixed Reality"
}, {"tmtNum", "tmtName"})
JS.setk(VERSION, "withoutName", (("v" .. JS.str(VERSION.num)) .. JS.str((if JS.t(VERSION.pre) then (" Pre-Release " .. JS.str(VERSION.pre)) else (if JS.t(VERSION.pre) then (" Beta " .. JS.str(VERSION.beta)) else "")))))
JS.setk(VERSION, "withName", JS.add(VERSION.withoutName, (if JS.t(VERSION.name) then (": " .. JS.str(VERSION.name)) else "")))
ticking = false
interval = setInterval(nil, function(this)
	if ((player == nil) or (tmp == nil)) then
		do return end
	end
	if JS.t(ticking) then
		do return end
	end
	if (JS.t(tmp.gameEnded) and (not JS.t(player.keepGoing))) then
		do return end
	end
	ticking = true
	local now = Date.now()
	local diff = ((JS.tonum(now) - JS.tonum(player.time)) / 1000)
	local trueDiff = diff
	if (not (player.offTime == nil)) then
		if (JS.tonum(player.offTime.remain) > (JS.tonum(modInfo.offlineLimit) * 3600)) then
			JS.setk(player.offTime, "remain", (JS.tonum(modInfo.offlineLimit) * 3600))
		end
		if (JS.tonum(player.offTime.remain) > 0) then
			local offlineDiff = Math.max((JS.tonum(player.offTime.remain) / 10), diff)
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
	if JS.t(needCanvasUpdate) then
		resizeCanvas(nil)
		needCanvasUpdate = false
	end
	JS.setk(tmp, "scrolled", JS.and_(document.getElementById("treeTab"), function() return (JS.tonum(document.getElementById("treeTab").scrollTop) > 30) end))
	updateTemp(nil)
	updateOomps(nil, diff)
	updateWidth(nil)
	updateTabFormats(nil)
	gameLoop(nil, diff)
	fixNaNs(nil)
	adjustPopupTime(nil, trueDiff)
	updateParticles(nil, trueDiff)
	ticking = false
end, 50)
setInterval(nil, function(this)
	needCanvasUpdate = true
end, 500)

end
