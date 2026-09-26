--!nocheck
-- transpiled from rbx/view.js by port/build.js: do not edit
return function()
-- transpiled from rbx/view.js
rbx_act = function(this, a)
	JS.m(rbx_actions, "push", a)
	do return a end
end
rbx_cssInto = function(this, out, s)
	local i, k, v
	if (((((s == nil) or (s == JS.NULL)) or (s == false)) or (s == "")) or (s == true)) then
		do return end
	end
	if Array.isArray(s) then
		for i = 0, JS.cap(0, (JS.len(s)) - 1, 1) do
			rbx_cssInto(nil, out, s[JS.k(i)])
		end
		do return end
	end
	if ((not (JS.typeof(s) == "object")) or JS.instanceof(s, Decimal)) then
		do return end
	end
	for _, __k1 in JS.keys(s) do
		k = __k1
		v = s[k]
		if (((not (v == nil)) and (not (v == JS.NULL))) and (not (JS.typeof(v) == "function"))) then
			JS.set(out, k, ("" .. JS.str(v)))
		end
	end
end
rbx_css = function(this, list)
	local out
	out = JS.O({})
	rbx_cssInto(nil, out, list)
	do return out end
end
rbx_v = function(this, t, L, key)
	local v
	v = t[JS.k(key)]
	if (JS.typeof(v) == "function") then
		do return run(nil, L[JS.k(key)], L) end
	end
	do return v end
end
rbx_str = function(this, x)
	if ((x == nil) or (x == JS.NULL)) then
		do return "" end
	end
	do return ("" .. JS.str(x)) end
end
rbx_err = function(this, what, e)
	do return JS.O({
		t = "html",
		h = (((("<span style='color: #ff5050'>[" .. JS.str(what)) .. " failed: ") .. JS.str(rbx_str(nil, e))) .. "]</span>")
	}, {"t", "h"}) end
end
rbx_nn = function(this, s)
	s = rbx_str(nil, s)
	do return (if (JS.tonum(JS.m(s, "indexOf", "NaN")) >= 0) then JS.NULL else s) end
end
rbx_txt = function(this, x)
	if (((x == nil) or (x == JS.NULL)) or (x == "")) then
		do return JS.NULL end
	end
	do return rbx_nn(nil, x) end
end
rbx_pr = function(this, have, need)
	local a, b, r
	if ((((have == nil) or (have == JS.NULL)) or (need == nil)) or (need == JS.NULL)) then
		do return JS.NULL end
	end
	have = JS.D(have)
	need = JS.D(need)
	if have:gte(need) then
		do return 1000 end
	end
	if (have:lte(1) or need:lte(1)) then
		do return 0 end
	end
	a = have:log10()
	b = need:log10()
	r = a:div(b):toNumber()
	if (((JS.tonum(r) < 0.01) and a:gt(1)) and b:gt(1)) then
		r = a:log10():div(b:log10()):toNumber()
	end
	if (not (JS.tonum(r) >= 0)) then
		do return 0 end
	end
	do return Math.min(999, Math.floor((JS.tonum(r) * 1000))) end
end
rbx_prCap = function(this, p)
	if (p == JS.NULL) then
		do return JS.NULL end
	end
	do return Math.min(999, p) end
end
rbx_hk = function(this, l)
	local h, d, i
	h = layers[JS.k(l)].hotkeys
	if (((((not JS.t(h)) or (not JS.t(JS.len(h)))) or (not JS.t(tmp[JS.k(l)].hotkeys))) or (not JS.t(tmp[JS.k(l)].hotkeys[0]))) or (not JS.t(tmp[JS.k(l)].hotkeys[0].unlocked))) then
		do return JS.NULL end
	end
	d = rbx_str(nil, h[0].description)
	i = JS.m(d, "indexOf", ":")
	do return (if (JS.tonum(i) > 0) then JS.m(d, "substring", 0, i) else JS.NULL) end
end
rbx_mainDisplay = function(this, layer, data)
	local c, pts, h, eff, e
	c = tmp[JS.k(layer)].color
	pts = (if JS.t(data) then format(nil, player[JS.k(layer)].points, data) else formatWhole(nil, player[JS.k(layer)].points))
	h = (if player[JS.k(layer)].points:lt("1e1000") then "You have " else "")
	h = (JS.str(h) .. (((((("<h2 style=\"color: " .. JS.str(c)) .. "; text-shadow: 0px 0px 10px ") .. JS.str(c)) .. "\">") .. JS.str(pts)) .. "</h2> "))
	h = JS.add(h, rbx_str(nil, tmp[JS.k(layer)].resource))
	eff = JS.NULL
	if JS.t(layers[JS.k(layer)].effectDescription) then
		e = run(nil, layers[JS.k(layer)].effectDescription, layers[JS.k(layer)])
		h = (JS.str(h) .. (", " .. JS.str(e)))
		eff = rbx_txt(nil, e)
	end
	do return JS.O({
		t = "html",
		h = (JS.str(h) .. "<br><br>"),
		pts = pts,
		res = rbx_str(nil, tmp[JS.k(layer)].resource),
		eff = eff
	}, {"t", "h", "pts", "res", "eff"}) end
end
rbx_prestigeButton = function(this, layer)
	local t, can, n, stat, nextAt
	if (tmp[JS.k(layer)].type == "none") then
		do return JS.NULL end
	end
	t = tmp[JS.k(layer)]
	can = t.canReset
	n = JS.O({
		t = "btn",
		k = "reset",
		cls = (if JS.t(can) then "can" else "locked"),
		h = prestigeButtonText(nil, layer),
		a = rbx_act(nil, JS.A(2, "reset", layer)),
		st = rbx_css(nil, JS.A(2, (if JS.t(can) then JS.O({
		["background-color"] = tmp[JS.k(layer)].color
	}) else JS.NULL), tmp[JS.k(layer)].componentStyles["prestige-button"]))
	}, {"t", "k", "cls", "h", "a", "st"})
	stat = (t.type == "static")
	nextAt = (if JS.t(stat) then t.nextAtDisp else t.nextAt)
	JS.setk(n, "gain", formatWhole(nil, t.resetGain))
	JS.setk(n, "res", rbx_str(nil, t.resource))
	JS.setk(n, "verb", (if ((not (t.resetDescription == nil)) and (not (t.resetDescription == JS.NULL))) then JS.m(rbx_str(nil, t.resetDescription), "trim") else JS.NULL))
	JS.setk(n, "next", (if ((nextAt == nil) or (nextAt == JS.NULL)) then JS.NULL else rbx_nn(nil, (if JS.t(t.roundUpCost) then formatWhole(nil, nextAt) else format(nil, nextAt)))))
	JS.setk(n, "base", (if ((t.baseAmount == nil) or (t.baseAmount == JS.NULL)) then JS.NULL else formatWhole(nil, t.baseAmount)))
	JS.setk(n, "bres", rbx_str(nil, t.baseResource))
	JS.setk(n, "static", (if JS.t(stat) then true else false))
	JS.setk(n, "pr", (if JS.t(can) then JS.NULL else rbx_prCap(nil, rbx_pr(nil, t.baseAmount, (if JS.t(stat) then t.nextAt else t.requires)))))
	JS.setk(n, "hk", rbx_hk(nil, layer))
	do return n end
end
rbx_resourceDisplay = function(this, layer)
	local t, h
	t = tmp[JS.k(layer)]
	h = ""
	if JS.t(t.baseAmount) then
		h = (JS.str(h) .. ((("<br>You have " .. JS.str(formatWhole(nil, t.baseAmount))) .. " ") .. JS.str(rbx_str(nil, t.baseResource))))
	end
	if JS.t(t.passiveGeneration) then
		h = (JS.str(h) .. (((("<br>You are gaining " .. JS.str(format(nil, t.resetGain:times(t.passiveGeneration)))) .. " ") .. JS.str(rbx_str(nil, t.resource))) .. " per second"))
	end
	h = (JS.str(h) .. "<br><br>")
	if JS.t(t.showBest) then
		h = (JS.str(h) .. (((("Your best " .. JS.str(rbx_str(nil, t.resource))) .. " is ") .. JS.str(formatWhole(nil, player[JS.k(layer)].best))) .. "<br>"))
	end
	if JS.t(t.showTotal) then
		h = (JS.str(h) .. (((("You have made a total of " .. JS.str(formatWhole(nil, player[JS.k(layer)].total))) .. " ") .. JS.str(rbx_str(nil, t.resource))) .. "<br>"))
	end
	do return JS.O({
		t = "html",
		h = h,
		have = (if JS.t(t.baseAmount) then formatWhole(nil, t.baseAmount) else JS.NULL),
		bres = (if JS.t(t.baseAmount) then rbx_str(nil, t.baseResource) else JS.NULL),
		gen = (if JS.t(t.passiveGeneration) then rbx_nn(nil, format(nil, t.resetGain:times(t.passiveGeneration))) else JS.NULL),
		best = (if JS.t(t.showBest) then formatWhole(nil, player[JS.k(layer)].best) else JS.NULL),
		total = (if JS.t(t.showTotal) then formatWhole(nil, player[JS.k(layer)].total) else JS.NULL)
	}, {"t", "h", "have", "bres", "gen", "best", "total"}) end
