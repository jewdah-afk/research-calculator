// Peckwood playtest, Phase 3: the Nest (map 4, left of the Park, Evolution 3), copied from Birb's nestManager (bT),
// the cultivation shop, fish breeding ("Lineage Lake"), the Red Panda and offline twigs.
// Riverside and the sawmill (carpentry, Nest IV + Evolution 6) live in riverside.js and hook in through PT.riv*.
"use strict";
(function () {
  const PT = window.PT;
  const { D } = PT;
  const r12 = (x) => Number(Number(x).toPrecision(12));

  // ------------------------------------------------------------------ constants (Birb main Zt/Dt/jt, editors Dh)
  PT.NEST_TIERS = [{ name: "Basic Nest", mult: 1 }, { name: "Sturdy Nest", mult: 2 }, { name: "Cozy Nest", mult: 5 }, { name: "Grand Nest", mult: 10 }];
  PT.NEST_TIER_COST = [1e5, 1e6, 1e8, 2e10];
  PT.NEST_MAP = 4; PT.NEST_ROOM_MAP = 14;
  const F = { baseDps: 2.5, treeHp: 12, spawnSec: 30, capacity: 30, growSec: 180, chopRadius: 58, dmgGrowth: 1.2, maxOffline: 28800 };
  PT.nestMaxTier = (s) => { const e = s.evolutionCount || 0; return e < 3 ? 1 : e < 6 ? 2 : 3; }; // Birb Cp

  // ------------------------------------------------------------------ state (Birb xp defaults + normalizeState, the parts the playtest uses)
  PT.nestState = function (s) {
    const n = s.nest || (s.nest = {});
    n.unlocked ??= false; n.tier = Math.max(0, Math.min(PT.nestMaxTier(s), Math.floor(n.tier || 0)));
    n.upgrades ||= {}; n.autoPopcornEnabled ??= false; n.autoGoldenPopcornEnabled ??= false; n.autoSeedsEnabled ??= false;
    const f = n.forest || (n.forest = {});
    f.trees ||= []; f.populationSeedVersion ??= 0; f.spawnAccumulator ??= 0; f.totalTwigsFromTrees ??= 0; f.tierTwigsProgress ??= 0;
    f.nextTreeId ??= 1; f.activeTreeId ??= null; f.hasSeenIntro ??= false; f.firstTreeChopped ??= false; f.autoCollectUnlocked ??= false; f.autoCollectEnabled ??= false;
    if (f.totalTwigsFromTrees > 0) f.firstTreeChopped = f.autoCollectUnlocked = true;
    const c = n.cultivation || (n.cultivation = {});
    c.treeBoxCount ??= 0; c.treeBoxes ||= []; c.treeBoxEvolution ??= false; c.treeBoxQuadEvolution ??= false;
    if (c.treeBoxQuadEvolution) c.treeBoxEvolution = true; // Birb zk: quad evolution implies double boxes; boxes from slot 16 are quad
    for (const b of c.treeBoxes) { if (c.treeBoxQuadEvolution || b.slotIndex >= 16) b.specialized = true; if (b.slotIndex >= 16 && !(b.extraTrees?.length >= 2)) b.extraTrees = [{}, {}]; }
    c.specialUpgrades = Object.assign({ fertilizer: false, specializedFertilizer: false, grainSilo: false, cornfield: false, sunflowerField: false, wateringWell: false }, c.specialUpgrades || {});
    for (const k of ["twigs", "wood"]) if (n.resources && n.resources[k] !== undefined) { s.resources[k] = D(n.resources[k]); delete n.resources[k]; } // Birb keeps twigs and wood in nest.resources
    const b = n.fishBreeding || (n.fishBreeding = {});
    b.unlocked ??= false; b.reserveSlotUnlocked ??= false; b.incubation ??= null; b.hybrids ||= []; b.activeHybridId ??= null; b.nextHybridId ??= 1; b.shinyProgressByLineage ||= {};
    n.unlocked = true; // Birb quirk: normalizeState infers 'unlocked' even on a fresh save (the map arrow still waits for Evolution 3)
    return n;
  };
  const twigs = (s) => PT.res(s, "twigs");
  const lvl = (s, id) => Math.max(0, Math.floor(PT.nestState(s).upgrades[id] || 0));
  const cult = (s) => PT.nestState(s).cultivation;
  const special = (s, k) => cult(s).specialUpgrades[k] === true;

  // ------------------------------------------------------------------ twig value, chopping, estimates (Birb §3)
  const mineMult = (s) => (PT.hasSun(s, "d_mine_nest_blades") ? 1.25 : 1); // Birb getMineTreeChopMultiplier
  PT.nestWellMult = (s) => (special(s, "wateringWell") ? 2 : 1);
  // Birb x community goal "twigGain": a live, server-wide event reward (x1.5 while the goal is met). Set it in Settings to match Birb today.
  PT.COMMUNITY = { twigGain: 1 };
  PT.nestResourceMult = (s) => PT.NEST_TIERS[PT.nestState(s).tier].mult * (1 + (PT.questBonus ? PT.questBonus(s, "twig_gain_mult") : 0)) * PT.COMMUNITY.twigGain * PT.nestWellMult(s); // x quest x carpentry forestry (later phases)
  PT.nestTwigMult = (s) => PT.nestResourceMult(s) * (PT.hasSun(s, "d_archivist_echo_ancient_roots") ? 1.15 : 1);
  const twigK = (tv, pp, mult) => { const base = Number((1 + 0.2 * tv).toFixed(1)); const v = Math.max(0.1, r12(base * mult)) * (1 + pp); return Math.max(0.1, r12(v)); }; // Birb _k
  PT.nestRewardPerHit = (s) => twigK(lvl(s, "n_twig_value"), 0, PT.nestTwigMult(s));
  PT.nestTwigPerPeck = (s, tv = lvl(s, "n_twig_value")) => twigK(tv, lvl(s, "n_peck_power"), PT.nestTwigMult(s));
  PT.nestCompanionDps = (s) => F.baseDps * Math.pow(F.dmgGrowth, PT.nestState(s).tier) * mineMult(s); // getForestChopDamagePerSecond
  const rk = (L) => Number((0.2 * L).toFixed(1));
  PT.nestHitRate = (s, pr = lvl(s, "n_peck_rate")) => PT.nestCompanionDps(s) + rk(pr) * mineMult(s);
  PT.nestPeckDamage = (s, pp = lvl(s, "n_peck_power")) => 1 + pp;
  PT.nestChopRadius = (s) => { const r = Math.max(40, PT.pickupProfile(s).collectRadius || 40); return F.chopRadius * (1 + 0.5 * Math.max(0, r / 40 - 1)); };
  const growSec = (s) => (special(s, "fertilizer") ? 40 : 60);
  const boxTreeHp = (s) => (special(s, "specializedFertilizer") ? 24 : 12);
  const isQuad = (b) => Array.isArray(b.extraTrees) && b.extraTrees.length >= 2;
  const treesIn = (b) => (isQuad(b) ? 4 : b.specialized ? 2 : 1);
  PT.nestTwigsPerSec = function (s, mode = "birb") { // Birb getEstimatedTwigGenPerSecond
    if (!PT.nestState(s).unlocked) return 0;
    let supply = (1 / F.spawnSec) * F.treeHp;
    for (const b of cult(s).treeBoxes) supply += (boxTreeHp(s) * treesIn(b)) / Math.max(0.001, growSec(s) + 3);
    const demand = mode === "birb" ? PT.nestHitRate(s) * PT.nestPeckDamage(s) : PT.nestCompanionDps(s);
    return Math.max(0, Math.min(demand, supply) * PT.nestRewardPerHit(s));
  };

  // ------------------------------------------------------------------ build bar (Birb getNestBuildProgress / addNestBuildProgress / tiers on evolution)
  PT.nestBuild = function (s) {
    const n = PT.nestState(s), cost = PT.NEST_TIER_COST[n.tier] || 0, cur = Math.min(cost, n.forest.tierTwigsProgress), p = cost > 0 ? Math.max(0, Math.min(1, cur / cost)) : 1;
    return { tier: n.tier, nextTier: n.tier >= 3 ? n.tier : n.tier + 1, current: cur, required: cost, progress: p, isComplete: p >= 1, isMaxed: n.tier >= 3 && p >= 1 };
  };
  PT.nestAddTwigs = function (s, t, build = true) {
    if (!(t > 0)) return;
    PT.add(s, "twigs", t);
    if (!build) return;
    const f = PT.nestState(s).forest, b = PT.nestBuild(s);
    f.totalTwigsFromTrees += t;
    if (!b.isComplete && !b.isMaxed) f.tierTwigsProgress = Math.min(b.required, b.current + t);
  };
  PT.nestCanMigrate = (s) => PT.nestState(s).tier >= 1; // Sparrow rebirb gate
  PT.nestOnEvolve = function (G) { // Birb advanceNestTierForEvolution + the nest part of onEvolutionReset (call after evolutionCount++)
    const s = G.s, n = PT.nestState(s), e = Math.floor(s.evolutionCount || 0);
    if (e >= 3) { if (!n.unlocked) n.unlocked = true; else if (e > 3 && n.tier < PT.nestMaxTier(s)) n.tier++; }
    const keepF = n.forest;
    n.upgrades = {}; n.autoPopcornEnabled = false; n.autoGoldenPopcornEnabled = false; n.autoSeedsEnabled = false;
    n.forest = { trees: [], populationSeedVersion: 0, spawnAccumulator: 0, totalTwigsFromTrees: 0, tierTwigsProgress: 0, nextTreeId: 1, activeTreeId: null,
      hasSeenIntro: keepF.hasSeenIntro, firstTreeChopped: keepF.firstTreeChopped || n.tier > 0, autoCollectUnlocked: keepF.autoCollectUnlocked || n.tier > 0, autoCollectEnabled: keepF.autoCollectEnabled };
    n.cultivation = { treeBoxCount: 0, treeBoxes: [], treeBoxEvolution: false, treeBoxQuadEvolution: false, specialUpgrades: {} };
    PT.nestState(s);
    s.lastActiveAt = Date.now(); // resetOfflineProgressForEvolution
  };

  // ------------------------------------------------------------------ multipliers for other systems (Birb §6)
  PT.nestGrainSilo = (s) => (special(s, "grainSilo") ? 1 + 3.7 * Math.log10(Math.max(0, PT.num(twigs(s))) / 5e4 + 1) : 1);
  PT.nestRespawnMult = (s) => (special(s, "cornfield") ? 2 : 1); // riverside.js adds the Pollinator Garden x1.25
  PT.nestSeedProdMult = (s) => (special(s, "sunflowerField") ? 2 : 1) * PT.nestWellMult(s);
  PT.redPandaNapMult = (s) => (s.redPanda?.introSeen && s.redPanda.mode === "chill" ? 1.25 : 1);
  PT.redPandaTier = (s) => Math.max(1, Math.min(4, PT.nestState(s).tier + 1));

  // ------------------------------------------------------------------ twig shop: Twig Value, Pecking Rhythm, Pecking Power (Birb §5)
  PT.NEST_UPS = {
    n_twig_value: { name: "Twig Value", text: "+0.2 Twig per hit each level.", max: 999, cost: (L) => Math.max(1, Math.ceil(15 * Math.pow(1.06496, L))) },
    n_peck_rate: { name: "Pecking Rhythm", text: "+0.2 Birb hit/s each level.", max: 20, cost: (L) => Math.max(1, Math.ceil(150 * Math.pow(1.18, L))) },
    n_peck_power: { name: "Pecking Power", text: "+1 damage per peck each level.", max: 15, cost: (L) => Math.max(1, Math.ceil(5000 * Math.pow(2.3, L))) },
  };
  PT.nestUpVisible = (s, id) => (id === "n_peck_rate" ? special(s, "fertilizer") : id === "n_peck_power" ? lvl(s, "n_peck_rate") >= 10 : true);
  PT.nestUpLevel = lvl;
  PT.nestMaxPreview = function (s, id) { // Birb getUpgradeMaxPreview (prefix sums + binary search)
    const u = PT.NEST_UPS[id], L = lvl(s, id), have = twigs(s); let total = D(0), t = L;
    while (t < u.max) { const nx = total.add(u.cost(t)); if (nx.gt(have)) break; total = nx; t++; }
    return { totalCost: total, targetLevel: t, levelsGained: t - L };
  };
  PT.nestBuyUp = function (s, id, max) {
    const u = PT.NEST_UPS[id], n = PT.nestState(s), L = lvl(s, id);
    if (!PT.nestUpVisible(s, id) || L >= u.max) return "Maxed or locked";
    if (max) { const p = PT.nestMaxPreview(s, id); if (p.levelsGained <= 0) return "Not enough twigs"; PT.sub(s, "twigs", p.totalCost); n.upgrades[id] = p.targetLevel; return ""; }
    const c = u.cost(L); if (twigs(s).lt(c)) return "Not enough twigs";
    PT.sub(s, "twigs", c); n.upgrades[id] = L + 1; return "";
  };

  // ------------------------------------------------------------------ cultivation shop (Birb Yk snapshot, purchaseTreeBox phases, specials)
  const pow12 = (n) => Math.pow(1.2, n);
  const costBase = (n) => Math.ceil(100 * pow12(Math.min(15, n)));
  const costDouble = (n) => Math.ceil(2 * costBase(15) * pow12(Math.min(15, n)));
  const costQuad = (n) => Math.ceil(2 * costDouble(15) * pow12(Math.min(15, n)));
  const costExp = (n) => Math.ceil(Math.ceil(costQuad(15) * 1.2) * pow12(Math.min(7, n)));
  PT.NEST_SPECIALS = [
    { id: "fertilizer", name: "Fertilizer", text: "Trees in planting beds grow 50% faster (60s → 40s). Unlocks Pecking Rhythm.", cost: 500, visible: (s, c) => c.treeBoxCount >= 5 },
    { id: "specializedFertilizer", name: "Specialized Fertilizer", text: "Doubles planting-bed tree durability (12 → 24 hits).", cost: 25000, visible: (s, c) => c.treeBoxCount >= 16 },
    { id: "grainSilo", name: "Grain Silo", text: "Your current Twig balance multiplies Egg and Seed gains.", cost: 50000, visible: () => true },
    { id: "cornfield", name: "Cornfield", text: "Doubles Egg respawn speed.", cost: 35000, visible: () => true },
    { id: "sunflowerField", name: "Sunflower Field", text: "Doubles Seed production speed.", cost: 150000, visible: (s, c) => c.specialUpgrades.sunflowerField || (c.specialUpgrades.cornfield && PT.nestState(s).tier + 1 >= 2) },
    { id: "wateringWell", name: "Watering Well", text: "Doubles Egg, Twig and Seed gains.", cost: 500000, visible: (s, c) => c.specialUpgrades.wateringWell || (s.evolutionCount || 0) >= 5 },
  ];
  PT.nestCultSnapshot = function (s) {
    const c = cult(s), base = c.treeBoxes.filter((b) => b.slotIndex < 16), r = base.filter((b) => b.specialized).length, sq = base.filter(isQuad).length;
    const o = c.treeBoxes.filter((b) => b.slotIndex >= 16 && b.slotIndex < 24).length, d = Math.max(1, PT.nestState(s).tier + 1);
    const evoAvail = c.treeBoxCount >= 16 && !c.treeBoxEvolution, quadAvail = c.treeBoxEvolution && r >= 16 && !c.treeBoxQuadEvolution;
    const cost = evoAvail ? 1e9 : quadAvail ? 1e12 : c.treeBoxQuadEvolution ? costQuad(sq) : c.treeBoxEvolution ? costDouble(r) : costBase(c.treeBoxCount);
    return {
      treeBoxCount: c.treeBoxCount, specializedCount: r, quadCount: sq, expansionCount: o,
      phase: evoAvail ? "EVOLVE TREE BOX" : quadAvail ? "EVOLVE TO QUAD TREE BOX" : c.treeBoxQuadEvolution ? "QUAD TREE BOX" : c.treeBoxEvolution ? "SPECIALIZED TREE BOX" : "TREE BOX",
      phaseLevel: evoAvail || quadAvail ? null : c.treeBoxQuadEvolution ? sq : c.treeBoxEvolution ? r : c.treeBoxCount,
      treeBoxCost: cost, treeBoxCostCurrency: evoAvail || quadAvail ? "goldenFeathers" : "twigs", treeBoxMaxed: c.treeBoxQuadEvolution && sq >= 16,
      quadRequirementMet: d >= 2, expansionVisible: sq >= 16 || o > 0, expansionCost: costExp(o), expansionMaxed: o >= 8,
      growthSeconds: growSec(s), treeHp: boxTreeHp(s),
    };
  };
  const freshBoxTree = (s) => ({ hp: boxTreeHp(s), maxHp: boxTreeHp(s), age: 0, respawn: 0, collapse: 0 });
  function boxTrees(s, b) { // the playtest keeps one tree object per tree in the box (Birb: primary + secondaryTree + extraTrees)
    const want = treesIn(b);
    b.trees ||= [];
    while (b.trees.length < want) b.trees.push(freshBoxTree(s));
    if (b.trees.length > want) b.trees.length = want;
    return b.trees;
  }
  PT.nestBuyTreeBox = function (s) {
    const c = cult(s), sn = PT.nestCultSnapshot(s);
    if (sn.treeBoxMaxed) return "Maxed";
    if (sn.phase === "EVOLVE TO QUAD TREE BOX" && !sn.quadRequirementMet) return "Requires Nest tier 2";
    if (!PT.has(s, sn.treeBoxCostCurrency, sn.treeBoxCost)) return "Not enough " + (sn.treeBoxCostCurrency === "twigs" ? "twigs" : "plumes");
    PT.sub(s, sn.treeBoxCostCurrency, sn.treeBoxCost);
    if (sn.phase === "TREE BOX") { c.treeBoxes.push({ slotIndex: c.treeBoxCount, specialized: false }); c.treeBoxCount++; }
    else if (sn.phase === "EVOLVE TREE BOX") c.treeBoxEvolution = true;
    else if (sn.phase === "SPECIALIZED TREE BOX") { const b = c.treeBoxes.find((x) => x.slotIndex < 16 && !x.specialized); b.specialized = true; }
    else if (sn.phase === "EVOLVE TO QUAD TREE BOX") c.treeBoxQuadEvolution = true;
    else { const b = c.treeBoxes.find((x) => x.slotIndex < 16 && !isQuad(x)); b.specialized = true; b.extraTrees = [{}, {}]; }
    for (const b of c.treeBoxes) boxTrees(s, b);
    return "";
  };
  PT.nestBuyExpansion = function (s) {
    const c = cult(s), sn = PT.nestCultSnapshot(s);
    if (!sn.expansionVisible || sn.expansionMaxed) return "Locked";
    if (twigs(s).lt(sn.expansionCost)) return "Not enough twigs";
    PT.sub(s, "twigs", sn.expansionCost);
    const slot = 16 + sn.expansionCount; c.treeBoxes.push({ slotIndex: slot, specialized: true, extraTrees: [{}, {}] }); c.treeBoxCount = Math.max(c.treeBoxCount, slot + 1);
    return "";
  };
  PT.nestBuySpecial = function (s, id) {
    const c = cult(s), it = PT.NEST_SPECIALS.find((x) => x.id === id);
    if (!it || c.specialUpgrades[id]) return "Owned";
    if (!it.visible(s, c)) return "Locked";
    if (id === "sunflowerField" && !c.specialUpgrades.cornfield) return "Needs the Cornfield";
    if (twigs(s).lt(it.cost)) return "Not enough twigs";
    PT.sub(s, "twigs", it.cost); c.specialUpgrades[id] = true;
    if (id === "specializedFertilizer") for (const b of c.treeBoxes) for (const t of boxTrees(s, b)) { t.hp = t.hp > 0 ? Math.max(1, Math.round((t.hp / 12) * 24)) : t.hp; t.maxHp = 24; }
    return "";
  };

  // ------------------------------------------------------------------ forest simulation (Birb updateForest, wild trees + planting beds)
  PT.boxSlotPos = (i) => (i < 16 ? { x: 380 + (i % 8) * 120, y: 1180 + Math.floor(i / 8) * 130 } : i < 24 ? { x: 380 + (i - 16) * 120, y: 1440 } : { x: 560 + (i - 24) * 160, y: 1580 });
  function spawnTree(s, mature) {
    const f = PT.nestState(s).forest, W = 1600, H = 2112, minX = 84, maxX = W - 84, minY = 230, maxY = Math.min(H - 44, 992);
    for (let a = 0; a < (mature ? 180 : 80); a++) {
      const x = minX + Math.random() * (maxX - minX), y = minY + Math.random() * (maxY - minY), sp = mature ? 42 + 24 * Math.random() : 42 + 44 * Math.random();
      if (Math.abs(x - 800) < 170 && y < 330) continue; // the ancient tree
      if (PT.spawnOk && !PT.spawnOk(PT.NEST_MAP, x, y)) continue; // game3d: only on open ground
      if (f.trees.some((t) => Math.hypot(t.x - x, t.y - y) < sp)) continue;
      f.trees.push({ id: "nest_tree_" + f.nextTreeId++, x, y, age: mature ? F.growSec : 0, hp: F.treeHp, maxHp: F.treeHp, collapse: 0 });
      return true;
    }
    return false;
  }
  function allTargets(s) { // mature, alive trees: wild + planting beds
    const out = [], f = PT.nestState(s).forest;
    for (const t of f.trees) if (t.hp > 0 && t.age >= F.growSec) out.push({ t, x: t.x, y: t.y, key: t.id });
    for (const b of cult(s).treeBoxes) { const p = PT.boxSlotPos(b.slotIndex); boxTrees(s, b).forEach((t, i) => { if (t.hp > 0 && t.age >= growSec(s)) out.push({ t, x: p.x + (i % 2) * 40 - (treesIn(b) > 1 ? 20 : 0), y: p.y + Math.floor(i / 2) * 36 - (treesIn(b) > 2 ? 18 : 0), key: "box" + b.slotIndex + "_" + i, box: true, slot: b.slotIndex, idx: i }); }); }
    return out;
  }
  PT.nestTargets = allTargets;
  function hitTree(G, tgt, dmgUnits, who, hits = 1) {
    const s = G.s, t = tgt.t, hp0 = Math.floor(t.hp), rem = Math.min(hp0, Math.max(1, Math.floor(dmgUnits)));
    t.harvestBaseHp ??= t.maxHp;
    const refund = who === "player" && PT.rivLumberRefund ? PT.rivLumberRefund(s, hp0, t.maxHp, dmgUnits, hits) : 0; // Lumberyard
    t.hp -= rem;
    const tw = r12(PT.nestRewardPerHit(s) * rem);
    PT.nestAddTwigs(s, tw); G.gain("twigs", tw);
    if (who === "player") G.onFloat(tgt.x, tgt.y - 30, "+" + PT.fmt(tw), "#d8a24a");
    if (refund > 0) { const rt = r12(PT.nestRewardPerHit(s) * refund); PT.nestAddTwigs(s, rt); G.gain("twigs", rt); }
    if (t.hp <= 0) {
      if (PT.rivOnTreeFelled) PT.rivOnTreeFelled(G, tgt);
      t.collapse = 0.8; if (tgt.box) t.respawn = 3;
      const f = PT.nestState(s).forest;
      if (!f.firstTreeChopped) { f.firstTreeChopped = f.autoCollectUnlocked = true; G.toast && G.toast("Auto collect unlocked"); }
      (G.nestChains ||= []).push({ x: tgt.x, y: tgt.y, key: tgt.key, timer: 0.42, depth: 1 });
    }
  }
  PT.updateNest = function (G, dt) {
    const s = G.s, n = PT.nestState(s), f = n.forest;
    if (!n.unlocked) return;
    // planting beds regrow everywhere (advanceCultivationTime)
    PT.nestAdvanceBeds(s, dt);
    for (const t of f.trees) { if (t.hp <= 0) t.collapse -= dt; else t.age += dt; }
    f.trees = f.trees.filter((t) => t.hp > 0 || t.collapse > 0);
    const here = s.currentMap === PT.NEST_MAP, panda = PT.pandaAssisting(s);
    if (here || panda) {
      if (f.populationSeedVersion < 1) { while (f.trees.length < F.capacity && spawnTree(s, true)); f.populationSeedVersion = 1; f.spawnAccumulator = 0; }
      if (f.trees.length < F.capacity) { f.spawnAccumulator += dt / F.spawnSec; while (f.spawnAccumulator >= 1 && f.trees.length < F.capacity) { f.spawnAccumulator -= 1; if (!spawnTree(s, false)) { f.spawnAccumulator = 0; break; } } }
      else f.spawnAccumulator = 0;
    }
    // chain falls (Birb: 0.42 s later the next tree in line takes 2 damage, up to 3 deep; the playtest uses the nearest tree)
    if (G.nestChains?.length) {
      for (const c of G.nestChains) c.timer -= dt;
      for (const c of G.nestChains.filter((c) => c.timer <= 0)) {
        const near = allTargets(s).filter((x) => x.key !== c.key).map((x) => ({ x, d: Math.hypot(x.x - c.x, x.y - c.y) })).filter((o) => o.d >= 16 && o.d <= 112).sort((a, b) => a.d - b.d)[0];
        if (near) { const was = near.x.t.hp; hitTree(G, near.x, 2, "chain"); if (near.x.t.hp <= 0 && was > 0 && c.depth < 3) G.nestChains[G.nestChains.length - 1].depth = c.depth + 1; }
      }
      G.nestChains = G.nestChains.filter((c) => c.timer > 0);
    }
    if (here) {
      const p = s.player, targets = allTargets(s);
      let tgt = null;
      if (f.autoCollectEnabled && f.autoCollectUnlocked) {
        tgt = targets.find((x) => x.key === f.activeTreeId) || targets.sort((a, b) => Math.hypot(a.x - p.x, a.y - p.y) - Math.hypot(b.x - p.x, b.y - p.y))[0] || null;
        if (tgt && !G.keys.size) G.target = { x: tgt.x, y: tgt.y + 20 };
      }
      const R = PT.nestChopRadius(s);
      if (!tgt || Math.hypot(tgt.x - p.x, tgt.y + 20 - p.y) > R) tgt = targets.filter((x) => Math.hypot(x.x - p.x, x.y - p.y) <= R).sort((a, b) => Math.hypot(a.x - p.x, a.y - p.y) - Math.hypot(b.x - p.x, b.y - p.y))[0] || null;
      f.activeTreeId = tgt ? tgt.key : f.autoCollectEnabled ? f.activeTreeId : null;
      if (tgt && Math.hypot(tgt.x - p.x, tgt.y - p.y) <= R + 30) {
        G.nestAcc = (G.nestAcc || 0) + PT.nestHitRate(s) * dt;
        const h = Math.floor(G.nestAcc); if (h > 0) { G.nestAcc -= h; hitTree(G, tgt, PT.nestPeckDamage(s) * h, "player", h); }
      } else G.nestAcc = 0;
      if (panda) { // the Red Panda chops another tree at the companion rate, 1 damage per hit
        const pt = targets.filter((x) => x.t.hp > 0 && x.key !== (tgt && tgt.key))[0];
        if (pt) { G.pandaAcc = (G.pandaAcc || 0) + PT.nestCompanionDps(s) * dt; const h = Math.floor(G.pandaAcc); if (h > 0) { G.pandaAcc -= h; hitTree(G, pt, h, "panda"); } G.pandaPos = { x: pt.x + 18, y: pt.y + 10 }; }
      }
    } else if (panda) { // Birb applyBackgroundCompanionWork(dt, 0.55)
      const per = PT.nestRewardPerHit(s), hps = per > 0 ? PT.nestTwigsPerSec(s, "companion") / per : 0;
      G.pandaAcc = (G.pandaAcc || 0) + hps * 0.55 * dt; const h = Math.floor(G.pandaAcc);
      if (h > 0) { G.pandaAcc -= h; const tw = r12(per * h); PT.nestAddTwigs(s, tw); G.gain("twigs", tw); }
    }
    PT.nestAutomation(G, dt);
  };
  PT.nestAdvanceBeds = function (s, dt) {
    for (const b of cult(s).treeBoxes) for (const t of boxTrees(s, b)) {
      let r = Math.min(dt, F.maxOffline);
      if (t.hp <= 0) { t.collapse -= r; if (r < t.respawn) { t.respawn -= r; continue; } r -= t.respawn; t.respawn = 0; t.hp = t.maxHp = boxTreeHp(s); t.age = 0; t.carpentryHarvested = false; delete t.harvestBaseHp; }
      t.age += r;
    }
  };

  // ------------------------------------------------------------------ automation from nest tier 2 (Birb updateUpgradeAutomation: 1 buy per second per channel)
  PT.nestAutomationUnlocked = (s) => PT.nestState(s).tier >= 2;
  PT.goldenAutomationUnlocked = (s) => PT.nestState(s).tier >= 3 && PT.nestMaxTier(s) >= 3;
  PT.nestAutomation = function (G, dt) {
    const s = G.s, n = PT.nestState(s);
    if (!PT.nestAutomationUnlocked(s)) return;
    // Birb isGoldenPopcornAutomationUnlocked: nest tier 3 and Evolution 6 (max nest tier 3)
    for (const [flag, tree, cur] of [["autoPopcornEnabled", "P", "popcorn"], ["autoGoldenPopcornEnabled", "P", "goldenPopcorn"], ["autoSeedsEnabled", "S", ""]]) {
      if (!n[flag] || (cur === "goldenPopcorn" && !PT.goldenAutomationUnlocked(s))) continue;
      const tk = "auto" + flag; G[tk] = (G[tk] || 0) + dt; if (G[tk] < 1) continue; G[tk] = Math.min(1, G[tk] - 1);
      for (const d of PT.UP.values()) {
        if (d.tree !== tree || (tree === "P" && d.costCurrency !== cur)) continue;
        if (d.id === "s_more_seeds" && !PT.hasSun(s, "d_seed_multiplier_unlocker")) continue;
        if (d.id === "p_golden_popcorn_value" && !PT.hasSun(s, "d_desert_core_mockup")) continue;
        if (d.id === "p_auric_silo" && !PT.hasSun(s, "d_desert_auric_blueprints")) continue;
        const before = PT.level(s, d.id); PT.buy(s, d.id); if (PT.level(s, d.id) > before) break;
      }
    }
  };

  // ------------------------------------------------------------------ Red Panda (nest interior, tier = nest tier + 1)
  PT.redPandaState = (s) => { const r = s.redPanda || (s.redPanda = { name: "Red Panda", named: false, introSeen: false, mode: "chill" }); r.tier = PT.redPandaTier(s); if (r.mode !== "assist" && r.mode !== "chill") r.mode = "chill"; return r; };
  PT.pandaAssisting = (s) => !!(s.redPanda?.introSeen && s.redPanda.mode === "assist" && PT.nestState(s).tier >= 1);
  PT.nameRedPanda = (s, name) => { const r = PT.redPandaState(s); r.name = String(name || "").trim().replace(/\s+/g, " ").slice(0, 12) || "Red Panda"; r.named = true; r.introSeen = true; r.mode = "chill"; };
  PT.hiddenTabTwigRate = function (s) { // Birb getHiddenTabTwigGainPerSecond
    const n = PT.nestState(s); if (!n.unlocked) return 0;
    if (s.currentMap === PT.NEST_MAP) return n.forest.activeTreeId || n.forest.autoCollectEnabled ? PT.nestTwigsPerSec(s, "birb") : 0;
    return PT.pandaAssisting(s) ? 0.55 * PT.nestTwigsPerSec(s, "companion") : 0;
  };
  PT.applyOffline = function (s, now = Date.now()) { // Birb applyOfflineEarnings: only twigs, only via the Red Panda helping; 8 h cap
    const t = s.lastActiveAt; s.lastActiveAt = now;
    if (!(t > 0) || t >= now) return null;
    const sec = Math.min(F.maxOffline, (now - t) / 1000);
    PT.nestAdvanceBeds(s, sec);
    const rate = PT.pandaAssisting(s) ? 0.55 * PT.nestTwigsPerSec(s, "companion") : 0, tw = Math.floor(rate * sec);
    if (tw > 0) PT.nestAddTwigs(s, tw);
    return { seconds: sec, awaySeconds: (now - t) / 1000, twigs: tw };
  };

  // ------------------------------------------------------------------ fish breeding, "Lineage Lake" (Birb §3)
  const BREED_TYPES = new Set(["popcorn_mult", "feather_mult", "seed_mult", "speed_mult", "reel_speed_mult", "pickup_mult", "xp_mult", "sell_mult", "expedition_mult", "golden_popcorn_mult", "parrot_damage_mult", "parrot_life_regen_mult", "parrot_hp_mult", "parrot_skill_point_mult", "parrot_attack_speed_mult", "parrot_move_speed_mult"]);
  const RAR = ["common", "uncommon", "rare", "epic", "legendary", "mythic"];
  const BREED_COST = { common: 25000, uncommon: 50000, rare: 100000, epic: 250000, legendary: 500000, mythic: 1e6 };
  const BREED_ODDS = [[68, 25, 6, 0.9, 0.1], [68, 25, 6, 0.9, 0.1], [38, 38, 18, 5, 1], [38, 38, 18, 5, 1], [15, 30, 35, 16, 4], [15, 30, 35, 16, 4], [5, 15, 35, 35, 10], [5, 15, 35, 35, 10], [0, 10, 30, 45, 15]];
  const BREED_MS = { common: 3e5, uncommon: 1.2e6, rare: 3.6e6, epic: 1.08e7, legendary: 2.16e7, mythic: 4.32e7 };
  const FUSE_POINTS = { common: 10, uncommon: 20, rare: 35, epic: 60, legendary: 100, mythic: 150 };
  const HYBRID_F = { common: 0.2, uncommon: 0.35, rare: 0.55, epic: 0.75, legendary: 1, mythic: 1.25 };
  const lineage = (a, b) => [PT.baseFishId(a), PT.baseFishId(b)].sort().join("|");
  const breed = (s) => PT.nestState(s).fishBreeding;
  PT.breedVisible = (s) => breed(s).unlocked || ((s.evolutionCount || 0) >= 5 && PT.aqPoints(PT.aq(s)) >= 600);
  PT.breedUnlock = function (s) {
    if (breed(s).unlocked) return "Owned";
    if ((s.evolutionCount || 0) < 5) return "Needs Evolution 5"; if (PT.aqPoints(PT.aq(s)) < 600) return "Needs 600 aquarium resonance";
    if (twigs(s).lt(1e6)) return "Not enough twigs";
    PT.sub(s, "twigs", 1e6); breed(s).unlocked = true; return "";
  };
  PT.breedCandidates = (s) => (s.fishInventory || []).filter((r) => r.count > 0 && BREED_TYPES.has(PT.FISH_BY.get(PT.baseFishId(r.fishId))?.effect?.type));
  PT.breedPreview = function (s, a, b) {
    const fa = PT.FISH_BY.get(PT.baseFishId(a || "")), fb = PT.FISH_BY.get(PT.baseFishId(b || ""));
    if (!fa || !fb || !BREED_TYPES.has(fa.effect?.type) || !BREED_TYPES.has(fb.effect?.type)) return { valid: false, reason: "invalid-parent" };
    const cnt = (id) => (s.fishInventory.find((r) => r.fishId === id)?.count || 0);
    const cost = BREED_COST[fa.rarity] + BREED_COST[fb.rarity], row = Math.min(8, RAR.indexOf(fa.rarity) + RAR.indexOf(fb.rarity) + (fa.type === fb.type ? 1 : 0));
    const sp = [a, b].filter((x) => PT.isShiny(x)).length, prog = breed(s).shinyProgressByLineage[lineage(a, b)] || 0;
    const out = { valid: false, monetaCost: cost, odds: BREED_ODDS[row], oddsRow: row, shinyParentCount: sp, shinyChance: prog >= 100 ? 100 : sp === 2 ? 10 : sp === 1 ? 5 : 0.5, shinyProgress: prog, shinyGuaranteed: prog >= 100 };
    if (cnt(a) <= 0 || cnt(b) <= 0 || (a === b && cnt(a) < 2)) return { ...out, reason: "not-owned" };
    if (breed(s).incubation) return { ...out, reason: "busy" };
    if (!PT.has(s, "monetariaMoneta", cost)) return { ...out, reason: "insufficient-moneta" };
    return { ...out, valid: true };
  };
  PT.breedStart = function (s, a, b) {
    const bs = breed(s), p = PT.breedPreview(s, a, b);
    if (!bs.unlocked) return "Locked"; if (!p.valid) return p.reason;
    for (const id of [a, b]) { const r = s.fishInventory.find((x) => x.fishId === id); r.count--; }
    s.fishInventory = s.fishInventory.filter((r) => r.count > 0);
    PT.sub(s, "monetariaMoneta", p.monetaCost);
    let x = 100 * Math.random(), rar = "legendary";
    for (let i = 0; i < 5; i++) { x -= p.odds[i]; if (x <= 0) { rar = RAR[i]; break; } }
    const shiny = p.shinyGuaranteed || 100 * Math.random() < p.shinyChance, key = lineage(a, b);
    if (shiny) delete bs.shinyProgressByLineage[key]; else if (p.shinyParentCount > 0) bs.shinyProgressByLineage[key] = Math.min(100, (bs.shinyProgressByLineage[key] || 0) + 5 * p.shinyParentCount);
    const dur = BREED_MS[rar], now = Date.now();
    bs.incubation = { parentAId: PT.baseFishId(a), parentBId: PT.baseFishId(b), dominantParentId: Math.random() < 0.5 ? PT.baseFishId(a) : PT.baseFishId(b), resultRarity: rar, resultShiny: shiny, startedAt: now, hatchAt: now + dur, baseDurationMs: dur, monetaCost: p.monetaCost };
    bs.lastParentIds = [a, b];
    return "";
  };
  PT.breedOnCatch = function (s, fishId, shiny) { // Birb recordFishingCatch: 5 s same species, 2 s same type, else 1 s; shiny catch cuts 40%
    const inc = breed(s).incubation, now = Date.now(); if (!inc || inc.hatchAt <= now) return;
    const f = PT.FISH_BY.get(PT.baseFishId(fishId)), pa = PT.FISH_BY.get(inc.parentAId), pb = PT.FISH_BY.get(inc.parentBId);
    const flat = f && (f.id === inc.parentAId || f.id === inc.parentBId) ? 5 : f && (f.type === pa?.type || f.type === pb?.type) ? 2 : 1;
    let rem = Math.max(0, inc.hatchAt - now - 1000 * flat); if (shiny) rem *= 0.6; inc.hatchAt = now + Math.round(rem);
  };
  const hybridCap = (s) => (breed(s).reserveSlotUnlocked ? 2 : 1);
  PT.breedClaim = function (s) {
    const bs = breed(s), inc = bs.incubation; if (!inc || inc.hatchAt > Date.now()) return "Not ready";
    if (bs.hybrids.length >= hybridCap(s)) { if (hybridCap(s) === 1) bs.hybrids = []; else return "Discard the reserve hybrid first"; }
    const h = { id: "nest_hybrid_" + bs.nextHybridId++, parentAId: inc.parentAId, parentBId: inc.parentBId, dominantParentId: inc.dominantParentId, rarity: inc.resultRarity, shiny: inc.resultShiny, lineagePoints: 0, hatchedAt: Date.now() };
    bs.hybrids.push(h); if (!bs.hybrids.some((x) => x.id === bs.activeHybridId)) bs.activeHybridId = h.id;
    bs.incubation = null; return "";
  };
  PT.breedFuse = function (s, hid) {
    const bs = breed(s), inc = bs.incubation, h = bs.hybrids.find((x) => x.id === hid); if (!inc || inc.hatchAt > Date.now() || !h) return "Not ready";
    if (lineage(h.parentAId, h.parentBId) !== lineage(inc.parentAId, inc.parentBId)) return "Different lineage";
    const before = JSON.stringify(h);
    if (h.rarity !== "legendary") { h.lineagePoints += FUSE_POINTS[inc.resultRarity]; while (h.lineagePoints >= 100 && h.rarity !== "legendary") { h.lineagePoints -= 100; h.rarity = RAR[RAR.indexOf(h.rarity) + 1]; } if (h.rarity === "legendary") h.lineagePoints = 0; }
    h.shiny = h.shiny || inc.resultShiny;
    if (JSON.stringify(h) === before) return "Nothing to gain";
    bs.incubation = null; return "";
  };
  PT.breedDiscard = (s) => { breed(s).incubation = null; return ""; };
  PT.hybridMult = function (s, type) { // Birb getActiveHybridMultiplier
    const bs = s.nest?.fishBreeding; const h = bs && bs.hybrids?.find((x) => x.id === bs.activeHybridId); if (!h) return 1;
    const dId = h.dominantParentId === h.parentBId ? h.parentBId : h.parentAId, rId = dId === h.parentAId ? h.parentBId : h.parentAId;
    const Df = PT.FISH_BY.get(dId), Rf = PT.FISH_BY.get(rId);
    const o = (Df?.effect?.type === type ? Math.max(0, Df.effect.value - 1) : 0) + (Rf?.effect?.type === type ? Math.max(0, Rf.effect.value - 1) * HYBRID_F[h.rarity] : 0);
    return 1 + o * (h.shiny ? 1.25 : 1);
  };
  PT.breedSyncReserve = (s) => { if (PT.aqPoints(PT.aq(s)) >= 1000) breed(s).reserveSlotUnlocked = true; };
})();
