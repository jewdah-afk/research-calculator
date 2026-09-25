--!nocheck
-- transpiled from utils/save.js by port/build.js: do not edit
return function()
-- transpiled from utils/save.js
save = function(this, force)
	NaNcheck(nil, player)
	if (JS.t(NaNalert) and (not JS.t(force))) then
		do return end
	end
	localStorage.setItem(modInfo.id, btoa(nil, unescape(nil, encodeURIComponent(nil, JSON.stringify(player)))))
	localStorage.setItem((JS.str(modInfo.id) .. "_options"), btoa(nil, unescape(nil, encodeURIComponent(nil, JSON.stringify(options)))))
end
startPlayerBase = function(this)
	do return JS.O({
		tab = layoutInfo.startTab,
		navTab = (if JS.t(layoutInfo.showTree) then layoutInfo.startNavTab else "none"),
		time = Date.now(),
		notify = JS.O({}),
		versionType = modInfo.id,
		version = VERSION.num,
		beta = VERSION.beta,
		timePlayed = 0,
		keepGoing = false,
		hasNaN = false,
		points = modInfo.initialStartPoints,
		subtabs = JS.O({}),
		lastSafeTab = (if JS.t(readData(nil, layoutInfo.showTree)) then "none" else layoutInfo.startTab)
	}, {"tab", "navTab", "time", "notify", "versionType", "version", "beta", "timePlayed", "keepGoing", "hasNaN", "points", "subtabs", "lastSafeTab"}) end
end
getStartPlayer = function(this)
	playerdata = startPlayerBase(nil)
	if JS.t(addedPlayerData) then
		extradata = addedPlayerData(nil)
		for _, __k1 in JS.keys(extradata) do
			thing = __k1
			JS.set(playerdata, thing, extradata[thing])
		end
	end
	JS.setk(playerdata, "infoboxes", JS.O({}))
	for _, __k2 in JS.keys(layers) do
		layer = __k2
		JS.set(playerdata, layer, getStartLayerData(nil, layer))
		if (JS.t(layers[layer].tabFormat) and (not Array.isArray(layers[layer].tabFormat))) then
			JS.set(playerdata.subtabs, layer, JS.O({}))
			JS.setk(playerdata.subtabs[layer], "mainTabs", Object.keys(layers[layer].tabFormat)[0])
		end
		if JS.t(layers[layer].microtabs) then
			if JS.isnil(playerdata.subtabs[layer]) then
				JS.set(playerdata.subtabs, layer, JS.O({}))
			end
			for _, __k3 in JS.keys(layers[layer].microtabs) do
				item = __k3
				JS.set(playerdata.subtabs[layer], item, Object.keys(layers[layer].microtabs[item])[0])
			end
		end
		if JS.t(layers[layer].infoboxes) then
			if JS.isnil(playerdata.infoboxes[layer]) then
				JS.set(playerdata.infoboxes, layer, JS.O({}))
			end
			for _, __k4 in JS.keys(layers[layer].infoboxes) do
				item = __k4
				JS.set(playerdata.infoboxes[layer], item, false)
			end
		end
	end
	do return playerdata end
end
getStartLayerData = function(this, layer)
	layerdata = JS.O({})
	if JS.t(layers[JS.k(layer)].startData) then
		layerdata = layers[JS.k(layer)]:startData()
	end
	if (layerdata.unlocked == nil) then
		JS.setk(layerdata, "unlocked", true)
	end
	if (layerdata.total == nil) then
		JS.setk(layerdata, "total", decimalZero)
	end
	if (layerdata.best == nil) then
		JS.setk(layerdata, "best", decimalZero)
	end
	if (layerdata.resetTime == nil) then
		JS.setk(layerdata, "resetTime", 0)
	end
	if (layerdata.forceTooltip == nil) then
		JS.setk(layerdata, "forceTooltip", false)
	end
	JS.setk(layerdata, "buyables", getStartBuyables(nil, layer))
	if (layerdata.noRespecConfirm == nil) then
		JS.setk(layerdata, "noRespecConfirm", false)
	end
	if JS.isnil(layerdata.clickables) then
		JS.setk(layerdata, "clickables", getStartClickables(nil, layer))
	end
	JS.setk(layerdata, "spentOnBuyables", decimalZero)
	JS.setk(layerdata, "upgrades", JS.A(0))
	JS.setk(layerdata, "milestones", JS.A(0))
	JS.setk(layerdata, "lastMilestone", JS.NULL)
	JS.setk(layerdata, "achievements", JS.A(0))
	JS.setk(layerdata, "challenges", getStartChallenges(nil, layer))
	JS.setk(layerdata, "grid", getStartGrid(nil, layer))
	JS.setk(layerdata, "prevTab", "")
	do return layerdata end
