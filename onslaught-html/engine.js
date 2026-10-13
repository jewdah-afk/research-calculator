/*
  Onslaught 2 engine: a 1:1 simulation of Onslaught 2.2 (build 2350-gaby).
  Spec: onslaught-data/MECHANICS.md. The Luau port (onslaught-roblox/src/shared/Onslaught/Engine.luau)
  mirrors this file function for function, so both builds play the same game.

  No DOM in here. A renderer reads G and drains G.fx (visual events).
  Time is integer milliseconds of game time; step() advances 1 ms.
*/
(function (root) {
"use strict";

// ================================================================ RNG (xorshift32; identical in Luau)
function rngNew(seed) { return { s: (seed >>> 0) || 0x9e3779b9 }; }
function rnd(G) {
  let x = G.rng.s;
  x = (x ^ (x << 13)) >>> 0;
  x = (x ^ (x >>> 17)) >>> 0;
  x = (x ^ (x << 5)) >>> 0;
  G.rng.s = x;
  return x / 4294967296;
}

// ================================================================ math, as the original does it
const DEG = 57.296;                                   // OnslaughtObject.trigDegreesTo
function degTo(a, b) { return Math.atan2(b.y - a.y, b.x - a.x) * DEG; }
function dist(a, b) { const dx = b.x - a.x, dy = b.y - a.y; return Math.sqrt(dx * dx + dy * dy); }
function dist2(a, b) { const dx = b.x - a.x, dy = b.y - a.y; return dx * dx + dy * dy; }
function wrap180(r) { r = r % 360; if (r > 180) r -= 360; else if (r <= -180) r += 360; return r; }   // MovieClip._rotation
// MathCache: the angle is floored to 0.01 rad; inside the precomputed table sin/cos are exact, outside floored to 0.01
function qsin(q) { return (q >= -3.14 && q <= 3.14) ? Math.sin(q) : Math.floor(Math.sin(q) * 100) / 100; }
function qcos(q) { return (q >= -3.14 && q <= 3.14) ? Math.cos(q) : Math.floor(Math.cos(q) * 100) / 100; }
function fwd(deg, hyp) {
  const q = Math.floor(deg * 0.0174498255 * 100) / 100;
  return { x: qcos(q) * hyp, y: qsin(q) * hyp };
}
function modStat(added, mult, v) { return Math.max(0, (v + added) * Math.max(mult, 0.2)); }

// ================================================================ constants
const TICK = { turret: 70, fusion: 64, combonlyIdle: 1000, manager: 200, spawner: 200, shell: 32, tween: 32,
  frame: 32, mine: 150, hole: 200, walker: 32, napalm: 75 };
const MODES = ["near", "far", "weak", "strong", "slow", "fast", "old", "young"];
const MODE_TITLES = { near: "Nearest", far: "Furthest", weak: "Weakest", strong: "Strongest", slow: "Slowest", fast: "Fastest", old: "Oldest", young: "Youngest" };
const MUZZLE = { Blue: 14, Green: 14, Red: 0, Yellow: 0, Sniper: 20, Fusion: 10, Railgun: 12, Targeter: 10, Combonly: 0 };
const COLOURS = ["Red", "Green", "Blue", "Yellow"];
const PLAY = { x0: 18, x1: 702, y0: 18, y1: 462 };   // PlayArea
const BUILD_SPACING = 36, BUILD_PROBE = 19, ROAD_HALF = 15.5;
const BLAST_SHAPES = { BlastSmall: "small", BlastMedium: "medium", BlastLarge: "large", BlastHuge: "huge", BlastPoison: "poison", BlastBFG: "bfg" };

// ================================================================ setup
function newGame(D, opts) {
  opts = opts || {};
  const mapKey = opts.map || "map1";
  const map = D.maps[mapKey];
  const mode = opts.mode || "medium";
  const ch = opts.challenge || null;
  const diff = ch ? ch.difficulty : (mode === "sandbox" || mode === "sandbox2" ? "easy" : mode);
  const S = D.settings;
  const road = map.road.map(p => ({ x: p.x, y: p.y }));
  const mines = [];
  for (let i = 1; i < road.length; i++) {               // RoadManager.roadBuild: a mine point every 4 px
    const a = road[i - 1], b = road[i], n = Math.floor(dist(a, b) / 4);
    for (let s = 1; s <= n; s++) mines.push({ x: Math.round(a.x + s / n * (b.x - a.x)), y: Math.round(a.y + s / n * (b.y - a.y)) });
  }
  const hp = D.hpRate[diff], hpRate = {};
  for (let i = 0; i < hp.wave.length; i++) hpRate[hp.wave[i]] = hp.rate[i];
  const G = {
    D, rng: rngNew(opts.seed || 1), now: 0, mode, diff, mapKey, map, road, mines, challenge: ch,
    lives: opts.lives || S.lives, kills: 0, over: false, won: false, lost: false,
    waveNum: 0, energy: S.attackerEnergy, upRate: 1.125, value: 0, hpRate,
    speed: D.speed[diff], waveSpacing: opts.waveSpacing || S.waveSpacing, waveFollow: !!opts.waveFollow,
    waveLast: 0, mgrNext: TICK.manager, waves: [], noMoreWaves: false,
    waveSizeList: null, waveSizeCur: 0, speedList: null, speedCur: 0,
    waveLimit: null, killTarget: null, timeLimit: null, turretLimit: null, limitHit: false, winNext: null,
    attackers: [], turrets: [], shots: [], blasts: [], fx: [],
    players: {}, playerOrder: [], nextId: 1, unlocked: {}, stats: { shots: 0, combos: 0, spent: 0 },
    mods: opts.mods || null,   // expansion hooks (Expansion.js); null = pure 1:1
  };
  if (ch) {
    if (ch.objective) { const p = ch.objective.split(","); if (p[0] === "w") G.waveLimit = +p[1]; else G.killTarget = +p[1]; }
    if (ch.timelimit) G.timeLimit = ch.timelimit * 1000;
    if (ch.turretlimit) G.turretLimit = ch.turretlimit;
    const ws = String(ch.wavesize).split(",").map(Number);
    if (ws.length > 1 || ws[0] !== 10) G.waveSizeList = ws;
    G.speedList = String(ch.wavespeed).split(",").map(Number);
  }
  const startCash = ch ? ch.cash : (D.startingCash[mode] !== undefined ? D.startingCash[mode] : 30);
  const pids = opts.players && opts.players.length ? opts.players : ["p1"];
  for (const pid of pids) addPlayer(G, pid, startCash + ((opts.bonusCash && opts.bonusCash[pid]) || 0));
  for (const k of D.buildOrder) G.unlocked[k] = !D.turrets[k].unlock;
  if (mode === "sandbox" || mode === "sandbox2") for (const k of D.buildOrder) G.unlocked[k] = true;
  if (opts.unlockAll) for (const k of D.buildOrder) G.unlocked[k] = true;
  if (G.mods && G.mods.init) G.mods.init(G);
  return G;
}
function addPlayer(G, pid, cash) {
  if (G.players[pid]) return G.players[pid];
  G.players[pid] = { id: pid, cash, kills: 0, spent: 0 };
  G.playerOrder.push(pid);
  return G.players[pid];
}
function removePlayer(G, pid) {
  if (!G.players[pid] || G.playerOrder.length <= 1) return;
  const heir = G.playerOrder.find(p => p !== pid);
  for (const t of G.turrets) if (t.owner === pid) t.owner = heir;      // turrets stay on the map
  G.players[heir].cash += G.players[pid].cash;
  delete G.players[pid];
  G.playerOrder = G.playerOrder.filter(p => p !== pid);
}
// one player gets the full bounty (the original); a party splits it evenly
function cashWin(G, amount) {
  if (G.mods && G.mods.bounty) amount = G.mods.bounty(G, amount);
  const n = G.playerOrder.length;
  for (const pid of G.playerOrder) G.players[pid].cash += amount / n;
}
function cashSpend(G, pid, amount) {
  const p = G.players[pid];
  if (!p || p.cash < amount) return false;
  p.cash -= amount; p.spent += amount; G.stats.spent += amount;
  return true;
}
function fx(G, e) { e.t = G.now; G.fx.push(e); }

// ================================================================ waves (AttackerManager / WaveManager)
function waveSend(G) {
  if (G.over || G.noMoreWaves || G.limitHit) return false;
  if (G.waveLimit !== null && G.waveNum >= G.waveLimit) { limitReached(G, "wave"); return false; }
  G.waveNum += 1;                                         // _waveNext
  if (G.hpRate[G.waveNum] !== undefined) G.upRate = G.hpRate[G.waveNum];
  G.value = G.waveNum;
  G.energy *= G.upRate;
  G.waveLast = G.now;
  let size = G.D.settings.waveSize;
  if (G.waveSizeList) { size = G.waveSizeList[G.waveSizeCur]; G.waveSizeCur = (G.waveSizeCur + 1) % G.waveSizeList.length; }
  const bump = 10 / size;
  let speed = G.speed;
  if (G.speedList) { speed = G.speedList[G.speedCur]; G.speedCur = (G.speedCur + 1) % G.speedList.length; }
  let energy = G.energy * bump;
  if (G.mods && G.mods.waveEnergy) energy = G.mods.waveEnergy(G, energy);
  G.waves.push({ num: G.waveNum, size, sent: 0, last: 0, next: G.now + TICK.spawner,
    energy, value: Math.round(G.value * bump), speed, scale: bump });
  fx(G, { k: "wave", n: G.waveNum });
  if (G.mods && G.mods.waveSent) G.mods.waveSent(G);
  return true;
}
function updateManager(G) {
  if (G.timeLimit !== null && G.now >= G.timeLimit && !G.limitHit) { limitReached(G, "time"); if (G.over) return; }
  if (G.noMoreWaves) return;
  if (G.now - G.waveLast > G.waveSpacing) waveSend(G);
  if (G.attackers.length === 0 && G.waves.length === 0 && G.waveFollow) waveSend(G);
}
function updateSpawner(G, w) {
  if (G.now - w.last > G.D.settings.attackerSpacing) {
    w.last = G.now;
    spawnAttacker(G, w);
    w.sent++;
  }
}
function limitReached(G, why) {
  G.noMoreWaves = true; G.limitHit = true;
  if (why === "time") {
    let ok = true;
    if (G.killTarget !== null && G.kills < G.killTarget) ok = false;
    if (G.waveLimit !== null && G.waveNum < G.waveLimit) ok = false;
    if (!ok) { gameOver(G, "time"); return; }
  }
  G.winNext = G.now + 1000;
  fx(G, { k: "limit", why });
}
function winCheck(G) {
  let ok = !(G.killTarget !== null && G.kills < G.killTarget);
  if (G.attackers.length > 0 || G.waves.length > 0) ok = false;
  if (ok) { G.over = true; G.won = true; fx(G, { k: "win" }); } else G.winNext = G.now + 1000;
}
function gameOver(G, why) {
  if (G.over) return;
  G.over = true; G.lost = true;
  fx(G, { k: "gameover", why });
}

// ================================================================ attackers (AttackerEngine)
function spawnAttacker(G, w) {
  const p = G.road[0], j = 19;
  const a = { id: G.nextId++, type: (w.num - 1) % 9, wave: w.num, x: 0, y: 0, wp: 1,
    energy: w.energy, start: w.energy, bounty: w.value, speed: w.speed, speedInit: w.speed, scale: w.scale,
    born: G.now, tw: null, rep: null, dead: false, holed: null, rot: 0 };
  a.x = p.x + Math.round(rnd(G) * j - j / 2);
  a.y = p.y + Math.round(rnd(G) * j - j / 2);
  G.attackers.push(a);
  attackerAdvance(G, a);
  return a;
}
function attackerAdvance(G, a) {                          // AttackerEngine.update
  a.wp += 1;
  if (a.wp > G.road.length) { baseHit(G, a); return; }
  attackerMove(G, a);
}
function attackerMove(G, a) {                             // AttackerEngine.updateMove (a fresh 32 ms tween)
  const wp = G.road[a.wp - 1];
  const dur = dist(a, wp) / a.speed * 1000;
  const j = 19;
  const tx = wp.x + Math.round(rnd(G) * j - j / 2), ty = wp.y + Math.round(rnd(G) * j - j / 2);
  a.rot = degTo(a, wp);
  a.tw = { sx: a.x, sy: a.y, tx, ty, t0: G.now, dur, next: G.now + TICK.tween };
  if (a.speed < a.speedInit && !a.rep) a.rep = { t0: G.now, next: G.now + TICK.tween };
}
function updateAttacker(G, a) {
  if (a.holed) {
    const h = a.holed;
    if (G.now >= h.next) {
      h.next += TICK.tween;
      const r = h.dur > 0 ? (G.now - h.t0) / h.dur : 1;
      if (r >= 1) { a.x = h.tx; a.y = h.ty; a.dead = true; fx(G, { k: "holed", x: a.x, y: a.y }); return; }
      a.x = h.sx + (h.tx - h.sx) * r; a.y = h.sy + (h.ty - h.sy) * r;
    }
    return;
  }
  if (a.rep && G.now >= a.rep.next) {                      // replenish: a 1000 ms pausable tween
    a.rep.next += TICK.tween;
    if (G.now - a.rep.t0 >= 1000) {
      a.rep = null;
      a.speed += 2; if (a.speed >= a.speedInit) a.speed = a.speedInit;
      attackerMove(G, a);
    }
  }
  const t = a.tw;
  if (t && G.now >= t.next) {
    t.next += TICK.tween;
    const r = t.dur > 0 ? (G.now - t.t0) / t.dur : 1;
    if (r >= 1) { a.x = t.tx; a.y = t.ty; a.tw = null; attackerAdvance(G, a); }
    else { a.x = t.sx + (t.tx - t.sx) * r; a.y = t.sy + (t.ty - t.sy) * r; }
  }
}
function baseHit(G, a) {
  a.dead = true;
  G.lives -= 1;
  fx(G, { k: "life", lives: G.lives });
  if (G.lives <= 0) gameOver(G, "lives");
}
// attackerHit: turrets can be "hit" too; only the Fusion Cannon does anything with it
function hit(G, a, dmg, src) {
  if (!a || a.dead) return;
  if (a.isTurret) { if (a.kind === "Fusion") a.store += dmg * 1.15; return; }
  if (a.holed) return;
  a.energy -= dmg;
  if (a.energy <= 0) {
    a.dead = true;
    if (src && src.isTurret) src.kills++;
    G.kills++;
    cashWin(G, a.bounty);
    fx(G, { k: "kill", x: a.x, y: a.y, b: a.bounty });
    checkUnlocks(G);
    if (G.killTarget !== null && G.kills >= G.killTarget && !G.limitHit) limitReached(G, "kills");
  }
}
function poison(G, a, p, minus) {                         // attackerPoison
  if (!a || a.dead) return;
  if (a.isTurret) { if (a.kind === "Fusion") a.storeP += p * 1.15; return; }
  if (a.holed) return;
  if (minus) a.speed -= p; else a.speed /= p;
  a.speed = Math.max(a.speed, 5);
  attackerMove(G, a);
}
function checkUnlocks(G) {
  for (const k of G.D.buildOrder) {
    const u = G.D.turrets[k].unlock;
    if (u && !G.unlocked[k] && G.kills === u) { G.unlocked[k] = true; fx(G, { k: "unlock", kind: k }); }
  }
}
function alive(o) { return !!o && !o.dead; }

// ================================================================ targeting (OnslaughtObject)
function inBox(src, a, r) { return a.x >= src.x - r && a.x <= src.x + r && a.y >= src.y - r && a.y <= src.y + r; }
function dirOk(t, a) {
  if (!t.dir) return true;
  const d = (t.dir.deg + 360 - (((degTo(t, a) + 720) % 360) + 360)) % 360;
  return Math.abs(d) <= t.dir.spread;
}
function inRange(G, src, a, range) {                      // targetInRange
  if (!alive(a)) return false;
  if (!inBox(src, a, range)) return false;
  if (dist(src, a) > range) return false;
  return dirOk(src, a);
}
function acquire(G, src, range, mode) {                   // targetAcquire
  if (!MODE_TITLES[mode]) mode = "near";
  const lowest = mode === "weak" || mode === "near" || mode === "slow" || mode === "young";
  let best = null, lo = 1e38, hi = 0;
  const r2 = range * range;
  for (const a of G.attackers) {
    if (a.dead || !inBox(src, a, range) || !dirOk(src, a)) continue;
    const d2 = dist2(src, a);
    if (!(d2 < r2)) continue;
    let v;
    if (mode === "weak" || mode === "strong") v = a.energy;
    else if (mode === "slow" || mode === "fast") v = a.speed;
    else if (mode === "near" || mode === "far") v = d2;
    else v = G.now - a.born;
    if (lowest) { if (v < lo) { lo = v; best = a; } } else if (v > hi) { hi = v; best = a; }
  }
  return best;
}
function availOrAcquire(G, cur, src, range, mode) {
  if (inRange(G, src, cur, range)) return cur;
  return acquire(G, src, range, mode);
}
function inBoxList(G, src, r) {
  const out = [];
  for (const a of G.attackers) if (!a.dead && inBox(src, a, r)) out.push(a);
  return out;
}
function arrayPick(G, list, qty) {                        // OnslaughtObject.arrayPick
  const n = list.length;
  if (n === qty) return list.slice();
  if (qty === 1) return [list[Math.floor(rnd(G) * n)]];
  if (qty === 2) {
    let i = 0, j = 0;
    while (i === j) { i = Math.floor(rnd(G) * n); j = Math.floor(rnd(G) * n); }
    return [list[i], list[j]];
  }
  if (n <= 2) return list.slice();
  const l = list.slice();
  for (let i = n - 1; i > 0; i--) { const k = Math.floor(rnd(G) * (i + 1)); const t = l[i]; l[i] = l[k]; l[k] = t; }
  return l.slice(0, qty);
}

// ================================================================ turrets
function def(G, kind) { return G.D.turrets[kind]; }
function makeTurret(G, kind, x, y, owner) {
  const d = def(G, kind);
  const t = {
    id: G.nextId++, kind, owner, x, y, isTurret: true, active: true, dead: false,
    type: d.type, modifiable: d.modifiable !== false, comboNever: !!d.comboNever,
    lvl: { damage: 0, range: 0, rate: 0 },
    base: { damage: d.damage, range: d.range, rate: d.rate, poison: d.poison || 0 },
    up: d.up, value: d.cost, kills: 0,
    mod: { damage_added: 0, range_added: 0, rate_added: 0, poison_added: 0, damage_mult: 1, range_mult: 1, rate_mult: 1, poison_mult: 1 },
    freakGain: { damage: 0, range: 0, rate: 0 },
    eff: { damage: 1, range: 1, rate: 1, poison: 0, msec: 0 },
    rot: 0, rotSpeed: d.rotate, mustFace: d.mustFace !== false,
    fired: 0, timeLast: G.now, next: G.now + (kind === "Fusion" ? TICK.fusion : kind === "Combonly" ? TICK.combonlyIdle : TICK.turret),
    target: null, bearTo: null, bearIgnore: false, modeNum: 0, targetMode: "near", reacquire: false, dir: null,
    comboCapable: false, comboNext: 0, comboRecharge: 0,
    freakCapable: !!d.freak, freakAvail: false, freakNext: null, freak: null,
  };
  if (kind === "Yellow" || kind === "Targeter") { t.targetMode = "fast"; t.modeNum = 5; }
  if (kind === "Targeter") t.reacquire = true;
  if (kind === "Sniper") t.freakAvail = true;            // TurretSniper declares freak_available = true (no stat effect)
  if (kind === "Green") t.offered = false;
  if (kind === "Yellow") { t.charge = 0; t.chargeMax = 100; t.chargeRate = 10; }
  if (kind === "Red") { t.holdingPattern = false; t.holding = []; }
  if (kind === "Fusion") { t.store = 0; t.storeP = 0; t.fired = G.now; t.feedList = null; }
  if (kind === "Targeter") t.joins = [];
  if (kind === "Combonly") { t.combo = null; t.comboCapable = true; t.comboNext = G.now; t.fired = G.now; t.armedAt = null; t.active = true; }
  if (d.type === "modifier") t.modify = d.modify;
  modifyUpdate(G, t);
  if (G.mods && G.mods.turretCreated) G.mods.turretCreated(G, t);
  return t;
}
function upMax(t, s) { return t.up[s] ? t.up[s].cost.length : 0; }
function upCost(t, s) { return t.lvl[s] < upMax(t, s) ? t.up[s].cost[t.lvl[s]] : null; }
function upPct(t, s) { const m = upMax(t, s); return m ? Math.floor(t.lvl[s] / m * 100) : 0; }
function upAmountMax(t, s) { const m = upMax(t, s); return m ? t.up[s].amount[m - 1] : t.base[s]; }
function modifyUpdate(G, t) {
  const m = t.mod, f = t.freakGain;
  t.eff.damage = modStat(m.damage_added, m.damage_mult + f.damage, t.base.damage);
  t.eff.range = modStat(m.range_added, m.range_mult + f.range, t.base.range);
  t.eff.rate = modStat(m.rate_added, m.rate_mult + f.rate, t.base.rate);
  t.eff.poison = modStat(m.poison_added, m.poison_mult, t.base.poison);
  if (G.mods && G.mods.effective) G.mods.effective(G, t);
  t.eff.msec = t.eff.rate > 0 ? 1000 / (t.eff.rate / 60) : Infinity;
}
// modifier turrets: every modifiable turret within a modifier's range gets its bonus (sums stack)
function recalcMods(G) {
  for (const t of G.turrets) {
    if (!t.modifiable) continue;
    const m = { damage_added: 0, range_added: 0, rate_added: 0, poison_added: 0, damage_mult: 1, range_mult: 1, rate_mult: 1, poison_mult: 1 };
    for (const s of G.turrets) {
      if (s.type !== "modifier" || s === t || !s.active) continue;
      if (dist(s, t) > s.base.range) continue;
      m.damage_added += s.modify.damage; m.range_added += s.modify.range; m.rate_added += s.modify.rate;
      m.damage_mult += s.modify.damage_mult; m.range_mult += s.modify.range_mult; m.rate_mult += s.modify.rate_mult;
    }
    if (G.mods && G.mods.auras) G.mods.auras(G, t, m);
    const o = t.mod;
    if (o.damage_added !== m.damage_added || o.range_added !== m.range_added || o.rate_added !== m.rate_added ||
        o.damage_mult !== m.damage_mult || o.range_mult !== m.range_mult || o.rate_mult !== m.rate_mult ||
        o.poison_added !== m.poison_added || o.poison_mult !== m.poison_mult) {
      t.mod = m;
      modifyUpdate(G, t);
    }
  }
}
function canBuildAt(G, kind, x, y, ignore) {
  if (x < PLAY.x0 || x > PLAY.x1 || y < PLAY.y0 || y > PLAY.y1) return false;
  if (G.turretLimit !== null && G.turrets.length >= G.turretLimit) return false;
  for (const t of G.turrets) if (t !== ignore && dist(t, { x, y }) < BUILD_SPACING) return false;
  const r = BUILD_PROBE, s = Math.sin(45 * 0.017453117987018096) * r, c = Math.cos(45 * 0.017453117987018096) * r;
  const probes = [[0, r], [0, -r], [r, 0], [-r, 0], [s, c], [s, -c], [-s, c], [-s, -c]];
  for (const [px, py] of probes) if (onRoad(G, x + px, y + py)) return false;
  return true;
}
function onRoad(G, x, y) {
  const r = G.road;
  for (let i = 1; i < r.length; i++) {
    const a = r[i - 1], b = r[i], dx = b.x - a.x, dy = b.y - a.y, l2 = dx * dx + dy * dy;
    let k = l2 ? ((x - a.x) * dx + (y - a.y) * dy) / l2 : 0;
    k = Math.max(0, Math.min(1, k));
    const ex = x - (a.x + k * dx), ey = y - (a.y + k * dy);
    if (ex * ex + ey * ey <= ROAD_HALF * ROAD_HALF) return true;
  }
  return false;
}
function turretCost(G, pid, kind) {
  const c = def(G, kind).cost;
  return G.mods && G.mods.cost ? G.mods.cost(G, pid, kind, c) : c;
}

// ---------------------------------------------------------------- aiming and firing (Turret.as)
function bearTowards(G, t, target, dt) {                  // turretBearTowards
  const want = degTo(t, target);
  const step = dt / 1000 * t.rotSpeed;
  const diff = want + 360 - (t.rot + 360);
  if (Math.abs(diff) < 1) { t.rot = wrap180(want); if (t.bearIgnore) t.bearTo = null; return true; }
  if (Math.abs(diff) < Math.abs(step)) { t.rot = wrap180(want); if (t.bearIgnore) t.bearTo = null; return true; }
  const a = (diff + 360) % 360, b = (360 - diff) % 360;
  t.rot = wrap180(b < a ? t.rot - step : t.rot + step);
  return false;
}
function canFire(G, t) { return !(G.now - t.fired <= t.eff.msec); }   // turretCanFire
function muzzle(t) { const m = MUZZLE[t.kind] || 0; const f = fwd(t.rot, m); return { x: t.x + f.x, y: t.y + f.y }; }
function turretFire(G, t, target, dmg, poisonOverride) {
  t.fired = G.now;
  G.stats.shots++;
  const m = muzzle(t);
  const p = poisonOverride !== undefined ? poisonOverride : t.eff.poison;
  let shot = null;
  switch (t.kind) {
    case "Blue":
      shot = addShot(G, { k: "shell", x: m.x, y: m.y, target, dmg, speed: 900, src: t, tier: t.lvl.damage }); break;
    case "Red": {
      const hc = t.holdingRound ? true : (t.holdingPattern ? true : false);
      shot = newRocket(G, m.x, m.y, t.rot, target, dmg, t, { holdingCapable: hc, holdingInitially: !!t.holdingRound, tier: t.lvl.damage });
      break;
    }
    case "Green": laserNow(G, m, target, dmg, t); break;
    case "Yellow": case "Fusion": sparkNow(G, m, target, dmg, p, t, t.kind === "Fusion" ? "fusion" : null); break;
    case "Sniper":
      if (alive(target)) { hit(G, target, dmg, t); fx(G, { k: "sniper", x1: m.x, y1: m.y, x2: target.x, y2: target.y }); } break;
    case "Railgun":
      if (alive(target)) {
        const d = dist(t, target) || 1, sc = 900 / d;
        const rail = { x1: t.x, y1: t.y, x2: t.x + (target.x - t.x) * sc, y2: t.y + (target.y - t.y) * sc };
        addShot(G, { k: "rail", next: G.now + 32, ...rail, dmg, src: t });
        fx(G, { k: "rail", ...rail, dmg });
      }
      break;
    default: if (G.mods && G.mods.fire) shot = G.mods.fire(G, t, target, dmg, p); break;   // expansion weapons
  }
  if (t.reacquire) t.target = null;
  return shot;
}
function laserNow(G, from, target, dmg, src) {            // LaserEngine: instant
  if (!alive(target)) return;
  fx(G, { k: "laser", x1: from.x, y1: from.y, x2: target.x, y2: target.y, dmg });
  hit(G, target, dmg, src);
}
function sparkNow(G, from, target, dmg, p, src, look, blast) {   // SparkEngine: instant
  if (!alive(target)) return;
  fx(G, { k: "spark", x1: from.x, y1: from.y, x2: target.x, y2: target.y, dmg, look: look || null });
  if (blast) spawnBlast(G, blast.type, target.x, target.y, blast.dmg, blast.poison, src, { target, angle: 0 });
  poison(G, target, p, true);
  hit(G, target, dmg, src);
}

// ---------------------------------------------------------------- per-kind updates
function updateTurret(G, t) {
  const dt = G.now - t.timeLast;
  let keepTime = false;
  if (dt > 0 && t.active) {
    switch (t.type) {
      case "modifier": break;
      case "targeter": updateTargeter(G, t, dt); break;
      case "combonly": updateCombonly(G, t, dt); break;
      default:
        if (t.kind === "Green") updateGreen(G, t, dt);
        else if (t.kind === "Red") updateRed(G, t, dt);
        else if (t.kind === "Fusion") keepTime = updateFusion(G, t, dt);
        else if (G.mods && G.mods.update && G.mods.update(G, t, dt)) { /* expansion turret */ }
        else updateStandard(G, t, dt);
    }
  }
  if (!keepTime) t.timeLast = G.now;
}
function freakCheck(G, t) {
  if (t.freakAvail && (t.freakNext === null || G.now >= t.freakNext)) freakoutNow(G, t);
}
function updateStandard(G, t, dt) {                       // Blue, Yellow, Sniper, Railgun
  freakCheck(G, t);
  if (t.kind === "Yellow") chargeAccumulate(t, dt);
  t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode);
  if (alive(t.target)) { t.bearTo = null; tryFiring(G, t, t.target, dt); }
  else if (alive(t.bearTo)) bearTowards(G, t, t.bearTo, dt);
}
function tryFiring(G, t, target, dt) {                    // turretTryFiring
  if (!alive(target)) return true;
  if (bearTowards(G, t, target, dt) !== true && t.mustFace) return false;
  if (canFire(G, t)) {
    if (comboCanFire(G, t)) comboFire(G, t, target);
    else normalFire(G, t, target);
  }
  return true;
}
function normalFire(G, t, target) {
  if (t.kind === "Green") return linkFire(G, t, target, t.eff.damage, true);
  if (t.kind === "Yellow" && t.charge > 0) return chargeFire(G, t, target);
  if (t.kind === "Fusion") return fusionFire(G, t, target);
  return turretFire(G, t, target, t.eff.damage);
}
function updateGreen(G, t, dt) {
  t.offered = canFire(G, t);
  t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode);
  if (alive(t.target)) { t.bearTo = null; tryFiring(G, t, t.target, dt); }
  else if (alive(t.bearTo)) bearTowards(G, t, t.bearTo, dt);
}
// Turret.linkFire: offering greens in range fire into the lead and add their chain ×1.25
function linkFire(G, t, target, dmg, lead) {
  const inRangeGreens = [];
  for (const o of G.turrets) if (o !== t && o.kind === "Green" && o.active && dist(t, o) <= t.eff.range) inRangeGreens.push(o);
  if (inRangeGreens.length === 0) { if (t.kind === "Green") turretFire(G, t, target, dmg); return dmg; }
  t.offered = false;
  let total = t.eff.damage;
  const offered = [];
  for (const o of inRangeGreens) if (o.offered) { o.offered = false; offered.push(o); }
  if (offered.length === 0) {
    if (t.kind === "Green") turretFire(G, t, target, total);
    return total;
  }
  for (const o of offered) {
    o.rot = wrap180(degTo(o, t));
    total += linkFire(G, o, t, 0, false) * G.D.settings.linkMult;
  }
  if (t.kind === "Green") turretFire(G, t, target, total);
  return total;
}
function chargeAccumulate(t, dt) {
  if (t.charge >= t.chargeMax) return;
  t.charge = Math.max(t.charge, 0);
  t.charge = Math.min(t.charge + t.chargeRate * (dt / 1000), t.chargeMax);
}
function chargeFire(G, t, target) {                       // TurretYellow.chargeFire: boosts the slow, not the damage
  const c = t.charge / 100;
  const p = modStat(t.mod.poison_added + c * 3, t.mod.poison_mult, t.base.poison);
  const shot = turretFire(G, t, target, t.eff.damage, p);
  t.charge = Math.max(t.charge - 50, 0);
  return shot;
}
function updateRed(G, t, dt) {
  t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode);
  if (alive(t.target)) {
    tryFiring(G, t, t.target, dt);
    for (const r of t.holding) if (!r.dead) { r.target = t.target; r.holdingInitially = false; }
    t.holding = [];
  } else if (alive(t.bearTo)) bearTowards(G, t, t.bearTo, dt);
  if (t.holdingPattern && canFire(G, t)) {
    let n = 0; for (const r of t.holding) if (!r.dead) n++;
    if (n < 4) { t.holdingRound = true; const r = turretFire(G, t, null, t.eff.damage); t.holdingRound = false; if (r) t.holding.push(r); }
  }
}
function updateFusion(G, t, dt) {
  // one ready green/yellow in range fires into the cannon each tick
  const feeders = [];
  for (const o of G.turrets) if (o !== t && o.active && (o.kind === "Green" || o.kind === "Yellow") && dist(t, o) <= t.eff.range) feeders.push(o);
  if (!t.feedList) t.feedList = arrayPick(G, feeders, feeders.length);
  let fed = false;
  for (const o of t.feedList) {
    if (fed) break;
    if (!o.dead && o.active && canFire(G, o)) { turretFire(G, o, t, o.eff.damage); fed = true; }
  }
  if (!fed) t.feedList = null;
  t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode);
  if (alive(t.target)) {
    if (bearTowards(G, t, t.target, dt) !== true && t.mustFace) return true;   // skip the time_last update
    if (G.now - t.fired > 6000) tryFiring(G, t, t.target, dt);
  } else if (alive(t.bearTo)) bearTowards(G, t, t.bearTo, dt);
  return false;
}
function fusionFire(G, t, target) {
  const e = t.eff.damage, add = Math.min(e, t.store);
  const p = Math.min(100, t.storeP);
  turretFire(G, t, target, add + e, p);
  t.store -= add; t.storeP -= p;
}
function updateTargeter(G, t, dt) {
  t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode);
  if (alive(t.target)) {
    if (bearTowards(G, t, t.target, dt)) {
      fx(G, { k: "paint", x1: t.x, y1: t.y, x2: t.target.x, y2: t.target.y });
      if (canFire(G, t)) {
        t.fired = G.now;
        const tg = t.target;
        for (const o of t.joins) if (!o.dead && o.active) { tryFiring(G, o, tg, G.now - o.timeLast); if (alive(tg)) { o.bearTo = tg; o.bearIgnore = false; } }
        if (t.reacquire) t.target = null;
      }
    }
  } else t.rot = wrap180(t.rot + dt / 1000 * 90);
}
function updateCombonly(G, t, dt) {
  if (!t.combo) return;                                   // waiting for the player to pick a combo
  if (t.armedAt !== null && G.now < t.armedAt) return;    // 1.5 s weapon fade-in
  t.target = availOrAcquire(G, t.target, t, t.eff.range, t.targetMode);
  if (alive(t.target)) {
    t.bearTo = null;
    if (bearTowards(G, t, t.target, dt) && comboCanFire(G, t)) comboFireNamed(G, t, t.combo, null, t.target, true);
  } else if (alive(t.bearTo)) bearTowards(G, t, t.bearTo, dt);
}