end
rbx_upgrade = function(this, layer, id)
	local t, L, req, bought, can, h, ti, ds, ef, co, cn, custom, title, e, cd, cur, n
	t = tmp[JS.k(layer)].upgrades[JS.k(id)]
	L = layers[JS.k(layer)].upgrades[JS.k(id)]
	if (t == nil) then
		do return JS.NULL end
	end
	if (JS.t(perkUnl(nil, layer, id)) and (not JS.t(t.unlocked))) then
		req = rbx_str(nil, rbx_v(nil, t, L, "perkReq"))
		do return JS.O({
			t = "btn",
			k = "perk",
			cls = (if JS.t(t.perkCan) then "perk" else "perked"),
			a = rbx_act(nil, JS.A(3, "perk", layer, id)),
			h = ("<h3>Explore A New Perk Upgrade</h3><br>" .. JS.str(req)),
			id = id,
			req = req
		}, {"t", "k", "cls", "a", "h", "id", "req"}) end
	end
	if (not JS.t(t.unlocked)) then
		do return JS.NULL end
	end
	bought = hasUpgrade(nil, layer, id)
	can = (canAffordUpgrade(nil, layer, id) and (not JS.t(bought)))
	h = ""
	ti = JS.NULL
	ds = JS.NULL
	ef = JS.NULL
	co = JS.NULL
	cn = JS.NULL
	custom = true
	if JS.t(L.fullDisplay) then
		h = rbx_str(nil, run(nil, L.fullDisplay, L))
	else
		title = rbx_v(nil, t, L, "title")
		if JS.t(title) then
			h = (JS.str(h) .. (("<h3>" .. JS.str(title)) .. "</h3><br>"))
		end
		ti = rbx_txt(nil, title)
		ds = rbx_str(nil, rbx_v(nil, t, L, "description"))
		h = JS.add(h, ds)
		if JS.t(L.effectDisplay) then
			e = run(nil, L.effectDisplay, L)
			h = (JS.str(h) .. ("<br>Currently: " .. JS.str(e)))
			ef = rbx_txt(nil, e)
		end
		h = (JS.str(h) .. "<br>")
		cd = rbx_v(nil, t, L, "costDescription")
		if JS.t(cd) then
			h = JS.add(h, cd)
			co = rbx_str(nil, cd)
		else
			cur = rbx_v(nil, t, L, "currencyDisplayName")
			co = formatWhole(nil, t.cost)
			cn = rbx_str(nil, (if JS.t(cur) then cur else tmp[JS.k(layer)].resource))
			h = (JS.str(h) .. ((("Cost: " .. JS.str(co)) .. " ") .. JS.str(cn)))
			custom = false
		end
	end
	n = JS.O({
		t = "btn",
		k = "upg",
		cls = (if JS.t(bought) then "bought" else (if JS.t(can) then "can" else "locked")),
		n = (if JS.t(L.fullDisplay) then JS.NULL else id),
		h = h,
		a = rbx_act(nil, JS.A(3, "upg", layer, id)),
		tip = rbx_v(nil, t, L, "tooltip"),
		st = rbx_css(nil, JS.A(3, (if JS.t(can) then JS.O({
		["background-color"] = tmp[JS.k(layer)].color
	}) else JS.NULL), tmp[JS.k(layer)].componentStyles.upgrade, rbx_v(nil, t, L, "style")))
	}, {"t", "k", "cls", "n", "h", "a", "tip", "st"})
	JS.setk(n, "id", id)
	JS.setk(n, "ti", ti)
	JS.setk(n, "ds", ds)
	JS.setk(n, "ef", ef)
	JS.setk(n, "co", co)
	JS.setk(n, "cur", cn)
	JS.setk(n, "pr", (if (((JS.t(bought) or JS.t(can)) or JS.t(custom)) or (t.cost == nil)) then JS.NULL else rbx_prCap(nil, rbx_pr(nil, rbx_upgHave(nil, layer, t), t.cost))))
	do return n end
end
rbx_upgHave = function(this, layer, t)
	local name
	name = t.currencyInternalName
	if JS.t(name) then
		if JS.t(t.currencyLocation) then
			do return t.currencyLocation[JS.k(name)] end
		end
		if JS.t(t.currencyLayer) then
			do return player[JS.k(t.currencyLayer)][JS.k(name)] end
		end
		do return player[JS.k(name)] end
	end
	do return player[JS.k(layer)].points end
end
rbx_upgrades = function(this, layer)
	local t, rows, r, row, c, id, u
	t = tmp[JS.k(layer)].upgrades
	if (not JS.t(t)) then
		do return JS.NULL end
	end
	rows = JS.A(0)
	for r = 1, JS.cap(1, JS.tonum(t.rows), 1) do
		row = JS.A(0)
		for c = 1, JS.cap(1, JS.tonum(t.cols), 1) do
			id = JS.add((JS.tonum(r) * 10), c)
			if (not (t[JS.k(id)] == nil)) then
				u = rbx_upgrade(nil, layer, id)
				if JS.t(u) then
					JS.m(row, "push", u)
				end
			end
		end
		if JS.t(JS.len(row)) then
			JS.m(rows, "push", JS.O({
				t = "row",
				c = row
			}, {"t", "c"}))
		end
	end
	do return JS.O({
		t = "col",
		c = rows
	}, {"t", "c"}) end
end
rbx_toggle = function(this, toggle)
	do return JS.O({
		t = "btn",
		k = "toggle",
		cls = "can",
		h = (if JS.t(player[JS.k(toggle[0])][JS.k(toggle[1])]) then "ON" else "OFF"),
		a = rbx_act(nil, JS.A(3, "toggle", toggle[0], toggle[1])),
		st = JS.O({
		["background-color"] = rbx_str(nil, tmp[JS.k(toggle[0])].color)
	})
	}, {"t", "k", "cls", "h", "a", "st"}) end
end
rbx_milestone = function(this, layer, id)
	local t, L, done, ti, ds, h, kids, plocked, pc, i
	t = tmp[JS.k(layer)].milestones[JS.k(id)]
	L = layers[JS.k(layer)].milestones[JS.k(id)]
	if (not (((not (t == nil)) and JS.t(milestoneShown(nil, layer, id))) and JS.t(t.unlocked))) then
		do return JS.NULL end
	end
	done = hasMilestone(nil, layer, id)
	ti = rbx_str(nil, rbx_v(nil, t, L, "requirementDescription"))
	ds = rbx_str(nil, run(nil, L.effectDescription, L))
	h = (((("<h3>" .. JS.str(ti)) .. "</h3><br>") .. JS.str(ds)) .. "<br>")
	kids = JS.A(0)
	if (JS.eq(t.pseudoUnl, true) and (not JS.m(player[JS.k(layer)].pseudoBuys, "includes", id))) then
		plocked = (not player.points:gte(t.pseudoCost))
		pc = format(nil, t.pseudoCost)
		JS.m(kids, "push", JS.O({
			t = "btn",
			k = "malware",
			cls = (if JS.t(plocked) then "plocked" else "pseudo"),
			a = rbx_act(nil, JS.A(3, "malware", layer, id)),
			h = (("Infect a Milestone with Malware<br>Cost: " .. JS.str(pc)) .. " points."),
			id = id,
			co = pc
		}, {"t", "k", "cls", "a", "h", "id", "co"}))
	end
	if (JS.t(t.toggles) and JS.t(done)) then
		for i = 0, JS.cap(0, (JS.len(t.toggles)) - 1, 1) do
			JS.m(kids, "push", rbx_toggle(nil, t.toggles[JS.k(i)]))
		end
	end
	do return JS.O({
		t = "ms",
		done = done,
		h = h,
		c = kids,
		tip = rbx_v(nil, t, L, "tooltip"),
		st = rbx_css(nil, JS.A(2, tmp[JS.k(layer)].componentStyles.milestone, rbx_v(nil, t, L, "style"))),
		id = id,
		ti = ti,
		ds = ds,
		mal = (if (JS.t(player[JS.k(layer)].pseudoBuys) and JS.m(player[JS.k(layer)].pseudoBuys, "includes", rbx_str(nil, id))) then true else false)
	}, {"t", "done", "h", "c", "tip", "st", "id", "ti", "ds", "mal"}) end
end
rbx_milestones = function(this, layer, data)
	local ids, out, i, id, m
	if (not JS.t(tmp[JS.k(layer)].milestones)) then
		do return JS.NULL end
	end
	ids = data
	if (data == nil) then
		ids = Object.keys(tmp[JS.k(layer)].milestones)
		if JS.eq(options.reverseMilestones, true) then
			ids = JS.m(ids, "reverse")
		end
	end
	out = JS.A(0)
	for i = 0, JS.cap(0, (JS.len(ids)) - 1, 1) do
		id = ids[JS.k(i)]
		if (((not (tmp[JS.k(layer)].milestones[JS.k(id)] == nil)) and JS.t(tmp[JS.k(layer)].milestones[JS.k(id)].unlocked)) and JS.t(milestoneShown(nil, layer, id))) then
			m = rbx_milestone(nil, layer, id)
			if JS.t(m) then
				JS.m(out, "push", m)
			end
		end
	end
	do return JS.O({
		t = "col",
		c = out
	}, {"t", "c"}) end
end
rbx_buyHave = function(this, bc)
	do return (if JS.t(bc[0]) then player[JS.k(bc[0])][JS.k(bc[1])] else player[JS.k(bc[1])]) end
end
rbx_buyable = function(this, layer, id)
	local t, L, cls, h, title, node, maxed, pl, bc, sellOne, sellAll, kids, cls2
	t = tmp[JS.k(layer)].buyables[JS.k(id)]
	L = layers[JS.k(layer)].buyables[JS.k(id)]
	if (not ((not (t == nil)) and JS.t(t.unlocked))) then
		do return JS.NULL end
	end
	cls = (if JS.t(t.canBuy) then "can" else "locked")
	if player[JS.k(layer)].buyables[JS.k(id)]:gte(t.purchaseLimit) then
		cls = "bought"
	end
	h = ""
	title = rbx_v(nil, t, L, "title")
	if JS.t(title) then
		h = (JS.str(h) .. (("<h2>" .. JS.str(title)) .. "</h2><br>"))
	end
	h = JS.add(h, rbx_str(nil, run(nil, L.display, L)))
	node = JS.O({
		t = "btn",
		k = "buy",
		cls = cls,
		h = h,
		a = rbx_act(nil, JS.A(3, "buy", layer, id)),
		tip = rbx_v(nil, t, L, "tooltip"),
		hold = true,
		st = rbx_css(nil, JS.A(3, (if JS.t(t.canBuy) then JS.O({
		["background-color"] = tmp[JS.k(layer)].color
	}) else JS.NULL), tmp[JS.k(layer)].componentStyles.buyable, rbx_v(nil, t, L, "style")))
	}, {"t", "k", "cls", "h", "a", "tip", "hold", "st"})
	maxed = (cls == "bought")
	pl = t.purchaseLimit
	bc = (if JS.t(rbx_BUY_CUR[JS.k(layer)]) then rbx_BUY_CUR[JS.k(layer)][JS.k(id)] else nil)
	JS.setk(node, "id", id)
	JS.setk(node, "ti", rbx_txt(nil, title))
	JS.setk(node, "lv", formatWhole(nil, player[JS.k(layer)].buyables[JS.k(id)]))
	JS.setk(node, "max", (if (((not (pl == nil)) and (not (pl == JS.NULL))) and (JS.D(pl)):lt("1e300")) then formatWhole(nil, pl) else JS.NULL))
	JS.setk(node, "co", (if ((t.cost == nil) or (t.cost == JS.NULL)) then JS.NULL else rbx_nn(nil, format(nil, t.cost))))
	JS.setk(node, "cur", (if JS.t(bc) then (if JS.t(bc[2]) then bc[2] else (if JS.t(bc[0]) then rbx_str(nil, tmp[JS.k(bc[0])].resource) else rbx_str(nil, modInfo.pointsName))) else JS.NULL))
	JS.setk(node, "pr", (if ((((not JS.t(bc)) or JS.t(maxed)) or JS.t(t.canAfford)) or (t.cost == nil)) then JS.NULL else rbx_prCap(nil, rbx_pr(nil, rbx_buyHave(nil, bc), t.cost))))
	sellOne = (if JS.t(t.sellOne) then (not ((not (t.canSellOne == nil)) and JS.eq(t.canSellOne, false))) else t.sellOne)
	sellAll = (if JS.t(t.sellAll) then (not ((not (t.canSellAll == nil)) and JS.eq(t.canSellAll, false))) else t.sellAll)
	if ((not JS.t(sellOne)) and (not JS.t(sellAll))) then
		do return node end
	end
	kids = JS.A(1, node)
	cls2 = (if JS.t(player[JS.k(layer)].unlocked) then "can" else "locked")
	if JS.t(sellOne) then
		JS.m(kids, "push", JS.O({
			t = "btn",
			k = "sell",
			cls = cls2,
			h = (if JS.t(tmp[JS.k(layer)].buyables.sellOneText) then tmp[JS.k(layer)].buyables.sellOneText else "Sell One"),
			a = rbx_act(nil, JS.A(3, "sellOne", layer, id))
		}, {"t", "k", "cls", "h", "a"}))
	end
	if JS.t(sellAll) then
		JS.m(kids, "push", JS.O({
			t = "btn",
			k = "sell",
			cls = cls2,
			h = (if JS.t(tmp[JS.k(layer)].buyables.sellAllText) then tmp[JS.k(layer)].buyables.sellAllText else "Sell All"),
			a = rbx_act(nil, JS.A(3, "sellAll", layer, id))
		}, {"t", "k", "cls", "h", "a"}))
	end
	do return JS.O({
		t = "col",
		c = kids
	}, {"t", "c"}) end
