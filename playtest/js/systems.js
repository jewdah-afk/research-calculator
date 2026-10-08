// Peckwood playtest: game systems, 1:1 with Birb. Each block names the Birb function it copies.
"use strict";
(function () {
  const PT = window.PT;
  const { D } = PT;

  // ------------------------------------------------------------------ maps (Birb map ids; park field 1056x792)
  PT.MAPS = {
    0: { id: 0, key: "meadow", name: "THE PARK", w: 1056, h: 792, popcorn: true },
    1: { id: 1, key: "sunflower-field", name: "SUNFLOWER FIELD", w: 4000, h: 2000 },
    2: { id: 2, key: "bridge", name: "THE BRIDGE", w: 3000, h: 1400 },
    3: { id: 3, key: "castle", name: "THE CASTLE", w: 1600, h: 1152 },
    22: { id: 22, key: "aquarium", name: "THE AQUARIUM", w: 1600, h: 1100, side: true },
    24: { id: 24, key: "fish-market", name: "FISH MARKET", w: 1056, h: 792, side: true },
    4: { id: 4, key: "nest", name: "BIRB NEST", w: 1600, h: 2112 },
    14: { id: 14, key: "twig-nest-room", name: "NEST INTERIOR", w: 1056, h: 792, side: true },
    25: { id: 25, key: "expedition-mine-room", name: "THE MINE", w: 1056, h: 792, side: true },
    26: { id: 26, key: "expedition-mine-treasure-room", name: "TREASURE ROOM", w: 1056, h: 792, side: true },
  };
  // Birb map arrows: the Nest (4) is left of the Park (0); its left arrow leads to the Expedition hub (later phase).
  PT.travelTarget = function (s, dir) {
    const m = s.currentMap;
    if (m === 0 && dir < 0) return 4;
    if (m === 9) return dir > 0 ? 1 : 4; // Birb: the Desert sits above the Park with the same side arrows
    if (m === 4) return dir > 0 ? (s.nestReturnMap === 9 && PT.desertUnlocked(s) ? 9 : 0) : PT.EXP_HUB_MAP; // Birb: the Expedition hub is left of the Nest
    if (m === PT.EXP_HUB_MAP) return dir > 0 ? 4 : PT.SACRIFICE_MAP; // Birb: the Sacrifice Room is left of the hub
    if (m === PT.SACRIFICE_MAP) return dir > 0 ? PT.EXP_HUB_MAP : -99;
    if (m === 1 && dir < 0) return s.sunflowerFieldReturnMap === 9 && PT.desertUnlocked(s) ? 9 : 0;
    return m + dir;
  };
  // Birb sA(): the Aquarium is "down" from the Bridge (Evolution 5), the Fish Market is a room off the Aquarium.
  PT.vertLinks = { 2: { down: 22 }, 22: { up: 2, down: 24 }, 24: { up: 22 }, 4: { up: 14 }, 14: { down: 4 }, 25: { down: 26 }, 26: { up: 25 } };
  PT.vertBlock = function (s, dir) {
    const to = PT.vertLinks[s.currentMap]?.[dir];
    if (to === undefined) return "end";
    if (to === 22 && !PT.aquariumUnlocked(s)) return "The Aquarium opens at Evolution 5";
    if (to === 24 && !PT.fishMarketUnlocked(s)) return "The Fish Market opens at 700 resonance";
    if (to === 9 && !PT.desertUnlocked(s)) return "end"; // Birb shows the up arrow once the desert tree is unlocked
    if (to === 14 && PT.nestState(s).tier < 1) return "The nest interior opens at Nest level 2";
    if (to === 26 && PT.mineArea(s) < 1) return "Defeat the first giant ore";
    return "";
  };
  // Birb uA(): +1 = right arrow, -1 = left. Returns "" or the reason travel is blocked.
  PT.travelBlock = function (s, dir) {
    const m = s.currentMap;
    if (PT.MAPS[m]?.side) return "end";
    if (dir > 0) {
      if ((m === 0 || m === 9) && (s.rebirthCount || 0) < 1) return "Molt once to travel";
      if (m === 1 && !s.hasUnlockedEvolve) return "Needs Unlock Evolve";
      if (m === 2 && !s.hasEnteredDungeon) return "Walk to the castle gate at the end of the bridge";
      if (m === 3) return "end";
    } else {
      if (m === 0 || m === 9) return (s.evolutionCount || 0) < 3 ? "EVOLUTION 3" : "";
      if (m === 4) return PT.expState(s).unlocked ? "" : "COMPLETE NEST LEVEL 2";
      if (m === PT.SACRIFICE_MAP) return "end";
    }
    return "";
  };

  // ------------------------------------------------------------------ popcorn types (Birb: Wc)
  PT.TYPES = {
    plain: { color: "#f2e8cf", baseValue: 1, weight: 100 },
    butter: { color: "#dda15e", baseValue: 2, weight: 20 },
    caramel: { color: "#bc6c25", baseValue: 10, weight: 5 },
    cheese: { color: "#e9a319", baseValue: 25, weight: 1 },
    rainbow: { color: "#c77b7b", baseValue: 100, weight: 0.1 },
    red: { color: "#ff0000", baseValue: 100, weight: 0.01 },
    golden: { color: "#f0b428", baseValue: 1, weight: 0 },
  };
  const ROLL_TYPES = Object.keys(PT.TYPES);

  // Later-phase multipliers are 1 until those systems exist (fish, nest, quests, sacrifice, red panda).
  PT.fishMult = () => 1;
  const nestPopcornRespawnMult = (s) => (PT.nestRespawnMult ? PT.nestRespawnMult(s) : 1), nestSeedProductionMult = (s) => (PT.nestSeedProdMult ? PT.nestSeedProdMult(s) : 1);
  const grainSilo = (s) => (PT.nestGrainSilo ? PT.nestGrainSilo(s) : 1), wateringWell = (s) => (PT.nestWellMult ? PT.nestWellMult(s) : 1);
  const questBonus = () => 0, sacrificeMult = (s) => (PT.sacrificePopcornMult ? PT.sacrificePopcornMult(s) : 1), redPandaNap = (s) => (PT.redPandaNapMult ? PT.redPandaNapMult(s) : 1), flockCommunity = () => 1;

  // Birb: fo/$r  a + i * log10(x / t + 1)
  const logCurve = (x, t, i, a) => a + i * D(x).div(t).add(1).log10().toNumber();
  // Birb: yI  min(cap, 1 + sqrt(x) * k)
  const sqrtBoost = (x, k, cap) => { const v = 1 + Math.sqrt(Math.max(0, x)) * k; return cap ? Math.min(cap, v) : v; };

  // Birb: wI.calculateMultiplier + getTotalMultiplier
  PT.totalMultiplier = function (s) {
    let t = 1;
    t *= PT.effect(s, "p_value") || 1;
    t *= PT.effect(s, "pr_popcorn_mult") || 1;
    t *= PT.effect(s, "s_more_popcorn") || 1;
    if (PT.hasSun(s, "d_butter_hose")) t *= 1.5;
    if (PT.hasSun(s, "d_kernel_polish")) t *= 2;
    t *= PT.fishMult(s, "popcorn_mult");
    if (s.evolutionCount >= 2) t *= s.evolutionCount;
    if (PT.hasSun(s, "d_seed_synergy")) t *= 1 + 1.3 * Math.log10(1 + PT.num(s.resources.sunflowerSeeds) / 5e4);
    t *= Math.max(1, grainSilo(s));
    if (PT.hasSun(s, "d_trophy_bonus")) t *= 1 + 3 * Math.log10(1 + (PT.highestFishWeight ? PT.highestFishWeight(s) : 0));
    t *= PT.sparrowDrainMult(s);
    if (PT.hasSun(s, "d_golden_butter")) t *= 1 + 0.5 * Math.log10(PT.num(s.resources.goldenFeathers) + 1);
    t *= sacrificeMult(s);
    t *= 1 + questBonus(s, "popcorn_gain_mult");
    return t * redPandaNap(s) * wateringWell(s) * flockCommunity(s);
  };
  // Birb: getPopcornCollectionMultiplier (room multiplier = 1 offline; desert fever later)
  PT.collectionMultiplier = (s) => PT.totalMultiplier(s) * (PT.hasSun(s, "d_desert_popcorn_gain_x2") ? 2 : 1);

  // Birb: wI.getMaxCapacity
  PT.maxPopcorn = function (s) {
    const t = (PT.effect(s, "p_capacity") || 0) + ((PT.hasSun(s, "d_desert_auric_blueprints") && PT.effect(s, "p_auric_silo")) || 0);
    let n = PT.hasSun(s, "d_popcorn_cap") ? 2 : 1;
    if (PT.hasSun(s, "d_void_silo")) n *= 1.1;
    return Math.floor(t * n);
  };
  // Birb: wI.getSpawnInterval / game.getSpawnInterval
  PT.spawnInterval = function (s) {
    let t = (PT.effect(s, "p_speed") || 2.6) / (PT.effect(s, "pr_respawn_mult") || 1);
    if (PT.hasSun(s, "d_quantum_corn")) t /= 1.2;
    t /= Math.max(sqrtBoost(s.sparrowPrestigeCount || 0, 1.5, 10), 1);
    return t / nestPopcornRespawnMult(s);
  };
  // Birb: game.getPickupProfile + wI.getPickupProfile
  PT.pickupProfile = function (s) {
    const e = PT.effect(s, "pr_radius_mult") || 1;
    const t = PT.hasSun(s, "d_pickup_range") ? 1.25 : 1;
    const i = PT.hasSun(s, "d_focus_training") ? 1.3 : 1;
    const a = 1 + questBonus(s, "pickup_radius_mult");
    const n = Math.max(1, 40 * e * t * i * a), m = Math.max(1, PT.fishMult(s, "pickup_mult"));
    const lg = Math.log2(m), r = n * (1 + 0.35 * lg), o = Math.max(0, n * m - r);
    return { collectRadius: r, magnetRadius: r + Math.min(n, Math.sqrt(o * n)), magnetSpeed: m > 1 ? Math.min(420, 160 + 70 * lg) : 0 };
  };
  // Birb: getCurrentMaxSpeed (BASE_MAX_SPEED 168, BASE_ACCELERATION 500)
  PT.speedMult = (s) => (PT.effect(s, "s_speed_boost") || 1) * (PT.effect(s, "p_move_speed") || 1) *
    (PT.hasSun(s, "d_swift_wings") ? 1.3 : 1) * (PT.hasSun(s, "d_platinum_wings") ? 1.15 : 1) * PT.fishMult(s, "speed_mult");
  PT.maxSpeed = (s) => 168 * PT.speedMult(s);
  PT.accel = (s) => 500 * PT.speedMult(s);

  // ------------------------------------------------------------------ popcorn field (Birb: class wI)
  PT.Field = class {
    constructor() { this.byMap = new Map(); this.timer = new Map(); this.nextId = 1; }
    list(m) { if (!this.byMap.has(m)) this.byMap.set(m, []); return this.byMap.get(m); }
    clear() { this.byMap.clear(); this.timer.clear(); }
    rollType(s) {
      const w = {}; let sum = 0;
      for (const k of ROLL_TYPES) {
        let t = PT.TYPES[k].weight;
        if (k === "cheese" && PT.hasSun(s, "d_cheese_powder")) t *= 1.5;
        if (k === "rainbow") { t += PT.level(s, "f_rainbow_chance"); if (PT.hasSun(s, "d_rainbow_aura")) t *= 2; }
        if (k === "butter" && PT.hasSun(s, "d_butter_bonanza")) t *= 1.5;
        w[k] = t; sum += t;
      }
      let r = Math.random() * sum;
      for (const k of ROLL_TYPES) { r -= w[k]; if (r <= 0) return k; }
      return "plain";
    }
    // Birb: wI.spawnPopcorn (40 px margin; spawns that land inside the bird's reach are collected at once)
    spawn(s, m, W, H, ctx) {
      const pad = 40;
      const type = ctx && ctx.rollType ? ctx.rollType() : this.rollType(s); // Birb rollPopcornType: the desert rolls only plain / golden
      const p = { id: this.nextId++, type, caramel: type === "golden" && !!(ctx && ctx.caramel) && Math.random() < 0.25, x: pad + Math.random() * (W - 2 * pad), y: pad + Math.random() * (H - 2 * pad) };
      if (ctx && ctx.player) {
        const dx = p.x - ctx.player.x, dy = p.y - ctx.player.y, r = ctx.immediateRadius;
        if (dx * dx + dy * dy <= r * r) { ctx.onImmediate(p); return; }
      }
      this.list(m).push(p);
    }
    // Birb: wI.update (spawn timer only runs while below the cap)
    update(s, dt, m, W, H, cap, interval, ctx) {
      const arr = this.list(m);
      let c = this.timer.get(m) || 0;
      if (arr.length < cap) {
        c += dt;
        const l = Math.max(1e-4, interval);
        let room = cap - arr.length;
        while (c >= l && room > 0) { c -= l; this.spawn(s, m, W, H, ctx); room--; }
      }
      this.timer.set(m, c);
      // d_gravity_field: drift toward the bird within 1.1x the 70px pickup radius
      if (ctx && ctx.player && PT.hasSun(s, "d_gravity_field")) {
        const step = 50 * dt, r = 1.1 * ctx.legacyRadius;
        for (const e of arr) {
          const dx = ctx.player.x - e.x, dy = ctx.player.y - e.y, d = Math.hypot(dx, dy);
          if (d < r && d > 10) { e.x += (dx / d) * step; e.y += (dy / d) * step; }
        }
      }
    }
    // Birb: wI.updatePlayerPickup
    pickup(m, px, py, prof, dt, onCollect) {
      const arr = this.list(m), n = prof.collectRadius, i = Math.max(n, prof.magnetRadius);
      const a = n * n, r = i * i, step = prof.magnetSpeed * dt;
      for (let c = arr.length - 1; c >= 0; c--) {
        const p = arr[c], ox = p.x - px, oy = p.y - py, u = ox * ox + oy * oy;
        if (u <= a) { arr.splice(c, 1); onCollect(p); continue; }
        if (step <= 0 || u > r) continue;
        const g = Math.sqrt(u), f = Math.min(step, Math.max(0, g - n));
        if (f > 0 && g > 1e-4) { p.x -= (ox / g) * f; p.y -= (oy / g) * f; if (g - f <= n + 0.001) { arr.splice(c, 1); onCollect(p); } }
      }
    }
    take(m, id) { const arr = this.list(m), i = arr.findIndex((p) => p.id === id); return i < 0 ? null : arr.splice(i, 1)[0]; }
  };

  // Birb: awardCollectedPopcorn (player / sparrow; desert golden handled in the desert phase)
  PT.award = function (G, p, who) {
    const s = G.s;
    let o = PT.collectionMultiplier(s);
    if (who === "sparrow") {
      const base = { butter: 2, caramel: 3, cheese: 5, rainbow: 10, golden: 10 }[p.type] || 1;
      const xp = base * sparrowXpMult(s, false);
      s.sparrow.xp += xp;
      o *= (PT.hasSun(s, "d_mecha_birb") ? 2 : 1) * (PT.hasSun(s, "d_sparrow_hoard") ? 5 : 1);
    }
    const v = D(Math.floor(PT.TYPES[p.type].baseValue * o));
    PT.add(s, "popcorn", v);
    s.totalPopcornCollected = D(s.totalPopcornCollected).add(v);
    G.gain("popcorn", v);
    if (G.onFloat && (who === "player" || G.s.currentMap === 0)) G.onFloat(p.x, p.y, "+" + PT.fmt(v), PT.TYPES[p.type].color);
  };

  // ------------------------------------------------------------------ Molt (Birb: getPotentialPrestigePoints / performRebirth)
  PT.playtimeMult = (s) => (PT.hasSun(s, "d_rebirth_playtime") ? Math.min(10, 1 + 0.01 * (s.playTime / 60)) : 1);
  PT.prestigePayoutMult = (s) => PT.fishMult(s, "feather_mult") * (s.evolutionCount >= 2 ? s.evolutionCount : 1) * auricRebirb(s);
  function auricRebirb(s) { // archivist node, echo phase
    if (!PT.hasSun(s, "d_archivist_auric_rebirb")) return 1;
    const i = Math.log10(PT.num(s.resources.goldenPopcorn) + 1) / 16;
    return 1 + (i <= 1 ? 6 * i : 6 * (1 + Math.log(1 + (i - 1)) / 10));
  }
  PT.prestige = function (s) {
    const base = PT.res(s, "popcorn").div(1000).floor();
    const play = PT.playtimeMult(s);
    const fe = (PT.level(s, "s_more_feathers") > 0 && PT.effect(s, "s_more_feathers")) || 1;
    let a = play + (fe - 1);
    if (PT.hasSun(s, "d_golden_harvest")) a *= 3;
    if (PT.hasSun(s, "d_desert_rebirb_golden_feathers")) a *= 2;
    a *= 1 + questBonus(s, "feather_gain_mult");
    const pay = PT.prestigePayoutMult(s);
    return { base, a, pay, play, final: base.mul(a).mul(pay).floor() };
  };
  PT.molt = function (G) {
    const s = G.s, { final } = PT.prestige(s);
    if (final.lt(1)) return false;
    s.resources.popcorn = D(0);
    G.field.clear();
    for (const def of PT.UP.values()) if (def.tree === "P" && !def.permanent) delete s.upgrades[def.id];
    PT.add(s, "goldenFeathers", final);
    G.gain("goldenFeathers", final);
    s.rebirthCount = (s.rebirthCount || 0) + 1;
    return true;
  };

  // ------------------------------------------------------------------ seeds (Birb: update(), sunflower machine block)
  PT.seedRate = function (s, onPlatform) {
    if (!PT.hasSun(s, "d_sunflower_machine")) return { ticksPerSec: 0, perTick: 0 };
    if (!(onPlatform || PT.hasSun(s, "d_auto_gen"))) return { ticksPerSec: 0, perTick: 0 };
    let a = 1;
    if (PT.hasSun(s, "d_faster_seeds")) a *= 2;
    if (PT.hasSun(s, "d_seed_pipeline")) a *= 1.25;
    a *= nestSeedProductionMult(s);
    let m = PT.hasSun(s, "d_seed_multiplier") ? logCurve(s.resources.goldenFeathers, 2e4, 0.8, 1) : 1;
    const r = PT.level(s, "s_more_seeds"); if (r > 0) m *= r;
    if (PT.hasSun(s, "d_golden_harvest")) m *= 3;
    if (PT.hasSun(s, "d_seed_bag")) m *= 1.5;
    if (PT.hasSun(s, "d_fish_seeds")) m *= logCurve(s.totalFishCaught || 0, 10, 1.4, 1);
    let desertSeed = 1;
    for (const id of ["d_desert_seed_generation_x2", "d_desert_seed_generation_x5", "d_desert_seed_generation_x2_plus", "d_desert_bountiful_harvest"]) if (PT.hasSun(s, id)) desertSeed *= 2;
    const perTick = m * PT.fishMult(s, "seed_mult") * (s.evolutionCount >= 2 ? s.evolutionCount : 1) * PT.sparrowDrainMult(s) *
      (1 + questBonus(s, "seed_gain_mult")) * flockCommunity(s) * desertSeed * redPandaNap(s) * grainSilo(s);
    return { ticksPerSec: a, perTick };
  };

  // ------------------------------------------------------------------ Sparrow (Birb: fz, sz, oz, ZH, updateSparrow)
  const SP = { xpPerLevel: 40, base: 150, growth: 2, max: 2048, full: 16 };
  PT.SPARROW_MILESTONES = [
    { id: "resonance_flow", name: "Resonance Flow", type: "mitoses", req: 1, eff: "drained_xp_mult", val: 1.25, text: "1 mitosis: drained XP x1.25" },
    { id: "steady_feeder", name: "Steady Feeder", type: "level", req: 50, eff: "seed_feed_xp_mult", val: 1.5, text: "Reach LV 50: feed XP x1.5" },
    { id: "mitosis_rhythm", name: "Mitosis Rhythm", type: "mitoses", req: 2, eff: "mitosis_requirement_mult", val: 0.8, text: "2 mitoses: mitosis needs x0.8" },
    { id: "full_flock", name: "Full Flock", type: "mitoses", req: 3, eff: "seed_feed_xp_mult", val: 1.25, text: "3 mitoses: feed XP x1.25" },
    { id: "first_rebirb", name: "First Rebirb", type: "rebirbs", req: 1, eff: "drained_xp_mult", val: 1.25, auto: "mitosis", text: "1 rebirb: drained XP x1.25, auto mitosis" },
    { id: "loop_engine", name: "Loop Engine", type: "rebirbs", req: 5, eff: "mitosis_requirement_mult", val: 0.85, auto: "rebirb", text: "5 rebirbs: mitosis needs x0.85, auto rebirb" },
  ];
  const sparrowFeaturesOn = (s) => (s.evolutionCount || 0) >= 2; // Birb KH
  PT.mitosisCount = (s) => (s.sparrowPrestigeCount || 0) * Math.log2(SP.full) + Math.max(0, Math.floor(Math.log2(Math.max(1, Math.min(SP.full, s.sparrowCount || 1)))));
  PT.milestoneMet = function (s, m) {
    if (!sparrowFeaturesOn(s)) return false;
    if (m.type === "level") return Math.max(s.sparrow.level || 1, s.sparrow.maxLevelReached || 1) >= m.req;
    if (m.type === "mitoses") return PT.mitosisCount(s) >= m.req;
    return (s.sparrowPrestigeCount || 0) >= m.req;
  };
  const milestoneMult = (s, eff) => PT.SPARROW_MILESTONES.reduce((n, m) => (m.eff === eff && PT.milestoneMet(s, m) ? n * m.val : n), 1);
  PT.sparrowXpNeeded = (L) => { const i = Math.max(1, Math.floor(L || 0)); if (i <= 100) return i * SP.xpPerLevel; const a = i - 100; return Math.floor(SP.xpPerLevel * (100 + a * a)); };
  PT.sparrowTotalXp = (L, xp) => { let t = xp; for (let a = 1; a < L; a++) t += PT.sparrowXpNeeded(a); return t; };
  PT.mitosisNeed = function (s, count) {
    const t = Math.max(1, Math.floor(count || 1));
    const n = t === 1 ? 1e4 : t === 2 ? 1e5 : t === 4 ? 1e6 : t === 8 ? 1e7 : t >= SP.full ? 16e6 : 5e5 * t;
    return Math.max(1, Math.floor(n * milestoneMult(s, "mitosis_requirement_mult")));
  };
  PT.sparrowSpeed = (s) => Math.min(SP.base + (s.sparrow.level - 1) * SP.growth, SP.max * (PT.hasSun(s, "d_hive_mind") ? 1.5 : 1));
  PT.sparrowDrainMult = (s) => (sparrowFeaturesOn(s) ? 1 + (2.5 * Math.log(1 + (s.sparrowResonanceXP || 0) / 5e3)) / Math.log(40.6) : 1);
  PT.sparrowRebirbBoost = (s) => sqrtBoost(s.sparrowPrestigeCount || 0, 1.5, 10);
  // Birb uz (seed feed) / the pickup XP multiplier (same minus the feed milestone)
  function sparrowXpMult(s, feed) {
    let t = feed ? 0.01 : 1;
    if (PT.hasSun(s, "d_sparrow_xp_2")) t *= 1.25;
    if (PT.hasSun(s, "d_sparrow_snacks")) t *= 1.5;
    if (PT.hasSun(s, "d_sparrow_wisdom")) t *= 1.5;
    t *= sqrtBoost(s.sparrowPrestigeCount || 0, 2);
    if (feed) t *= milestoneMult(s, "seed_feed_xp_mult");
    return t; // hat bonus: none in the playtest
  }
  PT.seedFeedXp = (s) => sparrowXpMult(s, true);
  const seedCostPerUnit = (s) => (PT.hasSun(s, "d_sparrow_xp_2") ? 0.75 : 1);
  // Birb fz: feed a % of seed income, capped at 25% of the current level's XP per second
  PT.feedSparrow = function (G, dt) {
    const s = G.s;
    if (!s.isFeedingSparrow) return;
    if (!PT.hasSun(s, "d_seed_feeder") || s.isDrainingSparrow) { s.isFeedingSparrow = false; return; }
    const seeds = PT.num(s.resources.sunflowerSeeds);
    if (seeds <= 0) return;
    const rate = Math.max(0, G.rates.sunflowerSeeds || 0);
    if (rate <= 0) return;
    const pct = Math.max(1, Math.min(100, Math.floor(s.sparrowSeedFeedRatePercent || 25))) / 100;
    const xpPer = PT.seedFeedXp(s), cap = (0.25 * PT.sparrowXpNeeded(s.sparrow.level)) / xpPer;
    const i = Math.min(rate * pct, cap * pct);
    const per = seedCostPerUnit(s);
    const o = Math.min(i * dt, seeds / per, cap * dt);
    if (o > 0) { PT.sub(s, "sunflowerSeeds", o * per); s.sparrow.xp += o * xpPer; }
  };
  // Birb: resonance drain (d_sparrow_drain_power, Evolution 2+)
  PT.drainSparrow = function (s, dt) {
    if (!(s.isDrainingSparrow && sparrowFeaturesOn(s) && PT.hasSun(s, "d_sparrow_drain_power"))) return;
    const sp = s.sparrow, before = PT.sparrowTotalXp(sp.level, sp.xp);
    let r = PT.sparrowXpNeeded(sp.level) * Math.max(2, 0.1 * sp.level) * dt;
    const take = Math.min(sp.xp, r); sp.xp -= take; r -= take;
    while (r > 1e-10 && sp.level > 1) { sp.level--; const need = PT.sparrowXpNeeded(sp.level), t = Math.min(r, need); sp.xp = need - t; r -= t; }
    const drained = Math.max(0, before - PT.sparrowTotalXp(sp.level, sp.xp)) * milestoneMult(s, "drained_xp_mult");
    s.sparrowResonanceXP = (s.sparrowResonanceXP || 0) + drained;
    s.sparrowTotalEnergyDrained = (s.sparrowTotalEnergyDrained || 0) + drained;
  };
  PT.sparrowLevelUps = function (s) {
    const sp = s.sparrow; let need = PT.sparrowXpNeeded(sp.level);
    while (sp.xp >= need) { sp.xp -= need; sp.level++; need = PT.sparrowXpNeeded(sp.level); }
    sp.maxLevelReached = Math.max(sp.maxLevelReached || 1, sp.level);
  };
  // Birb sz: mitosis doubles the flock and resets the level to 0
  PT.mitosis = function (s) {
    const t = Math.max(1, Math.floor(s.sparrowCount || 1));
    if (!PT.hasSun(s, "d_sparrow_mitosis") || t >= SP.full) return false;
    if (PT.sparrowTotalXp(s.sparrow.level, s.sparrow.xp) < PT.mitosisNeed(s, t)) return false;
    s.sparrowCount = Math.min(SP.full, 2 * t); s.sparrow.level = 0; s.sparrow.xp = 0; s.isDrainingSparrow = false;
    return true;
  };
  // Birb oz: rebirb at 16 sparrows; also needs the nest's first tier (rz -> nestManager.canMigrate)
  PT.sparrowRebirbReady = (s) => (PT.nestCanMigrate ? PT.nestCanMigrate(s) : (s.nest?.tier || 0) >= 1);
  PT.sparrowRebirb = function (s) {
    const n = Math.max(1, Math.floor(s.sparrowCount || 1));
    if (!PT.sparrowRebirbReady(s) || n < SP.full) return false;
    if (PT.sparrowTotalXp(s.sparrow.level, s.sparrow.xp) < PT.mitosisNeed(s, n)) return false;
    s.sparrowCount = 1; s.sparrowPrestigeCount = (s.sparrowPrestigeCount || 0) + 1; s.sparrow.level = 1; s.sparrow.xp = 0; s.isDrainingSparrow = false;
    return true;
  };
  PT.autoSparrow = function (s) {
    if (!PT.hasSun(s, "d_sparrow_mitosis")) return;
    const auto = (k) => PT.SPARROW_MILESTONES.some((m) => m.auto === k && PT.milestoneMet(s, m));
    if (s.sparrowAutoRebirbEnabled && auto("rebirb")) PT.sparrowRebirb(s);
    if (s.sparrowAutoMitosisEnabled && auto("mitosis")) PT.mitosis(s);
  };

  // Birb: updateSparrow movement. Sparrows hunt eggs on the Park field, anchored on the bird (or where it left).
  PT.updateSparrows = function (G, dt) {
    const s = G.s;
    if (!s.sparrow.unlocked) { G.sparrows = []; return; }
    if (s.currentMap === 0) G.anchor = { x: s.player.x, y: s.player.y };
    PT.feedSparrow(G, dt);
    PT.drainSparrow(s, dt);
    PT.sparrowLevelUps(s);
    PT.autoSparrow(s);
    const n = s.sparrowCount || 1, A = G.anchor || { x: 528, y: 396 };
    while (G.sparrows.length < n) G.sparrows.push({ x: A.x - 30 - 20 * G.sparrows.length, y: A.y - 60, target: null, timer: 0, state: "idle", face: 1 });
    while (G.sparrows.length > n) G.sparrows.pop();
    const h = 0.016, acc = (G.sparrowAcc || 0) + dt, steps = Math.floor((acc + 1e-10) / h);
    G.sparrowAcc = Math.max(0, acc - steps * h);
    if (steps <= 0) return;
    const field = G.field.list(0), c = PT.sparrowSpeed(s);
    const byId = new Map(field.map((p) => [p.id, p]));
    const claimed = new Set();
    for (const b of G.sparrows) if (b.target != null && b.target !== -1 && byId.has(b.target)) claimed.add(b.target); else if (b.target !== -1) b.target = null;
    for (let k = 0; k < Math.min(steps, 30); k++) {
      for (const b of G.sparrows) {
        if (b.target === null || b.target === -1) {
          let best = Infinity, id = null;
          for (const p of field) { if (claimed.has(p.id)) continue; const d = (p.x - b.x) ** 2 + (p.y - b.y) ** 2; if (d < best) { best = d; id = p.id; } }
          if (id !== null) { b.target = id; claimed.add(id); } else if (b.target === null) b.target = -1;
        }
        let tx, ty;
        if (b.target === -1) {
          if (b.idleT > 0) { tx = b.ix; ty = b.iy; b.idleT -= h; }
          else { const an = Math.random() * Math.PI * 2, r = 100 + 150 * Math.random(); b.ix = A.x + Math.cos(an) * r; b.iy = A.y + Math.sin(an) * r; b.idleT = 1 + 2 * Math.random(); tx = b.ix; ty = b.iy; }
        } else {
          const p = byId.get(b.target);
          if (p) { tx = p.x; ty = p.y; } else { b.target = null; tx = A.x; ty = A.y - 60; }
        }
        const dx = tx - b.x, dy = ty - b.y, d = Math.hypot(dx, dy);
        if (Math.abs(dx) > 2) b.face = dx > 0 ? 1 : -1;
        const step = c * h;
        const collect = () => { const p = G.field.take(0, b.target); if (p) { byId.delete(p.id); PT.award(G, p, "sparrow"); } b.target = null; b.timer = 0; };
        if (d > Math.max(5, Math.min(0.5 * step, 50))) {
          b.state = "fly";
          if (step >= d) { b.x = tx; b.y = ty; if (b.target !== -1 && b.target !== null) { b.state = "peck"; collect(); } }
          else { b.x += (dx / d) * step; b.y += (dy / d) * step; }
        } else if (b.target !== -1) {
          b.state = "peck"; b.timer += h;
          if (b.timer > Math.max(0.01, (200 / Math.max(c, 200)) * 0.2)) collect();
        } else { b.state = "idle"; if (field.length > G.sparrows.length) b.target = null; }
      }
    }
  };

  // ------------------------------------------------------------------ Castle monster (Birb: sR.feedMonster / _h / performEvolutionReset)
  PT.EVO_REQ = [
    { popcorn: 1e7, feathers: 0, seeds: 0, fish: 0, twigs: 0, moneta: 0 },
    { popcorn: 1e10, feathers: 0, seeds: 0, fish: 0, twigs: 0, moneta: 1e3 },
    { popcorn: 25e10, feathers: 0, seeds: 3e7, fish: 0, twigs: 0, moneta: 0 },
    { popcorn: 1e15, feathers: 0, seeds: 0, fish: 0, twigs: 1e5, moneta: 1e4 },
    { popcorn: 1e18, feathers: 0, seeds: 0, fish: 0, twigs: 1e6, moneta: 0 },
  ];
  const ZERO_REQ = { popcorn: 0, feathers: 0, seeds: 0, fish: 0, twigs: 0, moneta: 0 };
  PT.evoReq = (n) => PT.EVO_REQ[Math.max(0, Math.floor(n || 0))] ?? ZERO_REQ;
  PT.evoCap = (s) => (s.expedition?.hasRescuedCastleMonster ? 6 : 5);
  PT.canEvolveStage = (s) => !((s.evolutionCount || 0) >= PT.evoCap(s)) && ((s.evolutionCount || 0) !== 0 || PT.hasSun(s, "d_unlock_evolve"));
  PT.feedProgress = function (s) {
    if ((s.evolutionCount || 0) === 5) return s.expedition?.hasRescuedCastleMonster ? 100 : 0;
    const t = PT.evoReq(s.evolutionCount);
    const rows = [[s.monsterPopcornFed, t.popcorn], [s.monsterFeathersFed, t.feathers], [s.monsterSeedsFed, t.seeds], [s.monsterFishFed, t.fish], [s.monsterTwigsFed, t.twigs], [s.monsterMonetaFed, t.moneta]];
    let a = 0, r = 0;
    for (const [n, o] of rows) { if (o <= 0) continue; a += Math.min(1, Math.max(0, Number(n) || 0) / o); r++; }
    return r > 0 ? (a / r) * 100 : 0;
  };
  // pct: share of each requirement fed per call (hold = 10% per second, a click = 1%)
  PT.feedMonster = function (s, pct) {
    if ((s.evolutionCount || 0) >= 5) return;
    const n = PT.evoReq(s.evolutionCount);
    const feed = (cur, fedKey, need) => {
      if (need <= 0 || s[fedKey] >= need) return;
      const have = PT.res(s, cur); if (have.lte(0)) return;
      const amt = PT.num(Decimal.min(need * (pct / 100), Decimal.min(have, need - s[fedKey])));
      PT.sub(s, cur, amt); s[fedKey] += amt;
    };
    feed("popcorn", "monsterPopcornFed", n.popcorn);
    feed("goldenFeathers", "monsterFeathersFed", n.feathers);
    feed("sunflowerSeeds", "monsterSeedsFed", n.seeds);
    if (n.fish > 0 && s.monsterFishFed < n.fish) s.monsterFishFed = Math.min(n.fish, s.totalFishCaught || 0);
    feed("twigs", "monsterTwigsFed", n.twigs);
    feed("monetariaMoneta", "monsterMonetaFed", n.moneta);
    s.monsterFeedProgress = Math.min(100, PT.feedProgress(s));
  };
  // Birb: evolvePigeon -> performEvolutionReset -> onEvolutionReset (Phase 1 parts)
  const KEEP_SUN = new Set(["d_unlock_evolve", "d_unlock_desert_tree", "d_double_catch", "d_seagull_synergy"]);
  PT.evolve = function (G) {
    const s = G.s;
    if (!PT.canEvolveStage(s) || PT.feedProgress(s) < 100) return false;
    s.evolutionCount = Math.min(PT.evoCap(s), (s.evolutionCount || 0) + 1);
    for (const k of ["monsterFeedProgress", "monsterPopcornFed", "monsterFeathersFed", "monsterSeedsFed", "monsterFishFed", "monsterTwigsFed", "monsterMonetaFed"]) s[k] = 0;
    const ups = {};
    for (const def of PT.UP.values()) { if (!def.permanent || def.tree === "M") continue; const L = s.upgrades[def.id] || 0; if (L > 0) ups[def.id] = L; }
    const sun = {};
    for (const [id, def] of PT.SUN) { const L = s.sunflowerUpgrades[id] || 0; if (L > 0 && (KEEP_SUN.has(id) || def.permanent)) sun[id] = L; }
    if (s.sparrow.unlocked) {
      s.sparrow.level = 0; s.sparrow.xp = 0;
      if (s.evolutionCount === 2) s.sparrow.maxLevelReached = 1;
      s.sparrowCount = 1; G.sparrows = []; s.isDrainingSparrow = false; s.isFeedingSparrow = false; s.sparrowResonanceXP = 0;
    }
    s.upgrades = ups; s.sunflowerUpgrades = sun;
    for (const k of ["popcorn", "goldenPopcorn", "echoPopcorn", "goldenFeathers", "sunflowerSeeds", "monetariaMoneta", "twigs"]) s.resources[k] = D(0);
    G.field.clear();
    if (s.fishing) { // Birb onEvolutionReset: fish, bait and buffs go; rods, total catches and fishing level stay
      s.fishInventory = []; s.fishing.xp = 0; s.fishing.baitInventory = []; s.fishing.equippedBaitId = undefined;
      s.activeFishIds = []; s.activeFishBuffs = {};
    }
    if (s.evolutionCount >= 1) s.sparrow.unlocked = true;
    if (PT.nestOnEvolve) PT.nestOnEvolve(G);
    if (PT.mineOnEvolve) PT.mineOnEvolve(G);
    s.currentMap = 0; s.player.x = 528; s.player.y = 396;
    return true;
  };
})();
