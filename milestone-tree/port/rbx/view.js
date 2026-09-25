// Roblox front end, game side: builds what the web page would draw, as plain view nodes, from inside a player's game
// instance. It is transpiled to Luau with the game (so the JS and Luau builds can be diffed like the game itself) and
// mirrors TMT's Vue components (loader_v.js, components.js) and the NG+ page (menu, overlay head), minus the browser.
//
// A node is { t: type, ... }. Containers have c (children). Anything the player can press has a (the action, an
// array the server re-checks against the actions on screen before it runs one). HTML strings stay HTML (h); the
// client turns them into RichText. st is a flat CSS object ({ "background-color": "#77bf5f", ... }).
//   col / row          c
//   html               h
//   blank              w, hh
//   hr                 w
//   btn                k (kind: upg buy click chal reset tab sub toggle perk malware respec master sell grid menu opt),
//                      cls (can / locked / bought / perk / perked / pseudo / plocked / ...), h, st, tip, n (upgrade number)
//   ms                 milestone: done, h, st, tip, c (toggle / malware buttons)
//   chal               challenge: cls, st, c (name, button, text)
//   ach                achievement: done, h, st, tip, num
//   info               infobox: title, body, shut, color, st, a
//   bar                w, hh, p (0..1), dir, h, st, fill, base
//   tabs               c (tab buttons)

var rbx_actions = []
function rbx_act(a) { rbx_actions.push(a); return a }

function rbx_cssInto(out, s) {
	if (s === undefined || s === null || s === false || s === "" || s === true) return
	if (Array.isArray(s)) {
		for (var i = 0; i < s.length; i++) rbx_cssInto(out, s[i])
		return
	}
	if (typeof s != "object" || s instanceof Decimal) return
	for (var k in s) {
		var v = s[k]
		if (v !== undefined && v !== null && typeof v != "function") out[k] = "" + v
	}
}
function rbx_css(list) {
	var out = {}
	rbx_cssInto(out, list)
	return out
}
// a value TMT evaluates when it draws: display functions are left out of updateTemp (see boot.js), so tmp still
// holds the function itself and the component runs it with the definition as `this`
function rbx_v(t, L, key) {
	var v = t[key]
	if (typeof v == "function") return run(L[key], L)
	return v
}
function rbx_str(x) {
	if (x === undefined || x === null) return ""
	return "" + x
}
function rbx_err(what, e) {
	return { t: "html", h: "<span style='color: #ff5050'>[" + what + " failed: " + rbx_str(e) + "]</span>" }
}

// ------------------------------------------------------------------------------------------------ layer components
function rbx_mainDisplay(layer, data) {
	var c = tmp[layer].color
	var h = player[layer].points.lt("1e1000") ? "You have " : ""
	h += "<h2 style=\"color: " + c + "; text-shadow: 0px 0px 10px " + c + "\">" + (data ? format(player[layer].points, data) : formatWhole(player[layer].points)) + "</h2> "
	h += rbx_str(tmp[layer].resource)
	if (layers[layer].effectDescription) h += ", " + run(layers[layer].effectDescription, layers[layer])
	return { t: "html", h: h + "<br><br>" }
}

function rbx_prestigeButton(layer) {
	if (tmp[layer].type === "none") return null
	var can = tmp[layer].canReset
	return {
		t: "btn", k: "reset", cls: can ? "can" : "locked", h: prestigeButtonText(layer), a: rbx_act(["reset", layer]),
		st: rbx_css([can ? { "background-color": tmp[layer].color } : null, tmp[layer].componentStyles["prestige-button"]]),
	}
}

function rbx_resourceDisplay(layer) {
	var t = tmp[layer]
	var h = ""
	if (t.baseAmount) h += "<br>You have " + formatWhole(t.baseAmount) + " " + rbx_str(t.baseResource)
	if (t.passiveGeneration) h += "<br>You are gaining " + format(t.resetGain.times(t.passiveGeneration)) + " " + rbx_str(t.resource) + " per second"
	h += "<br><br>"
	if (t.showBest) h += "Your best " + rbx_str(t.resource) + " is " + formatWhole(player[layer].best) + "<br>"
	if (t.showTotal) h += "You have made a total of " + formatWhole(player[layer].total) + " " + rbx_str(t.resource) + "<br>"
	return { t: "html", h: h }
}

