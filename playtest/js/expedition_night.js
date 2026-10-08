// Phase 6c: night mode (Birb activeRun.nightMode). Parrot rebirb III opens it; it is floor 1 only, on its own procedural map
// (Birb map 32: a trail through forest and ponds), with three night enemies and an ice-fire guardian boss. Stats and loot use
// floor 10 + floor - 1 (expedition.js X.qt); mythic auras can drop (expedition_loot.js). Clearing the boss portal ends the run as a success.
// Numbers copied from Birb: the trail / pond layout (maps be / xe / pe / Me), Uo (assassin), Oo (cultist leap), Ho / zo / Qo (guardian).
(function () {
  const PT = window.PT, X = PT.EXP, hyp = Math.hypot;

  // ------------------------------------------------------------------ night map walkability (Birb maps Ce / Pe / ze / ve / Re)
  const TILE = 64, PORTAL_IN = [1472, 5248], PORTAL_OUT = [704, 288];
  const TRAIL = [PORTAL_IN, [1472, 4800], [1152, 4352], [1344, 3904], [1792, 3520], [1600, 3008], [1216, 2688], [1024, 2176], [1472, 1664], [1536, 1088], [1408, 448], PORTAL_OUT];
  const SIDE = [[[1152, 4352], [576, 4224], [448, 3712], [704, 3264], [1216, 2688]], [[1792, 3520], [2240, 3584], [2432, 3008], [2304, 2496], [1984, 2240], [1472, 1664]],
    [[1024, 2176], [576, 1920], [512, 1408], [832, 1088], [1536, 1088]]];
  const PONDS = [{ x: 608, y: 4832, rx: 400, ry: 256 }, { x: 2176, y: 4352, rx: 432, ry: 384 }, { x: 832, y: 3648, rx: 288, ry: 384 }, { x: 1856, y: 2752, rx: 352, ry: 320 },
    { x: 640, y: 2496, rx: 320, ry: 256 }, { x: 960, y: 1536, rx: 288, ry: 320 }, { x: 2240, y: 1280, rx: 384, ry: 448 }];
  const CLEARINGS = [{ x: PORTAL_IN[0], y: PORTAL_IN[1], radius: 256 }, { x: 1408, y: 448, radius: 352 }, { x: PORTAL_OUT[0], y: PORTAL_OUT[1], radius: 192 }, { x: 1472, y: 1664, radius: 192 },
    { x: 1216, y: 2688, radius: 192 }, { x: 1792, y: 3520, radius: 192 }, { x: 1152, y: 4352, radius: 192 }];
  const segDist = (x, y, pts) => { let t = Infinity; for (let a = 1; a < pts.length; a++) { const [n, r] = pts[a - 1], [o, i] = pts[a], g = o - n, l = i - r, w = Math.max(0, Math.min(1, ((x - n) * g + (y - r) * l) / (g * g + l * l))); t = Math.min(t, hyp(x - n - w * g, y - r - w * l)); } return t; };
  const onTrail = (x, y, pad = 0) => segDist(x, y, TRAIL) < 100 + pad || SIDE.some((p) => segDist(x, y, p) < 62 + pad) || CLEARINGS.some((c) => hyp(x - c.x, y - c.y) < c.radius + pad);
  const inPond = (x, y) => !onTrail(x, y, 24) && PONDS.some((p) => { const t = (x - p.x) / p.rx, a = (y - p.y) / p.ry, n = 1 + 0.07 * Math.sin(5 * Math.atan2(a, t)); return !(p.x === 2240 && hyp(x - 2240, y - 1280) < 112) && t * t + a * a < n; });
  const tile = (i, j) => { const x = (i + 0.5) * TILE, y = (j + 0.5) * TILE; return inPond(x, y) ? "water" : onTrail(x, y, 40) ? "trail" : "forest"; };
  X.nightWalkable = function (x, y) {
    if (!Number.isFinite(x) || !Number.isFinite(y) || !onTrail(x, y, -16)) return false;
    for (let j = Math.floor((y - 24) / TILE); j <= Math.floor((y + 24) / TILE); j++) for (let i = Math.floor((x - 24) / TILE); i <= Math.floor((x + 24) / TILE); i++) if (tile(i, j) !== "trail") return false;
    return true;
  };
  { const sb = X.spawnBlocked; X.spawnBlocked = (mapId, x, y) => (mapId === X.NIGHT_MAP && !X.nightWalkable(x, y)) || sb(mapId, x, y); } // Birb isEnemySpawnBlockedByCollision

  // Birb getProjectileWallImpact: the first collision box a segment crosses (boxes padded by r)
  X.wallImpact = function (mapId, x1, y1, x2, y2, r = 6) {
    const s = x2 - x1, o = y2 - y1; let best = Infinity;
    for (const c of X.collisions(mapId)) {
      const L = c.left - r, R = c.right + r, T = c.top - r, B = c.bottom + r; let u = 0, h = 1;
      const slab = (p, d, lo, hi) => { if (Math.abs(d) <= 1e-8) return p >= lo && p <= hi; const a = 1 / d; let t0 = (lo - p) * a, t1 = (hi - p) * a; if (t0 > t1) [t0, t1] = [t1, t0]; u = Math.max(u, t0); h = Math.min(h, t1); return u <= h; };
      if (slab(x1, s, L, R) && slab(y1, o, T, B) && u >= 0 && u <= 1) best = Math.min(best, u);
    }
    return Number.isFinite(best) ? { x: x1 + s * best, y: y1 + o * best, t: best } : null;
  };

  // ------------------------------------------------------------------ night enemies
  const ASSASSIN = { disappear: 0.32, fall: 0.24, landing: 0.3, recovery: 0.2, cooldown: 5, impact: 0.06, damageMultiplier: 1.15 }; // Birb Uo
  const LEAP = { minRange: 80, maxRange: 240, windup: 0.15, flight: 0.27, recovery: 0.18, height: 18, cooldown: 4.8, meleeRecovery: 0.8 }; // Birb Oo
  const GUARD = { scale: 2.9, attackRange: 108, parrotDistance: 72, combatAnchorY: 90, enrageHealthRatio: 0.5, enrageAnimationSpeed: 1.1, enrageCooldownMultiplier: 0.7 }; // Birb Ho
  const GUARD_SEQ = ["slash", "thrust", "slash", "ascend"]; // Birb zo
  const GUARD_ATK = { slash: { frames: 6, frameSeconds: 0.09, cooldown: 1.3, hits: [{ frame: 1, damage: 1 }] }, thrust: { frames: 8, frameSeconds: 0.085, cooldown: 1.55, hits: [{ frame: 4, damage: 1.15 }] },
    ascend: { frames: 15, frameSeconds: 0.095, cooldown: 2, hits: [{ frame: 2, damage: 0.35 }, { frame: 9, damage: 1.1 }] } }; // Birb Qo
  const dtm = (run) => X.dmgTakenMult(run), queue = (p, dmg) => X.queueParrotHit(p, dmg, 0.08, 0.35);
  const leash = (e) => (e.isBoss ? 420 : 280);
  const assassinBusy = (e) => e.type === "elven-assassin" && e.health > 0 && !!e.elvenAssassin && e.elvenAssassin.phase !== "hunt"; // Birb Lo
  const leapBusy = (e) => e.type === "zombie-cultist" && e.health > 0 && !!e.zombieCultist && e.zombieCultist.phase !== "hunt"; // Birb _o
  const crowded = (run, n) => run.enemies.some((e) => e !== n && (assassinBusy(e) || leapBusy(e)) && hyp(e.x - n.x, e.y - n.y) < 480);

  // Birb PT / NT / LT: the elven assassin vanishes after two blade swings and drops behind the parrot
  const aPhase = (e, t, ph) => { Object.assign(t, { phase: ph, elapsed: 0, hitApplied: false }); Object.assign(e, { animFrame: 0, animTimer: 0, attackDamageApplied: false, state: ph === "hunt" || ph === "recovery" ? "idle" : "attack" }); };
  const behind = (s, t, n) => { const i = X.respawnPos(t), mapId = s.currentMap, r = 0.7 * X.triggerRange(t), side = t.facingRight ? -1 : 1, o = X.safePoint(mapId, n.x + side * r, n.y, X.bounds(mapId));
    return !o || hyp(o.x - n.x, o.y - n.y) > r + 36 || hyp(o.x - i.x, o.y - i.y) > leash(t) || X.wallImpact(mapId, t.x, t.y, o.x, o.y, 12) ? null : o; };
  function assassin(s, run, n, dt) {
    const a = (n.elvenAssassin ??= { phase: "hunt", elapsed: 0, cooldown: 0, bladeAttacks: 0, wasAttacking: false, targetX: n.x, targetY: n.y, hitApplied: false });
    const r = run.parrot, sp = X.respawnPos(n), near = r && hyp(r.x - sp.x, r.y - sp.y) <= leash(n);
    if (!r || r.health <= 0 || !near) { if (a.phase !== "hunt") { aPhase(n, a, "hunt"); a.cooldown = ASSASSIN.cooldown; } a.bladeAttacks = 0; a.wasAttacking = false; return false; }
    a.cooldown = Math.max(0, a.cooldown - dt);
    if (a.phase === "hunt") {
      if (a.wasAttacking && n.state !== "attack") a.bladeAttacks++;
      a.wasAttacking = n.state === "attack";
      if (a.wasAttacking || a.bladeAttacks < 2 || a.cooldown > 0 || hyp(r.x - n.x, r.y - n.y) > 180 || crowded(run, n)) return false;
      n.facingRight = r.x >= n.x; const i = behind(s, n, r);
      if (!i) { a.cooldown = 1; return false; }
      Object.assign(a, { targetX: i.x, targetY: i.y, bladeAttacks: 0, wasAttacking: false, cooldown: ASSASSIN.cooldown }); aPhase(n, a, "disappear"); return true;
    }
    a.elapsed += Math.min(Math.max(dt, 0), 0.1); n.targetX = n.x; n.targetY = n.y; n.stunTimer = 0;
    if ((a.phase === "disappear" && a.elapsed >= ASSASSIN.disappear) || a.phase === "fall" || (a.phase === "landing" && !a.hitApplied)) {
      const t = behind(s, n, r); if (!t) { aPhase(n, a, "hunt"); a.cooldown = 1; return true; }
      a.targetX = n.x = t.x; a.targetY = n.y = t.y;
    }
    if (a.phase === "disappear" && a.elapsed >= ASSASSIN.disappear) { n.x = a.targetX; n.y = a.targetY; aPhase(n, a, "fall"); }
    else if (a.phase === "fall" && a.elapsed >= ASSASSIN.fall) aPhase(n, a, "landing");
    else if (a.phase === "landing") { if (a.elapsed >= ASSASSIN.impact && !a.hitApplied) { a.hitApplied = true; queue(r, n.attack * ASSASSIN.damageMultiplier * dtm(run)); } if (a.elapsed >= ASSASSIN.landing) aPhase(n, a, "recovery"); }
    else if (a.phase === "recovery" && a.elapsed >= ASSASSIN.recovery) { aPhase(n, a, "hunt"); n.attackCooldown = 0.65; }
    return true;
  }
  // Birb _T / DT / qT: the zombie cultist winds up and leaps onto the parrot
  const lPhase = (e, t, ph) => { t.phase = ph; t.elapsed = 0; Object.assign(e, { state: ph === "hunt" ? "idle" : "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false, targetX: e.x, targetY: e.y }); };
  const landing = (s, t, n, i) => { const a = X.respawnPos(t), mapId = s.currentMap, r = X.safePoint(mapId, n.x + i.offsetX, n.y + i.offsetY, X.bounds(mapId));
    return !r || hyp(r.x - i.startX, r.y - i.startY) > LEAP.maxRange || hyp(r.x - a.x, r.y - a.y) > leash(t) || hyp(r.x - n.x, r.y - n.y) > X.triggerRange(t) || X.wallImpact(mapId, t.x, t.y, r.x, r.y, 12) || X.wallImpact(mapId, r.x, r.y, n.x, n.y, 2) ? null : r; };
  function leaper(s, run, n, dt) {
    if (n.state === "respawn" || n.health <= 0) return false;
    const a = (n.zombieCultist ??= { phase: "hunt", elapsed: 0, cooldown: 0, startX: n.x, startY: n.y, offsetX: 0, offsetY: 0 }), r = run.parrot, sp = X.respawnPos(n);
    const near = r && r.health > 0 && hyp(r.x - sp.x, r.y - sp.y) <= leash(n), l = Math.min(Math.max(dt, 0), 0.1);
    a.cooldown = Math.max(0, a.cooldown - Math.max(0, dt));
    if (a.phase === "hunt") {
      if (!near || a.cooldown > 0 || n.attackCooldown > 0 || n.state === "attack" || (n.stunTimer ?? 0) > 0) return false;
      const ix = n.x - r.x, iy = n.y - r.y, d = hyp(ix, iy); if (d < LEAP.minRange || d > LEAP.maxRange || crowded(run, n)) return false;
      const c = 0.7 * X.triggerRange(n); Object.assign(a, { startX: n.x, startY: n.y, offsetX: (ix / d) * c, offsetY: (iy / d) * c });
      if (landing(s, n, r, a)) { n.facingRight = r.x >= n.x; a.cooldown = LEAP.cooldown; lPhase(n, a, "windup"); return true; }
      a.cooldown = 0.5; return false;
    }
    n.stunTimer = 0;
    if (a.phase === "recovery") { a.elapsed += l; if (a.elapsed >= LEAP.recovery) { lPhase(n, a, "hunt"); n.attackCooldown = LEAP.meleeRecovery; } return true; }
    const c = near ? landing(s, n, r, a) : null; if (!c) { lPhase(n, a, "recovery"); return true; }
    const d = a.elapsed; a.elapsed += l;
    if (a.phase === "windup") { if (a.elapsed >= LEAP.windup) lPhase(n, a, "flight"); return true; }
    const u = Math.min(1, l / Math.max(0.001, LEAP.flight - d)); n.x += (c.x - n.x) * u; n.y += (c.y - n.y) * u; n.targetX = n.renderX = n.x; n.targetY = n.renderY = n.y;
    if (a.elapsed >= LEAP.flight) { queue(r, n.attack * dtm(run)); lPhase(n, a, "recovery"); }
    return true;
  }
  X.nightPreAI = (s, run, r, dt) => (r.type === "elven-assassin" && assassin(s, run, r, dt)) || (r.type === "zombie-cultist" && leaper(s, run, r, dt));

  // Birb $T: the ice-fire guardian boss cycles slash / thrust / slash / ascend, faster below half health
  X.guardianAI = function (s, run, n, a) {
    const g = (n.guardianBoss ??= { attack: null, elapsed: 0, sequence: 0, hitsApplied: 0, enraged: false }), r = run.parrot;
    if (!r || r.health <= 0) { if (g.attack) { g.attack = null; n.state = "idle"; n.animFrame = n.animTimer = 0; n.attackCooldown = 0.6; } return false; }
    const an = X.anchor(n), o = hyp(r.x - an.x, r.y - an.y);
    if (!g.attack) {
      if (n.attackCooldown > 0 || o >= GUARD.attackRange || X.wallImpact(s.currentMap, an.x, an.y, r.x, r.y, 2)) return false;
      g.enraged = g.enraged || n.health / Math.max(1, n.maxHealth) <= GUARD.enrageHealthRatio; g.attack = GUARD_SEQ[g.sequence % GUARD_SEQ.length]; g.sequence++; g.elapsed = 0; g.hitsApplied = 0;
      Object.assign(n, { state: "attack", animFrame: 0, animTimer: 0, attackDamageApplied: false, facingRight: r.x >= an.x, targetX: n.x, targetY: n.y }); return true;
    }
    const l = GUARD_ATK[g.attack], c = g.enraged ? GUARD.enrageAnimationSpeed : 1;
    g.elapsed += Math.min(0.1, Math.max(0, a)) * c; n.state = "attack"; n.stunTimer = 0; n.animFrame = Math.min(l.frames - 1, Math.floor(g.elapsed / l.frameSeconds)); n.animTimer = g.elapsed % l.frameSeconds;
    while (g.hitsApplied < l.hits.length) {
      const h = l.hits[g.hitsApplied]; if (g.elapsed < h.frame * l.frameSeconds) break; g.hitsApplied++;
      if (o > GUARD.attackRange + 36 || X.wallImpact(s.currentMap, an.x, an.y, r.x, r.y, 2)) continue;
      queue(r, n.attack * h.damage * dtm(run)); n.attackDamageApplied = true;
    }
    if (g.elapsed >= l.frames * l.frameSeconds) { g.attack = null; n.state = "idle"; n.animFrame = n.animTimer = 0; n.attackCooldown = l.cooldown * (g.enraged ? GUARD.enrageCooldownMultiplier : 1); }
    return true;
  };
})();
