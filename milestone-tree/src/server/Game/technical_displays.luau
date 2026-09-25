--!nocheck
-- transpiled from technical/displays.js by port/build.js: do not edit
return function()
-- transpiled from technical/displays.js
prestigeButtonText = function(this, layer)
	if (not (layers[JS.k(layer)].prestigeButtonText == nil)) then
		do return run(nil, layers[JS.k(layer)]:prestigeButtonText(), layers[JS.k(layer)]) end
	end
	if (tmp[JS.k(layer)].type == "normal") then
		do return (JS.str((if player[JS.k(layer)].points:lt(1000) then (if (not (tmp[JS.k(layer)].resetDescription == nil)) then tmp[JS.k(layer)].resetDescription else "Reset for ") else "")) .. "+<b>" .. JS.str(formatWhole(nil, tmp[JS.k(layer)].resetGain)) .. "</b> " .. JS.str(tmp[JS.k(layer)].resource) .. " " .. JS.str((if (tmp[JS.k(layer)].resetGain:lt(100) and player[JS.k(layer)].points:lt(1000)) then ("<br><br>Next at " .. JS.str((if JS.t(tmp[JS.k(layer)].roundUpCost) then formatWhole(nil, tmp[JS.k(layer)].nextAt) else format(nil, tmp[JS.k(layer)].nextAt))) .. " " .. JS.str(tmp[JS.k(layer)].baseResource)) else ""))) end
	end
	if (tmp[JS.k(layer)].type == "static") then
		do return (JS.str((if (not (tmp[JS.k(layer)].resetDescription == nil)) then tmp[JS.k(layer)].resetDescription else "Reset for ")) .. "+<b>" .. JS.str(formatWhole(nil, tmp[JS.k(layer)].resetGain)) .. "</b> " .. JS.str(tmp[JS.k(layer)].resource) .. "<br><br>" .. JS.str((if player[JS.k(layer)].points:lt(30) then (if ((tmp[JS.k(layer)].baseAmount:gte(tmp[JS.k(layer)].nextAt) and (not (tmp[JS.k(layer)].canBuyMax == nil))) and JS.t(tmp[JS.k(layer)].canBuyMax)) then "Next:" else "Req:") else "")) .. " " .. JS.str(formatWhole(nil, tmp[JS.k(layer)].baseAmount)) .. " / " .. JS.str((if JS.t(tmp[JS.k(layer)].roundUpCost) then formatWhole(nil, tmp[JS.k(layer)].nextAtDisp) else format(nil, tmp[JS.k(layer)].nextAtDisp))) .. " " .. JS.str(tmp[JS.k(layer)].baseResource) .. "\t\t\n\t\t") end
	end
	if (tmp[JS.k(layer)].type == "none") then
		do return "" end
	end
	do return "You need prestige button text" end
end
constructNodeStyle = function(this, layer)
	local style = JS.A(0)
	if ((JS.t(tmp[JS.k(layer)].isLayer) and layerunlocked(nil, layer)) or ((not JS.t(tmp[JS.k(layer)].isLayer)) and JS.t(tmp[JS.k(layer)].canClick))) then
		JS.m(style, "push", JS.O({
			["background-color"] = tmp[JS.k(layer)].color
		}))
	end
	if (not (tmp[JS.k(layer)].image == nil)) then
		JS.m(style, "push", JS.O({
			["background-image"] = (("url(\"" .. JS.str(tmp[JS.k(layer)].image)) .. "\")")
		}))
	end
	if (JS.t(tmp[JS.k(layer)].notify) and JS.t(player[JS.k(layer)].unlocked)) then
		JS.m(style, "push", JS.O({
			["box-shadow"] = ("var(--hqProperty2a), 0 0 20px " .. JS.str(tmp[JS.k(layer)].trueGlowColor))
		}))
	end
	JS.m(style, "push", tmp[JS.k(layer)].nodeStyle)
	do return style end
end
constructMenuButtonStyle = function(this, layer)
	local style = JS.A(0)
	if JS.eq(layerShown(nil, layer), true) then
		JS.m(style, "push", JS.O({
			["background-color"] = tmp[JS.k(layer)].color
		}))
	end
	if (JS.t(tmp[JS.k(layer)].notify) and JS.t(player[JS.k(layer)].unlocked)) then
		JS.m(style, "push", JS.O({
			["box-shadow"] = ("var(--hqProperty2a), 0 0 20px " .. JS.str(tmp[JS.k(layer)].trueGlowColor))
		}))
	end
	do return style end