function rbx_upgrade(layer, id) {
	var t = tmp[layer].upgrades[id]
	var L = layers[layer].upgrades[id]
	if (t === undefined) return null
	if (perkUnl(layer, id) && !t.unlocked) {
		return {
			t: "btn", k: "perk", cls: t.perkCan ? "perk" : "perked", a: rbx_act(["perk", layer, id]),
			h: "<h3>Explore A New Perk Upgrade</h3><br>" + rbx_str(rbx_v(t, L, "perkReq")),
		}
	}
	if (!t.unlocked) return null
	var bought = hasUpgrade(layer, id)
	var can = canAffordUpgrade(layer, id) && !bought
	var h = ""
	if (L.fullDisplay) h = rbx_str(run(L.fullDisplay, L))
	else {
		var title = rbx_v(t, L, "title")
		if (title) h += "<h3>" + title + "</h3><br>"
		h += rbx_str(rbx_v(t, L, "description"))
		if (L.effectDisplay) h += "<br>Currently: " + run(L.effectDisplay, L)
		h += "<br>"
		var cd = rbx_v(t, L, "costDescription")
		if (cd) h += cd
		else {
			var cur = rbx_v(t, L, "currencyDisplayName")
			h += "Cost: " + formatWhole(t.cost) + " " + rbx_str(cur ? cur : tmp[layer].resource)
		}
	}
	return {
		t: "btn", k: "upg", cls: bought ? "bought" : (can ? "can" : "locked"), n: L.fullDisplay ? null : id, h: h,
		a: rbx_act(["upg", layer, id]), tip: rbx_v(t, L, "tooltip"),
		st: rbx_css([can ? { "background-color": tmp[layer].color } : null, tmp[layer].componentStyles.upgrade, rbx_v(t, L, "style")]),
	}
}

function rbx_upgrades(layer) {
	var t = tmp[layer].upgrades
	if (!t) return null
	var rows = []
	for (var r = 1; r <= t.rows; r++) {
		var row = []
		for (var c = 1; c <= t.cols; c++) {
			var id = r * 10 + c
			if (t[id] !== undefined) {
				var u = rbx_upgrade(layer, id)
				if (u) row.push(u)
			}
		}
		if (row.length) rows.push({ t: "row", c: row })
	}
	return { t: "col", c: rows }
}

function rbx_toggle(toggle) {
	return {
		t: "btn", k: "toggle", cls: "can", h: player[toggle[0]][toggle[1]] ? "ON" : "OFF",
		a: rbx_act(["toggle", toggle[0], toggle[1]]), st: { "background-color": rbx_str(tmp[toggle[0]].color) },
	}
}

function rbx_milestone(layer, id) {
	var t = tmp[layer].milestones[id]
	var L = layers[layer].milestones[id]
	if (!(t !== undefined && milestoneShown(layer, id) && t.unlocked)) return null
	var done = hasMilestone(layer, id)
	var h = "<h3>" + rbx_str(rbx_v(t, L, "requirementDescription")) + "</h3><br>" + rbx_str(run(L.effectDescription, L)) + "<br>"
	var kids = []
	if (t.pseudoUnl == true && !player[layer].pseudoBuys.includes(id)) {
		var plocked = !player.points.gte(t.pseudoCost)
		kids.push({
			t: "btn", k: "malware", cls: plocked ? "plocked" : "pseudo", a: rbx_act(["malware", layer, id]),
			h: "Infect a Milestone with Malware<br>Cost: " + format(t.pseudoCost) + " points.",
		})
	}
	if (t.toggles && done) {
		for (var i = 0; i < t.toggles.length; i++) kids.push(rbx_toggle(t.toggles[i]))
	}
	return {
		t: "ms", done: done, h: h, c: kids, tip: rbx_v(t, L, "tooltip"),
		st: rbx_css([tmp[layer].componentStyles.milestone, rbx_v(t, L, "style")]),
	}
}

function rbx_milestones(layer, data) {
	if (!tmp[layer].milestones) return null
	var ids = data
	if (data === undefined) {
		ids = Object.keys(tmp[layer].milestones)
		if (options.reverseMilestones == true) ids = ids.reverse()
	}
	var out = []
	for (var i = 0; i < ids.length; i++) {
		var id = ids[i]
		if (tmp[layer].milestones[id] !== undefined && tmp[layer].milestones[id].unlocked && milestoneShown(layer, id)) {
			var m = rbx_milestone(layer, id)
			if (m) out.push(m)
		}
	}
	return { t: "col", c: out }
}

function rbx_buyable(layer, id) {
	var t = tmp[layer].buyables[id]
	var L = layers[layer].buyables[id]
	if (!(t !== undefined && t.unlocked)) return null
	var cls = t.canBuy ? "can" : "locked"
	if (player[layer].buyables[id].gte(t.purchaseLimit)) cls = "bought"
	var h = ""
	var title = rbx_v(t, L, "title")
	if (title) h += "<h2>" + title + "</h2><br>"
	h += rbx_str(run(L.display, L))
	var node = {
		t: "btn", k: "buy", cls: cls, h: h, a: rbx_act(["buy", layer, id]), tip: rbx_v(t, L, "tooltip"), hold: true,
		st: rbx_css([t.canBuy ? { "background-color": tmp[layer].color } : null, tmp[layer].componentStyles.buyable, rbx_v(t, L, "style")]),
	}
	var sellOne = t.sellOne && !(t.canSellOne !== undefined && t.canSellOne == false)
	var sellAll = t.sellAll && !(t.canSellAll !== undefined && t.canSellAll == false)
	if (!sellOne && !sellAll) return node
	var kids = [node]
	var cls2 = player[layer].unlocked ? "can" : "locked"
	if (sellOne) kids.push({ t: "btn", k: "sell", cls: cls2, h: tmp[layer].buyables.sellOneText ? tmp[layer].buyables.sellOneText : "Sell One", a: rbx_act(["sellOne", layer, id]) })
	if (sellAll) kids.push({ t: "btn", k: "sell", cls: cls2, h: tmp[layer].buyables.sellAllText ? tmp[layer].buyables.sellAllText : "Sell All", a: rbx_act(["sellAll", layer, id]) })
	return { t: "col", c: kids }
}

