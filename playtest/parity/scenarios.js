// Parity scenarios: each one is a partial save applied to BOTH Birb (live engine) and the playtest.
// Resources are plain numbers; upgrades and sunflowerUpgrades are id -> level, same as Birb's save.
module.exports = [
  { name: "fresh start", state: {} },
  { name: "early eggs", state: { resources: { popcorn: 5000 }, upgrades: { p_value: 12, p_speed: 5, p_capacity: 8, p_move_speed: 4 } } },
  { name: "first molt done", state: { rebirthCount: 1, playTime: 1800, resources: { popcorn: 3e6, goldenFeathers: 40 }, upgrades: { p_value: 40, p_speed: 10, p_capacity: 20, pr_popcorn_mult: 3, pr_radius_mult: 2 } } },
  { name: "seeds online", state: { rebirthCount: 4, playTime: 7200, resources: { popcorn: 2e9, goldenFeathers: 5000, sunflowerSeeds: 2e5 }, upgrades: { p_value: 120, p_speed: 12, p_capacity: 35, p_move_speed: 15, pr_popcorn_mult: 10, pr_radius_mult: 5, pr_respawn_mult: 4, s_more_popcorn: 6, s_more_feathers: 4, s_more_seeds: 3 },
    sunflowerUpgrades: { d_sunflower_machine: 1, d_popcorn_cap: 1, d_auto_gen: 1, d_faster_seeds: 1, d_seed_multiplier: 1 } } },
  { name: "evolve unlocked", state: { rebirthCount: 9, playTime: 20000, resources: { popcorn: 2e12, goldenFeathers: 1e6, sunflowerSeeds: 1e8 }, upgrades: { p_value: 300, p_speed: 12, p_capacity: 40, p_move_speed: 20, pr_popcorn_mult: 25, pr_radius_mult: 8, pr_respawn_mult: 8, s_more_popcorn: 15, s_more_feathers: 10, s_more_seeds: 10 },
    sunflowerUpgrades: { d_sunflower_machine: 1, d_popcorn_cap: 1, d_auto_gen: 1, d_faster_seeds: 1, d_seed_multiplier: 1, d_rebirth_playtime: 1, d_golden_harvest: 1, d_unlock_evolve: 1 } } },
  { name: "evolution 1", state: { evolutionCount: 1, rebirthCount: 2, playTime: 30000, resources: { popcorn: 1e8, goldenFeathers: 300 }, upgrades: { p_value: 60, p_speed: 8, p_capacity: 20, pr_popcorn_mult: 5 },
    sunflowerUpgrades: { d_unlock_evolve: 1, d_sunflower_machine: 1 } } },
  { name: "evolution 3", state: { evolutionCount: 3, rebirthCount: 20, playTime: 90000, resources: { popcorn: 1e14, goldenFeathers: 1e8, sunflowerSeeds: 1e10, monetariaMoneta: 5000 }, upgrades: { p_value: 500, p_speed: 12, p_capacity: 40, p_move_speed: 20, pr_popcorn_mult: 40, pr_radius_mult: 10, pr_respawn_mult: 10, s_more_popcorn: 25, s_more_feathers: 20, s_more_seeds: 20 },
    sunflowerUpgrades: { d_unlock_evolve: 1, d_sunflower_machine: 1, d_popcorn_cap: 1, d_auto_gen: 1, d_faster_seeds: 1, d_seed_multiplier: 1, d_rebirth_playtime: 1, d_golden_harvest: 1, d_fish_seeds: 1 } } },
];

// Aquarium + Fish Market scenarios: built from the fish data so both games get the same lists.
{
  const fs = require("fs"), path = require("path");
  const window = {}; eval(fs.readFileSync(path.join(__dirname, "../js/data.js"), "utf8"));
  const FISH = window.BIRB_DATA.tables.fish;
  const aquarium = (every, shinyEvery) => {
    const housedFish = {}, releasedShinyFishes = {};
    FISH.forEach((f, i) => { if (i % every === 0) housedFish[f.id] = true; if (shinyEvery && i % shinyEvery === 0) releasedShinyFishes[f.id] = true; });
    return { activeBiomeId: "coast", housedFish, researchedFishCounts: {}, releasedShinyFishes, releasedShinyWeightsKg: {} };
  };
  const disc = FISH.filter((f, i) => i % 2 === 0 && !f.id.startsWith("exp_")).map((f) => f.id);
  const inv = disc.slice(0, 60).map((id, i) => ({ fishId: id, count: 1 + (i % 7) * 3 }));
  const recs = disc.slice(0, 40).map((id, i) => ({ fishId: id, weightKg: 0.5 + i * 1.7 }));
  const base = { evolutionCount: 5, rebirthCount: 30, playTime: 200000, sunflowerUpgrades: { d_unlock_evolve: 1, d_double_fish_buff: 1 }, discoveredFish: disc, discoveredShinyFish: disc.slice(0, 8), fishInventory: inv, fishWeightRecords: recs };
  module.exports.push(
    { name: "aquarium early", state: { ...base, aquarium: aquarium(12, 0) } },
    { name: "aquarium mid", state: { ...base, aquarium: aquarium(3, 40) } },
    { name: "aquarium full + market", state: { ...base, fishInventory: [...inv, { fishId: disc[0] + "__shiny", count: 3 }], aquarium: { ...aquarium(1, 4), market: { contractReputationXp: 1200 } } } },
  );
}

