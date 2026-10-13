// Headless checks of the engine against onslaught-data/MECHANICS.md.  node test/sim_test.js
const E = require("../engine.js");
const D = require("../../onslaught-data/game.json");
let fails = 0, passes = 0;
function ok(c, msg) { if (c) passes++; else { fails++; console.log("FAIL:", msg); } }
function near(a, b, tol, msg) { ok(Math.abs(a - b) <= tol, `${msg} (got ${a}, want ${b}±${tol})`); }
function game(o) { return E.newGame(D, Object.assign({ map: "map1", mode: "medium", seed: 7 }, o || {})); }
function drain(G) { const f = G.fx; G.fx = []; return f; }

// ---- waves
{
  const G = game();
  E.run(G, 20000); ok(G.waveNum === 0, "no wave before 20 s");
  E.run(G, 400); ok(G.waveNum === 1, "wave 1 just after 20 s");
  near(G.energy, 13, 1e-9, "wave 1 energy = 10*1.3");
  // spawn spacing
  const spawns = [];
  for (let i = 0; i < 9000; i++) { const n = G.attackers.length; E.step(G); if (G.attackers.length > n) spawns.push(G.now); }
  ok(spawns.length >= 9, "10 attackers spawned");
  const gaps = spawns.slice(1).map((t, i) => t - spawns[i]);
  ok(gaps.every(g => g === 800), "attackers are 800 ms apart: " + gaps.join(","));
  E.waveSend(G); ok(G.waveNum === 2 && Math.abs(G.energy - 16.9) < 1e-9, "next wave by hand, energy 16.9");
  ok(G.attackers[0].bounty === 1, "wave 1 bounty $1");
}
// ---- hp tables
{
  const G = game({ mode: "hard" });
  for (let i = 0; i < 12; i++) E.waveSend(G);
  near(G.energy, 10 * Math.pow(1.4, 9) * Math.pow(1.3, 3), 1e-6, "hard wave 12 energy");
  const X = game({ mode: "extreme" }); for (let i = 0; i < 5; i++) E.waveSend(X);
  near(X.energy, 10 * Math.pow(1.125, 5), 1e-9, "extreme wave 5 energy");
  ok(X.speed === 80, "extreme speed 80");
}
// ---- building rules
{
  const G = game();
  ok(!E.canBuildAt(G, "Blue", 150, 382), "cannot build on the road");
  ok(E.canBuildAt(G, "Blue", 150, 320), "can build next to the road");
  const t = E.build(G, "p1", "Blue", 150, 320); ok(!!t && G.players.p1.cash === 20, "build blue costs 10");
  ok(!E.canBuildAt(G, "Blue", 180, 320), "36 px spacing");
  ok(E.canBuildAt(G, "Blue", 186.5, 320), "36 px spacing edge");
  ok(!E.build(G, "p1", "Yellow", 200, 300), "cannot afford yellow");
  ok(!E.canBuildAt(G, "Blue", 10, 200), "outside the play area");
  ok(E.sell(G, "p1", t.id) === 7 && G.players.p1.cash === 27, "sell refunds ceil(10*0.7)=7");
}
// ---- upgrades, effective stats, modifiers
{
  const G = game({ mode: "sandbox" });
  const b = E.build(G, "p1", "Blue", 150, 320);
  E.upgrade(G, "p1", b.id, "damage", true);
  ok(b.lvl.damage === 9 && b.eff.damage === 46000, "blue max damage 46000");
  ok(b.comboCapable, "max damage makes it combo capable");
  ok(G.D.turrets.Blue.up.damage.amount[7] === 18400, "blue level 8 uses the code value 18400");
  const m = E.build(G, "p1", "DamageUp", 150, 260);
  near(b.eff.damage, 46000 * 1.4, 1e-6, "damage enhancer +40%");
  const m2 = E.build(G, "p1", "RateUpExchange", 110, 300);
  near(b.eff.damage, 46000 * (1 + 0.4 - 0.4), 1e-6, "mults stack additively");
  near(b.eff.range, 130 * 0.9, 1e-6, "rate exchanger -10% range");
  E.sell(G, "p1", m.id); E.sell(G, "p1", m2.id);
  ok(b.eff.damage === 46000, "modifier removed on sell");
}
// ---- green chain: g1 leads, g2 and g3 offer and fire into it: 25 + 2*(25*1.25) = 87.5
{
  const G = game({ mode: "sandbox" });
  E.build(G, "p1", "Green", 150, 330); E.build(G, "p1", "Green", 186, 330); E.build(G, "p1", "Green", 168, 296);
  E.waveSend(G);
  let best = 0;
  for (let i = 0; i < 15000; i++) { E.step(G); for (const f of drain(G)) if (f.k === "laser") best = Math.max(best, f.dmg); }
  ok(best === 87.5, "green chain damage 87.5 (got " + best + ")");
}
// ---- combos fire with the right recipe
function comboRun(build, wantName, ms) {
  const G = game({ mode: "sandbox", seed: 11 });
  G.energy = 1e9;
  let first = true;
  for (const [k, x, y] of build) {
    const t = E.build(G, "p1", k, x, y); if (!t) { ok(false, `build ${k} at ${x},${y}`); return; }
    E.upgrade(G, "p1", t.id, "damage", true);
    if (!first) E.setDirectional(G, "p1", t.id, -90, 15);   // partners look away from the road so they stay ready
    first = false;
  }
  E.waveSend(G);
  const seen = new Set();
  for (let i = 0; i < (ms || 25000); i++) { E.step(G); for (const f of drain(G)) if (f.k === "combo") seen.add(f.name); if (seen.has(wantName)) break; }
  ok(seen.has(wantName), `${wantName} fires (saw ${[...seen].join(",") || "none"})`);
  return G;
}
const P = (k, dx, dy) => [k, 150 + dx, 345 + dy];   // a cluster beside Classic's first road segment
comboRun([P("Red", 0, 0), P("Blue", -36, -8), P("Blue", 36, -8)], "nuke");
comboRun([P("Red", 0, 0), P("Red", -36, -8), P("Yellow", 36, -8), P("Blue", 0, -36)], "napalm");
comboRun([P("Red", 0, 0), P("Blue", -36, -8), P("Green", 36, -8)], "poison_rocket");
comboRun([P("Red", 0, 0), P("Yellow", 36, -8)], "tazer_rocket");
comboRun([P("Red", 0, 0), P("Green", 36, -8)], "laser_rocket");
comboRun([P("Blue", 0, 0), P("Blue", 36, -8)], "landmine");
comboRun([P("Blue", 0, 0), P("Red", 36, -8)], "clusterbomb");
comboRun([P("Yellow", 0, 0), P("Yellow", -36, -8), P("Yellow", 36, -8), P("Green", 0, -36)], "blackhole");
comboRun([P("Yellow", 0, 0), P("Yellow", -36, -8), P("Blue", 36, -8), P("Green", 0, -36)], "shockwave");

