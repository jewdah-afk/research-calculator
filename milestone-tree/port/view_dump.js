// Shared by the JS and Luau view tests (transpiled too): walk every tab and dump its view as JSON; replay actions.
function rbx_viewDump(tag) {
	var out = []
	var tabs = ["none", "options-tab"]
	for (var l in layers) if (tmp[l].layerShown == true && l != "tree-tab") tabs.push(l)
	for (var i = 0; i < tabs.length; i++) {
		rbx_do(["tab", tabs[i]])
		var subs = [null]
		var t = tmp[tabs[i]]
		if (t && t.tabFormat && !Array.isArray(t.tabFormat)) subs = Object.keys(t.tabFormat)
		for (var j = 0; j < subs.length; j++) {
			if (subs[j] !== null) rbx_do(["subtab", tabs[i], "mainTabs", subs[j]])
			out.push("##" + tag + " " + tabs[i] + " " + subs[j] + "\n" + JSON.stringify(rbx_view()))
		}
	}
	// inside the Prestige Multiverse (mp challenge 21): its own layers and the map's other half (saves already inside
	// were dumped there above)
	if (player.m.best.gte(185) && player.mp.activeChallenge != 21) {
		player.mp.unlocked = true
		rbx_do(["chal", "mp", 21])
		player.time -= 50
		rbx_tick()
		var mv = []
		for (var l in layers) if (tmp[l].layerShown == true && l != "tree-tab") mv.push(l)
		for (var k = 0; k < mv.length; k++) {
			rbx_do(["tab", mv[k]])
			out.push("##" + tag + " mv " + mv[k] + "\n" + JSON.stringify(rbx_view()))
		}
		rbx_do(["tab", "none"])
		out.push("##" + tag + " mv none\n" + JSON.stringify(rbx_view()) + "\n" + JSON.stringify(rbx_popups(0)))
	}
	return out.join("\n")
}
// the fuzz actions ([kind, layer, id]) as button presses and ticks, then the view of the last layer touched
function rbx_viewActs(tag, acts) {
	var last = "m"
	for (var i = 0; i < acts.length; i++) {
		var a = acts[i]
		if (a[0] == "tick") { player.time -= a[2] * 1000; rbx_tick() }
		else {
			rbx_do(["tab", a[1]])
			rbx_view()
			if (a[0] == "reset") rbx_do(["reset", a[1]])
			else if (a[0] == "upg") rbx_do(["upg", a[1], a[2]])
			else if (a[0] == "buy") rbx_do(["buy", a[1], a[2]])
			else if (a[0] == "chal") rbx_do(["chal", a[1], a[2]])
			else if (a[0] == "click") rbx_do(["click", a[1], a[2]])
		}
		last = a[1]
	}
	rbx_do(["tab", last])
	return "##" + tag + " acts " + last + "\n" + JSON.stringify(rbx_view()) + "\n" + JSON.stringify(rbx_popups(0))
}
