--!nocheck
-- transpiled from technical/temp.js by port/build.js: do not edit
return function()
-- transpiled from technical/temp.js
setupTemp = function(this)
	tmp = JS.O({})
	JS.setk(tmp, "pointGen", JS.O({}))
	JS.setk(tmp, "backgroundStyle", JS.O({}))
	JS.setk(tmp, "displayThings", JS.A(0))
	JS.setk(tmp, "scrolled", 0)
	JS.setk(tmp, "gameEnded", false)
	funcs = JS.O({})
	setupTempData(nil, layers, tmp, funcs)
	for _, __k1 in JS.keys(layers) do
		layer = __k1
		JS.setk(tmp[layer], "resetGain", JS.O({}))
		JS.setk(tmp[layer], "nextAt", JS.O({}))
		JS.setk(tmp[layer], "nextAtDisp", JS.O({}))
		JS.setk(tmp[layer], "canReset", JS.O({}))
		JS.setk(tmp[layer], "notify", JS.O({}))
		JS.setk(tmp[layer], "prestigeNotify", JS.O({}))
		JS.setk(tmp[layer], "computedNodeStyle", JS.A(0))
		setupBuyables(nil, layer)
		JS.setk(tmp[layer], "trueGlowColor", JS.A(0))
	end
	JS.setk(tmp, "other", JS.O({
		lastPoints = (if JS.t(player.points) then player.points else decimalZero),
		oomps = decimalZero,
		screenWidth = 0,
		screenHeight = 0
	}, {"lastPoints", "oomps", "screenWidth", "screenHeight"}))
	updateWidth(nil)
	temp = tmp
end
setupTempData = function(this, layerData, tmpData, funcsData)
	for _, __k2 in JS.keys(layerData) do
		item = __k2
		if JS.isnil(layerData[item]) then
			JS.set(tmpData, item, JS.NULL)
		elseif JS.instanceof(layerData[item], Decimal) then
			JS.set(tmpData, item, layerData[item])
		elseif Array.isArray(layerData[item]) then
			JS.set(tmpData, item, JS.A(0))
			JS.set(funcsData, item, JS.A(0))
			setupTempData(nil, layerData[item], tmpData[item], funcsData[item])
		elseif ((not (not JS.t(layerData[item]))) and JS.eq(JS.get(layerData[item], "constructor"), Object)) then
			JS.set(tmpData, item, JS.O({}))
			JS.set(funcsData, item, JS.A(0))
			setupTempData(nil, layerData[item], tmpData[item], funcsData[item])
		elseif (((not (not JS.t(layerData[item]))) and (JS.typeof(layerData[item]) == "object")) and JS.m(traversableClasses, "includes", JS.get(layerData[item], "constructor").name)) then
			JS.set(tmpData, item, JS.new(JS.get(layerData[item], "constructor")))
			JS.set(funcsData, item, JS.new(JS.get(layerData[item], "constructor")))
		elseif (isFunction(nil, layerData[item]) and (not JS.m(activeFunctions, "includes", item))) then
			JS.set(funcsData, item, layerData[item])
			if JS.m(boolNames, "includes", item) then
				JS.set(tmpData, item, false)
			else
				JS.set(tmpData, item, decimalOne)
			end
		else
			JS.set(tmpData, item, layerData[item])
		end
	end
end
updateTemp = function(this)
	if JS.eq(player.cp.chosenBackdoor, 0) then
		JS.setk(player.cp, "chosenBackdoor", nil)
	end
	if JS.isnil(player.cp.trojanChosen) then
		JS.setk(player.cp, "trojanChosen", nil)
	end
	if (JS.tonum(player.mp.challenges[21]) > 1) then
		JS.set(player.mp.challenges, 21, 0)
	end
	if player.p.points:lt(0) then
		JS.setk(player.p, "points", JS.D(0))
	end
	if (tmp == nil) then
		setupTemp(nil)
	end
	updateTempData(nil, layers, tmp, funcs)
	for _, __k3 in JS.keys(layers) do
		layer = __k3
		JS.setk(tmp[layer], "resetGain", getResetGain(nil, layer))
		JS.setk(tmp[layer], "nextAt", getNextAt(nil, layer))
		JS.setk(tmp[layer], "nextAtDisp", getNextAt(nil, layer, true))
		JS.setk(tmp[layer], "canReset", canReset(nil, layer))
		JS.setk(tmp[layer], "trueGlowColor", tmp[layer].glowColor)
		JS.setk(tmp[layer], "notify", shouldNotify(nil, layer))
		JS.setk(tmp[layer], "prestigeNotify", prestigeNotify(nil, layer))
		if (tmp[layer].passiveGeneration == true) then
			JS.setk(tmp[layer], "passiveGeneration", 1)
		end
		if JS.isnil(player.cp.grid[101].cautPower) then
			fixOldSave(nil)
		end
	end
	JS.setk(tmp, "pointGen", getPointGen(nil))
	JS.setk(tmp, "backgroundStyle", readData(nil, backgroundStyle))
	JS.setk(tmp, "displayThings", JS.A(0))
	for _, __k4 in JS.keys(displayThings) do
		thing = __k4
		local text = displayThings[thing]
		if isFunction(nil, text) then
			text = text(nil)
		end
		JS.m(tmp.displayThings, "push", text)
	end