// Nest scenarios (Birb's state.nest shape: twigs live in nest.resources)
{
  const fs = require("fs"), path = require("path");
  const window = {}; eval(fs.readFileSync(path.join(__dirname, "../js/data.js"), "utf8"));
  const FISH = window.BIRB_DATA.tables.fish;
  const box = (i, kind) => ({ slotIndex: i, specialized: kind !== "plain", ...(kind === "quad" ? { extraTrees: [{ age: 0, hp: 12 }, { age: 0, hp: 12 }] } : {}) });
  const boxes = (n, kind, from = 0) => Array.from({ length: n }, (_, i) => box(from + i, kind));
  const pick = (type) => FISH.find((f) => f.effect && f.effect.type === type && f.rarity === "rare") || FISH.find((f) => f.effect && f.effect.type === type);
  const fa = pick("popcorn_mult").id, fb = pick("seed_mult").id, fc = pick("xp_mult").id;
  const ev3 = { evolutionCount: 3, rebirthCount: 20, playTime: 90000, upgrades: { p_value: 300, p_speed: 12, p_capacity: 40, pr_respawn_mult: 6 }, sunflowerUpgrades: { d_unlock_evolve: 1, d_sunflower_machine: 1 } };
  module.exports.push(
    { name: "nest start", state: { ...ev3, nest: { unlocked: true, tier: 0, resources: { twigs: 40 }, forest: { tierTwigsProgress: 40, totalTwigsFromTrees: 40 } } } },
    { name: "nest boxes", state: { ...ev3, nest: { unlocked: true, tier: 0, resources: { twigs: 52000 }, upgrades: { n_twig_value: 60, n_peck_rate: 12, n_peck_power: 2 },
      forest: { tierTwigsProgress: 1e5, totalTwigsFromTrees: 1.2e5 }, cultivation: { schemaVersion: 8, treeBoxCount: 16, treeBoxes: boxes(16, "plain"), specialUpgrades: { fertilizer: true, grainSilo: true, cornfield: true } } } } },
    { name: "nest tier 2", redPanda: true, state: { ...ev3, evolutionCount: 5, resources: { monetariaMoneta: 5e5 },
      nest: { unlocked: true, tier: 2, resources: { twigs: 3e7 }, upgrades: { n_twig_value: 400, n_peck_rate: 20, n_peck_power: 9 }, forest: { tierTwigsProgress: 4e7, totalTwigsFromTrees: 6e7 },
        cultivation: { schemaVersion: 8, treeBoxCount: 16, treeBoxes: [...boxes(10, "quad"), ...boxes(6, "double", 10)], treeBoxEvolution: true, treeBoxQuadEvolution: true,
          specialUpgrades: { fertilizer: true, specializedFertilizer: true, grainSilo: true, cornfield: true, sunflowerField: true, wateringWell: true } },
        fishBreeding: { unlocked: true, hybrids: [{ id: "nest_hybrid_1", parentAId: fa, parentBId: fb, dominantParentId: fb, rarity: "epic", shiny: true, lineagePoints: 30, hatchedAt: 1 }], activeHybridId: "nest_hybrid_1", nextHybridId: 2 } },
      redPanda: { name: "Mochi", named: true, introSeen: true, mode: "chill" },
      fishInventory: [{ fishId: fa, count: 3 }, { fishId: fb, count: 2 }, { fishId: fc + "__shiny", count: 1 }] },
      breed: [[fa, fb], [fa, fc + "__shiny"], [fb, fb]] },
  );
  // Phase 3b: riverside and the sawmill (Nest IV + Evolution 6)
  const XPT = [0]; for (let L = 1; L < 99; L++) { const a = L - 1; XPT.push(XPT[L - 1] + 10 * Math.round((150 + 12 * a + 6 * a ** 2.2) / 10)); }
  const allSpecial = { fertilizer: true, specializedFertilizer: true, grainSilo: true, cornfield: true, sunflowerField: true, wateringWell: true };
  const ev6 = { ...ev3, evolutionCount: 6 };
  const nest6 = (extra, cult) => ({ unlocked: true, tier: 3, upgrades: { n_twig_value: 500, n_peck_rate: 20, n_peck_power: 12 }, forest: { tierTwigsProgress: 5e9, totalTwigsFromTrees: 9e9 },
    cultivation: { schemaVersion: 8, treeBoxCount: 16, treeBoxes: boxes(16, "quad"), treeBoxEvolution: true, treeBoxQuadEvolution: true, specialUpgrades: allSpecial, ...cult }, ...extra });
  const carp = (bench, prod) => ({ version: 4, workbenchLevel: bench, woodRemainderHp: 7, production: { balanceVersion: 6, workshopUnlocked: false, toolLevel: 0, expansionLevel: 0, upgrades: { forestry: 0, timber: 0, saw: 0 }, yieldRemainder: 0.3, autoEnabled: true, xp: 0, selected: "plank", stock: { plank: 0 }, progress: { plank: 0 }, ...prod } });
  const full = [...boxes(16, "quad"), ...boxes(8, "quad", 16)];
  module.exports.push(
    { name: "riverside locked", state: { ...ev3, evolutionCount: 5, nest: nest6({ tier: 2, resources: { twigs: 1e9 } }) } },
    { name: "riverside open", state: { ...ev6, nest: nest6({ resources: { twigs: 7e7 } }, { specialUpgrades: { ...allSpecial, sunflowerField: false } }) } },
    { name: "riverside open fields", state: { ...ev6, nest: nest6({ resources: { twigs: 3e8 }, riverside: { upgrades: { lumberyard: 1 } } }) } },
    { name: "riverside grove", state: { ...ev6, nest: nest6({ resources: { twigs: 5e8, wood: 40 }, fishBreeding: { unlocked: true },
      riverside: { upgrades: { pollinator: 1, lumberyard: 1, compost: 1, grove: 2, nursery: 0 }, compostProgress: 12, compostSlot: null, compostMask: 0, nextCompostSlot: 3 } },
      { treeBoxCount: 24, treeBoxes: full }) } },
    { name: "riverside grove waiting", state: { ...ev6, nest: nest6({ resources: { twigs: 5e8 }, riverside: { upgrades: { pollinator: 1, lumberyard: 1, grove: 3 } } }, { treeBoxCount: 20, treeBoxes: [...boxes(16, "quad"), ...boxes(4, "quad", 16)] }) } },
    { name: "sawmill wood", state: { ...ev6, nest: nest6({ resources: { twigs: 2e6, wood: 900 }, riverside: { upgrades: { lumberyard: 1 } }, carpentry: carp(1, { upgrades: { forestry: 5, timber: 3, saw: 0 } }) }) } },
    { name: "sawmill early", state: { ...ev6, nest: nest6({ resources: { twigs: 4e6, wood: 2500 }, riverside: { upgrades: { lumberyard: 1 } },
      carpentry: carp(1, { workshopUnlocked: true, xp: XPT[11] + 40, toolLevel: 1, upgrades: { forestry: 12, timber: 9, saw: 0 }, stock: { plank: 650 } }) }) } },
    { name: "sawmill mid", state: { ...ev6, nest: nest6({ resources: { twigs: 6e7, wood: 6000 }, riverside: { upgrades: { lumberyard: 1, pollinator: 1 } },
      carpentry: carp(2, { workshopUnlocked: true, xp: XPT[27] + 900, toolLevel: 4, upgrades: { forestry: 33, timber: 22, saw: 14 }, stock: { plank: 9000 } }) }) } },
    { name: "sawmill late", state: { ...ev6, nest: nest6({ resources: { twigs: 9e10, wood: 2e5 }, forest: { tierTwigsProgress: 2e10, totalTwigsFromTrees: 5e10 }, riverside: { upgrades: { lumberyard: 1 } },
      carpentry: carp(3, { workshopUnlocked: true, xp: XPT[72] + 5, toolLevel: 15, expansionLevel: 2, upgrades: { forestry: 61, timber: 41, saw: 52 }, stock: { plank: 4e5 } }) }) } },
    { name: "sawmill mastery", state: { ...ev6, nest: nest6({ resources: { twigs: 2e9, wood: 9000 }, forest: { tierTwigsProgress: 2e10, totalTwigsFromTrees: 5e10 }, riverside: { upgrades: { lumberyard: 1 } },
      carpentry: carp(3, { workshopUnlocked: true, xp: XPT[55], toolLevel: 15, upgrades: { forestry: 45, timber: 30, saw: 35 }, stock: { plank: 30000 } }) }) } },
  );
}