end
rbx_rowsOf = function(this, t, data)
	local rows, out, i, r
	rows = (if (data == nil) then t.rows else data)
	out = JS.A(0)
	if Array.isArray(rows) then
		for i = 0, JS.cap(0, (JS.len(rows)) - 1, 1) do
			JS.m(out, "push", rows[JS.k(i)])
		end
	else
		for r = 1, JS.cap(1, JS.tonum(rows), 1) do
			JS.m(out, "push", r)
		end
	end
	do return out end
end
rbx_buyables = function(this, layer, data)
	local t, out, rows, i, row, c, id, b
	t = tmp[JS.k(layer)].buyables
	if (not JS.t(t)) then
		do return JS.NULL end
	end
	out = JS.A(0)
	if (JS.t(t.respec) and (not ((not (t.showRespec == nil)) and JS.eq(t.showRespec, false)))) then
		JS.m(out, "push", JS.O({
			t = "btn",
			k = "respec",
			cls = (if JS.t(player[JS.k(layer)].unlocked) then "can" else "locked"),
			a = rbx_act(nil, JS.A(2, "respec", layer)),
			h = (if JS.t(t.respecText) then t.respecText else "Respec"),
			st = rbx_css(nil, JS.A(1, tmp[JS.k(layer)].componentStyles["respec-button"]))
		}, {"t", "k", "cls", "a", "h", "st"}))
	end
	rows = rbx_rowsOf(nil, t, data)
	for i = 0, JS.cap(0, (JS.len(rows)) - 1, 1) do
		row = JS.A(0)
		for c = 1, JS.cap(1, JS.tonum(t.cols), 1) do
			id = JS.add((JS.tonum(rows[JS.k(i)]) * 10), c)
			if ((not (t[JS.k(id)] == nil)) and JS.t(t[JS.k(id)].unlocked)) then
				b = rbx_buyable(nil, layer, id)
				if JS.t(b) then
					JS.m(row, "push", b)
				end
			end
		end
		if JS.t(JS.len(row)) then
			JS.m(out, "push", JS.O({
				t = "row",
				c = row
			}, {"t", "c"}))
		end
	end
	do return JS.O({
		t = "col",
		c = out
	}, {"t", "c"}) end
end
rbx_clickable = function(this, layer, id)
	local t, L, h, title
	t = tmp[JS.k(layer)].clickables[JS.k(id)]
	L = layers[JS.k(layer)].clickables[JS.k(id)]
	if (not ((not (t == nil)) and JS.t(t.unlocked))) then
		do return JS.NULL end
	end
	h = ""
	title = rbx_v(nil, t, L, "title")
	if JS.t(title) then
		h = (JS.str(h) .. (("<h2>" .. JS.str(title)) .. "</h2><br>"))
	end
	h = JS.add(h, rbx_str(nil, run(nil, L.display, L)))
	do return JS.O({
		t = "btn",
		k = "click",
		cls = (if JS.t(t.canClick) then "can" else "locked"),
		h = h,
		a = rbx_act(nil, JS.A(3, "click", layer, id)),
		tip = rbx_v(nil, t, L, "tooltip"),
		hold = (if JS.t(L.onHold) then true else JS.NULL),
		st = rbx_css(nil, JS.A(3, (if JS.t(t.canClick) then JS.O({
		["background-color"] = tmp[JS.k(layer)].color
	}) else JS.NULL), tmp[JS.k(layer)].componentStyles.clickable, rbx_v(nil, t, L, "style"))),
		id = id,
		ti = rbx_txt(nil, title)
	}, {"t", "k", "cls", "h", "a", "tip", "hold", "st", "id", "ti"}) end
end
rbx_clickables = function(this, layer, data)
	local t, out, rows, i, row, c, id, b
	t = tmp[JS.k(layer)].clickables
	if (not JS.t(t)) then
		do return JS.NULL end
	end
	out = JS.A(0)
	if (JS.t(t.masterButtonPress) and (not ((not (t.showMasterButton == nil)) and JS.eq(t.showMasterButton, false)))) then
		JS.m(out, "push", JS.O({
			t = "btn",
			k = "master",
			cls = (if JS.t(player[JS.k(layer)].unlocked) then "can" else "locked"),
			a = rbx_act(nil, JS.A(2, "master", layer)),
			h = (if JS.t(t.masterButtonText) then t.masterButtonText else "Click me!"),
			st = rbx_css(nil, JS.A(1, tmp[JS.k(layer)].componentStyles["master-button"]))
		}, {"t", "k", "cls", "a", "h", "st"}))
	end
	rows = rbx_rowsOf(nil, t, data)
	for i = 0, JS.cap(0, (JS.len(rows)) - 1, 1) do
		row = JS.A(0)
		for c = 1, JS.cap(1, JS.tonum(t.cols), 1) do
			id = JS.add((JS.tonum(rows[JS.k(i)]) * 10), c)
			if ((not (t[JS.k(id)] == nil)) and JS.t(t[JS.k(id)].unlocked)) then
				b = rbx_clickable(nil, layer, id)
				if JS.t(b) then
					JS.m(row, "push", b)
				end
			end
		end
		if JS.t(JS.len(row)) then
			JS.m(out, "push", JS.O({
				t = "row",
				c = row
			}, {"t", "c"}))
		end
	end
	do return JS.O({
		t = "col",
		c = out
	}, {"t", "c"}) end
end
rbx_challenge = function(this, layer, id)
	local t, L, cls, btn, body, ds, goal, rw, rcur, gd, cur, rd, active, name, lim
	t = tmp[JS.k(layer)].challenges[JS.k(id)]
	L = layers[JS.k(layer)].challenges[JS.k(id)]
	if (not (((not (t == nil)) and JS.t(t.unlocked)) and (not ((JS.t(options.hideChallenges) and maxedChallenge(nil, layer, id)) and (not inChallenge(nil, layer, id)))))) then
		do return JS.NULL end
	end
	cls = challengeStyle(nil, layer, id)
	btn = JS.O({
		t = "btn",
		k = "chalbtn",
		cls = "can",
		h = challengeButtonText(nil, layer, id),
		a = rbx_act(nil, JS.A(3, "chal", layer, id)),
		st = rbx_css(nil, JS.A(1, (if JS.t(rbx_v(nil, t, L, "buttonStyle")) then rbx_v(nil, t, L, "buttonStyle") else JS.O({
		["background-color"] = tmp[JS.k(layer)].color
	}))))
	}, {"t", "k", "cls", "h", "a", "st"})
	body = ""
	ds = JS.NULL
	goal = JS.NULL
	rw = JS.NULL
	rcur = JS.NULL
	if JS.t(L.fullDisplay) then
		body = rbx_str(nil, run(nil, L.fullDisplay, L))
	else
		ds = rbx_str(nil, rbx_v(nil, t, L, "challengeDescription"))
		body = (JS.str(ds) .. "<br>Goal:  ")
		gd = rbx_v(nil, t, L, "goalDescription")
		if JS.t(gd) then
			goal = rbx_str(nil, gd)
		else
			cur = rbx_v(nil, t, L, "currencyDisplayName")
			goal = ((JS.str(format(nil, t.goal)) .. " ") .. JS.str(rbx_str(nil, (if JS.t(cur) then cur else modInfo.pointsName))))
		end
		body = JS.add(body, goal)
		rw = rbx_str(nil, rbx_v(nil, t, L, "rewardDescription"))
		body = (JS.str(body) .. (("<br>Reward: " .. JS.str(rw)) .. "<br>"))
		if (not (L.rewardDisplay == nil)) then
			rd = (if JS.t(t.rewardDisplay) then run(nil, L.rewardDisplay, L) else format(nil, t.rewardEffect))
			body = (JS.str(body) .. ("Currently: " .. JS.str(rd)))
			rcur = rbx_txt(nil, rd)
		end
	end
	active = JS.eq(player[JS.k(layer)].activeChallenge, id)
	name = rbx_str(nil, rbx_v(nil, t, L, "name"))
	lim = t.completionLimit
	do return JS.O({
		t = "chal",
		cls = cls,
		active = active,
		st = rbx_css(nil, JS.A(2, tmp[JS.k(layer)].componentStyles.challenge, rbx_v(nil, t, L, "style"))),
		c = JS.A(3, JS.O({
		t = "html",
		h = (("<h3>" .. JS.str(name)) .. "</h3>")
	}, {"t", "h"}), btn, JS.O({
		t = "html",
		h = body
	}, {"t", "h"})),
		id = id,
		ti = name,
		ds = ds,
		goal = goal,
		rw = rw,
		cur = rcur,
		cmp = formatWhole(nil, challengeCompletions(nil, layer, id)),
		lim = (if (((not (lim == nil)) and (not (lim == JS.NULL))) and (not JS.eq(lim, 1))) then rbx_str(nil, lim) else JS.NULL),
		st8 = (if JS.t(active) then (if canCompleteChallenge(nil, layer, id) then "completable" else "active") else (if maxedChallenge(nil, layer, id) then "done" else "idle"))
	}, {"t", "cls", "active", "st", "c", "id", "ti", "ds", "goal", "rw", "cur", "cmp", "lim", "st8"}) end
