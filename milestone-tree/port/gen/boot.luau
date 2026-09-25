--!nocheck
-- transpiled from boot.js by port/build.js: do not edit
return function()
-- transpiled from boot.js
if ((JS.typeof(u__KEEP_DISPLAY) == "undefined") or (not JS.t(u__KEEP_DISPLAY))) then
	u__displayOnly = JS.A(18, "style", "tooltip", "tooltipStyle", "title", "description", "challengeDescription", "rewardDescription", "requirementDescription", "goalDescription", "costDescription", "buttonStyle", "nodeStyle", "respecMessage", "prestigeButtonText", "currencyDisplayName", "markNodes", "pseudoReq", "perkReq")
	for u__i = 0, JS.cap(0, (JS.len(u__displayOnly)) - 1, 1) do
		JS.m(activeFunctions, "push", u__displayOnly[JS.k(u__i)])
	end
end
if ((not (JS.typeof(u__RESUME) == "undefined")) and JS.t(u__RESUME)) then
	player = Object.assign(getStartPlayer(nil), JSON.parse(u__RESUME))
	fixSave(nil)
else
	player = getStartPlayer(nil)
end
options = getStartOptions(nil)
JS.setk(player, "time", Date.now())
updateLayers(nil)
setupTemp(nil)
updateTemp(nil)
updateTemp(nil)

end
