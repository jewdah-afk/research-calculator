// Roblox front end, game side: builds what the web page would draw, as plain view nodes, from inside a player's game
// instance. It is transpiled to Luau with the game (so the JS and Luau builds can be diffed like the game itself) and
// mirrors TMT's Vue components (loader_v.js, components.js), minus the browser. The page itself is the realm map (v.map)
// with the HUD (v.hud) and the open panel's tab (v.tab).
//
// A node is { t: type, ... }. Containers have c (children). Anything the player can press has a (the action, an
// array the server re-checks against the actions on screen before it runs one). HTML strings stay HTML (h); the
// client turns them into RichText. st is a flat CSS object ({ "background-color": "#77bf5f", ... }).
//   col / row          c
//   html               h
//   blank              w, hh
//   hr                 w
//   btn                k (kind: upg buy click chal reset tab sub toggle perk malware respec master sell grid opt),
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
// null when a formatted value is NaN (the game shows "NaN"; the client hides the line instead)
function rbx_nn(s) {
	s = rbx_str(s)
	return s.indexOf("NaN") >= 0 ? null : s
}
// a text a display function returned, or null when it returned nothing (never the string "undefined")
function rbx_txt(x) {
	if (x === undefined || x === null || x === "") return null
	return rbx_nn(x)
}
// progress toward `need`, per mille, floored, on a log scale. 1000 only when have >= need. null when unknown.
function rbx_pr(have, need) {
	if (have === undefined || have === null || need === undefined || need === null) return null
	have = new Decimal(have)
	need = new Decimal(need)
	if (have.gte(need)) return 1000
	if (have.lte(1) || need.lte(1)) return 0
	var a = have.log10(), b = need.log10()
	var r = a.div(b).toNumber()
	if (r < 0.01 && a.gt(1) && b.gt(1)) r = a.log10().div(b.log10()).toNumber()
	if (!(r >= 0)) return 0
	return Math.min(999, Math.floor(r * 1000))
}
// per mille that is never "done": a cost that cannot be paid right now caps at 999
function rbx_prCap(p) {
	if (p === null) return null
	return Math.min(999, p)
}
// the label of a layer's first hotkey ("P", "Shift+M", "Ctrl+E", "C+M"): the text before ":" in its description
function rbx_hk(l) {
	var h = layers[l].hotkeys
	if (!h || !h.length || !tmp[l].hotkeys || !tmp[l].hotkeys[0] || !tmp[l].hotkeys[0].unlocked) return null
	var d = rbx_str(h[0].description), i = d.indexOf(":")
	return i > 0 ? d.substring(0, i) : null
}

// ------------------------------------------------------------------------------------------------ layer components
function rbx_mainDisplay(layer, data) {
	var c = tmp[layer].color
	var pts = data ? format(player[layer].points, data) : formatWhole(player[layer].points)
	var h = player[layer].points.lt("1e1000") ? "You have " : ""
	h += "<h2 style=\"color: " + c + "; text-shadow: 0px 0px 10px " + c + "\">" + pts + "</h2> "
	h += rbx_str(tmp[layer].resource)
	var eff = null
	if (layers[layer].effectDescription) {
		var e = run(layers[layer].effectDescription, layers[layer])
		h += ", " + e
		eff = rbx_txt(e)
	}
	return { t: "html", h: h + "<br><br>", pts: pts, res: rbx_str(tmp[layer].resource), eff: eff }
}

function rbx_prestigeButton(layer) {
	if (tmp[layer].type === "none") return null
	var t = tmp[layer]
	var can = t.canReset
	var n = {
		t: "btn", k: "reset", cls: can ? "can" : "locked", h: prestigeButtonText(layer), a: rbx_act(["reset", layer]),
		st: rbx_css([can ? { "background-color": tmp[layer].color } : null, tmp[layer].componentStyles["prestige-button"]]),
	}
	var stat = t.type == "static"
	var nextAt = stat ? t.nextAtDisp : t.nextAt
	n.gain = formatWhole(t.resetGain)
	n.res = rbx_str(t.resource)
	n.verb = t.resetDescription !== undefined && t.resetDescription !== null ? rbx_str(t.resetDescription).trim() : null
	n.next = nextAt === undefined || nextAt === null ? null : rbx_nn(t.roundUpCost ? formatWhole(nextAt) : format(nextAt))
	n.base = t.baseAmount === undefined || t.baseAmount === null ? null : formatWhole(t.baseAmount)
	n.bres = rbx_str(t.baseResource)
	n.static = stat ? true : false
	n.pr = can ? null : rbx_prCap(rbx_pr(t.baseAmount, stat ? t.nextAt : t.requires))
	n.hk = rbx_hk(layer)
	return n
}