end
rbx_challenges = function(this, layer, data)
	local t, out, rows, i, row, c, id, ch
	t = tmp[JS.k(layer)].challenges
	if (not JS.t(t)) then
		do return JS.NULL end
	end
	out = JS.A(0)
	rows = rbx_rowsOf(nil, t, data)
	for i = 0, JS.cap(0, (JS.len(rows)) - 1, 1) do
		row = JS.A(0)
		for c = 1, JS.cap(1, JS.tonum(t.cols), 1) do
			id = JS.add((JS.tonum(rows[JS.k(i)]) * 10), c)
			if ((not (t[JS.k(id)] == nil)) and JS.t(t[JS.k(id)].unlocked)) then
				ch = rbx_challenge(nil, layer, id)
				if JS.t(ch) then
					JS.m(row, "push", ch)
				end
			end
		end
		if JS.t(JS.len(row)) then
			JS.m(out, "push", JS.O({
				t = "row",
				c = row
			}, {"t", "c"}))
		end
	end
	do return JS.O({
		t = "col",
		c = out
	}, {"t", "c"}) end
end
rbx_achievement = function(this, layer, id)
	local t, L, done, tip, text, dt, gt, name
	t = tmp[JS.k(layer)].achievements[JS.k(id)]
	L = layers[JS.k(layer)].achievements[JS.k(id)]
	if (not ((not (t == nil)) and JS.t(t.unlocked))) then
		do return JS.NULL end
	end
	done = hasAchievement(nil, layer, id)
	tip = rbx_v(nil, t, L, "tooltip")
	if JS.eq(tip, "") then
		text = JS.NULL
	elseif JS.t(done) then
		dt = rbx_v(nil, t, L, "doneTooltip")
		text = (if JS.t(dt) then dt else (if JS.t(tip) then tip else "You did it!"))
	else
		gt = rbx_v(nil, t, L, "goalTooltip")
		text = (if JS.t(gt) then gt else (if JS.t(tip) then tip else "LOCKED"))
	end
	name = rbx_v(nil, t, L, "name")
	do return JS.O({
		t = "ach",
		done = done,
		tip = text,
		num = (if (Math.floor((JS.tonum(id) / 10)) <= 1) then (JS.tonum(id) - 10) else (JS.tonum(id) - 11)),
		h = (if JS.t(name) then (("<h3>" .. JS.str(name)) .. "</h3>") else ""),
		st = rbx_css(nil, JS.A(2, tmp[JS.k(layer)].componentStyles.achievement, rbx_v(nil, t, L, "style"))),
		id = id,
		ti = rbx_txt(nil, name)
	}, {"t", "done", "tip", "num", "h", "st", "id", "ti"}) end
end
rbx_achievements = function(this, layer, data)
	local t, out, rows, i, row, c, id, a
	t = tmp[JS.k(layer)].achievements
	if (not JS.t(t)) then
		do return JS.NULL end
	end
	out = JS.A(0)
	rows = rbx_rowsOf(nil, t, data)
	for i = 0, JS.cap(0, (JS.len(rows)) - 1, 1) do
		row = JS.A(0)
		for c = 1, JS.cap(1, JS.tonum(t.cols), 1) do
			id = JS.add((JS.tonum(rows[JS.k(i)]) * 10), c)
			if ((not (t[JS.k(id)] == nil)) and JS.t(t[JS.k(id)].unlocked)) then
				a = rbx_achievement(nil, layer, id)
				if JS.t(a) then
					JS.m(row, "push", a)
				end
			end
		end
		if JS.t(JS.len(row)) then
			JS.m(out, "push", JS.O({
				t = "row",
				c = row
			}, {"t", "c"}))
		end
	end
	do return JS.O({
		t = "col",
		c = out
	}, {"t", "c"}) end
end
rbx_gridable = function(this, layer, id)
	local g, data, can, h, n
	g = layers[JS.k(layer)].grid
	data = player[JS.k(layer)].grid[JS.k(id)]
	if (not ((not (data == nil)) and JS.t(gridRun(nil, layer, "getUnlocked", data, id)))) then
		do return JS.NULL end
	end
	can = gridRun(nil, layer, "getCanClick", data, id)
	h = ""
	if JS.t(g.getTitle) then
		h = (JS.str(h) .. (("<h3>" .. JS.str(rbx_str(nil, gridRun(nil, layer, "getTitle", data, id)))) .. "</h3><br>"))
	end
	h = JS.add(h, rbx_str(nil, gridRun(nil, layer, "getDisplay", data, id)))
	n = JS.O({
		t = "btn",
		k = "grid",
		cls = (if JS.t(can) then "can" else "locked"),
		h = h,
		a = rbx_act(nil, JS.A(3, "grid", layer, id)),
		hold = (if JS.t(g.onHold) then true else JS.NULL),
		tip = (if JS.t(g.getTooltip) then gridRun(nil, layer, "getTooltip", data, id) else JS.NULL),
		st = rbx_css(nil, JS.A(3, (if JS.t(can) then JS.O({
		["background-color"] = tmp[JS.k(layer)].color
	}) else JS.NULL), tmp[JS.k(layer)].componentStyles.gridable, gridRun(nil, layer, "getStyle", data, id)))
	}, {"t", "k", "cls", "h", "a", "hold", "tip", "st"})
	if (layer == "cp") then
		rbx_cpCell(nil, n, data, id)
	end
	do return n end
end
rbx_cpCell = function(this, n, data, id)
	local lv, pm, chosen, gs, cost, have, r
	lv = (if JS.t(data.level) then data.level else 0)
	pm = (data.type == "pm")
	chosen = (if JS.t(pm) then JS.eq(player.cp.chosenBackdoor, id) else JS.eq(player.cp.trojanChosen, id))
	gs = (if (JS.tonum(lv) < 1) then "empty" else (if JS.eq(data.active, true) then "active" else (if JS.t(chosen) then "chosen" else "corrupted")))
	JS.setk(n, "id", id)
	JS.setk(n, "gs", gs)
	JS.setk(n, "lv", lv)
	JS.setk(n, "kind", (if JS.t(pm) then "backdoor" else "trojan"))
	JS.setk(n, "caut", (if JS.t(data.cautPower) then data.cautPower else 0))
	JS.setk(n, "gx", JS.NULL)
	JS.setk(n, "gp", JS.NULL)
	if (JS.tonum(lv) < 1) then
		do return end
	end
	cost = gridCost(nil, "cp", id)
	JS.setk(n, "gx", JS.O({
		fix = format(nil, cost),
		fres = (if JS.t(pm) then "prestige essences" else "points"),
		deb = format(nil, gridEffect(nil, "cp", id), 5),
		rew = format(nil, gridEssence(nil, "cp", id), 0)
	}, {"fix", "fres", "deb", "rew"}))
	if ((gs == "active") or (gs == "chosen")) then
		have = (if (gs == "chosen") then (if JS.t(pm) then player.cp.peInCorrupt:add(1) else player.cp.pointsInCorrupt:add(1)) else (if JS.t(pm) then player.pm.essence else player.points))
		r = (JS.D(have)):div(cost)
		JS.setk(n, "gp", (if r:gte(1) then 1000 else (if r:gt(0) then Math.min(999, Math.floor((r:toNumber() * 1000))) else 0)))
	end
end
rbx_grid = function(this, layer, data)
	local t, out, rows, i, row, c, id, b
	t = tmp[JS.k(layer)].grid
	if (not JS.t(t)) then
		do return JS.NULL end
	end
	out = JS.A(0)
	rows = rbx_rowsOf(nil, t, data)
	for i = 0, JS.cap(0, (JS.len(rows)) - 1, 1) do
		row = JS.A(0)
		for c = 1, JS.cap(1, JS.tonum(t.cols), 1) do
			id = JS.add((JS.tonum(rows[JS.k(i)]) * 100), c)
			if JS.t(run(nil, layers[JS.k(layer)].grid.getUnlocked, layers[JS.k(layer)].grid, id)) then
				b = rbx_gridable(nil, layer, id)
				if JS.t(b) then
					JS.m(row, "push", b)
				end
			end
		end
		if JS.t(JS.len(row)) then
			JS.m(out, "push", JS.O({
				t = "row",
				c = row
			}, {"t", "c"}))
		end
	end
	do return JS.O({
		t = "col",
		c = out
	}, {"t", "c"}) end
end
rbx_infobox = function(this, layer, id)
	local t, shut
	t = tmp[JS.k(layer)].infoboxes
	if (not ((JS.t(t) and (not (t[JS.k(id)] == nil))) and JS.t(t[JS.k(id)].unlocked))) then
		do return JS.NULL end
	end
	shut = player.infoboxes[JS.k(layer)][JS.k(id)]
	do return JS.O({
		t = "info",
		shut = (if JS.t(shut) then true else false),
		color = rbx_str(nil, tmp[JS.k(layer)].color),
		a = rbx_act(nil, JS.A(3, "infobox", layer, id)),
		title = rbx_str(nil, (if JS.t(t[JS.k(id)].title) then t[JS.k(id)].title else tmp[JS.k(layer)].name)),
		body = rbx_str(nil, (if JS.t(t[JS.k(id)].body) then t[JS.k(id)].body else "Blah")),
		st = rbx_css(nil, JS.A(1, t[JS.k(id)].style))
	}, {"t", "shut", "color", "a", "title", "body", "st"}) end
