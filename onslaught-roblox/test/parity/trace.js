// Parity trace (JS side). node trace.js > js.jsonl ; the Luau side is trace.luau. compare.js diffs them.
const E = require("../../../onslaught-html/engine.js");
const GAME = require("../../../onslaught-data/game.json");
let X = null; try { X = require("../../../onslaught-html/expansion.js"); } catch (e) {}
const SC = require("./scenarios.json");
const only = process.argv[2];
const Q = [[0, 0], [-36, -8], [36, -8], [0, -36], [-36, -44], [36, -44]];

function spots(G, range) {
  const out = [];
  for (let y = 24; y <= 456; y += 12) for (let x = 24; x <= 696; x += 12) {
    if (!E.canBuildAt(G, "Blue", x, y, null)) continue;
    let cover = 0; for (const m of G.mines) { const dx = m.x - x, dy = m.y - y; if (Math.sqrt(dx * dx + dy * dy) <= range) cover++; }
    out.push({ x, y, cover, i: out.length });
  }
  return out.sort((a, b) => (b.cover - a.cover) || (a.i - b.i));
}
function botTick(G, st, kinds) {
  for (const pid of G.playerOrder) {
    const p = G.players[pid];
    for (let guard = 0; guard < 50; guard++) {
      let best = null;
      for (const t of G.turrets) { if (t.owner !== pid) continue; for (const s of ["damage", "rate", "range"]) { const c = E.upCost(t, s); if (c !== null && (!best || c < best.c)) best = { t, st: s, c }; } }
      let kind = kinds[G.turrets.length % kinds.length];
      if (G.turrets.length === 0 && p.cash < G.D.turrets[kind].cost) kind = "Blue";
      const cost = G.D.turrets[kind].cost * (1 + G.turrets.length * 0.5);
      if ((!best || cost < best.c) && p.cash >= G.D.turrets[kind].cost && G.turrets.length < 24) {
        while (st.next < st.cand.length && !E.canBuildAt(G, kind, st.cand[st.next].x, st.cand[st.next].y, null)) st.next++;
        if (st.next < st.cand.length && E.build(G, pid, kind, st.cand[st.next].x, st.cand[st.next].y)) continue;
      }
      if (best && p.cash >= best.c) { E.upgrade(G, pid, best.t.id, best.st); continue; }
      break;
    }
  }
}
function act(G, a) {
  const [, op, ...r] = a;
  if (op === "build") return E.build(G, r[0], r[1], r[2], r[3]);
  if (op === "upgrade") return E.upgrade(G, r[0], r[1], r[2], r[3]);
  if (op === "waveSend") return E.waveSend(G);
  if (op === "combonly") { const c = G.turrets.find(t => t.type === "combonly"); return c && E.combonlyChoose(G, "p1", c.id, r[0]); }
  const T = i => G.turrets[i];
  const own = i => T(i) && T(i).owner;
  if (op === "tmax") return T(r[0]) && E.upgrade(G, own(r[0]), T(r[0]).id, r[1], true);
  if (op === "mode") return T(r[0]) && E.setTargetMode(G, own(r[0]), T(r[0]).id, r[1]);
  if (op === "lock") return T(r[0]) && E.toggleLock(G, own(r[0]), T(r[0]).id);
  if (op === "dir") return T(r[0]) && E.setDirectional(G, own(r[0]), T(r[0]).id, r[1], r[2]);
  if (op === "join") return T(r[0]) && T(r[1]) && E.join(G, own(r[0]), T(r[0]).id, T(r[1]).id);
  if (op === "focus") return E.focus(G, r[0], r[1]);
  if (op === "move") return T(r[0]) && E.move(G, own(r[0]), T(r[0]).id, r[1], r[2]);
  if (op === "sell") return T(r[0]) && E.sell(G, own(r[0]), T(r[0]).id);
  if (op === "leave") return E.removePlayer(G, r[0]);
  if (op === "prefs") return E.setPrefs(G, { waveSpacing: r[0], waveFollow: r[1] });
  if (op === "group") {
    r[2].forEach((k, i) => {
      const t = E.build(G, "p1", k, r[0] + Q[i][0], r[1] + Q[i][1]);
      if (!t) return;
      if (t.type !== "combonly") E.upgrade(G, "p1", t.id, "damage", true);
      if (i > 0) E.setDirectional(G, "p1", t.id, -90, 15);
    });
  }
}
function snap(G) {
  let hp = 0, xs = 0, ys = 0, sp = 0;
  for (const a of G.attackers) { hp += a.energy; xs += a.x; ys += a.y; sp += a.speed; }
  let rot = 0, val = 0;
  for (const t of G.turrets) { rot += t.rot || 0; val += t.value; }
  return { t: G.now, w: G.waveNum, k: G.kills, l: G.lives, c: G.playerOrder.map(p => G.players[p].cash), r: G.rng.s,
    na: G.attackers.length, hp, xs, ys, sp, nt: G.turrets.length, rot, val, ns: G.shots.length, nb: G.blasts.length,
    sh: G.stats.shots, co: G.stats.combos, over: G.over };
}
for (const sc of SC) {
  if (only && sc.name !== only) continue;
  const o = Object.assign({ players: ["p1"] }, sc.opts);
  if (o.challengeIndex !== undefined) { o.challenge = GAME.challenges[o.challengeIndex]; delete o.challengeIndex; }
  const G = E.newGame(GAME, o);
  if (sc.energy) G.energy = sc.energy;
  const bot = sc.bot ? { cand: spots(G, 110), next: 0 } : null;
  const script = (sc.script || []).slice();
  let fxKinds = {};
  for (let t = 0; t <= sc.ms && !G.over; ) {
    while (script.length && script[0][0] <= G.now) act(G, script.shift());
    if (bot && G.now % 1000 === 0) botTick(G, bot, sc.bot);
    E.step(G); t++;
    for (const f of G.fx) { const key = f.k === "combo" ? "combo:" + f.name : f.k; fxKinds[key] = (fxKinds[key] || 0) + 1; }
    G.fx = [];
    if (G.now % 500 === 0 || G.over) { const s = snap(G); s.sc = sc.name; s.fx = fxKinds; fxKinds = {}; console.log(JSON.stringify(s)); }
  }
}