// Mine scenarios (Birb state.mine shape; d_mine_* nodes live in sunflowerUpgrades)
{
  const dm = (ids) => Object.fromEntries(ids.map((x) => ["d_mine_" + (Array.isArray(x) ? x[0] : x), Array.isArray(x) ? x[1] : 1]));
  const base = { evolutionCount: 5, rebirthCount: 30, playTime: 3e5, floorOneMineEntranceOpened: true };
  const MV = { journeyVersion: 1, currencyVersion: 1, deepCoreMigrationVersion: 3, crowRebirbLegacyCount: 0 }; // a current-format save
  module.exports.push(
    { name: "mine start", state: { ...base, resources: { bruteOre: 500 }, mine: { ...MV, highestArea: 0, crowLevel: 2, crowXp: 30 } } },
    { name: "mine mid", state: { ...base, resources: { bruteOre: 5e9 }, upgrades: { m_ore_value: 40, m_mining_power: 35, m_charged_strike: 3 },
      sunflowerUpgrades: dm(["work_perch", "precise_peck", "rich_vein", "impact_transfer", "peck_rhythm", "deep_survey", "seismic_strike"]),
      mine: { ...MV, highestArea: 4, crowLevel: 12, crowXp: 500, crowRebirbCount: 3, crowTrainingLevel: 30, goldOre: 900, campaign: { version: 2, areaDamage: { 4: 9e6 }, areaMilestones: { 4: 2 }, normalBreaks: 400, chargeHits: 1, oreDiscoveries: {} } } } },
    { name: "mine deep", state: { ...base, evolutionCount: 6, resources: { bruteOre: 1e30 }, upgrades: { m_ore_value: 300, m_mining_power: 280, m_charged_strike: 4 },
      sunflowerUpgrades: dm(["work_perch", "precise_peck", "rich_vein", "impact_transfer", "peck_rhythm", "deep_survey", "seismic_strike", "mineral_temper", "clean_extraction", "unbroken_rhythm", "work_pulse", "gold_beacon", "crown_survey", "fine_cut", "royal_mastery", "deep_mine", "royal_impact", "mineral_coffers", "seismic_echo", "royal_cut", ["abyssal_forge", 12], ["abyssal_treasure", 7]]),
      mine: { ...MV, highestArea: 10, crowLevel: 140, crowXp: 0, crowRebirbCount: 9, crowTrainingLevel: 160, goldOre: 50000, campaign: { version: 2, areaDamage: {}, areaMilestones: { 10: 4 }, normalBreaks: 9000, chargeHits: 0, oreDiscoveries: {} } } } },
    { name: "mine crow tracks", state: { ...base, evolutionCount: 6, mine: { ...MV, highestArea: 3, crowLevel: 20, crowArmorLevel: 12, crowDamageLevel: 30, crowRegenLevel: 7, crowDrainTarget: "damage" },
      parrot: { equipmentUpgrades: { beak: { rarity: "legendary", level: 5 }, armor: { rarity: "legendary", level: 5 }, aura: { rarity: "epic", level: 5 } } } } },
    { name: "mine crow tracks low gear", state: { ...base, evolutionCount: 6, mine: { ...MV, highestArea: 3, crowLevel: 20, crowArmorLevel: 12, crowDamageLevel: 30, crowRegenLevel: 7 },
      parrot: { equipmentUpgrades: { beak: { rarity: "legendary", level: 4 }, armor: { rarity: "legendary", level: 5 }, aura: { rarity: "legendary", level: 5 } } } } },
  );
}

