--!nocheck
--[[
	Fast: native versions of the game's hottest per-tick functions, installed after the game chunks load
	(Session:_start). Same behaviour as the transpiled code, down to the RNG draws, the iteration order and the
	sloppy globals the JS leaves behind (`i`, `l`), without the JS-emulation cost in the inner loops. The fuzz parity
	test (./test.sh game) compares every player value with the web game after these run.

	    Fast(JS, ENV)
]]

return function(JS, ENV)
	local layers = ENV.layers
	local cp = layers and layers.cp
	if cp == nil or type(cp.update) ~= "function" then return end

	-- layers/cp.js update(diff): the two "pick the least corrupted cell" passes walk the grid inside a walk of the
	-- grid (49 x 49 twice a tick) through JS property access; they run natively here on arrays of the cells
	local function pass(player, tmp, kind: string, chosenKey: string, cdKey: string)
		local pcp = player.cp
		local grid = pcp.grid
		local keys = {}
		for _, k in JS.keys(grid) do keys[#keys + 1] = k end
		local n = #keys
		-- per cell: its level as a number, whether it is "0" by JS ==, and its type (kept current when a level changes)
		local lv, num, zero, ty = table.create(n), table.create(n), table.create(n), table.create(n)
		for j = 1, n do
			local c = grid[keys[j]]
			local v = c.level
			lv[j], num[j], zero[j], ty[j] = v, JS.tonum(v), JS.eq(v, 0), c.type
		end
		local Math = ENV.Math -- the page's Math (its seeded random)
		local totalC = JS.tonum(pcp.totalCorrupt)
		local a2 = JS.tonum(player.ex.a2Unl) >= 1
		local cdZero = JS.eq(pcp[cdKey], 0)
		local noChal = JS.isnil(player.pm.activeChallenge)
		local lastL = ENV.l
		for j = 1, n do
			local i = keys[j]
			ENV.i = i
			-- per cell, as the page does (the values do not change inside the pass, the RNG draw must happen)
			local rangeMul = Math.floor(totalC / 4)
			local addLevel = Math.floor(totalC / 5) * 1.5
			local _ranType = Math.floor(Math.random() * 1.5)
			local pm13 = if player.pm.best:gte(13) then tmp.pm.pMilestone13Effect else 0
			local range = JS.tonum(JS.add(10, addLevel)) - JS.tonum(pm13)
			local startN = JS.tonum(JS.D(1):add(rangeMul))
			local minCorrupt = 1000
			local mine = a2 and ty[j] == kind and num[j] >= 1 and cdZero
			local myDiff = if mine then num[j] - startN else 0
			-- numbers only in here: JS Math.min and == on finite numbers are math.min and ==; a NaN level would
			-- behave the same too (min(NaN) is NaN in both, NaN == x is false)
			for m = 1, n do
				lastL = keys[m]
				if not zero[m] and ty[m] == kind then
					local d = num[m] - startN
					minCorrupt = if d ~= d or minCorrupt ~= minCorrupt then 0 / 0 elseif d < minCorrupt then d else minCorrupt
				end
				if mine and myDiff == minCorrupt then
					JS.setk(pcp, chosenKey, i)
					break
				end
			end
			local cell = grid[i]
			if JS.cmp(cell.level, ">", range) and noChal then
				JS.setk(cell, "level", JS.tonum(ENV.getGridData(nil, "cp", i).level) - JS.tonum(pm13))
				local v = cell.level
				lv[j], num[j], zero[j] = v, JS.tonum(v), JS.eq(v, 0)
			end
		end
		ENV.l = lastL
	end

	cp.update = function(this, diff)
		local player, tmp = ENV.player, ENV.tmp
		-- everything before the two passes: the transpiled function's own text (layers_cp.luau), unchanged
		local pcp = player.cp
		if ((not JS.isnil(pcp.trojanChosen)) and (JS.tonum(player.ex.a2Unl) >= 1)) then
			JS.setk(pcp, "pointsInCorrupt", pcp.pointsInCorrupt:add(tmp.cp.gainInCorrupt:times(diff)))
		end
		if ((not JS.isnil(pcp.chosenBackdoor)) and (JS.tonum(player.ex.a2Unl) >= 1)) then
			JS.setk(pcp, "peInCorrupt", pcp.peInCorrupt:add(tmp.cp.peGainInCorrupt:times(diff)))
		end
		if (JS.tonum(pcp.cooldown) > 0) then
			JS.setk(pcp, "cooldown", (JS.tonum(pcp.cooldown) - JS.tonum(diff)))
		end
		if (JS.tonum(pcp.cooldown) < 0) then
			JS.setk(pcp, "cooldown", 0)
		end
		if (JS.tonum(pcp.cooldown2) > 0) then
			JS.setk(pcp, "cooldown2", (JS.tonum(pcp.cooldown2) - JS.tonum(diff)))
		end
		if (JS.tonum(pcp.cooldown2) < 0) then
			JS.setk(pcp, "cooldown2", 0)
		end
		if JS.m(pcp.pool, "includes", "pow") then
			JS.setk(pcp, "pool", JS.A(2, "div", "pm"))
		end
		local getGridData, gridEssence, gridCost, doPopup = ENV.getGridData, ENV.gridEssence, ENV.gridCost, ENV.doPopup
		local function fix(key)
			JS.setk(player.cp, "formatted", player.cp.formatted:add(gridEssence(nil, "cp", key)))
			JS.set(player.cp.grid, JS.k(key), JS.O({
				level = 0,
				active = false,
				fixed = false,
				type = getGridData(nil, "cp", key).type,
				cautPower = getGridData(nil, "cp", key).cautPower,
			}, { "level", "active", "fixed", "type", "cautPower" }))
			doPopup(nil, "none", "Corruption was fixed!", "Corruption Info", 3, "black", "lime")
			JS.setk(player.cp, "totalCorrupt", JS.add(player.cp.totalCorrupt, 1))
		end
		local slots = ENV.activeCorruptions(nil)
		local all = JS.m(ENV.Object.keys(pcp.grid), "filter", function(_, x)
			return (JS.cmp(player.cp.grid[JS.k(x)].level, "<", ENV.antiCorrupt(nil)) and (JS.tonum(player.cp.grid[JS.k(x)].level) > 0))
		end)
		for i = 0, JS.cap(0, (JS.len(all)) - 1, 1) do
			if ((player.cm.best:gte(3) and (JS.len(all) > 0)) and JS.isnil(player.pm.activeChallenge)) then
				fix(all[JS.k(i)])
			end
		end
		ENV.setTimeout(nil, 100000)
		if ((((JS.eq(player.mp.activeChallenge, 21) and (JS.tonum(player.ex.a2Unl) >= 1)) and (not JS.isnil(player.cp.trojanChosen))) and (player.cp.pointsInCorrupt:gte(gridCost(nil, "cp", player.cp.trojanChosen)) and (getGridData(nil, "cp", player.cp.trojanChosen).type == "div"))) and (JS.tonum(getGridData(nil, "cp", player.cp.trojanChosen).level) >= 1)) then
			fix(player.cp.trojanChosen)
			JS.setk(player.cp, "cooldown", ENV.buyableEffect(nil, "cp", 33))
			JS.setk(player.cp, "trojanChosen", nil)
			JS.setk(player.cp, "pointsInCorrupt", JS.D(0))
		end
		if ((((JS.eq(player.mp.activeChallenge, 21) and (JS.tonum(player.ex.a2Unl) >= 1)) and (not JS.isnil(player.cp.chosenBackdoor))) and (player.cp.peInCorrupt:gte(gridCost(nil, "cp", player.cp.chosenBackdoor)) and (getGridData(nil, "cp", player.cp.chosenBackdoor).type == "pm"))) and (JS.tonum(getGridData(nil, "cp", player.cp.chosenBackdoor).level) >= 1)) then
			fix(player.cp.chosenBackdoor)
			JS.setk(player.cp, "cooldown2", ENV.buyableEffect(nil, "cp", 34))
			JS.setk(player.cp, "chosenBackdoor", nil)
			JS.setk(player.cp, "peInCorrupt", JS.D(0))
		end
		for i = 0, JS.cap(0, (JS.len(slots)) - 1, 1) do
			if JS.isnil(player.pm.activeChallenge) then
				if ((JS.tonum(player.ex.a2Unl) <= 1) and (player.points:gte(gridCost(nil, "cp", slots[JS.k(i)])) and (getGridData(nil, "cp", slots[JS.k(i)]).type == "div"))) then
					fix(slots[JS.k(i)])
				end
				ENV.setTimeout(nil, 100000)
				if (player.pm.essence:gte(gridCost(nil, "cp", slots[JS.k(i)])) and (getGridData(nil, "cp", slots[JS.k(i)]).type == "pm")) then
					fix(slots[JS.k(i)])
				end
			end
		end
		pass(player, tmp, "div", "trojanChosen", "cooldown")
		pass(player, tmp, "pm", "chosenBackdoor", "cooldown2")
	end
end
