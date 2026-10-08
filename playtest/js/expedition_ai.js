// Peckwood playtest, Phase 6a: Expedition combat, copied from Birb's dungeon enemy runtime (class WT.update), the
// parrot (fI.updateParrot), its tactics (ET), pursuit (QT), formation (YT) and the damage batcher (GT).
// Every enemy type keeps Birb's ranges, frame timings, cooldowns and damage multipliers.
"use strict";
(function () {
  const PT = window.PT, X = PT.EXP, K = X.K;
  const hyp = Math.hypot;

  // ------------------------------------------------------------------ runtime helpers
  const RT = (X.RT = { sepPhase: 0, regenPenalty: 0, pending: null, tactics: new WeakMap(), lanes: new WeakMap(), laneRun: null, laneRefresh: 0, routes: new WeakMap() });
  X.dmgTakenMult = () => 1; // artifacts (6b)
  const dtm = (run) => X.dmgTakenMult(run);
  // Birb GT: enemy hits on the parrot are batched for 0.1 s
  const queue = (p, dmg, stun, cd, fn) => {
    if (!Number.isFinite(dmg) || dmg <= 0 || p.health <= 0) return;
    RT.pending ||= { damage: 0, stunTimer: 0, hitCooldown: 0, onApply: [], timer: 0.1 };
    RT.pending.damage += dmg; RT.pending.stunTimer = Math.max(RT.pending.stunTimer, stun); RT.pending.hitCooldown = Math.max(RT.pending.hitCooldown, cd); if (fn) RT.pending.onApply.push(fn);
  };
  const flush = (run) => {
    const n = RT.pending; RT.pending = null; if (!n) return;
    const p = run.parrot; if (!p || p.health <= 0 || n.damage <= 0) return;
    const was = p.state === "take_damage", fighting = /^attack/.test(p.state);
    p.health = Math.max(0, p.health - n.damage); X.dmgNumber(run, p, "-" + PT.fmt(n.damage), "#fb7185");
    if (p.health > 0) { p.hitCooldown = Math.max(p.hitCooldown ?? 0, n.hitCooldown); if (!fighting) { p.state = "take_damage"; if (!was) { p.animFrame = 0; p.animTimer = 0; p.stunTimer = Math.max(p.stunTimer ?? 0, n.stunTimer); } } }
    RT.regenPenalty = 3; for (const f of n.onApply) f();
  };
  X.queueParrotHit = queue;
  X.dmgNumber = (run, at, text, color) => { if (run.damageNumbers.length < 60) run.damageNumbers.push({ x: at.x, y: at.y - 24, text, color, life: 0.9 }); };
  const ROLE = X.role;
  const anchorY = (e) => { if (e.type === "ice-fire-guardian" && e.isBoss) return 90; /* Birb Go -> Ho.combatAnchorY */ const t = e.type === "harpy" || e.type === "ice-harpy" ? K.HARPY_Y : e.type === "frogfolk-wizard" ? K.WIZARD_Y : e.type === "frogfolk-brute" ? K.BRUTE_Y : e.type === "frogfolk-chieftain" ? K.CHIEFTAIN_Y : 0; return t <= 0 ? 0 : e.isBoss ? Math.round(1.8 * t) : e.isElite ? Math.round(1.4 * t) : t; };
  X.anchor = (e) => ({ x: e.x, y: e.y + anchorY(e) });
  const r2 = (base, min, boss, bossAdd, bossMin) => { const t = Math.max(min, base); return boss ? Math.max(t + bossAdd, bossMin) : t; };
  // Birb getEnemyRetaliationTriggerRange
  X.triggerRange = function (e) {
    const a = e.attackRange, B = e.isBoss;
    switch (e.type) {
      case "elven-assassin": case "zombie-cultist": case "shardsoul-slayer": return B ? 48 : 34;
      case "masked-forest-spirit": return B ? 78 : 45;
      case "flower-monster": return r2(a || 22, 12, B, 6, 28);
      case "harpy": case "ice-harpy": return r2(a || 28, 16, B, 8, 36);
      case "witch": return r2(a || 220, 130, B, 24, 244);
      case "anubis": return r2(a || 280, 180, B, 32, 300);
      case "anubis-warrior": return r2(a || 180, 130, B, 20, 200);
      case "fishfolk-archpriest": return r2(a || 170, 130, B, 20, 190);
      case "cobra": case "ghoul": case "skeleton-warrior": case "mummy": return r2(a || 32, 14, B, 6, 36);
      case "fishfolk-whipe": case "fishfolk-inkbender": return r2(a || 34, 15, B, 7, 38);
      case "fishfolk-brute": return r2(a || 36, 18, B, 8, 44);
      case "fishfolk-horror": return r2(a || 38, 18, B, 8, 46);
      case "fishfolk-pugilist": return r2(a || 34, 16, B, 8, 42);
      case "sea-horror": return r2(a || 34, 16, B, 8, 40);
      case "sea-gramlin": return r2(a || 32, 15, B, 8, 38);
      case "elemental": return r2(a || 38, 18, B, 8, 42);
      case "frost-wisp": case "ghost": return r2(a || 34, 16, B, 8, 40);
      case "doppelganger": return r2(a || 36, 18, B, 8, 42);
      case "black-pudding": return r2(a || 34, 18, B, 8, 42);
      case "giant-black-pudding": return r2(a || 74, 38, B, 18, 88);
      case "hell-critter": return r2(a || 34, 16, B, 8, 42);
      case "cultist": return 20;
      case "cultist-brute": return r2(a || 34, 18, B, 8, 44);
      case "the-archivist": return Math.max(68, a || 68);
      case "imp": return r2(a || 260, 220, B, 30, 290);
      case "cacodaemon": return r2(a || 270, 230, B, 30, 300);
      case "arctic-whisper": return r2(a || 42, 22, B, 10, 48);
      case "frozy-cube": return r2(a || 36, 18, B, 8, 42);
      case "frosty-slime": return r2(a || 68, 32, B, 16, 84);
      case "ice-fire-guardian": return B ? 108 : Math.max(20, a || 40);
      case "frogfolk-wizard": return r2(a || 46, 24, B, 12, 56);
      case "frogfolk-brute": return r2(a || 52, 28, B, 12, 64);
      case "frogfolk-chieftain": return r2(a || 60, 32, B, 14, 74);
      case "twig-blight": { const t = Math.max(16, a || 40); return B ? Math.max(t, 72) : t; }
      case "giant-fly": return 200;
      default: return Math.max(20, a || 40);
    }
  };
  const STRIKE = { "elven-assassin": 28, "zombie-cultist": 28, "shardsoul-slayer": 28, "flower-monster": 21, harpy: 22, "ice-harpy": 22, witch: 58, anubis: 66, "anubis-warrior": 52, "fishfolk-archpriest": 56, cobra: 28, ghoul: 28, "skeleton-warrior": 28,
    "fishfolk-whipe": 30, "fishfolk-brute": 32, "fishfolk-horror": 34, "fishfolk-pugilist": 30, "sea-horror": 30, "sea-gramlin": 28, elemental: 32, "frost-wisp": 30, ghost: 30, doppelganger: 32,
    "black-pudding": 32, "giant-black-pudding": 58, "hell-critter": 28, cultist: 26, "cultist-brute": 30, "the-archivist": 54, imp: 30, cacodaemon: 38, "arctic-whisper": 34, "frozy-cube": 32,
    "frosty-slime": 44, "frogfolk-wizard": 38, "frogfolk-brute": 44, "frogfolk-chieftain": 50, "fishfolk-inkbender": 30, mummy: 28, "masked-forest-spirit": 40, "giant-fly": 44, "twig-blight": 44 };
  // Birb getParrotStrikeDistance
  X.strikeDist = (e) => { let t = STRIKE[e.type] ?? 40; if (e.type === "ice-fire-guardian") t = e.isBoss ? 72 : 36; if (e.isElite) t += 4; if (e.isBoss) t += 16; return Math.max(18, Math.min(t, Math.max(18, X.triggerRange(e) - 2))); };

  // ------------------------------------------------------------------ leash / targeting (Birb isPointInsideParrotLeash, scanForTarget, ET.choose)
  X.rangeMult = () => Math.max(1, (1 + (X.bonuses?.rangeMult || 0) + (X.tempRange ? X.tempRange(X.curState && PT.expState(X.curState).activeRun) : 0)) * (X.bonuses?.sacRadiusMult || 1)); // Birb getEffectiveParrotRangeMultiplier
  const inLeash = (x, y, px, py, pad = 0) => { const l = Math.max(0, K.LEASH * X.rangeMult() + pad); return (x - px) ** 2 + (y - py) ** 2 <= l * l; };
  const DIRS = [{ x: -1, y: 0 }, { x: 1, y: 0 }, { x: -Math.SQRT1_2, y: -Math.SQRT1_2 }, { x: Math.SQRT1_2, y: -Math.SQRT1_2 }, { x: -Math.SQRT1_2, y: Math.SQRT1_2 }, { x: Math.SQRT1_2, y: Math.SQRT1_2 }, { x: 0, y: -1 }, { x: 0, y: 1 }];
  const firstOk = (c, d, ok, pref = DIRS[0]) => { const a = { x: c.x + pref.x * d, y: c.y + pref.y * d }; if (ok(a)) return a; for (const r of DIRS) { const i = { x: c.x + r.x * d, y: c.y + r.y * d }; if (ok(i)) return i; } return null; };
  const strikeOk = (pt, px, py, b) => pt.x >= b.minX && pt.x <= b.maxX && pt.y >= b.minY && pt.y <= b.maxY && inLeash(pt.x, pt.y, px, py);
  X.validTarget = (e) => !!e && e.health > 0 && e.isLeashing !== true && e.type !== "mini-fly" && e.type !== "cultist" && !(e.type === "the-archivist" && e.archivistPhase !== "active") && e.state !== "respawn" && !(e.type === "doppelganger" && e.doppelgangerForm !== "monster");
  const inCircle = (e, px, py, inset = 0) => { const a = X.anchor(e); return inLeash(a.x, a.y, px, py, -inset); };
  const reachable = (e, px, py, b) => firstOk(X.anchor(e), X.strikeDist(e), (pt) => strikeOk(pt, px, py, b)) !== null;
  const tState = (p) => { let t = RT.tactics.get(p); if (!t) RT.tactics.set(p, (t = { target: null, commit: 0, stuck: 0, blocked: new Map() })); return t; };
  const choose = (run, cur, ok, distSq) => {
    const a = run.parrot; if (!a) return null; const r = tState(a); let best = null, bv = Infinity, curV = Infinity, shiny = null, sd = Infinity;
    for (const u of run.enemies) {
      if (r.blocked.has(u.id) || !ok(u)) continue; const e = Math.sqrt(distSq(u));
      if (u.mineralTrackerShiny && e < sd) { shiny = u; sd = e; }
      const h = e - (u.health <= a.damage && e < 180 ? 100 : 0) - (e < 210 && /attack|cast/.test(String(u.state)) ? 45 : 0) - (e < 160 && ROLE(u.type) === "support" ? 25 : 0) - (u.id === cur ? 35 : 0);
      if (u.id === cur) curV = h; if (h < bv) { best = u; bv = h; }
    }
    return shiny ? shiny.id : Number.isFinite(curV) && (r.commit > 0 || bv + 30 >= curV) ? cur : best?.id ?? null;
  };
  const distSqFrom = (x, y) => (e) => { const a = X.anchor(e); return (a.x - x) ** 2 + (a.y - y) ** 2; };
  const canMaintain = (p, e, px, py, b) => inCircle(e, px, py) && reachable(e, px, py, b) && (() => { const a = strikeAnchor(p, e, px, py, b); return inLeash(a.x, a.y, px, py); })();
  const scan = (s, run, x, y, px, py, b) => (PT.expState(s).isAutoAttack && inLeash(x, y, px, py, -24) ? choose(run, null, (e) => X.validTarget(e) && inCircle(e, px, py, K.ACQUIRE_INSET) && reachable(e, px, py, b), distSqFrom(x, y)) : null);
  const smarter = (run, x, y, px, py, cur, b) => choose(run, cur, (t) => X.validTarget(t) && (t.id === cur ? canMaintain(run.parrot, t, px, py, b) : inCircle(t, px, py, K.ACQUIRE_INSET) && reachable(t, px, py, b)), distSqFrom(x, y));
  const sideOf = (dx, cur, thr, fb) => (dx <= -thr ? -1 : dx >= thr ? 1 : cur ?? fb);
  const followSide = (p, px) => (p.preferredFollowSide = sideOf(p.x - px, p.preferredFollowSide, 10, p.facingRight ? -1 : 1));
  const strikeSide = (p, ax, px) => (p.preferredStrikeSide = sideOf(Number.isFinite(px) ? px - ax : p.x - ax, p.preferredStrikeSide, Number.isFinite(px) ? 12 : 8, p.preferredFollowSide ?? (p.facingRight ? -1 : 1)));
  function strikeAnchor(p, e, px, py, b) {
    const d = X.strikeDist(e), r = X.anchor(e), st = tState(p);
    if (st.strikeTarget !== e.id) { st.strikeTarget = e.id; st.direction = { x: strikeSide(p, r.x, px), y: 0 }; }
    const o = firstOk(r, d, (pt) => strikeOk(pt, px, py, b), st.direction);
    if (o) { st.direction = { x: (o.x - r.x) / d, y: (o.y - r.y) / d }; p.preferredStrikeSide = o.x < r.x ? -1 : 1; return o; }
    const s = strikeSide(p, r.x); return { x: r.x + s * d, y: r.y };
  }
  const followTarget = (p, px, py, b) => { const i = followSide(p, px) < 0 ? -40 : 40; return { x: Math.max(b.minX, Math.min(b.maxX, px + i)), y: Math.max(b.minY, Math.min(b.maxY, py - 30)) }; };
  const fly = (p, t, stop, v, dt, b) => { const s = t.x - p.x, o = t.y - p.y, l = hyp(s, o), c = Math.min(Math.max(0, v * dt), l - stop); if (c > 0) { p.x = Math.max(b.minX, Math.min(b.maxX, p.x + (s / l) * c)); p.y = Math.max(b.minY, Math.min(b.maxY, p.y + (o / l) * c)); } };
  const tacMove = (p, t, v, dt, b, ok) => {
    const s0 = { x: p.x, y: p.y }, o = Math.min(v * dt, hyp(t.x - p.x, t.y - p.y)); fly(p, t, 3, v, dt, b); if (!ok(p)) { p.x = s0.x; p.y = s0.y; }
    const l = tState(p), c = hyp(p.x - s0.x, p.y - s0.y);
    l.stuck = c < 0.05 * o && hyp(t.x - p.x, t.y - p.y) > 12 ? l.stuck + dt : 0;
    if (l.stuck > 1.5 && p.targetEnemyId) { l.blocked.set(p.targetEnemyId, 2.5); p.targetEnemyId = null; p.manualTargetEnemyId = null; p.state = "idle"; l.stuck = 0; }
  };
  const retarget = (s, run, p, px, py, b) => { p.manualTargetEnemyId = null; p.animFrame = 0; p.animTimer = 0; const a = scan(s, run, p.x, p.y, px, py, b); if (a) { p.targetEnemyId = a; p.state = "attack"; } else { p.state = "return"; p.targetEnemyId = null; } };
  X.byId = (run, id) => (id ? run.enemies.find((e) => e.id === id) : undefined);
  // Birb handleParrotCommand: clicking an enemy arms combat and makes it the manual target
  X.command = function (s, wx, wy, px, py) {
    const run = PT.expState(s).activeRun; if (!run?.parrot || run.parrot.state === "death") return false; const b = X.bounds(s.currentMap);
    const hit = run.enemies.find((e) => { if (!X.validTarget(e)) return false; const a = X.anchor(e), d = e.isBoss ? 60 : 48; return (wx - e.x) ** 2 + (wy - e.y) ** 2 <= d * d || (wx - a.x) ** 2 + (wy - a.y) ** 2 <= d * d; });
    if (!hit || !(inCircle(hit, px, py) && reachable(hit, px, py, b))) return false;
    run.combatArmed = true; run.parrot.targetEnemyId = hit.id; run.parrot.manualTargetEnemyId = hit.id; run.parrot.state = "attack"; return true;
  };

  // ------------------------------------------------------------------ pursuit around walls (Birb QT, A* on a 24 px grid)
  const blockedSeg = (a, t, rects) => {
    const i = t.x - a.x, n = t.y - a.y;
    for (const r of rects) {
      const L = r.left - 10, R = r.right + 10, T = r.top, B = r.bottom + 10;
      if (Math.max(a.x, t.x) <= L || Math.min(a.x, t.x) >= R || Math.max(a.y, t.y) <= T || Math.min(a.y, t.y) >= B) continue;
      const c = Math.abs(i) < 1e-8 ? -Infinity : (L - a.x) / i, d = Math.abs(i) < 1e-8 ? Infinity : (R - a.x) / i, u = Math.abs(n) < 1e-8 ? -Infinity : (T - a.y) / n, h = Math.abs(n) < 1e-8 ? Infinity : (B - a.y) / n;
      if (Math.max(0, Math.min(c, d), Math.min(u, h)) < Math.min(1, Math.max(c, d), Math.max(u, h))) return true;
    }
    return false;
  };
  const clear = (a, t, rects) => !blockedSeg(a, t, rects);
  const advance = (e, t, n) => { const i = hyp(t.x - e.x, t.y - e.y); if (i < 0.01) return false; const a = Math.min(n, i) / i; e.x += (t.x - e.x) * a; e.y += (t.y - e.y) * a; return true; };
  const findRoute = (e, t, n, b, rects) => {
    let s = Math.max(b.minX, Math.min(e.x, t.x) - 120), o = Math.min(b.maxX, Math.max(e.x, t.x) + 120), l = Math.max(b.minY, Math.min(e.y, t.y) - 120), c = Math.min(b.maxY, Math.max(e.y, t.y) + 120);
    for (const g of rects) if (!clear(e, t, [g])) { s = Math.max(b.minX, Math.min(s, g.left - 120)); o = Math.min(b.maxX, Math.max(o, g.right + 120)); l = Math.max(b.minY, Math.min(l, g.top - 120)); c = Math.min(b.maxY, Math.max(c, g.bottom + 120)); }
    const d = rects.filter((r) => r.right + 10 >= s && r.left - 10 <= o && r.bottom + 10 >= l && r.top <= c);
    const start = { x: e.x, y: e.y, key: "0,0", cost: 0, estimate: hyp(t.x - e.x, t.y - e.y) }, open = [start], best = new Map([["0,0", 0]]), done = new Set();
    for (let g = 0; open.length && g < 768; g++) {
      let bi = 0; for (let k = 1; k < open.length; k++) if (open[k].estimate < open[bi].estimate) bi = k;
      const a = open.splice(bi, 1)[0]; if (done.has(a.key)) continue; done.add(a.key);
      const u = hyp(t.x - a.x, t.y - a.y), gp = u > n ? { x: t.x - ((t.x - a.x) / u) * n, y: t.y - ((t.y - a.y) / u) * n } : a;
      if (u <= n || (u <= n + 36 && clear(a, gp, d))) { const path = u > n ? [gp] : []; for (let q = a; q?.parent; q = q.parent) path.push({ x: q.x, y: q.y }); return path.reverse(); }
      for (let fx = -1; fx <= 1; fx++) for (let fy = -1; fy <= 1; fy++) {
        if (!fx && !fy) continue; const q = { x: a.x + fx * 24, y: a.y + fy * 24 }; if (q.x < s || q.x > o || q.y < l || q.y > c) continue;
        const key = `${Math.round((q.x - e.x) / 24)},${Math.round((q.y - e.y) / 24)}`, cost = a.cost + hyp(fx, fy) * 24;
        if (done.has(key) || cost >= (best.get(key) ?? Infinity) || !clear(a, q, d)) continue;
        best.set(key, cost); open.push({ ...q, key, cost, estimate: cost + Math.max(0, hyp(t.x - q.x, t.y - q.y) - n), parent: a });
      }
    }
    return [];
  };
  const pursue = (e, t, stop, v, dt, b, rects) => {
    const l = Math.max(0, v * dt); if (l <= 0) return false;
    const u = hyp(t.x - e.x, t.y - e.y); if (u <= stop) return false;
    const h = { x: t.x - ((t.x - e.x) / u) * stop, y: t.y - ((t.y - e.y) / u) * stop };
    if (clear(e, h, rects)) { RT.routes.delete(e); return advance(e, h, l); }
    let c = RT.routes.get(e); if (c) c.retryAfter = Math.max(0, c.retryAfter - dt);
    const far = !c || hyp(c.target.x - t.x, c.target.y - t.y) > 24, m = c?.points[0], bad = !!m && !clear(e, m, rects);
    if (!c || (c.retryAfter <= 0 && (far || bad || !m))) { c = { target: { ...t }, retryAfter: 0.4, points: findRoute(e, t, stop, b, rects) }; RT.routes.set(e, c); }
    let f = l, moved = false;
    while (f > 0 && c.points.length) { const q = c.points[0]; if (!clear(e, q, rects)) break; const n = Math.min(f, hyp(q.x - e.x, q.y - e.y)); moved = advance(e, q, n) || moved; f -= n; if (!(hyp(q.x - e.x, q.y - e.y) < 0.01)) break; c.points.shift(); }
    return moved;
  };
  // Birb YT: up to 8 front-line enemies near the parrot take lanes around it
  const updateLanes = (run, dt) => {
    RT.laneRefresh -= dt; if (RT.laneRun === run && RT.laneRefresh > 0) return; RT.laneRun = run; RT.laneRefresh = 0.4;
    const p = run.parrot; if (!p || p.health <= 0) return;
    const near = run.enemies.filter((e) => e.health > 0 && !e.isBoss && !e.projectileKind && ROLE(e.type) === "front" && hyp(e.x - p.x, e.y - p.y) < 240).sort((a, b) => hyp(a.x - p.x, a.y - p.y) - hyp(b.x - p.x, b.y - p.y)).slice(0, 8), used = new Set();
    for (const r of near) {
      const ang = Math.atan2(r.y - p.y, r.x - p.x); let t = RT.lanes.get(r);
      if (t === undefined || used.has(t)) { let best = Infinity; for (let i = 0; i < 8; i++) { if (used.has(i)) continue; const d = Math.abs(Math.atan2(Math.sin((i * Math.PI) / 4 - ang), Math.cos((i * Math.PI) / 4 - ang))); if (d < best) { best = d; t = i; } } }
      if (t !== undefined) { used.add(t); RT.lanes.set(r, t); }
    }
  };
  const laneTarget = (e, p, range, yo) => { const a = RT.lanes.get(e); if (e.isBoss || a === undefined || hyp(e.x - p.x, e.y + yo - p.y) > 240) return { x: p.x, y: p.y - yo, stop: range - 2 }; const r = Math.max(10, range - 8); return { x: p.x + Math.cos((a * Math.PI) / 4) * r, y: p.y + Math.sin((a * Math.PI) / 4) * r - yo, stop: 2 }; };
  const sepRadius = (e, p, range, yo, base) => (!p || ROLE(e.type) !== "front" || hyp(e.x - p.x, e.y + yo - p.y) > range + base ? base : Math.min(base, Math.max(12, 0.5 * range)));

  // ------------------------------------------------------------------ spawns used in combat (mini flies, mummies, fireballs, ankhs)
  const miniCount = (run, pid) => run.enemies.reduce((n, e) => (e && e.health > 0 && e.type === "mini-fly" && !e.projectileKind && String(e.miniFlyParentId || e.leaderId || "") === pid ? n + 1 : n), 0);
  const canFlyAttack = (run, e) => miniCount(run, String(e.id)) <= K.MINI_FLY_READY;
  let pid = 1;
  const projectile = (o) => Object.assign({ id: "proj_" + pid++, type: "mini-fly", defense: 0, xpReward: 0, skillPointReward: 0, attackCooldown: 0, hitFlash: 0, animFrame: 0, animTimer: 0, state: "idle", roamTimer: 0, isBoss: false }, o);
  const spawnMiniFlies = (s, run, e, mapId) => {
    const b = X.bounds(mapId), id = String(e.id), n = Math.min(2, Math.max(0, K.MINI_FLY_MAX_PER_PARENT - miniCount(run, id))); let made = 0;
    for (let l = 0; l < n; l++) { const x = Math.max(b.minX, Math.min(b.maxX, e.x + 20 * (Math.random() - 0.5))), y = Math.max(b.minY, Math.min(b.maxY, e.y + 20 * (Math.random() - 0.5)));
      run.enemies.push(projectile({ x, y, targetX: e.x, targetY: e.y, speed: K.MINI_FLY_BASE, health: 10, maxHealth: 10, attack: Math.floor(0.5 * e.attack), attackRange: 10, facingRight: Math.random() > 0.5, originalX: x, originalY: y, leaderId: id, miniFlyParentId: id, groupCenterX: e.x, groupCenterY: e.y })); made++; }
    return made;
  };
  const summonCount = (run, id) => run.enemies.reduce((n, e) => (e.health > 0 && e.type !== "mini-fly" && e.anubisSummon && String(e.anubisLeaderId || "") === id ? n + 1 : n), 0);
  const spawnMummies = (s, run, e, mapId) => {
    const id = String(e.id); if (summonCount(run, id) >= K.ANUBIS_SUMMONS) return 0;
    const floor = X.MAP_FLOOR[mapId], b = X.bounds(mapId), st = X.enemyStats("mummy", floor, false); if (!st) return 0; let made = 0;
    for (let c = 0; c < 3 && summonCount(run, id) < K.ANUBIS_SUMMONS; c++) {
      const a = [{ x: -112, y: 78 }, { x: 0, y: 94 }, { x: 112, y: 78 }][c], d = a.x < 0 ? -1 : 1;
      for (let o = 0; o < 10; o++) {
        const g = X.safeFreePoint(run, mapId, e.x + a.x + d * 6 * o + 10 * (Math.random() - 0.5), e.y + a.y + 10 * (Math.random() - 0.5), b, { minDistance: K.SPAWN_MIN }); if (!g) continue;
        const f = X.createEnemy(s, run, "mummy", g.x, g.y, st, mapId); Object.assign(f, { xpReward: 0, skillPointReward: 0, attackCooldown: 0.35 + 0.25 * Math.random(), groupCenterX: e.x, groupCenterY: e.y, leaderId: e.id, anubisSummon: true, anubisLeaderId: id });
        run.enemies.push(f); made++; break;
      }
    }
    return made;
  };
  const wallHit = (mapId, x0, y0, x1, y1, pad = 6) => {
    const s = x1 - x0, o = y1 - y0; let best = Infinity;
    for (const c of X.collisions(mapId)) {
      let u = 0, h = 1; const axis = (p, d, lo, hi) => { if (Math.abs(d) <= 1e-8) return p >= lo && p <= hi; const a = 1 / d; let r = (lo - p) * a, t = (hi - p) * a; if (r > t) [r, t] = [t, r]; u = Math.max(u, r); h = Math.min(h, t); return u <= h; };
      if (axis(x0, s, c.left - pad, c.right + pad) && axis(y0, o, c.top - pad, c.bottom + pad) && u >= 0 && u <= 1) best = Math.min(best, u);
    }
    return Number.isFinite(best) ? { x: x0 + s * best, y: y0 + o * best, t: best } : null;
  };
  const spawnFireball = (run, e, p, mapId) => {
    const b = X.bounds(mapId), dir = e.facingRight ? 1 : -1, l = X.safePoint(mapId, e.x + 18 * dir, e.y - 10, b); if (!l) return;
    const c = p.x - l.x, d = p.y - l.y, u = hyp(c, d) || 1, h = c / u, q = d / u, side = Math.random() < 0.25 ? (42 + 34 * Math.random()) * (Math.random() < 0.5 ? -1 : 1) : 0;
    const tx = p.x - q * side, ty = p.y + h * side, A = tx - l.x, v = ty - l.y, x = hyp(A, v) || 1, w = (A / x) * 380, M = (v / x) * 380;
    run.enemies.push(projectile({ x: l.x, y: l.y, targetX: tx, targetY: ty, speed: 380, health: 1, maxHealth: 1, attack: Math.max(1, Math.round(0.85 * e.attack)), attackRange: 14, facingRight: w >= 0, originalX: l.x, originalY: l.y,
      groupCenterX: e.x, groupCenterY: e.y, projectileKind: "imp-fireball", projectilePhase: "appear", projectilePhaseTimer: 0.18, projectileLifetime: 2.2, projectileVelocityX: w, projectileVelocityY: M, projectileSpawnX: l.x, projectileSpawnY: l.y, projectileMaxRange: 380 }));
  };
  const spawnAnkh = (run, e, p, side, mapId) => {
    const b = X.bounds(mapId), c = X.safeFreePoint(run, mapId, e.x + (side === "left" ? -34 : 34), e.y - 18, b, { minDistance: K.MINI_FLY_SPAWN_MIN }); if (!c) return;
    const d = p.x - c.x, u = p.y - c.y, h = hyp(d, u) || 1, m = (d / h) * 260, g = (u / h) * 260;
    run.enemies.push(projectile({ x: c.x, y: c.y, targetX: p.x, targetY: p.y, speed: 260, health: 1, maxHealth: 1, attack: Math.max(1, Math.round(0.95 * e.attack)), attackRange: 18, facingRight: m >= 0, originalX: c.x, originalY: c.y,
      groupCenterX: e.x, groupCenterY: e.y, projectileKind: "ankh", ankhPhase: "appear", ankhPhaseTimer: 0.9, ankhHitTimer: 0, ankhLifetime: 3.5, ankhVelocityX: m, ankhVelocityY: g, ankhSpawnX: c.x, ankhSpawnY: c.y, ankhMaxRange: Math.max(280, (e.attackRange || 280) + 90) }));
  };
  const healTargets = (run, t, range) => {
    const cap = t.isBoss ? 4 : 3, rr = Math.max(1, range) ** 2, r = [];
    for (const e of run.enemies) { if (!e || e.id === t.id || e.health <= 0 || e.type === "mini-fly") continue; const miss = Math.max(0, e.maxHealth - e.health); if (miss < 1) continue; const d = (e.x - t.x) ** 2 + (e.y - t.y) ** 2; if (d <= rr) r.push({ e, miss, d }); }
    return r.sort((a, b) => (Math.abs(a.miss - b.miss) > 1e-4 ? b.miss - a.miss : a.d - b.d)).slice(0, cap).map((x) => x.e);
  };
  const moveHome = (e, dt, b, base) => {
    const c = Number.isFinite(+e.originalX) ? +e.originalX : Number.isFinite(+e.groupCenterX) ? +e.groupCenterX : e.x, d = Number.isFinite(+e.originalY) ? +e.originalY : Number.isFinite(+e.groupCenterY) ? +e.groupCenterY : e.y;
    const u = c - e.x, h = d - e.y, p = hyp(u, h);
    if (p <= 3) { e.x = Math.max(b.minX, Math.min(b.maxX, c)); e.y = Math.max(b.minY, Math.min(b.maxY, d)); Object.assign(e, { targetX: c, targetY: d, state: "idle", animFrame: 0, animTimer: 0, attackDamageApplied: false }); return false; }
    const f = Math.min(p, 1.1 * Math.max(1, +e.speed || base) * Math.max(0, dt));
    e.state = "move"; e.x = Math.max(b.minX, Math.min(b.maxX, e.x + (u / p) * f)); e.y = Math.max(b.minY, Math.min(b.maxY, e.y + (h / p) * f));
    Object.assign(e, { targetX: c, targetY: d, facingRight: u > 0, animFrame: 0, animTimer: 0, attackDamageApplied: false }); return true;
  };
  const cobraVenom = (p, dmg) => { if (dmg <= 0) return; p.poisonTicksRemaining = K.COBRA_TICKS; p.poisonTickTimer = K.COBRA_TICK; p.poisonDamagePerTick = Math.max(dmg, Math.max(0, +p.poisonDamagePerTick || 0)); };
  const bossLeash = (s, e, p, dt, b) => {
    if (!e.isLeashing) {
      if (!e.isBoss || e.health <= 0) return false;
      const n = X.respawnPos(e), r = X.triggerRange(e), lim = Math.max(420, 2.25 * r); let start = (e.x - n.x) ** 2 + (e.y - n.y) ** 2 > lim * lim;
      if (!start && e.health < e.maxHealth) { if (!p || p.health <= 0) start = true; else if (!(p.targetEnemyId === e.id && /^attack/.test(p.state))) { const a = X.anchor(e), d = Math.max(180, 1.75 * r); start = (p.x - a.x) ** 2 + (p.y - a.y) ** 2 > d * d; } }
      if (!start) return false;
      e.isLeashing = true; if (X.onEnemyRespawn && X.curState) X.onEnemyRespawn(PT.expState(X.curState).activeRun, e); e.archivistSpells = undefined; e.health = e.maxHealth; e.hitFlash = 0; e.stunTimer = 0; e.attackCooldown = 0; e.attackDamageApplied = false;
    }
    if (!moveHome(e, dt, b, 62)) X.applyRespawnedState(e);
    return true;
  };
  const clampB = (e, b) => { e.x = Math.max(b.minX, Math.min(b.maxX, e.x)); e.y = Math.max(b.minY, Math.min(b.maxY, e.y)); };

  // ------------------------------------------------------------------ kills and boss rewards (Birb WT.update death branch + grantBossKillRewards)
  X.onKill = (s, run, e) => {}; // loot, quests (6b / 6c)
  const grantSp = (s, run, e) => { // Birb grantParrotSkillPoints (artifact multipliers in 6b)
    const a = e.isShiny ? 10 * (PT.hasSun(s, "d_desert_golden_emblem") ? 2 : 1) : 1, r = Math.max(0, Math.floor(+e.skillPointReward || 0)) * a; if (r <= 0) return;
    const c = 1 + (X.bonuses?.skillPointMult || 0), d = 1 + (X.externalBonuses(s).skillPointMult || 0), h = r * X.spKillMult(s, run) * c * d + Math.max(0, +run.skillPointFractionCarry || 0), p = Math.max(0, Math.floor(h + 1e-6));
    run.skillPointFractionCarry = Math.max(0, h - p); if (p <= 0) return;
    X.grantSkillPoints(s, p); run.spGained = (run.spGained || 0) + p; X.dmgNumber(run, e, "+" + PT.fmt(p) + " SP", "#f1c40f");
  };
  X.spKillMult = (s) => (X.sacSpMult ? X.sacSpMult(s) : 1); // artifact roll (6b) x common sacrifice multiplier
  const bossKill = (s, run, e, mapId) => {
    if (e.xpGranted) return;
    X.onKill(s, run, e, true); X.tryLegendaryKey(s, run, e); grantSp(s, run, e); run.enemiesDefeated++; e.xpGranted = true;
    X.trackQuestKill(s, run, run.currentFloor, e, mapId || s.currentMap);
    if (e.type !== "the-archivist") { e.respawnTimer = X.effectiveRespawn(s, K.BOSS_RESPAWN); X.setCooldown(s, e, e.respawnTimer); }
    if (e.type === "anubis") { run.enemies = run.enemies.filter((m) => !(m.anubisSummon && String(m.anubisLeaderId || "") === String(e.id))); Object.assign(e, { anubisAction: "", anubisActionApplied: false, anubisCoffinPhase: "", anubisCoffinFrame: 0, anubisCoffinSpawned: false }); }
    X.dmgNumber(run, e, "BOSS DOWN", "#f59e0b");
  };
  X.finalizeArchivist = (s, e) => { const run = PT.expState(s).activeRun; if (!run || e.type !== "the-archivist" || e.health > 0 || e.xpGranted) return; bossKill(s, run, e); e.respawnTimer = undefined; X.clearCooldown(s, e); PT.expState(s).archivistDefeated = true; };
  // Birb tryAwardLegendaryKeyFromFloor2WitchBoss: the floor 2 witch boss drops the Legendary Key once
  X.tryLegendaryKey = (s, run, e) => {
    if (!e.isBoss || run.currentFloor !== 2 || e.type !== "witch") return;
    if (PT.parrotState(s).strangeKeys > 0 || s.hasUnlockedDesertMap || PT.hasSun(s, "d_unlock_desert_tree")) return;
    PT.parrotState(s).strangeKeys = 1; X.dmgNumber(run, e, "LEGENDARY KEY ACQUIRED!", "#facc15");
  };
  const trackKill = (s, run, e) => X.trackQuestKill(s, run, run.currentFloor, e, s.currentMap); // quests.js
  X.trackQuestKill = () => {};

  // ------------------------------------------------------------------ enemy runtime (Birb WT.update)
  const GENERIC = new Set(["elven-assassin", "zombie-cultist", "shardsoul-slayer", "cobra", "ghoul", "skeleton-warrior", "mummy", "fishfolk-whipe", "fishfolk-inkbender", "fishfolk-brute", "fishfolk-horror", "fishfolk-pugilist", "sea-horror", "sea-gramlin", "elemental", "frost-wisp", "ghost",
    "doppelganger", "black-pudding", "giant-black-pudding", "hell-critter", "cultist-brute", "the-archivist", "arctic-whisper", "frozy-cube", "frosty-slime", "ice-fire-guardian", "frogfolk-wizard", "frogfolk-brute", "frogfolk-chieftain"]);
  const HIT_FRAME = { "elven-assassin": 1, "zombie-cultist": 4, "shardsoul-slayer": 3, "skeleton-warrior": 4, mummy: 3, "fishfolk-whipe": 4, "fishfolk-inkbender": 8, "sea-horror": 4, "sea-gramlin": 4, "frost-wisp": 4, ghost: 4, doppelganger: 4, "black-pudding": 4, "giant-black-pudding": 8,
    "hell-critter": 3, "cultist-brute": 3, "arctic-whisper": 5, "frozy-cube": 4, "frosty-slime": 10, "ice-fire-guardian": 4, "frogfolk-wizard": 4, "frogfolk-brute": 4, "frogfolk-chieftain": 4, "fishfolk-brute": 4, "fishfolk-horror": 4 };
  const END_FRAME = { "elven-assassin": 6, "zombie-cultist": 8, "shardsoul-slayer": 5, "skeleton-warrior": 10, mummy: 6, "fishfolk-whipe": 7, "fishfolk-inkbender": 16, "sea-horror": 8, "sea-gramlin": 8, elemental: 8, "frost-wisp": 8, ghost: 8, doppelganger: 8, "black-pudding": 8,
    "giant-black-pudding": 16, "hell-critter": 5, "cultist-brute": 6, "the-archivist": 12, "arctic-whisper": 8, "frozy-cube": 8, "frosty-slime": 16, "ice-fire-guardian": 6, "frogfolk-wizard": 8, "frogfolk-brute": 8, "frogfolk-chieftain": 8, "fishfolk-brute": 8, "fishfolk-horror": 8 };
  const COOLDOWN = { "fishfolk-inkbender": 1.6, "sea-horror": 1.3, "sea-gramlin": 1.15, "frost-wisp": 1, ghost: 1.15, doppelganger: 1.2, "black-pudding": 1.25, "giant-black-pudding": 2.2, "hell-critter": 1.05, "cultist-brute": 1.25,
    "arctic-whisper": 1.35, "frozy-cube": 1.2, "frosty-slime": 2.6, "ice-fire-guardian": 1.55, "frogfolk-wizard": 1.45, "frogfolk-brute": 1.8, "frogfolk-chieftain": 2, "fishfolk-brute": 1.8, "fishfolk-horror": 1.8 };
  X.updateEnemies = function (s, run, dt, px, py) {
    const mapId = s.currentMap, floor = run.currentFloor, a = dt * K.COMBAT_FEEL, b = X.bounds(mapId), { minX: o, maxX: l, minY: c, maxY: d } = b, u = run.enemies, rects = X.collisions(mapId);
    X.reconcileBoss(s, run, mapId, floor);
    const h = run.parrot && run.parrot.health > 0 ? run.parrot : null;
    updateLanes(run, dt);
    const g = u.length > 28 ? 4 : 3, f = u.length <= 18 || !(1 & RT.sepPhase++);
    if (RT.pending && RT.pending.timer <= 0) flush(run);
    let prune = false;
    for (let v = 0; v < u.length; v++) {
      const r = u[v];
      if (r.leaderId) { const ld = u.find((e) => e.id === r.leaderId); if (ld && ld.health > 0) { r.groupCenterX = ld.x; r.groupCenterY = ld.y; } }
      const M = (r.x - px) ** 2 + (r.y - py) ** 2, S = h ? (r.x - h.x) ** 2 + (r.y - h.y) ** 2 : Infinity, C = r.isBoss || r.type === "mini-fly" || M < 81e4 || S < 81e4;
      if (r.hitFlash > 0) r.hitFlash -= a;
      const E = String(r.state || ""), sepOk = r.health > 0 && E !== "death" && !/attack|cast/.test(E) && !(r.type === "cultist" && (E === "ritual" || E === "sacrifice")) && r.type !== "mini-fly";
      if (f && C && sepOk && (M < 722500 || S < 722500 || r.isBoss)) { // separation (Birb quadtree query)
        const base = r.groupId ? 52 * K.GROUP_SPACING : 50, an = X.anchor(r), rad = sepRadius(r, h, X.triggerRange(r), an.y - r.y, base); let ox = 0, oy = 0, cnt = 0;
        for (const e of u) {
          if (e === r || e.health <= 0 || e.state === "death" || e.type === "mini-fly" || Math.abs(e.x - r.x) > rad || Math.abs(e.y - r.y) > rad) continue;
          const tx = r.x - e.x, ty = r.y - e.y, dd = tx * tx + ty * ty;
          if (dd <= 1e-6) { const ang = (0.73 * v + 1.37 * cnt + 0.19 * RT.sepPhase) % (2 * Math.PI); ox += Math.cos(ang); oy += Math.sin(ang); cnt++; continue; }
          if (dd < rad * rad) { const e2 = Math.sqrt(dd), k = (rad - e2) / rad; ox += (tx / e2) * k; oy += (ty / e2) * k; cnt++; }
        }
        if (cnt > 0) { const t = 175 * dt; r.x += (ox / cnt) * t; r.y += (oy / cnt) * t; }
      }
      if (r.health <= 0) {
        if (X.onEnemyRespawn) X.onEnemyRespawn(run, r); // Birb: drop the opening strike mark and focus on a dead enemy
        if (r.isBoss) {
          bossKill(s, run, r, mapId);
          if (r.type === "the-archivist") { r.respawnTimer = undefined; X.clearCooldown(s, r); PT.expState(s).archivistDefeated = true; continue; }
          const t = X.advanceRespawn(s, r, dt);
          if (t !== null && t <= 0) {
            const e = X.respawnPos(r), sp = X.safePoint(mapId, e.x, e.y, b); if (!sp) { X.setRetry(s, r, 2); continue; }
            X.rerollShinyOnRespawn(s, r, mapId, floor); Object.assign(r, { health: r.maxHealth, x: sp.x, y: sp.y, respawnTimer: undefined, xpGranted: false, spawnedDeadFromCooldown: false });
            X.clearCooldown(s, r); X.applyRespawnedState(r);
            if (r.type === "anubis") Object.assign(r, { anubisAction: "", anubisActionApplied: false, anubisAnkhCooldown: 1.6, anubisCoffinCooldown: 6.8, anubisCoffinPhase: "", anubisCoffinFrame: 0, anubisCoffinSpawned: false });
            X.dmgNumber(run, r, "BOSS RESPAWNED", "#ef4444");
          }
          continue;
        }
        if (r.type === "cultist") { if (r.cultistSacrificeApplied !== true) prune = true; continue; }
        if (r.type === "mini-fly" || r.anubisSummon) { prune = true; continue; }
        if (r.respawnTimer === undefined) {
          X.onKill(s, run, r, false); grantSp(s, run, r); trackKill(s, run, r); run.enemiesDefeated++;
          r.respawnTimer = X.effectiveRespawn(s, r.isElite ? K.ELITE_RESPAWN : X.respawnVariance(10)); if (r.isElite) X.setCooldown(s, r, r.respawnTimer); r.xpGranted = true;
        } else {
          const t = X.advanceRespawn(s, r, dt);
          if (t !== null && t <= 0) {
            const e = X.respawnPos(r), sp = X.safePoint(mapId, e.x, e.y, b); if (!sp) { X.setRetry(s, r, 1); continue; }
            X.rerollShinyOnRespawn(s, r, mapId, floor); Object.assign(r, { health: r.maxHealth, x: sp.x, y: sp.y, respawnTimer: undefined, xpGranted: false, spawnedDeadFromCooldown: false }); X.clearCooldown(s, r); X.applyRespawnedState(r);
          }
        }
        continue;
      }
      if (bossLeash(s, r, h, dt, b)) continue;
      if (X.nightPreAI && X.nightPreAI(s, run, r, dt)) continue; // expedition_night.js (Birb LT / qT)
      if (r.type === "the-archivist" && archivistSpells(s, run, r, dt)) continue;
      if (!C) { r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a); if ((v + RT.sepPhase) % g !== 0) continue; }
      enemyAI(s, run, r, dt, a, px, py, h, b, rects, mapId, u, () => (prune = true));
      clampB(r, b);
    }
    if (prune) run.enemies = run.enemies.filter((e) => !((e.type === "mini-fly" || (e.type === "cultist" && e.cultistSacrificeApplied !== true) || e.anubisSummon) && e.health <= 0));
    if (RT.pending) { RT.pending.timer -= dt; if (RT.pending.timer <= 0) flush(run); }
    if (u.length <= 24 || !(3 & RT.sepPhase)) resolveOverlaps(run, b);
    X.syncExitPortal(run, mapId);
  };
  const resolveOverlaps = (run, b) => {
    const o = run.enemies, sep = (e) => (e.type === "mini-fly" ? K.MINI_FLY_SEP : e.isBoss ? Math.max(30, K.SEP + 6) : K.SEP);
    for (let i = 0; i < o.length; i++) {
      const t = o[i]; if (!t || t.health <= 0 || t.state === "death" || t.type === "mini-fly") continue;
      for (let n = i + 1; n < o.length; n++) {
        const q = o[n]; if (!q || q.health <= 0 || q.state === "death" || q.type === "mini-fly") continue;
        const aa = Math.max(sep(t), sep(q)), lx = q.x - t.x, cy = q.y - t.y, dd = lx * lx + cy * cy; if (dd >= aa * aa) continue;
        let ux = 0, uy = 0, p = 0; if (dd <= 1e-6) { const ang = (0.61 * i + 1.17 * n + 0.23 * RT.sepPhase) % (2 * Math.PI); ux = Math.cos(ang); uy = Math.sin(ang); } else { p = Math.sqrt(dd); ux = lx / p; uy = cy / p; }
        const m = aa - p; if (m <= 0) continue; const g = 0.5 * Math.max(0.5, 0.55 * m); t.x -= ux * g; t.y -= uy * g; q.x += ux * g; q.y += uy * g;
      }
    }
    for (const e of o) if (e && e.health > 0 && e.state !== "death") clampB(e, b);
  };
  // Birb UT: the Archivist's chains / seals spells once active
  const archivistSpells = (s, run, n, dt) => {
    const A = K.ARCH; if (n.archivistPhase !== "active") { n.archivistSpells = undefined; return false; }
    const p = run.parrot; if (!p || p.health <= 0) { if (n.archivistSpells?.spell) { n.state = "idle"; n.animFrame = n.animTimer = 0; } n.archivistSpells = undefined; return false; }
    const r = (n.archivistSpells ??= { spell: null, elapsed: 0, cooldown: A.firstCastDelay, sequence: 0, enraged: false, enrageAge: 0, marks: [] }), st = Math.min(0.1, Math.max(0, dt));
    if (r.enraged) r.enrageAge += st; else if (n.health / Math.max(1, n.maxHealth) <= A.enrageHealthRatio) { r.enraged = true; r.enrageAge = 0; r.cooldown = Math.min(r.cooldown, 0.8); }
    if (r.spell) r.elapsed += st;
    else {
      r.cooldown = Math.max(0, r.cooldown - st); const t = X.anchor(n), b = X.bounds(s.currentMap);
      if (r.cooldown > 0 || n.state === "attack" || (n.stunTimer || 0) > 0 || hyp(p.x - t.x, p.y - t.y) > A.castRange || !(inCircle(n, s.player.x, s.player.y) && reachable(n, s.player.x, s.player.y, b))) return false;
      r.spell = r.sequence++ % 2 === 0 ? "chains" : "seals"; r.elapsed = 0;
      const offs = r.spell === "chains" ? [[0, 0]] : r.enraged ? [[0, 0], [-100, 20], [100, -20], [0, -110]] : [[0, 0], [-100, 20], [100, -20]];
      r.marks = offs.map(([ex, ey], k) => ({ x: Math.max(b.minX, Math.min(b.maxX, p.x + ex)), y: Math.max(b.minY, Math.min(b.maxY, p.y + ey)), hitAt: r.spell === "chains" ? A.chainWindup + A.chainTravel : A.sealWindup + k * A.sealInterval, resolved: false }));
      n.archivistAttackMode = "attack2"; n.facingRight = p.x >= t.x; n.animFrame = n.animTimer = 0; n.attackDamageApplied = false;
    }
    n.state = "attack"; n.targetX = n.x; n.targetY = n.y; n.stunTimer = 0;
    const rad = r.spell === "chains" ? A.chainRadius : A.sealRadius;
    for (const m of r.marks) { if (m.resolved || r.elapsed < m.hitAt) continue; m.resolved = true; if (hyp(p.x - m.x, p.y - m.y) > rad) continue; queue(p, n.attack * (r.spell === "chains" ? A.chainDamage : A.sealDamage) * dtm(run), 0.12, 0.4); n.attackDamageApplied = true; }
    if (r.elapsed >= r.marks[r.marks.length - 1].hitAt + A.recovery) { r.spell = null; r.marks = []; r.cooldown = r.enraged ? A.enragedCooldown : A.cooldown; n.state = "idle"; n.animFrame = n.animTimer = 0; n.attackCooldown = 0.8; }
    return true;
  };
  const stunned = (r, a, allowAttack) => { if (r.stunTimer && r.stunTimer > 0) { r.stunTimer -= a; if (r.stunTimer > 0 && !(allowAttack && allowAttack(r.state))) return true; } return false; };
  const goHome = (r, sx, sy, m, dt, mult, base, extra) => { const t = m || 1, n = mult * (r.speed || base); r.state = "move"; r.x += ((sx - r.x) / t) * n * dt; r.y += ((sy - r.y) / t) * n * dt; r.facingRight = sx - r.x > 0; r.animFrame = 0; r.animTimer = 0; r.attackDamageApplied = false; if (extra) extra(); };
  const kite = (r, t, n, i, a, mid, lo, dt, fwd, back, base) => { const d = Math.sqrt(a) || 1; if (d > mid) { const v = fwd * (r.speed || base); r.state = "move"; r.x += (n / d) * v * dt; r.y += (i / d) * v * dt; r.facingRight = n > 0; } else if (d < lo) { const v = back * (r.speed || base); r.state = "move"; r.x -= (n / d) * v * dt; r.y -= (i / d) * v * dt; r.facingRight = n > 0; } else r.state = "idle"; };
  function enemyAI(s, run, r, dt, a, px, py, h, b, rects, mapId, u, markPrune) {
    const e = dt, i = run, t = i.parrot, alive = !!(t && t.health > 0);
    if (r.type === "the-archivist" && r.archivistPhase !== "active") {
      const ph = r.archivistPhase || "dormant";
      if (ph === "dormant") { r.state = "idle"; r.attackCooldown = 0; if (h && ((h.x - r.x) ** 2 + (h.y - r.y) ** 2 <= 67600 || (inCircle(r, px, py) && reachable(r, px, py, b)))) { r.archivistPhase = "sacrificing"; r.archivistSacrificesReceived = 0; for (const c of u) if (c.type === "cultist" && c.cultistArchivistId === r.id && c.health > 0) Object.assign(c, { state: "sacrifice", cultistSacrificeTimer: K.CULT_SACRIFICE, cultistSacrificeApplied: false, animFrame: 0, animTimer: 0 }); } }
      else if (ph === "sacrificing") { r.state = "idle"; if (!u.some((c) => c.type === "cultist" && c.cultistArchivistId === r.id && c.health > 0)) Object.assign(r, { archivistPhase: "transforming", archivistTransformationTimer: K.ARCH_TRANSFORM, state: "transform", animFrame: 0, animTimer: 0 }); }
      else if (ph === "transforming") { r.state = "transform"; r.archivistTransformationTimer = Math.max(0, (+r.archivistTransformationTimer || 0) - a); if (r.archivistTransformationTimer <= 0) Object.assign(r, { archivistPhase: "active", state: "idle", attackCooldown: 0.45, animFrame: 0, animTimer: 0 }); }
      return;
    }
    if (r.type === "cultist") {
      const n = u.find((x) => x.id === (r.cultistArchivistId || r.leaderId));
      if (!n || n.type !== "the-archivist" || n.health <= 0) { r.health = 0; markPrune(); return; }
      r.groupCenterX = n.x; r.groupCenterY = n.y;
      if (r.state === "sacrifice") { r.cultistSacrificeTimer = Math.max(0, (+r.cultistSacrificeTimer || 0) - a); if (r.cultistSacrificeTimer <= 0 && !r.cultistSacrificeApplied) { r.cultistSacrificeApplied = true; n.archivistSacrificesReceived = Math.max(0, +n.archivistSacrificesReceived || 0) + 1; r.state = "death"; r.health = 0; } return; }
      const ang = +r.cultistWorshipAngle || 0, tx = n.x + Math.cos(ang) * K.CULT_RX, ty = n.y + Math.sin(ang) * K.CULT_RY, hx = tx - r.x, hy = ty - r.y, m = hyp(hx, hy);
      if (m > 10) { const sp = r.speed || 46; r.state = "move"; r.x += (hx / m) * sp * e; r.y += (hy / m) * sp * e; r.facingRight = hx > 0; } else { r.state = "ritual"; r.facingRight = n.x > r.x; }
      return;
    }
    if (r.type === "masked-forest-spirit") {
      if (!r.isBoss && stunned(r, a)) return;
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
      const pd = alive ? (r.x - t.x) ** 2 + (r.y - t.y) ** 2 : 999999, H = r.isBoss ? 78 : 45, P = r.isBoss ? 92 : 55, ml = r.x - px, gl = r.y - py, fp = ml * ml + gl * gl;
      const gx = r.groupCenterX ?? r.originalX ?? r.x, gy = r.groupCenterY ?? r.originalY ?? r.y, vx = gx - r.x, vy = gy - r.y, w = hyp(vx, vy), near = !!(alive && pd < 176400);
      if (w > 1.05 * (r.isBoss && near ? 420 : r.isBoss ? 340 : 180)) { const n = 1.2 * (r.speed || 40); r.state = "move"; r.x += (vx / (w || 1)) * n * e; r.y += (vy / (w || 1)) * n * e; r.facingRight = vx > 0; r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a); return; }
      const rect = (W, up, down) => r.isBoss && alive && Math.abs(r.x - t.x) <= W && Math.abs(r.y - t.y) <= (t.y < r.y ? up : down);
      if (r.state === "attack") {
        if (r.isBoss && alive) { const tx = t.x - r.x, ty = t.y - r.y, dd = tx * tx + ty * ty, lim = 0.7 * H; if (dd > lim * lim) { const q = Math.sqrt(dd) || 1, sp = 0.65 * (r.speed || 40); r.x += (tx / q) * sp * e; r.y += (ty / q) * sp * e; r.facingRight = tx > 0; } }
        r.animTimer = (r.animTimer || 0) + a;
        if (r.animTimer > 0.08) { r.animTimer = 0; r.animFrame = (r.animFrame || 0) + 1;
          if (r.animFrame >= 2 && !r.attackDamageApplied && alive && ((r.x - t.x) ** 2 + (r.y - t.y) ** 2 < P * P || rect(140, 230, 145))) { queue(t, r.attack * dtm(i), 0.25, 0.8); r.attackDamageApplied = true; }
          if (r.animFrame >= 4) { r.state = "idle"; r.attackCooldown = 1.2; r.attackDamageApplied = false; } }
      } else if ((pd < H * H || rect(120, 190, 125)) && r.attackCooldown <= 0 && alive) { r.state = "attack"; r.animFrame = 0; r.animTimer = 0; r.attackDamageApplied = false; }
      else if (r.isBoss && alive && pd < 102400) { const tx = t.x - r.x, ty = t.y - r.y, q = Math.sqrt(pd) || 1; if (q > 0.9 * H) { const sp = 1.05 * (r.speed || 40); r.state = "move"; r.x += (tx / q) * sp * e; r.y += (ty / q) * sp * e; r.facingRight = tx > 0; } else r.state = "idle"; }
      else if (!r.isBoss && fp < 3600) { r.state = "scared"; const q = Math.sqrt(fp) || 1, sp = 1.4 * (r.speed || 40); r.x += (ml / q) * sp * e; r.y += (gl / q) * sp * e; r.facingRight = ml > 0; }
      else if (r.state === "scared") { if (fp > 4e4) { r.state = "idle"; r.roamTimer = 1; } else { const q = Math.sqrt(fp) || 1, sp = 1.4 * (r.speed || 40); r.x += (ml / q) * sp * e; r.y += (gl / q) * sp * e; r.facingRight = ml > 0; } }
      else if (r.state === "move") { const tx = (r.targetX ?? r.x) - r.x, ty = (r.targetY ?? r.y) - r.y, q = hyp(tx, ty); if (q < 4) { r.state = "idle"; r.roamTimer = 1 + 2 * Math.random(); } else { const sp = 0.8 * (r.speed || 40); r.x += (tx / q) * sp * e; r.y += (ty / q) * sp * e; if (Math.abs(tx) > 1) r.facingRight = tx > 0; } }
      else { r.state = "idle"; r.roamTimer = (r.roamTimer || 0) - a; if (r.roamTimer <= 0) { const n = 120; r.targetX = Math.max(b.minX, Math.min(b.maxX, gx - n + Math.random() * 2 * n)); r.targetY = Math.max(b.minY, Math.min(b.maxY, gy - n + Math.random() * 2 * n)); r.state = "move"; } }
      return;
    }
    if (r.type === "flower-monster") {
      if (stunned(r, a, (st) => st === "attack")) return;
      const n = r.isBoss ? 240 : 170, sR = r.isBoss ? 360 : 260, uR = Math.max(12, r.attackRange || 22), hR = r.isBoss ? Math.max(uR + 6, 28) : uR, gx = r.groupCenterX ?? r.originalX ?? r.x, gy = r.groupCenterY ?? r.originalY ?? r.y, y = hyp(r.x - gx, r.y - gy), lim = r.isBoss ? 420 : 280;
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
      if (!alive) { Object.assign(r, { state: "hide", animFrame: 0, animTimer: 0, flowerEmerged: false }); return; }
      const vx = t.x - r.x, vy = t.y - r.y, w = vx * vx + vy * vy;
      if (!r.flowerEmerged) { if (r.state === "attack") { r.animTimer = (r.animTimer || 0) + a; if (r.animTimer >= 0.45) Object.assign(r, { animTimer: 0, animFrame: 0, state: "idle", flowerEmerged: true }); } else { r.state = "hide"; if (w < n * n) { r.state = "attack"; r.animFrame = 0; r.animTimer = 0; } } return; }
      if (y > lim) { const q = y || 1, sp = 1.2 * (r.speed || 54); r.state = "move"; r.x += ((gx - r.x) / q) * sp * e; r.y += ((gy - r.y) / q) * sp * e; r.facingRight = gx - r.x > 0; return; }
      if (w < sR * sR) {
        const q = Math.sqrt(w) || 1; if (q > 0.65 * hR) { const sp = 1.1 * (r.speed || 54); r.state = "move"; r.x += (vx / q) * sp * e; r.y += (vy / q) * sp * e; r.facingRight = vx > 0; } else r.state = "idle";
        if (r.attackCooldown <= 0) { if ((t.x - r.x) ** 2 + (t.y - r.y) ** 2 >= hR * hR) return; queue(t, r.attack * dtm(i), 0.25, 1); r.attackCooldown = 1; }
      } else Object.assign(r, { state: "hide", animFrame: 0, animTimer: 0, flowerEmerged: false });
      return;
    }
    if (r.type === "witch" || r.type === "fishfolk-archpriest" || r.type === "anubis-warrior" || r.type === "anubis") return caster(s, run, r, e, a, t, alive, b, mapId);
    if (r.type === "harpy" || r.type === "ice-harpy") {
      if (stunned(r, a)) return;
      const gx = r.groupCenterX ?? r.originalX ?? r.x, gy = r.groupCenterY ?? r.originalY ?? r.y, m = hyp(r.x - gx, r.y - gy), g = Math.max(16, r.attackRange || 28), fR = r.isBoss ? Math.max(g + 8, 36) : g, y = r.isBoss ? 0.8 * fR : 0.7 * fR, bR = r.isBoss ? 380 : 290, A = r.isBoss ? 440 : 300;
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
      if (m > 1.08 * A) return goHome(r, gx, gy, m, e, 1.1, 68);
      if (r.state === "attack") {
        for (r.animTimer = (r.animTimer || 0) + a; r.animTimer >= 0.1;) {
          r.animTimer -= 0.1; r.animFrame = (r.animFrame || 0) + 1;
          if (r.animFrame >= 2 && !r.attackDamageApplied && alive) { const an = X.anchor(r), lim = r.isBoss ? fR + 10 : fR + 4; if ((t.x - an.x) ** 2 + (t.y - an.y) ** 2 < lim * lim) { queue(t, r.attack * dtm(i), 0.25, 1); r.attackDamageApplied = true; } }
          if (r.animFrame >= 5) { Object.assign(r, { state: "idle", attackCooldown: 1, animFrame: 0, animTimer: 0, attackDamageApplied: false }); break; }
        }
      } else if (alive) {
        const an = X.anchor(r), ix = t.x - an.x, iy = t.y - an.y, ss = ix * ix + iy * iy, inR = ss < bR * bR;
        if (inR && ss < fR * fR && r.attackCooldown <= 0) Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false, facingRight: ix > 0 });
        else if (inR) { const q = Math.sqrt(ss) || 1; if (q > y) { const sp = 1.05 * (r.speed || 68); r.state = "move"; r.x += (ix / q) * sp * e; r.y += (iy / q) * sp * e; r.facingRight = ix > 0; } else r.state = "idle"; }
        else r.state = "idle";
      } else r.state = "idle";
      return;
    }
    if (r.type === "cacodaemon") {
      if (stunned(r, a, (st) => st === "attack")) return;
      const sx = r.originalX ?? r.groupCenterX ?? r.x, sy = r.originalY ?? r.groupCenterY ?? r.y, m = hyp(r.x - sx, r.y - sy), g = Math.max(230, r.attackRange || 270);
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
      const stop = () => { r.cacodaemonChargeVelocityX = 0; r.cacodaemonChargeVelocityY = 0; r.cacodaemonChargeTimer = 0; };
      if (m > 1.08 * 440 && r.state !== "attack") { stop(); moveHome(r, e, b, 58); }
      else if (r.state === "attack") {
        const x0 = r.x, y0 = r.y, vx = +r.cacodaemonChargeVelocityX || 0, nx = x0 + vx * e, ny = y0 + (+r.cacodaemonChargeVelocityY || 0) * e;
        r.x = Math.max(b.minX, Math.min(b.maxX, nx)); r.y = Math.max(b.minY, Math.min(b.maxY, ny)); r.facingRight = vx >= 0; r.cacodaemonChargeTimer = Math.max(0, +r.cacodaemonChargeTimer || 0) - a;
        let hit = false;
        if (alive && !r.attackDamageApplied) { const ex = r.x - x0, ey = r.y - y0, aa = ex * ex + ey * ey, cc = aa > 0 ? Math.max(0, Math.min(1, ((t.x - x0) * ex + (t.y - y0) * ey) / aa)) : 0, qx = x0 + ex * cc, qy = y0 + ey * cc;
          hit = (t.x - qx) ** 2 + (t.y - qy) ** 2 < 784; if (hit) { r.x = qx; r.y = qy; queue(t, r.attack * dtm(i), 0.25, 1); r.attackDamageApplied = true; } }
        const clipped = Math.abs(nx - r.x) > 0.001 || Math.abs(ny - r.y) > 0.001;
        if (hit || clipped || r.cacodaemonChargeTimer <= 0) { Object.assign(r, { state: "idle", attackCooldown: 1.45, animFrame: 0, animTimer: 0, attackDamageApplied: false }); stop(); }
      } else if (alive) {
        const n = t.x - r.x, iy = t.y - r.y, aa = n * n + iy * iy, q = Math.sqrt(aa) || 1;
        if (aa <= g * g && r.attackCooldown <= 0) Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false, facingRight: n > 0, cacodaemonChargeVelocityX: (n / q) * 285, cacodaemonChargeVelocityY: (iy / q) * 285, cacodaemonChargeTimer: 0.75 });
        else if (aa <= 420 * 420 && q > 0.72 * g) { const sp = 1.04 * (r.speed || 58); r.state = "move"; r.x += (n / q) * sp * e; r.y += (iy / q) * sp * e; r.facingRight = n > 0; }
        else if (aa <= 420 * 420) r.state = "idle"; else { stop(); moveHome(r, e, b, 58); }
      } else { stop(); moveHome(r, e, b, 58); }
      return;
    }
    if (r.type === "imp") {
      if (stunned(r, a, (st) => st === "attack")) return;
      const sx = r.originalX ?? r.groupCenterX ?? r.x, sy = r.originalY ?? r.groupCenterY ?? r.y, m = hyp(r.x - sx, r.y - sy), g = Math.max(220, r.attackRange || 260);
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
      if (m > 1.08 * 430) moveHome(r, e, b, 62);
      else if (r.state === "attack") {
        for (r.animTimer = (r.animTimer || 0) + a; r.animTimer >= 0.088;) { r.animTimer -= 0.088; r.animFrame = (r.animFrame || 0) + 1; if (r.animFrame >= 3 && !r.attackDamageApplied && alive) { spawnFireball(i, r, t, mapId); r.attackDamageApplied = true; } if (r.animFrame >= 6) { Object.assign(r, { state: "idle", attackCooldown: 1.55, animFrame: 0, animTimer: 0, attackDamageApplied: false }); break; } }
      } else if (alive) {
        const n = t.x - r.x, iy = t.y - r.y, aa = n * n + iy * iy, q = Math.sqrt(aa) || 1;
        if (aa <= 430 * 430) { r.facingRight = n > 0; if (q <= g && q >= 105 && r.attackCooldown <= 0) Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false }); else if (q < 105) { const sp = 1.12 * (r.speed || 62); r.state = "move"; r.x -= (n / q) * sp * e; r.y -= (iy / q) * sp * e; } else if (q > 185) { const sp = 1.02 * (r.speed || 62); r.state = "move"; r.x += (n / q) * sp * e; r.y += (iy / q) * sp * e; } else r.state = "idle"; }
        else moveHome(r, e, b, 62);
      } else moveHome(r, e, b, 62);
      return;
    }
    if (GENERIC.has(r.type)) return melee(s, run, r, e, a, t, alive, b, rects, px, py);
    if (r.type === "mini-fly") return miniFly(s, run, r, e, a, t, markPrune, mapId);
    if (r.type === "twig-blight" || r.type === "giant-fly") return blightFly(s, run, r, e, a, t, b, mapId);
  }
  // witch, archpriest, anubis warrior and anubis: ranged casters that hold a distance band
  function caster(s, run, r, e, a, t, alive, b, mapId) {
    const i = run, gx = r.groupCenterX ?? r.originalX ?? r.x, gy = r.groupCenterY ?? r.originalY ?? r.y, m = hyp(r.x - gx, r.y - gy);
    if (r.type === "witch") {
      if (stunned(r, a, (st) => st === "attack")) return;
      const g = Math.max(130, r.attackRange || 220), f = r.isBoss ? Math.max(g + 20, 240) : g, y = r.isBoss ? 0.72 * f : 0.68 * f, bR = r.isBoss ? 520 : 420, A = r.isBoss ? 560 : 420;
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
      if (m > 1.08 * A) return goHome(r, gx, gy, m, e, 1.08, 56);
      if (r.state === "attack") {
        for (r.animTimer = (r.animTimer || 0) + a; r.animTimer >= 0.09;) {
          r.animTimer -= 0.09; r.animFrame = (r.animFrame || 0) + 1;
          if (r.animFrame >= 4 && !r.attackDamageApplied && alive) { const lim = r.isBoss ? f + 40 : f + 28; if ((t.x - r.x) ** 2 + (t.y - r.y) ** 2 < lim * lim) { queue(t, r.attack * dtm(i), 0.22, 1); r.attackDamageApplied = true; } }
          if (r.animFrame >= 8) { Object.assign(r, { state: "idle", attackCooldown: 1.6, animFrame: 0, animTimer: 0, attackDamageApplied: false }); break; }
        }
      } else if (alive) { const n = t.x - r.x, iy = t.y - r.y, aa = n * n + iy * iy, inR = aa < bR * bR; if (inR && aa < f * f && r.attackCooldown <= 0) Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false, facingRight: n > 0 }); else if (inR) kite(r, t, n, iy, aa, y, 0.76 * y, e, 1.04, 0.82, 56); else r.state = "idle"; }
      else r.state = "idle";
      return;
    }
    if (r.type === "fishfolk-archpriest") {
      if (stunned(r, a, (st) => st === "attack")) return;
      const g = Math.max(130, r.attackRange || 170), f = r.isBoss ? Math.max(g + 20, 190) : g, y = r.isBoss ? 210 : 180, bb = r.isBoss ? 0.68 * f : 0.64 * f, A = r.isBoss ? 540 : 440, v = r.isBoss ? 600 : 470;
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a); r.archpriestHealCooldown = Math.max(0, +r.archpriestHealCooldown || 0) - a;
      if (m > 1.08 * v) return goHome(r, gx, gy, m, e, 1.08, 56, () => (r.archpriestAttackMode = "damage"));
      if (r.state === "attack") {
        for (r.animTimer = (r.animTimer || 0) + a; r.animTimer >= 0.1;) {
          r.animTimer -= 0.1; r.animFrame = (r.animFrame || 0) + 1; const heal = r.archpriestAttackMode === "heal", hitF = heal ? 4 : 3, endF = heal ? 9 : 7;
          if (r.animFrame >= hitF && !r.attackDamageApplied) {
            if (heal) { const pct = r.isBoss ? 0.2 : 0.14, min = r.isBoss ? 20 : 12; let any = false; for (const q of healTargets(i, r, y)) { const miss = Math.max(0, q.maxHealth - q.health); if (miss <= 0.25) continue; const amt = Math.min(miss, Math.max(min, q.maxHealth * pct)); if (amt <= 0) continue; q.health = Math.min(q.maxHealth, q.health + amt); q.hitFlash = Math.max(q.hitFlash || 0, 0.16); X.dmgNumber(i, q, "+" + PT.fmt(amt), "#86efac"); any = true; } r.archpriestHealCooldown = any ? (r.isBoss ? 7.8 : 9) : 3.2; }
            else if (alive) { const lim = f + (r.isBoss ? 30 : 22); if ((t.x - r.x) ** 2 + (t.y - r.y) ** 2 < lim * lim) queue(t, r.attack * dtm(i), 0.22, 1); }
            r.attackDamageApplied = true;
          }
          if (r.animFrame >= endF) { Object.assign(r, { state: "idle", attackCooldown: heal ? 1.4 : 1.2, animFrame: 0, animTimer: 0, attackDamageApplied: false, archpriestAttackMode: "damage" }); break; }
        }
      } else {
        const ht = (r.archpriestHealCooldown ?? 0) <= 0 ? healTargets(i, r, y) : [];
        if (ht.length && r.attackCooldown <= 0) Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false, archpriestAttackMode: "heal", facingRight: ht[0].x - r.x > 0 });
        else if (alive) { const n = t.x - r.x, iy = t.y - r.y, aa = n * n + iy * iy, inR = aa < A * A; if (inR && aa < f * f && r.attackCooldown <= 0) Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false, archpriestAttackMode: "damage", facingRight: n > 0 }); else if (inR) { kite(r, t, n, iy, aa, bb, 0.72 * bb, e, 1.05, 0.84, 56); if (r.state === "idle") r.facingRight = n > 0; } else r.state = "idle"; }
        else r.state = "idle";
      }
      return;
    }
    if (r.type === "anubis-warrior") {
      if (stunned(r, a, (st) => st === "attack" || st === "hitting")) return;
      const g = Math.max(130, r.attackRange || 180), f = r.isBoss ? Math.max(g + 20, 200) : g, y = r.isBoss ? 48 : 42, bb = r.isBoss ? 0.66 * f : 0.62 * f, A = r.isBoss ? 520 : 430, v = r.isBoss ? 580 : 460;
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
      if (m > 1.08 * v) return goHome(r, gx, gy, m, e, 1.08, 58, () => (r.anubisWarriorAttackMode = "range"));
      if (r.state === "attack" || r.state === "hitting") {
        for (r.animTimer = (r.animTimer || 0) + a; r.animTimer >= 0.1;) {
          r.animTimer -= 0.1; r.animFrame = (r.animFrame || 0) + 1; const close = (r.anubisWarriorAttackMode || (r.state === "hitting" ? "close" : "range")) === "close" || r.state === "hitting", hitF = close ? 2 : 3, endF = close ? 4 : 5;
          if (r.animFrame >= hitF && !r.attackDamageApplied && alive) { const lim = close ? y + 10 : f + (r.isBoss ? 34 : 26); if ((t.x - r.x) ** 2 + (t.y - r.y) ** 2 < lim * lim) { queue(t, r.attack * dtm(i), close ? 0.25 : 0.22, 1); r.attackDamageApplied = true; } }
          if (r.animFrame >= endF) { Object.assign(r, { state: "idle", attackCooldown: close ? 1.15 : 1.45, animFrame: 0, animTimer: 0, attackDamageApplied: false, anubisWarriorAttackMode: "range" }); break; }
        }
      } else if (alive) {
        const n = t.x - r.x, iy = t.y - r.y, aa = n * n + iy * iy, inR = aa < A * A;
        if (inR && aa < y * y && r.attackCooldown <= 0) Object.assign(r, { state: "hitting", animFrame: 0, animTimer: 0, attackDamageApplied: false, anubisWarriorAttackMode: "close", facingRight: n > 0 });
        else if (inR && aa < f * f && r.attackCooldown <= 0) Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false, anubisWarriorAttackMode: "range", facingRight: n > 0 });
        else if (inR) kite(r, t, n, iy, aa, bb, 0.9 * y, e, 1.05, 0.86, 58); else r.state = "idle";
      } else r.state = "idle";
      return;
    }
    // anubis
    if (stunned(r, a, (st) => st === "attack")) return;
    const g = Math.max(180, r.attackRange || 280), f = r.isBoss ? Math.max(g + 32, 300) : g, y = r.isBoss ? 0.78 * f : 0.74 * f, bR = r.isBoss ? 600 : 500, A = r.isBoss ? 640 : 500;
    r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a); r.anubisAnkhCooldown = Math.max(0, +r.anubisAnkhCooldown || 0) - a; r.anubisCoffinCooldown = Math.max(0, +r.anubisCoffinCooldown || 0) - a;
    const resetCoffin = () => Object.assign(r, { anubisCoffinPhase: "", anubisCoffinFrame: 0, anubisCoffinSpawned: false });
    if (m > 1.08 * A) return goHome(r, gx, gy, m, e, 1.08, 54, () => { r.anubisAction = ""; r.anubisActionApplied = false; resetCoffin(); });
    if (r.state === "attack") {
      const act = r.anubisAction || "";
      for (r.animTimer = (r.animTimer || 0) + a; r.animTimer >= 0.09;) {
        r.animTimer -= 0.09; r.animFrame = (r.animFrame || 0) + 1;
        if (act === "coffin") {
          let ph = r.anubisCoffinPhase || "", fr = Math.max(0, Math.floor(+r.anubisCoffinFrame || 0)), sp = r.anubisCoffinSpawned === true;
          if (ph !== "emerge" && ph !== "open") { ph = "emerge"; fr = 0; sp = false; }
          else if (ph === "emerge") { fr += 1; if (fr >= 12) { ph = "open"; fr = 0; } }
          else { fr += 1; if (fr === 4 && !sp) { spawnMummies(s, run, r, mapId); sp = true; } if (fr >= 12) { Object.assign(r, { state: "idle", attackCooldown: 1.9, animFrame: 0, animTimer: 0, anubisAction: "", anubisActionApplied: false, anubisCoffinCooldown: K.COFFIN_CD }); resetCoffin(); break; } }
          r.anubisCoffinPhase = ph; r.anubisCoffinFrame = fr; r.anubisCoffinSpawned = sp;
        } else {
          resetCoffin();
          if (r.animFrame >= 6 && !r.anubisActionApplied && alive) { spawnAnkh(i, r, t, r.anubisAttackSide === "left" ? "left" : "right", mapId); r.anubisActionApplied = true; }
          if (r.animFrame >= 14) { Object.assign(r, { state: "idle", attackCooldown: 1.55, animFrame: 0, animTimer: 0, anubisAction: "", anubisActionApplied: false, anubisAnkhCooldown: K.ANKH_CD }); break; }
        }
      }
    } else if (alive) {
      const n = t.x - r.x, iy = t.y - r.y, ss = n * n + iy * iy, q = Math.sqrt(ss) || 1, inR = ss < bR * bR, coffin = (r.anubisCoffinCooldown ?? 0) <= 0 && summonCount(i, String(r.id)) < K.ANUBIS_SUMMONS, ankh = (r.anubisAnkhCooldown ?? 0) <= 0;
      if (inR && ss < f * f && r.attackCooldown <= 0 && (coffin || ankh)) {
        const pick = coffin && (q > 0.86 * y || Math.random() < 0.36); let act = pick ? "coffin" : "ankh"; if (!pick && !ankh && coffin) act = "coffin";
        r.anubisAction = act; r.anubisActionApplied = false; if (act === "coffin") Object.assign(r, { anubisCoffinPhase: "emerge", anubisCoffinFrame: 0, anubisCoffinSpawned: false }); else resetCoffin();
        Object.assign(r, { anubisAttackSide: n < 0 ? "left" : "right", state: "attack", animFrame: 0, animTimer: 0, facingRight: n > 0 });
      } else if (inR) { kite(r, t, n, iy, ss, y, 0.72 * y, e, 1.04, 0.82, 54); if (r.state === "idle") r.facingRight = n > 0; }
      else r.state = "idle";
    } else r.state = "idle";
  }
  // shared melee AI for the remaining types (Birb's big "cobra || ghoul || ..." branch)
  function melee(s, run, r, e, a, t, alive, b, rects, px, py) {
    const i = run;
    if (stunned(r, a)) return;
    const home = X.returnsToSpawn(r), hx = home ? r.originalX ?? r.groupCenterX ?? r.x : r.groupCenterX ?? r.originalX ?? r.x, hy = home ? r.originalY ?? r.groupCenterY ?? r.y : r.groupCenterY ?? r.originalY ?? r.y;
    const f = hyp(r.x - hx, r.y - hy), y = X.triggerRange(r), bb = r.isBoss ? 0.75 * y : 0.65 * y, A = r.isBoss ? 340 : 260, v = r.isBoss ? 420 : 280, an = X.anchor(r), w = alive ? hyp(t.x - an.x, t.y - an.y) : Infinity, M = alive && (w < y || (t.targetEnemyId === r.id && w < A));
    r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
    if (r.type === "elemental") r.elementalSpecialCooldown = Math.max(0, (+r.elementalSpecialCooldown || 0) - a);
    if ((r.type === "frost-wisp" || r.type === "ghost" || r.type === "giant-black-pudding" || r.type === "zombie-cultist") && r.state === "respawn") { if (r.attackCooldown <= 0) { r.state = "idle"; r.animFrame = 0; r.animTimer = 0; } return; }
    if (r.type === "doppelganger") {
      const sx = alive ? t.x - r.x : 0, sy = alive ? t.y - r.y : 0;
      if (r.doppelgangerForm === "human" && ((alive && sx * sx + sy * sy <= 104 * 104) || r.health < r.maxHealth)) Object.assign(r, { doppelgangerForm: "transforming", state: "transform", animFrame: 0, animTimer: 0, attackCooldown: 0, facingRight: sx > 0 });
      if (r.doppelgangerForm === "human") { Object.assign(r, { state: "idle", targetX: r.x, targetY: r.y, attackDamageApplied: false }); return; }
      if (r.doppelgangerForm === "transforming") { r.state = "transform"; for (r.animTimer = (r.animTimer || 0) + a; r.animTimer >= 0.085;) { r.animTimer -= 0.085; r.animFrame = (r.animFrame || 0) + 1; if (r.animFrame >= 8) { Object.assign(r, { doppelgangerForm: "monster", state: "idle", animFrame: 0, animTimer: 0, attackCooldown: 0.35 }); break; } } return; }
    }
    if (f > 1.08 * v && !M) return goHome(r, hx, hy, f, e, 1.1, 62, () => { if (r.type === "fishfolk-brute") r.fishfolkBruteAttackStage = "windup"; if (r.type === "elemental") { r.elementalAttackMode = "normal"; r.elementalSpecialLastHitFrame = -1; } });
    if (r.type === "ice-fire-guardian" && r.isBoss && X.guardianAI && X.guardianAI(s, run, r, a)) return; // expedition_night.js (Birb $T)
    if (r.state === "attack") {
      const mode = r.type === "elemental" ? String(r.elementalAttackMode || "normal") : "normal";
      if (r.type === "elemental" && mode === "special" && alive) { const rad = Math.max(18, y - 6), ang = (+r.elementalOrbitAngle || 0) + a * 4.8; r.elementalOrbitAngle = ang; const ox = t.x + Math.cos(ang) * rad - r.x, oy = t.y + Math.sin(ang) * rad - r.y, q = hyp(ox, oy) || 1, sp = 2.2 * (r.speed || 60); r.x += (ox / q) * sp * e; r.y += (oy / q) * sp * e; r.facingRight = ox > 0; }
      for (r.animTimer = (r.animTimer || 0) + a; r.animTimer >= 0.1;) {
        r.animTimer -= 0.1; r.animFrame = (r.animFrame || 0) + 1;
        const brute = r.type === "fishfolk-brute", pug = r.type === "fishfolk-pugilist", stage = brute ? String(r.fishfolkBruteAttackStage || "windup") : "", pm = pug ? String(r.fishfolkPugilistAttackMode || "left") : "";
        if (brute && stage === "windup") { if (r.animFrame >= 5) { r.fishfolkBruteAttackStage = "attack"; r.animFrame = 0; } continue; }
        if (pug && pm === "charge") { if (r.animFrame >= 8) { r.fishfolkPugilistAttackMode = "release"; r.animFrame = 0; r.attackDamageApplied = false; } continue; }
        const hitF = r.type === "fishfolk-pugilist" ? (pm === "release" ? 5 : 3) : r.type === "elemental" ? (mode === "special" ? 2 : 4) : r.type === "the-archivist" ? (r.archivistAttackMode === "attack2" ? 8 : 7) : HIT_FRAME[r.type] ?? 2;
        let doHit = r.animFrame >= hitF && !r.attackDamageApplied;
        if (r.type === "elemental" && mode === "special") { const last = +(r.elementalSpecialLastHitFrame ?? -1); let tf; if (last < 2 && r.animFrame >= 2) tf = 2; else if (last < 4 && r.animFrame >= 4) tf = 4; else if (last < 6 && r.animFrame >= 6) tf = 6; doHit = tf !== undefined; if (tf !== undefined) r.elementalPendingHitFrame = tf; }
        if (doHit && alive) {
          const ea = X.anchor(r), lim = r.type === "frosty-slime" ? y + 22 : r.type === "the-archivist" && r.archivistAttackMode === "attack2" ? y + 18 : r.isBoss ? y + 10 : y + 4;
          if ((t.x - ea.x) ** 2 + (t.y - ea.y) ** 2 < lim * lim) {
            const mult = pug && pm === "release" ? 1.85 : r.type === "elemental" && mode === "special" ? 0.7 : r.type === "the-archivist" && r.archivistAttackMode === "attack2" ? 1.25 : 1, dmg = r.attack * mult * dtm(i);
            queue(t, dmg, 0.25, 1, () => { if (r.type === "cobra") cobraVenom(t, dmg); }); r.attackDamageApplied = true;
            if (r.type === "elemental" && mode === "special") { r.elementalSpecialLastHitFrame = +(r.elementalPendingHitFrame ?? r.animFrame); r.attackDamageApplied = false; }
            if (pug) { if (pm === "release") r.fishfolkPugilistSuccessfulHits = 0; else { const k = Math.max(0, +r.fishfolkPugilistSuccessfulHits || 0) + 1; r.fishfolkPugilistSuccessfulHits = k; if (k >= 3) r.fishfolkPugilistSpecialReady = true; } }
          }
        }
        const endF = r.type === "fishfolk-pugilist" ? (pm === "release" ? 8 : 6) : END_FRAME[r.type] ?? 5;
        if (r.animFrame >= endF) {
          r.state = "idle";
          r.attackCooldown = r.type === "fishfolk-pugilist" ? (pm === "release" ? 2.15 : 1.05) : r.type === "elemental" ? (mode === "special" ? 2.4 : 1.25) : r.type === "the-archivist" ? (r.archivistAttackMode === "attack2" ? 2.05 : 1.5) : COOLDOWN[r.type] ?? 1.2;
          r.animFrame = 0; r.animTimer = 0; r.attackDamageApplied = false;
          if (r.type === "fishfolk-brute") r.fishfolkBruteAttackStage = "windup";
          if (pug && pm === "release") r.fishfolkPugilistAttackMode = r.fishfolkPugilistNextSide || "left";
          if (r.type === "elemental") { r.elementalSpecialLastHitFrame = -1; r.elementalPendingHitFrame = -1; if (mode === "special") r.elementalSpecialCooldown = 6; r.elementalAttackMode = "normal"; }
          break;
        }
      }
    } else if (alive) {
      const ix = t.x - an.x, iy = t.y - an.y, hh = ix * ix + iy * iy, inR = hh < A * A;
      if (inR && hh < y * y && r.attackCooldown <= 0) {
        Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false });
        if (r.type === "the-archivist") r.archivistAttackMode = Math.random() < 0.35 ? "attack2" : "attack1";
        if (r.type === "fishfolk-brute") r.fishfolkBruteAttackStage = "windup";
        else if (r.type === "fishfolk-pugilist") { if (r.fishfolkPugilistSpecialReady) Object.assign(r, { fishfolkPugilistAttackMode: "charge", fishfolkPugilistSpecialReady: false, fishfolkPugilistSuccessfulHits: 0 }); else { const sd = String(r.fishfolkPugilistNextSide || "left") === "right" ? "right" : "left"; r.fishfolkPugilistAttackMode = sd; r.fishfolkPugilistNextSide = sd === "left" ? "right" : "left"; } }
        else if (r.type === "elemental") { r.elementalAttackMode = (+r.elementalSpecialCooldown || 0) <= 0 ? "special" : "normal"; r.elementalSpecialLastHitFrame = -1; r.elementalPendingHitFrame = -1; }
        else if (r.type === "black-pudding" || r.type === "giant-black-pudding") r.blackPuddingAttackMode = Math.random() < 0.5 ? "attack" : "attack2";
        r.facingRight = ix > 0;
      } else if (inR) {
        if ((Math.sqrt(hh) || 1) > bb) { const sp = 1.06 * (r.speed || 62) * (r.type === "elemental" ? 1.08 : 1), x0 = r.x, lt = laneTarget(r, t, y, an.y - r.y), moved = pursue(r, lt, lt.stop, sp, e, b, rects); r.state = moved ? "move" : "idle"; if (moved) r.facingRight = r.x > x0; }
        else r.state = "idle";
      } else if (home) moveHome(r, e, b, 62); else r.state = "idle";
    } else if (home) moveHome(r, e, b, 62); else r.state = "idle";
  }
  function miniFly(s, run, r, e, a, t, markPrune, mapId) {
    const i = run; if (stunned(r, a)) return;
    const kind = r.projectileKind || "";
    if (kind === "imp-fireball") {
      if (!t || t.health <= 0) { r.health = 0; return; }
      const ph = r.projectilePhase || "move";
      if (ph === "appear") { r.projectilePhaseTimer = Math.max(0, +r.projectilePhaseTimer || 0.18) - e; if (r.projectilePhaseTimer <= 0) r.projectilePhase = "move"; }
      else if (ph === "hit") { r.projectilePhaseTimer = Math.max(0, +r.projectilePhaseTimer || 0.28) - e; if (r.projectilePhaseTimer <= 0) r.health = 0; }
      else {
        const vx = +r.projectileVelocityX || 0, vy = +r.projectileVelocityY || 0; r.projectileLifetime = Math.max(0, +r.projectileLifetime || 0) - e; if (r.projectileLifetime <= 0) { r.health = 0; return; }
        const x0 = r.x, y0 = r.y, x1 = x0 + vx * e, y1 = y0 + vy * e; r.facingRight = vx >= 0;
        const dx = x1 - x0, dy = y1 - y0, hh = dx * dx + dy * dy, wall = wallHit(mapId, x0, y0, x1, y1), f = hh > 0 ? Math.max(0, Math.min(1, ((t.x - x0) * dx + (t.y - y0) * dy) / hh)) : 0, qx = x0 + dx * f, qy = y0 + dy * f;
        if ((t.x - qx) ** 2 + (t.y - qy) ** 2 < 225 && (!wall || f < wall.t)) { r.x = qx; r.y = qy; if (!r.projectileHitApplied) { queue(t, r.attack * dtm(i), 0.2, 0.9); r.projectileHitApplied = true; } r.projectilePhase = "hit"; r.projectilePhaseTimer = 0.28; return; }
        if (wall) { r.x = wall.x; r.y = wall.y; r.projectilePhase = "hit"; r.projectilePhaseTimer = 0.28; return; }
        r.x = x1; r.y = y1; const M = Math.max(1, +r.projectileMaxRange || 380); if ((r.x - r.projectileSpawnX) ** 2 + (r.y - r.projectileSpawnY) ** 2 >= M * M) { r.projectilePhase = "hit"; r.projectilePhaseTimer = 0.28; }
      }
      return;
    }
    if (kind === "ankh") {
      if (!t || t.health <= 0) { r.health = 0; return; }
      const ph = r.ankhPhase || "move";
      if (ph === "appear") { r.ankhPhaseTimer = Math.max(0, +r.ankhPhaseTimer || 0.9) - e; if (r.ankhPhaseTimer <= 0) r.ankhPhase = "move"; }
      else if (ph === "hit") { r.ankhHitTimer = Math.max(0, +r.ankhHitTimer || 0.4) - e; if (r.ankhHitTimer <= 0) r.health = 0; }
      else {
        r.ankhLifetime = Math.max(0, +r.ankhLifetime || 0) - e; if (r.ankhLifetime <= 0) { r.health = 0; return; }
        r.x += (+r.ankhVelocityX || 0) * e; r.y += (+r.ankhVelocityY || 0) * e; r.facingRight = (+r.ankhVelocityX || 0) >= 0;
        if ((t.x - r.x) ** 2 + (t.y - r.y) ** 2 < 324) { if (!r.ankhHitApplied) { queue(t, r.attack * dtm(i), 0.2, 0.95); r.ankhHitApplied = true; } r.ankhPhase = "hit"; r.ankhHitTimer = 0.4; return; }
        const M = Math.max(1, +r.ankhMaxRange || 360); if ((r.x - r.ankhSpawnX) ** 2 + (r.y - r.ankhSpawnY) ** 2 >= M * M) { r.ankhPhase = "hit"; r.ankhHitTimer = 0.4; }
      }
      return;
    }
    if (t && t.health > 0) {
      const n = t.x - r.x, iy = t.y - r.y, d = hyp(n, iy);
      const land = () => { if (!r.miniFlyHitApplied) { queue(t, r.attack * dtm(i), 0.2, 0.95); r.miniFlyHitApplied = true; } r.health = 0; markPrune(); };
      if (d <= K.MINI_FLY_LAND) land();
      else { const sp = Math.min(K.MINI_FLY_MAX, Math.max(K.MINI_FLY_BASE, +r.speed || 0) + K.MINI_FLY_ACCEL * Math.max(0, e)); r.speed = sp; const step = sp * Math.max(0, e); if (step >= d) { r.x = t.x; r.y = t.y; land(); } else { r.x += (n / d) * step; r.y += (iy / d) * step; } r.facingRight = n > 0; }
    } else { r.health = 0; markPrune(); }
  }
  function blightFly(s, run, r, e, a, t, b, mapId) {
    const i = run; if (stunned(r, a)) return;
    const blight = r.type === "twig-blight", h = r.attackRange || 40, p = blight && r.isBoss ? Math.max(h, 72) : h, mm = blight && r.isBoss ? 52 : 30;
    const gx = r.groupCenterX ?? r.originalX ?? r.x, gy = r.groupCenterY ?? r.originalY ?? r.y, A = hyp(r.x - gx, r.y - gy), v = !blight ? (r.isBoss ? 400 : 260) : r.isBoss ? 340 : 200, x = blight && r.hitFlash > 0.05, w = x ? 1.35 : 1.05;
    let n = r.x, sy = r.y, u = 9999; if (t && t.health > 0) { n = t.x; sy = t.y; u = hyp(r.x - n, r.y - sy); }
    const M = !!(t && t.health > 0 && u <= 1.25 * p);
    if (A > v * w && !M) { const q = A || 1, sp = 1.15 * (r.speed || 40); r.state = blight ? "walk" : "move"; r.x += ((gx - r.x) / q) * sp * e; r.y += ((gy - r.y) / q) * sp * e; r.facingRight = gx - r.x > 0; r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a); r.attackDamageApplied = false; r.animFrame = 0; r.animTimer = 0; return; }
    const C = x ? 375 : 300, k = !!(t && t.health > 0 && u < C && (A <= v * w || M));
    if (r.state === "hitting" || r.state === "attack") {
      if (!blight && !r.attackDamageApplied && !canFlyAttack(i, r)) { Object.assign(r, { state: "idle", animFrame: 0, animTimer: 0, attackCooldown: Math.max(r.attackCooldown || 0, 0.35) }); return; }
      if (blight && t && t.health > 0) { const dx = t.x - r.x, dy = t.y - r.y, aa = dx * dx + dy * dy; if (aa > p * p * 0.7) { const q = Math.sqrt(aa) || 1, sp = 0.55 * (r.speed || 40); r.x += (dx / q) * sp * e; r.y += (dy / q) * sp * e; r.facingRight = dx > 0; } }
      for (r.animTimer = (r.animTimer || 0) + a; r.animTimer > 0.1;) {
        r.animTimer -= 0.1; r.animFrame = (r.animFrame || 0) + 1;
        if (r.animFrame >= (blight ? 3 : 2) && !r.attackDamageApplied) {
          if (!blight) { if (!(spawnMiniFlies(s, i, r, mapId) > 0)) { Object.assign(r, { state: "idle", animFrame: 0, animTimer: 0, attackCooldown: Math.max(r.attackCooldown || 0, 0.35) }); break; } r.attackDamageApplied = true; }
          else if (t && t.health > 0 && hyp(r.x - t.x, r.y - t.y) < (r.isBoss ? p + 28 : Math.max(70, p + 18))) { queue(t, r.attack * dtm(i), 0.3, 1); r.attackDamageApplied = true; }
        }
        if (r.animFrame >= (blight ? 6 : 4)) { r.state = "idle"; r.attackCooldown = blight ? 1 : 3; r.attackDamageApplied = false; break; }
      }
    } else {
      r.attackCooldown = Math.max(0, (r.attackCooldown || 0) - a);
      if (!blight) {
        if (k && u < 200 && r.attackCooldown <= 0 && canFlyAttack(i, r)) Object.assign(r, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false });
        else if (k) { r.state = "move"; const dx = n - r.x, dy = sy - r.y; if (u > 150) { const sp = r.speed || 60; r.x += (dx / u) * sp * e; r.y += (dy / u) * sp * e; r.facingRight = dx > 0; } else if (u < 100) { const sp = 0.5 * (r.speed || 60); r.x -= (dx / u) * sp * e; r.y -= (dy / u) * sp * e; } }
        else r.state = "idle";
      } else if (k && u < p && r.attackCooldown <= 0) Object.assign(r, { state: "hitting", animFrame: 0, animTimer: 0, attackDamageApplied: false });
      else if (k) { r.state = "walk"; const dx = n - r.x, dy = sy - r.y; if (u > mm) { const sp = r.speed || 40; r.x += (dx / u) * sp * e; r.y += (dy / u) * sp * e; r.facingRight = dx > 0; } }
      else r.state = "idle";
    }
  }

  // ------------------------------------------------------------------ the parrot (Birb fI.updateParrot)
  const CONTACT_SKIP = new Set(["mini-fly", "twig-blight", "masked-forest-spirit", "flower-monster", "harpy", "ice-harpy", "witch", "anubis", "anubis-warrior", "fishfolk-archpriest", "cultist", ...GENERIC, "imp", "cacodaemon"]);
  X.updateParrot = function (s, run, dt, px, py) {
    const p = run.parrot; if (!p) return; const a = dt * K.COMBAT_FEEL, b = X.bounds(s.currentMap), B = X.bonuses || X.parrotBonuses(s);
    // venom (Birb updateParrotPoison)
    let n = Math.max(0, Math.floor(+p.poisonTicksRemaining || 0));
    if (n > 0) { p.poisonTickTimer = Math.max(0, +p.poisonTickTimer || K.COBRA_TICK) - dt; while (n > 0 && p.poisonTickTimer <= 0 && p.health > 0) { const t = Math.max(0, +p.poisonDamagePerTick || 0); if (t > 0) { p.health = Math.max(0, p.health - t); X.dmgNumber(run, p, "-" + PT.fmt(t), "#a3e635"); RT.regenPenalty = 3; } n--; p.poisonTickTimer += K.COBRA_TICK; } p.poisonTicksRemaining = n; if (n <= 0) { p.poisonTickTimer = 0; p.poisonDamagePerTick = 0; } }
    const fighting = RT.regenPenalty > 0; RT.regenPenalty = Math.max(0, RT.regenPenalty - dt);
    // death (Birb totemRuntime.updateDeath): 5 frames at 0.1 s, then the run ends
    if (p.health <= 0 && p.state !== "death") { p.state = "death"; p.animTimer = 0; p.animFrame = 0; }
    if (p.state === "death") { for (p.animTimer += a; p.animTimer > 0.1;) { p.animTimer -= 0.1; p.animFrame++; if (p.animFrame >= 5) { if (!p.deathHandled) { p.deathHandled = true; X.onParrotDeath && X.onParrotDeath(s); } break; } } return; }
    const ts = tState(p); ts.commit = Math.max(0, ts.commit - a); for (const [k, v] of ts.blocked) v <= a ? ts.blocked.delete(k) : ts.blocked.set(k, v - a); if (ts.target !== p.targetEnemyId) { ts.target = p.targetEnemyId; ts.commit = 0.55; ts.stuck = 0; }
    // regen: x0.25 for 3 s after taking damage (artifact / desert reductions shrink the penalty)
    if (p.health < p.maxHealth && B.lifeRegen > 0) { const red = Math.max(0, Math.min(1, (X.externalBonuses(s).combatRegenPenaltyReduction || 0) + (B.combatRegenPenaltyReduction || 0))), m = fighting ? 1 - 0.75 * (1 - red) : 1; p.health = Math.min(p.maxHealth, p.health + B.lifeRegen * m * (X.regenMult ? X.regenMult(s, p) : 1) * dt); }
    if (p.state === "take_damage") {
      p.stunTimer = Math.max(0, (p.stunTimer ?? 0) - a);
      if (p.stunTimer <= 0) { const e = X.byId(run, p.targetEnemyId); if (X.validTarget(e)) p.state = "attack"; else { p.state = "return"; p.targetEnemyId = null; p.manualTargetEnemyId = null; } }
      return;
    }
    const snap = Math.max(1e3, K.LEASH * X.rangeMult() + 650);
    if ((p.x === 0 && p.y === 0) || (p.x - px) ** 2 + (p.y - py) ** 2 > snap * snap) { p.x = px - 40; p.y = py - 40; }
    if (!inLeash(p.x, p.y, px, py) && /^attack/.test(p.state)) Object.assign(p, { state: "return", targetEnemyId: null, manualTargetEnemyId: null, animFrame: 0, animTimer: 0 });
    p.hitCooldown = Math.max(0, (p.hitCooldown ?? 0) - a);
    const M = Math.max(0.2, 1 + (B.attackSpeedMult || 0) + (X.tempAttackSpeed ? X.tempAttackSpeed(run) : 0)), S = Math.max(0.25, 1 + (B.moveSpeedMult || 0) + (X.tempMoveSpeed ? X.tempMoveSpeed(run) : 0)), ok = (pt) => inLeash(pt.x, pt.y, px, py);
    if (PT.expState(s).isAutoAttack && !p.targetEnemyId && /^(idle|follow|return)$/.test(p.state)) { const e = scan(s, run, p.x, p.y, px, py, b); if (e) { p.targetEnemyId = e; p.manualTargetEnemyId = null; p.state = "attack"; } }
    if (p.state === "idle") { const e = followTarget(p, px, py, b); if ((e.x - p.x) ** 2 + (e.y - p.y) ** 2 > 4900) p.state = "follow"; else p.facingRight = followSide(p, px) < 0; }
    else if (p.state === "follow") { const e = followTarget(p, px, py, b); if ((e.x - p.x) ** 2 + (e.y - p.y) ** 2 < 100) p.state = "idle"; else { fly(p, e, 0, p.speed * S, a, b); p.facingRight = followSide(p, px) < 0; } }
    else if (p.state === "attack") {
      if (!p.manualTargetEnemyId || p.manualTargetEnemyId !== p.targetEnemyId) { const e = smarter(run, p.x, p.y, px, py, p.targetEnemyId, b); if (e && e !== p.targetEnemyId) p.targetEnemyId = e; }
      const e = X.byId(run, p.targetEnemyId);
      if (X.validTarget(e) && canMaintain(p, e, px, py, b)) { const sa = strikeAnchor(p, e, px, py, b); if ((hyp(sa.x - p.x, sa.y - p.y) || 1) <= 8) { p.state = "attacking"; p.animFrame = 0; p.animTimer = 0; } else { tacMove(p, sa, 1.1 * p.speed * S, a, b, ok); p.facingRight = e.x > p.x; } }
      else retarget(s, run, p, px, py, b);
    } else if (p.state === "attacking") {
      const e = X.byId(run, p.targetEnemyId);
      if (X.validTarget(e) && canMaintain(p, e, px, py, b)) {
        const sa = strikeAnchor(p, e, px, py, b); if ((hyp(sa.x - p.x, sa.y - p.y) || 1) > 10) tacMove(p, sa, 1.1 * p.speed * S, a, b, ok);
        p.facingRight = e.x > p.x; p.animTimer += a; const step = 0.1 / M;
        while (p.animTimer > step) {
          p.animTimer -= step; p.animFrame++;
          if (p.animFrame === 2) {
            if (hyp(sa.x - p.x, sa.y - p.y) > 18) { p.state = "attack"; p.animFrame = 0; p.animTimer = 0; break; }
            if (X.validTarget(e)) X.parrotHit(s, run, p, e); // Birb: the hit, with artifact procs (expedition_loot.js)
          }
          if (p.animFrame >= 4) { if (X.validTarget(e) && canMaintain(p, e, px, py, b)) { p.state = "attack_wait"; p.animTimer = 0.6 / M; } else retarget(s, run, p, px, py, b); break; }
        }
      } else retarget(s, run, p, px, py, b);
    } else if (p.state === "attack_wait") {
      if (!p.manualTargetEnemyId || p.manualTargetEnemyId !== p.targetEnemyId) { const e = smarter(run, p.x, p.y, px, py, p.targetEnemyId, b); if (e && e !== p.targetEnemyId) p.targetEnemyId = e; }
      p.animTimer -= a; const e = X.byId(run, p.targetEnemyId);
      if (X.validTarget(e) && canMaintain(p, e, px, py, b)) { const sa = strikeAnchor(p, e, px, py, b); p.facingRight = e.x > p.x; if ((hyp(sa.x - p.x, sa.y - p.y) || 1) > 10) tacMove(p, sa, 1.1 * p.speed * S, a, b, ok); if (p.animTimer <= 0) { p.state = "attacking"; p.animFrame = 0; p.animTimer = 0; } }
      else retarget(s, run, p, px, py, b);
    } else if (p.state === "return") { const e = followTarget(p, px, py, b); if ((e.x - p.x) ** 2 + (e.y - p.y) ** 2 < 225) p.state = "idle"; else { fly(p, e, 0, 1.1 * p.speed * S, a, b); p.facingRight = followSide(p, px) < 0; } }
    p.x = Math.max(b.minX, Math.min(b.maxX, p.x)); p.y = Math.max(b.minY, Math.min(b.maxY, p.y));
    // contact damage from anything not in Birb's skip list (none of the current floor types)
    for (const k of run.enemies) {
      if (k.health <= 0 || CONTACT_SKIP.has(k.type)) continue;
      if ((k.x - p.x) ** 2 + (k.y - p.y) ** 2 < 625 && p.state !== "take_damage" && (p.hitCooldown ?? 0) <= 0) { const t = 0.5 * k.attack * dtm(run), f = /^attack/.test(p.state); p.health = Math.max(0, p.health - t); if (p.health > 0 && !f) Object.assign(p, { state: "take_damage", animFrame: 0, animTimer: 0, stunTimer: 0.3 }); p.hitCooldown = 2; }
    }
  };
  // Birb: enemies on this list are never stunned by parrot hits; the rest (and not bosses) get 0.3 s
  const NO_STUN = new Set(["harpy", "ice-harpy", "witch", "anubis", "anubis-warrior", "fishfolk-archpriest", "twig-blight", "cobra", "ghoul", "skeleton-warrior", "elven-assassin", "zombie-cultist", "shardsoul-slayer",
    "fishfolk-whipe", "fishfolk-brute", "fishfolk-horror", "fishfolk-pugilist", "sea-horror", "sea-gramlin", "elemental", "frost-wisp", "ghost", "doppelganger", "black-pudding", "giant-black-pudding", "hell-critter", "imp",
    "cacodaemon", "arctic-whisper", "frozy-cube", "frosty-slime", "ice-fire-guardian", "frogfolk-wizard", "frogfolk-brute", "frogfolk-chieftain", "fishfolk-inkbender", "mummy", "giant-fly"]);
  X.hitStun = (e) => (e.isBoss || NO_STUN.has(e.type) || String(e.type).includes("masked-forest-spirit") ? 0 : 0.3);
  X.parrotHit = function (s, run, p, e) { // replaced by the artifact version in expedition_loot.js
    const dmg = Math.max(0, p.damage); e.stunTimer = X.hitStun(e); e.health = Math.max(0, e.health - dmg); e.hitFlash = 0.06;
    if (e.health <= 0) X.primeOnKill(s, e); X.dmgNumber(run, e, PT.fmt(dmg), "#ff4444");
  };

  // ------------------------------------------------------------------ per-frame driver (Birb updateCurrentMap)
  X.update = function (G, dt) {
    const s = G.s, e = PT.expState(s), run = e.activeRun; X.syncUnlock(s);
    if (!X.bonuses || G.expBonusT === undefined || (G.expBonusT -= dt) <= 0) { X.bonuses = X.parrotBonuses(s); G.expBonusT = 1; }
    if (!run || !X.isRunMap(s.currentMap)) return;
    run.elapsedTime = (Date.now() - run.startTime) / 1e3;
    if (X.fieldNotesRate(s) > 0) { G.fieldNotes = (G.fieldNotes || 0) + X.fieldNotesRate(s) * dt; if (G.fieldNotes >= 1) { const k = Math.floor(G.fieldNotes); G.fieldNotes -= k; X.grantSkillPoints(s, k); } }
    if (e.isAutoAttack) run.combatArmed = true;
    if (run.combatArmed) { X.updateEnemies(s, run, dt, s.player.x, s.player.y); X.updateParrot(s, run, dt, s.player.x, s.player.y); }
    else { const p = run.parrot; if (p && p.state !== "death" && (p.x - s.player.x) ** 2 + (p.y - s.player.y) ** 2 > 1e6) { p.x = s.player.x - 40; p.y = s.player.y - 40; } }
    for (const d of run.damageNumbers) { d.life -= dt; d.y -= 26 * dt; }
    run.damageNumbers = run.damageNumbers.filter((d) => d.life > 0);
    // portals: next floor while the boss is down, back to the hub at the entrance
    const m = s.currentMap, P = s.player;
    if (run.exitPortal?.active) { const q = X.portal(m, "next_floor"); if (q && (P.x - q.x) ** 2 + (P.y - q.y) ** 2 <= q.radius * q.radius) X.advanceFloor(G); }
  };
})();