// ---------------------------------------------------------------- freakout (FreakoutEngine)
function freakoutNow(G, t) {
  if (t.freakAvail) t.freakNext = G.now + 80000 / 2 + rnd(G) * 40000 - t.lvl.rate * 4 * 1000;
  t.freak = { stage: 0, timer: 0, next: G.now + TICK.frame };
}
function updateFreak(G, t) {
  const f = t.freak;
  if (!f || G.now < f.next) return;
  f.next += TICK.frame;
  if (f.stage === 0) { f.timer = G.now; f.stage = 1; fx(G, { k: "freakwarn", id: t.id }); }
  else if (f.stage === 1) { if (G.now - f.timer > 3000) f.stage = 2; }
  else if (f.stage === 2) {
    if (t.modifiable) { t.freakGain.damage += 3; t.freakGain.rate += 4; modifyUpdate(G, t); }
    f.timer = G.now; f.stage = 3; fx(G, { k: "freak", id: t.id });
  } else if (f.stage === 3) { if (G.now - f.timer > 5000) f.stage = 4; }
  else if (f.stage === 4) {
    if (t.modifiable) { t.freakGain.damage -= 3; t.freakGain.rate -= 4; modifyUpdate(G, t); }
    t.freak = null;
  }
}

// ================================================================ combos
function comboCanFire(G, t) {
  if (!t.active || !t.comboCapable) return false;
  if (G.now - t.fired < t.eff.msec) return false;
  return G.now >= t.comboNext;
}
function countColours(G, t, regardless) {                 // comboCountColours(Regardless)
  const c = { Red: [], Green: [], Blue: [], Yellow: [] };
  if (G.D.extraColours) for (const k of G.D.extraColours) c[k] = [];
  for (const o of G.turrets) {
    if (o === t || o.comboNever || !o.active || !c[o.kind]) continue;
    if (dist(o, t) > G.D.settings.comboRange) continue;
    if (regardless ? o.comboCapable : comboCanFire(G, o)) c[o.kind].push(o);
  }
  return c;
}
const RULES = {
  Red: [[c => c.Blue >= 2, "nuke"], [c => c.Red >= 1 && c.Yellow >= 1 && c.Blue >= 1, "napalm"], [c => c.Blue >= 1 && c.Green >= 1, "poison_rocket"],
    [c => c.Yellow >= 1, "tazer_rocket"], [c => c.Green >= 1, "laser_rocket"]],
  Green: [[c => c.Red >= 2 && c.Blue >= 1, "rocket_bfg"], [c => c.Red >= 1 && c.Blue >= 1, "bfg"]],
  Blue: [[c => c.Red >= 2 && c.Green >= 1 && c.Blue >= 1, "big_laser_cluster_landmine"], [c => c.Red >= 2 && c.Blue >= 1, "big_cluster_landmine"],
    [c => c.Red >= 2 && c.Green >= 1, "big_laser_clusterbomb"], [c => c.Red >= 2, "big_clusterbomb"], [c => c.Blue >= 1 && c.Yellow >= 1, "sparky_landmine"],
    [c => c.Red >= 1 && c.Yellow >= 1, "sparky_clusterbomb"], [c => c.Red >= 1 && c.Green >= 1, "laser_clusterbomb"], [c => c.Red >= 1 && c.Blue >= 1, "big_landmine"],
    [c => c.Red >= 1, "clusterbomb"], [c => c.Blue >= 1, "landmine"]],
  Yellow: [[c => c.Yellow >= 2 && c.Green === 1, "blackhole"], [c => c.Yellow >= 1 && c.Blue === 1 && c.Green === 1, "shockwave"], [c => c.Red >= 1 && c.Blue === 1, "tazer_bfg"]],
};
// TurretCombonly.comboScan: what a Combonly can become, by colour (later entries overwrite earlier ones)
const COMBONLY = [
  [c => c.Blue >= 2, "Blue", "landmine", { Blue: 2 }], [c => c.Red >= 1 && c.Blue >= 1, "Blue", "clusterbomb", { Blue: 1, Red: 1 }],
  [c => c.Green >= 1 && c.Red >= 1, "Red", "laser_rocket", { Green: 1, Red: 1 }], [c => c.Yellow >= 1 && c.Red >= 1, "Red", "tazer_rocket", { Yellow: 1, Red: 1 }],
  [c => c.Red >= 1 && c.Blue >= 2, "Blue", "big_landmine", { Blue: 2, Red: 1 }], [c => c.Blue >= 2 && c.Yellow >= 1, "Blue", "sparky_landmine", { Blue: 2, Yellow: 1 }],
  [c => c.Red >= 2 && c.Blue >= 1, "Blue", "big_clusterbomb", { Red: 2, Blue: 1 }], [c => c.Blue >= 2 && c.Red >= 1, "Red", "nuke", { Blue: 2, Red: 1 }],
  [c => c.Yellow >= 3 && c.Green >= 1, "Yellow", "blackhole", { Yellow: 3, Green: 1 }], [c => c.Red >= 1 && c.Green >= 1 && c.Blue >= 1, "Blue", "laser_clusterbomb", { Red: 1, Green: 1, Blue: 1 }],
  [c => c.Red >= 1 && c.Blue >= 1 && c.Yellow >= 1, "Yellow", "tazer_bfg", { Red: 1, Yellow: 1, Blue: 1 }], [c => c.Red >= 1 && c.Blue >= 1 && c.Green >= 1, "Green", "bfg", { Red: 1, Green: 1, Blue: 1 }],
  [c => c.Blue >= 1 && c.Green >= 1 && c.Red >= 1, "Red", "poison_rocket", { Red: 1, Green: 1, Blue: 1 }], [c => c.Red >= 1 && c.Yellow >= 1 && c.Blue >= 1, "Blue", "sparky_clusterbomb", { Red: 1, Yellow: 1, Blue: 1 }],
  [c => c.Yellow >= 2 && c.Blue >= 1 && c.Green >= 1, "Yellow", "shockwave", { Yellow: 2, Green: 1, Blue: 1 }], [c => c.Red >= 2 && c.Blue >= 1 && c.Green >= 1, "Blue", "big_laser_clusterbomb", { Red: 2, Green: 1, Blue: 1 }],
  [c => c.Red >= 2 && c.Blue >= 1 && c.Green >= 1, "Green", "rocket_bfg", { Red: 2, Green: 1, Blue: 1 }], [c => c.Red >= 2 && c.Blue >= 1 && c.Yellow >= 1, "Red", "napalm", { Red: 2, Yellow: 1, Blue: 1 }],
  [c => c.Red >= 2 && c.Blue >= 2, "Blue", "big_cluster_landmine", { Red: 2, Blue: 2 }], [c => c.Red >= 2 && c.Blue >= 2 && c.Green >= 1, "Blue", "big_laser_cluster_landmine", { Red: 2, Blue: 2, Green: 1 }],
];
function counts(c) { const n = {}; for (const k in c) n[k] = c[k].length; return n; }
function comboFire(G, t, target) {
  const c = countColours(G, t, false), n = counts(c);
  const rules = RULES[t.kind] || (G.mods && G.mods.rules && G.mods.rules[t.kind]) || [];
  for (const r of rules) if (r[0](n)) return comboFireNamed(G, t, r[1], c, target, false);
  return normalFire(G, t, target);
}
const TAKES = {
  clusterbomb: { Red: 1 }, sparky_clusterbomb: { Red: 1, Yellow: 1 }, big_clusterbomb: { Red: 2 }, big_sparky_clusterbomb: { Red: 2, Yellow: 1 },
  laser_clusterbomb: { Red: 1 }, big_laser_clusterbomb: { Red: 2 }, landmine: { Blue: 1 }, big_landmine: { Red: 1, Blue: 1 },
  sparky_landmine: { Red: 1, Blue: 1, Yellow: 1 }, big_cluster_landmine: { Red: 2, Blue: 1 }, big_laser_cluster_landmine: { Red: 2, Blue: 1, Green: 1 },
  bfg: { Red: 1, Blue: 1 }, tazer_bfg: { Red: 1, Blue: 1 }, rocket_bfg: { Red: 1, Blue: 1 }, laser_rocket: {}, tazer_rocket: {},
  poison_rocket: { Green: 1, Blue: 1 }, nuke: { Blue: 2 }, blackhole: { Yellow: 2, Green: 1 }, shockwave: { Yellow: 1, Blue: 1 }, napalm: { Yellow: 1, Blue: 1, Red: 1 },
};
const TAKE_ORDER = {                                        // the order comboTake is called in, per combo
  sparky_clusterbomb: ["Red", "Yellow"], big_sparky_clusterbomb: ["Red", "Yellow"], big_landmine: ["Red", "Blue"], sparky_landmine: ["Red", "Blue", "Yellow"],
  big_cluster_landmine: ["Red", "Blue"], big_laser_cluster_landmine: ["Red", "Blue", "Green"], bfg: ["Red", "Blue"], tazer_bfg: ["Red", "Blue"], rocket_bfg: ["Red", "Blue"],
  poison_rocket: ["Green", "Blue"], blackhole: ["Yellow", "Green"], shockwave: ["Yellow", "Blue"], napalm: ["Yellow", "Blue", "Red"],
};
function comboTake(G, lead, list) {
  for (const o of list) {
    if (!o) continue;
    o.comboNext = G.now + lead.comboRecharge - 1;
    o.bearTo = lead; o.bearIgnore = true;
    fx(G, { k: "take", x1: o.x, y1: o.y, x2: lead.x, y2: lead.y });
  }
}
function takeColour(G, lead, list, qty) { if (list && list.length) comboTake(G, lead, qty === 2 ? arrayPick(G, list, 2) : arrayPick(G, list, 1)); }
function takeLink(G, lead, greens, silent) {              // comboTakeLink
  if (silent || !greens || !greens.length) return 0;
  const g = arrayPick(G, greens, 1)[0];
  if (!g || g.dead) return 0;
  let d = linkFire(G, g, lead, 0, false);
  d += g.eff.damage;
  g.rot = wrap180(degTo(g, lead));
  comboTake(G, lead, [g]);
  return d;
}
function takePoison(G, lead, yellows, silent) {           // comboTakePoison
  if (silent || !yellows || !yellows.length) return 20;
  const y = arrayPick(G, yellows, 1)[0];
  if (!y) return 20;
  const p = y.eff.poison;
  comboTake(G, lead, [y]);
  return p;
}
function comboFireNamed(G, t, name, c, target, silent) {
  const C = G.D.combos[name];
  const cm = G.mods && G.mods.comboDamage ? G.mods.comboDamage(G, t, name) : 1;
  const md = v => modStat(t.mod.damage_added, t.mod.damage_mult + t.freakGain.damage, v) * cm;
  t.comboRecharge = C.recharge * (G.mods && G.mods.rechargeMult ? G.mods.rechargeMult(G, t, name) : 1);
  G.stats.combos++;
  // comboFired
  t.comboNext = G.now + t.comboRecharge;
  t.fired = G.now;
  fx(G, { k: "combo", name, x: t.x, y: t.y, id: t.id });
  const take = () => {
    if (silent) return;
    const needs = TAKES[name] || (G.D.combos[name] && G.D.combos[name].needs) || {};
    const order = TAKE_ORDER[name] || Object.keys(needs);
    for (const col of order) takeColour(G, t, c[col], needs[col]);
  };
  const m = muzzle(t);
  const base = { x: m.x, y: m.y, rot: t.rot, target, src: t };
  let link = 0, p = 20;
  if (G.mods && G.mods.comboStart) G.mods.comboStart(G, t, name);
  switch (name) {
    case "clusterbomb": case "sparky_clusterbomb": case "big_clusterbomb": case "big_sparky_clusterbomb":
    case "laser_clusterbomb": case "big_laser_clusterbomb": {
      const laser = name.indexOf("laser") >= 0, sparky = name.indexOf("sparky") >= 0;
      if (laser) link = takeLink(G, t, c && c.Green, silent);
      const blastType = { clusterbomb: "small", sparky_clusterbomb: "small", big_clusterbomb: "large", big_sparky_clusterbomb: "large", laser_clusterbomb: "medium", big_laser_clusterbomb: "large" }[name];
      addShot(G, { ...base, k: "bomb", dmg: md(C.bullet_damage), speed: 750, next: G.now + TICK.frame, timeLast: G.now,
        blast: { type: blastType, dmg: md(C.blast_damage), poison: 1 },
        cluster: { type: sparky ? "spark" : "blast", qty: C.cluster_qty, dmg: md(C.cluster_damage), holding: C.cluster_holding !== false,
          laser: laser, laserDmg: laser ? md(link + C.cluster_laser_damage) : 1e6 } });
      take();
      break;
    }
    case "landmine": case "big_landmine": case "sparky_landmine": case "big_cluster_landmine": case "big_laser_cluster_landmine": {
      if (!t.minePts) {
        const maxR = upAmountMax(t, "range");
        t.minePts = [];
        for (const q of G.mines) if (dist(t, q) <= maxR) t.minePts.push({ x: q.x, y: q.y });
      }
      const spot = t.minePts.length ? arrayPick(G, t.minePts, 1)[0] : null;
      const blastType = (name === "landmine" || name === "sparky_landmine") ? "small" : "large";
      let cluster = null;
      if (name === "sparky_landmine") cluster = { type: "spark", qty: C.cluster_qty, dmg: 1e6, holding: true, laser: false, laserDmg: 1e6 };
      if (name === "big_cluster_landmine") cluster = { type: "blast", qty: C.cluster_qty, dmg: md(C.cluster_damage), holding: C.cluster_holding !== false, laser: false, laserDmg: 1e6 };
      if (name === "big_laser_cluster_landmine") cluster = { type: "blast", qty: C.cluster_qty, dmg: md(C.cluster_damage), holding: C.cluster_holding !== false, laser: true, laserDmg: md(C.cluster_laser_damage) };
      if (spot) {
        spot.x += Math.floor(rnd(G) * 10 - 5); spot.y += Math.floor(rnd(G) * 10 - 5);
        addShot(G, { k: "mine", x: t.x, y: t.y, sx: t.x, sy: t.y, tx: spot.x, ty: spot.y, t0: G.now, planted: false,
          twNext: G.now + TICK.tween, next: G.now + TICK.mine, target, src: t, big: blastType === "large",
          blast: { type: blastType, dmg: md(C.blast_damage), poison: 1 }, cluster });
      }
      take();
      break;
    }
    case "bfg": case "tazer_bfg": case "rocket_bfg": {
      if (name !== "tazer_bfg") link = linkFire(G, t, t, 0, true);
      const tz = name === "tazer_bfg";
      let tp = 20;
      if (tz) { tp = Math.trunc(t.eff.poison); if (tp <= 0) tp = 20; }
      newRocket(G, m.x, m.y, t.rot, target, md(C.bullet_damage + link), t, {
        variant: tz ? "bfgtazer" : "bfg", speed: C.move_speed, noRotate: true, holdingCapable: true, offRemove: true, offLock: true, impact: 10,
        blast: { type: "bfg", dmg: md(C.blast_damage + link), poison: 1 },
        laser: { dmg: md(C.laser_damage + link), range: C.laser_range, rate: C.laser_rate, spark: tz, poison: tp },
        rocketGun: name === "rocket_bfg" ? { dmg: md(C.rocket_damage + link), rate: 120 } : null });
      take();
      break;
    }
    case "laser_rocket": {
      link = takeLink(G, t, c && c.Green, silent);
      newRocket(G, m.x, m.y, t.rot, target, md(link + C.bullet_damage), t, { variant: "laserrocket", speed: C.move_speed, holdingCapable: true,
        laser: { dmg: md(link + C.laser_damage), range: C.laser_range, rate: 120, spark: false, poison: 1 } });
      break;
    }
    case "tazer_rocket": {
      p = takePoison(G, t, c && c.Yellow, silent);
      newRocket(G, m.x, m.y, t.rot, target, md(C.bullet_damage), t, { variant: "tazerrocket", speed: C.move_speed, holdingCapable: true,
        laser: { dmg: md(C.laser_damage), range: C.laser_range, rate: 120, spark: true, poison: p } });
      break;
    }
    case "poison_rocket":
      newRocket(G, m.x, m.y, t.rot, target, md(C.bullet_damage), t, { variant: "poison", speed: C.move_speed, holdingCapable: true,
        blast: { type: "poison", dmg: C.blast_damage, poison: 2 } });
      take();
      break;
    case "nuke":
      newRocket(G, m.x, m.y, t.rot, target, md(C.bullet_damage), t, { variant: "nuke", speed: C.move_speed, holdingCapable: true,
        blast: { type: "huge", dmg: md(C.blast_damage), poison: 1 } });
      take();
      break;
    case "napalm":
      newRocket(G, m.x, m.y, t.rot, target, t.eff.damage, t, { variant: "napalm",
        napalm: { qty: C.napalm_quantity, timing: C.napalm_timing, jit: C.napalm_jit } });
      take();
      break;
    case "blackhole": {
      if (!t.holePts) { t.holePts = []; for (const q of G.mines) if (dist(t, q) <= 90) t.holePts.push({ x: q.x, y: q.y }); }
      const pts = t.holePts;
      if (pts.length) {
        const spot = arrayPick(G, pts, 1)[0];
        addShot(G, { k: "hole", x: spot.x, y: spot.y, r: C.blackhole_radius, dur: C.blackhole_duration, t0: G.now, open: false,
          openAt: G.now + 224, next: G.now + 224, closing: false, src: t });
      }
      take();
      break;
    }
    case "shockwave": {
      link = takeLink(G, t, c && c.Green, silent);
      sparkNow(G, m, target, md(link + C.bullet_damage), C.bullet_poison, t, "shock",
        { type: "shockwave", dmg: md(link + C.blast_damage), poison: C.blast_poison });
      take();
      break;
    }
    default:
      if (G.mods && G.mods.comboFire) G.mods.comboFire(G, t, name, c, target, silent, { md, take, m, link: () => takeLink(G, t, c && c.Green, silent) });
  }
}