// Desert scenarios (Phase 5): golden eggs, sandstorm, Dave (state.collaredDove)
{
  const sun = (ids) => Object.fromEntries(ids.map((x) => (Array.isArray(x) ? x : [x, 1])));
  const base = { evolutionCount: 5, rebirthCount: 40, playTime: 4e5, hasUnlockedDesertMap: true };
  const early = ["d_unlock_desert_tree", "d_desert_core_mockup", "d_desert_quest_merchant", "d_desert_golden_popcorn_chance", "d_desert_golden_popcorn_x2"];
  const mid = [...early, "d_desert_seed_generation_x2", "d_desert_fever", "d_desert_expedition_points", "d_desert_rebirb_golden_feathers", "d_desert_rebirb_parrot_vitality", "d_desert_field_notes",
    "d_desert_scout_gull", "d_desert_tackle_crate", "d_desert_guarded_plumage", "d_desert_salvage_rights", "d_desert_signal_smoke", "d_desert_auric_bargain", "d_desert_golden_popcorn_chance_3",
    "d_desert_golden_popcorn_gain_2", "d_desert_popcorn_spawn_rate", "d_desert_golden_popcorn_chance_4", "d_desert_collared_dove", "d_desert_dave_golden_xp", "d_desert_bloom_netting", "d_desert_bloom_reservoir",
    "d_desert_golden_popcorn_mult_unlock", "d_desert_seed_generation_x5", "d_desert_golden_popcorn_chance_2", "d_desert_popcorn_gain_x2", "d_desert_warpath", ["d_desert_field_notes_plus", 2]];
  const late = [...mid, "d_desert_seed_generation_x2_plus", "d_desert_auric_blueprints", ["d_desert_oasis_recovery", 5], "d_desert_muad_birb", "d_desert_sandstorm", "d_desert_gourmet_golden_popcorn",
    "d_desert_bountiful_harvest", "d_desert_feathered_harvest", "d_desert_golden_popcorn_chance_5", "d_desert_dune_conductors", "d_desert_golden_sand", "d_desert_dave_popcorn_xp"];
  const dove = (o) => ({ rebirbProgressionVersion: 3, unspentRebirbPoints: 0, level: 1, xp: 0, seedTrainingLevel: 0, rebirbCount: 1, cycleGoldenCollected: 0, instincts: { scavenger: 0, sweep: 0, gilded: 0 },
    upgrades: { scan: 0, sweep: 0, instinct: 0, storm: 0 }, lifetimeSweeps: 0, lifetimePopcornCollected: 0, lifetimeGoldenCollected: 0, ...o });
  module.exports.push(
    { name: "desert start", state: { ...base, resources: { goldenPopcorn: 40, sunflowerSeeds: 6e11 }, upgrades: { p_golden_popcorn_value: 3 }, sunflowerUpgrades: sun(early) } },
    { name: "desert dave", state: { ...base, sparrowPrestigeCount: 2, resources: { goldenPopcorn: 3e7, sunflowerSeeds: 4e13, goldenFeathers: 2e18 },
      upgrades: { p_golden_popcorn_value: 40, p_auric_silo: 5, pr_golden_popcorn_mult: 3 }, sunflowerUpgrades: sun(mid),
      collaredDove: dove({ level: 104, xp: 900, seedTrainingLevel: 12, rebirbCount: 14, unspentRebirbPoints: 1, instincts: { scavenger: 6, sweep: 4, gilded: 3 } }) } },
    { name: "desert sandstorm late", state: { ...base, evolutionCount: 6, desertSandstormTimeRemaining: 12, resources: { goldenPopcorn: 5e12, sunflowerSeeds: 1e22, goldenFeathers: 3e24 },
      upgrades: { p_golden_popcorn_value: 300, p_auric_silo: 30, pr_golden_popcorn_mult: 7 }, sunflowerUpgrades: sun(late),
      nest: { unlocked: true, tier: 3 },
      collaredDove: dove({ level: 260, xp: 5e4, seedTrainingLevel: 70, rebirbCount: 100, instincts: { scavenger: 40, sweep: 35, gilded: 25 } }) } },
  );
}