end
getStartBuyables = function(this, layer)
	local data = JS.O({})
	if JS.t(layers[JS.k(layer)].buyables) then
		for _, __k5 in JS.keys(layers[JS.k(layer)].buyables) do
			id = __k5
			if isPlainObject(nil, layers[JS.k(layer)].buyables[id]) then
				JS.set(data, id, decimalZero)
			end
		end
	end
	do return data end
end
getStartClickables = function(this, layer)
	local data = JS.O({})
	if JS.t(layers[JS.k(layer)].clickables) then
		for _, __k6 in JS.keys(layers[JS.k(layer)].clickables) do
			id = __k6
			if isPlainObject(nil, layers[JS.k(layer)].clickables[id]) then
				JS.set(data, id, "")
			end
		end
	end
	do return data end
end
getStartChallenges = function(this, layer)
	local data = JS.O({})
	if JS.t(layers[JS.k(layer)].challenges) then
		for _, __k7 in JS.keys(layers[JS.k(layer)].challenges) do
			id = __k7
			if isPlainObject(nil, layers[JS.k(layer)].challenges[id]) then
				JS.set(data, id, 0)
			end
		end
	end
	do return data end
end
getStartGrid = function(this, layer)
	local data = JS.O({})
	if (not JS.t(layers[JS.k(layer)].grid)) then
		do return data end
	end
	if (layers[JS.k(layer)].grid.maxRows == nil) then
		JS.setk(layers[JS.k(layer)].grid, "maxRows", layers[JS.k(layer)].grid.rows)
	end
	if (layers[JS.k(layer)].grid.maxCols == nil) then
		JS.setk(layers[JS.k(layer)].grid, "maxCols", layers[JS.k(layer)].grid.cols)
	end
	for y = 1, JS.cap(1, JS.tonum(layers[JS.k(layer)].grid.maxRows), 1) do
		for x = 1, JS.cap(1, JS.tonum(layers[JS.k(layer)].grid.maxCols), 1) do
			JS.set(data, JS.k(JS.add((100 * JS.tonum(y)), x)), layers[JS.k(layer)].grid:getStartData(JS.add((100 * JS.tonum(y)), x)))
		end
	end
	do return data end
end
fixSave = function(this)
	defaultData = getStartPlayer(nil)
	fixData(nil, defaultData, player)
	for _, __k8 in JS.keys(layers) do
		layer = __k8
		if (not (player[layer].best == nil)) then
			JS.setk(player[layer], "best", JS.D(player[layer].best))
		end
		if (not (player[layer].total == nil)) then
			JS.setk(player[layer], "total", JS.D(player[layer].total))
		end
		if (JS.t(layers[layer].tabFormat) and (not Array.isArray(layers[layer].tabFormat))) then
			if (not JS.m(Object.keys(layers[layer].tabFormat), "includes", player.subtabs[layer].mainTabs)) then
				JS.setk(player.subtabs[layer], "mainTabs", Object.keys(layers[layer].tabFormat)[0])
			end
		end
		if JS.t(layers[layer].microtabs) then
			for _, __k9 in JS.keys(layers[layer].microtabs) do
				item = __k9
				if (not JS.m(Object.keys(layers[layer].microtabs[item]), "includes", player.subtabs[layer][item])) then
					JS.set(player.subtabs[layer], item, Object.keys(layers[layer].microtabs[item])[0])
				end
			end
		end
	end
end
fixData = function(this, defaultData, newData)
	for _, __k10 in JS.keys(defaultData) do
		item = __k10
		if JS.isnil(defaultData[item]) then
			if (newData[item] == nil) then
				JS.set(newData, item, JS.NULL)
			end
		elseif Array.isArray(defaultData[item]) then
			if (newData[item] == nil) then
				JS.set(newData, item, defaultData[item])
			else
				fixData(nil, defaultData[item], newData[item])
			end
		elseif JS.instanceof(defaultData[item], Decimal) then
			if (newData[item] == nil) then
				JS.set(newData, item, defaultData[item])
			else
				JS.set(newData, item, JS.D(newData[item]))
			end
		elseif ((not (not JS.t(defaultData[item]))) and (JS.typeof(defaultData[item]) == "object")) then
			if ((newData[item] == nil) or (not (JS.typeof(defaultData[item]) == "object"))) then
				JS.set(newData, item, defaultData[item])
			else
				fixData(nil, defaultData[item], newData[item])
			end
		else
			if (newData[item] == nil) then
				JS.set(newData, item, defaultData[item])
			end
		end
	end
end
load = function(this)
	local get = localStorage.getItem(modInfo.id)
	if ((get == JS.NULL) or (get == nil)) then
		player = getStartPlayer(nil)
		options = getStartOptions(nil)
	else
		player = Object.assign(getStartPlayer(nil), JSON.parse(decodeURIComponent(nil, escape(nil, atob(nil, get)))))
		fixSave(nil)
		loadOptions(nil)
	end
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
	changeTheme(nil)
	changeTreeQuality(nil)
	updateLayers(nil)
	setupModInfo(nil)
	setupTemp(nil)
	updateTemp(nil)
	updateTemp(nil)
	updateTabFormats(nil)
	loadVue(nil)