function rbx_resourceDisplay(layer) {
	var t = tmp[layer]
	var h = ""
	if (t.baseAmount) h += "<br>You have " + formatWhole(t.baseAmount) + " " + rbx_str(t.baseResource)
	if (t.passiveGeneration) h += "<br>You are gaining " + format(t.resetGain.times(t.passiveGeneration)) + " " + rbx_str(t.resource) + " per second"
	h += "<br><br>"
	if (t.showBest) h += "Your best " + rbx_str(t.resource) + " is " + formatWhole(player[layer].best) + "<br>"
	if (t.showTotal) h += "You have made a total of " + formatWhole(player[layer].total) + " " + rbx_str(t.resource) + "<br>"
	return {
		t: "html", h: h, have: t.baseAmount ? formatWhole(t.baseAmount) : null, bres: t.baseAmount ? rbx_str(t.baseResource) : null,
		gen: t.passiveGeneration ? rbx_nn(format(t.resetGain.times(t.passiveGeneration))) : null,
		best: t.showBest ? formatWhole(player[layer].best) : null, total: t.showTotal ? formatWhole(player[layer].total) : null,
	}
}

function rbx_upgrade(layer, id) {
	var t = tmp[layer].upgrades[id]
	var L = layers[layer].upgrades[id]
	if (t === undefined) return null
	if (perkUnl(layer, id) && !t.unlocked) {
		var req = rbx_str(rbx_v(t, L, "perkReq"))
		return {
			t: "btn", k: "perk", cls: t.perkCan ? "perk" : "perked", a: rbx_act(["perk", layer, id]),
			h: "<h3>Explore A New Perk Upgrade</h3><br>" + req, id: id, req: req,
		}
	}
	if (!t.unlocked) return null
	var bought = hasUpgrade(layer, id)
	var can = canAffordUpgrade(layer, id) && !bought
	var h = ""
	var ti = null, ds = null, ef = null, co = null, cn = null, custom = true
	if (L.fullDisplay) h = rbx_str(run(L.fullDisplay, L))
	else {
		var title = rbx_v(t, L, "title")
		if (title) h += "<h3>" + title + "</h3><br>"
		ti = rbx_txt(title)
		ds = rbx_str(rbx_v(t, L, "description"))
		h += ds
		if (L.effectDisplay) {
			var e = run(L.effectDisplay, L)
			h += "<br>Currently: " + e
			ef = rbx_txt(e)
		}
		h += "<br>"
		var cd = rbx_v(t, L, "costDescription")
		if (cd) {
			h += cd
			co = rbx_str(cd)
		} else {
			var cur = rbx_v(t, L, "currencyDisplayName")
			co = formatWhole(t.cost)
			cn = rbx_str(cur ? cur : tmp[layer].resource)
			h += "Cost: " + co + " " + cn
			custom = false
		}
	}
	var n = {
		t: "btn", k: "upg", cls: bought ? "bought" : (can ? "can" : "locked"), n: L.fullDisplay ? null : id, h: h,
		a: rbx_act(["upg", layer, id]), tip: rbx_v(t, L, "tooltip"),
		st: rbx_css([can ? { "background-color": tmp[layer].color } : null, tmp[layer].componentStyles.upgrade, rbx_v(t, L, "style")]),
	}
	n.id = id
	n.ti = ti
	n.ds = ds
	n.ef = ef
	n.co = co
	n.cur = cn
	n.pr = bought || can || custom || t.cost === undefined ? null : rbx_prCap(rbx_pr(rbx_upgHave(layer, t), t.cost))
	return n
}

// what canAffordPurchase checks an upgrade's cost against
function rbx_upgHave(layer, t) {
	var name = t.currencyInternalName
	if (name) {
		if (t.currencyLocation) return t.currencyLocation[name]
		if (t.currencyLayer) return player[t.currencyLayer][name]
		return player[name]
	}
	return player[layer].points
}

// Buy All (a Roblox addition): one press buys every upgrade of a layer the player can afford, from when the layer
// after it is reached (sp opens it on p, mm on sp, ...). Upgrade Perk upgrades (p) stay a choice and are skipped.
var rbx_BUYALL_AFTER = { p: "sp", sp: "mm", pb: "hp", hp: "ap", ap: "t", t: "hb", hb: "pe", pe: "se", se: "pp", pp: "ep",
	ep: "mp", mp: "pm", pep: "cp", cp: "cm", ex: "cm" }