function rbx_rowsOf(t, data) {
	var rows = data === undefined ? t.rows : data
	var out = []
	if (Array.isArray(rows)) { for (var i = 0; i < rows.length; i++) out.push(rows[i]) }
	else { for (var r = 1; r <= rows; r++) out.push(r) }
	return out
}

function rbx_buyables(layer, data) {
	var t = tmp[layer].buyables
	if (!t) return null
	var out = []
	if (t.respec && !(t.showRespec !== undefined && t.showRespec == false)) {
		out.push({
			t: "btn", k: "respec", cls: player[layer].unlocked ? "can" : "locked", a: rbx_act(["respec", layer]),
			h: t.respecText ? t.respecText : "Respec", st: rbx_css([tmp[layer].componentStyles["respec-button"]]),
		})
	}
	var rows = rbx_rowsOf(t, data)
	for (var i = 0; i < rows.length; i++) {
		var row = []
		for (var c = 1; c <= t.cols; c++) {
			var id = rows[i] * 10 + c
			if (t[id] !== undefined && t[id].unlocked) {
				var b = rbx_buyable(layer, id)
				if (b) row.push(b)
			}
		}
		if (row.length) out.push({ t: "row", c: row })
	}
	return { t: "col", c: out }
}

function rbx_clickable(layer, id) {
	var t = tmp[layer].clickables[id]
	var L = layers[layer].clickables[id]
	if (!(t !== undefined && t.unlocked)) return null
	var h = ""
	var title = rbx_v(t, L, "title")
	if (title) h += "<h2>" + title + "</h2><br>"
	h += rbx_str(run(L.display, L))
	return {
		t: "btn", k: "click", cls: t.canClick ? "can" : "locked", h: h, a: rbx_act(["click", layer, id]), tip: rbx_v(t, L, "tooltip"),
		hold: L.onHold ? true : null,
		st: rbx_css([t.canClick ? { "background-color": tmp[layer].color } : null, tmp[layer].componentStyles.clickable, rbx_v(t, L, "style")]),
	}
}

function rbx_clickables(layer, data) {
	var t = tmp[layer].clickables
	if (!t) return null
	var out = []
	if (t.masterButtonPress && !(t.showMasterButton !== undefined && t.showMasterButton == false)) {
		out.push({
			t: "btn", k: "master", cls: player[layer].unlocked ? "can" : "locked", a: rbx_act(["master", layer]),
			h: t.masterButtonText ? t.masterButtonText : "Click me!", st: rbx_css([tmp[layer].componentStyles["master-button"]]),
		})
	}
	var rows = rbx_rowsOf(t, data)
	for (var i = 0; i < rows.length; i++) {
		var row = []
		for (var c = 1; c <= t.cols; c++) {
			var id = rows[i] * 10 + c
			if (t[id] !== undefined && t[id].unlocked) {
				var b = rbx_clickable(layer, id)
				if (b) row.push(b)
			}
		}
		if (row.length) out.push({ t: "row", c: row })
	}
	return { t: "col", c: out }
}

function rbx_challenge(layer, id) {
	var t = tmp[layer].challenges[id]
	var L = layers[layer].challenges[id]
	if (!(t !== undefined && t.unlocked && !(options.hideChallenges && maxedChallenge(layer, id) && !inChallenge(layer, id)))) return null
	var cls = challengeStyle(layer, id)
	var btn = {
		t: "btn", k: "chalbtn", cls: "can", h: challengeButtonText(layer, id), a: rbx_act(["chal", layer, id]),
		st: rbx_css([rbx_v(t, L, "buttonStyle") ? rbx_v(t, L, "buttonStyle") : { "background-color": tmp[layer].color }]),
	}
	var body = ""
	if (L.fullDisplay) body = rbx_str(run(L.fullDisplay, L))
	else {
		body = rbx_str(rbx_v(t, L, "challengeDescription")) + "<br>Goal:  "
		var gd = rbx_v(t, L, "goalDescription")
		if (gd) body += gd
		else {
			var cur = rbx_v(t, L, "currencyDisplayName")
			body += format(t.goal) + " " + rbx_str(cur ? cur : modInfo.pointsName)
		}
		body += "<br>Reward: " + rbx_str(rbx_v(t, L, "rewardDescription")) + "<br>"
		if (L.rewardDisplay !== undefined) body += "Currently: " + (t.rewardDisplay ? run(L.rewardDisplay, L) : format(t.rewardEffect))
	}
	return {
		t: "chal", cls: cls, active: player[layer].activeChallenge === id, st: rbx_css([tmp[layer].componentStyles.challenge, rbx_v(t, L, "style")]),
		c: [{ t: "html", h: "<h3>" + rbx_str(rbx_v(t, L, "name")) + "</h3>" }, btn, { t: "html", h: body }],
	}
}

