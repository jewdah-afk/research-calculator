--!nocheck
-- transpiled from layers/ex.js by port/build.js: do not edit
return function()
-- transpiled from layers/ex.js
checkFeatureDot = function(this, dot)
	if dot == nil then dot = "" end
	if JS.eq(dot, ("(" .. JS.str(tmp.ex.xGoal) .. ";" .. JS.str(tmp.ex.yGoal) .. ")")) then
		do
			local __sw1 = player.ex.zone
			local __ft2 = false
			repeat
				if __ft2 or JS.eq(__sw1, "a") then
					__ft2 = true
					if JS.cmp(player.ex.dotUnl, "<", player.ex.aLimit) then
						JS.setk(player.ex, "dotUnl", JS.add(player.ex.dotUnl, 1))
					end
					break
				end
				if __ft2 or JS.eq(__sw1, "a-02") then
					__ft2 = true
					if JS.cmp(player.ex.a2Unl, "<", player.ex.a2Limit) then
						JS.setk(player.ex, "a2Unl", JS.add(player.ex.a2Unl, 1))
					end
					break
				end
				if __ft2 or JS.eq(__sw1, "a-03") then
					__ft2 = true
					if JS.cmp(player.ex.a3Unl, "<", player.ex.a3Limit) then
						JS.setk(player.ex, "a3Unl", JS.add(player.ex.a3Unl, 1))
					end
					break
				end
				if __ft2 or JS.eq(__sw1, "b-01") then
					__ft2 = true
					if JS.cmp(player.ex.b1Unl, "<", player.ex.b1Limit) then
						JS.setk(player.ex, "b1Unl", JS.add(player.ex.b1Unl, 1))
					end
					break
				end
			until true
		end
	end
end
xMoveCost = function(this, x, checkedZone)
	if checkedZone == nil then checkedZone = "" end
	local cost = Decimal.pow(10, x:add(1):mul(11.76))
	do
		local __sw3 = (if (not JS.isnil(checkedZone)) then checkedZone else player.ex.zone)
		local __ft4 = false
		repeat
			if __ft4 or JS.eq(__sw3, "a") then
				__ft4 = true
				cost = Decimal.pow(10, x:add(1):mul(11.76))
				break
			end
			if __ft4 or JS.eq(__sw3, "a-02") then
				__ft4 = true
				cost = Decimal.pow(17, x:add(1):mul(22.6))
				break
			end
			if __ft4 or JS.eq(__sw3, "a-03") then
				__ft4 = true
				cost = Decimal.pow(15, x:add(1):mul(8.6))
				break
			end
			if __ft4 or JS.eq(__sw3, "b-01") then
				__ft4 = true
				cost = Decimal.pow(15, x:add(1):mul(23.6))
				break
			end
		until true
	end
	do return cost end
end
yMoveCost = function(this, x, checkedZone)
	if checkedZone == nil then checkedZone = "" end
	local cost = Decimal.pow(2, x:add(1):mul(3.76))
	do
		local __sw5 = (if (not JS.isnil(checkedZone)) then checkedZone else player.ex.zone)
		local __ft6 = false
		repeat
			if __ft6 or JS.eq(__sw5, "a") then
				__ft6 = true
				cost = Decimal.pow(2, x:add(1):mul(3.76))
				break
			end
			if __ft6 or JS.eq(__sw5, "a-02") then
				__ft6 = true
				cost = Decimal.pow(6, x:mul(3.25):add(1))
				break
			end
			if __ft6 or JS.eq(__sw5, "a-03") then
				__ft6 = true
				cost = Decimal.pow(8, x:mul(2.65):add(1))
				break
			end
			if __ft6 or JS.eq(__sw5, "b-01") then
				__ft6 = true
				cost = Decimal.pow(5, x:mul(2.75):add(1))
				break
			end
		until true
	end
	do return cost end
end
xGoalCheck = function(this, checkedZone)
	if checkedZone == nil then checkedZone = "" end
	local goal = JS.D(8)
	do
		local __sw7 = (if (not JS.isnil(checkedZone)) then checkedZone else player.ex.zone)
		local __ft8 = false
		repeat
			if __ft8 or JS.eq(__sw7, "a") then
				__ft8 = true
				x = JS.D(player.ex.dotUnl)
				goal = JS.D(8)
				if (JS.tonum(x) < 2) then
					goal = goal:add(x)
				end
				if (JS.tonum(x) >= 2) then
					goal = goal:add(x:add(1):mul(1.15)):floor()
				end
				break
			end
			if __ft8 or JS.eq(__sw7, "a-02") then
				__ft8 = true
				x = player.ex.a2Unl
				goal = JS.D(3)
				goal = goal:add(x)
				if JS.eq(x, 1) then
					goal = JS.D(2)
				end
				break
			end
			if __ft8 or JS.eq(__sw7, "a-03") then
				__ft8 = true
				x = player.ex.a3Unl
				goal = JS.D(2)
				goal = goal:add(x)
				if (JS.tonum(player.ex.a3Unl) >= 2) then
					goal = (JS.D(2)):add((JS.tonum(x) * 2))
				end
				break
			end
			if __ft8 or JS.eq(__sw7, "b-01") then
				__ft8 = true
				x = JS.D(player.ex.b1Unl)
				goal = JS.D(4)
				goal = (function() local __v9 = goal:add(x:add(1):mul(1.15)):floor(); goal = __v9 return __v9 end)()
				if x:gte(1) then
					goal = JS.D(1)
				end
				break
			end
		until true
	end
	do return goal end