// ================================================================ projectiles
function addShot(G, s) { s.id = G.nextId++; s.dead = false; G.shots.push(s); return s; }
function newRocket(G, x, y, rot, target, dmg, src, o) {    // RocketEngine (+ Projectile defaults)
  o = o || {};
  const dir = rnd(G) >= 0.5 ? -1 : 1;
  const period = Math.floor(32 + rnd(G) * 10);
  const r = { k: "rocket", x, y, rot, target, dmg, src, speed: o.speed || 250, turn: 270, impact: o.impact || 8,
    holdingCapable: !!o.holdingCapable, holdingInitially: !!o.holdingInitially, holdDir: dir, noRotate: !!o.noRotate,
    offRemove: !!o.offRemove, offLock: !!o.offLock, blast: o.blast || null, cluster: o.cluster || null, napalm: o.napalm || null,
    laser: null, rocketGun: null, variant: o.variant || "rocket", tier: o.tier || 0,
    period, next: G.now + period, timeLast: G.now };
  if (o.laser) r.laser = { dmg: o.laser.dmg, r2: o.laser.range * o.laser.range, msec: 1000 / (o.laser.rate / 60), fired: G.now, spark: o.laser.spark, poison: o.laser.poison };
  if (o.rocketGun) r.rocketGun = { dmg: o.rocketGun.dmg, msec: 1000 / (o.rocketGun.rate / 60), fired: G.now };
  return addShot(G, r);
}
function updateShot(G, s) {
  switch (s.k) {
    case "shell": return updateShell(G, s);
    case "rocket": return updateRocket(G, s);
    case "bomb": return updateBomb(G, s);
    case "mine": return updateMine(G, s);
    case "hole": return updateHole(G, s);
    case "walker": return updateWalker(G, s);
    case "napalm": return updateNapalm(G, s);
    case "rail": if (G.now >= s.next) { railHurt(G, s); s.dead = true; } return;
    default: if (G.mods && G.mods.updateShot) G.mods.updateShot(G, s); return;
  }
}
function updateShell(G, s) {                               // ShellEngine (32 ms)
  if (s.next === undefined) { s.next = G.now + TICK.shell; s.timeLast = G.now; return; }
  if (G.now < s.next) return;
  s.next += TICK.shell;
  const dt = G.now - s.timeLast; s.timeLast = G.now;
  if (dt === 0) return;
  const step = dt / 1000 * s.speed;
  if (!alive(s.target)) { s.dead = true; return; }
  const d = dist(s, s.target);
  if (d < 3) { hit(G, s.target, s.dmg, s.src); s.dead = true; return; }
  s.rot = degTo(s, s.target);
  const f = fwd(s.rot, step);
  if (d < step) { hit(G, s.target, s.dmg, s.src); s.dead = true; return; }
  s.x += f.x; s.y += f.y;
}
function updateRocket(G, s) {                              // RocketEngine.update
  if (G.now < s.next) return;
  s.next += s.period;
  const dt = G.now - s.timeLast;
  if (dt === 0) return;
  s.timeLast = G.now;
  if (s.offRemove || s.offLock) { if (s.x < -10 || s.x > 730 || s.y < -10 || s.y > 490) { s.dead = true; return; } }
  const step = dt / 1000 * s.speed, rstep = dt / 1000 * s.turn;
  const f = fwd(s.rot, step);
  s.target = availOrAcquire(G, s.target, s, 1000, "near");
  if (s.holdingInitially) {
    s.x += f.x; s.y += f.y; s.rot = wrap180(s.rot + rstep * s.holdDir);
  } else if (s.target) {
    const want = degTo(s, s.target), diff = want - s.rot, d2 = dist2(s, s.target);
    if (!s.noRotate) {
      if (Math.abs(diff) < Math.abs(rstep)) s.rot = want;
      else { const a = (diff + 360) % 360, b = (360 - diff) % 360; s.rot = wrap180(b < a ? s.rot - rstep : s.rot + rstep); }
    }
    if (d2 < step * step || d2 < s.impact * s.impact) { s.x = s.target.x; s.y = s.target.y; rocketHit(G, s, s.target); return; }
    s.x += f.x; s.y += f.y;
    if (s.laser && d2 <= s.laser.r2 && G.now - s.laser.fired >= s.laser.msec) {
      s.laser.fired = G.now;
      if (s.laser.spark) sparkNow(G, s, s.target, s.laser.dmg, s.laser.poison, s.src, "tazer");
      else laserNow(G, s, s.target, s.laser.dmg, s.src);
    }
    if (s.rocketGun && G.now - s.rocketGun.fired >= s.rocketGun.msec) {
      s.rocketGun.fired = G.now;
      newRocket(G, s.x, s.y, degTo(s, s.target), s.target, s.rocketGun.dmg, s.src, { holdingCapable: s.holdingCapable, tier: 9 });
    }
  } else if (s.holdingCapable) {
    s.offRemove = false;
    s.x += f.x; s.y += f.y;
    if (!s.noRotate) s.rot = wrap180(s.rot + rstep * s.holdDir);
  } else {
    s.x += f.x; s.y += f.y; s.offRemove = true;
  }
}
function rocketHit(G, s, target) {                         // RocketEngine.targetHit
  projectileBlast(G, s, target);
  projectileCluster(G, s);
  hit(G, target, s.dmg, s.src);
  s.dead = true;
}
function projectileBlast(G, s, target) {
  if (s.blast) spawnBlast(G, s.blast.type, s.x, s.y, s.blast.dmg, s.blast.poison, s.src, { target, angle: s.rot });
  if (s.napalm) addShot(G, { k: "napalm", x: s.x, y: s.y, angle: s.rot, out: 0, qty: s.napalm.qty, timing: s.napalm.timing, jit: s.napalm.jit,
    next: G.now, src: s.src, fx: fwd(s.rot, 15) });
}
function projectileCluster(G, s) {
  const c = s.cluster;
  if (!c) return;
  if (c.type === "spark") {                                // ClusterSparkEngine
    const list = inBoxList(G, s, 220);
    for (let i = 0; i < c.qty; i++) {
      const f = fwd((i + 1) / c.qty * 360, 40);
      const from = { x: s.x + f.x, y: s.y + f.y };
      const tg = list.length ? list[i % list.length] : null;
      if (tg) sparkNow(G, from, tg, c.dmg, 20, s.src, "cluster");
    }
  } else {                                                 // ClusterBlastEngine: Rocket9 × qty
    for (let i = 0; i < c.qty; i++) {
      const rot = (i + 1) / c.qty * 360, f = fwd(rot, 30);
      newRocket(G, s.x + f.x, s.y + f.y, rot, null, c.dmg, s.src, { holdingCapable: c.holding, tier: 9,
        laser: c.laser ? { dmg: c.laserDmg, range: 200, rate: 120, spark: false, poison: 1 } : null });
    }
  }
}
function updateBomb(G, s) {                                // ClusterBombEngine (every frame)
  if (G.now < s.next) return;
  s.next += TICK.frame;
  const dt = G.now - s.timeLast; s.timeLast = G.now;
  if (dt === 0) return;
  const step = dt / 1000 * s.speed;
  if (alive(s.target)) {
    const d = dist(s, s.target);
    if (d < 3) { hit(G, s.target, s.dmg, s.src); return; }
    s.rot = degTo(s, s.target);
    const f = fwd(s.rot, step);
    if (d < step) { hit(G, s.target, s.dmg, s.src); bombExplode(G, s); return; }
    s.x += f.x; s.y += f.y;
  } else bombExplode(G, s);
}
function bombExplode(G, s) { projectileBlast(G, s, s.target); projectileCluster(G, s); s.dead = true; }
function updateMine(G, s) {                                // LandmineEngine
  if (!s.planted && G.now >= s.twNext) {
    s.twNext += TICK.tween;
    const r = (G.now - s.t0) / 1000;
    if (r >= 1) { s.x = s.tx; s.y = s.ty; s.planted = true; }
    else { s.x = s.sx + (s.tx - s.sx) * r; s.y = s.sy + (s.ty - s.sy) * r; }
  }
  if (G.now < s.next) return;
  s.next += TICK.mine;
  if (!s.planted) return;
  const list = inBoxList(G, s, 20);
  if (list.length) {
    arrayPick(G, list, 1);                                 // targetAcquireBySlice picks one at random
    projectileBlast(G, s, s.target); projectileCluster(G, s); s.dead = true;
    fx(G, { k: "mine", x: s.x, y: s.y });
  }
}
function updateHole(G, s) {                                // BlackHole
  if (G.now < s.next) return;
  if (s.closing) { s.dead = true; return; }
  s.next += TICK.hole;
  s.open = true;
  for (const a of inBoxList(G, s, s.r)) {
    if (a.holed) continue;
    const d = dist(s, a);
    if (d <= s.r) {
      a.holed = { sx: a.x, sy: a.y, tx: s.x, ty: s.y, t0: G.now, dur: d / 500 * 1000, next: G.now + TICK.tween };
      a.bounty = 0; a.tw = null; a.rep = null;
    }
  }
  for (const o of G.shots) {                               // projectiles get swallowed too
    if (o === s || o.dead || o.k === "hole" || o.k === "walker" || o.k === "rail") continue;
    if (inBox(s, o, s.r)) { o.dead = true; fx(G, { k: "swallow", x: o.x, y: o.y }); }
  }
  for (const b of G.blasts) if (!b.done && inBox(s, b, s.r)) { b.done = true; b.swallowed = true; }
  if (G.now - s.t0 >= s.dur) { s.closing = true; s.next = G.now + 224; }
}
function updateWalker(G, s) {                              // Shockwave (an AttackerEngine that walks the road)
  const t = s.tw;
  if (t && G.now >= t.next) {
    t.next += TICK.tween;
    const r = t.dur > 0 ? (G.now - t.t0) / t.dur : 1;
    if (r >= 1) { s.x = t.tx; s.y = t.ty; s.tw = null; walkerAdvance(G, s); if (s.dead) return; }
    else { s.x = t.sx + (t.tx - t.sx) * r; s.y = t.sy + (t.ty - t.sy) * r; }
  }
  if (G.now >= s.end) { s.dead = true; return; }
  if (G.now < s.next) return;
  s.next += TICK.walker;
  const k = 1 - (G.now - s.t0) / 3000;
  const dmg = Math.max(0, k * s.dmg), p = Math.max(0, k * s.poison);
  for (const a of inBoxList(G, s, 10)) { hit(G, a, dmg, null); poison(G, a, p, true); }
}
function walkerAdvance(G, s) {
  if (s.wp === null) return;                                // the target was already gone: stand still
  s.wp += s.dir;
  if (s.wp <= 0 || s.wp > G.road.length) { s.dead = true; return; }
  const wp = G.road[s.wp - 1];
  s.tw = { sx: s.x, sy: s.y, tx: wp.x, ty: wp.y, t0: G.now, dur: dist(s, wp) / 150 * 1000, next: G.now + TICK.tween };
}
function updateNapalm(G, s) {                              // BlastNapalm
  if (G.now < s.next) return;
  s.next += s.timing;
  if (s.out >= s.qty) { s.dead = true; return; }
  const jx = Math.round(rnd(G) * s.jit - s.jit / 2), jy = Math.round(rnd(G) * s.jit - s.jit / 2);
  spawnBlast(G, "tiny", s.x + jx, s.y + jy, 1e6, 1, s.src, null);   // the sub-blasts get Projectile's default 1 M
  s.x += s.fx.x; s.y += s.fx.y;
  s.out++;
}
function railHurt(G, s) {                                  // RailLaser: everything under the 40 px beam
  for (const a of G.attackers) {
    if (a.dead) continue;
    const dx = s.x2 - s.x1, dy = s.y2 - s.y1, l2 = dx * dx + dy * dy;
    let k = ((a.x - s.x1) * dx + (a.y - s.y1) * dy) / l2; k = Math.max(0, Math.min(1, k));
    const ex = a.x - (s.x1 + k * dx), ey = a.y - (s.y1 + k * dy);
    if (ex * ex + ey * ey <= 400) hit(G, a, s.dmg, s.src);
  }
}

