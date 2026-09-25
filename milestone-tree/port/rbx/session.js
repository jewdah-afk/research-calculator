// Roblox front end, game side: one player's game, run the way the web page runs it (load(), the 50 ms interval and
// the buttons) without the page. Transpiled to Luau with the game; the Luau Session module drives these functions.

// Display-only functions are left out of the per-tick temp refresh (TMT's activeFunctions list): the view builder
// calls them when it draws. Same list as boot.js uses for the headless runs.
var rbx_displayOnly = ["style", "tooltip", "tooltipStyle", "title", "description", "challengeDescription", "rewardDescription",
	"requirementDescription", "goalDescription", "costDescription", "buttonStyle", "nodeStyle", "respecMessage",
	"prestigeButtonText", "currencyDisplayName", "markNodes", "pseudoReq", "perkReq"]
for (var rbx_i = 0; rbx_i < rbx_displayOnly.length; rbx_i++) activeFunctions.push(rbx_displayOnly[rbx_i])

// load(): saveStr / optionsStr are JSON (what rbx_saveData returns), or empty for a new game
function rbx_boot(saveStr, optionsStr) {
	if (saveStr) {
		player = Object.assign(getStartPlayer(), JSON.parse(saveStr))
		fixSave()
	} else player = getStartPlayer()
	options = getStartOptions()
	if (optionsStr) {
		options = Object.assign(getStartOptions(), JSON.parse(optionsStr))
		fixData(options, getStartOptions())
	}
	options.forceOneTab = true      // the Roblox page is the NG+ "Revamped" layout: the menu, no tree
	if (options.offlineProd) {
		if (player.offTime === undefined) player.offTime = { remain: 0 }
		player.offTime.remain += (Date.now() - player.time) / 1000
	}
	player.time = Date.now()
	versionCheck()
	updateLayers()
	setupModInfo()
	setupTemp()
	updateTemp()
	updateTemp()
	updateTabFormats()
}

function rbx_updateWidth() {
	tmp.other.screenWidth = 1280
	tmp.other.screenHeight = 720
	tmp.other.splitScreen = false
	tmp.other.lastPoints = player.points
}

// the page's setInterval body; Date.now() is the server clock
function rbx_tick() {
	if (tmp.gameEnded && !player.keepGoing) return
	var now = Date.now()
	var diff = (now - player.time) / 1e3
	var trueDiff = diff
	if (player.offTime !== undefined) {
		if (player.offTime.remain > modInfo.offlineLimit * 3600) player.offTime.remain = modInfo.offlineLimit * 3600
		if (player.offTime.remain > 0) {
			var offlineDiff = Math.max(player.offTime.remain / 10, diff)
			player.offTime.remain -= offlineDiff
			diff += offlineDiff
		}
		if (!options.offlineProd || player.offTime.remain <= 0) player.offTime = undefined
	}
	if (player.devSpeed) diff *= player.devSpeed
	player.time = now
	updateTemp()
	updateOomps(diff)
	rbx_updateWidth()
	gameLoop(diff)
	fixNaNs()
	adjustPopupTime(trueDiff)
}