// Expedition scenarios (Phase 6a): parrot skills, gear, rebirbs, desert expedition nodes
{
  const eq = (b, a, u) => ({ beak: b, armor: a, aura: u });
  module.exports.push(
    { name: "expedition start", expedition: true, state: { evolutionCount: 4, rebirthCount: 20, expedition: { unlocked: true, highestFloorReached: 1, progress: { level: 1 } },
      parrot: { unlocked: true, level: 1, skillPoints: 40, rebirbCount: 0, skills: { hp: 10, lifeRegen: 2, damage: 25 } } } },
    { name: "expedition rebirb 1", state: { evolutionCount: 5, rebirthCount: 40, expedition: { unlocked: true, highestFloorReached: 7, progress: { level: 45 } },
      parrot: { unlocked: true, level: 45, skillPoints: 9000, rebirbCount: 1, skills: { hp: 4000, lifeRegen: 300, damage: 2500 }, equipmentUpgrades: eq({ rarity: "rare", level: 3 }, { rarity: "uncommon", level: 5 }, { rarity: "epic", level: 1 }) },
      sunflowerUpgrades: { d_desert_expedition_points: 1, d_desert_guarded_plumage: 1, d_desert_rebirb_parrot_vitality: 1, d_desert_warpath: 3, d_desert_combat_regen_penalty: 1, d_desert_salvage_rights: 1, d_desert_blossom_route: 1 } } },
    { name: "expedition late", expedition: true, night: true, state: { evolutionCount: 6, rebirthCount: 60, resources: { goldenPopcorn: 8e12 }, expedition: { unlocked: true, highestFloorReached: 9, progress: { level: 220 } },
      parrot: { unlocked: true, level: 220, skillPoints: 1e9, rebirbCount: 2, skills: { hp: 3e8, lifeRegen: 2e6, damage: 9e7 }, equipmentUpgrades: eq({ rarity: "legendary", level: 2 }, { rarity: "legendary", level: 4 }, { rarity: "epic", level: 5 }) },
      sunflowerUpgrades: { d_desert_expedition_points: 1, d_desert_muad_birb: 1, d_desert_shiny_enemies: 1, d_desert_dune_scouts: 1, d_desert_warpath: 5 } } },
  );
}

// Sacrifice Room scenarios (Phase 6b): milestone tiers, expansion, parrot rebirb unlock
{
  const sac = (n, x, rb, sp) => ({ evolutionCount: 5, rebirthCount: 40, expedition: { unlocked: true, highestFloorReached: 5, progress: { level: 30 }, sacrifice: { skillPointsSacrificed: n, commonMilestoneExpansionUnlocked: x } },
    parrot: { unlocked: true, level: 30, skillPoints: sp, rebirbCount: rb, skills: { hp: 500, lifeRegen: 50, damage: 400 }, artifactInventory: [{ instanceId: "art_sac_aura", name: "Spirit Aura", count: 80 }] } });
  module.exports.push(
    { name: "sacrifice tier I", expedition: true, state: sac(5000, false, 0, 300) },
    { name: "sacrifice capped III", expedition: true, state: sac(4e5, false, 0, 1e4) },
    { name: "sacrifice expansion V", expedition: true, state: sac(9e5, true, 0, 1e5) },
    { name: "sacrifice rebirb XIV", expedition: true, state: sac(3e12, false, 2, 1e9) },
  );
}

// Loot scenarios (Phase 6b): equipped artifacts with infusion, effect copies, inventory capacity
{
  let n = 0; const art = (name, infusionLevel = 0, count = 1) => ({ instanceId: `art_p_${++n}`, name, count, ...(infusionLevel ? { infusionLevel } : {}) });
  const kit = (items, eq, rb, extra = {}) => ({ evolutionCount: 5, rebirthCount: 40, expedition: { unlocked: true, highestFloorReached: 6, progress: { level: 60 }, sacrifice: { skillPointsSacrificed: 6e5, commonMilestoneExpansionUnlocked: true } },
    parrot: { unlocked: true, level: 60, skillPoints: 500, rebirbCount: rb, skills: { hp: 2000, lifeRegen: 200, damage: 1500 }, artifactInventory: items, equippedArtifacts: eq.map((i) => items[i].instanceId) }, ...extra });
  const a1 = [art("Crow Feather", 2), art("Spirit Vest"), art("Simple Book", 1), art("Spirit Aura", 0, 120), art("Minor Healing Potion", 0, 3)];
  const a2 = [art("Bandit Purse", 4), art("Bandit Purse", 1), art("Bandit Purse"), art("Point Hoard"), art("Divine Symbol", 3), art("Mythic Ledger", 2), art("Tempest Harp")];
  const a3 = [art("Skull of Reckoning", 10), art("Skull of Reckoning", 5), art("Storm Locket"), art("Depth Chronicle", 6), art("Mythic Ledger"), ...Array.from({ length: 30 }, () => art("Marrow Charm"))];
  module.exports.push(
    { name: "loot basic kit", expedition: true, state: kit(a1, [0, 1, 2], 0) },
    { name: "loot effect copies", expedition: true, state: kit(a2, [0, 1, 2, 3, 4], 2, { sunflowerUpgrades: { d_desert_blossom_route: 1 } }) },
    { name: "loot full bag", expedition: true, state: kit(a3, [0, 1, 2, 3], 1) },
  );
}

