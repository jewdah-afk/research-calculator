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
    { name: "expedition late", expedition: true, state: { evolutionCount: 6, rebirthCount: 60, resources: { goldenPopcorn: 8e12 }, expedition: { unlocked: true, highestFloorReached: 9, progress: { level: 220 } },
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