// a button press. The server only passes actions that are on the player's screen right now (see rbx_view).
function rbx_do(a) {
	var k = a[0], l = a[1], id = a[2]
	if (k == "opt") return rbx_option(l)
	if (tmp.gameEnded && !player.keepGoing) return
	if (k == "upg") buyUpg(l, id)
	else if (k == "buy") buyBuyable(l, id)
	else if (k == "click") clickClickable(l, id)
	else if (k == "hold") {
		var c = layers[l].clickables[id]
		if (c.onHold && run(c.canClick, c)) run(c.onHold, c)
	}
	else if (k == "chal") startChallenge(l, id)
	else if (k == "reset") doReset(l)
	else if (k == "tab") showTab(l)
	else if (k == "subtab") {
		player.subtabs[l][id] = a[3]
		updateTabFormats()
	}
	else if (k == "toggle") toggleAuto([l, id])
	else if (k == "perk") unlockUpg(l, id)
	else if (k == "malware") unlockBuy(l, id)
	else if (k == "respec") respecBuyables(l)
	else if (k == "master") run(tmp[l].clickables.masterButtonPress, tmp[l].clickables)
	else if (k == "sellOne") run(tmp[l].buyables[id].sellOne, tmp[l].buyables[id])
	else if (k == "sellAll") run(tmp[l].buyables[id].sellAll, tmp[l].buyables[id])
	else if (k == "grid") clickGrid(l, id)
	else if (k == "gridHold") {
		if (layers[l].grid.onHold && gridRun(l, "getCanClick", player[l].grid[id], id)) gridRun(l, "onHold", player[l].grid[id], id)
	}
	else if (k == "infobox") player.infoboxes[l][id] = !player.infoboxes[l][id]
	else if (k == "key") {
		var hk = hotkeys[l]
		if (hk && player[hk.layer].unlocked && tmp[hk.layer].hotkeys[hk.id].unlocked) hk.onPress()
	}
}

function rbx_option(name) {
	if (name == "offlineProd" || name == "hideChallenges" || name == "reverseMilestones") toggleOpt(name)
	else if (name == "msDisplay") adjustMSDisp()
	else if (name == "cctp") adjustCCTP()
	else if (name == "keepGoing") keepGoing()
}

// save(): null while the game holds a NaN (the web page stops saving then too)
function rbx_saveData() {
	NaNcheck(player)
	if (NaNalert) return null
	return [JSON.stringify(player), JSON.stringify(options)]
}

// popups (achievements, milestones...) raised since the given id. kind: milestone / achievement / corruption / other;
// layer: the layer it is about, or null
function rbx_popups(since) {
	var out = []
	for (var i = 0; i < activePopups.length; i++) {
		var p = activePopups[i]
		if (p.id >= since) {
			var kind = "other"
			if (p.rbxKind) kind = p.rbxKind
			else if (p.type == "achievement-popup") kind = "achievement"
			else if (p.title == "Corruption Info") kind = "corruption"
			var layer = null
			if (p.layer) layer = "" + p.layer
			else if (kind == "achievement") layer = "ach"
			else if (kind == "corruption") layer = "cp"
			out.push({
				id: p.id, title: "" + p.title, message: "" + p.message, type: "" + p.type, color: p.color ? "" + p.color : "", bColor: p.bColor ? "" + p.bColor : "",
				kind: kind, layer: layer,
			})
		}
	}
	return out
}

// updateMilestones from utils.js, except that the popup text is worked out when the popup fires:
// requirementDescription is one of the display-only functions tmp no longer refreshes every tick
function updateMilestones(layer) {
	if (tmp[layer].deactivated) return
	for (id in layers[layer].milestones) {
		if (!(hasMilestone(layer, id)) && layers[layer].milestones[id].done()) {
			player[layer].milestones.push(id)
			if (layers[layer].milestones[id].onComplete) layers[layer].milestones[id].onComplete()
			if (tmp[layer].milestonePopups || tmp[layer].milestonePopups === undefined) {
				doPopup("milestone", rbx_v(tmp[layer].milestones[id], layers[layer].milestones[id], "requirementDescription"), "Milestone Gotten!", 3, tmp[layer].color)
				activePopups[activePopups.length - 1].layer = layer
				activePopups[activePopups.length - 1].rbxKind = "milestone"
			}
			player[layer].lastMilestone = id
		}
	}
}

// sp's Spark Milestone burn bar: the game draws it as an HTML div with a gradient; the view builds a bar node from
// ["rbx-burn", id] instead (rbx_burnBar in view.js), under the same two conditions. rbx_burnHtml is the game's own.
var rbx_burnHtml = handleBurnDisplay
handleBurnDisplay = function (checkId) {
	var d = rbx_burnHtml(checkId)
	return d ? ["rbx-burn", checkId] : d
}
