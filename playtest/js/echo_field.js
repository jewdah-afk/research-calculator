// Phase 7: the Echo Field (Birb map 30, "echo-field"), left of the Sunflower Field's archivist tree.
// Plain popcorn only. Eating one has a 25% (up to 35%) chance to spawn a pair: 1 plain + 1 purple Echo. Purple popcorn
// pays Echo Popcorn (Echo Value x Birb Tn). The field holds 2 + 2 per Resonant Field level (2..40). Mushrooms (Awakened
// Mycelium...) pick popcorn up by themselves, and while they exist the field keeps running when you are away.
(function () {
  const PT = window.PT, D = PT.D, M = (PT.ECHO_FIELD_MAP = 30);
  PT.MAPS[M] = { id: M, key: "echo-field", name: "ECHO FIELD", w: PT.ECHO_FIELD_W, h: PT.ECHO_FIELD_H };
  const st = { pending: { plain: 0, echo: 0 }, credit: 0, active: false, floatAmount: D(0) };
  PT.echoRuntime = st;
  PT.echoFieldLive = (s, currentMap = s.currentMap) => (currentMap === M || PT.echoMushroomRate(s) > 0) && PT.echoFieldOpen(s); // Birb JC

  // travel (Birb Vb / Xb): the Sunflower Field's left arrow leads here while the archivist tree is in view
  { const tt = PT.travelTarget, tb = PT.travelBlock;
    PT.travelTarget = (s, dir) => (s.currentMap === 1 && dir < 0 && s.sunflowerTreeView === "archivist" && PT.archivistTreeOpen(s) ? M : s.currentMap === M ? (dir > 0 ? 1 : -99) : tt(s, dir));
    PT.travelBlock = (s, dir) => {
      if (s.currentMap === M) return dir > 0 ? "" : "end";
      if (s.currentMap === 1 && dir < 0 && s.sunflowerTreeView === "archivist" && PT.archivistTreeOpen(s)) return PT.echoFieldOpen(s) ? "" : "Buy Popcorn Echo to open the Echo Field";
      return tb(s, dir);
    }; }

  // Birb wI.spawnPopcorn for map 30 (plain only, 0.2 s pickup delay; half near a mushroom with Meeting Points)
  const spawnPlain = (s, field) => {
    const b = PT.echoBounds(); let x = b.left + Math.random() * (b.right - b.left), y = b.top + Math.random() * (b.bottom - b.top);
    const res = PT.echoNode(s, "A2") ? PT.echoMushrooms(s) : [];
    if (res.length && Math.random() < 0.5) { const e = res[Math.floor(Math.random() * res.length)], t = Math.random() * Math.PI * 2, a = 240 * Math.sqrt(Math.random()); x = Math.max(b.left, Math.min(b.right, e.x + Math.cos(t) * a)); y = Math.max(b.top, Math.min(b.bottom, e.y + Math.sin(t) * a)); }
    field.list(M).push({ id: field.nextId++, type: "plain", x, y, pickupDelay: 0.2 });
  };
  // Birb spawnEchoPopcorn: a plain popcorn eaten here may answer with 1 plain + 1 echo (75% near it with Nearby Response)
  const spawnPair = (s, field, p) => {
    if (p.type !== "plain" || Math.random() >= PT.echoChance(s)) return;
    const b = PT.echoBounds(), near = PT.echoNode(s, "R1"), cap = st.cap ?? 2;
    for (const type of ["echo", "plain"]) { // Birb builds [plain, echo] and reverses it
      const n = near && Math.random() < 0.75, a = Math.random() * Math.PI * 2, r = Math.sqrt(8100 + 24300 * Math.random());
      if (field.list(M).length >= cap) { st.pending[type]++; continue; }
      field.list(M).push({ id: field.nextId++, type, spawnedByEcho: true, pickupDelay: 0.35,
        x: n ? Math.max(b.left, Math.min(b.right, p.x + Math.cos(a) * r)) : b.left + Math.random() * (b.right - b.left),
        y: n ? Math.max(b.top, Math.min(b.bottom, p.y + Math.sin(a) * r)) : b.top + Math.random() * (b.bottom - b.top) });
    }
  };
  // Birb awardCollectedPopcorn on map 30: purple pays echo, plain may echo and still pays normal popcorn
  PT.collectEcho = function (G, p) {
    const s = G.s; if (!PT.echoFieldLive(s, M)) return;
    if (p.type === "echo") {
      const v = D(PT.effect(s, "p_echo_value")); if (v.lte(0)) return;
      const g = PT.echoGrove(s); PT.add(s, "echoPopcorn", v); g.lifetimeEarned = PT.num(D(g.lifetimeEarned).add(v)); G.gain && G.gain("echoPopcorn", v); st.floatAmount = st.floatAmount.add(v);
      return;
    }
    if (PT.echoFieldOpen(s)) spawnPair(s, G.field, p);
    PT.award(G, p, "player");
  };

  // Birb popcornSystem.update(map 30) + the grove's mushroom collector
  PT.updateEchoField = function (G, dt, prof) {
    const s = G.s, field = G.field, here = s.currentMap === M;
    if (!PT.echoFieldOpen(s)) { field.list(M).length = 0; st.pending = { plain: 0, echo: 0 }; st.active = false; st.credit = 0; return; }
    const live = PT.echoFieldLive(s); if (!live) { st.credit = 0; st.active = false; return; }
    PT.echoGrove(s);
    const arr = field.list(M), cap = (st.cap = Math.max(2, Math.min(40, PT.echoCapacity(s))));
    for (const k of ["echo", "plain"]) while (st.pending[k] > 0 && arr.length < cap) { st.pending[k]--; const b = PT.echoBounds(); arr.push({ id: field.nextId++, type: k, spawnedByEcho: true, pickupDelay: 0.35, x: b.left + Math.random() * (b.right - b.left), y: b.top + Math.random() * (b.bottom - b.top) }); }
    for (const p of arr) p.pickupDelay = Math.max(0, (p.pickupDelay || 0) - dt);
    let c = field.timer.get(M) || 0;
    if (arr.length < cap && st.pending.echo + st.pending.plain === 0) { c += dt; const l = Math.max(1e-4, PT.spawnInterval(s)); let room = cap - arr.length; while (c >= l && room > 0) { c -= l; spawnPlain(s, field); room--; } }
    field.timer.set(M, c);
    // mushrooms (Birb: collectorCredit += rate x dt, one pickup per credit within reach of any mushroom)
    const r = st.active ? Math.min(0.1, Math.max(0, dt)) : 0; st.active = true;
    if (r > 0 && (st.credit += PT.echoMushroomRate(s) * r) >= 1) {
      const ms = PT.echoMushrooms(s), reach = PT.echoMushroomReach(s), i = arr.findIndex((p) => (p.pickupDelay || 0) <= 0 && ms.some((m) => Math.hypot(p.x - m.x, p.y - m.y) <= reach));
      if (i >= 0) { st.credit--; PT.collectEcho(G, arr.splice(i, 1)[0]); } else st.credit = 1;
    }
    // the player (Violet Trail pulls purple popcorn from 180 px at 180 px/s or more)
    if (here) {
      const n = prof.collectRadius, big = Math.max(n, prof.magnetRadius), trail = PT.echoNode(s, "R4");
      for (let k = arr.length - 1; k >= 0; k--) {
        const p = arr[k]; if ((p.pickupDelay || 0) > 0) continue;
        const ox = p.x - s.player.x, oy = p.y - s.player.y, u = ox * ox + oy * oy;
        if (u <= n * n) { arr.splice(k, 1); PT.collectEcho(G, p); continue; }
        const mag = trail && p.type === "echo", R = mag ? Math.max(big * big, 32400) : big * big, step = mag ? Math.max(prof.magnetSpeed * dt, 180 * dt) : prof.magnetSpeed * dt;
        if (step <= 0 || u > R) continue;
        const g = Math.sqrt(u), f = Math.min(step, Math.max(0, g - n));
        if (f > 0 && g > 1e-4) { p.x -= (ox / g) * f; p.y -= (oy / g) * f; if (g - f <= n + 0.001) { arr.splice(k, 1); PT.collectEcho(G, p); } }
      }
    }
  };
})();