end
rbx_burnBar = function(this, id)
	local html, timer, perm, p
	html = rbx_burnHtml(nil, id)
	if (not JS.t(html)) then
		do return JS.NULL end
	end
	timer = player.sp.timer[JS.k(id)]
	perm = JS.eq(tmp.sp.milestones[JS.k(id)].permanent, true)
	p = (if ((JS.t(perm) or (timer == nil)) or (timer == JS.NULL)) then 1 else (1 - Math.max(0, ((240 - JS.tonum(timer)) / 240))))
	do return JS.O({
		t = "bar",
		w = 300,
		hh = 44,
		p = p,
		dir = 3,
		h = rbx_str(nil, html[1]),
		st = JS.O({}),
		fill = JS.O({}),
		base = JS.O({}),
		id = id,
		st8 = (if JS.t(perm) then "permanent" else (if JS.eq(timer, 0) then "ashed" else "burning")),
		bp = Math.max(0, Math.min(1000, Math.floor((JS.tonum(p) * 1000))))
	}, {"t", "w", "hh", "p", "dir", "h", "st", "fill", "base", "id", "st8", "bp"}) end
end
rbx_bar = function(this, layer, id)
	local t, b, p
	t = tmp[JS.k(layer)].bars
	if (not ((JS.t(t) and JS.t(t[JS.k(id)])) and JS.t(t[JS.k(id)].unlocked))) then
		do return JS.NULL end
	end
	b = t[JS.k(id)]
	p = b.progress
	if JS.instanceof(p, Decimal) then
		p = p:toNumber()
	end
	p = Math.min(Math.max(p, 0), 1)
	do return JS.O({
		t = "bar",
		w = b.width,
		hh = b.height,
		p = p,
		dir = b.direction,
		h = rbx_str(nil, run(nil, layers[JS.k(layer)].bars[JS.k(id)].display, layers[JS.k(layer)].bars[JS.k(id)])),
		st = rbx_css(nil, JS.A(2, b.style, b.borderStyle)),
		fill = rbx_css(nil, JS.A(2, b.style, b.fillStyle)),
		base = rbx_css(nil, JS.A(2, b.style, b.baseStyle))
	}, {"t", "w", "hh", "p", "dir", "h", "st", "fill", "base"}) end
end
rbx_tabButtons = function(this, layer, data, name)
	local out, keys, i, tab, glow, cur
	out = JS.A(0)
	keys = Object.keys(data)
	for i = 0, JS.cap(0, (JS.len(keys)) - 1, 1) do
		tab = keys[JS.k(i)]
		if (JS.isnil(data[JS.k(tab)].unlocked) or JS.t(data[JS.k(tab)].unlocked)) then
			glow = subtabShouldNotify(nil, layer, name, tab)
			cur = JS.eq(player.subtabs[JS.k(layer)][JS.k(name)], tab)
			JS.m(out, "push", JS.O({
				t = "btn",
				k = "tab",
				cls = (if JS.t(cur) then "cur" else "can"),
				h = tab,
				a = rbx_act(nil, JS.A(4, "subtab", layer, name, tab)),
				glow = (if JS.t(glow) then rbx_str(nil, (if JS.t(data[JS.k(tab)].glowColor) then data[JS.k(tab)].glowColor else defaultGlow)) else JS.NULL),
				pulse = (if JS.t(subtabResetNotify(nil, layer, name, tab)) then true else JS.NULL),
				st = rbx_css(nil, JS.A(3, JS.O({
				["border-color"] = tmp[JS.k(layer)].color
			}), tmp[JS.k(layer)].componentStyles["tab-button"], data[JS.k(tab)].buttonStyle))
			}, {"t", "k", "cls", "h", "a", "glow", "pulse", "st"}))
		end
	end
	do return JS.O({
		t = "tabs",
		c = out
	}, {"t", "c"}) end
end
rbx_microtabs = function(this, layer, family)
	local m, cur, kids
	m = tmp[JS.k(layer)].microtabs
	if (not JS.t(m)) then
		do return JS.NULL end
	end
	cur = m[JS.k(family)][JS.k(player.subtabs[JS.k(layer)][JS.k(family)])]
	kids = JS.A(1, rbx_tabButtons(nil, layer, m[JS.k(family)], family))
	if JS.t(cur) then
		if JS.t(cur.embedLayer) then
			JS.m(kids, "push", rbx_layerTab(nil, cur.embedLayer, true))
		else
			JS.m(kids, "push", rbx_column(nil, layer, cur.content, cur.style))
		end
	end
	do return JS.O({
		t = "col",
		c = kids,
		st = JS.O({
		["border-style"] = "solid"
	})
	}, {"t", "c", "st"}) end
end
rbx_thingTree = function(this, layer, data, type_)
	local out, r, row, i, id, t, n
	out = JS.A(0)
	for r = 0, JS.cap(0, (JS.len(data)) - 1, 1) do
		row = JS.A(0)
		for i = 0, JS.cap(0, (JS.len(data[JS.k(r)])) - 1, 1) do
			id = data[JS.k(r)][JS.k(i)]
			t = tmp[JS.k(layer)][JS.k((JS.str(type_) .. "s"))][JS.k(id)]
			if ((not (t == nil)) and JS.t(t.unlocked)) then
				n = (if (type_ == "upgrade") then rbx_upgrade(nil, layer, id) else (if (type_ == "buyable") then rbx_buyable(nil, layer, id) else rbx_clickable(nil, layer, id)))
				if JS.t(n) then
					JS.m(row, "push", n)
				end
			end
		end
		JS.m(out, "push", JS.O({
			t = "row",
			c = row
		}, {"t", "c"}))
	end
	do return JS.O({
		t = "col",
		c = out
	}, {"t", "c"}) end
end
rbx_component = function(this, layer, item, ci)
	local name, data, style, n, st
	name = item
	data = nil
	style = nil
	if Array.isArray(item) then
		name = item[0]
		data = item[1]
		if JS.eq(JS.len(item), 3) then
			style = item[2]
		end
	end
	if (((item == nil) or (item == JS.NULL)) or (item == "")) then
		do return JS.NULL end
	end
	do
		local __ok2, __e3 = pcall(function()
			n = rbx_componentNode(nil, layer, name, data)
		end)
		if not __ok2 then
			local e = __e3
			n = rbx_err(nil, rbx_str(nil, name), e)
		end
	end
	if (not JS.t(n)) then
		do return JS.NULL end
	end
	st = rbx_css(nil, JS.A(2, tmp[JS.k(layer)].componentStyles[JS.k(name)], style))
	if JS.t(JS.len(Object.keys(st))) then
		JS.setk(n, "cst", st)
	end
	JS.setk(n, "cn", rbx_str(nil, name))
	JS.setk(n, "ci", (if JS.t(ci) then ci else JS.NULL))
	do return n end
end
rbx_componentNode = function(this, layer, name, data)
	do
		local __sw4 = name
		local __ft5 = false
		repeat
			if __ft5 or JS.eq(__sw4, "display-text") then
				__ft5 = true

			end
			if __ft5 or JS.eq(__sw4, "raw-html") then
				__ft5 = true
				do return JS.O({
					t = "html",
					h = rbx_str(nil, data)
				}, {"t", "h"}) end
			end
			if __ft5 or JS.eq(__sw4, "blank") then
				__ft5 = true
				if (not JS.t(data)) then
					do return JS.O({
						t = "blank",
						w = "8px",
						hh = "17px"
					}, {"t", "w", "hh"}) end
				end
				if Array.isArray(data) then
					do return JS.O({
						t = "blank",
						w = rbx_str(nil, data[0]),
						hh = rbx_str(nil, data[1])
					}, {"t", "w", "hh"}) end
				end
				do return JS.O({
					t = "blank",
					w = "8px",
					hh = rbx_str(nil, data)
				}, {"t", "w", "hh"}) end
			end
			if __ft5 or JS.eq(__sw4, "display-image") then
				__ft5 = true
				do return JS.O({
					t = "html",
					h = ""
				}, {"t", "h"}) end
			end
			if __ft5 or JS.eq(__sw4, "row") then
				__ft5 = true
				do return rbx_container(nil, "row", layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "column") then
				__ft5 = true
				do return rbx_container(nil, "col", layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "layer-proxy") then
				__ft5 = true
				do return rbx_column(nil, data[0], data[1]) end
			end
			if __ft5 or JS.eq(__sw4, "infobox") then
				__ft5 = true
				do return rbx_infobox(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "h-line") then
				__ft5 = true
				do return JS.O({
					t = "hr",
					w = (if JS.t(data) then rbx_str(nil, data) else JS.NULL)
				}, {"t", "w"}) end
			end
			if __ft5 or JS.eq(__sw4, "v-line") then
				__ft5 = true
				do return JS.O({
					t = "blank",
					w = "2px",
					hh = (if JS.t(data) then rbx_str(nil, data) else "10px")
				}, {"t", "w", "hh"}) end
			end
			if __ft5 or JS.eq(__sw4, "challenges") then
				__ft5 = true
				do return rbx_challenges(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "challenge") then
				__ft5 = true
				do return rbx_challenge(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "upgrades") then
				__ft5 = true
				do return rbx_upgrades(nil, layer) end
			end
			if __ft5 or JS.eq(__sw4, "upgrade") then
				__ft5 = true
				do return rbx_upgrade(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "milestones") then
				__ft5 = true
				do return rbx_milestones(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "milestone") then
				__ft5 = true
				do return rbx_milestone(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "toggle") then
				__ft5 = true
				do return rbx_toggle(nil, data) end
			end
			if __ft5 or JS.eq(__sw4, "prestige-button") then
				__ft5 = true
				do return rbx_prestigeButton(nil, layer) end
			end
			if __ft5 or JS.eq(__sw4, "main-display") then
				__ft5 = true
				do return rbx_mainDisplay(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "resource-display") then
				__ft5 = true
				do return rbx_resourceDisplay(nil, layer) end
			end
			if __ft5 or JS.eq(__sw4, "buyables") then
				__ft5 = true
				do return rbx_buyables(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "buyable") then
				__ft5 = true
				do return rbx_buyable(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "clickables") then
				__ft5 = true
				do return rbx_clickables(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "clickable") then
				__ft5 = true
				do return rbx_clickable(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "grid") then
				__ft5 = true
				do return rbx_grid(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "microtabs") then
				__ft5 = true
				do return rbx_microtabs(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "bar") then
				__ft5 = true
				do return rbx_bar(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "achievements") then
				__ft5 = true
				do return rbx_achievements(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "achievement") then
				__ft5 = true
				do return rbx_achievement(nil, layer, data) end
			end
			if __ft5 or JS.eq(__sw4, "upgrade-tree") then
				__ft5 = true
				do return rbx_thingTree(nil, layer, data, "upgrade") end
			end
			if __ft5 or JS.eq(__sw4, "buyable-tree") then
				__ft5 = true
				do return rbx_thingTree(nil, layer, data, "buyable") end
			end
			if __ft5 or JS.eq(__sw4, "clickable-tree") then
				__ft5 = true
				do return rbx_thingTree(nil, layer, data, "clickable") end
			end
			if __ft5 or JS.eq(__sw4, "rbx-burn") then
				__ft5 = true
				do return rbx_burnBar(nil, data) end
			end
		until true
	end
	do return JS.O({
		t = "html",
		h = ""
	}, {"t", "h"}) end
