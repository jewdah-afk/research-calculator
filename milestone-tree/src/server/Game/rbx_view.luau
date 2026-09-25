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
rbx_mainDisplay = function(this, layer, data)
	local c, h
	c = tmp[JS.k(layer)].color
	h = (if player[JS.k(layer)].points:lt("1e1000") then "You have " else "")
	h = (JS.str(h) .. (((((("<h2 style=\"color: " .. JS.str(c)) .. "; text-shadow: 0px 0px 10px ") .. JS.str(c)) .. "\">") .. JS.str((if JS.t(data) then format(nil, player[JS.k(layer)].points, data) else formatWhole(nil, player[JS.k(layer)].points)))) .. "</h2> "))
	h = JS.add(h, rbx_str(nil, tmp[JS.k(layer)].resource))
	if JS.t(layers[JS.k(layer)].effectDescription) then
		h = (JS.str(h) .. (", " .. JS.str(run(nil, layers[JS.k(layer)].effectDescription, layers[JS.k(layer)]))))
	end
	do return JS.O({
		t = "html",
		h = (JS.str(h) .. "<br><br>")
	}, {"t", "h"}) end
end
rbx_prestigeButton = function(this, layer)
	local can
	if (tmp[JS.k(layer)].type == "none") then
		do return JS.NULL end
	end
	can = tmp[JS.k(layer)].canReset
	do return JS.O({
		t = "btn",
		k = "reset",
		cls = (if JS.t(can) then "can" else "locked"),
		h = prestigeButtonText(nil, layer),
		a = rbx_act(nil, JS.A(2, "reset", layer)),
		st = rbx_css(nil, JS.A(2, (if JS.t(can) then JS.O({
		["background-color"] = tmp[JS.k(layer)].color
	}) else JS.NULL), tmp[JS.k(layer)].componentStyles["prestige-button"]))
	}, {"t", "k", "cls", "h", "a", "st"}) end
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
		h = h
	}, {"t", "h"}) end