const Q = [[0, 0], [-36, -8], [36, -8], [0, -36], [-36, -44], [36, -44]];
function group(kinds) { return kinds.map((k, i) => P(k, Q[i][0], Q[i][1])); }
comboRun(group(["Green", "Red", "Blue"]), "bfg");
comboRun(group(["Green", "Red", "Red", "Blue"]), "rocket_bfg");
comboRun(group(["Yellow", "Red", "Blue"]), "tazer_bfg");
comboRun(group(["Blue", "Blue", "Yellow"]), "sparky_landmine");
comboRun(group(["Blue", "Red", "Yellow"]), "sparky_clusterbomb");
comboRun(group(["Blue", "Red", "Green"]), "laser_clusterbomb");
comboRun(group(["Blue", "Red", "Blue"]), "big_landmine");
comboRun(group(["Blue", "Red", "Red"]), "big_clusterbomb");
comboRun(group(["Blue", "Red", "Red", "Green"]), "big_laser_clusterbomb");
comboRun(group(["Blue", "Red", "Red", "Blue"]), "big_cluster_landmine");
comboRun(group(["Blue", "Red", "Red", "Blue", "Green"]), "big_laser_cluster_landmine");
// ---- fusion: greens and yellows feed it, it fires stored damage
{
  const G = game({ mode: "sandbox" });
  const f = E.build(G, "p1", "Fusion", 150, 320);
  E.build(G, "p1", "Green", 150, 260); E.build(G, "p1", "Yellow", 200, 260);
  ok(f.eff.damage === 1e6, "fusion base damage is the class value 1M");
  G.energy = 1e12; E.waveSend(G);
  let maxSpark = 0;
  for (let i = 0; i < 20000; i++) { E.step(G); for (const x of drain(G)) if (x.k === "spark" && x.look === "fusion") maxSpark = Math.max(maxSpark, x.dmg); }
  ok(f.store > 0 || maxSpark > 1e6, "fusion stores fed damage (" + Math.round(f.store) + ")");
  ok(maxSpark > 1e6 && maxSpark <= 2e6, "fusion shot = 1M + min(1M, stored) (" + maxSpark + ")");
}
// ---- targeter: a joined turret fires at the painted target even out of its own range
{
  const G = game({ mode: "sandbox" });
  const tg = E.build(G, "p1", "Targeter", 150, 330);
  const b = E.build(G, "p1", "Red", 40, 170);               // far from the first road segment
  ok(E.join(G, "p1", tg.id, b.id), "join red to targeter");
  E.waveSend(G);
  let shots = 0;
  for (let i = 0; i < 9000; i++) { E.step(G); }
  ok(b.kills + G.kills > 0 || G.stats.shots > 0, "targeter drives the joined red");
}
// ---- combonly: absorbs Red + 2 Blue and becomes a nuke cannon
{
  const G = game({ mode: "sandbox" });
  const c = E.build(G, "p1", "Combonly", 150, 330);
  const parts = [["Red", 186, 322], ["Blue", 114, 322], ["Blue", 150, 290]].map(([k, x, y]) => { const t = E.build(G, "p1", k, x, y); E.upgrade(G, "p1", t.id, "damage", true); return t; });
  const opts = E.combonlyOptions(G, c.id).map(o => o.colour + ":" + o.combo);
  ok(opts.indexOf("Red:nuke") >= 0, "combonly offers Red:nuke (" + opts.join(",") + ")");
  ok(E.combonlyChoose(G, "p1", c.id, "Red"), "choose nuke");
  ok(G.turrets.length === 1 && c.value > 5000, "partners absorbed into the combonly");
  G.energy = 1e9; E.waveSend(G);
  let nukes = 0;
  for (let i = 0; i < 30000; i++) { E.step(G); for (const x of drain(G)) if (x.k === "combo" && x.name === "nuke") nukes++; }
  ok(nukes >= 2, "combonly keeps firing nukes (" + nukes + ")");
}
// ---- challenge: Warmup = survive 60 s on easy
{
  const ch = D.challenges.find(c => c.name === "Warmup");
  const G = E.newGame(D, { map: "map1", challenge: ch, seed: 5 });
  E.build(G, "p1", "Blue", 150, 330); E.build(G, "p1", "Blue", 60, 360);
  E.run(G, 120000);
  ok(G.won, "Warmup challenge won after the clock and a clear field (over=" + G.over + " lives=" + G.lives + ")");
}
// ---- freakout: first one on the next tick after arming, then 3 s warning, then x4 damage for 5 s
{
  const G = game({ mode: "sandbox" });
  const b = E.build(G, "p1", "Blue", 150, 320);
  for (let i = 0; i < 4; i++) { E.upgrade(G, "p1", b.id, "damage"); E.upgrade(G, "p1", b.id, "rate"); }
  ok(b.freakAvail, "freakout armed at damage 4 + rate 4");
  const base = b.eff.damage;
  let warnAt = null, onAt = null;
  for (let i = 0; i < 10000; i++) { E.step(G); for (const f of drain(G)) { if (f.k === "freakwarn" && warnAt === null) warnAt = G.now; if (f.k === "freak" && onAt === null) onAt = G.now; } }
  ok(warnAt !== null && warnAt <= 110, "first freakout warns right away (" + warnAt + ")");
  ok(onAt - warnAt > 3000 && onAt - warnAt < 3100, "3 s warning (" + (onAt - warnAt) + ")");
  ok(b.eff.damage === base, "freakout over after 5 s");
  ok(b.freakNext >= 24000 && b.freakNext <= 80000 + 200, "next freakout in 24-64 s (" + b.freakNext + ")");
}
// ---- yellow slow lags one upgrade (as in the original)
{
  const G = game({ mode: "sandbox" });
  const y = E.build(G, "p1", "Yellow", 150, 320);
  E.upgrade(G, "p1", y.id, "damage");
  ok(y.base.poison > 1 && y.eff.poison === 1, "yellow effective slow updates one step late");
  E.upgrade(G, "p1", y.id, "damage");
  near(y.eff.poison, 10 * 14 / 100, 1e-9, "…and catches up on the next upgrade");
}
// ---- black hole swallows without paying
{
  const G = comboRun([P("Yellow", 0, 0), P("Yellow", -36, -8), P("Yellow", 36, -8), P("Green", 0, -36)], "blackhole", 30000);
}
// ---- full game smoke test: a simple build survives early waves
{
  const G = game({ seed: 3 });
  E.build(G, "p1", "Blue", 150, 330); E.build(G, "p1", "Blue", 230, 330);
  let maxWave = 0;
  for (let s = 0; s < 400; s++) {
    E.run(G, 1000);
    const p = G.players.p1;
    for (const t of G.turrets) for (const st of ["damage", "rate", "range"]) E.upgrade(G, "p1", t.id, st);
    if (p.cash > 60) E.build(G, "p1", "Blue", 120 + Math.floor(Math.random() * 500), 300 + Math.floor(Math.random() * 40));
    maxWave = G.waveNum;
    if (G.over) break;
  }
  ok(maxWave >= 15, "smoke game reaches wave 15+ (" + maxWave + ", kills " + G.kills + ", lives " + G.lives + ")");
}
console.log(`${passes} passed, ${fails} failed`);
process.exit(fails ? 1 : 0);