end
rbx_container = function(this, t, layer, data)
	local out, i, n
	out = JS.A(0)
	if JS.t(data) then
		for i = 0, JS.cap(0, (JS.len(data)) - 1, 1) do
			n = rbx_component(nil, layer, data[JS.k(i)], JS.add(i, 1))
			if JS.t(n) then
				JS.m(out, "push", n)
			end
		end
	end
	do return JS.O({
		t = t,
		c = out
	}, {"t", "c"}) end
end
rbx_column = function(this, layer, data, style)
	local n
	n = rbx_container(nil, "col", layer, data)
	if JS.t(style) then
		JS.setk(n, "st", rbx_css(nil, JS.A(1, style)))
	end
	do return n end
end
rbx_layerTab = function(this, layer, embedded)
	local t, out, cur, kids, i
	t = tmp[JS.k(layer)]
	out = JS.A(0)
	if (not JS.t(t.tabFormat)) then
		if JS.t(t.infoboxes) then
			JS.m(out, "push", rbx_infobox(nil, layer, Object.keys(t.infoboxes)[0]))
		end
		JS.m(out, "push", rbx_component(nil, layer, "main-display", 1))
		if (not (t.type == "none")) then
			JS.m(out, "push", rbx_component(nil, layer, "prestige-button", 2))
		end
		JS.m(out, "push", rbx_component(nil, layer, "resource-display", 3))
		JS.m(out, "push", rbx_component(nil, layer, "milestones", 4))
		if Array.isArray(t.midsection) then
			JS.m(out, "push", rbx_column(nil, layer, t.midsection))
		end
		JS.m(out, "push", rbx_component(nil, layer, "clickables", 6))
		JS.m(out, "push", rbx_component(nil, layer, "buyables", 7))
		JS.m(out, "push", rbx_component(nil, layer, "upgrades", 8))
		JS.m(out, "push", rbx_component(nil, layer, "challenges", 9))
		JS.m(out, "push", rbx_component(nil, layer, "achievements", 10))
	elseif Array.isArray(t.tabFormat) then
		JS.m(out, "push", rbx_column(nil, layer, t.tabFormat))
	else
		cur = t.tabFormat[JS.k(player.subtabs[JS.k(layer)].mainTabs)]
		JS.m(out, "push", rbx_tabButtons(nil, layer, t.tabFormat, "mainTabs"))
		if JS.t(cur.embedLayer) then
			JS.m(out, "push", rbx_layerTab(nil, cur.embedLayer, true))
		else
			JS.m(out, "push", rbx_column(nil, layer, cur.content))
		end
	end
	kids = JS.A(0)
	for i = 0, JS.cap(0, (JS.len(out)) - 1, 1) do
		if JS.t(out[JS.k(i)]) then
			JS.m(kids, "push", out[JS.k(i)])
		end
	end
	do return JS.O({
		t = "col",
		c = kids
	}, {"t", "c"}) end
end
rbx_tabStyle = function(this, layer)
	local t, sub
	t = tmp[JS.k(layer)]
	if (not JS.t(t)) then
		do return JS.O({}) end
	end
	sub = (if (JS.t(t.tabFormat) and (not Array.isArray(t.tabFormat))) then t.tabFormat[JS.k(player.subtabs[JS.k(layer)].mainTabs)].style else JS.NULL)
	do return rbx_css(nil, JS.A(2, (if JS.t(t.style) then t.style else JS.NULL), sub)) end
end
rbx_opt = function(this, label, sub, a, ti, val, idx, n, on)
	do return JS.O({
		t = "btn",
		k = "opt",
		cls = "can",
		h = (((("<b>" .. JS.str(label)) .. "</b><br><span style=\"font-size:12px\">") .. JS.str(sub)) .. "</span>"),
		a = rbx_act(nil, a),
		id = a[1],
		ti = ti,
		val = (if (val == nil) then JS.NULL else val),
		idx = (if (idx == nil) then JS.NULL else idx),
		n = (if (n == nil) then JS.NULL else n),
		on = (if (on == nil) then JS.NULL else (if JS.t(on) then true else false))
	}, {"t", "k", "cls", "h", "a", "id", "ti", "val", "idx", "n", "on"}) end
end
rbx_about = function(this)
	local keys, key, k, d, i
	keys = JS.A(0)
	for _, __k6 in JS.keys(hotkeys) do
		key = __k6
		k = hotkeys[key]
		if (JS.t(player[JS.k(k.layer)].unlocked) and JS.t(tmp[JS.k(k.layer)].hotkeys[JS.k(k.id)].unlocked)) then
			d = rbx_str(nil, k.description)
			i = JS.m(d, "indexOf", ":")
			JS.m(keys, "push", JS.O({
				k = (if (JS.tonum(i) > 0) then JS.m(d, "substring", 0, i) else rbx_str(nil, key)),
				d = (if (JS.tonum(i) > 0) then JS.m(JS.m(d, "substring", JS.add(i, 1)), "trim") else d)
			}, {"k", "d"}))
		end
	end
	do return JS.O({
		t = "about",
		name = rbx_str(nil, modInfo.name),
		ver = rbx_str(nil, VERSION.withName),
		author = (if JS.t(modInfo.author) then rbx_str(nil, modInfo.author) else JS.NULL),
		tmt = (("The Modding Tree " .. JS.str(TMT_VERSION.tmtNum)) .. " by Acamaeda"),
		pt = "The Prestige Tree made by Jacorb and Aarex",
		keys = keys
	}, {"t", "name", "ver", "author", "tmt", "pt", "keys"}) end
end
rbx_optionsTab = function(this)
	local ms, cc, saving, displays
	ms = JS.m(MS_SETTINGS, "indexOf", options.msDisplay)
	cc = JS.m(CCTP_SETTINGS, "indexOf", options.changeCorruptTooltipPlace)
	saving = JS.O({
		t = "row",
		c = JS.A(2, rbx_opt(nil, "Save", "Save now (the game also saves automatically)", JS.A(2, "opt", "save"), "Save"), rbx_opt(nil, (("Offline Production - [ " .. JS.str((if JS.t(options.offlineProd) then "ON" else "OFF"))) .. " ]"), "Produce resources when not in game", JS.A(2, "opt", "offlineProd"), "Offline Production", (if JS.t(options.offlineProd) then "ON" else "OFF"), JS.NULL, JS.NULL, (if JS.t(options.offlineProd) then true else false)))
	}, {"t", "c"})
	displays = JS.O({
		t = "row",
		c = JS.A(4, rbx_opt(nil, "Milestone Showing Mode", (("[ " .. JS.str(MS_DISPLAYS[JS.k(ms)])) .. " ]"), JS.A(2, "opt", "msDisplay"), "Milestone Showing Mode", rbx_str(nil, MS_DISPLAYS[JS.k(ms)]), ms, JS.len(MS_SETTINGS)), rbx_opt(nil, "Completed Challenges", (("[ " .. JS.str((if JS.t(options.hideChallenges) then "Hidden" else "Shown"))) .. " ]"), JS.A(2, "opt", "hideChallenges"), "Completed Challenges", (if JS.t(options.hideChallenges) then "Hidden" else "Shown"), JS.NULL, JS.NULL, (if JS.t(options.hideChallenges) then true else false)), rbx_opt(nil, "Corrupt. Tooltip Pos.", (("[ " .. JS.str(CCTP_DISPLAYS[JS.k(cc)])) .. " ]"), JS.A(2, "opt", "cctp"), "Corrupt. Tooltip Pos.", rbx_str(nil, CCTP_DISPLAYS[JS.k(cc)]), cc, JS.len(CCTP_SETTINGS)), rbx_opt(nil, (("Milestones Order - [ " .. JS.str((if JS.t(options.reverseMilestones) then "Last to First" else "First to Last"))) .. " ]"), "Choose milestone ordering", JS.A(2, "opt", "reverseMilestones"), "Milestones Order", (if JS.t(options.reverseMilestones) then "Last to First" else "First to Last"), JS.NULL, JS.NULL, (if JS.t(options.reverseMilestones) then true else false)))
	}, {"t", "c"})
	do return JS.O({
		t = "col",
		c = JS.A(6, JS.O({
		t = "html",
		h = "<h2>[ Saving ]</h2><br>"
	}, {"t", "h"}), saving, JS.O({
		t = "blank",
		w = "8px",
		hh = "20px"
	}, {"t", "w", "hh"}), JS.O({
		t = "html",
		h = "<h2>[ Displays ]</h2><br>"
	}, {"t", "h"}), displays, rbx_about(nil))
	}, {"t", "c"}) end
end
rbx_endScreen = function(this)
	local h, took
	h = (("<br><h3>" .. JS.str(modInfo.winText)) .. "</h3><br><br>")
	took = (if JS.t(player.timePlayedReset) then JS.NULL else formatTime(nil, player.timePlayed))
	if (not (took == JS.NULL)) then
		h = (JS.str(h) .. (("It took you " .. JS.str(took)) .. " to beat the game.<br>"))
	end
	do return JS.O({
		t = "col",
		c = JS.A(2, JS.O({
		t = "html",
		h = h
	}, {"t", "h"}), JS.O({
		t = "row",
		c = JS.A(2, JS.O({
		t = "btn",
		k = "opt",
		cls = "can",
		h = "Play Again",
		a = rbx_act(nil, JS.A(2, "opt", "playAgain"))
	}, {"t", "k", "cls", "h", "a"}), JS.O({
		t = "btn",
		k = "opt",
		cls = "can",
		h = "Keep Going",
		a = rbx_act(nil, JS.A(2, "opt", "keepGoing"))
	}, {"t", "k", "cls", "h", "a"}))
	}, {"t", "c"})),
		win = rbx_str(nil, modInfo.winText),
		took = took
	}, {"t", "c", "win", "took"}) end
