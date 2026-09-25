--!nocheck
-- transpiled from bot.js by port/build.js: do not edit
return function()
-- transpiled from bot.js
u__canon = function(this, x)
	local l
	x = JS.D(x)
	if x:lt(1000000000000000) then
		do return ("" .. JS.str(JS.m(x:toNumber(), "toPrecision", 6))) end
	end
	l = x:log10()
	if l:lt(1000000000000000) then
		do return ("E" .. JS.str(JS.m(l:toNumber(), "toPrecision", 6))) end
	end
	do return ("EE" .. JS.str(JS.m(l:log10():toNumber(), "toPrecision", 6))) end
end
u__botLayers = function(this)
	local out, l
	out = JS.A(0)
	for _, __k1 in JS.keys(layers) do
		l = __k1
		JS.m(out, "push", l)
	end
	JS.m(out, "sort")
	do return out end
end
u__tick = function(this, dt)
	local ls, i, l, t, id, k
	updateTemp(nil)
	gameLoop(nil, dt)
	fixNaNs(nil)
	ls = u__botLayers(nil)
	for i = 0, JS.cap(0, (JS.len(ls)) - 1, 1) do
		l = ls[JS.k(i)]
		if (not JS.t(tmp[JS.k(l)].layerShown)) then
			continue
		end
		t = tmp[JS.k(l)]
		if JS.t(layers[JS.k(l)].upgrades) then
			for _, __k2 in JS.keys(layers[JS.k(l)].upgrades) do
				id = __k2
				if (((isPlainObject(nil, layers[JS.k(l)].upgrades[id]) and (not hasUpgrade(nil, l, id))) and JS.t(tmp[JS.k(l)].upgrades[id].unlocked)) and canAffordUpgrade(nil, l, id)) then
					buyUpg(nil, l, id)
				end
			end
		end
		if JS.t(layers[JS.k(l)].buyables) then
			for _, __k3 in JS.keys(layers[JS.k(l)].buyables) do
				id = __k3
				if isPlainObject(nil, layers[JS.k(l)].buyables[id]) then
					for k = 0, (5) - 1 do
						if (JS.t(tmp[JS.k(l)].buyables[id].unlocked) and JS.t(tmp[JS.k(l)].buyables[id].canBuy)) then
							buyBuyable(nil, l, id)
						else
							break
						end
					end
				end
			end
		end
		if ((not (t.type == "none")) and JS.t(t.canReset)) then
			if (((t.type == "static") or player[JS.k(l)].points:lte(0)) or t.resetGain:gte(player[JS.k(l)].points)) then
				doReset(nil, l)
			end
		end
	end
end
u__snap = function(this, i)
	local s, ls, j, l
	s = ((("t" .. JS.str(i)) .. " pts=") .. JS.str(u__canon(nil, player.points)))
	ls = u__botLayers(nil)
	for j = 0, JS.cap(0, (JS.len(ls)) - 1, 1) do
		l = ls[JS.k(j)]
		if ((JS.t(player[JS.k(l)]) and JS.instanceof(player[JS.k(l)].points, Decimal)) and JS.t(tmp[JS.k(l)].layerShown)) then
			s = ((((((JS.str(s) .. " ") .. JS.str(l)) .. "=") .. JS.str(u__canon(nil, player[JS.k(l)].points))) .. "/u") .. JS.str(JS.len(player[JS.k(l)].upgrades)))
		end
	end
	do return s end
end

end
