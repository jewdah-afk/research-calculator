// Peckwood playtest, Phase 2b: Aquarium and Fish Market, copied from Birb's aquariumManager (DF),
// the aquarium helpers in the editors bundle (Ku biomes, om milestones, bm points, Em tiers, vm shiny)
// and fishMarketManager (rR). Names follow Birb so the parity test can compare them.
"use strict";
(function () {
  const PT = window.PT;
  const FISH = PT.FISH, FISH_BY = PT.FISH_BY;
  const base = (id) => PT.baseFishId(id);
  const SHINY = "__shiny";

  // ------------------------------------------------------------------ data (Birb Ku, Vu, Hu, zu, Wu, om)
  PT.AQ_BIOMES = [
    { id: "coast", fishTypes: ["coastal"], modifierType: "seed_mult", color: "#38bdf8" },
    { id: "reef", fishTypes: ["reef", "exotic_reef"], modifierType: "popcorn_mult", color: "#fb7185" },
    { id: "freshwater", fishTypes: ["freshwater", "river"], modifierType: "xp_mult", color: "#34d399" },
    { id: "ocean", fishTypes: ["ocean"], modifierType: "reel_speed_mult", color: "#2563eb" },
    { id: "abyssal", fishTypes: ["abyssal"], modifierType: "golden_popcorn_mult", color: "#8b5cf6" },
    { id: "creatures", fishTypes: ["creature", "crab"], modifierType: "pickup_mult", color: "#f97316" },
    { id: "mystic", fishTypes: ["spirit", "cosmic"], modifierType: "feather_mult", color: "#c084fc" },
    { id: "mechanical", fishTypes: ["mechanical"], modifierType: "speed_mult", color: "#94a3b8" },
    { id: "expedition", fishTypes: ["expedition"], modifierType: "parrot_damage_mult", color: "#f59e0b" },
  ];
  const RARITY_POINTS = { common: 1, uncommon: 2, rare: 3, epic: 4, legendary: 5, mythic: 6 };
  const HOUSED_SHINY = { common: 0.001, uncommon: 0.002, rare: 0.004, epic: 0.01, legendary: 0.02, mythic: 0.03 };
  const TIERS = [0.25, 0.5, 0.75, 1];
  const TIER_BONUS = 0.02; // every biome: +2% per tier
  PT.AQ_MILESTONES = [
    { id: "third_buff_slot", points: 10, title: "Extra Course", text: "+1 fish buff slot", rewardType: "fish_buff_slot", rewardValue: 1 },
    { id: "shiny_current_surge", points: 50, title: "Current Surge", text: "Shiny chance x1.2", rewardType: "shiny_chance_mult", rewardValue: 1.2 },
    { id: "glass_tide", points: 120, title: "Glass Tide", text: "Shiny fish buffs last 12h longer", rewardType: "shiny_buff_duration_hours", rewardValue: 12 },
    { id: "deep_resonance", points: 250, title: "Deep Resonance", text: "+1% shiny chance per housed species", rewardType: "shiny_chance_per_fish", rewardValue: 0.01 },
    { id: "aquarium_harmony", points: 450, title: "Aquarium Harmony", text: "Normal fish buffs x1.25", rewardType: "normal_fish_buff_mult", rewardValue: 1.25 },
    { id: "fish_market", points: 700, title: "Fish Market", text: "Opens the Fish Market", rewardType: "fish_market", rewardValue: 1 },
    { id: "market_rerolls", points: 900, title: "Market Rerolls", text: "3 contract rerolls per day", rewardType: "fish_market_rerolls", rewardValue: 3 },
    { id: "nest_fish_breeding", points: 600, title: "Fish Breeding", text: "Unlocks fish breeding in the Nest", rewardType: "nest_fish_breeding", rewardValue: 1 },
  ];
  const BIOME_OF_TYPE = new Map(PT.AQ_BIOMES.flatMap((b) => b.fishTypes.map((t) => [t, b])));
  const BIOME_TOTAL = new Map(PT.AQ_BIOMES.map((b) => [b.id, FISH.filter((f) => f.type && b.fishTypes.includes(f.type)).length]));
  const REF_RANGE = { coastal: [0.1, 2], reef: [0.2, 3], freshwater: [0.15, 2.5], river: [0.2, 4], ocean: [0.5, 50], creature: [0.05, 5], exotic_reef: [0.3, 4], spirit: [0.01, 1], cosmic: [0.1, 3], mechanical: [1, 20], crab: [0.1, 5], abyssal: [0.3, 15], expedition: [0.3, 6] };
  const REF_RAR = { common: 1, uncommon: 1.5, rare: 2.5, epic: 4, legendary: 8, mythic: 12 };

  // ------------------------------------------------------------------ state + helpers
  PT.aq = function (s) {
    const a = s.aquarium || (s.aquarium = { activeBiomeId: "coast", housedFish: {}, researchedFishCounts: {}, releasedShinyFishes: {}, releasedShinyWeightsKg: {} });
    a.housedFish ||= {}; a.researchedFishCounts ||= {}; a.releasedShinyFishes ||= {}; a.releasedShinyWeightsKg ||= {};
    if (!PT.AQ_BIOMES.some((b) => b.id === a.activeBiomeId)) a.activeBiomeId = "coast";
    return a;
  };
  PT.AQUARIUM_MAP = 22; PT.FISH_MARKET_MAP = 24;
  PT.aquariumUnlocked = (s) => s.aquarium?.unlocked === true || Math.max(0, Math.floor(s.evolutionCount || 0)) >= 5; // Birb xd
  const research = (a, id) => { const n = Number(a?.researchedFishCounts?.[base(id)] || 0); return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0; };
  PT.aqShinyStored = (a, id) => a?.releasedShinyFishes?.[base(id)] === true; // Birb um
  PT.aqHoused = (a, id) => a?.housedFish?.[base(id)] === true || PT.aqShinyStored(a, id) || research(a, id) > 0; // Birb mm
  PT.aqHousedCount = (a) => FISH.reduce((n, f) => n + (PT.aqHoused(a, f.id) ? 1 : 0), 0);
  PT.aqShinyCount = (a) => FISH.reduce((n, f) => n + (PT.aqShinyStored(a, f.id) ? 1 : 0), 0);
  PT.aqPoints = (a) => FISH.reduce((n, f) => (PT.aqHoused(a, f.id) ? n + RARITY_POINTS[f.rarity] * (PT.aqShinyStored(a, f.id) ? 2 : 1) : n), 0); // resonance (Birb bm)
  PT.aqBiome = function (a, id) { // Birb Em
    const b = PT.AQ_BIOMES.find((x) => x.id === id), total = BIOME_TOTAL.get(id) || 0;
    if (!b || total <= 0) return { biomeId: id, housedSpecies: 0, totalSpecies: 0, shinySpecies: 0, completionRatio: 0, tierCount: 0, maxTierCount: TIERS.length + 1, isPrestiged: false };
    let h = 0, sh = 0;
    for (const f of FISH) if (f.type && b.fishTypes.includes(f.type) && PT.aqHoused(a, f.id)) { h++; if (PT.aqShinyStored(a, f.id)) sh++; }
    const r = Math.min(1, h / total), t = TIERS.reduce((n, x) => n + (r >= x ? 1 : 0), 0), pre = h === total && sh === total;
    return { biomeId: id, housedSpecies: h, totalSpecies: total, shinySpecies: sh, completionRatio: r, baseTierCount: t, tierCount: t + (pre ? 1 : 0), maxTierCount: TIERS.length + 1, isPrestiged: pre };
  };
  PT.aqBiomeBuff = (a, id) => PT.aqBiome(a, id).tierCount * TIER_BONUS; // Birb Cm
  const modSum = (a, type) => PT.AQ_BIOMES.reduce((n, b) => (b.modifierType === type ? n + PT.aqBiomeBuff(a, b.id) : n), 0); // Birb Sm
  const housedShiny = (a) => FISH.reduce((n, f) => (PT.aqHoused(a, f.id) ? n + HOUSED_SHINY[f.rarity] * (PT.aqShinyStored(a, f.id) ? 2 : 1) : n), 0); // Birb Bm
  PT.aqMilestones = function (a) { // Birb ym
    const pts = PT.aqPoints(a), legacy = Math.max(0, Math.min(PT.AQ_MILESTONES.length, Math.floor(Number(a?.legacyResonanceMilestoneCount) || 0)));
    return PT.AQ_MILESTONES.filter((m, i) => i < legacy || pts >= m.points);
  };
  const buffMult = (a) => PT.aqMilestones(a).reduce((t, m) => (m.rewardType === "aquarium_buff_mult" ? t * Math.max(1, m.rewardValue) : t), 1); // Birb Mm
  PT.aqNormalBuffMult = (s) => PT.aqMilestones(PT.aq(s)).reduce((t, m) => (m.rewardType === "normal_fish_buff_mult" ? t * Math.max(1, m.rewardValue) : t), 1); // Birb Im
  PT.aqShinyBuffMs = (s) => PT.aqMilestones(PT.aq(s)).reduce((t, m) => (m.rewardType === "shiny_buff_duration_hours" ? t + 3600e3 * Math.max(0, m.rewardValue) : t), 864e5); // Birb Tm
  PT.aqBuffSlots = (s) => PT.aqMilestones(PT.aq(s)).filter((m) => m.rewardType === "fish_buff_slot").reduce((n, m) => n + Math.max(0, Math.floor(m.rewardValue)), 0);
  PT.aqRefWeight = function (s, id) { // Birb getReferenceWeightKg + rm
    const r = (s.fishWeightRecords || []).find((e) => e.fishId === base(id));
    if (r && r.weightKg > 0) return r.weightKg;
    const f = FISH_BY.get(base(id)); if (!f) return 1;
    if (typeof f.minWeightKg === "number" && typeof f.maxWeightKg === "number") return Math.max(0.05, (f.minWeightKg + f.maxWeightKg) / 2);
    const t = REF_RANGE[f.type || (f.id.startsWith("exp_") ? "expedition" : "coastal")] || REF_RANGE.coastal; // Birb's fish table types expedition fish as "expedition"
    return Math.max(0.05, ((t[0] + t[1]) / 2) * (REF_RAR[f.rarity] || 1));
  };
  PT.aqWeightBonus = (kg) => (!Number.isFinite(kg) || kg <= 0 ? 0 : (kg / 100) * 0.01); // Birb gm
  PT.aqStoredShinyBonus = (s) => Object.entries(PT.aq(s).releasedShinyFishes).reduce((n, [id, v]) => (v === true ? n + PT.aqWeightBonus(PT.aqRefWeight(s, id)) : n), 0);
  PT.aqShinyChanceMult = function (s) { // Birb getShinyChanceMultiplier = vm + stored shiny bonus
    const a = PT.aq(s), housed = PT.aqHousedCount(a);
    let t = 1;
    for (const m of PT.aqMilestones(a)) {
      if (m.rewardType === "shiny_chance_mult") t *= m.rewardValue;
      if (m.rewardType === "shiny_chance_per_fish") t *= 1 + Math.max(0, m.rewardValue) * housed;
    }
    return 1 + (Math.max(0, t - 1) + housedShiny(a)) * buffMult(a) + PT.aqStoredShinyBonus(s) * buffMult(a);
  };
  PT.aqModifier = function (s, type) { // Birb getModifierMultiplier
    if (type === "sell_mult") return 1;
    const a = PT.aq(s);
    let n = modSum(a, type);
    for (const m of PT.aqMilestones(a)) if (m.rewardType === type) n += Math.max(0, m.rewardValue - 1);
    return 1 + n * buffMult(a);
  };
  PT.fishMarketUnlocked = (s) => Number(s.aquarium?.market?.unlockedAt || 0) > 0 || PT.aqMilestones(PT.aq(s)).some((m) => m.rewardType === "fish_market"); // Birb Rm

  // ------------------------------------------------------------------ donating (Birb getDonatePreviewFromContext / donateFish / donateAllFish)
  PT.aqDonatePreview = function (s, id, shiny) {
    const a = PT.aq(s), fid = base(id), f = FISH_BY.get(fid), inv = shiny ? fid + SHINY : fid;
    const have = (s.fishInventory || []).find((r) => r.fishId === inv)?.count || 0;
    const reserved = shiny ? 0 : PT.reservedFish(s, fid), usable = Math.max(0, have - reserved);
    const was = PT.aqHoused(a, fid), wasShiny = PT.aqShinyStored(a, fid), rp = f ? RARITY_POINTS[f.rarity] : 0;
    const before = was ? rp * (wasShiny ? 2 : 1) : 0, after = shiny ? Math.max(before, 2 * rp) : Math.max(before, rp);
    const p = { fishId: fid, shiny, inventoryFishId: inv, availableCount: have, usableCount: usable, pointsGain: Math.max(0, after - before), canDonate: false };
    if (!f) return { ...p, reason: "Unknown fish" };
    if ((s.lockedFish || []).includes(inv)) return { ...p, reason: "Fish is locked" };
    if (s.currentMap !== PT.AQUARIUM_MAP) return { ...p, reason: "Travel to the Aquarium to donate" };
    if (shiny ? wasShiny : was) return { ...p, reason: shiny ? "Shiny already donated" : "Already housed" };
    if (usable <= 0) return { ...p, reason: !shiny && have > 0 && reserved >= have ? "No safe extra copies" : shiny ? "No shiny copies owned" : "No copies owned" };
    return { ...p, canDonate: true };
  };
  function takeOne(s, inv) {
    const row = (s.fishInventory || []).find((r) => r.fishId === inv); if (!row || row.count < 1) return false;
    row.count -= 1; s.fishInventory = s.fishInventory.filter((r) => r.count > 0); return true;
  }
  PT.aqDonate = function (s, id, shiny) {
    const p = PT.aqDonatePreview(s, id, shiny); if (!p.canDonate) return p.reason;
    const before = PT.aqPoints(PT.aq(s));
    if (!takeOne(s, p.inventoryFishId)) return "Donate failed";
    const a = PT.aq(s); a.housedFish[p.fishId] = true; if (shiny) a.releasedShinyFishes[p.fishId] = true;
    PT.marketGrantRerolls(s, before, PT.aqPoints(a));
    return "";
  };
  PT.aqDonateAllPreview = (s) => FISH.map((f) => PT.aqDonatePreview(s, f.id, false)).filter((p) => p.canDonate);
  PT.aqDonateAll = function (s) {
    const list = PT.aqDonateAllPreview(s); if (!list.length) return "Nothing to donate";
    const a = PT.aq(s), before = PT.aqPoints(a);
    for (const p of list) if (takeOne(s, p.inventoryFishId)) a.housedFish[p.fishId] = true;
    PT.marketGrantRerolls(s, before, PT.aqPoints(a));
    return `Donated ${list.length} species`;
  };

  // ------------------------------------------------------------------ Fish Market (Birb rR)
  const DAY = 864e5, OFFERS = 3, ABANDON_CD = 108e5;
  const REP_LEVELS = [0, 100, 300, 650, 1100, 1700, 2500, 3500, 4700, 6200];
  const PARROT_BUFFS = ["expedition_damage_mult", "expedition_hp_mult", "expedition_life_regen_mult", "expedition_move_speed_mult", "expedition_attack_speed_mult", "expedition_skill_point_mult", "expedition_chest_reward_mult"];
  PT.MARKET_BUFFS = [...PARROT_BUFFS, "reel_speed_mult", "xp_mult", "fishing_luck_mult", "shiny_chance_mult"];
  PT.MARKET_RARITY = { common: { value: 0.35, durationMs: 144e5 }, uncommon: { value: 0.5, durationMs: 216e5 }, rare: { value: 0.75, durationMs: 288e5 }, epic: { value: 1.1, durationMs: 432e5 }, legendary: { value: 1.65, durationMs: 648e5 } };
  const RARS = ["common", "uncommon", "rare", "epic", "legendary"];
  const NORMAL_COUNT = { common: 90, uncommon: 55, rare: 25, epic: 10, legendary: 3, mythic: 1 };
  const SHINY_COUNT = { common: 4, uncommon: 3, rare: 2, epic: 1, legendary: 1, mythic: 1 };
  const REP_PER = { common: 60, uncommon: 95, rare: 150, epic: 240, legendary: 380, mythic: 600 };
  const RAR_BY_LEVEL = [
    { common: 70, uncommon: 30, rare: 0, epic: 0, legendary: 0 }, { common: 55, uncommon: 37, rare: 8, epic: 0, legendary: 0 },
    { common: 40, uncommon: 40, rare: 18, epic: 2, legendary: 0 }, { common: 28, uncommon: 38, rare: 27, epic: 7, legendary: 0 },
    { common: 20, uncommon: 32, rare: 34, epic: 12, legendary: 2 }, { common: 14, uncommon: 26, rare: 38, epic: 18, legendary: 4 },
    { common: 10, uncommon: 21, rare: 38, epic: 25, legendary: 6 }, { common: 8, uncommon: 18, rare: 36, epic: 30, legendary: 8 },
    { common: 6, uncommon: 15, rare: 34, epic: 34, legendary: 11 }, { common: 5, uncommon: 13, rare: 31, epic: 36, legendary: 15 },
  ];
  const SLOT_BIAS = [
    { common: 1.25, uncommon: 1.1, rare: 0.75, epic: 0.45, legendary: 0.25 }, { common: 1, uncommon: 1, rare: 1, epic: 1, legendary: 1 },
    { common: 0.45, uncommon: 0.75, rare: 1.35, epic: 1.9, legendary: 2.4 },
  ];
  const TYPES_PER = { common: { min: 1, max: 1, extra: 0 }, uncommon: { min: 1, max: 2, extra: 0.45 }, rare: { min: 2, max: 3, extra: 0.2 }, epic: { min: 2, max: 3, extra: 0.65 }, legendary: { min: 3, max: 3, extra: 0 } };
  const SHINY_REQ_CHANCE = { common: 0.08, uncommon: 0.12, rare: 0.2, epic: 0.3, legendary: 0.4 };
  const MAX_SHINY_REQ = { common: 1, uncommon: 1, rare: 1, epic: 2, legendary: 2 };
  const VALUE_BY_BUFF = { reel_speed_mult: 1.05, xp_mult: 1.1, fishing_luck_mult: 1.15, shiny_chance_mult: 0.9, expedition_damage_mult: 1.1, expedition_hp_mult: 1.1, expedition_life_regen_mult: 1.2, expedition_move_speed_mult: 0.8, expedition_attack_speed_mult: 0.9, expedition_skill_point_mult: 1.15, expedition_chest_reward_mult: 1.15 };
  const DURATION_BY_BUFF = { fishing_luck_mult: 0.9, shiny_chance_mult: 0.85, expedition_move_speed_mult: 0.9, expedition_attack_speed_mult: 0.9, expedition_skill_point_mult: 0.9, expedition_chest_reward_mult: 0.9 };
  const rIdx = (r) => (r === "mythic" ? RARS.length : Math.max(0, RARS.indexOf(r)));
  const lowRar = (r) => r === "common" || r === "uncommon";
  const reqInv = (q) => (q.shiny ? q.fishId + SHINY : q.fishId);
  const pickRar = (rng, w) => { const t = RARS.reduce((n, r) => n + Math.max(0, w[r] || 0), 0); if (t <= 0) return "common"; let x = rng() * t; for (const r of RARS) { x -= Math.max(0, w[r] || 0); if (x <= 0) return r; } return "common"; };
  function rngFrom(seed) { let t = seed >>> 0; return () => { t = (t + 1831565813) >>> 0; let e = t; e = Math.imul(e ^ (e >>> 15), 1 | e); e ^= e + Math.imul(e ^ (e >>> 7), 61 | e); return ((e ^ (e >>> 14)) >>> 0) / 4294967296; }; }

  PT.market = function (s, now = 0) {
    const a = PT.aq(s);
    if (!a.market || typeof a.market !== "object") { const c = now > 0 ? Math.floor(now / DAY) : 0;
      a.market = { unlockedAt: 0, dailySeed: 0, dailyCycle: c, rerollIndex: 0, lastRefreshAt: 0, nextRefreshAt: c > 0 ? (c + 1) * DAY : 0, rerollsRemaining: 0, parrotOffers: [], activeParrotBuffs: {}, contractOffers: [], acceptedContracts: [], pinnedContractIds: [], contractReputationXp: 0, contractAcceptCooldownUntil: 0, activeContractBuffs: {}, oddKeyPurchased: false, nextCollectionStageUnlocked: false }; }
    return a.market;
  };
  PT.repLevel = (xp) => { const t = Math.max(0, Math.floor(Number(xp) || 0)); let n = 1; for (let i = 0; i < REP_LEVELS.length; i++) if (t >= REP_LEVELS[i]) n = i + 1; return n; };
  PT.repProgress = function (s) { const xp = PT.market(s).contractReputationXp, L = PT.repLevel(xp), cur = REP_LEVELS[L - 1] || 0, next = REP_LEVELS[L] ?? null; return { level: L, xp, current: cur, next, progress: next === null ? 1 : Math.max(0, Math.min(1, (xp - cur) / Math.max(1, next - cur))) }; };
  PT.contractSlots = (s) => { const L = PT.repLevel(PT.market(s).contractReputationXp); return L >= 5 ? 4 : L >= 3 ? 3 : 2; };
  PT.marketRerollsUnlocked = (s) => { const m = PT.aqMilestones(PT.aq(s)).find((x) => x.rewardType === "fish_market_rerolls"); return m ? Math.max(0, Math.floor(m.rewardValue)) : 0; };
  PT.marketGrantRerolls = function (s, before, after) { // Birb grantRerollsForPointsMilestone
    const need = PT.AQ_MILESTONES.find((m) => m.rewardType === "fish_market_rerolls").points;
    if (before >= need || after < need) return 0;
    const m = PT.market(s, Date.now()), o = m.rerollsRemaining; m.rerollsRemaining = Math.max(m.rerollsRemaining, PT.marketRerollsUnlocked(s)); return m.rerollsRemaining - o;
  };
  const discovered = (s, shiny) => { const set = new Set(shiny ? s.discoveredShinyFish || [] : s.discoveredFish || []);
    for (const r of s.fishInventory || []) if (shiny ? PT.isShiny(r.fishId) : !PT.isShiny(r.fishId)) set.add(base(r.fishId));
    return FISH.filter((f) => set.has(f.id) && f.rarity !== "mythic"); };
  function pickRarities(rng, L, n) {
    const w = RAR_BY_LEVEL[Math.max(0, Math.min(RAR_BY_LEVEL.length - 1, L - 1))], out = [];
    for (let i = 0; i < n; i++) { const b = SLOT_BIAS[Math.min(i, SLOT_BIAS.length - 1)]; out.push(pickRar(rng, RARS.reduce((o, r) => ((o[r] = w[r] * b[r]), o), {}))); }
    if (L >= 4 && Math.max(...out.map(rIdx)) < rIdx("rare")) out[out.length - 1] = "rare";
    if (L >= 7 && Math.max(...out.map(rIdx)) < rIdx("epic") && rng() < 0.35) out[out.length - 1] = "epic";
    return out;
  }
  function typeCount(r, L, rng) { const t = TYPES_PER[r]; let a = t.min; if (t.max > t.min && rng() < t.extra) a++; if (r === "rare" && L >= 6 && rng() < 0.25) a++; return Math.max(t.min, Math.min(t.max, a)); }
  function pickFish(list, rng, L, boost, r) {
    if (!list.length) return null;
    const k = rIdx(r), w = list.map((f) => { const t = rIdx(f.rarity); return Math.max(0.05, Math.max(0.25, 1.65 - 0.35 * Math.abs(t - k)) * (1 + t * (boost ? 0.55 : 0.18) + Math.min(8, Math.max(0, L - 1)) * t * 0.045) * (t > k + 1 ? 0.35 : 1) * (t + 2 < k ? 0.65 : 1)); });
    let x = rng() * w.reduce((a, b) => a + b, 0);
    for (let i = 0; i < list.length; i++) { x -= w[i]; if (x <= 0) return list[i]; }
    return list[list.length - 1];
  }
  function countFor(f, shiny, rng, L, r, n) {
    const o = shiny ? SHINY_COUNT[f.rarity] : NORMAL_COUNT[f.rarity], l = 0.75 + 0.75 * rng(), c = rIdx(r);
    if (shiny) { const e = 1 + 0.12 * Math.max(0, c - rIdx(f.rarity)), cap = lowRar(r) ? 3 : c === 2 ? 4 : c === 3 ? 5 : 6; return Math.min(cap, Math.max(1, Math.floor(o * l * e))); }
    return Math.max(1, Math.floor(o * l * (1 + 0.08 * Math.min(8, Math.max(0, L - 1))) * (1 + 0.16 * c) * (n <= 1 ? 1 : n === 2 ? 0.82 : 0.68)));
  }
  function buildReqs(rng, L, r, normal, shinyList) {
    const n = Math.min(new Set([...normal, ...shinyList].map((f) => f.id)).size, typeCount(r, L, rng)), out = [], used = new Set();
    let sc = 0; const maxS = MAX_SHINY_REQ[r];
    for (let u = 0; u < n; u++) {
      const sh = shinyList.filter((f) => !used.has(f.id)), no = normal.filter((f) => !used.has(f.id));
      const p = Math.min(0.6, SHINY_REQ_CHANCE[r] + 0.025 * Math.min(8, Math.max(0, L - 1)) + 0.04 * u);
      let m = sc < maxS && sh.length > 0 && rng() < p, g = pickFish(m ? sh : no, rng, L, m || u > 0, r);
      if (!g) { m = false; g = pickFish(no, rng, L, u > 0, r); }
      if (!g) continue;
      used.add(g.id); if (m) sc++;
      out.push({ fishId: g.id, count: countFor(g, m, rng, L, r, n), shiny: m });
    }
    return out;
  }
  PT.contractValue = (buff, r, L, reqs) => Number((PT.MARKET_RARITY[r].value * (VALUE_BY_BUFF[buff] ?? 1) * (1 + 0.045 * Math.min(8, Math.max(0, L - 1))) * (1 + 0.08 * Math.max(0, reqs.length - 1) + 0.12 * reqs.filter((q) => q.shiny).length)).toFixed(4));
  PT.contractDuration = (buff, r, L, reqs) => Math.floor(PT.MARKET_RARITY[r].durationMs * (DURATION_BY_BUFF[buff] ?? 1) * (1 + 0.035 * Math.min(8, Math.max(0, L - 1))) * (1 + 0.14 * Math.max(0, reqs.length - 1) + 0.12 * reqs.filter((q) => q.shiny).length));
  PT.contractRep = (reqs, r, L) => Math.max(1, Math.floor(0.5 * (REP_PER[r] + reqs.reduce((n, q) => n + REP_PER[FISH_BY.get(q.fishId)?.rarity || "common"] * (q.shiny ? 2.4 : 1), 0)) * (1 + 0.06 * Math.min(6, Math.max(0, L - 1)))));
  PT.generateContracts = function (s, cycle, reroll) { // Birb generateContractOffers (seeded, so Birb and the playtest roll the same offers)
    const m = PT.market(s), seed = (2654435761 * (cycle + 1) + 101 * PT.aqPoints(PT.aq(s)) + 9973 * reroll + 789882) >>> 0, rng = rngFrom(seed);
    const L = PT.repLevel(m.contractReputationXp), normal = discovered(s, false), shiny = discovered(s, true), out = [], rars = pickRarities(rng, L, OFFERS);
    for (let d = 0; d < OFFERS && normal.length > 0; d++) {
      const r = rars[d] || "common", reqs = buildReqs(rng, L, r, normal, shiny);
      if (!reqs.length) continue;
      const buff = PT.MARKET_BUFFS[Math.floor(rng() * PT.MARKET_BUFFS.length)];
      out.push({ id: `fc_${cycle}_${reroll}_${d}_${reqs.map((q) => `${q.shiny ? "s" : "n"}_${q.fishId}_${q.count}`).join("__")}_${buff}_${r}`, cycle, requirements: reqs,
        reward: { reputation: PT.contractRep(reqs, r, L), buffType: buff, value: PT.contractValue(buff, r, L, reqs), durationMs: PT.contractDuration(buff, r, L, reqs), rarity: r } });
    }
    m.dailySeed = seed; m.contractOffers = out;
    return out;
  };
  PT.marketSync = function (s, now = Date.now()) { // Birb sync + refreshContractOffersIfNeeded + prune
    if (!PT.fishMarketUnlocked(s)) return;
    const m = PT.market(s, now); if (!m.unlockedAt) m.unlockedAt = now;
    const cycle = Math.floor(now / DAY), last = cycle * DAY, next = (cycle + 1) * DAY;
    const empty = m.contractOffers.length === 0 && m.acceptedContracts.length === 0 && (m.dailySeed <= 0 || m.parrotOffers.length > 0);
    if (m.dailyCycle !== cycle || empty) { m.dailyCycle = cycle; m.rerollIndex = 0; m.lastRefreshAt = last; m.nextRefreshAt = next; m.rerollsRemaining = PT.marketRerollsUnlocked(s); m.parrotOffers = []; PT.generateContracts(s, cycle, 0); }
    else { m.lastRefreshAt = last; m.nextRefreshAt = next; }
    for (const k of Object.keys(m.activeContractBuffs)) { const l = m.activeContractBuffs[k].filter((b) => b.expiresAt > now); if (l.length) m.activeContractBuffs[k] = l; else delete m.activeContractBuffs[k]; }
  };
  PT.marketReroll = function (s) { const m = PT.market(s, Date.now()); if (m.rerollsRemaining <= 0) return "No rerolls left"; m.rerollsRemaining--; m.rerollIndex++; PT.generateContracts(s, m.dailyCycle, m.rerollIndex); return ""; };
  PT.contractBuffCount = (s, now = Date.now()) => Object.values(PT.market(s).activeContractBuffs).reduce((n, l) => n + l.filter((b) => b.expiresAt > now && b.value > 0).length, 0);
  const owned = (s, q) => ((s.lockedFish || []).includes(reqInv(q)) ? 0 : (s.fishInventory || []).find((r) => r.fishId === reqInv(q))?.count || 0);
  PT.contractOwned = owned;
  PT.acceptContract = function (s, id) {
    PT.marketSync(s); const now = Date.now(), m = PT.market(s, now);
    if (m.contractAcceptCooldownUntil > now) return "Contract cooldown";
    if (m.acceptedContracts.length >= PT.contractSlots(s)) return "Contract slots full";
    if (m.acceptedContracts.some((c) => c.id === id)) return "Already accepted";
    const i = m.contractOffers.findIndex((c) => c.id === id); if (i < 0) return "Contract expired";
    const c = JSON.parse(JSON.stringify(m.contractOffers[i])); c.acceptedAt = now;
    m.contractOffers.splice(i, 1); m.acceptedContracts.push(c); return "";
  };
  PT.abandonContract = function (s, id) {
    const now = Date.now(), m = PT.market(s, now), i = m.acceptedContracts.findIndex((c) => c.id === id); if (i < 0) return "Contract expired";
    m.acceptedContracts.splice(i, 1); m.pinnedContractIds = m.pinnedContractIds.filter((x) => x !== id); m.contractAcceptCooldownUntil = now + ABANDON_CD; return "";
  };
  PT.claimContract = function (s, id) { // the playtest replaces nothing when buff slots are full (Birb asks which buff to swap)
    PT.marketSync(s); const now = Date.now(), m = PT.market(s, now), i = m.acceptedContracts.findIndex((c) => c.id === id);
    if (i < 0) return "Contract expired";
    if (PT.contractBuffCount(s, now) >= PT.contractSlots(s)) return "Active contract buffs full";
    const c = m.acceptedContracts[i];
    if (!c.requirements.every((q) => owned(s, q) >= q.count)) return "Missing fish";
    for (const q of c.requirements) { const r = s.fishInventory.find((x) => x.fishId === reqInv(q)); if (r) r.count = Math.max(0, r.count - q.count); }
    s.fishInventory = s.fishInventory.filter((r) => r.count > 0);
    m.contractReputationXp = Math.max(0, Math.floor(m.contractReputationXp || 0)) + c.reward.reputation;
    (m.activeContractBuffs[c.reward.buffType] ||= []).push({ value: c.reward.value, expiresAt: now + c.reward.durationMs, sourceContractId: c.id, rarity: c.reward.rarity });
    m.acceptedContracts.splice(i, 1); m.pinnedContractIds = m.pinnedContractIds.filter((x) => x !== id);
    return "";
  };
  PT.contractBonus = function (s, type, now = Date.now()) { // Birb getActiveContractBuffBonus
    const l = s.aquarium?.market?.activeContractBuffs?.[type] || [];
    return l.reduce((n, b) => (b && b.expiresAt > now ? n + Math.max(0, Number(b.value) || 0) : n), 0);
  };
})();