function rbx_challenges(layer, data) {
	var t = tmp[layer].challenges
	if (!t) return null
	var out = []
	var rows = rbx_rowsOf(t, data)
	for (var i = 0; i < rows.length; i++) {
		var row = []
		for (var c = 1; c <= t.cols; c++) {
			var id = rows[i] * 10 + c
			if (t[id] !== undefined && t[id].unlocked) {
				var ch = rbx_challenge(layer, id)
				if (ch) row.push(ch)
			}
		}
		if (row.length) out.push({ t: "row", c: row })
	}
	return { t: "col", c: out }
}

function rbx_achievement(layer, id) {
	var t = tmp[layer].achievements[id]
	var L = layers[layer].achievements[id]
	if (!(t !== undefined && t.unlocked)) return null
	var done = hasAchievement(layer, id)
	var tip = rbx_v(t, L, "tooltip")
	var text
	if (tip == "") text = null
	else if (done) {
		var dt = rbx_v(t, L, "doneTooltip")
		text = dt ? dt : (tip ? tip : "You did it!")
	} else {
		var gt = rbx_v(t, L, "goalTooltip")
		text = gt ? gt : (tip ? tip : "LOCKED")
	}
	var name = rbx_v(t, L, "name")
	return {
		t: "ach", done: done, tip: text, num: Math.floor(id / 10) <= 1 ? id - 10 : id - 11,
		h: name ? "<h3>" + name + "</h3>" : "", st: rbx_css([tmp[layer].componentStyles.achievement, rbx_v(t, L, "style")]),
	}
}

function rbx_achievements(layer, data) {
	var t = tmp[layer].achievements
	if (!t) return null
	var out = []
	var rows = rbx_rowsOf(t, data)
	for (var i = 0; i < rows.length; i++) {
		var row = []
		for (var c = 1; c <= t.cols; c++) {
			var id = rows[i] * 10 + c
			if (t[id] !== undefined && t[id].unlocked) {
				var a = rbx_achievement(layer, id)
				if (a) row.push(a)
			}
		}
		if (row.length) out.push({ t: "row", c: row })
	}
	return { t: "col", c: out }
}

function rbx_gridable(layer, id) {
	var g = layers[layer].grid
	var data = player[layer].grid[id]
	if (!(data !== undefined && gridRun(layer, "getUnlocked", data, id))) return null
	var can = gridRun(layer, "getCanClick", data, id)
	var h = ""
	if (g.getTitle) h += "<h3>" + rbx_str(gridRun(layer, "getTitle", data, id)) + "</h3><br>"
	h += rbx_str(gridRun(layer, "getDisplay", data, id))
	return {
		t: "btn", k: "grid", cls: can ? "can" : "locked", h: h, a: rbx_act(["grid", layer, id]), hold: g.onHold ? true : null,
		tip: g.getTooltip ? gridRun(layer, "getTooltip", data, id) : null,
		st: rbx_css([can ? { "background-color": tmp[layer].color } : null, tmp[layer].componentStyles.gridable, gridRun(layer, "getStyle", data, id)]),
	}
}

function rbx_grid(layer, data) {
	var t = tmp[layer].grid
	if (!t) return null
	var out = []
	var rows = rbx_rowsOf(t, data)
	for (var i = 0; i < rows.length; i++) {
		var row = []
		for (var c = 1; c <= t.cols; c++) {
			var id = rows[i] * 100 + c
			if (run(layers[layer].grid.getUnlocked, layers[layer].grid, id)) {
				var b = rbx_gridable(layer, id)
				if (b) row.push(b)
			}
		}
		if (row.length) out.push({ t: "row", c: row })
	}
	return { t: "col", c: out }
}

function rbx_infobox(layer, id) {
	var t = tmp[layer].infoboxes
	if (!(t && t[id] !== undefined && t[id].unlocked)) return null
	var shut = player.infoboxes[layer][id]
	return {
		t: "info", shut: shut ? true : false, color: rbx_str(tmp[layer].color), a: rbx_act(["infobox", layer, id]),
		title: rbx_str(t[id].title ? t[id].title : tmp[layer].name), body: rbx_str(t[id].body ? t[id].body : "Blah"),
		st: rbx_css([t[id].style]),
	}
}

function rbx_bar(layer, id) {
	var t = tmp[layer].bars
	if (!(t && t[id] && t[id].unlocked)) return null
	var b = t[id]
	var p = b.progress
	if (p instanceof Decimal) p = p.toNumber()
	p = Math.min(Math.max(p, 0), 1)
	return {
		t: "bar", w: b.width, hh: b.height, p: p, dir: b.direction, h: rbx_str(run(layers[layer].bars[id].display, layers[layer].bars[id])),
		st: rbx_css([b.style, b.borderStyle]), fill: rbx_css([b.style, b.fillStyle]), base: rbx_css([b.style, b.baseStyle]),
	}
}