// ---------------------------------------------------------------- blasts (BlastEngine)
function spawnBlast(G, type, x, y, dmg, p, src, ctx) {
  const shape = G.D.blasts[type] || [80, 80];
  const time = shape[0], size = shape[1];
  const b = { id: G.nextId++, type, x, y, dmg, poison: p, src, size, t0: G.now, hitAt: G.now + Math.ceil(time / TICK.tween) * TICK.tween,
    done: false, swallowed: false };
  G.blasts.push(b);
  fx(G, { k: "blast", type, x, y, size });
  if (type === "shockwave" && ctx) {                       // BlastShockwave.preBlast: two walkers along the road
    const tg = ctx.target, wp = alive(tg) && tg.wp ? tg.wp : null;
    for (const dir of [1, -1]) {
      const w = { k: "walker", x, y, dir, wp: wp === null ? null : (dir === 1 ? wp - 1 : wp), dmg, poison: p, t0: G.now, end: G.now + 3008,
        next: G.now + TICK.walker, tw: null, src };
      addShot(G, w);
      walkerAdvance(G, w);
    }
  }
  return b;
}
function updateBlast(G, b) {
  if (b.done || G.now < b.hitAt) return;
  b.done = true;
  const r = b.size / 2;
  for (const a of inBoxList(G, b, r)) {
    if (dist(b, a) <= r) { poison(G, a, b.poison, false); hit(G, a, b.dmg, b.src); }
  }
}