// the next layers that a new game already has "unlocked" (mm, pm, cp, cm): for those only shown / best counts
var rbx_BUYALL_STARTUNL = null
function rbx_buyAllOn(l) {
	var nx = rbx_BUYALL_AFTER[l]
	if (!nx || !player[l] || !player[nx] || !tmp[nx]) return false
	if (rbx_BUYALL_STARTUNL === null) {
		rbx_BUYALL_STARTUNL = {}
		for (var k in rbx_BUYALL_AFTER) {
			var n = rbx_BUYALL_AFTER[k]
			var sd = layers[n] && layers[n].startData ? layers[n].startData() : null
			rbx_BUYALL_STARTUNL[n] = sd && sd.unlocked ? true : false
		}
	}
	if ((player[nx].unlocked && !rbx_BUYALL_STARTUNL[nx]) || tmp[nx].layerShown == true) return true
	return player[nx].best !== undefined && new Decimal(player[nx].best).gt(0)
}
// the upgrades Buy All would buy now
function rbx_buyAllIds(l) {
	var t = tmp[l].upgrades, out = []
	if (!t || !player[l].unlocked || player[l].deactivated) return out // buyUpg's own rule
	for (var r = 1; r <= t.rows; r++) {
		for (var c = 1; c <= t.cols; c++) {
			var id = r * 10 + c
			if (t[id] === undefined || layers[l].upgrades[id].perkUnl !== undefined) continue
			if (t[id].unlocked && !hasUpgrade(l, id) && canAffordUpgrade(l, id)) out.push(id)
		}
	}
	return out
}
// buy them, again while a purchase makes more affordable or unlocks more (a few passes at most); the count bought
function rbx_buyAll(l) {
	if (!rbx_buyAllOn(l) || !player[l].unlocked) return 0
	var n = 0
	for (var pass = 0; pass < 6; pass++) {
		var ids = rbx_buyAllIds(l)
		var got = 0
		for (var i = 0; i < ids.length; i++) {
			var id = ids[i], U = layers[l].upgrades[id]
			// tmp's canAfford is from before this pass: an upgrade with its own pay() is checked again against the
			// live resources (buyUpg re-checks a plain cost itself), or it could be paid with what is already spent
			if (U.canAfford !== undefined) {
				var ok = false
				try { ok = run(U.canAfford, U) ? true : false } catch (e) { ok = false }
				tmp[l].upgrades[id].canAfford = ok
			}
			if (!canAffordUpgrade(l, id)) continue
			buyUpg(l, id)
			if (hasUpgrade(l, id)) got++
		}
		if (got == 0) break
		n += got
		updateTemp()
	}
	return n
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
	var col = { t: "col", c: rows }
	// Buy All: the action while it is open, and how many upgrades are affordable one by one (> 0: it lights up)
	if (rbx_buyAllOn(layer)) {
		col.ba = rbx_act(["buyall", layer])
		col.bn = rbx_buyAllIds(layer).length
	}
	return col
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
	var ti = rbx_str(rbx_v(t, L, "requirementDescription"))
	var ds = rbx_str(run(L.effectDescription, L))
	var h = "<h3>" + ti + "</h3><br>" + ds + "<br>"
	var kids = []
	if (t.pseudoUnl == true && !player[layer].pseudoBuys.includes(id)) {
		var plocked = !player.points.gte(t.pseudoCost)
		var pc = format(t.pseudoCost)
		kids.push({
			t: "btn", k: "malware", cls: plocked ? "plocked" : "pseudo", a: rbx_act(["malware", layer, id]),
			h: "Infect a Milestone with Malware<br>Cost: " + pc + " points.", id: id, co: pc,
		})
	}
	if (t.toggles && done) {
		for (var i = 0; i < t.toggles.length; i++) kids.push(rbx_toggle(t.toggles[i]))
	}
	return {
		t: "ms", done: done, h: h, c: kids, tip: rbx_v(t, L, "tooltip"),
		st: rbx_css([tmp[layer].componentStyles.milestone, rbx_v(t, L, "style")]),
		id: id, ti: ti, ds: ds, mal: player[layer].pseudoBuys && player[layer].pseudoBuys.includes(rbx_str(id)) ? true : false,
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

// what each buyable's canAfford checks its cost against: [layer or null, key, currency name or null (the layer's
// resource)]. Read from the buyables' canAfford / buy code; port/tools/check_buycur.js checks it on the fuzz saves.
// Buyables whose price also depends on something else (mp 23, the ex movers) are left out: they get no progress bar.
var rbx_BUY_CUR = {
	p: { 11: ["p", "points"], 12: ["p", "points"] },
	sp: { 11: ["sp", "points"], 12: ["sp", "points"] },
	hp: { 11: ["hp", "points"], 12: ["hp", "points"] },
	ap: { 11: ["ap", "points"] },
	pp: { 11: ["pp", "points"] },
	ep: { 11: ["ep", "points"] },
	mp: { 11: ["mp", "points"], 12: ["mp", "points"], 13: ["mp", "points"], 21: ["mp", "points"], 22: ["pm", "essence", "prestige essences"] },
	pep: { 11: ["pep", "points"] },
	cp: {
		11: ["cp", "formatted", "corruption essences"], 21: ["cp", "formatted", "corruption essences"], 22: ["cp", "formatted", "corruption essences"],
		31: [null, "points", null], 32: ["pm", "essence", "prestige essences"], 33: [null, "points", null], 34: ["pm", "essence", "prestige essences"],
	},
}
function rbx_buyHave(bc) {
	return bc[0] ? player[bc[0]][bc[1]] : player[bc[1]]
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
	var maxed = cls == "bought"
	var pl = t.purchaseLimit
	var bc = rbx_BUY_CUR[layer] ? rbx_BUY_CUR[layer][id] : undefined
	node.id = id
	node.ti = rbx_txt(title)
	node.lv = formatWhole(player[layer].buyables[id])
	node.max = pl !== undefined && pl !== null && new Decimal(pl).lt("1e300") ? formatWhole(pl) : null
	node.co = t.cost === undefined || t.cost === null ? null : rbx_nn(format(t.cost))
	node.cur = bc ? (bc[2] ? bc[2] : (bc[0] ? rbx_str(tmp[bc[0]].resource) : rbx_str(modInfo.pointsName))) : null
	node.pr = !bc || maxed || t.canAfford || t.cost === undefined ? null : rbx_prCap(rbx_pr(rbx_buyHave(bc), t.cost))
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
		id: id, ti: rbx_txt(title),
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
	var ds = null, goal = null, rw = null, rcur = null
	if (L.fullDisplay) body = rbx_str(run(L.fullDisplay, L))
	else {
		ds = rbx_str(rbx_v(t, L, "challengeDescription"))
		body = ds + "<br>Goal:  "
		var gd = rbx_v(t, L, "goalDescription")
		if (gd) goal = rbx_str(gd)
		else {
			var cur = rbx_v(t, L, "currencyDisplayName")
			goal = format(t.goal) + " " + rbx_str(cur ? cur : modInfo.pointsName)
		}
		body += goal
		rw = rbx_str(rbx_v(t, L, "rewardDescription"))
		body += "<br>Reward: " + rw + "<br>"
		if (L.rewardDisplay !== undefined) {
			var rd = t.rewardDisplay ? run(L.rewardDisplay, L) : format(t.rewardEffect)
			body += "Currently: " + rd
			rcur = rbx_txt(rd)
		}
	}
	var active = player[layer].activeChallenge === id
	var name = rbx_str(rbx_v(t, L, "name"))
	var lim = t.completionLimit
	return {
		t: "chal", cls: cls, active: active, st: rbx_css([tmp[layer].componentStyles.challenge, rbx_v(t, L, "style")]),
		c: [{ t: "html", h: "<h3>" + name + "</h3>" }, btn, { t: "html", h: body }],
		id: id, ti: name, ds: ds, goal: goal, rw: rw, cur: rcur, cmp: formatWhole(challengeCompletions(layer, id)),
		lim: lim !== undefined && lim !== null && lim != 1 ? rbx_str(lim) : null,
		st8: active ? (canCompleteChallenge(layer, id) ? "completable" : "active") : (maxedChallenge(layer, id) ? "done" : "idle"),
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
		id: id, ti: rbx_txt(name),
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
	var n = {
		t: "btn", k: "grid", cls: can ? "can" : "locked", h: h, a: rbx_act(["grid", layer, id]), hold: g.onHold ? true : null,
		tip: g.getTooltip ? gridRun(layer, "getTooltip", data, id) : null,
		st: rbx_css([can ? { "background-color": tmp[layer].color } : null, tmp[layer].componentStyles.gridable, gridRun(layer, "getStyle", data, id)]),
	}
	if (layer == "cp") rbx_cpCell(n, data, id)
	return n
}

// a Corrupted Prestige hard drive: its state, level and the tooltip's three numbers, apart
function rbx_cpCell(n, data, id) {
	var lv = data.level ? data.level : 0
	var pm = data.type == "pm"
	var chosen = pm ? player.cp.chosenBackdoor == id : player.cp.trojanChosen == id
	var gs = lv < 1 ? "empty" : (data.active == true ? "active" : (chosen ? "chosen" : "corrupted"))
	n.id = id
	n.gs = gs
	n.lv = lv
	n.kind = pm ? "backdoor" : "trojan"
	n.caut = data.cautPower ? data.cautPower : 0
	n.gx = null
	n.gp = null
	if (lv < 1) return
	var cost = gridCost("cp", id)
	n.gx = { fix: format(cost), fres: pm ? "prestige essences" : "points", deb: format(gridEffect("cp", id), 5), rew: format(gridEssence("cp", id), 0) }
	if (gs == "active" || gs == "chosen") {
		// the resource the drive's ASCII bar fills from
		var have = gs == "chosen" ? (pm ? player.cp.peInCorrupt.add(1) : player.cp.pointsInCorrupt.add(1)) : (pm ? player.pm.essence : player.points)
		var r = new Decimal(have).div(cost)
		n.gp = r.gte(1) ? 1000 : (r.gt(0) ? Math.min(999, Math.floor(r.toNumber() * 1000)) : 0)
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

// sp's Spark Milestone burn bar (session.js turns handleBurnDisplay's HTML div into ["rbx-burn", id]); h keeps the
// game's HTML for the old client
function rbx_burnBar(id) {
	var html = rbx_burnHtml(id)
	if (!html) return null
	var timer = player.sp.timer[id]
	var perm = tmp.sp.milestones[id].permanent == true
	var p = perm || timer === undefined || timer === null ? 1 : 1 - Math.max(0, (240 - timer) / 240)
	return {
		t: "bar", w: 300, hh: 44, p: p, dir: 3, h: rbx_str(html[1]), st: {}, fill: {}, base: {}, id: id,
		st8: perm ? "permanent" : (timer == 0 ? "ashed" : "burning"), bp: Math.max(0, Math.min(1000, Math.floor(p * 1000))),
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

// one tabFormat entry: "name", [name, data] or [name, data, style]. ci is its 1-based place in the list it came from
// (before empty entries are dropped): cn + ci + the subtab name name a component the same way while path ids shift.
function rbx_component(layer, item, ci) {
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
	n.cn = rbx_str(name)
	n.ci = ci ? ci : null
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
		case "rbx-burn": return rbx_burnBar(data)
	}
	return { t: "html", h: "" }
}

function rbx_container(t, layer, data) {
	var out = []
	if (data) {
		for (var i = 0; i < data.length; i++) {
			var n = rbx_component(layer, data[i], i + 1)
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
		out.push(rbx_component(layer, "main-display", 1))
		if (t.type !== "none") out.push(rbx_component(layer, "prestige-button", 2))
		out.push(rbx_component(layer, "resource-display", 3))
		out.push(rbx_component(layer, "milestones", 4))
		if (Array.isArray(t.midsection)) out.push(rbx_column(layer, t.midsection))
		out.push(rbx_component(layer, "clickables", 6))
		out.push(rbx_component(layer, "buyables", 7))
		out.push(rbx_component(layer, "upgrades", 8))
		out.push(rbx_component(layer, "challenges", 9))
		out.push(rbx_component(layer, "achievements", 10))
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
// an Options button. id is the option, ti its label, val the state it shows; idx / n place a cycler (0-based, of n);
// on is the state of a two-state toggle
function rbx_opt(label, sub, a, ti, val, idx, n, on) {
	return {
		t: "btn", k: "opt", cls: "can", h: "<b>" + label + "</b><br><span style=\"font-size:12px\">" + sub + "</span>", a: rbx_act(a),
		id: a[1], ti: ti, val: val === undefined ? null : val, idx: idx === undefined ? null : idx, n: n === undefined ? null : n,
		on: on === undefined ? null : (on ? true : false),
	}
}

// the game's facts (the web page's Information tab), for the Options ABOUT card
function rbx_about() {
	var keys = []
	for (var key in hotkeys) {
		var k = hotkeys[key]
		if (player[k.layer].unlocked && tmp[k.layer].hotkeys[k.id].unlocked) {
			var d = rbx_str(k.description), i = d.indexOf(":")
			keys.push({ k: i > 0 ? d.substring(0, i) : rbx_str(key), d: i > 0 ? d.substring(i + 1).trim() : d })
		}
	}
	return {
		t: "about", name: rbx_str(modInfo.name), ver: rbx_str(VERSION.withName), author: modInfo.author ? rbx_str(modInfo.author) : null,
		tmt: "The Modding Tree " + TMT_VERSION.tmtNum + " by Acamaeda", pt: "The Prestige Tree made by Jacorb and Aarex", keys: keys,
	}
}

function rbx_optionsTab() {
	var ms = MS_SETTINGS.indexOf(options.msDisplay), cc = CCTP_SETTINGS.indexOf(options.changeCorruptTooltipPlace)
	var saving = { t: "row", c: [
		rbx_opt("Save", "Save now (the game also saves automatically)", ["opt", "save"], "Save"),
		rbx_opt("Offline Production - [ " + (options.offlineProd ? "ON" : "OFF") + " ]", "Produce resources when not in game", ["opt", "offlineProd"],
			"Offline Production", options.offlineProd ? "ON" : "OFF", null, null, options.offlineProd ? true : false),
	] }
	var displays = { t: "row", c: [
		rbx_opt("Milestone Showing Mode", "[ " + MS_DISPLAYS[ms] + " ]", ["opt", "msDisplay"],
			"Milestone Showing Mode", rbx_str(MS_DISPLAYS[ms]), ms, MS_SETTINGS.length),
		rbx_opt("Completed Challenges", "[ " + (options.hideChallenges ? "Hidden" : "Shown") + " ]", ["opt", "hideChallenges"],
			"Completed Challenges", options.hideChallenges ? "Hidden" : "Shown", null, null, options.hideChallenges ? true : false),
		rbx_opt("Corrupt. Tooltip Pos.", "[ " + CCTP_DISPLAYS[cc] + " ]", ["opt", "cctp"],
			"Corrupt. Tooltip Pos.", rbx_str(CCTP_DISPLAYS[cc]), cc, CCTP_SETTINGS.length),
		rbx_opt("Milestones Order - [ " + (options.reverseMilestones ? "Last to First" : "First to Last") + " ]", "Choose milestone ordering", ["opt", "reverseMilestones"],
			"Milestones Order", options.reverseMilestones ? "Last to First" : "First to Last", null, null, options.reverseMilestones ? true : false),
	] }
	return { t: "col", c: [
		{ t: "html", h: "<h2>[ Saving ]</h2><br>" }, saving, { t: "blank", w: "8px", hh: "20px" },
		{ t: "html", h: "<h2>[ Displays ]</h2><br>" }, displays, rbx_about(),
	] }
}

function rbx_endScreen() {
	var h = "<br><h3>" + modInfo.winText + "</h3><br><br>"
	var took = player.timePlayedReset ? null : formatTime(player.timePlayed)
	if (took !== null) h += "It took you " + took + " to beat the game.<br>"
	return { t: "col", c: [{ t: "html", h: h }, { t: "row", c: [
		{ t: "btn", k: "opt", cls: "can", h: "Play Again", a: rbx_act(["opt", "playAgain"]) },
		{ t: "btn", k: "opt", cls: "can", h: "Keep Going", a: rbx_act(["opt", "keepGoing"]) },
	] }], win: rbx_str(modInfo.winText), took: took }
}

// ------------------------------------------------------------------------------------------------ the map
// The home screen: every layer is a node in a socket on the painted tree / Multiverse rift. The list is fixed (hidden
// layers stay in it as { show: false }), so node ids ("map.3") never move and a patch only carries nodes that changed.
// A node's changing numbers live in its one child ("map.3.1", t: "val") so the node itself is resent only when its
// look changes. map.22 is the Enter / Leave Prestige Multiverse gate.
var rbx_MAP = ["ach", "m", "mm", "em", "p", "pe", "sp", "pb", "pp", "se", "hp", "ep", "hb", "ap", "mp", "t", "pm", "pep", "cp", "cm", "ex"]
var rbx_MAP_NAME = {
	ach: "Achievements", m: "Milestone", mm: "Meta Milestone", em: "Extra Milestone", p: "Prestige Points", pe: "Prestige Energy",
	sp: "Super Prestige Points", pb: "Prestige Boosts", pp: "Prestige Power", se: "Super Energy", hp: "Hyper Prestige Points",
	ep: "Exotic Prestige Points", hb: "Hyper Boosts", ap: "Atomic Prestige Points", mp: "Multiverse Prestige Points", t: "Transcend Points",
	pm: "Prestige Milestone", pep: "Prestiged-Exotic Prestige", cp: "Corrupted Prestige", cm: "Corrupted Milestone", ex: "Exploration Points",
}
// the layers entering the Prestige Multiverse resets (mp challenge 21 onEnter)
var rbx_MV_RESETS = ["pp", "p", "sp", "pe", "hp", "ap", "pb", "hb", "se", "ep", "em", "mm", "m", "t"]

function rbx_mapName(l) {
	if (l == "pm" && player.pm.best.gte(15)) return "P███t█g█ M██e█t███"
	return rbx_MAP_NAME[l]
}

// a branch colour: a theme slot (1 white, 2 light grey, 3 grey, 4 red) or a CSS colour (P's malware "#c86a6a")
function rbx_branchColor(c) {
	if (typeof c == "number") {
		var th = colors[options.theme] ? colors[options.theme] : colors["default"]
		return rbx_str(th[c])
	}
	return rbx_str(c)
}

// drawTree(): a branch is drawn from a shown layer to each target in its (live) branches list
function rbx_mapBranches(l) {
	var out = []
	var b = tmp[l].branches
	if (!Array.isArray(b)) return out
	for (var i = 0; i < b.length; i++) {
		var to = b[i], col = 1, w = 15
		if (Array.isArray(to)) {
			if (to[1] !== undefined) col = to[1]
			if (to[2]) w = to[2]
			to = to[0]
		}
		if (tmp[to] && tmp[to].layerShown == true) out.push({ to: rbx_str(to), col: rbx_branchColor(col), w: w })
	}
	return out
}

// the tree node's tooltip (components.js tree-node)
function rbx_nodeTip(l) {
	var t = tmp[l]
	var tip = rbx_v(t, layers[l], "tooltip")
	if (tip === "") return null
	if (player[l].unlocked) return tip ? rbx_str(tip) : formatWhole(player[l].points) + " " + rbx_str(t.resource)
	if (t.tooltipLocked) return rbx_str(t.tooltipLocked)
	return "Reach " + formatWhole(t.requires) + " " + rbx_str(t.baseResource) + " to unlock (You have " + formatWhole(t.baseAmount) + " " + rbx_str(t.baseResource) + ")"
}

// how many achievements the game has
function rbx_achTotal() {
	var n = 0
	var a = layers.ach.achievements
	for (var k in a) if (a[k] && typeof a[k] == "object") n++
	return n
}

// what reveals a hidden layer (the layers' own layerShown rules): the best of that resource must reach the count.
// Only the plain count rules are listed (ex needs Malware 9 on the Milestone layer and has no count).
var rbx_UNLOCK = {
	p: ["m", 5], sp: ["m", 25], mm: ["m", 40], pb: ["m", 50], hp: ["m", 60], ap: ["m", 80], t: ["m", 99],
	hb: ["m", 104], pe: ["m", 125], se: ["m", 140], pp: ["m", 151], ep: ["m", 160], mp: ["m", 181], em: ["mm", 30],
	pep: ["pm", 5], cp: ["pm", 6], cm: ["pm", 10],
}
// plain names: the prestige-milestone resource name is deliberately scrambled text in the game
var rbx_UNLOCK_NAMES = { m: "milestones", mm: "meta-milestones", pm: "prestige-milestones" }
function rbx_need(l) {
	var u = rbx_UNLOCK[l]
	if (!u || !player[u[0]] || player[u[0]].best === undefined) return null
	var have = new Decimal(player[u[0]].best)
	return { r: rbx_UNLOCK_NAMES[u[0]], n: formatWhole(u[1]), have: formatWhole(have), pr: rbx_prCap(rbx_pr(have, u[1])) }
}

function rbx_mapNode(l) {
	var t = tmp[l]
	var shown = t.layerShown == true
	var n = { t: "node", id: l, show: shown }
	if (!shown) {
		var reached = player[l].unlocked || (player[l].best !== undefined && new Decimal(player[l].best).gt(0))
		n.dor = reached ? true : false
		n.need = rbx_need(l)
		return n
	}
	var unl = player[l].unlocked ? true : false
	var can = t.type != "none" && t.canReset ? true : false
	var lit = unl || can
	n.unl = unl
	n.col = rbx_str(t.color)
	n.sym = l == "cp" ? "CR" : rbx_str(t.symbol)
	n.name = rbx_mapName(l)
	n.st = rbx_css([rbx_v(t, layers[l], "nodeStyle")])
	n.tab = (t.tabFormat && !Array.isArray(t.tabFormat)) ? rbx_str(player.subtabs[l].mainTabs) : null
	n.ch = player[l].activeChallenge ? player[l].activeChallenge : null
	n.cur = player.tab == l ? true : false
	n.br = rbx_mapBranches(l)
	n.a = rbx_act(["tab", l])
	n.c = [{
		t: "val", can: can, lit: lit, glow: t.notify && unl ? true : false, pulse: t.prestigeNotify ? true : false,
		pts: l == "ach" ? formatWhole(player.ach.achievements.length) : formatWhole(player[l].points), res: rbx_str(t.resource),
		tip: rbx_nodeTip(l), ra: can ? rbx_act(["reset", l]) : null,
		req: lit || t.requires === undefined ? null : rbx_nn(formatWhole(t.requires)), rres: lit ? null : rbx_str(t.baseResource),
		gain: can ? formatWhole(t.resetGain) : null, pr: lit ? null : rbx_prCap(rbx_pr(t.baseAmount, t.requires)),
		gen: unl && t.passiveGeneration && t.resetGain && new Decimal(t.resetGain).gt(0) ? rbx_nn(format(t.resetGain.times(t.passiveGeneration))) : null,
		tot: l == "ach" ? rbx_achTotal() : null,
	}]
	return n
}

// the Enter / Leave Prestige Multiverse gate (the web page's menu button: Multiverse Prestige challenge 21)
function rbx_mapGate() {
	var inMv = player.mp.activeChallenge == 21
	var g = { t: "gate", show: player.m.best.gte(185) ? true : false, inside: inMv }
	var best = player.m.best
	var req = { have: formatWhole(best), need: "185", pr: best.gte(185) ? 1000 : Math.max(0, Math.min(999, Math.floor(best.toNumber() / 185 * 1000))) }
	if (!g.show) {
		g.req = req
		return g
	}
	var c = tmp.mp.challenges[21]
	g.can = player.mp.unlocked && c.unlocked ? true : false
	g.fin = inMv && canCompleteChallenge("mp", 21) ? true : false
	g.h = inMv ? "Leave Prestige Multiverse" : "Enter Prestige Multiverse"
	g.goal = rbx_str(rbx_v(c, layers.mp.challenges[21], "goalDescription"))
	g.done = challengeCompletions("mp", 21) >= 1
	g.a = rbx_act(["chal", "mp", 21])
	g.req = req
	var rs = []
	for (var i = 0; i < rbx_MV_RESETS.length; i++) if (!(rbx_MV_RESETS[i] == "sp" && hasMalware("m", 15))) rs.push(rbx_MV_RESETS[i])
	g.rs = rs
	return g
}

// the panel that is open: a shown layer or the options; anything else (a hidden layer, "none", an old info tab) is the map
function rbx_openPanel() {
	var tab = player.tab
	if (tab == "options-tab") return tab
	if (rbx_MAP.indexOf(tab) >= 0 && tmp[tab].layerShown == true) return tab
	return null
}

function rbx_map() {
	var open = rbx_openPanel()
	var kids = []
	for (var i = 0; i < rbx_MAP.length; i++) {
		var n
		try {
			n = rbx_mapNode(rbx_MAP[i])
		} catch (e) {
			n = { t: "node", id: rbx_MAP[i], show: false, dor: false }
		}
		kids.push(n)
	}
	kids.push(rbx_mapGate())
	return {
		t: "map", inside: player.mp.activeChallenge == 21, open: open,
		close: rbx_act(["tab", "none"]), opt: rbx_act(["tab", "options-tab"]), c: kids,
	}
}

// the HUD: the overlay head's numbers, apart, so the client can set them big
function rbx_hud() {
	var h = { t: "hud", pts: format(player.points), name: rbx_str(modInfo.pointsName), gen: null }
	var pg = getPointGen() // once: it is the costly part
	if (canGenPoints()) {
		var o = tmp.other
		// no pill while the rate is zero
		if (!(o.oompsMag == 0 ? pg.lte(0) : new Decimal(o.oomps).lte(0))) {
			h.gen = o.oompsMag != 0 ? format(o.oomps) + " OOM" + (o.oompsMag < 0 ? "^OOM" : (o.oompsMag > 1 ? "^" + o.oompsMag : "")) + "s/sec" : formatSmall(pg) + "/sec"
		}
	}
	h.dev = player.devSpeed && player.devSpeed != 1 ? format(player.devSpeed) + "x" : null
	h.off = player.offTime !== undefined && player.offTime.remain > 0 ? formatTime(player.offTime.remain) : null
	// the softcap / overflow warnings (mod.js displayThings[1], same conditions)
	var w = []
	var wh = tmp.displayThings[1] ? rbx_str(tmp.displayThings[1]) : ""
	if (wh !== "") {
		var sc = getPointSoftcapStart(), of = getCostOverflowStart()
		if (pg.gte(sc.sqrt())) w.push({ k: "softcap", v: format(sc), e: rbx_nn(format(pg.log(getPointGenBeforeSoftcap()), 4)) })
		if (player.m.points.gte(of)) w.push({ k: "overflow", v: format(of), e: rbx_nn(format(getCostOverflowEff(), 4)) })
	}
	h.w = w
	h.wh = wh === "" ? null : wh
	// the head's other lines: sp challenge 11's ashes and the burning Spark Milestone
	var x = []
	if (player.sp.activeChallenge == 11) {
		x.push("<h2 style=\"color:#9f2846\">" + format(player.m.points, 0) + "</h2> milestones,<br> which can be transformed into <h2 style=\"color:orange\">" + format(tmp.sp.ambersGain) + "</h2> Prestige Ashes after a cooldown. (" + format(player.sp.chalCooldown) + "s)")
	}
	if ((player.sp.sparkMilestones.gt(0) && new Decimal(player.sp.ashedMilestones).lt(player.sp.sparkMilestones) && player.sp.burningTimer > 0) && tmp.sp.milestones[player.sp.ashedMilestones].permanent == false) {
		x.push("<span style=\"color: orange\">Your " + format(player.sp.ashedMilestones + 1, 0) + helper(player.sp.ashedMilestones + 1) + " Spark Milestone will burn for " + formatTime(player.sp.burningTimer) + "</span>")
	}
	h.x = x.length ? x.join("<br>") : null
	h.fr = player.m.best.eq(0) ? true : false
	return h
}

// The whole page. Returns { ended, map, hud, tabName, tabStyle, tab, keys }. tabName is "end", "options-tab", the open
// layer, or "none" (the map alone: no tab is built; an old save's info or changelog tab is the map alone too).
function rbx_view() {
	rbx_actions = []
	updateTabFormats()
	var v = {}
	var ended = tmp.gameEnded && !player.keepGoing
	v.ended = ended ? true : false
	try { v.map = rbx_map() } catch (e) { v.map = rbx_err("map", e) }
	try { v.hud = rbx_hud() } catch (e) { v.hud = rbx_err("hud", e) }
	var open = v.map.t == "map" ? v.map.open : null
	v.tabName = ended ? "end" : (open ? open : "none")
	v.tabStyle = {}
	try {
		if (ended) v.tab = rbx_endScreen()
		else if (open == "options-tab") v.tab = rbx_optionsTab()
		else if (open) {
			v.tab = rbx_layerTab(open)
			v.tabStyle = rbx_tabStyle(open)
		}
		else v.tab = { t: "col", c: [] }
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