function rbx_tabButtons(layer, data, name) {
	var out = []
	var keys = Object.keys(data)
	for (var i = 0; i < keys.length; i++) {
		var tab = keys[i]
		if (data[tab].unlocked == undefined || data[tab].unlocked) {
			var glow = subtabShouldNotify(layer, name, tab)
			var cur = player.subtabs[layer][name] == tab
			out.push({
				t: "btn", k: "tab", cls: cur ? "cur" : "can", h: tab, a: rbx_act(["subtab", layer, name, tab]),
				glow: glow ? rbx_str(data[tab].glowColor || defaultGlow) : null, pulse: subtabResetNotify(layer, name, tab) ? true : null,
				st: rbx_css([{ "border-color": tmp[layer].color }, tmp[layer].componentStyles["tab-button"], data[tab].buttonStyle]),
			})
		}
	}
	return { t: "tabs", c: out }
}

function rbx_microtabs(layer, family) {
	var m = tmp[layer].microtabs
	if (!m) return null
	var cur = m[family][player.subtabs[layer][family]]
	var kids = [rbx_tabButtons(layer, m[family], family)]
	if (cur) {
		if (cur.embedLayer) kids.push(rbx_layerTab(cur.embedLayer, true))
		else kids.push(rbx_column(layer, cur.content, cur.style))
	}
	return { t: "col", c: kids, st: { "border-style": "solid" } }
}

function rbx_thingTree(layer, data, type) {
	var out = []
	for (var r = 0; r < data.length; r++) {
		var row = []
		for (var i = 0; i < data[r].length; i++) {
			var id = data[r][i]
			var t = tmp[layer][type + "s"][id]
			if (t !== undefined && t.unlocked) {
				var n = type == "upgrade" ? rbx_upgrade(layer, id) : (type == "buyable" ? rbx_buyable(layer, id) : rbx_clickable(layer, id))
				if (n) row.push(n)
			}
		}
		out.push({ t: "row", c: row })
	}
	return { t: "col", c: out }
}

// one tabFormat entry: "name", [name, data] or [name, data, style]
function rbx_component(layer, item) {
	var name = item, data = undefined, style = undefined
	if (Array.isArray(item)) {
		name = item[0]
		data = item[1]
		if (item.length == 3) style = item[2]
	}
	if (item === undefined || item === null || item === "") return null
	var n
	try {
		n = rbx_componentNode(layer, name, data)
	} catch (e) {
		n = rbx_err(rbx_str(name), e)
	}
	if (!n) return null
	var st = rbx_css([tmp[layer].componentStyles[name], style])
	if (Object.keys(st).length) n.cst = st
	return n
}

function rbx_componentNode(layer, name, data) {
	switch (name) {
		case "display-text": case "raw-html": return { t: "html", h: rbx_str(data) }
		case "blank":
			if (!data) return { t: "blank", w: "8px", hh: "17px" }
			if (Array.isArray(data)) return { t: "blank", w: rbx_str(data[0]), hh: rbx_str(data[1]) }
			return { t: "blank", w: "8px", hh: rbx_str(data) }
		case "display-image": return { t: "html", h: "" }
		case "row": return rbx_container("row", layer, data)
		case "column": return rbx_container("col", layer, data)
		case "layer-proxy": return rbx_column(data[0], data[1])
		case "infobox": return rbx_infobox(layer, data)
		case "h-line": return { t: "hr", w: data ? rbx_str(data) : null }
		case "v-line": return { t: "blank", w: "2px", hh: data ? rbx_str(data) : "10px" }
		case "challenges": return rbx_challenges(layer, data)
		case "challenge": return rbx_challenge(layer, data)
		case "upgrades": return rbx_upgrades(layer)
		case "upgrade": return rbx_upgrade(layer, data)
		case "milestones": return rbx_milestones(layer, data)
		case "milestone": return rbx_milestone(layer, data)
		case "toggle": return rbx_toggle(data)
		case "prestige-button": return rbx_prestigeButton(layer)
		case "main-display": return rbx_mainDisplay(layer, data)
		case "resource-display": return rbx_resourceDisplay(layer)
		case "buyables": return rbx_buyables(layer, data)
		case "buyable": return rbx_buyable(layer, data)
		case "clickables": return rbx_clickables(layer, data)
		case "clickable": return rbx_clickable(layer, data)
		case "grid": return rbx_grid(layer, data)
		case "microtabs": return rbx_microtabs(layer, data)
		case "bar": return rbx_bar(layer, data)
		case "achievements": return rbx_achievements(layer, data)
		case "achievement": return rbx_achievement(layer, data)
		case "upgrade-tree": return rbx_thingTree(layer, data, "upgrade")
		case "buyable-tree": return rbx_thingTree(layer, data, "buyable")
		case "clickable-tree": return rbx_thingTree(layer, data, "clickable")
	}
	return { t: "html", h: "" }
}