end
yGoalCheck = function(this, checkedZone)
	if checkedZone == nil then checkedZone = "" end
	local goal = JS.D(4)
	do
		local __sw10 = (if (not JS.isnil(checkedZone)) then checkedZone else player.ex.zone)
		local __ft11 = false
		repeat
			if __ft11 or JS.eq(__sw10, "a") then
				__ft11 = true
				x = JS.D(player.ex.dotUnl)
				if (JS.tonum(x) < 2) then
					goal = goal:add(x)
				end
				if (JS.tonum(x) >= 2) then
					goal = goal:add(x:add(1):mul(1.25)):floor()
				end
				break
			end
			if __ft11 or JS.eq(__sw10, "a-02") then
				__ft11 = true
				x = JS.D(player.ex.a2Unl)
				goal = JS.D(2)
				goal = goal:add(x)
				if (JS.tonum(player.ex.a2Unl) >= 1) then
					goal = goal:add(2)
				end
				break
			end
			if __ft11 or JS.eq(__sw10, "a-03") then
				__ft11 = true
				x = JS.D(player.ex.a3Unl)
				goal = JS.D(5)
				goal = goal:add(x)
				if (JS.tonum(player.ex.a3Unl) >= 2) then
					goal = (JS.D(5)):add(Math.floor((JS.tonum(x) * 1.5)))
				end
				break
			end
			if __ft11 or JS.eq(__sw10, "b-01") then
				__ft11 = true
				x = JS.D(player.ex.b1Unl)
				goal = JS.D(4)
				goal = goal:add(x:add(1):mul(1.15)):floor()
				break
			end
		until true
	end
	do return goal end
end
calcFeatureBuyable = function(this)
	local zones = JS.A(4, "a", "a-02", "a-03", "b-01")
	local checkIf = JS.A(4, JS.A(2, "a", false), JS.A(2, "a-02", false), JS.A(2, "a-03", false), JS.A(2, "b-01", false))
	local counter = 0
	local checkPopup = false
	for _, __k12 in JS.vals(zones) do
		i = __k12
		local X = xGoalCheck(nil, i)
		local Y = yGoalCheck(nil, i)
		local xCost = JS.D(0)
		local yCost = JS.D(0)
		for c = 0, JS.cap(0, (JS.tonum(X)) - 1, 1) do
			xCost = xCost:add(xMoveCost(nil, JS.D(c), i))
		end
		for c = 0, JS.cap(0, (JS.tonum(Y)) - 1, 1) do
			yCost = yCost:add(yMoveCost(nil, JS.D(c), i))
		end
		if (player.cp.formatted:gte(yCost) and player.pm.essence:gte(xCost)) then
			checkPopup = true
			JS.set(checkIf[JS.k(counter)], 1, true)
		else
			JS.set(checkIf[JS.k(counter)], 1, false)
		end
		counter = (JS.tonum(counter) + 1)
	end
	checkFeatureObtainable = checkIf
	do return checkIf end
end
getFeatureBuyableDisplay = function(this)
	local check = calcFeatureBuyable(nil)
	local display = ""
	for _, __k13 in JS.vals(check) do
		i = __k13
		if JS.eq(i[1], true) then
			display = (JS.str(display) .. (" " .. JS.str(i[0]) .. ";"))
		end
	end
	display = (JS.str(display) .. ("</span>"))
	do return (if (not JS.eq(display, ("</span>"))) then (("<br><span style='color: red'>You can obtain a new feature at zones:") .. JS.str(display)) else "") end
end
pointWithinBounds = function(this, point, topLeft, bottomRight)
	if JS.cmp(point[0], "<", topLeft[0]) then
		do return false end
	end
	if JS.cmp(point[0], ">", bottomRight[0]) then
		do return false end
	end
	if JS.cmp(point[1], "<", topLeft[1]) then
		do return false end
	end
	if JS.cmp(point[1], ">", bottomRight[1]) then
		do return false end
	end
	do return true end
end
checkDirection = function(this, dir)
	local pos = nil
	do
		local __sw14 = dir
		local __ft15 = false
		repeat
			if __ft15 or JS.eq(__sw14, LEFT) then
				__ft15 = true
				pos = JS.A(2, player.ex.buyables[11]:sub(1):toNumber(), player.ex.buyables[12]:toNumber())
				break
			end
			if __ft15 or JS.eq(__sw14, RIGHT) then
				__ft15 = true
				pos = JS.A(2, player.ex.buyables[11]:add(1):toNumber(), player.ex.buyables[12]:toNumber())
				break
			end
			if __ft15 or JS.eq(__sw14, UP) then
				__ft15 = true
				pos = JS.A(2, player.ex.buyables[11]:toNumber(), player.ex.buyables[12]:sub(1):toNumber())
				break
			end
			if __ft15 or JS.eq(__sw14, DOWN) then
				__ft15 = true
				pos = JS.A(2, player.ex.buyables[11]:toNumber(), player.ex.buyables[12]:add(1):toNumber())
				break
			end
		until true
	end
	for _, __k16 in JS.vals(getWalls(nil)) do
		local wall = __k16
		if JS.t(pointWithinBounds(nil, pos, wall[0], wall[1])) then
			do return false end
		end
	end
	do return true end
