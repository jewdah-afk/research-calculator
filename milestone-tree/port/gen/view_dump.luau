--!nocheck
-- transpiled from view_dump.js by port/build.js: do not edit
return function()
-- transpiled from view_dump.js
rbx_viewDump = function(this, tag)
	local out, tabs, l, i, subs, t, j
	out = JS.A(0)
	tabs = JS.A(2, "info-tab", "options-tab")
	for _, __k1 in JS.keys(layers) do
		l = __k1
		if (JS.eq(tmp[l].layerShown, true) and (not (l == "tree-tab"))) then
			JS.m(tabs, "push", l)
		end
	end
	for i = 0, JS.cap(0, (JS.len(tabs)) - 1, 1) do
		rbx_do(nil, JS.A(2, "tab", tabs[JS.k(i)]))
		subs = JS.A(1, JS.NULL)
		t = tmp[JS.k(tabs[JS.k(i)])]
		if ((JS.t(t) and JS.t(t.tabFormat)) and (not Array.isArray(t.tabFormat))) then
			subs = Object.keys(t.tabFormat)
		end
		for j = 0, JS.cap(0, (JS.len(subs)) - 1, 1) do
			if (not (subs[JS.k(j)] == JS.NULL)) then
				rbx_do(nil, JS.A(4, "subtab", tabs[JS.k(i)], "mainTabs", subs[JS.k(j)]))
			end
			JS.m(out, "push", ((((((("##" .. JS.str(tag)) .. " ") .. JS.str(tabs[JS.k(i)])) .. " ") .. JS.str(subs[JS.k(j)])) .. "\n") .. JS.str(JSON.stringify(rbx_view(nil)))))
		end
	end
	do return JS.m(out, "join", "\n") end
end
rbx_viewActs = function(this, tag, acts)
	local last, i, a
	last = "m"
	for i = 0, JS.cap(0, (JS.len(acts)) - 1, 1) do
		a = acts[JS.k(i)]
		if (a[0] == "tick") then
			JS.setk(player, "time", (JS.tonum(player.time) - (JS.tonum(a[2]) * 1000)))
			rbx_tick(nil)
		else
			rbx_do(nil, JS.A(2, "tab", a[1]))
			rbx_view(nil)
			if (a[0] == "reset") then
				rbx_do(nil, JS.A(2, "reset", a[1]))
			elseif (a[0] == "upg") then
				rbx_do(nil, JS.A(3, "upg", a[1], a[2]))
			elseif (a[0] == "buy") then
				rbx_do(nil, JS.A(3, "buy", a[1], a[2]))
			elseif (a[0] == "chal") then
				rbx_do(nil, JS.A(3, "chal", a[1], a[2]))
			elseif (a[0] == "click") then
				rbx_do(nil, JS.A(3, "click", a[1], a[2]))
			end
		end
		last = a[1]
	end
	rbx_do(nil, JS.A(2, "tab", last))
	do return ((((((("##" .. JS.str(tag)) .. " acts ") .. JS.str(last)) .. "\n") .. JS.str(JSON.stringify(rbx_view(nil)))) .. "\n") .. JS.str(JSON.stringify(rbx_popups(nil, 0)))) end
end

end
