--!nocheck
-- transpiled from technical/layerSupport.js by port/build.js: do not edit
return function()
-- transpiled from technical/layerSupport.js
layerShown = function(this, layer)
	do return tmp[JS.k(layer)].layerShown end
end
updateHotkeys = function(this)
	hotkeys = JS.O({})
	for _, __k1 in JS.keys(layers) do
		layer = __k1
		hk = layers[layer].hotkeys
		if JS.t(hk) then
			for _, __k2 in JS.keys(hk) do
				id = __k2
				JS.set(hotkeys, JS.k(hk[id].key), hk[id])
				JS.setk(hotkeys[JS.k(hk[id].key)], "layer", layer)
				JS.setk(hotkeys[JS.k(hk[id].key)], "id", id)
				if (hk[id].unlocked == nil) then
					JS.setk(hk[id], "unlocked", true)
				end
			end
		end
	end
end
updateLayers = function(this)
	LAYERS = Object.keys(layers)
	ROW_LAYERS = JS.O({})
	TREE_LAYERS = JS.O({})
	OTHER_LAYERS = JS.O({})
	for _, __k3 in JS.keys(layers) do
		layer = __k3
		setupLayer(nil, layer)
	end
	for _, __k4 in JS.keys(OTHER_LAYERS) do
		row = __k4
		JS.m(OTHER_LAYERS[row], "sort", function(_, a, b)
			do return (if JS.cmp(a.position, ">", b.position) then 1 else (-1)) end
		end)
		for _, __k5 in JS.keys(OTHER_LAYERS[row]) do
			layer = __k5
			JS.set(OTHER_LAYERS[row], layer, OTHER_LAYERS[row][layer].layer)
		end
	end
	for _, __k6 in JS.keys(TREE_LAYERS) do
		row = __k6
		JS.m(TREE_LAYERS[row], "sort", function(_, a, b)
			do return (if JS.cmp(a.position, ">", b.position) then 1 else (-1)) end
		end)
		for _, __k7 in JS.keys(TREE_LAYERS[row]) do
			layer = __k7
			JS.set(TREE_LAYERS[row], layer, TREE_LAYERS[row][layer].layer)
		end
	end
	local treeLayers2 = JS.A(0)
	for x = 0, JS.cap(0, (JS.tonum(JS.add(maxRow, 1))) - 1, 1) do
		if JS.t(TREE_LAYERS[JS.k(x)]) then
			JS.m(treeLayers2, "push", TREE_LAYERS[JS.k(x)])
		end
	end
	TREE_LAYERS = treeLayers2
	updateHotkeys(nil)