end
getWalls = function(this)
	do
		local __sw17 = player.ex.zone
		local __ft18 = false
		repeat
			if __ft18 or JS.eq(__sw17, "a-02") then
				__ft18 = true
				do return JS.A(6, JS.A(2, JS.A(2, 3, 0), JS.A(2, 3, 1)), JS.A(2, JS.A(2, 3, 4), JS.A(2, 3, 6)), JS.A(2, JS.A(2, 1, 3), JS.A(2, 3, 3)), JS.A(2, JS.A(2, 0, 5), JS.A(2, 1, 5)), JS.A(2, JS.A(2, 1, 6), JS.A(2, 3, 6)), JS.A(2, JS.A(2, 3, 5), JS.A(2, 6, 5))) end
			end
			if __ft18 or JS.eq(__sw17, "a-03") then
				__ft18 = true
				do return JS.A(7, JS.A(2, JS.A(2, 0, 1), JS.A(2, 0, 2)), JS.A(2, JS.A(2, 2, 1), JS.A(2, 2, 1)), JS.A(2, JS.A(2, 1, 4), JS.A(2, 4, 4)), JS.A(2, JS.A(2, 4, 5), JS.A(2, 4, 7)), JS.A(2, JS.A(2, 0, 6), JS.A(2, 2, 6)), JS.A(2, JS.A(2, 2, 7), JS.A(2, 4, 7)), JS.A(2, JS.A(2, 2, 6), JS.A(2, 2, 7))) end
			end
			if __ft18 or JS.eq(__sw17, "b-01") then
				__ft18 = true
				do return JS.A(7, JS.A(2, JS.A(2, 0, 1), JS.A(2, 0, 1)), JS.A(2, JS.A(2, 2, 1), JS.A(2, 4, 1)), JS.A(2, JS.A(2, 6, 0), JS.A(2, 6, 3)), JS.A(2, JS.A(2, 1, 3), JS.A(2, 5, 3)), JS.A(2, JS.A(2, 1, 7), JS.A(2, 7, 7)), JS.A(2, JS.A(2, 0, 5), JS.A(2, 4, 5)), JS.A(2, JS.A(2, 6, 5), JS.A(2, 7, 5))) end
			end
			if true then
				__ft18 = true
				do return JS.A(0) end
			end
		until true
	end
end
checkIfMaxExploreBonus = function(this)
	local max = 0
	zone = player.ex.zone
	do
		local __sw19 = zone
		local __ft20 = false
		repeat
			if __ft20 or JS.eq(__sw19, "a") then
				__ft20 = true
				max = 3
				break
			end
			if __ft20 or JS.eq(__sw19, "a-02") then
				__ft20 = true
				max = 1
				break
			end
			if __ft20 or JS.eq(__sw19, "a-03") then
				__ft20 = true
				max = 6
				break
			end
			if __ft20 or JS.eq(__sw19, "b-01") then
				__ft20 = true
				max = 6
				break
			end
		until true
	end
	do return max end
end
checkPortalEnterDot = function(this, dot)
	if dot == nil then dot = "" end
	dot = JS.A(0)
	dot2 = JS.A(0)
	dotback = JS.A(0)
	zone = player.ex.zone
	do
		local __sw21 = zone
		local __ft22 = false
		repeat
			if __ft22 or JS.eq(__sw21, "a") then
				__ft22 = true
				dot = JS.A(2, "(10;5)", "a-02")
				dot2 = JS.A(2, "(9;9)", "a-03")
				break
			end
			if __ft22 or JS.eq(__sw21, "a-02") then
				__ft22 = true
				dotback = JS.A(2, "(1;1)", "a")
				dot = JS.A(2, "(5;3)", "b-01")
				dot2 = JS.A(2, "(6;5)", "c-01")
				break
			end
			if __ft22 or JS.eq(__sw21, "a-03") then
				__ft22 = true
				dotback = JS.A(2, "(1;1)", "a")
				break
			end
			if __ft22 or JS.eq(__sw21, "b-01") then
				__ft22 = true
				dotback = JS.A(2, "(1;1)", "a-02")
				break
			end
		until true
	end
	if JS.eq(dot[0], ("(" .. JS.str(player.ex.buyables[11]) .. ";" .. JS.str(player.ex.buyables[12]) .. ")")) then
		JS.setk(player.ex, "zone", dot[1])
		JS.set(player.ex.buyables, 11, JS.D(0))
		JS.set(player.ex.buyables, 12, JS.D(0))
	elseif JS.eq(dot2[0], ("(" .. JS.str(player.ex.buyables[11]) .. ";" .. JS.str(player.ex.buyables[12]) .. ")")) then
		JS.setk(player.ex, "zone", dot2[1])
		JS.set(player.ex.buyables, 11, JS.D(0))
		JS.set(player.ex.buyables, 12, JS.D(0))
	elseif JS.eq(dotback[0], ("(" .. JS.str(player.ex.buyables[11]) .. ";" .. JS.str(player.ex.buyables[12]) .. ")")) then
		JS.setk(player.ex, "zone", dotback[1])
		JS.set(player.ex.buyables, 11, JS.D(0))
		JS.set(player.ex.buyables, 12, JS.D(0))
	end
