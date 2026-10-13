// Balance harness: a simple bot plays one strategy at a time; compare how far each tower carries a game.
// node test/balance.js [seeds]
const E = require("../engine.js");
const X = require("../expansion.js");
const GAME = require("../../onslaught-data/game.json");
const seeds = +(process.argv[2] || 3);
const L = { level: 99, research: {}, passes: {} };

function spots(G, range) {             // build spots ranked by how much road they cover
  const out = [];
  for (let y = 24; y <= 456; y += 12) for (let x = 24; x <= 696; x += 12) {
    if (!E.canBuildAt(G, "Blue", x, y, null)) continue;
    let cover = 0; for (const m of G.mines) if (Math.hypot(m.x - x, m.y - y) <= range) cover++;
    out.push({ x, y, cover });
  }
  return out.sort((a, b) => b.cover - a.cover);
}
function play(kinds, seed, mode, maxMin) {
  const D = X.data(GAME, L);
  const G = E.newGame(D, X.gameOpts({ map: "map1", mode: mode || "medium", seed, players: ["p1"] }, { p1: L }));
  const cand = spots(G, 110);
  let next = 0;
  for (let s = 0; s < (maxMin || 60) * 60 && !G.over; s++) {
    E.run(G, 1000);
    const p = G.players.p1;
    // keep upgrading the cheapest upgrade; build another when that's cheaper
    for (let guard = 0; guard < 50; guard++) {
      let best = null;
      for (const t of G.turrets) for (const st of ["damage", "rate", "range"]) {
        const c = E.upCost(t, st); if (c !== null && (!best || c < best.c)) best = { t, st, c };
      }
      let kind = kinds[G.turrets.length % kinds.length];
      if (G.turrets.length === 0 && p.cash < D.turrets[kind].cost) kind = "Blue";      // everyone opens with a Blue ($30 start)
      const cost = D.turrets[kind].cost * (1 + G.turrets.length * 0.5);
      if ((!best || cost < best.c) && p.cash >= D.turrets[kind].cost && G.turrets.length < 24) {
        while (next < cand.length && !E.canBuildAt(G, kind, cand[next].x, cand[next].y, null)) next++;
        if (next < cand.length && E.build(G, "p1", kind, cand[next].x, cand[next].y)) continue;
      }
      if (best && p.cash >= best.c) { E.upgrade(G, "p1", best.t.id, best.st); continue; }
      break;
    }
  }
  return { wave: G.waveNum, kills: G.kills, combos: G.stats.combos, spent: G.stats.spent };
}
const plans = [
  ["Blue"], ["Green"], ["Red"], ["Yellow"], ["Orange"], ["Violet"],
  ["Blue", "Cyan"], ["Red", "Blue", "Blue"], ["Red", "Vault", "Blue"], ["Orange", "Red", "Red"], ["Violet", "Green"], ["Blue", "Red", "Green", "Yellow"],
];
console.log("plan".padEnd(28), "wave(avg)", "min", "max", "combos");
for (const plan of plans) {
  const res = [];
  for (let s = 1; s <= seeds; s++) res.push(play(plan, s * 7919));
  const w = res.map(r => r.wave);
  console.log(plan.join("+").padEnd(28), String((w.reduce((a, b) => a + b, 0) / w.length).toFixed(1)).padStart(9), String(Math.min(...w)).padStart(3), String(Math.max(...w)).padStart(3), String(Math.round(res.reduce((a, r) => a + r.combos, 0) / res.length)).padStart(6));
}