end
challengeStyle = function(this, layer, id)
	if (JS.eq(player[JS.k(layer)].activeChallenge, id) and canCompleteChallenge(nil, layer, id)) then
		do return "canComplete" end
	elseif JS.t(hasChallenge(nil, layer, id)) then
		do return "done" end
	end
	do return "locked" end
end
challengeButtonText = function(this, layer, id)
	do return (if JS.eq(player[JS.k(layer)].activeChallenge, id) then (if canCompleteChallenge(nil, layer, id) then "Finish" else "Exit Early") else (if JS.t(hasChallenge(nil, layer, id)) then "Completed" else "Start")) end
end
achievementStyle = function(this, layer, id)
	ach = tmp[JS.k(layer)].achievements[JS.k(id)]
	local style = JS.A(0)
	if JS.t(ach.image) then
		JS.m(style, "push", JS.O({
			["background-image"] = (("url(\"" .. JS.str(ach.image)) .. "\")")
		}))
	end
	if (not JS.t(ach.unlocked)) then
		JS.m(style, "push", JS.O({
			visibility = "hidden"
		}))
	end
	JS.m(style, "push", ach.style)
	do return style end
end
updateWidth = function(this)
	local screenWidth = window.innerWidth
	local splitScreen = (JS.tonum(screenWidth) >= 1024)
	if JS.t(options.forceOneTab) then
		splitScreen = false
	end
	if (player.navTab == "none") then
		splitScreen = true
	end
	JS.setk(tmp.other, "screenWidth", screenWidth)
	JS.setk(tmp.other, "screenHeight", window.innerHeight)
	JS.setk(tmp.other, "splitScreen", splitScreen)
	JS.setk(tmp.other, "lastPoints", player.points)
end
updateOomps = function(this, diff)
	local pp, lp
	JS.setk(tmp.other, "oompsMag", 0)
	if (player.points:lte(JS.D(1e100)) or JS.eq(diff, 0)) then
		do return end
	end
	pp = JS.D(player.points)
	lp = (if JS.t(tmp.other.lastPoints) then tmp.other.lastPoints else JS.D(0))
	if pp:gt(lp) then
		if pp:gte("10^^8") then
			pp = pp:slog(10000000000)
			lp = lp:slog(10000000000)
			JS.setk(tmp.other, "oomps", pp:sub(lp):div(diff))
			JS.setk(tmp.other, "oompsMag", (-1))
		else
			local __g1 = 0
			while ((pp:div(lp):log(10):div(diff):gte("100") and (JS.tonum(tmp.other.oompsMag) <= 5)) and lp:gt(0)) do
				__g1 += 1; if __g1 > 5000000 then JS.runaway() end
				pp = pp:log(10)
				lp = lp:log(10)
				JS.setk(tmp.other, "oomps", pp:sub(lp):div(diff))
				JS.setk(tmp.other, "oompsMag", (JS.tonum(tmp.other.oompsMag) + 1))
			end
		end
	end
end
constructBarStyle = function(this, layer, id)
	local bar = tmp[JS.k(layer)].bars[JS.k(id)]
	local style = JS.O({})
	if JS.instanceof(bar.progress, Decimal) then
		JS.setk(bar, "progress", bar.progress:toNumber())
	end
	JS.setk(bar, "progress", ((1 - Math.min(Math.max(bar.progress, 0), 1)) * 100))
	JS.setk(style, "dims", JS.O({
		width = (JS.str(bar.width) .. "px"),
		height = (JS.str(bar.height) .. "px")
	}, {"width", "height"}))
	local dir = bar.direction
	JS.setk(style, "fillDims", JS.O({
		width = (JS.str(JS.add(bar.width, 0.5)) .. "px"),
		height = (JS.str(JS.add(bar.height, 0.5)) .. "px")
	}, {"width", "height"}))
	do
		local __sw2 = bar.direction
		local __ft3 = false
		repeat
			if __ft3 or JS.eq(__sw2, UP) then
				__ft3 = true
				JS.set(style.fillDims, "clip-path", (("inset(" .. JS.str(bar.progress)) .. "% 0% 0% 0%)"))
				JS.setk(style.fillDims, "width", (JS.str(JS.add(bar.width, 1)) .. "px"))
				break
			end
			if __ft3 or JS.eq(__sw2, DOWN) then
				__ft3 = true
				JS.set(style.fillDims, "clip-path", (("inset(0% 0% " .. JS.str(bar.progress)) .. "% 0%)"))
				JS.setk(style.fillDims, "width", (JS.str(JS.add(bar.width, 1)) .. "px"))
				break
			end
			if __ft3 or JS.eq(__sw2, RIGHT) then
				__ft3 = true
				JS.set(style.fillDims, "clip-path", (("inset(0% " .. JS.str(bar.progress)) .. "% 0% 0%)"))
				break
			end
			if __ft3 or JS.eq(__sw2, LEFT) then
				__ft3 = true
				JS.set(style.fillDims, "clip-path", (("inset(0% 0% 0% " .. JS.str(bar.progress)) .. "%)"))
				break
			end
			if __ft3 or JS.eq(__sw2, DEFAULT) then
				__ft3 = true
				JS.set(style.fillDims, "clip-path", "inset(0% 50% 0% 0%)")
			end
		until true
	end
	if JS.t(bar.instant) then
		JS.set(style.fillDims, "transition-duration", "0s")
	end
	do return style end
