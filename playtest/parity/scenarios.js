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
