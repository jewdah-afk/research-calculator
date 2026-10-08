// Parity test: puts the same save state into Birb's live engine (birbplay.com, window.game)
// and into the playtest, then compares every formula both sides expose.
// Run from the repo root:  NODE_PATH=/opt/node-tools/node_modules node playtest/parity/parity.js
// Writes playtest/parity/REPORT.md. Needs network access to birbplay.com.
const fs = require("fs"), path = require("path"), http = require("http");
const { chromium } = require("playwright");
const ROOT = path.resolve(__dirname, "../..");
const SCENARIOS = require("./scenarios.js");
const DATA = (() => { const window = {}; eval(fs.readFileSync(path.join(ROOT, "playtest/js/data.js"), "utf8")); return window.BIRB_DATA; })();

const MIME = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".png": "image/png", ".json": "application/json" };
function serve() {
  return new Promise((ok) => {
    const srv = http.createServer((req, res) => {
      const f = path.join(ROOT, decodeURIComponent(req.url.split("?")[0]));
      if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end(); }
      res.writeHead(200, { "content-type": MIME[path.extname(f)] || "application/octet-stream" });
      fs.createReadStream(f).pipe(res);
    });
    srv.listen(0, "127.0.0.1", () => ok(srv));
  });
}

// The probe runs inside each page. `side` is "birb" or "ours"; both get the same scenario and return a flat {key: number|bool}.
function probe({ side, scenario }) {
  const D = window.BIRB_DATA;
  const num = (x) => (x == null ? null : typeof x === "boolean" ? x : typeof x === "object" && x.toNumber ? x.toNumber() : typeof x === "object" && "mantissa" in x ? x.mantissa * Math.pow(10, x.exponent) : Number(x));
  const deep = (dst, src) => { for (const [k, v] of Object.entries(src)) { if (v && typeof v === "object" && !Array.isArray(v)) { dst[k] = dst[k] && typeof dst[k] === "object" ? dst[k] : {}; deep(dst[k], v); } else dst[k] = v; } };
  const fresh = () => ({ parrot: null, collaredDove: null, sparrowPrestigeCount: 0, desertSandstormTimeRemaining: 0, desertSandstormCooldownRemaining: 0, hasUnlockedDesertMap: false, mine: {}, floorOneMineEntranceOpened: false, aquarium: { activeBiomeId: "coast", housedFish: {}, researchedFishCounts: {}, releasedShinyFishes: {}, releasedShinyWeightsKg: {} }, fishInventory: [], discoveredFish: [], discoveredShinyFish: [], fishWeightRecords: [], activeFishIds: [], activeFishBuffs: {}, lockedFish: [], fishBuffThirdSlotUnlocked: false });
  let A;
  if (side === "birb") {
    const g = window.game, s = g.state;
    s.upgrades = {}; s.sunflowerUpgrades = {};
    for (const k of Object.keys(s.resources)) s.resources[k] = 0;
    Object.assign(s, fresh());
    const st = JSON.parse(JSON.stringify(scenario.state));
    deep(s, st);
    if (g.invalidateUpgradeTreeCache) g.invalidateUpgradeTreeCache();
    g.nestManager.setState(JSON.parse(JSON.stringify(st.nest || {})), false); s.nest = g.nestManager.getState();
    s.redPanda = Object.assign({ name: "Red Panda", named: false, introSeen: false, tier: 1, mode: "chill", x: 528, y: 300 }, st.redPanda || {}); g.ensureRedPandaState();
    g.aquariumManager.invalidateModifierCache(); g.activeFishEffectSnapshot = null; g.fishMarketManager.normalizedMarketState = null;
    const nm = g.nestManager, snap = () => nm.getCultivationShopSnapshot();
    g.ensureMineState(); g.ensureCollaredDoveState(); g.ensureParrotState();
    { const em0 = g.expeditionManager, pr = (st.expedition && st.expedition.progress) || {}; em0.state.progress.level = pr.level || 1; em0.state.highestFloorReached = (st.expedition && st.expedition.highestFloorReached) || 1; em0.state.archivistEncounterVersion = 1; em0.state.archivistDefeated = !!(st.expedition && st.expedition.archivistDefeated); em0.state.activeRun = null; } g.goldenPopcornRewardSnapshotTime = -1;
    const mm = g.fishMarketManager, am = g.aquariumManager;
    A = {
      level: (id) => g.getUpgradeLevel(id), max: (id) => g.getUpgradeMaxLevel(id), eff: (id) => g.getUpgradeEffect(id),
      cost: (d) => g.getDiscountedUpgradeCost(d, g.getUpgradeLevel(d.id)),
      maxPopcorn: () => g.getMaxPopcorn(0), interval: () => g.getSpawnInterval(0), total: () => g.getTotalMultiplier(),
      prestige: () => g.getPotentialPrestigePoints().final, playtime: () => g.getPlaytimeMultiplier(), payout: () => g.getPrestigePayoutMultiplier(),
      radius: () => g.getPickupRadius(), sunUnlocked: (id) => g.isSunflowerUpgradeUnlocked(id), sunVisible: (id) => g.isSunflowerUpgradeVisible(id),
      sunCost: (d) => g.getDiscountedUpgradeCost(d, g.getSunflowerUpgradeLevel(d.id)),
      fish: (t) => g.getFishMultiplier(t), canEvolve: () => g.canEvolveCurrentStage(), sparrowXp: (L) => g.getSparrowXpNeeded(L),
      aqMod: (t) => am.getModifierMultiplier(t), aqShiny: () => am.getShinyChanceMultiplier(), aqNormal: () => am.getNormalFishBuffMultiplier(),
      aqShinyMs: () => am.getShinyBuffDurationMs(), aqSlots: () => am.getFishBuffSlotBonus(), aqPoints: () => am.getResonancePoints(),
      aqTier: (b) => am.getBiomeProgress(b).tierCount, aqHoused: () => am.getHousedSpeciesCount(), marketOpen: () => g.isFishMarketUnlocked(),
      maxBuffs: () => g.fishingManager.getMaxActiveFishBuffs(), aqUnlocked: () => g.isAquariumUnlocked(),
      contracts: (c, r) => { mm.ensureState(); mm.generateContractOffers(c, r); return JSON.stringify(s.aquarium.market.contractOffers); },
      repLevel: (x) => mm.getContractReputationLevel(x),
      community: () => g.getCommunityGoalRewardValue("twigGain"),
      exp: (() => { const em = g.expeditionManager, FI = em.constructor; return {
        xpReq: (L) => FI.getXpRequirementForLevel(L), stats: (t, f, b, k) => em.resolveEnemyStatsForMapSpawn(t, f, b)?.[k],
        depthHp: (t, h, r, f, q) => em.enemyDepthBalance.resolveDepthScaledHealthAtQuantile(t, h, r, f, q), atk: (a, h, l, b) => em.resolveAttackFromLife(a, h, l, b),
        sp: (t, l, h, m, b, f, r) => em.resolveSkillPointReward(t, l, h, m, b, f, r), spScale: (sp, f, r) => em.applyFloorSkillPointRewardScaling(sp, f, r),
        total: (k) => g.getParrotTotalStats()[k], gear: (k) => g.getEquipmentMultipliers()[k], spMult: () => g.getParrotRebirbSkillPointMultiplier(), rebirb: () => g.canPerformParrotRebirb(),
        ext: (k) => g.getQuestMerchantExpeditionBonuses()[k], muad: () => g.getMuadBirbSkillPointMultiplier(), add: (k) => g.getParrotSkillAdditions()[k],
        range: (t, b) => em.getEnemyRetaliationTriggerRange({ type: t, isBoss: b, attackRange: em.constructor && undefined }), strike: (t, b) => em.getParrotStrikeDistance({ type: t, isBoss: b }),
        respawn: (x) => em.getEffectiveEnemyRespawnDelaySeconds(x), shiny: () => g.getExpeditionShinyEnemyChance(), sac: { level: () => em.getCommonSacrificeMilestoneLevel(), target: () => em.getCommonSacrificeMilestoneTarget(), popcorn: () => em.getSacrificePopcornMultiplier(), sp: () => em.getCommonSacrificeSkillPointMultiplier(),
          radius: () => em.getSacrificeParrotRadiusMultiplier(), seed: () => em.getSacrificeSeedMultiplier(), qty: () => em.getSacrificeAuraQuantityMultiplier(), chance: () => em.getCommonSacrificeChestChanceMultiplier(),
          promo: () => em.getSacrificeAuraRarityPromotionChance(), canExpand: () => em.canUnlockCommonMilestoneExpansion(), maxLv: () => em.getCommonSacrificeMilestoneMaxUnlockedLevel(),
          progress: () => em.getCommonSacrificeMilestoneProgressByTarget(em.getCommonSacrificeMilestoneTarget()), atk: () => { em.refreshParrotBonuses(g.getEquippedArtifactNames(), g.getEquipmentMultipliers(), g.getEquippedArtifactInfusionLevels()); return em.parrotBonuses.attackSpeedMult; }, move: () => em.parrotBonuses.moveSpeedMult, range: () => em.getEffectiveParrotRangeMultiplier() },
        loot: { ab: (k) => em.getArtifactBonuses(g.getEquippedArtifactNames(), g.getEquippedArtifactInfusionLevels())[k], slots: () => g.getParrotArtifactSlotCount(),
          cap: (c) => g.getParrotInventoryCapacity(c).max, used: (c) => g.getParrotInventoryCapacity(c).used, rolls: () => em.getLootAuraExpectedRollCount({ artifacts: [], persistentEquippedNames: g.getEquippedArtifactNames(), persistentEquippedInfusionLevels: g.getEquippedArtifactInfusionLevels() }),
          spMult: () => em.artifactManager.getSkillPointMultiplier([], g.getEquippedArtifactNames()), hoard: () => em.artifactManager.getPointHoardJackpotChance([], g.getEquippedArtifactNames()),
          auraBonus: () => em.artifactManager.getLootAuraChanceBonus([], g.getEquippedArtifactNames(), g.getEquippedArtifactInfusionLevels()), passive: () => { em.refreshParrotBonuses(g.getEquippedArtifactNames(), g.getEquipmentMultipliers(), g.getEquippedArtifactInfusionLevels()); return em.getPassiveSkillPointMultiplier(g.getEquippedArtifactNames()); },
          names: () => g.getEquippedArtifactNames().filter(Boolean).length },
        procs: window.__BIRB_PROCS ? { kn: (o) => window.__BIRB_PROCS.kn(o), xn: (h, m, p) => window.__BIRB_PROCS.xn(h, m, p), cn: (n, p) => window.__BIRB_PROCS.Cn(n, p).damageRatio * 100 + window.__BIRB_PROCS.Cn(n, p).maxTargets } : null,
        resetCost: () => { const sk = s.parrot.skills, t = sk.hp + sk.lifeRegen + sk.damage; return t <= 0 ? 0 : Math.max(1, Math.ceil(Math.sqrt(0.01 * t))); },
      }; })(),
      desert: {
        chance: () => g.getDesertGoldenPopcornChance(), interval: () => g.getSpawnInterval(9) / g.getDesertPopcornSpawnRateMultiplier(), perDrop: () => g.calculateGoldenPopcornGainPerDrop(),
        collect: (c) => g.getGoldenPopcornCollectionMultiplier(c), eggMult: () => g.getPopcornCollectionMultiplier(9, g.getTotalMultiplier()), bloom: () => g.getDuneBloomGoldenPopcornMultiplier(),
        storm: () => g.isDesertSandstormActive(), xpNeed: (L) => g.getDaveXpNeeded(L), seedCost: (L) => g.getDaveSeedTrainingCost(L), speed: () => g.getDaveSpeedMultiplier(),
        delay: () => g.getDaveForagePickDelay(), sweep: () => g.getDaveSweepSize(), burst: () => g.getDaveBurstPickCount(), golden: () => g.getDaveGoldenPopcornMultiplier(),
        canRebirb: () => g.canDaveRebirb(), xpGain: () => g.getDaveXpGainMultiplier(), rebirbs: () => g.getDaveRebirbCount(), unspent: () => g.getDaveUnspentRebirbPoints(),
        milestone: (id) => g.isDaveMilestoneUnlocked(id), goldenAuto: () => nm.isGoldenPopcornAutomationUnlocked(),
      },
      mine: {
        value: () => g.getMineOreValue(), bonus: () => g.getMineOreDamageBonus(), interval: () => g.getMineCrowHitInterval(), golden: () => g.getMineGoldenOreChance(),
        area: () => g.getMineMilestoneLevel(), stat: (k) => g.getMineShopStats()[k], xpNeed: (L) => g.getMineCrowXpNeeded(L), rebirbLevel: () => g.getMineCrowRebirbRequiredLevelForNext(),
        rebirbUnlocked: () => g.isMineCrowRebirbUnlocked(), canRebirb: () => g.canRebirbMineCrow(),
        nodeVisible: (id) => g.isMineTreasureUpgradeVisible("d_mine_" + id), nodeUnlocked: (id) => g.upgradeManager.isSunflowerUpgradeUnlocked("d_mine_" + id),
        cost: (d, L) => g.getDiscountedUpgradeCost(d, L),
      },
      nest: {
        resMult: () => nm.getResourceMultiplier(), twigMult: () => nm.getForestTwigMultiplier(), perHit: () => nm.getTwigRewardPerHit(),
        compDps: () => nm.getForestChopDamagePerSecond(), hitRate: () => nm.getBirbForestChopHitRatePerSecond(), peckDmg: () => nm.getBirbForestPeckDamage(),
        estBirb: () => nm.getEstimatedTwigGenPerSecond("birb"), estComp: () => nm.getEstimatedTwigGenPerSecond("companion"),
        build: (k) => nm.getNestBuildProgress()[k], maxTier: () => nm.getMaxNestTierForCurrentEvolution(), migrate: () => nm.canMigrate(),
        silo: () => nm.getGrainSiloMultiplier(), respawn: () => nm.getPopcornRespawnMultiplier(), seedProd: () => nm.getSeedProductionMultiplier(), well: () => nm.getWateringWellResourceMultiplier(),
        snap: (k) => snap()[k], maxPrev: (kind, k) => nm.getCultivationUpgradeMaxPreview(kind)[k],
        nap: () => g.getRedPandaNapResourceMultiplier(), pandaTier: () => g.getRedPandaTier(), hybrid: (t) => nm.getActiveHybridMultiplier(t),
        breed: (a, b, k) => { const v = nm.getFishBreedingPreview(a, b)[k]; return v && typeof v === "object" ? ["common", "uncommon", "rare", "epic", "legendary"].map((r) => v[r]).join(",") : v; },
      },
    };
  } else {
    const G = window.PT.G, PT = window.PT, s = Object.assign(PT.newState(), fresh());
    const st = JSON.parse(JSON.stringify(scenario.state));
    const res = st.resources || {}; delete st.resources;
    deep(s, st);
    for (const [k, v] of Object.entries(res)) s.resources[k] = new Decimal(v);
    G.s = s; PT.ensureFishing && PT.ensureFishing(s);
    A = {
      level: (id) => PT.level(s, id), max: (id) => PT.maxLevel(s, id), eff: (id) => PT.effect(s, id),
      cost: (d) => PT.discounted(s, PT.UP.get(d.id), PT.level(s, d.id)),
      maxPopcorn: () => PT.maxPopcorn(s), interval: () => PT.spawnInterval(s), total: () => PT.totalMultiplier(s),
      prestige: () => PT.prestige(s).final, playtime: () => PT.playtimeMult(s), payout: () => PT.prestigePayoutMult(s),
      radius: () => PT.pickupProfile(s).collectRadius, sunUnlocked: (id) => PT.sunUnlocked(s, id), sunVisible: (id) => PT.sunVisible(s, id),
      sunCost: (d) => PT.sunCost(s, d.id),
      fish: (t) => PT.fishMult(s, t), canEvolve: () => PT.canEvolveStage(s), sparrowXp: (L) => PT.sparrowXpNeeded(L),
      aqMod: (t) => PT.aqModifier(s, t), aqShiny: () => PT.aqShinyChanceMult(s), aqNormal: () => PT.aqNormalBuffMult(s),
      aqShinyMs: () => PT.aqShinyBuffMs(s), aqSlots: () => PT.aqBuffSlots(s), aqPoints: () => PT.aqPoints(PT.aq(s)),
      aqTier: (b) => PT.aqBiome(PT.aq(s), b).tierCount, aqHoused: () => PT.aqHousedCount(PT.aq(s)), marketOpen: () => PT.fishMarketUnlocked(s),
      maxBuffs: () => PT.maxFishBuffs(s), aqUnlocked: () => PT.aquariumUnlocked(s),
      contracts: (c, r) => { PT.market(s); return JSON.stringify(PT.generateContracts(s, c, r)); },
      repLevel: (x) => PT.repLevel(x),
      exp: (() => { const X = PT.EXP; PT.parrotState(s); PT.expState(s); const pw = (p) => (typeof p === "number" ? { copies: Math.min(2, p), primaryPower: p >= 1 ? 1 : 0, secondaryPower: p >= 2 ? 1 : 0 } : { copies: Math.min(2, p.copies), primaryPower: p.copies >= 1 ? p.primaryPower : 0, secondaryPower: p.copies >= 2 ? p.secondaryPower : 0 }); return {
        xpReq: (L) => X.xpReq(L), stats: (t, f, b, k) => X.enemyStats(t, f, b)?.[k], depthHp: (t, h, r, f, q) => X.depthHealthAt(t, h, r, f, q), atk: (a, h, l, b) => X.attackFromLife(a, h, l, b),
        sp: (t, l, h, m, b, f, r) => X.spReward(t, l, h, m, b, f, r), spScale: (sp, f, r) => X.floorSpScale(sp, f, r), total: (k) => PT.parrotTotalStats(s)[k], gear: (k) => X.gearMults(s)[k],
        spMult: () => X.rebirbSpMult(s), rebirb: () => PT.parrotRebirbReady(s), ext: (k) => X.externalBonuses(s)[k], muad: () => X.muadBirb(s), add: (k) => X.skillAdditions(s)[k],
        range: (t, b) => X.triggerRange({ type: t, isBoss: b }), strike: (t, b) => X.strikeDist({ type: t, isBoss: b }), respawn: (x) => X.effectiveRespawn(s, x), shiny: () => X.shinyChance(s), resetCost: () => PT.parrotResetCost(s),
        loot: { ab: (k) => X.artifactBonuses(s)[k], slots: () => X.slotCount(s), cap: (c) => X.invCapacity(s, c).max, used: (c) => X.invCapacity(s, c).used, rolls: () => X.lootAuraExpectedRolls(s),
          spMult: () => X.artifactSpMult(s), hoard: () => X.pointHoardChance(s), auraBonus: () => X.lootAuraChanceBonus(s), passive: () => X.passiveSpMult(s) / X.rebirbSpMult(s), names: () => X.equippedNames(s).filter(Boolean).length },
        procs: { kn: (o) => X.procMult({ ...o, isOpening: o.isOpeningStrike, redline: pw(o.redlinePower), opening: pw(o.openingStrikePower), focus: pw(o.focusPower) }), xn: (h, m, p) => X.recoveryMult(pw(p), h, m),
          cn: (n, p) => { const r = X.storm(n, pw(p)); return r.damageRatio * 100 + r.maxTargets; } },
        sac: { level: () => X.sacLevel(s), target: () => X.sacTarget(s), popcorn: () => PT.sacrificePopcornMult(s), sp: () => X.sacSpMult(s), radius: () => X.sacRadiusMult(s), seed: () => X.sacSeedMult(s),
          qty: () => X.sacProfile(s).auraQuantityMultiplier, chance: () => X.sacProfile(s).auraChanceMultiplier, promo: () => X.sacProfile(s).auraRarityPromotionChance, canExpand: () => X.canUnlockSacExpansion(s),
          maxLv: () => X.sacMaxUnlocked(s), progress: () => X.sacProgress(s).progress, atk: () => { const b = X.parrotBonuses(s); return b.attackSpeedMult; }, move: () => X.parrotBonuses(s).moveSpeedMult, range: () => { X.bonuses = X.parrotBonuses(s); return X.rangeMult(); } },
      }; })(),
      desert: {
        chance: () => PT.desertGoldenChance(s), interval: () => PT.desertSpawnInterval(s), perDrop: () => PT.goldenPerDrop(s),
        collect: (c) => PT.goldenCollectMult(s, c), eggMult: () => PT.desertEggMult(s), bloom: () => PT.duneBloomMult(s),
        storm: () => PT.sandstormOn(s), xpNeed: (L) => PT.daveXpNeeded(L), seedCost: (L) => PT.daveSeedCost(L), speed: () => PT.daveSpeedMult(s),
        delay: () => PT.davePickDelay(s), sweep: () => PT.daveSweepSize(s), burst: () => PT.daveBurst(s), golden: () => PT.daveGoldenMult(s),
        canRebirb: () => PT.daveCanRebirb(s), xpGain: () => PT.daveXpGainMult(s), rebirbs: () => PT.daveRebirbs(s), unspent: () => PT.dave(s).unspentRebirbPoints,
        milestone: (id) => PT.daveMilestone(s, id), goldenAuto: () => PT.goldenAutomationUnlocked(s),
      },
      mine: {
        value: () => PT.mineOreValue(s), bonus: () => PT.mineDamageBonus(s), interval: () => PT.crowInterval(s), golden: () => PT.mineGoldenChance(s),
        area: () => PT.mineArea(s), stat: (k) => (k === "chargeInterval" ? PT.mineProfile(s).chargeInterval : k === "chargeBonus" ? (PT.mineHas(s, "seismic_strike") ? 3 : 0) : k === "crowDamage" ? PT.crowDamage(s) : NaN),
        xpNeed: (L) => PT.crowXpNeeded(L), rebirbLevel: () => { const n = PT.mineState(s).crowRebirbCount; return n < 8 ? [3, 5, 7, 7, 10, 12, 16, 20][n] : 20 + 5 * (n - 8); },
        rebirbUnlocked: () => PT.crowRebirbUnlocked(s), canRebirb: () => PT.crowCanRebirb(s),
        nodeVisible: (id) => PT.mineNodeVisible(s, id), nodeUnlocked: (id) => PT.mineNodeUnlocked(s, id),
        cost: (d, L) => PT.cost(PT.UP.get(d.id), L),
      },
      nest: (() => {
        const sn = () => PT.nestCultSnapshot(s), up = (id) => PT.NEST_UPS[id].cost(PT.nestUpLevel(s, id));
        const SNAP = { twigValueCost: () => up("n_twig_value"), peckRateCost: () => up("n_peck_rate"), peckPowerCost: () => up("n_peck_power"),
          peckRateVisible: () => PT.nestUpVisible(s, "n_peck_rate"), peckPowerVisible: () => PT.nestUpVisible(s, "n_peck_power"),
          treeBoxCost: () => sn().treeBoxCost, treeBoxCostCurrency: () => sn().treeBoxCostCurrency, treeBoxMaxed: () => sn().treeBoxMaxed,
          treeBoxExpansionVisible: () => sn().expansionVisible, treeBoxExpansionCost: () => sn().expansionCost, growthSeconds: () => sn().growthSeconds,
          fertilizerVisible: () => PT.NEST_SPECIALS[0].visible(s, s.nest.cultivation), specializedFertilizerVisible: () => PT.NEST_SPECIALS[1].visible(s, s.nest.cultivation),
          sunflowerFieldVisible: () => PT.NEST_SPECIALS[4].visible(s, s.nest.cultivation), wateringWellVisible: () => PT.NEST_SPECIALS[5].visible(s, s.nest.cultivation),
          twigValuePerPeck: () => PT.nestTwigPerPeck(s), peckRate: () => PT.nestHitRate(s), peckDamage: () => PT.nestPeckDamage(s) };
        const KIND = { "twig-value": "n_twig_value", "peck-rate": "n_peck_rate", "peck-power": "n_peck_power" };
        return {
          resMult: () => PT.nestResourceMult(s), twigMult: () => PT.nestTwigMult(s), perHit: () => PT.nestRewardPerHit(s),
          compDps: () => PT.nestCompanionDps(s), hitRate: () => PT.nestHitRate(s), peckDmg: () => PT.nestPeckDamage(s),
          estBirb: () => PT.nestTwigsPerSec(s, "birb"), estComp: () => PT.nestTwigsPerSec(s, "companion"),
          build: (k) => PT.nestBuild(s)[k], maxTier: () => PT.nestMaxTier(s), migrate: () => PT.nestCanMigrate(s),
          silo: () => PT.nestGrainSilo(s), respawn: () => PT.nestRespawnMult(s), seedProd: () => PT.nestSeedProdMult(s), well: () => PT.nestWellMult(s),
          snap: (k) => SNAP[k](), maxPrev: (kind, k) => { const p = PT.nestMaxPreview(s, KIND[kind]); return k === "totalCost" ? PT.num(p.totalCost) : p[k]; },
          nap: () => PT.redPandaNapMult(s), pandaTier: () => PT.redPandaTier(s), hybrid: (t) => PT.hybridMult(s, t),
          breed: (a, b, k) => { const v = PT.breedPreview(s, a, b)[k]; return Array.isArray(v) ? v.join(",") : v; },
        };
      })(),
    };
    PT.nestState(s);
  }
  const out = {}, put = (k, f) => { try { out[k] = num(f()); } catch (e) { out[k] = "ERR " + e.message.slice(0, 60); } };
  for (const d of D.upgrades.filter((u) => !u.id.startsWith("d_"))) {
    put(`upgrade ${d.id} level`, () => A.level(d.id)); put(`upgrade ${d.id} max`, () => A.max(d.id));
    put(`upgrade ${d.id} effect`, () => A.eff(d.id)); put(`upgrade ${d.id} cost`, () => A.cost(d));
  }
  put("egg cap", A.maxPopcorn); put("spawn interval", A.interval); put("total multiplier", A.total);
  put("molt plumes", A.prestige); put("playtime mult", A.playtime); put("molt payout mult", A.payout); put("pickup radius", A.radius);
  put("can evolve", A.canEvolve);
  for (const t of ["popcorn_mult", "seed_mult", "feather_mult", "speed_mult", "pickup_mult", "spawn_mult", "reel_speed_mult", "xp_mult"]) put(`fish mult ${t}`, () => A.fish(t));
  for (const L of [1, 2, 10, 50]) put(`sparrow xp needed L${L}`, () => A.sparrowXp(L));
  for (const t of ["popcorn_mult", "seed_mult", "feather_mult", "golden_popcorn_mult", "speed_mult", "pickup_mult", "reel_speed_mult", "xp_mult", "shiny_chance_mult", "parrot_damage_mult", "sell_mult"]) put(`aquarium modifier ${t}`, () => A.aqMod(t));
  put("aquarium shiny chance mult", A.aqShiny); put("aquarium normal buff mult", A.aqNormal); put("aquarium shiny buff ms", A.aqShinyMs);
  put("aquarium buff slots", A.aqSlots); put("aquarium resonance", A.aqPoints); put("aquarium housed species", A.aqHoused); put("aquarium unlocked", A.aqUnlocked);
  put("fish market unlocked", A.marketOpen); put("max fish buffs", A.maxBuffs);
  for (const b of ["coast", "reef", "freshwater", "ocean", "abyssal", "creatures", "mystic", "mechanical", "expedition"]) put(`aquarium tier ${b}`, () => A.aqTier(b));
  for (const x of [0, 99, 100, 650, 6200, 9999]) put(`market rep level at ${x}`, () => A.repLevel(x));
  if (scenario.state.aquarium) for (const [c, r] of [[20000, 0], [20001, 0], [20001, 2]]) out[`contract offers cycle ${c} reroll ${r}`] = A.contracts(c, r);
  const Ex = A.exp, PLAN = { 1: ["cobra", "masked-forest-spirit", "twig-blight", "flower-monster"], 2: ["witch", "harpy", "cobra", "skeleton-warrior", "ghoul"], 3: ["anubis", "mummy", "anubis-warrior"],
    4: ["fishfolk-brute", "fishfolk-whipe", "fishfolk-inkbender", "fishfolk-archpriest"], 5: ["fishfolk-horror", "fishfolk-pugilist", "sea-horror", "sea-gramlin", "elemental"], 6: ["frosty-slime", "frost-wisp", "arctic-whisper", "ice-harpy", "frozy-cube"],
    7: ["frogfolk-chieftain", "frogfolk-wizard", "frogfolk-brute", "giant-fly"], 8: ["giant-black-pudding", "black-pudding", "ghost", "doppelganger"], 9: ["the-archivist", "hell-critter", "imp", "cacodaemon", "cultist-brute", "cultist"] };
  for (const L of [1, 2, 7, 30, 150, 1000]) put(`parrot xp needed L${L}`, () => Ex.xpReq(L));
  if (scenario.expedition) {
    for (const [f, types] of Object.entries(PLAN)) for (const t of types) for (const b of [false, true]) {
      for (const k of ["health", "attack", "xpBase", "skillPointReward", "speed"]) put(`exp stats F${f} ${t}${b ? " boss" : ""} ${k}`, () => Ex.stats(t, +f, b, k));
      if (!b) for (const r of [0.1, 0.5, 0.95]) for (const q of [0, 1]) put(`exp depth hp F${f} ${t} r${r} q${q}`, () => Ex.depthHp(t, Ex.stats(t, +f, false, "health"), r, +f, q));
      for (const r of [0.1, 0.5, 0.95]) put(`exp sp F${f} ${t}${b ? " boss" : ""} r${r}`, () => { const h = Ex.stats(t, +f, b, "health"), life = Ex.depthHp(t, h, r, +f, 0.5); return Ex.spScale(Ex.sp(t, life, h, Ex.stats(t, +f, b, "skillPointReward"), b, +f, r), +f, r); });
      put(`exp atk F${f} ${t}${b ? " boss" : ""}`, () => { const h = Ex.stats(t, +f, b, "health"); return Ex.atk(Ex.stats(t, +f, b, "attack"), h, Ex.depthHp(t, h, 0.5, +f, 0.5), b); });
      put(`exp range ${t}${b ? " boss" : ""}`, () => Ex.range(t, b)); put(`exp strike ${t}${b ? " boss" : ""}`, () => Ex.strike(t, b));
    }
  }
  for (const k of ["hp", "damage", "lifeRegen"]) put(`parrot total ${k}`, () => Ex.total(k));
  for (const k of ["beakMult", "armorMult", "auraMult"]) put(`parrot gear ${k}`, () => Ex.gear(k));
  for (const k of ["hpMult", "damageMult", "lifeRegenMult", "skillPointMult", "attackSpeedMult"]) put(`parrot additions ${k}`, () => Ex.add(k));
  for (const k of ["damageMult", "hpMult", "skillPointMult", "chestRewardMult", "combatRegenPenaltyReduction", "lootAuraChanceFlat"]) put(`parrot external ${k}`, () => Ex.ext(k));
  put("parrot rebirb sp mult", Ex.spMult); put("parrot can rebirb", Ex.rebirb); put("parrot muad birb", Ex.muad); put("parrot boss respawn s", () => Ex.respawn(480)); put("exp shiny chance", Ex.shiny); put("parrot reset cost", Ex.resetCost);
  for (const k of ["damageMult", "hpMult", "hpAdd", "lifeRegenAdd", "lifeRegenMult", "combatRegenPenaltyReduction", "attackSpeedMult", "moveSpeedMult", "inventorySpace"]) put(`artifact bonus ${k}`, () => Ex.loot.ab(k));
  { const P = [0, 1, 2, { copies: 2, primaryPower: 1.2, secondaryPower: 1.04 }, { copies: 1, primaryPower: 1.4, secondaryPower: 0 }];
    for (const [i, pp] of P.entries()) for (const hr of [1, 0.69, 0.45, 0.2, 0.05]) for (const tr of [1, 0.9, 0.5]) for (const op of [true, false]) for (const fh of [0, 3, 9])
      if (scenario.name === "loot basic kit") put(`proc mult p${i} hp${hr} t${tr} o${op} f${fh}`, () => Ex.procs && Ex.procs.kn({ health: hr * 1000, maxHealth: 1000, targetHealth: tr * 500, targetMaxHealth: 500, isOpeningStrike: op, focusHits: fh, redlinePower: pp, openingStrikePower: pp, focusPower: pp }));
    if (scenario.name === "loot basic kit") for (const [i, pp] of P.entries()) { for (const hr of [1, 0.6, 0.4, 0.2, 0]) put(`proc recovery p${i} hp${hr}`, () => Ex.procs && Ex.procs.xn(hr * 800, 800, pp)); for (const n of [5, 6, 12, 13]) put(`proc storm p${i} hit${n}`, () => Ex.procs && Ex.procs.cn(n, pp)); } }
  for (const k of ["slots", "rolls", "spMult", "hoard", "auraBonus", "passive", "names"]) put(`loot ${k}`, Ex.loot[k]);
  for (const c of ["artifact", "material"]) { put(`inventory cap ${c}`, () => Ex.loot.cap(c)); put(`inventory used ${c}`, () => Ex.loot.used(c)); }
  for (const k of ["level", "target", "popcorn", "sp", "radius", "seed", "qty", "chance", "promo", "canExpand", "maxLv", "progress", "atk", "move", "range"]) put(`sacrifice ${k}`, Ex.sac[k]);
  const Dz = A.desert;
  for (const k of ["chance", "interval", "perDrop", "eggMult", "bloom", "storm", "speed", "delay", "sweep", "burst", "golden", "canRebirb", "xpGain", "rebirbs", "unspent", "goldenAuto"]) put(`desert ${k}`, Dz[k]);
  for (const c of [false, true]) put(`desert golden collect caramel=${c}`, () => Dz.collect(c));
  for (const L of [1, 50, 100, 250]) { put(`dave xp needed L${L}`, () => Dz.xpNeed(L)); put(`dave seed cost L${L - 1}`, () => Dz.seedCost(L - 1)); }
  for (const id of ["firstHop", "quickFeet", "sharpEyes", "davesSons", "workRhythm", "fieldSense", "davesFamily", "masterForager"]) put(`dave milestone ${id}`, () => Dz.milestone(id));
  const Mn = A.mine;
  for (const k of ["value", "bonus", "interval", "golden", "area", "rebirbLevel", "rebirbUnlocked", "canRebirb"]) put(`mine ${k}`, Mn[k]);
  for (const k of ["chargeInterval", "chargeBonus", "crowDamage"]) put(`mine stat ${k}`, () => Mn.stat(k));
  for (const L of [1, 5, 26, 100]) put(`crow xp needed L${L}`, () => Mn.xpNeed(L));
  for (const [id, Ls] of [["m_ore_value", [1, 8, 11, 30, 100]], ["m_mining_power", [1, 8, 13, 25, 100]], ["m_charged_strike", [1, 2, 3, 4]]]) for (const L of Ls) put(`mine cost ${id} L${L}`, () => Mn.cost(D.upgrades.find((u) => u.id === id), L));
  for (const id of ["work_perch", "precise_peck", "rich_vein", "impact_transfer", "peck_rhythm", "deep_survey", "seismic_strike", "mineral_temper", "clean_extraction", "unbroken_rhythm", "work_pulse", "gold_beacon", "crown_survey", "fine_cut", "royal_mastery", "deep_mine", "royal_impact", "mineral_coffers", "seismic_echo", "royal_cut", "abyssal_forge", "abyssal_treasure", "deep_rebirb"]) {
    put(`mine tree ${id} visible`, () => Mn.nodeVisible(id)); put(`mine tree ${id} unlocked`, () => Mn.nodeUnlocked(id));
  }
  const N = A.nest;
  for (const k of ["resMult", "twigMult", "perHit", "compDps", "hitRate", "peckDmg", "estBirb", "estComp", "maxTier", "migrate", "silo", "respawn", "seedProd", "well", "nap", "pandaTier"]) put(`nest ${k}`, N[k]);
  for (const k of ["tier", "current", "required", "progress", "isComplete", "isMaxed"]) put(`nest build ${k}`, () => N.build(k));
  for (const k of ["twigValueCost", "peckRateCost", "peckPowerCost", "peckRateVisible", "peckPowerVisible", "treeBoxCost", "treeBoxCostCurrency", "treeBoxMaxed", "treeBoxExpansionVisible", "treeBoxExpansionCost", "growthSeconds", "fertilizerVisible", "specializedFertilizerVisible", "sunflowerFieldVisible", "wateringWellVisible", "twigValuePerPeck", "peckRate", "peckDamage"])
    out[`nest shop ${k}`] = (() => { try { const v = N.snap(k); return typeof v === "string" ? v : num(v); } catch (e) { return "ERR " + e.message.slice(0, 50); } })();
  for (const kind of ["twig-value", "peck-rate", "peck-power"]) for (const k of ["targetLevel", "levelsGained", "totalCost"]) put(`nest max preview ${kind} ${k}`, () => N.maxPrev(kind, k));
  for (const t of ["popcorn_mult", "seed_mult", "xp_mult", "reel_speed_mult", "pickup_mult"]) put(`nest hybrid ${t}`, () => N.hybrid(t));
  if (scenario.breed) for (const [a, b] of scenario.breed) for (const k of ["monetaCost", "odds", "shinyChance", "shinyParentCount"]) out[`breed ${a} x ${b} ${k}`] = (() => { const v = N.breed(a, b, k); return typeof v === "string" ? v : num(v); })();
  for (const [id] of D.stations) { if (id.startsWith("__")) continue; put(`tree ${id} unlocked`, () => A.sunUnlocked(id)); put(`tree ${id} visible`, () => A.sunVisible(id)); put(`tree ${id} cost`, () => A.sunCost(D.upgrades.find((u) => u.id === id))); }
  return out;
}