end
loadOptions = function(this)
	local get2 = localStorage.getItem((JS.str(modInfo.id) .. "_options"))
	if JS.t(get2) then
		options = Object.assign(getStartOptions(nil), JSON.parse(decodeURIComponent(nil, escape(nil, atob(nil, get2)))))
	else
		options = getStartOptions(nil)
	end
	if (JS.tonum(JS.m(themes, "indexOf", options.theme)) < 0) then
		theme = "default"
	end
	fixData(nil, options, getStartOptions(nil))
end
setupModInfo = function(this)
	JS.setk(modInfo, "changelog", changelog)
	JS.setk(modInfo, "winText", (if JS.t(winText) then winText else ("Congratulations! You have reached the end and beaten this game, but for now...")))
end
fixNaNs = function(this)
	NaNcheck(nil, player)
end
NaNcheck = function(this, data)
	for _, __k11 in JS.keys(data) do
		item = __k11
		if JS.isnil(data[item]) then

		elseif Array.isArray(data[item]) then
			NaNcheck(nil, data[item])
		elseif ((not JS.eq(data[item], data[item])) or JS.t(checkDecimalNaN(nil, data[item]))) then
			if (not JS.t(NaNalert)) then
				clearInterval(nil, interval)
				NaNalert = true
				alert(nil, (((("Invalid value found in player, named '" .. JS.str(item)) .. "'. ") .. JS.str(data[item])) .. " Please let the creator of this mod know! You can refresh the page, and you will be un-NaNed."))
				do return end
			end
		elseif JS.instanceof(data[item], Decimal) then

		elseif ((not (not JS.t(data[item]))) and JS.eq(JS.get(data[item], "constructor"), Object)) then
			NaNcheck(nil, data[item])
		end
	end
end
exportSave = function(this)
	local str = btoa(nil, JSON.stringify(player))
	local el = document.createElement("textarea")
	JS.setk(el, "value", str)
	document.body:appendChild(el)
	el:select()
	el:setSelectionRange(0, 99999)
	document.execCommand("copy")
	document.body:removeChild(el)
end
ImportSave = function(this)
	modal:show("Import Save", ("\n\t\t\tPaste your save here... (Warning: your current save will be overwritten!)<br/>\n\t\t\t<input type=\"text\" id=\"importSaveInput\" autocomplete=\"off\" style=\"margin:5px 0;width:400px;\"><br/>\n\t\t\t<button style=\"margin:5px\" class='import' onclick='importSave(document.getElementById(\"importSaveInput\").value)'> Import\n\t\t"), "❌")
end
HardReset = function(this)
	modal:show("Hard Reset", ("\n\t\t\tAre you sure you want to hard reset?<br/>\n\t\t\t<button style=\"margin:5px\" class='import' onclick='hardReset()'> Proceed\n\t\t"), "❌")
end
importSave = function(this, imported, forced)
	if imported == nil then imported = nil end
	if forced == nil then forced = false end
	if (imported == nil) then
		imported = createPrompt(nil, "Paste your save here")
	end
	do
		local __ok12, __e13 = pcall(function()
			tempPlr = Object.assign(getStartPlayer(nil), JSON.parse(atob(nil, imported)))
			if (((not JS.eq(tempPlr.versionType, modInfo.id)) and (not JS.t(forced))) and (not JS.t(confirm(nil, "This save appears to be for a different mod! Are you sure you want to import?")))) then
				do return end
			end
			player = tempPlr
			JS.setk(player, "versionType", modInfo.id)
			fixSave(nil)
			versionCheck(nil)
			NaNcheck(nil, save)
			save(nil)
			window.location:reload()
		end)
		if not __ok12 then
			local e = __e13
			do return end
		end
	end
end
versionCheck = function(this)
	local setVersion = true
	if ((player.versionType == nil) or (player.version == nil)) then
		JS.setk(player, "versionType", modInfo.id)
		JS.setk(player, "version", 0)
	end
	if JS.t(setVersion) then
		if (JS.eq(player.versionType, modInfo.id) and JS.cmp(VERSION.num, ">", player.version)) then
			JS.setk(player, "keepGoing", false)
			if JS.t(fixOldSave) then
				fixOldSave(nil, player.version)
			end
		end
		JS.setk(player, "versionType", getStartPlayer(nil).versionType)
		JS.setk(player, "version", VERSION.num)
		JS.setk(player, "beta", VERSION.beta)
	end
end
saveInterval = setInterval(nil, function(this)
	if (player == nil) then
		do return end
	end
	if (JS.t(tmp.gameEnded) and (not JS.t(player.keepGoing))) then
		do return end
	end
	if JS.t(options.autosave) then
		save(nil)
	end
end, 5000)
JS.setk(window, "onbeforeunload", function(_)
	if JS.t(player.autosave) then
		save(nil)
	end
end)

end