// Forge scenarios (Phase 6b): gear upgrade / evolve / refine plans, infusion, fusion, aura batches
{
  let n = 0; const art = (name, infusionLevel = 0, count = 1) => ({ instanceId: `art_f_${++n}`, name, count, ...(infusionLevel ? { infusionLevel } : {}) });
  const eq = (b, a, u) => ({ beak: b, armor: a, aura: u });
  const forge = (gear, items, sac, rb, mine) => ({ evolutionCount: 6, rebirthCount: 60, mine: mine || {}, expedition: { unlocked: true, highestFloorReached: 8, progress: { level: 120 }, sacrifice: { skillPointsSacrificed: sac, commonMilestoneExpansionUnlocked: true } },
    parrot: { unlocked: true, level: 120, skillPoints: 1e5, rebirbCount: rb, skills: { hp: 4e4, lifeRegen: 3e3, damage: 2e4 }, equipmentUpgrades: gear, artifactInventory: items, equippedArtifacts: [items[3].instanceId] } });
  const items1 = [art("Crow Feather", 1), art("Forest Egg"), art("Pair of Boots", 3), art("Spirit Vest", 2), art("Spirit Aura", 0, 640), art("Simple Book"), art("Witchcap", 5), art("Uncommon Spirit Aura", 0, 120), art("Rare Spirit Aura", 0, 30)];
  const items2 = [art("Holy Symbol", 4), art("Spirit Broth"), art("Umbra Bastion", 9), art("Skull of Reckoning", 14), art("Epic Spirit Aura", 0, 900), art("Legendary Spirit Aura", 0, 260), art("Spirit Amulet"), art("Auric Oath"), art("Mythic Spirit Aura", 0, 40)];
  module.exports.push(
    { name: "forge no milestone", expedition: true, state: forge(eq({ rarity: "common", level: 2 }, { rarity: "common", level: 5 }, { rarity: "uncommon", level: 1 }), items1, 100, 0) },
    { name: "forge early", expedition: true, state: forge(eq({ rarity: "common", level: 4 }, { rarity: "uncommon", level: 5 }, { rarity: "rare", level: 5 }), items1, 2e4, 0) },
    { name: "forge legendary", expedition: true, state: forge(eq({ rarity: "epic", level: 5 }, { rarity: "legendary", level: 3 }, { rarity: "legendary", level: 5 }), items2, 3e8, 3, { journeyVersion: 1, goldOre: 500, highestArea: 4, expeditionCycle: { version: 1, rewardedGiants: 4, refinements: { aura: 2 } } }) },
    { name: "forge refined deep", expedition: true, state: forge(eq({ rarity: "legendary", level: 5 }, { rarity: "legendary", level: 5 }, { rarity: "legendary", level: 5 }), items2, 3e10, 3, { journeyVersion: 1, goldOre: 9e4, highestArea: 9, expeditionCycle: { version: 1, rewardedGiants: 9, refinements: { beak: 3, armor: 35, aura: 0 } } }) },
  );
}

