--!nocheck
-- transpiled from utils/easyAccess.js by port/build.js: do not edit
return function()
-- transpiled from utils/easyAccess.js
hasUpgrade = function(this, layer, id)
	do return ((JS.m(player[JS.k(layer)].upgrades, "includes", toNumber(nil, id)) or JS.m(player[JS.k(layer)].upgrades, "includes", JS.m(id, "toString"))) and (not JS.t(tmp[JS.k(layer)].deactivated))) end
end
hasMilestone = function(this, layer, id)
	do return ((JS.m(player[JS.k(layer)].milestones, "includes", toNumber(nil, id)) or JS.m(player[JS.k(layer)].milestones, "includes", JS.m(id, "toString"))) and (not JS.t(tmp[JS.k(layer)].deactivated))) end
end
hasAchievement = function(this, layer, id)
	do return ((JS.m(player[JS.k(layer)].achievements, "includes", toNumber(nil, id)) or JS.m(player[JS.k(layer)].achievements, "includes", JS.m(id, "toString"))) and (not JS.t(tmp[JS.k(layer)].deactivated))) end
end
hasChallenge = function(this, layer, id)
	do return (if JS.t(player[JS.k(layer)].challenges[JS.k(id)]) then (not JS.t(tmp[JS.k(layer)].deactivated)) else player[JS.k(layer)].challenges[JS.k(id)]) end
end
maxedChallenge = function(this, layer, id)
	do return (JS.cmp(player[JS.k(layer)].challenges[JS.k(id)], ">=", tmp[JS.k(layer)].challenges[JS.k(id)].completionLimit) and (not JS.t(tmp[JS.k(layer)].deactivated))) end
end
challengeCompletions = function(this, layer, id)
	do return player[JS.k(layer)].challenges[JS.k(id)] end
end
getBuyableAmount = function(this, layer, id)
	do return player[JS.k(layer)].buyables[JS.k(id)] end
end
setBuyableAmount = function(this, layer, id, amt)
	JS.set(player[JS.k(layer)].buyables, JS.k(id), amt)
end
addBuyables = function(this, layer, id, amt)
	JS.set(player[JS.k(layer)].buyables, JS.k(id), player[JS.k(layer)].buyables[JS.k(id)]:add(amt))
end
getClickableState = function(this, layer, id)
	do return player[JS.k(layer)].clickables[JS.k(id)] end
end
setClickableState = function(this, layer, id, state)
	JS.set(player[JS.k(layer)].clickables, JS.k(id), state)
end
getGridData = function(this, layer, id)
	do return player[JS.k(layer)].grid[JS.k(id)] end
end
setGridData = function(this, layer, id, data)
	JS.set(player[JS.k(layer)].grid, JS.k(id), data)
end
upgradeEffect = function(this, layer, id)
	do return tmp[JS.k(layer)].upgrades[JS.k(id)].effect end
end
challengeEffect = function(this, layer, id)
	do return tmp[JS.k(layer)].challenges[JS.k(id)].rewardEffect end
end
buyableEffect = function(this, layer, id)
	do return tmp[JS.k(layer)].buyables[JS.k(id)].effect end
end
clickableEffect = function(this, layer, id)
	do return tmp[JS.k(layer)].clickables[JS.k(id)].effect end
end
milestoneEffect = function(this, layer, id)
	do return tmp[JS.k(layer)].milestones[JS.k(id)].effect end
end
achievementEffect = function(this, layer, id)
	do return tmp[JS.k(layer)].achievements[JS.k(id)].effect end
end
gridEffect = function(this, layer, id)
	do return gridRun(nil, layer, "getEffect", player[JS.k(layer)].grid[JS.k(id)], id) end
end
gridCost = function(this, layer, id)
	do return gridRun(nil, layer, "getCost", player[JS.k(layer)].grid[JS.k(id)], id) end
end
gridEssence = function(this, layer, id)
	do return gridRun(nil, layer, "getEssence", player[JS.k(layer)].grid[JS.k(id)], id) end
end
hasMalware = function(this, layer, id)
	do return JS.m(player[JS.k(layer)].pseudoBuys, "includes", JS.m(id, "toString")) end
end

end
