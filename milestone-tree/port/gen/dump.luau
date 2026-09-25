--!nocheck
-- transpiled from dump.js by port/build.js: do not edit
return function()
-- transpiled from dump.js
u__dv = function(this, x)
	local s, a, l, ll
	if JS.instanceof(x, Decimal) then
		s = JS.P(x, "sign")
		if JS.eq(s, 0) then
			do return "D0" end
		end
		if isNaN(nil, s) then
			do return "DNaN" end
		end
		a = x:abs()
		if a:gte(Decimal.dInf) then
			do return (("D" .. JS.str(s)) .. ":inf") end
		end
		if a:lt(1000000000000000) then
			do return ((("D" .. JS.str(s)) .. ":0:") .. JS.str(a:toNumber())) end
		end
		l = a:log10()
		if l:lt(1000000000000000) then
			do return ((("D" .. JS.str(s)) .. ":1:") .. JS.str(l:toNumber())) end
		end
		ll = l:log10()
		if ll:lt(1000000000000000) then
			do return ((("D" .. JS.str(s)) .. ":2:") .. JS.str(ll:toNumber())) end
		end
		do return ((("D" .. JS.str(s)) .. ":3:") .. JS.str(ll:log10():toNumber())) end
	end
	if (JS.typeof(x) == "number") then
		do return ("N" .. JS.str(x)) end
	end
	if (JS.typeof(x) == "string") then
		do return ("S" .. JS.str(x)) end
	end
	if (JS.typeof(x) == "boolean") then
		do return ("B" .. JS.str(x)) end
	end
	do return JS.NULL end
end
u__dump = function(this, x, path, out, depth)
	local v, i, ks, k, j, kk
	if (JS.tonum(depth) > 12) then
		do return end
	end
	if ((x == nil) or (x == JS.NULL)) then
		JS.m(out, "push", (JS.str(path) .. "=nil"))
		do return end
	end
	v = u__dv(nil, x)
	if (not (v == JS.NULL)) then
		JS.m(out, "push", ((JS.str(path) .. "=") .. JS.str(v)))
		do return end
	end
	if (JS.typeof(x) == "function") then
		do return end
	end
	if Array.isArray(x) then
		JS.m(out, "push", ((JS.str(path) .. "#") .. JS.str(JS.len(x))))
		for i = 0, JS.cap(0, (JS.len(x)) - 1, 1) do
			u__dump(nil, x[JS.k(i)], (((JS.str(path) .. "[") .. JS.str(i)) .. "]"), out, JS.add(depth, 1))
		end
		do return end
	end
	if (JS.typeof(x) == "object") then
		ks = JS.A(0)
		for _, __k1 in JS.keys(x) do
			k = __k1
			JS.m(ks, "push", ("" .. JS.str(k)))
		end
		JS.m(ks, "sort")
		for j = 0, JS.cap(0, (JS.len(ks)) - 1, 1) do
			kk = ks[JS.k(j)]
			if (((kk == "tabFormat") or (kk == "content")) or ((kk == "grid") and (path == "tmp.cp"))) then
				continue
			end
			u__dump(nil, x[JS.k(kk)], ((JS.str(path) .. ".") .. JS.str(kk)), out, JS.add(depth, 1))
		end
	end
end
u__dumpAll = function(this, tag)
	local out, ls, l, i
	out = JS.A(0)
	u__dump(nil, player, "player", out, 0)
	ls = JS.A(0)
	for _, __k2 in JS.keys(layers) do
		l = __k2
		JS.m(ls, "push", l)
	end
	JS.m(ls, "sort")
	for i = 0, JS.cap(0, (JS.len(ls)) - 1, 1) do
		u__dump(nil, tmp[JS.k(ls[JS.k(i)])], ("tmp." .. JS.str(ls[JS.k(i)])), out, 0)
	end
	u__dump(nil, tmp.pointGen, "tmp.pointGen", out, 0)
	do return ((("##" .. JS.str(tag)) .. "\n") .. JS.str(JS.m(out, "join", "\n"))) end
end
u__act = function(this, list)
	local i, a, kind, l, id
	for i = 0, JS.cap(0, (JS.len(list)) - 1, 1) do
		a = list[JS.k(i)]
		kind = a[0]
		l = a[1]
		id = a[2]
		if (kind == "tick") then
			updateTemp(nil)
			gameLoop(nil, id)
			fixNaNs(nil)
		elseif (kind == "reset") then
			updateTemp(nil)
			if JS.t(tmp[JS.k(l)].canReset) then
				doReset(nil, l)
			end
		elseif (kind == "forcereset") then
			updateTemp(nil)
			doReset(nil, l, true)
		elseif (kind == "upg") then
			updateTemp(nil)
			buyUpg(nil, l, id)
		elseif (kind == "buy") then
			updateTemp(nil)
			buyBuyable(nil, l, id)
		elseif (kind == "chal") then
			updateTemp(nil)
			startChallenge(nil, l, id)
		elseif (kind == "click") then
			updateTemp(nil)
			if ((JS.t(tmp[JS.k(l)].clickables[JS.k(id)]) and JS.t(tmp[JS.k(l)].clickables[JS.k(id)].unlocked)) and JS.t(tmp[JS.k(l)].clickables[JS.k(id)].canClick)) then
				clickClickable(nil, l, id)
			end
		end
	end
	updateTemp(nil)
end

end