(async () => {
  const srv = await serve(), port = srv.address().port;
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-unsafe-swiftshader"] });
  const birb = await (await browser.newContext({ viewport: { width: 1600, height: 900 } })).newPage();
  await birb.goto("https://birbplay.com/", { waitUntil: "domcontentloaded", timeout: 90000 });
  await birb.waitForTimeout(6000);
  await birb.click("#start-game-btn", { force: true });
  await birb.waitForFunction(() => window.game && window.game.state && window.game.upgradeManager, null, { timeout: 60000 });
  await birb.waitForTimeout(3000);
  await birb.evaluate((d) => { window.BIRB_DATA = d; }, DATA); // CSP blocks script tags; evaluate goes through devtools
  await birb.evaluate(async () => { // Birb's artifact proc helpers live in the main chunk (kn / xn / Cn, exported as a0 / $ / a1)
    const src = [...document.querySelectorAll("script[src],link[href]")].map((e) => e.src || e.href).find((u) => /\/assets\/main-[^/]+\.js$/.test(u)) || "/assets/main-CPPXRpzm.js";
    const m = await import(src); window.__BIRB_PROCS = { kn: m.a0, xn: m.$, Cn: m.a1 };
  });
  const ours = await (await browser.newContext()).newPage();
  const errs = [];
  ours.on("pageerror", (e) => errs.push(e.message));
  await ours.goto(`http://127.0.0.1:${port}/playtest/index.html`);
  await ours.evaluate(() => localStorage.clear());
  await ours.reload(); await ours.waitForFunction(() => window.PT && window.PT.G);
  await ours.evaluate(() => { window.PT.G.paused = true; });

  const lines = [], close = (a, b) => (typeof a === "number" && typeof b === "number" ? Math.abs(a - b) <= 1e-6 * Math.max(1, Math.abs(a), Math.abs(b)) : a === b);
  let total = 0, bad = 0, communityNote = 0;
  const summary = [];
  for (const sc of SCENARIOS) {
    const b = await birb.evaluate(probe, { side: "birb", scenario: sc });
    const tg = await birb.evaluate(() => window.game.getCommunityGoalRewardValue("twigGain"));
    const cg = await birb.evaluate(() => ({ skillPointGain: window.game.getCommunityGoalRewardValue("skillPointGain"), chestRewards: window.game.getCommunityGoalRewardValue("chestRewards") }));
    await ours.evaluate(([v, c]) => { window.PT.COMMUNITY.twigGain = v; Object.assign(window.PT.COMMUNITY, c); }, [tg, cg]); // live server-wide event values
    if (!communityNote) communityNote = tg;
    const o = await ours.evaluate(probe, { side: "ours", scenario: sc });
    const rows = [];
    for (const k of Object.keys(b)) { total++; if (!close(b[k], o[k])) { bad++; rows.push(`| ${k} | ${b[k]} | ${o[k]} |`); } }
    summary.push(`| ${sc.name} | ${Object.keys(b).length} | ${rows.length} |`);
    lines.push(`\n### ${sc.name}\n`, rows.length ? "| Value | Birb | Playtest |\n|---|---|---|\n" + rows.join("\n") : "All match.");
  }
  const report = `# Parity report\n\nBirb's live engine (birbplay.com \`window.game\`) vs the playtest, same save state per scenario. Generated ${new Date().toISOString().slice(0, 16)}Z by \`playtest/parity/parity.js\`.\n\n**${total - bad} / ${total} values match.** Birb's live community-goal twig reward today: x${communityNote} (copied into the playtest for the run).\n\n| Scenario | Values | Mismatches |\n|---|---|---|\n${summary.join("\n")}\n${errs.length ? "\nPlaytest page errors:\n" + errs.map((e) => "- " + e).join("\n") + "\n" : ""}${lines.join("\n")}\n`;
  fs.writeFileSync(path.join(__dirname, "REPORT.md"), report);
  console.log(`${total - bad}/${total} match`);
  console.log(summary.join("\n"));
  await browser.close(); srv.close();
})().catch((e) => { console.error(e); process.exit(1); });