function rbx_container(t, layer, data) {
	var out = []
	if (data) {
		for (var i = 0; i < data.length; i++) {
			var n = rbx_component(layer, data[i])
			if (n) out.push(n)
		}
	}
	return { t: t, c: out }
}

function rbx_column(layer, data, style) {
	var n = rbx_container("col", layer, data)
	if (style) n.st = rbx_css([style])
	return n
}

// layer-tab: the default layout, an array tabFormat, or main tabs (tab buttons + the current tab's content)
function rbx_layerTab(layer, embedded) {
	var t = tmp[layer]
	var out = []
	if (!t.tabFormat) {
		if (t.infoboxes) out.push(rbx_infobox(layer, Object.keys(t.infoboxes)[0]))
		out.push(rbx_component(layer, "main-display"))
		if (t.type !== "none") out.push(rbx_component(layer, "prestige-button"))
		out.push(rbx_component(layer, "resource-display"))
		out.push(rbx_component(layer, "milestones"))
		if (Array.isArray(t.midsection)) out.push(rbx_column(layer, t.midsection))
		out.push(rbx_component(layer, "clickables"))
		out.push(rbx_component(layer, "buyables"))
		out.push(rbx_component(layer, "upgrades"))
		out.push(rbx_component(layer, "challenges"))
		out.push(rbx_component(layer, "achievements"))
	} else if (Array.isArray(t.tabFormat)) {
		out.push(rbx_column(layer, t.tabFormat))
	} else {
		var cur = t.tabFormat[player.subtabs[layer].mainTabs]
		out.push(rbx_tabButtons(layer, t.tabFormat, "mainTabs"))
		if (cur.embedLayer) out.push(rbx_layerTab(cur.embedLayer, true))
		else out.push(rbx_column(layer, cur.content))
	}
	var kids = []
	for (var i = 0; i < out.length; i++) if (out[i]) kids.push(out[i])
	return { t: "col", c: kids }
}

function rbx_tabStyle(layer) {
	var t = tmp[layer]
	if (!t) return {}
	var sub = (t.tabFormat && !Array.isArray(t.tabFormat)) ? t.tabFormat[player.subtabs[layer].mainTabs].style : null
	return rbx_css([t.style ? t.style : null, sub])
}

// ------------------------------------------------------------------------------------------------ page parts
// the NG+ menu down the left side (index.html, options.forceOneTab)
var rbx_MENU = [
	["head", "[ Misc ]"], ["page", "info-tab", "Information"], ["page", "options-tab", "Options"], ["page", "changelog-tab", "Changelog"],
	["layer", "ach", "Achievements"], ["hr"],
	["headIf", "m", "[ Milestones (Normal Universe) ]"], ["layer", "m", "Milestone"], ["layer", "mm", "Meta Milestone"], ["layer", "em", "Extra Milestone"], ["hrIf", "m"],
	["headIf", "p", "[ Row 1 ]"], ["layer", "p", "Prestige Points"], ["hrIf", "p"],
	["headIf", "sp", "[ Row 2 ]"], ["layer", "pe", "Prestige Energy"], ["layer", "sp", "Super Prestige Points"], ["layer", "pb", "Prestige Boosts"], ["layer", "pp", "Prestige Power"], ["hrIf", "sp"],
	["headIf", "hp", "[ Row 3 ]"], ["layer", "se", "Super Energy"], ["layer", "hp", "Hyper Prestige Points"], ["layer", "ep", "Exotic Prestige Points"], ["hrIf", "hp"],
	["headIf", "ap", "[ Row 4 ]"], ["layer", "hb", "Hyper Boosts"], ["layer", "ap", "Atomic Prestige Points"], ["mpOut", "mp", "Multiverse Prestige Points"], ["multiverse", "Enter Prestige Multiverse "], ["hrIf", "ap"],
	["headIf", "t", "[ Row 5 ]"], ["layer", "t", "Transcend Points"], ["hrIf", "t"],
	["headIf", "pm", "[ Prestige Multiverse ]"], ["inMultiverse", "[ Main ]"], ["mpIn", "mp", "Multiverse Prestige Points"], ["multiverseIn", "Leave Prestige Multiverse "], ["hrIf", "pm"],
	["headIf", "pm", "[ Row 0 ]"], ["pmLayer"], ["hrIf", "pm"],
	["headPepCp", "[ Row 1 ]"], ["layer", "pep", "Prestiged-Exotic Prestige "], ["cpLayer"], ["cmLayer"], ["hrPepCp"],
	["headIf", "ex", "[ Row 2 ]"], ["layer", "ex", "Exploration Points "], ["hrIf", "ex"],
]