end
checkFeatureObtainable = JS.A(0)
addLayer(nil, "ex", JS.O({
	name = "exploration points",
	symbol = "EX",
	position = 2,
	startData = function(this)
	do return JS.O({
		unlocked = false,
		points = JS.D(0),
		zone = "a",
		dotUnl = 0,
		a2Unl = 0,
		a3Unl = 0,
		b1Unl = 0,
		c1Unl = 0,
		aLimit = 4,
		a2Limit = 3,
		a3Limit = 5,
		b1Limit = 1,
		c1Limit = 1
	}, {"unlocked", "points", "zone", "dotUnl", "a2Unl", "a3Unl", "b1Unl", "c1Unl", "aLimit", "a2Limit", "a3Limit", "b1Limit", "c1Limit"}) end
end,
	color = function(this)
	do return "#46a364" end
end,
	requires = function(this)
	do return JS.D(1e100) end
end,
	resource = function(this)
	do return "exploration points" end
end,
	baseResource = function(this)
	do return "prestige essence" end
end,
	baseAmount = function(this)
	do return player.pm.essence end
end,
	type = function(this)
	do return "static" end
end,
	gainMult = function(this)
	mult = JS.D(1)
	do return mult end
end,
	shouldNotify = function(this)
	local check = calcFeatureBuyable(nil)
	for _, __k23 in JS.vals(check) do
		i = __k23
		if JS.eq(i[1], true) then
			do return true end
		end
	end
end,
	gainExp = function(this)
	local m = JS.D(0.3)
	do return m end
end,
	xLimit = function(this)
	zone = player.ex.zone
	local x = JS.D(0)
	do
		local __sw24 = zone
		local __ft25 = false
		repeat
			if __ft25 or JS.eq(__sw24, "a") then
				__ft25 = true
				x = JS.D(8)
				x = x:mul(player.ex.points:add(1):pow(0.37):mul(1.05)):floor()
				break
			end
			if __ft25 or JS.eq(__sw24, "a-02") then
				__ft25 = true
				x = JS.D(6)
				break
			end
			if __ft25 or JS.eq(__sw24, "a-03") then
				__ft25 = true
				x = JS.D(6)
				x = x:mul(player.ex.points:sub(3):add(1):pow(0.37):mul(1.05)):floor()
				break
			end
			if __ft25 or JS.eq(__sw24, "b-01") then
				__ft25 = true
				x = JS.D(7)
				x = x:mul(player.ex.points:sub(3):add(1):pow(0.2)):floor()
				break
			end
		until true
	end
	do return x end
end,
	yLimit = function(this)
	zone = player.ex.zone
	local x = JS.D(0)
	do
		local __sw26 = zone
		local __ft27 = false
		repeat
			if __ft27 or JS.eq(__sw26, "a") then
				__ft27 = true
				x = JS.D(5)
				x = x:mul(player.ex.points:add(1):div(2):mul(1.25)):floor()
				break
			end
			if __ft27 or JS.eq(__sw26, "a-02") then
				__ft27 = true
				x = JS.D(6)
				break
			end
			if __ft27 or JS.eq(__sw26, "a-03") then
				__ft27 = true
				x = JS.D(7)
				x = x:mul(player.ex.points:sub(3):add(1):pow(0.37):mul(1.05)):floor()
				break
			end
			if __ft27 or JS.eq(__sw26, "b-01") then
				__ft27 = true
				x = JS.D(6)
				x = x:mul(player.ex.points:sub(3):add(1):pow(0.75):mul(1.05)):floor()
				break
			end
		until true
	end
	do return x end
end,
	xGoal = function(this, x)
	if x == nil then x = JS.D(player.ex.dotUnl) end
	local goal = JS.D(8)
	do
		local __sw28 = player.ex.zone
		local __ft29 = false
		repeat
			if __ft29 or JS.eq(__sw28, "a") then
				__ft29 = true
				goal = JS.D(8)
				if (JS.tonum(x) < 2) then
					goal = goal:add(x)
				end
				if (JS.tonum(x) >= 2) then
					goal = goal:add(x:add(1):mul(1.15)):floor()
				end
				break
			end
			if __ft29 or JS.eq(__sw28, "a-02") then
				__ft29 = true
				x = player.ex.a2Unl
				goal = JS.D(3)
				goal = goal:add(x)
				if JS.eq(x, 1) then
					goal = JS.D(2)
				end
				break
			end
			if __ft29 or JS.eq(__sw28, "a-03") then
				__ft29 = true
				x = player.ex.a3Unl
				goal = JS.D(2)
				goal = goal:add(x)
				if (JS.tonum(player.ex.a3Unl) >= 2) then
					goal = (JS.D(2)):add((JS.tonum(x) * 2))
				end
				break
			end
			if __ft29 or JS.eq(__sw28, "b-01") then
				__ft29 = true
				x = JS.D(player.ex.b1Unl)
				goal = JS.D(4)
				goal = (function() local __v30 = goal:add(x:add(1):mul(1.15)):floor(); goal = __v30 return __v30 end)()
				if x:gte(1) then
					goal = JS.D(1)
				end
				break
			end
		until true
	end
	do return goal end
end,
	yGoal = function(this, x)
	if x == nil then x = JS.D(player.ex.dotUnl) end
	local goal = JS.D(4)
	do
		local __sw31 = player.ex.zone
		local __ft32 = false
		repeat
			if __ft32 or JS.eq(__sw31, "a") then
				__ft32 = true
				if (JS.tonum(x) < 2) then
					goal = goal:add(x)
				end
				if (JS.tonum(x) >= 2) then
					goal = goal:add(x:add(1):mul(1.25)):floor()
				end
				break
			end
			if __ft32 or JS.eq(__sw31, "a-02") then
				__ft32 = true
				x = JS.D(player.ex.a2Unl)
				goal = JS.D(2)
				goal = goal:add(x)
				if (JS.tonum(player.ex.a2Unl) >= 1) then
					goal = goal:add(2)
				end
				break
			end
			if __ft32 or JS.eq(__sw31, "a-03") then
				__ft32 = true
				x = JS.D(player.ex.a3Unl)
				goal = JS.D(5)
				goal = goal:add(x)
				if (JS.tonum(player.ex.a3Unl) >= 2) then
					goal = (JS.D(5)):add(Math.floor((JS.tonum(x) * 1.5)))
				end
				break
			end
			if __ft32 or JS.eq(__sw31, "b-01") then
				__ft32 = true
				x = JS.D(player.ex.b1Unl)
				goal = JS.D(4)
				goal = goal:add(x:add(1):mul(1.15)):floor()
				break
			end
		until true
	end
	do return goal end
end,
	exOneEffect = function(this)
	local eff = JS.D(1)
	if (JS.tonum(player.ex.dotUnl) >= 1) then
		eff = eff:mul(player.ex.points:add(1):pow(2.674))
	end
	if hasUpgrade(nil, "ex", 12) then
		eff = eff:mul(player.ex.points:add(1):pow(2.867))
	end
	eff = softcap(nil, eff, JS.D(1000), 0.15)
	do return eff end
end,
	exponent = function(this)
	do return JS.D(3) end
end,
	row = 2,
	exponent = 5,
	hotkeys = JS.A(6, JS.O({
	key = "ctrl+e",
	description = "Ctrl+E: Reset for exploration points",
	onPress = function(this)
	if canReset(nil, this.layer) then
		doReset(nil, this.layer)
	end
end
}, {"key", "description", "onPress"}), JS.O({
	key = "ArrowDown",
	description = "↓: Move down on exploration grid",
	onPress = function(this)
	buyBuyable(nil, "ex", 12)
end
}, {"key", "description", "onPress"}), JS.O({
	key = "ArrowRight",
	description = "→: Move right on exploration grid",
	onPress = function(this)
	buyBuyable(nil, "ex", 11)
end
}, {"key", "description", "onPress"}), JS.O({
	key = "ArrowLeft",
	description = "←: Move left on exploration grid",
	onPress = function(this)
	buyBuyable(nil, "ex", 13)
end
}, {"key", "description", "onPress"}), JS.O({
	key = "ArrowUp",
	description = "↑: Move up on exploration grid",
	onPress = function(this)
	buyBuyable(nil, "ex", 14)
end
}, {"key", "description", "onPress"}), JS.O({
	key = "r",
	description = "R: Reset the current position",
	onPress = function(this)
	respecBuyables(nil, "ex")
end
}, {"key", "description", "onPress"})),
	layerShown = function(this)
	do return (hasMalware(nil, "m", 9) and JS.eq(player.mp.activeChallenge, 21)) end
end,
	upgrades = JS.O({
	rows = 4,
	cols = 4,
	[11] = JS.O({
	title = "Explore Upgrade 11",
	description = function(this)
	do return ("slog(points)*" .. JS.str((if (JS.tonum(player.ex.b1Unl) >= 1) then ("C") else ("Square root of c"))) .. "urrent coordinates summa<br>Exponents Prestige Essence effect outside Prestige Universe at boosted rate") end
end,
	cost = JS.D(2),
	unlocked = function(this)
	do return hasMalware(nil, "m", 14) end
end,
	effect = function(this)
	local base = 100
	local xPos = player.ex.buyables[11]
	local yPos = player.ex.buyables[12]
	local ret = (JS.D(player.points)):add(1):slog(2):max(1):mul(xPos:add(yPos):pow(0.5):mul(base)):max(1)
	if (JS.tonum(player.ex.b1Unl) >= 1) then
		ret = (JS.D(player.points)):add(1):slog(1.5):max(1):mul(xPos:add(yPos):mul(base)):max(1)
	end
	do return ret end
end,
	pay = function(this)

end,
	effectDisplay = function(this)
	do return ("^" .. JS.str(format(nil, this:effect(), 4))) end
end
}, {"title", "description", "cost", "unlocked", "effect", "pay", "effectDisplay"}),
	[12] = JS.O({
	title = "Explore Upgrade 12",
	description = "Zone a (8;4) reward formula is slightly better. Corruption Booster effect is slightly better.",
	cost = JS.D(3),
	unlocked = function(this)
	do return hasMalware(nil, "m", 14) end
end,
	pay = function(this)

end
}, {"title", "description", "cost", "unlocked", "pay"})
}, {"rows", "cols"}),
	buyables = JS.O({
	respec = function(this)
	for _, __k33 in JS.keys(player.ex.buyables) do
		i = __k33
		JS.set(player.ex.buyables, i, JS.D(0))
	end
end,
	respecMessage = function(this)
	do return (((("Are you sure you want to respec Multiversal Fusioners? This will reset your current position (" .. JS.str(format(nil, player.ex.buyables[11], 0))) .. ";") .. JS.str(format(nil, player.ex.buyables[12], 0))) .. ") to (0,0)!") end
end,
	respecText = "Respec Position",
	showRespec = function(this)
	do return player.ex.points:gte(1) end
end,
	rows = 4,
	cols = 4,
	[11] = JS.O({
	title = function(this)
	do return "<h3 class='exf'>Increase X</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return ((((("You went right for " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)], 0))) .. " tiles<br>") .. "Cost: ") .. JS.str(format(nil, data.cost, 0))) .. " Prestige Essences") end
end,
	cost = function(this, x)
	local cost = Decimal.pow(10, x:add(1):mul(11.76))
	do
		local __sw34 = player.ex.zone
		local __ft35 = false
		repeat
			if __ft35 or JS.eq(__sw34, "a") then
				__ft35 = true
				cost = Decimal.pow(10, x:add(1):mul(11.76))
				break
			end
			if __ft35 or JS.eq(__sw34, "a-02") then
				__ft35 = true
				cost = Decimal.pow(17, x:add(1):mul(22.6))
				break
			end
			if __ft35 or JS.eq(__sw34, "a-03") then
				__ft35 = true
				cost = Decimal.pow(15, x:add(1):mul(8.6))
				break
			end
			if __ft35 or JS.eq(__sw34, "b-01") then
				__ft35 = true
				cost = Decimal.pow(15, x:add(1):mul(23.6))
				break
			end
		until true
	end
	do return cost end
end,
	canAfford = function(this)
	local basicCond = player.pm.essence:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost)
	local can = false
	local maxX = tmp.ex.xLimit
	if ((JS.t(checkDirection(nil, RIGHT)) and player.ex.buyables[11]:lte(tmp.ex.xLimit)) and JS.t(basicCond)) then
		can = true
	end
	do return can end
end,
	buy = function(this)
	JS.setk(player.pm, "essence", player.pm.essence:sub(this:cost()))
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	if player[JS.k(this.layer)].buyables[13]:gt(0) then
		JS.set(player[JS.k(this.layer)].buyables, 13, player[JS.k(this.layer)].buyables[13]:sub(1))
	end
end,
	effect = function(this)
	local b = 1
	local eff = (JS.D(0)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b))
	do return eff end
end,
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 21) and player.ex.points:gte(1)) end
end,
	style = function(this)
	if (not JS.t(this:canAfford())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[12] = JS.O({
	title = function(this)
	do return "<h3 class='exf'>Increase Y</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return ((((("You went down for " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[JS.k(this.id)], 0))) .. " tiles<br>") .. "Cost: ") .. JS.str(format(nil, data.cost, 0))) .. " Corruption Essences") end
end,
	cost = function(this, x)
	local cost = Decimal.pow(2, x:add(1):mul(3.76))
	do
		local __sw36 = player.ex.zone
		local __ft37 = false
		repeat
			if __ft37 or JS.eq(__sw36, "a") then
				__ft37 = true
				cost = Decimal.pow(2, x:add(1):mul(3.76))
				break
			end
			if __ft37 or JS.eq(__sw36, "a-02") then
				__ft37 = true
				cost = Decimal.pow(6, x:mul(3.25):add(1))
				break
			end
			if __ft37 or JS.eq(__sw36, "a-03") then
				__ft37 = true
				cost = Decimal.pow(8, x:mul(2.65):add(1))
				break
			end
			if __ft37 or JS.eq(__sw36, "b-01") then
				__ft37 = true
				cost = Decimal.pow(5, x:mul(2.75):add(1))
				break
			end
		until true
	end
	do return cost end
end,
	canAfford = function(this)
	local basicCond = player.cp.formatted:gte(tmp[JS.k(this.layer)].buyables[JS.k(this.id)].cost)
	local can = false
	local maxX = tmp.ex.yLimit
	if ((JS.t(checkDirection(nil, DOWN)) and player.ex.buyables[12]:lte(tmp.ex.yLimit)) and JS.t(basicCond)) then
		can = true
	end
	do return can end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, JS.k(this.id), player[JS.k(this.layer)].buyables[JS.k(this.id)]:add(1))
	if player[JS.k(this.layer)].buyables[14]:gt(0) then
		JS.set(player[JS.k(this.layer)].buyables, 14, player[JS.k(this.layer)].buyables[14]:sub(1))
	end
end,
	effect = function(this)
	local b = 1
	local eff = (JS.D(0)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b))
	do return eff end
end,
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 21) and player.ex.points:gte(1)) end
end,
	style = function(this)
	if (not JS.t(this:canAfford())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[13] = JS.O({
	title = function(this)
	do return "<h3 class='exf'>Decrease X</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (("You went left for " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[13], 0))) .. " tiles<br>Move left without a cost") end
end,
	cost = function(this, x)
	local cost = Decimal.pow(2, x:add(1):mul(3.76))
	do
		local __sw38 = player.ex.zone
		local __ft39 = false
		repeat
			if __ft39 or JS.eq(__sw38, "a") then
				__ft39 = true
				cost = Decimal.pow(2, x:add(1):mul(3.76))
				break
			end
			if __ft39 or JS.eq(__sw38, "a-02") then
				__ft39 = true
				cost = Decimal.pow(1, x:mul(3.25):add(1))
				break
			end
			if __ft39 or JS.eq(__sw38, "a-03") then
				__ft39 = true
				cost = Decimal.pow(8, x:mul(2.65):add(1))
				break
			end
			if __ft39 or JS.eq(__sw38, "b-01") then
				__ft39 = true
				cost = Decimal.pow(5, x:mul(2.75):add(1))
				break
			end
		until true
	end
	do return cost end
end,
	canAfford = function(this)
	local basicCond = player.ex.buyables[11]:gt(0)
	local can = false
	local maxX = tmp.ex.yLimit
	if ((JS.t(checkDirection(nil, LEFT)) and player.ex.buyables[11]:lte(tmp.ex.xLimit)) and JS.t(basicCond)) then
		can = true
	end
	do return can end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, 11, player[JS.k(this.layer)].buyables[11]:sub(1))
	JS.set(player[JS.k(this.layer)].buyables, 13, player[JS.k(this.layer)].buyables[13]:add(1))
end,
	effect = function(this)
	local b = 1
	local eff = (JS.D(0)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b))
	do return eff end
end,
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 21) and player.ex.points:gte(1)) end
end,
	style = function(this)
	if (not JS.t(this:canAfford())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end
}, {"title", "display", "cost", "canAfford", "buy", "effect", "unlocked", "style"}),
	[14] = JS.O({
	title = function(this)
	do return "<h3 class='exf'>Decrease Y</h3>" end
end,
	display = function(this)
	local data = tmp[JS.k(this.layer)].buyables[JS.k(this.id)]
	do return (("You went up for " .. JS.str(format(nil, player[JS.k(this.layer)].buyables[14], 0))) .. " tiles<br>Move up without a cost") end
end,
	canAfford = function(this)
	local basicCond = player.ex.buyables[12]:gt(0)
	local can = false
	local maxX = tmp.ex.yLimit
	if ((JS.t(checkDirection(nil, UP)) and player.ex.buyables[12]:lte(tmp.ex.xLimit)) and JS.t(basicCond)) then
		can = true
	end
	do return can end
end,
	buy = function(this)
	JS.set(player[JS.k(this.layer)].buyables, 12, player[JS.k(this.layer)].buyables[12]:sub(1))
	JS.set(player[JS.k(this.layer)].buyables, 14, player[JS.k(this.layer)].buyables[14]:add(1))
end,
	effect = function(this)
	local b = 1
	local eff = (JS.D(0)):add(player[JS.k(this.layer)].buyables[JS.k(this.id)]:mul(b))
	do return eff end
end,
	unlocked = function(this)
	do return (JS.eq(player.mp.activeChallenge, 21) and player.ex.points:gte(1)) end
end,
	style = function(this)
	if (not JS.t(this:canAfford())) then
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "black",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	else
		do return JS.O({
			["border-radius"] = "0%",
			color = "white",
			["background-color"] = "rgb(68, 68, 68)",
			border = "2px solid",
			height = "100px"
		}, {"border-radius", "color", "background-color", "border", "height"}) end
	end
end
}, {"title", "display", "canAfford", "buy", "effect", "unlocked", "style"})
}, {"respec", "respecMessage", "respecText", "showRespec", "rows", "cols"}),
	tabFormat = JS.O({
	Main = JS.O({
	content = JS.A(6, "main-display", "prestige-button", "resource-display", JS.A(2, "display-text", function(this)
	table_ = ""
	if player.ex.points:gte(1) then
		table_ = (((((((("You can move in the zone by typing arrow keys and reset current position by clicking R button.<br>our exploration points are increasing your exploration area limits. For now, your area limits are: X axis - " .. JS.str(format(nil, tmp.ex.xLimit))) .. ", Y axis - ") .. JS.str(format(nil, tmp.ex.yLimit))) .. ".<br>By reaching some of positions in the area you can unlock new features.<br>New feature is at ") .. ("(" .. JS.str(tmp.ex.xGoal) .. ";" .. JS.str(tmp.ex.yGoal) .. ")")) .. (".")) .. JS.str(getFeatureBuyableDisplay(nil))) .. ("<br>Current zone: " .. JS.str(player.ex.zone)))
	end
	do return table_ end
end), "buyables", JS.A(2, "display-text", function(this)
	table_ = ""
	if player.ex.points:gte(1) then
		table_ = ("Green circle is current position, the yellow star is a position for a new feature" .. JS.str((if hasMalware(nil, "m", 14) then (",<br> the Portal is a teleport to a new zone, the yellow arrow is the portal to go to previous zone") else ".")) .. ".<br><svg style=\"background:url(zones/" .. JS.str(player.ex.zone) .. "-" .. JS.str(player.ex.points:min(checkIfMaxExploreBonus(nil))) .. ".svg)\"width=\"" .. JS.str(((JS.tonum(tmp.ex.xLimit) * 20) + 60)) .. "\" height=\"" .. JS.str(((JS.tonum(tmp.ex.yLimit) * 20) + 90)) .. "\" version=\"1.1\">\n\t\t\t\t\t<text x=\"0\" y=\"40\" fill=\"white\" font-size=\"12px\">0</text>")
	end
	zone = player.ex.zone
	local dot = nil
	local dot2 = nil
	local dot3 = nil
	dotback = nil
	do
		local __sw40 = zone
		local __ft41 = false
		repeat
			if __ft41 or JS.eq(__sw40, "a") then
				__ft41 = true
				dot = JS.A(2, 10, 5)
				dot2 = JS.A(2, 9, 8)
				break
			end
			if __ft41 or JS.eq(__sw40, "a-02") then
				__ft41 = true
				dot = JS.A(2, 5, 3)
				dotback = JS.A(2, 1, 1)
				break
			end
			if __ft41 or JS.eq(__sw40, "a-03") then
				__ft41 = true
				dot = JS.A(2, 16, 3)
				dotback = JS.A(2, 1, 1)
				break
			end
			if __ft41 or JS.eq(__sw40, "b-01") then
				__ft41 = true
				dot = JS.A(2, 25, 25)
				dotback = JS.A(2, 1, 1)
				break
			end
		until true
	end
	for xPos = 1, JS.cap(1, Math.floor(tmp.ex.xLimit), 1) do
		for y = 1, JS.cap(1, Math.floor(tmp.ex.yLimit), 1) do
			table_ = (JS.str(table_) .. ("\n\t\t\t\t\t\t <text x=\"0\" y=\"" .. JS.str((Math.floor((Math.floor(tmp.ex.yLimit) * 20)) + 75)) .. "\" fill=\"white\" font-size=\"16px\">Y</text>\n\t\t\t\t\t\t <text x=\"" .. JS.str((Math.floor((Math.floor(tmp.ex.xLimit) * 20)) + 35)) .. "\" y=\"40\" fill=\"white\" font-size=\"16px\">X</text>\n\t\t\t\t\t\t <text x=\"" .. JS.str((Math.floor((JS.tonum(xPos) * 20)) + 15)) .. "\" y=\"40\" fill=\"white\" font-size=\"12px\">" .. JS.str(format(nil, xPos, 0)) .. "</text>\n\t\t\t\t\t\t <text x=\"0\" y=\"" .. JS.str((Math.floor((JS.tonum(y) * 20)) + 55)) .. "\" fill=\"white\" font-size=\"12px\">" .. JS.str(format(nil, y, 0)) .. "</text>"))
		end
	end
	if player.ex.points:gte(1) then
		table_ = (JS.str(table_) .. ("\n\t\t\t\t\t<text x=\"" .. JS.str(player.ex.buyables[11]:mul(20):add(11)) .. "\" y=\"" .. JS.str(player.ex.buyables[12]:mul(20):add(55)) .. "\" fill=\"#46a364\" font-size=\"12px\">🟢</text>"))
	end
	if (((JS.cmp(player.ex.dotUnl, "<", player.ex.aLimit) or JS.cmp(player.ex.a2Unl, "<", player.ex.a2Limit)) or JS.cmp(player.ex.a3Unl, "<", player.ex.a3Limit)) and (tmp.ex.xGoal:lte(tmp.ex.xLimit) and tmp.ex.yGoal:lte(tmp.ex.yLimit))) then
		table_ = (JS.str(table_) .. ("<text x=\"" .. JS.str(tmp.ex.xGoal:mul(20):add(11)) .. "\" y=\"" .. JS.str(tmp.ex.yGoal:mul(20):add(55)) .. "\" fill=\"yellow\" font-size=\"20px\">★</text>"))
	end
	if hasMalware(nil, "m", 14) then
		table_ = (JS.str(table_) .. ("<text x=\"" .. JS.str((JS.D(dot[0])):mul(20):add(6)) .. "\" y=\"" .. JS.str((JS.D(dot[1])):mul(20):add(55)) .. "\" fill=\"yellow\" font-size=\"20px\">🌀</text>"))
		if (not JS.isnil(dot2)) then
			table_ = (JS.str(table_) .. ("<text x=\"" .. JS.str((JS.D(dot2[0])):mul(20):add(10)) .. "\" y=\"" .. JS.str((JS.D(dot2[1])):mul(20):add(55)) .. "\" fill=\"yellow\" font-size=\"20px\">꩜</text>"))
		end
		if (not JS.isnil(dot3)) then
			table_ = (JS.str(table_) .. ("<text x=\"" .. JS.str((JS.D(dot3[0])):mul(20):add(6)) .. "\" y=\"" .. JS.str((JS.D(dot3[1])):mul(20):add(55)) .. "\" fill=\"red\" font-size=\"20px\">꩜</text>"))
		end
		if (not JS.isnil(dotback)) then
			table_ = (JS.str(table_) .. ("<text x=\"" .. JS.str((JS.D(dotback[0])):mul(20):add(8)) .. "\" y=\"" .. JS.str((JS.D(dotback[1])):mul(20):add(57)) .. "\" fill=\"yellow\" font-size=\"20px\">⇦</text>"))
		end
	end
	do return (JS.str(table_) .. "</svg>") end
end))
}),
	Upgrades = JS.O({
	content = JS.A(1, function(this)
	if (player.tab == "ex") then
		do return JS.A(2, "column", JS.A(4, "main-display", "prestige-button", "resource-display", "upgrades")) end
	end
end)
}),
	Rewards = JS.O({
	content = JS.A(1, JS.A(2, "display-text", function(this)
	local tableA = (if hasMalware(nil, "m", 14) then "<br>Zone A Rewards:" else "")
	local tableA2 = (if (JS.tonum(player.ex.a2Unl) >= 1) then "<br>Zone A-2 Rewards:" else "")
	local tableA3 = (if (JS.tonum(player.ex.a3Unl) >= 1) then "<br>Zone A-3 Rewards:" else "")
	local tableB1 = (if (JS.tonum(player.ex.b1Unl) >= 1) then "<br>Zone B-1 Rewards:" else "")
	if (JS.tonum(player.ex.dotUnl) >= 1) then
		tableA = (JS.str(tableA) .. (("<br>(8;4) - [ Corruptions rewards are " .. JS.str(format(nil, tmp.ex.exOneEffect))) .. "x better.<br>Unlock one Super Prestige Upgrade in Normal Universe. ]"))
	end
	if (JS.tonum(player.ex.dotUnl) >= 2) then
		tableA = (JS.str(tableA) .. "<br>(9;5) - [ Unlock more Malware Milestones. ]")
	end
	if (JS.tonum(player.ex.dotUnl) >= 3) then
		tableA = (JS.str(tableA) .. "<br>(11;7) - [ Unlock one Malware Milestones. ]")
	end
	if (JS.tonum(player.ex.a2Unl) >= 1) then
		tableA2 = (JS.str(tableA2) .. "<br>Zone A-2 (3;2) - [ Unlock Security Algorithms. ]")
	end
	if (JS.tonum(player.ex.a2Unl) >= 2) then
		tableA2 = (JS.str(tableA2) .. "<br>Zone A-2 (4;4) - [ Expand Disks to 6x6 grid. ]")
	end
	if (JS.tonum(player.ex.b1Unl) >= 1) then
		tableB1 = (JS.str(tableB1) .. "<br>Zone B-1 (5;5) - [ Explore Upgrade 11 formula is better ]")
	end
	table_ = (((("Currently unlocked:" .. JS.str(tableA)) .. JS.str(tableA2)) .. JS.str(tableA3)) .. JS.str(tableB1))
	do return table_ end
end))
})
}, {"Main", "Upgrades", "Rewards"}),
	branches = JS.A(2, "pep", "cp"),
	softcap = function(this)
	do return JS.D(math.huge) end
