// Peckwood playtest, Phase 5: the Desert, copied from Birb (game: getDesertGoldenPopcornChance,
// calculateGoldenPopcornGainPerDrop, getGoldenPopcornCollectionMultiplier, updateDesertSandstorm,
// wI.getSpawnInterval desert branch, Dave / collared dove: getDave*, performDaveRebirb, awardDaveXp,
// updateCollaredDove + tQ/nQ/iQ/sQ). The Desert is map 9 ("desert-meadow"), up from the Park, after the
// Legendary Key unlocks the desert tree. Desert eggs are plain or golden; golden pays Golden Eggs.
"use strict";
(function () {
  const PT = window.PT;
  const { D } = PT;
  PT.DESERT_MAP = 9;
  PT.DESERT_W = Math.round(1267.2); PT.DESERT_H = Math.round(855.36); // Birb maps rt / ot
  PT.MAPS[9] = { id: 9, key: "desert-meadow", name: "THE DESERT", w: PT.DESERT_W, h: PT.DESERT_H, popcorn: true };
  PT.vertLinks[0] = { up: 9 };
  PT.vertLinks[9] = { down: 0 };

  // Birb maps: ct 0.05 base, dt 0.025 (Gilded Kernels), ut 0.025 (others), mt 30 s storm, Bt 840 s cooldown, ft 1e-4 per second
  const BASE_CHANCE = 0.05, CHANCE_1 = 0.025, CHANCE_N = 0.025, STORM_S = 30, STORM_CD = 840, STORM_P = 1e-4;
  const DAVE_CAP = 100; // Birb Cy
  const ky = (e) => (Number.isFinite(e) ? Math.floor(Math.max(0, Math.min(DAVE_CAP, e))) : 0);
  const Ty = (e) => Math.min(1, ky(DAVE_CAP - ky(e)));
  PT.desertUnlocked = (s) => !!s.hasUnlockedDesertMap || PT.hasSun(s, "d_unlock_desert_tree");

  // ------------------------------------------------------------------ golden eggs
  PT.sandstormOn = (s) => (PT.hasSun(s, "d_desert_sandstorm") || PT.hasSun(s, "d_desert_dune_conductors")) && (Number(s.desertSandstormTimeRemaining) || 0) > 0.001;
  PT.desertGoldenChance = function (s) {
    if (PT.sandstormOn(s)) return 1;
    if (!PT.hasSun(s, "d_desert_core_mockup")) return 0;
    let e = BASE_CHANCE;
    if (PT.hasSun(s, "d_desert_golden_popcorn_chance")) e += CHANCE_1;
    for (const id of ["d_desert_golden_popcorn_chance_2", "d_desert_golden_popcorn_chance_3", "d_desert_golden_popcorn_chance_4", "d_desert_golden_popcorn_chance_5"]) if (PT.hasSun(s, id)) e += CHANCE_N;
    return e;
  };
  PT.desertSpawnRateMult = (s) => (PT.hasSun(s, "d_desert_bloom_netting") ? 1.15 : 1);
  // Birb wI.getSpawnInterval: the desert divides by max(sparrow rebirb boost, Dave rebirb boost), not both
  PT.desertSpawnInterval = function (s) {
    let t = (PT.effect(s, "p_speed") || 2.6) / (PT.effect(s, "pr_respawn_mult") || 1);
    if (PT.hasSun(s, "d_quantum_corn")) t /= 1.2;
    const sp = Math.min(10, 1 + Math.sqrt(Math.max(0, s.sparrowPrestigeCount || 0)) * 1.5);
    const dv = Math.min(10, 1 + Math.sqrt(PT.daveRebirbs(s)) * (9 / Math.sqrt(DAVE_CAP)));
    t /= Math.max(sp, dv);
    return t / (PT.nestRespawnMult ? PT.nestRespawnMult(s) : 1) / PT.desertSpawnRateMult(s);
  };
  PT.duneBloomMult = function (s) {
    if (!PT.hasSun(s, "d_desert_popcorn_spawn_rate")) return 1;
    const e = PT.res(s, "sunflowerSeeds"); if (e.lte(0)) return 1;
    return 1 + e.add(1).log10().toNumber() * (2 / Math.log10(400000000000001));
  };
  // Birb ph/gh: Bountiful Harvest x3, Feathered Harvest = plume curve (soft cap above 12)
  const featheredHarvest = (f) => { const t = 1 + (11 / 17) * D(f).div(1e10).add(1).log10().toNumber(); return Number.isFinite(t) ? (t <= 12 ? t : 12 + Math.log1p(t - 12)) : 1; };
  PT.harvestMult = (s) => (PT.hasSun(s, "d_desert_bountiful_harvest") ? 3 : 1) * (PT.hasSun(s, "d_desert_feathered_harvest") ? featheredHarvest(s.resources.goldenFeathers) : 1);
  // Birb calculateGoldenPopcornGainPerDrop (floors after every step, x2 from Evolution 6)
  PT.goldenPerDrop = function (s) {
    const fl = (x) => Math.max(1, Math.floor(x));
    let t = fl((PT.effect(s, "p_golden_popcorn_value") || 1) * (PT.effect(s, "pr_golden_popcorn_mult") || 1));
    t = fl(t * PT.fishMult(s, "golden_popcorn_mult"));
    if (PT.hasSun(s, "d_desert_golden_popcorn_x2")) t *= 2;
    if (PT.hasSun(s, "d_desert_golden_popcorn_gain_2")) t = fl(1.5 * t);
    if (PT.hasSun(s, "d_desert_signal_smoke")) t = fl(1.5 * t);
    const n = PT.sunLevel(s, "d_desert_field_notes_plus"); if (n > 0) t = fl(t * (1 + n / 3));
    t = fl(t * PT.duneBloomMult(s));
    if (PT.hasSun(s, "d_desert_bloom_reservoir")) t = fl(1.35 * t);
    if (PT.hasSun(s, "d_desert_collared_dove")) t = fl(Math.floor(t * PT.daveGoldenMult(s)));
    return fl(t * PT.harvestMult(s)) * ((s.evolutionCount || 0) >= 6 ? 2 : 1);
  };
  // Birb getGoldenPopcornCollectionMultiplier: caramelized x2, archivist V2 x1.15 (comes with Phase 7), Golden Sand x3 in a storm
  PT.goldenCollectMult = (s, caramel) => (caramel ? 2 : 1) * (PT.hasSun(s, "d_archivist_echo_golden_memory") ? 1.15 : 1) * (PT.sandstormOn(s) && PT.hasSun(s, "d_desert_golden_sand") ? 3 : 1);
  PT.desertEggMult = (s) => PT.collectionMultiplier(s) * (PT.hasSun(s, "d_desert_fever") ? 5 : 1);

  // Birb awardCollectedPopcorn, desert branch (who: player / collared_dove)
  PT.awardDesert = function (G, p, who) {
    const s = G.s;
    if (p.type !== "golden") {
      const v = D(Math.floor(PT.TYPES[p.type].baseValue * PT.desertEggMult(s)));
      PT.add(s, "popcorn", v); s.totalPopcornCollected = D(s.totalPopcornCollected).add(v); G.gain("popcorn", v);
      if (who === "collared_dove") daveXp(G, PT.hasSun(s, "d_desert_dave_popcorn_xp") ? 2 : 1);
      if (G.onFloat && s.currentMap === PT.DESERT_MAP) G.onFloat(p.x, p.y, "+" + PT.fmt(v), PT.TYPES[p.type].color);
      return;
    }
    const u = PT.goldenPerDrop(s) * PT.goldenCollectMult(s, p.caramel);
    PT.add(s, "goldenPopcorn", D(u)); G.gain("goldenPopcorn", D(u));
    s.totalGoldenPopcornCollected = (s.totalGoldenPopcornCollected || 0) + u;
    if (who === "collared_dove") {
      const d = PT.dave(s);
      daveXp(G, 5 * (PT.hasSun(s, "d_desert_dave_golden_xp") ? 2 : 1));
      d.lifetimeGoldenCollected += u; d.cycleGoldenCollected += u;
    }
    if (G.onFloat && s.currentMap === PT.DESERT_MAP) G.onFloat(p.x, p.y - 18, "+" + PT.fmt(u), p.caramel ? "#ffd54a" : "#f59e0b");
  };

  // ------------------------------------------------------------------ sandstorm (Birb updateDesertSandstorm / startDesertSandstorm)
  PT.updateSandstorm = function (G, dt) {
    const s = G.s;
    let t = Math.max(0, Number(s.desertSandstormTimeRemaining) || 0), n = Math.max(0, Number(s.desertSandstormCooldownRemaining) || 0);
    const conductors = PT.hasSun(s, "d_desert_dune_conductors");
    if (!PT.hasSun(s, "d_desert_sandstorm") && !conductors) { s.desertSandstormTimeRemaining = 0; s.desertSandstormCooldownRemaining = 0; return; }
    if (t > 0) { t = Math.max(0, t - dt); s.desertSandstormTimeRemaining = t; if (t <= 0) s.desertSandstormCooldownRemaining = STORM_CD; return; }
    if (n > 0) { s.desertSandstormCooldownRemaining = Math.max(0, n - dt); return; }
    if (s.currentMap !== PT.DESERT_MAP) return;
    if (conductors || Math.random() < 1 - Math.pow(1 - STORM_P, Math.max(0, dt))) PT.startSandstorm(G);
  };
  PT.startSandstorm = function (G) {
    const s = G.s; s.desertSandstormTimeRemaining = STORM_S; s.desertSandstormCooldownRemaining = 0;
    for (const p of G.field.list(PT.DESERT_MAP)) { if (p.type !== "golden") { p.type = "golden"; p.caramel = PT.hasSun(s, "d_desert_gourmet_golden_popcorn") && Math.random() < 0.25; } }
  };

  // ------------------------------------------------------------------ Dave (Birb collaredDove state + getDave*)
  PT.DAVE_MILESTONES = [
    ["firstHop", 1, "Wider landing reach (38 px)"], ["quickFeet", 3, "Flies and walks 18% faster"], ["sharpEyes", 5, "Scans farther, values clusters 20% more"],
    ["davesSons", 10, "Two sons help him forage"], ["workRhythm", 25, "Auto rebirb, chains sweeps without resting"], ["fieldSense", 50, "Cluster radius 92 → 124 px"],
    ["davesFamily", 75, "A third son joins"], ["masterForager", DAVE_CAP, "Speed and forage pace x1.25"],
  ];
  PT.dave = function (s) {
    const d = s.collaredDove || (s.collaredDove = { rebirbProgressionVersion: 3, unspentRebirbPoints: 1, level: 1, xp: 0, seedTrainingLevel: 0, rebirbCount: 1, cycleGoldenCollected: 0,
      instincts: { scavenger: 0, sweep: 0, gilded: 0 }, lifetimeSweeps: 0, lifetimePopcornCollected: 0, lifetimeGoldenCollected: 0, autoRebirbEnabled: false, autoRebirbInstinct: null });
    d.instincts ||= { scavenger: 0, sweep: 0, gilded: 0 };
    return d;
  };
  PT.daveRebirbs = (s) => ky(PT.dave(s).rebirbCount);
  const inst = (s, k) => ky(PT.dave(s).instincts[k] || 0);
  PT.daveMilestone = (s, id) => PT.daveRebirbs(s) >= (PT.DAVE_MILESTONES.find((m) => m[0] === id) || [0, Infinity])[1];
  PT.daveXpNeeded = (L) => PT.sparrowXpNeeded(Math.max(1, Math.floor(L || 1)));
  PT.daveSeedCost = (L) => Math.floor(25e3 * Math.pow(4e10, Math.max(0, Math.floor(L)) / 50));
  PT.daveXpGainMult = (s) => 1 + 0.08 * PT.dave(s).seedTrainingLevel;
  PT.daveTrainSpeed = (s) => 1 + 0.02 * Math.min(50, PT.dave(s).seedTrainingLevel);
  PT.daveScavengerMult = (s) => 1 + 0.3 * inst(s, "scavenger");
  PT.daveVelocityMult = (s) => 1 + 0.3 * inst(s, "scavenger"); // Birb reads the scavenger count here too
  PT.daveSpeedMult = (s) => PT.daveTrainSpeed(s) * PT.daveScavengerMult(s) * (PT.daveMilestone(s, "masterForager") ? 1.25 : 1);
  PT.davePickDelay = (s) => Math.max(5e-4, 0.18 / (PT.daveVelocityMult(s) * PT.daveTrainSpeed(s) * (PT.daveMilestone(s, "masterForager") ? 1.25 : 1)));
  PT.daveSweepSize = (s) => 8 + 20 * inst(s, "sweep");
  PT.daveBurst = (s) => Math.min(6, 1 + Math.floor(inst(s, "sweep") / 10));
  PT.daveGoldenMult = (s) => (1 + Math.min(10, 0.01 * PT.dave(s).level)) * (1 + inst(s, "gilded"));
  PT.daveCanRebirb = (s) => PT.hasSun(s, "d_desert_collared_dove") && PT.daveRebirbs(s) < DAVE_CAP && PT.dave(s).level >= 100;
  PT.daveTrain = function (s) {
    if (!PT.hasSun(s, "d_desert_collared_dove")) return false;
    const d = PT.dave(s), c = PT.daveSeedCost(d.seedTrainingLevel);
    if (PT.res(s, "sunflowerSeeds").lt(c)) return false;
    PT.sub(s, "sunflowerSeeds", c); d.seedTrainingLevel++; return true;
  };
  // Birb performDaveRebirb: +1 to the chosen instinct, level drops by 100, XP keeps its fraction
  PT.daveRebirb = function (G, k) {
    const s = G.s; if (!["scavenger", "sweep", "gilded"].includes(k) || !PT.daveCanRebirb(s)) return false;
    const d = PT.dave(s), n = d.level, frac = Math.min(1, d.xp / Math.max(1, PT.daveXpNeeded(n))), o = Math.max(0, n - 100), l = Math.max(1, PT.daveXpNeeded(o)), c = Ty(d.rebirbCount);
    d.rebirbCount = ky(d.rebirbCount + c); d.instincts[k] = ky(inst(s, k) + c); d.level = o; d.xp = Math.max(0, Math.min(l - 1e-6, frac * l));
    d.cycleGoldenCollected = 0; d.autoRebirbInstinct = k; G.daves = [];
    return true;
  };
  // Birb spendDaveRebirbPoint (the window's x1 / x10 / MAX picks the amount)
  PT.daveSpendPoint = function (s, k, amt = 1) {
    const d = PT.dave(s), i = ky(d.unspentRebirbPoints); if (!["scavenger", "sweep", "gilded"].includes(k) || i <= 0) return false;
    const r = Math.min(i, ky(Number(amt) || 1)); if (r <= 0) return false;
    d.instincts[k] = ky(inst(s, k) + r); d.unspentRebirbPoints = ky(i - r); if (d.unspentRebirbPoints > 0) d.autoRebirbEnabled = false; return true;
  };
  PT.daveRefund = function (s) {
    const d = PT.dave(s), t = inst(s, "scavenger") + inst(s, "sweep") + inst(s, "gilded"); if (t <= 0) return false;
    d.instincts = { scavenger: 0, sweep: 0, gilded: 0 }; d.unspentRebirbPoints = ky(ky(d.unspentRebirbPoints) + t); d.autoRebirbEnabled = false; return true;
  };
  // Birb awardDaveXp (x Flock Memory)
  function daveXp(G, base) {
    const s = G.s, a = Math.max(0, base) * PT.daveXpGainMult(s) * (PT.flockMemoryMult ? PT.flockMemoryMult(s, "dave") : 1);
    if (a <= 0 || !PT.hasSun(s, "d_desert_collared_dove")) return;
    const d = PT.dave(s); d.xp += a; d.lifetimePopcornCollected++; G.gain("daveXp", a);
    let ups = 0, need = PT.daveXpNeeded(d.level);
    while (d.xp >= need) { d.xp -= need; d.level++; ups++; need = PT.daveXpNeeded(d.level); }
    if (ups > 0 && PT.daveMilestone(s, "workRhythm") && d.autoRebirbEnabled && ky(d.unspentRebirbPoints) <= 0 && d.autoRebirbInstinct && PT.daveCanRebirb(s)) PT.daveRebirb(G, d.autoRebirbInstinct);
  }

  // ------------------------------------------------------------------ Dave's foraging (Birb updateCollaredDove)
  const gold = (p) => (p.type !== "golden" ? 0 : p.caramel ? 2 : 1); // Birb Kz
  const setState = (b, st) => { if (b.state !== st) { b.state = st; b.timer = 0; } };
  const moveTo = (b, x, y, v, dt) => { // Birb oQ
    const dx = x - b.x, dy = y - b.y, o = Math.hypot(dx, dy); if (o <= 1e-4) return 0;
    if (Math.abs(dx) > 1.5) b.face = dx > 0 ? 1 : -1;
    const l = v * dt; if (l >= o) { b.x = x; b.y = y; return 0; } b.x += (dx / o) * l; b.y += (dy / o) * l; return o - l;
  };
  // Birb tQ: best cluster = own value + neighbours within the cluster radius - distance cost
  function bestCluster(b, arr, prio, rad, cost, clusterMult, taken) {
    let best = null, bv = -Infinity;
    for (const h of arr) {
      if (taken.has(h.id)) continue;
      const g = gold(h); let f = (g > 0 ? 20 * prio * g : 1.3) * clusterMult;
      for (const e of arr) { if (e === h || taken.has(e.id)) continue; const dx = e.x - h.x, dy = e.y - h.y; if (dx * dx + dy * dy <= rad * rad) { const t = gold(e); f += (t > 0 ? 10 * prio * t : 1) * clusterMult; } }
      const v = f - Math.hypot(h.x - b.x, h.y - b.y) * cost; if (v > bv) { bv = v; best = h; }
    }
    return best;
  }
  // Birb nQ: nearest within radius, golden first
  function nearest(x, y, arr, prio, rad, taken) {
    let best = null, bv = -Infinity;
    for (const d of arr) { if (taken.has(d.id)) continue; const u = (d.x - x) ** 2 + (d.y - y) ** 2; if (u > rad * rad) continue; const h = 1e5 * prio * gold(d) - u; if (h > bv) { bv = h; best = d; } }
    return best;
  }
  // Birb iQ: burst picks the target plus the best eggs within 48 px
  function burst(e, arr, n, taken) {
    if (n <= 1) return [e];
    const near = arr.filter((t) => t.id !== e.id && !taken.has(t.id) && (t.x - e.x) ** 2 + (t.y - e.y) ** 2 <= 2304)
      .sort((t, u) => gold(u) - gold(t) || ((t.x - e.x) ** 2 + (t.y - e.y) ** 2) - ((u.x - e.x) ** 2 + (u.y - e.y) ** 2));
    return [e, ...near.slice(0, n - 1)];
  }
  const sonOffset = (i) => [i === 0 ? -26 : i === 1 ? 26 : -57.2, i === 2 ? 0 : -6];
  PT.updateDave = function (G, dt) {
    const s = G.s, M = PT.DESERT_MAP, W = PT.DESERT_W, H = PT.DESERT_H;
    if (!PT.hasSun(s, "d_desert_collared_dove")) { G.daves = []; return; }
    if (s.currentMap === M) { G.daveAnchor = { x: Math.max(48, Math.min(W - 48, s.player.x)), y: Math.max(48, Math.min(H - 48, s.player.y)) }; }
    const anc = G.daveAnchor || (G.daveAnchor = { x: W / 2, y: H / 2 });
    if (!G.daves || !G.daves.length) G.daves = [{ x: anc.x, y: anc.y - 18, state: "idle", targetId: null, tx: anc.x, ty: anc.y, timer: 0, face: 1, left: 0, sons: [] }];
    const a = G.daves[0], arr = G.field.list(M), byId = new Map(arr.map((p) => [p.id, p]));
    a.timer += dt;
    const prio = 5, hop = PT.daveMilestone(s, "firstHop"), quick = PT.daveMilestone(s, "quickFeet"), sharp = PT.daveMilestone(s, "sharpEyes"), sense = PT.daveMilestone(s, "fieldSense");
    const rhythm = PT.daveMilestone(s, "workRhythm"), sons = PT.daveMilestone(s, "davesSons"), family = PT.daveMilestone(s, "davesFamily");
    const rad = sense ? 124.2 : 92, cost = sharp ? 0.018 : 0.025, cm = sharp ? 1.2 : 1, qf = quick ? 1.18 : 1, reach = hop ? 38 : 28;
    const w = PT.daveSpeedMult(s), vel = PT.daveVelocityMult(s), flyV = 255 * w * qf, walkV = 92 * w * qf, delay = PT.davePickDelay(s);
    if (a.targetId !== null && !byId.has(a.targetId)) a.targetId = null;
    const collect = (p) => { const q = G.field.take(M, p.id); if (q) { byId.delete(q.id); PT.awardDesert(G, q, "collared_dove"); } };
    const retarget = (keepLeft, taken) => { const c = bestCluster(a, arr.filter((p) => byId.has(p.id)), prio, rad, cost, cm, taken); if (!c) return false; a.targetId = c.id; a.tx = c.x; a.ty = c.y; if (!keepLeft) a.left = 0; setState(a, "fly"); return true; };
    // sons (Birb sQ): pick the nearest egg near Dave within 3x the cluster radius, one pick every 0.4 x pick delay
    const taken = new Set();
    if (sons) {
      const n = family ? 3 : 2; while (a.sons.length < n) { const i = a.sons.length, [ox, oy] = sonOffset(i); a.sons.push({ x: a.x + ox, y: a.y + oy, state: "idle", targetId: null, timer: 0, face: 1, i }); } a.sons.length = n;
      const claimed = new Set(); if (a.targetId !== null) claimed.add(a.targetId);
      const live = () => arr.filter((p) => byId.has(p.id));
      for (const e of a.sons) {
        e.timer += dt; const [ox, oy] = sonOffset(e.i), fy = Math.max(190, 255 * w * qf * 1.5), wk = Math.max(92, 92 * w * qf * vel * 1.5), A = Math.max(0.02, 0.4 * delay);
        if (e.targetId !== null && (!byId.has(e.targetId) || claimed.has(e.targetId))) e.targetId = null;
        if (e.targetId === null) { const t = nearest(a.x, a.y, live(), prio, 3 * rad, claimed); if (!t) { e.state = "idle"; moveTo(e, a.x + ox, a.y + oy, 0.7 * wk, dt); continue; } e.targetId = t.id; e.state = "fly"; }
        claimed.add(e.targetId);
        const v = byId.get(e.targetId); e.face = v.x >= e.x ? 1 : -1;
        const left = moveTo(e, v.x + (e.face > 0 ? -13 : 13), v.y - 10, e.state === "fly" ? fy : wk, dt);
        if (left > 4) e.state = e.state === "fly" ? "fly" : "walk";
        else { e.state = "forage"; if (e.timer >= A) { e.timer = 0; claimed.delete(v.id); collect(v); e.targetId = null; } }
      }
      for (const e of a.sons) if (e.targetId !== null) taken.add(e.targetId);
    } else a.sons = [];
    if (a.state === "fly") {
      let t = a.targetId !== null ? byId.get(a.targetId) : null;
      if (!t) { t = bestCluster(a, arr.filter((p) => byId.has(p.id)), prio, rad, cost, cm, taken); if (t) a.targetId = t.id; else { a.targetId = null; a.left = 0; setState(a, "idle"); return; } }
      a.tx = t.x; a.ty = t.y;
      if (moveTo(a, a.tx, a.ty, flyV, dt) <= reach) { a.x = a.tx + (a.face > 0 ? -18 : 18); a.y = a.ty - 10; a.targetId = null; if (a.left <= 0) a.left = PT.daveSweepSize(s); setState(a, "forage"); }
      return;
    }
    if (a.state === "forage") {
      if (a.left <= 0) { a.targetId = null; if (rhythm && byId.size && retarget(false, taken)) return; setState(a, "idle"); return; }
      if (a.targetId === null) { const e = nearest(a.tx, a.ty, arr.filter((p) => byId.has(p.id)), prio, rad, taken); if (!e) { if (rhythm && byId.size && retarget(true, taken)) return; a.left = 0; setState(a, "idle"); return; } a.targetId = e.id; }
      let i = byId.get(a.targetId); if (!i) { a.targetId = null; if (rhythm && byId.size) retarget(true, taken); return; }
      a.face = i.x >= a.x ? 1 : -1;
      const u = Math.max(76, 0.92 * walkV * vel), h = Math.max(4, u * dt + 4);
      if (moveTo(a, i.x + (a.face > 0 ? -18 : 18), i.y - 10, u, dt) > 4) { a.timer = 0; return; }
      let guard = 128;
      while (i && a.timer >= delay && a.left > 0 && guard-- > 0) {
        a.timer -= delay;
        for (const r of burst(i, arr.filter((p) => byId.has(p.id)), Math.min(PT.daveBurst(s), a.left || 1), taken)) { if (a.left <= 0) break; collect(r); a.left = Math.max(0, a.left - 1); }
        a.targetId = null;
        if (a.left <= 0) { if (rhythm && byId.size && retarget(false, taken)) break; setState(a, "idle"); break; }
        const nx = nearest(a.tx, a.ty, arr.filter((p) => byId.has(p.id)), prio, rad, taken);
        if (!nx) { if (rhythm && byId.size && retarget(true, taken)) break; setState(a, "idle"); break; }
        a.face = nx.x >= a.x ? 1 : -1; const dx = nx.x + (a.face > 0 ? -18 : 18), dy = nx.y - 10; a.targetId = nx.id;
        if (Math.hypot(dx - a.x, dy - a.y) > h) break;
        a.x = dx; a.y = dy; i = nx;
      }
      return;
    }
    if (byId.size && a.targetId === null) {
      const t = bestCluster(a, arr, prio, rad, cost, cm, taken);
      if (t) { a.targetId = t.id; a.tx = t.x; a.ty = t.y; a.left = 0; PT.dave(s).lifetimeSweeps++; setState(a, "fly"); return; }
    }
    if ((a.idle = (a.idle ?? 0) - dt) <= 0) { const e = Math.random() * Math.PI * 2, r = 42 + 76 * Math.random(); a.ix = anc.x + Math.cos(e) * r; a.iy = anc.y + Math.sin(e) * r; a.idle = 1.4 + 1.6 * Math.random(); }
    setState(a, moveTo(a, a.ix ?? anc.x, a.iy ?? anc.y, walkV, dt) > 10 ? "walk" : "idle");
  };

  // ------------------------------------------------------------------ per-frame update
  PT.updateDesert = function (G, dt, prof) {
    const s = G.s, M = PT.DESERT_MAP, here = s.currentMap === M;
    PT.updateSandstorm(G, dt);
    // Birb update(): the desert field runs while you're there, and while away once Dave is unlocked
    if (here || PT.hasSun(s, "d_desert_collared_dove")) {
      G.field.update(s, dt, M, PT.DESERT_W, PT.DESERT_H, PT.maxPopcorn(s), PT.desertSpawnInterval(s), {
        player: here ? s.player : null, immediateRadius: prof.collectRadius, legacyRadius: 70, onImmediate: (p) => PT.awardDesert(G, p, "player"),
        rollType: () => (Math.random() < Math.min(1, Math.max(0, PT.desertGoldenChance(s))) ? "golden" : "plain"),
        caramel: PT.hasSun(s, "d_desert_gourmet_golden_popcorn"),
      });
    }
    if (here) G.field.pickup(M, s.player.x, s.player.y, prof, dt, (p) => PT.awardDesert(G, p, "player"));
    PT.updateDave(G, dt);
  };
})();
