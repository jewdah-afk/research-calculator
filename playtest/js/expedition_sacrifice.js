// Peckwood playtest - Phase 6b: the Sacrifice Room (Birb map 8, left of the Expedition hub).
// Sacrifice available skill points toward 18 milestone tiers. Each tier sets aura quantity / chance,
// skill point, popcorn and seed multipliers, parrot radius and attack / move speed, and an aura rarity
// promotion chance. Tiers I-III are open, IV-VI need the expansion (50 Spirit Aura at tier III),
// parrot rebirb 1 opens all 18. Numbers copied from Birb (Ly, fI.COMMON_SACRIFICE_*).
(function () {
  const PT = window.PT, X = PT.EXP;
  PT.SACRIFICE_MAP = 8;
  PT.MAPS[8] = { id: 8, key: "expedition-sacrifice-room", name: "SACRIFICE ROOM", w: 1056, h: 792 };

  const BASE = { auraQuantityMultiplier: 1, auraChanceMultiplier: 1, skillPointMultiplier: 1, popcornMultiplier: 1, seedMultiplier: 1,
    parrotRadiusMultiplier: 1, parrotAttackSpeedMultiplier: 1, parrotMoveSpeedMultiplier: 1, auraRarityPromotionChance: 0 };
  // label, cost, aura qty, aura chance, SP, popcorn, seed, radius, attack/move speed, promotion
  const ROWS = [
    ["I", 450, 1.1, 1.1, 1, 1, 1, 1, 1, 0], ["II", 1e4, 1.1, 1.1, 2, 1, 1, 1, 1, 0], ["III", 1e5, 1.1, 1.1, 2, 2, 2, 1, 1, 0],
    ["IV", 25e4, 1.2, 1.2, 2, 2, 2, 1.1, 1, 0], ["V", 5e5, 1.2, 1.2, 2, 3, 3, 1.1, 1, 0], ["VI", 1e6, 1.2, 1.2, 3, 3, 3, 1.1, 1, 0],
    ["VII", 5e6, 1.3, 1.3, 3, 3, 3, 1.1, 1, 0.03], ["VIII", 1e7, 1.3, 1.3, 5, 5, 5, 1.1, 1, 0.03], ["IX", 25e6, 1.3, 1.3, 5, 5, 5, 1.2, 1, 0.03],
    ["X", 2e8, 1.4, 1.35, 5, 5, 5, 1.2, 1, 0.05], ["XI", 2e9, 1.4, 1.35, 8, 5, 5, 1.2, 1, 0.05], ["XII", 2e10, 1.4, 1.35, 8, 8, 8, 1.2, 1, 0.05],
    ["XIII", 2e11, 1.5, 1.4, 8, 8, 8, 1.2, 1, 0.07], ["XIV", 2e12, 1.5, 1.4, 8, 8, 8, 1.3, 1, 0.07], ["XV", 2e13, 1.5, 1.4, 8, 8, 8, 1.3, 1.2, 0.07],
    ["XVI", 1e14, 1.6, 1.5, 8, 8, 8, 1.3, 1.2, 0.1], ["XVII", 3e14, 1.6, 1.5, 12, 12, 12, 1.3, 1.2, 0.1], ["XVIII", 1e15, 1.6, 1.5, 16, 16, 16, 1.3, 1.2, 0.1],
  ];
  const TIERS = ROWS.map(([label, cost, q, c, sp, pop, seed, rad, spd, promo]) => ({ ...BASE, label, cost, auraQuantityMultiplier: q, auraChanceMultiplier: c,
    skillPointMultiplier: sp, popcornMultiplier: pop, seedMultiplier: seed, parrotRadiusMultiplier: rad, parrotAttackSpeedMultiplier: spd, parrotMoveSpeedMultiplier: spd, auraRarityPromotionChance: promo }));
  const THRESH = TIERS.reduce((a, t) => (a.push((a[a.length - 1] || 0) + t.cost), a), []);
  X.SACRIFICE_TIERS = TIERS; X.SACRIFICE_THRESHOLDS = THRESH;
  const EXPANSION_COST = 50;

  X.sacState = function (s) {
    const e = PT.expState(s), q = e.sacrifice || (e.sacrifice = {});
    q.skillPointsSacrificed ??= 0; q.commonMilestoneExpansionUnlocked ??= false; q.seedMultiplierBonus ??= 0; q.chestChanceBonus ??= 0;
    return q;
  };
  const parrotExpansion = (s) => X.rebirbs(s) >= 1;
  // Birb getCommonSacrificeAvailableMaxIndex / getCommonSacrificeMilestoneLevelFromCount
  const maxIndex = (s) => (parrotExpansion(s) ? THRESH.length - 1 : X.sacState(s).commonMilestoneExpansionUnlocked ? 5 : 2);
  X.sacLevel = function (s) {
    const n = Math.max(0, Math.floor(X.sacState(s).skillPointsSacrificed || 0));
    for (let a = maxIndex(s); a >= 0; a--) if (n >= THRESH[a]) return a + 1;
    return 0;
  };
  X.sacProfile = (s) => { const l = X.sacLevel(s); return l > 0 ? TIERS[l - 1] : BASE; };
  X.sacMaxUnlocked = (s) => (parrotExpansion(s) ? THRESH.length : X.sacState(s).commonMilestoneExpansionUnlocked ? 6 : 3);
  // Birb getNextCommonMilestoneTargetFromCount: 0 when every open tier is reached
  X.sacTarget = function (s) {
    const n = Math.floor(X.sacState(s).skillPointsSacrificed || 0), a = maxIndex(s);
    for (let r = 0; r <= a; r++) if (n < THRESH[r]) return THRESH[r];
    return 0;
  };
  const levelForTarget = (t) => { if (t <= 0) return 1; for (let n = 0; n < THRESH.length; n++) if (t <= THRESH[n]) return n + 1; return THRESH.length; };
  X.sacTierCost = (s, lv) => (lv <= 0 ? 0 : TIERS[Math.min(lv, X.sacMaxUnlocked(s)) - 1].cost);
  X.sacTierStart = (s, lv) => (lv <= 0 ? 0 : THRESH[Math.min(lv, X.sacMaxUnlocked(s)) - 1]);
  X.sacProgress = function (s) {
    const t = X.sacTarget(s), lv = levelForTarget(t), cost = X.sacTierCost(s, lv);
    return { target: t, level: lv, cost, progress: Math.max(0, Math.min(cost, Math.floor(X.sacState(s).skillPointsSacrificed) - X.sacTierStart(s, lv - 1))) };
  };

  // Spirit Aura lives in the parrot's artifact inventory (stackable "material" items, by name)
  X.itemCount = (s, name) => (PT.parrotState(s).artifactInventory || []).reduce((a, it) => a + (it.name === name ? Math.max(0, Math.floor(it.count ?? 1)) : 0), 0);
  X.takeItem = function (s, name, n) {
    const inv = PT.parrotState(s).artifactInventory; if (X.itemCount(s, name) < n) return false;
    for (const it of inv) { if (n <= 0) break; if (it.name !== name) continue; const k = Math.min(n, it.count ?? 1); it.count = (it.count ?? 1) - k; n -= k; }
    PT.parrotState(s).artifactInventory = inv.filter((it) => (it.count ?? 1) > 0); return true;
  };

  X.canUnlockSacExpansion = (s) => !parrotExpansion(s) && X.sacLevel(s) >= 3 && !X.sacState(s).commonMilestoneExpansionUnlocked;
  X.unlockSacExpansion = function (s) {
    if (!X.canUnlockSacExpansion(s) || !X.takeItem(s, "Spirit Aura", EXPANSION_COST)) return false;
    X.sacState(s).commonMilestoneExpansionUnlocked = true; X.refreshRunParrot(s); return true;
  };
  // Birb $b: sacrifice min(available, left to the next milestone) x share ("all" / "half" / "quarter"), at least 1
  X.sacrifice = function (s, mode = "all") {
    const p = PT.parrotState(s), have = Math.max(0, Math.floor(p.skillPoints || 0)), pr = X.sacProgress(s), left = pr.target > 0 ? Math.max(0, pr.cost - pr.progress) : 0;
    if (left <= 0 || have <= 0) return 0;
    const share = mode === "quarter" ? 0.25 : mode === "half" ? 0.5 : 1, n = Math.min(left, Math.max(1, Math.floor(Math.min(have, left) * share)));
    p.skillPoints -= n; X.sacState(s).skillPointsSacrificed += n; X.refreshRunParrot(s); return n;
  };

  // ------------------------------------------------------------------ hooks into the rest of the game
  X.sacrificeMilestone = (s) => X.sacProfile(s);
  PT.sacrificePopcornMult = (s) => X.sacProfile(s).popcornMultiplier; // Birb getSacrificePopcornMultiplier -> wI sacrificeMultiplier
  const softCap = (e, t) => (e <= t ? e : t + t * Math.log(1 + (e - t) / t));
  X.sacSeedMult = (s) => (1 + softCap(X.sacState(s).seedMultiplierBonus || 0, 14)) * X.sacProfile(s).seedMultiplier; // Birb getSacrificeSeedMultiplier (chest seed rewards)
  X.sacSpMult = (s) => X.sacProfile(s).skillPointMultiplier; // Birb getCommonSacrificeSkillPointMultiplier
  X.sacRadiusMult = (s) => X.sacProfile(s).parrotRadiusMultiplier;
  // Birb getSacrificeChestChanceBonus: legacy rare sacrifice bonus with an asymptotic cap (0.12 soft, 0.2 hard)
  X.sacChestChanceBonus = function (s) {
    const i = Math.max(0, X.sacState(s).chestChanceBonus || 0), t = 0.12, n = 0.2;
    return i <= t ? i : t + (n - t) * (1 - Math.exp(-(i - t) / Math.max(1e-4, t)));
  };
  const prevRebirb = X.onParrotRebirb;
  X.onParrotRebirb = function (s) { if (prevRebirb) prevRebirb(s); const q = X.sacState(s); q.skillPointsSacrificed = 0; q.commonMilestoneExpansionUnlocked = false; };
})();