end,
	softcapPower = function(this)
	do return JS.D(1) end
end,
	doReset = function(this, l)
	if JS.eq(player.mp.activeChallenge, 21) then
		JS.setk(player.pm, "essence", JS.D(0))
	end
end,
	update = function(this, diff)
	calcFeatureBuyable(nil)
	if JS.isnil(player.ex.zone) then
		JS.setk(player.ex, "zone", "a")
	end
	checkFeatureDot(nil, (function() local __v42 = ("(" .. JS.str(player.ex.buyables[11]) .. ";" .. JS.str(player.ex.buyables[12]) .. ")"); dot = __v42 return __v42 end)())
	if hasMalware(nil, "m", 14) then
		checkPortalEnterDot(nil, (function() local __v43 = ("(" .. JS.str(player.ex.buyables[11]) .. ";" .. JS.str(player.ex.buyables[12]) .. ")"); dot = __v43 return __v43 end)())
	end
end
}, {"name", "symbol", "position", "startData", "color", "requires", "resource", "baseResource", "baseAmount", "type", "gainMult", "shouldNotify", "gainExp", "xLimit", "yLimit", "xGoal", "yGoal", "exOneEffect", "exponent", "row", "exponent", "hotkeys", "layerShown", "upgrades", "buyables", "tabFormat", "branches", "softcap", "softcapPower", "doReset", "update"}))

end
