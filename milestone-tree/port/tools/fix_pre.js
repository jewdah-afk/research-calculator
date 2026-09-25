// Scripted states for the capture fixtures (tools/capture.luau). Transpiled by tools/fix_gen.js and run inside a
// Session's game, so the fixtures carry the same data as the design mocks (plan/final/tools s13pre.js, mv2.js).

// n ticks of sec seconds each
function fix_T(sec, n) {
	for (var k = 0; k < n; k++) {
		player.time -= sec * 1000
		rbx_tick()
	}
}

// S13: fuzz save 13, then a P reset, an SP reset, 7 P upgrade buys, malware m15 and a spark state
function fix_s13() {
	rbx_do(["tab", "none"])
	fix_T(0.05, 2)
	rbx_do(["reset", "p"])
	fix_T(0.05, 1)
	rbx_do(["reset", "sp"])
	fix_T(0.05, 3)
	rbx_do(["tab", "p"])
	var ups = [11, 13, 14, 22, 23, 42, 44]
	for (var i = 0; i < ups.length; i++) rbx_do(["upg", "p", ups[i]])
	if (player.m.pseudoBuys.indexOf("15") < 0) player.m.pseudoBuys.push("15")
	player.sp.sparkMilestones = new Decimal(3)
	player.sp.showSparkAmt = 3
	player.sp.chosenSparkMil = 0
	player.sp.sparkPage = 1
	player.sp.timer = { 0: 0, 1: 151.2, 2: 240 }
	updateTemp()
	rbx_do(["tab", "none"])
}

// inside the Prestige Multiverse with the ex zone, cp buyable 22 and a filled hard-drive grid (one drive active)
function fix_mv() {
	player.keepGoing = true // a finished game plays on (Keep Going)
	player.mp.unlocked = true
	rbx_do(["chal", "mp", 21])
	player.time -= 50
	rbx_tick()
	// 12 Prestige Milestones: pep, cp and cm show
	player.pm.unlocked = true
	if (player.pm.best.lt(12)) {
		player.pm.points = new Decimal(12)
		player.pm.best = new Decimal(12)
	}
	if (player.m.pseudoBuys.indexOf("9") < 0) player.m.pseudoBuys.push("9")
	player.cp.buyables[22] = new Decimal(0)
	player.ex.points = new Decimal(3)
	player.ex.unlocked = true
	player.ex.dotUnl = 1
	player.ex.buyables[11] = new Decimal(6)
	player.ex.buyables[12] = new Decimal(4)
	// below 3 Corrupted Milestones the game does not fix low drives by itself, so the grid below stays
	if (player.cm.best.gte(3)) {
		player.cm.points = new Decimal(2)
		player.cm.best = new Decimal(2)
	}
	updateTemp()
	fix_cell(101, 3.21, "div")
	fix_cell(103, 2.62, "pm")
	fix_cell(202, 6.31, "div")
	fix_cell(204, 1.83, "div")
	fix_cell(301, 4.46, "pm")
	fix_cell(305, 2.54, "div")
	fix_cell(403, 3.08, "div")
	player.cp.points = new Decimal(23)
	player.cp.totalCorrupt = 16
	rbx_do(["tab", "cp"])
	// (no drive is left running: at this save's income the game fixes a running drive within a tick)
	rbx_do(["tab", "none"])
}
function fix_cell(id, lv, type) {
	var g = player.cp.grid
	g[id] = { level: lv, active: false, fixed: false, type: type, cautPower: (g[id] && g[id].cautPower) || 0 }
}

// trapped in the Normal Universe: inside the Multiverse with a Prestige Milestone challenge running
function fix_trapped() {
	fix_mv()
	player.pm.activeChallenge = 12
	fix_T(0.05, 2)
}

// the layers shown right now, in the map's order
function fix_shown() {
	var out = []
	for (var i = 0; i < rbx_MAP.length; i++) if (tmp[rbx_MAP[i]].layerShown == true) out.push(rbx_MAP[i])
	return out.join(",")
}
