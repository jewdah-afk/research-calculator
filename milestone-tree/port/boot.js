// Same boot as TMT load() minus DOM/Vue/save.
// Display-only functions are left out of the per-tick temp refresh (TMT's activeFunctions list): boards call them
// directly when they draw. Set __KEEP_DISPLAY = true before boot to refresh them every tick like the web version.
if (typeof __KEEP_DISPLAY === "undefined" || !__KEEP_DISPLAY) {
	var __displayOnly = ["style", "tooltip", "tooltipStyle", "title", "description", "challengeDescription", "rewardDescription",
		"requirementDescription", "goalDescription", "costDescription", "buttonStyle", "nodeStyle", "respecMessage",
		"prestigeButtonText", "currencyDisplayName", "markNodes", "pseudoReq", "perkReq"]
	for (var __i = 0; __i < __displayOnly.length; __i++) activeFunctions.push(__displayOnly[__i])
}
// __RESUME (a JSON save string) loads a save the same way TMT's load() does
if (typeof __RESUME !== "undefined" && __RESUME) { player = Object.assign(getStartPlayer(), JSON.parse(__RESUME)); fixSave() }
else player = getStartPlayer()
options = getStartOptions();
player.time = Date.now();
updateLayers();
setupTemp(); updateTemp(); updateTemp();