// ================================================================ main step
function step(G) {
  if (G.over) return;
  G.now += 1;
  const now = G.now;
  if (now >= G.mgrNext) { G.mgrNext += TICK.manager; updateManager(G); if (G.over) return; }
  for (const w of G.waves) if (now >= w.next) { w.next += TICK.spawner; updateSpawner(G, w); }
  if (G.waves.length && G.waves.some(w => w.sent >= w.size)) G.waves = G.waves.filter(w => w.sent < w.size);
  const atk = G.attackers;
  for (let i = 0; i < atk.length; i++) if (!atk[i].dead) updateAttacker(G, atk[i]);
  const tur = G.turrets;
  for (let i = 0; i < tur.length; i++) {
    const t = tur[i];
    if (t.dead) continue;
    if (t.freak) updateFreak(G, t);
    if (now >= t.next) { t.next += t.type === "combonly" && t.combo ? TICK.turret : (t.kind === "Fusion" ? TICK.fusion : (t.type === "combonly" ? TICK.combonlyIdle : TICK.turret)); updateTurret(G, t); }
  }
  const sh = G.shots;
  for (let i = 0; i < sh.length; i++) if (!sh[i].dead) updateShot(G, sh[i]);
  const bl = G.blasts;
  for (let i = 0; i < bl.length; i++) updateBlast(G, bl[i]);
  if (G.winNext !== null && now >= G.winNext) winCheck(G);
  if (G.mods && G.mods.step) G.mods.step(G);
  // compact (cheap: only when something died)
  if (atk.some(a => a.dead)) G.attackers = atk.filter(a => !a.dead);
  if (sh.some(s => s.dead)) G.shots = sh.filter(s => !s.dead);
  if (bl.length && bl.some(b => b.done)) G.blasts = bl.filter(b => !b.done);
  if (tur.some(t => t.dead)) G.turrets = tur.filter(t => !t.dead);
}
function run(G, ms) { for (let i = 0; i < ms && !G.over; i++) step(G); }

