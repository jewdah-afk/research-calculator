// Phase 6c: the quest merchant (Birb sI / questMerchantManager). Main quests, daily quests (rules v1), quest stats, bonuses.
// Birb's server "flock orders" (daily rules v2/v3) are off today (flockCommunity.generationEnabled is false), so only v1 dailies run.
(function () {
  const PT = window.PT, X = PT.EXP;
  const DAY = 864e5; // Birb yB: one daily cycle
  const q = (id, type, family, metric, target, rewardStat, rewardValue, sortOrder, extra) => ({ id, questType: type, family, metric, target, rewardStat, rewardValue, sortOrder, ...extra });
  const KF = "kills_by_floor", BC = "boss_clears_by_floor", KT = "kills_by_enemy_type";
  // Birb vB (daily) and MB (main): numbers only
  const DAILY = [
    q("daily_floor1_clearance", "daily", "floor_kill", KF, 35, "popcorn_gain_mult", 0.01, 10, { floor: 1 }),
    q("daily_floor2_predator_control", "daily", "floor_kill", KF, 30, "seed_gain_mult", 0.02, 11, { floor: 2, requiredHighestFloor: 2 }),
    q("daily_floor3_recon", "daily", "floor_kill", KF, 30, "twig_gain_mult", 0.03, 12, { floor: 3, requiredHighestFloor: 3 }),
    q("daily_floor4_tidebreak_patrol", "daily", "floor_kill", KF, 30, "feather_gain_mult", 0.02, 13, { floor: 4, requiredHighestFloor: 4 }),
    q("daily_floor1_boss", "daily", "boss_clear", BC, 1, "expedition_skill_point_mult", 0.01, 20, { floor: 1 }),
    q("daily_floor2_boss", "daily", "boss_clear", BC, 1, "expedition_skill_point_mult", 0.02, 21, { floor: 2, requiredHighestFloor: 2 }),
    q("daily_floor3_boss", "daily", "boss_clear", BC, 1, "expedition_damage_mult", 0.02, 22, { floor: 3, requiredHighestFloor: 3 }),
    q("daily_floor4_boss", "daily", "boss_clear", BC, 1, "expedition_chest_reward_mult", 0.05, 23, { floor: 4, requiredHighestFloor: 4 }),
    q("daily_hunt_harpy", "daily", "enemy_hunt", KT, 8, "seed_gain_mult", 0.01, 30, { enemyType: "harpy", requiredHighestFloor: 4 }),
    q("daily_hunt_witch", "daily", "enemy_hunt", KT, 3, "twig_gain_mult", 0.02, 31, { enemyType: "witch", requiredHighestFloor: 2 }),
    q("daily_hunt_cobra", "daily", "enemy_hunt", KT, 12, "popcorn_gain_mult", 0.02, 32, { enemyType: "cobra", requiredHighestFloor: 2 }),
    q("daily_hunt_whipe", "daily", "enemy_hunt", KT, 10, "popcorn_gain_mult", 0.03, 33, { enemyType: "fishfolk-whipe", requiredHighestFloor: 4 }),
    q("daily_hunt_inkbender", "daily", "enemy_hunt", KT, 8, "twig_gain_mult", 0.04, 34, { enemyType: "fishfolk-inkbender", requiredHighestFloor: 4 }),
  ];
  const FLOCK = ["daily_flock_patrol", "daily_flock_elite", "daily_flock_boss", "daily_flock_deep"].map((id, t) =>
    q(id, "daily", t === 2 ? "boss_clear" : t === 1 ? "enemy_hunt" : "floor_kill", t === 2 ? BC : KF, 1, "expedition_skill_point_mult", 0, 100 + t, {}));
  const M = (id, family, metric, target, stat, value, order, floor, extra = {}) => q(id, "main", family, metric, target, stat, value, order, { ...(floor ? { floor } : {}), requiredHighestFloor: extra.req ?? floor, ...(extra.enemyType ? { enemyType: extra.enemyType } : {}) });
  const MAIN = [
    M("main_floor1_first_incursion", "floor_kill", KF, 150, "expedition_damage_mult", 0.1, 900, 1),
    M("main_floor1_break_the_fangs", "boss_clear", BC, 1, "expedition_skill_point_mult", 0.25, 910, 1),
    M("main_floor2_swamp_trail", "floor_kill", KF, 350, "expedition_hp_mult", 0.15, 920, 2),
    M("main_floor2_break_the_coven", "boss_clear", BC, 2, "expedition_skill_point_mult", 0.5, 930, 2),
    M("main_defeat_anubis", "enemy_hunt", KT, 1, "expedition_skill_point_mult", 1, 1000, 0, { enemyType: "anubis", req: 3 }),
    M("main_floor3_war_of_attrition", "floor_kill", KF, 600, "expedition_damage_mult", 0.25, 1010, 3),
    M("main_floor4_boss_gauntlet", "boss_clear", BC, 3, "expedition_skill_point_mult", 1.25, 1030, 4),
    M("main_floor4_whipline_collapse", "enemy_hunt", KT, 100, "expedition_chest_reward_mult", 0.25, 1040, 0, { enemyType: "fishfolk-whipe", req: 4 }),
    M("main_floor4_inkbender_blackout", "enemy_hunt", KT, 80, "expedition_skill_point_mult", 0.4, 1050, 0, { enemyType: "fishfolk-inkbender", req: 4 }),
    M("main_floor4_tidebreak_pressure", "floor_kill", KF, 1000, "expedition_skill_point_mult", 0.65, 1060, 4),
    M("main_floor5_horror_encore", "boss_clear", BC, 3, "expedition_skill_point_mult", 1.25, 1080, 5),
    M("main_floor6_frozen_apex", "boss_clear", BC, 5, "expedition_skill_point_mult", 1.5, 1100, 6),
    M("main_floor6_winter_breaker", "floor_kill", KF, 2000, "expedition_hp_mult", 0.5, 1110, 6),
    M("main_floor7_marsh_siege", "floor_kill", KF, 3000, "expedition_damage_mult", 0.35, 1120, 7),
    M("main_floor7_chieftains_fall", "boss_clear", BC, 5, "expedition_skill_point_mult", 1.75, 1130, 7),
    M("main_floor8_beyond_the_reflection", "floor_kill", KF, 4000, "expedition_hp_mult", 0.75, 1140, 8),
    M("main_floor8_end_the_feast", "boss_clear", BC, 5, "expedition_skill_point_mult", 2, 1150, 8),
    M("main_floor9_ash_march", "floor_kill", KF, 5000, "expedition_damage_mult", 0.5, 1160, 9),
    M("main_floor9_silence_the_archivist", "boss_clear", BC, 1, "expedition_skill_point_mult", 2.5, 1170, 9),
  ];
  const ALL = [...DAILY, ...FLOCK, ...MAIN], BY_ID = Object.fromEntries(ALL.map((d) => [d.id, d]));
  // Birb KT: legacy main reward overrides (applied once when the reward rules moved to v2)
  const OVERRIDES = { main_defeat_anubis: 1, main_floor3_war_of_attrition: 0.2, main_floor4_boss_gauntlet: 2, main_floor4_whipline_collapse: 0.25, main_floor4_inkbender_blackout: 0.25,
    main_floor4_tidebreak_pressure: 0.3, main_floor5_horror_encore: 1, main_floor6_frozen_apex: 1.5, main_floor6_winter_breaker: 0.5 };
  // Birb v1 daily target overrides (getQuestTarget)
  const V1_TARGETS = { daily_floor2_predator_control: 25, daily_floor3_recon: 20, daily_floor4_tidebreak_patrol: 18 };
  const TRACKED = ["masked-forest-spirit", "twig-blight", "giant-fly", "harpy", "cobra", "witch", "anubis", "fishfolk-whipe", "fishfolk-inkbender", "fishfolk-brute"]; // Birb RB
  const BONUS_STATS = ["seed_gain_mult", "popcorn_gain_mult", "twig_gain_mult", "feather_gain_mult", "expedition_damage_mult", "expedition_hp_mult", "expedition_skill_point_mult",
    "expedition_chest_chance_flat", "expedition_chest_reward_mult", "pickup_radius_mult"];
  X.QUESTS = { DAILY, MAIN, FLOCK, ALL, BY_ID, BONUS_STATS };

  const int0 = (v) => { const n = Number(v); return Number.isFinite(n) ? Math.max(0, Math.floor(n)) : 0; };
  const softCap = (e, t) => { const n = Math.max(0, Number.isFinite(e) ? e : 0); return n <= t ? n : 2 * Math.sqrt(t) * Math.sqrt(n) - t; }; // Birb tM
  const dailyCount = (stat, n) => { const v = int0(n); return stat === "expedition_chest_reward_mult" ? softCap(v, 5) : v; }; // Birb JT
  X.dailyBonuses = (counts) => { const t = {}; for (const d of DAILY) t[d.rewardStat] = (t[d.rewardStat] || 0) + dailyCount(d.rewardStat, Number(counts?.[d.id])) * d.rewardValue; return t; }; // Birb ZT

  const emptyStats = () => {
    const f = {}; for (let i = 1; i <= 8; i++) f[i] = 0;
    return { killsByFloor: { ...f }, bossClearsByFloor: { ...f }, killsByEnemyType: Object.fromEntries(TRACKED.map((t) => [t, 0])) };
  };
  const normStats = (e) => { const z = emptyStats(); return { killsByFloor: { ...z.killsByFloor, ...(e?.killsByFloor || {}) }, bossClearsByFloor: { ...z.bossClearsByFloor, ...(e?.bossClearsByFloor || {}) },
    killsByEnemyType: { ...z.killsByEnemyType, ...(e?.killsByEnemyType || {}) } }; };
  const normIds = (e, type) => (Array.isArray(e) ? [...new Set(e.filter((id) => typeof id === "string" && BY_ID[id]).filter((id) => !type || BY_ID[id].questType === type))] : []);
  const highest = (s) => Math.max(1, Math.floor(Number(PT.expState(s).highestFloorReached) || 1));
  X.questVisible = (s, d) => !!d && highest(s) >= Math.max(1, Math.floor(Number(d.requiredHighestFloor || 0) || 0));

  // Birb normalizeState: run once per state object (the playtest calls it from X.questState)
  const normalized = new WeakMap();
  X.questState = function (s) {
    const e = PT.expState(s);
    if (e.questMerchant && normalized.get(e) === e.questMerchant && normalized.get(e.questStats) === e.questMerchant) return e.questMerchant;
    e.questStats = normStats(e.questStats);
    const t = e.questMerchant || {}, act = normIds(t.activeQuestIds), pin = normIds(t.pinnedQuestIds);
    const daily = normIds(t.dailyQuestIds || act.filter((id) => BY_ID[id].questType === "daily"), "daily").filter((id) => X.questVisible(s, BY_ID[id]));
    const comp = normIds(t.completedQuestIds);
    const main = [...new Set([...normIds(t.mainCompletedQuestIds, "main"), ...comp.filter((id) => BY_ID[id].questType === "main")])];
    const dComp = normIds(t.dailyCompletedQuestIds, "daily").filter((id) => daily.includes(id));
    const l = t.dailyCompletionCounts && typeof t.dailyCompletionCounts === "object" ? t.dailyCompletionCounts : {}, c = {};
    for (const d of DAILY) { const n = int0(l[d.id]); if (n > 0) c[d.id] = n; }
    for (const id of dComp) c[id] = Math.max(1, c[id] || 0);
    const cyc = Number(t.dailyCycle);
    const m = e.questMerchant = { activeQuestIds: [], completedQuestIds: [], pinnedQuestIds: [], dailyQuestIds: [], dailyCompletedQuestIds: [], dailyCompletionCounts: {}, mainCompletedQuestIds: [], dailySeed: 0, dailyCycle: -1,
      lastRefreshAt: 0, nextRefreshAt: 0, unlockedAt: 0, lastViewedAt: 0, ...t,
      activeQuestIds: act, completedQuestIds: [...main], pinnedQuestIds: pin, pinDefaultsInitialized: true, dailyQuestIds: daily, dailyCompletedQuestIds: dComp, dailyCompletionCounts: c,
      mainCompletedQuestIds: main, dailySeed: int0(t.dailySeed), dailyCycle: Number.isFinite(cyc) ? Math.floor(cyc) : -1, dailyBaselineStats: normStats(t.dailyBaselineStats),
      lastRefreshAt: int0(t.lastRefreshAt), nextRefreshAt: int0(t.nextRefreshAt), unlockedAt: int0(t.unlockedAt), lastViewedAt: int0(t.lastViewedAt) };
    if (m.rewardRulesVersion !== 2) { // the one-time move to reward rules v2
      m.mainRewardOverrides = {};
      for (const d of MAIN) if (m.mainCompletedQuestIds.includes(d.id)) m.mainRewardOverrides[d.id] = Math.max(d.rewardValue, OVERRIDES[d.id] || 0);
      m.rewardRulesVersion = 2; m.dailyRulesVersion = 1; m.legacyDailyBonuses = X.dailyBonuses(m.dailyCompletionCounts); m.flockOrders = {}; m.flockOrderHistory = [];
    }
    const fp = m.flockProgress; m.flockProgress = {};
    for (let i = 1; i <= 9; i++) m.flockProgress[i] = { normal: int0(fp?.[i]?.normal), elite: int0(fp?.[i]?.elite), deep: int0(fp?.[i]?.deep) };
    if (!m.flockFarmSamples || typeof m.flockFarmSamples !== "object") m.flockFarmSamples = {};
    m.flockOrders = {}; m.flockOrderHistory = []; // server orders are not issued today (see the file header)
    normalized.set(e, m); normalized.set(e.questStats, m);
    return m;
  };

  const metric = (st, d) => d.metric === KF ? int0(st.killsByFloor[d.floor || 1]) : d.metric === BC ? int0(st.bossClearsByFloor[d.floor || 1]) : d.metric === KT && d.enemyType ? int0(st.killsByEnemyType[d.enemyType]) : 0;
  X.questProgress = (s, d) => { const m = X.questState(s), n = metric(PT.expState(s).questStats, d); return d.questType !== "daily" ? n : Math.max(0, n - metric(m.dailyBaselineStats, d)); };
  X.questTarget = (s, d) => Math.max(1, d.questType === "daily" && X.questState(s).dailyRulesVersion === 1 ? V1_TARGETS[d.id] ?? d.target : d.target);
  X.questCompleted = (s, d) => { const m = X.questState(s); return d.questType === "main" ? m.mainCompletedQuestIds.includes(d.id) : m.dailyCompletedQuestIds.includes(d.id); };

  // Birb getBonus: completed main quests + every daily completion so far
  X.questMerchantBonus = function (s, stat) {
    const m = X.questState(s), done = new Set(m.mainCompletedQuestIds); let i = 0;
    for (const d of MAIN) if (done.has(d.id) && d.rewardStat === stat) i += Math.max(d.rewardValue, m.mainRewardOverrides?.[d.id] || 0);
    const a = m.dailyRulesVersion === 1 ? X.dailyBonuses(m.dailyCompletionCounts) : m.legacyDailyBonuses;
    return i + (a?.[stat] || 0);
  };
  X.questBonus = (s, stat) => X.questMerchantBonus(s, stat); // feeds X.externalBonuses
  PT.questBonus = (s, stat) => X.questMerchantBonus(s, stat); // feeds systems.js (seed / popcorn / feather / pickup) and the nest (twigs)
  // Birb tI: the server-wide flock community bonus on seeds (0 today; the playtest has no server)
  PT.flockCommunityMult = (s, now = Date.now()) => { const e = PT.expState(s).questMerchant?.flockCommunity; return e && now >= e.startsAt && now < e.endsAt && Number.isFinite(e.bonus) && e.bonus >= 0 ? 1 + e.bonus : 1; };

  X.questUnlocked = (s) => int0(X.questState(s).unlockedAt) > 0;
  const mixSeed = (e, t) => { const n = Math.max(1, Math.floor(Number(e) || 1)) >>> 0, i = (Math.max(0, Math.floor(Number(t) || 0)) + 1) >>> 0, a = (n ^ Math.imul(i, 2654435761)) >>> 0; return a > 0 ? a : 1; };
  const seeded = (e) => { let t = e >>> 0; return () => { t += 1831565813; let x = t; x = Math.imul(x ^ (x >>> 15), 1 | x); x ^= x + Math.imul(x ^ (x >>> 7), 61 | x); return ((x ^ (x >>> 14)) >>> 0) / 4294967296; }; };
  X.pickDailyQuests = function (s, seed, count) { // Birb pickDailyQuests (Birb always has order services, so the boss / witch filters apply)
    const bc = PT.expState(s).questStats.bossClearsByFloor;
    const n = DAILY.filter((d) => X.questVisible(s, d) && (d.family !== "boss_clear" || (bc[d.floor || 1] || 0) > 0) && (d.id !== "daily_hunt_witch" || (bc[2] || 0) > 0)), r = seeded(seed);
    for (let i = n.length - 1; i > 0; i -= 1) { const j = Math.floor(r() * (i + 1)), t = n[i]; n[i] = n[j]; n[j] = t; }
    const a = [];
    for (const fam of ["floor_kill", "enemy_hunt", "boss_clear"]) { const d = n.find((x) => x.family === fam); if (d) a.push(d); }
    for (const d of n) { if (a.length >= count) break; if (!a.includes(d)) a.push(d); }
    return a.slice(0, count).sort((x, y) => x.sortOrder - y.sortOrder);
  };
  const sortIds = (ids) => ids.sort((a, b) => (BY_ID[a]?.sortOrder || 0) - (BY_ID[b]?.sortOrder || 0));
  const ensureSeed = (m, now) => { if (int0(m.dailySeed) > 0) return false; const a = (Math.floor(now) ^ int0(m.unlockedAt) ^ Math.floor(2147483647 * Math.random())) >>> 0; m.dailySeed = a > 0 ? a : 1; return true; };
  const completeEligible = (s, m) => {
    const n = new Set(m.mainCompletedQuestIds), i = new Set(m.dailyCompletedQuestIds), a = { ...(m.dailyCompletionCounts || {}) }; let r = false;
    for (const id of m.activeQuestIds) {
      const d = BY_ID[id]; if (!d || X.questProgress(s, d) < X.questTarget(s, d)) continue;
      if (d.questType === "main") { if (!n.has(id)) { n.add(id); r = true; } continue; }
      if (i.has(id) || m.dailyRulesVersion === 2) continue;
      i.add(id); a[id] = int0(a[id]) + 1; r = true;
    }
    if (!r) return false;
    m.mainCompletedQuestIds = sortIds([...n]); m.dailyCompletedQuestIds = sortIds([...i]); m.dailyCompletionCounts = a; m.completedQuestIds = [...m.mainCompletedQuestIds];
    return true;
  };
  const shouldRefresh = (m, now) => m.dailyQuestIds.length <= 0 || m.nextRefreshAt <= 0 || now >= m.nextRefreshAt;
  const refreshDaily = (s, m, now) => {
    const n = Math.floor(now / DAY);
    if (m.dailyRulesVersion === 1) m.legacyDailyBonuses = X.dailyBonuses(m.dailyCompletionCounts);
    m.dailyRulesVersion = m.dailyRulesVersion === 2 ? 2 : 1; m.flockOrders = {};
    m.dailyQuestIds = X.pickDailyQuests(s, mixSeed(m.dailySeed, n), 3).map((d) => d.id); m.dailyCompletedQuestIds = []; m.dailyCycle = n;
    m.dailyBaselineStats = normStats(PT.expState(s).questStats); m.lastRefreshAt = now; m.nextRefreshAt = (n + 1) * DAY;
    rebuildActive(s, m);
  };
  const rebuildActive = (s, m) => {
    const t = [...new Set([...m.dailyQuestIds.filter((id) => BY_ID[id]?.questType === "daily" && X.questVisible(s, BY_ID[id])), ...MAIN.filter((d) => X.questVisible(s, d)).map((d) => d.id)])];
    const p = normIds(m.pinnedQuestIds), ch = t.length !== m.activeQuestIds.length || t.some((x, k) => m.activeQuestIds[k] !== x) || p.length !== (m.pinnedQuestIds || []).length || p.some((x, k) => m.pinnedQuestIds[k] !== x);
    if (ch) { m.activeQuestIds = t; m.pinnedQuestIds = p; } return ch;
  };
  const cleanupPins = (s, m) => { const a = new Set(m.activeQuestIds); const i = normIds(m.pinnedQuestIds).filter((id) => { const d = BY_ID[id]; return d && X.questVisible(s, d) && a.has(id) && !X.questCompleted(s, d) && X.questProgress(s, d) < X.questTarget(s, d); });
    const ch = i.length !== (m.pinnedQuestIds || []).length; m.pinnedQuestIds = i; return ch; };
  // Birb unlock / sync (the sunflower node d_desert_quest_merchant unlocks it)
  X.questSync = function (s, now = Date.now()) {
    const m = X.questState(s); let t = false;
    if (PT.hasSun(s, "d_desert_quest_merchant") && m.unlockedAt <= 0) { m.unlockedAt = now; t = true; }
    if (m.unlockedAt <= 0) return false;
    if (ensureSeed(m, now)) t = true;
    if (completeEligible(s, m)) t = true;
    if (shouldRefresh(m, now)) { refreshDaily(s, m, now); t = true; }
    if (rebuildActive(s, m)) t = true;
    if (completeEligible(s, m)) t = true;
    if (cleanupPins(s, m)) t = true;
    return t;
  };
  X.togglePinnedQuest = (s, id) => { const m = X.questState(s), d = BY_ID[id]; if (!d || !X.questVisible(s, d)) return false; const n = m.pinnedQuestIds || [];
    if (n.includes(id)) { m.pinnedQuestIds = n.filter((x) => x !== id); return true; }
    if (!m.activeQuestIds.includes(id) || X.questCompleted(s, d) || X.questProgress(s, d) >= X.questTarget(s, d)) return false; m.pinnedQuestIds = [...new Set([...n, id])]; return true; };
  X.questTimeUntilRefresh = (s, now = Date.now()) => Math.max(0, int0(X.questState(s).nextRefreshAt) - now);
  X.questCompletedCount = (s) => { const m = X.questState(s), t = new Set(m.dailyCompletedQuestIds), n = new Set(m.mainCompletedQuestIds);
    return m.dailyQuestIds.map((id) => BY_ID[id]).filter((d) => d && X.questVisible(s, d) && t.has(d.id)).length + MAIN.filter((d) => X.questVisible(s, d) && n.has(d.id)).length; };
  X.questTotalCount = (s) => X.questState(s).dailyQuestIds.map((id) => BY_ID[id]).filter((d) => d && X.questVisible(s, d)).length + MAIN.filter((d) => X.questVisible(s, d)).length;

  // Birb normalizeTrackedEnemyType + trackQuestKill (the mythic relic part lives in expedition_mythic.js)
  X.trackedEnemyType = (t) => (t.includes("masked-forest-spirit") ? "masked-forest-spirit" : t === "ice-harpy" ? "harpy" : TRACKED.find((x) => x === t) || null);
  X.trackQuestKill = function (s, run, floor, e, mapId) {
    if (X.onQuestKillPre) X.onQuestKillPre(s, run, e);
    if (e.type === "mini-fly") return;
    X.questState(s); const st = PT.expState(s).questStats, n = Math.max(1, Math.min(9, Math.floor(Number(floor) || 1)));
    if (!e.anubisSummon && !e.isBoss) { // Birb flock progress (feeds the server orders; tracked so saves match)
      const r = (X.questState(s).flockProgress[n] ||= { normal: 0, elite: 0, deep: 0 });
      if (e.isElite) r.elite++; else { r.normal++; if (X.depthRatio(mapId, e.originalX ?? e.x, e.originalY ?? e.y) >= 0.65) r.deep++; }
    }
    st.killsByFloor[n] = int0(st.killsByFloor[n]) + 1;
    if (e.isBoss) st.bossClearsByFloor[n] = int0(st.bossClearsByFloor[n]) + 1;
    if (n === 9 && e.type === "the-archivist") PT.expState(s).archivistDefeated = true;
    const a = X.trackedEnemyType(e.type); if (a) st.killsByEnemyType[a] = int0(st.killsByEnemyType[a]) + 1;
  };

  // sync about once a second, like Birb's UI loop
  const updOrig = X.update; let acc = 1;
  X.update = function (G, dt) { acc += dt; if (acc >= 1) { acc = 0; X.questSync(G.s); } return updOrig(G, dt); };
})();