end
updateTempData = function(this, layerData, tmpData, funcsData, useThis)
	for _, __k5 in JS.keys(funcsData) do
		item = __k5
		if Array.isArray(layerData[item]) then
			if ((not (item == "tabFormat")) and (not (item == "content"))) then
				updateTempData(nil, layerData[item], tmpData[item], funcsData[item], useThis)
			end
		elseif (((not (not JS.t(layerData[item]))) and JS.eq(JS.get(layerData[item], "constructor"), Object)) or ((JS.typeof(layerData[item]) == "object") and JS.m(traversableClasses, "includes", JS.get(layerData[item], "constructor").name))) then
			updateTempData(nil, layerData[item], tmpData[item], funcsData[item], useThis)
		elseif (isFunction(nil, layerData[item]) and (not isFunction(nil, tmpData[item]))) then
			local value = nil
			if (not (useThis == nil)) then
				value = (JS.m(layerData[item], "bind", useThis))(nil)
			else
				value = JS.mc(layerData, item)
			end
			Vue.set(tmpData, item, value)
		end
	end
end
updateChallengeTemp = function(this, layer)
	updateTempData(nil, layers[JS.k(layer)].challenges, tmp[JS.k(layer)].challenges, funcs[JS.k(layer)].challenges)
end
updateBuyableTemp = function(this, layer)
	updateTempData(nil, layers[JS.k(layer)].buyables, tmp[JS.k(layer)].buyables, funcs[JS.k(layer)].buyables)
end
updateClickableTemp = function(this, layer)
	updateTempData(nil, layers[JS.k(layer)].clickables, tmp[JS.k(layer)].clickables, funcs[JS.k(layer)].clickables)
end
setupBuyables = function(this, layer)
	for _, __k6 in JS.keys(layers[JS.k(layer)].buyables) do
		id = __k6
		if isPlainObject(nil, layers[JS.k(layer)].buyables[id]) then
			local b = layers[JS.k(layer)].buyables[id]
			JS.setk(b, "actualCostFunction", b.cost)
			JS.setk(b, "cost", function(this, x)
				x = (if (x == nil) then player[JS.k(this.layer)].buyables[JS.k(this.id)] else x)
				do return layers[JS.k(this.layer)].buyables[JS.k(this.id)]:actualCostFunction(x) end
			end)
			JS.setk(b, "actualEffectFunction", b.effect)
			JS.setk(b, "effect", function(this, x)
				x = (if (x == nil) then player[JS.k(this.layer)].buyables[JS.k(this.id)] else x)
				do return layers[JS.k(this.layer)].buyables[JS.k(this.id)]:actualEffectFunction(x) end
			end)
		end
	end
end
checkDecimalNaN = function(this, x)
	do return (JS.instanceof(x, Decimal) and (not x:eq(x))) end
end
tmp = JS.O({})
temp = tmp
funcs = JS.O({})
NaNalert = false
activeFunctions = JS.A(42, "startData", "onPrestige", "doReset", "update", "automate", "buy", "buyMax", "respec", "onPress", "onClick", "onHold", "masterButtonPress", "sellOne", "sellAll", "pay", "actualCostFunction", "actualEffectFunction", "effectDescription", "display", "fullDisplay", "effectDisplay", "rewardDisplay", "tabFormat", "content", "onComplete", "onPurchase", "onEnter", "onExit", "done", "getUnlocked", "getStyle", "getCanClick", "getTitle", "getDisplay", "getCost", "getEffect", "getEssence", "getTooltip", "getTooltipStyle", "activeCorruptions", "getMark", "fetchTimer")
noCall = doNotCallTheseFunctionsEveryTick
for _, __k7 in JS.keys(noCall) do
	item = __k7
	JS.m(activeFunctions, "push", noCall[item])
end
traversableClasses = JS.A(0)
boolNames = JS.A(2, "unlocked", "deactivated")

end