// Quest merchant scenarios (Phase 6c): unlock, daily picks (rules v1), progress, completions, the v2 reward migration, kill tracking
{
  const T0 = 1.8e12, DAY = 864e5, cyc = Math.floor(T0 / DAY);
  const qs = (kf, bc, kt) => ({ killsByFloor: kf, bossClearsByFloor: bc, killsByEnemyType: kt });
  const base = (hf, qm, stats, extra = {}) => ({ evolutionCount: 6, rebirthCount: 60, sunflowerUpgrades: { d_desert_quest_merchant: 1, ...(extra.sun || {}) },
    expedition: { unlocked: true, highestFloorReached: hf, progress: { level: 80 }, sacrifice: { skillPointsSacrificed: 0, commonMilestoneExpansionUnlocked: false }, questMerchant: qm, questStats: stats } });
  const kills = [[1, { type: "cobra", x: 600, y: 400 }], [1, { type: "masked-forest-spirit-blue", x: 600, y: 3500 }], [1, { type: "twig-blight", isElite: true, x: 600, y: 900 }],
    [2, { type: "witch", isBoss: true, x: 700, y: 3000 }], [4, { type: "fishfolk-whipe", x: 700, y: 3400 }], [6, { type: "ice-harpy", x: 600, y: 1200 }], [3, { type: "mini-fly", x: 600, y: 500 }],
    [3, { type: "anubis", isBoss: true, x: 900, y: 2000 }], [3, { type: "mummy", anubisSummon: true, x: 900, y: 2000 }]];
  module.exports.push(
    { name: "quest unlock", quest: { now: T0, kills }, state: base(4, { dailySeed: 424242 }, qs({ 1: 40 }, { 1: 1 }, { cobra: 5 })) },
    { name: "quest progress", quest: { now: T0, kills }, state: base(6, { unlockedAt: T0 - 9 * DAY, dailySeed: 99173, dailyCycle: cyc, rewardRulesVersion: 2, dailyRulesVersion: 1, nextRefreshAt: (cyc + 1) * DAY,
      lastRefreshAt: cyc * DAY, dailyQuestIds: ["daily_floor3_recon", "daily_hunt_witch", "daily_floor4_boss"], dailyCompletedQuestIds: [], dailyCompletionCounts: { daily_floor4_boss: 9, daily_hunt_cobra: 3, daily_floor1_clearance: 12 },
      mainCompletedQuestIds: ["main_floor1_first_incursion", "main_floor1_break_the_fangs"], dailyBaselineStats: qs({ 3: 100 }, { 4: 2 }, { witch: 4 }) },
      qs({ 1: 900, 2: 400, 3: 125, 4: 50 }, { 1: 6, 2: 1, 3: 2, 4: 3 }, { witch: 6, anubis: 1, "fishfolk-whipe": 99 })) },
    { name: "quest legacy migration", quest: { now: T0, kills }, state: base(9, { unlockedAt: T0 - 40 * DAY, dailySeed: 7, dailyCycle: cyc - 1, nextRefreshAt: cyc * DAY,
      dailyQuestIds: ["daily_floor1_boss", "daily_hunt_inkbender", "daily_floor2_predator_control"], dailyCompletedQuestIds: ["daily_floor1_boss"], completedQuestIds: ["main_defeat_anubis", "main_floor4_boss_gauntlet"],
      dailyCompletionCounts: { daily_floor4_boss: 30, daily_hunt_inkbender: 4, daily_floor1_boss: 2 }, mainCompletedQuestIds: ["main_floor6_frozen_apex"] },
      qs({ 1: 5000, 6: 2500, 7: 10 }, { 6: 5, 9: 1 }, { anubis: 3, "fishfolk-inkbender": 90 })) },
  );
}

// Fish market parrot buffs (Phase 6c): contract buffs of the expedition types stack; a legacy bought parrot buff counts if larger
{
  const far = 9e15, buff = (value, i) => ({ value, expiresAt: far, sourceContractId: `c_test_${i}`, rarity: "rare" });
  module.exports.push(
    { name: "market parrot buffs", expedition: false, state: { evolutionCount: 6, rebirthCount: 60, expedition: { unlocked: true, highestFloorReached: 5, progress: { level: 40 } },
      parrot: { unlocked: true, level: 40, skillPoints: 0, skills: { hp: 500, lifeRegen: 50, damage: 300 } },
      aquarium: { market: { unlockedAt: 1, contractReputationXp: 500, activeParrotBuffs: { expedition_damage_mult: { value: 0.9, expiresAt: far, sourceOfferId: "o1", rarity: "epic" }, expedition_hp_mult: { value: 0.2, expiresAt: far, sourceOfferId: "o2", rarity: "common" } },
        activeContractBuffs: { expedition_damage_mult: [buff(0.35, 1), buff(0.5, 2)], expedition_hp_mult: [buff(0.75, 3)], expedition_life_regen_mult: [buff(0.5, 4)], expedition_move_speed_mult: [buff(0.35, 5)],
          expedition_attack_speed_mult: [buff(1.1, 6)], expedition_skill_point_mult: [buff(1.65, 7)], expedition_chest_reward_mult: [buff(0.75, 8), { value: 9, expiresAt: 1000, sourceContractId: "old", rarity: "epic" }] } } } } },
  );
}

// Floor 1 mine entrance (Phase 6c): rebirb II + maxed starter gear (legendary, or epic 5); old saves with mine progress reopen it
{
  const gear = (b, a, u) => ({ beak: b, armor: a, aura: u }), L = { rarity: "legendary", level: 1 }, E5 = { rarity: "epic", level: 5 }, E4 = { rarity: "epic", level: 4 };
  const st = (rb, eq, extra = {}) => ({ evolutionCount: 6, rebirthCount: 60, expedition: { unlocked: true, highestFloorReached: 9, progress: { level: 50 } }, ...extra,
    parrot: { unlocked: true, level: 50, skillPoints: 0, rebirbCount: rb, skills: { hp: 10, lifeRegen: 0, damage: 10 }, equipmentUpgrades: eq } });
  module.exports.push(
    { name: "mine entrance ready", state: st(2, gear(L, E5, L)) },
    { name: "mine entrance epic 4", state: st(2, gear(L, E4, L)) },
    { name: "mine entrance rebirb 1", state: st(1, gear(L, L, L)) },
    { name: "mine entrance repair crow", state: st(0, gear(E4, E4, E4), { mine: { crowLevel: 3 } }) },
    { name: "mine entrance repair tree", state: st(0, gear(E4, E4, E4), { sunflowerUpgrades: { d_mine_work_perch: 1 } }) },
  );
}

