// Deterministic bot shared by the JS reference and the Luau port (this file gets transpiled too).
function __canon(x) {
	x = new Decimal(x)
	if (x.lt(1e15)) return "" + x.toNumber().toPrecision(6)
	var l = x.log10()
	if (l.lt(1e15)) return "E" + l.toNumber().toPrecision(6)
	return "EE" + l.log10().toNumber().toPrecision(6)
}
function __botLayers() {
	var out = []
	for (var l in layers) out.push(l)
	out.sort()
	return out
}
function __tick(dt) {
	updateTemp()
	gameLoop(dt)
	fixNaNs()
	var ls = __botLayers()
	for (var i = 0; i < ls.length; i++) {
		var l = ls[i]
		if (!tmp[l].layerShown) continue
		var t = tmp[l]
		if (layers[l].upgrades) {
			for (var id in layers[l].upgrades) {
				if (isPlainObject(layers[l].upgrades[id]) && !hasUpgrade(l, id) && tmp[l].upgrades[id].unlocked && canAffordUpgrade(l, id)) buyUpg(l, id)
			}
		}
		if (layers[l].buyables) {
			for (var id in layers[l].buyables) {
				if (isPlainObject(layers[l].buyables[id])) {
					for (var k = 0; k < 5; k++) { if (tmp[l].buyables[id].unlocked && tmp[l].buyables[id].canBuy) buyBuyable(l, id); else break }
				}
			}
		}
		if (t.type != "none" && t.canReset) {
			if (t.type == "static" || player[l].points.lte(0) || t.resetGain.gte(player[l].points)) doReset(l)
		}
	}
}
function __snap(i) {
	var s = "t" + i + " pts=" + __canon(player.points)
	var ls = __botLayers()
	for (var j = 0; j < ls.length; j++) {
		var l = ls[j]
		if (player[l] && player[l].points instanceof Decimal && tmp[l].layerShown) s = s + " " + l + "=" + __canon(player[l].points) + "/u" + player[l].upgrades.length
	}
	return s
}