end
rbx_upgrade = function(this, layer, id)
	local t, L, bought, can, h, title, cd, cur
	t = tmp[JS.k(layer)].upgrades[JS.k(id)]
	L = layers[JS.k(layer)].upgrades[JS.k(id)]
	if (t == nil) then
		do return JS.NULL end
	end
	if (JS.t(perkUnl(nil, layer, id)) and (not JS.t(t.unlocked))) then
		do return JS.O({
			t = "btn",
			k = "perk",
			cls = (if JS.t(t.perkCan) then "perk" else "perked"),
			a = rbx_act(nil, JS.A(3, "perk", layer, id)),
			h = ("<h3>Explore A New Perk Upgrade</h3><br>" .. JS.str(rbx_str(nil, rbx_v(nil, t, L, "perkReq"))))
		}, {"t", "k", "cls", "a", "h"}) end
	end
	if (not JS.t(t.unlocked)) then
		do return JS.NULL end
	end
	bought = hasUpgrade(nil, layer, id)
	can = (canAffordUpgrade(nil, layer, id) and (not JS.t(bought)))
	h = ""
	if JS.t(L.fullDisplay) then
		h = rbx_str(nil, run(nil, L.fullDisplay, L))
	else
		title = rbx_v(nil, t, L, "title")
		if JS.t(title) then
			h = (JS.str(h) .. (("<h3>" .. JS.str(title)) .. "</h3><br>"))
		end
		h = JS.add(h, rbx_str(nil, rbx_v(nil, t, L, "description")))
		if JS.t(L.effectDisplay) then
			h = (JS.str(h) .. ("<br>Currently: " .. JS.str(run(nil, L.effectDisplay, L))))
		end
		h = (JS.str(h) .. "<br>")
		cd = rbx_v(nil, t, L, "costDescription")
		if JS.t(cd) then
			h = JS.add(h, cd)
		else
			cur = rbx_v(nil, t, L, "currencyDisplayName")
			h = (JS.str(h) .. ((("Cost: " .. JS.str(formatWhole(nil, t.cost))) .. " ") .. JS.str(rbx_str(nil, (if JS.t(cur) then cur else tmp[JS.k(layer)].resource)))))
		end
	end
	do return JS.O({
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
	}, {"t", "k", "cls", "n", "h", "a", "tip", "st"}) end
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
	local t, L, done, h, kids, plocked, i
	t = tmp[JS.k(layer)].milestones[JS.k(id)]
	L = layers[JS.k(layer)].milestones[JS.k(id)]
	if (not (((not (t == nil)) and JS.t(milestoneShown(nil, layer, id))) and JS.t(t.unlocked))) then
		do return JS.NULL end
	end
	done = hasMilestone(nil, layer, id)
	h = (((("<h3>" .. JS.str(rbx_str(nil, rbx_v(nil, t, L, "requirementDescription")))) .. "</h3><br>") .. JS.str(rbx_str(nil, run(nil, L.effectDescription, L)))) .. "<br>")
	kids = JS.A(0)
	if (JS.eq(t.pseudoUnl, true) and (not JS.m(player[JS.k(layer)].pseudoBuys, "includes", id))) then
		plocked = (not player.points:gte(t.pseudoCost))
		JS.m(kids, "push", JS.O({
			t = "btn",
			k = "malware",
			cls = (if JS.t(plocked) then "plocked" else "pseudo"),
			a = rbx_act(nil, JS.A(3, "malware", layer, id)),
			h = (("Infect a Milestone with Malware<br>Cost: " .. JS.str(format(nil, t.pseudoCost))) .. " points.")
		}, {"t", "k", "cls", "a", "h"}))
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
		st = rbx_css(nil, JS.A(2, tmp[JS.k(layer)].componentStyles.milestone, rbx_v(nil, t, L, "style")))
	}, {"t", "done", "h", "c", "tip", "st"}) end
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
rbx_buyable = function(this, layer, id)
	local t, L, cls, h, title, node, sellOne, sellAll, kids, cls2
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
	}) else JS.NULL), tmp[JS.k(layer)].componentStyles.clickable, rbx_v(nil, t, L, "style")))
	}, {"t", "k", "cls", "h", "a", "tip", "hold", "st"}) end
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
	local t, L, cls, btn, body, gd, cur
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
	if JS.t(L.fullDisplay) then
		body = rbx_str(nil, run(nil, L.fullDisplay, L))
	else
		body = (JS.str(rbx_str(nil, rbx_v(nil, t, L, "challengeDescription"))) .. "<br>Goal:  ")
		gd = rbx_v(nil, t, L, "goalDescription")
		if JS.t(gd) then
			body = JS.add(body, gd)
		else
			cur = rbx_v(nil, t, L, "currencyDisplayName")
			body = (JS.str(body) .. ((JS.str(format(nil, t.goal)) .. " ") .. JS.str(rbx_str(nil, (if JS.t(cur) then cur else modInfo.pointsName)))))
		end
		body = (JS.str(body) .. (("<br>Reward: " .. JS.str(rbx_str(nil, rbx_v(nil, t, L, "rewardDescription")))) .. "<br>"))
		if (not (L.rewardDisplay == nil)) then
			body = (JS.str(body) .. ("Currently: " .. JS.str((if JS.t(t.rewardDisplay) then run(nil, L.rewardDisplay, L) else format(nil, t.rewardEffect)))))
		end
	end
	do return JS.O({
		t = "chal",
		cls = cls,
		active = JS.eq(player[JS.k(layer)].activeChallenge, id),
		st = rbx_css(nil, JS.A(2, tmp[JS.k(layer)].componentStyles.challenge, rbx_v(nil, t, L, "style"))),
		c = JS.A(3, JS.O({
		t = "html",
		h = (("<h3>" .. JS.str(rbx_str(nil, rbx_v(nil, t, L, "name")))) .. "</h3>")
	}, {"t", "h"}), btn, JS.O({
		t = "html",
		h = body
	}, {"t", "h"}))
	}, {"t", "cls", "active", "st", "c"}) end
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
		st = rbx_css(nil, JS.A(2, tmp[JS.k(layer)].componentStyles.achievement, rbx_v(nil, t, L, "style")))
	}, {"t", "done", "tip", "num", "h", "st"}) end
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
	local g, data, can, h
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
	do return JS.O({
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
	}, {"t", "k", "cls", "h", "a", "hold", "tip", "st"}) end
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
rbx_component = function(this, layer, item)
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
			n = rbx_component(nil, layer, data[JS.k(i)])
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
		JS.m(out, "push", rbx_component(nil, layer, "main-display"))
		if (not (t.type == "none")) then
			JS.m(out, "push", rbx_component(nil, layer, "prestige-button"))
		end
		JS.m(out, "push", rbx_component(nil, layer, "resource-display"))
		JS.m(out, "push", rbx_component(nil, layer, "milestones"))
		if Array.isArray(t.midsection) then
			JS.m(out, "push", rbx_column(nil, layer, t.midsection))
		end
		JS.m(out, "push", rbx_component(nil, layer, "clickables"))
		JS.m(out, "push", rbx_component(nil, layer, "buyables"))
		JS.m(out, "push", rbx_component(nil, layer, "upgrades"))
		JS.m(out, "push", rbx_component(nil, layer, "challenges"))
		JS.m(out, "push", rbx_component(nil, layer, "achievements"))
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
rbx_menuButton = function(this, layer, label, style)
	local shown, glow
	shown = JS.eq(layerShown(nil, layer), true)
	glow = (if JS.t(tmp[JS.k(layer)].notify) then player[JS.k(layer)].unlocked else tmp[JS.k(layer)].notify)
	do return JS.O({
		t = "btn",
		k = "menu",
		cls = (if JS.eq(player.tab, layer) then "cur" else "can"),
		h = label,
		a = rbx_act(nil, JS.A(2, "tab", layer)),
		glow = (if JS.t(glow) then rbx_str(nil, tmp[JS.k(layer)].trueGlowColor) else JS.NULL),
		st = rbx_css(nil, JS.A(2, (if JS.t(shown) then JS.O({
		["background-color"] = tmp[JS.k(layer)].color
	}) else JS.NULL), style))
	}, {"t", "k", "cls", "h", "a", "glow", "st"}) end
