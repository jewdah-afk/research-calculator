// Peckwood playtest, Phase 4: the Mine and the Crow, copied from Birb (editors LE ore system + area formulas,
// game WE mine profile, mine journey _E, crow ME/gE/lE). In Birb the mine opens from the Expedition floor-1
// secret room (Parrot Rebirb II + maxed starter gear); see expedition_secret.js.
// The mine room is map 25, the Treasure Room (mine tree) is map 26.
"use strict";
(function () {
  const PT = window.PT;
  const { D } = PT;
  PT.MINE_MAP = 25; PT.MINE_TREE_MAP = 26;
  const nn = (x) => (Number.isFinite(x) ? Math.max(0, Math.floor(x)) : 0);
  const Bi = (L, b) => { L = Math.max(0, Math.floor(L || 0)); return Math.pow(b, L) * Math.pow(2, Math.floor(L / 10)); };

  // ------------------------------------------------------------------ area formulas (Birb editors 18430-18552)
  const Yi = [10, 100, 1e3, 1e4, 1e5, 1e6, 1e7], Vi = [360, 2600, 13e4, 18e5, 21e6, 285e6, 18e8];
  const Hi = [240, 14400, 967680, 65028096, 4369888051, 293656477041, 19733715257131, 1326105665279205];
  const zi = [180, 9e3, 504e3, 28224e3, 1580544e3, 88510464e3, 4956585984e3, 277568815104000];
  const Wi = [...Hi, 36 * Hi[7]], Xi = [7, 17, 34, 47, 60, 73, 86], Ki = 1.1 / 1.15, Ji = Xi.map((x) => Math.pow(Ki, x - 1)), Mi = [10, 15, 20, 30, 40, 50, 60];
  const qi = (arr, e) => { const i = nn(e), a = Math.min(i, arr.length - 1); return Math.max(1, arr[a] * Ji[a] * Math.pow(5.8, i - a)); };
  const ji = (arr, t, g) => { const a = nn(t); return a < arr.length ? arr[a] : arr[arr.length - 1] * Math.pow(g, a - arr.length + 1); };
  const Zi = (arr, t, step, g) => { const r = Math.floor(t / step), n = ji(arr, r, g), o = ji(arr, r + 1, g); return Math.ceil(n * Math.pow(o / n, (t % step) / step)); };
  PT.mineAa = (a) => (a < 2 ? qi(Yi, a) : PT.mineDa(a) / 32);
  PT.mineDa = (a) => qi(Vi, a);
  PT.mineCa = (t) => [1, 1, 2, 3, 4, 5, 6][Math.min(6, t)] * (1 + Math.min(2, Math.max(0, t - 6) / 24));
  PT.mineUa = (t) => ((t < 2 ? 1 : 0.8) / Ji[Math.min(t, 6)]) * (1 + Math.min(5, Math.max(0, t - 6) / 12)) * Math.pow(2, Math.min(1, t)) * Math.pow(1.6, Math.max(0, Math.min(6, t) - 1)) * Math.pow(8.8 / 5.8, Math.max(0, t - 6));
  const ta = (area, branch) => Math.ceil(ji(Hi, area - 1, 36) * (6 + branch));
  PT.mineIa = (a) => (a >= 7 ? PT.mineIa(6) * Math.pow(8, a - 6) : Math.floor(ta(a + 1, 0) * (a < 2 ? 1 : 0.5)));
  PT.mineVr = (a) => 6 * Math.pow(2, Math.min(6, a));
  PT.mineMa = (id, L) => { const i = Math.floor(L - 1); return id === "m_ore_value" ? Zi(zi, i, 10, 30) : id === "m_mining_power" ? Zi(Wi, i, 12, 400) : id === "m_rupture" ? Math.ceil(2e6 * Math.pow(2.7, i)) : 4800 * Math.pow(24, i); };
  PT.mineAaMilestones = (a) => [0.2, 0.45, 0.7, 0.9].map((f) => Math.ceil(12 * Mi[Math.min(6, a)] * Math.max(1, Math.min(4, a)) * f) * qi(Yi, a));
  PT.mineRa = (a, k) => (a >= 7 ? PT.mineRa(6, k) * Math.pow(8, a - 6) : a < 2 ? 2 * PT.mineMa("m_mining_power", 11 * a + 1 + 2 * k) : 0.75 * PT.mineMa("m_mining_power", Xi[Math.min(6, a)] + 12 * Math.max(0, a - 6) - 6 + 2 * k));
  PT.mineGoldFromGolden = (a, rank) => Math.max(1, Math.round([2, 2, 4, 7, 12, 20, 32][Math.min(6, a)] * [1, 1.25, 1.75, 2.5, 4][rank] * PT.mineCa(a)));
  PT.MINE_TIERS = [["brute", 1], ["iron", 3], ["silver", 8], ["crystal", 20], ["obsidian", 48], ["luminite", 110], ["royal", 260]];
  PT.MINE_RARITY = [
    { id: "common", unlock: 0, hp: 1, reward: 1, guarantee: 0, color: "#cbd5e1" }, { id: "uncommon", unlock: 0, hp: 1.15, reward: 3, guarantee: 8, color: "#22c55e" },
    { id: "rare", unlock: 1, hp: 1.35, reward: 8, guarantee: 30, color: "#38bdf8" }, { id: "epic", unlock: 3, hp: 1.6, reward: 20, guarantee: 100, color: "#a855f7" },
    { id: "legendary", unlock: 5, hp: 2, reward: 50, guarantee: 250, color: "#facc15" },
  ];
  const ROLL = [[88, 12, 0, 0, 0], [78, 18, 4, 0, 0], [68, 24, 8, 0, 0], [64, 24, 10, 2, 0], [58, 27, 12, 3, 0], [54, 28, 13, 4, 1], [48, 30, 15, 5, 2]];

  // ------------------------------------------------------------------ mine tree (Birb d_mine_* nodes in the Treasure Room)
  PT.MINE_TREE = [
    { id: "work_perch", parent: null, area: 1, cost: 0, name: "Crow Rebirb", text: "START HERE. Unlocks Crow Rebirb." },
    { id: "precise_peck", parent: "work_perch", area: 1, cost: 12000, name: "Precise Peck", text: "Every 4th Crow peck is charged (x3). Unlocks Charged Strike." },
    { id: "rich_vein", parent: "work_perch", area: 1, cost: 28000, name: "Rich Vein", text: "Every 5th ore is Rare+ (Uncommon+ in area 0); rich ores pay x1.5." },
    { id: "impact_transfer", parent: "precise_peck", area: 2, cost: 86400, name: "Impact Transfer", text: "Damage x1.25; 75% of overkill carries to the next ore." },
    { id: "peck_rhythm", parent: "precise_peck", area: 2, cost: 115200, name: "Peck Rhythm", text: "Crow speed x1.35." },
    { id: "deep_survey", parent: "rich_vein", area: 3, cost: 6773760, name: "Deep Survey", text: "Rare+ every 3rd ore; Epic+ every 12th (area 3+)." },
    { id: "seismic_strike", parent: "impact_transfer", area: 4, cost: 390168576, name: "Seismic Strike", text: "+3 charged peck multiplier." },
    { id: "mineral_temper", parent: "seismic_strike", area: 4, cost: 1.2e9, name: "Mineral Temper", text: "Damage x1.08." },
    { id: "clean_extraction", parent: "deep_survey", area: 4, cost: 1.8e9, name: "Clean Extraction", text: "Full-break bonus 25% → 35%." },
    { id: "unbroken_rhythm", parent: "peck_rhythm", area: 5, cost: 34959104408, name: "Unbroken Rhythm", text: "Crow speed x1.25; ores respawn in 0.25 s." },
    { id: "work_pulse", parent: "unbroken_rhythm", area: 5, cost: 1.2e11, name: "Work Pulse", text: "Crow speed x1.05." },
    { id: "gold_beacon", parent: "clean_extraction", area: 5, cost: 1200, cur: "goldOre", name: "Gold Beacon", text: "Gold vein work x1.2." },
    { id: "crown_survey", parent: "deep_survey", area: 6, cost: 2055595339287, name: "Crown Survey", text: "Legendary every 20th ore (area 5+)." },
    { id: "fine_cut", parent: "gold_beacon", area: 6, cost: 1.6e12, name: "Fine Cut", text: "Rich ores pay x1.08 more." },
    { id: "royal_mastery", parent: "seismic_strike", area: 7, cost: 118402291542786, name: "Giant Slayer", text: "x2 damage to giants under 50% HP." },
    { id: "deep_mine", parent: "work_perch", area: 7, evo: 6, cost: 0, name: "Deep Mine", text: "Opens the deep nodes (area 7+)." },
    { id: "royal_impact", parent: "deep_mine", area: 7, evo: 6, cost: 2e16, name: "Royal Impact", text: "Damage x2." },
    { id: "mineral_coffers", parent: "deep_mine", area: 7, evo: 6, cost: 4e16, name: "Mineral Coffers", text: "Every 6 breaks pays 50% of the batch's Brute Ore again." },
    { id: "seismic_echo", parent: "royal_impact", area: 8, evo: 6, cost: 8000, cur: "goldOre", name: "Seismic Echo", text: "Charged hits echo for 50% after 0.08 s." },
    { id: "royal_cut", parent: "mineral_coffers", area: 8, evo: 6, cost: 12000, cur: "goldOre", name: "Royal Cut", text: "Coffers pay 100%." },
    { id: "abyssal_forge", parent: "seismic_echo", area: 8, evo: 6, growth: (L) => Math.ceil(2e17 * Math.pow(3, Math.min(200, L)) * Math.pow(2.85, Math.max(0, L - 200))), name: "Abyssal Forge", text: "Damage x1.2 per level (x2 every 10)." },
    { id: "abyssal_treasure", parent: "royal_cut", area: 8, evo: 6, cur: "goldOre", growth: (L) => Math.ceil(8000 * Math.pow(1.4, L)), name: "Abyssal Treasure", text: "Ore value and Gold x1.15 per level (x2 every 10)." },
    { id: "deep_rebirb", parent: ["abyssal_forge", "abyssal_treasure"], area: 10, evo: 6, cost: 0, name: "Deep Rebirb", text: "Crow rebirbs past 8 (needs 8 crow rebirbs)." },
  ];
  const NODE = new Map(PT.MINE_TREE.map((n) => [n.id, n]));
  const lvlOf = (s, id) => Math.floor(s.sunflowerUpgrades?.["d_mine_" + id] || 0);
  PT.mineHas = function (s, id) { // Birb Di: the node and every ancestor owned
    let n = NODE.get(id); if (!n || lvlOf(s, id) <= 0) return false;
    while (n.parent) { const ps = Array.isArray(n.parent) ? n.parent : [n.parent]; if (!ps.every((p) => lvlOf(s, p) > 0)) return false; n = NODE.get(ps[0]); }
    return true;
  };
  const has = PT.mineHas;
  PT.mineNodeCost = (s, id) => { const n = NODE.get(id), L = lvlOf(s, id); return n.growth ? n.growth(L) : n.cost; };
  PT.mineNodeVisible = (s, id) => { const n = NODE.get(id); if (!n) return false; if (id === "deep_mine" && PT.mineArea(s) < 7) return false; const ps = n.parent ? (Array.isArray(n.parent) ? n.parent : [n.parent]) : []; return ps.length === 0 || ps.some((p) => lvlOf(s, p) > 0); };
  PT.mineNodeUnlocked = (s, id) => { const n = NODE.get(id); if (!n) return false; if (PT.mineArea(s) < n.area || (s.evolutionCount || 0) < (n.evo || 0)) return false;
    if (id === "deep_rebirb" && PT.mineState(s).crowRebirbCount < 8) return false;
    const ps = n.parent ? (Array.isArray(n.parent) ? n.parent : [n.parent]) : []; return ps.every((p) => lvlOf(s, p) > 0); };
  PT.mineBuyNode = function (s, id) {
    const n = NODE.get(id); if (!n) return "unknown";
    if (!n.growth && lvlOf(s, id) >= 1) return "Owned";
    if (!PT.mineNodeUnlocked(s, id)) return "Locked";
    const c = PT.mineNodeCost(s, id), m = PT.mineState(s);
    if (n.cur === "goldOre") { if (m.goldOre < c) return "Not enough Gold Ore"; m.goldOre -= c; } else { if (!PT.has(s, "bruteOre", c)) return "Not enough Brute Ore"; PT.sub(s, "bruteOre", c); }
    s.sunflowerUpgrades["d_mine_" + id] = lvlOf(s, id) + 1;
    if (id === "work_perch") PT.mineCampaign(s).freeTreasureClaimed = true;
    return "";
  };

  // ------------------------------------------------------------------ m_ upgrades: real costs (Birb ma) and effects (la, sa, $i, ea)
  const EFFECTS = { m_ore_value: (L) => Math.pow(1.1, L - 1), m_mining_power: (L) => Math.pow(1.1, L - 1), m_rupture: (L) => 0.25 + 0.05 * Math.min(15, L - 1), m_charged_strike: (L) => 3 + Math.min(3, L - 1) };
  for (const [id, f] of Object.entries(EFFECTS)) { const d = PT.UP.get(id); if (d) d.effectFn = f; }
  const cost0 = PT.cost;
  PT.cost = (def, L) => (def.tree === "M" && EFFECTS[def.id] ? PT.mineMa(def.id, L) : cost0(def, L));
  PT.mineUpShown = (s, id) => id !== "m_pickaxe" && id !== "m_rupture" && (id !== "m_charged_strike" || has(s, "precise_peck")); // Birb GE

  // ------------------------------------------------------------------ state (Birb BE defaults + campaign YE)
  PT.mineState = function (s) {
    const m = s.mine || (s.mine = {});
    const def = { goldOre: 0, journeyVersion: 1, highestArea: 0, bossRespawnAt: 0, playerAutoEnabled: false, crowLevel: 1, crowXp: 0, crowRebirbCount: 0, crowRebirbLegacyCount: 0, crowTrainingLevel: 1 };
    if (m.crowRebirbLegacyCount === undefined && m.crowRebirbCount !== undefined) m.crowRebirbLegacyCount = Math.min(8, nn(m.crowRebirbCount)); // Birb EE on old saves
    for (const k in def) m[k] ??= def[k];
    m.crowLevel = Math.max(1, Math.floor(m.crowLevel)); m.crowTrainingLevel = Math.max(1, m.crowTrainingLevel, m.crowLevel);
    if (s.upgrades) delete s.upgrades.m_pickaxe;
    return m;
  };
  PT.mineCampaign = (s) => { const m = PT.mineState(s); const c = m.campaign || (m.campaign = { version: 2, areaDamage: {}, areaMilestones: {}, normalBreaks: 0, chargeHits: 0, freeTreasureClaimed: false, oreDiscoveries: {} }); c.coffer ||= { breaks: 0, income: 0 }; return c; };
  PT.mineArea = (s) => Math.floor(s.mine?.highestArea || 0); // replaces the core stub (desert nodes use mineAreaRequired)
  PT.mineOpen = (s) => s.floorOneMineEntranceOpened === true;

  // ------------------------------------------------------------------ profile, damage, crow (Birb WE, getMineOreDamageBonus, ME, Ju, gE)
  PT.mineProfile = (s) => ({
    breakBonus: 0.25 + (has(s, "clean_extraction") ? 0.1 : 0), chargeInterval: has(s, "precise_peck") ? 4 : 0,
    chargeMultiplier: EFFECTS.m_charged_strike(s.upgrades.m_charged_strike || 1) + (has(s, "seismic_strike") ? 3 : 0),
    retainedImpact: has(s, "impact_transfer"), coreBreaker: has(s, "royal_mastery"),
    richInterval: has(s, "deep_survey") ? 3 : has(s, "rich_vein") ? 5 : 0, richMultiplier: (has(s, "rich_vein") ? 1.5 : 1) * (has(s, "fine_cut") ? 1.08 : 1),
    epicInterval: has(s, "deep_survey") ? 12 : 0, legendaryInterval: has(s, "crown_survey") ? 20 : 0, breakSeconds: has(s, "unbroken_rhythm") ? 0.25 : 0.5,
    rarityDiscoveryMultiplier: 1 + 0.1 * PT.mineState(s).crowRebirbCount, goldDiscoveryMultiplier: (1 + 0.15 * PT.mineState(s).crowRebirbCount) * (has(s, "gold_beacon") ? 1.2 : 1),
    cofferBonus: has(s, "mineral_coffers") ? (has(s, "royal_cut") ? 1 : 0.5) : 0, echoMultiplier: has(s, "seismic_echo") ? 0.5 : 0,
  });
  const legacy = (m) => Math.min(8, nn(m.crowRebirbLegacyCount ?? m.crowRebirbCount));
  const ME = (L, leg) => Math.max(Math.max(0.24 - 0.08, 0.24 - 0.01 * leg), 0.55 / ((1 + 0.015 * (L - 1)) * Math.pow(1.06, leg)));
  const speed = (s) => (has(s, "peck_rhythm") ? 1.35 : 1) * (has(s, "unbroken_rhythm") ? 1.25 : 1) * (has(s, "work_pulse") ? 1.05 : 1);
  const Ju = (e, t) => { const i = Math.max(0.18, e) / Math.max(1, t), a = Math.max(0.18, i); return { interval: a, damage: a / i }; };
  const crowJu = (s) => { const m = PT.mineState(s); return Ju(ME(Math.max(1, m.crowLevel, m.crowTrainingLevel), legacy(m)), speed(s)); };
  PT.crowInterval = (s) => crowJu(s).interval;
  PT.crowRebirbDamage = (n) => Math.pow(1.25, Math.min(8, n)) * Math.pow(2, Math.max(0, n - 8));
  PT.mineDamageBonus = function (s) { // getMineOreDamageBonus
    const m = PT.mineState(s), c = PT.mineCampaign(s), area = PT.mineArea(s);
    const ha = 1 * Math.pow(1.1, Math.floor(s.upgrades.m_mining_power || 1) - 1); // x (1 + core edge): Metal Drain is switched off in Birb
    const areaMult = 1 + 0.04 * Math.min(4, Math.max(0, c.areaMilestones[area] || 0));
    const Fi = (has(s, "impact_transfer") ? 1.25 : 1) * (has(s, "mineral_temper") ? 1.08 : 1) * (has(s, "royal_impact") ? 2 : 1) * Bi(lvlOf(s, "abyssal_forge") * (has(s, "abyssal_forge") ? 1 : 0), 1.2);
    return Math.min(Number.MAX_VALUE, ha * areaMult * Fi * PT.crowRebirbDamage(m.crowRebirbCount) * crowJu(s).damage) - 1;
  };
  PT.crowDamage = (s) => 1 + PT.mineDamageBonus(s);
  PT.playerPickDamage = (s) => (0.3 * PT.crowDamage(s) * 0.28) / Math.max(0.18, PT.crowInterval(s)); // Birb ga
  PT.mineOreValue = (s) => Math.min(Number.MAX_VALUE, Math.pow(1.1, Math.floor(s.upgrades.m_ore_value || 1) - 1) * Math.pow(1.12, legacy(PT.mineState(s))) * ((s.evolutionCount || 0) >= 6 ? 2 : 1) * Bi(has(s, "abyssal_treasure") ? lvlOf(s, "abyssal_treasure") : 0, 1.15));
  PT.mineGoldenChance = (s) => Math.max(0, Math.min(0.1, Math.min(0.06, 0.01 * Math.min(6, PT.mineArea(s))) + 0.005 * legacy(PT.mineState(s))));
  PT.crowXpNeeded = (L) => { const t = Math.max(1, Math.floor(L)); return Math.max(1, Math.floor(60 * Math.pow(t, 1.55) + 120 * Math.pow(Math.max(0, t - 25), 1.25))); };
  const REBIRB = [[3, 1], [5, 2], [7, 3], [7, 3], [10, 4], [12, 5], [16, 6], [20, 7]];
  PT.crowRebirbReq = (s) => { const n = PT.mineState(s).crowRebirbCount; if (n < 8) return { level: REBIRB[n][0], giants: REBIRB[n][1] }; return lvlOf(s, "deep_rebirb") > 0 ? { level: 20 + 5 * (n - 8), giants: 10 + 3 * (n - 8) } : null; };
  PT.crowRebirbUnlocked = (s) => has(s, "work_perch");
  PT.crowCanRebirb = (s) => { const r = PT.crowRebirbReq(s), m = PT.mineState(s); return PT.crowRebirbUnlocked(s) && !!r && m.crowLevel >= r.level && PT.mineArea(s) >= r.giants; };
  PT.crowRebirb = function (s) { if (!PT.crowCanRebirb(s)) return false; const m = PT.mineState(s); m.crowRebirbLegacyCount = Math.min(m.crowRebirbCount, legacy(m)); m.crowTrainingLevel = Math.max(1, m.crowLevel, m.crowTrainingLevel); m.crowRebirbCount++; m.crowLevel = 1; m.crowXp = 0; return true; };
  function crowXp(G, ore) { // Birb addMineCrowXp (every non-giant break)
    const s = G.s, m = PT.mineState(s);
    const gain = Math.max(1, Math.ceil(Math.max(1, Math.floor(ore.xpBase || 1)) * (ore.golden ? 2 : 1) * (1 + 0.15 * PT.mineArea(s)) * Math.pow(1.25, m.crowRebirbCount)));
    m.crowXp += gain; while (m.crowXp >= PT.crowXpNeeded(m.crowLevel)) { m.crowXp -= PT.crowXpNeeded(m.crowLevel); m.crowLevel++; }
    m.crowTrainingLevel = Math.max(m.crowTrainingLevel, m.crowLevel);
  }

  // ------------------------------------------------------------------ ore spawn, damage, break (Birb LE.spawnOre / applyOreDamage / handleMineOreBroken)
  const disc = (s, a) => { const c = PT.mineCampaign(s); return c.oreDiscoveries[a] || (c.oreDiscoveries[a] = { breaks: 0, drought: [0, 0, 0, 0, 0], goldWork: 0 }); };
  function spawnOre(s, boss) {
    const area = PT.mineArea(s), P = PT.mineProfile(s), tier = Math.min(6, area);
    let rank = 0;
    if (!boss) {
      const d = disc(s, area), mlt = P.rarityDiscoveryMultiplier;
      if (d.pending !== undefined) rank = PT.MINE_RARITY.findIndex((r) => r.id === d.pending);
      else {
        let x = 100 * Math.random(); const row = ROLL[tier]; for (let i = 0; i < 5; i++) { x -= row[i]; if (x <= 0) { rank = i; break; } }
        if (d.breaks === 0) rank = 0;
        else {
          PT.MINE_RARITY.forEach((r, i) => { if (r.unlock <= area && r.guarantee > 0 && d.drought[i] + 1e-9 >= r.guarantee - mlt) rank = Math.max(rank, i); });
          const t = d.surveyWork ?? d.breaks, a = t + mlt, crosses = (k) => Math.floor(a / k) > Math.floor(t / k);
          if (P.richInterval && crosses(P.richInterval)) rank = Math.max(rank, area >= 1 ? 2 : 1);
          if (area >= 3 && P.epicInterval && crosses(12)) rank = Math.max(rank, 3);
          if (area >= 5 && P.legendaryInterval && crosses(20)) rank = 4;
        }
        d.pending = PT.MINE_RARITY[rank].id; d.pendingSurveyWork = (d.surveyWork ?? d.breaks) + mlt;
      }
    }
    const R = PT.MINE_RARITY[rank], base = PT.mineAa(area), lo = Math.max(1, Math.ceil(0.9 * base)), hi = Math.floor(1.1 * base);
    const A = Math.min(hi, lo + Math.floor((hi - lo + 1) * Math.random()));
    let maxHits = boss ? PT.mineDa(area) : Math.max(1, Math.round(A * R.hp));
    const rarityReward = R.reward * (!boss && rank > 0 ? P.richMultiplier : 1);
    const ore = { boss, area, tier, tierId: PT.MINE_TIERS[tier][0], rank, rarity: R.id, rarityReward, rewardMult: PT.mineUa(area) * rarityReward * (boss ? 1 : A / maxHits),
      xpBase: PT.MINE_TIERS[tier][1] * 2 * (1 + 0.5 * rank) * (boss ? 1 : PT.mineCa(area)), golden: false, maxHits, hits: maxHits };
    if (!boss) {
      const d = disc(s, area), ch = PT.mineGoldenChance(s);
      const g = d.pendingGolden !== undefined ? d.pendingGolden : (area > 0 || ch > 0) && (Math.random() < ch || d.goldWork + 1e-9 >= 30);
      d.pendingGolden = g; ore.golden = g; if (g && ore.maxHits < 8) { ore.hits += 8 - ore.maxHits; ore.maxHits = 8; }
    }
    return ore;
  }
  const payout = (ore, value, hp) => (ore.boss ? 0 : Math.max(1, value) * Math.max(1, ore.rewardMult) * hp); // Birb oE
  function pay(G, amt, x, y, color) { if (!(amt > 0)) return; const s = G.s; PT.add(s, "bruteOre", amt); G.gain("bruteOre", amt); PT.mineState(s).runBruteOreEarned = (PT.mineState(s).runBruteOreEarned || 0) + amt; if (x !== undefined && s.currentMap === PT.MINE_MAP) G.onFloat(x, y, "+" + PT.fmt(amt), color || "#b9c2cf"); }
  function damageOre(G, ore, dmg, charged, echo) {
    const s = G.s, P = PT.mineProfile(s), c = PT.mineCampaign(s), M = G.mine, value = PT.mineOreValue(s);
    if (charged && P.chargeInterval) { c.chargeHits = (c.chargeHits || 0) + 1; if (c.chargeHits >= 4) { dmg *= P.chargeMultiplier; c.chargeHits = 0; ore.chargedHit = 0.3; } }
    const A = dmg, before = ore.hits;
    if (ore.boss && !echo && P.coreBreaker && before <= 0.5 * ore.maxHits) dmg *= 2;
    if (!ore.boss && !echo) { if (M.retained > 0) dmg += Math.min(ore.maxHits, M.retained); M.retained = 0; }
    const dealt = dmg >= ore.hits * (1 - 1e-12) ? ore.hits : dmg;
    ore.hits -= dealt;
    if (!ore.boss && !ore.golden) c.areaDamage[ore.area] = (c.areaDamage[ore.area] || 0) + dealt;
    const d = payout(ore, value, dealt);
    if (!ore.boss) { pay(G, d, 528 + (Math.random() - 0.5) * 60, 470, charged && ore.chargedHit ? "#facc15" : echo ? "#b5e9ef" : "#fff4d6"); if (P.cofferBonus) c.coffer.income += d; }
    if (ore.hits <= 0) {
      ore.breakReward = payout(ore, value, ore.maxHits) * P.breakBonus;
      if (!echo && P.retainedImpact && !ore.boss) M.retained = 0.75 * Math.max(0, A - before);
      return true;
    }
    if (charged && ore.chargedHit && P.echoMultiplier > 0) ore.echo = { damage: dmg * 0.5, t: 0.08 };
    return false;
  }
  function oreBroken(G, ore) {
    const s = G.s, P = PT.mineProfile(s), c = PT.mineCampaign(s), m = PT.mineState(s);
    if (!ore.boss) {
      if (!ore.golden) c.normalBreaks = (c.normalBreaks || 0) + 1;
      const d = disc(s, ore.area), mlt = P.rarityDiscoveryMultiplier;
      d.surveyWork = d.pendingSurveyWork ?? (d.surveyWork ?? d.breaks) + mlt; d.breaks++;
      d.drought = d.drought.map((v, r) => (r <= ore.rank ? 0 : Math.min(PT.MINE_RARITY[r].guarantee, v + mlt)));
      delete d.pending; delete d.pendingSurveyWork;
      d.goldWork = ore.golden ? 0 : Math.min(30, (d.goldWork || 0) + (1 + 2 * ore.rank) * P.goldDiscoveryMultiplier); delete d.pendingGolden;
      let coffer = 0;
      if (P.cofferBonus > 0) { c.coffer.income += ore.breakReward; if (++c.coffer.breaks >= 6) { coffer = c.coffer.income * P.cofferBonus; c.coffer.breaks = 0; c.coffer.income = 0; } }
      G.mine.respawn = P.breakSeconds;
      pay(G, ore.breakReward, 528, 430, "#ffd27a"); pay(G, coffer, 528, 400, "#a7f3d0");
      if (!ore.golden) { // area milestones: +4% damage and a Brute Ore payout each
        let k = c.areaMilestones[ore.area] || 0; const th = PT.mineAaMilestones(ore.area);
        while (k < 4 && (c.areaDamage[ore.area] || 0) >= th[k]) { pay(G, PT.mineRa(ore.area, k)); k++; G.toast && G.toast(`+${4 * k}% damage in this area`); }
        c.areaMilestones[ore.area] = k;
      }
      crowXp(G, ore);
      if (ore.golden) m.goldOre += Math.floor(PT.mineGoldFromGolden(ore.area, ore.rank) * Bi(has(s, "abyssal_treasure") ? lvlOf(s, "abyssal_treasure") : 0, 1.15));
    }
  }

  // ------------------------------------------------------------------ giants (Birb mineJourney: 60 s fight, 60 s cooldown, no penalty for losing)
  PT.mineChallenge = function (G) {
    const s = G.s, m = PT.mineState(s), M = G.mine; if (M.boss || Date.now() < m.bossRespawnAt) return "The giant is resting";
    M.boss = spawnOre(s, true); M.bossUntil = Date.now() + 60e3; M.bossArea = PT.mineArea(s); return "";
  };
  function bossWon(G) {
    const s = G.s, m = PT.mineState(s), a = G.mine.bossArea;
    m.highestArea = a + 1; m.bossRespawnAt = Date.now() + 60e3;
    const brute = PT.mineIa(a) * ((s.evolutionCount || 0) >= 6 ? 2 : 1); PT.add(s, "bruteOre", brute); G.gain("bruteOre", brute);
    const ec = m.expeditionCycle || (m.expeditionCycle = { version: 1, rewardedGiants: 0 });
    if (ec.rewardedGiants < a + 1) { m.goldOre += PT.mineVr(a); ec.rewardedGiants = a + 1; }
    G.toast && G.toast(`AREA ${a + 1} UNLOCKED! Giant treasure: +${PT.fmt(brute)} Brute Ore`);
    G.mine.boss = null;
  }

  // ------------------------------------------------------------------ simulation: the crow mines everywhere once the entrance is open
  PT.updateMine = function (G, dt) {
    const s = G.s; if (!PT.mineOpen(s)) return;
    const M = G.mine || (G.mine = { ore: null, respawn: 0, prog: 0, retained: 0, boss: null, autoT: 0 });
    if (M.boss && Date.now() > M.bossUntil) { M.boss = null; G.toast && G.toast("Time is up! Cave-in! Back to the mine."); }
    const fightingBoss = M.boss && s.currentMap === PT.MINE_MAP;
    if (!M.boss && !M.ore) { M.respawn -= dt; if (M.respawn <= 0) M.ore = spawnOre(s, false); }
    const target = fightingBoss ? M.boss : M.boss ? null : M.ore;
    for (const o of [M.ore, M.boss]) if (o?.echo) { o.echo.t -= dt; if (o.echo.t <= 0) { const e = o.echo; o.echo = null; if (o.hits > 0 && damageOre(G, o, e.damage, false, true)) finish(G, o); } }
    if (!target) return;
    const iv = PT.crowInterval(s), d = M.prog + dt / iv;
    if (Math.floor(d + 0.6) > Math.floor(M.prog + 0.6)) { M.prog = d % 1; if (M.prog < 0.4) M.prog = 0.4; if (damageOre(G, target, PT.crowDamage(s), true, false)) finish(G, target); }
    else M.prog = d % 1;
    if (s.currentMap === PT.MINE_MAP && PT.mineState(s).playerAutoEnabled && PT.mineArea(s) >= 1 && Date.now() > (M.manualAt || 0) + 1000) {
      M.autoT += dt; if (M.autoT >= iv) { M.autoT -= iv; const t2 = fightingBoss ? M.boss : M.ore; if (t2 && damageOre(G, t2, PT.playerPickDamage(s), false, false)) finish(G, t2); }
    }
  };
  function finish(G, ore) { if (ore.boss) bossWon(G); else { oreBroken(G, ore); G.mine.ore = null; } }
  PT.minePlayerHit = function (G) { // click on the ore: one Birb strike (never charged)
    const M = G.mine; if (!M) return; const t = M.boss && G.s.currentMap === PT.MINE_MAP ? M.boss : M.ore; if (!t) return;
    M.manualAt = Date.now(); if (damageOre(G, t, PT.playerPickDamage(G.s), false, false)) finish(G, t);
  };
  PT.mineOnEvolve = function (G) { // Birb: the mine object is replaced; crow rebirbs and the open entrance stay
    const s = G.s, old = PT.mineState(s);
    s.mine = { crowRebirbCount: old.crowRebirbCount, crowRebirbLegacyCount: Math.min(old.crowRebirbCount, legacy(old)) };
    PT.mineState(s); s.resources.bruteOre = D(0); if (G.mine) G.mine = null;
    for (const k of Object.keys(s.upgrades)) if (k.startsWith("m_")) delete s.upgrades[k];
    for (const k of Object.keys(s.sunflowerUpgrades)) if (k.startsWith("d_mine_")) delete s.sunflowerUpgrades[k];
  };
})();