end
constructTabFormat = function(this, layer, id, family)
	local tabTemp = nil
	local tabLayer = nil
	local tabFunc = nil
	local location = nil
	local key = nil
	if (id == nil) then
		tabTemp = tmp[JS.k(layer)].tabFormat
		tabLayer = layers[JS.k(layer)].tabFormat
		tabFunc = funcs[JS.k(layer)].tabFormat
		location = tmp[JS.k(layer)]
		key = "tabFormat"
	elseif (family == nil) then
		tabTemp = tmp[JS.k(layer)].tabFormat[JS.k(id)].content
		tabLayer = layers[JS.k(layer)].tabFormat[JS.k(id)].content
		tabFunc = funcs[JS.k(layer)].tabFormat[JS.k(id)].content
		location = tmp[JS.k(layer)].tabFormat[JS.k(id)]
		key = "content"
	else
		tabTemp = tmp[JS.k(layer)].microtabs[JS.k(family)][JS.k(id)].content
		tabLayer = layers[JS.k(layer)].microtabs[JS.k(family)][JS.k(id)].content
		tabFunc = funcs[JS.k(layer)].microtabs[JS.k(family)][JS.k(id)].content
		location = tmp[JS.k(layer)].microtabs[JS.k(family)][JS.k(id)]
		key = "tabFormat"
	end
	if isFunction(nil, tabLayer) then
		do return (JS.m(tabLayer, "bind", location))(nil) end
	end
	updateTempData(nil, tabLayer, tabTemp, tabFunc, JS.O({
		layer = layer,
		id = id,
		family = family
	}, {"layer", "id", "family"}))
	do return tabTemp end
end
updateTabFormats = function(this)
	updateTabFormat(nil, player.tab)
	updateTabFormat(nil, player.navTab)
end
updateTabFormat = function(this, layer)
	if ((function() local __c4 = (layers)[JS.k(layer)]; if JS.isnil(__c4) then return nil end; return (__c4).tabFormat end)() == nil) then
		do return end
	end
	local tab = (function() local __c5 = ((player).subtabs)[JS.k(layer)]; if JS.isnil(__c5) then return nil end; return (__c5).mainTabs end)()
	if isFunction(nil, layers[JS.k(layer)].tabFormat) then
		Vue.set(temp[JS.k(layer)], "tabFormat", layers[JS.k(layer)]:tabFormat())
	elseif Array.isArray(layers[JS.k(layer)].tabFormat) then
		Vue.set(temp[JS.k(layer)], "tabFormat", constructTabFormat(nil, layer))
	elseif isPlainObject(nil, layers[JS.k(layer)].tabFormat) then
		if (layers[JS.k(layer)].tabFormat[JS.k(tab)].embedLayer == nil) then
			Vue.set(temp[JS.k(layer)].tabFormat[JS.k(tab)], "content", constructTabFormat(nil, layer, tab))
		end
	end
	if (isPlainObject(nil, tmp[JS.k(layer)].tabFormat) and (not (tmp[JS.k(layer)].tabFormat[JS.k(tab)].embedLayer == nil))) then
		updateTabFormat(nil, tmp[JS.k(layer)].tabFormat[JS.k(tab)].embedLayer)
	end
	for _, __k6 in JS.keys(layers[JS.k(layer)].microtabs) do
		family = __k6
		tab = player.subtabs[JS.k(layer)][family]
		if JS.t(tmp[JS.k(layer)].microtabs[family][JS.k(tab)]) then
			if JS.t(tmp[JS.k(layer)].microtabs[family][JS.k(tab)].embedLayer) then
				updateTabFormat(nil, tmp[JS.k(layer)].microtabs[family][JS.k(tab)].embedLayer)
			else
				Vue.set(temp[JS.k(layer)].microtabs[family][JS.k(tab)], "content", constructTabFormat(nil, layer, tab, family))
			end
		end
	end
end

end