end
rbx_menu = function(this)
	local out, inMv, i, e, k, b
	out = JS.A(0)
	inMv = JS.eq(player.mp.activeChallenge, 21)
	for i = 0, JS.cap(0, (JS.len(rbx_MENU)) - 1, 1) do
		e = rbx_MENU[JS.k(i)]
		k = e[0]
		if (k == "head") then
			JS.m(out, "push", JS.O({
				t = "html",
				h = e[1]
			}, {"t", "h"}))
		elseif (k == "hr") then
			JS.m(out, "push", JS.O({
				t = "hr"
			}))
		elseif (k == "headIf") then
			if JS.eq(layerShown(nil, e[1]), true) then
				JS.m(out, "push", JS.O({
					t = "html",
					h = e[2]
				}, {"t", "h"}))
			end
		elseif (k == "hrIf") then
			if JS.eq(layerShown(nil, e[1]), true) then
				JS.m(out, "push", JS.O({
					t = "hr"
				}))
			end
		elseif (k == "page") then
			JS.m(out, "push", JS.O({
				t = "btn",
				k = "menu",
				cls = (if JS.eq(player.tab, e[1]) then "cur" else "can"),
				h = e[2],
				a = rbx_act(nil, JS.A(2, "tab", e[1]))
			}, {"t", "k", "cls", "h", "a"}))
		elseif (k == "layer") then
			if JS.eq(layerShown(nil, e[1]), true) then
				JS.m(out, "push", rbx_menuButton(nil, e[1], e[2]))
			end
		elseif (k == "mpOut") then
			if (JS.eq(layerShown(nil, e[1]), true) and (not JS.t(inMv))) then
				JS.m(out, "push", rbx_menuButton(nil, e[1], e[2]))
			end
		elseif (k == "mpIn") then
			if (JS.eq(layerShown(nil, e[1]), true) and JS.t(inMv)) then
				JS.m(out, "push", rbx_menuButton(nil, e[1], e[2]))
			end
		elseif (k == "multiverse") then
			if (player.m.best:gte(185) and (not JS.t(inMv))) then
				JS.m(out, "push", JS.O({
					t = "btn",
					k = "menu",
					cls = "can",
					h = e[1],
					a = rbx_act(nil, JS.A(3, "chal", "mp", 21))
				}, {"t", "k", "cls", "h", "a"}))
			end
		elseif (k == "multiverseIn") then
			if (player.m.best:gte(185) and JS.t(inMv)) then
				JS.m(out, "push", JS.O({
					t = "btn",
					k = "menu",
					cls = "can",
					h = e[1],
					a = rbx_act(nil, JS.A(3, "chal", "mp", 21))
				}, {"t", "k", "cls", "h", "a"}))
			end
		elseif (k == "inMultiverse") then
			if JS.t(inMv) then
				JS.m(out, "push", JS.O({
					t = "html",
					h = e[1]
				}, {"t", "h"}))
			end
		elseif (k == "pmLayer") then
			if JS.eq(layerShown(nil, "pm"), true) then
				JS.m(out, "push", rbx_menuButton(nil, "pm", (if player.pm.best:gte(15) then "P███t█g█ M██e█t███" else "Prestige Milestone")))
			end
		elseif (k == "headPepCp") then
			if (JS.eq(layerShown(nil, "pep"), true) or JS.eq(layerShown(nil, "cp"), true)) then
				JS.m(out, "push", JS.O({
					t = "html",
					h = e[1]
				}, {"t", "h"}))
			end
		elseif (k == "hrPepCp") then
			if (JS.eq(layerShown(nil, "pep"), true) or JS.eq(layerShown(nil, "cp"), true)) then
				JS.m(out, "push", JS.O({
					t = "hr"
				}))
			end
		elseif (k == "cpLayer") then
			if JS.eq(layerShown(nil, "cp"), true) then
				b = rbx_menuButton(nil, "cp", "Corrupted Prestige", JS.O({
					color = "lime",
					["border-color"] = "lime"
				}, {"color", "border-color"}))
				JS.set(b.st, "background-color", "black")
				JS.m(out, "push", b)
			end
		elseif (k == "cmLayer") then
			if (((player.tab == "cp") or (player.tab == "cm")) and JS.eq(layerShown(nil, "cm"), true)) then
				JS.m(out, "push", rbx_menuButton(nil, "cm", "Corrupted Milestone", JS.O({
					color = "lime",
					["border-color"] = "lime"
				}, {"color", "border-color"})))
			end
		end
	end
	do return JS.O({
		t = "col",
		c = out
	}, {"t", "c"}) end