end
rbx_mapName = function(this, l)
	if ((l == "pm") and player.pm.best:gte(15)) then
		do return "P███t█g█ M██e█t███" end
	end
	do return rbx_MAP_NAME[JS.k(l)] end
end
rbx_branchColor = function(this, c)
	local th
	if (JS.typeof(c) == "number") then
		th = (if JS.t(colors[JS.k(options.theme)]) then colors[JS.k(options.theme)] else colors["default"])
		do return rbx_str(nil, th[JS.k(c)]) end
	end
	do return rbx_str(nil, c) end
end
rbx_mapBranches = function(this, l)
	local out, b, i, to, col, w
	out = JS.A(0)
	b = tmp[JS.k(l)].branches
	if (not Array.isArray(b)) then
		do return out end
	end
	for i = 0, JS.cap(0, (JS.len(b)) - 1, 1) do
		to = b[JS.k(i)]
		col = 1
		w = 15
		if Array.isArray(to) then
			if (not (to[1] == nil)) then
				col = to[1]
			end
			if JS.t(to[2]) then
				w = to[2]
			end
			to = to[0]
		end
		if (JS.t(tmp[JS.k(to)]) and JS.eq(tmp[JS.k(to)].layerShown, true)) then
			JS.m(out, "push", JS.O({
				to = rbx_str(nil, to),
				col = rbx_branchColor(nil, col),
				w = w
			}, {"to", "col", "w"}))
		end
	end
	do return out end
end
rbx_nodeTip = function(this, l)
	local t, tip
	t = tmp[JS.k(l)]
	tip = rbx_v(nil, t, layers[JS.k(l)], "tooltip")
	if (tip == "") then
		do return JS.NULL end
	end
	if JS.t(player[JS.k(l)].unlocked) then
		do return (if JS.t(tip) then rbx_str(nil, tip) else ((JS.str(formatWhole(nil, player[JS.k(l)].points)) .. " ") .. JS.str(rbx_str(nil, t.resource)))) end
	end
	if JS.t(t.tooltipLocked) then
		do return rbx_str(nil, t.tooltipLocked) end
	end
	do return (((((((("Reach " .. JS.str(formatWhole(nil, t.requires))) .. " ") .. JS.str(rbx_str(nil, t.baseResource))) .. " to unlock (You have ") .. JS.str(formatWhole(nil, t.baseAmount))) .. " ") .. JS.str(rbx_str(nil, t.baseResource))) .. ")") end
end
rbx_achTotal = function(this)
	local n, a, k
	n = 0
	a = layers.ach.achievements
	for _, __k7 in JS.keys(a) do
		k = __k7
		if (JS.t(a[k]) and (JS.typeof(a[k]) == "object")) then
			n = (JS.tonum(n) + 1)
		end
	end
	do return n end
end
rbx_need = function(this, l)
	local u, have
	u = rbx_UNLOCK[JS.k(l)]
	if (((not JS.t(u)) or (not JS.t(player[JS.k(u[0])]))) or (player[JS.k(u[0])].best == nil)) then
		do return JS.NULL end
	end
	have = JS.D(player[JS.k(u[0])].best)
	do return JS.O({
		r = rbx_UNLOCK_NAMES[JS.k(u[0])],
		n = formatWhole(nil, u[1]),
		have = formatWhole(nil, have),
		pr = rbx_prCap(nil, rbx_pr(nil, have, u[1]))
	}, {"r", "n", "have", "pr"}) end
end
rbx_mapNode = function(this, l)
	local t, shown, n, reached, unl, can, lit
	t = tmp[JS.k(l)]
	shown = JS.eq(t.layerShown, true)
	n = JS.O({
		t = "node",
		id = l,
		show = shown
	}, {"t", "id", "show"})
	if (not JS.t(shown)) then
		reached = (if JS.t(player[JS.k(l)].unlocked) then player[JS.k(l)].unlocked else ((not (player[JS.k(l)].best == nil)) and (JS.D(player[JS.k(l)].best)):gt(0)))
		JS.setk(n, "dor", (if JS.t(reached) then true else false))
		JS.setk(n, "need", rbx_need(nil, l))
		do return n end
	end
	unl = (if JS.t(player[JS.k(l)].unlocked) then true else false)
	can = (if ((not (t.type == "none")) and JS.t(t.canReset)) then true else false)
	lit = (if JS.t(unl) then unl else can)
	JS.setk(n, "unl", unl)
	JS.setk(n, "col", rbx_str(nil, t.color))
	JS.setk(n, "sym", (if (l == "cp") then "CR" else rbx_str(nil, t.symbol)))
	JS.setk(n, "name", rbx_mapName(nil, l))
	JS.setk(n, "st", rbx_css(nil, JS.A(1, rbx_v(nil, t, layers[JS.k(l)], "nodeStyle"))))
	JS.setk(n, "tab", (if (JS.t(t.tabFormat) and (not Array.isArray(t.tabFormat))) then rbx_str(nil, player.subtabs[JS.k(l)].mainTabs) else JS.NULL))
	JS.setk(n, "ch", (if JS.t(player[JS.k(l)].activeChallenge) then player[JS.k(l)].activeChallenge else JS.NULL))
	JS.setk(n, "cur", (if JS.eq(player.tab, l) then true else false))
	JS.setk(n, "br", rbx_mapBranches(nil, l))
	JS.setk(n, "a", rbx_act(nil, JS.A(2, "tab", l)))
	JS.setk(n, "c", JS.A(1, JS.O({
		t = "val",
		can = can,
		lit = lit,
		glow = (if (JS.t(t.notify) and JS.t(unl)) then true else false),
		pulse = (if JS.t(t.prestigeNotify) then true else false),
		pts = (if (l == "ach") then formatWhole(nil, JS.len(player.ach.achievements)) else formatWhole(nil, player[JS.k(l)].points)),
		res = rbx_str(nil, t.resource),
		tip = rbx_nodeTip(nil, l),
		ra = (if JS.t(can) then rbx_act(nil, JS.A(2, "reset", l)) else JS.NULL),
		req = (if (JS.t(lit) or (t.requires == nil)) then JS.NULL else rbx_nn(nil, formatWhole(nil, t.requires))),
		rres = (if JS.t(lit) then JS.NULL else rbx_str(nil, t.baseResource)),
		gain = (if JS.t(can) then formatWhole(nil, t.resetGain) else JS.NULL),
		pr = (if JS.t(lit) then JS.NULL else rbx_prCap(nil, rbx_pr(nil, t.baseAmount, t.requires))),
		gen = (if (((JS.t(unl) and JS.t(t.passiveGeneration)) and JS.t(t.resetGain)) and (JS.D(t.resetGain)):gt(0)) then rbx_nn(nil, format(nil, t.resetGain:times(t.passiveGeneration))) else JS.NULL),
		tot = (if (l == "ach") then rbx_achTotal(nil) else JS.NULL)
	}, {"t", "can", "lit", "glow", "pulse", "pts", "res", "tip", "ra", "req", "rres", "gain", "pr", "gen", "tot"})))
	do return n end
end
rbx_mapGate = function(this)
	local inMv, g, best, req, c, rs, i
	inMv = JS.eq(player.mp.activeChallenge, 21)
	g = JS.O({
		t = "gate",
		show = (if player.m.best:gte(185) then true else false),
		inside = inMv
	}, {"t", "show", "inside"})
	best = player.m.best
	req = JS.O({
		have = formatWhole(nil, best),
		need = "185",
		pr = (if best:gte(185) then 1000 else Math.max(0, Math.min(999, Math.floor(((best:toNumber() / 185) * 1000)))))
	}, {"have", "need", "pr"})
	if (not JS.t(g.show)) then
		JS.setk(g, "req", req)
		do return g end
	end
	c = tmp.mp.challenges[21]
	JS.setk(g, "can", (if (JS.t(player.mp.unlocked) and JS.t(c.unlocked)) then true else false))
	JS.setk(g, "fin", (if (JS.t(inMv) and canCompleteChallenge(nil, "mp", 21)) then true else false))
	JS.setk(g, "h", (if JS.t(inMv) then "Leave Prestige Multiverse" else "Enter Prestige Multiverse"))
	JS.setk(g, "goal", rbx_str(nil, rbx_v(nil, c, layers.mp.challenges[21], "goalDescription")))
	JS.setk(g, "done", (JS.tonum(challengeCompletions(nil, "mp", 21)) >= 1))
	JS.setk(g, "a", rbx_act(nil, JS.A(3, "chal", "mp", 21)))
	JS.setk(g, "req", req)
	rs = JS.A(0)
	for i = 0, JS.cap(0, (JS.len(rbx_MV_RESETS)) - 1, 1) do
		if (not ((rbx_MV_RESETS[JS.k(i)] == "sp") and hasMalware(nil, "m", 15))) then
			JS.m(rs, "push", rbx_MV_RESETS[JS.k(i)])
		end
	end
	JS.setk(g, "rs", rs)
	do return g end
end
rbx_openPanel = function(this)
	local tab
	tab = player.tab
	if (tab == "options-tab") then
		do return tab end
	end
	if ((JS.tonum(JS.m(rbx_MAP, "indexOf", tab)) >= 0) and JS.eq(tmp[JS.k(tab)].layerShown, true)) then
		do return tab end
	end
	do return JS.NULL end
end
rbx_map = function(this)
	local open, kids, i, n
	open = rbx_openPanel(nil)
	kids = JS.A(0)
	for i = 0, JS.cap(0, (JS.len(rbx_MAP)) - 1, 1) do
		do
			local __ok8, __e9 = pcall(function()
				n = rbx_mapNode(nil, rbx_MAP[JS.k(i)])
			end)
			if not __ok8 then
				local e = __e9
				n = JS.O({
					t = "node",
					id = rbx_MAP[JS.k(i)],
					show = false,
					dor = false
				}, {"t", "id", "show", "dor"})
			end
		end
		JS.m(kids, "push", n)
	end
	JS.m(kids, "push", rbx_mapGate(nil))
	do return JS.O({
		t = "map",
		inside = JS.eq(player.mp.activeChallenge, 21),
		open = open,
		close = rbx_act(nil, JS.A(2, "tab", "none")),
		opt = rbx_act(nil, JS.A(2, "tab", "options-tab")),
		c = kids
	}, {"t", "inside", "open", "close", "opt", "c"}) end