function rbx_menuButton(layer, label, style) {
	var shown = layerShown(layer) == true
	var glow = tmp[layer].notify && player[layer].unlocked
	return {
		t: "btn", k: "menu", cls: player.tab == layer ? "cur" : "can", h: label, a: rbx_act(["tab", layer]),
		glow: glow ? rbx_str(tmp[layer].trueGlowColor) : null, st: rbx_css([shown ? { "background-color": tmp[layer].color } : null, style]),
	}
}

function rbx_menu() {
	var out = []
	var inMv = player.mp.activeChallenge == 21
	for (var i = 0; i < rbx_MENU.length; i++) {
		var e = rbx_MENU[i]
		var k = e[0]
		if (k == "head") out.push({ t: "html", h: e[1] })
		else if (k == "hr") out.push({ t: "hr" })
		else if (k == "headIf") { if (layerShown(e[1]) == true) out.push({ t: "html", h: e[2] }) }
		else if (k == "hrIf") { if (layerShown(e[1]) == true) out.push({ t: "hr" }) }
		else if (k == "page") out.push({ t: "btn", k: "menu", cls: player.tab == e[1] ? "cur" : "can", h: e[2], a: rbx_act(["tab", e[1]]) })
		else if (k == "layer") { if (layerShown(e[1]) == true) out.push(rbx_menuButton(e[1], e[2])) }
		else if (k == "mpOut") { if (layerShown(e[1]) == true && !inMv) out.push(rbx_menuButton(e[1], e[2])) }
		else if (k == "mpIn") { if (layerShown(e[1]) == true && inMv) out.push(rbx_menuButton(e[1], e[2])) }
		else if (k == "multiverse") { if (player.m.best.gte(185) && !inMv) out.push({ t: "btn", k: "menu", cls: "can", h: e[1], a: rbx_act(["chal", "mp", 21]) }) }
		else if (k == "multiverseIn") { if (player.m.best.gte(185) && inMv) out.push({ t: "btn", k: "menu", cls: "can", h: e[1], a: rbx_act(["chal", "mp", 21]) }) }
		else if (k == "inMultiverse") { if (inMv) out.push({ t: "html", h: e[1] }) }
		else if (k == "pmLayer") { if (layerShown("pm") == true) out.push(rbx_menuButton("pm", player.pm.best.gte(15) ? "P███t█g█ M██e█t███" : "Prestige Milestone")) }
		else if (k == "headPepCp") { if (layerShown("pep") == true || layerShown("cp") == true) out.push({ t: "html", h: e[1] }) }
		else if (k == "hrPepCp") { if (layerShown("pep") == true || layerShown("cp") == true) out.push({ t: "hr" }) }
		else if (k == "cpLayer") {
			if (layerShown("cp") == true) {
				var b = rbx_menuButton("cp", "Corrupted Prestige", { color: "lime", "border-color": "lime" })
				b.st["background-color"] = "black"
				out.push(b)
			}
		}
		else if (k == "cmLayer") {
			if ((player.tab == "cp" || player.tab == "cm") && layerShown("cm") == true) out.push(rbx_menuButton("cm", "Corrupted Milestone", { color: "lime", "border-color": "lime" }))
		}
	}
	return { t: "col", c: out }
}

// overlay-head: points, points per second and the mod's extra lines
function rbx_head() {
	var h = ""
	if (player.devSpeed && player.devSpeed != 1) h += "<br>Dev Speed: " + format(player.devSpeed) + "x<br>"
	if (player.offTime !== undefined) h += "<br>Offline Time: " + formatTime(player.offTime.remain) + "<br>"
	if (player.points.lt("1e1000")) h += "You have "
	h += "<h2>" + format(player.points) + "</h2> "
	if (canGenPoints()) {
		var o = tmp.other
		h += "(" + (o.oompsMag != 0 ? format(o.oomps) + " OOM" + (o.oompsMag < 0 ? "^OOM" : (o.oompsMag > 1 ? "^" + o.oompsMag : "")) + "s" : formatSmall(getPointGen())) + "/sec)"
	}
	if (player.points.lt("1e1e6")) h += " " + modInfo.pointsName
	if (player.sp.activeChallenge == 11) {
		h += " and <h2 style=\"color:#9f2846\">" + format(player.m.points, 0) + "</h2> milestones,<br> which can be transformed into <h2 style=\"color:orange\">" + format(tmp.sp.ambersGain) + "</h2> Prestige Ashes after a cooldown. (" + format(player.sp.chalCooldown) + "s)"
	}
	if ((player.sp.sparkMilestones.gt(0) && new Decimal(player.sp.ashedMilestones).lt(player.sp.sparkMilestones) && player.sp.burningTimer > 0) && tmp.sp.milestones[player.sp.ashedMilestones].permanent == false) {
		h += "<br><span style=\"color: orange\">Your " + format(player.sp.ashedMilestones + 1, 0) + helper(player.sp.ashedMilestones + 1) + " Spark Milestone will burn for " + formatTime(player.sp.burningTimer) + "</span>"
	}
	var things = []
	for (var i = 0; i < tmp.displayThings.length; i++) if (tmp.displayThings[i]) things.push(rbx_str(tmp.displayThings[i]))
	return { t: "col", c: [{ t: "html", h: h }, { t: "html", h: things.join("<br>") }] }
}