end
rbx_head = function(this)
	local h, o, things, i
	h = ""
	if (JS.t(player.devSpeed) and (not JS.eq(player.devSpeed, 1))) then
		h = (JS.str(h) .. (("<br>Dev Speed: " .. JS.str(format(nil, player.devSpeed))) .. "x<br>"))
	end
	if (not (player.offTime == nil)) then
		h = (JS.str(h) .. (("<br>Offline Time: " .. JS.str(formatTime(nil, player.offTime.remain))) .. "<br>"))
	end
	if player.points:lt("1e1000") then
		h = (JS.str(h) .. "You have ")
	end
	h = (JS.str(h) .. (("<h2>" .. JS.str(format(nil, player.points))) .. "</h2> "))
	if JS.t(canGenPoints(nil)) then
		o = tmp.other
		h = (JS.str(h) .. (("(" .. JS.str((if (not JS.eq(o.oompsMag, 0)) then (((JS.str(format(nil, o.oomps)) .. " OOM") .. JS.str((if (JS.tonum(o.oompsMag) < 0) then "^OOM" else (if (JS.tonum(o.oompsMag) > 1) then ("^" .. JS.str(o.oompsMag)) else "")))) .. "s") else formatSmall(nil, getPointGen(nil))))) .. "/sec)"))
	end
	if player.points:lt("1e1e6") then
		h = (JS.str(h) .. (" " .. JS.str(modInfo.pointsName)))
	end
	if JS.eq(player.sp.activeChallenge, 11) then
		h = (JS.str(h) .. ((((((" and <h2 style=\"color:#9f2846\">" .. JS.str(format(nil, player.m.points, 0))) .. "</h2> milestones,<br> which can be transformed into <h2 style=\"color:orange\">") .. JS.str(format(nil, tmp.sp.ambersGain))) .. "</h2> Prestige Ashes after a cooldown. (") .. JS.str(format(nil, player.sp.chalCooldown))) .. "s)"))
	end
	if (((player.sp.sparkMilestones:gt(0) and (JS.D(player.sp.ashedMilestones)):lt(player.sp.sparkMilestones)) and (JS.tonum(player.sp.burningTimer) > 0)) and JS.eq(tmp.sp.milestones[JS.k(player.sp.ashedMilestones)].permanent, false)) then
		h = (JS.str(h) .. ((((("<br><span style=\"color: orange\">Your " .. JS.str(format(nil, JS.add(player.sp.ashedMilestones, 1), 0))) .. JS.str(helper(nil, JS.add(player.sp.ashedMilestones, 1)))) .. " Spark Milestone will burn for ") .. JS.str(formatTime(nil, player.sp.burningTimer))) .. "</span>"))
	end
	things = JS.A(0)
	for i = 0, JS.cap(0, (JS.len(tmp.displayThings)) - 1, 1) do
		if JS.t(tmp.displayThings[JS.k(i)]) then
			JS.m(things, "push", rbx_str(nil, tmp.displayThings[JS.k(i)]))
		end
	end
	do return JS.O({
		t = "col",
		c = JS.A(2, JS.O({
		t = "html",
		h = h
	}, {"t", "h"}), JS.O({
		t = "html",
		h = JS.m(things, "join", "<br>")
	}, {"t", "h"}))
	}, {"t", "c"}) end