// ================================================================ player actions (all validated)
function build(G, pid, kind, x, y) {
  const d = def(G, kind);
  if (!d || G.over || !G.unlocked[kind]) return null;
  if (!canBuildAt(G, kind, x, y, null)) return null;
  if (G.mods && G.mods.canBuild && !G.mods.canBuild(G, pid, kind)) return null;
  if (!cashSpend(G, pid, turretCost(G, pid, kind))) return null;
  const t = makeTurret(G, kind, x, y, pid);
  G.turrets.push(t);
  recalcMods(G);
  if (t.kind === "Red" || t.kind === "Yellow" || t.kind === "Blue" || t.kind === "Green") { /* combo/link lists are computed live */ }
  return t;
}
function owned(G, pid, id) { const t = G.turrets.find(t => t.id === id && !t.dead); return t && (t.owner === pid || G.playerOrder.length === 1) ? t : null; }
function upgrade(G, pid, id, stat, max) {
  const t = owned(G, pid, id);
  if (!t || G.over) return false;
  let any = false;
  do {
    const c = upCost(t, stat);
    if (c === null || !cashSpend(G, pid, c)) break;
    t.lvl[stat]++;
    t.base[stat] = t.up[stat].amount[t.lvl[stat] - 1];
    t.value += c;
    upgradeDone(G, t);
    any = true;
  } while (max);
  return any;
}
function upgradeDone(G, t) {
  if (!t.comboNever && !t.comboCapable && upPct(t, "damage") === 100) { t.comboCapable = true; t.comboNext = G.now; fx(G, { k: "comboready", id: t.id }); }
  modifyUpdate(G, t);
  if (t.type === "modifier") recalcMods(G);
  // onUpgrade
  if (t.kind === "Yellow") {
    t.base.poison = Math.max(1, 10 * (upPct(t, "damage") / 100));
    t.chargeMax = 100 + t.lvl.damage * 10;
    t.chargeRate = 10 + t.lvl.rate * 2;
  }
  if (t.kind === "Red" && t.lvl.range >= 3 && t.lvl.rate >= 3) t.holdingPattern = true;
  if (t.kind === "Fusion") t.feedList = null;
  // freakoutActivate
  if (t.freakCapable) {
    const fl = def(G, t.kind).freakLevel;
    if (t.lvl.damage >= fl.damage && t.lvl.range >= fl.range && t.lvl.rate >= fl.rate) t.freakAvail = true;
  }
}
function sell(G, pid, id) {
  const t = owned(G, pid, id);
  if (!t || G.over) return 0;
  const v = Math.ceil(t.value * (G.mods && G.mods.resale ? G.mods.resale(G, t) : G.D.settings.resale));
  G.players[t.owner].cash += v;
  G.players[t.owner].spent -= v; G.stats.spent -= v;
  if (t.kind === "Red") { const w = acquire(G, t, 720, "weak"); for (const r of t.holding) if (!r.dead) { r.target = w; r.holdingInitially = false; } }
  t.dead = true; t.active = false;
  for (const o of G.turrets) { if (o.joins) o.joins = o.joins.filter(j => j !== t); if (o.bearTo === t) o.bearTo = null; }
  G.turrets = G.turrets.filter(o => o !== t);
  recalcMods(G);
  fx(G, { k: "sell", x: t.x, y: t.y, v });
  return v;
}
function move(G, pid, id, x, y) {
  const t = owned(G, pid, id);
  if (!t || G.over) return false;
  if (!canBuildAt(G, t.kind, x, y, t)) return false;
  if (!cashSpend(G, pid, G.D.settings.moveCost)) return false;
  t.x = x; t.y = y;
  t.minePts = null; t.holePts = null;
  if (t.kind === "Fusion") t.feedList = null;
  recalcMods(G);
  return true;
}
function cycleTargetMode(G, pid, id) {
  const t = owned(G, pid, id); if (!t) return null;
  t.modeNum = (t.modeNum + 1) % MODES.length; t.targetMode = MODES[t.modeNum];
  return MODE_TITLES[t.targetMode];
}
function setTargetMode(G, pid, id, mode) { const t = owned(G, pid, id); if (!t || !MODE_TITLES[mode]) return false; t.targetMode = mode; t.modeNum = MODES.indexOf(mode); return true; }
function toggleLock(G, pid, id) { const t = owned(G, pid, id); if (!t) return null; t.reacquire = !t.reacquire; return t.reacquire ? "Lock Off" : "Lock On"; }
function setDirectional(G, pid, id, deg, spread) {         // spread 0 = off, else 50/30/15
  const t = owned(G, pid, id); if (!t || t.type === "modifier") return false;
  t.dir = spread ? { deg: ((deg + 720) % 360), spread } : null; return true;
}
function focus(G, x, y) {                                   // AttackerFocus: every weapon turret targets it
  const a = acquire(G, { x, y }, 25, "near");
  if (!a) return null;
  for (const t of G.turrets) if (t.type !== "modifier") t.target = a;
  fx(G, { k: "focus", id: a.id });
  return a;
}
function join(G, pid, targeterId, id) {
  const t = owned(G, pid, targeterId), o = G.turrets.find(q => q.id === id && !q.dead);
  if (!t || !o || t.type !== "targeter" || o === t || o.type === "modifier" || o.type === "targeter") return false;
  if (t.joins.indexOf(o) >= 0) return true;
  if (t.joins.length === 3) t.joins.shift();
  t.joins.push(o);
  return true;
}
function combonlyOptions(G, id) {
  const t = G.turrets.find(q => q.id === id && !q.dead);
  if (!t || t.type !== "combonly" || t.combo) return [];
  const c = countColours(G, t, true), n = counts(c), byColour = {};
  for (const r of COMBONLY) if (r[0](n)) byColour[r[1]] = { colour: r[1], combo: r[2], needs: r[3] };
  return COLOURS.filter(k => byColour[k]).map(k => byColour[k]);
}
function combonlyChoose(G, pid, id, colour) {
  const t = owned(G, pid, id);
  if (!t || t.type !== "combonly" || t.combo) return false;
  const opt = combonlyOptions(G, id).find(o => o.colour === colour);
  if (!opt) return false;
  const c = countColours(G, t, true);
  for (const col in opt.needs) if (c[col].length < opt.needs[col]) return false;
  for (const col in opt.needs) {
    for (const o of arrayPick(G, c[col], opt.needs[col])) {
      t.value += o.value; o.active = false; o.dead = true;
      fx(G, { k: "absorb", x1: o.x, y1: o.y, x2: t.x, y2: t.y });
    }
  }
  G.turrets = G.turrets.filter(o => !o.dead);
  t.combo = opt.combo; t.colour = colour; t.armedAt = G.now + 1500; t.next = G.now + TICK.turret;
  recalcMods(G);
  return true;
}
function setPrefs(G, p) {
  if (p.waveSpacing !== undefined) G.waveSpacing = Math.max(1000, p.waveSpacing);
  if (p.waveFollow !== undefined) G.waveFollow = !!p.waveFollow;
}

// ================================================================ export
const API = {
  TICK, MODES, MODE_TITLES, COLOURS, RULES, COMBONLY, TAKES, PLAY, BUILD_SPACING,
  newGame, addPlayer, removePlayer, step, run, waveSend, build, upgrade, sell, move, cycleTargetMode, setTargetMode, toggleLock,
  setDirectional, focus, join, combonlyOptions, combonlyChoose, setPrefs, canBuildAt, turretCost,
  upCost, upMax, upPct, upAmountMax, comboCanFire, countColours, counts, modifyUpdate, recalcMods, rnd, dist, degTo, fwd, spawnBlast, hit, poison,
  acquire, availOrAcquire, inRange, inBoxList, arrayPick, addShot, newRocket, laserNow, sparkNow, bearTowards, canFire, tryFiring, turretFire, muzzle, fx,
  attackerMove, wrap180, modStat, alive, linkFire, comboTake, cashSpend, cashWin,
};
if (typeof module !== "undefined" && module.exports) module.exports = API;
root.OnsEngine = API;
})(typeof window !== "undefined" ? window : globalThis);
