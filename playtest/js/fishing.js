// Peckwood playtest: Bridge fishing and the Seagull, 1:1 with Birb (fishingManager SF, XB roll pool, seagull PB/RB/LB).
"use strict";
(function () {
  const PT = window.PT;
  const T = window.BIRB_DATA.tables;
  const FISH = T.fish, RODS = T.rods, TACKLE = T.baits;
  const FISH_BY = new Map(FISH.map((f) => [f.id, f]));
  const TACKLE_BY = new Map(TACKLE.map((b) => [b.id, b]));
  PT.FISH = FISH; PT.RODS = RODS; PT.TACKLE = TACKLE; PT.FISH_BY = FISH_BY; PT.TACKLE_BY = TACKLE_BY;

  const SHINY = "__shiny";
  const isShiny = (id) => id.endsWith(SHINY);
  const baseId = (id) => (isShiny(id) ? id.slice(0, -7) : id);
  PT.isShiny = isShiny; PT.baseFishId = baseId;
  const RANK = { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4, mythic: 5 };
  PT.RARITY_COLOR = { common: "#9ca3af", uncommon: "#22c55e", rare: "#3b82f6", epic: "#a855f7", legendary: "#f59e0b", mythic: "#ff597d" };
  const TUNE = { xpPerFish: { common: 5, uncommon: 15, rare: 40, epic: 100, legendary: 300, mythic: 600 }, xpPerLevel: 100, levelScaling: 1.2, cooldownReductionPerLevel: 0.02 };
  // Names live in Birb's translation files; build readable ones from the id.
  PT.fishName = (id) => {
    const b = baseId(id).replace(/^exp_f\d+_/, "").replace(/^fish_/, "").split("_").map((w) => w[0].toUpperCase() + w.slice(1)).join(" ");
    return (isShiny(id) ? "Shiny " : "") + b;
  };
  PT.itemName = (id) => id.replace(/^(rod|hook|lure|bait|shiny_bait)_/, "").split("_").map((w) => w[0].toUpperCase() + w.slice(1)).join(" ");

  // ------------------------------------------------------------------ state
  PT.ensureFishing = function (s) {
    if (!s.fishing) s.fishing = { level: 1, xp: 0, equippedRodId: "rod_simple", ownedRods: ["rod_simple"], equippedLureId: "lure_basic", unlockedLures: ["lure_basic"], unlockedHooks: [], baitInventory: [], monetaWealthPeak: 0 };
    s.fishInventory = s.fishInventory || [];
    s.discoveredFish = s.discoveredFish || [];
    s.discoveredShinyFish = s.discoveredShinyFish || [];
    s.fishWeightRecords = s.fishWeightRecords || [];
    s.activeFishIds = s.activeFishIds || [];
    s.activeFishBuffs = s.activeFishBuffs || {};
    s.lockedFish = s.lockedFish || [];
    if (!s.seagull) s.seagull = { discovered: false, level: 1, xp: 0, migrationCount: 0, hasReborn: false, autoRebirbEnabled: false, frenzyActiveUntil: 0, frenzyCooldownUntil: 0,
      dailyLegendaryReadyAt: 0, forecastTimelineMs: Date.now(), dailyLegendaryCycle: 0, randomSeed: (Date.now() ^ Math.floor(4294967296 * Math.random())) >>> 0,
      gulls: [{ routeId: "bridge", doctrine: "balanced", equippedRodId: "rod_simple", pendingDoctrine: null, progressSeconds: 0, lastCatchSummary: null }] };
    return s.fishing;
  };

  // ------------------------------------------------------------------ inventory helpers
  PT.speciesCount = (s, id) => (s.fishInventory || []).reduce((t, n) => (baseId(n.fishId) !== id ? t : t + Math.max(0, n.count || 0)), 0);
  // Birb consumeFishSpecies: normal copies first, then shiny
  PT.consumeSpecies = function (s, id, n) {
    if (n <= 0) return true;
    if (PT.speciesCount(s, id) < n) return false;
    let a = n;
    for (const shinyPass of [false, true]) for (const e of s.fishInventory) {
      if (a <= 0) break;
      if (baseId(e.fishId) !== id || isShiny(e.fishId) !== shinyPass) continue;
      const take = Math.min(e.count, a); e.count -= take; a -= take;
    }
    s.fishInventory = s.fishInventory.filter((e) => e.count > 0);
    return a <= 0;
  };
  function addFish(s, id, shiny, who) {
    if (!s.discoveredFish.includes(id)) s.discoveredFish.push(id);
    if (shiny) { s.lastShinyFishCaughtAt = Date.now(); if (who === "player") s.lastPlayerShinyFishCaughtAt = Date.now(); if (!s.discoveredShinyFish.includes(id)) s.discoveredShinyFish.push(id); }
    const key = shiny ? id + SHINY : id;
    const row = s.fishInventory.find((e) => e.fishId === key);
    if (row) row.count++; else s.fishInventory.push({ fishId: key, count: 1 });
  }
  const bestTier = (owned) => RODS.reduce((t, r) => (owned.includes(r.id) ? Math.max(t, r.tier) : t), 0);
  const rodById = (id) => RODS.find((r) => r.id === id) || RODS[0];
  const fastestRod = (owned) => { let n = RODS[0]; for (const r of RODS) if (owned.includes(r.id) && r.speedBonus < n.speedBonus) n = r; return n; };
  const richestRod = (owned) => { let n = RODS[0]; for (const r of RODS) if (owned.includes(r.id) && r.monetaPerCatch > n.monetaPerCatch) n = r; return n; };

  // ------------------------------------------------------------------ tackle rules (Birb getTackleUnlockRequirement)
  PT.tackleReq = function (s, item) {
    const f = PT.ensureFishing(s), evo = s.evolutionCount || 0;
    if (item.type === "hook") {
      const have = new Set([...(f.unlockedHooks || []), ...(f.unlockedLures || [])]);
      if (have.has(item.id)) return "";
      if (item.requiredHookId && !have.has(item.requiredHookId)) return "needs " + PT.itemName(item.requiredHookId) + " first";
      if ((item.evolutionRequired || 0) > evo) return "needs Evolution " + item.evolutionRequired;
      if ((item.rodTierRequired || 0) > bestTier(f.ownedRods)) return "needs rod tier " + item.rodTierRequired;
      if ((item.fishingLevelRequired || 0) > (f.level || 1)) return "needs fishing LV " + item.fishingLevelRequired;
      return "";
    }
    if (item.aquariumRequired && !PT.aquariumUnlocked(s)) return "needs the Aquarium";
    if ((item.evolutionRequired || 0) > evo) return "needs Evolution " + item.evolutionRequired;
    return "";
  };
  PT.aquariumUnlocked = () => false; // aquarium phase
  const usableLure = (s, id) => { const t = id && TACKLE_BY.get(id); return t && t.type === "lure" && !PT.tackleReq(s, t) ? id : undefined; };

  // ------------------------------------------------------------------ fish buffs (Birb getActiveFishEffectSnapshot)
  const SHINY_BUFF_MS = (s) => (PT.aqShinyBuffMs ? PT.aqShinyBuffMs(s) : 864e5); // 24h, +12h from the Glass Tide aquarium milestone
  PT.normalizeFishBuffs = function (s, now = Date.now()) {
    const out = [];
    for (const id of s.activeFishIds || []) {
      let n = id;
      if (isShiny(id)) {
        const at = Number(s.activeFishBuffs[id]?.activatedAt || 0);
        if (at > 0 && now >= at + SHINY_BUFF_MS(s)) { n = baseId(id); delete s.activeFishBuffs[id]; }
        else if (!(at > 0)) s.activeFishBuffs[id] = { activatedAt: now };
      }
      if (!out.includes(n)) out.push(n);
    }
    s.activeFishIds = out;
  };
  PT.activeFishMult = function (s, type, now = Date.now()) {
    let sum = 0, any = false; const dur = SHINY_BUFF_MS(s), nb = PT.aqNormalBuffMult ? PT.aqNormalBuffMult(s) : 1;
    for (const id of s.activeFishIds || []) {
      const f = FISH_BY.get(baseId(id)); if (!f?.effect || f.effect.type !== type) continue;
      const v = Number(f.effect.value) - 1;
      const at = Number(s.activeFishBuffs?.[id]?.activatedAt || 0);
      sum += isShiny(id) && at > 0 && at + dur > now ? 3 * v : v * nb; any = true; // Birb getScaledActiveFishBuffValue
    }
    return any ? Math.max(0, 1 + sum) : 1;
  };
  // Birb getFishMultiplier (replaces the Phase 1 stub)
  PT.fishMult = function (s, e) {
    let t = PT.activeFishMult(s, e);
    if (PT.aqModifier && e !== "expedition_mult") t *= PT.aqModifier(s, e); // aquarium biomes + milestones
    if ((e === "reel_speed_mult" || e === "xp_mult") && PT.contractBonus) t *= 1 + PT.contractBonus(s, e); // fish market contracts
    const n = e === "xp_mult" && (s.evolutionCount || 0) >= 6 ? 2 : 1;
    const f = s.fishing; if (!f) return t * n;
    for (const id of [f.equippedBaitId, f.equippedLureId, f.equippedHookId]) {
      const it = id && TACKLE_BY.get(id); if (!it?.effect) continue;
      const a = it.effect;
      if ((a.type === "speed" && e === "speed_mult") || (a.type === "radius" && e === "pickup_mult") || a.type === e) t *= a.value;
    }
    return (t + (e === "xp_mult" ? 0.05 * (Math.max(1, Math.floor(f.level || 1)) - 1) : 0)) * n;
  };
  PT.maxFishBuffs = (s) => { // Birb getMaxActiveFishBuffs
    const e = PT.hasSun(s, "d_double_fish_buff") ? 1 : 0, t = PT.aqBuffSlots ? PT.aqBuffSlots(s) : 0;
    if (e > 0 && (s.fishBuffThirdSlotUnlocked === true || (s.activeFishIds || []).length >= 3)) { s.fishBuffThirdSlotUnlocked = true; return 3; }
    return Math.max(1, Math.min(3, 1 + e + t));
  };
  PT.eatFish = function (s, key) {
    PT.normalizeFishBuffs(s);
    const f = FISH_BY.get(baseId(key)); if (!f?.effect) return "no effect";
    const row = s.fishInventory.find((e) => e.fishId === key); if (!row || row.count <= 0) return "none left";
    if (s.activeFishIds.includes(key)) return "already active";
    if (s.activeFishIds.length >= PT.maxFishBuffs(s)) s.activeFishIds.shift(); // Birb asks which to replace; the playtest replaces the oldest
    row.count--; s.fishInventory = s.fishInventory.filter((e) => e.count > 0);
    s.activeFishIds.push(key);
    if (isShiny(key)) s.activeFishBuffs[key] = { activatedAt: Date.now() };
    return "";
  };

  // ------------------------------------------------------------------ roll pool (Birb XB / YB)
  function nextRodState(s) {
    const owned = new Set(s.fishing.ownedRods);
    const left = RODS.filter((r) => !owned.has(r.id)).sort((a, b) => a.tier - b.tier), next = left[0] || null;
    const need = new Set();
    for (const c of next?.cost || []) if (PT.speciesCount(s, c.fishId) < c.count) need.add(c.fishId);
    return { next, need };
  }
  function neededUpgradeFish(s) { // sunflower nodes paid in fish that are visible, unlocked and not yet affordable
    const out = new Set();
    for (const [id, n] of PT.SUN) {
      if (!FISH_BY.has(n.costCurrency)) continue;
      if ((s.sunflowerUpgrades[id] || 0) >= (n.maxLevel || 1)) continue;
      if (!PT.sunVisible(s, id) || !PT.sunUnlocked(s, id)) continue;
      if (PT.speciesCount(s, n.costCurrency) < PT.sunCost(s, id)) out.add(n.costCurrency);
    }
    return out;
  }
  const typeFilterOf = (baitId) => { const t = baitId && TACKLE_BY.get(baitId); return t && t.type === "consumable" && (t.effect.type === "type_boost" || t.effect.type === "shiny_type_boost") ? t.effect.targetType : null; };
  const hookMult = (h, r) => ({ hook_bronze: r === "uncommon" ? 2 : 1, hook_iron: r === "rare" ? 2.5 : 1, hook_gold: r === "epic" ? 3 : 1, hook_diamond: r === "legendary" ? 4 : 1,
    hook_ancient: r === "legendary" ? 4 : r === "epic" ? 2.5 : r === "rare" ? 1.5 : 1, hook_cursed: r === "common" ? 3 : 1 }[h] || 1);
  PT.rollPool = function (s, rod, baitId, lureId, hookId, minRarity) {
    const f = s.fishing;
    let pool = FISH.filter((t) => (t.expeditionFloor || 0) <= 0 && (t.minTier || 0) <= rod.tier + 1 && (!minRarity || RANK[t.rarity] >= RANK[minRarity]));
    const tf = typeFilterOf(baitId), typed = tf ? pool.filter((t) => t.type === tf) : pool;
    const baitApplied = !tf || typed.length > 0;
    if (baitApplied) pool = typed;
    const prog = nextRodState(s).need; for (const x of neededUpgradeFish(s)) prog.add(x);
    const disc = new Set(s.discoveredFish), housed = new Set(Object.entries(s.aquarium?.housedFish || {}).filter(([, v]) => v === true).map(([k]) => k));
    const luck = Math.max(1, 1 + (PT.contractBonus ? PT.contractBonus(s, "fishing_luck_mult") : 0)); // Birb getUncommonPlusWeightMultiplier
    const progMult = PT.hasSun(s, "d_rod_chance") ? 1.15 : 1;
    const entries = pool.map((t) => {
      let w = Math.max(1e-12, Number(t.weight) || 0);
      if ((t.minTier || 0) > rod.tier) w *= 0.15;
      w *= hookMult(hookId, t.rarity);
      if ((lureId === "lure_basic" && prog.has(t.id)) || (lureId === "lure_advanced" && !disc.has(t.id)) || (lureId === "lure_pro" && !housed.has(t.id))) w *= 3;
      if (lureId === "lure_basic" && prog.has(t.id)) w *= progMult;
      if (t.rarity !== "common") w *= luck;
      for (const id of [baitId, hookId, lureId]) { const e = id && TACKLE_BY.get(id); if (e?.effect.type === "specific_fish" && e.effect.targetFish?.includes(t.id)) w *= Math.max(1e-12, Number(e.effect.value) || 1); }
      return { fish: t, weight: Math.max(1e-12, w) };
    });
    const total = entries.reduce((a, e) => a + e.weight, 0);
    return { entries, total, baitApplied };
  };
  function pick(pool) {
    if (!pool.entries.length || pool.total <= 0) return null;
    let n = Math.min(0.999999999999, Math.random()) * pool.total;
    for (const e of pool.entries) { n -= e.weight; if (n <= 0) return e.fish; }
    return pool.entries[pool.entries.length - 1].fish;
  }
  function consumeBait(s, id) {
    const it = id && TACKLE_BY.get(id); if (!it || it.type !== "consumable") return;
    const f = s.fishing, row = f.baitInventory.find((b) => b.baitId === id);
    if (row) row.count--;
    f.baitInventory = f.baitInventory.filter((b) => b.count > 0);
    if (!f.baitInventory.some((b) => b.baitId === id)) { if (f.equippedBaitId === id) f.equippedBaitId = undefined; }
  }
  PT.rollFish = function (s, rod, bait, lure, hook, consume = true, minRarity) {
    const pool = PT.rollPool(s, rod, bait, usableLure(s, lure), hook, minRarity), f = pick(pool);
    if (f && consume && pool.baitApplied) consumeBait(s, bait);
    return f;
  };

  // ------------------------------------------------------------------ shiny chance (Birb VI / _B / QI)
  const shinySoftcap = (base, mult, moon, contract = 1) => { const a = Math.max(0, base * mult); const r = (a <= 0.1 ? a : 0.1 * (1 + (Math.pow(a / 0.1, 0.9) - 1) / 0.9)) * moon * contract; return Math.max(0, Math.min(1, r || 0)); };
  const pity = (n) => Math.min(50, 1 + Math.pow(Math.max(0, Math.floor(n || 0)) / 2e3, 2));
  const moonlit = (mig, lastAt, now) => (Math.min(100, Math.floor(mig || 0)) < 75 || !(lastAt > 0) ? 1 : 1 + (Math.max(0, now - lastAt) / 36e5) * 0.4);
  const shinyBait = (baitId, fish) => { const b = baitId && TACKLE_BY.get(baitId); return b?.effect.type !== "shiny_type_boost" || (b.effect.targetType && b.effect.targetType !== fish.type) ? 1 : Math.max(1, Math.min(3, Number(b.effect.value || 1))); };
  const fleetShiny = (s) => (usableLure(s, s.fishing.equippedLureId) === "lure_legend" ? 1.5 : 1) * (PT.hasSun(s, "d_shiny_scale") ? 1 + 0.1 * bestTier(s.fishing.ownedRods) : 1);

  // ------------------------------------------------------------------ weight (Birb generateFishWeight)
  const TYPE_RANGE = { coastal: [0.1, 2], reef: [0.2, 3], freshwater: [0.15, 2.5], river: [0.2, 4], ocean: [0.5, 50], creature: [0.05, 5], exotic_reef: [0.3, 4], spirit: [0.01, 1], cosmic: [0.1, 3], mechanical: [1, 20], crab: [0.1, 5], abyssal: [0.3, 15] };
  const RAR_W = { common: 1, uncommon: 1.5, rare: 2.5, epic: 4, legendary: 8, mythic: 12 };
  PT.fishWeight = function (s, fish, shiny, tier) {
    const tr = TYPE_RANGE[fish.type || "coastal"] || [0.1, 2], rm = RAR_W[fish.rarity] || 1;
    let a = fish.minWeightKg ?? tr[0] * rm, r = fish.maxWeightKg ?? tr[1] * rm;
    const maxT = Math.max(...RODS.map((x) => x.tier)), l = Math.pow(((tier ?? maxT) + 1) / (maxT + 1), 0.9), c = a + (r - a) * l;
    a *= 0.6 + 0.4 * l; r = c;
    const d = usableLure(s, s.fishing.equippedLureId) === "lure_master" ? 1.25 : 1;
    a *= d; r *= d; if (shiny) r = 10 * (r || 1);
    const u = Math.random();
    let h = 0.1, p = 0.5, m = 1.6;
    if (u >= 0.7 && u < 0.9) { h = 0.35; p = 0.7; m = 1.2; } else if (u >= 0.9 && u < 0.97) { h = 0.6; p = 0.85; m = 1.05; }
    else if (u >= 0.97 && u < 0.995) { h = 0.8; p = 0.95; m = 0.9; } else if (u >= 0.995 && u < 0.9995) { h = 0.92; p = 1; m = 0.8; } else if (u >= 0.9995) { h = 1; p = 1.2; m = 0.7; }
    const g = r - a, f = h + (p - h) * Math.pow(Math.random(), m);
    let y = f > 1 ? r * f : a + g * f;
    y = Math.max(0.7 * a, Math.min(r * (shiny ? 1.35 : 1.2), y));
    return Math.round(100 * y) / 100;
  };
  function recordWeight(s, id, w) {
    const r = s.fishWeightRecords.find((e) => e.fishId === id);
    if (r) { if (w > r.weightKg) { r.weightKg = w; return true; } return false; }
    s.fishWeightRecords.push({ fishId: id, weightKg: w }); return true;
  }
  PT.highestFishWeight = (s) => (s.fishWeightRecords || []).reduce((m, r) => Math.max(m, r.weightKg), 0);

  // ------------------------------------------------------------------ Moneta, XP, timings
  function monetaPerCatch(s, rod, count, source) { // Birb QB / GB
    let i = PT.fishMult(s, "xp_mult");
    if (PT.hasSun(s, "d_treasure_map")) i *= 1.5;
    if (PT.hasSun(s, "d_treasure_appraisal")) i *= 2;
    if (PT.hasSun(s, "d_treasure_seeker")) i *= 2;
    if (source === "seagull") i *= 0.25;
    const per = Math.max(1, Math.floor(rod.monetaPerCatch || 1)) * i;
    return source === "seagull" ? per * count : Math.max(1, Math.round(per)) * count;
  }
  function grantMoneta(G, n) {
    if (!(n > 0)) return;
    PT.add(G.s, "monetariaMoneta", n); G.gain("monetariaMoneta", n);
    const f = G.s.fishing; if (PT.res(G.s, "monetariaMoneta").gt(f.monetaWealthPeak || 0)) f.monetaWealthPeak = PT.num(G.s.resources.monetariaMoneta);
  }
  PT.fishingXpNeeded = (L) => Math.floor(TUNE.xpPerLevel * Math.pow(TUNE.levelScaling, L - 1));
  function addFishingXp(s, e) { const f = s.fishing; f.xp += e; while (f.xp >= PT.fishingXpNeeded(f.level)) { f.xp -= PT.fishingXpNeeded(f.level); f.level++; } }
  PT.reelDuration = function (s) {
    let t = 4 * (0.35 + 0.65 * Math.max(0.05, Math.min(1, fastestRod(s.fishing.ownedRods).speedBonus || 1)));
    if (PT.hasSun(s, "d_fast_reeling")) t *= 0.75;
    return Math.max(0.2, t / PT.fishMult(s, "reel_speed_mult"));
  };
  PT.fishCooldown = function (s) {
    const f = s.fishing, t = Math.max(0.25, 3 * fastestRod(f.ownedRods).speedBonus);
    let i = 1;
    for (const id of [f.equippedBaitId, usableLure(s, f.equippedLureId), f.equippedHookId]) { const it = id && TACKLE_BY.get(id); if (it && (it.effect.type === "speed" || it.effect.type === "reel_speed_mult")) i *= it.effect.value; }
    const n = i * PT.fishMult(s, "reel_speed_mult") * (PT.hasSun(s, "d_fast_reeling") ? 1.33 : 1) * (PT.hasSun(s, "d_fish_frenzy") ? 1.25 : 1);
    const a = 1 - Math.min(0.9, Math.max(0, (Math.max(1, f.level || 1) - 1) * TUNE.cooldownReductionPerLevel));
    return Math.max(0.05, (t / n) * a);
  };
  PT.autoFishUnlocked = (s) => (s.manualFishingCatches || 0) >= 10;

  // Birb catchFish
  PT.catchFish = function (G, manual) {
    const s = G.s, f = PT.ensureFishing(s), rod = rodById(f.equippedRodId);
    let bait = f.equippedBaitId && f.baitInventory.some((b) => b.baitId === f.equippedBaitId && b.count > 0) ? f.equippedBaitId : undefined;
    if (f.equippedBaitId && !bait) f.equippedBaitId = undefined;
    const a = PT.rollFish(s, rod, bait, f.equippedLureId, f.equippedHookId);
    if (!a) return null;
    const tf = typeFilterOf(bait);
    if (bait && tf && a.type !== tf) { if (f.equippedBaitId === bait) f.equippedBaitId = undefined; bait = undefined; }
    const now = Date.now();
    const shinyRoll = (fish) => { const m = shinySoftcap(fish.rarity === "legendary" || fish.rarity === "mythic" ? 1e-5 : 2e-5, shinyBait(bait, fish) * pity(s.shinyPityCatches) * fleetShiny(s) * (PT.aqShinyChanceMult ? PT.aqShinyChanceMult(s) : 1), moonlit(s.seagull.migrationCount, s.lastPlayerShinyFishCaughtAt, now), 1 + (PT.contractBonus ? PT.contractBonus(s, "shiny_chance_mult") : 0)); const g = Math.random() < m; s.shinyPityCatches = g ? 0 : (s.shinyPityCatches || 0) + 1; return g; };
    const g = shinyRoll(a);
    addFish(s, a.id, g, "player");
    const w = PT.fishWeight(s, a, g, rod.tier); const rec = recordWeight(s, a.id, w);
    let second = null, w2 = 0, g2 = false;
    if (PT.hasSun(s, "d_double_catch") && Math.random() < 0.1) {
      second = PT.rollFish(s, rod, bait, f.equippedLureId, f.equippedHookId, false);
      if (second) { g2 = shinyRoll(second); addFish(s, second.id, g2, "player"); w2 = PT.fishWeight(s, second, g2, rod.tier); recordWeight(s, second.id, w2); }
    }
    if (PT.hasSun(s, "d_ocean_bounty")) { const v = Math.floor(100 * (w + w2)); PT.add(s, "sunflowerSeeds", v); }
    const M = second ? 2 : 1;
    grantMoneta(G, monetaPerCatch(s, richestRod(f.ownedRods), M, manual ? "manual" : "auto"));
    s.totalFishCaught = (s.totalFishCaught || 0) + M;
    if (manual) s.manualFishingCatches = Math.min(10, (s.manualFishingCatches || 0) + 1);
    const xpOf = (x) => Math.floor((TUNE.xpPerFish[x.rarity] || 5) * (PT.hasSun(s, "d_xp_tome") ? 1.5 : 1));
    addFishingXp(s, xpOf(a) + (second ? xpOf(second) : 0));
    return { fish: a, shiny: g, weight: w, record: rec, second, shiny2: g2, weight2: w2 };
  };

  // Birb buyBait (consumables stack, hooks/lures unlock once)
  PT.buyTackle = function (s, id, qty = 1) {
    const it = TACKLE_BY.get(id), f = PT.ensureFishing(s); if (!it) return "unknown";
    if (it.shiny) return "needs the fish market";
    const tackle = it.type === "lure" || it.type === "hook", o = tackle ? 1 : Math.min(1e5, Math.max(1, Math.floor(qty)));
    if (it.type === "lure" && f.unlockedLures.includes(id)) return "already owned";
    if (it.type === "hook" && (f.unlockedHooks.includes(id) || f.unlockedLures.includes(id))) return "already owned";
    const req = PT.tackleReq(s, it); if (req) return req;
    for (const c of it.cost) { const n = c.count * o; if (c.type === "currency" ? !PT.has(s, c.id, n) : PT.speciesCount(s, c.id) < n) return "not enough"; }
    for (const c of it.cost) { const n = c.count * o; if (c.type === "currency") PT.sub(s, c.id, n); else PT.consumeSpecies(s, c.id, n); }
    if (it.type === "hook") f.unlockedHooks.push(id); else if (it.type === "lure") f.unlockedLures.push(id);
    else { const r = f.baitInventory.find((b) => b.baitId === id); if (r) r.count += o; else f.baitInventory.push({ baitId: id, count: o }); }
    return "";
  };
  PT.equipTackle = function (s, id) {
    const it = TACKLE_BY.get(id), f = PT.ensureFishing(s); if (!it || PT.tackleReq(s, it)) return;
    if (it.type === "consumable") f.equippedBaitId = f.equippedBaitId === id || !f.baitInventory.some((b) => b.baitId === id) ? undefined : id;
    else if (it.type === "hook" && f.unlockedHooks.includes(id)) f.equippedHookId = f.equippedHookId === id ? undefined : id;
    else if (it.type === "lure" && f.unlockedLures.includes(id)) f.equippedLureId = f.equippedLureId === id ? undefined : id;
  };
  // Birb handleRodClick: equip owned rods; craft the next rod from fish (rods unlock in order)
  PT.rodClick = function (s, id) {
    const f = PT.ensureFishing(s), r = RODS.find((x) => x.id === id); if (!r) return "unknown";
    if (f.ownedRods.includes(id)) { f.equippedRodId = id; return ""; }
    if (r.evolutionRequired && (s.evolutionCount || 0) < r.evolutionRequired) return "needs Evolution " + r.evolutionRequired;
    const idx = RODS.findIndex((x) => x.id === id);
    if (RODS.slice(0, idx).some((x) => !f.ownedRods.includes(x.id))) return "craft the earlier rods first";
    if (!r.cost.every((c) => PT.speciesCount(s, c.fishId) >= c.count)) return "not enough fish";
    r.cost.forEach((c) => PT.consumeSpecies(s, c.fishId, c.count));
    f.ownedRods.push(id); f.equippedRodId = id; return "";
  };
  // Birb getFishSellValue / sellSafeFish: selling pays SEEDS and needs Fish Seeds
  PT.fishValueMult = function (s) {
    let e = 1;
    if (PT.hasSun(s, "d_seed_market")) e *= 1 + 4 * Math.log10((s.fishing.monetaWealthPeak || 0) / 1e3 + 1);
    if (PT.hasSun(s, "d_fish_value")) e *= 2;
    e *= 1 + 0.005 * Math.max(1, Math.floor(s.fishing.level || 1));
    return e * PT.fishMult(s, "sell_mult");
  };
  PT.sellValue = function (s, key) {
    const f = FISH_BY.get(baseId(key)); if (!f) return 0;
    let i = 1; const best = (s.fishWeightRecords.find((r) => r.fishId === baseId(key)) || {}).weightKg;
    if (best > 0) i *= PT.hasSun(s, "d_leviathan_mastery") ? 1 + Math.log10(1 + best * best) : 1 + Math.log10(1 + best);
    i *= PT.fishValueMult(s); if (isShiny(key)) i *= 10;
    return Math.max(1, Math.floor(f.sellValue * i));
  };
  PT.reservedFish = function (s, id) { // fish kept back for rods, tackle and fish-priced sunflower nodes
    const f = s.fishing; let n = 0;
    for (const r of RODS) if (!f.ownedRods.includes(r.id)) for (const c of r.cost) if (c.fishId === id) n += c.count;
    for (const t of TACKLE) if ((t.type === "hook" || t.type === "lure") && !(f.unlockedHooks.includes(t.id) || f.unlockedLures.includes(t.id))) for (const c of t.cost) if (c.type === "fish" && c.id === id) n += c.count;
    for (const [sid, d] of PT.SUN) { if (d.costCurrency !== id || (s.sunflowerUpgrades[sid] || 0) >= (d.maxLevel || 1)) continue; if (d.evolutionRequired !== undefined && (s.evolutionCount || 0) < d.evolutionRequired) continue; if (d.requires && !(s.sunflowerUpgrades[d.requires] >= 1)) continue; n += Math.ceil(d.cost || d.baseCost || 0) * Math.max(1, (d.maxLevel || 1) - (s.sunflowerUpgrades[sid] || 0)); }
    return n;
  };
  PT.sellSafe = function (G) {
    const s = G.s; if (!PT.hasSun(s, "d_fish_seeds")) return "needs Fish Seeds";
    let total = 0, n = 0; const keep = [];
    for (const row of s.fishInventory) {
      const id = baseId(row.fishId);
      if (s.lockedFish.includes(id) || isShiny(row.fishId)) { keep.push(row); continue; }
      const safe = Math.min(row.count, Math.max(0, PT.speciesCount(s, id) - PT.reservedFish(s, id)));
      if (safe > 0) { total += PT.sellValue(s, row.fishId) * safe; n += safe; if (row.count - safe > 0) keep.push({ fishId: row.fishId, count: row.count - safe }); } else keep.push(row);
    }
    if (!n) return "nothing safe to sell";
    if (PT.hasSun(s, "d_bulk_bonus")) total = Math.floor(1.2 * total);
    if (PT.hasSun(s, "d_profit_surge") && Math.random() < 0.1) total *= 10;
    s.fishInventory = keep; PT.add(s, "sunflowerSeeds", total); G.gain("sunflowerSeeds", total);
    return `Sold ${n} fish for ${PT.fmt(total)} seeds`;
  };

  // ------------------------------------------------------------------ player fishing loop (Birb startFishing / updateFishing)
  PT.updateFishing = function (G, dt, moving) {
    const s = G.s, F = (G.fish = G.fish || { casting: 0, reeling: 0, total: 0, cooldown: 0, last: null, lastT: 0 });
    F.cooldown = Math.max(0, F.cooldown - dt); F.lastT = Math.max(0, F.lastT - dt);
    if ((F.casting > 0 || F.reeling > 0) && moving) { F.casting = 0; if (F.reeling > 0) { F.reeling = 0; F.cooldown = G.autoFish ? 0 : PT.fishCooldown(s) / 1.5; } G.toast?.("Cast cancelled: stand still"); return; }
    if (F.casting > 0) { F.casting -= dt; if (F.casting <= 0) { F.total = PT.reelDuration(s); F.reeling = F.total; if (PT.hasSun(s, "d_critical_reel") && Math.random() < 0.1) F.reeling = 0.0001; } return; }
    if (F.reeling > 0) { F.reeling -= dt; if (F.reeling <= 0) { const r = PT.catchFish(G, !G.autoFish); F.cooldown = PT.fishCooldown(s); F.last = r; F.lastT = 3; } return; }
    if (G.autoFish && PT.autoFishUnlocked(s) && !moving) PT.startCast(G);
  };
  PT.canFish = (G) => G.s.currentMap === 2 && (G.s.evolutionCount || 0) >= 1 && (!G.fish || (G.fish.casting <= 0 && G.fish.reeling <= 0 && G.fish.cooldown <= 0));
  PT.startCast = function (G) { PT.ensureFishing(G.s); if (!PT.canFish(G)) return false; G.fish = G.fish || {}; G.fish.casting = 0.5; return true; };

  // ------------------------------------------------------------------ Seagull (Birb seagull system, needs Evolution 3)
  const ROUTE = { bridge: { interval: 1 } };
  const DOCTRINE = {
    balanced: { interval: 1, xp: 1, share: 1, weight: 1, reroll: 0, penalty: 0 },
    hunter: { interval: 1.3, xp: 0.94, share: 0.8, weight: 1.18, reroll: 0.72, penalty: 0 },
    training: { interval: 1.02, xp: 1.45, share: 2, weight: 0.92, reroll: 0, penalty: 0.56 },
  };
  const FORECAST = {
    bustling_shoal: { w: 34, fav: "balanced", interval: 0.88, xp: 1, share: 1, weight: 1, reroll: 0, pen: 0 },
    predator_wake: { w: 26, fav: "hunter", interval: 1, xp: 1, share: 1, weight: 1.12, reroll: 0.25, pen: 0 },
    study_current: { w: 26, fav: "training", interval: 1, xp: 1.12, share: 1.2, weight: 1, reroll: 0, pen: 0.2 },
    silver_thermals: { w: 6, fav: "balanced", interval: 0.84, xp: 1.02, share: 1, weight: 1.04, reroll: 0.12, pen: 0.1 },
    blood_tide: { w: 4.5, fav: "hunter", interval: 0.96, xp: 1.02, share: 1, weight: 1.18, reroll: 0.38, pen: 0 },
    archive_bloom: { w: 4.5, fav: "training", interval: 0.98, xp: 1.2, share: 1.45, weight: 1, reroll: 0, pen: 0.38 },
    kings_tide: { w: 1, fav: "*", interval: 0.82, xp: 1.15, share: 1.25, weight: 1.2, reroll: 0.42, pen: 1 },
  };
  PT.SEAGULL_FORECAST = FORECAST; PT.SEAGULL_DOCTRINE = DOCTRINE;
  const mig = (s) => Math.max(0, Math.min(100, Math.floor(s.seagull.migrationCount || 0)));
  PT.gullCount = (s) => (mig(s) >= 30 ? 3 : mig(s) >= 3 ? 2 : 1);
  PT.gullCap = (s) => (s.seagull.hasReborn ? 100 : 50);
  PT.migrateLevel = (s) => (mig(s) >= 50 ? 100 : mig(s) >= 10 ? 50 : 25);
  PT.gullXpNeeded = (L) => Math.floor(100 * Math.pow(1.12, L - 1));
  const migK = (s) => { let t = 0.02; if (mig(s) >= 100) t *= 2; const n = PT.sunLevel(s, "d_migration_amplifier"); if (n > 0) t *= 1 + 0.05 * n; return t; };
  const xpAlpha = (s) => { let t = 1; if (mig(s) >= 100) t *= 2; const n = PT.sunLevel(s, "d_migration_amplifier"); if (n > 0) t *= 1 + 0.05 * n; return t; };
  PT.forecastAt = function (ms) { // Birb gB: hourly seeded forecast (bridge offset 0)
    let a = (2654435769 ^ Math.floor(Math.max(0, ms) / 36e5)) >>> 0;
    a ^= a >>> 16; a = Math.imul(a, 2146121005) >>> 0; a ^= a >>> 15; a = Math.imul(a, 2221713035) >>> 0; a ^= a >>> 16;
    let l = ((a >>> 0) / 4294967296) * Object.values(FORECAST).reduce((x, f) => x + f.w, 0);
    for (const [k, f] of Object.entries(FORECAST)) { l -= f.w; if (l <= 0) return k; }
    return "bustling_shoal";
  };
  const favored = (fid, ms) => (fid === "kings_tide" ? ["balanced", "hunter", "training"][Math.floor(Math.max(0, ms) / 36e5) % 3] : FORECAST[fid].fav);
  function gullMods(s, i, ms) {
    const specialist = i === 2 && mig(s) >= 30, doc = specialist ? "balanced" : s.seagull.gulls[i].doctrine || "balanced";
    const fid = PT.forecastAt(ms);
    if (specialist) return { doc, fid, interval: 1, xp: 1, share: 1, weight: 1, reroll: 0, pen: 0, specialist };
    const d = DOCTRINE[doc], f = FORECAST[fid], on = favored(fid, ms) === doc;
    return { doc, fid, specialist, interval: d.interval * (on ? f.interval : 1), xp: d.xp * (on ? f.xp : 1), share: d.share * (on ? f.share : 1), weight: d.weight * (on ? f.weight : 1), reroll: d.reroll + (on ? f.reroll : 0), pen: Math.max(0, d.penalty - (on ? f.pen : 0)) };
  }
  PT.frenzyOn = (s, now = Date.now()) => (s.seagull.frenzyActiveUntil || 0) > now;
  PT.gullInterval = function (s, i, now = Date.now()) {
    const m = gullMods(s, i, s.seagull.forecastTimelineMs);
    let u = 10 * Math.pow(0.99, s.seagull.level) * (1 / (1 + mig(s) * migK(s)));
    u *= ROUTE.bridge.interval * m.interval;
    if (m.specialist) u *= 2.5;
    if (PT.frenzyOn(s, now)) u /= 2;
    return Math.max(0.25, u);
  };
  const rankOf = (r) => ({ common: 1, uncommon: 2, rare: 3, epic: 4, legendary: 5, mythic: 6 }[r] ?? 0);
  const better = (a, b) => (rankOf(b.rarity) > rankOf(a.rarity) ? b : rankOf(b.rarity) < rankOf(a.rarity) ? a : (b.weight ?? 1) > (a.weight ?? 1) ? b : a);
  function gullXp(G, rarity, xpMult, shareMult) { // Birb IB
    const s = G.s, sg = s.seagull;
    let a = { common: 10, uncommon: 25, rare: 50, epic: 100, legendary: 250 }[rarity] || 10;
    a = Math.floor(a * (1 + mig(s) * xpAlpha(s)));
    if (PT.hasSun(s, "d_seagull_xp")) a = Math.floor(1.5 * a);
    if (PT.hasSun(s, "d_seagull_synergy")) a = Math.floor(a * Math.max(0, PT.activeFishMult(s, "xp_mult") || 1));
    const ft = PT.sunLevel(s, "d_fleet_training"); if (ft > 0) a = Math.floor(a * (1 + 0.06 * ft));
    a = Math.max(1, Math.floor(a * xpMult));
    if (sg.migrationCount >= 5) { const t = Math.floor(a * (PT.hasSun(s, "d_ancestral_radio") ? 0.1 : 0.05) * shareMult); if (t > 0 && s.sparrow.unlocked) s.sparrow.xp += t; }
    const cap = PT.gullCap(s); if (sg.level >= cap) return a;
    sg.xp += a;
    while (sg.level < cap && sg.xp >= PT.gullXpNeeded(sg.level)) { sg.xp -= PT.gullXpNeeded(sg.level); sg.level++; if (sg.level >= cap) { sg.xp = 0; break; } }
    return a;
  }
  function gullCatch(G, i) { // Birb PB (bridge route)
    const s = G.s, sg = s.seagull, g = sg.gulls[i], f = s.fishing, m = gullMods(s, i, sg.forecastTimelineMs);
    const rod = RODS.find((r) => r.id === g.equippedRodId && f.ownedRods.includes(r.id)) || rodById(f.equippedRodId);
    const roll = (consume, minR) => PT.rollFish(s, rod, undefined, f.equippedLureId, f.equippedHookId, consume, minR);
    const minR = m.specialist ? "rare" : undefined;
    let M = roll(true, minR); if (!M) return;
    if (PT.hasSun(s, "d_gull_sonar")) { const t = roll(false, minR); if (t) M = better(M, t); }
    const k = Math.min(0.95, mig(s) * migK(s));
    if (k > 0 && rankOf(M.rarity) < 3 && Math.random() < k) { const t = roll(false, minR); if (t) M = better(M, t); }
    if (PT.hasSun(s, "d_rare_routes") && rankOf(M.rarity) < 3 && Math.random() < 0.15) { const t = roll(false, minR); if (t) M = better(M, t); }
    const rr = Math.min(0.95, m.reroll);
    if (rr > 0 && rankOf(M.rarity) < 3 && Math.random() < rr) { const t = roll(false, minR); if (t) M = better(M, t); }
    if (m.pen > 0 && rankOf(M.rarity) >= 3 && Math.random() < m.pen) { const t = roll(false); if (t) M = better(M, t) === M ? t : M; }
    const now = Date.now();
    const shiny = Math.random() < shinySoftcap(1e-5, fleetShiny(s), moonlit(sg.migrationCount, g.lastShinyFishCaughtAt, now));
    if (shiny) g.lastShinyFishCaughtAt = now;
    let w = PT.fishWeight(s, M, shiny, rod.tier); if (PT.hasSun(s, "d_lunar_compass")) w *= 1.35; w = Math.round(100 * w * m.weight) / 100;
    addFish(s, M.id, shiny, "seagull"); recordWeight(s, M.id, w);
    s.totalFishCaught = (s.totalFishCaught || 0) + 1;
    gullXp(G, M.rarity, m.xp, m.share);
    let echo = 0; if (sg.migrationCount >= 15) echo += 0.08; if (PT.hasSun(s, "d_echo_vectors")) echo += 0.1; echo += Math.min(0.05, 0.01 * PT.sunLevel(s, "d_patrol_network"));
    let caught = 1;
    if (echo > 0 && Math.random() < Math.min(0.95, echo)) { addFish(s, M.id, shiny, "seagull"); s.totalFishCaught++; gullXp(G, M.rarity, m.xp, m.share); caught = 2; }
    // seagull Moneta keeps the fractional remainder (Birb seagullMonetaRemainder)
    const raw = monetaPerCatch(s, richestRod(f.ownedRods), caught, "seagull"), acc = Math.min(0.999999, f.seagullMonetaRemainder || 0) + raw, whole = Math.floor(acc + 1e-9);
    f.seagullMonetaRemainder = Math.max(0, acc - whole); grantMoneta(G, whole);
    g.lastCatchSummary = { id: M.id, rarity: M.rarity, shiny, weight: w, at: now };
    if (m.specialist) { g.doctrine = "balanced"; g.pendingDoctrine = null; } else if (g.pendingDoctrine && g.pendingDoctrine !== g.doctrine) { g.doctrine = g.pendingDoctrine; g.pendingDoctrine = null; }
  }
  PT.updateSeagull = function (G, dt) {
    const s = G.s; PT.ensureFishing(s); const sg = s.seagull;
    sg.forecastTimelineMs = (sg.forecastTimelineMs || Date.now()) + 1000 * dt;
    if (!s.hasMetSeagull || !sg.discovered || (s.evolutionCount || 0) < 3 || dt <= 0) return;
    while (sg.gulls.length < PT.gullCount(s)) sg.gulls.push({ routeId: "bridge", doctrine: "balanced", equippedRodId: "rod_simple", pendingDoctrine: null, progressSeconds: 0 });
    for (let i = 0; i < sg.gulls.length; i++) {
      const g = sg.gulls[i]; let left = dt, n = 0;
      while (left > 1e-7 && n < 32) {
        const iv = PT.gullInterval(s, i), p = g.progressSeconds || 0;
        if (p + 1e-7 >= iv) { g.progressSeconds = Math.max(0, p - iv); gullCatch(G, i); n++; continue; }
        const r = iv - p; if (r > left) { g.progressSeconds = p + left; left = 0; break; }
        left -= r; g.progressSeconds = 0; gullCatch(G, i); n++;
      }
    }
    if (sg.migrationCount >= 50 && sg.autoRebirbEnabled && sg.migrationCount < 100 && sg.level >= PT.migrateLevel(s)) PT.migrate(s);
    const now = Date.now();
    if (!PT.frenzyOn(s, now) && (sg.frenzyCooldownUntil || 0) < now) { sg.frenzyActiveUntil = 0; sg.frenzyCooldownUntil = 0; }
  };
  // Birb LB: keeps the levels above the requirement; the 10th migration needs Evolution 4 and makes the gull Reborn (cap 100)
  PT.migrate = function (s) {
    const sg = s.seagull; if (mig(s) >= 100) return "max";
    const n = PT.migrateLevel(s); if (sg.level < n) return "needs LV " + n;
    if (mig(s) === 9 && !sg.hasReborn) { if ((s.evolutionCount || 0) < 4) return "needs Evolution 4"; sg.hasReborn = true; }
    const i = Math.max(1, sg.level), r = Math.max(0, Math.min(1, sg.xp / PT.gullXpNeeded(i))), lv = Math.max(1, i - n);
    sg.level = lv; sg.xp = Math.max(0, Math.min(PT.gullXpNeeded(lv) - 1e-6, r * PT.gullXpNeeded(lv)));
    sg.migrationCount++; sg.gulls.forEach((g) => { g.progressSeconds = 0; g.pendingDoctrine = null; });
    return "";
  };
  PT.frenzy = function (s) {
    const sg = s.seagull, now = Date.now();
    if (sg.migrationCount < 1) return "needs 1 migration";
    if (PT.frenzyOn(s, now) || (sg.frenzyCooldownUntil || 0) > now) return "cooling down";
    const until = now + 1000 * (PT.hasSun(s, "d_frenzy_reactor") ? 45 : 30);
    sg.frenzyActiveUntil = until; sg.frenzyCooldownUntil = until + 1000 * (PT.hasSun(s, "d_cold_start") ? 2340 : 3600);
    return "";
  };
})();