end
rbx_infoTab = function(this)
	local h, key, k
	h = (((("<h2>" .. JS.str(modInfo.name)) .. "</h2><br><h3>") .. JS.str(VERSION.withName)) .. "</h3>")
	if JS.t(modInfo.author) then
		h = (JS.str(h) .. ("<br>Made by " .. JS.str(modInfo.author)))
	end
	h = (JS.str(h) .. (("<br>The Modding Tree " .. JS.str(TMT_VERSION.tmtNum)) .. " by Acamaeda<br>The Prestige Tree made by Jacorb and Aarex<br><br>"))
	h = (JS.str(h) .. (("Time Played: " .. JS.str(formatTime(nil, player.timePlayed))) .. "<br><br><h3>Hotkeys</h3><br>"))
	for _, __k6 in JS.keys(hotkeys) do
		key = __k6
		k = hotkeys[key]
		if (JS.t(player[JS.k(k.layer)].unlocked) and JS.t(tmp[JS.k(k.layer)].hotkeys[JS.k(k.id)].unlocked)) then
			h = (JS.str(h) .. ("<br>" .. JS.str(k.description)))
		end
	end
	do return JS.O({
		t = "col",
		c = JS.A(1, JS.O({
		t = "html",
		h = h
	}, {"t", "h"}))
	}, {"t", "c"}) end
end
rbx_opt = function(this, label, sub, a)
	do return JS.O({
		t = "btn",
		k = "opt",
		cls = "can",
		h = (((("<b>" .. JS.str(label)) .. "</b><br><span style=\"font-size:12px\">") .. JS.str(sub)) .. "</span>"),
		a = rbx_act(nil, a)
	}, {"t", "k", "cls", "h", "a"}) end