end
rbx_hud = function(this)
	local h, pg, o, w, wh, sc, of, x
	h = JS.O({
		t = "hud",
		pts = format(nil, player.points),
		name = rbx_str(nil, modInfo.pointsName),
		gen = JS.NULL
	}, {"t", "pts", "name", "gen"})
	pg = getPointGen(nil)
	if JS.t(canGenPoints(nil)) then
		o = tmp.other
		if (not (if JS.eq(o.oompsMag, 0) then pg:lte(0) else (JS.D(o.oomps)):lte(0))) then
			JS.setk(h, "gen", (if (not JS.eq(o.oompsMag, 0)) then (((JS.str(format(nil, o.oomps)) .. " OOM") .. JS.str((if (JS.tonum(o.oompsMag) < 0) then "^OOM" else (if (JS.tonum(o.oompsMag) > 1) then ("^" .. JS.str(o.oompsMag)) else "")))) .. "s/sec") else (JS.str(formatSmall(nil, pg)) .. "/sec")))
		end
	end
	JS.setk(h, "dev", (if (JS.t(player.devSpeed) and (not JS.eq(player.devSpeed, 1))) then (JS.str(format(nil, player.devSpeed)) .. "x") else JS.NULL))
	JS.setk(h, "off", (if ((not (player.offTime == nil)) and (JS.tonum(player.offTime.remain) > 0)) then formatTime(nil, player.offTime.remain) else JS.NULL))
	w = JS.A(0)
	wh = (if JS.t(tmp.displayThings[1]) then rbx_str(nil, tmp.displayThings[1]) else "")
	if (not (wh == "")) then
		sc = getPointSoftcapStart(nil)
		of = getCostOverflowStart(nil)
		if pg:gte(sc:sqrt()) then
			JS.m(w, "push", JS.O({
				k = "softcap",
				v = format(nil, sc),
				e = rbx_nn(nil, format(nil, pg:log(getPointGenBeforeSoftcap(nil)), 4))
			}, {"k", "v", "e"}))
		end
		if player.m.points:gte(of) then
			JS.m(w, "push", JS.O({
				k = "overflow",
				v = format(nil, of),
				e = rbx_nn(nil, format(nil, getCostOverflowEff(nil), 4))
			}, {"k", "v", "e"}))
		end
	end
	JS.setk(h, "w", w)
	JS.setk(h, "wh", (if (wh == "") then JS.NULL else wh))
	x = JS.A(0)
	if JS.eq(player.sp.activeChallenge, 11) then
		JS.m(x, "push", (((((("<h2 style=\"color:#9f2846\">" .. JS.str(format(nil, player.m.points, 0))) .. "</h2> milestones,<br> which can be transformed into <h2 style=\"color:orange\">") .. JS.str(format(nil, tmp.sp.ambersGain))) .. "</h2> Prestige Ashes after a cooldown. (") .. JS.str(format(nil, player.sp.chalCooldown))) .. "s)"))
	end
	if (((player.sp.sparkMilestones:gt(0) and (JS.D(player.sp.ashedMilestones)):lt(player.sp.sparkMilestones)) and (JS.tonum(player.sp.burningTimer) > 0)) and JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, false)) then
		JS.m(x, "push", ((((("<span style=\"color: orange\">Your " .. JS.str(format(nil, JS.add(player.sp.ashedMilestones, 1), 0))) .. JS.str(helper(nil, JS.add(player.sp.ashedMilestones, 1)))) .. " Spark Milestone will burn for ") .. JS.str(formatTime(nil, player.sp.burningTimer))) .. "</span>"))
	end
	JS.setk(h, "x", (if JS.t(JS.len(x)) then JS.m(x, "join", "<br>") else JS.NULL))
	JS.setk(h, "fr", (if player.m.best:eq(0) then true else false))
	do return h end
end
rbx_view = function(this)
	local v, ended, open, keys, key, k
	rbx_actions = JS.A(0)
	updateTabFormats(nil)
	v = JS.O({})
	ended = (if JS.t(tmp.gameEnded) then (not JS.t(player.keepGoing)) else tmp.gameEnded)
	JS.setk(v, "ended", (if JS.t(ended) then true else false))
	do
		local __ok10, __e11 = pcall(function()
			JS.setk(v, "map", rbx_map(nil))
		end)
		if not __ok10 then
			local e = __e11
			JS.setk(v, "map", rbx_err(nil, "map", e))
		end
	end
	do
		local __ok12, __e13 = pcall(function()
			JS.setk(v, "hud", rbx_hud(nil))
		end)
		if not __ok12 then
			local e = __e13
			JS.setk(v, "hud", rbx_err(nil, "hud", e))
		end
	end
	open = (if (v.map.t == "map") then v.map.open else JS.NULL)
	JS.setk(v, "tabName", (if JS.t(ended) then "end" else (if JS.t(open) then open else "none")))
	JS.setk(v, "tabStyle", JS.O({}))
	do
		local __ok14, __e15 = pcall(function()
			if JS.t(ended) then
				JS.setk(v, "tab", rbx_endScreen(nil))
			elseif (open == "options-tab") then
				JS.setk(v, "tab", rbx_optionsTab(nil))
			elseif JS.t(open) then
				JS.setk(v, "tab", rbx_layerTab(nil, open))
				JS.setk(v, "tabStyle", rbx_tabStyle(nil, open))
			else
				JS.setk(v, "tab", JS.O({
					t = "col",
					c = JS.A(0)
				}, {"t", "c"}))
			end
		end)
		if not __ok14 then
			local e = __e15
			JS.setk(v, "tab", rbx_err(nil, "tab", e))
		end
	end
	keys = JS.A(0)
	for _, __k16 in JS.keys(hotkeys) do
		key = __k16
		k = hotkeys[key]
		if (JS.t(player[JS.k(k.layer)].unlocked) and JS.t(tmp[JS.k(k.layer)].hotkeys[JS.k(k.id)].unlocked)) then
			JS.m(keys, "push", key)
		end
	end
	JS.setk(v, "keys", keys)
	do return v end
end
rbx_actions = JS.A(0)
rbx_BUY_CUR = JS.O({
	p = JS.O({
	[11] = JS.A(2, "p", "points"),
	[12] = JS.A(2, "p", "points")
}),
	sp = JS.O({
	[11] = JS.A(2, "sp", "points"),
	[12] = JS.A(2, "sp", "points")
}),
	hp = JS.O({
	[11] = JS.A(2, "hp", "points"),
	[12] = JS.A(2, "hp", "points")
}),
	ap = JS.O({
	[11] = JS.A(2, "ap", "points")
}),
	pp = JS.O({
	[11] = JS.A(2, "pp", "points")
}),
	ep = JS.O({
	[11] = JS.A(2, "ep", "points")
}),
	mp = JS.O({
	[11] = JS.A(2, "mp", "points"),
	[12] = JS.A(2, "mp", "points"),
	[13] = JS.A(2, "mp", "points"),
	[21] = JS.A(2, "mp", "points"),
	[22] = JS.A(3, "pm", "essence", "prestige essences")
}),
	pep = JS.O({
	[11] = JS.A(2, "pep", "points")
}),
	cp = JS.O({
	[11] = JS.A(3, "cp", "formatted", "corruption essences"),
	[21] = JS.A(3, "cp", "formatted", "corruption essences"),
	[22] = JS.A(3, "cp", "formatted", "corruption essences"),
	[31] = JS.A(3, JS.NULL, "points", JS.NULL),
	[32] = JS.A(3, "pm", "essence", "prestige essences"),
	[33] = JS.A(3, JS.NULL, "points", JS.NULL),
	[34] = JS.A(3, "pm", "essence", "prestige essences")
})
}, {"p", "sp", "hp", "ap", "pp", "ep", "mp", "pep", "cp"})
rbx_MAP = JS.A(21, "ach", "m", "mm", "em", "p", "pe", "sp", "pb", "pp", "se", "hp", "ep", "hb", "ap", "mp", "t", "pm", "pep", "cp", "cm", "ex")
rbx_MAP_NAME = JS.O({
	ach = "Achievements",
	m = "Milestone",
	mm = "Meta Milestone",
	em = "Extra Milestone",
	p = "Prestige Points",
	pe = "Prestige Energy",
	sp = "Super Prestige Points",
	pb = "Prestige Boosts",
	pp = "Prestige Power",
	se = "Super Energy",
	hp = "Hyper Prestige Points",
	ep = "Exotic Prestige Points",
	hb = "Hyper Boosts",
	ap = "Atomic Prestige Points",
	mp = "Multiverse Prestige Points",
	t = "Transcend Points",
	pm = "Prestige Milestone",
	pep = "Prestiged-Exotic Prestige",
	cp = "Corrupted Prestige",
	cm = "Corrupted Milestone",
	ex = "Exploration Points"
}, {"ach", "m", "mm", "em", "p", "pe", "sp", "pb", "pp", "se", "hp", "ep", "hb", "ap", "mp", "t", "pm", "pep", "cp", "cm", "ex"})
rbx_MV_RESETS = JS.A(14, "pp", "p", "sp", "pe", "hp", "ap", "pb", "hb", "se", "ep", "em", "mm", "m", "t")
rbx_UNLOCK = JS.O({
	p = JS.A(2, "m", 5),
	sp = JS.A(2, "m", 25),
	mm = JS.A(2, "m", 40),
	pb = JS.A(2, "m", 50),
	hp = JS.A(2, "m", 60),
	ap = JS.A(2, "m", 80),
	t = JS.A(2, "m", 99),
	hb = JS.A(2, "m", 104),
	pe = JS.A(2, "m", 125),
	se = JS.A(2, "m", 140),
	pp = JS.A(2, "m", 151),
	ep = JS.A(2, "m", 160),
	mp = JS.A(2, "m", 181),
	em = JS.A(2, "mm", 30),
	pep = JS.A(2, "pm", 5),
	cp = JS.A(2, "pm", 6),
	cm = JS.A(2, "pm", 10)
}, {"p", "sp", "mm", "pb", "hp", "ap", "t", "hb", "pe", "se", "pp", "ep", "mp", "em", "pep", "cp", "cm"})
rbx_UNLOCK_NAMES = JS.O({
	m = "milestones",
	mm = "meta-milestones",
	pm = "prestige-milestones"
}, {"m", "mm", "pm"})

end