// Mythic sacrifice (Phase 6c): levels from contributions, x1.2 final at I, night elite kills drop relics at II, doubled relic at III
{
  let n = 0; const art = (name, count = 1, infusionLevel = 0) => ({ instanceId: `art_m_${++n}`, name, count, ...(infusionLevel ? { infusionLevel } : {}) });
  const W = [{ skillPoints: 2e15, aura: 1200 }, { skillPoints: 4e15, aura: 3600 }, { skillPoints: 8e15, aura: 9000 }];
  const st = (contrib, extra, items, relic) => ({ evolutionCount: 6, rebirthCount: 60, expedition: { unlocked: true, highestFloorReached: 9, progress: { level: 300 },
      sacrifice: { skillPointsSacrificed: 2e16, commonMilestoneExpansionUnlocked: true }, mythicSacrifice: { contributions: contrib, ...extra } },
    parrot: { unlocked: true, level: 300, skillPoints: 5e15, rebirbCount: 3, skills: { hp: 1e6, lifeRegen: 1e4, damage: 5e5 }, artifactInventory: items,
      equippedArtifacts: [items[0].instanceId], ...(relic ? { relicSlot: relic } : {}),
      equipmentUpgrades: { beak: { rarity: "legendary", level: 5 }, armor: { rarity: "legendary", level: 5 }, aura: { rarity: "legendary", level: 5 } } } });
  const kills = [[1, { type: "elven-assassin", isElite: true, x: 1400, y: 4000 }], [1, { type: "zombie-cultist", isElite: true, x: 1400, y: 4000 }], [1, { type: "ice-fire-guardian", isBoss: true, x: 1400, y: 900 }],
    [1, { type: "shardsoul-slayer", x: 1400, y: 3000 }], [1, { type: "elven-assassin", isElite: true, x: 1400, y: 4000 }]];
  const i1 = [art("Spirit Vest", 1, 3), art("Mythic Spirit Aura", 400)], i2 = [art("Spirit Vest", 1, 3), art("Heart of the Veil", 1, 4), art("Mythic Spirit Aura", 50)];
  module.exports.push(
    { name: "mythic none", mythic: { kills }, state: st([{ skillPoints: 1e15, aura: 1200 }], {}, i1) },
    { name: "mythic I", mythic: { kills }, state: st([W[0], { skillPoints: 3e15, aura: 10 }], { eliteKills: 5 }, i1) },
    { name: "mythic II relic bar", mythic: { kills }, state: st([W[0], W[1], { skillPoints: 0, aura: 900 }], { eliteKills: 9, relicDrops: 1, pendingAura: 7 }, i2, "art_m_4") },
    { name: "mythic III doubled relic", mythic: { kills }, state: st([W[0], W[1], W[2]], { eliteKills: 11, relicDrops: 2, claimedRelicId: "veil_heart" }, i2, "art_m_7") },
  );
}

// Phase 7: the Archivist's Book, the archivist tree and the Echo Field
{
  const desert = ["d_desert_core_mockup", "d_desert_golden_popcorn_chance", "d_desert_golden_reserve", "d_desert_golden_sand", "d_desert_golden_emblem", "d_desert_tempered_glass", "d_desert_mineral_tracker", "d_desert_dune_conductors"];
  const base = (sun, extra = {}) => ({ evolutionCount: 6, rebirthCount: 80, hasUnlockedDesertMap: true, resources: { goldenPopcorn: 3e22, goldenFeathers: 4e31, echoPopcorn: 2.5e6 },
    sunflowerUpgrades: Object.fromEntries(["d_sunflower_machine", "d_unlock_desert_tree", ...desert, ...sun].map((k) => [k, 1])), mine: { journeyVersion: 1, highestArea: 9 },
    expedition: { unlocked: true, highestFloorReached: 9, archivistDefeated: true, progress: { level: 200 }, sacrifice: { skillPointsSacrificed: 0, commonMilestoneExpansionUnlocked: false } }, parrot: { unlocked: true, level: 200, rebirbCount: 3, skills: { hp: 10, lifeRegen: 0, damage: 10 } }, ...extra });
  const R = ["near_response", "duet", "tuning", "trail", "chord", "harvest"], A = ["mycelium", "meeting", "network", "roots", "coordination", "route"], V = ["flock_memory", "golden_memory", "veil", "knowledge", "ancient_roots", "deep_memory"];
  const nodes = (list) => list.map((k) => "d_archivist_echo_" + k);
  module.exports.push(
    { name: "archivist book", echo: true, state: base([]) },
    { name: "archivist tree early", echo: true, state: base(["d_unlock_archivist_tree", "d_archivist_popcorn_echo", "d_archivist_auric_rebirb", ...nodes(R.slice(0, 2)), ...nodes(A.slice(0, 1))],
      { upgrades: { p_echo_value: 24, p_echo_capacity: 6 }, echoGrove: { version: 2, lifetimeEarned: 8e4 } }) },
    { name: "archivist tree full", echo: true, state: base(["d_unlock_archivist_tree", "d_archivist_popcorn_echo", "d_archivist_auric_rebirb", "d_archivist_golden_ascension", "d_archivist_echo_chance", "d_archivist_echo_value_milestones",
      "d_archivist_echo_capacity_expansion", ...nodes(R), ...nodes(A), ...nodes(V), "d_archivist_echo_resonant_grove", "d_archivist_echo_forever"], { upgrades: { p_echo_value: 260, p_echo_capacity: 17 }, echoGrove: { version: 2, lifetimeEarned: 9e9 } }) },
  );
}