end
setupLayer = function(this, layer)
	JS.setk(layers[JS.k(layer)], "layer", layer)
	if JS.t(layers[JS.k(layer)].upgrades) then
		setRowCol(nil, layers[JS.k(layer)].upgrades)
		for _, __k8 in JS.keys(layers[JS.k(layer)].upgrades) do
			thing = __k8
			if isPlainObject(nil, layers[JS.k(layer)].upgrades[thing]) then
				JS.setk(layers[JS.k(layer)].upgrades[thing], "id", thing)
				JS.setk(layers[JS.k(layer)].upgrades[thing], "layer", layer)
				if (layers[JS.k(layer)].upgrades[thing].unlocked == nil) then
					JS.setk(layers[JS.k(layer)].upgrades[thing], "unlocked", true)
				end
			end
		end
	end
	if JS.t(layers[JS.k(layer)].milestones) then
		for _, __k9 in JS.keys(layers[JS.k(layer)].milestones) do
			thing = __k9
			if isPlainObject(nil, layers[JS.k(layer)].milestones[thing]) then
				JS.setk(layers[JS.k(layer)].milestones[thing], "id", thing)
				JS.setk(layers[JS.k(layer)].milestones[thing], "layer", layer)
				if (layers[JS.k(layer)].milestones[thing].unlocked == nil) then
					JS.setk(layers[JS.k(layer)].milestones[thing], "unlocked", true)
				end
			end
		end
	end
	if JS.t(layers[JS.k(layer)].achievements) then
		setRowCol(nil, layers[JS.k(layer)].achievements)
		for _, __k10 in JS.keys(layers[JS.k(layer)].achievements) do
			thing = __k10
			if isPlainObject(nil, layers[JS.k(layer)].achievements[thing]) then
				JS.setk(layers[JS.k(layer)].achievements[thing], "id", thing)
				JS.setk(layers[JS.k(layer)].achievements[thing], "layer", layer)
				if (layers[JS.k(layer)].achievements[thing].unlocked == nil) then
					JS.setk(layers[JS.k(layer)].achievements[thing], "unlocked", true)
				end
			end
		end
	end
	if JS.t(layers[JS.k(layer)].challenges) then
		setRowCol(nil, layers[JS.k(layer)].challenges)
		for _, __k11 in JS.keys(layers[JS.k(layer)].challenges) do
			thing = __k11
			if isPlainObject(nil, layers[JS.k(layer)].challenges[thing]) then
				JS.setk(layers[JS.k(layer)].challenges[thing], "id", thing)
				JS.setk(layers[JS.k(layer)].challenges[thing], "layer", layer)
				if (layers[JS.k(layer)].challenges[thing].unlocked == nil) then
					JS.setk(layers[JS.k(layer)].challenges[thing], "unlocked", true)
				end
				if (layers[JS.k(layer)].challenges[thing].completionLimit == nil) then
					JS.setk(layers[JS.k(layer)].challenges[thing], "completionLimit", 1)
				elseif (layers[JS.k(layer)].challenges[thing].marked == nil) then
					JS.setk(layers[JS.k(layer)].challenges[thing], "marked", function(this)
						do return maxedChallenge(nil, this.layer, this.id) end
					end)
				end
			end
		end
	end
	if JS.t(layers[JS.k(layer)].buyables) then
		JS.setk(layers[JS.k(layer)].buyables, "layer", layer)
		setRowCol(nil, layers[JS.k(layer)].buyables)
		for _, __k12 in JS.keys(layers[JS.k(layer)].buyables) do
			thing = __k12
			if isPlainObject(nil, layers[JS.k(layer)].buyables[thing]) then
				JS.setk(layers[JS.k(layer)].buyables[thing], "id", thing)
				JS.setk(layers[JS.k(layer)].buyables[thing], "layer", layer)
				if (layers[JS.k(layer)].buyables[thing].unlocked == nil) then
					JS.setk(layers[JS.k(layer)].buyables[thing], "unlocked", true)
				end
				JS.setk(layers[JS.k(layer)].buyables[thing], "canBuy", function(this)
					do return canBuyBuyable(nil, this.layer, this.id) end
				end)
				if (layers[JS.k(layer)].buyables[thing].purchaseLimit == nil) then
					JS.setk(layers[JS.k(layer)].buyables[thing], "purchaseLimit", JS.D(math.huge))
				end
			end
		end
	end
	if JS.t(layers[JS.k(layer)].clickables) then
		JS.setk(layers[JS.k(layer)].clickables, "layer", layer)
		setRowCol(nil, layers[JS.k(layer)].clickables)
		for _, __k13 in JS.keys(layers[JS.k(layer)].clickables) do
			thing = __k13
			if isPlainObject(nil, layers[JS.k(layer)].clickables[thing]) then
				JS.setk(layers[JS.k(layer)].clickables[thing], "id", thing)
				JS.setk(layers[JS.k(layer)].clickables[thing], "layer", layer)
				if (layers[JS.k(layer)].clickables[thing].unlocked == nil) then
					JS.setk(layers[JS.k(layer)].clickables[thing], "unlocked", true)
				end
			end
		end
	end
	if JS.t(layers[JS.k(layer)].bars) then
		JS.setk(layers[JS.k(layer)].bars, "layer", layer)
		for _, __k14 in JS.keys(layers[JS.k(layer)].bars) do
			thing = __k14
			JS.setk(layers[JS.k(layer)].bars[thing], "id", thing)
			JS.setk(layers[JS.k(layer)].bars[thing], "layer", layer)
			if (layers[JS.k(layer)].bars[thing].unlocked == nil) then
				JS.setk(layers[JS.k(layer)].bars[thing], "unlocked", true)
			end
		end
	end
	if JS.t(layers[JS.k(layer)].infoboxes) then
		for _, __k15 in JS.keys(layers[JS.k(layer)].infoboxes) do
			thing = __k15
			JS.setk(layers[JS.k(layer)].infoboxes[thing], "id", thing)
			JS.setk(layers[JS.k(layer)].infoboxes[thing], "layer", layer)
			if (layers[JS.k(layer)].infoboxes[thing].unlocked == nil) then
				JS.setk(layers[JS.k(layer)].infoboxes[thing], "unlocked", true)
			end
		end
	end
	if JS.t(layers[JS.k(layer)].grid) then
		JS.setk(layers[JS.k(layer)].grid, "layer", layer)
		if (layers[JS.k(layer)].grid.getUnlocked == nil) then
			JS.setk(layers[JS.k(layer)].grid, "getUnlocked", true)
		end
		if (layers[JS.k(layer)].grid.getCanClick == nil) then
			JS.setk(layers[JS.k(layer)].grid, "getCanClick", true)
		end
	end
	if JS.t(layers[JS.k(layer)].startData) then
		data = layers[JS.k(layer)]:startData()
		if ((not (data.best == nil)) and (data.showBest == nil)) then
			JS.setk(layers[JS.k(layer)], "showBest", true)
		end
		if ((not (data.total == nil)) and (data.showTotal == nil)) then
			JS.setk(layers[JS.k(layer)], "showTotal", true)
		end
	end
	if (not JS.t(layers[JS.k(layer)].componentStyles)) then
		JS.setk(layers[JS.k(layer)], "componentStyles", JS.O({}))
	end
	if (layers[JS.k(layer)].symbol == nil) then
		JS.setk(layers[JS.k(layer)], "symbol", (JS.str(JS.m(JS.m(layer, "charAt", 0), "toUpperCase")) .. JS.str(JS.m(layer, "slice", 1))))
	end
	if (layers[JS.k(layer)].unlockOrder == nil) then
		JS.setk(layers[JS.k(layer)], "unlockOrder", JS.A(0))
	end
	if (layers[JS.k(layer)].gainMult == nil) then
		JS.setk(layers[JS.k(layer)], "gainMult", decimalOne)
	end
	if (layers[JS.k(layer)].gainExp == nil) then
		JS.setk(layers[JS.k(layer)], "gainExp", decimalOne)
	end
	if (layers[JS.k(layer)].directMult == nil) then
		JS.setk(layers[JS.k(layer)], "directMult", decimalOne)
	end
	if (layers[JS.k(layer)].type == nil) then
		JS.setk(layers[JS.k(layer)], "type", "none")
	end
	if ((layers[JS.k(layer)].base == nil) or (JS.tonum(layers[JS.k(layer)].base) <= 1)) then
		JS.setk(layers[JS.k(layer)], "base", 2)
	end
	if (layers[JS.k(layer)].softcap == nil) then
		JS.setk(layers[JS.k(layer)], "softcap", JS.D("e1e7"))
	end
	if (layers[JS.k(layer)].softcapPower == nil) then
		JS.setk(layers[JS.k(layer)], "softcapPower", JS.D("0.5"))
	end
	if (layers[JS.k(layer)].displayRow == nil) then
		JS.setk(layers[JS.k(layer)], "displayRow", layers[JS.k(layer)].row)
	end
	if (layers[JS.k(layer)].name == nil) then
		JS.setk(layers[JS.k(layer)], "name", layer)
	end
	if (layers[JS.k(layer)].layerShown == nil) then
		JS.setk(layers[JS.k(layer)], "layerShown", true)
	end
	if (layers[JS.k(layer)].glowColor == nil) then
		JS.setk(layers[JS.k(layer)], "glowColor", defaultGlow)
	end
	local row = layers[JS.k(layer)].row
	local displayRow = layers[JS.k(layer)].displayRow
	if (not JS.t(ROW_LAYERS[JS.k(row)])) then
		JS.set(ROW_LAYERS, JS.k(row), JS.O({}))
	end
	if ((not JS.t(TREE_LAYERS[JS.k(displayRow)])) and (not isNaN(nil, displayRow))) then
		JS.set(TREE_LAYERS, JS.k(displayRow), JS.A(0))
	end
	if ((not JS.t(OTHER_LAYERS[JS.k(displayRow)])) and isNaN(nil, displayRow)) then
		JS.set(OTHER_LAYERS, JS.k(displayRow), JS.A(0))
	end
	JS.set(ROW_LAYERS[JS.k(row)], JS.k(layer), layer)
	local position = (if (not (layers[JS.k(layer)].position == nil)) then layers[JS.k(layer)].position else layer)
	if ((not isNaN(nil, displayRow)) or (JS.tonum(displayRow) < 0)) then
		JS.m(TREE_LAYERS[JS.k(displayRow)], "push", JS.O({
			layer = layer,
			position = position
		}, {"layer", "position"}))
	else
		JS.m(OTHER_LAYERS[JS.k(displayRow)], "push", JS.O({
			layer = layer,
			position = position
		}, {"layer", "position"}))
	end
	if JS.cmp(maxRow, "<", layers[JS.k(layer)].displayRow) then
		maxRow = layers[JS.k(layer)].displayRow
	end
