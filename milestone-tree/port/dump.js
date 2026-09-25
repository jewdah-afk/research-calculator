// Deterministic dump of player + tmp for JS-vs-Luau comparison (transpiled to Luau too, so both walk identically).
function __dv(x) {
	if (x instanceof Decimal) {
		var s = x.sign
		if (s == 0) return "D0"
		if (isNaN(s)) return "DNaN"
		var a = x.abs()
		if (a.gte(Decimal.dInf)) return "D" + s + ":inf"
		if (a.lt(1e15)) return "D" + s + ":0:" + a.toNumber()
		var l = a.log10()
		if (l.lt(1e15)) return "D" + s + ":1:" + l.toNumber()
		var ll = l.log10()
		if (ll.lt(1e15)) return "D" + s + ":2:" + ll.toNumber()
		return "D" + s + ":3:" + ll.log10().toNumber()
	}
	if (typeof x == "number") return "N" + x
	if (typeof x == "string") return "S" + x
	if (typeof x == "boolean") return "B" + x
	return null
}
function __dump(x, path, out, depth) {
	if (depth > 12) return
	if (x === undefined || x === null) { out.push(path + "=nil"); return }
	var v = __dv(x)
	if (v !== null) { out.push(path + "=" + v); return }
	if (typeof x == "function") return
	if (Array.isArray(x)) {
		out.push(path + "#" + x.length)
		for (var i = 0; i < x.length; i++) __dump(x[i], path + "[" + i + "]", out, depth + 1)
		return
	}
	if (typeof x == "object") {
		var ks = []
		for (var k in x) ks.push("" + k)
		ks.sort()
		for (var j = 0; j < ks.length; j++) {
			var kk = ks[j]
			if (kk == "tabFormat" || kk == "content" || kk == "grid" && path == "tmp.cp") continue
			__dump(x[kk], path + "." + kk, out, depth + 1)
		}
	}
}
function __dumpAll(tag) {
	var out = []
	__dump(player, "player", out, 0)
	var ls = []
	for (var l in layers) ls.push(l)
	ls.sort()
	for (var i = 0; i < ls.length; i++) __dump(tmp[ls[i]], "tmp." + ls[i], out, 0)
	__dump(tmp.pointGen, "tmp.pointGen", out, 0)
	return "##" + tag + "\n" + out.join("\n")
}
// scripted actions shared by both engines: [kind, layer, id]
function __act(list) {
	for (var i = 0; i < list.length; i++) {
		var a = list[i]
		var kind = a[0], l = a[1], id = a[2]
		if (kind == "tick") { updateTemp(); gameLoop(id); fixNaNs() }
		else if (kind == "reset") { updateTemp(); if (tmp[l].canReset) doReset(l) }
		else if (kind == "forcereset") { updateTemp(); doReset(l, true) }
		else if (kind == "upg") { updateTemp(); buyUpg(l, id) }
		else if (kind == "buy") { updateTemp(); buyBuyable(l, id) }
		else if (kind == "chal") { updateTemp(); startChallenge(l, id) }
		else if (kind == "click") { updateTemp(); if (tmp[l].clickables[id] && tmp[l].clickables[id].unlocked && tmp[l].clickables[id].canClick) clickClickable(l, id) }
	}
	updateTemp()
}
