// Phase 6c: mythic sacrifice (Birb wa / Oy / Hy / Ba / Qh, the Sacrifice Room's page past tier XVIII).
// Opens at parrot rebirb III with all 18 common tiers. Three levels, each filled by pouring skill points and Mythic Spirit Aura:
//   I  (2e15 SP + 1,200 aura): x1.2 final parrot stats (X.mythicFinal in expedition.js)
//   II (4e15 SP + 3,600 aura): night-mode elite kills fill a relic bar (12, bosses count 4) that drops Heart of the Veil / Watcher's Oath in turn
//   III (8e15 SP + 9,000 aura): the equipped relic's stats are doubled (X.relicBoost)
(function () {
  const PT = window.PT, X = PT.EXP;
  X.MYTHIC_TIERS = [{ skillPoints: 2e15, aura: 1200 }, { skillPoints: 4e15, aura: 3600 }, { skillPoints: 8e15, aura: 9000 }]; // Birb wa
  X.RELIC_KILLS = 12; // Birb Sa
  X.RELICS = ["veil_heart", "watcher_oath"]; // Birb Qh, dropped in this order
  const MYTHIC_AURA = "mythic_spirit_trash"; // Birb Fa
  const cap = (e, t = Number.MAX_SAFE_INTEGER) => (typeof e === "number" && Number.isFinite(e) ? Math.max(0, Math.min(t, Math.floor(e))) : 0); // Birb Uy

  // Birb Oy: the level is how many tiers are fully paid, in order
  X.mythicState = function (s) {
    const e = PT.expState(s), t = e.mythicSacrifice; let n = 0;
    const c = X.MYTHIC_TIERS.map((w, i) => { const a = t?.contributions?.[i], r = n === i ? { skillPoints: cap(a?.skillPoints, w.skillPoints), aura: cap(a?.aura ?? a?.essence, w.aura) } : { skillPoints: 0, aura: 0 };
      if (r.skillPoints === w.skillPoints && r.aura === w.aura) n++; return r; });
    e.mythicSacrifice = { level: n, contributions: c, eliteKills: n >= 2 ? cap(t?.eliteKills, X.RELIC_KILLS) : 0, relicDrops: cap(t?.relicDrops), pendingAura: cap(cap(t?.pendingAura) + cap(t?.essence)),
      claimedRelicId: n === 3 && X.RELICS.includes(t?.claimedRelicId) ? t.claimedRelicId : undefined };
    return e.mythicSacrifice;
  };
  // Birb Hy: parrot rebirb III and all 18 common tiers paid
  X.mythicOpen = function (s) {
    if (X.rebirbs(s) < 3) return false;
    const n = Math.max(0, Math.floor(Number(X.sacState(s).skillPointsSacrificed) || 0)), T = X.SACRIFICE_THRESHOLDS; let lv = 0;
    for (let i = T.length - 1; i >= 0; i--) if (n >= T[i]) { lv = i + 1; break; }
    return lv >= T.length;
  };
  const sp = (s) => { const v = Math.floor(Number(PT.parrotState(s).skillPoints) || 0); return v > 0 ? v : 0; };
  const mythicAura = (s) => X.itemCount(s, X.itemById(MYTHIC_AURA).name);
  // Birb Ba: something is left to pour into the current level
  X.mythicCanPour = function (s) {
    const m = X.mythicState(s), w = X.MYTHIC_TIERS[m.level]; if (!w) return false; const c = m.contributions[m.level];
    return (sp(s) >= 1 && (c?.skillPoints ?? 0) < w.skillPoints) || (mythicAura(s) >= 1 && (c?.aura ?? 0) < w.aura);
  };
  X.relicBoost = (s) => X.mythicState(s).level >= 3; // Birb normalizes the mythic state on load (normalizeSacrificeState)
  X.mythicFinal = (s) => (X.mythicState(s).level >= 1 ? 1.2 : 1); // Birb Ia

  // Birb's hold-to-pour loop: each level fills in about 2.4 s, paid in 0.1 s ticks, with a 0.85 s pause after a level completes
  let pour = null;
  X.mythicPourStart = (s) => { if (!X.mythicOpen(s) || X.mythicState(s).level >= 3 || !X.mythicCanPour(s)) return false; X.mythicClaimPending(s); pour = { level: -1, tick: 0, pointsRate: 0, auraRate: 0, pr: 0, ar: 0, pause: 0 }; return true; };
  X.mythicPourStop = () => { pour = null; };
  X.mythicPouring = () => !!pour;
  X.mythicPourTick = function (s, dt) {
    if (!pour) return false;
    if (s.currentMap !== PT.SACRIFICE_MAP || !X.mythicCanPour(s)) { pour = null; return false; }
    const m = X.mythicState(s), o = sp(s), l = mythicAura(s), c = Math.min(0.05, Math.max(0, dt));
    if (pour.pause > 0) { pour.pause -= c; return true; }
    const d = X.MYTHIC_TIERS[m.level], u = m.contributions[m.level];
    if (pour.level !== m.level) { pour.level = m.level; pour.pointsRate = Math.max(1, Math.min(o, d.skillPoints - u.skillPoints) / 2.4); pour.auraRate = Math.max(1, Math.min(l, d.aura - u.aura) / 2.4); pour.pr = pour.ar = 0; }
    pour.pr += pour.pointsRate * c; pour.ar += pour.auraRate * c; pour.tick += c;
    if (pour.tick < 0.1) return true;
    pour.tick %= 0.1;
    const r = X.mythicContribute(s, Math.min(o, Math.floor(pour.pr)), Math.min(l, Math.floor(pour.ar)));
    pour.pr -= r.skillPoints; pour.ar -= r.aura;
    if (r.completed) pour.pause = 0.85;
    if (X.mythicState(s).level === 3) pour = null;
    return true;
  };
  // one paid tick (Birb's inner contribute step)
  X.mythicContribute = function (s, points, aura) {
    const r = { skillPoints: 0, aura: 0, completed: false }; if (!X.mythicOpen(s)) return r;
    const m = X.mythicState(s), w = X.MYTHIC_TIERS[m.level]; if (!w) return r;
    const c = m.contributions[m.level]; r.skillPoints = cap(points, w.skillPoints - c.skillPoints);
    const a = cap(aura, w.aura - c.aura); if (a > 0 && mythicAura(s) >= a && X.takeItem(s, X.itemById(MYTHIC_AURA).name, a) !== false) r.aura = a;
    c.skillPoints += r.skillPoints; c.aura += r.aura; PT.parrotState(s).skillPoints = Math.max(0, sp(s) - r.skillPoints);
    if (c.skillPoints === w.skillPoints && c.aura === w.aura) { m.level++; r.completed = true; X.bonusesDirty = true; }
    return r;
  };
  // Birb Sb: aura kept aside (old saves) goes back into the bag when there is room
  X.mythicClaimPending = (s) => { const m = PT.expState(s).mythicSacrifice; if (!m?.pendingAura) return 0; const n = cap(m.pendingAura); if (!n) return 0; m.pendingAura = 0; if (X.addItemById(s, MYTHIC_AURA, n)) return n; m.pendingAura = n; return 0; };

  // Birb trackQuestKill's first step: night elite / boss kills at mythic II fill the relic bar
  X.onQuestKillPre = function (s, run, e) {
    if (X.rebirbs(s) < 3 || !run?.nightMode || e.type === "mini-fly") return;
    const a = PT.expState(s).mythicSacrifice ?? X.mythicState(s);
    if (a.level < 2 || (!e.isElite && !e.isBoss)) return;
    a.eliteKills = Math.min(X.RELIC_KILLS, a.eliteKills + (e.isBoss ? 4 : 1)); if (a.eliteKills < X.RELIC_KILLS) return;
    const r = a.relicDrops ?? 0, id = X.RELICS[r % X.RELICS.length];
    a.eliteKills = 0; a.relicDrops = r + 1;
    if (X.addItemById(s, id, 1)) X.dmgNumber(run, { x: e.x, y: e.y - 32 }, "+ " + X.itemById(id).name, "#dfbcee");
    else { a.eliteKills = X.RELIC_KILLS; a.relicDrops = r; }
  };
  let claimT = 1;
  const upd = X.update; X.update = function (G, dt) { X.mythicPourTick(G.s, dt); if ((claimT -= dt) <= 0) { claimT = 1; X.mythicClaimPending(G.s); } return upd(G, dt); };
})();