end
addLayer = function(this, layerName, layerData, tabLayers)
	if tabLayers == nil then tabLayers = JS.NULL end
	JS.set(layers, JS.k(layerName), layerData)
	JS.setk(layers[JS.k(layerName)], "isLayer", true)
	if (not (tabLayers == JS.NULL)) then
		local format = JS.O({})
		for _, __k16 in JS.keys(tabLayers) do
			id = __k16
			layer = tabLayers[id]
			JS.set(format, JS.k((if JS.t(layers[JS.k(layer)].name) then layers[JS.k(layer)].name else layer)), JS.O({
				embedLayer = layer,
				buttonStyle = function(this)
				if (not JS.t(tmp[JS.k(this.embedLayer)].nodeStyle)) then
					do return JS.O({
						["border-color"] = tmp[JS.k(this.embedLayer)].color
					}) end
				else
					style = tmp[JS.k(this.embedLayer)].nodeStyle
					if (style["border-color"] == nil) then
						JS.set(style, "border-color", tmp[JS.k(this.embedLayer)].color)
					end
					do return style end
				end
			end,
				unlocked = function(this)
				do return tmp[JS.k(this.embedLayer)].layerShown end
			end
			}, {"embedLayer", "buttonStyle", "unlocked"}))
		end
		JS.setk(layers[JS.k(layerName)], "tabFormat", format)
	end