end
rbx_optionsTab = function(this)
	local saving, displays
	saving = JS.O({
		t = "row",
		c = JS.A(5, rbx_opt(nil, "Save", "Save current progress", JS.A(2, "opt", "save")), rbx_opt(nil, "Hard Reset", "Reset current progress (press twice)", JS.A(2, "opt", "hardReset")), rbx_opt(nil, "Export save", "Show a save string you can copy", JS.A(2, "opt", "export")), rbx_opt(nil, "Import a save", "Paste a save string (web saves work too)", JS.A(2, "opt", "import")), rbx_opt(nil, (("Offline Production - [ " .. JS.str((if JS.t(options.offlineProd) then "ON" else "OFF"))) .. " ]"), "Produce resources when not in game", JS.A(2, "opt", "offlineProd")))
	}, {"t", "c"})
	displays = JS.O({
		t = "row",
		c = JS.A(4, rbx_opt(nil, "Milestone Showing Mode", (("[ " .. JS.str(MS_DISPLAYS[JS.k(JS.m(MS_SETTINGS, "indexOf", options.msDisplay))])) .. " ]"), JS.A(2, "opt", "msDisplay")), rbx_opt(nil, "Completed Challenges", (("[ " .. JS.str((if JS.t(options.hideChallenges) then "Hidden" else "Shown"))) .. " ]"), JS.A(2, "opt", "hideChallenges")), rbx_opt(nil, "Corrupt. Tooltip Pos.", (("[ " .. JS.str(CCTP_DISPLAYS[JS.k(JS.m(CCTP_SETTINGS, "indexOf", options.changeCorruptTooltipPlace))])) .. " ]"), JS.A(2, "opt", "cctp")), rbx_opt(nil, (("Milestones Order - [ " .. JS.str((if JS.t(options.reverseMilestones) then "Last to First" else "First to Last"))) .. " ]"), "Choose milestone ordering", JS.A(2, "opt", "reverseMilestones")))
	}, {"t", "c"})
	do return JS.O({
		t = "col",
		c = JS.A(5, JS.O({
		t = "html",
		h = "<h2>[ Saving ]</h2><br>"
	}, {"t", "h"}), saving, JS.O({
		t = "blank",
		w = "8px",
		hh = "20px"
	}, {"t", "w", "hh"}), JS.O({
		t = "html",
		h = "<h2>[ Displays ]</h2><br>"
	}, {"t", "h"}), displays)
	}, {"t", "c"}) end
end
rbx_endScreen = function(this)
	local h
	h = (("<br><h3>" .. JS.str(modInfo.winText)) .. "</h3><br><h3>Please check the Discord to see if there are new content updates!</h3><br><br>")
	if (not JS.t(player.timePlayedReset)) then
		h = (JS.str(h) .. (("It took you " .. JS.str(formatTime(nil, player.timePlayed))) .. " to beat the game.<br>"))
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
	}, {"t", "c"}))
	}, {"t", "c"}) end
end
rbx_view = function(this)
	local v, ended, tab, keys, key, k
	rbx_actions = JS.A(0)
	updateTabFormats(nil)
	v = JS.O({})
	ended = (if JS.t(tmp.gameEnded) then (not JS.t(player.keepGoing)) else tmp.gameEnded)
	JS.setk(v, "ended", (if JS.t(ended) then true else false))
	do
		local __ok7, __e8 = pcall(function()
			JS.setk(v, "menu", rbx_menu(nil))
		end)
		if not __ok7 then
			local e = __e8
			JS.setk(v, "menu", rbx_err(nil, "menu", e))
		end
	end
	do
		local __ok9, __e10 = pcall(function()
			JS.setk(v, "head", rbx_head(nil))
		end)
		if not __ok9 then
			local e = __e10
			JS.setk(v, "head", rbx_err(nil, "head", e))
		end
	end
	tab = player.tab
	JS.setk(v, "tabName", tab)
	JS.setk(v, "tabStyle", JS.O({}))
	do
		local __ok11, __e12 = pcall(function()
			if JS.t(ended) then
				JS.setk(v, "tab", rbx_endScreen(nil))
			elseif (tab == "info-tab") then
				JS.setk(v, "tab", rbx_infoTab(nil))
			elseif (tab == "options-tab") then
				JS.setk(v, "tab", rbx_optionsTab(nil))
			elseif (tab == "changelog-tab") then
				JS.setk(v, "tab", JS.O({
					t = "col",
					c = JS.A(1, JS.O({
					t = "html",
					h = rbx_str(nil, modInfo.changelog)
				}, {"t", "h"}))
				}, {"t", "c"}))
			elseif JS.t(layers[JS.k(tab)]) then
				JS.setk(v, "tab", rbx_layerTab(nil, tab))
				JS.setk(v, "tabStyle", rbx_tabStyle(nil, tab))
			else
				JS.setk(v, "tab", JS.O({
					t = "col",
					c = JS.A(0)
				}, {"t", "c"}))
			end
		end)
		if not __ok11 then
			local e = __e12
			JS.setk(v, "tab", rbx_err(nil, "tab", e))
		end
	end
	keys = JS.A(0)
	for _, __k13 in JS.keys(hotkeys) do
		key = __k13
		k = hotkeys[key]
		if (JS.t(player[JS.k(k.layer)].unlocked) and JS.t(tmp[JS.k(k.layer)].hotkeys[JS.k(k.id)].unlocked)) then
			JS.m(keys, "push", key)
		end
	end
	JS.setk(v, "keys", keys)
	do return v end