function rbx_infoTab() {
	var h = "<h2>" + modInfo.name + "</h2><br><h3>" + VERSION.withName + "</h3>"
	if (modInfo.author) h += "<br>Made by " + modInfo.author
	h += "<br>The Modding Tree " + TMT_VERSION.tmtNum + " by Acamaeda<br>The Prestige Tree made by Jacorb and Aarex<br><br>"
	h += "Time Played: " + formatTime(player.timePlayed) + "<br><br><h3>Hotkeys</h3><br>"
	for (var key in hotkeys) {
		var k = hotkeys[key]
		if (player[k.layer].unlocked && tmp[k.layer].hotkeys[k.id].unlocked) h += "<br>" + k.description
	}
	return { t: "col", c: [{ t: "html", h: h }] }
}

function rbx_opt(label, sub, a) {
	return { t: "btn", k: "opt", cls: "can", h: "<b>" + label + "</b><br><span style=\"font-size:12px\">" + sub + "</span>", a: rbx_act(a) }
}

function rbx_optionsTab() {
	var saving = { t: "row", c: [
		rbx_opt("Save", "Save current progress", ["opt", "save"]),
		rbx_opt("Hard Reset", "Reset current progress (press twice)", ["opt", "hardReset"]),
		rbx_opt("Export save", "Show a save string you can copy", ["opt", "export"]),
		rbx_opt("Import a save", "Paste a save string (web saves work too)", ["opt", "import"]),
		rbx_opt("Offline Production - [ " + (options.offlineProd ? "ON" : "OFF") + " ]", "Produce resources when not in game", ["opt", "offlineProd"]),
	] }
	var displays = { t: "row", c: [
		rbx_opt("Milestone Showing Mode", "[ " + MS_DISPLAYS[MS_SETTINGS.indexOf(options.msDisplay)] + " ]", ["opt", "msDisplay"]),
		rbx_opt("Completed Challenges", "[ " + (options.hideChallenges ? "Hidden" : "Shown") + " ]", ["opt", "hideChallenges"]),
		rbx_opt("Corrupt. Tooltip Pos.", "[ " + CCTP_DISPLAYS[CCTP_SETTINGS.indexOf(options.changeCorruptTooltipPlace)] + " ]", ["opt", "cctp"]),
		rbx_opt("Milestones Order - [ " + (options.reverseMilestones ? "Last to First" : "First to Last") + " ]", "Choose milestone ordering", ["opt", "reverseMilestones"]),
	] }
	return { t: "col", c: [
		{ t: "html", h: "<h2>[ Saving ]</h2><br>" }, saving, { t: "blank", w: "8px", hh: "20px" },
		{ t: "html", h: "<h2>[ Displays ]</h2><br>" }, displays,
	] }
}

function rbx_endScreen() {
	var h = "<br><h3>" + modInfo.winText + "</h3><br><h3>Please check the Discord to see if there are new content updates!</h3><br><br>"
	if (!player.timePlayedReset) h += "It took you " + formatTime(player.timePlayed) + " to beat the game.<br>"
	return { t: "col", c: [{ t: "html", h: h }, { t: "row", c: [
		{ t: "btn", k: "opt", cls: "can", h: "Play Again", a: rbx_act(["opt", "playAgain"]) },
		{ t: "btn", k: "opt", cls: "can", h: "Keep Going", a: rbx_act(["opt", "keepGoing"]) },
	] }] }
}

// The whole page for the current tab. Returns { menu, head, tab, tabStyle, tabName, ended, keys }.
function rbx_view() {
	rbx_actions = []
	updateTabFormats()
	var v = {}
	var ended = tmp.gameEnded && !player.keepGoing
	v.ended = ended ? true : false
	try { v.menu = rbx_menu() } catch (e) { v.menu = rbx_err("menu", e) }
	try { v.head = rbx_head() } catch (e) { v.head = rbx_err("head", e) }
	var tab = player.tab
	v.tabName = tab
	v.tabStyle = {}
	try {
		if (ended) v.tab = rbx_endScreen()
		else if (tab == "info-tab") v.tab = rbx_infoTab()
		else if (tab == "options-tab") v.tab = rbx_optionsTab()
		else if (tab == "changelog-tab") v.tab = { t: "col", c: [{ t: "html", h: rbx_str(modInfo.changelog) }] }
		else if (layers[tab]) {
			v.tab = rbx_layerTab(tab)
			v.tabStyle = rbx_tabStyle(tab)
		} else v.tab = { t: "col", c: [] }
	} catch (e) {
		v.tab = rbx_err("tab", e)
	}
	var keys = []
	for (var key in hotkeys) {
		var k = hotkeys[key]
		if (player[k.layer].unlocked && tmp[k.layer].hotkeys[k.id].unlocked) keys.push(key)
	}
	v.keys = keys
	return v
}