end
addNode = function(this, layerName, layerData)
	JS.set(layers, JS.k(layerName), layerData)
	JS.setk(layers[JS.k(layerName)], "isLayer", false)
end
readData = function(this, data, args)
	if args == nil then args = JS.NULL end
	if ((((not (not JS.t(data))) and JS.t(JS.get(data, "constructor"))) and JS.t(JS.get(data, "call"))) and JS.t(JS.get(data, "apply"))) then
		do return data(nil, args) end
	else
		do return data end
	end
end
setRowCol = function(this, upgrades)
	if (JS.t(upgrades.rows) and JS.t(upgrades.cols)) then
		do return end
	end
	local maxRow = 0
	local maxCol = 0
	for _, __k17 in JS.keys(upgrades) do
		up = __k17
		if (not isNaN(nil, up)) then
			if (Math.floor((JS.tonum(up) / 10)) > JS.tonum(maxRow)) then
				maxRow = Math.floor((JS.tonum(up) / 10))
			end
			if (math.fmod(JS.tonum(up), 10) > JS.tonum(maxCol)) then
				maxCol = math.fmod(JS.tonum(up), 10)
			end
		end
	end
	JS.setk(upgrades, "rows", maxRow)
	JS.setk(upgrades, "cols", maxCol)
end
someLayerUnlocked = function(this, row)
	for _, __k18 in JS.keys(ROW_LAYERS[JS.k(row)]) do
		layer = __k18
		if JS.t(player[layer].unlocked) then
			do return true end
		end
	end
	do return false end
end
layers = JS.O({})
decimalZero = JS.D(0)
decimalOne = JS.D(1)
decimalNaN = JS.D((0/0))
defaultGlow = "#ff0000"
LAYERS = Object.keys(layers)
hotkeys = JS.O({})
maxRow = 0
ROW_LAYERS = JS.O({})
TREE_LAYERS = JS.O({})
OTHER_LAYERS = JS.O({})
UP = 0
DOWN = 1
LEFT = 2
RIGHT = 3
addLayer(nil, "info-tab", JS.O({
	tabFormat = JS.A(1, "info-tab"),
	row = "otherside"
}, {"tabFormat", "row"}))
addLayer(nil, "options-tab", JS.O({
	tabFormat = JS.A(1, "options-tab"),
	row = "otherside"
}, {"tabFormat", "row"}))
addLayer(nil, "changelog-tab", JS.O({
	tabFormat = function(this)
	do return JS.A(1, JS.A(2, "raw-html", modInfo.changelog)) end
end,
	row = "otherside"
}, {"tabFormat", "row"}))

end