end
rbx_actions = JS.A(0)
rbx_MENU = JS.A(50, JS.A(2, "head", "[ Misc ]"), JS.A(3, "page", "info-tab", "Information"), JS.A(3, "page", "options-tab", "Options"), JS.A(3, "page", "changelog-tab", "Changelog"), JS.A(3, "layer", "ach", "Achievements"), JS.A(1, "hr"), JS.A(3, "headIf", "m", "[ Milestones (Normal Universe) ]"), JS.A(3, "layer", "m", "Milestone"), JS.A(3, "layer", "mm", "Meta Milestone"), JS.A(3, "layer", "em", "Extra Milestone"), JS.A(2, "hrIf", "m"), JS.A(3, "headIf", "p", "[ Row 1 ]"), JS.A(3, "layer", "p", "Prestige Points"), JS.A(2, "hrIf", "p"), JS.A(3, "headIf", "sp", "[ Row 2 ]"), JS.A(3, "layer", "pe", "Prestige Energy"), JS.A(3, "layer", "sp", "Super Prestige Points"), JS.A(3, "layer", "pb", "Prestige Boosts"), JS.A(3, "layer", "pp", "Prestige Power"), JS.A(2, "hrIf", "sp"), JS.A(3, "headIf", "hp", "[ Row 3 ]"), JS.A(3, "layer", "se", "Super Energy"), JS.A(3, "layer", "hp", "Hyper Prestige Points"), JS.A(3, "layer", "ep", "Exotic Prestige Points"), JS.A(2, "hrIf", "hp"), JS.A(3, "headIf", "ap", "[ Row 4 ]"), JS.A(3, "layer", "hb", "Hyper Boosts"), JS.A(3, "layer", "ap", "Atomic Prestige Points"), JS.A(3, "mpOut", "mp", "Multiverse Prestige Points"), JS.A(2, "multiverse", "Enter Prestige Multiverse "), JS.A(2, "hrIf", "ap"), JS.A(3, "headIf", "t", "[ Row 5 ]"), JS.A(3, "layer", "t", "Transcend Points"), JS.A(2, "hrIf", "t"), JS.A(3, "headIf", "pm", "[ Prestige Multiverse ]"), JS.A(2, "inMultiverse", "[ Main ]"), JS.A(3, "mpIn", "mp", "Multiverse Prestige Points"), JS.A(2, "multiverseIn", "Leave Prestige Multiverse "), JS.A(2, "hrIf", "pm"), JS.A(3, "headIf", "pm", "[ Row 0 ]"), JS.A(1, "pmLayer"), JS.A(2, "hrIf", "pm"), JS.A(2, "headPepCp", "[ Row 1 ]"), JS.A(3, "layer", "pep", "Prestiged-Exotic Prestige "), JS.A(1, "cpLayer"), JS.A(1, "cmLayer"), JS.A(1, "hrPepCp"), JS.A(3, "headIf", "ex", "[ Row 2 ]"), JS.A(3, "layer", "ex", "Exploration Points "), JS.A(2, "hrIf", "ex"))

end
